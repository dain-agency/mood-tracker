---
description: Fetch PR feedback (DainOS reviewer + human), address findings, and iterate until clean
argument-hint: [optional: PR number]
---

# PR Feedback: $ARGUMENTS

Address all PR review feedback -- the DainOS PR reviewer's findings and human comments -- commit fixes, and iterate until the PR is clean.

> **Reviewer model.** The active reviewer is the DainOS PR reviewer (GitHub App, webhook-driven). Greptile is retired -- do not wait for it, @-mention it, or use Greptile MCP tools. Key behaviours that shape this workflow:
> - It reviews automatically on PR open AND re-reviews on every push. Never trigger reviews manually; batch fixes into ONE push per cycle.
> - **Finding bodies are NOT posted to GitHub.** Query them via the DainOS MCP (`pr_reviews` / `pr_review_findings`). The `repo` filter is the FULL GitHub slug (e.g. `dain-agency/dain-os`) -- PR numbers collide across repos.
> - It does NOT track resolution across commits: fixed findings are re-flagged on every push. Re-flags are not new work.
> - A run that failed-at-fetch (rate limit) or was skipped by the monthly cost cap is NOT a clean pass. Retrigger by closing and reopening the PR.
> - Docs/markdown-only PRs are silently skipped -- absence of a review on those is expected, not a failure.

## Step 1: Identify the PR

If `$ARGUMENTS` contains a PR number, use that. Otherwise, detect from the current branch:

```bash
git branch --show-current
gh pr view --json number,url
```

If no open PR is found, tell the user and stop. Store the PR number -- it's used throughout.

## Step 2: Fetch findings and comments

Fetch the DainOS reviewer's latest run and findings via the DainOS MCP:

```
query({ resource: "pr_reviews", filters: { repo: "{{repo_org}}/{{repo_name}}", prNumber: <pr-number> } })
query({ resource: "pr_review_findings", filters: { repo: "{{repo_org}}/{{repo_name}}", prNumber: <pr-number> } })
```

Check the review run status FIRST: `failed` (fetch error, rate limit) or `skipped` (cost cap) is NOT a pass -- close and reopen the PR to retrigger, then re-fetch.

Also fetch human comments so nothing is missed:

```bash
gh pr view <pr-number> --json reviews,comments
gh api repos/{{repo_org}}/{{repo_name}}/pulls/<pr-number>/comments
```

### Present a summary

```
## PR #<number> -- Feedback Summary

**Reviewer findings (open):** N   **Human comments:** N

### Reviewer Findings
| # | File | Finding | Severity |
|---|------|---------|----------|
| 1 | path/to/file.ts:L42 | Description | high/medium/low |

### Human Comments
- @author: "comment summary" (on file.ts)
```

If there are **no open reviewer findings**, skip to Step 5.

## Step 3: Address findings

For each open finding:

1. **Read the file** referenced in the finding
2. **Verify the claim empirically before acting.** The reviewer has a known false-positive tail (Prisma.sql bind params flagged as SQL injection, HugeiconsIcon rendering, `Edit`-form permission rules, tailwind-merge patterns, and more -- check the Dev KB `false-positive` tag). A finding whose body retracts itself, or that contradicts an earlier round, is noise: score it and move on.
3. **Evaluate the suggestion:**
   - Valid improvement (bug fix, type safety, missing error handling, security) -> apply it
   - Style nit or subjective preference that doesn't match project conventions -> skip it, but note why
   - **Never apply a reviewer bot's suggested patch verbatim.** The diagnosis is a lead, not a fix: re-derive the patch independently against the actual behaviour of the code (read the surrounding code, reproduce or verify the claimed defect), then write your own change. Bot patches routinely look plausible while being wrong -- the canonical example is the Form/aria-describedby near-miss, where the suggested patch compiled cleanly but would have regressed the accessible descriptions it claimed to fix. If your independently-derived fix happens to match the suggestion, fine; the derivation comes first.
4. **Make the fix** using Edit tool
5. **Track what was done** -- keep a running list of addressed vs skipped findings with reasons

### Replying on the PR

Reviewer finding bodies live in DainOS, not GitHub, so per-finding inline replies usually have no thread to attach to. Where a human commented, or where a false positive needs a public paper trail, post a PR-level comment.

**IMPORTANT:** Bash mangles backticks in `gh api` bodies. Always write the reply body to a temp file first and pass it with an ABSOLUTE path:

```bash
cat > /tmp/pr-reply.txt << 'REPLY_EOF'
Reply text -- can safely include backticks, code blocks, etc.
REPLY_EOF
gh pr comment <pr-number> --body-file /tmp/pr-reply.txt
```

**Reply content guidelines:** fixed -> what changed; skipped -> why; partial -> what was and wasn't done. 2-3 sentences max.

### Run verification

```bash
npx tsc --noEmit
```

Run tests for any modified files. If verification fails, fix the issues before proceeding.

### Commit and push

Stage only the files that were modified to address feedback, and push ONCE (each push triggers a re-review -- batch everything):

```bash
git add <specific-files>
git commit -m "fix(review): address PR review feedback"
git push
```

## Step 4: The re-review cycle

The reviewer re-reviews automatically on the push -- do not trigger anything. Wait for the new run (poll `pr_reviews` status), then fetch findings again and diff against your addressed list: genuinely NEW findings vs re-flags of fixed ones.

**Reviewer-loop cap (hard rules):**

1. **Pass 1 is the only full review.** Every subsequent pass is scoped to the DELTA only -- the commits pushed since the previous pass. Findings on unchanged code from a later pass are re-flags, not new work.
2. **Hard stop after 3 passes.** No fourth review cycle, ever. Whatever is still open after pass 3 goes to a human.
3. **Every finding is scored `useful` / `noise` / `wrong` with a written reason** -- nothing leaves the loop unscored. Score inline as you address each finding, or at wrap-up via `score_pr_finding` (wrap-up Step 7.5); the written reason is what makes the verdict auditable when tuning the reviewer.

**Bot-loop close-out (MANDATORY after cycle 2):** The DainOS reviewer does NOT track resolution state across commits -- it re-flags previously-fixed findings on every new push. After cycle 2, if a new cycle returns no NEW findings (only re-flags of already-addressed ones), post a single meta-comment closing further auto-cycles. Example body:

> Per the cmd-pr-feedback rule (max 3 cycles), this PR is now closing further automated re-review cycles. N genuinely new findings across the cycles were addressed in commits A, B, C. The reviewer does not track resolution across commits, so subsequent re-flags of fixed findings are expected -- verified the fixes are in place; clarification comments posted for the false positives. Ready for human review.

The PR proceeds to Step 5 with the open false-positive findings documented in the progress file. Do not keep pushing in pursuit of a "zero findings" state the reviewer will never produce.

## Step 5: Final status and merge prompt

Present the final summary with changes made, items skipped with reasons, and verification results.

Then ask the user: "All review feedback has been addressed. Ready to merge?"

**Wait for explicit user confirmation before merging.** Never auto-merge.

## Step 6: Capture lessons learned

After merge, distil lessons from the review session and present them to the user. For each lesson, determine category, module, severity, description, prevention, and context file updates. Recurring reviewer false positives belong in the Dev KB with the `false-positive` tag AND as a `pr_review_suppression_rules` candidate.
