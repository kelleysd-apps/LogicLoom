---
name: service-architecture
version: 3.0.0
category: domain
description: Microservices and service boundary design. Routes to backend-architect.
triggers: ["service architecture", "microservice", "service design", "domain service", "bounded context"]
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
---

# Service Architecture Skill

## Purpose

Designs service architecture including microservices, service boundaries,
API contracts, and inter-service communication patterns. Follows domain-driven
design principles.

## When to Use

Activate this skill when the user request involves:
- Service boundary definition
- Microservice design
- Domain-driven design
- Service communication patterns
- Event-driven architecture

## Configuration

### Allowed Tools

- Read, Write, Edit, Grep, Glob

### Agent Invocations

**backend-architect**:
- Context: service_name, service_boundaries, dependencies, contracts
- When: Service architecture design is needed
- Expected output: architecture_design

### DS-STAR Integration

- Pre-execution: validation/message-preflight
- Post-verification: true
- Auto-debug: conditional

## Constitutional Compliance

- **Principle III (Contract-First)**: API contracts before implementation
- **Principle X (Skills-First)**: Skill orchestrates, backend-architect executes

## Instructions

### Step 1: Analyze Service Requirements

Gather:
- Business domain/bounded context
- Service responsibilities
- External dependencies
- Performance requirements

### Step 2: Design Service Boundaries

Apply DDD principles:
- Identify aggregates
- Define bounded contexts
- Map domain events
- Establish service contracts

### Step 3: Define API Contracts

```yaml
service_contract:
  name: <service>
  version: <semver>
  endpoints:
    - path: <path>
      method: <GET|POST|PUT|DELETE>
      request: <schema>
      response: <schema>
  events:
    - name: <event>
      payload: <schema>
```

### Step 4: Document Architecture

Create:
- Service diagram
- API specifications
- Event catalog
- Dependency map

## Agent Invocation

```yaml
invoke: backend-architect
context:
  service_name: "<service>"
  boundaries: "<bounded context>"
  dependencies: ["<dep1>", "<dep2>"]
  contracts: true
expected:
  format: architecture_design
  artifacts: [diagram, contracts, events]
```

## Examples

### Example 1: Design User Service

**Request**: "Design the user service architecture"

**Output**:
```yaml
service: user-service
bounded_context: Identity
aggregates:
  - User
  - Profile
events:
  - UserCreated
  - UserUpdated
  - ProfileUpdated
endpoints:
  - POST /users
  - GET /users/{id}
  - PUT /users/{id}
```

## Error Handling

| Scenario | Detection | Resolution |
|----------|-----------|------------|
| Unclear boundaries | Analysis | Propose bounded contexts |
| Missing dependencies | Validation | Identify required services |
| Contract conflicts | Review | Resolve with versioning |

## Quality Checks

Before completing:
- [ ] Service boundaries clearly defined
- [ ] Contracts documented
- [ ] Events catalogued
- [ ] Dependencies mapped

## Related Skills

- **domain/backend-operations**: Implementation
- **domain/api-design**: Detailed API contracts
- **domain/database-operations**: Data layer
