# Adopter parity + a live backlog dashboard — design specification

**Status:** design only. No repo file changed by this document, no git mutation run.
**Repo:** `/Users/bkelley/kelleysd-apps/LogicLoom` @ `dev-main`, v6.6.2.
**Backlog:** LOOM-0048 (`.brain/`), LOOM-0049 (dashboard), LOOM-0050 (CI templates), LOOM-0051 (`/initialize-project` parity).
**Evidence base:** a clean install of `logicloom@6.6.1` into `kori-beta` (393 files, 0 skipped, 0 failed), audited against the `v6.6.2` tag and `payload-manifest.txt`.

---

## The governing principle

> Every architectural piece of LogicLoom reaches an adopter as **sanitized
> structure**, or as a **script or guide that builds it**, wired into onboarding.
> Our data never travels; the structure that makes the harness strong always does.

`features/` and `specs/` already implement this exactly — `.gitkeep` + `README.md`
ship, content is excluded. **This document is about applying that existing pattern
to the three places it was not applied.** It invents no new distribution mechanism.

---

## 1. The root cause, stated once

The payload is assembled from the **tag's tree**, which the strip manifest has
already sanitized. That is why the payload manifest needs no `stub:` verb: a path
the strip manifest stubs arrives at the adopter already stubbed and safe.

The consequence, and the rule to apply to every future exclusion:

> **An `exclude:` on a path the strip manifest STUBS throws away safe structure.**

Audit of all four `stub:` entries:

| Stubbed path | Safe in tag | Payload | Adopter | Verdict |
|---|---|---|---|---|
| `.logic-loom/memory/todos.md` | yes | inherits | present | correct |
| `.logic-loom/memory/backlog.md` | yes | inherits | present | correct |
| `.brain/README.md` | yes | `exclude: .brain` | **missing** | **defect** |
| `VISION.md` | yes | `exclude: VISION.md` | missing | **correct — deliberate**, `/initialize-project` §1.5 offers it from a shipped template |

Verified: kori-beta's `todos.md` and `backlog.md` contain **0 LOOM items and 0
references to our work**. The inheritance path is sound; only the explicit
re-exclusion is wrong.

A wider sweep found 27 payload exclusions that survive sanitization. All but the
three below are correctly the adopter's own file (`package.json`, `README.md`,
`.editorconfig`), our record (`.docs/history`, `.docs/reviews`, `CHANGELOG.md`),
or maintainer-only (`.github`, `packaging`, `tests`, `adopt-smoke-test.md`).

---

## 2. `.brain/` — a gap and a broken reference (LOOM-0048)

A template clone gets `.brain/README.md`. An npm adopter gets nothing.

This is worse than an omission: `initialize-project.md:200` instructs the agent
that "`.brain/` keeps just its `README.md`" — a file the npm path never installs.
The command reasons about a file that is not there.

**Change:** add `include: .brain/README.md` AND delete `exclude: .brain`.

**Both are required, and an earlier draft of this document said only the second
was — that was wrong and would have shipped nothing.** The payload copier
selects a path only if an `include:` matches it (`lib/fsops.js`; a `rename:`
source also counts). No include covered `.brain`, so removing the exclusion
alone leaves the path unselected. Verified by running the real assembly script
against the v6.6.2 tag: before, 276 files and no `.brain`; after, 277 files and
`.brain/README.md`.

The include mirrors `features/`/`specs/` directly below it. The tag carries
exactly one `.brain` path (`README.md`, stubbed), so the adopter receives the
contract document and no content — confirmed byte-identical to
`brain-readme-template.md`, with zero references to our work. `.brain/raw`, `wiki`, `index`, `memory` and `DISTILL-LOG.md` are already
strip-manifest entries and are absent from the tag — they cannot leak.

**Verify by:** `git ls-tree -r --name-only <tag> | grep '^\.brain/'` returns
`README.md` and nothing else, before and after.

---

## 3. `artifacts/` and the dashboard (LOOM-0049)

### 3.1 What already works

`build-backlog-index.sh` and `build-backlog-dashboard.sh` **ship** and have
**zero references to our repository** — they are already portable. Running them
in kori-beta produced a working 11.8 KB dashboard from that project's own
`todos.md` and `backlog.md`.

The capability is present. What is missing is the directory, the convention, the
gate, and any instruction to run it.

### 3.2 Structure

Apply the `features/`/`specs/` pattern verbatim:

```
include: artifacts/.gitkeep
include: artifacts/README.md
exclude: artifacts/backlog-dashboard.html
```

`artifacts/README.md` is the convention document: what belongs in `artifacts/`
(standalone deliverables — vision, research, forensics, docs; **never a plan**),
and that a generated deliverable belongs there too and is tracked.

### 3.3 Ship the freshness gate

`exclude: .logic-loom/scripts/bash/check-generated-freshness.sh` is removed. Its
recorded reason —

> "it regenerates `artifacts/backlog-dashboard.html` — an artifact the payload
> does not ship and the adopter has no source for. A gate that can only fail is
> worse than no gate."

— was true when written and is now false. The adopter has `todos.md`,
`backlog.md`, and both generators.

### 3.4 The live-data design — fetch at VIEW time

**Decision: GitHub issues are RENDERED, never imported into `todos.md`.**
Importing puts two writers on one id space and guarantees drift. The markdown
stays the SSOT for LOOM items; GitHub stays the SSOT for issues; the dashboard is
a view over both.

The apparent conflict — a tracked, fail-closed-gated artifact cannot contain
live data without reddening the gate on unrelated commits — dissolves by moving
the fetch out of build time:

| | Build time | View time |
|---|---|---|
| **Source** | `todos.md`, `backlog.md` | `api.github.com/repos/{owner}/{repo}/issues` |
| **Output** | deterministic HTML | DOM injected on open |
| **Gate** | meaningful — pure function of the markdown | untouched |

The generated bytes remain a function of the two markdown files alone, so
`check-generated-freshness.sh` keeps its meaning and never fails because someone
commented on an issue.

**Precisely, and this correction matters because an earlier draft of this document
got it wrong:** the generator is NOT byte-deterministic. It carries a
`generated_at` ISO-8601 stamp from the index, so two runs a second apart differ —
verified. The gate already designs that out: it normalises every ISO-8601 UTC
timestamp to a fixed placeholder **on both sides** before diffing (option (c) in
its own header), and additionally honours `SOURCE_DATE_EPOCH` so a debugging
human gets reproducible scratch files. So the invariant to protect is not byte
identity; it is:

> the generated HTML is a function of `todos.md` and `backlog.md` **modulo the
> existing `generated_at` normalisation**, and of nothing else.

Issue data entering the file at build time would break that invariant. The
`generated_at` stamp does not.

**Feasibility verified, not assumed:**

- `api.github.com` responds with `access-control-allow-origin: *`, so the fetch
  works from `file://` with no server and no proxy.
- Unauthenticated: 60 requests/hour per IP. With an optional token held in
  `localStorage`: 5,000/hour, and private repositories become readable.
- `{owner}/{repo}` is derived from `git remote` **at build time** and baked into
  the HTML, so the dashboard stays repo-neutral and works in any adopter's repo.

**Degradation is visible, never silent.** Each of these renders a stated reason
in the issues panel rather than an empty list: no git remote, no network, rate
limit exhausted, private repository with no token, malformed response.

### 3.5 Keeping the markdown half current

Regenerate on `SessionStart` — a hook point already in
`merge/settings-hooks-fragment.json`.

Regeneration depends only on the sources — plus the `generated_at` stamp, which
means an unchanged backlog still produces a one-line diff on every session start.
That is unacceptable for a hook: it would dirty the tree constantly.

So the SessionStart step must be `SOURCE_DATE_EPOCH`-pinned (the generator
already honours it) or must skip the write when the normalised content is
unchanged. With either, an unchanged backlog produces no diff and a changed one
produces a real update. The freshness gate remains the backstop for anything
committed stale.

**Ordering constraint:** the regenerate step must not fail the session. It writes
one file and exits 0 regardless, in the same spirit as `check-brain-signals.sh`.

---

## 4. CI methodology as templates (LOOM-0050)

`exclude: .github` **stays**. Those workflows are our release loop, they name our
topology, and we must never write into an adopter's CI unasked.

But the current consequence is that the methodology is never offered:
`initialize-project.md` step 4f skips CI entirely for an adopted repo.

**Change:** ship the workflows as templates under
`.logic-loom/templates/workflows/`, and turn step 4f from *"skip entirely"* into
*"offer, adapt, never install unprompted"* — the shape step 1.5 already uses for
`VISION.md`.

The adopter can install them as-is, adapt them, or decline. Their `.github/`
remains theirs in every case.

---

## 5. `/initialize-project` reaches parity (LOOM-0051)

The goal: `npx logicloom init` then `/initialize-project` leaves an adopter with
the same structure and systems we have, unless they choose otherwise.

Current steps: PRD · VISION.md · `project.conf` · gate posture · memory+distill ·
constitution · agents · MCP/keys/upstream · remove-maintainer-CI · validate.

Three steps are added, each following the established **offer, never create
unprompted** shape:

| New step | Asks | Default if declined |
|---|---|---|
| `.brain/` scaffold | create `raw/`, `wiki/`, `index/`, `memory/`? | README only — the current documented state |
| `artifacts/` + dashboard | build the first dashboard now? | directory and README only |
| CI methodology | install the workflow templates? | nothing written to `.github/` |

**This lands last.** It is the single place these questions surface, and it
depends on all three preceding items.

---

## 6. What this design does NOT do

- **Does not import issues into markdown.** Rendering only. One writer per source.
- **Does not write to `.github/`.** Templates and an offer; never an install.
- **Does not ship our content.** `.brain/` ships one stubbed README; `artifacts/`
  ships a `.gitkeep` and a convention doc. Both are the `features/`/`specs/`
  pattern, not a new one.
- **Does not change `VISION.md`.** Its exclusion is deliberate and correctly
  handled by onboarding; an earlier draft of this audit called it a gap and was
  wrong.
- **Does not add a server, a daemon, or a build step.** The dashboard is a static
  file that fetches on open.

---

## 7. Risks, and what would falsify the design

| Risk | Mitigation | Residual |
|---|---|---|
| Rate limit (60/hr) exhausted by refreshes | optional token → 5,000/hr | a heavy anonymous user sees a stated limit message |
| Private repo, no token | visible "issues unavailable — add a token" | issues panel empty by design |
| No git remote | build-time detection; markdown-only dashboard | no issues panel at all |
| `SessionStart` regeneration dirties the tree | pure function of sources; unchanged input → identical bytes | a genuinely changed backlog produces a real diff, which is correct |
| GitHub changes the CORS policy | the fetch fails and the panel says so | issues panel stops working; markdown half unaffected |

**The claim most likely to be wrong:** that view-time fetching keeps the gate
honest. It rests on the generated HTML depending on nothing but the two markdown
files (modulo the `generated_at` normalisation the gate already applies). If a
future change bakes issue data into the file at build time, the gate starts
failing on unrelated commits and the whole reconciliation collapses.

The contract test must therefore assert **source-dependence, not byte-identity**.
An earlier draft of this document proposed asserting byte-identical output across
two runs; that test would fail today, against a generator that is working
correctly, because of the `generated_at` stamp. The test to write instead:

1. regenerate with the network disabled and assert success — proving the build
   path makes no network call, so no issue data can enter it;
2. regenerate twice with `SOURCE_DATE_EPOCH` pinned and assert byte-identity —
   proving the clock is the only per-run variable;
3. assert the emitted HTML contains no issue titles or numbers, only the fetch
   scaffolding.

Together those pin the invariant the gate depends on. Byte-identity alone pins
the wrong thing.
