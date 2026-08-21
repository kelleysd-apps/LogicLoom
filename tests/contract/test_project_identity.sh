#!/usr/bin/env bash
# Contract Tests: project identity declaration + validator
#
# Guards the per-project SSOT key. Two halves:
#
#   1. the validator parses, validates, and reports (absent / unstamped / valid /
#      bad slug / bad prefix / missing key / duplicate key / unknown key)
#   2. the shipped config declares NO REAL SLUG — a cloner must never inherit
#      `logicloom` (or any plausible-looking value) as their project's identity —
#      and the validator is read-only by construction: no writes, no git.
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

# ── 2. The shipped config declares NO REAL SLUG ──────────────────────────────
# The failure this prevents: every clone silently sharing one identity, which
# makes the identity worthless for exactly the cross-project aggregation it
# exists to enable.
echo "2. Shipped config is a placeholder, not an identity"
assert "shipped project_slug is the __UNSET__ placeholder" \
  "grep -qE '^[[:space:]]*project_slug[[:space:]]*=[[:space:]]*__UNSET__[[:space:]]*\$' '$CONF'"
assert "shipped project_name is the __UNSET__ placeholder" \
  "grep -qE '^[[:space:]]*project_name[[:space:]]*=[[:space:]]*__UNSET__[[:space:]]*\$' '$CONF'"
assert "shipped id_prefix is the __UNSET__ placeholder" \
  "grep -qE '^[[:space:]]*id_prefix[[:space:]]*=[[:space:]]*__UNSET__[[:space:]]*\$' '$CONF'"
assert "shipped config leaks no 'logicloom' slug" \
  "! grep -qiE '^[[:space:]]*project_slug[[:space:]]*=[[:space:]]*logic' '$CONF'"
SHIPPED_OUT="$(bash "$VALIDATOR" "$CONF" 2>&1)"; SHIPPED_RC=$?
assert "shipped config exits 0 (unstamped is normal, not an error)" "[ $SHIPPED_RC -eq 0 ]"
assert "shipped config is reported as UNSTAMPED" \
  "printf '%s' \"\$SHIPPED_OUT\" | grep -q 'UNSTAMPED'"
assert "unstamped is a WARNING, not an ERROR" \
  "printf '%s' \"\$SHIPPED_OUT\" | grep -q '^WARN' && ! printf '%s' \"\$SHIPPED_OUT\" | grep -q '^ERROR'"
echo ""

# ── 3. Absent config exits 0 ─────────────────────────────────────────────────
echo "3. Absent declaration exits 0"
ABSENT_OUT="$(bash "$VALIDATOR" "$TMP/nope.conf" 2>&1)"; ABSENT_RC=$?
assert "absent config exits 0" "[ $ABSENT_RC -eq 0 ]"
assert "absent config says so informationally" \
  "printf '%s' \"\$ABSENT_OUT\" | grep -q 'nothing declared'"
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
assert "reports the slug" "printf '%s' \"\$VALID_OUT\" | grep -q 'acme-widgets'"
assert "reports the display name" "printf '%s' \"\$VALID_OUT\" | grep -q 'ACME Widgets'"
assert "reports the id prefix and how ids mint" \
  "printf '%s' \"\$VALID_OUT\" | grep -q 'ACME-001'"
assert "calls the slug immutable" \
  "printf '%s' \"\$VALID_OUT\" | grep -q 'immutable once set'"
assert "does not claim to have verified the repo" \
  "printf '%s' \"\$VALID_OUT\" | grep -q 'NOT verified'"
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
  "printf '%s' \"\$MISS_OUT\" | grep -q \"required key 'id_prefix' is missing\""
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
  "printf '%s' \"\$BS_OUT\" | grep -q 'invalid project_slug'"

cat > "$TMP/emptyslug.conf" <<'CONF_EOF'
project_slug =
project_name = ACME Widgets
id_prefix    = ACME
CONF_EOF
ES_OUT="$(bash "$VALIDATOR" "$TMP/emptyslug.conf" 2>&1)"; ES_RC=$?
assert "empty slug exits nonzero" "[ $ES_RC -ne 0 ]"
assert "empty slug is reported" \
  "printf '%s' \"\$ES_OUT\" | grep -q 'project_slug is empty'"
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
  "printf '%s' \"\$BP_OUT\" | grep -q 'invalid id_prefix'"

cat > "$TMP/longprefix.conf" <<'CONF_EOF'
project_slug = acme-widgets
project_name = ACME Widgets
id_prefix    = TOOLONGPREFIX
CONF_EOF
LP_OUT="$(bash "$VALIDATOR" "$TMP/longprefix.conf" 2>&1)"; LP_RC=$?
assert "over-long prefix exits nonzero" "[ $LP_RC -ne 0 ]"
assert "over-long prefix reports the length rule" \
  "printf '%s' \"\$LP_OUT\" | grep -q '2 to 6 characters'"
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
  "printf '%s' \"\$DUP_OUT\" | grep -q \"duplicate key 'project_slug'\""
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
  "printf '%s' \"\$UNK_OUT\" | grep -q \"unknown key 'owner'\""
assert "unknown key does not suppress the report" \
  "printf '%s' \"\$UNK_OUT\" | grep -q 'acme-widgets'"
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
