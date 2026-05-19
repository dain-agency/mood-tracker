---
description: End-of-session wrap-up: commit, push, link to DainOS product + tasks, write session context
argument-hint: [optional: summary override for session context]
---

# Wrap Up

End-of-session command. Commits all uncommitted work across all worktrees, pushes all branches, links the session to a DainOS product, matches and updates one or more DainOS tasks (with confirmation), and writes session context to DainOS.

**Run this LAST before ending a session.**

---

## Data sources (fallback chain)

For every read and write, prefer this order. Skip to the next tier only if the higher tier is unavailable or doesn't expose the column/operation you need.

1. **DainOS MCP** (`mcp__dainos__*`) — preferred when available. Cross-project, no Supabase token needed, portable across MCP clients.
2. **Supabase MCP** (`mcp__claude_ai_Supabase__execute_sql`) with project_id `nkwxprrhkifxoeqwvnpu` — fallback for tables and columns the DainOS MCP doesn't yet expose.
3. **Supabase CLI** (`supabase db ...`) — last resort, e.g. when running offline or against a local stack.

**Where each tier applies in this skill** (as of 2026-05-18, after the MCP extension wave):

| Step | DainOS MCP tool | Notes |
|------|-----------------|-----|
| Operator identity | `list_tenant_users({ status: 'active' })` | Returns users in caller's tenant only — no `tenantSlug` arg needed |
| 3.5. Log commits | `log_changelog_entry({ project, entries: [...] })` | Batch insert (up to 50/call), idempotent on `(project, commit_sha)`. Safe to call even if a CI hook also writes — duplicates are silently skipped |
| 4b. Product lookup | `lookup_product_repos({ owner, repo })` | Returns `[{ productId, tenantId, productName, companyId, isPortalVisible }]` |
| 4c. Tenant guard | `get_user({ id })` + `lookup_product_repos` | Compare `user.tenantId` against each product's `tenantId` client-side |
| 5b. Candidate task query | — | Still uses SQL: the WITH-CTE explicit-refs + recent-open join across all projects under a product has no single-call MCP equivalent. `summarise_product_tasks` returns aggregates, not the full per-task signal-matched list |
| 5c. Create new task | `create_task` | Server fills `priority_score` default; takes `title, projectId, status, assigneeId, reporterId, startDate` |
| 6/7. Task UPDATE | `update_task` covers everything | Now exposes `descriptionClient`, `descriptionJson`, `descriptionClientJson`, `actualHoursDelta` (additive), `completedAt`, `completedBy`. Use `complete_task` only for the status state-machine walk. **One MCP call per task — no transactional batch**. If you need all-or-nothing semantics across multiple tasks, drop to SQL with `BEGIN; ... COMMIT;` instead. |
| 7.5. PR review feedback | `list_unscored_pr_findings({ repo, prNumber, scoredBy })` + `score_pr_finding({ findingId, verdict, scoredBy, notes?, reviewerVersion? })` | Verdict enum: `useful \| noise \| wrong`. 409 on duplicate — don't retry. |
| 8. session_context INSERT | `log_session_context` covers everything | Now exposes `productId`, `taskIds`, `operatorIamUserId`. |

Supabase MCP / CLI is only needed for Step 5b's cross-product query and for the transactional task-UPDATE batch in Step 7 (when explicit ALL-OR-NOTHING semantics are required across multiple tasks).

---

## Operator identity (one-time setup)

Before Step 1, check `~/.dain-os/wrap-up.json`. If absent OR missing `operator_iam_user_id`:

1. Query users in the caller's tenant via the MCP:

```
mcp__dainos__list_tenant_users({ status: "active" })
```

Returns `[{ id, email, fullName, displayName, status, tenantId }, ...]` ordered by fullName. The endpoint always scopes to the caller's own tenant (no `tenantSlug` param) — so when the operator is signed in as their own user, the result is the agency tenant's roster.

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

## Step 3.5: Log Commits to the Developer Changelog

For each branch pushed in Step 3, persist its commits to `developer.changelog`. /recap reads this table in its Step 3, so a skipped log step means recap shows fewer commits than were actually shipped. The MCP call is idempotent on `(project, commit_sha)` so re-runs are safe; this makes it harmless to call even when a CI hook may also be writing to the same table.

### 3.5a. Enumerate commits per worktree

For each (worktree, branch) you pushed, list every commit on the branch since main:

```bash
cd <worktree_path>
git log --pretty='format:%H%x09%ci%x09%an%x09%s' origin/main..HEAD
```

Output is tab-separated: `<full_sha>\t<iso_committed_at>\t<author>\t<subject>`.

If the branch has no clear merge base (e.g. detached HEAD, freshly cloned), fall back to `git log --pretty='...' -50` and trust idempotency to skip duplicates.

### 3.5b. Parse each commit

For each row:

- **`commit_type`**: parse from a conventional-commit subject. `feat(scope): subject` → `feat`. `feat: subject` → `feat`. Unconventional subject → `chore` (defensive default). Valid types: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `perf`, `ci`, `build`, `revert`, `style`.
- **`scope`**: the `(...)` group in the subject, or `null` if absent.
- **`summary`**: the subject minus the type/scope prefix.
- **`pr_number`**: parse trailing `(#NNNN)` in the merge-commit subject. If absent, run `gh pr list --search "<sha>" --json number --limit 1` and parse. Omit if still unknown.
- **`task_ref`**: parse `[A-Z]+-\d+` from the commit body via `git log -1 --format=%B <sha>`. Omit if absent.
- **`pr_url`**: derive from `pr_number` + the repo: `https://github.com/<owner>/<repo>/pull/<pr_number>`. Omit if `pr_number` is unknown.

### 3.5c. Batch and write

Group entries by **project slug** (= the `github_repo` name from `git remote get-url origin`). Different project slugs need separate MCP calls.

For each project slug, batch entries in chunks of 50 (the tool's max) and call:

```
mcp__dainos__log_changelog_entry({
  project: "<project_slug>",
  entries: [
    {
      commit_sha: "<full_40_char_sha>",
      branch: "<branch>",
      commit_type: "feat",
      scope: "api",
      summary: "add foo to bar",
      committed_at: "<iso_8601>",
      author: "Dane",
      pr_number: 317,
      pr_url: "https://github.com/dain-agency/dain-os/pull/317",
      task_ref: "PRD-080"
    },
    ...
  ]
})
```

The tool returns `{ inserted, skipped }`. `skipped` counts existing `(project, commit_sha)` rows — that's expected when the CI hook ran first, or when you re-run wrap-up on the same session.

### 3.5d. Report

Add to the Step 9 summary block:

```
## Changelog
| Project | Branch | Inserted | Skipped (dupes) |
|---------|--------|----------|-----------------|
| dain-os | feat/foo | 7 | 1 |
| eoc-herbert | fix/bar | 3 | 0 |
```

(Omit the section if no branches were pushed in Step 3.)

---

## Step 4: Resolve the DainOS Product

For each worktree, identify the matching product.

### 4a. Extract repo identity

```bash
cd <worktree_path>
git remote get-url origin
```

Parse `github_owner` and `github_repo` from the URL (handles both `git@github.com:owner/repo.git` and `https://github.com/owner/repo` forms).

### 4b. Look up product(s)

A single repo can map to multiple products (e.g. `eoc-herbert` hosts both PEARL and HERBERT; `portunus-pipelines` hosts three pipeline products). Return all matches.

```
mcp__dainos__lookup_product_repos({ owner: "<owner>", repo: "<repo>" })
```

Returns `[{ productId, tenantId, productName, companyId, isPortalVisible }, ...]`.

**If empty array:**

Ask via `AskUserQuestion`: "No DainOS product is mapped to this repo (`<owner>/<repo>`). Skip task linking for this worktree, or register the repo?"

Options:
- "Skip task linking": leave `product_id = NULL` for this worktree's session context, continue to Step 8 (write session_context with no product/task links).
- "Register repo": list existing products in the tenant (no MCP tool for `projects.products` enumeration yet — use SQL `SELECT id, name FROM projects.products WHERE tenant_id = <caller_tenant>`), let the user pick one (or pick "create new product"), then INSERT into `projects.product_repos` with the chosen `product_id`, `github_owner`, `github_repo`, `github_repo_id` (fetch from the GitHub API), `default_branch`, `is_private`.

**If exactly one row returned:** store `productId`, `tenantId`, `companyId` and continue.

**If multiple rows returned:** present them via `AskUserQuestion` (multiSelect: true) labelled `[productName]` so the user picks which one(s) the session worked on. Store the picked productIds. Task matching in Step 5 must be scoped to projects under the picked product(s).

### 4c. Tenant consistency guard

Before any write in Step 7 / Step 8, assert that every picked product's `tenantId` equals the operator's `tenantId`. If a mismatch is detected, STOP and surface the conflict to the user via `AskUserQuestion`. This almost always means a misconfigured repo mapping. Do NOT proceed with writes that span tenants.

The check is two independent MCP reads + an in-skill equality assertion:

```
// 1) Operator's tenant
const operator = await mcp__dainos__get_user({ id: "<operator_iam_user_id>" });
// → { id, email, fullName, displayName, status, tenantId } or null

// 2) Tenants across every picked product (4b already returned tenantId per row).
const productTenants = new Set(pickedProducts.map(p => p.tenantId));
```

**Pass criteria (all must hold):**
- `get_user` returns a row (operator exists).
- `productTenants.size === 1` (exactly one distinct tenant across picked products).
- `operator.tenantId === [...productTenants][0]` (operator and product share a tenant).

**Block conditions:**
- `get_user` returns null → operator_iam_user_id is invalid / cross-tenant. Halt; ask user to re-run the operator-identity setup.
- `pickedProducts.length === 0` (impossible if 4b returned anything — defensive). Halt.
- `productTenants.size > 1` → picked products span multiple tenants. Halt; ask user to narrow the selection.
- Tenant mismatch → operator and product belong to different tenants. Halt; this is the misconfigured-repo case the guard exists for.

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

The DainOS MCP exposes `list_tasks({ projectId, assigneeId, status })` but only one project at a time, and not joined to `product_id`. For wrap-up we need a single query that spans all projects under the picked product(s), so use SQL:

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
  - "None of these": log session_context with `product_id` set but `task_ids = '{}'`, skip to Step 8.
  - "Create new task": ask for: title, project (pick from `mcp__dainos__list_projects` results filtered by product, or NULL), initial status (default `in_progress`). Prefer `mcp__dainos__create_task({ title, projectId, status, assigneeId, reporterId, startDate })` for the insert — the MCP fills server-side defaults (e.g. priority_score) correctly. Fall back to SQL INSERT only if the MCP is unavailable. Add the returned id to the linked set.

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

The DainOS MCP `update_task` exposes `status`, `assigneeId`, `priorityMoscow`, `storyPoints`, `estimatedHours`, `dueDate`, `startDate`, `tags`, `title`, `description`. It does NOT expose `description_client`, `description_json`, `description_client_json`, `actual_hours`, `completed_at`, or `completed_by`. Because the bulk of what wrap-up writes lives in the unexposed columns, **default to SQL for the task UPDATE** so we can wrap everything in one transaction. Use `mcp__dainos__complete_task(id)` only for the status state-machine walk when a task moves to `done`, then follow up with SQL for the rest.

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

## Step 7.5: PR Review Feedback (DainOS reviewer A/B)

For each PR opened or updated by commits pushed in this session, score any unscored DainOS-reviewer findings so we can tune the reviewer (and validate retiring Greptile by end of month).

This step writes to `developer.pr_review_finding_feedback`. No MCP tool yet — SQL only.

### 7.5a. Discover PRs touched this session

For each branch pushed in Step 3, ask GitHub for the PR number:

```bash
gh pr view --json number,headRefName,headRefOid 2>/dev/null
```

If a worktree's branch has no PR, skip. Collect the set of `(repo, pr_number)` pairs.

### 7.5b. Pull unscored findings

For each `(repo, pr_number)`, query unscored findings via the MCP:

```
mcp__dainos__list_unscored_pr_findings({
  repo: "<owner>/<repo>",
  prNumber: <pr_number>,
  scoredBy: "<operator_iam_user_id>"
})
```

Returns findings the operator hasn't scored yet, with `id`, `severity`, `category`, `title`, `body`, `suggestion`, `file`, `line`, `resolutionStatus`, plus the review's `commitSha` and `createdAt`. Ordered by `createdAt` DESC then severity.

If empty across all PRs, skip to Step 8 silently. **Do NOT prompt the user.**

### 7.5c. Score findings (batched up to 4 per prompt)

For each batch of up to four unscored findings, render the block below and ask one `AskUserQuestion` per finding (max 4 questions per call, the AskUserQuestion limit):

```
PR #<pr_number> · DainOS reviewer · finding <i>/<n>

  Severity   <severity>
  Category   <category>
  File       <file>:<line>
  Title      <title>

  ----
  <body, first 600 chars>
  ----

  Resolution status   <open | acknowledged | resolved>
```

`AskUserQuestion` shape for each finding. **Three of the four options are verdicts that get persisted; `Skip` is a sentinel that explicitly does NOT write a row** (see 7.5d). Keep these two groups separate when rendering — they have different semantics, and the DB's `verdict` CHECK constraint will reject anything other than the three real verdicts:

- Question: `Score finding [<short_title>]?`
- Header: `Score #<i>`
- Options — **verdicts (persisted; must be one of these three exact strings to satisfy the CHECK constraint)**:
  - `useful` — finding was correct and worth acting on
  - `noise` — finding was technically correct but low value, or pointed at something out of scope
  - `wrong` — finding was factually incorrect or based on a misreading
- Options — **sentinel (NOT persisted)**:
  - `Skip` — don't write a verdict for this finding (e.g., not enough context to judge). 7.5d MUST short-circuit before the INSERT for this value.

After collecting answers, prompt once more for free-text notes (optional):

- Question: `Any notes on this batch of findings? (e.g. "the critical was right in spirit but mechanism was wrong")`
- Header: `Notes`
- Options:
  - `Skip notes`
  - Free-text via the "Other" path (user types the note)

The note applies to every scored finding in the batch (cheap path). If a user wants per-finding notes, they can pick "Other" on the question itself with text in the answer — handled naturally by AskUserQuestion's Other support.

If there are more than 4 unscored findings, complete the first batch, then ask:

- Question: `<remaining> more unscored findings on this PR. Continue scoring now?`
- Options: `Score the next batch`, `Skip the rest for this session`.

If "Skip the rest" → leave them unscored; they'll surface again on the next wrap-up.

### 7.5d. Write verdicts

For each finding the operator gave a real verdict to (NOT `Skip`):

```
mcp__dainos__score_pr_finding({
  findingId: "<uuid>",
  verdict: "<useful|noise|wrong>",
  scoredBy: "<operator_iam_user_id>",
  notes: <batch_notes or omitted>,
  reviewerVersion: <reviewerVersion or omitted>
})
```

One MCP call per scored finding. The API enforces `UNIQUE(finding_id, scored_by)` and returns **409** with the existing row if the operator already scored this finding (shouldn't happen since 7.5b filtered them out, but treat 409 as a no-op rather than an error).

If a finding was marked `Skip`, do NOT call `score_pr_finding` — leaving it null means "not yet scored" and it'll resurface on the next session.

`reviewerVersion` is currently omitted until the DainOS reviewer starts publishing a version tag in its review comment. When that ships, parse it from the comment body and pass it through.

### 7.5e. Report

Add to the Step 9 summary block:

```
## PR Review Feedback (DainOS reviewer)
| PR | Findings scored | useful / noise / wrong | Skipped |
|----|-----------------|------------------------|---------|
| #267 | 2 | 2 / 0 / 0 | 0 |
| #269 | 5 | 1 / 1 / 2 | 1 |
```

---

## Step 8: Write Session Context

INSERT one row into `developer.session_context` via the MCP. As of #319 the tool covers the relational fields (`productId`, `taskIds`, `operatorIamUserId`) alongside the core columns.

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

```
mcp__dainos__log_session_context({
  project: "<project_slug>",
  sessionName: "<descriptive session name>",
  sessionDate: "<YYYY-MM-DD>",
  operator: "<model name e.g. claude-opus-4.7>",
  machine: "<resolved hostname from `hostname` shell call>",
  durationMinutes: <estimated minutes>,
  summary: "<summary>",
  decisionsMade: [<{ decision, reason }>...],
  handoffNotes: "<handoff narrative>",
  filesTouched: [<files>],
  tasksCompleted: [<task_titles_completed_text>],
  blockers: [<blockers>],
  tags: [<tags>],
  productId: "<product_id_or_null>",
  taskIds: ["<linked_task_id>", ...],
  operatorIamUserId: "<operator_iam_user_id>"
})
```

If `productId` was not resolved (Step 4 returned no row and user chose "Skip"), omit it (or pass `null`). Same for `taskIds` (omit or pass `[]`) — the API treats both as "not linked".

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

## PR Review Feedback (DainOS reviewer)
| PR | Findings scored | useful / noise / wrong | Skipped |
|----|-----------------|------------------------|---------|
| #267 | 2 | 2 / 0 / 0 | 0 |

(Omit the whole section if no unscored findings were found in Step 7.5b.)

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
13. **PR review feedback (Step 7.5) never prompts when there are zero unscored findings.** Don't add friction to wrap-ups that didn't touch a reviewed PR.
14. **Skip = don't write a row.** A `pr_review_finding_feedback` row with a real verdict is a commitment. If the operator picks `Skip`, leave the finding unscored so it resurfaces next session.
15. **DainOS MCP is the default path.** The fallback table at the top of this skill lists only two exceptions where Supabase is still required: Step 5b's cross-product candidate task query, and Step 7's transactional all-or-nothing task UPDATE batch. Everywhere else, use the MCP — no Supabase token needed.
