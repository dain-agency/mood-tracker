# Publish @dain-os/mcp-server to npm + deploy to mcp.dainos.app

Two deployment surfaces:

1. **npm** (`@dain-os/mcp-server`) — used by local stdio clients (`npx -y @dain-os/mcp-server`).
2. **Vercel** (`mcp.dainos.app`) — the cloud HTTP endpoint used by Claude Code MCP config and subagents. Served from the `mcp-server` project on the `dain-agency` Vercel team, deployed from the `feat/cloud-mcp` branch.

Both must be updated on every release. npm publish ships the package; Vercel deploy ships the cloud endpoint. Forgetting the Vercel deploy means the cloud MCP serves stale tools until someone notices.

## When to use

- A release PR (`chore(mcp): release @dain-os/mcp-server vX.Y.Z`) has been merged to `main` and `packages/mcp-server/package.json` reads the new version, but `npm view @dain-os/mcp-server version` still reports the old one.
- The user asks to "publish the MCP server", "ship MCP server v0.4.0", "push the new MCP server to npm".
- `npm view @dain-os/mcp-server version` < `packages/mcp-server/package.json` version on `main`.

## Prerequisites

- Secret `NPM-PUBLISH-TOKEN` present in Azure Key Vault `dain-os-kv` (an automation token with publish rights on the `@dain-os` org).
- `az` CLI installed and logged in (`az account show` should succeed).
- `vercel` CLI installed and logged in to the `dain-agency` team.
- `git`, `node`, `npm` available locally.
- Current branch is `main` and is fully up to date with `origin/main` (or you are in a worktree that was created from `origin/main`).
- `.claude/settings.json` must NOT contain `Bash(npm publish:*)` in its `deny` list. Deny rules override `--dangerously-skip-permissions`, so a stray entry will block every step of this skill. The deny was lifted intentionally in the PR that introduced this skill — if it has been re-added, remove it again rather than working around it.

## The 7-step flow

### 1. Confirm the version that is about to publish

```bash
cd /home/dane/dain-os
LOCAL=$(node -p "require('./packages/mcp-server/package.json').version")
REMOTE=$(npm view @dain-os/mcp-server version)
echo "local:  $LOCAL"
echo "npm:    $REMOTE"
```

- If `LOCAL === REMOTE`, **stop**: there is no new version to publish. The release PR may not be merged yet, or someone already published. Surface this to the user.
- If `LOCAL < REMOTE`, **stop**: the local tree is behind. `git pull` on main first.
- If `LOCAL > REMOTE`, continue.

### 2. Build + dry-run

The package prepare script runs `tsc`, so `npm publish` will build. Do a dry-run first so the tarball contents are visible before the real publish:

```bash
cd packages/mcp-server
npm publish --dry-run 2>&1 | tail -30
```

Confirm the tarball contains `dist/` and `README.md` only (the `files` field restricts this). Surface the file list to the user before continuing.

### 3. Publish using the token from Azure Key Vault

**Never echo the token.** Pull it from Key Vault into a temp `.npmrc`, point `npm publish` at it explicitly with `--userconfig`, then delete the temp file.

Two reasons to use `--userconfig` rather than a package-local `.npmrc`:

1. The monorepo root holds an `npm` workspaces config. Running `npm publish` from `packages/mcp-server/` triggers `ENOWORKSPACES` on any in-tree `.npmrc` lookup, and the per-package file is silently skipped, leaving the publish unauthenticated (`ENEEDAUTH`).
2. A `.npmrc` inside `packages/mcp-server/` is not gitignored at the repo root, so a careless `git add .` would commit the token. Keeping it in `/tmp` removes that footgun. (Note: `packages/mcp-server/.gitignore` exists but only covers `.vercel/`.)

```bash
# From the repo root
set +o history 2>/dev/null
NPM_TOKEN=$(az keyvault secret show --vault-name dain-os-kv --name NPM-PUBLISH-TOKEN --query value -o tsv)
[ -z "$NPM_TOKEN" ] && { echo "NPM-PUBLISH-TOKEN not found in dain-os-kv (run az login or check the secret)"; exit 1; }

# Write a one-shot npmrc OUTSIDE the repo so it cannot be staged
NPMRC=$(mktemp --suffix=-npmrc)
chmod 600 "$NPMRC"
cat > "$NPMRC" <<EOF
//registry.npmjs.org/:_authToken=${NPM_TOKEN}
registry=https://registry.npmjs.org/
EOF

# Publish. --userconfig forces npm to read this file, --no-workspaces bypasses the monorepo workspace error
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

### 4. Verify npm

```bash
npm view @dain-os/mcp-server version
```

Should print the new version. Also verify the tarball lands by checking `npm view @dain-os/mcp-server time --json | tail -5`. The new version should have a timestamp within the last minute.

### 5. Tag + push

From the repo root (still on `main`):

```bash
VERSION=$(node -p "require('./packages/mcp-server/package.json').version")
git tag "mcp-server-v${VERSION}"
git push origin "mcp-server-v${VERSION}"
```

### 6. Deploy to Vercel (mcp.dainos.app)

The cloud MCP endpoint runs on Vercel from the `feat/cloud-mcp` branch. It serves the compiled `dist/http.js` from the monorepo `packages/mcp-server/` directory. The Vercel project is `mcp-server` on the `dain-agency` team (`prj_EztEE1S3HunLWhqlBRale9IGO8Wi`).

**Vercel does NOT auto-deploy from git pushes** for this project. You must deploy manually.

#### 6a. Merge main into feat/cloud-mcp

```bash
git checkout feat/cloud-mcp
git merge main -m "merge main: <description> (v<VERSION>)"
```

If there are merge conflicts, resolve them taking main version for everything under `packages/mcp-server/src/tools/`. Push after resolving:

```bash
git push origin feat/cloud-mcp
```

#### 6b. Build and deploy

```bash
cd packages/mcp-server
npx tsc   # build dist/
```

Verify `.vercel/project.json` points to the correct project:

```json
{"projectId":"prj_EztEE1S3HunLWhqlBRale9IGO8Wi","orgId":"team_qTXqkkgjQK7bx0HXQ2P7S9gR","projectName":"mcp-server"}
```

If it points elsewhere, overwrite it with the above. Then deploy:

```bash
vercel deploy --prod
```

Confirm the output shows `dain-agency` in the URL (not `dane-krambergars-projects`). If it deployed to the wrong team, fix `.vercel/project.json` and redeploy.

#### 6c. Verify the cloud endpoint

```bash
curl -s -X POST https://mcp.dainos.app/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DAINOS_API_TOKEN}" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' \
  | python3 -c "import json,sys; tools=json.load(sys.stdin)['result']['tools']; print(f'{len(tools)} tools'); [print(f'  - {t[\"name\"]}') for t in tools]"
```

Confirm the tool count and names match what was just published. The `describe_schema`, `query`, and `mutate` generic tools should be present.

### 7. Notify

Tell the user:
- The publish is live on npm (`@dain-os/mcp-server@<version>`).
- The cloud endpoint at `mcp.dainos.app` is updated.
- Suggest they restart Claude Code to pick up the new tools if using the cloud HTTP MCP.
- Suggest bumping any local `.mcp.json` files pinned to the old version.

## Hard rules

1. **Never commit `packages/mcp-server/.npmrc`.** Step 3 writes it transiently and removes it before the function returns. If `npm publish` errors out, **verify the file is gone** before reporting back.
2. **Never echo the token.** Do not `cat .npmrc`, do not print `$NPM_TOKEN`, do not pass `--verbose` to `npm publish` (it can dump auth headers).
3. **Never `git add` the `.npmrc`.** It is not gitignored at `packages/mcp-server/`. Assume any stray file there will be picked up by a careless `git add .`. The scrub in step 3 must run.
4. **Never publish from a worktree stale `main`.** If you are driving this from a worktree, the worktree must have been created from `origin/main` *after* the release PR merged. Otherwise you will publish the old version.
5. **Do not bump the version yourself.** This skill publishes whatever is on `main`. The version bump is a separate PR (`chore(mcp): release @dain-os/mcp-server vX.Y.Z`) reviewed by a human.
6. **Always deploy to Vercel after npm publish.** The cloud endpoint at `mcp.dainos.app` is the primary MCP surface for Claude Code. Forgetting this step means the cloud serves stale tools.
7. **Always verify `.vercel/project.json` before `vercel deploy`.** The Vercel CLI deploys to whatever project is linked locally. A wrong `projectId` deploys to a personal project instead of the team project, which is invisible to users.

## Vercel project details

| Field | Value |
|---|---|
| Team | Dain (`team_qTXqkkgjQK7bx0HXQ2P7S9gR`, slug: `dain-agency`) |
| Project | `mcp-server` (`prj_EztEE1S3HunLWhqlBRale9IGO8Wi`) |
| Domain | `mcp.dainos.app` |
| Source branch | `feat/cloud-mcp` |
| Entry point | `dist/http.js` via `@vercel/node` |
| Config | `packages/mcp-server/vercel.json` |
| Routes | `POST /mcp` (MCP JSON-RPC), `GET /health` |

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `403 Forbidden` | Token in Key Vault lacks publish scope or revoked | New automation token on npmjs.com, then `az keyvault secret set --vault-name dain-os-kv --name NPM-PUBLISH-TOKEN --value '<new-token>'` |
| `402 / EOTP` | Wrong token type | Use "Automation", not "Publish" |
| `409 / version already exists` | Already published | Bump to next patch and retry |
| `npm ERR! code ENEEDAUTH` | `.npmrc` not read or token malformed | Confirm `--userconfig="$NPMRC" --no-workspaces` flags |
| `az: keyvault not found` | CLI not installed or not logged in | `az login` |
| `tsc` fails in `prepare` | TypeScript error | Fix on a branch, merge, retry. Do not `--ignore-scripts` past it |
| Vercel deploys to wrong team (`dane-krambergars-projects`) | `.vercel/project.json` has wrong `projectId`/`orgId` | Overwrite with correct values from table above, redeploy |
| Vercel deploy shows ERROR | Build failure (usually tsc errors from merge conflicts) | Check `vercel logs` or inspector URL. Fix conflicts on `feat/cloud-mcp`, rebuild, redeploy |
| `mcp.dainos.app` still serves old tools | Vercel edge cache or DNS propagation | Wait 30 seconds and re-test. If stale after 2 minutes, check the deployment inspector URL |
| Cloud MCP returns old tool count | `feat/cloud-mcp` branch not updated with main | `git checkout feat/cloud-mcp && git merge main && git push && cd packages/mcp-server && npx tsc && vercel deploy --prod` |

## Why manual

Two reasons we have not automated this with a workflow:

1. **Low frequency.** Releases are bursty (sometimes weeks apart). The manual review of `npm publish --dry-run` output catches the occasional stray file before it ships.
2. **Token blast radius.** Putting an npm publish token in GitHub Actions secrets makes every Actions run a potential exfil vector. Keeping the token in Azure Key Vault scopes access to anyone with an `az` login against the `dain-os-kv` vault (currently developers + the API App Service managed identity), and every read is audited.

If the cadence picks up, revisit. `pr-build-check.yml` already runs on PRs and could be extended with a `release` job that triggers on a `mcp-server-v*` tag push. That release job could pull `NPM-PUBLISH-TOKEN` from Key Vault via the `azure/login` + `azure/get-keyvault-secrets` actions, keeping the token out of GitHub Secrets. The Vercel deploy could also be automated via the Vercel CLI in the same workflow, or by connecting the Vercel project to the `main` branch with a root directory filter on `packages/mcp-server/`.