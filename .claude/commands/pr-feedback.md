---
description: Fetch PR feedback (especially Greptile), address comments, and iterate until clean
argument-hint: [optional: PR number]
---

# PR Feedback: $ARGUMENTS

Address all PR review comments -- especially Greptile -- commit fixes, and iterate until the PR is clean.

## Step 1: Identify the PR

If `$ARGUMENTS` contains a PR number, use that. Otherwise, detect from the current branch:

```bash
git branch --show-current
```

Then find the PR for this branch using the Greptile MCP:

```
mcp__greptile__list_pull_requests({
  name: "{{repo_org}}/{{repo_name}}",
  remote: "github",
  defaultBranch: "main",
  sourceBranch: "<current-branch>",
  state: "open"
})
```

If no open PR is found, tell the user and stop.

Store the PR number -- it's used throughout.

## Step 2: Fetch PR comments

Pull all comments, filtering for Greptile-generated ones that haven't been addressed:

```
mcp__greptile__list_merge_request_comments({
  name: "{{repo_org}}/{{repo_name}}",
  remote: "github",
  defaultBranch: "main",
  prNumber: <pr-number>,
  greptileGenerated: true,
  addressed: false
})
```

Also fetch human comments to be aware of them:

```
mcp__greptile__list_merge_request_comments({
  name: "{{repo_org}}/{{repo_name}}",
  remote: "github",
  defaultBranch: "main",
  prNumber: <pr-number>,
  greptileGenerated: false
})
```

### Present a summary

```
## PR #<number> -- Feedback Summary

**Greptile comments (unaddressed):** N
**Human comments:** N

### Greptile Issues
| # | File | Issue | Severity |
|---|------|-------|----------|
| 1 | path/to/file.ts:L42 | Description | high/medium/low |
| 2 | ... | ... | ... |

### Human Comments
- @author: "comment summary" (on file.ts)
```

If there are **no unaddressed Greptile comments**, skip to Step 5.

## Step 3: Address Greptile comments

For each unaddressed Greptile comment:

1. **Read the file** referenced in the comment
2. **Understand the suggestion** -- Greptile comments may include suggestion blocks with proposed code changes
3. **Evaluate the suggestion:**
   - If it's a valid improvement (bug fix, type safety, missing error handling, security) -> apply it
   - If it's a style nit or subjective preference that doesn't match project conventions -> skip it, but note why
   - **Never apply a reviewer bot's suggested patch verbatim.** The diagnosis is a lead, not a fix: re-derive the patch independently against the actual behaviour of the code (read the surrounding code, reproduce or verify the claimed defect), then write your own change. Bot patches routinely look plausible while being wrong -- the canonical example is the Form/aria-describedby near-miss, where the suggested patch compiled cleanly but would have regressed the accessible descriptions it claimed to fix. If your independently-derived fix happens to match the suggestion, fine; the derivation comes first.
4. **Make the fix** using Edit tool
5. **Reply to the comment inline** on the PR (see Reply Protocol below)
6. **Track what was done** -- keep a running list of addressed vs skipped comments with reasons

### Reply Protocol

After addressing (or deciding to skip) each Greptile comment, reply inline on the PR.

**IMPORTANT:** Bash mangles backticks in `gh api` bodies. Always write the reply body to a temp file first.

The Greptile `id` field is NOT the GitHub comment ID. You must fetch the actual GitHub comment IDs first:

```bash
# Get GitHub comment IDs for Greptile bot comments
gh api repos/{{repo_org}}/{{repo_name}}/pulls/<pr-number>/comments \
  --jq '.[] | select(.user.login | test("greptile")) | {id, path: .path, line: .line, body: (.body[:80])}'
```

Then reply using the GitHub numeric `id`:

```bash
# 1. Write reply body to temp file (avoids backtick mangling)
cat > /tmp/pr-reply.txt << 'REPLY_EOF'
Your reply text here -- can safely include backticks, code blocks, etc.
REPLY_EOF

# 2. Post a threaded reply using the GitHub comment ID
gh api repos/{{repo_org}}/{{repo_name}}/pulls/<pr-number>/comments \
  -X POST \
  -F in_reply_to=<github-numeric-comment-id> \
  -F body=@/tmp/pr-reply.txt
```

**Reply content guidelines:**

- **If fixed:** Brief description of what was changed.
- **If skipped:** Explain why.
- **If partially addressed:** Note what was done and what wasn't.
- Keep replies concise (2-3 sentences max)

After addressing all comments:

### Run verification

```bash
npx tsc --noEmit
```

Run tests for any modified files.

If verification fails, fix the issues before proceeding.

### Commit and push

Stage only the files that were modified to address feedback:

```bash
git add <specific-files>
git commit -m "fix(review): address Greptile PR feedback"
git push
```

## Step 4: Decide whether to re-review

Assess the **scope of changes** made in Step 3:

- **Minor** (typos, single-line fixes, comment updates, <5 lines changed) -> Skip re-review, go to Step 5
- **Significant** (logic changes, new error handling, refactored code, >5 lines changed) -> Trigger re-review

### If re-review needed:

1. Trigger a new Greptile review
2. Poll for review completion (max 5 minutes, check every 30 seconds)
3. Compare comment counts -- after review completes, fetch new unaddressed Greptile comments
4. If genuinely new comments exist -> repeat Step 3 and Step 4
5. If no new comments -> proceed to Step 5

**Reviewer-loop cap (hard rules):**

1. **Pass 1 is the only full review.** Every subsequent pass is scoped to the DELTA only -- the commits pushed since the previous pass. Never re-run a full review of the whole PR on pass 2+; findings on unchanged code from a later pass are re-flags, not new work.
2. **Hard stop after 3 passes.** No fourth review cycle, ever. Whatever is still open after pass 3 goes to a human.
3. **Every finding is scored `useful` / `noise` / `wrong` with a written reason** -- nothing leaves the loop unscored. Score inline as you address each finding, or at wrap-up via `score_pr_finding` (wrap-up Step 7.5); the written reason is what makes the verdict auditable when tuning the reviewer.

**Bot-loop close-out (MANDATORY after cycle 2):** Some reviewer bots (e.g. dainos-reviewer, certain Greptile configurations) do NOT track resolution state across commits — they re-flag previously-fixed findings on every new push. After cycle 2, if a new cycle returns no NEW findings (only re-flags of already-addressed ones), post a single meta-comment closing further auto-cycles and stop triggering `@dainreview`/equivalent. Example body:

> Per the cmd-pr-feedback Phase 10 rule (max 3 cycles), this PR is now closing further automated re-review cycles. N genuinely new findings across the N cycles addressed in commits A, B, C. The bot does not track resolution across commits, so subsequent re-flags of fixed findings are expected — verified the fixes are in place; clarification replies posted on the false-positive threads. Ready for human review.

The PR proceeds to Step 5 with the open false-positive threads documented in the progress file. Do not keep triggering re-reviews in pursuit of a "zero comments" state the bot will never produce.

### Resolve addressed threads

After confirming no further Greptile feedback, resolve all Greptile review threads on the PR using GitHub GraphQL API.

## Step 5: Final status and merge prompt

Present the final summary with changes made, items skipped with reasons, and verification results.

Then ask the user: "All review feedback has been addressed. Ready to merge?"

**Wait for explicit user confirmation before merging.** Never auto-merge.

## Step 6: Capture lessons learned

After merge, distil lessons from the review session and present them to the user. For each lesson, determine category, module, severity, description, prevention, and context file updates.