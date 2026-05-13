#!/usr/bin/env bash
# Block code edits while on protected branches (develop, main).
#
# Why: work must land on feature branches so PRs can be reviewed and Greptile
# can run. Direct edits on develop/main cause mid-session scramble to branch
# and cherry-pick, or worse, accidental direct pushes.
#
# Guarded tools:
#   - Write / Edit / NotebookEdit — inspect `.tool_input.file_path`
#   - Bash — inspect `.tool_input.command` for write-like shell patterns
#     (redirections `>`/`>>`, `tee`, `sed -i`, `printf ... >`, heredocs to
#     file) targeting code-ish extensions. Conservative: read-only commands
#     (grep, ls, cat-without-redirect, git status, etc.) are not blocked.
#
# Allowed even on protected branches (documentation / tooling / config —
# these are often edited session-to-session without needing a PR):
#   - *.md files anywhere
#   - .claude/** (hooks, settings, agents, skills, rules)
#   - CODEBASE_MAP.md, MEMORY.md, INDEX.md files
#   - docs/** (audits, PRDs, gotchas, notes)
#   - .gitignore, .npmrc, .env.example, .editorconfig
#
# Escape hatch: set `ALLOW_PROTECTED_BRANCH_EDIT=1` in the environment for
# the session, or add a commit-hygiene exception to this script.

set -uo pipefail

input="$(cat)"
tool="$(printf '%s' "$input" | jq -r '.tool_name // ""')"

case "$tool" in
  Write|Edit|NotebookEdit|Bash) ;;
  *) exit 0 ;;
esac

# Escape hatch for the rare legitimate case (e.g. fixing a broken hook on develop)
if [[ "${ALLOW_PROTECTED_BRANCH_EDIT:-0}" == "1" ]]; then
  exit 0
fi

# For Bash we look at the command; for the file-path tools we look at the path.
if [[ "$tool" == "Bash" ]]; then
  command_text="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"
  if [[ -z "$command_text" ]]; then
    exit 0
  fi

  # Code-ish extensions worth protecting. Keep in sync with the list below.
  code_ext_re='\.(tsx?|jsx?|css|scss|sql|json|ya?ml|sh|mjs|cjs)'

  # Write-like patterns:
  #   1. redirection (`>` or `>>`) into a code-ish path
  #   2. `tee` (with or without `-a`) of a code-ish path
  #   3. `sed -i` against a code-ish path
  # The patterns are intentionally conservative — false negatives are fine,
  # false positives are not (reads shouldn't be blocked).
  write_re_1=">>?[[:space:]]*[^|&;<>[:space:]]*${code_ext_re}([[:space:]]|$)"
  write_re_2="tee([[:space:]]+-[aA]?)?[[:space:]]+[^|&;<>[:space:]]*${code_ext_re}([[:space:]]|$)"
  write_re_3="sed[[:space:]]+(-[^[:space:]]*i[^[:space:]]*|--in-place)[[:space:]].*${code_ext_re}([[:space:]]|$|['\"])"

  if [[ ! "$command_text" =~ $write_re_1 ]] \
     && [[ ! "$command_text" =~ $write_re_2 ]] \
     && [[ ! "$command_text" =~ $write_re_3 ]]; then
    exit 0
  fi

  # Determine the branch via the cwd jq gives us (fall back to PWD).
  cwd_dir="$(printf '%s' "$input" | jq -r '.cwd // ""')"
  if [[ -z "$cwd_dir" ]]; then
    cwd_dir="$PWD"
  fi
  branch="$(git -C "$cwd_dir" branch --show-current 2>/dev/null || echo "")"

  case "$branch" in
    develop|main) ;;
    *) exit 0 ;;
  esac

  cat <<MSG >&2
=============================================================================
  BLOCKED: shell write on protected branch '$branch'
=============================================================================

Command: $command_text

Shell redirections, \`tee\`, and \`sed -i\` into code files are treated the
same as Write/Edit on protected branches. Create a feature branch first:

  git checkout -b feat/<short-name>

Escape hatch (rare — e.g. fixing a broken hook on develop):
  ALLOW_PROTECTED_BRANCH_EDIT=1 (set in environment for this session)
MSG
  exit 2
fi

# Find the current branch. Resolve from the repo that owns the target file
# so the hook works correctly inside worktrees.
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')"

if [[ -z "$file_path" ]]; then
  exit 0
fi

# Normalise path (strip Windows backslashes for pattern-matching)
norm_path="${file_path//\\//}"

# Run git from the target file's directory so worktree branches are detected
target_dir="$(dirname "$norm_path")"
branch="$(git -C "$target_dir" branch --show-current 2>/dev/null || echo "")"

# Only guard the two protected branches
case "$branch" in
  develop|main) ;;
  *) exit 0 ;;
esac

# Allow-list: paths that don't require a feature branch
case "$norm_path" in
  *.md)                                exit 0 ;;
  */.claude/*)                         exit 0 ;;
  */docs/*)                            exit 0 ;;
  */MEMORY.md|*/INDEX.md)              exit 0 ;;
  */CODEBASE_MAP.md|*/README.md)       exit 0 ;;
  */.gitignore|*/.npmrc|*/.env.example|*/.editorconfig) exit 0 ;;
  */project-config*.md|*/project-config*.json)          exit 0 ;;
esac

cat <<MSG >&2
=============================================================================
  BLOCKED: code edit on protected branch '$branch'
=============================================================================

Target path: $file_path

Work must land on a feature branch. Create one before editing:

  git checkout -b feat/<short-name>

Conventions:
  feat/* — new features, domain work
  fix/*  — bug fixes
  chore/* — tooling, deps, refactors

Allowed on develop/main without branching: *.md, .claude/**, docs/**,
.gitignore, .npmrc, .env.example, project-config*.

Escape hatch (rare — e.g. fixing a broken hook on develop):
  ALLOW_PROTECTED_BRANCH_EDIT=1 (set in environment for this session)
MSG

exit 2
