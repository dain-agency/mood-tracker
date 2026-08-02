# Accessibility Rule — accessible by default, adaptive by data

Accessibility is architecture, not decoration. These requirements originated with Millennium (agreed with Tommy Collins, 31 Jul 2026; HUB-011 names WCAG 2.2 AA explicitly) but apply platform-wide: every tenant inherits them because they live in shared packages, not client code.

## 1 · The standard

- **WCAG 2.2 Level AA is the hard floor** for every surface, every tenant. Name the version — 2.2 adds directly relevant AA criteria (focus not obscured by sticky headers; no sign-in relying on memory alone).
- **Named AAA criteria are adopted into the design system** because they carry the readability payload (dyslexia support especially): line spacing ≥ 1.5 · line length ≤ 80 characters · text never justified · reader-selectable text/background colours · plain-English content · enhanced-contrast option. BDA-informed defaults: clean sans-serif, left-aligned, off-white (not stark white) background option.
- Already standard in the design system and non-negotiable in new work: text-size control on every page (4 steps, 14–20px, layouts reflow), contrast-tuned light + dark with **measured ratios published per pairing**, OS reduced-motion respected throughout.

## 2 · Colour is never the sole signal

- Every status carries a label or icon as well as a colour.
- **Charts differ by more than hue**: line styles, markers, direct labels — never a legend keyed only by colour. Known palette collisions to design out: teal↔purple under deuteranopia; pink↔deep-teal under protanopia.
- CI gate: palettes and chart configurations pass simulation for protanopia, deuteranopia and tritanopia.

## 3 · The four architectural commitments (expensive to reverse — everything else waits for co-production)

1. **Presentation is driven by data, not by a separate build.** How a person needs information presented is a property of the person, not of a screen. Adding a new need later = data change, not code change.
2. **Every piece of content can carry alternatives** — plain-English, easy-read, symbol/photograph, audio. The slots exist from day one even if unpopulated; Engine collections support alternative-content variants natively and views select the variant per viewer profile.
3. **Nothing a person might need changed is written into code** — wording, reading level, symbol sets, colour, text size, density. No hardcoded user-facing strings anywhere: all copy resolves through the message catalogue (mechanism in ui; content as data).
4. **One identity model covers everyone.** A person we support, a family member and a social worker are all people with accounts, permissions and accessibility needs. One platform that genuinely adapts — for some people that is a symbol-led, one-question-per-screen, audio-first surface sharing almost nothing visually with a professional's view. Same platform, same permissions, same record.

## 4 · The communication passport (semantic owner: platform/master-data)

The passport is **structured data on the person record**, not a document. One record, two jobs: it tells a new support worker how someone communicates AND configures how the platform renders for that person (large symbols + audio + no free text, etc.). Per-person presentation profiles resolve through the config layer stack at person/user scope (see rule-config-framework §4). Never duplicate accessibility preferences per-surface — everything reads the passport.

**Personal vocabulary (licence-free Makaton alternative):** a person's own record holds their own vocabulary — their photographs, their symbols, short videos of their own signs — which the platform uses to render content for them. No commercial symbol licence required; a shared library can be offered for people to choose from.

## 5 · Translation-readiness (build now, ship English-only)

Four tiers, combinable:
1. **Interface translation-ready from day one** — no wording baked into code (falls out of commitment 3). Ship English-only; the option stays open.
2. **On-demand translation of user content** (messages, news) via Azure AI Translator adapter — UK region, does not store submitted text (matters for care data).
3. **Human translation for safety-critical content** — medication, safeguarding, tenancy: never machine-only; AI pass + human verification at minimum.
4. **BSL & captions** — captions toggleable on all video/audio; signed-overlay via specialist provider if required.

## 6 · Assisted use is a first-class design goal

For many people we support, **the interface is a person, not a screen**: a support worker and an individual going through something together on a tablet. This is a distinct design goal from independent self-service and carries its own testing criteria (both parties get value; large targets; choose-between-options over typing; audio on prompts; photographs of real people/places over generic icons).

## 7 · Verification (goes in every recipe card's §5A)

- Automated WCAG 2.2 AA scan clean on every touched surface, in CI from provision time.
- **Automated tools catch ~20–50% of issues — a clean scan is necessary, never sufficient.** Person-facing surfaces must name their human verification (including assisted-use testing where relevant).
- Every design-system component ships with a11y conformance fixtures — fix once in the shared component, inherit everywhere (the 12/18-pages-clean scan pattern: issues cluster in one repeated component).
- Where UI joins other packages, seam suites include keyboard navigation, visible focus, and screen-reader announcement checks.
- platform/sign-in: every role's auth config must include at least one method that does not rely on memory alone (WCAG 2.2 accessible-authentication) — enforced as a manifest bound.
- Publish an accessibility statement per tenant once standards are agreed.

## 8 · Sequencing rule

The four commitments are Wave-0/foundational and ship with the platform. Specialised person-centred requirements are **earned through co-production** (e.g. Millennium's Inclusion Group) — they arrive as passport data, content alternatives and surface configuration, never as redevelopment. Co-production must be timed to land before person-facing surfaces are designed.
