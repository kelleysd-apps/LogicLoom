# Skill Activation Triggers

**Version**: 1.0.0
**Feature**: 002-skills-first-architecture
**Task**: T044
**Purpose**: Comprehensive mapping of triggers to skills for skills-first routing

---

## Overview

This document provides the authoritative mapping of trigger keywords and commands
to skills, and of domain keywords to domain briefs. Used by governance domain
detection to route work.

---

## Command Routes (Slash Commands)

Exact matches for slash commands:

| Command | Skill Path | Skill |
|---------|------------|-------|
| `/specify` | sdd-workflow/sdd-specification | unified-specification skill |
| `/plan` | sdd-workflow/sdd-planning | planning-agent skill |
| `/tasks` | sdd-workflow/sdd-tasks | task-generation skill |
| `/debug` | sdd-workflow/sdd-debug | auto-debug skill (auto-debug-agent) |
| `/finalize` | governance/finalize | finalize skill (loom-git) |
| `/create-agent` | creation/create-agent | agent-creation skill (subagent-architect) |
| `/create-skill` | creation/create-skill | skill-creation skill (subagent-architect) |
| `/create-prd` | creation/create-prd | prd-creation skill (prd-specialist) |
| `/initialize-project` | project-initialization/initialize-project | project-initialization skill |

---

## Domain Triggers

Technical domains route **keyword → domain → brief**. Keywords are mapped to a
domain in `config/domains.conf`; the consolidated worker brief is injected at
swarm/team spawn time via `get_domain_brief <domain>`
(`plugins/loom-governance/domain-briefs/<domain>.md`). Domains are *briefs*, not
plugins.

### Frontend Domain

**Triggers**: UI, component, React, CSS, form, responsive, page, layout, style

**Route**: domain `frontend` → `get_domain_brief frontend`

**Examples**:
- "Create a login form component"
- "Style the navigation bar"
- "Make the page responsive"

### Backend Domain

**Triggers**: API, endpoint, server, middleware, service, authentication

**Route**: domain `backend` → `get_domain_brief backend`

**Examples**:
- "Create a user registration endpoint"
- "Add authentication middleware"
- "Design the API for orders"

### Database Domain

**Triggers**: schema, migration, query, SQL, RLS, table, index, data model

**Route**: domain `database` → `get_domain_brief database`

**Examples**:
- "Create the users table schema"
- "Write a migration for adding email column"
- "Add RLS policies for multi-tenant access"

### Testing Domain

**Triggers**: test, TDD, E2E, coverage, unit test, QA, assertion, mock

**Route**: domain `testing` → `get_domain_brief testing`

**Examples**:
- "Write unit tests for the user service"
- "Create E2E tests for login flow"
- "Check test coverage"

### Security Domain

**Triggers**: security, encryption, XSS, secrets, vulnerability, OWASP

**Route**: domain `security` → `get_domain_brief security`

**Examples**:
- "Review code for security vulnerabilities"
- "Implement input sanitization"
- "Check for SQL injection risks"

### Performance Domain

**Triggers**: performance, optimize, cache, benchmark, latency, speed

**Route**: domain `performance` → `get_domain_brief performance`

**Examples**:
- "Optimize database queries"
- "Set up caching for API responses"
- "Benchmark the application"

### DevOps Domain

**Triggers**: deploy, CI/CD, Docker, pipeline, infrastructure, Kubernetes

**Route**: domain `devops` → `get_domain_brief devops`

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

**Skill**: finalize skill (loom-git plugin)

### Compliance

**Triggers**: compliance, constitutional check, validation

**Skill**: constitutional-compliance skill (constitutional-governance-agent)

---

## Orchestration Triggers

### Multi-Domain Work

**Detection**: 2+ domains identified in message

**Skill**: team-orchestration skill (loom-orchestrator)

**Examples**:
- "Build user profile with database and UI" (frontend + database)
- "Create auth system with API and security" (backend + security)
- "Deploy app with monitoring" (devops + performance)

### Migration Work

**Triggers**: migration, migrate, upgrade pattern, convert to skills

**Skill**: multi-skill-workflow skill (loom-orchestrator)

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

**Skill**: mcp-server-setup skill (loom-maintenance)

---

## Selection Rules

When multiple routes match:

1. **Prefer the most specific match** (exact command > keyword > domain)
2. **Workflow-phase skills** take precedence for `/`-commands
3. **Domain briefs** apply for technical work; 2+ domains → team-orchestration / `/swarm`
4. **Default to direct execution** when nothing specialized matches

---

## Fallback Rules

If no route matches:

1. **Check command routes** for exact match
2. **Check keyword routes** for partial match
3. **Check domain routes** (keyword → domain → `get_domain_brief`)
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
