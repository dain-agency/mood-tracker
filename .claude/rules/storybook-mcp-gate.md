# Storybook MCP Gate

**MANDATORY before writing or editing ANY UI component, page, or layout code.**

## When Storybook is running (port 6006)

Before creating or modifying any `.tsx` file in `apps/web/src/` that renders UI:

1. **Query `storybook-mcp` tools first** — call `list-all-documentation` to discover available components
2. **Fetch component details** — call `get-documentation` for any component you intend to use or that might already solve your need
3. **Never recreate existing components** — if Storybook has a component that covers your need, import it. Do not build a new one.
4. **Verify props against documentation** — never guess component props. Use the documented interface.
5. **MCP requires Claude Code restart** — If Storybook was started after Claude Code, the MCP tools won't be available. Restart Claude Code to pick up the connection. Check with `ListMcpResourcesTool` or `ToolSearch` for "storybook" before relying on MCP tools.

## What to query before specific tasks

| Task | Query |
|------|-------|
| Building a page | Query `Pages/*` — they define canonical page patterns |
| Building a table | Query `Organisms/DataTable/*` — MasterTable with presets covers all cases |
| Building a form | Query `Molecules/FormField` and `Molecules/FormCombobox` |
| Building a chart | Query `Organisms/Charts/*` — check which chart type stories exist |
| Building feedback UI | Query `Molecules/EmptyState`, `ErrorState`, `LoadingState`, `ConfirmDialog` |
| Building stats/KPIs | Query `Molecules/StatsCards/*` — 10+ variants exist |
| Building a calendar | Query `Organisms/ScheduleCalendar` |
| Building a wizard | Query `Molecules/WizardDialog` + `Pages/Multi-Step Form` |
| Building a Gantt chart | Query `Organisms/Gantt` |
| Building settings UI | Query `Pages/Settings Shell` and `Organisms/SettingsMembers` |

Domain components do NOT have stories — query `Pages/*` for page composition patterns.

## When Storybook is NOT running

Fall back to reading story files directly:
1. Check `apps/web/src/components/layout/archetypes/*.stories.tsx` for `Pages/*` patterns
2. Check `apps/web/src/components/organisms/**/*.stories.tsx` for complex components
3. Check `apps/web/src/components/composed/*.stories.tsx` for molecules
4. Check `apps/web/src/components/ui/*.stories.tsx` for atoms

## Why this matters

The design system has 100+ stories across atoms, molecules, organisms, and Pages. Rebuilding existing components wastes time, creates inconsistency, and violates design system standards. The MCP server gives live, queryable access to the full component library — use it.
