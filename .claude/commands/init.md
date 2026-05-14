---
description: Scaffold a new repo from a Forge project config
argument-hint: <target-dir> <config-json-path>
---

# /init -- Repository Initialisation from Forge Config

Scaffolds a complete, buildable repository from a project config JSON file (the same format produced by the Forge wizard). The repo structure -- monorepo with Turbo, single-app, etc. -- is determined by the config's `project.structure` field. After running, `/ship` works immediately in the new repo.

## Input

```
/init <target-dir> <config-json-path>
```

- **target-dir** -- Absolute or relative path where the new repo will be created (must not exist or be empty)
- **config-json-path** -- Path to a JSON file matching the Forge wizard's `config_data` format

Both arguments are required. Parse them from `$ARGUMENTS`.

## Validation

Before invoking the skill, validate:

1. **Two arguments provided** -- If not, print usage and stop.
2. **Config file exists** -- Read the JSON file. If it doesn't exist or isn't valid JSON, stop with an error.
3. **Config has required sections** -- Must contain at minimum:
   - `project.name` (string)
   - `project.type` (string)
   - `techStack` (object with at least one of `frontend` or `backend`)
   - `context` (object) -- may be empty, but must exist
4. **Target directory** -- If it exists, it must be empty. If it doesn't exist, that's fine (the skill creates it).
5. **Multi-repo warning** -- If `project.structure` is `multi-repo`, print a notice.

## Normalisation

The Forge wizard produces a deeply nested config with 200+ fields. The `repo-init` skill expects a flatter structure. Before showing the confirmation, detect and transform the wizard format to the skill format.

### Detection

Check for wizard format markers -- if ANY of these exist, the config needs normalisation:
- `project.repo.structure` exists (skill expects `project.structure`)
- `techStack.backend.apiStyle` exists (skill expects `techStack.apiStyle`)
- `brand.icons` exists (skill expects `brand.iconSet`)
- `brand.palette` exists (skill expects `brand.primaryColour`)
- `tenancy.model` exists (skill expects `tenancy.strategy`)
- `locale.dateDisplay` exists (skill expects `locale.dateFormat`)
- `techStack.frontend.forms` exists (skill expects `techStack.frontend.formLibrary`)

### Field Mapping

Transform wizard paths to skill paths. Only extract fields the skill actually consumes -- everything else goes to `_wizardExtras`.

Key mappings:
- `project.repo.structure` -> `project.structure`
- `techStack.backend.apiStyle` -> `techStack.apiStyle`
- `techStack.backend.orm` -> `techStack.orm`
- `techStack.database.primaryDb` -> `techStack.database`
- `brand.icons` -> `brand.iconSet`
- `brand.palette.primary` -> `brand.primaryColour`
- `brand.borderRadius` -> `brand.radius` (convert preset to CSS value)
- `tenancy.model` -> `tenancy.strategy`
- `locale.dateDisplay` -> `locale.dateFormat`
- `locale.currencyCode` -> `locale.currency`
- `locale.displayTimezone` -> `locale.timezone`

### Border radius conversion

| Wizard value | CSS value |
|-------------|----------|
| `none` | `0` |
| `sm` | `0.25rem` |
| `md` | `0.375rem` |
| `lg` | `0.5rem` |
| `full` | `9999px` |

## Confirmation

Before invoking the skill, print a summary for the user to review with project name, type, structure, tech stack details, domain count, and sections to generate.

Ask `Proceed with scaffold? (y/n)` -- stop on `n`.

## Execution

Invoke the `repo-init` skill with the target directory and parsed JSON config.

## Output

When the skill completes, print a summary with next steps:
```
cd <target-dir>
npm run dev          # Start development servers
/ship <feature>      # Build your first feature
```