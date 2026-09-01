# LogicLoom Todos — cross-cutting work being addressed NOW

**Level 0 of the Todo Architecture SSOT, active half.** Authoritative list for
work that is **not a feature** — governance, hooks, tests, CI, release tooling,
policy and documentation — and that is **being worked, is next up, or is waiting
only on a maintainer decision that has already been asked for**.

Its deferred half is `.logic-loom/memory/backlog.md`: same grammar, same id
space, different question. **Todos answer "what am I doing"; backlog answers
"what should I bring up later".** One stream mixing both is a list nobody can
read: the item you must act on today sits between two you decided six weeks ago
not to act on at all.

Feature work does **not** belong in either file. It belongs in
`features/<name>/plan.md` (swarm pack) or `specs/###-name/tasks.md` (SDD pack).
Strategic direction does not belong here either — that is `VISION.md`
§ Open Threads.

Full rationale and the SSOT hierarchy: `.docs/policies/todo-architecture-policy.md`.

---

## Grammar — normative in `backlog.md`, unchanged here

There is **one item grammar for both streams** and it is specified once, in
`.logic-loom/memory/backlog.md` § *Item grammar (normative)*. This file uses it
verbatim: same `- [ ] LOOM-NNNN — Title `` `status:…` `` line, same tag rules,
same `## Items` scope rule, same fenced-block rule, same closed status
vocabulary, same `blocked_on:` forms.

It is **not** restated here on purpose. Two copies of a normative grammar
disagree the first time one is edited, and the collector
(`.logic-loom/scripts/bash/build-backlog-index.sh`) implements exactly one
parser for both files — a forked grammar would be a specification the tool does
not implement.

The only differences between the two files are **scope** (stated above) and
**`level`**: items collected here carry `level: "todo"`, items collected from
`backlog.md` carry `level: "backlog"`.

## One id space across both files

Ids are **globally unique across `todos.md` and `backlog.md`**, not per-file.
This is load-bearing rather than tidy: `blocked_on:` references cross the
streams — a todo may be blocked on a deferred backlog item, and a deferred item
is routinely blocked on a decision that is an active todo. If each file minted
its own sequence, `blocked_on:LOOM-0010` would have two answers and the
reference would be meaningless.

**Where the counter lives: nowhere.** It is **derived**, not stored:

> **next id = (highest id present in `todos.md` or `backlog.md`) + 1**

A stored counter would have to live in one file and be honoured by the other,
and the moment someone appends an item to the file that does *not* hold it, the
counter is wrong and nothing says so. Deriving it means the two files cannot
disagree, because there is nothing to disagree about. To get the value without
reading both files by eye:

```
./.logic-loom/scripts/bash/lint-backlog.sh --next-id
```

The guarantee behind this is mechanical, not clerical: `lint-backlog.sh` reports
a `duplicate-id` finding when the same id appears in both files (naming both),
and `build-backlog-index.sh` treats a duplicate anywhere across all sources as a
**fatal** defect — it exits non-zero and writes no index at all. A colliding
mint cannot reach a consumer.

## Promotion — how an item moves between the two files

Movement is a **cut and paste of the item's whole block, and nothing else**:

| Direction | When | What changes |
|---|---|---|
| `backlog.md` → `todos.md` (**promote**) | you have decided to work it, it is next up, or it is now waiting only on an answer you have asked for | the file it sits in; its `level` in the index |
| `todos.md` → `backlog.md` (**defer**) | you decided not to act on it now, it needs a decision you are not ready to make, or it lost its consumer | the file it sits in; its `level` in the index |

**The id NEVER changes when an item moves.** Not on promote, not on defer, not
on a title edit made while moving it. This is the whole reason the id exists: it
is the stable handle every `blocked_on:` reference and every consumer holds, and
an id that churned on a state change would make "the item with id X" mean
something different on Tuesday. An item's stream is a *property* of the item,
not part of its identity — which is exactly why `level` is a field the collector
derives from the file path rather than a value anyone writes down.

Consequences worth being explicit about:

- **Do not re-mint.** Moving an item never allocates a new id, so the derived
  counter above does not advance on a promotion.
- **Do not split.** If a moved item turns out to be two pieces of work, mint the
  second one as a new id; do not renumber the first.
- **Edit the body freely while moving.** Status, title and prose are all
  mutable; only the id is not.
- **A `done` item stays where it was completed** — which is `todos.md`, since
  completing it means it was being worked. Deferred items that were never
  promoted stay in `backlog.md`. Nothing is deleted on completion: the id is the
  stable handle other items' `blocked_on:` still refer to.

## Ship / strip

This file **ships** as machinery — a cloner inherits the two-stream shape and an
empty item list, not this repo's maintenance items. Its content is
harness-dev-specific, so it carries a `stub:` entry in
`.logic-loom/scripts/bash/template-strip-manifest.txt`
(`.logic-loom/templates/project-todos-template.md`), exactly as `backlog.md` and
`VISION.md` do.

---

## Items

### Provider portability — instruction files (TOP PRIORITY)

- [ ] LOOM-0046 — Make AGENTS.md the single provider-neutral source; CLAUDE.md imports it `status:open`
      Raised 2026-08-31. Two problems, one root cause: CLAUDE.md (860 lines) and
      AGENTS.md (620 lines) duplicate content that a contract test and the Tandem
      Update Rules police by hand, and AGENTS.md is serving two masters — this
      harness treats it as an agent REGISTRY while every other provider treats it
      as the PRIMARY PROMPT file.
      Resolution: `CLAUDE.md` becomes `@AGENTS.md` plus Claude-only sections;
      the provider-neutral governance moves into AGENTS.md Tier 1 (already
      structured Tier 1 / Tier 2, so mostly relocation). Zero drift by
      construction, which retires the verbatim-duplication test and the manual
      tandem rules.
      NOT A SYMLINK, and this was checked rather than assumed. The Claude Code
      docs support `ln -s AGENTS.md CLAUDE.md` but only "if you don't need to add
      Claude-specific content", and state: "On Windows, creating a symlink
      requires Administrator privileges or Developer Mode, so use the @AGENTS.md
      import instead." Our CLAUDE.md is largely Claude-specific (hook wiring,
      slash commands, plugin bridge), so a symlink would force host detail into
      the provider-neutral file — backwards. `lib/fsops.js` also REFUSES symlinks
      outright (`REFUSE-SYMLINK`), so one interacts badly with the payload.

- [ ] LOOM-0047 — An adopter on a non-Claude provider gets ZERO LogicLoom governance `status:open`
      Raised 2026-08-31, VERIFIED in a real install (kori-beta, logicloom@6.6.1).
      This is the one that actually "breaks the harness if the user changes
      providers", and it is separate from LOOM-0046.
      `--claude-md` offers `rules` | `import` | `none`. All three put the
      harness's operating instructions in `.claude/rules/logicloom-*.md`, which
      only Claude Code reads. The payload also renames our AGENTS.md to
      `.logic-loom/AGENTS.md` — correct, it must not collide with theirs — so
      nothing LogicLoom installs is visible to Codex, Cursor, Gemini CLI or
      Aider.
      Evidence: kori-beta's own CLAUDE.md is a one-line `@AGENTS.md` import and
      its AGENTS.md is an Expo file. Grepped both after a clean 393-file install:
      NEITHER mentions LogicLoom. Open that repo in another provider and the
      governance is not degraded, it is absent.
      Needs a design decision before code: an `agents-md` install target (or a
      renamed flag covering all instruction surfaces) that offers to append a
      marked LogicLoom block to the adopter's AGENTS.md, under the same
      never-overwrite/fenced-merge rules as `.gitignore`. Changes the install
      contract, so: design doc first.
      Confirmed while investigating, and it closes a question open since the
      smoke test: rules WITHOUT `paths` frontmatter "are loaded at launch with
      the same priority as `.claude/CLAUDE.md`" (Claude Code docs). So `rules`
      mode does work — it just does not travel.

### Adopter parity — structure ships, our data does not

- [x] LOOM-0048 — `.brain/` structure never reaches an npm adopter, and onboarding assumes it did `status:done`
      Raised 2026-08-31 from a structural audit of both distribution channels.
      A TEMPLATE CLONE gets `.brain/README.md`, stubbed from
      `.logic-loom/templates/brain-readme-template.md` by the strip manifest —
      structure ships, our data does not, which is correct. An NPM ADOPTER gets
      nothing: `payload-manifest.txt` carries `exclude: .brain` wholesale.
      This is not only a gap, it is a BROKEN REFERENCE:
      `initialize-project.md:200` instructs the agent that "`.brain/` keeps just
      its `README.md`" — a file the npm path never installs. Verified absent in
      kori-beta after a clean 393-file install of logicloom@6.6.1.
      DONE 2026-08-31. The fix needed BOTH `include: .brain/README.md` and the
      removal of `exclude: .brain` — the design doc first said only the second
      was required, which would have shipped nothing, because the copier selects
      a path only when an include matches it. Verified against the real
      assembler on the v6.6.2 tag: 276 files before, 277 after, exactly one
      `.brain` path, byte-identical to `brain-readme-template.md`, zero
      references to our work. Three assertions added and mutation-verified,
      including one that fails if anyone ever includes `.brain/wiki` or similar.
      ROOT CAUSE, and the thing to check on every future exclusion: because the
      payload builds from an already-sanitized tree, an `exclude:` on a path the
      strip manifest STUBS throws away safe structure. Two of the four `stub:`
      entries were affected; `todos.md` and `backlog.md` inherit correctly and
      arrive clean (verified: 0 LOOM items, 0 references to our work in
      kori-beta). `VISION.md` is NOT affected — its exclusion is deliberate and
      `/initialize-project` offers it from a template that does ship.

- [x] LOOM-0049 — Ship the `artifacts/` convention and a live backlog dashboard `status:done`
      Raised 2026-08-31. The generators already ship and are already
      repo-neutral — `build-backlog-index.sh` and `build-backlog-dashboard.sh`
      have zero references to our repo, and running them in kori-beta produced a
      working 11.8KB dashboard. What does NOT ship: the `artifacts/` directory
      itself, its convention README, any instruction to run the generators, and
      `check-generated-freshness.sh`.
      Fix `artifacts/` the way `features/` and `specs/` are already done —
      `.gitkeep` + `README.md` ship, content excluded. That pattern is in the
      manifest and works; this is applying it, not inventing it.
      Ship `check-generated-freshness.sh`. Its recorded exclusion reason —
      "it regenerates artifacts/backlog-dashboard.html … an artifact the payload
      does not ship and the adopter has no source for" — has expired: they have
      `todos.md`, `backlog.md`, and both generators.
      DASHBOARD MUST TRACK LIVE WORK. Decided: GitHub issues are RENDERED, never
      imported into `todos.md` — importing puts two writers on one id space and
      guarantees drift.
      The freshness gate and live data are reconciled by moving the fetch to
      VIEW time: the generated HTML stays a pure function of todos.md +
      backlog.md, so it is deterministic and the gate keeps its meaning, while an
      inline script fetches issues when the file is opened. Verified feasible —
      `api.github.com` returns `access-control-allow-origin: *`, so this works
      from `file://`; 60 req/hr unauthenticated, 5,000 with an optional token in
      localStorage, which also covers private repos. Owner/repo derived from
      `git remote` at build time. Must degrade VISIBLY ("issues unavailable")
      with no remote, no network, or a private repo and no token.
      DONE 2026-08-31. `artifacts/{.gitkeep,README.md}` ship; the three
      generated pages are excluded; `check-generated-freshness.sh` ships.
      The issues panel fetches at VIEW time only — proven, not asserted: a build
      with `curl`/`wget` PATH-shimmed to fail made ZERO network attempts, and an
      issue title that is not also a LOOM item appears nowhere in the output.
      TWO DEFECTS CAUGHT DURING IMPLEMENTATION, both would have shipped broken:
      (1) `artifacts` was ALSO stripped wholesale by the template strip manifest,
      so the new payload includes would have shipped nothing — the LOOM-0048
      mistake about to repeat in a second file. Now named per-file.
      (2) The hook derived owner/repo from `git remote` and passed `--repo`. The
      freshness gate regenerates WITHOUT that override, so it produced
      `GH_REPO = null` against a committed real value and the tracked artifact
      was PERMANENTLY STALE — the gate caught it on exactly that line. Fixed by
      making `project.conf`'s `repo` key the single deterministic source and
      removing the override; the hook now runs no git at all. `repo` is declared
      in our own project.conf as part of this change.
      Idempotency proven: two consecutive hook runs on an unchanged backlog
      leave the tree untouched.

- [ ] LOOM-0050 — Offer the CI methodology as templates the adopter can install and edit `status:open`
      Raised 2026-08-31. `payload-manifest.txt` excludes `.github` wholesale and
      that stays — those workflows are our release loop and name our topology,
      and we must never write into someone's CI unasked. But the consequence
      today is that an adopter is never OFFERED the methodology at all:
      `initialize-project.md` step 4f skips CI entirely for an adopted repo.
      Fix: ship the workflows as templates under
      `.logic-loom/templates/workflows/`, and turn step 4f from "skip entirely"
      into "offer, adapt, never install unprompted" — the same shape 1.5 already
      uses for VISION.md.

- [ ] LOOM-0051 — `/initialize-project` does not get an adopter to parity `status:open`
      Raised 2026-08-31. The stated goal is that `npx logicloom init` followed by
      `/initialize-project` leaves an adopter with the same structure and systems
      we have, unless they choose otherwise. It does not today.
      Current steps: PRD, VISION.md, project.conf, gate posture, memory+distill,
      constitution, agents, MCP/keys/upstream, remove-maintainer-CI, validate.
      Missing: the `.brain/` scaffold (LOOM-0048), `artifacts/` plus a first
      dashboard build (LOOM-0049), and the CI methodology offer (LOOM-0050).
      Depends on all three. The command is the single place these questions
      should surface, so it is the last piece to land, not the first.

### Adopter-found defects — mirrored from GitHub (kori-beta, logicloom@6.6.1)

Filed 2026-08-31. These five were found by auditing a real npm install and exist
as GitHub issues #77-#81. GitHub is INTAKE; these items are the record of record.
Each names its issue so the two cannot drift silently — close the issue when the
item is done, and say so here.

- [x] LOOM-0052 — Five plugin-declared agents never load, but docs and a command still dispatch them `status:done` `ref:gh#77`
      VERIFIED FIRST-HAND, not inspected: `subagent-architect`, `prd-specialist`,
      `team-synthesizer`, `framework-sync-agent` and `memory-context-agent` are
      absent from this session's own available agent types, while the two
      `.claude/agents/` project agents (`deep-reasoner`, `fast-worker`) are
      present. All five files exist under `plugins/*/agents/`; there is no
      `marketplace.json` anywhere and nothing of ours in `~/.claude/plugins/`.
      CLAUDE.md already documents this mechanism for HOOKS ("the repo's plugins/
      tree is not a plugin installation … so a per-plugin hooks/hooks.json is
      never read"); it holds for agents too and was never followed through.
      Effect: a command dispatching one by name silently gets a generic agent,
      losing the declared model tier and tool restrictions. Highest severity of
      the five — behavioural, silent, and in every install.
      `constitutional-governance-agent` is correctly NOT affected: it is
      hook-injected via the preflight, working as designed.
      DONE 2026-08-31. Maintainer chose: move all five to `.claude/agents/`.
      Not a new Principle XVI exception — CLAUDE.md already states "Keep the two
      agents as PROJECT files (.claude/agents/), never plugin agents (which lose
      hooks/mcpServers/permissionMode)". This applies that existing decision to
      the five left behind. `constitutional-governance-agent` stays in
      loom-governance: hook-injected, working as designed.
      PROVED BY OBSERVATION, not inference: immediately after the move this
      session registered all five as available agent types with their declared
      tools intact — the exact condition whose absence was the defect.
      Four plugin manifests updated (the validator enforces agents.list ==
      disk), four empty agents/ dirs removed, AGENTS.md registry restructured,
      and a `history-scrub-rules.json` rule that still named the old path fixed.
      New assertion mutation-verified twice by me independently: planting one
      back under plugins/*/agents/ fails, and removing one from .claude/agents/
      fails.
      ALSO FIXED, and it would have regenerated the defect: `/create-agent`'s
      doc routed new agents to `plugins/*/agents/`. Note the SCRIPT was already
      correct (`AGENTS_DIR=.claude/agents`) — only the doc was stale, which is
      the opposite of what the report implied. Its `<department>/` subdirectory
      is fine: Claude Code scans `.claude/agents/` RECURSIVELY and identity comes
      from the `name` field, not the path (vendor docs, checked because I
      initially suspected it as a second instance of the same defect).

- [ ] LOOM-0053 — Domain briefs hardcode a React/Next.js web stack with no adaptation point `status:open` `ref:gh#79`
      VERIFIED: `frontend.md` names React/Next/Vue/Angular and owns
      `src/components/**`; `testing.md` names Jest/Vitest/Cypress/Playwright;
      `backend.md` owns `src/api/**`, `src/services/**`. `database.md` is
      stack-neutral and fine.
      Found in a React Native/Expo repo with Deno edge functions — none of it
      fits, so swarm and team workers are primed with the wrong frameworks, the
      wrong runner, and ownership pointing at directories that do not exist.
      The issue's own scope note is CORRECT and I checked it: impact is advisory
      only. `freeze-write-scope.sh` has ZERO references to domain briefs — it
      resolves `owns:`/`freeze:` from a marker file or plan.md — so write-scope
      enforcement is unaffected. An earlier draft of that report claimed
      otherwise and was withdrawn.
      Same theme as LOOM-0048..0051: an adaptation point at adoption time is the
      fix, not a second hardcoded stack.

- [ ] LOOM-0054 — Three shipped files say the dangerous-command guard needs bash 4 `status:open` `ref:gh#78`
      VERIFIED at all three sites: `payload/rules/logicloom-governance.md:38`,
      `CLAUDE.md:95`, `.docs/architecture/governance-threat-model.md:32` — all
      say "bash 4+; fails open otherwise". The guard's own comments say the
      opposite: the libs are 3.2-compatible, it "ENFORCES on stock macOS", the
      re-exec is belt-and-braces, and falling through is "NOT a failure". The
      threat model contradicts itself inside one file — it documents the fix as
      closed around line 347.
      Worse than a typo because it UNDERSTATES protection, in the rule file every
      adopter installs: a macOS adopter could reasonably conclude they are
      unguarded when they are guarded. Straight correction, no decision needed.

- [ ] LOOM-0055 — architecture.conf count and path metadata is false in the release itself `status:open` `ref:gh#80`
      VERIFIED: plugins 18 vs 8 actual, agents 11 vs 8, commands 19 vs 24, test
      suites 28 vs 47. Release tooling re-stamps only the version keys, so the
      file looks maintained while the rest dates from the pre-v3.1.0 architecture,
      and the installer copies the false metadata into every adopted repo.
      LOWEST severity of the five, and the issue overstates it: NOTHING READS
      THESE KEYS. Only prose files and `bump-version.sh`, which touches version
      keys only. False metadata, not false behaviour.
      One factual error in the issue to correct when closing it: it claims
      `.docs/archive/` does not exist upstream. It does. Only
      `.docs/audit/message-preflight.log` is genuinely missing.
      Fix should also make the counts derived or dropped — a number nothing
      derives is a number that drifts, which is the reasoning already applied to
      the plugin manifest's removed `count` field.

- [ ] LOOM-0056 — Shipped .docs cite ~10 paths that never ship; no link check at release `status:open` `ref:gh#81`
      VERIFIED on four spot-checks, all genuinely absent from dev-main AND the
      tag: `.docs/workflows/sdd-waterfall.md` (cited by loom-architecture.md:85),
      `plugins/sdd-specification/agents/quality-assessor.md`,
      `plugins/loom-git/skills/git-push/SKILL.md`, `.logic-loom/memory/MEMORY.md`.
      The git-push one is the most damaging: it is a WORKED EXAMPLE in the graph
      convention doc and the real path is `git-push-workflow`, so anyone copying
      it produces a dangling graph edge.
      Root cause is structural, and the fix should be too: `.docs/` is authored
      against the full dev-main tree and published into a deliberately stripped
      one, with nothing link-checking it at release. A link check belongs beside
      the sanitization audit, where it can distinguish "dead everywhere" from
      "maintainer-only by design".

### Governance and constitution

- [x] LOOM-0001 — Maintainer sign-off on constitution v3.3.0 + the amendments extension point `status:done`
      Signed off 2026-08-24, followed-not-enforced by deliberate choice.
      LOOM-0002 stays OPEN and the honesty is the point: nothing loads
      `amendments.md`. It works because `CLAUDE.md` and `AGENTS.md` instruct
      agents to read it, which the threat model states plainly. Wiring it into
      `governance-preflight.sh` is a protected-hook edit and deserves its own
      change rather than riding along with a sign-off.
      Constitution **v3.3.0** and the amendments extension point are implemented
      but sit **uncommitted** in the working tree, awaiting maintainer sign-off on
      the ratified text. This is the only uncommitted work from the 2026-08-13
      pass (backlog §3.2).
      Shape as implemented: a fork adds mandates in `.logic-loom/memory/amendments.md`
      (seeded from `.logic-loom/templates/amendments-template.md`), never by
      editing `constitution.md`. Upstream ships no `amendments.md`, so a fork's
      mandates survive `/update-framework` and the constitution stays
      byte-identical to upstream. The only normative unit is a named mandate
      (`### Mandate: <NAME>` with `Constrains:` / `Rule:` / `Rationale:`) — no
      second surface, no per-principle override blocks. Effective governance is a
      conjunction: constitution AND every mandate. There is deliberately **no
      `Overrides` / `Waives` verb**, which makes a weakening mandate conspicuous
      rather than impossible; the adjudication defaults all fail toward the
      constitutional floor. Immutable principles I–III remain un-overridable.
      Tandem `CLAUDE.md` / `AGENTS.md` sync is included in the uncommitted change,
      as are corrections from adversarial review of the draft.
      **Version recommendation: keep it MINOR (3.2.0 → 3.3.0), not MAJOR.** For
      every existing project effective governance is **byte-identical** — upstream
      ships no `amendments.md`, nothing loads it, and no principle body moved.
      Repo precedent supports MINOR **2:1**, with the 3.0.0 bump the outlier.
      *(protected)* *(constitutional)*

- [x] LOOM-0002 — Inject `amendments.md` into the governance preflight `status:done`
      The amendments mechanism is **declared but not wired**. No hook, no
      preflight, no context module reads `.logic-loom/memory/amendments.md`;
      nothing validates a mandate; nothing fails closed. A fork that does not read
      the file gets no mandates **and no warning**. It works today only because
      `CLAUDE.md` and `AGENTS.md` instruct agents to read it — followed, not
      enforced.
      Wiring it into `governance-preflight.sh` is a **protected-hook edit** and
      therefore needs its own approved item rather than riding along with
      LOOM-0001. **VISION Thread #7 was deliberately left OPEN** for this reason
      rather than being closed alongside the amendments work.
      *(protected)*

- [x] LOOM-0003 — Answer the hook noise-reduction proposal `status:done`
      A proposal was put to the maintainer and has **no answer yet**. As proposed:
      **Keep asking** — branch and worktree create/delete; push; pull; merge;
      rebase; `reset --hard`; `clean`; `restore`; `git rm` / `git mv`; remote
      write; history rewriting; PR, release, repo, secret, auth and alias
      mutations; protected-file writes; dangerous shell.
      **Drop to silent** — commit; add; stash push/list/show; local tag;
      checkout/switch between existing branches; cherry-pick; revert; am/apply;
      fetch; issue create/close/edit/pin; run rerun/cancel.
      **Deviation recorded:** `reset --hard`, `clean` and `restore` are **kept in
      the ask set despite not appearing on the maintainer's list**, because they
      destroy uncommitted work. That is a deliberate departure and should be
      confirmed or overruled explicitly. Blocked on a maintainer decision, not on
      another item.

- [x] LOOM-0011 — Fix the `grep -c … || echo 0` two-line-value bug at `governance-preflight.sh:160` `status:done`
      The exact idiom the new `.docs/policies/shell-idiom-policy.md` warns
      against, still live in a shipped hook. **Deliberately not fixed during the
      2026-08-13 pass**: it is protected governance surface and needs its own
      approved change with its own approval gate.
      *(protected)*

### Release, distribution and externalization

- [ ] LOOM-0004 — Archive `kelleysd-apps/sdd-plugins-marketplace` `status:blocked` `blocked_on:external:maintainer archiving that repository (outside this repo)`
      Separate repository, **maintainer action** — not something this branch or
      any in-repo change can do. Private, not archived, last pushed 2026-02-06,
      containing the pre-rename `sdd-*` generation including plugins deleted
      months ago. **Zero in-repo references remain** (cleared in `d8716d1`), so
      archiving is now zero-risk. Blocked on maintainer action outside the repo.

- [x] LOOM-0017 — Add a `stub:` entry for this backlog file to the strip manifest `status:done`
      `.logic-loom/memory/backlog.md` ships as machinery but its **content is
      harness-dev-specific** — it names internal commits, a private sibling
      repository, and this repo's release topology. It needs a
      `stub: .logic-loom/memory/backlog.md` entry in
      `.logic-loom/scripts/bash/template-strip-manifest.txt` so a customer clone
      inherits the grammar header and an **empty** item list, exactly as
      `VISION.md` does today.
      Without this entry the file ships verbatim: `leak-guard.sh` only asserts
      that *listed* paths are absent, so an unlisted new file is silently
      shippable. The stub content should be the grammar sections above with the
      `## Items` section emptied.
      Not done in the same change that created this file because the manifest and
      the stripper were owned by concurrent work.

### VISION threads awaiting work

Direction lives in `VISION.md`; these are the *work* those threads imply.

- [x] LOOM-0007 — Make `.gitignore` patterns actually match the local-override filenames (VISION #2) `status:done`
      `.local/` and `*.local` still do **not** match `settings.local.json` or
      `CLAUDE.local.md` — the two files the patterns were added to cover. A user's
      local overrides are therefore tracked unless they notice.

- [x] LOOM-0009 — Document `artifacts/` (VISION #5) `status:done`
      `artifacts/` is absent from the `CLAUDE.md` directory structure **and** from
      `.docs/policies/file-structure-policy.md`. It is a real repo-root convention
      (vision / research / forensics / docs) that no shipped document describes,
      so a cloner has no way to learn it exists.
      **Done.** Documented in both places — `CLAUDE.md` § *Directory structure*
      and a new `### artifacts/` section in the file-structure policy (plus its
      Root Structure block and Quick Reference table).
      A **shipping defect** was found and fixed alongside it, which the original
      item mis-stated: VISION #5 called `artifacts/` *untracked*, but
      `artifacts/harness-graph.html` and `artifacts/logicloom-vision.html` are
      **git-tracked** and were in **no** strip list — so two hand-authored
      LogicLoom-internal pages (our harness breakdown and our vision/findings
      record) were shipping to customers verbatim. Fixed by adding a **wholesale**
      `artifacts` entry to `.logic-loom/scripts/bash/template-strip-manifest.txt`:
      the *convention* ships (documented), the *contents* do not — same class as
      `.docs/reports` and `.docs/design`. Wholesale rather than `artifacts/*.html`
      so the first non-HTML artifact dropped in there cannot leak, and no
      `.gitkeep` is shipped, so the directory is created on first use exactly like
      `web/`. Guarded by `tests/contract/test_backlog_dashboard.sh`.

- [ ] LOOM-0010 — Withdraw one side of the contested marketplace direction (VISION #8) `status:open`
      Thread #8 remains **CONTESTED**: it proposes making this repo its own
      marketplace via `marketplace.json`, which points the opposite way from the
      externalization direction in LOOM-0005. Neither can be designed until one is
      withdrawn. This item is the withdrawal decision itself; LOOM-0005 is blocked
      on it.

- [x] LOOM-0016 — Audit VISION threads #9–#18 `status:done`
      Threads #1–#8 were audited or resolved during the 2026-08-13 pass (#1 closed,
      #8 annotated, #2–#6 audited, #7 left open for LOOM-0002). **#9–#18 are
      untouched** — never read against current state, so their claims are of
      unknown accuracy. Audit each: still true, already fixed, or superseded.

### Dead code and test hygiene

- [x] LOOM-0014 — Remove the dead `mcp-servers/` loop at `setup.sh:206` `status:done`
      Loops over a nonexistent `mcp-servers/` directory — dead since the
      marketplace MCP removal. **Left in place deliberately** during the
      2026-08-13 governance pass rather than touched mid-pass; it needs its own
      change.

- [x] LOOM-0015 — Give `logging.sh` an override for `LOG_DIR` `status:done`
      `logging.sh` hardcodes `LOG_DIR` with no override, so **every test suite
      appends to the operations log**. A test-isolation gap, not a correctness
      bug — but it means the operations log is polluted by test runs and cannot be
      read as a record of real operations.

### Backlog schema — promoted out of the deferred set

One item from that review that was NOT held: it was promoted into active work
and completed. Its id did not change on the way across.

- [x] LOOM-0022 — Make the dashboard honour the consumer-liberal compatibility rule `status:done`
      The grammar's *Schema compatibility* section states the contract as
      **producer strict, consumer liberal**: a consumer must carry an
      unrecognised `status` or `level` through verbatim, never drop the item,
      bucket it under a catch-all, and never fail. `build-backlog-dashboard.sh`
      did not honour that rule — it grouped by a fixed list of the four known
      statuses, so an item carrying a future value was **silently omitted from
      the page**. Not reachable from today's collector, which rejects an
      out-of-vocabulary status at the fatal gate, so it was latent rather than
      live. It becomes real the moment a second producer writes an index, which
      is the whole point of publishing a schema.
      **Done**, on BOTH fields rather than the one recorded here. The rework that
      made item CLASS the page's outer dimension had to derive its groups from
      the data anyway, so the fix landed properly instead of half-way:
      * `status` — the group list is now `known vocabulary, in order` **+**
        `every other status actually present, unique-sorted`. An unknown status
        gets its own labelled group ("<value> (unrecognised status)"), and is
        counted in the page-level tally.
      * `level` — a level outside the viewer's class table lands in an explicit
        **Other** section naming the levels it saw, rather than falling out of
        every class section. This is the same defect one field over, and it
        became reachable the moment `level` was made a visible dimension.
      Asserted in `tests/contract/test_backlog_dashboard.sh` § 14 with a fixture
      carrying an unknown status **and** an unknown level: both items render,
      both values appear verbatim, neither is coerced, and the generator exits 0.

### Environment promotion

- [x] LOOM-0024 — Base development worktrees on `dev-main` explicitly, never on the default branch `status:done`
      VERIFIED cost, this session: `EnterWorktree` bases a new worktree on
      `origin/<default-branch>`. In this repository the default branch is `main`
      — the sanitized template line — so a worktree came up on the v6.4.1
      release merge instead of `dev-main`, and a review agent then analyzed the
      SANITIZED tree and produced findings that were artifacts of it (stripped
      files reading as missing, stubbed files as incomplete).
      The usual fix does NOT apply. `git remote set-head origin --auto` repairs a
      STALE `origin/HEAD`; ours is not stale — `main` genuinely IS the production
      line, and it must stay the default so "Use this template" clones the
      sanitized tree rather than the dev tree. So the guard has to run the other
      way: any tooling that creates a branch or worktree for development work
      must name the integration branch EXPLICITLY and must never resolve its base
      from the default branch, from `origin/HEAD`, or from an unqualified "main".
      Shape is undecided and worth deciding before building: a documented rule
      only (cheapest, followed-not-enforced), a `PreToolUse` guard on the
      worktree-creating tool, or a startup assertion that reports when the
      current tree is `main`. A customer project has no such constraint and
      should follow the ordinary advice instead — see
      `.docs/policies/environment-promotion-policy.md` § 2.

- [x] LOOM-0025 — Ship opt-in environment-promotion scaffolding, adoptable into an EXISTING project `status:done`
      DONE. `/scaffold-environments` (plugin `loom-maintenance`) stands the
      methodology up in a user's own project. Both constraints were honoured and
      are contract-tested, not merely claimed.
      (1) OPT-IN: `--plan` is the default and writes nothing; `--apply` REQUIRES
      `--only=<targets>`, so there is no apply-everything-by-omission; there is
      no `--force`, and an existing file is left byte-identical and reported as a
      conflict. Declining leaves the tree byte-identical.
      (2) EXISTING PROJECT: `detect-environment-topology.sh` reads branches,
      roles, default branch, CI provider, environment-ish workflows, and any
      existing declaration; the scaffolder then proposes a DELTA. No branch is
      ever created — a role with no matching branch yields no environment, so
      greenfield gets ONE environment (Principle V) and a project that already
      has `develop`/`staging` gets a declaration in ITS names. Detection reads
      `.git` refs off the FILESYSTEM and shells out to git nowhere, so it is
      provably non-mutating, works under `subagent-git-guard.sh`, and its
      fixtures need no repository.
      Writes, all opt-in and all named before writing: a filled-in
      `environments.conf`; a branch-boundary CI check generalized from
      `branch-topology-guard.yml` and parameterized by their branches; a
      promotion checklist carrying the portable patterns; a commented deploy-seam
      placeholder per environment that exits NON-ZERO (a placeholder exiting 0
      would report a deploy that did not happen).
      Also generalizes the § 2 default-branch trap WITHOUT exporting LogicLoom's
      inversion: the generated guard is mode-selected
      (`expect-default-is-integration` vs `expect-explicit-base`), and is not
      generated at all when there is no integration branch or the default branch
      is unknown (fail closed).
      Does NOT write, and the contract suite asserts it: cloud/CI deploy logic,
      secret values, migration runners, seed or teardown scripts, rollback.
      Landed: `plugins/loom-maintenance/commands/scaffold-environments.md`,
      `plugins/loom-maintenance/skills/environment-scaffolding/SKILL.md`,
      `.logic-loom/scripts/bash/{detect-environment-topology,scaffold-environments}.sh`,
      `.logic-loom/templates/environment-promotion/` (5 templates),
      `tests/contract/test_environment_scaffolding.sh` (90 assertions),
      `.docs/policies/environment-promotion-policy.md` § 11 (amends § 10).
      The name deliberately avoids BOTH `/promote` and `/deploy-promote` —
      LOOM-0006 stays open: this command promotes nothing, so it must not consume
      the name the actual promotion command should have.
      Deferred out of scope, minted below: LOOM-0028, LOOM-0029.

- [x] LOOM-0026 — Give `/promote` a typed-exact-phrase confirmation at the release step `status:done`
      **SUPERSEDED, not implemented as written.** The maintainer's decision on
      2026-08-24: the maintainer `/promote` stays exactly as it is — the
      template-release driver, stripped by exact path, untouched. The
      escalating-confirm ladder ships instead as a customer-facing lifecycle:
      `/promote-dev` and `/promote-staging` prompt (skippable), `/promote-prod`
      demands a typed exact phrase that no flag bypasses. Confirmation strength
      resolves from the target environment's declared `confirm` value first, so
      the ladder is configurable rather than hardcoded. This also consumes the
      customer-facing promotion command LOOM-0006 anticipated, so that item's
      `/deploy-promote` naming suggestion is moot — `/scaffold-environments`
      correctly declined the name and these are the promotion commands.
      `.docs/policies/environment-promotion-policy.md` § 4.3 adopts escalating
      confirmation strength by blast radius, with a typed exact phrase and no
      skip flag at production scale. `/promote` implements the ladder's shape —
      per-mutation Principle VI approval, no skip flag anywhere, a hard stop on a
      failed sanitization audit — but has no typed-phrase step. Its
      highest-consequence action (publishing a sanitized template line the world
      clones) is confirmed by the same prompt as every other git mutation.
      Small change, and the policy currently has to state the gap rather than
      cite the implementation. Decide whether the phrase belongs at the dispatch
      step, at the PR-open step, or both.

- [x] LOOM-0030 — Write the evaluator hard-gate contract before hardening anything `status:done`
      `.docs/architecture/evaluator-protocol.md` is still stamped v0.1 and
      specifies no gate semantics at all — the only two uses of "gate" defer
      gating to `/plan-review`. VISION thread #16 asks to harden a contract that
      does not exist yet, so hardening is not the first move: deciding is.
      Decide whether an evaluator FAIL blocks `/git-push`, write that down, then
      harden. Surfaced by the VISION #9-#18 audit (LOOM-0016), which found the
      thread understated its own gap.

- [x] LOOM-0031 — Reconcile threat-model residual #4 with the host's native sandbox `status:done`
      `.docs/architecture/governance-threat-model.md` asserts "No execution
      sandbox" as a LogicLoom fact. The runtime now sandboxes Bash by default —
      `dangerouslyDisableSandbox` is the opt-out, which means sandboxing is the
      standing posture rather than an absent capability. The doc therefore
      OVERSTATES the gap, which is the same defect class this repo spent a
      session removing in the other direction. Correct it, and state plainly
      what the native boundary does and does not cover rather than replacing one
      overstatement with another.

- [x] LOOM-0032 — Determine empirically whether plugin `hooks/hooks.json` files fire at all `status:done`
      `governance-threat-model.md` (~line 248) records the flat-array shape used
      by `plugins/*/hooks/hooks.json` as "almost certainly inert", which would
      mean `loom-orchestrator`'s Stop/SubagentStop hooks have never run. The
      evidence is consistent with that: `subagent-activity.log` holds ONE line,
      last written 2026-06-14. Yet `tests/contract/test_plugin_lifecycle.sh`
      asserts the file exists — a test that passes on the presence of something
      that may do nothing.
      Determine it by observation, not by reading the shape. Then either fix the
      registration or delete the file AND its assertion. Blocks any honest work
      on VISION thread #11.

---

## Provenance

These items were split out of `.logic-loom/memory/backlog.md` on 2026-08-24,
when the single stream was separated into **todos** (this file, active work) and
**backlog** (deferred work). Every item kept its id, its title and its body
verbatim; only the file it sits in changed, and with it the `level` the
collector derives. Nothing was merged, renumbered or dropped: the 29 items in
the pre-split file are the 16 here plus the 13 in `backlog.md`.

For where the ids originally came from — the 2026-08-13 report items A–K, the
cross-provider index-contract review, and the environment-promotion policy pass
— see `.logic-loom/memory/backlog.md` § *Provenance*, which remains the single
record of minting history for both streams.
