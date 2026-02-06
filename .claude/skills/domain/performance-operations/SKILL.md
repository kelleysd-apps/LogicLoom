---
# ⚠️ DEPRECATED — MIGRATED TO PLUGIN
# This skill has been migrated to: plugins/sdd-domain-performance/skills/performance-operations/
# Use the plugin version instead. This file will be removed in v5.0.
# Migration date: 2026-01-15
---

---
name: performance-operations
version: 3.0.0
category: domain
description: Performance optimization and caching. Routes to operations-specialist.
triggers: ["performance", "optimize", "cache", "benchmark", "latency", "profiling"]
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
---

# Performance Operations Skill

## Overview

This skill handles all performance operations including optimization, caching
strategies, benchmarking, profiling, and latency reduction. Routes to
`operations-specialist` agent.

## When to Use

Activate this skill when the user request involves:
- Performance optimization
- Caching implementation
- Benchmark setup
- Latency reduction
- Query optimization
- Load testing
- Profiling

## Configuration

### Allowed Tools

- Read, Write, Edit, Bash, Grep, Glob

### Agent Invocations

**operations-specialist**:
- Context: performance-requirements, bottleneck-analysis, caching-needs, benchmark-targets
- When: Performance optimization work is needed
- Timeout: 10m

### Composes

- validation/message-preflight (pre-execution)
- validation/domain-detection (analysis)

## Instructions

### Step 1: Analyze Performance Requirements

Identify the specific performance work needed:

1. **Profiling**: Identify bottlenecks
2. **Optimization**: Code/query improvements
3. **Caching**: Redis, CDN, browser cache
4. **Benchmarking**: Performance baselines
5. **Load Testing**: Stress testing

### Step 2: Prepare Context for Agent

Gather minimal required context:

```yaml
context-subset:
  - performance-requirements: Target metrics
  - bottleneck-analysis: Known slow points
  - caching-needs: What to cache
  - benchmark-targets: Performance goals
```

### Step 3: Invoke Operations Specialist

Delegate to `operations-specialist` with:
- Clear performance targets
- Bottleneck analysis results
- Caching requirements
- Benchmark baseline data

### Step 4: Validate Output

Check agent output for:
- [ ] Measurable improvements defined
- [ ] Cache invalidation strategy
- [ ] No premature optimization
- [ ] Benchmarks reproducible
- [ ] Performance tests added

## Context Requirements

| Field | Required | Description |
|-------|----------|-------------|
| performance-requirements | Yes | Target metrics |
| bottleneck-analysis | No | Known issues |
| caching-needs | No | Cache requirements |
| benchmark-targets | Yes | Performance goals |

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

## Performance Targets

| Metric | Good | Better | Best |
|--------|------|--------|------|
| Page Load | <3s | <2s | <1s |
| API Response | <500ms | <200ms | <100ms |
| Database Query | <100ms | <50ms | <10ms |
| Memory Usage | <80% | <60% | <40% |

## Optimization Checklist

### Database
- [ ] Indexes on frequently queried columns
- [ ] Query EXPLAIN analyzed
- [ ] N+1 queries eliminated
- [ ] Connection pooling

### Caching
- [ ] Cache headers set
- [ ] CDN for static assets
- [ ] Redis for session/frequent data
- [ ] Cache invalidation strategy

### Code
- [ ] Lazy loading implemented
- [ ] Bundle size optimized
- [ ] Tree shaking enabled
- [ ] Critical CSS inlined

## Quality Checks

Before completing:
- [ ] Baseline measurements taken
- [ ] Improvements measurable
- [ ] Cache invalidation works
- [ ] No memory leaks introduced
- [ ] Performance tests added



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
  "skill": "performance-operations",
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

- **domain/database-operations**: For query optimization
- **domain/devops-operations**: For infrastructure scaling
- **domain/backend-operations**: For API optimization

## Constitutional Compliance

- **Principle V (Progressive Enhancement)**: Start simple, optimize when needed
- **Principle X (Delegation)**: Routes to operations-specialist
- **Principle VII (Observability)**: Performance metrics logged
