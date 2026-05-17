#!/bin/bash
# .claude/hooks/block-dangerous.sh
# BLOCK: Block dangerous bash commands before execution
# Exit code 2 blocks the command

set -euo pipefail

json=$(cat)
tool_name=$(echo "$json" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only check Bash commands
if [[ "$tool_name" != "Bash" ]]; then
    exit 0
fi

command=$(echo "$json" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# =============================================================================
# SAFE PATTERNS - ALLOW (only for simple, non-chained commands)
# =============================================================================

# Chained commands (&&, ||, ;, |) can smuggle dangerous ops alongside safe ones.
# Only early-exit if the command has no chaining operators.
is_chained() {
    echo "$1" | grep -qE '&&|\|\||;|\|' 2>/dev/null
}

if ! is_chained "$command"; then
    # Allow worktree cleanup (rm -rf .worktrees/*)
    if echo "$command" | grep -qE 'rm -rf.*\.worktrees/' 2>/dev/null; then
        exit 0
    fi
    # Allow node_modules cleanup (rm -rf .../node_modules)
    if echo "$command" | grep -qE 'rm -rf.*/node_modules' 2>/dev/null; then
        exit 0
    fi
fi

# =============================================================================
# DANGEROUS PATTERNS - ALWAYS BLOCK
# =============================================================================

dangerous_patterns=(
    # Destructive commands
    "rm -rf /"
    "rm -rf ~"
    "rm -rf \$HOME"
    'rm -rf \.[[:space:]]*([;&|]|$)'
    'rm -rf \./'
    "rm -rf \*"
    "rm -f /"
    "rm -f ~"
    "rm -f \*"
    "sudo rm"

    # System modification
    "chmod 777"
    "chmod -R 777"
    "> /etc/"
    ">> /etc/"

    # Network piping (code execution)
    "curl.*\\|.*\\bsh\\b"
    "curl.*\\|.*\\bbash\\b"
    "wget.*\\|.*\\bsh\\b"
    "wget.*\\|.*\\bbash\\b"

    # Publishing
    "npm publish"

    # Fork bomb
    ":\(\)\{.*\}.*:"

    # Disk operations
    "dd if="
    "mkfs"
    "> /dev/"

    # Code execution
    "node -e.*\\b(exec|spawn|child_process|require\\(.*http)\\b"
    "python -c.*exec"
    "eval \$"
)

for pattern in "${dangerous_patterns[@]}"; do
    if echo "$command" | grep -qiE "$pattern" 2>/dev/null; then
        echo "=============================================================================" >&2
        echo "  DANGEROUS COMMAND BLOCKED" >&2
        echo "=============================================================================" >&2
        echo "" >&2
        echo "Command: $command" >&2
        echo "Pattern: $pattern" >&2
        echo "" >&2
        echo "This command has been blocked for safety." >&2
        exit 2
    fi
done

# =============================================================================
# SENSITIVE FILE ACCESS - BLOCK
# =============================================================================

# Block reading .env files.
#
# Safe-context skip: writing or referencing the literal string ".env" inside a
# commit/tag/PR/issue body, a heredoc, an echo/printf, or a documentation file
# is not a secret read. The original regex matched the substring anywhere in
# the command, which caused false positives like:
#   git commit -m "$(cat <<EOF ... mentions .env ... EOF)"
#   gh pr create --body "... touches .env.local ..."
# Both contain `cat` and `.env` but neither reads a secrets file.
if ! echo "$command" | grep -qE '(^|[[:space:]])(git[[:space:]]+(commit|tag|log|show|format-patch)|gh[[:space:]]+(pr|issue|release)[[:space:]]+(create|edit|comment)|echo|printf)([[:space:]]|$)' 2>/dev/null \
   && ! echo "$command" | grep -qE '<<-?[[:space:]]*'\''?[A-Za-z_]' 2>/dev/null; then
    # Match the readers when .env appears as a file argument (word-boundaried),
    # not as a substring of a longer token like `.environment` or `.envoy`.
    if echo "$command" | grep -qE "(^|[[:space:]/<])(cat|head|tail|less|more|bat|vim|nano|code)[[:space:]].*\.env(\b|\.|$)" 2>/dev/null; then
        echo "=============================================================================" >&2
        echo "  BLOCKED: Cannot read .env files" >&2
        echo "=============================================================================" >&2
        echo "" >&2
        echo "Environment files contain secrets." >&2
        echo "Use process.env.VARIABLE_NAME in code instead." >&2
        exit 2
    fi
fi

# Block reading private keys
if echo "$command" | grep -qE "(cat|head|tail|less|more).*\.(pem|key|p12|pfx)" 2>/dev/null; then
    echo "=============================================================================" >&2
    echo "  BLOCKED: Cannot read private key files" >&2
    echo "=============================================================================" >&2
    echo "" >&2
    echo "Private keys should never be read or displayed." >&2
    exit 2
fi

# Block reading secrets directory
if echo "$command" | grep -qE "(cat|head|tail|less|more|ls).*secrets/" 2>/dev/null; then
    echo "=============================================================================" >&2
    echo "  BLOCKED: Cannot access secrets directory" >&2
    echo "=============================================================================" >&2
    exit 2
fi

exit 0
