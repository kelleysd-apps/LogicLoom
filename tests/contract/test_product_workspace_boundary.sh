#!/usr/bin/env bash
# Contract Tests: harness↔product workspace boundary
#
# Encodes the executable spec for the harness/product-boundary fixes. A product
# built on LogicLoom needs a clean boundary against the framework-owned root:
#   1. SPECS ARE TRACKED   — a product spec under specs/<feature>/ must NOT be
#                            git-ignored (cosmos lost ~801 spec files to this).
#   2. JEST IS SCOPED      — the framework's jest must not sweep product tests
#                            under web/ apps/ src/ into framework coverage gates.
#   3. POLICY RATIFIED     — file-structure-policy.md must be ratified (no
#                            'Effective Date: TBD') and document the product
#                            workspace (web/ , apps/).
#   4. ENTRY DOCS SURFACE  — CLAUDE.md and a top-level entry doc (README.md /
#                            START_HERE.md) must surface the product-workspace
#                            location so a new user finds it before they need it.
#
# This test is RED until the fixes land — that is expected. It is meant for the
# user/CI to run; it shells out to `git check-ignore` (read-only) by design.
set -euo pipefail

PASS=0; FAIL=0; TOTAL=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

# Resolve the repo root so the test runs from anywhere. Prefer git; fall back to
# walking up from this script to the dir that holds package.json + .logic-loom.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"

PKG="package.json"
POLICY=".docs/policies/file-structure-policy.md"
CLAUDE="CLAUDE.md"
README="README.md"
START_HERE="START_HERE.md"

echo "═══ Harness↔Product Workspace Boundary ═══"
echo ""

# ── 1. SPECS ARE TRACKED ─────────────────────────────────────────────────────
# A product spec path under specs/<feature>/ must NOT be git-ignored.
# git check-ignore operates on the path string, so the file need not exist; we
# create a throwaway path to make the assertion robust either way, then clean up.
echo "1. Product specs under specs/<feature>/ are tracked (not git-ignored)"
SAMPLE_SPEC="specs/000-sample/spec.md"
CREATED_SAMPLE=0
if [ ! -e "$SAMPLE_SPEC" ]; then
  mkdir -p "$(dirname "$SAMPLE_SPEC")" 2>/dev/null || true
  : > "$SAMPLE_SPEC" 2>/dev/null && CREATED_SAMPLE=1
fi
# rc==0 means the path IS ignored; rc!=0 means NOT ignored (what we want).
set +e
git check-ignore -q "$SAMPLE_SPEC"; SPEC_IGNORE_RC=$?
set -e
assert "specs/000-sample/spec.md is NOT git-ignored (check-ignore rc != 0)" \
  "[ $SPEC_IGNORE_RC -ne 0 ]"
# Clean up only what we created, so we don't perturb the working tree.
if [ "$CREATED_SAMPLE" -eq 1 ]; then
  rm -f "$SAMPLE_SPEC" 2>/dev/null || true
  rmdir "specs/000-sample" 2>/dev/null || true
fi

# ── 2. JEST IS SCOPED AWAY FROM PRODUCT PATHS ────────────────────────────────
# The framework jest config must (a) ignore product paths web/ apps/ src/ via
# testPathIgnorePatterns, and (b) scope discovery to tests/ (via `roots` or a
# tests/-anchored `testMatch`) rather than a bare repo-wide `**/tests/**` glob.
echo ""
echo "2. Framework jest is scoped away from product paths (web/ apps/ src/)"
if command -v jq >/dev/null 2>&1; then
  IGNORE_HAS_WEB=$(jq -r '[.jest.testPathIgnorePatterns[]? | select(test("(^|/)web/"))] | length' "$PKG" 2>/dev/null || echo 0)
  IGNORE_HAS_APPS=$(jq -r '[.jest.testPathIgnorePatterns[]? | select(test("(^|/)apps/"))] | length' "$PKG" 2>/dev/null || echo 0)
  IGNORE_HAS_SRC=$(jq -r '[.jest.testPathIgnorePatterns[]? | select(test("(^|/)src/"))] | length' "$PKG" 2>/dev/null || echo 0)
  # roots scoped to tests/  OR  every testMatch entry anchored under tests/ .
  ROOTS_SCOPED=$(jq -r '[.jest.roots[]? | select(test("(^|/)tests/?"))] | length' "$PKG" 2>/dev/null || echo 0)
  TESTMATCH_TOTAL=$(jq -r '(.jest.testMatch // []) | length' "$PKG" 2>/dev/null || echo 0)
  # An entry only counts as scoped-to-tests/ if it anchors on tests/ AND is not
  # the bare repo-wide '**/tests/**' glob (which spans product paths too).
  TESTMATCH_TESTS_ANCHORED=$(jq -r '[.jest.testMatch[]? | select(test("(^|/)tests/")) | select(test("\\*\\*/tests/\\*\\*") | not)] | length' "$PKG" 2>/dev/null || echo 0)
  TESTMATCH_BARE_GLOB=$(jq -r '[.jest.testMatch[]? | select(test("\\*\\*/tests/\\*\\*"))] | length' "$PKG" 2>/dev/null || echo 0)
else
  # jq-absent fallback: grep the raw file. Coarser but sufficient for the gate.
  JEST_BLOCK="$(cat "$PKG")"
  grep -qE '"testPathIgnorePatterns"' <<<"$JEST_BLOCK" && {
    grep -qE '/?web/'  <<<"$JEST_BLOCK" && IGNORE_HAS_WEB=1  || IGNORE_HAS_WEB=0
    grep -qE '/?apps/' <<<"$JEST_BLOCK" && IGNORE_HAS_APPS=1 || IGNORE_HAS_APPS=0
    grep -qE '/?src/'  <<<"$JEST_BLOCK" && IGNORE_HAS_SRC=1  || IGNORE_HAS_SRC=0
  } || { IGNORE_HAS_WEB=0; IGNORE_HAS_APPS=0; IGNORE_HAS_SRC=0; }
  grep -qE '"roots"[[:space:]]*:' <<<"$JEST_BLOCK" && ROOTS_SCOPED=1 || ROOTS_SCOPED=0
  TESTMATCH_TOTAL=1
  grep -qE '\*\*/tests/\*\*' <<<"$JEST_BLOCK" && TESTMATCH_BARE_GLOB=1 || TESTMATCH_BARE_GLOB=0
  # tests/-anchored only counts if a tests/ entry exists AND no bare glob present.
  if grep -qE '"\.?/?tests/' <<<"$JEST_BLOCK" && [ "$TESTMATCH_BARE_GLOB" -eq 0 ]; then
    TESTMATCH_TESTS_ANCHORED=1
  else
    TESTMATCH_TESTS_ANCHORED=0
  fi
fi

assert "jest.testPathIgnorePatterns contains web/"  "[ \"\${IGNORE_HAS_WEB:-0}\"  -gt 0 ]"
assert "jest.testPathIgnorePatterns contains apps/" "[ \"\${IGNORE_HAS_APPS:-0}\" -gt 0 ]"
assert "jest.testPathIgnorePatterns contains src/"  "[ \"\${IGNORE_HAS_SRC:-0}\"  -gt 0 ]"
# Discovery scoped to tests/ : roots includes tests/  OR  testMatch is fully
# tests/-anchored — AND the bare repo-wide '**/tests/**' glob is gone.
assert "jest discovery is scoped to tests/ (roots tests/ OR testMatch all tests/-anchored)" \
  "[ \"\${ROOTS_SCOPED:-0}\" -gt 0 ] || { [ \"\${TESTMATCH_TOTAL:-0}\" -gt 0 ] && [ \"\${TESTMATCH_TESTS_ANCHORED:-0}\" -eq \"\${TESTMATCH_TOTAL:-0}\" ]; }"
assert "jest.testMatch has no bare repo-wide '**/tests/**' glob" \
  "[ \"\${TESTMATCH_BARE_GLOB:-0}\" -eq 0 ]"

# ── 3. POLICY RATIFIED + WORKSPACE DOCUMENTED ────────────────────────────────
echo ""
echo "3. file-structure-policy.md is ratified and documents the product workspace"
assert "policy has NO 'Effective Date: TBD' (ratified)" \
  "! grep -qE 'Effective Date.*:.*TBD' \"\$POLICY\""
assert "policy documents the product workspace (mentions web/)"  "grep -qE '(^|[^A-Za-z])web/'  \"\$POLICY\""
assert "policy documents the product workspace (mentions apps/)" "grep -qE '(^|[^A-Za-z])apps/' \"\$POLICY\""

# ── 4. ENTRY DOCS SURFACE THE BOUNDARY ───────────────────────────────────────
echo ""
echo "4. Entry docs surface the product-workspace location"
assert "CLAUDE.md surfaces the product workspace (web/ or 'product workspace')" \
  "grep -qiE 'web/|product workspace' \"\$CLAUDE\""
# At least one of README.md / START_HERE.md must surface it too.
README_HIT=0
[ -f "$README" ]     && grep -qiE 'web/|product workspace' "$README"     && README_HIT=1
START_HIT=0
[ -f "$START_HERE" ] && grep -qiE 'web/|product workspace' "$START_HERE" && START_HIT=1
assert "README.md or START_HERE.md surfaces the product workspace" \
  "[ \"\$README_HIT\" -eq 1 ] || [ \"\$START_HIT\" -eq 1 ]"

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
