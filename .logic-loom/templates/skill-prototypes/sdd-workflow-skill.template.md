---
name: {{SKILL_NAME}}
version: 3.0.0
category: sdd-workflow
description: {{SKILL_DESCRIPTION}}
triggers:
  - {{PRIMARY_TRIGGER}}
  - {{SECONDARY_TRIGGERS}}
progressive-disclosure:
  layer-1-metadata:
    description: {{SHORT_DESCRIPTION}}
    triggers: [{{TRIGGER_LIST}}]
    primary-agent: {{PRIMARY_AGENT}}
  layer-2-instructions: true
  layer-3-examples: true
agent-invocations:
  - agent: {{PRIMARY_AGENT}}
    context-subset: [{{CONTEXT_FIELDS}}]
    expected-output: {{OUTPUT_TYPE}}
governance:
  pre-execution: validation/message-preflight
  post-verification: true
---

# {{SKILL_NAME}} Skill

## Purpose

{{DETAILED_PURPOSE}}

## SDD Workflow Position

```
/specify -> /plan -> /tasks -> {{POSITION_IN_FLOW}}
```

## Constitutional Compliance

- **Principle II (Test-First)**: {{TDD_REQUIREMENTS}}
- **Principle III (Contract-First)**: {{CONTRACT_REQUIREMENTS}}
- **Principle VI (Git Approval)**: NEVER execute git commands

## Instructions

### Prerequisites

{{PREREQUISITES}}

### Execution Steps

1. **Step 1**: {{STEP_1}}
2. **Step 2**: {{STEP_2}}
3. **Step 3**: {{STEP_3}}
4. **Validation**: {{VALIDATION_STEP}}
5. **Output**: {{OUTPUT_STEP}}

## Agent Invocation

```yaml
invoke: {{PRIMARY_AGENT}}
context:
  {{CONTEXT_KEY_1}}: {{CONTEXT_VALUE_1}}
  {{CONTEXT_KEY_2}}: {{CONTEXT_VALUE_2}}
expected:
  format: {{OUTPUT_FORMAT}}
  validation: {{VALIDATION_CRITERIA}}
```

## Quality Gates

- Pre-execution: message pre-flight compliance check required
- Post-verification: Verifier validates {{VALIDATION_TARGET}}

## Examples

### Example 1: {{EXAMPLE_1_TITLE}}

**Input**: {{EXAMPLE_1_INPUT}}

**Output**: {{EXAMPLE_1_OUTPUT}}

### Example 2: {{EXAMPLE_2_TITLE}}

**Input**: {{EXAMPLE_2_INPUT}}

**Output**: {{EXAMPLE_2_OUTPUT}}

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| {{ERROR_1}} | {{CAUSE_1}} | {{RESOLUTION_1}} |
| {{ERROR_2}} | {{CAUSE_2}} | {{RESOLUTION_2}} |

## Metrics

- **Success Criteria**: {{SUCCESS_CRITERIA}}
- **Performance Target**: {{PERFORMANCE_TARGET}}
- **Token Budget**: Layer 1: ~100, Layer 2: ~500, Layer 3: variable

## Related Skills

- **Upstream**: {{UPSTREAM_SKILL}}
- **Downstream**: {{DOWNSTREAM_SKILL}}
- **Composes with**: validation/message-preflight

---

*Skill template version: 3.0.0*
*Constitutional compliance: Verified*
