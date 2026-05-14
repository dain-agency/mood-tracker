---
description: Plan and implement a new feature with proper structure
argument-hint: [feature description]
---

# New Feature: $ARGUMENTS

**STOP. Do not write code yet.**

## Phase 1: Understand

### Questions to Answer
1. What is the core functionality?
2. Who uses this feature? (residents, staff, admin?)
3. What data does it need?
4. What existing code/patterns can be reused?
5. Are there edge cases or error scenarios?

Ask the user clarifying questions if anything is unclear.

## Phase 2: Plan

### Files to Create/Modify

| File | Type | Purpose |
|------|------|--------|
| `src/modules/[domain]/types/[Feature].types.ts` | Types | Data interfaces |
| `src/modules/[domain]/services/[feature].service.ts` | Service | Business logic |
| `src/modules/[domain]/hooks/use[Feature].ts` | Hook | Data fetching |
| `src/modules/[domain]/components/[Feature].tsx` | Component | UI |
| `src/modules/[domain]/__tests__/[Feature].test.ts` | Test | Tests for above |

### Types First
```typescript
// Define all interfaces before implementation
interface FeatureInput {
  // ...
}

interface FeatureResponse {
  // ...
}
```

### API Endpoints (if needed)
| Method | Route | Purpose | Request | Response |
|--------|-------|---------|---------|----------|
| GET | /api/[resource] | Fetch all | - | FeatureResponse[] |
| POST | /api/[resource] | Create | FeatureInput | FeatureResponse |

### Component Tree
```
FeaturePage
\u251c\u2500\u2500 FeatureHeader
\u251c\u2500\u2500 FeatureList
\u2502   \u2514\u2500\u2500 FeatureCard (\u00d7n)
\u2514\u2500\u2500 FeatureForm (modal?)
```

### State Management
- What state is needed?
- Local state vs server state (React Query)?
- What loading/error states?

## Phase 3: Confirm

Present this plan and ask:
> "Does this plan look correct? Any changes before I implement?"

## Phase 4: Implementation Order

Execute in this order (each step must pass type check):

1. **Types** (packages/types or .types.ts)
   ```bash
   npx tsc --noEmit  # Must pass
   ```

2. **Service/API** (business logic)
   ```bash
   npx tsc --noEmit  # Must pass
   ```

3. **Hook** (data fetching)
   ```bash
   npx tsc --noEmit  # Must pass
   ```

4. **Components** (UI)
   ```bash
   npx tsc --noEmit  # Must pass
   ```

5. **Tests** (for each file above)
   ```bash
   npm test  # Must pass
   ```

6. **Integration** (wire it all together)
   ```bash
   npm test && npx tsc --noEmit  # Must pass
   ```

## Phase 5: Verification

Before marking complete:
- [ ] `npx tsc --noEmit` passes
- [ ] `npm test` passes
- [ ] `npm run lint` passes (if configured)
- [ ] No `any` types
- [ ] Error handling in place
- [ ] Loading states handled
- [ ] Test files exist for all new source files

## Phase 6: Commit

```bash
git add .
git commit -m "feat([module]): [feature description]"
```

---

Now plan: $ARGUMENTS