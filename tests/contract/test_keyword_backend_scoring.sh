#!/usr/bin/env bash
# Contract Tests: keyword-backend.sh query-coverage scoring
#
# Bug: _keyword_search_dir (plugins/loom-memory/lib/keyword-backend.sh)
# scored a file by how many LINES matched a SINGLE keyword, divided by 10,
# capped at 1.0. A common word occurring 10+ times in a long doc therefore
# scored 1.0 on its own, regardless of how many OTHER query keywords the file
# actually matched — the 0.7 MEMORY_CONFIDENCE_THRESHOLD filtered nothing.
#
# Fix: score by query COVERAGE — distinct query keywords matched / total
# query keywords — plus a small density bonus that is bounded so it can
# never lift a single-keyword hit over the threshold on its own.
#
# This suite uses synthetic fixture files in a temp dir (never real repo
# docs), and calls the backend's internal `_keyword_search` directly so it
# is independent of backend_search's hardcoded repo-relative search paths.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0

assert() {
  TOTAL=$((TOTAL + 1))
  local desc="$1"; local condition="$2"
  if eval "$condition"; then
    echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KEYWORD_BACKEND="$REPO_ROOT/plugins/loom-memory/lib/keyword-backend.sh"

FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/keyword-backend-fixture.XXXXXX")"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# Six synthetic, non-stopword, alnum-only keywords chosen to never collide
# with real repo content.
QUERY_KEYWORDS="zeltrun voxbari plindak strovek maquelt jindaro"

# noisy.md: matches ONE keyword (zeltrun) at HIGH frequency (15 lines) and
# NONE of the other five. Under the old per-keyword scoring this alone
# reached score 1.0 (15 >= 10 cap). Under coverage scoring it must stay well
# under the 0.7 threshold: 1/6 keywords matched.
{
  for i in $(seq 1 15); do
    echo "line $i mentions zeltrun in passing, nothing else relevant here."
  done
} > "$FIXTURE_DIR/noisy.md"

# relevant.md: matches FIVE of the six query keywords once each (not
# jindaro). This must score >= 0.7 — proving the fix doesn't just suppress
# everything.
cat > "$FIXTURE_DIR/relevant.md" <<'EOF'
This document discusses voxbari at length.
It also covers plindak in some detail.
Later sections mention strovek as a related idea.
Finally maquelt closes out the discussion.
And one more pass to restate zeltrun for good measure.
EOF

# absent.md: matches NONE of the query keywords — must never appear.
cat > "$FIXTURE_DIR/absent.md" <<'EOF'
This file is about completely unrelated subject matter.
EOF

# heavy4of6.md: matches FOUR of the six query keywords (zeltrun voxbari
# plindak strovek — not maquelt or jindaro) at HIGH frequency (15 occurrences
# each). This is the exact regression scenario: coverage = 4/6 = 0.6667, and
# under the old scoring the density bonus (capped at 0.05) pushed the total
# to 0.7167 — crossing the 0.7 threshold on density alone, even though 4/6
# coverage should NOT clear it (0.7 sits strictly between the 4/6 and 5/6
# coverage steps). Emitted score must be coverage alone (0.6667), so this
# must stay < 0.7 regardless of how many times each matched keyword recurs.
{
  for i in $(seq 1 15); do
    echo "line $i repeats zeltrun voxbari plindak strovek heavily, nothing else."
  done
} > "$FIXTURE_DIR/heavy4of6.md"

echo "═══ keyword-backend.sh query-coverage scoring ═══"
echo ""
echo "Fixture: $FIXTURE_DIR"
echo ""

assert "keyword-backend.sh exists" "[ -f '$KEYWORD_BACKEND' ]"

# shellcheck disable=SC1090
source "$KEYWORD_BACKEND"

assert "_keyword_search is defined (internal search entrypoint)" \
  "declare -f _keyword_search >/dev/null 2>&1"

RESULTS=$(_keyword_search "$FIXTURE_DIR" "$QUERY_KEYWORDS" 10 2>/dev/null || true)

assert "search returns at least one result" "[ -n \"\$RESULTS\" ]"

NOISY_LINE=$(printf '%s\n' "$RESULTS" | grep "noisy.md" || true)
RELEVANT_LINE=$(printf '%s\n' "$RESULTS" | grep "relevant.md" || true)
ABSENT_LINE=$(printf '%s\n' "$RESULTS" | grep "absent.md" || true)
HEAVY4_LINE=$(printf '%s\n' "$RESULTS" | grep "heavy4of6.md" || true)

assert "noisy.md (1/6 keywords, 15 occurrences) is present in results" "[ -n '$NOISY_LINE' ]"
assert "relevant.md (5/6 keywords) is present in results" "[ -n '$RELEVANT_LINE' ]"
assert "absent.md (0/6 keywords) is absent from results" "[ -z '$ABSENT_LINE' ]"
assert "heavy4of6.md (4/6 keywords, high frequency) is present in results" "[ -n '$HEAVY4_LINE' ]"

if [ -n "$NOISY_LINE" ]; then
  NOISY_SCORE=$(printf '%s' "$NOISY_LINE" | cut -f1)
  echo "     ↳ noisy.md score: $NOISY_SCORE"
  NOISY_BELOW=$(awk "BEGIN { print ($NOISY_SCORE < 0.7) ? 1 : 0 }")
  assert "THE BUG: noisy.md (one common keyword, high frequency) scores < 0.7" \
    "[ '$NOISY_BELOW' -eq 1 ]"
fi

if [ -n "$RELEVANT_LINE" ]; then
  RELEVANT_SCORE=$(printf '%s' "$RELEVANT_LINE" | cut -f1)
  echo "     ↳ relevant.md score: $RELEVANT_SCORE"
  RELEVANT_ABOVE=$(awk "BEGIN { print ($RELEVANT_SCORE >= 0.7) ? 1 : 0 }")
  assert "relevant.md (5 of 6 keywords matched) scores >= 0.7 (retrieval still works)" \
    "[ '$RELEVANT_ABOVE' -eq 1 ]"
fi

if [ -n "$HEAVY4_LINE" ]; then
  HEAVY4_SCORE=$(printf '%s' "$HEAVY4_LINE" | cut -f1)
  echo "     ↳ heavy4of6.md score: $HEAVY4_SCORE"
  HEAVY4_BELOW=$(awk "BEGIN { print ($HEAVY4_SCORE < 0.7) ? 1 : 0 }")
  assert "THE BUG: heavy4of6.md (4/6 coverage, high frequency) scores < 0.7 (density cannot bridge the coverage-step gap)" \
    "[ '$HEAVY4_BELOW' -eq 1 ]"
fi

# ── Low-keyword-count queries: what is sane for 1-2 keywords ──
echo ""
echo "Low-keyword-count query sanity"

SINGLE_FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/keyword-backend-single.XXXXXX")"
trap 'rm -rf "$FIXTURE_DIR" "$SINGLE_FIXTURE_DIR"' EXIT
echo "this file mentions grendolix exactly once here." > "$SINGLE_FIXTURE_DIR/hit.md"
echo "this file has nothing to do with the query at all." > "$SINGLE_FIXTURE_DIR/miss.md"

SINGLE_RESULTS=$(_keyword_search "$SINGLE_FIXTURE_DIR" "grendolix" 10 2>/dev/null || true)
SINGLE_HIT_LINE=$(printf '%s\n' "$SINGLE_RESULTS" | grep "hit.md" || true)
if [ -n "$SINGLE_HIT_LINE" ]; then
  SINGLE_SCORE=$(printf '%s' "$SINGLE_HIT_LINE" | cut -f1)
  echo "     ↳ single-keyword query, one match: score $SINGLE_SCORE"
  SINGLE_FULL=$(awk "BEGIN { print ($SINGLE_SCORE >= 0.99) ? 1 : 0 }")
  assert "single-keyword query: a real match scores ~1.0 (full coverage of the query)" \
    "[ '$SINGLE_FULL' -eq 1 ]"
else
  assert "single-keyword query: hit.md must appear in results (got empty)" "false"
fi

TWO_KW_DIR="$(mktemp -d "${TMPDIR:-/tmp}/keyword-backend-twokw.XXXXXX")"
trap 'rm -rf "$FIXTURE_DIR" "$SINGLE_FIXTURE_DIR" "$TWO_KW_DIR"' EXIT
echo "this file mentions korvellan many many many many many many many many many many many times." > "$TWO_KW_DIR/half.md"

TWO_RESULTS=$(_keyword_search "$TWO_KW_DIR" "korvellan pazuthri" 10 2>/dev/null || true)
HALF_LINE=$(printf '%s\n' "$TWO_RESULTS" | grep "half.md" || true)
if [ -n "$HALF_LINE" ]; then
  HALF_SCORE=$(printf '%s' "$HALF_LINE" | cut -f1)
  echo "     ↳ two-keyword query, one of two matched (high frequency): score $HALF_SCORE"
  HALF_BELOW=$(awk "BEGIN { print ($HALF_SCORE < 0.7) ? 1 : 0 }")
  assert "two-keyword query: matching only 1 of 2 keywords stays below 0.7 no matter the frequency" \
    "[ '$HALF_BELOW' -eq 1 ]"
else
  assert "two-keyword query: half.md must appear in results (got empty)" "false"
fi

echo ""
echo "═══ Results: $PASS/$TOTAL passed, $FAIL failed ═══"
[ "$FAIL" -eq 0 ]
