#!/bin/bash
# .claude/hooks/code-quality.sh
# WARN: General code quality checks
# Non-blocking but shows warnings

set -euo pipefail

json=$(cat)
file_path=$(echo "$json" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null || echo "")

# Only check code files
if [[ ! "$file_path" =~ \.(ts|tsx|js|jsx)$ ]]; then
    exit 0
fi

# Skip test files for some checks
is_test=false
if [[ "$file_path" =~ \.(test|spec)\.(ts|tsx|js|jsx)$ ]] || [[ "$file_path" =~ __tests__ ]]; then
    is_test=true
fi

warnings=""

if [[ -f "$file_path" ]]; then

    # CHECK 1: console.log (not in tests)
    if [[ "$is_test" == false ]]; then
        console_logs=$(grep -n 'console\.log(' "$file_path" 2>/dev/null | head -5 || true)
        if [[ -n "$console_logs" ]]; then
            warnings+="\nconsole.log STATEMENTS FOUND\n$console_logs\n\nRemove or replace with logger.\n"
        fi
    fi

    # CHECK 2: TODO/FIXME without ticket
    todos=$(grep -n 'TODO\|FIXME\|HACK\|XXX' "$file_path" 2>/dev/null | grep -v '#[0-9]\|ticket\|issue\|jira' | head -3 || true)
    if [[ -n "$todos" ]]; then
        warnings+="\nTODO/FIXME WITHOUT TICKET REFERENCE\n$todos\n\nAdd ticket reference: // TODO(#123): description\n"
    fi

    # CHECK 3: Commented-out code
    commented_code=$(grep -nE '^\s*//\s*(const|let|var|function|if|for|while|return|import|export)\s' "$file_path" 2>/dev/null | head -3 || true)
    if [[ -n "$commented_code" ]]; then
        warnings+="\nCOMMENTED-OUT CODE DETECTED\n$commented_code\n\nDelete commented code - git remembers everything.\n"
    fi

    # CHECK 4: File size
    line_count=$(wc -l < "$file_path")
    if [[ "$line_count" -gt 500 ]]; then
        warnings+="\nLARGE FILE ($line_count lines)\n\nFiles over 500 lines are harder to maintain. Consider splitting.\n"
    elif [[ "$line_count" -gt 300 ]]; then
        warnings+="\nFILE GETTING LARGE ($line_count lines)\n\nConsider splitting if it grows further.\n"
    fi

    # CHECK 5: Magic numbers
    magic_numbers=$(grep -nE '[\(,=<>]\s*[2-9][0-9]+\s*[\),;\]]' "$file_path" 2>/dev/null \
        | grep -v 'const\|let\|var\|port\|status\|code\|index\|length\|width\|height\|size\|count\|max\|min\|timeout\|delay\|duration\|year\|month\|day\|hour\|minute\|second\|millisecond\|px\|rem\|em\|%\|grid\|flex' \
        | head -3 || true)
    if [[ -n "$magic_numbers" ]]; then
        warnings+="\nPOSSIBLE MAGIC NUMBERS\n$magic_numbers\n\nExtract to named constants: const MAX_RETRIES = 3\n"
    fi

    # CHECK 6: Deep nesting
    deep_nesting=$(awk '/^(\t{5,}|\ {20,})/' "$file_path" 2>/dev/null | head -3 || true)
    if [[ -n "$deep_nesting" ]]; then
        warnings+="\nDEEP NESTING DETECTED\n\nConsider early returns, extract functions, or async/await.\n"
    fi

    # CHECK 7: eslint-disable without comment
    eslint_disable=$(grep -n 'eslint-disable' "$file_path" 2>/dev/null | grep -v '// ' | head -3 || true)
    if [[ -n "$eslint_disable" ]]; then
        warnings+="\neslint-disable WITHOUT EXPLANATION\n$eslint_disable\n\nAdd explanation why the rule is disabled.\n"
    fi

    # CHECK 8: Duplicate imports
    imports=$(grep "^import.*from" "$file_path" 2>/dev/null | sed "s/.*from ['\"]^//;s/['\"]^.*//" | sort | uniq -d || true)
    if [[ -n "$imports" ]]; then
        warnings+="\nDUPLICATE IMPORTS DETECTED\nModules imported multiple times: $imports\n\nConsolidate into single import statement.\n"
    fi

    # CHECK 9: US spellings (UK required for user-facing text)
    if [[ "$file_path" =~ \.(tsx|jsx)$ ]]; then
        us_words="analyze|analyzing|organization|organizations|customize|customizing|customizable|customization|optimize|optimizing|optimization|authorize|authorizing|authorization|finalize|finalizing|visualize|visualizing|visualization|summarize|summarizing|categorize|categorizing|prioritize|prioritizing|standardize|standardizing|normalize|normalizing|synchronize|synchronizing|minimize|minimizing|maximize|maximizing"
        us_matches=$(grep -niE "\b($us_words)\b" "$file_path" 2>/dev/null \
            | grep -v "^\s*//" \
            | grep -v "import\|from\|require" \
            | grep -v "// @allow-us" \
            | head -5 || true)
        if [[ -n "$us_matches" ]]; then
            warnings+="\nUS SPELLING DETECTED (UK required)\n$us_matches\n\nUse UK spellings: analyze->analyse, organization->organisation, customize->customise\n"
        fi
    fi
fi

# Report warnings (non-blocking)
if [[ -n "$warnings" ]]; then
    echo "---" >&2
    echo "  CODE QUALITY SUGGESTIONS for $file_path" >&2
    echo "---" >&2
    echo "$warnings" >&2
fi

exit 0