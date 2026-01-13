---
name: backend-operations
version: 3.0.0
description: |
  Domain skill for backend development operations including API endpoints, server logic,
  middleware, authentication, and service layer implementation. Routes to backend-architect
  or implementation-specialist agents for execution. Part of the skills-first architecture.
category: domain
triggers:
  - "backend"
  - "API endpoint"
  - "server"
  - "middleware"
  - "service layer"
  - "authentication"
  - "authorization"
allowed-tools:
  - Read
  - Write
  - Edit
  - MultiEdit
  - Bash
  - Grep
  - Glob
agent-invocations:
  - agent: backend-architect
    context-subset:
      - api-contracts
      - service-requirements
      - authentication-needs
      - data-flow
    when: "API design or service architecture work is needed"
    timeout: 10m
  - agent: implementation-specialist
    context-subset:
      - api-specifications
      - endpoint-requirements
      - middleware-config
    when: "backend implementation work is needed"
    timeout: 10m
composes:
  - skill: validation/message-preflight
    phase: pre-execution
  - skill: validation/domain-detection
    phase: analysis
progressive-disclosure:
  layer1:
    - name
    - description
    - triggers
    - category
    - version
    - rl_metrics
  layer2:
    - instructions
    - agent-invocations
    - composes
    - allowed-tools
  layer3:
    - examples
    - references
rl_metrics:
  success_rate: 0.5
  avg_tokens: 0
  avg_duration_ms: 0
  user_satisfaction: 0.5
  selection_weight: 0.5
  invocation_count: 0
---

# Backend Operations Skill

## Overview

This skill handles all backend development operations including API endpoints,
server logic, middleware configuration, authentication/authorization, and
service layer implementation.

## When to Use

Activate this skill when the user request involves:
- Creating API endpoints
- Server-side logic implementation
- Middleware configuration
- Authentication/authorization setup
- Service layer architecture
- Request/response handling
- Server-side validation

## Instructions

### Step 1: Analyze Backend Requirements

Identify the specific backend work needed:

1. **API Endpoints**: REST or GraphQL endpoints
2. **Middleware**: Auth, logging, validation, error handling
3. **Services**: Business logic layer
4. **Authentication**: JWT, OAuth, session management
5. **Data Flow**: Request -> Service -> Database -> Response

### Step 2: Prepare Context for Agent

For **API Design** (backend-architect):
```yaml
context-subset:
  - api-contracts: OpenAPI/Swagger specs
  - service-requirements: Business logic needs
  - authentication-needs: Auth requirements
  - data-flow: How data moves through system
```

For **Implementation** (implementation-specialist):
```yaml
context-subset:
  - api-specifications: Endpoint specs
  - endpoint-requirements: Request/response format
  - middleware-config: Middleware stack
```

### Step 3: Select and Invoke Agent

**backend-architect** for:
- API contract design
- Service architecture decisions
- Authentication strategy

**implementation-specialist** for:
- Endpoint implementation
- Middleware implementation
- Integration work

### Step 4: Validate Output

Check agent output for:
- [ ] Follows RESTful conventions (if REST)
- [ ] Proper error handling
- [ ] Input validation present
- [ ] Authentication checks in place
- [ ] Tests included (Principle II)

## Context Requirements

| Field | Required | Description |
|-------|----------|-------------|
| api-contracts | Yes | OpenAPI or similar spec |
| service-requirements | Yes | Business logic needs |
| authentication-needs | No | Auth requirements |
| data-flow | No | Data flow diagram/description |

## Agent Invocations

### backend-architect
```yaml
purpose: Design APIs and backend services
department: architecture
skill-portfolio:
  - domain/api-design
  - domain/service-architecture
```

### implementation-specialist
```yaml
purpose: Build backend integrations
merged-from:
  - frontend-specialist
  - full-stack-developer
```

## Quality Checks

Before completing:
- [ ] API follows project conventions
- [ ] Error responses are consistent
- [ ] Input validation comprehensive
- [ ] Auth middleware configured
- [ ] Integration tests written (Principle II)

## Related Skills

- **domain/api-design**: For detailed API contract design
- **domain/database-operations**: For data layer integration
- **domain/security-operations**: For security review

## Constitutional Compliance

- **Principle II (Test-First)**: Integration tests required
- **Principle X (Delegation)**: Routes to appropriate agent
- **Principle XI (Input Validation)**: Validates all inputs
