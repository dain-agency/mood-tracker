---
description: Pre-PR validation checklist - run before opening a pull request
argument-hint: (no arguments needed)
---

# PR Checklist

Run this before opening a pull request.

## Automated Checks

```bash
# 1. typescript compilation
echo "-> typescript check..."
npx tsc --noEmit

# 2. Linting
echo "-> ESLint check..."
npm run lint 2>/dev/null || npx eslint . --ext .ts,.tsx

# 3. Tests
echo "-> Running tests..."
npx vitest run   # NEVER bare `npm test`: it hangs forever in watch-mode repos (KB 570f3ec0)

# 4. Check for any types
echo "-> Checking for any types..."
grep -rn ": any\|as any" --include="*.ts" --include="*.tsx" src/ | grep -v "// @allow-any" | head -10
# When scoping any check to the diff, ALWAYS use `git diff --name-only --diff-filter=d`:
# without --diff-filter=d a DELETED file in the diff makes file-targeted greps exit
# clean and the check reports CLEAN on a dirty diff (KB 4cdef371).

# 5. Check for console.log
echo "-> Checking for console.log..."
grep -rn "console\.log" --include="*.ts" --include="*.tsx" src/ | grep -v "__tests__" | head -10

# 6. Check for .only in tests
echo "-> Checking for .only in tests..."
grep -rn "\.only(" --include="*.test.ts" --include="*.test.tsx" --include="*.spec.ts" src/
```

## Manual Checklist

### Code Quality
- [ ] No `any` types (or justified with `// @allow-any`)
- [ ] No `console.log` statements
- [ ] No commented-out code
- [ ] No TODO without ticket reference
- [ ] Error handling in place for all async operations
- [ ] Loading and error states handled in UI

### Testing
- [ ] Test file exists for each new source file
- [ ] Tests cover happy path
- [ ] Tests cover error/edge cases
- [ ] All tests passing
- [ ] No `.only()` left in tests

### Types
- [ ] typescript compiles without errors
- [ ] New interfaces in appropriate location
- [ ] No implicit any
- [ ] No `(x as T[]) ?? []` on JSON/unknown fields -- use `Array.isArray(x) ? x : []` instead

### Security
- [ ] No hardcoded secrets or API keys
- [ ] No hardcoded URLs
- [ ] Sensitive data not logged

### Accessibility
- [ ] Images have alt text
- [ ] Form inputs have labels
- [ ] Interactive elements are keyboard accessible

### Database / {{orm}}
- [ ] If `{{orm}} schema` was modified: generate step has been run
- [ ] If new columns/models added: verified the client recognises them (no `Unknown argument` errors)
- [ ] If migrations added: tested against a fresh database or staging

### Git
- [ ] Branch name follows convention: `feature/`, `fix/`, `chore/`
- [ ] Commits follow conventional format
- [ ] No merge commits (rebased on main)
- [ ] Reasonable commit history (squash if needed)

## PR Description Template

```markdown
## What
[Brief description of what this PR does]

## Why
[Link to ticket or explanation of why this change is needed]
Fixes #[issue-number]

## How
[Technical approach if non-obvious]

## Testing
- [ ] Unit tests added/updated
- [ ] Manually tested locally
- [ ] Tested edge cases: [list them]

## Screenshots
[If UI changes, add before/after screenshots]

## Checklist
- [ ] typescript compiles
- [ ] Tests pass
- [ ] No any types
- [ ] Error handling complete
- [ ] Accessibility considered
```

## Final Steps

```bash
# Ensure you're up to date with main
git fetch origin main
git rebase origin/main

# Push
git push origin HEAD

# Create PR
gh pr create --title "feat(module): description" --body "..."
```

---

Running checks now...