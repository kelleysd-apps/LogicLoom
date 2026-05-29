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
assert "loom-governance has plugin.json" "[ -f plugins/loom-governance/.claude-plugin/plugin.json ]"
assert "plugin.json is valid JSON" "python3 -c 'import json; json.load(open(\"plugins/loom-governance/.claude-plugin/plugin.json\"))'"
assert "plugin.json has name field" "python3 -c 'import json; d=json.load(open(\"plugins/loom-governance/.claude-plugin/plugin.json\")); assert d[\"name\"]==\"loom-governance\"'"
assert "plugin.json has version field" "python3 -c 'import json; d=json.load(open(\"plugins/loom-governance/.claude-plugin/plugin.json\")); assert \"version\" in d'"

echo ""
echo "T1.1.2: Plugin has required components"
assert "Has hooks/hooks.json" "[ -f plugins/loom-governance/hooks/hooks.json ]"
assert "Has at least 1 skill" "[ \$(find plugins/loom-governance/skills -name 'SKILL.md' | wc -l) -gt 0 ]"
assert "Has at least 1 agent" "[ \$(ls plugins/loom-governance/agents/*.md 2>/dev/null | wc -l) -gt 0 ]"

echo ""
echo "T1.1.3: loom-governance is protected"
assert "plugin.json has protected=true" "python3 -c 'import json; d=json.load(open(\"plugins/loom-governance/.claude-plugin/plugin.json\")); assert d.get(\"protected\")==True'"
assert "plugin.json has required=true" "python3 -c 'import json; d=json.load(open(\"plugins/loom-governance/.claude-plugin/plugin.json\")); assert d.get(\"required\")==True'"

echo ""
echo "T1.1.4: Plugin list returns valid data"
# v3.1.0: 9 plugins after domain collapse (governance core + tooling + workflow packs)
PLUGIN_COUNT=$(find plugins -name "plugin.json" -path "*/.claude-plugin/*" | wc -l | tr -d ' ')
assert "All 9+ plugins have manifests (found $PLUGIN_COUNT)" "[ $PLUGIN_COUNT -ge 9 ]"

echo ""
echo "═══ Core Plugin Contract Tests (T2.1.1-T2.1.4) ═══"
for plugin in sdd-specification loom-git loom-creation; do
  echo ""
  echo "Testing: ${plugin}"
  assert "${plugin} has plugin.json" "[ -f plugins/${plugin}/.claude-plugin/plugin.json ]"
  assert "${plugin} plugin.json valid JSON" "python3 -c 'import json; json.load(open(\"plugins/${plugin}/.claude-plugin/plugin.json\"))'"
  assert "${plugin} depends on loom-governance" "python3 -c 'import json; d=json.load(open(\"plugins/${plugin}/.claude-plugin/plugin.json\")); assert \"loom-governance\" in d.get(\"dependencies\",[])'"
done

echo ""
echo "═══ Domain Brief Registry Tests (v3.1.0: domains collapsed into core) ═══"
GOV_DIR="plugins/loom-governance"; [ -d "plugins/loom-governance" ] && GOV_DIR="plugins/loom-governance"
for domain in frontend backend database testing security devops performance; do
  echo ""
  echo "Testing: ${domain} brief"
  assert "sdd-domain-${domain} plugin removed" "[ ! -d plugins/sdd-domain-${domain} ]"
  assert "${domain} registry brief exists" "[ -f ${GOV_DIR}/domain-briefs/${domain}.md ]"
  assert "${domain} brief has Task Brief" "grep -q '## Task Brief' ${GOV_DIR}/domain-briefs/${domain}.md 2>/dev/null"
done

echo ""
echo "═══ Orchestrator Skill Consolidation Tests ═══"
echo ""
echo "Orchestrator agent-to-skill conversion"
assert "team-orchestration skill exists" "[ -f plugins/loom-orchestrator/skills/team-orchestration/SKILL.md ]"
assert "team-orchestration skill has Task Brief" "grep -q '## Task Brief' plugins/loom-orchestrator/skills/team-orchestration/SKILL.md"
assert "multi-skill-workflow skill exists" "[ -f plugins/loom-orchestrator/skills/multi-skill-workflow/SKILL.md ]"
assert "multi-skill-workflow skill has Task Brief" "grep -q '## Task Brief' plugins/loom-orchestrator/skills/multi-skill-workflow/SKILL.md"
assert "team-synthesizer agent retained" "[ -f plugins/loom-orchestrator/agents/team-synthesizer.md ]"
assert "task-orchestrator agent removed" "[ ! -f plugins/loom-orchestrator/agents/task-orchestrator.md ]"
assert "swarm-coordinator agent removed" "[ ! -f plugins/loom-orchestrator/agents/swarm-coordinator.md ]"
assert "workflow-coordinator agent removed" "[ ! -f plugins/loom-orchestrator/agents/workflow-coordinator.md ]"
assert "plugin.json lists only team-synthesizer" "python3 -c 'import json; d=json.load(open(\"plugins/loom-orchestrator/.claude-plugin/plugin.json\")); agents=d.get(\"agents\",{}); lst=agents.get(\"list\",agents) if isinstance(agents,dict) else agents; assert lst==[\"team-synthesizer\"]'"

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
assert "loom-orchestrator has /swarm command" "[ -f plugins/loom-orchestrator/commands/swarm.md ]"
assert "loom-orchestrator has team-orchestration skill" "[ -f plugins/loom-orchestrator/skills/team-orchestration/SKILL.md ]"
assert "loom-orchestrator has launch-swarm.sh" "[ -f plugins/loom-orchestrator/scripts/launch-swarm.sh ]"
assert "launch-swarm.sh is executable" "[ -x plugins/loom-orchestrator/scripts/launch-swarm.sh ]"

echo ""
echo "T4.1.2: Agent team templates"
for team in build-team review-team fullstack-team; do
  assert "Has /${team} command" "[ -f plugins/loom-orchestrator/commands/${team}.md ]"
done

echo ""
echo "T4.1.3: Budget controls"
assert "Has budget-manager.sh" "[ -f plugins/loom-orchestrator/scripts/budget-manager.sh ]"
assert "budget-manager.sh is executable" "[ -x plugins/loom-orchestrator/scripts/budget-manager.sh ]"

echo ""
echo "═══════════════════════════════════════"
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "═══════════════════════════════════════"
[ $FAIL -eq 0 ] && exit 0 || exit 1
