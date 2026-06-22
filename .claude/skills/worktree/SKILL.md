---
name: worktree
description: Use when creating a new git worktree for a feature branch, tearing down a worktree after a PR merges, or recovering from worktree breakage (missing .env files, stale ORM client, "Device or resource busy" on cleanup, dev servers from another worktree winning the port). Covers the full setup + cleanup lifecycle for `.claude/worktrees/<slug>/`. Auto-detects ORM, env files, and workspace packages — works across Node monorepos with or without Prisma/Drizzle, npm/pnpm/yarn, single-app or multi-app layouts.
---

# Worktree Lifecycle

This skill exists because the same things break on every fresh worktree, in every Node repo: env files missing (always gitignored), ORM client stale (Prisma / Drizzle), dev servers from a previous worktree still holding the directory, workspace package `dist/` missing. The recipes below handle all of them, and **auto-detect** what each repo needs — so it works whether your stack uses Prisma, Drizzle, or no ORM at all; npm, pnpm, or yarn; one app or fifteen.

**Worktree home:** `<repo-root>/.claude/worktrees/<branch-slug>/`. Use the branch's trailing segment as the slug (`feat/some-thing` → `some-thing`).

**node_modules strategy:** hardlink-copy from main (`cp -al`). Inode-shared, so a large monorepo's `node_modules` (often 1–3 GB) costs ~5 seconds and near-zero new disk per worktree. Safe because `npm`/`pnpm`/`yarn` replace files atomically on install rather than mutating them in place — a later `install` in the worktree won't corrupt the source.

---

## Setup — new worktree

Run from the **main repo root**, not from inside an existing worktree.

```bash
BRANCH=feat/your-feature
SLUG=your-feature
WT=.claude/worktrees/$SLUG
REPO=$(git rev-parse --show-toplevel)

# 1. Create the worktree + branch from origin/main
git worktree add -b "$BRANCH" "$WT" origin/main

# 2. Hardlink-copy every node_modules in the repo (auto-detect — no hardcoded paths).
#    Excludes: node_modules nested inside another (covered by -prune), .git, and
#    any sibling worktrees under .claude/worktrees/ (otherwise we'd hardlink every
#    other worktree's deps into the new one — nested and pointless).
find "$REPO" -name node_modules -type d -prune \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "$REPO/.claude/worktrees/*" 2>/dev/null \
| while read -r src; do
    rel="${src#"$REPO"/}"
    mkdir -p "$(dirname "$WT/$rel")"
    cp -al "$src" "$WT/$rel" && echo "  hardlinked $rel"
  done

# 3. Reconcile against the lockfile — detect package manager from packageManager
#    field or lockfile presence, then run install with offline preference.
PKG_MANAGER=$(node -e "try{console.log((require('$REPO/package.json').packageManager||'').split('@')[0]||'')}catch{}" 2>/dev/null)
[ -z "$PKG_MANAGER" ] && [ -f "$REPO/pnpm-lock.yaml" ] && PKG_MANAGER=pnpm
[ -z "$PKG_MANAGER" ] && [ -f "$REPO/yarn.lock" ]      && PKG_MANAGER=yarn
[ -z "$PKG_MANAGER" ]                                  && PKG_MANAGER=npm
echo "  package manager: $PKG_MANAGER"
case "$PKG_MANAGER" in
  pnpm) (cd "$WT" && pnpm install --prefer-offline --reporter=silent) ;;
  yarn) (cd "$WT" && yarn install --prefer-offline --silent) ;;
  npm)  (cd "$WT" && npm install  --prefer-offline --no-audit --no-fund) ;;
esac

# 4. Copy every gitignored env file (auto-detect — no hardcoded paths).
#    Mirrors each .env / .env.local / .env.development / etc from main to the same
#    relative path in the worktree.
cd "$REPO"
git ls-files --others --ignored --exclude-standard -z \
| tr '\0' '\n' \
| grep -E '(^|/)\.env(\..*)?$' \
| while read -r rel; do
    [ -f "$REPO/$rel" ] || continue
    mkdir -p "$(dirname "$WT/$rel")"
    cp "$REPO/$rel" "$WT/$rel" && echo "  copied $rel"
  done

# 5. ORM client regeneration (auto-detect — only runs if a schema is found).
#    Prisma: find every prisma/schema.prisma and run `prisma generate` from its parent.
#    Drizzle: find every drizzle.config.{ts,js,mjs} and run `drizzle-kit generate` from its parent.
#    No schemas found → step is a no-op, which is correct for repos that don't use an ORM.
find "$WT" -name schema.prisma -not -path "*/node_modules/*" 2>/dev/null \
| while read -r schema; do
    dir=$(dirname "$(dirname "$schema")")
    echo "  prisma generate in $dir"
    (cd "$dir" && npx prisma generate >/dev/null)
  done
find "$WT" -maxdepth 4 -name 'drizzle.config.*' -not -path "*/node_modules/*" 2>/dev/null \
| while read -r cfg; do
    dir=$(dirname "$cfg")
    echo "  drizzle-kit generate in $dir"
    (cd "$dir" && npx drizzle-kit generate >/dev/null) || true
  done

# 6. Strip baked dev URLs from the env files we just copied — anything that pins
#    a host name will defeat per-worktree subdomain routing (Portless / Caddy /
#    mkcert / vite preview). Operates only on gitignored env files (the same
#    list as step 4) so we never touch tracked .env.example / .env.sample.
cd "$REPO"
git ls-files --others --ignored --exclude-standard -z \
| tr '\0' '\n' \
| grep -E '(^|/)\.env(\..*)?$' \
| while read -r rel; do
    f="$WT/$rel"
    [ -f "$f" ] || continue
    if grep -qE '^(NEXT_PUBLIC_|VITE_|REACT_APP_|PUBLIC_)[A-Z_]*(API_URL|BASE_URL|HOST|HOSTNAME)=' "$f"; then
      cp "$f" "$f.worktree-backup"
      sed -i.bak -E '/^(NEXT_PUBLIC_|VITE_|REACT_APP_|PUBLIC_)[A-Z_]*(API_URL|BASE_URL|HOST|HOSTNAME)=/d' "$f"
      rm -f "$f.bak"
      echo "  stripped baked public URL vars from $rel (backup at .worktree-backup)"
    fi
  done

echo ""
echo "Worktree ready at: $WT"
```

**Verify:**

```bash
# Every gitignored env file present in main should also exist in the worktree.
missing=0
cd "$REPO"
git ls-files --others --ignored --exclude-standard -z \
| tr '\0' '\n' \
| grep -E '(^|/)\.env(\..*)?$' \
| while read -r rel; do
    if [ ! -f "$WT/$rel" ]; then echo "  MISSING in worktree: $rel"; missing=1; fi
  done
[ "$missing" = "0" ] && echo "OK: env files mirrored"

# If a TypeScript root exists, type-check from the worktree to surface drift.
(cd "$WT" && [ -f tsconfig.json ] && npx tsc --noEmit 2>&1 | tail -3 || echo "no root tsconfig — skipping type-check")
```

Smoke-test recipes for the dev server depend on your repo's proxy setup (Portless, Caddy, mkcert, vite preview). Add a project-specific verification step on top of this skill rather than baking it in.

---

## Cleanup — post-merge teardown

**Always confirm before removing.** Another session may be using the worktree, or there may be unpushed work the merge didn't capture.

> For sweeping *many* stale worktrees/branches at once (not just the one you just merged), use `/worktree-gc` — it applies the same integration ladder across every worktree with a dry-run preview.

```bash
SLUG=your-feature
WT=.claude/worktrees/$SLUG
BRANCH=$(git -C "$WT" rev-parse --abbrev-ref HEAD)

# 1. Show the state — eyeball this before removing
echo "=== Worktree: $WT ==="
echo "Branch: $BRANCH"
git -C "$WT" status --short
echo ""
# Integration check — squash-merge-safe. --merged is USELESS under squash-merge
# (SHAs differ), so use the [gone]-upstream + gh-PR ladder instead.
BASE=$(git rev-parse --verify --quiet refs/remotes/origin/develop >/dev/null && echo develop || echo main)
git fetch --prune --quiet 2>/dev/null || true
TRACK=$(git for-each-ref --format='%(upstream:track)' "refs/heads/$BRANCH" 2>/dev/null)
if [ "$TRACK" = "[gone]" ]; then
  echo "INTEGRATED (remote branch deleted after merge) — safe to remove"
elif command -v gh >/dev/null 2>&1 && [ "$(gh pr view "$BRANCH" --json state --jq .state 2>/dev/null)" = "MERGED" ]; then
  echo "INTEGRATED (gh: PR merged) — safe to remove"
else
  echo "NOT provably integrated into $BASE — bail out (keep on ambiguity)"
fi
echo ""
echo "Dev server processes holding this directory?"
pgrep -af "$WT" || echo "  (none)"
```

If anything looks off — uncommitted changes, unmerged branch, running processes — **stop and surface it to the user**. Don't `git worktree remove --force` to make the warning go away; that's how work gets lost.

When the state is clean and the user has confirmed:

```bash
# 2. Kill any dev processes rooted in the worktree (Linux/macOS)
pgrep -f "$WT" | xargs -r kill
sleep 1
pgrep -f "$WT" | xargs -r kill -9   # only if anything survived SIGTERM

# 3. Remove the worktree
git worktree remove "$WT"

# 4. Delete the local branch (safe if provably integrated; if `git branch -d` refuses,
#    the branch is not fully merged — keep it rather than forcing -D)
git branch -d "$BRANCH"

# 5. Prune any stale worktree metadata
git worktree prune
```

If `git worktree remove` complains about untracked files (typically `node_modules/.cache/`, build output), confirm with the user before adding `--force`. The hardlinked `node_modules` is safe to lose — inodes survive in the main repo.

---

## Universal gotchas (apply to every Node repo)

| Symptom | Cause | Fix |
|---|---|---|
| API / app fails to start after fresh setup — env vars undefined | `.env*` files are gitignored and don't come with a fresh worktree | Step 4 auto-copies every gitignored `.env*` file from main. If main doesn't have it, the worktree won't either |
| `git worktree remove` says "Device or resource busy" or "directory is in use" | Dev server / Turbopack / vite still holds the directory | Run `pgrep -f "$WT" \| xargs kill` BEFORE `git worktree remove`. On Windows, `wmic process where "CommandLine like '%$WT%'" get ProcessId` + `taskkill //PID <pid> //F` |
| Workspace package errors (`Cannot find module '@scope/<pkg>/dist/...'`) at startup | Workspace package was built but its `dist/` was either (a) not copied or (b) gitignored so step 4's mirror misses it | If `dist/` is gitignored, rebuild that package in the worktree (`npm run build -w @scope/pkg`). Otherwise re-run step 2 — the hardlink copy missed a node_modules location |
| Pre-commit hooks fail with errors pointing at files not in the worktree | A hook resolves paths from `$CLAUDE_PROJECT_DIR` (main repo) instead of the worktree's git root | Either fix the hook to use `git rev-parse --show-toplevel` of the invoking shell, or do the corrective action (codegen, install, etc.) in **both** the main repo and the worktree |

## Common patterns (apply if your stack uses them)

| Stack feature | Gotcha | Fix |
|---|---|---|
| **Prisma** | `@prisma/client did not initialize yet` because the hardlinked client is from main's last schema | Step 5 detects `schema.prisma` and runs `prisma generate`. If you change `schema.prisma` later in the worktree, regenerate again |
| **Drizzle** | Stale generated types if `drizzle.config.*` has changed since the hardlink | Step 5 detects `drizzle.config.*` and runs `drizzle-kit generate` |
| **Next.js / Vite / CRA per-branch dev URLs** | `NEXT_PUBLIC_API_URL` / `VITE_API_URL` baked from main makes the worktree's web app talk to main's API | Step 6 strips `*_API_URL`, `*_BASE_URL`, `*_HOST*` from public env vars. Backup is saved at `<file>.worktree-backup` in case you need the original |
| **Reverse proxy with branch-prefix routing** (Portless, Caddy, etc.) | Only one instance of each named service can claim a route — last-started worktree wins, others get 502 | Run only one instance of each named service at a time. Stop the other worktree's dev process before starting this one |
| **Subagent-spawned worktrees** (Agent tool `isolation: "worktree"`) | The harness creates throwaway worktrees the agent manages — don't run this skill on those | This skill is for **persistent** worktrees the user works in across sessions, not Agent-isolated dispatches |

---

## When NOT to use this skill

- Quick read-only exploration — just `cd` into the main repo
- Agent dispatches with `isolation: "worktree"` (see table above)
- Windows: the `pgrep -f` step is POSIX-only. Use `wmic process where "CommandLine like '%$WT%'" get ProcessId` then `taskkill //PID <pid> //F` for the kill step

---

## Project-specific overlays

If your repo has additional setup steps that don't generalise (database seed scripts, secret rotation, specific port bindings, framework-specific dev-server invocation), document them in a project-local skill or in `CLAUDE.md` rather than editing this skill. Common overlays:

- **`/portless-dev`** (dain-os) — Portless reverse proxy verification + restart recipe
- **`/database-gotchas`** (dain-os) — ORM-side gotchas if `prisma generate` produces an unexpected client
- Project KB entries via your project's `mcp__*_search_knowledge_base` tool with `q: "worktree"`
