# Sprint Model (one agency-wide sprint)

Dain runs **one** sprint at a time, and it is **agency-wide**. That single active sprint is a tenant-wide, cross-project time-box: it manages **every** project at once, client-facing and internal alike, with membership defined by `tasks.sprint_id`. There are no per-client or per-project sprints. We run projects for clients; we run sprints across all of those projects.

## The facts

1. **One active sprint, tenant-wide.** At any moment there is at most one sprint with `status = 'active'`, and it spans all projects. The database enforces this with the partial unique index `uq_sprints_one_active_per_tenant`. Find the active sprint with `query(sprints, { status: 'active' }, limit: 1)` — **never** add a `projectId` filter.
2. **A sprint is owned by the tenant, not a project.** `sprints.tenant_id` is the owning tenant and the scoping column. `sprints.project_id` is **nullable** — an optional "created-under" origin pointer (`ON DELETE SET NULL`), never ownership and never the scoping mechanism. A populated `project_id` only records which project the sprint happened to be created under; the active sprint holds tasks from many projects regardless. (The active sprint has spanned 14 projects at once.)
3. **Any project's task attaches to the one active sprint.** Membership is `tasks.sprint_id`. When a flow assigns a task to the sprint, it uses the single active sprint's id regardless of which project the task sits under.
4. **Sprints are named by date range, never by client.** e.g. *"Sprint 8th - 22nd June"*. A sprint is never named, or referred to, after a project or client.

## What this means for you

- **Never say "the [Project] sprint" or "[Client]'s active sprint".** There is no such thing. Say "the active sprint", or name it by its date-range name. Narrating "Portunus's sprint" (or any client's) is the canonical symptom of getting this model wrong.
- **Never query sprints filtered by `projectId`** to find "a project's sprint". The active sprint's `project_id` is just its (now optional, possibly null) origin pointer, so that filter returns nothing for every project except the incidental origin — which then reads as "no sprint for this project". Wrong.
- When a sprint-aware command (`/ship`, `/wrap-up`, `/new-feature`, `/sprint`) mentions "the active sprint for the project", read it as "the single agency-wide active sprint". The project is just the work you happen to be doing, not a scope on the sprint.
- To see one project's slice of the sprint, filter the sprint's **tasks** by project (`query(tasks, { sprintId, projectId })`) — never filter the **sprints** by project.

## Why this rule exists

Two reinforcing causes.

1. **The data model.** It historically conflated tenant scope, an access-control anchor, and a "created-under" project into a single `NOT NULL` `sprints.project_id`, then treated that as ownership. The 2026-06-16 re-architecture (PR #605, PRJ-0019 *"Sprints as tenant-wide entities"*, migration `20260616100000_sprints_tenant_wide`; KB *"sprints.project_id is vestigial"*) gave sprints their own `tenant_id`, demoted `project_id` to an optional origin pointer, and DB-enforced one active sprint per tenant.
2. **The instruction prose.** Several sprint-aware commands framed the lookup as "the active sprint **for the primary/current project**". The query underneath was always global (`status: 'active'`, no project filter), but the prose taught a per-project model — and because the active sprint's origin `project_id` pointed at the Portunus project, the model resolved that name and narrated "Portunus's active sprint", a sprint that does not exist. Jack flagged this twice.

The framing is now corrected in `cmd-ship`, `cmd-new-feature`, `cmd-sprint` and `cmd-wrap-up`, and this rule is the single source of truth for the model.
