#!/bin/bash
# .claude/hooks/import-hierarchy.sh
# BLOCK/WARN: Import hierarchy violations in domain and app components
# Exit code 2 for BLOCK, exit code 0 with stderr for WARN

set -euo pipefail

json=$(cat)
file_path=$(echo "$json" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null || echo "")

# Only check .tsx files
if [[ ! "$file_path" =~ \.tsx$ ]]; then
    exit 0
fi

# Skip test and story files
if [[ "$file_path" =~ \.(test|spec|stories)\.tsx$ ]]; then
    exit 0
fi

# Only check files in domains/*/components/ and app/ directories
if [[ ! "$file_path" =~ domains/[^/]+/components/ ]] && [[ ! "$file_path" =~ /app/ ]]; then
    exit 0
fi

blocks=""
warnings=""

if [[ -f "$file_path" ]]; then

    # -------------------------------------------------------------------------
    # WARN: Importing 3+ different modules from components/ui/ — suggest
    # checking composed/organisms for an existing higher-level component
    # -------------------------------------------------------------------------
    ui_imports=$(grep -oE "from ['\"]@/components/ui/[^'\"']+" "$file_path" 2>/dev/null | sort -u | wc -l | tr -d ' ')
    if [[ "$ui_imports" -ge 3 ]]; then
        warnings+="\nIMPORTING $ui_imports DISTINCT ATOM MODULES FROM components/ui/\n"
        warnings+="$(grep -nE "from ['\"]@/components/ui/" "$file_path" | head -5)\n\n"
        warnings+="When importing 3+ atoms, a composed component or organism likely exists.\n"
        warnings+="Check components/composed/ and components/organisms/ first.\n"
    fi

    # -------------------------------------------------------------------------
    # WARN: Importing from framer-motion or motion directly — must use
    # @herbert/ui animation primitives instead
    # -------------------------------------------------------------------------
    if grep -qE "from ['\"]framer-motion['\"]|from ['\"]motion['\"]" "$file_path" 2>/dev/null; then
        warnings+="\nDIRECT FRAMER MOTION / MOTION IMPORT DETECTED\n"
        warnings+="$(grep -nE "from ['\"]framer-motion['\"]|from ['\"]motion['\"]" "$file_path" | head -3)\n\n"
        warnings+="Use @herbert/ui animation primitives instead:\n"
        warnings+="  import { Fade, Slide, AutoHeight, ... } from '@herbert/ui';\n"
    fi

    # -------------------------------------------------------------------------
    # BLOCK: Cross-domain import — domains/X/components/ importing from
    # domains/Y/components/ where X != Y
    # -------------------------------------------------------------------------
    if [[ "$file_path" =~ domains/([^/]+)/components/ ]]; then
        source_domain="${BASH_REMATCH[1]}"
        cross_imports=$(grep -nE "from ['\"]@/domains/[^/]+/components/" "$file_path" 2>/dev/null \
            | grep -v "from ['\"]@/domains/${source_domain}/components/" || true)
        if [[ -n "$cross_imports" ]]; then
            blocks+="\nCROSS-DOMAIN IMPORT VIOLATION (BLOCKING)\n"
            blocks+="$cross_imports\n\n"
            blocks+="Domain components in domains/${source_domain}/components/ must not import\n"
            blocks+="from other domain component folders. Extract shared code to:\n"
            blocks+="  - components/composed/   (molecules)\n"
            blocks+="  - components/organisms/  (complex reusable sections)\n"
            blocks+="  - packages/ui/           (cross-app shared components)\n"
        fi
    fi
fi

# Report blocking violations
if [[ -n "$blocks" ]]; then
    echo "=============================================================================" >&2
    echo "  IMPORT HIERARCHY VIOLATIONS in $file_path" >&2
    echo "=============================================================================" >&2
    printf "%b\n" "$blocks" >&2
    echo "" >&2
    echo "Fix blocking issues to continue." >&2
    exit 2
fi

# Report warnings (non-blocking)
if [[ -n "$warnings" ]]; then
    echo "---" >&2
    echo "  IMPORT HIERARCHY WARNINGS in $file_path" >&2
    echo "---" >&2
    printf "%b\n" "$warnings" >&2
    echo "" >&2
    echo "Consider addressing these patterns for better code quality." >&2
fi

exit 0
