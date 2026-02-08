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
  assert "grading-engine.sh defines compute_composite_grade" "bash -c 'source $PLUGIN_DIR/lib/grading-engine.sh && type compute_composite_grade' 2>/dev/null"
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
  # Test normalize_metric: 5 passed out of 10 -> 0.5
  result=$(bash -c "source '$PLUGIN_DIR/lib/grading-engine.sh' && normalize_metric ratio 5 10" 2>/dev/null || echo "ERROR")
  assert "normalize_metric ratio 5/10 = 0.5" "[ '$result' = '0.50' ] || [ '$result' = '0.5' ] || [ '$result' = '.50' ]"

  # Test normalize_metric: 0 errors -> 1.0 (inverse)
  result=$(bash -c "source '$PLUGIN_DIR/lib/grading-engine.sh' && normalize_metric inverse 0 50" 2>/dev/null || echo "ERROR")
  assert "normalize_metric inverse 0 errors = 1.0" "[ '$result' = '1.00' ] || [ '$result' = '1.0' ] || [ '$result' = '1' ]"

  # Test compute_composite_grade with known inputs
  # metrics: all 1.0, weights: default -> should produce 1.0
  result=$(bash -c "source '$PLUGIN_DIR/lib/grading-engine.sh' && compute_composite_grade 1.0 1.0 1.0 1.0 1.0 1.0 0.35 0.20 0.15 0.15 0.10 0.05" 2>/dev/null || echo "ERROR")
  assert "composite grade all-perfect = 1.0" "[ '$result' = '1.00' ] || [ '$result' = '1.0' ] || [ '$result' = '1' ]"

  # Test compute_composite_grade with mixed inputs
  # metrics: 0.8 0.6 1.0 1.0 1.0 1.0, weights: default
  # expected: 0.8*0.35 + 0.6*0.20 + 1.0*0.15 + 1.0*0.15 + 1.0*0.10 + 1.0*0.05 = 0.28+0.12+0.15+0.15+0.10+0.05 = 0.85
  result=$(bash -c "source '$PLUGIN_DIR/lib/grading-engine.sh' && compute_composite_grade 0.8 0.6 1.0 1.0 1.0 1.0 0.35 0.20 0.15 0.15 0.10 0.05" 2>/dev/null || echo "ERROR")
  assert "composite grade mixed = ~0.85" "echo '$result' | python3 -c 'import sys; v=float(sys.stdin.read().strip()); assert 0.84 <= v <= 0.86, f\"got {v}\"' 2>/dev/null"

  # Test threshold check
  result=$(bash -c "source '$PLUGIN_DIR/lib/grading-engine.sh' && check_threshold 0.96 0.95" 2>/dev/null || echo "ERROR")
  assert "threshold 0.96 >= 0.95 -> met" "[ '$result' = 'met' ] || [ '$result' = 'true' ] || [ '$result' = '1' ]"

  result=$(bash -c "source '$PLUGIN_DIR/lib/grading-engine.sh' && check_threshold 0.90 0.95" 2>/dev/null || echo "ERROR")
  assert "threshold 0.90 < 0.95 -> not met" "[ '$result' = 'not_met' ] || [ '$result' = 'false' ] || [ '$result' = '0' ]"
else
  assert "grading-engine.sh exists (skipping grading tests)" "false"
fi

echo ""

# ──────────────────────────────────────────────────────
# Test 6: Termination engine logic
# ──────────────────────────────────────────────────────
echo "Termination Engine"

if [ -f "$PLUGIN_DIR/lib/termination-engine.sh" ]; then
  # Test convergence detection: grades that ARE converging (delta < 0.001)
  result=$(bash -c "source '$PLUGIN_DIR/lib/termination-engine.sh' && check_convergence '0.840 0.845 0.846 0.8465' 0.001 3" 2>/dev/null || echo "ERROR")
  assert "convergence detected on plateau grades" "[ '$result' = 'converged' ] || [ '$result' = 'true' ] || [ '$result' = '1' ]"

  # Test convergence: grades NOT converging (still improving)
  result=$(bash -c "source '$PLUGIN_DIR/lib/termination-engine.sh' && check_convergence '0.60 0.70 0.80 0.90' 0.001 3" 2>/dev/null || echo "ERROR")
  assert "no convergence on improving grades" "[ '$result' = 'not_converged' ] || [ '$result' = 'false' ] || [ '$result' = '0' ]"

  # Test budget check: within budget
  result=$(bash -c "source '$PLUGIN_DIR/lib/termination-engine.sh' && check_budget 100000 500000" 2>/dev/null || echo "ERROR")
  assert "budget not exhausted (100k/500k)" "[ '$result' = 'within_budget' ] || [ '$result' = 'false' ] || [ '$result' = '0' ]"

  # Test budget check: exceeded
  result=$(bash -c "source '$PLUGIN_DIR/lib/termination-engine.sh' && check_budget 500001 500000" 2>/dev/null || echo "ERROR")
  assert "budget exhausted (500001/500000)" "[ '$result' = 'exhausted' ] || [ '$result' = 'true' ] || [ '$result' = '1' ]"

  # Test checkpoint save/load round-trip
  CKPT_DIR="$TEMP_DIR/.devloop/sessions/$SESSION_ID/checkpoints"
  mkdir -p "$CKPT_DIR"
  bash -c "source '$PLUGIN_DIR/lib/termination-engine.sh' && save_checkpoint '$SESSION_DIR' 'checkpoint_1'" 2>/dev/null || true
  assert "checkpoint file created" "[ -f '$CKPT_DIR/checkpoint_1.json' ] || [ -f '$CKPT_DIR/checkpoint_1' ]"

  if [ -f "$CKPT_DIR/checkpoint_1.json" ] || [ -f "$CKPT_DIR/checkpoint_1" ]; then
    result=$(bash -c "source '$PLUGIN_DIR/lib/termination-engine.sh' && load_checkpoint '$SESSION_DIR' 'checkpoint_1'" 2>/dev/null || echo "ERROR")
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
  EVENT_LOG="$SESSION_DIR/event-log.jsonl"

  # Initialize event log
  bash -c "source '$PLUGIN_DIR/lib/event-logger.sh' && init_event_log '$SESSION_DIR'" 2>/dev/null || true
  assert "event log file created" "[ -f '$EVENT_LOG' ]"

  # Log some events
  bash -c "source '$PLUGIN_DIR/lib/event-logger.sh' && log_event '$SESSION_DIR' 'session_start' 'mode=tactic'" 2>/dev/null || true
  bash -c "source '$PLUGIN_DIR/lib/event-logger.sh' && log_event '$SESSION_DIR' 'iteration_start' 'iteration=1'" 2>/dev/null || true
  bash -c "source '$PLUGIN_DIR/lib/event-logger.sh' && log_event '$SESSION_DIR' 'quality_grade' 'grade=0.72'" 2>/dev/null || true

  # Verify events are in the log
  assert "event log has content" "[ -s '$EVENT_LOG' ]"

  # Count events
  line_count=$(wc -l < "$EVENT_LOG" 2>/dev/null | tr -d ' ')
  assert "event log has 3 entries" "[ '$line_count' -eq 3 ]"

  # Query events by type
  result=$(bash -c "source '$PLUGIN_DIR/lib/event-logger.sh' && query_events '$SESSION_DIR' 'session_start'" 2>/dev/null || echo "")
  assert "query finds session_start event" "echo '$result' | grep -q 'session_start'"

  # Count events by type
  result=$(bash -c "source '$PLUGIN_DIR/lib/event-logger.sh' && count_events '$SESSION_DIR' 'iteration_start'" 2>/dev/null || echo "0")
  assert "count_events returns 1 for iteration_start" "[ '$result' = '1' ]"

  # Verify each line is valid JSON
  all_valid=true
  while IFS= read -r line; do
    if ! python3 -c "import json; json.loads('$line')" 2>/dev/null; then
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
