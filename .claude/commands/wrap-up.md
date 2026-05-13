---
description: End-of-session wrap-up: commit, push, link to DainOS product + tasks, write session context
argument-hint: [optional: summary override for session context]
---

# Wrap Up

End-of-session command. Commits all uncommitted work across all worktrees, pushes all branches, links the session to a DainOS product, matches and updates one or more DainOS tasks (with confirmation), and writes session context to DainOS Supabase.

**Run this LAST before ending a session.**

---

## Operator identity (one-time setup)

Before Step 1, check `~/.dain-os/wrap-up.json`. If absent OR missing `operator_iam_user_id`:

1. Query agency tenant users (the tenant that owns the dain-os product):

```sql
SELECT u.id, u.email, u.full_name, u.display_name
FROM iam.users u
JOIN core.tenants t ON t.id = u.tenant_id
WHERE t.slug = 'dain'  -- the agency tenant
  AND u.status = 'active'
ORDER BY u.full_name;
```

2. If exactly one row is returned, auto-select that row (no prompt). The agency tenant typically has a small fixed roster, so the n=1 case is common and a forced pick is pointless friction. Otherwise use `AskUserQuestion` to let the user pick themselves from the returned list.
3. Write the config:

```json
{
  "operator_iam_user_id": "<uuid>",
  "operator_email": "<email>",
  "operator_display_name": "<full_name>"
}
```

Save to `~/.dain-os/wrap-up.json` (create the directory if missing). Use this on every subsequent run.

---

## Step 1: Discover All Worktrees

```bash
git worktree list
```

Process each worktree (including the main working tree) in steps 2-4.

---

## Step 2: For Each Worktree - Check and Commit

### 2a. Check status

```bash
cd <worktree_path> && git status --short
```

If clean, skip to the next worktree.

### 2b. Group changes logically

```bash
git diff --stat HEAD
```

Group related changes into logical conventional commits: `feat(scope):`, `fix(scope):`, `chore(scope):`, `docs(scope):`.

### 2c. Commit each group

```bash
git add <files...>
git commit -m "<conventional commit message>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### 2d. Pre-commit hook failures

If a commit fails:
1. Trivial fix (unused import etc): fix and retry.
2. Otherwise ask via `AskUserQuestion`: "Pre-commit hook failed with: `<error>`. Commit with `--no-verify`, fix first, or skip this file?"
3. Only use `--no-verify` with explicit user approval.

---

## Step 3: Push All Branches

For each worktree:

```bash
cd <worktree_path> && git push origin <branch> 2>&1
```

If push is rejected (non-fast-forward):
1. `git pull --rebase origin <branch>`
2. If rebase has conflicts, ask the user. Do NOT force push.
3. Re-push after successful rebase.

---

## Step 4: Resolve the DainOS Product

For each worktree, identify the matching product:

### 4a. Extract repo identity

```bash
cd <worktree_path>
git remote get-url origin
```

Parse `github_owner` and `github_repo` from the URL (handles both `git@github.com:owner/repo.git` and `https://github.com/owner/repo` forms).

### 4b. Look up product(s)

A single repo can map to multiple products (e.g. `eoc-herbert` hosts both PEARL and HERBERT; `portunus-pipelines` hosts three pipeline products). Return all matches.

```sql
SELECT pr.product_id, pr.tenant_id,
       p.name AS product_name, p.company_id, p.is_portal_visible
FROM projects.product_repos pr
JOIN projects.products p ON p.id = pr.product_id
WHERE pr.github_owner = '<owner>' AND pr.github_repo = '<repo>'
ORDER BY p.name;
```

**If no row returned:**

Ask via `AskUserQuestion`: "No DainOS product is mapped to this repo (`<owner>/<repo>`). Skip task linking for this worktree, or register the repo?"

Options:
- "Skip task linking": leave `product_id = NULL` for this worktree's session context, continue to Step 7 (write session_context with no product/task links).
- "Register repo": list existing products in the agency tenant, let the user pick one (or pick "create new product"), then INSERT into `projects.product_repos` with the chosen `product_id`, `github_owner`, `github_repo`, `github_repo_id` (fetch from the GitHub API), `default_branch`, `is_private`.

**If exactly one row returned:** store `product_id`, `tenant_id`, `company_id` and continue.

**If multiple rows returned:** present them via `AskUserQuestion` (multiSelect: true) labelled `[product_name]` so the user picks which one(s) the session worked on. Store the picked product ids. Task matching in Step 5 must be scoped to projects under the picked product(s).

### 4c. Tenant consistency guard

Before any write in Step 7 / Step 8, assert that every picked product's `tenant_id` equals the operator's `tenant_id` (fetched in the operator-identity step from `iam.users.tenant_id`). If a mismatch is detected, STOP and surface the conflict to the user via `AskUserQuestion`. This almost always means a misconfigured repo mapping. Do NOT proceed with writes that span tenants.

The check is two independent reads + an in-skill equality assertion. Do NOT use a single CROSS JOIN query: when zero rows match it returns NULL, which a naive assertion treats as "no mismatch found" and silently passes.

```sql
-- 1) Operator's tenant. Returns exactly one row or zero (BLOCK if zero).
SELECT tenant_id AS operator_tenant
FROM iam.users
WHERE id = '<operator_iam_user_id>'::uuid;

-- 2) Distinct tenants across every picked product. Should be exactly one row,
--    matching operator_tenant. BLOCK if zero rows, multiple distinct rows, or
--    a single row that disagrees with operator_tenant.
SELECT DISTINCT tenant_id AS product_tenant
FROM projects.product_repos
WHERE product_id = ANY(ARRAY[<picked_product_ids>]::uuid[]);
```

**Pass criteria (all must hold):**
- Query 1 returns exactly one row.
- Query 2 returns exactly one row.
- The two tenant_id values are equal.

**Block conditions:**
- Query 1 returns zero rows → operator_iam_user_id is invalid / not in iam.users. Halt; ask user to re-run the operator-identity setup.
- Query 2 returns zero rows → picked product ids are invalid / not in product_repos. Halt; ask user to re-pick or skip task linking.
- Query 2 returns multiple rows → picked products span multiple tenants. Halt; ask user to narrow the selection.
- Single rows that disagree → operator and product belong to different tenants. Halt; this is the misconfigured-repo case the guard exists for.

### 4d. Note on `is_portal_visible`

The Step 4b query selects `p.is_portal_visible` for visibility context only. It does NOT gate whether the skill writes `description_client`. The skill always writes both internal and client descriptions when a task is linked. Whether the client actually sees the client description is governed by the product's portal-visibility flag, not by the wrap-up flow.

---

## Step 5: Match Tasks

Match one or more `projects.tasks` rows the session worked on.

### 5a. Collect signals

From this session, extract:
- **Task number refs in commit subjects:** scan commit subjects on the current branch (since branching from main) for `[A-Z]+-\d+` patterns (e.g. `PRD-008`, `DAIN-123`). Also scan for `fixes <ref>` or `closes <ref>` keywords. Flag these as completion candidates for Step 6.
- **File path domains:** map files in `git diff --name-only main..HEAD` to top-level folders like `apps/web/src/domains/<domain>/*` and `apps/api/src/domains/<domain>/*`.
- **Commit-scope tags:** extract scopes from conventional commit messages (`feat(finance):` → `finance`).
- **Branch name:** the slugified text after the type prefix (`fix/finance-pnl-zero-edit-and-utc-dates` → tokens `finance`, `pnl`, `zero-edit`, `utc-dates`).

### 5b. Query candidate tasks

```sql
WITH operator AS (
  SELECT '<operator_iam_user_id>'::uuid AS uid
),
explicit_refs AS (
  -- Task numbers parsed from commits (highest confidence)
  SELECT id FROM projects.tasks
   WHERE tenant_id = '<tenant_id>'
     AND task_number = ANY(ARRAY[<extracted_task_numbers>])
),
recent_open AS (
  -- Open tasks the operator owns or has touched recently, under this product (or any picked product if multiple)
  SELECT t.id
  FROM projects.tasks t
  LEFT JOIN projects.projects pj ON pj.id = t.project_id
  WHERE t.tenant_id = '<tenant_id>'
    AND t.status NOT IN ('done', 'cancelled', 'production_ready')
    AND (t.assignee_id = (SELECT uid FROM operator)
         OR t.reporter_id = (SELECT uid FROM operator))
    AND (pj.product_id = ANY(ARRAY[<picked_product_ids>]::uuid[]) OR t.project_id IS NULL)
  ORDER BY t.updated_at DESC
  LIMIT 10
)
SELECT t.id, t.task_number, t.title, t.status, t.assignee_id, t.start_date,
       t.actual_hours, t.project_id, pj.name AS project_name,
       (t.id IN (SELECT id FROM explicit_refs)) AS matched_explicitly
FROM projects.tasks t
LEFT JOIN projects.projects pj ON pj.id = t.project_id
WHERE t.id IN (SELECT id FROM explicit_refs)
   OR t.id IN (SELECT id FROM recent_open);
```

### 5c. Present candidates

- If `explicit_refs` returned tasks, pre-select those (high confidence).
- Otherwise show top 5 from `recent_open` sorted by `updated_at DESC`.
- Use `AskUserQuestion` (multiSelect: true) with each candidate as an option labelled `[task_number] title (project_name, status)`.
- Allow "None of these" / "Create new task" branches:
  - "None of these": log session_context with `product_id` set but `task_ids = '{}'`, skip to Step 7.
  - "Create new task": ask for: title, project (pick from active projects under the product, or NULL), initial status (default `in_progress`). INSERT a new `projects.tasks` row with `tenant_id`, `project_id`, `title`, `status`, `assignee_id = operator_iam_user_id`, `reporter_id = operator_iam_user_id`, `start_date = <conversation_start_date>`. Omit `priority_score` so the column default (50) fires; do NOT pass 0. Add the returned id to the linked set.

Store the final array of selected task ids as `linked_task_ids`.

---

## Step 6: Propose Field Updates & Confirm

For each task in `linked_task_ids`, build a proposed update.

### 6a. Per-task descriptions (D6)

For each task, identify which commits and which files were primarily about that task. Heuristics:
- If `task_number` appears in a commit subject, that commit's diff is scoped to this task.
- Otherwise, attribute commits whose conventional-commit scope matches the task's project area, or whose files overlap with files modified by other commits already attributed to this task.

Draft two descriptions per task:

**`description` (internal, technical, for Jack and Dane):**
- Reference specific files, functions, schema changes.
- Note technical decisions and trade-offs.
- Mention edge cases handled or deferred.
- Length: 4-10 lines. Markdown allowed.

**`description_client` (client-facing, plain English):**
- Frame as problem → outcome → benefit.
- No file paths, no function names, no commit hashes.
- UK English. No em dashes (see `.claude/rules/copy-style.md`).
- Length: 2-4 sentences. Plain text.

### 6b. Per-task field proposal (D5)

For each task, propose:

| Field | Rule |
|---|---|
| `description` | APPEND a new section: `\n\nSession <session_date>\n\n<drafted internal>` |
| `description_json` | APPEND two Plate paragraph nodes (heading-text + body). MUST be written alongside `description` because Task Detail UI reads `description_json` first (`apps/web/src/domains/projects/components/task-detail/task-detail-body.tsx:54`, helper at `apps/web/src/domains/projects/hooks/use-enrichment-commit.ts:20`). |
| `description_client` | If currently NULL → set to drafted client copy. If non-null → APPEND `\n\nSession <session_date>\n\n<drafted client>`. |
| `description_client_json` | If currently NULL → set to one Plate paragraph node containing the drafted client copy. If non-null → APPEND two Plate paragraph nodes (heading-text + body). Same UI-rendering rationale as `description_json`. |
| `start_date` | Only set if currently NULL → conversation start date. |
| `status` | Propose `in_progress` if currently `todo`/`backlog`/`blocked`. Propose `done` if a commit subject contained `fixes <task_number>` or `closes <task_number>` (D7 auto-mark). Leave `review` and `production_ready` unchanged unless user overrides. Valid `task_status` values: `backlog`, `todo`, `in_progress`, `review`, `blocked`, `done`, `cancelled`, `production_ready`. |
| `completed_at` | Only when proposed status is `done` → NOW(). |
| `completed_by` | Only when proposed status is `done` → `operator_iam_user_id`. |
| `actual_hours` | INCREMENT by `(<session_duration_minutes> / 60) / <count_of_linked_tasks>` (even split, D5). |
| `assignee_id` | Never auto-change (D5). |
| `due_date` | Never auto-set (D5). |
| `updated_at` | NOW() (handled by `@updatedAt` if present, else explicit). |

**Plate paragraph node shape:** every node is `{ "type": "p", "children": [{ "text": "<content>" }] }`. This matches the codebase pattern in `descriptionToPlateValue` (`use-enrichment-commit.ts`). Stick to `p` nodes; do NOT introduce `h2`/`h3` types unless you've verified they render in Task Detail's Plate config.

### 6c. Human gate review (mandatory)

**Before any DB write in Step 7, recall every material field back to the user in a structured block.** This is the equivalent of the tenant-guard line from Step 4c: the user should be able to read what's about to happen and stop you. Do NOT collapse this into a single "Create new task" prompt. Show the whole proposed shape.

For EACH task in `linked_task_ids` (whether new or existing), render this block verbatim before prompting:

```
About to write to projects.tasks:

  Product       Dain-OS (<owner>/<repo>)
  Project       <project_name>            (id: <project_id_or_NULL>)
  Task          [<task_number_or_TASK-NEW>] <title>
                <new | existing>

  Assignee      <assignee_full_name>      (iam_user_id: <uuid>)
  Reporter      <reporter_full_name>      (iam_user_id: <uuid>)

  Status        <current> → <proposed>     (auto-flip from "fixes/closes" commit? Y/N)
  Start date    <current> → <proposed>
  Completed at  <proposed_NOW_or_unchanged>
  Hours         actual_hours += <allocated_h> (session minutes <duration> / linked tasks <n>)

  Internal description (description / description_json)
  ----
  <first 400 chars of drafted internal copy>
  ----

  Client description (description_client / description_client_json)
  ----
  <first 400 chars of drafted client copy>
  ----
```

Then use `AskUserQuestion`:
- Question: `Apply the above to [<task_number>] <title>?`
- Options:
  - `Apply as proposed`: proceeds to Step 7.
  - `Edit a field`: re-prompts for which field (status, assignee, hours split, internal copy, client copy, project, title for new tasks). Apply edits, re-render the same block, ask again. Loop until applied or skipped.
  - `Skip this task`: drop from `linked_task_ids`, do not write.
  - `Mark complete instead`: only shown if proposed status is not already `done`. Sets status = `done`, completed_at = NOW(), completed_by = operator. Re-render the block, ask again.

**Multi-task sessions:** ask once per task. Do NOT batch confirm "all tasks" into one prompt. Each task's block + AskUserQuestion is its own gate.

**No silent defaults.** If any field in the block is blank or `<...>`, STOP and surface that the proposal is incomplete. Never proceed with a partially-filled write.

---

## Step 7: Write the Task Updates

Wrap all task UPDATEs in a single transaction.

```sql
BEGIN;

-- Repeat per task in linked_task_ids:
UPDATE projects.tasks
SET description = COALESCE(description, '') || E'\n\nSession <YYYY-MM-DD>\n\n<internal>',
    description_json = COALESCE(description_json, '[]'::jsonb) || jsonb_build_array(
      jsonb_build_object(
        'type', 'p',
        'children', jsonb_build_array(jsonb_build_object('text', 'Session <YYYY-MM-DD>'))
      ),
      jsonb_build_object(
        'type', 'p',
        'children', jsonb_build_array(jsonb_build_object('text', '<internal>'))
      )
    ),
    description_client = CASE
      WHEN description_client IS NULL THEN '<client>'
      ELSE description_client || E'\n\nSession <YYYY-MM-DD>\n\n<client>'
    END,
    description_client_json = CASE
      WHEN description_client_json IS NULL THEN
        jsonb_build_array(
          jsonb_build_object(
            'type', 'p',
            'children', jsonb_build_array(jsonb_build_object('text', '<client>'))
          )
        )
      ELSE description_client_json || jsonb_build_array(
        jsonb_build_object(
          'type', 'p',
          'children', jsonb_build_array(jsonb_build_object('text', 'Session <YYYY-MM-DD>'))
        ),
        jsonb_build_object(
          'type', 'p',
          'children', jsonb_build_array(jsonb_build_object('text', '<client>'))
        )
      )
    END,
    start_date = COALESCE(start_date, '<conversation_start_date>'::date),
    status = '<proposed_status>',
    completed_at = CASE WHEN '<proposed_status>' = 'done' THEN NOW() ELSE completed_at END,
    completed_by = CASE WHEN '<proposed_status>' = 'done' THEN '<operator_iam_user_id>'::uuid ELSE completed_by END,
    actual_hours = actual_hours + <allocated_hours>,
    updated_at = NOW()
WHERE id = '<task_id>'
  AND tenant_id = '<tenant_id>';

COMMIT;
```

**Why both text and jsonb columns:** Task Detail UI reads `description_json` first and only falls back to `description` when the jsonb is null (`task-detail-body.tsx:54`). Writing only the text column would leave the appended session notes invisible in the UI for any task whose `description_json` is already populated.

If the transaction fails, ROLLBACK and report the error to the user. Do NOT retry without confirmation.

**Escape all string literals.** Use `$$ ... $$` dollar quoting for any description bodies that contain quotes or backslashes.

---

## Step 8: Write Session Context

INSERT one row into `developer.session_context`. Reuse all existing columns plus the new ones.

Resolve `<machine hostname>` by running `hostname` in the shell first:

```bash
hostname
```

Use the captured value (e.g. `kramb-desktop`) in the INSERT below. Do NOT leave the placeholder unfilled.

### 8a. Recall before insert

Before running the INSERT, render this block and ask for confirmation:

```
About to write to developer.session_context:

  Session name   <descriptive session name>
  Session date   <YYYY-MM-DD>
  Operator       <operator_display_name> (<email>)  iam_user: <uuid>
  Model          <model name e.g. claude-opus-4.7>
  Machine        <resolved hostname>
  Duration       <estimated minutes> minutes
  Product        <product_name>                     id: <product_id_or_NULL>
  Linked tasks   <count>                            <task_number list>

  Summary (first 400 chars)
  ----
  <truncated summary>
  ----

  Decisions      <count> decision(s) recorded
  Files touched  <count>
  Tags           <comma-joined tags>
```

Then `AskUserQuestion`:
- Question: `Write this session_context row?`
- Options: `Write it`, `Edit the summary first`, `Cancel session_context write`.

If "Cancel session_context write" is chosen, the task writes from Step 7 are NOT rolled back; only the session_context row is skipped. Tell the user explicitly that the session is now untracked but the task updates already landed.

```sql
INSERT INTO developer.session_context (
  project, session_name, session_date, operator, machine, duration_minutes,
  summary, decisions_made, handoff_notes, files_touched, tasks_completed, blockers, tags,
  product_id, task_ids, operator_iam_user_id
) VALUES (
  '<project_slug>',                       -- free-text repo/product slug (existing convention)
  '<descriptive session name>',
  '<today YYYY-MM-DD>',
  '<model name e.g. claude-opus-4.7>',
  '<resolved hostname from `hostname` shell call>',
  <estimated minutes>,
  $session_summary$<summary>$session_summary$,
  '<decisions JSON array>'::jsonb,
  '<handoff notes JSON object>'::jsonb,
  ARRAY[<files>],
  ARRAY[<task_titles_completed_text>],
  ARRAY[<blockers>],
  ARRAY[<tags>],
  '<product_id_or_NULL>'::uuid,
  ARRAY[<linked_task_ids>]::uuid[],
  '<operator_iam_user_id>'::uuid
);
```

If `product_id` was not resolved (Step 4 returned no row and user chose "Skip"), pass `NULL`.

---

## Step 9: Report

Present a concise summary:

```
# Session Wrapped Up

## Commits
| Worktree | Branch | Commits | Status |
|----------|--------|---------|--------|
| main     | <branch> | 3       | pushed |

## Product
<product_name> (<owner>/<repo>) - session_context.product_id = <uuid>

## Tasks Updated
| Task | Status | Hours | Internal Δ | Client Δ |
|------|--------|-------|------------|----------|
| [TASK-1] Title | in_progress → done | +1.5h | appended | set |
| [TASK-2] Title | in_progress | +1.5h | appended | appended |

## Session Context
Written to DainOS. Session: "<session_name>" (id: <uuid>)

## Remaining
- <any untracked files or unresolved blockers>
```

---

## Rules

1. **Never force push** without explicit user approval.
2. **Never skip hooks** without asking. Use `AskUserQuestion`.
3. **Group commits logically.** Don't dump everything into one commit.
4. **Conventional commit format** is mandatory.
5. **Co-Authored-By trailer** on every commit.
6. **ARRAY[] syntax** for Postgres arrays, not JSON.
7. **Task writes are transactional.** All linked task UPDATEs go in one `BEGIN; ... COMMIT;` block.
8. **Never auto-change `assignee_id` or `due_date`.** Those require explicit user input.
9. **`description_client` is plain English.** No file paths, no commit hashes, no technical jargon.
10. **UK English** in `description_client` and no em dashes. See `.claude/rules/copy-style.md`.
11. `.worktrees/` directory is always untracked. Ignore it.
12. If `~/.dain-os/wrap-up.json` is missing on a fresh machine, the operator-identity setup runs once before any wrap-up writes.
