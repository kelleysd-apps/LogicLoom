# LogicLoom Backlog — cross-cutting work to bring up LATER

**Level 0 of the Todo Architecture SSOT, deferred half.** Authoritative list for
work that is **not a feature** — governance, hooks, tests, CI, release tooling,
policy and documentation — and that has been **explicitly deferred**: a "decide
later", a recorded analysis with no consumer yet, an improvement that is real
but not needed today.

Its active half is `.logic-loom/memory/todos.md`: same grammar, same id space,
different question. **Backlog answers "what should I bring up later"; todos
answer "what am I doing".** An item that is being worked, is next up, or is
waiting only on an answer already asked for belongs *there*, not here — see
§ *Promotion* in that file for how an item moves, and for the rule that its id
never changes when it does.

**Nothing here is rejected.** A rejected idea gets written down as rejected (the
grammar's *Deliberately excluded* section is where that happens) and then
deleted. Everything in this file is work someone may pick up; it is filed here so
the reasoning survives and the next person hits it instead of re-deriving it.

Feature work does **not** belong in either file. It belongs in
`features/<name>/plan.md` (swarm pack) or `specs/###-name/tasks.md` (SDD pack).
Strategic direction does not belong here either — that is `VISION.md` § Open
Threads. **VISION threads are *direction*; backlog items are *work*.** A thread
may spawn one or more items; an item never supersedes a thread.

Full rationale and the SSOT hierarchy: `.docs/policies/todo-architecture-policy.md`.

---

## Item grammar (normative)

This section is the specification. A collector parses this file; a cross-project
aggregator consumes the collector's output. Keep it simple and keep it stable.

### Scope — where items are read from

Two rules, both required, and neither optional for a conforming collector:

1. **Items are read only from below the `## Items` heading**, to the end of the
   file or the next `## ` heading, whichever comes first.
2. **Fenced code blocks are skipped**, everywhere, including inside `## Items`.

Without these, the illustrative lines in this very section would be collected as
real items. `LOOM-0042` through `LOOM-0046` below are **examples inside fences and
are not minted ids** — they are free to be minted later as ordinary items.

### The line

```
- [ ] LOOM-0042 — Short imperative title `status:open`
```

With an optional dependency tag and an optional indented body:

```
- [ ] LOOM-0043 — Wire the collector into CI `status:blocked` `blocked_on:LOOM-0042`
      Free prose. Any length. Indented at least two spaces. Belongs to the
      item above until the next `- [` at column zero.
```

**Full syntax, in order, left to right.** Every rule here is what a conforming
collector must implement, and matches the reference implementation in
`.logic-loom/scripts/bash/build-backlog-index.sh`:

1. **Marker.** The line begins at **column zero** with `- [ ] ` or `- [x] ` —
   hyphen, space, bracket, one space *or* a lowercase `x`, bracket, **exactly one
   space**. Leading indentation disqualifies the line: an indented `- [ ]` is
   body prose, not an item.
2. **Id.** Everything up to the separator, trimmed.
3. **Separator.** The **first** occurrence of ` — ` — space, U+2014 EM DASH,
   space. A hyphen, an en dash, or an em dash without surrounding spaces is not a
   separator. Later ` — ` occurrences are ordinary title text.
4. **Title.** Everything between the separator and the `status:` tag, trimmed.
   Free text, one line, may contain any character except a tab (tabs are
   normalised to spaces).
5. **Tags.** Backtick-wrapped `key:value` tokens, **after** the title,
   space-separated. `` `status:` `` is **required and must come first**; every
   other tag follows it. This is not cosmetic — the title is defined as the text
   preceding the `status:` tag, so a tag placed before it is swallowed into the
   title.
6. **Only the first occurrence of a tag is read.** A second `` `status:` `` or
   `` `blocked_on:` `` on the same line is silently ignored. Do not write one.
7. **Unknown tags are not parsed.** A `` `foo:bar` `` token after the `status:`
   tag is neither read nor rejected; it is invisible to the collector. Do not
   invent tags — see *Deliberately excluded*.

**Structural context.** Two rules from *Scope* plus two more, all enforced by the
collector:

- A `#`-prefixed line inside `## Items` sets the item's **heading** (the
  `source.heading` a collector derives). A `## ` line **ends** the section.
- A line that is neither an item line nor a heading is **ignored entirely** —
  including an item's indented body. **The body is for humans; no part of it
  reaches the index.** Put nothing in a body that a consumer needs.

Regex for the item line (POSIX ERE):

```
^- \[[ x]\] (LOOM-[0-9]{4,}) — (.+?) `status:(open|in_progress|blocked|done)`
```

The regex is a summary, not the specification — rules 5–7 above are not
expressible in it.

### Fields

| Field | Required | Form | Notes |
|---|---|---|---|
| checkbox | yes | `- [ ]` or `- [x]` | Human/GitHub affordance only. **Not** the parsed status. |
| id | yes | `LOOM-` + at least 4 digits | Immutable once minted. Never reused. Unique across the whole index. |
| separator | yes | ` — ` (space, em dash, space) | Separates id from title. First occurrence wins. |
| title | yes | one line, free text | No newline, no tab. Ends at the `status:` tag. |
| `status:` | yes | `open`\|`in_progress`\|`blocked`\|`done` | Closed vocabulary. Backtick-wrapped. **First tag on the line.** |
| `blocked_on:` | no | comma-separated entries | Each entry is an **id** or `external:<reason>`. See *Blocked on*. |
| body | no | indented lines under the item | Human detail. **Not parsed, not indexed.** |

### Ids

- Format `LOOM-NNNN`, zero-padded to at least four digits. Past `LOOM-9999`,
  widen to five digits; compare numerically, never lexically.
- **Syntax a collector accepts:** `[A-Z][A-Z0-9]*-[0-9]{4,}` — an uppercase
  alphanumeric prefix starting with a letter, a hyphen, then four or more digits.
  Note the parser accepts **any** conforming prefix; that a project's ids all use
  *its own* declared prefix is an **authoring lint**
  (`lint-backlog.sh`, class `prefix-mismatch`), not a parse rule. The two are
  separate on purpose: a collector that rejected a foreign prefix could not
  collect a backlog that had legitimately been renamed mid-life.
- **The prefix is immutable once the first id is minted.** It is declared once as
  `id_prefix` in `.logic-loom/config/project.conf`. Changing it afterwards
  strands every already-minted id — nothing rewrites them — and breaks every
  `blocked_on` reference that names one. Nothing enforces this; no hook reads
  `project.conf` and no collector rewrites this file. Pick it before the first
  item, then never touch it.
- **Allocated monotonically**: next id = (highest id ever present in this file) + 1.
  Ids are **never reused**, including after an item is deleted. If you delete a
  done item, its id stays burned — leave a `<!-- burned: LOOM-0031 -->` comment
  or simply never reissue.
- **Immutable once minted.** Editing a title, status, body, or file position does
  not change the id. This is the whole point: a content-hash id churns on every
  wording edit, and a daily brief would then report the same item as new work.
  A visible short id survives rewording, reordering, and reformatting.

### Duplicate ids

An id identifies **exactly one** item. This is the strictest rule in the grammar
because it is the one a consumer depends on without being able to check it: the
id is the primary key, and two rows sharing one means "the item with id X" has no
answer.

The rule holds across the **whole index**, not just this file. Feature and spec
task ids are qualified `<dir>:<task-id>` by the collector and land in the same id
space, so a collision between two sources counts.

**A duplicate is fatal to the collector.** `build-backlog-index.sh` exits
non-zero, writes nothing, and leaves any previous index untouched. It does not
merge the rows, pick one, or drop one — a consumer cannot tell a dropped item
from a nonexistent one, so nothing is dropped quietly. `lint-backlog.sh` reports
the same defect as an advisory finding (class `duplicate-id`) while you author.

### Status

The vocabulary is closed at exactly four values: `open`, `in_progress`,
`blocked`, `done`. No others. **A collector encountering anything else must
error, not guess** — the reference implementation treats it as fatal and refuses
to write the index.

(That strictness is the **producer** obligation. A **consumer** of an already-
built index has the opposite obligation — see *Schema compatibility*.)

**Why a `status:` tag and not four checkbox glyphs.** A checkbox has two states
and cannot express four. The obvious extension — `[ ]`/`[~]`/`[!]`/`[x]` — was
rejected: `[~]` and `[!]` are not real checkboxes, they render as literal text on
GitHub, and every markdown formatter, editor plugin and "fix my todos" script in
existence treats the box as a two-state token it may normalise. Putting the
load-bearing value in a token that tools rewrite is how the status silently
becomes wrong.

So the two are split by audience: **the checkbox is for humans, the tag is for
the parser.** The rule is `- [x]` if and only if `` `status:done` ``; every other
status keeps `- [ ]`. The redundancy is deliberate and one-directional — the
collector reads `status:` and ignores the box. A mismatch is an authoring lint,
never an ambiguity.

### Blocked on

`` `blocked_on:` `` holds a comma-separated list. Each entry is trimmed;
**internal whitespace is preserved**. An entry is one of exactly two kinds:

| Kind | Form | Meaning |
|---|---|---|
| id reference | `LOOM-0002` | Blocked by **another item in this index**. Must resolve to a real id. |
| external blocker | `external:<reason>` | Blocked by something **outside this index** — free text. |

```
- [ ] LOOM-0044 — Depends on another item `status:blocked` `blocked_on:LOOM-0042`
- [ ] LOOM-0045 — Depends on a person `status:blocked` `blocked_on:external:maintainer decision on the proposal`
- [ ] LOOM-0046 — Both at once `status:blocked` `blocked_on:LOOM-0042,external:upstream release`
```

The two kinds are distinguished by the literal prefix `external:` **and nothing
else**. There is deliberately **no taxonomy of blocker kinds**, no
`blocker_type` field, and no structure inside the reason. The one distinction
that earns its place is *inside the index* vs *outside it*, because that is the
one a reader has to act on: an id reference clears when that item closes, and an
external blocker clears only when a human does something.

Rules:

- A reason is **required**: bare `external:` is an authoring finding. "Blocked,
  reason withheld" is the state this marker exists to end.
- A reason **may not contain a comma** — the comma is the list separator. Reword.
- `external` is a **reserved prefix**: no `features/` or `specs/` directory may
  be named `external`, because their task ids are qualified `<dir>:<id>` and
  would otherwise be indistinguishable from an external blocker.
- `lint-backlog.sh` checks id references against the id set (class
  `unknown-blocker`) and **exempts** `external:` entries from that check.
- A `status:blocked` item with no `blocked_on:` at all is legal but unhelpful —
  it tells a reader an item is stuck and refuses to say why. Prefer an
  `external:` reason.

### Source pointer

**Do not write one.** The collector derives an item's source from the file path
and the nearest preceding heading. Hand-written source pointers rot the moment an
item moves between headings, and they add authoring friction for information the
tool already has.

### Schema compatibility

The collector emits `schema_version` as a single integer. It is the **only**
compatibility signal, and producer and consumer have **opposite** obligations —
conflating them is what turns a closed vocabulary into a breaking change.

- **Producer (a collector) is strict.** It emits only the four `status` values
  and only the known `level` values, and treats anything else as fatal.
- **Consumer of an index is liberal.** On a `status` or `level` it does not
  recognise it must: carry the value through **verbatim** (never coerce, never
  map to a known value), **never drop the item**, bucket it under a catch-all,
  and not fail. Unknown object keys are ignored, not rejected.

**Additive — no version bump, no consumer change:** a new *optional* field; a new
value added to the `status` or `level` vocabulary; a new `source` sub-key. These
are safe only because the consumer rule above is written down in advance.

**Breaking — bump `schema_version`:** removing or renaming a field; making an
optional field required; changing a field's JSON type; changing the meaning of an
existing field or value; changing id syntax, the `<dir>:<id>` qualification, or
the `external:` marker; changing what `source_digest` is computed over.

A consumer reading a **higher** `schema_version` than it understands must say so
and stop, not guess. A **lower** one it may read.

This is a stated rule, not machinery. Nothing validates a consumer; there is no
negotiation, no capability list, no migration engine. One integer and this
paragraph is the whole mechanism.

### Deliberately excluded — do not add these

The following were considered and **rejected**. This paragraph exists so they are
not quietly re-added later:

- **owner** — this is a single-maintainer harness; an owner field is noise, and
  on a fork it is wrong on day one.
- **estimate / story points** — unverifiable, and nothing consumes them.
- **percent complete** — the four-value status is the whole progress model.
  Percentages invite made-up numbers.
- **priority** — file order is the priority. A separate priority field
  immediately disagrees with the order and then someone has to reconcile them.
- **per-item timestamps** — git already records when every line changed, more
  accurately than a hand-maintained date will.

A richer schema on day one is the classic failure of this design: the fields go
stale, the parser grows special cases, and authors stop adding items because the
ceremony costs more than the item is worth. Add a field only when a consumer
exists that cannot work without it.

### The grammar above is normative for BOTH streams

This section is the specification for `.logic-loom/memory/todos.md` as well as
for this file. There is **one** item grammar, one parser
(`build-backlog-index.sh`), one linter, and one id space; the two files differ
only in **scope** (deferred vs active) and in the `level` the collector derives
from the path — `backlog` here, `todo` there.

`todos.md` deliberately does not restate any of it. Two copies of a normative
grammar disagree the first time one is edited, and the tools implement exactly
one of them.

Ids are unique **across both files**, because `blocked_on:` references cross the
streams. The counter is **derived, never stored**: next id = (highest id present
in either file) + 1 — `lint-backlog.sh --next-id` computes it. A stored counter
would live in one file and be silently wrong the moment an item was appended to
the other. A colliding mint is caught mechanically: the linter reports it as
`duplicate-id` naming both files, and the collector treats a duplicate anywhere
across all sources as fatal — non-zero exit, no index written.

### Ship / strip

Both files **ship** as machinery — a cloner should inherit the grammar, the
two-stream shape and an empty item list, not this repo's maintenance items.
Their **content is harness-dev-specific**, so each has its own `stub:` entry in
`.logic-loom/scripts/bash/template-strip-manifest.txt`, exactly as `VISION.md`
has:

```
stub: .logic-loom/memory/todos.md   :: .logic-loom/templates/project-todos-template.md
stub: .logic-loom/memory/backlog.md :: .logic-loom/templates/project-backlog-template.md
```

Without an entry a file ships verbatim: `leak-guard.sh` only asserts that
*listed* paths are absent, so an unlisted new file is silently shippable. That
wiring is tracked as LOOM-0017 in `todos.md`.

---

## Items

### Governance and constitution

- [x] LOOM-0013 — Decide whether Principles I and III should report SKIP for a harness-shaped repo `status:done`
      `constitutional-check.sh` still reports findings for Principles **I
      (Library-First)** and **III (Contract-First)** — no `libs/`, no contract
      files. These findings are *real for a shell/markdown harness*, and they are
      **not path bugs** (those were fixed in `26bac08`). Open question: should
      these principles report SKIP when the repo has no product workspace, rather
      than a permanent finding a reader learns to ignore? Deciding "no" is a valid
      outcome — but it should be decided, not left ambient.

- [ ] LOOM-0036 — Decide whether routing surfaces should be verified against disk — analysis done, decision deferred `status:open`
      **Considered and deferred on 2026-08-25, with the analysis already
      complete.** Do not re-derive this; what is left is a yes/no call, best made
      at the START of a cycle rather than on a release day.
      A **routing surface** is any table, trigger map, or dispatch regex that maps
      a command/skill/agent name to behaviour. The v6.5.0 cycle found that a
      five-month-old command consolidation (v5.1.0, commit `7b6bb69`, which merged
      `/specify` + `/plan` + `/tasks` into `/specification` and deleted three
      skills) had left stale references across roughly 30 files, because **nothing
      fails when a routing surface goes stale**. Fixing them consumed most of a
      release day.
      **Already verified — do not rebuild it.** (a) `plugins/*/.claude-plugin/plugin.json`
      inventory blocks, `tests/contract/test_plugin_manifest_schema.sh:246-315`,
      checked against disk in both directions (declared-but-absent AND
      on-disk-but-undeclared). (b) The `.claude/commands/*.md` <-> `plugins/*/commands/`
      bridge, `tests/contract/test_plugin_command_bridge.sh:66-160, 220-240`,
      bidirectional. (c) Seven individually named commands via a hardcoded
      allowlist at `test_plugin_command_bridge.sh:157-163` — an allowlist, not a
      general rule.
      **Not verified:** `.claude/context/{agents,skills,workflows}.md`,
      `.logic-loom/memory/{skill-activation-triggers,agent-collaboration-triggers}.md`,
      the `AGENTS.md` pack/skill/delegation tables, `CLAUDE.md`'s four Quick
      Command Reference tables, `constitutional-governance-agent-knowledge.md`,
      and — most notably — two *executable* dispatch regexes with zero test
      coverage: `load-context.sh:215,220` and `create-agent.sh:494`. Also
      `governance-preflight.sh:171-227`, where `test_orchestration_hook.sh:133-166`
      asserts the nudge fires but never asserts that the command it names resolves.
      **The proposal that was analysed:** extend `test_plugin_command_bridge.sh`
      (not a new suite — it already owns command-name truth) to extract
      `/[a-z][a-z-]*` tokens from a declared list of routing-surface files and
      assert each resolves to `.claude/commands/<name>.md`.
      **Why deferred.** (1) It needs an intentional-mention allowlist from day
      one: the repo deliberately names dead commands in prose — `AGENTS.md:199`
      explains that `/specify` no longer exists, and `.claude/context/skills.md:310-315`
      is a deprecated-to-current redirect table whose entire left column is dead by
      design. Every allowlist entry is a permanent future false-negative. (2) It
      would not catch the most likely future error: a row repointed at a command
      that exists but is the wrong one passes, stale *descriptions* (right name,
      wrong stated behaviour) are invisible, and bare skill/agent names without a
      `/` prefix are too noisy to match — so the middle column of every routing
      table stays unchecked. (3) The declared file list is itself an unverified
      routing surface; it goes stale silently, the same failure mode moved up one
      level. (4) Timing: this cycle was spent REMOVING checks that asserted things
      they did not actually verify. Adding a partially-effective gate on release
      day, against that backdrop, is the wrong moment.
      **The honest counter-argument**, so this record is not one-sided: it WOULD
      have caught the `/debug` row that took manual sweeping to find, and it WOULD
      catch the next consolidation's leftovers. The reviewer's own verdict was
      "modest value, real maintenance drag — I'd take it, scoped tight." This is a
      judgment call on timing and scope, **not a rejection of the idea**.
      **Alternative worth weighing next cycle:** stop hardcoding inventories in
      prose rather than testing them — a count or list that is not written down
      cannot go stale. That may be the better answer for the doc surfaces even if
      a test is right for the two executable regexes, which are the strongest
      candidates for coverage: live dispatch, zero tests today.

### Release, distribution and externalization

- [ ] LOOM-0005 — Decide the plugin-externalization direction `status:blocked` `blocked_on:LOOM-0010`
      A **decision, not an implementation** (backlog §8.1). The in-repo residue is
      already cleared; what remains is the direction itself. Constraints, restated
      because they govern the decision:
      - Roughly **1.5 of 8** plugins could leave cleanly (`sdd-specification`, and
        parts of `loom-creation` after decoupling). That figure is a judgement
        call from dependency reading, not a proven decoupling; the `loom-creation`
        split in particular is unverified.
      - `loom-governance` **is** the hook floor — a user-disablable marketplace
        plugin is not a floor.
      - All **19** bridged commands are pointers into `plugins/` with **zero
        static fallback**. Removal deletes `/swarm`, `/research`, `/cross-check`,
        `/git-push`, `/promote`, `/update-framework`.
      - **Principle XVI requires every plugin to declare `loom-governance` as a
        dependency** — which a harness-agnostic third-party plugin cannot do.
        Externalization therefore needs a **constitutional amendment**, not just
        tooling.
      - **VISION Thread #8 points the opposite way** (make this repo its own
        marketplace via `marketplace.json`). One direction must be withdrawn
        before either is designed — hence the block on LOOM-0010.
      *(constitutional)*

- [ ] LOOM-0006 — Resolve the `/promote <env>` name collision `status:open`
      `/promote` is stripped by **exact path** in the strip manifest
      (`plugins/loom-maintenance/commands/promote.md`, `.claude/commands/promote.md`),
      so a customer-facing `/promote <env>` would either collide with the
      maintainer release driver or force a manifest restructure. Documented and
      undecided. **Suggested resolution: `/deploy-promote <env>`.**

- [ ] LOOM-0035 — Consolidate `/promote` and `/promote-prod` into a single production-release command named `/promote-prod` `status:open`
      **Decided, not proposed.** The maintainer asked for this directly on
      2026-08-25, immediately after approving the 6.5.0 release: one command to
      promote to production/release, and it should be `/promote-prod`. What is
      open is the design, not the decision.
      Today there are two, and the split confuses people. `/promote` is the
      maintainer-only template release driver (dev-main into the sanitized `main`
      line), stripped at release so a customer never sees it. `/promote-prod` is
      the top rung of the environment promotion lifecycle: it gates, confirms,
      and calls the deploy seam the project owns. Both get called "promote to
      prod" in conversation; only one publishes a release.
      The real tension, stated so whoever picks this up does not rediscover it:
      `/promote` is stripped from a customer's clone and `/promote-prod` ships to
      customers. Merging them means either one command that behaves differently
      depending on whether it runs on the maintainer's dev line or in a
      customer's project, or a decision that the maintainer release path stops
      being a slash command at all. That choice is unmade and is the substance of
      the work.
      One contract must survive whatever consolidation happens: prod requires a
      **typed exact phrase that no flag, env var, or non-interactive path
      bypasses**. A merge that weakens it — or that lets the maintainer path
      inherit a lower confirmation strength — is not an acceptable answer.
      A second contract, added 2026-08-25 with evidence: the consolidated
      `/promote-prod` **must own GitHub Release publication**, not just tagging.
      Evidence — the release path created a git tag and stopped. Tags exist for
      **v6.3.0, v6.3.1, v6.4.0, v6.4.1 and v6.5.0; GitHub Releases exist for
      none of them.** The Releases page showed **v6.2.0 as "Latest" across five
      consecutive releases**, and nothing went red, because no step created a
      Release and no command asserted one existed. v6.5.0 was published by hand
      on 2026-08-25; the four back-releases stay unpublished by decision
      (writing notes after the fact is guesswork presented as a record).
      The mechanism now lives in `.github/workflows/release-tag.yml`, which
      creates a **draft** Release from the matching `## [X.Y.Z]` CHANGELOG
      section — read from the dev-main commit named by the snapshot's
      `Source-dev-main:` trailer, because `CHANGELOG.md` is in the strip
      manifest and does not exist in the sanitized tree the workflow runs on.
      `/promote` step 7 verifies it and fails the hand-off when it is missing.
      What consolidation must preserve: the mechanism stays in the **workflow**
      (a step that runs only when someone invokes the right command is exactly
      how this drifted for five releases), the Release is created as a **draft**
      and **published by a human**, and creation is **idempotent**. What
      consolidation must add: `/promote-prod` today only *checks* for a Release
      — it cannot drive the harness release path at all, since `/promote` is
      stripped from a customer's clone and `/promote-prod` ships to customers.
      That asymmetry is the same one this item already names, now with a
      concrete capability riding on it.
      Related to LOOM-0006, which is the other half of the same naming problem
      (a customer-facing `/promote <env>` colliding with the stripped release
      driver); resolving this one may resolve or reshape that one.
      References: this cycle's 6.5.0 release verdict, and `CLAUDE.md`
      § *Quick Command Reference — Environment promotion*, which currently
      documents the `/promote` vs `/promote-prod` distinction explicitly and will
      need updating.

- [ ] LOOM-0037 — Decide how to stop a fix to `promote-to-main.yml` from taking effect one release late `status:open`
      **From the v6.5.0 release day (2026-08-25). The original question here —
      "what opened those three Actions-authored PRs?" — is ANSWERED. What is
      still open is the property that answer exposed.**
      **The answer: `workflow_dispatch` runs the workflow from the DEFAULT
      branch.** `gh run view 32899320230 --json headBranch,headSha` returns
      `headBranch: main`, `headSha: 3d17c399…`. Every release dispatched that
      night executed **`main`'s copy**, which at that point was the **v6.4.1**
      workflow — not the `dev-main` copy being promoted.
      `git show v6.4.1:.github/workflows/promote-to-main.yml` has a step
      `- name: Publish via PR to main` (line 196) that calls `gh pr create` under
      the built-in `GITHUB_TOKEN`. That is what opened the three PRs. The
      GitHub behaviour they hit is not in doubt: a PR authored by `GITHUB_TOKEN`
      emits no `pull_request` event, so no workflow fires, and a PR with *no*
      checks looks identical to one whose checks all passed.
      **Corrected provenance — do not re-derive this a third time.** This item
      was filed asserting that "`/promote`'s docs say the workflow does not open
      the PR, but `promote-to-main.yml` now has a *Publish via PR to main* step
      that does". That assertion was then refuted against `dev-main` at
      `66b2e1b`, whose only publish steps are `Publish release branch (PR is
      opened with a user token)` (`:505`, pushes `release/$TAG`, prints the PR
      command to the job summary, and stops) and `Publish via direct push`
      (`:542`) — docs and workflow agree there. **Both claims were right about
      different files.** Nobody had noticed that the copy which *runs* is not the
      copy being *built*.
      **The consequence, which is the real finding: the version-binding gate
      added this cycle never ran for v6.5.0.** `bump-version.sh --check` occurs
      **0** times in the executed copy (`main@3d17c399`) and **2** times on
      `main` now, post-merge. The v6.5.0 stamps were correct only because the
      maintainer ran the bump by hand and verified it; the gate meant to enforce
      that was inert. Generalised: **any change to `promote-to-main.yml` is one
      release behind** — it cannot take effect until it has already shipped to
      `main`. That holds for every future fix to that workflow, and it is exactly
      the "a gate that does not actually run" class this release cycle was about.
      **What is open is the remedy; the options are recorded, not chosen:**
      1. **Verify after the merge, before trusting.** Treat the merge to `main`
         as the moment a workflow change becomes live, and add a post-merge check
         that the gates the maintainer believes are running are present in
         `main`'s copy.
      2. **Assert before dispatching.** Have `/promote` read `main`'s copy of
         `promote-to-main.yml` and refuse to dispatch unless it contains the
         gates this release expects — turning a silent one-release lag into a
         loud precondition failure.
      3. Some combination, or a dispatch that pins `ref` explicitly. Whoever
         picks this up decides; the point is that no remedy is in place today.
      **The close/reopen remediation is no longer needed from v6.6.0 onward** —
      recorded here rather than kept as a step. `origin/main` now carries the
      newer workflow: its publish step is `Publish release branch (PR is opened
      with a user token)` (`:505`), and no workflow on `main` calls
      `gh pr create` outside a job-summary `echo` (checked across all five:
      `branch-topology-guard.yml`, `leak-guard.yml`, `plugin-tests.yml`,
      `promote-to-main.yml`, `release-tag.yml`). The next dispatch therefore runs
      a copy that pushes the release branch and stops, and the PR is opened by a
      user token, which does emit `pull_request` events. The check that matters
      stays the same either way and should remain in the procedure: not "did
      anything fail" but "did any check **report**" — the
      `statusCheckRollup | length` must-be-nonzero probe already printed at
      `promote-to-main.yml:530-534`.
      Related: LOOM-0035 (consolidating the promote commands) will rewrite this
      procedure anyway — sequence accordingly.

- [x] LOOM-0012 — Reconcile or remove the `loom-orchestrator` manifest inventory counts `status:done`
      The manifest declares `commands.count: 8` / `skills.count: 10`; disk has
      **9 and 11** (the `graph` command and skill). Harmless today, but it proves
      the inventory blocks are **documentation, not an index** — nothing
      reconciles them, so they will drift again. Decide: drop the counts, or
      generate them.

### VISION threads awaiting work

Direction lives in `VISION.md`; these are the *work* those threads imply.

- [ ] LOOM-0008 — Settle graph-layer placement (VISION #4) `status:open`
      Now a **relocation** job rather than greenfield: the graph layer exists
      (`.logic-loom/graph/`, `/graph`), so the thread is about where it should
      live and what it belongs to, not whether to build it.

### Backlog schema — deferred, not rejected

Schema extensions raised by a cross-provider design review of the published
index contract, plus one identity-stamping item. Each is a **real** improvement
and none is needed today: there is no monorepo, no cross-project rollup consumer,
and no second index generation. Principle V (Progressive Enhancement) applies —
build a field when a consumer exists that cannot work without it, not when one
can be imagined. They are minted here so the analysis is recorded rather than
lost, and so the next person hits the reasoning instead of re-deriving it.

- [ ] LOOM-0018 — Add a monorepo-scoped `project.id` to the backlog index `status:open`
      `project.slug` identifies a **repository's** project. In a monorepo with
      several products under `apps/<name>/`, one slug cannot distinguish work in
      `apps/a` from work in `apps/b`, so an aggregator collecting from a monorepo
      gets one undifferentiated pile.
      Deferred because **this repo is not a monorepo and has no product workspace
      at all** — `web/` and `apps/` do not exist. A scoping field with exactly one
      possible value is a field that is never exercised and therefore never known
      to work. Revisit when a second product workspace lands.
      Note the interaction with LOOM-0005 / LOOM-0010: how projects are scoped is
      entangled with the unresolved marketplace/externalization direction.

- [ ] LOOM-0019 — Decide whether the backlog schema needs parent/child grouping `status:open`
      The index is a flat list plus `blocked_on` edges. It cannot express "these
      six items are one epic", so a consumer cannot roll a group up to a single
      line in a brief.
      Deferred because the current substitutes are adequate at this size:
      `source.heading` already groups items (`### Governance and constitution`),
      and `blocked_on` already carries the only dependency that changes what can
      be worked next. A parent/child relation is a **second** grouping axis that
      will immediately disagree with the heading axis, and reconciling two
      groupings is exactly the class of ceremony the grammar's *Deliberately
      excluded* section exists to prevent.
      Revisit only when a real consumer needs a rollup that headings cannot give.

- [ ] LOOM-0020 — Consider an append-only tombstone registry for burned ids `status:open`
      The grammar says ids are never reused, including after deletion, and
      suggests a `<!-- burned: LOOM-0031 -->` comment. Nothing enforces that: once
      a done item is deleted, its id vanishes from the file and the "next id =
      highest present + 1" rule can hand it out again.
      Deferred because **no id has been deleted yet** — every minted id is still
      in the file, so the failure mode has not occurred once. A registry is a
      second file that must be kept in sync with the first by hand, which is a new
      drift surface bought against a hypothetical.
      Cheaper interim mitigation if this ever bites: keep done items in the file
      rather than deleting them. Revisit the registry when the file is large
      enough that deletion becomes necessary.

- [ ] LOOM-0021 — Add a revision descriptor alongside `source_digest` `status:open`
      `source_digest` is only meaningful to a consumer that can **re-read the
      sources**. A remote aggregator holding just the JSON cannot recompute it, so
      for that consumer it is an opaque equal/not-equal token: no ordering, no
      provenance, no link to a commit. The review proposed replacing it with a
      revision descriptor.
      **Do not replace it — it does its actual job.** Local staleness detection is
      real and is the job it was built for, and that is now stated narrowly in the
      collector header rather than overclaimed. What is missing is the *separate*
      question "which revision is this", which needs a different field.
      Deferred because the only honest source of a revision is git, and the
      collector **runs no git by construction** — that boundary is asserted at
      runtime by a PATH shim in `tests/contract/test_backlog_index.sh`. Adding a
      revision field means either breaking that boundary or accepting a value
      passed in from outside, and neither should be decided without a consumer
      that needs it. Additive when it happens: a new optional field, no
      `schema_version` bump (see *Schema compatibility* in the grammar above).

- [ ] LOOM-0023 — Stamp this repo's own project identity without shipping it `status:open`
      `.logic-loom/config/project.conf` must ship as `__UNSET__` so a cloner
      never inherits our slug — `tests/contract/test_project_identity.sh`
      asserts exactly that, correctly. But LogicLoom's own dev tree therefore
      cannot stamp its identity either, so the tracked
      `artifacts/backlog-dashboard.html` renders as `__UNSET__ — Backlog` for
      the maintainer who looks at it daily.
      This repo is both the harness AND the template source, which is the same
      tension `VISION.md` already resolves: ours in dev, stubbed at promote.
      The fix is the established pattern, not new machinery — stamp
      `project_slug = logicloom` / `project_name = LogicLoom` /
      `id_prefix = LOOM` in dev, add a `history-scrub` rule (or a `stub:`
      manifest entry) that resets the three keys at promote, and retarget the
      six placeholder assertions to check the SANITIZED tree rather than the
      dev tree.
      `id_prefix = LOOM` is not a free choice: 22 ids are already minted with
      that prefix and the grammar declares the prefix immutable once minted.
      Recorded rather than done because retargeting a passing security-shaped
      assertion deserves its own change, not a drive-by during a merge.

### Environment promotion

- [ ] LOOM-0027 — Decide whether LogicLoom's own promotion line is declarable in `environments.conf` `status:open`
      This repository has a real promotion path — `dev-main` (integration) to
      `main` (the sanitized template line, published to cloners) — and now has a
      schema that could describe it. It declares nothing, because
      `tests/contract/test_environment_declaration.sh` § 2 correctly asserts the
      SHIPPED config has no uncommented `environment =` line: an active
      declaration would hand every cloner a topology they do not have.
      Same tension as LOOM-0023, one file over, and the same resolution is
      available: ours in dev, stubbed at promote. Worth deciding rather than
      leaving implicit — the alternative answer, that the harness's own release
      line is deliberately NOT an "environment" in this schema's sense, is also
      defensible and should be written down if chosen.

- [ ] LOOM-0028 — Teach the environment scaffolder a non-GitHub CI provider `status:open`
      `/scaffold-environments` only knows how to write a GitHub Actions
      workflow. On a repo whose detected CI provider is GitLab, CircleCI,
      Jenkins, or Azure Pipelines it SKIPS the `ci-guard` target with a typed
      reason and points at `environment-promotion-policy.md` § 3 to port by hand.
      That is deliberate — guessing at another provider's syntax would ship a
      gate that silently never fires. But it means the branch-boundary check,
      which the policy calls the one thing that turns a convention into a
      boundary, is unavailable to a non-GitHub project.
      Not obviously worth building: one template per provider, but each needs its
      own fail-closed idiom AND its own answer to "is the workflow evaluated from
      the base branch?" — GitHub's tamper-proof-by-placement property does NOT
      generalize, and a ported gate lacking it is weaker in a way the copy would
      not advertise. Decide whether to add providers or to state the limitation
      permanently.

- [ ] LOOM-0029 — Nothing regenerates environment scaffolding after a topology change `status:open`
      `/scaffold-environments` never overwrites — correct on first adoption, and
      a gap over time. Every artifact it writes encodes the topology detected at
      scaffold time: the CI guard's allowed-head regex, the checklist's branch
      table, the branch-base check's mode. Add a `staging` branch, or make the
      integration branch the repository default, and all three now describe an
      arrangement that no longer exists — while still passing, still looking
      authoritative, and still carrying the scaffolder's marker.
      Partial mitigation shipped: the generated `check-branch-base.sh` notices
      that `origin/HEAD` no longer matches the mode it was built for and says so.
      Nothing else does; the checklist and CI guard have no equivalent.
      Each obvious answer has a cost: a `--check` mode that fails closed on drift
      (a new gate to maintain, and it must not block anyone's CI); a
      `--regenerate` that rewrites marker-carrying files (breaks the
      never-overwrite guarantee that makes the tool safe to run); or a stamped
      topology fingerprint compared on each `--plan` (cheap, advisory, and only
      seen by someone already running the command).

- [ ] LOOM-0033 — Teach the backlog tooling to see VISION threads `status:open`
      Neither `lint-backlog.sh` nor `build-backlog-index.sh` reads `VISION.md`,
      so nothing links a thread to the items it spawned and nothing flags a
      thread that has never been audited. The VISION #9-#18 audit (LOOM-0016)
      had to be run by hand, and three threads turned out to be worse than
      recorded precisely because nobody was checking.
      A `vision:#N` tag on the item line plus a lint warning for an unaudited
      thread would close the remaining half of VISION thread #18. Deferred, not
      rejected: it adds a source the collector must parse for a benefit only one
      reader has so far, and `backlog.md` already draws the line that threads are
      DIRECTION and items are WORK — a tag must not blur it.

- [x] LOOM-0034 — Retire VISION thread #17 at the next Open Threads rewrite `status:done`
      Thread #17 (separate tool registration from exposure) is marked STALE as of
      2026-08-24: the runtime now ships deferred tools plus `ToolSearch`, which is
      registration without exposure, in the host. Building our own would be
      reimplementing what the harness deliberately rides on.
      What survives is small — whether swarm and team worker briefs should mention
      tool loading at all — and belongs in the domain-brief registry rather than
      carried as a strategic thread. Deferred because retiring a thread is a
      VISION edit and should happen when that section is next revised, not as a
      drive-by.

### Test suite defects

- [ ] LOOM-0038 — Fix three known-false assertions in the test suite — two are false greens, one silently drops 91 assertions `status:open`
      **Found during the v6.5.0 release (2026-08-25) and deliberately left**
      because a release PR was in flight and none of them is a product defect.
      All three are verified against `dev-main` at `66b2e1b`; do not re-derive.
      1. **An assertion that can never fail.**
         `tests/contract/test_environment_scaffolding.sh:182-183` — the
         "every skip states a reason" assertion ends in `|| true`, so its
         expression is unconditionally true. It has never tested anything.
      2. **A false green over six assertions.**
         The same file's `treehash()` (`:76-81`) runs `shasum -a 256` with
         `2>/dev/null` on the per-file hash and a bare `shasum` on the roll-up.
         On a host without `shasum` both sides yield the **empty string**, so the
         six "tree is byte-identical" assertions compare empty to empty and
         **pass**. A missing tool must fail the assertion, not empty it — assert
         the hash is non-empty first, and use the same `shasum`/`sha256sum`
         fallback the backlog collector already uses.
      3. **91 assertions count as zero.**
         `tests/run_all_tests.sh:38` parses a suite's summary with
         `grep -E "Results:|pass.*fail"`, but
         `test_environment_scaffolding.sh:411` prints
         `Total: N | Passed: N | Failed: N | Skipped: N`. No match, so the
         fallback at `:49-52` finds no `^ℹ pass` line either and the suite
         contributes **0** to the headline totals. Either the suite emits a
         `Results:` line or the aggregator learns this format — and the
         aggregator should treat a suite that emits **no parseable summary** as
         a failure rather than a zero.
      All three are instances of the same pattern — a check whose stated
      precondition is not its real precondition — which is worth reading before
      the next release, not just fixing here.

### Workflow packs

- [ ] LOOM-0039 — Direction: restore the MULTI-command SDD (`/specify`, `/plan`, `/tasks`) and retire the merged `/specification` `status:open`
      **A direction decision awaiting a plan — not a task ready to execute.**
      Do not start implementing off this item; it needs a plan first.
      **Stated by the maintainer on 2026-08-25:** the demand is for the *three*
      SDD commands, not the merged one. `/specification` is the thing that was
      intended to be removed — which inverts what the v5.1.0 consolidation
      (commit `7b6bb69`) actually did when it merged `/specify` + `/plan` +
      `/tasks` into `/specification` and deleted the three skills.
      **There is a starting point — this is not archaeology.** This cycle's
      repair work already recovered the three phases' logic inline into
      `plugins/sdd-specification/skills/unified-specification/SKILL.md` from
      `7b6bb69^`. That recovered material *is* the substance the three separate
      commands need; the work is splitting and re-surfacing it, not
      reconstructing it from a deleted commit.
      **What a plan has to settle**, at minimum: whether the three commands are
      independently invocable or a phased sequence with state between them; what
      happens to `/specification` (removed, or kept as an alias that runs all
      three); the plugin's identity, since `sdd-specification` is named for the
      merged command; and the routing surfaces that will go stale on the rename —
      which is the same class of debt LOOM-0036 is about.

---

## Provenance

**Minting history for BOTH streams lives here.** The 2026-08-24 split moved 16
items to `.logic-loom/memory/todos.md` and kept 13 here; every id, title and body
crossed verbatim and no id changed. The mapping below therefore names ids that
now live in either file — which is the point of one shared id space.

Items LOOM-0001 … LOOM-0016 were migrated on 2026-08-20 from
`.docs/reports/backlog-2026-08-13.md` § "Open after this pass" (items A–K), which
is now a historical record of that session. LOOM-0017 was minted here.

LOOM-0018 … LOOM-0021 were minted on 2026-08-20 from a cross-provider design
review of the published backlog-index contract. They are the review's
recommendations that were **deliberately not built** — see § *Backlog schema —
deferred, not rejected* for why each was held. The review's other findings were
implemented in the same pass (fatal duplicate/malformed handling in the
collector, the `external:` blocker form, the completed grammar, the schema
compatibility rules, and the `id_prefix` immutability statement). LOOM-0022 came
from the same review, was promoted into active work, and is `done` in `todos.md`.

Mapping from the original letters, for anyone reading the old report:

| Report item | Backlog ids | Now in |
|---|---|---|
| A — §3.2 sign-off | LOOM-0001 | todos |
| B — amendments not injected | LOOM-0002 | todos |
| C — hook noise reduction | LOOM-0003 | todos |
| D — archive marketplace repo | LOOM-0004 | todos |
| E — plugin externalization | LOOM-0005 | backlog |
| F — `/promote` collision | LOOM-0006 | backlog |
| G — VISION threads still open | LOOM-0007, LOOM-0008, LOOM-0009, LOOM-0010, LOOM-0016 | todos, except LOOM-0008 (backlog) |
| H — preflight anti-pattern | LOOM-0011 | todos |
| I — manifest drift | LOOM-0012 | backlog |
| J — constitutional-check residual | LOOM-0013 | backlog |
| K — dead code left deliberately | LOOM-0014, LOOM-0015 | todos |

LOOM-0028 and LOOM-0029 were minted on 2026-08-24 while building
`/scaffold-environments` for LOOM-0025 — the two things that work deliberately
did not do: non-GitHub CI providers, and regeneration after a topology change.

LOOM-0024 … LOOM-0027 were minted on 2026-08-22 while writing
`.docs/policies/environment-promotion-policy.md` — the portable
environment-promotion methodology. They are the work that policy surfaced and
deliberately did not do: the harness's own worktree-base guard, the opt-in
scaffolding a customer would adopt, the missing typed-phrase confirmation in
`/promote`, and whether this repository's own release line belongs in
`environments.conf`.

LOOM-0037 … LOOM-0039 were minted on 2026-08-25, immediately after the v6.5.0
release, from what that release day surfaced and deliberately did not fix: the
Actions-authored release PR that arrives with zero checks, three known-false
assertions in the test suite, and the maintainer's stated direction that the SDD
pack should go back to three commands. LOOM-0037's filing premise was checked
against the tree, and the check itself turned out to be looking at a different
file than the one that runs; the item now records the resolved answer — a
dispatched workflow executes `main`'s copy, so a fix to it lands one release
late — rather than the original question. The correction is in the item, not in
this section.

**Next id to mint: derived, not stored.** It is (highest id present in
`todos.md` or `backlog.md`) + 1 — today `LOOM-0030`, but do not trust that
sentence over the files. Compute it:

```
./.logic-loom/scripts/bash/lint-backlog.sh --next-id
```

A written-down counter in a two-file stream is wrong the first time someone
appends to the other file, and nothing tells them. The derivation cannot drift
because there is nothing to drift from.
