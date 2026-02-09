#!/usr/bin/env bash
# Contract Tests: Memory Context Search
# Validates memory search, tier priority, filtering, and timeout behavior
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

MEMORY_SEARCH="plugins/sdd-memory/scripts/memory-search.sh"
MEMORY_LOG="plugins/sdd-memory/scripts/memory-log.sh"
MEMORY_CONF="plugins/sdd-memory/config/memory.conf"

echo "═══ Memory Context Search Contract Tests ═══"
echo ""

# ── Plugin Infrastructure Tests ──
echo "Plugin infrastructure"
assert "sdd-memory plugin.json exists" "[ -f plugins/sdd-memory/plugin.json ]"
assert "sdd-memory plugin.json is valid JSON" \
  "python3 -c 'import json; json.load(open(\"plugins/sdd-memory/plugin.json\"))'"
assert "memory.conf exists" "[ -f $MEMORY_CONF ]"
assert "memory-search.sh exists" "[ -f $MEMORY_SEARCH ]"
assert "memory-search.sh is executable" "[ -x $MEMORY_SEARCH ]"
assert "memory-log.sh exists" "[ -f $MEMORY_LOG ]"
assert "memory-log.sh is executable" "[ -x $MEMORY_LOG ]"
assert "context-injection skill exists" \
  "[ -f plugins/sdd-memory/skills/context-injection/SKILL.md ]"
assert "memory-context-agent exists" \
  "[ -f plugins/sdd-memory/agents/memory-context-agent.md ]"

# ── Configuration Tests ──
echo ""
echo "Memory configuration"
assert "Config has MEMORY_ENABLED" "grep -q 'MEMORY_ENABLED' $MEMORY_CONF"
assert "Config has MEMORY_TIMEOUT_MS" "grep -q 'MEMORY_TIMEOUT_MS' $MEMORY_CONF"
assert "Config has MEMORY_MAX_TOKENS" "grep -q 'MEMORY_MAX_TOKENS' $MEMORY_CONF"
assert "Config has MEMORY_CONFIDENCE_THRESHOLD" "grep -q 'MEMORY_CONFIDENCE_THRESHOLD' $MEMORY_CONF"

# ── Memory Search Output Tests ──
echo ""
echo "Memory search behavior"

# Test with a query that should find something (constitution is always there)
SEARCH_OUTPUT=$(bash "$MEMORY_SEARCH" "constitution principles governance" 2>/dev/null || echo "")
SEARCH_OUTPUT_LEN=${#SEARCH_OUTPUT}
assert "Search returns output for known content" "[ $SEARCH_OUTPUT_LEN -gt 0 ]"

# Test output format
if [ -n "$SEARCH_OUTPUT" ]; then
  HAS_HEADER=$(echo "$SEARCH_OUTPUT" | head -1 | grep -c "MEMORY CONTEXT" || echo "0")
  assert "Search output has MEMORY CONTEXT header" "[ '$HAS_HEADER' -ge 1 ]"
fi

# Test with gibberish query — should return empty/minimal
EMPTY_OUTPUT=$(bash "$MEMORY_SEARCH" "xyzzy98765nonexistenttermfoobar" 2>/dev/null || echo "")
NO_RESULTS=$(echo "$EMPTY_OUTPUT" | grep -c "No relevant context found" || echo "0")
assert "Search returns no-results message for gibberish query" "[ '$NO_RESULTS' -ge 1 ] || [ -z '$EMPTY_OUTPUT' ]"

# ── Timeout Tests ──
echo ""
echo "Timeout and error handling"
# Search should complete within 5 seconds
START=$(date +%s)
bash "$MEMORY_SEARCH" "test query" >/dev/null 2>&1 || true
END=$(date +%s)
DURATION=$((END - START))
assert "Memory search completes within 5 seconds" "[ $DURATION -le 5 ]"

# ── Integration with Hook ──
echo ""
echo "Hook integration"
HOOK_SCRIPT=".claude/hooks/user-prompt-submit/governance-preflight.sh"
assert "Preflight hook references memory-search.sh" "grep -q 'memory-search.sh' $HOOK_SCRIPT"
assert "Preflight hook references memory-log.sh" "grep -q 'memory-log.sh' $HOOK_SCRIPT"

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
exit $FAIL
