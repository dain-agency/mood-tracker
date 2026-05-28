---
description: Run e2e tests via Chrome browser automation
argument-hint: "[optional: scope of changes to test, or 'plan' to generate test plan, or a URL to test against]"
---

# E2E Testing: $ARGUMENTS

**THIS PHASE MUST NEVER BE SKIPPED WHEN THERE IS UI TO REVIEW.**

E2E testing is the single most important QA gate. Unit tests verify code correctness; E2E verifies *feature* correctness — what the user actually sees and experiences. Every shortcut taken here (skipping because dev servers won't start, skipping because credentials don't work, skipping because "the unit tests pass") has resulted in shipping broken UI to production.

If you encounter a blocker at any phase, you must **diagnose and fix it**, not skip around it. The phases below provide multiple fallback strategies for every common blocker. Exhaust them all before concluding E2E cannot run — and if it truly cannot, explain exactly what failed, what you tried, and what the user must do to unblock it. Never silently degrade to "deferred to manual testing" without fighting for it first.

---

## Phase 0: Browser Tool Discovery

**Determine which browser automation is available.** Try in order — use the first that works:

### Option A: Claude-in-Chrome (preferred for interactive sessions)
```
Check for mcp__claude-in-chrome__* tools via ToolSearch.
```
If available: use `mcp__claude-in-chrome__tabs_create_mcp`, `navigate`, `read_page`, `form_input`, `click`.

### Option B: Playwright MCP (preferred for headless / CI / background agents)
```
Check for mcp__plugin_playwright_playwright__* tools via ToolSearch.
```
If available: use `browser_navigate`, `browser_snapshot`, `browser_click`, `browser_fill_form`, `browser_take_screenshot`.

### Option C: Install Playwright (fallback)
If neither is available:
```bash
npx playwright install chromium
```
Then use `@playwright/test` programmatically, or re-check for the Playwright MCP tools after install.

**If all three fail**, inform the user and stop. Do not proceed without browser access.

Record which option was selected — all subsequent phases use that tool set.

---

## Phase 1: Determine Target URL

**E2E testing is the most important QA gate. It must NEVER be skipped when there is UI to review.** Exhaust every method below before concluding the app is unreachable.

**If `$ARGUMENTS` contains a URL** (e.g. a Vercel preview URL, localhost:3000, an Azure domain):
- Use that URL directly. Skip to Step 6.

**If no URL provided**, work through this discovery chain. Stop at the first success:

### Step 1: Check for a running app on common ports
```bash
for port in 3000 3001 3002 3003 3033 4000 4200 5173 8080; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port" 2>/dev/null || echo "000")
  [ "$code" != "000" ] && echo "FOUND: localhost:$port (HTTP $code)"
done
```
If found, use that URL.

### Step 2: Check for a Vercel preview deployment
If the current branch has been pushed:
```bash
# Check for Vercel project link
cat .vercel/project.json 2>/dev/null
# Or search for vercel.json
find . -name 'vercel.json' -maxdepth 3 -not -path '*/node_modules/*' 2>/dev/null
```
If a Vercel project is linked, use the Vercel MCP tools (`list_deployments` filtered by the current branch) or construct the branch alias URL: `https://<project>-git-<branch>-<team>.vercel.app`. Use `get_access_to_vercel_url` if deployment protection blocks access.

### Step 3: Check for an Azure deployment
If the project uses Azure (check for `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, or `az` CLI config):
```bash
# List container apps in the subscription
az containerapp list --query '[].{name:name, fqdn:properties.configuration.ingress.fqdn}' -o table 2>/dev/null
# Or check for Azure Static Web Apps
az staticwebapp list --query '[].{name:name, url:defaultHostname}' -o table 2>/dev/null
```
Match the app name to the current project. Use the FQDN as the target URL.

### Step 4: Start dev servers locally
Try in order:
1. **Portless** (if installed): `portless dev` or check `portless.config.*` for the project's dev command
2. **Project dev script**: `scripts/dev.sh`, `npm run dev`, `make dev`
3. **Monorepo per-app**: `npm run dev --workspace=<app>` (identify the relevant app from the test scope)
4. **Single app**: `npm run dev` or `npx next dev`

Start with `run_in_background: true`. Poll until responsive (max 60 seconds):
```bash
for i in $(seq 1 20); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT:-3000}" 2>/dev/null || echo "000")
  [ "$code" != "000" ] && echo "DEV SERVER READY" && break
  sleep 3
done
```

If dev server fails (missing env vars, build errors, port conflicts), diagnose and fix:
- Missing `.env.local`: pull from Vercel (`npx vercel env pull`) or copy from `.env.example`
- Port conflict: use `PORT=<free-port> npm run dev`
- Turbopack/build error: try without turbopack, or fix the build error

### Step 5: Use the production URL as read-only fallback
If no dev or preview environment is reachable, check for a production URL in:
- `CLAUDE.md` or `README.md` (deployment URLs section)
- `.env.example` or `.env.production` (`NEXT_PUBLIC_APP_URL`, `APP_URL`)
- `vercel.json` or project config

**Only use production for read-only verification** (viewing reports, checking layout). Never test data mutations against production.

### Step 6: Record the target URL
Store the resolved URL. All subsequent phases use this as the base URL. Log which discovery method succeeded so the user knows where the tests ran.

---

## Phase 2: Authenticate

**Credential discovery chain** — try each in order until one works:

### Step 1: Search for env-based test credentials
```bash
# Search all .env / .env.local files across the repo (monorepos have multiple)
find . -name '.env*' -not -path '*/node_modules/*' -not -path '*/.next/*' 2>/dev/null \
| xargs grep -l 'TEST_EMAIL\|TEST_PASSWORD\|TESTING_EMAIL\|TESTING_PASSWORD\|DEMO.*EMAIL\|E2E.*EMAIL' 2>/dev/null
```
Read the matching file(s). Extract email + password pairs. Try each pair against the login form until one succeeds.

### Step 2: Check for credential helper files
```bash
find . -name '*testing-credentials*' -o -name '*test-users*' -o -name '*seed-test-users*' \
  -not -path '*/node_modules/*' 2>/dev/null
```

### Step 3: Azure Key Vault (if env credentials fail)
If the project uses Azure (check for `AZURE_TENANT_ID` in any .env file):
```bash
# Login to DAIN tenant if not already authenticated
az account show 2>/dev/null || az login --tenant <AZURE_TENANT_ID>
# List available key vaults
az keyvault list --query '[].name' -o tsv
# Fetch test credentials
az keyvault secret show --vault-name <vault> --name e2e-test-email --query value -o tsv
az keyvault secret show --vault-name <vault> --name e2e-test-password --query value -o tsv
```

### Step 4: Create a test user via Supabase MCP (last resort)
If all credential sources fail and the Supabase MCP is available:
```
Use mcp__claude_ai_Supabase__execute_sql to create a test user:
- email: e2e-test@claude-code.local
- password: a secure random string
- Grant minimum permissions needed for the test scope
```
**Always inform the user** when creating a test user. Clean up after testing.

### Login execution
1. Navigate to the login page
2. Take a snapshot to identify form fields
3. If there's an "Other ways to sign in" or "Email login" expander, click it first
4. Fill email + password fields
5. Click the login/submit button
6. Wait for redirect away from the login page (up to 45 seconds)
7. If login fails ("Invalid credentials"), try the next credential pair
8. If all credentials exhausted, stop and surface to the user

---

## Phase 3: Test Plan

### If `$ARGUMENTS` is empty — Interactive mode
After login, inform the user the browser is ready and ask what to test.

### If `$ARGUMENTS` is 'plan' — Auto-generate from changes
1. Detect changes: `git diff main --name-only` (or `git diff develop --name-only`)
2. Map changed files to testable user journeys
3. Generate a test plan: page URL, user actions, expected outcomes, persistence checks
4. Present for approval before executing

### If `$ARGUMENTS` describes a scope or feature
Read the Feature Brief if one exists (check `docs/plans/` for a matching brief). Extract user journeys from section 5. Map each journey to browser actions.

### If `$ARGUMENTS` is a URL
Navigate to the URL and run the full Phase 4 (UX Audit) + Phase 5 (Functional) + Phase 6 (Persistence) checklist against whatever page loads.

---

## Phase 4: UX & Visual Audit (MANDATORY)

**This phase runs for EVERY test, not just UI-specific changes.** Put yourself in the user's shoes. Walk through each journey slowly, reasoning about whether anything feels confusing, unintuitive, cluttered, or broken.

### 4.1 Mandatory Visual Checklist

Run these checks on every page visited. Take a screenshot before and after if issues are found.

| Check | What to look for | Severity |
|---|---|---|
| **No overlapping elements** | Text over text, buttons behind modals, z-index fights | BLOCK |
| **Sufficient spacing** | Elements crammed together, no breathing room between cards/rows/sections | HIGH |
| **Horizontal overflow** | Content wider than viewport, horizontal scrollbar on the page body (not inside a deliberate scroll container) | BLOCK |
| **Vertical overflow** | Content cut off at bottom without scroll, modals taller than viewport without scroll | BLOCK |
| **Responsive at desktop** | Verify at 1280px+ — no wasted space, content fills the layout sensibly | HIGH |
| **Responsive at tablet** | Verify at 768px — sidebar collapses, tables scroll horizontally, forms stack | HIGH |
| **Responsive at mobile** | Verify at 375px — everything reachable, touch targets >= 44px, no horizontal scroll | MEDIUM (skip if brief says "no mobile") |
| **Loading states** | Skeleton/spinner shown while data loads, no flash of empty content | HIGH |
| **Empty states** | Zero-data scenario shows a helpful message, not a blank page or broken table | HIGH |
| **Error states** | Network failure shows a user-friendly message, not a raw error or blank screen | HIGH |
| **Text truncation** | Long names/values truncate with ellipsis rather than breaking layout | MEDIUM |
| **Icon rendering** | All icons visible (no blank squares, no missing SVGs) | HIGH |
| **Colour contrast** | Text readable against background, status colours distinguishable | MEDIUM |
| **Interactive feedback** | Buttons show hover/active states, clicks produce visible response | MEDIUM |

### 4.2 Journey-Level UX Review

For each user journey being tested, reason through:

1. **Discoverability** — Can the user find this feature? Is the entry point obvious?
2. **Cognitive load** — Is there too much on screen? Would a first-time user know what to do?
3. **Information hierarchy** — Is the most important information visually prominent?
4. **Action clarity** — Are buttons labelled clearly? Is the primary action obvious?
5. **Feedback loops** — After an action, does the user know it worked? (Toast, state change, navigation)
6. **Error recovery** — If something goes wrong, can the user recover without starting over?

Document any UX concerns with a screenshot and a one-line description.

### 4.3 Viewport Verification

Resize the browser to test at three widths. Use the browser resize tool if available:
- **Desktop:** 1440px wide
- **Tablet:** 768px wide
- **Mobile:** 375px wide (skip if the Feature Brief explicitly says "no mobile")

Take a screenshot at each viewport for any page that has layout concerns.

---

## Phase 5: Functional Testing

For each user journey or test scope:

1. **Navigate** to the starting page
2. **Interact** — click buttons, fill forms, select filters, sort columns, switch tabs
3. **Verify** — check that the expected content appears, tables populate, filters work
4. **Console check** — look for JavaScript errors after each interaction
5. **Cross-link verification** — if the feature links to other pages (click-through), follow the link and verify the destination loads correctly

### Crash detection and recovery (CRITICAL)

**Every browser tool call can timeout or fail because the page crashed.** A timeout on `browser_snapshot`, `browser_click`, or `browser_console_messages` after an interaction almost certainly means the page has entered an infinite render loop, thrown an unhandled exception, or frozen.

**When a tool call times out or errors after an interaction:**

1. **Record what you just did.** Log the exact interaction that preceded the crash (e.g. "clicked Home faceted filter button, ref=e346"). This is the most valuable diagnostic — it tells the developer exactly how to reproduce.
2. **Do NOT retry the same action.** The page is dead. Retrying the same click will timeout again.
3. **Close and reopen the browser.** Call `browser_close` (may itself timeout — that's fine, ignore the error). Then navigate fresh to the target URL.
4. **Re-authenticate** if the new browser session requires it.
5. **Navigate back to the page that crashed** and take a screenshot of its initial state (before the crashing interaction) as evidence.
6. **Log a PAGE_CRASH finding** with: the page URL, the interaction that triggered it, and the pre-crash screenshot. This is a **BLOCK** severity finding.
7. **Continue testing other journeys.** A crash in one filter does not excuse skipping the remaining test plan. Navigate to the next journey's starting page and continue.

**The goal: never exit silently.** A crashed E2E run that produces no report is worse than useless — it wastes the entire test budget and gives false confidence. Even if every single interaction crashes the page, the report must still be produced listing every crash with its trigger.

**Tool timeout budget:** If you get 3 consecutive timeouts without a successful tool call in between, the browser is irrecoverably stuck. Close it, reopen, and log all pending tests as UNTESTED with the reason.

### Functional checks by component type

| Component | What to test |
|---|---|
| **Tables** | Sorting works, pagination works, search filters rows, faceted filters work, empty state shows for no-match |
| **Forms** | Required fields validate, submission shows success feedback, invalid input shows error |
| **Tabs** | Each tab loads its content, active state is visually correct, lazy-loaded tabs fetch on first click |
| **Modals/Dialogs** | Open and close cleanly, escape key works, overlay click closes (if applicable) |
| **Export/Download** | Button triggers download, file is non-empty |
| **Navigation** | Links navigate to correct pages, breadcrumbs are accurate, back button works |

---

## Phase 6: Persistence Testing

**Every flow that creates, updates, or deletes data MUST include persistence verification.**

### 6.1 Save and Reload
After any data-modifying action:
1. Note the data that was saved
2. Reload the page (navigate to the same URL)
3. Verify the data persists after reload

### 6.2 Network Validation
After save/create/update/delete actions, check for network errors in the console or via network request tools.

### 6.3 Cross-Session Persistence (for critical flows)
1. Log out
2. Log back in
3. Navigate to the same page
4. Verify data still exists

### 6.4 Database Verification (when Supabase MCP is available)
For critical create/update operations, query the database directly to confirm the data was written:
```
Use mcp__claude_ai_Supabase__execute_sql with a SELECT query to verify.
```

---

## Phase 7: Reporting

After all tests complete, provide a summary:

### Results Table

| # | Test | Journey | Status | Persistence | UX Issues | Notes |
|---|---|---|---|---|---|---|
| 1 | ... | Journey 1 | PASS/FAIL | PASS/FAIL/N/A | 0/N | ... |

### Failure Classification

| Classification | Meaning | Severity | Blocker? |
|---|---|---|---|
| PAGE_CRASH | Page froze or entered infinite loop after an interaction — browser tools timed out | Critical | **Always** |
| RENDER_FAIL | Page doesn't render or shows error | High | Yes |
| INTERACTION_FAIL | Button/form doesn't respond | High | Yes |
| SAVE_FAIL | Network request returns 4xx/5xx | Critical | **Always** |
| PERSISTENCE_FAIL | Data doesn't survive page reload | Critical | **Always** |
| CACHE_STALE | UI shows old data after reload | High | Yes |
| CONSOLE_ERROR | JS errors in console | Medium-High | Context-dependent |
| UX_OVERLAP | Elements overlapping or overflowing | High | Yes |
| UX_SPACING | Insufficient padding/spacing | Medium | No (but flag) |
| UX_RESPONSIVE | Layout breaks at a viewport width | Medium-High | Context-dependent |
| UX_CONFUSION | Flow is unintuitive or unclear | Medium | No (but flag) |
| UNTESTED | Could not test due to unrecoverable browser failure | High | Yes (requires manual verification) |

### Visual Evidence
Attach screenshots for:
- Every FAIL result
- Every UX issue found
- Viewport checks at desktop/tablet/mobile (if layout concerns exist)

**PAGE_CRASH, SAVE_FAIL, and PERSISTENCE_FAIL are always blockers. UX_OVERLAP is a blocker. UNTESTED requires manual verification before merge. Everything else is context-dependent — use judgement.**

**A report with zero findings is still a report.** An E2E run that crashes and produces nothing is not. The minimum acceptable output is a table listing every planned test with its status — even if every status is PAGE_CRASH or UNTESTED.