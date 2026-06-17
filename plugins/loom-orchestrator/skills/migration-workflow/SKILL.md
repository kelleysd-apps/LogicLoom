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
skill-invocations:
  - skill: team-orchestration
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
  layer2:
    - instructions
    - agent-invocations
    - composes
    - allowed-tools
  layer3:
    - examples
    - references
---

# Migration Workflow Orchestration

## Overview

This orchestration skill manages migration workflows for the skills-first architecture
transition. It coordinates the migration from legacy agent-first patterns to the
new skills-first approach, ensuring backward compatibility during the hybrid mode
period.

## Task Brief

You are the migration workflow orchestrator. Your job is to manage architectural
transitions including agent-to-skill migrations, skill version upgrades, agent
consolidation, and legacy pattern conversion within the SDD framework.

**Key responsibilities:**
- Analyze migration targets and determine migration type (agent-to-skill, version upgrade, consolidation)
- Create detailed migration plans with source, target, rollback strategy, and validation criteria
- Execute migrations in correct sequence: create target -> update routing -> validate -> deprecate source
- Maintain backward compatibility during hybrid mode (legacy + new patterns coexist)
- Validate that no functionality is lost after migration completes
- Track and document all migration decisions for audit trail

**Constitutional constraints:**
- Principle V: Progressive Enhancement - gradual migration, never big-bang
- Principle VIII: Documentation Sync - migration documentation kept current
- Principle X: Delegation - route complex migrations to team-orchestration skill
- Principle IV: Idempotency - migrations must be safe to retry

**Error handling:**
- Migration failure: Execute rollback strategy, restore routing, re-enable legacy pattern
- Validation failure: Block migration completion, report specific failures, suggest fixes
- Partial migration: Track progress, allow resume from last successful step

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
2. **Skill Upgrade**: v2 to v3 skill contract
3. **Workflow Update**: Legacy patterns to skills-first
4. **Configuration**: Update routing and indexes

### Step 2: Create Migration Plan

Build a migration plan:

```yaml
migration-plan:
  type: agent-to-skill
  source:
    name: frontend-operations (legacy agent)
    type: agent
    location: plugins/<legacy-plugin>/agents/frontend-operations.md
  target:
    brief: get_domain_brief frontend
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
3. **Update routing** in plugin manifest (plugins/*/plugin.json)
4. **Update agent registry** at .docs/agents/agent-registry.json
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

## Skill Invocation

```yaml
skill: team-orchestration
purpose: Coordinate multi-skill workflows and migrations
plugin: loom-orchestrator
delegates-to:
  - orchestration/multi-skill-workflow
  - orchestration/migration-workflow
```

## Migration Types

### Agent to Skill Migration

```
frontend-operations (legacy agent)
       |
       v
get_domain_brief frontend (registry brief)
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
progressive-disclosure:
  layer1: [name, triggers]
  layer2: [instructions]
  layer3: [examples]
```

### Agent Consolidation

| Original | Consolidated |
|----------|--------------|
| frontend-operations (legacy agent) | implementation-specialist |
| backend-operations (legacy agent) | implementation-specialist |
| monitoring / devops (legacy agent) | operations-specialist |
| performance-operations (legacy agent) | operations-specialist |
| testing-operations (legacy agent) | quality-specialist |
| security-operations (legacy agent) | quality-specialist |

## Migration Scripts

### migrate-agent-to-skill.sh
```bash
# Usage: ./migrate-agent-to-skill.sh <agent-name> <target-brief>
./migrate-agent-to-skill.sh frontend-operations get_domain_brief-frontend
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
## Related Skills

- **orchestration/multi-skill-workflow**: For complex migrations
- **validation/constitutional-compliance**: For validation
- **governance/finalize**: For pre-commit checks

## Constitutional Compliance

- **Principle X (Delegation)**: Routes to workflow-coordinator
- **Principle VIII (Documentation)**: Migration documented
- **Principle V (Progressive Enhancement)**: Gradual migration
