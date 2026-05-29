#!/usr/bin/env bash
# Contract Tests: Spec 006 — Agent Architecture Simplification + Memory Enhancement
# Validates the full scope of spec 006 changes:
#   - Agent reduction (22→12)
#   - Agent→skill conversions (13 skills with Task Brief)
#   - Memory v2.0 backends (keyword, bm25, vector, hybrid)
#   - Retention policies and memory flush
#   - Plugin manifest integrity
#   - Bridge command sync
set -eo pipefail

PASS=0; FAIL=0; TOTAL=0
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

assert() {
  TOTAL=$((TOTAL + 1))
  local desc="$1"; shift
  if ( set +eu; eval "$@" ) >/dev/null 2>&1; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

echo "=== Spec 006: Agent Architecture Simplification + Memory Enhancement ==="
echo ""

# ═══════════════════════════════════════
# Section 1: Agent Reduction
# ═══════════════════════════════════════
echo "--- Agent Reduction ---"

# Count remaining agent files across all plugins
AGENT_COUNT=$(find "$ROOT_DIR/plugins" -path "*/agents/*.md" | wc -l | tr -d ' ')
assert "Agent count reduced to ~6 (found ${AGENT_COUNT})" "[ ${AGENT_COUNT} -le 7 ]"

# Verify essential agents are KEPT
assert "constitutional-governance-agent kept" "[ -f '$ROOT_DIR/plugins/loom-governance/agents/constitutional-governance-agent.md' ]"
assert "memory-context-agent kept" "[ -f '$ROOT_DIR/plugins/loom-memory/agents/memory-context-agent.md' ]"
assert "framework-sync-agent kept" "[ -f '$ROOT_DIR/plugins/loom-maintenance/agents/framework-sync-agent.md' ]"
assert "prd-specialist kept" "[ -f '$ROOT_DIR/plugins/loom-creation/agents/prd-specialist.md' ]"
assert "subagent-architect kept" "[ -f '$ROOT_DIR/plugins/loom-creation/agents/subagent-architect.md' ]"
assert "team-synthesizer kept" "[ -f '$ROOT_DIR/plugins/loom-orchestrator/agents/team-synthesizer.md' ]"
# dev-loop agents removed (converted to core-loop skill)
assert "dev-loop agents directory removed" "[ ! -d '$ROOT_DIR/plugins/loom-dev-loop/agents' ]"

# v3.1.0: domain plugins collapsed into the governance-core domain-brief registry
for domain in frontend backend database testing security performance devops; do
  assert "sdd-domain-${domain} plugin removed" "[ ! -d '$ROOT_DIR/plugins/sdd-domain-${domain}' ]"
done

echo ""

# ═══════════════════════════════════════
# Section 2: Agent→Skill Conversions
# ═══════════════════════════════════════
echo "--- Agent→Skill Conversions ---"

# Domain knowledge now lives in the governance-core domain-brief registry
GOV_DIR="$ROOT_DIR/plugins/loom-governance"; [ -d "$ROOT_DIR/plugins/loom-governance" ] && GOV_DIR="$ROOT_DIR/plugins/loom-governance"
REG_BRIEF_COUNT=$(grep -rl "^## Task Brief" "$GOV_DIR/domain-briefs"/*.md 2>/dev/null | wc -l | tr -d ' ')
assert "7 domain briefs in registry (found ${REG_BRIEF_COUNT})" "[ ${REG_BRIEF_COUNT} -ge 7 ]"

# Verify each domain brief exists with a Task Brief section
for domain in backend frontend database testing security performance devops; do
  assert "${domain} registry brief exists" "[ -f '$GOV_DIR/domain-briefs/${domain}.md' ]"
  assert "${domain} brief has Task Brief" "grep -q '^## Task Brief' '$GOV_DIR/domain-briefs/${domain}.md'"
done

# Orchestrator/specification skill consolidations
assert "team-orchestration skill exists" "[ -f '$ROOT_DIR/plugins/loom-orchestrator/skills/team-orchestration/SKILL.md' ]"
assert "multi-skill-workflow skill exists" "[ -f '$ROOT_DIR/plugins/loom-orchestrator/skills/multi-skill-workflow/SKILL.md' ]"
# sdd-specification, sdd-planning, sdd-tasks consolidated into unified-specification (v2.0.0)
assert "unified-specification skill exists" "[ -f '$ROOT_DIR/plugins/sdd-specification/skills/unified-specification/SKILL.md' ]"
assert "deprecated sdd-specification skill removed" "[ ! -d '$ROOT_DIR/plugins/sdd-specification/skills/sdd-specification' ]"
assert "deprecated sdd-planning skill removed" "[ ! -d '$ROOT_DIR/plugins/sdd-specification/skills/sdd-planning' ]"
assert "deprecated sdd-tasks skill removed" "[ ! -d '$ROOT_DIR/plugins/sdd-specification/skills/sdd-tasks' ]"

echo ""

# ═══════════════════════════════════════
# Section 3: Domain Registry Integrity
# ═══════════════════════════════════════
echo "--- Domain Registry Integrity ---"

# No domain plugin manifests should remain (collapsed into the core registry)
for domain in backend frontend database testing security performance devops; do
  assert "no sdd-domain-${domain} manifest" "[ ! -f '$ROOT_DIR/plugins/sdd-domain-${domain}/plugin.json' ]"
done
# Registry README documents the collapse
assert "domain-briefs registry README exists" "[ -f '$GOV_DIR/domain-briefs/README.md' ]"

# Memory plugin should be v2.0.0
MEM_VERSION=$(python3 -c "import json; print(json.load(open('$ROOT_DIR/plugins/loom-memory/.claude-plugin/plugin.json'))['version'])" 2>/dev/null)
assert "loom-memory plugin version is 2.0.0 (found ${MEM_VERSION})" "[ '${MEM_VERSION}' = '2.0.0' ]"

# Memory plugin has backends field
assert "loom-memory plugin.json has backends field" "python3 -c \"import json; d=json.load(open('$ROOT_DIR/plugins/loom-memory/.claude-plugin/plugin.json')); assert 'backends' in d\""
assert "backends has keyword entry" "python3 -c \"import json; d=json.load(open('$ROOT_DIR/plugins/loom-memory/.claude-plugin/plugin.json')); assert 'keyword' in d['backends']\""
assert "backends has bm25 entry" "python3 -c \"import json; d=json.load(open('$ROOT_DIR/plugins/loom-memory/.claude-plugin/plugin.json')); assert 'bm25' in d['backends']\""
assert "backends has vector entry" "python3 -c \"import json; d=json.load(open('$ROOT_DIR/plugins/loom-memory/.claude-plugin/plugin.json')); assert 'vector' in d['backends']\""
assert "backends has hybrid entry" "python3 -c \"import json; d=json.load(open('$ROOT_DIR/plugins/loom-memory/.claude-plugin/plugin.json')); assert 'hybrid' in d['backends']\""

echo ""

# ═══════════════════════════════════════
# Section 4: Memory v2.0 Backend Files
# ═══════════════════════════════════════
echo "--- Memory v2.0 Backend Files ---"

LIB_DIR="$ROOT_DIR/plugins/loom-memory/lib"

# File existence
assert "backend-interface.sh exists" "[ -f '$LIB_DIR/backend-interface.sh' ]"
assert "keyword-backend.sh exists" "[ -f '$LIB_DIR/keyword-backend.sh' ]"
assert "bm25-search.sh exists" "[ -f '$LIB_DIR/bm25-search.sh' ]"
assert "vector-search.sh exists" "[ -f '$LIB_DIR/vector-search.sh' ]"
assert "hybrid-search.sh exists" "[ -f '$LIB_DIR/hybrid-search.sh' ]"
assert "retention.sh exists" "[ -f '$LIB_DIR/retention.sh' ]"
assert "memory-flush.sh exists" "[ -f '$LIB_DIR/memory-flush.sh' ]"

# Backend interface contract (4 required functions)
assert "interface defines backend_search" "grep -q 'backend_search()' '$LIB_DIR/backend-interface.sh'"
assert "interface defines backend_index" "grep -q 'backend_index()' '$LIB_DIR/backend-interface.sh'"
assert "interface defines backend_reindex_all" "grep -q 'backend_reindex_all()' '$LIB_DIR/backend-interface.sh'"
assert "interface defines backend_health_check" "grep -q 'backend_health_check()' '$LIB_DIR/backend-interface.sh'"

# Each backend implements the 4 contract functions
for backend in keyword-backend bm25-search vector-search hybrid-search; do
  assert "${backend} implements backend_search" "grep -q 'backend_search()' '$LIB_DIR/${backend}.sh'"
  assert "${backend} implements backend_health_check" "grep -q 'backend_health_check()' '$LIB_DIR/${backend}.sh'"
done

# Retention implements cleanup functions
assert "retention.sh has retention_cleanup" "grep -q 'retention_cleanup()' '$LIB_DIR/retention.sh'"
assert "retention.sh has parse_ttl" "grep -q 'parse_ttl' '$LIB_DIR/retention.sh'"

# Memory flush implements extraction
assert "memory-flush.sh has flush function" "grep -q 'memory_flush\|flush_session\|_flush' '$LIB_DIR/memory-flush.sh'"

# Bash syntax validation on all backend files
for f in backend-interface keyword-backend bm25-search vector-search hybrid-search retention memory-flush; do
  assert "${f}.sh passes bash -n" "bash -n '$LIB_DIR/${f}.sh'"
done

echo ""

# ═══════════════════════════════════════
# Section 5: Memory v2.0 Configuration
# ═══════════════════════════════════════
echo "--- Memory v2.0 Configuration ---"

V2_CONF="$ROOT_DIR/plugins/loom-memory/config/memory-v2.conf"

assert "memory-v2.conf exists" "[ -f '$V2_CONF' ]"
assert "MEMORY_BACKEND configured" "grep -q '^MEMORY_BACKEND=' '$V2_CONF'"
assert "VECTOR_WEIGHT configured" "grep -q '^VECTOR_WEIGHT=' '$V2_CONF'"
assert "KEYWORD_WEIGHT configured" "grep -q '^KEYWORD_WEIGHT=' '$V2_CONF'"
assert "MAX_CANDIDATES configured" "grep -q '^MAX_CANDIDATES=' '$V2_CONF'"
assert "INJECT_COUNT configured" "grep -q '^INJECT_COUNT=' '$V2_CONF'"
assert "MEMORY_TIMEOUT_MS configured" "grep -q '^MEMORY_TIMEOUT_MS=' '$V2_CONF'"
assert "WORKING_TTL configured" "grep -q '^WORKING_TTL=' '$V2_CONF'"
assert "RECALL_TTL configured" "grep -q '^RECALL_TTL=' '$V2_CONF'"
assert "ARCHIVAL_TTL configured" "grep -q '^ARCHIVAL_TTL=' '$V2_CONF'"
assert "SCOPE_MODE configured" "grep -q '^SCOPE_MODE=' '$V2_CONF'"

# Validate weight values sum to ~1.0
VWEIGHT=$(grep '^VECTOR_WEIGHT=' "$V2_CONF" | cut -d= -f2)
KWEIGHT=$(grep '^KEYWORD_WEIGHT=' "$V2_CONF" | cut -d= -f2)
WSUM=$(python3 -c "print(round(${VWEIGHT:-0}+${KWEIGHT:-0}, 2))" 2>/dev/null || echo "0")
assert "Hybrid weights sum to 1.0 (${VWEIGHT}+${KWEIGHT}=${WSUM})" "[ '${WSUM}' = '1.0' ]"

# Timeout within hook budget (5000ms)
TIMEOUT=$(grep '^MEMORY_TIMEOUT_MS=' "$V2_CONF" | cut -d= -f2)
assert "Timeout within 5s hook budget (${TIMEOUT}ms)" "[ ${TIMEOUT:-0} -le 5000 ]"

echo ""

# ═══════════════════════════════════════
# Section 6: Memory-Search v2.0 Upgrade
# ═══════════════════════════════════════
echo "--- Memory-Search v2.0 Upgrade ---"

SEARCH_SCRIPT="$ROOT_DIR/plugins/loom-memory/scripts/memory-search.sh"

assert "memory-search.sh exists" "[ -f '$SEARCH_SCRIPT' ]"
assert "memory-search.sh passes bash -n" "bash -n '$SEARCH_SCRIPT'"
assert "loads memory-v2.conf" "grep -q 'memory-v2.conf' '$SEARCH_SCRIPT'"
assert "has backend selection logic" "grep -q 'MEMORY_BACKEND\|_select_backend' '$SEARCH_SCRIPT'"
assert "supports keyword backend" "grep -q 'keyword' '$SEARCH_SCRIPT'"
assert "supports bm25 backend" "grep -q 'bm25' '$SEARCH_SCRIPT'"
assert "supports vector backend" "grep -q 'vector' '$SEARCH_SCRIPT'"
assert "supports hybrid backend" "grep -q 'hybrid' '$SEARCH_SCRIPT'"
assert "has retention integration" "grep -q 'retention' '$SEARCH_SCRIPT'"
assert "has result formatting" "grep -q 'format\|_format' '$SEARCH_SCRIPT'"

echo ""

# ═══════════════════════════════════════
# Section 7: Memory Tier Directories
# ═══════════════════════════════════════
echo "--- Memory Tier Directories ---"

MEM_DIR="$ROOT_DIR/plugins/loom-memory"

assert "working/ directory exists" "[ -d '$MEM_DIR/working' ]"
assert "recall/ directory exists" "[ -d '$MEM_DIR/recall' ]"
assert "archival/ directory exists" "[ -d '$MEM_DIR/archival' ]"
assert "working/.gitkeep exists" "[ -f '$MEM_DIR/working/.gitkeep' ]"
assert "recall/.gitkeep exists" "[ -f '$MEM_DIR/recall/.gitkeep' ]"
assert "archival/.gitkeep exists" "[ -f '$MEM_DIR/archival/.gitkeep' ]"

echo ""

# ═══════════════════════════════════════
# Section 8: Bridge Command Integrity
# ═══════════════════════════════════════
echo "--- Bridge Command Integrity ---"

MANIFEST="$ROOT_DIR/.claude/commands/.bridge-manifest.json"

assert "Bridge manifest exists" "[ -f '$MANIFEST' ]"
BRIDGE_COUNT=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(len(d.get('bridged',{})))" 2>/dev/null || echo "0")
assert "15+ bridged commands (found ${BRIDGE_COUNT})" "[ ${BRIDGE_COUNT} -ge 15 ]"

# Verify key commands are bridged (specify/plan/tasks removed — use /specification)
for cmd in specification research swarm build-team fullstack-team review-team finalize git-push dev-loop update-framework; do
  assert "${cmd} is bridged" "python3 -c \"import json; d=json.load(open('$MANIFEST')); assert '${cmd}' in d['bridged']\""
done

echo ""

# ═══════════════════════════════════════
# Section 9: Cross-Cutting Validation
# ═══════════════════════════════════════
echo "--- Cross-Cutting Validation ---"

# No sdd-domain-* plugin directories remain (collapsed into the core registry)
ORPHAN_DOMAINS=$(find "$ROOT_DIR/plugins" -maxdepth 1 -type d -name 'sdd-domain-*' 2>/dev/null | wc -l | tr -d ' ')
assert "No sdd-domain-* plugin dirs remain (found ${ORPHAN_DOMAINS})" "[ ${ORPHAN_DOMAINS} -eq 0 ]"

# All plugin manifests are valid JSON (canonical location: .claude-plugin/plugin.json)
INVALID_JSON=0
for pjson in "$ROOT_DIR"/plugins/*/.claude-plugin/plugin.json; do
  [ -f "$pjson" ] || continue
  if ! python3 -c "import json; json.load(open('$pjson'))" 2>/dev/null; then
    INVALID_JSON=$((INVALID_JSON + 1))
    echo "    WARNING: Invalid JSON in $pjson"
  fi
done
assert "All plugin.json files are valid JSON (${INVALID_JSON} invalid)" "[ ${INVALID_JSON} -eq 0 ]"

# Constitution still references 16 principles
PRINCIPLE_COUNT=$(grep -c '^### Principle' "$ROOT_DIR/.logic-loom/memory/constitution.md" 2>/dev/null || echo "0")
assert "Constitution has 16 principles (found ${PRINCIPLE_COUNT})" "[ ${PRINCIPLE_COUNT} -eq 16 ]"

echo ""

# ═══════════════════════════════════════
# Final Results
# ═══════════════════════════════════════
echo ""
echo "======================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "======================================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
