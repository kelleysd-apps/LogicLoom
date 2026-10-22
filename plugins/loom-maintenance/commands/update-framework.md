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
| 3b · Release migration scan | as written | as written — the registry is read from the fetched ref, so it is current even when the receipt filter would suppress the file's proposal; content checks apply only to files the receipt recorded (plus the receipt itself) |
| 4 · Present Proposals | as written, including the inherited-maintainer-CI check | **skip the inherited-maintainer-CI check** — nothing under `.github/` in an adopted repo came from LogicLoom (see Step 4 below); if filtering emptied the visible set, say so plainly rather than showing nothing unexplained |
| 5 · Apply Accepted | as written | as written, **plus**: after writing accepted files, this install records what it wrote (the recorder), then re-checks for anything that recording just unblocked, before Step 6 moves the sync ref — see Step 5 below |
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

### Step 3b: Release migration scan

Run this **regardless of Step 3's exit code** — when it emits `[]`, when it
exits 3 (sync-ref unreachable from upstream — precisely the pre-v6.2
population this scan exists for), and under `--check-only` (scan only, no
conversion offered). The fetch into `refs/loom-upstream/main` already
happened in Step 2/3, so the registry this reads is upstream-fresh even on a
run that produces zero enhancement proposals.

```bash
bash plugins/loom-maintenance/scripts/release-migrations.sh scan
```

Read-only; it never runs a mutating git command. In order, it reads:
`.logic-loom/config/release-migrations.conf` from the fetched
`refs/loom-upstream/main` ref first, falling back to the local copy only when
that ref is unavailable — this is what keeps the scan current even when the
adopted-repo receipt filter (Step 0/3) would otherwise suppress a proposal
for the registry file itself; then the project-owned
`.logic-loom/config/project-migrations.conf` (never shipped by LogicLoom — a
fork's own rows, evaluated identically); then
`.logic-loom/config/migration-decisions.conf` (the standing decisions this
project has already recorded).

Three item kinds come out of the scan:
- a **retired plugin / mcp-server / path** component — one of the four
  actions REMOVE, ADOPT-REPLACEMENT, CONVERT-TO-LOCAL, KEEP-AS-IS;
- a **moved path** — the MOVE action;
- a **content check** — a proposal with its reason (`why`); the script never
  edits the file itself.

References for a retired component are collected from the whole tree and
classified: a wired `.claude/settings.json` / `.claude/settings.local.json`
hook, a bridge command wrapper, a `.github/workflows/` CI step, a
`.mcp.json` entry, a cross-reference from another plugin, a project
agent/skill/rule, or a docs mention. **REMOVE is blocked** while a
`.claude/settings.json` hook or a `.github/` workflow still points under the
item's path — the plan's first step is then to repoint or remove that line,
not to run `git rm`.

When nothing is pending, the section printed in Step 4 is exactly the line
`Release migrations: none pending.` plus the *Decisions in force* block
whenever `migration-decisions.conf` holds at least one line — a standing
decision is never silent about what it silenced.

### Step 4: Present Proposals to User

**Present the release migration scan first, as its own section, before the
enhancement-proposal list below — on every run, `--check-only` included, and
even when nothing else is pending.**

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

The menu is per item **kind**, not per item: plugin → `[r]emove
[c]onvert-to-local [k]eep [s]kip`; mcp-server / path → `[r]emove [k]eep
[s]kip`; a moved path recommended MOVE → `[m]ove [k]eep [s]kip`; content →
`[k]eep [s]kip`. A REMOVE line shows `blocked-by: <file:line>` in place of
the menu when a settings.json hook or a `.github/` workflow still references
the path — repointing or removing that reference is the plan's first step.

When `.logic-loom/config/migration-decisions.conf` holds at least one line,
show the standing decisions next — on every run, `--check-only` included,
even when every item above reads `none pending`:

```
Decisions in force (.logic-loom/config/migration-decisions.conf — edit or delete a line to revisit)
  keep       sdd-dev-loop       plugins/sdd-dev-loop stays as-is: no upstream updates ever; CI notices it raises: floor test 1b info line, manifest validator SKIPPED line, lifecycle suite pending-migration notice; /dev-loop resolves only through its bridge wrapper
  keep       CLAUDE.md@v7.0.0   content check silenced for v7.0.0 only; nothing else is affected
  converted  sdd-debug          plugins/sdd-debug still on disk — delete it once /debug works, then run sync-plugin-commands.sh prune
  stale      sdd-foo            names nothing on disk and no registry row — remove the line
```

The rule, stated once and applied every run: a decision suppresses a proposal, never the fact that one was suppressed.

When the scan finds nothing pending, the section is exactly one line,
`Release migrations: none pending.`, plus the *Decisions in force* block
above whenever a decision exists.

**Then show the enhancement proposals.** Show categorized proposals: new
files, enhancements, structural changes. Each proposal is independently
accept/reject.

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

**Then apply accepted release-migration items (Step 3b) — in this order, so
that any clean-add from above lands before a MOVE that depends on it:**

- **`r` (remove)** — the main agent runs the item's `remove_command` on the
  user's yes. **plugin** → `git rm -r plugins/<name>` (gate policy `git.rm =
  ask`, so you approve it), then
  `.logic-loom/scripts/bash/sync-plugin-commands.sh prune` to drop the
  bridge wrapper(s) and regenerate `.bridge-manifest.json`. **mcp-server** →
  first remove the `"<name>":` entry from `.mcp.json` (the main agent edits
  it on the user's yes, showing the diff first — `.mcp.json` is not a
  protected file), then `git rm -r mcp-servers/<name>` (`git.rm = ask`).
  **path** → `git rm <path>` for a file, `git rm -r <path>` for a directory
  (`git.rm = ask`). A **blocked** REMOVE (a settings.json hook or a
  `.github/` workflow still points under the path) is skipped until the
  blocker is gone — the user repoints or removes that line themselves (for a
  moved path, until `<new>` exists on disk after its own clean-add is
  accepted); the main agent re-checks the blocker immediately before running
  `git rm`.
- **`c` (convert-to-local)** — `convert <name> --dry-run`, show it, a second
  explicit yes runs `--apply`.
- **`k` (keep)** — append `keep = <name>` to
  `.logic-loom/config/migration-decisions.conf` (or `keep = <name>@<release>`
  for a content item — that form silences every content row for that file
  and that release only; nothing else is affected).
- **`m` (move)** — the main agent runs `git mv <old> <new>` on the user's
  yes (gate policy `git.mv = ask`).
- **content `PROPOSE`** — the user edits the file, or the main agent does on
  the user's yes with the diff shown first; the script never edits it.
- **`s` (skip)** — nothing is recorded; the item reappears next run.

Migration decisions never touch `.sdd-sync-ref`. This command never edits
`.claude/settings.json` — a wired-hook blocker is always removed by the
user's own edit. After a `c` conversion: delete `plugins/<name>` once
`/<name>` (or the converted command) works — and only if that `--apply`
run's closing lines said `accounted: every file under plugins/<name> is
carried over`, never after `DO NOT delete plugins/<name> yet` (which names
what was left behind) — then run `sync-plugin-commands.sh prune` (Step 7
repeats this reminder).

**ADOPTED repos only — record what this run wrote.** After writing every
accepted `clean-add` / `clean-apply` file above, run:

```bash
bash plugins/loom-maintenance/scripts/record-update-writes.sh --version <upstream FRAMEWORK_VERSION> <each written path>
```

This appends one run to `.logicloom-adopt-receipt.json` — no git, one JSON
file, committed together with the rest of this update — so a later
`/update-framework` run can reach these files instead of silently
suppressing their next upstream edit (mechanism:
`.docs/guides/MIGRATION_GUIDE.md`). If the scan showed the `MG-` item on
`.logicloom-adopt-receipt.json` itself (Step 3b) and the user accepted it,
run:

```bash
bash plugins/loom-maintenance/scripts/record-update-writes.sh --reconcile
```

Show the user the `RECONCILE` lines (byte-identical to the sync-ref copy —
safe to record ONLY because `--reconcile` itself first refuses to run at all
unless the sync-ref is provably LogicLoom's own record: a hex object name
that `refs/loom-upstream/main` exists locally and reaches. Without that,
"byte-identical to the sync-ref" proves nothing about who wrote those
bytes — an adopted repo's own sync-ref could equally point at a customer
commit that happens to match a customer file already on disk — so
`--reconcile` lists and records nothing and prints why, instead of ever
stamping unproven evidence as LogicLoom's) and the `DIFFERS` lines (differs
from upstream — never recorded automatically) it prints; on a second yes,
re-run with `--reconcile --apply`. A `DIFFERS` file is never recorded by
`--reconcile` — the user may record one explicitly, if they accepted it
through `/update-framework` and edited it afterwards, with
`bash plugins/loom-maintenance/scripts/record-update-writes.sh <path>`.

**Re-check for changes this run's own recording just unblocked, before Step
6 moves the sync ref.** Step 3 extracted proposals against the OLD
`.sdd-sync-ref`, before the record/reconcile calls above made any path
owned for the first time this run — an upstream change to a path that was
still unowned at Step 3 stays suppressed unless it is checked again now,
and Step 6 moves `.sdd-sync-ref` straight past it, so a missed check here
is permanent, not merely delayed to next run. Skip this when nothing was
recorded or reconciled above. Otherwise, re-run extraction once more against
the same `.sdd-sync-ref` (unchanged; Step 6 has not run yet); the script
fetches upstream again, so if upstream moved in the meantime the re-run
simply covers those commits too — the same tip Step 6 then records:

```bash
bash plugins/loom-maintenance/scripts/extract-proposals.sh
```

To tell what is new, **compare by path against Step 3's list**
(`upstream_file`): every path Step 3 already showed reappears, and a file
this run just applied now reads `conflict-review` or `already-present` (its
working copy matches upstream, not the sync-ref) — none of that is new and
none of it is applied again. A path Step 3 never listed is the unlock.
Present those as their own short list,
**Proposals unlocked by this run's recording**, and apply each per this
step's resolution rules above, on the user's yes — before Step 6 runs.
Then **record any path this re-check writes** with the recorder command
above — an unlocked `clean-add` is a new file the receipt does not know
yet. Nothing new appears → say so in one line and continue.

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

If any release-migration item was converted this run, remember the two
follow-ups: delete `plugins/<name>` once its converted command/skill works
(only if the convert run reported every file accounted for — a `DO NOT
delete … yet` run names the files it left behind), then run
`.logic-loom/scripts/bash/sync-plugin-commands.sh prune` — neither happens
automatically.

## Usage
```
/update-framework
/update-framework --check-only
```
