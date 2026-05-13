#!/bin/bash
# .claude/hooks/eslint-on-commit.sh
# BLOCK: Run ESLint on staged files before git commit
# Prevents lint errors from reaching CI
# Exit code 2 blocks the commit and feeds errors to Claude

set -euo pipefail

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only check Bash commands
if [[ "$tool_name" != "Bash" ]]; then
    exit 0
fi

command=$(echo "$json" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Only check git commit commands
if [[ ! "$command" =~ ^git\ commit ]] && [[ ! "$command" =~ \&\&\ *git\ commit ]]; then
    exit 0
fi

# Skip amend commits
if [[ "$command" =~ --amend ]]; then
    exit 0
fi

# Respect --no-verify flag
if [[ "$command" =~ --no-verify ]]; then
    exit 0
fi

# Determine project root
project_dir="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
if [[ "$command" =~ ^cd[[:space:]]+(\"([^\"]+)\"|([^[:space:]&]+)) ]]; then
    worktree_dir="${BASH_REMATCH[2]:-${BASH_REMATCH[3]}}"
    if [[ -d "$worktree_dir/apps" ]]; then
        project_dir="$worktree_dir"
    fi
fi

# Worktree compatibility
if [[ ! -d "$project_dir/node_modules" ]]; then
    main_root="$(git rev-parse --git-common-dir 2>/dev/null | sed 's|/.git$||')"
    if [[ -n "$main_root" && -d "$main_root/node_modules" ]]; then
        project_dir="$main_root"
    fi
fi

# Get staged .ts/.tsx files in apps/web
staged_files=$(git diff --cached --name-only 2>/dev/null || true)
web_files=$(echo "$staged_files" | grep "^apps/web/.*\.\(ts\|tsx\)$" 2>/dev/null || true)

if [[ -z "$web_files" ]]; then
    exit 0
fi

echo "" >&2
echo "=============================================================================" >&2
echo "  PRE-COMMIT: Running ESLint on staged files..." >&2
echo "=============================================================================" >&2

# Build file list relative to apps/web
file_args=""
while IFS= read -r f; do
    # Strip apps/web/ prefix for eslint running from that directory
    relative="${f#apps/web/}"
    if [[ -f "$project_dir/$f" ]]; then
        file_args+=" $relative"
    fi
done <<< "$web_files"

if [[ -z "$file_args" ]]; then
    echo "  No lintable files found, skipping" >&2
    exit 0
fi

# Run ESLint on only the staged files (errors only, warnings don't block)
# shellcheck disable=SC2086
lint_output=$(cd "$project_dir/apps/web" && npx eslint --no-warn-ignored --quiet $file_args 2>&1) || {
    error_count=$(echo "$lint_output" | grep -cE '^\s+[0-9]+:[0-9]+\s+error' || echo "0")
    if [[ "$error_count" -gt 0 ]]; then
        echo "" >&2
        echo "=============================================================================" >&2
        echo "  PRE-COMMIT: ESLint FAILED ($error_count errors)" >&2
        echo "=============================================================================" >&2
        echo "" >&2
        echo "$lint_output" >&2
        echo "" >&2
        echo "Fix ESLint errors before committing." >&2
        exit 2
    fi
}

echo "  ESLint passed (staged files only)" >&2
exit 0
