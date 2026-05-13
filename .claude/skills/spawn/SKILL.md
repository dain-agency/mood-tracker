---
name: spawn
description: >
  Spawn one or more subagents for a task with deliberate scope triage. Before invoking the Agent tool,
  this skill forces a pre-spawn evaluation — checking whether a specialised agent fits, whether the task
  should be split, and which model to use. Use whenever the user asks to "spawn an agent", "delegate to
  a subagent", "run this in parallel", or when you're about to call the Agent tool for non-trivial work.
user-invocable: true
disable-model-invocation: false
---

# Spawn — Deliberate Subagent Dispatch

Stop and triage **before** calling the Agent tool. A badly-scoped subagent produces placeholder code, skips project patterns, and wastes a cache window. A well-scoped one saves hours.

## Constraints (honest)

- Subagents cannot be given the `[1m]` context variant — the `model` param only accepts `sonnet | opus | haiku`.
- Subagents cannot talk to each other. Coordination is always parent-orchestrated.
- Each subagent call is a closed box: prompt in, one message out. No retries without losing state.

## Step 1 — Match a specialised agent first

Before defaulting to `general-purpose`, check whether one of these fits the task better. Specialised agents carry project-specific instructions that a generic agent lacks.

| Agent | When it's the right call |
|---|---|
| `Explore` | Open-ended codebase searches taking >3 queries. "How does X work?", "Find all places that Y." |
| `Plan` | Designing an implementation strategy before coding. Returns step-by-step plans. |
| `code-reviewer` | Independent second opinion on a diff, migration safety, PR review. |
| `react-specialist` | React component issues, hooks problems, rendering/perf in `.tsx` files. |
| `typescript-fixer` | Fixing type errors, removing `any`, creating interfaces. |
| `test-writer` | Writing or expanding test coverage. |
| `ship-scaffolder` | Round 0 of a Ship pipeline — stub files + INDEX.md anchors. |
| `ship-ui-builder` | Building React components/hooks/pages inside the Ship pipeline. |
| `ship-api-builder` | Zod schemas, services, controllers, route factories (Ship pipeline). |
| `ship-db-builder` | Supabase JS models, migrations, tenant-scoped registration. |
| `ship-test-builder` | Test builder inside a Ship pipeline. |
| `ship-ui-auditor` | Visual verification of UI rounds — Chrome-driven layout/responsiveness/CLEAR checks. |
| `ship-business-reviewer` | Verify build matches Feature Brief WHO/WHY/WHERE/WHEN. |
| `ship-quality-reviewer` | Code quality, type safety, security, error handling. |
| `ship-context-mapper` | Verify builders wrote under the correct scaffold anchors + INDEX updates. |
| `ship-structural-fixer` | Split oversized files; remediate context-mapper BLOCK findings. |
| `migration-specialist` | Porting an external app into a DainOS domain. |
| `storybook-writer` | Writing `.stories.tsx` for a new shared atom/molecule/organism/layout component. |
| `logger-fixer` | Sweeping `console.*`, empty catches, missing `logError`, or PII in logs. |
| `index-updater` | Auditing/fixing drift in domain `INDEX.md` files after file changes. |
| `claude-code-guide` | Questions about Claude Code, the Agent SDK, or the Anthropic API. |

If a specialised agent matches, **use it** — do not fall back to `general-purpose`.

## Step 2 — Score the scope

Before spawning, answer these honestly:

1. **How many files will the agent touch or create?**
2. **How many domains does it span?** (contacts, residents, crm, workforce, …)
3. **Does it need to iterate on its own output?** (build → test → fix)
4. **Would the result be hard for me to verify in one pass?**

### Rubric

| Signal | Recommendation |
|---|---|
| 1 file, 1 domain, 1 concern | **Single agent** — spawn it |
| 2–5 files, 1 domain, straight-line work | **Single agent, specialised if possible** |
| Scaffold → build → review flow | **2–3 sequential agents** (scaffolder → builder → reviewer) |
| Multiple domains OR needs cross-referencing outputs | **Parent orchestrates**, spawn per-piece subagents |
| Open research across the repo | **Single Explore agent**, thorough |
| "Build the whole feature" | **Stop.** Use `/ship` or decompose with `ship-plan-writer` first |

## Step 3 — Produce the triage note

Before calling Agent, surface a short triage to the user:

> **Task:** {what they asked}
> **Scope assessment:** {files/domains/complexity}
> **Recommendation:** {1 agent / N agents with focus areas / decompose first}
> **Agent choice:** {specialised agent name, or general-purpose + model}
> **Proceeding unless you redirect.**

Keep it under 6 lines. If the user has already green-lit the scope, skip the triage and spawn directly.

## Step 4 — Model selection

Defaults:
- **opus** — deep reasoning, architecture, independent reviews, hard bugs
- **sonnet** — standard builds, refactors, most ship-* agents (they set this themselves)
- **haiku** — quick lookups, single-file edits, fast iterations

Only override the specialised agent's model if the user explicitly asks.

## Step 5 — Write a self-contained prompt

Subagents inherit nothing from this conversation. The prompt must include:

- **Goal** — what success looks like
- **Context** — file paths, line numbers, constraints, what's already been tried
- **Scope boundary** — what NOT to touch
- **Deliverable** — "return a diff", "return findings under 200 words", "write the file and report the path"

Never write "based on your findings, implement the fix." That delegates understanding. You synthesise; the agent executes a bounded task.

## Step 6 — Parallel vs sequential

- **Parallel** (single message, multiple Agent calls): genuinely independent work. E.g. "audit domain A" + "audit domain B".
- **Sequential**: any case where agent N's output informs agent N+1's input. Do the orchestration yourself — subagents can't hand off.
- **Background** (`run_in_background: true`): long-running work you don't need immediately. Notifications fire on completion — don't poll.

## Anti-patterns

- Spawning a `general-purpose` agent when a specialised one exists
- "Build the feature end-to-end in one agent"
- Passing the user's message verbatim as the prompt (no context transplant)
- Spawning on a task you could do in <3 tool calls yourself
- Firing the agent-scope-check hook as the first line of defence — that's the backstop, not the gate. Triage here, not there.

## Escape hatch

If the user has said "just spawn it, I don't want triage" in this session, skip Steps 2–3 and go straight to spawn. Still pick the right specialised agent in Step 1.
