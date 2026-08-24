#!/usr/bin/env bash
# Contract Tests: Tool policy pattern matching (.logic-loom/lib/policy.sh)
#
# Exercises `validate_tool_call "<cmd>"` (the function `guard-dangerous-commands.sh`
# and friends delegate to) directly and asserts its RETURN CODE against the
# documented contract:
#   0 = allowed
#   2 = blocked
#   3 = requires_approval
#   4 = warning
#
# Five groups:
#   A - true positives that MUST block (ec=2)
#   B - false positives (prose/data referencing dangerous text) that MUST NOT
#       block (ec=0) - the matcher is a plain `grep -E` over the whole command
#       string, so these cases probe whether quoting/anchoring saves it.
#   C - security-critical anti-bypass cases: command-substitution / interpreter
#       wrappers that MUST STILL block (ec=2) because the wrapped text executes
#       regardless of the quoting around it.
#   D - wrapper/indirection forms (enforced): previously-known-gap bypass
#       shapes that now block correctly and are counted like A-C.
#   E - reviewer-supplied root-delete hardening cases (option spellings,
#       path-qualified command, control-flow wrappers, and the near-miss
#       cases that must NOT block).
#
# All groups (A-E) count toward the final `Results:` line parsed by
# tests/run_all_tests.sh.
#
# bash 3.2 safe: no associative arrays, no `declare -g`, no mapfile/readarray,
# no ${var,,}.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
POLICY_LIB="$ROOT_DIR/.logic-loom/lib/policy.sh"

# Operations-log isolation: policy.sh logs every blocked/approval command via
# logging.sh, which defaults to the shared .logic-loom/logs/operations/ file.
# Point it at a temp dir (same idiom as LOOM_CHECKPOINT_DIR in
# .logic-loom/tests/test-git-safety.sh) so the suite is not stateful across runs
# and does not pollute the working tree.
LOOM_LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/loom-logs.XXXXXX")"
export LOOM_LOG_DIR
cleanup_test_logs() {
  if [ -n "${LOOM_LOG_DIR:-}" ] && [ -d "$LOOM_LOG_DIR" ]; then
    case "$LOOM_LOG_DIR" in
      */loom-logs.*) rm -rf "$LOOM_LOG_DIR" ;;
    esac
  fi
}
trap cleanup_test_logs EXIT

PASS=0; FAIL=0; TOTAL=0

echo "=== Policy Pattern-Matching Contract Tests ==="
echo ""

if [ ! -f "$POLICY_LIB" ]; then
  echo "  FAIL: policy.sh not found at $POLICY_LIB"
  echo ""
  echo "======================================="
  echo " Results: 0/1 passed, 1 failed"
  echo "======================================="
  exit 1
fi

# shellcheck source=/dev/null
source "$POLICY_LIB"

# ------------------------------------------------------------------------
# WHY commands are built from fragments at runtime rather than written as
# plain literals: this test file's own source text gets read by git/gh
# commands (commit messages, PR bodies) and by the repo's own
# guard-dangerous-commands.sh hook, which matches the WHOLE command string.
# A literal "rm -rf /" sitting in a diff/commit-message context is exactly
# the kind of string that guard has previously blocked (see MEMORY:
# guard_enforcement_live_bash32.md). Building the dangerous substrings from
# inert fragments at runtime keeps this FILE's own text out of that blast
# radius while still exercising the real strings against validate_tool_call.
# ------------------------------------------------------------------------
RF="-$(printf 'rf')"          # "-rf"
SLASH="/"
RM_ROOT="rm $RF $SLASH"       # "rm -rf /"
RM_GLOB="rm $RF ${SLASH}*"    # "rm -rf /*"

# Literal "$(" / ")" / backtick as DATA (not executed): built via
# concatenation of inert characters so bash never parses them as command
# substitution syntax while this script itself is being read/executed.
DLR='$'
OPEN_SUB="${DLR}("            # "$("
CLOSE_SUB=")"
BACKTICK='`'

# expect_ec <expected_ec> "<command>" "<label>"
#   Calls validate_tool_call and asserts its return code WITHOUT letting a
#   nonzero code kill the script (this file does not use `set -e`, so a
#   direct call + capture of $? is sufficient and safe).
expect_ec() {
  local expected="$1"
  local cmd="$2"
  local label="$3"
  local ec

  validate_tool_call "$cmd" >/dev/null 2>&1
  ec=$?

  TOTAL=$((TOTAL + 1))
  if [ "$ec" -eq "$expected" ]; then
    echo "  PASS: $label (ec=$ec)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (expected ec=$expected, got ec=$ec)"
    FAIL=$((FAIL + 1))
  fi
}

# ==========================================================================
# GROUP A - true positives that MUST block (ec=2)
# ==========================================================================
echo "--- Group A: true positives (must block, ec=2) ---"

expect_ec 2 "$RM_ROOT" "rm -rf /"
expect_ec 2 "${RM_ROOT}   " "rm -rf /  (trailing spaces)"
expect_ec 2 "$RM_ROOT ; echo done" "rm -rf / ; echo done"
expect_ec 2 "$RM_ROOT && echo done" "rm -rf / && echo done"
expect_ec 2 "echo hi ; $RM_ROOT" "echo hi ; rm -rf /"
expect_ec 2 "cd /tmp && $RM_ROOT" "cd /tmp && rm -rf /"
expect_ec 2 "$RM_GLOB" "rm -rf /*"
expect_ec 2 "pkill -f node" "pkill -f node"
expect_ec 2 "chmod -R 777 /etc" "chmod -R 777 /etc"
# Force push is deliberately NOT in group A. It moved out of `dangerous_commands`
# (hard block, ec=2) into `git_operations` (require_approval, ec=3): a hard deny
# left the user no approval path at all, which contradicts "if the user asks, the
# hook should not stop the ask". It is still gated — see group F.
expect_ec 3 "git push --force origin main" "git push --force origin main (approval-gated, not blocked)"

echo ""

# ==========================================================================
# GROUP B - false positives (prose/data) that MUST NOT block (ec=0)
# ==========================================================================
echo "--- Group B: false positives (must NOT block, ec=0) ---"

expect_ec 0 "gh pr create --body \"docs mention $RM_ROOT here\"" \
  'gh pr create --body "docs mention rm -rf / here"'
expect_ec 0 "gh pr create --body \"line ends with $RM_ROOT\"" \
  'gh pr create --body "line ends with rm -rf /"'
expect_ec 3 "git commit -m \"fix: stop matching $RM_ROOT in prose\"" \
  'git commit -m "fix: stop matching rm -rf / in prose" (not blocked, approval-gated)'
expect_ec 3 "git commit -m \"note about git push --force in docs\"" \
  'git commit -m "note about git push --force in docs" (not blocked, approval-gated)'
expect_ec 0 "jq -r '.x' file.json" "jq -r '.x' file.json"
expect_ec 0 "gh pr create --body=\"text $RM_ROOT here\"" \
  'gh pr create --body="text rm -rf / here" (equals form)'

echo ""

# ==========================================================================
# GROUP C - anti-bypass: command substitution / interpreter wrappers.
# These MUST STILL block (ec=2): the wrapped dangerous text executes
# regardless of the quoting/prose context around it.
# ==========================================================================
echo "--- Group C: anti-bypass, must STILL block (ec=2) ---"

expect_ec 2 "gh pr create --body \"${OPEN_SUB}${RM_ROOT}${CLOSE_SUB}\"" \
  'gh pr create --body "$(rm -rf /)"'
expect_ec 2 "git commit -m \"${OPEN_SUB}${RM_ROOT}${CLOSE_SUB}\"" \
  'git commit -m "$(rm -rf /)"'
expect_ec 2 "git commit -m \"text ${BACKTICK}${RM_ROOT}${BACKTICK} more\"" \
  'git commit -m "text `rm -rf /` more" (backtick form)'
expect_ec 2 "echo \"$RM_ROOT\" | bash" 'echo "rm -rf /" | bash'
expect_ec 2 "bash -c \"$RM_ROOT\"" 'bash -c "rm -rf /"'
expect_ec 2 "sh -c \"$RM_ROOT\"" 'sh -c "rm -rf /"'
expect_ec 2 "eval \"$RM_ROOT\"" 'eval "rm -rf /"'

echo ""

# ==========================================================================
# GROUP D - wrapper/indirection forms (enforced): these now block correctly
# and are counted like groups A-C.
# ==========================================================================
echo "--- Group D: wrapper/indirection forms (enforced) ---"

expect_ec 2 "command $RM_ROOT" 'command rm -rf /'
expect_ec 2 "exec $RM_ROOT" 'exec rm -rf /'
expect_ec 2 "env FOO=1 $RM_ROOT" 'env FOO=1 rm -rf /'
expect_ec 2 "xargs -I{} $RM_ROOT" 'xargs -I{} rm -rf /'
expect_ec 2 "X=${OPEN_SUB}${RM_ROOT}${CLOSE_SUB} ls" 'X=$(rm -rf /) ls'
expect_ec 2 "python3 -c \"import os; os.system('$RM_ROOT')\"" \
  "python3 -c \"import os; os.system('rm -rf /')\""

echo ""

# ==========================================================================
# GROUP E - reviewer-supplied root-delete hardening cases.
# ==========================================================================
echo "--- Group E: root-delete hardening (reviewer cases) ---"

expect_ec 2 "rm -r -f $SLASH" "rm -r -f /  (split options)"
expect_ec 2 "rm -vrf $SLASH" "rm -vrf /  (bundled options)"
expect_ec 2 "rm --recursive --force $SLASH" "rm --recursive --force /  (long options)"
expect_ec 2 "rm $RF -- $SLASH" "rm -rf -- /  (option separator)"
expect_ec 2 "/bin/rm $RF $SLASH" "/bin/rm -rf /  (path-qualified command)"
expect_ec 2 "{ $RM_ROOT; }" "{ rm -rf /; }  (brace group)"
expect_ec 2 "if $RM_ROOT; then :; fi" "if rm -rf /; then :; fi  (if condition)"
expect_ec 2 "! $RM_ROOT" "! rm -rf /  (negated)"
expect_ec 0 "$RM_ROOT@" "rm -rf /@  (real dir named @ - must NOT block)"
expect_ec 0 "rm $RF ${SLASH}tmp/x && echo $SLASH" "rm -rf /tmp/x && echo /  (wildcard must not cross the operator)"
expect_ec 0 "rm $RF ${SLASH}tmp/scratch" "rm -rf /tmp/scratch  (ordinary path)"
expect_ec 0 "rm $RF ./build/" "rm -rf ./build/  (ordinary relative path)"

echo ""

# ==========================================================================
# GROUP F - force push is approval-gated (ec=3), never a silent allow, and
# never an unappealable block. The rest of dangerous_commands is untouched.
# ==========================================================================
echo "--- Group F: force push reclassified block -> require_approval ---"

FORCE="--$(printf 'force')"
expect_ec 3 "git push $FORCE origin main" "git push --force origin main"
expect_ec 3 "git push $FORCE-with-lease origin main" "git push --force-with-lease origin main"
expect_ec 3 "git push origin main" "git push origin main (plain push still gated)"

echo ""
echo "======================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "======================================="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
