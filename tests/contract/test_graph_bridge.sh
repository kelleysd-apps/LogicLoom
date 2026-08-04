#!/usr/bin/env bash
# Contract Tests: project knowledge-graph bridge (Phase 1 — deterministic, docs-first)
#
# Encodes the executable spec for the graph-bridge layer. Phase 1 is
# DETERMINISTIC + fail-open: a ~jq/rg generator harvests edges already in the
# markdown corpus into graph-bridge.jsonl (Anthropic memory-server shape), and a
# warn-only linter flags dangling references. Neither ever blocks — the graph is
# advisory defense-in-depth, not a gate.
#
#   (a) BUILDER EXISTS + EMITS VALID JSONL — build-graph-bridge.sh is present and
#       executable; run against a TEMP fixture corpus (never the real repo) and
#       assert exit 0, non-empty output, every line valid JSON, and >=1 entity +
#       >=1 relation.
#   (b) LINTER WARNS BUT NEVER FAILS — lint-graph.sh over the fixture output warns
#       about a dangling `covers:` (grep 'WARN' + the missing path) AND exits 0
#       (fail-open — the linter is advisory, it can never break a build).
#   (c) SHIPPED SEED IS VALID — if .logic-loom/graph/graph-bridge.jsonl is present,
#       every line parses as JSON (a corrupt committed seed would poison /graph).
#
# Both scripts accept an OPTIONAL corpus-root argument — the test passes a tmpdir
# so it never mutates the real repo. jq is required to validate JSONL; if jq is
# absent the JSONL-shape checks are skipped (informational), not failed.
#
# This test is RED until the graph scripts land — that is expected. It is meant
# for the user/CI to run; it is read-only against the repo (writes only to a
# tmpdir that is always cleaned up on exit).
set -euo pipefail

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

BUILDER=".logic-loom/scripts/bash/build-graph-bridge.sh"
LINTER=".logic-loom/scripts/bash/lint-graph.sh"
SEED=".logic-loom/graph/graph-bridge.jsonl"

# jq is used to validate JSONL. Track availability; degrade gracefully if absent.
HAVE_JQ=0; command -v jq >/dev/null 2>&1 && HAVE_JQ=1

# ── Fixture corpus in a tmpdir (never touches the real repo) ──────────────────
# trap guarantees cleanup even on set -e abort.
TMPDIR_FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/graph-bridge-test.XXXXXX")"
cleanup() { rm -rf "$TMPDIR_FIXTURE" 2>/dev/null || true; }
trap cleanup EXIT

# The corpus root the scripts will harvest. Give it a shape close to the real
# corpus (a .docs/-style note dir) so relative-path resolution is exercised.
CORPUS="$TMPDIR_FIXTURE/corpus"
mkdir -p "$CORPUS/.docs/architecture" "$CORPUS/src"

# A real file that lives INSIDE the corpus, so an inline backtick mention of it
# resolves to a code-path node (the builder tests the mention target against the
# corpus root, not the real repo).
REAL_FILE="src/real-module.ts"
printf 'export const x = 1;\n' > "$CORPUS/$REAL_FILE"

# Note 1 — DANGLING covers: (frontmatter points at a file that does NOT exist in
# the corpus). The linter must warn about this and still exit 0.
DANGLING_PATH="nonexistent/path.ts"
cat > "$CORPUS/.docs/architecture/decision-dangling.md" <<EOF
---
covers: [$DANGLING_PATH]
---
# Dangling Decision
This note covers a module that no longer exists — the linter must warn.
EOF

# Note 2 — VALID inline backtick mention of a real (corpus-local) file → a
# code-path node + a mentions edge.
cat > "$CORPUS/.docs/architecture/mentions-real.md" <<EOF
# Real Mention
This note mentions \`$REAL_FILE\` inline, which resolves to a code-path node.
EOF

# Note 3 — a [[wikilink]] to Note 2 (a links-to edge inside the corpus).
cat > "$CORPUS/.docs/architecture/links-out.md" <<EOF
# Links Out
See [[mentions-real]] for the real-file mention.
EOF

BRIDGE_OUT="$TMPDIR_FIXTURE/graph-bridge.jsonl"

echo "═══ Project Knowledge-Graph Bridge (Phase 1) ═══"
echo ""

# ── (a) BUILDER EXISTS + EMITS VALID JSONL ───────────────────────────────────
echo "(a) build-graph-bridge.sh exists, is executable, and emits valid JSONL"
assert "build-graph-bridge.sh exists"        "[ -f \"\$BUILDER\" ]"
assert "build-graph-bridge.sh is executable" "[ -x \"\$BUILDER\" ]"

BUILD_RC=127
if [ -x "$BUILDER" ]; then
  # Scripts accept an optional corpus-root arg; capture stdout as the JSONL.
  # Never let a non-zero build abort the whole test suite (set -e): capture rc.
  set +e
  bash "$BUILDER" "$CORPUS" > "$BRIDGE_OUT" 2>/dev/null
  BUILD_RC=$?
  set -e
fi
assert "build-graph-bridge.sh exits 0 on the fixture corpus" "[ \"\$BUILD_RC\" -eq 0 ]"
assert "emitted graph-bridge.jsonl is non-empty" "[ -s \"\$BRIDGE_OUT\" ]"

# Every line must be valid JSON, and there must be >=1 entity and >=1 relation.
if [ "$HAVE_JQ" -eq 1 ] && [ -s "$BRIDGE_OUT" ]; then
  set +e
  # jq -e over each line: rc!=0 on the first line that fails to parse.
  BAD_LINES="$(grep -cvE '^[[:space:]]*$' "$BRIDGE_OUT")"; : "$BAD_LINES"
  JSONL_OK=1
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    printf '%s' "$line" | jq -e . >/dev/null 2>&1 || { JSONL_OK=0; break; }
  done < "$BRIDGE_OUT"
  ENTITY_CT="$(jq -rs '[.[] | select(.type=="entity")] | length' "$BRIDGE_OUT" 2>/dev/null || echo 0)"
  RELATION_CT="$(jq -rs '[.[] | select(.type=="relation")] | length' "$BRIDGE_OUT" 2>/dev/null || echo 0)"
  set -e
  assert "every emitted line is valid JSON (valid JSONL)" "[ \"\${JSONL_OK:-0}\" -eq 1 ]"
  assert "emits >=1 entity object"   "[ \"\${ENTITY_CT:-0}\"   -ge 1 ]"
  assert "emits >=1 relation object" "[ \"\${RELATION_CT:-0}\" -ge 1 ]"
else
  echo "  ⚠ SKIP: jq absent or no output — JSONL-shape checks skipped (informational)"
fi

# ── (b) LINTER WARNS BUT NEVER FAILS ─────────────────────────────────────────
echo ""
echo "(b) lint-graph.sh warns about the dangling covers: and still exits 0 (fail-open)"
assert "lint-graph.sh exists"        "[ -f \"\$LINTER\" ]"
assert "lint-graph.sh is executable" "[ -x \"\$LINTER\" ]"

LINT_RC=127; LINT_OUT="$TMPDIR_FIXTURE/lint.out"
if [ -x "$LINTER" ]; then
  set +e
  # Contract: lint-graph.sh [JSONL] [--root REPO_ROOT]. Pass the fixture corpus
  # as --root so it tests covers/links-to targets against the fixture, never the
  # real repo (a covers path 'nonexistent/path.ts' must be missing *in the corpus*).
  bash "$LINTER" "$BRIDGE_OUT" --root "$CORPUS" > "$LINT_OUT" 2>&1
  LINT_RC=$?
  set -e
else
  : > "$LINT_OUT"
fi
# Fail-open is the whole point: the linter must NEVER return non-zero.
assert "lint-graph.sh exits 0 even with a dangling covers: (fail-open)" "[ \"\$LINT_RC\" -eq 0 ]"
assert "lint output contains a WARN"                     "grep -q 'WARN' \"\$LINT_OUT\""
assert "lint output names the missing path ($DANGLING_PATH)" "grep -qF '$DANGLING_PATH' \"\$LINT_OUT\""

# ── (c) SHIPPED SEED IS VALID JSONL (if present) ─────────────────────────────
echo ""
echo "(c) shipped seed .logic-loom/graph/graph-bridge.jsonl is valid JSONL (if present)"
if [ -f "$SEED" ]; then
  if [ "$HAVE_JQ" -eq 1 ]; then
    set +e
    SEED_OK=1
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      printf '%s' "$line" | jq -e . >/dev/null 2>&1 || { SEED_OK=0; break; }
    done < "$SEED"
    set -e
    assert "shipped seed is valid JSONL (every line parses)" "[ \"\${SEED_OK:-0}\" -eq 1 ]"
  else
    echo "  ⚠ SKIP: jq absent — seed JSONL validation skipped (informational)"
  fi
else
  echo "  ⚠ SKIP: no shipped seed at $SEED — nothing to validate (not a failure)"
fi

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
