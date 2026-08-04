#!/usr/bin/env bash
# Master Test Runner — LogicLoom Framework
# Runs all contract, integration, and validation tests
set -uo pipefail

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SUITES=0
FAILED_SUITES=""
# Suites that exited non-zero WITHOUT emitting a parseable "Results: x/y" line —
# i.e. they crashed before reporting (missing interpreter feature, syntax error,
# absent file). Their assertions are counted nowhere, so they must gate the exit
# code independently or a wholly broken suite reads as green.
CRASHED_SUITES=0

run_suite() {
  local name="$1"
  local cmd="$2"
  TOTAL_SUITES=$((TOTAL_SUITES + 1))
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Suite: ${name}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  output=$(eval "$cmd" 2>&1)
  exit_code=$?
  echo "$output"
  
  # Parse results from output
  parsed=false
  results_line=$(echo "$output" | grep -E "Results:|pass.*fail" | tail -1)
  if echo "$results_line" | grep -qE "[0-9]+/[0-9]+"; then
    parsed=true
    passed=$(echo "$results_line" | grep -oE "[0-9]+" | head -1)
    total=$(echo "$results_line" | grep -oE "[0-9]+" | head -2 | tail -1)
    failed=$(echo "$results_line" | grep -oE "[0-9]+" | tail -1)
    TOTAL_PASS=$((TOTAL_PASS + passed))
    TOTAL_FAIL=$((TOTAL_FAIL + failed))
  elif echo "$output" | grep -q "^ℹ pass"; then
    # Node.js test runner format
    parsed=true
    passed=$(echo "$output" | grep "^ℹ pass" | grep -oE "[0-9]+")
    failed=$(echo "$output" | grep "^ℹ fail" | grep -oE "[0-9]+")
    TOTAL_PASS=$((TOTAL_PASS + ${passed:-0}))
    TOTAL_FAIL=$((TOTAL_FAIL + ${failed:-0}))
  fi

  if [ $exit_code -ne 0 ]; then
    FAILED_SUITES="${FAILED_SUITES}  ❌ ${name}\n"
    # Crashed before reporting: contributes 0 to TOTAL_FAIL, so track separately.
    if [ "$parsed" = false ]; then
      CRASHED_SUITES=$((CRASHED_SUITES + 1))
      FAILED_SUITES="${FAILED_SUITES}     ↳ crashed before reporting (exit ${exit_code})\n"
    fi
  fi
}

echo "╔═══════════════════════════════════════════════╗"
echo "║   LogicLoom Framework — Full Test Suite       ║"
echo "║   $(date '+%Y-%m-%d %H:%M:%S')                         ║"
echo "╚═══════════════════════════════════════════════╝"

# Contract Tests
run_suite "Plugin Lifecycle" "bash tests/contract/plugins/test_plugin_lifecycle.sh"
run_suite "Swarm Lifecycle" "bash tests/contract/plugins/test_swarm_lifecycle.sh"
run_suite "Constitution v3.2.0" "bash tests/contract/test_constitution.sh"
run_suite "Governance Hooks" "bash tests/contract/test_governance_hooks.sh"
run_suite "Deprecation Compliance" "bash tests/contract/test_deprecation.sh"
run_suite "Plugin Command Bridge" "bash tests/contract/test_plugin_command_bridge.sh"
run_suite "Orchestration Hook" "bash tests/contract/test_orchestration_hook.sh"
run_suite "Memory Search" "bash tests/contract/test_memory_search.sh"
run_suite "Update Framework" "bash tests/contract/test_update_framework.sh"
run_suite "Spec 006 Integration" "bash tests/contract/test_spec006_integration.sh"

# Validation Tests (Framework v2.0 enhancements)
run_suite "Git Safety" "bash .logic-loom/tests/test-git-safety.sh"
run_suite "Policy Validation" "bash .logic-loom/tests/test-policy-validation.sh"
run_suite "Structured Logging" "bash .logic-loom/tests/test_logging.sh"

echo ""
echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║   FINAL RESULTS                               ║"
echo "╠═══════════════════════════════════════════════╣"
echo "║                                               ║"
printf "║   Suites: %-3s                                 ║\n" "$TOTAL_SUITES"
printf "║   Passed: %-3s                                 ║\n" "$TOTAL_PASS"
printf "║   Failed: %-3s                                 ║\n" "$TOTAL_FAIL"
printf "║   Total:  %-3s                                 ║\n" "$((TOTAL_PASS + TOTAL_FAIL))"
[ $CRASHED_SUITES -ne 0 ] && \
  printf "║   Crashed suites: %-3s (assertions uncounted)  ║\n" "$CRASHED_SUITES"
echo "║                                               ║"

if [ $TOTAL_FAIL -eq 0 ] && [ $CRASHED_SUITES -eq 0 ]; then
  echo "║   ✅ ALL TESTS PASSING                        ║"
else
  echo "║   ❌ FAILURES DETECTED                        ║"
  echo "║                                               ║"
  echo -e "$FAILED_SUITES" | while read -r line; do
    if [ -n "$line" ]; then
      printf "║   %-44s║\n" "$line"
    fi
  done
fi
echo "║                                               ║"
echo "╚═══════════════════════════════════════════════╝"

[ $TOTAL_FAIL -eq 0 ] && [ $CRASHED_SUITES -eq 0 ] && exit 0 || exit 1
