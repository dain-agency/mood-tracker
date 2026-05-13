#!/bin/bash
# .claude/hooks/schema-check-mark.sh
# PostToolUse (Read): Marks schema as read when supabase types or
# domain query types are loaded. Partner to schema-check-gate.sh.

set -euo pipefail

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only track Read calls
[ "$tool_name" != "Read" ] && exit 0

file_path=$(echo "$json" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
[ -z "$file_path" ] && exit 0

# Check if the file read is a schema/types file
is_schema=false

# Generated Supabase types
if [[ "$file_path" =~ packages/types/src/supabase ]]; then
    is_schema=true
fi

# Domain query types (e.g. packages/queries/src/crm/types.ts)
if [[ "$file_path" =~ packages/queries/src/.*/types ]]; then
    is_schema=true
fi

if [ "$is_schema" = "true" ]; then
    PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || { cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd; })"
    touch "$PROJECT_DIR/.claude/.schema-read"
fi

exit 0
