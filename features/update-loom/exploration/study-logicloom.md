# Reader B: LogicLoom's current update system and the v7 work

Scope: read-only study of `/Users/bkelley/kelleysd-apps/LogicLoom` (branch `feature/v7-update-migrations`, HEAD `29383e6`), plus read-only looks at `kori-beta` and `launchhouse-founder-template`. Nothing was built; this is the only file written.

Method and limits. I read the files cited. I did NOT run any test suite: `test_update_from_6x.sh` and the ownership suites build throwaway repos with `commit-tree`/`update-ref`/`git archive` and run the adopt CLI under node, which is mutating git/process work I was told not to do. Every claim about "what the old updater accepts" is therefore derived from reading the v6.6.2 script (saved copy of `git show v6.6.2:plugins/loom-maintenance/scripts/extract-proposals.sh`) and the test's own description of itself, not from a run. Anything I could not check is marked UNVERIFIED.

Line citations: `HEAD:` means this working tree; `v6.6.2:` means `git show v6.6.2:<path>`. "6.6.2" is the version customers actually hold (public `origin/main` = `123b18e`, tag `v6.6.2` = `75e6dff`).

---

## 0. Findings that change the design brief (read first)

1. **The shipped updater has no adopted-install filter. The brief's premise for constraint C is true only of unreleased code.** `v6.6.2:extract-proposals.sh` is 428 lines and contains zero occurrences of `adopt_file_recorded`, `ADOPT_MODE`, `detect_adopt_mode` (I counted 0 on `v6.2.0`, `v6.3.1`, `v6.4.0`, `v6.5.0`, `v6.6.0`, `v6.6.1`, `v6.6.2`, and on `origin/main`). The receipt filter (HEAD `extract-proposals.sh:592-643`) landed in `39b59d5` (2026-09-02, dev-main only) and is in no tag and no `origin/main` commit. `tests/contract/test_update_from_6x.sh:62-72,367-377` pins the same finding. So a 6.x adopted install does NOT receive "only files its receipt recorded"; it receives the same unfiltered diff a template clone does (section 2). The filter matters only if some future release ships that extractor, which the "replace the whole system" decision makes moot.
2. **Nothing from v7 has shipped.** All 8 commits since `2ca2340` exist only on `feature/v7-update-migrations` (`git branch -a --contains 6d7c066` lists only this branch; `origin/dev-main` is still `2ca2340`; no tag contains them). "Retiring the scanner" therefore needs no customer-facing migration; it is a branch decision. No customer holds `release-migrations.sh`, `record-update-writes.sh`, `migration-decisions.conf`, or a `.logicloom-adopt-receipt.json` row stamped `logicloom-update-framework@`.
3. **The gate is a string gate that cannot see inside a script.** `git-safety-gate.sh:10-14` states it: `bash script.sh`, `eval`, `G=git; $G push` are invisible. A ported `update.sh` that runs `git commit`/`tag`/`worktree add`/`merge --ff-only` internally is judged by NO row of `gate-policy.conf` (section 5.3). It also over-triggers: during this study the subagent hook denied plain `grep`/`for` commands that merely contained the words `git tag`/`git commit`, which is relevant to how the engine's own commands will be quoted in skills.
4. **Launchhouse's engine uses an `upstream` git remote; LogicLoom forbids one.** `launchhouse update.sh:72-79` runs `git remote add upstream` and `set-url --push upstream DISABLED`, then `git fetch upstream` (`:285,882,1096,1645`). LogicLoom's invariant (HEAD `update-framework.md:11-15`; `FRAMEWORK_SYNC_GUIDE.md:19-24`) is fetch-only into `refs/loom-upstream/main` with no remote; `git remote add` is `git.remote.write = ask` (`gate-policy.conf:160`). The port must keep `extract-proposals.sh`'s ad-hoc `git fetch <url> +refs/heads/main:refs/loom-upstream/main` (`:107-116`).
5. **Populations the old updater cannot serve at all** (constraint C): clones whose `.sdd-sync-ref` is not an ancestor of public main exit 3 (section 1.3). I verified `c6092b0` (stamped in tags `v6.3.0`, `v6.4.1`, `v6.5.0`) exists locally but is NOT an ancestor of `origin/main`, and is not in the remap table (`v6.6.2:extract-proposals.sh:127-138` maps only `6c4c420`, `c6d040f`). A missing `.sdd-sync-ref` makes the old script baseline at upstream tip and adopt NOTHING (`:145-155`), so the engine never arrives for that customer either.
6. **The old Step 6 silently discards rejected proposals.** If the customer accepts at least one proposal, `.sdd-sync-ref` moves to the upstream tip (`v6.6.2:update-framework.md:77-82`, skill `:190-197`). Anything they declined in that run is never shown again. Presence-by-base-tree detection will treat everything in the new sync-ref's tree as "already decided".
7. **The kori-beta "ladder" row cites a public source that does not exist.** The advisory row (`release-migrations.conf:88`) tells the customer to see `~/.claude/CLAUDE.md` and `.docs/architecture/orchestrator-worker-ladder.md` for "the current wording". The ladder doc has no 0/1/3-plus-3 scale (it has only "Effort follows cost", `:78-110`, and says the ladder lives in "a personal CLAUDE.md"); `git grep "changes auth, payment"` finds the sentence only in the registry, the guide and tests. A shipped note must carry the target wording itself, and must not mention the maintainer's home file.
8. **New directories directly under `.claude/` are invisible to the HEAD adopted filter and to the bash-3.2 floor test.** In kori-beta's receipt the recorded `dir` entries are `.claude/agents/`, `commands/`, `context/`, `hooks/`, `hooks/user-prompt-submit/`, `policies/`, `schemas/` but NOT `.claude/` itself, so `adopt_offer_added_path` (HEAD `:456-472`) returns SUPPRESS for any new `.claude/updates/` or `.claude/scripts/` path. `test_bash32_floor.sh` scans only `.logic-loom`, `.claude/hooks`, `tests`, `packaging/adopt` and declared plugin roots (`:177-195`), so `.claude/scripts/update.sh` and `.claude/updates/*.check.sh` would be unscanned. The adopt payload also has no `.claude/scripts`, `.claude/skills`, or `.claude/updates` row (`payload-manifest.txt` includes only `.claude/hooks|commands|context|agents|policies|schemas`). Everything new should live under `plugins/loom-maintenance/` or `.logic-loom/`, both payload-included, receipt-recorded, and floor-scanned.
9. **Retired-plugin tolerance is wired into six shipped CI checks through the registry lib.** `tests/contract/plugins/test_plugin_lifecycle.sh:37-41,108`, `test_bash32_floor.sh:202-296`, `test_deprecation.sh`, `test_model_agnostic.sh:78-82`, `test_plugin_manifest_schema.sh:146-147`, and `.logic-loom/scripts/python/validate-plugin-manifests.py:207-232` all consult `release-migrations.conf` (via `loom_is_deprecated_plugin_dir`) so a customer who still holds `plugins/sdd-*` does not turn their CI red. Retiring the 790-line lib/registry must keep a tiny flat "retired plugin names" list, or case (a) breaks every customer's CI.
10. **`CHANGELOG.md` is maintainer-only (stripped).** `template-strip-manifest.txt:126`. Customers never see the "Migrating from 6.x" text; notes (and `.docs/guides`) are the only channel for migration prose.
11. **Notes will trip the leak-guard history gate unless exempted.** `leak-guard.sh:145-152` fails any shipped file containing markers such as `from v5.0.0`, `introduced in v5.0.0`, `(legacy)`, `Removal Target: v`; `framework-updater/*` and `extract-proposals.sh` are already KEEP-zoned (`:150-151`). Retired-plugin notes are exactly that kind of prose. ID markers (`brian@kelleysd.com`, `kelleysd.com/`, `ioun-ai`, `/workspaces/`, `:51`) apply too.
12. **Real adopted evidence exists and shows the ownership rot.** kori-beta's receipt has exactly one run, `logicloom@6.6.1`, 393 wrote entries (282 file, 109 dir, 2 merge); its `.sdd-sync-ref` is `123b18e` (the public main tip after the 6.6.2 PR) and `.logic-loom/AGENTS.md` says 6.6.2. So that repo already ran the old updater past the install version, and the receipt does not know about what it wrote.

---

## 1. `/update-framework` mechanics

### 1.1 What a customer actually runs (6.6.2) versus HEAD

| | v6.6.2 (shipped) | HEAD (unreleased v7) |
|---|---|---|
| Command text | `update-framework.md` 91 lines | 364 lines (`+212` vs `2ca2340`) |
| Skill | `framework-updater/SKILL.md` 276 lines | 465 lines |
| Extractor | `extract-proposals.sh` 428 lines | 771 lines (adopted filter `:285-643` is pre-v7, from `39b59d5`; only +25 lines are v7) |
| Extra scripts | none | `release-migrations.sh` 4,805, `record-update-writes.sh` 1,556, lib 790 |
| Bridge stub | `.claude/commands/update-framework.md`: "Read and execute ... plugins/loom-maintenance/commands/update-framework.md" (unchanged since 6.6.2; `.claude/commands/update-framework.md:10`) | same |
| Agent named | `.claude/agents/framework-sync-agent.md` (30 lines, tools Read/Write/Edit/Bash/Grep/Glob; a project agent) | same |

### 1.2 The 6.6.2 procedure, step by step

Command (`v6.6.2:update-framework.md`): Step 1 `claude --version`, `cat .sdd-sync-ref` (`:19-23`); Step 2 states the fetch happens inside the script, no `upstream` remote (`:25-30`); Step 3 `bash plugins/loom-maintenance/scripts/extract-proposals.sh` (`:32-38`); Step 4 present proposals + the inherited-maintainer-CI warning (`:40-63`); Step 5 apply (`:65-75`); Step 6 `git rev-parse refs/loom-upstream/main > .sdd-sync-ref` only if at least one proposal accepted (`:77-82`); Step 7 run the test suite (`:84-85`). There is no channel detection (Step 0 is HEAD-only) and no `--check-only` implementation (the usage line `:87-91` names it, the script has only `--dry-run`/`--help`, `:41,424`).

Skill (`v6.6.2:SKILL.md`, 10 steps): Step 6 checkpoint tag `git tag "loom/pre-update-$(date +%Y%m%d-%H%M%S)" HEAD`, undo via `git reset --hard <tag>` (`:144-153`); Step 7 apply (`:158-188`) — `clean-add`/`clean-apply` write with `git show refs/loom-upstream/main:"$file_path" > "$file_path"` (`:166`); Step 8 sync-ref update (`:190-197`); Step 9 `constitutional-check.sh` then `bash tests/run_all_tests.sh`, already guarded by `[ -f tests/run_all_tests.sh ]` in 6.6.2 (`:206-227`; `payload-manifest.txt:428-440` records why); Step 10 commit with approval (`:229-246`).

So the apply mechanism is a plain redirect by the main agent, not a script. Consequences (all from the text above, none executed): new files get mode 644 (a shell redirect creates no exec bit; `./.logic-loom/scripts/bash/constitutional-check.sh` in skill Step 9 is invoked directly, UNVERIFIED whether that bites); parent directories are created by the model's own `mkdir -p` (the fixture simulates it, `test_update_from_6x.sh` §D `:441-480`); `.claude/settings.json` and `.claude/hooks/*` writes by the main agent hit `protect-governance-files.sh` = ASK; and the skill's own tag step (git.tag.write = silent) and commit (git.commit = silent) are the only git the old flow runs.

### 1.3 `extract-proposals.sh`: resolutions, sync-ref, fetch

Common to 6.6.2 and HEAD (HEAD line numbers; 6.6.2 numbers in brackets):

- **Upstream URL** `:92-104` [`:77-90`]: env `LOOM_UPSTREAM_URL`, then `framework-upstream.conf` (`LOOM_UPSTREAM_URL`, then `LOOM_UPSTREAM_REPO`), never `origin`; unresolved exits 2 (`:708-718`).
- **Fetch** `:107-116` [`:92-102`]: `git fetch --no-tags [--no-write-fetch-head] <url> +refs/heads/main:refs/loom-upstream/main`. Always branch `main`, full history, no remote.
- **Base** = contents of `.sdd-sync-ref` (`:118-120`). Diff is `git diff --name-status <sync-ref>..refs/loom-upstream/main` (`:479` [`:273`]); `.sdd-sync-ref` itself is skipped (`:505` [`:281`]).
- **Resolutions** (3-way: base blob vs working file vs upstream), HEAD `:538-576` [`:303-324`]:
  - `M|R*` and working file equals sync-ref blob: `clean-apply`; otherwise `conflict-review`.
  - `A` and working file equals upstream: `already-present`; otherwise `conflict-review`.
  - `D`: `info-upstream-deleted` (file still present) / `info-already-absent`.
  - File absent downstream and status `A` OR `M`: `clean-add` (`:572-576` [`:323`]). So a file the customer deliberately deleted is re-offered the next time upstream edits it.
  - Rename: `structural-change`, `breaking: true`, manual (`:581-584` [`:332-335`]). 6.6.2 reads two fields only, so a rename's `upstream_file` carries an embedded tab (the test works around it, `test_update_from_6x.sh:304-326`); HEAD reads the third field (`:495-503`).
- **Release grouping** via `find_tag_for_file` (`:222-243`): tags found by walking `sync-ref..upstream`; `--no-tags` fetch means only tags reachable as local refs resolve (UNVERIFIED how often `release_tag` is null in practice).
- **Sync-ref guard** `ensure_sync_ref` HEAD `:160-206` [`:145-191`]:
  - Missing file: set baseline to upstream tip, print "Adopting nothing this run", emit `[]`, exit 0 (`:163-170` [`:149-155`]).
  - Not a commit, or not an ancestor of upstream main: try the remap (`:142-153` [`:127-138`]) which maps exactly two bad stamps (`6c4c420...` to `a2ed862...` for v6.3.1, `c6d040f...` to `75551c3...` for v6.4.0); else exit 3 with manual-fix text (`:189-203`). The remap exists only in v6.4.1+ scripts, so a v6.3.1/v6.4.0 customer holds a script that cannot self-repair.
  - Verified facts about stamps (my `git merge-base --is-ancestor` runs): reachable from `origin/main`: tags v6.2.0, v6.3.0, v6.4.1, v6.5.0, v6.6.0, v6.6.1, v6.6.2 as commits, and the 6.6.0/6.6.1/6.6.2 stamps (`2ab14e9`, `d762991`, `ea41228`). NOT reachable: `c6092b0` (the `.sdd-sync-ref` inside tags v6.3.0, v6.4.1, v6.5.0). Public main's root commit is `0e28655` (v6.2.0), so pre-6.2 history never existed on public main.
  - `plugin-tests.yml:119-124` and `release-tag.yml`/`promote-to-main.yml:497-583` exist to keep future stamps reachable; `test_release_sync_ref.sh` (350 lines) guards it. These stay relevant as long as `.sdd-sync-ref` is the base.

**Populations, by what the old updater does** (UNVERIFIED which actually exist in the field):

| Customer | Old `/update-framework` outcome |
|---|---|
| 6.6.0 to 6.6.2, template or adopted | Works; sync-ref reachable. Engine can arrive. |
| 6.4.1 / 6.5.0 / tag-clones with `c6092b0` | Exit 3, no remap. Needs a manual repair (`FRAMEWORK_SYNC_GUIDE.md` "Broken sync baseline", KNOWN_ISSUES.md `:55-112`) before any bootstrap. |
| 6.3.1 / 6.4.0 | Script has no remap (added in 6.4.1); manual repair table in KNOWN_ISSUES.md `:68-76`. |
| No `.sdd-sync-ref` | Baselines at tip, adopts nothing; a second run then shows only later changes. Engine never arrives unless a later release re-ships it. |
| Pre-6.2 (`.specify/` layout) | Out of scope of any registry; CHANGELOG "Migrating from 6.x" and `MIGRATION_GUIDE.md:577-582` say re-baseline first and that the `.specify/` to `.logic-loom/` rename is not covered. |

### 1.4 Channel detection (HEAD only; absent in 6.6.2)

- Command Step 0 (HEAD `:19-70`): ADOPTED if `.logicloom-adopt-receipt.json` contains `"schema": "logicloom/adopt-receipt@1"` (`:35`), else fallback tell `.logic-loom/AGENTS.md` exists (`:39`; only the adopt path installs AGENTS.md there, a template clone has it at root).
- Script `detect_adopt_mode` (`:299-371`): python3 parses the receipt; statuses `complete|partial|in-progress` only; collects `kind\tpath` pairs; no python3 means "receipt unusable" and a degraded deny-list posture (`:431-440`, `:698-701`).
- Adopted-only prose: root `CLAUDE.md`/`AGENTS.md`/`README.md`/`package.json` are the adopter's; harness AGENTS.md lives at `.logic-loom/AGENTS.md` (`:48-59`); `.github/` is never LogicLoom's in an adopted repo (`:215-221`, from `payload-manifest.txt` `exclude: .github`).

Receipt format (read from kori-beta `.logicloom-adopt-receipt.json`): top keys `schema`, `runs`, `uninstall`; each run has `at, generator, node, payloadSource, only, root, claudeMd, status, wrote, skipped, failed, notAttempted`; `wrote` items are `{target, path, kind: file|dir|merge}`; the two merges are `.gitignore` (marked block) and `.claude/settings.json` (hooks object, with `.claude/.logicloom-adopt-settings.json` recording what was inserted). The receipt is tracked in kori-beta's git (`ls-files --error-unmatch` succeeded).

### 1.5 The HEAD receipt filter (the thing the brief calls ~:592-606)

HEAD `extract-proposals.sh:592-643`, ADOPTED only: a merge-channel path (`.gitignore`, `.claude/settings.json`) is rewritten to `info-adopted-merge-channel` pointing at `npx logicloom@<ver> init --apply --only=hooks,gitignore` (`:593-599`); with a usable receipt `M|D|R*` is proposed only if the path is a recorded `file` (`:601-610`), `A` only per `adopt_offer_added_path` (`:456-472`: some ancestor dir recorded, and no ancestor that already existed upstream at the sync-ref missing from `wrote`); with an unusable receipt a deny-list suppresses `CLAUDE.md|AGENTS.md|README.md|package.json|.github/*|tests/*|TEMPLATE_INIT.md` (`:431-440`). Given finding 1 this code has never run on a customer machine.

### 1.6 What the v7 additions to the command do (HEAD, all retiring)

Step 3b scan (`:93-136`), Step 4 migrations section and decisions block (`:138-188`), Step 5 apply `r/c/k/m/s` items (`:235-272`), recorder and reconcile (`:274-306`), re-check unlock (`:308-334`), Step 6 empty-after-filter advance (`:343-348`), Step 7 conversion follow-ups (`:353-358`). The Step 0 table (`:61-70`) is the only part with lasting value (channel-specific behaviour), and it describes a filter that never shipped.

---

## 2. What a 6.6.x install will and will not accept through its existing updater

Derived from `v6.6.2:extract-proposals.sh` (read, not run). The fixture strategy in `test_update_from_6x.sh` (`:202-304`) runs exactly this script against a v6.6.2 archive plus a grafted upstream commit; I did not run it.

| Upstream change | Template clone | Adopted (6.6.x npm install) |
|---|---|---|
| New file at any path, absent locally (including new top-level dirs such as `.claude/updates/`, `plugins/loom-maintenance/updates/`, `.logic-loom/updates/`) | `clean-add` | `clean-add`. No filter exists. |
| New file where customer already has a different file at that path | `conflict-review` (never overwritten) | same |
| Modified file, customer's copy byte-equal to sync-ref blob | `clean-apply` | same; but only if the adopt copy is byte-identical to the tag blob. Not true for `AGENTS.md` (installed at `.logic-loom/AGENTS.md`, `payload-manifest.txt` `rename:`), `.claude/settings.json` and `.gitignore` (merge channels) |
| Modified file the customer changed | `conflict-review`, "never overwrite" (command `:69-72`) | same |
| Root `CLAUDE.md`, `README.md`, `package.json`, `AGENTS.md`, `START_HERE.md`, `KNOWN_ISSUES.md` | offered like any file | offered although not the adopter's: `clean-add` if absent, `conflict-review` if they have their own; the model must decline them (`MIGRATION_GUIDE.md:540-548`) |
| Anything under `tests/` or `.github/` | normal | offered although the adopt payload excludes both (`payload-manifest.txt` `exclude: tests`, `exclude: .github`); adopter would receive harness CI and the harness test suite into their product repo if they accept |
| `.logic-loom/AGENTS.md` (harness operating text) | n/a | the upstream edit appears as a change to root `AGENTS.md`, so it lands against the adopter's own file and never reaches `.logic-loom/AGENTS.md` through the old path |
| Upstream deletes a file | `info-upstream-deleted`, customer file stays | same. A retired `plugins/sdd-*` therefore stays on disk (case a) |
| Rename | `structural-change`, manual | same |
| Executable bit | not preserved on new files (redirect write) | same (UNVERIFIED impact) |
| Run scripts, edit `settings.json`, regenerate `.bridge-manifest.json`, delete anything | never | never. `settings.json` is `conflict-review` for any customer who changed it; for adopted it is a merge-channel file whose edit the model must do by hand |

What this means for arrival of the new system (constraint C), as facts:

- **Everything new can arrive**: engine scripts, notes, the `/update-loom` command file, its bridge stub `.claude/commands/update-loom.md`, `.claude/agents/update-adapter.md`, `.claude/agents/update-reviewer.md`, the updater skill. Each is an `A` to the old script; the only filter is the model's judgement. In an adopted repo that includes the `tests/` and `.github/` files that change in the same release; the release notes shipped through the old path cannot warn about this (the old command is what runs), only the proposal descriptions the old script generates (`describe_change`, `:248-258`).
- **The bridge stub is the load-bearing file.** `.claude/commands/update-framework.md` is only a pointer to `plugins/loom-maintenance/commands/update-framework.md`. For `/update-framework` to hand over, the plugin command file must change to a forwarding stub; that is a `clean-apply` for pristine customers and `conflict-review` for anyone who edited it, in which case they keep running the old flow. `/update-loom` must therefore work standalone, not rely on the old command having been replaced. Whether Claude Code reloads a newly added `.claude/commands/*.md` within the same session is UNVERIFIED; plan for "start a fresh session".
- **First-run handover**: after the old run, `.sdd-sync-ref` is the upstream tip T, which contains the new notes. A presence-by-base-tree rule ("in upstream tree, absent from base tree") treats every note in T as already applied (finding 6). Notes for the bridging release are never offered by the engine; anything the customer declined in the old run is silently gone.
- **Receipt**: the old flow never writes `.logicloom-adopt-receipt.json`. Files it adds are not in `wrote`, so `npx logicloom uninstall` (derived from `runs[]`) would leave them behind. The v7 recorder existed for this (`record-update-writes.sh:1-50`; `test_adopt_applier.sh:562-590` pins that `uninstallProcedure()` covers an update-shaped run). Decide whether the uninstall gap matters; it does not affect update correctness once ownership is not inferred from the receipt.
- **Case study kori-beta** (read-only): adopted by `logicloom@6.6.1`; `.sdd-sync-ref` = `123b18e`; 731 tracked files; branch `brian-dev`; an untracked `.claude/launch.json` is present (so a "working tree must be clean" precondition must ignore unrelated untracked files); its own `.claude/rules/*` and `.github/` and `package.json` are customer files; `.logic-loom/memory/amendments.md:148` still has `- 3 = it changes auth, payment, or customer-data logic`.

---

## 3. v7 inventory: `git diff --stat 2ca2340 HEAD` (57 files, +20,263 / -394, 8 commits)

Classes: KEEP = commit as is; SALVAGE = content moves into notes or a small replacement, then the original goes; RETIRE = delete with the branch work.

### 3.1 The scanner, registry and recorder

| File (lines) | Class | Why |
|---|---|---|
| `plugins/loom-maintenance/scripts/release-migrations.sh` (4,805) | RETIRE | The inference engine. Prints delete commands from guessed ownership; seven review rounds did not converge. Salvage ideas only: "is anything still wired to this path" (settings hook / workflow / `.mcp.json` / bridge wrapper) becomes a note `check`/done-when; `convert` plugin-to-skill logic becomes the adapter agent's job for a customised retired plugin (the executable-bit and unaccounted-files lessons in CHANGELOG "Fixed" go into the adapter brief). |
| `.logic-loom/lib/release-migrations.sh` (790) | RETIRE (but see 3.3) | Registry parser/linter (`loom_migration_lint`, `check-release` support). Only `loom_is_deprecated_plugin_dir` (`:324-334`) has shipped consumers (finding 9). |
| `.logic-loom/config/release-migrations.conf` (88 lines; 23 deprecation rows `:58-84` + 2 content rows `:87-88`) | SALVAGE INTO NOTES | See 3.2. Then delete. |
| `plugins/loom-maintenance/scripts/record-update-writes.sh` (1,556) | RETIRE | Exists only to feed the receipt filter that never shipped (header `:1-50`). If the maintainer wants update-added files to appear in `npx logicloom uninstall`, a trimmed append-only recorder (single JSON run append, no reconcile, no ownership inference) is the only salvageable piece; flag as an explicit decision, not a default. |
| `plugins/loom-maintenance/scripts/extract-proposals.sh` (771; +25 vs `2ca2340`) | The +25 = RETIRE; the file = SALVAGE | The +25 are the "not-installed-here" path list and the `--reconcile` hint (`:489-491,683-696`). The rest of the file: `resolve_upstream_url`, `fetch_upstream`, `read_sync_ref`, `remap_known_bad_sync_ref`, `ensure_sync_ref` (`:84-206`) are the reusable base-resolution core (fetch-only, no remote, known-bad-stamp repair). The proposal diff, 3-way resolutions, adopted detection and filter (`:245-705`) retire with the model. |
| `plugins/loom-maintenance/commands/update-framework.md` (+212) | RETIRE | Becomes the 10-line forwarding stub (section 4.1). |
| `plugins/loom-maintenance/skills/framework-updater/SKILL.md` (+186) | RETIRE | Replaced by the new updater skill; leak-guard KEEP-zone entry (`leak-guard.sh:150`) must follow the new path. |
| `.docs/guides/MIGRATION_GUIDE.md` (614) | SALVAGE then RETIRE | Keep prose that explains 6.x arrival (`:507-575`) and pre-6.2 (`:577-582`) as the source for the bootstrap note and for new `FRAMEWORK_SYNC_GUIDE.md` text; the registry/decisions/convert/recorder sections retire. It ships to both channels (`.docs/guides`), so deleting it is a deletion customers never saw. |
| `.logic-loom/lib/` consumers: `validate-plugin-manifests.py` (+73), `constitutional-check.sh` (+31) | KEEP, re-source | Both implement real tolerance (retired-plugin manifests skipped; marked project skills accepted). Re-point the registry read to the flat list (3.3); reword comments that cite `release-migrations.sh`/`MIGRATION_GUIDE.md` (`validate-plugin-manifests.py:24-32,207-220`, `constitutional-check.sh:700-701`). The `.claude/skills` relaxation is independent value: before it, ANY `.claude/skills/` warned, even for a legitimate user-authored project skill (`test_deprecation.sh` comment). |

### 3.2 The 23 registry rows, and where each goes

All 23 are retirements the customer may still hold on disk (case a). Fields in the registry: kind, name, fate, replacement, default action, first_shipped, release-without (the first tag lacking it).

| Rows (`release-migrations.conf` lines) | Count | Note content to preserve |
|---|---|---|
| `sdd-creation`, `sdd-git`, `sdd-maintenance`, `sdd-memory`, `sdd-orchestrator`, `sdd-orchestrator-hook`, `sdd-governance` renamed to `loom-*` (`:58-64`) | 7 | Rename mapping; first shipped v4.0.0/v4.1.0, gone in v6.2.0; `sdd-governance`: hooks.json, governance-preflight.cjs and rl-metrics-capture.sh have NO successor, and `git-safety-gate.sh` is wired from root `.claude/settings.json`; `sdd-orchestrator` agents moved to `.claude/agents/` (LOOM-0052). |
| `sdd-domain-{backend,database,devops,frontend,performance,security,testing}` folded into `plugins/loom-governance/domain-briefs/<d>.md` (`:66-72`) | 7 | Successor path per domain; gone v6.2.0. |
| `sdd-dev-loop`, alias `loom-dev-loop` replaced by native `/workflow`, `/loop`, `/goal` (`:74-75`) | 2 | The alias row is for a hand-rename that never shipped under that name. |
| `sdd-debug` (no successor), `sdd-domain-template` (successor `/create-plugin`) removed in v5.1.0 (`:77-78`) | 2 | `sdd-debug` is the "customised" worked example in the command doc. |
| mcp-server `sdd-marketplace` (also remove its `.mcp.json` entry) (`:80`) | 1 | External replacement: Anthropic Claude Code Plugin Marketplace + Docker MCP Toolkit. |
| paths `src/sdd/__init__.py` (match the file, never `src/` wholesale; "a product may own `src/`"), `.specify/config/refinement.conf`, `plugins/migrate-to-plugins.sh`, `plugins/create-domain-plugin.sh` (`:81-84`) | 4 | The "never match a product directory" rule is Constraint F in miniature. |

Content rows (`:87-88`): the `.logicloom-adopt-receipt.json` row (`:87`) RETIRES (it proposes the recorder). The `amendments.md` row (`:88`) is the kori case and SALVAGES into one non-safety note: the customer's file is fork-owned, LogicLoom never shipped it, so the note has no upstream blob and can only be adapted, never created or taken whole. Its regex (`:88`) becomes the note's `check`. The fixtures `tests/fixtures/release-migrations/kori-amendments-ladder.{before,after}` (32/35 lines) are real before/after text for the adapter brief and the note's "what it looks like after"; they show the actual defect (two `3 =` lines on one scale versus `+3` on top of reversibility 0/1/3, `.after:20-21`). The note cannot cite `~/.claude/CLAUDE.md` (finding 7).

### 3.3 Reusable pieces to carry out of the scanner

- A flat list of the 23 retired names (for CI tolerance, finding 9), read by `validate-plugin-manifests.py`, `test_plugin_lifecycle.sh`, `test_bash32_floor.sh`, `test_deprecation.sh`, `test_model_agnostic.sh`, `test_plugin_manifest_schema.sh`. It needs a home that ships to both channels and that the python validator can read: `.logic-loom/config/` qualifies (payload `include: .logic-loom`; not in the strip manifest). New file there needs no manifest row.
- The 6.x compatibility test idea (`test_update_from_6x.sh`): see 3.4.
- The CLAUDE.md trim (3.5).

### 3.4 Tests and fixtures

| File | Class | Why |
|---|---|---|
| `tests/contract/test_release_migrations.sh` (5,568) | RETIRE | Tests the scanner/registry/gate. |
| `tests/contract/test_update_framework_ownership.sh` (2,826) | RETIRE | Tests the receipt rot gap and recorder. Includes a check that `uninstallProcedure()` covers update runs; that single assertion is duplicated in `test_adopt_applier.sh:562-590`. |
| `tests/contract/test_update_from_6x.sh` (564) | SALVAGE | Keep the harness, change the assertions. Reusable: `archive_v662_tree` (`:202`), `init_fixture_repo` (`:210`), `build_sanitized_upstream_tree` (`:230`, runs the same sanitize/strip/scrub steps as `promote-to-main.yml`), `graft_synthetic_upstream` (`:256`, commit-tree inside the fixture's own `.git`, alternates for read access), the fresh-process `EXTRACT_RUNNER` (`:280-290`, with the bash 3.2 BASH_SOURCE reason in its comment), `resolution_for` (`:304`), the control case (`:407-423`), and the adopted fixture built from the real v6.6.2-era installer (`:482-`, anchored on the `stamp v6.6.2` commit). New assertions: the engine, notes, `/update-loom` stub, adapter/reviewer agents arrive as `clean-add`/`clean-apply` on both fixtures; the forwarding stub for `update-framework.md` is `clean-apply`; and, new, that nothing the customer's own is overwritten. It already pins finding 1 (`:377`). Must stay maintainer-only (it skips on a sanitized tree, `:125-131`). |
| `tests/fixtures/update-from-6x/v7-machinery-paths.txt` (47) | SALVAGE | Rewrite the 8 rows for the new file set; its comments (`:1-37`) hold the reasoning about why unchanged files cannot be listed. |
| `tests/fixtures/release-migrations/adopt-receipt-generator-stamp.{before,after}` | RETIRE | Fixture for the receipt row. |
| `tests/fixtures/release-migrations/kori-amendments-ladder.{before,after}` | SALVAGE | See 3.2. |
| `test_bash32_floor.sh` (+128), `test_deprecation.sh` (+122), `plugins/test_plugin_lifecycle.sh` (+70), `test_model_agnostic.sh` (+28), `test_plugin_manifest_schema.sh` (+247) | KEEP, re-source | Retired-plugin and marked-skill tolerance (finding 9). Change only the source of the legacy-name list and the "run /update-framework" hint strings (`test_plugin_lifecycle.sh:108`, `test_bash32_floor.sh:296`). The tests use `tests/lib/tree-provenance.sh` to skip on sanitized trees, which any new shipped test must also do. |
| `tests/contract/test_adopt_applier.sh` (+29) | KEEP | Pins installer behaviour (`uninstallProcedure()` covers update-shaped runs); depends only on the decision in 3.1 about a recorder. |
| `tests/contract/test_keyword_backend_scoring.sh` (171), `test_shipped_skill_commands.sh` (135) | KEEP | Unrelated fixes (3.6). |
| `tests/run_all_tests.sh` (+5) | Edit | Keep the two unrelated registrations (`:140,174`); drop `:182-184`. |

### 3.5 CLAUDE.md trim and doc moves

`CLAUDE.md` 234 lines changed (+26/-208): the directory tree, the `.brain/` section, the amendments doctrine and two embedded "What changed in v6.x" changelogs moved out or were shortened. Classes:

- KEEP: the moves themselves. `.docs/architecture/loom-architecture.md` (+80, "Directory structure" annex), `.docs/policies/project-amendments-policy.md` (+45), `.brain/README.md` and `.logic-loom/templates/brain-readme-template.md` (+35/+29; the template is the stub the strip manifest ships, `template-strip-manifest.txt:219`), `.docs/policies/file-structure-policy.md` (+9, but its `.claude/skills` sentence mentions `converted-from:`; reword, keep the carve-out for user-authored skills), `.claude/context/skills.md` (+3, same marker mention), `history-scrub-rules.json` (-12, drops two `drop-section` rules whose headings no longer exist in CLAUDE.md). I grepped the added `loom-architecture.md` text: no v7/migration sentences.
- RETIRE inside CLAUDE.md: the v7-specific sentences (HEAD `CLAUDE.md:413-417`, the retired-plugin paragraph under the Plugin Registry, and `:636-645`, the Step 3b / `migration-decisions.conf` / `record-update-writes.sh` / `check-release` paragraph) plus the `**Last Updated**` line.
- Cost note: because `CLAUDE.md` is customised by many clones (case c), the trim itself arrives as `conflict-review` in the old flow (CHANGELOG "Migrating from 6.x", first bullet). That is the same mechanism the new notes are meant to replace; the trim is the first real candidate note ("CLAUDE.md shrank").

### 3.6 Unrelated fixes already committed (commit `84c2395`, before any v7 code)

KEEP AS IS: `plugins/loom-memory/lib/keyword-backend.sh` (+225, query-coverage scoring), `plugins/loom-orchestrator/skills/cross-check/SKILL.md` (+21, Mode B model resolution), `project-graph/SKILL.md` and `commands/graph.md` and `project-graph-convention.md` (package name `@optave/codegraph`), `.docs/architecture/orchestrator-worker-ladder.md` (+33 "Effort follows cost"; note its `:77-80` cites `.brain/raw/research/...`, a path the strip manifest removes, so a shipped doc points at a stripped file), backlog/todos/VISION edits (maintainer-only or stubbed), `.brain/` DISTILL-LOG, bash-sandbox research and wiki page (maintainer-only), `artifacts/backlog-dashboard.html` (+69, generated, tracked, freshness-gated by `check-generated-freshness.sh`; regenerate after any backlog edit), `.logic-loom/graph/graph-bridge.jsonl` (+17, derived; stripped at release; regenerate with `/graph build` after removing docs, since it has `mentions` edges from `MIGRATION_GUIDE.md` at `:157-164`). Commit `84c2395` precedes `6d7c066`, so these can be cherry-picked ahead of the rest if the branch is rebuilt.

### 3.7 Release plumbing and docs touched by v7

| File | Class | Why |
|---|---|---|
| `.github/workflows/plugin-tests.yml` (+22) | Edit | KEEP `fetch-depth: 0` (`:12`, also needed by the 6.x test's tag lookup), the keyword-scoring step (`:61-62`) and the shipped-skill-commands step (`:181-187`); RETIRE the three update steps (`:308-316`); ADD new engine/notes tests. |
| `.github/workflows/promote-to-main.yml` (+5, `:139-145`) | Edit | Replace the three suite names in the promote gate list with the new engine suites; promotion pipeline otherwise unchanged. |
| `.docs/guides/FRAMEWORK_SYNC_GUIDE.md` (+12) | SALVAGE/rewrite | The v7 "Release migrations" block (`:36-47`) retires; the "How updates work" invariants (`:6-33`) and sync-ref troubleshooting stay, rewritten for `/update-loom`. |
| `KNOWN_ISSUES.md` (+47) | SALVAGE | Entries `:8-54` ("Retired plugin never mentioned", "Adopted installs never received updates to files added by `/update-framework`") are described as "FIXED in v7.0.0"; re-word to the new mechanism or drop. The sync-ref entry `:55-112` stays true. |
| `START_HERE.md` (+2, `:158`) | Edit | Remove the registry paragraph; `:156` and `:351` rename. |
| `plugins/CONTRIBUTING.md` (+18, `:110-127`) | SALVAGE | The "Shipping a release" checklist (add registry rows, `### Migrating from` subsection, run the gate) becomes "write notes". |
| `VISION.md` (+12) | KEEP | Backlog decisions; unrelated. |
| `CHANGELOG.md` (+863) | SALVAGE | Stripped at release (`template-strip-manifest.txt:126`); rewrite the `[Unreleased]` entry for 7.0.0 (`:8-100`: the "Migrating from 6.x" bullets are the best existing statement of the old-path behaviour). |
| `.docs/architecture/loom-architecture.md` (+80) / `.docs/policies/project-amendments-policy.md` (+45) | KEEP | See 3.5. |

"Installer changes": there are none in `packaging/` between `2ca2340` and HEAD (`git diff --stat 2ca2340 HEAD -- packaging` is empty). The only installer-adjacent v7 edits are the recorder script's relationship to `packaging/adopt/lib/apply.js`'s `uninstallProcedure()` and the `test_adopt_applier.sh` pin; the installer's own ALREADY-ADOPTED remedy text still says `use /update-framework ...` (`packaging/adopt/lib/preconditions.js:416`, pinned by `test_adopt_planner.sh:266-267`).

---

## 4. Rename and removal blast radius (everything naming `/update-framework`, release-migrations, migration-decisions, record-update-writes, MIGRATION_GUIDE)

Method: `git grep -n` over tracked files at HEAD. Counts per file elsewhere in this section are mine; `SHIPS` = reaches template customers, `ADOPT` = also in the npm payload, `MAINT` = stripped or maintainer-only.

### 4.1 Commands, skills, agents, manifests (must change together)

- `plugins/loom-maintenance/commands/update-framework.md` (7 mentions) SHIPS ADOPT: becomes forwarding stub for older customers; constraint C needs it to exist.
- `plugins/loom-maintenance/skills/framework-updater/SKILL.md` (7): replaced; referenced by `test_update_framework.sh:27,85-87`, `test_deprecation.sh:187`, `.claude/context/skills.md:176`, `plugin.json:24`, `leak-guard.sh:150`, `payload-manifest.txt:435` (a line-number citation `SKILL.md:210`).
- `.claude/commands/update-framework.md` (bridge stub) and `.claude/commands/.bridge-manifest.json:27`: regenerate via `.logic-loom/scripts/bash/sync-plugin-commands.sh sync`; add `update-loom`. `tests/contract/test_plugin_command_bridge.sh` and `test_spec006_integration.sh:232` (command loop includes `update-framework`) check the bridge.
- `plugins/loom-maintenance/.claude-plugin/plugin.json` (`:24` skill, `:38` command): inventory lists are validated against disk (`validate-plugin-manifests.py` addition 4); new command/skill entries are required, and `strip-harness-dev.sh` prunes inventories of stripped files.
- `.claude/agents/framework-sync-agent.md`; `AGENTS.md:212,254,406,505`; `.claude/context/agents.md:82,129`; `.docs/agents/agent-registry.json:39-46`; `.docs/policies/file-structure-policy.md:172`; `.docs/policies/code-review-policy.md:51`; `test_plugin_lifecycle.sh:151` (`LOOM_0052_AGENTS` list) and `test_spec006_integration.sh:42` (asserts the agent file exists). New `update-adapter` / `update-reviewer` agents are additions to every one of these registries (AGENTS.md is "tandem" with CLAUDE.md, CLAUDE.md `:668-670`).
- `plugins/loom-maintenance/README.md:6,10,15`.

### 4.2 Scripts, libs, config

`plugins/loom-maintenance/scripts/extract-proposals.sh` (5 mentions; cited by `shell-idiom-policy.md:160`, `payload`, tests), `release-migrations.sh`, `record-update-writes.sh`, `.logic-loom/lib/release-migrations.sh` (+ its graph-bridge entries), `.logic-loom/config/release-migrations.conf`, `.logic-loom/config/framework-upstream.conf:2-26` (names the command; the file itself stays as the URL source), `.logic-loom/scripts/bash/common.sh:640`, `constitutional-check.sh:700-701`, `validate-plugin-manifests.py:24-32,207-232`, `init-project.sh:363-368`, `plugins/loom-maintenance/commands/initialize-project.md:246` and `skills/project-initialization/SKILL.md:365-367` (these two assume an adopter "adopted LogicLoom via /update-framework" and never ran init, which is the 6.6.2 command's own confusing wording at `v6.6.2:update-framework.md:44-47`; HEAD fixes it with Step 0).
Templates that say "`/update-framework` will not touch it": `.logic-loom/templates/amendments-template.md:10`, `environment-promotion/deploy-seam.sh.tmpl:10`, `check-branch-base.sh.tmpl:25`, `.logic-loom/domain-briefs/README.md:40-43`. Those are promises about fork-owned files; under the notes model a note MAY propose an adapted edit to a fork-owned file with approval, so each sentence must become "never overwrites; may offer a reviewed change".

### 4.3 Tests naming these systems

| Test | Status |
|---|---|
| `test_update_framework.sh` (121) | pre-v7. Asserts the script, skill, command exist and carry `list_tags_in_range`, `find_tag_for_file`, `release_tag` (`:46-115`). Retire or retarget. |
| `test_update_framework_adopted.sh` (502) | pre-v7. Sources `extract-proposals.sh` to test the unshipped adopted filter. Retire with the filter. |
| `test_release_sync_ref.sh` (350, `:57,106,263`) | KEEP. Guards that published `.sdd-sync-ref` stays reachable and the remap table is not widened (`promote-to-main.yml:567`). Still valid as long as the base pointer is `.sdd-sync-ref` and old scripts survive on disk. |
| `test_shipped_gates_vs_strip.sh:560-575` | Asserts `update-framework.md` warns about inherited maintainer CI and that `branch-topology-guard.yml`'s header names the adopter; update if the warning moves into the new skill. |
| `test_suite_registration.sh:47`, `test_adopt_planner.sh:266-267`, `test_adopt_applier.sh:562-590`, `test_spec006_integration.sh:42,232`, `test_plugin_lifecycle.sh:108,151`, `test_deprecation.sh:187`, `test_bash32_floor.sh:296` | Strings or existence checks that need the new names/paths. |
| `test_release_migrations.sh`, `test_update_framework_ownership.sh`, `test_update_from_6x.sh` | Section 3.4. Registered at `run_all_tests.sh:182-184`, `plugin-tests.yml:308-316`, `promote-to-main.yml:143-145`. |

### 4.4 CI and release workflows

`plugin-tests.yml` (`:121` comment on `/update-framework` breakage; `:254` adopted filtering; `:308-316` v7 steps), `promote-to-main.yml` (`:139-145` gate list; `:202-208` stamps `framework-upstream.conf`; `:497-583` sync-ref advance and reachability), `release-tag.yml` (`:28,89,105,131,156-168` sync-ref reachability, "Do NOT add a remap entry"), `branch-topology-guard.yml:55`, `.docs/guides/dev-main-template-split.md:75,101` (MAINT). The `check-release --since auto` removal guard was run inside `test_release_migrations.sh:394` (not a separate workflow step, contrary to `plugins/CONTRIBUTING.md:120-124`); retiring the scanner removes the guard that fails a release which drops a `plugins/<x>` directory without declaring it. A replacement gate ("every removed plugin dir has a retire note") is a new maintainer-side requirement.

### 4.5 Docs

`README.md:7,200,264` (`:7` troubleshooting banner for sync-ref failure), `START_HERE.md:156,158,351`, `AGENTS.md` (above, plus `:629` version-table row for 6.4.1), `CLAUDE.md:240,396,413-417,634,636-645`, `VISION.md:227-232,293-316,336` (history prose naming the extractor), `.docs/guides/FRAMEWORK_SYNC_GUIDE.md`, `MIGRATION_GUIDE.md`, `KNOWN_ISSUES.md`, `plugins/CONTRIBUTING.md`, `.docs/policies/file-structure-policy.md:94,172,180-189`, `.docs/policies/shell-idiom-policy.md:160` (cites an `extract-proposals.sh` line number), `.logic-loom/memory/constitution.md:21,314` and `constitution_update_checklist.md:95,205` (both state `/update-framework` has "no upstream counterpart" to amendments; constitution.md is a PROTECTED path, so editing it is a main-agent ASK), `.logic-loom/memory/todos.md:257,312,379`, `backlog.md:478` (MAINT), `.brain/memory/*` (MAINT).
Single most customer-visible sentence set: CLAUDE.md `:634` (command list) and `:636-645`.

### 4.5b Installer

`packaging/adopt/lib/preconditions.js:416` (ALREADY-ADOPTED remedy text), `packaging/adopt/lib/detect.js:625` (label `update-framework baseline`), `payload-manifest.txt:197,347,435`. Old npm versions keep printing the old command name forever, which is why `/update-framework` must keep resolving.

---

## 5. Governance facts the port must respect

### 5.1 Hook set (all wired from `.claude/settings.json`, HEAD `CLAUDE.md` "LogicLoom Hooks")

`subagent-git-guard.sh`, `git-safety-gate.sh`, `protect-governance-files.sh` (both Write/Edit and Bash matchers), `guard-dangerous-commands.sh`, `freeze-write-scope.sh` (only during `/swarm implement`; irrelevant to updates), `governance-preflight.sh` (UserPromptSubmit).

### 5.2 `gate-policy.conf` verdicts for the git operations an updater needs

Verdicts come from `_loom_seg_git_op` (`governance-verdicts.sh:1252-1305`) and `gate-policy.conf` (shipped `balanced`). Main agent, command typed visibly in a Bash call:

| Operation | Op id | Verdict | Cite |
|---|---|---|---|
| `git fetch <url> +refs/heads/main:refs/loom-upstream/main` | `git.fetch` | silent | `gate-policy.conf:208`; the fetch writes a ref but is not `update-ref` |
| `git commit`, `git add` | `git.commit`, `git.add` | silent | `:167,170` |
| `git tag <name>` / `git tag -d <name>` (pre-update tag; both create and delete are `tag.write`) | `git.tag.write` | silent | `:178`; `_loom_git_tag_mutates` `:153-173` |
| `git worktree add` / `remove` / `prune` | `git.worktree.write` | ask | `:156`; verbs `governance-verdicts.sh:65` |
| `git worktree list` | read | allow (subagents too) | `governance-verdicts.sh:482` |
| `git merge --ff-only <branch>` | `git.merge` (classified by subcommand; no `--ff-only` carve-out) | ask | `:103` |
| `git branch -D`, `git checkout -b`, `git switch -c` | `git.branch.write` | ask | `:151` |
| `git reset --soft/--mixed` | `git.reset` | ask | `:133` |
| `git reset --hard` | `git.reset.hard` | ask; plus `git reset --hard origin/main` is a BLOCK pattern in `tool-restrictions.json` dangerous_commands | `:120` |
| `git revert <sha>` | `git.revert` | silent | `:196`. This is the cheapest governed "undo" |
| `git restore`, `git checkout -- <path>` | `git.restore` | ask | `:129` |
| `git rm`, `git mv` | `git.rm`, `git.mv` | ask | `:142,146` |
| `git update-ref` (including `-d refs/loom-upstream/main`) | `git.history-rewrite` | ask, FLOOR (cannot be silenced) | `:95` |
| `git push`, `git remote add/remove/set-url`, `gh pr ...` | push FLOOR ask; remote ask; gh ask | n/a for an updater but `git remote add upstream` (Launchhouse `:76-79`) would be an ask |
| `git stash` | `git.stash` | silent | `:175` |

Hard rule: a subagent (non-empty `agent_id`) may run only the read-only allowlist (`LOOM_GIT_SUBAGENT_READ_SUBCOMMANDS`, `governance-verdicts.sh:274`: status, log, diff, show, rev-parse, rev-list, ls-files, ls-tree, cat-file, merge-base, describe, grep, ...) with no `-c`, `--git-dir`, `--work-tree`, `--exec-path`, no `$(...)`/backticks/process substitution (`governance-verdicts.sh:506-519`); `fetch`, `worktree add`, `tag`, `commit`, everything else is denied "in every posture and every mode" (`:954-957`, `gate-policy.conf:52-58`). I hit this live: command substitution in an otherwise read-only loop was denied.

### 5.3 Visibility: what the gate does not see

`git-safety-gate.sh:10-14` and `governance-verdicts.sh:47-49`: `bash script.sh`, `eval`, variable indirection are invisible. Therefore:

- The Launchhouse engine's internal git (fetch `:285`, `tag :1743`, `worktree add -b :1749`, `commit :2192`, `merge --ff-only :2246`, `worktree remove :2226,2247`, `branch -D :2227,2248`, `tag -d :2228`, `checkout -- .claude/ :2389`, `rm -f` in the worktree `:1791,1819`, revert-based undo `:2433-2497`) would not be adjudicated by `gate-policy.conf` at all if run through one `bash update.sh --apply`. The only governance on that call is that the main agent obtained the user's yes first (Principle VI as followed, not as enforced; CLAUDE.md states hooks are "a deterministic floor, not a sandbox").
- A subagent that runs `bash update.sh` would likewise escape `subagent-git-guard.sh` (it matches command text). The prohibition on subagent git is therefore only as strong as the engine's own refusal; the engine should refuse to run mutating subcommands when invoked from a subagent, but a script cannot know (the hook payload's `agent_id` is not passed to child processes; UNVERIFIED whether any env marker exists).
- Who may run what, per the constitution and hooks: only the main agent runs mutating git, with direct-user approval where policy says ask (`CLAUDE.md` Governance table, Principle VI). The three structurally different ways to map the Launchhouse flow onto this are: (A) engine does file work only and prints a git plan; the main agent issues each git command visibly, so every verdict in 5.2 applies (worktree add and ff-merge each prompt, commit and tag do not); (B) engine does all git internally behind one approval; (C) split subcommands (`--prepare`, `--commit`, `--finish`) so each mutation is a separate visible call. The decision is not made here.
- Launchhouse keeps its working state in `$(git rev-parse --absolute-git-dir)/launchhouse/update/` (`update.sh:1-12`). In LogicLoom a visible `rm -rf` of anything containing `.git` matches `tool-restrictions.json` file_operations `rm.*-rf.*\.git` (action `warn`), and `rm ... /` style patterns BLOCK (dangerous_commands); an engine that cleans its own state inside a script is not subject to either.

### 5.4 Protected paths an update can touch (`_loom_path_in_builtin_floor`, `governance-verdicts.sh:815-824`; list at `:891-912`)

Subagent write: DENY. Main-agent write: ASK (`:915-921`). Built-in floor:
`.claude/hooks/*`, `.claude/settings.json`, `.claude/settings.local.json`, `.logic-loom/config/governance.conf`, `.logic-loom/config/gate-policy.conf`, `.logic-loom/memory/constitution.md`, `.logic-loom/lib/governance-verdicts.sh`, `.logic-loom/lib/policy.sh`, `plugins/loom-governance/hooks/*`, `plugins/loom-governance/.claude-plugin/plugin.json`. Config additions: this repo's `governance.conf` adds `.logic-loom/config/memory-backend.conf` and `.logic-loom/config/brain.conf`; a fork can add more (`protected_paths =`, additive only). The Bash branch substring-matches command text for these tokens (`protect-governance-files.sh`), which I observed deny a read-only-looking subagent command that merely mentioned a `.conf` path under `.logic-loom/config/`.

Not protected, and therefore subagent-writable: all of `plugins/loom-maintenance/**` (the updater itself, the notes, the notes' executable checks), `.claude/agents/*`, `.claude/policies/tool-restrictions.json`, `.logic-loom/lib/logging.sh`, `.logic-loom/lib/release-migrations.sh`, `.claude/commands/*`. Implications, as facts: (1) a read-only adapter with `tools: Read, Grep, Glob` (agent frontmatter `tools:` is honoured; `fast-worker.md`, `framework-sync-agent.md` show the pattern) is the only enforcement that a worker cannot write, and constraint H already requires project agents; (2) notes' `check` scripts execute during an update, so reading notes from the fetched upstream ref (`git show refs/loom-upstream/main:<path>`) rather than from the working tree prevents a locally edited or subagent-edited note from changing what the update runs; (3) if the engine or notes should be tamper-protected, the only additive mechanism is `protected_paths` in `governance.conf`, which is itself a protected, customer-customisable file (case c applies to it too).

Which update-touched paths are protected in practice: governance hooks wiring (`.claude/settings.json`), hook scripts, `gate-policy.conf`, `governance.conf`, `constitution.md`, `governance-verdicts.sh`, `policy.sh`, `loom-governance` hooks. Any note touching these needs a main-agent write with a user prompt, never an adapter-agent write. The adapter returns text; the skill (main agent) writes it, which already matches Launchhouse design.

### 5.5 Bash 3.2 floor (constraint B)

- Scope (`test_bash32_floor.sh:1-90,177-195`): `*.sh` under `.logic-loom/`, `.claude/hooks/`, `tests/`, `packaging/adopt/` and every plugin declared in CLAUDE.md's Plugin Registry table (`loom-maintenance` is declared, CLAUDE.md `:384-396`). A `loom-*`/`sdd-*` plugin dir not in that table fails section 1b. A customer plugin is deliberately not scanned.
- Pattern: grep for `declare/local/typeset -A`, `[[ -v`, `mapfile|readarray`, `${v,,}`/`${v^^}` in non-comment lines (`test_bash32_floor.sh:150-165`). A POSIX `sh` script passes trivially; the pattern is shebang-blind. Sections 4-5 execute under real bash 3.2 on macOS only. Launchhouse `update.sh` is `#!/bin/sh` (`:1`) and uses `set -u`, `awk`, no arrays (my read of the head; not audited in full).
- The floor is a style gate for harness-owned shell; there is no rule "harness shell must be bash". Placing the engine at `plugins/loom-maintenance/scripts/` or under `.logic-loom/` puts it in scan scope automatically; `.claude/scripts/` would not be scanned.
- Notes' `*.check.sh` scripts are shell that ships: located under the plugin or `.logic-loom` they are scanned and must be 3.2-safe; they also run in adopted installs, where `tests/` does not exist (any `bash tests/run_all_tests.sh` call must be guarded, `payload-manifest.txt:428-440`).

### 5.6 Other governance interplay

- `constitutional-check.sh` (runs in both channels) warns on unmarked `.claude/skills/*` (`:698-730`); new skills belong in `plugins/loom-maintenance/skills/` (Principle XVI), agents in `.claude/agents/` (plugin agents are never loaded, `constitutional-check.sh` UNREACHABLE_AGENTS warning at `:695-697`).
- `.logic-loom/config/gate-policy.conf` is customer-owned in practice (`/initialize-project` rewrites its operation lines, `gate-policy.conf:79-80`); the update must not reset a customer's chosen posture, and a note that changes a verdict would need to be marked safety-class.
- Constitution Principle X: delegate for isolation; the read-only adapter and a separate reviewer agent are compatible.
- Worktree facts for LogicLoom (for the Launchhouse worktree step): `.claude/worktrees/` already exists as Claude Code's own area; the SessionStart hooks `worktree-port-namespace.sh` and `check-dev-branch-base.sh` fire on session start, not on `git worktree add`; a tracked-tree checkout of a product repo like kori-beta (731 files) is cheap, but a worktree has no `node_modules`, `.env` or other ignored files, so engine checks must be harness-only (the old Step 9 `constitutional-check.sh` already is).

---

## 6. Channel facts the engine design needs (constraint D) and sanitization rows (E)

### 6.1 "Which notes apply" in each channel

- Both channels hold `.sdd-sync-ref` (template: committed at release; adopted: `include: .sdd-sync-ref`, `payload-manifest.txt:197-198`). The base commit's tree is available locally after the ad-hoc fetch, because the fetch brings full history of public `main` (`--no-tags`, no `--depth`), provided the stamp is an ancestor of public main (section 1.3). The template channel may or may not share history with upstream (`git clone` of main does; GitHub "Use this template" does not); the fetch makes upstream objects local either way, so presence-by-tree (`git ls-tree -r <sync-ref>` vs `git ls-tree -r refs/loom-upstream/main`) works identically in both; no receipt is needed for "which notes apply".
- Difference between channels is not note applicability but whether a note's `touches` path exists in the customer's tree at all. Adopted installs lack `tests/`, `.github/`, root `README.md`/`package.json`/`CLAUDE.md`/`START_HERE.md`/`KNOWN_ISSUES.md`/`.mcp.json`/`.editorconfig`, `.docs/design|reports|archive|plans|memory|governance`, `.logic-loom/{tests,graph,plans,logs}` (`payload-manifest.txt` excludes), and hold three files the template does not have (`.claude/rules/logicloom-{governance,workflow,file-rules}.md`, authored) plus merge-channel `settings.json`/`.gitignore`. The only record of what an adopted install owns is the receipt (and the exclude list in the unshipped `packaging/` manifest). A note therefore has to declare per-channel `touches`, or the engine must refuse to create paths under the adopt-excluded set; the second option needs the exclude list shipped as data (it is not today).
- Adopted `settings.json` is a merge: the adopter's file with a marked hooks block (`.claude/.logicloom-adopt-settings.json` records insertions). Case c in an adopted repo is the normal case.
- Adopted `AGENTS.md` lives at `.logic-loom/AGENTS.md` (rename row). Notes for that file need the re-addressing the HEAD extractor did (`:513-517`).

### 6.2 Strip and payload manifest rows that change

`template-strip-manifest.txt` (maintainer-only, drives `strip-harness-dev.sh` and `leak-guard.sh`):
- No row is needed to ship notes, engine, adapter/reviewer agents or the retired-names list (not stripped by default; payload `include: .logic-loom|plugins|.claude/agents|.claude/commands` covers them).
- ADD bare rows for any maintainer-only authoring aid (note lint, a "every shipped change is covered by a note" release gate, the release-side retire-note gate) so it never ships; Launchhouse's `docs/upstream-exclude.txt` plays this role there.
- `leak-guard.sh` `HIST_EXCLUDES` (`:149-153`): add the notes directory (and engine path if it carries release examples) as a KEEP zone, mirroring `framework-updater/*` and `extract-proposals.sh`; mirror in `history-scrub-rules.json` `leakGuardHistoryMarkers` if the scrubber is also run over notes. Remove the `framework-updater` and `extract-proposals.sh` exclusions when those files go.
- Update the comment block at `:309-310` (what ships) for the new set.
- Keep `CHANGELOG.md` stripped (`:126`); notes are its customer-facing replacement.
- Notes must avoid `ID_MARKERS` (`brian@kelleysd.com`, `kelleysd.com/`, `ioun-ai`, `/workspaces/`) and should not name private customer repos (kori-beta) in shipped text.

`packaging/adopt/payload-manifest.txt` (maintainer-only, consumed by the installer and `test_adopt_payload_manifest.sh`): no new `include:` rows if everything lives under `plugins/` or `.logic-loom/`; if anything lives directly under `.claude/` (`.claude/updates`, `.claude/scripts`, `.claude/skills`) it needs a new `include:` row, and the receipt will not record `.claude/` itself (finding 8). Comments `:197`, `:347`, `:435` name the old command and a skill line number.

### 6.3 Product vs harness (constraint F), as it exists today

The harness already declares the boundary (`CLAUDE.md` "Harness <-> product boundary"): product code in `web/` or `apps/<name>/`; `features/`, `specs/` and `.brain/` are customer workspaces (`features/*/` and `specs/*/` are `exclude:` in the adopt payload; `.brain/` ships README-only). The old extractor has no path denylist for the template channel; HEAD's deny-list (`:431-440`) is adopted-only and suppresses `tests/` and `.github/` but not `features/`, `specs/`, `.brain/`, `web/`, `apps/`. A note-level `touches` validator (reject `features/`, `specs/`, `.brain/`, `web/`, `apps/`, and anything outside the repo through a symlink) is new work; Launchhouse's equivalent for `growth-engine/` is `path_ignored` plus `.launchhouse-update-ignore` (`update.sh:361-375` per its design doc).

---

## 7. What I could not verify

- Whether any customer is actually on a broken-stamp release, or how many are adopted versus template; npm package version history (the 6.6.0 to 6.6.2 claim comes from `test_update_from_6x.sh:64-66`).
- That the 6.6.2 extractor's behaviour matches my reading under bash 3.2 and under the model's real use; I did not run it.
- Whether Claude Code picks up a new `.claude/commands/*.md` mid-session.
- Whether a child process can detect that it was launched from a subagent (no env marker found in the hook scripts).
- Executable-bit impact of redirect-written new files on shipped scripts invoked directly.
- That `git worktree add` into `.claude/worktrees/` or a temp dir is acceptable to every customer repo (submodules, sparse checkout, LFS, huge repos) — not examined.
- Launchhouse's engine beyond the head of `update.sh`, the design-doc sections 2, 4 and 8, and the git calls listed in 5.3; Reader A covers it.

Files read (absolute): `/Users/bkelley/kelleysd-apps/LogicLoom/plugins/loom-maintenance/{commands/update-framework.md,skills/framework-updater/SKILL.md,scripts/extract-proposals.sh}` (HEAD and `v6.6.2`), `.../scripts/{release-migrations,record-update-writes}.sh` (headers), `.logic-loom/{config/{release-migrations,gate-policy,governance,framework-upstream}.conf,lib/{governance-verdicts,release-migrations}.sh,scripts/bash/{template-strip-manifest.txt,leak-guard.sh,constitutional-check.sh},scripts/python/validate-plugin-manifests.py}`, `plugins/loom-governance/hooks/scripts/*.sh`, `.claude/{settings.json,policies/tool-restrictions.json,agents/*,commands/update-framework.md}`, `packaging/adopt/payload-manifest.txt`, `tests/contract/{test_update_from_6x,test_bash32_floor}.sh` and grep of the others, `.docs/guides/{MIGRATION_GUIDE,FRAMEWORK_SYNC_GUIDE}.md`, `KNOWN_ISSUES.md`, `CHANGELOG.md` head, `/Users/bkelley/kelleysd-apps/kori-beta/{.logicloom-adopt-receipt.json,.sdd-sync-ref,.logic-loom/memory/amendments.md}` and `/Users/bkelley/kelleysd-apps/launchhouse-founder-template/{docs/purpose-based-updates.md §1,2,4,8,9; .claude/scripts/update.sh (git calls)}`.
