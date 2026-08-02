# Config Framework — one manifest, package-owned sections, layered resolution

Load with `rule-package-map`. Every new config key must answer five questions before it exists: **which section owns it · which plane it belongs to · which scopes it can be set at · which governance tier it carries · what its default and bounds are.** Recipe cards must declare these for any new key.

## 1 · Three planes (never conflate their lifecycles)

| Plane | What | Where it lives | Lifecycle |
|---|---|---|---|
| **Build-time** | lint, TS settings (toolchain) | files in repo | code review; never at runtime |
| **Runtime settings** (the manifest) | auth methods, providers, escalation windows, themes, flags | config store, cached at edge | edited per governance tier below |
| **Config-as-product** (Engine schema packs) | collections, views, automations, forms | versioned pack artifacts | pack pipeline: version → dry-run ×tenants → approve → staged rollout → verify → rollback path |

Soft fourth plane: **user preferences** (density, quiet hours) — self-serve, no review, audit only.

A theme tweak and a schema-pack release must never share a review process. If you're unsure which plane a key belongs to: does it tune behaviour (manifest) or IS it the product (pack)?

## 2 · Ownership — sections follow the semantic-owner rule

The manifest is ONE logical document per tenant; each section's **schema is owned by the consuming package** (Zod, composed into the manifest schema at build time):

- `core.*` — kernel owns the envelope + shared primitive types only
- `platform.*` — auth (methods × roles × device class, session policies, PIN/lockout), roles & dataset scopes, SLA defaults, retention & data-protection policy
- `services.*` — per-adapter blocks (sync cadence, webhook secret REFS, field mappings), notification channels & quiet hours, storage buckets, AI model + governance thresholds, monitoring levels
- `ui.*` — density, archetype defaults
- `portal.*` — exposed surfaces, consent model, external session policy
- `engine.*` — installed packs + versions, module flags
- toolchain: **no runtime section**. kernel: **no section of its own beyond core types**.

### Hard rules (lint-checkable)
1. **A package reads only its own section + the shared core.** Cross-section reads are coupling in disguise — if services needs something auth-ish, it calls platform's API.
2. **Kernel reads no config at all.** Zero dependencies includes zero config dependencies; kernel functions take values as arguments.
3. **Secrets are references, never values.** `secretRef: 'camascope/webhook'` resolves via the secrets provider; a literal secret in config fails check #24.

## 3 · The shared core block (deliberately small)

| Key group | Schema owner | Consumers |
|---|---|---|
| tenant identity: name, locale, timezone, residency region | kernel types | everyone |
| theme tokens (brand as data) | ui | ui, portal, notification templates |
| module flags (what's switched on) | engine/manifest core | navigation, provisioning, billing |
| provider SELECTION (m365 vs google, postmark vs ses, supabase vs s3) | services | services (declared centrally: provisioning + procurement read it) |
| retention & data-protection policy | platform | documents, audit, db, portal |
| environment + secret references | platform | everyone |

Everything not in this table is package-specific. When in doubt, it is NOT shared.

## 4 · Resolution — layered, with provenance

Effective value = merge in fixed precedence:
`package defaults (in code)` → `Dain platform defaults` → `tenant manifest` → `site/unit override` → `role` → `user preference`

- Computed once per change, cached at edge, invalidated on write.
- **Every effective value records its source layer** — "why is escalation 20m not 30m?" answers with layer, author, date, diff. Provenance is not optional; it is the audit story for config.
- **Bounds live one level below values**: statutory/regulatory floors are enforced in the plugin/typed property, so config tunes WITHIN limits and can never configure its way out of compliance. A bound violation is a validation error at write time, not a runtime surprise.

## 5 · Governance tiers — per KEY, not per document

Declared in each key's schema:

| Tier | Examples | Process |
|---|---|---|
| **self-serve** | theme, quiet hours, density | edit in UI; audit only |
| **reviewed** | auth methods, automations, adapter settings, module flags | PR-style diff, one approval |
| **countersigned** | retention, dataset scopes, anything RLS-adjacent or regulated-semantic | Dane + Jack, both |

Rigour attaches to blast radius — the config mirror of code-review asymmetry. "Config is production change" applies to WHAT the key controls, not to the fact that it's config.

## 6 · The agent's mental model

```ts
const cfg = await config.for(tenant)     // typed, validated
cfg.platform.auth.methods                // own section: allowed
cfg.core.theme                           // shared core: allowed
cfg.services.notifications               // from platform code: LINT ERROR
```

New key checklist (goes in the recipe card):
- [ ] Section + owner named (per this rule)
- [ ] Plane named
- [ ] Scopes it may be set at (tenant / site / role / user)
- [ ] Governance tier
- [ ] Default + bounds (and WHERE the bound is enforced)
- [ ] Provenance visible in the admin surface
