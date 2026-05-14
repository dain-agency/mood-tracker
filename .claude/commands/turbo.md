---
description: Run Turborepo tasks with proper filtering
argument-hint: [task] [filter]
---

# Turbo: $ARGUMENTS

## Common Commands

```bash
# Build everything (cached)
turbo build

# Build specific app
turbo build --filter=web
turbo build --filter=api

# Build only what changed since last commit
turbo build --filter="[HEAD^1]"

# Dev mode for specific app
turbo dev --filter=web

# Type check everything
turbo typecheck

# Type check only changed packages
turbo typecheck --filter="[HEAD]"

# Run tests
turbo test

# Run tests for specific package
turbo test --filter=@client/ui

# Lint everything
turbo lint

# Run multiple tasks
turbo build test lint
```

## Filter Patterns

| Pattern | Meaning |
|---------|--------|
| `--filter=web` | Only the 'web' app |
| `--filter=@client/ui` | Only the @client/ui package |
| `--filter=web...` | web and all its dependencies |
| `--filter=...web` | web and everything that depends on it |
| `--filter="[HEAD^1]"` | Only packages changed since last commit |
| `--filter="[HEAD]"` | Only packages with uncommitted changes |
| `--filter="./apps/*"` | All apps |
| `--filter="./packages/*"` | All packages |

## Caching

Turbo caches task outputs based on inputs.

```bash
# Force rebuild (bust cache)
turbo build --force

# See what would run (dry run)
turbo build --dry-run

# Show cache status
turbo build --summarize
```

## Dependency Graph

```bash
# Visualise dependencies
turbo build --graph

# Show dependency graph as JSON
turbo build --graph=graph.json
```

## Parallel Execution

```bash
# Limit concurrency
turbo build --concurrency=2

# Sequential (for debugging)
turbo build --concurrency=1
```

## Common Workflows

### Before PR
```bash
turbo typecheck lint test --filter="[HEAD]"
```

### Full CI check
```bash
turbo build typecheck lint test
```

### Development
```bash
# Start specific app with dependencies
turbo dev --filter=web...
```

### After pulling changes
```bash
npm install
turbo build --filter="[origin/main]"
```

---

Run: turbo $ARGUMENTS