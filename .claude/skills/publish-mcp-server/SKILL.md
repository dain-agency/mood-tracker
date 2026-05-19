---
name: publish-mcp-server
description: Publish a new version of @dain-os/mcp-server to npm. Use after a release PR (e.g. "chore(mcp): release @dain-os/mcp-server vX.Y.Z") has bumped packages/mcp-server/package.json on main, when npm view shows a version older than package.json, or when the user asks to "publish the MCP server" / "ship MCP server vX.Y.Z" / "push the new MCP server version to npm".
---

# Publish @dain-os/mcp-server to npm

This project has no GitHub Actions publish workflow for `@dain-os/mcp-server` — releases are cut by merging a version-bump PR to `main`, then **manually** running `npm publish` from the package directory. The npm token lives in Azure Key Vault `dain-os-kv` as the `NPM-PUBLISH-TOKEN` secret. Use this skill to drive the whole flow without leaking the token into a transcript.

## When to use

- A release PR (`chore(mcp): release @dain-os/mcp-server vX.Y.Z`) has been merged to `main` and `packages/mcp-server/package.json` reads the new version, but `npm view @dain-os/mcp-server version` still reports the old one.
- The user asks to "publish the MCP server", "ship MCP server v0.4.0", "push the new MCP server to npm".
- `npm view @dain-os/mcp-server version` < `packages/mcp-server/package.json` version on `main`.

## Prerequisites

- Secret `NPM-PUBLISH-TOKEN` present in Azure Key Vault `dain-os-kv` (an automation token with publish rights on the `@dain-os` org).
- `az` CLI installed and logged in (`az account show` should succeed). Locally this uses your developer identity; on Azure App Service the managed identity is used by other paths but this skill always runs locally.
- `git`, `node`, `npm` available locally.
- Current branch is `main` and is fully up to date with `origin/main` (or you are in a worktree that was created from `origin/main`).
- `.claude/settings.json` must NOT contain `Bash(npm publish:*)` in its `deny` list. Deny rules override `--dangerously-skip-permissions`, so a stray entry will block every step of this skill. The deny was lifted intentionally in the PR that introduced this skill — if it's been re-added, remove it again rather than working around it.

## The 5-step flow

### 1. Confirm the version that's about to publish

```bash
LOCAL=$(node -p "require('./packages/mcp-server/package.json').version")
REMOTE=$(npm view @dain-os/mcp-server version)
echo "local:  $LOCAL"
echo "npm:    $REMOTE"
```

- If `LOCAL === REMOTE`, **stop**: there's no new version to publish. The release PR may not be merged yet, or someone already published. Surface this to the user.
- If `LOCAL < REMOTE`, **stop**: the local tree is behind. `git pull` on main first.
- If `LOCAL > REMOTE`, continue.

### 2. Build + dry-run

The package's `prepare` script runs `tsc`, so `npm publish` will build. Do a dry-run first so the tarball contents are visible before the real publish:

```bash
cd packages/mcp-server
npm publish --dry-run 2>&1 | tail -30
```

Confirm the tarball contains `dist/` and `README.md` only (the `files` field restricts this). Surface the file list to the user before continuing.

### 3. Publish using the token from Azure Key Vault

**Never echo the token.** Pull it from Key Vault into a temp `.npmrc`, point `npm publish` at it explicitly with `--userconfig`, then delete the temp file.

Two reasons to use `--userconfig` rather than a package-local `.npmrc`:

1. The monorepo root holds an `npm` workspaces config. Running `npm publish` from `packages/mcp-server/` triggers `ENOWORKSPACES` on any in-tree `.npmrc` lookup, and the per-package file is silently skipped — leaving the publish unauthenticated (`ENEEDAUTH`).
2. A `.npmrc` inside `packages/mcp-server/` isn't gitignored, so a careless `git add .` would commit the token. Keeping it in `/tmp` removes that footgun.

```bash
# From the repo root
set +o history 2>/dev/null   # bash; zsh uses `setopt nohistsave`
NPM_TOKEN=$(az keyvault secret show --vault-name dain-os-kv --name NPM-PUBLISH-TOKEN --query value -o tsv)
[ -z "$NPM_TOKEN" ] && { echo "NPM-PUBLISH-TOKEN not found in dain-os-kv (run 'az login' or check the secret)"; exit 1; }

# Write a one-shot npmrc OUTSIDE the repo so it can't be staged
NPMRC=$(mktemp --suffix=-npmrc)
chmod 600 "$NPMRC"
cat > "$NPMRC" <<EOF
//registry.npmjs.org/:_authToken=${NPM_TOKEN}
registry=https://registry.npmjs.org/
EOF

# Publish — --userconfig forces npm to read this file, --no-workspaces bypasses the monorepo workspace error
cd packages/mcp-server
npm publish --userconfig="$NPMRC" --no-workspaces 2>&1 | tail -10
PUBLISH_EXIT=$?

# Scrub
rm -f "$NPMRC"
unset NPM_TOKEN NPMRC
set -o history 2>/dev/null
exit $PUBLISH_EXIT
```

If `npm publish` fails (see Failure modes below), the `rm -f "$NPMRC"` line still runs; double-check the temp file is gone (`ls "$NPMRC" 2>&1`) before walking away.

**One-time setup if `NPM-PUBLISH-TOKEN` is missing from the vault:**

```bash
# Generate a new automation token at https://www.npmjs.com/settings/<user>/tokens
# (must be "Automation" type for the @dain-os org), then:
az keyvault secret set --vault-name dain-os-kv --name NPM-PUBLISH-TOKEN --value '<the-token>'
```

### 4. Verify

```bash
npm view @dain-os/mcp-server version
```

Should print the new version. Also verify the tarball lands by checking `npm view @dain-os/mcp-server time --json | tail -5` — the new version should have a timestamp within the last minute.

### 5. Tag + push

Past releases haven't been tagged consistently, but it's a cheap audit trail. From the repo root (still on `main`):

```bash
VERSION=$(node -p "require('./packages/mcp-server/package.json').version")
git tag "mcp-server-v${VERSION}"
git push origin "mcp-server-v${VERSION}"
```

Tell the user the publish is live and suggest they bump any local `.mcp.json` pinned to `@dain-os/mcp-server@<old-version>`.

## Hard rules

1. **Never commit `packages/mcp-server/.npmrc`.** Step 3 writes it transiently and removes it before the function returns. If `npm publish` errors out, **verify the file is gone** before reporting back.
2. **Never echo the token.** Don't `cat .npmrc`, don't print `$NPM_TOKEN`, don't pass `--verbose` to `npm publish` (it can dump auth headers).
3. **Never `git add` the `.npmrc`.** It's not gitignored at `packages/mcp-server/` — assume any stray file there will be picked up by a careless `git add .`. The scrub in step 3 must run.
4. **Never publish from a worktree's stale `main`.** If you're driving this from a worktree, the worktree must have been created from `origin/main` *after* the release PR merged. Otherwise you'll publish the old version.
5. **Don't bump the version yourself.** This skill publishes whatever's on `main`. The version bump is a separate PR (`chore(mcp): release @dain-os/mcp-server vX.Y.Z`) reviewed by a human.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `403 Forbidden — You do not have permission to publish` | The token in Key Vault lacks publish scope, or has been revoked | Generate a new automation token on npmjs.com under the `@dain-os` org, then `az keyvault secret set --vault-name dain-os-kv --name NPM-PUBLISH-TOKEN --value '<new-token>'`. The old version is retained in the vault's history if you need to roll back |
| `402 / EOTP — One-time password required` | The token requires a 2FA OTP for publish | Re-run with `npm publish --otp=<code>`. Automation tokens are normally exempt; if you hit this, the token is the wrong type (use "Automation", not "Publish") |
| `409 / version already exists` | Someone already published this version | Stop. Open a new PR bumping to the next patch (`X.Y.Z+1`) and merge before retrying |
| `npm ERR! code ENEEDAUTH` | The `.npmrc` wasn't read (often: a package-local `.npmrc` got skipped because of the workspace root) or the token line is malformed | Confirm you passed `--userconfig="$NPMRC" --no-workspaces` to `npm publish`. The skill flow uses `mktemp` for the `.npmrc` for exactly this reason — running `npm publish` from inside the workspace without `--userconfig` silently ignores per-package `.npmrc` files |
| `Forbidden — please log in via the CLI` / `az: 'keyvault' is not a valid command` | `az` CLI not installed or not logged in | Install Azure CLI, then `az login`. The dev login is enough; no managed identity needed for this local flow |
| `tsc` fails during the `prepare` step | TypeScript error in `src/` | Fix on a branch, open a PR, merge, retry. Don't `--ignore-scripts` past it — that ships an empty `dist/` |

## Why manual

Two reasons we haven't automated this with a workflow:

1. **Low frequency.** Releases are bursty (sometimes weeks apart). The manual review of `npm publish --dry-run` output catches the occasional stray file before it ships.
2. **Token blast radius.** Putting an npm publish token in GitHub Actions secrets makes every Actions run a potential exfil vector. Keeping the token in Azure Key Vault scopes access to anyone with an `az` login against the `dain-os-kv` vault (currently developers + the API's App Service managed identity), and every read is audited.

If the cadence picks up, revisit — `pr-build-check.yml` already runs on PRs and could be extended with a `release` job that triggers on a `mcp-server-v*` tag push. That release job could pull `NPM-PUBLISH-TOKEN` from Key Vault via the `azure/login` + `azure/get-keyvault-secrets` actions, keeping the token out of GitHub Secrets. That would also remove the "did you remember to tag?" step 5 fragility.
