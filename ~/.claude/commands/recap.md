# Session Recap

Read the most recent session context, changelog, and knowledge base entries to get up to speed on what happened recently.

## Usage

```
/recap
/recap $ARGUMENTS
```

- `/recap` — auto-detect project, show last 7 days
- `/recap 3d` — show last 3 days
- `/recap 2026-03-23` — show specific date
- `/recap eoc-edna` — show specific project
- `/recap mabel 7d marketing campaigns, custom fields, proposal wireframes` — narrow to a topic
- `/recap sandbox work, campaigns and custom fields` — free-text scope; project + window auto-detected

## Instructions

Use Supabase MCP (project ID `nkwxprrhkifxoeqwvnpu`). All tables are in the `developer` schema.

### Step 1: Determine parameters

Parse `$ARGUMENTS` into three slots. ANY may be omitted; treat the whole string as a free bag of tokens:

- **Project**: known project name in args, otherwise detect from CLAUDE.md or repo name. If ambiguous between two close names, run a COUNT query and pick the one with most recent activity.
- **Lookback**: A duration (`3d`, `1w`, `24h`) or absolute date anywhere in args. Default: 3 days from most recent session.
- **Scope keywords**: Anything leftover after removing project + lookback. Split on spaces/commas/dashes/slashes, lowercase, dedupe, drop stop-words. Keep multi-word phrases AND emit constituent words separately.

### Step 2: Find time window

Query `MAX(session_date)` from `developer.session_context` for the project.

### Step 3: Fetch session context

Select from `developer.session_context` with optional scope clause OR-ing across `tags`, `session_name`, `summary`. Use `tags && ARRAY[...]` for overlap and `ILIKE ANY` for text.

### Step 4: Fetch changelog

Select from `developer.changelog` with same scope clause across `tags`, `scope`, `summary`.

If scope filter is active, mention it in recap header. If filter returns zero results, surface that explicitly and offer to re-run without scope.

### Step 5: Present recap

```
## Recap: <project> (last N days)

### Sessions
**<date>  <session_name>** (<operator>)
<summary>

Decisions:
- <decision>: <reason>

Handoff: <handoff_notes>

---

### Commits (X total)
| Type | Scope | Summary | Branch | PR |
```

Group commits by PR where possible.

### Step 6: Action items

End with open items from handoff_notes or blockers. If none, say "No open items from recent sessions."
