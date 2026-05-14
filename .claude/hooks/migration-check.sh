#!/bin/bash
# .claude/hooks/migration-check.sh
# WARN: Validates domain files follow project patterns
# Non-blocking but shows warnings

set -euo pipefail

json=$(cat)
file_path=$(echo "$json" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null || echo "")

# Only check files in domains/ or prisma schema
if [[ ! "$file_path" =~ /domains/ ]] && [[ ! "$file_path" =~ schema\.prisma$ ]]; then
    exit 0
fi

# Skip test files
if [[ "$file_path" =~ \.(test|spec)\.(ts|tsx)$ ]] || [[ "$file_path" =~ __tests__ ]]; then
    exit 0
fi

if [[ ! -f "$file_path" ]]; then
    exit 0
fi

warnings=""

# --- Backend checks ({{backend_app_path}}/src/domains/) ---
if [[ "$file_path" == *"{{backend_app_path}}/src/domains/"* ]]; then

    # Route files must export factory functions
    if [[ "$file_path" == *"/routes/"* && "$file_path" =~ \.ts$ ]]; then
        if ! grep -q "export function create.*Routes" "$file_path" 2>/dev/null; then
            warnings+="\nRoute file should export a create*Routes() factory function\n"
        fi
        if ! grep -q "authenticate" "$file_path" 2>/dev/null; then
            warnings+="\nRoute file should use authenticate middleware\n"
        fi
        if ! grep -q "tenantMiddleware" "$file_path" 2>/dev/null; then
            warnings+="\nRoute file should use tenantMiddleware\n"
        fi
    fi

    # Service files should use prismaWithTenant
    if [[ "$file_path" == *"/services/"* && "$file_path" =~ \.ts$ ]]; then
        if ! grep -q "prismaWithTenant" "$file_path" 2>/dev/null; then
            warnings+="\nService file should use prismaWithTenant for DB access\n"
        fi
    fi

    # Type files should have Zod schemas
    if [[ "$file_path" == *"/types/"* && "$file_path" =~ \.ts$ ]]; then
        if ! grep -qE "import.*z.*from.*zod|from.*zod" "$file_path" 2>/dev/null; then
            warnings+="\nType file should include Zod validation schemas\n"
        fi
    fi

    # Controller files should use ResponseUtil
    if [[ "$file_path" == *"/controllers/"* && "$file_path" =~ \.ts$ ]]; then
        if ! grep -q "ResponseUtil" "$file_path" 2>/dev/null; then
            warnings+="\nController should use ResponseUtil for responses\n"
        fi
    fi
fi

# --- Frontend checks ({{frontend_app_path}}/src/domains/) ---
if [[ "$file_path" == *"{{frontend_app_path}}/src/domains/"* ]]; then

    # Lucide imports (should use {{icon_library}})
    if grep -q "from.*lucide-react" "$file_path" 2>/dev/null; then
        lucide_lines=$(grep -n "lucide-react" "$file_path" 2>/dev/null | head -2 || true)
        warnings+="\nUse {{icon_library}} instead of Lucide\n$lucide_lines\n"
    fi

    # Zustand in hooks (should use React Query)
    if [[ "$file_path" == *"/hooks/"* ]]; then
        if grep -q "from.*zustand" "$file_path" 2>/dev/null; then
            warnings+="\nUse React Query for server state, not Zustand\n"
        fi
    fi
fi

# --- Prisma schema checks ---
if [[ "$file_path" == *"schema.prisma" ]]; then
    if grep -q "^model " "$file_path" 2>/dev/null; then
        while IFS= read -r model_line; do
            model_name=$(echo "$model_line" | awk '{print $2}')
            if [[ "$model_name" != "auth_"* && "$model_name" != "tenants" && "$model_name" != "Tenant" ]]; then
                if ! sed -n "/^model $model_name/,/^}/p" "$file_path" | grep -q "tenant_id"; then
                    warnings+="\nModel '$model_name' may need tenant_id for multi-tenancy\n"
                fi
            fi
        done < <(grep "^model " "$file_path")
    fi
fi

# Report warnings (non-blocking)
if [[ -n "$warnings" ]]; then
    echo "---" >&2
    echo "  DOMAIN PATTERN SUGGESTIONS for $file_path" >&2
    echo "---" >&2
    echo "$warnings" >&2
fi

exit 0