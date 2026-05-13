---
description: Comprehensive code review against project standards
argument-hint: [file or path to review]
---

# Code Review: $ARGUMENTS

## Review Process

1. **Read the code** to understand what it does
2. **Check each category below** systematically
3. **Report issues** with file:line, problem, and fix
4. **Summarise** with pass/fail and issue counts

---

## Review Checklist

### BLOCKING (Must Fix)

#### Type Safety
- [ ] No `any` types (grep `: any`, `as any`)
- [ ] No `@ts-ignore` without explanation
- [ ] Proper types on function parameters and returns
- [ ] No implicit any
- [ ] Catch blocks use `unknown` not `any`

#### Error Handling
- [ ] No empty catch blocks
- [ ] All async operations have try/catch
- [ ] Errors logged with context
- [ ] User feedback on errors (toast/alert)
- [ ] `.then()` has `.catch()` if used

#### Testing
- [ ] Test file exists for source file
- [ ] Tests cover happy path
- [ ] Tests cover error cases
- [ ] No `.only()` in tests

#### Security
- [ ] No hardcoded secrets/API keys
- [ ] No hardcoded URLs (use env vars)
- [ ] No `eval()` or `new Function()`
- [ ] No `dangerouslySetInnerHTML` without sanitization
- [ ] No SQL string interpolation

### WARNINGS (Should Fix)

#### nextjs Patterns
- [ ] No `useEffect` + `fetch` (use useQuery)
- [ ] Loading states handled
- [ ] Error states handled
- [ ] No inline functions in JSX (if many)
- [ ] Keys in lists are stable IDs (not index)

#### Code Quality
- [ ] No `console.log` (use logger)
- [ ] No commented-out code
- [ ] No TODO without ticket reference
- [ ] File under 300 lines
- [ ] No magic numbers (use constants)

#### Accessibility
- [ ] Images have alt text
- [ ] Form inputs have labels
- [ ] Buttons have accessible names
- [ ] No click handlers on divs without role

#### Naming & Structure
- [ ] Components: PascalCase.tsx
- [ ] Hooks: useCamelCase.ts
- [ ] Services: camelCase.service.ts
- [ ] File in correct module folder
- [ ] Imports from correct packages

---

## Report Format

```
## Summary
[PASS/FAIL] - X blocking issues, Y warnings

## BLOCKING ISSUES

### 1. [Category]: [Brief description]
**File**: path/to/file.ts:42
**Problem**: [What's wrong]
**Fix**:
\`\`\`typescript
// Before
[problematic code]

// After
[fixed code]
\`\`\`

## WARNINGS

### 1. [Category]: [Brief description]
**File**: path/to/file.ts:15
**Suggestion**: [How to improve]

## GOOD PRACTICES OBSERVED
- [Positive observations if any]
```

---

## Review Commands

```bash
# Check for any types
grep -rn ": any\|as any" --include="*.ts" --include="*.tsx" $ARGUMENTS

# Check for console.log
grep -rn "console\.log" --include="*.ts" --include="*.tsx" $ARGUMENTS

# Check for empty catches
grep -rn "catch.*{" --include="*.ts" -A 1 $ARGUMENTS | grep -B 1 "^.*}$"

# Check typescript compiles
npx tsc --noEmit

# Check for missing test files
# For each .ts/.tsx in path, verify .test.ts/.test.tsx exists

# Run ESLint
npx eslint $ARGUMENTS
```

---

Now review: $ARGUMENTS