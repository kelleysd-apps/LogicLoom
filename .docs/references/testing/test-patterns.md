# Test Patterns Reference

Reference patterns for testing operations skill.

## Unit Test (Jest)

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

  it('should sum item prices', () => {
    const cart = [{ price: 10 }, { price: 20 }];
    expect(calculateTotal(cart)).toBe(30);
  });
});
```

## Integration Test

```typescript
describe('POST /api/users', () => {
  it('should create user and return 201', async () => {
    const response = await request(app)
      .post('/api/users')
      .send({ email: 'test@example.com' });

    expect(response.status).toBe(201);
    expect(response.body.id).toBeDefined();
  });

  it('should return 400 for invalid email', async () => {
    const response = await request(app)
      .post('/api/users')
      .send({ email: 'invalid' });

    expect(response.status).toBe(400);
  });
});
```

## E2E Test (Playwright)

```typescript
test('user can sign up', async ({ page }) => {
  await page.goto('/signup');
  await page.fill('[name="email"]', 'test@example.com');
  await page.fill('[name="password"]', 'SecureP@ss123');
  await page.click('button[type="submit"]');
  await expect(page).toHaveURL('/dashboard');
});

test('user can login', async ({ page }) => {
  await page.goto('/login');
  await page.fill('[name="email"]', 'test@example.com');
  await page.fill('[name="password"]', 'SecureP@ss123');
  await page.click('button[type="submit"]');
  await expect(page.locator('h1')).toContainText('Welcome');
});
```

## Test Coverage Standards

Per Principle II (Test-First Development):
- Minimum coverage: 80%
- TDD cycle: RED → GREEN → REFACTOR
- Tests written BEFORE implementation
