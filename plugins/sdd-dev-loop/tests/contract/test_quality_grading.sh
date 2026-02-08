#!/usr/bin/env bash
# Contract Tests: Quality Grading Engine
# TDD tests for quality-grading.md contract
# Tests: normalize_metric, compute_composite, check_threshold, validate_weights
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
CONFIG_DIR="${PLUGIN_DIR}/config"
TEST_TMPDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_TMPDIR"
}
trap cleanup EXIT

echo "=== Quality Grading Contract Tests ==="
echo ""

# ── Library Existence ──
echo "Library and config existence"
assert "grading-engine.sh exists" "[ -f '${LIB_DIR}/grading-engine.sh' ]"
assert "weights.json config exists" "[ -f '${CONFIG_DIR}/weights.json' ]"
assert "thresholds.json config exists" "[ -f '${CONFIG_DIR}/thresholds.json' ]"

# Source library (tolerant of partially-implemented libs)
LIBS_SOURCED=false
if [ -f "${LIB_DIR}/grading-engine.sh" ]; then
  ( set +eu; source "${LIB_DIR}/grading-engine.sh" ) 2>/dev/null || true
  set +eu
  source "${LIB_DIR}/grading-engine.sh" 2>/dev/null || true
  set -eo pipefail
  LIBS_SOURCED=true
fi

# ── Function Existence ──
echo ""
echo "Function existence"
assert "normalize_metric function exists" "type -t normalize_metric 2>/dev/null | grep -q function"
assert "compute_composite function exists" "type -t compute_composite 2>/dev/null | grep -q function"
assert "check_threshold function exists" "type -t check_threshold 2>/dev/null | grep -q function"
assert "validate_weights function exists" "type -t validate_weights 2>/dev/null | grep -q function"

# ══════════════════════════════════════════
# normalize_metric Tests
# ══════════════════════════════════════════
echo ""
echo "--- normalize_metric ---"

echo "Clamping to 0.0-1.0 range"
if $LIBS_SOURCED; then
  # Standard values within range
  NORM_HALF="$(safe_call normalize_metric 0.5)"
  assert "normalize_metric 0.5 returns 0.5" \
    "python3 -c 'v=float(\"${NORM_HALF}\".strip()); assert round(v,2) == 0.5, f\"got {v}\"'"

  # Value at boundaries
  NORM_ZERO="$(safe_call normalize_metric 0.0)"
  assert "normalize_metric 0.0 returns 0.0" \
    "python3 -c 'v=float(\"${NORM_ZERO}\".strip()); assert round(v,2) == 0.0, f\"got {v}\"'"

  NORM_ONE="$(safe_call normalize_metric 1.0)"
  assert "normalize_metric 1.0 returns 1.0" \
    "python3 -c 'v=float(\"${NORM_ONE}\".strip()); assert round(v,2) == 1.0, f\"got {v}\"'"

  # Values outside range should be clamped
  NORM_OVER="$(safe_call normalize_metric 1.5)"
  assert "normalize_metric 1.5 clamps to 1.0" \
    "python3 -c 'v=float(\"${NORM_OVER}\".strip()); assert round(v,2) == 1.0, f\"got {v}\"'"

  NORM_NEG="$(safe_call normalize_metric -0.3)"
  assert "normalize_metric -0.3 clamps to 0.0" \
    "python3 -c 'v=float(\"${NORM_NEG}\".strip()); assert round(v,2) == 0.0, f\"got {v}\"'"

  # Lint/type_safety: error count to normalized (1.0 if zero errors)
  NORM_LINT_ZERO="$(safe_call normalize_metric --type lint 0)"
  assert "normalize_metric --type lint 0 errors returns 1.0" \
    "python3 -c 'v=float(\"${NORM_LINT_ZERO}\".strip()); assert round(v,2) == 1.0, f\"got {v}\"'"

  NORM_LINT_MANY="$(safe_call normalize_metric --type lint 50)"
  assert "normalize_metric --type lint 50 errors returns value < 1.0" \
    "python3 -c 'v=float(\"${NORM_LINT_MANY}\".strip()); assert 0.0 <= v < 1.0, f\"got {v}\"'"

  # Build: boolean to 0.0/1.0
  NORM_BUILD_PASS="$(safe_call normalize_metric --type build true)"
  assert "normalize_metric --type build true returns 1.0" \
    "python3 -c 'v=float(\"${NORM_BUILD_PASS}\".strip()); assert round(v,2) == 1.0, f\"got {v}\"'"

  NORM_BUILD_FAIL="$(safe_call normalize_metric --type build false)"
  assert "normalize_metric --type build false returns 0.0" \
    "python3 -c 'v=float(\"${NORM_BUILD_FAIL}\".strip()); assert round(v,2) == 0.0, f\"got {v}\"'"
else
  assert "normalize_metric 0.5 returns 0.5" "false"
  assert "normalize_metric 0.0 returns 0.0" "false"
  assert "normalize_metric 1.0 returns 1.0" "false"
  assert "normalize_metric 1.5 clamps to 1.0" "false"
  assert "normalize_metric -0.3 clamps to 0.0" "false"
  assert "normalize_metric --type lint 0 errors returns 1.0" "false"
  assert "normalize_metric --type lint 50 errors returns value < 1.0" "false"
  assert "normalize_metric --type build true returns 1.0" "false"
  assert "normalize_metric --type build false returns 0.0" "false"
fi

# ══════════════════════════════════════════
# compute_composite Tests
# ══════════════════════════════════════════
echo ""
echo "--- compute_composite ---"

echo "Weighted average calculation"
if $LIBS_SOURCED; then
  # All metrics perfect (1.0) with default weights should yield 1.0
  PERFECT='{"test_pass_rate":1.0,"test_coverage":1.0,"lint":1.0,"type_safety":1.0,"security":1.0,"build":1.0}'
  DEFAULT_W='{"test_pass_rate":0.35,"test_coverage":0.20,"lint":0.15,"type_safety":0.15,"security":0.10,"build":0.05}'
  COMP_PERFECT="$(safe_call compute_composite --metrics "$PERFECT" --weights "$DEFAULT_W")"
  assert "All 1.0 metrics with valid weights yields composite 1.0" \
    "python3 -c 'import json; d=json.loads(\"\"\"${COMP_PERFECT}\"\"\"); assert abs(d[\"composite_grade\"] - 1.0) < 0.001, f\"got {d[\"composite_grade\"]}\"'"

  # All metrics zero yields 0.0
  ZERO='{"test_pass_rate":0.0,"test_coverage":0.0,"lint":0.0,"type_safety":0.0,"security":0.0,"build":0.0}'
  COMP_ZERO="$(safe_call compute_composite --metrics "$ZERO" --weights "$DEFAULT_W")"
  assert "All 0.0 metrics yields composite 0.0" \
    "python3 -c 'import json; d=json.loads(\"\"\"${COMP_ZERO}\"\"\"); assert abs(d[\"composite_grade\"] - 0.0) < 0.001, f\"got {d[\"composite_grade\"]}\"'"

  # Verify weighted calculation: 0.35*0.8 + 0.20*0.7 + 0.15*0.9 + 0.15*0.6 + 0.10*1.0 + 0.05*1.0 = 0.795
  MIXED='{"test_pass_rate":0.8,"test_coverage":0.7,"lint":0.9,"type_safety":0.6,"security":1.0,"build":1.0}'
  COMP_MIXED="$(safe_call compute_composite --metrics "$MIXED" --weights "$DEFAULT_W")"
  assert "Mixed metrics yield correct weighted average (0.795)" \
    "python3 -c 'import json; d=json.loads(\"\"\"${COMP_MIXED}\"\"\"); assert abs(d[\"composite_grade\"] - 0.795) < 0.01, f\"got {d[\"composite_grade\"]}\"'"

  # Returns breakdown array
  assert "compute_composite returns breakdown array" \
    "python3 -c 'import json; d=json.loads(\"\"\"${COMP_MIXED}\"\"\"); assert \"breakdown\" in d and isinstance(d[\"breakdown\"], list)'"
  assert "breakdown entries have metric, value, weight, contribution" \
    "python3 -c 'import json; d=json.loads(\"\"\"${COMP_MIXED}\"\"\"); e=d[\"breakdown\"][0]; assert all(k in e for k in [\"metric\",\"value\",\"weight\",\"contribution\"])'"

  # INVALID_METRICS: metric values outside 0.0-1.0
  BAD_METRICS='{"test_pass_rate":1.5,"test_coverage":0.7,"lint":0.9,"type_safety":0.6,"security":1.0,"build":1.0}'
  COMP_BAD="$(safe_call compute_composite --metrics "$BAD_METRICS" --weights "$DEFAULT_W")"
  assert "Metric value > 1.0 returns INVALID_METRICS" \
    "echo '${COMP_BAD}' | grep -q 'INVALID_METRICS'"

  # INVALID_WEIGHTS: weights don't sum to 1.0
  BAD_W='{"test_pass_rate":0.50,"test_coverage":0.50,"lint":0.15,"type_safety":0.15,"security":0.10,"build":0.05}'
  COMP_BAD_W="$(safe_call compute_composite --metrics "$PERFECT" --weights "$BAD_W")"
  assert "Weights not summing to 1.0 returns INVALID_WEIGHTS" \
    "echo '${COMP_BAD_W}' | grep -q 'INVALID_WEIGHTS'"
else
  assert "All 1.0 metrics with valid weights yields composite 1.0" "false"
  assert "All 0.0 metrics yields composite 0.0" "false"
  assert "Mixed metrics yield correct weighted average (0.795)" "false"
  assert "compute_composite returns breakdown array" "false"
  assert "breakdown entries have metric, value, weight, contribution" "false"
  assert "Metric value > 1.0 returns INVALID_METRICS" "false"
  assert "Weights not summing to 1.0 returns INVALID_WEIGHTS" "false"
fi

# ══════════════════════════════════════════
# check_threshold Tests
# ══════════════════════════════════════════
echo ""
echo "--- check_threshold ---"

echo "Threshold pass/fail"
if $LIBS_SOURCED; then
  # Grade above threshold
  ABOVE="$(safe_call check_threshold --grade 0.96 --threshold 0.95)"
  assert "Grade 0.96 >= threshold 0.95 returns threshold_met=true" \
    "python3 -c 'import json; d=json.loads(\"\"\"${ABOVE}\"\"\"); assert d[\"threshold_met\"] == True'"
  assert "Grade 0.96 vs threshold 0.95 returns positive delta" \
    "python3 -c 'import json; d=json.loads(\"\"\"${ABOVE}\"\"\"); assert d[\"delta\"] > 0'"
  assert "Grade 0.96 vs threshold 0.95 returns percent_complete > 100" \
    "python3 -c 'import json; d=json.loads(\"\"\"${ABOVE}\"\"\"); assert d[\"percent_complete\"] > 100'"

  # Grade below threshold
  BELOW="$(safe_call check_threshold --grade 0.80 --threshold 0.95)"
  assert "Grade 0.80 < threshold 0.95 returns threshold_met=false" \
    "python3 -c 'import json; d=json.loads(\"\"\"${BELOW}\"\"\"); assert d[\"threshold_met\"] == False'"
  assert "Grade 0.80 vs threshold 0.95 returns negative delta" \
    "python3 -c 'import json; d=json.loads(\"\"\"${BELOW}\"\"\"); assert d[\"delta\"] < 0'"

  # Grade exactly at threshold
  EXACT="$(safe_call check_threshold --grade 0.95 --threshold 0.95)"
  assert "Grade exactly at threshold returns threshold_met=true" \
    "python3 -c 'import json; d=json.loads(\"\"\"${EXACT}\"\"\"); assert d[\"threshold_met\"] == True'"

  # INVALID_GRADE
  BAD_GRADE="$(safe_call check_threshold --grade 1.5 --threshold 0.95)"
  assert "Grade > 1.0 returns INVALID_GRADE" \
    "echo '${BAD_GRADE}' | grep -q 'INVALID_GRADE'"

  # INVALID_THRESHOLD
  BAD_THRESH="$(safe_call check_threshold --grade 0.90 --threshold 0.50)"
  assert "Threshold < 0.80 returns INVALID_THRESHOLD" \
    "echo '${BAD_THRESH}' | grep -q 'INVALID_THRESHOLD'"
else
  assert "Grade 0.96 >= threshold 0.95 returns threshold_met=true" "false"
  assert "Grade 0.96 vs threshold 0.95 returns positive delta" "false"
  assert "Grade 0.96 vs threshold 0.95 returns percent_complete > 100" "false"
  assert "Grade 0.80 < threshold 0.95 returns threshold_met=false" "false"
  assert "Grade 0.80 vs threshold 0.95 returns negative delta" "false"
  assert "Grade exactly at threshold returns threshold_met=true" "false"
  assert "Grade > 1.0 returns INVALID_GRADE" "false"
  assert "Threshold < 0.80 returns INVALID_THRESHOLD" "false"
fi

# ══════════════════════════════════════════
# validate_weights Tests
# ══════════════════════════════════════════
echo ""
echo "--- validate_weights ---"

echo "Weight validation rules"
if $LIBS_SOURCED; then
  # Valid weights (sum to 1.0)
  VALID_W='{"test_pass_rate":0.35,"test_coverage":0.20,"lint":0.15,"type_safety":0.15,"security":0.10,"build":0.05}'
  VW_RESULT="$(safe_call validate_weights "$VALID_W")"
  assert "Valid weights (sum=1.0) passes validation" \
    "python3 -c 'import json; d=json.loads(\"\"\"${VW_RESULT}\"\"\"); assert d.get(\"valid\") == True'"

  # Weights within tolerance (0.001)
  CLOSE_W='{"test_pass_rate":0.351,"test_coverage":0.199,"lint":0.15,"type_safety":0.15,"security":0.10,"build":0.05}'
  VW_CLOSE="$(safe_call validate_weights "$CLOSE_W")"
  assert "Weights within 0.001 tolerance passes" \
    "python3 -c 'import json; d=json.loads(\"\"\"${VW_CLOSE}\"\"\"); assert d.get(\"valid\") == True'"

  # Weights not summing to 1.0 (outside tolerance)
  BAD_SUM='{"test_pass_rate":0.40,"test_coverage":0.30,"lint":0.15,"type_safety":0.15,"security":0.10,"build":0.05}'
  VW_BAD="$(safe_call validate_weights "$BAD_SUM")"
  assert "Weights summing to 1.15 fails validation" \
    "python3 -c 'import json; d=json.loads(\"\"\"${VW_BAD}\"\"\"); assert d.get(\"valid\") == False' || echo '${VW_BAD}' | grep -q 'INVALID_WEIGHTS'"

  # test_pass_rate below minimum (0.30 per config)
  LOW_TPR_W='{"test_pass_rate":0.10,"test_coverage":0.30,"lint":0.20,"type_safety":0.20,"security":0.15,"build":0.05}'
  VW_LOW="$(safe_call validate_weights "$LOW_TPR_W")"
  assert "test_pass_rate weight below min (0.30) fails validation" \
    "python3 -c 'import json; d=json.loads(\"\"\"${VW_LOW}\"\"\"); assert d.get(\"valid\") == False' || echo '${VW_LOW}' | grep -q 'INVALID_WEIGHTS'"

  # test_pass_rate at exactly minimum
  EXACT_TPR_W='{"test_pass_rate":0.30,"test_coverage":0.20,"lint":0.15,"type_safety":0.15,"security":0.15,"build":0.05}'
  VW_EXACT="$(safe_call validate_weights "$EXACT_TPR_W")"
  assert "test_pass_rate weight at exactly min (0.30) passes" \
    "python3 -c 'import json; d=json.loads(\"\"\"${VW_EXACT}\"\"\"); assert d.get(\"valid\") == True'"

  # Missing required metric key
  MISSING_KEY='{"test_pass_rate":0.35,"test_coverage":0.20,"lint":0.15,"type_safety":0.15,"security":0.15}'
  VW_MISSING="$(safe_call validate_weights "$MISSING_KEY")"
  assert "Missing weight key (build) fails validation" \
    "python3 -c 'import json; d=json.loads(\"\"\"${VW_MISSING}\"\"\"); assert d.get(\"valid\") == False' || echo '${VW_MISSING}' | grep -q 'INVALID_WEIGHTS'"
else
  assert "Valid weights (sum=1.0) passes validation" "false"
  assert "Weights within 0.001 tolerance passes" "false"
  assert "Weights summing to 1.15 fails validation" "false"
  assert "test_pass_rate weight below min (0.30) fails validation" "false"
  assert "test_pass_rate weight at exactly min (0.30) passes" "false"
  assert "Missing weight key (build) fails validation" "false"
fi

# ══════════════════════════════════════════
# Full Pipeline Tests (run_grade)
# ══════════════════════════════════════════
echo ""
echo "--- run_grade full pipeline ---"

echo "Full pipeline: collect, normalize, composite, threshold"
if $LIBS_SOURCED; then
  # Check run_grade function exists
  assert "run_grade function exists" "type -t run_grade 2>/dev/null | grep -q function"

  # Full pipeline with a mock project directory
  MOCK_PROJECT="$TEST_TMPDIR/mock_project"
  mkdir -p "$MOCK_PROJECT/src" "$MOCK_PROJECT/tests"

  # Create a minimal mock project for grading
  cat > "$MOCK_PROJECT/src/main.py" << 'PYEOF'
def hello():
    return "world"
PYEOF

  cat > "$MOCK_PROJECT/tests/test_main.py" << 'PYEOF'
def test_hello():
    from src.main import hello
    assert hello() == "world"
PYEOF

  # Full pipeline: should collect all 6 raw metrics, normalize, compute composite, check threshold
  PIPELINE_WEIGHTS='{"test_pass_rate":0.35,"test_coverage":0.20,"lint":0.15,"type_safety":0.15,"security":0.10,"build":0.05}'
  PIPELINE_RESULT="$(safe_call run_grade --project-dir "$MOCK_PROJECT" --weights "$PIPELINE_WEIGHTS" --threshold 0.95)"

  # Pipeline should return a JSON object with composite_grade
  assert "run_grade returns composite_grade field" \
    "python3 -c 'import json; d=json.loads(\"\"\"${PIPELINE_RESULT}\"\"\"); assert \"composite_grade\" in d, f\"keys: {list(d.keys())}\"'"

  # Pipeline should return all 6 raw metrics
  assert "run_grade returns all 6 raw metrics" \
    "python3 -c 'import json; d=json.loads(\"\"\"${PIPELINE_RESULT}\"\"\"); rm=d.get(\"raw_metrics\",{}); expected=[\"test_pass_rate\",\"coverage_pct\",\"lint_error_count\",\"type_error_count\",\"security_vulnerabilities\",\"build_status\"]; assert all(k in rm for k in expected), f\"missing: {[k for k in expected if k not in rm]}\"'"

  # Pipeline should return normalized scores
  assert "run_grade returns normalized_scores" \
    "python3 -c 'import json; d=json.loads(\"\"\"${PIPELINE_RESULT}\"\"\"); assert \"normalized_scores\" in d'"

  # Pipeline should return passed_threshold boolean
  assert "run_grade returns passed_threshold boolean" \
    "python3 -c 'import json; d=json.loads(\"\"\"${PIPELINE_RESULT}\"\"\"); assert isinstance(d.get(\"passed_threshold\"), bool)'"

  # Pipeline composite_grade should be in [0, 1]
  assert "run_grade composite_grade is in [0, 1]" \
    "python3 -c 'import json; d=json.loads(\"\"\"${PIPELINE_RESULT}\"\"\"); g=d[\"composite_grade\"]; assert 0.0 <= g <= 1.0, f\"got {g}\"'"

  # GRADING_TIMEOUT: pipeline must complete within 30 seconds
  TIMEOUT_START=$(date +%s)
  TIMEOUT_RESULT="$(timeout 30 bash -c "
    source '${LIB_DIR}/grading-engine.sh' 2>/dev/null || true
    safe_call() { local r=''; r=\"\$( set +eu; \"\$@\" 2>/dev/null )\" || true; echo \"\$r\"; }
    safe_call run_grade --project-dir '$MOCK_PROJECT' --weights '$PIPELINE_WEIGHTS' --threshold 0.95
  " 2>/dev/null)" || true
  TIMEOUT_END=$(date +%s)
  TIMEOUT_ELAPSED=$((TIMEOUT_END - TIMEOUT_START))
  assert "GRADING_TIMEOUT: full pipeline completes within 30 seconds (took ${TIMEOUT_ELAPSED}s)" \
    "[ $TIMEOUT_ELAPSED -le 30 ]"
else
  assert "run_grade function exists" "false"
  assert "run_grade returns composite_grade field" "false"
  assert "run_grade returns all 6 raw metrics" "false"
  assert "run_grade returns normalized_scores" "false"
  assert "run_grade returns passed_threshold boolean" "false"
  assert "run_grade composite_grade is in [0, 1]" "false"
  assert "GRADING_TIMEOUT: full pipeline completes within 30 seconds" "false"
fi

# ══════════════════════════════════════════
# LLM Judge Tests
# ══════════════════════════════════════════
echo ""
echo "--- LLM Judge ---"

echo "Semantic evaluation"
if $LIBS_SOURCED; then
  # Check llm_judge function exists
  assert "llm_judge function exists" "type -t llm_judge 2>/dev/null | grep -q function"

  # LLM judge should evaluate readability aspect
  LLM_MOCK_DIFF='--- a/src/main.py
+++ b/src/main.py
@@ -1,2 +1,5 @@
 def hello():
-    return "world"
+    """Return a greeting."""
+    greeting = "world"
+    return greeting'

  echo "$LLM_MOCK_DIFF" > "$TEST_TMPDIR/mock_diff.patch"

  LLM_RESULT="$(safe_call llm_judge --diff-file "$TEST_TMPDIR/mock_diff.patch" --spec-file /dev/null)"

  # Should return a score in [0, 1]
  assert "llm_judge returns llm_judge_score in [0, 1]" \
    "python3 -c 'import json; d=json.loads(\"\"\"${LLM_RESULT}\"\"\"); s=d.get(\"llm_judge_score\", -1); assert 0.0 <= s <= 1.0, f\"got {s}\"'"

  # Should return readability aspect
  assert "llm_judge evaluates readability aspect" \
    "python3 -c 'import json; d=json.loads(\"\"\"${LLM_RESULT}\"\"\"); aspects=d.get(\"aspects\", {}); assert \"readability\" in aspects, f\"aspects: {list(aspects.keys())}\"'"

  # Should return architecture aspect
  assert "llm_judge evaluates architecture aspect" \
    "python3 -c 'import json; d=json.loads(\"\"\"${LLM_RESULT}\"\"\"); aspects=d.get(\"aspects\", {}); assert \"architecture\" in aspects, f\"aspects: {list(aspects.keys())}\"'"

  # Should return compliance aspect
  assert "llm_judge evaluates compliance aspect" \
    "python3 -c 'import json; d=json.loads(\"\"\"${LLM_RESULT}\"\"\"); aspects=d.get(\"aspects\", {}); assert \"compliance\" in aspects, f\"aspects: {list(aspects.keys())}\"'"

  # Should return feedback text
  assert "llm_judge returns feedback text" \
    "python3 -c 'import json; d=json.loads(\"\"\"${LLM_RESULT}\"\"\"); fb=d.get(\"llm_judge_feedback\", \"\"); assert len(fb) > 0, \"empty feedback\"'"

  # NO_CODE_CHANGES error: empty diff should produce error
  echo "" > "$TEST_TMPDIR/empty_diff.patch"
  LLM_EMPTY="$(safe_call llm_judge --diff-file "$TEST_TMPDIR/empty_diff.patch" --spec-file /dev/null)"
  assert "llm_judge with empty diff returns NO_CODE_CHANGES error" \
    "echo '${LLM_EMPTY}' | grep -q 'NO_CODE_CHANGES'"

  # LLM_FAILED error: simulate by passing an invalid model
  LLM_BAD_MODEL="$(safe_call llm_judge --diff-file "$TEST_TMPDIR/mock_diff.patch" --spec-file /dev/null --model "nonexistent-model-xyz")"
  assert "llm_judge with invalid model returns LLM_FAILED error" \
    "echo '${LLM_BAD_MODEL}' | grep -q 'LLM_FAILED'"
else
  assert "llm_judge function exists" "false"
  assert "llm_judge returns llm_judge_score in [0, 1]" "false"
  assert "llm_judge evaluates readability aspect" "false"
  assert "llm_judge evaluates architecture aspect" "false"
  assert "llm_judge evaluates compliance aspect" "false"
  assert "llm_judge returns feedback text" "false"
  assert "llm_judge with empty diff returns NO_CODE_CHANGES error" "false"
  assert "llm_judge with invalid model returns LLM_FAILED error" "false"
fi

# ═══════════════════════════════════════
# Final Results
# ═══════════════════════════════════════
echo ""
echo "======================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "======================================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
