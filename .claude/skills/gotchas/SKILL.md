---
name: gotchas
description: >
  Project gotchas reference — curated index of known pitfalls. Use before writing code
  (builders check relevant sections), during review (reviewers verify gotchas weren't introduced),
  and during planning (plan writer tags tasks with relevant gotchas).
user-invocable: true
disable-model-invocation: false
---

# Gotchas — Section-Aware Reference

`docs/gotchas/GOTCHAS.md` contains hard-won knowledge from production debugging. Do NOT load the entire file. Each section is marked with `<!-- ANCHOR: id -->` comments for stable lookup.

## How to Load a Section

Use `Grep` to find the anchor, then `Read` from that line:

```
1. Grep for "ANCHOR: <id>" in docs/gotchas/GOTCHAS.md to get the line number
2. Read(file_path="docs/gotchas/GOTCHAS.md", offset=<line>, limit=40)
```

## Pre-Build Checklist

**Before writing or modifying code**, scan this checklist. If any item applies, load the relevant GOTCHAS.md section and follow the documented pattern.

### Frontend

| Writing code that... | Check this rule | Anchor |
|---|---|---|
| Uses {{component_library}} components | Check default width/padding behaviour | `component-defaults` |
| Imports an icon | Use {{icon_library}} only | `icon-library` |
| Renders a select/dropdown for an entity ID | Use combobox component for lookups | `combobox-for-lookups` |
| Writes any user-facing text | Check spelling conventions | `spelling-conventions` |
| Manages server state (fetching, caching) | Use {{data_fetching_library}}, not useState+useEffect | `server-state-management` |

### Backend

| Writing code that... | Check this rule | Anchor |
|---|---|---|
| Queries the database | Always use tenant-scoped queries | `tenant-isolation` |
| Accepts user input (POST/PATCH/PUT) | Zod schema validation required on every route | `zod-validation-required` |

## Ship Pipeline Integration

### For Plan Writers

When creating task specs, scan this index and add a `gotchas` array to any task where checklist items apply.

### For Builders

If your task spec includes `gotchas`, read those sections before writing code.

### For Reviewers

After reviewing code quality, cross-reference the task's `gotchas` list against the implementation.

## When You Discover a New Gotcha

Add it to `docs/gotchas/GOTCHAS.md` with an anchor comment, then update this skill index.