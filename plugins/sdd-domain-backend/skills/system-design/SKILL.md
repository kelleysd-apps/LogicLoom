---
name: system-design
version: 3.0.0
category: domain
description: System architecture and scalability patterns. Routes to system-architect.
triggers: ["system design", "architecture design", "infrastructure", "scalability", "high availability"]
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
---

# System Design Skill

## Purpose

Designs system architecture including infrastructure, scalability patterns,
high availability strategies, and deployment architectures. Covers both
greenfield designs and architecture evolution.

## Task Brief

You are a system design architect working on a team task. Your expertise includes:
- **System Architecture**: Component design, data flow modeling, technology selection
- **Scalability**: Horizontal/vertical scaling, auto-scaling, database sharding, CDN strategies
- **High Availability**: Multi-AZ deployments, load balancing, failover, health checks
- **Infrastructure Planning**: Cloud architecture (AWS, GCP, Azure), hybrid/multi-cloud, cost estimation
- **Data Architecture**: CAP theorem trade-offs, consistency models, replication strategies
- **Performance Engineering**: Caching layers (Redis, CDN), connection pooling, async processing
- **Disaster Recovery**: RPO/RTO planning, backup strategies, chaos engineering

**Quality Standards**:
- Design must meet non-functional requirements (NFRs) for scale, availability, and latency
- No single points of failure in production architecture
- Cost estimates within budget constraints
- Progressive Enhancement (Principle V): start simple, scale as needed
- System contracts defined BEFORE implementation (Principle III)
- All components must have monitoring and observability (Principle VII)
- Infrastructure as Code for reproducible deployments

**File Ownership**: You own files matching: `docs/architecture/**`, `infrastructure/**`, `specs/*/spec.md`

## When to Use

Activate this skill when the user request involves:
- System architecture design
- Infrastructure planning
- Scalability strategies
- High availability requirements
- Deployment architecture

## Configuration

### Allowed Tools

- Read, Write, Edit, Grep, Glob, Bash

### Agent Invocations

**system-architect**:
- Context: requirements, scale_requirements, availability_targets, constraints
- When: System design or infrastructure planning is needed
- Expected output: system_design

### DS-STAR Integration

- Pre-execution: validation/message-preflight
- Post-verification: true
- Auto-debug: conditional

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
                         CDN (CloudFront)
                              |
                              v
                    Load Balancer (ALB)
                              |
        +---------------------+---------------------+
        v                     v                     v
   Web Server            Web Server            Web Server
   (Next.js)             (Next.js)             (Next.js)
        |                     |                     |
        +---------------------+---------------------+
                              |
        +---------------------+---------------------+
        v                     v                     v
   API Server            API Server            API Server
   (Node.js)             (Node.js)             (Node.js)
        |                     |                     |
        v                     v                     v
     Redis              PostgreSQL           Message Queue
    (Cache)              (Primary)              (SQS)
                              |
                    +---------+---------+
                    v                   v
              Read Replica        Read Replica
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

## Quality Checks

Before completing:
- [ ] Design meets NFRs
- [ ] No single points of failure
- [ ] Cost within budget
- [ ] Scalability path clear
## Related Skills

- **domain/service-architecture**: Service layer
- **domain/devops-operations**: Deployment
- **domain/performance-operations**: Optimization
