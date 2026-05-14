---
description: Analyse a source app for migration. Outputs a v2 migration manifest with tech stack, data models, API surface, UI components, and source file inventory.
argument-hint: [source-app-path]
---

# Migration Analysis: $ARGUMENTS

Analyse the source application at `$ARGUMENTS` and produce a v2 migration manifest. This is Phase 1 of the 7-phase migration lifecycle.

## Step 1: Discover Source Structure

Scan for all source files (TypeScript, Prisma, SQL).

## Step 2: Tech Stack Detection

Read `package.json` and identify framework, database, auth, state management, UI library, form/validation libraries.

## Step 3: Data Model Extraction

Find Prisma schemas, migrations, TypeScript interfaces, Zod schemas. Capture entities with fields, types, relationships, indexes, constraints.

## Step 4: API Surface Mapping

Find all API routes. For each: method, path, request body shape, response shape, purpose.

## Step 5: UI Component Inventory

Catalogue pages, forms, tables, wizards, modals, custom components, preview components.

## Step 6: Source File Inventory

For every source file: count lines, classify type, note significant patterns.

## Step 7: Output v2 Migration Manifest

Save to `docs/migrations/{domain}-manifest.json` with meta, sourceInventory, entities, apiEndpoints, features, phaseGates, summary.

## Step 8: Gate Check

Verify Phase 1 criteria:
- sourceInventory.files populated
- techStack filled in
- apiEndpoints lists all routes
- entities lists all models

## Step 9: Print Summary and Next Steps

Report source stats and direct to Phase 2 (Decomposition).