---
name: security-operations
version: 3.0.0
category: domain
description: Security operations skill. Routes to quality-specialist.
triggers: ["security", "encryption", "vulnerability", "secrets", "auth security", "OWASP"]
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
---

# Security Operations Skill

## Overview

Domain skill for security operations including security review, vulnerability assessment, encryption, secrets management, and authentication security hardening.

## When to Use

- Security code review
- Vulnerability assessment
- Encryption implementation
- Secrets management
- Authentication hardening
- OWASP compliance review

## Configuration

### Allowed Tools
Read, Write, Edit, Bash, Grep, Glob

### Agent Invocation

```yaml
agent: quality-specialist
context-subset:
  - security-requirements
  - threat-model
  - sensitive-data
  - auth-config
when: "security review or hardening work is needed"
timeout: 10m
```

### Composes
- validation/message-preflight (pre-execution)
- validation/domain-detection (analysis)

## Instructions

### Step 1: Analyze Security Requirements

Identify the specific security work:
1. **Security Review**: Code audit for vulnerabilities
2. **Vulnerability Assessment**: OWASP Top 10 check
3. **Encryption**: Data encryption at rest/transit
4. **Secrets**: Environment variables, key management
5. **Authentication**: JWT, OAuth, session security

### Step 2: Prepare Context

```yaml
context-subset:
  - security-requirements: What needs securing
  - threat-model: Potential attack vectors
  - sensitive-data: Data that needs protection
  - auth-config: Authentication configuration
```

### Step 3: Invoke Quality Specialist

Delegate to `quality-specialist` with:
- Clear security requirements
- Threat model context
- Sensitive data locations
- Current auth configuration

### Step 4: Validate Output

- [ ] OWASP Top 10 addressed
- [ ] No secrets in code
- [ ] Input validation present
- [ ] Output encoding applied
- [ ] Auth tokens properly handled

## Constitutional Compliance

- **Principle XI**: All inputs validated
- **Principle XIII**: Proper authorization
- **Principle X**: Routes to quality-specialist

## Security Checklist

See [OWASP Checklist Reference](../../../.docs/references/security/owasp-checklist.md) for complete OWASP Top 10 checklist.

### Quick Checks
- [ ] No secrets in code (.env used)
- [ ] Input validation on all endpoints
- [ ] SQL injection prevented
- [ ] XSS mitigated
- [ ] CSRF tokens implemented

## Related Skills

- domain/backend-operations - Secure API implementation
- domain/database-operations - RLS policies
- domain/testing-operations - Security testing
