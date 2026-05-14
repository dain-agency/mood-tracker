#!/bin/bash
# .claude/hooks/test-enforcement.sh
# BLOCK: Ensures test files exist for touched source files
# Exit code 2 feeds stderr to Claude for auto-fix

set -euo pipefail

json=$(cat)
file_path=$(echo "$json" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null || echo "")

# Only check TypeScript files
if [[ ! "$file_path" =~ \.(ts|tsx)$ ]]; then
    exit 0
fi

# If this IS a test file, check test quality instead
if [[ "$file_path" =~ \.(test|spec)\.(ts|tsx)$ ]]; then
    if [[ -f "$file_path" ]]; then
        test_violations=""

        # Check for .only() in test files
        only_matches=$(grep -n "\.only(" "$file_path" 2>/dev/null | head -3 || true)
        if [[ -n "$only_matches" ]]; then
            test_violations+="\n.only() FOUND IN TEST FILE\n$only_matches\n\nRemove .only() - it prevents other tests from running.\n"
        fi

        # Check for missing await on async assertions
        missing_await=$(grep -nE "expect\(.*\)\.(resolves|rejects)" "$file_path" 2>/dev/null | grep -v "await" | head -3 || true)
        if [[ -n "$missing_await" ]]; then
            test_violations+="\nMISSING await ON ASYNC ASSERTION\n$missing_await\n\nWithout await, async assertions silently pass even when they should fail:\n  await expect(promise).resolves.toBe(value)\n"
        fi

        if [[ -n "$test_violations" ]]; then
            echo "=============================================================================" >&2
            echo "  TEST QUALITY VIOLATIONS in $file_path" >&2
            echo "=============================================================================" >&2
            echo "$test_violations" >&2
            echo "" >&2
            echo "Fix these issues to continue." >&2
            exit 2
        fi
    fi
    exit 0
fi

# Skip test directories, type definitions, configs, index, stories, mocks, fixtures
if [[ "$file_path" =~ __tests__/ ]] || [[ "$file_path" =~ /test/ ]] || [[ "$file_path" =~ /tests/ ]]; then
    exit 0
fi
if [[ "$file_path" =~ \.d\.ts$ ]] || [[ "$file_path" =~ \.types\.ts$ ]]; then
    exit 0
fi
if [[ "$file_path" =~ config\.(ts|tsx)$ ]] || [[ "$file_path" =~ \.config\.(ts|tsx)$ ]]; then
    exit 0
fi
if [[ "$file_path" =~ index\.(ts|tsx)$ ]]; then
    exit 0
fi
filename=$(basename "$file_path")
if [[ "$filename" =~ ^(constants|types|interfaces|enums)\.(ts|tsx)$ ]]; then
    exit 0
fi
if [[ "$filename" =~ \.stories\.(ts|tsx)$ ]]; then
    exit 0
fi
if [[ "$filename" =~ \.mock\.(ts|tsx)$ ]] || [[ "$filename" =~ ^mock ]]; then
    exit 0
fi
if [[ "$filename" =~ \.fixture\.(ts|tsx)$ ]] || [[ "$file_path" =~ /fixtures/ ]]; then
    exit 0
fi

# =============================================================================
# DETERMINE EXPECTED TEST FILE LOCATION
# =============================================================================

dir=$(dirname "$file_path")
base=$(basename "$file_path" | sed 's/\.[^.]*$//')
ext="${file_path##*.}"

# Possible test file locations
test_locations=(
    "${dir}/${base}.test.${ext}"
    "${dir}/${base}.spec.${ext}"
    "${dir}/__tests__/${base}.test.${ext}"
    "${dir}/__tests__/${base}.spec.${ext}"
    "${dir}/tests/${base}.test.${ext}"
    "${dir}/tests/${base}.spec.${ext}"
    "$(dirname "$dir")/__tests__/${base}.test.${ext}"
    "$(dirname "$dir")/__tests__/${base}.spec.${ext}"
)

# Check if any test file exists
test_found=false
for test_file in "${test_locations[@]}"; do
    if [[ -f "$test_file" ]]; then
        test_found=true
        break
    fi
done

if [[ "$test_found" == false ]]; then
    echo "=============================================================================" >&2
    echo "  MISSING TEST FILE (BLOCKING)" >&2
    echo "=============================================================================" >&2
    echo "" >&2
    echo "Source file: $file_path" >&2
    echo "" >&2
    echo "Expected test file at one of:" >&2
    echo "  ${dir}/${base}.test.${ext}" >&2
    echo "  ${dir}/__tests__/${base}.test.${ext}" >&2
    echo "" >&2
    echo "Create this test file before continuing." >&2
    exit 2
fi

exit 0