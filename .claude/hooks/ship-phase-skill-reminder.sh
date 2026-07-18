#!/bin/bash
# .claude/hooks/ship-phase-skill-reminder.sh
# Enforce mandatory gates when marking ship phases as done.
# Ship v2 phase numbering. Fires on Edit/Write to progress.md files.
# Exit code 2 blocks the edit and feeds stderr to Claude for correction.
#
# Reviewer model: the DainOS PR reviewer (GitHub App, webhook-driven).
# It reviews on PR open and re-reviews on EVERY push; finding bodies are
# NOT posted to GitHub (query pr_reviews / pr_review_findings via the
# DainOS MCP). A run that failed-at-fetch or was skipped by the monthly
# cost cap is NOT a clean pass.
#
# Self-test: run with --self-test (no stdin needed); asserts the
# Phase-10-without-PR path blocks (exit 2). Used by the enforcement audit.

set -uo pipefail

if [ "${1:-}" = "--self-test" ]; then
    out=$(printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/ship-selftest-nonrepo/progress.md","new_string":"10. PR ... done"}}' \
        | SHIP_PHASE_HOOK_SELFTEST=1 bash "$0" 2>&1)
    rc=$?
    if [ "$rc" -eq 2 ]; then
        echo "self-test OK: Phase-10-without-PR path blocks (exit 2)"
        exit 0
    fi
    echo "self-test FAILED: expected exit 2, got $rc. Output: $out"
    exit 1
fi

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

file_path=""
new_text=""

case "$tool_name" in
    Write)
        file_path=$(echo "$json" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
        new_text=$(echo "$json" | jq -r '.tool_input.content // empty' 2>/dev/null || echo "")
        ;;
    Edit|MultiEdit)
        file_path=$(echo "$json" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
        new_text=$(echo "$json" | jq -r '.tool_input.new_string // empty' 2>/dev/null || echo "")
        ;;
    *)
        exit 0
        ;;
esac

# Only check progress.md files
if ! echo "$file_path" | grep -qE 'progress\.md$' 2>/dev/null; then
    exit 0
fi

# Phase 8: E2E Testing -- warn only
if echo "$new_text" | grep -qiE '8\.\s*E2E.*done' 2>/dev/null; then
    echo "PHASE 8 GATE: Did you invoke Skill('ship-e2e')? E2E testing must use browser automation against user journeys, not be skipped. E2E must NOT be deferred for ML-integrated features." >&2
fi

# Phase 9: Human Review -- warn only
if echo "$new_text" | grep -qiE '9\.\s*Human Review.*done' 2>/dev/null; then
    echo "PHASE 9 GATE: Did the user explicitly approve? Human gates are blocking -- do not mark done without user confirmation." >&2
fi

# Phase 10: PR -- BLOCK only if gh definitively reports no PR for the branch
# that owns the progress file. Hooks run in $CLAUDE_PROJECT_DIR, not the
# worktree cwd, so resolve the repo from the edited file's own path.
# The gh call is watchdogged (perl alarm, no coreutils dependency) so the
# script always finishes inside the wired hook timeout; a network failure
# degrades to the warning path, never to a silent kill or a false block.
if echo "$new_text" | grep -qiE '10\.\s*PR.*done' 2>/dev/null; then
    file_dir=$(dirname "$file_path")
    repo_top=$(git -C "$file_dir" rev-parse --show-toplevel 2>/dev/null || echo "")

    pr_number=""
    if [ -n "$repo_top" ] && [ -z "${SHIP_PHASE_HOOK_SELFTEST:-}" ]; then
        gh_err_file=$(mktemp)
        gh_rc=0
        gh_out=$(cd "$repo_top" && perl -e 'alarm 4; exec @ARGV' -- gh pr view --json number -q .number 2>"$gh_err_file") || gh_rc=$?
        gh_err=$(cat "$gh_err_file" 2>/dev/null; rm -f "$gh_err_file")
        if [ "$gh_rc" -eq 0 ] && [ -n "$gh_out" ]; then
            pr_number="$gh_out"
        elif echo "$gh_err" | grep -qiE 'no pull requests found|no default remote|not a git repository'; then
            pr_number=""
        else
            # network hiccup / rate limit / killed by alarm: cannot verify
            pr_number="unknown"
        fi
    fi

    if [ "$pr_number" = "unknown" ]; then
        echo "PHASE 10: could not verify PR presence (gh unavailable or slow). Verify manually that the PR exists, then follow the DainOS reviewer checklist below." >&2
    fi

    if [ -z "$pr_number" ]; then
        echo "===============================================================" >&2
        echo "  PHASE 10 GATE: NO OPEN PR FOUND FOR THIS BRANCH" >&2
        echo "===============================================================" >&2
        echo "Phase 10 cannot be done without a PR. Push the branch and open" >&2
        echo "the PR (gh pr create --body-file <absolute-path>), then retry." >&2
        exit 2
    fi

    pr_label="PR #${pr_number} found"
    [ "$pr_number" = "unknown" ] && pr_label="PR presence unverified"
    echo "===============================================================" >&2
    echo "  PHASE 10 CHECKLIST (${pr_label}) -- DainOS reviewer" >&2
    echo "===============================================================" >&2
    echo "  * Check the reviewer verdict via the DainOS MCP:" >&2
    echo "    query pr_reviews / pr_review_findings (repo = FULL GitHub" >&2
    echo "    slug). Finding bodies are NOT posted to GitHub." >&2
    echo "  * A run that failed-at-fetch (rate limit) or was skipped by" >&2
    echo "    the monthly cost cap is NOT a clean pass -- retrigger by" >&2
    echo "    closing and reopening the PR, or record the skip explicitly." >&2
    echo "  * Score each finding via score_pr_finding before wrap-up." >&2
    echo "  * The reviewer re-reviews on every push: batch fixes into ONE" >&2
    echo "    push; do not reply finding-by-finding per push." >&2
    echo "===============================================================" >&2
fi

exit 0
