# Security Policy

**Version**: 1.0.0
**Effective Date**: TBD
**Authority**: Constitution v3.1.0 - Principle XI (Input Validation & Output Sanitization)
**Review Cycle**: Quarterly

---

## Purpose

This policy establishes security standards and practices for the LogicLoom framework, ensuring all applications built with this framework follow security-by-default principles.

---

## Constitutional Mandate

**Principle XI: Input Validation and Output Sanitization**

Security is not optional. All inputs must be validated and sanitized. All outputs must be properly escaped.

### Requirements
- ✅ All user inputs validated against expected schemas
- ✅ All external data sanitized before use
- ✅ All outputs escaped for their context (HTML, SQL, shell, etc.)
- ✅ Secrets NEVER logged or committed
- ✅ Authentication and authorization enforced at every boundary
- ✅ Dependencies regularly audited for vulnerabilities

---

## Security Principles

### Defense in Depth

Never rely on a single security control:
- Multiple layers of security
- Fail securely (deny by default)
- Least privilege access
- Separation of duties

### Security by Default

Security must be the default:
- Secure configurations out of the box
- Opt-in for less secure options
- Clear warnings for security implications
- Automatic security updates

### Zero Trust

Never trust, always verify:
- Verify every request
- Authenticate every user
- Authorize every action
- Validate every input

---

## OWASP Top 10 Mitigations

### 1. Broken Access Control

**Threat**: Users access unauthorized resources

**Mitigations**:
- ✅ Enforce authorization on every endpoint
- ✅ Deny by default, allow by exception
- ✅ Use role-based access control (RBAC)
- ✅ Implement row-level security (RLS) in database
- ✅ Test authorization with different roles

**Example**:
```typescript
// ✅ GOOD: Check authorization
app.get('/api/users/:id', authenticate, (req, res) => {
  if (req.user.id !== parseInt(req.params.id) && !req.user.isAdmin) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  // ... proceed
});

// ❌ BAD: No authorization check
app.get('/api/users/:id', authenticate, (req, res) => {
  // Anyone authenticated can access any user
});
```

### 2. Cryptographic Failures

**Threat**: Sensitive data exposed due to weak crypto

**Mitigations**:
- ✅ Use strong algorithms (AES-256, bcrypt, Argon2)
- ✅ Never roll your own crypto
- ✅ Encrypt data at rest and in transit
- ✅ Use TLS 1.3 minimum
- ✅ Rotate keys regularly

**Example**:
```typescript
// ✅ GOOD: bcrypt for passwords
import bcrypt from 'bcrypt';
const hash = await bcrypt.hash(password, 12);

// ❌ BAD: Plain MD5
import md5 from 'md5';
const hash = md5(password); // ❌ Weak, not salted
```

### 3. Injection

**Threat**: SQL, NoSQL, Command, LDAP injection

**Mitigations**:
- ✅ Use parameterized queries
- ✅ Use ORM/query builders
- ✅ Validate and sanitize ALL inputs
- ✅ Use allow-lists, not deny-lists
- ✅ Escape special characters

**Example**:
```typescript
// ✅ GOOD: Parameterized query
const users = await db.query(
  'SELECT * FROM users WHERE email = $1',
  [email]
);

// ❌ BAD: String concatenation
const users = await db.query(
  `SELECT * FROM users WHERE email = '${email}'`
);
```

### 4. Insecure Design

**Threat**: Missing security requirements

**Mitigations**:
- ✅ Threat model during design
- ✅ Define security requirements in specs
- ✅ Security review before implementation
- ✅ Use secure design patterns
- ✅ Document security decisions in ADRs

### 5. Security Misconfiguration

**Threat**: Default credentials, verbose errors, unnecessary features

**Mitigations**:
- ✅ Disable default accounts
- ✅ Remove unnecessary features/endpoints
- ✅ Use security headers
- ✅ Hide error details in production
- ✅ Keep dependencies updated

**Example**:
```typescript
// ✅ GOOD: Security headers
app.use(helmet({
  contentSecurityPolicy: true,
  hsts: true,
  noSniff: true,
  xssFilter: true
}));

// ✅ GOOD: Hide errors in production
app.use((err, req, res, next) => {
  if (process.env.NODE_ENV === 'production') {
    res.status(500).json({ error: 'Internal server error' });
  } else {
    res.status(500).json({ error: err.message, stack: err.stack });
  }
});
```

### 6. Vulnerable and Outdated Components

**Threat**: Using libraries with known vulnerabilities

**Mitigations**:
- ✅ Regular dependency audits (`npm audit`)
- ✅ Automated dependency updates (Dependabot)
- ✅ Pin dependency versions
- ✅ Monitor security advisories
- ✅ Remove unused dependencies

**Commands**:
```bash
# Audit dependencies
npm audit

# Fix automatically
npm audit fix

# Update with care
npm update
```

### 7. Identification and Authentication Failures

**Threat**: Weak authentication, session hijacking

**Mitigations**:
- ✅ Implement multi-factor authentication (MFA)
- ✅ Strong password requirements
- ✅ Secure session management
- ✅ Rate limit login attempts
- ✅ No default credentials

**Example**:
```typescript
// ✅ GOOD: Rate limiting
import rateLimit from 'express-rate-limit';

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts
  message: 'Too many login attempts'
});

app.post('/api/login', loginLimiter, loginHandler);
```

### 8. Software and Data Integrity Failures

**Threat**: Unsigned updates, insecure CI/CD

**Mitigations**:
- ✅ Code signing
- ✅ Verify package integrity (checksums)
- ✅ Secure CI/CD pipelines
- ✅ Immutable artifacts
- ✅ Audit logs for all changes

### 9. Security Logging and Monitoring Failures

**Threat**: Attacks go undetected

**Mitigations**:
- ✅ Log all authentication events
- ✅ Log authorization failures
- ✅ Log input validation failures
- ✅ Monitor for anomalies
- ✅ Set up alerts for suspicious activity

**Example**:
```typescript
// ✅ GOOD: Security logging
logger.warn('Failed login attempt', {
  email,
  ip: req.ip,
  userAgent: req.get('user-agent'),
  timestamp: new Date()
});

// Set up alerts
if (failedAttempts > 10) {
  alertSecurityTeam('Possible brute force attack', { email, ip });
}
```

### 10. Server-Side Request Forgery (SSRF)

**Threat**: Attacker tricks server into making requests

**Mitigations**:
- ✅ Validate and sanitize URLs
- ✅ Use allow-lists for allowed hosts
- ✅ Disable redirects
- ✅ Use network segmentation
- ✅ Don't return raw responses

**Example**:
```typescript
// ✅ GOOD: Validate URL
const allowedHosts = ['api.example.com'];

function isAllowedURL(url: string): boolean {
  try {
    const parsed = new URL(url);
    return allowedHosts.includes(parsed.hostname);
  } catch {
    return false;
  }
}

// ❌ BAD: No validation
fetch(userProvidedURL); // ❌ SSRF vulnerability
```

---

## Input Validation

### Validation Requirements

**ALL inputs must be validated**:
- User form data
- URL parameters
- Query strings
- HTTP headers
- File uploads
- API requests

### Validation Strategy

1. **Type checking**: Ensure correct data type
2. **Format validation**: Email, phone, date formats
3. **Range validation**: Min/max length, value ranges
4. **Allow-list**: Only allow known-good values
5. **Schema validation**: Use JSON Schema, Zod, Yup

### Validation Example

```typescript
import { z } from 'zod';

// Define schema
const UserSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(100),
  age: z.number().int().min(13).max(120)
});

// Validate input
function createUser(input: unknown) {
  try {
    const validated = UserSchema.parse(input);
    // Safe to use validated data
  } catch (error) {
    // Validation failed
    throw new ValidationError('Invalid input', error);
  }
}
```

---

## Output Sanitization

### Context-Aware Escaping

**HTML Context**:
```typescript
import escape from 'escape-html';
const safe = escape(userInput);
```

**SQL Context**:
```typescript
// Use parameterized queries
db.query('SELECT * FROM users WHERE id = $1', [userId]);
```

**JavaScript Context**:
```typescript
// Use JSON.stringify
const safe = JSON.stringify(userInput);
```

**Shell Context**:
```typescript
import { execFile } from 'child_process';
// Use execFile with array, not string concatenation
execFile('ls', [userInput]);
```

---

## Secrets Management

### Requirements

- ✅ Never hardcode secrets
- ✅ Use environment variables
- ✅ Use secret managers (AWS Secrets Manager, HashiCorp Vault)
- ✅ Rotate secrets regularly
- ✅ Different secrets per environment

### Secret Storage

```typescript
// ✅ GOOD: Environment variables
const apiKey = process.env.API_KEY;

// ❌ BAD: Hardcoded
const apiKey = 'sk_live_12345'; // ❌ NEVER DO THIS
```

### Git Pre-commit Hook

Prevent committing secrets:
```bash
#!/bin/sh
# .git/hooks/pre-commit

if git diff --cached | grep -E '(API_KEY|SECRET|PASSWORD|TOKEN).*=.*["\']'; then
  echo "❌ Potential secret detected in commit"
  exit 1
fi
```

### Scanning Tools

Use secret scanning:
- git-secrets
- truffleHog
- GitHub secret scanning

---

## Authentication & Authorization

### Authentication Best Practices

1. **Use proven libraries**: Passport.js, Auth0, NextAuth
2. **Strong passwords**: Min 8 chars, complexity requirements
3. **MFA**: Require for sensitive operations
4. **Session management**: Secure cookies, expiration
5. **Password reset**: Secure reset flows with tokens

### Authorization Patterns

**Role-Based Access Control (RBAC)**:
```typescript
enum Role {
  Admin = 'admin',
  User = 'user',
  Guest = 'guest'
}

function requireRole(role: Role) {
  return (req, res, next) => {
    if (req.user.role !== role) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    next();
  };
}

app.get('/admin', requireRole(Role.Admin), adminHandler);
```

**Row-Level Security (RLS)**:
```sql
-- PostgreSQL RLS
CREATE POLICY user_isolation ON documents
  FOR SELECT
  USING (user_id = current_user_id());
```

---

## Security Headers

### Required Headers

```typescript
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", 'data:', 'https:']
    }
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  },
  frameguard: {
    action: 'deny'
  },
  noSniff: true,
  xssFilter: true
}));
```

---

## Dependency Security

### Regular Audits

**Schedule**:
- Weekly: Automated audits in CI
- Monthly: Manual review of audit results
- Quarterly: Major dependency updates

**Process**:
1. Run `npm audit`
2. Review vulnerabilities
3. Update dependencies
4. Test thoroughly
5. Deploy updates

### Dependency Policies

- ✅ Pin exact versions in package.json
- ✅ Use lock files (package-lock.json, yarn.lock)
- ✅ Review dependency licenses
- ✅ Minimize dependencies
- ✅ Remove unused dependencies

---

## Secure Development Lifecycle

### Design Phase
- Threat modeling
- Security requirements in specs
- Privacy impact assessment

### Development Phase
- Secure coding practices
- Code review with security focus
- SAST (Static Application Security Testing)

### Testing Phase
- Security unit tests
- DAST (Dynamic Application Security Testing)
- Penetration testing

### Deployment Phase
- Security scan before deploy
- Secrets management
- Security monitoring

### Maintenance Phase
- Patch management
- Incident response
- Security updates

---

## Incident Response

### Incident Classification

**P0 - Critical**: Active exploit, data breach
**P1 - High**: Vulnerability disclosed, no active exploit
**P2 - Medium**: Security issue, low risk
**P3 - Low**: Security improvement

### Response Procedure

1. **Detect**: Identify security incident
2. **Contain**: Isolate affected systems
3. **Investigate**: Determine scope and impact
4. **Remediate**: Fix vulnerability
5. **Recover**: Restore normal operations
6. **Learn**: Post-mortem and improvements

### Notification Requirements

**Internal**:
- Security team immediately
- Management within 1 hour
- Development team within 4 hours

**External**:
- Affected users within 72 hours (GDPR)
- Regulatory bodies as required
- Security researchers (if disclosed)

---

## Security Training

### Required Training

All team members must complete:
- OWASP Top 10 training (annually)
- Secure coding practices (annually)
- Social engineering awareness (quarterly)
- Incident response procedures (semi-annually)

---

## Security Metrics

### Track These Metrics

- Vulnerability count by severity
- Time to patch critical vulns
- Security test coverage
- Dependency audit score
- Failed authentication attempts
- Authorization failures

### Targets

- Zero critical vulnerabilities in production
- Patch critical vulns within 24 hours
- Security test coverage ≥ 90%
- Clean dependency audit (no high/critical)

---

## Compliance

### Relevant Standards

- OWASP Top 10
- NIST Cybersecurity Framework
- CWE Top 25
- GDPR (if applicable)
- SOC 2 (if applicable)

---

## References

- Constitution v3.1.0: `.logic-loom/memory/constitution.md`
- Testing Policy: `.docs/policies/testing-policy.md`
- Code Review Policy: `.docs/policies/code-review-policy.md`
- OWASP: https://owasp.org/
- CWE: https://cwe.mitre.org/

---

**Policy Owner**: Quality Department (security-operations skill)
**Last Reviewed**: TBD
**Next Review**: TBD
