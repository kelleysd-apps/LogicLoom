---
# ⚠️ DEPRECATED — MIGRATED TO PLUGIN
# This skill has been migrated to: plugins/sdd-domain-security/skills/security-operations/
# Use the plugin version instead. This file will be removed in v5.0.
# Migration date: 2026-01-15
---

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
  "skill": "security-operations",
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

- domain/backend-operations - Secure API implementation
- domain/database-operations - RLS policies
- domain/testing-operations - Security testing
