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

## Related Skills

- **domain/database-operations**: For query optimization
- **domain/devops-operations**: For infrastructure scaling
- **domain/backend-operations**: For API optimization

## Constitutional Compliance

- **Principle V (Progressive Enhancement)**: Start simple, optimize when needed
- **Principle X (Delegation)**: Routes to operations-specialist
- **Principle VII (Observability)**: Performance metrics logged
