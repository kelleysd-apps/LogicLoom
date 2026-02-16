# Skill Activation Triggers

**Version**: 1.0.0
**Feature**: 002-skills-first-architecture
**Task**: T044
**Purpose**: Comprehensive mapping of triggers to skills for skills-first routing

---

## Overview

This document provides the authoritative mapping of trigger keywords and commands
to skills. Used by the Router Agent for RL-enhanced skill selection.

---

## Command Routes (Slash Commands)

Exact matches for slash commands:

| Command | Skill Path | Skill |
|---------|------------|-------|
| `/specify` | sdd-workflow/sdd-specification | unified-specification skill |
| `/plan` | sdd-workflow/sdd-planning | planning-agent skill |
| `/tasks` | sdd-workflow/sdd-tasks | task-generation skill |
| `/debug` | sdd-workflow/sdd-debug | auto-debug skill (auto-debug-agent) |
| `/finalize` | governance/finalize | finalize skill (sdd-git) |
| `/create-agent` | creation/create-agent | agent-creation skill (subagent-architect) |
| `/create-skill` | creation/create-skill | skill-creation skill (subagent-architect) |
| `/create-prd` | creation/create-prd | prd-creation skill (prd-specialist) |
| `/initialize-project` | project-initialization/initialize-project | project-initialization skill |

---

## Domain Triggers

### Frontend Domain

**Triggers**: UI, component, React, CSS, form, responsive, page, layout, style

**Primary Skill**: frontend-operations skill (sdd-domain-frontend)

**Examples**:
- "Create a login form component"
- "Style the navigation bar"
- "Make the page responsive"

### Backend Domain

**Triggers**: API, endpoint, server, middleware, service, authentication

**Primary Skill**: api-design skill (sdd-domain-backend)
**Fallback Skill**: service-architecture skill (sdd-domain-backend)

**Examples**:
- "Create a user registration endpoint"
- "Add authentication middleware"
- "Design the API for orders"

### Database Domain

**Triggers**: schema, migration, query, SQL, RLS, table, index, data model

**Primary Skill**: schema-design skill (sdd-domain-database)
**Fallback Skill**: planning-agent skill (sdd-specification)

**Examples**:
- "Create the users table schema"
- "Write a migration for adding email column"
- "Add RLS policies for multi-tenant access"

### Testing Domain

**Triggers**: test, TDD, E2E, coverage, unit test, QA, assertion, mock

**Primary Skill**: testing-operations skill (sdd-domain-testing)

**Examples**:
- "Write unit tests for the user service"
- "Create E2E tests for login flow"
- "Check test coverage"

### Security Domain

**Triggers**: security, encryption, XSS, secrets, vulnerability, OWASP

**Primary Skill**: security-operations skill (sdd-domain-security)
**Fallback Skill**: api-design skill (sdd-domain-backend)

**Examples**:
- "Review code for security vulnerabilities"
- "Implement input sanitization"
- "Check for SQL injection risks"

### Performance Domain

**Triggers**: performance, optimize, cache, benchmark, latency, speed

**Primary Skill**: performance-operations skill (sdd-domain-performance)
**Fallback Skill**: monitoring skill (sdd-domain-devops)

**Examples**:
- "Optimize database queries"
- "Set up caching for API responses"
- "Benchmark the application"

### DevOps Domain

**Triggers**: deploy, CI/CD, Docker, pipeline, infrastructure, Kubernetes

**Primary Skill**: monitoring skill (sdd-domain-devops)

**Examples**:
- "Set up CI/CD pipeline"
- "Create Docker configuration"
- "Deploy to production"

---

## SDD Workflow Triggers

### Specification Phase

**Triggers**: specify, specification, requirements, feature spec, user story

**Skill**: unified-specification skill (sdd-specification)

### Planning Phase

**Triggers**: plan, implementation plan, technical research, data model, contract

**Skill**: planning-agent skill (sdd-specification)

### Tasks Phase

**Triggers**: tasks, task list, breakdown, dependencies, implementation tasks

**Skill**: task-generation skill (sdd-specification)

### Debug Phase

**Triggers**: debug, troubleshoot, error, deployment issue, bug

**Skill**: auto-debug skill (auto-debug-agent plugin)

---

## Governance Triggers

### Finalization

**Triggers**: finalize, pre-commit, commit check, ready to commit

**Skill**: finalize skill (sdd-git plugin)

### Compliance

**Triggers**: compliance, constitutional check, validation

**Skill**: constitutional-compliance skill (constitutional-governance-agent)

---

## Orchestration Triggers

### Multi-Domain Work

**Detection**: 2+ domains identified in message

**Skill**: team-orchestration skill (sdd-orchestrator)

**Examples**:
- "Build user profile with database and UI" (frontend + database)
- "Create auth system with API and security" (backend + security)
- "Deploy app with monitoring" (devops + performance)

### Migration Work

**Triggers**: migration, migrate, upgrade pattern, convert to skills

**Skill**: multi-skill-workflow skill (sdd-orchestrator)

---

## Creation Triggers

### Agent Creation

**Triggers**: create agent, new agent, /create-agent

**Skill**: agent-creation skill (subagent-architect)

### Skill Creation

**Triggers**: create skill, new skill, /create-skill

**Skill**: skill-creation skill (subagent-architect)

### PRD Creation

**Triggers**: create PRD, product requirements, /create-prd

**Skill**: prd-creation skill (prd-specialist)

---

## Integration Triggers

### MCP Server

**Triggers**: MCP, mcp-add, MCP server, tool integration

**Skill**: mcp-server-setup skill (sdd-maintenance)

---

## RL Selection Rules

When multiple skills match:

1. **Check selection weights** from plugin manifests (plugins/*/plugin.json)
2. **Apply softmax** with configured temperature
3. **Select skill** probabilistically (or deterministically in testing)
4. **Log selection** for RL feedback

### Selection Weight Update

After skill execution:
```
new_weight = alpha * reward + (1 - alpha) * old_weight

Where:
- alpha = 0.1 (learning rate)
- reward = 0.5 * success + 0.3 * token_efficiency + 0.2 * user_satisfaction
```

---

## Fallback Rules

If no skill matches:

1. **Check command routes** for exact match
2. **Check keyword routes** for partial match
3. **Check domain routes** for domain-based routing
4. **Default to direct execution** if no match

---

## Validation

Triggers are validated against:
- Uniqueness within category
- No conflicting routes
- Valid skill path references
- Skill exists in plugin manifests

---

*Skill activation triggers maintained by framework*
*Updates must follow constitutional amendment process*
