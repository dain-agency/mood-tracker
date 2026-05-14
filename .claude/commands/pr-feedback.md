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
   - If it includes a suggestion block -> apply the suggested diff directly unless it's incorrect
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

**Safety limit:** Maximum 3 review cycles to avoid infinite loops.

### Resolve addressed threads

After confirming no further Greptile feedback, resolve all Greptile review threads on the PR using GitHub GraphQL API.

## Step 5: Final status and merge prompt

Present the final summary with changes made, items skipped with reasons, and verification results.

Then ask the user: "All review feedback has been addressed. Ready to merge?"

**Wait for explicit user confirmation before merging.** Never auto-merge.

## Step 6: Capture lessons learned

After merge, distil lessons from the review session and present them to the user. For each lesson, determine category, module, severity, description, prevention, and context file updates.