---
name: update-framework
description: Monitor and apply updates from upstream logic-loom using proposal-based selective adoption.
model: opus
---

# /update-framework Command

**SKILL ACTIVATION**: Activate the framework-updater skill at `plugins/loom-maintenance/skills/framework-updater/SKILL.md`.

> **Safety invariants (never violate):** upstream is **fetch-only** — LogicLoom
> never creates an `upstream` git remote and never pushes / pulls / merges
> upstream. All accepted changes commit to **your current branch on `origin`**
> (verify the branch first). The upstream URL is config-driven
> (`.logic-loom/config/framework-upstream.conf`), never derived from `origin`.

## Execution Instructions

### Step 1: Pre-Assessment
```bash
claude --version
cat .sdd-sync-ref 2>/dev/null || echo "No sync ref found"
```

### Step 2: Fetch Upstream (ad-hoc, fetch-only — NO git remote)
The fetch happens INSIDE `extract-proposals.sh` (Step 3): it resolves the upstream
URL from `.logic-loom/config/framework-upstream.conf` (or `$LOOM_UPSTREAM_URL`)
and fetches it into `refs/loom-upstream/main`. It does NOT run `git remote add
upstream` — there is no `upstream` remote, so `git push upstream …` is impossible.
**Do not add one.**

### Step 3: Extract Enhancement Proposals
```bash
bash plugins/loom-maintenance/scripts/extract-proposals.sh
```

This diffs ONLY upstream's own history (`sync-ref..refs/loom-upstream/main`).
It does NOT compare downstream content against upstream, and creates no `upstream` remote.

### Step 4: Present Proposals to User
Show categorized proposals: new files, enhancements, structural changes.
Each proposal is independently accept/reject.

### Step 5: Apply Accepted Proposals (with user approval)
**Principle VI**: ask before any git operation. Apply each per its `resolution`
field (extract-proposals.sh computes it via a 3-way baseline/yours/upstream compare):
- `clean-add` / `clean-apply`: add or update from upstream (you did not customize it).
- `conflict-review` ⚠️ (you customized this file): **NEVER overwrite** — show
  upstream's change AND your customization, then choose per file: keep mine /
  take upstream / additive-insert upstream's new sections / manual merge. Default
  non-destructive.
- `already-present`: skip. `info-*`: informational only (e.g. upstream deletions).

Never `git merge` / `git cherry-pick`. Commit to your current branch on `origin`.

### Step 6: Update Sync Reference (only if ≥1 proposal accepted)
```bash
git rev-parse refs/loom-upstream/main > .sdd-sync-ref
```
If the user deferred ALL proposals, leave `.sdd-sync-ref` unchanged so the same
proposals reappear next run.

### Step 7: Validate
Run full test suite to confirm framework integrity.

## Usage
```
/update-framework
/update-framework --check-only
```
