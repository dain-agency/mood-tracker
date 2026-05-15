# Worktree Cleanup

Remove stale git worktrees safely on Windows/OneDrive paths.

## Usage

```
/worktree-cleanup
/worktree-cleanup billing-primary-funding
```

- `/worktree-cleanup` — list and remove all worktrees (except the main working tree)
- `/worktree-cleanup <name>` — remove a specific worktree by name

## Instructions

### Step 1: List current worktrees

```bash
git worktree list
```

If only the main working tree exists, report "No worktrees to clean up." and stop.

### Step 2: Identify targets

- If `$ARGUMENTS` is provided, match against worktree names (partial match fine).
- If empty, target ALL worktrees except the main working tree.
- Show user which will be removed and ask for confirmation.

### Step 3: Remove worktrees

For each, in order:

**a) Prune git metadata first:**
```bash
git worktree prune
```

**b) Delete directory using PowerShell (NEVER use rm -rf — fails on OneDrive paths):**
```bash
powershell.exe -Command "Remove-Item -Path '<full-worktree-path>' -Recurse -Force -ErrorAction Stop"
```

**c) Prune again:**
```bash
git worktree prune
```

### Step 4: Clean up associated local branches (optional)

Check `git branch --merged main`. For merged branches, offer to delete. For unmerged, warn and skip unless confirmed.

```bash
git branch -d <branch-name>
```

### Step 5: Verify

```bash
git worktree list
```

### Important notes

- **ALWAYS use PowerShell Remove-Item** for directory deletion. `rm -rf`, `cmd.exe /c rd`, and bash `rmdir` all fail silently on Windows/OneDrive.
- "Cannot find path" means already deleted — fine, continue.
- Permission/lock error: suggest user close IDE tabs pointing at the worktree, retry.
- Run `git worktree prune` both before and after deletion.
