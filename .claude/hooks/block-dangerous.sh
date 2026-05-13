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

# Block reading .env files
if echo "$command" | grep -qE "(cat|head|tail|less|more|bat|vim|nano|code).*\.env" 2>/dev/null; then
    echo "=============================================================================" >&2
    echo "  BLOCKED: Cannot read .env files" >&2
    echo "=============================================================================" >&2
    echo "" >&2
    echo "Environment files contain secrets." >&2
    echo "Use process.env.VARIABLE_NAME in code instead." >&2
    exit 2
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