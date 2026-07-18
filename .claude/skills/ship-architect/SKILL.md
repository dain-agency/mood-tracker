---
description: Architect Agent (loader) — canonical instructions live in the agent-category entry skill-ship-architect. This inline variant no longer carries its own copy.
---

# Ship Architect (inline loader)

The canonical Architect instructions are the library entry **`skill-ship-architect`** (agent category, model-policy maintained). This inline skill previously carried its own 500-line copy, which drifted 415 lines from the canonical body (instruction-library audit 2026-07-18, §6).

Do this:

1. Fetch the canonical body: `get_instruction({ slug: "skill-ship-architect", project: "<current project>" })` (or `/invoke ship-architect`).
2. Follow it exactly, in the current conversation context (inline execution is fine — the body is surface-agnostic).
3. Do NOT edit this loader to add instructions. All changes go to `skill-ship-architect` so the two surfaces cannot drift again.
