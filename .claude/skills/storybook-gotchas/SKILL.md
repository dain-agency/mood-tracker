---
name: storybook-gotchas
description: >
  Storybook gotchas — auto-invoked when writing .stories.tsx files, Storybook config,
  or debugging Storybook rendering issues. Lightweight index pointing to docs/gotchas/GOTCHAS.md.
user-invocable: true
disable-model-invocation: false
---

# Storybook Gotchas — Quick Reference

Before writing Storybook stories, debugging story rendering, or configuring Storybook, scan this checklist. If an item applies, load the full section from `docs/gotchas/GOTCHAS.md` using:
```
Grep "ANCHOR: <id>" in docs/gotchas/GOTCHAS.md → Read from that line, limit=30
```

## Loading & Performance

| When you... | Gotcha | Anchor |
|---|---|---|
| See spinner that never resolves on first load | Vite pre-bundling takes 30-60s on first load with 700+ stories. Wait or clear caches. | `storybook-first-load-hang` |
| Use `file:` linked monorepo packages | Transitive dependencies resolve from linked package's node_modules, not the project's. Blank iframe, no errors. | `storybook-file-link-deps` |

## Data Table Stories

| When you... | Gotcha | Anchor |
|---|---|---|
| Demo a table with `pagination: 'server'` | Client-side sorting/filtering are disabled by design. Use `'none'` or `'client'` for sample data. | `storybook-server-pagination-sorting` |
| Enable filtering but no filter buttons appear | Columns need `meta: { variant: 'select' }` to render faceted filters. Flag alone is not enough. | `storybook-column-filter-meta` |
| Change density via Storybook controls | Initial-value state doesn't sync with prop changes. Fixed in MasterTable; watch for same pattern elsewhere. | `storybook-density-sync` |

## Testing & Vitest Integration

| When you... | Gotcha | Anchor |
|---|---|---|
| Archetype/composition stories fail in vitest | Inline render functions cause NoRenderFunctionError. Add `!vitest` tag to meta AND configure/disable the storybookTest plugin in vitest.config.ts. Tag alone is not enough. | `storybook-vitest-no-render` |
| Use Next.js navigation hooks in stories | useRouter/useSearchParams crash without router context. Wrap in try-catch; pass `urlSync: false`. | `nextjs-hooks-storybook-crash` |
| Use TanStack Table column defs in stories | Cast columns to `ColumnDef<T, unknown>[]` to fix generic variance. | `tanstack-table-columndef-variance` |
