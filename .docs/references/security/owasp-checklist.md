# OWASP Top 10 Security Checklist

Reference checklist for security-operations skill.

## A01: Broken Access Control
- [ ] Principle of least privilege enforced
- [ ] Deny by default
- [ ] Rate limiting implemented
- [ ] CORS properly configured
- [ ] Directory listing disabled

## A02: Cryptographic Failures
- [ ] Data encrypted in transit (HTTPS/TLS 1.3)
- [ ] Sensitive data encrypted at rest
- [ ] Strong algorithms used (AES-256, bcrypt)
- [ ] No deprecated crypto (MD5, SHA1)
- [ ] Keys rotated regularly

## A03: Injection
- [ ] Parameterized queries used
- [ ] Input validation on all endpoints
- [ ] Output encoding applied
- [ ] ORM used where possible
- [ ] Command injection prevented

## A04: Insecure Design
- [ ] Threat modeling completed
- [ ] Secure design patterns used
- [ ] Defense in depth applied
- [ ] Fail securely

## A05: Security Misconfiguration
- [ ] Default credentials changed
- [ ] Unnecessary features disabled
- [ ] Error handling doesn't leak info
- [ ] Security headers set (CSP, HSTS, X-Frame)
- [ ] Debug mode disabled in production

## A06: Vulnerable Components
- [ ] Dependencies up to date
- [ ] Known vulnerabilities addressed
- [ ] npm audit / snyk used
- [ ] Unused dependencies removed

## A07: Authentication Failures
- [ ] Strong password policy
- [ ] MFA available/required
- [ ] Session management secure
- [ ] Account lockout after failures
- [ ] Passwords properly hashed

## A08: Data Integrity Failures
- [ ] Signatures verified
- [ ] Updates validated
- [ ] Deserialization secured
- [ ] CI/CD pipeline secured

## A09: Logging Failures
- [ ] Security events logged
- [ ] Logs protected from tampering
- [ ] No sensitive data in logs
- [ ] Alerting configured

## A10: Server-Side Request Forgery (SSRF)
- [ ] URL validation implemented
- [ ] Allowlists used for external calls
- [ ] Internal network access blocked
- [ ] Response handling secured

## Quick Security Checks

```bash
# Check for secrets in code
grep -r "password\|secret\|api_key" --include="*.js" .

# Check npm vulnerabilities
npm audit

# Check for outdated packages
npm outdated
```
