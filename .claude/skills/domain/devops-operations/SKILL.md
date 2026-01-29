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

## Related Skills

- domain/performance-operations - Scaling
- domain/monitoring - Observability setup
- sdd-workflow/sdd-debug - Deployment issues
