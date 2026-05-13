#!/bin/bash
# .claude/hooks/commit-lint.sh
# BLOCK: Enforce conventional commit format
# Runs on PreToolUse for git commit commands
# Exit code 2 blocks the commit

set -euo pipefail

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only check Bash commands
if [[ "$tool_name" != "Bash" ]]; then
    exit 0
fi

command=$(echo "$json" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Only check git commit commands
if [[ ! "$command" =~ ^git\ commit ]]; then
    exit 0
fi

# Extract the commit message
# Handle multiple formats:
#   git commit -m "message"
#   git commit -m 'message'
#   git commit -m "$(cat <<'EOF' ... EOF )"  (heredoc)
#   git commit -F /path/to/file
#   git commit --file /path/to/file

if [[ "$command" =~ -F\ +([^\ ]+) ]] || [[ "$command" =~ --file\ +([^\ ]+) ]]; then
    # -F flag: read first line from the referenced file
    msg_file="${BASH_REMATCH[1]}"
    if [[ -f "$msg_file" ]]; then
        message=$(head -1 "$msg_file")
    else
        # File doesn't exist yet or can't read -- allow
        exit 0
    fi
elif [[ "$command" =~ \<\<[\']\''^EOF ]]; then
    # Heredoc style: first content line after the <<EOF marker is the subject
    message=$(echo "$command" | sed -n '/<<.*EOF/{n;p;q;}')
    if [[ -z "$message" ]]; then
        # Fallback: grab first line that looks like a conventional commit
        message=$(echo "$command" | grep -oE "^(feat|fix|chore|docs|style|refactor|test|perf|ci|build|revert)(\([a-z0-9-]+\))?: .+" | head -1)
    fi
    if [[ -z "$message" ]]; then
        # Can't parse heredoc -- allow through
        exit 0
    fi
elif [[ "$command" =~ -m\ +\"([^\"]+) ]]; then
    message="${BASH_REMATCH[1]}"
elif [[ "$command" =~ -m\ +\'([^\']+) ]]; then
    message="${BASH_REMATCH[1]}"
elif [[ "$command" =~ -m\ +([^\ ]+) ]]; then
    message="${BASH_REMATCH[1]}"
else
    # No -m or -F flag, might be opening editor - allow
    exit 0
fi

# =============================================================================
# CONVENTIONAL COMMIT FORMAT
# =============================================================================
# type(scope): description
# type: description
#
# Types: feat, fix, chore, docs, style, refactor, test, perf, ci, build, revert
# Scope: optional, lowercase
# Description: lowercase, no period, imperative mood

# Valid types
valid_types="feat|fix|chore|docs|style|refactor|test|perf|ci|build|revert"

# Regex pattern for conventional commit
pattern="^($valid_types)(\([a-z0-9-]+\))?: .+"

if [[ ! "$message" =~ $pattern ]]; then
    echo "=============================================================================" >&2
    echo "  INVALID COMMIT MESSAGE FORMAT (BLOCKING)" >&2
    echo "=============================================================================" >&2
    echo "" >&2
    echo "Your message: \"$message\"" >&2
    echo "" >&2
    echo "Required format: type(scope): description" >&2
    echo "" >&2
    echo "Valid types:" >&2
    echo "  feat     - New feature" >&2
    echo "  fix      - Bug fix" >&2
    echo "  chore    - Maintenance, dependencies" >&2
    echo "  docs     - Documentation only" >&2
    echo "  style    - Formatting, no code change" >&2
    echo "  refactor - Code change, no new feature or fix" >&2
    echo "  test     - Adding or updating tests" >&2
    echo "  perf     - Performance improvement" >&2
    echo "  ci       - CI/CD changes" >&2
    echo "  build    - Build system changes" >&2
    echo "  revert   - Reverting previous commit" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  feat(residents): add room assignment feature" >&2
    echo "  fix(auth): handle expired token refresh" >&2
    echo "  chore: update dependencies" >&2
    echo "  test(billing): add invoice generation tests" >&2
    echo "" >&2
    echo "Rules:" >&2
    echo "  - Type must be lowercase" >&2
    echo "  - Scope is optional, must be lowercase" >&2
    echo "  - Description must start with lowercase" >&2
    echo "  - No period at the end" >&2
    echo "" >&2
    exit 2
fi

# Check description starts with lowercase
description_part="${message#*: }"
first_char="${description_part:0:1}"
if [[ "$first_char" =~ [[:upper:]] ]]; then
    echo "=============================================================================" >&2
    echo "  COMMIT DESCRIPTION SHOULD START LOWERCASE (BLOCKING)" >&2
    echo "=============================================================================" >&2
    echo "" >&2
    echo "Your message: \"$message\"" >&2
    echo "Suggested:    \"${message%%: *}: ${first_char,,}${description_part:1}\"" >&2
    echo "" >&2
    exit 2
fi

# Check for period at end
if [[ "$message" =~ \.$ ]]; then
    echo "=============================================================================" >&2
    echo "  COMMIT MESSAGE SHOULD NOT END WITH PERIOD (BLOCKING)" >&2
    echo "=============================================================================" >&2
    echo "" >&2
    echo "Your message: \"$message\"" >&2
    echo "Suggested:    \"${message%.}\"" >&2
    echo "" >&2
    exit 2
fi

# Check minimum length
if [[ ${#description_part} -lt 10 ]]; then
    echo "=============================================================================" >&2
    echo "  COMMIT DESCRIPTION TOO SHORT (BLOCKING)" >&2
    echo "=============================================================================" >&2
    echo "" >&2
    echo "Your message: \"$message\"" >&2
    echo "" >&2
    echo "Description should be at least 10 characters." >&2
    echo "Be specific about what changed and why." >&2
    echo "" >&2
    exit 2
fi

exit 0