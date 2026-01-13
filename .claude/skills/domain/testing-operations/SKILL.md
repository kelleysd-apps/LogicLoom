---
name: testing-operations
version: 3.0.0
description: |
  Domain skill for testing operations including test strategy, unit tests, integration tests,
  E2E tests, and coverage analysis. Routes to quality-specialist agent for execution.
  Critical for Principle II (Test-First Development) compliance.
category: domain
triggers:
  - "test"
  - "TDD"
  - "E2E"
  - "coverage"
  - "unit test"
  - "QA"
  - "test plan"
  - "integration test"
allowed-tools:
  - Read
  - Write
  - Edit
  - MultiEdit
  - Bash
  - Grep
  - Glob
agent-invocations:
  - agent: quality-specialist
    context-subset:
      - test-requirements
      - coverage-targets
      - test-framework
      - code-to-test
    when: "testing strategy or implementation work is needed"
    timeout: 10m
composes:
  - skill: validation/message-preflight
    phase: pre-execution
  - skill: validation/domain-detection
    phase: analysis
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

# Testing Operations Skill

## Overview

This skill handles all testing operations including test strategy, unit tests,
integration tests, E2E tests, and coverage analysis. It is critical for
Principle II (Test-First Development) compliance. Routes to `quality-specialist`.

## When to Use

Activate this skill when the user request involves:
- Test strategy planning
- Unit test creation
- Integration test creation
- E2E test implementation
- Coverage analysis
- Test-driven development
- QA validation

## Instructions

### Step 1: Analyze Testing Requirements

Identify the specific testing work needed:

1. **Test Strategy**: Overall approach and coverage targets
2. **Unit Tests**: Individual function/component tests
3. **Integration Tests**: API and service integration tests
4. **E2E Tests**: Full user flow tests
5. **Coverage Analysis**: Coverage gaps and improvements

### Step 2: Prepare Context for Agent

Gather minimal required context:

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

Check agent output for:
- [ ] Tests follow AAA pattern (Arrange, Act, Assert)
- [ ] Edge cases covered
- [ ] Error scenarios tested
- [ ] Mocks used appropriately
- [ ] Coverage target met (>80%)

## Context Requirements

| Field | Required | Description |
|-------|----------|-------------|
| test-requirements | Yes | What to test |
| coverage-targets | Yes | Coverage goals |
| test-framework | Yes | Testing framework |
| code-to-test | Yes | Code references |

## Agent Invocation

```yaml
agent: quality-specialist
purpose: Ensure quality through testing and security review
department: quality
merged-from:
  - testing-specialist
  - security-specialist
skill-portfolio:
  - domain/testing-operations
  - domain/security-operations
  - validation/qa-validation
```

## Constitutional Compliance - Principle II

**Test-First Development is NON-NEGOTIABLE**

From Constitution v1.6.0:
> Tests MUST be written BEFORE implementation
> Minimum coverage: 80%
> TDD cycle: Write failing test -> Implement -> Refactor

### TDD Workflow

1. **Write failing tests first** (RED)
2. **Get approval** for test approach
3. **Implement** to make tests pass (GREEN)
4. **Refactor** while keeping tests green

## Quality Checks

Before completing:
- [ ] Tests written before implementation (TDD)
- [ ] Coverage > 80%
- [ ] Happy path tested
- [ ] Error cases tested
- [ ] Edge cases tested
- [ ] Mocks don't hide bugs

## Test Patterns

### Unit Test (Jest)
```typescript
describe('calculateTotal', () => {
  it('should return 0 for empty cart', () => {
    // Arrange
    const cart = [];

    // Act
    const result = calculateTotal(cart);

    // Assert
    expect(result).toBe(0);
  });
});
```

### Integration Test
```typescript
describe('POST /api/users', () => {
  it('should create user and return 201', async () => {
    const response = await request(app)
      .post('/api/users')
      .send({ email: 'test@example.com' });

    expect(response.status).toBe(201);
    expect(response.body.id).toBeDefined();
  });
});
```

### E2E Test (Playwright)
```typescript
test('user can sign up', async ({ page }) => {
  await page.goto('/signup');
  await page.fill('[name="email"]', 'test@example.com');
  await page.click('button[type="submit"]');
  await expect(page).toHaveURL('/dashboard');
});
```

## Related Skills

- **domain/security-operations**: For security testing
- **validation/qa-validation**: For QA review
- **sdd-workflow/sdd-tasks**: For test task generation

## Constitutional Compliance

- **Principle II (Test-First)**: MANDATORY - tests first, >80% coverage
- **Principle X (Delegation)**: Routes to quality-specialist
- **Principle VII (Observability)**: Test results logged
