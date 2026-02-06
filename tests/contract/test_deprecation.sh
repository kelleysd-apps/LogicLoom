#!/usr/bin/env bash
# Contract Tests: Deprecation compliance
# Updated for Plugin-First Architecture v4.0 — all skills, agents, commands migrated to plugins
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

echo "═══ Deprecation Compliance Tests ═══"
echo ""

echo "Monolithic skills deprecation"
DEPRECATED_SKILLS=0
TOTAL_MIGRATED=0
for skill_file in $(find .claude/skills -name "SKILL.md" -type f); do
  # Check if this skill has a plugin equivalent
  skill_name=$(basename "$(dirname "$skill_file")")
  plugin_match=$(find plugins -path "*/skills/${skill_name}/SKILL.md" -type f 2>/dev/null | head -1)
  if [ -n "$plugin_match" ]; then
    TOTAL_MIGRATED=$((TOTAL_MIGRATED + 1))
    # Search first 20 lines for DEPRECATED (handles YAML frontmatter + notice)
    if head -20 "$skill_file" | grep -q "DEPRECATED"; then
      DEPRECATED_SKILLS=$((DEPRECATED_SKILLS + 1))
    else
      echo "  ⚠️  Missing deprecation: $skill_file"
    fi
  fi
done
assert "All migrated skills have deprecation headers" "[ $DEPRECATED_SKILLS -eq $TOTAL_MIGRATED ]"
echo "  (${DEPRECATED_SKILLS}/${TOTAL_MIGRATED} migrated skills deprecated)"

echo ""
echo "Monolithic agents deprecation"
DEPRECATED_AGENTS=0
TOTAL_MIGRATED_AGENTS=0
for agent_file in $(find .claude/agents -name "*.md" -type f); do
  agent_name=$(basename "$agent_file")
  plugin_match=$(find plugins -path "*/agents/${agent_name}" -type f 2>/dev/null | head -1)
  if [ -n "$plugin_match" ]; then
    TOTAL_MIGRATED_AGENTS=$((TOTAL_MIGRATED_AGENTS + 1))
    # Search first 20 lines for DEPRECATED (handles YAML frontmatter + notice)
    if head -20 "$agent_file" | grep -q "DEPRECATED"; then
      DEPRECATED_AGENTS=$((DEPRECATED_AGENTS + 1))
    else
      echo "  ⚠️  Missing deprecation: $agent_file"
    fi
  fi
done
assert "All migrated agents have deprecation headers" "[ $DEPRECATED_AGENTS -eq $TOTAL_MIGRATED_AGENTS ]"
echo "  (${DEPRECATED_AGENTS}/${TOTAL_MIGRATED_AGENTS} migrated agents deprecated)"

echo ""
echo "Monolithic commands deprecation"
DEPRECATED_CMDS=0
TOTAL_CMDS=0
for cmd_file in .claude/commands/*.md; do
  TOTAL_CMDS=$((TOTAL_CMDS + 1))
  if head -20 "$cmd_file" | grep -q "DEPRECATED"; then
    DEPRECATED_CMDS=$((DEPRECATED_CMDS + 1))
  else
    echo "  ⚠️  Missing deprecation: $cmd_file"
  fi
done
assert "All monolithic commands have deprecation headers" "[ $DEPRECATED_CMDS -eq $TOTAL_CMDS ]"
echo "  (${DEPRECATED_CMDS}/${TOTAL_CMDS} commands deprecated)"

echo ""
echo "skill-index.json deprecation"
assert "skill-index.json has deprecated flag" "python3 -c 'import json; d=json.load(open(\".claude/skill-index.json\")); assert d[\"_metadata\"][\"deprecated\"]==True'"
assert "skill-index.json has migration target" "python3 -c 'import json; d=json.load(open(\".claude/skill-index.json\")); assert \"plugin\" in d[\"_metadata\"][\"migration_target\"].lower()'"

echo ""
echo "Plugin-First completeness (v4.0)"
# All 3 previously-orphan skills now have plugin homes
assert "framework-updater has plugin home" "[ -f plugins/sdd-maintenance/skills/framework-updater/SKILL.md ]"
assert "mcp-server-setup has plugin home" "[ -f plugins/sdd-maintenance/skills/mcp-server-setup/SKILL.md ]"
assert "project-initialization has plugin home" "[ -f plugins/sdd-maintenance/skills/project-initialization/SKILL.md ]"
assert "create-plugin command exists" "[ -f plugins/sdd-creation/commands/create-plugin.md ]"
assert "create-plugin skill exists" "[ -f plugins/sdd-creation/skills/create-plugin/SKILL.md ]"
assert "sdd-maintenance plugin manifest exists" "[ -f plugins/sdd-maintenance/.claude-plugin/plugin.json ]"

echo ""
echo "Backup files cleaned"
assert "No .bak files in .claude/" "[ \$(find .claude -name '*.bak' 2>/dev/null | wc -l | tr -d ' ') -eq 0 ]"
assert "No .backup files in root" "[ \$(find . -maxdepth 1 -name '*backup*' 2>/dev/null | wc -l | tr -d ' ') -eq 0 ]"

echo ""
echo "═══════════════════════════════════════"
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "═══════════════════════════════════════"
[ $FAIL -eq 0 ] && exit 0 || exit 1
