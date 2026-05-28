---
name: plan-review
version: 0.1.0
description: |
  Gates `/swarm implement` by running a multi-perspective review of a feature's
  plan.md (CEO scope-challenge + Eng architecture-review, optional Design). Emits
  a go/no-go verdict and detailed feedback at features/<name>/plan-review.md.
allowed-tools: Read, Write
triggers: ["plan-review", "review plan", "plan review"]
category: orchestration
constitutional_principles: [II, X]
---

# Plan Review Skill

## Overview

This skill is the plan-stage analogue of `/review-team`. Where `/review-team`
checks code on a branch, `/plan-review` checks the `plan.md` for a feature
before any worker writes code under `/swarm implement`. It runs two mandatory
reviewers (CEO + Eng) and one optional reviewer (Design, behind `--design`)
sequentially within a single Task context, synthesizes their findings, and
writes a single artifact: `features/<feature-name>/plan-review.md` containing
an explicit go / no-go verdict plus actionable feedback.

The skill is intentionally a single-skill / sequential-reviewers design (v0.1).
If a false-pass rate above 15% is observed across 10 invocations, refactor to
parallel-Task architecture in v0.2.

## When to Use

Invoke this skill in exactly one window of the feature lifecycle:

- **After** `plan.md` has been written to `features/<feature-name>/plan.md`
  (i.e. plan-mode has completed and Claude has exited plan mode).
- **Before** any worker is spawned by `/swarm implement` for that feature.

Do NOT use this skill:

- During brainstorming or vision drafting (use `/research` or office-hours
  conversation instead).
- After code has been written (use `/review-team` instead — that is the
  code-stage gate).
- For trivial single-file edits with no architectural impact.

## Task Brief

You are a sequential plan reviewer. You will adopt two reviewer roles in turn
(CEO, then Eng) and optionally a third (Design) when `--design` is set. Each
reviewer reads the same three artifacts and emits findings against a concrete
rubric. Do not blend the reviewers — keep each role's section separate so the
synthesis step can compare them.

**Reviewer roles (sequential within one Task context):**

### 1. CEO review — scope challenge (mandatory)

The CEO is paid to push back. Read in this order:

1. `features/<name>/vision.md`
2. `features/<name>/prd.md`
3. `features/<name>/plan.md`

Then grade the plan against this rubric. For each item, output one of
`pass | concern | fail` with a one-line justification:

- **Vision alignment**: Does the plan deliver the outcome the vision asked for,
  or has it drifted into adjacent work?
- **PRD success criteria coverage**: Does every PRD success criterion have at
  least one task or contract that satisfies it?
- **Overshoot check**: Is the plan doing more than the PRD requires? Flag any
  task that is not traceable to a PRD line.
- **Cheaper path**: Is there a materially cheaper / simpler path that achieves
  the same PRD success criteria? If yes, name it concretely.
- **Cut list**: Which (if any) tasks could be cut without violating the PRD?

CEO verdict: `go | no-go | conditional` plus one paragraph of reasoning.

### 2. Eng review — architecture + test plan (mandatory)

Read the same three artifacts (`vision.md`, `prd.md`, `plan.md`). Grade the
plan against this rubric. Same `pass | concern | fail` format per item:

- **DAG file-ownership coherence**: Does each task declare the files it will
  own? Are there ownership conflicts (two tasks writing the same file with no
  ordering)?
- **Dependency ordering**: Are task dependencies a real DAG (no cycles)? Are
  obvious prerequisites declared (e.g., schema before API, API before UI)?
- **Per-task rubric testability**: Does each task have a concrete acceptance
  rubric a reviewer or test can check? Flag any task whose rubric is vague
  ("works correctly", "looks good") rather than checkable.
- **Test plan adequacy**: Is there a test strategy (unit / integration /
  contract / e2e mix) that maps to the contracts? Does it satisfy Principle II
  (>80% coverage, test-first)?
- **Risk surface**: Are the top 3 architectural risks called out with
  mitigations? Common misses: auth boundaries, migration order, idempotency,
  failure-mode behavior.

Eng verdict: `go | no-go | conditional` plus one paragraph of reasoning.

### 3. Design review — UX coherence (optional, `--design` flag only)

Skip this section entirely unless the user passed `--design`. When invoked,
read the same three artifacts and grade:

- **User flow completeness**: Are the primary user flows in the PRD covered by
  concrete UI tasks in the plan?
- **State coverage**: Loading / empty / error / success states accounted for
  per surface?
- **Accessibility floor**: Keyboard nav, focus management, contrast targets
  mentioned where relevant?
- **Design-system reuse**: Does the plan reuse existing components or invent
  new ones unnecessarily?

Design verdict: `go | no-go | conditional` plus one paragraph of reasoning.

## Procedure

1. **Parse arguments**: Extract `<feature-name>` (required, positional or via
   `--feature`) and `--design` (optional boolean flag).
2. **Locate artifacts**: Verify the following exist:
   - `features/<feature-name>/vision.md`
   - `features/<feature-name>/prd.md`
   - `features/<feature-name>/plan.md`
   If any are missing, emit a clear error naming the missing file and exit
   without writing `plan-review.md`.
3. **Run CEO review**: Read all three artifacts. Produce the CEO rubric table
   and verdict per the Task Brief.
4. **Run Eng review**: Re-read the artifacts in the Eng role. Produce the Eng
   rubric table and verdict.
5. **Run Design review** (only if `--design`): Produce the Design rubric and
   verdict.
6. **Synthesize**: Combine the reviewer verdicts into a single overall verdict
   using this rule:
   - Overall = `go` only if all invoked reviewers returned `go`.
   - Overall = `no-go` if any reviewer returned `no-go`.
   - Overall = `conditional` otherwise (any `conditional` and no `no-go`).
7. **Write artifact**: Write the full review to
   `features/<feature-name>/plan-review.md` using the schema below. Overwrite
   any previous review at that path.
8. **Print summary**: Echo the overall verdict and the path of the written
   artifact to stdout. Do not print the full review — the file is the artifact.

## Output format

Write `features/<feature-name>/plan-review.md` with exactly this structure:

```markdown
# Plan Review — <feature-name>

- Date: <YYYY-MM-DD>
- Reviewers run: CEO, Eng[, Design]
- Overall verdict: go | no-go | conditional

## Overall reasoning

<2-4 sentences synthesizing the reviewer verdicts. Name any blocking item.>

## CEO review (scope challenge)

Verdict: go | no-go | conditional

| Item | Result | Justification |
|------|--------|---------------|
| Vision alignment | pass / concern / fail | ... |
| PRD success criteria coverage | ... | ... |
| Overshoot check | ... | ... |
| Cheaper path | ... | ... |
| Cut list | ... | ... |

Reasoning: <one paragraph>

## Eng review (architecture + test plan)

Verdict: go | no-go | conditional

| Item | Result | Justification |
|------|--------|---------------|
| DAG file-ownership coherence | ... | ... |
| Dependency ordering | ... | ... |
| Per-task rubric testability | ... | ... |
| Test plan adequacy | ... | ... |
| Risk surface | ... | ... |

Reasoning: <one paragraph>

## Design review (optional)

<Omit this whole section if --design was not passed.>

Verdict: go | no-go | conditional

| Item | Result | Justification |
|------|--------|---------------|
| User flow completeness | ... | ... |
| State coverage | ... | ... |
| Accessibility floor | ... | ... |
| Design-system reuse | ... | ... |

Reasoning: <one paragraph>

## Required changes (if verdict is no-go or conditional)

- [ ] <concrete change to plan.md, traceable to a rubric item above>
- [ ] ...
```

The required-changes list is the load-bearing output for the human: every item
must be specific enough that an editor of `plan.md` knows what to add, remove,
or rephrase. Vague items ("tighten the test plan") are not acceptable — name
the section and the change.

## Configuration

**Arguments:**

- `<feature-name>` (required, positional): the directory name under
  `features/` whose plan should be reviewed. Example: `auth-jwt-rotation`.
- `--design` (optional): also run the Design reviewer. Off by default; turn on
  only for plans with material UX surface.

**Resolution rules:**

- If invoked without a feature name and exactly one directory exists under
  `features/` containing a `plan.md`, default to that feature and announce the
  defaulting in the summary line.
- If multiple candidates exist, error out and list them.

**Gating contract with `/swarm implement`:**

- `/swarm implement <feature>` reads `features/<feature>/plan-review.md` before
  spawning workers. If the file is missing, or its `Overall verdict` is not
  `go`, `/swarm implement` refuses to proceed and points the user at the
  required-changes list. The author of the plan iterates and re-runs
  `/plan-review` until `go`.

**Promotion criteria (v0.1 → v0.2):**

If the false-pass rate exceeds 15% over 10 invocations (i.e., `go` verdicts
that subsequently required hot-fixes the rubric should have caught), refactor
this skill from sequential-reviewers in one context to parallel-Task workers
with a synthesizer, mirroring `/review-team`'s architecture.

## Constitutional alignment

- **Principle II (Test-First)**: The Eng rubric explicitly grades test-plan
  adequacy and Principle II coverage targets, so a plan that ships without a
  testable strategy cannot pass review.
- **Principle X (Agent Delegation)**: This skill is the specialist for
  plan-stage review. `/swarm implement` must delegate plan validation here
  rather than inlining ad-hoc checks.
