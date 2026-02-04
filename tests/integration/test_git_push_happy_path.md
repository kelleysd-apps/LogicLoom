# Integration Test: Git-Push Happy Path (TS-101)

**Scenario**: Complete workflow without conflicts
**Test ID**: IT-GIT-001
**Status**: FAILING (Implementation pending)

---

## Test Setup

**Preconditions**:
- Repository with uncommitted changes
- Remote origin configured
- gh CLI authenticated
- Target branch (main) clean

**Test Environment**:
- Branch: feature-test-branch
- Changes: 3 modified files
- Target: main branch

---

## Test Execution Steps

### Step 1: DIFF Stage
```
Trigger: /git-push
Expected: Changes displayed
```
- [ ] `git status` output shown
- [ ] File change count: 3 files
- [ ] Diff summary displayed
- [ ] User prompted to continue

**User Action**: Approve (y)

### Step 2: COMMIT Stage
```
Trigger: User approved diff review
Expected: Commit message suggested
```
- [ ] Suggested message based on changes
- [ ] Preview displayed
- [ ] User asked for approval

**User Action**: Approve commit (y)

- [ ] `git commit` executed
- [ ] Co-Authored-By line included
- [ ] Commit SHA displayed

### Step 3: PUSH Stage
```
Trigger: Commit successful
Expected: Push preview shown
```
- [ ] Push target displayed (origin/feature-test-branch)
- [ ] User asked for approval

**User Action**: Approve push (y)

- [ ] `git push -u origin feature-test-branch` executed
- [ ] Push successful
- [ ] Upstream tracking set

### Step 4: PR TARGET Stage
```
Trigger: Push successful
Expected: Target branch selection
```
- [ ] Available branches listed
- [ ] Default (main) highlighted
- [ ] User asked to select

**User Action**: Select "main"

### Step 5: PR CREATE Stage
```
Trigger: Target selected
Expected: PR preview shown
```
- [ ] Title generated from commits
- [ ] Body generated with summary
- [ ] Test plan section included
- [ ] User asked for approval

**User Action**: Approve PR creation (y)

- [ ] `gh pr create` executed
- [ ] PR number returned
- [ ] PR URL displayed

### Step 6: CONFLICT CHECK Stage
```
Trigger: PR created
Expected: Clean merge status
```
- [ ] `gh pr view --json mergeable` executed
- [ ] mergeStateStatus == "CLEAN"
- [ ] "Ready to merge" displayed

### Step 7: COMPLETE Stage
```
Trigger: No conflicts
Expected: Final summary
```
- [ ] PR URL displayed prominently
- [ ] Status: Ready to merge
- [ ] Optional: Monitor CI offered

---

## Expected Console Output

```
🚀 Git Push Workflow

📊 Stage 1: Review Changes
   Modified: 3 files (+150, -25)
   Approve? (y/n) y ✓

📝 Stage 2: Commit
   Message: "feat: Add user management endpoints"
   Approve? (y/n) y ✓
   Committed: abc1234

🚀 Stage 3: Push  
   Push to origin/feature-test-branch? (y/n) y ✓
   Pushed successfully

🎯 Stage 4: Select PR Target
   Target: main ✓

📋 Stage 5: Create PR
   Title: "feat: Add user management endpoints"
   Approve? (y/n) y ✓
   PR #42 created

🔍 Stage 6: Conflict Check
   Status: Clean ✓

✅ Complete!
   PR: https://github.com/owner/repo/pull/42
   Status: Ready to merge
```

---

## Validation Checklist

- [ ] All 7 stages completed
- [ ] User approval obtained at each gate
- [ ] Commit includes Co-Authored-By
- [ ] PR created successfully
- [ ] No conflicts detected
- [ ] Final URL displayed
- [ ] Total time < 2 minutes

---

## Principle VI Compliance Check

| Operation | Approval Asked | Approval Received |
|-----------|----------------|-------------------|
| Commit | ✓ | ✓ |
| Push | ✓ | ✓ |
| PR Create | ✓ | ✓ |

**Compliance**: ✓ All git operations approved

---

## Current Status

**Result**: ❌ FAILING (Implementation pending)

**Reason**: Git-push workflow skill not yet implemented
