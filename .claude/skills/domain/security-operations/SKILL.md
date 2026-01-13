---
name: security-operations
version: 3.0.0
description: |
  Domain skill for security operations including security review, vulnerability assessment,
  encryption, secrets management, and authentication security. Routes to quality-specialist
  agent for execution. Critical for application security.
category: domain
triggers:
  - "security"
  - "encryption"
  - "XSS"
  - "secrets"
  - "vulnerability"
  - "auth security"
  - "OWASP"
  - "SQL injection"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
agent-invocations:
  - agent: quality-specialist
    context-subset:
      - security-requirements
      - threat-model
      - sensitive-data
      - auth-config
    when: "security review or hardening work is needed"
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

# Security Operations Skill

## Overview

This skill handles all security operations including security review, vulnerability
assessment, encryption implementation, secrets management, and authentication
security hardening. Routes to `quality-specialist` agent.

## When to Use

Activate this skill when the user request involves:
- Security code review
- Vulnerability assessment
- Encryption implementation
- Secrets management
- Authentication hardening
- OWASP compliance
- Input sanitization

## Instructions

### Step 1: Analyze Security Requirements

Identify the specific security work needed:

1. **Security Review**: Code audit for vulnerabilities
2. **Vulnerability Assessment**: OWASP Top 10 check
3. **Encryption**: Data encryption at rest/transit
4. **Secrets**: Environment variables, key management
5. **Authentication**: JWT, OAuth, session security

### Step 2: Prepare Context for Agent

Gather minimal required context:

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

Check agent output for:
- [ ] OWASP Top 10 addressed
- [ ] No secrets in code
- [ ] Input validation present
- [ ] Output encoding applied
- [ ] Auth tokens properly handled

## Context Requirements

| Field | Required | Description |
|-------|----------|-------------|
| security-requirements | Yes | What to secure |
| threat-model | No | Attack vectors |
| sensitive-data | Yes | Protected data |
| auth-config | No | Auth setup |

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

## Security Checklist (OWASP Top 10)

### A01: Broken Access Control
- [ ] Principle of least privilege
- [ ] Deny by default
- [ ] Rate limiting implemented

### A02: Cryptographic Failures
- [ ] Data encrypted in transit (HTTPS)
- [ ] Sensitive data encrypted at rest
- [ ] Strong algorithms used

### A03: Injection
- [ ] Parameterized queries
- [ ] Input validation
- [ ] Output encoding

### A04: Insecure Design
- [ ] Threat modeling done
- [ ] Secure design patterns used

### A05: Security Misconfiguration
- [ ] Default credentials changed
- [ ] Unnecessary features disabled
- [ ] Error handling doesn't leak info

### A06: Vulnerable Components
- [ ] Dependencies up to date
- [ ] Known vulnerabilities addressed

### A07: Auth Failures
- [ ] Strong password policy
- [ ] MFA available
- [ ] Session management secure

### A08: Data Integrity
- [ ] Signatures verified
- [ ] Updates validated

### A09: Logging Failures
- [ ] Security events logged
- [ ] Logs protected

### A10: SSRF
- [ ] URL validation
- [ ] Allowlists used

## Quality Checks

Before completing:
- [ ] No secrets in code (.env used)
- [ ] Input validation on all endpoints
- [ ] SQL injection prevented
- [ ] XSS mitigated
- [ ] CSRF tokens implemented
- [ ] Security headers set

## Related Skills

- **domain/backend-operations**: For secure API implementation
- **domain/database-operations**: For RLS policies
- **domain/testing-operations**: For security testing

## Constitutional Compliance

- **Principle XI (Input Validation)**: All inputs validated
- **Principle XIII (Access Control)**: Proper authorization
- **Principle X (Delegation)**: Routes to quality-specialist
