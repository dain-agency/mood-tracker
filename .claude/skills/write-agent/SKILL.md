---
name: write-agent
description: >
  Author a new specialised agent in .claude/agents/ consistently with existing patterns.
  Use when the user asks to "create an agent", "add a subagent", "write an agent for X",
  or when proposing a new agent. Enforces de-duplication checks, length discipline,
  and links to project rules instead of restating them.
user-invocable: true
disable-model-invocation: false
---

# Write-Agent — Consistent Agent Authoring

Before writing a new agent, run through this checklist. A bloated or duplicative agent wastes cache on every invocation and fragments project knowledge.

## Step 1 — Justify the agent

Answer these before creating the file. If any answer is weak, don't create it.

1. **What specific task does it own?** One sentence. If you need two sentences, it's too broad — split it or don't create it.
2. **Why isn't a skill enough?** Skills are cheaper (reloaded in parent context, no new window). Agents are right when the task needs isolation, a fresh context, or deep focus on one file at a time.
3. **Why isn't a hook enough?** Mechanical enforcement (linting, blocking anti-patterns) belongs in hooks — they always run. Agents are for judgment work.
4. **Does an existing agent already cover this?** Check `.claude/agents/` first. If an existing agent covers 70% of the task, extend it rather than create a new one.

## Step 2 — Check for duplication

Before drafting, run:

```bash
ls .claude/agents/
grep -l "<keyword>" .claude/agents/*.md
```

Common overlaps to watch:
- `code-reviewer` already covers general review — don't create per-topic reviewers
- `typescript-fixer` already covers `any` sweeps — don't create narrower type agents
- `ship-*` agents are pipeline-scoped — don't replicate them as generic variants without reason
- Built-in agents (`Explore`, `Plan`) cover open-ended search and planning — don't rebuild these

## Step 3 — Frontmatter (required shape)

```yaml
---
name: <kebab-case-name>
description: <one sentence stating the domain>. Use PROACTIVELY when <trigger condition>. Triggers on "<phrase>", "<phrase>", "<phrase>".
tools: Read, Write, Edit, Grep, Glob, Bash
model: sonnet
---
```

- **`name`** — lowercase, hyphenated, matches the filename
- **`description`** — *the* most important field. The dispatcher reads this to decide when to invoke. Include: domain, `PROACTIVELY` keyword if applicable, 3–5 trigger phrases in quotes
- **`tools`** — minimum set needed. Review/audit agents typically don't need `Write` or `Edit`. Builder agents usually do. Never include tools that aren't used
- **`model`** — `sonnet` is the default for builders/fixers. Use `opus` only for deep reasoning (architecture, independent reviews). `haiku` only for single-file mechanical fixes. Omit to inherit parent.

## Step 4 — Body structure

Follow this skeleton. Sections in **bold** are required.

```markdown
# <Agent Title>

You are <role>. <one-line scope statement>.

## **Core Principles / Rules**

Numbered list. 3–8 items. Short, imperative.

## **Scope boundaries**

What this agent does NOT do. Prevents scope creep mid-task.

## Patterns / Examples

Concrete code blocks. Surgical — not an encyclopedia. If the knowledge lives
in `CLAUDE.md`, `.claude/rules/*`, or `docs/gotchas/GOTCHAS.md`, LINK to the
rule by path rather than restating it. Duplication rots.

## **Process**

Numbered steps the agent follows from invocation to completion.

## **Verification**

How the agent proves its work is correct before reporting done.
Usually: `npx tsc --noEmit`, targeted vitest, grep for what was fixed.

## **Output Format**

Exact shape of the final message back to the parent. Parents orchestrate
based on this — make it predictable.
```

## Step 5 — Length discipline

| Agent type | Target lines | Why |
|---|---|---|
| Narrow mechanical (fixer/sweeper) | 80–180 | One job, tight rules, quick examples |
| Builder (generates files) | 150–300 | Needs patterns + scope boundaries + verification |
| Reviewer / auditor | 100–200 | Checklist-driven, output format heavy |
| Orchestrator (rare) | 200–400 | Dispatches others, needs coordination logic |

If you're exceeding the target, the agent is probably too broad.

## Step 6 — Avoiding context bloat

**Link, don't restate.**

- Rules live in `.claude/rules/core-rules.md`, `design-system.md`, `testing-standards.md`, `gotchas-gate.md` — reference by path, don't copy
- Gotchas live in `docs/gotchas/GOTCHAS.md` with stable anchors — tell the agent which anchor to load
- Design system patterns live in Storybook + archetype stories — tell the agent to query them, don't paste the HTML
- `CLAUDE.md` is auto-loaded — don't restate its content

**Use examples as instruction, not inventory.**

- Two good examples beat six mediocre ones
- Prefer diffs/transformations over finished artefacts — shows the delta
- Never paste a whole file; paste the 10 lines that illustrate the pattern

## Step 7 — Self-contained invocation

The parent must be able to invoke the agent with only a short task prompt. The agent file should encode:

- Project conventions (via rule file paths)
- Deliverable shape
- Verification commands

If the agent needs the parent to pass a 400-word briefing every time, the agent is under-specified — push that content into the agent file.

## Step 8 — Register and announce

After writing:

1. Agent is auto-discovered from `.claude/agents/` — no registration step
2. Add it to the specialised-agents table in `.claude/skills/spawn/SKILL.md` so the spawn triage picks it up
3. Mention it to the user and suggest a first task to validate it

## Anti-patterns

- Agent description without trigger phrases — dispatcher can't route to it
- Restating `core-rules.md` inside the agent — one source of truth per rule
- Tools list including `Write` on a reviewer agent — scope leak risk
- Agent longer than 400 lines — too broad, split it
- Agent that duplicates 70%+ of an existing one — extend the existing instead
- Examples that show entire files — pastes become stale, patterns don't
- Using `opus` model by default — reserve for work that actually needs it

## Reference: existing agents to study

Short and tight: `typescript-fixer.md` (184), `code-reviewer.md` (98), `ship-db-builder.md` (79)
Long but justified: `ship-ui-auditor.md` (466 — visual + CLEAR + WCAG spans a lot), `ship-ui-builder.md` (385)

When in doubt, copy the shape of `typescript-fixer.md` — it's the cleanest mechanical-fixer pattern in the repo.
