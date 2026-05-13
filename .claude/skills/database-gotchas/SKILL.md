---
name: database-gotchas
description: >
  Database and Supabase gotchas — auto-invoked when writing SQL migrations, RLS policies,
  triggers, partitioning, cron jobs, or Supabase configuration. Lightweight index that
  points to specific sections in docs/gotchas/GOTCHAS.md.
user-invocable: true
disable-model-invocation: false
---

# Database Gotchas — Quick Reference

Before writing any SQL migration, RLS policy, trigger, or Supabase configuration, scan this checklist. If an item applies, load the full section from `docs/gotchas/GOTCHAS.md` using:
```
Grep "ANCHOR: <id>" in docs/gotchas/GOTCHAS.md → Read from that line, limit=30
```

## Security & RLS

| When you... | Gotcha | Anchor |
|---|---|---|
| Create a SECURITY DEFINER function | Must REVOKE FROM PUBLIC + GRANT to specific role. Also SET search_path. Any authenticated user can call it otherwise. | `security-definer-revoke` |
| Write RLS policies | RLS returns empty rows, not 403. App must handle this. | `rls-empty-not-403` |
| Use auth.uid() in RLS | Returns NULL for anon requests — policy silently matches nothing. | `rls-auth-uid-null` |
| Enable RLS on a table | Must add policies in the same migration or document why not. Default is deny-all. | `rls-enabled-no-policies` |
| Add a second layer of RLS (e.g., home-level on top of tenant) | Must use `AS RESTRICTIVE`. Default PERMISSIVE uses OR logic — the second layer is bypassed. | `rls-restrictive-vs-permissive` |
| Use RLS helper functions in policies | Grant EXECUTE to `anon` too, not just `authenticated`. Otherwise anon queries hard-error. | `anon-role-function-grants` |
| Use current_setting() in RLS policies | Replaced by `core.tenant_id()` which reads JWT. Never use `current_setting('app.tenant_id')` directly. | `guc-tenant-isolation-use-jwt` |
| Reference the "auth" schema | Supabase reserves it. Use "iam" for app-level auth tables. | `supabase-auth-schema-reserved` |

## Partitioning

| When you... | Gotcha | Anchor |
|---|---|---|
| Convert a table to partitioned | Destroys ALL triggers, RLS, indexes from prior migrations. Must re-apply everything. | `partitioning-destroys-triggers-rls` |
| Create child/DEFAULT partitions | Children do NOT inherit parent RLS. Must explicitly enable + create policies on each partition. | `partition-children-no-rls-inheritance` |

## Triggers & Audit

| When you... | Gotcha | Anchor |
|---|---|---|
| Apply append-only USING(false) on UPDATE | Check if the table needs UPDATE for business operations (clock-out, check-out). Only block DELETE if needed. | `append-only-update-block` |
| Audit sensitive tables with row triggers | TRUNCATE bypasses all row-level triggers. Need a separate FOR EACH STATEMENT trigger. | `truncate-bypasses-row-triggers` |

## Migrations & Functions

| When you... | Gotcha | Anchor |
|---|---|---|
| Write SQL migrations | Must be idempotent: IF NOT EXISTS, CREATE OR REPLACE, DROP IF EXISTS. | `migration-idempotent` |
| Squash migrations | Squash drops INSERT, cron schedules, vault secrets. Verify after squash. | `migration-squash-data-loss` |
| Call functions defined in other migrations | Stub signatures must match real signatures exactly. Wrong signatures create overloads. | `cross-migration-function-signatures` |
| Create pg_cron jobs | DROP+CREATE function can leave stale cache. Use CREATE OR REPLACE. | `pg-cron-stale-cache` |

## Data & Performance

| When you... | Gotcha | Anchor |
|---|---|---|
| Use JSONB columns | Values > 2KB go to TOAST storage, causing 2-10x slowdown. | `jsonb-toast-2kb` |
| Query tables that might exceed 10K rows | Supabase silently truncates at row limit. Must use .range() pagination. | `supabase-row-limit-pagination` |
| Query across tenants for analytics | Use materialised views refreshed by service_role. Never expose service_role to reporting. | `cross-tenant-analytics` |

## Supabase Platform

| When you... | Gotcha | Anchor |
|---|---|---|
| Deploy Edge Functions | Env vars need explicit `supabase secrets set`. Not inherited from .env. | `edge-function-env-vars` |
| Configure auth redirects | URLs must be whitelisted in Supabase Dashboard. | `supabase-auth-redirect-whitelist` |
| Expose a non-public schema via REST API | Need exposed schemas in dashboard + GRANT USAGE/SELECT to anon/authenticated + project restart. | `supabase-expose-schema-postgrest` |
| Regenerate Supabase types | The Supabase MCP `generate_typescript_types` tool only returns the `public` schema. It does NOT support multi-schema generation. Use the CLI instead: `npx supabase gen types typescript --project-id <id> --schema public --schema core --schema iam ...` (requires `SUPABASE_ACCESS_TOKEN` via `npx supabase login`). The `npm run types:supabase` script wraps this with all 27 schemas. | N/A |
| Decide when to regenerate types | Only needed after DDL changes (CREATE/ALTER/DROP TABLE/VIEW/TYPE). NOT needed after adding functions, triggers, RLS policies, indexes, cron jobs, or storage buckets — these don't affect the generated types. | N/A |
| Insert seed users via raw SQL | GoTrue crashes on NULL token columns (`recovery_token`, etc.). Must use empty strings, not NULL. | `seed-users-null-token-columns` |
