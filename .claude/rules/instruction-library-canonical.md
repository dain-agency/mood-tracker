# Instruction Library is Canonical

The DainOS instruction library — the database, accessed via `get_instruction` and `list_instructions` on the DainOS MCP — is the single source of truth for all skills, commands, rules, and agents.

Files under `.claude/skills/`, `.claude/commands/`, `.claude/rules/`, and `.claude/agents/` are **auto-synced mirrors** of library entries (see the `chore(claude-tooling): sync .claude/ from library` commits). They exist so content is browsable on disk and works offline, but they can lag the library between syncs.

## The rule

When a name exists BOTH as a local skill/command/rule/agent AND as a library instruction, **the library wins**.

- When the user invokes something `via /invoke <name>`, or names an instruction that lives in the library, resolve it through `get_instruction` — do not run the local same-named skill or command directly.
- Library slugs are category-prefixed: `cmd-wrap-up`, `skill-ship-architect`, `rule-core-rules`, `agent-*`, and user-level entries as `user-cmd-*` / `user-skill-*`. The bare name (`wrap-up`) will 404. `/invoke` does the prefix fallback for you; if you call `get_instruction` directly, try the `cmd-` / `skill-` / `rule-` / `agent-` prefixes yourself.
- Reading the on-disk mirror for reference is fine, but never assume it is current. If behaviour matters, fetch the library version.

## Why

On 2026-05-31, `/invoke wrap-up` ran the local `.claude/commands/wrap-up.md` mirror instead of the canonical `cmd-wrap-up` library entry. It happened to be in sync (both v11), so no harm done, but the moment the library advances and the on-disk sync lags, the two diverge silently and the wrong version runs. The mirror is a cache, not the source.

The same investigation surfaced a slug gotcha: a human types `/invoke wrap-up`, but the library slug is `cmd-wrap-up`. `/invoke` must resolve the category prefix rather than 404 and fall back to disk. That fallback is now built into `.claude/commands/invoke.md`.

## Per-category channels (amended 2026-07-18, audit §4 R9)

The single-channel model above holds for PROSE instructions only. The daily `.claude/` auto-sync was disabled on 2026-07-16 after it clobbered project-specific rules with unresolved universal templates, so distribution now works per category:

- **Rules, skills, commands, agents (prose):** the library is canonical; resolve at runtime via `/invoke` / `get_instruction`. On-disk mirrors are frozen caches and MAY lag — never assume currency.
- **Hooks:** the DISK copy in each repo is the executing artefact (hooks run from `settings.json` paths; `/invoke` cannot execute them). The library holds the reference body; repo copies are reconciled by deliberate PRs, and drift is detected by the weekly enforcement audit (checksum comparison), not by auto-sync.
- **settings.json:** never distributed by file copy. `config-settings` is a CONTRACT (required wiring + permission-rule forms), checked by the enforcement audit.

Library-write gotchas: use base64 for large bodies (SQL escaping silently truncates, KB a7f9d9b5); never round-trip `get_instruction` output into an upsert — it resolves template variables and destroys them (KB b27bd0e3); edit from the raw DB body instead.
