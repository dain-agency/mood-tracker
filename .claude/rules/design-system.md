# Design System

These rules ensure consistent UI across Herbert. AI-generated code must reuse existing components — never recreate what already exists.

## Status Key

- **ENFORCE NOW** — these patterns exist today and must be followed

## Related rules

- `.claude/rules/component-defaults.md` — AD-10 / AD-11 / AD-12: how every component in `packages/ui/` declares its defaults; how app-specific defaults belong in app-local wrappers; why `packages/ui/` never references an app by name. Enforced by the permanent `prd-018-defaults-required.sh`, `prd-018-no-master-fork.sh`, and `prd-018-no-app-name-branch.sh` hooks.

---

## Component Hierarchy (ENFORCE NOW)

| Layer | Location | Examples |
|-------|----------|---------|
| **Atoms** | `apps/web/src/components/ui/` | Button, Input, Card, Badge (shadcn-ui) |
| **Molecules** | `apps/web/src/components/composed/` | FormField, SearchInput, StatCard, WizardDialog, StepIndicator |
| **Organisms** | `apps/web/src/components/organisms/` | DataTable, Charts |
| **Layout** | `apps/web/src/components/layout/` | Page, Sidebar, AppShell |
| **Domain** | `apps/web/src/domains/[name]/components/` | Feature-specific components |
| **Shared package** | `packages/ui/` (`@herbert/ui`) | Cross-app shared components |

### Component Resolution Hierarchy (TOP DOWN)

When building UI, **always resolve top-down**. Start at the highest level and only drop down when the higher level doesn't cover your need:

```
1. Domain components   → domains/*/components/           (existing domain-specific UI)
2. Archetype stories   → components/layout/archetypes/   (page-level composition patterns — the CANONICAL reference)
3. Organisms           → components/organisms/            (MasterTable, KanbanBoard, Timeline, Charts)
4. Composed/Molecules  → components/composed/             (FormField, StepIndicator, KPIMetricCard, EmptyState)
5. Atoms/Primitives    → components/ui/                   (Button, Card, Badge — shadcn-ui)
6. Shared package      → packages/ui/                     (cross-app: CountingNumber, AnimatedProgress, Fade, etc.)
```

- **Never skip levels.** If an archetype composes organisms in a specific way, follow that composition.
- **If you're importing 3+ atoms to build something, stop.** A composed component or organism almost certainly exists.
- **Pages stories are the authority** for how page-level components should be structured. Read the relevant story at `components/layout/archetypes/*.stories.tsx` (Storybook prefix `Pages/*`) before building any page component.

### Before Creating ANY Component

1. Check domain components in `domains/*/components/` for domain-specific UI
2. Check archetype stories in `components/layout/archetypes/` for page composition patterns
3. Check organisms in `components/organisms/` for complex reusable components
4. Check molecules in `components/composed/` for combined components
5. Check atoms in `components/ui/` for shadcn-ui primitives
6. Check `packages/ui/src/` for shared cross-app components
7. Need a new primitive? Add from shadcn-ui (`npx shadcn@latest add <component>`)
8. **After every `npx shadcn add`:** Check installed files for bare CSS variable refs (`--popover`, `--sidebar`, `--border`) and fix to `--color-*` format. Check `globals.css` for re-injected HSL variables that conflict with OkLCH tokens.
9. If nothing exists, discuss with the team before creating — do not silently introduce a new component

### Where New Components Go

- **Reusable atoms/molecules/organisms** — the appropriate folder under `apps/web/src/components/`
- **Domain-specific UI** — `apps/web/src/domains/[name]/components/`
- **Cross-app shared components** — `packages/ui/src/` (exported via `@herbert/ui`)

### Storybook Organisation (Brad Frost 5-Level Atomic Design)

Storybook follows [Brad Frost's Atomic Design](https://bradfrost.com/blog/post/atomic-design-and-storybook/) model:

| Level | Storybook prefix | Folder | What belongs |
|-------|-----------------|--------|-------------|
| 5. Pages | `Pages/*` | `layout/archetypes/` | Canonical page composition patterns — the authority for how to build any page |
| 4. Layout | `Layout/*` | `layout/` | Shell components: AppShell, Sidebar, Page, CommandMenu |
| 3. Organisms | `Organisms/*` | `organisms/` | Complex reusable sections: DataTable, Charts, Timeline, Kanban |
| 2. Molecules | `Molecules/*` | `composed/` | Simple atom combinations: FormField, EmptyState, StepIndicator |
| 1. Atoms | `Atoms/*` | `ui/` | shadcn-ui primitives: Button, Input, Card, Badge |

**Domain components (`domains/*/components/`) do NOT have Storybook stories.** They are wired integrations of design system components. Reference `Pages/*` for how to compose pages.

---

## Styling (ENFORCE NOW)

1. **NEVER** use inline styles or the `style` prop
2. **NEVER** use arbitrary Tailwind values (e.g., `text-[13px]`, `bg-[#ff0000]`, `p-[18px]`)
3. **ALWAYS** use design token classes (e.g., `text-primary`, `bg-muted`, `border-input`)
4. **ALWAYS** use the Tailwind spacing scale (e.g., `p-4`, `gap-6`, not `p-[18px]`)
5. Colour comes from CSS variables only — never hardcode hex/rgb values

---

## Icons (ENFORCE NOW)

1. **ALWAYS** import icons from `lucide-react`
2. **NEVER** use inline SVGs, Font Awesome, Heroicons, or any other icon library

---

## Toast Notifications (ENFORCE NOW)

1. **ALWAYS** use Sonner for toast notifications (`import { toast } from 'sonner'`)
2. Sonner is already configured in the root layout — never add a second `<Toaster />`
3. **NEVER** use `window.alert()`, custom toast implementations, or other notification libraries

---

## Page Structure (ENFORCE NOW)

> `Page` component: `apps/web/src/components/layout/page.tsx`

1. Every authenticated page MUST use the `Page` layout component
2. Pages MUST provide: `title`, and optionally `description`, `breadcrumbs`, `actions`
3. Page content width is controlled by the layout prop, not custom CSS
4. Never create custom layout wrappers — pages render inside the app layout

---

## Tables (ENFORCE NOW)

> `useTable` hook: `apps/web/src/components/organisms/data-table/use-table.ts`
> `MasterTable` component: `apps/web/src/components/organisms/data-table/master-table.tsx`

1. ALL data tables MUST use the `useTable` hook + `MasterTable` component
2. **NEVER** use raw `<table>`, `<tr>`, `<td>` HTML elements for data display — ESLint enforced at `error` level
3. **NEVER** import `@tanstack/react-table` directly — it is wrapped by `useTable`. ESLint enforced at `error` level
4. Start with the closest preset and override specific flags
5. Available presets:

| Preset | Use case |
|--------|----------|
| `PRESET_ENTITY_LIST` | Standard CRUD list pages (residents, enquiries, contacts) — multi-select, dropdown actions, CSV export |
| `PRESET_MOBILE_LOOKUP` | Mobile-optimised lookup tables — card-view, comfortable density, no pagination |
| `PRESET_SETTINGS` | Low-density settings/configuration tables — no search, inline actions, minimal chrome |
| `PRESET_DASHBOARD_SUMMARY` | Compact summary tables inside dashboard widgets — compact density, no pagination |
| `PRESET_LOG_VIEWER` | Audit logs and activity feeds — server pagination, column search, PDF export |
| `PRESET_FINANCIAL` | Invoice/billing tables — multi-select, column totals, all export formats, sticky first column |
| `PRESET_LIVE_STATUS` | Real-time status boards (shift tasks, medication rounds) — realtime updates, inline editing |

6. Import pattern:

```typescript
import { MasterTable, useTable, PRESET_ENTITY_LIST } from '@/components/organisms/data-table';
```

---

## Forms (ENFORCE NOW)

> `useFormConfig` hook: `apps/web/src/lib/hooks/use-form-config.ts`
> `FormField` component: `apps/web/src/components/composed/form-field.tsx`

1. ALL forms MUST use React Hook Form with Zod resolvers
2. ALL forms MUST use the `useFormConfig` hook + `FormField` component
3. **NEVER** use raw `<form>`, `<input>`, `<select>` HTML elements — use shadcn-ui form primitives at minimum
4. Every form MUST have a Zod schema shared with the API endpoint
5. Use `autosave` option for forms used by mobile care staff
6. Multi-step wizard **dialogs** MUST use `WizardDialog` from `@/components/composed/wizard-dialog` + the canonical `useWizard` from `@/lib/hooks/use-wizard` (the `@herbert/ui` hook; API `{ totalSteps, validateStep }`). Never reimplement step navigation manually. **Two same-named hooks exist** (PRD-018 M11a): this canonical *System 1*, and a web-local *System 2* at `@/components/layout/use-wizard` (API `{ steps, initialStep }`) that is the companion hook of the `@herbert/ui` `MultiStepFormShell`, scoped to the multi-step-form archetype (enquiry-form). Use System 1 for dialogs; only the `MultiStepFormShell` uses System 2.
7. **`required` prop is mandatory for required fields** — `FormField` accepts a `required` prop that renders a visible `*` marker on the label (using `text-destructive` or `text-muted-foreground` per the design token) AND sets `required` + `aria-required="true"` on the underlying input. Any `FormField` bound to a Zod field using `.min(1)` or a non-optional schema type MUST pass `required={true}`. Note: the `required` prop rendering is Wave 1b T1 (the component must accept the prop before this rule is fully enforced — track in Wave 1b manifest).
8. **Copy must not lie about required fields** — if a dialog or form contains the copy "Fields marked with * are required" or similar, at least one `FormField` in that form MUST have `required={true}` and render a visible `*`. Mismatched copy is a BLOCK (see Wave 1 Contacts finding).
9. **Build-time check (ship-ui-builder)** — if dialog copy contains "required" or "mandatory", grep the same file for `required={true}`. If none found, it is a copy lie — flag as BLOCK before shipping.
10. **Audit check (ship-ui-auditor)** — for any visible text matching `* required` or `required *` patterns, count rendered `*` markers in the DOM and compare against the claim. Zero markers with non-zero claim is a BLOCK.

---

## Feedback Patterns (ENFORCE NOW)

> All feedback components: `apps/web/src/components/composed/`
> `ConfirmDialog`: `confirm-dialog.tsx` | `ErrorState`: `error-state.tsx` | `EmptyState`: `empty-state.tsx` | `LoadingState`: `loading-state.tsx`

1. Use `ConfirmDialog` for all destructive actions (delete, archive, cancel)
2. Use `ErrorState` component for error boundaries and failed data loads
3. Use `EmptyState` component for zero-data states (with icon, title, description, action)
4. Use `LoadingState` component for loading/skeleton states

---

## Empty-State CTA Co-location (ENFORCE NOW)

Every empty-state message that implies a user action ("Add your first X", "No Y yet — create one", "Get started by creating a Z") **MUST** render a working action button in the same visible viewport.

1. **Build-time check** — grep the component for `EmptyState` copy; if the title or description contains "add", "create", "get started", or "first", verify the sibling JSX includes a `<Button>` with a live `onClick` (not `() => {}`).
2. **Action must be real** — the button must navigate, open a working dialog, or call a mutation. A toast-only handler is a fake CTA and is treated as a BLOCK.
3. **Co-location is mandatory** — the CTA must be rendered *inside* the `EmptyState` `action` prop or immediately adjacent in the same viewport section. A button elsewhere on the page does not satisfy this rule.
4. **Audit check** — `ship-ui-auditor` will click every empty-state CTA and verify it produces a navigable or interactive result. Zero-effect clicks are a BLOCK.

```tsx
// Correct — action prop wires a real handler
<EmptyState
  icon={FileText}
  title="No templates yet"
  description="Add your first template to get started."
  action={<Button onClick={() => setCreateOpen(true)}>Add Template</Button>}
/>
```

---

## Animation & Micro-interactions (ENFORCE NOW)

> All 9 animation primitives and the `useReducedMotion` hook are exported from `@herbert/ui`.

1. **NEVER** add Framer Motion / Motion directly to a page or component — ESLint enforced
2. Animated primitives are ONLY the ones exported from `@herbert/ui`:
   - `CountingNumber` — animates from 0 to target using easing (dashboard KPIs)
   - `SlidingNumber` — digit-by-digit slide transition (real-time counters)
   - `ScrollingNumber` — slot-machine scroll effect (live totals)
   - `AnimatedProgress` — spring-animated progress bar (wizards, completion %)
   - `Fade` — opacity transition with configurable duration/delay (content entering viewport)
   - `Slide` — directional slide-in from top/bottom/left/right (panels, loading states)
   - `AutoHeight` — animates height changes on content resize (accordions, expanding sections)
   - `NotificationList` — animated add/remove for notification feeds
   - `ThemeToggler` — animated light/dark theme switch
3. `useReducedMotion` hook — returns `true` when `prefers-reduced-motion: reduce` is active. All primitives use this internally; use it in custom transitions
4. Import pattern:
   ```typescript
   import { CountingNumber, Fade, Slide, useReducedMotion } from '@herbert/ui';
   ```
5. Do NOT use animation for decoration — only for communicating data changes or state transitions
6. All animated components must respect `prefers-reduced-motion` automatically (handled by the primitives)

---

## Storybook (ENFORCE NOW)

> Storybook config: `apps/web/.storybook/main.ts`, `apps/web/.storybook/preview.ts`

1. Every new shared component (atoms, molecules, organisms) must have a `.stories.tsx` file
2. Check Storybook for composition examples before creating new components
3. Stories must cover: default state, all variants, edge cases (empty, loading, error)
