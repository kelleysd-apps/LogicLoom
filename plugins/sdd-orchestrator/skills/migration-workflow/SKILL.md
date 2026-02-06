---
name: migration-workflow
version: 3.0.0
description: |
  Orchestration skill for managing migration workflows including agent-to-skill migration,
  pattern upgrades, and architectural transitions. Coordinates the skills-first migration
  from legacy agent patterns.
category: orchestration
triggers:
  - "migration"
  - "migrate patterns"
  - "upgrade workflow"
  - "agent to skill"
  - "pattern migration"
allowed-tools:
  - Read
  - Write
  - Edit
  - MultiEdit
  - Bash
  - Grep
  - Glob
agent-invocations:
  - agent: workflow-coordinator
    context-subset:
      - migration-plan
      - source-pattern
      - target-pattern
      - rollback-strategy
    when: "migration orchestration is needed"
    timeout: 30m
composes:
  - skill: validation/message-preflight
    phase: pre-execution
  - skill: validation/constitutional-compliance
    phase: validation
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

# Migration Workflow Orchestration

## Overview

This orchestration skill manages migration workflows for the skills-first architecture
transition. It coordinates the migration from legacy agent-first patterns to the
new skills-first approach, ensuring backward compatibility during the hybrid mode
period.

## When to Use

Activate this skill when:
- Migrating from agent-first to skills-first
- Upgrading skill definitions to v3
- Consolidating agents (15 -> 8)
- Converting legacy workflows

## Instructions

### Step 1: Analyze Migration Target

Identify what needs migration:

1. **Agent Migration**: Convert agent to skill + consolidated agent
2. **Skill Upgrade**: v2 to v3 with RL metrics
3. **Workflow Update**: Legacy patterns to skills-first
4. **Configuration**: Update routing and indexes

### Step 2: Create Migration Plan

Build a migration plan:

```yaml
migration-plan:
  type: agent-to-skill
  source:
    name: frontend-specialist
    type: agent
    location: .claude/agents/engineering/frontend-specialist.md
  target:
    skill: domain/frontend-operations
    agent: implementation-specialist (consolidated)
  rollback-strategy: Keep source until validated
  validation:
    - Skill definition validates against v3 contract
    - Agent consolidation map updated
    - Routing table updated
    - Integration tests pass
```

### Step 3: Execute Migration

For agent-to-skill migration:

1. **Create skill** if not exists
2. **Update agent** to consolidated version
3. **Update routing** in skill-index.json
4. **Update consolidation map** in agent-index.json
5. **Test** new pattern works
6. **Mark legacy** as deprecated

### Step 4: Validate and Rollback

Validate migration:
- [ ] New skill activates correctly
- [ ] Consolidated agent invokes correctly
- [ ] Legacy pattern still works (hybrid mode)
- [ ] No functionality lost

Rollback if needed:
1. Revert routing changes
2. Re-enable legacy agent
3. Log rollback reason

## Context Requirements

| Field | Required | Description |
|-------|----------|-------------|
| migration-plan | Yes | Migration steps |
| source-pattern | Yes | What to migrate from |
| target-pattern | Yes | What to migrate to |
| rollback-strategy | Yes | How to rollback |

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

## Migration Types

### Agent to Skill Migration

```
frontend-specialist (legacy)
       |
       v
domain/frontend-operations (skill)
       |
       v
implementation-specialist (consolidated agent)
```

### Skill v2 to v3 Upgrade

```yaml
# v2 (before)
name: skill-name
version: 1.0.0
description: ...
triggers: [...]

# v3 (after)
name: skill-name
version: 3.0.0
description: ...
triggers: [...]
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
progressive-disclosure:
  layer1: [name, triggers, rl_metrics]
  layer2: [instructions]
  layer3: [examples]
```

### Agent Consolidation

| Original | Consolidated |
|----------|--------------|
| frontend-specialist | implementation-specialist |
| full-stack-developer | implementation-specialist |
| devops-engineer | operations-specialist |
| performance-engineer | operations-specialist |
| testing-specialist | quality-specialist |
| security-specialist | quality-specialist |

## Migration Scripts

### migrate-agent-to-skill.sh
```bash
# Usage: ./migrate-agent-to-skill.sh <agent-name> <skill-path>
./migrate-agent-to-skill.sh frontend-specialist domain/frontend-operations
```

### upgrade-skill-to-v3.sh
```bash
# Usage: ./upgrade-skill-to-v3.sh <skill-path>
./upgrade-skill-to-v3.sh sdd-workflow/sdd-specification
```

### consolidate-agents.sh
```bash
# Usage: ./consolidate-agents.sh --verify
./consolidate-agents.sh --execute
```

## Quality Checks

Before completing:
- [ ] Migration plan documented
- [ ] Source pattern identified
- [ ] Target pattern created
- [ ] Rollback strategy defined
- [ ] Validation tests pass
- [ ] Legacy pattern marked deprecated

## Deprecation Handling

During hybrid mode (Phase 1-2):
- Legacy patterns work but emit warnings
- Migration tracking enabled
- Users guided to new patterns

After hybrid mode (Phase 3-4):
- Legacy patterns blocked
- Forced migration if not converted
- Constitutional enforcement updated



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
  "skill": "migration-workflow",
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

- **orchestration/multi-skill-workflow**: For complex migrations
- **validation/constitutional-compliance**: For validation
- **governance/finalize**: For pre-commit checks

## Constitutional Compliance

- **Principle X (Delegation)**: Routes to workflow-coordinator
- **Principle VIII (Documentation)**: Migration documented
- **Principle V (Progressive Enhancement)**: Gradual migration
