# Framework Updater Skill

---
name: framework-updater
description: |
  Monitors and applies updates from Claude Code releases and upstream sdd-agentic-framework repository.
  Ensures your project stays current with latest features, bug fixes, and best practices.
allowed-tools: Read, Write, Bash, Grep, Glob, WebFetch, WebSearch
---

## When to Use

Use `/update-framework` when:
- You want to check for new Claude Code CLI releases
- You need to sync updates from upstream sdd-agentic-framework
- A new constitutional principle or best practice has been published
- You're experiencing issues that may be fixed in newer versions
- You want to adopt new agent patterns or skills from the framework
- Monthly maintenance window (recommended: first Monday of each month)

## Procedure

### Step 1: Pre-Update Assessment

**Action**: Assess current state and identify what needs updating

**Tasks**:
1. Check current Claude Code version:
   ```bash
   claude --version
   ```

2. Check current SDD framework commit:
   ```bash
   git log --oneline -1 .specify/
   ```

3. Document current state:
   - Active feature branches
   - Uncommitted changes
   - Custom modifications to framework files

**Validation**: Create backup report with current versions

---

### Step 2: Check Claude Code CLI Updates

**Action**: Query latest Claude Code releases from GitHub

**Tasks**:
1. Fetch latest release info:
   ```bash
   # Check GitHub releases API
   curl -s https://api.github.com/repos/anthropics/claude-code/releases/latest
   ```

2. Compare with current version
3. Review release notes for breaking changes
4. Identify relevant updates:
   - New features that benefit this project
   - Bug fixes for issues you've encountered
   - Security patches (HIGH PRIORITY)
   - Breaking changes requiring migration

**Validation**: Generate update report with version comparison

---

### Step 3: Check SDD Framework Updates

**Action**: Query upstream sdd-agentic-framework repository

**Tasks**:
1. Check if upstream remote exists:
   ```bash
   git remote -v | grep -q 'sdd-agentic-framework' || \
     git remote add upstream https://github.com/yourusername/sdd-agentic-framework.git
   ```

2. Fetch upstream changes:
   ```bash
   git fetch upstream main
   ```

3. Compare framework files:
   ```bash
   # Check for updates to core framework files
   git diff HEAD..upstream/main -- .specify/
   git diff HEAD..upstream/main -- .claude/agents/
   git diff HEAD..upstream/main -- .claude/skills/
   ```

4. Review changes:
   - New constitutional principles
   - Updated agent templates
   - New skills or workflows
   - Bug fixes in scripts
   - Documentation updates

**Validation**: Generate diff report showing what changed upstream

---

### Step 4: Analyze Update Impact

**Action**: Assess impact of updates on current project

**Tasks**:
1. **Breaking Changes Assessment**:
   - Check if constitution version changed (v1.5.0 → v1.6.0)
   - Identify deprecated patterns or commands
   - Review migration requirements

2. **Compatibility Check**:
   - Verify updates don't conflict with custom agents/skills
   - Check if project-specific customizations need adjustments
   - Identify files that will be overwritten vs. merged

3. **Benefit Analysis**:
   - List new features applicable to this project
   - Identify performance improvements
   - Document security enhancements

**Validation**: Create impact report with risk assessment (LOW/MEDIUM/HIGH)

---

### Step 5: User Approval Gate

**Action**: Present findings and request approval

**Output Format**:
```
Framework Update Available
--------------------------

Claude Code CLI:
  Current: v1.2.3
  Latest:  v1.3.0
  Impact:  MEDIUM (new agent delegation features)

SDD Framework:
  Current: abc123 (2026-01-01)
  Latest:  def456 (2026-01-09)
  Impact:  LOW (documentation updates, 1 new skill)

Breaking Changes: None
Security Fixes:   Yes (XSS vulnerability in skill template)

Recommended Action: APPLY ALL UPDATES

Apply updates? [y/N]
```

**CRITICAL**: NEVER proceed without explicit user approval (Principle VI)

**Validation**: User provides explicit "yes" or "y" confirmation

---

### Step 6: Backup Current State

**Action**: Create safety backup before applying updates

**Tasks**:
1. Create backup branch:
   ```bash
   BACKUP_BRANCH="backup-before-framework-update-$(date +%Y%m%d-%H%M%S)"
   git checkout -b "$BACKUP_BRANCH"
   git add -A
   git commit -m "Backup before framework update $(date +%Y-%m-%d)"
   git checkout -  # Return to original branch
   ```

2. Document backup location
3. Verify backup integrity

**Validation**: Backup branch exists with all current changes

---

### Step 7: Apply Claude Code CLI Updates

**Action**: Upgrade Claude Code CLI to latest version

**Tasks**:
1. Update via package manager:
   ```bash
   # npm
   npm install -g @anthropic-ai/claude-code@latest

   # Or via direct download (if npm not used)
   # Follow instructions from release notes
   ```

2. Verify installation:
   ```bash
   claude --version
   ```

3. Test basic functionality:
   ```bash
   claude --help
   ```

**Validation**: New version installed and functional

---

### Step 8: Apply Framework Updates (Selective Merge)

**Action**: Merge upstream changes to framework files

**Tasks**:
1. **Update Core Framework Files** (if no custom modifications):
   ```bash
   # Constitution (ONLY if new version)
   git checkout upstream/main -- .specify/memory/constitution.md

   # Core scripts (if no custom changes)
   git checkout upstream/main -- .specify/scripts/bash/

   # Agent templates
   git checkout upstream/main -- .claude/agents/_templates/
   ```

2. **Merge Custom Files** (if you have modifications):
   ```bash
   # Use three-way merge for files you've customized
   git checkout --patch upstream/main -- .specify/memory/constitution.md

   # Review each hunk, accept or reject
   ```

3. **Add New Skills/Agents**:
   ```bash
   # Copy new skills that don't exist locally
   rsync -av --ignore-existing upstream/.claude/skills/ .claude/skills/
   ```

4. **Update CLAUDE.md** (if framework changed structure):
   ```bash
   # Manual merge required - compare and update
   diff CLAUDE.md upstream/CLAUDE.md
   ```

**Validation**: Framework files updated, no merge conflicts

---

### Step 9: Reconcile Project Customizations

**Action**: Ensure project-specific customizations still work

**Tasks**:
1. **Review Custom Agents**:
   ```bash
   # Check if agent patterns still valid
   ls -la .claude/agents/
   ```

2. **Review Custom Skills**:
   ```bash
   # Verify skill structure matches new templates
   ls -la .claude/skills/
   ```

3. **Update Constitutional Customizations**:
   - Check [.docs/project/constitutional-customizations.md](c:\Users\brian\Dev Apps\kelleysd.com\.docs\project\constitutional-customizations.md)
   - Ensure project-specific rules still compatible
   - Update if constitution version changed

4. **Update PRD References** (if constitution changed):
   - Review [.docs/prd/prd.md](c:\Users\brian\Dev Apps\kelleysd.com\.docs\prd\prd.md)
   - Update principle references if numbering changed

**Validation**: All project-specific files reference correct constitution version

---

### Step 10: Run Validation Suite

**Action**: Verify updates didn't break anything

**Tasks**:
1. **Constitutional Compliance Check**:
   ```bash
   ./.specify/scripts/bash/constitutional-check.sh
   ```

2. **Sanitization Audit** (if you maintain a sanitized framework):
   ```bash
   ./.specify/scripts/bash/sanitization-audit.sh
   ```

3. **Test Core Commands**:
   ```bash
   # Test that key commands still work
   # (Don't actually execute, just verify help text)
   ls .claude/commands/*.md
   ```

4. **Verify Agent Registry**:
   ```bash
   # Check all agents still valid
   find .claude/agents -name "*.md" -type f
   ```

**Validation**: All validation scripts pass

---

### Step 11: Test in Isolated Environment

**Action**: Test updates in safe environment before production use

**Tasks**:
1. Create test feature branch:
   ```bash
   git checkout -b test-framework-update-$(date +%Y%m%d)
   ```

2. Run sample workflows:
   - Test `/specify` command
   - Test agent delegation
   - Test skill invocation

3. Verify no regressions:
   - Existing features still work
   - Custom agents/skills functional
   - Documentation generates correctly

**Validation**: Sample workflows execute successfully

---

### Step 12: Update Documentation

**Action**: Document what was updated and why

**Tasks**:
1. **Update CHANGELOG.md** (if exists):
   ```markdown
   ## Framework Update - YYYY-MM-DD

   ### Claude Code CLI
   - Updated from v1.2.3 to v1.3.0
   - Added: [new features]
   - Fixed: [bug fixes]

   ### SDD Framework
   - Synced with upstream commit def456
   - Added: [new skills/agents]
   - Updated: [modified files]

   ### Migration Notes
   - [Any manual steps required]
   ```

2. **Update Framework Version References**:
   - CLAUDE.md (if structure changed)
   - README.md (if applicable)
   - Constitution version in PRD

3. **Document Breaking Changes** (if any):
   - Create migration guide
   - Update affected feature specs

**Validation**: Documentation reflects current versions

---

### Step 13: Commit Updates

**Action**: Commit framework updates with detailed message

**Tasks**:
1. Stage all changes:
   ```bash
   git add -A
   ```

2. Create descriptive commit:
   ```bash
   git commit -m "$(cat <<'EOF'
   chore: Update framework to latest versions

   Claude Code CLI: v1.2.3 → v1.3.0
   SDD Framework: abc123 → def456 (upstream/main)

   Changes:
   - Updated constitution to v1.6.0
   - Added 2 new skills: [skill-names]
   - Fixed bug in constitutional-check.sh
   - Security patch: XSS vulnerability in templates

   Breaking Changes: None
   Migration Required: No

   Validated with:
   - constitutional-check.sh ✓
   - sanitization-audit.sh ✓
   - Manual testing of /specify, /plan, /tasks ✓

   Backup: backup-before-framework-update-20260109-143052

   Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
   EOF
   )"
   ```

3. **CRITICAL**: Only commit after user approval (Principle VI)

**Validation**: Changes committed with detailed message

---

### Step 14: Post-Update Verification

**Action**: Final verification in production context

**Tasks**:
1. **Run Full Validation**:
   ```bash
   # Full constitutional check
   ./.specify/scripts/bash/constitutional-check.sh --verbose
   ```

2. **Test Real Workflow**:
   - Try creating a new feature spec
   - Test agent delegation
   - Verify skill commands work

3. **Monitor for Issues**:
   - Watch for unexpected errors
   - Verify logs show no warnings
   - Check that custom features work

**Validation**: All systems operational post-update

---

### Step 15: Cleanup and Documentation

**Action**: Clean up temporary artifacts and finalize documentation

**Tasks**:
1. Delete test branches (if successful):
   ```bash
   git branch -D test-framework-update-*
   ```

2. Keep backup branch:
   ```bash
   # Document backup location for rollback if needed
   echo "Backup available at: $BACKUP_BRANCH" >> .framework-update-log
   ```

3. Update team documentation:
   - Notify team of framework update
   - Share migration notes if applicable
   - Update project wiki/docs

**Validation**: Cleanup complete, rollback path documented

---

## Constitutional Compliance

This skill complies with:

- **Principle VI (Git Operations)**: REQUIRES user approval before ANY git operations (Step 5, Step 13)
- **Principle VII (Observability)**: Generates detailed logs and reports at each step
- **Principle VIII (Documentation Sync)**: Updates documentation to reflect framework changes (Step 12)
- **Principle IX (Dependency Management)**: Explicitly manages Claude Code CLI and framework versions
- **Principle X (Agent Delegation)**: Delegates execution to framework-sync-agent

## Agent Collaboration

**Primary Agent**: `framework-sync-agent`

This skill should ALWAYS delegate to the framework-sync-agent for execution:

```
User: /update-framework
Claude: Invoking framework-sync-agent to execute update workflow...
```

The framework-sync-agent has specialized capabilities for:
- Querying GitHub APIs for release info
- Analyzing git diffs across framework files
- Assessing breaking change impact
- Safely merging upstream changes
- Validating constitutional compliance post-update

**When NOT to use the agent**:
- Simple version checks (can be done directly)
- Reading release notes (can use WebFetch directly)

## Examples

### Example 1: Monthly Update Check

```bash
User: /update-framework

Claude: Running framework update check...

Step 1: Current State
  - Claude Code: v1.2.3
  - Framework:   commit abc123 (2026-01-01)

Step 2: Checking for updates...
  - Claude Code: v1.3.0 available (released 2026-01-09)
  - Framework:   5 commits ahead (def456)

Step 3: Analyzing impact...
  - Breaking changes: None
  - Security fixes:   Yes (1 critical)
  - New features:     2 new skills

Recommendation: APPLY UPDATES

Would you like to proceed? [y/N]
```

### Example 2: Checking Specific Component

```bash
User: Are there updates to the constitution?

Claude: Checking constitution version...
  - Current: v1.5.0 (14 principles)
  - Upstream: v1.6.0 (15 principles)

Change: New Principle XV added (AI Safety Guidelines)

Run /update-framework to apply?
```

### Example 3: Post-Issue Update

```bash
User: I'm seeing an error in constitutional-check.sh, is there a fix upstream?

Claude: Checking upstream for fixes...
  - Bug #123 fixed in commit def456
  - Fix: Corrected regex pattern in line 45

Run /update-framework to apply fix?
```

## Validation

After running `/update-framework`, verify:

- [ ] Backup branch created before changes
- [ ] User provided explicit approval for updates
- [ ] Claude Code CLI version updated (if applicable)
- [ ] Framework files synced from upstream (if applicable)
- [ ] No merge conflicts remain
- [ ] Constitutional compliance check passes
- [ ] Custom agents/skills still functional
- [ ] Documentation updated with new versions
- [ ] Changes committed with detailed message
- [ ] Rollback path documented

## Troubleshooting

### Issue: Merge Conflicts

**Symptom**: Git merge fails with conflicts in framework files

**Solution**:
1. Identify conflicting files:
   ```bash
   git status | grep "both modified"
   ```

2. For each conflict:
   - If you have NO custom changes: Accept upstream version
   - If you have custom changes: Manual three-way merge required

3. Common conflict files:
   - `CLAUDE.md` → Usually accept upstream, re-apply customizations
   - `constitution.md` → ALWAYS accept upstream (canonical source)
   - Custom agents → Keep your version, review if template changed

### Issue: Breaking Changes in Constitution

**Symptom**: New constitution version incompatible with project specs

**Solution**:
1. Review breaking changes in upstream release notes
2. Update affected specs:
   ```bash
   # Find specs referencing old principle numbers
   grep -r "Principle X" specs/
   ```
3. Run migration script (if provided by framework)
4. Update constitutional-customizations.md

### Issue: Claude Code CLI Upgrade Fails

**Symptom**: npm install fails or binary not found

**Solution**:
1. Clear npm cache:
   ```bash
   npm cache clean --force
   ```

2. Try alternative installation:
   ```bash
   # Direct download from GitHub releases
   curl -L https://github.com/anthropics/claude-code/releases/latest/download/claude-code-linux-x64 -o ~/bin/claude
   chmod +x ~/bin/claude
   ```

3. Verify PATH:
   ```bash
   which claude
   ```

### Issue: Validation Scripts Fail Post-Update

**Symptom**: constitutional-check.sh or other validation fails after update

**Solution**:
1. Check script syntax:
   ```bash
   bash -n ./.specify/scripts/bash/constitutional-check.sh
   ```

2. Review script changes:
   ```bash
   git diff backup-branch HEAD -- .specify/scripts/bash/
   ```

3. If script broken, rollback:
   ```bash
   git checkout backup-branch -- .specify/scripts/bash/constitutional-check.sh
   ```

4. Report issue upstream

### Issue: Custom Agents/Skills Break

**Symptom**: Custom agents fail to load or execute after framework update

**Solution**:
1. Check agent file structure:
   ```bash
   # Verify YAML frontmatter still valid
   head -20 .claude/agents/custom/your-agent.md
   ```

2. Compare against new template:
   ```bash
   diff .claude/agents/custom/your-agent.md .claude/agents/_templates/AGENT_TEMPLATE.md
   ```

3. Update to match new template structure
4. Test agent invocation

## Notes

- **Update Frequency**: Recommended monthly on first Monday
- **Security Updates**: Apply immediately when released
- **Breaking Changes**: Schedule during sprint planning
- **Backup Retention**: Keep last 3 backup branches
- **Upstream Remote**: Add once, reuse for all updates
- **Custom Modifications**: Document in constitutional-customizations.md
- **Version Pinning**: Consider pinning framework version in production

## Related Commands

- `/create-agent` - May use updated agent templates after framework sync
- `/create-skill` - May use updated skill templates after framework sync
- `/specify` - Behavior may change if constitution updated
- `/plan` - May reference new patterns from framework
- `/tasks` - Task templates may be updated

## Skill Dependencies

**Required Files**:
- `.specify/scripts/bash/constitutional-check.sh`
- `.specify/scripts/bash/sanitization-audit.sh` (optional)
- `.specify/memory/constitution.md`
- `.claude/context/governance.md`

**Required Tools**:
- git (for upstream sync)
- curl or wget (for GitHub API)
- bash 4.0+ (for validation scripts)
- npm or package manager (for Claude Code CLI updates)

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-09 | Initial framework-updater skill creation |

---

**Skill Location**: `.claude/skills/integration/framework-updater/SKILL.md`
**Command**: `/update-framework`
**Agent**: `framework-sync-agent`
**Category**: Integration (External framework synchronization)
**Status**: Active
