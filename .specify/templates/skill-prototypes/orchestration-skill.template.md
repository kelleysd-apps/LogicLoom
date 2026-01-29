---
name: {{SKILL_NAME}}
version: 3.0.0
category: orchestration
description: {{ORCHESTRATION_DESCRIPTION}}
triggers:
  - {{PRIMARY_TRIGGER}}
  - {{SECONDARY_TRIGGERS}}
rl_metrics:
  success_rate: 0.0
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
progressive-disclosure:
  layer-1-metadata:
    description: "Orchestrates {{WORKFLOW_TYPE}}"
    triggers: [{{TRIGGER_LIST}}]
    primary-agent: workflow-coordinator
  layer-2-instructions: true
  layer-3-examples: true
agent-invocations:
  - agent: workflow-coordinator
    context-subset:
      - workflow_type
      - skills_to_invoke
      - execution_order
    expected-output: coordination_plan
  - agent: {{DOMAIN_AGENT_1}}
    context-subset: [{{CONTEXT_1}}]
    expected-output: {{OUTPUT_1}}
  - agent: {{DOMAIN_AGENT_2}}
    context-subset: [{{CONTEXT_2}}]
    expected-output: {{OUTPUT_2}}
ds-star:
  pre-execution: validation/message-preflight
  post-verification: true
  auto-debug: true
---

# {{SKILL_NAME}} Orchestration Skill

## Purpose

{{DETAILED_PURPOSE}}

Coordinates multiple domain skills and agents to complete {{WORKFLOW_TYPE}} workflows.

## Orchestration Pattern

```
User Request (Multi-Domain)
    |
    v
[FR-707] Compliance Check
    |
    v
{{SKILL_NAME}} Activation
    |
    +---> Domain Analysis
    |
    +---> Skill Sequencing
    |
    v
Workflow Coordinator
    |
    +---> {{SKILL_1}} -> {{AGENT_1}}
    |
    +---> {{SKILL_2}} -> {{AGENT_2}}
    |
    +---> {{SKILL_3}} -> {{AGENT_3}}
    |
    v
Result Aggregation
    |
    v
Verifier Validation
```

## Constitutional Compliance

- **Principle X (Skills-First)**: Orchestrates skills, not agents directly
- **Principle IV (Idempotent)**: Safe to re-run orchestration
- **Principle VI (Git Approval)**: Never auto-commits

## Instructions

### Domain Detection

Analyze user request for multiple domains:

1. Scan for domain keywords:
   - Frontend: UI, component, React, CSS
   - Backend: API, endpoint, server, auth
   - Database: schema, migration, query, SQL
   - Testing: test, TDD, E2E, coverage
   - Security: encryption, XSS, secrets
   - DevOps: deploy, CI/CD, Docker

2. If 2+ domains detected:
   - Activate this orchestration skill
   - Coordinate domain skills

### Skill Sequencing

Determine execution order based on dependencies:

```yaml
{{WORKFLOW_NAME}}:
  sequence:
    - skill: {{SKILL_1}}
      depends_on: []
      parallel: false
    - skill: {{SKILL_2}}
      depends_on: [{{SKILL_1}}]
      parallel: false
    - skill: {{SKILL_3}}
      depends_on: [{{SKILL_1}}]
      parallel: true  # Can run with SKILL_2
```

### Execution Flow

1. **Initialize Workflow**
   - Create workflow session
   - Set up credit tracking
   - Initialize RL metrics

2. **Execute Skills**
   - For each skill in sequence:
     - Activate skill with minimal context
     - Skill invokes appropriate agent
     - Capture output
     - Update RL metrics

3. **Aggregate Results**
   - Combine outputs from all skills
   - Validate completeness
   - Format for user

4. **Finalize**
   - Run verifier validation
   - Distribute RL rewards
   - Log completion

## Agent Coordination

### Primary Coordinator

```yaml
invoke: workflow-coordinator
context:
  workflow_type: "{{WORKFLOW_TYPE}}"
  domains_detected: [{{DOMAIN_LIST}}]
  skills_to_invoke:
    - {{SKILL_1}}
    - {{SKILL_2}}
    - {{SKILL_3}}
  execution_order: sequential | parallel | mixed
output:
  coordination_plan: {...}
```

### Domain Agent Invocations

Skills invoke their respective agents:

| Skill | Agent | Context |
|-------|-------|---------|
| {{SKILL_1}} | {{AGENT_1}} | {{CONTEXT_1}} |
| {{SKILL_2}} | {{AGENT_2}} | {{CONTEXT_2}} |
| {{SKILL_3}} | {{AGENT_3}} | {{CONTEXT_3}} |

## Parallel Execution

When possible, execute independent skills in parallel:

```
{{SKILL_1}} (sequential - must be first)
    |
    +----+----+
    |         |
    v         v
{{SKILL_2}} {{SKILL_3}} (parallel)
    |         |
    +----+----+
         |
         v
    Aggregation
```

## Examples

### Example 1: {{EXAMPLE_1_TITLE}}

**Request**: "{{EXAMPLE_1_REQUEST}}"

**Domains Detected**: {{EXAMPLE_1_DOMAINS}}

**Execution**:
1. Activate {{SKILL_NAME}}
2. Skills invoked: {{EXAMPLE_1_SKILLS}}
3. Agents used: {{EXAMPLE_1_AGENTS}}

**Output**:
```
{{EXAMPLE_1_OUTPUT}}
```

### Example 2: {{EXAMPLE_2_TITLE}}

**Request**: "{{EXAMPLE_2_REQUEST}}"

**Domains Detected**: {{EXAMPLE_2_DOMAINS}}

**Execution**:
1. Activate {{SKILL_NAME}}
2. Skills invoked: {{EXAMPLE_2_SKILLS}}
3. Agents used: {{EXAMPLE_2_AGENTS}}

**Output**:
```
{{EXAMPLE_2_OUTPUT}}
```

## Error Handling

### Skill Failure

If a skill fails during orchestration:

1. Log failure with context
2. Check if skill is critical or optional
3. For critical skills:
   - Trigger auto-debug
   - Retry once after fix
   - Fail workflow if retry fails
4. For optional skills:
   - Log warning
   - Continue with remaining skills
   - Mark output as partial

### Coordination Failure

If workflow coordinator fails:

1. Fall back to sequential execution
2. Use default skill order
3. Log degraded mode

## RL Metrics

Orchestration rewards distributed using credit assignment:

- **Skill orchestration**: 40% of total reward
- **Agent execution**: 50% of total reward
- **Context provision**: 10% of total reward

## Quality Gates

| Gate | Validation | Threshold |
|------|------------|-----------|
| Domain coverage | All detected domains addressed | 100% |
| Skill completion | All skills executed successfully | 80%+ |
| Output validation | Verifier passes | Required |
| Token efficiency | Below budget | Layer 1+2 < 600 |

## Related Skills

- **Domain skills**: {{RELATED_DOMAIN_SKILLS}}
- **SDD workflow**: sdd-workflow/sdd-tasks
- **Compliance**: validation/message-preflight

---

*Orchestration skill template version: 3.0.0*
*Multi-domain workflow: Supported*
