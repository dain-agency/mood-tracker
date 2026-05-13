#!/bin/bash
# .claude/hooks/supabase-types-commit-gate.sh
# PreToolUse: BLOCK git commit if .types-pending exists
# Exit code 2 blocks the command

set -euo pipefail

# Use git to find the actual repo root (works correctly in worktrees)
PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || { cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd; })"

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only check Bash commands
if [[ "$tool_name" != "Bash" ]]; then
    exit 0
fi

command=$(echo "$json" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Only check git commit commands
if [[ ! "$command" =~ git\ commit ]]; then
    exit 0
fi

# Check for pending types marker
if [[ -f "$PROJECT_DIR/.types-pending" ]]; then
    migration_files=$(cat "$PROJECT_DIR/.types-pending" 2>/dev/null || echo "unknown")
    echo "=============================================================================" >&2
    echo "  BLOCKED: Supabase types not regenerated after DDL change" >&2
    echo "=============================================================================" >&2
    echo "" >&2
    echo "  Migration file(s) written:" >&2
    echo "$migration_files" | while read -r line; do
        [[ -n "$line" ]] && echo "    $line" >&2
    done
    echo "" >&2
    echo "  You MUST:" >&2
    echo "  1. Run: npm run types:supabase" >&2
    echo "  2. Stage the regenerated types file" >&2
    echo "  3. Delete .types-pending:  rm .types-pending" >&2
    echo "  4. Then retry git commit" >&2
    echo "" >&2
    echo "  Stale Supabase types cause silent runtime errors." >&2
    echo "" >&2
    exit 2
fi

exit 0
