#!/bin/bash
# .claude/hooks/session-start.sh
# INFO: Load context when Claude Code starts
# Non-blocking, provides useful context

set -uo pipefail

echo "" >&2
echo "=============================================================================" >&2
echo "  mood-tracker STANDARDS ENABLED" >&2
echo "=============================================================================" >&2
echo "" >&2

# =============================================================================
# PROJECT STATUS
# =============================================================================

# Git status
if command -v git &> /dev/null && git rev-parse --is-inside-work-tree &> /dev/null; then
    branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    echo "  Branch: $branch" >&2

    # Uncommitted changes
    changes=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') || true
    if [[ "$changes" -gt 0 ]]; then
        echo "  Uncommitted changes: $changes files" >&2
    fi

    # Last commit
    last_commit=$(git log -1 --format="%s" 2>/dev/null || echo "")
    if [[ -n "$last_commit" ]]; then
        echo "  Last commit: ${last_commit:0:50}" >&2
    fi
fi

echo "" >&2

# =============================================================================
# STANDARDS REMINDER
# =============================================================================

echo "  ENFORCED STANDARDS:" >&2
echo "     - No 'any' types - use proper types or 'unknown'" >&2
echo "     - Error handling required - no empty catches" >&2
echo "     - Test files required - every source file needs tests" >&2
echo "     - Conventional commits - feat/fix/chore(scope): message" >&2
echo "" >&2

# =============================================================================
# CONTEXT FILES
# =============================================================================

# Load any context from CLAUDE.md if it exists
if [[ -f "CLAUDE.md" ]]; then
    echo "  Project context loaded from CLAUDE.md" >&2
fi

# Check for any types in source
any_count=0
for dir in src apps/web/src apps/api/src; do
    if [[ -d "$dir" ]]; then
        count=$(grep -r ": any\|as any" --include="*.ts" --include="*.tsx" "$dir" 2>/dev/null | wc -l | tr -d ' ') || true
        any_count=$((any_count + count))
    fi
done
if [[ "$any_count" -gt 0 ]]; then
    echo "  Found $any_count 'any' types - consider fixing" >&2
fi

echo "" >&2
echo "=============================================================================" >&2
echo "" >&2

# Output context to stdout (will be added to Claude's context)
echo "Standards active: TypeScript strict, no any, tests required, conventional commits."

exit 0