# LogicLoom Backlog — cross-cutting / harness-maintenance work

**Level 0 of the Todo Architecture SSOT.** Authoritative list for work that is
**not a feature**: governance, hooks, tests, CI, release tooling, policy and
documentation — anything that spans the harness rather than living inside one
`features/<name>/` or `specs/###-name/`.

Feature work does **not** belong here. It belongs in `features/<name>/plan.md`
(swarm pack) or `specs/###-name/tasks.md` (SDD pack). Strategic direction does
not belong here either — that is `VISION.md` § Open Threads. **VISION threads are
*direction*; backlog items are *work*.** A thread may spawn one or more items;
an item never supersedes a thread.

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

### Ship / strip

This file **ships** as machinery — a cloner should inherit the grammar and an
empty item list, not this repo's maintenance items. Its **content is
harness-dev-specific**, so it needs a `stub:` entry in
`.logic-loom/scripts/bash/template-strip-manifest.txt`, exactly as `VISION.md`
has. That wiring is itself tracked below as LOOM-0017.

---

## Items

### Governance and constitution

- [ ] LOOM-0001 — Maintainer sign-off on constitution v3.3.0 + the amendments extension point `status:in_progress`
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

- [ ] LOOM-0002 — Inject `amendments.md` into the governance preflight `status:blocked` `blocked_on:LOOM-0001`
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

- [ ] LOOM-0003 — Answer the hook noise-reduction proposal `status:blocked` `blocked_on:external:maintainer answer on the proposal below`
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

- [ ] LOOM-0011 — Fix the `grep -c … || echo 0` two-line-value bug at `governance-preflight.sh:160` `status:open`
      The exact idiom the new `.docs/policies/shell-idiom-policy.md` warns
      against, still live in a shipped hook. **Deliberately not fixed during the
      2026-08-13 pass**: it is protected governance surface and needs its own
      approved change with its own approval gate.
      *(protected)*

- [ ] LOOM-0013 — Decide whether Principles I and III should report SKIP for a harness-shaped repo `status:open`
      `constitutional-check.sh` still reports findings for Principles **I
      (Library-First)** and **III (Contract-First)** — no `libs/`, no contract
      files. These findings are *real for a shell/markdown harness*, and they are
      **not path bugs** (those were fixed in `26bac08`). Open question: should
      these principles report SKIP when the repo has no product workspace, rather
      than a permanent finding a reader learns to ignore? Deciding "no" is a valid
      outcome — but it should be decided, not left ambient.

### Release, distribution and externalization

- [ ] LOOM-0004 — Archive `kelleysd-apps/sdd-plugins-marketplace` `status:blocked` `blocked_on:external:maintainer archiving that repository (outside this repo)`
      Separate repository, **maintainer action** — not something this branch or
      any in-repo change can do. Private, not archived, last pushed 2026-02-06,
      containing the pre-rename `sdd-*` generation including plugins deleted
      months ago. **Zero in-repo references remain** (cleared in `d8716d1`), so
      archiving is now zero-risk. Blocked on maintainer action outside the repo.

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

- [ ] LOOM-0012 — Reconcile or remove the `loom-orchestrator` manifest inventory counts `status:open`
      The manifest declares `commands.count: 8` / `skills.count: 10`; disk has
      **9 and 11** (the `graph` command and skill). Harmless today, but it proves
      the inventory blocks are **documentation, not an index** — nothing
      reconciles them, so they will drift again. Decide: drop the counts, or
      generate them.

- [ ] LOOM-0017 — Add a `stub:` entry for this backlog file to the strip manifest `status:open`
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

- [ ] LOOM-0007 — Make `.gitignore` patterns actually match the local-override filenames (VISION #2) `status:open`
      `.local/` and `*.local` still do **not** match `settings.local.json` or
      `CLAUDE.local.md` — the two files the patterns were added to cover. A user's
      local overrides are therefore tracked unless they notice.

- [ ] LOOM-0008 — Settle graph-layer placement (VISION #4) `status:open`
      Now a **relocation** job rather than greenfield: the graph layer exists
      (`.logic-loom/graph/`, `/graph`), so the thread is about where it should
      live and what it belongs to, not whether to build it.

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

- [ ] LOOM-0016 — Audit VISION threads #9–#18 `status:open`
      Threads #1–#8 were audited or resolved during the 2026-08-13 pass (#1 closed,
      #8 annotated, #2–#6 audited, #7 left open for LOOM-0002). **#9–#18 are
      untouched** — never read against current state, so their claims are of
      unknown accuracy. Audit each: still true, already fixed, or superseded.

### Dead code and test hygiene

- [ ] LOOM-0014 — Remove the dead `mcp-servers/` loop at `setup.sh:206` `status:open`
      Loops over a nonexistent `mcp-servers/` directory — dead since the
      marketplace MCP removal. **Left in place deliberately** during the
      2026-08-13 governance pass rather than touched mid-pass; it needs its own
      change.

- [ ] LOOM-0015 — Give `logging.sh` an override for `LOG_DIR` `status:open`
      `logging.sh` hardcodes `LOG_DIR` with no override, so **every test suite
      appends to the operations log**. A test-isolation gap, not a correctness
      bug — but it means the operations log is polluted by test runs and cannot be
      read as a record of real operations.

### Backlog schema — deferred, not rejected

Four schema extensions raised by a cross-provider design review of the published
index contract. Each is a **real** improvement and none is needed today: there is
no monorepo, no cross-project rollup consumer, and no second index generation.
Principle V (Progressive Enhancement) applies — build a field when a consumer
exists that cannot work without it, not when one can be imagined. They are minted
here so the analysis is recorded rather than lost, and so the next person hits the
reasoning instead of re-deriving it.

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

- [ ] LOOM-0024 — Base development worktrees on `dev-main` explicitly, never on the default branch `status:open`
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

- [ ] LOOM-0025 — Ship opt-in environment-promotion scaffolding, adoptable into an EXISTING project `status:open`
      `.docs/policies/environment-promotion-policy.md` writes the methodology
      down; nothing stands it up. The shippable capability is scaffolding a user
      who adopts LogicLoom can run to get the shape into their own project:
      the environment declarations, a branch-boundary CI guard adapted to their
      topology, a rehearsal seed/teardown skeleton with the fail-closed allowlist
      wired as an abort, and the escalating-confirm ladder in their promotion
      script.
      Two constraints that should be settled before any of it is built. (1) It
      must be OPT-IN scaffolding, not hard rails — the harness ships no
      deployment machinery today and Principle V says do not ship a
      three-environment pipeline before one environment is proven in use. (2) It
      must adopt into an EXISTING project, not only a greenfield one — a
      repository that already has branches, workflows, and a deployed
      environment is the normal case, so the command has to detect and merge
      rather than assume it is writing onto a blank tree.
      The command name is not free: `/promote` is taken by the maintainer
      release driver and is stripped from customer copies by exact path — the
      same collision already recorded as LOOM-0006.

- [ ] LOOM-0026 — Give `/promote` a typed-exact-phrase confirmation at the release step `status:open`
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

---

## Provenance

Items LOOM-0001 … LOOM-0016 were migrated on 2026-08-20 from
`.docs/reports/backlog-2026-08-13.md` § "Open after this pass" (items A–K), which
is now a historical record of that session. LOOM-0017 was minted here.

LOOM-0018 … LOOM-0021 were minted on 2026-08-20 from a cross-provider design
review of the published backlog-index contract. They are the review's
recommendations that were **deliberately not built** — see § *Backlog schema —
deferred, not rejected* for why each was held. The review's other findings were
implemented in the same pass (fatal duplicate/malformed handling in the
collector, the `external:` blocker form, the completed grammar, the schema
compatibility rules, and the `id_prefix` immutability statement).

Mapping from the original letters, for anyone reading the old report:

| Report item | Backlog ids |
|---|---|
| A — §3.2 sign-off | LOOM-0001 |
| B — amendments not injected | LOOM-0002 |
| C — hook noise reduction | LOOM-0003 |
| D — archive marketplace repo | LOOM-0004 |
| E — plugin externalization | LOOM-0005 |
| F — `/promote` collision | LOOM-0006 |
| G — VISION threads still open | LOOM-0007, LOOM-0008, LOOM-0009, LOOM-0010, LOOM-0016 |
| H — preflight anti-pattern | LOOM-0011 |
| I — manifest drift | LOOM-0012 |
| J — constitutional-check residual | LOOM-0013 |
| K — dead code left deliberately | LOOM-0014, LOOM-0015 |

LOOM-0024 … LOOM-0027 were minted on 2026-08-22 while writing
`.docs/policies/environment-promotion-policy.md` — the portable
environment-promotion methodology. They are the work that policy surfaced and
deliberately did not do: the harness's own worktree-base guard, the opt-in
scaffolding a customer would adopt, the missing typed-phrase confirmation in
`/promote`, and whether this repository's own release line belongs in
`environments.conf`.

**Next id to mint: LOOM-0028.**
