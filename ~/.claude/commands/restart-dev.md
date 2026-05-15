---
name: restart-dev
description: Use when the dain-os dev servers (API or web) are down, showing 502, failing to start, or after killing portless processes. Use when Next.js lock is stale or portless route is missing.
---

# Restart Dev Servers

Runs `scripts/restart-dev.sh` which kills stale processes cleanly, clears the Next.js lock, and restarts both servers via `dev.sh`.

## Steps

1. Run the script:
```bash
bash "/c/Users/kramb/OneDrive - DAIN/Apps/dain-os/scripts/restart-dev.sh" > /tmp/devlog 2>&1
```
Use `run_in_background: true`. Then `sleep 25 && tail -5 /tmp/devlog` to confirm both servers are ready.

2. Verify both routes are live:
```bash
portless list
curl -sk https://dain-api.localhost/api/v1/health | python3 -c "import sys,json; print(json.load(sys.stdin).get('success'))"
```

## Why Things Break

**Root cause:** Killing portless wrapper PIDs (e.g. to unblock the API) can clear the web route from the portless daemon. Always kill tsx/Node process PIDs directly — never the portless wrapper PID.

**Next.js lock:** If the web Next.js process dies without cleanup, `.next/dev/lock` stays held. The script clears it.

## Never Do This

- `taskkill` on portless wrapper PIDs — kills the daemon route, takes web server down too
- Pipe `dev.sh` through `head` — SIGPIPE kills the child processes immediately

Kill the **tsx** process or the **node** process directly instead.
