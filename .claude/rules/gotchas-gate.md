# Gotchas Gate

**MANDATORY before writing or editing ANY code file:**

## SQL / Database / Supabase work
Before writing or editing `.sql` files, RLS policies, triggers, migrations, Supabase config, or any `apps/api/` database interaction code:
→ Invoke `/database-gotchas` (Skill tool with `skill: "database-gotchas"`)

## Frontend / React / Next.js work
Before writing or editing `.tsx`, `.ts` component files in `apps/web/`, hooks, pages, or test files:
→ Invoke `/frontend-gotchas` (Skill tool with `skill: "frontend-gotchas"`)

## Storybook work
Before writing or editing `.stories.tsx` files, Storybook config, or debugging Storybook rendering:
→ Invoke `/storybook-gotchas` (Skill tool with `skill: "storybook-gotchas"`)

## Why this matters
This project has 20+ documented gotchas from production incidents and code review. Ignoring them causes repeated mistakes that cost hours to debug. The skills are lightweight indexes (~60 lines) that load in <1 second.

## When to skip
- Reading/exploring code (no writes)
- Editing documentation, configs, or non-code files
- If you already invoked the relevant gotchas skill earlier in this conversation
