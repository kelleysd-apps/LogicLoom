---
name: multi-skill-workflow
version: 3.0.0
description: |
  Orchestration skill for coordinating multi-domain workflows that require 2+ skills.
  Routes to workflow-coordinator agent when multiple domain skills must work together.
  Activates automatically when message-preflight detects multi-domain work.
category: orchestration
triggers:
  - "orchestrate workflow"
  - "multi-domain"
  - "coordinate skills"
  - "full-stack feature"
  - "multiple domains"
allowed-tools:
  - Read
  - Write
  - Edit
  - MultiEdit
  - Bash
  - Grep
  - Glob
  - Task
agent-invocations:
  - agent: workflow-coordinator
    context-subset:
      - skill-sequence
      - domain-requirements
      - coordination-plan
      - dependencies
    when: "multi-skill coordination is needed"
    timeout: 30m
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

# Multi-Skill Workflow Orchestration

## Overview

This orchestration skill coordinates multi-domain workflows that require two or more
domain skills working together. It is automatically activated when `message-preflight`
detects that a user request spans multiple domains (e.g., frontend + backend + database).

## When to Use

Activate this skill when:
- 2+ domains detected in user request
- Full-stack feature implementation
- Cross-cutting concerns (security across all layers)
- Complex workflows requiring coordination

## Instructions

### Step 1: Receive Multi-Domain Analysis

From `message-preflight`, receive:
- List of detected domains
- Skills needed for each domain
- Suggested execution order

### Step 2: Create Coordination Plan

Build a skill sequence plan:

```yaml
coordination-plan:
  domains: [frontend, backend, database]
  skill-sequence:
    - skill: domain/database-operations
      phase: data-layer
      dependencies: []
    - skill: domain/backend-operations
      phase: api-layer
      dependencies: [database-operations]
    - skill: domain/frontend-operations
      phase: ui-layer
      dependencies: [backend-operations]
```

### Step 3: Execute Skills in Order

For each skill in sequence:

1. **Check dependencies** - Previous skills complete
2. **Prepare context** - Gather outputs from dependencies
3. **Activate skill** - Via skill loader
4. **Validate output** - Quality check
5. **Pass to next** - Forward relevant context

### Step 4: Consolidate Results

After all skills complete:
- Merge all outputs
- Verify integration points
- Run cross-domain validation
- Report completion

## Context Requirements

| Field | Required | Description |
|-------|----------|-------------|
| skill-sequence | Yes | Ordered skill list |
| domain-requirements | Yes | Per-domain needs |
| coordination-plan | Yes | Execution plan |
| dependencies | Yes | Skill dependencies |

## Agent Invocation

```yaml
agent: workflow-coordinator
purpose: Coordinate multi-skill workflows and migrations
department: product
merged-from:
  - task-orchestrator
skill-portfolio:
  - orchestration/multi-skill-workflow
  - orchestration/migration-workflow
```

## Execution Patterns

### Sequential (Default)
```
Database -> Backend -> Frontend
```
Each skill waits for previous to complete.

### Parallel (When Independent)
```
Frontend ----\
              |-> Integration
Backend -----/
```
Independent skills run simultaneously.

### Iterative (Refinement)
```
Spec -> Plan -> Review -> Revise -> Approve
```
Loops until quality gate passes.

## Quality Checks

Before completing:
- [ ] All skills in sequence executed
- [ ] Dependencies respected
- [ ] Outputs integrated correctly
- [ ] Cross-domain tests pass
- [ ] No orphaned changes

## Example: Full-Stack Feature

**User Request**: "Build user profile page with database storage"

**Detected Domains**: frontend, backend, database

**Coordination Plan**:
```yaml
1. database-operations:
   - Create users table
   - Add profile fields
   - Create RLS policies

2. backend-operations:
   - Create /api/profile endpoint
   - Add authentication middleware
   - Implement CRUD operations

3. frontend-operations:
   - Build ProfilePage component
   - Create profile form
   - Wire up API calls
```

**Execution**:
1. Execute database-operations -> produces schema
2. Execute backend-operations (uses schema) -> produces API
3. Execute frontend-operations (uses API) -> produces UI
4. Run integration tests across all layers

## Error Handling

### Skill Failure
1. Log which skill failed
2. Determine if rollback needed
3. Report to user
4. Suggest recovery steps

### Dependency Failure
1. Don't proceed with dependent skills
2. Mark workflow as blocked
3. Report dependency issue

## Related Skills

- **validation/message-preflight**: Detects multi-domain need
- **sdd-workflow/sdd-planning**: Plans multi-domain features
- **orchestration/migration-workflow**: For migrations

## Constitutional Compliance

- **Principle X (Delegation)**: Routes to workflow-coordinator
- **Principle IV (Idempotent)**: Safe to retry partial workflows
- **Principle VII (Observability)**: Logs each skill execution
