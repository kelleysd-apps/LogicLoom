#!/usr/bin/env bash
# Contract Tests: freeze-write-scope.sh PreToolUse hook
#
# Verifies the plan-as-DAG file-ownership enforcement actually fires:
#   - DENY a write to a path OUTSIDE the active task's owns: list
#   - ALLOW a write to a path INSIDE the active task's owns: list
#   - DENY a write to a path in the active task's freeze: list
#   - ALLOW (default) when there is no active DAG context
#   - ALLOW non-write tools regardless of context
#   - Verify the OUTPUT uses the current PreToolUse permissionDecision schema
#
# The hook derives REPO_ROOT from its own location (../.. of the hook dir),
# so the test builds an isolated fake repo tree, copies the hook into
# <fake>/.claude/hooks/, and drives it there. The real repo is never touched.
#
# bash 3.2 safe. No external deps beyond awk/sed/grep (jq optional — the hook
# falls back to grep when jq is absent).
set -u

PASS=0; FAIL=0; TOTAL=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_SRC="$REAL_REPO_ROOT/.claude/hooks/freeze-write-scope.sh"

assert() {
  TOTAL=$((TOTAL + 1))
  local desc="$1"; shift
  if "$@"; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# Build an isolated fake repo tree
FAKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/loom-freeze-test.XXXXXX")"
cleanup() { rm -rf "$FAKE_ROOT"; }
trap cleanup EXIT

mkdir -p "$FAKE_ROOT/.claude/hooks"
mkdir -p "$FAKE_ROOT/features/demo"
cp "$HOOK_SRC" "$FAKE_ROOT/.claude/hooks/freeze-write-scope.sh"
chmod +x "$FAKE_ROOT/.claude/hooks/freeze-write-scope.sh"
HOOK="$FAKE_ROOT/.claude/hooks/freeze-write-scope.sh"

# A flat-format plan.md (the fallback parse path: `## task: <id>` blocks)
cat > "$FAKE_ROOT/features/demo/plan.md" <<'EOF'
# Plan: demo

## task: t1
owns:
  - src/auth/login.ts
  - src/auth/types.ts
freeze:
  - src/payments/charge.ts

## task: t2
owns:
  - src/auth/session.ts
EOF

# Helper: write the active-context marker file with owns/freeze scope.
write_marker() {
  # write_marker <feature> <task> <owns-newline-list> <freeze-newline-list>
  local feature="$1" task="$2" owns="$3" freeze="$4"
  {
    printf 'feature: %s\n' "$feature"
    printf 'task: %s\n' "$task"
    printf 'owns:\n'
    if [ -n "$owns" ]; then
      printf '%s\n' "$owns" | while IFS= read -r p; do [ -n "$p" ] && printf '  - %s\n' "$p"; done
    fi
    printf 'freeze:\n'
    if [ -n "$freeze" ]; then
      printf '%s\n' "$freeze" | while IFS= read -r p; do [ -n "$p" ] && printf '  - %s\n' "$p"; done
    fi
  } > "$FAKE_ROOT/.loom-active-feature"
}

clear_marker() { rm -f "$FAKE_ROOT/.loom-active-feature"; }

# Run the hook with a synthetic PreToolUse payload. Echoes stdout JSON.
# Unsets LOOM_ACTIVE_* so the marker file is the only context source unless
# a test explicitly sets them.
run_hook() {
  # run_hook <tool_name> <abs_file_path>
  local tool="$1" path="$2"
  printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$tool" "$path" \
    | env -u LOOM_ACTIVE_FEATURE -u LOOM_ACTIVE_TASK bash "$HOOK" 2>/dev/null
}

decision_is() {
  # decision_is <expected: allow|deny> <output-json>
  local expected="$1" out="$2"
  case "$out" in
    *'"permissionDecision":"'"$expected"'"'*) return 0 ;;
    *) return 1 ;;
  esac
}

echo "=== freeze-write-scope.sh contract tests ==="
echo "Hook under test: $HOOK_SRC"
echo "Fake repo:       $FAKE_ROOT"
echo ""

# ── 1. DENY outside owns (marker-provided scope) ──
echo "Marker-provided scope"
write_marker demo t1 "src/auth/login.ts"$'\n'"src/auth/types.ts" "src/payments/charge.ts"
out=$(run_hook Edit "$FAKE_ROOT/src/payments/refund.ts")
assert "DENY write outside owns: (src/payments/refund.ts)" decision_is deny "$out"

# ── 2. ALLOW inside owns ──
out=$(run_hook Edit "$FAKE_ROOT/src/auth/login.ts")
assert "ALLOW write inside owns: (src/auth/login.ts)" decision_is allow "$out"

# ── 3. ALLOW inside owns via directory-prefix (owns lists a file, exact) ──
out=$(run_hook Write "$FAKE_ROOT/src/auth/types.ts")
assert "ALLOW write inside owns: (src/auth/types.ts)" decision_is allow "$out"

# ── 4. DENY freeze hit (freeze takes precedence) ──
out=$(run_hook Edit "$FAKE_ROOT/src/payments/charge.ts")
assert "DENY write in freeze: (src/payments/charge.ts)" decision_is deny "$out"

# ── 5. relative path (no repo prefix) outside owns -> DENY ──
out=$(run_hook Edit "src/billing/invoice.ts")
assert "DENY relative write outside owns:" decision_is deny "$out"

# ── 6. Default-allow when no active context ──
echo ""
echo "No active context"
clear_marker
out=$(run_hook Edit "$FAKE_ROOT/anything/at/all.ts")
assert "ALLOW (default) when no marker + no env" decision_is allow "$out"

# ── 7. Non-write tool is never gated ──
echo ""
echo "Tool gating"
write_marker demo t1 "src/auth/login.ts" ""
out=$(run_hook Bash "$FAKE_ROOT/src/payments/refund.ts")
assert "ALLOW non-write tool (Bash) even with active context" decision_is allow "$out"

# ── 8. plan.md fallback parse (marker has feature/task but NO owns/freeze) ──
echo ""
echo "plan.md flat-format fallback"
# Marker with only feature:/task: lines -> hook must read owns from plan.md.
printf 'feature: demo\ntask: t1\n' > "$FAKE_ROOT/.loom-active-feature"
out=$(run_hook Edit "$FAKE_ROOT/src/auth/login.ts")
assert "ALLOW inside owns: via plan.md fallback (t1 -> src/auth/login.ts)" decision_is allow "$out"
out=$(run_hook Edit "$FAKE_ROOT/src/auth/session.ts")
assert "DENY outside t1 owns: via plan.md fallback (session.ts is t2's)" decision_is deny "$out"
out=$(run_hook Edit "$FAKE_ROOT/src/payments/charge.ts")
assert "DENY freeze: via plan.md fallback (t1 freeze charge.ts)" decision_is deny "$out"

# ── 9. Env var overrides marker feature/task; scope from plan.md ──
echo ""
echo "Env-var context (LOOM_ACTIVE_*)"
clear_marker
out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$FAKE_ROOT/src/auth/session.ts" \
  | env LOOM_ACTIVE_FEATURE=demo LOOM_ACTIVE_TASK=t2 bash "$HOOK" 2>/dev/null)
assert "ALLOW inside owns: via env-var + plan.md (t2 -> session.ts)" decision_is allow "$out"
out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$FAKE_ROOT/src/auth/login.ts" \
  | env LOOM_ACTIVE_FEATURE=demo LOOM_ACTIVE_TASK=t2 bash "$HOOK" 2>/dev/null)
assert "DENY outside owns: via env-var + plan.md (login.ts is t1's)" decision_is deny "$out"

# ── 10. Output schema is the current PreToolUse permissionDecision shape ──
echo ""
echo "Output schema"
write_marker demo t1 "src/auth/login.ts" "src/payments/charge.ts"
out=$(run_hook Edit "$FAKE_ROOT/src/auth/login.ts")
assert "allow output carries hookSpecificOutput.permissionDecision" \
  bash -c 'case "$1" in *"\"hookSpecificOutput\""*"\"permissionDecision\":\"allow\""*) exit 0;; *) exit 1;; esac' _ "$out"
out=$(run_hook Edit "$FAKE_ROOT/src/payments/charge.ts")
assert "deny output carries permissionDecisionReason" \
  bash -c 'case "$1" in *"\"permissionDecisionReason\""*) exit 0;; *) exit 1;; esac' _ "$out"
assert "deny output does NOT use legacy decision:block schema" \
  bash -c 'case "$1" in *"\"decision\":\"block\""*) exit 1;; *) exit 0;; esac' _ "$out"

echo ""
echo "==========================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "==========================================="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
