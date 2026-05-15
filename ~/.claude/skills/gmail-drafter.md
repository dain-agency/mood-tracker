---
name: gmail-drafter
description: Use whenever drafting or creating a Gmail email, whether a new email or a reply. Enforces the user's hard rules on email formatting (HTML body, no em dashes, UK spelling). Invoke BEFORE calling any Gmail draft-creation tool.
---

# Gmail Drafter

Every email draft must follow three hard rules. Non-negotiable.

## The three rules

### 1. Always use HTML body, never plain text

Pass body as HTML via `htmlBody` parameter (or `contentType: "text/html"`). Optional plain-text alternative in `body` field.

Semantic markup:
- `<h3>` for section headings (not h1/h2)
- `<ul>` + `<li>` for bullets
- `<strong>` for emphasis on labels/key figures
- `<p>` for paragraphs
- `<a href="...">link text</a>` for links; escape `&` as `&amp;`
- `<br>` only for genuine soft line breaks

Minimal styling. No inline `style=`, no `<font>`, no colours, no CSS unless user explicitly asks.

### 2. Never use em dashes

The em dash is U+2014 (long). Zero allowed in subject, body, signature, or quoted text you author.

Replace with, in order:
1. A comma if clause fits naturally
2. Parentheses for asides
3. A colon for lead-ins
4. An en dash (U+2013) for ranges or compound modifiers
5. A hyphen for short bullet asides

En dash is allowed. Re-read every dash before submitting.

### 3. Always UK spelling

British English throughout. Substitutions:
- favourable, colour, behaviour, honour, neighbour
- organisation, realise, recognise, optimise, analyse, prioritise
- programme (TV/project), centre, theatre, metre, litre
- licence (noun) / license (verb)
- defence, offence, pretence
- catalogue, dialogue, analogue
- travelled, cancelled, labelled, modelled, focused
- whilst, amongst, maths, grey, kerb, tyre
- learnt, spelt, burnt, dreamt

Style: dates `13 April 2026`; currency `GBP485,649`; single quotes for terms, double for direct speech; Oxford comma optional (default omit).

## Structure and concision

Cut anything recipient doesn't care about: implementation details, tool names, process caveats, preliminary analysis, parked items, coupled-action framing.

Prefer specific ownership: name the individual owner (not the team), call out explicit dependencies, @mention people via mailto anchors:

```html
<a href="mailto:louise.ashley@eachothercare.co.uk">@Louise Ashley</a>
```

Phrasing: prefer action-oriented over hedged. "Shout if I have missed anything." is preferred sign-off line for recap emails.

### CC convention

For external stakeholder emails from `hello@dain.agency`, CC `jack.taylor@dain.agency`.

## Pre-flight checklist

Before submitting draft-creation tool call:

1. **Body format**: htmlBody or contentType: text/html? If not, switch.
2. **Em dash scan**: zero in subject, body, plain-text alternative
3. **UK spelling scan**: re-read for -ize, -or, -er (for -re words), -ense (for -ence words)
4. **Concision scan**: cut implementation details, tool names, process caveats, parked items
5. **Ownership tagging**: each new action has a named owner; consider mailto @Name
6. **HTML validity**: closed tags, escaped ampersands
7. **Recipients**: to/cc take bare emails only (no `Name <email>` format). @Name mentions go inside the body as mailto anchors.

## Common tool calls

### mcp__claude_ai_Gmail__create_draft

```
to=["recipient@example.com"]
cc=["cc@example.com"]
subject="Subject with no em dash"
htmlBody="<p>Hi all,</p><h3>Headline</h3><ul><li>...</li></ul>"
body="Plain-text fallback"  # optional
```

### mcp__Gmail__gmail_create_draft

Recipients as comma-separated string, `body` with `contentType="text/html"`.

### Reply in thread

Use `threadId` (on `mcp__Gmail__gmail_create_draft`). Subject auto-derived. Pre-flight checklist still applies.

## When this skill does not apply

- User asking about email content conceptually (not yet asking for a draft)
- User explicitly asks for plain text, or allows em dashes / US spelling for a specific message. Confirm override is intentional before applying.
