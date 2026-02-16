# Agents Context Module
<!-- Auto-generated from AGENTS.md and plugin files - Skill-Based Delegation v5.0 + Plugin-First Architecture v4.1 -->
<!-- Module: Agent/skill registry, delegation protocol, multi-agent coordination -->

## Agent & Skill Delegation Protocol

**Constitutional Principle X** requires specialized work be delegated to specialized agents or skills.

**Architecture (v5.0.0)**: 11 custom agents + 14 enhanced skills with Task Briefs. Domain and workflow expertise lives in plugin SKILL.md files, injected as Task tool briefs when spawning workers.

**Quick Rule**: Domain keywords → skill delegation (via team commands). Non-domain work → agent delegation.

---

## Domain → Skill Mapping (v5.0.0)

Domain work is handled by enhanced plugin skills, NOT custom agents:

| Domain | Keywords | Plugin:Skill | Invocation |
|--------|----------|-------------|------------|
| Frontend | UI, component, React, CSS | `sdd-domain-frontend:frontend-operations` | via team commands |
| Backend | API, endpoint, service, auth | `sdd-domain-backend:backend-operations` | via team commands |
| Database | schema, migration, query, SQL | `sdd-domain-database:database-operations` | via team commands |
| Testing | test, E2E, coverage, QA | `sdd-domain-testing:testing-operations` | via team commands |
| Security | encryption, XSS, vulnerability | `sdd-domain-security:security-operations` | via team commands |
| Performance | optimize, cache, benchmark | `sdd-domain-performance:performance-operations` | via team commands |
| DevOps | deploy, CI/CD, Docker | `sdd-domain-devops:devops-operations` | via team commands |

### Skill Injection Pattern

```
/build-team → extract_skill_brief("sdd-domain-backend", "backend-operations")
            → Task(prompt=skill_brief + task, model=sonnet)
```

Coordinators use Opus; domain workers use Sonnet with skill briefs.

---

## Non-Domain Delegation

| Domain | Keywords | Delegate To | Type |
|--------|----------|-------------|------|
| Specification | spec, requirements, user story | sdd-specification skill | skill |
| Planning | /plan, research, contracts | sdd-planning skill | skill |
| Tasks | /tasks, task breakdown | sdd-tasks skill | skill |
| Full pipeline | /specification | unified-specification skill | skill |
| Multi-Domain | 2+ domains | team-orchestration skill | skill |
| Swarm | /swarm, parallel agents | team-orchestration skill | skill |
| PRD/Product | PRD, product, vision | prd-specialist | agent |
| Debugging | debug, error, crash | auto-debug-agent | agent |
| Agent Creation | create agent/plugin | subagent-architect | agent |
| Dev Loop | /dev-loop, autonomous cycle | dev-loop-orchestrator | agent |

---

## Agent Registry (11 agents)

### sdd-governance (1)
- **constitutional-governance-agent** — Primary entry point, governance enforcement (opus)
  - Hook-based: no `"agent"` field in settings.json, runs via `UserPromptSubmit` preflight hook

### sdd-orchestrator (1)
- **team-synthesizer** — Merges multi-LLM outputs, tribunal confidence scoring (opus)

### sdd-creation (2)
- **prd-specialist** — PRD creation, product strategy (opus)
- **subagent-architect** — Agent/plugin creation, SDD compliance (inherit)

### sdd-debug (1)
- **auto-debug-agent** — Self-healing error resolution (opus)

### sdd-maintenance (1)
- **framework-sync-agent** — Framework updates from upstream (opus)

### sdd-memory (1)
- **memory-context-agent** — Memory search + context injection via preflight hook (haiku)

### sdd-dev-loop (4)
- **dev-loop-orchestrator** — Recursive autonomous dev-loop (opus)
- **debug-analyst** — Test failure analysis and fix proposals (sonnet)
- **quality-assessor** — Multi-model tribunal voting, quality grading (sonnet)
- **tribunal-judge** — Independent quality judgment for cross-validation (sonnet)

---

## Enhanced Skills (replacing former agents)

### Orchestrator Skills (replaced 3 agents)
- `team-orchestration/SKILL.md` — Team coordination, swarm management, budget controls (merged from task-orchestrator + swarm-coordinator)
- `multi-skill-workflow/SKILL.md` — Multi-domain workflow sequencing (merged from workflow-coordinator)

### Specification Skills (replaced 4 agents)
- `sdd-specification/SKILL.md` — Feature spec creation (merged from specification-agent)
- `sdd-planning/SKILL.md` — Implementation planning (merged from planning-agent)
- `sdd-tasks/SKILL.md` — Task decomposition (merged from tasks-agent)
- `unified-specification/SKILL.md` — End-to-end spec pipeline (merged from specification-orchestrator)

### Domain Skills (replaced 7 agents)
- 7 `*-operations/SKILL.md` files with Task Brief sections (replaced frontend-specialist, backend-architect, database-specialist, security-specialist, testing-specialist, performance-engineer, devops-engineer)

---

## Slash Command Mapping

| Command | Delegate | Plugin |
|---------|----------|--------|
| `/create-prd` | prd-specialist (agent) | sdd-creation |
| `/specification` | unified-specification skill | sdd-specification |
| `/specify` | sdd-specification skill | sdd-specification |
| `/plan` | sdd-planning skill | sdd-specification |
| `/tasks` | sdd-tasks skill | sdd-specification |
| `/create-agent` | subagent-architect (agent) | sdd-creation |
| `/debug` | auto-debug-agent (agent) | sdd-debug |
| `/research` | team-synthesizer (agent) | sdd-orchestrator |
| `/swarm` | team-orchestration skill | sdd-orchestrator |
| `/build-team` | team-orchestration skill | sdd-orchestrator |
| `/fullstack-team` | team-orchestration skill | sdd-orchestrator |
| `/review-team` | team-orchestration skill | sdd-orchestrator |
| `/dev-loop` | dev-loop-orchestrator (agent) | sdd-dev-loop |
| `/update-framework` | framework-sync-agent (agent) | sdd-maintenance |

---

## Delegation Decision Tree

```
START → Analyze task keywords
  ↓
2+ domain keywords? → YES → team-orchestration skill (or team command)
  ↓ NO
1 domain keyword? → YES → Load domain skill brief via team command
  ↓ NO
Specification work? → YES → appropriate spec skill
  ↓ NO
Debugging? → YES → auto-debug-agent
  ↓ NO
Execute directly (simple task, no domain specialization needed)
```

---

## Multi-Agent Swarm (Skill-Based)

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

---

**Module Version**: 3.0.0
**Last Updated**: 2026-02-15
**Architecture**: Plugin-First v4.1 + Skill-Based Delegation v5.0.0
**Constitutional Authority**: Principle X (Agent Delegation Protocol)
