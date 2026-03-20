---
name: backend-operations
version: 3.0.0
category: domain
description: Backend development and API endpoints. Routes to api-design skill (sdd-domain-backend).
triggers: ["backend", "API endpoint", "server", "middleware", "service layer", "authentication"]
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
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

## Task Brief

You are a backend architect working on a team task. Your expertise includes:
- **API Design**: RESTful APIs, GraphQL, gRPC, OpenAPI specifications
- **Database Architecture**: PostgreSQL, MongoDB, Redis, schema design, query optimization
- **Microservices**: Service decomposition, API gateways, message queues, event-driven architecture
- **Cloud Platforms**: AWS, GCP, Azure - serverless, containers, managed services
- **Performance**: Caching strategies, load balancing, horizontal scaling, database sharding
- **Security**: Authentication (OAuth 2.0, JWT), authorization, API security, data protection
- **Languages**: Node.js/TypeScript, Python, Go, Java
- **DevOps Integration**: Docker, Kubernetes, CI/CD pipeline design

**Quality Standards**:
- Design for failure and recovery scenarios
- Consider data consistency and transaction boundaries
- Plan for monitoring, logging, and observability (Principle VII)
- Document architecture decisions and trade-offs
- Start with business requirements, not technology (Principle V)
- Test-First Development (Principle II): integration tests required for all endpoints

**File Ownership**: You own files matching: `src/api/**`, `src/services/**`, `src/middleware/**`, `src/routes/**`, `src/controllers/**`, `server.*`

## Configuration

### Allowed Tools

- Read, Write, Edit, MultiEdit, Bash, Grep, Glob

### Agent Invocations

**api-design skill (sdd-domain-backend)**:
- Context: api-contracts, service-requirements, authentication-needs, data-flow
- When: API design or service architecture work is needed
- Timeout: 10m

**backend-operations skill (sdd-domain-backend)**:
- Context: api-specifications, endpoint-requirements, middleware-config
- When: Backend implementation work is needed
- Timeout: 10m

### Composes

- validation/message-preflight (pre-execution)
- validation/domain-detection (analysis)

## Instructions

### Step 1: Analyze Backend Requirements

Identify the specific backend work needed:

1. **API Endpoints**: REST or GraphQL endpoints
2. **Middleware**: Auth, logging, validation, error handling
3. **Services**: Business logic layer
4. **Authentication**: JWT, OAuth, session management
5. **Data Flow**: Request -> Service -> Database -> Response

### Step 2: Prepare Context for Agent

For **API Design** (api-design skill (sdd-domain-backend)):
```yaml
context-subset:
  - api-contracts: OpenAPI/Swagger specs
  - service-requirements: Business logic needs
  - authentication-needs: Auth requirements
  - data-flow: How data moves through system
```

For **Implementation** (backend-operations skill (sdd-domain-backend)):
```yaml
context-subset:
  - api-specifications: Endpoint specs
  - endpoint-requirements: Request/response format
  - middleware-config: Middleware stack
```

### Step 3: Select and Invoke Agent

**api-design skill (sdd-domain-backend)** for:
- API contract design
- Service architecture decisions
- Authentication strategy

**backend-operations skill (sdd-domain-backend)** for:
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

### api-design skill (sdd-domain-backend)
```yaml
purpose: Design APIs and backend services
department: architecture
skill-portfolio:
  - domain/api-design
  - domain/service-architecture
```

### backend-operations skill (sdd-domain-backend)
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
