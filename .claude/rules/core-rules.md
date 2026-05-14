# Core Rules

These rules apply to ALL code written in this project. Violations should be caught during review.

## Language and Framework

- **Language:** typescript with strict mode enabled
- **Framework:** nextjs
- **Methodology:** {{methodology}}

## Coding Standards

1. **No `any` types** — Use proper types or `unknown` with type guards. The `any` type defeats the purpose of typescript.
2. **No `console.log` in production code** — Use a proper logger for backend. Remove all console.log before committing.
3. **Conventional commits** — Use `feat(scope):`, `fix(scope):`, `chore(scope):` format for all commit messages.
4. **{{spelling_convention}} spelling** in all user-facing text — {{spelling_examples}}.

## Component Usage

1. **Use {{component_library}}** — All UI primitives come from the component library. Never create custom `<Button>`, `<Input>`, `<Card>` etc.
2. **Use {{icon_library}}** — All icons from the designated icon library. Never mix icon libraries.
3. **Check existing components first** — Before creating ANY component, check:
   - `components/ui/` for primitives
   - `components/composed/` for combined components
   - `components/organisms/` for complex reusable components
   - `domains/*/components/` for domain-specific UI

## Data and State

1. **{{data_fetching_library}} for server state** — All server data fetching and caching uses {{data_fetching_library}}. Never use useState + useEffect for data fetching.
2. **{{form_library}} for forms** — All forms use {{form_library}} with {{validation_library}} resolvers.
3. **API client for all requests** — Use the shared `apiClient`, never direct fetch() or database client calls from the frontend.

## Architecture

1. **Domain boundaries** — Business logic lives in `domains/`, not `app/` or `components/`. Pages in `app/` are thin wrappers that render domain components.
2. **Tenant isolation** — Every database query must be tenant-scoped. Use the tenant-aware database client.
3. **Input validation** — Every API endpoint that accepts user input must validate with {{validation_library}} schemas.

## Anti-Patterns

1. **No `z.any()` without null guards** — If downstream code accesses properties, the schema MUST validate that structure.
2. **No stale closures** — When `setFoo(value)` is followed by a function that reads `foo`, the closure still has the old value. Pass `value` directly.
3. **No `{{orm}} generate` forgetting** — Run `{{orm}} generate` after any schema change. A stale client causes silent 500 errors.