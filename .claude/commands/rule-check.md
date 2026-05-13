---
description: Audit codebase against project rules — catch violations that hooks miss over time
argument-hint: [optional: "fix" to auto-fix where safe, or specific check name]
---

# Rule Check: $ARGUMENTS

Periodic audit command. Scans the codebase for rule violations that accumulate between sessions. Run this after major changes, at milestone boundaries, or whenever you suspect drift.

**Default mode:** report only. **Fix mode** (`/rule-check fix`): auto-fix safe violations and report the rest.

You can also run a single check: `/rule-check british-english` or `/rule-check changelog`.

---

## Check 1: British English (`british-english`)

Grep all `.tsx` and `.ts` files under `apps/` and `packages/` for common American spellings in string literals, JSX text, comments, and labels.

**Search patterns** (case-insensitive, in quoted strings and JSX text only):
```
"color" (but NOT "color:" in CSS/Tailwind — exclude className, cn(), and style props)
"organization" / "organizations"
"center" (but NOT "text-center", "items-center" etc. — exclude Tailwind classes)
"license" (noun context)
"authorized" / "unauthorized"
"favorite" / "favorites"
"catalog"
"behavior"
"labor"
"theater"
"defense"
"customize" / "customized"
"analyze" / "analyzed"
"optimize" / "optimized"
```

**How to check:** Use Grep with patterns like `"[Cc]olor"` in `.tsx`/`.ts` files, then manually filter out CSS/Tailwind contexts (className, cn(), tailwind utility classes). Only flag strings that appear in user-facing text (labels, messages, tooltips, headings, placeholder text).

**Fix mode:** Replace American → British spelling in user-facing strings only.

---

## Check 2: Changelog vs Commits (`changelog`)

Compare git commit history against `developer.changelog` entries on DainOS Supabase.

```bash
# Get all commit SHAs on develop from last 7 days
git log --format="%H" --since="7 days ago" develop
```

```sql
-- Get all changelog SHAs for this project from last 7 days
SELECT commit_sha FROM developer.changelog
WHERE project = 'eoc-herbert'
  AND created_at >= (now() - interval '7 days');
```

**Report:** List any commit SHAs present in git but missing from the changelog table.

**Fix mode:** For each missing SHA, gather the commit details and INSERT into the changelog.

---

## Check 3: Test Coverage (`tests`)

Check that every `.ts`/`.tsx` source file under `src/` has a corresponding `.test.ts`/`.test.tsx` sibling.

**Exclude:** Type definition files (`.d.ts`), index barrel files (`index.ts` that only re-export), config files, layout files that are trivial wrappers.

**How to check:** Use Glob to find all source files, then check for test file existence.

**Report:** List source files missing test files, grouped by domain.

---

## Check 4: Type Safety (`types`)

Grep for `any` type usage across the codebase.

```
: any
as any
<any>
z.any()
@ts-ignore (without explanation comment)
@ts-nocheck
```

**Exclude:** Test files for `: any` (mocks sometimes need it), generated files (`supabase.ts`).

**Report:** Count and list violations by file.

---

## Check 5: Error Handling (`errors`)

Grep for error handling anti-patterns:

```
catch.*\{\s*\}                    # Empty catch blocks
catch.*console\.(log|error|warn)  # Console instead of logger
return null.*catch                # Swallowing errors
catch.*\/\/.*ignore               # Silently ignoring
```

**Exclude:** Test files.

**Report:** List violations with file and line number.

---

## Check 6: Console Usage (`console`)

Grep for direct `console.log`, `console.error`, `console.warn` in production code.

**Exclude:** Test files, scripts/, config files, `.mjs`/`.cjs` config files.

**Report:** List violations. Should use `@herbert/utils` logger instead.

---

## Check 7: Domain Boundaries (`domains`)

Check for business logic leaking into `app/` routes:

- Grep for `useEffect`, `useState`, `useMutation`, `useQuery` in `app/` route files
- Grep for `fetch(`, `supabase.`, `apiClient.` in `app/` route files
- Check for files > 50 lines in `app/` directories (routes should be thin)

**Exclude:** `layout.tsx`, `providers.tsx`, `middleware.ts`, `error.tsx`, `loading.tsx`, `not-found.tsx`.

**Report:** List route files with business logic that should be in a domain.

---

## Check 8: INDEX.md Freshness (`indexes`)

For each domain that has source files, compare the files listed in INDEX.md against actual files on disk.

**How to check:** For each domain folder with an INDEX.md:
1. Parse the INDEX.md tables for listed file names
2. Glob the actual files in the domain
3. Report files on disk but missing from INDEX.md, and files in INDEX.md but missing from disk

**Report:** List stale INDEX.md files with specific missing/extra entries.

---

## Check 9: Supabase Types Freshness (`supabase-types`)

Check if the Supabase types file is older than the latest migration.

```bash
# Compare timestamps
ls -la packages/types/src/supabase.ts
ls -la supabase/migrations/ | tail -1
```

If the latest migration is newer than supabase.ts, types may be stale.

**Report:** Warn if types appear stale.

---

## Check 10: `.only()` in Tests (`test-only`)

Grep for `.only(` in all test files. These skip other tests silently.

```
\.only\(
```

**Report:** List violations with file and line number.

**Fix mode:** Remove `.only` calls.

---

## Output Format

Present results as a summary table, then details for each failing check:

```
# Rule Check Report — {date}

| # | Check | Status | Violations |
|---|-------|--------|------------|
| 1 | British English | PASS/FAIL | {count} |
| 2 | Changelog completeness | PASS/FAIL | {count} missing |
| 3 | Test coverage | PASS/FAIL | {count} files missing tests |
| 4 | Type safety | PASS/FAIL | {count} `any` usages |
| 5 | Error handling | PASS/FAIL | {count} |
| 6 | Console usage | PASS/FAIL | {count} |
| 7 | Domain boundaries | PASS/FAIL | {count} |
| 8 | INDEX.md freshness | PASS/FAIL | {count} stale |
| 9 | Supabase types | PASS/FAIL | fresh/stale |
| 10 | .only() in tests | PASS/FAIL | {count} |

## Failures

### Check N: {name}
{details with file paths and line numbers}

### Recommended fixes
{actionable list, grouped by priority}
```

---

## Rules

1. **Run checks in parallel** where possible (most are independent Grep calls).
2. **Be precise, not noisy.** Filter out false positives (Tailwind classes, generated files, test mocks). A noisy report gets ignored.
3. **In fix mode,** only auto-fix changes that are safe and reversible. For anything ambiguous, report but don't fix.
4. **Don't run tsc or tests** — this command is for static analysis only. The user runs tsc and tests separately.
5. **Use Supabase MCP** (`execute_sql` on project `nkwxprrhkifxoeqwvnpu`) for changelog verification.
6. **Run from repo root.** All paths relative to the repo root.
