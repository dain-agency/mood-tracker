---
description: Fetch and execute an instruction from the DainOS library.
argument-hint: <slug> [args...]
allowed-tools: Bash(~/.dain-os/bin/instruction get:*)
---

Fetch and execute an instruction from the DainOS instruction library.

The library (the database) is the SINGLE SOURCE OF TRUTH for every skill, command, rule, and agent. Files under `.claude/skills/`, `.claude/commands/`, `.claude/rules/`, and `.claude/agents/` are auto-synced MIRRORS that can lag the library — never run a same-named local file when the library has the entry. See `.claude/rules/instruction-library-canonical.md`.

The block below was fetched at command time by the instruction CLI (`scripts/instruction/`), which resolves category-prefixed slugs (`cmd-`, `skill-`, `rule-`, `agent-`, `user-cmd-`, `user-skill-`) deterministically against the canonical REST endpoint. The first word of the input is the slug; any following words are passed through as the fetched instruction's own arguments (e.g. `/invoke cmd-wrap-up auto`).

## Fetched instruction

<!-- Single quotes are deliberate: $ARGUMENTS is textual substitution, and inside double
     quotes an injected $(...) or backtick would still execute. Inside single quotes nothing
     is special except ' itself, and the CLI rejects any slug outside [a-z0-9-]. -->
!`~/.dain-os/bin/instruction get '$ARGUMENTS' --project "$(basename -s .git "$(git remote get-url origin 2>/dev/null)" 2>/dev/null)"`

## How to proceed

Act on the FIRST state that matches the block above:

1. **`--- INSTRUCTION <slug> ... ---` marker present** — the content between the markers IS the instruction, fetched from the canonical library with template variables resolved. Follow it directly as if it were inline in this conversation. If an `ARGS FOR THIS INSTRUCTION` line follows the end marker, treat its value as the `$ARGUMENTS` of the fetched instruction. If a `WARNING: unresolved template variables` line follows, tell the user which variables did not resolve.
2. **`INSTRUCTION NOT FOUND`** — show the user the listed closest matches and stop. Do NOT silently fall back to a local file of the same name.
3. **`NO SLUG PROVIDED` or `INVALID SLUG`** — ask the user which instruction to run.
4. **`INSTRUCTION FETCH FAILED`, `command not found`, or anything else** — the CLI is unavailable (not installed on this machine, or the API is unreachable). Fall back to the DainOS MCP: call `get_instruction({ slug: "$ARGUMENTS", project: "<this repo's slug, from git remote get-url origin>" })`, retrying with the prefixes `cmd-`, `skill-`, `rule-`, `agent-`, `user-cmd-`, `user-skill-` on not-found; if none resolve, call `list_instructions({ q: "$ARGUMENTS", project: "<this repo's slug>" })` and show the user the closest matches. If the failure said `no API token configured` or the CLI was missing, also suggest running the installer once on this machine (`bash scripts/instruction/install.sh` from a dain-os checkout).