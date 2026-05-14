---
description: Run e2e tests via Chrome browser automation
argument-hint: [optional: scope of changes to test, or 'plan' to generate test plan]
---

# E2E Testing: $ARGUMENTS

## Phase 1: Start Dev Servers

**First, check if servers are already running:**

```bash
api=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/health 2>/dev/null || echo "000")
web=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3002 2>/dev/null || echo "000")
echo "API: $api, Web: $web"
```

- If both return 200/307/302 -> **skip starting servers**, they're already running.
- Otherwise -> start them:

```bash
bash scripts/dev.sh
```

Run this with `run_in_background: true`. The script kills zombie ports and starts both API (:3001) and Web (:3002).

**Wait for servers to be ready** -- poll until response (max 30 seconds):

```bash
for i in $(seq 1 10); do curl -s -o /dev/null -w "%{http_code}" http://localhost:3002 && break; sleep 3; done
```

## Phase 2: Open Chrome and Login

### Step 1: Get browser context
Call `mcp__claude-in-chrome__tabs_context_mcp` to see current browser tabs.

### Step 2: Create a new tab
Call `mcp__claude-in-chrome__tabs_create_mcp` to open a new tab.

### Step 3: Navigate to the app
Call `mcp__claude-in-chrome__navigate` to go to `http://localhost:3002`.

### Step 4: Read test credentials
Read the credentials from the env file safely -- extract only the two variables needed.

**IMPORTANT:** Never output raw .env contents. Only extract `TESTING_EMAIL` and `TESTING_PASSWORD`.

### Step 5: Fill in login form
1. Use `mcp__claude-in-chrome__read_page` to identify the login form fields
2. Fill in the email and password fields
3. Click the sign-in / login button
4. Wait for redirect to the dashboard

## Phase 3: E2E Testing

### If `$ARGUMENTS` is empty -- Interactive mode
After login, inform the user the browser is ready for e2e testing.

### If `$ARGUMENTS` is 'plan' -- Auto-generate test plan from changes

1. Detect recent changes via `git diff main`
2. Map changed files to testable flows
3. Generate a test plan with page URLs, actions, expected outcomes, and persistence verification steps
4. Present the plan for approval before executing
5. Execute approved tests sequentially using Chrome MCP tools

### If `$ARGUMENTS` describes a specific scope
Test the described scope with navigation, interactions, verification, console error checks, and persistence checks.

## Phase 4: Persistence Testing (MANDATORY)

**Every flow that creates, updates, or deletes data MUST include persistence verification.**

### 4.1 Network Request Validation
After every save/create/update/delete action, check network requests for 2xx responses.

### 4.2 Page Reload Verification
After any data-modifying action, reload the page and verify data persists.

### 4.3 Specific Persistence Test Patterns
Apply patterns for form submissions, inline edits, AI-generated content, delete operations, and config/settings changes.

### 4.4 Console Error Check
After every persistence test, check the console for errors.

### 4.5 Database State Verification (when feasible)
For critical flows, verify the database directly.

## Reporting

After all tests complete, provide a summary table with test name, status, persistence result, and notes.

### Failure Classification

| Classification | Meaning | Severity |
|---|---|---|
| RENDER_FAIL | Page doesn't render or shows error | High |
| INTERACTION_FAIL | Button/form doesn't respond | High |
| SAVE_FAIL | Network request returns 4xx/5xx | Critical |
| PERSISTENCE_FAIL | Data doesn't survive page reload | Critical |
| CACHE_STALE | UI shows old data after reload | High |
| CONSOLE_ERROR | JS errors in console | Medium-High |

**SAVE_FAIL and PERSISTENCE_FAIL are always blockers.**