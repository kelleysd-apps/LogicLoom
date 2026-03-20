# SDD Framework Agent Registry

**Version**: 5.0.0
**Last Updated**: 2026-02-15
**Constitution**: v3.0.0 (16 Principles)
**Architecture**: Plugin-First (v4.1) + Skill-Based Delegation
**Total Agents**: 6
**Plugins**: 16

---

## Purpose

This file is the **Single Source of Truth (SSOT)** for agent information in the SDD Framework. It provides quick reference for agent selection, capabilities, and usage patterns.

**Relationship to CLAUDE.md**:
- `CLAUDE.md` → Workflow rules, compliance protocols, delegation triggers
- `AGENTS.md` → Agent registry, capabilities, selection guidance

**Both files MUST be updated together** when agents are added/modified (see Tandem Update Rules below).

> **Plugin-First Architecture**: All agents live within their respective plugins at `plugins/<plugin>/agents/`. Legacy `.claude/agents/` directory has been removed.

---

## Primary Agent (settings.json)

### constitutional-governance-agent ⭐ DEFAULT

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

---

## Agent Registry by Plugin

### sdd-governance (1 agent)

| Agent | Purpose | Model |
|-------|---------|-------|
| **constitutional-governance-agent** ⭐ | Primary entry point, governance enforcement | opus |

### sdd-orchestrator (1 agent)

| Agent | Purpose | Model |
|-------|---------|-------|
| **team-synthesizer** | Merges multi-LLM parallel outputs; cross-model convergence analysis and tribunal confidence scoring | opus |

> **Note**: task-orchestrator, swarm-coordinator, and workflow-coordinator have been converted to enhanced skills (`team-orchestration`, `multi-skill-workflow`) with Task Brief sections (v5.0.0).

### sdd-specification (0 agents — skill-based)

> All 4 specification agents (specification-agent, planning-agent, tasks-agent, specification-orchestrator) have been converted to enhanced skills with Task Brief sections (v5.0.0). Skills: `sdd-specification`, `sdd-planning`, `sdd-tasks`, `unified-specification`.

### sdd-creation (2 agents)

| Agent | Purpose | Model |
|-------|---------|-------|
| **prd-specialist** | PRD creation, product strategy | opus |
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

> All 4 dev-loop agents (dev-loop-orchestrator, debug-analyst, quality-assessor, tribunal-judge) have been removed. The rewritten `core-loop` skill handles all dev-loop functionality directly.

---

## Skill-Based Domain Delegation

**Architecture Change (v4.0.0)**: Domain specialist agents have been replaced by enhanced plugin SKILL.md files. Instead of custom agent definitions, domain expertise lives in plugin skills that are injected as Task tool briefs when spawning team workers.

### How It Works

```
BEFORE (v3.0):
  /build-team → reads agents/backend-architect.md → Task(prompt=agent_prompt)

AFTER (v4.0):
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
- **File Ownership**: Each worker is assigned file boundaries to prevent conflicts

---

## Non-Domain Agent/Skill Mapping

Quick reference for delegation based on task domain:

| Domain | Keywords | Delegate To | Type | Plugin |
|--------|----------|-------------|------|--------|
| **PRD/Product** | PRD, product, vision, personas | prd-specialist | agent | sdd-creation |
| **Specification** | spec, requirements, user story | sdd-specification skill | skill | sdd-specification |
| **Planning** | /plan, research, contracts | sdd-planning skill | skill | sdd-specification |
| **Tasks** | /tasks, task list, breakdown | sdd-tasks skill | skill | sdd-specification |
| **Orchestration** | /specification (unified) | unified-specification skill | skill | sdd-specification |
| **Agent Creation** | create agent, new agent | subagent-architect | agent | sdd-creation |
| **Multi-Domain** | 2+ domains detected | team-orchestration skill | skill | sdd-orchestrator |
| **Swarm** | swarm, team, parallel agents | team-orchestration skill | skill | sdd-orchestrator |
| **Dev Loop** | /dev-loop, autonomous cycle | core-loop skill | skill | sdd-dev-loop |

---

## Slash Command → Agent/Skill Mapping

| Command | Delegate | Plugin | Purpose |
|---------|----------|--------|---------|
| `/create-prd` | prd-specialist | sdd-creation | Create Product Requirements Document |
| `/specification` | unified-specification skill | sdd-specification | Unified SDD workflow (spec+plan+tasks) |
| `/specify` | sdd-specification skill | sdd-specification | Create feature specification |
| `/plan` | sdd-planning skill | sdd-specification | Generate implementation plan |
| `/tasks` | sdd-tasks skill | sdd-specification | Generate task list |
| `/create-agent` | subagent-architect | sdd-creation | Create new agent |
| `/create-plugin` | subagent-architect | sdd-creation | Create new plugin |
| `/finalize` | - | sdd-git | Pre-commit compliance validation |
| `/git-push` | - | sdd-git | Complete git workflow |
| `/research` | team-synthesizer | sdd-orchestrator | Multi-LLM tribunal research (Claude, OpenAI, Gemini) |
| `/swarm` | domain skills + coordinator | sdd-orchestrator | Multi-agent swarm execution |
| `/build-team` | domain skills + coordinator | sdd-orchestrator | Sequential architect→implementor→reviewer |
| `/fullstack-team` | domain skills + coordinator | sdd-orchestrator | Parallel full-stack team |
| `/review-team` | domain skills + coordinator | sdd-orchestrator | Parallel security+quality+performance |
| `/update-framework` | framework-sync-agent | sdd-maintenance | Framework updates from upstream |
| `/initialize-project` | - | sdd-maintenance | Post-PRD project customization |

---

## Agent Collaboration Workflows

### Feature Development Pipeline

```
prd-specialist (Phase 0: PRD)
       ↓
unified-specification skill (/specification — unified workflow)
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
User: /swarm "Build auth with React UI, Express API, PostgreSQL"
       ↓
Coordinator (Opus): analyzes domains, loads skill briefs, plans phases
       ↓
Phase 1: database-operations skill worker (Sonnet) → schema
       ↓
Phase 2 (parallel):
  ├── backend-operations skill worker (Sonnet) → API
  └── frontend-operations skill worker (Sonnet) → UI
       ↓
Phase 3: testing-operations + security-operations workers (Sonnet)
       ↓
Coordinator merges results
```

### Plugin Discovery (Dynamic)

```
team-orchestration skill receives request
       ↓
marketplace-list (MCP) → discover installed plugins
       ↓
Domain keyword matching → select skill
       ↓
RL-weighted routing (prefer higher success_rate)
       ↓
marketplace-search → find missing capabilities
       ↓
marketplace-install → install on-demand (with approval)
```

---

## Agent File Locations (Plugin-First)

```
plugins/
├── sdd-governance/agents/
│   └── constitutional-governance-agent.md  ⭐ PRIMARY
├── sdd-orchestrator/
│   ├── agents/
│   │   └── team-synthesizer.md
│   └── skills/
│       ├── team-orchestration/SKILL.md  (merged from task-orchestrator + swarm-coordinator)
│       └── multi-skill-workflow/SKILL.md  (merged from workflow-coordinator)
├── sdd-specification/skills/
│   ├── sdd-specification/SKILL.md  (merged from specification-agent)
│   ├── sdd-planning/SKILL.md  (merged from planning-agent)
│   ├── sdd-tasks/SKILL.md  (merged from tasks-agent)
│   └── unified-specification/SKILL.md  (merged from specification-orchestrator)
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

> **Note**: Domain agents converted to skills in v4.0.0. Orchestrator and specification agents converted in v5.0.0. Domain/workflow expertise is now injected via `extract_skill_brief()` into Task tool prompts.

---

## Constitutional Compliance

All agents enforce Constitution v3.0.0 (16 Principles):

### Immutable Principles (I-III)
- **I: Library-First** — Features as standalone libraries
- **II: Test-First** — TDD mandatory, >80% coverage
- **III: Contract-First** — Define contracts before implementation

### Critical Principles
- **VI: Git Approval** — NO autonomous git operations
- **X: Agent Delegation** — Specialized work → specialized agents/skills
- **XVI: Plugin-First** — All capabilities as discrete plugins

### All Agents Must
- Reference constitution in their system prompt
- Enforce TDD and library-first patterns
- Request approval for git operations
- Maintain audit trails
- Follow file organization rules (Principle XV)

---

## Quick Decision Tree

```
Creating PRD/product vision? ──────────────→ prd-specialist (agent)
Creating feature specification? ───────────→ sdd-specification skill
Planning implementation? ──────────────────→ sdd-planning skill
Breaking down into tasks? ─────────────────→ sdd-tasks skill
Full spec→plan→tasks pipeline? ────────────→ unified-specification skill
Building UI components? ───────────────────→ frontend-operations skill (via team command)
Designing APIs/services? ──────────────────→ backend-operations skill (via team command)
Working with database? ────────────────────→ database-operations skill (via team command)
Writing tests? ────────────────────────────→ testing-operations skill (via team command)
Security concerns? ────────────────────────→ security-operations skill (via team command)
Performance issues? ───────────────────────→ performance-operations skill (via team command)
Deploying/CI-CD? ──────────────────────────→ devops-operations skill (via team command)
Creating new agent? ───────────────────────→ subagent-architect (agent)
Multi-agent swarm? ────────────────────────→ team-orchestration skill (/swarm)
Deep research? ────────────────────────────→ /research command
Autonomous dev loop? ──────────────────────→ core-loop skill (/dev-loop)
Multiple domains (2+)? ───────────────────→ team-orchestration skill
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
| 5.1.0 | 2026-03-20 | Dead code cleanup — removed 4 orphaned dev-loop agents, sdd-debug plugin, sdd-domain-template; 6 agents, 16 plugins |
| 5.0.0 | 2026-02-15 | Full skill-based delegation — 3 orchestrator + 4 specification agents converted to skills, added sdd-dev-loop agents, 11 agents |
| 4.0.0 | 2026-02-15 | Skill-based domain delegation — 7 domain agents converted to skills, model mixing (Opus/Sonnet) |
| 3.0.0 | 2026-02-07 | Plugin-First Architecture rewrite — 22 agents across 15 plugins, command bridge, marketplace |
| 2.1.0 | 2025-12-05 | Added constitutional-governance-agent (15 agents) |
| 2.0.0 | 2025-11-29 | Complete rewrite, 14 agents, constitution v1.6.0 |
| 1.0.0 | 2025-09-19 | Initial creation with 9 agents |

---

**Registry Maintainer**: subagent-architect
**Review Cycle**: On any agent change
**Cross-Reference**: CLAUDE.md, constitution.md, agent-collaboration-triggers.md
