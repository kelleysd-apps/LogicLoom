---
name: service-architecture
version: 3.0.0
category: domain
description: Designs service architecture, microservices, and API contracts
triggers:
  - service architecture
  - microservice
  - service design
  - API design
  - service layer
  - domain service
rl_metrics:
  success_rate: 0.0
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
progressive-disclosure:
  layer-1-metadata:
    description: "Handles service architecture design and microservices"
    triggers: [service, microservice, service design]
    primary-agent: backend-architect
  layer-2-instructions: true
  layer-3-examples: true
agent-invocations:
  - agent: backend-architect
    context-subset:
      - service_name
      - service_boundaries
      - dependencies
      - contracts
    expected-output: architecture_design
ds-star:
  pre-execution: validation/message-preflight
  post-verification: true
  auto-debug: conditional
---

# Service Architecture Skill

## Purpose

Designs service architecture including microservices, service boundaries,
API contracts, and inter-service communication patterns. Follows domain-driven
design principles.

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

## RL Metrics

- **Success Criteria**: Architecture validated and documented
- **Token Efficiency**: < 1000 tokens per service

## Related Skills

- **domain/backend-operations**: Implementation
- **domain/api-design**: Detailed API contracts
- **domain/database-operations**: Data layer

---

*Domain skill version: 3.0.0*
