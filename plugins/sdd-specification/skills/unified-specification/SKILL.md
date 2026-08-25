---
name: unified-specification
version: 2.0.0
description: |
  Unified SDD specification workflow. Generates the full set of design artifacts
  (spec.md, research.md, data-model.md, contracts/, quickstart.md, plan.md,
  tasks.md) in one orchestrated run, with quality gates between phases.

  Triggered by: /specification command, "create full specification",
  "generate complete spec", "unified specification workflow"

allowed-tools: Read, Write, Bash, Grep, Glob
triggers:
  - /specification
  - unified specification
  - complete specification workflow
  - generate full spec
category: sdd-workflow
constitutional_principles:
  - II (Test-First — tasks are TDD-ordered)
  - III (Contract-First — contracts precede implementation)
  - VI (Git Approval for branch operations)
  - VIII (Documentation Synchronization)
---

# Unified Specification Skill

## Overview

This skill runs the complete SDD waterfall — specification, planning, and task
breakdown — in a single execution with quality gates between phases.

**It is self-contained.** You perform all three phases yourself using the
scripts and templates named below. There is no sub-skill to hand off to.

## When to Use

Activate this skill when:
- User invokes `/specification <feature-description>`
- User requests "create a complete specification"
- User wants to go from feature idea to executable tasks
- Starting a new feature that needs the full SDD waterfall

## Task Brief

You are the Specification Engineer for the full SDD waterfall. You translate a
business need into an executable specification, a technical plan with contracts
and a data model, and a dependency-ordered task list — yourself, in one pass,
enforcing a quality gate between each phase.

**Required context**: feature-description (what to build), user-requirements
(user needs). Optional: constraints (technical limits), scope-boundaries
(what's in/out).

**What you do NOT do**: skip a phase (each one feeds the next), make product
scope calls the user hasn't made, or invent an answer to a `[NEEDS
CLARIFICATION]` marker rather than asking.

**Resume capability**: workflow state is saved to `.workflow-state.json`. On
interruption, resume from the last completed phase via `--resume`.

The standards below apply to all three phases.

**Specification** — intent-first (what/why before how), technology-agnostic,
measurable outcomes. Business objectives traceable; user stories with specific,
testable acceptance criteria; functional *and* non-functional requirements; edge
cases and error conditions identified; constraints documented without prescribing
solutions. Avoid solution bias, ambiguous language, missing context, feature
creep. Write for direct AI interpretation: concrete examples, clear boundaries,
unambiguous acceptance criteria.

**Planning** — for each technology decision, evaluate 2-3 options and record
decision + rationale + alternatives. Resolve every `[NEEDS CLARIFICATION]` before
moving to design. Contracts: REST uses standard verbs, resource-oriented URLs,
proper status codes, OpenAPI 3.0; GraphQL is schema-first with query/mutation
separation. Every user action gets a contract. Data model entities carry fields,
types, constraints, relationships, validation rules, state transitions, indexes.

**Tasks** — each task is single-responsibility, time-bounded (1-4 hours),
unambiguous, objectively testable, minimally coupled, and actionable without
further research. Anything over ~4 hours gets broken down.

## Procedure

### Step 0: Initialize Workflow

Resolve the feature paths. The SDD pack keys off a `###-name` feature branch:

```bash
.logic-loom/scripts/bash/get-feature-paths.sh
```

If that fails with "Not on a feature branch", you are not on a `###-name`
branch. Do **not** fabricate paths: jump to Step 1a, settle the branch question
with the user, then come back here and re-run the script to get real paths.

**Create workflow state** at `${FEATURE_DIR}/.workflow-state.json`, once
`${FEATURE_DIR}` exists:

```bash
cat > "${FEATURE_DIR}/.workflow-state.json" << EOF
{
  "version": "2.0.0",
  "feature_branch": "${BRANCH}",
  "feature_description": "$ARGUMENTS",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "current_phase": "spec",
  "phases": {
    "spec": { "status": "pending" },
    "plan": { "status": "pending" },
    "tasks": { "status": "pending" }
  },
  "artifacts": {},
  "quality_gates": {}
}
EOF
```

**Check for resume**:
```
IF --resume flag AND state file exists:
  Load state file, resume from current_phase
ELSE IF state file exists:
  Ask: "Previous workflow found. Resume or start fresh?"
```

---

### Step 1: Specification Phase (spec.md)

**Update state**: `current_phase: "spec"`, `phases.spec.status: "running"`

**1a. Branch decision (Principle VI)**

Ask: *"Would you like to create a new feature branch, or work on the current
branch?"*

- **New branch** → run `.logic-loom/scripts/bash/create-new-feature.sh --json "$ARGUMENTS"`.
  The script handles branch creation; git approval is gated by the hook floor.
  It returns `BRANCH_NAME`, `SPEC_FILE`, `FEATURE_NUM`, `FEATURE_DIR` and copies
  the spec template into place.
- **Current branch** → confirm it matches `###-name`, ensure `${FEATURE_DIR}`
  exists, and copy `.logic-loom/templates/spec-template.md` to
  `${FEATURE_DIR}/spec.md` if no spec is there yet.

Never create a branch without the user having asked for one.

**1b. Load the template**

```
Read: .logic-loom/templates/spec-template.md
```

The template is self-executing — follow its Execution Flow. Preserve its section
structure and order: Title, Overview, User Scenarios & Testing, Functional
Requirements, Key Entities, Acceptance Criteria, Technical Considerations,
Dependencies, Risks, Success Metrics.

**1c. Write the specification**

Replace every placeholder with concrete content drawn from the user's feature
description. User stories in "As a [role], I want [capability], so that
[benefit]" form. Mark genuinely unresolved points `[NEEDS CLARIFICATION: <specific
question>]` rather than guessing. Write to `${FEATURE_SPEC}`.

**1d. Quality gate**

```bash
.logic-loom/scripts/bash/validate-spec.sh --file ${FEATURE_SPEC} --json
```

The script reports `score` as a percentage (0-100) across required, recommended,
and optional checks. Threshold: **90**.

**Read the exit code before the score.** Exit **3** is a script error — bad
option, or a missing/unreadable file — and on that path nothing was validated
and no JSON is emitted. There is no score to read, and an absent score is *not*
a zero.

```
IF exit code == 3:
  The gate NEVER RAN. Do not report a score, and do not infer one.
  Report the script's stderr verbatim and the ${FEATURE_SPEC} path you passed.
  Fix the invocation (usually: the spec was never written, or the path is wrong)
  and re-run. Never continue to Step 1e on a 3.

IF exit code is 0, 1 or 2:
  The document WAS validated and the JSON carries a real score — act on it.
  IF score < 90:
    Report the score and the script's specific recommendations
    IF retry_count < 3:
      Ask: "Refine specification and retry? (y/n)"
      IF yes: address the named gaps, rewrite, re-validate
    ELSE:
      Ask: "Proceed despite low quality? (y/n/abort)"
```

**1e. Domain detection**

```bash
.logic-loom/scripts/bash/detect-phase-domain.sh --file ${FEATURE_SPEC} --json
```

Record detected domains, suggested specialists, and whether the feature is
single- or multi-domain. Report to the user; carry it forward to Step 4.

**Update state on success**:
```json
{
  "phases.spec.status": "complete",
  "phases.spec.completed_at": "<timestamp>",
  "artifacts.spec.md": { "exists": true, "validated": true, "score": 95 },
  "quality_gates.spec_completeness": 95
}
```

---

### Step 2: Planning Phase (plan.md + design artifacts)

**Update state**: `current_phase: "plan"`, `phases.plan.status: "running"`

**2a. Scaffold**

```bash
.logic-loom/scripts/bash/setup-plan.sh --json
```

Returns `FEATURE_SPEC`, `IMPL_PLAN`, `SPECS_DIR`, `BRANCH`, and copies
`.logic-loom/templates/plan-template.md` into `${IMPL_PLAN}`. Use absolute paths
from the repository root throughout.

The template copy is unconditional — it overwrites an existing `plan.md`. On a
`--resume` or `--phase plan` run where a plan already exists, skip this script
and read the existing `${IMPL_PLAN}` instead, or you will discard prior work.

**2b. Read inputs**

- `${FEATURE_SPEC}` — requirements, user stories, acceptance criteria,
  constraints, dependencies.
- `.logic-loom/memory/constitution.md` — focus on I (Library-First), II
  (Test-First), III (Contract-First), IX (Dependency Management).
- `.logic-loom/memory/amendments.md` if it exists — its named mandates are
  binding alongside the principles.

**2c. Execute the plan template**

The plan template is self-executing; follow its Execution Flow. It produces:

**Phase 0 — Research** → `${SPECS_DIR}/research.md`
Technical research per requirement; technology evaluation (2-3 options each, with
decision, rationale, alternatives); architecture patterns; dependency list with
version constraints and licenses; risk assessment. Every `[NEEDS CLARIFICATION]`
from spec.md must be resolved here or escalated to the user.

**Phase 1 — Design artifacts**
- `${SPECS_DIR}/data-model.md` — entities, fields, types, constraints,
  relationships, validation rules, state transitions, indexes.
- `${SPECS_DIR}/contracts/*.md` — one file per endpoint or interface, each with
  request schema, response schema, error cases, and examples.
- `${SPECS_DIR}/quickstart.md` — test scenarios derived from the user stories,
  covering happy path, error cases, and edge cases. These drive TDD in Step 3.

**Phase 2 — Execution planning**
Implementation roadmap and approach recorded in `${IMPL_PLAN}`. Task generation
itself is deferred to Step 3.

Fold any implementation preferences, technology choices, or constraints the user
passed as arguments into the plan's Technical Context section. Update the
template's Progress Tracking as each phase completes.

**2d. Verify artifacts exist before gating**

- [ ] `research.md` exists and is substantive
- [ ] `data-model.md` exists with entities defined
- [ ] `contracts/` exists and contains at least one contract file
- [ ] `quickstart.md` exists with test scenarios
- [ ] `${IMPL_PLAN}` documents the implementation approach
- [ ] No ERROR states left in Progress Tracking

**2e. Quality gate**

```bash
.logic-loom/scripts/bash/validate-plan.sh --file ${IMPL_PLAN} --json
```

Sixteen checks, all of them heading or keyword greps over `${IMPL_PLAN}` plus
four file-existence tests. Five are **required** (only these can produce exit 1):
file larger than 200 bytes, a `# ` title, an `## architecture` / `## system
design` / `## technical approach` heading, an `## tech stack` / `## technology` /
`## technologies` / `## tools` heading, and an `## implementation` / `## steps` /
`## plan` / `## approach` heading. The remaining eleven are **recommended**
(warnings only): the words `library|package|module|reusable`,
`test|testing|TDD|jest|vitest|playwright|cypress`, and
`contract|API|interface|schema` anywhere in the file; a data-model reference *or*
`data-model.md` on disk; a contracts reference *or* a `contracts/` directory; an
`## dependencies` / `## requirements` / `## prerequisites` heading; the words
`security|authentication|authorization|validation`; and the existence of
`research.md`, `data-model.md`, a non-empty `contracts/`, and `quickstart.md`.

It does **not** check for an overview, phases, a timeline, a risk section, or
deployment — earlier wording here claimed all five and none of them exist in the
script. Threshold: **85**.

**Read the exit code before the score**, exactly as in Step 1d. Exit **3** is a
script error — bad option, or a missing/unreadable `${IMPL_PLAN}` — and emits no
JSON, so there is no score and a missing score is not a zero.

```
IF exit code == 3:
  The gate NEVER RAN. Do not report a score, and do not infer one.
  Report the script's stderr verbatim and the ${IMPL_PLAN} path you passed.
  Fix the invocation (usually: setup-plan.sh was skipped, or the path is wrong)
  and re-run. Never continue to Step 2f on a 3.

IF exit code is 0, 1 or 2:
  The document WAS validated and the JSON carries a real score — act on it.
  IF score < 85:
    Report score and the failing checks
    Ask: "Refine or proceed?"
```

**2f. Domain re-detection**

```bash
.logic-loom/scripts/bash/detect-phase-domain.sh --file ${IMPL_PLAN} --json
```

Compare against Step 1e. New domains emerging during planning is expected and
additive — report the delta. A large divergence means the spec should be revisited.

**Update state on success**:
```json
{
  "phases.plan.status": "complete",
  "artifacts": {
    "plan.md": { "exists": true, "validated": true, "score": 88 },
    "research.md": { "exists": true },
    "data-model.md": { "exists": true },
    "contracts/": { "exists": true, "count": 3 },
    "quickstart.md": { "exists": true }
  },
  "quality_gates.plan_quality": 88
}
```

---

### Step 3: Tasks Phase (tasks.md)

**Update state**: `current_phase: "tasks"`, `phases.tasks.status: "running"`

**3a. Check prerequisites**

```bash
.logic-loom/scripts/bash/check-task-prerequisites.sh --json
```

Returns `FEATURE_DIR` and `AVAILABLE_DOCS`. `plan.md` is always required; the
other artifacts are conditional. Not every feature has every artifact — a CLI
tool may have no `contracts/`, a simple library may have no `data-model.md`.
Generate tasks from what is actually present.

**3b. Read the design artifacts**

`plan.md` (tech stack, approach, architecture patterns) always; then
`data-model.md` (entity names, relationships), every file under `contracts/`
(endpoint names, schemas, error cases), `research.md` (decisions, dependencies),
and `quickstart.md` (test scenarios, integration test requirements) if present.

**3c. Load the task template**

```
Read: .logic-loom/templates/tasks-template.md
```

It defines task numbering (`T001`…), categories, parallel markers `[P]`,
dependency tracking, and progress tracking.

**3d. Generate tasks by category**

```
Setup (always first)
  T001  Initialize project structure
  T002  Install and configure dependencies (from research.md)
  T003  Set up linting and formatting [P]
  T004  Configure build system [P]

Tests (test-first — these precede all implementation)
  For each contract file:        write contract test for <endpoint/interface> [P]
  For each quickstart scenario:  write integration test for <user story> [P]

Core implementation
  For each entity in data-model.md:  implement <Entity> model [P]
  For each contract:                 implement <endpoint/interface>
                                     (NOT [P] when several share one file)
  For each service/module in plan:   implement <Service> logic

Integration
  Database connection (if a database domain was detected)
  Middleware and error handling
  Logging and observability
  External service integration (if any)

Polish (last)
  Unit tests for edge cases [P]
  Performance optimization [P]
  Documentation generation [P]
  Code review and refactoring [P]
```

**3e. Apply the generation rules**

*Parallelism* — mark `[P]` only when tasks touch **different files**. Two tests in
separate files are parallel; two endpoints in the same routes file are not.

*Ordering* — Setup → Tests (TDD) → Models → Services → Endpoints → Integration →
Polish. No implementation task may precede its test task.

**3f. Write `${FEATURE_DIR}/tasks.md`**

Include feature name, total task count, parallel-execution guidance, and every
task in this shape:

```markdown
- [ ] T005: Write contract test for GET /users [P]
  - File: `tests/contracts/get-users.test.ts`
  - Dependencies: T001, T002
  - Parallel: Yes (with T006, T007)
```

**3g. Quality check — ADVISORY, not a gate**

```bash
.logic-loom/scripts/bash/validate-tasks.sh --file ${FEATURE_DIR}/tasks.md --json
```

Unlike Steps 1d and 2e there is **no threshold here, and exit 0/1/2 do not gate
anything**. Report the `score`; do not treat it as pass/fail.

One exit code still matters. Exit **3** is a script error — bad option, or a
missing/unreadable `tasks.md` — and emits no JSON at all:

```
IF exit code == 3:
  The lint NEVER RAN. There is no score; do not report one and do not infer one.
  Report the script's stderr verbatim and the path you passed, fix the
  invocation (usually: tasks.md was never written in 3f), and re-run.
  Do not substitute the checklist below for the lint — do both.

IF exit code is 0, 1 or 2:
  The lint ran. Report the score as advisory and continue to the checklist.
  A 1 means a required check failed (see below) — worth fixing, still not a gate.
```

Read what the script actually does before relying on it:

*Required (these four, and only these, can make it exit 1)* — the file is larger
than 100 bytes, has a `# ` title, contains at least one `- [ ]` / `- [x]` line,
and uses checkbox syntax.

*Recommended and optional (reported as warnings; exit stays 0)* — at least 3
tasks, a `[P]` marker somewhere, at most 50 tasks, at least one `##` section, at
least one incomplete task, and three **whole-file case-insensitive keyword
greps**: for `test`, for `contract|API spec|interface|schema`, and for
`depends on|dependency|prerequisite|after|before`.

Those last three are the thing to understand. They are presence-of-a-word checks
over the entire file. They do **not** parse task numbering, do not resolve
`File:` paths, do not read the dependency graph, and — despite what this step
used to claim — **do not check that tests are ordered before implementation at
all**. A tasks.md with the word "before" in an ordinary prose sentence satisfies
the dependency check. Nothing in the script can fail a file for bad TDD ordering.
(`--strict` exists, but it only downgrades to exit 2 when **more than four** of
the eight non-required checks warn — a bar a badly-ordered file clears easily, so
it is not a threshold worth passing.)

The substantive verification is therefore yours, by inspection, and it is the
real gate for this phase. The script is a lint that catches an empty or
malformed file:

- [ ] Every contract has a test task
- [ ] Every entity has an implementation task
- [ ] TDD ordering holds throughout — no implementation task precedes its test
- [ ] Every task names a concrete `File:` path
- [ ] Every `Dependencies:` reference points at a task id that exists
- [ ] `[P]` appears only on tasks that touch different files

If any of these fail, fix tasks.md before moving on. Never report the phase
complete on the script's exit code alone.

**Update state on success**:
```json
{
  "phases.tasks.status": "complete",
  "artifacts.tasks.md": { "exists": true, "task_count": 25 },
  "current_phase": "complete"
}
```

---

### Step 4: Completion Report

```bash
.logic-loom/scripts/bash/detect-phase-domain.sh --file ${FEATURE_DIR}/tasks.md --json
```

Then report:

```
✅ Unified Specification Workflow Complete

Branch: ${BRANCH}

📄 Artifacts Created:
  ✓ spec.md         (score: 95)
  ✓ plan.md         (score: 88)
  ✓ research.md
  ✓ data-model.md
  ✓ contracts/      (3 files)
  ✓ quickstart.md
  ✓ tasks.md        (25 tasks, 12 parallel)

Constitutional Compliance:
  ✓ Test-First: tests precede implementation
  ✓ Contract-First: contract tests for every contract
  ✓ Dependency-Ordered: setup → tests → core → integration → polish

🎯 Domains Detected: ${domains}
👥 Suggested Specialists: ${agents}
📋 Delegation: ${strategy}

Next: execute tasks.md in TDD order, or route to specialists via /build-team
or /fullstack-team.
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--branch <name>` | Specify branch name | current |
| `--resume` | Resume from last checkpoint | false |
| `--phase <phase>` | Start from a specific phase | spec |
| `--skip-validation` | Skip quality gates (report the skip loudly) | false |

## Error Handling

### Phase failure
```
IF any phase fails:
  Save current state to .workflow-state.json
  Report: "Workflow paused at ${phase}"
  Report: "Run '/specification --resume' to continue"
```

### State corruption
```
IF state file unreadable:
  Report: "State file corrupted"
  Ask: "Delete and restart? (y/n)"
```

## Constitutional Compliance

**Principle VI (Git Approval)** — branch creation happens only when the user asks
for it, via `create-new-feature.sh`. Never create or switch branches silently.

**Principle II (Test-First)** — `tasks.md` places every test task before the
implementation it covers. This is a gate, not a preference.

**Principle III (Contract-First)** — contracts under `contracts/` are written in
Step 2 and have failing tests in Step 3, before any implementation task.

**Principle VIII (Documentation Sync)** — all seven artifacts are generated in one
run and cross-reference each other, so none can drift ahead of the others.

## Troubleshooting

**`get-feature-paths.sh` / `setup-plan.sh` reports "Not on a feature branch"** —
the SDD pack requires a `###-name` branch. Ask the user whether to create one via
`create-new-feature.sh`.

**Spec validation score is low** — read the script's per-check output; it names
the missing sections. Ask the user for the missing information rather than
inventing it, then re-validate.

**No contracts generated** — re-read the spec for endpoints or component
interfaces. If the feature genuinely has no external surface, document the
module's public API as one contract instead of skipping the directory.

**No test tasks generated** — that means no contracts and no quickstart scenarios
were found. Fix Step 2 before continuing; shipping a tasks.md without tests
violates Principle II.

**Every task is sequential (no `[P]`)** — usually means file paths are missing or
too coarse. Test files are almost always parallelizable.

**Fewer than ~10 tasks** — the breakdown is too coarse. One task per contract, per
entity, per integration point; split testing from implementation.

## Validation

After execution, verify:
- [ ] All seven artifacts exist in the feature directory
- [ ] State file shows `"current_phase": "complete"`
- [ ] Quality gates passed, or the user explicitly approved an override
- [ ] Domain detection ran at spec, plan, and tasks
- [ ] Completion report displayed

## Related Skills

- `domain-detection` — standalone domain detection for an existing file
- `constitutional-compliance` — principle adherence validation
- `team-orchestration` — coordinates specialists when the feature spans 3+ domains
