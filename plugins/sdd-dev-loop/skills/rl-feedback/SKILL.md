---
name: rl-feedback
version: 0.1.0
description: |
  RL (Reinforcement Learning) feedback skill — tracks skill and model performance metrics
  across dev-loop sessions using EMA-weighted success rates and UCB1 exploration scores.
  Updates RLMetrics entities and syncs with plugin manifests (plugins/*/plugin.json) for
  adaptive routing decisions.
allowed-tools: Read, Write, Bash, Grep
triggers:
  - session-complete
  - rl-feedback-collect
category: analytics
constitutional_principles:
  - VII   # Observability: all metrics tracked and auditable
  - VIII  # Documentation Sync: metrics synced with plugin manifests
  - XIV   # AI Model Selection: per-model tracking informs selection
  - XVI   # Plugin-First: capability organized as installable plugin
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_updated: null
---

# RL Feedback Skill

## Overview

The rl-feedback skill implements performance tracking and learning for the dev-loop
plugin. It is invoked by the dev-loop-orchestrator at session end to record outcomes
for all skills and models used during the session, update their EMA-weighted success
rates, and compute UCB1 exploration scores for future routing decisions.

This skill bridges the dev-loop's session-level outcomes to the framework's existing
RL feedback system (`.docs/rl-metrics/` and plugin manifests at `plugins/*/plugin.json`), ensuring that
autonomous loop performance data feeds back into the global skill routing.

## Invocation

Called by the dev-loop-orchestrator during post-loop finalization (Step 6 of core-loop):

```
Session Complete -> dev-loop-orchestrator -> rl-feedback skill
```

The skill is invoked exactly once per session, after the termination reason is determined
and the session report is generated.

## Inputs

The rl-feedback skill requires the following inputs from the session context:

| Input | Type | Source | Description |
|-------|------|--------|-------------|
| `session_outcome` | enum | Session state | `success`, `converged`, `budget_exhausted`, `max_iterations`, `stuck`, `user_interrupt` |
| `skills_used` | string[] | Session event log | List of skill names invoked during the session (e.g., `["core-loop", "scope-analysis", "quality-grade"]`) |
| `models_used` | string[] | Session event log | List of model names used during the session (e.g., `["claude-opus-4-6", "claude-sonnet-4-5"]`) |
| `task_type` | enum | Scope analysis | `tactic` or `strategy` — the resolved scope of the task |
| `total_tokens` | integer | Session budget tracking | Total tokens consumed across all iterations |
| `total_duration_ms` | integer | Session timing | Total wall-clock duration in milliseconds |
| `iteration_count` | integer | Session state | Number of iterations executed |
| `final_grade` | float | Quality grade | Final composite quality grade (0.0-1.0) |

## Outputs

| Output | Type | Destination | Description |
|--------|------|-------------|-------------|
| Updated RLMetrics | JSON | `plugins/sdd-dev-loop/templates/rl-metrics.json` instances | Per-skill, per-model metric updates |
| Synced plugin manifests | JSON | `plugins/*/plugin.json` | Updated selection_weight values |
| Synced performance store | JSON | `.docs/rl-metrics/skill-performance.json` | Detailed history persisted |
| Feedback summary | text | Session report | Human-readable summary of metric changes |

## Procedure

### Step 1: Determine Outcome Encoding

Map the session outcome to a binary success/failure value for EMA update:

| Session Outcome | Encoded Value | Rationale |
|----------------|---------------|-----------|
| `success` | 1.0 | Quality threshold met |
| `converged` | 1.0 | Quality plateaued at acceptable level |
| `budget_exhausted` | 0.0 | Did not meet threshold |
| `max_iterations` | 0.0 | Did not meet threshold |
| `stuck` | 0.0 | Loop detected oscillation/repetition |
| `user_interrupt` | *(skip)* | User-initiated, not a skill performance signal |

If the outcome is `user_interrupt`, do not update success_rate or selection_weight.
Still record the invocation in history for audit purposes.

### Step 2: Update Per-Skill Metrics (EMA)

For each skill in `skills_used`, apply the EMA update algorithm:

```
alpha = 0.1  # EMA learning rate

# EMA update for success_rate
new_rate = (1 - alpha) * old_rate + alpha * outcome_value

# Clamp selection_weight
new_weight = clamp(new_rate, 0.1, 1.0)

# Cumulative moving average for tokens
per_skill_tokens = total_tokens / len(skills_used)  # proportional split
new_avg_tokens = old_avg + (per_skill_tokens - old_avg) / new_count

# Cumulative moving average for duration
per_skill_duration = total_duration_ms / len(skills_used)  # proportional split
new_avg_duration = old_avg + (per_skill_duration - old_avg) / new_count
```

### Step 3: Update Per-Model Metrics

For each model in `models_used`, apply the same EMA update:

```
# Same EMA formula applied per model
new_model_rate = (1 - alpha) * old_model_rate + alpha * outcome_value
```

This enables model-aware routing — if a particular model consistently underperforms
on certain task types, the framework can route future work to better-performing models.

### Step 4: Update Per-Task-Type Breakdown

Update the `per_task_type` sub-metrics in each skill's RLMetrics:

```
# For the resolved task_type (tactic or strategy)
sub = rl_metrics.per_task_type[task_type]
sub.success_rate = (1 - alpha) * sub.success_rate + alpha * outcome_value
sub.invocation_count += 1
sub.avg_tokens = sub.avg_tokens + (per_skill_tokens - sub.avg_tokens) / sub.invocation_count
sub.avg_duration_ms = sub.avg_duration_ms + (per_skill_duration - sub.avg_duration_ms) / sub.invocation_count
```

### Step 5: Compute UCB1 Scores

After updating all skill metrics, compute UCB1 exploration scores for future routing:

```
total_invocations = sum(skill.invocation_count for skill in all_skills)

for each skill:
    if skill.invocation_count == 0:
        ucb1_score = Infinity  # Always explore untried skills
    else:
        ucb1_score = skill.success_rate + sqrt(2 * ln(total_invocations) / skill.invocation_count)
```

UCB1 scores are advisory — they inform the orchestrator's skill selection but do not
override explicit user commands or constitutional delegation requirements.

### Step 6: Persist Metrics

Record all updates to the persistent stores:

```bash
# Record outcome via existing framework RL scripts
.specify/scripts/bash/rl/collect-feedback.sh <skill_name> <success|failure> <tokens>

# Sync updated metrics to plugin manifests
.specify/scripts/bash/rl/sync-metrics.sh
```

Additionally, update the dev-loop-specific metric files:
- Append history entries to each skill's RLMetrics
- Update `last_feedback` snapshot
- Persist to `.docs/rl-metrics/skill-performance.json`

### Step 7: Generate Feedback Summary

Produce a human-readable summary of metric changes for the session report:

```
RL Feedback Summary:
- Skills updated: core-loop, scope-analysis, quality-grade
- Outcome: success (encoded as 1.0)
- Task type: strategy
- core-loop: success_rate 0.55 -> 0.60, weight 0.55 -> 0.60 (UCB1: 1.23)
- scope-analysis: success_rate 0.70 -> 0.73, weight 0.70 -> 0.73 (UCB1: 1.05)
- quality-grade: success_rate 0.80 -> 0.82, weight 0.80 -> 0.82 (UCB1: 0.98)
```

## Integration

### With Existing RL System

This skill integrates with the framework's existing RL feedback infrastructure:

| Component | Path | Integration |
|-----------|------|-------------|
| Collect script | `.specify/scripts/bash/rl/collect-feedback.sh` | Called to record each skill outcome |
| Sync script | `.specify/scripts/bash/rl/sync-metrics.sh` | Called to push updated weights to plugin manifests |
| Plugin manifests | `plugins/*/plugin.json` | Updated `selection_weight` for framework-wide routing |
| Performance store | `.docs/rl-metrics/skill-performance.json` | Detailed history persistence |
| Dashboard | `.specify/scripts/bash/rl/dashboard.sh` | Human-readable metric view |

### With Dev-Loop Plugin

| Component | Path | Integration |
|-----------|------|-------------|
| RLMetrics template | `plugins/sdd-dev-loop/templates/rl-metrics.json` | Entity model for metric structure |
| Core loop skill | `plugins/sdd-dev-loop/skills/core-loop/SKILL.md` | Primary skill tracked |
| Session state | `plugins/sdd-dev-loop/templates/session-state.json` | Source of session outcome data |
| Orchestrator agent | `plugins/sdd-dev-loop/agents/dev-loop-orchestrator.md` | Invokes this skill at session end |

## Algorithm Reference

### EMA (Exponential Moving Average)

```
new_rate = (1 - alpha) * old_rate + alpha * outcome
alpha = 0.1 (default learning rate)
outcome = 1.0 (success) or 0.0 (failure)
```

Properties:
- Recent outcomes have more influence than older ones
- Alpha = 0.1 means ~10% weight on newest observation
- Converges slowly, providing stability against noise
- Initial value of 0.5 provides neutral prior

### UCB1 (Upper Confidence Bound 1)

```
ucb1 = success_rate + sqrt(2 * ln(N) / n_i)
N = total invocations across all skills
n_i = invocations for skill i
```

Properties:
- Balances exploitation (high success_rate) with exploration (low invocation_count)
- Untried skills get Infinity score (always explored first)
- Exploration bonus decays as invocation_count grows
- Proven optimal for multi-armed bandit problems

## Constitutional Compliance

| Principle | Enforcement |
|-----------|-------------|
| **VII (Observability)** | All metric updates logged with before/after values in session event log. Full history maintained for audit. |
| **VIII (Documentation Sync)** | Metrics synced to plugin manifests (`plugins/*/plugin.json`) after every session, keeping the skill registry current. |
| **XIV (AI Model Selection)** | Per-model tracking enables data-driven model selection for future sessions. |
| **XVI (Plugin-First)** | RL feedback is a discrete, installable skill within the sdd-dev-loop plugin. |
