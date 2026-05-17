---
description: Ship a feature end-to-end — discover, design, plan, build, review, merge
argument-hint: <feature description or path to existing feature brief / progress file>
---

# Ship v2: $ARGUMENTS

Agent Swarm Feature Factory — from idea to merged PR via six layers of context.

**YOU ARE A PIPELINE COORDINATOR.** You execute phases in order, invoke specialised skills and agents at each phase, enforce human gates, and track progress. You do NOT do the work yourself — you delegate to the right agent/skill for each phase.

---

## The Pipeline

```
0.   Initialise      → Route check, project config, progress file
0.5. Environment Gate → Validate dev servers + tsc + env vars BEFORE any expensive work
1.   Discovery       → WHO / WHY / WHERE / WHEN / Journeys     [SKILL: ship-discovery — INLINE in main thread]
2.   HUMAN GATE      → "Does this describe the people and context accurately?"
3.   Architect       → Technical Strategy + Implementation Spec [AGENT: ship-architect]
4.   HUMAN GATE      → "Does the technical approach serve the human context?"
5.   Plan            → Task Manifest with rounds + dependencies [AGENT: ship-plan-writer]
6.   Build           → Foreman dispatches builders + reviewers  [AGENT: ship-foreman]
7.   Pre-Flight      → Final technical checks                   [AGENT: ship-preflight]
8.   E2E Testing     → Browser tests against user journeys      [AGENT: ship-e2e]
9.   HUMAN REVIEW    → User tests running application
10.  PR              → Push, create PR, one Greptile cycle      [AGENT: ship-pr]
11.  Retrospective   → Analyse build, propose pipeline patches  [SKILL: ship-retrospective — INLINE in main thread]
12.  Human merges
```

### Inline vs Agent dispatch — why the distinction matters

Two phases now run as **inline `Skill` invocations** in the main conversation, not as `Agent` dispatches:

- **Phase 1 (Discovery)** — needs `AskUserQuestion`, which is only available in the main thread. Subagents cannot interactively interview the user. A subagent-dispatched discovery silently degrades into a speculative brief that fakes the appearance of an interview. That is a trust bug, not a token bug. **Always inline.**
- **Phase 11 (Retrospective)** — same reason. The retro is a conversation about what to patch, not a job to delegate.

Build, review, and code-writing phases stay as `Agent` dispatches — those genuinely benefit from isolated context.

---

## Route Check — run BEFORE Phase 0

**Read this first. /ship costs $50-150 and takes half a day. If this feature is simpler, use a lighter command.**

Answer these 3 questions:

| Question | Yes = +1 | No = 0 |
|---|---|---|
| Needs a new DB table or schema change? | +1 | 0 |
| Touches 3+ domains OR creates 5+ new files? | +1 | 0 |
| Design is genuinely ambiguous — needs structured discovery? | +1 | 0 |

**Score 0-1 → Use `/new-feature`** (~$5-15, 30-60 min. Same result, 10x cheaper.)
**Score 2 → Ask the user:** "Can you write the brief yourself in 10 minutes? If yes → `/new-feature`. If no → continue."
**Score 3 → Proceed with `/ship`** — the full pipeline is justified.

**Other lighter options:**
- Bug fix → `/debug` + PR
- Migration → `/migrate-app`
- Resume existing ship → `/ship docs/plans/YYYY-MM-DD-progress.md`

**Before proceeding:** Present your score and recommendation to the user:
> "This is a [N]/3 on the /ship complexity scale. I recommend [tool] — it will cost ~$[estimate] and take ~[time]. Should I use /ship or switch to [lighter option]?"

**Only continue to Phase 0 once the user explicitly confirms /ship is the right tool.**

---

## Phase 0: Initialise

**This phase runs FIRST, ALWAYS, BEFORE anything else.**

### Determine input type

- If `$ARGUMENTS` is a path to a file containing `## Progress` → **Resume mode**: read the file, find the first incomplete phase, jump to it.
- If `$ARGUMENTS` is a path to a file containing `## 1. WHO` → **Feature Brief mode**: skip Discovery, go to Phase 3 (Architect).
- If `$ARGUMENTS` is a path to a file containing `"featureBrief"` (JSON) → **Task Manifest mode**: skip to Phase 6 (Build).
- Otherwise → **New feature mode**: start from Phase 1.

### Locate project config

Search for the project config (the architect's blueprint):
1. Check `docs/architecture/project-config.json`
2. Check for any `project-config.json` in the repo root or `docs/`
3. If found → record path in progress file, pass to Discovery and Architect
4. If not found → log in progress file: "No project config found — Discovery and Architect will work from scratch"

### Create progress file

Create `docs/plans/YYYY-MM-DD-<feature-slug>-progress.md`:

```markdown
# Ship Progress: <feature name>

**Started:** <ISO timestamp>
**Status:** IN_PROGRESS
**Branch:** (TBD)
**Worktree:** (TBD)

## Inputs
- **Description:** <feature description>
- **Project Config:** (TBD — path to project-config.json)
- **Feature Brief:** (TBD)
- **Task Manifest:** (TBD)

## Progress

| Phase | Status | Started | Completed | Notes |
|-------|--------|---------|-----------|-------|
| 0.5. Environment Gate | pending | | | |
| 1. Discovery | pending | | | |
| 2. Human Gate: Context | pending | | | |
| 3. Architect | pending | | | |
| 4. Human Gate: Brief | pending | | | |
| 5. Plan | pending | | | |
| 6. Build | pending | | | |
| 7. Pre-Flight | pending | | | |
| 8. E2E Testing | pending | | | |
| 9. Human Review | pending | | | |
| 10. PR | pending | | | |
| 11. Retrospective | pending | | | |

## Phase Telemetry

Recorded after every phase completion. Lets the retrospective answer *which phase ate the budget* without guessing.

| Phase | Model | Wall-clock | Output size | Interactions | Notes |
|-------|-------|-----------|-------------|--------------|-------|
| 0.5. Environment Gate | — | | — | — | |
| 1. Discovery | | | brief: N lines | N AskUserQuestion calls / M questions | |
| 3. Architect | | | brief: N lines added | N wireframes generated | |
| 5. Plan | | | manifest: N tasks / M rounds | — | |
| 6. Build (Round N) | | | files: N changed / M LOC | reviewer cycles: K | repeat per round |
| 7. Pre-Flight | | | — | findings: N | |
| 8. E2E Testing | | | journeys: N covered | failures: M | |
| 10. PR | | | — | greptile rounds: N | |
| 11. Retrospective | | | patches: N proposed / M applied | — | |

**Filling this in is mandatory.** If a phase finishes without a telemetry row, the orchestrator must stop and complete the row before moving on. Use proxy metrics when exact tokens aren't available: model id, wall-clock duration, output artifact size, count of interactive turns. Wall-clock comes from comparing the `Started` and `Completed` columns above.

## Review Reports
(populated during build)

## Failures & Fixes
(populated during execution)

## Suggestions for Human Review
(populated if issues found)
```

**Tell user:** "Progress file created at `<path>`. Starting Phase 0.5: Environment Gate."

---

## Phase 0.5: Environment Gate

**Fail fast on environment issues. The whole point: catch the bug at minute 5, not hour 4.**

Run these checks against the **main repo** (worktree doesn't exist yet — that's Phase 6). The goal is to confirm the *baseline* environment is healthy before we spend Opus tokens on Discovery and Architect.

### Check 1: Required env vars present

```bash
test -f apps/web/.env.local || echo "MISSING: apps/web/.env.local"
test -f apps/api/.env || echo "MISSING: apps/api/.env"
grep -q "NEXT_PUBLIC_API_URL" apps/web/.env.local || echo "MISSING: NEXT_PUBLIC_API_URL in apps/web/.env.local"
grep -q "DATABASE_URL" apps/api/.env || echo "MISSING: DATABASE_URL in apps/api/.env"
```

Any line emitting `MISSING:` → STOP, surface to the user, do not proceed.

### Check 2: TypeScript baseline is clean

```bash
cd apps/web && npx tsc --noEmit
cd ../api && npx tsc --noEmit
```

If either fails on `main` BEFORE this build started, the baseline is dirty. STOP and tell the user — do not start a build on top of an already-broken `main`.

### Check 3: Prisma client matches schema

```bash
cd apps/api && npx prisma validate
```

A stale Prisma client will cause silent 500 errors mid-build (see CLAUDE.md "Prisma generate after schema changes" rule). Catch it now.

### Check 4: Dev servers can boot (smoke test)

Only run this if the previous checks passed.

```bash
# Boot in background, give 20s, check health endpoint, kill.
bash scripts/dev.sh > /tmp/ship-env-smoke.log 2>&1 &
SMOKE_PID=$!
sleep 20
curl -fsS http://localhost:3001/health > /dev/null && echo "API: OK" || echo "API: FAIL"
curl -fsS http://localhost:3002/ > /dev/null && echo "WEB: OK" || echo "WEB: FAIL"
kill $SMOKE_PID 2>/dev/null
```

Both must report `OK`. Either `FAIL` → surface the log, stop the pipeline.

### Output

Record in the Phase Telemetry table:
- Each check result (pass/fail)
- Wall-clock duration of the gate

**Tell user:** "Environment gate passed (4/4). Starting Phase 1: Discovery." Or, on failure: "Environment gate failed at check N. Log: `<path>`. Fix this before /ship continues — the rest of the pipeline depends on a working baseline."

---

## Phase 1: Discovery

**Phase 1 runs INLINE in the main conversation thread, not as an Agent dispatch.**

> Why: Discovery requires `AskUserQuestion`, which is only available in the main thread. Subagents cannot interview the user — they silently degrade to writing speculative briefs. See pipeline diagram above.

Invoke the `ship-discovery` skill via the `Skill` tool. Pass the feature description from `$ARGUMENTS` as the skill argument.

The skill itself runs in this conversation: questions appear in your terminal, you answer, the next round of questions follows. There is no subagent. There is no waiting on a black-box dispatch.

**Output:** Sections 1–5 of the Feature Brief written to `docs/plans/YYYY-MM-DD-<feature>-brief.md`

Update progress file. Fill the Phase 1 telemetry row: model used, wall-clock duration, brief line count, and number of `AskUserQuestion` rounds + total questions asked.

**Tell user:** "Discovery complete. Feature Brief sections 1–5 at `<path>`."

---

## Phase 2: Human Gate — Context Review

**STOP. Present the Feature Brief sections 1–5 to the user.**

Ask: "Does this accurately describe the people, the need, and the context? Edit anything that's wrong before we proceed to technical design."

- If user approves → mark Phase 2 done, proceed
- If user edits → update the brief, re-confirm
- If user wants more discovery → re-invoke ship-discovery with the gap

---

## Phase 3: Architect

Dispatch the `ship-architect` agent with the Feature Brief path.

The Architect reads the codebase, finds patterns, and produces sections 6-7 (Technical Strategy + Implementation Spec). **If the feature involves UI changes, the Architect also generates mid-fi wireframes using the visual companion server and reviews them interactively with the user per-screen.**

**Output:** Complete Feature Brief (sections 6-7, plus 7b Wireframes if applicable) at the same path.

Update progress file. **Tell user:** "Architecture complete. Full Feature Brief at `<path>`."

---

## Phase 4: Human Gate — Brief Approval

**STOP. Present the complete Feature Brief to the user.**

Ask: "Does the technical approach serve the human context? If wireframes were generated, they're referenced in Section 7b of the brief. This is the key approval — everything after this is automated build + review."

- If user approves → mark Phase 4 done, proceed
- If user requests changes → update the brief, re-confirm

---

## Phase 5: Plan

Dispatch the `ship-plan-writer` agent with the Feature Brief path.

**Output:** Task Manifest at `docs/plans/YYYY-MM-DD-<feature>-tasks.json`

Update progress file. **Tell user:** "Plan complete. Task manifest at `<path>`. Starting automated build."

---

## Phase 6: Build

### Setup worktree

Invoke the `worktree` skill via the `Skill` tool with arguments `setup feat/<feature-slug>`. The skill owns the full setup recipe (worktree creation, hardlink-copy `node_modules`, env files, `prisma generate`, optional smoke test) and is the single source of truth for worktree gotchas. Do NOT inline a setup recipe here — it drifts. See `.claude/skills/worktree/SKILL.md`.

Worktree path produced by the skill: `.claude/worktrees/<feature-slug>/` (used by every step below — `<wt>` from here on).

**Note for resumes from older progress files:** earlier versions of /ship used `.worktrees/<feature-slug>/` (top-level) and appended a hardcoded `NEXT_PUBLIC_API_URL=https://<slug>.dain-api.localhost:1355` to `apps/web/.env.local`. Both are now obsolete — the path moved under `.claude/`, and the `dev.mjs` wrappers resolve the API URL at runtime via `portless get` (KB `31e0e6b0`). If you're resuming and find a baked URL or a `.worktrees/` path, the skill's setup will normalise it.

### Verify boot before dispatching the foreman

Run the skill's smoke-test block (see "Smoke test" in the worktree skill). If either dev server fails to boot, surface to the user before the foreman is dispatched. Builders can run without dev servers, but Phase 8 E2E cannot — fix it now.

Copy the Feature Brief and Task Manifest into the worktree's `docs/plans/`.

### Execute

Dispatch the `ship-foreman` agent with the task manifest path and worktree path.

The Foreman:
1. Reads the task manifest
2. For each round: dispatches builder agents → invokes review panel → fixes blocking issues
3. Tracks progress in a round-by-round log

**Output:** All code built, reviewed at each round boundary.

Update progress file with build results.

---

## Phase 7: Pre-Flight

Dispatch the `ship-preflight` agent with the worktree path.

**Output:** Pre-flight report (pass/fail with details).

If failures: fix and re-run. Max 3 cycles.

Update progress file.

---

## Phase 8: E2E Testing

### Non-browser features — decision point before invoking ship-e2e

**Before dispatching `ship-e2e`, check whether the Feature Brief describes any browser-testable journey.** Indicators that a feature has no browser surface:

- No new routes under `apps/web/src/app/`
- No new React components, pages, or dialogs
- No HTTP endpoints under `apps/api/src/domains/*/routes/`
- Journeys that run inside Claude Code (slash commands), GitHub Actions (CI), CLIs, or agent dispatches (reviewers, architect hooks) — i.e. surfaces that a Chrome browser cannot interact with

If ALL journeys fall into this category, **STOP and present the user with two options** (do NOT silently skip, do NOT invoke `ship-e2e` on nothing):

- **(a) CLI smoke test substitute (Recommended).** Run the CLI / script against real infrastructure (Supabase, GitHub API, filesystem) and verify end-to-end behaviour. Record outcome as "E2E-equivalent: PASS/WARN/BLOCK" in the progress file. This is the canonical non-browser E2E.
- **(b) Invoke `ship-e2e` anyway.** The agent reads journeys, determines none are browser-testable, and returns "no applicable journeys". Cleaner on paper; effectively a no-op.

There is no third "skip" option for non-browser features — at least one of (a) or (b) must run.

### Browser-testable features — invoke ship-e2e

Dispatch the `ship-e2e` agent with the Feature Brief path and worktree path.

The E2E Agent:
1. Reads user journeys from the Feature Brief
2. Generates a test plan mapping each journey to browser interactions
3. Presents the plan to the user for approval (run all / critical path / skip)
4. Starts dev servers from the worktree
5. Logs in and executes the test plan via Chrome browser automation
6. Reports pass/fail with persistence checks and UX constraint verification

**Output:** E2E Test Report (pass/fail per journey, persistence results, failure classification).

### On Boot Failure (dev servers won't start, auth fails, env mismatch)

This is the case that burned 60+ minutes on PR #140. **Boot failure is NOT a "skip with acknowledgement" situation** — it's a debug-and-fix situation.

If dev servers won't start, or the E2E agent reports it cannot reach the worktree's web app, or login fails:

1. **Capture the diagnostic.** Save the dev-server logs, the failing curl, and the actual env vars present in the worktree (`grep -E "API_URL|DATABASE|SUPABASE" .claude/worktrees/<slug>/apps/api/.env .claude/worktrees/<slug>/apps/web/.env.local`).
2. **Re-run the worktree skill's smoke test** (see `.claude/skills/worktree/SKILL.md`) and keep the logs.
3. **Check for baked URLs.** A baked `NEXT_PUBLIC_API_URL` in `apps/web/.env.local` defeats portless's per-worktree resolution. Run `grep '^NEXT_PUBLIC_API_URL=' .claude/worktrees/<slug>/apps/web/.env.local` — there should be no match. If one is present, delete it (the skill's setup step strips it, but a copy-from-main may re-introduce it).
4. **Compare other env vars against main's.** Specifically `DATABASE_URL` and any `*_KEY` that maps to a hostname.
5. **Surface the diagnostic to the user** with a one-line proposed fix. Apply and retry — up to 2 attempts.

If after 2 retries the env still won't boot, that's a *genuine* infrastructure issue, not a config gap. **Only then** is this an option:
- **(c) Acknowledged-deferral with mandatory follow-up PRD.** Stop, file a follow-up PRD in `docs/prds/` describing the env block and what's needed to unblock. Add a `tests-deferred` line to the Suggestions section of the progress file. Surface to user: "E2E unbootable after 2 retries due to <specific blocker>. Filed PRD-NNN. Recommend you test the running app manually in Phase 9 with extra scrutiny on <affected journeys>."

### On Test Failure (E2E started but tests fail)

If E2E tests fail:
1. The E2E agent returns a structured failure report identifying likely files involved
2. Route failures back to the Foreman — dispatch appropriate builders to fix
3. After fixes, re-run only failed test cases
4. **Max 2 E2E fix cycles** — after that, include remaining failures in the human review report

Update progress file. **Tell user:** "E2E testing [passed / N issues found]. Ready for your review."

---

## Phase 9: Human Review

**STOP. Present to the user:**

1. The full Review Report (accumulated from all round reviews)
2. The Pre-Flight report
3. The E2E Test Report (journey results, persistence checks, any remaining failures)
4. Instructions to test the running application

Ask: "The automated build, review, and E2E testing is complete. Please test the running application and focus on: does this feel right? All technical issues should already be caught. Tell me when you're happy to proceed to PR, or list what needs fixing."

- If user approves → proceed to Phase 10
- If user requests fixes → fix in worktree, re-run pre-flight + E2E, re-present

---

## Phase 10: PR

Dispatch the `ship-pr` agent with the worktree path, feature branch, and PR details.

The PR Agent:
1. Runs final PR checklist
2. Pushes branch
3. Creates PR with Feature Brief summary
4. Waits for Greptile review
5. Addresses one cycle of feedback

**Output:** PR URL and final state.

Update progress file. **Tell user:** "PR #<number> at <url>. Greptile feedback addressed. Ready for your merge."

---

## Phase 11: Retrospective

**Phase 11 runs INLINE in the main conversation thread, not as an Agent dispatch.**

Invoke the `ship-retrospective` skill via the `Skill` tool. Pass the progress file path, project config path, and worktree path as arguments.

The retrospective is a *conversation* with the user about what to patch. Running it as a subagent loses the back-and-forth — the user sees a wall of proposed patches with no chance to redirect.

The skill:
1. Analyses the full build — progress file, **Phase Telemetry table**, review findings, fix cycles, Greptile feedback
2. Proposes **universal patches** (skill/agent improvements for all projects) and **project-specific patches** (config/CLAUDE.md updates for this project)
3. Presents patches one at a time, takes your Y/N/Edit per patch

**Telemetry-aware:** the retrospective should specifically read the Phase Telemetry table and call out the most expensive phase. *"Discovery took 24 minutes and emitted a 1,014-line brief — that's the cost ceiling."*

**Output:** Approved patches applied, committed to the branch before merge.

Update progress file. **Tell user:** "Retrospective complete. N patches proposed, M approved. Ready for merge."

---

## Phase 12: Human Merges

**NEVER auto-merge.** Ask the user to confirm merge.

On confirmation:
```bash
gh pr merge <pr-number> --squash --delete-branch
```

### Post-merge cleanup

```bash
# Update main
cd <repo-root>
git checkout main && git pull --ff-only

# Regenerate Prisma in main if schema changed (matters for the tsc-on-commit hook in other worktrees — KB b3845a30)
if git show HEAD --name-only | grep -q "prisma/schema.prisma"; then
  (cd apps/api && npx prisma generate)
fi
```

Then invoke the `worktree` skill via the `Skill` tool with arguments `cleanup <feature-slug>`. The skill kills any dev processes rooted in the worktree, removes the worktree, deletes the merged branch, and prunes stale metadata. It always confirms before destructive steps — do NOT pre-approve. See `.claude/skills/worktree/SKILL.md`.

**Tell user:** "Ship complete. PR #<number> merged. Worktree cleaned up."

---

## Crash Recovery

Resume with: `/ship docs/plans/YYYY-MM-DD-<feature>-progress.md`

The orchestrator reads the progress file, finds the first incomplete phase, and resumes from there.

---

## Context Discipline

The build pipeline reads a lot of files a lot of times. Some of those reads are load-bearing; many are habit. Apply the following discipline to keep token cost honest.

### Immutable for the duration of a build (read once, refer thereafter)

These artifacts do NOT change between phases. After their initial read, downstream agents should reference them by path, not re-Read full content:

- `docs/architecture/project-config.json` — only changes if the architect updates it during retrospective
- `CLAUDE.md` — only changes via explicit edits, not during a build
- `.claude/rules/*.md` — design system and copy style; immutable for a build
- `docs/gotchas/GOTCHAS.md` — synced weekly, not mid-build

### Mutable per phase (re-read at phase boundaries)

- The Feature Brief — grows during Phases 1 and 3, then frozen at the Phase 4 gate
- The Task Manifest — written at Phase 5, frozen thereafter

### Mutable per round (re-read at round start)

- `INDEX.md` files in touched domains
- Recent commits in the worktree
- Test output, tsc output

### Brief slicing for builders

The Foreman dispatches a builder per task. The builder does NOT need the full 1,000-line Feature Brief — it needs the brief slices relevant to its task. The Foreman's dispatch prompt should:

- Pass the path to the brief (so the builder can deep-read on demand)
- Inline-quote the specific user journey, design implication, or technical decision relevant to the builder's task
- Skip the WHO/WHY layers (the architect already collapsed those into Section 6/7 directives)

This is not a performance trick — it's a correctness one. A builder reading a 1,000-line brief loses signal in noise; a builder reading a 50-line slice acts on the right thing.

### Reviewer slicing

Quality, business, context-mapper, and UX reviewers each have a narrow concern. They should receive:

- The diff for the round (always)
- The brief slice for the round (the same one given to the builder)
- The reviewer-specific checklist from the agent definition

A reviewer that re-reads the full brief on every round adds Opus tokens to every round of every build. Compounds fast.

---

## Hard Rules

1. **Never skip phases.** Every phase must complete or be explicitly skipped by the user.
2. **Never commit to main.** All commits on the feature branch. Only merge touches main.
3. **Human gates are blocking.** Do not proceed past gates 2, 4, or 9 without explicit user approval.
4. **Delegate, don't do.** Use the right skill/agent for each phase — don't try to be all agents at once. **Exception:** Phases 1 (Discovery) and 11 (Retrospective) run as inline `Skill` invocations in the main thread, never as `Agent` dispatches. AskUserQuestion does not exist in subagents.
5. **Track everything.** Progress file updated after every phase transition. **Phase Telemetry table is mandatory** — model + wall-clock + output size + interaction count for every phase.
6. **E2E testing is NEVER optional.** Phase 8 must run with real browser automation. If Chrome is unavailable or dev servers won't start, STOP and run the boot-failure diagnostic — do not skip or defer to human review. Unit tests cannot replace browser verification. E2E has found real bugs in 100% of builds where it was initially skipped.
7. **No fake interactivity.** If a phase is documented as interactive (Discovery, Retrospective), and `AskUserQuestion` is unavailable in the current execution context, STOP and surface the issue. Do NOT silently fall back to a non-interactive "speculation" mode that fakes the appearance of an interview.
