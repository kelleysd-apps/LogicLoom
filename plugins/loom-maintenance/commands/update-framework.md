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

### Step 0: Which install is this? — TEMPLATE CLONE or ADOPTED

**Run this first. Step 4's inherited-CI warning is wrong, and the proposal
list itself is different, in an adopted repository.**

This command is reachable from both a **template clone** (a fresh checkout of
the LogicLoom template that becomes the project) and a repository that
**adopted** LogicLoom via `npx logicloom init` — the adopt payload ships
`plugins/` and `.claude/commands/`, so `/update-framework` is in that user's
command palette either way. Telling adopters not to run it is not a control;
making it know where it is running is.

Detect, read-only, no git:

```bash
# ADOPTED if this prints the schema line; TEMPLATE CLONE if the file is absent.
grep -l '"schema": *"logicloom/adopt-receipt@1"' .logicloom-adopt-receipt.json 2>/dev/null
# Fallback tell if the receipt itself is gone: only the adopt path installs
# the harness's own AGENTS.md at .logic-loom/AGENTS.md. A template clone has
# AGENTS.md at repo ROOT instead.
ls .logic-loom/AGENTS.md 2>/dev/null
```

**When ADOPTED, `extract-proposals.sh` filters proposals against the
receipt's `wrote` list itself** — a proposal for a path the adopt applier
never wrote is dropped before it reaches you, so this is enforced by the
script, not left to your judgement. What the script cannot know is *why*
that's correct, which is why this section states it in prose:

- **The adopter's root `CLAUDE.md`, `AGENTS.md`, `README.md`, and
  `package.json` are theirs and are never proposal targets.** The naive
  reading — "upstream changed a file with this name, propose it" — fails
  because these are different documents that merely share a filename with
  the template's own: measured overlap in one reported case was 1–7 lines.
  The adopter's `package.json` also carries an npm `workspaces` key the
  template's does not; "take upstream" on that file would break every
  workspace script in their build.
- **The harness's own operating instructions install to `.logic-loom/AGENTS.md`**,
  byte-identical to upstream `AGENTS.md` apart from the version stamp. An
  upstream `AGENTS.md` change is legitimate and should reach you — but as a
  proposal against `.logic-loom/AGENTS.md`, not root `AGENTS.md`.

| Step | TEMPLATE CLONE | ADOPTED |
|---|---|---|
| 1 · Pre-Assessment | as written | as written |
| 2 · Fetch Upstream | as written | as written |
| 3 · Extract Proposals | as written | as written — `extract-proposals.sh` filters out any path the adopt receipt never wrote, including root `CLAUDE.md`/`AGENTS.md`/`README.md`/`package.json` |
| 4 · Present Proposals | as written, including the inherited-maintainer-CI check | **skip the inherited-maintainer-CI check** — nothing under `.github/` in an adopted repo came from LogicLoom (see Step 4 below); if filtering emptied the visible set, say so plainly rather than showing nothing unexplained |
| 5 · Apply Accepted | as written | as written |
| 6 · Update Sync Reference | as written | as written, **plus**: if the visible proposal set is empty solely because filtering removed everything, advance `.sdd-sync-ref` anyway — see Step 6 below |
| 7 · Validate | as written | as written |

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

**TEMPLATE CLONE only (see Step 0) — check for inherited maintainer-only CI.**
A repository that CLONED the LogicLoom template and never ran
`/initialize-project` still has the four workflows that release and guard the
LogicLoom template itself. One of them actively breaks the project:
`branch-topology-guard.yml` fails **every** PR into `main` whose head branch is
not `release/vX.Y.Z`.

```bash
ls .github/workflows/branch-topology-guard.yml \
   .github/workflows/promote-to-main.yml \
   .github/workflows/release-tag.yml \
   .github/workflows/leak-guard.yml 2>/dev/null
```

If any are present, say so plainly at the top of the proposal output — one short
paragraph naming `branch-topology-guard.yml` as the one that will reject their
PRs, and the exact `rm` command for all four. **Do not delete them yourself**:
this command is proposal-based and each item is the user's call. Keep
`plugin-tests.yml`. This is a message, not machinery — there is no state, no
flag, and no automatic removal.

**ADOPTED — skip this check entirely.** The `npx logicloom init` payload
excludes `.github/` wholesale (`packaging/adopt/payload-manifest.txt`), so
**nothing under `.github/workflows/` in an adopted repository came from
LogicLoom** — every workflow there, including one that happens to share a
name like `release-tag.yml` or `leak-guard.yml`, is the adopter's own CI.
Never `ls`, propose, list, or suggest removing anything under an adopted
repo's `.github/`.

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

**ADOPTED, and the visible set is empty solely because filtering removed
everything:** advance `.sdd-sync-ref` anyway. Deferral and filtering are
different states — deferral means the user saw a proposal and said not yet,
filtering means the receipt's `wrote` list excluded it before the user ever
saw it. Leaving the sync ref unchanged for a fully-filtered run would rescan
and re-hide the same upstream commits forever; nothing changes by re-running.

### Step 7: Validate
Run full test suite to confirm framework integrity.

## Usage
```
/update-framework
/update-framework --check-only
```
