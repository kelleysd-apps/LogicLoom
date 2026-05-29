#!/usr/bin/env bash
# Contract Tests: Self-Extension System
# TDD tests for gap detection, plugin scaffolding, quarantine validation,
# and plugin registration in the dev-loop self-extension subsystem.
# Tests: detect_gap, scaffold_plugin, validate_quarantine, register_plugin
# These tests are written BEFORE implementation (TDD).
#
# Self-Extension Lifecycle:
#   detect_gap -> scaffold_plugin -> validate_quarantine -> register_plugin
#
# All self-generated plugins use the sdd-tool-{name} naming convention
# and author = "devloop-selfgen".
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
TEMPLATES_DIR="${PLUGIN_DIR}/templates"
TEST_TMPDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_TMPDIR"
}
trap cleanup EXIT

echo "=== Self-Extension System Contract Tests ==="
echo ""

# ══════════════════════════════════════════
# Template & Skill Existence
# ══════════════════════════════════════════
echo "Template and skill existence"
assert "gap-analysis.md template exists" "[ -f '${TEMPLATES_DIR}/gap-analysis.md' ]"
# Self-extension capability is hosted within the dev-loop core-loop skill
# (the standalone self-extend skill was consolidated into core-loop).
assert "core-loop SKILL.md exists" "[ -f '${PLUGIN_DIR}/skills/core-loop/SKILL.md' ]"

# Source libraries (tolerant of partially-implemented libs)
LIBS_SOURCED=false
if [ -f "${LIB_DIR}/self-extension.sh" ]; then
  set +eu
  source "${LIB_DIR}/self-extension.sh" 2>/dev/null
  set -eu
  LIBS_SOURCED=true
fi

# Also try sourcing event-logger for helper use
EVENT_LOGGER_SOURCED=false
if [ -f "${LIB_DIR}/event-logger.sh" ]; then
  set +eu
  source "${LIB_DIR}/event-logger.sh" 2>/dev/null
  set -eu
  EVENT_LOGGER_SOURCED=true
fi

# ── Function Existence ──
echo ""
echo "Function existence"
assert "detect_gap function exists" "type -t detect_gap 2>/dev/null | grep -q function"
assert "scaffold_plugin function exists" "type -t scaffold_plugin 2>/dev/null | grep -q function"
assert "validate_quarantine function exists" "type -t validate_quarantine 2>/dev/null | grep -q function"
assert "register_plugin function exists" "type -t register_plugin 2>/dev/null | grep -q function"

# ── Helper: create mock session with error events in event log ──
create_session_with_errors() {
  local session_id="$1"
  local error_count="${2:-5}"
  local error_message="${3:-TOOL_NOT_FOUND: eslint config validation not available}"

  local sess_dir="${TEST_TMPDIR}/.devloop/sessions/${session_id}"
  mkdir -p "${sess_dir}"

  # Create events.jsonl with error events
  local event_log="${sess_dir}/events.jsonl"
  > "$event_log"

  for i in $(seq 1 "$error_count"); do
    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")
    cat >> "$event_log" <<EVTJSON
{"event_id":"evt-$(date +%Y%m%d-%H%M%S)-$(printf '%03d' "$i")","session_id":"${session_id}","timestamp":"${ts}","iteration":${i},"event_type":"error","content":"${error_message}","metadata":{"error":"TOOL_NOT_FOUND","severity":"error"}}
EVTJSON
  done

  echo "${sess_dir}"
}

# ── Helper: create mock session with no errors ──
create_session_no_errors() {
  local session_id="$1"

  local sess_dir="${TEST_TMPDIR}/.devloop/sessions/${session_id}"
  mkdir -p "${sess_dir}"

  # Create events.jsonl with non-error events only
  local event_log="${sess_dir}/events.jsonl"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")
  cat > "$event_log" <<EVTJSON
{"event_id":"evt-001","session_id":"${session_id}","timestamp":"${ts}","iteration":1,"event_type":"action","content":"Implemented feature","metadata":{}}
{"event_id":"evt-002","session_id":"${session_id}","timestamp":"${ts}","iteration":2,"event_type":"observation","content":"Tests passing","metadata":{}}
EVTJSON

  echo "${sess_dir}"
}

# ── Helper: create mock session with empty event log ──
create_session_empty_log() {
  local session_id="$1"

  local sess_dir="${TEST_TMPDIR}/.devloop/sessions/${session_id}"
  mkdir -p "${sess_dir}"

  # Create empty events.jsonl
  touch "${sess_dir}/events.jsonl"

  echo "${sess_dir}"
}

# ── Helper: create quarantine plugin with passed status ──
create_quarantine_plugin() {
  local plugin_name="$1"
  local status="${2:-passed}"

  local q_dir="${TEST_TMPDIR}/.devloop/quarantine/${plugin_name}"
  mkdir -p "${q_dir}/.claude-plugin"
  mkdir -p "${q_dir}/skills"
  mkdir -p "${q_dir}/tests/contract"
  mkdir -p "${q_dir}/tests/integration"
  mkdir -p "${q_dir}/agents"

  # Create plugin.json
  cat > "${q_dir}/.claude-plugin/plugin.json" <<PLUGJSON
{
  "name": "${plugin_name}",
  "version": "0.1.0",
  "description": "Auto-generated tool plugin",
  "author": "devloop-selfgen",
  "entrypoint": "skills/tool/SKILL.md",
  "permissions_required": ["Read", "Bash"],
  "created_by_session": "test-session-001",
  "gap_id": "gap-test-001",
  "category": "tool",
  "quarantine_lifecycle": {
    "status": "${status}",
    "validated_at": "2026-02-07T15:30:00Z"
  },
  "rl_metrics": {
    "success_rate": 0.5,
    "selection_weight": 0.5,
    "invocation_count": 0
  }
}
PLUGJSON

  # Create minimal SKILL.md
  cat > "${q_dir}/skills/tool/SKILL.md" 2>/dev/null || {
    mkdir -p "${q_dir}/skills/tool"
    echo "# Tool Skill" > "${q_dir}/skills/tool/SKILL.md"
  }

  # Create test stubs
  cat > "${q_dir}/tests/contract/test_tool.sh" <<'TESTSH'
#!/usr/bin/env bash
echo "PASS: stub test"
exit 0
TESTSH
  chmod +x "${q_dir}/tests/contract/test_tool.sh"

  echo "${q_dir}"
}

# ══════════════════════════════════════════
# Detect Gap: Frequency >= 3 Triggers Detection
# ══════════════════════════════════════════
echo ""
echo "--- Detect Gap: Recurring Pattern (frequency >= 3) ---"

if $LIBS_SOURCED; then
  # Session with 5 recurring errors — should detect gap
  SESS_DIR_HIGH="$(create_session_with_errors "test-gap-high-$$" 5 "TOOL_NOT_FOUND: eslint config validation not available")"

  GAP_RESULT="$(safe_call detect_gap --session-dir "$SESS_DIR_HIGH" --min-frequency 3)"
  assert "Gap detected with frequency >= 3" \
    "python3 -c 'import json; d=json.loads(\"\"\"${GAP_RESULT}\"\"\"); assert d.get(\"gap_detected\", False) == True or \"gap_id\" in d, f\"got {d}\"'"
  assert "Gap has frequency >= 3" \
    "python3 -c 'import json; d=json.loads(\"\"\"${GAP_RESULT}\"\"\"); assert d.get(\"frequency\", 0) >= 3, f\"freq={d.get(\"frequency\")}\"'"
  assert "Gap has non-empty missing_capability" \
    "python3 -c 'import json; d=json.loads(\"\"\"${GAP_RESULT}\"\"\"); assert len(d.get(\"missing_capability\", \"\")) > 0'"
  assert "Gap has impact field (low/medium/high)" \
    "python3 -c 'import json; d=json.loads(\"\"\"${GAP_RESULT}\"\"\"); assert d.get(\"impact\") in (\"low\", \"medium\", \"high\"), f\"impact={d.get(\"impact\")}\"'"
  assert "Gap has suggested_plugin_name with sdd-tool- prefix" \
    "python3 -c 'import json; d=json.loads(\"\"\"${GAP_RESULT}\"\"\"); assert d.get(\"suggested_plugin_name\", \"\").startswith(\"sdd-tool-\"), f\"name={d.get(\"suggested_plugin_name\")}\"'"
  assert "Gap has confidence in [0.0, 1.0]" \
    "python3 -c 'import json; d=json.loads(\"\"\"${GAP_RESULT}\"\"\"); c=d.get(\"confidence\", -1); assert 0.0 <= c <= 1.0, f\"conf={c}\"'"
  assert "Gap has status = detected" \
    "python3 -c 'import json; d=json.loads(\"\"\"${GAP_RESULT}\"\"\"); assert d.get(\"status\") == \"detected\", f\"status={d.get(\"status\")}\"'"
  assert "Gap has gap_id field" \
    "python3 -c 'import json; d=json.loads(\"\"\"${GAP_RESULT}\"\"\"); assert \"gap_id\" in d and len(d[\"gap_id\"]) > 0'"
else
  assert "Gap detected with frequency >= 3" "false"
  assert "Gap has frequency >= 3" "false"
  assert "Gap has non-empty missing_capability" "false"
  assert "Gap has impact field (low/medium/high)" "false"
  assert "Gap has suggested_plugin_name with sdd-tool- prefix" "false"
  assert "Gap has confidence in [0.0, 1.0]" "false"
  assert "Gap has status = detected" "false"
  assert "Gap has gap_id field" "false"
fi

# ══════════════════════════════════════════
# Detect Gap: Low Frequency — No Gap
# ══════════════════════════════════════════
echo ""
echo "--- Detect Gap: Low Frequency (< 3) — No Detection ---"

if $LIBS_SOURCED; then
  # Session with only 2 errors — below threshold
  SESS_DIR_LOW="$(create_session_with_errors "test-gap-low-$$" 2 "TOOL_NOT_FOUND: some tool")"

  NO_GAP_RESULT="$(safe_call detect_gap --session-dir "$SESS_DIR_LOW" --min-frequency 3)"
  assert "No gap detected with frequency < 3" \
    "python3 -c 'import json; d=json.loads(\"\"\"${NO_GAP_RESULT}\"\"\"); assert d.get(\"gap_detected\") == False or \"gap_id\" not in d, f\"got {d}\"'"
else
  assert "No gap detected with frequency < 3" "false"
fi

# ══════════════════════════════════════════
# Detect Gap: EMPTY_ERROR_LOG
# ══════════════════════════════════════════
echo ""
echo "--- Detect Gap: Empty Error Log ---"

if $LIBS_SOURCED; then
  # Session with empty event log
  SESS_DIR_EMPTY="$(create_session_empty_log "test-gap-empty-$$")"

  EMPTY_RESULT="$(safe_call detect_gap --session-dir "$SESS_DIR_EMPTY" --min-frequency 3)"
  assert "EMPTY_ERROR_LOG returned for empty event log" \
    "echo '${EMPTY_RESULT}' | grep -q 'EMPTY_ERROR_LOG'"

  # Session with events but no errors
  SESS_DIR_NOERR="$(create_session_no_errors "test-gap-noerr-$$")"

  NOERR_RESULT="$(safe_call detect_gap --session-dir "$SESS_DIR_NOERR" --min-frequency 3)"
  assert "No gap detected when event log has no error events" \
    "python3 -c 'import json; d=json.loads(\"\"\"${NOERR_RESULT}\"\"\"); assert d.get(\"gap_detected\") == False or \"EMPTY_ERROR_LOG\" in str(d) or \"gap_id\" not in d, f\"got {d}\"'"
else
  assert "EMPTY_ERROR_LOG returned for empty event log" "false"
  assert "No gap detected when event log has no error events" "false"
fi

# ══════════════════════════════════════════
# Detect Gap: Recurring Pattern Identification
# ══════════════════════════════════════════
echo ""
echo "--- Detect Gap: Recurring Pattern Identification ---"

if $LIBS_SOURCED; then
  # Session with mixed errors — only one pattern recurs >= 3 times
  SESS_DIR_MIX="$(mktemp -d)"
  mkdir -p "${SESS_DIR_MIX}/.devloop/sessions/test-mix"
  MIXED_DIR="${SESS_DIR_MIX}/.devloop/sessions/test-mix"
  mkdir -p "$MIXED_DIR"

  EVENT_LOG_MIX="${MIXED_DIR}/events.jsonl"
  > "$EVENT_LOG_MIX"

  # 4 occurrences of the same pattern
  for i in 1 2 3 4; do
    echo "{\"event_id\":\"evt-r${i}\",\"session_id\":\"test-mix\",\"timestamp\":\"2026-02-07T10:0${i}:00Z\",\"iteration\":${i},\"event_type\":\"error\",\"content\":\"TOOL_NOT_FOUND: formatter not available\",\"metadata\":{\"error\":\"TOOL_NOT_FOUND\",\"severity\":\"error\"}}" >> "$EVENT_LOG_MIX"
  done
  # 1 occurrence of a different pattern (should not trigger)
  echo "{\"event_id\":\"evt-r5\",\"session_id\":\"test-mix\",\"timestamp\":\"2026-02-07T10:05:00Z\",\"iteration\":5,\"event_type\":\"error\",\"content\":\"TIMEOUT: api call timed out\",\"metadata\":{\"error\":\"TIMEOUT\",\"severity\":\"warning\"}}" >> "$EVENT_LOG_MIX"

  MIX_RESULT="$(safe_call detect_gap --session-dir "$MIXED_DIR" --min-frequency 3)"
  assert "Recurring pattern detected from mixed errors" \
    "python3 -c 'import json; d=json.loads(\"\"\"${MIX_RESULT}\"\"\"); assert d.get(\"gap_detected\", False) == True or \"gap_id\" in d, f\"got {d}\"'"
  assert "Detected pattern matches the recurring error (TOOL_NOT_FOUND)" \
    "python3 -c 'import json; d=json.loads(\"\"\"${MIX_RESULT}\"\"\"); mc=d.get(\"missing_capability\",\"\") + d.get(\"error_pattern\",\"\"); assert \"TOOL_NOT_FOUND\" in mc or \"formatter\" in mc.lower(), f\"got {mc}\"'"

  rm -rf "$SESS_DIR_MIX"
else
  assert "Recurring pattern detected from mixed errors" "false"
  assert "Detected pattern matches the recurring error (TOOL_NOT_FOUND)" "false"
fi

# ══════════════════════════════════════════
# Detect Gap: SESSION_NOT_FOUND
# ══════════════════════════════════════════
echo ""
echo "--- Detect Gap: SESSION_NOT_FOUND ---"

if $LIBS_SOURCED; then
  MISSING_RESULT="$(safe_call detect_gap --session-dir "${TEST_TMPDIR}/nonexistent" --min-frequency 3)"
  assert "SESSION_NOT_FOUND for nonexistent session dir" \
    "echo '${MISSING_RESULT}' | grep -q 'SESSION_NOT_FOUND'"
else
  assert "SESSION_NOT_FOUND for nonexistent session dir" "false"
fi

# ══════════════════════════════════════════
# Scaffold Plugin: Valid Scaffold
# ══════════════════════════════════════════
echo ""
echo "--- Scaffold Plugin: Valid Scaffold ---"

if $LIBS_SOURCED; then
  SCAFFOLD_WORKDIR="${TEST_TMPDIR}/scaffold-test"
  mkdir -p "$SCAFFOLD_WORKDIR"

  GAP_JSON='{"gap_id":"gap-test-001","session_id":"test-sess","missing_capability":"ESLint configuration validation","frequency":5,"impact":"medium","suggested_plugin_name":"sdd-tool-eslint-validator","confidence":0.78,"status":"detected"}'

  SCAFFOLD_RESULT="$(safe_call scaffold_plugin \
    --gap-id "gap-test-001" \
    --plugin-name "sdd-tool-eslint-validator" \
    --workdir "$SCAFFOLD_WORKDIR" \
    --gap-analysis "$GAP_JSON")"

  # Check plugin.json was created
  QUARANTINE_PATH="${SCAFFOLD_WORKDIR}/.devloop/quarantine/sdd-tool-eslint-validator"
  assert "Quarantine directory created" "[ -d '${QUARANTINE_PATH}' ]"
  assert "plugin.json exists in quarantine" "[ -f '${QUARANTINE_PATH}/.claude-plugin/plugin.json' ]"
  assert "SKILL.md exists in quarantine" \
    "[ -f '${QUARANTINE_PATH}/skills/eslint-validator/SKILL.md' ] || find '${QUARANTINE_PATH}/skills' -name 'SKILL.md' | grep -q 'SKILL.md'"
  assert "Contract test stubs exist" \
    "find '${QUARANTINE_PATH}/tests/contract' -name 'test_*.sh' | grep -q 'test_'"
  assert "Integration test stubs exist" \
    "find '${QUARANTINE_PATH}/tests/integration' -name 'test_*.sh' | grep -q 'test_'"

  # Verify plugin.json content
  if [ -f "${QUARANTINE_PATH}/.claude-plugin/plugin.json" ]; then
    assert "plugin.json has correct name" \
      "python3 -c 'import json; d=json.load(open(\"${QUARANTINE_PATH}/.claude-plugin/plugin.json\")); assert d[\"name\"] == \"sdd-tool-eslint-validator\"'"
    assert "plugin.json has version 0.1.0" \
      "python3 -c 'import json; d=json.load(open(\"${QUARANTINE_PATH}/.claude-plugin/plugin.json\")); assert d[\"version\"] == \"0.1.0\"'"
    assert "plugin.json has author = devloop-selfgen" \
      "python3 -c 'import json; d=json.load(open(\"${QUARANTINE_PATH}/.claude-plugin/plugin.json\")); assert d[\"author\"] == \"devloop-selfgen\"'"
    assert "plugin.json has created_by_session" \
      "python3 -c 'import json; d=json.load(open(\"${QUARANTINE_PATH}/.claude-plugin/plugin.json\")); assert \"created_by_session\" in d and len(d[\"created_by_session\"]) > 0'"
    assert "plugin.json has permissions_required" \
      "python3 -c 'import json; d=json.load(open(\"${QUARANTINE_PATH}/.claude-plugin/plugin.json\")); assert isinstance(d.get(\"permissions_required\"), list) and len(d[\"permissions_required\"]) > 0'"
  fi

  # Verify scaffold result
  assert "Scaffold result has status = pending" \
    "python3 -c 'import json; d=json.loads(\"\"\"${SCAFFOLD_RESULT}\"\"\"); assert d.get(\"status\") == \"pending\" or d.get(\"quarantine_status\") == \"pending\", f\"got {d}\"'"
else
  assert "Quarantine directory created" "false"
  assert "plugin.json exists in quarantine" "false"
  assert "SKILL.md exists in quarantine" "false"
  assert "Contract test stubs exist" "false"
  assert "Integration test stubs exist" "false"
  assert "plugin.json has correct name" "false"
  assert "plugin.json has version 0.1.0" "false"
  assert "plugin.json has author = devloop-selfgen" "false"
  assert "plugin.json has created_by_session" "false"
  assert "plugin.json has permissions_required" "false"
  assert "Scaffold result has status = pending" "false"
fi

# ══════════════════════════════════════════
# Scaffold Plugin: INVALID_NAME (non sdd-tool- prefix)
# ══════════════════════════════════════════
echo ""
echo "--- Scaffold Plugin: INVALID_NAME ---"

if $LIBS_SOURCED; then
  BAD_NAME_WORKDIR="${TEST_TMPDIR}/scaffold-badname"
  mkdir -p "$BAD_NAME_WORKDIR"

  GAP_JSON_BAD='{"gap_id":"gap-test-bad","session_id":"test-sess","missing_capability":"Something","frequency":3,"impact":"low","status":"detected"}'

  # Name without sdd-tool- prefix
  BAD_RESULT="$(safe_call scaffold_plugin \
    --gap-id "gap-test-bad" \
    --plugin-name "my-custom-plugin" \
    --workdir "$BAD_NAME_WORKDIR" \
    --gap-analysis "$GAP_JSON_BAD")"
  assert "INVALID_NAME for plugin without sdd-tool- prefix" \
    "echo '${BAD_RESULT}' | grep -q 'INVALID_NAME'"

  # Name with sdd- but not sdd-tool-
  BAD_RESULT2="$(safe_call scaffold_plugin \
    --gap-id "gap-test-bad" \
    --plugin-name "sdd-custom-thing" \
    --workdir "$BAD_NAME_WORKDIR" \
    --gap-analysis "$GAP_JSON_BAD")"
  assert "INVALID_NAME for plugin with sdd- but not sdd-tool- prefix" \
    "echo '${BAD_RESULT2}' | grep -q 'INVALID_NAME'"
else
  assert "INVALID_NAME for plugin without sdd-tool- prefix" "false"
  assert "INVALID_NAME for plugin with sdd- but not sdd-tool- prefix" "false"
fi

# ══════════════════════════════════════════
# Scaffold Plugin: CAPABILITY_TOO_VAGUE
# ══════════════════════════════════════════
echo ""
echo "--- Scaffold Plugin: CAPABILITY_TOO_VAGUE ---"

if $LIBS_SOURCED; then
  VAGUE_WORKDIR="${TEST_TMPDIR}/scaffold-vague"
  mkdir -p "$VAGUE_WORKDIR"

  # Empty missing_capability
  GAP_JSON_EMPTY='{"gap_id":"gap-test-vague","session_id":"test-sess","missing_capability":"","frequency":3,"impact":"low","status":"detected"}'

  VAGUE_RESULT="$(safe_call scaffold_plugin \
    --gap-id "gap-test-vague" \
    --plugin-name "sdd-tool-vague" \
    --workdir "$VAGUE_WORKDIR" \
    --gap-analysis "$GAP_JSON_EMPTY")"
  assert "CAPABILITY_TOO_VAGUE for empty missing_capability" \
    "echo '${VAGUE_RESULT}' | grep -q 'CAPABILITY_TOO_VAGUE'"

  # Very short missing_capability (< 10 chars)
  GAP_JSON_SHORT='{"gap_id":"gap-test-short","session_id":"test-sess","missing_capability":"fix","frequency":3,"impact":"low","status":"detected"}'

  SHORT_RESULT="$(safe_call scaffold_plugin \
    --gap-id "gap-test-short" \
    --plugin-name "sdd-tool-short" \
    --workdir "$VAGUE_WORKDIR" \
    --gap-analysis "$GAP_JSON_SHORT")"
  assert "CAPABILITY_TOO_VAGUE for very short missing_capability" \
    "echo '${SHORT_RESULT}' | grep -q 'CAPABILITY_TOO_VAGUE'"
else
  assert "CAPABILITY_TOO_VAGUE for empty missing_capability" "false"
  assert "CAPABILITY_TOO_VAGUE for very short missing_capability" "false"
fi

# ══════════════════════════════════════════
# Quarantine Validate: All-Pass Scenario
# ══════════════════════════════════════════
echo ""
echo "--- Quarantine Validate: All-Pass Scenario ---"

if $LIBS_SOURCED; then
  VALIDATE_WORKDIR="${TEST_TMPDIR}/validate-test"
  mkdir -p "${VALIDATE_WORKDIR}/.devloop/quarantine"

  # Create a well-formed quarantine plugin
  create_quarantine_plugin "sdd-tool-good-plugin" "pending" >/dev/null
  # Move to the correct workdir
  mv "${TEST_TMPDIR}/.devloop/quarantine/sdd-tool-good-plugin" \
     "${VALIDATE_WORKDIR}/.devloop/quarantine/" 2>/dev/null || true

  VALIDATE_RESULT="$(safe_call validate_quarantine \
    --plugin-name "sdd-tool-good-plugin" \
    --workdir "$VALIDATE_WORKDIR")"

  assert "Validation returns result JSON" \
    "python3 -c 'import json; json.loads(\"\"\"${VALIDATE_RESULT}\"\"\")'"
  assert "Validation has test_coverage result" \
    "python3 -c 'import json; d=json.loads(\"\"\"${VALIDATE_RESULT}\"\"\"); assert \"test_coverage\" in d or \"test_coverage\" in d.get(\"validation_results\", {}), f\"got {d}\"'"
  assert "Validation has security_scan result" \
    "python3 -c 'import json; d=json.loads(\"\"\"${VALIDATE_RESULT}\"\"\"); assert \"security_scan\" in d or \"security_scan\" in d.get(\"validation_results\", {}), f\"got {d}\"'"
  assert "Validation has constitutional_review result" \
    "python3 -c 'import json; d=json.loads(\"\"\"${VALIDATE_RESULT}\"\"\"); assert \"constitutional_review\" in d or \"constitutional_review\" in d.get(\"validation_results\", {}), f\"got {d}\"'"
else
  assert "Validation returns result JSON" "false"
  assert "Validation has test_coverage result" "false"
  assert "Validation has security_scan result" "false"
  assert "Validation has constitutional_review result" "false"
fi

# ══════════════════════════════════════════
# Quarantine Validate: Security Scan Failure
# ══════════════════════════════════════════
echo ""
echo "--- Quarantine Validate: Security Scan Failure ---"

if $LIBS_SOURCED; then
  SEC_FAIL_WORKDIR="${TEST_TMPDIR}/validate-secfail"
  mkdir -p "${SEC_FAIL_WORKDIR}/.devloop/quarantine/sdd-tool-insecure"
  INSECURE_DIR="${SEC_FAIL_WORKDIR}/.devloop/quarantine/sdd-tool-insecure"
  mkdir -p "${INSECURE_DIR}/.claude-plugin"
  mkdir -p "${INSECURE_DIR}/skills/insecure"
  mkdir -p "${INSECURE_DIR}/tests/contract"

  # Create plugin.json
  cat > "${INSECURE_DIR}/.claude-plugin/plugin.json" <<'SECJSON'
{
  "name": "sdd-tool-insecure",
  "version": "0.1.0",
  "author": "devloop-selfgen",
  "description": "Insecure test plugin",
  "permissions_required": ["Read", "Bash"],
  "quarantine_lifecycle": {"status": "pending"}
}
SECJSON

  # Create a skill with hardcoded secret (should fail security scan)
  cat > "${INSECURE_DIR}/skills/insecure/SKILL.md" <<'SECSKILL'
# Insecure Skill
API_KEY="sk-1234567890abcdef"
SECSKILL

  # Create a lib file with command injection vulnerability
  mkdir -p "${INSECURE_DIR}/lib"
  cat > "${INSECURE_DIR}/lib/vuln.sh" <<'VULNSH'
#!/usr/bin/env bash
eval "$USER_INPUT"
VULNSH

  SEC_RESULT="$(safe_call validate_quarantine \
    --plugin-name "sdd-tool-insecure" \
    --workdir "$SEC_FAIL_WORKDIR")"

  assert "Security scan fails for plugin with hardcoded secrets" \
    "python3 -c '
import json
d = json.loads(\"\"\"${SEC_RESULT}\"\"\")
vr = d.get(\"validation_results\", d)
sec = vr.get(\"security_scan\", {})
assert sec.get(\"status\") == \"failed\" or d.get(\"overall_status\") == \"failed\" or d.get(\"status\") == \"failed\", f\"got {d}\"
'"
  assert "Overall quarantine status is failed" \
    "python3 -c '
import json
d = json.loads(\"\"\"${SEC_RESULT}\"\"\")
status = d.get(\"overall_status\", d.get(\"status\", d.get(\"quarantine_status\", \"\")))
assert status == \"failed\", f\"got {status}\"
'"
else
  assert "Security scan fails for plugin with hardcoded secrets" "false"
  assert "Overall quarantine status is failed" "false"
fi

# ══════════════════════════════════════════
# Quarantine Validate: Test Coverage < 80% Failure
# ══════════════════════════════════════════
echo ""
echo "--- Quarantine Validate: Test Coverage Below 80% ---"

if $LIBS_SOURCED; then
  COV_FAIL_WORKDIR="${TEST_TMPDIR}/validate-covfail"
  mkdir -p "${COV_FAIL_WORKDIR}/.devloop/quarantine/sdd-tool-low-coverage"
  LOWCOV_DIR="${COV_FAIL_WORKDIR}/.devloop/quarantine/sdd-tool-low-coverage"
  mkdir -p "${LOWCOV_DIR}/.claude-plugin"
  mkdir -p "${LOWCOV_DIR}/skills/low-coverage"
  mkdir -p "${LOWCOV_DIR}/tests/contract"

  cat > "${LOWCOV_DIR}/.claude-plugin/plugin.json" <<'COVJSON'
{
  "name": "sdd-tool-low-coverage",
  "version": "0.1.0",
  "author": "devloop-selfgen",
  "description": "Low coverage test plugin",
  "permissions_required": ["Read", "Bash"],
  "quarantine_lifecycle": {"status": "pending"}
}
COVJSON

  echo "# Low Coverage Skill" > "${LOWCOV_DIR}/skills/low-coverage/SKILL.md"

  # Create a test that mostly fails (low coverage)
  cat > "${LOWCOV_DIR}/tests/contract/test_low_coverage.sh" <<'LOWTEST'
#!/usr/bin/env bash
PASS=0; FAIL=0; TOTAL=0
TOTAL=$((TOTAL+1)); FAIL=$((FAIL+1)); echo "FAIL: test1"
TOTAL=$((TOTAL+1)); FAIL=$((FAIL+1)); echo "FAIL: test2"
TOTAL=$((TOTAL+1)); FAIL=$((FAIL+1)); echo "FAIL: test3"
TOTAL=$((TOTAL+1)); FAIL=$((FAIL+1)); echo "FAIL: test4"
TOTAL=$((TOTAL+1)); PASS=$((PASS+1)); echo "PASS: test5"
echo "Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
exit 1
LOWTEST
  chmod +x "${LOWCOV_DIR}/tests/contract/test_low_coverage.sh"

  COV_RESULT="$(safe_call validate_quarantine \
    --plugin-name "sdd-tool-low-coverage" \
    --workdir "$COV_FAIL_WORKDIR")"

  assert "Test coverage check fails for < 80% coverage" \
    "python3 -c '
import json
d = json.loads(\"\"\"${COV_RESULT}\"\"\")
vr = d.get(\"validation_results\", d)
tc = vr.get(\"test_coverage\", {})
assert tc.get(\"status\") == \"failed\" or d.get(\"overall_status\") == \"failed\" or d.get(\"status\") == \"failed\", f\"got {d}\"
'"
else
  assert "Test coverage check fails for < 80% coverage" "false"
fi

# ══════════════════════════════════════════
# Quarantine Validate: Constitutional Review Failure
# ══════════════════════════════════════════
echo ""
echo "--- Quarantine Validate: Constitutional Review Failure ---"

if $LIBS_SOURCED; then
  CONST_FAIL_WORKDIR="${TEST_TMPDIR}/validate-constfail"
  mkdir -p "${CONST_FAIL_WORKDIR}/.devloop/quarantine/sdd-tool-unconstitutional"
  UNCONST_DIR="${CONST_FAIL_WORKDIR}/.devloop/quarantine/sdd-tool-unconstitutional"
  mkdir -p "${UNCONST_DIR}/.claude-plugin"
  mkdir -p "${UNCONST_DIR}/skills/unconstitutional"

  # plugin.json missing permissions_required (violates Principle XIII)
  cat > "${UNCONST_DIR}/.claude-plugin/plugin.json" <<'CONSTJSON'
{
  "name": "sdd-tool-unconstitutional",
  "version": "0.1.0",
  "author": "devloop-selfgen",
  "description": "Plugin violating constitutional principles"
}
CONSTJSON

  # Skill with git push command (violates Principle VI)
  cat > "${UNCONST_DIR}/skills/unconstitutional/SKILL.md" <<'CONSTSKILL'
# Unconstitutional Skill
Run: git push origin main
CONSTSKILL

  # No tests directory (violates Principle II)

  CONST_RESULT="$(safe_call validate_quarantine \
    --plugin-name "sdd-tool-unconstitutional" \
    --workdir "$CONST_FAIL_WORKDIR")"

  assert "Constitutional review fails for non-compliant plugin" \
    "python3 -c '
import json
d = json.loads(\"\"\"${CONST_RESULT}\"\"\")
vr = d.get(\"validation_results\", d)
cr = vr.get(\"constitutional_review\", {})
assert cr.get(\"status\") == \"failed\" or d.get(\"overall_status\") == \"failed\" or d.get(\"status\") == \"failed\", f\"got {d}\"
'"
  assert "Constitutional review checks all 16 principles" \
    "python3 -c '
import json
d = json.loads(\"\"\"${CONST_RESULT}\"\"\")
vr = d.get(\"validation_results\", d)
cr = vr.get(\"constitutional_review\", {})
assert cr.get(\"principles_checked\", 0) == 16 or len(cr.get(\"principle_results\", {})) == 16, f\"got {cr}\"
'"
else
  assert "Constitutional review fails for non-compliant plugin" "false"
  assert "Constitutional review checks all 16 principles" "false"
fi

# ══════════════════════════════════════════
# Quarantine Validate: PLUGIN_NOT_FOUND
# ══════════════════════════════════════════
echo ""
echo "--- Quarantine Validate: PLUGIN_NOT_FOUND ---"

if $LIBS_SOURCED; then
  PNF_WORKDIR="${TEST_TMPDIR}/validate-pnf"
  mkdir -p "${PNF_WORKDIR}/.devloop/quarantine"

  PNF_RESULT="$(safe_call validate_quarantine \
    --plugin-name "sdd-tool-nonexistent" \
    --workdir "$PNF_WORKDIR")"
  assert "PLUGIN_NOT_FOUND for nonexistent quarantine plugin" \
    "echo '${PNF_RESULT}' | grep -q 'PLUGIN_NOT_FOUND'"
else
  assert "PLUGIN_NOT_FOUND for nonexistent quarantine plugin" "false"
fi

# ══════════════════════════════════════════
# Register Plugin: Successful Registration
# ══════════════════════════════════════════
echo ""
echo "--- Register Plugin: Successful Registration ---"

if $LIBS_SOURCED; then
  REG_WORKDIR="${TEST_TMPDIR}/register-test"
  mkdir -p "${REG_WORKDIR}/.devloop/quarantine"
  mkdir -p "${REG_WORKDIR}/plugins"

  # Create mock sync script
  mkdir -p "${REG_WORKDIR}/.logic-loom/scripts/bash"
  cat > "${REG_WORKDIR}/.logic-loom/scripts/bash/sync-plugin-commands.sh" <<'SYNCSH'
#!/usr/bin/env bash
echo "Commands synced"
exit 0
SYNCSH
  chmod +x "${REG_WORKDIR}/.logic-loom/scripts/bash/sync-plugin-commands.sh"

  # Create mock RL metrics directory
  mkdir -p "${REG_WORKDIR}/.docs/rl-metrics"

  # Create a validated quarantine plugin (status: passed)
  Q_DIR="${REG_WORKDIR}/.devloop/quarantine/sdd-tool-register-test"
  mkdir -p "${Q_DIR}/.claude-plugin"
  mkdir -p "${Q_DIR}/skills/register-test"
  mkdir -p "${Q_DIR}/tests/contract"

  cat > "${Q_DIR}/.claude-plugin/plugin.json" <<'REGJSON'
{
  "name": "sdd-tool-register-test",
  "version": "0.1.0",
  "description": "Test plugin for registration",
  "author": "devloop-selfgen",
  "entrypoint": "skills/register-test/SKILL.md",
  "permissions_required": ["Read", "Bash"],
  "created_by_session": "test-session-001",
  "gap_id": "gap-test-reg",
  "category": "tool",
  "quarantine_lifecycle": {
    "status": "passed",
    "validated_at": "2026-02-07T15:30:00Z"
  },
  "rl_metrics": {
    "success_rate": 0.5,
    "selection_weight": 0.5,
    "invocation_count": 0
  }
}
REGJSON

  echo "# Register Test Skill" > "${Q_DIR}/skills/register-test/SKILL.md"
  echo "#!/usr/bin/env bash" > "${Q_DIR}/tests/contract/test_register.sh"
  echo "echo PASS" >> "${Q_DIR}/tests/contract/test_register.sh"
  chmod +x "${Q_DIR}/tests/contract/test_register.sh"

  REG_RESULT="$(safe_call register_plugin \
    --plugin-name "sdd-tool-register-test" \
    --workdir "$REG_WORKDIR")"

  # Verify plugin moved from quarantine to plugins/
  assert "Plugin moved to plugins/ directory" \
    "[ -d '${REG_WORKDIR}/plugins/sdd-tool-register-test' ]"
  assert "Plugin removed from quarantine" \
    "[ ! -d '${REG_WORKDIR}/.devloop/quarantine/sdd-tool-register-test' ]"
  assert "plugin.json exists in plugins/" \
    "[ -f '${REG_WORKDIR}/plugins/sdd-tool-register-test/.claude-plugin/plugin.json' ]"
  assert "SKILL.md exists in plugins/" \
    "[ -f '${REG_WORKDIR}/plugins/sdd-tool-register-test/skills/register-test/SKILL.md' ]"

  # Verify registration result
  assert "Registration result has plugin_name" \
    "python3 -c 'import json; d=json.loads(\"\"\"${REG_RESULT}\"\"\"); assert d.get(\"plugin_name\") == \"sdd-tool-register-test\" or \"sdd-tool-register-test\" in str(d), f\"got {d}\"'"
  assert "Registration result indicates RL metrics initialized" \
    "python3 -c 'import json; d=json.loads(\"\"\"${REG_RESULT}\"\"\"); assert d.get(\"rl_metrics_initialized\", False) == True or \"rl_metrics\" in str(d), f\"got {d}\"'"
else
  assert "Plugin moved to plugins/ directory" "false"
  assert "Plugin removed from quarantine" "false"
  assert "plugin.json exists in plugins/" "false"
  assert "SKILL.md exists in plugins/" "false"
  assert "Registration result has plugin_name" "false"
  assert "Registration result indicates RL metrics initialized" "false"
fi

# ══════════════════════════════════════════
# Register Plugin: VALIDATION_NOT_PASSED
# ══════════════════════════════════════════
echo ""
echo "--- Register Plugin: VALIDATION_NOT_PASSED ---"

if $LIBS_SOURCED; then
  VNP_WORKDIR="${TEST_TMPDIR}/register-vnp"
  mkdir -p "${VNP_WORKDIR}/.devloop/quarantine/sdd-tool-not-validated"
  mkdir -p "${VNP_WORKDIR}/plugins"

  VNP_DIR="${VNP_WORKDIR}/.devloop/quarantine/sdd-tool-not-validated"
  mkdir -p "${VNP_DIR}/.claude-plugin"

  # Plugin with status "pending" (not validated)
  cat > "${VNP_DIR}/.claude-plugin/plugin.json" <<'VNPJSON'
{
  "name": "sdd-tool-not-validated",
  "version": "0.1.0",
  "author": "devloop-selfgen",
  "description": "Not yet validated",
  "permissions_required": ["Read"],
  "quarantine_lifecycle": {
    "status": "pending"
  }
}
VNPJSON

  VNP_RESULT="$(safe_call register_plugin \
    --plugin-name "sdd-tool-not-validated" \
    --workdir "$VNP_WORKDIR")"
  assert "VALIDATION_NOT_PASSED for plugin with pending status" \
    "echo '${VNP_RESULT}' | grep -q 'VALIDATION_NOT_PASSED'"

  # Also test with "failed" status
  cat > "${VNP_DIR}/.claude-plugin/plugin.json" <<'VNPFAIL'
{
  "name": "sdd-tool-not-validated",
  "version": "0.1.0",
  "author": "devloop-selfgen",
  "description": "Failed validation",
  "permissions_required": ["Read"],
  "quarantine_lifecycle": {
    "status": "failed"
  }
}
VNPFAIL

  VNP_FAIL_RESULT="$(safe_call register_plugin \
    --plugin-name "sdd-tool-not-validated" \
    --workdir "$VNP_WORKDIR")"
  assert "VALIDATION_NOT_PASSED for plugin with failed status" \
    "echo '${VNP_FAIL_RESULT}' | grep -q 'VALIDATION_NOT_PASSED'"
else
  assert "VALIDATION_NOT_PASSED for plugin with pending status" "false"
  assert "VALIDATION_NOT_PASSED for plugin with failed status" "false"
fi

# ══════════════════════════════════════════
# Register Plugin: ALREADY_REGISTERED
# ══════════════════════════════════════════
echo ""
echo "--- Register Plugin: ALREADY_REGISTERED ---"

if $LIBS_SOURCED; then
  AR_WORKDIR="${TEST_TMPDIR}/register-ar"
  mkdir -p "${AR_WORKDIR}/.devloop/quarantine/sdd-tool-already-reg"
  mkdir -p "${AR_WORKDIR}/plugins/sdd-tool-already-reg"

  AR_Q_DIR="${AR_WORKDIR}/.devloop/quarantine/sdd-tool-already-reg"
  mkdir -p "${AR_Q_DIR}/.claude-plugin"
  cat > "${AR_Q_DIR}/.claude-plugin/plugin.json" <<'ARJSON'
{
  "name": "sdd-tool-already-reg",
  "version": "0.1.0",
  "author": "devloop-selfgen",
  "description": "Already registered",
  "permissions_required": ["Read"],
  "quarantine_lifecycle": {
    "status": "passed"
  }
}
ARJSON

  AR_RESULT="$(safe_call register_plugin \
    --plugin-name "sdd-tool-already-reg" \
    --workdir "$AR_WORKDIR")"
  assert "ALREADY_REGISTERED for plugin already in plugins/" \
    "echo '${AR_RESULT}' | grep -q 'ALREADY_REGISTERED'"
else
  assert "ALREADY_REGISTERED for plugin already in plugins/" "false"
fi

# ══════════════════════════════════════════
# Register Plugin: MANIFEST_INVALID
# ══════════════════════════════════════════
echo ""
echo "--- Register Plugin: MANIFEST_INVALID ---"

if $LIBS_SOURCED; then
  MI_WORKDIR="${TEST_TMPDIR}/register-mi"
  mkdir -p "${MI_WORKDIR}/.devloop/quarantine/sdd-tool-bad-manifest"
  mkdir -p "${MI_WORKDIR}/plugins"

  MI_DIR="${MI_WORKDIR}/.devloop/quarantine/sdd-tool-bad-manifest"
  mkdir -p "${MI_DIR}/.claude-plugin"

  # Write invalid JSON to plugin.json
  echo "NOT VALID JSON {{{" > "${MI_DIR}/.claude-plugin/plugin.json"

  MI_RESULT="$(safe_call register_plugin \
    --plugin-name "sdd-tool-bad-manifest" \
    --workdir "$MI_WORKDIR")"
  assert "MANIFEST_INVALID for malformed plugin.json" \
    "echo '${MI_RESULT}' | grep -q 'MANIFEST_INVALID'"
else
  assert "MANIFEST_INVALID for malformed plugin.json" "false"
fi

# ══════════════════════════════════════════
# Register Plugin: Plugin Bridge Sync Triggered
# ══════════════════════════════════════════
echo ""
echo "--- Register Plugin: Bridge Sync Triggered ---"

if $LIBS_SOURCED; then
  SYNC_WORKDIR="${TEST_TMPDIR}/register-sync"
  mkdir -p "${SYNC_WORKDIR}/.devloop/quarantine"
  mkdir -p "${SYNC_WORKDIR}/plugins"
  mkdir -p "${SYNC_WORKDIR}/.docs/rl-metrics"

  # Create sync script that writes a marker file
  mkdir -p "${SYNC_WORKDIR}/.logic-loom/scripts/bash"
  cat > "${SYNC_WORKDIR}/.logic-loom/scripts/bash/sync-plugin-commands.sh" <<SYNCMARK
#!/usr/bin/env bash
touch "${SYNC_WORKDIR}/.sync-marker"
echo "Commands synced"
exit 0
SYNCMARK
  chmod +x "${SYNC_WORKDIR}/.logic-loom/scripts/bash/sync-plugin-commands.sh"

  # Create validated quarantine plugin
  SYNC_Q="${SYNC_WORKDIR}/.devloop/quarantine/sdd-tool-sync-test"
  mkdir -p "${SYNC_Q}/.claude-plugin"
  mkdir -p "${SYNC_Q}/skills/sync-test"

  cat > "${SYNC_Q}/.claude-plugin/plugin.json" <<'SYNCJSON'
{
  "name": "sdd-tool-sync-test",
  "version": "0.1.0",
  "author": "devloop-selfgen",
  "description": "Sync test",
  "permissions_required": ["Read"],
  "quarantine_lifecycle": { "status": "passed" }
}
SYNCJSON
  echo "# Sync Test" > "${SYNC_Q}/skills/sync-test/SKILL.md"

  safe_call register_plugin \
    --plugin-name "sdd-tool-sync-test" \
    --workdir "$SYNC_WORKDIR" >/dev/null

  assert "Plugin bridge sync was triggered during registration" \
    "[ -f '${SYNC_WORKDIR}/.sync-marker' ]"
else
  assert "Plugin bridge sync was triggered during registration" "false"
fi

# ═══════════════════════════════════════
# Final Results
# ═══════════════════════════════════════
echo ""
echo "======================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "======================================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
