---
description: Execute a task from Notion — claim, build, verify, update. Delegates code tasks to /ship. Works across projects using project-config.json for context.
argument-hint: <task number e.g. "4.2" or Notion URL or "next" for auto-pick>
---

# Execute: $ARGUMENTS

Notion coordination wrapper for multi-machine task execution. Claims tasks, checks dependencies, delegates building to the right tool, updates Notion with results, and cascades learnings to downstream tasks.

**YOU ARE A COORDINATOR.** You handle the Notion lifecycle and delegate the actual building.

## Phase 0: Load Context
- Find project-config.json
- Find the Notion task (by number, URL, "next", or list available)
- Verify claimable (Status = Backlog, dependencies met)
- Claim: Status -> In progress

## Phase 1: Read Brief & Route
- SQL/config tasks -> Path A: Direct execution
- Code tasks -> Path B: Delegate to /ship
- Human tasks -> STOP

## Phase 2A: Direct Execution (SQL/Config)
- Execute exactly what the brief says
- UK English, idempotent, migrations in files
- Verify acceptance criteria

## Phase 2B: Delegate to /ship (Code Tasks)
- Write Feature Brief from Notion brief
- Invoke /ship with the brief path
- Capture branch and PR

## Phase 3: Complete
- Update Notion status and notes
- Report results to user

## Phase 4: Learn & Cascade
- Capture gotchas to dev KB
- Assess system-level patches
- Cascade impact to downstream tasks
