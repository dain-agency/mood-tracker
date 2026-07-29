# Package Map — where does X live?

Load this before creating, moving, or extending ANY code. If this map doesn't answer your placement question, mark the task blocked and cite this rule — do not guess. Fleet-scale guessing is how duplication happens.

## The six packages, one sentence each

| Package | Identity |
|---|---|
| `@dain-os/toolchain` | Dev-time only: lint + TypeScript configs. Never ships to runtime. |
| `@dain-os/kernel` | Pure utilities with ZERO runtime dependencies: types, dates, validation, logging. If it imports anything, it doesn't belong here. |
| `@dain-os/platform` | Domain-neutral business machinery: db boundary, sign-in, permissions, audit, person records, record linking, obligations, workflow & approvals + SLA. |
| `@dain-os/services` | Server-side, no React, talks to the outside world or runs in the background: integrations, notifications, documents, AI, monitoring. |
| `@dain-os/ui` | The only React unit: design system, primitives, page archetypes, Engine view renderers. Never shares a manifest with a data layer. |
| `@dain-os/portal` | External users only — the one piece that is BOTH security-critical AND React. External identity never mixes with staff sign-in. |

## The decision tree

1. **Can it be expressed as configuration on the Engine** (a collection, view, automation, form)? → It is CONFIG, not code. Stop. Do not write a component or service for something a schema can say.
2. **Is it care/housing/client vocabulary** (e.g. "person we support", certificate types, form wording)? → Domain content: config or schema-pack data. NEVER Kernel or Platform mechanism. (Ledger: proactive-for-mechanism, earned-for-domain.)
3. **Is it dev-time tooling** (lint rule, TS config)? → Toolchain.
4. **Is it a pure utility with no dependencies**? → Kernel.
5. **Does it render** (React)? → UI — unless it exists for external users, then Portal.
6. **Does it talk to an external system, send through a channel, move files, call a model, or watch health**? → Services, in the matching folder. New provider = new adapter INSIDE the integrations shell, never a standalone pipeline.
7. **Is it domain-neutral business machinery** (identity, access, audit, people, deadlines, approvals, linking)? → Platform.
8. Still unsure → BLOCKED, cite this rule, state your best two options and a recommendation.

## The Engine (ruling: no seventh npm name — named folders + one contract)

The Engine spans packages by design:
- `platform/engine-collections` — schemas, records, RLS integration
- `platform/engine-automations` — trigger → condition → action runtime
- `ui/engine-views` — view renderers (table, board, timeline, calendar, quadrant, decision-tree)
- **The view-capability contract lives in `kernel/types`.** engine-views and engine-collections communicate ONLY through it.

The Engine is the single standing candidate for a seventh published name; that decision belongs to Dane + Jack, not to any build session.

## Semantic-owner registry (one owner of meaning per cross-cutting concept)

Concepts may be COMPOSED across packages; their data shape and semantics have exactly ONE owner. Consumers consume — they never redefine.

| Concept | Owner of shape & meaning | Everyone else |
|---|---|---|
| Acknowledgement (seen & actioned) | `platform/workflow` (record, SLA, escalation state) | Services delivers it; UI renders it |
| Notification delivery & channels | `services/notifications` | Platform requests; UI shows badges |
| External event envelopes (e.g. `medication.dose.missed`) | `services/integrations` (normalised envelope) | Engine config decides what happens next |
| Person (resident, staff, relative, GP) | `platform/master-data` | Everything references by id; no local person shapes |
| Document files & storage | `services/documents` | Platform `record-linking` owns the LINKS between records and documents |
| Obligation / deadline semantics | `platform/obligations` | Engine config may create them; UI renders countdowns |
| Audit event shape | `platform/audit` — append-only, one-way-door territory | Everything emits; nothing redefines |
| Session & identity (staff) | `platform/sign-in` | Portal owns EXTERNAL identity separately |

Adding a new cross-cutting concept? Name its owner in your recipe card BEFORE building (see `template-recipe-card`).

## Import boundaries (lint-enforced — violations fail CI, not review)

- `kernel` imports **nothing** (dev-deps from toolchain only)
- `toolchain` is dev-time only; nothing imports it at runtime
- `platform` may import `kernel`
- `services` may import `kernel` + platform **contracts** (types), never platform internals
- `ui` imports `kernel` types + the Engine view contract. **Never** services or platform runtime
- `portal` composes platform sign-in (external lifecycle) + ui; no direct services imports — go through platform/services contracts
- `ui/engine-views` ↔ `platform/engine-collections`: **only** via the kernel contract
- Vendor SDKs appear **only** inside `services/integrations/<adapter>`. An `import twilio` anywhere else is a build failure.

## Belongs here / doesn't (quick checks)

- A date formatter → kernel/dates. A "review due" badge → ui, reading platform/obligations.
- Retry logic for an API → services/integrations shell. A Camascope-specific field mapping → that adapter's folder.
- "Who can see room 14's residents" → platform/permissions. The lock icon → ui.
- A new view type → ui/engine-views + capability declaration. A new client's dashboard → Engine CONFIG, no code at all.
