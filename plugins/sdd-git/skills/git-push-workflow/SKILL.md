---
name: git-push-workflow
version: 1.0.0
description: |
  Complete git workflow from commit to PR with merge conflict resolution.
  Handles commit, push, PR creation, and conflict detection/resolution
  with user approval at every git operation (Principle VI compliance).
  
  Triggered by: /git-push command, "push my changes", "create a PR",
  "commit and push", "submit for review"

allowed-tools: Read, Bash, Grep
triggers:
  - /git-push
  - push changes
  - create PR
  - commit and push
  - submit for review
category: git
constitutional_principles:
  - VI (CRITICAL - Git Operation Approval at EVERY step)
  - IV (Idempotent Operations)
  - VII (Observability - Audit logging)
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_feedback: null
---

# Git Push Workflow Skill

## Overview

Complete git workflow that handles commit, push, PR creation, and merge
conflict resolution with **mandatory user approval at every git operation**.

**CRITICAL**: This skill strictly enforces Constitutional Principle VI.
NO git operations execute without explicit user approval.

## When to Use

Activate this skill when:
- User invokes `/git-push`
- User wants to "commit and push changes"
- User wants to "create a PR"
- User wants to "submit changes for review"

## Prerequisites

- Git repository with changes (staged or unstaged)
- GitHub CLI (gh) installed and authenticated
- Remote "origin" configured
- User has push access

## Procedure

### Stage 0: Initialization

**Verify prerequisites**:
```bash
# Check git repo
git rev-parse --git-dir > /dev/null 2>&1 || ERROR "Not a git repository"

# Check gh CLI
gh --version > /dev/null 2>&1 || ERROR "GitHub CLI required"

# Check remote
git remote get-url origin > /dev/null 2>&1 || ERROR "No origin remote"

# Get current branch
BRANCH=$(git branch --show-current)
```

**Initialize state**:
```json
{
  "version": "1.0.0",
  "branch": "<branch>",
  "stage": "INIT",
  "started_at": "<timestamp>",
  "commit": null,
  "push": null,
  "pull_request": null,
  "conflicts": [],
  "aborted": false
}
```

### Stage 1: DIFF - Review Changes

**Show changes to user**:
```bash
echo "📊 Changes to commit:"
git status --short
echo ""
echo "Summary:"
git diff --stat
```

**User interaction**:
```
📊 Changes to commit:
  M  src/file1.ts
  M  src/file2.ts
  A  src/newfile.ts
  
Summary: 3 files changed, 150 insertions(+), 25 deletions(-)

Would you like to see the full diff? (y/n/abort)
```

**Handle response**:
- `y` → Show full diff, then proceed
- `n` → Proceed without full diff
- `abort` → End workflow

**Update state**: `stage: "DIFF"`

### Stage 2: COMMIT_PENDING - Prepare Commit

**Generate commit message suggestion**:
```bash
# Analyze changes for message
FILES=$(git diff --name-only --cached 2>/dev/null || git diff --name-only)
# Generate based on file patterns and changes
```

**Show commit preview**:
```
📝 Suggested commit message:

  feat: Add user authentication endpoints
  
  - Add login endpoint
  - Add registration endpoint  
  - Add JWT token generation

Options:
  1. Use this message
  2. Edit message (type your message)
  3. Abort

Your choice:
```

**⚠️ PRINCIPLE VI CHECKPOINT**:
```
🔒 APPROVAL REQUIRED: Commit these changes?

Files to commit:
  - src/file1.ts (modified)
  - src/file2.ts (modified)
  - src/newfile.ts (new)

Message: "feat: Add user authentication endpoints"

Approve commit? (y/n/abort)
```

**CRITICAL**: Do NOT proceed until explicit "y" received.

**Update state**: `stage: "COMMIT_PENDING"`

### Stage 3: COMMITTED - Execute Commit

**Only after approval**:
```bash
# Stage all changes
git add -A

# Commit with Co-Authored-By
git commit -m "$(cat <<'EOF'
$COMMIT_MESSAGE

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"

# Capture result
COMMIT_SHA=$(git rev-parse HEAD)
```

**Report success**:
```
✅ Committed: $COMMIT_SHA
   Message: "$COMMIT_MESSAGE"
   Files: X changed (+Y, -Z)
```

**Update state**:
```json
{
  "stage": "COMMITTED",
  "commit": {
    "sha": "<sha>",
    "message": "<message>",
    "files_changed": X
  }
}
```

### Stage 4: PUSH_PENDING - Prepare Push

**Show push preview**:
```
🚀 Ready to push:

  Branch: $BRANCH
  Remote: origin
  Commits: 1 new commit(s)
  
  $COMMIT_SHA $COMMIT_MESSAGE
```

**⚠️ PRINCIPLE VI CHECKPOINT**:
```
🔒 APPROVAL REQUIRED: Push to origin?

Push $BRANCH to origin/$BRANCH? (y/n/abort)
```

**CRITICAL**: Do NOT proceed until explicit "y" received.

**Update state**: `stage: "PUSH_PENDING"`

### Stage 5: PUSHED - Execute Push

**Only after approval**:
```bash
git push -u origin $BRANCH
```

**Handle errors**:
```
IF push fails with "non-fast-forward":
  Report: "Remote has newer commits"
  Ask: "Pull and merge first? (y/n)"
  IF y:
    git pull --rebase origin $BRANCH
    Retry push (with approval)

IF push fails with "authentication":
  Report: "Authentication failed"
  Report: "Run 'gh auth login' to authenticate"
  Pause workflow
```

**Report success**:
```
✅ Pushed successfully
   Branch: origin/$BRANCH
   Upstream tracking: set
```

**Update state**:
```json
{
  "stage": "PUSHED",
  "push": {
    "success": true,
    "remote": "origin",
    "branch": "$BRANCH"
  }
}
```

**Check --no-pr flag**: If set, skip to COMPLETE

### Stage 6: PR_TARGET_PENDING - Select Target Branch

**Detect default branch**:
```bash
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name')
```

**Ask user for target**:
```
🎯 Select PR target branch:

  1. $DEFAULT_BRANCH (default)
  2. develop
  3. Other (enter branch name)
  
Target branch [1]:
```

**Update state**: `stage: "PR_TARGET_PENDING"`

### Stage 7: PR_CREATE_PENDING - Prepare PR

**Generate PR content from commits**:
```bash
# Get commits since target branch
COMMITS=$(git log $TARGET_BRANCH..HEAD --oneline)

# Generate title (from first commit or branch name)
PR_TITLE=$(git log -1 --format=%s)

# Generate body
PR_BODY="## Summary
$(git log $TARGET_BRANCH..HEAD --format='- %s')

## Test Plan
- [ ] Verify changes work as expected
- [ ] Run test suite

🤖 Generated with Claude Code"
```

**Show PR preview**:
```
📋 PR Preview:

  Title: $PR_TITLE
  Target: $TARGET_BRANCH ← $BRANCH
  
  ## Summary
  - feat: Add user authentication endpoints
  
  ## Test Plan
  - [ ] Verify changes work as expected
```

**⚠️ PRINCIPLE VI CHECKPOINT**:
```
🔒 APPROVAL REQUIRED: Create this PR?

Create PR "$PR_TITLE" targeting $TARGET_BRANCH? (y/n/edit/abort)
```

**CRITICAL**: Do NOT proceed until explicit "y" received.

**Handle "edit"**: Allow user to modify title/body before re-asking.

**Update state**: `stage: "PR_CREATE_PENDING"`

### Stage 8: PR_CREATED - Create PR

**Only after approval**:
```bash
PR_URL=$(gh pr create \
  --title "$PR_TITLE" \
  --body "$PR_BODY" \
  --base "$TARGET_BRANCH" \
  --head "$BRANCH")

PR_NUMBER=$(gh pr view --json number -q '.number')
```

**Report success**:
```
✅ PR #$PR_NUMBER created
   URL: $PR_URL
   Title: $PR_TITLE
   Target: $TARGET_BRANCH
```

**Update state**:
```json
{
  "stage": "PR_CREATED",
  "pull_request": {
    "number": X,
    "url": "<url>",
    "title": "<title>",
    "base_branch": "<target>"
  }
}
```

### Stage 9: CONFLICT_CHECK - Check Merge Status

**Query GitHub API**:
```bash
MERGE_STATUS=$(gh pr view $PR_NUMBER --json mergeable,mergeStateStatus)
MERGEABLE=$(echo $MERGE_STATUS | jq -r '.mergeable')
STATE=$(echo $MERGE_STATUS | jq -r '.mergeStateStatus')
```

**Decision tree**:
```
IF STATE == "CLEAN":
  → COMPLETE (ready to merge)
  
IF STATE == "DIRTY":
  → CONFLICT_DETECTED
  
IF STATE == "BLOCKED":
  Report: "Branch protections blocking merge"
  → COMPLETE (with warning)
  
IF STATE == "UNSTABLE":
  Report: "CI checks failing"
  → COMPLETE (with warning)
```

**Update state**: `stage: "CONFLICT_CHECK"`

### Stage 10: CONFLICT_DETECTED - Report Conflicts

**Get conflicting files**:
```bash
# Fetch and check merge
git fetch origin $TARGET_BRANCH
git merge-tree $(git merge-base HEAD origin/$TARGET_BRANCH) HEAD origin/$TARGET_BRANCH | grep -A3 "CONFLICT"
```

**Analyze and recommend**:
```
⚠️ Merge Conflicts Detected

Conflicting files:

1. package-lock.json
   Type: Lock file conflict
   Recommendation: Delete file, run 'npm install' after merge
   Auto-resolvable: Yes

2. src/utils.ts
   Type: Content conflict (lines 45-67)
   Recommendation: Review both versions, combine changes
   Auto-resolvable: No
```

**⚠️ PRINCIPLE VI CHECKPOINT**:
```
🔒 APPROVAL REQUIRED: Resolve conflicts?

Would you like me to help resolve these conflicts? (y/n/manual/abort)

Options:
  y      - Attempt automatic resolution with my guidance
  n      - Skip resolution, PR remains conflicted
  manual - I'll provide guidance, you resolve manually
  abort  - End workflow
```

**Update state**: `stage: "CONFLICT_DETECTED"`, `conflicts: [...]`

### Stage 11: CONFLICT_RESOLVING - Resolve Conflicts

**Only after approval**:

**Create backup branch first**:
```bash
git branch backup-$BRANCH-$(date +%s)
```

**For each conflict**:
```
Resolving: package-lock.json

Strategy: Delete and regenerate
Action: rm package-lock.json

Confirm this resolution? (y/n/skip)
```

**After all resolutions**:
```bash
git add -A
git commit -m "Resolve merge conflicts

Co-Authored-By: Claude <noreply@anthropic.com>"
git push origin $BRANCH
```

**Return to CONFLICT_CHECK** (loop until clean)

**Max iterations**: 5 (prevent infinite loop)

**Update state**: `stage: "CONFLICT_RESOLVING"`

### Stage 12: COMPLETE - Final Report

**Display final status**:
```
✅ Git Push Workflow Complete!

PR #$PR_NUMBER: $PR_TITLE
URL: $PR_URL
Status: Ready to merge ✓

Summary:
  ✓ Changes committed ($COMMIT_SHA)
  ✓ Pushed to origin/$BRANCH
  ✓ PR created targeting $TARGET_BRANCH
  ✓ No merge conflicts

Would you like me to monitor CI status? (y/n)
```

**Update state**: `stage: "COMPLETE"`, `completed_at: <timestamp>`

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `-m, --message` | Commit message | Auto-generated |
| `-t, --target` | PR target branch | Default branch |
| `--draft` | Create draft PR | false |
| `--no-pr` | Push only, skip PR | false |
| `--skip-commit` | Push existing commits | false |

## Error Handling

| Error | Response |
|-------|----------|
| No changes | Ask: "Push existing commits only?" |
| Auth failed | Report: "Run 'gh auth login'" |
| Push rejected | Offer: "Pull and merge first?" |
| PR exists | Offer: "Update existing PR?" |
| Max conflict iterations | Report: "Manual resolution needed" |

## Constitutional Compliance

### Principle VI: Git Operation Approval (CRITICAL)

**EVERY git operation requires explicit user approval**:

| Operation | Approval Prompt | Checkpoint |
|-----------|-----------------|------------|
| `git commit` | "Approve commit? (y/n)" | Stage 2→3 |
| `git push` | "Push to origin? (y/n)" | Stage 4→5 |
| `gh pr create` | "Create this PR? (y/n)" | Stage 7→8 |
| Conflict resolution | "Resolve conflicts? (y/n)" | Stage 10→11 |

**VIOLATION**: Any git command without prior approval is a **constitutional violation**.

### Principle IV: Idempotent Operations
- Workflow can be re-run safely
- State file tracks progress
- Partial work preserved on abort

### Principle VII: Observability
- Audit log maintained at `.claude/audit/`
- All operations logged with timestamps

## Audit Logging

**Log entry format**:
```json
{
  "timestamp": "ISO8601",
  "workflow_id": "uuid",
  "stage": "COMMITTED",
  "operation": "git commit",
  "approval_received": true,
  "result": "success",
  "details": { "sha": "abc123" }
}
```

## Validation

After execution, verify:
- [ ] User approved every git operation
- [ ] Commit includes Co-Authored-By
- [ ] PR created (unless --no-pr)
- [ ] Conflicts resolved (if any)
- [ ] Final status displayed
- [ ] Audit log updated
## Related Skills

- `domain-detection` - For PR description enhancement
- `constitutional-compliance` - For Principle VI validation
