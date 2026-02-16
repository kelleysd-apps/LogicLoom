---
name: monitoring
version: 3.0.0
category: domain
description: Monitoring and observability operations providing direct domain expertise.
triggers: ["monitoring", "observability", "metrics", "logging", "health check", "alerting"]
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
---

# Monitoring Operations Skill

## Overview

Domain skill for monitoring and observability including health checks, metrics collection, logging configuration, and alerting setup. Essential for Principle VII (Observability) compliance.

## Task Brief

You are a monitoring and observability specialist working on a team task. Your expertise includes:
- **Health Checks**: Liveness probes, readiness probes, dependency health, deep health checks
- **Metrics Collection**: Prometheus, StatsD, CloudWatch, custom business metrics, SLI/SLO tracking
- **Structured Logging**: JSON log formats, correlation IDs, log levels, log aggregation (ELK, Loki)
- **Alerting**: Alert rules, notification channels (PagerDuty, Slack, email), escalation policies
- **Dashboards**: Grafana, CloudWatch dashboards, RED method (Rate, Errors, Duration)
- **Distributed Tracing**: OpenTelemetry, Jaeger, trace context propagation
- **Incident Response**: Runbook integration, automated remediation, post-mortem data collection

**Quality Standards**:
- All services must expose /health and /metrics endpoints (Principle VII - Observability)
- Structured logging with correlation IDs for request tracing
- Alerts must have clear descriptions, severity levels, and runbook links
- Dashboards must show the four golden signals (latency, traffic, errors, saturation)
- Monitoring configuration as code - no manual dashboard creation
- Alert fatigue prevention: actionable alerts only, proper thresholds
- Test-First Development (Principle II): health check and metrics tests required

**File Ownership**: You own files matching: `monitoring/**`, `prometheus/**`, `grafana/**`, `alerting/**`, `src/**/health.*`, `src/**/metrics.*`

## When to Use

- Monitoring infrastructure setup
- Health check implementation
- Logging configuration
- Alert rule creation
- Metrics dashboard setup
- Observability improvements

## Configuration

### Allowed Tools
Read, Write, Edit, Bash, Grep, Glob

### Skill Context

```yaml
context-subset:
  - monitoring-scope
  - infrastructure
  - alerting-requirements
  - metrics-config
when: "monitoring or observability work is needed"
timeout: 15m
```

### Composes
- validation/message-preflight (pre-execution)
- domain/devops-operations (integration)

## Instructions

### Step 1: Analyze Monitoring Requirements

Identify the specific monitoring work:
1. **Health Checks**: Liveness and readiness probes
2. **Metrics**: Performance and business metrics
3. **Logging**: Structured logging setup
4. **Alerting**: Alert rules and notifications
5. **Dashboards**: Visualization setup

### Step 2: Prepare Context

```yaml
context-subset:
  - monitoring-scope: What to monitor
  - infrastructure: Cloud provider, tools (Prometheus, Grafana)
  - alerting-requirements: Notification channels
  - metrics-config: Metrics to collect
```

### Step 3: Execute Monitoring Setup

Implement monitoring setup with:
- Clear monitoring scope
- Infrastructure details
- Alerting requirements
- Metrics configuration

### Step 4: Validate Output

- [ ] Health checks respond correctly
- [ ] Metrics being collected
- [ ] Logs in correct format
- [ ] Alerts configured and tested
- [ ] Dashboards accessible

## Constitutional Compliance - Principle VII

**Observability is Required**

From Constitution:
> All operations must have structured logging and metrics
> Monitoring enables system understanding and debugging

## Monitoring Patterns

### Health Check Endpoint
```typescript
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString()
  });
});
```

### Structured Logging
```typescript
logger.info('Request processed', {
  method: req.method,
  path: req.path,
  duration_ms: duration,
  status: res.statusCode
});
```

### Prometheus Metrics
```typescript
const requestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests',
  labelNames: ['method', 'path', 'status']
});
```

## Quality Checks

Before completing:
- [ ] Health endpoint returns 200
- [ ] Metrics exposed at /metrics
- [ ] Logs include correlation IDs
- [ ] Alerts have clear descriptions
- [ ] Dashboard shows key metrics



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
  "skill": "monitoring",
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

- domain/devops-operations - Infrastructure setup
- domain/performance-operations - Performance tuning
- sdd-workflow/sdd-debug - Debugging with observability
