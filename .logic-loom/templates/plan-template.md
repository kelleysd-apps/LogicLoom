<!--
LogicLoom Plan-as-DAG Template (v0.1)

Semantics:
- DAG ordering: `depends_on` lists task IDs that must complete (and pass their
  rubric) before a task is dispatched. Cycles are a parser error.
- File ownership: every task declares `owns` — a list of file globs it may
  write. The freeze-write-scope hook (Stage 11) enforces this at write time.
  This nested-YAML frontmatter is the source of truth that `/swarm implement`
  parses. Before dispatching each task's worker, the scheduler resolves that
  task's `owns`/`freeze` lists and writes them — together with the feature and
  task id — into the repo-root marker file `.loom-active-feature`, which is
  what the hook reads on every write attempt. (LOOM_ACTIVE_FEATURE /
  LOOM_ACTIVE_TASK env vars are also set as an override for env-aware runners.)
  See `.docs/architecture/freeze-scope-protocol.md` for the marker format and
  enforcement rules, and `plugins/loom-orchestrator/skills/swarm-implement/
  SKILL.md` §6 for the write/teardown lifecycle.
- One-task-one-owner rule: if two tasks declare the same path in `owns`, the
  swarm-implement scheduler refuses to dispatch and reports the conflict.
  Concurrent writes to the same file are never allowed.
- `freeze`: optional explicit denylist for tasks that need to assert they will
  not touch a sibling area (defense-in-depth on top of `owns`).
- Typed edges (optional): a task may declare two keys that enrich `depends_on`
  with the concrete interface a downstream task needs:
    - `produces`: a list of "<kind>: <path>#<symbol-or-anchor>" strings naming
      the interfaces this task creates,
      e.g. "api-contract: src/auth/types.ts#LoginRequest".
    - `consumes`: a list of refs that each match, VERBATIM, an upstream task's
      `produces` entry (same string).
  Quote these scalars in YAML — the embedded `: ` would otherwise parse as a
  mapping rather than a string. At brief-authoring time `/swarm implement`
  resolves each `consumes` ref against the COMPLETED upstream task's `produces`,
  reads the named `path#symbol`, and embeds it in that worker's brief.md under a
  section titled "## Upstream interfaces". Both keys are OPTIONAL and
  warn-not-block: an unresolved `consumes` ref WARNs (it never blocks dispatch),
  and legacy plans declaring neither key parse unchanged.
- `status`: optional, CLOSED vocabulary — exactly one of:
    - `open`         not started (the DEFAULT when the key is absent)
    - `in_progress`  a worker is on it right now
    - `blocked`      cannot proceed; see `blocked_on`
    - `done`         complete and its rubric passed
  No other value is legal. Absent means `open` — legacy plans that predate this
  key parse unchanged. This exists so completion is MACHINE-READABLE: before it,
  a plan's DAG could be walked but nothing could say what was finished.
- `blocked_on`: optional, a list of task ids that are BLOCKING this task.
  Distinct from `depends_on`, and the distinction is the whole point:
    - `depends_on` is ORDERING — a permanent structural fact of the plan,
      declared up front, and what the scheduler topologically sorts on.
    - `blocked_on` is a LIVE IMPEDIMENT — "this cannot proceed right now" —
      added and removed as work happens. A consumer SURFACES it (a backlog
      report, a status roll-up); the scheduler does not sort on it.
  A task listing `blocked_on` should normally carry `status: blocked`.
  Deliberately NOT in this schema — owners, estimates, percent-complete,
  per-item timestamps, priority. A richer schema on day one is the standard way
  this kind of file rots: every extra field is one more thing to keep true.
- Task `id`s are PROJECT-LOCAL and short (`t1`, `t2`) — unique within this plan,
  not across repositories. What qualifies them when they leave the repo is
  `id_prefix` in `.logic-loom/config/project.conf` (e.g. `ACME-t1`).
- Rubric: each task ships acceptance predicates that the evaluator
  (/review-team) checks before downstream tasks are dispatched. A task with a
  failing rubric blocks its dependents.
- Sprints: grouped tasks. Sprints run in order; within a sprint, the scheduler
  topologically sorts tasks and (eventually) dispatches non-conflicting tasks
  in parallel waves. v0.1 may execute a sprint sequentially.
-->

---
feature: <feature-name>
version: 0.1.0
inputs:
  vision: features/<feature-name>/vision.md
  prd: features/<feature-name>/prd.md
  research:
    - features/<feature-name>/research/*.md
  exploration:
    - features/<feature-name>/exploration/*.md
sprints:
  - name: 01-foundations
    description: One-line sprint goal.
    tasks:
      - id: t1
        description: One-line task goal.
        status: open                    # open | in_progress | blocked | done (default: open)
        owns:
          - src/auth/login.ts
          - src/auth/types.ts
        freeze:
          - src/payments/**
        depends_on: []
        produces:                       # optional typed-edge outputs (quote the scalars)
          - "api-contract: src/auth/types.ts#LoginRequest"
        rubric:
          - login form renders without runtime errors
          - submits credentials via POST /api/auth
      - id: t2
        description: Persist session after successful login.
        status: blocked                 # cannot proceed right now — see blocked_on
        owns:
          - src/auth/session.ts
        freeze: []
        depends_on:                     # ORDERING — structural, sorted on
          - t1
        blocked_on:                     # LIVE IMPEDIMENT — surfaced, not sorted on
          - t1
        consumes:                       # optional; each ref must match an upstream `produces` string verbatim
          - "api-contract: src/auth/types.ts#LoginRequest"
        rubric:
          - session token written to httpOnly cookie
          - integration test passes for login -> protected route
  - name: 02-hardening
    description: One-line sprint goal.
    tasks:
      - id: t3
        description: One-line task goal.
        # status omitted on purpose — an absent `status` means `open`.
        owns:
          - tests/auth/*.test.ts
        depends_on:
          - t2
        rubric:
          - ">80% line coverage on src/auth/**"
---

# Plan: <feature-name>

## Summary

Two to four sentences describing what this plan delivers and the headline
approach. Tie back to the PRD success criteria.

## Architectural notes

Call out the load-bearing decisions: data model boundary, auth boundary,
external services, migration order, idempotency strategy.

## Risks and mitigations

- Risk: <short>. Mitigation: <short>.
- Risk: <short>. Mitigation: <short>.

## Out of scope

Bulleted list of items deferred to a later feature. Each item should be
traceable to a PRD line that was explicitly deferred.

## Test strategy

Brief paragraph mapping contracts to test types (unit / integration / contract
/ e2e). Must satisfy Principle II (>80% coverage, test-first).
