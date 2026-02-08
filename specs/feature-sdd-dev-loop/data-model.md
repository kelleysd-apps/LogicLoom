# Data Model: sdd-dev-loop — Recursive Autonomous Dev-Loop Plugin

**Branch**: `feature-sdd-dev-loop` | **Date**: 2026-02-07

---

## Entity: DevLoopSession

Represents a single invocation of the dev-loop from start to termination. Tracks execution state, quality progression, resource consumption, and termination conditions.

```json
{
  "session_id": "devloop-20260207-143022-abc123",
  "feature_description": "implement OAuth2 authentication with RBAC",
  "branch": "feature/oauth2-auth",
  "current_phase": "implement",
  "iteration_count": 7,
  "quality_grades": [
    {"iteration": 1, "composite_grade": 0.72, "timestamp": "2026-02-07T14:35:00Z"},
    {"iteration": 2, "composite_grade": 0.81, "timestamp": "2026-02-07T14:42:00Z"},
    {"iteration": 3, "composite_grade": 0.89, "timestamp": "2026-02-07T14:48:00Z"}
  ],
  "tribunal_ballots": [
    {"ballot_id": "ballot-1", "round": "research", "verdict": "approved"},
    {"ballot_id": "ballot-2", "round": "approach", "verdict": "approved"}
  ],
  "termination_reason": null,
  "started_at": "2026-02-07T14:30:00Z",
  "completed_at": null,
  "scope_mode": "strategy",
  "budget_spent": {
    "tokens": 125000,
    "cost_usd": 3.75
  },
  "budget_limit": {
    "tokens": 500000,
    "cost_usd": 15.00,
    "max_iterations": 25
  },
  "checkpoint_path": "/path/to/checkpoint.json",
  "config": {
    "quality_threshold": 0.95,
    "convergence_delta": 0.001,
    "convergence_window": 3,
    "model_primary": "claude-opus-4-6",
    "model_fallback": "claude-sonnet-4-5"
  }
}
```

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| session_id | string | Yes | Unique session identifier (devloop-{timestamp}-{hash}) |
| feature_description | string | Yes | Natural language task description from user |
| branch | string | Yes | Git branch for autonomous work |
| current_phase | enum | Yes | research, plan, implement, test, grade, evaluate, complete |
| iteration_count | integer | Yes | Current iteration number (1-based) |
| quality_grades | QualityGrade[] | Yes | History of quality assessments |
| tribunal_ballots | TribunalBallot[] | Yes | History of tribunal decisions |
| termination_reason | string | No | success, converged, budget_exhausted, max_iterations, stuck, user_interrupt |
| started_at | ISO8601 | Yes | Session start timestamp |
| completed_at | ISO8601 | No | Session completion timestamp |
| scope_mode | enum | Yes | tactic (streamlined) or strategy (full workflow) |
| budget_spent | BudgetUsage | Yes | Cumulative resource consumption |
| budget_limit | BudgetLimit | Yes | Hard circuit breakers |
| checkpoint_path | string | No | Path to resumable checkpoint file |
| config | SessionConfig | Yes | Configuration overrides |

### State Transitions

```
pending → running → [paused ↔ running]* → complete
                                         → failed
```

**Allowed Transitions:**
- `pending → running`: Session start
- `running → paused`: User interrupt (FR-028)
- `paused → running`: Resume from checkpoint
- `running → complete`: Termination condition met (FR-022)
- `running → failed`: Unrecoverable error
- `paused → complete`: User terminates paused session

### Validation Rules

- `iteration_count` MUST be ≥ 1 and ≤ `budget_limit.max_iterations`
- `budget_spent.tokens` MUST be ≤ `budget_limit.tokens`
- `budget_spent.cost_usd` MUST be ≤ `budget_limit.cost_usd`
- `quality_grades` array MUST have length = `iteration_count`
- `termination_reason` MUST be null when status = `running` or `paused`
- `completed_at` MUST be null when status ≠ `complete` or `failed`
- `scope_mode` MUST be set before first iteration (FR-034)

---

## Entity: TribunalBallot

Represents a single tribunal voting round where three independent AI models assess a decision point (research synthesis, implementation approach, or quality dispute).

```json
{
  "ballot_id": "ballot-20260207-143500-xyz",
  "session_id": "devloop-20260207-143022-abc123",
  "round": "approach_selection",
  "decision_point": "Choose between monolithic auth service vs. microservice gateway",
  "claims": [
    {
      "model_id": "model-A",
      "assessment": "Recommend microservice gateway for scalability",
      "confidence": 0.85,
      "reasoning": "Aligns with existing architecture, enables independent scaling"
    },
    {
      "model_id": "model-B",
      "assessment": "Recommend monolithic for simplicity",
      "confidence": 0.78,
      "reasoning": "Lower operational overhead, faster initial delivery"
    },
    {
      "model_id": "model-C",
      "assessment": "Recommend microservice gateway",
      "confidence": 0.91,
      "reasoning": "Future-proofs against multi-tenant requirements"
    }
  ],
  "votes": {
    "model-A": {
      "vote": "microservice",
      "weight": 0.88,
      "historical_success_rate": 0.88
    },
    "model-B": {
      "vote": "monolithic",
      "weight": 0.82,
      "historical_success_rate": 0.82
    },
    "model-C": {
      "vote": "microservice",
      "weight": 0.91,
      "historical_success_rate": 0.91
    }
  },
  "verdict": "microservice",
  "consensus_level": "majority",
  "weighted_score": 0.895,
  "timestamp": "2026-02-07T14:35:00Z"
}
```

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| ballot_id | string | Yes | Unique ballot identifier (ballot-{timestamp}-{hash}) |
| session_id | string | Yes | Parent session reference |
| round | enum | Yes | research, approach_selection, quality_dispute |
| decision_point | string | Yes | Human-readable description of what's being decided |
| claims | Claim[] | Yes | Anonymized assessments from each model (length = 3) |
| votes | object | Yes | Per-model vote with EMA-adjusted weight (FR-009) |
| verdict | string | Yes | Final decision reached by tribunal |
| consensus_level | enum | Yes | unanimous (3-of-3), majority (2-of-3), split (1-1-1) |
| weighted_score | float | No | Aggregate confidence weighted by historical reliability |
| timestamp | ISO8601 | Yes | Ballot completion timestamp |

### Validation Rules

- `claims` array MUST have length = 3 (FR-006)
- `votes` object MUST have exactly 3 entries
- `votes[*].weight` MUST be in range [0.1, 1.0]
- `consensus_level = "unanimous"` ⟺ all votes equal
- `consensus_level = "majority"` ⟺ 2 votes equal
- `consensus_level = "split"` ⟺ all votes different
- `verdict` MUST match the majority vote (or weighted winner for split)
- `weighted_score` = Σ(confidence[i] × weight[i]) / Σ(weight[i])

### Anonymization Protocol (FR-007)

During tribunal execution:
1. Models assessed in parallel without seeing each other's identity
2. Claims presented to aggregator without model attribution
3. Voting occurs based on claim content only
4. Attribution revealed only after verdict finalized

---

## Entity: QualityGrade

Represents the composite quality assessment of a single iteration's output, combining automated metrics and AI-based semantic evaluation.

```json
{
  "grade_id": "grade-20260207-143500-iter3",
  "session_id": "devloop-20260207-143022-abc123",
  "iteration": 3,
  "raw_metrics": {
    "test_pass_rate": 0.95,
    "coverage_pct": 87.5,
    "lint_error_count": 0,
    "type_error_count": 2,
    "security_vulnerabilities": {
      "critical": 0,
      "high": 0,
      "medium": 1,
      "low": 3
    },
    "build_status": "success"
  },
  "normalized_scores": {
    "test_pass_rate": 0.95,
    "coverage": 0.875,
    "lint": 1.0,
    "type_safety": 0.80,
    "security": 0.85,
    "build": 1.0
  },
  "weights_used": {
    "test_pass_rate": 0.35,
    "coverage": 0.20,
    "lint": 0.15,
    "type_safety": 0.15,
    "security": 0.10,
    "build": 0.05
  },
  "composite_grade": 0.89,
  "llm_judge_score": 0.92,
  "llm_judge_feedback": "Architecture is sound, code is readable, edge cases covered",
  "passed_threshold": false,
  "threshold": 0.95,
  "timestamp": "2026-02-07T14:48:00Z"
}
```

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| grade_id | string | Yes | Unique grade identifier (grade-{timestamp}-iter{N}) |
| session_id | string | Yes | Parent session reference |
| iteration | integer | Yes | Iteration number (1-based) |
| raw_metrics | object | Yes | Unprocessed quality measurements |
| normalized_scores | object | Yes | All metrics normalized to [0, 1] scale |
| weights_used | object | Yes | Weights applied to each metric (sum = 1.0) |
| composite_grade | float | Yes | Weighted average of normalized scores |
| llm_judge_score | float | No | AI-based semantic evaluation (0-1 scale) |
| llm_judge_feedback | string | No | Qualitative commentary from AI judge |
| passed_threshold | boolean | Yes | Whether composite_grade ≥ threshold |
| threshold | float | Yes | Quality threshold for this session |
| timestamp | ISO8601 | Yes | Grade computation timestamp |

### Calculation Algorithm (FR-012)

```javascript
composite_grade = Σ(normalized_scores[metric] × weights_used[metric])
                  for metric in [test_pass_rate, coverage, lint, type_safety, security, build]

// Test pass rate normalization
normalized_scores.test_pass_rate = raw_metrics.test_pass_rate

// Coverage normalization
normalized_scores.coverage = raw_metrics.coverage_pct / 100

// Lint normalization (zero errors = 1.0)
normalized_scores.lint = raw_metrics.lint_error_count === 0 ? 1.0 : 0.0

// Type safety normalization (zero errors = 1.0)
normalized_scores.type_safety = raw_metrics.type_error_count === 0 ? 1.0 : 0.0

// Security normalization (zero critical/high = 1.0, medium/low deducted)
normalized_scores.security = 1.0 - (critical × 0.2 + high × 0.1 + medium × 0.05 + low × 0.01)

// Build normalization
normalized_scores.build = raw_metrics.build_status === "success" ? 1.0 : 0.0
```

### Validation Rules

- `composite_grade` MUST be in range [0, 1]
- All `normalized_scores[*]` MUST be in range [0, 1]
- All `weights_used[*]` MUST be in range [0, 1]
- Σ(weights_used[*]) MUST = 1.0
- `weights_used.test_pass_rate` MUST be ≥ 0.30 (FR-014)
- `llm_judge_score` MUST be in range [0, 1] if present
- `passed_threshold` = (`composite_grade` ≥ `threshold`)

---

## Entity: TerminationEvent

Represents the reason a dev-loop session ended and the conditions that triggered termination.

```json
{
  "event_id": "term-20260207-150000-success",
  "session_id": "devloop-20260207-143022-abc123",
  "reason": "success",
  "iteration": 7,
  "final_grade": 0.96,
  "checkpoint_saved": true,
  "trigger_conditions": {
    "threshold_met": true,
    "convergence_detected": false,
    "budget_exhausted": false,
    "max_iterations_reached": false,
    "stuck_detected": false,
    "user_interrupted": false
  },
  "details": {
    "quality_threshold": 0.95,
    "final_quality": 0.96,
    "iterations_used": 7,
    "budget_used_pct": 45.3
  },
  "timestamp": "2026-02-07T15:00:00Z"
}
```

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| event_id | string | Yes | Unique termination event identifier |
| session_id | string | Yes | Parent session reference |
| reason | enum | Yes | success, converged, budget_exhausted, max_iterations, stuck, user_interrupt |
| iteration | integer | Yes | Iteration at which termination occurred |
| final_grade | float | No | Composite quality grade at termination |
| checkpoint_saved | boolean | Yes | Whether session state was persisted |
| trigger_conditions | object | Yes | Boolean flags for each termination layer |
| details | object | No | Context-specific termination details |
| timestamp | ISO8601 | Yes | Termination timestamp |

### Termination Priority (FR-022)

Evaluated in order (first match wins):
1. **success**: `trigger_conditions.threshold_met = true` (FR-016)
2. **converged**: `trigger_conditions.convergence_detected = true` (FR-023)
3. **budget_exhausted**: `trigger_conditions.budget_exhausted = true` (FR-025)
4. **max_iterations**: `trigger_conditions.max_iterations_reached = true` (FR-024)
5. **stuck**: `trigger_conditions.stuck_detected = true` (FR-026)
6. **user_interrupt**: `trigger_conditions.user_interrupted = true` (FR-028)

### Validation Rules

- Exactly one of `trigger_conditions[*]` MUST be `true`
- `reason` MUST match the highest-priority triggered condition
- `checkpoint_saved` MUST be `true` for `user_interrupt` terminations
- `final_grade` MUST match the last entry in `DevLoopSession.quality_grades[]`

---

## Entity: PluginManifest (Self-Created)

Represents the metadata for a plugin created by the dev-loop system via self-extension (FR-038 through FR-042).

```json
{
  "name": "sdd-tool-specialized-linter",
  "version": "0.1.0",
  "description": "Specialized linter for project-specific conventions",
  "author": "devloop-selfgen",
  "license": "MIT",
  "entrypoint": "plugins/sdd-tool-specialized-linter/index.sh",
  "parameters": {
    "config_path": {
      "type": "string",
      "required": true,
      "description": "Path to linter configuration"
    },
    "severity": {
      "type": "enum",
      "values": ["error", "warning", "info"],
      "default": "error"
    }
  },
  "permissions_required": ["read:workspace", "write:logs"],
  "created_by_session": "devloop-20260207-143022-abc123",
  "quarantine_status": "passed",
  "constitutional_review": {
    "passed": true,
    "reviewed_by": "constitutional-governance-agent",
    "review_date": "2026-02-07T15:30:00Z",
    "violations_found": [],
    "risk_assessment": "low"
  },
  "rl_metrics": {
    "success_rate": 0.5,
    "selection_weight": 0.5,
    "invocation_count": 0,
    "avg_tokens": 0,
    "last_updated": "2026-02-07T15:30:00Z"
  }
}
```

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | Yes | Plugin identifier (sdd-tool-{name}) |
| version | semver | Yes | Semantic version (starts at 0.1.0) |
| description | string | Yes | Human-readable purpose |
| author | string | Yes | Always "devloop-selfgen" for self-created |
| entrypoint | string | Yes | Path to executable entry point |
| parameters | object | No | JSON schema for plugin parameters |
| permissions_required | string[] | Yes | Required access levels (L0-L3) |
| created_by_session | string | Yes | Session ID that created this plugin |
| quarantine_status | enum | Yes | pending, testing, passed, failed |
| constitutional_review | object | Yes | Governance validation results (FR-041) |
| rl_metrics | object | Yes | Performance tracking |

### Quarantine Lifecycle (FR-040)

```
created → quarantine:pending → quarantine:testing → quarantine:passed → active
                                                   → quarantine:failed → archived
```

**Quarantine Checks:**
- Unit tests pass with ≥ 80% coverage
- Security scan shows no critical/high vulnerabilities
- No access to files outside workspace
- No network calls to non-allowlisted destinations
- Constitutional review passed

### Validation Rules

- `name` MUST start with `"sdd-tool-"`
- `version` MUST be valid semver
- `author` MUST be `"devloop-selfgen"` for self-created plugins
- `permissions_required` MUST only contain: `read:workspace`, `write:workspace`, `read:logs`, `write:logs`
- `quarantine_status = "passed"` ⟹ `constitutional_review.passed = true`
- Plugin MUST NOT be usable until `quarantine_status = "passed"`

---

## Entity: EventLog

Represents a single event in the dev-loop session's structured event stream, enabling session replay and RL feedback extraction.

```json
{
  "event_id": "evt-20260207-143500-001",
  "session_id": "devloop-20260207-143022-abc123",
  "timestamp": "2026-02-07T14:35:00Z",
  "event_type": "thought",
  "iteration": 1,
  "content": "Analyzing test failures to identify root cause",
  "metadata": {
    "phase": "diagnose",
    "test_failures": 3,
    "related_files": ["auth.test.ts", "auth.service.ts"]
  },
  "parent_event_id": null,
  "tokens_consumed": 0
}
```

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| event_id | string | Yes | Unique event identifier (evt-{timestamp}-{seq}) |
| session_id | string | Yes | Parent session reference |
| timestamp | ISO8601 | Yes | Event occurrence timestamp |
| event_type | enum | Yes | thought, action, observation, decision, tool_invocation, grade, vote, error |
| iteration | integer | Yes | Iteration number (0 = pre-loop, ≥1 = loop iterations) |
| content | string | Yes | Human-readable event description |
| metadata | object | No | Type-specific structured data |
| parent_event_id | string | No | For nested/causal event chains |
| tokens_consumed | integer | No | Tokens used by this event (if applicable) |

### Event Types and Metadata Schemas

**thought**: Agent reasoning step
```json
{"phase": "string", "reasoning": "string"}
```

**action**: Agent action performed
```json
{"action_type": "read|write|execute", "target": "string", "tool": "string"}
```

**observation**: Result of an action
```json
{"action_id": "string", "status": "success|failure", "output": "string"}
```

**decision**: Tribunal or quality gate decision
```json
{"decision_type": "tribunal|convergence|termination", "verdict": "string"}
```

**tool_invocation**: External tool called
```json
{"tool": "string", "args": {}, "duration_ms": 1200, "exit_code": 0}
```

**grade**: Quality assessment completed
```json
{"grade_id": "string", "composite_score": 0.89, "passed": false}
```

**vote**: Tribunal ballot recorded
```json
{"ballot_id": "string", "verdict": "string", "consensus": "majority"}
```

**error**: Error encountered
```json
{"error_type": "string", "message": "string", "recoverable": true}
```

### Validation Rules

- Events MUST be ordered chronologically by `timestamp`
- `iteration` MUST be ≤ parent session's `iteration_count`
- `parent_event_id` MUST reference an earlier event in the same session
- Session replay MUST produce deterministic results from event log

---

## Entity: RLMetrics

Represents learned performance data for a skill or AI model, updated after each session via EMA (Exponential Moving Average).

```json
{
  "skill_name": "sdd-specification",
  "model_name": "claude-opus-4-6",
  "success_rate": 0.88,
  "selection_weight": 0.88,
  "invocation_count": 47,
  "avg_tokens": 3500,
  "avg_duration_ms": 4200,
  "last_feedback": {
    "session_id": "devloop-20260207-143022-abc123",
    "outcome": "success",
    "timestamp": "2026-02-07T15:00:00Z"
  },
  "ema_alpha": 0.1,
  "history": [
    {"date": "2026-02-05", "success_rate": 0.85, "invocations": 12},
    {"date": "2026-02-06", "success_rate": 0.87, "invocations": 20},
    {"date": "2026-02-07", "success_rate": 0.88, "invocations": 15}
  ],
  "per_task_type": {
    "strategy": {"success_rate": 0.92, "invocations": 30},
    "tactic": {"success_rate": 0.82, "invocations": 17}
  }
}
```

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| skill_name | string | Yes | Skill or plugin identifier |
| model_name | string | No | AI model identifier (if model-specific) |
| success_rate | float | Yes | EMA-smoothed success rate [0, 1] |
| selection_weight | float | Yes | Derived routing weight [0.1, 1.0] |
| invocation_count | integer | Yes | Total invocations recorded |
| avg_tokens | integer | No | Average tokens per invocation |
| avg_duration_ms | integer | No | Average execution time |
| last_feedback | object | No | Most recent feedback event |
| ema_alpha | float | Yes | Learning rate (default: 0.1) |
| history | HistoryEntry[] | No | Daily success rate snapshots |
| per_task_type | object | No | Performance breakdown by task type |

### Update Algorithm (FR-018)

```javascript
// After session completes with outcome ∈ {success, failure}
new_success_rate = (1 - ema_alpha) × old_success_rate + ema_alpha × (outcome === "success" ? 1 : 0)
selection_weight = clamp(new_success_rate, 0.1, 1.0)
invocation_count += 1
```

### Validation Rules

- `success_rate` MUST be in range [0, 1]
- `selection_weight` MUST be in range [0.1, 1.0]
- `ema_alpha` MUST be in range (0, 1) (typically 0.1)
- `selection_weight ≈ success_rate` (within ε = 0.05)
- `invocation_count` MUST be ≥ history length

---

## Entity: ScopeAnalysis

Represents the system's classification of a task's scope (tactic vs. strategy) based on input description analysis.

```json
{
  "analysis_id": "scope-20260207-143000-xyz",
  "input_description": "implement OAuth2 authentication with RBAC",
  "detected_scope": "strategy",
  "keyword_scores": {
    "tactic_score": 0.12,
    "strategy_score": 0.88
  },
  "signals": {
    "tactic_keywords": ["fix", "refactor"],
    "strategy_keywords": ["implement", "authentication", "architecture"],
    "file_count_estimate": 15,
    "cross_cutting_concerns": ["security", "database", "api"]
  },
  "confidence": 0.91,
  "override_by_user": null,
  "final_scope": "strategy",
  "timestamp": "2026-02-07T14:30:00Z"
}
```

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| analysis_id | string | Yes | Unique analysis identifier |
| input_description | string | Yes | Original user task description |
| detected_scope | enum | Yes | tactic or strategy |
| keyword_scores | object | Yes | Normalized scores for each scope type |
| signals | object | Yes | Evidence used for classification |
| confidence | float | Yes | Classification confidence [0, 1] |
| override_by_user | enum | No | User-forced scope (tactic or strategy) |
| final_scope | enum | Yes | Effective scope after user override |
| timestamp | ISO8601 | Yes | Analysis timestamp |

### Classification Algorithm (FR-034)

```javascript
// Tactic indicators (quick, localized)
tactic_keywords = ["fix", "bug", "typo", "refactor", "rename", "update", "change"]
tactic_patterns = [/\bREADME\b/, /\btypo\b/, /\bone file\b/]

// Strategy indicators (complex, cross-cutting)
strategy_keywords = ["implement", "add feature", "architecture", "integrate", "design", "create"]
strategy_patterns = [/\bauthentication\b/, /\bmultiple components\b/, /\bnew feature\b/]

// Scoring
tactic_score = count(tactic_keywords + tactic_patterns) / total_indicators
strategy_score = count(strategy_keywords + strategy_patterns) / total_indicators

// File count heuristic
if (estimated_files > 5) { strategy_score += 0.2 }

// Cross-cutting concerns heuristic
if (cross_cutting_concerns.length > 2) { strategy_score += 0.2 }

// Final classification
detected_scope = strategy_score > tactic_score ? "strategy" : "tactic"
confidence = max(strategy_score, tactic_score)
```

### Scope Routing (FR-035, FR-036)

**Tactic Mode** (streamlined):
```
plan → implement → test → grade → [pass: complete | fail: iterate]
```

**Strategy Mode** (full workflow):
```
research → tribunal:research → specify → plan → tribunal:approach → implement → test → grade → [pass: complete | fail: diagnose → iterate]
```

### Validation Rules

- `detected_scope` MUST be either `"tactic"` or `"strategy"`
- `keyword_scores.tactic_score + keyword_scores.strategy_score` ≈ 1.0
- `confidence` MUST be in range [0, 1]
- `final_scope = override_by_user ?? detected_scope`
- If `confidence < 0.6`, system SHOULD prompt user for clarification

---

## Relationships

```
DevLoopSession ──has-many──► QualityGrade (1 per iteration)
DevLoopSession ──has-many──► TribunalBallot (1 per decision point)
DevLoopSession ──has-many──► EventLog (many per iteration)
DevLoopSession ──has-one──► ScopeAnalysis (at session start)
DevLoopSession ──has-one──► TerminationEvent (at session end)
DevLoopSession ──may-create──► PluginManifest (via self-extension)

TribunalBallot ──references──► RLMetrics (per model, for weighting)
PluginManifest ──has-one──► RLMetrics (performance tracking)
EventLog ──contributes-to──► RLMetrics (via feedback extraction)

QualityGrade ──triggers──► TerminationEvent (when threshold met)
```

---

## Data Flow

### Session Initialization
```
User: /dev-loop "task description"
  → Create DevLoopSession
  → Create ScopeAnalysis
  → Set scope_mode (tactic | strategy)
  → Initialize EventLog
```

### Iteration Cycle
```
For each iteration:
  1. Read current state from git
  2. Log "thought" events to EventLog
  3. Execute phase actions (research/plan/implement/test)
  4. Log "action" and "observation" events
  5. Compute QualityGrade
  6. Evaluate termination conditions
  7. If continue: diagnose failures, iterate
  8. If terminate: Create TerminationEvent
```

### Tribunal Decision
```
Decision point triggered:
  → Create TribunalBallot (parallel query to 3 models)
  → Load RLMetrics for each model (get weights)
  → Anonymize claims
  → Aggregate votes (majority or weighted)
  → Record ballot to EventLog
  → Update model RLMetrics based on outcome
```

### Self-Extension
```
Capability gap detected:
  → Create PluginManifest (quarantine:pending)
  → Generate plugin scaffold
  → Run quarantine tests
  → Run constitutional review
  → If passed: quarantine:passed, register plugin
  → If failed: quarantine:failed, report to user
```

### Session Termination
```
Termination condition met:
  → Create TerminationEvent
  → Save checkpoint (if user_interrupt or partial success)
  → Generate session report from EventLog
  → Extract RL feedback signals
  → Update RLMetrics for all skills/models used
  → Mark DevLoopSession.status = complete
```

---

## Storage Locations

| Entity | File Path | Format |
|--------|-----------|--------|
| DevLoopSession | `.devloop/sessions/{session_id}.json` | JSON |
| TribunalBallot | `.devloop/sessions/{session_id}/ballots/{ballot_id}.json` | JSON |
| QualityGrade | `.devloop/sessions/{session_id}/grades/{grade_id}.json` | JSON |
| TerminationEvent | `.devloop/sessions/{session_id}/termination.json` | JSON |
| PluginManifest | `plugins/sdd-tool-{name}/plugin.json` | JSON |
| EventLog | `.devloop/sessions/{session_id}/events.jsonl` | JSONL (append-only) |
| RLMetrics | `.docs/rl-metrics/plugin-performance.json` | JSON (merged) |
| ScopeAnalysis | `.devloop/sessions/{session_id}/scope.json` | JSON |

---

## Indexes and Queries

### Session Lookup
```sql
-- All sessions for a feature branch
SELECT * FROM DevLoopSession WHERE branch = 'feature/oauth2-auth'

-- Sessions by termination reason
SELECT * FROM DevLoopSession WHERE termination_reason = 'success'

-- Sessions exceeding budget threshold
SELECT * FROM DevLoopSession WHERE budget_spent.cost_usd > 10.00
```

### Quality Trajectory
```sql
-- Quality progression for a session
SELECT iteration, composite_grade, passed_threshold
FROM QualityGrade
WHERE session_id = 'devloop-20260207-143022-abc123'
ORDER BY iteration ASC
```

### Tribunal Performance
```sql
-- Model accuracy in tribunal votes
SELECT model_id, AVG(CASE WHEN verdict = expected_outcome THEN 1 ELSE 0 END) as accuracy
FROM TribunalBallot
GROUP BY model_id
```

### Event Replay
```sql
-- All events for an iteration
SELECT event_type, content, metadata, timestamp
FROM EventLog
WHERE session_id = 'devloop-20260207-143022-abc123' AND iteration = 3
ORDER BY timestamp ASC
```

---

## Migration Considerations

### Backward Compatibility
- RLMetrics schema extends existing `.docs/rl-metrics/skill-performance.json`
- PluginManifest schema is backward-compatible with existing plugins (new fields optional)
- EventLog is a new capability (no existing data to migrate)

### Versioning
- DevLoopSession schema versioned via `schema_version: "1.0"`
- Breaking changes require new schema version and migration script
- All JSON files include `schema_version` field for forward compatibility

---
