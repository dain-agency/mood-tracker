---
description: Session startup recap — pull recent session context, changelog, and DainOS task status to ground a fresh session in any repo
argument-hint: [optional: "deep" for 7 days, a project slug to override, or free-text scope]
---

# Recap: $ARGUMENTS

Session startup command. Auto-detects the active project from `git remote` and pulls three persistence layers so you can start working immediately without re-exploring the codebase.

**YOU ARE A READER, NOT A DOER.** Gather context, synthesise it, present a concise briefing. No writes, no commits, no migrations.

---

## Data sources (fallback chain)

For every read, prefer this order. Skip to the next tier only if the higher tier is unavailable or doesn't expose the data you need.

1. **DainOS MCP** (`mcp__dainos__*`) — preferred when available. Cross-project, no Supabase token needed, portable across MCP clients.
2. **Supabase MCP** (`mcp__claude_ai_Supabase__execute_sql`) with project_id `nkwxprrhkifxoeqwvnpu` — fallback for tables not yet exposed via the DainOS MCP.
3. **Supabase CLI** (`supabase db ...`) — last resort, e.g. when running offline or against a local stack.

The DainOS MCP covers every read this skill needs as of 2026-05-18. Tier 2/3 fallbacks are only relevant when the MCP itself is unavailable.

---

## Step 0: Parse arguments and resolve dates

`$ARGUMENTS` is a free bag of tokens. Extract three slots, any of which may be omitted:

- **Window**: `deep` → 7 days; a duration token (`3d`, `1w`, `24h`); an absolute date (`2026-05-10`). Default: today + yesterday.
- **Project slug override**: a known slug like `eoc-herbert`, `mabel`, `dain-os`, `portunus-pipelines`. If present, skip Step 1.
- **Scope keywords**: anything left over. Split on spaces/commas/dashes/slashes, lowercase, dedupe, drop stop-words. Used to narrow session_context and changelog queries.

```
today      = current date (YYYY-MM-DD)
start_date = today - {window in days}
```

---

## Step 1: Resolve the active project

If `$ARGUMENTS` contained an explicit project slug, use it and skip the rest of this step.

Otherwise, parse `git remote get-url origin` for `<owner>/<repo>` (handle both `git@github.com:owner/repo.git` and `https://github.com/owner/repo` forms), then look up the product via the DainOS MCP:

```
mcp__dainos__lookup_product_repos({ owner: "<owner>", repo: "<repo>" })
```

Returns an array of `{ productId, tenantId, productName, companyId, isPortalVisible }`.

- **Zero rows** — fall back to the repo name as the project slug (e.g. `eoc-herbert`). Note this in the briefing so the user knows the lookup missed.
- **One row** — set `project_slug = <repo>` (the developer schema uses repo slugs, not product UUIDs), capture `productId` for the task query in Step 4.
- **Multiple rows** — capture all `productId` values, set `project_slug = <repo>`. The repo hosts more than one product; the briefing should mention which.

---

## Step 2: Recent sessions

Prefer the DainOS MCP:

```
mcp__dainos__list_recent_sessions({ project: "<project_slug>", limit: 10 })
```

Filter the returned rows client-side to those with `session_date >= start_date`. If the MCP is unavailable, fall back to SQL:

```sql
SELECT id, session_name, session_date, operator, machine, duration_minutes,
       summary, decisions_made, handoff_notes, files_touched, tasks_completed,
       blockers, tags, created_at
FROM developer.session_context
WHERE project = '<project_slug>'
  AND session_date >= '<start_date>'::date
ORDER BY created_at DESC;
```

If scope keywords were supplied, narrow with an OR across `tags` (use `tags && ARRAY[...]`) and `session_name`/`summary` (use `ILIKE ANY`). If the scoped query returns zero rows, surface that and offer to re-run without scope.

If no sessions in the window, note "No session context recorded in this period" and move on. Do **not** treat this as silent — it usually means /wrap-up was skipped.

---

## Step 3: Recent commits

```
mcp__dainos__list_changelog({ project: "<project_slug>", since: "<start_date ISO>", limit: 200 })
```

Returns full changelog rows (camelCase: `commitSha`, `commitType`, `committedAt`, `prNumber`, `prUrl`, etc.) ordered by `committedAt` DESC.

If empty, note it — combined with an empty Step 2 it usually means the changelog ingestor isn't running for this project.

Apply scope keywords client-side across `tags`, `scope`, `summary` if supplied.

---

## Step 4: Task status (replaces the old Notion fetch)

If Step 1 resolved one or more `productId` values, summarise the project's task pipeline. For each productId:

```
mcp__dainos__summarise_product_tasks({ productId: "<uuid>" })
```

Returns `{ statusCounts: { backlog, todo, in_progress, review, production_ready, blocked, done, cancelled }, activeTasks: Array<{ id, taskNumber, title, status, assigneeId, projectName, updatedAt, completedAt }> }`. The active list is server-capped to 20 rows ordered by status then `updatedAt` DESC, and includes any `done` tasks completed within the last 7 days.

If Step 1 returned multiple productIds, call the tool once per id and merge counts client-side; otherwise it's one call.

If you have a known assignee UUID for the operator (cached from a previous /wrap-up at `~/.dain-os/wrap-up.json`), highlight the operator's in-progress tasks in the activeTasks list.

If Step 1 returned zero product matches, skip this step entirely — the project isn't registered with DainOS yet.

---

## Step 5: Local git state

```bash
git branch --show-current
git log --oneline -5
git status --short
git worktree list
```

Quick check only. Don't dive into diffs.

---

## Step 6: Synthesise and present

```
# Session Recap — <project_slug> · <window label>

## Recent Sessions (<n>)
For each session: **date  session_name** (operator)
  1–2 line summary
  Key decisions: <bulleted>
  Handoff: <handoff_notes if non-empty>
  ---

## Recent Commits (<n>)
| Date | Type(Scope) | Summary | Branch | PR |

## Tasks
| Status | Count |
|--------|-------|
| Done (in window) | <n> |
| In review | <n> |
| In progress | <n> |
| Blocked | <n> |

**Active work:**
- [TASK-N] Title (project, assignee)

**Recently completed:**
- [TASK-N] Title

## Local State
- Branch: <current>
- Last commit: <sha + subject>
- Working tree: <clean | n modified>
- Worktrees: <list if more than one>

## Handoff Notes
<Quoted handoff_notes from the most recent session — this is the most important section for continuity.>

## Open Blockers
<From session blockers + handoff notes. Skip the section entirely if empty.>
```

If Step 1 fell back to the bare repo slug (no product match), prefix the briefing with a one-line note: "Project not registered with DainOS — running on repo-name fallback. Register via /wrap-up to enable task summary."

---

## Rules

1. **Read only.** Never write to any table, commit anything, or call MCP tools that mutate state.
2. **Be concise.** Synthesise, don't dump. Aim for a screen of output, not a wall.
3. **Highlight blockers and stale handoffs.** If the most recent session is more than 3 days old, call that out.
4. **Flag empty persistence layers.** If session_context is empty for a project that was clearly worked on (git commits in window, but no /wrap-up rows), warn the user — they probably skipped /wrap-up.
5. **Run Steps 2–5 in parallel** where the tooling allows (independent reads).
6. **Don't fetch Notion.** Task status comes from DainOS now. Notion-backed projects fall through to the "no product registered" path.
