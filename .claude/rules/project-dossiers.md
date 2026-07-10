# Project Dossiers (session orientation)

One dossier per active DainOS project, stored in `developer.project_dossiers`.
A SessionStart hook injects a compact index (slug, aliases, headline, freshness)
into every session in a registered repo. When the user's prompt names an
initiative matching a dossier slug or alias, run `~/.dain-os/bin/dossier show
<slug>` FIRST — before any code exploration, recap, or glob/grep.

## Contract

- **Index ≤ 500 tokens; body ≤ 2,500 tokens.** The body is a snapshot, not a
  log: /wrap-up rewrites it in place. History lives in session_context.
- **key_files is paths + one-liners ONLY** — lightweight identifiers the
  session resolves just-in-time. Never paste file content into a dossier.
- **Mechanical fields are executor-owned** (task_counts, recent_prs,
  last_code_activity_at — refreshed nightly by dossier_mechanical_refresh).
  Never write them from wrap-up or by hand.
- **Staleness is self-announcing:** narrative older than code activity by >3
  days renders a STALE banner. Trust the mechanical footer over a stale
  narrative, and update the dossier at wrap-up.
- **Sub-agents do not inherit injected context.** When spawning workers for an
  initiative, paste the dossier body (or `dossier show <slug>` instruction)
  into each worker prompt.
- In-session access: MCP resource `project_dossiers` (query: list requires a
  repo filter, get by slug; writes via `mutate` operation `'create'` — create
  IS the slug-keyed upsert; there is no update operation).

## Install (per repo, once)

Append to the repo's SessionStart hook (see eoc-herbert
`.claude/hooks/session-start.sh` for the reference block): derive the repo
name from `git remote get-url origin` (NEVER the directory basename — worktree
dirs are named after branches) and run `~/.dain-os/bin/dossier index --repo
<repo>`. Per machine: copy `dain-os/scripts/dossier/{dossier.mjs,lib.mjs}` to
`~/.dain-os/bin/`, add the `dossier` wrapper, chmod +x, and put a
`dain_pat_...` token in `~/.dain-os/config.json`.
