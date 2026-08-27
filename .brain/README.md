# `.brain/` — this project's knowledge layer

`.brain/` is this project's own vault: same structure, same raw/distilled
discipline, same one-fact-one-file rule, scoped to one project and
self-contained — no link to and no dependency on any external or personal
vault.

`.brain/` is the default home for a document that is **knowledge about this
project** rather than an operational file something reads. Nothing parses a page
here. No hook resolves a path here. It exists so a claim has one home and a
checkable origin.

This directory ships holding **only this README**. There is no `raw/`, `wiki/`,
`index/` or `memory/` directory yet, and that is deliberate: **a layer is created
the first time you have something to put in it** — the same treatment `web/` and
`artifacts/` already get.

---

## The boundary test

A file belongs **outside** `.brain/` when something *resolves* its exact path:

- a hook parses it (`features/<name>/plan.md` — `freeze-write-scope.sh` reads its
  `owns:`/`freeze:` blocks),
- a script or command reads it as data (`.logic-loom/config/*`,
  `.logic-loom/memory/{todos,backlog}.md`),
- a workflow pack requires it at that path (`specs/###-name/tasks.md`).

Everything else — research output, an exploration write-up, a review verdict, a
forensic report, a design record, a distilled concept — belongs here.

---

## The layers

```
.brain/
├── README.md          # this file
├── raw/               # captures. Immutable after capture; never edited in place
│   ├── research/      #   /research output
│   ├── exploration/   #   /swarm explore output
│   ├── reviews/       #   /review-team, /cross-check, /plan-review verdicts
│   ├── reports/       #   forensics, one-off investigations
│   ├── retro/         #   /retro raw output
│   └── archive/       #   superseded plans, historical designs
├── wiki/              # distilled and compounding; every page cites its raw sources
│   ├── concepts/
│   └── decisions/     #   ## Context / ## Decision / ## Why
├── memory/            # default backend (memory_backend = repo); absent under project (see below)
└── DISTILL-LOG.md     # append-only record of every /distill run
```

### `raw/` — evidence

A capture is **immutable after capture**. Append or supersede with a new file;
never rewrite one. A capture is evidence, and evidence you can edit isn't.

Frontmatter contract:

```yaml
---
type: capture
title: "..."
date: YYYY-MM-DD
source: "the command or act that produced it"
status: unprocessed        # unprocessed | processed
---
```

Once `status: processed`, the capture carries **exactly one** of:

```yaml
distilled-into: .brain/wiki/concepts/<page>.md    # or [[page-slug]]
discarded: "why this was not promoted"
```

**Captures are never deleted.** `.brain/raw` is stripped at template release, so
deleting a capture after distilling it would leave the only surviving copy of a
research output as a paragraph in a wiki page. The cost of not deleting is
stated plainly: `raw/` grows without bound, and `status` becomes the only thing
separating pending from done — which is exactly why check 1 of the integrity
gate exists.

### `wiki/` — distillation

```yaml
---
type: concept            # or: decision
title: "..."
date-updated: YYYY-MM-DD
sources:
  - .brain/raw/research/<file>.md
---
```

`sources:` must be non-empty. A page without a citable origin is an assertion.

**One fact, one file.** A fact lives in exactly one page; everything else links
to it. This is the rule that makes the layer worth having, and the one nothing
can enforce. Search `wiki/` before creating a page.

Use `[[wikilinks]]` and relative markdown links — the project graph builder
harvests both into `links-to` edges, so linking buys the graph for free.

### `index/` — pointer entries

A pointer entry is a summary of an **operational primary** that cannot move.
It carries `primary:`, `primary-sha:` (the git blob hash at distillation time),
`why-outside:`, `covers:` and `status:`, plus two sections that are the whole
point: **`## Open the primary when`** and **`## Do not open it for`**.

A pointer entry is authored and restamped **by a human**, never by a command.
A restamp is the act of having read the diff.

### `memory/` — the default backend

`.brain/memory/` is where durable cross-session memory (`/retro` action-items)
lives by default. The memory backend has two options:

- `repo` -> `<repo>/.brain/memory/` — in-tree, versioned, stripped at template
  release. **This is the shipped default.**
- `project` -> `$HOME/.claude/projects/<slug>/memory/` — per-machine, outside
  the repo, invisible to anything that is not Claude Code.

A third option, pointing at an external absolute path, was deleted outright:
it inverted the relationship this file describes throughout — `.brain/` is
self-contained, and an external store reads it; the project never reaches out
to someone else's directory.

Resolution is a pure function of `(env, conf)`. With no explicit setting the
resolver returns `repo`, always. It deliberately does **not** probe the
filesystem to pick a default: the `project` slug is derived from the checkout
path, so a probe would resolve differently in a worktree than in the main
checkout of the same project — two stores, neither aware of the other, which is
the exact defect one resolver exists to prevent. It would also turn a reviewable
one-line config diff into a filesystem side effect with no diff anywhere.

Migration is handled where a human can see it instead. When memory resolves to
`repo` while the previous location `$HOME/.claude/projects/<slug>/memory/` still
holds files, `check-brain-signals.sh` says so in the preflight advisory — the
file count and both paths. It never blocks, and it never moves anyone's files.
It goes quiet when you move them or set `memory_backend = project`. Detection,
not resolution.

So `.brain/memory/` exists by default for a new project, not only under one
setting. It is absent only when the project chose `project` — and it is stripped
at template release either way.

---

## `DISTILL-LOG.md`

Append-only, newest entry first, **one dated entry per `/distill` run including
a zero-op run**. A one-line healthy entry is what makes a later break visible by
contrast, and log age — not queue depth — is what tells you the pass is alive.

```markdown
## YYYY-MM-DD

- run: /distill
- scanned: N captures under .brain/raw/ (M unprocessed)
- promoted: <raw path> -> <wiki path>
- extended: <raw path> -> <wiki path>
- discarded: <raw path> — <reason>
- contradiction: "<side A>" vs "<side B>" — both pages untouched, human decides
- result: zero-op
```

`run:`, `scanned:` and `result:` are mandatory. A contradiction is **recorded
here and nowhere else** — there is no separate contradiction store, and nothing
auto-merges.

---

## What checks what

| Signal | Question | Mechanism | Strength |
|---|---|---|---|
| Record integrity | Does the record hold together? | `.logic-loom/scripts/bash/check-brain-record.sh` (CI) | **FAIL-CLOSED** |
| Liveness | Did the pass run recently? | preflight advisory | never blocks |
| Load | Is there a backlog? | preflight advisory | never blocks |

The gate is vacuous — and green — on a `.brain/` holding only this README. It is
live from day one rather than switched on later by a step nobody remembers.

Only record integrity gates, because a fail-closed gate must assert something
the change in front of it caused. "You have not distilled in 40 days" is not
that.

**No script may ever parse a `.brain/wiki/` page's body.** The gate reads
frontmatter and file existence only. The moment a gate depends on prose
structure, the contract stops being portable.

---

## Getting started

1. Create a layer when you have a file for it: `mkdir -p .brain/raw/research`.
2. Drop the capture in with the frontmatter above and `status: unprocessed`.
3. Run `/distill` when you have a few. It never runs git — it leaves its writes
   in the working tree and you commit them through the normal approval path.
4. `bash .logic-loom/scripts/bash/check-brain-record.sh` says whether the record
   still holds.

Running `/distill` on a schedule is **your** act, not the harness's:
`.logic-loom/templates/distill-schedule-prompt.md` is the prompt to install
yourself. Scheduled tasks live in your own tree, and the harness never writes
there.

---

## In this repo (dev line)

Capture is wired for two commands. `/cross-check` writes its report to
`.brain/raw/reviews/YYYYMMDD-HHMMSS-<scope-slug>/cross-check-report.md` by
default, with capture frontmatter — previously `.docs/cross-check/...`.
`.docs/cross-check/` was never gitignored, so this changes nothing about
tracking.

`/research` writes its final report as a single self-contained capture at
`.brain/raw/research/YYYYMMDD-HHMMSS-<topic-slug>.md`, also with capture
frontmatter. Its working intermediates — `jury.json`, per-researcher reports,
vote JSONs, `claims.json` — stay in the gitignored `.docs/research/<id>-<slug>/`.
That split follows the repo's existing rule, stated in `.gitignore`: track only
what a human opens. The cost, stated plainly: the tribunal vote JSONs and
per-researcher drafts are per-machine and are not on any committed line;
commit them deliberately if you want them.

`raw/` fills as those commands run. The `wiki/` layer is still empty — it will
be created the first time `/distill` has something to promote. Until then,
`/distill` runs zero-op and logs that it did, which is the point: the log
entry is the liveness signal, and a zero-op run is a healthy one.
