#!/bin/bash
# .claude/hooks/placeholder-check.sh
# BLOCK: Detect placeholder/dummy values in source code
# Exit code 2 feeds stderr to Claude for auto-fix

set -euo pipefail

json=$(cat)
file_path=$(echo "$json" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null || echo "")

# Only check source code files
if [[ ! "$file_path" =~ \.(ts|tsx|js|jsx)$ ]]; then
    exit 0
fi

# Skip test files, mocks, fixtures, seeds
if [[ "$file_path" =~ \.(test|spec)\.(ts|tsx)$ ]] || [[ "$file_path" =~ __tests__ ]]; then
    exit 0
fi
if [[ "$file_path" =~ \.mock\. ]] || [[ "$file_path" =~ /fixtures/ ]] || [[ "$file_path" =~ /seeds/ ]] || [[ "$file_path" =~ seed-data ]]; then
    exit 0
fi

# Skip type/config/story files
if [[ "$file_path" =~ \.d\.ts$ ]] || [[ "$file_path" =~ \.stories\. ]] || [[ "$file_path" =~ \.config\. ]]; then
    exit 0
fi

if [[ ! -f "$file_path" ]]; then
    exit 0
fi

violations=""

# CHECK 1: 'your-*' pattern
matches=$(grep -nE "['\"]your-[a-z0-9-]+" "$file_path" 2>/dev/null | grep -v "^\s*//" | head -3 || true)
if [[ -n "$matches" ]]; then
    violations+="\nPLACEHOLDER 'your-...' STRING DETECTED\n$matches\n\nReplace with actual value or read from config/environment.\n"
fi

# CHECK 2: CHANGEME / REPLACEME / PLACEHOLDER as a value inside a string
# literal. Camel-cased identifiers like `placeholderLength` (legitimate
# kibo-ui API field), `placeholderText`, etc. are not markers — the second
# `grep -vE 'placeholder[A-Z]'` is case-sensitive so it filters those out
# while still letting genuine string-literal placeholders trip the check.
# Tailwind data-attribute variant classes (`data-[placeholder]:...`, emitted by
# react-aria DateSegment for empty segments) are likewise legitimate, not
# markers. They MUST be written as a single static literal so Tailwind's source
# scanner can emit the rule. Obfuscating them to dodge this check silently
# breaks the build, so `data-[placeholder` is allowlisted here.
matches=$(grep -niE "['\"][^'\"]*(CHANGEME|REPLACEME|PLACEHOLDER)[^'\"]*['\"]" "$file_path" 2>/dev/null \
    | grep -v "^\s*//" \
    | grep -v "// placeholder" \
    | grep -vi 'placeholder=' \
    | grep -vi 'placeholder:' \
    | grep -vi 'data-\[placeholder' \
    | grep -vE 'placeholder[A-Z]' \
    | head -3 || true)
if [[ -n "$matches" ]]; then
    violations+="\nPLACEHOLDER MARKER DETECTED\n$matches\n\nReplace with actual implementation.\n"
fi

# CHECK 3: Fake UUIDs
matches=$(grep -nE "['\"]^00000000-0000-0000-0000-000000000000['\"]^|['\"]^ffffffff-ffff-ffff-ffff-ffffffffffff['\"]^|['\"]^12345678-" "$file_path" 2>/dev/null | grep -v "^\s*//" | head -3 || true)
if [[ -n "$matches" ]]; then
    violations+="\nFAKE/PLACEHOLDER UUID DETECTED\n$matches\n\nUse actual IDs from database or environment config.\n"
fi

# CHECK 4: xxx-xxx / abc-123 dummy patterns
matches=$(grep -nE "['\"]^xxx-|['\"]^abc-123|['\"]^test-test-test" "$file_path" 2>/dev/null | grep -v "^\s*//" | head -3 || true)
if [[ -n "$matches" ]]; then
    violations+="\nDUMMY VALUE DETECTED\n$matches\n\nReplace with actual value or read from config/environment.\n"
fi

# CHECK 5: TODO/FIXME inside string literals
matches=$(grep -nE "['\"]^TODO:|['\"]^FIXME:" "$file_path" 2>/dev/null | head -3 || true)
if [[ -n "$matches" ]]; then
    violations+="\nTODO/FIXME INSIDE STRING LITERAL\n$matches\n\nThis looks like an unfinished placeholder being used as a value.\n"
fi

# Report violations
if [[ -n "$violations" ]]; then
    echo "=============================================================================" >&2
    echo "  PLACEHOLDER VALUES in $file_path" >&2
    echo "=============================================================================" >&2
    echo "$violations" >&2
    echo "" >&2
    echo "Replace placeholder values with real implementations." >&2
    exit 2
fi

exit 0