#!/usr/bin/env bash
# Contract Tests: test-suite registration coherence
#
# Closes a recurring drift class: a test suite is ADDED to the tree but nothing
# REGISTERS it, so it runs nowhere and its assertions silently protect nothing.
# (Four suites — governance verdicts, freeze scope, git adapter, disposition
# tandem — sat unregistered in both the local runner and CI.)
#
#   1. Every tests/contract/**/*.sh is referenced in tests/run_all_tests.sh.
#   2. Every .logic-loom/tests/*.sh is referenced in tests/run_all_tests.sh.
#   3. Every suite referenced by the runner is also a CI step in
#      .github/workflows/plugin-tests.yml, OR is on the documented exclusion
#      list below (each exclusion needs a stated reason).
#   4. Every suite referenced by plugin-tests.yml exists on disk (catches a
#      renamed/deleted file leaving a dangling CI step).
#
# This suite registers itself normally in BOTH places, so it self-checks.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
# Overridable for meta-testing: LOOM_RUNNER_FILE / LOOM_WORKFLOW_FILE.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

# Resolve the repo root so the test runs from anywhere: prefer git, else walk up
# from this script (tests/contract/ → repo root).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

RUNNER="${LOOM_RUNNER_FILE:-$ROOT/tests/run_all_tests.sh}"
WORKFLOW="${LOOM_WORKFLOW_FILE:-$ROOT/.github/workflows/plugin-tests.yml}"

# ── Documented CI exclusions ─────────────────────────────────────────────────
# Suites that run in the local runner but are deliberately NOT gated in CI.
# Every entry needs a reason. Add nothing here casually — an undocumented
# exclusion is the same drift this suite exists to catch.
#
#   test_update_framework.sh — performs live network I/O via
#     extract-proposals.sh --dry-run with no timeout, and its key assertion is
#     suffixed `|| true`; gating CI on it adds flake with no signal.
CI_EXCLUSIONS="test_update_framework.sh"

is_excluded() {
  local base="$1" e
  for e in $CI_EXCLUSIONS; do
    [ "$e" = "$base" ] && return 0
  done
  return 1
}

# Strip whole-line comments so a suite mentioned only inside a comment does not
# count as "registered".
strip_comments() { sed 's/[[:space:]]*#.*$//' "$1"; }

RUNNER_BODY=""
[ -f "$RUNNER" ] && RUNNER_BODY="$(strip_comments "$RUNNER")"
WORKFLOW_BODY=""
[ -f "$WORKFLOW" ] && WORKFLOW_BODY="$(strip_comments "$WORKFLOW")"

# Suite paths the CI workflow actually invokes: single-line `run: bash <x>.sh`
# steps only (multi-line run blocks are scripts, not suites).
WORKFLOW_PATHS="$(printf '%s\n' "$WORKFLOW_BODY" \
  | grep -E '^[[:space:]]*run:[[:space:]]*bash[[:space:]]+[^[:space:]]+\.sh[[:space:]]*$' \
  | sed -E 's/^[[:space:]]*run:[[:space:]]*bash[[:space:]]+//; s/[[:space:]]*$//')"

# Suite paths the runner invokes, from its run_suite lines.
RUNNER_PATHS="$(printf '%s\n' "$RUNNER_BODY" \
  | grep -E '^[[:space:]]*run_suite[[:space:]]' \
  | grep -oE '[A-Za-z0-9_./-]+\.sh' \
  | sort -u)"

# Basename appears anywhere in a body (tolerates `tests/contract/x.sh` and bare
# `x.sh` reference styles).
referenced_in() { grep -qF -- "$1" <<< "$2"; }

echo "═══ Test Suite Registration Coherence ═══"
echo ""

echo "0. Registration surfaces exist"
assert "runner present: ${RUNNER#$ROOT/}"   "[ -f \"\$RUNNER\" ]"
assert "workflow present: ${WORKFLOW#$ROOT/}" "[ -f \"\$WORKFLOW\" ]"

# ── 1. Every contract test is in the runner ──────────────────────────────────
echo ""
echo "1. Every tests/contract/**/*.sh is registered in the runner"
MISSING=""
COUNT=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  COUNT=$((COUNT + 1))
  base="$(basename "$f")"
  referenced_in "$base" "$RUNNER_BODY" || MISSING="${MISSING}${f}"$'\n'
done < <(find tests/contract -type f -name '*.sh' 2>/dev/null | sort)
[ -n "$MISSING" ] && { echo "     UNREGISTERED (add a run_suite line to ${RUNNER#$ROOT/}):";
  printf '%s' "$MISSING" | sed 's/^/       - /'; }
echo "     (scanned $COUNT contract suites)"
assert "no unregistered tests/contract suite" "[ -z \"\$MISSING\" ]"

# ── 2. Every .logic-loom test is in the runner ───────────────────────────────
echo ""
echo "2. Every .logic-loom/tests/*.sh is registered in the runner"
MISSING_LL=""
COUNT_LL=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  COUNT_LL=$((COUNT_LL + 1))
  base="$(basename "$f")"
  referenced_in "$base" "$RUNNER_BODY" || MISSING_LL="${MISSING_LL}${f}"$'\n'
done < <(find .logic-loom/tests -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort)
[ -n "$MISSING_LL" ] && { echo "     UNREGISTERED (add a run_suite line to ${RUNNER#$ROOT/}):";
  printf '%s' "$MISSING_LL" | sed 's/^/       - /'; }
echo "     (scanned $COUNT_LL .logic-loom suites)"
assert "no unregistered .logic-loom/tests suite" "[ -z \"\$MISSING_LL\" ]"

# ── 3. Runner suites are gated in CI (or explicitly excluded) ────────────────
echo ""
echo "3. Every runner suite is a CI step (or a documented exclusion)"
MISSING_CI=""
EXCLUDED_SEEN=""
while IFS= read -r p; do
  [ -n "$p" ] || continue
  base="$(basename "$p")"
  if is_excluded "$base"; then
    EXCLUDED_SEEN="${EXCLUDED_SEEN}${base}"$'\n'
    continue
  fi
  referenced_in "$base" "$WORKFLOW_BODY" || MISSING_CI="${MISSING_CI}${p}"$'\n'
done < <(printf '%s\n' "$RUNNER_PATHS")
if [ -n "$EXCLUDED_SEEN" ]; then
  echo "     documented CI exclusions (see CI_EXCLUSIONS in this file):"
  printf '%s' "$EXCLUDED_SEEN" | sed 's/^/       - /'
fi
[ -n "$MISSING_CI" ] && { echo "     NOT GATED IN CI (add a step to ${WORKFLOW#$ROOT/}):";
  printf '%s' "$MISSING_CI" | sed 's/^/       - /'; }
assert "no runner suite is missing from CI without a documented reason" \
  "[ -z \"\$MISSING_CI\" ]"

# ── 4. Every CI-referenced suite exists on disk ──────────────────────────────
echo ""
echo "4. Every suite referenced by the CI workflow exists on disk"
DANGLING=""
COUNT_CI=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  COUNT_CI=$((COUNT_CI + 1))
  [ -f "$ROOT/$p" ] || DANGLING="${DANGLING}${p}"$'\n'
done < <(printf '%s\n' "$WORKFLOW_PATHS")
[ -n "$DANGLING" ] && { echo "     DANGLING CI STEPS (file renamed or deleted):";
  printf '%s' "$DANGLING" | sed 's/^/       - /'; }
echo "     (scanned $COUNT_CI CI suite steps)"
assert "no dangling suite reference in the CI workflow" "[ -z \"\$DANGLING\" ]"

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
