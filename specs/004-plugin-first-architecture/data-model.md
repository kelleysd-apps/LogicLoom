# Data Model: Plugin-First Architecture (v4.0)

**Branch**: `004-plugin-first-architecture` | **Date**: 2026-02-06

---

## Entity: Plugin Manifest (`plugin.json`)

```json
{
  "name": "sdd-governance",
  "version": "1.0.0",
  "description": "Constitutional governance enforcement for SDD framework",
  "author": "kelleysd-apps",
  "license": "MIT",
  "homepage": "https://github.com/kelleysd-apps/sdd-plugins-marketplace",
  "keywords": ["sdd", "governance", "constitutional"],
  "dependencies": [],
  "rl_metrics": {
    "success_rate": 0.5,
    "selection_weight": 0.5,
    "invocation_count": 0,
    "avg_tokens": 0,
    "last_updated": "2026-02-06T00:00:00Z"
  }
}
```

### Fields
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | Yes | Plugin identifier (sdd-{category}-{name}) |
| version | semver | Yes | Semantic version (independent per plugin) |
| description | string | Yes | Human-readable purpose |
| author | string | Yes | Plugin author/org |
| dependencies | string[] | No | Other SDD plugins required |
| rl_metrics | object | No | Per-plugin reinforcement learning metrics |

---

## Entity: Swarm State File (`.claude/multi-agent-swarm.local.md`)

```yaml
---
agent_name: backend-api-auth
task_number: 3.2
coordinator_session: auth-swarm-leader
enabled: true
dependencies: ["3.1"]
budget_usd: 5.00
budget_spent_usd: 0.00
worktree: feat/auth-api
model: opus
fallback_model: sonnet
status: running
started_at: "2026-02-06T10:30:00Z"
---
# Task: Implement Auth API
Build JWT-based authentication endpoint with refresh tokens...
```

### Fields
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| agent_name | string | Yes | Unique agent identifier within swarm |
| task_number | float | Yes | Task graph position (supports sub-tasks) |
| coordinator_session | string | Yes | tmux session name of coordinator |
| enabled | boolean | Yes | Whether agent is active |
| dependencies | string[] | No | Task numbers that must complete first |
| budget_usd | float | No | Maximum spend for this agent |
| budget_spent_usd | float | No | Current spend (updated by hooks) |
| worktree | string | No | Git worktree branch name |
| model | string | No | Primary model (default: opus) |
| fallback_model | string | No | Fallback when quota depletes |
| status | enum | Yes | pending, running, complete, failed, killed |

---

## Entity: Agent Team Template

```yaml
name: build-team
description: "Sequential build workflow: architect → implementor → reviewer"
execution_mode: sequential
agents:
  - role: architect
    agent: backend-architect
    model: opus
    budget_pct: 30
    task: "Design the architecture for: {task_description}"
  - role: implementor
    agent: full-stack-developer
    model: opus
    budget_pct: 50
    task: "Implement based on the architecture: {architect_output}"
    depends_on: [architect]
  - role: reviewer
    agent: testing-specialist
    model: opus
    budget_pct: 20
    task: "Review and test the implementation: {implementor_output}"
    depends_on: [implementor]
total_budget_usd: 15.00
```

### Fields
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | Yes | Template name (used as command: /{name}) |
| description | string | Yes | Human-readable purpose |
| execution_mode | enum | Yes | sequential, parallel, or mixed |
| agents | AgentSpec[] | Yes | Ordered list of agent configurations |
| agents[].role | string | Yes | Role name within team |
| agents[].agent | string | Yes | Agent definition to use |
| agents[].model | string | No | Model override (default: opus) |
| agents[].budget_pct | int | No | Percentage of total_budget |
| agents[].depends_on | string[] | No | Roles that must complete first |
| total_budget_usd | float | No | Team-wide budget cap |

---

## Entity: Plugin RL Metrics

```json
{
  "success_rate": 0.85,
  "selection_weight": 0.9,
  "invocation_count": 47,
  "avg_tokens": 1250,
  "avg_duration_ms": 3200,
  "last_updated": "2026-02-06T15:30:00Z",
  "history": [
    {"date": "2026-02-05", "success_rate": 0.82, "invocations": 12},
    {"date": "2026-02-06", "success_rate": 0.85, "invocations": 35}
  ]
}
```

### Algorithm
```
success_rate = 0.9 * old_rate + 0.1 * (1 if success else 0)   # EMA, lr=0.1
selection_weight = clamp(success_rate, 0.1, 1.0)
```

---

## Entity: Marketplace Registry

```json
{
  "marketplace": "sdd-plugins-marketplace",
  "repository": "kelleysd-apps/sdd-plugins-marketplace",
  "plugins": {
    "sdd-governance": { "version": "1.0.0", "category": "core", "required": true },
    "sdd-specification": { "version": "1.0.0", "category": "workflow" },
    "sdd-orchestrator": { "version": "1.0.0", "category": "coordination" },
    "sdd-git": { "version": "1.0.0", "category": "safety" },
    "sdd-creation": { "version": "1.0.0", "category": "creation" },
    "sdd-debug": { "version": "1.0.0", "category": "debug" },
    "sdd-domain-frontend": { "version": "1.0.0", "category": "domain" },
    "sdd-domain-backend": { "version": "1.0.0", "category": "domain" },
    "sdd-domain-database": { "version": "1.0.0", "category": "domain" },
    "sdd-domain-testing": { "version": "1.0.0", "category": "domain" },
    "sdd-domain-security": { "version": "1.0.0", "category": "domain" },
    "sdd-domain-devops": { "version": "1.0.0", "category": "domain" },
    "sdd-domain-performance": { "version": "1.0.0", "category": "domain" }
  }
}
```

---

## Relationships

```
Marketplace ──has-many──► Plugin Manifest
Plugin Manifest ──has-one──► RL Metrics
Plugin (sdd-orchestrator) ──defines──► Agent Team Templates
Agent Team Template ──spawns──► Swarm State Files (1 per agent)
Swarm State Files ──reference──► Agent definitions (from any installed plugin)
Plugin (sdd-governance) ──enforces──► All other Plugins (via hooks)
```

---
