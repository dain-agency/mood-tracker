#!/bin/bash
# .claude/hooks/agent-scope-check.sh
# BLOCK: Prevent overscoped agent launches without explicit user confirmation.
#
# Fires on PreToolUse:Agent. Reads the agent prompt from stdin JSON and checks
# for complexity indicators. If the task exceeds safe thresholds, BLOCK with
# a message forcing the caller to break the work down.
#
# Exit code 2 = block the tool call
# Exit code 0 = allow

set -uo pipefail
# Note: -e intentionally omitted — grep returns 1 on no match which would exit early

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only check Agent tool calls
if [[ "$tool_name" != "Agent" ]]; then
    exit 0
fi

prompt=$(echo "$json" | jq -r '.tool_input.prompt // empty' 2>/dev/null || echo "")
description=$(echo "$json" | jq -r '.tool_input.description // empty' 2>/dev/null || echo "")
background=$(echo "$json" | jq -r '.tool_input.run_in_background // false' 2>/dev/null || echo "false")

# Skip scope check for non-builder agents (explore, plan, review, etc.)
subagent=$(echo "$json" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || echo "")
case "$subagent" in
    Explore|Plan|code-reviewer|ship-business-reviewer|ship-quality-reviewer|ship-context-mapper|ship-ui-auditor|claude-code-guide)
        exit 0
        ;;
esac

# =============================================================================
# COMPLEXITY SCORING
# =============================================================================

score=0
reasons=()

# --- Domain count ---
domain_count=$(echo "$prompt" | grep -oiE '(contacts|tasks|documents|notifications|crm|residents|workforce|billing|clinical|medication|compliance|visitors|facilities|hr|procurement|bookings|dependency|content|workflows|reporting|ai) domain' | sort -u | wc -l)
if [[ $domain_count -gt 1 ]]; then
    score=$((score + domain_count * 15))
    reasons+=("$domain_count domains referenced (each domain = 15 points)")
fi

# --- File count indicators ---
file_refs=$(echo "$prompt" | grep -oiE '(create|build|implement|write|generate) .*(files?|components?|hooks?|pages?|routes?|tests?)' | wc -l)
if [[ $file_refs -gt 10 ]]; then
    score=$((score + file_refs * 2))
    reasons+=("$file_refs file creation instructions")
fi

# --- Round/phase indicators (multi-round builds) ---
round_count=$(echo "$prompt" | grep -oiE '(round [0-9]|phase [0-9]|step [0-9])' | sort -u | wc -l)
if [[ $round_count -gt 2 ]]; then
    score=$((score + round_count * 10))
    reasons+=("$round_count build rounds/phases")
fi

# --- "Full domain build" or "end-to-end" indicators ---
if echo "$prompt" | grep -qiE '(full domain build|end.to.end|scaffold through tests|complete domain|all rounds)'; then
    score=$((score + 30))
    reasons+=("Full domain build detected")
fi

# --- Task manifest reference ---
task_count=$(echo "$prompt" | grep -oE 'task-[0-9]+' | sort -u | wc -l)
if [[ $task_count -gt 15 ]]; then
    score=$((score + task_count))
    reasons+=("$task_count tasks referenced")
fi

# --- Prompt length (very long prompts = very complex tasks) ---
prompt_length=${#prompt}
if [[ $prompt_length -gt 5000 ]]; then
    score=$((score + 20))
    reasons+=("Prompt is ${prompt_length} chars (>5000)")
fi

# =============================================================================
# THRESHOLDS
# =============================================================================

# Score < 25: fine, proceed
# Score 25-49: warn but allow
# Score >= 50: BLOCK — too complex for reliable autonomous execution

if [[ $score -lt 25 ]]; then
    exit 0
fi

if [[ $score -lt 50 ]]; then
    # Warn but allow
    reason_text=""
    for r in "${reasons[@]}"; do
        reason_text="${reason_text}\n  - ${r}"
    done
    echo "=============================================================================
  SCOPE WARNING: Agent task complexity score = $score/100
=============================================================================
${reason_text}

  This task is moderately complex. Consider whether the agent can reliably
  handle it in one shot, or whether it should be broken into smaller tasks.
"
    exit 0
fi

# BLOCK — too complex
reason_text=""
for r in "${reasons[@]}"; do
    reason_text="${reason_text}\n  - ${r}"
done

echo "=============================================================================
  BLOCKED: Agent task too complex (score: $score/100, threshold: 50)
=============================================================================
${reason_text}

  This task exceeds the complexity threshold for reliable autonomous execution.
  Agents that take on too much scope produce placeholder data, skip design
  system patterns, and ignore project rules.

  You MUST either:
  1. Break the task into smaller, focused agent calls (one component at a time)
  2. Get explicit user confirmation that they accept the quality trade-off

  To proceed anyway, get user approval first, then re-launch with a note
  that the user has accepted reduced quality for speed.
" >&2

exit 2
