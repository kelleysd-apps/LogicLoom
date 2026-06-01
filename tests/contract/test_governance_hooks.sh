#!/usr/bin/env bash
# Contract Tests: Governance PreToolUse hooks (Principle VI hardening)
#
# Feeds synthetic PreToolUse JSON on stdin to the real hook scripts and asserts
# the emitted permissionDecision. Two hooks are exercised:
#   - subagent-git-guard.sh : DENY git when a subagent (agent_id present) runs it;
#                             ALLOW (defer) when the main agent (no agent_id) runs it.
#   - git-safety-gate.sh    : ASK on mutating git from the main agent; ALLOW non-git.
#
# Path-prefix bypass cases are intentionally NOT duplicated here — they live in
# .logic-loom/tests/test-git-safety.sh (owned by another suite).
#
# bash 3.2 safe.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0

assert() {
  TOTAL=$((TOTAL + 1))
  local desc="$1"; local condition="$2"
  if eval "$condition"; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_DIR="$ROOT_DIR/plugins/loom-governance/hooks/scripts"
GUARD="$HOOK_DIR/subagent-git-guard.sh"
GATE="$HOOK_DIR/git-safety-gate.sh"

# Extract the permissionDecision value from a hook's JSON stdout.
decision() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null
  else
    grep -oE '"permissionDecision"[[:space:]]*:[[:space:]]*"[^"]*"' \
      | head -1 | sed 's/.*"permissionDecision"[^"]*"\([^"]*\)".*/\1/'
  fi
}

echo "=== Governance Hooks Contract Tests ==="
echo ""

assert "subagent-git-guard.sh exists" "[ -f '$GUARD' ]"
assert "git-safety-gate.sh exists" "[ -f '$GATE' ]"
assert "subagent-git-guard.sh passes bash -n" "bash -n '$GUARD'"
assert "git-safety-gate.sh passes bash -n" "bash -n '$GATE'"

echo ""
echo "--- subagent-git-guard: subagent (agent_id present) ---"

# Subagent running a git command -> DENY.
SUB_GIT_JSON='{"tool_name":"Bash","agent_id":"a8e123","agent_type":"general-purpose","tool_input":{"command":"git clean -fd"}}'
SUB_GIT_DECISION="$(printf '%s' "$SUB_GIT_JSON" | bash "$GUARD" | decision)"
assert "subagent git command -> deny (got '${SUB_GIT_DECISION}')" "[ '${SUB_GIT_DECISION}' = 'deny' ]"

SUB_PUSH_JSON='{"tool_name":"Bash","agent_id":"a8e123","agent_type":"general-purpose","tool_input":{"command":"git push origin main"}}'
SUB_PUSH_DECISION="$(printf '%s' "$SUB_PUSH_JSON" | bash "$GUARD" | decision)"
assert "subagent git push -> deny (got '${SUB_PUSH_DECISION}')" "[ '${SUB_PUSH_DECISION}' = 'deny' ]"

# Subagent running a NON-git command -> allow (not the guard's concern).
SUB_NONGIT_JSON='{"tool_name":"Bash","agent_id":"a8e123","agent_type":"general-purpose","tool_input":{"command":"ls -la"}}'
SUB_NONGIT_DECISION="$(printf '%s' "$SUB_NONGIT_JSON" | bash "$GUARD" | decision)"
assert "subagent non-git command -> allow (got '${SUB_NONGIT_DECISION}')" "[ '${SUB_NONGIT_DECISION}' = 'allow' ]"

echo ""
echo "--- subagent-git-guard: main agent (no agent_id) ---"

# Main agent (no agent_id) running git push -> guard ALLOWS (defers to git-safety-gate).
MAIN_PUSH_JSON='{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
MAIN_PUSH_GUARD_DECISION="$(printf '%s' "$MAIN_PUSH_JSON" | bash "$GUARD" | decision)"
assert "main-agent git push -> guard allows/defers (got '${MAIN_PUSH_GUARD_DECISION}')" "[ '${MAIN_PUSH_GUARD_DECISION}' = 'allow' ]"

# Main agent running a non-git command -> allow.
MAIN_NONGIT_JSON='{"tool_name":"Bash","tool_input":{"command":"echo hello"}}'
MAIN_NONGIT_GUARD_DECISION="$(printf '%s' "$MAIN_NONGIT_JSON" | bash "$GUARD" | decision)"
assert "main-agent non-git -> guard allows (got '${MAIN_NONGIT_GUARD_DECISION}')" "[ '${MAIN_NONGIT_GUARD_DECISION}' = 'allow' ]"

echo ""
echo "--- git-safety-gate: main agent ---"

# git-safety-gate is the second line: it forces approval ("ask") on mutating git.
GATE_PUSH_DECISION="$(printf '%s' "$MAIN_PUSH_JSON" | bash "$GATE" | decision)"
assert "main-agent git push -> gate asks (got '${GATE_PUSH_DECISION}')" "[ '${GATE_PUSH_DECISION}' = 'ask' ]"

# Non-git command -> gate allows.
GATE_NONGIT_DECISION="$(printf '%s' "$MAIN_NONGIT_JSON" | bash "$GATE" | decision)"
assert "main-agent non-git -> gate allows (got '${GATE_NONGIT_DECISION}')" "[ '${GATE_NONGIT_DECISION}' = 'allow' ]"

# Read-only git (status) -> gate allows (not a mutation).
GATE_STATUS_JSON='{"tool_name":"Bash","tool_input":{"command":"git status"}}'
GATE_STATUS_DECISION="$(printf '%s' "$GATE_STATUS_JSON" | bash "$GATE" | decision)"
assert "main-agent git status -> gate allows (got '${GATE_STATUS_DECISION}')" "[ '${GATE_STATUS_DECISION}' = 'allow' ]"

# ── Context-injecting hooks must use the nested hookSpecificOutput schema ──
# A flat {"hookEventName":...,"additionalContext":...} emit is silently dropped
# by the harness (the v6.1 schema regression guard). Counts computed outside the
# assert eval to avoid quoting pitfalls.
CCW="$ROOT_DIR/.claude/hooks/context-cap-warn.sh"
WPN="$ROOT_DIR/.claude/hooks/worktree-port-namespace.sh"
ccw_nested=$(grep -c 'hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext' "$CCW" 2>/dev/null)
ccw_flat=$(grep -cE "printf '\{\"hookEventName\":\"UserPromptSubmit\",\"additionalContext" "$CCW" 2>/dev/null)
wpn_nested=$(grep -c 'hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext' "$WPN" 2>/dev/null)
wpn_flat=$(grep -cE "printf '\{\"hookEventName\":\"SessionStart\",\"additionalContext" "$WPN" 2>/dev/null)
assert "context-cap-warn additionalContext nested, not flat (nested=$ccw_nested flat=$ccw_flat)" "[ \"$ccw_nested\" -ge 1 ] && [ \"$ccw_flat\" -eq 0 ]"
assert "worktree-port additionalContext nested, not flat (nested=$wpn_nested flat=$wpn_flat)" "[ \"$wpn_nested\" -ge 1 ] && [ \"$wpn_flat\" -eq 0 ]"

echo ""
echo "======================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "======================================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
