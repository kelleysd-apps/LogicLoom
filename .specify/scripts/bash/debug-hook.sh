#!/usr/bin/env bash
# Debug UserPromptSubmit Hook
# Tests hook execution and validates output
# Constitutional Principle VI: No git operations
# Version: 1.0.0

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HOOK_SCRIPT="$REPO_ROOT/.claude/hooks/user-prompt-submit/governance-preflight.sh"
SETTINGS_FILE="$REPO_ROOT/.claude/settings.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
PASS_COUNT=0
FAIL_COUNT=0

# ============================================
# Functions
# ============================================

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  UserPromptSubmit Hook Debugger${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
}

test_pass() {
    local message="$1"
    echo -e "${GREEN}✅ PASS${NC}: $message"
    ((PASS_COUNT++))
}

test_fail() {
    local message="$1"
    echo -e "${RED}❌ FAIL${NC}: $message"
    ((FAIL_COUNT++))
}

test_warn() {
    local message="$1"
    echo -e "${YELLOW}⚠️  WARN${NC}: $message"
}

# ============================================
# Tests
# ============================================

print_header

echo -e "${BLUE}[Test 1/7]${NC} Hook script exists"
if [ -f "$HOOK_SCRIPT" ]; then
    test_pass "Hook script found at $HOOK_SCRIPT"
else
    test_fail "Hook script not found at $HOOK_SCRIPT"
    echo "   Expected location: .claude/hooks/user-prompt-submit/governance-preflight.sh"
    exit 1
fi
echo ""

echo -e "${BLUE}[Test 2/7]${NC} Hook script is executable"
if [ -x "$HOOK_SCRIPT" ]; then
    test_pass "Hook script has executable permission"
else
    test_fail "Hook script is not executable"
    echo "   Fix: chmod +x $HOOK_SCRIPT"
fi
echo ""

echo -e "${BLUE}[Test 3/7]${NC} Hook script syntax"
if bash -n "$HOOK_SCRIPT" 2>/dev/null; then
    test_pass "Hook script syntax is valid"
else
    test_fail "Hook script has syntax errors"
    echo "   Run: bash -n $HOOK_SCRIPT"
fi
echo ""

echo -e "${BLUE}[Test 4/7]${NC} Hook execution test"
TEST_INPUT='{"message": "test message", "context": {}}'
if OUTPUT=$(echo "$TEST_INPUT" | "$HOOK_SCRIPT" 2>&1); then
    test_pass "Hook executes without errors"
else
    test_fail "Hook execution failed"
    echo "   Error output:"
    echo "$OUTPUT" | sed 's/^/   /'
fi
echo ""

echo -e "${BLUE}[Test 5/7]${NC} Hook output is valid JSON"
if echo "$OUTPUT" | jq . >/dev/null 2>&1; then
    test_pass "Hook output is valid JSON"
else
    test_fail "Hook output is not valid JSON"
    echo "   Output received:"
    echo "$OUTPUT" | sed 's/^/   /'
fi
echo ""

echo -e "${BLUE}[Test 6/7]${NC} Hook output has required fields"
if echo "$OUTPUT" | jq -e '.blocked' >/dev/null 2>&1; then
    test_pass "Output contains 'blocked' field"
else
    test_fail "Output missing 'blocked' field"
fi

if echo "$OUTPUT" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
    test_pass "Output contains 'hookSpecificOutput.additionalContext' field"
else
    test_fail "Output missing 'hookSpecificOutput.additionalContext' field"
fi
echo ""

echo -e "${BLUE}[Test 7/7]${NC} Settings.json hook configuration"
if [ -f "$SETTINGS_FILE" ]; then
    if grep -q "UserPromptSubmit" "$SETTINGS_FILE" 2>/dev/null; then
        test_pass "settings.json contains UserPromptSubmit hook configuration"

        # Check if hook path is correct
        if grep -q "governance-preflight.sh" "$SETTINGS_FILE" 2>/dev/null; then
            test_pass "Hook path references governance-preflight.sh"
        else
            test_warn "Hook path may be incorrect in settings.json"
        fi
    else
        test_warn "settings.json does not contain UserPromptSubmit hook configuration"
        echo "   Add hook configuration to .claude/settings.json"
    fi
else
    test_fail "settings.json not found at $SETTINGS_FILE"
fi
echo ""

# ============================================
# Additional Checks
# ============================================

echo -e "${BLUE}Additional Checks:${NC}"
echo ""

# Check if audit directory exists
AUDIT_DIR="$REPO_ROOT/.docs/governance/audit"
if [ -d "$AUDIT_DIR" ]; then
    test_pass "Audit directory exists: $AUDIT_DIR"

    # Check if audit logs were created
    TODAY=$(date +%Y-%m-%d)
    if [ -d "$AUDIT_DIR/$TODAY" ]; then
        SESSION_COUNT=$(find "$AUDIT_DIR/$TODAY" -name "session-*.json" 2>/dev/null | wc -l || echo 0)
        if [ "$SESSION_COUNT" -gt 0 ]; then
            test_pass "Audit logs found for today ($SESSION_COUNT sessions)"
        else
            test_warn "No audit logs created today (this is normal if hook not used yet)"
        fi
    else
        test_warn "No audit directory for today (normal if hook not used yet)"
    fi
else
    test_warn "Audit directory does not exist yet (will be created on first hook execution)"
fi
echo ""

# Check hook performance
echo -e "${BLUE}Performance Test:${NC}"
START_TIME=$(date +%s%N 2>/dev/null || echo "0")
echo "$TEST_INPUT" | "$HOOK_SCRIPT" >/dev/null 2>&1
END_TIME=$(date +%s%N 2>/dev/null || echo "0")

if [ "$START_TIME" != "0" ] && [ "$END_TIME" != "0" ]; then
    ELAPSED=$((($END_TIME - $START_TIME) / 1000000))  # Convert to milliseconds
    echo "Hook execution time: ${ELAPSED}ms"

    if [ "$ELAPSED" -lt 200 ]; then
        test_pass "Hook performance excellent (<200ms)"
    elif [ "$ELAPSED" -lt 1000 ]; then
        test_pass "Hook performance acceptable (<1s)"
    else
        test_warn "Hook execution slow (>1s) - may need optimization"
    fi
else
    echo "Performance measurement not available on this system"
fi
echo ""

# ============================================
# Summary
# ============================================

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "${GREEN}✅ Passed:${NC} $PASS_COUNT"
echo -e "${RED}❌ Failed:${NC} $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    echo "Hook is properly configured and working."
    echo ""
    echo "Next steps:"
    echo "  1. Restart Claude Code to activate hook"
    echo "  2. Send a test message to verify governance context injection"
    echo "  3. Check audit logs: ls $AUDIT_DIR/\$(date +%Y-%m-%d)/"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    echo ""
    echo "Fix the issues above and run this script again."
    echo ""
    exit 1
fi
