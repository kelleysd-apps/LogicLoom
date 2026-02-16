# Agent Collaboration Triggers

**Purpose**: Define when and how to delegate work to specialized agents (Constitutional Principle X)

**Version**: 2.0.0
**Last Updated**: 2026-02-15
**Authority**: Constitutional Principle X - Agent Delegation Protocol

---

## Overview

This document defines the **automatic delegation triggers** that determine when general-purpose agents must delegate work to specialized agents. Constitutional Principle X mandates that specialized work be delegated to specialized agents.

### Work Session Initiation Protocol (MANDATORY)

Every work session must follow these 4 steps:

1. **READ CONSTITUTION** - First action, no exceptions
2. **ANALYZE TASK DOMAIN** - Use this document to identify triggers
3. **DELEGATION DECISION** - Delegate if triggers matched
4. **EXECUTION** - Execute or invoke specialized agent

---

## Department Structures

### Available Agents by Department

**Architecture Department**:
- `api-design` skill (sdd-domain-backend plugin) - API architecture, contract design
- `service-architecture` skill (sdd-domain-backend plugin) - System design, scalability
- `subagent-architect` agent (sdd-creation plugin) - Creating new SDD-compliant agents

**Data Department**:
- `schema-design` skill (sdd-domain-database plugin) - Schema design, queries, migrations, RLS, indexing

**Engineering Department**:
- `frontend-operations` skill (sdd-domain-frontend plugin) - React/Next.js, UI components, state management

**Operations Department**:
- `monitoring` skill (sdd-domain-devops plugin) - CI/CD, Docker, deployment, infrastructure
- `performance-operations` skill (sdd-domain-performance plugin) - Optimization, caching, benchmarking

**Product Department**:
- `sdd-specification` skill (sdd-specification plugin) - Feature specs, requirements, user stories
- `planning-agent` skill (sdd-specification plugin) - Implementation planning, technical research, contract design
- `task-generation` skill (sdd-specification plugin) - Task breakdown, dependency tracking
- `team-orchestration` skill (sdd-orchestrator plugin) - Multi-agent workflow coordination

**Quality Department**:
- `testing-operations` skill (sdd-domain-testing plugin) - Test strategy, test creation, QA
- `security-operations` skill (sdd-domain-security plugin) - Security review, vulnerability assessment

---

## Domain Trigger Keywords

### Frontend Development

**Primary Keywords** (MUST delegate):
- UI, user interface, component, view, screen, page
- React, Next.js, Vue, Angular, Svelte
- CSS, styling, theme, design system
- State management, Redux, Zustand, Context
- Responsive, mobile, tablet, desktop
- Animation, transition, interaction
- Form, input, validation (UI-side)
- Routing, navigation

**Example Phrases**:
- "Create a login form component"
- "Style the dashboard with dark theme"
- "Add responsive navigation menu"
- "Implement state management for user data"

**Delegate To**: `frontend-operations` skill (sdd-domain-frontend plugin)

---

### Backend Development

**Primary Keywords** (MUST delegate):
- API, endpoint, route, controller, handler
- Server, backend, service, microservice
- Authentication, auth, login, session, JWT, OAuth
- Authorization, permissions, roles, access control
- Middleware, interceptor, guard
- Business logic, domain logic
- Integration, webhook, third-party API
- Background job, queue, worker
- Real-time, WebSocket, SSE

**Example Phrases**:
- "Create user authentication API"
- "Implement JWT token refresh endpoint"
- "Add role-based access control"
- "Build webhook handler for payments"

**Delegate To**: `api-design` or `service-architecture` skill (sdd-domain-backend plugin)

---

### Database Operations

**Primary Keywords** (MUST delegate):
- Database, DB, SQL, PostgreSQL, MySQL, MongoDB
- Schema, table, collection, model, entity
- Migration, seed, fixture
- Query, SELECT, INSERT, UPDATE, DELETE, JOIN
- Index, indexing, performance
- RLS, row-level security, policy
- Transaction, ACID, rollback
- Relationship, foreign key, reference
- ORM, Prisma, TypeORM, Sequelize, Mongoose
- Backup, restore, replication

**Example Phrases**:
- "Design user profiles schema"
- "Create RLS policies for multi-tenancy"
- "Add indexes for query performance"
- "Write migration for new table"

**Delegate To**: `schema-design` skill (sdd-domain-database plugin)

---

### Testing & QA

**Primary Keywords** (MUST delegate):
- Test, testing, QA, quality assurance
- Unit test, integration test, E2E test, end-to-end
- TDD, test-driven development
- Contract test, API test
- Mock, stub, spy, fixture
- Test coverage, assertion
- Jest, Vitest, Mocha, Chai, Pytest
- Playwright, Cypress, Selenium
- Test scenario, test case, test plan

**Example Phrases**:
- "Write unit tests for auth service"
- "Create E2E tests for checkout flow"
- "Add integration tests for API"
- "Set up test fixtures and mocks"

**Delegate To**: `testing-operations` skill (sdd-domain-testing plugin)

---

### Security

**Primary Keywords** (MUST delegate):
- Security, vulnerability, exploit
- XSS, CSRF, SQL injection, injection attack
- Encryption, hashing, bcrypt, crypto
- Secret, credential, API key, token
- HTTPS, SSL, TLS, certificate
- OWASP, security audit, penetration test
- Sanitization, validation (security context)
- Rate limiting, brute force protection
- CORS, CSP, security headers
- Privacy, GDPR, PII, data protection

**Example Phrases**:
- "Review authentication for security issues"
- "Add input sanitization to prevent XSS"
- "Implement rate limiting on login"
- "Encrypt sensitive user data"

**Delegate To**: `security-operations` skill (sdd-domain-security plugin)

---

### Performance Optimization

**Primary Keywords** (MUST delegate):
- Performance, optimization, speed, latency
- Caching, cache, Redis, Memcached
- CDN, content delivery
- Lazy loading, code splitting, bundling
- Database optimization, query optimization
- Profiling, benchmark, metrics
- Memory leak, garbage collection
- Pagination, infinite scroll
- Debounce, throttle
- Worker thread, parallel processing

**Example Phrases**:
- "Optimize slow database queries"
- "Add caching to API responses"
- "Improve page load speed"
- "Profile and fix memory leaks"

**Delegate To**: `performance-operations` skill (sdd-domain-performance plugin)

---

### DevOps & Infrastructure

**Primary Keywords** (MUST delegate):
- Deploy, deployment, release, rollout
- CI/CD, continuous integration, pipeline
- Docker, Dockerfile, container, Kubernetes
- Cloud, AWS, GCP, Azure, Vercel, Railway
- Infrastructure, server, hosting
- Environment, staging, production, dev
- Build, compile, bundle, artifact
- Monitoring, logging, observability (infra context)
- Load balancing, scaling, autoscaling

**Example Phrases**:
- "Set up CI/CD pipeline for automated testing"
- "Containerize application with Docker"
- "Deploy to production on AWS"
- "Configure environment variables for staging"

**Delegate To**: `monitoring` skill (sdd-domain-devops plugin)

---

### Specification & Requirements

**Primary Keywords** (MUST delegate):
- Specification, spec, requirements
- Feature, functionality, capability
- User story, use case, scenario
- Acceptance criteria, success criteria
- Scope, MVP, milestone
- Stakeholder, user, customer
- PRD, product requirements document
- Flow, workflow, user journey

**Example Phrases**:
- "Create specification for user authentication"
- "Write user stories for dashboard"
- "Define acceptance criteria for feature"
- "Document requirements for API"

**Delegate To**: `sdd-specification` skill (sdd-specification plugin)

---

### Implementation Planning

**Primary Keywords** (MUST delegate):
- Implementation plan, technical plan, architecture plan, planning phase
- /plan command, Phase 0, Phase 1, Phase 2
- Technical research, library evaluation, framework selection
- Technology stack, tech stack selection
- API design, contract design, schema design, OpenAPI, GraphQL
- Data model, entity design, relationship modeling
- Quickstart, test scenario planning
- NEEDS CLARIFICATION, technical unknowns
- Research.md, data-model.md, contracts/, quickstart.md
- Best practices research, pattern recommendations

**Example Phrases**:
- "Create implementation plan for feature"
- "Execute the /plan command"
- "Research technology stack options"
- "Design API contracts and data models"
- "Evaluate libraries for this feature"
- "Generate contracts and test scenarios"

**Workflow Context**:
- Phase 2 of SDD workflow (between specification and tasks)
- Receives: spec.md from sdd-specification skill
- Produces: plan.md, research.md, data-model.md, contracts/, quickstart.md
- Hands off to: task-generation skill for task generation

**Delegate To**: `planning-agent` skill (sdd-specification plugin)

---

### Task Management

**Primary Keywords** (MUST delegate):
- Task, todo, checklist, action items
- /tasks command, task generation, task list
- Dependency, prerequisite, blocker
- Parallel, concurrent, sequential
- Priority, critical, high, medium, low
- Estimate, effort, timeline
- Breakdown, decompose, split
- tasks.md generation

**Example Phrases**:
- "Break down feature into tasks"
- "Execute the /tasks command"
- "Create task list with dependencies"
- "Generate implementation checklist"
- "Prioritize tasks by importance"

**Workflow Context**:
- Phase 3 of SDD workflow (after planning, before implementation)
- Receives: plan.md + artifacts from planning-agent skill
- Produces: tasks.md with dependency-ordered task list
- Hands off to: Domain-specific skills for task execution

**Delegate To**: `task-generation` skill (sdd-specification plugin)

---

### Multi-Agent Orchestration

**Primary Keywords** (MUST delegate):
- Multi-domain, cross-functional, full-stack
- Complex feature, large feature, major feature
- Multiple agents, agent coordination
- Workflow, pipeline, process
- End-to-end, E2E (when referring to full feature)
- Integration (when multiple systems involved)

**Example Phrases**:
- "Implement user authentication system" (needs frontend + backend + database + security)
- "Build complete payment flow" (multiple domains)
- "Create full CRUD feature with UI and API"
- "Develop multi-tenant system" (architecture + database + security + frontend)

**Multi-Domain Detection**:
If task description contains keywords from 2+ domains → Use `team-orchestration` skill (sdd-orchestrator plugin)

**Delegate To**: `team-orchestration` skill (sdd-orchestrator plugin)

---

### Agent Creation

**Primary Keywords** (MUST delegate):
- Create agent, new agent, agent definition
- Specialized agent, domain agent
- Agent purpose, agent capabilities
- SDD-compliant agent, constitutional agent

**Example Phrases**:
- "Create new agent for data analysis"
- "Build agent for email handling"
- "Define agent for report generation"

**Delegate To**: `subagent-architect`

---

## Delegation Decision Tree

```
START
  ↓
Read Constitution (Step 1)
  ↓
Analyze Task Description (Step 2)
  ↓
Scan for Trigger Keywords
  ↓
┌─────────────────────────────────┐
│ Keywords from 2+ domains found? │
└─────────────────────────────────┘
  ↓ YES                        NO ↓
  ↓                               ↓
Use team-orchestration       Keywords from 1 domain?
  ↓                               ↓
  ↓                         YES ↙   ↘ NO
  ↓                          ↓         ↓
  ↓                    Delegate to    Execute
  ↓                    domain         directly
  ↓                    skill          (if simple)
  ↓                          ↓         ↓
  └──────────────────────────┴─────────┘
                    ↓
            EXECUTE TASK
```

---

## Multi-Agent Scenario Examples

### Example 1: User Authentication System

**Task**: "Implement user authentication with email/password"

**Analysis**:
- Keywords: authentication (backend), login (frontend), database (data), security (quality)
- Domains: Backend, Frontend, Database, Security = 4 domains

**Decision**: Multi-agent scenario → Delegate to `team-orchestration` skill (sdd-orchestrator plugin)

**Orchestration Workflow**:
1. `sdd-specification` skill: Create feature spec
2. `api-design` skill: Design API endpoints
3. `schema-design` skill: Design user schema, RLS policies
4. `security-operations` skill: Review auth flow, encryption
5. `frontend-operations` skill: Implement login UI
6. `testing-operations` skill: Create E2E tests

---

### Example 2: API Endpoint Creation

**Task**: "Create GET /api/users endpoint with pagination"

**Analysis**:
- Keywords: API, endpoint (backend), pagination (backend)
- Domains: Backend only = 1 domain

**Decision**: Single-domain scenario → Delegate to `api-design` skill (sdd-domain-backend plugin)

---

### Example 3: Database Schema Design

**Task**: "Design database schema for blog posts with categories"

**Analysis**:
- Keywords: database, schema, table relationships
- Domains: Database only = 1 domain

**Decision**: Single-domain scenario → Delegate to `schema-design` skill (sdd-domain-database plugin)

---

### Example 4: Performance Optimization

**Task**: "Optimize slow loading dashboard page"

**Analysis**:
- Keywords: optimize, performance, slow loading
- Domains: Performance = 1 domain (but may expand after analysis)

**Decision**: Start with `performance-operations` skill (sdd-domain-performance plugin) → May delegate to frontend/backend if needed

---

### Example 5: Full Feature Development

**Task**: "Build complete blog system with posts, comments, and categories"

**Analysis**:
- Scope: Full feature with CRUD, UI, API, database
- Domains: Frontend, Backend, Database, Testing = 4+ domains

**Decision**: Complex multi-domain → Delegate to `team-orchestration` skill (sdd-orchestrator plugin)

**Orchestration Workflow**:
1. `sdd-specification` skill: Create feature specification
2. `api-design` skill: Design data model and API
3. `schema-design` skill: Design schema and relationships
4. `frontend-operations` skill: Implement UI components
5. `testing-operations` skill: Create test suite
6. `security-operations` skill: Review for vulnerabilities

---

## Agent Routing Logic

### Single-Domain Routing

**When to use single domain skill**:
- Task clearly within one domain
- Simple, straightforward requirements
- No cross-functional dependencies
- Time-critical operations

**Pattern**:
```
Task → Analyze Domain → Select Domain Skill → Delegate → Execute
```

### Multi-Domain Orchestration

**When to use orchestration skill**:
- Task spans 2+ domains
- Complex feature requiring multiple expertise areas
- Needs quality gates between stages
- Production-critical changes

**Pattern**:
```
Task → team-orchestration skill → Coordinate Skills → Manage Handoffs → Validate → Complete
```

---

## Context Handoff Format

When multiple skills work on same feature, use structured context handoff:

```json
{
  "feature": "user-authentication",
  "phase": "implementation",
  "previous_skill": "api-design",
  "next_skill": "frontend-operations",
  "context": {
    "api_endpoints": [
      "POST /api/auth/login",
      "POST /api/auth/register",
      "POST /api/auth/refresh"
    ],
    "contracts": "specs/005-auth/contracts/",
    "database_schema": "specs/005-auth/data-model.md",
    "requirements": "specs/005-auth/spec.md"
  },
  "handoff_notes": "API implemented and tested. Frontend should use /api/auth/login with email/password in request body. Returns JWT token in response."
}
```

---

## Non-Delegation Scenarios

**When NOT to delegate** (execute directly):

1. **Simple file operations**:
   - Reading existing files
   - Checking git status
   - Listing directory contents

2. **Documentation-only tasks**:
   - Reading specifications
   - Answering questions about existing code
   - Explaining how something works

3. **Coordination tasks**:
   - Determining which skill to use
   - Analyzing task complexity
   - Project planning (high-level)

4. **Constitutional tasks**:
   - Reading constitution
   - Running compliance checks
   - Sanitization audits

**Pattern**: If task involves no specialized domain work, execute directly.

---

## Enforcement

### Constitutional Requirement

Principle X mandates:
- MUST read constitution first
- MUST analyze domain
- MUST delegate if triggers matched
- MUST NOT execute specialized work directly

### Compliance Checking

Run automated check:
```bash
./.specify/scripts/bash/constitutional-check.sh
```

Checks for:
- Constitution read at session start
- Domain analysis performed
- Delegation decision documented
- Appropriate skill invoked

---

## Quick Reference Table

| Domain | Skill / Agent | Trigger Keywords |
|--------|---------------|------------------|
| Frontend | frontend-operations (sdd-domain-frontend) | UI, React, component, styling, responsive |
| Backend | api-design / service-architecture (sdd-domain-backend) | API, endpoint, server, auth, business logic |
| Database | schema-design (sdd-domain-database) | schema, migration, query, RLS, index |
| Testing | testing-operations (sdd-domain-testing) | test, E2E, unit, integration, QA |
| Security | security-operations (sdd-domain-security) | security, XSS, encryption, vulnerability |
| Performance | performance-operations (sdd-domain-performance) | optimization, caching, benchmark, speed |
| DevOps | monitoring (sdd-domain-devops) | deploy, CI/CD, Docker, infrastructure |
| Specs | sdd-specification (sdd-specification) | spec, requirements, user story |
| Planning | planning-agent (sdd-specification) | implementation plan, research, contracts |
| Tasks | task-generation (sdd-specification) | task list, breakdown, dependency |
| Multi-Domain | team-orchestration (sdd-orchestrator) | 2+ domains, complex feature |
| Agent Creation | subagent-architect | create agent, new agent |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0.0 | 2026-02-15 | Updated for v5.0 refactor: 14 agents converted to enhanced skills |
| 1.1.0 | 2025-12-01 | Updated for Constitution v1.6.0 (15 principles) |
| 1.0.0 | 2025-11-06 | Initial creation for Constitution v1.5.0 |

---

**Authority**: Constitutional Principle X
**Enforcement**: constitutional-check.sh
**Referenced By**: constitution.md, all agent/skill context files
