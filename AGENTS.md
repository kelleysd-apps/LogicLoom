# LogicLoom Agent Registry

**Version**: 6.0.0
**Last Updated**: 2026-05-27
**Constitution**: v3.0.0 (16 Principles)
**Architecture**: LogicLoom workflow + Plugin-First + Skill-Based Delegation
**Total Agents**: 6
**Plugins**: 16

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

**Purpose**: Primary orchestration agent that serves as the **main thread entry point** for all Claude Code sessions. Enforces the 4-step pre-flight compliance protocol on every user message, routes specialized work to domain agents/skills, and gates all git operations.

| Setting | Value |
|---------|-------|
| **Plugin** | `sdd-governance` |
| **Model** | opus (required for governance decisions) |
| **Tools** | Full access (Read, Write, Edit, Bash, Grep, Glob, WebSearch, Task, TaskCreate, TaskUpdate, TaskList, TaskGet, Skill, ToolSearch) |
| **Location** | `plugins/sdd-governance/agents/constitutional-governance-agent.md` |

**Configuration**: Hook-based orchestration (no custom `"agent"` field in settings.json). Constitutional governance is injected via the `UserPromptSubmit` preflight hook as `additionalContext`. Claude Code runs with its native capabilities, augmented by hook-injected guidance.

**Key Responsibilities** (via hook injection):
1. Inject constitutional governance reminder on EVERY user message
2. Detect domains and recommend specialist skills or agents (Principle X)
3. Gate ALL git operations (Principle VI - CRITICAL)
4. Inject relevant project memory context
5. Enforce worktree-port-namespace, context-cap-warn, and freeze-write-scope hooks

---

## Agent Registry by Plugin

### sdd-governance (1 agent)

| Agent | Purpose | Model |
|-------|---------|-------|
| **constitutional-governance-agent** | Primary entry point, governance enforcement | opus |

### sdd-orchestrator (1 agent, 9 skills)

| Agent | Purpose | Model |
|-------|---------|-------|
| **team-synthesizer** | Merges multi-LLM parallel outputs; cross-model convergence analysis and tribunal confidence scoring | opus |

> **Note**: task-orchestrator, swarm-coordinator, and workflow-coordinator were converted to enhanced skills (`team-orchestration`, `multi-skill-workflow`) with Task Brief sections in v5.0.0. v6.0.0 added `plan-review` and `retro` skills for the LogicLoom workflow (now 9 skills total in this plugin).

### sdd-specification (0 agents — skill-based)

> All 4 specification agents (specification-agent, planning-agent, tasks-agent, specification-orchestrator) were converted to enhanced skills with Task Brief sections in v5.0.0. Skills: `sdd-specification`, `sdd-planning`, `sdd-tasks`, `unified-specification`. The `/specification` waterfall remains available as the legacy SDD path.

### sdd-creation (2 agents)

| Agent | Purpose | Model |
|-------|---------|-------|
| **prd-specialist** | PRD creation (auto-detects vision-driven vs legacy mode), product strategy | opus |
| **subagent-architect** | Agent creation, SDD compliance | inherit |

### sdd-maintenance (1 agent)

| Agent | Purpose | Model |
|-------|---------|-------|
| **framework-sync-agent** | Framework updates from upstream | opus |

### sdd-memory (1 agent)

| Agent | Purpose | Model |
|-------|---------|-------|
| **memory-context-agent** | Searches project memory and injects relevant context via preflight hook | haiku |

### sdd-dev-loop (0 agents — skill-based)

> All 4 dev-loop agents (dev-loop-orchestrator, debug-analyst, quality-assessor, tribunal-judge) were removed. The `core-loop` skill handles all dev-loop functionality directly.

---

## LogicLoom Workflow Skills (sdd-orchestrator)

The LogicLoom workflow is built on the following orchestrator skills:

| Skill | Purpose | Backed By |
|-------|---------|-----------|
| `team-orchestration` | Multi-agent swarm coordination (explore + implement + generic) | sdd-orchestrator |
| `multi-skill-workflow` | Cross-domain workflow composition | sdd-orchestrator |
| `research` | Jury-on-demand multi-LLM research with tribunal cross-validation | sdd-orchestrator |
| `plan-review` | CEO + Eng review verdict on `plan.md` before swarm implement | sdd-orchestrator |
| `retro` | Post-feature learning capture — what worked, what to change | sdd-orchestrator |

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

`/research` now selects 1-3 judges based on the query type rather than always running the full tribunal. Pass `--judges all` to force the legacy 3-judge behavior (Claude + OpenAI + Gemini).

---

## Skill-Based Domain Delegation

**Architecture Change (v4.0.0)**: Domain specialist agents were replaced by enhanced plugin SKILL.md files. Instead of custom agent definitions, domain expertise lives in plugin skills that are injected as Task tool briefs when spawning team workers.

### How It Works

```
BEFORE (v3.0):
  /build-team → reads agents/backend-architect.md → Task(prompt=agent_prompt)

AFTER (v4.0+):
  /build-team → extract_skill_brief("sdd-domain-backend", "backend-operations")
              → Task(prompt=skill_brief + task, model=sonnet)
```

### Domain → Skill Mapping

| Domain | Keywords | Plugin | Skill |
|--------|----------|--------|-------|
| **Frontend** | UI, React, CSS, component | sdd-domain-frontend | frontend-operations |
| **Backend** | API, endpoint, server, service | sdd-domain-backend | backend-operations |
| **Database** | schema, SQL, migration, query | sdd-domain-database | database-operations |
| **Testing** | test, TDD, coverage, QA | sdd-domain-testing | testing-operations |
| **Security** | auth, encryption, vulnerability | sdd-domain-security | security-operations |
| **Performance** | optimize, cache, latency | sdd-domain-performance | performance-operations |
| **DevOps** | deploy, CI/CD, Docker | sdd-domain-devops | devops-operations |

### Model Strategy

- **Coordinator** (Opus): Orchestrates team pipeline, makes architectural decisions
- **Domain Workers** (Sonnet): Execute domain-specific tasks using skill briefs
- **File Ownership**: Each worker is assigned file boundaries to prevent conflicts (enforced by `freeze-write-scope` hook)

---

## Non-Domain Agent/Skill Mapping

Quick reference for delegation based on task domain:

| Domain | Keywords | Delegate To | Type | Plugin |
|--------|----------|-------------|------|--------|
| **PRD/Product** | PRD, product, vision, personas | prd-specialist | agent | sdd-creation |
| **Specification (legacy)** | spec, requirements, user story | sdd-specification skill | skill | sdd-specification |
| **Planning (legacy)** | /plan, research, contracts | sdd-planning skill | skill | sdd-specification |
| **Tasks (legacy)** | /tasks, task list, breakdown | sdd-tasks skill | skill | sdd-specification |
| **Plan review** | /plan-review, plan verdict | plan-review skill | skill | sdd-orchestrator |
| **Retro** | /retro, learnings | retro skill | skill | sdd-orchestrator |
| **Orchestration (legacy unified)** | /specification | unified-specification skill | skill | sdd-specification |
| **Agent Creation** | create agent, new agent | subagent-architect | agent | sdd-creation |
| **Multi-Domain** | 2+ domains detected | team-orchestration skill | skill | sdd-orchestrator |
| **Swarm** | swarm, team, parallel agents | team-orchestration skill | skill | sdd-orchestrator |
| **Dev Loop** | /dev-loop, autonomous cycle | core-loop skill | skill | sdd-dev-loop |

---

## Slash Command → Agent/Skill Mapping

| Command | Delegate | Plugin | Purpose |
|---------|----------|--------|---------|
| `/create-prd` | prd-specialist | sdd-creation | Create PRD (auto-detects vision-driven vs legacy) |
| `/swarm` | team-orchestration skill | sdd-orchestrator | Multi-agent swarm (explore / implement / generic-legacy) |
| `/research` | team-synthesizer | sdd-orchestrator | Jury-on-demand multi-LLM research |
| `/plan-review` | plan-review skill | sdd-orchestrator | CEO + Eng verdict on plan.md |
| `/retro` | retro skill | sdd-orchestrator | Post-feature learning capture |
| `/review-team` | 4 parallel reviewers | sdd-orchestrator | security + quality + performance + behavioral evaluator |
| `/git-push` | - | sdd-git | Complete git workflow (commit + push + PR) |
| `/code-review` | - | sdd-git | PR-level review |
| `/specification` | unified-specification skill | sdd-specification | Legacy SDD waterfall (spec+plan+tasks) |
| `/specify` | sdd-specification skill | sdd-specification | Legacy: create feature specification |
| `/plan` | sdd-planning skill | sdd-specification | Legacy: generate implementation plan |
| `/tasks` | sdd-tasks skill | sdd-specification | Legacy: generate task list |
| `/build-team` | domain skills + coordinator | sdd-orchestrator | Legacy: sequential architect→implementor→reviewer |
| `/fullstack-team` | domain skills + coordinator | sdd-orchestrator | Legacy: parallel full-stack team |
| `/dev-loop` | core-loop skill | sdd-dev-loop | Legacy: recursive autonomous edit-test-debug |
| `/finalize` | - | sdd-git | Legacy: pre-commit compliance validation |
| `/create-agent` | subagent-architect | sdd-creation | Create new agent |
| `/create-plugin` | subagent-architect | sdd-creation | Create new plugin |
| `/update-framework` | framework-sync-agent | sdd-maintenance | Framework updates from upstream |
| `/initialize-project` | - | sdd-maintenance | Post-PRD project customization |

---

## Agent Collaboration Workflows

### LogicLoom Feature Pipeline (primary)

```
vision.md (human)
       ↓
/swarm explore + /research (fill gaps)
       ↓
prd-specialist (/create-prd — vision-driven mode)
       ↓
plan mode → plan.md (sprint-structured, file-ownership DAG)
       ↓
/plan-review (CEO + Eng verdict — gates swarm)
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

### Legacy SDD Pipeline (alternative)

```
prd-specialist (Phase 0: PRD)
       ↓
unified-specification skill (/specification)
  → sdd-specification skill → sdd-planning skill → sdd-tasks skill
       ↓
[Domain skill workers for implementation]
       ↓
testing skill worker (validation)
       ↓
security skill worker (review)
       ↓
devops skill worker (deployment)
```

### Multi-Agent Swarm (Skill-Based)

```
User: /swarm implement 02-api-surface
       ↓
Coordinator (Opus): reads plan.md sprint declaration, loads skill briefs
       ↓
File-ownership DAG enforced by freeze-write-scope hook
       ↓
Phase 1: database-operations skill worker (Sonnet) → schema
       ↓
Phase 2 (parallel):
  ├── backend-operations skill worker (Sonnet) → API
  └── frontend-operations skill worker (Sonnet) → UI
       ↓
Phase 3: testing-operations + behavioral-evaluator (Sonnet)
       ↓
Coordinator merges results into features/<feature>/sprints/02-api-surface/
```

---

## Agent File Locations (Plugin-First)

```
plugins/
├── sdd-governance/agents/
│   └── constitutional-governance-agent.md  (PRIMARY)
├── sdd-orchestrator/
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
├── sdd-creation/agents/
│   ├── prd-specialist.md
│   └── subagent-architect.md
├── sdd-maintenance/agents/
│   └── framework-sync-agent.md
├── sdd-memory/agents/
│   └── memory-context-agent.md
├── sdd-dev-loop/skills/
│   └── core-loop/SKILL.md
└── sdd-domain-*/skills/
    └── *-operations/SKILL.md  (7 domain skills with Task Briefs)
```

---

## Constitutional Compliance

All agents enforce Constitution v3.0.0 (16 Principles) plus the v6.0.0 supplementary principle:

### Immutable Principles (I-III)
- **I: Library-First** — Features as standalone libraries
- **II: Test-First** — TDD mandatory, >80% coverage
- **III: Contract-First** — Define contracts before implementation

### Critical Principles
- **VI: Git Approval** — NO autonomous git operations
- **X: Agent Delegation** — Specialized work → specialized agents/skills
- **XVI: Plugin-First** — All capabilities as discrete plugins

### v6.0.0 Supplementary Principle
- **Legacy-Tool Coexistence** — Legacy SDD tools (`/specification`, validators, DS-STAR, domain plugins, `/build-team`, `/fullstack-team`, `/dev-loop`, `/finalize`) remain as alternative paths alongside the LogicLoom workflow.

### All Agents Must
- Reference constitution in their system prompt
- Enforce TDD and library-first patterns
- Request approval for git operations
- Maintain audit trails
- Follow file organization rules (Principle XV)
- Respect file-ownership DAG and `freeze-write-scope` hook during swarm work

---

## Quick Decision Tree

```
Starting a new feature? ────────────────────→ vision.md → /swarm explore → /create-prd
Reviewing a plan before implement? ────────→ /plan-review (skill, sdd-orchestrator)
Running per-sprint workers? ───────────────→ /swarm implement <sprint>
Multi-LLM external research? ──────────────→ /research (jury-on-demand)
Multi-reviewer code/PR review? ────────────→ /review-team (4 reviewers)
Capturing post-feature learnings? ─────────→ /retro (skill, sdd-orchestrator)
Building UI components? ───────────────────→ frontend-operations skill (via swarm)
Designing APIs/services? ──────────────────→ backend-operations skill (via swarm)
Working with database? ────────────────────→ database-operations skill (via swarm)
Writing tests? ────────────────────────────→ testing-operations skill (via swarm)
Security concerns? ────────────────────────→ security-operations skill (via swarm)
Performance issues? ───────────────────────→ performance-operations skill (via swarm)
Deploying/CI-CD? ──────────────────────────→ devops-operations skill (via swarm)
Creating new agent? ───────────────────────→ subagent-architect (agent)
Legacy waterfall (well-understood feature)?─→ /specification (unified) or /specify + /plan + /tasks
Legacy autonomous loop? ───────────────────→ /dev-loop (core-loop skill)
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

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 6.0.0 | 2026-05-27 | LogicLoom rename + workflow modernization — `/swarm` 3 modes, `/review-team` 4 reviewers, `/research` jury-on-demand, `plan-review` + `retro` skills, vision-driven `/create-prd`, `.logic-loom/` paths |
| 5.1.0 | 2026-03-20 | Dead code cleanup — removed 4 orphaned dev-loop agents, sdd-debug plugin, sdd-domain-template; 6 agents, 16 plugins |
| 5.0.0 | 2026-02-15 | Full skill-based delegation — 3 orchestrator + 4 specification agents converted to skills |
| 4.0.0 | 2026-02-15 | Skill-based domain delegation — 7 domain agents converted to skills, model mixing (Opus/Sonnet) |
| 3.0.0 | 2026-02-07 | Plugin-First Architecture rewrite — command bridge, marketplace |
| 2.1.0 | 2025-12-05 | Added constitutional-governance-agent |
| 2.0.0 | 2025-11-29 | Complete rewrite, constitution v1.6.0 |
| 1.0.0 | 2025-09-19 | Initial creation |

---

**Registry Maintainer**: subagent-architect
**Review Cycle**: On any agent change
**Cross-Reference**: CLAUDE.md, `.logic-loom/memory/constitution.md`, `features/README.md`
