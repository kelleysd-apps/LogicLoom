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

echo "T4.1.1: Swarm command and coordinator"
assert "/swarm command exists" "[ -f plugins/sdd-orchestrator/commands/swarm.md ]"
assert "swarm-coordinator agent exists" "[ -f plugins/sdd-orchestrator/agents/swarm-coordinator.md ]"
assert "team-synthesizer agent exists" "[ -f plugins/sdd-orchestrator/agents/team-synthesizer.md ]"
assert "task-orchestrator agent exists" "[ -f plugins/sdd-orchestrator/agents/task-orchestrator.md ]"
assert "workflow-coordinator agent exists" "[ -f plugins/sdd-orchestrator/agents/workflow-coordinator.md ]"

echo ""
echo "T4.1.2: Launch script"
assert "launch-swarm.sh exists" "[ -f plugins/sdd-orchestrator/scripts/launch-swarm.sh ]"
assert "launch-swarm.sh is executable" "[ -x plugins/sdd-orchestrator/scripts/launch-swarm.sh ]"
assert "launch-swarm.sh has tmux setup" "grep -q 'tmux' plugins/sdd-orchestrator/scripts/launch-swarm.sh"
assert "launch-swarm.sh has session management" "grep -q 'session' plugins/sdd-orchestrator/scripts/launch-swarm.sh"

echo ""
echo "T4.1.3: Budget controls"
assert "budget-manager.sh exists" "[ -f plugins/sdd-orchestrator/scripts/budget-manager.sh ]"
assert "budget-manager.sh is executable" "[ -x plugins/sdd-orchestrator/scripts/budget-manager.sh ]"
assert "budget-manager.sh has max cost logic" "grep -q 'max.*budget\|MAX.*BUDGET\|budget' plugins/sdd-orchestrator/scripts/budget-manager.sh"
assert "budget-manager.sh has fallback model" "grep -q 'fallback\|FALLBACK' plugins/sdd-orchestrator/scripts/budget-manager.sh"

echo ""
echo "T4.2: Agent team templates"
for team in build-team review-team fullstack-team; do
  assert "${team} command exists" "[ -f plugins/sdd-orchestrator/commands/${team}.md ]"
done

echo ""
echo "T4.3: Hooks for agent coordination"
assert "hooks.json exists" "[ -f plugins/sdd-orchestrator/hooks/hooks.json ]"
assert "hooks.json is valid JSON" "python3 -c 'import json; json.load(open(\"plugins/sdd-orchestrator/hooks/hooks.json\"))'"
assert "hooks.json has Stop event" "python3 -c 'import json; d=json.load(open(\"plugins/sdd-orchestrator/hooks/hooks.json\")); assert any(h[\"event\"]==\"Stop\" for h in d[\"hooks\"])'"
assert "hooks.json has SubagentStop event" "python3 -c 'import json; d=json.load(open(\"plugins/sdd-orchestrator/hooks/hooks.json\")); assert any(h[\"event\"]==\"SubagentStop\" for h in d[\"hooks\"])'"
assert "agent-stop-notification.sh exists" "[ -f plugins/sdd-orchestrator/hooks/scripts/agent-stop-notification.sh ]"

echo ""
echo "T4.4: Orchestrator skills"
for skill in multi-skill-workflow full-stack-feature migration-workflow tribunal-review team-orchestration; do
  assert "Skill ${skill} exists" "[ -f plugins/sdd-orchestrator/skills/${skill}/SKILL.md ]"
done

echo ""
echo "═══════════════════════════════════════"
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "═══════════════════════════════════════"
[ $FAIL -eq 0 ] && exit 0 || exit 1
