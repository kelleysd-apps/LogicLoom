---
name: git-push
description: Complete git workflow — commit, push, PR creation with merge conflict resolution. All operations require user approval.
model: opus
---

# /git-push Command

**SKILL ACTIVATION**: Activate the git-push-workflow skill at `plugins/loom-git/skills/git-push-workflow/SKILL.md`.

**CRITICAL (Principle VI)**: ALL git operations in this command require explicit user approval.

## Execution Instructions

### Step 1: Assess Current State
```bash
git status
git diff --stat
git log --oneline -5
```
Show user: modified files, staged changes, recent commits.

### Step 2: Stage and Commit (with approval)
- Show what will be committed
- Generate descriptive commit message
- **ASK USER for approval** before `git commit`

### Step 3: Push (with approval)
- Check remote tracking branch
- **ASK USER for approval** before `git push`
- Handle merge conflicts if detected

### Step 4: PR Creation (optional, with approval)
- Generate PR title and description from commits
- **ASK USER for approval** before `gh pr create`
- Report PR URL

## Constitutional Compliance
- **Principle VI (CRITICAL)**: Every git operation requires explicit user approval
- No `--force` operations without explicit request
- No automatic branch creation
