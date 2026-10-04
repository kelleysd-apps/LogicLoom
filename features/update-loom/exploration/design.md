# Design: `/update-loom` — purpose-based updates for LogicLoom

Status: design only, nothing built. **Revision 2 — adjudicated after cross-provider review.** Sources: `study-launchhouse.md` (A), `study-logicloom.md` (B), `critique-codex.txt` (Codex/GPT, final answer at `:2902-2998`), `critique-agy.txt` (Antigravity/Gemini, 265 lines), and the primary files cited inline. `LH:` prefixes a Launchhouse path (`/Users/bkelley/kelleysd-apps/launchhouse-founder-template`); unprefixed paths are LogicLoom at `29383e6`. Claims I could not verify are marked UNVERIFIED. I executed nothing.

> **Review status.** Both external reviewers produced findings: Codex (16 numbered findings) and Antigravity (7 sections, 25 numbered items). Both are different-provider from this design's author, so this was a decorrelated review of the design. One caveat relayed from the orchestrator: Codex reported it had no *further* different-provider reviewer available to itself, so its result is a single-model review of the design, not a cross-check of its own output. Every finding is listed in section 10 with a disposition; 30 were confirmed and are addressed in the body (section numbers given), 2 are confirmed-and-accepted-as-tradeoff with stronger mitigations, 6 were refuted with evidence, 7 were "unclear" and are resolved with a specification each. Nothing is dropped.

---

## 0. One-page summary

**For a customer (template clone or `npx logicloom` install)**
- Updates become a short list of named improvements, each with one plain sentence on what it does for you, instead of a list of changed file paths.
- A file you never changed takes the new version. A file you did change is adapted around your edits by a read-only agent, and you see a plain description of the result before anything lands.
- An improvement that closes a safety hole cannot be skipped. If it cannot be fitted around your edits, nothing is replaced silently: you are shown exactly which of your customisations would be lost and you choose between replacing that file or stopping the whole update.
- Your governance settings cannot get weaker by accident: a deterministic check refuses any adapted `settings.json`, `tool-restrictions.json` or gate policy that drops a hook, shrinks a deny list, widens an allow list or turns an "ask" into "silent".
- Nothing of yours is deleted or overwritten without your yes; a retired plugin you customised stays, with an explanation of what replaced it and the exact command if you want it gone.
- The whole update is one commit on your branch. "Undo the update" reverses exactly that commit — from any clone, because the record of what was applied travels inside the commit — and verifies every file came back. Undo refuses if your own later commits changed the same files; then it names them and you decide.
- What you will be asked, honestly: one batched question screen per group of improvements that need a decision (improvements on files you never touched are listed, not asked, unless you opt one out), one final "land it?" after you have seen the result, and one governance approval on the merge that makes it live. A stock copy taking 7.0.0 sees three prompts; a heavily customised copy sees a few more.
- Your product code, `features/`, `specs/`, `.brain/` and, in an adopted repo, every directory the harness did not install, are never touched; a cheap tree-hash check proves it on every update.
- The first time, you run your existing `/update-framework` once; it brings the new engine in. That old command keeps working until the new engine proves it arrived complete; then it hands over to `/update-loom`.
- If your copy's update pointer is broken (some 6.3–6.5 clones) or missing, `npx logicloom@7 update-bootstrap` installs the engine directly, in either channel. That command ships with 7.0.0, not later.

**For the maintainer**
- Every change that reaches customers ships with a note: purpose, which files, a done-when list, and an executable check with a planted-defect fixture that proves the check can fail.
- A release gate refuses to promote while any shipped change has no note; the note linter runs in CI and at `/promote`.
- Deleting a plugin directory needs a note that says so (`removes:`) — this replaces `check-release`.
- 7.0.0 is a bootstrap release built from the last shipped tree plus the updater bundle only. `dev-main` is already 192 commits ahead of `v6.6.2` (250 files, +31,696/−975); promoting it as 7.0.0 would make the old updater offer all of that. The thin shape needs a release branch, not a promise (decision 9.3).

**Retired**: the v7 scanner (`release-migrations.sh`, its library and registry, `record-update-writes.sh`), the ownership and scanner test suites, `MIGRATION_GUIDE.md`, the old proposal extractor and skill. About 18,500 lines go; about 9,500 come in, about half of them tests.

**Cost**: four build phases; the first slice (engine + two fixture notes + the end-to-end test) proves the model before anything else is written. Estimated 9,500 new lines; see section 7.

**What could go wrong**
- A note's done-when is too loose and an adaptation passes that reads wrong (silent; mitigated by the reviewer agent, the retention invariants in 1.10, and by always showing the plain-words result).
- The engine runs git inside one script where the hooks cannot see it. We accept that for a detached throwaway worktree inside `.git/`, after the user has approved the enumerated transaction, and make landing a visible, gated command. A hook pattern denies subagents the engine's mutating verbs.
- Checks are upstream shell run locally. They run against a read-only export, never the live tree before approval, and a check that writes anything fails the run; but there is no sandbox on a POSIX-sh floor, and trust reduces to the pinned, committed upstream URL plus TLS.
- Legacy `sdd-*` directories cannot be told apart from a customer's own by content (no reference copy exists in public history), so they are kept by default and only the wiring is checked.

---

## 1. The model, as ported

### 1.1 What stays from Launchhouse, in one paragraph

The engine is a git three-way file engine with a notes layer (A §1.0): every tracked path in the union of base, HEAD and upstream trees (`LH:update.sh:931-941`) is classified by comparing three blobs **and tree modes** against a real base commit; untouched files take the new version, both-changed files merge or are held; held files reach the adapter, and (new) a reviewer may route a merged-clean file to the adapter too. Notes supply purpose, the plain-words question, the safety flag and an executable outcome check. No ownership is ever inferred from content (`LH:update.sh:546-677`). LogicLoom's base commit is `.sdd-sync-ref`, which both channels hold (`payload-manifest.txt:199`; B §6.1) and whose tree is local after the fetch-only pull into `refs/loom-upstream/main` (`extract-proposals.sh:108-116`). **New in this revision**: which notes are *offered* is decided by a tracked ledger, not by presence in the base tree (1.5), and a family of deterministic security invariants sits between the adapter and the tree (1.10).

### 1.2 Where things live (ships to both channels unless marked)

| Artefact | Path | Why there |
|---|---|---|
| Engine | `plugins/loom-maintenance/scripts/update-loom.sh` | floor-scanned (`test_bash32_floor.sh:177-195`), payload `include: plugins` (`payload-manifest.txt:122`), receipt records the dir (kori receipt lists `plugins/loom-maintenance/`) |
| JSON tools | `plugins/loom-maintenance/scripts/json-valid.sh`, `json-flat.sh` | verbatim from LH (POSIX sh + awk) |
| Security invariants | `plugins/loom-maintenance/scripts/security-invariants.sh` | new (1.10); POSIX sh + awk over `json-flat.sh` output and conf lines |
| Linter, checks runner | `plugins/loom-maintenance/scripts/updates-lint.sh`, `updates-checks.sh` | same tree, same floor |
| Notes + checks | `plugins/loom-maintenance/updates/<release>/<id>.md`, `<id>.check.sh` | always upstream-owned (1.6); `<release>` is the version, e.g. `7.0.0` |
| Bundle manifest | `plugins/loom-maintenance/updates/BUNDLE.sha256` | the updater set with hashes; `--status` verifies completeness (3.2) |
| Skill | `plugins/loom-maintenance/skills/update-loom/SKILL.md` | Principle XVI; `constitutional-check.sh:698-730` warns on unmarked `.claude/skills/*` |
| Command | `plugins/loom-maintenance/commands/update-loom.md` + bridge stub `.claude/commands/update-loom.md` | via `sync-plugin-commands.sh sync`; prune keys on plugin presence, not the manifest (`sync-plugin-commands.sh:167-195`) |
| Agents | `.claude/agents/update-adapter.md`, `.claude/agents/update-reviewer.md` | project agents keep `tools:` (constraint H); payload `include: .claude/agents` (`:175`) |
| Retired names | `.logic-loom/config/retired-plugins.txt` | flat list for the six CI consumers (B §0.9) |
| Channel map | `.logic-loom/config/update-channels.conf` | harness-owned prefixes, adopt-excluded prefixes, payload groups, renames; generated from `payload-manifest.txt` at promote (1.4) |
| **Ledger** (new) | `.logic-loom/memory/update-ledger.tsv` | **tracked, fork-owned, never shipped with content**; one row per note the customer has answered (1.5). Written only by the engine inside the update commit; `touches` may not name it (linter) |
| **Applied records** (new) | `.logic-loom/memory/updates/<update-id>.applied` | tracked; tag, commit, upstream sha, touched paths with blob shas and modes; what `--undo <id>` reads (2.2 step 11) |
| Coverage + shape gates | `.logic-loom/scripts/bash/update-coverage.sh`, `bootstrap-shape.sh` | MAINTAINER-ONLY, stripped (section 5) |
| Installer subcommand | `packaging/adopt/` → `npx logicloom update-bootstrap` | ships in 7.0.0 (3.3) |
| Scratch state | `$(git rev-parse --absolute-git-dir)/loom/update/` | per clone, never committed: plan, sides, diffs, `mine/<update-id>/`, lock. Nothing the next update depends on lives here |

Not `.claude/updates/` or `.claude/scripts/`: unscanned by the floor and absent from the adopt payload and the receipt's recorded dirs (B §0.8). The ledger and applied records sit beside `amendments.md` because they share its nature — fork-owned data with no upstream counterpart (`constitution.md:313-318`) — and `.logic-loom/memory/` is already in both channels.

### 1.3 Note schema

Launchhouse's fields kept verbatim (`LH:.claude/updates/README.md`, Frontmatter): `id title purpose touches adds requires safety done-when check`. Changed and added:

| Field | Rule |
|---|---|
| `touches` | Each row may carry a channel suffix: `- CLAUDE.md @template`, `- .docs/x.md` (default `@both`). **Per row, not per note** (Codex #12). Linter validates the suffix. |
| `project-data` (was `founder-data`) | `true` only for a **fork-authored file LogicLoom never ships**. Allowlist, shipped in the linter: `.logic-loom/memory/amendments.md`, `.claude/rules/*` **except** `.claude/rules/logicloom-*.md` (those are shipped via `author:` rows, `payload-manifest.txt:366-368`). `gate-policy.conf`, `project.conf` and `environments.conf` are **removed** from the allowlist: they ship, so they are *posture files* (below), not project data. A `project-data` note: is never `safety: true`; must carry `pattern:`; has no upstream blob, so the engine can only adapt, never take; its check may test only `pattern`, never conformance to LogicLoom wording; declining it is final. Body section `## What this note may claim` replaces `## Migration`. |
| `pattern` (new) | A `grep -E` regex naming the defect lines. Required for `project-data` notes; optional elsewhere. Used by the check **and** by `--adapt-save` to bound deletions (1.10 rule R4). |
| `removes` (new) | Paths that must be absent after the note applies. The linter asserts each is absent in the upstream tree (mirror of the `touches` exists-rule, `LH:updates-lint.sh:234`). |
| `may-drop-headings` (new, markdown only) | Headings the adaptation may remove from a customer's prose file. Everything else is retained by rule R3 (1.10). |
| `relaxes` (new, rare) | Exact security-surface entries a note is allowed to weaken (e.g. a permission moved from `deny` to `ask`). Must be `safety: false`, must be listed verbatim, and is shown to the user as its own exact-diff question. Without it, rule R1/R2 refuse any weakening (1.10). |
| `check` | `none` allowed only for non-safety, non-protected, non-posture notes. A `check: none` note is offered exactly once (1.5) and never re-verified; the linter prints that consequence. |

**Posture files** (new class): `.logic-loom/config/gate-policy.conf`, `governance.conf`, `project.conf`, `environments.conf`. Shipped, protected or customer-tuned, always **held** when both sides changed (like `settings.json`). A note whose upstream diff changes any `<op> = ask|silent` line or any `protected_paths` line must be `safety: true` (linter computes this from the base→upstream diff; B §5.6). Rule R2 forbids the adapter from relaxing a verdict.

**Overlap groups** (new; Codex #1): at lint time within a release folder, and at plan time across all applicable notes, notes sharing any `touches`/`adds`/`removes` path form one **group**. A group is approved or declined as a unit, with every member's title shown. The linter warns on a group of more than two notes. This is the honest answer to "the file is the unit of application, the note is the unit of approval": the two are made to coincide instead of pretending otherwise.

**Forbidden-touch set** (constraint F; linter refuses, engine refuses, gate proves): `web/`, `apps/`, `features/`, `specs/`, `.brain/` except `.brain/README.md`, `node_modules/`, `.logic-loom/memory/update-ledger.tsv` and `updates/*.applied` (engine-written only), and in an adopted repo **every top-level path not under a harness-owned prefix in the channel map** (1.4). Launchhouse's five-layer `growth-engine/` protection (A §3, last paragraph) ports with this list substituted: excluded from the path universe, `path_ignored`, apply-loop skip, `--adapt-save` refusal, linter rule, and the **tree-sha equality gate** (`git rev-parse HEAD:web` etc. equal between worktree and live, `LH:update.sh:1363-1368`), plus undo's refusal of a commit touching them (`LH:update.sh:2497-2502`).

**Protected paths** (constraint A): a note whose `touches` include anything in `loom_protected_path_tokens` (`governance-verdicts.sh:891-912`: `.claude/hooks`, `.claude/settings.json`, `gate-policy.conf`, `governance.conf`, `constitution.md`, `loom-governance/hooks`, …) or in the **security surface** (1.10) must name an executable `check`. `safety` is inferred `true` when the diff changes hook wiring, a verdict, a `protected_paths` line or a `tool-restrictions.json` rule; otherwise the author's call.

### 1.4 Channels, one engine (constraint D)

**Detection, fail-closed** (Codex #11):
1. `.logicloom-adopt-receipt.json` parses and has `"schema": "logicloom/adopt-receipt@1"` → **adopted**; the last run's `only:` list (kori: `harness, gitignore, rules, hooks`) names the installed payload groups.
2. No receipt, but any adoption fingerprint present — `.claude/.logicloom-adopt-settings.json`, `.claude/rules/logicloom-*.md`, `.logic-loom/AGENTS.md` without a root `AGENTS.md` equal to upstream's — → **ambiguous**: treated as adopted with *every* optional group considered uninstalled (the conservative superset of adopter-owned paths), and the skill asks the user to confirm the channel before planning.
3. Receipt present but unparseable → **ambiguous**, same handling, plus a one-line "your receipt is damaged" notice.
4. Otherwise → **template**.

Both channels: base = `.sdd-sync-ref`; upstream = `refs/loom-upstream/main` after the ad-hoc fetch (no remote — `framework-upstream.conf:8-12`; Launchhouse's `git remote add upstream`, `LH:update.sh:72-79`, is dropped: `git.remote.write = ask`, `gate-policy.conf:160`). "Which notes apply" (1.5) is identical in both channels because it reads the upstream tree and the tracked ledger, which both have.

Differences, all data in `update-channels.conf`, generated at promote from `payload-manifest.txt`:
- **harness-owned prefixes**: every `include:` row (`.logic-loom`, `plugins`, `.claude/hooks|commands|context|agents|policies|schemas`, `.docs/...`, `features/README.md`, …, `payload-manifest.txt:113-304`) with its payload group. In an adopted repo a path outside these prefixes is adopter-owned: never proposed, never checked, never written — including an upstream-new top-level directory that happens to collide with the adopter's own (`lib/`, `services/`); a both-added path inside a harness prefix (absent in base, different blobs in HEAD and upstream) is `conflict` → held, never overwritten (agy 2.5).
- **adopt-excluded rows**: `exclude: CLAUDE.md` (`:365`), `exclude: .github` (`:424`), `exclude: tests` (`:458`), root project files; skipped with a one-line reason.
- **payload groups**: a path whose group is not in the receipt's `only:` list is adopter-owned for that install.
- renames (`rename: AGENTS.md :: .logic-loom/AGENTS.md`, `:316`): the engine re-addresses the note's row and the three-way sides;
- merge-channel files (`:330,337`: `.claude/settings.json`, `.gitignore`): always held in an adopted repo; the adapter's `base` side for `settings.json` is the recorded insertion `.claude/.logicloom-adopt-settings.json` (kori has it, 1,598 bytes), not upstream's file, since the adopter's file never equalled upstream's.

The map carries a `manifest-version` header; the engine prints a warning when the receipt's generator version is newer than the map it is reading. Shipping the exclude list as data is new work; today it exists only in the unshipped `packaging/` manifest (B §6.1).

### 1.5 Which notes are offered — a ledger, not base-tree presence

Launchhouse: a note applies iff present in upstream's tree and absent from the base commit's tree, or standing in `held.tsv` (`LH:update.sh:802-820`). That rule breaks LogicLoom's first run after bootstrap (after the old updater, `.sdd-sync-ref` already points at the tree that contains the notes, `v6.6.2:SKILL.md` Step 8), drops declined notes (A §3.2), and — as both reviewers showed — my earlier "check fails → re-offer" patch could never surface a `project-data` note or an advisory note after handover, and did not survive a re-clone. Replaced:

> A note is **offered** iff it is in the upstream tree **and** any of:
> (a) its id has **no row in the ledger**;
> (b) it has an executable check, that check exits non-zero against the read-only export of HEAD (1.7), and its ledger row is not `declined-final`;
> (c) its ledger row is `held`.

Ledger rows: `id<TAB>outcome<TAB>note-blob<TAB>upstream-sha<TAB>date`, outcome ∈ `applied | acknowledged | declined | declined-final | held`. `acknowledged` is for advisory notes (nothing to apply; the user was told). `declined-final` is written for `project-data` notes and for `check: none` notes (there is nothing to re-test). A `declined` note whose check still fails is re-asked in one line ("you skipped this before — still skip?") **only when its `note-blob` changed upstream or the user asks** `/update-loom --revisit`; otherwise the decline stands (Codex #15: snooze, do not nag).

Consequences, each one a finding closed: handover offers every 7.0.0 note because the ledger is empty (agy 1.1, Codex #9); the retired-plugins note is offered once and its "the user has been told" done-when is satisfied by an `acknowledged` row, which is machine-checkable (agy 4.3); `check: none` is defined — offered once via (a), never via (b) (agy 4.5); a re-clone carries the ledger because it is tracked (agy 2.4); undo restores the ledger because it is inside the reverted commit (agy 5.3). Notes and checks are read from `refs/loom-upstream/main` into state at plan time, never from the working tree (`LH:update.sh:780-787`; B §5.4 point 2).

**Rows for an offered note when the three-way engine has none** (agy 1.1): after handover, base = T = upstream for 7.0.0 files, so a file the customer left as `conflict-review` in the old run classifies `keep` (mine ≠ theirs, theirs = base) and produces no row. Rule: for every path a *offered* note touches whose class is `keep`, the engine emits a **two-way held row** with base `-`, mine and theirs — exactly the shape `project-data` rows already have (4.2). The adapter is briefed with the note and both sides. The `handover` base rung (3.2) recovers a true base when a pre-update tag survives, which turns those rows back into ordinary three-way merges; the two-way row is the fallback when it does not.

### 1.6 Notes tree is upstream-owned

Any path under `plugins/loom-maintenance/updates/` that differs from upstream is `take`/`delete`, never held or kept (`LH:update.sh:560-576`), and is exempt from `.gitignore` suppression (`LH:update.sh:381-386`). A customer cannot edit a safety note away. The same rule covers the engine, tools and `BUNDLE.sha256` under `plugins/loom-maintenance/scripts/`: a customer who edited the engine gets upstream's, with their copy preserved in `mine/<update-id>/` and the pre-update tag, and is told so.

### 1.7 Check contract

Runs as `sh <file>` with `REPO_ROOT` exported and **cwd = a read-only export of the tree under test** — at plan time `git archive HEAD | tar -x` into `<state>/export/`, `chmod -R a-w`; at stage time the apply worktree; after landing the live tree (the user has approved by then). POSIX sh + awk only. Exit 0 = purpose holds. Last line on failure: `hint=<one plain sentence>`. **New**: last line `skip=<reason>` with exit 0 means "not applicable in this copy" (e.g. `amendments.md` absent) — distinct from pass; the note is recorded `acknowledged`, not `applied` (agy 4.2). JSON is read by content via `json-flat.sh`, never by line shape (lesson A §2.2 #8).

**A check that writes anything fails the run** (Codex #8): the runner snapshots the export (`find -newer` sentinel plus `git status --porcelain` in a worktree) before and after each check; any new, changed or removed path, or any ref change in the repo, is `FAIL check-wrote=<path>`. This is before/after verification, not a sandbox; the floor has no sandbox. The linter adds static rules for check bodies: no `git ` other than `git show|ls-tree|cat-file|rev-parse`, no `curl|wget|nc|ssh`, no redirection except into `$TMPDIR`, no `rm -r`, no `eval`, no `. `/`source` of a working-tree file. String rules; defence in depth, stated as such.

Hook commands in LogicLoom's `settings.json` are `bash <relpath>` (`.claude/settings.json:2-89`; kori-beta identical, plus one adopter hook `bash scripts/hooks/guard-prod-db.sh`), so the shipped `hooks-resolve` helper extracts the first `*.sh` token, requires it to exist, be readable and pass `sh -n`/`bash -n`, and **never executes it** (`LH:update.sh:1487-1524`). It gates only on paths under harness-owned trees and warns on the rest. **It is a liveness check, not a preservation check**; preservation is rule R1 in 1.10.

Two check kinds, by note: **safety** — must pass in every copy; missing check, `check: none`, malformed `safety:` or any non-zero exit is FAIL (`LH:updates-checks.sh:165-214`). **Non-safety** — in a customer copy a failure is `WARN` and the standalone run stays green; in the template repo it is FAIL (`LH:updates-checks.sh:93-105, 204-206`). The hold-back pass (`LH:update.sh:1855-2072`) re-runs each non-safety check in the worktree and sets aside the failing improvement **and every note that `requires` it, transitively** (agy 2.3); each is reported as `held because <blocker> failed in your copy`. Copy-mode detector: the engine carries its own `copy_mode()` with the five marker paths (`tests/lib/tree-provenance.sh:28-40`); a contract test asserts the two lists are identical, because `tests/` is not in the adopt payload (`payload-manifest.txt:458`; Codex #16). Absent `tests/` is a customer copy, the safe direction.

### 1.8 Linter

Port of `LH:updates-lint.sh:155-236` plus: `removes` absent upstream; `project-data` allowlist and required `pattern`; protected-path/posture/security-surface ⇒ `check` required and `safety` inference; per-row `channels` suffix ∈ {`@both`, `@template`, `@adopted`}; forbidden-touch set (including the ledger); overlap groups; `requires` acyclic and pointing at the same or an earlier release; `relaxes` entries verbatim and `safety: false`; check-body static rules (1.7); a `## Example` section required when `project-data: true` (the worked example ships in the note, not in `tests/`, Codex #16); no `ID_MARKERS` (`leak-guard.sh` list: `brian@kelleysd.com`, `kelleysd.com/`, `ioun-ai`, `/workspaces/`) and no `~/.claude` reference in any note body (B §0.7). Runs in `plugin-tests.yml`, in `/promote` step 2, and first inside `updates-checks.sh`.

### 1.9 `requires` chains, declined notes

`requires` is schema-only in Launchhouse (A §1.13). Here: `--plan` orders notes topologically; a note whose `requires` names a declined or held note is shown as **blocked** with the blocker's title and is not applied; a safety note may not `requires` a non-safety note (linter) so the half-applied case in LH risk 3 cannot arise; and hold-back cascades to dependents (1.7). Declined: 1.5.

### 1.10 Security invariants — deterministic, between the adapter and the tree (new)

The adapter's prose rules ("never drop a base hook, never loosen a permission") stay, but they are no longer the only line (Codex #7, agy 3.1). `security-invariants.sh` runs in three places with the same code: inside `--adapt-save` (refuse the body), in the `--stage` gate (fail the commit) and in post-landing smoke (auto-undo). Inputs are the `mine` side (the customer's current file), `theirs` (upstream's), the candidate, and the approved notes' `relaxes` lists. Flattening is `json-flat.sh`; conf files are read line-wise.

| Rule | Surface | Invariant (candidate vs mine) |
|---|---|---|
| R1 hooks | `.claude/settings.json` `hooks` | every `(event, matcher, command)` triple in mine is present in candidate, unless the command's script path is listed in an approved note's `removes:`; no matcher of a surviving triple changes; adopter triples (command outside harness prefixes) are always preserved |
| R2 permissions and verdicts | `settings.json` `permissions.{allow,ask,deny}`; `tool-restrictions.json` block/warn lists; `gate-policy.conf` `<op> = ask|silent`; `governance.conf` `protected_paths` | `deny ⊇ mine.deny`; `allow ⊆ mine.allow ∪ theirs.allow`; `ask ⊇ mine.ask − candidate.deny`; no `tool-restrictions` pattern removed and no action downgraded (`block`→`warn`); no verdict `ask`→`silent`; no `protected_paths` line removed. Exactly the entries in an approved `relaxes:` list are exempt, and only those |
| R3 retention (markdown) | any `*.md` the adapter edits for a non-`project-data` note | every `#`/`##`/`###` heading in mine is present in candidate unless listed in `may-drop-headings`; candidate is non-empty |
| R4 bounded edit (`project-data`) | the allowlisted file | `diff mine candidate` deletions are all lines matching `pattern`; insertions are allowed; nothing else may change |
| R5 shape | all JSON surfaces | parses with upstream's `json-valid.sh` saved at plan time (`LH:update.sh:871-876`); key set of mine outside `hooks`/`permissions` unchanged (an adopter's `enabledPlugins` survives, `kori-beta/.claude/settings.json:2-4`) |

`.claude/policies/tool-restrictions.json` is added to the shipped `governance.conf` `protected_paths` (syntax `governance.conf:44-56`), along with `framework-upstream.conf`, `plugins/loom-maintenance/scripts`, `plugins/loom-maintenance/updates`, and the two agent files — the updater may not be rewritten by a subagent, and a main-agent edit asks (orchestrator finding; B §5.4 lists all of these as currently unprotected). Those lines ship in the template's `governance.conf` and reach existing customers as a 7.0.0 safety note (`governance-protected-paths`), held and adapted like any posture file.

What R1–R5 cannot do: judge whether a *new* upstream hook is wanted (that is the note's purpose), or detect a redirected command that points at a different, existing, harmless script (R1 pins the command string, so a redirect is a dropped triple and is refused — but a redirect *upstream intends* must come as a `take` of upstream's blob with `removes:` naming the old script). Stated as the limit.

### 1.11 Trust root (new)

The upstream URL is read from the **committed HEAD blob** `HEAD:.logic-loom/config/framework-upstream.conf`, never the working tree (Launchhouse lesson, `LH:update.sh:83-91`; today's extractor reads the working tree and prefers `LOOM_UPSTREAM_URL` from the environment, `extract-proposals.sh:93-105`, `framework-upstream.conf:14-18`). The env override survives only as `--upstream-url <url>` on the command line, which the engine refuses unless `--i-am-pointing-at-a-fork` is also given, prints in `--status`, and the skill must read back to the user before fetching. `--status` also prints the URL whenever it differs from the shipped default (`kelleysd-apps/LogicLoom`, `:33-34`): "this copy pulls updates from X". With `framework-upstream.conf` on `protected_paths`, a subagent cannot repoint it and a main-agent edit asks. Trust therefore reduces to: the committed URL, GitHub TLS, the notes tree being upstream-owned, checks running against an export with write detection, and the bootstrap rule (run upstream's engine when the local one differs). None of that is cryptographic verification; signing the bundle is listed in 7.3 as not provided.

---

## 2. The `/update-loom` flow

Actors: **engine** (`update-loom.sh`, deterministic, POSIX sh); **skill** (main agent, the only thing that talks to the user and the only thing that types git); **update-adapter** and **update-reviewer** (project agents, `tools: Read, Grep, Glob`, no Bash — the engine pre-writes every diff and log they need into state, so the reviewer's `git show/diff/log` allowance in `LH:update-reviewer.md:18-20` is unnecessary and its prose-only enforcement is gone); **user**.

### 2.1 Git operations mapped to `gate-policy.conf` (constraint A)

The hooks are a string gate on the command the agent types (`git-safety-gate.sh:12-16`); git run inside `sh update-loom.sh` is invisible to them (B §5.3). `gate-policy.conf:153-156` says why worktree writes ask: "an agent that can add a worktree can stage work outside the tree you are watching". This design does exactly that, deliberately, and narrows the invisible set as far as it can:

| Step | Who runs it | Where | Gate verdict | Why acceptable |
|---|---|---|---|---|
| `git fetch <url> +refs/heads/main:refs/loom-upstream/main` | engine (`--plan`) | local ref only | `git.fetch = silent` (`gate-policy.conf:208`) | same as today's extractor |
| `git tag loom/pre-update-<ts>` | engine (`--stage`) | local tag | `git.tag.write = silent` (`:178`) | the old skill does the same (`v6.6.2:SKILL.md` Step 6). Never deleted by the engine |
| `git worktree add --detach <state>/wt HEAD`, `git add`, `git commit`, `--amend` (hold-back), `worktree remove` | engine (`--stage`, `--abandon`, `--finish`) | inside `.git/loom/update/`; live tree untouched | `worktree.write = ask` (`:156`) **when typed**; here invisible. `git.commit = silent` (`:167`) | **Detached**: no branch is created, so `branch -D` (`branch.write = ask`, `:151`) leaves the list entirely. The user approves the enumerated transaction before `--stage` runs (step 6). Reversibility 0: nothing in the working tree changes; the refusal set (`is_clean`, HEAD and upstream unchanged since plan, `LH:update.sh:1631-1653`) runs first. Decision 9.2 keeps the fully visible alternative |
| **`git merge --ff-only <staged-sha>`** | **skill, typed visibly** | live branch | **`git.merge = ask` (`:103`)** | the governance prompt; the moment the live tree changes; where Principle VI's approval belongs. The command names a sha, not a protected token, so `protect-governance-files.sh`'s Bash branch stays quiet |
| post-landing smoke, auto-undo via `git revert --no-edit` | engine (`--finish`) | live branch | `git.revert = silent` (`:196`) | additive by construction; verified by content (`LH:update.sh:2439-2448`); only runs when smoke fails, which the user is told |
| `--undo <id>` → `git revert --no-edit <recorded commit>` | engine, after the user says "undo" | live branch | silent | same |
| `git reset --hard` | **never** | — | `ask` (`:120`) | Launchhouse's undo-verification failure path (`LH:update.sh:2522`) is replaced: `git revert --abort` where a revert is in progress, otherwise print `result=reverted-failed`, `pre_update_tag=` and stop; a person decides |
| `git push` | **never** | — | FLOOR (`:90`) | Launchhouse's skill pushes (`LH:SKILL.md` step 10.1); LogicLoom does not. `/git-push` is the user's path |

**Subagents** (agy 3.4, Codex #6 residual): neither agent has Bash, so no agent in this flow can run the engine or git. Landing requires a typed git command, which `subagent-git-guard.sh` denies for any subagent (`gate-policy.conf:56-58`). A subagent outside this flow could today run `--stage`. The engine cannot detect a subagent caller (UNVERIFIED: no environment marker, B §5.3), but the hook can: `subagent-git-guard.sh` already sees `agent_id` on every subagent Bash call (`subagent-git-guard.sh:16-21`). Add one pattern to its deny list — any command invoking `update-loom.sh` with `--stage|--finish|--undo|--abandon|--set-base|--adapt-save` from a subagent is **denied**. Same string-gate floor as the rest; a governance-file edit, so main-agent ASK at build time.

**Protected-path writes** (`.claude/settings.json`, hooks): the engine writes them only in the worktree; they reach the live tree through the gated merge. The adapter never writes anything (constraint H); the skill saves its returned body with `--adapt-save`, which validates path membership, the forbidden set, symlinked parents, JSON validity with upstream's validator saved at plan time (`LH:update.sh:968-1081`, `:871-876`), and rules R1–R5.

**All engine writes** (take, add, adapt-save, delete) go through one `write_path`: every parent component is `lstat`ed (`[ -L ]` in sh) and a symlink anywhere refuses; the body is written to a temp regular file in the same directory and renamed into place; modes mirror upstream's `ls-tree` entry on disk and in the index (`LH:update.sh:726-753`). The classifier compares mode as well as blob: equal blobs with different modes are class `mode` and take upstream's mode when the customer's mode equals base's, else hold (Codex #13; A §3 finding 9).

### 2.2 Step by step (both channels; channel differences in brackets)

0. **Preflight** (skill → engine `--status`): channel (1.4), `clean` (ignores untracked files outside harness paths — kori has an untracked `.claude/launch.json`, B §2), `in_progress`, `shallow` (`git rev-parse --is-shallow-repository`; if `true`, stop with "run `git fetch --unshallow origin` first" — the base-reachability test is unreliable in a shallow clone; agy 7.2, UNVERIFIED how git behaves, so the engine refuses rather than guesses), stale-lock self-heal (`LH:update.sh:1567-1601` pattern; agy 7.3), upstream URL (1.11), **bundle** (`BUNDLE.sha256` verified: `bundle=complete` or `bundle=incomplete missing=<paths>` → stop, 3.2). **Bootstrap check** (section 3): if the local engine differs from upstream's copy, run upstream's copy from `<gitdir>/loom/bootstrap/` for this one update (`LH:SKILL.md:18-32`). Dirty tree → stop and ask the user to commit; the skill does not commit for them.
1. **Base** (`--detect-base`), ladder in order: (0) **`handover <B0>`** — ledger has no rows, `.sdd-sync-ref` is reachable from upstream, the newest `loom/pre-update-*` tag is an ancestor of HEAD, and `<tag>:.sdd-sync-ref` resolves to a commit reachable from upstream → base = that older stamp B0 (agy 1.2: the rung is now first, so it can fire); (1) `recorded <sha>` from `.sdd-sync-ref` if reachable; (2) the known-bad remap (`extract-proposals.sh:140-153`, kept); (3) `closest <sha> <n>` by fewest differing harness-owned files across first-parent public history (`LH:update.sh:300-330`), confirmed by the user; (4) `none` → stop with the repair text from `KNOWN_ISSUES.md:55-112` and the `update-bootstrap` command (3.3). `--set-base` commits `.sdd-sync-ref` alone (lesson A §2.2 #15; `git.commit = silent`).
2. **Plan** (`--plan`, 10-minute Bash timeout, idempotent): fetch; copy notes+checks from upstream into state; export HEAD read-only; classify every path (blob and mode); apply channel map; compute offered notes (1.5) and overlap groups; run applicability checks against the export with write detection; emit two-way rows for `keep` paths under offered notes; write `plan.tsv`, `notes.tsv` (columns: `blocked`, `declined-before`, `group`, `untouched`), `adapt.tsv` with base/theirs/mine sides, `diffs/`, `reviewer/<path>.log`, and `transaction.txt` (the exact git mutations `--stage` will perform). If every row is `keep`/unchanged and no note is offered: "You are up to date."
3. **Digest and questions** (skill, AskUserQuestion, batched — up to four questions per call, UNVERIFIED exact cap): one screen. **Listed, not asked**: safety notes (cannot be declined; shown as "will be applied"); non-safety notes whose every touched file the customer never changed (`untouched`), applied under the final yes **with a per-item opt-out** ("take all except…"). **Asked**: each overlap group containing a note with a held or two-way row — *Take this update* / *Keep mine as it is*; `project-data` — *Adapt my file* / *Leave it (final)*; declined-before whose note changed — one line, *Still skip* recommended. Blocked: shown, not asked. Paths no note covers (the bootstrap span only): one group, "other upstream changes", with the reviewer's bullets. This restores Launchhouse's quiet handling of untouched files (A §3.1) while keeping per-improvement decline reachable (agy 6.1, Codex #15).
4. **Adapt** (skill dispatches `update-adapter` per held or two-way row whose group was approved, concurrently): brief = path, the sides from state, the approved notes' purpose/done-when/body/`## Example` (`LH:update-adapter.md` rules carry over, now backed by R1–R5). Skill writes the body to `state/adapt/out/<path>` and calls `--adapt-save`, which applies R1–R5 and refuses with the rule name. **`cannot-adapt`/refusal/invariant-refusal on a safety note → `safety-unresolved`**, never `take-theirs` (Codex #5, agy 2.1). The engine writes `state/unresolved/<path>.lost.diff`: the hunks of mine that would disappear under a full replacement. Non-safety → `hold`.
5. **Second read** (`update-reviewer`, read-only): waterfall items 1, 3, 7, 8 of `LH:update-reviewer.md` (dependency grep, settings customisation, merged-clean sense read, adapted-vs-purpose) plus: *is each prose done-when checkable and does it match the purpose* (LH §11 Q3). The reviewer may make a row more cautious (`hold`) **or route a `merged-clean` row to the adapter** (`adapt`), in which case step 4 runs for that row before step 6 (agy 2.2: the reviewer can cause a fix, not only a stall).
6. **Show, resolve, one yes** (skill): what is new; kept as you made it; one sentence per adapted file; held items with reasons; blocked items; **for each `safety-unresolved` file: the exact customisations that would be lost (from `.lost.diff`), and the two choices — *Replace my file* (recorded as `take-theirs` with `informed=yes`) or *Stop the update* (nothing lands)** — "safety cannot be skipped" means the update cannot proceed, not that the engine may overwrite; then the enumerated transaction (`transaction.txt`: "tag; detached worktree; one commit; then I will ask you to approve the merge"); then one clear yes. Developer audience: paths and a diff on request, never pushed (A §4.3).
7. **Stage** (`--stage decisions.tsv`): closed vocabulary `apply|take-theirs|keep-mine|hold|adapted|acknowledge|decline|decline-final`, anything else refused before touching anything (lesson A §2.3 #22); `take-theirs` on a safety row requires `informed=yes` in the same row; pre-update tag; detached worktree; per-row writes through `write_path`; ledger rows and `.logic-loom/memory/updates/<update-id>.applied` written **into the worktree**; `.sdd-sync-ref` bumped in the same commit; one commit "LogicLoom update to <sha12>"; hold-back with cascade; gate: notes' checks, R1–R5 on every security surface, `settings.json` valid JSON, hooks resolve, protected-tree equality, **staged-path allowlist** — the commit's path set must equal the union of approved notes' `touches`/`adds`/`removes` plus the engine's own records; anything else aborts (Codex #1, path-level) — fail-closed if a safety note is in the plan and the check machinery is missing (`LH:update.sh:1297-1341`). Prints `staged=<sha>`, `tag=`, `held=` lines, or `result=aborted unchanged=yes`.
8. **Land** (skill types `git merge --ff-only <staged-sha>`): the gate asks; the user approves. Declined → skill runs `--abandon` (worktree removed, tag kept and named; nothing changed).
9. **Finish** (`--finish`): post-landing smoke on the live tree (checks again, R1–R5, JSON valid, hooks resolve, no tracked harness file differs from the commit); failure → `git revert` + content verification → `result=reverted` or `reverted-failed`; removes the worktree. No `.git`-local bookkeeping is load-bearing after this point.
10. **Report** (skill): three outcomes — Updated / Updated with some held back / Stopped — plus `reverted-failed` worded as "pause, ask for help, tag kept" (`LH:SKILL.md` step 10). Held-back notes are named with "its check failed in your copy" so a forgotten safety flag is at least visible (agy 3.3 residual). Then "run `/git-push` when ready" — the engine never pushes. Suggest a fresh session so new commands load (UNVERIFIED whether Claude Code reloads `.claude/commands/*.md` mid-session, B §7).
11. **Undo** (`--undo [<update-id>]`, default the newest `.applied` record): reverts only the recorded commit, which must look like an update commit and whose parent is verified (`LH:update.sh:2455-2500` pattern); refuses on dirty tree; verifies every touched path's blob **and mode** against `<commit>^` (not the tag, so it works on any clone — the tag is a convenience); refuses a commit touching the forbidden set; on overlap with later edits, `revert --abort` and name the paths. Because the ledger, `.applied` record and `.sdd-sync-ref` are inside the commit, the revert restores the bookkeeping transactionally (agy 5.3, Codex #14), and the next plan sees base = pre-update, so the undone files are taken again as untouched (agy 5.1 refuted on this ground). Undoing an older update beneath newer ones is refused with the list.

**Prompt count per update**, stated honestly: one question screen per overlap group that needs a decision (a stock copy taking 7.0.0: one screen, possibly none), one final yes carrying the transaction, one governance ASK on the merge. Plus a `protect-governance-files` ASK only if the skill edits a protected path by hand, which the flow never does. Retired-directory removals the user chooses are offered as **one** `git rm -r a b c` command (one ASK, `gate-policy.conf:142`), typed only if they want it.

---

## 3. Bootstrap: from 6.x to the new engine (constraint C)

### 3.1 Correction to the brief's premise

The receipt filter the brief cites (`extract-proposals.sh:592-606`) exists only on `dev-main` since `39b59d5` and in no tag or npm version; `v6.6.2:extract-proposals.sh` is 428 lines with zero occurrences of `adopt_file_recorded|ADOPT_MODE|detect_adopt_mode` (verified by `git show v6.6.2:… | grep -c`; B §0.1; pinned by `test_update_from_6x.sh:62-72`). So an adopted 6.6.x install receives the same unfiltered `sync-ref..upstream` diff a template clone does: every new file is a `clean-add`. Nothing has to "get through" a filter.

### 3.2 The path, both channels

1. Customer runs `/update-framework` (their 6.6.x copy). It fetches, diffs `.sdd-sync-ref..refs/loom-upstream/main`, and offers (`v6.6.2:SKILL.md` Step 4, "accept all" or per-file, `:124`): `clean-add` for the engine, JSON tools, invariants script, linter, checks runner, `BUNDLE.sha256`, `updates/7.0.0/*`, skill, `update-loom.md` command + bridge stub, the two agents, `retired-plugins.txt`, `update-channels.conf`, regenerated `.bridge-manifest.json`; `clean-apply` for `plugins/loom-maintenance/commands/update-framework.md` when pristine, `conflict-review` when customised. The old skill writes with `git show > path` (Step 7) — mode 644, which is why every new script is invoked as `sh <path>` and never relies on the exec bit.
2. **`update-framework.md` in 7.0.0 is not a forwarding stub** (Codex #2). It keeps the complete old procedure and gains a 12-line **handover preamble**: "Run `sh plugins/loom-maintenance/scripts/update-loom.sh --status`. If it prints `bundle=complete`, stop here and run `/update-loom`. If it prints `bundle=incomplete missing=…`, re-run this command and accept those paths, or run `npx logicloom@7 update-bootstrap`. If the file does not exist, continue with the procedure below." A partial accept therefore never disables the only updater; the old flow stays whole until the new one proves it arrived. The 15-line forwarding stub (3.4) ships in 7.1.0, through the new engine, where the updater tree is upstream-owned (1.6) and arrives whole.
3. The old skill tags `loom/pre-update-<ts>` (Step 6), commits, and advances `.sdd-sync-ref` to T (Step 8).
4. **First `/update-loom` run — handover.** The ledger is empty, so rule 1.5(a) offers every 7.0.0 note regardless of `.sdd-sync-ref`. `--detect-base` rung (0) reads `<tag>:.sdd-sync-ref` = B0 from the pre-update tag when it survives, so files the customer left as `conflict-review` in the old run classify as both-changed against B0 and go through ordinary adaptation. Without the tag, base = T and those files get two-way held rows under their notes (1.5). Both paths reach the adapter; neither depends on the other.
5. From then on, only `/update-loom`.

**Adopted channel specifics**: the old path also offers `tests/` and `.github/` changes that are not the adopter's (B §2). That is why 7.0.0 must be thin **by construction** (3.6), not by intent.

### 3.3 Who cannot get there through the old path — and the shipped remedy

- `.sdd-sync-ref` not an ancestor of public `main` and not in the two-entry remap: v6.3.0/v6.4.1/v6.5.0 tag clones carry `c6092b0` (verified: `git merge-base --is-ancestor c6092b0 origin/main` exits 1). The 6.6.2 extractor exits 3.
- Missing `.sdd-sync-ref`: the old script baselines at tip and adopts nothing (`v6.6.2:extract-proposals.sh:149-155`); the engine never arrives through that path.
- Pre-6.2 (`.specify/`) layouts: out of scope, as today.

**`npx logicloom@7 update-bootstrap` ships in 7.0.0 (Phase 3, a release prerequisite — agy 1.3, Codex #3).** It is a payload group `updater` containing exactly the bundle; it bypasses the already-adopted refusal (`preconditions.js:416`) for this subcommand only; works in both channels (a template clone is a git repo with the same paths); records a receipt run (adopted) or nothing (template); writes `.sdd-sync-ref` to the upstream tip when missing or unreachable **after telling the user what that means** — and under the ledger rule it means little: every note is still offered, and customer-changed files become two-way rows. Then the user runs `/update-loom`. The manual repair in `KNOWN_ISSUES.md:55-112` remains documented for people who prefer it.

### 3.4 What `/update-framework` becomes

7.0.0: the old procedure plus the handover preamble (3.2). 7.1.0: a ~15-line **forwarding stub**: "This command was renamed `/update-loom`. Run it; if it is not available in this session, start a new session, or run `sh plugins/loom-maintenance/scripts/update-loom.sh --status`." Not a tombstone (old npm installers print the old name forever, `preconditions.js:416`, `detect.js:625`), not an alias (the bridge manifest maps one name to one source, `.bridge-manifest.json:27`). The `framework-updater` skill directory is removed in 7.1.0; `plugin.json:24,38` lists change; `leak-guard.sh:150-151` KEEP zones move to the new paths.

### 3.5 The tests that prove it

`tests/contract/test_update_from_6x.sh` keeps its harness (`archive_v662_tree`, `init_fixture_repo`, `build_sanitized_upstream_tree`, `graft_synthetic_upstream`, the fresh-process extractor runner, `:202-290`) and changes its assertions: (1) both fixtures see every path in `tests/fixtures/update-from-6x/v7-machinery-paths.txt` as `clean-add`/`clean-apply`; (2) `update-framework.md` is `clean-apply` and still contains the full old procedure; (3) **partial accept**: accepting only the command and skill leaves `--status` absent, and the fixture's old `/update-framework` procedure is intact; accepting everything but one bundle file yields `bundle=incomplete missing=<that file>` (Codex #2); (4) after full acceptance, the fixture's own `update-loom.sh --status` and `--plan` run on the 6.x-shaped tree (run the accepted tool, not this tree's copy, `test_update_from_6x.sh:~49-56`); (5) handover with an empty ledger and `.sdd-sync-ref` at T offers all 7.0.0 notes, including the `project-data` ladder note against a planted `amendments.md` and the retired-plugins note against an unwired `plugins/sdd-debug/`; (6) handover with a surviving tag recovers B0 and produces three-way rows; without the tag, two-way rows. Maintainer-only (skips on a sanitized tree via `tree-provenance.sh`).

### 3.6 Release shape is enforced, not promised (Codex #4)

`origin/dev-main` is 192 commits ahead of `v6.6.2`: 250 files, +31,696/−975, across `.docs` (56), `plugins` (37), `.logic-loom` (36), `packaging` (30), `.brain` (26), `tests` (19), `.claude` (17), plus `CLAUDE.md`, `AGENTS.md`, `README.md`, `START_HERE.md`, `VISION.md` (verified: `git log --oneline v6.6.2..origin/dev-main | wc -l`, `git diff --stat`). Promoting dev-main as 7.0.0 cannot be thin. Two shapes are possible and decision 9.3 chooses:

- (a) **Bootstrap branch**: `release/7.0.0` = `origin/main` (the v6.6.2 tree) + the bundle + the handover preamble + `retired-plugins.txt` + the `governance.conf` lines, nothing else; promoted as 7.0.0; dev-main's 192 commits follow as 7.1.0 through the new engine with the channel map in force. Needs `promote-to-main.yml` to accept a source ref other than dev-main (plumbing, Phase 3). The CLAUDE.md trim, doc moves and every other content change wait for 7.1.0.
- (b) **Fat 7.0.0** from dev-main: everything arrives through the old updater, including root `CLAUDE.md`, `tests/`, `.github/` offered to adopters they must decline by hand (B §2).

Either way, a maintainer-only gate `bootstrap-shape.sh` runs at `/promote` for a release flagged `bootstrap` in its notes folder: the shipped diff from the previous tag, after strip, must be a subset of `BUNDLE.sha256` paths plus an explicit allowlist in the release's `README`. It fails otherwise. Under (b) the gate is skipped and the risk is accepted in writing.

---

## 4. Worked cases

### 4.1 Case 6(a): a retired plugin directory, pristine or customised

**Grouping decision**: four notes, one per retirement family (decision 9.1). Families from `release-migrations.conf:58-84`: `retired-plugins-renamed` (7 `sdd-*` → `loom-*`), `retired-plugins-domain-briefs` (7 → `plugins/loom-governance/domain-briefs/<d>.md`), `retired-plugins-native` (`sdd-dev-loop`, `loom-dev-loop`, `sdd-debug`, `sdd-domain-template`), `retired-components` (`sdd-marketplace` MCP + `.mcp.json` entry, `src/sdd/__init__.py`, `.specify/config/refinement.conf`, `plugins/migrate-to-plugins.sh`, `plugins/create-domain-plugin.sh`). Each note's body carries the family table (name → successor → what to do).

**No ownership inference, and why the engine cannot see these at all**: public `main` was re-rooted at v6.2.0 (`0e28655`, verified `git rev-list --max-parents=0 origin/main`), after every `sdd-*` plugin was gone; `git log origin/main -- plugins/sdd-debug` is empty (verified). There is no pristine blob to compare against, and in a 6.6.x customer's base tree the dir is absent too, so to the three-way engine `plugins/sdd-debug/` is an unchanged local-only path — the customer's, as far as git can tell. The design does not guess. The note tests the **outcome** (is anything still routed through it) and offers the deletion as the user's own command:

```
---
id: retired-plugins-native
title: Plugins replaced by Claude Code's own features
purpose: Nothing in this project routes a hook, command, MCP server or bridge stub through sdd-dev-loop, loom-dev-loop, sdd-debug or sdd-domain-template, which were replaced by native /workflow, /loop and /goal and by /create-plugin.
touches:
  - .logic-loom/config/retired-plugins.txt
removes:
  - plugins/sdd-dev-loop
  - plugins/loom-dev-loop
  - plugins/sdd-debug
  - plugins/sdd-domain-template
adds: []
requires: []
safety: false
done-when:
  - "no hook command in .claude/settings.json names a path under any of the four directories"
  - "no .claude/commands/*.md bridge stub points at any of them"
  - ".mcp.json names no server under them"
  - "the ledger records this note as applied or acknowledged"
check: retired-plugins-native.check.sh
project-data: false
---
## What changed and why
These four plugins were removed in v5.1.0 and v6.2.0 (sdd-debug had no successor; sdd-dev-loop was superseded by native /workflow, /loop and /goal; sdd-domain-template by /create-plugin). A copy may still hold the directory. LogicLoom never deletes it: it may carry your own edits, and nothing in git can tell your work from a stale copy. If nothing is wired to it, keeping it is harmless.
## What a stock file looks like after
.logic-loom/config/retired-plugins.txt lists the four names; nothing else changes unless you remove a directory yourself.
```

Check (POSIX sh, ~60 lines): flatten `settings.json` with `json-flat.sh`; non-zero if any `/hooks/*/*/hooks/*/command` value contains `plugins/sdd-dev-loop/` etc.; non-zero if any `.claude/commands/*.md` contains the path; non-zero if `.mcp.json` (when present) names it; for each directory present on disk print `WARN plugins/sdd-debug is on disk; nothing is wired to it; replaced by: (none). To remove it yourself: git rm -r plugins/sdd-debug` — exit 0. Last line on failure: `hint=Something in your settings or commands still points at a retired plugin; take this update and the pointer is removed, your directory stays.` Planted-defect fixture: a `settings.json` with one hook under `plugins/sdd-debug/`. The note is **offered once via the ledger** regardless of the exit code (1.5), which is what makes done-when item 4 true and testable (agy 4.3).

Flow: pristine or customised, the directory is **kept**; the user is told once per family, with the exact command, and may have the skill type one combined `git rm -r …` (one ASK, `gate-policy.conf:142`). The wiring, if any, is adapted by `update-adapter` in `settings.json`/stubs under the normal held-row flow with R1 in force. CI stays green through `retired-plugins.txt` feeding the six tolerance consumers (B §0.9; verified those consumers on `origin/dev-main` do not yet reference `release-migrations.conf`, so the flat list is a fresh addition, not a revert). For retirements **after** 7.0.0 the pristine blob exists in public history, so the ordinary classes apply: unchanged → `delete` (taken under the note's yes), changed → `deleted-upstream-kept` (hold → kept unless the user says remove, `LH:update.sh:662-663`).

### 4.2 Case 6(b): kori-beta's escalation ladder

The file `.logic-loom/memory/amendments.md` is fork-authored (`constitution.md:313-318`: amendments have "no upstream counterpart"). kori's copy at `:148` carries `- 3 = it changes auth, payment, or customer-data logic` as a fourth line on the same scale as the 0/1/3 reversibility lines (read directly; `kori-beta/.logic-loom/memory/amendments.md:142-148`). LogicLoom never shipped that text; the only public ladder doc has no numeric scale (B §0.7). An honest note:

```
---
id: amendments-ladder-plus-three
title: Escalation ladder: the auth/payment line is a +3 on top, not a fourth 3
purpose: A fork's escalation ladder that lists "it changes auth, payment, or customer-data logic" as another 3 on the reversibility scale under-scores a reversible auth change; the current form treats it as +3 added on top of whichever reversibility line applies.
touches:
  - .logic-loom/memory/amendments.md
adds: []
requires: []
safety: false
done-when:
  - "no line in amendments.md scores the auth/payment/customer-data case as a bare 3 on the reversibility scale"
  - "every other line of the file is byte-identical to before"
check: amendments-ladder-plus-three.check.sh
pattern: '^-[[:space:]]*3[[:space:]]*=[[:space:]]*it changes auth, payment, or customer-data logic'
project-data: true
---
## What this note may claim
Only this: your file matches a known defect pattern. It may not claim LogicLoom shipped the ladder text (it did not), may not cite any maintainer's personal files, and carries the target wording itself:
  Plus, on top of whichever reversibility line applies:
  +3 — it changes auth, payment, or customer-data logic
## Example
Before: "- 3 = it changes auth, payment, or customer-data logic" as the fourth bullet under "Cost if this turns out wrong".
After: that bullet removed; the two lines above inserted after the 0/1/3 bullets; nothing else changed.
```

Check: if `amendments.md` is absent → `skip=no amendments file in this copy`, exit 0 (agy 4.2: an adopter with no file is not a pass, it is not-applicable). Otherwise `grep -E "$pattern"` → non-zero on match with `hint=Your escalation ladder scores the auth/payment case on the wrong scale; "Adapt my file" fixes that one line and keeps the rest.` Planted-defect fixture: the kori excerpt. **Retention is not the check's job**: rule R4 in `--adapt-save` refuses any adapted body whose deletions are not all `pattern` lines, so a wiped or truncated file is refused deterministically before it can reach the gate. The engine has no upstream blob: the row is a two-way held row, base `-`, adapter briefed with the note's `## Example` (shipped in the note; the `tests/fixtures/…` copies are for the test only, Codex #16). Declining is final (`declined-final`). The adapter output must keep `apps/mobile/...` and every other mandate byte-for-byte; R4 enforces it, the reviewer's item 8 reads it.

### 4.3 Case 6(c): customised `CLAUDE.md` or `.claude/settings.json`

**`CLAUDE.md`, template channel** (7.1.0 under decision 9.3(a)): upstream changed it (the trim: −208/+26 lines, B §3.5) and the customer changed it → `merged-clean` or `conflict` (`LH:update.sh:670-671`). Note `claude-md-trim` (non-safety): purpose "CLAUDE.md carries only facts about this repo; the directory tree, the `.brain/` contract and the amendments doctrine live in `.docs/`"; `touches: CLAUDE.md @template, .docs/architecture/loom-architecture.md, .docs/policies/project-amendments-policy.md, .brain/README.md` (per-row channel, Codex #12; an adopter's root `CLAUDE.md` is theirs, `payload-manifest.txt:365`); `may-drop-headings:` names exactly the moved sections. **Check asserts on `CLAUDE.md` itself** (agy 4.1, Codex #10): non-empty; contains at least one `#` heading; none of the moved headings present; the three destination docs carry theirs. Planted-defect fixture: a CLAUDE.md still carrying `## Directory structure`. Retention: R3 refuses an adapted body missing any customer heading not in `may-drop-headings`. Held row → adapter brief: remove only the sections that moved, keep every customer section and sentence. On `cannot-adapt`: hold; the customer keeps their file.

**`.claude/settings.json`**: both-changed is always held (`LH:update.sh:666-667`). Template: base = `.sdd-sync-ref:.claude/settings.json`. Adopted: base = `.claude/.logicloom-adopt-settings.json`'s inserted hooks, mine = the adopter's whole file (`enabledPlugins`, their `permissions`, their `bash scripts/hooks/guard-prod-db.sh` hook on both the Bash matcher and the MCP matcher, `kori-beta/.claude/settings.json:84-96`), theirs = upstream's hooks object. Adapter rules carry over; **R1, R2, R5 enforce them**: the adopter's two `guard-prod-db.sh` triples must survive, `permissions.deny` may not shrink, `enabledPlugins` is untouched. `--adapt-save` refuses otherwise and the skill is told which rule. Gate and smoke repeat R1–R5. If the adapter cannot satisfy a safety note without dropping an adopter hook, the result is `safety-unresolved` and the user sees the `.lost.diff` and chooses (2.2 step 6) — the hook is never dropped silently. The write reaches the live tree through the gated merge (one ASK). Any 7.x note that changes hook wiring is a protected-path note with inferred `safety: true` (1.3).

---

## 5. Maintainer side

**How a change becomes a note.** Whoever opens the PR to `dev-main` that touches a shipped path writes or extends a note under `plugins/loom-maintenance/updates/<next-version>/`. The linter (1.8) runs in `plugin-tests.yml` on every push and in `/promote` step 2 (`promote.md:47`).

**Every executable check is proven both ways** (agy 4.4, Codex #10): `tests/contract/test_update_notes.sh` runs every check against (i) the template tree, (ii) a sanitized-template fixture built by `build_sanitized_upstream_tree`, (iii) an adopted-payload fixture built from `payload-manifest.txt` — each must exit 0 or `skip=` — and against a planted-defect fixture under `tests/fixtures/update-notes/<id>/` — must exit non-zero with a `hint=` last line. A check with no fixture directory fails the suite; a check whose body references none of its note's `touches`/`removes`/`pattern` strings fails lint. `LH:upstream-pr.md:95-108` as a test instead of a prompt, extended to all checks and both channels.

**Coverage gate** (`update-coverage.sh`, maintainer-only, stripped): at `/promote` step 2 and as a warning on PRs: compute the shipped diff `<last release tag>..<release source>` after applying `template-strip-manifest.txt` and `sanitize-for-template.sh` exclusions; subtract the union of `touches`, `removes` and `adds` across notes in release folders newer than the last tag; any remaining path fails promotion. A deleted `plugins/<x>/` directory with no `removes` row fails the same way — **this replaces `check-release`**. `promote-to-main.yml:139-145` swaps `test_release_migrations.sh` and `test_update_framework_ownership.sh` for `test_update_loom.sh` and `test_update_notes.sh`, keeping `test_update_from_6x.sh`; `plugin-tests.yml:308-316` likewise.

**Bootstrap-shape gate** (`bootstrap-shape.sh`, maintainer-only): 3.6.

**Channel map generation**: `/promote` step 2 regenerates `.logic-loom/config/update-channels.conf` from `payload-manifest.txt` and fails if it is stale (same pattern as `check-generated-freshness.sh`).

**Release shape rule**: the maintainer standing principle (decision 5) becomes a line in `plugins/CONTRIBUTING.md:110-127`'s release checklist: "every adopter-facing change has a note with a check that can fail; ask what a 6.x copy and a 7.x copy each see."

---

## 6. Retired, salvaged, kept — from study B §3

| File (lines) | Fate | Where it goes |
|---|---|---|
| `plugins/loom-maintenance/scripts/release-migrations.sh` (4,805) | RETIRE | the "is anything still wired to this path" idea → retired-plugin checks (4.1) |
| `.logic-loom/lib/release-migrations.sh` (790) | RETIRE | `loom_is_deprecated_plugin_dir` → read `retired-plugins.txt` (one awk line) in the six consumers |
| `.logic-loom/config/release-migrations.conf` (88) | SALVAGE → 4 notes + `retired-plugins.txt` + the ladder `pattern`; then delete | 4.1, 4.2 |
| `plugins/loom-maintenance/scripts/record-update-writes.sh` (1,556) | RETIRE | decision 9.9 if an uninstall record is wanted |
| `plugins/loom-maintenance/scripts/extract-proposals.sh` (771) | SALVAGE core, retire rest | `fetch_upstream`, `read_sync_ref`, `remap_known_bad_sync_ref`, `ensure_sync_ref` (`:84-206`) → engine's `--status`/`--detect-base`, rewritten in POSIX sh; `resolve_upstream_url` replaced by the committed-HEAD read (1.11) |
| `plugins/loom-maintenance/commands/update-framework.md` (364) | KEEP in 7.0.0 + handover preamble; RETIRE → stub in 7.1.0 | 3.2, 3.4 |
| `plugins/loom-maintenance/skills/framework-updater/SKILL.md` (465) | KEEP in 7.0.0; RETIRE in 7.1.0 | `skills/update-loom/SKILL.md`; the inherited-maintainer-CI warning moves into the new skill; `test_shipped_gates_vs_strip.sh:560-575` retargets |
| `.docs/guides/MIGRATION_GUIDE.md` (614) | SALVAGE prose for the bootstrap note and `FRAMEWORK_SYNC_GUIDE.md`; delete in 7.1.0 | its deletion is a `removes` row |
| `tests/contract/test_release_migrations.sh` (5,568), `test_update_framework_ownership.sh` (2,826), `test_update_framework.sh` (121), `test_update_framework_adopted.sh` (502) | RETIRE | registrations at `run_all_tests.sh:141-142,182-184` |
| `tests/contract/test_update_from_6x.sh` (564) | SALVAGE harness, new assertions | 3.5 |
| `tests/fixtures/update-from-6x/v7-machinery-paths.txt` | SALVAGE, rewrite rows | 3.5 |
| `tests/fixtures/release-migrations/kori-amendments-ladder.{before,after}` | KEEP as the planted-defect fixture for `test_update_notes.sh`; the worked example moves into the note body | 4.2 |
| `tests/fixtures/release-migrations/adopt-receipt-generator-stamp.*` | RETIRE | |
| `test_bash32_floor.sh` (+128), `test_deprecation.sh`, `plugins/test_plugin_lifecycle.sh`, `test_model_agnostic.sh`, `test_plugin_manifest_schema.sh`, `validate-plugin-manifests.py`, `constitutional-check.sh` | KEEP, source `retired-plugins.txt`; reword "run /update-framework" hints | |
| `CLAUDE.md` trim, doc moves | KEEP on dev-main; ship in 7.1.0 under 9.3(a) | note `claude-md-trim` |
| Unrelated fixes in `84c2395` (keyword-backend, cross-check Mode B, graph package name, ladder doc) | KEEP | cherry-pick to dev-main; 7.1.0 |
| `KNOWN_ISSUES.md:8-54` ("FIXED in v7.0.0" entries) | REWORD to the note mechanism; `:55-112` stays true and gains the `update-bootstrap` line | |
| `plugins/CONTRIBUTING.md:110-127`, `FRAMEWORK_SYNC_GUIDE.md:36-47`, `START_HERE.md:156-158,351`, `CHANGELOG.md` `[Unreleased]` | REWRITE for notes | `CHANGELOG.md` stays stripped (`template-strip-manifest.txt:126`) |
| `subagent-git-guard.sh` | EXTEND: deny engine mutating verbs from subagents | 2.1; governance file, main-agent ASK |
| `governance.conf` (template) | EXTEND: `protected_paths` for the updater, agents, `framework-upstream.conf`, `tool-restrictions.json` | 1.10; shipped lines + 7.0.0 safety note |

**Rename blast radius** (B §4, all must move together, split across 7.0.0 and 7.1.0 per 3.4): command + bridge stub + `.bridge-manifest.json:27` + `plugin.json:24,38`; `.claude/agents/framework-sync-agent.md` retired, two agents added to `AGENTS.md:212,254,406,505`, `.claude/context/agents.md:82,129`, `.docs/agents/agent-registry.json:39-46`, `test_plugin_lifecycle.sh:151`, `test_spec006_integration.sh:42,232`; `leak-guard.sh:150-151`; `payload-manifest.txt:197,347,435` comments; `template-strip-manifest.txt:309-311` comments; `framework-upstream.conf:2-26`; `common.sh:640`; templates promising "`/update-framework` will not touch it" (`amendments-template.md:10`, `deploy-seam.sh.tmpl:10`, `check-branch-base.sh.tmpl:25`, `domain-briefs/README.md:40-43`) → "never overwrites; may offer a reviewed change"; `constitution.md:21,314` and `constitution_update_checklist.md:95,205` (protected: main-agent ASK); `README.md:7,200,264`; `VISION.md:227-232,293-316,336`; installer strings stay (`preconditions.js:416`, `detect.js:625`) because old npm versions print them forever.

---

## 7. Size and risk

### 7.1 Lines

| Component | New | Basis |
|---|---|---|
| `update-loom.sh` | ~2,200 | 1,800 portable LH lines (A §5.1) − pack machinery + channel map, base ladder with handover rung, `--stage/--finish/--abandon` split, ledger, two-way rows, overlap groups, staged-path allowlist, export + write detection, `write_path`, mode class |
| `json-valid.sh` + `json-flat.sh` | 430 | verbatim |
| `security-invariants.sh` | ~350 | R1–R5 over flattened JSON and conf lines |
| `updates-lint.sh`, `updates-checks.sh` | ~650 | 243 + 225 ported, plus 1.8 rules, check-body static rules, copy-mode detector, `skip=` protocol |
| Agents (2) | ~160 | |
| Skill + command + handover preamble + 7.1.0 stub | ~380 | |
| Notes + checks for 7.0.0 (6 notes: 4 retired families, `governance-protected-paths`, `engine-arrival`) and 7.1.0 (ladder, `claude-md-trim`, `migration-guide-retired`, `update-framework-stub`) | ~1,300 | 60-90 + 40-70 each + `## Example` |
| `retired-plugins.txt`, `update-channels.conf`, `BUNDLE.sha256` | ~120 | |
| `update-bootstrap` installer subcommand | ~250 | payload group + receipt run + sync-ref write; JS in `packaging/adopt/` |
| `test_update_loom.sh` (engine fixtures), `test_update_notes.sh` (three trees + planted defects), retargeted `test_update_from_6x.sh`, floor additions, shallow/crash fixtures | ~3,800 | LH `update-cases.sh` case list (A §1.16) minus pack cases, plus the cases in section 8 |
| `update-coverage.sh`, `bootstrap-shape.sh` (maintainer) | ~300 | |
| **Total new** | **~9,900** | |
| **Retired** (section 6) | **~18,500** | 4,805 + 790 + 88 + 1,556 + 771 + 364 + 465 + 614 + 5,568 + 2,826 + 121 + 502 |

### 7.2 Risks, ranked

1. **Loose done-when passes an adaptation that reads wrong** (LH §12 #1; applies in full). Silent. Mitigation: R3/R4 retention invariants; reviewer item "is done-when checkable"; plain-words result always shown; every check has a planted-defect fixture.
2. **Hooks cannot see inside the engine** (B §5.3; Codex #6). Accepted for a detached worktree inside `.git/` after the user approves the enumerated transaction; landing is a typed, gated merge; no `reset --hard`, no push, no branch, ever. Residual: a subagent could run `--stage` until the one-line `subagent-git-guard` pattern lands; it cannot land.
3. **Checks are upstream shell** (Codex #8). Export + write detection + static lint rules + committed URL. Not a sandbox; a read-only exfiltrating check is not detected. Residual accepted and stated.
4. **Bootstrap populations** (3.3). `update-bootstrap` covers broken and missing stamps; pre-6.2 layouts remain out of scope. Unknown how many exist (B §7).
5. **Legacy `sdd-*` dirs are indistinguishable from customer plugins**. By design nothing is deleted; the wiring check is the only assertion.
6. **Release shape**: if 9.3(a) is not taken, adopters' old updater offers ~250 files they must sort by hand once.
7. **Adapter drift across many small notes** (LH #2). Per-group approval; adapter sees the current file each time.
8. **Maintainer workload** (LH #5; applies more). Fixtures for every check cost time; the coverage gate warns on PRs and blocks only at promote.
9. **Scope creep into a patch language** (LH #6). Rule: a check that only makes sense against the template's own prose is template-only; `pattern`/R4 is the only hunk-level mechanism and only for `project-data`.
10. **Stray agent write** (LH #7). Both agents have no write tool and no Bash; deterministic `--adapt-save`.
11. **`settings.json` bridge** (LH #4): LogicLoom has no analogous one-time loss; the restore machinery (`LH:update.sh:1083-1251`) is **not ported** (−170 lines).
12. **Windows/CRLF** (LH #8): the floor is macOS bash 3.2, not Windows; CRLF-insensitive hashing is kept (cheap), the Windows lane is not built.
13. **Worktree in unusual repos** (submodules, LFS, sparse checkout): UNVERIFIED; the `--stage` refusal set, the shallow refusal and the stale-lock self-heal are the guards; gitfile layouts are handled by `--absolute-git-dir`.

### 7.3 What this model does not guarantee

- It cannot tell a customer-authored file from a stale harness file when no reference blob exists; it keeps it.
- A tampered engine on the customer's disk runs with their rights; mitigations are the bootstrap rule, the notes/engine tree being always-taken, and `protected_paths`; none is a sandbox.
- Checks are upstream shell executed locally against an export; a check that only reads can still read anything the user can. Bundle signing is not provided.
- Per-improvement approval is enforced at **path** granularity (staged-path allowlist, overlap groups). Two intended changes inside one file under one note land together; a hunk-level patch language is deliberately not built.
- Undo is one commit deep per update id; undoing beneath later updates or over the customer's own edits to the same paths is refused, not merged.
- The pre-update tag is local unless the user pushes tags; undo does not need it.
- The governance hooks still see only typed commands; "nothing irreversible without you" holds because the irreversible-feeling step is typed, not because a hook can prove it.
- "Thin 7.0.0" holds only under decision 9.3(a); under (b) the old updater's offer list is long and unfiltered.

---

## 8. Build plan

Phases are ordered; work packages inside a phase run concurrently with disjoint files. "Done" is always a green test, not a claim.

**Phase 0 — first slice: prove the model on a fixture** (one worker, high effort)
- WP0.1 owns `plugins/loom-maintenance/scripts/{update-loom.sh,json-valid.sh,json-flat.sh,security-invariants.sh,updates-lint.sh,updates-checks.sh}` and `tests/contract/test_update_loom.sh`. Port the engine with the `--stage/--finish/--abandon` split, ledger-based offering, two-way rows, handover rung, overlap groups, `removes`/`project-data`/`pattern`/per-row channels, forbidden set, channel map reader, detached worktree, `write_path`, mode class, export + write detection, staged-path allowlist, R1–R5. The test builds throwaway upstream+customer repos (the `update-cases.sh` pattern) with three fixture notes (one safety touching `settings.json` with an adopter hook present, one non-safety touching a doc, one `project-data` with `pattern`) and drives: plan → digest (simulated) → adapt-save (including each R1–R5 refusal) → stage → `git merge --ff-only` → finish → undo from a fresh clone of the result; plus hold-back with a `requires` cascade, stale plan, unknown decision, forbidden-tree gate, handover with and without a surviving tag, `safety-unresolved` with `informed=yes` and with stop, two notes sharing a path, a check that writes a file, an ambiguous-channel fixture, a shallow-clone refusal, a killed `--stage` followed by self-heal, a symlinked parent, a mode-only change.
- Done when: the e2e passes under macOS `/bin/sh` and under `dash` on CI (bash 3.2 floor test gains a "POSIX family executes under sh" section); no skill exists yet.

**Phase 1 — the people-facing layer** (three workers)
- WP1.1 owns `skills/update-loom/SKILL.md`, `commands/update-loom.md`, the handover preamble for `update-framework.md`, `plugin.json`, bridge sync output.
- WP1.2 owns `.claude/agents/update-adapter.md`, `update-reviewer.md` (with the `adapt` routing), and the registry files in section 6's blast radius that name agents.
- WP1.3 owns `tests/contract/test_update_notes.sh` (lint fixtures; three-tree positive runs; planted-defect runs for every check).
- Done when: the skill drives Phase 0's fixture by hand once; `test_update_notes.sh` green on the fixture notes and red on a planted check with no fixture.

**Phase 2 — content and retirement** (three workers)
- WP2.1 owns `plugins/loom-maintenance/updates/7.0.0/*` and `7.1.0/*` (notes, checks, `## Example` bodies, fixtures), `.logic-loom/config/retired-plugins.txt`, `BUNDLE.sha256` generator.
- WP2.2 owns the six CI tolerance consumers + `validate-plugin-manifests.py` + `constitutional-check.sh` (source the flat list), the `governance.conf` `protected_paths` lines and `subagent-git-guard.sh` pattern (both main-agent ASK, listed for the user), and the deletions in section 6 (scanner, lib, conf, recorder, old tests, `run_all_tests.sh` rows).
- WP2.3 owns the doc/rename sweep (`AGENTS.md`, `START_HERE.md`, `README.md`, `VISION.md`, `KNOWN_ISSUES.md`, `FRAMEWORK_SYNC_GUIDE.md`, `CONTRIBUTING.md`, templates) — `constitution.md` edits are main-agent ASK and listed separately for the user.
- Done when: `run_all_tests.sh` green; `updates-checks.sh` prints `notes=<n> ok`; a planted retired-plugin hook in a fixture makes `--plan` offer the family note; the planted kori ladder makes `--plan` offer the `project-data` note with the ledger empty.

**Phase 3 — release plumbing and bootstrap** (three workers)
- WP3.1 owns `tests/contract/test_update_from_6x.sh` + `v7-machinery-paths.txt` (3.5, including the partial-accept and handover cases).
- WP3.2 owns `template-strip-manifest.txt` (adds the ledger and `.applied` rows defensively, `update-coverage.sh`, `bootstrap-shape.sh`), `leak-guard.sh:149-153`, `payload-manifest.txt` (the `updater` group and comments), `.logic-loom/scripts/bash/update-coverage.sh`, `bootstrap-shape.sh`, channel-map generator, `promote-to-main.yml:139-145` (+ source-ref input under 9.3(a)), `plugin-tests.yml:308-316`, `promote.md` step 2.
- WP3.3 owns `packaging/adopt/` `update-bootstrap` subcommand and its test (`test_adopt_update_bootstrap.sh`): installs the `updater` group into an adopted fixture and a template fixture, records the receipt run, handles missing and unreachable `.sdd-sync-ref`.
- Done when: the 6.x test passes on both fixtures; `update-coverage.sh` reports zero uncovered paths and fails on a planted uncovered file; `bootstrap-shape.sh` passes on the `release/7.0.0` tree and fails on dev-main; `leak-guard` green on a built sanitized tree; `update-bootstrap` leaves a fixture that `--status` reports `bundle=complete`.

**Phase 4 — polish** `closest` base ladder UX, `--revisit`, declined-note digest wording.

Order constraints: 0 → 1 → 2 → 3; 2 and 3 may overlap only on files not shared (they are not). Nothing is committed without the user; `/git-push` at phase ends.

---

## 9. Decisions for the maintainer

1. **Retired-plugin notes: how many?** (a) **Four family notes** (recommended) — one question per family at most, successor table in the body, and under the digest rule a stock copy is asked nothing. (b) One note for all 23 — one question, but the mapping is buried. (c) One note per plugin — exact, but up to 23 questions for one customer.
2. **Where does `git worktree add` run?** (a) **Inside the engine, detached, after the user approves the enumerated transaction** (recommended) — one governance prompt (the merge); no branch is ever created; the worktree never leaves `.git/`; a `subagent-git-guard` pattern denies subagents the engine's mutating verbs. (b) Typed by the skill — two more prompts (`worktree add`, `worktree remove`), every mutation visible to the gate.
3. **7.0.0 release shape** (evidence in 3.6: dev-main is +31,696 lines ahead of v6.6.2). (a) **Bootstrap branch `release/7.0.0` = v6.6.2 tree + bundle only** (recommended) — the old updater offers ~20 obviously updater-shaped files; everything else arrives in 7.1.0 through the new engine with the channel map; costs a source-ref input in `promote-to-main.yml` and a second release two to four weeks later. (b) Fat 7.0.0 from dev-main — one release, but adopters' old updater offers root `CLAUDE.md`, `tests/`, `.github/` and ~250 files they must decline by hand; the bootstrap-shape gate is skipped.
4. **Reviewer agent tools.** (a) **Read/Grep/Glob only, with the power to route a merged-clean row to the adapter** (recommended). (b) Keep Bash with a prose allowlist as Launchhouse does — more flexible, enforced by nothing.
5. **Declined non-safety notes.** (a) **Record in the tracked ledger; re-ask only when the note changes upstream or on `--revisit`** (recommended) — survives re-clone, no nagging. (b) Re-ask every run while the check fails — louder. (c) Declined is final for everything — quieter, but a bad-timing decline is permanent.
6. **Fallback for installs the old updater cannot serve.** (a) **Ship `npx logicloom@7 update-bootstrap` in 7.0.0, Phase 3** (recommended) — both channels, receipt run, sync-ref repair with explanation. (b) Document the manual repair only (`KNOWN_ISSUES.md`). (c) Tell them to re-clone/re-adopt.
7. **A retired directory the user wants gone.** (a) **The note prints the `git rm -r` command; the skill offers to type one combined command; the gate asks** (recommended). (b) The engine stages the deletion under the note's yes — fewer steps, but the engine deletes something git cannot prove is stale.
8. **Where notes live.** (a) **`plugins/loom-maintenance/updates/`** (recommended) — plugin-owned data, no exposure to a fork's `.logic-loom` rename. (b) `.logic-loom/updates/` — sits beside `config/`, but a renamed framework dir moves it.
9. **Uninstall record for update-added files.** (a) **Drop the recorder; the tracked `.applied` records already list every path each update added** (recommended) — `npx logicloom uninstall` can read them in a later release. (b) Keep a trimmed append-only recorder (~150 lines) run by `--finish` in adopted repos.
10. **Engine language rule in the shell policy.** (a) **POSIX sh + awk for the update family, bash 3.2 for the rest** (recommended) — checks run in adopted repos on any machine; CI's `/bin/sh` (dash) becomes a free second interpreter. (b) bash 3.2 for everything — one rule, but the port is rewritten from `sh` and loses the dash check.
11. **Where the ledger lives** (new). (a) **Tracked, `.logic-loom/memory/update-ledger.tsv`** (recommended) — survives re-clone and second machines, reverted by undo, offered-once semantics need no base-tree trick; costs one bookkeeping commit on an all-declined run. (b) `.git`-local as Launchhouse does — no commit noise, but every finding in 1.5's list returns.
12. **Security relaxations** (new). (a) **Only via an explicit `relaxes:` list shown as its own exact-diff question** (recommended) — an adaptation can never widen a permission by inference. (b) Trust the adapter's prose rules plus the reviewer — Launchhouse's posture; the one both reviewers called out.

---

## 10. Critique disposition

Status key: **Addressed** — the design changed; section given. **Accepted** — a deliberate tradeoff, kept with stronger mitigation. **Refuted** — shown wrong with evidence. **Resolved** — an "unclear" finding given a specification. Nothing is dropped.

| # | Source | Finding (short) | Status | Disposition |
|---|---|---|---|---|
| 1 | Codex #5, agy 2.1 | Failed safety adaptation silently becomes `take-theirs` | **Addressed** | `safety-unresolved` state; `.lost.diff` shown; explicit *Replace my file* (`informed=yes`) or *Stop the update*; never automatic — 2.2 steps 4, 6, 7; section 0 reworded |
| 2 | Codex #7, agy 3.1 | Security preservation is prose; `tool-restrictions.json` unprotected | **Addressed** | Deterministic R1–R5 in `--adapt-save`, gate and smoke — 1.10; `tool-restrictions.json`, updater, agents and `framework-upstream.conf` added to `protected_paths` via a 7.0.0 safety note; `relaxes:` for intentional weakening (decision 9.12) |
| 3 | Codex #9 (first), orchestrator | `project-data` note never offered after handover | **Addressed** | Offering is ledger-based (1.5(a)), not base-tree presence; `project-data` exempt only from re-offer, not from first offer; tested in 3.5(5) |
| 4 | Codex #9 (second), agy 4.3 | Retired-plugins check exits 0 for unwired dir → never offered | **Addressed** | Offered once via the ledger regardless of exit code; done-when 4 becomes "ledger records applied/acknowledged" — 4.1 |
| 5 | agy 1.1, 1.2, orchestrator | Re-offered note has no engine row; `handover` rung missing from ladder | **Addressed** | Two-way held rows (base `-`) for `keep` paths under offered notes — 1.5; `handover` is rung (0) and reads `<tag>:.sdd-sync-ref` for the true base — 2.2 step 1, 3.2(4); both tested in 3.5(6) |
| 6 | agy 1.3, Codex #3 | Broken/missing stamp customers stranded; `update-bootstrap` optional | **Addressed** | `update-bootstrap` ships in 7.0.0, Phase 3 WP3.3, both channels — 3.3, 8; decision 9.6 |
| 7 | Codex #2 | Bootstrap not atomic; stub can disable the only updater | **Addressed** | 7.0.0 `update-framework.md` keeps the full old procedure + handover preamble gated on `bundle=complete`; `BUNDLE.sha256` verified by `--status`; stub only in 7.1.0 — 3.2, 3.4; partial-accept test 3.5(3) |
| 8 | Codex #4, orchestrator | "Thin 7.0.0" unenforced and inconsistent | **Addressed** | New evidence: dev-main is +31,696 lines ahead of v6.6.2, so thin needs a bootstrap branch — 3.6; `bootstrap-shape.sh` gate; decision 9.3 restated with the real tradeoff; CLAUDE.md trim moved to 7.1.0 under (a) |
| 9 | Codex #1 | Per-improvement approval not enforced at file level | **Addressed** (to path granularity) | Overlap groups approved as a unit — 1.3; staged-path allowlist aborts on any path outside approved notes — 2.2 step 7; hunk-level enforcement deliberately not built, stated in 7.3 |
| 10 | Codex #8, orchestrator | Trust root not pinned; checks run live before approval | **Addressed** | URL read from committed HEAD blob; env override replaced by a double-flag CLI option read back to the user; `framework-upstream.conf` protected — 1.11; checks run against a read-only export with write detection and static lint rules — 1.7; no sandbox, stated in 7.3 |
| 11 | Codex #6, orchestrator | Engine runs git the hooks cannot see | **Accepted** with narrowing | Detached worktree removes `branch -D` from the invisible set; tag never deleted; user approves the enumerated `transaction.txt` before `--stage`; `reset --hard` and push never — 2.1; decision 9.2 keeps the visible alternative |
| 12 | agy 3.4 | Subagent can run `--stage` | **Addressed** | One deny pattern in `subagent-git-guard.sh` for engine mutating verbs (the hook sees `agent_id`, `subagent-git-guard.sh:16-21`) — 2.1; residual until it lands stated in 7.2 #2 |
| 13 | Codex #10, agy 4.1 | `claude-md-trim` check vacuous w.r.t. CLAUDE.md | **Addressed** | Check asserts on CLAUDE.md (non-empty, heading present, moved headings absent) with a planted defect; R3 heading retention in `--adapt-save` — 4.3, 1.10 |
| 14 | agy 4.2, Codex #10 | Ladder check is a negative grep; wipe or absent file passes | **Addressed** | `skip=` protocol for an absent file; R4 bounds deletions to `pattern` lines so a wipe is refused deterministically; planted defect — 4.2, 1.7, 1.10 |
| 15 | agy 4.5 | `check: none` under rule (b) undefined | **Addressed** | Defined: offered once via (a), never via (b); `declined-final` on decline; linter prints the consequence — 1.3, 1.5 |
| 16 | agy 4.4, Codex #10 | Only safety checks proven both ways | **Addressed** | Every check has a planted-defect fixture and runs positive on three trees (template, sanitized, adopted payload); missing fixture fails the suite; lint requires the check to reference its targets — 5 |
| 17 | agy 2.3 | Hold-back does not cascade through `requires` | **Resolved** | Hold-back holds the transitive dependents and reports each — 1.7, 1.9; test in Phase 0 |
| 18 | Codex #11 | Channel detection fails open; no per-install profile | **Addressed** | Fail-closed ladder with an `ambiguous` state treated as adopted-superset and confirmed by the user; receipt `only:` groups map to payload groups in the channel map; `manifest-version` header — 1.4 |
| 19 | Codex #12 | `channels` per note, needed per row | **Addressed** | `@template`/`@adopted`/`@both` suffix per `touches` row — 1.3; used in 4.3 |
| 20 | Codex #16 | `tests/` fixtures and `tests/lib/tree-provenance.sh` referenced at runtime; absent in adopted repos | **Addressed** | Worked example moves into the note's `## Example`; engine carries its own `copy_mode()` with a contract test pinning it to the test helper — 1.7, 1.8, 4.2 |
| 21 | orchestrator (also Codex #7, agy 3.2) | `project-data` allowlist includes shipped protected files; verdict changes not safety-class | **Addressed** | Allowlist narrowed to never-shipped files; `gate-policy.conf` etc. become *posture files*, always held, `safety` inferred when a verdict/`protected_paths` line changes, R2 forbids relaxation — 1.3, 1.10 |
| 22 | agy 3.3 | Non-safety protected-path note lands despite failing check | **Refuted** | Hold-back sets aside a failing non-safety note before the commit lands (`LH:update.sh:1855-2072`; design 1.7). Residual (silent non-delivery) addressed: the report names each held-back note with the reason — 2.2 step 10; `safety` is now inferred for wiring/verdict changes — 1.3 |
| 23 | agy 5.1 | `git revert` undo poisons the next three-way | **Refuted** | `.sdd-sync-ref` is bumped inside the update commit, so the revert restores the old base; the next plan sees base = pre-update, HEAD = pre-update, upstream = newer → untouched → taken. The analysis assumed the base stayed at 7.0.0. Stated in 2.2 step 11 |
| 24 | agy 5.2, Codex #14 | Undo one-deep, clone-local, refuses on overlap | **Addressed** (partly accepted) | Tracked `.applied` records with blob+mode lists; `--undo <id>`; verification against `<commit>^`, no tag dependency, works from any clone — 1.2, 2.2 step 11. Refusal on overlapping later edits is kept and stated in 0 and 7.3 as the honest limit; agy's "a single later commit paralyses undo" is overstated — only same-path edits block |
| 25 | agy 5.3, Codex #14 | Undo does not restore held/declined/applied bookkeeping | **Addressed** | Ledger and `.applied` are inside the reverted commit; no `.git`-local state is load-bearing after `--finish` — 1.2, 1.5, 2.2 steps 7, 9, 11 |
| 26 | agy 6.1, 6.2, Codex #15 | Approval fatigue; "one prompt" understated | **Addressed** | Digest: untouched-file notes listed with opt-out, safety notes listed not asked, one screen per overlap group needing a decision, declines snoozed until the note changes; honest count in section 0 and 2.2 — agy's 14-prompt count double-counted (the four family notes are four of the eight notes) |
| 27 | agy 2.2 | Merged-clean bypasses the adapter; reviewer can only hold | **Resolved** | Reviewer may route a merged-clean row to the adapter (`adapt`), step 4 re-runs for it — 2.2 step 5; decision 9.4 |
| 28 | agy 2.4 | Declined note dropped on re-clone | **Resolved** | Tracked ledger — 1.5; decision 9.11 |
| 29 | agy 2.5 | Upstream dir colliding with an adopter's own top-level dir | **Resolved** | In an adopted repo any path outside harness-owned prefixes is adopter-owned and never written; both-added inside a prefix is `conflict` → held — 1.3, 1.4 |
| 30 | agy 1.4 | `sync-plugin-commands.sh` prunes the new stub | **Refuted** | `do_prune` removes a bridge command only when no `plugins/*/commands/<name>.md` exists (`sync-plugin-commands.sh:167-195`); it never consults the manifest; `update-loom.md` ships in the plugin. The regenerated manifest is in the bundle anyway. Mid-session reload stays UNVERIFIED (2.2 step 10) |
| 31 | agy 7.5 | Template clones misclassified as maintainer | **Refuted** | The five markers (`tree-provenance.sh:28-40`) are bare strip-manifest entries removed wholesale at promotion, so a template clone is `sanitized`. The real gap was the opposite (helper absent in adopted repos) — fixed under #20 |
| 32 | agy 7.1 | `git fetch` blocked by a sandbox | **Refuted** | Identical to today's extractor (`extract-proposals.sh:108-116`); any sandbox restriction is the user's host setting and affects the current flow equally. Not a regression of this design. Whether a given sandbox permits it: not verified |
| 33 | agy 7.2 | Shallow clones break base reachability | **Resolved** | `--status` detects `--is-shallow-repository` and refuses with the `--unshallow` hint rather than guessing; git's behaviour in that case is UNVERIFIED — 2.2 step 0; Phase 0 fixture |
| 34 | agy 7.3 | Worktrees fragile: linked worktrees, gitfile, stale locks | **Resolved** | `--absolute-git-dir` handles linked worktrees and gitfiles; stale-lock self-heal ported (`LH:update.sh:1567-1601`); crash-recovery case in Phase 0 — 2.2 step 0, 8 |
| 35 | agy 7.4 | `.gitattributes` causes false conflicts | **Refuted** | Classification compares git blobs (base, HEAD, upstream trees), never working-tree bytes, so smudge/eol conversion does not enter; kori has `* text=auto eol=lf` and LogicLoom `* text=auto`, both irrelevant to blob comparison. CRLF-insensitive hashing is kept for the adapted body |
| 36 | Codex #13 | Symlink and mode safety incomplete | **Resolved** | Single `write_path` with per-component symlink refusal and temp+rename; classifier compares modes, new `mode` class — 2.1 |
| 37 | orchestrator | Updater itself not on the protected-path list | **Addressed** | `protected_paths` for `plugins/loom-maintenance/scripts`, `updates`, both agent files, `framework-upstream.conf`, `tool-restrictions.json`; shipped in the template and as a 7.0.0 safety note — 1.10 |
| — | orchestrator caveat | Codex had no further different-provider reviewer available to itself | **Noted** | Stated at the top; both reviewers are different-provider from the author, so the review of the design is decorrelated; Codex's own output was not cross-checked |

**Where the two reviewers disagreed**, in a sentence each: agy wanted undo to be a branch reset (`git reset --hard` to the tag) to avoid "revert poisoning"; Codex wanted durable multi-update revert metadata. The design keeps revert (reset is `ask` and destructive, `gate-policy.conf:120`) and refutes the poisoning on the sync-ref evidence, while taking Codex's durable metadata. agy wanted every applying note auto-applied on untouched paths as Launchhouse does; Codex wanted a digest with per-item toggles and persisted declines. The design does both: untouched-path notes are listed with an opt-out, and declines persist in the ledger.

---

## 11. Maintainer decisions 2026-10-03

Recorded by the Phase 0 planner. Where these differ from the body above, **these win**. Decisions not listed here take the designer's recommended option in section 9 (9.1(a), 9.2(a), 9.4(a), 9.5(a), 9.7(a), 9.8(a), 9.9(a), 9.10(a), 9.11(a), 9.12(a)).

| # | Decision | What it changes in the design |
|---|---|---|
| 1 | **Release shape: one 7.0.0 from `dev-main` — option 9.3(b), "fat".** No release is cut now. | No `release/7.0.0` branch, no source-ref input to `promote-to-main.yml`, **`bootstrap-shape.sh` is not built** (3.6, 5, WP3.2 lose that item). Section 0's "7.0.0 is a bootstrap release built from the last shipped tree plus the updater bundle only" is withdrawn; risk 7.2 #6 is accepted in writing. Consequences honoured in the build: (a) the handover (3.2) and the 6.x test (3.5) must work when the old `/update-framework` offers the **full dev-main change set** (~250 files), not ~20; (b) the handover preamble in `update-framework.md` and the customer docs must tell a 6.x customer plainly **which offered files to accept first** — the updater bundle, exactly the paths in `BUNDLE.sha256` — and that **everything else can then come through `/update-loom`** (and may be declined in the old run without loss, because the ledger offers every 7.0.0 note regardless of `.sdd-sync-ref`, 1.5); (c) the `claude-md-trim` note and the other dev-main content notes ship in **7.0.0**, not 7.1.0 (4.3, 6 "ship in 7.1.0 under 9.3(a)" rows move to 7.0.0); the two-release split in 3.4 (stub in 7.1.0) stands for the *command* only. |
| 2 | **Broken or missing update pointer: ship BOTH** `npx logicloom@7 update-bootstrap` (9.6(a)) **and** written manual repair steps in `KNOWN_ISSUES.md`. | 3.3 unchanged for the installer; `KNOWN_ISSUES.md:55-112` is rewritten (not merely kept) so it covers the missing-stamp case and the `c6092b0` tag clones step by step, and names the installer as the alternative. WP2.3/WP3.3. |
| 3 | **Retired plugins: four family notes** (9.1(a)). | 4.1 as written. |
| 4 | **Command name `/update-loom`; `/update-framework` keeps working** for older versions per 3.2/3.4 (full procedure + handover preamble in 7.0.0; forwarding stub in 7.1.0). | As written. |
| 5 | **Build all phases; nothing is pushed.** | Phase order 0 → 1 → 2 → 3 (→ 4) stands; every phase ends with the work committed locally only when the user approves; `/git-push` is never run by the build. |

**Phase 0 planning notes** (`packages-phase-0.json` beside this file holds the packages):

- Phase 0 is split into ten sequential-where-needed Sonnet packages instead of the single "one worker, high effort" WP0.1, because the engine alone is ~2,200 lines. Shared contract (state layout, TSV columns, decision vocabulary, check contract) is written once as the header of a new sourceable `plugins/loom-maintenance/scripts/update-loom-common.sh` (POSIX sh), which the engine, linter, checks runner and invariants script all source. This file is an addition to the 1.2 table; it ships with the bundle.
- Per-package test cases live under **`tests/update-loom/`** (`lib.sh`, `cases-*.sh`, `fixtures/`), driven by one registered suite `tests/contract/test_update_loom.sh`. Reason: `tests/contract/test_suite_registration.sh` requires every `tests/contract/**/*.sh` to be registered in both `tests/run_all_tests.sh` and `plugin-tests.yml`, so case files cannot sit under `tests/contract/`. The suite is POSIX sh and runs every case file under `${LOOM_TEST_SH:-/bin/sh}`; CI's `/bin/sh` is dash, and `/bin/dash` exists on current macOS, so the "under dash" done-criterion is runnable locally too.
- Forbidden-touch set, refined: `web/`, `apps/`, `node_modules/`, `features/*/` and `specs/*/` (the subdirectories — `features/README.md`, `features/.gitkeep`, `specs/README.md`, `specs/.gitkeep` are shipped by the payload manifest and stay harness-owned), `.brain/` except `.brain/README.md`, the ledger and `.logic-loom/memory/updates/*.applied` (engine-written only). The tree-sha equality gate covers `web`, `apps`, `.brain`, `features`, `specs` with the two shipped files excluded by comparing per-subdirectory trees.
- Check contract addition: the engine exports **`UPDATE_TOOLS`** (= `<state>/tools`, upstream's `json-valid.sh`/`json-flat.sh` saved at plan time) to every check; a check reads JSON via `${UPDATE_TOOLS:-$REPO_ROOT/plugins/loom-maintenance/scripts}/json-flat.sh`, because the export of a 6.x HEAD may not yet hold the tools. `updates-checks.sh` exports the same variable pointing at its own directory.
- `BUNDLE.sha256` lines are `<sha256 hex>  <path>` computed by `sha256sum`, else `shasum -a 256`, else `openssl dgst -sha256`; `--status` prints `bundle=complete`, `bundle=incomplete missing=<a,b>`, `bundle=absent` (no file — the handover preamble's "continue with the old procedure" case) or `bundle=unverifiable` (no hash tool).
- The ladder `pattern` (4.2) must match the kori fixture's **both** forms (`- 3 = …` and the indented `  3 = …` at `kori-amendments-ladder.before:20,32`): `^[[:space:]-]*3[[:space:]]*=[[:space:]]*it changes auth, payment, or customer-data logic`.
- `--undo <id>` locates the update commit as the single commit that **adds** `.logic-loom/memory/updates/<id>.applied` (`git log --diff-filter=A --format=%H -- <path>`), whose parent equals the record's `parent=` line and whose subject starts `LogicLoom update to`; the record cannot carry its own commit sha because it is inside the commit.
- The `.logic-loom/config/update-channels.conf` reader ships in Phase 0 with a hand-derived first version of the file (from `payload-manifest.txt` rows); the generator and freshness gate remain WP3.2.
- Protected-file edits the engine implies (`subagent-git-guard.sh` deny pattern for the engine's mutating verbs; `governance.conf` `protected_paths` lines for the updater, agents, `framework-upstream.conf`, `tool-restrictions.json`) are listed in `packages-phase-0.json` → `protected_edits` for the main session; the design schedules them in WP2.2, and applying them at the end of Phase 0 is also acceptable.

---

## Build status — paused 2026-10-03

Paused at the maintainer's request (token spend). Phase 0 is split into ten
packages (`packages-phase-0.json`); four are built and reviewed:
`p0-foundation`, `p0-lint-checks`, `p0-invariants`, `p0-engine-status-base`.
Next package: `p0-engine-plan-classify`, then plan-notes, adapt-save,
stage-abandon, finish-undo, e2e-floor. Not yet done for Phase 0: the phase
gate (full suite) and the cross-provider review. Phases 1-4 not started.
`tests/contract/test_update_loom.sh`: 1153 passing under `sh`.
The v7 scanner is still in the tree; it is retired in Phase 2.

Known red at the pause point (found 2026-10-04): `tests/contract/test_shipped_path_references.sh`
fails 9/10 — `plugins/loom-maintenance/scripts/update-loom.sh:312-313` and
`.logic-loom/config/update-loom-channels:63-64` cite two maintainer-only guides
(`.docs/guides/dev-main-template-split.md`, `adopt-smoke-test.md`) that are
stripped at release. Fix when the build resumes; the full suite was not run at the pause.
