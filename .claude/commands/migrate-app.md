---
description: Migrate an external app into the project as a new domain. 7-phase lifecycle with feature-level tracking.
argument-hint: [source-app-path] [domain-name]
---

# App Migration: $ARGUMENTS

Migrate the source application into the project as a new domain using the 7-phase lifecycle.

**Parse arguments:** Extract `source-app-path` and `domain-name` from `$ARGUMENTS`.

---

## Phase 1: Analyse Source

Use the `migrate-analyze` skill pattern:

1. Read source `package.json` for tech stack
2. Find all source files -- count lines per file
3. Map data models ({{orm}}/types/interfaces)
4. Catalogue API endpoints
5. List UI components and pages
6. Build `sourceInventory` with every file + line count
7. Document dependencies and external services

**Output:** v2 migration manifest saved to `docs/migrations/{domain-name}-manifest.json`

### Gate Check
- [ ] `sourceInventory.files` populated with all source files
- [ ] `sourceInventory.totalSourceLines` > 0
- [ ] `meta.techStack` filled in
- [ ] `apiEndpoints` lists all source routes
- [ ] `entities` lists all data models
- [ ] `phaseGates.analysis.status = "passed"`

---

## Phase 2: Decompose Features (CRITICAL)

Use the `migrate-decompose` skill pattern.

**This phase MUST complete before writing any code.** It enumerates every feature in the source at granular level so nothing is lost across sessions.

1. Read every source file in the inventory
2. Identify every distinct feature
3. Create a feature entry with: id, sourceRefs, targetRefs, verificationCriteria, dependencies, complexityEstimate
4. Auto-detect already-migrated features if target files exist
5. Present the full feature list to the user for review

### Gate Check
- [ ] Every source file has at least one `featureId` reference
- [ ] No feature has `complexityEstimate: "xl"` -- all decomposed to <= `large`
- [ ] Every feature has at least one `verificationCriteria` entry
- [ ] User has reviewed and confirmed the decomposition

**STOP HERE if the user wants to review before coding begins.**

---

## Phase 3: Database Schema

Use the `migrate-database` skill pattern:

1. Add schema namespace to database
2. Create models with tenant isolation
3. Register in `TENANT_SCOPED_MODELS`
4. Run `npx {{orm}} generate`
5. Update `data-model` feature statuses in manifest

### Gate Check
- [ ] All `data-model` features: `done` or `verified`
- [ ] `{{orm}} generate` succeeds
- [ ] Models in `TENANT_SCOPED_MODELS`
- [ ] `cd apps/api && npx tsc --noEmit` passes

---

## Phase 4: Backend Scaffold

Use the `migrate-backend` skill pattern:

1. Create domain directory structure
2. Port types/schemas (add Zod validation)
3. Create route factory with middleware chain
4. Create controllers with validation
5. Create services with tenant-scoped queries
6. Register routes

### Gate Check
- [ ] All `api-route` features: `done` or `verified`
- [ ] Route factory registered
- [ ] `cd apps/api && npx tsc --noEmit` passes

---

## Phase 5: Frontend Scaffold

Use the `migrate-frontend` skill pattern (scaffold only):

1. Create domain directory
2. Create API client
3. Create data-fetching hooks
4. Create types
5. Create basic page routes
6. Add to sidebar navigation

**Do NOT implement feature-rich components yet** -- that happens in Phase 6.

### Gate Check
- [ ] Domain directory exists
- [ ] Types, API client, and hooks created
- [ ] `cd apps/web && npx tsc --noEmit` passes

---

## Phase 6: Frontend Features (Iterative)

Use the `migrate-frontend` skill's manifest-driven feature loop.

This phase works through features in priority order. **It may span multiple sessions.**

### Per-Feature Loop
1. Read manifest -> find next unblocked, not-started feature
2. Set status to `"in-progress"`, save manifest
3. Read source at `sourceRefs` line ranges
4. Implement following project patterns
5. Run `verificationCriteria` checks
6. Set status to `"done"` if all pass
7. Move to next feature

### Session End Protocol
Save manifest, print progress summary, print: `To continue: /migrate-resume {domain-name}`

---

## Phase 7: Verification

Use the `migrate-verify` skill:

1. Run ALL verification criteria for ALL `done`/`verified` features
2. Promote `done` -> `verified` where all criteria pass
3. Flag regressions
4. Compute final summary
5. Create domain README

---

## Post-Migration Checklist

- [ ] All source endpoints mapped to project API
- [ ] All data models have tenant isolation
- [ ] UI uses {{component_library}} components (no custom primitives)
- [ ] Icons use {{icon_library}}
- [ ] Server state uses data-fetching hooks (not client stores)
- [ ] Forms use react-hook-form + zod
- [ ] Tests exist for all components and services
- [ ] Sidebar navigation updated
- [ ] Domain README written
- [ ] typescript compiles cleanly
- [ ] Migration manifest shows all features as `done` or `verified`

---

## Multi-Session Continuity

If a session ends before the migration is complete:

```
SESSION END -- Progress saved.
  Phase: {current phase}
  Features: {done}/{total} ({percent}%)
  Remaining: {not-started} not-started, {in-progress} in-progress

  To continue in a new session:
  /migrate-resume {domain-name}
```

The `migrate-resume` command reloads the manifest, runs quick verification, shows the work queue, and continues the feature loop.