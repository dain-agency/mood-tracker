# Gotchas Gate

**MANDATORY before writing or editing ANY code file:**

## The query, not the index

The static skill indexes drifted from their GOTCHAS.md anchors (KB 35bd031e) and cannot keep up with ~20 new entries a week. Query the live Dev KB instead (DainOS MCP, resource `dev_knowledge_base`; or `psql` against `developer.dev_knowledge_base` when the MCP is unavailable):

| Work about to start | Query |
|---|---|
| SQL / RLS / migrations / Supabase / Prisma | tags any-of: supabase, rls, postgres, prisma, migrations; project in (this repo's slug, universal) |
| React / Next.js / hooks / forms / tests | tags any-of: react, nextjs, react-query, vitest, tailwind, zod; project in (this repo's slug, universal) |
| Storybook / Chromatic | tags any-of: storybook, chromatic; project in (this repo's slug, universal) |
| A named vendor (Connecteam, SharePoint, Salesforce, Documenso, Xero, Sage, Meta, Google, ...) | free-text search on the vendor name |
| Worktrees / CI / hooks / agent tooling | tags any-of: worktree, ci, hooks, claude-code |

Rules of use:

1. **ALWAYS include the `universal` bucket.** The PR reviewer once missed 1,057 entries by hardcoding one project slug (KB 086aa8e8).
2. **Read `prevention` fields first** — that is the actionable half of every entry.
3. Limit to the most recent ~20 per query; broaden only on a hit that references older entries.
4. An empty result means your filter is wrong more often than it means no knowledge exists (rule-dainos-mcp-interaction move 3).

## Why this matters

The KB holds 3,100+ entries from production incidents and review. Sessions that skip the query re-discover known traps: the same fact has been logged up to five times because retrieval failed (audit 2026-07-18 §9.4). Ignoring it costs hours.

## When to skip

- Reading/exploring code (no writes)
- Editing documentation, configs, or non-code files
- If you already ran the relevant query earlier in this conversation
