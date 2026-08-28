#!/usr/bin/env bash
# Contract Tests: Cross-Check Disposition tandem coherence
# Asserts the canonical Cross-Check Disposition appears verbatim in BOTH
# AGENTS.md (Tier 1) and CLAUDE.md (Standing policies), that AGENTS.md is
# two-tiered with the in-band Enforcement-Reality banner, and that the
# bidirectional cross-references resolve. Converts the tandem-update prose rule
# into a CI gate so the two files cannot drift.
set -euo pipefail

PASS=0; FAIL=0; TOTAL=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

AGENTS="AGENTS.md"; CLAUDE="CLAUDE.md"
# THE THIRD COPY. The adopt package ships its own authored governance rule to an
# adopter's repo, so the Disposition now lives in three files, not two. It is
# authored rather than extracted, which is exactly the condition under which
# silent drift happens — so the tandem gate covers it too.
#
# Held to the SAME standard and skipped on the same terms as the adopt suites
# beside it: `packaging` is a template-strip-manifest entry, so on a stripped or
# customer tree the file does not exist and its absence is not a failure.
PAYLOAD_RULE="packaging/adopt/payload/rules/logicloom-governance.md"
CHECK_PAYLOAD=no
if [ -f "$PAYLOAD_RULE" ]; then CHECK_PAYLOAD=yes
elif git ls-files --error-unmatch "$PAYLOAD_RULE" >/dev/null 2>&1; then CHECK_PAYLOAD=yes; fi

echo "═══ Cross-Check Disposition Tandem Coherence ═══"
echo ""

# Canonical disposition core sentences — must be byte-identical in both files.
N1="default to a decorrelated second look from a DIFFERENT-PROVIDER model rather than reviewing your own output in-lineage"
N2="a same-lineage self-review shares your blind spots"
N3="On any host where you are the ONLY model reachable, a self-review is NOT decorrelation"

echo "Canonical disposition present in both files"
assert "core sentence 1 in AGENTS.md" "grep -qF \"\$N1\" $AGENTS"
assert "core sentence 1 in CLAUDE.md" "grep -qF \"\$N1\" $CLAUDE"
assert "core sentence 2 in AGENTS.md" "grep -qF \"\$N2\" $AGENTS"
assert "core sentence 2 in CLAUDE.md" "grep -qF \"\$N2\" $CLAUDE"
assert "off-host honesty sentence in AGENTS.md" "grep -qF \"\$N3\" $AGENTS"
assert "off-host honesty sentence in CLAUDE.md" "grep -qF \"\$N3\" $CLAUDE"
if [ "$CHECK_PAYLOAD" = yes ]; then
  assert "adopt payload rule exists (it is tracked, so it must be on disk)" "[ -f \"$PAYLOAD_RULE\" ]"
  assert "core sentence 1 in the adopt payload rule" "grep -qF \"\$N1\" \"$PAYLOAD_RULE\""
  assert "core sentence 2 in the adopt payload rule" "grep -qF \"\$N2\" \"$PAYLOAD_RULE\""
  assert "off-host honesty sentence in the adopt payload rule" "grep -qF \"\$N3\" \"$PAYLOAD_RULE\""
else
  echo "  ⏭  SKIP: no adopt payload rule and none tracked — stripped or customer tree."
fi

echo ""
echo "AGENTS.md two-tier structure"
assert "AGENTS.md has Tier 1 heading" "grep -qE '^# Tier 1 — Operating Principles' $AGENTS"
assert "AGENTS.md has Tier 2 heading" "grep -qE '^# Tier 2 — Host Implementation' $AGENTS"
assert "AGENTS.md has in-band Enforcement-Reality banner" "grep -q 'Enforcement reality on this host' $AGENTS"
assert "AGENTS.md Tier 1 carries self-enforced git rule" "grep -q 'VI Git Approval (self-enforced)' $AGENTS"

echo ""
echo "Bidirectional cross-references resolve"
assert "CLAUDE.md points to AGENTS.md Tier 1 as neutral source" "grep -q 'AGENTS.md Tier 1' $CLAUDE"
assert "CLAUDE.md records the portability supersession" "grep -q 'superseded stance' $CLAUDE"
assert "AGENTS.md points to the threat-model matrix" "grep -q 'governance-threat-model.md' $AGENTS"
assert "threat-model has the enforced-vs-followed matrix" "grep -q 'enforced-vs-followed' .docs/architecture/governance-threat-model.md"

# NOTE: provenance/ID-marker scanning of shipped files is leak-guard.sh's job
# (the promote-time sanitization audit), NOT this contract test's — hardcoding
# the marker patterns here would itself trip leak-guard on the shipped tree.

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
