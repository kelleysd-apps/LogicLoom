# RL Feedback Architecture

**Version**: 1.0.0
**Feature**: DS-STAR Multi-Agent Enhancements
**Status**: Active

---

## Overview

The RL (Reinforcement Learning) Feedback Architecture enables skills to improve over time based on execution outcomes. This implements FR-701 (RL-enhanced routing) and FR-708 (3.5x task completion accuracy target).

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        USER REQUEST                                  │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   [FR-707] MESSAGE PREFLIGHT                         │
│                   Constitutional compliance check                     │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   [FR-701] ROUTER AGENT                              │
│                                                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  skill-index.json                                            │   │
│   │  └── skills[].rl_metrics.selection_weight                    │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│   Algorithm: Softmax selection with temperature                      │
│   P(skill) = exp(weight/T) / Σexp(weights/T)                        │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      SKILL EXECUTION                                 │
│                                                                      │
│   1. Skill activates with progressive disclosure                     │
│   2. Agent(s) invoked as needed                                      │
│   3. Output generated                                                │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   VERIFIER VALIDATION                                │
│                                                                      │
│   • Output format validation                                         │
│   • Constitutional compliance check                                  │
│   • Quality threshold verification                                   │
│   • Domain-specific validation                                       │
└─────────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
              ┌──────────┐           ┌──────────┐
              │ SUCCESS  │           │ FAILURE  │
              └──────────┘           └──────────┘
                    │                       │
                    └───────────┬───────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   RL FEEDBACK COLLECTION                             │
│                                                                      │
│   collect-feedback.sh <skill-name> <success|failure> [tokens]        │
│                                                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  EMA Update:                                                 │   │
│   │  success_rate = 0.9 * old_rate + 0.1 * (1 if success else 0)│   │
│   │  selection_weight = clamp(success_rate, 0.1, 1.0)           │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│   Output: skill-performance.json                                     │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   METRICS SYNC                                       │
│                                                                      │
│   sync-metrics.sh                                                    │
│   skill-performance.json → skill-index.json                          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. skill-index.json

Central registry containing RL metrics for each skill:

```json
{
  "skills": [
    {
      "name": "api-design",
      "rl_metrics": {
        "success_rate": 0.85,
        "selection_weight": 0.85,
        "invocation_count": 42,
        "avg_tokens": 1250,
        "last_updated": "2026-02-05T12:00:00Z"
      }
    }
  ],
  "rl_config": {
    "algorithm": "ema",
    "learning_rate": 0.1,
    "temperature": 1.0,
    "min_weight": 0.1,
    "max_weight": 1.0
  }
}
```

### 2. skill-performance.json

Detailed performance tracking with history:

```json
{
  "skills": {
    "api-design": {
      "success_rate": 0.85,
      "selection_weight": 0.85,
      "invocation_count": 42,
      "history": [
        {"timestamp": "...", "success": true, "tokens": 1200}
      ]
    }
  },
  "aggregates": {
    "total_invocations": 150,
    "average_success_rate": 0.78
  }
}
```

### 3. SKILL.md Frontmatter

Each skill includes RL metrics in frontmatter:

```yaml
---
name: api-design
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_feedback: null
---
```

### 4. RL Scripts

| Script | Purpose |
|--------|---------|
| `collect-feedback.sh` | Record execution result |
| `sync-metrics.sh` | Sync to skill-index.json |
| `dashboard.sh` | View performance metrics |

---

## Algorithm: EMA (Exponential Moving Average)

Used in Phase 1-2 (hybrid mode):

```
success_rate_new = (1 - α) * success_rate_old + α * reward

Where:
  α = learning_rate = 0.1
  reward = 1.0 for success, 0.0 for failure
  
selection_weight = clamp(success_rate, min_weight, max_weight)
```

### Selection via Softmax

Router selects skill using temperature-controlled softmax:

```
P(skill_i) = exp(weight_i / T) / Σ exp(weight_j / T)

Where:
  T = temperature = 1.0 (balanced exploration/exploitation)
```

---

## Integration Points

### Skill Execution

Each skill includes RL Feedback Loop section:

```markdown
## RL Feedback Loop

ON SKILL COMPLETION:
  1. Capture execution result
  2. Record token usage
  3. Update metrics via EMA
  4. Log to skill-performance.json
```

### Verifier Validation

Before completion, skills invoke verifier:

```markdown
## Verifier Integration

VERIFIER_CHECK:
  1. Output format validation
  2. Constitutional compliance
  3. Quality threshold (0.85)
```

---

## Performance Targets (FR-708)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Task completion accuracy | 3.5x baseline | Pre/post comparison |
| Average success rate | >80% | After 30 days |
| Selection weight convergence | Within 50 invocations | Per skill |

---

## Usage

### Record Feedback

```bash
# After successful skill execution
.specify/scripts/bash/rl/collect-feedback.sh api-design success 1500

# After failed execution
.specify/scripts/bash/rl/collect-feedback.sh api-design failure 800
```

### Sync to Index

```bash
# Sync performance metrics to skill-index.json
.specify/scripts/bash/rl/sync-metrics.sh

# Dry run
.specify/scripts/bash/rl/sync-metrics.sh --dry-run
```

### View Dashboard

```bash
# Display dashboard
.specify/scripts/bash/rl/dashboard.sh

# Top 20 skills
.specify/scripts/bash/rl/dashboard.sh --top 20

# Raw JSON
.specify/scripts/bash/rl/dashboard.sh --json
```

---

## Future Enhancements (Phase 3-4)

- **GRPO/PPO algorithms** for more sophisticated learning
- **Multi-arm bandit** for exploration/exploitation balance
- **Contextual bandits** for user/project-specific learning
- **Automatic skill enhancement** trigger when success_rate < 0.6

---

## Related

- Constitution v2.0.0 - Principle X (Skills-First)
- Router Agent - `.claude/agents/ds-star/router-agent.md`
- Verifier Agent - `.claude/agents/ds-star/verifier-agent.md`
