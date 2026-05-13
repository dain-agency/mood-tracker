#!/usr/bin/env bash
# archetype-enforcement.sh
# Pre-commit hook: detects manual page composition in domain components
# that should use EntityDetail, EntityList, or MultiStepFormShell instead.
#
# Scoped to: domains/*/components/*.tsx files only
# Ignores: stories, tests, sub-components (files not importing Page)

set -uo pipefail

# Resolve the target file: prefer stdin JSON (PostToolUse/PreToolUse), fall back
# to $1 (pre-commit / manual invocation). Never let an unset $1 crash the hook.
FILE=""
if [[ ! -t 0 ]]; then
  json=$(cat)
  if [[ -n "$json" ]]; then
    FILE=$(echo "$json" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
  fi
fi
FILE="${FILE:-${1:-}}"

if [[ -z "$FILE" ]]; then
  exit 0
fi

# Only check domain component files (not tests, stories, or hooks)
if [[ ! "$FILE" =~ domains/[^/]+/components/[^/]+\.tsx$ ]]; then
  exit 0
fi
if [[ "$FILE" =~ \.(test|stories)\. ]]; then
  exit 0
fi

# Only check files that import Page (page-level components)
if ! grep -q "from.*@/components/layout/page" "$FILE" 2>/dev/null; then
  exit 0
fi

VIOLATIONS=""

# Pattern 1: Page + Tabs + Badge = likely manual EntityDetail composition
if grep -q "from.*@/components/ui/tabs" "$FILE" 2>/dev/null && \
   grep -q "from.*@/components/ui/badge" "$FILE" 2>/dev/null && \
   ! grep -q "from.*@/components/layout/entity-detail" "$FILE" 2>/dev/null; then
  VIOLATIONS="${VIOLATIONS}\n  - Imports Page + Tabs + Badge without EntityDetail"
  VIOLATIONS="${VIOLATIONS}\n    Use <EntityDetail sections={[...]} tabs={[...]} badges={[...]} /> instead"
fi

# Pattern 2: Page + MasterTable/useTable = likely manual EntityList composition
if grep -q "from.*@/components/organisms/data-table" "$FILE" 2>/dev/null && \
   ! grep -q "from.*@/components/layout/entity-list" "$FILE" 2>/dev/null; then
  VIOLATIONS="${VIOLATIONS}\n  - Imports Page + MasterTable/useTable without EntityList"
  VIOLATIONS="${VIOLATIONS}\n    Use <EntityList columns={...} data={...} tableConfig={...} /> instead"
fi

# Pattern 3: Dialog + AnimatedProgress = likely manual MultiStepFormShell composition
if grep -q "from.*@/components/ui/dialog" "$FILE" 2>/dev/null && \
   grep -q "AnimatedProgress" "$FILE" 2>/dev/null && \
   ! grep -q "from.*@/components/layout/multi-step-form" "$FILE" 2>/dev/null; then
  VIOLATIONS="${VIOLATIONS}\n  - Imports Dialog + AnimatedProgress without MultiStepFormShell"
  VIOLATIONS="${VIOLATIONS}\n    Use <MultiStepFormShell container=\"dialog\" wizard={wizard} /> instead"
fi

if [[ -n "$VIOLATIONS" ]]; then
  echo "============================================================================="
  echo "  ARCHETYPE COMPOSITION VIOLATION (WARNING)"
  echo "============================================================================="
  echo ""
  echo "File: $FILE"
  echo ""
  echo -e "Detected manual page composition that should use archetype components:${VIOLATIONS}"
  echo ""
  echo "See: apps/web/src/components/layout/entity-detail.tsx"
  echo "     apps/web/src/components/layout/entity-list.tsx"
  echo "     apps/web/src/components/layout/multi-step-form-shell.tsx"
  echo ""
  echo "If this is intentional (e.g. a unique page that doesn't fit an archetype),"
  echo "add a comment: // archetype-override: <reason>"
  echo "============================================================================="
  # WARNING only — don't block commits during migration period
  exit 0
fi
