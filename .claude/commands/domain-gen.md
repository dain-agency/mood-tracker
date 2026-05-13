---
description: Generate a Feature Brief and Task Manifest from a domain-spec.yaml
argument-hint: <domain-name> [--brief-only] [--dry-run] [--ship]
---

# Domain Generator: $ARGUMENTS

You are a Domain Generator. You read a domain specification YAML and produce two artefacts: a Feature Brief (sections 1-7) and a Task Manifest (JSON). You do NOT write application code.

---

## Phase 1: Parse Arguments

Extract from `$ARGUMENTS`:
- **domain-name** (required) — kebab-case domain identifier (e.g. `crm`, `residents`, `workforce`)
- **--brief-only** (optional flag) — generate Feature Brief only, skip Task Manifest
- **--dry-run** (optional flag) — show what would be generated without writing any files
- **--ship** (optional flag) — after generating, invoke `/ship` with the brief path

If no domain name is provided, stop and ask for one.

---

## Phase 2: Load & Validate

### Read the domain spec
```
apps/web/src/domains/{domain-name}/domain-spec.yaml
```

If the file exists, skip to **Phase 2b: Read Context & Validate** below.

If the file does NOT exist, enter **Phase 2a: Interactive Spec Builder**.

---

### Phase 2a: Interactive Spec Builder

Build the domain spec interactively using AskUserQuestion. This is a multi-round discovery process — gather enough context to write a complete `domain-spec.yaml`, then proceed to Phase 3.

#### Pre-load context
Before asking questions, silently read:
1. `project-config-index.md` — entity definitions, persona profiles, schema list
2. `docs/templates/domain-spec-schema.yaml` — field reference
3. `docs/templates/domain-spec-example.yaml` — worked CRM example
4. Check if screenshots or migration docs exist for this domain:
   - `docs/migrations/screenshots/` — look for files matching the domain name
   - `docs/prds/` — look for PRDs mentioning this domain
   If screenshots exist, read them for UI context before asking questions.

#### Round 1: Domain Identity (1 AskUserQuestion call, up to 4 questions)

Ask these together in a single AskUserQuestion:

1. **"What does this domain do?"** — Free text describing the domain's purpose. Use this for the `description` and `label` fields. Header: "Purpose"
   - Options: provide 2-3 inferred descriptions based on the domain name + project-config entity definitions. Always include an "Other" option (automatic).

2. **"Which personas use this domain?"** — multiSelect from the project-config persona list. Header: "Personas"
   - Options: list the 4 most likely personas based on the domain name. The user can select multiple.

3. **"Which nav group should this appear under?"** — Header: "Nav group"
   - Options: "Core Business", "Clinical & Care", "Workforce", "Supporting", "Intelligence"

4. **"What icon best represents this domain?"** — Header: "Nav icon"
   - Options: suggest 3-4 Lucide icon names that match the domain purpose.

#### Round 2: Pages & Archetypes (1 AskUserQuestion call, up to 4 questions)

Based on the domain's entities (from project-config-index.md), infer the likely pages and ask:

1. **"Which page types does this domain need?"** — multiSelect. Header: "Pages"
   - Options: infer from entity structure. For example, if the domain has a main entity → entity-list + entity-detail. If it has stages/statuses → suggest kanban. If it has metrics → suggest dashboard.
   - Use previews showing a 2-3 line description of what each archetype provides.

2. **"How should the detail page be structured?"** — Only ask if entity-detail was selected. Header: "Detail tabs"
   - Options based on common patterns: suggest 3-4 tab configurations based on the domain's related entities and the Mabel screenshots (if available).

3. **"Should new records be created via a dialog wizard or full-page form?"** — Only ask if multi-step-form was selected. Header: "Form style"
   - Options: "Dialog wizard (Recommended)", "Full page form", "Both options"

4. **"Should the list page include a kanban view toggle?"** — Only ask if both entity-list and kanban were selected. Header: "View toggle"
   - Options: "Same route with toggle (Recommended)", "Separate /pipeline route"

#### Round 3: Detail Page Deep-Dive (1 AskUserQuestion call, up to 4 questions)

Only ask this round if entity-detail was selected. Tailor questions based on the domain's related entities:

1. **"Which tabs should the detail page have?"** — multiSelect. Header: "Tabs"
   - Options: infer from related entities. E.g., for CRM: Activity, Details, Contacts, Documents, Notes, Tasks. For Residents: Overview, Care Plans, Medication, Documents, Activity.

2. **"Should the detail page have a persistent sidebar?"** — Header: "Sidebar"
   - Options: "Yes — summary card always visible on right", "No — full-width content only"

3. **"What badges/info chips should appear below the title?"** — multiSelect. Header: "Badges"
   - Options: infer from the entity's key fields (status, type, priority, location, etc.)

4. **"What actions should appear in the detail page header?"** — multiSelect. Header: "Actions"
   - Options: Edit, Export, Delete/Archive, Print, domain-specific actions (e.g. "Make Resident" for CRM)

#### Round 4: Refinement (optional — 1 AskUserQuestion call)

Show a summary of what will be generated and ask:

1. **"Anything to add or change before I write the spec?"** — Header: "Review"
   - Options: "Looks good, generate it", "I have changes (describe below)", "Show me the full spec first"

#### Write the spec

After all rounds, write the complete `domain-spec.yaml` to:
```
apps/web/src/domains/{domain-name}/domain-spec.yaml
```

Create the domain directory if it doesn't exist. Then continue to Phase 2b.

---

### Phase 2b: Read Context & Validate

### Read project context
1. `project-config-index.md` — persona profiles, entity definitions, decisions
2. `packages/types/src/supabase.ts` — entity field types for the spec's `schema` and `entity` values
3. `CODEBASE_MAP.md` — existing domain structure and what already exists
4. The domain's `INDEX.md` if it exists (`apps/web/src/domains/{domain-name}/INDEX.md`)

### Validate required fields
Confirm these exist in the spec:
- `domain`, `label`, `schema`, `nav_group`, `nav_icon`, `personas`
- Every page has `name`, `archetype`, `route`, `entity`
- Every archetype has its required fields (see schema reference below)

**Required fields per archetype:**
| Archetype | Required Fields |
|---|---|
| entity-list | table_preset, columns |
| entity-detail | tabs (each with label + sections or component) |
| multi-step-form | steps (each with label + fields) |
| dashboard | at least one of: stats, charts, summary_table |
| kanban | stages, card_fields |
| calendar | event_entity, views |
| settings-config | sections (each with label + fields or toggles) |
| timeline-log | log_entity, detail_fields |

If validation fails, list all issues and stop. Do not generate partial output.

---

### Phase 2c: Backend Readiness Check

Before generating the Feature Brief, audit whether the backend architecture needed by this domain is in place. Check each layer and report status.

#### Layer 1: Database (Supabase)
Check `packages/types/src/supabase.ts` for the domain's schema and tables:
- Are the entity tables defined in the generated types? (e.g. `crm.enquiries`)
- Are lookup tables present? (e.g. `crm.enquiry_stages`, `crm.enquiry_sources`)
- If types are missing, the schema DDL hasn't been applied yet.

**Status:** `ready` | `partial` | `missing`

#### Layer 2: Validators (`@herbert/validators`)
Check `packages/validators/src/` for Zod schemas matching each entity:
- Create schema (e.g. `createEnquirySchema`)
- Update schema (e.g. `updateEnquirySchema`)
- Search/filter schema if the spec has filters

**Status:** `ready` | `partial` | `missing`

#### Layer 3: Query Functions (`@herbert/queries`)
Check `packages/queries/src/` (or wherever query functions live) for:
- CRUD functions per entity (e.g. `createEnquiry`, `getEnquiry`, `listEnquiries`, `updateEnquiry`, `deleteEnquiry`)
- Aggregation queries if dashboard archetype is used (e.g. `getEnquiryStats`)
- Stage/status transition functions if kanban/pipeline is used

**Status:** `ready` | `partial` | `missing`

#### Layer 4: Server Actions
Check `apps/web/src/domains/{domain-name}/actions/` for:
- Action wrappers using `executeAction` / `executeQuery` from `@/lib/actions/action-helper`
- One action per mutation (create, update, delete)
- Read actions for server-side data fetching

**Status:** `ready` | `partial` | `missing`

#### Layer 5: API Routes (if REST API needed)
Check `apps/api/src/domains/{domain-name}/` for:
- Route definitions
- Controllers
- Service layer

**Status:** `ready` | `partial` | `missing` | `not-needed` (web-only domains use server actions)

#### Report & Decision

Print a backend readiness summary:

```
Backend Readiness: {domain-name}
─────────────────────────────────
Shared infra:      {status} {detail — action-helper, tenant client, query types}
Database types:    {status} {detail}
Validators:        {status} {detail}
Query functions:   {status} {detail}
Server actions:    {status} {detail}
API routes:        {status} {detail}
```

**Shared infrastructure vs domain-specific gaps:**

The backend readiness check distinguishes two types of gaps:

1. **Shared infrastructure** (action-helper.ts, tenant.ts, @herbert/queries types, @herbert/validators package structure) — these are cross-cutting and managed by the backend session. If shared infra is missing, **STOP and tell the user** — domain-gen cannot proceed without it.

2. **Domain-specific gaps** (CRM validators, CRM query functions, CRM server actions) — these are specific to this domain and **domain-gen writes them directly** as part of generation. They are NOT deferred to another session.

**If shared infra is ready but domain-specific layers are `partial` or `missing`:**
1. List exactly what's missing
2. **Write the missing domain-specific code directly** in a new **Phase 2d: Fill Backend Gaps**
3. Then proceed to Phase 3

**If shared infra is NOT ready:**
1. List what shared infrastructure is missing
2. Stop and tell the user: "Shared backend infrastructure is not ready. The backend session needs to complete: [list]. Run `/domain-gen {domain-name}` again after those are in place."

---

### Phase 2d: Fill Domain-Specific Backend Gaps

Only runs if Phase 2c found domain-specific gaps with shared infra ready.

For each missing layer, **write the code directly** following existing patterns:

#### Validators (if missing)
Write to `packages/validators/src/{domain}/`:
- Read existing validators in the package to match the pattern
- `create{Entity}Schema` — fields from the domain spec's form steps
- `update{Entity}Schema` — partial version
- `search{Entity}Schema` — if the spec defines filters
- Export from the package barrel file

#### Query Functions (if missing)
Write to `packages/queries/src/{domain}/`:
- Read existing query modules (e.g. `packages/queries/src/residents/`) to match the pattern
- CRUD: `create{Entity}`, `get{Entity}`, `list{Entities}`, `update{Entity}`, `delete{Entity}`
- Use `TypedClient` from `@herbert/queries`
- Aggregations: `get{Entity}Stats` (if dashboard archetype used)
- Stage transitions: `update{Entity}Stage` (if kanban/pipeline used)
- Lookup queries: one function per lookup table (if entity has FK lookups)
- Export from the package barrel file

#### Server Actions (if missing)
Write to `apps/web/src/domains/{domain-name}/actions/`:
- Follow the `executeAction` / `executeQuery` pattern from `@/lib/actions/action-helper`
- One action per mutation (create, update, delete, stage-change)
- Read actions for server-side data fetching (list, get, stats)
- Import validators from `@herbert/validators`
- Import query functions from `@herbert/queries`

After writing, run `npx tsc --noEmit` from `apps/web` to verify the wiring compiles. Fix any type errors before proceeding.

Then continue to Phase 3.

---

## Phase 3: Generate Feature Brief

Write to: `docs/plans/domains/{domain-name}-brief.md`

Use the Feature Brief template from `.claude/templates/feature-brief.md` as the structural base. Fill every section using the domain spec data.

### Section 1: WHO — The People

Map each persona ID from the spec's `personas` array to their full profile in project-config:
- **Name & Role** — persona's display name and job title
- **Tech comfort** — from persona profile
- **Device** — from persona profile (desktop, tablet, mobile)
- **Time pressure** — from persona profile
- **What they care about** — infer from persona goals + domain purpose
- **What frustrates them** — infer from current state (no UI exists yet)

Group personas by usage pattern:
- **Primary users** — personas who use this domain daily (care-manager, admin-officer typically)
- **Secondary users** — personas who use it periodically (ops-director, deputy-manager typically)

Generate Success Criteria as human-verifiable checkboxes:
- One per page, phrased as "[Persona] can [action] in [time budget]"

Generate Anti-Goals:
- "Not building [adjacent domain] UI"
- "Not implementing [future feature from spec description]"
- Any scope boundaries evident from the spec

### Section 2: WHY — The Motivation

- **The Underlying Need:** Derive from `description` field. Why does this domain exist in a care home ERP?
- **What Happens Today:** This domain has no UI yet. Describe the manual/paper-based process it replaces.
- **What Failure Costs:** What goes wrong if this feature is bad? Think: compliance risk, data loss, missed enquiries, staff frustration.
- **What Success Enables:** Positive outcomes — efficiency gains, better care, compliance confidence, management visibility.

### Sections 3-4: WHERE & WHEN

For each page, infer device context and timing from its archetype:
- Desktop archetypes (list, detail, dashboard, kanban, log): seated, focused, high attention, 2-15 min
- Tablet/mobile archetypes (form, calendar): seated or standing, medium attention, 5-15 min
- Settings: desktop, admin quiet time, 10-30 min

Generate Digital Context per page: entry point, previous screen, expected location, exit point.

### Section 5: User Journeys

Generate 2-3 per page. Format: `> Who / When / Where` narrative, numbered steps, design implications.
Journey patterns by archetype: list=search/triage, detail=review/update, form=capture mid-conversation, dashboard=morning review, kanban=drag-to-update, calendar=plan/reschedule, settings=configure, log=investigate.

### Section 6: HOW — Technical Strategy

#### Archetype Reference (MANDATORY)

For EVERY page in the domain, include a reference to the archetype story that the UI builder MUST read before implementing. This is the single most important section for ensuring consistent UI patterns.

```markdown
#### Archetype Stories to Follow

| Page | Archetype | Story File | Key Patterns |
|---|---|---|---|
| {Entity} List | entity-list | `components/layout/archetypes/entity-list.stories.tsx` | MasterTable + preset, view toggle, bulk actions |
| {Entity} Detail | entity-detail | `components/layout/archetypes/entity-detail.stories.tsx` | Page wrapper, badges, quick actions, tabbed content |
| New {Entity} | multi-step-form | `components/layout/archetypes/multi-step-form.stories.tsx` | Dialog + StepIndicator + AnimatedProgress |
| {Domain} Dashboard | domain-dashboard | `components/layout/archetypes/domain-dashboard.stories.tsx` | KPIMetricCard, Quick Actions, Workflows |
```

**Every page MUST use these patterns from its archetype:**
1. `<Page>` wrapper with `title`, `breadcrumbs`, `actions` — no custom `<h2>` headers
2. `KPIMetricCard` from `components/composed/kpi-metric-card.tsx` — never custom stat cards
3. `AnimatedProgress` + `StepIndicator` for multi-step forms — not StepIndicator alone

**Nested Organism Presets (MANDATORY)**

For EVERY tab or section that contains an organism, specify the exact preset and wrapper. The UI builder cannot infer these — they must be in the brief.

```markdown
#### Nested Organism Specifications

| Page | Section/Tab | Organism | Preset | Wrapper |
|---|---|---|---|---|
| Detail | Activity tab | TimelineView | `PRESET_AUDIT_LOG` | `Card > CardHeader + CardContent > TooltipProvider` |
| Detail | Documents tab | MasterTable | `PRESET_SETTINGS` | none |
| Detail | Care Plans tab | MasterTable | `PRESET_ENTITY_LIST` | none |
| List | Main table | MasterTable | `PRESET_ENTITY_LIST` | none |
| Dashboard | Stats | KPIMetricCard | n/a | grid layout |
```

Available timeline presets: `PRESET_AUDIT_LOG` (search+filter+diffs), `PRESET_ENTITY_HISTORY` (change tracking), `PRESET_PROCESS_TIMELINE` (workflow stages), `PRESET_CLINICAL_HISTORY` (care records), `PRESET_COMPACT_FEED` (sidebar widget).

Available table presets: `PRESET_ENTITY_LIST`, `PRESET_MOBILE_LOOKUP`, `PRESET_SETTINGS`, `PRESET_DASHBOARD_SUMMARY`, `PRESET_LOG_VIEWER`, `PRESET_FINANCIAL`, `PRESET_LIVE_STATUS`.
4. Badges section below title on detail pages
5. Quick Actions section on domain dashboards
6. `DropdownMenu` for row actions (not inline button rows)
7. `renderRowActions` returns ReactNode (JSX), not action config arrays

#### Existing Patterns to Reuse
Based on archetypes used, list:
- `MasterTable` + `useTable` + specified preset (for entity-list)
- `FormField` + `useFormConfig` (for multi-step-form)
- `Page` layout component (all pages)
- `EmptyState`, `ErrorState`, `LoadingState` (all pages)
- `ConfirmDialog` (for destructive actions)
- Specific `@herbert/ui` animation primitives (for dashboard stats)
- `KPIMetricCard` + `CountingNumber` (for dashboard KPIs)

#### Domain Dependencies
From the spec's `depends_on` field, list:
- Import paths and what is imported
- Data relationships between domains

#### API Endpoints Needed
Generate endpoint list from pages:
- entity-list → `GET /api/{entity}` (list with filters)
- entity-detail → `GET /api/{entity}/{id}` (single record)
- multi-step-form → `POST /api/{entity}` (create), `PUT /api/{entity}/{id}` (update)
- kanban → `PATCH /api/{entity}/{id}/stage` (status update)
- dashboard → `GET /api/{entity}/stats` (aggregations)

#### Security Considerations
- RLS policies needed per entity
- Permission checks from the spec's permissions matrix

### Section 7: WHAT — Implementation Spec

#### Data Model
For each entity referenced in the spec, look up field definitions from `packages/types/src/supabase.ts`. List fields, types, nullability, and foreign keys.

#### API Surface
Full endpoint table with Method, Route, Purpose, Request body, Response type.

#### Components
List every component that will be generated, grouped by page:

Use this archetype-to-component mapping. **Every component entry MUST include the archetype story reference** so the UI builder knows which pattern to follow:

| Archetype | Primary Component | Hook | Supporting Components | Archetype Story |
|---|---|---|---|---|
| entity-list | {Entity}List | use{Entities} | column definitions file | `entity-list.stories.tsx` |
| entity-detail | {Entity}Detail | use{Entity} | {Entity}Summary, tab components, sidebar | `entity-detail.stories.tsx` |
| multi-step-form | {Entity}Form | use{Entity}Form | step components per step | `multi-step-form.stories.tsx` |
| dashboard | {Domain}Dashboard | use{Domain}Stats | KPIMetricCard, Quick Actions, charts | `domain-dashboard.stories.tsx` |
| kanban | {Entity}Board | use{Entity}Pipeline | {Entity}Card | `kanban-board.stories.tsx` |
| calendar | {Domain}Calendar | use{Domain}Events | event dialog component | `calendar-view.stories.tsx` |
| settings-config | {Domain}Settings | use{Domain}Settings | section components | `settings-config.stories.tsx` |
| timeline-log | {Entity}Log | use{Entity}Log | detail drawer component | `timeline-log.stories.tsx` |

For each component listed, include a note: `// Follow archetype: apps/web/src/components/layout/archetypes/{story-file}`

#### Page Routes
List all `app/(app)/` route files that will be created.

#### File Inventory
Full list of every file that will be created, with path relative to `apps/web/src/`.

---

## Phase 4: Generate Task Manifest

Skip this phase if `--brief-only` flag was provided.

Write to: `docs/plans/domains/{domain-name}-tasks.json`

### Structure

```json
{
  "featureBrief": "docs/plans/domains/{domain-name}-brief.md",
  "domainSpec": "apps/web/src/domains/{domain-name}/domain-spec.yaml",
  "branch": "feat/{domain-name}-domain",
  "rounds": [
    {
      "round": 0,
      "name": "Scaffold",
      "reviewFocus": ["Domain directory exists", "INDEX.md created", "All stub files have anchors"]
    },
    {
      "round": 1,
      "name": "Hooks & Services",
      "reviewFocus": ["All hooks return correct types", "API client methods match endpoint spec", "tsc --noEmit passes"]
    },
    {
      "round": 2,
      "name": "Components",
      "reviewFocus": ["Components render without errors", "Props match hook return types", "Design system components used (no raw HTML)"]
    },
    {
      "round": 3,
      "name": "Pages",
      "reviewFocus": ["Routes resolve correctly", "Pages compose domain components", "Page layout component used", "Permissions enforced"]
    },
    {
      "round": 4,
      "name": "Tests & Stories",
      "reviewFocus": ["All source files have test files", "Tests cover loading/error/success states", "Stories cover all variants", "vitest run passes"]
    }
  ],
  "tasks": []
}
```

### Task Generation Rules

**Round -1 — Backend Wiring** (handled by Phase 2d during generation)

This round is NOT added to the task manifest — domain-gen writes the code directly in Phase 2d before generating the frontend tasks. The manifest only contains Rounds 0-4.

If Phase 2d wrote backend code, note it in the Phase 5 summary so the user knows what was created.

**Round 0 — Scaffold** (agent: `ship-scaffolder`)
- One task: create domain directory, stub all files with `<!-- @anchor -->` comments, create INDEX.md from `.claude/templates/domain-index.md`
- Size: M
- Inputs: domain spec, domain-index template
- Outputs: all stub files, INDEX.md

**Round 1 — Hooks & Services** (agent: `ship-ui-builder`)
- One task per entity for API client methods
- One task per hook (use the archetype-to-hook mapping)
- One task for shared types file
- Size: S or M depending on complexity

**Round 2 — Components** (agent: `ship-ui-builder`)
- One task per primary component (from archetype mapping)
- One task per set of supporting components (group related ones)
- Size: S for simple, M for complex (multi-step form, kanban board)
- Every component task must include parent wiring in outputs

**Round 3 — Pages** (agent: `ship-ui-builder`)
- One task per route file
- Each page task depends on its component task(s) from Round 2
- Size: S (pages are thin wrappers)

**Round 4 — Tests & Stories** (agent: `ship-test-builder`)
- One task per test file (matching each source file)
- One task for Storybook stories (grouped per component)
- Size: S for hook tests, M for component tests

### Task Fields

Every task must have:
```json
{
  "id": "task-001",
  "round": 0,
  "name": "Scaffold CRM domain directory and stub files",
  "agent": "ship-scaffolder",
  "size": "M",
  "inputs": [
    "apps/web/src/domains/crm/domain-spec.yaml",
    ".claude/templates/domain-index.md"
  ],
  "outputs": [
    "apps/web/src/domains/crm/INDEX.md",
    "apps/web/src/domains/crm/types/crm.types.ts",
    "apps/web/src/domains/crm/services/crm.api.ts"
  ],
  "done": [
    "Domain directory exists at apps/web/src/domains/crm/",
    "INDEX.md follows domain-index template",
    "All stub files contain anchor comments"
  ],
  "depends": [],
  "journeys": [],
  "gotchas": []
}
```

### Validation Before Writing

Before writing the manifest, verify:
- Every entity field from the spec has a task that creates its type definition
- Every component from the archetype mapping has a task that builds it
- Every page route has a task that creates its route file
- Every source file has a corresponding test task in Round 4
- No circular dependencies between tasks
- Every output file has exactly one task that creates it
- Task IDs are sequential (task-001, task-002, ...)

---

## Phase 5: Output & Next Steps

### Summary
Print a summary table:

```
Domain: {domain-name} ({label})
Pages:      {count} ({list of archetypes used})
Components: {count} (primary + supporting)
Hooks:      {count}
Tasks:      {count} across 5 rounds
```

### Generated Files
```
docs/plans/domains/{domain-name}-brief.md   — Feature Brief (sections 1-7)
docs/plans/domains/{domain-name}-tasks.json — Task Manifest ({count} tasks)
```

### Next Steps
Print recommended next steps:
1. Review the Feature Brief — especially personas, journeys, and anti-goals
2. Review the Task Manifest — check task sizing and dependencies
3. Run `/ship docs/plans/domains/{domain-name}-brief.md` to start building

### Flag Handling
- If `--dry-run`: print the summary and file paths but do NOT write any files. Show a preview of the first 3 tasks.
- If `--ship`: after writing both files, invoke `/ship docs/plans/domains/{domain-name}-brief.md`
- If `--brief-only`: skip Phase 4 entirely, only generate the Feature Brief

---

## Reference: Archetype-to-Component Mapping

Use this table when generating components, hooks, and tasks:

| Archetype | Primary Component | Hook | Supporting |
|---|---|---|---|
| entity-list | {Entity}List | use{Entities} | columns definition file |
| entity-detail | {Entity}Detail | use{Entity} | {Entity}Summary, tab components |
| multi-step-form | {Entity}Form | use{Entity}Form | step components |
| dashboard | {Domain}Dashboard | use{Domain}Stats | stat widgets, chart widgets |
| kanban | {Entity}Board | use{Entity}Pipeline | {Entity}Card |
| calendar | {Domain}Calendar | use{Domain}Events | event dialog |
| settings-config | {Domain}Settings | use{Domain}Settings | section components |
| timeline-log | {Entity}Log | use{Entity}Log | detail drawer |

## Reference: Entity Name Conventions

- Entity name from spec (e.g. `enquiries`) is pluralised for list hooks: `useEnquiries`
- Singularised for detail hooks: `useEnquiry`
- PascalCase for components: `EnquiryList`, `EnquiryDetail`, `EnquiryForm`
- Domain name for cross-entity components: `CrmDashboard`, `CrmSettings`
