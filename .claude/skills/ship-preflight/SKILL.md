---
description: Pre-Flight Agent — final technical checks before human review
argument-hint: <worktree path>
---

# Ship Pre-Flight: $ARGUMENTS

You are the Pre-Flight Agent. You run final technical checks on the completed build before presenting it to the human for review.

**Worktree path:** `$ARGUMENTS`

---

## Checks

Run all of these from the worktree directory. Report each as PASS or FAIL with details.

### 1. TypeScript Compilation

**Always clear the tsbuildinfo cache before running, and disable incremental mode.** A stale `.tsbuildinfo` file caused PR #252's Pre-Flight to miss a `noUncheckedIndexedAccess` regression in a test file. Cache drift is a real failure mode.

```bash
rm -f <worktree>/apps/web/tsconfig.tsbuildinfo <worktree>/apps/api/tsconfig.tsbuildinfo
cd <worktree>/apps/web && npx tsc --noEmit --incremental false
cd <worktree>/apps/api && npx tsc --noEmit --incremental false
```

**Treat test-file tsc errors as failures, not noise.** The project's testing-standards rule (`.claude/rules/testing-standards.md`) explicitly says "Same type safety standards as production code." A `noUncheckedIndexedAccess` error in `*.test.ts` is a real regression that will catch a real bug — do not pre-emptively filter it out. If `tsc` exits non-zero for any reason, that is a FAIL.

### 2. Run Tests for New/Changed Files

Identify changed files:
```bash
cd <worktree> && git diff --name-only main...HEAD -- '*.ts' '*.tsx' | grep -v '.test.'
```

Run tests for those directories:
```bash
cd <worktree>/apps/web && npx vitest run <changed-dirs>
```

### 3. No `any` Types in New Files

```bash
cd <worktree> && git diff --name-only main...HEAD -- '*.ts' '*.tsx' | xargs grep -n ': any\|as any' 2>/dev/null
```

### 4. No `console.log` in New Files

```bash
cd <worktree> && git diff --name-only main...HEAD -- '*.ts' '*.tsx' | grep -v '.test.' | grep -v '.stories.' | xargs grep -n 'console\.log' 2>/dev/null
```

### 4b. No Hardcoded Locale/Currency in Formatters

```bash
cd <worktree> && git diff --name-only main...HEAD -- '*.ts' '*.tsx' | grep -v '.test.' | xargs grep -n "currency: '[A-Z]'" 2>/dev/null
```

FAIL if any new formatter hardcodes a currency code, locale, or timezone string. These should be read from tenant/user context.

### 5. No `.only()` in Tests

```bash
cd <worktree> && git diff --name-only main...HEAD -- '*.test.*' | xargs grep -n '\.only(' 2>/dev/null
```

### 6. Routes Registered

Check that any new route files are imported and registered in the appropriate router/app file.

### 7. Sidebar Navigation Updated

If the feature adds a new top-level page, verify the sidebar navigation includes it.

### 8. Cross-Layer Schema Consistency

**Verify that every frontend mutation's data shape is accepted by the backend validation schema.** This catches the #1 silent persistence failure: frontend sends data the backend rejects with 422, but no error is shown to the user.

```bash
# Find all section values sent from frontend mutations
cd <worktree> && grep -rn "section:" apps/web/src/domains/ --include="*.ts" --include="*.tsx" | grep -v ".test." | grep -v "node_modules" | grep "as const\|literal\|'[a-z]'"

# Find all discriminant values accepted by backend schemas
cd <worktree> && grep -rn "z.literal(" apps/api/src/shared/validation/ --include="*.ts" | grep "section"
```

For each frontend `section` value, verify it exists in the corresponding backend Zod discriminatedUnion. **FAIL** if any frontend value is missing from the backend schema.

**Why this matters:** In the repo structure designer build, `section: 'repoStructure'` was sent by the frontend but the backend discriminatedUnion only accepted `'design' | 'personas' | 'components' | 'schema'`. Every auto-save silently returned 422. No automated check caught this until human review.

### 9. Prisma Schema vs Migration FK Action Drift

For any new migration SQL in the PR, every `FOREIGN KEY ... REFERENCES ... ON DELETE <X> ON UPDATE <Y>` must match the corresponding Prisma `@relation` directive's `onDelete`/`onUpdate`. When they diverge, `prisma migrate dev` on the next run will silently regenerate a migration that reverts the DB to match the schema — breaking cascade/SetNull/Restrict semantics and creating zombie migrations.

```bash
# List FK actions declared in NEW migration files only
cd <worktree> && git diff --name-only main...HEAD -- 'apps/api/prisma/migrations/**/*.sql' | \
  xargs grep -niE 'FOREIGN KEY|ON DELETE|ON UPDATE'

# List every @relation in schema.prisma with onDelete/onUpdate
grep -nE '@relation.*onDelete|@relation.*onUpdate' apps/api/prisma/schema.prisma
```

Manually (or with a script) cross-reference each FK constraint in the migration against the Prisma model it targets. The mapping is:

| SQL clause | Prisma equivalent |
|---|---|
| `ON DELETE CASCADE` | `onDelete: Cascade` |
| `ON DELETE SET NULL` | `onDelete: SetNull` |
| `ON DELETE RESTRICT` | `onDelete: Restrict` |
| `ON DELETE NO ACTION` | `onDelete: NoAction` |
| (no clause) | defaults to `NoAction` in Postgres |

**FAIL** if any constraint in a new migration doesn't match the Prisma model.

**Fix:** Update the Prisma schema to match the migration. The migration is authoritative because it's already applied to the DB — changing it after the fact would require another migration.

**Why this matters:** In the payroll × HR × dividends build, `company_dividend_vouchers.employee` was declared `onDelete: NoAction` in schema.prisma but `ON DELETE SET NULL` in the migration. The next `prisma migrate dev` would have silently reverted the constraint to `NO ACTION`, breaking the graceful unlink-on-employee-delete protection. Greptile caught it at review time; Pre-flight should catch it before Greptile ever sees it.

### 10. AI Route Contract (when applicable)

If the branch touches any file matching `apps/web/src/app/api/ai/**` or `apps/web/src/domains/*/hooks/use-*-chat.ts`, run the project's Otto AI route guard:

```bash
cd <worktree> && bash scripts/check-ai-route-contract.sh
```

The guard enforces the Otto AI Route Contract (`skill-otto-ai-routes`; gate stub at `.claude/rules/otto-ai-routes.md`):

1. SSRF allowlist comes from `apps/web/src/app/api/ai/_lib/api-host.ts` (no inline `ALLOWED_API_HOSTS`)
2. Routes accept `userContext` in their Zod request schema
3. Client hooks forward `userContext` via `useOttoUserContext` from `@/domains/auth/hooks/use-otto-user-context`
4. System prompts pass client-supplied strings through `sanitiseForPrompt` from `apps/web/src/app/api/ai/_lib/prompt-safety.ts`

```bash
# detect whether the branch touched AI routes / chat hooks
cd <worktree> && git diff --name-only main...HEAD | grep -E 'apps/web/src/app/api/ai/|apps/web/src/domains/.*/hooks/use-.*-chat\.ts$'
```

If the diff is empty, this check is N/A. If it's non-empty, the guard MUST exit 0 to PASS.

**Why this matters:** Day Planner (PRD-072 morning) was forked off `main` BEFORE PR #199 (the contract). The contract violation (inline SSRF allowlist, missing `userContext` forwarding, local copies of `sanitiseForPrompt`) was only surfaced when the orchestrator ran the guard manually during Phase 9 prep — too late, requiring a mid-Phase-9 merge of `main` and a separate fix-cycle commit. Pre-flight catches the same drift on every future Otto-class build.

If the project lacks `scripts/check-ai-route-contract.sh`, mark this check N/A — the guard is project-specific (currently dain-os).

### Credentials (canonical convention)

Pre-flight checks above are static (TypeScript, tests, grep) and do NOT require browser login. However, if a future Pre-flight check adds a smoke-test that boots the dev server and logs in (e.g. a hosted health-check, a login-required route reachability probe):

- **Source:** read credentials from `apps/api/testing-credentials.txt` (first line = email, second line = password). Use the `Read` tool, then pass the values directly to whatever automation needs them.
- **NEVER** re-derive from `process.env.TESTING_EMAIL` / `process.env.TESTING_PASSWORD` or from `apps/api/.env`.
- **NEVER** prompt the user to paste credentials.
- **Do not** echo the password to a shell or log it.

This is the canonical convention across the entire ship pipeline (Discovery, Architect wireframe-auth, Pre-flight, E2E). See `feedback_testing_credentials` in user memory for rationale.

---

## Report Format

```markdown
# Pre-Flight Report

**Status:** PASS / FAIL
**Timestamp:** <ISO>

| Check | Status | Details |
|-------|--------|---------|
| TypeScript (web) | PASS | |
| TypeScript (api) | PASS | |
| Tests | PASS | 12 tests, 12 passed |
| No `any` types | PASS | |
| No `console.log` | PASS | |
| No `.only()` | PASS | |
| Routes registered | PASS | |
| Sidebar updated | N/A | No new pages |

## Issues Found
(only if FAIL — list each issue with file:line)
```

---

## On Failure

For each failing check:
1. Fix the issue directly (if straightforward)
2. Re-run the failing check
3. Max 3 fix cycles total across all checks
4. If still failing after 3 cycles, report to the orchestrator with details
