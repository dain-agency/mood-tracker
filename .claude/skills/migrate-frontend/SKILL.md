---
description: Convert external UI into a frontend domain with {{component_library}} primitives, React Query hooks, and proper test coverage.
argument-hint: [domain-name]
---

# Frontend Migration: $ARGUMENTS

Convert source UI into a frontend domain at `apps/web/src/domains/$ARGUMENTS/`.

## Rules

1. **{{component_library}} atoms** — Use `components/ui/` primitives (Button, Input, Card, Badge, etc.)
2. **{{icon_library}}** — Use the project's chosen icon library, NOT alternatives
3. **{{data_fetching_library}}** — Server state via hooks, NOT client-side stores
4. **API client** — `apiClient` from `lib/api/`, NOT direct fetch calls
5. **Forms** — {{form_library}} + zodResolver, combobox for entity lookups
6. **Tests required** — Every `.tsx` needs a `.test.tsx`
7. **Stories required** — Reusable components need `.stories.tsx`

## File Structure

```
apps/web/src/domains/$ARGUMENTS/
|- components/
|  |- {Feature}List.tsx
|  |- {Feature}FormModal.tsx
|  |- {Feature}Preview.tsx
|- hooks/
|  |- use-{feature}.ts
|- types/
|  |- index.ts
```

## Replacement Table

| Source Pattern | Target Replacement |
|---------------|-------------------|
| `import { X } from 'lucide-react'` | Import from {{icon_library}} |
| `useStore()` (Zustand) | `useQuery()` / `useMutation()` from {{data_fetching_library}} |
| Direct Supabase client | `apiClient` via `@/lib/api/` |
| Custom `<Input>`, `<Button>` | `@/components/ui/` from {{component_library}} |

## Manifest-Driven Feature Implementation

Switch to feature-by-feature mode using the migration manifest. For each session: read manifest, select highest-priority unblocked feature, implement, run verification criteria, update status.

## Verification

```bash
cd apps/web && npx tsc --noEmit
cd apps/web && npx {{testing_framework}} run src/domains/$ARGUMENTS/
```