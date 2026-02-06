#!/usr/bin/env bash
# Master Test Runner — SDD Agentic Framework
# Runs all contract, integration, and validation tests
set -uo pipefail

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SUITES=0
FAILED_SUITES=""

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
  results_line=$(echo "$output" | grep -E "Results:|pass.*fail" | tail -1)
  if echo "$results_line" | grep -qE "[0-9]+/[0-9]+"; then
    passed=$(echo "$results_line" | grep -oE "[0-9]+" | head -1)
    total=$(echo "$results_line" | grep -oE "[0-9]+" | head -2 | tail -1)
    failed=$(echo "$results_line" | grep -oE "[0-9]+" | tail -1)
    TOTAL_PASS=$((TOTAL_PASS + passed))
    TOTAL_FAIL=$((TOTAL_FAIL + failed))
  elif echo "$output" | grep -q "^ℹ pass"; then
    # Node.js test runner format
    passed=$(echo "$output" | grep "^ℹ pass" | grep -oE "[0-9]+")
    failed=$(echo "$output" | grep "^ℹ fail" | grep -oE "[0-9]+")
    TOTAL_PASS=$((TOTAL_PASS + ${passed:-0}))
    TOTAL_FAIL=$((TOTAL_FAIL + ${failed:-0}))
  fi
  
  if [ $exit_code -ne 0 ]; then
    FAILED_SUITES="${FAILED_SUITES}  ❌ ${name}\n"
  fi
}

echo "╔═══════════════════════════════════════════════╗"
echo "║   SDD Framework — Full Test Suite             ║"
echo "║   $(date '+%Y-%m-%d %H:%M:%S')                         ║"
echo "╚═══════════════════════════════════════════════╝"

# Contract Tests
run_suite "Plugin Lifecycle" "bash tests/contract/plugins/test_plugin_lifecycle.sh"
run_suite "Swarm Lifecycle" "bash tests/contract/plugins/test_swarm_lifecycle.sh"
run_suite "RL Metrics" "bash tests/contract/plugins/test_rl_metrics.sh"
run_suite "Constitution v3.0.0" "bash tests/contract/test_constitution.sh"
run_suite "Deprecation Compliance" "bash tests/contract/test_deprecation.sh"
run_suite "Plugin Command Bridge" "bash tests/contract/test_plugin_command_bridge.sh"

# MCP Tests (unit)
run_suite "Marketplace MCP (unit)" "node --test mcp-servers/sdd-marketplace/src/__tests__/marketplace.test.js"

# MCP Integration (E2E)
run_suite "Marketplace MCP (E2E)" "NODE_PATH=mcp-servers/sdd-marketplace/node_modules node tests/integration/test_marketplace_mcp.js"

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
echo "║                                               ║"

if [ $TOTAL_FAIL -eq 0 ]; then
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

[ $TOTAL_FAIL -eq 0 ] && exit 0 || exit 1
