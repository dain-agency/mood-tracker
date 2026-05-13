#!/bin/bash
# .claude/hooks/changelog-gate.sh
# PreToolUse: BLOCK git push if any changelog entries are pending.
#
# Checks the SHARED marker directory ($HOME/.claude/changelog-pending/)
# which is populated by changelog-reminder.sh after every commit.
# This works across worktrees because the marker dir is in $HOME,
# not in any specific repo/worktree directory.
#
# Exit code 2 blocks the command.

set -euo pipefail

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only check Bash commands
if [[ "$tool_name" != "Bash" ]]; then
    exit 0
fi

command=$(echo "$json" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Only check git push commands
if [[ ! "$command" =~ git\ push ]]; then
    exit 0
fi

# Shared marker directory
MARKER_DIR="$HOME/.claude/changelog-pending"

# If no marker directory or it's empty, allow push
if [[ ! -d "$MARKER_DIR" ]] || [[ -z "$(ls -A "$MARKER_DIR" 2>/dev/null)" ]]; then
    exit 0
fi

# Count pending entries
pending_count=$(ls -1 "$MARKER_DIR" 2>/dev/null | wc -l)

echo "=============================================================================" >&2
echo "  BLOCKED: ${pending_count} changelog entry/entries not written" >&2
echo "=============================================================================" >&2
echo "" >&2
echo "  Pending commits without changelog entries:" >&2
for marker in "$MARKER_DIR"/*; do
    [[ -f "$marker" ]] || continue
    sha=$(basename "$marker")
    branch=$(grep -oP '(?<=branch=).*' "$marker" 2>/dev/null || echo "unknown")
    echo "    ${sha} (${branch})" >&2
done
echo "" >&2
echo "  You MUST for each pending commit:" >&2
echo "  1. Write to developer.changelog on DainOS Supabase (nkwxprrhkifxoeqwvnpu)" >&2
echo "     using the Supabase MCP execute_sql tool with full 40-char SHA" >&2
echo "  2. Delete the marker: rm $MARKER_DIR/<sha>" >&2
echo "  3. Then retry git push" >&2
echo "" >&2
echo "  To clear all (if changelogs were written externally):" >&2
echo "    rm $MARKER_DIR/*" >&2
echo "" >&2
exit 2
