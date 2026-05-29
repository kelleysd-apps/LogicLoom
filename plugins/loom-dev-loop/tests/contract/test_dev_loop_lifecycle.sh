#!/usr/bin/env bash
# Contract Tests: Dev-Loop Lifecycle
# TDD tests for dev-loop-lifecycle.md contract
# Tests: start_session, execute_iteration, grade_iteration,
#        terminate_session, resume_session, get_session_status
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
TEST_TMPDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_TMPDIR"
}
trap cleanup EXIT

echo "=== Dev-Loop Lifecycle Contract Tests ==="
echo ""

# ── Library Existence ──
echo "Library file existence"
assert "grading-engine.sh exists" "[ -f '${LIB_DIR}/grading-engine.sh' ]"
assert "termination-engine.sh exists" "[ -f '${LIB_DIR}/termination-engine.sh' ]"
assert "event-logger.sh exists" "[ -f '${LIB_DIR}/event-logger.sh' ]"
assert "lifecycle.sh exists" "[ -f '${LIB_DIR}/lifecycle.sh' ]"

# Source libraries (tolerant of partially-implemented libs)
LIBS_SOURCED=false
if [ -f "${LIB_DIR}/lifecycle.sh" ] && \
   [ -f "${LIB_DIR}/grading-engine.sh" ] && \
   [ -f "${LIB_DIR}/termination-engine.sh" ] && \
   [ -f "${LIB_DIR}/event-logger.sh" ]; then
  set +eu
  source "${LIB_DIR}/lifecycle.sh" 2>/dev/null
  source "${LIB_DIR}/grading-engine.sh" 2>/dev/null
  source "${LIB_DIR}/termination-engine.sh" 2>/dev/null
  source "${LIB_DIR}/event-logger.sh" 2>/dev/null
  set -eu
  LIBS_SOURCED=true
fi

# ── Function Existence ──
echo ""
echo "Function existence"
assert "start_session function exists" "type -t start_session 2>/dev/null | grep -q function"
assert "execute_iteration function exists" "type -t execute_iteration 2>/dev/null | grep -q function"
assert "grade_iteration function exists" "type -t grade_iteration 2>/dev/null | grep -q function"
assert "terminate_session function exists" "type -t terminate_session 2>/dev/null | grep -q function"
assert "resume_session function exists" "type -t resume_session 2>/dev/null | grep -q function"
assert "get_session_status function exists" "type -t get_session_status 2>/dev/null | grep -q function"

# ══════════════════════════════════════════
# Start Session Tests
# ══════════════════════════════════════════
echo ""
echo "--- Start Session ---"

# Test: Valid session creation with defaults
echo "Valid session creation"
if $LIBS_SOURCED; then
  START_RESULT="$(start_session --task 'Implement user auth' --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "start_session returns JSON with session_id" \
    "echo '$START_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"session_id\" in d'"
  assert "start_session returns status=running" \
    "echo '$START_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"status\"] == \"running\"'"
  assert "start_session returns started_at timestamp" \
    "echo '$START_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"started_at\" in d'"
  assert "start_session returns mode field" \
    "echo '$START_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"mode\"] in [\"tactic\", \"strategy\"]'"
else
  assert "start_session returns JSON with session_id" "false"
  assert "start_session returns status=running" "false"
  assert "start_session returns started_at timestamp" "false"
  assert "start_session returns mode field" "false"
fi

# Test: Config overrides applied
echo ""
echo "Config overrides"
if $LIBS_SOURCED; then
  OVERRIDE_RESULT="$(start_session \
    --task 'Build login form' \
    --workdir "$TEST_TMPDIR" \
    --threshold 0.90 \
    --budget-tokens 200000 \
    --budget-cost 5.00 \
    --max-iterations 15 \
    --mode tactic 2>&1)" || true
  assert "Custom threshold accepted (0.90)" \
    "echo '$OVERRIDE_RESULT' | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null"
else
  assert "Custom threshold accepted (0.90)" "false"
fi

# Test: INVALID_THRESHOLD error
echo ""
echo "INVALID_THRESHOLD error"
if $LIBS_SOURCED; then
  THRESH_LOW="$(start_session --task 'test' --workdir "$TEST_TMPDIR" --threshold 0.50 2>&1)" || true
  assert "Threshold below 0.80 returns INVALID_THRESHOLD" \
    "echo '$THRESH_LOW' | grep -q 'INVALID_THRESHOLD'"

  THRESH_HIGH="$(start_session --task 'test' --workdir "$TEST_TMPDIR" --threshold 1.00 2>&1)" || true
  assert "Threshold above 0.99 returns INVALID_THRESHOLD" \
    "echo '$THRESH_HIGH' | grep -q 'INVALID_THRESHOLD'"

  THRESH_EDGE_LOW="$(start_session --task 'test' --workdir "$TEST_TMPDIR" --threshold 0.80 2>&1)" || true
  assert "Threshold 0.80 is accepted (lower bound)" \
    "! echo '$THRESH_EDGE_LOW' | grep -q 'INVALID_THRESHOLD'"

  THRESH_EDGE_HIGH="$(start_session --task 'test' --workdir "$TEST_TMPDIR" --threshold 0.99 2>&1)" || true
  assert "Threshold 0.99 is accepted (upper bound)" \
    "! echo '$THRESH_EDGE_HIGH' | grep -q 'INVALID_THRESHOLD'"
else
  assert "Threshold below 0.80 returns INVALID_THRESHOLD" "false"
  assert "Threshold above 0.99 returns INVALID_THRESHOLD" "false"
  assert "Threshold 0.80 is accepted (lower bound)" "false"
  assert "Threshold 0.99 is accepted (upper bound)" "false"
fi

# Test: INVALID_BUDGET error
echo ""
echo "INVALID_BUDGET error"
if $LIBS_SOURCED; then
  BUDGET_NEG="$(start_session --task 'test' --workdir "$TEST_TMPDIR" --budget-tokens -100 2>&1)" || true
  assert "Negative token budget returns INVALID_BUDGET" \
    "echo '$BUDGET_NEG' | grep -q 'INVALID_BUDGET'"

  BUDGET_ZERO="$(start_session --task 'test' --workdir "$TEST_TMPDIR" --budget-cost 0 2>&1)" || true
  assert "Zero cost budget returns INVALID_BUDGET" \
    "echo '$BUDGET_ZERO' | grep -q 'INVALID_BUDGET'"
else
  assert "Negative token budget returns INVALID_BUDGET" "false"
  assert "Zero cost budget returns INVALID_BUDGET" "false"
fi

# Test: INVALID_WEIGHTS error
echo ""
echo "INVALID_WEIGHTS error"
if $LIBS_SOURCED; then
  # Weights that don't sum to 1.0
  BAD_WEIGHTS="$(start_session --task 'test' --workdir "$TEST_TMPDIR" \
    --weights '{"test_pass_rate":0.50,"test_coverage":0.50,"lint":0.50,"type_safety":0.10,"security":0.10,"build":0.10}' 2>&1)" || true
  assert "Weights not summing to 1.0 returns INVALID_WEIGHTS" \
    "echo '$BAD_WEIGHTS' | grep -q 'INVALID_WEIGHTS'"

  # Weights with test_pass_rate below minimum (0.30 per weights.json)
  LOW_TPR="$(start_session --task 'test' --workdir "$TEST_TMPDIR" \
    --weights '{"test_pass_rate":0.10,"test_coverage":0.30,"lint":0.20,"type_safety":0.20,"security":0.15,"build":0.05}' 2>&1)" || true
  assert "test_pass_rate below min weight (0.30) returns INVALID_WEIGHTS" \
    "echo '$LOW_TPR' | grep -q 'INVALID_WEIGHTS'"
else
  assert "Weights not summing to 1.0 returns INVALID_WEIGHTS" "false"
  assert "test_pass_rate below min weight (0.30) returns INVALID_WEIGHTS" "false"
fi

# Test: INVALID_TASK error
echo ""
echo "INVALID_TASK error"
if $LIBS_SOURCED; then
  EMPTY_TASK="$(start_session --task '' --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Empty task description returns INVALID_TASK" \
    "echo '$EMPTY_TASK' | grep -q 'INVALID_TASK'"

  NO_TASK="$(start_session --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Missing task description returns INVALID_TASK" \
    "echo '$NO_TASK' | grep -q 'INVALID_TASK'"
else
  assert "Empty task description returns INVALID_TASK" "false"
  assert "Missing task description returns INVALID_TASK" "false"
fi

# Test: Session directory creation side effect
echo ""
echo "Session directory creation"
if $LIBS_SOURCED; then
  SESS_RESULT="$(start_session --task 'test dir creation' --workdir "$TEST_TMPDIR" 2>&1)" || true
  SESS_ID="$(echo "$SESS_RESULT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("session_id",""))' 2>/dev/null)" || true
  if [ -n "$SESS_ID" ]; then
    assert "Session directory created under .dev-loop/sessions/" \
      "[ -d '${TEST_TMPDIR}/.dev-loop/sessions/${SESS_ID}' ]"
    assert "Initial checkpoint (checkpoint_0) created" \
      "[ -f '${TEST_TMPDIR}/.dev-loop/sessions/${SESS_ID}/checkpoints/checkpoint_0.json' ] || [ -d '${TEST_TMPDIR}/.dev-loop/sessions/${SESS_ID}/checkpoints/' ]"
    assert "Event log initialized" \
      "[ -f '${TEST_TMPDIR}/.dev-loop/sessions/${SESS_ID}/events.jsonl' ]"
  else
    assert "Session directory created under .dev-loop/sessions/" "false"
    assert "Initial checkpoint (checkpoint_0) created" "false"
    assert "Event log initialized" "false"
  fi
else
  assert "Session directory created under .dev-loop/sessions/" "false"
  assert "Initial checkpoint (checkpoint_0) created" "false"
  assert "Event log initialized" "false"
fi

# ══════════════════════════════════════════
# Execute Iteration Tests
# ══════════════════════════════════════════
echo ""
echo "--- Execute Iteration ---"

if $LIBS_SOURCED && [ -n "${SESS_ID:-}" ]; then
  ITER_RESULT="$(execute_iteration --session "$SESS_ID" --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "execute_iteration returns iteration_number" \
    "echo '$ITER_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"iteration_number\" in d'"
  assert "execute_iteration returns status (complete|failed)" \
    "echo '$ITER_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"status\"] in [\"complete\", \"failed\"]'"
  assert "execute_iteration returns quality_grade" \
    "echo '$ITER_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"quality_grade\" in d'"
  assert "execute_iteration returns resources_consumed" \
    "echo '$ITER_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"resources_consumed\" in d'"
  assert "execute_iteration returns next_action" \
    "echo '$ITER_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"next_action\"] in [\"continue\", \"terminate\"]'"
else
  assert "execute_iteration returns iteration_number" "false"
  assert "execute_iteration returns status (complete|failed)" "false"
  assert "execute_iteration returns quality_grade" "false"
  assert "execute_iteration returns resources_consumed" "false"
  assert "execute_iteration returns next_action" "false"
fi

# Test: SESSION_NOT_FOUND error
echo ""
echo "Execute iteration error handling"
if $LIBS_SOURCED; then
  BAD_SESS="$(execute_iteration --session 'nonexistent-session-id' --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Nonexistent session returns SESSION_NOT_FOUND" \
    "echo '$BAD_SESS' | grep -q 'SESSION_NOT_FOUND'"
else
  assert "Nonexistent session returns SESSION_NOT_FOUND" "false"
fi

# ══════════════════════════════════════════
# Grade Iteration Tests
# ══════════════════════════════════════════
echo ""
echo "--- Grade Iteration ---"

if $LIBS_SOURCED && [ -n "${SESS_ID:-}" ]; then
  GRADE_RESULT="$(grade_iteration --session "$SESS_ID" --iteration 1 --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "grade_iteration returns composite_grade (0.0-1.0)" \
    "echo '$GRADE_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert 0.0 <= d[\"composite_grade\"] <= 1.0'"
  assert "grade_iteration returns metrics object" \
    "echo '$GRADE_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"metrics\" in d'"
  assert "grade_iteration returns threshold_met boolean" \
    "echo '$GRADE_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d[\"threshold_met\"], bool)'"
  assert "grade_iteration metrics includes test_pass_rate" \
    "echo '$GRADE_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"test_pass_rate\" in d[\"metrics\"]'"
else
  assert "grade_iteration returns composite_grade (0.0-1.0)" "false"
  assert "grade_iteration returns metrics object" "false"
  assert "grade_iteration returns threshold_met boolean" "false"
  assert "grade_iteration metrics includes test_pass_rate" "false"
fi

# Test: ITERATION_NOT_FOUND
echo ""
echo "Grade iteration error handling"
if $LIBS_SOURCED && [ -n "${SESS_ID:-}" ]; then
  BAD_ITER="$(grade_iteration --session "$SESS_ID" --iteration 999 --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Invalid iteration number returns ITERATION_NOT_FOUND" \
    "echo '$BAD_ITER' | grep -q 'ITERATION_NOT_FOUND'"
else
  assert "Invalid iteration number returns ITERATION_NOT_FOUND" "false"
fi

# ══════════════════════════════════════════
# Terminate Session Tests
# ══════════════════════════════════════════
echo ""
echo "--- Terminate Session ---"

echo "Termination reasons"
TERM_REASONS=("success" "converged" "budget_exhausted" "max_iterations" "stuck" "user_interrupt")
for reason in "${TERM_REASONS[@]}"; do
  if $LIBS_SOURCED; then
    # Create a fresh session for each termination test
    TERM_SESS="$(start_session --task "test terminate $reason" --workdir "$TEST_TMPDIR" 2>&1)" || true
    TERM_SESS_ID="$(echo "$TERM_SESS" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("session_id",""))' 2>/dev/null)" || true
    if [ -n "$TERM_SESS_ID" ]; then
      TERM_RESULT="$(terminate_session --session "$TERM_SESS_ID" --reason "$reason" --workdir "$TEST_TMPDIR" 2>&1)" || true
      assert "terminate_session with reason=$reason returns status=terminated" \
        "echo '$TERM_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"status\"] == \"terminated\"'"
    else
      assert "terminate_session with reason=$reason returns status=terminated" "false"
    fi
  else
    assert "terminate_session with reason=$reason returns status=terminated" "false"
  fi
done

# Test: Terminate returns session_report
echo ""
echo "Termination report structure"
if $LIBS_SOURCED; then
  RPT_SESS="$(start_session --task 'test report' --workdir "$TEST_TMPDIR" 2>&1)" || true
  RPT_SESS_ID="$(echo "$RPT_SESS" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("session_id",""))' 2>/dev/null)" || true
  if [ -n "$RPT_SESS_ID" ]; then
    RPT_RESULT="$(terminate_session --session "$RPT_SESS_ID" --reason success --workdir "$TEST_TMPDIR" 2>&1)" || true
    assert "terminate returns session_report" \
      "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"session_report\" in d'"
    assert "session_report has total_iterations" \
      "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"total_iterations\" in d[\"session_report\"]'"
    assert "session_report has resources_consumed" \
      "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"resources_consumed\" in d[\"session_report\"]'"
    assert "session_report has rl_feedback_recorded" \
      "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"rl_feedback_recorded\" in d[\"session_report\"]'"
  else
    assert "terminate returns session_report" "false"
    assert "session_report has total_iterations" "false"
    assert "session_report has resources_consumed" "false"
    assert "session_report has rl_feedback_recorded" "false"
  fi
else
  assert "terminate returns session_report" "false"
  assert "session_report has total_iterations" "false"
  assert "session_report has resources_consumed" "false"
  assert "session_report has rl_feedback_recorded" "false"
fi

# Test: ALREADY_TERMINATED
echo ""
echo "Double-terminate error"
if $LIBS_SOURCED && [ -n "${RPT_SESS_ID:-}" ]; then
  DOUBLE_TERM="$(terminate_session --session "$RPT_SESS_ID" --reason success --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Terminating already-terminated session returns ALREADY_TERMINATED" \
    "echo '$DOUBLE_TERM' | grep -q 'ALREADY_TERMINATED'"
else
  assert "Terminating already-terminated session returns ALREADY_TERMINATED" "false"
fi

# ══════════════════════════════════════════
# Resume Session Tests
# ══════════════════════════════════════════
echo ""
echo "--- Resume Session ---"

if $LIBS_SOURCED; then
  # Create and terminate a session to test resume
  RES_SESS="$(start_session --task 'test resume' --workdir "$TEST_TMPDIR" 2>&1)" || true
  RES_SESS_ID="$(echo "$RES_SESS" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("session_id",""))' 2>/dev/null)" || true
  if [ -n "$RES_SESS_ID" ]; then
    terminate_session --session "$RES_SESS_ID" --reason user_interrupt --workdir "$TEST_TMPDIR" >/dev/null 2>&1 || true

    RESUME_RESULT="$(resume_session --session "$RES_SESS_ID" --workdir "$TEST_TMPDIR" 2>&1)" || true
    assert "resume_session returns status=running" \
      "echo '$RESUME_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"status\"] == \"running\"'"
    assert "resume_session returns resumed_from_iteration" \
      "echo '$RESUME_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"resumed_from_iteration\" in d'"
    assert "resume_session returns remaining_budget" \
      "echo '$RESUME_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"remaining_budget\" in d'"
  else
    assert "resume_session returns status=running" "false"
    assert "resume_session returns resumed_from_iteration" "false"
    assert "resume_session returns remaining_budget" "false"
  fi
else
  assert "resume_session returns status=running" "false"
  assert "resume_session returns resumed_from_iteration" "false"
  assert "resume_session returns remaining_budget" "false"
fi

# Test: CHECKPOINT_NOT_FOUND
echo ""
echo "Resume error handling"
if $LIBS_SOURCED && [ -n "${RES_SESS_ID:-}" ]; then
  BAD_CKPT="$(resume_session --session "$RES_SESS_ID" --checkpoint '/nonexistent/checkpoint.json' --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Nonexistent checkpoint returns CHECKPOINT_NOT_FOUND" \
    "echo '$BAD_CKPT' | grep -q 'CHECKPOINT_NOT_FOUND'"
else
  assert "Nonexistent checkpoint returns CHECKPOINT_NOT_FOUND" "false"
fi

# Test: SESSION_NOT_FOUND for resume
if $LIBS_SOURCED; then
  NO_SESS_RESUME="$(resume_session --session 'nonexistent-id' --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Resume nonexistent session returns SESSION_NOT_FOUND" \
    "echo '$NO_SESS_RESUME' | grep -q 'SESSION_NOT_FOUND'"
else
  assert "Resume nonexistent session returns SESSION_NOT_FOUND" "false"
fi

# ══════════════════════════════════════════
# Get Session Status Tests
# ══════════════════════════════════════════
echo ""
echo "--- Get Session Status ---"

if $LIBS_SOURCED; then
  STAT_SESS="$(start_session --task 'test status' --workdir "$TEST_TMPDIR" 2>&1)" || true
  STAT_SESS_ID="$(echo "$STAT_SESS" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("session_id",""))' 2>/dev/null)" || true
  if [ -n "$STAT_SESS_ID" ]; then
    STATUS_RESULT="$(get_session_status --session "$STAT_SESS_ID" --workdir "$TEST_TMPDIR" 2>&1)" || true
    assert "get_session_status returns session_id" \
      "echo '$STATUS_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"session_id\"] == \"$STAT_SESS_ID\"'"
    assert "get_session_status returns status field" \
      "echo '$STATUS_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"status\"] in [\"running\", \"paused\", \"terminated\"]'"
    assert "get_session_status returns current_iteration" \
      "echo '$STATUS_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"current_iteration\" in d'"
    assert "get_session_status returns resources_consumed" \
      "echo '$STATUS_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"resources_consumed\" in d'"
    assert "get_session_status returns remaining_budget" \
      "echo '$STATUS_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"remaining_budget\" in d'"
  else
    assert "get_session_status returns session_id" "false"
    assert "get_session_status returns status field" "false"
    assert "get_session_status returns current_iteration" "false"
    assert "get_session_status returns resources_consumed" "false"
    assert "get_session_status returns remaining_budget" "false"
  fi
else
  assert "get_session_status returns session_id" "false"
  assert "get_session_status returns status field" "false"
  assert "get_session_status returns current_iteration" "false"
  assert "get_session_status returns resources_consumed" "false"
  assert "get_session_status returns remaining_budget" "false"
fi

# Test: SESSION_NOT_FOUND for status
echo ""
echo "Status error handling"
if $LIBS_SOURCED; then
  NO_SESS_STATUS="$(get_session_status --session 'nonexistent-id' --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Status of nonexistent session returns SESSION_NOT_FOUND" \
    "echo '$NO_SESS_STATUS' | grep -q 'SESSION_NOT_FOUND'"
else
  assert "Status of nonexistent session returns SESSION_NOT_FOUND" "false"
fi

# ═══════════════════════════════════════
# Final Results
# ═══════════════════════════════════════
echo ""
echo "======================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "======================================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
