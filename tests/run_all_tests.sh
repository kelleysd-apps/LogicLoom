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
# Any suite that exits nonzero, regardless of whether its output parsed as a
# results line. Guards against a suite that PRINTS a passing "Results: N/N"
# line (e.g. cleanup happens before the trap-triggering failure) but then
# exits nonzero itself — that case parses fine, so CRASHED_SUITES alone
# would miss it and let the run report green.
NONZERO_EXITS=0
# Suites that RAN, exited zero, and emitted a summary this runner could not
# parse — so their assertions were counted nowhere while the run read green.
# This is the "green and uncounted" defect: worse than red, because the number
# in the summary understates coverage and nobody can tell. A runner that
# quietly counts less than it ran must fail, so this gates the exit code.
UNPARSED_SUITES=0
UNPARSED_LIST=""

# parse_results <output>
# Sets globals PARSED_PASS / PARSED_FAIL and returns 0 on success, 1 if the
# output carries no summary this runner recognises.
#
# House formats, ALL accepted (each is in use in this repo today):
#   A  Results: 64/64 passed, 0 failed[, 0 skipped]     slash form
#   B  Results: 39 passed, 0 failed, 39 total           named form
#   C  Total: 91 | Passed: 91 | Failed: 0 | Skipped: 0  labelled form (one line)
#   C  Total: 17 \n Passed: 17 \n Failed: 0             labelled form (stacked)
#   D  ℹ pass N / ℹ fail M                              node:test runner
# Anything else is NOT silently skipped — it fails the run (see UNPARSED_SUITES).
parse_results() {
  local out="$1" line norm p f
  PARSED_PASS=0
  PARSED_FAIL=0

  # --- A / B: a "Results:"-style line -----------------------------------------
  line=$(printf '%s\n' "$out" | grep -E "Results:|pass.*fail" | tail -1)
  if [ -n "$line" ]; then
    # Collapse "N/M passed" to "N passed" so one extractor covers A and B.
    norm=" $(printf '%s\n' "$line" | sed -E 's#([0-9]+)/[0-9]+([[:space:]]*[Pp]assed)#\1\2#g')"
    p=$(printf '%s\n' "$norm" | sed -nE 's#.*[^0-9]([0-9]+)[[:space:]]*[Pp]assed.*#\1#p')
    f=$(printf '%s\n' "$norm" | sed -nE 's#.*[^0-9]([0-9]+)[[:space:]]*[Ff]ailed.*#\1#p')
    if [ -n "$p" ] && [ -n "$f" ]; then
      PARSED_PASS=$p
      PARSED_FAIL=$f
      return 0
    fi
  fi

  # --- D: node:test runner ----------------------------------------------------
  if printf '%s\n' "$out" | grep -q "^ℹ pass"; then
    p=$(printf '%s\n' "$out" | grep "^ℹ pass" | grep -oE "[0-9]+" | tail -1)
    f=$(printf '%s\n' "$out" | grep "^ℹ fail" | grep -oE "[0-9]+" | tail -1)
    PARSED_PASS=${p:-0}
    PARSED_FAIL=${f:-0}
    return 0
  fi

  # --- C: labelled "Passed:" / "Failed:" (same line or stacked) ---------------
  p=$(printf '%s\n' "$out" | sed -nE 's#.*[Pp]assed:[[:space:]]*([0-9]+).*#\1#p' | tail -1)
  f=$(printf '%s\n' "$out" | sed -nE 's#.*[Ff]ailed:[[:space:]]*([0-9]+).*#\1#p' | tail -1)
  if [ -n "$p" ] && [ -n "$f" ]; then
    PARSED_PASS=$p
    PARSED_FAIL=$f
    return 0
  fi

  return 1
}

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
  if parse_results "$output"; then
    parsed=true
    TOTAL_PASS=$((TOTAL_PASS + PARSED_PASS))
    TOTAL_FAIL=$((TOTAL_FAIL + PARSED_FAIL))
  elif [ $exit_code -eq 0 ]; then
    # Ran, passed, and reported in a shape this runner does not know. Its
    # assertions are invisible in the headline total. Fail loudly rather than
    # under-report — see UNPARSED_SUITES.
    UNPARSED_SUITES=$((UNPARSED_SUITES + 1))
    UNPARSED_LIST="${UNPARSED_LIST}  ❓ ${name}: unparseable results line\n"
    echo "  ⚠️  RUNNER: could not parse a results summary from this suite."
    echo "     Its assertions would be counted nowhere. Emit one of:"
    echo "       Results: N/N passed, M failed   |   Results: N passed, M failed, T total"
    echo "       Total: T | Passed: N | Failed: M"
  fi

  if [ $exit_code -ne 0 ]; then
    FAILED_SUITES="${FAILED_SUITES}  ❌ ${name}\n"
    NONZERO_EXITS=$((NONZERO_EXITS + 1))
    # Crashed before reporting: contributes 0 to TOTAL_FAIL, so track separately.
    if [ "$parsed" = false ]; then
      CRASHED_SUITES=$((CRASHED_SUITES + 1))
      FAILED_SUITES="${FAILED_SUITES}     ↳ crashed before reporting (exit ${exit_code})\n"
    else
      FAILED_SUITES="${FAILED_SUITES}     ↳ suite exited nonzero (exit ${exit_code}) despite parsed results\n"
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
run_suite "Constitution v3.3.0" "bash tests/contract/test_constitution.sh"
run_suite "Governance Hooks" "bash tests/contract/test_governance_hooks.sh"
run_suite "Policy Matching" "bash tests/contract/test_policy_matching.sh"
run_suite "Deprecation Compliance" "bash tests/contract/test_deprecation.sh"
run_suite "Plugin Command Bridge" "bash tests/contract/test_plugin_command_bridge.sh"
run_suite "Orchestration Hook" "bash tests/contract/test_orchestration_hook.sh"
run_suite "Memory Search" "bash tests/contract/test_memory_search.sh"
run_suite "Update Framework" "bash tests/contract/test_update_framework.sh"
run_suite "Spec 006 Integration" "bash tests/contract/test_spec006_integration.sh"
run_suite "Product Workspace Boundary" "bash tests/contract/test_product_workspace_boundary.sh"
run_suite "Model Agnosticism" "bash tests/contract/test_model_agnostic.sh"
run_suite "Graph Bridge" "bash tests/contract/test_graph_bridge.sh"
run_suite "Governance Verdicts" "bash tests/contract/test_governance_verdicts.sh"
run_suite "Gate Policy" "bash tests/contract/test_gate_policy.sh"
run_suite "Environment Scaffolding" "bash tests/contract/test_environment_scaffolding.sh"
run_suite "Dev Branch Base Guard" "bash tests/contract/test_dev_branch_base_guard.sh"
run_suite "Freeze Scope" "bash tests/contract/test_freeze_scope.sh"
run_suite "Git Adapter" "bash tests/contract/test_git_adapter.sh"
run_suite "Disposition Tandem" "bash tests/contract/test_disposition_tandem.sh"
run_suite "Suite Registration" "bash tests/contract/test_suite_registration.sh"
run_suite "Generated Artifacts Declared" "bash tests/contract/test_generated_artifacts_declared.sh"
run_suite "Scrub Rules Match" "bash tests/contract/test_scrub_rules_match.sh"
run_suite "gh Telemetry Notice" "bash tests/contract/test_gh_telemetry_notice.sh"
run_suite "Environment Declaration" "bash tests/contract/test_environment_declaration.sh"
run_suite "Plugin Manifest Schema" "bash tests/contract/test_plugin_manifest_schema.sh"
run_suite "Project Identity" "bash tests/contract/test_project_identity.sh"
run_suite "Backlog Index" "bash tests/contract/test_backlog_index.sh"
run_suite "Backlog Dashboard" "bash tests/contract/test_backlog_dashboard.sh"
run_suite "Promotion Lifecycle" "bash tests/contract/test_promotion_lifecycle.sh"
run_suite "Release Publication" "bash tests/contract/test_release_publication.sh"
run_suite "Release Sync-Ref Reachability" "bash tests/contract/test_release_sync_ref.sh"
run_suite "Shipped Gates vs Strip" "bash tests/contract/test_shipped_gates_vs_strip.sh"
run_suite "Sanitization Audit" "bash tests/contract/test_sanitization_audit.sh"
run_suite "bash 3.2 Floor" "bash tests/contract/test_bash32_floor.sh"
run_suite "Brain Record" "bash tests/contract/test_brain_record.sh"
run_suite "Init Project README" "bash tests/contract/test_init_project_readme.sh"
run_suite "Adopt Payload Manifest" "bash tests/contract/test_adopt_payload_manifest.sh"
run_suite "Adopt Planner" "bash tests/contract/test_adopt_planner.sh"
run_suite "Adopt Merges" "bash tests/contract/test_adopt_merges.sh"
run_suite "Adopt Applier" "bash tests/contract/test_adopt_applier.sh"
run_suite "Adopt Rules + CLAUDE.md Mode" "bash tests/contract/test_adopt_rules.sh"
run_suite "Adopt Entry Points + Post-Install" "bash tests/contract/test_adopt_entrypoints.sh"
run_suite "Adopt Agent-Drivable Install" "bash tests/contract/test_adopt_agent_mode.sh"

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
[ $NONZERO_EXITS -ne 0 ] && \
  printf "║   Nonzero exits:  %-3s                         ║\n" "$NONZERO_EXITS"
[ $UNPARSED_SUITES -ne 0 ] && \
  printf "║   Unparsed suites: %-3s (assertions uncounted) ║\n" "$UNPARSED_SUITES"
echo "║                                               ║"

if [ $TOTAL_FAIL -eq 0 ] && [ $CRASHED_SUITES -eq 0 ] && [ $NONZERO_EXITS -eq 0 ] && [ $UNPARSED_SUITES -eq 0 ]; then
  echo "║   ✅ ALL TESTS PASSING                        ║"
else
  echo "║   ❌ FAILURES DETECTED                        ║"
  echo "║                                               ║"
  echo -e "${FAILED_SUITES}${UNPARSED_LIST}" | while read -r line; do
    if [ -n "$line" ]; then
      printf "║   %-44s║\n" "$line"
    fi
  done
fi
echo "║                                               ║"
echo "╚═══════════════════════════════════════════════╝"

[ $TOTAL_FAIL -eq 0 ] && [ $CRASHED_SUITES -eq 0 ] && [ $NONZERO_EXITS -eq 0 ] && [ $UNPARSED_SUITES -eq 0 ] && exit 0 || exit 1
