---
description: Batch-execute tasks from Notion projects/milestones — builds global DAG, plans waves, distributes across sessions. Invoked by /batch command.
---

# Batch Orchestrator

Dependency-driven batch execution across Notion projects and milestones. Builds a global dependency graph, computes wave ordering, prepares environments, dispatches work, and handles merge choreography.

## Phases

1. **Analyse** — Resolve URLs, fetch tasks, parse dependencies into global DAG, extract domain fingerprints, classify status
2. **Plan** — Topological sort into waves, two-layer overlap detection, migration collision prevention, machine assignment, parallelism cap
3. **Prepare** — Progress file, pre-wave migrations, worktree setup, Notion claiming, session commands
4. **Execute** — Subagent dispatch for small tasks, clipboard commands for interactive sessions, resume-based monitoring
5. **Merge** — PR creation, cross-PR review, CI wait, hybrid merge, cleanup, advance to next wave

See full skill file for complete methodology.
