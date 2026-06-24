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
# Use the real Claude Code envelope key `.prompt` (extraction is
# `.prompt // .message // .messageContent`), with a domain-bearing prompt so the
# lean-mode hook actually injects guidance — NOT the old trivial "hello world"
# that only produced output via the envelope-fallback memory fluke.
HOOK_OUTPUT=$(echo '{"prompt":"fix the authentication endpoint and update the database schema"}' | bash "$HOOK_SCRIPT" 2>/dev/null || echo '{"blocked":false}')

assert "Hook returns valid JSON" \
  "echo '$HOOK_OUTPUT' | python3 -c 'import json,sys; json.load(sys.stdin)'"
assert "Hook output has blocked=false" \
  "echo '$HOOK_OUTPUT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"blocked\") == False'"

# A domain-bearing prompt yields non-empty additionalContext via the REAL
# extraction path (not the envelope fallback).
HAS_CONTEXT=$(echo "$HOOK_OUTPUT" | python3 -c '
import json,sys
d=json.load(sys.stdin)
ctx = d.get("hookSpecificOutput",{}).get("additionalContext","")
print("yes" if len(ctx) > 10 else "no")
' 2>/dev/null || echo "no")
assert "Hook output contains additionalContext for a domain-bearing prompt" "[ '$HAS_CONTEXT' = 'yes' ]"

# Lean mode injects orchestration/domain guidance. The constitutional protocol
# itself lives in CLAUDE.md (not the hook) by design — only NEW info is injected.
HAS_GUIDANCE=$(echo "$HOOK_OUTPUT" | python3 -c '
import json,sys
d=json.load(sys.stdin)
ctx = d.get("hookSpecificOutput",{}).get("additionalContext","")
print("yes" if "DOMAIN DETECTION" in ctx or "Delegation" in ctx else "no")
' 2>/dev/null || echo "no")
assert "Hook injects orchestration/domain guidance (lean mode)" "[ '$HAS_GUIDANCE' = 'yes' ]"

# Strict mode re-injects the governance pre-flight recitation (lean does not).
STRICT_OUT=$(echo '{"prompt":"hello there everyone"}' | LOOM_GOVERNANCE_MODE=strict bash "$HOOK_SCRIPT" 2>/dev/null || echo '{}')
HAS_STRICT=$(echo "$STRICT_OUT" | python3 -c '
import json,sys
ctx=json.load(sys.stdin).get("hookSpecificOutput",{}).get("additionalContext","")
print("yes" if "GOVERNANCE PRE-FLIGHT" in ctx or "CONSTITUTION" in ctx else "no")
' 2>/dev/null || echo "no")
assert "Strict mode injects the governance pre-flight recitation" "[ '$HAS_STRICT' = 'yes' ]"

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

# ── Verification-Intent Disposition (cross-check nudge) ──
echo ""
echo "Verification-intent disposition (cross-check nudge)"
VERIFY_CONF="plugins/loom-orchestrator-hook/config/verification-intent.conf"

# Helper: does the hook's additionalContext contain a needle for a given prompt?
contains() { # $1=prompt text  $2=needle  → echo yes/no
  python3 -c "import json,sys; print(json.dumps({'prompt': sys.argv[1]}))" "$1" \
    | bash "$HOOK_SCRIPT" 2>/dev/null \
    | python3 -c "
import json,sys
ctx=json.load(sys.stdin).get('hookSpecificOutput',{}).get('additionalContext','')
print('yes' if '''$2''' in ctx else 'no')
" 2>/dev/null || echo "no"
}

assert "verification-intent.conf exists" "[ -f $VERIFY_CONF ]"

VI_FIRE=$(contains "are you sure this is correct" "VERIFICATION INTENT DETECTED")
assert "verify nudge fires on a scrutiny ask ('are you sure')" "[ '$VI_FIRE' = 'yes' ]"

VI_KEYAWARE=$(contains "double-check my logic" "does NOT decorrelate")
assert "verify nudge is key-aware (states unkeyed no-op)" "[ '$VI_KEYAWARE' = 'yes' ]"

DF_DOMAIN=$(contains "write a unit test for the parser" "testing")
DF_VERIFY=$(contains "write a unit test for the parser" "VERIFICATION INTENT")
assert "no double-fire: 'unit test' yields testing domain" "[ '$DF_DOMAIN' = 'yes' ]"
assert "no double-fire: 'unit test' does NOT emit verify nudge" "[ '$DF_VERIFY' = 'no' ]"

SEC_SUP=$(contains "cross-check the encryption handling" "VERIFICATION INTENT")
assert "redundancy: verify nudge suppressed when security domain present" "[ '$SEC_SUP' = 'no' ]"

CMD_SUP=$(contains "<command-name>/cross-check</command-name> the diff" "VERIFICATION INTENT")
assert "redundancy: verify nudge suppressed when /cross-check invoked" "[ '$CMD_SUP' = 'no' ]"

REG_DOMAIN=$(contains "add a React component" "frontend")
REG_VERIFY=$(contains "add a React component" "VERIFICATION INTENT")
assert "no regression: 'React component' still detects frontend" "[ '$REG_DOMAIN' = 'yes' ]"
assert "no spurious verify nudge on a plain build ask" "[ '$REG_VERIFY' = 'no' ]"

# Ship-gate: every verify phrase must be substring-disjoint from domains.conf
# keywords, or it double-fires the domain block.
DISJOINT=$(python3 - "$DOMAINS_CONF" "$VERIFY_CONF" <<'PY'
import sys
dom_path, ver_path = sys.argv[1], sys.argv[2]
kws = []
for line in open(dom_path):
    line = line.strip()
    if not line or line.startswith('#'):
        continue
    kw = line.split('=', 1)[0].strip().lower()
    if kw:
        kws.append(kw)
bad = 0
for line in open(ver_path):
    p = line.strip()
    if not p or p.startswith('#'):
        continue
    pl = p.lower()
    for kw in kws:
        if kw in pl:
            bad = 1
            print("COLLISION: '%s' contains domain keyword '%s'" % (p, kw), file=sys.stderr)
print(bad)
PY
)
assert "every verify phrase is substring-disjoint from domains.conf keywords" "[ '$DISJOINT' = '0' ]"

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
