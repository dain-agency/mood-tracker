#!/bin/bash
# .claude/hooks/changelog-reminder.sh
# PostToolUse: After successful git commit, create a marker file
# that blocks git push until the changelog entry is written.
#
# Uses a SHARED marker directory ($HOME/.claude/changelog-pending/)
# so worktree agents can't bypass the gate. Each pending commit gets
# its own file named by SHA, allowing multiple pending commits.

set -euo pipefail

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only check Bash commands
if [[ "$tool_name" != "Bash" ]]; then
    exit 0
fi

command=$(echo "$json" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Only trigger on git commit commands
if [[ ! "$command" =~ git\ commit ]]; then
    exit 0
fi

# Check if the commit succeeded (output contains [branch sha] pattern)
output=$(echo "$json" | jq -r '.tool_output.stdout // empty' 2>/dev/null || echo "")
if [[ ! "$output" =~ \[.*\ [0-9a-f]+\] ]]; then
    exit 0
fi

# Extract commit SHA from output (e.g., "[develop 0c55575]")
commit_sha=$(echo "$output" | grep -oE '\[[^ ]+ ([0-9a-f]+)\]' | grep -oE '[0-9a-f]{7,}' | head -1)

# Extract branch name
branch=$(echo "$output" | grep -oE '\[([^ ]+) [0-9a-f]+\]' | grep -oE '\[([^ ]+)' | tr -d '[' | head -1)

# Shared marker directory — survives across worktrees
MARKER_DIR="$HOME/.claude/changelog-pending"
mkdir -p "$MARKER_DIR"

# Write marker with metadata
cat > "$MARKER_DIR/${commit_sha:-unknown}" <<EOF
sha=${commit_sha:-unknown}
branch=${branch:-unknown}
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cwd=$(pwd)
EOF

echo "CHANGELOG REQUIRED: Commit ${commit_sha:-???} on ${branch:-???}. Write to developer.changelog on DainOS Supabase (nkwxprrhkifxoeqwvnpu) using execute_sql with full 40-char SHA. Then run: rm $MARKER_DIR/${commit_sha:-unknown}"

exit 0
