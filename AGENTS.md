# SDD Framework Agent Registry

**Version**: 3.0.0
**Last Updated**: 2026-02-07
**Constitution**: v3.0.0 (16 Principles)
**Architecture**: Plugin-First (v4.1)
**Total Agents**: 21
**Plugins**: 15

---

## Purpose

This file is the **Single Source of Truth (SSOT)** for agent information in the SDD Framework. It provides quick reference for agent selection, capabilities, and usage patterns.

**Relationship to CLAUDE.md**:
- `CLAUDE.md` → Workflow rules, compliance protocols, delegation triggers
- `AGENTS.md` → Agent registry, capabilities, selection guidance

**Both files MUST be updated together** when agents are added/modified (see Tandem Update Rules below).

> **Plugin-First Architecture**: All agents now live within their respective plugins at `plugins/<plugin>/agents/`. The `.claude/agents/` directory contains deprecated shims that point to plugin sources.

---

## Primary Agent (settings.json)

### constitutional-governance-agent ⭐ DEFAULT

**Purpose**: Primary orchestration agent that serves as the **main thread entry point** for all Claude Code sessions. Enforces the 4-step pre-flight compliance protocol on every user message, routes specialized work to domain agents, and gates all git operations.

| Setting | Value |
|---------|-------|
| **Plugin** | `sdd-governance` |
| **Model** | opus (required for governance decisions) |
| **Tools** | Full access (Read, Write, Edit, MultiEdit, Bash, Grep, Glob, WebSearch, Task, TodoWrite) |
| **Location** | `plugins/sdd-governance/agents/constitutional-governance-agent.md` |

**Configuration** (`.claude/settings.json`):
```json
{
  "agent": "constitutional-governance-agent"
}
```

**Key Responsibilities**:
1. Enforce 4-step pre-flight compliance on EVERY user message
2. Route specialized work to domain agents (Principle X)
3. Gate ALL git operations (Principle VI - CRITICAL)
4. Maintain constitutional governance across session

---

## Agent Registry by Plugin

### sdd-governance (1 agent)

| Agent | Purpose | Model |
|-------|---------|-------|
| **constitutional-governance-agent** ⭐ | Primary entry point, governance enforcement | opus |

### sdd-orchestrator (4 agents)

| Agent | Purpose | Model |
|-------|---------|-------|
| **task-orchestrator** | Multi-agent coordination via Plugin Marketplace (MCP) | opus |
| **swarm-coordinator** | Multi-agent swarm management, task graphs, budget controls | opus |
| **team-synthesizer** | Merges parallel agent outputs into coherent results | opus |
| **workflow-coordinator** | Multi-skill workflows, migrations, complex orchestration | opus |

### sdd-specification (4 agents)

| Agent | Purpose | Model |
|-------|---------|-------|
| **specification-agent** | Feature specs, user stories, requirements | opus |
| **planning-agent** | Implementation planning, /plan command | opus |
| **tasks-agent** | Task decomposition, /tasks command | opus |
| **specification-orchestrator** | End-to-end product workflow (PRD → spec → plan → tasks) | opus |

### sdd-creation (2 agents)

| Agent | Purpose | Model |
|-------|---------|-------|
| **prd-specialist** | PRD creation, product strategy | opus |
| **subagent-architect** | Agent creation, SDD compliance | inherit |

### sdd-debug (1 agent)

| Agent | Purpose | Model |
|-------|---------|-------|
| **auto-debug-agent** | Self-healing error resolution | opus |

### sdd-maintenance (1 agent)

| Agent | Purpose | Model |
|-------|---------|-------|
| **framework-sync-agent** | Framework updates from upstream | opus |

### Domain Plugins (7 agents — 1 per domain)

| Plugin | Agent | Domain | Model |
|--------|-------|--------|-------|
| `sdd-domain-frontend` | **frontend-specialist** | React/Next.js, UI, CSS | opus |
| `sdd-domain-backend` | **backend-architect** | API design, services, auth | opus |
| `sdd-domain-database` | **database-specialist** | Schema, SQL, migrations | opus |
| `sdd-domain-testing` | **testing-specialist** | TDD, E2E, QA | opus |
| `sdd-domain-security` | **security-specialist** | Vulnerabilities, encryption | opus |
| `sdd-domain-devops` | **devops-engineer** | CI/CD, Docker, cloud | opus |
| `sdd-domain-performance` | **performance-engineer** | Optimization, caching, latency | opus |

### sdd-domain-template (1 agent — scaffold only)

| Agent | Purpose | Model |
|-------|---------|-------|
| **template-specialist** | Template for new domain plugins | opus |

---

## Domain → Agent Mapping

Quick reference for agent selection based on task domain:

| Domain | Keywords | Primary Agent | Plugin |
|--------|----------|---------------|--------|
| **PRD/Product** | PRD, product, vision, personas | prd-specialist | sdd-creation |
| **Specification** | spec, requirements, user story | specification-agent | sdd-specification |
| **Planning** | /plan, research, contracts | planning-agent | sdd-specification |
| **Tasks** | /tasks, task list, breakdown | tasks-agent | sdd-specification |
| **Frontend** | UI, React, CSS, component | frontend-specialist | sdd-domain-frontend |
| **Backend** | API, endpoint, server, service | backend-architect | sdd-domain-backend |
| **Database** | schema, SQL, migration, query | database-specialist | sdd-domain-database |
| **Testing** | test, TDD, coverage, QA | testing-specialist | sdd-domain-testing |
| **Security** | auth, encryption, vulnerability | security-specialist | sdd-domain-security |
| **Performance** | optimize, cache, latency | performance-engineer | sdd-domain-performance |
| **DevOps** | deploy, CI/CD, Docker | devops-engineer | sdd-domain-devops |
| **Debugging** | debug, error, fix, crash | auto-debug-agent | sdd-debug |
| **Agent Creation** | create agent, new agent | subagent-architect | sdd-creation |
| **Multi-Domain** | 2+ domains detected | task-orchestrator | sdd-orchestrator |
| **Swarm** | swarm, team, parallel agents | swarm-coordinator | sdd-orchestrator |

---

## Slash Command → Agent Mapping

| Command | Agent | Plugin | Purpose |
|---------|-------|--------|---------|
| `/create-prd` | prd-specialist | sdd-creation | Create Product Requirements Document |
| `/specification` | specification-agent | sdd-specification | Unified SDD workflow (spec+plan+tasks) |
| `/specify` | specification-agent | sdd-specification | Create feature specification |
| `/plan` | planning-agent | sdd-specification | Generate implementation plan |
| `/tasks` | tasks-agent | sdd-specification | Generate task list |
| `/create-agent` | subagent-architect | sdd-creation | Create new agent |
| `/create-plugin` | subagent-architect | sdd-creation | Create new plugin |
| `/debug` | auto-debug-agent | sdd-debug | Debug deployment/runtime issues |
| `/finalize` | - | sdd-git | Pre-commit compliance validation |
| `/git-push` | - | sdd-git | Complete git workflow |
| `/research` | task-orchestrator | sdd-orchestrator | Multi-pass deep research |
| `/swarm` | swarm-coordinator | sdd-orchestrator | Multi-agent swarm execution |
| `/build-team` | swarm-coordinator | sdd-orchestrator | Sequential architect→implementor→reviewer |
| `/fullstack-team` | swarm-coordinator | sdd-orchestrator | Parallel full-stack team |
| `/research-team` | swarm-coordinator | sdd-orchestrator | Parallel research agents + synthesizer |
| `/review-team` | swarm-coordinator | sdd-orchestrator | Parallel security+quality+performance |
| `/update-framework` | framework-sync-agent | sdd-maintenance | Framework updates from upstream |
| `/initialize-project` | - | sdd-maintenance | Post-PRD project customization |

---

## Agent Collaboration Workflows

### Feature Development Pipeline

```
prd-specialist (Phase 0: PRD)
       ↓
specification-agent (/specification — unified workflow)
       ↓
[Specialized agents for implementation]
       ↓
testing-specialist (validation)
       ↓
security-specialist (review)
       ↓
devops-engineer (deployment)
```

### Multi-Agent Swarm

```
User: /swarm "Build auth with React UI, Express API, PostgreSQL"
       ↓
swarm-coordinator (analyzes domains, plans phases)
       ↓
Phase 1: database-specialist (schema)
       ↓
Phase 2 (parallel):
  ├── backend-architect (API)
  └── frontend-specialist (UI)
       ↓
Phase 3: testing-specialist + security-specialist
       ↓
team-synthesizer (merge results)
```

### Plugin Discovery (Dynamic)

```
task-orchestrator receives request
       ↓
marketplace-list (MCP) → discover installed plugins
       ↓
Domain keyword matching → select agent
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
├── sdd-orchestrator/agents/
│   ├── task-orchestrator.md
│   ├── swarm-coordinator.md
│   ├── team-synthesizer.md
│   └── workflow-coordinator.md
├── sdd-specification/agents/
│   ├── specification-agent.md
│   ├── planning-agent.md
│   ├── tasks-agent.md
│   └── specification-orchestrator.md
├── sdd-creation/agents/
│   ├── prd-specialist.md
│   └── subagent-architect.md
├── sdd-debug/agents/
│   └── auto-debug-agent.md
├── sdd-maintenance/agents/
│   └── framework-sync-agent.md
└── sdd-domain-*/agents/
    └── [domain]-specialist.md  (7 domain agents)
```

> **Legacy**: `.claude/agents/` contains deprecated shims pointing to plugin sources. These will be removed in v5.0.

---

## Constitutional Compliance

All agents enforce Constitution v3.0.0 (16 Principles):

### Immutable Principles (I-III)
- **I: Library-First** — Features as standalone libraries
- **II: Test-First** — TDD mandatory, >80% coverage
- **III: Contract-First** — Define contracts before implementation

### Critical Principles
- **VI: Git Approval** — NO autonomous git operations
- **X: Agent Delegation** — Specialized work → specialized agents
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
Creating PRD/product vision? ──────────────→ prd-specialist
Creating feature specification? ───────────→ specification-agent
Planning implementation? ──────────────────→ planning-agent
Breaking down into tasks? ─────────────────→ tasks-agent
Building UI components? ───────────────────→ frontend-specialist
Designing APIs/services? ──────────────────→ backend-architect
Working with database? ────────────────────→ database-specialist
Writing tests? ────────────────────────────→ testing-specialist
Security concerns? ────────────────────────→ security-specialist
Performance issues? ───────────────────────→ performance-engineer
Deploying/CI-CD? ──────────────────────────→ devops-engineer
Debugging errors? ─────────────────────────→ auto-debug-agent
Creating new agent? ───────────────────────→ subagent-architect
Multi-agent swarm? ────────────────────────→ swarm-coordinator
Deep research? ────────────────────────────→ /research command
Multiple domains (2+)? ───────────────────→ task-orchestrator
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

### Update Protocol
1. Update agent file in plugin
2. Update AGENTS.md registry
3. Update CLAUDE.md delegation rules
4. Run `sync-plugin-commands.sh sync` (if commands changed)
5. Run `constitutional-check.sh`
6. Run full test suite

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 3.0.0 | 2026-02-07 | Plugin-First Architecture rewrite — 21 agents across 15 plugins, command bridge, marketplace |
| 2.1.0 | 2025-12-05 | Added constitutional-governance-agent (15 agents) |
| 2.0.0 | 2025-11-29 | Complete rewrite, 14 agents, constitution v1.6.0 |
| 1.0.0 | 2025-09-19 | Initial creation with 9 agents |

---

**Registry Maintainer**: subagent-architect
**Review Cycle**: On any agent change
**Cross-Reference**: CLAUDE.md, constitution.md, agent-collaboration-triggers.md
