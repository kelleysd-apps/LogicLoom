---
description: Complete git workflow - commit, push, PR creation with merge conflict resolution. All operations require user approval.
---

# /git-push Command

**Skill**: `git/git-push-workflow`
**Version**: 1.0.0
**Constitutional Compliance**: Principle VI (CRITICAL)

## Usage

```
/git-push [options]
```

## Description

Complete git workflow that handles:
1. **Commit** - Stage and commit changes with auto-generated message
2. **Push** - Push to origin with upstream tracking
3. **PR Creation** - Create pull request with generated description
4. **Conflict Resolution** - Detect and resolve merge conflicts

**⚠️ CRITICAL**: All git operations require explicit user approval (Principle VI)

## Options

| Option | Description |
|--------|-------------|
| `-m, --message <msg>` | Custom commit message |
| `-t, --target <branch>` | PR target branch (default: main) |
| `--draft` | Create draft PR |
| `--no-pr` | Push only, skip PR creation |
| `--skip-commit` | Push existing commits |

## Examples

```bash
# Full workflow (commit → push → PR)
/git-push

# Custom commit message
/git-push -m "feat: Add user authentication"

# Push only, no PR
/git-push --no-pr

# Create draft PR
/git-push --draft

# Target specific branch
/git-push -t develop

# Push existing commits (no new commit)
/git-push --skip-commit
```

## Workflow Stages

```
┌─────────┐   ┌────────────────┐   ┌───────────┐
│  DIFF   │ → │ COMMIT_PENDING │ → │ COMMITTED │
└─────────┘   └────────────────┘   └───────────┘
                    ↓ (approval)
              ┌────────────────┐   ┌────────┐
              │  PUSH_PENDING  │ → │ PUSHED │
              └────────────────┘   └────────┘
                    ↓ (approval)
              ┌──────────────────┐   ┌────────────┐
              │ PR_CREATE_PENDING│ → │ PR_CREATED │
              └──────────────────┘   └────────────┘
                    ↓ (approval)
              ┌────────────────┐
              │ CONFLICT_CHECK │ ─── CLEAN ──→ COMPLETE
              └────────────────┘
                    ↓ (dirty)
              ┌───────────────────┐   ┌────────────────────┐
              │ CONFLICT_DETECTED │ → │ CONFLICT_RESOLVING │ ─┐
              └───────────────────┘   └────────────────────┘  │
                    ↓ (approval)              ↑               │
                    └─────────────────────────┴───────────────┘
                                        (loop until clean)
```

## User Approval Points

**Constitutional Principle VI requires approval at every git operation:**

| Stage | Approval Prompt |
|-------|-----------------|
| COMMIT_PENDING | "Approve commit? (y/n/abort)" |
| PUSH_PENDING | "Push to origin? (y/n/abort)" |
| PR_CREATE_PENDING | "Create this PR? (y/n/edit/abort)" |
| CONFLICT_DETECTED | "Resolve conflicts? (y/n/manual/abort)" |

**CRITICAL**: The workflow will NEVER execute git commands without your explicit "y" response.

## Merge Conflict Handling

When conflicts are detected:
1. Conflicting files listed with paths
2. Conflict type identified (content, rename, delete, lock file)
3. Resolution recommendation provided
4. User approval required before any resolution
5. Backup branch created before changes
6. Loop continues until PR is clean

**Lock File Conflicts** (package-lock.json, yarn.lock):
- Recommendation: Delete and regenerate
- Marked as auto-resolvable

**Source Code Conflicts**:
- Recommendation: Review both versions
- NOT auto-resolved without review

## Error Handling

| Error | Response |
|-------|----------|
| No changes to commit | "Push existing commits? (y/n)" |
| Push rejected | "Pull and merge first? (y/n)" |
| Auth failed | "Run 'gh auth login'" |
| PR already exists | "Update existing PR? (y/n)" |

## Output Example

```
🚀 Git Push Workflow

📊 Stage 1: Review Changes
   Modified: 3 files (+150, -25)
   
🔒 Approve commit? (y/n) y

📝 Stage 2: Commit
   ✓ Committed: abc1234
   
🔒 Push to origin? (y/n) y

🚀 Stage 3: Push  
   ✓ Pushed successfully
   
🎯 Stage 4: Target Branch
   Selected: main
   
🔒 Create PR? (y/n) y

📋 Stage 5: Create PR
   ✓ PR #42 created

🔍 Stage 6: Conflict Check
   ✓ No conflicts

✅ Complete!
   PR: https://github.com/owner/repo/pull/42
```

## Prerequisites

- Git repository with remote "origin"
- GitHub CLI (gh) installed and authenticated
- Push access to repository

---

**Activate Skill**: When this command is invoked, activate the `git-push-workflow` skill at `.claude/skills/git/git-push-workflow/SKILL.md`
