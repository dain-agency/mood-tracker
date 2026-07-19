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
    #
    # The previous implementation matched the catch-opening line and then `next`-ed
    # past the rest of that line. That meant single-line catches like
    # `} catch (e) { handler(); }` were always flagged as empty: the body chars
    # on the same line were never scanned, only subsequent lines. The fix:
    # process the chars AFTER the matched `{` on the catch line, then continue
    # tracking on subsequent lines if depth hasn't closed. `has_code` is also
    # scoped to body chars (any non-whitespace inside the braces) rather than
    # matching the whole line.
    empty_catches=$(awk '
      function process(s,    i, c) {
        for (i = 1; i <= length(s); i++) {
          c = substr(s, i, 1)
          if (c == "{") depth++
          else if (c == "}") {
            depth--
            if (depth == 0) {
              if (!has_code) print catch_line_no ": " catch_line
              found = 0
              return
            }
          }
          else if (c !~ /[ \t]/) has_code = 1
        }
      }
      /catch\s*\([^)]*\)\s*\{/ {
        match($0, /catch\s*\([^)]*\)\s*\{/)
        found = 1; depth = 1; has_code = 0
        catch_line = $0; catch_line_no = NR
        process(substr($0, RSTART + RLENGTH))
        next
      }
      found { process($0) }
    ' "$file_path" 2>/dev/null | head -3)
    if [[ -n "$empty_catches" ]]; then
        violations+="\nEMPTY CATCH BLOCK DETECTED (BLOCKING)\n$empty_catches\n\nNever swallow errors silently. Always:\n  catch (error: unknown) {\n    if (error instanceof Error) {\n      logger.error('Operation failed', { error: error.message })\n    }\n    throw error  // Re-throw if calling code should handle\n  }\n"
    fi

    # CHECK 2: catch with just console.log
    if awk '/catch\s*\([^)]*\)\s*\{/{start=NR; content=""} start && NR>start{content=content $0} /\}/ && start && NR>start{if(content ~ /^\s*console\.(log|error)\([^)]*\)\s*;?\s*$/){print start}; start=0}' "$file_path" 2>/dev/null | head -1 | grep -q .; then
        violations+="\nCATCH BLOCK WITH ONLY console.log (BLOCKING)\n\nconsole.log is not proper error handling. Replace with:\n  logger.error() for server-side logging\n  toast.error() for user feedback\n"
    fi

    # CHECK 3: Unhandled async (not in test files)
    if [[ "$is_test" == false ]]; then
        # Skip these legitimate `.then` patterns (folded up from the
        # portunus-pipelines variant, 2026-07-18):
        # - dynamic imports: `import(...).then(m => m.X)` (next/dynamic and
        #   React.lazy use this to pluck the named export; errors surface
        #   via the framework's loading/error boundaries, not user catch)
        # - inline `// safe-then` marker for reviewed call sites
        then_no_catch=$(grep -n "\.then(" "$file_path" 2>/dev/null \
            | grep -v "\.catch(\|\.finally(" \
            | grep -v "import(.*).then\|import(.*\$\|// safe-then" \
            | head -3 || true)
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