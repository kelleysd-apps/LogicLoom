#!/usr/bin/env bash
# Contract Tests: Deprecation compliance
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
    if head -5 "$skill_file" | grep -q "DEPRECATED"; then
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
    if head -5 "$agent_file" | grep -q "DEPRECATED"; then
      DEPRECATED_AGENTS=$((DEPRECATED_AGENTS + 1))
    else
      echo "  ⚠️  Missing deprecation: $agent_file"
    fi
  fi
done
assert "All migrated agents have deprecation headers" "[ $DEPRECATED_AGENTS -eq $TOTAL_MIGRATED_AGENTS ]"
echo "  (${DEPRECATED_AGENTS}/${TOTAL_MIGRATED_AGENTS} migrated agents deprecated)"

echo ""
echo "skill-index.json deprecation"
assert "skill-index.json has deprecated flag" "python3 -c 'import json; d=json.load(open(\".claude/skill-index.json\")); assert d[\"_metadata\"][\"deprecated\"]==True'"
assert "skill-index.json has migration target" "python3 -c 'import json; d=json.load(open(\".claude/skill-index.json\")); assert \"plugin\" in d[\"_metadata\"][\"migration_target\"].lower()'"

echo ""
echo "Non-migrated skills preserved"
for skill in integration/framework-updater integration/mcp-server-setup project-initialization; do
  skill_file=".claude/skills/${skill}/SKILL.md"
  if [ -f "$skill_file" ]; then
    if head -5 "$skill_file" | grep -q "DEPRECATED"; then
      echo "  ⚠️  ${skill} should NOT be deprecated (no plugin equivalent)"
    else
      assert "${skill} preserved (no plugin equivalent)" "true"
    fi
  fi
done

echo ""
echo "Backup files cleaned"
assert "No .bak files in .claude/" "[ \$(find .claude -name '*.bak' 2>/dev/null | wc -l | tr -d ' ') -eq 0 ]"
assert "No .backup files in root" "[ \$(find . -maxdepth 1 -name '*backup*' 2>/dev/null | wc -l | tr -d ' ') -eq 0 ]"

echo ""
echo "═══════════════════════════════════════"
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "═══════════════════════════════════════"
[ $FAIL -eq 0 ] && exit 0 || exit 1
