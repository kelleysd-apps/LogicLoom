# Framework Updater Skill - Quick Reference

**Created**: 2026-01-09
**Status**: Active
**Command**: `/update-framework`
**Agent**: `framework-sync-agent`

---

## Overview

The **framework-updater** skill provides a comprehensive 15-step workflow for safely monitoring and applying updates from:
1. Claude Code CLI releases (via GitHub API)
2. Upstream sdd-agentic-framework repository (via git)
3. Constitutional principle updates

---

## Quick Start

### Check for Updates

```bash
/update-framework
```

The skill will:
1. Check your current Claude Code CLI version
2. Query GitHub for latest releases
3. Fetch upstream framework changes
4. Analyze impact and breaking changes
5. Request your approval before applying
6. Create safety backups
7. Apply updates selectively
8. Validate constitutional compliance
9. Test in isolated environment
10. Update documentation
11. Commit with detailed message (requires approval)

---

## Files Created

### Skill Files

| File | Purpose | Lines |
|------|---------|-------|
| `SKILL.md` | Complete 15-step workflow procedure | 712 |
| `README.md` | This quick reference | 120 |

### Integration Files

| File | Purpose | Status |
|------|---------|--------|
| `.claude/commands/update-framework.md` | VS Code command file | ✅ Created |
| `.claude/agents/operations/framework-sync-agent.md` | Execution agent | ✅ Created |
| `CLAUDE.md` | Quick command reference | ✅ Registered |
| `.specify/memory/agent-collaboration-triggers.md` | Trigger keywords | ✅ Registered |

---

## Agent Details

**Name**: `framework-sync-agent`
**Department**: Operations
**Location**: `.claude/agents/operations/framework-sync-agent.md`

**Capabilities**:
- GitHub API queries for release information
- Git upstream synchronization
- Version comparison and diff analysis
- Breaking change assessment
- Safe merging with conflict resolution
- Constitutional compliance validation
- Backup and rollback procedures

**Tools**:
- Bash (git operations with approval)
- Read/Write (update reports, file modifications)
- Grep/Glob (file analysis)
- WebFetch/WebSearch (GitHub API, release notes)
- TodoWrite (progress tracking)

---

## Workflow Summary

### Phase 1: Assessment (Steps 1-4)
- Document current state
- Check Claude Code CLI version
- Check upstream framework commits
- Analyze impact (LOW/MEDIUM/HIGH risk)

### Phase 2: Approval & Backup (Steps 5-6)
- **Step 5**: Present findings, request explicit user approval
- **Step 6**: Create safety backup branch

### Phase 3: Application (Steps 7-9)
- Update Claude Code CLI
- Merge upstream framework changes
- Reconcile project customizations

### Phase 4: Validation (Steps 10-11)
- Run constitutional-check.sh
- Test sample workflows
- Verify no regressions

### Phase 5: Finalization (Steps 12-15)
- Update CHANGELOG and documentation
- **Step 13**: Commit with detailed message (requires approval)
- Post-update verification
- Cleanup and document rollback path

---

## Trigger Keywords

The `/update-framework` command is automatically suggested when you mention:

**Update Keywords**:
- "update framework", "sync framework", "upgrade framework"
- "check for updates", "latest version", "new release"
- "framework version", "CLI update"

**Upstream Keywords**:
- "upstream changes", "pull from upstream"
- "sdd-agentic-framework updates"

**Component Keywords**:
- "claude code release", "github release"
- "constitution update", "new principles"
- "security patch", "bug fix update"

---

## Constitutional Compliance

This skill enforces strict compliance with:

### Principle VI: Git Operations
- **Step 5**: User approval REQUIRED before proceeding
- **Step 6**: Backup branch creation (requires approval)
- **Step 13**: Commit requires explicit approval
- **NO** automatic git operations

### Principle VII: Observability
- Detailed logs at each step
- Update reports (version comparison, impact assessment)
- Structured audit trail

### Principle VIII: Documentation Sync
- **Step 12**: Updates CHANGELOG with version changes
- Updates version references in CLAUDE.md
- Creates migration notes for breaking changes

### Principle IX: Dependency Management
- Explicitly tracks CLI version
- Pins framework commit SHA
- Documents all version changes

---

## Update Schedule (Recommended)

| Update Type | Priority | Timeline | Example |
|-------------|----------|----------|---------|
| **Security Patches** | CRITICAL | Apply same day | XSS vulnerability fix |
| **Bug Fixes** | HIGH | Review within 1 week | Script error correction |
| **New Features** | MEDIUM | Review monthly | New agent templates |
| **Breaking Changes** | VARIES | Coordinate with team | Constitution v2.0.0 |

---

## Common Use Cases

### Use Case 1: Monthly Maintenance

**Scenario**: First Monday of the month maintenance window

**Command**: `/update-framework`

**Expected Output**:
```
Framework Update Check - 2026-01-09
------------------------------------

Claude Code CLI:
  Current: v1.2.3
  Latest:  v1.3.0
  Changes: 2 bug fixes, 1 new feature

SDD Framework:
  Current: abc123 (2026-01-01)
  Latest:  def456 (2026-01-09)
  Changes: 5 commits (1 security fix, 2 docs updates, 2 new skills)

Impact: MEDIUM (no breaking changes)
Recommendation: APPLY ALL UPDATES

Proceed? [y/N]
```

---

### Use Case 2: Security Patch

**Scenario**: Security advisory for Claude Code CLI

**Command**: `/update-framework`

**Priority**: IMMEDIATE (apply same day)

**Workflow**:
1. Check release notes for security fix details
2. Backup current state
3. Apply CLI update only (skip framework if unrelated)
4. Validate fix applied
5. Commit with security patch note

---

### Use Case 3: Constitution Update

**Scenario**: New constitutional principle published upstream

**Command**: `/update-framework`

**Special Considerations**:
- Review new principle carefully
- Update affected feature specs
- Update constitutional-customizations.md
- Check if PRD references need updates
- Communicate changes to team

---

## Rollback Procedure

If updates cause issues:

1. **Identify backup branch**:
   ```bash
   git branch | grep backup-before-framework-update
   ```

2. **Restore from backup**:
   ```bash
   git checkout backup-before-framework-update-YYYYMMDD-HHMMSS
   git checkout -b rollback-framework-update
   ```

3. **Verify restoration**:
   ```bash
   claude --version
   git log --oneline -1 .specify/
   ```

4. **Document rollback reason** in `.framework-update-log`

---

## Troubleshooting

### Issue: Merge Conflicts

**Solution**: Use three-way merge for customized files, accept upstream for canonical files (constitution.md)

### Issue: CLI Upgrade Fails

**Solution**: Try alternative installation method (direct download from GitHub)

### Issue: Validation Scripts Fail

**Solution**: Compare script changes in diff, rollback if broken, report issue upstream

### Issue: Custom Agents Break

**Solution**: Compare against new agent template, update to match structure

---

## Related Commands

- `/create-agent` - May use updated templates after sync
- `/create-skill` - May use updated templates after sync
- `/specify`, `/plan`, `/tasks` - Behavior may change if constitution updated
- `/debug` - May be needed if updates cause issues

---

## Future Enhancements

Potential improvements for future versions:

1. **Automatic Scheduling**: Cron-like scheduling for monthly checks
2. **Slack/Email Notifications**: Alert when updates available
3. **Dry-Run Mode**: Preview changes without applying
4. **Selective Updates**: Update only CLI or only framework
5. **Version Pinning**: Pin specific framework version in config
6. **Changelog Parsing**: Automatic risk assessment from changelogs

---

## Support

**Skill Location**: `.claude/skills/integration/framework-updater/SKILL.md`
**Agent Location**: `.claude/agents/operations/framework-sync-agent.md`
**Command File**: `.claude/commands/update-framework.md`
**Documentation**: `CLAUDE.md` (search for "Framework Maintenance Commands")

**Questions?** Review the complete SKILL.md file for detailed step-by-step procedures.

---

**Version**: 1.0.0
**Last Updated**: 2026-01-09
**Status**: Production Ready
