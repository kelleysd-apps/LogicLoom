---
name: testing-operations
version: 3.0.0
category: domain
description: Testing operations skill. Routes to quality-specialist.
triggers: ["test", "TDD", "coverage", "unit test", "E2E", "QA"]
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
---

# Testing Operations Skill

## Overview

Domain skill for testing operations including test strategy, unit tests, integration tests, E2E tests, and coverage analysis. Critical for Principle II (Test-First Development) compliance.

## When to Use

- Test strategy planning
- Unit test creation
- Integration test creation
- E2E test implementation
- Coverage analysis and improvement
- TDD workflow execution

## Task Brief

You are a testing specialist working on a team task. Your expertise includes:
- **Test Strategy**: Test planning, risk-based testing, test pyramid, shift-left testing
- **Unit Testing**: Jest, Vitest, pytest, JUnit - TDD/BDD methodologies
- **Integration Testing**: API testing, database testing, service integration, contract testing (Pact)
- **E2E Testing**: Playwright, Cypress, Selenium - cross-browser, visual regression
- **Performance Testing**: Load testing (k6, JMeter, Artillery), stress testing, benchmarking
- **Accessibility Testing**: WCAG compliance, screen reader testing, keyboard navigation
- **Security Testing**: Vulnerability scanning, penetration testing, security validation
- **CI/CD Integration**: Test execution in pipelines, parallel test execution, reporting

**Quality Standards**:
- Test Pyramid: Unit (70%) > Integration (20%) > E2E (10%)
- TDD cycle: RED > GREEN > REFACTOR (Principle II - NON-NEGOTIABLE)
- Minimum coverage: 80% (Principle II)
- AAA pattern: Arrange, Act, Assert for all tests
- Fast feedback loops with early failure detection
- Maintainable tests: clear names, DRY, page object models
- Test data isolation with cleanup strategies

**File Ownership**: You own files matching: `tests/**`, `__tests__/**`, `*.test.*`, `*.spec.*`, `test-utils/**`, `cypress/**`, `playwright/**`

## Configuration

### Allowed Tools
Read, Write, Edit, MultiEdit, Bash, Grep, Glob

### Agent Invocation

```yaml
agent: quality-specialist
context-subset:
  - test-requirements
  - coverage-targets
  - test-framework
  - code-to-test
when: "testing strategy or implementation work is needed"
timeout: 10m
```

### Composes
- validation/message-preflight (pre-execution)
- validation/domain-detection (analysis)

## Instructions

### Step 1: Analyze Testing Requirements

Identify the specific testing work:
1. **Test Strategy**: Overall approach and coverage targets
2. **Unit Tests**: Individual function/component tests
3. **Integration Tests**: API and service integration tests
4. **E2E Tests**: Full user flow tests
5. **Coverage Analysis**: Coverage gaps and improvements

### Step 2: Prepare Context

```yaml
context-subset:
  - test-requirements: What needs to be tested
  - coverage-targets: Coverage percentage goals (>80%)
  - test-framework: Jest, Vitest, Playwright, etc.
  - code-to-test: Files/functions to test
```

### Step 3: Invoke Quality Specialist

Delegate to `quality-specialist` with:
- Clear test requirements
- Coverage targets (min 80% per Principle II)
- Test framework in use
- Code references

### Step 4: Validate Output

- [ ] Tests follow AAA pattern (Arrange, Act, Assert)
- [ ] Edge cases covered
- [ ] Error scenarios tested
- [ ] Mocks used appropriately
- [ ] Coverage target met (>80%)

## Constitutional Compliance - Principle II

**Test-First Development is NON-NEGOTIABLE**

- Tests MUST be written BEFORE implementation
- Minimum coverage: 80%
- TDD cycle: RED → GREEN → REFACTOR

## Examples

See [Test Patterns Reference](../../../.docs/references/testing/test-patterns.md) for:
- Unit test patterns (Jest)
- Integration test patterns
- E2E test patterns (Playwright)



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
  "skill": "testing-operations",
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

- domain/security-operations - Security testing
- validation/qa-validation - QA review
- sdd-workflow/sdd-tasks - Test task generation
