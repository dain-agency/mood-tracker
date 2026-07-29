# Recipe Card — plan → assemble → verify

Every unit of work — domain, module, feature, adapter, view type, or fix — gets a recipe card BEFORE building starts. An agent drafts it from the brief + `rule-package-map`; Dane + Jack approve it (this IS the per-package decision sheet, generalised to all unit types). The build queue does not pick up work without an approved card. On completion, the card is the proof.

**The core contract:** "done" may only be claimed when every clause of the brief is traced to a passing, machine-checkable verification. Verification proves the build matches the CARD; the approval step is what makes the card match the BRIEF. Ambiguity discovered mid-build is never interpreted silently — reversible calls: decide, log, continue; irreversible: mark blocked (per Decision Ledger).

---

## 1 · Header
- **Card id / version** · **Unit type**: domain | module | feature | adapter | view-type | fix
- **Source**: task/requirement link · requester · date
- **Status**: draft → approved → in-build → verified → shipped
- **Approvals**: Dane ☐ Jack ☐ (required before in-build)

## 2 · The brief
- **Verbatim ask** — the client's/requester's words, unedited.
- **Interpretation** — 1–3 sentences restating it in platform vocabulary. If interpretation adds ANY assumption, list each one explicitly for approval.

## 3 · Ingredients (placements must cite rule-package-map)
| Use | Item | Version | For |
|---|---|---|---|
| **Reuse as-is** | package/folder | @ver | what it provides here |
| **Configure** | Engine artifact (collection/view/automation/form) | — | shipped as config, no release |
| **Extend** | plugin/adapter + its home folder | — | why extension not config |
| **Build new** | (rare) | — | why nothing existing fits + demand evidence |
- **Explicitly NOT used / out of scope** — the fence against scope creep and wrong-layer builds.

## 4 · Assembly
- Ordered steps, each naming the folder it touches.
- **Semantic owners**: any cross-cutting concept → its owner named from the registry (new concept ⇒ propose owner here, needs approval).
- **Contracts & events**: consumed / emitted, with owning folder.
- **Data**: schemas/migrations touched; migration + rollback required if any.
- **One-way doors**: anything irreversible (contracts, audit shape, npm names, regulated semantics) flagged for human sign-off ☐.

## 5 · Verification — the checklist that makes "done" mean done
**A. Machine gates (all must be green):**
- ☐ Types, lint, **import-boundary** checks pass
- ☐ Unit + contract tests green; conformance fixtures pass
- ☐ Invariant suite: tenant isolation · audit append-only · statutory windows (where touched)
- ☐ Migration dry-run + rollback rehearsed (if schema touched)
- ☐ Simulated run: named twin scenario(s) with expected outcomes, e.g. "missed-dose fires, ack within SLA, escalation on timeout" — all pass
- ☐ Security check #24 (secrets, injection incl. CSV prefix, authz) — required for anything promoted to a shared package

**B. Spec-trace table (the heart of the card):**
| # | Brief clause | Verified by (test/fixture/scenario id) | Status |
|---|---|---|---|
Every clause gets a row. A clause with no machine-checkable verification must be either rewritten until it has one, or explicitly marked **HUMAN-JUDGEMENT** with Dane/Jack named as its verifier. No row may be empty.

**C. Human gates:** the specific items from §4 one-way doors + anything on the agent red-lines list.

**D. Evidence bundle (attached on completion):** test-run links · fixture results · screenshots/recording of the working feature · changelog entries · **exact package versions used** (Dain Bench provenance).

## 6 · Report-back (the only permitted completion formats)
- **DONE & VERIFIED** — "N/N brief clauses traced to passing checks. Deviations: none. Evidence: [bundle]." Only claimable when every §5B row is green and §5A is fully green.
- **DONE WITH EXCEPTIONS** — same format, listing each non-green row and why. Never dressed up as verified.
- **BLOCKED** — the clause/decision, the options, a recommendation.

Honesty rule: "verified against the spec" is a claim about the spec-trace table, nothing softer. If the table is green and the card was approved, the chain brief → card → checks → build is closed — that is what certainty means here.
