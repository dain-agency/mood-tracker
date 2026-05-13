#!/bin/bash
# .claude/hooks/index-update-gate.sh
# PostToolUse: When a source file in a domain is written/edited,
# track that domain's INDEX.md needs updating.

set -euo pipefail

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only check Write/Edit/MultiEdit
case "$tool_name" in
    Write|Edit|MultiEdit) ;;
    *) exit 0 ;;
esac

file_path=$(echo "$json" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

# Check if it's a source file inside a domain folder
# Match: apps/*/src/domains/*/  (but NOT INDEX.md itself)
if [[ "$file_path" =~ domains/([^/]+)/ ]] && [[ ! "$file_path" =~ INDEX\.md$ ]]; then
    # Only track code files, not config/json
    if [[ "$file_path" =~ \.(ts|tsx|js|jsx)$ ]]; then
        domain="${BASH_REMATCH[1]}"
        # Extract the app context too
        app=""
        if [[ "$file_path" =~ apps/([^/]+)/ ]]; then
            app="${BASH_REMATCH[1]}"
        fi
        marker_key="${app}/${domain}"

        # Write per-entry marker files to a shared home dir so markers
        # are visible across worktrees (not scoped to a single checkout).
        MARKER_DIR="$HOME/.claude/index-pending"
        mkdir -p "$MARKER_DIR"
        marker_file="$MARKER_DIR/$(echo "$marker_key" | tr '/' '_')"

        # Don't overwrite if already tracked
        if [[ -f "$marker_file" ]]; then
            exit 0
        fi

        echo "$file_path" > "$marker_file"
        echo "INDEX.md UPDATE REQUIRED: Domain file changed in ${marker_key}. Update the domain's INDEX.md before committing."
    fi
fi

exit 0
