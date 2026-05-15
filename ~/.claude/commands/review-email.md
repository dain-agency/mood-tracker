---
description: Review a Gmail email and create a worktree/branch to address the work
argument-hint: <email subject line>
---

# Review Email: $ARGUMENTS

**You are reviewing an email to understand what work is being requested, then setting up a workspace to address it.**

## Phase 1: Find and Read the Email

1. Search Gmail using `mcp__claude_ai_Gmail__gmail_search_messages` with the subject. If multiple results, pick the most recent.
2. Read full thread via `gmail_read_thread`.
3. Summarise: From, Date, Subject, 2-3 sentence overview, key details bullet list, attachments flag.

## Phase 1.5: Search for Related Emails

Extract search terms (people, project names, technical terms, ticket numbers). Run up to 3 targeted searches by sender, key topic, and thread participants. Read up to 3 additional relevant matches. Present as a "Related Emails Found" section. Flag contradictions between primary and related emails.

## Phase 2: Analyse the Work

Determine: type of work, areas of codebase affected, scope (small/medium/large), dependencies/blockers, deadline/urgency.

## Phase 3: Create Branch and Worktree

Derive branch name: `feat/<module>-<short-description>`, `fix/<module>-<short-description>`, or `chore/<short-description>`. Under 50 chars, kebab-case. Use the `EnterWorktree` tool.

## Phase 4: Create Notion Task

Use `mcp__claude_ai_Notion__notion-create-pages` with `data_source_id: 22a51000-c589-80d3-b5fd-000b4056315b` (Master Task DB).

Properties to set:
- **Name**: actionable task title (not raw subject)
- **Assignee**: Dane Krambergar
- **Status**: Backlog
- **Category**: pick from list
- **Effort/Impact**: best estimates
- **Tags**: relevant from list
- **Notes**: 2-3 sentence summary with sender + date

Page body has Context, Source (email metadata + branch), Requirements, Open Questions sections.

Output Notion URL and explain Category/Effort/Impact choices.

## Phase 5: Enter Plan Mode

Use `EnterPlanMode`. Present:
- Email Summary
- Proposed Approach (3-5 bullets)
- Clarifying Questions specific to the email and codebase

## Rules

- If `$ARGUMENTS` is empty, ask for the email subject before proceeding
- Do NOT start implementing — purely review/setup/planning
- UK spelling and UK date formats
- Reference specific files/modules when discussing approach
- If email contains sensitive data, flag but don't reproduce verbatim
