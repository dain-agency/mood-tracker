---
name: ux-discovery-questions
description: >
  Discovery question pack — the three General Empathy Questions (Hope/Pain/Barrier)
  and the Specific Empathy Question pattern, used when drafting user interview
  scripts, surveys, or the WHO/WHY section of a Feature Brief. British English.
user-invocable: true
disable-model-invocation: false
---

# UX Discovery Questions

A compact reference for the discovery questions that produce the richest user insight. Used alongside `/ux-psychology` and `/ship-discovery`.

Source: `docs/ux/growth-design-course/02-behavior-mapping.md`

---

## General Empathy Questions (GEQs)

Ask all three for every feature-level discovery. Get at least 5 answers per question when possible (real customer interviews, support tickets, or colleagues who talk to customers daily).

1. 🌈 **Hope** — "If you had a magic wand and could instantly <do X>, how would that change your day?"
2. 💀 **Pain** — "What's your #1 challenge when it comes to <X>, and why is it so challenging?"
3. 🚧 **Barrier** — "Tell me about the last time you did <X>. How did it go? What was preventing you from <Y>?"

### Substitutions

| Placeholder | Example for Herbert |
|---|---|
| `<X>` | "admit a new resident", "complete a medication round", "hand over to the next shift", "find a care plan update" |
| `<Y>` | "finishing the task", "feeling confident it was correct", "getting home on time" |

### The story byline

Append to every free-text question:
> "Be super specific to help us understand. Tell us a story if possible to give us some context."

This can meaningfully lengthen responses and turn flat factual answers into emotional narratives — the raw material for 6P stories and journey maps.

---

## Specific Empathy Questions (SEQs)

Used *after* GEQs, when you've picked a key moment to improve. SEQs probe one screen or step:

- "Walk me through the last time you used <specific screen>. What was going through your head?"
- "What did you expect to happen next? What actually happened?"
- "If you had to describe this step to a colleague, what would you say?"

Run SEQs for both successful users *and* dropouts — the contrast surfaces Behaviour Blockers and Enablers.

---

## How this feeds downstream

| Output from these questions | Feeds into |
|---|---|
| Hopes | BMAP Motivation levers; Peak moments in journey |
| Pains | BMAP Motivation (avoidance); Pit moments; top friction points |
| Barriers | BMAP Ability levers (which of the 5 is scarcest); 6P story conflict panels |
| Emotional stories | 6P story sketches; journey map emotional arc |

---

## When to invoke

- Drafting a user interview script
- Writing a survey (Typeform, Google Forms)
- Filling the WHO/WHY sections of a Feature Brief
- Before a stakeholder workshop where you need vocabulary for user motivations
