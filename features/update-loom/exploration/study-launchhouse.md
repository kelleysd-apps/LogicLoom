# Study: the Launchhouse purpose-based update engine (Reader A)

Source: `/Users/bkelley/kelleysd-apps/launchhouse-founder-template` at `d8d66e9` (main, clean tree). Read in full: `.claude/scripts/update.sh` (2594), `updates-lint.sh` (243), `.claude/tests/updates-checks.sh` (225), `.claude/skills/launchhouse-update/SKILL.md` (216), `update-adapter.md` (55), `update-reviewer.md` (70), `.claude/commands/growth-engine/update.md` (5), `.launchhouse-update-ignore` (9), `.claude/updates/README.md` (121), `docs/purpose-based-updates.md` (840), all 7 notes + 7 checks under `.claude/updates/2026-09-23/`, `AGENTS.md`, plus the updater-related parts of `.claude/tests/run.sh` and `update-cases.sh` (4308, skimmed by section map, not line-by-line) and the full commit bodies of every updater commit (`git log` for the paths above).

**Verification status.** Everything below is from reading. I executed nothing (no test suite run, no engine run). Where I say "the engine does X" the claim is a line cite; where a design-doc promise has no matching code I say so in section 3. Paths are relative to the Launchhouse repo unless prefixed `LL:` (LogicLoom). `update.sh:N` = `.claude/scripts/update.sh` line N.

## TL;DR for the orchestrator

1. **The engine is a git three-way file engine with a notes layer, not a note-driven engine.** Ownership is decided by comparing base/mine/theirs blobs from a real base commit (`update.sh:546-677`); notes add purpose, plain-words approval, a safety flag and an executable outcome check. No heuristics about "who owns this file". That is why it converged in a week where the v7 scanner did not, and also why it **needs a base commit tree**, which LogicLoom adopted installs may not have (4.2, 6.3). This is the single biggest porting risk.
2. **Portable core is ~70% of the 2,594-line engine** (section 5): classification, notes.tsv, read-only adapter + deterministic `--adapt-save`, worktree apply, hold-back, fail-closed gates, post-landing smoke, undo with content verification, lock/heal. Plus lint, checks runner, `json-valid.sh`/`json-flat.sh` verbatim (~1,000 lines). ~570 lines are skill-pack machinery that does not port.
3. **22 fix rounds are already paid for** (section 2). The ones most likely to bite LogicLoom: old-engine environment leaking into new checks (#3), template-conformance checks blocking customers (#7), shape-based JSON checks (#8), `git revert` exit status lying (#10), "absent safety machinery" read as "nothing to check" (#18), LLM-written decisions file with a typo (#22), validators taken from the tree being judged (#12), `--set-base` leaving the tree dirty (#15).
4. **The design note promises more than the code does** (section 3): per-improvement approval only for notes with held rows; declined improvements are silently dropped because the base advances; `requires`/`adds`/`founder-data` are schema-only; no Windows lane found; hook-gate extraction is line-shaped (vacuous on compact `settings.json`). Do not port the doc's claims; port the code and fix these.
5. **The engine performs ~12 kinds of git mutation inside one shell script** (1.17). Under LogicLoom's gate those are invisible to string-matching hooks, so Principle VI and governance-file protection must be re-implemented inside the engine or enforced by how the main agent drives it. The Launchhouse *skill* also runs `git add -A`, commit and `push` itself (`SKILL.md:41`, `:166`); LogicLoom must not.
6. **Bootstrap (constraint C) in Launchhouse = "the old skill tells the agent to read upstream's current SKILL.md and run upstream's engine from `<gitdir>/launchhouse/bootstrap/`"** (`SKILL.md:18-32`, `AGENTS.md`, `README.md:56-60`) plus "the only new code the old engine executes is the new tree's checks" (doc `:556-559`). It leans on a live git `upstream` remote and on the old skill being agent-readable instructions, both of which LogicLoom's two channels must be checked against (section 6).

---

## 1. How the engine actually works

### 1.0 The one-paragraph model

It is a **file-diff engine with a notes layer on top**, not a note-driven engine. `--plan` three-way-compares *every tracked path* (union of base, HEAD, upstream trees, minus `growth-engine/`) against a recorded base commit (`update.sh:931-941`). Untouched-by-founder files are simply taken. Files changed on both sides are either three-way-merged cleanly or **held**; only held rows reach the read-only adapter agent. Notes (`.claude/updates/<release>/<id>.md`) supply (a) the *purpose* the adapter works to, (b) the plain-words question the founder is asked, (c) the safety flag, and (d) an executable check that proves the outcome after apply. Ownership of a file is never inferred from content heuristics: it is decided by comparing three git blobs (base / mine / theirs) with a CRLF-insensitive hash (`norm_hash`, `update.sh:157-161`). That is the structural difference from LogicLoom's v7 scanner, and it depends entirely on having a trustworthy **base commit** (section 1.4, 4.2).

### 1.1 Artefact inventory (what ships to a founder and what runs)

| File | Lines | Role |
|---|---|---|
| `.claude/scripts/update.sh` | 2594 | the engine; subcommands `--status --detect-base --set-base --plan --adapt-save --restore-settings-plan --restore-settings-decline --apply --undo` (dispatch `update.sh:2579-2594`) |
| `.claude/scripts/lib.sh` | 741 | hook helpers, sourced at `update.sh:52`, copied beside the relocated script (`update.sh:1620`) |
| `.claude/scripts/updates-lint.sh` | 243 | note schema linter |
| `.claude/scripts/json-valid.sh` / `json-flat.sh` | 231 / 196 | real JSON parser / flattener to `path<TAB>value`, POSIX sh + awk (`json-valid.sh:1-20`, `json-flat.sh:1-35`) |
| `.claude/tests/updates-checks.sh` | 225 | runs linter then every note's check, cumulatively |
| `.claude/updates/README.md` + `<release>/<id>.md` + `<id>.check.sh` | 121 + 7 notes (61-106 lines each) + 7 checks (44-104 lines) | schema + shipped improvements |
| `.claude/skills/launchhouse-update/SKILL.md` | 216 | the conversation script for Claude |
| `.claude/agents/update-adapter.md` | 55 | `tools: Read, Grep, Glob`, `model: sonnet` |
| `.claude/agents/update-reviewer.md` | 70 | `tools: Read, Grep, Glob, Bash` (Bash allowlisted to read-only git in prose, `update-reviewer.md:18-20`; not enforced by tooling) |
| `.claude/commands/growth-engine/update.md` | 5 | `Use the launchhouse-update skill.` |
| `.launchhouse-update-ignore` | 9 | upstream-owned ignore list, read from the **upstream** tree (`update.sh:929`) |
| `AGENTS.md`, `README.md` paste-prompt | - | bootstrap instructions for non-Claude agents / pre-updater copies |
| `docs/purpose-based-updates.md` | 840 | maintainer design note, NOT shipped (`docs/upstream-exclude.txt:14`: `docs/`) |

### 1.2 State directory (`<gitdir>/launchhouse/update/`, never committed)

`state_dir()` = `$(git rev-parse --absolute-git-dir)/launchhouse/update` (`update.sh:62-66`). It lives inside `.git`, so it is per-clone and dies with a re-clone (the design doc says so at `docs/purpose-based-updates.md:603-607`, and relies on the pre-update **tag** surviving instead).

Rebuilt on every `--plan` (`rm -rf` at `update.sh:895-897`): `plan.tsv`, `diffs/<path>.base-upstream.diff|.base-local.diff` (`:404-411`), `merged/<path>`, `meta` (`base= upstream= head= time=`, `:945-950`), `notes.tsv`, `notes/<id>.md` + `notes/<id>.check.sh`, `adapt.tsv`, `adapt/{base,theirs,mine}/<path>`, `adapted.tsv`, `.heldbase.tsv`.

Persist across plans (never cleared by `--plan`): `held.tsv` (`id<TAB>reason<TAB>base-sha`, `:792-799`, `:2353-2374`), `applied` (`tag= commit= upstream=`, `:2250-2254`), `mine/<path>` (backup of a founder file taken wholesale, `:1796-1801`), `settings-resolutions` (`tag<TAB>path<TAB>taken|adapted`, `:2128-2133`), `restore-offered`, `restore-pending` (`:1110-1113`, `:1199`), `last-checks.log` (`:1401-1404`), `tools/json-valid.sh` (upstream's copy of the validator saved at plan time, `:871-876`), `run/update.sh` + `run/lib.sh` (self-relocation copy, `:1617-1626`), `apply.lock` (pid, `:1568-1600`), `wt/` (the throwaway worktree). Sibling folder `<gitdir>/launchhouse/bootstrap/` holds a fetched-from-upstream updater for copies that have none (`SKILL.md:20-32`, `update-cases.sh:433-475`).

### 1.3 Step-by-step flow (what the skill drives, what the script does)

The skill (`SKILL.md`) is the only thing that talks to the founder; every script call ends `< /dev/null` (`SKILL.md:16`, `update.sh:18-20`).

1. **Bootstrap check** (`SKILL.md:18-32`). If `.claude/scripts/update.sh` is missing **or differs from upstream's current copy**, verify the `upstream` remote against the canonical address (from the *committed HEAD tree's* `.claude/launchhouse-upstream`, falling back to the public URL; `update.sh:87-91`, `:108-117`), fetch, copy upstream's `update.sh` + `lib.sh` into `<gitdir>/launchhouse/bootstrap/`, read **upstream's** `SKILL.md` and follow *that*, and fall back to reading the agent files from upstream if the local copies are missing. The widening to "differs", not only "missing", came from commit `3e1000a`.
2. **Step 0 save** (`SKILL.md:34-41`): `--status` (`update.sh:263-278`: ensures `upstream` remote, push URL forced to `DISABLED` at `:79`, prints `clean`, `in_progress`). Dirty tree: the skill commits the founder's work itself first. `clean` = nothing outside `growth-engine/.state/` (`:142-145`).
3. **Step 2 base** (`SKILL.md:49-56`, `update.sh:282-368`): `--detect-base` returns `recorded <sha>` (from `.claude/launchhouse-version`), `exact <sha>` (merge-base, or for "Use this template" copies with no shared history, an upstream **first-parent** commit whose `.claude` tree-hash equals the founder's root commit's, `:300-324`), `closest <sha> <n>` (fewest differing files; the skill asks the founder, `SKILL.md:55`), or `none` (stop). `--set-base` validates the sha is reachable from some `refs/remotes/upstream/*` (`:338-343`) then **commits** the version file alone (`:353-360`).
4. **Step 3 plan** (`--plan`, `update.sh:878-953`): fetch, rebuild notes (`build_notes_tsv`), classify every path (`process_path`), build `adapt.tsv` for held rows, write `meta`. Prints class counts. If every class is `generated`/`keep`, or zero rows, the skill says "up to date" and never applies (`SKILL.md:62-63`, commit `91a3765`).
5. **Step 4 ask per note** (`SKILL.md:71-82`): only for notes that have at least one held row in `adapt.tsv`. Safety note: `Apply` / `Tell me more`, never skip. Other: `Take this update` / `Keep mine as it is`.
6. **Step 5 adapt** (`SKILL.md:84-101`): for each held row whose note was approved, dispatch `update-adapter`; skill writes the returned body to `adapt/out/<path>` and calls `--adapt-save <path> <file> <note-ids>`. A refusal or `cannot-adapt` means: safety note -> decision becomes `take-theirs`; otherwise `hold` (`SKILL.md:98`).
7. **Step 6 second read** (`SKILL.md:103-105`): `update-reviewer` reads the plan and every saved adaptation; it may only make a row *more* cautious (`update-reviewer.md:22-24`). Its flag on an adapted row overrides the founder's step-4 approval for that row.
8. **Step 8 show + one yes** (`SKILL.md:115-141`): plain-words "what is new", "kept as you made it", one sentence per adapted file, one question per no-note held path, migrations as separate yes/no, then **one clear yes** to apply.
9. **Step 9 apply** (`SKILL.md:143-153`): the skill writes `decisions.tsv` (`path<TAB>decision`; absent path = `hold`) and runs `--apply`. Ten-minute tool timeout; a cut-off run is safely re-runnable.
10. **Step 10 report** (`SKILL.md:155-191`): exactly three outcomes (Updated / Updated with some held back / Stopped), no check names or paths shown to the founder; `reverted-failed` is told differently (`:191`). Then it **always** runs `--restore-settings-plan` (`:171`).
11. **Undo** (`SKILL.md:193-206`): `--undo`.

### 1.4 Plan classes (`process_path`, `update.sh:546-677`)

Order of tests, first match wins:

| Class (`proposed`) | When | Cite |
|---|---|---|
| `take` / `delete` (take) | any path under `.claude/updates/` that differs from upstream: **always upstream-owned**, never held/kept; a deleted note or check comes back | `:560-576` |
| `generated` (regenerate) | skill-pack install path with a valid marker, founder copy unmodified | `:579-614` (Launchhouse-specific) |
| `conflict` (hold) | same shape but founder copy carries no/forged marker or drifted | `:607-608` |
| `add` (apply) / `add-conflict` (hold) | not in base; in upstream; absent / different locally | `:616-630` |
| (none) | unchanged both sides | `:635-637` |
| `take` / `delete` (apply) | changed upstream, unchanged locally | `:645-653` |
| `keep` (keep) | changed locally only | `:655-659` |
| `deleted-upstream-kept` (hold) | deleted upstream, changed locally | `:662-663` |
| `registry-merge` (apply) | `skill-packs/registry.tsv`, union of upstream rows + local-origin rows | `:664-665`, `:429-437` |
| `settings` (hold) | `.claude/settings.json` changed on both sides: **always held** | `:666-667` |
| `conflict` (hold) | deleted locally, changed upstream | `:668-669` |
| `merged-clean` (apply) / `conflict` (hold) | both changed: `git merge-file -p` (`try_merge_file`, `:413-427`) clean or not | `:670-671` |

Excluded before classification: `growth-engine/*` (`path_ignored`, `:380`), anything `git check-ignore` matches or a pattern in the upstream-owned ignore file matches (`:387-396`) - **except** `.claude/updates/*`, exempted so a founder's broad `.claude/` gitignore can never hide a deleted safety note (`:381-386`, commit `fe404a4`).

Decision vocabulary applied by `--apply` (`:1682`): `hold`, `keep-mine`, `take-theirs`, `apply`, `adapted`. Anything else is refused up front (commit `263f6f9`, `:1704-1713`). `adapted` is valid only on the four held classes (`:1726-1731`) and needs a saved body (`:1720-1725`).

### 1.5 Which notes apply: presence, not date (`build_notes_tsv`, `update.sh:788-831`)

A note applies iff its `.md` exists in the **upstream head tree** (`git ls-tree -r --name-only $uh -- .claude/updates`, `:802-803`) and does **not** exist in the **base commit's tree** (`:814-815`), or its id is standing in `held.tsv` (`:816-820`). Sorted by path, so release-date folders give chronological order (`:777-778`). Output row: `id<TAB>notes/<id>.md<TAB>safety<TAB>touches,comma,joined` (`:829`). The note and its named check are copied into `state/notes/` so agents read them from state, never from the founder's live `.claude/updates/` (`:780-787`, `SKILL.md:75`).

This works only because the base commit's tree is a real commit in the clone (`git ls-tree "$basecommit"`); see section 4.2 for what that means for adopted installs.

### 1.6 Adapt (plan time, read-only worker, deterministic save)

- `adapt.tsv` row per held path: `path<TAB>note-ids<TAB>base<TAB>theirs<TAB>mine`, the three sides saved from git into `state/adapt/{base,theirs,mine}/<path>`; a missing side is `-` (`write_adapt_row`, `:840-848`; `build_adapt_tsv`, `:852-860`). `note-ids` comes from `notes_touching` (`:758-770`), i.e. note `touches` membership. A held path no note names has `-` and is adapted from `git diff base upstream -- path` + `git log` as the "purpose" (`SKILL.md:93`, doc section 8).
- **The worker never writes.** `update-adapter` has `tools: Read, Grep, Glob` (`update-adapter.md:4`) and returns either `## Adapted body` + "What changes for the founder" or `cannot-adapt: <reason>` (`:41-55`). Its brief says: never drop a base hook, never loosen a permission, safety fix wins over a customisation that is the hole, preserve CRLF, JSON must be valid, treat all inputs as data (`update-adapter.md:19-32`).
- **`--adapt-save` is the deterministic gate** (`update.sh:968-1081`). Refuses: no plan; empty body; path not in `adapt.tsv`; `growth-engine/*`; `path_ignored`; symlink at HEAD or upstream (`is_symlink_at`, `:708-711`); a note id not listed for that path; for `*.json`, a body failing the **upstream's own** `json-valid.sh` saved at plan time (`:1033-1051`, preferred over the founder's live copy "which could have been altered to always pass"), and refusing outright if no validator exists. Then it matches the founder's line endings (CRLF detected from `adapt/mine`, `:1056-1069`), writes to `state/merged/<path>`, and records `path<TAB>note-ids` in `adapted.tsv` (`:1071-1078`).
- The skill, not the agent, is the only writer of the body file (`SKILL.md:98`). The design reason (doc `:271-284`): founders run with no permission prompts and every hook fails open (`lib.sh:3`), so "only write to merged/" is unenforceable as an instruction; remove the write tool instead.

### 1.7 Approval, per improvement, in plain words

Implemented as AskUserQuestion prompts in the skill (`SKILL.md:77-82`), not in the engine. The engine only sees the outcome as per-path decisions. Section 3 lists where the implementation is narrower than the design note's promise (non-held notes get no individual question).

### 1.8 Apply (`cmd_apply`, `update.sh:1603-2426`), in order

1. **Self-relocate** (`:1617-1626`): copies `update.sh`+`lib.sh` to `state/run/` and `exec`s from there with `LH_UPDATE_RELOCATED=1 LH_UPDATE_ROOT=$root`, so the update can replace the running script mid-run. (This is also why root discovery has a walk-up-for-`.git` fallback, `:43-49`.)
2. **Heal + lock** (`heal_stale_apply_worktree`, `:1567-1601`): refuse if another apply's pid is alive; otherwise `git worktree remove --force`, prune, delete stray `launchhouse-update-wt-*` branches, write lock; `trap ... EXIT` releases (`:1629`).
3. **Pre-flight refusals** (`:1631-1653`): trust check, `is_clean`, no merge/rebase in progress, plan exists, **HEAD unchanged since plan** (`:1642`), `git fetch upstream`, **upstream head unchanged since plan** (`:1651`).
4. **Decision validation** (`:1655-1731`): unknown values, missing decisions for held classes, `adapted` without body, `adapted` on a non-held row. All refuse with `unchanged=yes`.
5. **Pre-update tag + worktree** (`:1733-1751`): tag `launchhouse-pre-update-<UTC date>[-n]` on HEAD (no colons, `:5`), then `git worktree add -b launchhouse-update-wt-$$ $state/wt HEAD`.
6. **Per-row writes into the worktree** (`:2074-2134`): `apply_take` (`git show upstream:path`), `apply_merged` (copy `state/merged/<path>`), `apply_delete`, each followed by `set_path_mode` + `git add` + `stage_index_mode` (`:726-753`, `:1754-1795`). A held row with `take-theirs`/`apply` first `backup_mine`s the founder's file to `state/mine/`. `growth-engine/*` skipped (`:2076`).
7. **Generated pass** (`:2136-2183`): skill-pack compile + install (Launchhouse-specific).
8. **Version bump + one commit** (`:2185-2197`): write upstream sha to `.claude/launchhouse-version`, `git commit -m "Launchhouse update to <sha12>"` in the worktree. Empty diff => `aborted: nothing to apply`, which the skill reports as "up to date" (`SKILL.md:181`).
9. **Hold-back** then **gate** (`:2207-2222`): section 1.10, 1.9.
10. **Abort path** (`:2225-2244`): remove worktree, branch and tag; print `result=aborted`, `failed=<gate>`, `reason=`, `log=`, `unchanged=yes|no`. Nothing in the live tree has been touched at this point.
11. **Land** (`:2246-2254`): `git merge --ff-only $branch`, record `applied`.
12. **Post-landing smoke on the live folder** (`post_landing_smoke`, `:1455-1542`): (1) run the notes' checks again for real, (2) `settings.json` still valid JSON, (3) every hook command's script path resolves, is readable and passes `sh -n` (it **never executes** a hook: several write founder state, `:1487-1495`), (4) no tracked `.claude/` file differs from what the commit recorded (checkout-time line-ending change). Any failure => automatic `do_undo` => `result=reverted` or `result=reverted-failed` with `pre_update_tag` (`:2392-2410`).
13. **Success bookkeeping** (`:2263-2379`): resolve a pending settings-restore tag, resolve/refresh `held.tsv`, print `result=applied` + `held=<id>` lines + changed paths.

### 1.9 Checks: gating vs maintainer-only (`run_checks_in`, `update.sh:1286-1408`)

Only what protects the founder can abort. **Gating** (a failure prints `gate_failed=<name>`): the notes' own checks via `updates-checks.sh` (`:1302-1306`); `settings.json` valid JSON (`:1325-1330`); every hook command in `settings.json` resolves to a readable, `sh -n`-clean script (`:1343-1361`); and **`growth-engine/` byte-identical**: the worktree's `HEAD:growth-engine` tree sha must equal the live repo's (`:1363-1368`) - a cheap exact proof via git tree objects. Additionally, if the plan contains any `safety: true` note, the machinery it depends on (`updates-checks.sh`, `settings.json`, a JSON validator) must exist or the gate fails closed (`:1297-1341`, commit `c82aa54`).

**Non-gating**: the full maintainer suite (`run.sh`, `state.sh`, `skill-packs.sh --validate/--check-compiled`) runs and writes `last-checks.log`, never stops anything (`:1370-1404`). If none of those exist at all it prints `checks=none` and the apply refuses unless `--allow-no-checks` (`:1405`, `:2218-2221`).

`updates-checks.sh` semantics (`.claude/tests/updates-checks.sh`): no notes tree => `notes=none`, exit 0 (`:56-66`, so old trees never fail); linter first, a missing linter with notes present is a FAIL (`:112-128`); for each note (every release folder, never only newest) run `(cd root && REPO_ROOT=root sh <check>)` (`:199`); **safety note**: missing/unreadable check, `check: none`, malformed `safety:` value (treated as safety, `:165`), any non-zero exit incl. syntax error => FAIL (`:170-175`, `:184-197`, `:207-214`); **non-safety note in a founder copy** => failing check prints `WARN` and the run stays green, in the template repo the same failure is a FAIL (`:93-105`, `:204-206`). A failing check's last output line `hint=<plain sentence>` is replayed at the very end so it survives `tail` (`:210-222`).

### 1.10 Hold-back: fail one improvement, not the whole update (`hold_back_failing_notes`, `update.sh:1855-2072`)

After the update commit exists in the worktree and before the gate, every **non-safety** note that has a check file and touched a path this apply changed is tested (`REPO_ROOT=$wt sh state/notes/<id>.check.sh`, `:1869-1895`). A failing note's touched paths are reset to the founder's own HEAD content (`restore_path_to_head`, `:1809-1822`), the commit is `--amend`ed (`:2059`), and the note is written to `held.tsv` with the base commit it was classified against (`:2353-2374`). Rules learned the hard way: widen to any other non-safety note sharing a touched path, to a fixed point (`:1902-1928`); never restore a path a safety note also touches and, if that makes a "held" note's change stay live, **abort the whole apply** instead of lying (`:1955-1995`); abort if restore or amend fails (`:1997-2009`, `:2059-2065`); a held pack source triggers recompile/reinstall (`:2011-2052`). The next `--plan` re-offers a held note regardless of base presence (`:816-820`) and classifies its paths against the base it was held against (`.heldbase.tsv`, `:916-926`, `held_base_for_path` `:536-544`).

### 1.11 Commit and undo

One commit per update, in a worktree, fast-forwarded into the live branch (`:2192`, `:2246`). Undo (`do_undo`, `update.sh:2455-2570`): reverts **only the commit recorded in `state/applied`**, never one found by message or newest tag (`:2458-2465`); refuses if the tree is dirty or a merge is in progress; requires the commit still be an ancestor of HEAD, the tag exist, the subject start `Launchhouse update to`, and the commit's parent equal the tag's commit (`:2470-2492`); refuses if the commit touches `growth-engine/` (`:2497-2502`); `git revert --no-edit`, then **verifies every path the update touched now matches the tag** with `undo_mismatched_paths` (`:2439-2448`, `:2520-2527`), because a merge driver can make git report success or "nothing to revert" without restoring content (commit `1f6596a`). On a real overlap with later founder edits: `git revert --abort`, `result=aborted reason=later changes overlap the update` and the conflicting paths (`:2556-2569`).

### 1.12 The ignore file and ownership rules

`.launchhouse-update-ignore` is read from the **upstream** head (`git show $uh:.launchhouse-update-ignore`, `update.sh:929`, again at `:1000`), never the founder's copy. One glob per line; trailing `/` = prefix (`match_ignore_pattern`, `:369-376`). It lists maintainer-only paths (`docs/`, `IMPLEMENTATION-NOTES.md`) that exist in the template repo but must not reach founders, "never proposed as add, never diffed, never held" (`.launchhouse-update-ignore:1-7`). Separately `docs/upstream-exclude.txt` keeps the same paths out of upstream PRs (`:1-26`) - two lists for the two directions (what the founder never receives vs what the maintainer never publishes). Founder `.gitignore` is also honoured by `git check-ignore` (`:387`).

### 1.13 Notes: schema, `requires`, declined notes, safety, `adds`, `founder-data`

Frontmatter keys (`.claude/updates/README.md:22-51`): `id title purpose touches adds requires safety done-when check founder-data`; `purpose` single line (awk-readable, `:27`); lists are `  - item` lines or `[]`. Body: `## What changed and why`, `## What a stock file looks like after`, `## Migration` (only if `founder-data: true`). Linter rules: all keys present and non-empty (including quoted-empty), `touches` and `done-when` at least one item, `safety`/`founder-data` exactly `true|false`, `id` equals filename, safety note must name an existing check, no `touches` under `growth-engine/`, every `touches` path exists (`updates-lint.sh:155-236`).

What is **implemented in the engine** versus **schema-only**:

| Field/idea | Engine behaviour |
|---|---|
| `touches` | used: `notes_touching` ties held rows to notes (`:758-770`), hold-back restores these paths (`:1944-1953`), adapt-save checks ids against it (`:1012-1022`) |
| `safety` | used: gate fails closed (`:1297-1341`), hold-back never holds it (`:1871`), skill forbids skip (`SKILL.md:79`, `:214`) |
| `check` | used: `updates-checks.sh` + hold-back + post-landing smoke |
| `done-when` | executable ones live in the check script; prose ones are read by the reviewer for **adapted rows only** (`update-reviewer.md:37`) |
| `requires` | **not implemented**: grep finds it only in lint's required-key list (`updates-lint.sh:162`) and one comment (`update.sh:686`). No dependency ordering, no "blocked" state. Doc lists it under "Later" (`docs/...:745-748`) |
| declined notes | **not persisted** - see section 3.2 |
| `adds` | **not read** by any code |
| `founder-data` / `## Migration` | **not read by the engine**; the skill tells Claude to ask separately and run a named migration skill after landing (`SKILL.md:125,138`, `update-reviewer.md:31,52`) |

### 1.14 The `settings.json` bridge, end to end

Problem: a founder who customised `settings.json` before the connector dispatcher existed would, if they kept it, fail the wiring check; if they took upstream's, lose their customisation. Mechanics as built:

1. Both-changed `settings.json` is always held (`update.sh:666-667`) and goes to the adapter like any held row.
2. If a **safety** note is approved for it and adapt-save refuses or the adapter returns `cannot-adapt`, the decision becomes `take-theirs` (`SKILL.md:98`): upstream's file lands, the founder's goes to `state/mine/` (and, durably, to the pre-update tag).
3. `--apply` records per tag whether `settings.json` was `taken` or `adapted` (`:2128-2133`).
4. After every successful apply the skill runs `--restore-settings-plan` (`SKILL.md:171`). It walks **HEAD's own history newest-first** (never tag creator-date: two tags in one run can share a timestamp, `:1115-1121`), and picks the first `launchhouse-pre-update-*` tag where: an update commit directly follows it with subject `Launchhouse update to...` (`:1129-1134`); the tag's `settings.json` differs from its own base's (i.e. it was customised, `:1136-1143`); the live `settings.json` still equals what that update took (founder has not touched it since, `:1145-1147`); not recorded `adapted` (`:1158-1161`); not already offered (`:1126`). It writes a one-row plan (`mine` = tag's file, `theirs` = HEAD's file, `base` = that update's base) and the normal adapt/approve/apply flow runs as **its own recorded, undoable update** (`:1176-1232`).
5. `restore-pending` vs `restore-offered`: a tag is only retired by an applied restore or an explicit `--restore-settings-decline`, so an interrupted session re-offers it (`:1191-1199`, `:1240-1251`, `:2263-2275`).
6. Safety net around it: `run_checks_in` and `post_landing_smoke` both require valid JSON and resolvable hook scripts.

### 1.15 How the first release introducing the model arrives (doc section 8, `docs/purpose-based-updates.md:548-636`)

Three facts from the doc and code that matter for LogicLoom's constraint C:
- An old engine can only deliver *files*; the only new code it **executes** is the new tree's own checks, because `run_checks_in` runs whatever `run.sh`/`state.sh` exist in the updated worktree (doc `:556-559`). Commit `e0a686c` states it as: "the new checks are the only part the old updater picks up".
- Therefore the new checks defend against the old engine's leaks: `LH_UPDATE_RELOCATED`/`LH_UPDATE_ROOT` were exported by the old engine into checks and corrupted nested engine runs, so `run.sh`, `state.sh`, `update-cases.sh` all `unset` both before doing anything (`run.sh:11-17`; enforced by `state.sh:1819-1830`).
- The updater machinery itself is **upstream-owned**: `.claude/updates/**` is always taken (`update.sh:560-576`); update.sh/lib.sh/skill/agents are listed as "taken whole" in the boundary plan (doc `:566-574`), and the bootstrap path (section 1.3 step 1) means a copy never has to trust its own stale engine.
- A founder on an older copy follows a paste-in prompt in `README.md:56-60` or the generalised `AGENTS.md` steps; both end up reading upstream's current `SKILL.md` and running the engine from `<gitdir>/launchhouse/bootstrap/`.

### 1.16 Test wiring (`run.sh`, `update-cases.sh`)

- `run.sh` calls: linter fixtures (`run.sh:1408-1570`, ~160 lines), connector-check fixtures against compact/2-space/8-space/CRLF/variant/spoofed-matcher settings variants (`:1574-1726`), settings-reformat full-suite proof (`:1738-1820`), `updates-checks.sh` fixtures (`:1822-1996`), then `update-cases.sh` (`:1998-2030`), then the real `updates-checks.sh` (`:2032-2039`, "near the end on purpose" so a failing note's `hint=` stays inside the tail), then `agents-doc.sh` (`:2041-2044`), then a final settings-wiring `hint=` line (`:2052-2058`).
- Inside an apply worktree `run.sh` **skips** `update-cases.sh` and the settings-reformat proof, detected structurally by `git rev-parse --show-toplevel` ending in `/launchhouse/update/wt` (`run.sh:2019-2023`, `:1738-1741`). Rationale in the code: it halves the in-update time (188 s -> ~60 s per commit `e02bc5e`). Needs `state_dir`'s worktree path to be stable - it is, `update.sh:1745`.
- `update-cases.sh` (4308 lines, 366 `check`/`ok`/`want` calls by my grep): builds throwaway upstream + founder repos under `$TMPDIR`, with a **stub `run.sh`** exit-0/1 instead of a mock hook (`update-cases.sh:7-22`). Section map: core plan/apply/undo (`:64-432`), bootstrap-from-`.git/launchhouse/bootstrap` (`:433-475`), detect-base identical trees (`:475-535`), trust (`:535-568`), stale plan (`:568-602`), undo trust (`:602-636`), skill-pack generated/spoof (`:636-1086`), notes/adapt (`:1087-1590`), restore-settings (`:1590-1820`), post-landing smoke (`:1820-2133`), undo verification (`:2133-2200`), updates-owned (`:2201-2346`), gating (`:2398-2550`), e2e (`:2551-2743`), optional real-history clone gated by `LH_UPDATE_REAL=1` (`:2744-2888`), stale-worktree heal (`:2889-2966`), file modes incl. `core.filemode=false` (`:2967-3088`), safety gates (`:3089-3327`), hold-back (`:3328-4162`), unknown decision (`:4163-4228`), restore after adaptation (`:4229-4308`).

### 1.17 Every git mutation the script performs (relevant to LogicLoom's gate)

All run **inside `update.sh`**, i.e. invisible to a string-matching PreToolUse hook that only sees the outer `sh update.sh --apply` Bash command:

`git remote add` + `set-url --push upstream DISABLED` (`:77-79`); `git fetch upstream` (`:285`, `:882`, `:1096`, `:1645`); `git add` + `git commit` of the version file (`:355-356`); `git tag` / `git tag -d` (`:1743`, `:2228`, `:2415`); `git worktree add/remove/prune` and `git branch -D` (`:1582-1596`, `:1749`); `git add`, `git rm -f`, `git update-index --chmod` in the worktree (`:749-751`, `:1759`, `:1791`, `:1816`); `git commit` and `git commit --amend` in the worktree (`:2059`, `:2192`); `git merge --ff-only` into the live branch (`:2246`); `git checkout -- .claude/` (`:2389`); `git revert --no-edit` / `--abort` (`:2510`, `:2542`, `:2558`); and **`git reset --hard "$pre_head"`** (`:2522`, undo-verification failure path). The skill itself also runs `git add -A`, commit, and `git push origin` (`SKILL.md:41`, `:166`).

---

## 2. Hard-won lessons: the review rounds we get for free

Source: commit bodies for every commit touching the updater (`git log --reverse -- update.sh SKILL.md updates/ agents/update-*.md docs/purpose-based-updates.md updates-checks.sh`; 17 commits touch `update.sh` itself, 116 in the repo). Dates are 2026-09-21 to 09-27: **seven days from first engine to the last fix**. Each row is a real failure, not a hypothetical. "LL" says how it maps to LogicLoom.

### 2.1 Before notes existed (the diff-based engine)

| # | Commit | Failure | Fix | LL relevance |
|---|---|---|---|---|
| 1 | `1f785f6` | An `upstream` remote pointed anywhere could feed the updater; stale plans applied after the tree or upstream moved; undo could revert the wrong commit; an update with no checks silently passed | upstream address pinned to the **committed HEAD** value of `.claude/launchhouse-upstream` (a tampered working copy could repoint it, `update.sh:83-91`); plan carries `head`+`upstream` and `--apply` refuses if either moved (`:1642`, `:1651`); undo reverts only the recorded commit (`:2458`); `checks=none` refuses without `--allow-no-checks` (`:2218`) | Trust root must be something a customer's working tree cannot rewrite. Adopted channel needs its own pinned source |
| 2 | `3072948` | `--detect-base` mis-picked among upstream commits when a PR's merge commit has a `.claude` tree identical to its parent | scan first-parent history only, newest exact match wins (`:315-324`) | Applies to any "match tree to history" base detection (LL template clones) |
| 3 | `3072948` | **`LH_UPDATE_RELOCATED`/`LH_UPDATE_ROOT` (re-exec markers) leaked into checks**; checks that shell out to `update.sh` ran against the outer apply's root; the real cause of bootstrap/poisoned-upstream/no-checks failures | unset in `run_checks_in` (`:1303`) AND at the top of every test script that calls the engine; `state.sh:1819-1830` fails if any test script forgets | An old engine pollutes the environment of the NEW tree's checks. New checks must defend against old-engine leaks. Directly relevant to constraint C |
| 4 | `5acb1a8` (cross-provider review findings) | A forged or foreign "installed from pack" marker made a founder-edited file look generated and get overwritten | marker must name exactly the source path the installer would use, source must exist at that commit and be registered by the pack; drift from regenerated output is a conflict (`:208-262`, `:470-519`) | Launchhouse-specific mechanism, general lesson: **never trust a provenance marker by shape**. This is the same class as LL v7's inference failures |
| 5 | `11218d9` | state checks the engine did not run in-update were failing after landing | run `state.sh` too | trivial |
| 6 | `77d8e1e` | strict YAML parsers rejected `description:` values containing `": "` | quote them | LL agents/skills frontmatter: same trap |

### 2.2 Notes + adapter (09-22 to 09-23)

| # | Commit | Failure | Fix | LL relevance |
|---|---|---|---|---|
| 7 | `e0a686c` (PR #54 fix, a prerequisite for the whole model, doc `:575-582`) | A state check demanded `growth-engine/` hold only the template's starter files; **every founder with saved work failed the update's own checks** | split by mode: founder copy (tracked `.claude/launchhouse-version` or `growth-engine/.state/profile.md`) vs template repo; wording/style assertions run template-only (`8ade7be`, `ok_t()`) | **Template-conformance checks must never gate a customer**. Biggest single design rule: doc section 5 |
| 8 | `bdf9962` | the "JSON validator" was a brace count; the connector-safety check read **line shape** so reformatted/CRLF/compact settings failed or passed wrongly; empty and `""` values slipped the linter; scratch file in `.claude/tests/` | real recursive-descent `json-valid.sh`; check flattens JSON to `path<TAB>value` and asserts on content (matcher EXACTLY `^mcp__`, no retired script in any `command` at any depth); non-safety failing check is `WARN` in a founder copy; scratch files under `$TMPDIR`, fail closed if uncreatable | Outcome checks must read **meaning**, not text shape. LL `settings.json` hooks are the same problem |
| 9 | `3b85341` | Skill read notes from the upstream release path (a founder tree may have edited/removed it); asked after adapting rather than before; no note ids passed to adapt-save; blind retry on refusal | notes read from `state/notes/<id>.md` only; **ask first from the note's purpose, adapt only approved**; `--adapt-save` takes approved ids; never retry blindly | Same data-vs-instruction discipline |
| 10 | `1f6596a` | `.claude/updates/**` could be held/kept/deleted by a founder; smoke test **executed hooks** which wrote founder state; checkout-time CRLF change tripped undo's clean-tree guard; **`git revert` can report success or "nothing to revert" while content is wrong** (corrupt merge driver); `adapted` silently ignored on a non-held row | updates tree always upstream-owned (`:560-576`); smoke only resolves script paths + `sh -n` (`:1487-1524`); tracked `.claude/` reset before auto-undo (`:2388-2390`); undo verifies content vs tag (`:2439-2448`); refuse `adapted` on non-held (`:1726`) | Never trust git's exit status as proof of outcome; verify content. |
| 11 | `19b7909` -> superseded by `1f6596a` | A hook-start check grepped stderr for "not found" (a guard can legitimately print that) and ran hooks in a copy | decided by path exists + readable + `sh -n`; never execute | Do not execute hooks to prove they work |
| 12 | `fe404a4` ("seven remaining gaps") | founder `.gitignore` of `.claude/` hid a deleted safety note; reviewer judged adapted rows against **all candidate** note ids not the approved subset; a JSON **key literally named** `hooks/PreToolUse/0/matcher` spoofed a path; adapt-save validated JSON with the founder's live validator (alterable to always pass); a restore offer was marked resolved merely by being planned; `lh_mktemp` registry lost to `$(...)` subshell | `.claude/updates/*` exempt from `path_ignored` (`:381-386`); `adapted.tsv` carries approved ids; `/` and `\` escaped in flattened keys (`json-flat.sh:17-22, :116`); upstream's validator saved at plan time (`:871-876`, `:1033`); restore retires only on apply/decline; file-backed temp registry (`updates-lint.sh:41-60`) | Validators must come from the **trusted side**, never the tree being judged |
| 13 | `e02bc5e` | in-update checks took ~188 s; a killed/timed-out apply left a registered worktree so **every later apply failed forever**; `setup-check.sh` false alarm on reformatted `settings.json` | skip the engine's own self-tests + reformat proof inside an apply worktree, detected structurally (`run.sh:2019-2023`); self-heal + pid lock (`update.sh:1567-1601`); skill runs `--plan`/`--apply` with the 10-min Bash timeout (`SKILL.md:60`, `:149`); shared `json-flat.sh` | Long scripted steps need idempotent resume + a lock |
| 14 | `3e1000a` | agents other than Claude had no instruction file; a copy with a **stale** updater (not only a missing one) never got the newest | `AGENTS.md`; bootstrap whenever local `update.sh` **differs** from upstream's | LL already has AGENTS.md tandem |
| 15 | `9b96333` | `--set-base` wrote the version file without committing; `--apply`'s `is_clean` then refused **every first update of a version-less folder** | `--set-base` commits that one path (`update.sh:353-360`) | Any "record base" step must leave the tree clean or the next gate refuses |
| 16 | `02bd837` | outcomes narrated in internals ("checks failed", paths); scripts relied on the exec bit (Windows ignores it) | exactly three outcomes; every script invoked as `sh <file>` | LL: devs can see more, but the three-outcome discipline is still good |

### 2.3 After the first public run (09-24 to 09-27)

| # | Commit | Failure | Fix | LL relevance |
|---|---|---|---|---|
| 17 | `e67421f` | `git show blob > file` always lands mode 644: a new executable upstream script landed non-executable ("Permission denied"); **any failing check from the whole maintainer suite stopped every update** | mode mirrored on disk and in the index (`set_path_mode`, `:726-733`); only 4 founder-safety gates can abort; the full suite becomes a log (`last-checks.log`); a failing non-safety note is **held back alone** (`:1855-2072`) | Gate on what protects the customer; log the rest |
| 18 | `c82aa54` (six review findings) | gate **failed open** when `updates-checks.sh`/`settings.json`/validator were merely absent; hold-back dropped a path shared with a safety note but still printed `held=` (change stayed live, reported reverted); generated outputs missing from `changed_paths`; `git commit --amend` exit status ignored; a re-offered held note classified `keep` once the version file advanced past it (so `apply` was a no-op); `core.filemode=false` (Git for Windows default) ignores the exec bit in the index | fail closed when the plan has a safety note (`:1297-1341`); abort rather than lie (`:1978-1995`); fold generated paths in (`:2177-2182`); check every git step (`:2000`, `:2059`); `held.tsv` stores the base (`:2353-2374`); `git update-index --chmod` (`:746-753`) | "Absent" must never read as "nothing to check" |
| 19 | `288ab22` | `reverted-failed` was worded like a clean stop; a plugin check rejected **any** `enabledPlugins` key, failing a founder's unrelated plugin | honest wording: pause work, ask for help (`SKILL.md:191`); check rejects only the old plugin's own id | Checks must reject the specific bad thing, not the whole area. LL relevance: retired plugin dirs vs customer plugins |
| 20 | `bf99779` | `adapt/base` saved from the plan-wide base for a held path classified against its own older base; checkless held notes stayed held forever; **re-holding a note overwrote its original base with today's, so it could never re-apply** | `held_base_for_path()` shared by classifier and adapt writer (`:536-544`); resolve standing held ids when they land (`:2276-2319`); keep first-held base (`:2368-2370`) | Held/declined state needs its own base, or it vanishes (see 3.2) |
| 21 | `91a3765` | LH-028 blocked founders who kept an old harmless `enabledPlugins` line; "nothing changed" was presented as a stop | template-only vs gating split again; `generated`/`keep`-only plan and `reason=nothing to apply` both read "up to date" (`SKILL.md:62-63`, `:181`) | A no-op update is success, not an error |
| 22 | `263f6f9` | decisions.tsv is **written by an LLM**: a typo (`take` for `take-theirs`) fell through every `case` arm and was silently skipped; restore offered after an *adapted* settings merge (pointless, would drop merged content) | refuse unknown values before touching anything (`:1704-1713`); record taken/adapted per tag (`:2128-2133`) | Anything the model writes into a machine file needs a closed vocabulary + refusal |

### 2.4 Design-time decisions that were corrected before code (`6bbe4ae`)

- Adaptation moved to **plan time**, never inside the apply worktree, so the founder approves a plain-words description of a file version that already exists (doc `:248-259`).
- The worker was stripped of every write tool because the repo's hooks fail open and founders run without prompts (doc `:271-284`).
- A "legacy diff mode" fallback for spans with no notes was deleted: unnoted held rows are adapted from the commit diff + message instead, one code path (doc `:618-636`).
- Which notes apply is decided by tree presence, not date (doc `:225-239`), because a note can be added later under an earlier release folder.
- Maintainer side (`.claude/commands/upstream-pr.md:55-120`): a release step diffs the files that would ship against the union of every note's `touches` and drafts notes for uncovered paths; any note touching `settings.json`, a `*guard*` script, `ghl-op.sh` or `rules.awk` **must be `safety: true`** and its check must be **proven both ways** - exit 0 on `main`, non-zero (with a `hint=` last line) on a deliberately broken copy - with both runs shown (`upstream-pr.md:95-108`). That is a prompt-level procedure, not a script.

---

## 3. Where the design note, the skill, and the engine disagree (read before porting)

These are findings from reading code against the doc. None was run.

1. **Per-improvement approval covers only notes that have a held row.** The doc promises "the founder approves per improvement" (`docs/...:36-39`). The skill asks only for notes with at least one row in `adapt.tsv` (`SKILL.md:75`: "a note with no held row for it needs no question here; it is already covered by 'What is new'"). A note whose files the founder never changed is applied under the single final yes (`SKILL.md:125-126`). A safety note on untouched files is just a `take`. **The design for LogicLoom's decision 1 ("user approves per improvement") needs the engine to key approval to the note, which this engine does not do.**
2. **A declined or kept-mine improvement is never offered again.** `hold`/`keep-mine` write nothing (`update.sh:2081`), but the version file is bumped to upstream's head and committed in the same apply (`:2185-2197`); the next `--plan` then sees base == upstream for that file, founder changed, upstream not -> class `keep` (`:655-659`) -> "up to date" (`SKILL.md:63`). Only hold-back (failed check) writes `held.tsv` (`:2353-2374`), the sole mechanism that re-offers. The doc's recommendation (open question 2: re-offer with a one-line "still skip?") was not built; `docs/...:745-748` lists persisted declines as "Later". The skill text at `SKILL.md:68` ("offered again on their next update") is true only for hold-backs.
3. **`requires`, `adds`, `founder-data` are schema-only** (table in 1.13). `requires` has no ordering and no "blocked" state anywhere in the engine or skill.
4. **The note is not the unit of the engine; the file is.** Clean three-way merges (`merged-clean`) never reach the adapter or the note and are applied after only the reviewer's "read for sense" (`update-reviewer.md` waterfall step 7). Notes' `touches` can be wrong or incomplete without the engine noticing; the only guard is the maintainer-side coverage step (`upstream-pr.md:65-80`).
5. **Prose `done-when` is judged only for adapted rows.** The doc's open question 3 recommended the reviewer also judge whether a `done-when` is *checkable and matches the purpose*; `update-reviewer.md` has no such step (I read all eight waterfall items). A non-safety note with `check: none` that is `take`n or merged-clean is never verified at all.
6. **Non-safety check failures are two different things.** In `updates-checks.sh` a failing non-safety check is `WARN` in a founder copy (`:204-206`), so neither the gate nor post-landing smoke (which calls the same script, `update.sh:1463-1469`) fails on it. The *only* thing that acts on a failing non-safety check is `hold_back_failing_notes`, which reruns the check itself against the worktree (`:1889`) and only for notes that have a check **and** whose touched path this apply changed (`:1869-1878`).
7. **The Windows lane was promised, I could not find it.** Doc section 6 and build-plan item 8 (`docs/...:503-519`, `:727-729`) call for a Windows CI lane in the first slice. The repo has no `.github/`, no CI config (`git log --all -- .github` empty), and "Windows" appears in `update-cases.sh` 3 times, `update.sh` 3 times (comments). Defensive code exists (drive-letter path `update.sh:1608`, `core.filemode=false` handling `:735-753`, CRLF matching `:1056-1069`). Whether a lane exists outside this repo: unverified.
8. **Hook-gate extraction is line-shaped.** `extract_hook_commands` greps lines that begin with `"command":` (`update.sh:1422-1428`) and `hook_script_relpath` only understands `sh "$CLAUDE_PROJECT_DIR/<path>"` (`:1438-1446`). A compact one-line `settings.json` yields no commands, so the "every hook resolves" gate (`:1343-1361`) and smoke check 3 (`:1496-1524`) pass vacuously. This is the same bug class commit `e02bc5e` fixed elsewhere by introducing `json-flat.sh`; it was not applied here. By reading only.
9. **A content-equal file with a changed mode is never propagated.** `process_path` returns early on equal normalised hashes (`:635-637`); `norm_hash` hashes bytes only (`:157-161`). By reading only.
10. **Skill says "never reset", engine does.** `SKILL.md` hard rules forbid force/reset/rebase (`SKILL.md:211`); the engine's undo-verification failure path runs `git reset --hard "$pre_head"` (`update.sh:2522`). The engine is the exception; the skill-level rule is about Claude.
11. **Safety replace is not reversible via state alone.** A safety `take-theirs` backs the founder's file to `state/mine/` (`:1796-1801`, inside `.git`, lost on re-clone and overwritten by the next backup, doc `:603-607`); durable recovery is the pre-update **tag**, which is local-only unless the founder pushes tags.
12. **Executable check scripts come from upstream and run with the user's rights**, in the worktree (`:1889`, `:1303`) and in the live folder (`:1464`). Trust therefore reduces to the upstream pin (finding 1 of 2.1). The linter never inspects a check's contents.

### Five-layer `growth-engine/` protection (the model for LL's "product + `.brain/` never touched", constraint F)

Excluded from the path universe (`update.sh:935`); `path_ignored` (`:380`); apply loop skip (`:2076`); `--adapt-save` refusal (`:992-996`); note linter forbids `touches` under it (`updates-lint.sh:229-233`); **tree-sha equality gate** `HEAD:growth-engine` in worktree vs live (`:1363-1368`, an exact, cheap, content-independent proof); undo refuses a commit that touches it (`:2497-2502`). Layers are redundant on purpose (several were added after review, e.g. the gate in `e67421f`).

---

## 4. What is Launchhouse-specific and would NOT port

### 4.1 Skill-pack machinery (~570 lines of `update.sh`, plus ~600 lines of fixtures)

Entirely about Launchhouse's own `skill-packs.sh` installer: install-marker parsing and forgery defence (`update.sh:163-262`, `:439-535`), the `generated` class and its apply-time recompile/reinstall (`:579-614`, `:639-643`, `:2136-2183`), hold-back's pack-source recompile (`:2011-2052`), `registry.tsv` union merge (`:429-437`, `:664-665`), `skill-packs.sh --validate/--check-compiled` in the maintainer suite (`:1389-1397`). Fixtures: `update-cases.sh:636-1086` (~450 lines), `:3543-3700` (~160). LogicLoom has no installer that regenerates tracked files from sources, so none of this ports. (The only transferable idea is rule #4 of 2.1: a provenance marker is never trusted by shape.)

### 4.2 One channel, one upstream, one base pointer

Every Launchhouse folder is a git repo whose `upstream` remote is the public template: default URL constant (`update.sh:54`), per-copy override `.claude/launchhouse-upstream` read from the **committed** tree (`:87-91`), base pointer `.claude/launchhouse-version` committed by the engine (`:344-360`, `:2187`), "Use this template" copies (no shared history) matched to an upstream commit by `.claude` **tree hash** with `exact`/`closest`/`none` (`:300-330`). The engine **requires** a real base commit in the local object store: classification (`:552-554`), note presence (`:815`), adapter `base` side (`:844`), and held-base (`:536-544`) all `git show`/`git ls-tree` it. There is no concept of "a receipt of hashes" and no concept of an install that has no upstream history. This is exactly the hole in LL constraint D for adopted installs.

### 4.3 Founder wording and a non-terminal user

The skill and agents assume a founder who never sees a terminal, a diff, or a commit (`SKILL.md:10-16`, `:155-163`), use "Slack channel", "mentor", "quit and reopen the Claude app" (`SKILL.md:165-189`), three outcomes only (`:157-159`). LogicLoom's customers are developers who can see diffs and commands; the wording layer must be rewritten, but the discipline "name their doubt first, three outcomes, never relay raw check output" is portable.

### 4.4 `growth-engine/` and `.state/`

Hard-coded in six places (see section 3 last paragraph) plus `is_clean`'s `grep -v ' growth-engine/\.state/'` (`:143`) and the `founder copy vs template` detector keyed on `growth-engine/.state/profile.md` (`updates-checks.sh:101-105`). The *mechanism* ports (a list of protected trees; tree-sha equality gate) but the literal names do not.

### 4.5 The hook-command shape and `settings.json` specifics

`hook_script_relpath` only understands `sh "$CLAUDE_PROJECT_DIR/<path>"` (`:1438-1446`); `extract_hook_commands` is line-based (`:1422-1428`). LogicLoom's `.claude/settings.json` wires hooks differently and from two script trees (LL `CLAUDE.md`, "LogicLoom Hooks" table), so this must be rewritten (and should use `json-flat.sh`; see 3.8). The connector-dispatcher note and its `^mcp__` assertions are Launchhouse's own safety content, not portable.

### 4.6 Threat model: "no permission prompts, hooks fail open"

The whole "worker has no write tool, deterministic code gates its output" argument (doc `:271-284`) exists because Launchhouse founders run in a mode with no prompts and every hook fails open (`lib.sh:3`). LogicLoom's posture is the opposite (hooks deny/ask; `protect-governance-files.sh` makes subagent writes to governance paths DENY and main-agent writes ASK; LL `CLAUDE.md` "Hook enforcement"). The read-only adapter is still the right design for H (adapter is an agent), but the justification changes, and **the engine's own writes into the worktree will not pass through any PreToolUse hook** (they happen inside `sh update.sh`, 1.17), so governance-file protection for update-written files must be re-implemented in the engine or enforced by routing the apply through main-agent-approved steps. That is a design decision for the next phase; this study only flags it.

### 4.7 Windows / Git Bash lane

POSIX sh + awk was chosen because founders run Git for Windows' own `sh`/`gawk` (`lib.sh:1`, `update.sh:1-6`, doc `:503-519`). CRLF preservation, `core.filemode=false` index modes, drive-letter decisions paths (`update.sh:1608`) are Windows-driven. LogicLoom's floor is **bash 3.2 on stock macOS** (LL `tests/contract/test_bash32_floor.sh:1-60`), not Windows; the Windows-only code could be dropped, though CRLF-insensitive hashing is cheap and worth keeping (`norm_hash`, `update.sh:157-161`).

### 4.8 The restore-settings bridge (`update.sh:1083-1251`, 169 lines)

Fixes one specific history: the old engine took `settings.json` wholesale when it could not adapt it, and the founder's customisation must be brought back later (doc section 8). The *pattern* (recover the pre-update copy from a tag, re-adapt as its own recorded undoable update, decline retires it) is reusable if LogicLoom has an analogous one-time loss; the code is tied to `launchhouse-pre-update-*` tag naming and the commit subject `Launchhouse update to` (`:1123`, `:1132`).

### 4.9 Reviewer waterfall items tied to Launchhouse content

`update-reviewer.md` steps 2 (formats documented in `contract.md`/`state.md`/`gates.md`), 4 (`growth-engine/` references to skills), 5 (duplicate frontmatter names), 6 (local skill-pack format drift) are Launchhouse-domain. Steps 1, 3, 7, 8 (dependency grep, settings customisation, clean-merge sense-read, adapted-vs-purpose) are generic.

### 4.10 Founder-copy mode vs template mode

`updates-checks.sh:93-105` and `state.sh`'s `lh_founder_copy()` decide behaviour from tracked marker files. LogicLoom has the equivalent ambiguity (template repo, customer clone, adopted install) and needs its own detector; the **principle** (template-only conformance checks) is portable.

---

## 5. The portable core, with line counts

Counts are mine, from line ranges I read; function-comment blocks are attributed to the function below them. "Port" means the logic carries over with path/wording/channel edits, not copy-paste.

### 5.1 `update.sh` (2594 lines total)

| Block | Lines | Notes |
|---|---:|---|
| Self-location, `state_dir`, helpers (`blob_sha`, `norm_hash`, `is_clean`, `in_progress`) | `22-60`, `134-171` = 77 | trivial; `norm_hash` CRLF-insensitive |
| Upstream pin + trust check + default branch | `62-133` = 72 | **rewrite** for LL channels (4.2) |
| `--status`, `--detect-base`, `--set-base` | `263-368` = 106 | **rewrite**: base detection per channel |
| Ignore file matching | `366-398` = 33 | port; ignore list source differs (see section 6, E) |
| `process_path` classification (generic part: updates-owned, add/take/keep/both-changed/merge) | `546-577`, `616-637`, `645-663`, `668-677` = ~115 | the heart; port |
| `try_merge_file`, `write_row`, `write_diffs`, `held_base_for_path`, `save_side`, `is_symlink_at` | `400-427`, `536-545`, `698-725` = ~65 | port |
| Mode helpers (`set_path_mode`, `stage_index_mode`) | `726-753` = 28 | port (needed: a `git show > file` lands 644) |
| `lh_note_fm_list`, `notes_touching`, `build_notes_tsv` | `688-697`, `758-831` = 84 | port; base-presence logic needs channel work (4.2) |
| `write_adapt_row`, `build_adapt_tsv`, `save_upstream_json_validator` | `840-877` = 38 | port |
| `cmd_plan` skeleton | `878-967` = 90 | port minus pack bits |
| `cmd_adapt_save` (validation gate) | `968-1081` = 114 | port; JSON validation reusable for `settings.json` |
| `run_checks_in` (gating half: notes checks, settings JSON valid, hooks resolve, protected-tree equality, fail-closed on missing safety machinery) | `1286-1369`, `1405-1408` = ~90 | port; protected-tree list and hook parsing change |
| `post_landing_smoke` (generic checks 1, 2, 4) | `1455-1486`, `1526-1542` = ~50 | port |
| Lock + stale-worktree heal | `1546-1602` = 57 | port as-is |
| `cmd_apply` pre-flight, decision validation, tag, worktree, per-row writes, commit, abort, ff-merge | `1603-1823` (excl. helper defs shared above) + `2074-2134` + `2185-2261` = ~330 | port |
| `hold_back_failing_notes` (generic part) | `1855-2010`, `2054-2072` = ~170 | port; the 5 subtle rules in 1.10 are the value |
| Held-note bookkeeping (`held.tsv`) | `2276-2374` = 99 | port, **and fix 3.2** |
| `do_undo`, `undo_mismatched_paths`, `cmd_undo` | `2428-2594` = 167 | port nearly verbatim |

Roughly **1,800 of 2,594 lines (~70%)** are portable with edits; ~570 (22%) are Launchhouse-specific (4.1, 4.5, 4.8); ~230 are glue, comments and the status/dispatch plumbing. Of the ~1,800 portable lines, ~180 (upstream pin, status/detect-base/set-base, version file) must be **rewritten** rather than adapted because LogicLoom has two channels (4.2).

### 5.2 Everything else

| Artefact | Lines | Portability |
|---|---:|---|
| `updates-lint.sh` | 243 | ~90% (swap `growth-engine/` for a protected-path list) |
| `updates-checks.sh` | 225 | ~85% (founder/template detector, 4.10) |
| `json-valid.sh` + `json-flat.sh` | 427 | 100% as-is (POSIX sh + awk, gawk/mawk/BSD) |
| `.claude/updates/README.md` (schema) | 121 | ~95%; add the fields LL needs (see section 6) |
| `update-adapter.md` | 55 | ~85% (rules about hooks/permissions/JSON/CRLF apply to LL `settings.json`) |
| `update-reviewer.md` | 70 | ~50% (4.9) |
| `SKILL.md` | 216 | ~50%: flow, 3-outcome reporting, hard rules port; wording and `growth-engine`/Slack do not |
| `AGENTS.md` update section | ~25 | concept ports (LL has an AGENTS.md tandem) |
| `update-cases.sh` | 4308 | ~3,600 lines of fixtures port with rewrite (all but 4.1's ~610); the **case list** in 1.16 is the value |
| `run.sh` update wiring | ~330 lines (`:1408-1570`, `:1822-1996`, `:1998-2058`) | the three patterns port: lint fixtures, checks fixtures, skip-in-apply detection |
| Notes + checks (7 + 7) | 61-106 / 44-104 | **content is Launchhouse's; structure is the template**. Best reusable exemplars: `connector-safety-routing` (safety, content-based JSON check, 91 lines) and `ghl-install-link` (byte-identity outcome check, 104 lines) |
| `docs/purpose-based-updates.md` | 840 | design reference; sections 3-6 and 12 are directly reusable as LL's own design inputs |

Total Launchhouse updater-related source (engine, lint, checks, json, skill, agents, schema, notes, `update-cases.sh`, design doc; excluding `run.sh`/`state.sh`): **~10,100 lines**, of which the engine + its fixtures are 6,900.

---

## 6. Facts the LogicLoom design must answer (pointers from this reading, not decisions)

I read only the LL files cited here, to ground the questions. Reader B/C own the LL side.

1. **Approval per improvement vs per file.** LL decision 1 wants per-improvement approval. Launchhouse's engine asks per note only when a held row exists (3.1). A port that keeps its class table must add an approval layer keyed on the note for *every* touched path, including `take` rows.
2. **Declined must persist** if the maintainer wants "undo-able and re-offerable" (3.2). The simplest fix visible from the code: do not advance the base for a declined note's paths, or record declined ids with the base they were declined against (the `held.tsv` row shape `id<TAB>reason<TAB>base-sha` already does this for hold-backs).
3. **Base for the adopted channel.** The engine needs a base commit tree (4.2). `extract-proposals.sh` for adopted installs filters by receipt-recorded paths: M/D/R proposed only for recorded files, A by an ancestor-directory rule (`LL:plugins/loom-maintenance/scripts/extract-proposals.sh:592-606`). Launchhouse's `exact`/`closest`/`none` ladder (`update.sh:282-330`, `SKILL.md:49-56`) is the closest precedent: determine base by matching content, ask the user on `closest`, stop on `none`. Whether a receipt of content hashes can stand in for a base commit tree is a design question; the engine's three-way merge and adapter `base` side need an actual base **file**, not just a hash. (Hash-only means: you can tell "unchanged since install" but you cannot reconstruct what changed upstream relative to the customer's edit; classification `take` vs held is still possible, three-way merge is not.)
4. **Git mutations (constraint A).** The Launchhouse engine performs ~12 distinct git mutation kinds inside the script (1.17). LL's `git-safety-gate.sh` and `subagent-git-guard.sh` inspect the Bash command text (LL `CLAUDE.md` Hook enforcement table), so they will see `sh .../update.sh --apply`, not the nested `git tag`/`git commit`/`git merge --ff-only`/`git revert`/`git reset --hard`. Mapping to `gate-policy.conf` (`LL:.logic-loom/config/gate-policy.conf:1-60`; `commit`, `add`, `checkout`, `stash`, `fetch` silent, `push` and history rewrite FLOOR=ask per LL `CLAUDE.md`): tag, worktree, commit, `--ff-only` merge are local and cheap to undo (silent-class); `git reset --hard` and `git revert` are the closest to history rewriting (whether `guard-dangerous-commands.sh` denies `reset --hard` inside a nested script call: not checked); `push` is never in the engine (the Launchhouse **skill** pushes, `SKILL.md:166`, which LL must not copy). Who runs it: only the main agent may run the engine; subagents (adapter/reviewer) never run git (their tools exclude it, except the reviewer's allowlisted read-only git, which LL's subagent guard already permits).
5. **Bash 3.2 floor (constraint B).** LL's floor test statically greps `*.sh` under harness-owned trees for bash-4-only constructs (`LL:tests/contract/test_bash32_floor.sh:157-163`) and executes selected scripts under real bash 3.2 on macOS only (sections 4-5). A `#!/bin/sh` + awk engine contains none of those constructs, so it passes the static scan if it lives under a scanned tree (`.logic-loom/`, `.claude/hooks/`, `tests/`, `packaging/adopt/`, declared plugins, same file, `:15-60`). What the floor does **not** prove is that `sh` on stock macOS (bash 3.2 in POSIX mode, per my background knowledge, not verified here) runs the engine; that needs a fixture run under `/bin/sh`, analogous to section 4 of that test.
6. **Strip/payload manifests (constraint E).** Launchhouse solves "ships vs does not ship" with two lists: `.launchhouse-update-ignore` (read from upstream, so the customer never receives or diffs those paths, 1.12) and `docs/upstream-exclude.txt` (keeps them out of upstream PRs). The note-coverage step in `upstream-pr.md:55-120` is the maintainer-side guard. LL has `template-strip-manifest.txt` and `packaging/adopt/payload-manifest.txt` for the two directions; a port must add: engine, lint, checks, notes, agents, `/update-loom` to the *shipped* sets, and keep design docs and `features/update-loom/` out.
7. **Notes are executable code from upstream.** Checks run with the user's rights in the worktree and the live tree (3.12). LL's governance floor makes hooks/settings writes ASK or DENY, but a check script is arbitrary shell. The upstream pin (2.1 #1) plus "checks live under a path owned by upstream and always taken" (`update.sh:560-576`) is what Launchhouse relies on.
8. **Release-migrations salvage.** The 23 retired-plugin rows map naturally onto Launchhouse's note shape: `touches` = the retired directory, a `safety: false` note per plugin, an executable check asserting "no hook in `settings.json` names the retired path" (the exact shape of `connector-safety-routing.check.sh:60-85`), and the `adapt` flow for the "pristine vs customised" split: a pristine directory is an unchanged-since-base file (`take`/`delete` class, `update.sh:645-653`), a customised one is `deleted-upstream-kept` (hold, `:662-663`) which is already a first-class class here. No ownership inference is needed because the base commit says which it is, again subject to point 3.

---

## 7. What I did not verify

- Nothing was executed. I did not run `update-cases.sh`, `run.sh`, `update.sh`, or any check script; claims about behaviour are from reading code and commit bodies.
- Findings in section 3 items 2, 8, 9 are inferred from code paths; I did not construct a fixture to confirm them. Item 2 is the most consequential: confirm with a fixture (decline a held note, apply, re-plan).
- `update-cases.sh` was read via its section headers and ~160 lines of its setup/bootstrap/real-history parts, not line-by-line. The 366 count is `grep -c '^check\|^ok \|^want'`.
- I could not find a Windows CI lane or any `.github/` in the repo; it may live outside this repository.
- I did not read `state.sh` (1890 lines) beyond the lines cited, `skill-packs.sh`, `lib.sh` beyond its header, `prepare-upstream-pr.sh` beyond a grep, or the root `CLAUDE.md` beyond the lines cited. `ghl-install-link.md`/`agents-md-guidance.md` were read in full; the other five notes and checks in full as listed.
- The statement that stock macOS `/bin/sh` is bash 3.2 in POSIX mode is background knowledge, not checked in this session.
- LL-side facts in sections 4.5-4.7 and 6 come only from the cited LL lines; I did not audit LL's hooks, settings, or `update-framework` command.
