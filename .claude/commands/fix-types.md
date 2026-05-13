---
description: Scan for and fix all 'any' types in the codebase
argument-hint: [path or file, default: src/]
---

# Fix typescript Any Types

Scan the specified path for `any` type usage and fix them with proper types.

## Process

1. **Find all any types**:
   ```bash
   grep -rn ": any\|as any" --include="*.ts" --include="*.tsx" ${1:-src/} | grep -v "// @allow-any"
   ```

2. **For each occurrence, analyse**:
   - What data is being typed?
   - Where does it come from? (API, function param, catch block, event)
   - What properties/methods are accessed?

3. **Apply the appropriate fix**:

| Source | Fix Strategy |
|--------|-------------|
| API response | Create interface matching response shape, use Zod for runtime validation |
| Function parameter | Use generics `<T>` or union types or specific interface |
| Catch block | Use `unknown` with `instanceof Error` check |
| Event handler | Use nextjs event types: `nextjs.ChangeEvent<HTMLInputElement>` |
| Third-party lib | Check for `@types/package`, create declaration if needed |
| Complex object | Define interface in `.types.ts` file |

4. **Verify after each fix**:
   ```bash
   npx tsc --noEmit
   ```

## Fix Examples

### API Response
```typescript
// BEFORE
const data: any = await response.json()
data.users.map(u => u.name)

// AFTER
interface User {
  id: string
  name: string
  email: string
}
interface ApiResponse {
  users: User[]
  total: number
}
const data = await response.json() as ApiResponse
```

### Catch Block
```typescript
// BEFORE
catch (error: any) {
  console.log(error.message)
}

// AFTER
catch (error: unknown) {
  if (error instanceof Error) {
    logger.error('Failed', { message: error.message })
  } else {
    logger.error('Failed', { error: String(error) })
  }
  toast.error('Operation failed')
}
```

### Function Parameter
```typescript
// BEFORE
function process(data: any) {
  return data.items.filter(item => item.active)
}

// AFTER
interface ProcessableData {
  items: Array<{ id: string; active: boolean }>
}
function process(data: ProcessableData) {
  return data.items.filter(item => item.active)
}

// OR with generics
function process<T extends { items: Array<{ active: boolean }> }>(data: T) {
  return data.items.filter(item => item.active)
}
```

### Event Handlers
```typescript
// BEFORE
const handleChange = (e: any) => setValue(e.target.value)

// AFTER
const handleChange = (e: nextjs.ChangeEvent<HTMLInputElement>) => {
  setValue(e.target.value)
}

// Common nextjs event types:
// nextjs.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>
// nextjs.FormEvent<HTMLFormElement>
// nextjs.MouseEvent<HTMLButtonElement>
// nextjs.KeyboardEvent<HTMLInputElement>
```

### Third-Party Library
```typescript
// If @types/package doesn't exist, create local declaration:

// src/types/untyped-lib.d.ts
declare module 'untyped-lib' {
  export interface Config {
    apiKey: string
    timeout?: number
  }
  export function initialize(config: Config): void
  export function getData(): Promise<unknown>
}
```

## Skip These (add // @allow-any comment)
- Type definition files (.d.ts)
- Test mocks where any is genuinely needed
- Third-party type workarounds (document why)

## After Fixing
1. Run `npx tsc --noEmit` to verify all types compile
2. Run tests to ensure behaviour unchanged
3. Commit: `fix(types): replace any types in [module]`

---

Now scan and fix: $ARGUMENTS