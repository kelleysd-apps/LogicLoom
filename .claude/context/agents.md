# Agents Context Module
<!-- Auto-generated from CLAUDE.md and agent files - Sprint 3 Task T024 -->
<!-- Module: Agent registry, delegation protocol, multi-agent coordination -->

## Agent Delegation Protocol

**Constitutional Principle X** requires specialized work be delegated to specialized agents.

See `.specify/memory/agent-collaboration-triggers.md` for:
- Domain trigger keywords (Frontend, Backend, Database, Testing, Security, Performance, DevOps, etc.)
- Single-agent vs multi-agent decision tree
- Context handoff format
- 19+ specialized agents across 6 departments

**Quick Reference**: If task contains domain keywords (test, UI, database, API, security, etc.) → Delegate to specialized agent

---

## Domain → Agent Mapping

### Quick Reference Table

| Domain | Keywords | Agent |
|--------|----------|-------|
| Frontend | UI, component, React, CSS, responsive | `frontend-specialist` |
| Backend | API, endpoint, service, auth, server | `backend-architect` |
| Database | schema, migration, query, SQL, seed | `database-specialist` |
| Testing | test, E2E, integration, mock, QA | `testing-specialist` |
| Security | security, XSS, encryption, vulnerability | `security-specialist` |
| Performance | optimize, cache, benchmark, speed | `performance-engineer` |
| DevOps | deploy, CI/CD, Docker, infrastructure | `devops-engineer` |
| Specification | spec, requirements, user story | `specification-agent` |
| Planning | /plan, research, contract design | `planning-agent` |
| Tasks | /tasks, task breakdown, dependencies | `tasks-agent` |
| Multi-Domain | 2+ domains detected | `task-orchestrator` |

---

## Available Agents by Department

### Architecture Department

**backend-architect**
- **Purpose**: System design, API architecture, scalability planning
- **Competencies**: REST/GraphQL APIs, microservices, serverless architecture, authentication/authorization patterns, system integration
- **Usage**: `Use the backend-architect agent to...`
- **Location**: `.claude/agents/architecture/backend-architect.md`

**subagent-architect**
- **Purpose**: Creating new SDD-compliant agents with constitutional alignment
- **Competencies**: Agent design, tool selection, memory structure, department classification, governance setup
- **Usage**: `Use the subagent-architect agent to create a new agent for...`
- **Location**: `.claude/agents/architecture/subagent-architect.md`

---

### Data Department

**database-specialist**
- **Purpose**: Database design, query optimization, migrations, RLS policies
- **Competencies**: PostgreSQL/Supabase, schema design, indexing, Drizzle ORM, data modeling, query performance
- **Usage**: `Use the database-specialist agent to...`
- **Location**: `.claude/agents/data/database-specialist.md`

---

### Engineering Department

**frontend-specialist**
- **Purpose**: React/Next.js UI development, component creation, state management
- **Competencies**: React 18, TypeScript, TailwindCSS, Radix UI, Framer Motion, responsive design, accessibility
- **Usage**: `Use the frontend-specialist agent to...`
- **Location**: `.claude/agents/engineering/frontend-specialist.md`

**full-stack-developer**
- **Purpose**: End-to-end feature development spanning frontend and backend
- **Competencies**: React + Express.js, API integration, state management, authentication flows, database integration
- **Usage**: `Use the full-stack-developer agent to...`
- **Location**: `.claude/agents/engineering/full-stack-developer.md`

---

### Marketing Department

**content-strategist**
- **Purpose**: Content planning, editorial calendar, SEO keyword research, content brief creation
- **Competencies**: Content strategy, audience analysis, keyword research, content briefs, editorial planning
- **Usage**: `Use the content-strategist agent to...`
- **Location**: `.claude/agents/marketing/content-strategist.md`

**copywriter-agent**
- **Purpose**: Blog article writing in Brian Kelley's authentic voice
- **Competencies**: First-person writing, contrarian takes, founder content, LinkedIn-style paragraphs, avoiding AI-sounding language
- **Voice Profile**: Direct, honest, practical, opinionated, conversational, confident
- **Workflow Position**: research-agent → content-strategist → **copywriter-agent** → seo-specialist
- **Usage**: `Use the copywriter-agent agent to write a blog article about...`
- **Triggers**: write, draft, article, blog post, content creation, Brian's voice, copywriting
- **Location**: `.claude/agents/marketing/copywriter-agent.md`

**research-agent**
- **Purpose**: Deep research for AI topics, trends, tools, and competitor analysis
- **Competencies**: Market intelligence, trend analysis, source gathering, expert opinion research, citation management
- **Workflow Position**: **research-agent** → content-strategist → copywriter-agent → seo-specialist
- **Usage**: `Use the research-agent to research [topic]...`
- **Triggers**: Research, investigate, trends, competitor analysis, market intelligence, sources, citations
- **Location**: `.claude/agents/marketing/research-agent.md`

**seo-specialist**
- **Purpose**: SEO optimization, meta tags, heading structure, internal linking
- **Competencies**: On-page SEO, keyword optimization, meta descriptions, heading hierarchy, link building
- **Usage**: `Use the seo-specialist agent to...`
- **Location**: `.claude/agents/marketing/seo-specialist.md`

---

### Operations Department

**devops-engineer**
- **Purpose**: CI/CD, Docker, deployment, infrastructure management
- **Competencies**: Vercel deployments, GitHub Actions, Docker, environment management, build optimization
- **Usage**: `Use the devops-engineer agent to...`
- **Location**: `.claude/agents/operations/devops-engineer.md`

**performance-engineer**
- **Purpose**: Performance optimization, caching, benchmarking
- **Competencies**: Query optimization, caching strategies, CDN configuration, bundle size reduction, performance profiling
- **Usage**: `Use the performance-engineer agent to...`
- **Location**: `.claude/agents/operations/performance-engineer.md`

---

### Product Department

**prd-specialist**
- **Purpose**: Product Requirements Document (PRD) creation for Phase 0 project initialization
- **Competencies**: Product strategy, user research, requirements gathering, constitutional customization, release planning
- **Workflow Position**: **prd-specialist** (/create-prd) → specification-agent (/specify) → planning-agent (/plan)
- **Usage**: Automatically invoked by `/create-prd` command
- **Triggers**: /create-prd, PRD, product requirements, project initialization
- **Location**: `.claude/agents/product/prd-specialist.md`

**specification-agent**
- **Purpose**: Feature specification creation for Phase 1 requirements definition
- **Competencies**: User stories, acceptance criteria, functional requirements, constraints documentation
- **Workflow Position**: prd-specialist → **specification-agent** (/specify) → planning-agent (/plan)
- **Usage**: Automatically invoked by `/specify` command
- **Triggers**: /specify, spec, requirements, user story
- **Location**: `.claude/agents/product/specification-agent.md`

**planning-agent**
- **Purpose**: Implementation planning for Phase 2 technical design
- **Competencies**: Technical research, library evaluation, API contract design, data modeling, test scenario planning
- **Workflow Position**: specification-agent → **planning-agent** (/plan) → tasks-agent (/tasks)
- **Usage**: Automatically invoked by `/plan` command
- **Triggers**: /plan, implementation plan, technical research, contract design, data modeling
- **Produces**: plan.md, research.md, data-model.md, contracts/, quickstart.md
- **Location**: `.claude/agents/product/planning-agent.md`

**tasks-agent**
- **Purpose**: Task generation for Phase 3 implementation breakdown
- **Competencies**: Task decomposition, dependency analysis, priority assignment, parallel execution identification
- **Workflow Position**: planning-agent → **tasks-agent** (/tasks) → domain specialists
- **Usage**: Automatically invoked by `/tasks` command
- **Triggers**: /tasks, task generation, task breakdown
- **Produces**: tasks.md with dependency-ordered task list
- **Location**: `.claude/agents/product/tasks-agent.md`

**task-orchestrator**
- **Purpose**: Multi-agent workflow coordination for complex features
- **Competencies**: Agent routing, workflow sequencing, context handoff, quality gate management
- **Usage**: Automatically invoked for multi-domain tasks (2+ domains detected)
- **Triggers**: Complex feature, multi-domain, full-stack, end-to-end
- **Location**: `.claude/agents/product/task-orchestrator.md`

---

### Quality Department

**security-specialist**
- **Purpose**: Security review, vulnerability assessment, auth/auth patterns
- **Competencies**: OWASP Top 10, XSS/CSRF prevention, encryption, RLS policies, API security
- **Usage**: `Use the security-specialist agent to...`
- **Location**: `.claude/agents/quality/security-specialist.md`

**testing-specialist**
- **Purpose**: Test strategy, test creation, QA processes
- **Competencies**: TDD, unit tests, integration tests, E2E tests (Playwright), test coverage analysis
- **Usage**: `Use the testing-specialist agent to...`
- **Location**: `.claude/agents/quality/testing-specialist.md`

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
Use task-orchestrator        Keywords from 1 domain?
  ↓                               ↓
  ↓                         YES ↙   ↘ NO
  ↓                          ↓         ↓
  ↓                    Delegate to    Execute
  ↓                    specialized    directly
  ↓                    agent          (if simple)
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

**Decision**: Multi-agent scenario → Delegate to `task-orchestrator`

**Orchestrator Workflow**:
1. `specification-agent`: Create feature spec
2. `backend-architect`: Design API endpoints
3. `database-specialist`: Design user schema, RLS policies
4. `security-specialist`: Review auth flow, encryption
5. `frontend-specialist`: Implement login UI
6. `testing-specialist`: Create E2E tests

---

### Example 2: API Endpoint Creation

**Task**: "Create GET /api/users endpoint with pagination"

**Analysis**:
- Keywords: API, endpoint (backend), pagination (backend)
- Domains: Backend only = 1 domain

**Decision**: Single-agent scenario → Delegate to `backend-architect`

---

### Example 3: Blog Article Creation

**Task**: "Write a blog article about AI automation for founders"

**Analysis**:
- Keywords: blog, article, write (marketing)
- Domains: Marketing content pipeline

**Decision**: Multi-agent content pipeline

**Content Pipeline Workflow**:
1. `content-strategist`: Create content brief with keywords and structure
2. `research-agent`: Gather data, trends, expert insights
3. `copywriter-agent`: Write article in Brian's voice
4. `seo-specialist`: Optimize for SEO

**Skill Reference**: `.claude/skills/marketing/content-pipeline/SKILL.md`

---

## Context Handoff Format

When multiple agents work on same feature, use structured context handoff:

```json
{
  "feature": "user-authentication",
  "phase": "implementation",
  "previous_agent": "backend-architect",
  "next_agent": "frontend-specialist",
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

1. **Simple file operations**: Reading files, checking git status, listing directories
2. **Documentation-only tasks**: Reading specs, answering questions about code
3. **Coordination tasks**: Determining which agent to use, analyzing task complexity
4. **Constitutional tasks**: Reading constitution, running compliance checks

**Pattern**: If task involves no specialized domain work, execute directly.

---

## Agent Loading

Load agent context modules as needed:

```bash
# Load specific agent context
./.specify/scripts/bash/load-context.sh load agents

# Load agent + related contexts
./.specify/scripts/bash/load-context.sh analyze "implement user authentication"
```

---

**Module Version**: 1.0.0
**Created**: 2026-01-09 (Sprint 3 Task T024)
**Constitutional Authority**: Principle X (Agent Delegation Protocol)
**Source Documents**:
- CLAUDE.md "Available Agents" section
- `.specify/memory/agent-collaboration-triggers.md`
- All agent files in `.claude/agents/`

---

## sdd-agentic-framework Specific Agents

### constitutional-governance-agent (product)

**Purpose**: Primary orchestration agent that serves as the main thread entry point for all Claude Code sessions. Enforces the 4-step pre-flight compliance protocol on every user message, routes specialized work to domain agents per Principle X, gates all git operations per Principle VI, and maintains constitutional governance across the session.

**Model**: opus (required for maximum governance capability)

**Tools**: Full access (Read, Write, Edit, MultiEdit, Bash, Grep, Glob, WebSearch, Task, TodoWrite)

**Usage**: Configure as default agent in settings.json:
```json
{
  "agent": "constitutional-governance-agent",
  "model": "claude-opus-4-5-20251101"
}
```

**Triggers**: Automatically active when configured as default agent. Handles ALL user messages as primary entry point.

**Key Responsibilities**:
- Enforce 4-step pre-flight compliance on every message
- Route specialized work to domain agents (Principle X)
- Gate ALL git operations (Principle VI - CRITICAL)
- Maintain constitutional governance across session

See `.claude/agents/product/constitutional-governance-agent.md` for full details.

---

**Module**: agents.md
**Framework**: sdd-agentic-framework v3.1.0
**Last Updated**: 2026-01-09
