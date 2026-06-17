# Constitution Update Checklist

**Purpose**: Ensure all dependent documents are updated when the constitution changes.

**Version**: 1.0.0
**Last Updated**: 2025-11-06

---

## Overview

The constitution (`.logic-loom/memory/constitution.md`) is the supreme authority for the SDD framework. When constitutional principles change, many dependent documents must be updated to maintain synchronization and prevent documentation drift.

This checklist ensures constitutional changes propagate correctly throughout the framework.

---

## When to Use This Checklist

Use this checklist whenever you:
- Add a new constitutional principle
- Modify an existing principle
- Change principle numbering
- Update enforcement requirements
- Modify workflow gates
- Change quality standards

**DO NOT skip this checklist.** Constitutional Principle VIII (Documentation Synchronization) mandates its use.

---

## Pre-Change Preparation

Before modifying the constitution:

- [ ] **Read current constitution** completely
- [ ] **Identify affected principles** and their dependencies
- [ ] **Document rationale** for proposed change
- [ ] **Assess impact** on existing workflows, agents, and policies
- [ ] **Determine if breaking** change (requires migration path)
- [ ] **Create backup** of current constitution

---

## Constitutional Change Categories

### Category A: Adding New Principle

When adding a new principle (e.g., Principle XV):

- [ ] Assign next available principle number
- [ ] Determine if immutable, critical, or standard
- [ ] Write compliance checklist for new principle
- [ ] Define enforcement mechanism
- [ ] Document rationale
- [ ] Create examples

### Category B: Modifying Existing Principle

When changing an existing principle:

- [ ] Document what changed (before/after)
- [ ] Identify affected workflows/agents
- [ ] Update compliance checklists
- [ ] Update enforcement mechanisms
- [ ] Provide migration path if breaking

### Category C: Removing/Deprecating Principle

When removing a principle:

- [ ] Document deprecation reason
- [ ] Provide migration path
- [ ] Update principle numbering (if needed)
- [ ] Remove enforcement mechanisms
- [ ] Archive old principle content

---

## Mandatory Update Steps

After changing constitution, update ALL of the following:

### Step 1: Update Constitution Metadata

- [ ] Increment version number (e.g., 1.5.0 → 1.5.1 or 1.6.0)
- [ ] Update "Last Amended" date
- [ ] Add change to version history (if maintained)
- [ ] Update line count if significant change

### Step 2: Update Main Instruction Files

**CRITICAL: CLAUDE.md and AGENTS.md are TANDEM FILES - update BOTH together**

**CLAUDE.md** (`CLAUDE.md` at repo root):
- [ ] Update constitutional principle references (count, version)
- [ ] Add new principle to relevant sections
- [ ] Update workflow descriptions if changed
- [ ] Update command documentation if affected
- [ ] Update domain → agent mapping table (if agents changed)
- [ ] Update pre-flight compliance check (if principles changed)
- [ ] Verify cross-references to constitution

**AGENTS.md** (`AGENTS.md` at repo root):
- [ ] Update version number and date
- [ ] Update constitution version reference
- [ ] Update total agent count
- [ ] Update department agent counts
- [ ] Update agent tables (if agents changed)
- [ ] Update domain → agent mapping table
- [ ] Update slash command → agent mapping
- [ ] Update constitutional compliance section
- [ ] Update tandem update rules (if process changed)
- [ ] Verify all principle references

**CLAUDE.md ↔ AGENTS.md Tandem Verification**:
- [ ] Agent count matches in both files
- [ ] Domain → agent mappings are consistent
- [ ] Constitutional version matches in both files
- [ ] Delegation triggers align between files

**README.md**:
- [ ] Update framework overview if principles changed fundamentally
- [ ] Update "Core Principles" section
- [ ] Update quick reference if provided
- [ ] Verify constitutional references accurate

### Step 3: Update Agent Context Files

For EACH agent in `plugins/*/agents/**/*.md`:

- [ ] Review if agent's domain affected by change
- [ ] Update "Working Principles" section
- [ ] Update "Constitutional Principles Application"
- [ ] Update tool restrictions if security principles changed
- [ ] Update delegation triggers if Principle X changed
- [ ] Verify no outdated principle references

**Affected Agent Files** (check all 7 agents):
- [ ] constitutional-governance-agent.md (loom-governance)
- [ ] team-synthesizer.md (loom-orchestrator)
- [ ] prd-specialist.md (loom-creation)
- [ ] subagent-architect.md (loom-creation)
- [ ] auto-debug-agent.md (sdd-debug)
- [ ] framework-sync-agent.md (loom-maintenance)
- [ ] memory-context-agent.md (loom-memory)

### Step 4: Update Workflow Scripts

If workflows affected (Principles II, III, VI, X):

**create-new-feature.sh**:
- [ ] Update if branching/git workflow changed
- [ ] Add new validation if required
- [ ] Update constitutional checks

**setup-plan.sh**:
- [ ] Update if planning workflow changed
- [ ] Add new artifact generation if required
- [ ] Update multi-agent detection logic if Principle X changed

**check-task-prerequisites.sh**:
- [ ] Update prerequisite checks if quality gates changed
- [ ] Add new validations if required

**constitutional-check.sh**:
- [ ] **CRITICAL**: Add checks for new principles
- [ ] Update existing checks if principles modified
- [ ] Test all checks still pass
- [ ] Update output messages

**sanitization-audit.sh**:
- [ ] Update if security/validation principles changed
- [ ] Add new checks if required

**create-agent.sh**:
- [ ] Update agent template if delegation principles changed
- [ ] Update validation if requirements changed

### Step 5: Update Templates

**spec-template.md**:
- [ ] Add sections for new principles if user-facing
- [ ] Update validation requirements
- [ ] Update examples

**plan-template.md**:
- [ ] Update 9-step process if workflow changed
- [ ] Add new planning requirements
- [ ] Update compliance sections

**tasks-template.md**:
- [ ] Update task structure if workflow changed
- [ ] Add new task types if required
- [ ] Update agent assignment if Principle X changed

**agent-file-template.md**:
- [ ] **CRITICAL**: Update constitutional section
- [ ] Add new principle applications
- [ ] Update delegation protocol if Principle X changed
- [ ] Update tool restrictions if security changed

### Step 6: Update Policy Documents

In `.docs/policies/`:

**agent-collaboration-triggers.md**:
- [ ] **CRITICAL if Principle X changed**: Update trigger keywords
- [ ] Add new domain triggers
- [ ] Update agent routing logic

**testing-strategy-guide.md**:
- [ ] Update if Principle II (Test-First) changed
- [ ] Add new testing requirements
- [ ] Update test types/priorities

**feature-development-workflow.md**:
- [ ] Update workflow steps if processes changed
- [ ] Add new gates if quality standards changed
- [ ] Update approval requirements

**file-creation-policy.md**:
- [ ] Update if library-first or documentation principles changed

**Any other policy files**:
- [ ] Review each for constitutional references
- [ ] Update as needed

### Step 7: Update Slash Commands

In `.claude/commands/`:

**/specify** command:
- [ ] Update if specification requirements changed
- [ ] Add new validations if required

**/plan** command:
- [ ] Update if planning process changed
- [ ] Update multi-agent triggers if Principle X changed

**/tasks** command:
- [ ] Update if task generation requirements changed

**/create-agent** command:
- [ ] **CRITICAL**: Update if agent structure changed
- [ ] Update constitutional compliance requirements

### Step 8: Update Case Studies / Examples

**case-studies/<your-project>.md** (and any others):
- [ ] Add examples of new principle application
- [ ] Update existing examples if principles changed
- [ ] Document how principle was applied in practice

### Step 9: Update SOW / PRD (if applicable)

**sdd-framework-enhancements-sow.md**:
- [ ] Update constitutional foundation section if applicable
- [ ] Document change as enhancement

**sdd-framework-enhancements-prd.md**:
- [ ] Add change to enhancement catalog if applicable

---

## Testing & Validation

After all updates complete:

### Automated Testing

- [ ] Run `constitutional-check.sh` - all checks must pass
- [ ] Run `sanitization-audit.sh` - verify no regressions
- [ ] Test all workflow scripts with new constitution
- [ ] Validate all template files generate correctly

### Manual Testing

- [ ] Initialize test project with `init-project.sh`
- [ ] Create test feature with `/specify`
- [ ] Generate test plan with `/plan`
- [ ] Create test tasks with `/tasks`
- [ ] Verify all constitutional references accurate

### Documentation Review

- [ ] Check for broken cross-references
- [ ] Verify all principle numbers updated consistently
- [ ] Ensure no outdated principle references
- [ ] Validate all examples still accurate

### Agent Testing

- [ ] Verify agents can read updated constitution
- [ ] Test agent delegation with new principles
- [ ] Confirm constitutional compliance checking works
- [ ] Validate multi-agent workflows still function

---

## Migration Path (for Breaking Changes)

If constitutional change breaks existing projects:

### Document Migration

- [ ] Create migration guide: `.docs/migrations/constitution-v{old}-to-v{new}.md`
- [ ] Document what changed
- [ ] Provide before/after examples
- [ ] List required code changes
- [ ] Provide automated migration script if possible

### Communication

- [ ] Update CHANGELOG.md
- [ ] Add breaking change notice to README
- [ ] Document in release notes
- [ ] Consider semver major version bump

### Backwards Compatibility

- [ ] Determine if grace period needed
- [ ] Consider deprecation warnings before enforcement
- [ ] Document timeline for enforcement

---

## Post-Update Verification

### Checklist Completion

- [ ] All mandatory steps completed
- [ ] All automated tests pass
- [ ] Manual testing successful
- [ ] Documentation synchronized
- [ ] Migration path provided (if breaking)
- [ ] Team notified of changes

### Sign-Off

**Change Author**: _________________________
**Date**: _________

**Technical Reviewer**: _________________________
**Date**: _________

**Framework Maintainer**: _________________________
**Date**: _________

---

## Common Pitfalls to Avoid

1. **Forgetting agent files**: All 13+ agent files must be updated if delegation or workflow changes
2. **Missing script updates**: constitutional-check.sh MUST be updated for new principles
3. **Inconsistent numbering**: If renumbering principles, update EVERYWHERE
4. **Broken cross-references**: Search for `Principle [Roman numeral]` across all docs
5. **Outdated examples**: Code examples in constitution must match current practices
6. **Template lag**: Templates often forgotten but critical for new features
7. **Policy drift**: Policy docs can drift out of sync with constitution

---

## Quick Reference: Files That ALWAYS Need Review

**Always check these files when constitution changes**:

1. `.logic-loom/memory/constitution.md` (the constitution itself)
2. `CLAUDE.md` (main AI instructions) **← TANDEM with AGENTS.md**
3. `AGENTS.md` (agent registry) **← TANDEM with CLAUDE.md**
4. `.logic-loom/scripts/bash/constitutional-check.sh` (automated validation)
5. `.logic-loom/templates/agent-file-template.md` (new agents must comply)
6. `.logic-loom/memory/agent-collaboration-triggers.md` (if Principle X changes)
7. All agent files in `plugins/*/agents/**/*.md` (14 files)

**Often need updates**:

8. `.logic-loom/templates/spec-template.md`
9. `.logic-loom/templates/plan-template.md`
10. `.logic-loom/templates/tasks-template.md`
11. README.md
12. `.docs/sdd-framework-enhancements-sow.md` (if significant change)
13. `plugins/*/skills/validation/message-preflight/SKILL.md` (if principles change)

**TANDEM UPDATE RULE**: CLAUDE.md and AGENTS.md MUST be updated together when:
- Agent count changes
- Agent capabilities change
- Domain → agent mappings change
- Constitutional version changes
- Delegation protocol changes

---

## Appendix: Search Commands

Find all constitutional references:

```bash
# Find all mentions of specific principle
grep -r "Principle VI\|Principle 6" . --include="*.md"

# Find all constitution references
grep -r "constitution.md" . --include="*.md" --include="*.sh"

# Find all Work Session Initiation Protocol references
grep -r "Work Session Initiation\|READ CONSTITUTION" . --include="*.md"

# Find all agent delegation references
grep -r "Agent Delegation\|delegate to\|specialized agent" . --include="*.md"
```

---

**Remember**: Documentation synchronization (Principle VIII) is NOT optional. Use this checklist EVERY time the constitution changes.
