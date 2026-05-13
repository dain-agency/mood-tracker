#!/bin/bash
# .claude/hooks/security-scan.sh
# BLOCK: Security vulnerability detection
# Exit code 2 feeds stderr to Claude for auto-fix

set -euo pipefail

json=$(cat)
file_path=$(echo "$json" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null || echo "")

# Only check code files
if [[ ! "$file_path" =~ \.(ts|tsx|js|jsx)$ ]]; then
    exit 0
fi

# Skip test files
if [[ "$file_path" =~ \.(test|spec)\.(ts|tsx|js|jsx)$ ]] || [[ "$file_path" =~ __tests__ ]]; then
    exit 0
fi

violations=""

if [[ -f "$file_path" ]]; then

    # CHECK 1: Hardcoded secrets/API keys
    api_key_patterns=(
        'api[_-]?key\s*[:=]\s*["\x27][a-zA-Z0-9]{20,}'
        'apikey\s*[:=]\s*["\x27][a-zA-Z0-9]{20,}'
        'secret[_-]?key\s*[:=]\s*["\x27][a-zA-Z0-9]{20,}'
        'auth[_-]?token\s*[:=]\s*["\x27][a-zA-Z0-9]{20,}'
        'bearer\s+[a-zA-Z0-9_-]{20,}'
        'sk[-_]live[-_][a-zA-Z0-9]{20,}'
        'sk[-_]test[-_][a-zA-Z0-9]{20,}'
        'pk[-_]live[-_][a-zA-Z0-9]{20,}'
        'ghp_[a-zA-Z0-9]{36}'
        'gho_[a-zA-Z0-9]{36}'
        'xox[baprs]-[a-zA-Z0-9-]{10,}'
    )
    for pattern in "${api_key_patterns[@]}"; do
        matches=$(grep -inE "$pattern" "$file_path" 2>/dev/null | head -2 || true)
        if [[ -n "$matches" ]]; then
            violations+="\nPOSSIBLE HARDCODED SECRET DETECTED (BLOCKING)\n$matches\n\nNever hardcode secrets. Use environment variables.\n"
            break
        fi
    done

    # CHECK 2: Hardcoded URLs
    prod_urls=$(grep -nE 'https?://[a-zA-Z0-9][a-zA-Z0-9.-]+\.(com|io|org|net|co)' "$file_path" 2>/dev/null \
        | grep -v "localhost\|127.0.0.1\|example.com\|placeholder\|schema.org\|w3.org\|github.com\|npmjs" \
        | grep -v "process\.env\|// example\|// test" \
        | head -3 || true)
    if [[ -n "$prod_urls" ]]; then
        violations+="\nHARDCODED URL DETECTED (BLOCKING)\n$prod_urls\n\nUse environment variables for URLs.\n"
    fi

    # CHECK 3: eval()
    if grep -nE '\beval\s*\(' "$file_path" 2>/dev/null | grep -v "// safe\|// sanitized" | head -2; then
        violations+="\neval() DETECTED (BLOCKING)\n\neval() executes arbitrary code - major security risk.\n"
    fi

    # CHECK 4: new Function()
    if grep -n 'new Function(' "$file_path" 2>/dev/null | grep -v "// safe" | head -2; then
        violations+="\nnew Function() DETECTED (BLOCKING)\n\nDynamic function creation is a security risk.\n"
    fi

    # CHECK 5: innerHTML assignment
    if grep -nE '\.innerHTML\s*=' "$file_path" 2>/dev/null | head -2; then
        violations+="\ninnerHTML ASSIGNMENT DETECTED (BLOCKING)\n\nDirect innerHTML is an XSS risk. Use textContent or DOMPurify.\n"
    fi

    # CHECK 6: SQL injection
    if grep -nE '(SELECT|INSERT|UPDATE|DELETE|FROM|WHERE).*\$\{' "$file_path" 2>/dev/null | head -2; then
        violations+="\nPOSSIBLE SQL INJECTION (BLOCKING)\n\nUse parameterized queries instead of string interpolation.\n"
    fi

    # CHECK 7: Regex DoS
    if grep -nE 'new RegExp\([^)]*\+' "$file_path" 2>/dev/null | head -2; then
        violations+="\nDYNAMIC REGEX FROM USER INPUT (BLOCKING)\n\nUser-controlled regex can cause ReDoS attacks.\n"
    fi

    # CHECK 8: Path traversal
    path_traversal=$(grep -nE '(path|file|dir).*\.\./' "$file_path" 2>/dev/null | grep -v "// safe\|// validated" | head -2 || true)
    if [[ -n "$path_traversal" ]]; then
        violations+="\nPOSSIBLE PATH TRAVERSAL (BLOCKING)\n$path_traversal\n"
    fi

    # CHECK 9: SSRF
    ssrf_patterns=$(grep -nE 'fetch\s*\(\s*[\`\$]|axios\.\w+\s*\(\s*[\`\$]|request\s*\(\s*[\`\$]' "$file_path" 2>/dev/null | grep -v "// safe\|// validated" | head -2 || true)
    if [[ -n "$ssrf_patterns" ]]; then
        violations+="\nPOSSIBLE SSRF VULNERABILITY (BLOCKING)\n$ssrf_patterns\n"
    fi

    # CHECK 10: javascript: protocol in href
    js_href=$(grep -nE "href\s*=\s*[{\"\x27].*javascript:" "$file_path" 2>/dev/null | head -2 || true)
    if [[ -n "$js_href" ]]; then
        violations+="\njavascript: PROTOCOL IN href (BLOCKING)\n$js_href\n"
    fi

    # CHECK 11: Prisma $queryRawUnsafe
    raw_unsafe=$(grep -nE '\$queryRawUnsafe|\$executeRawUnsafe' "$file_path" 2>/dev/null | head -2 || true)
    if [[ -n "$raw_unsafe" ]]; then
        violations+="\nPrisma \$queryRawUnsafe DETECTED (BLOCKING)\n$raw_unsafe\n\nUse parameterised queries instead.\n"
    fi

    # CHECK 12: AI service without sanitisation
    if [[ "$file_path" =~ (ai[\.-]service|-ai\.) ]]; then
        interp_count=$(grep -cE '\$\{' "$file_path" 2>/dev/null || echo "0")
        if [[ "$interp_count" -gt 0 ]]; then
            if ! grep -q "sanitise\|sanitize" "$file_path" 2>/dev/null; then
                violations+="\nAI SERVICE WITHOUT SANITISATION (BLOCKING)\n\nUser input in AI prompts enables prompt injection.\n"
            fi
        fi
    fi

    # CHECK 13: NEXT_PUBLIC_ on sensitive vars
    public_secrets=$(grep -nE 'NEXT_PUBLIC_(SECRET|API_KEY|DATABASE|DB_|AUTH_SECRET|JWT_SECRET|PRIVATE|PASSWORD|TOKEN|SUPABASE_SERVICE)' "$file_path" 2>/dev/null | head -3 || true)
    if [[ -n "$public_secrets" ]]; then
        violations+="\nSENSITIVE ENV VAR WITH NEXT_PUBLIC_ PREFIX (BLOCKING)\n$public_secrets\n"
    fi

    # CHECK 14: CORS wildcard with credentials
    if grep -qE "origin.*['\"\`]\*['\"\`]|Access-Control-Allow-Origin.*\*" "$file_path" 2>/dev/null; then
        if grep -qi "credentials.*true\|Access-Control-Allow-Credentials" "$file_path" 2>/dev/null; then
            violations+="\nCORS WILDCARD WITH credentials: true (BLOCKING)\n"
        fi
    fi

    # CHECK 15: Mass assignment via spreading req.body
    mass_assign=$(grep -nE '\.\.\.(req\.body|request\.body)' "$file_path" 2>/dev/null | head -3 || true)
    if [[ -n "$mass_assign" ]]; then
        violations+="\nPOSSIBLE MASS ASSIGNMENT (BLOCKING)\n$mass_assign\n\nWhitelist allowed fields explicitly with Zod.\n"
    fi
fi

# Report violations
if [[ -n "$violations" ]]; then
    echo "=============================================================================" >&2
    echo "  SECURITY VIOLATIONS in $file_path" >&2
    echo "=============================================================================" >&2
    echo "$violations" >&2
    echo "" >&2
    echo "Fix security issues before continuing." >&2
    exit 2
fi

exit 0