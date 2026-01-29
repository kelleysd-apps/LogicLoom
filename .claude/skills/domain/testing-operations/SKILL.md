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

## Related Skills

- domain/security-operations - Security testing
- validation/qa-validation - QA review
- sdd-workflow/sdd-tasks - Test task generation
