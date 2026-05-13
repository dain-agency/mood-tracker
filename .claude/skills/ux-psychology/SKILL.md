---
name: ux-psychology
description: >
  UX psychology reference — auto-invoked before building or auditing user-facing UI,
  designing a multi-screen journey, or shipping ethics-sensitive features.
  Synthesises frameworks from the Growth.Design Product Psychology course into a
  Herbert-flavoured checklist. British English throughout.
user-invocable: true
disable-model-invocation: false
---

# UX Psychology — Quick Reference

Source material lives in `docs/ux/growth-design-course/`. Use this skill as an index: scan the relevant section for the task at hand, pull deeper content from the source note if needed.

## When this skill gets invoked

| Task | Section to read first |
|---|---|
| Building a new screen / component | B.I.A.S. + Psych Framework |
| Designing a multi-screen flow (admissions, med round, shift handover, onboarding) | Journey Map + Improve Tactics |
| Ethics-sensitive feature (residents, medication, safeguarding, consent) | Ethical Tests + Humane Principles |
| Running discovery / user interviews | Also invoke `/ux-discovery-questions` |
| Communicating a design decision in a PR or review | Communicate Decisions |

---

## 1 · BMAP — Behaviour = Motivation · Ability · Prompt

If the desired user behaviour isn't happening, one of the three is too low. Apply as a mental model, not a precise chart.

**Motivation** (3 levers): anticipation (hope / fear), sensation (pleasure / pain), belonging (acceptance / rejection).
**Ability** (5 levers — scarcest one determines total): time, money, physical capacity, mental capacity, practice.
**Prompt** (2 types): explicit (button, notification, timer) or implicit (place, person, emotion association).

**Ethical rule** — never impose behaviours. Align product with what the user already wants, then make Ability easy and Prompt timely.

Source: `docs/ux/growth-design-course/02-behavior-mapping.md`

---

## 2 · Psych Framework — Psych = M · A

Every interaction adds or subtracts Psych (Net Perceived Value = Motivation − Friction). Treat Psych as the user's "health bar" — if it drops too low, the flow dies.

- Motivating the user is as important as reducing friction.
- "Good friction" aligned with motivation (reassuring confirmations) is net positive.
- Values aren't precise; focus on insights, not numbers.

Source: `docs/ux/growth-design-course/03-psych-framework.md`

---

## 3 · B.I.A.S. — the System 1 design framework

Most decisions run on System 1 (fast, instinctive). Design for it, not for the deliberate System 2 reader.

### B — Block (what the brain filters out before reading)
Filters out: **High effort** (Hick's Law), **Unrelated** (selective attention), **Redundant** (banner blindness).
Captures attention: short-term memory (priming), belief-confirming signals, unexpectedness (pattern breaks / personalisation).

### I — Interpret (help users frame what they see)
Seven reframing principles:
1. Familiarity — reuse existing patterns
2. Cognitive Load — reduce noise around the critical info
3. Benefits — lead with what's in it for the user, not features
4. Anchoring — give a comparison reference point
5. Loss Aversion — highlight what happens if they don't act
6. Discoverability — make the key element stand out
7. Labor Illusion — show work happening behind the scenes

### A — Act (help users take action)
**Reduce friction:** remove options, create valid defaults, split steps, reveal features gradually (progressive disclosure).
**Nudge** (sparingly — overuse triggers Reactance): social proof, curiosity gap, scarcity.

### S — Store (make the interaction memorable)
In order of impact:
1. Clear feedback — show what just happened
2. Reassurance — confirm they're doing the right thing
3. Feeling of caring — users sense you have their interests at heart
4. Delighters — small humanity beats fancy animation

Every stored interaction shapes the next Block → Interpret → Act loop. Repeated positive loops become habits.

Source: `docs/ux/growth-design-course/04-bias-intro.md` through `09-bias-recap.md`

---

## 4 · Journeys — Peak / Pit / Jump / Drop / Transition

Boil a multi-screen flow down to its **5-6 key moments** (Miller's Law). Five element types:

- **Peak** — highest absolute psych
- **Pit** — lowest absolute psych
- **Jump** — psych increase
- **Drop** — psych decrease
- **Transition** — start/end of a milestone

### 4 improvement tactics (in order)
1. Mark the Transition (celebrate milestones)
2. Elevate the Peak
3. Fill the biggest Pit
4. Reorder steps

**Peak-End rule** — the brain remembers Peaks and endings, not averages. Don't play whack-a-mole with every small pit.
**Hyperbolic discounting** — deliver a preview of the reward earlier rather than making users wait.
**ROI of delight** — delighting good customers (NPS 5-8 → 9-10) can earn ~9× more than improving average ones.

Source: `docs/ux/growth-design-course/10-journey-map.md`, `11-journey-improve.md`

---

## 5 · Ethical Tests — for sensitive features

Required for features affecting residents, medication, safeguarding, consent, or any vulnerable-user flow.

- **Regret Test** — if the user knew everything the team knows, would they behave differently? If yes, reconsider.
- **Black Mirror Test** — if everyone used it all the time, does it end well? Think through second- and third-order effects.
- **In-Real-Life Test** — if the screen were a person, what would they be like? Someone you'd want to know?

### Manipulation Matrix (Nir Eyal)
Two axes — "improves user's life?" × "maker uses it?". Aim for **Facilitator** (yes / yes). Avoid Peddler, Entertainer, Dealer.

### Humane Principles
Products should: save time (not waste it), value attention (not interrupt), reflect human values (not shareholder interests).

Source: `docs/ux/growth-design-course/13-ethics.md`

---

## 6 · Communicating decisions

When defending a design in a PR or review:

1. Lead with a story (rallies people around the user)
2. Use psychology vocabulary (benefits, friction, nudge, framing, block)
3. Create feedback guardrails — ask specifically what you want feedback on
4. Answer feedback in 3 steps: **yes → repeat & empathise → reassure**

Apply B.I.A.S. to your own message: is it blocked / misinterpreted / actionable / storable?

Source: `docs/ux/growth-design-course/12-communicate-decisions.md`

---

## Herbert-specific application map

| Herbert flow | Frameworks that apply |
|---|---|
| Enquiry → admission pipeline | Journey (Peak-End at admission), 6P story for discovery |
| Medication round | B.I.A.S. Act (remove options, split steps) + Regret Test (errors are life-critical) |
| Shift handover | Store (clear feedback, reassurance) + Labor Illusion (show prior shift's work) |
| Family portal onboarding | 6P story; families are non-technical + emotionally invested |
| Care plan authoring | Interpret (cognitive load, progressive disclosure) |
| CQC compliance dashboard | Anchoring (benchmarks) + Discoverability (what needs action) |

---

## British English

Use British spelling throughout UI copy: colour, organisation, centre, behaviour, personalised, recognise, optimise. This is enforced by `core-rules.md`; the psychology frameworks don't change that.
