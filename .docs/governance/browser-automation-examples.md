# Browser Automation Examples

**Version**: 1.0.0
**Feature**: 003-governance-browser-enhancement
**MCP Tools**: browsermcp, chrome-devtools

---

## Overview

This document provides 10 practical examples of browser automation using Browser MCP and Chrome DevTools MCP servers. These examples demonstrate governance validation, testing, and inspection capabilities.

---

## Example 1: Navigate and Screenshot

### Use Case
Visual validation of deployed application or governance compliance dashboard.

### Prompt
```
Navigate to https://example.com and take a screenshot
```

### Expected Behavior
1. Uses `browser_navigate` to load URL
2. Waits for page load completion
3. Uses `browser_screenshot` to capture viewport
4. Returns screenshot (base64 or file path)

### Constitutional Compliance
- ✅ **Principle VII** (Observability): Visual evidence of deployment state
- ✅ **Principle XV** (File Organization): Screenshots saved to appropriate location

### Example Output
```
✅ Navigated to https://example.com
✅ Screenshot saved: .docs/screenshots/example-com-2025-12-19.png
```

---

## Example 2: Fill Login Form

### Use Case
Automated testing of authentication flow (test environment only).

### Prompt
```
Go to http://localhost:3000/login and fill in:
- Email: test@example.com
- Password: testpass123
Do NOT submit the form, just fill it.
```

### Expected Behavior
1. Navigates to login page
2. Uses `browser_click` to focus email field
3. Uses `browser_fill` to enter email
4. Uses `browser_click` to focus password field
5. Uses `browser_fill` to enter password
6. Stops without submitting (per instruction)

### Constitutional Compliance
- ✅ **Principle II** (Test-First): Validates test scenario
- ⚠️ **Security Warning**: Use test credentials only, never production

### Example Output
```
✅ Navigated to http://localhost:3000/login
✅ Filled email: test@example.com
✅ Filled password: ********* (hidden)
⚠️  Form not submitted (as requested)
```

---

## Example 3: Check Console for Errors

### Use Case
Validate no JavaScript errors on deployed page (governance compliance check).

### Prompt
```
Navigate to https://myapp.com and check the console for any errors
```

### Expected Behavior
1. Navigates to URL
2. Uses `browser_console_logs` to retrieve console output
3. Filters for error and warning levels
4. Reports findings

### Constitutional Compliance
- ✅ **Principle VII** (Observability): Structured logging inspection
- ✅ **Principle II** (Test-First): Validation test execution

### Example Output
```
✅ Navigated to https://myapp.com
📋 Console inspection:

Errors: 0
Warnings: 2
  ⚠️  Warning: Cookie 'session' will expire soon
  ⚠️  Warning: Deprecated API call in analytics.js:42

✅ No critical errors found
```

---

## Example 4: Network Traffic Inspection

### Use Case
Verify API endpoints are being called correctly (contract validation).

### Prompt
```
Navigate to https://myapp.com/dashboard and show me all API calls made
```

### Expected Behavior
1. Navigates to URL
2. Uses `devtools_get_network` to capture network activity
3. Filters for XHR/Fetch requests
4. Lists API endpoints with status codes

### Constitutional Compliance
- ✅ **Principle III** (Contract-First): Validates API contract compliance
- ✅ **Principle VII** (Observability): Network monitoring

### Example Output
```
✅ Navigated to https://myapp.com/dashboard
📡 Network Traffic:

API Calls:
1. GET /api/user/profile → 200 OK (142ms)
2. GET /api/dashboard/stats → 200 OK (89ms)
3. POST /api/events/track → 201 Created (56ms)

Total: 3 requests, 0 failures
```

---

## Example 5: Performance Tracing

### Use Case
Measure page load performance (Principle VII: Observability).

### Prompt
```
Navigate to https://myapp.com and measure page load performance
```

### Expected Behavior
1. Uses `devtools_performance_trace` to start tracing
2. Navigates to URL
3. Waits for load complete
4. Stops tracing
5. Reports timing metrics (FCP, LCP, TTI)

### Constitutional Compliance
- ✅ **Principle VII** (Observability): Performance monitoring
- ✅ **Principle V** (Progressive Enhancement): Baseline metrics for optimization

### Example Output
```
✅ Performance Trace Complete

Metrics:
- First Contentful Paint (FCP): 1.2s
- Largest Contentful Paint (LCP): 2.4s
- Time to Interactive (TTI): 3.1s
- Total Blocking Time (TBT): 180ms

⚠️  LCP exceeds recommended 2.5s threshold
💡 Consider optimizing largest content element
```

---

## Example 6: Form Validation Testing

### Use Case
Test client-side validation rules (Principle II: Test-First).

### Prompt
```
Go to http://localhost:3000/register and test the email validation:
1. Enter invalid email "notanemail"
2. Check if validation error appears
```

### Expected Behavior
1. Navigates to registration page
2. Fills email field with invalid value
3. Uses `browser_click` to trigger validation (blur event)
4. Uses `browser_console_logs` or DOM inspection to check for error message
5. Reports validation result

### Constitutional Compliance
- ✅ **Principle II** (Test-First): Validates test coverage
- ✅ **Principle XI** (Input Validation): Confirms validation works

### Example Output
```
✅ Navigated to http://localhost:3000/register
✅ Entered invalid email: "notanemail"
✅ Validation triggered

Result:
  ✅ Error message displayed: "Please enter a valid email address"
  ✅ Form submission blocked
  ✅ Client-side validation PASSED
```

---

## Example 7: Screenshot Comparison (Regression)

### Use Case
Visual regression testing for UI changes.

### Prompt
```
Take a screenshot of https://myapp.com/profile and compare it to the baseline at .docs/screenshots/baseline-profile.png
```

### Expected Behavior
1. Navigates to profile page
2. Takes screenshot
3. Compares with baseline (if comparison tool available)
4. Reports differences

### Constitutional Compliance
- ✅ **Principle II** (Test-First): Regression test
- ✅ **Principle XII** (Design System): UI consistency validation

### Example Output
```
✅ Screenshot taken: .docs/screenshots/profile-2025-12-19.png
📸 Comparing with baseline...

Differences Found:
  ⚠️  Avatar image changed (expected)
  ⚠️  Last login timestamp different (expected)
  ✅ No unexpected UI changes

Visual Regression: PASSED
```

---

## Example 8: Accessibility Check

### Use Case
Validate WCAG compliance (Principle XII: Design System includes a11y).

### Prompt
```
Navigate to https://myapp.com and check for accessibility issues
```

### Expected Behavior
1. Navigates to URL
2. Uses `devtools_evaluate_js` to run accessibility audit (e.g., axe-core)
3. Reports violations

### Constitutional Compliance
- ✅ **Principle XII** (Design System): Accessibility is part of design requirements

### Example Output
```
✅ Navigated to https://myapp.com
♿ Accessibility Audit:

Issues Found:
  ❌ Critical (1): Missing alt text on image
     Element: <img src="/logo.png">
     Impact: High
     Fix: Add alt="Company Logo"

  ⚠️  Warning (2): Low contrast ratio
     Element: <p class="subtext">
     Impact: Medium
     Fix: Increase contrast to 4.5:1 minimum

Total: 3 issues (1 critical, 2 warnings)
```

---

## Example 9: Local Storage Inspection

### Use Case
Verify session state and feature flags (Principle V: Progressive Enhancement).

### Prompt
```
Navigate to https://myapp.com and show me what's stored in localStorage
```

### Expected Behavior
1. Navigates to URL
2. Uses `devtools_evaluate_js` to access `window.localStorage`
3. Lists key-value pairs
4. Checks for sensitive data (warns if found)

### Constitutional Compliance
- ✅ **Principle XI** (Output Sanitization): Checks for secrets in localStorage
- ✅ **Principle V** (Progressive Enhancement): Feature flag inspection

### Example Output
```
✅ Navigated to https://myapp.com
💾 LocalStorage Contents:

Keys:
1. theme: "dark"
2. language: "en-US"
3. featureFlags: {"newDashboard": true, "betaFeatures": false}
4. lastVisit: "2025-12-19T14:30:00Z"

⚠️  Security Check:
  ✅ No API keys found
  ✅ No passwords found
  ✅ No sensitive tokens found

Storage: CLEAN
```

---

## Example 10: Multi-Step Workflow Test

### Use Case
End-to-end integration test (Principle II: Test-First).

### Prompt
```
Test the complete user registration flow:
1. Navigate to http://localhost:3000/register
2. Fill in email, password, and name
3. Click submit
4. Verify redirect to /welcome
5. Take screenshot of welcome page
```

### Expected Behavior
1. Navigates to registration page
2. Fills all form fields sequentially
3. Submits form
4. Waits for navigation to complete
5. Verifies URL changed to /welcome
6. Takes screenshot for evidence

### Constitutional Compliance
- ✅ **Principle II** (Test-First): Integration test
- ✅ **Principle VII** (Observability): Comprehensive test logging

### Example Output
```
✅ Step 1: Navigated to http://localhost:3000/register
✅ Step 2: Form filled
   - Email: test-user-12345@example.com
   - Password: ********* (hidden)
   - Name: Test User
✅ Step 3: Form submitted
✅ Step 4: Redirected to http://localhost:3000/welcome
✅ Step 5: Screenshot saved: .docs/screenshots/welcome-2025-12-19.png

Integration Test: PASSED ✅
```

---

## Error Handling Patterns

### Pattern 1: Timeout Handling

```
Navigate to https://slow-site.com and wait up to 30 seconds for load
```

**Implementation**:
- Set timeout in `browser_navigate` call
- Handle timeout gracefully
- Report partial results if available

**Output**:
```
⏳ Navigating to https://slow-site.com (timeout: 30s)
⚠️  Page load timeout after 30s
📊 Partial results:
   - DOM loaded: Yes
   - Images loaded: No (3 pending)
   - Scripts loaded: Partial (2/5)

Recommendation: Optimize page load time
```

---

### Pattern 2: Element Not Found

```
Click the 'Submit' button on the current page
```

**Implementation**:
- Use `browser_click` with selector
- Handle element not found error
- Suggest alternatives

**Output**:
```
❌ Element not found: button with text "Submit"

Debugging:
  - Checked selectors: button:contains("Submit"), input[type="submit"]
  - Page fully loaded: Yes
  - Console errors: None

💡 Did you mean:
  - Button with text "Send" (found)
  - Button with text "Continue" (found)
```

---

### Pattern 3: Permission Denied

```
Take a screenshot of chrome://settings
```

**Implementation**:
- Attempt operation
- Catch permission error
- Explain restriction

**Output**:
```
❌ Permission Denied

Browser MCP cannot access chrome:// internal pages for security reasons.

Allowed:
  ✅ http:// and https:// URLs
  ✅ localhost and development servers
  ✅ file:// (if extension has permission)

Blocked:
  ❌ chrome:// internal pages
  ❌ chrome-extension:// pages
  ❌ about: pages
```

---

## Best Practices

### 1. Use Test Environment
```bash
# Good
"Navigate to http://localhost:3000/test-page"

# Bad (production)
"Navigate to https://production.myapp.com"
```

### 2. Never Commit Secrets
```bash
# Good
"Fill login form with test credentials from .env.test"

# Bad
"Fill login form with email admin@real.com and password MyP@ssw0rd!"
```

### 3. Clean Up After Tests
```bash
# Good
"After testing, clear cookies and localStorage"

# Bad
"Leave test session active"
```

### 4. Validate, Don't Just Execute
```bash
# Good
"Submit form and verify redirect to /success"

# Bad
"Submit form" (no validation)
```

### 5. Screenshot for Evidence
```bash
# Good (Principle VII: Observability)
"Test the form and take before/after screenshots"

# Acceptable
"Test the form"
```

---

## Governance Integration

### Pre-Commit Visual Validation

```bash
# Before committing UI changes
/governance-preflight

# Then test visually
"Navigate to http://localhost:3000 and take screenshots of:
1. Home page
2. Dashboard
3. Settings page

Compare with baseline screenshots to verify no regressions."
```

### Feature Flag Verification

```bash
# Validate progressive enhancement (Principle V)
"Check localStorage for feature flags on https://staging.myapp.com
Verify 'newFeature' flag is false in production"
```

### Contract Compliance Check

```bash
# Validate API contracts (Principle III)
"Navigate to https://app.com/dashboard
Inspect all API calls and verify they match contracts/api-spec.yaml"
```

---

## Related Documentation

- **Browser MCP Setup**: `.docs/governance/browser-mcp-setup.md`
- **Test-First Development**: `.logic-loom/memory/constitution.md` (Principle II)
- **Observability**: `.logic-loom/memory/constitution.md` (Principle VII)
- **Contract-First**: `.logic-loom/memory/constitution.md` (Principle III)

---

## Troubleshooting

### Screenshots are blank
**Cause**: Page not fully loaded
**Fix**: Add explicit wait: "Wait 3 seconds after navigation before screenshot"

### Form fields not filling
**Cause**: Element selector incorrect
**Fix**: Use specific selectors: "Fill the input field with id='email'"

### Console logs empty
**Cause**: Logs cleared before retrieval
**Fix**: Get logs immediately after operation

### Network tab missing requests
**Cause**: DevTools attached after page load
**Fix**: Navigate with DevTools already attached

---

## Version History

**v1.0.0** (2025-12-19)
- 10 practical examples
- Error handling patterns
- Best practices
- Governance integration examples

---

*This guide is part of Feature 003: Governance Browser Enhancement*
