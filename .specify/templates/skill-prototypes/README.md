# Skill Prototype Templates

**Version**: 1.0.0
**Task**: T048
**FR**: FR-605

## Overview

This directory contains prototype templates for creating new skills following the skills-first architecture v3.0.0. These templates ensure consistent skill structure, constitutional compliance, and RL metrics integration.

## Available Templates

### 1. SDD Workflow Skill (`sdd-workflow-skill.template.md`)

Use for skills that are part of the Spec-Driven Development workflow:
- `/specify` related skills
- `/plan` related skills
- `/tasks` related skills
- `/debug` related skills
- `/finalize` related skills

**Characteristics**:
- Sequential workflow position
- Specific prerequisites
- Clear input/output contracts
- SDD phase integration

### 2. Domain Skill (`domain-skill.template.md`)

Use for skills that handle domain-specific operations:
- frontend-operations
- backend-operations
- database-operations
- testing-operations
- security-operations
- performance-operations
- devops-operations
- api-design

**Characteristics**:
- Domain keyword triggers
- Primary + fallback agent
- Operation type routing
- Domain-specific validation

### 3. Orchestration Skill (`orchestration-skill.template.md`)

Use for skills that coordinate multiple domains or workflows:
- multi-skill-workflow
- full-stack-feature
- migration-workflow

**Characteristics**:
- Multi-domain detection
- Skill sequencing
- Parallel execution support
- Credit assignment integration

## Template Variables

All templates use `{{VARIABLE_NAME}}` placeholders. Replace these with actual values when creating a new skill.

### Common Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{SKILL_NAME}}` | Skill identifier | `sdd-specification` |
| `{{SKILL_DESCRIPTION}}` | Brief description | `Handles feature specification` |
| `{{PRIMARY_TRIGGER}}` | Main activation keyword | `/specify` |
| `{{PRIMARY_AGENT}}` | Main agent to invoke | `specification-orchestrator` |

### RL Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `{{SUCCESS_RATE}}` | Initial success rate | `0.0` |
| `{{SELECTION_WEIGHT}}` | Initial selection weight | `0.5` |
| `{{TOKEN_TARGET}}` | Target token usage | Varies |

## Quality Rubrics

### Skill Definition Quality

| Criterion | Weight | Threshold |
|-----------|--------|-----------|
| Required fields present | 30% | 100% |
| Triggers well-defined | 20% | 3+ triggers |
| Agent invocations valid | 20% | References exist |
| Examples provided | 15% | 2+ examples |
| Error handling defined | 15% | 2+ scenarios |

### Progressive Disclosure Quality

| Layer | Target Tokens | Content |
|-------|---------------|---------|
| Layer 1 | ~100 | Metadata + RL metrics |
| Layer 2 | ~500 | Instructions + invocations |
| Layer 3 | Variable | Examples + references |

### Constitutional Compliance

| Principle | Requirement |
|-----------|-------------|
| I (Library-First) | Standalone skill |
| II (Test-First) | TDD noted |
| III (Contract-First) | Output format defined |
| VI (Git Approval) | No git commands |
| X (Skills-First) | Agent invocation via skill |

## Usage

### Creating a New Skill

1. **Choose Template**
   ```bash
   # Copy appropriate template
   cp .specify/templates/skill-prototypes/domain-skill.template.md \
      .claude/skills/domain/new-operations/SKILL.md
   ```

2. **Replace Variables**
   ```bash
   # Use sed or editor to replace placeholders
   sed -i 's/{{DOMAIN}}/new/g' SKILL.md
   sed -i 's/{{PRIMARY_AGENT}}/new-specialist/g' SKILL.md
   ```

3. **Validate Structure**
   ```bash
   # Run contract validation
   npm test -- tests/contracts/test_skill_definition_v3.test.js
   ```

4. **Add to Index**
   ```bash
   # Regenerate skill index
   ./.specify/scripts/bash/generate-skill-index-v3.sh
   ```

### Validation Checklist

- [ ] All `{{VARIABLE}}` placeholders replaced
- [ ] Frontmatter validates against skill-definition.yaml v3
- [ ] rl_metrics section present with defaults
- [ ] progressive-disclosure layers defined
- [ ] agent-invocations reference valid consolidated agents
- [ ] ds-star pre-execution includes message-preflight
- [ ] Examples demonstrate actual use cases
- [ ] Error handling covers common scenarios

## Integration with RL

New skills start with default RL metrics:
- `success_rate`: 0.0 (updated after invocations)
- `selection_weight`: 0.5 (adjusted by EMA)
- `invocation_count`: 0 (incremented on use)
- `avg_tokens`: 0 (calculated from actual usage)

RL learning improves selection over time based on:
- Task completion success
- Token efficiency
- User satisfaction

## Related Files

- `contracts/skill-definition.yaml` - Schema for validation
- `.claude/skill-index.json` - Skill registry
- `.specify/scripts/bash/rl/` - RL scripts
- `.docs/rl-metrics/skill-performance.json` - Performance tracking

---

*Template library version: 1.0.0*
*Skills-first architecture: v3.0.0*
