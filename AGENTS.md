# LogicLoom Agent Registry

**Version**: 6.2.0
**Constitution**: v3.2.0 (16 Principles)
**Architecture**: Governance core + interchangeable workflow packs + Plugin-First + Skill-Based Delegation
**Total Agents**: 6
**Plugins**: 8

---

## Purpose

This file is the **Single Source of Truth (SSOT)** for agent information in LogicLoom. It provides quick reference for agent selection, capabilities, and usage patterns.

**Relationship to CLAUDE.md**:
- `CLAUDE.md` → Workflow rules, compliance protocols, delegation triggers
- `AGENTS.md` → Agent registry, capabilities, selection guidance

**Both files MUST be updated together** when agents are added/modified (see Tandem Update Rules below).

> **Plugin-First Architecture**: All agents live within their respective plugins at `plugins/<plugin>/agents/`. The framework root holds no agent definitions outside of plugins.

---

## Primary Agent (settings.json)

### constitutional-governance-agent (DEFAULT)

**Purpose**: Primary orchestration agent that serves as the **main thread entry point** for all Claude Code sessions. Carries the durable **governance core**, routes specialized work to domain briefs/skills, and relies on hooks to gate all git operations.

| Setting | Value |
|---------|-------|
| **Plugin** | `loom-governance` |
| **Model** | opus (required for governance decisions) |
| **Tools** | Full access (Read, Write, Edit, Bash, Grep, Glob, WebSearch, Task, TaskCreate, TaskUpdate, TaskList, TaskGet, Skill, ToolSearch) |
| **Location** | `plugins/loom-governance/agents/constitutional-governance-agent.md` |

**Configuration**: Hook-based orchestration (no custom `"agent"` field in settings.json). Constitutional governance is injected via the `UserPromptSubmit` preflight hook as `additionalContext`. Claude Code runs with its native capabilities, augmented by hook-injected guidance.

**Governance is hook-enforced, not ceremony-driven.** The mandatory per-message 4-step pre-flight recitation is no longer the default. `LOOM_GOVERNANCE_MODE` (env > `.logic-loom/config/governance.conf` > built-in default) selects:

- **`lean`** (default) — hooks enforce; no per-message compliance recitation. Correct for flagship Opus-class models that follow the governance section of CLAUDE.md directly.
- **`strict`** — hooks enforce **and** the explicit step-by-step compliance assist is re-injected on every message, as a graceful-degradation path for weaker / non-flagship models.

The **git-safety gate** runs as a `PreToolUse` hook and forces explicit approval on any git mutation regardless of mode (Principle VI). The dangerous-command guard and freeze-write-scope hooks likewise run independent of the mode.

**Key Responsibilities** (via hooks):
1. Inject constitutional governance context (lean) or full compliance assist (strict)
2. Detect domains and recommend domain briefs / specialist skills (Principle X)
3. Gate ALL git mutations via the git-safety-gate hook (Principle VI - CRITICAL)
4. Inject relevant project memory context
5. Run worktree-port-namespace, context-cap-warn, and freeze-write-scope hooks

---

## Agent Registry by Plugin

### loom-governance (1 agent)

| Agent | Purpose | Model |
|-------|---------|-------|
| **constitutional-governance-agent** | Primary entry point, governance enforcement | opus |

### loom-orchestrator (1 agent, 9 skills)

| Agent | Purpose | Model |
|-------|---------|-------|
| **team-synthesizer** | Merges multi-LLM parallel outputs; cross-model convergence analysis and tribunal confidence scoring | opus |

> **Note**: this plugin's orchestration is skill-based — `team-orchestration`, `multi-skill-workflow`, `plan-review`, and `retro` (9 skills total in this plugin).

### sdd-specification (0 agents — skill-based)

> Specification work is skill-based: `sdd-specification`, `sdd-planning`, `sdd-tasks`, `unified-specification` back the SDD-waterfall workflow pack.

### loom-creation (2 agents)

| Agent | Purpose | Model |
|-------|---------|-------|
| **prd-specialist** | PRD creation (auto-detects vision-driven vs blank-slate mode), product strategy | opus |
| **subagent-architect** | Agent creation, SDD compliance | inherit |

### loom-maintenance (1 agent)

| Agent | Purpose | Model |
|-------|---------|-------|
| **framework-sync-agent** | Framework updates from upstream | opus |

### loom-memory (1 agent)

| Agent | Purpose | Model |
|-------|---------|-------|
| **memory-context-agent** | Searches project memory and injects relevant context via preflight hook | haiku |

---

## Workflow Packs over a shared governance core

LogicLoom is a durable **governance core** (constitution, hooks, memory, plugin
chassis) plus a set of **interchangeable workflow packs** layered on top. No pack
is "primary" or "legacy" — pick the one that matches the problem shape:

| Pack | Entry points | Best for |
|------|--------------|----------|
| **Vision / swarm** | `vision.md` → `/swarm explore` + `/research` → `/create-prd` → `/plan-review` → `/swarm implement` → `/review-team` → `/retro` | Exploratory or surface-bearing work with a behavioral quality bar |
| **SDD waterfall** | `/specification` (spec → plan → tasks), `/build-team`, `/fullstack-team`, `/finalize` | Well-understood, contract-first features with a fully specified up-front design |

Both packs share the same governance core, plugin chassis, and distribution
machinery. Vision/swarm-internal gates (`vision.md`, `/plan-review`) belong to
that pack, not to the framework as a whole.

### Vision / swarm pack skills (loom-orchestrator)

The vision/swarm pack is built on the following orchestrator skills:

| Skill | Purpose | Backed By |
|-------|---------|-----------|
| `team-orchestration` | Multi-agent swarm coordination (explore + implement + generic) | loom-orchestrator |
| `multi-skill-workflow` | Cross-domain workflow composition | loom-orchestrator |
| `research` | Jury-on-demand multi-LLM research with tribunal cross-validation | loom-orchestrator |
| `plan-review` | CEO + Eng review verdict on `plan.md` before swarm implement | loom-orchestrator |
| `retro` | Post-feature learning capture — what worked, what to change | loom-orchestrator |

### `/swarm` modes (3)

The `/swarm` command now operates in three modes, selected via the first argument:

| Mode | Purpose | Worker scope |
|------|---------|--------------|
| `explore <topic>` | Read-only parallel investigations of existing surfaces; outputs land in `features/<feature>/exploration/` | Read-only, no writes |
| `implement [sprint-name]` | Per-sprint scope-bounded workers from `plan.md`; outputs land in `features/<feature>/sprints/NN-name/` | File-ownership DAG enforced by `freeze-write-scope` hook |
| `generic-legacy` | Pre-LogicLoom swarm behavior preserved for backward compatibility | Per legacy team-orchestration skill |

### `/review-team` (4 reviewers)

`/review-team` now runs **4 parallel reviewers** instead of 3:

1. **security-operations** — vulnerability + access control review
2. **performance-operations** — latency, caching, bottleneck review
3. **testing-operations** — coverage + edge case review
4. **behavioral-evaluator** — Playwright via chrome-devtools MCP, exercises the actual UI/API behavior

### `/research` (jury-on-demand)

`/research` now selects 1-3 judges based on the query type rather than always running the full tribunal. Pass `--judges all` to force the full 3-judge tribunal (Claude + OpenAI + Gemini).

---

## Domain-Brief Delegation

**Architecture**: Domain expertise lives in a lightweight **domain-brief
registry** inside the governance core — not in standalone specialist plugins.
The former seven `sdd-domain-*` plugins were deleted; their guidance was folded
into one brief per domain at
`plugins/loom-governance/domain-briefs/<domain>.md`.

### How It Works

A coordinator resolves the brief for a detected domain via `get_domain_brief()`
in `.logic-loom/scripts/bash/common.sh`, then injects it as the Task tool prompt
when dispatching a worker:

```
/build-team (or /swarm) → get_domain_brief "backend"
                        → reads plugins/loom-governance/domain-briefs/backend.md
                        → Task(prompt=brief + task, model=<tier>)
```

### Domain → Brief Mapping

| Domain | Keywords | Brief file |
|--------|----------|------------|
| **Frontend** | UI, React, CSS, component | `domain-briefs/frontend.md` |
| **Backend** | API, endpoint, server, service | `domain-briefs/backend.md` |
| **Database** | schema, SQL, migration, query | `domain-briefs/database.md` |
| **Testing** | test, TDD, coverage, QA | `domain-briefs/testing.md` |
| **Security** | auth, encryption, vulnerability | `domain-briefs/security.md` |
| **Performance** | optimize, cache, latency | `domain-briefs/performance.md` |
| **DevOps** | deploy, CI/CD, Docker | `domain-briefs/devops.md` |

All briefs resolve under `plugins/loom-governance/domain-briefs/`.

### Model Strategy

Model tiers resolve via `.logic-loom/config/models.conf` (Principle XIV) using
tier keywords, never pinned version strings:

- **Coordinator** (`architect` → opus): Orchestrates team pipeline, makes architectural decisions
- **Domain Workers** (`worker` → opus by default; switch to sonnet in models.conf for cost): Execute domain-specific tasks using the resolved domain brief
- **File Ownership**: Each worker is assigned file boundaries to prevent conflicts (enforced by `freeze-write-scope` hook)

---

## Non-Domain Agent/Skill Mapping

Quick reference for delegation based on task domain:

| Domain | Keywords | Delegate To | Type | Plugin | Pack |
|--------|----------|-------------|------|--------|------|
| **PRD/Product** | PRD, product, vision, personas | prd-specialist | agent | loom-creation | shared |
| **Specification** | spec, requirements, user story | sdd-specification skill | skill | sdd-specification | SDD waterfall |
| **Planning** | /plan, research, contracts | sdd-planning skill | skill | sdd-specification | SDD waterfall |
| **Tasks** | /tasks, task list, breakdown | sdd-tasks skill | skill | sdd-specification | SDD waterfall |
| **Plan review** | /plan-review, plan verdict | plan-review skill | skill | loom-orchestrator | vision/swarm |
| **Retro** | /retro, learnings | retro skill | skill | loom-orchestrator | vision/swarm |
| **Unified spec** | /specification | unified-specification skill | skill | sdd-specification | SDD waterfall |
| **Agent Creation** | create agent, new agent | subagent-architect | agent | loom-creation | shared |
| **Multi-Domain** | 2+ domains detected | team-orchestration skill | skill | loom-orchestrator | vision/swarm |
| **Swarm** | swarm, team, parallel agents | team-orchestration skill | skill | loom-orchestrator | vision/swarm |

---

## Slash Command → Agent/Skill Mapping

| Command | Delegate | Plugin | Purpose |
|---------|----------|--------|---------|
| `/create-prd` | prd-specialist | loom-creation | Create PRD (auto-detects vision-driven vs legacy) |
| `/swarm` | team-orchestration skill | loom-orchestrator | Multi-agent swarm (explore / implement / generic-legacy) |
| `/research` | team-synthesizer | loom-orchestrator | Jury-on-demand multi-LLM research |
| `/plan-review` | plan-review skill | loom-orchestrator | CEO + Eng verdict on plan.md |
| `/retro` | retro skill | loom-orchestrator | Post-feature learning capture |
| `/review-team` | 4 parallel reviewers | loom-orchestrator | security + quality + performance + behavioral evaluator |
| `/git-push` | - | loom-git | Complete git workflow (commit + push + PR) |
| `/code-review` | - | loom-git | PR-level review |
| `/specification` | unified-specification skill | sdd-specification | SDD waterfall pack — spec+plan+tasks |
| `/specify` | sdd-specification skill | sdd-specification | SDD waterfall pack — create feature specification |
| `/plan` | sdd-planning skill | sdd-specification | SDD waterfall pack — generate implementation plan |
| `/tasks` | sdd-tasks skill | sdd-specification | SDD waterfall pack — generate task list |
| `/build-team` | domain briefs + coordinator | loom-orchestrator | SDD waterfall pack — sequential architect→implementor→reviewer |
| `/fullstack-team` | domain briefs + coordinator | loom-orchestrator | SDD waterfall pack — parallel full-stack team |
| `/finalize` | - | loom-git | Pre-commit compliance validation (no git execution) |
| `/create-agent` | subagent-architect | loom-creation | Create new agent |
| `/create-plugin` | subagent-architect | loom-creation | Create new plugin |
| `/update-framework` | framework-sync-agent | loom-maintenance | Framework updates from upstream |
| `/initialize-project` | - | loom-maintenance | Post-PRD project customization |

---

## Agent Collaboration Workflows

### Vision / swarm pack pipeline

```
vision.md (human — pack-internal gate)
       ↓
/swarm explore + /research (fill gaps)
       ↓
prd-specialist (/create-prd — vision-driven mode)
       ↓
plan mode → plan.md (sprint-structured, file-ownership DAG)
       ↓
/plan-review (CEO + Eng verdict — pack-internal gate on swarm implement)
       ↓
/swarm implement <sprint> (per-sprint scope-bounded workers)
       ↓
test / fix loop
       ↓
/review-team (4 reviewers: security + quality + performance + behavioral)
       ↓
/git-push (commit + PR with explicit approval)
       ↓
/code-review (PR-level)
       ↓
/retro (capture learnings)
```

### SDD waterfall pack pipeline

```
prd-specialist (Phase 0: PRD)
       ↓
unified-specification skill (/specification)
  → sdd-specification skill → sdd-planning skill → sdd-tasks skill
       ↓
[Domain-brief workers for implementation]
       ↓
testing-brief worker (validation)
       ↓
security-brief worker (review)
       ↓
devops-brief worker (deployment)
```

### Multi-Agent Swarm (domain-brief based)

```
User: /swarm implement 02-api-surface
       ↓
Coordinator (Opus): reads plan.md sprint declaration, resolves domain briefs
       ↓
File-ownership DAG enforced by freeze-write-scope hook
       ↓
Phase 1: database-brief worker → schema
       ↓
Phase 2 (parallel):
  ├── backend-brief worker → API
  └── frontend-brief worker → UI
       ↓
Phase 3: testing-brief + behavioral-evaluator
       ↓
Coordinator merges results into features/<feature>/sprints/02-api-surface/
```

---

## Agent File Locations (Plugin-First)

```
plugins/
├── loom-governance/
│   ├── agents/
│   │   └── constitutional-governance-agent.md  (governance core entry)
│   └── domain-briefs/
│       ├── frontend.md  backend.md  database.md
│       ├── testing.md  security.md  performance.md
│       └── devops.md    (7 briefs — replaces the deleted sdd-domain-* plugins)
├── loom-orchestrator/
│   ├── agents/
│   │   └── team-synthesizer.md
│   └── skills/
│       ├── team-orchestration/SKILL.md
│       ├── multi-skill-workflow/SKILL.md
│       ├── research/SKILL.md
│       ├── plan-review/SKILL.md     (v6.0.0)
│       ├── retro/SKILL.md           (v6.0.0)
│       └── ... (9 skills total)
├── sdd-specification/skills/
│   ├── sdd-specification/SKILL.md
│   ├── sdd-planning/SKILL.md
│   ├── sdd-tasks/SKILL.md
│   └── unified-specification/SKILL.md
├── loom-creation/agents/
│   ├── prd-specialist.md
│   └── subagent-architect.md
├── loom-maintenance/agents/
│   └── framework-sync-agent.md
└── loom-memory/agents/
    └── memory-context-agent.md
```

---

## Constitutional Compliance

All agents enforce Constitution v3.2.0 (16 Principles), the durable governance core for every workflow pack:

### Immutable Principles (I-III)
- **I: Library-First** — Features as standalone libraries
- **II: Test-First** — TDD mandatory, >80% coverage
- **III: Contract-First** — Define contracts before implementation

### Critical Principles
- **VI: Git Approval** — NO autonomous git operations
- **X: Agent Delegation** — Specialized work → specialized agents/skills
- **XVI: Plugin-First** — All capabilities as discrete plugins

### Interchangeable workflow packs
- The vision/swarm and SDD-waterfall packs are **peers** over the
  shared governance core. Neither is privileged. `/specification`, validators,
  `/build-team`, `/fullstack-team`, and `/finalize` are all first-class pack
  entry points — pick the pack that fits the problem shape.

### All Agents Must
- Reference constitution in their system prompt
- Enforce TDD and library-first patterns
- Defer git mutations to the git-safety-gate hook (which forces approval)
- Maintain audit trails
- Follow file organization rules (Principle XV)
- Respect file-ownership DAG and `freeze-write-scope` hook during swarm work

---

## Quick Decision Tree

```
Starting a new feature? ────────────────────→ vision.md → /swarm explore → /create-prd
Reviewing a plan before implement? ────────→ /plan-review (skill, loom-orchestrator)
Running per-sprint workers? ───────────────→ /swarm implement <sprint>
Multi-LLM external research? ──────────────→ /research (jury-on-demand)
Multi-reviewer code/PR review? ────────────→ /review-team (4 reviewers)
Capturing post-feature learnings? ─────────→ /retro (skill, loom-orchestrator)
Building UI components? ───────────────────→ frontend domain brief (via swarm/team)
Designing APIs/services? ──────────────────→ backend domain brief (via swarm/team)
Working with database? ────────────────────→ database domain brief (via swarm/team)
Writing tests? ────────────────────────────→ testing domain brief (via swarm/team)
Security concerns? ────────────────────────→ security domain brief (via swarm/team)
Performance issues? ───────────────────────→ performance domain brief (via swarm/team)
Deploying/CI-CD? ──────────────────────────→ devops domain brief (via swarm/team)
Creating new agent? ───────────────────────→ subagent-architect (agent)
Contract-first, well-understood feature? ──→ /specification (unified) or /specify + /plan + /tasks
```

---

## Tandem Update Rules

**CRITICAL**: CLAUDE.md and AGENTS.md must be updated together.

### When to Update
- Agent added, deleted, or deprecated
- Agent capabilities/tools/model changed
- Plugin restructured
- Command → agent mapping changed
- Constitutional version changes
- Domain skills added or modified

### Update Protocol
1. Update agent/skill file in plugin
2. Update AGENTS.md registry
3. Update CLAUDE.md delegation rules
4. Run `sync-plugin-commands.sh sync` (if commands changed)
5. Run `constitutional-check.sh`
6. Run full test suite

---


**Registry Maintainer**: subagent-architect
**Review Cycle**: On any agent change
**Cross-Reference**: CLAUDE.md, `VISION.md`, `.logic-loom/memory/constitution.md`, `features/README.md`
