#!/usr/bin/env bash
# Contract Tests: RL Feedback Engine
# TDD tests for rl-metrics.json contract and rl-feedback skill implementation
# Tests: EMA update, weight clamping, UCB1 calculation, invocation tracking,
#         per-task-type breakdown, integration with .docs/rl-metrics, persistence
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

# Helper: safely call a function and capture output (returns empty string on failure)
safe_call() {
  local result=""
  result="$( set +eu; "$@" 2>/dev/null )" || true
  echo "$result"
}

# ── Setup ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="${PLUGIN_DIR}/lib"
TEMPLATE_DIR="${PLUGIN_DIR}/templates"
TEST_TMPDIR="$(mktemp -d)"
REPO_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"

cleanup() {
  rm -rf "$TEST_TMPDIR"
}
trap cleanup EXIT

echo "=== RL Feedback Contract Tests ==="
echo ""

# ── Library Existence ──
echo "Library and template existence"
assert "rl-feedback-engine.sh exists" "[ -f '${LIB_DIR}/rl-feedback-engine.sh' ]"
assert "rl-metrics.json template exists" "[ -f '${TEMPLATE_DIR}/rl-metrics.json' ]"

# Source library (tolerant of partially-implemented libs)
LIBS_SOURCED=false
if [ -f "${LIB_DIR}/rl-feedback-engine.sh" ]; then
  ( set +eu; source "${LIB_DIR}/rl-feedback-engine.sh" ) 2>/dev/null || true
  set +eu
  source "${LIB_DIR}/rl-feedback-engine.sh" 2>/dev/null || true
  set -eo pipefail
  LIBS_SOURCED=true
fi

# ── Function Existence ──
echo ""
echo "Function existence"
assert "ema_update function exists" "type -t ema_update 2>/dev/null | grep -q function"
assert "clamp_weight function exists" "type -t clamp_weight 2>/dev/null | grep -q function"
assert "ucb1_score function exists" "type -t ucb1_score 2>/dev/null | grep -q function"
assert "record_feedback function exists" "type -t record_feedback 2>/dev/null | grep -q function"
assert "update_task_type_metrics function exists" "type -t update_task_type_metrics 2>/dev/null | grep -q function"

# ══════════════════════════════════════════
# EMA Update Tests
# ══════════════════════════════════════════
echo ""
echo "--- EMA Update ---"

echo "Exponential Moving Average calculation"
if $LIBS_SOURCED; then
  # Success outcome: new_rate = 0.9 * old_rate + 0.1 * 1.0
  # Starting from 0.5: new_rate = 0.9 * 0.5 + 0.1 * 1.0 = 0.45 + 0.10 = 0.55
  EMA_SUCCESS="$(safe_call ema_update --current-rate 0.5 --outcome success --alpha 0.1)"
  assert "EMA success: 0.9 * 0.5 + 0.1 * 1.0 = 0.55" \
    "python3 -c 'v=float(\"${EMA_SUCCESS}\".strip()); assert abs(v - 0.55) < 0.001, f\"got {v}\"'"

  # Failure outcome: new_rate = 0.9 * old_rate + 0.1 * 0.0
  # Starting from 0.5: new_rate = 0.9 * 0.5 + 0.1 * 0.0 = 0.45 + 0.00 = 0.45
  EMA_FAILURE="$(safe_call ema_update --current-rate 0.5 --outcome failure --alpha 0.1)"
  assert "EMA failure: 0.9 * 0.5 + 0.1 * 0.0 = 0.45" \
    "python3 -c 'v=float(\"${EMA_FAILURE}\".strip()); assert abs(v - 0.45) < 0.001, f\"got {v}\"'"

  # Success from 0.0: new_rate = 0.9 * 0.0 + 0.1 * 1.0 = 0.10
  EMA_FROM_ZERO="$(safe_call ema_update --current-rate 0.0 --outcome success --alpha 0.1)"
  assert "EMA success from 0.0: 0.9 * 0.0 + 0.1 * 1.0 = 0.10" \
    "python3 -c 'v=float(\"${EMA_FROM_ZERO}\".strip()); assert abs(v - 0.10) < 0.001, f\"got {v}\"'"

  # Failure from 1.0: new_rate = 0.9 * 1.0 + 0.1 * 0.0 = 0.90
  EMA_FROM_ONE="$(safe_call ema_update --current-rate 1.0 --outcome failure --alpha 0.1)"
  assert "EMA failure from 1.0: 0.9 * 1.0 + 0.1 * 0.0 = 0.90" \
    "python3 -c 'v=float(\"${EMA_FROM_ONE}\".strip()); assert abs(v - 0.90) < 0.001, f\"got {v}\"'"

  # Custom alpha: new_rate = (1 - 0.3) * 0.5 + 0.3 * 1.0 = 0.35 + 0.30 = 0.65
  EMA_CUSTOM_ALPHA="$(safe_call ema_update --current-rate 0.5 --outcome success --alpha 0.3)"
  assert "EMA with custom alpha 0.3: 0.7 * 0.5 + 0.3 * 1.0 = 0.65" \
    "python3 -c 'v=float(\"${EMA_CUSTOM_ALPHA}\".strip()); assert abs(v - 0.65) < 0.001, f\"got {v}\"'"

  # Consecutive successes converge toward 1.0
  RATE=0.5
  for i in 1 2 3 4 5; do
    RATE="$(safe_call ema_update --current-rate "$RATE" --outcome success --alpha 0.1)"
  done
  assert "5 consecutive successes from 0.5 converges toward 1.0 (> 0.7)" \
    "python3 -c 'v=float(\"${RATE}\".strip()); assert v > 0.7, f\"got {v}\"'"

  # Consecutive failures converge toward 0.0
  RATE_F=0.5
  for i in 1 2 3 4 5; do
    RATE_F="$(safe_call ema_update --current-rate "$RATE_F" --outcome failure --alpha 0.1)"
  done
  assert "5 consecutive failures from 0.5 converges toward 0.0 (< 0.3)" \
    "python3 -c 'v=float(\"${RATE_F}\".strip()); assert v < 0.3, f\"got {v}\"'"

  # EMA result always in [0, 1]
  assert "EMA result is always in range [0, 1]" \
    "python3 -c 'v=float(\"${EMA_SUCCESS}\".strip()); assert 0.0 <= v <= 1.0, f\"got {v}\"'"
else
  assert "EMA success: 0.9 * 0.5 + 0.1 * 1.0 = 0.55" "false"
  assert "EMA failure: 0.9 * 0.5 + 0.1 * 0.0 = 0.45" "false"
  assert "EMA success from 0.0: 0.9 * 0.0 + 0.1 * 1.0 = 0.10" "false"
  assert "EMA failure from 1.0: 0.9 * 1.0 + 0.1 * 0.0 = 0.90" "false"
  assert "EMA with custom alpha 0.3: 0.7 * 0.5 + 0.3 * 1.0 = 0.65" "false"
  assert "5 consecutive successes from 0.5 converges toward 1.0 (> 0.7)" "false"
  assert "5 consecutive failures from 0.5 converges toward 0.0 (< 0.3)" "false"
  assert "EMA result is always in range [0, 1]" "false"
fi

# ══════════════════════════════════════════
# Selection Weight Clamping Tests
# ══════════════════════════════════════════
echo ""
echo "--- Selection Weight Clamping ---"

echo "selection_weight clamped to [0.1, 1.0]"
if $LIBS_SOURCED; then
  # Normal value within range
  CLAMP_NORMAL="$(safe_call clamp_weight 0.75)"
  assert "clamp_weight 0.75 returns 0.75 (within range)" \
    "python3 -c 'v=float(\"${CLAMP_NORMAL}\".strip()); assert abs(v - 0.75) < 0.001, f\"got {v}\"'"

  # Value at lower boundary
  CLAMP_MIN="$(safe_call clamp_weight 0.1)"
  assert "clamp_weight 0.1 returns 0.1 (at minimum)" \
    "python3 -c 'v=float(\"${CLAMP_MIN}\".strip()); assert abs(v - 0.1) < 0.001, f\"got {v}\"'"

  # Value at upper boundary
  CLAMP_MAX="$(safe_call clamp_weight 1.0)"
  assert "clamp_weight 1.0 returns 1.0 (at maximum)" \
    "python3 -c 'v=float(\"${CLAMP_MAX}\".strip()); assert abs(v - 1.0) < 0.001, f\"got {v}\"'"

  # Value below minimum: should clamp to 0.1
  CLAMP_BELOW="$(safe_call clamp_weight 0.05)"
  assert "clamp_weight 0.05 clamps to 0.1 (below minimum)" \
    "python3 -c 'v=float(\"${CLAMP_BELOW}\".strip()); assert abs(v - 0.1) < 0.001, f\"got {v}\"'"

  # Value of 0.0: should clamp to 0.1 (never exclude a skill)
  CLAMP_ZERO="$(safe_call clamp_weight 0.0)"
  assert "clamp_weight 0.0 clamps to 0.1 (never fully excluded)" \
    "python3 -c 'v=float(\"${CLAMP_ZERO}\".strip()); assert abs(v - 0.1) < 0.001, f\"got {v}\"'"

  # Value above maximum: should clamp to 1.0
  CLAMP_ABOVE="$(safe_call clamp_weight 1.5)"
  assert "clamp_weight 1.5 clamps to 1.0 (above maximum)" \
    "python3 -c 'v=float(\"${CLAMP_ABOVE}\".strip()); assert abs(v - 1.0) < 0.001, f\"got {v}\"'"

  # Negative value: should clamp to 0.1
  CLAMP_NEG="$(safe_call clamp_weight -0.3)"
  assert "clamp_weight -0.3 clamps to 0.1 (negative)" \
    "python3 -c 'v=float(\"${CLAMP_NEG}\".strip()); assert abs(v - 0.1) < 0.001, f\"got {v}\"'"
else
  assert "clamp_weight 0.75 returns 0.75 (within range)" "false"
  assert "clamp_weight 0.1 returns 0.1 (at minimum)" "false"
  assert "clamp_weight 1.0 returns 1.0 (at maximum)" "false"
  assert "clamp_weight 0.05 clamps to 0.1 (below minimum)" "false"
  assert "clamp_weight 0.0 clamps to 0.1 (never fully excluded)" "false"
  assert "clamp_weight 1.5 clamps to 1.0 (above maximum)" "false"
  assert "clamp_weight -0.3 clamps to 0.1 (negative)" "false"
fi

# ══════════════════════════════════════════
# UCB1 Score Calculation Tests
# ══════════════════════════════════════════
echo ""
echo "--- UCB1 Score ---"

echo "UCB1 exploration/exploitation balance"
if $LIBS_SOURCED; then
  # UCB1 formula: success_rate + sqrt(2 * ln(total) / count)
  # total=100, count=10, success_rate=0.8: 0.8 + sqrt(2 * ln(100) / 10) = 0.8 + sqrt(2 * 4.605 / 10) = 0.8 + sqrt(0.921) = 0.8 + 0.9597 ≈ 1.76
  UCB1_NORMAL="$(safe_call ucb1_score --success-rate 0.8 --count 10 --total 100)"
  assert "UCB1(rate=0.8, count=10, total=100) approximately 1.76" \
    "python3 -c 'import math; v=float(\"${UCB1_NORMAL}\".strip()); expected=0.8+math.sqrt(2*math.log(100)/10); assert abs(v - expected) < 0.01, f\"got {v}, expected {expected}\"'"

  # Zero invocations: UCB1 should return infinity (always explore)
  UCB1_ZERO="$(safe_call ucb1_score --success-rate 0.5 --count 0 --total 100)"
  assert "UCB1 with count=0 returns infinity (explore untried)" \
    "python3 -c 'import math; v=float(\"${UCB1_ZERO}\".strip()); assert math.isinf(v) or v > 1000, f\"got {v}\"'"

  # High count: exploration bonus is small
  UCB1_HIGH_COUNT="$(safe_call ucb1_score --success-rate 0.5 --count 1000 --total 10000)"
  assert "UCB1 with high count has small exploration bonus (close to success_rate)" \
    "python3 -c 'import math; v=float(\"${UCB1_HIGH_COUNT}\".strip()); bonus=v-0.5; assert bonus < 0.2, f\"got bonus={bonus}\"'"

  # Low count: exploration bonus is large
  UCB1_LOW_COUNT="$(safe_call ucb1_score --success-rate 0.5 --count 2 --total 100)"
  assert "UCB1 with low count has large exploration bonus (> 0.5 above success_rate)" \
    "python3 -c 'import math; v=float(\"${UCB1_LOW_COUNT}\".strip()); bonus=v-0.5; assert bonus > 0.5, f\"got bonus={bonus}\"'"

  # UCB1 should always be >= success_rate (exploration bonus is non-negative)
  assert "UCB1 score is always >= success_rate" \
    "python3 -c 'v=float(\"${UCB1_NORMAL}\".strip()); assert v >= 0.8, f\"got {v}\"'"
else
  assert "UCB1(rate=0.8, count=10, total=100) approximately 1.76" "false"
  assert "UCB1 with count=0 returns infinity (explore untried)" "false"
  assert "UCB1 with high count has small exploration bonus (close to success_rate)" "false"
  assert "UCB1 with low count has large exploration bonus (> 0.5 above success_rate)" "false"
  assert "UCB1 score is always >= success_rate" "false"
fi

# ══════════════════════════════════════════
# Invocation Count Tests
# ══════════════════════════════════════════
echo ""
echo "--- Invocation Count ---"

echo "Invocation count increments correctly"
if $LIBS_SOURCED; then
  # Create a temporary metrics file
  cat > "$TEST_TMPDIR/test_metrics.json" << 'METRICEOF'
{"skill_name":"test-skill","model_name":"claude-opus-4-6","success_rate":0.5,"selection_weight":0.5,"invocation_count":0,"avg_tokens":0,"avg_duration_ms":0,"ema_alpha":0.1,"history":[],"per_task_type":{"tactic":{"success_rate":0.5,"invocation_count":0,"avg_tokens":0,"avg_duration_ms":0},"strategy":{"success_rate":0.5,"invocation_count":0,"avg_tokens":0,"avg_duration_ms":0}}}
METRICEOF

  # Record a feedback entry
  RECORD_RESULT="$(safe_call record_feedback --metrics-file "$TEST_TMPDIR/test_metrics.json" --outcome success --tokens 50000 --duration-ms 120000 --task-type tactic)"

  # Check invocation count incremented to 1
  assert "Invocation count increments from 0 to 1 after first feedback" \
    "python3 -c 'import json; d=json.load(open(\"$TEST_TMPDIR/test_metrics.json\")); assert d[\"invocation_count\"] == 1, f\"got {d[\"invocation_count\"]}\"'"

  # Record another feedback entry
  RECORD_RESULT2="$(safe_call record_feedback --metrics-file "$TEST_TMPDIR/test_metrics.json" --outcome failure --tokens 80000 --duration-ms 200000 --task-type tactic)"

  # Check invocation count incremented to 2
  assert "Invocation count increments from 1 to 2 after second feedback" \
    "python3 -c 'import json; d=json.load(open(\"$TEST_TMPDIR/test_metrics.json\")); assert d[\"invocation_count\"] == 2, f\"got {d[\"invocation_count\"]}\"'"

  # History length should match invocation count
  assert "History array length matches invocation count" \
    "python3 -c 'import json; d=json.load(open(\"$TEST_TMPDIR/test_metrics.json\")); assert len(d[\"history\"]) == d[\"invocation_count\"], f\"history={len(d[\"history\"])}, count={d[\"invocation_count\"]}\"'"

  # last_feedback should be set after recording
  assert "last_feedback is set after recording feedback" \
    "python3 -c 'import json; d=json.load(open(\"$TEST_TMPDIR/test_metrics.json\")); assert d[\"last_feedback\"] is not None, \"last_feedback is None\"'"

  # avg_tokens should be updated
  assert "avg_tokens updated after feedback (should be average of 50000 and 80000)" \
    "python3 -c 'import json; d=json.load(open(\"$TEST_TMPDIR/test_metrics.json\")); assert d[\"avg_tokens\"] > 0, f\"got {d[\"avg_tokens\"]}\"'"

  # avg_duration_ms should be updated
  assert "avg_duration_ms updated after feedback" \
    "python3 -c 'import json; d=json.load(open(\"$TEST_TMPDIR/test_metrics.json\")); assert d[\"avg_duration_ms\"] > 0, f\"got {d[\"avg_duration_ms\"]}\"'"
else
  assert "Invocation count increments from 0 to 1 after first feedback" "false"
  assert "Invocation count increments from 1 to 2 after second feedback" "false"
  assert "History array length matches invocation count" "false"
  assert "last_feedback is set after recording feedback" "false"
  assert "avg_tokens updated after feedback (should be average of 50000 and 80000)" "false"
  assert "avg_duration_ms updated after feedback" "false"
fi

# ══════════════════════════════════════════
# Per-Task-Type Breakdown Tests
# ══════════════════════════════════════════
echo ""
echo "--- Per-Task-Type Breakdown ---"

echo "Per-task-type metrics updated correctly"
if $LIBS_SOURCED; then
  # Create a fresh metrics file for per-task-type tests
  cat > "$TEST_TMPDIR/task_type_metrics.json" << 'TTEOF'
{"skill_name":"test-skill","model_name":"claude-opus-4-6","success_rate":0.5,"selection_weight":0.5,"invocation_count":0,"avg_tokens":0,"avg_duration_ms":0,"ema_alpha":0.1,"history":[],"per_task_type":{"tactic":{"success_rate":0.5,"invocation_count":0,"avg_tokens":0,"avg_duration_ms":0},"strategy":{"success_rate":0.5,"invocation_count":0,"avg_tokens":0,"avg_duration_ms":0}}}
TTEOF

  # Record tactic feedback
  safe_call record_feedback --metrics-file "$TEST_TMPDIR/task_type_metrics.json" --outcome success --tokens 30000 --duration-ms 60000 --task-type tactic > /dev/null

  # Tactic sub-metrics should be updated
  assert "Tactic invocation_count increments to 1" \
    "python3 -c 'import json; d=json.load(open(\"$TEST_TMPDIR/task_type_metrics.json\")); assert d[\"per_task_type\"][\"tactic\"][\"invocation_count\"] == 1, f\"got {d[\"per_task_type\"][\"tactic\"][\"invocation_count\"]}\"'"

  assert "Tactic success_rate updated via EMA after success" \
    "python3 -c 'import json; d=json.load(open(\"$TEST_TMPDIR/task_type_metrics.json\")); sr=d[\"per_task_type\"][\"tactic\"][\"success_rate\"]; assert abs(sr - 0.55) < 0.001, f\"got {sr}\"'"

  # Strategy sub-metrics should remain unchanged
  assert "Strategy invocation_count remains 0 after tactic feedback" \
    "python3 -c 'import json; d=json.load(open(\"$TEST_TMPDIR/task_type_metrics.json\")); assert d[\"per_task_type\"][\"strategy\"][\"invocation_count\"] == 0, f\"got {d[\"per_task_type\"][\"strategy\"][\"invocation_count\"]}\"'"

  # Record strategy feedback
  safe_call record_feedback --metrics-file "$TEST_TMPDIR/task_type_metrics.json" --outcome failure --tokens 100000 --duration-ms 300000 --task-type strategy > /dev/null

  # Strategy sub-metrics should now be updated
  assert "Strategy invocation_count increments to 1 after strategy feedback" \
    "python3 -c 'import json; d=json.load(open(\"$TEST_TMPDIR/task_type_metrics.json\")); assert d[\"per_task_type\"][\"strategy\"][\"invocation_count\"] == 1, f\"got {d[\"per_task_type\"][\"strategy\"][\"invocation_count\"]}\"'"

  assert "Strategy success_rate updated via EMA after failure" \
    "python3 -c 'import json; d=json.load(open(\"$TEST_TMPDIR/task_type_metrics.json\")); sr=d[\"per_task_type\"][\"strategy\"][\"success_rate\"]; assert abs(sr - 0.45) < 0.001, f\"got {sr}\"'"

  # Total invocation_count should be sum of both
  assert "Total invocation_count equals sum of tactic + strategy counts" \
    "python3 -c 'import json; d=json.load(open(\"$TEST_TMPDIR/task_type_metrics.json\")); tc=d[\"per_task_type\"][\"tactic\"][\"invocation_count\"]; sc=d[\"per_task_type\"][\"strategy\"][\"invocation_count\"]; assert d[\"invocation_count\"] == tc + sc, f\"total={d[\"invocation_count\"]}, tactic={tc}, strategy={sc}\"'"
else
  assert "Tactic invocation_count increments to 1" "false"
  assert "Tactic success_rate updated via EMA after success" "false"
  assert "Strategy invocation_count remains 0 after tactic feedback" "false"
  assert "Strategy invocation_count increments to 1 after strategy feedback" "false"
  assert "Strategy success_rate updated via EMA after failure" "false"
  assert "Total invocation_count equals sum of tactic + strategy counts" "false"
fi

# ══════════════════════════════════════════
# Integration with Existing RL System
# ══════════════════════════════════════════
echo ""
echo "--- Integration with .docs/rl-metrics ---"

echo "Integration with framework RL infrastructure"
# These tests verify integration points exist (do NOT modify real files)

assert "Framework collect-feedback.sh exists" \
  "[ -f '${REPO_ROOT}/.specify/scripts/bash/rl/collect-feedback.sh' ]"
assert "Framework sync-metrics.sh exists" \
  "[ -f '${REPO_ROOT}/.specify/scripts/bash/rl/sync-metrics.sh' ]"
assert "Framework skill-performance.json exists or directory exists" \
  "[ -f '${REPO_ROOT}/.docs/rl-metrics/skill-performance.json' ] || [ -d '${REPO_ROOT}/.docs/rl-metrics' ]"
assert "Framework skill-index.json exists or .claude directory exists" \
  "[ -f '${REPO_ROOT}/.claude/skill-index.json' ] || [ -d '${REPO_ROOT}/.claude' ]"

# ══════════════════════════════════════════
# Metrics Persistence Tests
# ══════════════════════════════════════════
echo ""
echo "--- Metrics Persistence ---"

echo "Metrics survive across simulated sessions"
if $LIBS_SOURCED; then
  # Create metrics file simulating session 1
  cat > "$TEST_TMPDIR/persist_metrics.json" << 'PERSISTEOF'
{"skill_name":"persist-test","model_name":"claude-opus-4-6","success_rate":0.5,"selection_weight":0.5,"invocation_count":0,"avg_tokens":0,"avg_duration_ms":0,"ema_alpha":0.1,"history":[],"per_task_type":{"tactic":{"success_rate":0.5,"invocation_count":0,"avg_tokens":0,"avg_duration_ms":0},"strategy":{"success_rate":0.5,"invocation_count":0,"avg_tokens":0,"avg_duration_ms":0}}}
PERSISTEOF

  # Session 1: record success
  safe_call record_feedback --metrics-file "$TEST_TMPDIR/persist_metrics.json" --outcome success --tokens 40000 --duration-ms 90000 --task-type tactic > /dev/null

  # Capture session 1 state
  SESSION1_RATE="$(python3 -c "import json; d=json.load(open('$TEST_TMPDIR/persist_metrics.json')); print(d['success_rate'])")"
  SESSION1_COUNT="$(python3 -c "import json; d=json.load(open('$TEST_TMPDIR/persist_metrics.json')); print(d['invocation_count'])")"

  assert "Session 1 state persisted (success_rate = 0.55)" \
    "python3 -c 'assert abs(float(\"${SESSION1_RATE}\") - 0.55) < 0.001, f\"got ${SESSION1_RATE}\"'"

  # Session 2: re-source the library (simulates new session) and record failure
  if [ -f "${LIB_DIR}/rl-feedback-engine.sh" ]; then
    set +eu
    source "${LIB_DIR}/rl-feedback-engine.sh" 2>/dev/null || true
    set -eo pipefail
  fi
  safe_call record_feedback --metrics-file "$TEST_TMPDIR/persist_metrics.json" --outcome failure --tokens 70000 --duration-ms 180000 --task-type strategy > /dev/null

  # Check that session 2 built on session 1 state
  SESSION2_RATE="$(python3 -c "import json; d=json.load(open('$TEST_TMPDIR/persist_metrics.json')); print(d['success_rate'])")"
  SESSION2_COUNT="$(python3 -c "import json; d=json.load(open('$TEST_TMPDIR/persist_metrics.json')); print(d['invocation_count'])")"

  assert "Session 2 builds on session 1 state (invocation_count = 2)" \
    "python3 -c 'assert int(\"${SESSION2_COUNT}\") == 2, f\"got ${SESSION2_COUNT}\"'"

  # EMA of success then failure from 0.5: 0.5 -> 0.55 -> 0.9*0.55 + 0.1*0 = 0.495
  assert "Session 2 success_rate reflects cumulative EMA (approx 0.495)" \
    "python3 -c 'v=float(\"${SESSION2_RATE}\"); assert abs(v - 0.495) < 0.01, f\"got {v}\"'"

  # History should contain both entries
  assert "History contains entries from both sessions" \
    "python3 -c 'import json; d=json.load(open(\"$TEST_TMPDIR/persist_metrics.json\")); assert len(d[\"history\"]) == 2, f\"got {len(d[\"history\"])}\"'"

  # First history entry should be success, second failure
  assert "History preserves chronological order (success then failure)" \
    "python3 -c 'import json; d=json.load(open(\"$TEST_TMPDIR/persist_metrics.json\")); assert d[\"history\"][0][\"outcome\"] == \"success\" and d[\"history\"][1][\"outcome\"] == \"failure\"'"
else
  assert "Session 1 state persisted (success_rate = 0.55)" "false"
  assert "Session 2 builds on session 1 state (invocation_count = 2)" "false"
  assert "Session 2 success_rate reflects cumulative EMA (approx 0.495)" "false"
  assert "History contains entries from both sessions" "false"
  assert "History preserves chronological order (success then failure)" "false"
fi

# ═══════════════════════════════════════
# Final Results
# ═══════════════════════════════════════
echo ""
echo "======================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "======================================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
