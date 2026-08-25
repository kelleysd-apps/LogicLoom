# Todos — work being addressed NOW

**Level 0 of the Todo Architecture SSOT, active half.** Authoritative list for
work that is **not a feature** — governance, hooks, tests, CI, release tooling,
policy and documentation — and that is **being worked, is next up, or is waiting
only on a decision that has already been asked for**.

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
verbatim: same `- [ ] <PREFIX>-NNNN — Title `` `status:…` `` line, same tag
rules, same `## Items` scope rule, same fenced-block rule, same closed status
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
its own sequence, a `blocked_on:` reference would have two answers and would
mean nothing.

**Where the counter lives: nowhere.** It is **derived**, not stored:

> **next id = (highest id present in `todos.md` or `backlog.md`) + 1**

A stored counter would have to live in one file and be honoured by the other,
and the moment someone appends an item to the file that does *not* hold it, the
counter is wrong and nothing says so. Deriving it means the two files cannot
disagree, because there is nothing to disagree about. To get the value:

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

---

## Items

<!--
Your active items go here — one per line in the grammar `backlog.md` specifies,
under whatever `### ` sub-headings suit your project (file order is the
priority, so put what matters first). Mint the first id as <PREFIX>-0001 using
the `id_prefix` from .logic-loom/config/project.conf, or run
`./.logic-loom/scripts/bash/lint-backlog.sh --next-id` once either file has an
item in it.

This section ships EMPTY on purpose: the two-stream shape and the grammar are
machinery you inherit, the items are yours. Delete this comment once you add
your first item.
-->
