# Agents Context Module
<!-- Auto-generated from AGENTS.md and plugin files -->
<!-- Module: Agent/skill registry, delegation protocol, multi-agent coordination -->

## Delegation & Context Isolation Protocol

**Constitutional Principle X** requires specialized work be delegated to
specialists or `/swarm`, with each worker's context kept isolated.

**Architecture**: A small set of custom agents + enhanced skills, plus a
**domain-brief registry**. Domain expertise lives in per-domain markdown briefs;
workflow expertise lives in plugin SKILL.md files. Both are injected as isolated
Task-tool briefs when spawning workers.

**Quick Rule**: Domain keywords → load the domain brief (via team commands or
`/swarm`). Non-domain / workflow work → agent or skill delegation.

Delegation routing is surfaced automatically by the `UserPromptSubmit` preflight
hook — no recited protocol is required.

---

## Domain → Brief Mapping

Domain expertise is organized in a lightweight **domain-brief registry** — one markdown brief per domain —
loaded on demand via `get_domain_brief <domain>` (in `common.sh`):

| Domain | Keywords | Brief | Loader |
|--------|----------|-------|--------|
| Frontend | UI, component, React, CSS | `plugins/loom-governance/domain-briefs/frontend.md` | `get_domain_brief frontend` |
| Backend | API, endpoint, service, auth | `plugins/loom-governance/domain-briefs/backend.md` | `get_domain_brief backend` |
| Database | schema, migration, query, SQL | `plugins/loom-governance/domain-briefs/database.md` | `get_domain_brief database` |
| Testing | test, E2E, coverage, QA | `plugins/loom-governance/domain-briefs/testing.md` | `get_domain_brief testing` |
| Security | encryption, XSS, vulnerability | `plugins/loom-governance/domain-briefs/security.md` | `get_domain_brief security` |
| Performance | optimize, cache, benchmark | `plugins/loom-governance/domain-briefs/performance.md` | `get_domain_brief performance` |
| DevOps | deploy, CI/CD, Docker | `plugins/loom-governance/domain-briefs/devops.md` | `get_domain_brief devops` |

### Brief Injection Pattern

```
/build-team → get_domain_brief backend
            → Task(prompt=domain_brief + task, model=sonnet)
```

Coordinators use Opus 4.8; domain workers use Sonnet with an isolated brief.

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
| Agent Creation | create agent/plugin | subagent-architect | agent |

---

## Agent Registry (6 agents)

### loom-governance (1)
- **constitutional-governance-agent** — Primary entry point, governance enforcement (opus)
  - Hook-based: no `"agent"` field in settings.json, runs via `UserPromptSubmit` preflight hook

### loom-orchestrator (1)
- **team-synthesizer** — Merges multi-LLM outputs, tribunal confidence scoring (opus)

### loom-creation (2)
- **prd-specialist** — PRD creation, product strategy (opus)
- **subagent-architect** — Agent/plugin creation, SDD compliance (inherit)

### loom-maintenance (1)
- **framework-sync-agent** — Framework updates from upstream (opus)

### loom-memory (1)
- **memory-context-agent** — Memory search + context injection via preflight hook (haiku)

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

### Domain Briefs (replaced 7 domain plugins)
- 7 `plugins/loom-governance/domain-briefs/<domain>.md` briefs, loaded via `get_domain_brief <domain>` and injected as isolated worker context (one brief per domain: frontend, backend, database, security, testing, performance, devops)

---

## Slash Command Mapping

| Command | Delegate | Plugin |
|---------|----------|--------|
| `/create-prd` | prd-specialist (agent) | loom-creation |
| `/specification` | unified-specification skill | sdd-specification |
| `/specify` | sdd-specification skill | sdd-specification |
| `/plan` | sdd-planning skill | sdd-specification |
| `/tasks` | sdd-tasks skill | sdd-specification |
| `/create-agent` | subagent-architect (agent) | loom-creation |
| `/research` | team-synthesizer (agent) | loom-orchestrator |
| `/swarm` | team-orchestration skill | loom-orchestrator |
| `/build-team` | team-orchestration skill | loom-orchestrator |
| `/fullstack-team` | team-orchestration skill | loom-orchestrator |
| `/review-team` | team-orchestration skill | loom-orchestrator |
| `/update-framework` | framework-sync-agent (agent) | loom-maintenance |

---

## Delegation Decision Tree

```
START → Analyze task keywords
  ↓
2+ domain keywords? → YES → /swarm or team-orchestration skill
  ↓ NO
1 domain keyword? → YES → get_domain_brief <domain> (via team command / swarm)
  ↓ NO
Specification work? → YES → appropriate spec skill
  ↓ NO
Execute directly (simple task, no domain specialization needed)
```

---

## Multi-Agent Swarm (Skill-Based)

```
User: /swarm "Build auth with React UI, Express API, PostgreSQL"
       ↓
Coordinator (Opus 4.8): analyzes domains, loads domain briefs, plans phases
       ↓
Phase 1: database worker (Sonnet, get_domain_brief database) → schema
       ↓
Phase 2 (parallel):
  ├── backend worker (Sonnet, get_domain_brief backend) → API
  └── frontend worker (Sonnet, get_domain_brief frontend) → UI
       ↓
Phase 3: testing + security workers (Sonnet, respective briefs)
       ↓
Coordinator merges results
```

---

**Module Version**: 3.0.0
**Architecture**: Plugin-First + domain-brief registry; hook-enforced governance
**Constitutional Authority**: Principle X (Delegation & Context Isolation)
