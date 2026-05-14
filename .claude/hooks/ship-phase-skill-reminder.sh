#!/bin/bash
# .claude/hooks/ship-phase-skill-reminder.sh
# BLOCK: Enforce mandatory gates when marking ship phases as done.
# Ship v2 phase numbering. Fires on Edit/Write to progress.md files.
# Exit code 2 blocks the edit and feeds stderr to Claude for correction.

set -euo pipefail

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

file_path=""
new_text=""

case "$tool_name" in
    Write)
        file_path=$(echo "$json" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
        new_text=$(echo "$json" | jq -r '.tool_input.content // empty' 2>/dev/null || echo "")
        ;;
    Edit|MultiEdit)
        file_path=$(echo "$json" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
        new_text=$(echo "$json" | jq -r '.tool_input.new_string // empty' 2>/dev/null || echo "")
        ;;
    *)
        exit 0
        ;;
esac

# Only check progress.md files
if ! echo "$file_path" | grep -qE 'progress\.md$' 2>/dev/null; then
    exit 0
fi

# Phase 8: E2E Testing
if echo "$new_text" | grep -qiE '8\.\s*E2E.*done' 2>/dev/null; then
    echo "PHASE 8 GATE: Did you invoke Skill('ship-e2e')? E2E testing must use browser automation against user journeys, not be skipped." >&2
fi

# Phase 9: Human Review -- warn only
if echo "$new_text" | grep -qiE '9\.\s*Human Review.*done' 2>/dev/null; then
    echo "PHASE 9 GATE: Did the user explicitly approve? Human gates are blocking -- do not mark done without user confirmation." >&2
fi

# Phase 10: PR -- BLOCK if Greptile not addressed
if echo "$new_text" | grep -qiE '10\.\s*PR.*done' 2>/dev/null; then
    echo "===============================================================" >&2
    echo "  PHASE 10 GATE: MANDATORY PR CHECKLIST" >&2
    echo "===============================================================" >&2
    echo "" >&2
    echo "Before marking Phase 10 done, verify ALL of these:" >&2
    echo "" >&2
    echo "  * Invoked Skill('pr-feedback', '<pr-number>') or fetched" >&2
    echo "    Greptile comments via gh api repos/.../pulls/.../comments" >&2
    echo "  * Each Greptile comment addressed (fixed or acknowledged)" >&2
    echo "  * Each comment replied to on GitHub with fix description" >&2
    echo "  * Fixes pushed and re-review triggered if >5 lines changed" >&2
    echo "  * Re-review cycle repeated until no new blocking comments" >&2
    echo "" >&2
    echo "If ANY are missing, do NOT mark Phase 10 as done." >&2
    echo "===============================================================" >&2
    exit 2
fi

exit 0