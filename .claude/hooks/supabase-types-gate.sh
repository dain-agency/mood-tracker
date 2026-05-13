#!/bin/bash
# .claude/hooks/supabase-types-gate.sh
# PostToolUse: When a migration file is written/edited, create a marker
# that blocks git commit until types are regenerated.

set -euo pipefail

PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || { cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd; })"

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only check Write/Edit/MultiEdit
case "$tool_name" in
    Write|Edit|MultiEdit) ;;
    *) exit 0 ;;
esac

# Get the file path that was written/edited
file_path=$(echo "$json" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

# Check if it's a migration file that changes table/column structure
# Only DDL that affects generated types needs regeneration:
#   CREATE TABLE, ALTER TABLE, DROP TABLE, CREATE VIEW, ALTER VIEW, DROP VIEW
# Skip: CREATE FUNCTION, CREATE TRIGGER, CREATE POLICY, CREATE INDEX, INSERT, etc.
if [[ "$file_path" =~ supabase/migrations/ ]] || [[ "$file_path" =~ \.sql$ && "$file_path" =~ migrations ]]; then
    # Read file content and check for table-altering DDL (case-insensitive)
    if [[ -f "$file_path" ]]; then
        if grep -qiE '^\s*(CREATE|ALTER|DROP)\s+(TABLE|VIEW|TYPE|SCHEMA)' "$file_path" 2>/dev/null; then
            echo "${file_path}" >> "$PROJECT_DIR/.types-pending"
            echo "SUPABASE TYPES REQUIRED: Migration contains DDL changes. Run 'npm run types:supabase' before committing, then delete .types-pending."
        fi
    fi
fi

exit 0
