---
# ⚠️ DEPRECATED — MIGRATED TO PLUGIN
# This skill has been migrated to: plugins/sdd-governance/skills/qa-validation/
# Use the plugin version instead. This file will be removed in v5.0.
# Migration date: 2026-01-15
---

---
name: qa-validation
version: 3.0.0
category: validation
description: Validates quality metrics, coverage, and acceptance criteria.
triggers: ["QA validation", "quality assurance", "test coverage", "acceptance criteria", "quality gate"]
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
---

# QA Validation Skill

## Overview

Validation skill for quality assurance including test coverage validation, acceptance criteria verification, and quality gate enforcement. Critical for Principle II (Test-First Development) compliance.

## When to Use

- Before PR merge
- After test execution
- Quality gate checkpoints
- Coverage validation
- Acceptance criteria verification
- Release readiness check

## Configuration

### Allowed Tools
Read, Grep, Glob, Bash

### Agent Invocation

```yaml
agent: quality-specialist
context-subset:
  - coverage-report
  - test-results
  - acceptance-criteria
  - quality-thresholds
when: "quality validation is needed"
timeout: 5m
```

### Composes
- validation/message-preflight (pre-execution)
- domain/testing-operations (prerequisite)

## Instructions

### Step 1: Gather Quality Metrics

Collect quality data:
1. **Coverage**: Test coverage percentage
2. **Tests**: Pass/fail counts
3. **Linting**: Lint error count
4. **Types**: Type check results
5. **Security**: Security scan results

### Step 2: Validate Against Criteria

Check against thresholds:
```yaml
quality-thresholds:
  coverage: >= 80%      # Principle II
  tests: 100% passing
  lint-errors: 0
  type-errors: 0
  security-critical: 0
```

### Step 3: Generate QA Report

Produce validation report:
```yaml
qa-report:
  status: PASS | FAIL
  coverage: 85%
  tests: 120/120 passing
  lint: 0 errors
  types: 0 errors
  blockers: []
```

### Step 4: Gate Decision

Based on results:
- **PASS**: All criteria met, proceed allowed
- **FAIL**: Criteria not met, block with details

## Quality Criteria (Principle II)

| Metric | Threshold | Required |
|--------|-----------|----------|
| Coverage | >= 80% | Yes |
| Tests | 100% pass | Yes |
| Lint Errors | 0 | Yes |
| Type Errors | 0 | Yes |
| Security Critical | 0 | Yes |

## Constitutional Compliance

- **Principle II**: Coverage >= 80% enforced
- **Principle XI**: Input validation checked
- **Principle VII**: Quality metrics logged

## Validation Commands

```bash
# Run tests with coverage
npm test -- --coverage

# Check coverage threshold
npm test -- --coverage --coverageThreshold='{"global":{"lines":80}}'

# Run linting
npm run lint

# Run type check
npm run typecheck
```

## Quality Report Template

```markdown
## QA Validation Report

**Status**: PASS ✅ / FAIL ❌

### Metrics
- Coverage: XX%
- Tests: X/Y passing
- Lint Errors: X
- Type Errors: X

### Blockers
- [ ] Blocker 1
- [ ] Blocker 2

### Recommendations
- Recommendation 1
- Recommendation 2
```



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
  "skill": "qa-validation",
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

- domain/testing-operations - Test execution
- validation/constitutional-compliance - Constitutional checks
- governance/finalize - Pre-commit validation
