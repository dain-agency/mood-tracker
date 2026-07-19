# Instruction Library is Canonical

The DainOS instruction library — the database, accessed via `get_instruction` and `list_instructions` on the DainOS MCP (REST: `GET /api/v1/instructions`) — is the single source of truth for all skills, commands, rules, agents and hooks.

## The rule

When a name exists BOTH as a local file AND as a library instruction, **the library wins**.

- When the user invokes something via `/invoke <name>`, or names an instruction that lives in the library, resolve it through `get_instruction` — do not run a local same-named copy directly.
- Library slugs are category-prefixed: `cmd-wrap-up`, `skill-ship-architect`, `rule-core-rules`, `hook-type-safety`, `agent-*`, and user-level entries as `user-cmd-*` / `user-hook-*`. The bare name (`wrap-up`) will 404. `/invoke` does the prefix fallback for you; if you call `get_instruction` directly, try the `cmd-` / `skill-` / `rule-` / `hook-` / `agent-` prefixes yourself.
- Repo-specific overrides shadow universal entries by sharing a `target_path` (or the `<category>-<repo>-<name>` slug convention, e.g. `hook-dain-os-block-dangerous` shadows `hook-block-dangerous` on dain-os). The most-specific compatible entry wins.

## Per-category channels (revised 2026-07-18, live-sync rollout)

- **Rules, hooks + agents: library-owned cache, refreshed at session start.** In repos on the live sync (dain-os is the reference), `.claude/rules/` and `.claude/hooks/` are **gitignored caches** materialised from the library by `.claude/sync/library-sync.mjs` (wired as the SessionStart hook; fail-open, so offline sessions serve the cached copies). The injected rule files are therefore current at session start — do NOT bulk-fetch rules over MCP. To change a rule or hook, edit the **library**; local cache edits are overwritten by the next sync. Bodies with unresolved `template variables` are refused by the sync (fix `project_configs.template_variables` for the repo, then re-sync). Fixtures and the fixture harness stay git-tracked; CI (`claude-hooks-lint`) materialises hooks from the live library on a weekly schedule and runs the fixture canaries against exactly what sessions execute.
- **Skills + commands: invoke stubs.** Local files are one-line loaders that fetch their canonical library body via `get_instruction` at invocation time (agents joined the synced cache instead, because subagents cannot self-fetch; ship agents keep their legacy skill-* slugs with category agent). Deprecated library entries have no local file at all — deprecating an entry removes it from every synced repo.
- **settings.json:** never distributed by file copy. `config-settings` is a CONTRACT (required wiring + permission-rule forms), checked by the enforcement audit; the sync WARNS when a synced hook is unwired but never rewrites settings.

## Why

On 2026-05-31, `/invoke wrap-up` ran the local mirror instead of the canonical `cmd-wrap-up`; the two happened to match, but a lagging mirror silently runs the wrong version the moment the library advances. The daily file auto-sync was disabled on 2026-07-16 after it clobbered project-specific rules with unresolved universal templates (KB 92e510a6, a5efab12) and synced a stale npm-bundled snapshot rather than the live library (KB f2575cce). The live session-start sync replaces both failure modes: one API call, version-diffed, most-specific-wins per target path, unresolved-variable refusal, and deletions when an entry leaves the plan (KB 42388985).

Library-write gotchas: `hook`/`config` categories require API >= PR #879 (older Zod enums 422 them; direct SQL with base64 bodies is the fallback — plain SQL escaping silently truncates, KB a7f9d9b5); never round-trip `get_instruction` output into an upsert when the entry has template variables — resolution destroys them (KB b27bd0e3); edit from the raw DB body instead.