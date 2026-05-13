#!/usr/bin/env bash
# Block writes/edits to apps/web/src/app/(authenticated)/** — the route group
# was unified into (app) on 2026-04-15 (Wave 3 UI remediation). Writing there
# creates duplicate-route collisions at build time and silent content drift
# against the canonical page under (app)/.
#
# If a legitimate reason arises to re-introduce (authenticated)/, remove this
# hook AND update .claude/rules/design-system.md.

set -uo pipefail

input="$(cat)"
tool="$(printf '%s' "$input" | jq -r '.tool_name // ""')"

case "$tool" in
  Write|Edit|NotebookEdit) ;;
  *) exit 0 ;;
esac

file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')"

case "$file_path" in
  *"apps/web/src/app/(authenticated)/"*|*"apps\\web\\src\\app\\(authenticated)\\"*)
    cat <<MSG >&2
BLOCKED: apps/web/src/app/(authenticated)/ was removed on 2026-04-15.
All authenticated routes live under apps/web/src/app/(app)/ now.

Target path: $file_path

If you are an agent: write to the equivalent path under (app)/ instead.
If a human reviewer intentionally wants to restore this route group, delete
this hook (.claude/hooks/route-group-guard.sh) and remove the matcher from
.claude/settings.json.
MSG
    exit 2
    ;;
esac

exit 0
