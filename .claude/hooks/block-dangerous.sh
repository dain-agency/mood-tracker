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

# Remove data that the shell treats as opaque commit prose before running any
# command-pattern checks. Keep flags, redirects, pipes, delimiters, and commands
# themselves so the structural safety checks still see the executable shell.
strip_heredoc_bodies() {
    local text="$1"
    local line marker delimiter="" strip_tabs=false compare

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -n "$delimiter" ]]; then
            compare="$line"
            if [[ "$strip_tabs" == true ]]; then
                while [[ "$compare" == $'\t'* ]]; do compare="${compare#$'\t'}"; done
            fi
            if [[ "$compare" == "$delimiter" ]]; then
                printf '%s\n' "$line"
                delimiter=""
                strip_tabs=false
            fi
            continue
        fi

        printf '%s\n' "$line"
        marker=$(printf '%s\n' "$line" | grep -oE "<<-?[[:space:]]*['\"]?[A-Za-z_][A-Za-z0-9_]*['\"]?" | head -1 || true)
        if [[ -n "$marker" ]]; then
            [[ "$marker" == '<<-'* ]] && strip_tabs=true
            delimiter=$(printf '%s' "$marker" | sed -E "s/^<<-?[[:space:]]*//; s/^['\"]//; s/['\"]$//")
        fi
    done <<< "$text"
}

command_for_matching=$(strip_heredoc_bodies "$command")
if printf '%s\n' "$command_for_matching" | grep -qE '(^|[;&|()[:space:]])git[[:space:]]+commit([;&|()[:space:]]|$)' 2>/dev/null; then
    command_for_matching=$(printf '%s' "$command_for_matching" | perl -0777 -pe '
        s{((?:^|[[:space:]])(?:-m|--message)(?:[[:space:]]*=)?[[:space:]]*)"(?:\\.|[^"\\])*"}{$1 . "\"\""}gse;
        s{((?:^|[[:space:]])(?:-m|--message)(?:[[:space:]]*=)?[[:space:]]*)'\''(?:[^'\'']*)'\''}{$1 . "'\'''\''"}gse;
    ')
fi

# =============================================================================
# SAFE PATTERNS - ALLOW (only for simple, non-chained commands)
# =============================================================================

# Chained commands (&&, ||, ;, |) can smuggle dangerous ops alongside safe ones.
# Only early-exit if the command has no chaining operators.
is_chained() {
    echo "$1" | grep -qE '&&|\|\||;|\||(^|[^&])&([^&]|$)' 2>/dev/null
}

# Explicitly allow a simple recursive force-removal only when every target is a
# scratch path. Mixed target lists never receive the exemption.
safe_temp_rm=false
if ! is_chained "$command_for_matching" \
   && [[ "$command_for_matching" =~ ^[[:space:]]*rm[[:space:]]+-rf[[:space:]]+(.+)$ ]]; then
    read -r -a rm_targets <<< "${BASH_REMATCH[1]}"
    safe_temp_rm=true
    for target in "${rm_targets[@]}"; do
        target="${target#\"}"; target="${target%\"}"
        target="${target#\'}"; target="${target%\'}"
        case "$target" in
            /tmp/*|/private/tmp/*|'$TMPDIR'/*|'${TMPDIR}'/*) ;;
            *) safe_temp_rm=false; break ;;
        esac
    done
fi

# Allow `curl | bash` (and wget | bash) ONLY when the URL points at a known-good
# installer endpoint. Extend this list when you need to add a new trusted vendor.
# All entries must be HTTPS — the protocol check is part of the regex.
trusted_install_urls=(
    'https://([a-z0-9-]+\.)*tailscale\.com/'
    'https://get\.docker\.com/?'
    'https://sh\.rustup\.rs/?'
    'https://bun\.sh/install'
    'https://deb\.nodesource\.com/'
    'https://raw\.githubusercontent\.com/'
    'https://aka\.ms/'
)
if echo "$command_for_matching" | grep -qE '(^|[^[:alnum:]_])(curl|wget)([^[:alnum:]_]|$).*\|.*(^|[^[:alnum:]_])(bash|sh)([^[:alnum:]_]|$)' 2>/dev/null; then
    for url in "${trusted_install_urls[@]}"; do
        if echo "$command_for_matching" | grep -qE "$url" 2>/dev/null; then
            # Trusted installer URL — bypass the curl|bash block below.
            # Other dangerous patterns in the same command will still be checked.
            trusted_pipe_install=1
            break
        fi
    done
fi

# =============================================================================
# DANGEROUS PATTERNS - ALWAYS BLOCK
# =============================================================================

dangerous_patterns=(
    # Destructive commands.
    # `rm -rf /` / `rm -f /` are matched against an explicit dangerous-target
    # list (bare root + sensitive top-level dirs) instead of the bare prefix
    # "rm -rf /", so cleanup of scratch files under /tmp/ is allowed while root
    # and system dirs stay blocked. /var is in the list, so /var/tmp is also
    # blocked — use /tmp for scratch files.
    '(^|[^[:alnum:]_])rm[[:space:]]+-rf[[:space:]]+/([[:space:]]|$)'
    '(^|[^[:alnum:]_])rm[[:space:]]+-rf[[:space:]]+/(bin|boot|dev|etc|home|lib|lib64|opt|proc|root|run|sbin|srv|sys|usr|var|mnt|media)([[:space:]/]|$)'
    '(^|[^[:alnum:]_])rm[[:space:]]+-f[[:space:]]+/([[:space:]]|$)'
    '(^|[^[:alnum:]_])rm[[:space:]]+-f[[:space:]]+/(bin|boot|dev|etc|home|lib|lib64|opt|proc|root|run|sbin|srv|sys|usr|var|mnt|media)([[:space:]/]|$)'
    '(^|[^[:alnum:]_])rm[[:space:]]+-rf[[:space:]]+(~|\$HOME)([^[:alnum:]_]|$)'
    '(^|[^[:alnum:]_])rm[[:space:]]+-rf[[:space:]]+\.[[:space:]]*([;&|]|$)'
    '(^|[^[:alnum:]_])rm[[:space:]]+-rf[[:space:]]+\./([^[:alnum:]_]|$)'
    '(^|[^[:alnum:]_])rm[[:space:]]+-rf[[:space:]]+\*([^[:alnum:]_]|$)'
    '(^|[^[:alnum:]_])rm[[:space:]]+-f[[:space:]]+(~|\*)([^[:alnum:]_]|$)'
    '(^|[^[:alnum:]_])sudo[[:space:]]+rm([^[:alnum:]_]|$)'

    # System modification
    '(^|[^[:alnum:]_])chmod[[:space:]]+777([^[:alnum:]_]|$)'
    '(^|[^[:alnum:]_])chmod[[:space:]]+-R[[:space:]]+777([^[:alnum:]_]|$)'
    '(^|[^>])>[[:space:]]*/etc/'
    '>>[[:space:]]*/etc/'

    # Network piping (code execution) — bypassed via trusted_install_urls above
    '(^|[^[:alnum:]_])curl([^[:alnum:]_]|$).*\|.*(^|[^[:alnum:]_])(sh|bash)([^[:alnum:]_]|$)'
    '(^|[^[:alnum:]_])wget([^[:alnum:]_]|$).*\|.*(^|[^[:alnum:]_])(sh|bash)([^[:alnum:]_]|$)'

    # Publishing. Blocked by default fleet-wide; dain-os's repo shadow allows
    # it (the DainOS MCP server package is published from there, each publish
    # explicitly authorised by the user).
    '(^|[^[:alnum:]_])npm[[:space:]]+publish([^[:alnum:]_]|$)'

    # Fork bomb
    ":\(\)\{.*\}.*:"

    # Disk operations — only match actual block devices, never /dev/null,
    # /dev/std{out,err}, /dev/tty*, /dev/fd/*, /dev/random, /dev/urandom etc.
    '(^|[^[:alnum:]_])dd[[:space:]]+[^;&|]*if='
    '(^|[^[:alnum:]_])mkfs([^[:alnum:]_]|$)'
    '> /dev/(sd|nvme|hd|disk|mmcblk|vd|xvd|loop|ram|sr)[a-z0-9]'

    # Code execution
    '(^|[^[:alnum:]_])node[[:space:]]+-e([^[:alnum:]_]|$).*(^|[^[:alnum:]_])(exec|spawn|child_process)([^[:alnum:]_]|$)'
    '(^|[^[:alnum:]_])node[[:space:]]+-e([^[:alnum:]_]|$).*require\([^)]*http'
    '(^|[^[:alnum:]_])python[[:space:]]+-c([^[:alnum:]_]|$).*(^|[^[:alnum:]_])exec([^[:alnum:]_]|$)'
    '(^|[^[:alnum:]_])eval[[:space:]]+\$'
)

for pattern in "${dangerous_patterns[@]}"; do
    # Bypass the curl/wget|bash patterns when the URL is on the trusted installer list.
    if [[ -n "${trusted_pipe_install:-}" ]] && [[ "$pattern" == *'(curl|wget)'* ]]; then
        continue
    fi
    if [[ "$safe_temp_rm" == true ]] && [[ "$pattern" == *'rm['* ]]; then
        continue
    fi
    if echo "$command_for_matching" | grep -qiE "$pattern" 2>/dev/null; then
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
# MAIN-TREE GIT MUTATIONS
# =============================================================================
# Worktree isolation is a per-repo policy, not a universal one: repos that
# mandate it (dain-os, eoc-herbert) carry the main-tree git-mutation guard in
# their repo-shadow variant of this hook (hook-<repo>-block-dangerous). Repos
# without the mandate (dain-website, portunus-pipelines) commit from the main
# tree, so a universal guard here would block every commit.

# =============================================================================
# SENSITIVE FILE ACCESS - BLOCK
# =============================================================================

# Reading .env files is ALLOWED — fleet-wide policy (Dane, 2026-07-18):
# sessions need .env values (at minimum names and lengths) for building,
# testing and debugging, and blocking the read created blockers with no safety
# gain on single-user dev machines. Private keys and the secrets/ directory
# stay blocked below, and the same split applies to settings.json permission
# rules (deny Read on .pem/.key/secrets/, never on .env).

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
