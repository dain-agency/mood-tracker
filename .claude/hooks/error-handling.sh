#!/bin/bash
# .claude/hooks/error-handling.sh
# BLOCK: Error handling pattern enforcement
# Exit code 2 feeds stderr to Claude for auto-fix

set -euo pipefail

json=$(cat)
file_path=$(echo "$json" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null || echo "")

# Only check TypeScript files
if [[ ! "$file_path" =~ \.(ts|tsx)$ ]]; then
    exit 0
fi

# Skip test files for some checks
is_test=false
if [[ "$file_path" =~ \.(test|spec)\.(ts|tsx)$ ]] || [[ "$file_path" =~ __tests__ ]]; then
    is_test=true
fi

violations=""

if [[ -f "$file_path" ]]; then
    content=$(cat "$file_path")

    # CHECK 1: Empty catch blocks (awk-based brace depth tracking)
    if awk '
      /catch\s*\([^)]*\)\s*\{/ { found=1; depth=1; has_code=0; next }
      found {
        for (i=1; i<=length($0); i++) {
          c = substr($0, i, 1)
          if (c == "{") depth++
          if (c == "}") depth--
          if (depth == 0) {
            if (!has_code) print NR": "$0
            found=0
            break
          }
        }
        if (found && /[a-zA-Z]/) has_code=1
      }
    ' "$file_path" 2>/dev/null | head -1 | grep -q .; then
        empty_catch=$(grep -n "catch" "$file_path" | head -3)
        violations+="\nEMPTY CATCH BLOCK DETECTED (BLOCKING)\n$empty_catch\n\nNever swallow errors silently. Always:\n  catch (error: unknown) {\n    if (error instanceof Error) {\n      logger.error('Operation failed', { error: error.message })\n    }\n    throw error  // Re-throw if calling code should handle\n  }\n"
    fi

    # CHECK 2: catch with just console.log
    if awk '/catch\s*\([^)]*\)\s*\{/{start=NR; content=""} start && NR>start{content=content $0} /\}/ && start && NR>start{if(content ~ /^\s*console\.(log|error)\([^)]*\)\s*;?\s*$/){print start}; start=0}' "$file_path" 2>/dev/null | head -1 | grep -q .; then
        violations+="\nCATCH BLOCK WITH ONLY console.log (BLOCKING)\n\nconsole.log is not proper error handling. Replace with:\n  logger.error() for server-side logging\n  toast.error() for user feedback\n"
    fi

    # CHECK 3: Unhandled async (not in test files)
    if [[ "$is_test" == false ]]; then
        then_no_catch=$(grep -n "\.then(" "$file_path" 2>/dev/null | grep -v "\.catch(\|\.finally(" | head -3 || true)
        if [[ -n "$then_no_catch" ]]; then
            violations+="\nPROMISE .then() WITHOUT .catch() (BLOCKING)\n$then_no_catch\n\nAlways handle promise rejections:\n  .then(result => handleResult(result))\n  .catch(error => { logger.error('Failed', { error }) })\n"
        fi
    fi

    # CHECK 4: throw new Error without message
    empty_throw=$(grep -n "throw new Error()" "$file_path" 2>/dev/null | head -3 || true)
    if [[ -n "$empty_throw" ]]; then
        violations+="\nthrow new Error() WITHOUT MESSAGE (BLOCKING)\n$empty_throw\n\nAlways provide descriptive error messages.\n"
    fi
fi

# Report violations
if [[ -n "$violations" ]]; then
    echo "=============================================================================" >&2
    echo "  ERROR HANDLING VIOLATIONS in $file_path" >&2
    echo "=============================================================================" >&2
    echo "$violations" >&2
    echo "" >&2
    echo "Fix these issues to continue." >&2
    exit 2
fi

exit 0