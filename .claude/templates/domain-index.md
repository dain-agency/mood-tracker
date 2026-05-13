<!-- Last updated: YYYY-MM-DDTHH:MM:SSZ -->
<!-- Domain: <domain-name> -->
<!-- Layer: frontend | backend -->

# <Domain Name> — INDEX

> One-sentence description of what this domain does and who it serves.

## Dependencies

| Imports From | What |
|-------------|------|
| `components/ui` | Button, Card, Input, Badge |
| `components/composed` | FormCombobox, SearchInput |
| `components/organisms` | DataTable |
| `domains/<other>` | useOtherHook, OtherType |
| `lib/api` | apiClient |

---

<!-- @anchor:types -->
## Types

| File | Description | Key Exports |
|------|-------------|-------------|
| `types/example.types.ts` | Domain type definitions | `Example`, `ExampleStatus` |

<!-- @anchor:services -->
## Services

| File | Lines | Description | Key Exports |
|------|-------|-------------|-------------|
| `services/example.api.ts` | 45 | API client functions | `exampleApi.getAll`, `.create` |

<!-- @anchor:hooks -->
## Hooks

| File | Lines | Description | Key Exports |
|------|-------|-------------|-------------|
| `hooks/use-examples.ts` | 32 | React Query list + mutations | `useExamples`, `useCreateExample` |

<!-- @anchor:components -->
## Components

| File | Lines | Description | Props | Used By |
|------|-------|-------------|-------|---------|
| `components/example-form.tsx` | 175 | Modal form | `open`, `onClose`, `onSuccess` | ExamplePage |

<!-- @anchor:pages -->
## Pages

| File | Route | Description |
|------|-------|-------------|
| `app/(app)/examples/page.tsx` | `/examples` | Main list page |

<!-- @anchor:utils -->
## Utilities

| File | Lines | Description | Key Exports |
|------|-------|-------------|-------------|

---

<!-- @anchor:backend (only in backend INDEX files) -->
## Backend

### Models
| Model | Table | Tenant Scoped | Key Fields |
|-------|-------|---------------|------------|

### Routes
| Method | Path | Controller | Description |
|--------|------|------------|-------------|

### Schemas
| File | Description | Key Exports |
|------|-------------|-------------|