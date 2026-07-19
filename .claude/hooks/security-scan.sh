#!/bin/bash
# .claude/hooks/security-scan.sh
# BLOCK: Security vulnerability detection in content added by Edit/MultiEdit/Write
# Exit code 2 feeds stderr to Claude for auto-fix

set -euo pipefail

json=$(cat)
tool_name=$(printf '%s' "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
file_path=$(printf '%s' "$json" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null || echo "")

# Claude may send Windows separators even when the hook runs in a POSIX shell.
# Exemption matching and git lookups must use the repository's separator.
file_path="${file_path//\\//}"

# Only check code files.
if [[ ! "$file_path" =~ \.(ts|tsx|js|jsx)$ ]]; then
    exit 0
fi

# Exemptions are safe only for ignored paths. A tracked test file can contain
# production code or be renamed later, so never let its name disable scanning.
if [[ "$file_path" =~ \.(test|spec)\.(ts|tsx|js|jsx)$ ]] || [[ "$file_path" =~ (^|/)__tests__/ ]]; then
    if git check-ignore -q -- "$file_path" 2>/dev/null; then
        exit 0
    fi
    echo "WARNING: unsafe security-scan path exemption ignored for tracked path: $file_path" >&2
fi

scan_file=$(mktemp "${TMPDIR:-/tmp}/security-scan.XXXXXX")
old_file=$(mktemp "${TMPDIR:-/tmp}/security-scan-old.XXXXXX")
trap 'rm -f "$scan_file" "$old_file"' EXIT

# Build the scan source from only content added by this tool call.
case "$tool_name" in
    Edit)
        printf '%s' "$json" | jq -r '.tool_input.new_string // empty' > "$scan_file"
        ;;
    MultiEdit)
        printf '%s' "$json" | jq -r '
            if (.tool_input.new_string? | type) == "string" then
                .tool_input.new_string
            elif (.tool_input.edits? | type) == "array" then
                [.tool_input.edits[]?.new_string // ""] | join("\n")
            else
                ""
            end
        ' > "$scan_file"
        ;;
    Write)
        printf '%s' "$json" | jq -r '.tool_input.content // empty' > "$scan_file.new"

        # A tracked HEAD copy is the only durable pre-Write state available to a
        # PostToolUse hook. For an existing file, remove exact old lines and scan
        # additions. For a new file, every line is added content.
        repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
        relative_path="$file_path"
        if [[ -n "$repo_root" ]]; then
            case "$file_path" in
                "$repo_root"/*) relative_path="${file_path#"$repo_root"/}" ;;
            esac
        fi
        if [[ -n "$repo_root" ]] && git -C "$repo_root" show "HEAD:$relative_path" > "$old_file" 2>/dev/null; then
            grep -F -v -x -f "$old_file" "$scan_file.new" > "$scan_file" || true
        else
            mv "$scan_file.new" "$scan_file"
        fi
        rm -f "$scan_file.new"
        ;;
    *)
        # This hook is registered for file-editing tools. Unknown tool payloads
        # have no trustworthy notion of added content.
        exit 0
        ;;
esac

if [[ ! -s "$scan_file" ]]; then
    exit 0
fi

violations=""

# CHECK 1: Hardcoded secrets/API keys
api_key_patterns=(
    'api[_-]?key[[:space:]]*[:=][[:space:]]*["\x27][a-zA-Z0-9]{20,}'
    'apikey[[:space:]]*[:=][[:space:]]*["\x27][a-zA-Z0-9]{20,}'
    'secret[_-]?key[[:space:]]*[:=][[:space:]]*["\x27][a-zA-Z0-9]{20,}'
    'auth[_-]?token[[:space:]]*[:=][[:space:]]*["\x27][a-zA-Z0-9]{20,}'
    'bearer[[:space:]]+[a-zA-Z0-9_-]{20,}'
    'sk[-_]live[-_][a-zA-Z0-9]{20,}'
    'sk[-_]test[-_][a-zA-Z0-9]{20,}'
    'pk[-_]live[-_][a-zA-Z0-9]{20,}'
    'ghp_[a-zA-Z0-9]{36}'
    'gho_[a-zA-Z0-9]{36}'
    'xox[baprs]-[a-zA-Z0-9-]{10,}'
)
for pattern in "${api_key_patterns[@]}"; do
    matches=$(grep -inE "$pattern" "$scan_file" 2>/dev/null | head -2 || true)
    if [[ -n "$matches" ]]; then
        violations+="\nPOSSIBLE HARDCODED SECRET DETECTED (BLOCKING)\n$matches\n\nNever hardcode secrets. Use environment variables.\n"
        break
    fi
done

# CHECK 2: Hardcoded URLs. An external-app marker exempts its own line and the
# immediately following line, allowing both inline and preceding annotations.
url_scan=$(mktemp "${TMPDIR:-/tmp}/security-url.XXXXXX")
awk '
    {
        marked = ($0 ~ /(\/\/|#)[[:space:]]*external-app-url/)
        skip = suppress_next || marked
        suppress_next = marked
        if (!skip) print
    }
' "$scan_file" > "$url_scan"
prod_urls=$(grep -nE 'https?://[a-zA-Z0-9][a-zA-Z0-9.-]+\.(com|io|org|net|co)' "$url_scan" 2>/dev/null \
    | grep -v 'localhost\|127.0.0.1\|example.com\|placeholder\|schema.org\|w3.org\|github.com\|npmjs' \
    | grep -v 'process\.env\|// example\|// test' \
    | head -3 || true)
rm -f "$url_scan"
if [[ -n "$prod_urls" ]]; then
    violations+="\nHARDCODED URL DETECTED (BLOCKING)\n$prod_urls\n\nUse environment variables for URLs.\n"
fi

# CHECK 3: eval()
eval_matches=$(grep -nE '\beval[[:space:]]*\(' "$scan_file" 2>/dev/null | grep -v '// safe\|// sanitized' | head -2 || true)
if [[ -n "$eval_matches" ]]; then
    violations+="\neval() DETECTED (BLOCKING)\n$eval_matches\n\neval() executes arbitrary code - major security risk.\n"
fi

# CHECK 4: new Function()
function_matches=$(grep -n 'new Function(' "$scan_file" 2>/dev/null | grep -v '// safe' | head -2 || true)
if [[ -n "$function_matches" ]]; then
    violations+="\nnew Function() DETECTED (BLOCKING)\n$function_matches\n\nDynamic function creation is a security risk.\n"
fi

# CHECK 5: innerHTML assignment
inner_html=$(grep -nE '\.innerHTML[[:space:]]*=' "$scan_file" 2>/dev/null | head -2 || true)
if [[ -n "$inner_html" ]]; then
    violations+="\ninnerHTML ASSIGNMENT DETECTED (BLOCKING)\n$inner_html\n\nDirect innerHTML is an XSS risk. Use textContent or DOMPurify.\n"
fi

# CHECK 6: SQL injection via string interpolation. Prisma's tagged-template
# forms are parameterised precisely when the backtick immediately follows
# $queryRaw/$executeRaw. Unsafe call variants remain blocking.
sql_src=$(perl -0777 -pe '
    s/\$(?:queryRaw|executeRaw)`(?:[^`\\]|\\.)*`/__SAFE_PRISMA_TAG__/gs;
    s/Prisma\.(?:sql|raw|join|empty)`(?:[^`\\]|\\.)*`/__SAFE_PRISMA_TAG__/gs;
' "$scan_file" 2>/dev/null || cat "$scan_file")
sql_interp=$(printf '%s\n' "$sql_src" | grep -nE '(SELECT|INSERT|UPDATE|DELETE|FROM|WHERE)[^`]*\$\{' | head -2 || true)
raw_unsafe=$(grep -nE '\$(queryRawUnsafe|executeRawUnsafe)[[:space:]]*\(' "$scan_file" 2>/dev/null | head -2 || true)
if [[ -n "$sql_interp" ]] || [[ -n "$raw_unsafe" ]]; then
    violations+="\nPOSSIBLE SQL INJECTION (BLOCKING)\n${sql_interp}${raw_unsafe:+$'\n'}${raw_unsafe}\n\nUse parameterised queries; only Prisma tagged templates with an immediate backtick are allowlisted.\n"
fi

# CHECK 7: Regex DoS
redos=$(grep -nE 'new RegExp\([^)]*\+' "$scan_file" 2>/dev/null | head -2 || true)
if [[ -n "$redos" ]]; then
    violations+="\nDYNAMIC REGEX FROM USER INPUT (BLOCKING)\n$redos\n\nUser-controlled regex can cause ReDoS attacks.\n"
fi

# CHECK 8: Path traversal
path_traversal=$(grep -nE '(path|file|dir).*\.\./' "$scan_file" 2>/dev/null | grep -v '// safe\|// validated' | head -2 || true)
if [[ -n "$path_traversal" ]]; then
    violations+="\nPOSSIBLE PATH TRAVERSAL (BLOCKING)\n$path_traversal\n"
fi

# CHECK 9: SSRF
ssrf_patterns=$(grep -nE 'fetch[[:space:]]*\([[:space:]]*[`$]|axios\.\w+[[:space:]]*\([[:space:]]*[`$]|request[[:space:]]*\([[:space:]]*[`$]' "$scan_file" 2>/dev/null | grep -v '// safe\|// validated' | head -2 || true)
if [[ -n "$ssrf_patterns" ]]; then
    violations+="\nPOSSIBLE SSRF VULNERABILITY (BLOCKING)\n$ssrf_patterns\n"
fi

# CHECK 10: javascript: protocol in href
js_href=$(grep -nE "href[[:space:]]*=[[:space:]]*[{\"\x27].*javascript:" "$scan_file" 2>/dev/null | head -2 || true)
if [[ -n "$js_href" ]]; then
    violations+="\njavascript: PROTOCOL IN href (BLOCKING)\n$js_href\n"
fi

# CHECK 11 is consolidated into CHECK 6 so unsafe Prisma calls are reported once.

# CHECK 12: AI service without sanitisation
if [[ "$file_path" =~ (ai[.-]service|-ai\.) ]]; then
    interp_count=$(grep -cE '\$\{' "$scan_file" 2>/dev/null || echo "0")
    if [[ "$interp_count" -gt 0 ]] && ! grep -q 'sanitise\|sanitize' "$scan_file" 2>/dev/null; then
        violations+="\nAI SERVICE WITHOUT SANITISATION (BLOCKING)\n\nUser input in AI prompts enables prompt injection.\n"
    fi
fi

# CHECK 13: NEXT_PUBLIC_ on sensitive vars
public_secrets=$(grep -nE 'NEXT_PUBLIC_(SECRET|API_KEY|DATABASE|DB_|AUTH_SECRET|JWT_SECRET|PRIVATE|PASSWORD|TOKEN|SUPABASE_SERVICE)' "$scan_file" 2>/dev/null | head -3 || true)
if [[ -n "$public_secrets" ]]; then
    violations+="\nSENSITIVE ENV VAR WITH NEXT_PUBLIC_ PREFIX (BLOCKING)\n$public_secrets\n"
fi

# CHECK 14: CORS wildcard with credentials
if grep -qE "origin.*['\"` ]\*['\"`]|Access-Control-Allow-Origin.*\*" "$scan_file" 2>/dev/null \
   && grep -qi 'credentials.*true\|Access-Control-Allow-Credentials' "$scan_file" 2>/dev/null; then
    violations+="\nCORS WILDCARD WITH credentials: true (BLOCKING)\n"
fi

# CHECK 15: Mass assignment via spreading req.body
mass_assign=$(grep -nE '\.\.\.(req\.body|request\.body)' "$scan_file" 2>/dev/null | head -3 || true)
if [[ -n "$mass_assign" ]]; then
    violations+="\nPOSSIBLE MASS ASSIGNMENT (BLOCKING)\n$mass_assign\n\nWhitelist allowed fields explicitly with Zod.\n"
fi

if [[ -n "$violations" ]]; then
    echo "=============================================================================" >&2
    echo "  SECURITY VIOLATIONS in $file_path" >&2
    echo "=============================================================================" >&2
    echo -e "$violations" >&2
    echo "" >&2
    echo "Fix security issues before continuing." >&2
    exit 2
fi

exit 0
