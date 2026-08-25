#!/usr/bin/env bash
# Contract Tests: Additive Update Framework
# Validates upstream-history-only diffing and proposal extraction
# Feature: 005-agent-architecture-refactor
set -euo pipefail

PASS=0; FAIL=0; TOTAL=0; SKIP=0

assert() {
  TOTAL=$((TOTAL + 1))
  local desc="$1"; local condition="$2"
  if eval "$condition"; then
    echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# A skip is NOT a pass. It is counted separately and never folded into PASS/TOTAL,
# so an unrunnable precondition can never masquerade as a satisfied assertion.
skip() {
  echo "  ⏭️  SKIP: $1 — $2"; SKIP=$((SKIP + 1))
}

SYNC_REF_FILE=".sdd-sync-ref"
EXTRACT_SCRIPT="plugins/loom-maintenance/scripts/extract-proposals.sh"
SKILL_FILE="plugins/loom-maintenance/skills/framework-updater/SKILL.md"

echo "═══ Additive Update Framework Contract Tests ═══"
echo ""

# ── Sync Reference Tests ──
echo "Sync reference tracking"
assert ".sdd-sync-ref exists" "[ -f $SYNC_REF_FILE ]"
assert ".sdd-sync-ref contains a commit hash" \
  "grep -qE '^[0-9a-f]{7,40}$' $SYNC_REF_FILE"
# The sync-ref is upstream bookkeeping that MUST travel with the clone — if it
# were ignored, every cloner would lose their update baseline. A missing
# .gitignore trivially satisfies this, which is correct: nothing is ignored.
assert ".sdd-sync-ref is not in .gitignore" \
  "! grep -q 'sdd-sync-ref' .gitignore 2>/dev/null"

# ── Extract Proposals Script ──
echo ""
echo "Proposal extraction"
assert "extract-proposals.sh exists" "[ -f $EXTRACT_SCRIPT ]"
assert "extract-proposals.sh is executable" "[ -x $EXTRACT_SCRIPT ]"

# Test script help/usage (should not error with no args)
HELP_EXIT=0
bash "$EXTRACT_SCRIPT" --help >/dev/null 2>&1 || HELP_EXIT=$?
assert "extract-proposals.sh responds to --help" "[ $HELP_EXIT -eq 0 ]"

# Test with dry-run.
# NOTE: --dry-run performs a live `git fetch` of the configured upstream. Output
# is captured to a file (not interpolated into the eval'd assert condition) so
# arbitrary command output can never break or rewrite the assertion.
DRY_OUT_FILE=$(mktemp "${TMPDIR:-/tmp}/loom-dryrun.XXXXXX")
trap 'rm -f "$DRY_OUT_FILE"' EXIT
DRY_EXIT=0
bash "$EXTRACT_SCRIPT" --dry-run >"$DRY_OUT_FILE" 2>&1 || DRY_EXIT=$?

# Invariant 1 (network-independent): --dry-run is a distinct mode that reports
# status. It must NEVER fall through to the default branch and emit proposals.
assert "extract-proposals.sh --dry-run emits no proposal JSON" \
  "! grep -q '\"id\": \"EP-' \"\$DRY_OUT_FILE\""

# Invariant 2: on a successful dry run the report names the upstream it fetched
# AND the sync-ref baseline it compared against — the two facts the mode exists
# to surface. Requires network + a configured upstream; if the fetch could not
# run we SKIP loudly rather than assert something that passes on anything.
if [ "$DRY_EXIT" -eq 0 ]; then
  assert "extract-proposals.sh --dry-run names the fetch-only upstream" \
    "grep -q '^Upstream (fetch-only, no remote): http' \"\$DRY_OUT_FILE\""
  assert "extract-proposals.sh --dry-run reports the sync-ref baseline" \
    "grep -qE '^(Current sync-ref: [0-9a-f]{7,40}|No \.sdd-sync-ref yet)' \"\$DRY_OUT_FILE\""
else
  skip "extract-proposals.sh --dry-run status report" \
    "dry-run exited $DRY_EXIT (upstream unconfigured or fetch failed); cannot assert on its report"
fi

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
# 'release|tag' matched almost any help text. The contract is that --help
# documents the release_tag field callers group proposals by, so assert that.
assert "Help text documents the release_tag field" \
  "bash \"\$EXTRACT_SCRIPT\" --help 2>&1 | grep -q 'release_tag'"

# ── Update Command ──
echo ""
echo "Update framework command"
assert "update-framework command exists" \
  "[ -f plugins/loom-maintenance/commands/update-framework.md ]"
assert "update-framework references proposal-based flow" \
  "grep -qi 'proposal\|enhancement' plugins/loom-maintenance/commands/update-framework.md"

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
exit $FAIL
