---
description: Add {{orm}} models for a new domain with tenant isolation, timestamps, and proper registration.
argument-hint: [schema-namespace]
---

# Database Migration: $ARGUMENTS

Add {{orm}} models in the `$ARGUMENTS` schema namespace.

## Rules

1. **Schema namespace** — Add `"$ARGUMENTS"` to datasource schemas array
2. **All models** — Use `@@schema("$ARGUMENTS")` directive
3. **Tenant isolation** — Every domain model includes `tenant_id String`
4. **Timestamps** — `created_at DateTime @default(now())` and `updated_at DateTime @updatedAt`
5. **Naming** — `snake_case` for tables and columns
6. **IDs** — UUID primary keys with `@default(dbgenerated("gen_random_uuid()"))`
7. **Register** — Add model names to tenant-scoped models registry

## Schema Template

```{{orm_schema_language}}
model {table_name} {
  id         String   @id @default(dbgenerated("gen_random_uuid()"))
  tenant_id  String
  // ... domain fields
  created_at DateTime @default(now())
  updated_at DateTime @updatedAt
  created_by String?

  @@schema("$ARGUMENTS")
}
```

## System/Global Records

For models that support both system-wide and tenant-specific records:
- Make `tenant_id` nullable
- System records: `tenant_id = null`
- Do NOT add these to tenant-scoped models registry

## Manifest-Driven Status Updates

After creating models, update the migration manifest.

## Verification

```bash
cd apps/api && npx {{orm}} generate
cd apps/api && npx tsc --noEmit
```