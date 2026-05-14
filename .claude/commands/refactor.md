---
description: Safely refactor code with verification at each step
argument-hint: [what to refactor and why]
---

# Refactor: $ARGUMENTS

## Safe Refactoring Workflow

### Step 0: Verify Starting Point

Before any changes:
```bash
# Ensure clean state
git status

# Ensure tests pass
npm test

# Ensure types compile
npx tsc --noEmit

# Create checkpoint
git add .
git commit -m "chore: checkpoint before refactor"
```

### Step 1: Understand Current State

1. Read the code to understand what it does
2. Identify all usages:
   ```bash
   grep -rn "FunctionName\|ComponentName" --include="*.ts" --include="*.tsx" src/
   ```
3. Check existing tests - they document expected behaviour
4. Note any implicit contracts or edge cases

### Step 2: Plan the Refactor

| Current | Target | Risk |
|---------|--------|------|
| [what exists] | [what you want] | [what could break] |

Common refactoring patterns:
- **Extract function** - Pull logic into reusable function
- **Extract component** - Split large component
- **Extract hook** - Move state logic to custom hook
- **Rename** - Improve naming (use IDE refactor tools)
- **Move** - Relocate to better module
- **Consolidate** - Merge duplicated code

### Step 3: Write Tests First (if missing)

If the code lacks tests, add them BEFORE refactoring:

```typescript
// Capture current behaviour
describe('ExistingFunction', () => {
  it('handles normal input', () => {
    expect(existingFunction(normalInput)).toEqual(expectedOutput)
  })
  
  it('handles edge case', () => {
    expect(existingFunction(edgeCase)).toEqual(edgeExpected)
  })
})
```

This ensures your refactor doesn't change behaviour.

### Step 4: Make Changes Incrementally

**Small steps, frequent verification.**

After EACH change:
```bash
# Types still compile?
npx tsc --noEmit

# Tests still pass?
npm test

# If both pass, checkpoint
git add .
git commit -m "refactor: [small step description]"
```

### Step 5: Refactoring Patterns

#### Extract Function
```typescript
// BEFORE
function processUser(user: User) {
  // 50 lines of validation
  // 50 lines of transformation
  // 50 lines of saving
}

// AFTER
function processUser(user: User) {
  const validated = validateUser(user)
  const transformed = transformUser(validated)
  return saveUser(transformed)
}

function validateUser(user: User): ValidatedUser { /* 50 lines */ }
function transformUser(user: ValidatedUser): TransformedUser { /* 50 lines */ }
function saveUser(user: TransformedUser): SavedUser { /* 50 lines */ }
```

#### Extract Component
```typescript
// BEFORE: 300 line component with complex list

// AFTER
function ResidentList({ residents }: Props) {
  return (
    <div>
      <ResidentListHeader count={residents.length} />
      <ResidentListFilters onFilter={handleFilter} />
      {residents.map(r => (
        <ResidentListItem key={r.id} resident={r} />
      ))}
      <ResidentListPagination {...pagination} />
    </div>
  )
}
```

#### Extract Hook
```typescript
// BEFORE: Logic mixed in component
function ResidentPage() {
  const [residents, setResidents] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  
  useEffect(() => { /* fetch logic */ }, [])
  
  // ... render
}

// AFTER: Logic in hook
function useResidents() {
  const [residents, setResidents] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  
  useEffect(() => { /* fetch logic */ }, [])
  
  return { residents, loading, error }
}

function ResidentPage() {
  const { residents, loading, error } = useResidents()
  // ... render
}
```

### Step 6: Update All Usages

If you changed a function/component signature:

```bash
# Find all usages
grep -rn "OldName" --include="*.ts" --include="*.tsx" src/

# Update each one
# Verify types after each file
npx tsc --noEmit
```

### Step 7: Clean Up

```bash
# Remove any dead code
grep -rn "function oldFunction" --include="*.ts" src/

# Check for unused imports (ESLint should catch)
npm run lint

# Final verification
npm test
npx tsc --noEmit
```

### Step 8: Final Commit

```bash
# Squash refactor commits if many small ones
git rebase -i HEAD~[number of commits]

# Or single commit
git add .
git commit -m "refactor(module): [description]

- Extract validation to separate function
- Split ResidentCard into smaller components
- Add missing type annotations

No functional changes."
```

## Abort if Needed

If something goes wrong:
```bash
# Reset to last checkpoint
git reset --hard HEAD

# Or reset to before refactor
git reset --hard [commit-before-refactor]
```

---

Now refactor: $ARGUMENTS