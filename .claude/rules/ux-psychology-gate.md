# UX Psychology & CLEAR UI Gate

**MANDATORY before building, auditing, or designing user-facing experience:**

## UI component / page work
Before writing or editing `.tsx` files in `apps/web/src/` that render user-facing UI (components, pages, layouts):
→ Invoke **both** `/ux-psychology` (user-behaviour frameworks — BMAP, B.I.A.S., Journey, Ethics) and `/clear-ui` (screen-level craft — Copywriting, Layout, Emphasis, Accessibility, Reward). The two are complementary: `/ux-psychology` decides *what* to design, `/clear-ui` decides *how* to render it.

## Multi-screen flow / journey design
Before designing or modifying any multi-screen flow — admissions, medication rounds, shift handover, family-portal onboarding, enquiry-to-placement pipeline, care-plan authoring:
→ Invoke `/ux-psychology` and focus on the Journey section

## Ethics-sensitive features
Before building features that touch residents, medication, safeguarding, consent, end-of-life care, family access, or any vulnerable-user flow:
→ Invoke `/ux-psychology` and apply the Ethical Tests (Regret / Black Mirror / In-Real-Life)

## Discovery / user research
Before drafting survey questions, user interview scripts, or a Feature Brief's WHO/WHY section:
→ Invoke `/ux-discovery-questions`

## Why this matters
Herbert is an ERP used by 600 staff caring for vulnerable residents. A misframed screen adds cognitive load in a safety-critical context; a missed Peak-End moment wastes a delight opportunity; an overlooked ethical second-order effect can harm residents. Weak CLEAR craft (generic copy, flat emphasis, inaccessible targets) compounds all of the above. These skills are lightweight indexes (<150 lines) that load in under a second.

## When to skip
- Reading/exploring code (no writes)
- Pure backend work (services, migrations, API handlers with no UI surface)
- Editing docs, configs, or non-code files
- If you already invoked the relevant skill(s) earlier in this conversation
