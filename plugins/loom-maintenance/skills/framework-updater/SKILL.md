---
name: framework-updater
description: |
  Monitors and applies updates from upstream logic-loom repository.
  Uses upstream-history-only diffing: never compares downstream content against
  upstream. Extracts discrete enhancement proposals for selective adoption.

  Triggered by: /update-framework command, "check for updates", "sync framework"
allowed-tools: Read, Write, Bash, Grep, Glob, WebFetch, WebSearch
---

# Framework Updater Skill

## Core Philosophy

**Upstream-history-only. Additive-only. Proposal-based.**

The SDD framework is a development platform that gets cloned to create independent
projects. Each downstream project customizes governance, agents, skills, and config.
The update process must NEVER compare downstream content against upstream — it only
looks at what upstream changed in its own history and offers those changes as
discrete, independently-adoptable enhancement proposals.

**Key insight**: Never `diff downstream..upstream`. Only `diff sync-ref..refs/loom-upstream/main`.

> **Safety invariants (misfire-proof — do not violate):**
> - **Fetch-only, no remote.** `extract-proposals.sh` fetches the upstream AD-HOC
>   into `refs/loom-upstream/main`. LogicLoom NEVER runs `git remote add upstream`,
>   so there is no `upstream` remote and `git push upstream …` cannot happen.
> - **Origin-only commits.** Every accepted change commits to YOUR current branch
>   on `origin`. NEVER push / pull / merge upstream.
> - **Config-driven URL** from `.logic-loom/config/framework-upstream.conf` (or
>   `$LOOM_UPSTREAM_URL`); NEVER derived from `origin`.
> - Optional cleanup: if an old clone still has a stale pushable `upstream` remote,
>   offer `git remote remove upstream` (approval-gated) — it is unused and a footgun.

## When to Use

Use `/update-framework` when:
- You want to check for new Claude Code CLI releases
- You need to pull enhancements from upstream logic-loom
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
1. Run proposal extraction — it performs the ad-hoc, FETCH-ONLY retrieval:
   ```bash
   bash plugins/loom-maintenance/scripts/extract-proposals.sh
   ```
   This resolves the upstream URL from config, fetches it into
   `refs/loom-upstream/main` (NO `upstream` git remote is created), reads
   `.sdd-sync-ref`, and emits proposals from upstream's OWN history. If the URL
   is unconfigured it exits with guidance — set `LOOM_UPSTREAM_REPO` in
   `.logic-loom/config/framework-upstream.conf` (the PUBLIC template repo) or
   `export LOOM_UPSTREAM_URL=…`, then re-run.

**CRITICAL**: This diffs `sync-ref..refs/loom-upstream/main` (upstream's own
history). It does NOT diff `HEAD..upstream` (which would show downstream
customizations as conflicts), and it NEVER adds an `upstream` git remote.

**Validation**: Proposals extracted as JSON

---

### Step 4: Present Enhancement Proposals

**Action**: Show user what's available from upstream

**Output Format**:
```
Framework Enhancement Proposals
================================

Source: refs/loom-upstream/main (last sync: <sync-ref-date>)
Changes: <N> files changed in upstream since last sync
Releases: v5.0.0 (2026-02-15), v5.1.0 (2026-03-01)

── v5.0.0 ──────────────────────────
  EP-001: [plugin] New plugin: sdd-foo — Install? [y/N]
  EP-002: [skill] New skill: bar-skill — Install? [y/N]

── v5.1.0 ──────────────────────────
  EP-003: [skill] New skill: baz-skill — Install? [y/N]
  EP-004: [governance] constitution.md — New Principle XVII added — Accept? [y/N]

── Untagged ─────────────────────────
  EP-005: [config] CLAUDE.md — New command table entries — Accept? [y/N]
```

**Group proposals by release tag** when available. Each proposal's `release_tag`
field comes from `extract-proposals.sh`. This lets users adopt per-release
(e.g., "accept all v5.0.0 changes") or per-file.

**For each proposal**: show what upstream changed (not how downstream differs),
AND flag conflicts. Each proposal carries `conflict` + `resolution` from
extract-proposals.sh — mark every `conflict: true` item with
"⚠️ CONFLICT — you have customized this file" so the user sees, per item, whether
adopting it would touch their own work. Suggested grouping: clean
additions/updates · ⚠️ conflicts (your customizations) · already-present (skip) ·
informational (upstream deletions). The user accepts or rejects each independently.

---

### Step 5: User Approval Gate

**CRITICAL**: NEVER proceed without explicit user approval (Principle VI)

Ask user which proposals to accept. Respect selective adoption.

---

### Step 6: Checkpoint Current State

**Action**: Tag current HEAD as a restore point. Do NOT switch branches — accepted
changes apply to the CURRENT branch, so verify you are on the intended branch FIRST.

```bash
git tag "loom/pre-update-$(date +%Y%m%d-%H%M%S)" HEAD
```

Undo later with `git reset --hard <that-tag>`. (A lightweight tag avoids the
`checkout -b` / `checkout -` dance that could strand changes on the wrong branch.)

---

### Step 7: Apply Accepted Proposals

Apply each ACCEPTED proposal according to its **`resolution`** field (computed by
extract-proposals.sh via a 3-way comparison: baseline `sync-ref:<file>` vs your
working file vs upstream). Never overwrite a customization without explicit consent.

- **`clean-add`** — file absent downstream; add upstream's version:
  ```bash
  git show refs/loom-upstream/main:"$file_path" > "$file_path"
  ```
- **`clean-apply`** — downstream is identical to the baseline (you did NOT
  customize it); safe to update to upstream's version (same command). No
  customization is at risk.
- **`already-present`** — your file already equals upstream's version. Skip (no-op).
- **`conflict-review`** ⚠️ — you customized this file AND upstream changed it.
  **NEVER overwrite.** Show BOTH sides and let the user choose, per file:
    - upstream's change:        `git diff <sync-ref>..refs/loom-upstream/main -- "$file_path"`
    - your customization:        `git diff <sync-ref> -- "$file_path"`
  Offer: (a) keep mine (skip), (b) take upstream (explicit overwrite — confirm),
  (c) additively insert only upstream's NEW sections (preserve your edits),
  (d) manual merge. Default to the NON-destructive option. One file at a time.
- **`info-upstream-deleted`** — upstream removed this file; inform the user, do
  NOT auto-delete their copy. They decide.

For **structural changes** (renames/`type: structural-change`): present full
details for manual review; do NOT attempt an automated move/merge.

NEVER run `git merge` or `git cherry-pick`. All writes go to the current branch on
`origin`; the git-safety-gate hook gates the commit (Principle VI).

---

### Step 8: Update Sync Reference

Update the sync ref after completion **only if ≥1 proposal was accepted** (or the
user explicitly chose "mark reviewed"). If ALL proposals were deferred, leave it
unchanged so the same proposals reappear next run.

```bash
git rev-parse refs/loom-upstream/main > .sdd-sync-ref
```

This ensures the next `/update-framework` run shows only NEW changes. The scratch
ref is pruned after the run (`git update-ref -d refs/loom-upstream/main`) and is
re-fetched next time.

---

### Step 9: Run Validation Suite

```bash
./.logic-loom/scripts/bash/constitutional-check.sh
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

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
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
