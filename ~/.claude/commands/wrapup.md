# Session Wrapup

Capture everything from the current session into the DainOS developer tables: changelog, session context, and dev knowledge base.

## Usage

```
/wrapup
```

## Instructions

Use Supabase MCP, project ID `nkwxprrhkifxoeqwvnpu`. All tables are in the `developer` schema.

Determine current project name from CLAUDE.md or repo name (e.g. 'eoc-edna', 'dain-os', 'mabel').

### Step 1: Gather session data

1. **Commits**: `git log --since="midnight" --all --reverse --format="%H|%s|%an|%aI" --no-merges`. For each, get stats with `git show --stat --format="" <sha> | tail -1`. Exclude merge commits and duplicate cherry-picks.
2. **Files touched**: `git diff --name-only` against today's first commit.
3. **Conversation context**: Decisions made, blockers, tasks completed, gotchas/lessons.

### Step 2: Insert changelog entries

**Table: `developer.changelog`** — required fields: project, commit_sha (40 chars), branch, commit_type (feat/fix/chore/refactor/test/docs/perf/ci/build/revert/style), summary, impacts_config, breaking_change, committed_at (ISO 8601). Optional: scope, description, files_changed, insertions, deletions, milestone, task_ref, tags, author, pr_number, pr_url.

Parse commit_type from conventional commit prefix. Insert in batches of 15-20 rows.

### Step 3: Insert session context

**Table: `developer.session_context`** — required: project, session_name, session_date (YYYY-MM-DD), operator, summary. Optional: machine, duration_minutes, decisions_made (jsonb array of {decision, reason}), files_touched (text[]), tasks_completed (text[]), blockers (text[]), handoff_notes, tags.

Focus summary on WHAT was accomplished and WHY, not play-by-play. Decisions capture non-obvious choices.

### Step 4: Insert dev knowledge base entries

**Table: `developer.dev_knowledge_base`** — required: project, category (gotcha/pattern/lesson/decision/workaround), module, title, description, source_type (fix_commit/pr_comment/pr_review/code_review/ai_conversation/incident/documentation/debugging_session). Optional: impact, prevention, severity (critical/high/medium/low), source_refs, tags, platform.

Only add entries for things that were **surprising, non-obvious, or caused real problems**. Check for duplicates first via ILIKE on title.

### Step 5: Summary

```
Session wrapup complete:
- X changelog entries
- 1 session context record
- Y knowledge base entries

Key handoff: [one sentence]
```
