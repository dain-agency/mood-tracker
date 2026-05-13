---
name: frontend-gotchas
description: >
  Frontend gotchas — auto-invoked when writing React components, hooks, Next.js pages,
  Tailwind styles, or Vitest tests. Lightweight index pointing to docs/gotchas/GOTCHAS.md.
user-invocable: true
disable-model-invocation: false
---

# Frontend Gotchas — Quick Reference

Before writing React components, hooks, pages, or tests, scan this checklist. If an item applies, load the full section from `docs/gotchas/GOTCHAS.md` using:
```
Grep "ANCHOR: <id>" in docs/gotchas/GOTCHAS.md → Read from that line, limit=30
```

## React & State

| When you... | Gotcha | Anchor |
|---|---|---|
| Fetch server data | Use React Query, never useState+useEffect for data fetching. | `server-state-management` |
| Write mutation callbacks | Invalidate ALL affected query keys across domains, not just the mutated entity. | `react-query-cache-invalidation` |
| Use optimistic updates with Realtime | Deduplicate to prevent flicker (mutation ID pattern). | `optimistic-updates-realtime-flicker` |

## Next.js

| When you... | Gotcha | Anchor |
|---|---|---|
| Load heavy components (charts, PDF, editors) | Use `next/dynamic` with `ssr: false` and loading skeleton. | `nextjs-dynamic-imports` |
| Create modal routes | Use a single `@modal` parallel route slot with sub-routes. | `nextjs-parallel-routes-modal` |
| Test components using useRouter | Mock `next/navigation` at module level. | `nextjs-mock-router` |
| Use navigation hooks in Storybook | Wrap in try-catch; pass `urlSync: false` to avoid router crashes. | `nextjs-hooks-storybook-crash` |

## Styling

| When you... | Gotcha | Anchor |
|---|---|---|
| Override Tailwind classes | Use `cn()` (tailwind-merge). Class order does NOT determine specificity. | `tailwind-class-order` |

## Testing (Vitest)

| When you... | Gotcha | Anchor |
|---|---|---|
| Mock modules with vi.mock | Factory runs once per file, not per test. Use mockImplementation per test. | `vitest-mock-factory-once` |
| Spy on function exports | vi.spyOn doesn't work on primitive exports. Use vi.mock instead. | `vitest-spyon-primitive` |
| Test React Query hooks | Create fresh QueryClient per test with retry:false, gcTime:0. | `react-query-test-isolation` |
| Assert on resolved data in component tests | `findByTestId` may match loading-state DOM before query resolves. Use `waitFor` with explicit attribute checks. | `react-query-loading-state-race` |
| Test with scrollTo/IntersectionObserver | Guard or mock missing jsdom APIs. | `jsdom-missing-apis` |
| Use TanStack Table column defs in tests | Cast columns to `ColumnDef<T, unknown>[]` to fix generic variance. | `tanstack-table-columndef-variance` |
| Set defaultSort on useTable/MasterTable | Must use the column `id`, not `accessorKey`. When both exist, `id` takes precedence. | `tanstack-table-defaultsort-column-id` |

## Data & Schema

| When you... | Gotcha | Anchor |
|---|---|---|
| Reference document file fields | `file_path`, `file_type`, `file_size` live on `document_revisions`, NOT `documents`. | `documents-table-no-file-columns` |
| Build renderRowActions for MasterTable | Must return ReactNode (JSX), not an array of action config objects. | `render-row-actions-returns-jsx` |
| Use Zod `.default()` with zodResolver | Creates input/output type mismatch. Use `useForm({ defaultValues })` instead. | `zod-default-breaks-zodresolver` |
| Map reference data to dropdowns | Use `display_name`, not `name`. Reference tables use `code` + `display_name` pattern. | `reference-data-display-name` |

## Mutations & Server Actions

| When you... | Gotcha | Anchor |
|---|---|---|
| Call a server action from a mutation | Use `useActionMutation` — raw `useMutation` silently succeeds on `ActionResult.failure()`. | `action-result-silent-failure` |
| Write a Zod create schema for server actions | Do NOT include `tenant_id`, `created_by`, or `created_at` — server action adds these after validation. | `zod-schema-system-fields` |

## Wiring & Integration

| When you... | Gotcha | Anchor |
|---|---|---|
| Add a button, link, or action to a component | It MUST have an `onClick`/`href` handler OR be explicitly `disabled` with a `title` explaining why. No decorative buttons. | `archetype-stories-must-be-read` |

## Architecture & Composition

| When you... | Gotcha | Anchor |
|---|---|---|
| Build any page-level component | MUST read the archetype story first AND match its structure exactly. Patching archetype pieces onto a non-archetype structure doesn't count. | `archetype-stories-must-be-read` |
| "Fix" a component to match an archetype | Rebuild from the archetype structure, don't bolt pieces onto the old structure. Section ordering, Page wrapper, layout must all match. | `archetype-stories-must-be-read` |
| Use an organism inside an archetype section | MUST match the archetype's nested preset, wrapper (Card, TooltipProvider), and categories — not just the organism itself. | `archetype-nested-organisms` |
