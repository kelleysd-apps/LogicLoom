---
name: distillation-pass
version: 0.1.0
description: |
  Promotes .brain/raw/ captures into .brain/wiki/ pages and appends one dated
  entry to .brain/DISTILL-LOG.md on every run, including a zero-op run. Ported
  from a scheduled distillation pass, stripped of the two things that do not
  belong in a repo: a runner outside the harness's control, and unattended git.
  What survives is the contract — capture frontmatter, wiki page shape, four
  promotion outcomes, log grammar — because the contract is portable and the
  invoker is not. The normative statement of that contract is .brain/README.md,
  which ships; read it first.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
triggers: ["distill", "distillation", "promote captures", "brain wiki"]
category: orchestration
constitutional_principles: [IV, VI, VII]
---

# Distillation Pass Skill

## Overview

`/distill` promotes `.brain/raw/` captures — the `status: unprocessed`
instance documents that `/research`, `/swarm explore`, `/review-team`, and
`/cross-check` already redirect into `.brain/raw/<layer>/` — into durable
`.brain/wiki/` pages, and appends one dated entry to `.brain/DISTILL-LOG.md`
on every run, including a run that promotes nothing.

This is a **prompt, not an engine**: no script parses a capture or writes a
wiki page. The judgment — extend, create, discard, or flag a contradiction —
is exercised by whoever runs this skill, every time, in-context. That is
deliberate: it is what keeps the contract below extractable into a future
product with no code to port (see "Designed for extraction").

There is no shipped scheduler. `~/.claude/scheduled-tasks/` is the user's
tree; CLAUDE.md's Harness ↔ user boundary forbids the harness writing there.
The harness ships an optional prompt template at
`.logic-loom/templates/distill-schedule-prompt.md` — the user installs it
themselves via `/schedule` or their own cron. `/distill` works identically
whether invoked by hand or by that installed prompt.

## When to Use

- Whenever `.brain/raw/` holds one or more `status: unprocessed` captures.
- On a cadence the user chooses (by hand, or via a self-installed scheduled
  task) — there is no cross-repo scheduler and none is coming from this
  harness.
- Never as a step inside `/retro` or any other command, for three reasons.
  **Coverage:** `/retro` is per-feature and terminal, while captures come from
  `/research`, `/swarm explore`, `/review-team` and `/cross-check` — and three
  of those are routinely run with no feature at all, so those captures would
  never be reached. **Cadence:** a pass that fires once per finished feature is
  not a cadence, it is an occasion. **It destroys the health signal:** if
  `/retro` were the only trigger, "no distillation in 60 days" and "no feature
  finished in 60 days" become the same reading, and the second is normal — the
  signal would stop meaning anything, which is worse than not having one.

  (`/retro` writing a `.brain/wiki/decisions/` page of its own is a separate,
  narrower idea and is **not built**. Nothing in this repo does it today.)

## The Contract

This is the part that must not drift — CI enforces most of it via
`.logic-loom/scripts/bash/check-brain-record.sh`, and a future product will
read the same frontmatter with none of this repo's code.

### Capture frontmatter

Files under `.brain/raw/<layer>/*.md`. Layers: `research`, `exploration`,
`reviews`, `reports`, `retro`, `archive`.

```yaml
---
type: capture
title: "..."
date: YYYY-MM-DD
source: "the command or act that produced it"
status: unprocessed
---
```

`status` is `unprocessed` or `processed`. Once `processed`, the capture MUST
carry exactly one of:

```yaml
distilled-into: <.brain/wiki/... path or [[slug]]>
```

or

```yaml
discarded: "<reason>"
```

Never both, never neither.

### Wiki page frontmatter

Files under `.brain/wiki/concepts/` or `.brain/wiki/decisions/`.

```yaml
---
type: concept        # or: decision
title: "..."
date-updated: YYYY-MM-DD
sources:
  - .brain/raw/research/<file>.md
---
```

`sources:` must be non-empty — a wiki page with no citation is a claim
nothing backs. A decision page's body uses `## Context` / `## Decision` /
`## Why`.

### DISTILL-LOG.md entry grammar

Append at the **top**, directly under the H1, newest first:

```markdown
## YYYY-MM-DD

- run: /distill
- scanned: N captures under .brain/raw/ (M unprocessed)
- promoted: <raw path> -> <wiki path>
- extended: <raw path> -> <wiki path>
- discarded: <raw path> — <reason>
- contradiction: "<side A>" vs "<side B>" — both pages untouched, human decides
- result: <one line; use exactly `zero-op` when nothing was promoted>
```

Only `run:`, `scanned:`, and `result:` are mandatory — every run has all
three, even a zero-op one. `promoted:` and `extended:` lines are the
**promoted form** the gate checks: the path right of `->` must be an existing
`.brain/wiki/` page. Omit `discarded:` / `contradiction:` lines entirely when
there are none to log; do not emit an empty line for a bucket that had no
entries.

## Procedure

1. **Read `.brain/README.md`** for this repo's layer conventions. If it does
   not exist, `.brain/` is not set up — stop and say so. Write nothing.
2. **Enumerate captures**: every file under `.brain/raw/**/*.md`, skipping any
   `README.md`. For each, **parse the frontmatter block** and read the
   `status` key.

   **Never grep for the literal string `status: unprocessed`.** Quoted
   (`status: "unprocessed"`) and unquoted YAML both occur across captures
   written by different commands, and grepping the literal string caused a
   real, recorded miss in the vault system this pass was ported from — a
   capture sat invisible because its frontmatter used the form the grep
   didn't match. Parse the block; don't pattern-match a substring of it.
3. **For each `status: unprocessed` capture, choose exactly one of four
   outcomes:**
   - **Extend** an existing `.brain/wiki/` page — append to it, bump
     `date-updated` — when the material is additive to something already
     there. **Search `wiki/` first.** A near-duplicate page created instead
     of an extension is the one-fact-one-file violation this layer exists to
     prevent.
   - **Create** a new `wiki/concepts/` or `wiki/decisions/` page when the
     topic is genuinely new. Cross-link it with `[[wikilinks]]` and relative
     markdown links to related pages.
   - **Discard** — record `discarded: "<reason>"` on the capture's
     frontmatter. Never silent: every discard leaves a reason a later reader
     can check.
   - **Flag a contradiction** — quote **both** sides into the run's
     `DISTILL-LOG.md` entry and touch **neither** page. A human decides
     merges; this pass never auto-merges a contradiction, and there is no
     mechanism anywhere in this system that would let it.
4. **Write provenance before marking processed.** The wiki page's `sources:`
   entry — source path, the command that produced the capture, the date —
   must land in the page *before* the capture's `status` flips to
   `processed`. Inline and self-describing: a reader of the wiki page alone
   should be able to tell where the fact came from without opening the
   capture.
5. **Mark the capture processed.** Set `status: processed` and add exactly
   one of `distilled-into:` or `discarded:`. **Never edit the capture's
   body.** A capture is evidence of what a command actually produced; a
   capture whose body can be rewritten after the fact isn't evidence anymore.
6. **Append the log entry, always.** Even a run that finds zero unprocessed
   captures appends a `## YYYY-MM-DD` entry with `result: zero-op`. A
   healthy, boring entry is what makes a later break visible by contrast —
   silence and health look identical unless every run leaves a mark.
7. **Verify and report.** Run
   `bash .logic-loom/scripts/bash/check-brain-record.sh` and print its
   result. Print a short summary: captures scanned, still-unprocessed count,
   pages promoted/extended, captures discarded, contradictions flagged. Do
   not print full wiki pages or full capture bodies — the files themselves
   are the artifact.

### --dry-run

Perform steps 1-3 (read, enumerate, parse, decide an outcome per capture) and
report exactly what step 4 onward *would* do — which page would be extended
or created, what reason a discard would record, which contradictions would be
flagged, and the log entry that would be appended. Write nothing: no
frontmatter change, no wiki edit, no `DISTILL-LOG.md` append, no
`check-brain-record.sh` run (there is nothing new for it to check).

## Never

- **Run git, in any form.** Not `git add`, not a commit, nothing. The vault's
  source pass pulls, commits, and pushes unattended at 6am; in this repo that
  is exactly what Principle VI exists to stop —
  `git-safety-gate.sh` forces an approval prompt on the main agent and
  `subagent-git-guard.sh` denies a subagent outright. This pass leaves its
  writes sitting in the working tree and the human commits them through the
  existing approval path. That is not a compromise on the vault's design —
  it removes the entire unattended-git failure mode the vault's own task
  spends three paragraphs mitigating.
- **Delete a capture.** The port deliberately drops the vault's
  delete-after-merge rule. `.brain/raw/` is stripped at template release
  (it never ships to a customer's public template line), so deleting a
  capture after distilling it would leave the *only* surviving copy of, say,
  a `/research` output as a paragraph inside a wiki page plus a blob in the
  private dev line's git history — a history the public template line never
  sees. That converts "does not ship" into "does not exist for anyone
  reading the public line," which is a strictly worse trade than keeping the
  raw file. The honest cost of this choice: `.brain/raw/` grows without
  bound, `status` becomes the *only* thing separating pending from done, and
  a capture that lands with no `status` at all is invisible to this pass
  forever — which is exactly why check 1 of `check-brain-record.sh` exists.
- **Edit an existing capture's body.** A capture is evidence of what a
  command produced at the time it produced it; editing the body after the
  fact destroys that.
- **Auto-merge a contradiction.** Quote both sides into the log and leave
  both pages untouched. A human decides merges — there is no mechanism in
  this system, or the vault's, that makes that safe to automate.
- **Write outside `.brain/`.** This pass's entire footprint is
  `.brain/raw/**` (frontmatter only), `.brain/wiki/**`, and
  `.brain/DISTILL-LOG.md`.
- **Touch `.logic-loom/memory/` or any external knowledge vault.** Those are
  different stores with different lifecycles and different strip decisions;
  bolting a second knowledge destination onto this pass is the same
  two-places-to-write failure this design otherwise avoids.
- **Author or restamp a `.brain/index/` pointer entry.** A restamp is the
  human act of having read the diff; an automated pass authoring or
  restamping one performs that same act without having done the reading it
  certifies. This pass never touches `.brain/index/`.

## Idempotency (Principle IV)

A second run over an already-`processed` capture is a no-op: its `status` is
not `unprocessed`, so step 3 never selects it, and nothing about it changes.
Re-running `/distill` when nothing new has landed in `.brain/raw/` is safe and
expected — it produces a `result: zero-op` log entry and nothing else.

## Health

`check-brain-record.sh`'s five checks (frontmatter parses, every `processed`
capture backs its claim, every wiki page cites a non-empty `sources:`, every
log promotion resolves to a real page, a non-empty `wiki/` implies a log
exists) are **fail-closed in CI**. Liveness (has the pass run recently?) and
load (how big is the backlog?) are **advisory only**, surfaced through the
`governance-preflight.sh` injection, and never block a build. Thresholds live
in `.logic-loom/config/brain.conf`.

Only record integrity is a gate, and deliberately so: a fail-closed CI check
must assert something the change in front of it is responsible for. "The log
says a run promoted capture X into page Y, and page Y doesn't exist" is a
broken record — deterministic, and never a false alarm on an unrelated PR.
"You haven't distilled in 40 days" is not caused by the PR it would block;
gating on it stops unrelated work for an unrelated reason, and the trained
response to that is to bypass the gate, not to fix the habit. A customer who
never adopts this routine would otherwise inherit a permanently red build —
the fastest route to a gate getting deleted rather than heeded.

## Designed for extraction

This pass is a stopgap for a product that will eventually live outside every
project it serves. Three layers, three different lifespans:

1. **The contract — portable, and the thing to protect.** Capture
   frontmatter, wiki page shape, the four promotion outcomes, the log entry
   grammar — all of it lives here and in `.brain/README.md` as **prose and
   data, never as parsing logic**. A future centralized product reads the
   same frontmatter off the same files with none of this repo's code.
2. **The invoker — replaceable, and expected to be replaced.** `/distill`
   itself. A future product substitutes its own scheduler pointed at the
   repo; nothing else moves, because `/distill` is a prompt, not an engine.
3. **Repo-local by necessity — does not extract.** `check-brain-record.sh` is
   a CI gate on this repo's own tracked files; a remote product cannot fail
   this repo's build, and shouldn't try. It keeps running unchanged on the
   day the invoker changes — it validates the record, not who wrote it.

**The one discipline that keeps this true: no script may ever parse a
`.brain/wiki/` page's body.** `check-brain-record.sh` reads frontmatter and
file existence only. The moment a gate depends on prose structure inside a
wiki page, the contract stops being portable.

## Configuration

**Arguments:**

- `/distill` (no arguments) — run the pass and write.
- `/distill --dry-run` — report the outcomes the pass would choose, write
  nothing.

**Resolution rules:** none — the pass always operates over the whole of
`.brain/raw/`, not a named feature or scope.

**Idempotency:** safe to re-run at any cadence; a `processed` capture is
never revisited, and a run with nothing to promote still appends a
`result: zero-op` log entry.

## Constitutional alignment

- **Principle IV (Idempotency)**: a second run over the same state changes
  nothing. See "Idempotency" above.
- **Principle VI (Git Approval)**: this pass never runs git, in any form. See
  "Never" above.
- **Principle VII (Observability)**: the log entry on every run — including
  zero-op runs — is what makes a later break in the routine visible by
  contrast against a history of healthy entries.
