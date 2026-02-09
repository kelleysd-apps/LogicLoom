---
name: update-framework
description: Monitor and apply updates from upstream sdd-agentic-framework using proposal-based selective adoption.
model: opus
---

# /update-framework Command

**SKILL ACTIVATION**: Activate the framework-updater skill at `plugins/sdd-maintenance/skills/framework-updater/SKILL.md`.

## Execution Instructions

### Step 1: Pre-Assessment
```bash
claude --version
cat .sdd-sync-ref 2>/dev/null || echo "No sync ref found"
```

### Step 2: Fetch Upstream
```bash
git remote -v | grep -q upstream || git remote add upstream https://github.com/kelleysd-apps/sdd-agentic-framework.git
git fetch upstream main
```

### Step 3: Extract Enhancement Proposals
```bash
bash plugins/sdd-maintenance/scripts/extract-proposals.sh
```

This diffs ONLY upstream's own history (`sync-ref..upstream/main`).
It does NOT compare downstream content against upstream.

### Step 4: Present Proposals to User
Show categorized proposals: new files, enhancements, structural changes.
Each proposal is independently accept/reject.

### Step 5: Apply Accepted Proposals (with user approval)
**Principle VI**: Ask user before any git operations.
- New files: copy from upstream
- Modified files: additive merge or replace (if unmodified downstream)
- Structural changes: manual review only

### Step 6: Update Sync Reference
```bash
git rev-parse upstream/main > .sdd-sync-ref
```

### Step 7: Validate
Run full test suite to confirm framework integrity.

## Usage
```
/update-framework
/update-framework --check-only
```
