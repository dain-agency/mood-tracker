# Otto AI Route Contract (gate)

**MANDATORY before writing or editing any `/api/ai/*` route, any client hook that calls one, or `scripts/check-ai-route-contract.sh`:**
→ Invoke `/otto-ai-routes` (Skill tool with `skill: "otto-ai-routes"`; library slug `skill-otto-ai-routes`). It is the single source of truth for the full contract.

The contract in one breath — all explained with correct/wrong examples in the skill:

Four CI-guarded invariants:
1. SSRF allowlist from the shared `_lib/api-host.ts` module — never inline `ALLOWED_API_HOSTS`.
2. Routes accept `userContext` in their Zod request schema (production cookie-forwarding fallback).
3. Client hooks forward `userContext` via `useOttoUserContext` (exempt: `/api/ai/copilot` and `/api/ai/command` — generic editor wrappers, no Otto auth).
4. Every client-supplied string interpolated into a system prompt passes through `sanitiseForPrompt`.

Three more rules from the same investigation (not auto-enforceable yet):
5. System prompts inject the active entity's id + name.
6. Open-domain routes expose a search tool.
7. Client hooks use `useChat` from `@ai-sdk/react` OR a documented, unit-tested SSE parser — never a hand-rolled NDJSON parser.

CI guard: `scripts/check-ai-route-contract.sh` (wired into `pr-build-check.yml`). Run it locally before opening a PR that touches AI routes.

> Why a stub: the full contract is ~250 lines and only matters for AI-route work. Keeping it in an on-demand skill keeps the always-loaded rule layer lean.
