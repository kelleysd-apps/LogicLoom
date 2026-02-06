---
name: framework-updater
description: |
  Monitors and applies updates from Claude Code releases and upstream sdd-agentic-framework repository.
  Uses enhancement-first philosophy: enhances the project's framework foundation without overwriting
  project-specific customizations. Supports 4-tier file classification with additive merges
  and cascade impact analysis.
  
  Triggered by: /update-framework command, "check for updates", "sync framework"
allowed-tools: Read, Write, Bash, Grep, Glob, WebFetch, WebSearch
rl_metrics:
  invocation_count: 0
  success_rate: 0.5
  avg_tokens: 0
  selection_weight: 0.5
---

# Framework Updater Skill

## Core Philosophy

**This is NOT a rebase. This is NOT a sync. This is an ENHANCEMENT.**

The SDD framework is a base application that gets cloned to create independent projects
(e.g., kelleysd.com, ioun-ai, cosmos). Each downstream project is a unique application
with its own customizations, agents, skills, and governance rules.

The `/update-framework` command enhances the project's framework layer by:
1. **Adding** new capabilities from upstream (new agents, skills, commands)
2. **Preserving** all project-specific customizations (constitution tweaks, custom agents, project config)
3. **Additively merging** governance/instruction files (add new sections, keep existing)
4. **Detecting cascade impacts** (when upstream adds entities that affect downstream documentation)
5. **Surfacing absent-but-available** components the project might benefit from

## When to Use

Use `/update-framework` when:
- You want to check for new Claude Code CLI releases
- You need to pull enhancements from upstream sdd-agentic-framework
- A new constitutional principle or best practice has been published
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

2. Check current SDD framework state:
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

**Action**: Query latest Claude Code releases

**Tasks**:
1. Check current version and available updates:
   ```bash
   claude doctor
   claude --version
   ```

2. Compare with latest available version
3. Review release notes for new capabilities
4. Identify relevant updates:
   - New features (e.g., plugin system, new CLI flags)
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
     git remote add upstream https://github.com/kelleysd-apps/sdd-agentic-framework.git
   ```

2. Fetch upstream changes:
   ```bash
   git fetch upstream main
   ```

3. Compare framework files:
   ```bash
   git diff HEAD..upstream/main -- .specify/ .claude/ plugins/ mcp-servers/ tests/ CLAUDE.md AGENTS.md
   ```

4. Generate change summary by component type

**Validation**: Generate diff report showing what changed upstream

---

### Step 4: 4-Tier File Classification

**Action**: Classify every changed file into one of 4 tiers

**CRITICAL**: This step determines HOW each file gets updated.

#### Tier 1: New Files (Pure Additions)
Files that exist in upstream but NOT in the downstream project.
- **Action**: Copy from upstream (no conflict possible)
- **Examples**: New plugins, new skills, new agents, new MCP servers, new scripts

```bash
# Identify Tier 1 files
git diff --name-only --diff-filter=A HEAD..upstream/main
```

#### Tier 2: Modified (No Downstream Customization)
Files changed in upstream that the downstream project has NOT modified.
- **Action**: Replace with upstream version (safe — no local changes to lose)
- **Detection**: Compare downstream file against upstream's PREVIOUS version

```bash
# Files modified upstream, check if downstream matches upstream's old version
git diff --name-only --diff-filter=M HEAD..upstream/main -- .specify/ .claude/ plugins/ mcp-servers/ tests/ CLAUDE.md AGENTS.md
```

#### Tier 3: Modified (WITH Downstream Customization)  
Files changed in upstream that the downstream project HAS customized.
- **Action**: ADDITIVE MERGE — identify new sections in upstream and propose additions
- **NEVER overwrite downstream content**
- **Common files**: constitution.md, CLAUDE.md, AGENTS.md, settings.json,
  agent-governance.md, agent-collaboration-triggers.md, .mcp.json,
  plugin manifests (plugins/*/.claude-plugin/plugin.json)

```
ADDITIVE MERGE PROCEDURE:
a) Diff upstream OLD vs upstream NEW (NOT upstream vs downstream!)
   → This isolates WHAT'S ACTUALLY NEW in upstream

b) Categorize upstream additions:
   → New sections (e.g., "Section VII: Skills-First Governance")
   → Expanded lists (e.g., new agent entries in a table)
   → New table rows (e.g., new skill triggers)
   → Version bumps (e.g., "v1.5.0" → "v2.0.0")

c) Present additive proposals to user:
   "Upstream added the following to agent-governance.md:
    - Section VII: Skills-First Governance (47 lines)
    - 3 new agent delegation entries
    - Updated version reference v1.6.0 → v2.0.0
    
    Your version has custom principles. These additions are COMPATIBLE.
    Add these upstream enhancements? [y/N/review]"

d) Preserve ALL downstream content — never remove or modify
   existing customized sections

e) For settings.json: Use DEEP MERGE
   - Merge hook arrays (add new hooks, keep existing)
   - Preserve agent selection
   - Add new configurations without overwriting
```

#### Tier 4: Unchanged But Affected (Cascade Impact)
Files NOT directly changed in upstream, but affected by upstream additions.
- **Action**: Flag for manual reconciliation with specific suggestions

```
CASCADE IMPACT ANALYSIS:
a) Scan new/modified files for entity additions:
   → New plugins? → Flag CLAUDE.md, marketplace registry
   → New agents? → Flag AGENTS.md
   → New skills? → Flag skill-index.json
   → New commands? → Flag CLAUDE.md command table
   → New hooks? → Flag settings.json
   → New MCP servers? → Flag .mcp.json, run npm install
   → Constitution version changed? → Flag all governance files
   → Plugin manifests changed? → Run marketplace-validate

b) Generate Reconciliation Checklist:
   "📋 Cascade Impact Analysis
    
    ⚠️  AGENTS.md — 3 new agents added upstream
    ⚠️  CLAUDE.md — 2 new slash commands available
    ⚠️  skill-index.json — 5 new skills need routing
    ⚠️  agent-collaboration-triggers.md — New triggers
    
    These files reference content that changed. Review recommended."

c) Suggest absent-but-available components:
   "✨ These upstream components aren't in your project:
    - /research skill — Deep multi-pass research
    - sdd-domain-performance/ — Performance domain
    Install any? [list numbers/skip]"
```

**Validation**: All files classified into tiers with action plan

---

### Step 5: User Approval Gate

**Action**: Present findings and request approval

**Output Format**:
```
Framework Enhancement Available
================================

Claude Code CLI:
  Current: v2.1.32
  Latest:  v2.1.35
  Impact:  LOW (bug fixes)

SDD Framework:
  Current: abc123 (2026-01-01)
  Latest:  def456 (2026-02-06)

File Classification:
  Tier 1 (New):                 12 files (copy)
  Tier 2 (Replace):              8 files (safe replace)
  Tier 3 (Additive Merge):       4 files (review needed)
  Tier 4 (Cascade Impact):       3 files (reconciliation)

Breaking Changes: None
Security Fixes:   Yes (1 patch)

Proceed with enhancement? [y/N]
```

**CRITICAL**: NEVER proceed without explicit user approval (Principle VI)

---

### Step 6: Backup Current State

**Action**: Create safety backup before applying updates

**Tasks**:
1. Request git approval for backup branch (Principle VI):
   ```
   "Creating backup branch before framework enhancement. Approve? [y/N]"
   ```

2. Create backup:
   ```bash
   BACKUP_BRANCH="backup-pre-update-$(date +%Y%m%d-%H%M%S)"
   git checkout -b "$BACKUP_BRANCH"
   git add -A && git commit -m "Backup before framework enhancement"
   git checkout -  # Return to original branch
   ```

**Validation**: Backup branch exists with all current changes

---

### Step 7: Apply Tier 1 — New Files

**Action**: Copy all new files from upstream

```bash
for file in $(git diff --name-only --diff-filter=A HEAD..upstream/main -- .specify/ .claude/ plugins/ mcp-servers/ tests/); do
  mkdir -p "$(dirname "$file")"
  git show upstream/main:"$file" > "$file"
  echo "Added: $file"
done
```

**Validation**: All new files present

---

### Step 8: Apply Tier 2 — Replace Unmodified

**Action**: Replace files that we haven't customized

```bash
# For each Tier 2 file, replace with upstream
git checkout upstream/main -- "$file"
```

**Validation**: Tier 2 files match upstream

---

### Step 9: Apply Tier 3 — Additive Merge

**Action**: For each customized file, additively merge upstream enhancements

**Per-file procedure**:
1. Show user what upstream added (diff upstream-old vs upstream-new)
2. Confirm each addition is compatible with downstream
3. Insert new sections at appropriate locations
4. Preserve all existing downstream content
5. Update version references if needed

**Special handling**:
- **settings.json**: Deep merge (jq-based or manual)
- **constitution.md**: Add new principles, update version, keep custom principles
- **CLAUDE.md**: Add new command entries, update model references
- **AGENTS.md**: Add new agent entries, keep custom agent entries

**Validation**: All Tier 3 files enhanced without losing downstream content

---

### Step 10: Cascade Impact — Tier 4

**Action**: Present reconciliation checklist for affected files

**Generate and display** the cascade impact report. Do NOT automatically modify
these files — present suggestions for user to review and approve individually.

**Validation**: Reconciliation checklist presented to user

---

### Step 11: Run Validation Suite

**Action**: Verify updates didn't break anything

**Tasks**:
1. Constitutional compliance check:
   ```bash
   ./.specify/scripts/bash/constitutional-check.sh
   ```

2. Run full test suite:
   ```bash
   bash tests/run_all_tests.sh
   ```

3. Verify plugin manifests are valid:
   ```bash
   # Via MCP marketplace
   marketplace-validate --plugin-name sdd-governance
   ```

4. Install MCP server dependencies (if new servers added):
   ```bash
   for mcp_dir in mcp-servers/*/; do
     [ -f "${mcp_dir}package.json" ] && (cd "$mcp_dir" && npm install --production)
   done
   ```

**Validation**: All validation scripts pass

---

### Step 12: Update Documentation

**Action**: Document what was enhanced

**Tasks**:
1. Update CHANGELOG.md with enhancement details
2. Update version references in CLAUDE.md, AGENTS.md
3. Document any migration notes

**Validation**: Documentation reflects current state

---

### Step 13: Commit Updates

**Action**: Commit framework enhancements with detailed message

**CRITICAL**: Only commit after explicit user approval (Principle VI)

```bash
git commit -m "$(cat <<'EOF'
chore: Enhance framework from upstream vX.Y.Z

Enhancement Summary:
- Tier 1: X new files added
- Tier 2: Y files updated (no conflicts)
- Tier 3: Z files additively merged
- Tier 4: W cascade impacts reviewed

Changes:
- [List key enhancements]

Downstream Customizations: PRESERVED
Breaking Changes: None

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Step 14: Post-Enhancement Verification

**Action**: Final verification

**Tasks**:
1. Run full constitutional check
2. Test key workflows (/specify, /plan, /tasks)
3. Verify custom agents/skills still functional
4. Monitor for issues

**Validation**: All systems operational post-enhancement

---

### Step 15: Cleanup

**Action**: Clean up and document rollback path

**Tasks**:
1. Keep backup branch for 30 days
2. Delete test branches
3. Document enhancement in project log

**Validation**: Cleanup complete, rollback path documented

---

## Constitutional Compliance

- **Principle VI (Git Operations)**: REQUIRES user approval for ALL git operations
- **Principle VII (Observability)**: Generates detailed logs and reports at each step
- **Principle VIII (Documentation Sync)**: Updates documentation to reflect changes
- **Principle IX (Dependency Management)**: Explicitly manages versions
- **Principle X (Agent Delegation)**: Delegates execution to framework-sync-agent

## Agent Collaboration

**Primary Agent**: `framework-sync-agent`

This skill should delegate to the framework-sync-agent for execution.

## Troubleshooting

### Issue: Merge Conflicts in Tier 3

**Solution**: The additive merge approach should prevent conflicts. If conflicts
occur, it means upstream modified existing content (not just added new content).
In this case, present both versions to user for manual resolution.

### Issue: Cascade Impact Too Large

**Solution**: Prioritize cascade items by impact:
1. HIGH: Constitution/governance files
2. MEDIUM: CLAUDE.md/AGENTS.md registry files
3. LOW: Trigger matrices, optional skill registrations

### Issue: Custom Agent Breaks After Update

**Solution**: Check if upstream changed agent template format. Compare custom
agent against new template and update structure while preserving custom content.

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0.0 | 2026-02-06 | Enhancement-first philosophy, 4-tier classification, additive merge, cascade analysis |
| 1.0.0 | 2026-01-09 | Initial framework-updater skill creation |

---

**Skill Location**: `plugins/sdd-maintenance/skills/framework-updater/SKILL.md`
**Command**: `/update-framework`
**Agent**: `framework-sync-agent`
**Category**: Integration (External framework synchronization)
**Status**: Active
