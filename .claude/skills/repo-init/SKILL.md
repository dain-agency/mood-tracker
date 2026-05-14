---
description: Scaffold a complete repo from a Forge project config
argument-hint: <target-dir> <config-json-path>
---

# Repo Init Skill

Reads a Forge project config and scaffolds a complete, buildable repository. The repo structure (monorepo with Turbo, single-app, etc.) is determined by the config's `project.structure` field. Config-driven — sections present get scaffolded, sections absent get skipped.

## Inputs

You receive two inputs from the `/init` command:
1. **Target directory** — absolute path where the repo will be created
2. **Project config** — parsed JSON matching the Forge wizard's `config_data` format

## Config-Driven Principle

**CRITICAL:** Every technology choice must come from the config, not from assumptions. The Forge wizard allows users to pick from many options. Before generating any file, check the relevant config field.

## Process

### 1. Parse Config
Read the project config and extract all technology decisions.

### 2. Create Directory Structure
Based on `project.structure` (monorepo, single-app, etc.), create the appropriate directory layout.

### 3. Generate Package Files
Create `package.json` with correct dependencies for the chosen stack.

### 4. Generate Config Files
Create framework configs (nextjs.config.ts, tailwind.config.ts, etc.).

### 5. Generate Boilerplate
Create initial pages, layouts, providers, and utility files.

### 6. Generate Claude Config
Create `.claude/` directory with skills, templates, and settings.

### 7. Generate CLAUDE.md
Create root CLAUDE.md with project-specific instructions.

### 8. Git Init
Initialise git repo with `.gitignore` and initial commit.

### 9. Install Dependencies
Run package manager install.

### 10. Verify
Run initial build/type check to verify the scaffold works.