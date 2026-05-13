#!/bin/bash
# .claude/hooks/index-update.sh
# WARN: Remind to update INDEX.md when domain files change
# Exit code 2 feeds stderr to Claude for auto-fix

set -euo pipefail

json=$(cat)
file_path=$(echo "$json" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null || echo "")

# Only check source code files
if [[ ! "$file_path" =~ \.(ts|tsx|js|jsx)$ ]]; then
    exit 0
fi

# Skip test files
if [[ "$file_path" =~ \.(test|spec)\.(ts|tsx)$ ]] || [[ "$file_path" =~ __tests__ ]]; then
    exit 0
fi

# Skip config files and non-domain files
if [[ "$file_path" =~ \.config\. ]] || [[ "$file_path" =~ \.d\.ts$ ]]; then
    exit 0
fi

# Check if file is inside a domain folder (apps/*/src/domains/*)
if [[ ! "$file_path" =~ /domains/ ]]; then
    exit 0
fi

# Extract the domain path: everything up to and including the domain name
# e.g., apps/web/src/domains/crm/hooks/use-enquiries.ts -> apps/web/src/domains/crm
domain_path=$(echo "$file_path" | sed -E 's|(.*domains/[^/]+)/.*|\1|')

if [[ -z "$domain_path" ]]; then
    exit 0
fi

index_file="${domain_path}/INDEX.md"

# Check if INDEX.md exists in the domain
if [[ ! -f "$index_file" ]]; then
    echo "=============================================================================" >&2
    echo "  MISSING INDEX.md (BLOCKING)" >&2
    echo "=============================================================================" >&2
    echo "" >&2
    echo "Domain directory: $domain_path" >&2
    echo "" >&2
    echo "Every domain MUST have an INDEX.md file." >&2
    echo "Create one from the template at .claude/templates/domain-index.md" >&2
    echo "then add an entry for the file you just wrote." >&2
    exit 2
fi

# INDEX.md exists — remind to update it
# Extract just the filename for the reminder
filename=$(basename "$file_path")

# Check if the filename is already mentioned in the INDEX.md
if ! grep -q "$filename" "$index_file" 2>/dev/null; then
    echo "=============================================================================" >&2
    echo "  INDEX.md UPDATE NEEDED" >&2
    echo "=============================================================================" >&2
    echo "" >&2
    echo "File: $file_path" >&2
    echo "INDEX: $index_file" >&2
    echo "" >&2
    echo "The file '$filename' is not listed in the domain INDEX.md." >&2
    echo "Add it to the appropriate @anchor section and update the Summary." >&2
    exit 2
fi

exit 0
