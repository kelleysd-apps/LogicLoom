---
name: SDD Framework Architectural Baseline (v5.0.0)
description: Frozen architectural snapshot of sdd-agentic-framework as of 2026-04-28, captured before planned major alterations. Use as the reference of "what was here originally" when comparing against altered state. Verify any specific path/version claim against the live repo before acting on it — this is a point-in-time baseline, not authoritative current state.
type: project
originSessionId: fa3efdd7-669a-41f1-a450-2f778bb4afde
---
# SDD Agentic Framework — Architectural Baseline

**Captured**: 2026-04-28
**Framework version**: v5.0.0
**Constitution version**: v3.0.0 (16 principles, ratified 2026-01-13)
**Architecture**: Skill-Based Delegation v5.0 + Plugin-First v4.1 + Modular Context v2.0

> **Why this exists**: The user is about to make significant alterations to this project. This document is the "before" snapshot. When recalling, treat any specific file path, line number, or version as point-in-time — verify against the live repo before acting on it. The high-level *shape* (three-layer separation, plugin-first, hook-based governance) is the durable part.

---

## 1. Three-Layer Separation

The repo is organized into three top-level directories with distinct ownership and mutability:

| Layer | Path | Purpose | Mutability | Modification Frequency |
|---|---|---|---|---|
| **Specification & execution** | `.specify/` | Constitution, config, scripts, libraries, templates | High in `memory/` (constitutional), medium elsewhere | Low — config changes need ratification |
| **Harness integration** | `.claude/` | Slash commands, context modules, hooks, settings, schemas | Medium — hooks are critical, commands evolve | Medium — updated with features |
| **Capabilities** | `plugins/` | Discrete installable plugins (skills, agents, plugin-local hooks/scripts) | Low — plugins are pluggable except `sdd-governance` | High — constant skill/agent dev |

**Data flow**: User message → `.claude/hooks/...governance-preflight.sh` (or plugin hook) → reads `.specify/memory/constitution.md` → routes to a `plugins/*/skills/<skill>/SKILL.md` Task Brief → injection.

**Other top-level directories**:
- `src/sdd/` — Python framework library (agents, context, feedback, metrics, refinement, validation)
- `tests/` — 1,322+ tests across 27 suites (contract, integration, unit, validation, fixtures)
- `.docs/` — internal docs (policies, guides, architecture, governance, agents, plans, reports, reviews, design, troubleshooting)
- `specs/` — per-feature directories
- `mcp-servers/sdd-marketplace/` — MCP server exposing marketplace tools
- `.github/` — CI/CD + PR templates

**Root-level files**: `CLAUDE.md` (harness preflight contract), `AGENTS.md` (SSOT for agent registry), `README.md`, `START_HERE.md`, `CHANGELOG.md`, `package.json` (Jest, 80% coverage), `pyproject.toml`, `requirements.txt`, `.mcp.json`, `.env.example`, `init-project.sh`, `.sdd-sync-ref` (upstream sync pointer).

---

## 2. Constitutional Governance (`.specify/memory/`)

### Constitution (`constitution.md`, v3.0.0)

16 principles. Three are **immutable**, two flagged **CRITICAL**:

| # | Principle | Status |
|---|---|---|
| I | Library-First Architecture | Immutable |
| II | Test-First Development (TDD, ≥80% coverage) | **Immutable, CRITICAL** |
| III | Contract-First Design | Immutable |
| IV | Idempotent Operations | Standard |
| V | Progressive Enhancement | Standard |
| VI | Git Operation Approval (NO autonomous git) | **CRITICAL** |
| VII | Observability (structured logging) | Standard |
| VIII | Documentation Synchronization | Standard |
| IX | Dependency Management | Standard |
| X | Skills-First Delegation Protocol | **CRITICAL** |
| XI | Input Validation & Output Sanitization | Standard |
| XII | Design System Compliance | Standard |
| XIII | Feature Access Control (dual-layer) | Standard |
| XIV | AI Model Selection (Opus 4.6 default) | Standard |
| XV | File Organization | Standard |
| XVI | Plugin-First Architecture | Standard |

### Change-management process (`constitution_update_checklist.md`)

Required propagation when amending the constitution: bump version, update CLAUDE.md and AGENTS.md **as tandem files**, update each agent context file in `plugins/*/agents/**`, add a check to `constitutional-check.sh` for any new principle (flagged CRITICAL in the checklist), update templates, update `agent-collaboration-triggers.md`, update slash commands, run `constitutional-check.sh` + `sanitization-audit.sh` + `/specify`/`/plan`/`/tasks` smoke test. Sign-off: Author / Technical Reviewer / Framework Maintainer.

### Domain → skill mapping (`agent-collaboration-triggers.md`)

Authoritative router for Principle X. Decision tree: 0 domains → direct execution; 1 domain → that domain's skill; ≥2 domains → `team-orchestration`. Includes a JSON `handoff` schema for cross-skill context transfer.

### Enforcement layers

1. **`.claude/hooks/user-prompt-submit/governance-preflight.sh`** — local fallback hook; reads stdin JSON, detects slash commands and domains, queries `plugins/sdd-memory/scripts/memory-search.sh` (3s timeout), injects `additionalContext` JSON. Never blocks user input (FALLBACK heredoc on error).
2. **`plugins/sdd-governance/hooks/scripts/`** — active plugin hooks registered in `plugins/sdd-governance/hooks/hooks.json`:
   - `governance-preflight.cjs` on `UserPromptSubmit` (4-step compliance check)
   - `git-safety-gate.sh` on `PreToolUse:Bash` (regex matches git verbs `push|pull|commit|merge|rebase|checkout|branch -[dD]|reset|tag|stash|cherry-pick|revert|am|format-patch`, returns `result: warn` requiring approval — Principle VI)
   - `rl-metrics-capture.sh` on `PostToolUse` (EMA-updates plugin `rl_metrics` with learning rate 0.1)
3. **`.claude/hooks/guard-dangerous-commands.sh`** — sources `.specify/lib/policy.sh`; exit 2 = blocked, 3 = approval required, 4 = warn.
4. **`.specify/scripts/bash/constitutional-check.sh`** — walks all 16 principles with `[N/16]` log markers, fails any script issuing git verbs without `request_git_approval` or a `read -p` prompt (lines ~184–207), checks plugin manifests exist for Principle XVI.
5. **`plugins/sdd-orchestrator-hook/`** — declares one skill `orchestration-guidance` and config `domains.conf` parsed by the preflight hook as `keyword=delegate` pairs.
6. **`plugins/sdd-memory/`** — declares `context-injection` skill, `memory-context-agent` (haiku, hook-budget-friendly), four pluggable backends (keyword, BM25, vector, hybrid).

---

## 3. Plugin Registry (16 plugins, v4.1 architecture)

| Plugin | Category | Version | Skills | Agents | Commands | Dependencies | Status |
|---|---|---|---|---|---|---|---|
| `sdd-governance` | governance | 1.0.0 | 6 | 1 | 0 | none | **PROTECTED, required, non-disableable** |
| `sdd-orchestrator` | orchestration | 3.0.0 | 4 | 1 | 5 | sdd-governance | active |
| `sdd-orchestrator-hook` | orchestration | 1.0.0 | 1 | 0 | 0 | none | active |
| `sdd-memory` | orchestration | 2.0.0 | 1 | 1 | 0 | none | active |
| `sdd-dev-loop` | core | 0.1.0 | 1 | 0 | 1 | sdd-governance, sdd-specification, sdd-git | active |
| `sdd-git` | core | 1.0.0 | 2 | 0 | 2 | sdd-governance | active |
| `sdd-creation` | core | 2.0.0 | 5 | 2 | 4 | sdd-governance | active |
| `sdd-specification` | core | 2.0.0 | 1 | 0 | 1 | sdd-governance | active |
| `sdd-maintenance` | core | 1.0.0 | 3 | 1 | 2 | sdd-governance | active |
| `sdd-domain-backend` | domain | 1.0.0 | 4 | 0 | 0 | sdd-governance | active |
| `sdd-domain-frontend` | domain | 1.0.0 | 1 | 0 | 0 | sdd-governance | active |
| `sdd-domain-database` | domain | 1.0.0 | 2 | 0 | 0 | sdd-governance | active |
| `sdd-domain-devops` | domain | 1.0.0 | 2 | 0 | 0 | sdd-governance | active |
| `sdd-domain-performance` | domain | 1.0.0 | 1 | 0 | 0 | sdd-governance | active |
| `sdd-domain-security` | domain | 1.0.0 | 1 | 0 | 0 | sdd-governance | active |
| `sdd-domain-testing` | domain | 1.0.0 | 1 | 0 | 0 | sdd-governance | active |

**Totals**: 16 plugins, ~35 skills, 6 agents (per AGENTS.md), 15 slash commands.

### Dependency graph

`sdd-governance` is the root. All non-governance plugins depend on it except `sdd-memory` and `sdd-orchestrator-hook` (which run in the preflight pipeline and can't depend on the very plugin they preflight). `sdd-dev-loop` additionally depends on `sdd-specification` and `sdd-git`.

### Standard plugin layout

```
plugins/<name>/
├── .claude-plugin/plugin.json   # manifest
├── skills/<skill>/SKILL.md      # YAML frontmatter + body
├── agents/<agent>.md            # YAML frontmatter + body
├── commands/<command>.md        # bridge source for /command
├── hooks/hooks.json + scripts/  # event hooks (only governance + orchestrator)
└── scripts/                     # plugin-local utilities
```

### Plugin manifest schema

```json
{
  "name": "sdd-plugin-name",
  "version": "1.0.0",
  "category": "core|domain|governance|orchestration",
  "description": "...",
  "dependencies": ["sdd-governance"],
  "required": false,
  "protected": false,
  "agents":   { "count": N, "list": [...] },
  "skills":   { "count": N, "list": [...] },
  "commands": { "count": N, "list": [...] },
  "rl_metrics": {
    "success_rate": 0.5,
    "selection_weight": 0.5,
    "invocation_count": 0,
    "avg_tokens": 0,
    "last_updated": "..."
  }
}
```

`required: true, protected: true` is set only on `sdd-governance`.

### Plugin command bridge

`.specify/scripts/bash/sync-plugin-commands.sh sync` discovers `plugins/*/commands/*.md` and generates wrapper stubs in `.claude/commands/` (each stub is a one-liner pointing at the plugin source — auto-regenerated). A `.bridge-manifest.json` tracks bridged vs static. Static commands are never overwritten.

### Marketplace MCP server (`mcp-servers/sdd-marketplace/`)

Six tools: `marketplace-list`, `marketplace-validate`, `marketplace-search`, `marketplace-install`, `marketplace-update`, `marketplace-publish`. Registry at `registry/registry.json`. Install uses git sparse checkout from `sdd-plugins-marketplace` repo or local path.

---

## 4. Skill & Agent System

### Six agents (per `AGENTS.md`)

| Agent | Plugin | Specialty | Model |
|---|---|---|---|
| `constitutional-governance-agent` | sdd-governance | Pre-flight + git gating (primary entry point) | opus |
| `team-synthesizer` | sdd-orchestrator | Merges multi-LLM tribunal outputs | opus |
| `prd-specialist` | sdd-creation | PRD authoring | opus |
| `subagent-architect` | sdd-creation | Agent/plugin scaffolding | inherit |
| `framework-sync-agent` | sdd-maintenance | Upstream sync | opus |
| `memory-context-agent` | sdd-memory | Tiered memory retrieval (hook-budget) | haiku |

(14 prior domain agents were converted to skills in v5.0 — domain agents were stateless prompt wrappers; skills carry the same Task Brief without per-agent overhead and gain RL weighting + composability.)

### SKILL.md structure

```yaml
---
name: <kebab-case>
version: <semver>
description: ...
allowed-tools: Read, Write, Bash
triggers: ["keyword1", "keyword2"]
category: domain | orchestration | sdd-workflow
constitutional_principles: [VI, X]
rl_metrics: { success_rate, selection_weight, invocation_count, avg_tokens }
---
```

Body convention: `# Title` → `## Overview` → `## When to Use` → `## Task Brief` (load-bearing — extracted as the prompt for spawned Task workers; includes role, expertise bullets, quality standards, file ownership globs) → `## Procedure` → `## Configuration`.

### Agent .md structure

```yaml
---
name: <kebab-case>
description: Use PROACTIVELY for ...
tools: Read, Write, Edit, MultiEdit, Bash, Grep, Glob, TaskCreate
model: opus | inherit | haiku    # Principle XIV
---
```

Body: `## Constitutional Adherence` → `## Critical Mandates` → `## Core Responsibilities` → workflow steps. Tool restrictions are explicit per agent.

### Skill vs Agent — when each is used

- **Agent**: persistent persona spawned via Task tool with its own context window and tool allowlist. Used for autonomous multi-step execution with its own scratchpad (`subagent-architect`, `prd-specialist`).
- **Skill**: procedural template invoked via Skill tool inside current context, OR extracted as a Task Brief and injected into a fresh worker. Used for repeatable workflows. Gains RL weighting and composition (`composes:` field).

### Slash command resolution

`.claude/commands/*.md` are bridge stubs. Example: `/specification` → `.claude/commands/specification.md` (stub) → `plugins/sdd-specification/commands/specification.md` (real source) → invokes the `unified-specification` skill which orchestrates phases via Skill tool calls.

### 7 sdd-domain-* plugins and primary skills

| Plugin | Primary Skill | Specialty |
|---|---|---|
| sdd-domain-frontend | frontend-operations | UI/React/CSS/components |
| sdd-domain-backend | backend-operations (+ api-design, service-architecture, system-design) | APIs/services |
| sdd-domain-database | database-operations (+ schema-design) | Schema/SQL/RLS |
| sdd-domain-testing | testing-operations | TDD/E2E/coverage |
| sdd-domain-security | security-operations | Auth/encryption/audit |
| sdd-domain-performance | performance-operations | Caching/latency |
| sdd-domain-devops | devops-operations (+ monitoring) | CI/CD/Docker |

---

## 5. SDD Workflow Lifecycle

```
USER IDEA
   │
   ▼
[/create-prd] ─────► .docs/prd/prd.md (Single Source of Truth)
   │
   ▼
[/initialize-project] ─► customizes constitution, agents, MCPs based on PRD
   │
   ▼
[/specification "<feature>"]
   │   Phase 1: spec.md (validate ≥0.90)
   │   Phase 2: plan.md + research.md + data-model.md + contracts/ + quickstart.md (≥0.85)
   │   Phase 3: tasks.md (TDD ordering check)
   │   State: specs/<branch>/.workflow-state.json (resumable)
   │
   ▼
IMPLEMENTATION (specialists per Principle X — /swarm | /build-team | /fullstack-team | /research)
   │
   ▼
[/finalize] ─────► constitutional-check + sanitization-audit, NO git ops
   │
   ▼
[/git-push] ─────► stage → commit → push → PR (4 approval gates)
```

### `/specification` (plugin: sdd-specification, skill: unified-specification)

Replaces legacy `/specify → /plan → /tasks`. Three quality-gated phases driven by `.specify/scripts/bash/validate-{spec,plan,tasks}.sh`. Up to 3 retry refinements per phase. Domain detection via `detect-phase-domain.sh` reports specialist suggestions on completion.

### Quality gates (`.specify/config/refinement.conf`)

| Gate | Threshold |
|---|---|
| `SPEC_COMPLETENESS_THRESHOLD` | 0.90 |
| `PLAN_QUALITY_THRESHOLD` | 0.85 |
| `CODE_QUALITY_THRESHOLD` | 0.80 |
| `TEST_COVERAGE_THRESHOLD` | 0.80 (matches Principle II) |
| `MAX_REFINEMENT_ROUNDS` | 20 |
| `EARLY_STOP_THRESHOLD` | 0.95 |
| `MAX_DEBUG_ITERATIONS` | 5 |
| `CIRCUIT_BREAKER_THRESHOLD` | 0.50 (disables agent above 50% failure) |
| Verification weights | 0.25 / 0.30 / 0.25 / 0.20 (completeness / constitutional / coverage / alignment) |

State persisted to `.docs/agents/shared/refinement-state/`.

### `specs/###-feature-name/` artifact order

1. `spec.md` (Phase 1)
2. `research.md`, `data-model.md`, `contracts/`, `quickstart.md`, `plan.md` (Phase 2 — `plan.md` last)
3. `tasks.md` (Phase 3, TDD-ordered, project SSOT)
4. `.workflow-state.json` (resumability)

### `/finalize` (plugin: sdd-git)

Reports only — never executes git (Principle VI). Runs constitutional-check, sanitization-audit, full test suite, doc-sync validation. Outputs scorecard + suggested manual git commands.

### `/git-push` (plugin: sdd-git)

8-stage flow with **4 approval checkpoints**: review → prepare msg → **APPROVE** → commit → **APPROVE** → push (rebase on non-FF) → **APPROVE** → `gh pr create` → check merge → conflict resolution (max 5 iterations, backup branch) → final report.

### Multi-agent orchestration commands

| Command | Skill | Mode | When |
|---|---|---|---|
| `/swarm` | team-orchestration | Adaptive parallel/sequential, budget-controlled | Complex multi-domain |
| `/research` | tribunal (Claude+OpenAI+Gemini) | 3 parallel + voting | Cross-validated research |
| `/build-team` | team-orchestration | Sequential architect → implementor → reviewer | Single-domain structured handoff |
| `/fullstack-team` | full-stack-feature | Parallel FE+BE+DB with DB→BE→FE dependency | Cross-layer features |
| `/review-team` | team-orchestration | Parallel security + quality + performance | Pre-merge PR review |

### `/update-framework` (plugin: sdd-maintenance)

Upstream-history-only, additive-only, proposal-based. Reads `.sdd-sync-ref`, diffs `sync-ref..upstream/main` (NEVER `downstream..upstream`), surfaces each change as a discrete proposal. User selectively adopts; no overwriting of customized files. Designed because the framework is cloned to start projects, then customized.

---

## 6. Scripts, Hooks & Automation

### `.specify/scripts/bash/` — workflow scripts

`common.sh` (sourced helpers + git approval), `constitutional-check.sh` (16-principle validator), `sanitization-audit.sh`, `create-new-feature.sh`, `setup-plan.sh`, `check-task-prerequisites.sh`, `validate-{spec,plan,tasks}.sh` (DS-STAR verifiers), `finalize-feature.sh`, `create-{prd,agent,skill-command,agent-command}.sh`, `migrate-agent-to-skill.sh`, `sync-plugin-commands.sh` (bridge), `load-context.sh` (TTL-cached module loader), `detect-phase-domain.sh`, `analyze-logs.sh` / `cleanup-governance-logs.sh` / `governance-metrics.sh`, `legacy-pattern-report.sh`, `skill-coverage-audit.sh`, `sanitize-for-template.sh`, `update-agent-context.sh`, `verify-mcp-toolkit.sh`, `debug-hook.sh`, `get-feature-paths.sh`.

### `.specify/scripts/bash/rl/` — RL feedback

`collect-feedback.sh` (append outcome), `update-skill-weight.sh` (EMA, lr=0.1), `sync-metrics.sh` (propagate to plugin manifests), `dashboard.sh`, `select-skill.sh` (weighted picker), `load-skill-progressive.sh` (token-efficient partial loader), `credit-assignment.sh` (per-LLM-request attribution), `grpo-optimizer.sh` (deferred FR-602, policy gradient).

**Algorithm**: `success_rate = 0.9 * old + 0.1 * (1 if success else 0)`; `selection_weight = clamp(success_rate, 0.1, 1.0)`. Performance log at `.docs/rl-metrics/skill-performance.json`; weights live in each `plugins/*/plugin.json`.

### `.specify/lib/` — shared libraries

`logging.sh` (Principle VII structured logging), `parallel.sh` (parallel agent execution helpers, 2-3× speedup for 3+ agents), `policy.sh` (tool restriction validator), `json-parse.cjs` (Node JSON helper for bash), `routing/legacy-blocker.sh` (blocks direct agent invocations in skills-first mode).

### `.specify/scripts/python/`

`ds_star_integration.py` (DS-STAR refinement loop glue), `auto_debug_wrapper.py` (T044 auto-debug, <30s target).

### Hooks summary

| Script | Event | Role |
|---|---|---|
| `plugins/sdd-governance/hooks/scripts/governance-preflight.cjs` | UserPromptSubmit | Active 4-step compliance check |
| `plugins/sdd-governance/hooks/scripts/git-safety-gate.sh` | PreToolUse:Bash | Warns on git commands (Principle VI) |
| `plugins/sdd-governance/hooks/scripts/rl-metrics-capture.sh` | PostToolUse | Updates `rl_metrics` in plugin manifests |
| `plugins/sdd-orchestrator/hooks/scripts/agent-stop-notification.sh` | Stop, SubagentStop | Swarm coordination via tmux |
| `.claude/hooks/user-prompt-submit/governance-preflight.sh` | UserPromptSubmit (local fallback) | Domain detection + memory injection, never blocks |
| `.claude/hooks/guard-dangerous-commands.sh` | PreToolUse | Sources `policy.sh`; exit 2/3/4 = block/approve/warn |

### End-to-end flow examples

**`/specification`**: hook fires → injects context → skill calls `create-new-feature.sh` → DS-STAR refinement (`ds_star_integration.py`) up to 20 rounds → `setup-plan.sh` → `validate-plan.sh` → `check-task-prerequisites.sh` → `validate-tasks.sh`. PostToolUse fires `rl-metrics-capture.sh` after each tool call.

**Pre-commit**: `/finalize` runs validators (no git) → user issues git command → `git-safety-gate.sh` warns → `guard-dangerous-commands.sh` checks deny list → if approved, user manually commits → `rl-metrics-capture.sh` records outcome.

**RL feedback loop**: skill completes → `collect-feedback.sh <skill> success|failure [tokens]` → appends to `.docs/rl-metrics/skill-performance.json` → `update-skill-weight.sh` applies EMA → `credit-assignment.sh` distributes across contributors → `sync-metrics.sh` propagates to `plugins/*/plugin.json` → next routing decision uses fresh weights via `select-skill.sh`.

---

## 7. Modular Context Loading (`.claude/context/` v2.0)

37% token reduction by lazy-loading. Modules:
- `core.md` — pre-flight, MCP toolkit, constitution ref (often redundant with CLAUDE.md)
- `agents.md` — agent registry, delegation
- `skills.md` — skill docs, slash commands
- `workflows.md` — SDD lifecycle
- `governance.md` — constitutional principles, git ops, compliance

Load via `./.specify/scripts/bash/load-context.sh load <name>` or analyze a task with `load-context.sh analyze "task description"` (auto-loads relevant modules).

---

## 8. AI Model Selection (Principle XIV)

| Model | ID | Default Use |
|---|---|---|
| Opus 4.6 | `claude-opus-4-6` | All specialized agents (default) |
| Sonnet 4.5 | `claude-sonnet-4-5-20250929` | Fallback, high-volume |
| Haiku 4.5 | `claude-haiku-4-5-20251001` | Quick tasks, hooks (memory agent) |

---

## 9. What's Likely To Change vs What Should Be Stable

This is editorial — based on architectural shape, not specific user instructions:

**Highly stable (likely preserved across alterations)**:
- The three-layer separation (`.specify/` / `.claude/` / `plugins/`)
- The 16 constitutional principles (immutable I-III; CRITICAL VI, X)
- Plugin-First as a structural pattern
- The hook-based governance injection model

**Mutable / candidates for alteration**:
- Plugin count and composition
- Skill/agent inventory
- Slash command surface
- RL algorithm specifics (GRPO upgrade is already deferred)
- Quality thresholds in `refinement.conf`
- DS-STAR integration

When the user says "we're changing X," locate X against the layers above first. If X touches `.specify/memory/constitution.md`, the change is constitutional and follows the formal amendment process in `constitution_update_checklist.md`. If X touches `plugins/sdd-governance/`, that plugin is protected and changes need careful review. Anything else is freer to alter.

---

## 10. Verification Checklist (when recalling this memory later)

Before acting on specifics from this baseline, spot-check:
- `cat .sdd-sync-ref` — has the upstream pointer moved?
- `ls plugins/` — has the plugin set changed?
- `head -20 .specify/memory/constitution.md` — is it still v3.0.0?
- `cat package.json | grep version` — framework version?
- `git log --oneline -10` — recent activity since baseline?

If any of these have shifted significantly, treat the corresponding section here as outdated and re-read the source.
