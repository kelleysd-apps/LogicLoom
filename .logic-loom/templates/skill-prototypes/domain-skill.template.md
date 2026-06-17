---
name: {{DOMAIN}}-operations
version: 3.0.0
category: domain
description: {{DOMAIN_DESCRIPTION}}
triggers:
  - {{KEYWORD_1}}
  - {{KEYWORD_2}}
  - {{KEYWORD_3}}
  - {{KEYWORD_4}}
  - {{KEYWORD_5}}
progressive-disclosure:
  layer-1-metadata:
    description: "Handles {{DOMAIN}} domain operations"
    triggers: [{{TRIGGER_LIST}}]
    primary-agent: {{PRIMARY_AGENT}}
  layer-2-instructions: true
  layer-3-examples: true
agent-invocations:
  - agent: {{PRIMARY_AGENT}}
    context-subset:
      - task_description
      - relevant_files
      - constraints
    expected-output: implementation
  - agent: {{SECONDARY_AGENT}}
    context-subset:
      - code_to_review
      - quality_criteria
    expected-output: validation
governance:
  pre-execution: validation/message-preflight
  post-verification: true
---

# {{DOMAIN}} Operations Skill

## Purpose

Provides orchestration for {{DOMAIN}} domain tasks, routing work to specialized
agents while maintaining skills-first architecture compliance.

## Domain Coverage

- **Primary Domain**: {{DOMAIN}}
- **Trigger Keywords**: {{KEYWORD_LIST}}
- **Primary Agent**: {{PRIMARY_AGENT}}
- **Fallback Agent**: {{FALLBACK_AGENT}}

## Constitutional Compliance

- **Principle X (Skills-First)**: This skill orchestrates, agent executes
- **Principle II (Test-First)**: TDD required for all implementations
- **Principle VII (Observability)**: All operations logged

## Instructions

### Task Analysis

1. Parse user request for {{DOMAIN}} requirements
2. Identify specific operation type:
   - {{OPERATION_TYPE_1}}
   - {{OPERATION_TYPE_2}}
   - {{OPERATION_TYPE_3}}
3. Gather required context

### Agent Invocation

Invoke {{PRIMARY_AGENT}} with minimal context:

```yaml
agent: {{PRIMARY_AGENT}}
context:
  task: "{{TASK_DESCRIPTION}}"
  files: [{{RELEVANT_FILES}}]
  constraints:
    - {{CONSTRAINT_1}}
    - {{CONSTRAINT_2}}
output:
  format: {{OUTPUT_FORMAT}}
  validation: {{VALIDATION_RULES}}
```

### Quality Validation

Post-execution verification:
- {{VERIFICATION_1}}
- {{VERIFICATION_2}}
- {{VERIFICATION_3}}

## Operation Types

### {{OPERATION_TYPE_1}}

**Description**: {{OPERATION_1_DESC}}

**Agent**: {{PRIMARY_AGENT}}

**Context Requirements**:
- {{CONTEXT_REQ_1}}
- {{CONTEXT_REQ_2}}

### {{OPERATION_TYPE_2}}

**Description**: {{OPERATION_2_DESC}}

**Agent**: {{PRIMARY_AGENT}} or {{SECONDARY_AGENT}}

**Context Requirements**:
- {{CONTEXT_REQ_3}}
- {{CONTEXT_REQ_4}}

### {{OPERATION_TYPE_3}}

**Description**: {{OPERATION_3_DESC}}

**Agent**: {{SECONDARY_AGENT}}

**Context Requirements**:
- {{CONTEXT_REQ_5}}
- {{CONTEXT_REQ_6}}

## Verification Flow

```
User Request
    |
    v
Message Pre-Flight Compliance Check
    |
    v
{{SKILL_NAME}} Skill Activation
    |
    v
Context Analysis
    |
    v
{{PRIMARY_AGENT}} Invocation
    |
    v
Verifier Validation
    |
    +-> SUFFICIENT: Return result
    |
    +-> INSUFFICIENT: Revise
```

## Examples

### Example 1: {{EXAMPLE_1_TITLE}}

**Request**: "{{EXAMPLE_1_REQUEST}}"

**Skill Action**:
1. Detect {{DOMAIN}} domain trigger
2. Identify operation type: {{EXAMPLE_1_OPERATION}}
3. Invoke {{PRIMARY_AGENT}}

**Agent Context**:
```json
{
  "task": "{{EXAMPLE_1_TASK}}",
  "files": ["{{EXAMPLE_1_FILE}}"],
  "constraints": ["{{EXAMPLE_1_CONSTRAINT}}"]
}
```

**Output**: {{EXAMPLE_1_OUTPUT}}

### Example 2: {{EXAMPLE_2_TITLE}}

**Request**: "{{EXAMPLE_2_REQUEST}}"

**Skill Action**:
1. Detect {{DOMAIN}} domain trigger
2. Identify operation type: {{EXAMPLE_2_OPERATION}}
3. Invoke {{SECONDARY_AGENT}} for {{REASON}}

**Output**: {{EXAMPLE_2_OUTPUT}}

## Error Handling

| Scenario | Detection | Resolution |
|----------|-----------|------------|
| Agent unavailable | Timeout | Fallback to {{FALLBACK_AGENT}} |
| Invalid context | Validation | Request missing information |
| Quality failure | Verifier | Request revision |

## Metrics

- **Success Criteria**: Task completed, verifier passes
- **Token Efficiency**: Target < {{TOKEN_TARGET}} tokens

## Related Skills

- **Multi-domain**: orchestration/multi-skill-workflow
- **SDD Integration**: sdd-workflow/sdd-{{RELATED_PHASE}}
- **Quality**: validation/message-preflight

---

*Domain skill template version: 3.0.0*
*Skills-first architecture: Compliant*
