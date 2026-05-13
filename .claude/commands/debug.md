---
description: Debug an issue systematically
argument-hint: [error message or issue description]
---

# Debug: $ARGUMENTS

## Step 1: Reproduce

First, understand the issue:
- What is the exact error message?
- What steps trigger it?
- Is it consistent or intermittent?
- When did it start? What changed?

```bash
# Check recent changes
git log --oneline -10
git diff HEAD~5 --name-only
```

## Step 2: Locate

Find where the error originates:

```bash
# Search for error message in code
grep -rn "error message text" --include="*.ts" --include="*.tsx" src/

# Search for related function/component
grep -rn "FunctionName\|ComponentName" --include="*.ts" --include="*.tsx" src/

# Check typescript errors
npx tsc --noEmit 2>&1 | head -50

# Check for the specific file if known
cat -n src/path/to/file.ts | head -100
```

## Step 3: Analyse

Once located, understand the cause:

### Common Causes & Fixes

| Error Type | Likely Cause | Investigation |
|------------|--------------|---------------|
| `Cannot read property 'x' of undefined` | Null/undefined access | Add optional chaining `?.` |
| `Type 'X' is not assignable` | Type mismatch | Check interfaces match |
| `is not a function` | Wrong import/undefined | Check export/import |
| `Network error` | API issue | Check endpoint, CORS |
| `Maximum update depth` | Infinite re-render | Check useEffect deps |
| `Hydration mismatch` | Server/client differ | Check conditional rendering |

### Debug Steps

1. **Read the stack trace** - Find the originating file/line
2. **Check the data** - What values are actually present?
3. **Trace backwards** - Where does the bad data come from?
4. **Check types** - Does typescript agree with reality?
5. **Check async** - Is data loaded before use?

## Step 4: Fix

Apply the fix following standards:

```typescript
// BEFORE: Unsafe access
const name = user.profile.name

// AFTER: Safe with fallback
const name = user?.profile?.name ?? 'Unknown'

// BEFORE: Untyped error
catch (error) {
  console.log(error)
}

// AFTER: Properly typed and handled
catch (error: unknown) {
  if (error instanceof Error) {
    logger.error('Operation failed', { 
      message: error.message,
      stack: error.stack,
      context: { userId, operation: 'fetchProfile' }
    })
  }
  toast.error('Failed to load profile')
}
```

## Step 5: Verify

After fixing:

```bash
# Check types compile
npx tsc --noEmit

# Run related tests
npm test -- --grep "[related test pattern]"

# If UI bug, test manually:
# 1. Clear browser cache
# 2. Reproduce original steps
# 3. Confirm fix works
# 4. Test edge cases
```

## Step 6: Prevent Regression

Add a test that would have caught this:

```typescript
describe('when user profile is undefined', () => {
  it('handles missing profile gracefully', () => {
    const user = { id: '1', profile: undefined }
    
    // This should not throw
    expect(() => render(<UserCard user={user} />)).not.toThrow()
    
    // Should show fallback
    expect(screen.getByText('Unknown')).toBeInTheDocument()
  })
})
```

## Step 7: Document & Commit

If non-obvious bug:
```typescript
// Fixed: profile can be undefined when user is newly created
// but hasn't completed onboarding. Added fallback handling.
const name = user?.profile?.name ?? 'Unknown'
```

Commit:
```bash
git add .
git commit -m "fix([module]): handle undefined profile in UserCard

- Add optional chaining for profile access
- Add fallback display for missing name
- Add test for undefined profile case

Fixes #123"
```

---

Now debug: $ARGUMENTS