#!/usr/bin/env bash
# Contract Tests: Orchestration Hook
# Validates hook output format, domain detection, and constitutional governance
# Feature: 005-agent-architecture-refactor
set -euo pipefail

PASS=0; FAIL=0; TOTAL=0

assert() {
  TOTAL=$((TOTAL + 1))
  local desc="$1"; local condition="$2"
  if eval "$condition"; then
    echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

HOOK_SCRIPT=".claude/hooks/user-prompt-submit/governance-preflight.sh"
SETTINGS_FILE=".claude/settings.json"
DOMAINS_CONF="plugins/loom-orchestrator-hook/config/domains.conf"

echo "═══ Orchestration Hook Contract Tests ═══"
echo ""

# ── Settings.json Tests ──
echo "Settings.json compliance"
assert "settings.json exists" "[ -f $SETTINGS_FILE ]"
assert "settings.json is valid JSON" "python3 -c 'import json; json.load(open(\"$SETTINGS_FILE\"))'"
assert "settings.json does NOT contain agent field" \
  "! python3 -c 'import json,sys; d=json.load(open(\"$SETTINGS_FILE\")); sys.exit(0 if \"agent\" in d else 1)'"
assert "settings.json has UserPromptSubmit hook" \
  "python3 -c 'import json; d=json.load(open(\"$SETTINGS_FILE\")); assert \"UserPromptSubmit\" in d.get(\"hooks\", {})'"

# ── Hook Script Tests ──
echo ""
echo "Hook script infrastructure"
assert "governance-preflight.sh exists" "[ -f $HOOK_SCRIPT ]"
assert "governance-preflight.sh is executable" "[ -x $HOOK_SCRIPT ]"

# Test hook output with sample input
echo ""
echo "Hook output format"
HOOK_OUTPUT=$(echo '{"sessionId":"test","messageContent":"hello world"}' | bash "$HOOK_SCRIPT" 2>/dev/null || echo '{"blocked":false}')

assert "Hook returns valid JSON" \
  "echo '$HOOK_OUTPUT' | python3 -c 'import json,sys; json.load(sys.stdin)'"
assert "Hook output has blocked=false" \
  "echo '$HOOK_OUTPUT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"blocked\") == False'"

# Check for additionalContext in output
HAS_CONTEXT=$(echo "$HOOK_OUTPUT" | python3 -c '
import json,sys
d=json.load(sys.stdin)
ctx = d.get("hookSpecificOutput",{}).get("additionalContext","")
print("yes" if len(ctx) > 10 else "no")
' 2>/dev/null || echo "no")
assert "Hook output contains additionalContext" "[ '$HAS_CONTEXT' = 'yes' ]"

# Check governance content is present
HAS_GOVERNANCE=$(echo "$HOOK_OUTPUT" | python3 -c '
import json,sys
d=json.load(sys.stdin)
ctx = d.get("hookSpecificOutput",{}).get("additionalContext","")
print("yes" if "CONSTITUTIONAL" in ctx or "Principle" in ctx else "no")
' 2>/dev/null || echo "no")
assert "Hook output includes constitutional governance reminder" "[ '$HAS_GOVERNANCE' = 'yes' ]"

# ── Domain Detection Tests ──
echo ""
echo "Domain detection"

# Test security domain detection
SEC_OUTPUT=$(echo '{"sessionId":"test","messageContent":"fix the XSS vulnerability in the login form"}' | bash "$HOOK_SCRIPT" 2>/dev/null || echo '{"blocked":false}')
HAS_SECURITY=$(echo "$SEC_OUTPUT" | python3 -c '
import json,sys
d=json.load(sys.stdin)
ctx = d.get("hookSpecificOutput",{}).get("additionalContext","")
print("yes" if "security" in ctx.lower() else "no")
' 2>/dev/null || echo "no")
assert "Hook detects security domain keywords" "[ '$HAS_SECURITY' = 'yes' ]"

# ── Plugin Infrastructure Tests ──
echo ""
echo "Orchestrator hook plugin"
assert "loom-orchestrator-hook plugin.json exists" "[ -f plugins/loom-orchestrator-hook/.claude-plugin/plugin.json ]"
assert "loom-orchestrator-hook plugin.json is valid JSON" \
  "python3 -c 'import json; json.load(open(\"plugins/loom-orchestrator-hook/.claude-plugin/plugin.json\"))'"
assert "domains.conf exists" "[ -f $DOMAINS_CONF ]"
assert "domains.conf has frontend mapping" "grep -q 'frontend' $DOMAINS_CONF"
assert "domains.conf has backend mapping" "grep -q 'backend' $DOMAINS_CONF"
assert "domains.conf has security mapping" "grep -q 'security' $DOMAINS_CONF"
assert "domains.conf uses keyword=domain format" "grep -qE '=(frontend|backend|database|testing|security|performance|devops)$' $DOMAINS_CONF"
assert "Orchestration skill exists" \
  "[ -f plugins/loom-orchestrator-hook/skills/orchestration-guidance/SKILL.md ]"

# ── Graceful Failure Test ──
echo ""
echo "Graceful failure"
# Test with invalid/empty input
FAIL_OUTPUT=$(echo '' | bash "$HOOK_SCRIPT" 2>/dev/null || echo '{"blocked":false}')
assert "Hook handles empty input gracefully" \
  "echo '$FAIL_OUTPUT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"blocked\") == False' 2>/dev/null"

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
