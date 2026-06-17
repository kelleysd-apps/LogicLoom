#!/usr/bin/env bash
# Contract Tests: Swarm Lifecycle (T4.1.1-T4.1.3, T4.5.x structural)
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

echo "═══ Swarm Lifecycle Contract Tests ═══"
echo ""

echo "T4.1.1: Swarm command and orchestration skills"
assert "/swarm command exists" "[ -f plugins/loom-orchestrator/commands/swarm.md ]"
assert "team-orchestration skill exists" "[ -f plugins/loom-orchestrator/skills/team-orchestration/SKILL.md ]"
assert "team-synthesizer agent exists" "[ -f plugins/loom-orchestrator/agents/team-synthesizer.md ]"
assert "multi-skill-workflow skill exists" "[ -f plugins/loom-orchestrator/skills/multi-skill-workflow/SKILL.md ]"
assert "orchestrator agents converted to skills" "[ ! -f plugins/loom-orchestrator/agents/swarm-coordinator.md ]"

echo ""
echo "T4.1.2: Native-primitive orchestration (no custom runner)"
# v6.2: orchestration leans on Claude Code's native Task tool + /workflow.
# The old tmux/launch-swarm/budget-manager custom runner is removed.
assert "dead launch-swarm.sh removed" "[ ! -f plugins/loom-orchestrator/scripts/launch-swarm.sh ]"
assert "dead budget-manager.sh removed" "[ ! -f plugins/loom-orchestrator/scripts/budget-manager.sh ]"
assert "team-orchestration uses native Task tool" "grep -q 'Task tool' plugins/loom-orchestrator/skills/team-orchestration/SKILL.md"
assert "team-orchestration references /workflow primitive" "grep -q '/workflow' plugins/loom-orchestrator/skills/team-orchestration/SKILL.md"
assert "team-orchestration drops tmux/state-file runner" "! grep -qE 'tmux|multi-agent-swarm' plugins/loom-orchestrator/skills/team-orchestration/SKILL.md"

echo ""
echo "T4.2: Agent team templates"
for team in build-team review-team fullstack-team; do
  assert "${team} command exists" "[ -f plugins/loom-orchestrator/commands/${team}.md ]"
done

echo ""
echo "T4.3: Hooks for agent coordination"
assert "hooks.json exists" "[ -f plugins/loom-orchestrator/hooks/hooks.json ]"
assert "hooks.json is valid JSON" "python3 -c 'import json; json.load(open(\"plugins/loom-orchestrator/hooks/hooks.json\"))'"
assert "hooks.json has Stop event" "python3 -c 'import json; d=json.load(open(\"plugins/loom-orchestrator/hooks/hooks.json\")); assert any(h[\"event\"]==\"Stop\" for h in d[\"hooks\"])'"
assert "hooks.json has SubagentStop event" "python3 -c 'import json; d=json.load(open(\"plugins/loom-orchestrator/hooks/hooks.json\")); assert any(h[\"event\"]==\"SubagentStop\" for h in d[\"hooks\"])'"
assert "agent-stop-notification.sh exists" "[ -f plugins/loom-orchestrator/hooks/scripts/agent-stop-notification.sh ]"

echo ""
echo "T4.4: Orchestrator skills"
for skill in multi-skill-workflow full-stack-feature migration-workflow team-orchestration; do
  assert "Skill ${skill} exists" "[ -f plugins/loom-orchestrator/skills/${skill}/SKILL.md ]"
done

echo ""
echo "═══════════════════════════════════════"
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "═══════════════════════════════════════"
[ $FAIL -eq 0 ] && exit 0 || exit 1
