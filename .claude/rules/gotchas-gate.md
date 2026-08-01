# Gotchas Gate

**MANDATORY before writing or editing ANY code file:**

## The query, not the index

The static skill indexes drifted from their GOTCHAS.md anchors (KB 35bd031e) and cannot keep up with ~20 new entries a week. Query the live Dev KB instead.

**The two names differ, and both are correct in their own place.** Over the DainOS MCP the resource is `developer_knowledge_base`. In SQL the table is `developer.dev_knowledge_base` (Prisma `@@map("dev_knowledge_base")`). Passing the SQL name to the MCP fails outright with `Unknown resource "dev_knowledge_base"`, so do not carry it into a `query` call, and do not "correct" the SQL name to match the MCP one when using `psql`.

```
query({ resource: "developer_knowledge_base", search: "prisma migration", limit: 20 })
```

**Search is the entry point. `tags` is NOT filterable.** Only `project`, `module`, `category`, `severity` and `title` can be filtered, and each value must be a single string, number or boolean. An array is rejected before it reaches the database (`invalid_union ... expected string, received array`), and even a single-string tags filter is refused: `Field "tags" is not filterable on "developer_knowledge_base"`. Tags come back on every entry, so read them, but never query by them.

| Work about to start | Query |
|---|---|
| SQL / RLS / migrations / Supabase / Prisma | `search` the specific thing: `prisma migration`, `rls policy`, `postgres index` |
| React / Next.js / hooks / forms / tests | `search`: `react query`, `vitest mock`, `tailwind token`, `zod schema` |
| Storybook / Chromatic | `search`: `storybook story`, `chromatic snapshot` |
| A named vendor (Connecteam, SharePoint, Salesforce, Documenso, Xero, Sage, Meta, Google, ...) | `search` the vendor name |
| Worktrees / CI / hooks / agent tooling | `search`: `worktree`, `local stack`, `claude code` |

Search is tokenised and whitespace terms are ANDed across `title` and `description`, so two words narrow hard and three usually over-narrow. Start with one or two, then narrow with `module` (real values include `dev-environment`, `database`, `design-system`, `accessibility`), `category` (`gotcha`, `pattern`, `lesson`, `decision`, `workaround`) or `severity` (`critical`, `high`, `medium`, `low`).

Rules of use:

1. **Do NOT set `project` unless you mean to exclude everything else.** The filter takes ONE slug, so "this repo plus universal" cannot be expressed in a single call. Omitting `project` searches ALL projects, which is what you want: it covers both this repo's entries and the cross-cutting `universal` ones. Hardcoding a single slug is how the PR reviewer once missed 1,057 entries (KB 086aa8e8). An unknown slug returns a 422 naming the valid slugs rather than an empty result.
2. **Read `prevention` fields first:** that is the actionable half of every entry.
3. Limit to the most recent ~20 per query; broaden only on a hit that references older entries. The server maximum is 50.
4. An empty result means your filter is wrong more often than it means no knowledge exists (rule-dainos-mcp-interaction move 3).

**Correction (2026-07-31).** This rule previously named the MCP resource `dev_knowledge_base`, which does not exist, and built every row of the table above on a `tags any-of: ...` filter plus `project in (this repo's slug, universal)`. Neither works: tags is not filterable at all, array filter values are rejected by the input schema, and `project` accepts a single slug. Every session in every synced repo was being sent to a call that errors, then to a filter that also errors. Verified against the live MCP before this edit.

## Why this matters

The KB holds 3,100+ entries from production incidents and review. Sessions that skip the query re-discover known traps: the same fact has been logged up to five times because retrieval failed (audit 2026-07-18 §9.4). Ignoring it costs hours.

## When to skip

- Reading/exploring code (no writes)
- Editing documentation, configs, or non-code files
- If you already ran the relevant query earlier in this conversation
