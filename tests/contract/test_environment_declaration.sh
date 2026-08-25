#!/usr/bin/env bash
# Contract Tests: environment declaration schema + validator
#
# Guards the §8.3 boundary: the harness ships the DECLARATION and the GATE
# STRUCTURE only. It ships no deploy execution, no cloud/CI integration, and no
# environment branches. This suite asserts both halves:
#
#   1. the validator parses, validates, and reports (absent / valid / cycle /
#      missing predecessor / duplicate / unknown key / confirm / seed allowlist)
#   2. the validator never deploys and never runs git, never READS the declared
#      seed allowlist, and the shipped config declares nothing active
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

VALIDATOR="$ROOT/.logic-loom/scripts/bash/validate-environments.sh"
CONF="$ROOT/.logic-loom/config/environments.conf"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Contract Tests: Environment Declaration (§8.3)           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# ── 1. Files exist and are syntactically sound ───────────────────────────────
echo "1. Schema + validator present"
assert "environments.conf exists" "[ -f '$CONF' ]"
assert "validate-environments.sh exists" "[ -f '$VALIDATOR' ]"
assert "validator passes bash -n" "bash -n '$VALIDATOR' >/dev/null 2>&1"
echo ""

# ── 2. Shipped config declares nothing active ────────────────────────────────
# An active declaration would assert a branch topology the cloner does not have
# — the same defect class as a policy describing a repo that does not exist.
echo "2. Shipped config is an example, not an active topology"
SHIPPED_OUT="$(bash "$VALIDATOR" "$CONF" 2>&1)"; SHIPPED_RC=$?
assert "shipped config validates clean (exit 0)" "[ $SHIPPED_RC -eq 0 ]"
assert "shipped config declares no environments" \
  "grep -q 'none declared' <<< \"\$SHIPPED_OUT\""
assert "shipped config has no uncommented 'environment =' line" \
  "! grep -E '^[[:space:]]*environment[[:space:]]*=' '$CONF' >/dev/null 2>&1"
echo ""

# ── 3. Absent config is normal, not an error ─────────────────────────────────
echo "3. Absent declaration exits 0"
ABSENT_OUT="$(bash "$VALIDATOR" "$TMP/nope.conf" 2>&1)"; ABSENT_RC=$?
assert "absent config exits 0" "[ $ABSENT_RC -eq 0 ]"
assert "absent config says so informationally" \
  "grep -q 'nothing declared' <<< \"\$ABSENT_OUT\""
echo ""

# ── 4. A valid three-environment chain reports its promotion order ───────────
echo "4. Valid declaration reports the promotion order"
cat > "$TMP/valid.conf" <<'CONF_EOF'
environment       = dev
branch            = main
requires_approval = false
deploy            = web/scripts/deploy-dev.sh

environment       = staging
branch            = release
promotes_from     = dev
requires_approval = false

environment       = prod
branch            = release
promotes_from     = staging
requires_approval = true
deploy            = web/scripts/deploy-prod.sh
CONF_EOF
VALID_OUT="$(bash "$VALIDATOR" "$TMP/valid.conf" 2>&1)"; VALID_RC=$?
assert "valid declaration exits 0" "[ $VALID_RC -eq 0 ]"
assert "reports 3 declared environments" \
  "grep -q '3 declared' <<< \"\$VALID_OUT\""
assert "orders dev first" "grep -q '1\. dev' <<< \"\$VALID_OUT\""
assert "orders staging second" "grep -q '2\. staging' <<< \"\$VALID_OUT\""
assert "orders prod third" "grep -q '3\. prod' <<< \"\$VALID_OUT\""
assert "surfaces the approval gate on prod" \
  "grep -q 'APPROVAL REQUIRED' <<< \"\$VALID_OUT\""
assert "names the deploy seam as product-owned / absent" \
  "grep -q 'deploy seam' <<< \"\$VALID_OUT\""
echo ""

# ── 5. Cycle in the promotion order ──────────────────────────────────────────
echo "5. Cycle detection"
cat > "$TMP/cycle.conf" <<'CONF_EOF'
environment   = a
promotes_from = c

environment   = b
promotes_from = a

environment   = c
promotes_from = b
CONF_EOF
CYCLE_OUT="$(bash "$VALIDATOR" "$TMP/cycle.conf" 2>&1)"; CYCLE_RC=$?
assert "cycle exits nonzero" "[ $CYCLE_RC -ne 0 ]"
assert "cycle message says 'cycle'" \
  "grep -q 'cycle in promotion order' <<< \"\$CYCLE_OUT\""
assert "cycle message names the members" \
  "grep -q 'a' <<< \"\$CYCLE_OUT\" && grep -q 'b' <<< \"\$CYCLE_OUT\" && grep -q 'c' <<< \"\$CYCLE_OUT\""
echo ""

# ── 6. Predecessor that is not declared ──────────────────────────────────────
echo "6. Missing predecessor"
cat > "$TMP/missingpred.conf" <<'CONF_EOF'
environment   = dev
branch        = main

environment   = prod
promotes_from = staging
CONF_EOF
MP_OUT="$(bash "$VALIDATOR" "$TMP/missingpred.conf" 2>&1)"; MP_RC=$?
assert "missing predecessor exits nonzero" "[ $MP_RC -ne 0 ]"
assert "missing predecessor names the missing env" \
  "grep -q \"predecessor 'staging'\" <<< \"\$MP_OUT\""
echo ""

# ── 7. Duplicate environment name ────────────────────────────────────────────
echo "7. Duplicate environment name"
cat > "$TMP/dupe.conf" <<'CONF_EOF'
environment = dev
branch      = main

environment = dev
branch      = other
CONF_EOF
DUP_OUT="$(bash "$VALIDATOR" "$TMP/dupe.conf" 2>&1)"; DUP_RC=$?
assert "duplicate name exits nonzero" "[ $DUP_RC -ne 0 ]"
assert "duplicate name is reported" \
  "grep -q 'duplicate environment name' <<< \"\$DUP_OUT\""
echo ""

# ── 8. Unknown key WARNS, never fails ────────────────────────────────────────
# Deliberate, and consistent with the sibling configs: governance.conf skips
# lines it does not recognise rather than failing. This validator does the same
# but says so out loud, because a typo'd key here silently does nothing.
echo "8. Unknown key warns but does not fail"
cat > "$TMP/unknown.conf" <<'CONF_EOF'
environment       = dev
branch            = main
region            = us-east-1
requires_approval = false
CONF_EOF
UNK_OUT="$(bash "$VALIDATOR" "$TMP/unknown.conf" 2>&1)"; UNK_RC=$?
assert "unknown key exits 0 (warning, not error)" "[ $UNK_RC -eq 0 ]"
assert "unknown key is warned about by name" \
  "grep -q \"unknown key 'region'\" <<< \"\$UNK_OUT\""
assert "unknown key does not suppress the report" \
  "grep -q 'Promotion order' <<< \"\$UNK_OUT\""
echo ""

# ── 9. Invalid requires_approval is an ERROR ─────────────────────────────────
echo "9. Invalid requires_approval"
cat > "$TMP/badappr.conf" <<'CONF_EOF'
environment       = dev
requires_approval = maybe
CONF_EOF
BA_OUT="$(bash "$VALIDATOR" "$TMP/badappr.conf" 2>&1)"; BA_RC=$?
assert "invalid requires_approval exits nonzero" "[ $BA_RC -ne 0 ]"
assert "invalid requires_approval is reported" \
  "grep -q 'requires_approval must be' <<< \"\$BA_OUT\""
echo ""

# ── 10. Key outside any environment block is an ERROR ────────────────────────
echo "10. Orphan key outside a block"
cat > "$TMP/orphan.conf" <<'CONF_EOF'
branch = main

environment = dev
CONF_EOF
OR_OUT="$(bash "$VALIDATOR" "$TMP/orphan.conf" 2>&1)"; OR_RC=$?
assert "orphan key exits nonzero" "[ $OR_RC -ne 0 ]"
assert "orphan key is reported as belonging to no environment" \
  "grep -q 'belongs to no environment' <<< \"\$OR_OUT\""
echo ""

# ── 11. The boundary: no deploy execution, no git, no branch creation ────────
echo "11. Harness boundary — declaration only"
assert "validator invokes no git command" \
  "! grep -nE '(^|[^[:alnum:]_])git[[:space:]]+(add|commit|push|checkout|switch|branch|merge|tag|reset|clean|rebase)' '$VALIDATOR' >/dev/null 2>&1"
assert "validator never executes a declared deploy value" \
  "! grep -nE '(bash|sh|exec|eval|source|\\.)[[:space:]]+\"?\\\$(cur_)?deploy' '$VALIDATOR' >/dev/null 2>&1"
assert "validator declares itself read-only in its header" \
  "grep -q 'read-only by construction' '$VALIDATOR'"
assert "config states the harness ships no deploy execution" \
  "grep -q 'ships NO deploy execution' '$CONF'"
assert "config marks deploy as the product-owned seam" \
  "grep -q 'PRODUCT-owned script' '$CONF'"
assert "deployment policy documents the declaration" \
  "grep -q 'environments.conf' '$ROOT/.docs/policies/deployment-policy.md'"
assert "deployment policy states the harness runs no deploys" \
  "grep -qi 'no deploy execution' '$ROOT/.docs/policies/deployment-policy.md'"
echo ""

# ── 12. `confirm` — the escalating-confirm declaration ───────────────────────
# Declaration only. The harness prompts for nothing; this key names the strength
# a PRODUCT promotion script is expected to implement.
# Policy: .docs/policies/environment-promotion-policy.md § 4.3
echo "12. confirm: none | prompt | typed:<PHRASE>"
cat > "$TMP/confirm.conf" <<'CONF_EOF'
environment       = dev
confirm           = none

environment       = staging
promotes_from     = dev
confirm           = prompt

environment              = prod
promotes_from            = staging
requires_approval        = true
confirm                  = typed:PROMOTE TO PRODUCTION
CONF_EOF
CF_OUT="$(bash "$VALIDATOR" "$TMP/confirm.conf" 2>&1)"; CF_RC=$?
assert "valid confirm ladder exits 0" "[ $CF_RC -eq 0 ]"
assert "confirm is not treated as an unknown key" \
  "! grep -q \"unknown key 'confirm'\" <<< \"\$CF_OUT\""
assert "reports the typed phrase verbatim" \
  "grep -q 'PROMOTE TO PRODUCTION' <<< \"\$CF_OUT\""
assert "says no flag may bypass the typed phrase" \
  "grep -q 'no flag may bypass' <<< \"\$CF_OUT\""
assert "reports the skippable prompt tier" \
  "grep -q 'skippable' <<< \"\$CF_OUT\""
echo ""

# ── 13. confirm errors — fail closed with a typed reason ─────────────────────
echo "13. confirm: invalid values and the approval coherence rule"
printf 'environment = dev\nconfirm = maybe\n' > "$TMP/confbad.conf"
CB_OUT="$(bash "$VALIDATOR" "$TMP/confbad.conf" 2>&1)"; CB_RC=$?
assert "invalid confirm value exits nonzero" "[ $CB_RC -ne 0 ]"
assert "invalid confirm value names the allowed forms" \
  "grep -q \"confirm must be 'none', 'prompt', or 'typed:<PHRASE>'\" <<< \"\$CB_OUT\""

printf 'environment = prod\nrequires_approval = true\nconfirm = typed:\n' > "$TMP/confempty.conf"
CE_OUT="$(bash "$VALIDATOR" "$TMP/confempty.conf" 2>&1)"; CE_RC=$?
assert "typed: with no phrase exits nonzero (never degrades to prompt)" "[ $CE_RC -ne 0 ]"
assert "typed: with no phrase says a phrase is needed" \
  "grep -q 'needs a phrase' <<< \"\$CE_OUT\""

# A typed phrase IS an approval. Declaring one alongside requires_approval=false
# is a self-contradicting declaration and must fail closed, naming both keys.
printf 'environment = prod\nrequires_approval = false\nconfirm = typed:GO\n' > "$TMP/confincoh.conf"
CI_OUT="$(bash "$VALIDATOR" "$TMP/confincoh.conf" 2>&1)"; CI_RC=$?
assert "typed phrase without requires_approval exits nonzero" "[ $CI_RC -ne 0 ]"
assert "incoherence names both keys and the two remedies" \
  "grep -q 'requires_approval' <<< \"\$CI_OUT\" && grep -q \"lower confirm to 'prompt'\" <<< \"\$CI_OUT\""

# The REVERSE pairing is legitimate, not an error: an environment gated by a CI
# approval (a reviewer on a protected environment) rather than a terminal prompt.
printf 'environment = prod\nrequires_approval = true\nconfirm = none\n' > "$TMP/confok.conf"
CO_OUT="$(bash "$VALIDATOR" "$TMP/confok.conf" 2>&1)"; CO_RC=$?
assert "requires_approval=true with confirm=none is VALID (CI gate, not a prompt)" "[ $CO_RC -eq 0 ]"
echo ""

# ── 14. rehearsal_seed_allowlist — a seam, never read ────────────────────────
# The allowlist is a PRODUCT-owned file. The harness records where it lives and
# nothing else: it never opens it, parses it, or counts it. Its fail-closed-on-
# empty behaviour is the product seed script's to implement.
# Policy: .docs/policies/environment-promotion-policy.md § 4.4
echo "14. rehearsal_seed_allowlist is a declared seam, never read"
mkdir -p "$TMP/seedroot"
printf 'SENTINEL_ACCOUNT_MUST_NOT_BE_READ\n' > "$TMP/seedroot/allowlist.txt"
cat > "$TMP/seed.conf" <<'CONF_EOF'
environment              = staging
rehearsal_seed_allowlist = allowlist.txt
CONF_EOF
SD_OUT="$(bash "$VALIDATOR" "$TMP/seed.conf" --root "$TMP/seedroot" 2>&1)"; SD_RC=$?
assert "declared allowlist exits 0" "[ $SD_RC -eq 0 ]"
assert "allowlist is not treated as an unknown key" \
  "! grep -q \"unknown key 'rehearsal_seed_allowlist'\" <<< \"\$SD_OUT\""
assert "allowlist path is reported" \
  "grep -q 'rehearsal seed allowlist: allowlist.txt' <<< \"\$SD_OUT\""
assert "present allowlist is reported as present" \
  "grep -q 'present' <<< \"\$SD_OUT\""
assert "the allowlist CONTENTS never reach the output (never read)" \
  "! grep -q 'SENTINEL_ACCOUNT_MUST_NOT_BE_READ' <<< \"\$SD_OUT\""

cat > "$TMP/seedabsent.conf" <<'CONF_EOF'
environment              = staging
rehearsal_seed_allowlist = nowhere/allowlist.txt
CONF_EOF
SA_OUT="$(bash "$VALIDATOR" "$TMP/seedabsent.conf" --root "$TMP/seedroot" 2>&1)"; SA_RC=$?
assert "absent allowlist still exits 0 (declaration, not a gate)" "[ $SA_RC -eq 0 ]"
assert "absent allowlist says the seed must ABORT, never widen" \
  "grep -q 'ABORT' <<< \"\$SA_OUT\""

# An environment with no allowlist declared prints no allowlist line at all.
assert "undeclared allowlist prints no allowlist line" \
  "! grep -q 'rehearsal seed allowlist' <<< \"\$VALID_OUT\""

assert "validator never cats/parses the declared allowlist path" \
  "! grep -nE '(cat|wc|awk|sed|head|tail|source|eval)[[:space:]]+\"?\\\$ROOT/\\\$seed' '$VALIDATOR' >/dev/null 2>&1"
assert "config documents the allowlist as fail-closed and never read" \
  "grep -q 'NEVER reads this file' '$CONF'"
assert "promotion policy exists and names both new keys" \
  "grep -q 'rehearsal_seed_allowlist' '$ROOT/.docs/policies/environment-promotion-policy.md' && grep -q 'confirm' '$ROOT/.docs/policies/environment-promotion-policy.md'"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "  Results: $PASS/$TOTAL passed, $FAIL failed"
echo "═══════════════════════════════════════════════════════════"
[ $FAIL -eq 0 ] && exit 0 || exit 1
