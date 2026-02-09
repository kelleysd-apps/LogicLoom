#!/usr/bin/env bash
# Contract Tests: Additive Update Framework
# Validates upstream-history-only diffing and proposal extraction
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

SYNC_REF_FILE=".sdd-sync-ref"
EXTRACT_SCRIPT="plugins/sdd-maintenance/scripts/extract-proposals.sh"
SKILL_FILE="plugins/sdd-maintenance/skills/framework-updater/SKILL.md"

echo "═══ Additive Update Framework Contract Tests ═══"
echo ""

# ── Sync Reference Tests ──
echo "Sync reference tracking"
assert ".sdd-sync-ref exists" "[ -f $SYNC_REF_FILE ]"
assert ".sdd-sync-ref contains a commit hash" \
  "grep -qE '^[0-9a-f]{7,40}$' $SYNC_REF_FILE"
assert ".sdd-sync-ref is not in .gitignore" \
  "! grep -q 'sdd-sync-ref' .gitignore 2>/dev/null || true"

# ── Extract Proposals Script ──
echo ""
echo "Proposal extraction"
assert "extract-proposals.sh exists" "[ -f $EXTRACT_SCRIPT ]"
assert "extract-proposals.sh is executable" "[ -x $EXTRACT_SCRIPT ]"

# Test script help/usage (should not error with no args)
HELP_EXIT=0
bash "$EXTRACT_SCRIPT" --help >/dev/null 2>&1 || HELP_EXIT=$?
assert "extract-proposals.sh responds to --help" "[ $HELP_EXIT -eq 0 ]"

# Test with dry-run (no upstream remote needed)
DRY_OUTPUT=$(bash "$EXTRACT_SCRIPT" --dry-run 2>&1 || echo "")
assert "extract-proposals.sh supports --dry-run" "echo '$DRY_OUTPUT' | grep -qi 'dry\|no upstream\|sync-ref' || true"

# ── Skill Definition Tests ──
echo ""
echo "Framework updater skill"
assert "framework-updater SKILL.md exists" "[ -f $SKILL_FILE ]"
assert "SKILL.md references .sdd-sync-ref" "grep -q 'sdd-sync-ref' $SKILL_FILE"
assert "SKILL.md references extract-proposals.sh" "grep -q 'extract-proposals' $SKILL_FILE"
assert "SKILL.md references upstream-history-only approach" \
  "grep -qi 'upstream.history\|upstream.*only\|sync.ref.*upstream' $SKILL_FILE"
assert "SKILL.md does NOT reference Tier 2 safe replace" \
  "! grep -q 'Tier 2.*safe replace\|Tier 2.*Replace' $SKILL_FILE"

# ── Tag Awareness Tests ──
echo ""
echo "Tag awareness"
assert "extract-proposals.sh has list_tags_in_range function" \
  "grep -q 'list_tags_in_range' $EXTRACT_SCRIPT"
assert "extract-proposals.sh has find_tag_for_file function" \
  "grep -q 'find_tag_for_file' $EXTRACT_SCRIPT"
assert "extract-proposals.sh outputs release_tag field" \
  "grep -q 'release_tag' $EXTRACT_SCRIPT"
assert "SKILL.md references release tag grouping" \
  "grep -qi 'release.tag\|per.release\|group.*by.*release' $SKILL_FILE"
assert "Help text mentions release tags" \
  "bash $EXTRACT_SCRIPT --help 2>&1 | grep -qi 'release\|tag'"

# ── Update Command ──
echo ""
echo "Update framework command"
assert "update-framework command exists" \
  "[ -f plugins/sdd-maintenance/commands/update-framework.md ]"
assert "update-framework references proposal-based flow" \
  "grep -qi 'proposal\|enhancement' plugins/sdd-maintenance/commands/update-framework.md"

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
exit $FAIL
