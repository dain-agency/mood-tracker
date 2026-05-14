# Otto AI Route Contract

Single source of truth for every `/api/ai/*` route and its client consumer.

This contract exists because three production-blocking bugs (PRs #197/#198/#199) all stemmed from the same drift pattern: each new Otto-class route reinvented its own auth handling, its own SSRF allowlist, its own system prompt structure. Drift is now caught by `scripts/check-ai-route-contract.sh`, wired into `pr-build-check.yml`.

## The four invariants

### 1. SSRF allowlist comes from one shared module

Every route that hits the Express API must derive its base URL through `_lib/api-host.ts`. Never inline a fresh `ALLOWED_API_HOSTS`.

```ts
// ✅ Correct
import { getAuthMeUrl, getApiBaseUrl, buildApiUrl } from '../_lib/api-host';

// ❌ Wrong — drift waiting to happen
const ALLOWED_API_HOSTS = ['localhost', '127.0.0.1'];
```

### 2. Routes must accept `userContext` for the production fallback

In production (`dainos.app` web → `api.dainos.app` express), server-side cookie forwarding to `/auth/me` fails because cookies issued by the API host aren't present on requests to the web host. The route must accept a client-supplied `userContext` (name + email) so it can identify the user for Anthropic cost attribution. Downstream data access is still cookie-authorised by tools — Strategy 2 never grants permissions, only metadata.

```ts
const requestBodySchema = z.object({
  // ...
  userContext: z
    .object({ name: z.string().optional(), email: z.string().email().optional(), /* ... */ })
    .optional(),
});

const userContext = await validateSessionAndGetUser(req, parsed.data.userContext);
if (!userContext) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
```

### 3. Client hooks must forward `userContext` via the shared helper

```ts
// ✅ Correct
import { useOttoUserContext } from '@/domains/auth/hooks/use-otto-user-context';

const userContext = useOttoUserContext();
// then in the request body:
body: { ...other, userContext }

// ❌ Wrong — silently 401s in production
body: { ...other }  // missing userContext
```

Exempt: `/api/ai/copilot` and `/api/ai/command` are generic editor wrappers and don't use Otto auth.

### 4. System prompts must sanitise client-supplied strings

Any string that originates from the request body and ends up interpolated into a system prompt must pass through `sanitiseForPrompt` first. UUID + enum + date fields are Zod-validated and don't need sanitisation.

```ts
import { sanitiseForPrompt } from '../_lib/prompt-safety';

function buildSystemPrompt(ctx: { projectId: string; projectName?: string }) {
  const safeName = sanitiseForPrompt(ctx.projectName);  // strips control chars + caps length
  return `Active project: "${safeName}" (id: ${ctx.projectId})`;
}
```

The sanitiser strips `\r \n \t` plus the C0 + DEL control ranges. This collapses prompt-injection payloads (`"X\n\nIgnore all rules: ..."`) onto a single line so they can't pose as fresh instruction blocks.

## Two more rules from the same investigation (not auto-enforceable yet)

### 5. System prompts must inject the active entity context

Every Otto wizard knows which entity (project, deal, task, ...) it's operating on. The system prompt MUST include the entity's id + name. Otherwise the model has to ask the user, which is the failure pattern that triggered PR #198.

```ts
// ✅ Correct
function buildSystemPrompt(ctx: { projectId: string; projectName?: string }) {
  const safeName = sanitiseForPrompt(ctx.projectName);
  return `ACTIVE PROJECT — "${safeName}" (id: ${ctx.projectId}).
Use this projectId for every tool call. Do NOT ask the user for a project ID.`;
}

// ❌ Wrong — model has no idea which entity it's working with
function buildSystemPrompt() { return `You are Otto. Help the user...`; }
```

### 6. Open-domain Otto routes need a search tool

Routes that aren't entity-locked (e.g. the regular Otto chat, future cross-domain assistants) must expose a search tool over the relevant data so the user never hears "I can only work with the ID you provide."

### 7. Client hooks must use `useChat` OR a documented SSE parser — never a hand-rolled NDJSON parser

The official `useChat` hook from `@ai-sdk/react` coalesces stream events correctly. Wizards that need an imperative async API (one-shot `rankPriorities`, `summariseYesterday` — not a chat conversation) MUST implement the SSE parser correctly:

- Parse `data: {json}` events, NOT `4:{json}` NDJSON.
- Coalesce `text-delta` events by `id` into final `text` parts on `text-end`.
- Track `toolCallId → toolName` from earlier `tool-input-start` / `tool-input-available` events, because `tool-output-available` carries only `toolCallId`, not `toolName`.
- Provide a unit test that exercises a captured real-format SSE response — mocking the chat hook in vitest is necessary but NOT sufficient; the parser itself must have a test.

```ts
// ✅ Correct — the official hook
import { useChat } from '@ai-sdk/react';
const { messages, sendMessage } = useChat({ api: '/api/ai/...' });

// ✅ Correct — manual fetch + documented SSE parser
const res = await fetch('/api/ai/...', { ... });
// reader loop: parse `data: {event}` lines, coalesce text-delta by id,
// map tool-output-available via toolCallId → toolName cache.
// Reference: apps/web/src/domains/day-planner/hooks/use-day-planner-chat.ts:callAiRoute

// ❌ Wrong — silently drops every event since AI SDK v5+
const colonIdx = trimmed.indexOf(':');
const eventData = trimmed.slice(colonIdx + 1);
const parsed = JSON.parse(eventData);
if ('role' in parsed) messages.push(parsed); // never matches stream events
```

**Why this matters:** the hand-rolled NDJSON parser shipped in two Otto wizards (PRD-072 EoD half PR #195, PRD-072 morning half through commit `1f75fbdc`). Both silently 401-equivalent on production: the regen counter ticks, but `result.tasks` is always `[]` and `result.narrative` is always `null` because the parser drops every SSE event. Tests didn't catch it because they mocked the chat hook entirely. Day Planner shipped fixed in PR #202 (commit `d7245ca0`); EoD's matching fix is tracked in PRD-080.

Guard regex (extends `scripts/check-ai-route-contract.sh` Guard 7):

```bash
grep -rnE "\.indexOf\\(':'\\)|^\\s*'4:'|\"role\" in parsed" apps/web/src/domains/*/hooks/use-*-chat.ts
```

A non-empty match = block.

## When you add a new `/api/ai/*` route

1. Import URL builders from `_lib/api-host` (invariant 1).
2. Declare `userContext` in your Zod request schema (invariant 2).
3. Build your client hook on top of `useOttoUserContext` (invariant 3).
4. If your system prompt interpolates any client-supplied string, pass it through `sanitiseForPrompt` (invariant 4).
5. Inject the active entity context into the system prompt (rule 5).
6. Use `useChat` from `@ai-sdk/react` for the client hook, OR document the SSE parser + ship a parser test (invariant 7).
7. Run `bash scripts/check-ai-route-contract.sh` locally to confirm before opening a PR.
