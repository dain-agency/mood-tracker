---
description: Draft a Gmail email per house style (HTML body, no em dashes, UK spelling). Pass intent as argument, e.g. `/draft polite reminder to katie about the invoice`.
---

# /draft

Draft a Gmail email following DAIN house style.

## Instructions

1. **Invoke the `gmail-drafter` skill** at `~/.claude/skills/gmail-drafter.md` BEFORE doing anything else. This is non-negotiable — the skill encodes the hard rules (HTML body, zero em dashes, UK spelling, semantic markup, concision, ownership tagging) and the pre-flight checklist.
2. **Parse the user's intent from `$ARGUMENTS`.** The argument is free-form: it may name recipients, the topic, the tone, attachments, or any context. Examples:
   - `/draft polite reminder to katie about the invoice`
   - `/draft tina at EOC, recap of payroll call from this morning`
   - `/draft reply to thread 19dcf125ca3c3283 thanking jo for the KPI feedback`
3. **Look up missing email addresses** via `mcp__claude_ai_Gmail__search_threads` if recipients are named but no addresses are given. Don't ask the user — find them.
4. **Apply the gmail-drafter pre-flight checklist** before submitting the draft tool call:
   - HTML body via `htmlBody` (or `contentType: "text/html"`)
   - Em dash scan: zero in subject, body, or plain-text alternative
   - UK spelling scan
   - Concision scan: cut implementation details, tool names, process caveats, preliminary analysis, parked items
   - Ownership tagging where actions arise
   - HTML validity
5. **Use semantic HTML, minimal styling** — `<p>`, `<h3>`, `<ul>`, `<ol>`, `<strong>`, `<table>` for tabular data. No inline `style=`, no colours, no bespoke CSS unless the user explicitly asks for a polished/branded look.
6. **CC convention**: For external stakeholder emails from `hello@dain.agency`, CC `jack.taylor@dain.agency` unless the user says otherwise.
7. **After creating the draft**, report the draft ID and a one-line summary (recipients, subject). Do NOT send — the user reviews drafts in Gmail before sending.

## Argument

$ARGUMENTS
