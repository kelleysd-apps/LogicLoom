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
