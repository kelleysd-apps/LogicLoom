#!/usr/bin/env bash
# Integration Tests: sdd-dev-loop End-to-End (Tactic Mode)
# Validates plugin structure, config, lib sourcing, session init,
# grading engine, termination engine, and event logger.
set -euo pipefail

PASS=0; FAIL=0; TOTAL=0
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
TEMP_DIR=""

# ──────────────────────────────────────────────────────
# Assert helper
# ──────────────────────────────────────────────────────
assert() {
  TOTAL=$((TOTAL + 1))
  local desc="$1"; local condition="$2"
  if eval "$condition"; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# ──────────────────────────────────────────────────────
# Setup: create temp workspace with git repo
# ──────────────────────────────────────────────────────
setup() {
  TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/devloop-test-XXXXXX")
  cd "$TEMP_DIR"
  git init --quiet
  git config user.email "test@test.com"
  git config user.name "Test"
  echo '{}' > package.json
  git add . && git commit -m "init" --quiet
}

# ──────────────────────────────────────────────────────
# Cleanup
# ──────────────────────────────────────────────────────
cleanup() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

echo ""
echo "=== sdd-dev-loop Integration Tests ==="
echo ""

# ──────────────────────────────────────────────────────
# Test 1: Plugin directory structure
# ──────────────────────────────────────────────────────
echo "Plugin Directory Structure"
assert "plugin root exists" "[ -d '$PLUGIN_DIR' ]"
assert ".claude-plugin/plugin.json exists" "[ -f '$PLUGIN_DIR/.claude-plugin/plugin.json' ]"
assert "agents/ directory exists" "[ -d '$PLUGIN_DIR/agents' ]"
assert "skills/ directory exists" "[ -d '$PLUGIN_DIR/skills' ]"
assert "skills/core-loop/ exists" "[ -d '$PLUGIN_DIR/skills/core-loop' ]"
assert "lib/ directory exists" "[ -d '$PLUGIN_DIR/lib' ]"
assert "config/ directory exists" "[ -d '$PLUGIN_DIR/config' ]"
assert "tests/ directory exists" "[ -d '$PLUGIN_DIR/tests' ]"
assert "tests/contract/ exists" "[ -d '$PLUGIN_DIR/tests/contract' ]"
assert "tests/integration/ exists" "[ -d '$PLUGIN_DIR/tests/integration' ]"
assert "templates/ directory exists" "[ -d '$PLUGIN_DIR/templates' ]"
assert "commands/ directory exists" "[ -d '$PLUGIN_DIR/commands' ]"

echo ""

# ──────────────────────────────────────────────────────
# Test 2: Config files are valid JSON
# ──────────────────────────────────────────────────────
echo "Config File Validation"
for config_file in "$PLUGIN_DIR"/config/*.json; do
  fname=$(basename "$config_file")
  assert "$fname is valid JSON" "python3 -c 'import json; json.load(open(\"$config_file\"))' 2>/dev/null"
done

assert "plugin.json is valid JSON" "python3 -c 'import json; json.load(open(\"$PLUGIN_DIR/.claude-plugin/plugin.json\"))' 2>/dev/null"

echo ""

# ──────────────────────────────────────────────────────
# Test 3: Lib files are sourceable
# ──────────────────────────────────────────────────────
echo "Lib File Sourcing"

# Check each lib file exists and can be sourced without error
if [ -f "$PLUGIN_DIR/lib/scope-detector.sh" ]; then
  assert "scope-detector.sh is sourceable" "bash -c 'source $PLUGIN_DIR/lib/scope-detector.sh' 2>/dev/null"
  assert "scope-detector.sh defines analyze_scope" "bash -c 'source $PLUGIN_DIR/lib/scope-detector.sh && type analyze_scope' 2>/dev/null"
else
  assert "scope-detector.sh exists" "false"
fi

if [ -f "$PLUGIN_DIR/lib/grading-engine.sh" ]; then
  assert "grading-engine.sh is sourceable" "bash -c 'source $PLUGIN_DIR/lib/grading-engine.sh' 2>/dev/null"
  assert "grading-engine.sh defines normalize_metric" "bash -c 'source $PLUGIN_DIR/lib/grading-engine.sh && type normalize_metric' 2>/dev/null"
  assert "grading-engine.sh defines compute_composite" "bash -c 'source $PLUGIN_DIR/lib/grading-engine.sh && type compute_composite' 2>/dev/null"
else
  assert "grading-engine.sh exists" "false"
fi

if [ -f "$PLUGIN_DIR/lib/termination-engine.sh" ]; then
  assert "termination-engine.sh is sourceable" "bash -c 'source $PLUGIN_DIR/lib/termination-engine.sh' 2>/dev/null"
  assert "termination-engine.sh defines check_convergence" "bash -c 'source $PLUGIN_DIR/lib/termination-engine.sh && type check_convergence' 2>/dev/null"
  assert "termination-engine.sh defines check_budget" "bash -c 'source $PLUGIN_DIR/lib/termination-engine.sh && type check_budget' 2>/dev/null"
  assert "termination-engine.sh defines save_checkpoint" "bash -c 'source $PLUGIN_DIR/lib/termination-engine.sh && type save_checkpoint' 2>/dev/null"
  assert "termination-engine.sh defines load_checkpoint" "bash -c 'source $PLUGIN_DIR/lib/termination-engine.sh && type load_checkpoint' 2>/dev/null"
else
  assert "termination-engine.sh exists" "false"
fi

if [ -f "$PLUGIN_DIR/lib/event-logger.sh" ]; then
  assert "event-logger.sh is sourceable" "bash -c 'source $PLUGIN_DIR/lib/event-logger.sh' 2>/dev/null"
  assert "event-logger.sh defines init_event_log" "bash -c 'source $PLUGIN_DIR/lib/event-logger.sh && type init_event_log' 2>/dev/null"
  assert "event-logger.sh defines log_event" "bash -c 'source $PLUGIN_DIR/lib/event-logger.sh && type log_event' 2>/dev/null"
  assert "event-logger.sh defines query_events" "bash -c 'source $PLUGIN_DIR/lib/event-logger.sh && type query_events' 2>/dev/null"
  assert "event-logger.sh defines count_events" "bash -c 'source $PLUGIN_DIR/lib/event-logger.sh && type count_events' 2>/dev/null"
else
  assert "event-logger.sh exists" "false"
fi

echo ""

# ──────────────────────────────────────────────────────
# Test 4: Session initialization
# ──────────────────────────────────────────────────────
echo "Session Initialization"
setup

SESSION_ID="test-session-$(date +%s)"
SESSION_DIR="$TEMP_DIR/.devloop/sessions/$SESSION_ID"
mkdir -p "$SESSION_DIR/checkpoints"

# Write a minimal session-state.json
cat > "$SESSION_DIR/session-state.json" <<STATEEOF
{
  "session_id": "$SESSION_ID",
  "status": "running",
  "mode": "tactic",
  "config": {
    "threshold": 0.95,
    "budget_tokens": 500000,
    "max_iterations": 25
  },
  "current_iteration": 0,
  "quality_history": [],
  "resources_consumed": { "tokens": 0, "cost": 0.0 },
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "last_checkpoint": "checkpoint_0"
}
STATEEOF

assert "session directory created" "[ -d '$SESSION_DIR' ]"
assert "session-state.json created" "[ -f '$SESSION_DIR/session-state.json' ]"
assert "session-state.json is valid JSON" "python3 -c 'import json; json.load(open(\"$SESSION_DIR/session-state.json\"))'"
assert "session status is running" "python3 -c 'import json; d=json.load(open(\"$SESSION_DIR/session-state.json\")); assert d[\"status\"]==\"running\"'"
assert "session mode is tactic" "python3 -c 'import json; d=json.load(open(\"$SESSION_DIR/session-state.json\")); assert d[\"mode\"]==\"tactic\"'"
assert "checkpoints directory exists" "[ -d '$SESSION_DIR/checkpoints' ]"

echo ""

# ──────────────────────────────────────────────────────
# Test 5: Grading engine logic
# ──────────────────────────────────────────────────────
echo "Grading Engine"

if [ -f "$PLUGIN_DIR/lib/grading-engine.sh" ]; then
  # Test normalize_metric: test_pass_rate 0.5 -> 0.5
  result=$(bash -c "source '$PLUGIN_DIR/lib/grading-engine.sh' && normalize_metric test_pass_rate 0.5" 2>/dev/null || echo "ERROR")
  assert "normalize_metric test_pass_rate 0.5" "python3 -c 'v=float(\"$result\".strip()); assert abs(v - 0.5) < 0.01, f\"got {v}\"' 2>/dev/null"

  # Test normalize_metric: coverage 85 -> 0.85
  result=$(bash -c "source '$PLUGIN_DIR/lib/grading-engine.sh' && normalize_metric coverage 85" 2>/dev/null || echo "ERROR")
  assert "normalize_metric coverage 85 = 0.85" "python3 -c 'v=float(\"$result\".strip()); assert abs(v - 0.85) < 0.01, f\"got {v}\"' 2>/dev/null"

  # Test compute_composite with known inputs (JSON API)
  # Required keys: test_pass_rate, test_coverage, lint, type_safety, security, build
  metrics='{"test_pass_rate":1.0,"test_coverage":1.0,"lint":1.0,"type_safety":1.0,"security":1.0,"build":1.0}'
  weights='{"test_pass_rate":0.35,"test_coverage":0.20,"lint":0.15,"type_safety":0.15,"security":0.10,"build":0.05}'
  result=$(bash -c "source '$PLUGIN_DIR/lib/grading-engine.sh' && compute_composite --metrics '$metrics' --weights '$weights'" 2>/dev/null || echo '{"composite_grade":0}')
  assert "composite grade all-perfect = 1.0" "python3 -c 'import json; d=json.loads(\"\"\"$result\"\"\"); assert abs(d[\"composite_grade\"] - 1.0) < 0.01' 2>/dev/null"

  # Test compute_composite with mixed inputs
  # expected: 0.8*0.35 + 0.6*0.20 + 1.0*0.15 + 1.0*0.15 + 1.0*0.10 + 1.0*0.05 = 0.85
  metrics='{"test_pass_rate":0.8,"test_coverage":0.6,"lint":1.0,"type_safety":1.0,"security":1.0,"build":1.0}'
  result=$(bash -c "source '$PLUGIN_DIR/lib/grading-engine.sh' && compute_composite --metrics '$metrics' --weights '$weights'" 2>/dev/null || echo '{"composite_grade":0}')
  assert "composite grade mixed = ~0.85" "python3 -c 'import json; d=json.loads(\"\"\"$result\"\"\"); assert 0.84 <= d[\"composite_grade\"] <= 0.86, f\"got {d}\"' 2>/dev/null"

  # Test threshold check: 0.96 >= 0.95 -> passed (exit code 0)
  result=$(bash -c "source '$PLUGIN_DIR/lib/grading-engine.sh' && check_threshold 0.96 0.95" 2>/dev/null) || true
  assert "threshold 0.96 >= 0.95 -> passed" "python3 -c 'import json; d=json.loads(\"\"\"$result\"\"\"); assert d[\"passed\"] == True' 2>/dev/null"

  # Test threshold check: 0.90 < 0.95 -> not passed (exit code 1, use || true)
  result=$(bash -c "source '$PLUGIN_DIR/lib/grading-engine.sh' && check_threshold 0.90 0.95" 2>/dev/null) || true
  assert "threshold 0.90 < 0.95 -> not passed" "python3 -c 'import json; d=json.loads(\"\"\"$result\"\"\"); assert d[\"passed\"] == False' 2>/dev/null"
else
  assert "grading-engine.sh exists (skipping grading tests)" "false"
fi

echo ""

# ──────────────────────────────────────────────────────
# Test 6: Termination engine logic
# ──────────────────────────────────────────────────────
echo "Termination Engine"

if [ -f "$PLUGIN_DIR/lib/termination-engine.sh" ]; then
  # Create a proper session state for termination engine tests
  TERM_SESSION_ID="test-term-$(date +%s)"
  TERM_SESSION_DIR="$TEMP_DIR/.dev-loop/sessions/$TERM_SESSION_ID"
  mkdir -p "$TERM_SESSION_DIR/checkpoints"
  cat > "$TERM_SESSION_DIR/state.json" <<TERMEOF
{
  "session_id": "$TERM_SESSION_ID",
  "status": "running",
  "current_iteration": 5,
  "current_grade": 0.50,
  "quality_threshold": 0.95,
  "quality_history": [0.50],
  "max_iterations": 25,
  "resources_consumed": {"total_tokens": 100000, "total_cost": 2.00},
  "budget": {"tokens": 500000, "cost": 10.00}
}
TERMEOF

  # Test convergence detection: grades that ARE converging (delta < 0.001)
  result=$(bash -c "source '$PLUGIN_DIR/lib/termination-engine.sh' && check_convergence --grades '[0.840, 0.845, 0.846, 0.8465]' --delta 0.001 --consecutive 3" 2>/dev/null) || true
  assert "convergence detected on plateau grades" "python3 -c 'import json; d=json.loads(\"\"\"$result\"\"\"); assert d[\"converged\"] == True' 2>/dev/null"

  # Test convergence: grades NOT converging (exit code 1 = not converged, use || true)
  result=$(bash -c "source '$PLUGIN_DIR/lib/termination-engine.sh' && check_convergence --grades '[0.60, 0.70, 0.80, 0.90]' --delta 0.001 --consecutive 3" 2>/dev/null) || true
  assert "no convergence on improving grades" "python3 -c 'import json; d=json.loads(\"\"\"$result\"\"\"); assert d[\"converged\"] == False' 2>/dev/null"

  # Test budget check: within budget (exit code 1 = within budget, use || true)
  result=$(bash -c "source '$PLUGIN_DIR/lib/termination-engine.sh' && check_budget --session '$TERM_SESSION_ID' --workdir '$TEMP_DIR'" 2>/dev/null) || true
  assert "budget not exhausted (100k/500k)" "python3 -c 'import json; d=json.loads(\"\"\"$result\"\"\"); assert d[\"budget_exhausted\"] == False' 2>/dev/null"

  # Test budget check: exceeded
  OVER_SESSION_ID="test-over-$(date +%s)"
  mkdir -p "$TEMP_DIR/.dev-loop/sessions/$OVER_SESSION_ID"
  cat > "$TEMP_DIR/.dev-loop/sessions/$OVER_SESSION_ID/state.json" <<OVEREOF
{
  "session_id": "$OVER_SESSION_ID", "status": "running", "current_iteration": 10,
  "current_grade": 0.50, "quality_threshold": 0.95, "quality_history": [0.50],
  "max_iterations": 25,
  "resources_consumed": {"total_tokens": 550000, "total_cost": 5.00},
  "budget": {"tokens": 500000, "cost": 10.00}
}
OVEREOF
  result=$(bash -c "source '$PLUGIN_DIR/lib/termination-engine.sh' && check_budget --session '$OVER_SESSION_ID' --workdir '$TEMP_DIR'" 2>/dev/null || echo "ERROR")
  assert "budget exhausted (550k/500k)" "python3 -c 'import json; d=json.loads(\"\"\"$result\"\"\"); assert d[\"budget_exhausted\"] == True' 2>/dev/null"

  # Test checkpoint save/load round-trip
  result=$(bash -c "source '$PLUGIN_DIR/lib/termination-engine.sh' && save_checkpoint --session '$TERM_SESSION_ID' --workdir '$TEMP_DIR' --name 'checkpoint_1'" 2>/dev/null || echo "ERROR")
  CKPT_PATH=$(python3 -c "import json; print(json.loads('''$result''').get('checkpoint_path',''))" 2>/dev/null || true)
  assert "checkpoint file created" "[ -n '$CKPT_PATH' ] && [ -f '$CKPT_PATH' ]"

  if [ -n "$CKPT_PATH" ] && [ -f "$CKPT_PATH" ]; then
    result=$(bash -c "source '$PLUGIN_DIR/lib/termination-engine.sh' && load_checkpoint '$CKPT_PATH'" 2>/dev/null || echo "ERROR")
    assert "checkpoint loads without error" "[ '$result' != 'ERROR' ]"
  fi
else
  assert "termination-engine.sh exists (skipping termination tests)" "false"
fi

echo ""

# ──────────────────────────────────────────────────────
# Test 7: Event logger
# ──────────────────────────────────────────────────────
echo "Event Logger"

if [ -f "$PLUGIN_DIR/lib/event-logger.sh" ]; then
  # Event logger is stateful — init_event_log, log_event, query_events, count_events
  # must run in the same shell. Create a session dir for event tests.
  EVT_SESSION_ID="test-events-$(date +%s)"
  EVT_SESSION_DIR="$TEMP_DIR/.dev-loop/sessions/$EVT_SESSION_ID"
  mkdir -p "$EVT_SESSION_DIR"
  EVENT_LOG="$EVT_SESSION_DIR/events.jsonl"

  # Initialize, log 3 events, and verify — all in one subshell
  bash -c "
    source '$PLUGIN_DIR/lib/event-logger.sh'
    init_event_log '$EVT_SESSION_ID' '$EVT_SESSION_DIR'
    log_event thought 1 'Session started in tactic mode'
    log_event action 1 'Running iteration 1'
    log_event observation 1 'Quality grade: 0.72'
  " 2>/dev/null || true

  assert "event log file created" "[ -f '$EVENT_LOG' ]"
  assert "event log has content" "[ -s '$EVENT_LOG' ]"

  # Count events
  line_count=$(wc -l < "$EVENT_LOG" 2>/dev/null | tr -d ' ')
  assert "event log has 3 entries" "[ '$line_count' -eq 3 ]"

  # Query events by type (stateful — must init first)
  result=$(bash -c "
    source '$PLUGIN_DIR/lib/event-logger.sh'
    init_event_log '$EVT_SESSION_ID' '$EVT_SESSION_DIR'
    query_events --type thought
  " 2>/dev/null || echo "")
  assert "query finds thought event" "echo '$result' | grep -q 'thought'"

  # Count events by type
  result=$(bash -c "
    source '$PLUGIN_DIR/lib/event-logger.sh'
    init_event_log '$EVT_SESSION_ID' '$EVT_SESSION_DIR' >/dev/null
    count_events action
  " 2>/dev/null || echo "0")
  assert "count_events returns 1 for action" "[ '$result' = '1' ]"

  # Verify each line is valid JSON
  all_valid=true
  while IFS= read -r line; do
    if ! echo "$line" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null; then
      all_valid=false
      break
    fi
  done < "$EVENT_LOG"
  assert "all event log entries are valid JSON" "$all_valid"
else
  assert "event-logger.sh exists (skipping event logger tests)" "false"
fi

echo ""

# ──────────────────────────────────────────────────────
# Results summary
# ──────────────────────────────────────────────────────
echo "======================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "======================================="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
