#!/bin/bash
# .claude/hooks/tsc-on-commit.sh
# BLOCK: Run TypeScript compilation check before git commit
# Prevents broken builds from being committed
# Exit code 2 blocks the commit and feeds errors to Claude

set -euo pipefail

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only check Bash commands
if [[ "$tool_name" != "Bash" ]]; then
    exit 0
fi

command=$(echo "$json" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Only check git commit commands
if [[ ! "$command" =~ ^git\ commit ]] && [[ ! "$command" =~ \&\&\ *git\ commit ]]; then
    exit 0
fi

# Skip amend commits (already compiled code)
if [[ "$command" =~ --amend ]]; then
    exit 0
fi

# Respect --no-verify flag (user explicitly bypassing checks)
if [[ "$command" =~ --no-verify ]]; then
    exit 0
fi

echo "" >&2
echo "=============================================================================" >&2
echo "  PRE-COMMIT: Running TypeScript check..." >&2
echo "=============================================================================" >&2

# Determine project root. Prefer `git rev-parse --show-toplevel` so commits made
# inside a worktree check the worktree's own TypeScript, not the main repo's.
# CLAUDE_PROJECT_DIR (always set to the main repo by the harness) is only used
# as a fallback when git is unavailable.
project_dir="$(git rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-$(pwd)}")"
if [[ "$command" =~ ^cd[[:space:]]+(\"([^\"]+)\"|([^[:space:]]\&]+)) ]]; then
    worktree_dir="${BASH_REMATCH[2]:-${BASH_REMATCH[3]}}"
    if [[ -d "$worktree_dir/apps" ]]; then
        project_dir="$worktree_dir"
    fi
fi

# Check which apps have staged TS changes
has_web_changes=false
has_api_changes=false

staged_files=$(git diff --cached --name-only 2>/dev/null || true)

if echo "$staged_files" | grep -q "^apps/web/.*\.\(ts\|tsx\)$" 2>/dev/null; then
    has_web_changes=true
fi

if echo "$staged_files" | grep -q "^apps/api/.*\.\(ts\|tsx\)$" 2>/dev/null; then
    has_api_changes=true
fi

# If no TS files staged, skip
if [[ "$has_web_changes" == false ]] && [[ "$has_api_changes" == false ]]; then
    echo "  No TypeScript changes staged, skipping tsc" >&2
    exit 0
fi

# =============================================================================
# CHECK: Stale Prisma client after schema change
#
# Npm/pnpm/yarn workspaces hoist transitive deps. The Prisma client could be
# at the workspace-local `apps/api/node_modules/.prisma/client/` OR at the
# hoisted root `node_modules/.prisma/client/`. Pick whichever exists; if
# neither exists, the client really is missing.
# =============================================================================
if echo "$staged_files" | grep -q "schema.prisma" 2>/dev/null; then
    schema_file="$project_dir/apps/api/prisma/schema.prisma"
    workspace_client="$project_dir/apps/api/node_modules/.prisma/client/index.js"
    hoisted_client="$project_dir/node_modules/.prisma/client/index.js"
    if [[ -f "$workspace_client" ]]; then
        client_index="$workspace_client"
    elif [[ -f "$hoisted_client" ]]; then
        client_index="$hoisted_client"
    else
        client_index=""
    fi
    if [[ -f "$schema_file" ]]; then
        if [[ -z "$client_index" ]] || [[ "$schema_file" -nt "$client_index" ]]; then
            echo "" >&2
            echo "=============================================================================" >&2
            echo "  PRE-COMMIT: Prisma client may be stale" >&2
            echo "=============================================================================" >&2
            echo "" >&2
            echo "schema.prisma is staged but the generated client appears outdated." >&2
            echo "Run: cd apps/api && npx prisma generate" >&2
            exit 2
        fi
    fi
fi

errors=""

# Filter out test file errors
filter_test_errors() {
    grep -vE '\.(test|spec)\.(ts|tsx)\(' | grep -v '__tests__/' || true
}

# tsc on this codebase regularly exceeds Node's default 4GB heap. Set 8GB
# before any tsc invocation in this hook to match the documented Environment
# Gate baseline (see /ship Phase 0.5 and CLAUDE.md's Workflow section).
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=8192}"

# Check web app
if [[ "$has_web_changes" == true ]] && [[ -f "$project_dir/apps/web/tsconfig.json" ]]; then
    echo "  Checking apps/web..." >&2
    web_output=$(cd "$project_dir/apps/web" && npx tsc --noEmit 2>&1) || {
        filtered=$(echo "$web_output" | filter_test_errors)
        if [[ -n "$filtered" ]]; then
            errors+="\n-- apps/web TypeScript errors --\n$filtered\n"
        else
            echo "  apps/web has tsc errors in test files only (ignored)" >&2
        fi
    }
fi

# Check api app
if [[ "$has_api_changes" == true ]] && [[ -f "$project_dir/apps/api/tsconfig.json" ]]; then
    echo "  Checking apps/api..." >&2
    api_output=$(cd "$project_dir/apps/api" && npx tsc --noEmit 2>&1) || {
        filtered=$(echo "$api_output" | filter_test_errors)
        if [[ -n "$filtered" ]]; then
            errors+="\n-- apps/api TypeScript errors --\n$filtered\n"
        else
            echo "  apps/api has tsc errors in test files only (ignored)" >&2
        fi
    }
fi

if [[ -n "$errors" ]]; then
    echo "" >&2
    echo "=============================================================================" >&2
    echo "  PRE-COMMIT: TypeScript compilation FAILED" >&2
    echo "=============================================================================" >&2
    echo "$errors" >&2
    echo "" >&2
    echo "Fix type errors before committing." >&2
    exit 2
fi

echo "  TypeScript compilation passed" >&2
exit 0