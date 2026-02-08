---
name: scope-analysis
version: 0.1.0
description: |
  Scope analysis skill — classifies task descriptions as tactic (small, focused) or
  strategy (large, cross-cutting) to determine the appropriate dev-loop workflow.
  Uses keyword scoring, file count heuristics, and cross-cutting concern detection
  for deterministic classification with confidence scoring.
allowed-tools: Read, Bash, Grep
triggers:
  - session-start
  - scope-detect
category: routing
constitutional_principles:
  - X    # Agent Delegation: scope determines which agents are invoked
  - XVI  # Plugin-First: capability organized as installable plugin
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_updated: null
---

# Scope Analysis Skill

## Overview

The scope-analysis skill classifies a user's task description as either **tactic** (small,
focused change) or **strategy** (large, cross-cutting change). This classification determines
which workflow the dev-loop orchestrator follows, enabling efficient resource allocation:

- **Tactic tasks** skip heavyweight specification and research phases
- **Strategy tasks** invoke the full SDD workflow with research, tribunal, and specification

The classification is deterministic -- the same input always produces the same output, ensuring
reproducible routing decisions across sessions.

## Invocation

Called by the dev-loop-orchestrator at session start (Step 2 of core-loop):

```
/dev-loop "task description" -> dev-loop-orchestrator -> scope-analysis skill
```

The skill is invoked exactly once per session, before the main iteration loop begins.
If the user provides `--mode tactic` or `--mode strategy`, the override bypasses detection
but the algorithmic classification is still computed for audit purposes.

## Inputs

| Input | Type | Source | Description |
|-------|------|--------|-------------|
| `description` | string | User /dev-loop command | Natural language task description (required, non-empty) |
| `--mode` | enum | User flag | Optional override: `tactic`, `strategy`, or `auto` (default: `auto`) |

## Outputs

| Output | Type | Destination | Description |
|--------|------|-------------|-------------|
| ScopeAnalysis entity | JSON | Session state | Full classification result conforming to `templates/scope-analysis.json` |
| Routing decision | string | dev-loop-orchestrator | `tactic` or `strategy` — determines workflow path |

### ScopeAnalysis Entity Fields

| Field | Type | Description |
|-------|------|-------------|
| `analysis_id` | string | Unique identifier (`scope-{timestamp}-{hash}`) |
| `input_description` | string | Original task description |
| `detected_scope` | enum | Algorithmic classification: `tactic` or `strategy` |
| `keyword_scores` | object | Breakdown of scoring signals |
| `signals` | object | Raw signal data (matched keywords, file estimate, concerns) |
| `confidence` | float | Classification confidence [0.0, 1.0] |
| `override_by_user` | string/null | User override value or null |
| `final_scope` | enum | Resolved scope used for routing |
| `timestamp` | string | ISO 8601 analysis timestamp |

## Procedure

### Step 1: Parse Inputs

Read the task description and optional `--mode` flag from the session context.
Validate that the description is non-empty. If `--mode` is set to `tactic` or `strategy`,
record it as the user override but still run the full detection pipeline for audit.

### Step 2: Score Keywords

```bash
source plugins/sdd-dev-loop/lib/scope-detector.sh
keyword_result=$(score_keywords "$description")
```

Match the lowercased description against two keyword lists:

**Tactic keywords** (weight -1.0 each):
`fix`, `typo`, `rename`, `bump`, `patch`, `tweak`, `adjust`, `update`, `correct`, `hotfix`

**Strategy keywords** (weight +1.0 each):
`implement`, `architect`, `design`, `migrate`, `redesign`, `integrate`, `overhaul`, `refactor`, `system`, `infrastructure`

### Step 3: Estimate File Count

```bash
file_count=$(estimate_file_count "$description")
```

Heuristic analysis of the description to estimate affected files:
- 1-2 files: score -0.5 (tactic bias)
- 3-5 files: score 0.0 (neutral)
- 6+ files: score +0.5 (strategy bias)

### Step 4: Detect Cross-Cutting Concerns

```bash
cross_cut=$(detect_cross_cutting "$description")
```

Scan for domain keywords across categories (frontend, backend, database, security, etc.).
If 2 or more distinct domains are detected, add +1.0 to the total score.

### Step 5: Classify Scope

```bash
detected_scope=$(classify_scope "$total_score")
```

Decision boundaries:
- `total_score <= -0.5` -> **tactic**
- `total_score >= 0.5` -> **strategy**
- `-0.5 < total_score < 0.5` -> **tactic** (ambiguous defaults to tactic)

### Step 6: Compute Confidence

```bash
confidence=$(compute_confidence "$total_score")
```

Formula: `confidence = min(1.0, abs(total_score) / 3.0)`

Confidence thresholds:
- **High (>= 0.8)**: Proceed with classification, no user prompt
- **Medium (0.6-0.8)**: Proceed but log a confidence warning
- **Low (< 0.6)**: Trigger clarification prompt to user before proceeding

### Step 7: Apply Override

If the user provided `--mode tactic` or `--mode strategy`, the `final_scope` uses
the override value regardless of the detected scope. The `detected_scope` field still
reflects the algorithmic result for audit purposes.

## Workflow Routing

The `final_scope` determines which workflow path the dev-loop orchestrator follows:

### Tactic Workflow

```
plan -> implement -> test -> grade
```

Streamlined cycle for small, focused changes:
- Skip research and specification phases
- Generate a lightweight plan directly from the task description
- Produce a focused task list (typically 1-3 tasks)
- Begin implementation immediately

### Strategy Workflow

```
research -> tribunal -> specify -> plan -> tasks -> implement -> test -> grade
```

Full SDD workflow for large, cross-cutting changes:
- Invoke `/specification` workflow (research, spec, plan, tasks)
- Run tribunal checkpoint on research synthesis
- Produce comprehensive specification, plan, and task list
- Integration with the full SDD specification workflow

## Integration

### With Core Loop Skill

The scope-analysis skill is invoked by the core-loop skill during Step 2. The routing
decision flows into Step 4 (Initial Research and Planning) to determine which planning
path to follow.

### With /specification Workflow

In strategy mode, scope-analysis triggers the full `/specification` workflow from the
sdd-specification plugin. This provides:
- Deep research synthesis
- Formal specification document
- Comprehensive implementation plan
- Detailed task breakdown with dependencies

### With RL Feedback

Scope classification accuracy is tracked via the RL feedback system. If a tactic-classified
task repeatedly fails or exceeds budget, the per_task_type metrics in the RLMetrics entity
capture this signal, enabling future routing improvements.

## Constitutional Compliance

| Principle | Enforcement |
|-----------|-------------|
| **X (Agent Delegation)** | Scope classification determines which agents and workflows are invoked. Tactic tasks use a streamlined path; strategy tasks invoke the full multi-agent SDD workflow. |
| **XVI (Plugin-First)** | Scope analysis is a discrete, installable skill within the sdd-dev-loop plugin. The library (`lib/scope-detector.sh`) and entity model (`templates/scope-analysis.json`) are self-contained. |

## Library Reference

All scope detection functions are implemented in `plugins/sdd-dev-loop/lib/scope-detector.sh`:

| Function | Purpose |
|----------|---------|
| `analyze_scope()` | Full pipeline: keyword scoring + file count + cross-cutting + classify |
| `score_keywords()` | Match tactic/strategy keywords and compute scores |
| `estimate_file_count()` | Heuristic file count estimation from description |
| `detect_cross_cutting()` | Multi-domain concern detection |
| `classify_scope()` | Score-to-classification mapping |
| `compute_confidence()` | Confidence score from total score magnitude |
| `apply_override()` | User override application |
