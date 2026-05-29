---
name: swarm
description: Spawn coordinated multi-agent swarm. Three modes — explore (read-only investigation), implement (DAG-driven sprint execution), and generic (domain auto-detect with phased execution).
model: opus
---

# /swarm Command

**Mode dispatch**: the first positional argument selects the skill to load.

## Mode 1 — `/swarm explore <topic>`

Read-only multi-agent investigation. Used in LogicLoom Phase 1 + Phase 3 (codebase exploration before vision; implementation discovery before plan).

**SKILL ACTIVATION**: Read and execute `plugins/loom-orchestrator/skills/swarm-explore/SKILL.md`. Spawn 3 (default) parallel investigators with `allowed_tools: Read, Grep, Glob, WebFetch` only; synthesize findings to `features/<active-feature>/exploration/<topic-slug>.md` if `LOOM_ACTIVE_FEATURE` is set, else CWD `./exploration/`.

**Usage**: `/swarm explore "current theming code"`

## Mode 2 — `/swarm implement [sprint-name]`

DAG-driven sprint execution. Used in LogicLoom Phase 7 (after `/plan-review` passes).

**SKILL ACTIVATION**: Read and execute `plugins/loom-orchestrator/skills/swarm-implement/SKILL.md`. Reads `features/<active-feature>/plan.md` (DAG format per `.logic-loom/templates/plan-template.md`), validates file-ownership (no two tasks owning same path), topologically sorts within the sprint, dispatches workers with `LOOM_ACTIVE_FEATURE` / `LOOM_ACTIVE_TASK` env vars set so the freeze-write-scope hook (Stage 11) gates writes. Hard gate: refuses to proceed unless `features/<active-feature>/plan-review.md` contains `Overall verdict: go`.

**Usage**: `/swarm implement` (next unstarted sprint) or `/swarm implement 02-feature-x`

## Mode 3 — `/swarm <freeform>` (generic)

Domain auto-detect + phased execution with budget controls.

**SKILL ACTIVATION**: Read and execute `plugins/loom-orchestrator/skills/team-orchestration/SKILL.md` in swarm mode. Analyzes task for domain keywords, injects the matching domain briefs via `get_domain_brief <domain>` from `.logic-loom/scripts/bash/common.sh` (registry at `plugins/loom-governance/domain-briefs/<domain>.md`), plans execution phases, spawns parallel workers per phase with budget tracking.

**Usage**: `/swarm "Build auth with React UI, Express API, PostgreSQL"`

## Mode detection rule

- First arg `== "explore"` → Mode 1
- First arg `== "implement"` → Mode 2
- Anything else (including no arg or freeform string) → Mode 3 (generic)
