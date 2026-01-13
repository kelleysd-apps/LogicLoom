---
name: devops-operations
version: 3.0.0
description: |
  Domain skill for DevOps operations including deployment, CI/CD pipelines, Docker,
  infrastructure management, and monitoring setup. Routes to operations-specialist
  agent for execution. Part of the skills-first architecture (FR-611).
category: domain
triggers:
  - "deploy"
  - "CI/CD"
  - "Docker"
  - "pipeline"
  - "infrastructure"
  - "DevOps"
  - "Kubernetes"
  - "container"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
agent-invocations:
  - agent: operations-specialist
    context-subset:
      - deployment-target
      - infrastructure-config
      - pipeline-requirements
      - monitoring-needs
    when: "deployment or infrastructure work is needed"
    timeout: 15m
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

# DevOps Operations Skill

## Overview

This skill handles all DevOps operations including deployment, CI/CD pipeline
configuration, Docker containerization, infrastructure management, and monitoring
setup. Routes to `operations-specialist` agent.

## When to Use

Activate this skill when the user request involves:
- Deployment configuration
- CI/CD pipeline setup
- Docker/containerization
- Infrastructure as code
- Kubernetes configuration
- Monitoring and alerting
- Environment management

## Instructions

### Step 1: Analyze DevOps Requirements

Identify the specific DevOps work needed:

1. **Deployment**: Production, staging, development
2. **CI/CD**: GitHub Actions, GitLab CI, Jenkins
3. **Containers**: Docker, docker-compose, K8s
4. **Infrastructure**: Terraform, AWS, GCP, Azure
5. **Monitoring**: Prometheus, Grafana, alerts

### Step 2: Prepare Context for Agent

Gather minimal required context:

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

Check agent output for:
- [ ] Idempotent deployments
- [ ] Secrets not in code
- [ ] Health checks configured
- [ ] Rollback strategy defined
- [ ] Tests run in pipeline

## Context Requirements

| Field | Required | Description |
|-------|----------|-------------|
| deployment-target | Yes | Where to deploy |
| infrastructure-config | Yes | Infra details |
| pipeline-requirements | No | CI/CD needs |
| monitoring-needs | No | Observability |

## Agent Invocation

```yaml
agent: operations-specialist
purpose: Manage runtime infrastructure and performance optimization
department: operations
merged-from:
  - devops-engineer
  - performance-engineer
skill-portfolio:
  - domain/devops-operations
  - domain/performance-operations
  - domain/monitoring
```

## Deployment Checklist

### Pre-Deployment
- [ ] Tests passing
- [ ] Linting passing
- [ ] Security scan passed
- [ ] Environment variables set
- [ ] Database migrations ready

### Deployment
- [ ] Health checks configured
- [ ] Rollback plan ready
- [ ] Monitoring active
- [ ] Alerts configured
- [ ] Backup created

### Post-Deployment
- [ ] Smoke tests pass
- [ ] Metrics normal
- [ ] No error spikes
- [ ] Performance acceptable

## Common Configurations

### Docker
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

### GitHub Actions
```yaml
name: Deploy
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test
      - run: npm run build
      - run: npm run deploy
```

### docker-compose
```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=${DATABASE_URL}
```

## Quality Checks

Before completing:
- [ ] Deployment is idempotent (Principle IV)
- [ ] No secrets in config files
- [ ] Health checks configured
- [ ] Monitoring in place
- [ ] Rollback tested

## Related Skills

- **domain/performance-operations**: For scaling
- **sdd-workflow/sdd-debug**: For deployment issues
- **domain/security-operations**: For security review

## Constitutional Compliance

- **Principle IV (Idempotent Operations)**: Deployments repeatable
- **Principle VI (Git Approval)**: User approves deployments
- **Principle VII (Observability)**: Monitoring required
- **Principle X (Delegation)**: Routes to operations-specialist
