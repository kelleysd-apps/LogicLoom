# Git Push Guide

**Command**: `/git-push`
**Version**: 1.0.0
**Constitutional Compliance**: Principle VI (CRITICAL)

---

## Quick Start

```bash
# Complete workflow: commit → push → PR
/git-push
```

**⚠️ IMPORTANT**: All git operations require your explicit approval.

---

## What It Does

The `/git-push` command provides a complete git workflow:

1. **Review changes** - Shows diff and file summary
2. **Commit** - Stages and commits with your approval
3. **Push** - Pushes to origin with your approval
4. **Create PR** - Opens pull request with your approval
5. **Check conflicts** - Detects merge conflicts
6. **Resolve conflicts** - Helps fix conflicts (loops until clean)

---

## Usage Examples

### Full Workflow

```bash
/git-push
```

### Custom Commit Message

```bash
/git-push -m "feat: Add user authentication"
```

### Push Only (No PR)

```bash
/git-push --no-pr
```

### Create Draft PR

```bash
/git-push --draft
```

### Target Specific Branch

```bash
/git-push -t develop
```

---

## Approval Points (Principle VI)

You will be asked for approval at each git operation:

| Stage | Prompt | Options |
|-------|--------|---------|
| Commit | "Approve commit? (y/n)" | y, n, abort |
| Push | "Push to origin? (y/n)" | y, n, abort |
| PR Create | "Create this PR? (y/n)" | y, n, edit, abort |
| Conflict Resolution | "Resolve conflicts? (y/n)" | y, n, manual, abort |

**The workflow NEVER executes git commands without your explicit "y" response.**

---

## Example Session

```
🚀 Git Push Workflow

📊 Stage 1: Review Changes
   Modified: 3 files (+150, -25)
   
🔒 Approve commit? (y/n) y

📝 Stage 2: Commit
   Message: "feat: Add user authentication"
   ✓ Committed: abc1234
   
🔒 Push to origin? (y/n) y

🚀 Stage 3: Push  
   ✓ Pushed successfully
   
🎯 Stage 4: Target Branch
   Select target: main
   
🔒 Create PR? (y/n) y

📋 Stage 5: Create PR
   ✓ PR #42 created

🔍 Stage 6: Conflict Check
   ✓ No conflicts

✅ Complete!
   PR: https://github.com/owner/repo/pull/42
```

---

## Merge Conflict Handling

When conflicts are detected:

1. **Files listed** with conflict type
2. **Recommendations** provided per file
3. **Your approval** required before resolution
4. **Backup branch** created before changes
5. **Loop** continues until PR is clean

### Common Conflict Types

| File Type | Recommendation |
|-----------|----------------|
| `package-lock.json` | Delete and regenerate |
| Source code | Review both versions |
| Config files | Merge carefully |
| Binary files | Choose one version |

---

## Error Handling

| Error | What Happens |
|-------|--------------|
| No changes | Asked: "Push existing commits?" |
| Push rejected | Offered: "Pull and merge first?" |
| Auth failed | Guided: "Run 'gh auth login'" |
| PR exists | Offered: "Update existing PR?" |

---

## Options Reference

| Option | Short | Description |
|--------|-------|-------------|
| `--message` | `-m` | Custom commit message |
| `--target` | `-t` | PR target branch |
| `--draft` | | Create draft PR |
| `--no-pr` | | Push only, skip PR |
| `--skip-commit` | | Push existing commits |

---

## Prerequisites

- Git repository with remote "origin"
- GitHub CLI (`gh`) installed and authenticated
- Push access to repository

**Check prerequisites**:
```bash
git --version        # Git installed
gh --version         # GitHub CLI installed
gh auth status       # Authenticated
```

---

## Constitutional Compliance

This command strictly enforces **Principle VI: Git Operation Approval**:

> "NO autonomous Git operations without user approval"

- Every `git commit` requires approval
- Every `git push` requires approval
- Every `gh pr create` requires approval
- Every conflict resolution requires approval

**Violations are impossible** - the workflow simply waits for your response.

---

## Related

- [Unified Specification Guide](./unified-specification-guide.md)
- [Constitutional Principles](../../.specify/memory/constitution.md)
