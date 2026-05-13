---
description: Session startup recap — pull recent session context, changelog, and Notion status to ground a fresh session
argument-hint: [optional: "deep" for 7 days instead of 2]
---

# Recap: $ARGUMENTS

Session startup command. Pulls context from three persistence layers so you can start working immediately without re-exploring the codebase.

**YOU ARE A READER, NOT A DOER.** Gather context, synthesise it, and present a concise briefing. Do not make any changes.

---

## Step 0: Determine Date Range

Get the current date and time. Default range is **today + yesterday**. If `$ARGUMENTS` contains "deep", extend to **7 days**.

```
today     = current date (YYYY-MM-DD)
yesterday = today - 1 day
deep_start = today - 7 days (only if "deep" mode)
```

Use the appropriate start date for all queries below.

---

## Step 1: Session Context (DainOS Supabase)

Query `developer.session_context` on **DainOS Supabase project `nkwxprrhkifxoeqwvnpu`** for recent sessions on this project.

```sql
SELECT session_name, session_date, operator, machine, duration_minutes, summary, decisions_made, handoff_notes, files_touched, tasks_completed, blockers, tags, created_at
FROM developer.session_context
WHERE project = 'eoc-herbert'
  AND session_date >= '{start_date}'::date
ORDER BY created_at DESC;
```

If no results, note "No session context recorded in this period" and move on.

---

## Step 2: Changelog (DainOS Supabase)

Query `developer.changelog` on **DainOS Supabase project `nkwxprrhkifxoeqwvnpu`** for recent commits.

```sql
SELECT commit_sha, branch, commit_type, scope, summary, description, files_changed, insertions, deletions, milestone, task_ref, tags, committed_at, pr_number, pr_url
FROM developer.changelog
WHERE project = 'eoc-herbert'
  AND committed_at >= '{start_date}'::date
ORDER BY committed_at DESC;
```

If `committed_at` has no data, fall back to filtering on `created_at` instead.

If no results, note "No changelog entries in this period" and move on.

---

## Step 3: Notion Project Status

Fetch the Herbert ERP project from Notion to understand current task status.

**Project page:** `https://www.notion.so/32351000c58981319be1e092a36fac93`
**Task board view:** `https://www.notion.so/dain-consulting/Herbert-ERP-32351000c58981319be1e092a36fac93?v=2ea51000c5898069aef7000cdfeb24d9`

Use the Notion MCP tools:

1. **Fetch the project page** to get the list of Milestones (linked page IDs).
2. **Fetch the task board view** (the `?v=` URL) to get the data source / database with task statuses.
3. From the tasks, extract:
   - Count by status (Backlog, In Progress, Ready for Testing/Review, Done, Blocked)
   - Tasks currently In Progress (who's working on what)
   - Tasks recently moved to Done (last 2 days)
   - Backlog tasks that appear ready to claim (dependencies met if identifiable)

**Keep it light.** Don't fetch every task page individually — use the database view to get status counts. Only fetch individual task pages if you need to check specific handoff details.

---

## Step 4: Git State

Quick check of the local repository state:

```bash
git branch --show-current
git log --oneline -5
git status --short
```

Also check if there are any open worktrees:
```bash
git worktree list
```

---

## Step 5: Synthesise and Present

Combine everything into a structured briefing. Use this exact format:

```
# Session Recap — {date} {time}

## Recent Sessions
{For each session context entry, show: session name, 1-2 line summary, key decisions, handoff notes}
{If none: "No session context recorded."}

## Recent Commits
{Table: date | type(scope) | summary | branch}
{If none: "No changelog entries."}

## Project Status
| Status | Count |
|--------|-------|
| Done | {n} |
| Ready for review | {n} |
| In progress | {n} |
| Backlog | {n} |

**Currently in progress:**
{List tasks with assignee if available}

**Recently completed:**
{Tasks moved to Done in the date range}

**Ready to claim:**
{Backlog tasks with dependencies met, if identifiable}

## Local State
- Branch: {current branch}
- Last commit: {sha + message}
- Working tree: {clean / N modified files}
- Worktrees: {list if any}

## Handoff Notes
{The most recent session's handoff notes, highlighted — this is the most important section for continuity}
```

---

## Rules

1. **Read only.** Never create files, make commits, or update Notion during recap.
2. **Be concise.** The whole point is to save tokens. Don't dump raw SQL results — synthesise.
3. **Highlight blockers.** If handoff notes mention blockers or urgent items, call them out prominently.
4. **Flag staleness.** If session context or changelog is empty, warn that persistence may not be working — sessions should always write these.
5. **Use the Supabase MCP `execute_sql` tool** with project_id `nkwxprrhkifxoeqwvnpu` for both SQL queries. Do NOT use the Herbert project (`fzpmdnoxqfroznyvlrte`) — the developer tables are on DainOS.
6. **Run Steps 1-4 in parallel** where possible to minimise latency.
