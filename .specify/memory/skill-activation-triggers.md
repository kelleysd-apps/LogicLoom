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

| Command | Skill Path | Agent |
|---------|------------|-------|
| `/specify` | sdd-workflow/sdd-specification | specification-orchestrator |
| `/plan` | sdd-workflow/sdd-planning | specification-orchestrator |
| `/tasks` | sdd-workflow/sdd-tasks | specification-orchestrator |
| `/debug` | sdd-workflow/sdd-debug | auto-debug-agent |
| `/finalize` | governance/finalize | finalizer-agent |
| `/create-agent` | creation/create-agent | system-architect |
| `/create-skill` | creation/create-skill | system-architect |
| `/create-prd` | creation/create-prd | specification-orchestrator |
| `/initialize-project` | project-initialization/initialize-project | specification-orchestrator |

---

## Domain Triggers

### Frontend Domain

**Triggers**: UI, component, React, CSS, form, responsive, page, layout, style

**Primary Skill**: domain/frontend-operations
**Agent**: implementation-specialist

**Examples**:
- "Create a login form component"
- "Style the navigation bar"
- "Make the page responsive"

### Backend Domain

**Triggers**: API, endpoint, server, middleware, service, authentication

**Primary Skill**: domain/backend-operations
**Fallback Skill**: domain/api-design
**Agent**: backend-architect, implementation-specialist

**Examples**:
- "Create a user registration endpoint"
- "Add authentication middleware"
- "Design the API for orders"

### Database Domain

**Triggers**: schema, migration, query, SQL, RLS, table, index, data model

**Primary Skill**: domain/database-operations
**Fallback Skill**: sdd-workflow/sdd-planning
**Agent**: database-specialist

**Examples**:
- "Create the users table schema"
- "Write a migration for adding email column"
- "Add RLS policies for multi-tenant access"

### Testing Domain

**Triggers**: test, TDD, E2E, coverage, unit test, QA, assertion, mock

**Primary Skill**: domain/testing-operations
**Agent**: quality-specialist

**Examples**:
- "Write unit tests for the user service"
- "Create E2E tests for login flow"
- "Check test coverage"

### Security Domain

**Triggers**: security, encryption, XSS, secrets, vulnerability, OWASP

**Primary Skill**: domain/security-operations
**Fallback Skill**: domain/backend-operations
**Agent**: quality-specialist

**Examples**:
- "Review code for security vulnerabilities"
- "Implement input sanitization"
- "Check for SQL injection risks"

### Performance Domain

**Triggers**: performance, optimize, cache, benchmark, latency, speed

**Primary Skill**: domain/performance-operations
**Fallback Skill**: domain/devops-operations
**Agent**: operations-specialist

**Examples**:
- "Optimize database queries"
- "Set up caching for API responses"
- "Benchmark the application"

### DevOps Domain

**Triggers**: deploy, CI/CD, Docker, pipeline, infrastructure, Kubernetes

**Primary Skill**: domain/devops-operations
**Agent**: operations-specialist

**Examples**:
- "Set up CI/CD pipeline"
- "Create Docker configuration"
- "Deploy to production"

---

## SDD Workflow Triggers

### Specification Phase

**Triggers**: specify, specification, requirements, feature spec, user story

**Skill**: sdd-workflow/sdd-specification
**Agent**: specification-orchestrator

### Planning Phase

**Triggers**: plan, implementation plan, technical research, data model, contract

**Skill**: sdd-workflow/sdd-planning
**Agent**: specification-orchestrator

### Tasks Phase

**Triggers**: tasks, task list, breakdown, dependencies, implementation tasks

**Skill**: sdd-workflow/sdd-tasks
**Agent**: specification-orchestrator

### Debug Phase

**Triggers**: debug, troubleshoot, error, deployment issue, bug

**Skill**: sdd-workflow/sdd-debug
**Agent**: auto-debug-agent

---

## Governance Triggers

### Finalization

**Triggers**: finalize, pre-commit, commit check, ready to commit

**Skill**: governance/finalize
**Agent**: finalizer-agent

### Compliance

**Triggers**: compliance, constitutional check, validation

**Skill**: validation/constitutional-compliance
**Agent**: verifier-agent

---

## Orchestration Triggers

### Multi-Domain Work

**Detection**: 2+ domains identified in message

**Skill**: orchestration/multi-skill-workflow
**Agent**: workflow-coordinator

**Examples**:
- "Build user profile with database and UI" (frontend + database)
- "Create auth system with API and security" (backend + security)
- "Deploy app with monitoring" (devops + performance)

### Migration Work

**Triggers**: migration, migrate, upgrade pattern, convert to skills

**Skill**: orchestration/migration-workflow
**Agent**: workflow-coordinator

---

## Creation Triggers

### Agent Creation

**Triggers**: create agent, new agent, /create-agent

**Skill**: creation/create-agent
**Agent**: system-architect

### Skill Creation

**Triggers**: create skill, new skill, /create-skill

**Skill**: creation/create-skill
**Agent**: system-architect

### PRD Creation

**Triggers**: create PRD, product requirements, /create-prd

**Skill**: creation/create-prd
**Agent**: specification-orchestrator

---

## Integration Triggers

### MCP Server

**Triggers**: MCP, mcp-add, MCP server, tool integration

**Skill**: integration/mcp-server-setup
**Agent**: operations-specialist

---

## RL Selection Rules

When multiple skills match:

1. **Check selection weights** from skill-index.json
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
- Agent exists in agent-index.json

---

*Skill activation triggers maintained by framework*
*Updates must follow constitutional amendment process*
