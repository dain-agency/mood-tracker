# Testing Standards

These rules govern all test code in this project.

## Framework

- **Test runner:** {{testing_framework}}
- **Component testing:** {{component_testing_library}}
- **E2E testing:** {{e2e_framework}}
- **Run tests from:** `{{test_working_directory}}`

## Requirements

1. **Every new file needs a test file** — `.test.ts` or `.test.tsx` sibling file.
2. **Never run the full test suite** — Run only tests affected by your changes (specific files or directories).
3. **No `.only()` in committed code** — `.only()` skips other tests silently.
4. **No `any` in test files** — Same type safety standards as production code.

## Test File Naming

```
src/domains/crm/hooks/use-enquiries.ts
src/domains/crm/hooks/use-enquiries.test.ts

src/domains/crm/components/enquiry-form.tsx
src/domains/crm/components/enquiry-form.test.tsx
```

## What to Test

### Services / Business Logic
- Input validation (valid and invalid inputs)
- Edge cases (empty arrays, null values, boundary conditions)
- Error handling (thrown errors, rejected promises)
- Business rules (calculations, transformations, state transitions)

### Hooks
- Return values for different states (loading, error, success)
- Mutation callbacks
- Query key structure

### Components
- Renders without crashing
- Displays correct content for given props
- User interactions trigger correct callbacks
- Loading, error, and empty states render correctly
- Form validation messages appear for invalid input

## Anti-Patterns

1. **No implementation testing** — Test behaviour, not implementation details. Don't assert on internal state or private methods.
2. **No snapshot overuse** — Snapshots are fragile. Use them sparingly for complex output. Prefer explicit assertions.
3. **No test interdependence** — Each test must be independent. Don't rely on execution order or shared mutable state.
4. **No sleeping** — Use {{testing_framework}}'s async utilities (waitFor, findBy) instead of `setTimeout` or `sleep`.
5. **Tests passing does not equal working** — Unit tests mock dependencies, so they can't catch integration issues. Always trace the full data path.

## Running Tests

```bash
# Run specific test file
cd {{test_working_directory}} && npx {{testing_framework}} run path/to/file.test.tsx

# Run domain tests
cd {{test_working_directory}} && npx {{testing_framework}} run src/domains/crm/

# TypeScript check
cd {{test_working_directory}} && npx tsc --noEmit
```

## Pre-Commit Checklist

- [ ] New files have test files
- [ ] Changed tests pass
- [ ] No `.only()` in test files
- [ ] `tsc --noEmit` passes