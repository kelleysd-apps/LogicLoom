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
for plugin in sdd-specification sdd-git sdd-creation; do
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
  assert "${plugin} has skill with Task Brief" "grep -q '## Task Brief' plugins/${plugin}/skills/${domain}-operations/SKILL.md 2>/dev/null"
done

echo ""
echo "═══ Orchestrator Skill Consolidation Tests ═══"
echo ""
echo "Orchestrator agent-to-skill conversion"
assert "team-orchestration skill exists" "[ -f plugins/sdd-orchestrator/skills/team-orchestration/SKILL.md ]"
assert "team-orchestration skill has Task Brief" "grep -q '## Task Brief' plugins/sdd-orchestrator/skills/team-orchestration/SKILL.md"
assert "multi-skill-workflow skill exists" "[ -f plugins/sdd-orchestrator/skills/multi-skill-workflow/SKILL.md ]"
assert "multi-skill-workflow skill has Task Brief" "grep -q '## Task Brief' plugins/sdd-orchestrator/skills/multi-skill-workflow/SKILL.md"
assert "team-synthesizer agent retained" "[ -f plugins/sdd-orchestrator/agents/team-synthesizer.md ]"
assert "task-orchestrator agent removed" "[ ! -f plugins/sdd-orchestrator/agents/task-orchestrator.md ]"
assert "swarm-coordinator agent removed" "[ ! -f plugins/sdd-orchestrator/agents/swarm-coordinator.md ]"
assert "workflow-coordinator agent removed" "[ ! -f plugins/sdd-orchestrator/agents/workflow-coordinator.md ]"
assert "plugin.json lists only team-synthesizer" "python3 -c 'import json; d=json.load(open(\"plugins/sdd-orchestrator/.claude-plugin/plugin.json\")); agents=d.get(\"agents\",{}); lst=agents.get(\"list\",agents) if isinstance(agents,dict) else agents; assert lst==[\"team-synthesizer\"]'"

echo ""
echo "═══ Specification Skill Consolidation Tests ═══"
echo ""
echo "Specification agent-to-skill conversion"
# sdd-specification, sdd-planning, sdd-tasks consolidated into unified-specification (v2.0.0)
assert "deprecated sdd-specification skill removed" "[ ! -d plugins/sdd-specification/skills/sdd-specification ]"
assert "deprecated sdd-planning skill removed" "[ ! -d plugins/sdd-specification/skills/sdd-planning ]"
assert "deprecated sdd-tasks skill removed" "[ ! -d plugins/sdd-specification/skills/sdd-tasks ]"
assert "unified-specification skill has Task Brief" "grep -q '## Task Brief' plugins/sdd-specification/skills/unified-specification/SKILL.md"
assert "specification agents directory removed" "[ ! -d plugins/sdd-specification/agents ]"
assert "plugin.json has empty agents array" "python3 -c 'import json; d=json.load(open(\"plugins/sdd-specification/.claude-plugin/plugin.json\")); agents=d.get(\"agents\",{}); lst=agents.get(\"list\",agents) if isinstance(agents,dict) else agents; assert lst==[]'"

echo ""
echo "═══ Swarm Contract Tests (T4.1.1-T4.1.3) ═══"
echo ""
echo "T4.1.1: Swarm lifecycle"
assert "sdd-orchestrator has /swarm command" "[ -f plugins/sdd-orchestrator/commands/swarm.md ]"
assert "sdd-orchestrator has team-orchestration skill" "[ -f plugins/sdd-orchestrator/skills/team-orchestration/SKILL.md ]"
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
