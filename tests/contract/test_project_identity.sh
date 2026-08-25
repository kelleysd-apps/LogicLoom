#!/usr/bin/env bash
# Contract Tests: project identity declaration + validator
#
# Guards the per-project SSOT key. Two halves:
#
#   1. the validator parses, validates, and reports (absent / unstamped / valid /
#      bad slug / bad prefix / missing key / duplicate key / unknown key)
#   2. the config AS SHIPPED — i.e. after the promote-time history scrub — declares
#      NO REAL SLUG. A cloner must never inherit `logicloom` (or any plausible-
#      looking value) as their project's identity — and the validator is
#      read-only by construction: no writes, no git.
#
# WHY SECTION 2 TARGETS A SANITIZED COPY, NOT THE DEV TREE
# -------------------------------------------------------
# LogicLoom is both the harness AND the template source. On dev-main the identity
# IS stamped (`logicloom` / LogicLoom / LOOM) — 29 backlog ids are minted with the
# LOOM prefix and the maintainer's dashboard renders from it. What ships is the
# PROMOTED tree, where history-scrub-rules.json resets all three keys to
# `__UNSET__`. So the cloner-protection assertions are pointed at a real scrubbed
# copy: this suite runs the ACTUAL scrubber (history-scrub.sh, the same script and
# the same rules CI runs at promote) over a one-file fixture tree and asserts on
# its output. Nothing in the repo is written.
#
# HONEST LIMITS (two, both real):
#   a) This proves the SCRUB step resets the keys. It does not prove the promote
#      pipeline invokes history-scrub.sh — that ordering (strip-harness-dev ->
#      sanitize-for-template -> history-scrub -> leak-guard) is asserted by the
#      promote/leak-guard suites, not here. If the scrub step were dropped from
#      promote, this suite would still pass and the identity would ship. Note
#      leak-guard does NOT carry 'logicloom' as a marker, so section 2 is
#      currently the only automated guard on the slug.
#   b) Sections 2 and 2c are HARNESS-DEV ONLY, gated on history-scrub.sh being
#      present. That script and its ruleset are manifest-stripped from the
#      template, so in a clone there is no scrubber to run and no dev identity to
#      assert — and a clone that has run /initialize-project legitimately carries
#      its OWN stamped slug. Asserting `__UNSET__` against a clone's tree (which
#      is what this suite did before) reddens that clone's first CI push. The
#      fixture-based guard in 2d runs in EVERY tree and is not gated.
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

VALIDATOR="$ROOT/.logic-loom/scripts/bash/validate-project-identity.sh"
CONF="$ROOT/.logic-loom/config/project.conf"
TEMPLATE="$ROOT/.logic-loom/templates/plan-template.md"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Contract Tests: Project Identity                         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# ── 1. Files exist and are syntactically sound ───────────────────────────────
echo "1. Schema + validator present"
assert "project.conf exists" "[ -f '$CONF' ]"
assert "validate-project-identity.sh exists" "[ -f '$VALIDATOR' ]"
assert "validator passes bash -n" "bash -n '$VALIDATOR' >/dev/null 2>&1"
echo ""

# ── 2. The config AS SHIPPED declares NO REAL SLUG ───────────────────────────
# The failure this prevents: every clone silently sharing one identity, which
# makes the identity worthless for exactly the cross-project aggregation it
# exists to enable.
#
# "As shipped" = after the promote-time history scrub. Build that tree here by
# running the REAL scrubber over a one-file fixture copy (see the header note for
# why, and for the honest limit). $CONF itself is never modified.
echo "2. The config AS SHIPPED (post-scrub) is a placeholder, not an identity"

SCRUBBER="$ROOT/.logic-loom/scripts/bash/history-scrub.sh"
SCRUB_RULES="$ROOT/.logic-loom/scripts/bash/history-scrub-rules.json"

# Harness-dev tree, or a clone of the shipped template? The scrubber and its
# ruleset are manifest-stripped at promote, so their presence IS the discriminant.
IS_HARNESS_DEV=0
if [ -f "$SCRUBBER" ] && [ -f "$SCRUB_RULES" ]; then IS_HARNESS_DEV=1; fi

if [ "$IS_HARNESS_DEV" -eq 0 ]; then
  echo "  ⏭  SKIP: no history-scrub.sh in this tree — it is stripped from the"
  echo "     shipped template, so there is nothing to scrub and no harness-dev"
  echo "     identity to reset. This project's own project.conf is its own"
  echo "     business (stamped or not); the validator half of this suite still"
  echo "     covers it, and 2d below still proves the guard bites."
  CLONE_OUT="$(bash "$VALIDATOR" "$CONF" 2>&1)"; CLONE_RC=$?
  assert "this tree's project.conf is parseable and non-fatal" "[ $CLONE_RC -eq 0 ]"
  assert "this tree's project.conf does not carry the harness-dev note" \
    "! grep -q 'HARNESS-DEV NOTE' '$CONF'"
  assert "this tree did not inherit the 'logicloom' slug from the template" \
    "! grep -qE '^[[:space:]]*project_slug[[:space:]]*=[[:space:]]*logicloom[[:space:]]*\$' '$CONF'"
  echo ""
else

SANITIZED_ROOT="$TMP/sanitized"
SANITIZED="$SANITIZED_ROOT/.logic-loom/config/project.conf"
mkdir -p "$SANITIZED_ROOT/.logic-loom/config"
cp "$CONF" "$SANITIZED"
SCRUB_OUT="$(LOOM_SCRUB_ROOT="$SANITIZED_ROOT" bash "$SCRUBBER" 2>&1)"; SCRUB_RC=$?

assert "the promote-time scrubber exists" "[ -f '$SCRUBBER' ]"
assert "the scrub ruleset carries a rule block for project.conf" \
  "grep -q '\"path\": \".logic-loom/config/project.conf\"' '$SCRUB_RULES'"
assert "the scrubber ran cleanly over the fixture" "[ $SCRUB_RC -eq 0 ]"
assert "no scrub op for project.conf missed" \
  "grep -q 'project.conf: [0-9]* applied, 0 missed' <<< \"\$SCRUB_OUT\""
assert "the scrub actually changed something (not a vacuous pass)" \
  "! diff -q '$CONF' '$SANITIZED' >/dev/null 2>&1"

# The six cloner-protection assertions, now pointed at the sanitized tree.
assert "shipped project_slug is the __UNSET__ placeholder" \
  "grep -qE '^[[:space:]]*project_slug[[:space:]]*=[[:space:]]*__UNSET__[[:space:]]*\$' '$SANITIZED'"
assert "shipped project_name is the __UNSET__ placeholder" \
  "grep -qE '^[[:space:]]*project_name[[:space:]]*=[[:space:]]*__UNSET__[[:space:]]*\$' '$SANITIZED'"
assert "shipped id_prefix is the __UNSET__ placeholder" \
  "grep -qE '^[[:space:]]*id_prefix[[:space:]]*=[[:space:]]*__UNSET__[[:space:]]*\$' '$SANITIZED'"
assert "shipped config leaks no 'logicloom' slug" \
  "! grep -qiE '^[[:space:]]*project_slug[[:space:]]*=[[:space:]]*logic' '$SANITIZED'"
assert "shipped config leaks no LOOM id_prefix (would collide with our ids)" \
  "! grep -qE '^[[:space:]]*id_prefix[[:space:]]*=[[:space:]]*LOOM[[:space:]]*\$' '$SANITIZED'"
assert "shipped config carries no harness-dev note" \
  "! grep -q 'HARNESS-DEV NOTE' '$SANITIZED'"
SHIPPED_OUT="$(bash "$VALIDATOR" "$SANITIZED" 2>&1)"; SHIPPED_RC=$?
assert "shipped config exits 0 (unstamped is normal, not an error)" "[ $SHIPPED_RC -eq 0 ]"
assert "shipped config is reported as UNSTAMPED" \
  "grep -q 'UNSTAMPED' <<< \"\$SHIPPED_OUT\""
assert "unstamped is a WARNING, not an ERROR" \
  "grep -q '^WARN' <<< \"\$SHIPPED_OUT\" && ! grep -q '^ERROR' <<< \"\$SHIPPED_OUT\""
echo ""

# ── 2c. The dev tree IS stamped ──────────────────────────────────────────────
# Load-bearing: if dev-main ever reverted to __UNSET__, the scrub rule would match
# nothing (test_scrub_rules_match.sh fails a dead rule) and section 2 above would
# become a vacuous pass. Assert the premise out loud.
echo "2c. The dev tree carries this project's real identity"
DEV_OUT="$(bash "$VALIDATOR" "$CONF" 2>&1)"; DEV_RC=$?
assert "dev-tree config is valid" "[ $DEV_RC -eq 0 ]"
assert "dev-tree slug is 'logicloom'" \
  "grep -qE '^[[:space:]]*project_slug[[:space:]]*=[[:space:]]*logicloom[[:space:]]*\$' '$CONF'"
assert "dev-tree id_prefix is 'LOOM' (immutable — ids already minted)" \
  "grep -qE '^[[:space:]]*id_prefix[[:space:]]*=[[:space:]]*LOOM[[:space:]]*\$' '$CONF'"
assert "dev-tree identity is reported as stamped, not UNSTAMPED" \
  "! grep -q 'UNSTAMPED' <<< \"\$DEV_OUT\""
echo ""

fi   # end IS_HARNESS_DEV branch (sections 2 + 2c)

# ── 2d. The guard still BITES — runs in EVERY tree, not harness-dev gated ────
# Retargeting a protection is only honest if the retargeted form still fails on
# the thing it protects against. Feed the same greps a sanitized file that leaked
# our identity and assert every one of them rejects it.
echo "2d. The shipped-config guard rejects a leaked identity"
LEAKED="$TMP/leaked-project.conf"
printf 'project_slug = logicloom\nproject_name = LogicLoom\nid_prefix    = LOOM\n' > "$LEAKED"
assert "a leaked project_slug is caught" \
  "! grep -qE '^[[:space:]]*project_slug[[:space:]]*=[[:space:]]*__UNSET__[[:space:]]*\$' '$LEAKED'"
assert "a leaked project_name is caught" \
  "! grep -qE '^[[:space:]]*project_name[[:space:]]*=[[:space:]]*__UNSET__[[:space:]]*\$' '$LEAKED'"
assert "a leaked id_prefix is caught" \
  "! grep -qE '^[[:space:]]*id_prefix[[:space:]]*=[[:space:]]*__UNSET__[[:space:]]*\$' '$LEAKED'"
assert "the 'no logicloom slug' guard rejects a leaked slug" \
  "grep -qiE '^[[:space:]]*project_slug[[:space:]]*=[[:space:]]*logic' '$LEAKED'"
assert "the 'no LOOM prefix' guard rejects a leaked prefix" \
  "grep -qE '^[[:space:]]*id_prefix[[:space:]]*=[[:space:]]*LOOM[[:space:]]*\$' '$LEAKED'"
LEAK_OUT="$(bash "$VALIDATOR" "$LEAKED" 2>&1)"
assert "the validator reports a leaked identity as STAMPED, not UNSTAMPED" \
  "! grep -q 'UNSTAMPED' <<< \"\$LEAK_OUT\""
echo ""


# ── 3. Absent config exits 0 ─────────────────────────────────────────────────
echo "3. Absent declaration exits 0"
ABSENT_OUT="$(bash "$VALIDATOR" "$TMP/nope.conf" 2>&1)"; ABSENT_RC=$?
assert "absent config exits 0" "[ $ABSENT_RC -eq 0 ]"
assert "absent config says so informationally" \
  "grep -q 'nothing declared' <<< \"\$ABSENT_OUT\""
echo ""

# ── 4. A valid identity reports slug, name, prefix ───────────────────────────
echo "4. Valid declaration reports the identity"
cat > "$TMP/valid.conf" <<'CONF_EOF'
project_slug = acme-widgets
project_name = ACME Widgets
id_prefix    = ACME
repo         = acme/widgets
CONF_EOF
VALID_OUT="$(bash "$VALIDATOR" "$TMP/valid.conf" 2>&1)"; VALID_RC=$?
assert "valid declaration exits 0" "[ $VALID_RC -eq 0 ]"
assert "reports the slug" "grep -q 'acme-widgets' <<< \"\$VALID_OUT\""
assert "reports the display name" "grep -q 'ACME Widgets' <<< \"\$VALID_OUT\""
assert "reports the id prefix and how ids mint" \
  "grep -q 'ACME-001' <<< \"\$VALID_OUT\""
assert "calls the slug immutable" \
  "grep -q 'immutable once set' <<< \"\$VALID_OUT\""
assert "does not claim to have verified the repo" \
  "grep -q 'NOT verified' <<< \"\$VALID_OUT\""
echo ""

# ── 5. Missing required key is an ERROR ──────────────────────────────────────
echo "5. Missing required key"
cat > "$TMP/missing.conf" <<'CONF_EOF'
project_slug = acme-widgets
project_name = ACME Widgets
CONF_EOF
MISS_OUT="$(bash "$VALIDATOR" "$TMP/missing.conf" 2>&1)"; MISS_RC=$?
assert "missing required key exits nonzero" "[ $MISS_RC -ne 0 ]"
assert "missing required key names the key" \
  "grep -q \"required key 'id_prefix' is missing\" <<< \"\$MISS_OUT\""
echo ""

# ── 6. Slug must be a safe machine token ─────────────────────────────────────
echo "6. Slug format"
cat > "$TMP/badslug.conf" <<'CONF_EOF'
project_slug = Acme_Widgets!
project_name = ACME Widgets
id_prefix    = ACME
CONF_EOF
BS_OUT="$(bash "$VALIDATOR" "$TMP/badslug.conf" 2>&1)"; BS_RC=$?
assert "bad slug exits nonzero" "[ $BS_RC -ne 0 ]"
assert "bad slug is reported by name" \
  "grep -q 'invalid project_slug' <<< \"\$BS_OUT\""

cat > "$TMP/emptyslug.conf" <<'CONF_EOF'
project_slug =
project_name = ACME Widgets
id_prefix    = ACME
CONF_EOF
ES_OUT="$(bash "$VALIDATOR" "$TMP/emptyslug.conf" 2>&1)"; ES_RC=$?
assert "empty slug exits nonzero" "[ $ES_RC -ne 0 ]"
assert "empty slug is reported" \
  "grep -q 'project_slug is empty' <<< \"\$ES_OUT\""
echo ""

# ── 7. id_prefix format ──────────────────────────────────────────────────────
echo "7. id_prefix format"
cat > "$TMP/badprefix.conf" <<'CONF_EOF'
project_slug = acme-widgets
project_name = ACME Widgets
id_prefix    = a
CONF_EOF
BP_OUT="$(bash "$VALIDATOR" "$TMP/badprefix.conf" 2>&1)"; BP_RC=$?
assert "lowercase/short prefix exits nonzero" "[ $BP_RC -ne 0 ]"
assert "bad prefix is reported by name" \
  "grep -q 'invalid id_prefix' <<< \"\$BP_OUT\""

cat > "$TMP/longprefix.conf" <<'CONF_EOF'
project_slug = acme-widgets
project_name = ACME Widgets
id_prefix    = TOOLONGPREFIX
CONF_EOF
LP_OUT="$(bash "$VALIDATOR" "$TMP/longprefix.conf" 2>&1)"; LP_RC=$?
assert "over-long prefix exits nonzero" "[ $LP_RC -ne 0 ]"
assert "over-long prefix reports the length rule" \
  "grep -q '2 to 6 characters' <<< \"\$LP_OUT\""
echo ""

# ── 8. Duplicate key is an ERROR ─────────────────────────────────────────────
echo "8. Duplicate key"
cat > "$TMP/dupe.conf" <<'CONF_EOF'
project_slug = acme-widgets
project_slug = other-thing
project_name = ACME Widgets
id_prefix    = ACME
CONF_EOF
DUP_OUT="$(bash "$VALIDATOR" "$TMP/dupe.conf" 2>&1)"; DUP_RC=$?
assert "duplicate key exits nonzero" "[ $DUP_RC -ne 0 ]"
assert "duplicate key is reported" \
  "grep -q \"duplicate key 'project_slug'\" <<< \"\$DUP_OUT\""
echo ""

# ── 9. Unknown key WARNS, never fails ────────────────────────────────────────
# Matches the sibling environments.conf disposition: a typo'd key silently does
# nothing, so say so out loud — but do not fail the run over it.
echo "9. Unknown key warns but does not fail"
cat > "$TMP/unknown.conf" <<'CONF_EOF'
project_slug = acme-widgets
project_name = ACME Widgets
id_prefix    = ACME
owner        = someone
CONF_EOF
UNK_OUT="$(bash "$VALIDATOR" "$TMP/unknown.conf" 2>&1)"; UNK_RC=$?
assert "unknown key exits 0 (warning, not error)" "[ $UNK_RC -eq 0 ]"
assert "unknown key is warned about by name" \
  "grep -q \"unknown key 'owner'\" <<< \"\$UNK_OUT\""
assert "unknown key does not suppress the report" \
  "grep -q 'acme-widgets' <<< \"\$UNK_OUT\""
echo ""

# ── 10. The validator writes NOTHING ─────────────────────────────────────────
# Run it against a fixture directory, snapshot before/after, and diff. This is
# the assertion that keeps "read-only by construction" true rather than merely
# claimed in a header comment.
echo "10. Validator performs no writes"
WDIR="$TMP/wtest"
mkdir -p "$WDIR"
cat > "$WDIR/project.conf" <<'CONF_EOF'
project_slug = acme-widgets
project_name = ACME Widgets
id_prefix    = ACME
CONF_EOF
BEFORE="$TMP/before.txt"; AFTER="$TMP/after.txt"
( cd "$WDIR" && find . -type f -exec shasum {} \; | sort ) > "$BEFORE" 2>/dev/null
bash "$VALIDATOR" "$WDIR/project.conf" --root "$WDIR" >/dev/null 2>&1
( cd "$WDIR" && find . -type f -exec shasum {} \; | sort ) > "$AFTER" 2>/dev/null
assert "fixture directory is byte-identical after a run" "diff -q '$BEFORE' '$AFTER' >/dev/null"
assert "validator created no new files in the fixture dir" \
  "[ \"\$(find '$WDIR' -type f | wc -l | tr -d ' ')\" = '1' ]"
assert "validator declares itself read-only in its header" \
  "grep -q 'read-only by construction' '$VALIDATOR'"
echo ""

# ── 11. The validator invokes NO git ─────────────────────────────────────────
# Named because `repo` is tempting to auto-populate from `git remote`. Doing so
# would put a git invocation inside a validator that runs on every init — and
# Principle VI keeps git in the main agent's hands, on explicit request.
echo "11. Validator invokes no git"
# Match git at a COMMAND position (line start, or after ; | & ( ` $( ) — the file
# names `git remote` in prose on purpose, to say the remote is the truth and this
# validator is not the one to ask it.
assert "no git invocation at a command position in the validator" \
  "! grep -nE '(^|[;&|(\`]|\\\$\\()[[:space:]]*git[[:space:]]+[a-z]' '$VALIDATOR' >/dev/null 2>&1"
assert "no gh invocation at a command position in the validator" \
  "! grep -nE '(^|[;&|(\`]|\\\$\\()[[:space:]]*gh[[:space:]]+[a-z]' '$VALIDATOR' >/dev/null 2>&1"
assert "no output redirection onto a file in the validator" \
  "! grep -nE '(^|[^0-9<>])>[[:space:]]*\"?\\\$(CONF|ROOT)' '$VALIDATOR' >/dev/null 2>&1"
assert "config states nothing here is enforced" \
  "grep -q 'NOTHING HERE IS ENFORCED' '$CONF'"
assert "config states the slug is immutable once set" \
  "grep -q 'IMMUTABLE ONCE SET' '$CONF'"
echo ""

# ── 12. Plan template: closed status vocabulary + blocked_on ─────────────────
echo "12. Plan template task schema"
assert "plan template exists" "[ -f '$TEMPLATE' ]"
assert "documents the closed status vocabulary" \
  "grep -q 'open | in_progress | blocked | done' '$TEMPLATE'"
assert "documents that absent status means open" \
  "grep -qi 'DEFAULT when the key is absent' '$TEMPLATE'"
assert "declares a status on a task in the frontmatter" \
  "grep -qE '^[[:space:]]*status:[[:space:]]*(open|in_progress|blocked|done)' '$TEMPLATE'"
assert "declares blocked_on on a task in the frontmatter" \
  "grep -qE '^[[:space:]]*blocked_on:' '$TEMPLATE'"
assert "distinguishes blocked_on from depends_on" \
  "grep -q 'ORDERING' '$TEMPLATE' && grep -q 'LIVE IMPEDIMENT' '$TEMPLATE'"
assert "records what was deliberately excluded from the schema" \
  "grep -qi 'owners, estimates, percent-complete' '$TEMPLATE'"
# No status value outside the closed vocabulary may appear in the frontmatter.
BADSTATUS="$(grep -nE '^[[:space:]]*status:' "$TEMPLATE" \
  | grep -vE '^[0-9]+:[[:space:]]*status:[[:space:]]*(open|in_progress|blocked|done)([[:space:]]|#|$)' || true)"
assert "no status value outside the closed vocabulary" "[ -z \"\$BADSTATUS\" ]"
echo ""

# ── 13. Initialization stamps the identity ───────────────────────────────────
# Without this, the file ships unstamped forever and the identity never exists.
echo "13. /initialize-project stamps the identity"
INIT_SH="$ROOT/init-project.sh"
INIT_CMD="$ROOT/plugins/loom-maintenance/commands/initialize-project.md"
INIT_SKILL="$ROOT/plugins/loom-maintenance/skills/project-initialization/SKILL.md"
assert "init-project.sh references project.conf" \
  "grep -q 'config/project.conf' '$INIT_SH'"
assert "init-project.sh guards against re-stamping an existing identity" \
  "grep -q 'already stamped' '$INIT_SH'"
assert "init-project.sh syntax is sound" "bash -n '$INIT_SH' >/dev/null 2>&1"
assert "the command doc has an identity step" \
  "grep -q 'Stamp the Project Identity' '$INIT_CMD'"
assert "the skill doc has an identity step" \
  "grep -q 'Stamp the Project Identity' '$INIT_SKILL'"
assert "the skill doc warns the slug is immutable" \
  "grep -qi 'IMMUTABLE once set' '$INIT_SKILL'"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "  Results: $PASS/$TOTAL passed, $FAIL failed"
echo "═══════════════════════════════════════════════════════════"
[ $FAIL -eq 0 ] && exit 0 || exit 1
