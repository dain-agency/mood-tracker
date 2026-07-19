# Schema Design Check

Run this before creating or modifying any database schema (Prisma models, SQL migrations, or Forge schema builder changes).

## Instructions

Read `docs/gotchas-schema-design.md` and verify the following against the current work:

### Checklist

1. **Timestamps** — Does every table have `created_at`? Does every mutable table have `updated_at`? Are append-only tables correctly missing `updated_at`?

2. **tenant_id** — Does every tenant-scoped table have `tenant_id`? Are junction tables included? Are global reference tables (countries, currencies) correctly WITHOUT tenant_id?

3. **Lookup tables** — Are business-domain values using lookup table FKs (not plain text with CHECK constraints)? Are state machine fields correctly kept as plain text?

4. **Lookup table pattern** — Do all lookup tables follow the standard pattern: id, tenant_id?, code, display_name, sort_order, is_active, created_at, updated_at, @@unique([tenant_id, code])?

5. **Table names** — Are @@map names unique across ALL schemas (not just within one schema)? Are they snake_case plural?

6. **Cross-schema FKs** — Are cross-schema references using uuid String fields with `// FK →` comments (not Prisma @relation)? Do within-schema relations use proper @relation?

7. **Layer dependencies** — Do references flow downward only (Layer N references Layer N-1 and below)? Are cross-Layer-2 references limited to published primary entities?

8. **Soft delete** — Does user-facing data have `deleted_at DateTime?`? Are append-only tables correctly WITHOUT deleted_at?

9. **Encryption** — Do sensitive clinical fields use `Bytes` type with a non-sensitive companion field for searching?

10. **Accountability** — Do business data tables have `created_by` FK to auth.users?

11. **High volume** — Will this table grow beyond 10M rows/year? If so, is it designed for partitioning (created_at always populated, composite index with tenant_id)?

### Output

Report any violations found, grouped by category. For each violation, state:
- Which table/field
- What's wrong
- How to fix it

If no violations found, confirm the schema passes all checks.
