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

The LogicLoom framework is a development platform that gets cloned to create independent
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

2. Run the release migration scan — **regardless of extraction's exit code**
   above (also when it emits `[]`, when it exits 3 because the sync-ref is
   unreachable from upstream, and under `--check-only`):
   ```bash
   bash plugins/loom-maintenance/scripts/release-migrations.sh scan
   ```
   Read-only; never runs a mutating git command. It reads
   `.logic-loom/config/release-migrations.conf` from the fetched
   `refs/loom-upstream/main` ref first (falling back to the local copy),
   then the project-owned `.logic-loom/config/project-migrations.conf`
   (never shipped upstream), then
   `.logic-loom/config/migration-decisions.conf`. Presented in Step 4b.

**Validation**: Proposals extracted as JSON; the migration scan ran and its
output is available for Step 4b regardless of the proposal count.

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
  EP-005: [config] .logic-loom/AGENTS.md — New command table entries — Accept? [y/N]
```

`.logic-loom/AGENTS.md` (harness-owned) is the correct example here, never
root `CLAUDE.md` / `AGENTS.md` / `README.md` / `package.json` — those are the
adopter's own and are never proposal targets. See Step 0 of
`update-framework.md` for why and for the receipt-filtering mechanism.

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

### Step 4b: Present release migrations and decisions

**Action**: Show the release migration scan's output as its own section,
**before** the enhancement-proposal list in Step 4 above — on every run,
including `--check-only`, and even when nothing else is pending.

**Tasks**:
1. The scan itself runs in Step 3 (`release-migrations.sh scan`), regardless
   of whether extraction produced any enhancement proposals.
2. Present one block per item, `MG-NNN` ids in registry order:

```
Release migrations for this repository   (registry: upstream refs/loom-upstream/main, 24 rows)
──────────────────────────────────────────────────────────────────────────────
MG-001  plugins/sdd-dev-loop   removed in v6.2.0 · replaced by native /workflow, /loop, /goal
        state: PRISTINE (baseline sync-ref 7d1c2e0 — 0 changed, 0 added)
        contains: 1 command (/dev-loop), 1 skill (core-loop), 3 config files
        referenced by: .claude/commands/dev-loop.md (bridge wrapper — pruned by sync-plugin-commands.sh prune)
        recommended: REMOVE            [r]emove  [c]onvert-to-local  [k]eep  [s]kip
MG-002  plugins/sdd-debug      removed in v5.1.0 · no successor
        state: CUSTOMIZED (baseline sync-ref 7d1c2e0 — 1 changed: commands/debug.md; 1 added: skills/sdd-debug/notes.md)
        contains: 1 command (/debug), 1 skill (sdd-debug), 1 agent (auto-debug-agent), 1 hook script
        wired hooks: .claude/settings.json:47 bash plugins/sdd-debug/hooks/scripts/debug-capture.sh  ← will dangle
        recommended: CONVERT-TO-LOCAL  (dry-run shown before anything is written)
MG-003  .logicloom-adopt-receipt.json   content check (v7.0.0, ADOPTED repos only)
        proposal: run bash plugins/loom-maintenance/scripts/record-update-writes.sh --reconcile once
        why: before v7.0.0 the adopt receipt was never written after install, so every later upstream edit to an update-added file was silently suppressed
        recommended: PROPOSE           [k]eep  [s]kip
Dangling hook wiring (plugin already gone): .claude/settings.json:73 bash plugins/sdd-governance/hooks/scripts/git-safety-gate.sh
Summary: 3 pending, 0 kept, 0 converted
```

3. The menu is per item **kind**, not per item: plugin →
   `[r]emove [c]onvert-to-local [k]eep [s]kip`; mcp-server / path →
   `[r]emove [k]eep [s]kip`; a moved path recommended MOVE →
   `[m]ove [k]eep [s]kip`; content → `[k]eep [s]kip`. A REMOVE line shows
   `blocked-by: <file:line>` in place of the menu when a settings.json hook
   or a `.github/` workflow still references the path — repointing or
   removing that reference is the plan's first step, before any `git rm`.
4. When `.logic-loom/config/migration-decisions.conf` holds at least one
   line, show it next — on every run, `--check-only` included, even when
   every item above reads `none pending`:

```
Decisions in force (.logic-loom/config/migration-decisions.conf — edit or delete a line to revisit)
  keep       sdd-dev-loop       plugins/sdd-dev-loop stays as-is: no upstream updates ever; CI notices it raises: floor test 1b info line, manifest validator SKIPPED line, lifecycle suite pending-migration notice; /dev-loop resolves only through its bridge wrapper
  keep       CLAUDE.md@v7.0.0   content check silenced for v7.0.0 only; nothing else is affected
  converted  sdd-debug          plugins/sdd-debug still on disk — delete it once /debug works, then run sync-plugin-commands.sh prune
  stale      sdd-foo            names nothing on disk and no registry row — remove the line
```

5. State the rule every time this block is shown: a decision suppresses a proposal, never the fact that one was suppressed.
6. When the scan finds nothing pending, the section is exactly one line,
   `Release migrations: none pending.`, plus the *Decisions in force* block
   above whenever a decision exists.

**Validation**: Release-migration section shown before the enhancement
proposals, every menu is kind-appropriate, and the decisions block (when
non-empty) is never skipped.

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

### Step 7b: Apply migration decisions and record adopted writes

**Action**: Apply accepted release-migration items (Step 4b), then — in an
ADOPTED repo — record what this run wrote.

**Principle VI throughout**: the script never runs git. The main agent runs
`git rm` / `git mv` only on the user's per-item yes.

**Tasks**:

1. Apply migration items **after** the enhancement-proposal apply above, so
   any accepted clean-add lands before a MOVE that depends on it:
   - **`r` (remove)** — the main agent runs the item's `remove_command` on
     the user's yes. plugin → `git rm -r plugins/<name>` (gate policy
     `git.rm = ask`), then
     `.logic-loom/scripts/bash/sync-plugin-commands.sh prune`. mcp-server →
     first remove the `"<name>":` entry from `.mcp.json` (main agent edits
     it on the user's yes, diff shown first), then
     `git rm -r mcp-servers/<name>`. path → `git rm <path>` (`git rm -r
     <path>` for a directory). A **blocked** REMOVE (a settings.json hook or
     a `.github/` workflow still points under the path) is skipped until the
     blocker is gone — the main agent re-checks immediately before running
     `git rm`.
   - **`c` (convert-to-local)** — `convert <name> --dry-run`, show it, a
     second explicit yes runs `--apply`.
   - **`k` (keep)** — append `keep = <name>` (or `keep = <name>@<release>`
     for a content item — silences every content row for that file and
     release only) to `.logic-loom/config/migration-decisions.conf`.
   - **`m` (move)** — the main agent runs `git mv <old> <new>` on the
     user's yes (gate policy `git.mv = ask`).
   - **content `PROPOSE`** — the user edits the file (or the main agent
     does, on the user's yes, diff shown first); the script never edits it.
   - **`s` (skip)** — nothing recorded; reappears next run.
   - Migration decisions never touch `.sdd-sync-ref` (Step 8 is unchanged
     by any of this).
2. **ADOPTED repos only — record what this run wrote.** After writing every
   accepted `clean-add` / `clean-apply` file (Step 7):
   ```bash
   bash plugins/loom-maintenance/scripts/record-update-writes.sh --version <upstream FRAMEWORK_VERSION> <each written path>
   ```
   One JSON file, no git; committed together with the rest of the update
   (Step 10). This is what lets a later `/update-framework` run reach these
   files instead of silently suppressing their next upstream edit.
3. If the Step 4b scan showed the `MG-` item on
   `.logicloom-adopt-receipt.json` itself and the user accepted it, run:
   ```bash
   bash plugins/loom-maintenance/scripts/record-update-writes.sh --reconcile
   ```
   Show the user the `RECONCILE` lines (byte-identical to the sync-ref copy
   — safe to record ONLY because `--reconcile` itself first refuses to run
   at all unless the sync-ref is provably LogicLoom's own record: a hex
   object name that `refs/loom-upstream/main` exists locally and reaches.
   Without that, "byte-identical to the sync-ref" proves nothing about who
   wrote those bytes — an adopted repo's own sync-ref could equally point
   at a customer commit that happens to match a customer file already on
   disk — so `--reconcile` lists and records nothing and prints why,
   instead of ever stamping unproven evidence as LogicLoom's) and the
   `DIFFERS` lines (differs from upstream — never recorded automatically).
   On a second yes, re-run with `--reconcile --apply`. A `DIFFERS` file is
   never recorded automatically — the user may record one explicitly, if
   they accepted it through `/update-framework` and edited it afterwards,
   with `bash plugins/loom-maintenance/scripts/record-update-writes.sh <path>`.
4. **Re-check for changes this run's own recording just unblocked, before
   Step 8 moves the sync ref.** Step 3's extraction ran against the OLD
   `.sdd-sync-ref` — before task 2's record or task 3's reconcile made any
   path owned for the first time. An upstream change to a path that was
   still unowned at Step 3 stays suppressed unless it is checked again now;
   Step 8 moves `.sdd-sync-ref` straight past it, so a missed check here is
   permanent, not merely delayed to next run. Skip this task when tasks 2
   and 3 recorded or reconciled nothing (a TEMPLATE repo, or an ADOPTED repo
   with nothing new to record this run). Otherwise, re-run extraction once
   more against the same `.sdd-sync-ref` (Step 8 has not run yet, so it is
   still the old value); the script fetches upstream again, so if upstream
   moved in the meantime the re-run simply covers those commits too — the
   same tip Step 8 then records:
   ```bash
   bash plugins/loom-maintenance/scripts/extract-proposals.sh
   ```
   To tell what is new, **compare by path against Step 3's list**
   (`upstream_file`): every path Step 3 already showed reappears, and a
   file this run just applied now reads `conflict-review` or
   `already-present` (its working copy matches upstream, not the sync-ref)
   — none of that is new and none of it is applied again. A path Step 3
   never listed is the unlock. Present those as their own short list,
   **Proposals unlocked by this run's recording**, and apply each per
   Step 7's resolution rules on the user's yes — before Step 8 runs. Then
   **record any path this re-check writes** with task 2's command — an
   unlocked `clean-add` is a new file the receipt does not know yet. No new
   proposal appears → say so in one line and continue.
5. After a `c` conversion: delete `plugins/<name>` once the converted
   command/skill works, then run `sync-plugin-commands.sh prune` — reminded
   again in Step 9.

**Validation**: Every accepted migration item applied per its action; in an
ADOPTED repo the recorder ran over the accepted write set with no git
invoked by the script; any proposal unlocked by this run's recording was
re-checked and resolved before Step 8 moved `.sdd-sync-ref`.

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

# The harness suite ships with a clone and with the template, but not with the
# npm adopt payload. Run it when present; do not claim a pass when it is not.
if [ -f tests/run_all_tests.sh ]; then
  bash tests/run_all_tests.sh
else
  echo "harness-tests: NOT RUN — tests/run_all_tests.sh is not present."
  echo "harness-tests: this install did not receive the harness suite (adopt payload excludes tests/)."
  echo "harness-tests: validate the applied enhancements by hand before accepting them."
fi
```

`constitutional-check.sh` ships with every install and always runs. If the
harness suite did not run, say so in the update summary and treat the applied
enhancements as **unvalidated by regression** — review the diff manually rather
than reporting the update as verified.

If Step 7b converted any release-migration item, remind the user once more
here: delete `plugins/<name>` once its converted command/skill works, then
run `sync-plugin-commands.sh prune` — neither cleanup happens automatically.

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
