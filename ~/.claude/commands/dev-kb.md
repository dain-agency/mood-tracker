# Dev Knowledge Base

Surface relevant gotchas, patterns, and lessons before you make the same mistake twice.

## Usage

```
/dev-kb $ARGUMENTS
```

- `/dev-kb` (no args) — auto-detect context from current files/conversation
- `/dev-kb database migrations` — explicit search terms
- `/dev-kb --all react` — include medium/low severity (default is critical+high only)
- `/dev-kb --add <description>` — write a new entry

## Step 1: Determine context

If `$ARGUMENTS` is empty, auto-detect by examining file paths in conversation, code patterns in recent edits, and git diff.

File-path-to-module mappings include: `prisma/migrations/` → database/prisma; `domains/*/components/*.tsx` → react/ui; `*.test.tsx` → testing/vitest; `middleware.ts` → nextjs/security; `Dockerfile` → docker; `.github/workflows/*` → cicd; `*.py` → pyspark/fabric.

Code-pattern-to-tag mappings: `useEffect` → useEffect/stale-closure; `CREATE POLICY` → rls/security; `as any` → type-safety; `dangerouslySetInnerHTML` → xss/security; `vi.mock` → vitest/mocking; `useSearchParams` → nextjs/suspense.

## Step 2: Query the KB

Use Supabase MCP, project ID `nkwxprrhkifxoeqwvnpu`. Query `developer.dev_knowledge_base` filtering by project (universal OR current) and severity (critical+high by default). Order by severity then category. Limit 8.

## Step 2b: Add a new entry (--add flag)

Reference allowed values:
- `category`: gotcha, pattern, lesson, decision, workaround
- `source_type`: fix_commit, pr_comment, pr_review, code_review, ai_conversation, incident, documentation, debugging_session
- `severity`: critical, high, medium, low

Draft the INSERT and show to user for confirmation. After successful insert, run Step 5 propagation.

## Step 3: Present results (compact format)

```
### KB: N relevant entries for [context]

**[CRITICAL]** Title of entry
  Prevention advice (1-2 sentences max)
```

Only expand full description if user asks.

## Step 4: Actionable summary

End with: "Key risk: [the single most important thing to watch out for]."

## Step 5: Propagate KB entries to local Claude files

When a new KB entry is inserted, propagate to:
- **CLAUDE.md** — Critical entries ONLY, one-line rule in Critical Rules
- **Commands/skills** — All severities, add guards/checks
- **PR Checklist** — Verifiable pre-PR
- **Ship command** — Affects build/deploy
- **Auto-memory** — Critical always, others if recurring
- **Hooks** — All severities if automatable
- **E2E command** — All severities if testable
