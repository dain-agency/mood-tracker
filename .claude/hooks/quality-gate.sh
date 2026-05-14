#!/bin/bash
# .claude/hooks/quality-gate.sh
# Fast quality checks on modified files only.
# Heavy checks (tsc, full test suite, eslint) moved to /pr-checklist.
# Exit code 2 blocks completion and feeds errors back.

set -euo pipefail

json=$(cat)

# Check if this is already a stop hook continuation (prevent loops)
stop_active=$(echo "$json" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
if [[ "$stop_active" == "true" ]]; then
    exit 0
fi

echo "" >&2
echo "=============================================================================" >&2
echo "  RUNNING QUALITY GATE CHECKS" >&2
echo "=============================================================================" >&2

blocking_errors=""
warnings=""

# Get modified TS/TSX files once
modified_ts=$(git diff --name-only HEAD 2>/dev/null | grep -E '\.(ts|tsx)$' || true)

# Skip if no TS files changed
if [[ -z "$modified_ts" ]]; then
    echo "" >&2
    echo "  QUALITY GATE PASSED (no TS changes)" >&2
    echo "" >&2
    exit 0
fi

# CHECK 1: any types in modified files
echo "  Checking for any types..." >&2
for file in $modified_ts; do
    if [[ "$file" =~ \.(test|spec)\.(ts|tsx)$ ]] || [[ "$file" =~ __tests__ ]]; then
        continue
    fi
    if [[ -f "$file" ]]; then
        any_count=$(grep -cE ": any|as any" "$file" 2>/dev/null || echo "0")
        if [[ "$any_count" -gt 0 ]]; then
            blocking_errors+="\n'any' TYPE FOUND in $file ($any_count occurrences)\n$(grep -nE ": any|as any" "$file" | head -3)\n"
        fi
    fi
done

# CHECK 2: Missing test files for modified source
echo "  Checking test coverage..." >&2
for file in $modified_ts; do
    if [[ "$file" =~ \.(test|spec)\.(ts|tsx)$ ]] || [[ "$file" =~ __tests__ ]]; then
        continue
    fi
    if [[ "$file" =~ \.d\.ts$ ]] || [[ "$file" =~ \.types\.ts$ ]] || [[ "$file" =~ config\. ]] || [[ "$file" =~ index\.(ts|tsx)$ ]]; then
        continue
    fi
    if [[ "$file" =~ \.stories\. ]] || [[ "$file" =~ \.mock\. ]] || [[ "$file" =~ /fixtures/ ]]; then
        continue
    fi
    if [[ -f "$file" ]]; then
        dir=$(dirname "$file")
        base=$(basename "$file" | sed 's/\.[^.]*$//')
        ext="${file##*.}"
        test_found=false
        for test_path in "${dir}/${base}.test.${ext}" "${dir}/__tests__/${base}.test.${ext}"; do
            if [[ -f "$test_path" ]]; then
                test_found=true
                break
            fi
        done
        if [[ "$test_found" == false ]]; then
            blocking_errors+="\nMISSING TEST FILE for $file\nExpected: ${dir}/${base}.test.${ext}\n"
        fi
    fi
done

# CHECK 3: Console.log in production code
echo "  Checking for console.log..." >&2
for file in $modified_ts; do
    if [[ "$file" =~ \.(test|spec)\.(ts|tsx)$ ]] || [[ "$file" =~ __tests__ ]]; then
        continue
    fi
    if [[ -f "$file" ]]; then
        console_count=$(grep -cE "console\.log" "$file" 2>/dev/null || echo "0")
        if [[ "$console_count" -gt 0 ]]; then
            warnings+="\nconsole.log in $file ($console_count occurrences)\n"
        fi
    fi
done

echo "" >&2

if [[ -n "$blocking_errors" ]]; then
    echo "=============================================================================" >&2
    echo "  QUALITY GATE FAILED - BLOCKING ISSUES" >&2
    echo "=============================================================================" >&2
    echo "$blocking_errors" >&2
    echo "" >&2
    echo "Fix these issues before completing this task." >&2
    exit 2
fi

if [[ -n "$warnings" ]]; then
    echo "---" >&2
    echo "  WARNINGS (non-blocking)" >&2
    echo "---" >&2
    echo "$warnings" >&2
fi

echo "" >&2
echo "  QUALITY GATE PASSED" >&2
echo "" >&2

exit 0