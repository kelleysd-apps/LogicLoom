# Changelog

All notable changes to LogicLoom (formerly the SDD Agent Framework) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Next release: **7.0.0** — major. The update path gains a release-migration
registry that `/update-framework` evaluates against your tree, and adopted
installs start recording what `/update-framework` writes.

### Migrating from 6.x

- Template clones: run `/update-framework`. Accept the `.logic-loom/config`,
  `.logic-loom/lib` and `plugins/loom-maintenance` proposals first; the Step
  3b scan then runs on every later run. `CLAUDE.md` shrank (sections moved to
  `.docs/architecture/loom-architecture.md`,
  `.docs/policies/project-amendments-policy.md` and `.brain/README.md`) — a
  customised `CLAUDE.md` arrives as `conflict-review`; take the moved files
  as `clean-add` and carry your `CLAUDE.md` edits by hand.
- Adopted installs (`npx logicloom init`): run
  `bash plugins/loom-maintenance/scripts/record-update-writes.sh --reconcile`
  once (the scan proposes it as an `MG-…` item on the first run of the
  v7.0.0 procedure — your second invocation, since the first one still
  runs the 6.x command that fetches it). The ownership filter is new in
  7.0.0: a 6.x `/update-framework` filtered nothing, so a file it added is
  not in the receipt, and from 7.0.0 on an upstream edit to it would be
  suppressed. Reconciling records those files as yours before that happens.
- Pre-v6.2 clones: re-baseline first (`FRAMEWORK_SYNC_GUIDE.md` "Broken sync
  baseline"); the `.specify/` → `.logic-loom/` rename is not covered by the
  registry.
- Decisions: `.logic-loom/config/migration-decisions.conf` is project-owned;
  commit it.
- Both a template clone still on 6.x and an already-adopted 6.x install
  receive all of the above through their **existing** `/update-framework` —
  the new files ride the same clean-add/clean-apply path every prior upstream
  file has always used; see `.docs/guides/MIGRATION_GUIDE.md`
  § *How a 6.x install receives this*.
- Project-owned content checks are new: `.logic-loom/config/project-migrations.conf`
  is yours to write, LogicLoom ships none and makes no claim about your own
  project's text. A row there only ever proposes (`PROPOSE`) — never applies —
  the same as an upstream `content` row. See `.docs/guides/MIGRATION_GUIDE.md`
  § *The project-owned registry*.
- One **advisory** row ships (`PROPOSE-ADVISORY`), on
  `.logic-loom/memory/amendments.md`: an upstream suggestion about text
  your fork wrote — LogicLoom did not ship this text and says so on the
  item itself. It only ever proposes, never applies, fires in template and
  adopted installs alike, and produces nothing if the file or the matched
  line is absent. A row of this kind may name only `amendments.md`,
  `CLAUDE.md`, `CLAUDE.local.md` or `AGENTS.md`; `lint` rejects any other
  target. See `.docs/guides/MIGRATION_GUIDE.md` § *The advisory row*.
- Maintainer-only, tightened at the gate: `release-migrations.sh
  check-release --since auto` (or `--since <tag>`) now also fails a release
  that dropped a `plugins/<x>` or `mcp-servers/<x>` directory since the
  previous tag without a registry row declaring it — see
  `.docs/guides/MIGRATION_GUIDE.md` § *For maintainers*.

### Added

- **Release-migration registry** (`.logic-loom/config/release-migrations.conf`)
  and its parser lib (`.logic-loom/lib/release-migrations.sh`) — one grammar
  for a retired plugin/mcp-server/path, a moved path, a content check, or a
  release's `none` row, evaluated the same way for the upstream registry and
  a project-owned `.logic-loom/config/project-migrations.conf`.
- **`plugins/loom-maintenance/scripts/release-migrations.sh`** —
  `scan [--json]`, `plan <name>`, `convert <name> --dry-run|--apply
  [--customized-only]`, `lint`, and `check-release [<vX.Y.Z>]
  [--since <tag>|auto]` (the removal guard, maintainer-only).
- **`/update-framework` Step 3b / 4b / 7b** — the scan, the presentation
  (per-kind menu including `[m]ove` for a moved path), and the apply step,
  wired into both `plugins/loom-maintenance/commands/update-framework.md`
  and the `framework-updater` skill.
- **`plugins/loom-maintenance/scripts/record-update-writes.sh`** — records
  what an adopted install's `/update-framework` run just wrote; `--reconcile`
  proposes recording the past (`RECONCILE` vs `DIFFERS`, never auto-recording
  a file that differs from upstream).
- **`.docs/guides/MIGRATION_GUIDE.md`** — the registry, the four actions plus
  MOVE and PROPOSE, plugin-to-skill conversion, the decisions file, and the
  adopted-repo recorder, all in one place.
- **`.docs/policies/project-amendments-policy.md`** — the fork-amendments
  doctrine, moved out of `CLAUDE.md`.
- **`tests/contract/test_release_migrations.sh`** and
  **`tests/contract/test_update_framework_ownership.sh`** — registry
  integrity, the scan/convert fixtures, the release gate, and the
  adopted-repo recorder/reconcile fixtures. Precisely what runs where: both
  suites are registered in `tests/run_all_tests.sh` (the local full suite)
  and in `.github/workflows/plugin-tests.yml` (CI, every push); both are
  also in the promote gate's contract-suite list in
  `.github/workflows/promote-to-main.yml`.
- `plugin-tests.yml` checks out full history (`fetch-depth: 0`) so the
  release-removal and tag-consistency checks run with teeth on every push,
  not only at the cut.

### Fixed

- **Plugin-to-skill `convert` no longer recommends deleting `plugins/<x>`
  while any of its files are unaccounted for.** `convert_hooks_and_support`
  used to walk a fixed subtree list (`hooks`, `scripts`, `lib`, `config`,
  `templates`, `tests`, `README.md`) — any other plugin-root file or
  directory (a `LICENSE`, a `package.json`, a custom asset dir) was silently
  never converted, and `cmd_convert` still printed an unconditional "delete
  plugins/$name" regardless. `convert_hooks_and_support` now enumerates
  every plugin-root entry generically; the delete recommendation (and
  `CONVERTED.md`'s own Follow-ups line) is now gated on every real file
  under `plugins/<x>` — tracked, untracked, and gitignored — being provably
  converted or already ours, and otherwise names exactly what was not
  carried over instead of the delete step.
- **A `converted = <name>` decision no longer yields `REMOVE` while files
  were left behind.** `convert --apply` records the decision for the units
  it converted even when it had to withhold its own delete step (a
  non-`.md` file under `commands/`, a symlink, a STOP), and the next scan
  read the decision alone — decision commit found, plugin untouched since,
  all-`SKIP` re-render — as "delete when verified", recommending
  `git rm -r plugins/<name>` over bytes never carried into `.claude/`.
  The re-render now also has to report every file accounted for
  (`convert` prints a machine-stable `accounted:` line in both modes; the
  scan fails closed on its absence); otherwise the item is `KEEP-AS-IS` and
  names the leftovers, and the decisions briefing says the same.
- **Symlinks under `plugins/<x>` are never converted and never silently
  dropped from the accounting.** The unconverted-files check walked
  `-type f` (regular files only), so a customer's symlink — a root-level
  link to a shared-asset directory, a link inside `config/`, a dangling
  link — was neither converted nor listed, and the delete step was printed
  over it. Everything that is not a directory is now enumerated; a symlink
  is reported under *Not carried over* and the delete step is withheld.
- **The manifest and the plugin directory itself were still read through a
  symlink.** `-f`/`-d` follow links: a `.claude-plugin/plugin.json ->
  <outside file>` was copied into `plugin.json.orig`, mapped, counted as
  accounted, "delete plugins/<p>" printed and `converted =` recorded — the
  same class as the generic-entry fix above, on the one entry that loop
  skips by name; and a `plugins/<p>` that is itself a symlink had its whole
  outside target rendered into `.claude/`, a `CONVERTED.md` written for it
  and a decision recorded (`find "$plugin_dir/skills"` is a path *through*
  a link, which every tool resolves). A symlinked `.claude-plugin/`,
  `plugin.json`, `skills/`, `commands/` or `agents/` is now never read and
  is named under *Not carried over*; a symlinked `plugins/<p>` is refused
  up front (`STOP`, exit 2, nothing read or written, no decision).
- **A `skip-worktree` / `assume-unchanged` local edit no longer reads as
  pristine.** `git diff` and `git status` trust the index for an entry
  carrying either flag and never stat its working-tree file, so a tracked
  plugin file edited under one was invisible to every "unchanged since
  <commit>" test: scan said `REMOVE`, plan printed `git rm -r plugins/<p>`
  — and with `assume-unchanged`, running that command deletes the edited
  file outright (probed: git re-checks nothing it was told not to look
  at). `resolve_state` and the converted-plugin status now read
  `ls-files -v` and treat any `S`-tagged or lowercase-tagged entry as
  changed by construction (listed under `changed`, never the `pristine`
  branch), and the `changed:` reason names the flag.
- **`convert --dry-run` no longer prints the delete step.** Nothing was
  written, so "once its converted commands/skills work" could not yet
  hold; it now says so and points at `--apply`.
- **`convert` refuses to write through a symlink at a target.** Every
  "target already exists" guard is an `-e` test, false for a DANGLING link,
  so a `.claude/skills/<p>/SKILL.md -> <elsewhere>` link made `--apply`
  create the file wherever the link pointed — outside `.claude/`, outside
  the repository. A symlink at a target now ERRORs that unit (a failed
  write: no `converted =`, delete withheld); it is never followed,
  replaced or removed.
- **The registry parser rejects an empty field.** Every consumer reads a row
  back with `IFS=$'\t' read`, which collapses an empty field and shifts
  every later one left, so an unlinted project row with an empty name was
  read as name=`removed`, fate=`none`, …. `_loom_parse_row` now reports the
  empty field by name (a valid `none` row uses `-`) and no consumer ever
  sees a shifted row.
- **An option-shaped name (`-f`, `--cached`) is rejected at lint and at
  use.** `-` is in the name whitelist and quoting cannot help: `git rm '-f'`
  still hands git an option. `_loom_lint_name_shell_safe` rejects a leading
  `-` for `plugin`/`mcp-server`/`path` rows and their MOVE replacement
  paths, and `compute_recommendation` now applies that same check to the
  NAME field before building any command — closing the at-use half for an
  unlinted project registry (round 5 had it at lint time, and at use only
  for a MOVE row's replacement path).
- **The registry's `sha256:<hash>` adopt-receipt baseline is now
  corroborated, not merely trusted.** `.logicloom-adopt-receipt.json` is a
  plain, hand-editable file; a receipt-recorded digest now authorizes a
  `REMOVE` recommendation only when that exact digest also matches a blob
  LogicLoom itself shipped at that path in `refs/loom-upstream/main`'s own
  history — see `.docs/guides/MIGRATION_GUIDE.md` § *Trust boundary — the
  adopt receipt* for the full boundary this does and does not close.
- **Path- and shell-safety hardening in `release-migrations.sh` /
  `.logic-loom/lib/release-migrations.sh`**: a registry row's `name` (and,
  for a `path`-kind `renamed` row, its `path:<new>` replacement) is now
  rejected at lint time if it contains a bare `.` path segment or a
  character outside `[A-Za-z0-9._/-]`, with the same check re-applied at
  the point each is turned into a printed `git rm` / `git mv` command
  (defense-in-depth for an unlinted project registry); every path those
  printed commands embed is now shell-quoted, including a fix to
  `shell_quote` itself (its original `${s//...}` form emitted unbalanced
  quoting for an embedded `'`, which `eval` alone had rather than exposed a
  live registry value with); and the EXIT-trap cleanup for the
  `check-release` fixture-proof scratch tree refuses to remove a symlinked
  entry or anything outside its own `mktemp` base rather than a bare
  check-then-`rm -rf`.
- `loom_latest_tag_at_or_below` / `loom_latest_tag_below` filter tags with
  the same strict `^v[0-9]+\.[0-9]+\.[0-9]+$` shape lint and `--since`
  already require, instead of a loose `/^v[0-9]/` that let a tag like
  `v8.0.0-rc1` through and fed it to `_loom_version_num`.
- **A `convert` write that genuinely FAILS is no longer counted as
  accounted-for.** Every unit converter called `note_mapping` for a source
  path *before* attempting the write, unconditionally — a write that then
  failed (a symlinked target, a parent-directory symlink, a rewrite
  failure) left the source mapped anyway, so `unconverted_plugin_files` saw
  nothing missing and `CONVERTED.md`'s own Follow-ups section printed the
  unconditional delete line despite the failure (the terminal's `accounted:`
  line already caught this class via `WRITE_FAILED`; the on-disk record did
  not). `note_mapping` now runs only after a write succeeds (or for a
  pre-existing target / dry-run plan, which never write).
- **`write_text_target` / `copy_target` now refuse a symlinked PARENT
  directory component, not only the final target.** `mkdir -p` follows an
  existing symlinked intermediate directory and creates missing components
  inside whatever it points to; a `>` redirect / `cp -p` then follows the
  same chain — so a symlink at, say, `.claude/skills/<plugin>` itself sent
  every write for that plugin outside `.claude/skills/`, contradicting this
  script's own stated contract. Every existing path component from the
  target's parent up to the repo root is now checked.
- **`record_converted_decision` and the adopt-receipt writers
  (`record-update-writes.sh`, both JSON-tool backends) refuse a symlinked
  target** rather than writing through it — the same rule every other
  writer in this codebase already applied, closed here for the three sites
  that had not caught up.
- **The adopt-receipt writers now write atomically** (temp file, then a
  same-filesystem rename) instead of truncating the real file in place, so
  a crash or kill mid-write can no longer leave the one record the
  ownership-tracking system depends on as invalid/truncated JSON.
- **`record-update-writes.sh`'s `recorded` op (both backends) now validates
  a run's `generator` string** before trusting its `wrote` entries, the same
  `^(logicloom|logicloom-update-framework)@.+$` check
  `release-migrations.sh`'s own receipt-digest baseline already applied to
  the same hand-editable receipt. Previously only `status` was checked, so a
  hand-added run with a forged generator but a plausible status had its
  directory entries treated as framework-owned, and `--reconcile` could
  offer `RECONCILE` for a file under it that merely happened to be
  byte-identical to the sync-ref blob.
- **`_loom_rm_safe_to_remove` now refuses when the proof-tree BASE itself is
  a symlink**, not only an entry under it. The previous check canonicalized
  both the entry's parent and the base via `cd -P` and compared them — if
  the base were swapped for a symlink between creation and the EXIT-trap
  cleanup, both sides resolved through the same symlink and matched,
  routing `rm -rf` into whatever it pointed at. `[ -L "$base" ]` is now
  checked first, before any canonicalization.
- **`apply_path_rewrites` now checks `mktemp` and the `sed` pipeline
  explicitly** and falls back to the original, unrewritten content (never
  empty) on either failure, with an `ERROR` line on stderr — previously an
  `mktemp` failure fed `sed -f ""` an empty filename, and under this
  script's `-uo pipefail` (no `-e`, by design) the failure did not stop the
  caller, so the empty output was written, `WROTE`-logged, and counted as
  accounted-for. Every real call site was also fixed to check the function's
  own exit status explicitly (`|| WRITE_FAILED="true"`) rather than relying
  on a variable it sets internally — that mutation lives only in the
  forked subshell every `$(apply_path_rewrites …)` capture creates and was
  otherwise invisible to the caller.
- **`resolve_baseline`'s "recoverable" advice for a pristine `receipt-sha256`
  baseline no longer claims `git checkout HEAD -- $path` will restore a path
  that was never tracked at HEAD** (a baseline resolved purely from a
  receipt/upstream match, never committed to this repo). The advice now
  checks HEAD-tracking first and words itself accordingly; both printed
  paths are single-quoted so the advice still prints and copy-pastes
  correctly for a path containing a space.
- **An EMPTY directory under `plugins/<p>` is no longer invisible to
  `convert`'s accounting.** `find … ! -type d` enumerates regular files and
  symlinks only, so a directory holding nothing produced no entry at all —
  never converted, never listed as left behind, and the delete
  recommendation fired as if the plugin were fully accounted for. An empty
  directory holds zero bytes, so nothing was ever actually lost this way,
  but `git rm -r plugins/<p>` on that advice removed the directory entry
  with no record this tool had ever seen it. Every leaf-empty directory is
  now named alongside unconverted files, and the delete step withheld.
- **A `KEEP <target> modified-after-conversion` no longer counts its source
  as carried over.** (Reviewer round 2, residual of the `note_mapping`
  finding above.) The "target already exists" branch of every unit
  converter mapped its source and then classified the target — a KEEP means
  the target differs from what the plugin source renders to *now*, so the
  source's current bytes are provably not there (the source was edited
  after conversion, or the target was, or both; nothing is overwritten
  either way) — yet `convert --apply` still printed `accounted: every file
  … is carried over` and `Next steps: delete plugins/<p>`. Reproduced by
  converting, editing `plugins/<p>/hooks/h.sh`, and converting again: two
  KEEP lines, the edit nowhere under `.claude/`, and the delete step. scan
  already read any KEEP as render-stale / `KEEP-AS-IS`; `convert`'s own
  output now agrees: every KEEP is listed under *Not carried over by this
  run* with the target it differs from and "reconcile by hand, then
  decide", and both delete gates (the terminal line and `CONVERTED.md`'s
  Follow-ups) withhold on it. An unedited re-run (all `SKIP`) is unchanged.
- **A `#` or `[` in the checkout path no longer blinds `convert`'s unit
  planner and accounting.** (Reviewer round 2.) `plan_convert_units` and
  `unconverted_plugin_files` stripped `$REPO_ROOT` with
  `sed "s#^$REPO_ROOT/##"` — a `#` in the path is that expression's
  delimiter, a `[` opens an unbalanced bracket expression, and either way
  sed errored with EMPTY output under `-uo pipefail` (no `-e`). No skill,
  command or agent unit was converted at all (only hooks/support, which
  used parameter expansion), the accounting saw zero files under
  `plugins/<p>`, the positive `accounted:` line fired, `converted =` was
  recorded, and the next scan said `REMOVE` with `git rm -r plugins/<p>`
  over a skill never carried into `.claude/` — reproduced for both
  characters. Every such prefix is now stripped by parameter expansion
  (`_loom_rm_strip_prefix`; `owning_plugin_name` and `content_matches`
  too), and `unconverted_plugin_files` now also fails closed when `find`
  itself exits non-zero — a subdirectory under `plugins/<p>` it cannot read
  used to yield a silently partial listing that read as complete; it now
  names the directory as unverifiable and withholds the delete step.
- **`CONVERTED.md`'s Follow-ups take the same delete gate as the
  terminal.** (Reviewer round 2, the on-disk half of the `note_mapping`
  finding.) The record gated its Follow-ups on unconverted files alone,
  while the terminal also required nothing STOPped and no write failed — so
  a run whose every unit was mapped but whose rewrite step failed
  (`apply_path_rewrites` → `WRITE_FAILED`; files written UNREWRITTEN) had the
  terminal say `DO NOT delete` and the file, the one a user may read later
  on its own, say `delete plugins/<p>`. `cmd_convert` now hands the run's
  STOP/failed state to the renderer before the record is written; a record
  written by a failed run says so and names the reason.
- **The adopt-receipt writers never write through a symlink planted at
  their own temp-file name.** (Reviewer round 2, residual of the
  atomic-write finding above.) The temp name is predictable
  (`<receipt>.tmp<pid>`) and both JSON helpers created it with a plain
  `open(…, 'w')` / `fs.writeFileSync`, which follow an existing symlink at
  that name — reproduced by planting `<receipt>.tmp<pid> -> <victim>`: the
  receipt JSON was written through the link, truncating a file this tool
  never created, and the rename then moved the link itself over the
  receipt. Both helpers now open the temp file `O_CREAT|O_EXCL` (`'wx'`),
  which fails on any pre-existing entry, symlink included, and refuse
  loudly; a failed write also unlinks its own half-written temp file.
- **A symlink to a FILE at a plugin's root (a `LICENSE` pointed elsewhere,
  say) is no longer silently converted.** `convert_hooks_and_support`'s
  `[ -d "$srcpath" ]` is false for a link-to-file, so the `else` branch set
  `files="$srcpath"` — the link path itself, read via `cat`/`copy_target`
  exactly like a real file and counted as carried over, contradicting this
  tool's own documented contract that a symlink anywhere under
  `plugins/<p>` is never converted. (A link-to-*directory* at plugin root
  was already safe, by an accident of how `find <link> -type f` does not
  descend past a link given as its own start point — this closes the
  file case explicitly, for both.)
- **A symlink named `*.md` directly under a plugin's `commands/` or
  `agents/` is no longer silently converted.** `plan_convert_units`'s
  `find … -name '*.md'` for `COMMAND_UNITS`/`AGENT_UNITS` had no `-type f`,
  so it matched a symlink by basename exactly like a real file; both unit
  converters `cat` their source unconditionally, so the link's target
  content was read through and written into `.claude/skills/<cmd>/SKILL.md`
  or `.claude/agents/<agent>.md`, counted as accounted-for. Both finds now
  require `-type f`; `convert_command_unit`/`convert_agent_unit` also
  refuse a symlinked source directly, defense-in-depth against a future
  caller that bypasses the unit list.
- **`record-update-writes.sh`'s `recorded` op (both backends) no longer
  trusts a `partial`/`in-progress` run's `wrote` entries as already
  framework-owned.** `release-migrations.sh`'s own baseline digest reader
  already restricts trust to `status == 'complete'` — a run that never
  finished is not vouching for the bytes it left behind — but this op
  accepted `('complete', 'partial', 'in-progress')` for the same
  adopter-editable receipt, an internal inconsistency between two pieces of
  receipt-trust logic tightened in the same PR. Both now match: `complete`
  only.
- **The adopt-receipt's stale-`uninstall`-marker text no longer claims
  every `kind:dir` entry is "a directory it created."** `build_entries`
  records every not-yet-recorded ancestor directory of a written file
  unconditionally, with no check for whether that directory already
  existed independent of this run (a customer's own pre-existing directory
  that happens to also receive one LogicLoom-written file is recorded the
  same as one this run's first write brought into being). The marker text
  (both JSON-tool backends, kept byte-identical) now says what a `kind:dir`
  entry actually means: the directory holds a LogicLoom-written file, never
  a claim of having created or owning the directory itself.
- **`CONVERTED.md` now says, in its own text, that it can go stale.**
  `finalize_convert` deliberately writes this record once, at conversion
  time, and never rewrites an existing one — its creation commit is the
  conversion decision, tamper-evident dating the removal gate relies on.
  The LIVE recommendation (`scan`/`plan`) already re-renders fresh and
  never trusts this file's on-disk text, but a human who opens it directly
  after a later edit to the plugin could still read an unqualified
  "delete" line as current. The rendered file now says up front that it is
  written once and may be stale, and to re-run `scan --json`/`plan` for
  the current recommendation.
- **`build_entries` no longer records a wide ancestor directory as
  `kind:dir` when it also holds git-tracked content this run cannot
  account for.** The round-3 fix above corrected the stale-marker's PROSE
  only; the recording behavior it described was unchanged, so a
  `kind:dir` entry still widened `--reconcile`'s `git ls-files -- "$d"`
  sweep to every file under a directory the run never actually wrote into
  — up to a repo-root-adjacent directory like `plugins/` or `.claude/`,
  since `path_ancestors` walks every level. `build_entries` now claims a
  directory only when every git-tracked file under it, right now, is
  either already recorded or being recorded in this same call
  (`_dir_is_fully_accounted`); a directory that also holds other,
  unaccounted content is left unrecorded, narrowing future
  `--reconcile` scope without touching the (separately-owned, unfiltered)
  npm installer's own full-tree recording.
- **`--reconcile`'s directory sweep now corroborates a `kind:"dir"` receipt
  entry against `refs/loom-upstream/main`'s own tree history before trusting
  it.** A `kind:"file"` entry carries a `sha256` verified against a real
  blob before anything is recorded; a `kind:"dir"` entry carries no hash, so
  a plausible-but-forged `generator` string in the same hand-editable
  receipt (`TRUSTED_GENERATOR_RE` checks shape, not authorship) was the only
  gate on a directory claim. New `loom_upstream_ever_had_dir`
  (`.logic-loom/lib/release-migrations.sh`) requires the claimed path to
  have genuinely been a tree somewhere in `refs/loom-upstream/main`'s
  reachable history; an uncorroborated `kind:"dir"` entry is dropped from
  the sweep, silently, without refusing the rest of the run.
- **A pre-existing `.claude/` target that is a symlink is now refused, not
  read through.** The write path (`write_text_target`/`copy_target`) has
  always refused a symlinked target via `_loom_rm_refuse_symlink_target`;
  the seven "target already exists" branches (skills, commands, agents, the
  generic plugin-root loop, the `.claude-plugin/plugin.json` manifest, the
  support index, `CONVERTED.md`) tested only `[ -e ]`, which follows a
  symlink, so a non-dangling symlinked target was classified/read straight
  through it and marked "accounted for" without ever noticing the target
  itself is a link. All seven now refuse it the same way a write does
  (`_loom_rm_refuse_existing_symlink_target`).
- **`record_converted_decision` now checks the FULL ancestor chain of the
  decisions file for a symlink, not only its immediate parent.**
  `.logic-loom/config/migration-decisions.conf` is two levels below
  `REPO_ROOT`; the old check tested only `.logic-loom/config`, so a symlink
  planted at `.logic-loom` itself — one level further up — went unchecked
  and the `>>` append (or the initial header write) would still follow it.
  Walks every component up to (not including) `REPO_ROOT`, the same rule
  `_loom_rm_refuse_symlink_parents` already applies on the write path for
  `.claude/skills/`/`.claude/agents/` targets.
- **`build_rewrite_sed` now escapes skill/command/agent/plugin names before
  interpolating them into generated `sed s|pattern|replacement|g` lines.**
  A name containing a BRE metacharacter (`. * [ ^ $`), the delimiter (`|`),
  or a replacement-side special (`&`, `\`) used to silently change what the
  generated rewrite matched or inserted, while the unit was still written
  and mapped as "accounted for." Unit/plugin names are conventionally
  kebab-case, so this rarely fired in practice — the gap is closed
  regardless.
- **`--reconcile`'s sync-ref blob extraction no longer misclassifies a
  failed read as a byte-identical match.** `git cat-file -p` was piped into
  a temp file with its own failure swallowed by `|| true`; the `>`
  redirect creates/truncates that file regardless of whether the command
  succeeds, so a failed extraction (after the preceding existence check
  passed) left an empty temp file that `cmp` could report as identical to
  a genuinely-empty on-disk file. The command's own exit status is now
  checked explicitly; a failed extraction is skipped — neither `RECONCILE`
  nor `DIFFERS` — instead of silently proven.
- Two stale comments corrected to match the code next to them: a
  trust-boundary comment on the receipt-recorded `sha256` baseline no
  longer claims "an adopter cannot forge this" a few dozen lines above the
  comment that spells out exactly how one can (both now point at the same,
  accurate story); and the registry-row parser's traversal-rejection
  messages now name the bare `.` segment `loom_path_traversal_safe` has
  always also rejected, not only `..`.
- **`build_entries` records the ancestors of a MULTI-file write again.**
  (Round-4 reviewer; a regression of the finding-3 narrowing directly
  above.) `_dir_is_fully_accounted` reads the call's entries file to decide
  whether every tracked file under a directory is accounted for, so it only
  saw entries written before it ran; the single interleaved pass (file, its
  ancestors, next file, …) judged `plugins/loom-git/commands/` while the
  sibling's entry did not exist yet, refused it, parked it in `seen_dirs`,
  and never asked again. Recording two files in one call — exactly how
  `/update-framework` invokes the recorder (`--version V <each written
  path>`) and how `--reconcile --apply` records every `RECONCILE` path —
  therefore recorded **no** ancestor directory at all, reopening the rot gap
  the script exists to close (a later upstream `A` under that directory
  would fail the ancestor rule silently, forever). Every file entry is now
  written first and directories are judged second, against the whole
  call; `plugins/` itself is still left unrecorded when a sibling subtree
  holds unaccounted content.
- **`--reconcile` no longer lists or records an index path that goes
  through a symlinked directory.** (Round-4 reviewer.) Candidates come from
  `git ls-files` — index paths — and the per-candidate check tested `-L`/`-f`
  on the final component only, which follow a symlinked *ancestor*: a
  recorded directory the adopter had replaced (unstaged) with a symlink to
  a directory elsewhere — reproduced with one outside the repository — still
  listed its old index paths, `cmp`'d the bytes on the far side of the link,
  printed `RECONCILE`, and `--apply` recorded the index path with the
  upstream digest (the receipt's later "digest matches → delete" step would
  then unlink the file *at the link's target*). Record mode already refused
  the same path (`canon_path` resolves the parent with `pwd -P` and rejects
  anything outside the root); `--reconcile` now applies the same rule and
  skips such a candidate loudly on stderr — neither `RECONCILE` nor
  `DIFFERS`, nothing about it is decided.
- **`convert` refuses to classify an existing target through a symlinked
  PARENT directory, not only a symlinked target.** (Round-4 reviewer; the
  round-4 `_loom_rm_refuse_existing_symlink_target` fix above checked the
  final component only, and `[ -e ]` follows a symlinked parent just as
  readily.) With `.claude/skills/<skill>` and `.claude/skills/<p>` replaced
  by symlinks to a directory outside the repository holding a previously
  converted copy, a re-run classified every file `SKIP` through the links,
  mapped them, printed `accounted: every file … is carried over` and `Next
  steps: delete plugins/<p>`, and `scan` said `REMOVE` — while the only
  in-repo home of those bytes was a symlink into an unversioned directory.
  The classify path now walks every existing component up to the repo root
  (the rule the write path has applied since round 2 and
  `MIGRATION_GUIDE.md` already stated), ERRORs naming the parent link,
  withholds the delete step, and the next `scan` reads the item as
  `KEEP-AS-IS`. The same guard now also covers the eighth "target already
  exists" read, `append_marked_section` (a command appended into its home
  skill, and the support-index append), which was previously refused only
  transitively via the skill unit's own check on the same file.
- **`record-update-writes.sh`'s directory-accounting check no longer reads
  a FAILED `git ls-files` as "the directory holds nothing."** (Round-5
  reviewer, high.) `_dir_is_fully_accounted` fed its accounting loop
  straight from `git ls-files -z ... || true`; a nonzero exit (a
  permission issue, a corrupted object, anything) was masked by `|| true`,
  which the loop could not tell apart from a directory that legitimately
  enumerates to zero tracked files — either way it fell through to "fully
  accounted," licensing a `kind:"dir"` receipt entry (and later a
  `--reconcile` sweep of that whole subtree) from an enumeration that
  never actually completed. The exact same fail-open class
  `unconverted_plugin_files` (`release-migrations.sh`) was already closed
  for a failed `find` a few rounds ago; this closes the matching gap in
  the recorder's own directory check. The listing is now captured to a
  temp file first, with git's real exit status checked before the loop
  ever runs; a failed enumeration refuses the directory outright instead
  of claiming it.
- **The registry row parser now rejects a field containing a literal TAB
  byte.** (Round-5 reviewer.) `loom_migration_rows`/`loom_deprecation_rows`
  re-serialize every row TAB-joined, and every consumer re-splits it with
  `IFS=$'\t' read`; a field that itself contained an embedded tab produced
  one extra tab boundary on that line, shifting every field after it one
  column to the left on read-back — the same corruption class as an empty
  field between two pipes (closed a few rounds ago), just triggered from
  inside a field instead of between two. `_loom_parse_row` now rejects an
  embedded tab in any of the 8 fields, named by field, the same place the
  empty-field and path-traversal checks already run.
- **A customer's own symlink at a receipt-recorded path is no longer read
  as "pristine."** (Round-5 reviewer.) `_loom_rm_sha256_file`'s `[ -f ]`
  test and Python's `open()` both dereference a symlink; a symlink whose
  TARGET happened to byte-match a receipt-recorded digest read back as
  pristine, and `resolve_baseline`/`resolve_state` could then drive a
  `REMOVE` recommendation whose `git rm` deletes the symlink entry itself
  — a path this tool never created — purely because of where it happens to
  point. `_loom_rm_sha256_file` now refuses a symlink outright; both
  callers already treat its failure as "cannot confirm pristine," so
  refusing there is enough — no other code path to touch.
- **Three unquoted `for x in $LIST` unit loops (skill/command/agent names)
  are now `while IFS= read -r`.** (Round-5 reviewer, low.) An unquoted
  `for` both word-splits a unit name containing whitespace into multiple
  bogus iterations and glob-expands each resulting word against files in
  `$PWD`; the lists in question are newline-per-entry by construction, so
  `while read` is both the correct delimiter and immune to glob expansion
  — the NUL/newline-safe-loop idiom this same diff already uses elsewhere.
  `unit_touched()`'s ERE `grep -E` match on an interpolated path is
  likewise replaced with a literal `case` comparison, so a plugin/unit name
  containing a regex metacharacter can no longer be misread as pattern
  syntax.
- **The registry row parser no longer silently accepts a trailing empty
  9th field.** (Round-5 reviewer, low.) A row ending in a stray extra `|`
  produces a 9-field-shaped row whose 9th field is empty; `read` cannot
  tell that apart from a genuine 8-field row (both leave the 9th variable
  empty), so the old `[ -n "$f9" ]` check alone let it through, silently
  contradicting the documented "exactly 8 pipe-separated fields" grammar.
  The parser now counts the real `|` delimiters directly (escaped `\|`
  already decoded out of the count) and requires exactly 7.
- **`record-update-writes.sh` now warns when it cannot determine a
  framework version.** (Round-5 reviewer, low.) With no `--version` given
  and no `FRAMEWORK_VERSION` in `.logic-loom/config/architecture.conf`,
  the empty version flowed into the new run's `generator` string as
  `logicloom-update-framework@` (nothing after the `@`) — a shape
  `TRUSTED_GENERATOR_RE` was always going to reject on every later read
  (fail-safe, never fail-open), but the command still printed `RECORDED`
  lines and exited 0 with no hint the run it just wrote could never be
  corroborated. Both actual-write call sites (record mode and
  `--reconcile --apply`) now print a warning naming the reason and the
  fix, without changing behavior otherwise — still records, still exits 0.
- **The printed/apply `MOVE` command's destination guard now also catches
  a DANGLING symlink at the destination.** (Round-5 reviewer, low.) `-e`
  alone is false for a symlink whose target does not exist, so this tool's
  own friendly refusal message did not fire for that case — the command
  fell through to a bare `git mv`, which independently refuses to
  overwrite an existing lstat entry (including a dangling symlink), so no
  path was ever actually overwritten either way. `[ -e ] || [ -L ]` closes
  the diagnostic gap: the same friendly message now fires for a dangling
  symlink too, not only a real file.
- **A receipt-sha256 baseline never reads a file behind a SYMLINKED PARENT
  directory as pristine.** (Round-5 reviewer, high, data-loss.) The round-5
  `[ -L ]` guard in `_loom_rm_sha256_file` checked the final component
  only; `[ -f ]` and `open()` resolve a symlink at any parent just as
  readily, so `docs -> <directory outside the repository>` with a
  byte-identical `docs/old-note.md` on its far side hashed clean, the
  receipt candidate won in `resolve_baseline` (a receipt match beats a
  stale sync-ref by design), `resolve_state` read it as pristine, and
  `scan`/`plan` printed `git rm 'docs/old-note.md'` — running which, in the
  reproduction, DELETED the file at the link's target, outside the
  repository (`git rm` unlinks by path; the kernel resolves the directory
  link). git's own diff already reports a tracked file behind a symlinked
  leading path as deleted, so the sync-ref/upstream baselines were safe;
  the receipt route never asked git. `resolve_state` now treats a symlinked
  ancestor as customized for every baseline kind (the ancestor is named
  under `changed`), and `_loom_rm_sha256_file` refuses to hash through one
  at all.
- **A nested git repository under `plugins/<p>` is never pristine, never
  converted, and always withholds the delete step.** (Round-5 reviewer,
  medium.) A `.git` directory (the customer ran `git init` inside a retired
  plugin to keep their own history of it) or a `.git` gitdir-pointer file
  (what `git worktree` writes) is invisible to the outer repository's git:
  `ls-files --others` lists nothing under a nested repository and `diff`
  stays clean, so `scan` said pristine and `plan` printed
  `git rm -r 'plugins/<p>'` over history nobody but the customer owns.
  `convert --apply` then carried `.git/**` into `.claude/skills/<p>/.git/`
  — a `WROTE` line per hook sample, `HEAD`, `config`, the object store —
  which makes `.claude/skills/<p>` an embedded repository the outer tree
  can only ever hold as a 160000 gitlink (reproduced: `git add .claude`
  warned "adding embedded git repository"), and for the pointer-file
  variant printed `accounted: every file … carried over` and the delete
  step outright. `resolve_state` (and the `converted =` status check) now
  list a nested `.git` under `added`; every converter walk prunes `.git`
  by name; `unconverted_plugin_files` reports it once, by name, so both
  delete gates withhold.
- **A subdirectory under `plugins/<p>` the scan cannot read is never
  pristine.** (Round-5 reviewer, medium.) `git ls-files --others` (with or
  without `--ignored`) lists nothing under a directory it cannot open and
  still exits 0, and `diff` is clean, so an untracked mode-000 directory
  holding a customer's file read as pristine / REMOVE with `added_files`
  empty. `resolve_state` now runs the same enumeration check
  `unconverted_plugin_files` already applies (reviewer round 2: "an
  enumeration that did not complete proves nothing about the tree") and
  lists the directory under `added` as not fully enumerable.
- **`record-update-writes.sh` hands directory names to git as literal
  pathspecs.** (Round-5 reviewer, low, residual of finding 3.) A directory
  name beginning with `:` is pathspec magic to git (`:colon` parses as the
  pattern `colon`), so `_dir_is_fully_accounted`'s `ls-files -z -- ':colon'`
  listed nothing with exit status 0 — the exact "empty, well-formed
  directory" shape the finding-3 exit-status check passes — and `:colon/`
  was recorded as fully accounted while a tracked, unrecorded sibling sat
  under it; `--reconcile` then swept and corroborated nothing for such a
  directory. Every pathspec built from a directory name
  (`_dir_is_fully_accounted`, the `--reconcile` sweep,
  `loom_upstream_ever_had_dir` in the shared lib and the recorder's
  fallback copy) is now `:(literal)<name>`; an empty name is refused
  rather than let `:(literal)` alone match the whole tree.
- **`write_text_target`'s executable-bit preservation is now a checked
  write, not a fire-and-forget one.** (Round-6 reviewer, medium.) A
  converted command/skill/agent/hook file's `chmod +x` (preserving the
  source's own +x bit, since the `>` redirect that writes the content never
  carries a mode over) had no exit-status check, and the function still
  `return 0`'d — the caller printed `WROTE`, recorded the mapping, and
  `unconverted_plugin_files` counted the source as carried over, even
  though the target on disk was not runnable. A failed `chmod +x` is now
  treated as a failed write (`ERROR`, `WRITE_FAILED=true`, unit STOPs, the
  source is reported under *Not carried over*), matching this file's own
  header claim that every write is checked explicitly.
- **A failed `git ls-files` enumeration in `resolve_state` /
  `_loom_rm_index_hidden_paths` / `_loom_rm_converted_plugin_status` no
  longer reads as "nothing hidden, nothing untracked."** (Round-6
  reviewer, high, data-loss.) All three collapsed a FAILED listing
  (permission issue, corrupt index, anything that makes `ls-files` exit
  non-zero) to the same empty output a genuinely clean result produces —
  `_loom_rm_index_hidden_paths` threw its own exit status away with an
  unconditional `return 0`, and `resolve_state`'s untracked/ignored
  captures used `|| var=""`. The pristine test that follows cannot tell a
  failed enumeration from a clean one, so a failed listing could drive a
  `pristine` state and a `REMOVE` recommendation over a path this run
  never actually verified. All three now check the real exit status and
  refuse the path (`resolve_state`: `customized`, naming the failure;
  `_loom_rm_converted_plugin_status`: `changed:<commit>`, the same "doubt"
  branch an actual untracked file already takes) rather than fall through.
- **`content_matches`' glob branch no longer reports success when its
  `find` pipeline fails partway.** (Round-6 reviewer, medium.) Same class
  as the two findings above, on a lower-stakes path: an unconditional
  `return 0` made a `find` that failed on an unreadable subdirectory
  indistinguishable from "the glob legitimately matched nothing," so
  `check-release`'s content-row after-proof silently reported "no shipped
  current copy — after-proof skipped" for a row it never actually could
  check, and `emit_content_item`'s scan-time detection silently dropped
  the row. `content_matches` now propagates `find`'s real exit status;
  `check-release` fails loudly instead of skipping, and `emit_content_item`
  warns on stderr (that call site's stdout is scan/plan's own item output,
  so a new failure signal there would have meant a schema change — see the
  code comment for why a stderr warning was chosen over that).
- **`--root` as the last, valueless argument no longer hangs every
  subcommand's argument parser forever.** (Round-6 reviewer, low.) Each of
  `lint`/`scan`/`plan`/`check-release`/`convert`'s option loop had
  `--root) shift 2 ;;` — bash's `shift N` with `N > $#` is a silent no-op
  (unlike referencing `$2` directly, which `set -u` would have caught), so
  with no value after `--root`, `$1` stayed `--root` forever and the
  `while [ $# -gt 0 ]` loop never exited. Each site now checks `$# -ge 2`
  first and reports a usage error (`--root requires a value`) instead of
  looping.
- **The pristine test no longer defers to the customer's own diff
  helpers.** (Round-6 REVIEWER, high — governing principle.) `git diff
  --quiet` consults `GIT_EXTERNAL_DIFF`, `diff.external` and a
  `.gitattributes` `diff=<driver>` (`command` or `textconv`), and when the
  helper's exit code is trusted (`GIT_EXTERNAL_DIFF_TRUST_EXIT_CODE`,
  `diff.trustExitCode`, `diff.<driver>.trustExitCode`; a lossy `textconv`
  needs none of these) takes the helper's "no difference" over its own
  blob compare. Reproduced on git 2.54 with an edited tracked file under
  every one of those routes: `state: pristine`, `changed_files: []`,
  `REMOVE`, `git rm -r plugins/<p>` printed over a customer edit, plus the
  plan's "removing a pristine path never loses bytes" line (`git rm`
  itself then refuses the modified file, so the printed command stops
  short of deleting — the wrong recommendation is the harm). None of
  those settings is a misconfiguration. Every `git diff` in
  `release-migrations.sh` (the pristine test, its `--name-status`, the
  converted-plugin "unchanged since the decision commit" test, and
  `check-release`'s surface count) now passes `--no-ext-diff
  --no-textconv`; a source pin in the contract suite holds every call site
  to it. `extract-proposals.sh` runs the same shape of `git diff --quiet`
  for its conflict-review classification and is outside this change's
  file scope — noted for the next pass, not fixed here.
- **`convert` no longer hangs on a named pipe at plugin root.** (Round-6
  REVIEWER, medium.) `convert_hooks_and_support`'s generic plugin-root
  walk treated every non-directory, non-symlink entry as a regular file
  and ran `grep -Iq .` on it to decide text-vs-binary; on a FIFO that
  `open()` blocks until a writer appears — forever — and killing the
  convert left the `grep` orphaned, still blocked on the pipe
  (reproduced). Only a regular file is converted from the plugin root
  now; a pipe, socket or device node is never opened and is reported by
  `unconverted_plugin_files` under *Not carried over* (the delete step
  is withheld), the same contract a symlink already has.
- **`scan` no longer reads a plugin holding a special file or an empty
  directory as pristine.** (Round-6 REVIEWER, low — parity with the
  round-2 empty-directory finding, which closed this on the convert side
  only.) git's directory walker drops every entry that is not a regular
  file, symlink or directory, and tracks no directories at all, so
  `plugins/<p>/commands/customer.pipe` and an empty `plugins/<p>/scratch/`
  were in no listing: `state: pristine`, `added_files: []`, `REMOVE`
  (reproduced for both). `git rm -r` leaves both behind, so no bytes were
  at stake — but the recommendation claimed the path holds nothing but
  LogicLoom's bytes. `_loom_rm_git_blind_spots` (read by both
  `resolve_state` and the converted-plugin status) now lists both under
  `added`, so the item is customized and the user is asked.
- **`tests/contract/test_release_migrations.sh` no longer depends on GNU
  `timeout`.** (Round-6 REVIEWER, test portability.) The round-6 `--root`
  hang regression test called `timeout 10 …`, which stock macOS does not
  ship (it came from Homebrew coreutils on the machine that wrote it);
  without it every assertion in that block failed with rc 127 rather
  than skipping. Replaced by a pure-bash watchdog
  (`rv6_run_with_timeout`), also used by the new FIFO regression test.
  Its E4 scratch files now live under the suite's own `mktemp -d` root
  instead of `/tmp`.
- **A re-run of `convert --apply` over an edited plugin now says its
  on-disk `CONVERTED.md` is stale.** (Loop round 1, low.) The file is still
  never rewritten (ledger stability, and it may be the customer's own
  edit), but when its Follow-ups still say `delete plugins/<p>` while the
  run's own fresh render says DO NOT delete, the run prints a `NOTE
  .claude/skills/<p>/CONVERTED.md: STALE …` line pointing at `scan
  --json`. Scan/plan's re-render gate only keys off `KEEP`/`WRITE`/…
  lines, so the note cannot change a recommendation.
- **`--registry` / `--since` with no value now fail with a usage error**
  like `--root` does, instead of a raw `$2: unbound variable` shell error.
- **The EXIT cleanup no longer `rm -rf`s a proof base it cannot vouch
  for.** (Loop round 1, low — the race itself is inherent to portable
  bash.) The base must still be a non-symlink directory named like the
  `mktemp` template and owned by the current user, or it is left alone.
- **The pristine test no longer reads the working tree through the
  customer's git clean filter.** (Loop round 1 REVIEWER, high — governing
  principle.) `git diff --quiet <base> -- <path>` compares the base blob
  against the working-tree file as git reads it — through a
  `filter=<driver>` attribute's `clean` command — so an edit the filter
  strips (a notebook's re-run cell outputs under nbstripout, a value a
  redaction filter blanks; git-lfs and git-crypt are the same mechanism)
  hashes straight back to the tracked blob. Reproduced on git 2.54 with
  the attribute in `.git/info/attributes` (nothing in the working tree)
  and again committed in `.gitattributes`: `state: pristine`,
  `changed_files: []`, `REMOVE`, `git rm -r plugins/<p>` printed over the
  edit. The round-6 `--no-ext-diff --no-textconv` fix does not reach this
  — a clean filter is content conversion, not a diff helper — and `git
  rm` refused the file in the reproduction only because its size changed
  (read-cache.c's `sd_size` shortcut), so a same-size edit would not even
  be refused. `_loom_rm_filtered_paths` (read-only `git ls-files -z |
  check-attr -z --stdin filter`) now lists every tracked file under the
  item that carries a `filter` value other than `unspecified`/`unset`;
  both blob-compare sites — `resolve_state`'s pristine test and the
  converted-plugin "unchanged since the decision commit" test — treat any
  such file as customized (listed under `changed`, driver named), and a
  `check-attr` that cannot run refuses the path rather than reading as
  "no filter applies". Pinned by `tests/contract/test_release_migrations.sh`
  ("F4"), including controls that a `-filter` (unset) attribute and the
  unspecified default still scan pristine.

### Known issues (accepted, documented tradeoffs — not fixed this round)

- **A mode-only change is not a customization.** With `core.fileMode`
  false (the default on some Windows checkouts), a `chmod` on a tracked
  file under a deprecated path is invisible to `git diff`, and the item
  still reads pristine — no bytes differ, and the printed `git rm` loses
  none, so this is left as-is.
- **Line-ending normalization is not a customization.** (Loop round 1
  REVIEWER, low, reproduced.) With `text=auto` / `core.autocrlf`, a tracked
  file under a deprecated path converted to CRLF on disk still reads
  pristine: git normalizes line endings when it reads the working tree, and
  the printed `git rm` deletes the CRLF copy. That is git's own content
  model (the LF blob is the content; the CRLF form is a checkout
  rendering, recoverable by checking out again with the same settings), so
  it is left as-is — unlike a `filter=<driver>` clean filter, which can
  strip arbitrary bytes and is now refused (see *Fixed* above).
- **A plugin skill that ships its own `CONVERTED.md`** (`plugins/<p>/skills/
  <p>/CONVERTED.md`) lands at `.claude/skills/<p>/CONVERTED.md`, the path
  the conversion ledger uses, so the ledger itself is never written for
  that plugin (`finalize_convert` classifies the existing file `KEEP`) while
  the run still prints the delete step — every byte WAS carried over, so
  nothing is at risk, and the next `scan` reports `render-stale` /
  KEEP-AS-IS rather than REMOVE. (Loop round 1 REVIEWER, low.) Not changed
  this round.
- **A converted plugin whose skill shares the plugin's name AND has
  support assets never reaches "unchanged".** (Round-6 REVIEWER, low,
  pre-existing, fail-safe.) `convert_support_index` appends its
  marker-delimited index section into that skill's `.claude/skills/<p>/
  SKILL.md`; every later re-render classifies that file `KEEP
  modified-after-conversion` (the skill unit renders the source without
  the appended section), so `scan`/`plan` report `render-stale` /
  KEEP-AS-IS forever — a false "reconcile by hand" rather than the REMOVE
  a clean conversion earned. Doubt → KEEP, so nothing is at risk; the
  classify step would need to compare against the rendered content plus
  the index section to clear it. Not changed this round.
- **`convert --apply --customized-only` on a plugin with nothing touched
  still records `converted = <name>`** while its own output says `DO NOT
  delete` (nothing was carried over). Harmless in effect — the read side
  (`_loom_rm_converted_plugin_status`) requires a fresh, all-SKIP,
  positively-accounted re-render before that decision can ever mean
  REMOVE, so the next scan says KEEP-AS-IS — but the decision line
  overstates what that run did. Not changed this round.

- **`CONVERTED.md` is written once and never rewritten**, by design (see
  `render_converted_md`'s own comment and its on-page disclaimer) — after a
  plugin source is edited and `convert --apply` re-run, the file on disk
  can still show a stale "delete `plugins/<x>`" line even though
  `scan`/`plan` (the live, authoritative path) already report
  `KEEP-AS-IS`. The re-run itself now prints a `NOTE … STALE` line when
  that contradiction exists (see above); the file stays frozen. Pinned by
  `tests/contract/test_release_migrations.sh` ("Round-4 finding 5", "F2").
- **A run recorded with no resolvable framework version** (no `--version`,
  no `FRAMEWORK_VERSION` in `architecture.conf`) still writes a receipt
  entry whose `generator` is `logicloom-update-framework@` (nothing after
  the `@`) — `TRUSTED_GENERATOR_RE` was always going to refuse that shape
  on every later read, so the write is fail-safe by construction, not
  fail-open; `record-update-writes.sh` now WARNS on stderr at both write
  call sites instead of failing silently. Pinned by
  `tests/contract/test_update_framework_ownership.sh` ("Round-5 finding
  8").
- **Ownership is inferred from byte equality corroborated against
  `refs/loom-upstream/main`, not cryptographically proven** —
  `.logicloom-adopt-receipt.json`, `.sdd-sync-ref` and
  `refs/loom-upstream/main` are plain, hand-editable local git state, and
  none of them is signed. `.docs/guides/MIGRATION_GUIDE.md` § *Trust
  boundary — the adopt receipt* states this plainly and bounds the
  practical impact (never an automatic delete; `--reconcile` only ever
  proposes, gated behind an explicit `--apply`).

### Changed

- `tests/contract/test_deprecation.sh`, `tests/contract/test_bash32_floor.sh`,
  `tests/contract/plugins/test_plugin_lifecycle.sh`,
  `tests/contract/test_plugin_manifest_schema.sh`,
  `tests/contract/test_model_agnostic.sh`, and
  `.logic-loom/scripts/python/validate-plugin-manifests.py` now treat a
  registry-listed legacy plugin as a pending-migration notice on a customer
  tree instead of a hard failure; the maintainer-tree absence guarantee moved
  to `test_release_migrations.sh`.
- `.logic-loom/scripts/bash/constitutional-check.sh` distinguishes a
  converted project-local skill (carries the `converted-from:` marker) from
  one without provenance.
- `extract-proposals.sh` names the suppressed not-installed-here paths on
  stderr (first 20, then a count) with the `--reconcile` hint, instead of a
  bare count.
- `record-update-writes.sh` deletes the receipt's cached `uninstall` key on
  every run it appends, instead of leaving it stale: `uninstall` is derived
  fresh from the complete `runs[]` by `packaging/adopt/lib/apply.js`'s
  `uninstallProcedure()` (`packaging` itself never ships to an adopted
  repo), and a cached list computed before this run's append cannot name a
  path this run just recorded. A file `/update-framework` added or
  reconciled is covered by `uninstall.remove.files` /
  `uninstall.remove.dirsIfEmpty` again the next time the adopter runs
  `npx logicloom init . --apply --only=<the targets you installed>`
  (`--only` is required with `--apply`; over an installed tree it is a
  no-op that says so and still appends the run that recomputes the list) —
  until then it is absent from that list rather than wrongly listed as safe
  to delete.
- `CLAUDE.md` trimmed: the directory tree moved to
  `.docs/architecture/loom-architecture.md`, the amendments doctrine to
  `.docs/policies/project-amendments-policy.md`, and the `.brain/` narrative
  to `.brain/README.md` and its template. `tests/contract/test_backlog_dashboard.sh`
  greps retargeted to the new locations.

### Removed

- The two "What changed in v6.x" sections of `CLAUDE.md` (this file is the
  durable record now) and the two `history-scrub-rules.json` ops that scrubbed
  them.

## [6.6.2] - 2026-08-31

### Added

- **The package ships a README.** npm renders it as the package's front page,
  and 6.6.0 and 6.6.1 both went out without one — the registry told every
  visitor "This package does not have a README". Nothing caught it because
  nothing asserted it: `files` does not list `README.md` (npm includes it
  unconditionally), so its absence was invisible to every check that reads that
  array. A contract test now pins that the README exists, names the primary
  command, and states the no-`--force` refusal — and that `files` still does not
  list it, so nobody "fixes" the omission by adding it there and then trusts the
  array as the whole picture.

  The README is written for someone deciding whether to point this at a
  repository they care about: the plan/apply split, what each `--only` target
  installs, why `hooks` is not in `all`, the four refusals enforced in code, how
  the receipt's uninstall works, and the runtime requirements the plan reports
  before you install rather than partway through.

## [6.6.1] - 2026-08-29

The first release published by CI. v6.6.0 claimed the `logicloom` name with a
manual publish — npm has no name reservation, and its trusted-publisher settings
page needs the package to exist before it can be configured — so that tarball
was built locally and this is the first one assembled by the release workflow.

### Fixed

- **`npm publish` is idempotent.** Publishing over an existing version fails
  E403, and the step had no guard, so two ordinary situations produced a red
  release: re-running the job after a transient failure, and the first release
  of a name claimed by hand (whose version is already on the registry by
  definition). The step now checks the registry first and exits 0 with a notice.
  This is why v6.6.0's own publish job went red — that tag predates the fix, and
  `publish-adopt.yml` runs from the tag's own tree.
- **The published payload is CI's, not a local build.** v6.6.0 shipped 276
  payload files where the workflow assembles 278; the local build re-initialised
  a git repo over the extracted tag tree and used `git ls-files`, which honours
  that tree's own `.gitignore` and dropped
  `plugins/loom-memory/{recall,working}/.gitkeep`. No adopter was affected —
  `_retention_ensure_dirs` recreates both on first use — and this release
  restores them by being built the normal way. (LOOM-0045)

### Changed

- README and START_HERE present `npx logicloom init .` as a runnable command;
  the package resolves. The docs-sync contract test moved to its third state,
  which asserts the "does not resolve" caveat is gone rather than present.

## [6.6.0] - 2026-08-28

Covers the `dev-main` line since v6.5.0 (2026-08-25 → 2026-08-28). One dominant
thread — **`npx logicloom init`, the adopt package** — plus the project knowledge
layer and a run of correctness fixes in the governance floor.

### Added

- **`npx logicloom init` — install LogicLoom into an existing repository, or
  start a new one.** A read-only PLAN phase the adopter reviews and answers,
  then an `--apply` that writes only the targets they named. Core promise,
  enforced in code rather than intended: it never deletes, never truncates,
  never overwrites a file it did not create (`copyFileNew` opens `'wx'`, so the
  kernel refuses an existing path), never moves source, and never runs a
  mutating git command. There is no `--force`. Every path it writes is recorded
  in `.logicloom-adopt-receipt.json`, whose `uninstall` object is the reversal
  procedure — a list you run, because an uninstall subcommand would be exactly
  the delete path the tool refuses to have.
- **An install a coding agent can drive.** `--agent-guide` and a machine-readable
  `--json` plan, so an agent can walk the adopter through the decisions instead
  of the adopter walking a terminal.
- **`.brain/` — a project-scoped knowledge layer**, with one resolver for where
  memory lives (`memory_backend = repo | project`) so retrieval follows the
  write target instead of assuming it.
- **A three-command promotion lifecycle** (`/promote-dev` → `/promote-staging`
  → `/promote-prod`) that gates and confirms, and ships no deploy engine.
- **A draft GitHub Release on tag**, and a command that asserts it happened —
  from v6.2.0 to v6.5.0 the release path pushed five tags and published zero
  Releases, with nothing going red.

### Fixed

- **The governance floor failed open on a machine without `jq` and `python3`.**
  `subagent-git-guard.sh` and `protect-governance-files.sh` parsed the hook
  payload jq → python3 with no third rung; with neither present every field read
  empty, an empty `agent_id` read as "main agent", and both returned ALLOW where
  they return DENY anywhere else. Principle VI and the hook that stops the model
  rewriting its own rules silently stopped holding on an ordinary slim
  container, and nothing told the adopter. Both now carry the raw-text rung
  `git-safety-gate.sh` already had, and a regression test asserts the decision
  is identical with and without those tools.
- **The uninstall procedure could destroy the adopter's own files.** Its delete
  list pointed at every recorded write — including the two files the tool had
  only MERGED into (the adopter's `.gitignore` and `.claude/settings.json`) and
  the sidecar a later step still needed to read. Directories sat in the same
  flat list, so a recursive delete would have taken anything the adopter added
  inside one. The list is now split into files and `dirsIfEmpty` (children
  first, non-recursive `rmdir`), merge targets and the sidecar are excluded, and
  every created file carries a `sha256` so deletion is conditional: a matching
  digest means deleting loses nothing of yours, a mismatch means the file is
  yours now and is kept.
- **Nested installs are detected.** Installing into `packages/foo/` of a
  monorepo produced a clean plan and would have written a harness into a
  directory where the hooks cannot load. Now blocking, naming both paths.
- **The plan reports the adopter's execution environment** — python3 (probed, so
  a Python-2 stub is caught rather than trusted on presence), bash, git, jq,
  node against the declared floor, and platform — instead of discovering it when
  a write fails mid-apply.
- **`engines.node` no longer asserts a CI requirement at adopters.** `>=22.14.0`
  came only from npm trusted publishing, a publish-time constraint, and made npm
  warn every adopter below it. Now `>=20.0.0`, the floor CI actually proves.
- A run of claims that nothing verified: a suite failing assertions *because*
  they passed, hooks that never fired, a sandbox claim that was backwards, an
  em-dash separator whose byte length was assumed rather than measured, and a
  heredoc bash 3.2 parses and bash 5.2 rejects.

### Changed

- The adopt package's publication gate is open (`private: false`). The name is
  still unclaimed on npm, so `npx logicloom` does not resolve yet; README and
  START_HERE say so.

## [6.5.0] - 2026-08-25

Covers the `dev-main` line since v6.4.1 (2026-08-13 → 2026-08-24). Four threads:
**user-tunable approval gating** (the harness's interruption budget becomes the
user's, with a floor that refuses to be silenced), the **environment-promotion
methodology** (declaration, validator, scaffolding, and a three-command lifecycle
that gates and confirms but deploys nothing), a **Level-0 backlog SSOT** for
cross-cutting work, and a long run of **governance-floor hardening and
doc-versus-reality corrections** — several of which found that a passing check
was proving nothing.

### Added — user-tunable approval gating

- **`.logic-loom/config/gate-policy.conf`** — live, commented per operation.
  Governance previously answered one question ("does this change the repo?"), so
  `git commit -m "wip"` and `git push --force` produced the same prompt. The
  second question — "is that change worth interrupting you?" — is now the user's,
  answered per operation with `ask` or `silent`. Default posture is `balanced`;
  `/initialize-project` offers `strict` / `balanced` / `minimal`, all three
  rendered from **one** definition shared by `init-project.sh`, the command doc,
  and the contract test.
- **A floor that is not tunable** — push, history rewriting, repo admin, secret
  write and auth refuse a `silent` setting with a typed reason rather than
  ignoring it. Three more are not config keys at all: governance-file writes, the
  dangerous-command guard, and subagent git/gh. Membership test: *a wrong answer
  leaves the repository, or a credential, somewhere a revert cannot reach.*
  `gate-policy.conf` is itself protected, so a subagent cannot rewrite the policy
  and then act under it. Floor verified across 32 combinations (five floor
  operations × four configs × eight permission modes); zero breaches. There is no
  wildcard and no "silence everything" line, by design.
- **Permission-mode awareness**, with its two claims graded differently.
  `permission_mode` **is** present in real hook payloads — verified in this
  repo's own audit log. That the host auto-approves an `ask` under
  `bypassPermissions` was derived by reading a minified binary: plausible,
  **unobserved**, and the sole justification for weakening a guard. So the
  mechanism ships and the weakening does not — `mode.bypassPermissions` defaults
  to **enforce**; relaxing it is one documented line. `dontAsk` and `auto` stay
  enforcing deliberately.
- **`.logic-loom/config/project.conf`** — project identity (`project_slug`,
  `project_name`, `id_prefix`; optional `repo`), read by
  `validate-project-identity.sh`. Kept out of `architecture.conf` so an upstream
  bump never conflicts with the line a fork must keep. Ships **unstamped**
  (`__UNSET__`) so no cloner inherits our slug. Nothing enforces it; the
  validator says so and exits 0.

### Added — environment promotion (declaration and lifecycle; no deploy engine)

- **`.docs/policies/environment-promotion-policy.md`** — the methodology, written
  down. Every claim carries its evidence grade (**VERIFIED / RECOMMENDED /
  UNSOLVED**). States plainly what a green rehearsal does *not* prove: no
  automated end-to-end test drives the artifact against the live environment, so
  "it deployed" and "it was proven to work" are different claims. Two items are
  recorded as **UNSOLVED and must not be copied as patterns** — schema-drift
  detection between deployed environments, and cross-environment secret-value
  parity.
- **`.logic-loom/config/environments.conf` + `validate-environments.sh`** — a
  declaration of environments, the branch each tracks, whether promotion needs
  approval, the promotion order, and the **`deploy` seam the product owns**. The
  validator reads and checks (cycles, missing predecessors, duplicate names,
  unknown keys); it never invokes the seam, never runs git, never writes, and
  exits 0 when the file is absent. Ships **fully commented out** — an active
  default would assert a branch topology a cloner does not have — with a contract
  assertion that no uncommented declaration can ship.
- **`/scaffold-environments`** (`loom-maintenance`) — adopts the methodology into
  a new *or existing* project: detects what the repo already has by reading git
  refs off the filesystem (it invokes no git), proposes a delta, and writes only
  what the user names.
- **`/promote-dev` → `/promote-staging` → `/promote-prod`** (`loom-maintenance`,
  `promotion-lifecycle` skill) — the escalating-confirm ladder made operable.
  Dev and staging prompt and are skippable; prod demands a **typed exact phrase**
  with no flag, environment variable, or non-interactive path past it (`--yes` is
  read and reported as ignored). Confirmation strength resolves from the target
  environment's declared `confirm` first, then the command default — so a project
  can raise dev or lower prod, with a loud note when it is weaker than the ladder
  recommends. The boundary holds and is asserted: no cloud or CI call, no deploy
  command, no migration, seed, teardown, secret or rollback, and **no git**.
  Distinct from the maintainer-only `/promote`, which is untouched and still
  stripped by exact path.
- **The rehearsal contract separates verified from trusted**, because the harness
  runs no git and has no CI API. *Verified*: the attestation exists, reports
  success, parses, is inside the staleness bound, and names a matching or covered
  commit. *Trusted*: that a rehearsal actually ran, that it passed, and that the
  commit is genuinely an ancestor. A rebuilt staging branch makes the rehearsed
  commit the merge's **second** parent, so a seam that writes the merge head
  writes a plausible wrong answer this gate will accept — stated in the refusal
  text rather than left implicit. An unparseable date refuses rather than
  assuming recent.

### Added — Level-0 backlog SSOT

- **`.logic-loom/memory/todos.md` + `.logic-loom/memory/backlog.md`** — the todo
  policy declared a three-level SSOT whose top level was empty and which had no
  slot for cross-cutting harness maintenance, so the real worklist accumulated in
  `.docs/reports/` and `VISION.md` Open Threads: the two least parseable sources,
  and respectively stripped and stubbed at release. Now two files, one grammar
  (normative in `backlog.md`), one parser, one linter, one id space. Todos answer
  "what am I doing"; backlog answers "what should I bring up later". Items carry
  a visible minted id (`LOOM-0042`); status lives in a `status:` tag, not the
  checkbox. The next id is **derived, never stored** (`lint-backlog.sh
  --next-id`) — a stored counter goes silently wrong the moment an item lands in
  the other file.
- **`build-backlog-index.sh`** → `.logic-loom/backlog-index.json`, deliberately
  **untracked and gitignored** (a machine intermediate no human opens has no
  committed copy that could disagree with its sources). Duplicate ids and
  unparseable items are **fatal**: exit 3, nothing written, prior index untouched
  — a consumer must never be unable to distinguish "no such item" from "the
  collector dropped it". `blocked_on` accepts `external:<reason>` so an item can
  say *why* it is stuck, not merely that it is.
- **`artifacts/backlog-dashboard.html`** — a self-contained offline snapshot
  (a `file://` page has an opaque origin and cannot fetch a sibling JSON, so the
  page says on its face that it is a snapshot). **Tracked** and stripped at
  promote, paid for by `check-generated-freshness.sh`, which regenerates and
  fails if the committed copy differs — wired into CI, naming the exact
  remediation command. Timestamps are normalised on both sides so it cannot
  false-fail; a check that always fails gets disabled, which is worse than no
  check.

### Added — governance floor

- **Subagent read-only git allowlist** — the guarantee changes from *subagents
  never touch git* to *subagents never **mutate** git*. Built allowlist-first
  rather than as a mutation classifier: a classifier's failure mode is a silent
  subagent mutation, an allowlist's is a loud false deny. `gh` stays denied to
  subagents wholesale, including reads.
- **`gh` mutations and worktree writes gated** for the main agent (`gh pr
  create|merge`, `gh workflow run`, `gh release`/`repo`/`secret`/`auth` writes,
  `git worktree add|remove|…`), plus two laundering vectors: `gh api` on any
  non-GET method, and `gh api -f/-F` which defaults to POST inside `gh` itself.
- **Forkable-but-unremovable protected-path set** — a fork that renames
  `.logic-loom/` got working git and freeze verdicts but a *silently* broken
  governance-file guard. Config can now only **add**: the built-in floor runs
  first and never reads config, the grammar has no negation or reset key, and
  half the floor is derived from the library's own file location so a renamed
  fork protects itself with zero configuration. 93-row table including eight
  distinct removal attempts; the floor held in all of them.
- **`check-gh-telemetry.sh`** — gh telemetry is opt-out by default and LogicLoom
  uses `gh` heavily, so setup **informs and stops there**. No offer, because an
  offer still ends with the harness writing outside the repo. The check invokes
  no `gh` subcommand at all (`gh config get` can *materialize* a config file),
  parses the config directly, and always exits 0.
- **CI: PRs into `main` are rejected from anything but a release branch**, and
  new prevention suites close the two classes behind the v6.4.0 leak — every
  tracked generated artifact must be declared (strip manifest or an explicit
  allow-to-ship list with a reason), and every history-scrub rule must match
  something. Both were proven to fail against a planted defect before being
  trusted; the second found **10 permanently dead rules**, deleted rather than
  excluded.
- **`.docs/policies/shell-idiom-policy.md`** — seven idioms, each traced to a real
  failure in this repo rather than to an abstraction, and
  **`plugins/MANIFEST-SCHEMA.md`** — the `.claude-plugin/plugin.json` schema,
  published where a plugin author already is.

### Fixed

- **The test suite failed assertions *because* they passed.** 204 sites across 22
  files asserted via `producer | grep -q` under `pipefail`: a matching `grep -q`
  exits immediately, the producer takes `SIGPIPE`, and `pipefail` propagates it.
  Measured, not estimated — 40 runs of one suite gave 22 pass / 18 fail. Six
  sites were worse than a flake (`| head -N` under `set -e` aborts the *whole*
  suite), and two of them sat inside assert helpers, so every assertion in those
  suites rode the race. Fixed with `grep -q PAT <<< "$VAR"`: a here-string is a
  temp file, so the race is structurally impossible rather than merely unlikely.
  Assertion counts verified identical against a pre-fix baseline, so nothing was
  silently dropped. Honest limit: this does not improve diagnosability.
- **Plugin `hooks.json` files never loaded — and the recorded reason was wrong.**
  Claude Code loads plugin hooks from *installed* plugins in `~/.claude/plugins/`;
  LogicLoom's in-repo tree qualifies nowhere, so the shape mismatch was never the
  blocker. Confirmed by observation (~98 subagent completions, zero growth in
  `subagent-activity.log`, whose one line dates from 2026-06-14) with a positive
  control proving the script itself works. **Deleted rather than repaired** —
  nothing consumed the log. The `loom-governance` *scripts* are untouched and
  still root-wired; that is the actual floor. Five tests that asserted the dead
  wiring exists now assert it is gone and that each guard is wired from
  `settings.json`.
- **The sandbox claim was backwards.** Host Bash sandboxing is **opt-in and off
  by default**, keyed on `sandbox.enabled`, which appears in neither settings
  file — verified by probe, not by reading docs. The threat model's residual #4
  was replaced with what the host provides, what it is not, and the note that
  `autoAllowBashIfSandboxed` defaults true, so enabling the sandbox and enabling
  auto-approval are the same decision unless explicitly set false. The shipped
  posture is **unsandboxed**.
- **`constitutional-check.sh` claimed more than it checked, six ways** — a
  success line naming a principle that could never fail; five `INFO` branches
  incrementing `PASS_COUNT` for an *absence*; Principle VI printing **nothing**
  when no git operations were found, so the only blocking check vanished from the
  summary; five principles scanning `src/` and `libs/`, which the harness↔product
  boundary says cannot exist; and Principle XVI searching at the wrong depth, so
  it reported "no plugin architecture" in a repo with eight manifests. Verdict
  goes from *12 passed / 5 warnings, arithmetic unverifiable* to *9 passed / 0
  failed / 2 warned / 5 skipped*, summing to 16 under a self-check. A stale
  duplicate copy under `plugins/loom-governance/scripts/` — frozen at
  constitution v1.6.0 and **shipping to every cloner** — was deleted.
- **Git checkpoints never worked, concealed by a dead assertion.**
  `local x=$(cmd)` resets `$?` to 0, so the test asserted `local`'s status;
  meanwhile `create_git_checkpoint` wrote pretty-printed JSON that
  `list_git_checkpoints` read line-by-line into `jq`. Records are now compact
  JSONL with `jq --arg` escaping, which also closes a latent corruption on any
  quote in an operation string.
- **Governance matching anchored at command position.** `grep
  --exclude-dir=.git` and `echo "check git status later"` were denied to
  subagents; `git stash list` and `git tag -l` prompted for approval. Two false
  *allows* closed as a side effect: bare `git branch newfeature`, and `rm
  .claude/hooks/x.sh` at the **start** of a line, which bypassed governance-file
  protection entirely.
- **`/promote` release path** — GitHub suppresses `pull_request` events for PRs
  opened with the built-in `GITHUB_TOKEN`, so when `promote-to-main.yml`
  *succeeded* at opening the release PR, neither `leak-guard` nor `plugin-tests`
  ran on it. The gap appeared only on the success path, which is why it survived
  two releases. The workflow no longer opens PRs at all and can no longer be made
  to; `/promote` now asserts that checks actually **reported** (counting
  `statusCheckRollup`) and requires `leak-guard` and `contract-tests` present by
  name and green.
- **Memory keyword search** — binary exclusion had been dropped in the ranking
  rewrite (invisible on macOS, where BSD `grep` prints nothing for a binary file;
  on GNU `grep` binary content could be selected and injected into a prompt); the
  50KB size filter ran *after* every file had already been read; and a colon in a
  filename corrupted the sort key. Also: ranking by match count rather than
  filesystem walk order.
- **Four contract suites ran nowhere** — not in the aggregate runner, not in CI —
  including the 149-assertion suite pinning the very behavior being changed. All
  four registered, and `test_suite_registration.sh` closes the class by asserting
  every suite is in the runner, every runner suite is in CI or on a documented
  exclusion list, and every CI step points at a file that exists. It registers
  itself.
- **`grep -c ... || echo 0`** produced the two-line string `0\n0`, breaking every
  numeric test downstream. Six instances found; five fixed (including
  `memory-log.sh`, which was emitting **invalid JSONL**). The sixth, in
  `governance-preflight.sh`, was on the protected surface and fixed separately.

### Changed

- **Two shipped policies described a repository that does not exist.**
  `branching-strategy-policy.md` prescribed GitFlow with a `develop` branch
  auto-deploying to a development environment, and `deployment-policy.md`
  asserted deployment was automatic on push to a `staging` branch. There is no
  `develop` and no `staging`. Both are now split three ways at the top —
  **ENFORCED** (the git-approval gate, the subagent git deny), **ASSUMED** (a
  mainline exists and work happens on branches; nothing checks it), and **YOUR
  CHOICE** (everything else) — mirroring the enforced-versus-followed honesty the
  threat model already uses. `dev-main` is deliberately still absent from the
  shipped policies: that topology exists only because LogicLoom is distributed as
  a template, and documenting it for a cloner would relocate the defect rather
  than fix it.
- **The evaluator is advisory, and now says so.** `evaluator-protocol.md` v0.1
  specified no gate semantics at all while a VISION thread asked to harden a
  hard-gate contract nobody had written. Answered rather than built (v0.2): the
  evaluator produces findings; it does not gate, block, or fail a workflow. The
  tradeoff is stated rather than sold — an ignored finding is indistinguishable
  from no finding, so the mitigation (surfacing plus a written report) makes the
  loss *auditable, not prevented*. What buys that cost is that a gate over
  subjective model judgement running on a flaky browser MCP would block real work
  on a wrong opinion, and the predictable response is a bypass flag.
- **Project amendments stay followed-not-enforced, by choice.** Wiring
  `amendments.md` into `governance-preflight.sh` was considered and declined: a
  loader would make mandates *look* enforced without making them enforced — the
  hook floor still would not consult a mandate — which is the phantom-gate
  failure the threat model exists to name. Recorded as decided rather than
  pending across the constitution, `CLAUDE.md`/`AGENTS.md`, and the threat model.
- **Marketplace residue cleared** from the command bridge, the context file, and
  `loom-orchestrator`'s manifest keywords. No live reference to
  `sdd-marketplace`, `marketplace.json`, or any registry URL remains. Scope stops
  short of externalising the eight in-repo plugins — `loom-governance` *is* the
  hook floor and Principle XVI requires every plugin to depend on it — which is a
  constitutional amendment still pending a maintainer decision.
- **`loom-maintenance` plugin manifest → 1.1.0** and its description rewritten;
  it gained four commands (`/scaffold-environments`, `/promote-dev`,
  `/promote-staging`, `/promote-prod`) and two skills (`environment-scaffolding`,
  `promotion-lifecycle`).

### Known gaps

- Nothing loads `.logic-loom/memory/amendments.md`. Mandates are followed because
  `CLAUDE.md` and `AGENTS.md` say to read them, not because anything fails
  closed. Deliberate (see above), not an oversight.
- `environments.conf`, `project.conf`, and the promotion ladder are all
  **declaration and guidance**. No hook reads any of them; the validators are
  read-only and exit 0 on an absent file. `requires_approval` is a statement your
  CI or your reviewer is expected to honour — the harness will not notice a
  deviation.
- One assertion in `test_update_framework.sh` ends in `|| true` and therefore can
  never fail. Found, recorded, not fixed. That suite is also the one documented CI
  exclusion (live network I/O, no timeout).

## [6.4.1] - 2026-08-13

A patch release fixing the **update path**. Clones of v6.3.1 and v6.4.0 could not
run `/update-framework` at all; this release repairs those baselines
automatically, documents the failure by its literal error string, and adds the CI
assertion that would have caught it at merge time.

### Fixed

- **`/update-framework` failed with "`.sdd-sync-ref` is NOT reachable from
  upstream main"** for clones of v6.3.1 and v6.4.0. Those releases' PRs were
  **squash-merged**, which discards the single-parent sanitized snapshot commit
  that `.sdd-sync-ref` names. Customers fetch only `refs/heads/main`, so the
  recorded baseline was unresolvable in their clone and the update exited 3.
  Root cause was a **settings conflict**: branch protection on `main` required
  linear history, which forbids the merge commit the release design depends on.
  Repo settings corrected — merge commits allowed; squash and rebase merging
  disabled.

### Added

- **Automatic repair of the broken baselines** —
  `plugins/loom-maintenance/scripts/extract-proposals.sh` now detects the two known-bad
  baseline SHAs, remaps each to its equivalent commit on `main` (re-verifying
  reachability before accepting the remap), and continues the update, so no
  changes are skipped.
- **`KNOWN_ISSUES.md`** at the repo root, a pointer from `README.md`, and an
  expanded **"Broken sync baseline"** section in
  `.docs/guides/FRAMEWORK_SYNC_GUIDE.md` — all keyed on the literal error string
  (`.sdd-sync-ref is NOT reachable from upstream main`) so a search finds them.
- **Release-time prevention gate** — `.github/workflows/release-tag.yml` now
  asserts the snapshot commit is an ancestor of `main`'s HEAD
  (`git merge-base --is-ancestor`) **before** creating the tag, and fails the
  release loudly (naming cause, impact, and remedy) if a future promotion is
  squash- or rebase-merged.

### Changed

- The **non-remappable error path** now states explicitly that the generic
  re-baseline adopts nothing and **permanently skips** the intervening changes,
  and offers the version-specific fix first.

## [6.4.0] - 2026-08-12

Covers the `dev-main` line since v6.3.1 (2026-06-24 → 2026-08-12). Three threads:
the **orchestrator + worker ladder** (making delegation actually bind, not just be
documented), the **project graph convention** (a text-first, deterministic
code+docs graph — no engine, no daemon), and a round of **governance / CI floor
hardening**. Plus the harness↔product and harness↔user boundaries written down.

### Added — orchestrator + worker ladder

- **Frontier orchestrator role** (`.logic-loom/config/models.conf`): a
  *model-agnostic-but-frontier* orchestrator tier — `FRONTIER_MODEL`
  (`claude-fable-5`) with a documented `FRONTIER_FALLBACK` (`claude-opus-4-8`)
  so the role survives a quota/availability gap. Both targets are Anthropic; the
  orchestrator never runs on a non-Claude model.
- **Two project agents** (`.claude/agents/`, deliberately *not* plugin agents —
  plugin agents lose `hooks`/`mcpServers`/`permissionMode`):
  `deep-reasoner` (opus, effort `high`) for architecture and hard debugging, and
  `fast-worker` (sonnet, effort `medium`) for boilerplate, tests, and routine
  edits.
- **`.docs/architecture/orchestrator-worker-ladder.md`** — the ladder, its
  economics, and the dispatch policy (reasoning → `deep-reasoner`; mechanical →
  `fast-worker`; correctness-critical + scrutiny-inviting → also `/cross-check`).
  Non-Claude models remain advisory-only; the ladder adds no non-Claude workers.
- **`.docs/architecture/model-selection-policy.md`** — canonical model-selection
  policy consolidating a four-surface audit (frontmatter executables, the
  cross-provider verification layer, config/scripts/schemas, documentation prose).
- **`.docs/architecture/orchestration-hook-enforcement.md`** — why an
  orchestration policy written in `CLAUDE.md` stops binding as a session grows
  (it is loaded once, at position zero) and the two hook patterns that fix it:
  `UserPromptSubmit` policy re-injection and a delegation nudge keyed on the
  `agent_id` discriminator. Includes exempt-recon carve-outs, threshold-not-
  tripwire tuning, a fail-safe posture (emit context, never a decision), and a
  **surface-portability** section that marks each claim with its verification
  level (confirmed-from-docs vs. explicitly undocumented).
- **Per-provider model selection for `/research`**: `--openai-model`,
  `--gemini-model`, `--claude-model`, resolved **flag → env → config default**.
  `models.conf` gains an "Advisory cross-provider models" block as the single
  documented source of each provider's default (`gpt-5.5`,
  `gemini-3.1-pro-preview`), shared with `/cross-check` via the same
  `CROSS_CHECK_*_MODEL` overrides. The advisory + read-only boundary is unchanged.

### Added — project graph convention

- **`/graph` command + `project-graph` skill** (`loom-orchestrator`) — regenerate
  and query a project-wide code+docs graph, emit a visual export, and lint it.
  Deterministic and text-first: it walks a git-tracked JSONL manifest with `jq`.
  No graph engine, no daemon, no default LLM extraction pass, and every mechanism
  fails open (warn, never block).
- **`.logic-loom/graph/graph-bridge.jsonl`** — the git-tracked bridge manifest
  (Anthropic memory-server shape), generated by
  `.logic-loom/scripts/bash/build-graph-bridge.sh`, with
  `.logic-loom/scripts/bash/lint-graph.sh` as the orphan/edge linter.
- **`.docs/architecture/project-graph-convention.md`** — the normative federated
  model: knowledge/docs in the markdown itself (Obsidian-readable), code in an
  **opt-in, per-product** code-graph MCP with a `ctags + rg` text floor, joined by
  the git-tracked bridge. The merged code+docs graph is an **export**, never a
  store. Ships an `.obsidian/` config *template* (`.logic-loom/templates/obsidian/`),
  not an installed app.

### Added — boundaries, written down

- **Harness ↔ product boundary** (`.docs/policies/file-structure-policy.md`
  § Product Workspace): the framework owns the repo root (root `package.json`,
  root `tests/`, `.claude/`, `.logic-loom/`, `plugins/`); product application code
  lives in its own workspace — `web/` for a single app, `apps/<name>/` for a
  monorepo — with its own `package.json`, `node_modules`, build, and test runner.
  A product `src/` at the repo root trips the framework's jest-glob and coverage
  gates. Backed by `tests/contract/test_product_workspace_boundary.sh`.
- **Harness ↔ user boundary** — a new section in `CLAUDE.md` and
  "Where do my personal preferences go?" in `START_HERE.md`, plus a pointer step
  in `/initialize-project`: **LogicLoom never writes to `~/.claude/`.** The
  harness governs this repo only; persona and working preferences belong in the
  user's own global config, which should stay out of git.
- **`START_HERE.md`** — onboarding walkthrough of a first feature via the swarm
  pack, with the SDD waterfall pack documented as the equal alternative.

### Added — exploration & design records

- `features/code-knowledge-graph/exploration/` — the build-vs-buy record behind
  the graph convention (`graph-design.md`, `project-graph-design.md`,
  `graph-stack-decision.md`: build a lightweight deterministic git-tracked text
  graph; adopt no third-party graph stack into the default path).
- `features/harness-product-boundary/exploration/` — the silent root-collision
  failure modes the product-workspace rule exists to prevent.
- `features/modular-harness/exploration/` — thin-core / layered-config design
  notes (`modular-harness-design.md`, `unified-architecture.md`).

### Changed

- **`VISION.md` rewritten to v2.0** — restated as a living product north-star:
  *a constitutional-governance-focused, workflow-agnostic development harness that
  ENHANCES the flagship model*, adding only what does not decay as models improve
  (governance, safety, observability, cost discipline, file-ownership) while
  riding **on** Claude Code's native orchestration. "Be the durable floor and the
  value-on-top, not the engine."
- **CI gate coverage** (`.github/workflows/plugin-tests.yml`) — the workflow now
  runs 9 additional contract suites (governance hooks, policy matching,
  orchestration hook, memory search, spec 006 integration, git safety, policy
  validation, structured logging) so every suite gates PRs. Previously only 8 of
  14 ran, and the **Git Safety** suite — Principle VI enforcement — was not among
  them.
- The `paths:` allowlist was removed from that workflow so the framework-wide gate
  always runs; the allowlist had excluded `.logic-loom/lib/`, `.claude/hooks/`,
  `settings.json`, and the workflow file itself.
- `tests/run_all_tests.sh` now also runs the three suites CI already gated but the
  local runner was missing: product workspace boundary, model agnosticism, and
  graph bridge.
- `test_update_framework.sh` is excluded from CI (it still runs locally): it makes
  a live network `git fetch` via `extract-proposals.sh --dry-run` with no timeout,
  and its key assertion is suffixed `|| true`.

### Fixed

- **`guard-dangerous-commands.sh` no longer fails open on bash 3.2.** `policy.sh`
  and `logging.sh` are now bash-3.2 compatible, so the dangerous-command guard
  **enforces on stock macOS** with nothing to install. Bash version is no longer a
  fail-open condition; the re-exec into a bash 4+ binary is kept only as
  belt-and-braces, and falling through it is not a failure. The remaining
  fail-open paths are genuine infrastructure gaps (missing/unsourceable policy
  lib) — the other guards gate independently and fail **safe**.
- **Dangerous-command matching now happens at command position, not anywhere in
  the string.** Quoting a dangerous example inside a commit message, PR body, or
  doc no longer trips the guard. Covered by
  `tests/contract/test_policy_matching.sh`.
- **The test runner no longer hides crashed suites.** A suite that exits nonzero
  without emitting a parseable `Results: x/y` line has its assertions counted
  nowhere; those now gate the run (`CRASHED_SUITES`). Also closed the adjacent
  hole where a suite printing parseable passing results but exiting nonzero would
  not fail the run (`NONZERO_EXITS`).
- Executable bits restored (0644 → 0755) on `protect-governance-files.sh` and
  `subagent-git-guard.sh` — two hooks in the enforcement floor.

## [6.3.1] - 2026-06-24

**Release-tooling maintenance** (no customer-facing framework changes).

### Added
- Maintainer release driver: `/promote <version>` + `bump-version.sh` (coherent
  framework-version stamping with `set`/`--check`) — drives the dev-main→main
  promotion end to end and hands off at the green PR (main stays review-protected;
  no `--admin`). Maintainer-only; stripped from customer copies.
- `.github/workflows/release-tag.yml` — auto-tags `vX.Y.Z` when a release PR is
  merged to `main` (push-triggered, idempotent), so the maintainer never hand-tags.

### Changed
- `/initialize-project` now also strips `release-tag.yml` from a customer project;
  the `promote-to-main.yml` PR body documents the auto-tag.

## [6.3.0] - 2026-06-24

**Provider-portability program (Phases 1–3)** — a considered supersession of the
prior absolute "Claude-Code-native, NOT provider-portable" stance. POLICY now
travels to any host as model-followed rules; ENFORCEMENT stays Claude-Code
reference with a documented adapter contract (Phase 4, the orchestration-runtime
abstraction + identity rewrite, is gated and not in this changeset).

### Added (portability)
- **Cross-Check Disposition** — the primary agent now leans toward a decorrelated
  cross-provider review on verification-shaped asks (double-check / are-you-sure /
  red-team / peer-review …), the way ultracode self-orchestrates. Two layers:
  host-neutral prose in **AGENTS.md Tier 1** + **CLAUDE.md** (the floor that
  travels), and a Claude-Code **preflight nudge** (`governance-preflight.sh` +
  `verification-intent.conf`) with five over-fire guardrails and key-aware text.
  Fixed a latent preflight bug (domain detection ran on the truncated JSON
  envelope, false-firing on `cwd`/paths — now on the real prompt).
- **Provider-neutral AGENTS.md** — restructured into **Tier 1** (operating
  principles + disposition + neutral capability catalog, with an in-band
  "Enforcement reality" banner) and **Tier 2** (Claude Code host implementation).
- **Verdict-function seam** (`.logic-loom/lib/governance-verdicts.sh`) — the four
  enforcement guarantees' decision logic factored into shared pure-bash
  `allow|ask|deny` functions; the four Claude Code hooks now call them
  (behavior-preserving, `test_governance_hooks.sh` 23/23). Golden-fixture
  conformance test (`test_governance_verdicts.sh`, 28/28).
- **First non-Claude enforcement adapter** (`.logic-loom/adapters/`) — an
  off-host **git-approval gate** (pre-push hook + PATH `git` wrapper) that calls
  the same verdicts and enforces Principle VI on any POSIX-shell host; passes
  `test_git_adapter.sh` (13/13). Proves the L2 adapter contract is real.
- **Per-host wiring guide** (`.logic-loom/adapters/HOSTS.md`) — policy shim +
  enforcement install for Codex CLI / Cursor / Gemini CLI / Copilot / Aider.
- **Honest portability docs** — threat-model L1/L2/L3 model + enforced-vs-followed
  matrix + adapter-conformance contract; supersession recorded in CLAUDE.md +
  `models.conf`. Governance does NOT degrade gracefully off-host — enforcement is
  binary present/absent by host.

**Added a governed cross-provider adversarial review flow** — the canonical path
for all adversarial / cross-check reviews. By default LogicLoom's reviewers are
Claude reviewing Claude (shared training lineage → shared blind spots); a
non-Claude lineage (Codex/GPT by default, Gemini pluggable) decorrelates the
review and catches the class of defects correlated reviewers structurally miss.

### Added
- **`cross-check` skill** (`plugins/loom-orchestrator/skills/cross-check/`): the
  shared machinery. A governed Claude subagent runs an external model over a
  target (diff / `plan.md` / `claims.json` / file scope) and returns structured
  findings. Two modes: **Mode A (API, default)** — artifact-scoped, zero agentic
  surface, reuses the `/research` cross-provider pattern; **Mode B (`--deep`,
  opt-in)** — read-only provider CLI (`codex exec --sandbox read-only`) for
  repo-wide exploration. The external model is strictly **advisory + read-only**:
  it emits findings; the governed Claude agent triages (`accept|reject|
  needs-investigation`) and owns all remediation. Never writes repo source, never
  runs git. Provider-pluggable (Codex/GPT default), key-gated, fails open to
  `unavailable` (never phantom-gates).
- **`/cross-check [target]` command** — the standalone ad-hoc entry point.
- **`/review-team` cross-provider adversary** — a 5th, key-gated reviewer slot
  (peer signal, not a hard gate). `--no-adversary` / `--adversary-deep` flags.
- **`/plan-review --adversary`** — optional cross-provider lens on the plan DAG.

### Changed
- `models.conf` provider-boundary note now names both verification-layer
  consumers (`/research` + `/cross-check`) and states the advisory/read-only
  invariant explicitly.
- `governance-threat-model.md` documents a new residual (#5): Mode B trusts the
  *provider's* `--sandbox read-only` flag (a subprocess, hook-invisible) rather
  than LogicLoom's hooks — why Mode A is the default and Mode B is opt-in.
- `.env.example` documents the cross-check keys and the data-governance opt-in
  posture (enabling a provider sends the review target to that provider's API).

## [6.2.1] - 2026-06-15

**Removed the DS-STAR refinement subsystem.** The orphaned, experimental,
never-wired heuristic quality-gate is gone — Claude Code's native `/goal`,
`/workflow`, and `/loop` primitives cover the same ground.

### Removed
- The DS-STAR refinement subsystem (`src/sdd/` Python library + the Python
  agent/refinement wrappers, their tests, packaging, and
  `.logic-loom/config/refinement.conf`) — orphaned/experimental and redundant
  with native `/goal`, `/workflow`, and `/loop`. Earlier release notes
  (v6.1 / v6.2.0) described DS-STAR as "retained"; that is now superseded — it
  is fully removed.

## [6.2.0] - 2026-05-31

**Removed the dev-loop pack** (superseded by native `/workflow`, `/loop`, `/goal`);
orchestration now leans on Claude Code's native loop primitives. LogicLoom has
**two** workflow packs over the governance core — swarm and SDD waterfall.

### Removed
- The `loom-dev-loop` plugin and the `/dev-loop` command (`core-loop` skill):
  Claude Code now ships native `/workflow`, `/loop`, and `/goal` primitives that
  supersede the autonomous edit-test-debug loop, and dev-loop's runtime
  self-extension (gap detection → scaffold → register) was a governance
  liability. Plugin count: 9 → 8.
- The dev-loop subsystems that lived only inside that pack: the dev-loop tribunal
  voting / grading engine, scope-detector, quality-grading, termination-engine,
  RL-feedback engine, self-extension, and the dev-loop contract test suites.

### Unchanged
- `/research` and its jury-on-demand multi-LLM tribunal (in `loom-orchestrator`,
  self-contained) are **kept** — they are not part of dev-loop.
- The DS-STAR refinement subsystem and `.logic-loom/config/refinement.conf` are
  **retained**, decoupled from governance.

## [6.1.0] - 2026-05-28

**Opus 4.8 re-base + workflow-agnostic core.** Removed harness scaffolding made
redundant by flagship models, and reframed the framework around a governance core
with interchangeable workflow packs (no "primary"/"legacy" path).

### Changed — governance is hook-enforced
- Removed the mandatory per-message **4-step compliance ceremony** (FR-707). The
  `git-safety-gate` PreToolUse hook now forces an approval prompt on git mutations
  (real Principle VI enforcement) and is wired into `.claude/settings.json` with
  the dangerous-command guard.
- New `LOOM_GOVERNANCE_MODE` (`.logic-loom/config/governance.conf`): `lean`
  (default, flagship models) / `strict` (re-adds recitation for weaker models).
- Constitution → **v3.1.0**: LogicLoom identity; Principle X rewritten to
  "Delegation & Context Isolation"; Opus 4.8 default; dropped the `rl_metrics`
  manifest mandate.

### Changed — workflow-agnostic reframe
- Governance core + **interchangeable workflow packs** (swarm, SDD waterfall,
  dev-loop); none privileged. `vision.md` / `/plan-review` are swarm-pack-internal
  gates, not framework-level.
- Plugins renamed `sdd-*` → `loom-*`; **`sdd-specification` keeps its prefix**
  (it *is* the SDD workflow). 9 plugins.

### Removed
- The 7 `sdd-domain-*` plugins — collapsed into a governance-core **domain-brief
  registry** (`get_domain_brief`).
- RL telemetry (`rl_metrics` fields), the `sdd-marketplace` MCP, migration
  scaffolding. (DS-STAR refinement subsystem **retained**, just decoupled from
  mandatory governance. RL retained inside the `loom-dev-loop` pack by design.)

### Added
- `.logic-loom/config/models.conf` — role→model config (flagship Opus 4.8); no
  pinned version strings in agents/commands.
- Documented model/provider boundary: orchestration is Claude-Code-native
  (Anthropic-only); cross-provider models only at the delegated `/research` layer.

## [6.0.0] - 2026-05-27

**Major release**: LogicLoom rename + workflow modernization. Project renamed `sdd-agentic-framework` → `logic-loom` (brand: **LogicLoom**); `.specify/` → `.logic-loom/`. The rename disambiguates from the loom.com video platform.

### Renamed

- Project package: `sdd-agentic-framework` → `logic-loom`
- Brand: **LogicLoom**
- Framework directory: `.specify/` → `.logic-loom/` (all script and config paths updated)

### Added — LogicLoom primary workflow

- **`features/<feature-name>/` layout**: vision → exploration → research → PRD → plan → plan-review → sprints → retro (see `features/README.md`)
- **`/plan-review` skill** (loom-orchestrator): CEO + Eng reviewer verdict on `plan.md` — gates `/swarm implement`
- **`/retro` skill** (loom-orchestrator): post-feature learning capture
- **Vision-driven `/create-prd`**: auto-detects whether `vision.md` exists and routes to vision-driven or legacy PRD mode; office-hours forcing-questions gate
- **3 new hooks**:
  - `worktree-port-namespace` — deterministic per-worktree dev-server port ranges (no collision across parallel branches)
  - `context-cap-warn` — flags sessions approaching 800K of the 1M context window
  - `freeze-write-scope` — rejects swarm worker writes outside declared file ownership

### Changed — Workflow commands

- **`/swarm` — 3 modes**: `explore` (read-only investigations), `implement [sprint]` (per-sprint scope-bounded workers, file-ownership DAG enforced), `generic-legacy` (pre-LogicLoom behavior preserved)
- **`/review-team` — 4 reviewers** (was 3): added a **behavioral evaluator** that drives Playwright via chrome-devtools MCP to exercise actual UI/API behavior alongside security + quality + performance
- **`/research` — jury-on-demand**: picks 1-3 LLM judges per query type instead of always running the full tribunal. Pass `--judges all` for legacy 3-judge cross-validation
- **`/create-prd`** auto-detects vision-driven vs legacy mode

### Removed

- `mcp-servers/sdd-marketplace/` — LogicLoom no longer runs its own plugin marketplace
- RL telemetry infrastructure: `.logic-loom/scripts/bash/rl/`, `src/sdd/feedback/`, `src/sdd/metrics/`, `.docs/rl-metrics/`
- 5 stale internal scripts: `migrate-agent-to-skill`, `legacy-pattern-report`, `skill-coverage-audit`, `analyze-logs`, and `.specify/memory/agent-collaboration.md`

### Defers (third-party discovery)

LogicLoom is not in the marketplace business. External skill and plugin discovery defers to:

- **Anthropic Claude Code Plugin Marketplace** — canonical source for installable skills/plugins
- **Docker MCP Toolkit** — 310+ containerized MCP servers via `mcp-find`, `mcp-add`, `mcp-config-set`, `mcp-exec`

### v3 supplementary principle — Legacy-Tool Coexistence

Legacy SDD tools remain as alternative paths alongside the LogicLoom workflow:

- `/specification` (unified waterfall), `/specify`, `/plan`, `/tasks`
- DS-STAR verifiers and validators
- 7 domain plugins (frontend, backend, database, testing, security, devops, performance)
- `/build-team`, `/fullstack-team`, `/dev-loop`, `/finalize`

Pick the workflow that matches the problem shape.

## [5.0.0] - 2026-02-16

**Major release**: Agent Architecture Simplification + pre-release sanitization. 1,322/1,322 tests passing across 27 suites.

### Added

- **Spec 006**: Agent Architecture Simplification + Memory Enhancement specification
- **13 new contract test suites**: dev-loop (8 suites), plugin lifecycle, deprecation, marketplace (unit + E2E) — total 27 suites, 1,322 tests
- **Dev-loop libraries**: lifecycle.sh, tribunal-engine.sh, self-extension.sh — completing dev-loop plugin implementation
- **Multi-LLM tribunal research**: `/research` command with Claude, OpenAI, and Gemini independent research + tribunal voting

### Changed - Agent Architecture Simplification

- **22 agents reduced to 11**: Eliminated redundant "Claude talking to Claude" custom agents
- **14 agents converted to enhanced plugin SKILLS**: Domain knowledge moved from agent `.md` files to plugin `SKILL.md` files with Task Briefs
  - 7 domain specialists (frontend, backend, database, security, testing, performance, devops) → plugin skills
  - 4 orchestrators (task-orchestrator, swarm-coordinator, workflow-coordinator, specification-orchestrator) → orchestration skills
  - 3 specification agents (specification, planning, tasks) → unified specification skill
- **11 agents retained**: constitutional-governance-agent, team-synthesizer, prd-specialist, subagent-architect, auto-debug-agent, framework-sync-agent, memory-context-agent, dev-loop-orchestrator, debug-analyst, quality-assessor, tribunal-judge
- **Plugin manifests** now authoritative source for RL metrics (replaces deprecated `.claude/skill-index.json`)
- **Agent registry** at `.docs/agents/agent-registry.json` (replaces deprecated `.claude/agent-index.json`)

### Changed - Pre-Release Sanitization

- **All policies** updated from Constitution v1.6.0 to v3.0.0 (8 files)
- **architecture.conf** rewritten for v5.0: skill-based-delegation mode, correct counts (11 agents, 18 plugins, 19 commands)
- **sanitize-for-template.sh** rewritten for v5.0: accurate README/TEMPLATE_INIT generation
- **RL feedback system** updated: all `skill-index.json` references replaced with plugin manifests
- **Constitutional compliance skill** updated from v1.5.0 to v3.0.0 (added Principles XV-XVI)
- **All "14 principles" references** updated to "16 principles" across ~20 files

### Removed

- **14 custom agent definitions**: Replaced by enhanced plugin skills with Task Briefs
- **3 obsolete scripts**: `generate-skill-index.sh`, `discover-skills.sh`, `update-agents-to-constitution-v1.5.0.sh`
- **TEMPLATE_INIT.md**: Now generated dynamically by sanitize script
- **Empty `loom-orchestrator-hook/agents/` directory**

### Fixed

- Agent-collaboration-triggers: removed references to non-existent agents (full-stack-developer, structure-architect, theme-designer)
- Governance knowledge base: domain-agent mapping updated to domain-skill mapping
- Plugin manifests: specification plugin agents count 4→0 (converted to skills)
- Bridge manifest: command count consistency

## [4.1.1] - 2026-02-09

**Patch**: Tag-aware update framework. 266/266 tests passing.

### Added

- **Release tag awareness** in `extract-proposals.sh`: proposals now include `release_tag` field associating each change with its upstream release version
- `list_tags_in_range()`: discovers release tags between sync-ref and upstream/main
- `find_tag_for_file()`: maps each changed file to the release it belongs to
- `--dry-run` now shows release tags in range with dates
- Framework-updater skill updated to group proposals by release tag for per-release adoption
- 5 new tag-awareness contract tests (266/266 total)

## [4.1.0] - 2026-02-09

**Release**: Hook-Based Orchestration + Memory Context Injection + Additive Update Framework. 261/261 tests passing.

### Added - Hook-Based Orchestration (Feature 005)

- **Removed custom agent profile** from `settings.json` — Claude Code runs natively, augmented by hooks
- **`loom-orchestrator-hook` plugin**: Domain detection via `config/domains.conf`, orchestration guidance injected as `additionalContext`
- **`governance-preflight.sh` v3.0.0**: Refactored to provide domain analysis, agent recommendations, and constitutional reminders without constraining Claude Code
- Downstream projects customize `domains.conf` for their own agent registries

### Added - Memory Context Agent (Feature 005)

- **`loom-memory` plugin**: 3-tier memory search (working/recall/archival) with keyword extraction and relevance scoring
- **`memory-search.sh`**: Searches project knowledge (specs, architecture docs, session history, plugins) within 5-second hook timeout
- **`memory-log.sh`**: Observability logging for memory search operations (JSONL format)
- **`memory-context-agent`**: Haiku-model agent for lightweight context injection
- Graceful fallback when plugin not installed — hook continues without memory context

### Added - Additive Update Framework (Feature 005 / Issue #30)

- **`.sdd-sync-ref`**: Single commit hash tracking last upstream sync point
- **`extract-proposals.sh`**: Upstream-history-only diffing (`sync-ref..upstream/main`) — never compares downstream content against upstream
- **Enhancement proposals**: Each upstream change presented as independently accept/reject proposal
- **Framework-updater skill v3.0.0**: 10-step proposal-based adoption flow replacing old git-diff heuristics
- Supports selective adoption: accept new plugins without accepting governance changes, etc.

### Added - Test Infrastructure

- **261/261 tests passing** across 14 suites (up from 209/11)
- 3 new contract test suites: `test_orchestration_hook.sh` (19), `test_memory_search.sh` (19), `test_update_framework.sh` (14)
- Test output format standardized to `N/N passed, N failed` for parser compatibility

### Changed

- `settings.json`: Removed `"agent"` field — Claude Code is primary agent, augmented by hook-based governance
- CLAUDE.md: Replaced agent profile section with hook-based orchestration documentation
- AGENTS.md: 22 agents across 17 plugins (up from 21/15)
- Plugin Command Bridge: 19 commands synced (unchanged count)

## [4.0.0] - 2026-02-08

**Major release**: Plugin-First Architecture, loom-dev-loop plugin, Multi-LLM tribunal research, 209/209 tests passing.

### Added - Plugin-First Architecture (v4.1)

- **16 plugins**: loom-governance, sdd-specification, loom-orchestrator, loom-creation, loom-git, sdd-debug, loom-maintenance, loom-dev-loop, 7 domain plugins, sdd-domain-template
- **SDD Marketplace MCP Server**: 6 tools for plugin management (list, validate, search, install, update, publish)
- **Dynamic Plugin Command Bridge**: `sync-plugin-commands.sh` auto-syncs plugin commands to `.claude/commands/`
- **Constitution v3.0.0**: 16 enforceable principles including Principle XVI (Plugin-First Architecture)
- **19 slash commands** across 7 core plugins, all bridge-generated

### Added - loom-dev-loop Plugin (NEW)

Recursive autonomous dev-loop with council/tribunal methodology:

- **8 libraries** (5,448 lines): grading-engine, termination-engine, event-logger, tribunal-api, permissions-sandbox, scope-detector, rl-feedback-engine, sandbox
- **6 skills**: core-loop, tribunal-vote, scope-analysis, rl-feedback, session-report, self-extend
- **4 agents**: dev-loop-orchestrator, tribunal-judge, quality-assessor, debug-analyst
- **7 entity models**: DevLoopSession, QualityGrade, TerminationEvent, TribunalBallot, RLMetrics, ScopeAnalysis, GapAnalysis
- **Composite quality grading**: 6 metrics (test_pass_rate, coverage, lint, type_safety, security, build) + LLM-as-Judge
- **6-layer termination engine**: Success → Convergence → Budget → Max Iterations → Stuck → User Interrupt
- **L0-L3 permission tiers**: Read-only → Safe Write → Network/VCS → High-Risk
- **Self-extension**: Gap detection → scaffold plugin → quarantine validate → register
- **764 test assertions** across 11 test files (247 passing, 517 TDD awaiting wiring libs)

### Added - Multi-LLM Tribunal Research

- **`/research` command**: Multi-LLM triplicate research with tribunal cross-validation
- **3 LLM providers**: Claude (Perplexity MCP), OpenAI (GPT-4o API), Gemini (2.5 Pro API)
- **5-phase pipeline**: Parallel Research → Claim Extraction → Tribunal Voting → Quality Gate → Synthesis
- **Tribunal voting**: Claude (accuracy), OpenAI (sourcing), Gemini (relevance) with EMA-weighted scoring
- Consolidates former `/research` and `/research-team` into single command

### Added - Test Infrastructure

- **209/209 framework tests passing** across 11 suites (up from 172)
- Contract tests: plugin lifecycle, swarm lifecycle, RL metrics, constitution, deprecation, plugin command bridge
- Integration tests: marketplace MCP (E2E), git safety, policy validation, structured logging

### Changed

- All monolithic agents/skills/commands migrated to plugins (deprecated stubs remain for backward compat)
- `skill-index.json` deprecated (plugin manifests now source of truth)
- AGENTS.md rewritten for Plugin-First Architecture (25 agents across 16 plugins)
- Session-specific artifacts (research output, agent decisions/sessions, feature specs) excluded from main via .gitignore
- Opus 4.6 model references updated throughout

### Fixed

- Git safety checkpoint ID assertion (epoch timestamp format)
- Structured logging `wc -l` whitespace comparison on macOS
- Policy validation `parse_json` silent failure on malformed JSON
- Missing guard-dangerous-commands.sh hook
- Stale `/research-team` test references after consolidation
- Governance plugin manifest missing `dependencies` field

## [3.2.0] - 2026-02-05

### Fixed - Framework Architecture Review

- Issues #18-#23 resolved
- Opus 4.6 model references updated
- `/research` skill added to loom-orchestrator
- Unified `/specification` and `/git-push` commands with RL integration

## [3.1.1] - 2026-01-10

### Added - Debug Skill

**New `/debug` Command** - Systematic deployment troubleshooting workflow

This patch release adds a comprehensive debugging skill with a 10-step systematic workflow for diagnosing and resolving production issues, deployment failures, and runtime errors.

#### New Skill: `/debug`

- **Location**: `.claude/skills/technical/debug/SKILL.md` (668 lines)
- **Command**: `.claude/commands/debug.md` (75 lines)

**10-Step Workflow**:
1. **Issue Identification** - Gather context, understand symptom type
2. **Local Verification** - Isolate platform vs code issues (TypeScript, client build, Vercel build)
3. **Vercel-Specific Diagnostics** - Function limits, config, env vars, platform dependencies
4. **API Endpoint Diagnosis** - Debug 404/500 errors, routing patterns
5. **TypeScript Error Resolution** - exactOptionalPropertyTypes, index signatures
6. **Fix Implementation** - Apply targeted fixes with type safety
7. **Verification Process** - Clean build, test, deploy
8. **Regression Check** - Ensure no new issues introduced
9. **Completion Report** - Document root cause and verification results
10. **Iteration Handling** - Max 5 cycles before user escalation

**Specialized Diagnostics**:
- Vercel deployment failures (build errors, function count limits, 404 endpoints)
- TypeScript compilation errors (`exactOptionalPropertyTypes`, index signatures)
- Platform-specific dependency issues (`package-lock.json`, native modules)
- API endpoint errors (500 errors, timeouts, missing routes)
- Production runtime issues (environment variables, database connections)

**Automatic Delegation**:
- `backend-architect` - API architecture issues, system design
- `database-specialist` - Query optimization, schema issues
- `security-specialist` - Auth/authorization, vulnerabilities
- `devops-engineer` - CI/CD failures, infrastructure

**Trigger Keywords**: debug, fix, broken, not working, failing, deployment failed, build error, 404, 500 error, investigate, troubleshoot, diagnose

**Constitutional Compliance**:
- **Principle II**: Verify/add tests for bug fixes
- **Principle VI**: NO automatic git operations
- **Principle VIII**: Update docs when patterns discovered
- **Principle X**: Delegates to specialists when appropriate

#### New Skill Category: `technical/`

Introduces domain-specific technical procedures category, enabling future skills:
- `technical/api-contract-design/`
- `technical/test-first-development/`
- `technical/performance-optimization/`

#### Documentation Updates

- **CLAUDE.md**: Added `/debug` to Quick Command Reference table
- **Version**: v3.1.0 → v3.1.1
- **.claude/context/skills.md**: Debug skill entry with workflow steps and delegation points

#### Real-World Validation

Battle-tested patterns from production debugging:
- Vercel function count limit issues (consolidating endpoints)
- TypeScript `exactOptionalPropertyTypes` errors (conditional object building)
- Platform-specific dependencies (Windows vs Linux lockfiles)

**Total Lines Added**: 743 lines (668 SKILL.md + 75 debug.md)

---

## [2.0.0] - 2025-11-11

### Major Feature: DS-STAR Multi-Agent Enhancement (Feature 001)

This release integrates Google's proven DS-STAR multi-agent patterns into the SDD framework, bringing sophisticated quality gates, intelligent routing, and self-healing capabilities.

#### Added - DS-STAR Agent Library

- **VerificationAgent** (`src/sdd/agents/quality/verifier.py`)
  - Binary quality decisions (sufficient/insufficient) at each workflow stage
  - Specification completeness validation (≥0.90 threshold)
  - Plan quality validation (≥0.85 threshold, ≥0.90 spec alignment)
  - Blocks progression when quality insufficient
  - Provides actionable feedback for improvements

- **FinalizerAgent** (`src/sdd/agents/quality/finalizer.py`)
  - Pre-commit constitutional compliance validation
  - All 14 constitutional principles validation
  - Test coverage verification (≥80%)
  - Code style compliance (black, isort)
  - Documentation synchronization checks
  - No automatic git operations (Principle VI compliant)

- **RouterAgent** (`src/sdd/agents/architecture/router.py`)
  - Intelligent multi-agent task orchestration
  - Domain detection and agent selection
  - Dependency graph (DAG) execution planning
  - Parallel execution optimization
  - Routing decision audit trails

- **AutoDebugAgent** (`src/sdd/agents/engineering/autodebug.py`)
  - Automatic error repair with >70% fix rate target
  - <30 second debug iteration cycles
  - Common error pattern recognition
  - Self-healing code corrections

- **ContextAnalyzerAgent** (`src/sdd/agents/architecture/context_analyzer.py`)
  - Semantic codebase search with <2 second retrieval
  - Context intelligence and summarization
  - Codebase understanding for agent tasks

#### Added - Refinement Engine

- **Iterative Refinement Loop** (`src/sdd/refinement/engine.py`)
  - Up to 20 refinement rounds with configurable thresholds
  - Early stopping at 0.95 quality threshold
  - State persistence between iterations
  - Feedback accumulation across rounds
  - Graceful escalation to human when needed

- **Configuration System** (`.logic-loom/config/refinement.conf`)
  - `MAX_REFINEMENT_ROUNDS=20` - Maximum iteration limit
  - `EARLY_STOP_THRESHOLD=0.95` - High quality early exit
  - `SPEC_COMPLETENESS_THRESHOLD=0.90` - Specification requirement
  - `PLAN_QUALITY_THRESHOLD=0.85` - Plan requirement
  - `TEST_COVERAGE_THRESHOLD=0.80` - Code coverage requirement

#### Enhanced - Workflow Commands

- **`/specify` Command**
  - Automatic refinement loop after spec generation
  - Iterative improvement until quality threshold met
  - Actionable feedback for specification improvements
  - Human escalation when quality unachievable

- **`/plan` Command**
  - Automatic verification gate after plan generation
  - Quality blocking before task generation phase
  - Plan-to-spec alignment validation
  - Actionable feedback for plan improvements

- **`/finalize` Command** (NEW)
  - Pre-commit compliance validation
  - All 14 constitutional principles checked
  - Test and coverage verification
  - Code style and linting validation
  - Documentation synchronization checks
  - Manual git command suggestions (no auto-execution)

#### Added - Testing Infrastructure

- **Contract Tests** (39 tests, 100% pass rate)
  - VerificationAgent contract tests (13 tests)
  - FinalizerAgent contract tests (13 tests)
  - RouterAgent contract tests (13 tests)
  - Full interface validation coverage

- **Integration Tests** (37 tests)
  - End-to-end verification workflow tests
  - Multi-agent routing orchestration tests
  - Context intelligence tests
  - Refinement loop tests
  - Autodebug healing tests

#### Added - Documentation

- **Feature Specification** (`specs/001-ds-star-multi/`)
  - Complete DS-STAR implementation spec
  - Technical design documentation
  - API contracts and data models
  - Test scenarios and quickstart guide

- **Integration Guides**
  - DS-STAR integration guide
  - Implementation status tracking
  - Test results documentation
  - Production readiness report

#### Enhanced - Framework Features

- **Graceful Degradation**
  - Framework works without Python/DS-STAR components
  - Warning messages when components unavailable
  - Manual review recommendations
  - No workflow blocking

- **Performance Targets**
  - Context retrieval: <2 seconds
  - Debug iteration: <30 seconds
  - 3.5x task completion accuracy improvement (target)
  - >70% automatic fix rate (target)

### Changed

- Updated README.md with DS-STAR feature documentation
- Updated CLAUDE.md with DS-STAR workflow enhancements
- Enhanced directory structure with `src/sdd/` Python library
- Added `.docs/agents/shared/` for cross-agent state

### Breaking Changes

None - DS-STAR enhancements are fully backward compatible with graceful degradation.

---

## [1.2.0] - 2025-09-19

### Added
- **New Agents**
  - `testing-specialist` - Comprehensive QA and test automation specialist in quality department
  - `performance-engineer` - Performance analysis and optimization specialist in operations department

### Enhanced
- **Agent Creation Workflow**
  - Enforced constitutional requirement for subagent-architect delegation
  - Custom tool override capability for specific agent needs
  - Automatic department classification based on purpose keywords
  - Improved MCP access configuration per department

### Documentation
- Updated README.md with current agent inventory (9 agents across 5 departments)
- Added agent quick reference section
- Improved troubleshooting guide

## [1.1.0] - 2025-09-18

### Added
- **Core Agent Infrastructure**
  - Established 7 initial agents across 5 departments:
    - Architecture: `subagent-architect`, `backend-architect`
    - Engineering: `frontend-specialist`, `full-stack-developer`
    - Quality: `security-specialist`
    - Operations: `devops-engineer`
    - Data: `database-specialist`

- **Agent Management System**
  - Central agent registry (`/docs/agents/agent-registry.json`)
  - Audit logging for agent creation
  - Memory structure for agent context and knowledge
  - Department-based organization

- **Constitutional Framework**
  - Section X: Mandatory specialized agent delegation
  - Agent governance framework
  - Agent collaboration patterns
  - Department-specific tool and MCP access controls

### Enhanced
- **create-agent.sh Script**
  - Automated department assignment
  - Tool restriction by department
  - MCP server configuration
  - Registry and documentation auto-updates
  - Constitutional compliance validation

- **Workflow Automation**
  - `/create-agent` command with subagent-architect enforcement
  - Automatic CLAUDE.md updates
  - Agent file naming conventions
  - Memory structure initialization

### Changed
- **Git Operations Policy**
  - NO automatic git operations without explicit user approval
  - Branch creation requires user confirmation and naming preference
  - All commits, pushes, and merges need explicit permission

## [1.0.0] - 2025-09-17

### Initial Framework Release
- **Specification-Driven Development (SDD) Core**
  - Constitutional development principles
  - Library-First architecture mandate
  - Test-First Development (TDD) enforcement
  - Contract-driven integration patterns

- **Workflow Commands**
  - `/specify` - Feature specification creation
  - `/plan` - Implementation planning
  - `/tasks` - Task list generation
  - `/create-agent` - Agent creation (initial version)

- **Directory Structure**
  - `.logic-loom/` - Framework core with templates and scripts
  - `.claude/` - AI assistant configuration
  - `.docs/` - Project documentation and policies
  - `specs/` - Feature specifications directory

- **Templates**
  - Feature specification template
  - Implementation plan template (9-step process)
  - Task list generation template
  - Agent file template

### Based On
- GitHub's spec-kit framework
- Extended with AI governance and agent orchestration
- Enhanced workflow automation and memory management

## Pre-1.0.0

### Foundation
- Initial commit from SDD framework base
- Basic directory structure setup
- Core constitutional principles established
- Initial templates and scripts

---

## Upgrade Guide

### From 1.1.0 to 1.2.0
1. No breaking changes
2. New agents available: `testing-specialist` and `performance-engineer`
3. Review updated agent collaboration patterns for optimal usage

### From 1.0.0 to 1.1.0
1. Review constitutional Section X for mandatory agent delegation
2. Update any custom scripts to use Task tool for agent invocation
3. Ensure all Git operations request user approval

## Future Roadmap

### Planned Features
- [ ] Agent performance metrics and optimization
- [ ] Cross-agent workflow templates
- [ ] Enhanced MCP integration patterns
- [ ] Agent capability evolution tracking
- [ ] Automated agent selection based on task analysis

### Under Consideration
- Product department agents
- Multi-agent orchestration improvements
- Agent learning and adaptation features
- Workflow visualization tools