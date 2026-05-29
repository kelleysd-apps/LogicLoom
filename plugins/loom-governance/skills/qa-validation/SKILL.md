---
name: qa-validation
version: 3.0.0
category: validation
description: Validates quality metrics, coverage, and acceptance criteria.
triggers: ["QA validation", "quality assurance", "test coverage", "acceptance criteria", "quality gate"]
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

### Skill Invocation

```yaml
skill: testing-operations
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
## Related Skills

- domain/testing-operations - Test execution
- validation/constitutional-compliance - Constitutional checks
- governance/finalize - Pre-commit validation
