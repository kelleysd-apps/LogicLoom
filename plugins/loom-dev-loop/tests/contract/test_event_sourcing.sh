#!/usr/bin/env bash
# Contract Tests: Event Sourcing and Session Reports
# TDD tests for event-logger.sh, session report generation, and session replay
# Tests: log_event, query_events, count_events, close_log,
#        generate_session_report, reconstruct_state, extract_rl_signals,
#        generate_audit_trail
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
# NOTE: This runs in a subshell, so it cannot modify parent state.
# For functions that depend on module state (log_event, query_events, etc.),
# call them directly instead.
safe_call() {
  local result=""
  result="$( set +eu; "$@" 2>/dev/null )" || true
  echo "$result"
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

echo "=== Event Sourcing & Session Report Contract Tests ==="
echo ""

# ── Library Existence ──
echo "Library file existence"
assert "event-logger.sh exists" "[ -f '${LIB_DIR}/event-logger.sh' ]"

# Source library (tolerant of partially-implemented libs)
LIBS_SOURCED=false
if [ -f "${LIB_DIR}/event-logger.sh" ]; then
  set +eu
  source "${LIB_DIR}/event-logger.sh" 2>/dev/null || true
  set -eo pipefail
  LIBS_SOURCED=true
fi

# ── Function Existence ──
echo ""
echo "Function existence (event-logger.sh)"
assert "init_event_log function exists" "type -t init_event_log 2>/dev/null | grep -q function"
assert "log_event function exists" "type -t log_event 2>/dev/null | grep -q function"
assert "query_events function exists" "type -t query_events 2>/dev/null | grep -q function"
assert "count_events function exists" "type -t count_events 2>/dev/null | grep -q function"
assert "close_log function exists" "type -t close_log 2>/dev/null | grep -q function"

echo ""
echo "Function existence (session report and replay)"
assert "generate_session_report function exists" "type -t generate_session_report 2>/dev/null | grep -q function"
assert "reconstruct_state function exists" "type -t reconstruct_state 2>/dev/null | grep -q function"
assert "extract_rl_signals function exists" "type -t extract_rl_signals 2>/dev/null | grep -q function"
assert "generate_audit_trail function exists" "type -t generate_audit_trail 2>/dev/null | grep -q function"

# ══════════════════════════════════════════
# Event Logging Tests
# ══════════════════════════════════════════
echo ""
echo "--- Event Logging: All 8 Event Types ---"

TEST_SESSION_ID="test-session-$(date +%s)"
TEST_SESSION_DIR="${TEST_TMPDIR}/sessions/${TEST_SESSION_ID}"
LOG_FILE=""

if $LIBS_SOURCED; then
  # init_event_log sets module-level state (_EVENT_LOG_FILE, _EVENT_LOG_SESSION_ID).
  # We must NOT capture its output via $() since that runs in a subshell and
  # the state changes would be lost. Instead, call it and let it print to stdout,
  # then derive the log file path from the known convention.
  init_event_log "$TEST_SESSION_ID" "$TEST_SESSION_DIR" >/dev/null 2>&1 || true
  LOG_FILE="${TEST_SESSION_DIR}/events.jsonl"
  assert "init_event_log creates events.jsonl" "[ -f '${LOG_FILE}' ]"
else
  assert "init_event_log creates events.jsonl" "false"
fi

# Test all 8 event types — log_event depends on module state set by init_event_log,
# so we must call it directly (not via safe_call subshell)
EVENT_TYPES=("thought" "action" "observation" "decision" "tool_invocation" "grade" "vote" "error")

for etype in "${EVENT_TYPES[@]}"; do
  if $LIBS_SOURCED && [ -n "$LOG_FILE" ]; then
    EVT_ID="$(log_event "$etype" 1 "Test $etype event" '{"test_key":"test_value"}' 2>/dev/null)" || true
    assert "log_event type=$etype returns event_id" \
      "[ -n '${EVT_ID}' ]"
  else
    assert "log_event type=$etype returns event_id" "false"
  fi
done

echo ""
echo "Event required fields"
if $LIBS_SOURCED && [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
  # Read the first event line and validate required fields
  FIRST_EVENT="$(head -1 "$LOG_FILE" 2>/dev/null)"
  assert "Event has timestamp field" \
    "echo '$FIRST_EVENT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"timestamp\" in d'"
  assert "Event has session_id field" \
    "echo '$FIRST_EVENT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"session_id\" in d'"
  assert "Event has iteration field" \
    "echo '$FIRST_EVENT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"iteration\" in d'"
  assert "Event has event_type field" \
    "echo '$FIRST_EVENT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"event_type\" in d'"
  assert "Event has content field" \
    "echo '$FIRST_EVENT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"content\" in d'"
  assert "Event has metadata field" \
    "echo '$FIRST_EVENT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"metadata\" in d'"
  assert "Event session_id matches initialized session" \
    "echo '$FIRST_EVENT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"session_id\"] == \"$TEST_SESSION_ID\"'"
else
  assert "Event has timestamp field" "false"
  assert "Event has session_id field" "false"
  assert "Event has iteration field" "false"
  assert "Event has event_type field" "false"
  assert "Event has content field" "false"
  assert "Event has metadata field" "false"
  assert "Event session_id matches initialized session" "false"
fi

echo ""
echo "JSONL format validation (each line is valid JSON)"
if $LIBS_SOURCED && [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
  # Validate every line is parseable JSON
  ALL_VALID=true
  LINE_COUNT=0
  while IFS= read -r line; do
    LINE_COUNT=$((LINE_COUNT + 1))
    if ! echo "$line" | jq empty 2>/dev/null; then
      ALL_VALID=false
    fi
  done < "$LOG_FILE"
  assert "All $LINE_COUNT event lines are valid JSON" \
    "[ '$ALL_VALID' = 'true' ]"
  assert "Event log contains 8 event lines (one per type)" \
    "[ '$LINE_COUNT' -eq 8 ]"
else
  assert "All event lines are valid JSON" "false"
  assert "Event log contains 8 event lines (one per type)" "false"
fi

echo ""
echo "Chronological ordering enforced"
if $LIBS_SOURCED && [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
  # Verify timestamps are in non-decreasing order
  CHRONO_OK="$(python3 -c "
import json, sys
events = [json.loads(line) for line in open('$LOG_FILE')]
timestamps = [e['timestamp'] for e in events]
print('true' if timestamps == sorted(timestamps) else 'false')
" 2>/dev/null)" || true
  assert "Events are in chronological order (non-decreasing timestamps)" \
    "[ '${CHRONO_OK}' = 'true' ]"
else
  assert "Events are in chronological order (non-decreasing timestamps)" "false"
fi

echo ""
echo "Invalid event type rejection"
if $LIBS_SOURCED && [ -n "$LOG_FILE" ]; then
  INVALID_RESULT="$(log_event "invalid_type" 1 "Should fail" '{}' 2>&1)" || true
  assert "Invalid event type is rejected with error" \
    "echo '$INVALID_RESULT' | grep -qi 'invalid\|error'"
else
  assert "Invalid event type is rejected with error" "false"
fi

# ══════════════════════════════════════════
# Event Query Tests
# ══════════════════════════════════════════
echo ""
echo "--- Event Query by Type ---"

if $LIBS_SOURCED && [ -n "$LOG_FILE" ]; then
  # Query for a specific type — query_events reads from _EVENT_LOG_FILE (module state)
  THOUGHT_EVENTS="$(query_events --type thought 2>/dev/null)" || true
  THOUGHT_COUNT="$(echo "$THOUGHT_EVENTS" | grep -c '.' 2>/dev/null || echo 0)"
  assert "query_events --type thought returns only thought events" \
    "[ '$THOUGHT_COUNT' -eq 1 ]"

  # Verify the returned event actually has the correct type
  if [ -n "$THOUGHT_EVENTS" ]; then
    assert "Queried thought event has event_type=thought" \
      "echo '$THOUGHT_EVENTS' | head -1 | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"event_type\"] == \"thought\"'"
  else
    assert "Queried thought event has event_type=thought" "false"
  fi

  # Query for grade events
  GRADE_EVENTS="$(query_events --type grade 2>/dev/null)" || true
  GRADE_COUNT="$(echo "$GRADE_EVENTS" | grep -c '.' 2>/dev/null || echo 0)"
  assert "query_events --type grade returns only grade events" \
    "[ '$GRADE_COUNT' -eq 1 ]"

  # Log additional events at different iterations for range and count tests
  log_event "thought" 2 "Iteration 2 thought" '{}' >/dev/null 2>&1 || true
  log_event "action" 2 "Iteration 2 action" '{}' >/dev/null 2>&1 || true
  log_event "thought" 3 "Iteration 3 thought" '{}' >/dev/null 2>&1 || true
  log_event "grade" 3 "Iteration 3 grade" '{"composite_grade":0.85}' >/dev/null 2>&1 || true
else
  assert "query_events --type thought returns only thought events" "false"
  assert "Queried thought event has event_type=thought" "false"
  assert "query_events --type grade returns only grade events" "false"
fi

echo ""
echo "--- Event Query by Iteration Range ---"

if $LIBS_SOURCED && [ -n "$LOG_FILE" ]; then
  # Query events in iteration range 2-3 (should be 4: thought@2, action@2, thought@3, grade@3)
  RANGE_EVENTS="$(query_events --from 2 --to 3 2>/dev/null)" || true
  RANGE_COUNT="$(echo "$RANGE_EVENTS" | grep -c '.' 2>/dev/null || echo 0)"
  assert "query_events --from 2 --to 3 returns correct subset" \
    "[ '$RANGE_COUNT' -eq 4 ]"

  # Verify all returned events have iterations in range
  RANGE_VALID="$(echo "$RANGE_EVENTS" | python3 -c "
import json, sys
lines = [line for line in sys.stdin if line.strip()]
events = [json.loads(line) for line in lines]
all_in_range = all(2 <= e['iteration'] <= 3 for e in events)
print('true' if all_in_range else 'false')
" 2>/dev/null)" || true
  assert "All events in iteration range have iteration 2-3" \
    "[ '${RANGE_VALID}' = 'true' ]"

  # Query events only at iteration 1 (8 original events)
  ITER1_EVENTS="$(query_events --from 1 --to 1 2>/dev/null)" || true
  ITER1_COUNT="$(echo "$ITER1_EVENTS" | grep -c '.' 2>/dev/null || echo 0)"
  assert "query_events --from 1 --to 1 returns iteration 1 events only" \
    "[ '$ITER1_COUNT' -eq 8 ]"

  # Combined type + iteration filter
  THOUGHT_ITER2="$(query_events --type thought --from 2 --to 2 2>/dev/null)" || true
  THOUGHT_ITER2_COUNT="$(echo "$THOUGHT_ITER2" | grep -c '.' 2>/dev/null || echo 0)"
  assert "query_events --type thought --from 2 --to 2 returns 1 event" \
    "[ '$THOUGHT_ITER2_COUNT' -eq 1 ]"
else
  assert "query_events --from 2 --to 3 returns correct subset" "false"
  assert "All events in iteration range have iteration 2-3" "false"
  assert "query_events --from 1 --to 1 returns iteration 1 events only" "false"
  assert "query_events --type thought --from 2 --to 2 returns 1 event" "false"
fi

# ══════════════════════════════════════════
# Event Count Tests
# ══════════════════════════════════════════
echo ""
echo "--- Event Count by Type ---"

if $LIBS_SOURCED && [ -n "$LOG_FILE" ]; then
  # Count specific types (8 original at iter 1 + 4 additional = 12 total)
  # thought: 1@iter1 + 1@iter2 + 1@iter3 = 3
  THOUGHT_CNT="$(count_events thought 2>/dev/null)" || true
  assert "count_events thought returns 3 (logged 3 thought events)" \
    "[ '${THOUGHT_CNT}' -eq 3 ]"

  # grade: 1@iter1 + 1@iter3 = 2
  GRADE_CNT="$(count_events grade 2>/dev/null)" || true
  assert "count_events grade returns 2 (logged 2 grade events)" \
    "[ '${GRADE_CNT}' -eq 2 ]"

  # action: 1@iter1 + 1@iter2 = 2
  ACTION_CNT="$(count_events action 2>/dev/null)" || true
  assert "count_events action returns 2 (logged 2 action events)" \
    "[ '${ACTION_CNT}' -eq 2 ]"

  # Count all types (returns JSON object)
  ALL_COUNTS="$(count_events 2>/dev/null)" || true
  assert "count_events (no arg) returns JSON object" \
    "echo '$ALL_COUNTS' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d, dict)'"
  assert "count_events all-types includes thought key" \
    "echo '$ALL_COUNTS' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"thought\" in d'"
  assert "count_events all-types thought count is 3" \
    "echo '$ALL_COUNTS' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"thought\"] == 3'"
else
  assert "count_events thought returns 3 (logged 3 thought events)" "false"
  assert "count_events grade returns 2 (logged 2 grade events)" "false"
  assert "count_events action returns 2 (logged 2 action events)" "false"
  assert "count_events (no arg) returns JSON object" "false"
  assert "count_events all-types includes thought key" "false"
  assert "count_events all-types thought count is 3" "false"
fi

# ══════════════════════════════════════════
# close_log Validation Tests
# ══════════════════════════════════════════
echo ""
echo "--- close_log Validation ---"

# Test close_log on the populated log (12 events: 8 original + 4 additional)
if $LIBS_SOURCED && [ -n "$LOG_FILE" ]; then
  CLOSE_RESULT="$(close_log 2>/dev/null)" || true
  assert "close_log returns JSON with valid=true for well-formed log" \
    "echo '$CLOSE_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"valid\"] == True'"
  assert "close_log returns total_lines count" \
    "echo '$CLOSE_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"total_lines\"] == 12'"
  assert "close_log returns empty invalid_lines array" \
    "echo '$CLOSE_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"invalid_lines\"] == []'"
  assert "close_log returns path field" \
    "echo '$CLOSE_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"path\" in d'"
else
  assert "close_log returns JSON with valid=true for well-formed log" "false"
  assert "close_log returns total_lines count" "false"
  assert "close_log returns empty invalid_lines array" "false"
  assert "close_log returns path field" "false"
fi

# ══════════════════════════════════════════
# Session Report Tests
# ══════════════════════════════════════════
echo ""
echo "--- Session Report ---"

# Create a fresh session with events across multiple iterations for report testing
RPT_SESSION_ID="report-session-$(date +%s)"
RPT_SESSION_DIR="${TEST_TMPDIR}/sessions/${RPT_SESSION_ID}"
RPT_LOG=""

if $LIBS_SOURCED; then
  init_event_log "$RPT_SESSION_ID" "$RPT_SESSION_DIR" >/dev/null 2>&1 || true
  RPT_LOG="${RPT_SESSION_DIR}/events.jsonl"

  # Iteration 1 events
  log_event "thought" 1 "Analyzing task requirements" '{}' >/dev/null 2>&1 || true
  log_event "action" 1 "Created initial implementation" '{"files_modified":["src/auth.ts"],"lines_added":45,"lines_removed":0}' >/dev/null 2>&1 || true
  log_event "tool_invocation" 1 "Running test suite" '{"tool":"bash","command":"npm test"}' >/dev/null 2>&1 || true
  log_event "observation" 1 "Tests: 8 passed, 2 failed" '{}' >/dev/null 2>&1 || true
  log_event "grade" 1 "Quality grade computed" '{"composite_grade":0.72,"metrics":{"test_pass_rate":0.80,"coverage":0.65}}' >/dev/null 2>&1 || true
  log_event "decision" 1 "Continue: below threshold" '{"next_action":"continue","threshold":0.95}' >/dev/null 2>&1 || true

  # Iteration 2 events
  log_event "thought" 2 "Fixing failing tests" '{}' >/dev/null 2>&1 || true
  log_event "action" 2 "Updated auth handler" '{"files_modified":["src/auth.ts","src/middleware.ts"],"lines_added":22,"lines_removed":8}' >/dev/null 2>&1 || true
  log_event "tool_invocation" 2 "Running test suite" '{"tool":"bash","command":"npm test","model":"opus","tokens":15000}' >/dev/null 2>&1 || true
  log_event "observation" 2 "Tests: 10 passed, 0 failed" '{}' >/dev/null 2>&1 || true
  log_event "grade" 2 "Quality grade computed" '{"composite_grade":0.96,"metrics":{"test_pass_rate":1.0,"coverage":0.88}}' >/dev/null 2>&1 || true
  log_event "vote" 2 "Tribunal vote: approve" '{"ballot":{"judge_1":"approve","judge_2":"approve","judge_3":"approve"},"verdict":"approved","confidence":0.95}' >/dev/null 2>&1 || true
  log_event "decision" 2 "Terminate: threshold met" '{"next_action":"terminate","reason":"success","threshold":0.95}' >/dev/null 2>&1 || true
fi

echo ""
echo "Report includes iteration count"
if $LIBS_SOURCED && [ -n "$RPT_LOG" ]; then
  RPT_RESULT="$(safe_call generate_session_report "$RPT_SESSION_ID" "$RPT_SESSION_DIR")"
  assert "Report contains iteration_count field" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"iteration_count\" in d'"
  assert "Report iteration_count is 2" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"iteration_count\"] == 2'"
else
  assert "Report contains iteration_count field" "false"
  assert "Report iteration_count is 2" "false"
fi

echo ""
echo "Report includes grade trajectory"
if $LIBS_SOURCED && [ -n "$RPT_LOG" ]; then
  assert "Report contains grade_trajectory field" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"grade_trajectory\" in d'"
  assert "grade_trajectory is list of per-iteration scores" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); t=d[\"grade_trajectory\"]; assert isinstance(t, list) and len(t) == 2'"
  assert "grade_trajectory first iteration is 0.72" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert abs(d[\"grade_trajectory\"][0] - 0.72) < 0.01'"
  assert "grade_trajectory second iteration is 0.96" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert abs(d[\"grade_trajectory\"][1] - 0.96) < 0.01'"
else
  assert "Report contains grade_trajectory field" "false"
  assert "grade_trajectory is list of per-iteration scores" "false"
  assert "grade_trajectory first iteration is 0.72" "false"
  assert "grade_trajectory second iteration is 0.96" "false"
fi

echo ""
echo "Report includes tribunal decisions"
if $LIBS_SOURCED && [ -n "$RPT_LOG" ]; then
  assert "Report contains tribunal_decisions field" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"tribunal_decisions\" in d'"
  assert "tribunal_decisions is a list" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d[\"tribunal_decisions\"], list)'"
  assert "tribunal_decisions contains ballot details" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); v=d[\"tribunal_decisions\"][0]; assert \"ballot\" in v or \"verdict\" in v'"
else
  assert "Report contains tribunal_decisions field" "false"
  assert "tribunal_decisions is a list" "false"
  assert "tribunal_decisions contains ballot details" "false"
fi

echo ""
echo "Report includes resources consumed per model"
if $LIBS_SOURCED && [ -n "$RPT_LOG" ]; then
  assert "Report contains resources_consumed field" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"resources_consumed\" in d'"
  assert "resources_consumed includes tokens_by_model" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"tokens_by_model\" in d[\"resources_consumed\"]'"
  assert "resources_consumed includes cost_by_model" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"cost_by_model\" in d[\"resources_consumed\"]'"
else
  assert "Report contains resources_consumed field" "false"
  assert "resources_consumed includes tokens_by_model" "false"
  assert "resources_consumed includes cost_by_model" "false"
fi

echo ""
echo "Report includes wall-clock time"
if $LIBS_SOURCED && [ -n "$RPT_LOG" ]; then
  assert "Report contains wall_clock_seconds field" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"wall_clock_seconds\" in d'"
  assert "wall_clock_seconds is a non-negative number" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"wall_clock_seconds\"] >= 0'"
else
  assert "Report contains wall_clock_seconds field" "false"
  assert "wall_clock_seconds is a non-negative number" "false"
fi

echo ""
echo "Report includes code changes summary"
if $LIBS_SOURCED && [ -n "$RPT_LOG" ]; then
  assert "Report contains code_changes field" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"code_changes\" in d'"
  assert "code_changes includes files_modified" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"files_modified\" in d[\"code_changes\"]'"
  assert "code_changes includes lines_added" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"lines_added\" in d[\"code_changes\"]'"
  assert "code_changes includes lines_removed" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"lines_removed\" in d[\"code_changes\"]'"
else
  assert "Report contains code_changes field" "false"
  assert "code_changes includes files_modified" "false"
  assert "code_changes includes lines_added" "false"
  assert "code_changes includes lines_removed" "false"
fi

echo ""
echo "Report includes termination reason"
if $LIBS_SOURCED && [ -n "$RPT_LOG" ]; then
  assert "Report contains termination_reason field" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"termination_reason\" in d'"
  assert "termination_reason is 'success'" \
    "echo '$RPT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"termination_reason\"] == \"success\"'"
else
  assert "Report contains termination_reason field" "false"
  assert "termination_reason is 'success'" "false"
fi

# ── Edge Case: Empty Event Log Report ──
echo ""
echo "Report from empty event log (edge case)"
if $LIBS_SOURCED; then
  EMPTY_SESSION_ID="empty-session-$(date +%s)"
  EMPTY_SESSION_DIR="${TEST_TMPDIR}/sessions/${EMPTY_SESSION_ID}"
  init_event_log "$EMPTY_SESSION_ID" "$EMPTY_SESSION_DIR" >/dev/null 2>&1 || true

  EMPTY_RPT="$(safe_call generate_session_report "$EMPTY_SESSION_ID" "$EMPTY_SESSION_DIR")"
  assert "Empty log report returns valid JSON" \
    "echo '$EMPTY_RPT' | python3 -c 'import json,sys; json.load(sys.stdin)'"
  assert "Empty log report has iteration_count=0" \
    "echo '$EMPTY_RPT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"iteration_count\"] == 0'"
  assert "Empty log report has empty grade_trajectory" \
    "echo '$EMPTY_RPT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"grade_trajectory\"] == []'"
  assert "Empty log report has empty tribunal_decisions" \
    "echo '$EMPTY_RPT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"tribunal_decisions\"] == []'"
else
  assert "Empty log report returns valid JSON" "false"
  assert "Empty log report has iteration_count=0" "false"
  assert "Empty log report has empty grade_trajectory" "false"
  assert "Empty log report has empty tribunal_decisions" "false"
fi

# ── Edge Case: Single-Iteration Report ──
echo ""
echo "Report from single-iteration log"
if $LIBS_SOURCED; then
  SINGLE_SESSION_ID="single-session-$(date +%s)"
  SINGLE_SESSION_DIR="${TEST_TMPDIR}/sessions/${SINGLE_SESSION_ID}"
  init_event_log "$SINGLE_SESSION_ID" "$SINGLE_SESSION_DIR" >/dev/null 2>&1 || true

  log_event "thought" 1 "Only iteration" '{}' >/dev/null 2>&1 || true
  log_event "grade" 1 "Only grade" '{"composite_grade":0.50}' >/dev/null 2>&1 || true
  log_event "decision" 1 "Terminate" '{"next_action":"terminate","reason":"budget_exhausted"}' >/dev/null 2>&1 || true

  SINGLE_RPT="$(safe_call generate_session_report "$SINGLE_SESSION_ID" "$SINGLE_SESSION_DIR")"
  assert "Single-iteration report returns valid JSON" \
    "echo '$SINGLE_RPT' | python3 -c 'import json,sys; json.load(sys.stdin)'"
  assert "Single-iteration report has iteration_count=1" \
    "echo '$SINGLE_RPT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"iteration_count\"] == 1'"
  assert "Single-iteration report grade_trajectory has 1 entry" \
    "echo '$SINGLE_RPT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d[\"grade_trajectory\"]) == 1'"
  assert "Single-iteration report termination_reason is budget_exhausted" \
    "echo '$SINGLE_RPT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"termination_reason\"] == \"budget_exhausted\"'"
else
  assert "Single-iteration report returns valid JSON" "false"
  assert "Single-iteration report has iteration_count=1" "false"
  assert "Single-iteration report grade_trajectory has 1 entry" "false"
  assert "Single-iteration report termination_reason is budget_exhausted" "false"
fi

# ══════════════════════════════════════════
# Session Replay Tests
# ══════════════════════════════════════════
echo ""
echo "--- Session Replay: Reconstruct State ---"

# Create a fresh session for replay tests
if $LIBS_SOURCED; then
  REPLAY_SESSION_ID="replay-session-$(date +%s)"
  REPLAY_SESSION_DIR="${TEST_TMPDIR}/sessions/${REPLAY_SESSION_ID}"
  init_event_log "$REPLAY_SESSION_ID" "$REPLAY_SESSION_DIR" >/dev/null 2>&1 || true

  # Build a multi-iteration event log for replay
  log_event "thought" 1 "Starting task" '{}' >/dev/null 2>&1 || true
  log_event "action" 1 "Created file" '{"files_modified":["src/a.ts"],"lines_added":10,"lines_removed":0}' >/dev/null 2>&1 || true
  log_event "grade" 1 "Grade" '{"composite_grade":0.60}' >/dev/null 2>&1 || true
  log_event "decision" 1 "Continue" '{"next_action":"continue"}' >/dev/null 2>&1 || true

  log_event "thought" 2 "Fixing tests" '{}' >/dev/null 2>&1 || true
  log_event "action" 2 "Updated file" '{"files_modified":["src/a.ts","src/b.ts"],"lines_added":20,"lines_removed":5}' >/dev/null 2>&1 || true
  log_event "grade" 2 "Grade" '{"composite_grade":0.80}' >/dev/null 2>&1 || true
  log_event "decision" 2 "Continue" '{"next_action":"continue"}' >/dev/null 2>&1 || true

  log_event "thought" 3 "Final polish" '{}' >/dev/null 2>&1 || true
  log_event "action" 3 "Polished code" '{"files_modified":["src/a.ts"],"lines_added":5,"lines_removed":2}' >/dev/null 2>&1 || true
  log_event "grade" 3 "Grade" '{"composite_grade":0.96}' >/dev/null 2>&1 || true
  log_event "decision" 3 "Terminate" '{"next_action":"terminate","reason":"success"}' >/dev/null 2>&1 || true
fi

echo ""
echo "Reconstruct state at specific iteration"
if $LIBS_SOURCED; then
  STATE_AT_2="$(safe_call reconstruct_state "$REPLAY_SESSION_ID" "$REPLAY_SESSION_DIR" --at-iteration 2)"
  assert "reconstruct_state at iteration 2 returns valid JSON" \
    "echo '$STATE_AT_2' | python3 -c 'import json,sys; json.load(sys.stdin)'"
  assert "reconstruct_state at iteration 2 includes events up to iteration 2" \
    "echo '$STATE_AT_2' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"current_iteration\"] == 2'"
  assert "reconstruct_state at iteration 2 includes grade 0.80" \
    "echo '$STATE_AT_2' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert abs(d[\"last_grade\"] - 0.80) < 0.01'"
  assert "reconstruct_state at iteration 2 does not include iteration 3 events" \
    "echo '$STATE_AT_2' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"current_iteration\"] <= 2'"
else
  assert "reconstruct_state at iteration 2 returns valid JSON" "false"
  assert "reconstruct_state at iteration 2 includes events up to iteration 2" "false"
  assert "reconstruct_state at iteration 2 includes grade 0.80" "false"
  assert "reconstruct_state at iteration 2 does not include iteration 3 events" "false"
fi

echo ""
echo "Reconstruct state at specific timestamp"
if $LIBS_SOURCED; then
  # Get the timestamp of the 8th event (last in iteration 2) from the log
  REPLAY_LOG="${REPLAY_SESSION_DIR}/events.jsonl"
  if [ -f "$REPLAY_LOG" ]; then
    CUTOFF_TS="$(python3 -c "
import json
events = [json.loads(l) for l in open('$REPLAY_LOG')]
# Take the timestamp of the 8th event (last in iteration 2)
print(events[7]['timestamp'] if len(events) > 7 else events[-1]['timestamp'])
" 2>/dev/null)" || true

    if [ -n "$CUTOFF_TS" ]; then
      STATE_AT_TS="$(safe_call reconstruct_state "$REPLAY_SESSION_ID" "$REPLAY_SESSION_DIR" --at-timestamp "$CUTOFF_TS")"
      assert "reconstruct_state at timestamp returns valid JSON" \
        "echo '$STATE_AT_TS' | python3 -c 'import json,sys; json.load(sys.stdin)'"
      assert "reconstruct_state at timestamp includes only events before cutoff" \
        "echo '$STATE_AT_TS' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"current_iteration\"] <= 2'"
    else
      assert "reconstruct_state at timestamp returns valid JSON" "false"
      assert "reconstruct_state at timestamp includes only events before cutoff" "false"
    fi
  else
    assert "reconstruct_state at timestamp returns valid JSON" "false"
    assert "reconstruct_state at timestamp includes only events before cutoff" "false"
  fi
else
  assert "reconstruct_state at timestamp returns valid JSON" "false"
  assert "reconstruct_state at timestamp includes only events before cutoff" "false"
fi

echo ""
echo "Replay produces consistent (deterministic) state"
if $LIBS_SOURCED; then
  STATE_RUN1="$(safe_call reconstruct_state "$REPLAY_SESSION_ID" "$REPLAY_SESSION_DIR" --at-iteration 2)"
  STATE_RUN2="$(safe_call reconstruct_state "$REPLAY_SESSION_ID" "$REPLAY_SESSION_DIR" --at-iteration 2)"
  assert "Two replays to iteration 2 produce identical state" \
    "[ '${STATE_RUN1}' = '${STATE_RUN2}' ]"
else
  assert "Two replays to iteration 2 produce identical state" "false"
fi

echo ""
echo "Replay of empty log returns initial state"
if $LIBS_SOURCED; then
  EMPTY_REPLAY_SESSION="empty-replay-$(date +%s)"
  EMPTY_REPLAY_DIR="${TEST_TMPDIR}/sessions/${EMPTY_REPLAY_SESSION}"
  init_event_log "$EMPTY_REPLAY_SESSION" "$EMPTY_REPLAY_DIR" >/dev/null 2>&1 || true

  EMPTY_STATE="$(safe_call reconstruct_state "$EMPTY_REPLAY_SESSION" "$EMPTY_REPLAY_DIR" --at-iteration 0)"
  assert "Empty log replay returns valid JSON" \
    "echo '$EMPTY_STATE' | python3 -c 'import json,sys; json.load(sys.stdin)'"
  assert "Empty log replay has current_iteration=0" \
    "echo '$EMPTY_STATE' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"current_iteration\"] == 0'"
  assert "Empty log replay has empty grade trajectory" \
    "echo '$EMPTY_STATE' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"grade_trajectory\", []) == []'"
else
  assert "Empty log replay returns valid JSON" "false"
  assert "Empty log replay has current_iteration=0" "false"
  assert "Empty log replay has empty grade trajectory" "false"
fi

# ══════════════════════════════════════════
# RL Signal Extraction Tests
# ══════════════════════════════════════════
echo ""
echo "--- RL Signal Extraction ---"

if $LIBS_SOURCED; then
  # Use the replay session which has a full lifecycle
  RL_SIGNALS="$(safe_call extract_rl_signals "$REPLAY_SESSION_ID" "$REPLAY_SESSION_DIR")"
  assert "extract_rl_signals returns valid JSON" \
    "echo '$RL_SIGNALS' | python3 -c 'import json,sys; json.load(sys.stdin)'"
  assert "RL signals include outcome field (success/failure)" \
    "echo '$RL_SIGNALS' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"outcome\"] in [\"success\",\"failure\"]'"
  assert "RL signals include skills_used list" \
    "echo '$RL_SIGNALS' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d.get(\"skills_used\", None), list)'"
  assert "RL signals include models_used list" \
    "echo '$RL_SIGNALS' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d.get(\"models_used\", None), list)'"
  assert "RL signals include total_tokens" \
    "echo '$RL_SIGNALS' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"total_tokens\" in d'"
  assert "RL signals include final_grade" \
    "echo '$RL_SIGNALS' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"final_grade\" in d'"
else
  assert "extract_rl_signals returns valid JSON" "false"
  assert "RL signals include outcome field (success/failure)" "false"
  assert "RL signals include skills_used list" "false"
  assert "RL signals include models_used list" "false"
  assert "RL signals include total_tokens" "false"
  assert "RL signals include final_grade" "false"
fi

# ══════════════════════════════════════════
# Audit Trail Generation Tests
# ══════════════════════════════════════════
echo ""
echo "--- Audit Trail Generation ---"

if $LIBS_SOURCED; then
  AUDIT="$(safe_call generate_audit_trail "$REPLAY_SESSION_ID" "$REPLAY_SESSION_DIR")"
  assert "generate_audit_trail returns valid JSON array" \
    "echo '$AUDIT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d, list)'"
  assert "Audit trail entries have timestamp" \
    "echo '$AUDIT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert all(\"timestamp\" in e for e in d)'"
  assert "Audit trail entries have action description" \
    "echo '$AUDIT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert all(\"action\" in e or \"content\" in e for e in d)'"
  assert "Audit trail is in chronological order" \
    "echo '$AUDIT' | python3 -c '
import json, sys
entries = json.load(sys.stdin)
timestamps = [e[\"timestamp\"] for e in entries]
assert timestamps == sorted(timestamps)
'"
  assert "Audit trail includes only autonomous actions (action/tool_invocation/decision types)" \
    "echo '$AUDIT' | python3 -c '
import json, sys
entries = json.load(sys.stdin)
valid_types = {\"action\", \"tool_invocation\", \"decision\"}
assert all(e.get(\"event_type\", e.get(\"type\", \"\")) in valid_types for e in entries)
'"
else
  assert "generate_audit_trail returns valid JSON array" "false"
  assert "Audit trail entries have timestamp" "false"
  assert "Audit trail entries have action description" "false"
  assert "Audit trail is in chronological order" "false"
  assert "Audit trail includes only autonomous actions (action/tool_invocation/decision types)" "false"
fi

# ══════════════════════════════════════════
# Performance Tests (NFR-007)
# ══════════════════════════════════════════
echo ""
echo "--- Performance Tests ---"

echo ""
echo "NFR-007: 50 iterations without degradation"
if $LIBS_SOURCED; then
  PERF_SESSION_ID="perf-session-$(date +%s)"
  PERF_SESSION_DIR="${TEST_TMPDIR}/sessions/${PERF_SESSION_ID}"
  init_event_log "$PERF_SESSION_ID" "$PERF_SESSION_DIR" >/dev/null 2>&1 || true

  # Log events for 50 iterations (4 events per iteration = 200 events)
  PERF_START="$(python3 -c 'import time; print(time.time())' 2>/dev/null)"
  for i in $(seq 1 50); do
    log_event "thought" "$i" "Iteration $i thought" '{}' >/dev/null 2>&1 || true
    log_event "action" "$i" "Iteration $i action" "{\"iter\":$i}" >/dev/null 2>&1 || true
    log_event "grade" "$i" "Iteration $i grade" "{\"composite_grade\":0.$((50 + i))}" >/dev/null 2>&1 || true
    log_event "decision" "$i" "Iteration $i decision" '{"next_action":"continue"}' >/dev/null 2>&1 || true
  done
  PERF_END="$(python3 -c 'import time; print(time.time())' 2>/dev/null)"

  PERF_LOG="${PERF_SESSION_DIR}/events.jsonl"
  PERF_LINE_COUNT="$(wc -l < "$PERF_LOG" | tr -d ' ')"
  assert "50 iterations produced 200 events" \
    "[ '$PERF_LINE_COUNT' -eq 200 ]"

  # Validate all lines are valid JSON (no corruption under load)
  PERF_VALID="$(python3 -c "
import json
valid = True
for line in open('$PERF_LOG'):
    try:
        json.loads(line)
    except:
        valid = False
        break
print('true' if valid else 'false')
" 2>/dev/null)" || true
  assert "All 200 event lines are valid JSON after 50 iterations" \
    "[ '${PERF_VALID}' = 'true' ]"

  # Total write time should be reasonable (under 60 seconds for 200 events)
  PERF_ELAPSED="$(python3 -c "print(float('${PERF_END}') - float('${PERF_START}'))" 2>/dev/null)" || true
  assert "200 events written in under 60 seconds (was: ${PERF_ELAPSED}s)" \
    "python3 -c 'assert float(\"${PERF_ELAPSED}\") < 60.0'"
else
  assert "50 iterations produced 200 events" "false"
  assert "All 200 event lines are valid JSON after 50 iterations" "false"
  assert "200 events written in under 60 seconds" "false"
fi

echo ""
echo "Event append is O(1) (constant time regardless of log size)"
if $LIBS_SOURCED; then
  # The PERF session already has 200 events; measure appending 10 more
  APPEND_LARGE_START="$(python3 -c 'import time; print(time.time())' 2>/dev/null)"
  for j in $(seq 1 10); do
    log_event "observation" 51 "Post-perf append $j" '{}' >/dev/null 2>&1 || true
  done
  APPEND_LARGE_END="$(python3 -c 'import time; print(time.time())' 2>/dev/null)"
  APPEND_LARGE_TIME="$(python3 -c "print(float('${APPEND_LARGE_END}') - float('${APPEND_LARGE_START}'))" 2>/dev/null)" || true

  # Create a small log and measure append time
  SMALL_SESSION_ID="small-perf-$(date +%s)"
  SMALL_SESSION_DIR="${TEST_TMPDIR}/sessions/${SMALL_SESSION_ID}"
  init_event_log "$SMALL_SESSION_ID" "$SMALL_SESSION_DIR" >/dev/null 2>&1 || true

  APPEND_SMALL_START="$(python3 -c 'import time; print(time.time())' 2>/dev/null)"
  for j in $(seq 1 10); do
    log_event "observation" 1 "Small log append $j" '{}' >/dev/null 2>&1 || true
  done
  APPEND_SMALL_END="$(python3 -c 'import time; print(time.time())' 2>/dev/null)"
  APPEND_SMALL_TIME="$(python3 -c "print(float('${APPEND_SMALL_END}') - float('${APPEND_SMALL_START}'))" 2>/dev/null)" || true

  # O(1) check: appending to large log should not be significantly slower (< 3x)
  # Allow generous margin since timing in CI can be noisy
  assert "Append to 200-event log is within 3x of append to empty log (O(1) check)" \
    "python3 -c '
small = float(\"${APPEND_SMALL_TIME}\")
large = float(\"${APPEND_LARGE_TIME}\")
# Guard against zero/near-zero times
if small < 0.001: small = 0.001
ratio = large / small
assert ratio < 3.0, f\"ratio={ratio:.2f} (small={small:.4f}s, large={large:.4f}s)\"
'"
else
  assert "Append to 200-event log is within 3x of append to empty log (O(1) check)" "false"
fi

# ═══════════════════════════════════════
# Final Results
# ═══════════════════════════════════════
echo ""
echo "======================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "======================================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
