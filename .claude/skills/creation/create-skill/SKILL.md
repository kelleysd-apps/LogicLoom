---
name: create-skill
version: 3.0.0
category: creation
description: Creates new skill definitions following skills-first architecture v3.0.0
triggers:
  - create skill
  - new skill
  - /create-skill
  - add skill
  - generate skill
rl_metrics:
  success_rate: 0.0
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
progressive-disclosure:
  layer-1-metadata:
    description: "Creates new skill definitions with RL metrics and progressive disclosure"
    triggers: [create skill, new skill, /create-skill]
    primary-agent: system-architect
  layer-2-instructions: true
  layer-3-examples: true
agent-invocations:
  - agent: system-architect
    context-subset:
      - skill_name
      - skill_category
      - skill_purpose
      - triggers
      - target_agents
    expected-output: skill_definition
ds-star:
  pre-execution: validation/message-preflight
  post-verification: true
  auto-debug: conditional
---

# Create Skill

## Purpose

Creates new skill definitions following the skills-first architecture v3.0.0.
This skill ensures all new skills are created with proper structure including
RL metrics, progressive disclosure layers, and agent invocations.

## FR Reference

- **FR-203**: Skill creation capability

## Constitutional Compliance

- **Principle I (Library-First)**: Skills are standalone units
- **Principle III (Contract-First)**: Validates against skill-definition.yaml v3
- **Principle X (Skills-First)**: Ensures skills orchestrate, agents execute

## Instructions

### Prerequisites

1. FR-707 compliance check must pass
2. User must provide:
   - Skill name or purpose
   - Target domain/category
   - Key triggers (optional - can be generated)

### Step 1: Gather Requirements

Prompt user for:
```yaml
skill_name: <required>
category: <sdd-workflow | domain | orchestration | validation | creation | governance | integration>
purpose: <brief description>
triggers: <list of activation keywords>
primary_agent: <consolidated agent to invoke>
```

### Step 2: Select Template

Based on category, use appropriate template:
- `sdd-workflow` -> `.specify/templates/skill-prototypes/sdd-workflow-skill.template.md`
- `domain` -> `.specify/templates/skill-prototypes/domain-skill.template.md`
- `orchestration` -> `.specify/templates/skill-prototypes/orchestration-skill.template.md`

### Step 3: Generate Skill Definition

Replace template variables:
```yaml
{{SKILL_NAME}}: skill_name
{{SKILL_DESCRIPTION}}: purpose
{{CATEGORY}}: category
{{PRIMARY_TRIGGER}}: triggers[0]
{{PRIMARY_AGENT}}: primary_agent
```

Initialize RL metrics with defaults:
```yaml
rl_metrics:
  success_rate: 0.0
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
```

### Step 4: Create File Structure

```
.claude/skills/
  {category}/
    {skill_name}/
      SKILL.md          # Main skill definition
      reference.md      # Optional reference documentation
```

### Step 5: Validate

Run validation against skill-definition.yaml v3:
```bash
npm test -- tests/contracts/test_skill_definition_v3.test.js
```

### Step 6: Update Index

Regenerate skill-index.json:
```bash
./.specify/scripts/bash/generate-skill-index-v3.sh
```

## Agent Invocation

```yaml
invoke: system-architect
context:
  skill_name: "<user provided>"
  category: "<selected category>"
  purpose: "<skill purpose>"
  triggers: ["<trigger1>", "<trigger2>"]
  target_agents: ["<agent1>"]
expected:
  format: skill_definition
  validation: skill-definition.yaml v3
```

## DS-STAR Integration

```
User Request: "Create a skill for X"
    |
    v
[FR-707] Compliance Check
    |
    v
create-skill Activation
    |
    v
Gather Requirements
    |
    v
system-architect Invocation
    |
    v
Generate Skill Definition
    |
    v
Verifier Validation
    |
    v
Update skill-index.json
```

## Examples

### Example 1: Create Domain Skill

**Request**: "Create a skill for caching operations"

**Requirements Gathered**:
```yaml
skill_name: caching-operations
category: domain
purpose: Handles caching operations for performance optimization
triggers: [cache, caching, redis, memcached, invalidate]
primary_agent: operations-specialist
```

**Generated File**: `.claude/skills/domain/caching-operations/SKILL.md`

### Example 2: Create SDD Workflow Skill

**Request**: "Create a skill for code review workflow"

**Requirements Gathered**:
```yaml
skill_name: sdd-review
category: sdd-workflow
purpose: Conducts code review following SDD principles
triggers: [review, code review, PR review]
primary_agent: quality-specialist
```

**Generated File**: `.claude/skills/sdd-workflow/sdd-review/SKILL.md`

## Error Handling

| Scenario | Detection | Resolution |
|----------|-----------|------------|
| Missing name | Validation | Prompt user for skill name |
| Invalid category | Validation | Show valid categories |
| Agent not found | Index lookup | Show available agents |
| Validation failure | Contract test | Show specific violations |

## RL Metrics

- **Success Criteria**: Skill created and passes validation
- **Token Efficiency**: Track generation tokens
- **Learning**: Improve trigger suggestions based on usage

## Related Skills

- **validation/message-preflight**: Pre-execution check
- **creation/create-agent**: For creating agents
- **creation/create-template**: For creating templates

---

*Creation skill version: 3.0.0*
*Skills-first architecture: Compliant*
