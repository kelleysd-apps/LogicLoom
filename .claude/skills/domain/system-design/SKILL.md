---
name: system-design
version: 3.0.0
category: domain
description: Designs system architecture, infrastructure, and scalability patterns
triggers:
  - system design
  - architecture design
  - infrastructure
  - scalability
  - high availability
  - system architecture
rl_metrics:
  success_rate: 0.0
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
progressive-disclosure:
  layer-1-metadata:
    description: "Handles system architecture and infrastructure design"
    triggers: [system design, architecture, infrastructure, scalability]
    primary-agent: system-architect
  layer-2-instructions: true
  layer-3-examples: true
agent-invocations:
  - agent: system-architect
    context-subset:
      - requirements
      - scale_requirements
      - availability_targets
      - constraints
    expected-output: system_design
ds-star:
  pre-execution: validation/message-preflight
  post-verification: true
  auto-debug: conditional
---

# System Design Skill

## Purpose

Designs system architecture including infrastructure, scalability patterns,
high availability strategies, and deployment architectures. Covers both
greenfield designs and architecture evolution.

## Constitutional Compliance

- **Principle III (Contract-First)**: System contracts before implementation
- **Principle V (Progressive Enhancement)**: Start simple, scale as needed
- **Principle X (Skills-First)**: Skill orchestrates, system-architect executes

## Instructions

### Step 1: Requirements Analysis

Gather:
- Functional requirements
- Non-functional requirements (NFRs):
  - Scale: Expected load, growth rate
  - Availability: Uptime targets (99.9%, etc.)
  - Latency: Response time targets
  - Consistency: CAP theorem tradeoffs
- Budget constraints
- Timeline

### Step 2: High-Level Design

```yaml
system_design:
  name: <system>
  components:
    - name: <component>
      type: <service | database | cache | queue | cdn>
      technology: <tech stack>
      scale_strategy: <horizontal | vertical | auto>

  data_flow:
    - from: <component>
      to: <component>
      protocol: <http | grpc | websocket | queue>

  deployment:
    environment: <cloud | hybrid | on-prem>
    regions: [<region1>, <region2>]
```

### Step 3: Scalability Design

Define scaling strategies:
```yaml
scalability:
  compute:
    strategy: auto-scaling
    min_instances: 2
    max_instances: 20
    scale_metric: cpu_utilization
    target_value: 70%

  database:
    strategy: read_replicas
    primary: 1
    replicas: 3
    sharding: optional

  caching:
    strategy: distributed
    technology: redis_cluster
    eviction: lru
```

### Step 4: High Availability Design

```yaml
availability:
  target: 99.9%
  strategy:
    - multi_az_deployment
    - load_balancing
    - health_checks
    - auto_failover

  disaster_recovery:
    rpo: 1_hour
    rto: 4_hours
    backup_strategy: continuous
```

### Step 5: Generate Artifacts

Produce:
- Architecture diagram
- Component specifications
- Infrastructure as Code (IaC)
- Runbook documentation

## Agent Invocation

```yaml
invoke: system-architect
context:
  requirements: "<functional requirements>"
  scale: "<expected scale>"
  availability: "<target uptime>"
  constraints: ["<budget>", "<timeline>"]
expected:
  format: system_design
  artifacts: [diagram, specs, iac, runbook]
```

## Examples

### Example 1: E-commerce Platform Design

**Request**: "Design system for e-commerce platform with 100K daily users"

**Output**:

```
┌─────────────────────────────────────────────────────────────┐
│                        CDN (CloudFront)                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Load Balancer (ALB)                       │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│  Web Server   │     │  Web Server   │     │  Web Server   │
│   (Next.js)   │     │   (Next.js)   │     │   (Next.js)   │
└───────────────┘     └───────────────┘     └───────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│  API Server   │     │  API Server   │     │  API Server   │
│   (Node.js)   │     │   (Node.js)   │     │   (Node.js)   │
└───────────────┘     └───────────────┘     └───────────────┘
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│    Redis      │     │  PostgreSQL   │     │ Message Queue │
│   (Cache)     │     │  (Primary)    │     │   (SQS)       │
└───────────────┘     └───────────────┘     └───────────────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
            ┌───────────────┐   ┌───────────────┐
            │  Read Replica │   │  Read Replica │
            └───────────────┘   └───────────────┘
```

**Specifications**:
```yaml
components:
  - name: web-servers
    technology: Next.js
    instances: 3-10 (auto-scale)
    cpu: 2 vCPU
    memory: 4 GB

  - name: api-servers
    technology: Node.js/Express
    instances: 3-15 (auto-scale)
    cpu: 2 vCPU
    memory: 4 GB

  - name: database
    technology: PostgreSQL 15
    instance_type: db.r6g.large
    storage: 500 GB
    replicas: 2

  - name: cache
    technology: Redis 7
    cluster_mode: enabled
    nodes: 3

availability:
  target: 99.9%
  multi_az: true
  backup_retention: 30_days

estimated_cost: $2,500/month
```

## Error Handling

| Scenario | Detection | Resolution |
|----------|-----------|------------|
| Over-engineering | Review | Apply progressive enhancement |
| Single points of failure | Analysis | Add redundancy |
| Cost overrun | Budget check | Optimize resource sizing |

## RL Metrics

- **Success Criteria**: Design meets NFRs
- **Token Efficiency**: < 1500 tokens per design

## Related Skills

- **domain/service-architecture**: Service layer
- **domain/devops-operations**: Deployment
- **domain/performance-operations**: Optimization

---

*Domain skill version: 3.0.0*
