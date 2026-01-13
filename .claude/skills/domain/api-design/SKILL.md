---
name: api-design
version: 3.0.0
description: |
  Domain skill for API design including REST, GraphQL, OpenAPI specifications,
  endpoint design, and contract definition. Routes to backend-architect agent for
  execution. Critical for Principle III (Contract-First Design).
category: domain
triggers:
  - "API design"
  - "REST"
  - "GraphQL"
  - "endpoint design"
  - "contract"
  - "OpenAPI"
  - "Swagger"
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
agent-invocations:
  - agent: backend-architect
    context-subset:
      - api-requirements
      - data-contracts
      - authentication-model
      - versioning-strategy
    when: "API design or contract work is needed"
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

# API Design Skill

## Overview

This skill handles all API design work including REST API design, GraphQL schemas,
OpenAPI/Swagger specifications, endpoint design, and contract definition. Critical
for Principle III (Contract-First Design). Routes to `backend-architect` agent.

## When to Use

Activate this skill when the user request involves:
- REST API design
- GraphQL schema design
- OpenAPI specification
- Endpoint design
- API versioning
- Request/response contracts
- Error response standardization

## Instructions

### Step 1: Analyze API Requirements

Identify the specific API design work needed:

1. **REST Design**: Resources, endpoints, methods
2. **GraphQL**: Types, queries, mutations, subscriptions
3. **OpenAPI**: Spec generation, validation
4. **Contracts**: Request/response schemas
5. **Versioning**: URL, header, or query versioning

### Step 2: Prepare Context for Agent

Gather minimal required context:

```yaml
context-subset:
  - api-requirements: What the API should do
  - data-contracts: Request/response shapes
  - authentication-model: Auth approach
  - versioning-strategy: How to version
```

### Step 3: Invoke Backend Architect

Delegate to `backend-architect` with:
- Clear API requirements
- Data contract definitions
- Authentication model
- Versioning strategy

### Step 4: Validate Output

Check agent output for:
- [ ] RESTful conventions followed
- [ ] Consistent naming
- [ ] Error responses standardized
- [ ] Authentication documented
- [ ] OpenAPI spec valid

## Context Requirements

| Field | Required | Description |
|-------|----------|-------------|
| api-requirements | Yes | API functionality |
| data-contracts | Yes | Request/response shapes |
| authentication-model | No | Auth approach |
| versioning-strategy | No | Version strategy |

## Agent Invocation

```yaml
agent: backend-architect
purpose: Design APIs and backend services
department: architecture
skill-portfolio:
  - domain/api-design
  - domain/service-architecture
```

## API Design Principles (Contract-First)

### Principle III Compliance

From Constitution v1.6.0:
> **Contract-First Design**: Define contracts BEFORE implementation
> - API contracts (OpenAPI/GraphQL)
> - Data models
> - Interface specifications

### RESTful Design Guidelines

1. **Resources as Nouns**: `/users`, `/orders`, `/products`
2. **HTTP Methods as Verbs**: GET, POST, PUT, PATCH, DELETE
3. **Plural Resource Names**: `/users` not `/user`
4. **Nested Resources**: `/users/{id}/orders`
5. **Query Parameters for Filtering**: `?status=active&limit=10`

### Status Codes

| Code | Meaning | Use Case |
|------|---------|----------|
| 200 | OK | Successful GET/PUT/PATCH |
| 201 | Created | Successful POST |
| 204 | No Content | Successful DELETE |
| 400 | Bad Request | Invalid input |
| 401 | Unauthorized | No/invalid auth |
| 403 | Forbidden | No permission |
| 404 | Not Found | Resource doesn't exist |
| 422 | Unprocessable | Validation error |
| 500 | Server Error | Unexpected error |

## OpenAPI Example

```yaml
openapi: 3.0.3
info:
  title: User API
  version: 1.0.0
paths:
  /users:
    get:
      summary: List users
      parameters:
        - name: limit
          in: query
          schema:
            type: integer
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/User'
    post:
      summary: Create user
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateUser'
      responses:
        '201':
          description: Created
components:
  schemas:
    User:
      type: object
      properties:
        id:
          type: string
        email:
          type: string
    CreateUser:
      type: object
      required:
        - email
      properties:
        email:
          type: string
```

## Quality Checks

Before completing:
- [ ] Contracts defined before implementation
- [ ] OpenAPI spec validates
- [ ] Error responses consistent
- [ ] Authentication documented
- [ ] Versioning strategy clear

## Related Skills

- **domain/backend-operations**: For implementation
- **sdd-workflow/sdd-planning**: For contract design phase
- **domain/security-operations**: For API security

## Constitutional Compliance

- **Principle III (Contract-First)**: MANDATORY - contracts first
- **Principle X (Delegation)**: Routes to backend-architect
- **Principle XI (Input Validation)**: Request validation defined
