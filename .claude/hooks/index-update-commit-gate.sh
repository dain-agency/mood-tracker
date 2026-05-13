#!/bin/bash
# .claude/hooks/index-update-commit-gate.sh
# PreToolUse: BLOCK git commit if .index-pending exists
# Exit code 2 blocks the command

set -euo pipefail

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

# Check for pending INDEX updates in the shared home marker dir
# (works across worktrees — markers are not scoped to a single checkout)
MARKER_DIR="$HOME/.claude/index-pending"

if [[ -d "$MARKER_DIR" ]]; then
    pending_markers=()
    for f in "$MARKER_DIR"/*; do
        [[ -f "$f" ]] && pending_markers+=("$f")
    done

    if [[ ${#pending_markers[@]} -gt 0 ]]; then
        echo "=============================================================================" >&2
        echo "  BLOCKED: Domain INDEX.md not updated" >&2
        echo "=============================================================================" >&2
        echo "" >&2
        echo "  Domain source files changed but INDEX.md not updated:" >&2
        for marker in "${pending_markers[@]}"; do
            key=$(basename "$marker" | tr '_' '/')
            echo "    $key/INDEX.md" >&2
        done
        echo "" >&2
        echo "  You MUST:" >&2
        echo "  1. Update each domain's INDEX.md to reflect file changes" >&2
        echo "  2. Delete markers:  rm -rf $MARKER_DIR" >&2
        echo "  3. Then retry git commit" >&2
        echo "" >&2
        echo "  Stale INDEX.md files waste tokens in future sessions." >&2
        echo "" >&2
        exit 2
    fi
fi

exit 0
