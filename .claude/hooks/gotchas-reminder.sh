#!/bin/bash
# .claude/hooks/gotchas-reminder.sh
# PostToolUse: Remind to check gotchas when writing SQL or component files.
# Non-blocking (exit 0) — just prints a reminder.

set -euo pipefail

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only check Write/Edit tools
case "$tool_name" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

file_path=$(echo "$json" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

# Check if it's a SQL migration or database file
if [[ "$file_path" =~ \.sql$ ]] || [[ "$file_path" =~ supabase/migrations/ ]]; then
    echo "GOTCHAS REMINDER: You're writing SQL. Did you invoke /database-gotchas? Key risks: SECURITY DEFINER needs REVOKE, partitioning destroys triggers/RLS, children don't inherit parent RLS."
fi

# Check if it's a frontend component or test
if [[ "$file_path" =~ apps/web/src/ ]] && [[ "$file_path" =~ \.(tsx|ts)$ ]]; then
    echo "GOTCHAS REMINDER: You're writing frontend code. Did you invoke /frontend-gotchas? Key risks: React Query cache invalidation, cn() for Tailwind overrides, fresh QueryClient per test."
fi

exit 0
