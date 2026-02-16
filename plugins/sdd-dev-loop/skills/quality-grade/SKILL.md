---
name: quality-grade
version: 0.1.0
description: |
  Quality grading skill — computes composite quality grades from normalized metrics
  (test pass rate, coverage, lint, type safety, security, build success) using configurable
  weights and threshold checks. Supports LLM-judge semantic evaluation for readability,
  architecture, and spec compliance assessment.
allowed-tools: Read, Bash, Grep
triggers:
  - grade-iteration
  - quality-check
  - threshold-evaluation
category: quality
constitutional_principles:
  - II    # Test-First: grade includes test_pass_rate (0.35 weight) and test_coverage (0.20)
  - VII   # Observability: all metrics normalized and auditable
  - VIII  # Documentation Sync: grades persisted to session grades/
  - XVI   # Plugin-First: capability organized as installable plugin
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_updated: null
---

# Quality Grade Skill

## Overview

The quality-grade skill computes composite quality grades for dev-loop iterations. It
normalizes raw quality metrics to a 0-1 scale, applies configurable weights, and checks
against quality thresholds to determine if the iteration meets the success criteria.

This skill is invoked by the core-loop at the end of each iteration to evaluate code quality
and determine whether to continue iterating or terminate with success.

## Invocation

Called by the core-loop during each iteration's grading phase (Step 5):

```
Implementation Complete -> Test Results -> quality-grade skill -> Termination Check
```

## Task Brief

When spawning an agent for quality grading, provide this context:

You are the Quality Grading specialist for the sdd-dev-loop plugin. Your role is to
evaluate code quality using the grading engine library.

**Library**: `plugins/sdd-dev-loop/lib/grading-engine.sh`

**Key Functions**:

### `normalize_metric METRIC_NAME RAW_VALUE`
Normalizes a raw metric value to a 0-1 scale. Metric names determine normalization strategy:
- `test_pass_rate`: ratio (0-1 passthrough)
- `test_coverage`: percentage divided by 100
- `lint`: inverse error count (1 / (1 + errors))
- `type_safety`: percentage divided by 100
- `security`: inverse vulnerability count
- `build`: binary (1.0 for success, 0.0 for failure)

### `compute_composite --metrics JSON --weights JSON`
Computes weighted composite grade from normalized metrics.
- `--metrics`: JSON object with keys: `test_pass_rate`, `test_coverage`, `lint`, `type_safety`, `security`, `build`
- `--weights`: JSON object with matching keys (must sum to ~1.0, test_pass_rate >= 0.30)
- Returns JSON: `{"composite_grade": N, "breakdown": [...]}`

### `check_threshold --grade FLOAT --threshold FLOAT`
Checks if a grade meets the quality threshold.
- Returns JSON: `{"passed": bool, "grade": N, "threshold": N, "delta": N}`
- Exit code 0 if passed, 1 if not

### `run_grade --workdir PATH`
Full grading pipeline — collects metrics from test results, lint, type checks, security
scans, and build status. Runs all collection functions and computes composite grade.

### `llm_judge --diff TEXT --spec TEXT`
AI semantic evaluation of code changes against specification. Returns scores for
readability, architecture, and compliance. Uses deterministic heuristic fallback
when LLM unavailable.

**Default Weights** (from `config/weights.json`):
| Metric | Weight |
|--------|--------|
| test_pass_rate | 0.35 |
| test_coverage | 0.20 |
| lint | 0.15 |
| type_safety | 0.15 |
| security | 0.10 |
| build | 0.05 |

**Quality Threshold**: Default 0.95 (configurable 0.80-0.99)

## Output

Grade results are persisted to session directory:
```
.devloop/sessions/$SESSION_ID/grades/grade-$ITERATION.json
```

## Constitutional Compliance

- **Principle II**: Test metrics (pass rate + coverage) carry 55% of total weight
- **Principle VII**: All metrics normalized and auditable via grade JSON files
