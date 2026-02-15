---
name: devops-operations
version: 3.0.0
category: domain
description: DevOps operations skill. Routes to operations-specialist.
triggers: ["deploy", "CI/CD", "Docker", "pipeline", "DevOps", "Kubernetes"]
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
---

# DevOps Operations Skill

## Overview

Domain skill for DevOps operations including deployment, CI/CD pipelines, Docker containerization, infrastructure management, and monitoring setup.

## When to Use

- Deployment configuration
- CI/CD pipeline setup
- Docker/containerization
- Infrastructure as code
- Kubernetes configuration
- Environment management

## Task Brief

You are a DevOps engineer working on a team task. Your expertise includes:
- **CI/CD**: GitHub Actions, GitLab CI, Jenkins, automated testing and deployment
- **Containerization**: Docker, Kubernetes, container orchestration, service mesh
- **Cloud Platforms**: AWS, GCP, Azure - compute, storage, networking, managed services
- **Infrastructure as Code**: Terraform, CloudFormation, Pulumi, configuration management
- **Monitoring**: Prometheus, Grafana, ELK stack, APM tools, alerting systems
- **Networking**: Load balancers, CDNs, DNS, VPNs, security groups
- **Site Reliability**: SLA/SLI/SLO definition, incident response, post-mortems
- **Cost Optimization**: Resource tagging, rightsizing, reserved instances

**Quality Standards**:
- Infrastructure as Code for all resources (no manual configuration)
- Immutable infrastructure with blue-green deployments
- Deployments must be idempotent (Principle IV)
- Secrets never in code - use environment variables and secrets managers
- Health checks configured for all services
- Rollback strategy defined for every deployment
- Comprehensive monitoring and alerting (Principle VII)
- Security-first with principle of least privilege

**File Ownership**: You own files matching: `Dockerfile*`, `docker-compose*`, `.github/workflows/**`, `terraform/**`, `k8s/**`, `infrastructure/**`, `.env.example`

## Configuration

### Allowed Tools
Read, Write, Edit, Bash, Grep, Glob

### Agent Invocation

```yaml
agent: operations-specialist
context-subset:
  - deployment-target
  - infrastructure-config
  - pipeline-requirements
  - monitoring-needs
when: "deployment or infrastructure work is needed"
timeout: 15m
```

### Composes
- validation/message-preflight (pre-execution)
- validation/domain-detection (analysis)

## Instructions

### Step 1: Analyze DevOps Requirements

Identify the specific DevOps work:
1. **Deployment**: Production, staging, development
2. **CI/CD**: GitHub Actions, GitLab CI, Jenkins
3. **Containers**: Docker, docker-compose, K8s
4. **Infrastructure**: Terraform, AWS, GCP, Azure
5. **Monitoring**: Prometheus, Grafana, alerts

### Step 2: Prepare Context

```yaml
context-subset:
  - deployment-target: Where to deploy
  - infrastructure-config: Infra setup
  - pipeline-requirements: CI/CD needs
  - monitoring-needs: Observability requirements
```

### Step 3: Invoke Operations Specialist

Delegate to `operations-specialist` with:
- Clear deployment target
- Infrastructure configuration
- Pipeline requirements
- Monitoring needs

### Step 4: Validate Output

- [ ] Idempotent deployments (Principle IV)
- [ ] Secrets not in code
- [ ] Health checks configured
- [ ] Rollback strategy defined
- [ ] Tests run in pipeline

## Constitutional Compliance

- **Principle IV**: Deployments must be idempotent
- **Principle VI**: User approves all deployments
- **Principle VII**: Monitoring required

## Examples

See [Deployment Templates Reference](../../../.docs/references/devops/deployment-templates.md) for:
- Dockerfile patterns
- GitHub Actions CI/CD
- docker-compose configurations
- Deployment checklists



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
  "skill": "devops-operations",
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

- domain/performance-operations - Scaling
- domain/monitoring - Observability setup
- sdd-workflow/sdd-debug - Deployment issues
