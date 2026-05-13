---
name: clear-ui
description: >
  CLEAR UI review framework — auto-invoked before building or auditing user-facing
  screens. Synthesises the Growth.Design "Psychology of UI Design" course into a
  per-pillar checklist plus a 0-5 scorecard. Complements `/ux-psychology` (which
  focuses on user behaviour) by providing the screen-level craft toolkit.
user-invocable: true
disable-model-invocation: false
---

# CLEAR UI — Quick Reference

Source material lives in `docs/ux/clear-ui-course/`. Use this skill as an index: scan the relevant pillar for the task at hand, pull deeper content from the source note if needed.

## The 5 pillars
- **C — Copywriting** — tell people *why* to care, *what* to do, *what happens next*
- **L — Layout** — group, position, align so the screen is easy to understand
- **E — Emphasis** — make the one thing that matters unmissable
- **A — Accessibility** — design for different abilities + situations
- **R — Reward** — make boring interactions feel good

**Guiding principle — Aesthetic Usability Effect:** polished, coherent interfaces *feel* easier to use. Users forgive minor issues on beautiful screens. CLEAR aims for beautiful, not just functional.

---

## C — Copywriting
Copy answers: "Why should I care, right now?"

**4 tips** — What's in it for me? · Reassure · Use specific action words · Talk like a real person.
**3 mistakes** — Too long · Too generic · Unnecessary/duplicated.
**Copy Swap Test** — if a competitor could use the same words, it's too vague.

Source: `docs/ux/clear-ui-course/02-copywriting.md`

## L — Layout
Layout creates clarity without shouting. 6 Gestalt-based principles:

Similarity · Proximity · Simplicity · Alignment · Common Region · Continuity.

**Common mistakes** — Sloppy Spacing · Border Bloat · Content Cramming.

Source: `docs/ux/clear-ui-course/03-layout.md`

## E — Emphasis
Layout makes a screen understandable. Emphasis makes its *purpose* unmissable.

**6 Dials** — Size · Colour · Space · Placement · Visualisation · Motion.
**Foggy Glasses / Squint Test** — blur the screen; the most important element should still be obvious.
**Mistakes** — Wrong Dial · Weak Dial · Screaming Dial.
**Psychology** — Von Restorff (distinctive = remembered), Reactance (don't shout at users).

Source: `docs/ux/clear-ui-course/04-emphasis.md`

## A — Accessibility
Design for 3 realities: **Permanent** + **Temporary** + **Situational** limitations. Care workers are usually situationally limited.

**3 principles** — Visible without searching · Operable without precision · Actionable without guessing.
**Error prevention** — disable invalid states, always offer undo, confirm destructive actions.
**Common mistakes** — tiny targets, low contrast, actions that don't look clickable, missing hints, colour-only meaning, too many patterns, assumption of user knowledge.

Source: `docs/ux/clear-ui-course/05-accessibility.md`

## R — Reward
A reward is the *emotional outcome* of a screen. Based on Self-Determination Theory — three reward flavours (the Reward Trifecta):

- **Control** — "I'm in control and safe"
- **Competence** — "I'm improving, I did well"
- **Recognition** — "I'm seen, connected"

**30-Second Reward Test** — users silently ask: "Am I safe?" / "Did I do well?" / "Do others see this?" If none is answered, the screen feels emotionally flat.

**Mistakes** — Wrong Reward (mismatched emotion), Shy Reward (hidden payoff), Over-Reward (confetti on routine actions).

Source: `docs/ux/clear-ui-course/06-reward.md`

---

## The CLEAR Scorecard (0–5 per pillar)

Score each pillar 0–5 for the screen under review. The conversation matters more than the number.

```
CLEAR Scorecard: [screen name]
- Copywriting:   _/5  — [note]
- Layout:        _/5  — [note]
- Emphasis:      _/5  — [note]
- Accessibility: _/5  — [note]
- Reward:        _/5  — [note]

Weakest pillar: [name] — fix first.
Key question: "What would make [pillar] a 5?"
```

Use to **prioritise** (fix lowest pillars), **align** (compare reviewer scores), **iterate** (re-score after changes).

---

## Pre-build micro-tests

Before calling a user-facing change "done":

1. **Copy Swap Test** — strip logo/visuals, read copy aloud. Could a competitor use the same words? If yes, it's too vague.
2. **Foggy Glasses Test** — blur or squint. Does the one important element still stand out?
3. **30-Second Reward Test** — can the user silently answer "am I safe / did I do well / am I seen"?
4. **Worst conditions test** — could a tired, distracted, one-handed user still succeed?

---

## Herbert application map

| Screen / flow | Likely weakest pillar | Action |
|---|---|---|
| Dashboard (12 KPI cards) | Emphasis (Screaming Dial) | Calm baseline, 1-2 dials lead the current job |
| MAR chart | Accessibility (glove-on / low light) | Large targets, colour+icon+text status |
| Admission form | Copywriting (generic labels) + Reward (Shy) | Specific labels, summary reward on completion |
| Handover summary | Reward (Control/Competence) | "Sent to night team — they'll see your 3 flagged concerns first" |
| Care plan authoring | Layout (content cramming) | Progressive disclosure; one decision at a time |
| Family portal | Accessibility + Copywriting | Bigger than default, conversational tone |

---

## British English

Use British spelling throughout UI copy: colour, organisation, centre, behaviour, personalised, recognise, optimise. This is enforced by `core-rules.md`.

## Complementary skill

For user-behaviour frameworks (BMAP, B.I.A.S., Journey, Ethics), see `/ux-psychology`. The two skills are designed to be invoked together on UI work.
