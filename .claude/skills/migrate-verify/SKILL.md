---
description: Verify a migration manifest against actual code. Reports what is truly complete vs what the manifest claims. Run at any time during a migration.
argument-hint: [domain-name]
---

# Migration Verification: $ARGUMENTS

Verify the migration of domain `$ARGUMENTS` by checking every feature''s verification criteria against the actual codebase. This is Phase 7 of the migration lifecycle but can be run at any point to check progress.

## Step 1: Load Manifest

Read `docs/migrations/$ARGUMENTS-manifest.json`. Verify `meta.schemaVersion` is 2.

If the manifest doesn''t exist, stop and report: "No manifest found. Run `/migrate-analyze` first."

## Step 2: Run Verification Checks

For each feature where `status` is `"done"`, `"in-progress"`, or `"verified"`, execute each entry in its `verificationCriteria` array.

### Check Execution

| Type | How to Execute | Pass Condition |
|------|---------------|----------------|
| `file-exists` | Check that the file at `check` path exists | File exists |
| `grep-in-file` | Search for regex `check` in `file` using Grep tool | At least one match |
| `grep-not-in-file` | Search for regex `check` in `file` using Grep tool | Zero matches |
| `export-exists` | Search for export in `file` | At least one match |
| `line-count-min` | Count lines in `file` | Line count >= parseInt(`check`) |
| `test-file-exists` | Derive test path from `file` | File exists |
| `story-file-exists` | Derive story path from `file` | File exists |
| `tsc-clean` | Run tsc --noEmit in `check` directory | Exit code 0 |
| `vitest-pass` | Run vitest on `file` | Exit code 0 |
| `manual` | Cannot be automated | Skip as manual-pending |

### For Each Check

1. Execute the check
2. Set `passed: true` or `passed: false` on the criterion object
3. Set `lastCheckedAt` to current ISO timestamp

## Step 3: Classify Results

- **REGRESSIONS**: Features with done/verified status but failing criteria
- **UNDOCUMENTED COMPLETIONS**: Not-started features with all criteria passing
- **PROMOTIONS**: Done features with all criteria passing — promote to verified
- **PARTIAL PROGRESS**: In-progress features — report pass/fail counts

## Step 4: Recompute Summary

Update totalFeatures, byStatus, byPriority, completionPercent, verifiedPercent.

## Step 5: Check Phase 7 Gate

All P0/P1 done or verified, verifiedPercent >= 95% for P0-P2, no regressions, tsc clean.

## Step 6: Update Manifest

Write updated manifest with verification results, promotions, regressions, and session log entries.

## Step 7: Print Report

Structured report with summary, regressions, promotions, undocumented completions, partial progress, and next work items.
