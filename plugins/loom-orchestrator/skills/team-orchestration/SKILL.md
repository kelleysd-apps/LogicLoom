---
name: team-orchestration
description: |
  Coordinates multi-agent team workflows on Claude Code's NATIVE primitives —
  the Task tool (subagents) and the /workflow tool (deterministic fan-out). It does
  not run its own agent runtime; it adds the LogicLoom value on top: domain-brief
  injection, governance gates, and result synthesis.
allowed-tools: Read, Write, Bash, Grep, Glob, Task
---

# Team Orchestration Skill

## Task Brief

You coordinate multi-agent team workflows. **You do not run a custom agent
runtime — you use Claude Code's native primitives:**

- **Task tool** — spawn subagents directly (sequential or in parallel; send
  multiple Task calls in one message for concurrency). This is the default.
- **`/workflow`** — when the fan-out is large or needs deterministic control
  flow (loops, conditionals, per-item pipelines, adversarial verify), author a
  workflow script instead of hand-spawning.
- **plan mode** — for drafting the plan before implementation.

There is **no separate process manager, no terminal-session runner, and no shared
swarm-state file**. Subagents run in their own isolated context; the **main
agent** collects their returned results and synthesizes. LogicLoom's job is the
layer on top, not the orchestration engine.

**What this skill adds (the durable value):**
- **Domain-brief injection** — for each detected domain, call
  `get_domain_brief <domain>` (`.logic-loom/scripts/bash/common.sh`; registry at
  `plugins/loom-governance/domain-briefs/<domain>.md`) and place its output in the
  worker's prompt. Routing is the model's native judgment (no RL scoring).
- **Governance** — subagents cannot run git (`subagent-git-guard`) or edit the
  governance surface (`protect-governance-files`); file-ownership is enforced by
  `freeze-write-scope` during `/swarm implement`.
- **Synthesis** — merge worker outputs in the main agent; for `/review-team` the
  behavioral evaluator's Functionality verdict is a hard gate.

**Constitutional constraints:** VI (git approval), X (delegate for isolation/
parallelism), XIV (flagship via `models.conf`), XVI (plugins).

**When invoked:** `/swarm`, `/build-team`, `/fullstack-team`, `/review-team`, or
any task requiring 2+ workers.

## Procedure

1. Decompose the request into worker tasks; detect domain(s).
2. For each worker, inject its `get_domain_brief <domain>` output into the prompt.
3. **Spawn** via the Task tool — sequential (each worker's output feeds the next)
   or parallel (multiple Task calls in one message). For large/looping fan-outs,
   author a `/workflow` script instead.
4. Assign file-ownership boundaries up front for parallel writers (the
   `freeze-write-scope` hook enforces them during `/swarm implement`).
5. Collect returned results in the main agent and **synthesize**; surface a brief
   cost note from the budget the user set.

## Domain-Brief Registry

The seven technical-domain briefs live in the governance core (the former
`sdd-domain-*` plugins were collapsed into this registry). Resolve via
`get_domain_brief <domain>`:

| Domain | Registry file |
|--------|---------------|
| Frontend | `plugins/loom-governance/domain-briefs/frontend.md` |
| Backend | `plugins/loom-governance/domain-briefs/backend.md` |
| Database | `plugins/loom-governance/domain-briefs/database.md` |
| Testing | `plugins/loom-governance/domain-briefs/testing.md` |
| Security | `plugins/loom-governance/domain-briefs/security.md` |
| Performance | `plugins/loom-governance/domain-briefs/performance.md` |
| DevOps | `plugins/loom-governance/domain-briefs/devops.md` |

## Execution patterns

- **Sequential**: Task → worker A → worker B → worker C → synthesize.
- **Parallel**: one message, N Task calls → collect all → synthesize.
- **Validation**: primary work → reviewer worker(s) → quality gate.
- **Large/looping**: author a `/workflow` (pipeline/parallel/loop-until-dry).
- **Gap-fill**: no capability → Anthropic Claude Code Plugin Marketplace / Docker
  MCP Toolkit, or `/create-plugin`.

## Quality gates

- **Pre**: request is clear; domains mapped to briefs; capability gaps identified.
- **Mid**: each worker's output meets its task; cross-worker consistency.
- **Post**: requirements met; solution complete; brief execution report.
- **Worker-completion contract** (mirrors `/swarm implement`): before any worker
  may report its task done, it MUST run its rubric's tests/build **in its own
  context** and paste the green evidence (the command(s) plus the exit-0 /
  passing summary) into its returned result. A red run forces a BOUNDED
  in-worker fix loop with an explicit cap of **3 attempts**; on cap exhaustion
  the worker returns failed with the diagnosis, never a false pass. This
  in-worker proof is the first gate; `/review-team` remains the INDEPENDENT
  second gate. It operationalizes **Principle II (Test-First)** at the worker
  boundary.

## Error handling

- **Capability not found**: Anthropic Marketplace / Docker MCP Toolkit, or `/create-plugin`.
- **Worker failure**: capture the error, retry or report to the user.
- **Dependency failure**: block dependents, report.
