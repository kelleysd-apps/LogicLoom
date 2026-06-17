# Testing Policy

**Version**: 1.0.0
**Effective Date**: TBD
**Authority**: Constitution v3.2.0 - Principle II (Test-First Development)
**Review Cycle**: Quarterly

---

## Purpose

This policy establishes comprehensive testing standards for the LogicLoom framework, enforcing Test-First Development (TDD) as a non-negotiable constitutional requirement.

---

## Constitutional Mandate

**Principle II: Test-First Development (IMMUTABLE - NON-NEGOTIABLE)**

Test-Driven Development (TDD) is mandatory for all code.

### Required Workflow
1. **Write tests** that define expected behavior
2. **Get user approval** on test scenarios
3. **Run tests** (they should fail initially - RED)
4. **Implement** the minimum code to make tests pass - GREEN
5. **Refactor** while keeping tests green - REFACTOR

**Violations of this principle are not permitted under any circumstances.**

---

## Scope

All code requires tests:
- Application code
- Library code
- Scripts and automation
- Configuration (where testable)
- Infrastructure as Code

**Exceptions**: None. No code without tests.

---

## Testing Pyramid

Follow the testing pyramid strategy:

```
        /\
       /  \     E2E Tests (10%)
      /----\    Few, slow, expensive
     /      \
    / Integration Tests (20%)
   /----------\  Moderate number
  /            \
 / Unit Tests (70%)
/----------------\
  Many, fast, cheap
```

### Distribution Guidelines

- **Unit Tests**: 70% - Fast, isolated, many
- **Integration Tests**: 20% - Medium speed, verify connections
- **E2E Tests**: 10% - Slow, expensive, critical paths only

---

## Test Types & Requirements

### Unit Tests (MANDATORY)

**Definition**: Test individual functions/methods in isolation

**Requirements**:
- ✅ Test all public methods/functions
- ✅ Mock external dependencies
- ✅ Cover edge cases and error paths
- ✅ Run in < 1ms per test
- ✅ No database, network, or file system
- ✅ ≥80% code coverage minimum

**Framework Examples**:
- JavaScript/TypeScript: Jest, Vitest, Mocha
- Python: pytest, unittest
- Go: testing package
- Java: JUnit

**Example**:
```typescript
// ✅ GOOD: Unit test with mocks
describe('UserService', () => {
  it('should create user with hashed password', async () => {
    const mockDB = jest.fn().mockResolvedValue({ id: 1 });
    const mockHasher = jest.fn().mockResolvedValue('hashed123');

    const service = new UserService(mockDB, mockHasher);
    const user = await service.createUser('user@example.com', 'password');

    expect(mockHasher).toHaveBeenCalledWith('password');
    expect(mockDB).toHaveBeenCalledWith({
      email: 'user@example.com',
      password: 'hashed123'
    });
  });
});
```

### Integration Tests (MANDATORY)

**Definition**: Test interactions between components

**Requirements**:
- ✅ Test contract compliance (Principle III)
- ✅ Test database interactions
- ✅ Test API endpoints
- ✅ Test message queues
- ✅ Run in < 100ms per test
- ✅ Use test database/services

**What to Test**:
- API request/response contracts
- Database queries and transactions
- External service integrations
- Middleware and authentication
- Error handling across boundaries

**Example**:
```typescript
// ✅ GOOD: Integration test with test DB
describe('POST /api/users', () => {
  beforeEach(async () => {
    await testDB.migrate.latest();
  });

  afterEach(async () => {
    await testDB.migrate.rollback();
  });

  it('should create user and return 201', async () => {
    const response = await request(app)
      .post('/api/users')
      .send({ email: 'test@example.com', password: 'password123' });

    expect(response.status).toBe(201);
    expect(response.body).toHaveProperty('id');

    // Verify database
    const user = await testDB('users').where({ id: response.body.id }).first();
    expect(user.email).toBe('test@example.com');
  });
});
```

### End-to-End (E2E) Tests (RECOMMENDED)

**Definition**: Test complete user workflows

**Requirements**:
- ✅ Test critical user paths
- ✅ Test authentication flows
- ✅ Test payment flows (if applicable)
- ✅ Test error recovery
- ✅ Run in < 10s per test
- ✅ Use production-like environment

**Framework Examples**:
- Playwright, Cypress, Selenium
- Postman for API E2E

**When Required**:
- User-facing applications
- Critical business workflows
- Payment processing
- Authentication systems

**Example**:
```typescript
// ✅ GOOD: E2E test with Playwright
test('user can sign up and log in', async ({ page }) => {
  // Sign up
  await page.goto('/signup');
  await page.fill('[name="email"]', 'test@example.com');
  await page.fill('[name="password"]', 'password123');
  await page.click('button[type="submit"]');

  // Verify redirect to dashboard
  await expect(page).toHaveURL('/dashboard');
  await expect(page.locator('h1')).toContainText('Welcome');

  // Log out
  await page.click('button:has-text("Logout")');

  // Log back in
  await page.goto('/login');
  await page.fill('[name="email"]', 'test@example.com');
  await page.fill('[name="password"]', 'password123');
  await page.click('button[type="submit"]');

  await expect(page).toHaveURL('/dashboard');
});
```

### Contract Tests (MANDATORY for APIs)

**Definition**: Verify API contracts match specifications

**Requirements**:
- ✅ One test per endpoint
- ✅ Validate request schemas
- ✅ Validate response schemas
- ✅ Validate error responses
- ✅ Match documented contracts

**Example**:
```typescript
// ✅ GOOD: Contract test
describe('GET /api/users/:id contract', () => {
  it('should match API contract', async () => {
    const response = await request(app).get('/api/users/1');

    // Validate against JSON Schema or OpenAPI spec
    expect(response.body).toMatchSchema({
      type: 'object',
      required: ['id', 'email', 'createdAt'],
      properties: {
        id: { type: 'number' },
        email: { type: 'string', format: 'email' },
        createdAt: { type: 'string', format: 'date-time' }
      }
    });
  });
});
```

---

## Test Coverage Requirements

### Minimum Coverage Thresholds

| Code Type | Statements | Branches | Functions | Lines |
|-----------|-----------|----------|-----------|-------|
| Application | 80% | 75% | 80% | 80% |
| Libraries | 90% | 85% | 90% | 90% |
| Critical paths | 100% | 100% | 100% | 100% |

### Critical Paths Requiring 100% Coverage

- Authentication and authorization
- Payment processing
- Data validation and sanitization
- Security-sensitive operations
- Data integrity operations

### Coverage Exemptions

Allowed to exclude from coverage:
- Generated code (with comment marker)
- Third-party code
- Trivial getters/setters (with approval)
- Deprecated code (scheduled for removal)

**How to Exempt**:
```typescript
/* istanbul ignore next */
function trivialGetter() {
  return this._value;
}
```

---

## Test-First Development (TDD) Workflow

### Step 1: Write Tests FIRST

Before writing implementation:
1. Understand requirements from specification
2. Write test cases covering happy path
3. Write test cases covering error cases
4. Write test cases covering edge cases
5. Get user approval on test scenarios

### Step 2: Run Tests (RED)

Tests should FAIL initially:
```bash
$ npm test
FAIL src/user-service.test.ts
  ● UserService › should create user
    UserService is not defined
```

**If tests pass initially, you're not doing TDD!**

### Step 3: Implement (GREEN)

Write minimum code to make tests pass:
```typescript
class UserService {
  async createUser(email, password) {
    // Minimum implementation
    return { id: 1, email };
  }
}
```

### Step 4: Run Tests (GREEN)

```bash
$ npm test
PASS src/user-service.test.ts
  ✓ UserService › should create user (5ms)
```

### Step 5: Refactor (REFACTOR)

Improve code while keeping tests green:
```typescript
class UserService {
  constructor(private db: Database, private hasher: Hasher) {}

  async createUser(email: string, password: string): Promise<User> {
    const hashedPassword = await this.hasher.hash(password);
    return this.db.users.create({ email, password: hashedPassword });
  }
}
```

### Step 6: Repeat

Repeat for each feature/function.

---

## Test Quality Standards

### Test Naming

Use descriptive test names:

```typescript
// ✅ GOOD: Descriptive
it('should return 400 when email is missing', () => {});

// ❌ BAD: Vague
it('works', () => {});
it('test1', () => {});
```

### Test Independence

Each test should be independent:

```typescript
// ✅ GOOD: Independent tests
describe('UserService', () => {
  let service;

  beforeEach(() => {
    service = new UserService();
  });

  it('should create user', async () => {
    const user = await service.createUser('email@test.com');
    expect(user).toBeDefined();
  });

  it('should list users', async () => {
    const users = await service.listUsers();
    expect(Array.isArray(users)).toBe(true);
  });
});

// ❌ BAD: Tests depend on each other
let userId;
it('should create user', async () => {
  const user = await service.createUser('email@test.com');
  userId = user.id; // ❌ Shared state
});

it('should get user', async () => {
  const user = await service.getUser(userId); // ❌ Depends on previous test
  expect(user).toBeDefined();
});
```

### Test Clarity

Tests should be clear and readable:

```typescript
// ✅ GOOD: Clear arrange-act-assert
it('should reject invalid email', async () => {
  // Arrange
  const invalidEmail = 'not-an-email';

  // Act & Assert
  await expect(service.createUser(invalidEmail, 'password'))
    .rejects
    .toThrow('Invalid email format');
});
```

### Test Data

Use meaningful test data:

```typescript
// ✅ GOOD: Realistic data
const testUser = {
  email: 'john.doe@example.com',
  name: 'John Doe',
  role: 'user'
};

// ❌ BAD: Meaningless data
const testUser = {
  email: 'a@b.c',
  name: 'x',
  role: 'y'
};
```

---

## Mocking & Test Doubles

### When to Mock

Mock external dependencies:
- ✅ Database connections
- ✅ External APIs
- ✅ File system operations
- ✅ Network requests
- ✅ Time/dates
- ✅ Random number generators

### Mocking Strategies

```typescript
// ✅ GOOD: Dependency injection enables mocking
class UserService {
  constructor(private db: Database) {}

  async getUser(id: number) {
    return this.db.users.findById(id);
  }
}

// Test with mock
const mockDB = { users: { findById: jest.fn() } };
const service = new UserService(mockDB);
```

### Test Doubles Types

1. **Stub**: Returns predetermined values
2. **Mock**: Verifies interactions
3. **Spy**: Wraps real implementation, records calls
4. **Fake**: Simplified implementation (in-memory DB)

---

## Continuous Integration (CI)

### Required CI Checks

All PRs must pass:
1. ✅ All tests pass
2. ✅ Coverage thresholds met
3. ✅ No test warnings or errors
4. ✅ Tests run in reasonable time (< 10 min)

### CI Configuration

```yaml
# Example: .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - run: npm ci
      - run: npm test
      - run: npm run test:coverage
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

---

## Test Data Management

### Test Databases

Use dedicated test databases:
- ✅ Separate from development DB
- ✅ Reset before each test suite
- ✅ Use migrations for schema
- ✅ Seed with minimal test data

### Test Fixtures

Manage test data with fixtures:

```typescript
// fixtures/users.ts
export const testUsers = {
  admin: {
    email: 'admin@example.com',
    role: 'admin'
  },
  user: {
    email: 'user@example.com',
    role: 'user'
  }
};
```

### Test Isolation

Ensure test isolation:
```typescript
beforeEach(async () => {
  await testDB.migrate.rollback();
  await testDB.migrate.latest();
  await testDB.seed.run();
});

afterEach(async () => {
  await testDB.destroy();
});
```

---

## Performance Testing

### Load Testing (Recommended for APIs)

Test system under load:
- Response time under load
- Concurrent user handling
- Resource usage
- Breaking points

### Benchmark Testing (Optional)

Track performance over time:
```typescript
describe('Performance benchmarks', () => {
  it('should process 1000 items in < 100ms', async () => {
    const start = Date.now();
    await service.processItems(1000);
    const duration = Date.now() - start;

    expect(duration).toBeLessThan(100);
  });
});
```

---

## Security Testing

### Security Test Requirements

Test security controls:
- ✅ Authentication bypasses
- ✅ Authorization checks
- ✅ Input validation
- ✅ SQL injection prevention
- ✅ XSS prevention
- ✅ CSRF protection

### Example Security Tests

```typescript
describe('Security: SQL Injection', () => {
  it('should prevent SQL injection in search', async () => {
    const maliciousInput = "'; DROP TABLE users; --";

    // Should not throw or execute SQL
    await expect(service.searchUsers(maliciousInput))
      .resolves
      .toEqual([]);
  });
});

describe('Security: Authorization', () => {
  it('should deny access to admin endpoint for regular user', async () => {
    const userToken = generateToken({ role: 'user' });

    const response = await request(app)
      .get('/admin/users')
      .set('Authorization', `Bearer ${userToken}`);

    expect(response.status).toBe(403);
  });
});
```

---

## Test Maintenance

### Keeping Tests Up to Date

When code changes:
1. Update failing tests
2. Add tests for new features
3. Remove tests for deleted features
4. Refactor tests with code
5. Keep tests DRY (use helpers)

### Test Debt

Avoid test debt:
- ❌ No skipped tests in main branch
- ❌ No commented-out tests
- ❌ No TODO tests
- ❌ No flaky tests

### Flaky Tests

Handle flaky tests:
1. Investigate root cause
2. Fix immediately
3. If can't fix: quarantine (separate suite)
4. Never ignore or skip permanently

---

## Metrics & Reporting

### Track These Metrics

- Test count (unit/integration/E2E)
- Code coverage percentage
- Test execution time
- Flaky test count
- Test failure rate
- Time to fix broken tests

### Coverage Reports

Generate and review coverage reports:
```bash
npm run test:coverage
open coverage/index.html
```

### Trend Analysis

Monitor trends over time:
- Coverage should increase or stay stable
- Test count should increase with code
- Execution time should stay reasonable
- Failure rate should stay low (<5%)

---

## Exceptions & Waivers

### No Exceptions for TDD

**Principle II is IMMUTABLE and NON-NEGOTIABLE.**

No code may be merged without tests. No exceptions.

### Emergency Hotfixes

Even emergency hotfixes require:
1. Tests written (can be simple)
2. Tests passing
3. Post-merge: Enhance tests within 24 hours

---

## Tools & Frameworks

### Recommended by Language

**JavaScript/TypeScript**:
- Unit: Jest, Vitest
- E2E: Playwright, Cypress
- Coverage: Istanbul/c8

**Python**:
- Unit: pytest
- Coverage: coverage.py
- E2E: Selenium

**Go**:
- Unit: testing package
- Coverage: go test -cover
- Mocking: testify

**Java**:
- Unit: JUnit 5
- Mocking: Mockito
- E2E: Selenium

---

## References

- Constitution v3.2.0: `.logic-loom/memory/constitution.md`
- Code Review Policy: `.docs/policies/code-review-policy.md`
- Security Policy: `.docs/policies/security-policy.md`

---

**Policy Owner**: Quality Department (testing-operations skill)
**Last Reviewed**: TBD
**Next Review**: TBD
