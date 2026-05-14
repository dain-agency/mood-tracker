---
description: Convert external API routes into an Express domain with routes, controllers, services, and types.
argument-hint: [domain-name]
---

# Backend Migration: $ARGUMENTS

Convert source API routes into a backend domain at `apps/api/src/domains/$ARGUMENTS/`.

## Rules

1. **Route factory** — Export `create{Domain}DomainRoutes()` returning an Express Router
2. **Middleware chain** — `authenticate` -> `tenantMiddleware` -> `requireModule`
3. **Controllers** — Class-based, Zod validation, `ResponseUtil` responses
4. **Services** — Use tenant-scoped database client for all DB access
5. **Types** — Zod schemas for input validation, TypeScript interfaces for data shapes
6. **Error handling** — Domain-specific error class extending base

## File Structure

```
apps/api/src/domains/$ARGUMENTS/
|- routes/
|  |- index.ts                    # createXxxDomainRoutes()
|  |- {resource}.routes.ts
|- controllers/
|  |- {resource}.controller.ts
|- services/
|  |- {resource}.service.ts
|- types/
    |- {resource}.types.ts
```

## Registration

Add to `apps/api/src/index.ts`:
```typescript
apiV1.use('/$ARGUMENTS', create{Domain}DomainRoutes());
```

## Manifest-Driven Status Updates

After creating each backend resource, update the migration manifest — find matching features, run verification criteria, set status.

## Verification

```bash
cd apps/api && npx tsc --noEmit
```