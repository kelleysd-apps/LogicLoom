---
name: api-design
version: 3.0.0
category: domain
description: REST, GraphQL, and OpenAPI contract design. Routes to backend-architect.
triggers: ["API design", "REST", "GraphQL", "OpenAPI", "Swagger", "contract"]
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
---

# API Design Skill

## Overview

This skill handles all API design work including REST API design, GraphQL schemas,
OpenAPI/Swagger specifications, endpoint design, and contract definition. Critical
for Principle III (Contract-First Design). Routes to `backend-architect` agent.

## Task Brief

You are an API design specialist working on a team task. Your expertise includes:
- **REST API Design**: Resource modeling, endpoint structure, HTTP methods, status codes, pagination
- **GraphQL**: Schema design, queries, mutations, subscriptions, federation
- **OpenAPI/Swagger**: Specification authoring, validation, code generation
- **Contract-First Design**: Request/response schemas, versioning strategies, breaking change management
- **API Security**: OAuth 2.0 flows, API keys, rate limiting, CORS configuration
- **Error Handling**: Standardized error responses, error codes, problem details (RFC 7807)

**Quality Standards**:
- Contracts must be defined BEFORE implementation (Principle III - Contract-First)
- RESTful conventions: plural nouns for resources, HTTP methods as verbs
- Consistent naming conventions across all endpoints
- Error responses follow a standardized schema
- Authentication and authorization documented for every endpoint
- OpenAPI spec must validate without errors
- Test-First Development (Principle II): contract tests required for all endpoints

**File Ownership**: You own files matching: `specs/*/contracts/**`, `openapi.*`, `swagger.*`, `*.graphql`, `schema.graphql`

## When to Use

Activate this skill when the user request involves:
- REST API design
- GraphQL schema design
- OpenAPI specification
- Endpoint design
- API versioning
- Request/response contracts
- Error response standardization

## Configuration

### Allowed Tools

- Read, Write, Edit, Grep, Glob

### Agent Invocations

**backend-architect**:
- Context: api-requirements, data-contracts, authentication-model, versioning-strategy
- When: API design or contract work is needed
- Timeout: 10m

### Composes

- validation/message-preflight (pre-execution)
- validation/domain-detection (analysis)

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



## RL Feedback Loop

After skill execution completes, the RL feedback mechanism updates metrics:

### Success Criteria
- Task completed without errors
- Output validated by verifier (if applicable)
- User satisfaction (implicit from follow-up)

### Feedback Collection
```
ON SKILL COMPLETION:
  1. Capture execution result (success/failure)
  2. Record token usage
  3. Calculate execution duration
  4. Update rl_metrics via EMA:
     - success_rate = 0.9 * old_rate + 0.1 * (1 if success else 0)
     - selection_weight = adjusted based on success_rate
  5. Log to .docs/rl-metrics/skill-performance.json
```

### Metrics Update Trigger
```python
# Pseudo-code for RL update
def update_rl_metrics(skill_name: str, success: bool, tokens: int):
    metrics = load_skill_metrics(skill_name)
    metrics['invocation_count'] += 1
    metrics['success_rate'] = 0.9 * metrics['success_rate'] + 0.1 * (1 if success else 0)
    metrics['avg_tokens'] = 0.9 * metrics['avg_tokens'] + 0.1 * tokens
    metrics['selection_weight'] = max(0.1, min(1.0, metrics['success_rate']))
    metrics['last_feedback'] = datetime.utcnow().isoformat()
    save_skill_metrics(skill_name, metrics)
```


## Verifier Integration

### Pre-Completion Validation
Before marking this skill as complete, invoke verifier validation:

```
VERIFIER_CHECK:
  1. Output format validation
  2. Constitutional compliance check
  3. Quality threshold verification
  4. Domain-specific validation rules
```

### Verifier Handoff
```json
{
  "skill": "api-design",
  "output": "<skill_output>",
  "validation_required": ["format", "compliance", "quality"],
  "threshold": 0.85
}
```

### On Verification Failure
- Log failure reason
- Update rl_metrics with failure
- Report to user with remediation options

## Related Skills

- **domain/backend-operations**: For implementation
- **sdd-workflow/sdd-planning**: For contract design phase
- **domain/security-operations**: For API security

## Constitutional Compliance

- **Principle III (Contract-First)**: MANDATORY - contracts first
- **Principle X (Delegation)**: Routes to backend-architect
- **Principle XI (Input Validation)**: Request validation defined
