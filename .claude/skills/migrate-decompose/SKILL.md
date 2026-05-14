---
description: Decompose a migration manifest into granular, trackable features with verification criteria. Run AFTER migrate-analyze, BEFORE any coding.
argument-hint: [domain-name]
---

# Migration Decomposition: $ARGUMENTS

Decompose the source application into granular, independently-trackable features. This is Phase 2 of the 7-phase migration lifecycle.

## Why This Phase Exists

Without decomposition, a 580-line source file gets tracked as one item. It compiles, so it looks "done" — but 60% of its features are missing.

## Step 1: Load Manifest

Verify `phaseGates.analysis.status` is `"passed"`.

## Step 2: Read Every Source File

For each file, identify every distinct feature: cards/sections, dynamic field arrays, conditional sections, API interactions, reusable sub-components, form field groups, state machines, utility functions, data files.

### Decomposition Rules

1. One feature = 30 minutes to 4 hours of work
2. No `complexityEstimate: "xl"` — split further
3. Every feature needs machine-checkable `verificationCriteria`
4. Source references must include line ranges
5. Dependencies must be explicit
6. Form steps with validation schemas require per-field verification

## Step 3: Create Feature Entries

Each feature gets: id, name, category, priority, status, complexityEstimate, sourceRefs, targetRefs, verificationCriteria, dependencies, sessionLog.

## Step 4: Auto-Detect Already-Migrated Features

Run verification criteria against current target files. Auto-set status for already-done features.

## Step 5: Update Source File References

Every source file must have at least one feature reference.

## Step 6: Compute Summary

Calculate totals by status and priority.

## Step 7: Gate Check

All source files have featureIds. No xl complexity. Every feature has verification criteria.

## Step 8: Save and Print Work Queue

Sorted by priority then dependencies.