#!/usr/bin/env bash
# Contract Tests: Memory Context Search
# Validates memory search, tier priority, filtering, and timeout behavior
# Feature: 005-agent-architecture-refactor
set -euo pipefail

# Operations-log isolation: the scripts this suite drives source common.sh /
# logging.sh, which otherwise append to the shared
# .logic-loom/logs/operations/ file. LOOM_LOG_DIR redirects that (same idiom as
# LOOM_CHECKPOINT_DIR in .logic-loom/tests/test-git-safety.sh), exported so
# subprocesses inherit it, and set before anything is sourced because logging.sh
# resolves LOG_FILE once at source time.
LOOM_LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/loom-logs.XXXXXX")"
export LOOM_LOG_DIR
trap 'rm -rf "$LOOM_LOG_DIR"' EXIT

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

# Safe replacement for the `grep -c ... || echo "0"` antipattern.
#
# `grep -c` PRINTS "0" and EXITS 1 when there are no matches, so `|| echo "0"`
# appends a SECOND line: the variable becomes the two-line string "0\n0" and
# `[ "0\n0" -ge 1 ]` dies with "integer expression expected". A legitimate
# zero-match then looks like a crash instead of a clean failure.
# Guard the exit status instead and sanitize to a single-line integer.
# Usage: count_matches <pattern> [file]   (reads stdin when no file is given)
count_matches() {
  local n
  n=$(grep -c "$@" 2>/dev/null || true)
  n=$(tr -dc '0-9\n' <<< "$n" | sed -n '1p')
  [ -n "$n" ] || n=0
  printf '%s' "$n"
}

MEMORY_SEARCH="plugins/loom-memory/scripts/memory-search.sh"
MEMORY_LOG="plugins/loom-memory/scripts/memory-log.sh"
MEMORY_CONF="plugins/loom-memory/config/memory.conf"

echo "═══ Memory Context Search Contract Tests ═══"
echo ""

# ── Plugin Infrastructure Tests ──
echo "Plugin infrastructure"
assert "loom-memory plugin.json exists" "[ -f plugins/loom-memory/.claude-plugin/plugin.json ]"
assert "loom-memory plugin.json is valid JSON" \
  "python3 -c 'import json; json.load(open(\"plugins/loom-memory/.claude-plugin/plugin.json\"))'"
assert "memory.conf exists" "[ -f $MEMORY_CONF ]"
assert "memory-search.sh exists" "[ -f $MEMORY_SEARCH ]"
assert "memory-search.sh is executable" "[ -x $MEMORY_SEARCH ]"
assert "memory-log.sh exists" "[ -f $MEMORY_LOG ]"
assert "memory-log.sh is executable" "[ -x $MEMORY_LOG ]"
assert "context-injection skill exists" \
  "[ -f plugins/loom-memory/skills/context-injection/SKILL.md ]"
assert "memory-context-agent exists as project agent (LOOM-0052)" \
  "[ -f .claude/agents/memory-context-agent.md ]"

# ── Configuration Tests ──
echo ""
echo "Memory configuration"
assert "Config has MEMORY_ENABLED" "grep -q 'MEMORY_ENABLED' $MEMORY_CONF"
assert "Config has MEMORY_TIMEOUT_MS" "grep -q 'MEMORY_TIMEOUT_MS' $MEMORY_CONF"
assert "Config has MEMORY_MAX_TOKENS" "grep -q 'MEMORY_MAX_TOKENS' $MEMORY_CONF"
assert "Config has MEMORY_CONFIDENCE_THRESHOLD" "grep -q 'MEMORY_CONFIDENCE_THRESHOLD' $MEMORY_CONF"

# ── Memory Search Output Tests ──
echo ""
echo "Memory search behavior"

# Test with a query that should find something (constitution is always there)
SEARCH_OUTPUT=$(bash "$MEMORY_SEARCH" "constitution principles governance" 2>/dev/null || echo "")
SEARCH_OUTPUT_LEN=${#SEARCH_OUTPUT}
assert "Search returns output for known content" "[ $SEARCH_OUTPUT_LEN -gt 0 ]"

# Test output format
if [ -n "$SEARCH_OUTPUT" ]; then
  HAS_HEADER=$(sed -n '1p' <<< "$SEARCH_OUTPUT" | count_matches "MEMORY CONTEXT")
  assert "Search output has MEMORY CONTEXT header" "[ '$HAS_HEADER' -ge 1 ]"
  if [ "$HAS_HEADER" -lt 1 ]; then
    echo "     ↳ diagnostic: first 5 lines of search output:"
    sed -n '1,5p' <<< "$SEARCH_OUTPUT" | sed 's/^/       | /'
  fi
fi

# Test with gibberish query — should return empty/minimal
EMPTY_OUTPUT=$(bash "$MEMORY_SEARCH" "xyzzy98765nonexistenttermfoobar" 2>/dev/null || echo "")
NO_RESULTS=$(echo "$EMPTY_OUTPUT" | count_matches "No relevant context found")
assert "Search returns no-results message for gibberish query" "[ '$NO_RESULTS' -ge 1 ] || [ -z '$EMPTY_OUTPUT' ]"

# ── Timeout Tests ──
echo ""
echo "Timeout and error handling"
# Search should complete within 5 seconds
START=$(date +%s)
bash "$MEMORY_SEARCH" "test query" >/dev/null 2>&1 || true
END=$(date +%s)
DURATION=$((END - START))
assert "Memory search completes within 5 seconds" "[ $DURATION -le 5 ]"

# ── Memory v2.0 Backend Interface Tests ──
echo ""
echo "Memory v2.0 backend interface"
assert "backend-interface.sh exists" "[ -f plugins/loom-memory/lib/backend-interface.sh ]"
assert "backend-interface.sh is executable" "[ -x plugins/loom-memory/lib/backend-interface.sh ]"
assert "keyword-backend.sh exists" "[ -f plugins/loom-memory/lib/keyword-backend.sh ]"
assert "keyword-backend.sh is executable" "[ -x plugins/loom-memory/lib/keyword-backend.sh ]"
assert "memory-v2.conf exists" "[ -f plugins/loom-memory/config/memory-v2.conf ]"
assert "memory-v2.conf has MEMORY_BACKEND setting" "grep -q 'MEMORY_BACKEND' plugins/loom-memory/config/memory-v2.conf"
assert "memory-v2.conf defaults to keyword backend" "grep -q 'MEMORY_BACKEND=keyword' plugins/loom-memory/config/memory-v2.conf"
assert "memory-v2.conf has hybrid weights" "grep -q 'VECTOR_WEIGHT' plugins/loom-memory/config/memory-v2.conf"

# Test keyword backend health check
KB_HEALTH=$(bash -c 'source plugins/loom-memory/lib/keyword-backend.sh && backend_health_check' 2>/dev/null || echo "")
KB_HEALTH_LEN=${#KB_HEALTH}
assert "Keyword backend health check returns output" "[ $KB_HEALTH_LEN -gt 0 ]"

# Test keyword backend search
KB_SEARCH=$(bash -c 'source plugins/loom-memory/lib/keyword-backend.sh && backend_search "constitution principles" 5 3000 session' 2>/dev/null || echo "")
KB_SEARCH_LEN=${#KB_SEARCH}
assert "Keyword backend search returns results for known content" "[ $KB_SEARCH_LEN -gt 0 ]"

# Test backend interface has required function stubs
assert "Interface defines backend_search" "grep -q 'backend_search()' plugins/loom-memory/lib/backend-interface.sh"
assert "Interface defines backend_index" "grep -q 'backend_index()' plugins/loom-memory/lib/backend-interface.sh"
assert "Interface defines backend_health_check" "grep -q 'backend_health_check()' plugins/loom-memory/lib/backend-interface.sh"
assert "Interface defines format_search_result helper" "grep -q 'format_search_result()' plugins/loom-memory/lib/backend-interface.sh"

# ── Skill-Brief Extraction Tests ──
echo ""
echo "Domain-brief registry (v3.1.0: domains collapsed into governance core)"
assert "get_domain_brief function exists in common.sh" \
  "grep -q 'get_domain_brief()' .logic-loom/scripts/bash/common.sh"

# Resolve governance core plugin dir (loom-governance after rename; sdd- before)
GOV_DIR="plugins/loom-governance"; [ -d "plugins/loom-governance" ] && GOV_DIR="plugins/loom-governance"

# get_domain_brief returns content for a registered domain
BRIEF_OUTPUT=$(bash -c 'source .logic-loom/scripts/bash/common.sh 2>/dev/null; get_domain_brief "backend"' 2>/dev/null || echo "")
BRIEF_LEN=${#BRIEF_OUTPUT}
assert "get_domain_brief returns content for backend domain" "[ $BRIEF_LEN -gt 20 ]"

# get_domain_brief returns empty for an unknown domain
EMPTY_BRIEF=$(bash -c 'source .logic-loom/scripts/bash/common.sh 2>/dev/null; get_domain_brief "nonexistent"' 2>/dev/null || echo "")
EMPTY_BRIEF_LEN=${#EMPTY_BRIEF}
assert "get_domain_brief returns empty for unknown domain" "[ $EMPTY_BRIEF_LEN -le 1 ]"

# ── Domain Plugin Removal Verification ──
echo ""
echo "Domain plugin removal verification"
DOMAIN_PLUGIN_COUNT=0
for d in frontend backend database security testing performance devops; do
  [ -d "plugins/sdd-domain-${d}" ] && DOMAIN_PLUGIN_COUNT=$((DOMAIN_PLUGIN_COUNT + 1))
done
assert "No sdd-domain-* plugins remain (found $DOMAIN_PLUGIN_COUNT)" "[ '$DOMAIN_PLUGIN_COUNT' -eq 0 ]"

# Verify each domain has a registry brief with a Task Brief section
for domain in frontend backend database security testing performance devops; do
  BRIEF_FILE="$GOV_DIR/domain-briefs/${domain}.md"
  assert "${domain} registry brief exists" "[ -f '$BRIEF_FILE' ]"
  if [ -f "$BRIEF_FILE" ]; then
    HAS_BRIEF=$(count_matches '## Task Brief' "$BRIEF_FILE")
    assert "${domain} brief has Task Brief section" "[ '$HAS_BRIEF' -ge 1 ]"
  fi
done

# ── Stack-neutral shipped briefs (LOOM-0053) ──
echo ""
echo "Stack-neutral shipped domain briefs"
for domain in frontend backend database security testing performance devops; do
  BRIEF_FILE="$GOV_DIR/domain-briefs/${domain}.md"
  if [ -f "$BRIEF_FILE" ]; then
    NAMED=$(count_matches -Eio 'React|Next\.js|Vue\.js|Angular|\bJest\b|Vitest|Cypress|Playwright' "$BRIEF_FILE")
    assert "${domain} brief names no React/Next/Vue/Angular/Jest/Vitest/Cypress/Playwright" "[ '$NAMED' -eq 0 ]"
  fi
done

# ── Domain-brief project overlay support (LOOM-0053) ──
echo ""
echo "Domain-brief project overlay (get_domain_brief)"

OVERLAY_DIR=".logic-loom/domain-briefs"
assert "overlay directory exists" "[ -d '$OVERLAY_DIR' ]"
assert "overlay README exists" "[ -f '$OVERLAY_DIR/README.md' ]"
assert "overlay .gitkeep exists" "[ -f '$OVERLAY_DIR/.gitkeep' ]"

# Absent overlay -> output is byte-identical to the shipped-only path.
# Computed two ways: once via get_domain_brief itself (compared again below,
# after exercising the overlay path, to catch state leaking across calls), and
# once via a DIRECT, independent awk extraction of the shipped brief (so a
# mutation that always appends something — even with no overlay file present —
# is caught here rather than passing by comparing two runs of the same bug).
NO_OVERLAY_OUTPUT=$(bash -c 'source .logic-loom/scripts/bash/common.sh 2>/dev/null; get_domain_brief "backend"' 2>/dev/null || echo "")
DIRECT_SHIPPED_ONLY=$(awk '/^## Task Brief/{f=1;next} f' "$GOV_DIR/domain-briefs/backend.md")
assert "absent overlay -> output matches a direct extraction of the shipped brief alone" \
  "[ \"\$NO_OVERLAY_OUTPUT\" = \"\$DIRECT_SHIPPED_ONLY\" ]"

# Present overlay -> its content is appended AFTER the shipped content, and
# get_domain_brief still returns 0.
TMP_OVERLAY_MARKER="__LOOM_0053_OVERLAY_MARKER__"
TMP_OVERLAY_FILE="$OVERLAY_DIR/backend.md"
OVERLAY_PRE_EXISTED=false
[ -f "$TMP_OVERLAY_FILE" ] && OVERLAY_PRE_EXISTED=true
if [ "$OVERLAY_PRE_EXISTED" = false ]; then
  printf '## This project\n\n- %s\n' "$TMP_OVERLAY_MARKER" > "$TMP_OVERLAY_FILE"

  WITH_OVERLAY_OUTPUT=$(bash -c 'source .logic-loom/scripts/bash/common.sh 2>/dev/null; get_domain_brief "backend"' 2>/dev/null || echo "")
  WITH_OVERLAY_RC=0
  bash -c 'source .logic-loom/scripts/bash/common.sh 2>/dev/null; get_domain_brief "backend" >/dev/null 2>&1' || WITH_OVERLAY_RC=$?

  assert "overlay content appears in get_domain_brief output" \
    "echo \"\$WITH_OVERLAY_OUTPUT\" | grep -q '$TMP_OVERLAY_MARKER'"

  SHIPPED_POS=$( (printf '%s\n' "$WITH_OVERLAY_OUTPUT" | grep -n 'File Ownership' || true) | head -1 | cut -d: -f1)
  OVERLAY_POS=$( (printf '%s\n' "$WITH_OVERLAY_OUTPUT" | grep -n "$TMP_OVERLAY_MARKER" || true) | head -1 | cut -d: -f1)
  assert "overlay content is appended AFTER the shipped content" \
    "[ -n '$SHIPPED_POS' ] && [ -n '$OVERLAY_POS' ] && [ '$OVERLAY_POS' -gt '$SHIPPED_POS' ]"

  assert "get_domain_brief still returns 0 with an overlay present" "[ '$WITH_OVERLAY_RC' -eq 0 ]"

  rm -f "$TMP_OVERLAY_FILE"
else
  echo "  ⏭  SKIP: $TMP_OVERLAY_FILE already exists on disk — refusing to overwrite it for this test"
fi

# Absent-overlay behavior is unchanged by the feature (byte-identical).
NO_OVERLAY_OUTPUT_AFTER=$(bash -c 'source .logic-loom/scripts/bash/common.sh 2>/dev/null; get_domain_brief "backend"' 2>/dev/null || echo "")
assert "absent overlay -> get_domain_brief output is byte-identical to before" \
  "[ \"\$NO_OVERLAY_OUTPUT\" = \"\$NO_OVERLAY_OUTPUT_AFTER\" ]"

# Overlay for a domain with NO shipped brief -> still returns 0, emits overlay only.
NOSHIP_DOMAIN="__loom0053_no_shipped_brief__"
NOSHIP_OVERLAY_FILE="$OVERLAY_DIR/${NOSHIP_DOMAIN}.md"
printf '## This project\n\n- %s\n' "$TMP_OVERLAY_MARKER" > "$NOSHIP_OVERLAY_FILE"
NOSHIP_OUTPUT=$(bash -c "source .logic-loom/scripts/bash/common.sh 2>/dev/null; get_domain_brief '$NOSHIP_DOMAIN'" 2>/dev/null || echo "")
NOSHIP_RC=0
bash -c "source .logic-loom/scripts/bash/common.sh 2>/dev/null; get_domain_brief '$NOSHIP_DOMAIN' >/dev/null 2>&1" || NOSHIP_RC=$?
assert "overlay-only domain (no shipped brief) still returns 0" "[ '$NOSHIP_RC' -eq 0 ]"
assert "overlay-only domain (no shipped brief) emits the overlay content" \
  "echo \"\$NOSHIP_OUTPUT\" | grep -q '$TMP_OVERLAY_MARKER'"
rm -f "$NOSHIP_OVERLAY_FILE"

# ── Manifest ships the overlay structure (LOOM-0053) ──
echo ""
echo "Adopt payload manifest ships the overlay structure"
ADOPT_MANIFEST="packaging/adopt/payload-manifest.txt"
if [ -f "$ADOPT_MANIFEST" ]; then
  # ASSERT THE OUTCOME, NOT THE MECHANISM. An earlier version of these two
  # assertions required a literal `include:` line per overlay file. Those lines
  # were added as "defensive" duplicates under the existing wholesale
  # `include: .logic-loom`, and they BROKE plan/apply reconciliation: the planner
  # counts UNITS, so a path named twice is predicted twice while the apply writes
  # it once (observed: plan 411 vs apply 407). Removing them fixed the count and
  # made these two assertions fail — a test that pinned the defect in place.
  #
  # What matters is that the overlay structure REACHES an adopter. The wholesale
  # include already does that. So: assert coverage, and assert that nobody
  # re-adds a redundant nested include.
  assert "the overlay directory is covered by an include (wholesale or explicit)" \
    "grep -qE '^include: \.logic-loom$' '$ADOPT_MANIFEST' || grep -qE '^include: \.logic-loom/domain-briefs' '$ADOPT_MANIFEST'"
  assert "no REDUNDANT nested include under the wholesale .logic-loom entry" \
    "! { grep -qE '^include: \.logic-loom$' '$ADOPT_MANIFEST' && grep -qE '^include: \.logic-loom/' '$ADOPT_MANIFEST'; }"
  assert "the overlay files exist to be shipped" \
    "[ -f .logic-loom/domain-briefs/README.md ] && [ -f .logic-loom/domain-briefs/.gitkeep ]"
else
  echo "  ⏭  SKIP: $ADOPT_MANIFEST absent (stripped/customer tree)"
fi
STRIP_MANIFEST=".logic-loom/scripts/bash/template-strip-manifest.txt"
assert "template-strip-manifest.txt does not remove .logic-loom/domain-briefs wholesale" \
  "! grep -Eq '^\.logic-loom/domain-briefs[[:space:]]*$' '$STRIP_MANIFEST'"

# ── Memory v2.0 Backend Implementations ──
echo ""
echo "Memory v2.0 backend implementations"
assert "bm25-search.sh exists" "[ -f plugins/loom-memory/lib/bm25-search.sh ]"
assert "bm25-search.sh is executable" "[ -x plugins/loom-memory/lib/bm25-search.sh ]"
assert "vector-search.sh exists" "[ -f plugins/loom-memory/lib/vector-search.sh ]"
assert "vector-search.sh is executable" "[ -x plugins/loom-memory/lib/vector-search.sh ]"
assert "hybrid-search.sh exists" "[ -f plugins/loom-memory/lib/hybrid-search.sh ]"
assert "hybrid-search.sh is executable" "[ -x plugins/loom-memory/lib/hybrid-search.sh ]"

# BM25 backend implements all interface functions
assert "BM25 implements backend_search" "grep -q 'backend_search()' plugins/loom-memory/lib/bm25-search.sh"
assert "BM25 implements backend_index" "grep -q 'backend_index()' plugins/loom-memory/lib/bm25-search.sh"
assert "BM25 implements backend_reindex_all" "grep -q 'backend_reindex_all()' plugins/loom-memory/lib/bm25-search.sh"
assert "BM25 implements backend_health_check" "grep -q 'backend_health_check()' plugins/loom-memory/lib/bm25-search.sh"

# Vector backend implements all interface functions
assert "Vector implements backend_search" "grep -q 'backend_search()' plugins/loom-memory/lib/vector-search.sh"
assert "Vector implements backend_index" "grep -q 'backend_index()' plugins/loom-memory/lib/vector-search.sh"
assert "Vector implements backend_reindex_all" "grep -q 'backend_reindex_all()' plugins/loom-memory/lib/vector-search.sh"
assert "Vector implements backend_health_check" "grep -q 'backend_health_check()' plugins/loom-memory/lib/vector-search.sh"

# Hybrid backend implements all interface functions
assert "Hybrid implements backend_search" "grep -q 'backend_search()' plugins/loom-memory/lib/hybrid-search.sh"
assert "Hybrid implements backend_index" "grep -q 'backend_index()' plugins/loom-memory/lib/hybrid-search.sh"
assert "Hybrid implements backend_reindex_all" "grep -q 'backend_reindex_all()' plugins/loom-memory/lib/hybrid-search.sh"
assert "Hybrid implements backend_health_check" "grep -q 'backend_health_check()' plugins/loom-memory/lib/hybrid-search.sh"

# ── Memory v2.0 Retention & Flush ──
echo ""
echo "Memory v2.0 retention and flush"
assert "retention.sh exists" "[ -f plugins/loom-memory/lib/retention.sh ]"
assert "retention.sh is executable" "[ -x plugins/loom-memory/lib/retention.sh ]"
assert "memory-flush.sh exists" "[ -f plugins/loom-memory/lib/memory-flush.sh ]"
assert "memory-flush.sh is executable" "[ -x plugins/loom-memory/lib/memory-flush.sh ]"
assert "retention.sh has retention_cleanup" "grep -q 'retention_cleanup()' plugins/loom-memory/lib/retention.sh"
assert "retention.sh has retention_lazy_check" "grep -q 'retention_lazy_check()' plugins/loom-memory/lib/retention.sh"
assert "retention.sh has retention_is_expired" "grep -q 'retention_is_expired()' plugins/loom-memory/lib/retention.sh"
assert "memory-flush.sh has memory_flush" "grep -q 'memory_flush()' plugins/loom-memory/lib/memory-flush.sh"
assert "memory-flush.sh has memory_flush_extract" "grep -q 'memory_flush_extract()' plugins/loom-memory/lib/memory-flush.sh"

# ── Memory Tier Directories ──
echo ""
echo "Memory tier directories"
assert "working directory exists" "[ -d plugins/loom-memory/working ]"
assert "working has .gitkeep" "[ -f plugins/loom-memory/working/.gitkeep ]"
assert "recall directory exists" "[ -d plugins/loom-memory/recall ]"
assert "recall has .gitkeep" "[ -f plugins/loom-memory/recall/.gitkeep ]"
assert "archival directory exists" "[ -d plugins/loom-memory/archival ]"
assert "archival has .gitkeep" "[ -f plugins/loom-memory/archival/.gitkeep ]"

# ── Configuration v2.0 ──
echo ""
echo "Memory v2.0 configuration"
assert "v2 config has retention settings" "grep -q 'WORKING_TTL' plugins/loom-memory/config/memory-v2.conf"
assert "v2 config has recall TTL" "grep -q 'RECALL_TTL' plugins/loom-memory/config/memory-v2.conf"
assert "v2 config has scope mode" "grep -q 'SCOPE_MODE' plugins/loom-memory/config/memory-v2.conf"
assert "v2 config has timeout setting" "grep -q 'MEMORY_TIMEOUT_MS' plugins/loom-memory/config/memory-v2.conf"
assert "v2 config has inject count" "grep -q 'INJECT_COUNT' plugins/loom-memory/config/memory-v2.conf"

# ── Memory-search.sh v2.0 Upgrade Verification ──
echo ""
echo "Memory-search.sh v2.0 upgrade"
assert "memory-search.sh references v2.0" "grep -q 'v2.0' plugins/loom-memory/scripts/memory-search.sh"
assert "memory-search.sh uses backend interface" "grep -q '_select_backend' plugins/loom-memory/scripts/memory-search.sh"
assert "memory-search.sh integrates retention" "grep -q 'retention' plugins/loom-memory/scripts/memory-search.sh"
assert "memory-search.sh supports multiple backends" "grep -q 'hybrid' plugins/loom-memory/scripts/memory-search.sh"

# Test v2.0 search output still has correct format
V2_OUTPUT=$(bash plugins/loom-memory/scripts/memory-search.sh "constitution governance" 2>/dev/null || echo "")
V2_LEN=${#V2_OUTPUT}
assert "v2.0 search returns output for known content" "[ $V2_LEN -gt 0 ]"
if [ -n "$V2_OUTPUT" ]; then
  V2_HEADER=$(sed -n '1p' <<< "$V2_OUTPUT" | count_matches "MEMORY CONTEXT")
  assert "v2.0 search output has MEMORY CONTEXT header" "[ '$V2_HEADER' -ge 1 ]"
  V2_BACKEND=$(echo "$V2_OUTPUT" | count_matches "backend: keyword")
  assert "v2.0 search shows keyword backend" "[ '$V2_BACKEND' -ge 1 ]"
  if [ "$V2_HEADER" -lt 1 ] || [ "$V2_BACKEND" -lt 1 ]; then
    echo "     ↳ diagnostic: MEMORY_BACKEND=$(grep -E '^[[:space:]]*MEMORY_BACKEND' plugins/loom-memory/config/memory-v2.conf 2>/dev/null | tr -d '\n')"
    echo "     ↳ diagnostic: first 5 lines of v2 search output:"
    sed -n '1,5p' <<< "$V2_OUTPUT" | sed 's/^/       | /'
  fi
fi

# ── Integration with Hook ──
echo ""
echo "Hook integration"
HOOK_SCRIPT=".claude/hooks/user-prompt-submit/governance-preflight.sh"
assert "Preflight hook references memory-search.sh" "grep -q 'memory-search.sh' $HOOK_SCRIPT"
assert "Preflight hook references memory-log.sh" "grep -q 'memory-log.sh' $HOOK_SCRIPT"

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
exit $FAIL
