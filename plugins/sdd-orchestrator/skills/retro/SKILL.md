---
name: retro
version: 0.1.0
description: |
  Sprint retrospective for the Reflect phase of the LogicLoom workflow.
  Consumed post-`/git-push`. Reads features/<name>/sprints/* + git log + plan-review
  artifacts, synthesizes features/<name>/retro.md with wins/misses/action-items,
  and writes the action-items into sdd-memory so future runs benefit.
allowed-tools: Read, Write, Bash
triggers: ["retro", "retrospective", "reflect"]
category: orchestration
constitutional_principles: [VII, VIII]
---

# Retro Skill

## Overview

`/retro` closes the LogicLoom loop. After `/git-push` merges a feature, this
skill assembles the structured artifacts produced during the run (per-sprint
outputs, git activity since branch creation, plan-vs-actual DAG outcomes, and
the original plan-review concerns), synthesizes a retrospective at
`features/<feature-name>/retro.md`, and writes the action-items section into
sdd-memory so the next feature inherits the lessons.

This is a simple v0.1 retro — no counterfactuals, no separate Memory-R2 trace
analysis. The Reflect phase exists to convert one-shot wins/misses into
durable improvements to skills, hooks, and plan templates.

## When to Use

Invoke this skill in exactly one window of the feature lifecycle:

- **After** `/git-push` has completed for the feature (branch merged or PR
  opened; feature code at rest).
- **Before** moving on to the next feature's Vision phase, so action-items can
  influence the next plan.

Do NOT use this skill:

- Mid-implementation (sprints/ is still being written — retro will be partial
  and misleading).
- For features that never reached `/git-push` (use `/research` or office-hours
  to triage failure modes instead).
- More than once per feature per day (idempotency: re-runs overwrite
  retro.md and skip duplicate memory writes for the same day).

## Task Brief

You are a retrospective synthesizer. You will read four inputs, classify each
observation into one of three buckets (went-well / didn't / action-item), and
emit a single markdown file plus one memory entry. Be specific — vague retro
items ("communication could be better") are not acceptable. Every item must
name the artifact, sprint, or step it refers to.

**Inputs:** (1) `features/<feature-name>/sprints/*` — per-sprint outputs,
noting which nodes completed first try vs needed retries (`attempt-2/`,
`retry-*/`, `failed.md`); (2) git activity since branch creation via
`git log --oneline $(git merge-base HEAD main)..HEAD` (shows cadence, scope
drift, freeze-hook trips, `fix:`-of-`feat:` patterns); (3) plan-vs-actual DAG
diff — sprints/ listing compared against the DAG in `plan.md`; (4)
`features/<feature-name>/plan-review.md` if present — re-grade the CEO+Eng
concerns against actual outcomes.

**Synthesis buckets:**

- **What went well**: technical wins, prompt patterns that worked, sprint
  nodes that hit their rubric first try, plan-review concerns that proved
  non-issues because the plan handled them.
- **What didn't**: debug loops, scope creep, freeze-hook trips, retries,
  plan-review concerns that proved warranted but weren't acted on, anything
  that took materially longer than the plan estimated.
- **Action items**: concrete follow-ups — skill prompt updates (name the
  skill file), hook tuning (name the hook), plan-template refinements (name
  the section), sdd-memory entries to write (name the topic). Each item must
  be small enough to do in one PR.

## Procedure

1. **Parse arguments**: Extract `<feature-name>` (required positional or via
   `--feature`).
2. **Locate artifacts**: Verify `features/<feature-name>/` exists. If it
   doesn't, emit a clear error and exit without writing anything. Note which
   inputs are present vs missing — `sprints/` is required; `plan.md`,
   `plan-review.md`, and a git history are best-effort.
3. **Read sprint outputs**: `ls features/<feature-name>/sprints/` and Read
   each sprint summary. Build a mental list of `{node, attempts, outcome}`.
4. **Read git log**: Run
   `git log --oneline $(git merge-base HEAD main)..HEAD` via Bash. If
   merge-base fails (branch was just created off main), fall back to
   `git log --oneline --since="$(git log -1 --format=%ai main)"`. Note
   commit cadence and any revert/fix-of-fix patterns.
5. **Read plan-review (optional)**: If
   `features/<feature-name>/plan-review.md` exists, Read it and extract the
   CEO + Eng `concern` and `fail` items. These are the predictions to grade
   against actual outcomes.
6. **Synthesize buckets**: Classify every observation into went-well /
   didn't / action-items per the Task Brief rubric.
7. **Write retro.md**: Write `features/<feature-name>/retro.md` using the
   schema below. Overwrite any previous retro at that path (idempotent).
8. **Write memory entry**: Compute the memory directory:
   `$HOME/.claude/projects/<project-slug>/memory/` where `<project-slug>` is
   the CWD path with `/` replaced by `-` (the convention this user's setup
   already follows — e.g.
   `-Users-bkelley-kelleysd-apps-sdd-agentic-framework`). Determine the slug
   via Bash:
   `slug=$(pwd | sed 's|/|-|g')` and target
   `$HOME/.claude/projects/${slug}/memory/retro_<feature>_<YYYY-MM-DD>.md`.
   If that exact path already exists (same feature, same day), skip the
   write and announce the skip — do NOT append or rewrite. Otherwise, write
   the action-items section (only the action-items, not the full retro) to
   that path with a one-line header that names the feature and date so the
   memory backend can index it.
9. **Print summary**: Echo three lines — retro path, memory path (or "memory
   write skipped: already exists for today"), and a one-line tally
   (`went-well: N, didn't: N, action-items: N`). Do not echo the full
   retro — the file is the artifact.

## Output format

Write `features/<feature-name>/retro.md` with exactly this structure:

```markdown
# Retro — <feature-name>

- Date: <YYYY-MM-DD>
- Branch: <branch-name>
- Sprints observed: <N>
- Commits since branch start: <N>
- Plan-review verdict at start: <go | conditional | no-go | n/a>

## Plan vs actual

| Planned node | Outcome | Attempts | Notes |
|--------------|---------|----------|-------|
| ... | first-try / retried / skipped / added | <N> | ... |

## What went well

- <specific observation tied to a sprint, commit, or artifact>
- ...

## What didn't

- <specific observation tied to a sprint, commit, or artifact>
- ...

## Action items

- [ ] <concrete change: skill prompt update, hook tuning, plan-template
      refinement, or memory entry — name the file/section>
- [ ] ...

## Plan-review re-grade (optional)

<Omit if no plan-review.md existed.>

| Original concern | Predicted by | Proved warranted? | Notes |
|------------------|--------------|-------------------|-------|
| ... | CEO / Eng / Design | yes / no / partial | ... |
```

The action-items list is the load-bearing output for memory: each item must
be specific enough that a future session reading the memory entry knows
exactly what file to edit. Vague items are not acceptable.

## Configuration

**Arguments:**

- `<feature-name>` (required, positional): the directory name under
  `features/` whose retro should be written. Example: `auth-jwt-rotation`.

**Resolution rules:**

- If invoked without a feature name and exactly one directory exists under
  `features/` containing a `sprints/` subdirectory, default to that feature
  and announce the defaulting in the summary line.
- If multiple candidates exist, error out and list them.

**Idempotency:** `retro.md` is overwritten on every invocation — re-running
is safe. Memory entries are dated and named `retro_<feature>_<YYYY-MM-DD>.md`;
a second invocation on the same day for the same feature detects the existing
file and skips the memory write rather than duplicating it.

**Memory write target:**
`$HOME/.claude/projects/<slug>/memory/retro_<feature>_<YYYY-MM-DD>.md` where
`<slug>` is derived via `pwd | sed 's|/|-|g'` (matches the convention used by
`MEMORY.md`). The memory file contains only the action-items section plus a
one-line header; the full retro stays in the feature directory.

## Constitutional alignment

- **Principle VII (Observability)**: Retro IS observability. Without a
  structured retro the framework can't see its own failure patterns. The
  memory write makes those patterns durable across sessions.
- **Principle VIII (Documentation Sync)**: Action items that update skills,
  hooks, or plan templates must land as real edits; the memory entry exists
  to make those follow-ups discoverable on the next session.
