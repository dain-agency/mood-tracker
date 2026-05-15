---
name: e2etest
description: Use when manually testing a feature end-to-end in the browser. Starts dev servers, opens Playwright browser, authenticates, and navigates to the target page. Invoke with optional arguments for the page path or feature name.
---

# E2E Manual Test

Spin up dev servers, authenticate via Playwright, navigate to the target page, and present a manual testing plan.

## Arguments

`/e2etest [path-or-feature]`

- `/e2etest` — starts servers, authenticates, lands on dashboard
- `/e2etest /forge/projects` — navigates to that path after auth
- `/e2etest forge ai assistant` — infers right path from feature name

## Step 1: Resolve target path

Map feature name to URL. Known routes: forge projects → /forge/projects; dashboard → /dashboard; crm → /crm; time → /time; finance → /finance; settings → /settings.

If no argument, default to page most relevant to current branch (check `git branch --show-current`).

## Step 2: Start dev servers

```bash
bash scripts/dev.sh
```

Run in background. Poll localhost:3002 until ready (max 30 attempts at 2s intervals). Skip if already running.

## Step 3: Authenticate

1. **Load testing credentials.** Do NOT read `.env.local` — it is in the permissions deny list. Each project keeps test-only credentials in a dedicated file:
   - **Mabel CRM:** `.claude/test-credentials.env`
   - **Other projects:** check project memory for reference entry; or `.claude/`; or ask user and offer to set up the pattern.

   Read the file with Read tool, extract credentials matching test role. Default to **super admin** to sidestep RLS gotchas.

2. **If no credentials file exists**, ask user to either (a) create `.claude/test-credentials.env` now or (b) paste credentials once. Option (a) preferred — one-time fix.

3. Navigate browser to `{baseUrl}/login`, fill form, wait for navigation away from /login.

**Security note:** password appears verbatim in form-fill tool call. Don't echo credentials in prose, don't log them.

## Step 4: Navigate to target

`browser_navigate` to `http://localhost:3002{targetPath}`, wait via `browser_snapshot`, screenshot.

## Step 5: Present manual testing plan

```markdown
## Manual Testing Plan: [Feature Name]

### Pre-conditions
- [ ] Dev servers running
- [ ] Authenticated as test user

### Functional Tests (generated from git diff)
### Visual/UX Tests (responsive, dark mode, loading, error)
### Edge Cases
```

Generate functional tests by reading `git diff main...HEAD` and component code. Be specific.

## Step 6: Interactive testing

Stay in browser session. User can ask to click, fill, navigate, screenshot, check console (`browser_console_messages`), inspect network (`browser_network_requests`).

## Error Recovery

| Problem | Fix |
|---|---|
| Port already in use | Servers already running — skip startup |
| Login fails | Check credentials, retry once, then report |
| Page 404 | Check route exists, suggest alternatives |
| Blank page after auth | Take snapshot, check for redirect loops |
