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
      | sed -n '1p' | sed 's/.*"permissionDecision"[^"]*"\([^"]*\)".*/\1/'
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

# §7.3: read-only git from a subagent -> ALLOW (explicit allowlist), while the
# write forms and the code-execution globals stay denied.
SUB_RO_JSON='{"tool_name":"Bash","agent_id":"a8e123","agent_type":"general-purpose","tool_input":{"command":"git status"}}'
D="$(printf '%s' "$SUB_RO_JSON" | bash "$GUARD" | decision)"
assert "subagent git status -> allow (read-only allowlist, got '$D')" "[ '$D' = 'allow' ]"
SUB_RO2_JSON='{"tool_name":"Bash","agent_id":"a8e123","agent_type":"general-purpose","tool_input":{"command":"git log --oneline -20"}}'
D="$(printf '%s' "$SUB_RO2_JSON" | bash "$GUARD" | decision)"
assert "subagent git log -> allow (read-only allowlist, got '$D')" "[ '$D' = 'allow' ]"
SUB_BR_JSON='{"tool_name":"Bash","agent_id":"a8e123","agent_type":"general-purpose","tool_input":{"command":"git branch newfeature"}}'
D="$(printf '%s' "$SUB_BR_JSON" | bash "$GUARD" | decision)"
assert "subagent git branch <name> -> deny (got '$D')" "[ '$D' = 'deny' ]"
SUB_CFG_JSON='{"tool_name":"Bash","agent_id":"a8e123","agent_type":"general-purpose","tool_input":{"command":"git -c core.fsmonitor=evil status"}}'
D="$(printf '%s' "$SUB_CFG_JSON" | bash "$GUARD" | decision)"
assert "subagent git -c core.fsmonitor=<cmd> -> deny (got '$D')" "[ '$D' = 'deny' ]"

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

echo ""
echo "--- gh gate (server-side repo mutation via the GitHub CLI) ---"

# Subagent running ANY gh -> DENY (categorical, mirrors the git rule).
SUB_GH_JSON='{"tool_name":"Bash","agent_id":"a8e123","agent_type":"general-purpose","tool_input":{"command":"gh pr merge 12 --squash"}}'
D="$(printf '%s' "$SUB_GH_JSON" | bash "$GUARD" | decision)"
assert "subagent gh pr merge -> deny (got '$D')" "[ '$D' = 'deny' ]"
SUB_GHR_JSON='{"tool_name":"Bash","agent_id":"a8e123","agent_type":"general-purpose","tool_input":{"command":"gh pr list"}}'
D="$(printf '%s' "$SUB_GHR_JSON" | bash "$GUARD" | decision)"
assert "subagent gh pr list -> deny (got '$D')" "[ '$D' = 'deny' ]"

# Main agent: consequential gh -> ask; read-only gh -> allow.
MAIN_GH_MERGE='{"tool_name":"Bash","tool_input":{"command":"gh pr merge 12 --squash"}}'
D="$(printf '%s' "$MAIN_GH_MERGE" | bash "$GATE" | decision)"
assert "main-agent gh pr merge -> gate asks (got '$D')" "[ '$D' = 'ask' ]"
MAIN_GH_WF='{"tool_name":"Bash","tool_input":{"command":"gh workflow run promote-to-main.yml"}}'
D="$(printf '%s' "$MAIN_GH_WF" | bash "$GATE" | decision)"
assert "main-agent gh workflow run -> gate asks (got '$D')" "[ '$D' = 'ask' ]"
MAIN_GH_API='{"tool_name":"Bash","tool_input":{"command":"gh api -X PUT repos/o/r/pulls/9/merge"}}'
D="$(printf '%s' "$MAIN_GH_API" | bash "$GATE" | decision)"
assert "main-agent gh api -X PUT (merge laundering) -> gate asks (got '$D')" "[ '$D' = 'ask' ]"
MAIN_GH_LIST='{"tool_name":"Bash","tool_input":{"command":"gh pr list"}}'
D="$(printf '%s' "$MAIN_GH_LIST" | bash "$GATE" | decision)"
assert "main-agent gh pr list -> gate allows (got '$D')" "[ '$D' = 'allow' ]"

# git worktree add/remove are mutations for the main agent; list is not.
MAIN_WT_ADD='{"tool_name":"Bash","tool_input":{"command":"git worktree add ../wt br"}}'
D="$(printf '%s' "$MAIN_WT_ADD" | bash "$GATE" | decision)"
assert "main-agent git worktree add -> gate asks (got '$D')" "[ '$D' = 'ask' ]"
MAIN_WT_LIST='{"tool_name":"Bash","tool_input":{"command":"git worktree list"}}'
D="$(printf '%s' "$MAIN_WT_LIST" | bash "$GATE" | decision)"
assert "main-agent git worktree list -> gate allows (got '$D')" "[ '$D' = 'allow' ]"

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

# ── protect-governance-files: the model can't soften its own rules ──
PROT="$HOOK_DIR/protect-governance-files.sh"
pdecision() { printf '%s' "$1" | bash "$PROT" | decision; }
assert "protect-governance-files.sh exists" "[ -f '$PROT' ]"
assert "protect-governance-files.sh passes bash -n" "bash -n '$PROT'"
# subagent editing a hook -> deny
SUB_HOOK="{\"tool_name\":\"Edit\",\"agent_id\":\"a1\",\"agent_type\":\"x\",\"tool_input\":{\"file_path\":\"$ROOT_DIR/.claude/hooks/freeze-write-scope.sh\"}}"
D="$(pdecision "$SUB_HOOK")"; assert "subagent edit of a hook -> deny (got '$D')" "[ '$D' = 'deny' ]"
# main editing the constitution -> ask
MAIN_CONST="{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$ROOT_DIR/.logic-loom/memory/constitution.md\"}}"
D="$(pdecision "$MAIN_CONST")"; assert "main edit of constitution -> ask (got '$D')" "[ '$D' = 'ask' ]"
# main editing settings.json -> ask
MAIN_SET="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$ROOT_DIR/.claude/settings.json\"}}"
D="$(pdecision "$MAIN_SET")"; assert "main edit of settings.json -> ask (got '$D')" "[ '$D' = 'ask' ]"
# main editing a normal source file -> allow
MAIN_SRC="{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$ROOT_DIR/src/app.ts\"}}"
D="$(pdecision "$MAIN_SRC")"; assert "main edit of normal file -> allow (got '$D')" "[ '$D' = 'allow' ]"
# subagent Bash redirect into settings.json -> deny
SUB_BASH="{\"tool_name\":\"Bash\",\"agent_id\":\"a1\",\"tool_input\":{\"command\":\"echo x > .claude/settings.json\"}}"
D="$(pdecision "$SUB_BASH")"; assert "subagent bash-write to settings.json -> deny (got '$D')" "[ '$D' = 'deny' ]"
# main Bash READ of a governance file -> allow (reads are fine)
MAIN_READ="{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cat .logic-loom/memory/constitution.md\"}}"
D="$(pdecision "$MAIN_READ")"; assert "main bash-read of constitution -> allow (got '$D')" "[ '$D' = 'allow' ]"

# ── Subagent inheritance: freeze-write-scope still fires inside a subagent ──
# (PreToolUse hooks DO run in subagents — agent_id present — so freeze must still
#  enforce. Default-allow when no active DAG context, which is the case here.)
FZ="$ROOT_DIR/.claude/hooks/freeze-write-scope.sh"
FZ_SUB="{\"tool_name\":\"Edit\",\"agent_id\":\"a1\",\"tool_input\":{\"file_path\":\"$ROOT_DIR/src/x.ts\"}}"
FZ_D="$(printf '%s' "$FZ_SUB" | bash "$FZ" | decision)"
assert "freeze-write-scope runs in subagent context (no-DAG -> allow, got '$FZ_D')" "[ '$FZ_D' = 'allow' ]"

echo ""
echo "── The floor must hold on a machine with NEITHER jq NOR python3 ──"
# A slim CI or dev container is an ordinary adopter environment, and it broke the
# floor silently. Both constitutional guards parsed the hook payload jq->python3
# with no third rung; with neither present every field read empty, an empty
# agent_id read as "main agent", and the guards returned ALLOW where they deny on
# a normal machine. Principle VI and the rule-protection hook simply stopped
# holding, with nothing said to the adopter. git-safety-gate.sh already had a
# grep rung, which is the only reason it survived — so it is the control here.
# The assertion is DIVERGENCE: same input, same decision, both environments.
NOBIN="$(mktemp -d)"
for t in bash sh grep sed awk cat tr cut head tail wc git dirname basename mktemp rm ls printf test expr; do
  for d in /usr/bin /bin /usr/sbin /sbin; do
    [ -x "$d/$t" ] && { ln -sf "$d/$t" "$NOBIN/$t"; break; }
  done
done
# The stub PATH is only meaningful if it really lacks both parsers AND can still
# run the hooks; a malformed one produced a false ALLOW while this was written.
assert "the degraded-PATH fixture genuinely has no jq" \
  "! PATH='$NOBIN' command -v jq >/dev/null 2>&1"
assert "the degraded-PATH fixture genuinely has no python3" \
  "! PATH='$NOBIN' command -v python3 >/dev/null 2>&1"
assert "the degraded-PATH fixture can still run grep (else every result below is void)" \
  "PATH='$NOBIN' grep --version >/dev/null 2>&1"

floor_same() { # label  hook  json  expected
  _full="$(printf '%s' "$3" | bash "$2" 2>/dev/null | decision)"
  _min="$(printf '%s' "$3" | PATH="$NOBIN" bash "$2" 2>/dev/null | decision)"
  assert "$1: '$4' on a normal machine (got '$_full')" "[ '$_full' = '$4' ]"
  assert "$1: SAME decision with no jq and no python3 (got '$_min')" "[ '$_min' = '$4' ]"
}
SGG="$ROOT_DIR/plugins/loom-governance/hooks/scripts/subagent-git-guard.sh"
PGF="$ROOT_DIR/plugins/loom-governance/hooks/scripts/protect-governance-files.sh"
GSG="$ROOT_DIR/plugins/loom-governance/hooks/scripts/git-safety-gate.sh"
floor_same "subagent git push" "$SGG" \
  '{"tool_name":"Bash","agent_id":"s1","tool_input":{"command":"git push origin main"}}' deny
floor_same "subagent gh" "$SGG" \
  '{"tool_name":"Bash","agent_id":"s1","tool_input":{"command":"gh pr merge 1"}}' deny
floor_same "subagent read-only git stays allowed" "$SGG" \
  '{"tool_name":"Bash","agent_id":"s1","tool_input":{"command":"git status"}}' allow
floor_same "subagent writes settings.json" "$PGF" \
  '{"tool_name":"Write","agent_id":"s1","tool_input":{"file_path":".claude/settings.json"}}' deny
floor_same "subagent writes the constitution" "$PGF" \
  '{"tool_name":"Write","agent_id":"s1","tool_input":{"file_path":".logic-loom/memory/constitution.md"}}' deny
floor_same "main agent git push (control: already survived)" "$GSG" \
  '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' ask
# External review flagged these two as uncovered, and both are ordinary shapes a
# host can emit — not exotic input. Pretty-printed JSON breaks a naive one-line
# grep; `agent_type` without `agent_id` is a MAIN-agent payload that an
# over-broad degraded-mode trigger would misclassify as a subagent and deny.
ML_JSON="$(printf '{\n  "tool_name": "Bash",\n  "agent_id": "s1",\n  "tool_input": {\n    "command": "git push origin main"\n  }\n}')"
floor_same "multi-line JSON still denies a subagent push" "$SGG" "$ML_JSON" deny
floor_same "agent_type WITHOUT agent_id is the main agent, not a subagent" "$SGG" \
  '{"tool_name":"Bash","agent_type":"general","tool_input":{"command":"git push origin main"}}' allow

# ── LOOM-0044 ──────────────────────────────────────────────────────────────
# The degraded-parse fix (LOOM-0043) made the hooks restrictive about WHO is
# calling but they stayed permissive about WHAT: an empty extraction fell through
# to an explicit `allow`. With no structured parser an empty value is not
# evidence the field is absent — it is evidence we cannot read it.
#
# These deliberately do NOT use floor_same: the decision SHOULD differ between a
# healthy and a degraded host. On a healthy host an absent field is genuinely
# absent (allow); on a degraded host it is unreadable (deny/ask).
deg() { printf '%s' "$2" | PATH="$NOBIN" bash "$1" 2>/dev/null | decision; }
hlt() { printf '%s' "$2" | bash "$1" 2>/dev/null | decision; }

_d="$(deg "$SGG" '{"tool_name":"Bash","agent_id":"s1","tool_input":{}}')"
assert "LOOM-0044: subagent with an UNREADABLE command is denied on a degraded host (got '$_d')" "[ '$_d' = 'deny' ]"
_h="$(hlt "$SGG" '{"tool_name":"Bash","agent_id":"s1","tool_input":{}}')"
assert "LOOM-0044: same payload on a HEALTHY host still allows — the field really is absent (got '$_h')" "[ '$_h' = 'allow' ]"

_d="$(deg "$PGF" '{"tool_name":"Write","agent_id":"s1","tool_input":{}}')"
assert "LOOM-0044: subagent with an UNREADABLE file_path is denied on a degraded host (got '$_d')" "[ '$_d' = 'deny' ]"
_h="$(hlt "$PGF" '{"tool_name":"Write","agent_id":"s1","tool_input":{}}')"
assert "LOOM-0044: same payload on a HEALTHY host still allows (got '$_h')" "[ '$_h' = 'allow' ]"

_d="$(deg "$PGF" '{"tool_name":"Write","tool_input":{}}')"
assert "LOOM-0044: MAIN agent with an unreadable file_path is ASKED, not denied (got '$_d')" "[ '$_d' = 'ask' ]"
_d="$(deg "$PGF" '{"tool_name":"Bash","tool_input":{}}')"
assert "LOOM-0044: MAIN agent with an unreadable command is ASKED, not denied (got '$_d')" "[ '$_d' = 'ask' ]"

# ANTI-LOCKOUT. The whole risk of this change is turning a degraded host into an
# unusable one. A readable, harmless command must still pass on a degraded host —
# only genuinely unreadable payloads escalate. If this ever flips to ask/deny the
# fix has become a lockout and must be reverted.
_d="$(deg "$SGG" '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}')"
assert "LOOM-0044 anti-lockout: a READABLE harmless command still allows on a degraded host (got '$_d')" "[ '$_d' = 'allow' ]"
_d="$(deg "$PGF" '{"tool_name":"Write","tool_input":{"file_path":"README.md"}}')"
assert "LOOM-0044 anti-lockout: a READABLE harmless write still allows on a degraded host (got '$_d')" "[ '$_d' = 'allow' ]"

rm -rf "$NOBIN"

echo ""
echo "======================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "======================================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
