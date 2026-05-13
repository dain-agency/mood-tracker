#!/bin/bash
# .claude/hooks/schema-check-gate.sh
# PreToolUse (Write|Edit): BLOCKS writes to query, validator, action, and
# migration files unless the Supabase schema for the relevant domain has
# been read in this session.
#
# How it works:
#   - When a Read tool loads a file matching packages/types/src/supabase.ts
#     or packages/queries/src/*/types.ts, the PostToolUse partner hook
#     (schema-check-mark.sh) touches .claude/.schema-read
#   - This hook checks for that marker before allowing writes to
#     data-layer files
#   - The marker is session-scoped: it's cleaned up by session-start.sh
#     or ages out after 4 hours

set -euo pipefail

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only gate Write and Edit
case "$tool_name" in
    Write|Edit|MultiEdit) ;;
    *) exit 0 ;;
esac

file_path=$(echo "$json" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
[ -z "$file_path" ] && exit 0

# Which files need schema verification?
needs_schema=false

# Query functions
if [[ "$file_path" =~ packages/queries/src/ && ! "$file_path" =~ \.test\. ]]; then
    needs_schema=true
fi

# Validator schemas
if [[ "$file_path" =~ packages/validators/src/ && ! "$file_path" =~ \.test\. ]]; then
    needs_schema=true
fi

# Server actions
if [[ "$file_path" =~ /actions/ && "$file_path" =~ \.(ts|tsx)$ && ! "$file_path" =~ \.test\. ]]; then
    needs_schema=true
fi

# SQL migrations
if [[ "$file_path" =~ supabase/migrations/ || "$file_path" =~ \.sql$ ]]; then
    needs_schema=true
fi

# Not a data-layer file — allow
if [ "$needs_schema" = "false" ]; then
    exit 0
fi

# Check for the marker file
PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || { cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd; })"
MARKER="$PROJECT_DIR/.claude/.schema-read"

if [ -f "$MARKER" ]; then
    # Check age — expire after 4 hours (14400 seconds)
    if [ "$(uname)" = "Darwin" ]; then
        age=$(( $(date +%s) - $(stat -f %m "$MARKER") ))
    else
        age=$(( $(date +%s) - $(stat -c %Y "$MARKER") ))
    fi
    if [ "$age" -lt 14400 ]; then
        exit 0
    fi
fi

# BLOCK — schema not read
cat <<'BLOCK'
=============================================================================
  SCHEMA CHECK REQUIRED (BLOCKING)
=============================================================================

You are writing to a data-layer file but have not read the Supabase schema
in this session. This prevents column name guessing and type mismatches.

Before writing queries, validators, actions, or migrations, you MUST:

  1. Read the relevant types:
     packages/types/src/supabase.ts (search for the table)
     OR packages/queries/src/<domain>/types.ts

  2. OR run: /schema <schema>.<table>
     (queries the live database for column names and types)

Read the schema file first, then retry this edit.

=============================================================================
BLOCK

exit 1
