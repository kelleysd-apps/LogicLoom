#!/usr/bin/env bash
# Contract Tests: Plugin Lifecycle (T1.1.1-T1.1.4)
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

echo "═══ Plugin Lifecycle Contract Tests ═══"
echo ""

echo "T1.1.1: Plugin install succeeds with valid manifest"
assert "sdd-governance has plugin.json" "[ -f plugins/sdd-governance/.claude-plugin/plugin.json ]"
assert "plugin.json is valid JSON" "python3 -c 'import json; json.load(open(\"plugins/sdd-governance/.claude-plugin/plugin.json\"))'"
assert "plugin.json has name field" "python3 -c 'import json; d=json.load(open(\"plugins/sdd-governance/.claude-plugin/plugin.json\")); assert d[\"name\"]==\"sdd-governance\"'"
assert "plugin.json has version field" "python3 -c 'import json; d=json.load(open(\"plugins/sdd-governance/.claude-plugin/plugin.json\")); assert \"version\" in d'"

echo ""
echo "T1.1.2: Plugin has required components"
assert "Has hooks/hooks.json" "[ -f plugins/sdd-governance/hooks/hooks.json ]"
assert "Has at least 1 skill" "[ \$(find plugins/sdd-governance/skills -name 'SKILL.md' | wc -l) -gt 0 ]"
assert "Has at least 1 agent" "[ \$(ls plugins/sdd-governance/agents/*.md 2>/dev/null | wc -l) -gt 0 ]"

echo ""
echo "T1.1.3: sdd-governance is protected"
assert "plugin.json has protected=true" "python3 -c 'import json; d=json.load(open(\"plugins/sdd-governance/.claude-plugin/plugin.json\")); assert d.get(\"protected\")==True'"
assert "plugin.json has required=true" "python3 -c 'import json; d=json.load(open(\"plugins/sdd-governance/.claude-plugin/plugin.json\")); assert d.get(\"required\")==True'"

echo ""
echo "T1.1.4: Plugin list returns valid data"
PLUGIN_COUNT=$(find plugins -name "plugin.json" -path "*/.claude-plugin/*" | wc -l | tr -d ' ')
assert "All 13+ plugins have manifests" "[ $PLUGIN_COUNT -ge 13 ]"

echo ""
echo "═══ Core Plugin Contract Tests (T2.1.1-T2.1.4) ═══"
for plugin in sdd-specification sdd-git sdd-debug sdd-creation; do
  echo ""
  echo "Testing: ${plugin}"
  assert "${plugin} has plugin.json" "[ -f plugins/${plugin}/.claude-plugin/plugin.json ]"
  assert "${plugin} plugin.json valid JSON" "python3 -c 'import json; json.load(open(\"plugins/${plugin}/.claude-plugin/plugin.json\"))'"
  assert "${plugin} depends on sdd-governance" "python3 -c 'import json; d=json.load(open(\"plugins/${plugin}/.claude-plugin/plugin.json\")); assert \"sdd-governance\" in d.get(\"dependencies\",[])'"
done

echo ""
echo "═══ Domain Plugin Contract Tests (T3.1.2) ═══"
for domain in frontend backend database testing security devops performance; do
  plugin="sdd-domain-${domain}"
  echo ""
  echo "Testing: ${plugin}"
  assert "${plugin} has plugin.json" "[ -f plugins/${plugin}/.claude-plugin/plugin.json ]"
  assert "${plugin} has skills" "[ \$(find plugins/${plugin}/skills -name 'SKILL.md' 2>/dev/null | wc -l) -gt 0 ]"
  assert "${plugin} has agents" "[ \$(ls plugins/${plugin}/agents/*.md 2>/dev/null | wc -l) -gt 0 ]"
done

echo ""
echo "═══ Swarm Contract Tests (T4.1.1-T4.1.3) ═══"
echo ""
echo "T4.1.1: Swarm lifecycle"
assert "sdd-orchestrator has /swarm command" "[ -f plugins/sdd-orchestrator/commands/swarm.md ]"
assert "sdd-orchestrator has swarm-coordinator agent" "[ -f plugins/sdd-orchestrator/agents/swarm-coordinator.md ]"
assert "sdd-orchestrator has launch-swarm.sh" "[ -f plugins/sdd-orchestrator/scripts/launch-swarm.sh ]"
assert "launch-swarm.sh is executable" "[ -x plugins/sdd-orchestrator/scripts/launch-swarm.sh ]"

echo ""
echo "T4.1.2: Agent team templates"
for team in build-team review-team fullstack-team; do
  assert "Has /${team} command" "[ -f plugins/sdd-orchestrator/commands/${team}.md ]"
done

echo ""
echo "T4.1.3: Budget controls"
assert "Has budget-manager.sh" "[ -f plugins/sdd-orchestrator/scripts/budget-manager.sh ]"
assert "budget-manager.sh is executable" "[ -x plugins/sdd-orchestrator/scripts/budget-manager.sh ]"

echo ""
echo "═══════════════════════════════════════"
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "═══════════════════════════════════════"
[ $FAIL -eq 0 ] && exit 0 || exit 1
