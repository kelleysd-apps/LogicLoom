---
name: swarm-implement
version: 0.1.0
description: |
  Executes a feature's plan.md as a DAG. Topologically sorts tasks within a
  sprint, enforces file-ownership conflict detection before dispatch, spawns
  Task workers after writing the .loom-active-feature marker (feature/task +
  resolved owns/freeze scope) so the freeze-write-scope hook gates writes, and
  verifies each task's rubric via /review-team before dispatching its
  dependents.
allowed-tools: Task, Read, Write, Bash
triggers: ["swarm implement", "/swarm implement"]
category: orchestration
constitutional_principles: [II, X]
---

# Swarm Implement Skill

## Overview

`swarm-implement` is the Phase 7 executor in the LogicLoom feature lifecycle:
it turns a reviewed `plan.md` into actual code by walking the plan as a
directed acyclic graph (DAG) of tasks. Each task is a Task-tool worker
constrained by:

1. A declared `owns` set of file paths (file-ownership).
2. An optional `freeze` denylist.
3. A `depends_on` ordering edge.
4. A `rubric` of acceptance predicates.

The scheduler dispatches a task only after all of its `depends_on` tasks have
completed AND passed their rubric. v0.1 may execute a sprint sequentially; the
DAG semantics, ownership enforcement, and rubric gating still apply.

## When to Use

Use this skill in exactly one window of the feature lifecycle:

- **After** `/plan-review <feature>` has written
  `features/<feature>/plan-review.md` with `Overall verdict: go`.
- **Before** code is hand-written for the feature.

Do NOT use this skill:

- When `plan-review.md` is missing or its verdict is not `go` — fix the plan,
  re-run `/plan-review`, then retry.
- For trivial single-file edits with no DAG structure — just edit.
- After implementation has started in a non-DAG manner — finish that work or
  reset the sprint directory first.

## Task Brief

You are the DAG executor for `features/<feature>/plan.md`. Your responsibilities:

### 1. Gate on plan-review

Before doing anything else, read `features/<feature>/plan-review.md`. If the
file is missing, or `Overall verdict:` is not exactly `go`, refuse to proceed.
Print the verdict and the path to the required-changes list.

### 2. Parse the plan

Load the YAML frontmatter from `features/<feature>/plan.md`. Validate:

- `sprints` is a non-empty list.
- Every task has `id`, `description`, `owns`, `depends_on`, `rubric`.
- `depends_on` references resolve to task IDs within the same sprint (no
  cross-sprint dependencies in v0.1).
- The dependency graph within a sprint is acyclic (Kahn's algorithm — if any
  node remains with unresolved deps after the sort, the graph has a cycle).

### 3. Detect file-ownership conflicts (pre-dispatch)

Within a sprint, collect every path declared in any task's `owns`. If the same
path appears in two tasks' `owns` lists, refuse to dispatch and report the
conflicting tasks. This is the one-task-one-owner rule. Globs are compared
literally in v0.1 (string equality on the declared pattern); a future version
may resolve globs and check overlap.

### 4. Resolve the active sprint

If `--sprint <name>` is given, use that sprint. Otherwise default to the next
sprint that does not yet have a directory under
`features/<feature>/sprints/`. If all sprints have directories, report "all
sprints started" and exit without dispatching.

### 5. Schedule

Topologically sort the sprint's tasks. In v0.1, execute the sorted list
sequentially. (v0.2 will group tasks with no remaining dependencies into a
"wave" and dispatch the wave in parallel via concurrent Task calls.)

### 6. Dispatch each task

For task `<id>`:

1. Create `features/<feature>/sprints/<NN-sprint-name>/<id>/` and write a
   `brief.md` containing the task description, `owns`, `freeze`, and `rubric`.
2. **Establish the active-task freeze context BEFORE dispatch.** This is the
   step that arms the `freeze-write-scope.sh` PreToolUse hook. Without it the
   hook has no active DAG context and default-allows every write — i.e. the
   ownership guarantee is a no-op. Write the marker file at the repo root,
   `<repo>/.loom-active-feature`, carrying the task's resolved scope inline:

   ```
   feature: <feature>
   task: <id>
   owns:
     - <each owns: path/glob resolved from plan.md for this task>
     - ...
   freeze:
     - <each freeze: path/glob resolved from plan.md for this task>
     - ...
   ```

   The marker's `owns:`/`freeze:` lists are **authoritative** for the hook —
   it does not have to re-parse the nested-YAML plan. You have already parsed
   `plan.md` in step 2, so emit the concrete resolved lists here. Use the
   `Write` tool to create the marker (this write is itself permitted — the
   marker does not yet exist, and the hook default-allows until a marker with
   scope is present).
3. Spawn a Task worker with:
   - Environment (belt-and-suspenders, for env-aware runners):
     `LOOM_ACTIVE_FEATURE=<feature>`, `LOOM_ACTIVE_TASK=<id>`. The hook reads
     these too; when present they override the marker's `feature:`/`task:`
     lines. The marker remains the source of the `owns:`/`freeze:` scope.
   - Prompt: the task description, the resolved `owns`/`freeze`/`rubric`, and
     the absolute path of the per-task output directory.
4. Wait for the worker to return.
5. **Tear down the marker** after the worker returns and BEFORE any
   orchestrator-side write that is not part of the next task's scope: delete
   `<repo>/.loom-active-feature` (or overwrite it with the next task's scope at
   the start of step 2 for that task). Leaving a stale marker would
   incorrectly constrain subsequent ad-hoc writes.

> **Why a marker file, not just env vars?** Task workers run in the same
> process tree, but env injection into a spawned Task is not guaranteed to
> reach every write boundary. The repo-root marker file is read by the hook on
> every write attempt regardless of how the worker was spawned, so it is the
> reliable mechanism. Env vars are kept as an override for runners that do
> propagate them.

### 7. Verify the rubric

Call `/review-team` (or the evaluator skill) against the task's diff with the
rubric as input. If any rubric predicate fails, mark the task `failed`, write
the evaluator output to `features/<feature>/sprints/<NN>/<id>/review.md`, and
do NOT dispatch dependents. Surface the failure to the user.

### 8. Record completion

On rubric pass, write `features/<feature>/sprints/<NN>/<id>/result.md` with
`status: passed`, the rubric outcomes, and pointers to the diff. This is the
signal the scheduler uses to dispatch dependents.

## Procedure

1. **Parse arguments**: `<sprint-name>` (optional positional or `--sprint`),
   `--dry-run` (optional boolean), `<feature>` resolved from
   `LOOM_ACTIVE_FEATURE` env or the single feature with a `plan-review.md` of
   verdict `go`.
2. **Gate on plan-review** per step 1 of the Task Brief.
3. **Parse plan** per step 2. On any validation error, print the error and
   exit without writing anything under `sprints/`.
4. **Detect ownership conflicts** per step 3.
5. **Resolve sprint** per step 4.
6. **If `--dry-run`**: print the topological order and the planned per-task
   output paths, then exit without spawning workers.
7. **Dispatch + verify** per steps 5-8, iterating until the sprint is
   exhausted or a rubric fails.
8. **Print summary**: number of tasks dispatched, number passed, number
   failed, and the absolute path of the sprint directory.

## Output format

Each invocation writes under `features/<feature>/sprints/<NN-sprint-name>/`:

```
sprints/
  01-foundations/
    t1/
      brief.md       # task description, owns, freeze, rubric (input to worker)
      result.md      # status: passed | failed, rubric outcomes, diff pointer
      review.md      # evaluator output (only on failure or if --verbose)
    t2/
      ...
```

The sprint directory itself contains no aggregate file in v0.1; downstream
tooling reads the per-task `result.md` files to determine sprint state.

## Configuration

**Arguments:**

- `<sprint-name>` (optional, positional): name of the sprint to execute (e.g.
  `01-foundations`). Defaults to the next sprint without a directory under
  `features/<feature>/sprints/`.
- `--sprint <name>` (optional): same as the positional, kept for readability.
- `--dry-run` (optional): print the wave schedule and ownership check results
  without spawning Task workers.

**Feature resolution:**

- If `LOOM_ACTIVE_FEATURE` is set, use it.
- Else if exactly one feature under `features/` has a `plan-review.md` with
  `Overall verdict: go`, default to it.
- Else error and list candidates.

**v0.1 vs future versions:**

- **v0.1 (this version)**: sequential execution within a sprint;
  one-task-one-owner check via literal string equality on `owns`; per-task
  rubric verification via /review-team; the `.loom-active-feature` marker
  (written per-dispatch, torn down after) arms the freeze-write-scope hook so
  it enforces writes against the active task's `owns`/`freeze` scope.
- **v0.2 (deferred)**: parallel wave dispatch (Kahn-style barrier between
  waves); glob-aware overlap detection in `owns`; cross-sprint dependencies;
  automatic retry on transient evaluator failure.

## Constitutional alignment

- **Principle II (Test-First)**: Every task's rubric is verified by
  `/review-team` before any dependent task is dispatched. Tasks ship with
  testable predicates or they fail review at plan-stage (`/plan-review`).
- **Principle X (Agent Delegation)**: Implementation work is dispatched to
  Task workers scoped by `owns`/`freeze`/`rubric`. The orchestrator does not
  inline implementation; it gates, dispatches, and verifies.
