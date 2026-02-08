#!/usr/bin/env bash
# Contract Tests: Scope Detection Engine
# TDD tests for scope-analysis.json contract and scope-detector.sh implementation
# Tests: classify tactic/strategy, ambiguous defaults, user overrides, confidence scoring,
#         cross-cutting concern detection, file count heuristic, performance
# These tests are written BEFORE implementation (TDD).
set -eo pipefail

PASS=0; FAIL=0; TOTAL=0

assert() {
  TOTAL=$((TOTAL + 1))
  local desc="$1"; local condition="$2"
  if ( set +eu; eval "$condition" ) 2>/dev/null; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# Helper: safely call a function and capture output (returns empty string on failure)
safe_call() {
  local result=""
  result="$( set +eu; "$@" 2>/dev/null )" || true
  echo "$result"
}

# ── Setup ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="${PLUGIN_DIR}/lib"
TEMPLATE_DIR="${PLUGIN_DIR}/templates"
TEST_TMPDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_TMPDIR"
}
trap cleanup EXIT

echo "=== Scope Detection Contract Tests ==="
echo ""

# ── Library Existence ──
echo "Library and template existence"
assert "scope-detector.sh exists" "[ -f '${LIB_DIR}/scope-detector.sh' ]"
assert "scope-analysis.json template exists" "[ -f '${TEMPLATE_DIR}/scope-analysis.json' ]"

# Source library (tolerant of partially-implemented libs)
LIBS_SOURCED=false
if [ -f "${LIB_DIR}/scope-detector.sh" ]; then
  ( set +eu; source "${LIB_DIR}/scope-detector.sh" ) 2>/dev/null || true
  set +eu
  source "${LIB_DIR}/scope-detector.sh" 2>/dev/null || true
  set -eo pipefail
  LIBS_SOURCED=true
fi

# ── Function Existence ──
echo ""
echo "Function existence"
assert "analyze_scope function exists" "type -t analyze_scope 2>/dev/null | grep -q function"
assert "classify_scope function exists" "type -t classify_scope 2>/dev/null | grep -q function"
assert "compute_confidence function exists" "type -t compute_confidence 2>/dev/null | grep -q function"
assert "detect_cross_cutting function exists" "type -t detect_cross_cutting 2>/dev/null | grep -q function"

# ══════════════════════════════════════════
# Tactic Classification Tests
# ══════════════════════════════════════════
echo ""
echo "--- Tactic Classification ---"

echo "Small, focused tasks should classify as tactic"
if $LIBS_SOURCED; then
  # Clear tactic: typo fix
  TACTIC_TYPO="$(safe_call analyze_scope "fix the typo in README")"
  assert "\"fix the typo in README\" classifies as tactic" \
    "python3 -c 'import json; d=json.loads(\"\"\"${TACTIC_TYPO}\"\"\"); assert d[\"detected_scope\"] == \"tactic\", f\"got {d[\"detected_scope\"]}\"'"

  # Clear tactic: rename variable
  TACTIC_RENAME="$(safe_call analyze_scope "rename the variable from x to count")"
  assert "\"rename the variable from x to count\" classifies as tactic" \
    "python3 -c 'import json; d=json.loads(\"\"\"${TACTIC_RENAME}\"\"\"); assert d[\"detected_scope\"] == \"tactic\", f\"got {d[\"detected_scope\"]}\"'"

  # Clear tactic: bump version
  TACTIC_BUMP="$(safe_call analyze_scope "bump the version number to 1.2.3")"
  assert "\"bump the version number to 1.2.3\" classifies as tactic" \
    "python3 -c 'import json; d=json.loads(\"\"\"${TACTIC_BUMP}\"\"\"); assert d[\"detected_scope\"] == \"tactic\", f\"got {d[\"detected_scope\"]}\"'"

  # Clear tactic: minor patch
  TACTIC_PATCH="$(safe_call analyze_scope "patch the off-by-one error in the loop")"
  assert "\"patch the off-by-one error in the loop\" classifies as tactic" \
    "python3 -c 'import json; d=json.loads(\"\"\"${TACTIC_PATCH}\"\"\"); assert d[\"detected_scope\"] == \"tactic\", f\"got {d[\"detected_scope\"]}\"'"

  # Tactic should have negative total_score
  assert "Tactic classification has total_score <= -0.5" \
    "python3 -c 'import json; d=json.loads(\"\"\"${TACTIC_TYPO}\"\"\"); assert d[\"keyword_scores\"][\"total_score\"] <= -0.5, f\"got {d[\"keyword_scores\"][\"total_score\"]}\"'"
else
  assert "\"fix the typo in README\" classifies as tactic" "false"
  assert "\"rename the variable from x to count\" classifies as tactic" "false"
  assert "\"bump the version number to 1.2.3\" classifies as tactic" "false"
  assert "\"patch the off-by-one error in the loop\" classifies as tactic" "false"
  assert "Tactic classification has total_score <= -0.5" "false"
fi

# ══════════════════════════════════════════
# Strategy Classification Tests
# ══════════════════════════════════════════
echo ""
echo "--- Strategy Classification ---"

echo "Large, cross-cutting tasks should classify as strategy"
if $LIBS_SOURCED; then
  # Clear strategy: OAuth2 with RBAC
  STRATEGY_OAUTH="$(safe_call analyze_scope "implement OAuth2 with RBAC across all API endpoints")"
  assert "\"implement OAuth2 with RBAC\" classifies as strategy" \
    "python3 -c 'import json; d=json.loads(\"\"\"${STRATEGY_OAUTH}\"\"\"); assert d[\"detected_scope\"] == \"strategy\", f\"got {d[\"detected_scope\"]}\"'"

  # Clear strategy: database migration
  STRATEGY_MIGRATE="$(safe_call analyze_scope "migrate the database schema from PostgreSQL to a new multi-tenant architecture")"
  assert "\"migrate the database schema\" classifies as strategy" \
    "python3 -c 'import json; d=json.loads(\"\"\"${STRATEGY_MIGRATE}\"\"\"); assert d[\"detected_scope\"] == \"strategy\", f\"got {d[\"detected_scope\"]}\"'"

  # Clear strategy: redesign UI
  STRATEGY_REDESIGN="$(safe_call analyze_scope "redesign the entire dashboard UI with new component architecture")"
  assert "\"redesign the entire dashboard UI\" classifies as strategy" \
    "python3 -c 'import json; d=json.loads(\"\"\"${STRATEGY_REDESIGN}\"\"\"); assert d[\"detected_scope\"] == \"strategy\", f\"got {d[\"detected_scope\"]}\"'"

  # Clear strategy: integrate third-party
  STRATEGY_INTEGRATE="$(safe_call analyze_scope "integrate Stripe payment processing with webhook handling and refund workflows")"
  assert "\"integrate Stripe payment processing\" classifies as strategy" \
    "python3 -c 'import json; d=json.loads(\"\"\"${STRATEGY_INTEGRATE}\"\"\"); assert d[\"detected_scope\"] == \"strategy\", f\"got {d[\"detected_scope\"]}\"'"

  # Strategy should have positive total_score
  assert "Strategy classification has total_score >= 0.5" \
    "python3 -c 'import json; d=json.loads(\"\"\"${STRATEGY_OAUTH}\"\"\"); assert d[\"keyword_scores\"][\"total_score\"] >= 0.5, f\"got {d[\"keyword_scores\"][\"total_score\"]}\"'"
else
  assert "\"implement OAuth2 with RBAC\" classifies as strategy" "false"
  assert "\"migrate the database schema\" classifies as strategy" "false"
  assert "\"redesign the entire dashboard UI\" classifies as strategy" "false"
  assert "\"integrate Stripe payment processing\" classifies as strategy" "false"
  assert "Strategy classification has total_score >= 0.5" "false"
fi

# ══════════════════════════════════════════
# Ambiguous Cases Default to Tactic
# ══════════════════════════════════════════
echo ""
echo "--- Ambiguous Cases ---"

echo "Ambiguous descriptions should default to tactic"
if $LIBS_SOURCED; then
  # Ambiguous: no strong signals either way
  AMBIG_SIMPLE="$(safe_call analyze_scope "change the color of the button")"
  assert "\"change the color of the button\" defaults to tactic (ambiguous)" \
    "python3 -c 'import json; d=json.loads(\"\"\"${AMBIG_SIMPLE}\"\"\"); assert d[\"detected_scope\"] == \"tactic\", f\"got {d[\"detected_scope\"]}\"'"

  # Ambiguous: mixed signals
  AMBIG_MIXED="$(safe_call analyze_scope "update the API response format")"
  assert "\"update the API response format\" defaults to tactic (ambiguous)" \
    "python3 -c 'import json; d=json.loads(\"\"\"${AMBIG_MIXED}\"\"\"); assert d[\"detected_scope\"] == \"tactic\", f\"got {d[\"detected_scope\"]}\"'"

  # Ambiguous score should be between -0.5 and 0.5
  assert "Ambiguous case has total_score between -0.5 and 0.5" \
    "python3 -c 'import json; d=json.loads(\"\"\"${AMBIG_SIMPLE}\"\"\"); s=d[\"keyword_scores\"][\"total_score\"]; assert -0.5 < s < 0.5, f\"got {s}\"'"
else
  assert "\"change the color of the button\" defaults to tactic (ambiguous)" "false"
  assert "\"update the API response format\" defaults to tactic (ambiguous)" "false"
  assert "Ambiguous case has total_score between -0.5 and 0.5" "false"
fi

# ══════════════════════════════════════════
# User Override Tests
# ══════════════════════════════════════════
echo ""
echo "--- User Override ---"

echo "User override should force scope regardless of detection"
if $LIBS_SOURCED; then
  # Override tactic task to strategy
  OVERRIDE_TO_STRATEGY="$(safe_call analyze_scope "fix the typo in README" --override strategy)"
  assert "User override forces tactic task to strategy" \
    "python3 -c 'import json; d=json.loads(\"\"\"${OVERRIDE_TO_STRATEGY}\"\"\"); assert d[\"final_scope\"] == \"strategy\", f\"got {d[\"final_scope\"]}\"'"
  assert "override_by_user is set to strategy" \
    "python3 -c 'import json; d=json.loads(\"\"\"${OVERRIDE_TO_STRATEGY}\"\"\"); assert d[\"override_by_user\"] == \"strategy\", f\"got {d[\"override_by_user\"]}\"'"
  assert "detected_scope still shows tactic despite override" \
    "python3 -c 'import json; d=json.loads(\"\"\"${OVERRIDE_TO_STRATEGY}\"\"\"); assert d[\"detected_scope\"] == \"tactic\", f\"got {d[\"detected_scope\"]}\"'"

  # Override strategy task to tactic
  OVERRIDE_TO_TACTIC="$(safe_call analyze_scope "implement OAuth2 with RBAC" --override tactic)"
  assert "User override forces strategy task to tactic" \
    "python3 -c 'import json; d=json.loads(\"\"\"${OVERRIDE_TO_TACTIC}\"\"\"); assert d[\"final_scope\"] == \"tactic\", f\"got {d[\"final_scope\"]}\"'"
  assert "override_by_user is set to tactic" \
    "python3 -c 'import json; d=json.loads(\"\"\"${OVERRIDE_TO_TACTIC}\"\"\"); assert d[\"override_by_user\"] == \"tactic\", f\"got {d[\"override_by_user\"]}\"'"
  assert "detected_scope still shows strategy despite override" \
    "python3 -c 'import json; d=json.loads(\"\"\"${OVERRIDE_TO_TACTIC}\"\"\"); assert d[\"detected_scope\"] == \"strategy\", f\"got {d[\"detected_scope\"]}\"'"

  # No override: override_by_user should be null
  NO_OVERRIDE="$(safe_call analyze_scope "fix the typo in README")"
  assert "Without override, override_by_user is null" \
    "python3 -c 'import json; d=json.loads(\"\"\"${NO_OVERRIDE}\"\"\"); assert d[\"override_by_user\"] is None, f\"got {d[\"override_by_user\"]}\"'"
else
  assert "User override forces tactic task to strategy" "false"
  assert "override_by_user is set to strategy" "false"
  assert "detected_scope still shows tactic despite override" "false"
  assert "User override forces strategy task to tactic" "false"
  assert "override_by_user is set to tactic" "false"
  assert "detected_scope still shows strategy despite override" "false"
  assert "Without override, override_by_user is null" "false"
fi

# ══════════════════════════════════════════
# Confidence Scoring Tests
# ══════════════════════════════════════════
echo ""
echo "--- Confidence Scoring ---"

echo "Confidence should reflect classification strength"
if $LIBS_SOURCED; then
  # High confidence: strong tactic signal (multiple tactic keywords)
  HIGH_CONF_TACTIC="$(safe_call analyze_scope "fix the typo and correct the minor naming issue")"
  assert "Strong tactic signal produces high confidence (>= 0.8)" \
    "python3 -c 'import json; d=json.loads(\"\"\"${HIGH_CONF_TACTIC}\"\"\"); assert d[\"confidence\"] >= 0.8, f\"got {d[\"confidence\"]}\"'"

  # High confidence: strong strategy signal
  HIGH_CONF_STRATEGY="$(safe_call analyze_scope "architect and implement a complete microservice infrastructure with database migration")"
  assert "Strong strategy signal produces high confidence (>= 0.8)" \
    "python3 -c 'import json; d=json.loads(\"\"\"${HIGH_CONF_STRATEGY}\"\"\"); assert d[\"confidence\"] >= 0.8, f\"got {d[\"confidence\"]}\"'"

  # Low confidence: ambiguous (< 0.6 triggers clarification)
  LOW_CONF="$(safe_call analyze_scope "change the button")"
  assert "Ambiguous description produces low confidence (< 0.6)" \
    "python3 -c 'import json; d=json.loads(\"\"\"${LOW_CONF}\"\"\"); assert d[\"confidence\"] < 0.6, f\"got {d[\"confidence\"]}\"'"

  # Confidence range: must be [0.0, 1.0]
  assert "Confidence is in range [0.0, 1.0]" \
    "python3 -c 'import json; d=json.loads(\"\"\"${HIGH_CONF_TACTIC}\"\"\"); c=d[\"confidence\"]; assert 0.0 <= c <= 1.0, f\"got {c}\"'"
else
  assert "Strong tactic signal produces high confidence (>= 0.8)" "false"
  assert "Strong strategy signal produces high confidence (>= 0.8)" "false"
  assert "Ambiguous description produces low confidence (< 0.6)" "false"
  assert "Confidence is in range [0.0, 1.0]" "false"
fi

# ══════════════════════════════════════════
# Cross-Cutting Concern Detection
# ══════════════════════════════════════════
echo ""
echo "--- Cross-Cutting Concerns ---"

echo "Multiple domains should bias toward strategy"
if $LIBS_SOURCED; then
  # Multiple domains: auth + database + api
  CROSS_CUT="$(safe_call analyze_scope "add authentication to the API and update the database schema for user roles")"
  assert "Multiple domains detected as cross-cutting concerns" \
    "python3 -c 'import json; d=json.loads(\"\"\"${CROSS_CUT}\"\"\"); cc=d[\"signals\"][\"cross_cutting_concerns\"]; assert len(cc) >= 2, f\"got {len(cc)} concerns: {cc}\"'"
  assert "Cross-cutting concerns add +1.0 to score" \
    "python3 -c 'import json; d=json.loads(\"\"\"${CROSS_CUT}\"\"\"); assert d[\"keyword_scores\"][\"cross_cutting_score\"] == 1.0, f\"got {d[\"keyword_scores\"][\"cross_cutting_score\"]}\"'"
  assert "Cross-cutting task biases toward strategy" \
    "python3 -c 'import json; d=json.loads(\"\"\"${CROSS_CUT}\"\"\"); assert d[\"detected_scope\"] == \"strategy\", f\"got {d[\"detected_scope\"]}\"'"

  # Single domain: no cross-cutting bonus
  SINGLE_DOMAIN="$(safe_call analyze_scope "fix the CSS padding on the login button")"
  assert "Single domain has no cross-cutting bonus" \
    "python3 -c 'import json; d=json.loads(\"\"\"${SINGLE_DOMAIN}\"\"\"); assert d[\"keyword_scores\"][\"cross_cutting_score\"] == 0.0, f\"got {d[\"keyword_scores\"][\"cross_cutting_score\"]}\"'"
else
  assert "Multiple domains detected as cross-cutting concerns" "false"
  assert "Cross-cutting concerns add +1.0 to score" "false"
  assert "Cross-cutting task biases toward strategy" "false"
  assert "Single domain has no cross-cutting bonus" "false"
fi

# ══════════════════════════════════════════
# File Count Heuristic
# ══════════════════════════════════════════
echo ""
echo "--- File Count Heuristic ---"

echo "File count estimates should bias scoring"
if $LIBS_SOURCED; then
  # 1-2 files: tactic bias (-0.5)
  FEW_FILES="$(safe_call analyze_scope "fix the typo in README")"
  assert "1-2 file estimate gives file_count_score of -0.5" \
    "python3 -c 'import json; d=json.loads(\"\"\"${FEW_FILES}\"\"\"); fce=d[\"signals\"][\"file_count_estimate\"]; fcs=d[\"keyword_scores\"][\"file_count_score\"]; assert fce <= 2 and fcs == -0.5, f\"files={fce}, score={fcs}\"'"

  # 6+ files: strategy bias (+0.5)
  MANY_FILES="$(safe_call analyze_scope "implement OAuth2 with RBAC across all API endpoints and update all test files and documentation")"
  assert "6+ file estimate gives file_count_score of +0.5" \
    "python3 -c 'import json; d=json.loads(\"\"\"${MANY_FILES}\"\"\"); fce=d[\"signals\"][\"file_count_estimate\"]; fcs=d[\"keyword_scores\"][\"file_count_score\"]; assert fce >= 6 and fcs == 0.5, f\"files={fce}, score={fcs}\"'"

  # 3-5 files: neutral (0.0)
  MID_FILES="$(safe_call analyze_scope "update the three configuration files for the new environment")"
  assert "3-5 file estimate gives file_count_score of 0.0" \
    "python3 -c 'import json; d=json.loads(\"\"\"${MID_FILES}\"\"\"); fcs=d[\"keyword_scores\"][\"file_count_score\"]; assert fcs == 0.0, f\"score={fcs}\"'"
else
  assert "1-2 file estimate gives file_count_score of -0.5" "false"
  assert "6+ file estimate gives file_count_score of +0.5" "false"
  assert "3-5 file estimate gives file_count_score of 0.0" "false"
fi

# ══════════════════════════════════════════
# Output Structure Tests
# ══════════════════════════════════════════
echo ""
echo "--- Output Structure ---"

echo "analyze_scope returns complete ScopeAnalysis entity"
if $LIBS_SOURCED; then
  STRUCT_RESULT="$(safe_call analyze_scope "fix the typo in README")"

  # Required top-level fields
  assert "Output contains analysis_id" \
    "python3 -c 'import json; d=json.loads(\"\"\"${STRUCT_RESULT}\"\"\"); assert \"analysis_id\" in d'"
  assert "Output contains input_description" \
    "python3 -c 'import json; d=json.loads(\"\"\"${STRUCT_RESULT}\"\"\"); assert \"input_description\" in d'"
  assert "Output contains detected_scope" \
    "python3 -c 'import json; d=json.loads(\"\"\"${STRUCT_RESULT}\"\"\"); assert \"detected_scope\" in d'"
  assert "Output contains keyword_scores" \
    "python3 -c 'import json; d=json.loads(\"\"\"${STRUCT_RESULT}\"\"\"); assert \"keyword_scores\" in d'"
  assert "Output contains signals" \
    "python3 -c 'import json; d=json.loads(\"\"\"${STRUCT_RESULT}\"\"\"); assert \"signals\" in d'"
  assert "Output contains confidence" \
    "python3 -c 'import json; d=json.loads(\"\"\"${STRUCT_RESULT}\"\"\"); assert \"confidence\" in d'"
  assert "Output contains override_by_user" \
    "python3 -c 'import json; d=json.loads(\"\"\"${STRUCT_RESULT}\"\"\"); assert \"override_by_user\" in d'"
  assert "Output contains final_scope" \
    "python3 -c 'import json; d=json.loads(\"\"\"${STRUCT_RESULT}\"\"\"); assert \"final_scope\" in d'"
  assert "Output contains timestamp" \
    "python3 -c 'import json; d=json.loads(\"\"\"${STRUCT_RESULT}\"\"\"); assert \"timestamp\" in d'"
else
  assert "Output contains analysis_id" "false"
  assert "Output contains input_description" "false"
  assert "Output contains detected_scope" "false"
  assert "Output contains keyword_scores" "false"
  assert "Output contains signals" "false"
  assert "Output contains confidence" "false"
  assert "Output contains override_by_user" "false"
  assert "Output contains final_scope" "false"
  assert "Output contains timestamp" "false"
fi

# ══════════════════════════════════════════
# Performance Tests
# ══════════════════════════════════════════
echo ""
echo "--- Performance ---"

echo "Scope detection must complete within time budget"
if $LIBS_SOURCED; then
  PERF_START=$(date +%s)
  PERF_RESULT="$(safe_call analyze_scope "implement a complete user authentication system with OAuth2 RBAC and database migrations")"
  PERF_END=$(date +%s)
  PERF_ELAPSED=$((PERF_END - PERF_START))
  assert "Scope detection completes within 5 seconds (took ${PERF_ELAPSED}s)" \
    "[ $PERF_ELAPSED -le 5 ]"
else
  assert "Scope detection completes within 5 seconds" "false"
fi

# ═══════════════════════════════════════
# Final Results
# ═══════════════════════════════════════
echo ""
echo "======================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "======================================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
