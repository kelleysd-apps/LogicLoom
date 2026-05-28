---
name: dev-loop
description: Recursive autonomous dev-loop with edit-test-debug cycles, multi-model tribunal voting, composite quality grading, and self-extension. Executes autonomously until quality threshold met or termination condition triggered.
model: opus
---

# /dev-loop Command — Recursive Autonomous Development Loop

Autonomous recursive development loop combining research, planning, implementation, testing, quality grading, and iteration with multi-model tribunal voting and self-improvement.

**SKILL ACTIVATION**: This command activates the core-loop skill at `plugins/sdd-dev-loop/skills/core-loop/SKILL.md`

**If you are NOT configured to use this command**, delegate to the dev-loop coordinator agent.

**CONSTITUTIONAL PRINCIPLE VI (Git Approval)**: This command will NOT perform git operations without explicit user approval. All git operations are gated and require per-action confirmation.

---

## Execution Instructions

### Step 1: Parse Arguments and Configuration

Parse command arguments:
```bash
TASK_DESCRIPTION="$1"
THRESHOLD="${2:-0.95}"
BUDGET="${3:-500000}"
MAX_ITERATIONS="${4:-25}"
MODE="${5:-auto}"
RESUME="${6:-false}"
```

**Options:**

| Option | Type | Default | Range | Description |
|--------|------|---------|-------|-------------|
| `--threshold` | float | 0.95 | 0.80-0.99 | Quality threshold for success (composite grade) |
| `--budget` | integer | 500000 | unlimited | Token budget limit (hard circuit breaker) |
| `--max-iterations` | integer | 25 | 10-50 | Maximum iteration safety backstop |
| `--mode` | enum | auto | tactic\|strategy\|auto | Execution mode (tactic=streamlined, strategy=full workflow, auto=detect) |
| `--resume` | string | false | session_id | Resume from checkpoint (session ID) |

**Usage Examples:**

```bash
# Basic invocation with defaults
/dev-loop "implement OAuth2 authentication with RBAC"

# Custom quality threshold and budget
/dev-loop "add input validation to user registration" --threshold 0.90 --budget 300000

# Force tactic mode for quick fix
/dev-loop "fix typo in README" --mode tactic

# Resume interrupted session
/dev-loop --resume devloop-20260207-143022-abc123

# Strategic feature with extended budget
/dev-loop "implement real-time WebSocket notification system" --mode strategy --budget 1000000 --max-iterations 40
```

### Step 2: Scope Detection (if mode=auto)

**Activate**: `plugins/sdd-dev-loop/skills/scope-detection/SKILL.md`

Analyze task description to classify as tactic (small, focused) or strategy (large, cross-cutting):

```bash
SCOPE_ANALYSIS=$(analyze_scope "$TASK_DESCRIPTION")
DETECTED_SCOPE=$(echo "$SCOPE_ANALYSIS" | jq -r '.detected_scope')
CONFIDENCE=$(echo "$SCOPE_ANALYSIS" | jq -r '.confidence')
```

**Tactic Indicators**:
- Keywords: fix, bug, typo, refactor, rename, update, change
- Patterns: README, single file, documentation
- Estimated files: ≤ 5

**Strategy Indicators**:
- Keywords: implement, add feature, architecture, integrate, design, create
- Patterns: authentication, multiple components, new feature
- Estimated files: > 5
- Cross-cutting concerns: > 2 domains

If `confidence < 0.6`, prompt user for clarification before proceeding.

Store scope analysis:
```bash
echo "$SCOPE_ANALYSIS" > "$RESEARCH_DIR/scope.json"
```

### Step 3: Session Setup

**Activate**: `plugins/sdd-dev-loop/skills/session-manager/SKILL.md`

Initialize or restore session state:

**New Session:**
```bash
SESSION_ID="devloop-$(date +%Y%m%d-%H%M%S)-$(head -c 6 /dev/urandom | base64 | tr -dc 'a-z0-9')"
RESEARCH_DIR=".devloop/sessions/$SESSION_ID"
mkdir -p "$RESEARCH_DIR/ballots" "$RESEARCH_DIR/grades"

# Create session from template
cp plugins/sdd-dev-loop/templates/session-state.json "$RESEARCH_DIR/session.json"

# Populate initial values
jq --arg id "$SESSION_ID" \
   --arg desc "$TASK_DESCRIPTION" \
   --arg mode "$FINAL_SCOPE" \
   --argjson threshold "$THRESHOLD" \
   '.session_id = $id | .feature_description = $desc | .scope_mode = $mode | .config.quality_threshold = $threshold' \
   "$RESEARCH_DIR/session.json" > "$RESEARCH_DIR/session.tmp" && mv "$RESEARCH_DIR/session.tmp" "$RESEARCH_DIR/session.json"
```

**Resume Session:**
```bash
SESSION_ID="$RESUME"
RESEARCH_DIR=".devloop/sessions/$SESSION_ID"

if [ ! -f "$RESEARCH_DIR/session.json" ]; then
  echo "ERROR: Session $SESSION_ID not found"
  exit 1
fi

# Load session state
SESSION_STATE=$(cat "$RESEARCH_DIR/session.json")
ITERATION_COUNT=$(echo "$SESSION_STATE" | jq -r '.iteration_count')
echo "Resuming session $SESSION_ID from iteration $ITERATION_COUNT"
```

### Step 4: Main Loop Execution

**Activate**: `plugins/sdd-dev-loop/skills/core-loop/SKILL.md`

Execute the recursive dev-loop following the workflow determined by scope mode:

**Tactic Mode** (streamlined):
```
plan → implement → test → grade → [pass: complete | fail: iterate]
```

**Strategy Mode** (full workflow):
```
research → tribunal:research → specify → plan → tribunal:approach →
implement → test → grade → [pass: complete | fail: diagnose → iterate]
```

**Core Loop Pattern** (FR-001):
```bash
while true; do
  ITERATION=$((ITERATION + 1))

  # 1. Fresh context: read current state from git
  git status
  git diff

  # 2. Execute phase actions (varies by scope mode)
  if [ "$SCOPE_MODE" = "strategy" ]; then
    # Full workflow with tribunal checkpoints
    execute_research
    execute_tribunal_vote "research"
    execute_specification
    execute_plan
    execute_tribunal_vote "approach"
  else
    # Streamlined tactic workflow
    execute_plan
  fi

  # 3. Implement changes
  execute_implementation

  # 4. Run tests
  execute_tests
  TEST_RESULTS=$?

  # 5. Compute quality grade
  compute_quality_grade
  COMPOSITE_GRADE=$(get_latest_grade)

  # 6. Evaluate termination conditions (FR-022)
  evaluate_termination
  TERMINATION_REASON=$?

  if [ "$TERMINATION_REASON" != "continue" ]; then
    break
  fi

  # 7. Diagnose failures and iterate
  execute_diagnosis
done
```

**Event Sourcing** (FR-043):
All thoughts, actions, observations, decisions, and tool invocations logged to:
```bash
.devloop/sessions/$SESSION_ID/events.jsonl
```

### Step 5: Multi-Layer Termination Evaluation (FR-022)

Evaluate termination conditions in priority order:

```bash
function evaluate_termination() {
  # Layer 1: Success threshold met (FR-016)
  if [ "$(echo "$COMPOSITE_GRADE >= $THRESHOLD" | bc)" -eq 1 ]; then
    create_termination_event "success"
    return 0
  fi

  # Layer 2: Convergence detected (FR-023)
  CONVERGENCE=$(check_convergence "$SESSION_ID")
  if [ "$CONVERGENCE" = "true" ]; then
    create_termination_event "converged"
    return 0
  fi

  # Layer 3: Budget exhausted (FR-025)
  BUDGET_USED=$(get_cumulative_tokens "$SESSION_ID")
  if [ "$BUDGET_USED" -ge "$BUDGET" ]; then
    create_termination_event "budget_exhausted"
    return 0
  fi

  # Layer 4: Max iterations reached (FR-024)
  if [ "$ITERATION" -ge "$MAX_ITERATIONS" ]; then
    create_termination_event "max_iterations"
    return 0
  fi

  # Layer 5: Stuck/oscillation detected (FR-026)
  STUCK=$(detect_stuck_state "$SESSION_ID")
  if [ "$STUCK" = "true" ]; then
    create_termination_event "stuck"
    return 0
  fi

  # Layer 6: User interrupt (FR-028)
  if [ -f "$RESEARCH_DIR/.interrupt" ]; then
    create_termination_event "user_interrupt"
    return 0
  fi

  echo "continue"
  return 1
}
```

### Step 6: Session Report Generation

**Activate**: `plugins/sdd-dev-loop/skills/report-generator/SKILL.md`

Generate comprehensive session report (FR-044):

```bash
generate_session_report "$SESSION_ID" > "$RESEARCH_DIR/report.md"
```

**Report Contents:**
- Session metadata (ID, task description, scope mode)
- Iteration count and quality grade trajectory
- All tribunal ballots and decisions
- Total tokens consumed per model
- Total cost (USD)
- Wall-clock time elapsed
- Code changes summary (files modified, lines changed)
- Termination reason and trigger values
- RL feedback recorded
- Full event log (append or reference)

### Step 7: RL Feedback Collection (FR-018)

Update performance metrics for all skills and models used:

```bash
# Extract outcome from termination
OUTCOME="success"  # or "failure"
if [ "$TERMINATION_REASON" = "success" ]; then
  OUTCOME="success"
else
  OUTCOME="failure"
fi

# Update RL metrics
.logic-loom/scripts/bash/rl/collect-feedback.sh "core-loop" "$OUTCOME" "$TOKENS_USED"
.logic-loom/scripts/bash/rl/sync-metrics.sh
```

---

## Output Files

All session artifacts stored in:
```
.devloop/sessions/$SESSION_ID/
  session.json              # DevLoopSession state
  scope.json                # ScopeAnalysis result
  events.jsonl              # EventLog (append-only)
  report.md                 # Session report
  ballots/                  # TribunalBallot files
    ballot-*.json
  grades/                   # QualityGrade files
    grade-*.json
  termination.json          # TerminationEvent
  checkpoint.json           # Resumable checkpoint (if interrupted)
```

**Session State Schema**: `plugins/sdd-dev-loop/templates/session-state.json`

**Quality Grade Schema**: `plugins/sdd-dev-loop/templates/quality-grade.json`

**Termination Event Schema**: `plugins/sdd-dev-loop/templates/termination-event.json`

---

## Safety and Sandboxing (FR-029 through FR-033)

**Tiered Permission Model** (FR-030):

| Level | Operations | Default |
|-------|------------|---------|
| L0 | Read workspace files | Always permitted |
| L1 | Write workspace files, run tests | Permitted by default |
| L2 | Git commit on current branch, network to allowlist | Requires per-session approval |
| L3 | Git push, deploy actions, credential access | Requires per-action approval |

**Git Operations Gating** (FR-031, FR-032):
- Branch operations (create, switch, delete) are BLOCKED during autonomous execution
- Push operations require explicit user approval (Constitutional Principle VI)
- All git operations logged to event stream

**Resource Limits** (FR-033):
- Processing time: 300s per iteration
- Memory: 4GB per sandbox
- Disk: Workspace only (no system access)

---

## Tribunal Voting (FR-006 through FR-011)

**Activation**: Multi-model tribunal invoked at key decision points:
1. Research synthesis
2. Implementation approach selection
3. Quality disputes

**Parallel Execution** (FR-010):
Query all 3 models simultaneously:
```bash
query_model_async "claude-opus-4-6" "$DECISION_POINT" &
PID_CLAUDE=$!

query_model_async "gpt-4" "$DECISION_POINT" &
PID_GPT=$!

query_model_async "gemini-2.0-flash-thinking-exp" "$DECISION_POINT" &
PID_GEMINI=$!

# Wait for all (max 60s timeout)
wait $PID_CLAUDE $PID_GPT $PID_GEMINI
```

**Anonymous Review** (FR-007):
Model identities anonymized during peer review until after voting complete.

**EMA-Weighted Voting** (FR-009):
Votes weighted by historical reliability scores from `.docs/rl-metrics/plugin-performance.json`

**Degraded Mode** (FR-011):
If 1 model unavailable, continue with 2-of-2 consensus. If 2+ unavailable, halt and request user guidance.

---

## Quality Grading (FR-012 through FR-017)

**Composite Grade Calculation** (FR-012):
```
composite_grade = Σ(normalized_score[metric] × weight[metric])
```

**Metrics** (FR-013):
- Test pass rate (weight: 0.35)
- Test coverage (weight: 0.20)
- Lint compliance (weight: 0.15)
- Type safety (weight: 0.15)
- Security scan (weight: 0.10)
- Build success (weight: 0.05)

**Default Threshold**: 0.95 (configurable 0.80-0.99)

**AI Semantic Evaluation** (FR-017):
Supplement automated metrics with AI assessment of readability, architectural soundness, and specification compliance.

---

## Self-Extension (FR-038 through FR-042)

**Capability Gap Detection**:
System monitors for recurring inefficiencies or missing tools during execution.

**Plugin Creation**:
When gap detected, system generates new plugin using `/create-plugin` workflow.

**Quarantine Validation** (FR-040):
New plugins tested in isolation:
- Unit tests (≥80% coverage)
- Security scan (zero critical/high)
- Access restrictions validated
- Constitutional review passed (FR-041)

**Dynamic Registration** (FR-042):
Validated plugins registered immediately without restart.

---

## Checkpoint and Resume (FR-028)

**Interrupt Handling**:
- User sends interrupt signal (Ctrl+C or SIGINT)
- System pauses within 5 seconds
- Full session state saved to checkpoint
- Progress summary displayed
- Options: resume, adjust parameters, terminate

**Resume**:
```bash
/dev-loop --resume devloop-20260207-143022-abc123
```

Restores:
- Iteration count
- Quality grade history
- Budget consumed
- Event log
- Current phase

---

## Integration Points

**SDD Framework Dependencies**:
- Constitutional Governance (Principle VI, X)
- RL Metrics System (`.docs/rl-metrics/`)
- Plugin Architecture (manifest conventions)
- Specification Workflow (for strategy mode)

**MCP Servers** (optional enhancements):
- Testing frameworks via MCP
- Security scanners via MCP
- Deployment tools via MCP

---

## Error Handling

**Unrecoverable Errors**:
- All tribunal models unavailable → save checkpoint, notify user
- Sandbox isolation breach → halt immediately, report security incident
- Corrupted session state → attempt recovery from event log, fallback to user guidance

**Recoverable Errors**:
- Single test failure → diagnose and iterate
- Quality grade below threshold → iterate with improvements
- Single model unavailable → continue with 2-model tribunal

---

## Constitutional Compliance

This command enforces:
- **Principle II (Test-First)**: TDD mandatory, >80% coverage validated in quality grading
- **Principle VI (Git Approval)**: NO autonomous git push operations
- **Principle X (Agent Delegation)**: Specialized work delegated to domain agents
- **Principle XVI (Plugin-First)**: All capabilities as plugins

Pre-flight check executed before session start. Violations halt execution.

---

**Framework**: logic-loom v5.0.0
**Plugin**: sdd-dev-loop v0.1.0
**Spec Reference**: `specs/feature-sdd-dev-loop/spec.md`
**Data Model**: `specs/feature-sdd-dev-loop/data-model.md`
