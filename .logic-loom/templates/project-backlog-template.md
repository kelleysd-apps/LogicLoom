# Backlog — cross-cutting / harness-maintenance work

**Level 0 of the Todo Architecture SSOT.** Authoritative list for work that is
**not a feature**: governance, hooks, tests, CI, release tooling, policy and
documentation — anything that spans the project rather than living inside one
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
real items. The `ACME-0042` through `ACME-0046` lines below are **examples inside
fences and are not minted ids**.

### The line

```
- [ ] ACME-0042 — Short imperative title `status:open`
```

With an optional dependency tag and an optional indented body:

```
- [ ] ACME-0043 — Wire the collector into CI `status:blocked` `blocked_on:ACME-0042`
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

Regex for the item line (POSIX ERE), with `<PREFIX>` substituted:

```
^- \[[ x]\] (<PREFIX>-[0-9]{4,}) — (.+?) `status:(open|in_progress|blocked|done)`
```

The regex is a summary, not the specification — rules 5–7 above are not
expressible in it.

### Fields

| Field | Required | Form | Notes |
|---|---|---|---|
| checkbox | yes | `- [ ]` or `- [x]` | Human/GitHub affordance only. **Not** the parsed status. |
| id | yes | `<PREFIX>-` + at least 4 digits | Immutable once minted. Never reused. Unique across the whole index. |
| separator | yes | ` — ` (space, em dash, space) | Separates id from title. First occurrence wins. |
| title | yes | one line, free text | No newline, no tab. Ends at the `status:` tag. |
| `status:` | yes | `open`\|`in_progress`\|`blocked`\|`done` | Closed vocabulary. Backtick-wrapped. **First tag on the line.** |
| `blocked_on:` | no | comma-separated entries | Each entry is an **id** or `external:<reason>`. See *Blocked on*. |
| body | no | indented lines under the item | Human detail. **Not parsed, not indexed.** |

### Ids

- **`<PREFIX>` is your project's id prefix, not a fixed string** (`ACME` is
  only this template's illustration). Declare it once as `id_prefix` in
  `.logic-loom/config/project.conf` (uppercase, 2–6 chars, `[A-Z][A-Z0-9]{1,5}`)
  — `/initialize-project` stamps it, or set it by hand and validate with
  `./.logic-loom/scripts/bash/validate-project-identity.sh`. The prefix exists so
  two projects' backlogs stay unambiguous side by side.
- Format `<PREFIX>-NNNN`, zero-padded to at least four digits. Past `9999`,
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
  done item, its id stays burned — leave a `<!-- burned: ACME-0031 -->` comment
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
| id reference | `ACME-0002` | Blocked by **another item in this index**. Must resolve to a real id. |
| external blocker | `external:<reason>` | Blocked by something **outside this index** — free text. |

```
- [ ] ACME-0044 — Depends on another item `status:blocked` `blocked_on:ACME-0042`
- [ ] ACME-0045 — Depends on a person `status:blocked` `blocked_on:external:maintainer decision on the proposal`
- [ ] ACME-0046 — Both at once `status:blocked` `blocked_on:ACME-0042,external:upstream release`
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

- **owner** — a small-team backlog does not need an owner field; it is noise, and
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

---

## Items

<!--
Your items go here — one per line in the grammar above, newest ideas appended
under whatever `### ` sub-headings suit your project (file order is the
priority, so put what matters first). Mint the first id as <PREFIX>-0001 using
the `id_prefix` from .logic-loom/config/project.conf.

This section ships EMPTY on purpose: the grammar above is machinery you inherit,
the items are yours. Delete this comment once you add your first item.
-->
