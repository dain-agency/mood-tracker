# /autopilot — autonomous run mode, optimised for PR throughput

Runs unattended toward a **PR-merge** goal until one of three things is true: the goal is hit, you hit a real blocker, or the deadline passes. Replaces ad-hoc `/loop` setups for any session where the user steps away expecting throughput.

This skill exists because hourly-cron-driven and "safe-checkpoint, stop" patterns produce zero-PR nights. The mental model here is the autopilot of an aircraft: you set the destination, you trust the rules, you don't re-decide the route every minute.

## Usage

```
/autopilot                                # PRDs/README.md dependency order, no deadline
/autopilot 031 030 025                    # explicit ordered PRD list
/autopilot --until 07:00                  # deadline (UTC)
/autopilot --target-prs 4                 # explicit PR target
/autopilot --resume                       # pick up an in-flight branch
/autopilot --mode overnight               # sets sensible overnight defaults (deadline 07:00, summary file)
/autopilot --mode meeting --until 11:00   # short window while user is in a meeting
```

If the user typed `/overnight`, `/autorun`, `/unattended`, or any synonym, treat it as `/autopilot --mode overnight`.

## The contract — re-read every turn

**Progress is measured in PRs merged, not commits pushed.** A turn that ends with a clean local commit but no open PR is a wasted turn.

Acceptable stop conditions, in priority order:

1. **Target PRs/PRDs all merged.** Done.
2. **Hard blocker that cannot be resolved autonomously.** Examples: Greptile stuck below 5/5 after 3 fix rounds; a credential not in the project's testing-creds; an external service (Vercel deploy, Supabase apply, GitHub Actions) not responding. **Document the blocker in the run summary.**
3. **Deadline reached.** Stop, write the summary. The summary is an *apology* if the goal wasn't hit, not a satisfied report.

**Not acceptable as a stop condition:**

- "I have a clean checkpoint."
- "This would make a good handover note."
- "The next phase is risky."
- "PRD compliance requires a script I haven't written yet."
- "It's late, the next phase is long."
- "The hourly cron will pick this up."

If you find yourself reaching for any of those, **reverse and continue.**

## Cadence — never wait for an hourly cron

When `/autopilot` is invoked, **this is the build chain.** Do not lean on a `CronCreate` hourly backup — the 1-hour gaps fragment work into shallow turns.

Use `ScheduleWakeup` yourself with sub-hour delays:

| Situation | `delaySeconds` |
|---|---|
| Active coding (writing code, applying migrations, running scripts) | **Don't `ScheduleWakeup`. Stay in the same turn.** |
| Pushed commits, CI starting | 270s (cache-warm) |
| Greptile review triggered, waiting for verdict | 270s |
| Long apt/npm install or build job | 270s |
| Idle wait on external (deploy, provision) | 1200-1800s (one cache miss buys a long wait) |
| **Never use 300s** | (worst-of-both: cache miss without amortisation) |

**Stay in one turn for active coding.** Splitting six SQL migration files across three hourly fires is the canonical anti-pattern this skill exists to prevent.

## Per-turn operational rules

1. **First action: state check.** One Bash call.
2. **Choose the minimal next action that progresses a PR.** Not the next safe checkpoint.
3. **PRD compliance is for the PR description, not the build pace.**
4. **Don't write markdown handover notes mid-build.**
5. **Trust memory rules.**
6. **Open the PR early.** A draft PR with one commit is better than five commits and no PR.

## Greptile gate

While waiting for review (typically 3-8 min), `ScheduleWakeup` at 270s. Do not poll.

- **5/5 + 0 P0/P1 → merge**, then `/wrapup`, then move to the next PRD.
- **<5/5 or P0/P1 present → fix round.** Up to **three rounds** total.
- **After round 3 still <5/5 → flag for human** in the run summary.

## Run summary

Write `docs/plans/<date>-autopilot-summary.md`. If zero PRs merged, the TL;DR says zero. **Don't bury the lede.**

## Anti-patterns this skill exists to prevent

- Hourly fragmentation
- Handover-note comfort blanket
- PRD deferral
- Deadline deceleration
- Checkpoint optimisation
- Late-PR (no PR open with multiple commits on branch)
- "Backup mode" paralysis

## Modes

- `--mode overnight` — deadline ~07:00 local, summary tone is "what could have shipped but didn't" if goal wasn't hit
- `--mode meeting` — short window (1-2 hours), single in-flight PR expected
- `--mode focused` (default) — no deadline; runs until target met or hard blocker

The deadline is the *latest* acceptable stop, not the goal. Aim to be done before it.
