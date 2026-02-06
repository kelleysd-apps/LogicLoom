---
# ⚠️ DEPRECATED — MIGRATED TO PLUGIN
# This skill has been migrated to: plugins/sdd-domain-backend/skills/service-architecture/
# Use the plugin version instead. This file will be removed in v5.0.
# Migration date: 2026-01-15
---

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
  "skill": "service-architecture",
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

- **domain/backend-operations**: Implementation
- **domain/api-design**: Detailed API contracts
- **domain/database-operations**: Data layer
