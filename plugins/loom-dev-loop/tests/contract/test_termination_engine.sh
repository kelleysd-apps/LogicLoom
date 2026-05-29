#!/usr/bin/env bash
# Contract Tests: Termination Engine
# TDD tests for termination-engine.md contract
# Tests: check_all_layers, check_convergence, check_budget,
#        check_oscillation, save_checkpoint
# These tests are written BEFORE implementation (TDD).
set -eo pipefail

PASS=0; FAIL=0; TOTAL=0

assert() {
  TOTAL=$((TOTAL + 1))
  local desc="$1"; local condition="$2"
  if ( set +eu; eval "$condition" ) 2>/dev/null; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# ── Setup ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="${PLUGIN_DIR}/lib"
CONFIG_DIR="${PLUGIN_DIR}/config"
TEST_TMPDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_TMPDIR"
}
trap cleanup EXIT

echo "=== Termination Engine Contract Tests ==="
echo ""

# ── Library Existence ──
echo "Library and config existence"
assert "termination-engine.sh exists" "[ -f '${LIB_DIR}/termination-engine.sh' ]"
assert "safety-limits.json config exists" "[ -f '${CONFIG_DIR}/safety-limits.json' ]"
assert "thresholds.json config exists" "[ -f '${CONFIG_DIR}/thresholds.json' ]"

# Source library (tolerant of partially-implemented libs)
LIBS_SOURCED=false
if [ -f "${LIB_DIR}/termination-engine.sh" ]; then
  set +eu
  source "${LIB_DIR}/termination-engine.sh" 2>/dev/null
  set -eu
  LIBS_SOURCED=true
fi

# ── Function Existence ──
echo ""
echo "Function existence"
assert "check_all_layers function exists" "type -t check_all_layers 2>/dev/null | grep -q function"
assert "check_convergence function exists" "type -t check_convergence 2>/dev/null | grep -q function"
assert "check_budget function exists" "type -t check_budget 2>/dev/null | grep -q function"
assert "check_oscillation function exists" "type -t check_oscillation 2>/dev/null | grep -q function"
assert "save_checkpoint function exists" "type -t save_checkpoint 2>/dev/null | grep -q function"

# ══════════════════════════════════════════
# check_all_layers Tests
# ══════════════════════════════════════════
echo ""
echo "--- check_all_layers ---"

# Helper: create a minimal session state file for testing
create_test_session() {
  local session_id="$1"
  local grade="${2:-0.50}"
  local threshold="${3:-0.95}"
  local iteration="${4:-1}"
  local tokens="${5:-10000}"
  local cost="${6:-0.50}"
  local max_iter="${7:-25}"
  local token_limit="${8:-500000}"
  local cost_limit="${9:-10.00}"

  local sess_dir="${TEST_TMPDIR}/.dev-loop/sessions/${session_id}"
  mkdir -p "${sess_dir}/checkpoints"
  cat > "${sess_dir}/state.json" <<EOJSON
{
  "session_id": "${session_id}",
  "status": "running",
  "current_iteration": ${iteration},
  "current_grade": ${grade},
  "quality_threshold": ${threshold},
  "quality_history": [${grade}],
  "max_iterations": ${max_iter},
  "resources_consumed": {
    "total_tokens": ${tokens},
    "total_cost": ${cost}
  },
  "budget": {
    "tokens": ${token_limit},
    "cost": ${cost_limit}
  }
}
EOJSON
  echo "${sess_dir}"
}

echo "Priority ordering (layer 1 wins over layer 2)"
if $LIBS_SOURCED; then
  # Layer 1: Success -- grade meets threshold
  SESS_SUCCESS="test-success-$$"
  create_test_session "$SESS_SUCCESS" "0.96" "0.95" "5" "10000" "0.50" >/dev/null
  L_RESULT="$(check_all_layers --session "$SESS_SUCCESS" --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Layer 1: Grade >= threshold triggers termination" \
    "python3 -c 'import json; d=json.loads(\"\"\"$L_RESULT\"\"\"); assert d[\"should_terminate\"] == True'"
  assert "Layer 1: Triggered layer is 1" \
    "python3 -c 'import json; d=json.loads(\"\"\"$L_RESULT\"\"\"); assert d[\"layer_triggered\"] == 1'"
  assert "Layer 1: Reason is success" \
    "python3 -c 'import json; d=json.loads(\"\"\"$L_RESULT\"\"\"); assert d[\"termination_reason\"] == \"success\"'"

  # No termination when grade below threshold and everything else OK
  SESS_CONTINUE="test-continue-$$"
  create_test_session "$SESS_CONTINUE" "0.50" "0.95" "3" "10000" "0.50" >/dev/null
  L_CONT="$(check_all_layers --session "$SESS_CONTINUE" --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "No termination when grade below threshold and within budget" \
    "python3 -c 'import json; d=json.loads(\"\"\"$L_CONT\"\"\"); assert d[\"should_terminate\"] == False'"
  assert "layer_triggered is null when no termination" \
    "python3 -c 'import json; d=json.loads(\"\"\"$L_CONT\"\"\"); assert d[\"layer_triggered\"] is None'"

  # Layer 3: Budget exhausted (tokens)
  SESS_BUDGET="test-budget-$$"
  create_test_session "$SESS_BUDGET" "0.50" "0.95" "5" "600000" "0.50" "25" "500000" >/dev/null
  L_BUDGET="$(check_all_layers --session "$SESS_BUDGET" --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Layer 3: Token budget exceeded triggers termination" \
    "python3 -c 'import json; d=json.loads(\"\"\"$L_BUDGET\"\"\"); assert d[\"should_terminate\"] == True'"
  assert "Layer 3: Triggered layer is 3" \
    "python3 -c 'import json; d=json.loads(\"\"\"$L_BUDGET\"\"\"); assert d[\"layer_triggered\"] == 3'"

  # Layer 4: Max iterations
  SESS_MAXITER="test-maxiter-$$"
  create_test_session "$SESS_MAXITER" "0.50" "0.95" "25" "10000" "0.50" "25" >/dev/null
  L_MAXITER="$(check_all_layers --session "$SESS_MAXITER" --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Layer 4: Max iterations reached triggers termination" \
    "python3 -c 'import json; d=json.loads(\"\"\"$L_MAXITER\"\"\"); assert d[\"should_terminate\"] == True'"
  assert "Layer 4: Triggered layer is 4" \
    "python3 -c 'import json; d=json.loads(\"\"\"$L_MAXITER\"\"\"); assert d[\"layer_triggered\"] == 4'"

  # check_all_layers returns all 6 layer results
  assert "check_all_layers returns layer_results with all 6 layers" \
    "python3 -c 'import json; d=json.loads(\"\"\"$L_RESULT\"\"\"); lr=d[\"layer_results\"]; assert all(k in lr for k in [\"layer_1_success\",\"layer_2_convergence\",\"layer_3_budget\",\"layer_4_max_iterations\",\"layer_5_stuck\",\"layer_6_user_interrupt\"])'"

  # Priority: layer 1 wins even if layer 3 would also trigger
  SESS_MULTI="test-multi-$$"
  create_test_session "$SESS_MULTI" "0.96" "0.95" "5" "600000" "0.50" "25" "500000" >/dev/null
  L_MULTI="$(check_all_layers --session "$SESS_MULTI" --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Priority: Layer 1 (success) wins over Layer 3 (budget)" \
    "python3 -c 'import json; d=json.loads(\"\"\"$L_MULTI\"\"\"); assert d[\"layer_triggered\"] == 1'"

  # SESSION_NOT_FOUND
  L_NOSESS="$(check_all_layers --session 'nonexistent' --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Nonexistent session returns SESSION_NOT_FOUND" \
    "echo '$L_NOSESS' | grep -q 'SESSION_NOT_FOUND'"
else
  assert "Layer 1: Grade >= threshold triggers termination" "false"
  assert "Layer 1: Triggered layer is 1" "false"
  assert "Layer 1: Reason is success" "false"
  assert "No termination when grade below threshold and within budget" "false"
  assert "layer_triggered is null when no termination" "false"
  assert "Layer 3: Token budget exceeded triggers termination" "false"
  assert "Layer 3: Triggered layer is 3" "false"
  assert "Layer 4: Max iterations reached triggers termination" "false"
  assert "Layer 4: Triggered layer is 4" "false"
  assert "check_all_layers returns layer_results with all 6 layers" "false"
  assert "Priority: Layer 1 (success) wins over Layer 3 (budget)" "false"
  assert "Nonexistent session returns SESSION_NOT_FOUND" "false"
fi

# ══════════════════════════════════════════
# check_convergence Tests
# ══════════════════════════════════════════
echo ""
echo "--- check_convergence ---"

echo "Delta detection"
if $LIBS_SOURCED; then
  # Converged: 3 consecutive improvements below delta
  CONV_RESULT="$(check_convergence \
    --grades '[0.80, 0.85, 0.855, 0.856, 0.8565]' \
    --delta 0.001 \
    --consecutive 3 2>&1)" || true
  assert "Converged when last 3 deltas < 0.001" \
    "python3 -c 'import json; d=json.loads(\"\"\"$CONV_RESULT\"\"\"); assert d[\"converged\"] == True'"
  assert "Convergence returns last_improvements array" \
    "python3 -c 'import json; d=json.loads(\"\"\"$CONV_RESULT\"\"\"); assert \"last_improvements\" in d and isinstance(d[\"last_improvements\"], list)'"
  assert "Convergence returns average_improvement" \
    "python3 -c 'import json; d=json.loads(\"\"\"$CONV_RESULT\"\"\"); assert \"average_improvement\" in d'"

  # Not converged: still improving
  NOCONV_RESULT="$(check_convergence \
    --grades '[0.50, 0.60, 0.70, 0.80, 0.90]' \
    --delta 0.001 \
    --consecutive 3 2>&1)" || true
  assert "Not converged when deltas > 0.001" \
    "python3 -c 'import json; d=json.loads(\"\"\"$NOCONV_RESULT\"\"\"); assert d[\"converged\"] == False'"

  # Not converged: mixed large and small deltas
  MIXED_CONV="$(check_convergence \
    --grades '[0.80, 0.85, 0.855, 0.856, 0.90]' \
    --delta 0.001 \
    --consecutive 3 2>&1)" || true
  assert "Not converged when last delta is large jump" \
    "python3 -c 'import json; d=json.loads(\"\"\"$MIXED_CONV\"\"\"); assert d[\"converged\"] == False'"

  # INSUFFICIENT_DATA: fewer grades than consecutive_count
  INSUF_RESULT="$(check_convergence \
    --grades '[0.80, 0.85]' \
    --delta 0.001 \
    --consecutive 3 2>&1)" || true
  assert "Fewer grades than consecutive_count returns INSUFFICIENT_DATA" \
    "echo '$INSUF_RESULT' | grep -q 'INSUFFICIENT_DATA'"

  # INVALID_DELTA: non-positive delta
  BAD_DELTA="$(check_convergence \
    --grades '[0.80, 0.85, 0.90]' \
    --delta -0.001 \
    --consecutive 3 2>&1)" || true
  assert "Negative delta returns INVALID_DELTA" \
    "echo '$BAD_DELTA' | grep -q 'INVALID_DELTA'"

  ZERO_DELTA="$(check_convergence \
    --grades '[0.80, 0.85, 0.90]' \
    --delta 0 \
    --consecutive 3 2>&1)" || true
  assert "Zero delta returns INVALID_DELTA" \
    "echo '$ZERO_DELTA' | grep -q 'INVALID_DELTA'"
else
  assert "Converged when last 3 deltas < 0.001" "false"
  assert "Convergence returns last_improvements array" "false"
  assert "Convergence returns average_improvement" "false"
  assert "Not converged when deltas > 0.001" "false"
  assert "Not converged when last delta is large jump" "false"
  assert "Fewer grades than consecutive_count returns INSUFFICIENT_DATA" "false"
  assert "Negative delta returns INVALID_DELTA" "false"
  assert "Zero delta returns INVALID_DELTA" "false"
fi

# ══════════════════════════════════════════
# check_budget Tests
# ══════════════════════════════════════════
echo ""
echo "--- check_budget ---"

echo "Token and cost limit checks"
if $LIBS_SOURCED; then
  # Under budget
  SESS_UNDER="test-underbudget-$$"
  create_test_session "$SESS_UNDER" "0.50" "0.95" "3" "100000" "2.00" "25" "500000" "10.00" >/dev/null
  BUD_UNDER="$(check_budget --session "$SESS_UNDER" --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Under budget returns budget_exhausted=false" \
    "python3 -c 'import json; d=json.loads(\"\"\"$BUD_UNDER\"\"\"); assert d[\"budget_exhausted\"] == False'"
  assert "Budget status includes tokens remaining" \
    "python3 -c 'import json; d=json.loads(\"\"\"$BUD_UNDER\"\"\"); assert d[\"budget_status\"][\"tokens\"][\"remaining\"] == 400000'"
  assert "Budget status includes cost remaining" \
    "python3 -c 'import json; d=json.loads(\"\"\"$BUD_UNDER\"\"\"); assert abs(d[\"budget_status\"][\"cost\"][\"remaining\"] - 8.00) < 0.01'"
  assert "Budget status includes percent_used for tokens" \
    "python3 -c 'import json; d=json.loads(\"\"\"$BUD_UNDER\"\"\"); assert abs(d[\"budget_status\"][\"tokens\"][\"percent_used\"] - 20.0) < 0.1'"

  # Token budget exceeded
  SESS_TOVER="test-tokenover-$$"
  create_test_session "$SESS_TOVER" "0.50" "0.95" "10" "550000" "5.00" "25" "500000" "10.00" >/dev/null
  BUD_TOVER="$(check_budget --session "$SESS_TOVER" --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Token budget exceeded returns budget_exhausted=true" \
    "python3 -c 'import json; d=json.loads(\"\"\"$BUD_TOVER\"\"\"); assert d[\"budget_exhausted\"] == True'"

  # Cost budget exceeded
  SESS_COVER="test-costover-$$"
  create_test_session "$SESS_COVER" "0.50" "0.95" "10" "100000" "12.00" "25" "500000" "10.00" >/dev/null
  BUD_COVER="$(check_budget --session "$SESS_COVER" --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Cost budget exceeded returns budget_exhausted=true" \
    "python3 -c 'import json; d=json.loads(\"\"\"$BUD_COVER\"\"\"); assert d[\"budget_exhausted\"] == True'"

  # SESSION_NOT_FOUND
  BUD_NOSESS="$(check_budget --session 'nonexistent' --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Nonexistent session returns SESSION_NOT_FOUND" \
    "echo '$BUD_NOSESS' | grep -q 'SESSION_NOT_FOUND'"
else
  assert "Under budget returns budget_exhausted=false" "false"
  assert "Budget status includes tokens remaining" "false"
  assert "Budget status includes cost remaining" "false"
  assert "Budget status includes percent_used for tokens" "false"
  assert "Token budget exceeded returns budget_exhausted=true" "false"
  assert "Cost budget exceeded returns budget_exhausted=true" "false"
  assert "Nonexistent session returns SESSION_NOT_FOUND" "false"
fi

# ══════════════════════════════════════════
# check_oscillation Tests
# ══════════════════════════════════════════
echo ""
echo "--- check_oscillation ---"

echo "State hash comparison"
if $LIBS_SOURCED; then
  # Setup session with oscillating state hashes
  SESS_OSC="test-oscillation-$$"
  SESS_OSC_DIR="$(create_test_session "$SESS_OSC" "0.50" "0.95" "6")"
  # Write iteration state hashes that repeat (A-B-A-B pattern)
  cat > "${SESS_OSC_DIR}/state_hashes.json" <<'EOJSON'
{
  "iterations": [
    {"iteration": 1, "hash": "abc123"},
    {"iteration": 2, "hash": "def456"},
    {"iteration": 3, "hash": "abc123"},
    {"iteration": 4, "hash": "def456"},
    {"iteration": 5, "hash": "abc123"},
    {"iteration": 6, "hash": "def456"}
  ]
}
EOJSON

  OSC_RESULT="$(check_oscillation --session "$SESS_OSC" --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Repeating state hashes detected as oscillation" \
    "python3 -c 'import json; d=json.loads(\"\"\"$OSC_RESULT\"\"\"); assert d[\"oscillation_detected\"] == True'"
  assert "Oscillation returns cycle_length" \
    "python3 -c 'import json; d=json.loads(\"\"\"$OSC_RESULT\"\"\"); assert d[\"oscillation_pattern\"][\"cycle_length\"] == 2'"
  assert "Oscillation returns repeated_states with matching hashes" \
    "python3 -c 'import json; d=json.loads(\"\"\"$OSC_RESULT\"\"\"); rs=d[\"oscillation_pattern\"][\"repeated_states\"]; assert len(rs) > 0'"
  assert "Oscillation returns recommendation" \
    "python3 -c 'import json; d=json.loads(\"\"\"$OSC_RESULT\"\"\"); assert \"recommendation\" in d and len(d[\"recommendation\"]) > 0'"

  # No oscillation with unique states
  SESS_NOOSC="test-no-oscillation-$$"
  SESS_NOOSC_DIR="$(create_test_session "$SESS_NOOSC" "0.50" "0.95" "5")"
  cat > "${SESS_NOOSC_DIR}/state_hashes.json" <<'EOJSON'
{
  "iterations": [
    {"iteration": 1, "hash": "aaa111"},
    {"iteration": 2, "hash": "bbb222"},
    {"iteration": 3, "hash": "ccc333"},
    {"iteration": 4, "hash": "ddd444"},
    {"iteration": 5, "hash": "eee555"}
  ]
}
EOJSON

  NOOSC_RESULT="$(check_oscillation --session "$SESS_NOOSC" --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Unique state hashes: no oscillation detected" \
    "python3 -c 'import json; d=json.loads(\"\"\"$NOOSC_RESULT\"\"\"); assert d[\"oscillation_detected\"] == False'"
  assert "No oscillation: oscillation_pattern is null" \
    "python3 -c 'import json; d=json.loads(\"\"\"$NOOSC_RESULT\"\"\"); assert d[\"oscillation_pattern\"] is None'"

  # INSUFFICIENT_HISTORY: fewer than 4 iterations
  SESS_SHORT="test-short-$$"
  SESS_SHORT_DIR="$(create_test_session "$SESS_SHORT" "0.50" "0.95" "2")"
  cat > "${SESS_SHORT_DIR}/state_hashes.json" <<'EOJSON'
{
  "iterations": [
    {"iteration": 1, "hash": "abc123"},
    {"iteration": 2, "hash": "def456"}
  ]
}
EOJSON

  SHORT_RESULT="$(check_oscillation --session "$SESS_SHORT" --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Fewer than 4 iterations returns INSUFFICIENT_HISTORY" \
    "echo '$SHORT_RESULT' | grep -q 'INSUFFICIENT_HISTORY'"

  # SESSION_NOT_FOUND
  OSC_NOSESS="$(check_oscillation --session 'nonexistent' --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Nonexistent session returns SESSION_NOT_FOUND" \
    "echo '$OSC_NOSESS' | grep -q 'SESSION_NOT_FOUND'"
else
  assert "Repeating state hashes detected as oscillation" "false"
  assert "Oscillation returns cycle_length" "false"
  assert "Oscillation returns repeated_states with matching hashes" "false"
  assert "Oscillation returns recommendation" "false"
  assert "Unique state hashes: no oscillation detected" "false"
  assert "No oscillation: oscillation_pattern is null" "false"
  assert "Fewer than 4 iterations returns INSUFFICIENT_HISTORY" "false"
  assert "Nonexistent session returns SESSION_NOT_FOUND" "false"
fi

# ══════════════════════════════════════════
# save_checkpoint Tests
# ══════════════════════════════════════════
echo ""
echo "--- save_checkpoint ---"

echo "Valid JSON checkpoint output"
if $LIBS_SOURCED; then
  SESS_CKPT="test-checkpoint-$$"
  create_test_session "$SESS_CKPT" "0.85" "0.95" "5" "150000" "3.50" >/dev/null

  CKPT_RESULT="$(save_checkpoint --session "$SESS_CKPT" --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "save_checkpoint returns valid JSON" \
    "python3 -c 'import json; json.loads(\"\"\"$CKPT_RESULT\"\"\")'"
  assert "save_checkpoint returns checkpoint_path" \
    "python3 -c 'import json; d=json.loads(\"\"\"$CKPT_RESULT\"\"\"); assert \"checkpoint_path\" in d'"
  assert "save_checkpoint returns checkpoint_size_bytes" \
    "python3 -c 'import json; d=json.loads(\"\"\"$CKPT_RESULT\"\"\"); assert \"checkpoint_size_bytes\" in d and d[\"checkpoint_size_bytes\"] > 0'"
  assert "save_checkpoint returns state_captured with iteration" \
    "python3 -c 'import json; d=json.loads(\"\"\"$CKPT_RESULT\"\"\"); assert d[\"state_captured\"][\"iteration\"] == 5'"
  assert "save_checkpoint returns state_captured with quality_history" \
    "python3 -c 'import json; d=json.loads(\"\"\"$CKPT_RESULT\"\"\"); assert \"quality_history\" in d[\"state_captured\"]'"
  assert "save_checkpoint returns state_captured with resources_consumed" \
    "python3 -c 'import json; d=json.loads(\"\"\"$CKPT_RESULT\"\"\"); assert \"resources_consumed\" in d[\"state_captured\"]'"

  # Verify the checkpoint file was actually created on disk
  CKPT_PATH="$(python3 -c "import json; print(json.loads('''$CKPT_RESULT''').get('checkpoint_path',''))" 2>/dev/null)" || true
  if [ -n "$CKPT_PATH" ]; then
    assert "Checkpoint file created on disk" "[ -f '$CKPT_PATH' ]"
    assert "Checkpoint file is valid JSON" "python3 -c 'import json; json.load(open(\"$CKPT_PATH\"))'"
  else
    assert "Checkpoint file created on disk" "false"
    assert "Checkpoint file is valid JSON" "false"
  fi

  # Custom checkpoint name
  CKPT_NAMED="$(save_checkpoint --session "$SESS_CKPT" --name 'pre-refactor' --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Custom checkpoint name accepted" \
    "python3 -c 'import json; d=json.loads(\"\"\"$CKPT_NAMED\"\"\"); assert \"pre-refactor\" in d[\"checkpoint_path\"]'"

  # SESSION_NOT_FOUND
  CKPT_NOSESS="$(save_checkpoint --session 'nonexistent' --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Nonexistent session returns SESSION_NOT_FOUND" \
    "echo '$CKPT_NOSESS' | grep -q 'SESSION_NOT_FOUND'"
else
  assert "save_checkpoint returns valid JSON" "false"
  assert "save_checkpoint returns checkpoint_path" "false"
  assert "save_checkpoint returns checkpoint_size_bytes" "false"
  assert "save_checkpoint returns state_captured with iteration" "false"
  assert "save_checkpoint returns state_captured with quality_history" "false"
  assert "save_checkpoint returns state_captured with resources_consumed" "false"
  assert "Checkpoint file created on disk" "false"
  assert "Checkpoint file is valid JSON" "false"
  assert "Custom checkpoint name accepted" "false"
  assert "Nonexistent session returns SESSION_NOT_FOUND" "false"
fi

# ═══════════════════════════════════════
# Final Results
# ═══════════════════════════════════════
echo ""
echo "======================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "======================================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
