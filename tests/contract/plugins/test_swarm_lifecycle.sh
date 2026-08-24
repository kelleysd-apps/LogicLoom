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
echo "T4.3: No dead hook wiring (LOOM-0032)"
# Empirically settled 2026-08-24: a per-plugin hooks/hooks.json is NEVER loaded in
# this repo. Claude Code reads plugin hooks from ~/.claude/plugins/*/hooks/hooks.json
# for INSTALLED plugins only; LogicLoom's plugins/ tree is not a plugin installation
# (no marketplace.json, absent from installed_plugins.json + enabledPlugins) and is
# consumed solely by sync-plugin-commands.sh, which bridges commands and not hooks.
# The orchestrator's Stop/SubagentStop wiring therefore never fired once: ~98 subagent
# completions between 2026-06-14 and 2026-08-24 left subagent-activity.log untouched.
# It was deleted rather than repaired -- nothing consumed the log, and a live Stop hook
# would append an "agent=unknown" line on every main-agent turn forever.
# These assertions pin the deletion so the dead wiring cannot silently return.
assert "no dead plugin hooks wiring" "[ ! -e plugins/loom-orchestrator/hooks ]"
assert "no orphaned agent-stop-notification.sh" "[ ! -f plugins/loom-orchestrator/hooks/scripts/agent-stop-notification.sh ]"
assert "no stale subagent-activity log" "[ ! -f .logic-loom/logs/subagent-activity.log ]"
# The real subagent-completion signal: the main agent collects each worker's result
# directly from the native Task tool -- no hook, no coordinator, no state file.
assert "subagent results come from the native Task tool" "grep -q 'Task tool' plugins/loom-orchestrator/skills/team-orchestration/SKILL.md"

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
