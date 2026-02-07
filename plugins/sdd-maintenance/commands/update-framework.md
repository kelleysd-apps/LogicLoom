---
name: update-framework
description: Monitor and apply updates from Claude Code releases and upstream sdd-agentic-framework repository.
model: opus
---

# /update-framework Command

**SKILL ACTIVATION**: Activate the framework-updater skill at `plugins/sdd-maintenance/skills/framework-updater/SKILL.md`.

## Execution Instructions

### Step 1: Check Claude Code Version
```bash
claude --version
```
Compare with latest release.

### Step 2: Check Upstream Framework
```bash
git fetch upstream 2>/dev/null || git remote add upstream https://github.com/kelleysd-apps/sdd-agentic-framework.git && git fetch upstream
git log upstream/main --oneline -10
```

### Step 3: Show Available Updates
Display: current version, available updates, changelog entries.

### Step 4: Apply Updates (with user approval)
**Principle VI**: Ask user before any git operations.
- Merge upstream changes
- Run tests to verify compatibility
- Report results

### Step 5: Validate
Run full test suite to confirm framework integrity.

## Usage
```
/update-framework
/update-framework --check-only
```
