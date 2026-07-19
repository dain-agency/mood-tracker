#!/bin/bash
# .claude/hooks/type-safety.sh
# BLOCK: TypeScript compilation and any type detection
# Exit code 2 feeds stderr to Claude for auto-fix

set -euo pipefail

json=$(cat)
file_path=$(echo "$json" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null || echo "")

# Only check TypeScript files
if [[ ! "$file_path" =~ \.(ts|tsx)$ ]]; then
    exit 0
fi

# Skip declaration files
if [[ "$file_path" =~ \.d\.ts$ ]]; then
    exit 0
fi

# Skip test files
if [[ "$file_path" =~ \.(test|spec)\.(ts|tsx)$ ]] || [[ "$file_path" =~ __tests__/ ]]; then
    exit 0
fi

# Skip files that opt out via a top-of-file directive. The directive must
# appear in the first 20 lines, in a comment, with a short justification.
# Format: // @hook-skip:type-safety <reason>
# Use this only for instructional .ts files where prose about types (e.g.
# system prompts for an LLM reviewer) trips the regexes. .md files are
# already excluded by the extension check above.
if [[ -f "$file_path" ]] && head -20 "$file_path" 2>/dev/null | grep -q "@hook-skip:type-safety"; then
    exit 0
fi

violations=""

# =============================================================================
# CHECK 1: Explicit 'any' types
# =============================================================================
if [[ -f "$file_path" ]]; then
    # Check for : any (but not in comments or strings)
    any_matches=$(grep -nE ':[[:space:]]*any\b' "$file_path" 2>/dev/null | grep -v "// @allow-any" | grep -v "^\s*//" | head -5 || true)
    if [[ -n "$any_matches" ]]; then
        violations+="\nEXPLICIT 'any' TYPE DETECTED (BLOCKING)\n$any_matches\n\nReplace with proper types:\n  - Specific types: string, number, boolean, etc.\n  - unknown + type guards for truly unknown data\n  - Generics <T> for flexible typing\n  - Interface/type definitions for objects\n"
    fi

    # Check for 'as any' assertions
    as_any_matches=$(grep -nE '\bas[[:space:]]+any\b' "$file_path" 2>/dev/null | grep -v "// @allow-any" | head -3 || true)
    if [[ -n "$as_any_matches" ]]; then
        violations+="\n'as any' TYPE ASSERTION DETECTED (BLOCKING)\n$as_any_matches\n\nThis bypasses type safety entirely. Instead:\n  - Fix the underlying type mismatch\n  - Use proper type guards\n  - Create a more specific type assertion (as SomeType)\n"
    fi

    # Check for @ts-ignore without explanation
    ts_ignore=$(grep -n "@ts-ignore" "$file_path" 2>/dev/null | grep -v "@ts-ignore:" | grep -v "// @ts-ignore //" | head -3 || true)
    if [[ -n "$ts_ignore" ]]; then
        violations+="\n'@ts-ignore' WITHOUT EXPLANATION (BLOCKING)\n$ts_ignore\n\nEither:\n  - Fix the actual type error\n  - Use @ts-expect-error with explanation\n  - Add comment explaining why\n"
    fi

    # Check for catch (error: any)
    catch_any=$(grep -nE 'catch[[:space:]]*\([^)]*:[[:space:]]*any\b' "$file_path" 2>/dev/null | head -3 || true)
    if [[ -n "$catch_any" ]]; then
        violations+="\n'catch (error: any)' DETECTED (BLOCKING)\n$catch_any\n\nAlways use 'unknown' for caught errors:\n  catch (error: unknown) {\n    if (error instanceof Error) {\n      logger.error(error.message)\n    }\n  }\n"
    fi
fi

# Report violations
if [[ -n "$violations" ]]; then
    echo "=============================================================================" >&2
    echo "  TYPE SAFETY VIOLATIONS in $file_path" >&2
    echo "=============================================================================" >&2
    echo "$violations" >&2
    echo "" >&2
    echo "Fix these issues to continue." >&2
    exit 2
fi

# =============================================================================
# NON-BLOCKING WARNINGS
# =============================================================================
warnings=""

if [[ -f "$file_path" ]]; then
    # JSON.parse without validation
    if grep -q "JSON\.parse" "$file_path" 2>/dev/null; then
        if ! grep -qE "\bz\b\.|zodResolver|\.safeParse|Schema|schema|validate" "$file_path" 2>/dev/null; then
            json_parse_lines=$(grep -n "JSON\.parse" "$file_path" 2>/dev/null | grep -v "// @allow-any" | head -3 || true)
            if [[ -n "$json_parse_lines" ]]; then
                warnings+="\nJSON.parse() WITHOUT VALIDATION\n$json_parse_lines\n\nJSON.parse() returns 'any', defeating type safety. Validate the output:\n  const result = mySchema.parse(JSON.parse(str))    // Zod\n  const data: unknown = JSON.parse(str)              // Type as unknown + guard\n"
            fi
        fi
    fi

    # process.env compared to a number
    env_num_cmp=$(grep -nE "process\.env\.\w+\s*[!=]==?\s*[0-9]" "$file_path" 2>/dev/null | head -3 || true)
    if [[ -n "$env_num_cmp" ]]; then
        warnings+="\nprocess.env COMPARED TO NUMBER\n$env_num_cmp\n\nEnvironment variables are always strings.\n  parseInt(process.env.PORT || '3000', 10)\n"
    fi

    # Excessive type assertions
    as_count=$(grep -cE "\bas [A-Z][a-zA-Z]+" "$file_path" 2>/dev/null || true)
    if [[ "$as_count" -gt 3 ]]; then
        warnings+="\nMULTIPLE TYPE ASSERTIONS ($as_count 'as Type' found)\n\nExcessive type assertions bypass type checking. Consider:\n  - Type guards: if (isUser(x)) { ... }\n  - Zod validation for external data\n  - Fixing underlying type mismatches\n"
    fi
fi

if [[ -n "$warnings" ]]; then
    echo "---" >&2
    echo "  TYPE SAFETY WARNINGS in $file_path" >&2
    echo "---" >&2
    echo "$warnings" >&2
fi

exit 0