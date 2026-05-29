#!/usr/bin/env bash
# Contract Tests: Memory Context Search
# Validates memory search, tier priority, filtering, and timeout behavior
# Feature: 005-agent-architecture-refactor
set -euo pipefail

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

MEMORY_SEARCH="plugins/loom-memory/scripts/memory-search.sh"
MEMORY_LOG="plugins/loom-memory/scripts/memory-log.sh"
MEMORY_CONF="plugins/loom-memory/config/memory.conf"

echo "═══ Memory Context Search Contract Tests ═══"
echo ""

# ── Plugin Infrastructure Tests ──
echo "Plugin infrastructure"
assert "loom-memory plugin.json exists" "[ -f plugins/loom-memory/plugin.json ]"
assert "loom-memory plugin.json is valid JSON" \
  "python3 -c 'import json; json.load(open(\"plugins/loom-memory/plugin.json\"))'"
assert "memory.conf exists" "[ -f $MEMORY_CONF ]"
assert "memory-search.sh exists" "[ -f $MEMORY_SEARCH ]"
assert "memory-search.sh is executable" "[ -x $MEMORY_SEARCH ]"
assert "memory-log.sh exists" "[ -f $MEMORY_LOG ]"
assert "memory-log.sh is executable" "[ -x $MEMORY_LOG ]"
assert "context-injection skill exists" \
  "[ -f plugins/loom-memory/skills/context-injection/SKILL.md ]"
assert "memory-context-agent exists" \
  "[ -f plugins/loom-memory/agents/memory-context-agent.md ]"

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
  HAS_HEADER=$(echo "$SEARCH_OUTPUT" | head -1 | grep -c "MEMORY CONTEXT" || echo "0")
  assert "Search output has MEMORY CONTEXT header" "[ '$HAS_HEADER' -ge 1 ]"
fi

# Test with gibberish query — should return empty/minimal
EMPTY_OUTPUT=$(bash "$MEMORY_SEARCH" "xyzzy98765nonexistenttermfoobar" 2>/dev/null || echo "")
NO_RESULTS=$(echo "$EMPTY_OUTPUT" | grep -c "No relevant context found" || echo "0")
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
    HAS_BRIEF=$(grep -c '## Task Brief' "$BRIEF_FILE" || echo "0")
    assert "${domain} brief has Task Brief section" "[ '$HAS_BRIEF' -ge 1 ]"
  fi
done

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
  V2_HEADER=$(echo "$V2_OUTPUT" | head -1 | grep -c "MEMORY CONTEXT" || echo "0")
  assert "v2.0 search output has MEMORY CONTEXT header" "[ '$V2_HEADER' -ge 1 ]"
  V2_BACKEND=$(echo "$V2_OUTPUT" | grep -c "backend: keyword" || echo "0")
  assert "v2.0 search shows keyword backend" "[ '$V2_BACKEND' -ge 1 ]"
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
