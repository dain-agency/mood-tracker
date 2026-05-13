#!/bin/bash
# .claude/hooks/feature-flag-consistency.sh
# WARN: Feature flag and companion hook consistency checks
# Non-blocking — exit 0 with stderr for warnings

set -euo pipefail

json=$(cat)
file_path=$(echo "$json" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null || echo "")

# Only check TypeScript/React files
if [[ ! "$file_path" =~ \.(ts|tsx)$ ]]; then
    exit 0
fi

# Skip test and story files
if [[ "$file_path" =~ \.(test|spec|stories)\.(ts|tsx)$ ]]; then
    exit 0
fi

warnings=""

if [[ -f "$file_path" ]]; then

    # -------------------------------------------------------------------------
    # WARN: Using useTable without any preset import — should start from a preset
    # -------------------------------------------------------------------------
    if grep -qE "useTable\(" "$file_path" 2>/dev/null; then
        if ! grep -qE "PRESET_ENTITY_LIST|PRESET_MOBILE_LOOKUP|PRESET_SETTINGS|PRESET_DASHBOARD_SUMMARY|PRESET_LOG_VIEWER|PRESET_FINANCIAL|PRESET_LIVE_STATUS" "$file_path" 2>/dev/null; then
            warnings+="\nuseTable WITHOUT PRESET IMPORT\n"
            warnings+="$(grep -nE "useTable\(" "$file_path" | head -2)\n\n"
            warnings+="Always start from the closest preset and override specific flags:\n"
            warnings+="  import { useTable, PRESET_ENTITY_LIST } from '@/components/organisms/data-table';\n"
            warnings+="  const table = useTable({ ...PRESET_ENTITY_LIST, columns, data });\n"
        fi
    fi

    # -------------------------------------------------------------------------
    # WARN: Using WizardDialog without importing useWizard — must use the
    # companion hook for step state management
    # -------------------------------------------------------------------------
    if grep -qE "WizardDialog|<WizardDialog" "$file_path" 2>/dev/null; then
        if ! grep -qE "useWizard" "$file_path" 2>/dev/null; then
            warnings+="\nWizardDialog WITHOUT useWizard HOOK\n"
            warnings+="$(grep -nE "WizardDialog" "$file_path" | head -2)\n\n"
            warnings+="WizardDialog requires the useWizard companion hook for step management:\n"
            warnings+="  import { WizardDialog } from '@/components/composed/wizard-dialog';\n"
            warnings+="  import { useWizard } from '@/lib/hooks/use-wizard';\n"
        fi
    fi
fi

# Report warnings (non-blocking)
if [[ -n "$warnings" ]]; then
    echo "---" >&2
    echo "  CONSISTENCY WARNINGS in $file_path" >&2
    echo "---" >&2
    printf "%b\n" "$warnings" >&2
    echo "" >&2
    echo "Consider addressing these patterns for better code quality." >&2
fi

exit 0
