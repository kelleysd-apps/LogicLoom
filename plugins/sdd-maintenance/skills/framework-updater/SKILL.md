---
name: framework-updater
description: |
  Monitors and applies updates from upstream sdd-agentic-framework repository.
  Uses upstream-history-only diffing: never compares downstream content against
  upstream. Extracts discrete enhancement proposals for selective adoption.

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

**Upstream-history-only. Additive-only. Proposal-based.**

The SDD framework is a development platform that gets cloned to create independent
projects. Each downstream project customizes governance, agents, skills, and config.
The update process must NEVER compare downstream content against upstream — it only
looks at what upstream changed in its own history and offers those changes as
discrete, independently-adoptable enhancement proposals.

**Key insight**: Never `diff downstream..upstream`. Only `diff sync-ref..upstream/main`.

## When to Use

Use `/update-framework` when:
- You want to check for new Claude Code CLI releases
- You need to pull enhancements from upstream sdd-agentic-framework
- A new constitutional principle or best practice has been published
- You want to adopt new agent patterns or skills from the framework

## Procedure

### Step 1: Pre-Update Assessment

**Action**: Assess current state

**Tasks**:
1. Check current Claude Code version: `claude --version`
2. Read `.sdd-sync-ref` for last sync point
3. Document current state (active branches, uncommitted changes)

**Validation**: Current versions documented

---

### Step 2: Check Claude Code CLI Updates

**Action**: Query latest Claude Code releases

**Tasks**:
1. Check current version: `claude --version`
2. Compare with latest available version
3. Review release notes for new capabilities

**Validation**: CLI update report generated

---

### Step 3: Fetch and Diff Upstream History

**Action**: Diff upstream's own history using sync-ref

**Tasks**:
1. Check upstream remote exists:
   ```bash
   git remote -v | grep -q 'sdd-agentic-framework' || \
     git remote add upstream https://github.com/kelleysd-apps/sdd-agentic-framework.git
   ```

2. Fetch upstream:
   ```bash
   git fetch upstream main
   ```

3. Read sync reference:
   ```bash
   SYNC_REF=$(cat .sdd-sync-ref)
   ```

4. Run proposal extraction:
   ```bash
   bash plugins/sdd-maintenance/scripts/extract-proposals.sh
   ```

**CRITICAL**: This diffs `sync-ref..upstream/main` (upstream's own history).
It does NOT diff `HEAD..upstream/main` (which would show downstream customizations
as conflicts).

**Validation**: Proposals extracted as JSON

---

### Step 4: Present Enhancement Proposals

**Action**: Show user what's available from upstream

**Output Format**:
```
Framework Enhancement Proposals
================================

Source: upstream/main (last sync: <sync-ref-date>)
Changes: <N> files changed in upstream since last sync
Releases: v4.1.0 (2026-02-09), v4.2.0 (2026-02-15)

── v4.1.0 ──────────────────────────
  EP-001: [plugin] New plugin: sdd-foo — Install? [y/N]
  EP-002: [skill] New skill: bar-skill — Install? [y/N]

── v4.2.0 ──────────────────────────
  EP-003: [agent] New agent: baz-agent — Install? [y/N]
  EP-004: [governance] constitution.md — New Principle XVII added — Accept? [y/N]

── Untagged ─────────────────────────
  EP-005: [config] CLAUDE.md — New command table entries — Accept? [y/N]
```

**Group proposals by release tag** when available. Each proposal's `release_tag`
field comes from `extract-proposals.sh`. This lets users adopt per-release
(e.g., "accept all v4.1.0 changes") or per-file.

**For each proposal**: Show what upstream changed (not how downstream differs).
User accepts or rejects each independently.

---

### Step 5: User Approval Gate

**CRITICAL**: NEVER proceed without explicit user approval (Principle VI)

Ask user which proposals to accept. Respect selective adoption.

---

### Step 6: Backup Current State

**Action**: Create safety backup before applying

```
"Creating backup branch before applying enhancements. Approve? [y/N]"
```

```bash
BACKUP_BRANCH="backup-pre-update-$(date +%Y%m%d-%H%M%S)"
git checkout -b "$BACKUP_BRANCH"
git add -A && git commit -m "Backup before framework enhancement"
git checkout -
```

---

### Step 7: Apply Accepted Proposals

**For new files (type: new-file)**:
```bash
git show upstream/main:"$file_path" > "$file_path"
```

**For modified files (type: modified-content)**:
- Show user what upstream changed (diff sync-ref..upstream/main for that file)
- If downstream has NOT modified the file: safe to replace
- If downstream HAS modified the file: extract new sections from upstream diff
  and present as additive insertions
- NEVER overwrite downstream customizations

**For structural changes (type: structural-change)**:
- Present full details for manual review
- Do NOT attempt automated merge

---

### Step 8: Update Sync Reference

**ALWAYS** update sync ref after completion, regardless of which proposals
were accepted or rejected:

```bash
git rev-parse upstream/main > .sdd-sync-ref
```

This ensures the next `/update-framework` run only shows NEW changes.

---

### Step 9: Run Validation Suite

```bash
./.specify/scripts/bash/constitutional-check.sh
bash tests/run_all_tests.sh
```

---

### Step 10: Commit Updates

**Only after explicit user approval (Principle VI)**

```bash
git commit -m "$(cat <<'EOF'
chore: Apply upstream enhancements from <sync-ref>..<upstream-head>

Accepted:
- EP-001: New plugin sdd-foo
- EP-004: Added Principle XVII to constitution

Rejected:
- EP-005: CLAUDE.md changes (project uses custom structure)

Downstream customizations: PRESERVED
Breaking changes: None

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## .sdd-sync-ref — Minimal Tracking

The only thing downstream needs to store is a single file:

```
# .sdd-sync-ref
c6092b0862562f306769ce742be5665fa0827c10
```

This commit hash marks the last point at which the downstream project
inspected upstream changes. It is updated after every `/update-framework`
run, regardless of which proposals were accepted.

## Constitutional Compliance

- **Principle VI (Git Operations)**: REQUIRES user approval for ALL git operations
- **Principle VII (Observability)**: Generates detailed proposal reports
- **Principle VIII (Documentation Sync)**: Updates docs to reflect changes
- **Principle XVI (Plugin-First)**: New capabilities offered as plugin installs

## Agent Collaboration

**Primary Agent**: `framework-sync-agent`

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 3.0.0 | 2026-02-09 | Upstream-history-only approach, proposal-based adoption, .sdd-sync-ref tracking |
| 2.0.0 | 2026-02-06 | Enhancement-first philosophy, 4-tier classification, additive merge |
| 1.0.0 | 2026-01-09 | Initial framework-updater skill creation |

---

**Skill Location**: `plugins/sdd-maintenance/skills/framework-updater/SKILL.md`
**Command**: `/update-framework`
**Agent**: `framework-sync-agent`
**Category**: Integration (External framework synchronization)
**Status**: Active
