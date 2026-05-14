---
description: Batch-execute tasks from a Notion milestone or project — analyses dependencies, plans waves, distributes across sessions and machines
argument-hint: <notion-url> [<notion-url>...] [--worker name:N] [--resume] [--dry-run]
---

# /batch: $ARGUMENTS

Dependency-driven batch orchestrator. Accepts Notion project or milestone URLs, builds a global dependency graph, computes optimal wave ordering, and distributes work across sessions and machines.

**YOU ARE AN ORCHESTRATOR.** You analyse, plan, and coordinate — then delegate execution to `/execute` which delegates building to `/ship`. You never build code yourself.

---

## Argument Parsing

Parse `$ARGUMENTS` into:

| Token | Detection | Variable |
|-------|-----------|----------|
| Notion URL | Starts with `https://` and contains `notion.so` or `notion.site` | Append to `urls[]` |
| `--resume` | Exact match | `resumeMode = true` |
| `--dry-run` | Exact match | `dryRun = true` |
| `--wave N` | `--wave` followed by integer | `jumpToWave = N` |
| `--worker name:N` | `--worker` followed by `string:integer` pattern | Append to `workers[]` as `{ name, capacity }` |
| `--max-parallel N` | `--max-parallel` followed by integer | `maxParallel = N` |

### Validate

- If `resumeMode`:
  - Look for `docs/plans/batch-*-progress.json` files. If exactly one exists, use it. If multiple, list them and ask user to specify.
  - URLs are optional in resume mode (progress file has them)
  - `--worker` flags are allowed (updates machine availability)
- If NOT `resumeMode`:
  - At least one URL is required.
  - Each URL must be fetchable via Notion MCP

### Invoke Skill

Pass parsed arguments to the batch-orchestrator skill. The skill handles all 5 phases: Analyse, Plan, Prepare, Execute, Merge.
