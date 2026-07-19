#!/bin/bash
# .claude/hooks/block-claire-typo.sh
# BLOCK: catch the `.claude` → `.claire` typo in Write/Edit file paths before
# the file lands on disk. Multiple agent sessions have demonstrably typed
# `.claire/worktrees/...` when meaning `.claude/worktrees/...`, and the Write
# tool silently creates parent dirs, leaving accreting debris that's a pain to
# audit and clean up. Exit code 2 blocks the call so the agent self-corrects.
#
# Matches:
#   .claude/settings.json → hooks.PreToolUse[matcher="Write|Edit|MultiEdit"]

set -euo pipefail

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only check file-writing tools.
case "$tool_name" in
    Write|Edit|MultiEdit|NotebookEdit) ;;
    *) exit 0 ;;
esac

# Collect every plausible path field from the tool input. We check three
# shapes so the hook is resilient to all current and likely-future schemas:
#
#   1. .tool_input.file_path        — Write, Edit, MultiEdit (one file, many edits)
#   2. .tool_input.edits[].file_path — defensive: any future MultiEdit-like
#                                       tool that fans out across multiple files
#   3. .tool_input.notebook_path     — NotebookEdit (Jupyter)
#
# DainOS reviewer's #323 finding incorrectly claimed MultiEdit uses
# edits[].file_path — it actually uses a single top-level file_path, same as
# Edit. But we cover both shapes anyway: zero false positives if (2) never
# fires, and we're future-proof if a multi-file variant ever ships.
paths=$(echo "$json" | jq -r '
  [
    .tool_input.file_path? // empty,
    .tool_input.notebook_path? // empty,
    (.tool_input.edits[]?.file_path? // empty)
  ]
  | .[]
  | select(. != "")
' 2>/dev/null || echo "")

# Block any path containing /.claire/ — almost certainly a `.claude` typo.
# Match the leading `/` (or string-start) to avoid false positives on user
# names like "Claire" or unrelated filenames.
while IFS= read -r path; do
    [ -z "$path" ] && continue
    if [[ "$path" == *"/.claire/"* ]] || [[ "$path" == ".claire/"* ]]; then
        echo "=============================================================================" >&2
        echo "  BLOCKED: '.claire/' path almost certainly meant '.claude/'" >&2
        echo "=============================================================================" >&2
        echo "" >&2
        echo "Path: $path" >&2
        echo "Tool: $tool_name" >&2
        echo "" >&2
        echo "Multiple prior sessions have typed '.claire/' when meaning '.claude/'." >&2
        echo "Correct the path and retry. If you genuinely need a folder named" >&2
        echo "'.claire' (you almost certainly don't), use a different name." >&2
        exit 2
    fi
done <<< "$paths"

exit 0
