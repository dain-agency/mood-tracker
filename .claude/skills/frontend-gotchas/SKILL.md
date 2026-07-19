---
name: frontend-gotchas
description: Live Dev KB query for React components, hooks, Next.js pages, Tailwind styles and Vitest tests. Replaces the drifted static index (2026-07-18).
user-invocable: true
---

# Frontend Gotchas (live KB wrapper)

The static index this skill used to carry drifted from its GOTCHAS.md anchors and was retired (KB 35bd031e; audit 2026-07-18 §4 R4). This skill is now a thin wrapper over the live Dev KB.

Run this query (DainOS MCP, resource `dev_knowledge_base`; psql fallback on `developer.dev_knowledge_base`):

- **Tags (any of):** react, nextjs, react-query, tailwind, vitest, zod, forms, css, design-system
- **Project:** current repo's slug AND `universal` (never one slug alone — KB 086aa8e8)
- **Order:** newest first, limit ~20; read `prevention` fields first.
- If the work names a vendor or library, ALSO free-text search that name.

Then proceed with the work, applying every relevant `prevention`. Log any NEW trap you hit back to the KB at wrap-up.
