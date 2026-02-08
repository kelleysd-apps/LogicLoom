#!/usr/bin/env bash
# Integration Tests: Self-Extension Full Lifecycle
# Validates the complete self-extension flow from gap detection through
# plugin registration and usability verification.
#
# Lifecycle: recurring gap (3+ errors) -> detect gap -> scaffold in quarantine
#            -> validate -> register -> verify in plugins/ -> verify command
#            bridge sync -> verify RL metrics -> verify usable
#
# Also tests the failure path: scaffold plugin that fails security scan,
# verify it remains in quarantine with "failed" status.
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
# Setup: create temp workspace
# ──────────────────────────────────────────────────────
setup() {
  TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/devloop-selfext-XXXXXX")

  # Create workspace structure
  mkdir -p "$TEMP_DIR/.devloop/sessions"
  mkdir -p "$TEMP_DIR/.devloop/quarantine"
  mkdir -p "$TEMP_DIR/plugins"
  mkdir -p "$TEMP_DIR/.docs/rl-metrics"

  # Create mock sync-plugin-commands.sh that writes a marker
  mkdir -p "$TEMP_DIR/.specify/scripts/bash"
  cat > "$TEMP_DIR/.specify/scripts/bash/sync-plugin-commands.sh" <<SYNCEOF
#!/usr/bin/env bash
touch "$TEMP_DIR/.bridge-sync-marker"
echo "Commands synced"
exit 0
SYNCEOF
  chmod +x "$TEMP_DIR/.specify/scripts/bash/sync-plugin-commands.sh"
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
echo "=== sdd-dev-loop Self-Extension Lifecycle Integration Tests ==="
echo ""

# ──────────────────────────────────────────────────────
# Test 0: Plugin structure prerequisites
# ──────────────────────────────────────────────────────
echo "Plugin Structure Prerequisites"
assert "self-extend skill directory exists" "[ -d '$PLUGIN_DIR/skills/self-extend' ]"
assert "self-extend SKILL.md exists" "[ -f '$PLUGIN_DIR/skills/self-extend/SKILL.md' ]"
assert "gap-analysis.md template exists" "[ -f '$PLUGIN_DIR/templates/gap-analysis.md' ]"
assert "contract tests exist" "[ -f '$PLUGIN_DIR/tests/contract/test_self_extension.sh' ]"

echo ""

# ──────────────────────────────────────────────────────
# Source libraries
# ──────────────────────────────────────────────────────
SELF_EXT_AVAILABLE=false
EVENT_LOGGER_AVAILABLE=false
RL_ENGINE_AVAILABLE=false

if [ -f "$PLUGIN_DIR/lib/self-extension.sh" ]; then
  set +eu
  source "$PLUGIN_DIR/lib/self-extension.sh" 2>/dev/null && SELF_EXT_AVAILABLE=true
  set -eu
fi

if [ -f "$PLUGIN_DIR/lib/event-logger.sh" ]; then
  set +eu
  source "$PLUGIN_DIR/lib/event-logger.sh" 2>/dev/null && EVENT_LOGGER_AVAILABLE=true
  set -eu
fi

if [ -f "$PLUGIN_DIR/lib/rl-feedback-engine.sh" ]; then
  set +eu
  source "$PLUGIN_DIR/lib/rl-feedback-engine.sh" 2>/dev/null && RL_ENGINE_AVAILABLE=true
  set -eu
fi

echo "Library Availability"
assert "self-extension.sh available" "$SELF_EXT_AVAILABLE"
assert "event-logger.sh available" "$EVENT_LOGGER_AVAILABLE"
assert "rl-feedback-engine.sh available" "$RL_ENGINE_AVAILABLE"

echo ""

# ══════════════════════════════════════════════════════
# LIFECYCLE TEST 1: Full Happy Path
# Gap detection -> Scaffold -> Validate -> Register
# ══════════════════════════════════════════════════════
echo "=== Lifecycle Test 1: Full Happy Path ==="
echo ""

if $SELF_EXT_AVAILABLE; then
  setup

  # ── Step 1: Simulate recurring gap (3+ errors) ──
  echo "Step 1: Simulate recurring errors"

  SESSION_ID="lifecycle-test-$(date +%s)"
  SESSION_DIR="$TEMP_DIR/.devloop/sessions/$SESSION_ID"
  mkdir -p "$SESSION_DIR"

  # Create event log with 5 recurring TOOL_NOT_FOUND errors
  EVENT_LOG="$SESSION_DIR/events.jsonl"
  > "$EVENT_LOG"

  for i in 1 2 3 4 5; do
    TS=$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")
    cat >> "$EVENT_LOG" <<EVTEOF
{"event_id":"evt-lc-${i}","session_id":"${SESSION_ID}","timestamp":"${TS}","iteration":${i},"event_type":"error","content":"TOOL_NOT_FOUND: markdown linter not available","metadata":{"error":"TOOL_NOT_FOUND","severity":"error","tool":"markdown-linter"}}
EVTEOF
  done

  # Add some non-error events for realism
  cat >> "$EVENT_LOG" <<EVTEOF2
{"event_id":"evt-lc-6","session_id":"${SESSION_ID}","timestamp":"${TS}","iteration":1,"event_type":"action","content":"Implemented changes","metadata":{}}
{"event_id":"evt-lc-7","session_id":"${SESSION_ID}","timestamp":"${TS}","iteration":2,"event_type":"grade","content":"Quality grade computed","metadata":{"composite_grade":0.72}}
EVTEOF2

  assert "Session event log created with 7 events" "[ $(wc -l < '$EVENT_LOG' | tr -d ' ') -eq 7 ]"

  echo ""

  # ── Step 2: Detect gap ──
  echo "Step 2: Detect gap"

  GAP_RESULT="$( set +eu; detect_gap --session-dir "$SESSION_DIR" --min-frequency 3 2>/dev/null )" || true

  assert "Gap detection returned result" "[ -n '$GAP_RESULT' ]"

  GAP_DETECTED=false
  GAP_ID=""
  SUGGESTED_NAME=""

  if [ -n "$GAP_RESULT" ]; then
    GAP_DETECTED=$(python3 -c "
import json
try:
    d = json.loads('''${GAP_RESULT}''')
    print('true' if d.get('gap_detected', False) or 'gap_id' in d else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")

    if [ "$GAP_DETECTED" = "true" ]; then
      GAP_ID=$(python3 -c "import json; d=json.loads('''${GAP_RESULT}'''); print(d.get('gap_id',''))" 2>/dev/null || echo "")
      SUGGESTED_NAME=$(python3 -c "import json; d=json.loads('''${GAP_RESULT}'''); print(d.get('suggested_plugin_name',''))" 2>/dev/null || echo "")
    fi
  fi

  assert "Gap was detected from recurring errors" "[ '$GAP_DETECTED' = 'true' ]"
  assert "Gap has a gap_id" "[ -n '$GAP_ID' ]"
  assert "Gap suggests a plugin name with sdd-tool- prefix" \
    "echo '$SUGGESTED_NAME' | grep -q '^sdd-tool-'"

  # Use the suggested name, or fallback
  PLUGIN_NAME="${SUGGESTED_NAME:-sdd-tool-markdown-linter}"

  echo ""

  # ── Step 3: Scaffold plugin in quarantine ──
  echo "Step 3: Scaffold plugin in quarantine"

  SCAFFOLD_RESULT="$( set +eu; scaffold_plugin \
    --gap-id "$GAP_ID" \
    --plugin-name "$PLUGIN_NAME" \
    --workdir "$TEMP_DIR" \
    --gap-analysis "$GAP_RESULT" 2>/dev/null )" || true

  QUARANTINE_PATH="$TEMP_DIR/.devloop/quarantine/$PLUGIN_NAME"

  assert "Quarantine directory created" "[ -d '$QUARANTINE_PATH' ]"
  assert "plugin.json created in quarantine" "[ -f '$QUARANTINE_PATH/.claude-plugin/plugin.json' ]"
  assert "SKILL.md created in quarantine" \
    "find '$QUARANTINE_PATH/skills' -name 'SKILL.md' 2>/dev/null | grep -q 'SKILL.md'"
  assert "Test stubs created in quarantine" \
    "find '$QUARANTINE_PATH/tests' -name 'test_*.sh' 2>/dev/null | grep -q 'test_'"

  # Verify plugin.json content
  if [ -f "$QUARANTINE_PATH/.claude-plugin/plugin.json" ]; then
    assert "plugin.json author is devloop-selfgen" \
      "python3 -c 'import json; d=json.load(open(\"$QUARANTINE_PATH/.claude-plugin/plugin.json\")); assert d[\"author\"] == \"devloop-selfgen\"'"
    assert "plugin.json version is 0.1.0" \
      "python3 -c 'import json; d=json.load(open(\"$QUARANTINE_PATH/.claude-plugin/plugin.json\")); assert d[\"version\"] == \"0.1.0\"'"
    assert "plugin.json has created_by_session" \
      "python3 -c 'import json; d=json.load(open(\"$QUARANTINE_PATH/.claude-plugin/plugin.json\")); assert len(d.get(\"created_by_session\",\"\")) > 0'"
  fi

  echo ""

  # ── Step 4: Validate in quarantine ──
  echo "Step 4: Validate in quarantine"

  VALIDATE_RESULT="$( set +eu; validate_quarantine \
    --plugin-name "$PLUGIN_NAME" \
    --workdir "$TEMP_DIR" 2>/dev/null )" || true

  VALIDATION_STATUS=""
  if [ -n "$VALIDATE_RESULT" ]; then
    VALIDATION_STATUS=$(python3 -c "
import json
try:
    d = json.loads('''${VALIDATE_RESULT}''')
    print(d.get('overall_status', d.get('status', d.get('quarantine_status', 'unknown'))))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")
  fi

  assert "Validation completed with a result" "[ -n '$VALIDATE_RESULT' ]"
  assert "Validation result has test_coverage" \
    "python3 -c '
import json
d = json.loads(\"\"\"${VALIDATE_RESULT}\"\"\")
vr = d.get(\"validation_results\", d)
assert \"test_coverage\" in vr, f\"got {list(vr.keys())}\"
' 2>/dev/null"
  assert "Validation result has security_scan" \
    "python3 -c '
import json
d = json.loads(\"\"\"${VALIDATE_RESULT}\"\"\")
vr = d.get(\"validation_results\", d)
assert \"security_scan\" in vr, f\"got {list(vr.keys())}\"
' 2>/dev/null"
  assert "Validation result has constitutional_review" \
    "python3 -c '
import json
d = json.loads(\"\"\"${VALIDATE_RESULT}\"\"\")
vr = d.get(\"validation_results\", d)
assert \"constitutional_review\" in vr, f\"got {list(vr.keys())}\"
' 2>/dev/null"

  echo ""

  # ── Step 5: Register plugin ──
  echo "Step 5: Register plugin"

  # Remove any previous sync marker
  rm -f "$TEMP_DIR/.bridge-sync-marker"

  REG_RESULT="$( set +eu; register_plugin \
    --plugin-name "$PLUGIN_NAME" \
    --workdir "$TEMP_DIR" 2>/dev/null )" || true

  PLUGINS_PATH="$TEMP_DIR/plugins/$PLUGIN_NAME"

  # ── Step 5a: Verify in plugins/ ──
  echo "Step 5a: Verify plugin in plugins/"
  assert "Plugin exists in plugins/ directory" "[ -d '$PLUGINS_PATH' ]"
  assert "Plugin removed from quarantine" "[ ! -d '$QUARANTINE_PATH' ]"
  assert "plugin.json exists in plugins/" "[ -f '$PLUGINS_PATH/.claude-plugin/plugin.json' ]"

  # ── Step 5b: Verify command bridge sync ──
  echo "Step 5b: Verify command bridge sync"
  assert "Command bridge sync was triggered" "[ -f '$TEMP_DIR/.bridge-sync-marker' ]"

  # ── Step 5c: Verify RL metrics ──
  echo "Step 5c: Verify RL metrics initialized"

  if [ -n "$REG_RESULT" ]; then
    assert "Registration result indicates RL metrics initialized" \
      "python3 -c '
import json
d = json.loads(\"\"\"${REG_RESULT}\"\"\")
assert d.get(\"rl_metrics_initialized\", False) == True or \"rl_metrics\" in str(d), f\"got {d}\"
' 2>/dev/null"
  fi

  # Check plugin.json for RL metrics defaults
  if [ -f "$PLUGINS_PATH/.claude-plugin/plugin.json" ]; then
    assert "Registered plugin has rl_metrics.success_rate = 0.5" \
      "python3 -c '
import json
d = json.load(open(\"$PLUGINS_PATH/.claude-plugin/plugin.json\"))
rl = d.get(\"rl_metrics\", {})
assert rl.get(\"success_rate\") == 0.5, f\"got {rl.get(\"success_rate\")}\"
' 2>/dev/null"
    assert "Registered plugin has rl_metrics.selection_weight = 0.5" \
      "python3 -c '
import json
d = json.load(open(\"$PLUGINS_PATH/.claude-plugin/plugin.json\"))
rl = d.get(\"rl_metrics\", {})
assert rl.get(\"selection_weight\") == 0.5, f\"got {rl.get(\"selection_weight\")}\"
' 2>/dev/null"
    assert "Registered plugin has rl_metrics.invocation_count = 0" \
      "python3 -c '
import json
d = json.load(open(\"$PLUGINS_PATH/.claude-plugin/plugin.json\"))
rl = d.get(\"rl_metrics\", {})
assert rl.get(\"invocation_count\") == 0, f\"got {rl.get(\"invocation_count\")}\"
' 2>/dev/null"
  fi

  # ── Step 5d: Verify plugin is usable ──
  echo "Step 5d: Verify plugin is usable"

  assert "Registered plugin has a SKILL.md" \
    "find '$PLUGINS_PATH/skills' -name 'SKILL.md' 2>/dev/null | grep -q 'SKILL.md'"
  assert "Registered plugin has test files" \
    "find '$PLUGINS_PATH/tests' -name 'test_*.sh' 2>/dev/null | grep -q 'test_'"

  if [ -f "$PLUGINS_PATH/.claude-plugin/plugin.json" ]; then
    assert "Registered plugin has valid JSON plugin.json" \
      "python3 -c 'import json; json.load(open(\"$PLUGINS_PATH/.claude-plugin/plugin.json\"))'"
    assert "Registered plugin has author = devloop-selfgen" \
      "python3 -c 'import json; d=json.load(open(\"$PLUGINS_PATH/.claude-plugin/plugin.json\")); assert d[\"author\"] == \"devloop-selfgen\"'"
    assert "Registered plugin has name with sdd-tool- prefix" \
      "python3 -c 'import json; d=json.load(open(\"$PLUGINS_PATH/.claude-plugin/plugin.json\")); assert d[\"name\"].startswith(\"sdd-tool-\")'"
  fi

else
  # Fallback: all tests fail if self-extension library not available
  for i in $(seq 1 30); do
    assert "Lifecycle test $i (self-extension.sh not available)" "false"
  done
fi

echo ""

# ══════════════════════════════════════════════════════
# LIFECYCLE TEST 2: Failure Path — Security Scan Failure
# Plugin should remain in quarantine with "failed" status
# ══════════════════════════════════════════════════════
echo "=== Lifecycle Test 2: Failure Path (Security Scan Failure) ==="
echo ""

if $SELF_EXT_AVAILABLE; then
  FAIL_TEMP=$(mktemp -d "${TMPDIR:-/tmp}/devloop-selfext-fail-XXXXXX")
  mkdir -p "$FAIL_TEMP/.devloop/quarantine"
  mkdir -p "$FAIL_TEMP/plugins"

  # Scaffold a plugin with deliberate security vulnerabilities
  INSECURE_NAME="sdd-tool-insecure-test"
  INSECURE_Q="$FAIL_TEMP/.devloop/quarantine/$INSECURE_NAME"
  mkdir -p "$INSECURE_Q/.claude-plugin"
  mkdir -p "$INSECURE_Q/skills/insecure-test"
  mkdir -p "$INSECURE_Q/tests/contract"
  mkdir -p "$INSECURE_Q/lib"

  # Create plugin.json
  cat > "$INSECURE_Q/.claude-plugin/plugin.json" <<'INSECJSON'
{
  "name": "sdd-tool-insecure-test",
  "version": "0.1.0",
  "description": "Plugin with security vulnerabilities",
  "author": "devloop-selfgen",
  "entrypoint": "skills/insecure-test/SKILL.md",
  "permissions_required": ["Read", "Bash"],
  "created_by_session": "fail-test-session",
  "gap_id": "gap-fail-test",
  "quarantine_lifecycle": { "status": "pending" }
}
INSECJSON

  # SKILL.md is fine
  echo "# Insecure Test Skill" > "$INSECURE_Q/skills/insecure-test/SKILL.md"

  # Lib file with hardcoded secret AND command injection
  cat > "$INSECURE_Q/lib/vulnerable.sh" <<'VULNEOF'
#!/usr/bin/env bash
# SECURITY VULNERABILITY: Hardcoded API key
API_KEY="sk-proj-1234567890abcdefghijklmnopqrstuvwxyz"
SECRET_TOKEN="ghp_abcdef1234567890"

# SECURITY VULNERABILITY: Unsanitized eval
process_input() {
  eval "$1"
}
VULNEOF

  # Test that passes (so test coverage is not the reason for failure)
  cat > "$INSECURE_Q/tests/contract/test_insecure.sh" <<'INSECTEST'
#!/usr/bin/env bash
PASS=0; FAIL=0; TOTAL=0
TOTAL=$((TOTAL+1)); PASS=$((PASS+1)); echo "PASS: stub"
echo "Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
exit 0
INSECTEST
  chmod +x "$INSECURE_Q/tests/contract/test_insecure.sh"

  # ── Run validation (should fail on security scan) ──
  echo "Running quarantine validation on insecure plugin"

  FAIL_VALIDATE="$( set +eu; validate_quarantine \
    --plugin-name "$INSECURE_NAME" \
    --workdir "$FAIL_TEMP" 2>/dev/null )" || true

  FAIL_STATUS=""
  if [ -n "$FAIL_VALIDATE" ]; then
    FAIL_STATUS=$(python3 -c "
import json
try:
    d = json.loads('''${FAIL_VALIDATE}''')
    print(d.get('overall_status', d.get('status', d.get('quarantine_status', 'unknown'))))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")
  fi

  assert "Validation returned a result" "[ -n '$FAIL_VALIDATE' ]"
  assert "Validation status is failed" "[ '$FAIL_STATUS' = 'failed' ]"

  # ── Verify plugin remains in quarantine ──
  assert "Plugin remains in quarantine directory" \
    "[ -d '$INSECURE_Q' ]"
  assert "Plugin NOT moved to plugins/" \
    "[ ! -d '$FAIL_TEMP/plugins/$INSECURE_NAME' ]"

  # ── Verify quarantine status updated in plugin.json ──
  if [ -f "$INSECURE_Q/.claude-plugin/plugin.json" ]; then
    QUARANTINE_STATUS=$(python3 -c "
import json
d = json.load(open('$INSECURE_Q/.claude-plugin/plugin.json'))
ql = d.get('quarantine_lifecycle', {})
print(ql.get('status', 'unknown'))
" 2>/dev/null || echo "unknown")

    assert "Quarantine status in plugin.json is 'failed'" \
      "[ '$QUARANTINE_STATUS' = 'failed' ]"
  fi

  # ── Verify security scan specifically failed ──
  assert "Security scan status is failed" \
    "python3 -c '
import json
d = json.loads(\"\"\"${FAIL_VALIDATE}\"\"\")
vr = d.get(\"validation_results\", d)
sec = vr.get(\"security_scan\", {})
assert sec.get(\"status\") == \"failed\", f\"got {sec}\"
' 2>/dev/null"

  # ── Attempt to register the failed plugin (should error) ──
  REG_FAIL="$( set +eu; register_plugin \
    --plugin-name "$INSECURE_NAME" \
    --workdir "$FAIL_TEMP" 2>/dev/null )" || true

  assert "Registration rejected for failed plugin (VALIDATION_NOT_PASSED)" \
    "echo '$REG_FAIL' | grep -q 'VALIDATION_NOT_PASSED'"

  # ── Cleanup ──
  rm -rf "$FAIL_TEMP"

else
  for i in $(seq 1 8); do
    assert "Failure path test $i (self-extension.sh not available)" "false"
  done
fi

echo ""

# ══════════════════════════════════════════════════════
# LIFECYCLE TEST 3: No Gap Detected (Below Threshold)
# ══════════════════════════════════════════════════════
echo "=== Lifecycle Test 3: No Gap Detected (Below Threshold) ==="
echo ""

if $SELF_EXT_AVAILABLE; then
  NOGAP_TEMP=$(mktemp -d "${TMPDIR:-/tmp}/devloop-selfext-nogap-XXXXXX")
  NOGAP_SESSION="$NOGAP_TEMP/.devloop/sessions/nogap-session"
  mkdir -p "$NOGAP_SESSION"

  # Create event log with only 2 errors (below threshold of 3)
  NOGAP_LOG="$NOGAP_SESSION/events.jsonl"
  TS=$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")
  cat > "$NOGAP_LOG" <<NOGAPEOF
{"event_id":"evt-ng-1","session_id":"nogap-session","timestamp":"${TS}","iteration":1,"event_type":"error","content":"TOOL_NOT_FOUND: rare tool missing","metadata":{"error":"TOOL_NOT_FOUND","severity":"error"}}
{"event_id":"evt-ng-2","session_id":"nogap-session","timestamp":"${TS}","iteration":2,"event_type":"error","content":"TOOL_NOT_FOUND: rare tool missing","metadata":{"error":"TOOL_NOT_FOUND","severity":"error"}}
{"event_id":"evt-ng-3","session_id":"nogap-session","timestamp":"${TS}","iteration":3,"event_type":"action","content":"Some action","metadata":{}}
NOGAPEOF

  NOGAP_RESULT="$( set +eu; detect_gap --session-dir "$NOGAP_SESSION" --min-frequency 3 2>/dev/null )" || true

  assert "No gap detected for below-threshold errors" \
    "python3 -c '
import json
d = json.loads(\"\"\"${NOGAP_RESULT}\"\"\")
assert d.get(\"gap_detected\") == False or \"gap_id\" not in d, f\"got {d}\"
' 2>/dev/null"

  rm -rf "$NOGAP_TEMP"

else
  assert "No gap detected for below-threshold errors" "false"
fi

echo ""

# ──────────────────────────────────────────────────────
# Results summary
# ──────────────────────────────────────────────────────
echo "======================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "======================================="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
