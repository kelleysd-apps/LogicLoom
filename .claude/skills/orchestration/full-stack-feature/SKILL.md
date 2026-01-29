---
name: full-stack-feature
version: 3.0.0
category: orchestration
description: Orchestrates full-stack features across frontend, backend, and database.
triggers: ["full-stack", "frontend and backend", "end-to-end feature", "UI with API", "cross-domain"]
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
---

# Full-Stack Feature Orchestration Skill

## Overview

Orchestration skill for coordinating multi-layer feature implementation spanning frontend, backend, and database layers. Ensures proper sequencing and dependency management across domains.

## When to Use

- Full-stack feature implementation
- Features requiring UI + API + database changes
- Cross-domain coordination
- End-to-end feature development
- Multi-layer architecture work

## Configuration

### Allowed Tools
Read, Write, Edit, MultiEdit, Bash, Grep, Glob, Task

### Agent Invocation

```yaml
primary-agent: workflow-coordinator
supporting-agents:
  - database-specialist
  - backend-architect
  - implementation-specialist
timeout: 30m
```

### Composes
- validation/message-preflight (pre-execution)
- domain/database-operations (phase 1)
- domain/backend-operations (phase 2)
- domain/frontend-operations (phase 3)

## Instructions

### Step 1: Domain Analysis

Identify requirements for each layer:
1. **Database**: Schema changes, migrations, RLS policies
2. **Backend**: API endpoints, services, middleware
3. **Frontend**: UI components, state management, API integration

### Step 2: Dependency Mapping

Establish execution order based on dependencies:
```
Database → Backend → Frontend
(Schema)   (API)     (UI)
```

### Step 3: Skill Sequencing

Execute domain skills in order:
1. Invoke `domain/database-operations` for schema work
2. Invoke `domain/backend-operations` for API work
3. Invoke `domain/frontend-operations` for UI work

### Step 4: Coordination via Workflow Coordinator

Delegate to `workflow-coordinator` with:
- Complete feature requirements
- Dependency order
- Integration points between layers
- Quality gates for each phase

### Step 5: Integration Validation

After all layers complete:
- [ ] Database schema supports API needs
- [ ] API contracts match frontend expectations
- [ ] End-to-end flow works correctly
- [ ] Tests cover all layers

## Constitutional Compliance

- **Principle II**: Tests at each layer (80% coverage)
- **Principle III**: Contracts defined between layers
- **Principle X**: Skills-first orchestration
- **Principle IV**: Operations are idempotent

## Examples

### Example 1: User Profile Feature

**Request**: "Build user profile page with avatar upload"

**Execution**:
1. Database: Add avatar_url to users table
2. Backend: Create /api/users/:id/avatar endpoint
3. Frontend: Build ProfilePage component with upload

### Example 2: E-commerce Cart

**Request**: "Implement shopping cart with checkout"

**Execution**:
1. Database: cart, cart_items tables
2. Backend: Cart API, payment integration
3. Frontend: Cart UI, checkout flow

## Quality Gates

Between each phase:
- [ ] Layer tests passing
- [ ] Contracts validated
- [ ] Dependencies satisfied
- [ ] Integration points verified

## Related Skills

- domain/database-operations - Database layer
- domain/backend-operations - API layer
- domain/frontend-operations - UI layer
- orchestration/multi-skill-workflow - Complex workflows
