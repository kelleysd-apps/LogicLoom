# Quickstart: sdd-dev-loop — Recursive Autonomous Dev-Loop Plugin

**Branch**: `feature-sdd-dev-loop` | **Date**: 2026-02-07

This quickstart provides a validation guide for verifying the sdd-dev-loop plugin's core functionality: recursive edit-test-debug cycles with multi-model tribunal voting, composite quality grading, and intelligent termination.

---

## Prerequisites

- **API keys configured**: `.env` file with `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY` (for tribunal voting)
- **Docker running**: Required for sandboxed execution (Phase 3)
- **SDD framework installed**: Plugin-first architecture v4.1 or later
- **Test suite available**: Project has automated tests that can be executed programmatically
- **Git repository initialized**: Project under development has version control set up

---

## Quick Validation Steps

### Step 1: Verify Plugin Structure

```bash
# Check plugin directory exists
ls -la plugins/sdd-dev-loop/

# Expected structure:
# plugins/sdd-dev-loop/
#   .claude-plugin/
#     plugin.json           # Plugin manifest
#     hooks.json            # Dev-loop hooks
#   agents/
#     dev-loop-orchestrator.md
#   skills/
#     dev-loop-core/
#     tribunal-voting/
#     quality-grading/
#     scope-detection/
#     rl-feedback/
#   scripts/
#     dev-loop.sh           # Main entry point
#     quality-grade.sh      # Composite grading
#     tribunal-vote.sh      # Multi-model voting
#     scope-detect.sh       # Tactic vs strategy
#     termination-check.sh  # 6-layer termination
#   tests/                  # Plugin test suite
```

```bash
# Verify plugin manifest
cat plugins/sdd-dev-loop/.claude-plugin/plugin.json

# Expected fields:
# - name: "sdd-dev-loop"
# - version: "0.1.0"
# - description: "Recursive autonomous development loop..."
# - rl_metrics: {...}
# - requires: ["sdd-governance", "sdd-specification"]
```

### Step 2: Basic Dev-Loop Invocation

```bash
# Create a simple test file to work with
echo 'export function add(a, b) { return a + b; }' > src/example.js

# Invoke the dev-loop with a simple task
/dev-loop "Add input validation to the add function to ensure both arguments are numbers, with comprehensive tests"
```

**Expected behavior**:
1. System classifies task as "tactic" mode (scope detection)
2. Enters edit-test-debug loop:
   - Research: Analyzes current code state
   - Plan: Creates streamlined implementation plan
   - Implement: Adds validation logic
   - Test: Runs test suite
   - Grade: Computes composite quality score
3. Iterates until quality threshold met (default 0.95) or convergence detected
4. Outputs final session report with:
   - Total iterations
   - Quality grade trajectory
   - Token usage and cost
   - Termination reason

### Step 3: Verify Tribunal Voting

```bash
# Invoke dev-loop with a task requiring tribunal decision
/dev-loop "Implement caching strategy for API responses" --mode strategy
```

**Expected behavior**:
1. System detects "strategy" mode task
2. Calls tribunal at key checkpoints:
   - Initial research synthesis
   - Implementation approach selection
   - Quality dispute resolution (if needed)
3. Tribunal process:
   - Queries 3 AI models in parallel (OpenAI, Anthropic, Google)
   - Anonymizes model identities during review
   - Applies majority voting (2-of-3 agreement)
   - Weights votes by historical reliability (EMA)

**Validation**:
```bash
# Check tribunal ballot file created
ls -la .docs/dev-loop-sessions/*/tribunal-ballots/

# Expected: JSON file with structure:
# {
#   "decision_point": "implementation_approach",
#   "assessments": [
#     {"model_id": "model_1", "vote": "approve", "confidence": 0.85},
#     {"model_id": "model_2", "vote": "approve", "confidence": 0.92},
#     {"model_id": "model_3", "vote": "reject", "confidence": 0.78}
#   ],
#   "result": "approved",
#   "ema_weights": [0.88, 0.91, 0.83]
# }
```

### Step 4: Verify Quality Grading

```bash
# Check session report for quality grade details
cat .docs/dev-loop-sessions/*/session-report.json
```

**Expected quality grade structure**:
```json
{
  "iteration_3": {
    "raw_metrics": {
      "test_pass_rate": 1.0,
      "test_coverage": 0.87,
      "lint_errors": 0,
      "type_errors": 0,
      "security_vulnerabilities": 0,
      "build_success": true
    },
    "normalized_scores": {
      "test_pass_rate": 1.0,
      "test_coverage": 0.87,
      "lint_compliance": 1.0,
      "type_safety": 1.0,
      "security": 1.0,
      "build": 1.0
    },
    "weights": {
      "test_pass_rate": 0.35,
      "test_coverage": 0.20,
      "lint_compliance": 0.15,
      "type_safety": 0.15,
      "security": 0.10,
      "build": 0.05
    },
    "composite_grade": 0.96
  }
}
```

**Validation**:
- [ ] Each metric normalized to 0-1 scale
- [ ] Test pass rate weighted most heavily (35%)
- [ ] Composite score calculated correctly: Σ(normalized_score × weight)
- [ ] Threshold comparison performed (grade >= 0.95)

### Step 5: Verify Termination Layers

Test each termination condition:

**A. Success threshold met**:
```bash
/dev-loop "Add a simple console.log statement" --threshold 0.90
# Expected: Exits with "success" status when grade >= 0.90
```

**B. Convergence detected**:
```bash
/dev-loop "Optimize performance of sort algorithm" --threshold 0.99
# Expected: Exits with "converged" status when grade delta < 0.001 for 3 iterations
# Example trajectory: [0.88, 0.91, 0.925, 0.927, 0.928] → converged
```

**C. Budget exhausted**:
```bash
/dev-loop "Complex refactoring task" --token-limit 100000
# Expected: Exits with "budget exhausted" when cumulative tokens >= 100000
```

**D. Max iterations reached**:
```bash
/dev-loop "Impossible task" --max-iterations 10
# Expected: Exits with "max iterations" after 10 iterations
```

**E. Stuck detection**:
```bash
# Artificially create a failing test that cannot be fixed
# Expected: System detects repeated failure after 3 iterations, triggers tribunal re-evaluation
```

**F. User interrupt**:
```bash
/dev-loop "Long-running task"
# Press Ctrl+C after 2 iterations
# Expected: Pauses within 5 seconds, saves checkpoint, presents summary
```

### Step 6: Verify Scope Detection

**Tactic mode (small task)**:
```bash
/dev-loop "Fix typo in README" --auto-scope
# Expected: Classified as "tactic", skips full specification workflow
# Output: "Scope: tactic (streamlined cycle)"
```

**Strategy mode (large task)**:
```bash
/dev-loop "Implement OAuth2 authentication with RBAC" --auto-scope
# Expected: Classified as "strategy", engages full /specification workflow
# Output: "Scope: strategy (full research → specify → plan → implement)"
```

**Manual override**:
```bash
/dev-loop "Add logging" --mode strategy
# Expected: Forces strategy mode regardless of scope analysis
```

### Step 7: Verify Event Sourcing

```bash
# Check event log created
cat .docs/dev-loop-sessions/*/event-log.jsonl

# Expected: JSONL file with structured events
# {"timestamp": "2026-02-07T14:23:45Z", "type": "thought", "iteration": 1, "payload": {...}}
# {"timestamp": "2026-02-07T14:23:47Z", "type": "action", "iteration": 1, "payload": {...}}
# {"timestamp": "2026-02-07T14:23:50Z", "type": "observation", "iteration": 1, "payload": {...}}
# {"timestamp": "2026-02-07T14:23:52Z", "type": "grade", "iteration": 1, "payload": {...}}
```

**Validation**:
- [ ] Every significant event logged (thoughts, actions, observations, grades, votes)
- [ ] Events include iteration number and timestamp
- [ ] Session replay possible from event log

### Step 8: Verify RL Feedback Integration

```bash
# Run a successful dev-loop session
/dev-loop "Add unit tests for user validation"

# Check RL metrics updated
cat .docs/rl-metrics/skill-performance.json | jq '.skills["dev-loop-core"]'

# Expected output:
# {
#   "success_rate": 0.92,          # EMA-updated
#   "selection_weight": 0.92,      # Derived from success_rate
#   "invocation_count": 15,        # Incremented
#   "avg_tokens": 45000,           # Running average
#   "last_updated": "2026-02-07T14:30:00Z"
# }
```

**Validation**:
- [ ] Success rate updated using EMA (alpha=0.1)
- [ ] Selection weight clamped to [0.1, 1.0]
- [ ] Invocation count incremented
- [ ] Average token consumption updated

---

## Validation Checklist

### Plugin Installation
- [ ] Plugin directory structure matches expected layout
- [ ] Plugin manifest (plugin.json) includes all required fields
- [ ] Plugin installs cleanly via `claude plugin install`
- [ ] Command `/dev-loop` accessible after installation

### Core Functionality
- [ ] Basic dev-loop invocation completes successfully
- [ ] Edit-test-debug cycle executes (research → plan → implement → test → grade)
- [ ] Quality grading produces composite score
- [ ] Iterations continue until termination condition met

### Tribunal Voting (Phase 2)
- [ ] Three AI models queried in parallel for tribunal decisions
- [ ] Model identities anonymized during review
- [ ] Majority voting (2-of-3) produces verdict
- [ ] Tribunal ballot file created with full voting record
- [ ] EMA-adjusted weights applied to votes

### Quality Grading
- [ ] All quality metrics collected (test pass rate, coverage, lint, type safety, security, build)
- [ ] Each metric normalized to 0-1 scale
- [ ] Composite score calculated with correct weights (test pass rate: 35%)
- [ ] Threshold comparison performed accurately

### Termination Layers
- [ ] Success threshold termination works (grade >= threshold)
- [ ] Convergence detection works (delta < 0.001 for 3 iterations)
- [ ] Budget circuit breaker fires when token limit reached
- [ ] Max iterations backstop prevents infinite loops
- [ ] Stuck detection triggers after repeated failures
- [ ] User interrupt saves checkpoint and pauses execution

### Scope Detection
- [ ] Tactic mode classification for small tasks (skips full specification)
- [ ] Strategy mode classification for large tasks (full workflow)
- [ ] Manual override flag (`--mode`) works correctly
- [ ] Scope analysis completes within 5 seconds

### Event Sourcing & Reporting
- [ ] Event log file created in JSONL format
- [ ] All significant events logged with timestamps and iteration numbers
- [ ] Session report generated with comprehensive metrics
- [ ] Session replay possible from event log

### RL Feedback
- [ ] skill-performance.json updated after session completion
- [ ] EMA calculation correct (alpha=0.1)
- [ ] Selection weight derived from success rate
- [ ] Integration with existing SDD RL metrics system works

### Safety (Phase 3 - Future)
- [ ] Sandboxed execution restricts agent to project workspace
- [ ] Tiered permission model enforced (L0-L3)
- [ ] Git push operations require explicit user approval
- [ ] Resource limits enforced on execution

---

## Common Issues

**Issue**: Tribunal voting fails with "API key not found"
**Solution**: Verify all three API keys configured in `.env`: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`

**Issue**: Quality grading returns 0.0
**Solution**: Ensure project has automated tests that can be executed. Check test runner configuration.

**Issue**: Dev-loop exits immediately with "converged"
**Solution**: This is expected if the first iteration already meets quality threshold. Lower threshold or provide more complex task.

**Issue**: Checkpoint save fails on interrupt
**Solution**: Check write permissions on `.docs/dev-loop-sessions/` directory.

---

## Next Steps

After validating basic functionality:

1. **Test Phase 2 (Tribunal)**: Run multiple sessions and validate tribunal decision quality
2. **Test Phase 3 (Safety)**: Verify sandboxed execution with Docker container
3. **Test Phase 4 (Intelligence)**: Validate scope detection accuracy across diverse tasks
4. **Test Phase 5 (Observability)**: Use session replay to debug failed iterations
5. **Test Phase 6 (Self-Extension)**: Trigger capability gap detection and plugin self-creation

---

**Plugin**: sdd-dev-loop v0.1.0
**Framework**: sdd-agentic-framework v4.1+
**Last Updated**: 2026-02-07
