# Framework Synchronization Guide

**Version**: 1.0.0
**Framework**: logic-loom v3.1.0
**Date**: 2026-01-09

---

## Overview

This guide explains how to use logic-loom as an **upstream source** for your projects and keep them synchronized with framework updates using the `/update-framework` command.

---

## Architecture

### Repository Relationship

```
logic-loom (UPSTREAM)
    ↓ (pulls updates from)
kelleysd.com (DOWNSTREAM PROJECT)
    ↓ (pulls updates from)
your-other-project (DOWNSTREAM PROJECT)
```

**Key Concept**: logic-loom is the **single source of truth** for:
- Constitutional principles
- Agent templates
- Workflow scripts
- Skills and commands
- Framework libraries (logging, policies, parallel execution, etc.)

---

## For Upstream (logic-loom)

### Purpose

This repository serves as the **framework source** that downstream projects sync from.

### Responsibilities

1. **Maintain constitutional integrity** (16 principles)
2. **Provide stable, tested framework updates**
3. **Document breaking changes clearly**
4. **Version framework releases** (semantic versioning)
5. **Provide migration guides** for breaking changes

### Making Framework Updates

When you make changes to the framework in this repo:

**Step 1: Document Changes**
```markdown
# In CHANGELOG.md
## [v3.2.0] - 2026-01-15

### Added
- New agent: data-migration-specialist
- Enhanced logging with trace support

### Changed
- Updated constitution Principle XII (Design System)
- Refactored common.sh for better error handling

### Breaking Changes
- Removed deprecated `old_function()` from common.sh
  Migration: Replace with `new_function()`
```

**Step 2: Tag Release**
```bash
git tag -a v3.2.0 -m "Release v3.2.0: Data migration support and enhanced logging"
git push origin v3.2.0
```

**Step 3: Update Version References**
- Update version in CLAUDE.md
- Update version in constitution.md
- Update package.json if applicable

---

## For Downstream Projects (kelleysd.com, etc.)

### Initial Setup

**One-time setup** to connect your project to the upstream framework:

```bash
cd /path/to/your-project

# Add upstream remote (if not already added)
git remote add sdd-upstream https://github.com/yourusername/logic-loom.git

# Or if using local path during development
git remote add sdd-upstream file:///c:/Users/brian/Dev\ Apps/logic-loom

# Verify remote
git remote -v
```

You should see:
```
origin          https://github.com/yourusername/your-project.git (fetch)
origin          https://github.com/yourusername/your-project.git (push)
sdd-upstream    https://github.com/yourusername/logic-loom.git (fetch)
sdd-upstream    https://github.com/yourusername/logic-loom.git (push)
```

---

### Checking for Updates

Use the `/update-framework` command to check for and apply updates:

```bash
/update-framework
```

This triggers the **framework-sync-agent** which follows a 15-step procedure.

---

### The Update Process (15 Steps)

#### Step 1: Pre-Update Assessment

**What it does**: Documents your current state
- Current Claude Code CLI version
- Current framework commit
- Active branches and uncommitted changes
- Custom modifications

**Output**: Backup report saved to `.docs/framework-updates/backup-YYYY-MM-DD.md`

---

#### Step 2: Check Claude Code CLI Updates

**What it does**: Queries GitHub for new Claude Code releases
- Fetches latest release from `https://api.github.com/repos/anthropics/claude-code/releases/latest`
- Compares with your current version
- Identifies relevant updates (features, bug fixes, security patches)

**Output**: CLI update report

**Example**:
```
Current: Claude Code v2.1.2
Latest:  Claude Code v2.2.0

Changes:
- [FEATURE] New parallel agent execution
- [BUGFIX] Fixed context loading race condition
- [SECURITY] XSS vulnerability patched
```

---

#### Step 3: Check SDD Framework Updates

**What it does**: Fetches updates from logic-loom upstream
```bash
git fetch sdd-upstream main
git diff HEAD..sdd-upstream/main -- .logic-loom/
git diff HEAD..sdd-upstream/main -- .claude/
```

**Output**: Framework update report

**Example**:
```
Upstream: 5 commits ahead

Changes:
- [AGENT] New data-migration-specialist agent
- [LIBRARY] Enhanced logging.sh with trace support
- [CONSTITUTION] Updated Principle XII
- [BUGFIX] Fixed common.sh path resolution
- [DOCS] Updated integration guide
```

---

#### Step 4: Analyze Impact

**What it does**: Assesses risk and compatibility
- **Breaking changes**: API changes, removed functions, renamed files
- **Security fixes**: Critical patches (MUST apply)
- **Custom modifications**: Detects files you've customized
- **Merge conflicts**: Predicts potential conflicts

**Risk Levels**:
- **LOW**: Documentation updates, new agents/skills, non-breaking enhancements
- **MEDIUM**: Modified core scripts, new dependencies, workflow changes
- **HIGH**: Breaking changes, constitutional amendments, major refactoring

**Output**: Impact assessment report

**Example**:
```
Impact Analysis:
- Breaking Changes: 1 (removed old_function from common.sh)
- Security Fixes: 1 (XSS patch in logging.sh)
- Custom Files Affected: 2 (.logic-loom/scripts/bash/common.sh, CLAUDE.md)
- Predicted Conflicts: 0

Risk Level: MEDIUM

Recommendation: APPLY WITH CAUTION
- Backup current state
- Review breaking changes
- Test in isolation before production
```

---

#### Step 5: User Approval Gate ⚠️

**MANDATORY** (Constitutional Principle VI)

**What happens**: You are presented with:
- Complete change summary
- Risk assessment
- Files that will be modified
- Recommended approach

**You decide**:
```
Proceed with update? [y/N]
  - y: Continue to backup and apply
  - N: Abort (safe, no changes made)
  - r: Review detailed diff first
```

---

#### Step 6: Backup Current State

**What it does**: Creates safety checkpoint
```bash
# Create backup branch
git checkout -b backup/pre-update-2026-01-09

# Tag current state
git tag -a pre-update-v3.1.0 -m "Backup before framework v3.2.0 update"

# Return to working branch
git checkout main
```

**Output**: Backup reference for rollback

---

#### Step 7: Apply CLI Updates

**What it does**: Updates Claude Code CLI (if applicable)
```bash
# macOS/Linux
brew upgrade claude-code

# Or manual download
# Download from GitHub releases
```

**Validation**: Verify new version installed
```bash
claude --version
# Expected: 2.2.0
```

---

#### Step 8: Apply Framework Updates

**What it does**: Selectively merges upstream changes

**Strategy A: Cherry-pick specific commits** (RECOMMENDED for complex projects)
```bash
# Merge only specific framework updates
git cherry-pick abc123  # New agent
git cherry-pick def456  # Bug fix
git cherry-pick ghi789  # Documentation
```

**Strategy B: Merge all changes** (for simple projects or full sync)
```bash
git merge sdd-upstream/main --no-ff --no-commit
```

**What gets updated**:
- ✅ `.logic-loom/lib/` (framework libraries)
- ✅ `.logic-loom/scripts/bash/` (workflow scripts)
- ✅ `.claude/agents/` (agent templates)
- ✅ `.claude/skills/` (skills and commands)
- ✅ `.logic-loom/memory/constitution.md` (if updated)
- ⚠️ `CLAUDE.md` (manually merge to preserve customizations)

**What stays yours**:
- ❌ Project-specific files (src/, components/, etc.)
- ❌ `.env` and secrets
- ❌ Custom agents you created
- ❌ Project-specific documentation

---

#### Step 9: Reconcile Customizations

**What it does**: Preserves your project-specific changes

**Common customizations**:
1. **CLAUDE.md** - Your project intro, MCP configs, custom sections
2. **common.sh** - Project-specific helper functions
3. **Custom agents** - Agents you created for your domain
4. **constitution.md** - Project-specific principle customizations

**Manual merge required for**:
```
<<<<<<< HEAD (your version)
Your custom content
=======
Upstream update
>>>>>>> sdd-upstream/main
```

**How to resolve**:
1. Keep your customizations
2. Integrate new upstream features
3. Remove conflicts
4. Test merged version

**Example** (CLAUDE.md):
```markdown
# Keep your project intro
This is kelleysd.com - a personal website with blog and portfolio

# Add upstream enhancements
## Framework v3.2.0 Enhancements
- Enhanced logging with trace support
- New data-migration-specialist agent

# Preserve your MCP configs
## MCP Servers (kelleysd.com specific)
- Supabase: Database and auth
- Vercel: Deployment
```

---

#### Step 10: Run Validation Suite

**What it does**: Validates framework integrity

```bash
# Constitutional compliance
./.logic-loom/scripts/bash/constitutional-check.sh

# Framework sanitization
./.logic-loom/scripts/bash/sanitization-audit.sh

# Run tests (if applicable)
npm test  # or pytest, etc.
```

**Expected**:
```
✅ Constitutional compliance: 14/15 passing
✅ No framework-specific content in project files
✅ All tests passing
```

**If failures**:
- Review breaking changes
- Update incompatible code
- Re-run validation

---

#### Step 11: Test in Isolation

**What it does**: Verify no regressions

**Test checklist**:
```bash
# 1. Test logging
source .logic-loom/lib/logging.sh
log_info "Test message"

# 2. Test git safety
source .logic-loom/scripts/bash/common.sh
create_git_checkpoint "test"

# 3. Test policy validation
source .logic-loom/lib/policy.sh
validate_tool_call "bash" "echo hello"

# 4. Test context loading
./.logic-loom/scripts/bash/load-context.sh list

# 5. Test parallel execution (if used)
source .logic-loom/lib/parallel.sh

# 6. Test your project-specific features
npm run dev  # or your startup command
```

**Validate**:
- ✅ Framework features work
- ✅ Your project still runs
- ✅ No console errors
- ✅ Agent delegation works

---

#### Step 12: Update Documentation

**What it does**: Syncs docs with changes

**Update files**:
1. **CHANGELOG.md** - Log framework update
```markdown
## [2026-01-09] Framework Update

### Updated from logic-loom v3.1.0 → v3.2.0

#### Framework Changes Applied
- Enhanced logging.sh with trace support
- New data-migration-specialist agent
- Updated constitutional Principle XII

#### Breaking Changes
- Removed `old_function()` from common.sh
- Migrated to `new_function()`

#### Project-Specific Changes
- Updated CLAUDE.md with new framework features
- Preserved kelleysd.com-specific MCP configurations
```

2. **README.md** - Update version references
```markdown
Framework: logic-loom v3.2.0
Claude Code: v2.2.0
```

3. **Version files** (if applicable)
```json
// package.json or version.json
{
  "framework-version": "3.2.0",
  "updated": "2026-01-09"
}
```

---

#### Step 13: Commit Updates ⚠️

**REQUIRES USER APPROVAL** (Principle VI)

**Review changes**:
```bash
git status
git diff --stat
```

**Commit with descriptive message**:
```bash
git add .
git commit -m "chore(framework): Update to logic-loom v3.2.0

Framework Updates:
- Enhanced logging.sh with trace support
- New data-migration-specialist agent
- Updated constitutional Principle XII (Design System)
- Bug fix: common.sh path resolution

Project Customizations Preserved:
- kelleysd.com-specific CLAUDE.md sections
- Supabase and Vercel MCP configurations
- Custom portfolio-generator agent

Breaking Changes Applied:
- Migrated old_function() → new_function() in common.sh

Testing:
- All constitutional checks passing (14/15)
- Framework features validated
- Project runs without errors

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

#### Step 14: Post-Update Verification

**What it does**: Production readiness check

**Verification steps**:
1. **Restart services**
```bash
npm run dev
# or docker-compose up
# or your deployment command
```

2. **Smoke test key features**
- Login/authentication
- Database operations
- API endpoints
- UI rendering
- Agent interactions

3. **Monitor logs**
```bash
tail -f .logic-loom/logs/operations/$(date +%Y-%m-%d).log
```

4. **Verify metrics**
- Response times
- Error rates
- Resource usage

**If issues found**:
- Document in `.docs/framework-updates/issues-YYYY-MM-DD.md`
- Rollback if critical (see Step 15)
- Report upstream if framework bug

---

#### Step 15: Cleanup and Rollback Path

**What it does**: Finalizes update or provides rollback

**On success**:
```bash
# Tag successful update
git tag -a post-update-v3.2.0 -m "Successfully updated to framework v3.2.0"

# Optional: Delete backup branch (after confidence period)
# Keep for 30 days recommended
git branch -D backup/pre-update-2026-01-09  # After 30 days

# Document rollback path (just in case)
echo "Rollback: git reset --hard pre-update-v3.1.0" > .docs/framework-updates/rollback.txt
```

**On failure** (Rollback):
```bash
# Option 1: Reset to backup tag
git reset --hard pre-update-v3.1.0
git clean -fd

# Option 2: Restore from backup branch
git checkout backup/pre-update-2026-01-09
git checkout -b main-restored
git branch -D main
git branch -m main

# Verify rollback
claude --version  # Should show previous version
git log -1        # Should show pre-update commit
```

---

## Recommended Update Schedule

| Update Type | Priority | Schedule | Process |
|-------------|----------|----------|---------|
| **Security Patches** | CRITICAL | Same day | Full 15-step process |
| **Bug Fixes** | HIGH | Within 1 week | Full 15-step process |
| **New Features** | MEDIUM | Monthly | Full 15-step process |
| **Documentation** | LOW | Quarterly | Steps 1-3, 12-13 only |
| **Breaking Changes** | VARIES | Coordinate | Plan migration, then full process |

---

## Common Scenarios

### Scenario 1: Security Patch (URGENT)

**Timeline**: Same day

```bash
# Quick path for security updates
/update-framework

# At Step 4 (Impact Analysis)
# Risk: HIGH (security fix)
# Recommendation: APPLY IMMEDIATELY

# Approve at Step 5
y

# Steps 6-15 proceed automatically (with approval gates)

# Result: Security patched within hours
```

---

### Scenario 2: New Agent Added Upstream

**Timeline**: Next monthly maintenance window

```bash
/update-framework

# At Step 3 (Framework Updates)
# New: data-migration-specialist agent at .claude/agents/engineering/

# At Step 4 (Impact Analysis)
# Risk: LOW (new file, no conflicts)
# Recommendation: SAFE TO APPLY

# Approve at Step 5
y

# Result: New agent available in your project
```

---

### Scenario 3: Breaking Change in common.sh

**Timeline**: Coordinate with team, plan migration

```bash
/update-framework

# At Step 4 (Impact Analysis)
# Breaking: old_function() removed from common.sh
# Your project uses old_function() in 3 files
# Risk: HIGH
# Recommendation: MANUAL MIGRATION REQUIRED

# At Step 5
# Decision: Review changes first
r

# Review detailed diff
git diff HEAD..sdd-upstream/main -- .logic-loom/scripts/bash/common.sh

# Plan migration
# 1. Identify all usages of old_function()
# 2. Replace with new_function()
# 3. Test changes
# 4. Then run /update-framework and approve

# After migration complete
/update-framework
y  # Approve with confidence
```

---

### Scenario 4: Customized File Conflict

**Timeline**: Requires manual merge

```bash
/update-framework

# At Step 9 (Reconcile Customizations)
# Conflict in CLAUDE.md
# Your version: Custom project intro
# Upstream: New framework section

# Manual merge required
git checkout --ours CLAUDE.md     # Keep your version
# Then manually add upstream content

# Or use merge tool
git mergetool CLAUDE.md

# Result: Best of both versions
```

---

## Best Practices

### 1. Regular Updates

✅ **DO**: Update monthly during maintenance windows
✅ **DO**: Apply security patches immediately
✅ **DO**: Test updates in staging before production
❌ **DON'T**: Let updates accumulate (harder to merge)
❌ **DON'T**: Skip validation steps

### 2. Custom Modifications

✅ **DO**: Document all framework customizations
✅ **DO**: Keep customizations in separate files when possible
✅ **DO**: Use clearly marked sections in shared files
❌ **DON'T**: Modify framework core without noting it
❌ **DON'T**: Assume upstream will preserve your changes

**Example** (CLAUDE.md):
```markdown
<!-- ============================================== -->
<!-- PROJECT-SPECIFIC SECTION: kelleysd.com BEGIN -->
<!-- ============================================== -->

## kelleysd.com MCP Servers
- Supabase: Database and authentication
- Vercel: Deployment

<!-- ============================================== -->
<!-- PROJECT-SPECIFIC SECTION: kelleysd.com END   -->
<!-- ============================================== -->
```

### 3. Backup Strategy

✅ **DO**: Create backup branch before updates
✅ **DO**: Tag pre-update state
✅ **DO**: Keep backups for 30 days minimum
✅ **DO**: Document rollback procedure
❌ **DON'T**: Update without backup
❌ **DON'T**: Delete backups immediately

### 4. Communication

✅ **DO**: Announce breaking changes to team
✅ **DO**: Document migration steps
✅ **DO**: Test with team before merging
✅ **DO**: Report issues upstream
❌ **DON'T**: Surprise team with breaking changes
❌ **DON'T**: Apply updates during critical periods

---

## Troubleshooting

### Issue: Merge Conflicts

**Symptom**: Git reports conflicts during Step 8

**Solution**:
```bash
# Identify conflicts
git status

# For each conflicted file
git diff <file>

# Resolve manually or use tool
git mergetool <file>

# Mark resolved
git add <file>

# Continue
git merge --continue
```

---

### Issue: Validation Failures

**Symptom**: constitutional-check.sh fails after update

**Solution**:
1. Review which principle failed
2. Check if upstream introduced non-compliance
3. Report to upstream if framework issue
4. Fix project code if project issue
5. Re-run validation

---

### Issue: Broken Features After Update

**Symptom**: Project features stop working

**Solution**:
```bash
# Immediate rollback
git reset --hard pre-update-v3.1.0

# Investigate
git log --oneline sdd-upstream/main
git diff pre-update-v3.1.0..sdd-upstream/main

# Find breaking change
# Test fix in isolation
# Re-apply update with fix
```

---

### Issue: Lost Customizations

**Symptom**: Your custom content overwritten

**Solution**:
```bash
# Restore from backup
git checkout backup/pre-update-2026-01-09 -- <file>

# Extract your customizations
git diff backup/pre-update-2026-01-09 HEAD -- <file>

# Manually re-apply
# Edit file to include both upstream + your changes

# Commit
git add <file>
git commit -m "fix: Restore customizations lost in merge"
```

---

## Framework Update Workflow (Visual)

```
┌─────────────────────────────────────────────────────────┐
│ 1. Pre-Update Assessment                                │
│    • Document current state                             │
│    • Check for uncommitted changes                      │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 2-3. Check for Updates                                  │
│      • Claude Code CLI releases                         │
│      • logic-loom commits                    │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 4. Impact Analysis                                      │
│    • Breaking changes?                                  │
│    • Security fixes?                                    │
│    • Risk level?                                        │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 5. ⚠️  USER APPROVAL GATE                              │
│     • Review summary                                    │
│     • Approve or abort                                  │
└────────────────────┬────────────────────────────────────┘
                     ↓ (if approved)
┌─────────────────────────────────────────────────────────┐
│ 6. Backup Current State                                 │
│    • Create backup branch                               │
│    • Tag current commit                                 │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 7-8. Apply Updates                                      │
│      • Update CLI (if needed)                           │
│      • Merge framework changes                          │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 9. Reconcile Customizations                             │
│    • Preserve project-specific changes                  │
│    • Manually merge conflicts                           │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 10-11. Validation & Testing                             │
│        • Run constitutional-check.sh                    │
│        • Test key features                              │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 12. Update Documentation                                │
│     • CHANGELOG.md                                      │
│     • Version references                                │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 13. ⚠️  COMMIT APPROVAL GATE                           │
│      • Review changes                                   │
│      • Approve commit                                   │
└────────────────────┬────────────────────────────────────┘
                     ↓ (if approved)
┌─────────────────────────────────────────────────────────┐
│ 14-15. Post-Update & Cleanup                            │
│        • Verify in production                           │
│        • Document rollback path                         │
└─────────────────────────────────────────────────────────┘
```

---

## Quick Reference

### Essential Commands

```bash
# Check for updates
/update-framework

# Manual upstream check
git fetch sdd-upstream main
git log HEAD..sdd-upstream/main --oneline

# View framework changes
git diff HEAD..sdd-upstream/main -- .logic-loom/ .claude/

# Create backup
git checkout -b backup/pre-update-$(date +%Y-%m-%d)
git tag -a pre-update-v$(date +%Y%m%d) -m "Backup before update"

# Apply framework updates (cherry-pick)
git cherry-pick abc123  # Specific commit

# Apply framework updates (merge)
git merge sdd-upstream/main --no-ff --no-commit

# Validate
./.logic-loom/scripts/bash/constitutional-check.sh
./.logic-loom/scripts/bash/sanitization-audit.sh

# Rollback
git reset --hard pre-update-v20260109
```

### File Locations

| File/Directory | Purpose |
|----------------|---------|
| `.logic-loom/lib/` | Framework libraries (logging, policy, parallel) |
| `.logic-loom/scripts/bash/` | Workflow scripts (common.sh, etc.) |
| `.claude/agents/` | Agent templates |
| `.claude/skills/` | Skills and commands |
| `.logic-loom/memory/constitution.md` | Constitutional principles |
| `CLAUDE.md` | Project instructions (merge carefully) |
| `.docs/framework-updates/` | Update logs and backups |

---

## Contributing Framework Updates

If you create improvements in your downstream project that would benefit others:

**Step 1: Identify Reusable Component**
- New agent that's domain-agnostic
- Enhanced framework script
- Bug fix in framework code
- Improved documentation

**Step 2: Extract to Framework Format**
- Remove project-specific content
- Generalize functionality
- Add clear documentation
- Follow framework conventions

**Step 3: Submit to Upstream**
```bash
# Create feature branch
git checkout -b feature/your-improvement

# Commit changes
git add .
git commit -m "feat: Add <improvement description>"

# Push to your fork
git push origin feature/your-improvement

# Create pull request to logic-loom
```

**Step 4: After Merge**
- Your improvement becomes part of framework
- All downstream projects can pull it
- You get credited as contributor

---

## Support

### Documentation
- Framework Guide: `.docs/guides/FRAMEWORK_SYNC_GUIDE.md` (this file)
- Integration Plan: `.docs/reports/FRAMEWORK_ENHANCEMENTS_INTEGRATION_PLAN.md`
- Compatibility Analysis: `.docs/reports/FRAMEWORK_ENHANCEMENTS_COMPATIBILITY_ANALYSIS.md`

### Commands
- `/update-framework` - Main update command
- `constitutional-check.sh` - Validate compliance
- `sanitization-audit.sh` - Check framework purity

### Agents
- **framework-sync-agent** - Handles updates automatically

---

**Version**: 1.0.0
**Last Updated**: 2026-01-09
**Framework**: logic-loom v3.1.0
**Maintained By**: Framework maintainers

---

## Troubleshooting: Hook Issues After Sync

### ES Module Projects

If your project has `"type": "module"` in `package.json`, the Node.js governance hook may fail.

**Symptoms**:
- `UserPromptSubmit hook error`
- No governance context injected

**Fix Options**:

1. **Rename to `.cjs`** (if using Node.js hook):
   ```bash
   mv .claude/hooks/user-prompt-submit/governance-preflight.js \
      .claude/hooks/user-prompt-submit/governance-preflight.cjs
   ```
   Then update settings.json to reference `.cjs`

2. **Use bash version** (recommended - universal):
   ```json
   {
     "command": "bash .claude/hooks/user-prompt-submit/governance-preflight.sh"
   }
   ```

**Full documentation**: `.docs/troubleshooting/governance-hook-esm-fix.md`

### hookEventName Missing

If you see hook validation errors, ensure the hook output includes:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",  // REQUIRED
    "additionalContext": "..."
  }
}
```

This was fixed in framework v3.1.3.
