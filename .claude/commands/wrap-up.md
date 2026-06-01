---
description: End-of-session wrap-up: commit, push, link to DainOS product + tasks, write session context
argument-hint: [optional: summary override for session context]
---

# Wrap Up

End-of-session command. Commits all uncommitted work across all worktrees, pushes all branches, links the session to a DainOS product, matches and updates one or more DainOS tasks (with confirmation), and writes session context to DainOS.

**Run this LAST before ending a session.**

---

## Auto Mode

**If `$ARGUMENTS` contains `auto`:** run the entire wrap-up without interactive prompts. Every `AskUserQuestion` call is replaced by the auto-default listed below. Use this for background agents, scheduled wrap-ups, or when the operator has pre-approved the session's scope.

**Auto-mode defaults by step:**

| Step | Interactive behaviour | Auto-mode default |
|------|----------------------|-------------------|
| Operator identity | AskUserQuestion to pick from tenant roster | Auto-select if exactly one user; FAIL if multiple (cannot guess) |
| 2d. Pre-commit hook failure | Ask: fix, --no-verify, or skip | Attempt trivial fix (unused imports, formatting). If fix fails, commit with `--no-verify` and log a warning. |
| 4b. Multiple products | AskUserQuestion multiSelect | Select ALL matched products (session likely touched all) |
| 4b. No product mapped | Ask: skip or register | Skip task linking, log warning |
| 5c. Task matching | AskUserQuestion multiSelect from candidates | Auto-select tasks matched by explicit commit refs in subjects. If no explicit refs, select the single most-recently-updated task assigned to the operator. If zero candidates, skip task linking. |
| 5c. Create new task | Interactive title/project/milestone flow | Never auto-create. Skip to Step 8 with no task link. |
| 6c. Human gate review | Per-task AskUserQuestion with full field block | Apply all proposals as-is. Log the full proposed block to the session summary so the operator can audit post-hoc. |
| 7.5c. PR review scoring | AskUserQuestion per finding batch | Skip entirely. Findings remain unscored for the next interactive session. |
| 7.6. KB learnings | Identify and log candidates | Still runs. KB entries are non-destructive and do not need confirmation. |
| 8a. Session context | AskUserQuestion to confirm | Write without confirmation. |

**Safety rails in auto mode:**
- Tenant consistency guard (Step 4c) still runs and will FAIL on mismatch. No auto-bypass.
- Transaction rollback on SQL error (Step 7) still halts. No auto-retry.
- `--no-verify` usage is logged as a warning in the Step 9 report so the operator knows hooks were skipped.
- If operator identity cannot be auto-resolved (multiple users in tenant), the entire wrap-up FAILS rather than guessing.

**To invoke:** `/wrap-up auto` or `/wrap-up auto <summary override>`

---

## Data sources (fallback chain)

For every read and write, prefer this order. Skip to the next tier only if the higher tier is unavailable or doesn't expose the column/operation you need.

1. **DainOS MCP** (`mcp__dainos__*`) — preferred when available. Cross-project, no Supabase token needed, portable across MCP clients.
2. **Supabase MCP** (`mcp__claude_ai_Supabase__execute_sql`) with project_id `nkwxprrhkifxoeqwvnpu` — fallback for tables and columns the DainOS MCP doesn't yet expose.
3. **Supabase CLI** (`supabase db ...`) — last resort, e.g. when running offline or against a local stack.

**Where each tier applies in this skill** (updated 2026-05-31 for the v0.8 generic-tools MCP: reads go through `query`, writes through `mutate`, and a handful of business-logic operations keep dedicated named tools. Call `describe_schema` if you are unsure of a resource's fields):

| Step | DainOS MCP call | Notes |
|------|-----------------|-----|
| Operator identity | `query({ resource: 'iam_users', filters: { status: 'active' } })` | Returns users in the caller's tenant only — no `tenantSlug` arg needed. Each row includes `id, email, fullName, displayName, status, tenantId` |
| 3.5. Log commits | `log_changelog_entry({ project, entries: [...] })` | **Named tool.** Batch insert (up to 50/call), idempotent on `(project, commit_sha)`. Safe to call even if a CI hook also writes — duplicates are silently skipped |
| 4b. Product lookup | `query({ resource: 'product_repos', filters: { owner, repo } })` | Returns `[{ productId, tenantId, productName, companyId, isPortalVisible }]` |
| 4c. Tenant guard | `query({ resource: 'iam_users', id })` + product lookup | Compare `user.tenantId` against each product's `tenantId` client-side |
| 5b. Candidate task query | — | Still uses SQL: the WITH-CTE explicit-refs + recent-open join across all projects under a product has no single-call equivalent. `query({ resource: 'product_task_summary', parentId: productId })` returns aggregates, not the full per-task signal-matched list |
| 5c. Milestone resolution | `query({ resource: 'milestones', parentId: projectId })` | Call before `create_task` whenever `projectId` is set. Orphan tasks (project with milestones but no `milestoneId`) clutter the project view. |
| 5c. Create milestone | `mutate({ resource: 'milestones', operation: 'create', parentId: projectId, data })` | `parentId` is the projectId. `data` takes `name` (required), `startDate?`, `dueDate?`, `status?`. Reuse the returned id on `create_task`. |
| 5c. Create new task | `create_task` | **Named tool.** Server fills `priority_score` default; takes `title, projectId, milestoneId, status, assigneeId, reporterId, startDate`. ALWAYS pass `milestoneId` when the project has milestones — see Step 5c.iii. **Does NOT yet expose `taskType`** — follow the `create_task` call with a one-row SQL UPDATE to set `task_type` (see Step 5c.iv). |
| 6/7. Task UPDATE | `mutate({ resource: 'tasks', operation: 'update', id, data })` | Exposes `descriptionClient`, `descriptionJson`, `descriptionClientJson`, `actualHoursDelta` (additive), `completedAt`, `completedBy`. Use `complete_task` (named tool) only for the status state-machine walk. **One call per task — no transactional batch**. If you need all-or-nothing semantics across multiple tasks, drop to SQL with `BEGIN; ... COMMIT;` instead. |
| 7.5. PR review feedback | `query({ resource: 'pr_review_findings', filters: { repo, prNumber, scoredBy } })` + `score_pr_finding({ findingId, verdict, scoredBy, notes?, reviewerVersion? })` | `score_pr_finding` is a named tool. Verdict enum: `useful \| noise \| wrong`. 409 on duplicate — don't retry. |
| 8. session_context INSERT | `mutate({ resource: 'session_context', operation: 'create', data })` | `data` uses snake_case fields including `product_id`, `task_ids`, `operator_iam_user_id` |

Supabase MCP / CLI is only needed for Step 5b's cross-product query and for the transactional task-UPDATE batch in Step 7 (when explicit ALL-OR-NOTHING semantics are required across multiple tasks).

---

## Operator identity (one-time setup)

Before Step 1, check `~/.dain-os/wrap-up.json`. If absent OR missing `operator_iam_user_id`:

1. Query users in the caller's tenant via the MCP:

```
mcp__dainos__query({ resource: "iam_users", filters: { status: "active" } })
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
mcp__dainos__query({ resource: "product_repos", filters: { owner: "<owner>", repo: "<repo>" } })
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
const operator = await mcp__dainos__query({ resource: "iam_users", id: "<operator_iam_user_id>" });
// → { id, email, fullName, displayName, status, tenantId } or null

// 2) Tenants across every picked product (4b already returned tenantId per row).
const productTenants = new Set(pickedProducts.map(p => p.tenantId));
```

**Pass criteria (all must hold):**
- the `iam_users` lookup returns a row (operator exists).
- `productTenants.size === 1` (exactly one distinct tenant across picked products).
- `operator.tenantId === [...productTenants][0]` (operator and product share a tenant).

**Block conditions:**
- the `iam_users` lookup returns null → operator_iam_user_id is invalid / cross-tenant. Halt; ask user to re-run the operator-identity setup.
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

`query({ resource: 'tasks', filters: { projectId, assigneeId, status } })` filters one project at a time and is not joined to `product_id`. For wrap-up we need a single query that spans all projects under the picked product(s), so use SQL:

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
  - "Create new task": follow Step 5c.i → 5c.iii → 5c.iv below. Add the returned task id to the linked set.

Store the final array of selected task ids as `linked_task_ids`.

#### 5c.i. Collect task basics

Ask the operator for:
- **title** — required.
- **project** — pick from `mcp__dainos__query({ resource: "projects", filters: { productId } })` results, or `NULL` for an unscoped task.
- **initial status** — default `in_progress`.
- **task_type** — required. Use `AskUserQuestion` (single-select) over the enum values `feat | fix | chore | refactor | docs | test`. Pre-select the value inferred from the dominant conventional-commit prefix across commits attributed to this task (`feat→feat, fix→fix, chore→chore, refactor→refactor, docs→docs, test→test`). For prefixes with no enum equivalent (`perf`, `ci`, `build`, `revert`, `style`), pre-select `chore` (same defensive default as 3.5b). The operator can always override.

If `project` is `NULL`, skip 5c.ii–5c.iii and go straight to 5c.iv with no `milestoneId`. `task_type` is collected regardless of `project`.

#### 5c.ii. List milestones on the chosen project

Call `mcp__dainos__query({ resource: "milestones", parentId: "<projectId>" })`. Three branches:

1. **Project has no milestones** → no decision to make. Go to 5c.iv with no `milestoneId`. Do not invent a milestone the operator hasn't asked for.
2. **Project has milestones** → go to 5c.iii.
3. **MCP error** → fall back to SQL:
   ```sql
   SELECT id, name, status, start_date, due_date
     FROM projects.milestones
    WHERE project_id = '<projectId>'
    ORDER BY sort_order, due_date NULLS LAST;
   ```

#### 5c.iii. Decide milestone (mandatory three-way prompt when 5c.ii returned ≥1 milestone)

Use `AskUserQuestion` (single-select) with the prompt: **"Attach this task to a milestone?"** and the following options (in this order):

- One option per existing milestone, labelled `<name> (<status>, due <due_date or "no date">)`. Selecting one carries its `id` forward as `milestoneId`.
- **"Create new milestone"** → go to 5c.iii.a.
- **"Leave unassigned"** → carry forward with no `milestoneId`. Acceptable but should be the exception, not the default. The MCP description explicitly flags orphan tasks under a milestoned project as a code smell, so prefer attaching wherever it fits.

##### 5c.iii.a. Create a new milestone

Ask the operator for `name` (required), `start_date` (optional, ISO), `due_date` (optional, ISO). Then create the milestone via `mutate` (parentId is the projectId):

```
mcp__dainos__mutate({
  resource: "milestones",
  operation: "create",
  parentId: "<projectId>",
  data: { name: "<name>", startDate: "<start_date_or_omit>", dueDate: "<due_date_or_omit>", status: "pending" }
})
```

Carry the returned `id` forward as `milestoneId`. If the MCP is unavailable, fall back to the Supabase MCP with `INSERT INTO projects.milestones (project_id, name, start_date, due_date, status) VALUES (...) RETURNING id`. Do **not** set `is_billable` or `billable_amount` from wrap-up — those belong to a deliberate financial decision, not a session-recap side effect.

#### 5c.iv. Insert the task

Prefer `mcp__dainos__create_task({ title, projectId, milestoneId, status, assigneeId, reporterId, startDate })` — pass `milestoneId` whenever 5c.iii produced one, omit otherwise. The MCP fills server-side defaults (e.g. `priority_score`) correctly. Fall back to SQL `INSERT INTO projects.tasks` only if the MCP is unavailable; include `project_milestone_id` in the column list if you have a milestone id.

**Setting `task_type`:** `mcp__dainos__create_task` does NOT yet accept a `taskType` parameter (as of 2026-05-28). Immediately after the create call returns the new task id, run a one-row SQL UPDATE to persist the value chosen in 5c.i:

```sql
UPDATE projects.tasks
   SET task_type = '<selected_task_type>'::projects.task_type,
       updated_at = NOW()
 WHERE id = '<new_task_id>'
   AND tenant_id = '<tenant_id>';
```

If you fell back to the SQL `INSERT` path, include `task_type` in the column list of the INSERT instead — no follow-up UPDATE needed. Valid enum values: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`.

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
| `task_type` | Only set if currently NULL → infer from the dominant conventional-commit prefix of commits attributed to this task. Mapping: `feat→feat, fix→fix, chore→chore, refactor→refactor, docs→docs, test→test`. Prefixes with no enum equivalent (`perf`, `ci`, `build`, `revert`, `style`) → default to `chore`. Never overwrite a non-NULL value. The Human Gate (6c) is the operator's chance to override or skip. |
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
  Type          <current> → <proposed>     (inferred from commit prefix; "—" if unchanged or already set)
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
  - `Edit a field`: re-prompts for which field (status, task_type, assignee, hours split, internal copy, client copy, project, title for new tasks). Apply edits, re-render the same block, ask again. Loop until applied or skipped.
  - `Skip this task`: drop from `linked_task_ids`, do not write.
  - `Mark complete instead`: only shown if proposed status is not already `done`. Sets status = `done`, completed_at = NOW(), completed_by = operator. Re-render the block, ask again.

**Multi-task sessions:** ask once per task. Do NOT batch confirm "all tasks" into one prompt. Each task's block + AskUserQuestion is its own gate.

**No silent defaults.** If any field in the block is blank or `<...>`, STOP and surface that the proposal is incomplete. Never proceed with a partially-filled write.

---

## Step 7: Write the Task Updates

`mutate({ resource: 'tasks', operation: 'update', id, data })` now exposes every field wrap-up writes — `descriptionClient`, `descriptionJson`, `descriptionClientJson`, `actualHoursDelta` (additive), `completedAt`, `completedBy`, plus `status`, `startDate`, etc. So a **single-task** update no longer needs SQL: read the task first (`query tasks id`) to compute the appended description bodies client-side, then `mutate` the full new values. **However, `mutate` is one call per record with no transaction.** When a session links **multiple** tasks and you want all-or-nothing semantics, **default to SQL for the task UPDATE** so the whole batch lands in one `BEGIN; ... COMMIT;` (this is the legitimate Supabase exception in Rule 15). Use `mcp__dainos__complete_task(id)` only for the status state-machine walk when a task moves to `done`.

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
    -- task_type: omit this line entirely if the existing task already has a non-NULL value.
    -- Otherwise set to the value chosen in 6c (already enum-validated).
    task_type = COALESCE(task_type, '<proposed_task_type>'::projects.task_type),
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
mcp__dainos__query({
  resource: "pr_review_findings",
  filters: { repo: "<owner>/<repo>", prNumber: <pr_number>, scoredBy: "<operator_iam_user_id>" }
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

## Step 7.6: Capture KB-Worthy Learnings

Before writing `session_context`, surface any KB-worthy learnings from this session and log them to `developer.dev_knowledge_base` via `mcp__dainos__log_knowledge_base_entry`. The KB is the team's accumulated memory of gotchas, patterns, decisions, and lessons — far more useful than any individual session_context row, because it's what future sessions read when grepping for "have I hit this before". `session_context` is per-session narrative; the KB is the permanent record.

This step is mandatory. If nothing felt KB-worthy, say so explicitly in the Step 9 report rather than silently skipping.

### 7.6a. Identify candidates

Skim the session for items matching the KB filter — "SURPRISING, NON-OBVIOUS, or caused real problems":

- **gotcha** — an API/library/tool/config behaved unexpectedly and burned debug time
- **pattern** — a reusable technique was invented or applied (e.g. "diagnostic-of-last-resort via ORM middleware", "Retry-After-aware backoff helper", "bucket-by-gap analysis for intermittent bugs")
- **lesson** — a debugging heuristic or analysis technique that worked
- **decision** — a non-obvious architectural call that future readers should know about, including the WHY
- **workaround** — a temporary fix that bypasses an upstream bug rather than solving it, plus the condition under which the workaround can be removed

Skip:
- One-off bug fixes with no general lesson
- Anything already captured in `CLAUDE.md`, `.claude/rules/*`, domain `INDEX.md` files, or existing KB entries
- Trivial / obvious-in-hindsight observations

### 7.6b. Dedupe

For each candidate, search the KB with a short query matching the title's key noun and the module:

```
mcp__dainos__query({ resource: "developer_knowledge_base", search: "<noun>", filters: { project: "dain-os", module: "<area>" }, limit: 5 })
```

If an entry already exists and the new occurrence reinforces it, call `mcp__dainos__mutate({ resource: "developer_knowledge_base", operation: "update", id: "<entry_id>", data: { ... } })` to append a new source_ref / refine prevention. If the existing entry is materially different, log a new one — KB cross-references are cheap, near-misses are expensive.

### 7.6c. Log

Batch new entries (1-50 per call) into `mcp__dainos__log_knowledge_base_entry`. Required fields per entry:

| Field | What to write |
|---|---|
| `category` | `gotcha` \| `pattern` \| `lesson` \| `decision` \| `workaround` |
| `module` | System area, e.g. `auth`, `pr-review`, `prisma`, `deployment` |
| `title` | Short, descriptive, would match a future grep |
| `description` | What happened / what is this. Include the WHY when it's non-obvious. |
| `impact` | Cost in real terms (debug hours, prod incidents, missed deadlines) — concrete numbers if you have them |
| `prevention` | Specific steps to avoid it next time. Code snippets, commands, or rules — not platitudes. |
| `severity` | `critical` \| `high` \| `medium` \| `low` |
| `source_type` | `fix_commit` \| `pr_comment` \| `pr_review` \| `code_review` \| `ai_conversation` \| `incident` \| `documentation` \| `debugging_session` |
| `source_refs` | Array of PR URLs, file paths, commit SHAs — anything a future reader can click |
| `tags` | Searchable keywords (lowercase, hyphenated multi-word) |

Use project `"universal"` instead of `"dain-os"` only when the lesson is genuinely cross-product (e.g. a Node/OpenSSL quirk, a Supabase platform behaviour). Most lessons are project-specific.

### 7.6d. Report

Add to the Step 9 summary block:

```
## Knowledge Base
| Entries logged | Categories                |
|----------------|---------------------------|
| 3              | 2 gotchas, 1 pattern      |
```

If zero entries felt worth logging, write `| 0 | nothing KB-worthy this session |` — explicit rather than silent.

---

## Step 8: Write Session Context

Create one row in `developer.session_context` via `mutate`. The resource covers the relational fields (`product_id`, `task_ids`, `operator_iam_user_id`) alongside the core columns.

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

Create the row via `mutate`. The `session_context` resource uses **snake_case** field names (confirm with `describe_schema` if unsure):

```
mcp__dainos__mutate({
  resource: "session_context",
  operation: "create",
  data: {
    project: "<project_slug>",
    session_name: "<descriptive session name>",
    session_date: "<YYYY-MM-DD>",
    operator: "<model name e.g. claude-opus-4.8>",
    machine: "<resolved hostname from `hostname` shell call>",
    duration_minutes: <estimated minutes>,
    summary: "<summary>",
    decisions_made: [<{ decision, reason }>...],
    handoff_notes: "<handoff narrative>",
    files_touched: [<files>],
    tasks_completed: [<task_titles_completed_text>],
    blockers: [<blockers>],
    tags: [<tags>],
    product_id: "<product_id_or_null>",
    task_ids: ["<linked_task_id>", ...],
    operator_iam_user_id: "<operator_iam_user_id>"
  }
})
```

If `product_id` was not resolved (Step 4 returned no row and user chose "Skip"), omit it (or pass `null`). Same for `task_ids` (omit or pass `[]`) — the API treats both as "not linked".

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
16. **`task_type` is one of `feat | fix | chore | refactor | docs | test`.** Required on every new task (Step 5c.i). Inferred from the dominant conventional-commit prefix; unmappable prefixes default to `chore`. Never auto-overwrite an existing non-NULL value — only fill when currently NULL. The Human Gate (6c) always offers an override.
17. **`mcp__dainos__create_task` does not yet expose `taskType`.** When creating via the MCP, follow up with a one-row SQL UPDATE to set `task_type` (see Step 5c.iv). When this gap closes in the MCP, drop the follow-up UPDATE.