---
name: create-milestone
description: Create a project milestone via the DainOS MCP. Use when the user says "create a milestone", "add a milestone to project X", or when the wrap-up flow (Step 5c.iii.a) needs to spin up a fresh milestone before linking a task.
---

# Create Milestone

Create a new milestone on a DainOS project. The DainOS MCP supports milestone creation directly via the generic `mutate` tool as of 2026-05-28; the old SQL-via-Supabase fallback is only needed against an MCP version older than that.

## When to use

- The user says "create a milestone called X on project Y".
- The wrap-up command's Step 5c.iii.a prompted the operator with "Create new milestone" and you need to spin one up before attaching a new task.
- A `/ship` plan needs a milestone bucket before the foreman starts dispatching builders.

Do **not** use this skill to retitle, reschedule, or close an existing milestone — use `mutate({ resource: 'milestones', operation: 'update', id, parentId, data })` instead.

## Inputs to collect (in order)

1. **`projectId`** (required) — the parent project's UUID. If you don't have it, call `query({ resource: 'projects', filters: { ... } })` first. There is no project-name fuzzy match for milestones yet — you need the UUID.
2. **`name`** (required) — short, descriptive milestone name, e.g. `"Discovery"`, `"Beta launch"`, `"Wave 1b: Forms"`.
3. **`description`** (optional) — one or two sentences of intent. Useful when the name alone is ambiguous.
4. **`status`** (optional) — `pending` (default), `in_progress`, `completed`, `cancelled`. Almost always `pending` on creation; the wrap-up flow will flip it later if it's the active milestone for the session.
5. **`startDate`** / **`dueDate`** (optional) — ISO 8601 (`YYYY-MM-DD`).
6. **`isBillable`** / **`billableAmount`** (optional) — leave unset unless the user explicitly asks for billing on the milestone itself. These belong to a deliberate finance decision, not a session side-effect (same rule as wrap-up Step 5c.iii.a).
7. **`sortOrder`** (optional) — integer for display order. Omit unless the user wants a specific position; the server will append.

If `projectId` cannot be resolved, STOP and ask the user — never invent a UUID, never create against the wrong project.

## The call

```
mcp__dainos__mutate({
  resource: "milestones",
  operation: "create",
  parentId: "<projectId>",
  data: {
    name: "<name>",
    description: "<optional description>",
    status: "pending",
    startDate: "<YYYY-MM-DD or omit>",
    dueDate: "<YYYY-MM-DD or omit>"
  }
})
```

The MCP routes this to `POST /projects/<projectId>/milestones` and returns the new milestone row with its `id`. Capture the `id` for follow-on work (e.g. passing as `milestoneId` to `create_task`).

## Human gate (when called from wrap-up)

Inside the wrap-up flow, render this block before calling `mutate` and ask `AskUserQuestion`:

```
About to create a milestone:

  Project       <project_name>            (id: <project_id>)
  Name          <name>
  Description   <description or "—">
  Status        <status>
  Start date    <start_date or "—">
  Due date      <due_date or "—">
```

Options: `Create it`, `Edit a field`, `Cancel`. Only proceed on `Create it`.

When invoked standalone (user typed "create a milestone called X"), the user has already given the intent — don't add a confirmation prompt unless a field is missing or ambiguous.

## Legacy SQL fallback (only if MCP create is unavailable)

If the deployed MCP server pre-dates 2026-05-28 (the `mutate` call returns `Operation "create" is not supported on "milestones"`), fall back to:

```sql
INSERT INTO projects.milestones (project_id, name, start_date, due_date, status)
VALUES ('<projectId>', '<name>', <start_date_or_NULL>, <due_date_or_NULL>, 'pending')
RETURNING id;
```

Run via `mcp__claude_ai_Supabase__execute_sql` against project `nkwxprrhkifxoeqwvnpu`. Do not set `is_billable` or `billable_amount` from this path either.

## Verification

After creation, run `query({ resource: 'milestones', parentId: '<projectId>' })` and confirm the new milestone appears with the expected `name` and `status`. Report the new `id` back to the user so they can reference it.

## Related

- `mutate` (generic) — used for the create call itself.
- `create_task` — pass the new milestone `id` as `milestoneId` when creating tasks under this milestone.
- `cmd-wrap-up` Step 5c.iii.a — references this skill.
