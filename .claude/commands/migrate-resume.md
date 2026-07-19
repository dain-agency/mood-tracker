---
description: Resume a migration from where the last session left off. Reloads the manifest, checks for regressions, and presents the work queue.
argument-hint: [domain-name]
---

# Resume Migration: $ARGUMENTS

Resume the migration of domain `$ARGUMENTS` from where the last session left off.

## Step 1: Load State

### 1a. Authenticate with the API
```bash
source scripts/migrate-auth.sh
```

### 1b. Try to pull latest from API
Search for the migration by domain name:
```bash
curl -s -H "Authorization: Bearer $MIGRATION_API_TOKEN" \
  "$MIGRATION_API_URL/api/v1/forge/migrations?search=$ARGUMENTS"
```

If found, export the latest state:
```bash
curl -s -H "Authorization: Bearer $MIGRATION_API_TOKEN" \
  "$MIGRATION_API_URL/api/v1/forge/migrations/<ID>/export" \
  | python3 -m json.tool > docs/migrations/$ARGUMENTS-manifest.json
```

Save the migration ID for later sync calls.

### 1c. Fall back to local manifest
If the API is unreachable or the migration isn't found in the API, read `docs/migrations/$ARGUMENTS-manifest.json`.

If it doesn't exist → "No migration manifest found. Run `/migrate-app $ARGUMENTS` to start a new migration."

Check `meta.schemaVersion`. If version 1 → "This manifest uses v1 schema. Run `/migrate-decompose $ARGUMENTS` to upgrade it with feature-level tracking."

## Step 2: Quick Verification

For features with `status: "done"` or `status: "in-progress"`, run their `verificationCriteria` checks:

- `grep-in-file` → search for pattern in target file
- `file-exists` → check target file exists
- `export-exists` → check export declaration exists

Skip slow checks (`tsc-clean`, `vitest-pass`) during quick verification — those run in full `/migrate-verify`.

Update `passed` and `lastCheckedAt` on each criterion.

Flag any REGRESSIONS (done features with now-failing criteria) — these need immediate attention.

## Step 3: Report Current State

Print:

```
=== Migration Resume: $ARGUMENTS ===
Last session: {meta.lastVerifiedAt or "unknown"}

PHASE GATES:
  1. Analysis:          {status}
  2. Decomposition:     {status}
  3. Database:          {status}
  4. Backend:           {status}
  5. Frontend Scaffold: {status}
  6. Frontend Features: {status}
  7. Verification:      {status}

FEATURES:
  Total:       {totalFeatures}
  Done:        {done + verified} ({completionPercent}%)
  In Progress: {in-progress}
  Not Started: {not-started}
  Deferred:    {deferred}

BY PRIORITY:
  P0: {completed}/{total}  P1: {completed}/{total}  P2: {completed}/{total}  P3: {completed}/{total}
```

If regressions were detected:
```
REGRESSIONS DETECTED ({count}):
  x {feature-id} — {check} FAILED — was "done", needs re-implementation
```

## Step 4: Present Work Queue

Show unblocked, not-started features sorted by priority (highest first), then by dependency order:

```
WORK QUEUE:
  1. [{priority}] {feature-id} — {name} ({complexityEstimate})
     Source: {sourceRefs[0].file}:{sourceRefs[0].lineRange}
  2. [{priority}] {feature-id} — {name} ({complexityEstimate})
     Source: {sourceRefs[0].file}:{sourceRefs[0].lineRange}
  ...

BLOCKED ({count} features waiting on dependencies):
  - {feature-id} — blocked by: {dependency-ids}
```

A feature is "unblocked" when all entries in its `dependencies[]` array have `status` of `"done"`, `"verified"`, or `"n/a"`.

## Step 5: Begin Feature Implementation Loop

Work through the queue in order. For each feature:

1. **Read the manifest** and select the next unblocked, not-started feature (or continue an in-progress one)
2. **Update status** to `"in-progress"` in the manifest, save immediately
3. **Read the source** — open each `sourceRefs` entry and study the original implementation
4. **Implement** in the `targetRefs` location, following DainOS patterns:
   - shadcn/ui components, HugeIcons, React Query
   - Proper TypeScript types (no `any`)
   - Follow existing patterns in the target codebase
5. **Run verification criteria** for this feature
6. **Update status** to `"done"` if all criteria pass, save manifest
7. **Add sessionLog entry**: `{ "date": "<now>", "action": "Implemented: brief description" }`
8. **Move to next feature**

### Session Discipline

- **At the start of each feature**: Update manifest status to `in-progress`
- **After completing each feature**: Update manifest status to `done` and save
- **After every manifest save**: Sync to API: `bash scripts/migrate-sync.sh <MIGRATION_ID> docs/migrations/$ARGUMENTS-manifest.json`
- **Before ending the session**: ALWAYS save the manifest with current state and sync to API
- **If context is getting large**: Save manifest, sync to API, add a sessionLog note about where you stopped, and suggest the user runs `/migrate-resume $ARGUMENTS` in a new session

### When to Stop

- When all features in the current priority tier are complete
- When the context window is getting full (>70% used)
- When blocked on an external dependency (add `blockedBy` note to the feature)

After stopping, always print:
```
SESSION END — Progress saved to manifest.
  Completed this session: {count} features
  Remaining: {not-started count} not-started, {in-progress count} in-progress
  Next: /migrate-resume $ARGUMENTS
```
