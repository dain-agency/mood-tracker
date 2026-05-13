# mood-tracker



## Tech Stack

- **Frontend:** nextjs, typescript, {{css_framework}}, {{component_library}}
- **Backend:** supabase, {{orm}}, {{api_style}}
- **Auth:** {{auth_provider}}
- **Testing:** {{testing_framework}}, {{component_testing_library}}, {{e2e_framework}}
- **Quality:** {{linter}}, {{formatter}}, typescript strict mode

## Environment

```bash
{{package_manager}} install          # Install dependencies
{{dev_command}}                       # Start development server
```

## Structure

```
{{source_root}}
|- app/                 # nextjs routes (thin, delegate to domains)
|- components/
|  |- ui/               # {{component_library}} primitives (atoms)
|  |- composed/         # Combined components (molecules)
|  |- layout/           # Layout components
|- domains/             # DDD bounded contexts
|  |- [domain]/
|     |- components/    # Domain UI (organisms)
|     |- hooks/         # Domain logic
|     |- services/      # API calls
|     |- stores/        # State management
|     |- types/         # Domain types
|- lib/                 # Shared utilities
|- shared/              # Cross-cutting types, constants
```

## Commands

```bash
{{dev_command}}              # Start development server
{{build_command}}            # Production build
{{lint_command}}             # Lint check
```

**Testing** — always run from `{{test_working_directory}}`:

```bash
cd {{test_working_directory}} && npx {{testing_framework}} run path/to/file.test.tsx   # Run specific test(s)
cd {{test_working_directory}} && npx {{testing_framework}} run src/domains/crm/        # Run domain tests
cd {{test_working_directory}} && npx tsc --noEmit                                      # TypeScript check
```

- **Never run the full test suite** — it is slow and unnecessary
- Run only tests affected by your changes (specific files or directories)
- Run `npx tsc --noEmit` from `{{test_working_directory}}`, not the repo root

## Domain INDEX Files

Every domain has an `INDEX.md` file that serves as a structured map of that domain. **Read the INDEX.md before exploring a domain** — it prevents unnecessary file reads and context bloat.

Each INDEX.md contains:
- **Dependencies** — what the domain imports
- **Types** — all type files with key exports and line counts
- **Hooks/Services** — every hook or service with function-level exports
- **Components** — every component with key props
- **Routes** — API endpoints with methods and controller mappings
- **Summary** — file and line counts by category

## Workflow

1. Read relevant domain INDEX.md before changes
2. Run `cd {{test_working_directory}} && npx tsc --noEmit` after edits
3. Run affected tests before committing (not the full suite)
4. Use conventional commits: `feat(scope):`, `fix(scope):`

## Critical Rules

- **Use existing components** — Check ui/, composed/, organisms/ before writing new UI
- **Use {{component_library}}** — Need a new primitive? Add from the component library
- **Use {{icon_library}}** — Not alternative icon libraries
- **No `any` types** — Use proper types or `unknown` with type guards
- **Tests required** — Every new file needs a `.test.tsx` file
- **Domain boundaries** — Business logic lives in `domains/`, not `app/` or `components/`
- **{{orm}} generate after schema changes** — Run `cd {{api_directory}} && npx {{orm}} generate` after any change to the schema. A stale client causes silent 500 errors.
- **No `z.any()` without null guards** — If downstream code accesses properties directly, the Zod schema MUST validate that structure.

## Component Usage

**ALWAYS check existing components before creating new ones.**

### Component Hierarchy

| Layer | Location | Examples |
|-------|----------|----------|
| **Atoms** | `components/ui/` | Button, Input, Card, Badge |
| **Molecules** | `components/composed/` | FormField, SearchInput, StatCard |
| **Organisms** | `components/organisms/` | DataTable, Charts |
| **Domain** | `domains/[name]/components/` | Feature-specific components |

### Before Creating ANY Component

1. Check atoms in `components/ui/` for {{component_library}} primitives
2. Check molecules in `components/composed/` for combined components
3. Check organisms in `components/organisms/` for complex reusable components
4. Check domain components in `domains/*/components/` for domain-specific UI
5. Need a new primitive? Add from {{component_library}}

### Forms

Use {{form_library}} with {{validation_library}} resolvers. Use combobox components for searchable select fields in form modals (entity lookups). Do **not** use raw text inputs for ID/UUID fields.

## Documentation

- **Architecture:** `docs/architecture.md` — Domain patterns and structure
- **PRDs:** `docs/prds/` — Read before implementing features