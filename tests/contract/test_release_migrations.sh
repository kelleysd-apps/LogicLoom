#!/usr/bin/env bash
# Contract Tests: the release-migration registry (.logic-loom/config/release-migrations.conf),
# its parser lib (.logic-loom/lib/release-migrations.sh), its script
# (plugins/loom-maintenance/scripts/release-migrations.sh — scan/plan/convert/lint/
# check-release), and the command/SKILL prose that wires it into /update-framework.
#
# Design: /private/tmp/.../scratchpad/deprecated-plugin-migration-design.md
# (§1-13 base; §14 supersedes; §15 "v7 critique disposition" supersedes both and
# is the final word — this suite follows the ACTUAL shipped WP1/WP2 behaviour,
# verified against the live tree, wherever the design's prose and the code differ
# in wording only).
#
# House rules: assert() below; every SKIP prints a reason and counts as a skip,
# never a pass; final line is "Results: N/M passed, F failed, S skipped";
# mktemp -d + trap cleanup; python3 for JSON; provenance via
# tests/lib/tree-provenance.sh. bash 3.2 safe: no associative arrays, no
# mapfile/readarray, no [[ -v ]], no ${v,,}, no `sort -V`.
#
# A NOTE ON A "PROSE PIN PROVES THE INSTRUCTION IS PRESENT IN THE RIGHT STEP,
# NOT THAT IT IS OBEYED" — this suite's §F below is exactly that kind of pin.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0; SKIP=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}
skip() { SKIP=$((SKIP + 1)); echo "  ⏭️  SKIP: $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

# shellcheck source=/dev/null
source "$ROOT/tests/lib/tree-provenance.sh"

REG="$ROOT/.logic-loom/config/release-migrations.conf"
LIB="$ROOT/.logic-loom/lib/release-migrations.sh"
RM="$ROOT/plugins/loom-maintenance/scripts/release-migrations.sh"
RECORDER="$ROOT/plugins/loom-maintenance/scripts/record-update-writes.sh"
CMD_MD="$ROOT/plugins/loom-maintenance/commands/update-framework.md"
SKILL_MD="$ROOT/plugins/loom-maintenance/skills/framework-updater/SKILL.md"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/loom-relmig-test.XXXXXX")"
cleanup() { [ -n "${TMP:-}" ] && rm -rf "$TMP"; }
trap cleanup EXIT

TREE_KIND="$(loom_tree_kind "$ROOT")"

echo "═══════════════════════════════════════════════════════════"
echo "  CONTRACT: release-migration registry / lib / script / prose pins"
echo "  tree kind: $TREE_KIND"
echo "═══════════════════════════════════════════════════════════"

if [ "$TREE_KIND" = "inconsistent" ]; then
  loom_require_consistent_tree "$ROOT" || true
  echo "── refusing to guess: tree provenance is inconsistent ──"
  echo "  RESULTS: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
  exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════
# SECTION A — registry integrity (real tree)
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "A. Registry integrity (real tree)"

assert "registry file exists" "[ -f '$REG' ]"
assert "lib file exists" "[ -f '$LIB' ]"
assert "script file exists" "[ -f '$RM' ]"

if [ -f "$LIB" ]; then
  # shellcheck source=/dev/null
  source "$LIB"
fi

assert "'lint' exits 0 on the real registry" \
  "bash '$RM' lint --root '$ROOT' >'$TMP/a-lint.out' 2>&1"
assert "'lint' reports clean" "grep -q 'lint: clean' '$TMP/a-lint.out'"

DEP_N="$(loom_deprecation_rows "$REG" 2>/dev/null | grep -c . || true)"
MIG_N="$(loom_migration_rows "$REG" 2>/dev/null | grep -c . || true)"
assert "exactly 23 deprecation-kind rows (found $DEP_N)" "[ '$DEP_N' -eq 23 ]"
assert "exactly 25 total rows: 23 deprecation + 2 v7.0.0 content (receipt + KORI-CLASS ladder) (found $MIG_N)" "[ '$MIG_N' -eq 25 ]"

# named fates
assert "sdd-dev-loop is native" \
  "[ \"\$(loom_deprecation_row sdd-dev-loop '$REG' | awk -F'\t' '{print \$3}')\" = native ]"
assert "loom-dev-loop (alias row) is native" \
  "[ \"\$(loom_deprecation_row loom-dev-loop '$REG' | awk -F'\t' '{print \$3}')\" = native ]"
for d in backend database devops frontend performance security testing; do
  assert "sdd-domain-$d is folded" \
    "[ \"\$(loom_deprecation_row sdd-domain-$d '$REG' | awk -F'\t' '{print \$3}')\" = folded ]"
done
for r in sdd-creation sdd-git sdd-maintenance sdd-memory sdd-orchestrator sdd-orchestrator-hook sdd-governance; do
  assert "$r is renamed" \
    "[ \"\$(loom_deprecation_row $r '$REG' | awk -F'\t' '{print \$3}')\" = renamed ]"
done
assert "sdd-debug is removed" \
  "[ \"\$(loom_deprecation_row sdd-debug '$REG' | awk -F'\t' '{print \$3}')\" = removed ]"
assert "sdd-domain-template is removed" \
  "[ \"\$(loom_deprecation_row sdd-domain-template '$REG' | awk -F'\t' '{print \$3}')\" = removed ]"
assert "sdd-marketplace is kind mcp-server" \
  "[ \"\$(loom_deprecation_row sdd-marketplace '$REG' | awk -F'\t' '{print \$1}')\" = mcp-server ]"

# path rows
for p in "src/sdd/__init__.py" ".specify/config/refinement.conf" "plugins/migrate-to-plugins.sh" "plugins/create-domain-plugin.sh"; do
  assert "path row exists: $p" \
    "loom_deprecation_row \"$p\" '$REG' >/dev/null 2>&1"
done
assert "the src/sdd row's name is the FILE, not the directory" \
  "[ \"\$(loom_deprecation_row 'src/sdd/__init__.py' '$REG' | awk -F'\t' '{print \$2}')\" = 'src/sdd/__init__.py' ]"

# v7.0.0 content row
V7ROW="$(loom_migration_row .logicloom-adopt-receipt.json "$REG" 2>/dev/null)" || V7ROW=""
assert "v7.0.0 content row exists (name .logicloom-adopt-receipt.json)" "[ -n \"\$V7ROW\" ]"
V7_KIND="$(printf '%s' "$V7ROW" | awk -F'\t' '{print $1}')"
V7_FATE="$(printf '%s' "$V7ROW" | awk -F'\t' '{print $3}')"
V7_REPL="$(printf '%s' "$V7ROW" | awk -F'\t' '{print $4}')"
V7_DEF="$(printf '%s' "$V7ROW" | awk -F'\t' '{print $5}')"
V7_REL="$(printf '%s' "$V7ROW" | awk -F'\t' '{print $7}')"
V7_NOTE="$(printf '%s' "$V7ROW" | awk -F'\t' '{print $8}')"
assert "v7.0.0 row kind: content" "[ \"\$V7_KIND\" = content ]"
assert "v7.0.0 row fate: absent" "[ \"\$V7_FATE\" = absent ]"
assert "v7.0.0 row replacement starts with pattern:" "case \"\$V7_REPL\" in pattern:*) true;; *) false;; esac"
assert "v7.0.0 row default: PROPOSE" "[ \"\$V7_DEF\" = PROPOSE ]"
assert "v7.0.0 row release: v7.0.0" "[ \"\$V7_REL\" = v7.0.0 ]"
assert "v7.0.0 row note contains proposal:" "case \"\$V7_NOTE\" in *proposal:*) true;; *) false;; esac"
assert "v7.0.0 row note contains why:" "case \"\$V7_NOTE\" in *why:*) true;; *) false;; esac"
V7REL_N="$(loom_migration_rows_for_release v7.0.0 "$REG" 2>/dev/null | grep -c . || true)"
assert "loom_migration_rows_for_release v7.0.0 = 2 rows (receipt + KORI-CLASS ladder)" "[ '$V7REL_N' -eq 2 ]"

# finding 6: the KORI-CLASS row itself
KORIROW="$(loom_migration_row .logic-loom/memory/amendments.md "$REG" 2>/dev/null)" || KORIROW=""
assert "the KORI-CLASS row exists (name .logic-loom/memory/amendments.md)" "[ -n \"\$KORIROW\" ]"
KORI_DEF="$(printf '%s' "$KORIROW" | awk -F'\t' '{print $5}')"
assert "its default is PROPOSE-ADVISORY" "[ \"\$KORI_DEF\" = PROPOSE-ADVISORY ]"

# every plugin:/path: replacement resolves
BAD_REPL="$(bash -c "
  source '$LIB'
  loom_deprecation_rows '$REG' | while IFS=\$'\t' read -r kind name fate repl default first release note; do
    case \"\$repl\" in
      plugin:*) p=\"\${repl#plugin:}\"; [ -d '$ROOT'/\"plugins/\$p\" ] || echo \"plugins/\$p\" ;;
      path:*) p=\"\${repl#path:}\"; [ -e '$ROOT'/\"\$p\" ] || echo \"\$p\" ;;
    esac
  done
")"
assert "every plugin:/path: replacement exists on disk (missing: ${BAD_REPL:-none})" "[ -z \"\$BAD_REPL\" ]"

# no duplicate deprecation names
DUP_NAMES="$(loom_deprecation_rows "$REG" 2>/dev/null | awk -F'\t' '{print $2}' | sort | uniq -d)"
assert "no duplicate names among deprecation rows (dup: ${DUP_NAMES:-none})" "[ -z \"\$DUP_NAMES\" ]"

echo ""
echo "A. lint failures via temporary registries"

mk_reg() { printf '%s\n' "$1" > "$TMP/$2"; }

mk_reg "plugin | x | removed | none | REMOVE | v1.0.0 | v2.0.0" "bad7field.conf"
assert "a 7-field row fails lint, message names 'LINT: line'" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/bad7field.conf' >'$TMP/l1.out' 2>&1; grep -q 'LINT: line' '$TMP/l1.out'"

# Round-5 finding 7 (low): a trailing pipe with nothing after it ('...|v2.0.0|')
# is a 9-field-SHAPED row (the 9th field just happens to be empty) — `read`
# cannot tell that apart from a genuine 8-field row (both leave f9=""), so
# the old `[ -n "$f9" ]` check alone let it through silently, contradicting
# the documented "exactly 8 pipe-separated fields" grammar.
mk_reg "plugin | sdd-rv5g7 | removed | none | REMOVE | v1.0.0 | v2.0.0 | trailing pipe below|" "trailingpipe.conf"
assert "a row with a trailing pipe (empty 9th field) fails lint, message names 'expected exactly 8 pipe-separated fields'" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/trailingpipe.conf' >'$TMP/l1b.out' 2>&1; grep -qF 'expected exactly 8 pipe-separated fields' '$TMP/l1b.out'"
assert "…and loom_migration_rows rejects it too (rc 1, zero rows on stdout)" \
  "! loom_migration_rows '$TMP/trailingpipe.conf' >'$TMP/l1b.rows' 2>/dev/null; [ ! -s '$TMP/l1b.rows' ]"
mk_reg "content | x\\|y.md | present | pattern:foo\\|bar | PROPOSE | - | v9.9.9 | proposal: exercise escaped-pipe field decoding; why: an escaped pipe inside two fields must not be miscounted as a real delimiter" "escapedpipe.conf"
assert "positive control: an escaped '\\|' inside a field is not miscounted as a real delimiter — still exactly 8 real fields, parses and lints clean" \
  "loom_migration_rows '$TMP/escapedpipe.conf' >/dev/null 2>&1 && bash '$RM' lint --root '$ROOT' --registry '$TMP/escapedpipe.conf' >/dev/null 2>&1"

mk_reg "content | x.md | present | pattern:foo | PROPOSE | - | v9.9.9 | no markers here" "badcontent.conf"
assert "a content row without 'why:' fails lint" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/badcontent.conf' >/dev/null 2>&1"

{
  echo "none | - | none | none | - | - | v9.9.9 | nothing changed"
  echo "content | x.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b"
} > "$TMP/badnonesib.conf"
assert "a 'none' row plus a sibling row for the same release fails lint" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/badnonesib.conf' >/dev/null 2>&1"

mk_reg "plugin | x | removed | pattern:foo | REMOVE | v1.0.0 | v2.0.0 | bad replacement kind" "badpluginpattern.conf"
assert "a plugin row using 'pattern:' fails lint" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/badpluginpattern.conf' >/dev/null 2>&1"

{
  echo "plugin | dup-x | removed | none | REMOVE | v1.0.0 | v2.0.0 | first"
  echo "plugin | dup-x | removed | none | REMOVE | v1.0.0 | v2.0.0 | second"
} > "$TMP/baddup.conf"
assert "two plugin rows with the same name fail lint (duplicate deprecation name)" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/baddup.conf' >'$TMP/l5.out' 2>&1; grep -q 'duplicate deprecation name' '$TMP/l5.out'"

mk_reg 'content | x.md | present | pattern:foo\|bar | PROPOSE | - | v9.9.9 | proposal: a; why: b' "escaped.conf"
assert "a content row with an escaped \\| alternation lints CLEAN" \
  "bash '$RM' lint --root '$ROOT' --registry '$TMP/escaped.conf' >/dev/null 2>&1"
ESC_REPL="$(loom_migration_rows "$TMP/escaped.conf" 2>/dev/null | awk -F'\t' '{print $4}')"
assert "the parsed replacement carries a literal | (got: $ESC_REPL)" \
  "[ \"\$ESC_REPL\" = 'pattern:foo|bar' ]"

echo ""
echo "A. round-3 finding 5: a row name must not be absolute or contain a '..'/'.' path segment"
mk_reg "path | ../../../etc/passwd | removed | none | REMOVE | v1.0.0 | v2.0.0 | traversal attempt" "badtraversal.conf"
assert "a row name containing a '..' path segment fails lint, naming the reason" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/badtraversal.conf' >'$TMP/l6.out' 2>&1; grep -q \"must not be absolute or contain a '..'/'.' path segment\" '$TMP/l6.out'"

mk_reg "path | /etc/passwd | removed | none | REMOVE | v1.0.0 | v2.0.0 | absolute path attempt" "badabsolute.conf"
assert "an ABSOLUTE row name fails lint, naming the reason" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/badabsolute.conf' >'$TMP/l7.out' 2>&1; grep -q \"must not be absolute or contain a '..'/'.' path segment\" '$TMP/l7.out'"

if command -v loom_path_traversal_safe >/dev/null 2>&1; then
  assert "loom_path_traversal_safe: rejects '../x'" "! loom_path_traversal_safe '../x'"
  assert "loom_path_traversal_safe: rejects 'a/../b' (a '..' segment mid-path, not just a prefix)" "! loom_path_traversal_safe 'a/../b'"
  assert "loom_path_traversal_safe: rejects '/etc/passwd' (absolute)" "! loom_path_traversal_safe '/etc/passwd'"
  assert "loom_path_traversal_safe: accepts a normal relative path" "loom_path_traversal_safe 'docs/notes.md'"
  assert "loom_path_traversal_safe: accepts the none-row placeholder '-'" "loom_path_traversal_safe '-'"
  assert "loom_path_traversal_safe: does NOT reject '..' as a mere substring of a real filename ('foo..bar')" "loom_path_traversal_safe 'foo..bar'"
else
  skip "loom_path_traversal_safe direct unit checks" "function not defined (lib not sourced, or not yet implemented)"
fi

echo ""
echo "A. round-5 finding 3: loom_path_traversal_safe rejects a bare '.' segment; _loom_lint_name_shell_safe rejects whitespace/shell metacharacters in plugin/mcp-server/path names; build_remove_cmd quotes every printed path"

if command -v loom_path_traversal_safe >/dev/null 2>&1; then
  assert "loom_path_traversal_safe: rejects a bare '.' segment" "! loom_path_traversal_safe '.'"
  assert "loom_path_traversal_safe: rejects 'a/./b' (a '.' segment mid-path, not just the whole name)" "! loom_path_traversal_safe 'a/./b'"
  assert "loom_path_traversal_safe: does NOT reject '.' as a mere substring of a real filename ('foo.bar')" "loom_path_traversal_safe 'foo.bar'"

  # Regression guard: reproduce the PRE-FIX shape (only '..' segments were
  # rejected, never a bare '.') as a plain shell function defined here in
  # the test — never touching the shipped lib — to prove the fix is a real
  # behavior change, not a tautological re-statement of it. A 'plugin | . |
  # removed | ...' row, pre-fix, would have built `git rm -r plugins/.`
  # (== plugins/ itself, every plugin in the tree) instead of failing lint.
  _pre_fix_traversal_safe() {
      local path="$1"
      case "$path" in /*) return 1 ;; esac
      [ "$path" = '-' ] && return 0
      local seg old_ifs="$IFS"
      IFS='/'
      for seg in $path; do
          if [ "$seg" = ".." ]; then IFS="$old_ifs"; return 1; fi
      done
      IFS="$old_ifs"
      return 0
  }
  PRE_FIX_DOT_RESULT="rejected"
  _pre_fix_traversal_safe '.' && PRE_FIX_DOT_RESULT="accepted"
  assert "regression guard: the PRE-FIX '..'-only check would have WRONGLY accepted a bare '.' segment (proves finding 3's dot-fix is a real behavior change)" \
    "[ \"\$PRE_FIX_DOT_RESULT\" = accepted ]"
  unset -f _pre_fix_traversal_safe
else
  skip "loom_path_traversal_safe '.' segment checks" "function not defined (lib not sourced, or not yet implemented)"
fi

if command -v _loom_lint_name_shell_safe >/dev/null 2>&1; then
  assert "_loom_lint_name_shell_safe: rejects a plugin name containing a space" "! _loom_lint_name_shell_safe plugin 'evil name'"
  assert "_loom_lint_name_shell_safe: rejects a path name containing a semicolon" "! _loom_lint_name_shell_safe path 'docs/evil;rm'"
  assert "_loom_lint_name_shell_safe: rejects an mcp-server name containing a backtick" "! _loom_lint_name_shell_safe mcp-server 'evil\`id\`'"
  assert "_loom_lint_name_shell_safe: rejects a path name containing a single quote" "! _loom_lint_name_shell_safe path \"evil'name\""
  assert "_loom_lint_name_shell_safe: accepts a normal plugin name" "_loom_lint_name_shell_safe plugin sdd-debug"
  assert "_loom_lint_name_shell_safe: accepts a normal nested path name" "_loom_lint_name_shell_safe path docs/notes.md"
  assert "_loom_lint_name_shell_safe: is exempt for content-kind rows (glob patterns legitimately use metacharacters like '*')" "_loom_lint_name_shell_safe content 'docs/*.md'"
else
  skip "_loom_lint_name_shell_safe direct unit checks" "function not defined (lib not sourced, or not yet implemented)"
fi

mk_reg "path | docs/evil name.md | removed | none | REMOVE | v1.0.0 | v2.0.0 | whitespace in name" "badspace.conf"
assert "a row name containing whitespace fails lint, naming the reason" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/badspace.conf' >'$TMP/l11.out' 2>&1; grep -q \"must contain only letters, digits, '.', '_', '/', '-'\" '$TMP/l11.out'"

mk_reg "plugin | evil;name | removed | none | REMOVE | v1.0.0 | v2.0.0 | shell metachar in name" "badmeta.conf"
assert "a plugin name containing a shell metacharacter fails lint, naming the reason" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/badmeta.conf' >'$TMP/l12.out' 2>&1; grep -q \"must contain only letters, digits, '.', '_', '/', '-'\" '$TMP/l12.out'"

mk_reg "path | old/thing.md | renamed | path:new/evil name.md | MOVE | v1.0.0 | v2.0.0 | whitespace in replacement path" "badmovespace.conf"
assert "a MOVE row whose REPLACEMENT path contains whitespace also fails lint (not just the name field)" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/badmovespace.conf' >'$TMP/l13.out' 2>&1; grep -q \"replacement path 'new/evil name.md' must contain only\" '$TMP/l13.out'"

# shell_quote/build_remove_cmd live in $RM (release-migrations.sh), not
# $LIB — source $RM in a subshell (same technique the finding-4/6 unit
# tests below use) so main() never runs and nothing leaks into this file's
# own shell.
#
# shell_quote itself: round-trips a name containing an embedded single
# quote back to the original string through eval — the exact property
# build_remove_cmd/REC_MOVE_CMD depend on. Reproduction: the shipped
# function used a `${s//\'/\'\\\'\'}` parameter-substitution one-liner that
# LOOKS like the standard close-escape-reopen POSIX quoting idiom but,
# empirically, bash does not expand its backslashes that way — it emitted
# an unbalanced `\'\\'\'` for one embedded quote, which does not even
# `eval` back to a single token (found while adding this coverage; fixed
# via `sed`, already a floor-safe dependency this file uses elsewhere).
SQ_RESULT="$(
  source "$RM" --root "$ROOT" >/dev/null 2>&1
  sq_input="it's got a quote"
  sq_quoted="$(shell_quote "$sq_input")"
  eval "printf '%s' $sq_quoted" 2>/dev/null
)"
assert "shell_quote: round-trips a name with an embedded single quote through eval back to the original string" \
  "[ \"\$SQ_RESULT\" = \"it's got a quote\" ]"

# build_remove_cmd itself (never reachable through the registry, since lint
# now rejects such a name — this proves the function's OWN quoting
# defense-in-depth, independent of the lint gate in front of it).
BRC_RESULT="$(
  source "$RM" --root "$ROOT" >/dev/null 2>&1
  build_remove_cmd plugin "evil name" ""
  printf '%s' "$REC_REMOVE_CMD"
)"
assert "build_remove_cmd (plugin kind): quotes a name containing a space in the printed git rm command" \
  "[ \"\$BRC_RESULT\" = \"git rm -r 'plugins/evil name'\" ]"

echo ""
echo "A. round-4 review, finding-6 class: first_shipped / release fields require STRICT vX.Y.Z, not a loose glob"
mk_reg "plugin | x | removed | none | REMOVE | v1.0.0 | v8.0.0-rc1 | loose release shape" "badrelrc.conf"
assert "release 'v8.0.0-rc1' fails lint (the old v[0-9]*.[0-9]*.[0-9]* glob let it through)" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/badrelrc.conf' >'$TMP/l8.out' 2>&1; grep -q \"release 'v8.0.0-rc1' must be vX.Y.Z\" '$TMP/l8.out'"
mk_reg "plugin | x | removed | none | REMOVE | v9x.0.0 | v8.0.0 | loose first_shipped shape" "badfirstx.conf"
assert "first_shipped 'v9x.0.0' fails lint" \
  "! bash '$RM' lint --root '$ROOT' --registry '$TMP/badfirstx.conf' >'$TMP/l9.out' 2>&1; grep -q \"first_shipped 'v9x.0.0' must be\" '$TMP/l9.out'"
mk_reg "plugin | x | removed | none | REMOVE | v1.0.0 | v8.0.0 | strict shapes still pass" "goodver.conf"
assert "…and a strict vX.Y.Z row still lints clean" \
  "bash '$RM' lint --root '$ROOT' --registry '$TMP/goodver.conf' >'$TMP/l10.out' 2>&1"

echo ""
echo "A. round-5 finding 5: loom_latest_tag_at_or_below / loom_latest_tag_below filter tags with the same strict vX.Y.Z shape lint requires, not a loose /^v[0-9]/"
if command -v loom_latest_tag_at_or_below >/dev/null 2>&1 && command -v loom_latest_tag_below >/dev/null 2>&1; then
  TAGFILT_ROOT="$TMP/tagfilt-repo"
  mkdir -p "$TAGFILT_ROOT"
  git init -q "$TAGFILT_ROOT"
  ( cd "$TAGFILT_ROOT" && git commit -q --allow-empty -m c1 )
  git -C "$TAGFILT_ROOT" tag v7.0.0
  ( cd "$TAGFILT_ROOT" && git commit -q --allow-empty -m c2 )
  # loose-shaped tags that must NOT be treated as candidates: an rc suffix,
  # and a non-numeric first-component glob the old /^v[0-9]/ still matched
  # (it only required the FIRST character after 'v' to be a digit).
  git -C "$TAGFILT_ROOT" tag v8.0.0-rc1
  ( cd "$TAGFILT_ROOT" && git commit -q --allow-empty -m c3 )
  git -C "$TAGFILT_ROOT" tag v9x.0.0
  ( cd "$TAGFILT_ROOT" && git commit -q --allow-empty -m c4 )

  TAGFILT_AT_OR_BELOW="$(loom_latest_tag_at_or_below "9.0.0" "$TAGFILT_ROOT" 2>/dev/null)"
  assert "loom_latest_tag_at_or_below('9.0.0'): skips the loose-shaped v8.0.0-rc1/v9x.0.0 tags, resolves the strict v7.0.0" \
    "[ \"\$TAGFILT_AT_OR_BELOW\" = v7.0.0 ]"
  TAGFILT_BELOW="$(loom_latest_tag_below "9.0.0" "$TAGFILT_ROOT" 2>/dev/null)"
  assert "loom_latest_tag_below('9.0.0'): same strict filter, resolves the strict v7.0.0" \
    "[ \"\$TAGFILT_BELOW\" = v7.0.0 ]"

  # Regression guard, same shape as finding 3's above: reproduce the OLD
  # loose /^v[0-9]/ filter as a standalone awk one-liner (never touching
  # the shipped lib) and prove it WOULD have matched v8.0.0-rc1 and
  # v9x.0.0 as candidates — the exact bug finding 5 closed, not a
  # tautological re-statement of the fix.
  TAGFILT_TAGS="$(git -C "$TAGFILT_ROOT" for-each-ref --format='%(refname:short)' refs/tags/)"
  TAGFILT_PRE_FIX="$(printf '%s\n' "$TAGFILT_TAGS" | awk '/^v[0-9]/ { print }')"
  assert "regression guard: the PRE-FIX loose /^v[0-9]/ filter would have wrongly matched v8.0.0-rc1 (proves finding 5's strict-shape fix is a real behavior change)" \
    "printf '%s\n' \"\$TAGFILT_PRE_FIX\" | grep -qx 'v8.0.0-rc1'"
  assert "…and would ALSO have wrongly matched v9x.0.0 (first char after 'v' is a digit; the rest was never checked)" \
    "printf '%s\n' \"\$TAGFILT_PRE_FIX\" | grep -qx 'v9x.0.0'"
else
  skip "loom_latest_tag_at_or_below / loom_latest_tag_below direct unit checks" "functions not defined (lib not sourced, or not yet implemented)"
fi

echo ""
echo "A. Maintainer-tree-only assertions (release-removal guard, tag consistency)"

case "$TREE_KIND" in
  maintainer)
    BAD_PATHS="$(bash -c "
      source '$LIB'
      loom_deprecation_rows '$REG' | while IFS=\$'\t' read -r kind name fate repl default first release note; do
        path=\"\$(loom_deprecation_dir \"\$kind\" \"\$name\")\"
        [ -e '$ROOT'/\"\$path\" ] && echo \"\$path\"
      done
    ")"
    assert "on a maintainer tree, no deprecation row's path exists on disk (found: ${BAD_PATHS:-none})" \
      "[ -z \"\$BAD_PATHS\" ]"
    assert "migration-decisions.conf does not exist on a maintainer tree" \
      "[ ! -f '$ROOT/.logic-loom/config/migration-decisions.conf' ]"
    assert "project-migrations.conf does not exist on a maintainer tree" \
      "[ ! -f '$ROOT/.logic-loom/config/project-migrations.conf' ]"

    bash "$RM" check-release --since auto --root "$ROOT" > "$TMP/a-removal-guard.out" 2>&1
    RG_RC=$?
    echo "     $(head -1 "$TMP/a-removal-guard.out")"
    assert "'check-release --since auto' exits 0 on the maintainer tree" "[ $RG_RC -eq 0 ]"
    assert "output names the resolved floor branch ('previous release:')" \
      "grep -q 'previous release:' '$TMP/a-removal-guard.out'"

    echo "  tag consistency:"
    bash -c "
      source '$LIB'
      loom_deprecation_rows '$REG' | while IFS=\$'\t' read -r kind name fate repl default first release note; do
        case \"\$first\" in v[0-9]*) : ;; *) continue ;; esac
        path=\"\$(loom_deprecation_dir \"\$kind\" \"\$name\")\"
        if ! git -C '$ROOT' rev-parse -q --verify \"refs/tags/\$first\" >/dev/null 2>&1; then
          echo \"SKIP \$name: tag \$first absent\"; continue
        fi
        if ! git -C '$ROOT' cat-file -e \"\$first:\$path\" 2>/dev/null; then
          echo \"FAIL \$name: \$path absent at \$first (should be present)\"; continue
        fi
        if [ \"\$release\" != '-' ] && git -C '$ROOT' rev-parse -q --verify \"refs/tags/\$release\" >/dev/null 2>&1; then
          if git -C '$ROOT' cat-file -e \"\$release:\$path\" 2>/dev/null; then
            echo \"FAIL \$name: \$path still present at \$release (should be gone)\"
          else
            echo \"OK \$name\"
          fi
        else
          echo \"SKIP \$name: tag \$release absent\"
        fi
      done
    " > "$TMP/a-tagcheck.out"
    cat "$TMP/a-tagcheck.out" | sed 's/^/    /'
    # A row whose tag is absent locally (shallow clone, private remote without
    # the pre-v6.2 tags) is a SKIP with the tag named — counted, never a pass.
    while IFS= read -r skline; do
      [ -n "$skline" ] && skip "tag consistency: ${skline#SKIP }"
    done <<< "$(grep '^SKIP' "$TMP/a-tagcheck.out" || true)"
    TAG_FAILS="$(grep -c '^FAIL' "$TMP/a-tagcheck.out" || true)"
    assert "tag consistency: no row's path violates first_shipped/release tag facts" "[ '$TAG_FAILS' -eq 0 ]"
    ;;
  sanitized)
    skip "release-removal guard is a maintainer check — sanitized tree (release tags are not shipped)"
    skip "maintainer-tree absence (no deprecation path on disk; no decisions/project registry) is a maintainer check — sanitized tree"
    skip "tag consistency is a maintainer check — sanitized tree (release tags are not shipped)"
    ;;
esac

# ═══════════════════════════════════════════════════════════════════════════
# SECTION B — fixture: a throwaway git repo shaped like §7-B of the design
# ═══════════════════════════════════════════════════════════════════════════
#
# Every sub-test below gets its OWN repo via fixture_repo() (cheap: local git,
# a handful of small files). The main worker's own Bash lines never run git —
# only this SCRIPT does, on the throwaway fixture path it creates, exactly the
# precedent tests/contract/test_release_sync_ref.sh sets.
export GIT_AUTHOR_NAME=loom-test GIT_AUTHOR_EMAIL=loom@test
export GIT_COMMITTER_NAME=loom-test GIT_COMMITTER_EMAIL=loom@test

# fixture_repo <dir> — builds commit A (the full §7-B shape), tags v9.0.0 at
# A, a commit A2 touching one file, tags v9.1.0 at A2, then leaves three
# UNCOMMITTED edits in the working tree. Returns via stdout: "A A2".
fixture_repo() {
  local F="$1"
  mkdir -p "$F"
  git init -q "$F"

  mkdir -p "$F/plugins/sdd-dev-loop/.claude-plugin" \
           "$F/plugins/sdd-dev-loop/commands" \
           "$F/plugins/sdd-dev-loop/skills/core-loop" \
           "$F/plugins/sdd-dev-loop/skills/dev-loop" \
           "$F/plugins/sdd-dev-loop/config" \
           "$F/.claude/commands" \
           "$F/plugins/sdd-debug/commands" \
           "$F/plugins/sdd-debug/agents" \
           "$F/plugins/sdd-debug/skills/sdd-debug" \
           "$F/plugins/sdd-debug/hooks/scripts" \
           "$F/plugins/sdd-git/commands" \
           "$F/plugins/loom-git/commands" \
           "$F/.logic-loom/config" \
           "$F/.logic-loom/lib" \
           "$F/.claude"

  cat > "$F/plugins/sdd-dev-loop/.claude-plugin/plugin.json" <<'JSON'
{ "name": "sdd-dev-loop", "version": "1.0.0", "dependencies": ["loom-governance"],
  "agents": { "count": 0, "list": [] } }
JSON
  cat > "$F/plugins/sdd-dev-loop/commands/dev-loop.md" <<'MD'
---
name: dev-loop
description: Autonomous edit-test-debug loop
allowed-tools: Bash
model: opus
---

# /dev-loop

Runs an edit-test-debug cycle.
MD
  cat > "$F/plugins/sdd-dev-loop/skills/core-loop/SKILL.md" <<'MD'
---
name: core-loop
description: Core loop internals
---

Core loop body.
MD
  cat > "$F/plugins/sdd-dev-loop/skills/dev-loop/SKILL.md" <<'MD'
---
name: dev-loop
description: The dev-loop skill (same name as the command, for the append path)
---

Existing skill body.
MD
  echo '{"threshold": 1}' > "$F/plugins/sdd-dev-loop/config/thresholds.json"

  cat > "$F/.claude/commands/dev-loop.md" <<'MD'
<!-- 🔌 AUTO-GENERATED by plugin-bridge | source: sdd-dev-loop | DO NOT EDIT -->
<!-- To modify this command, edit: plugins/sdd-dev-loop/commands/dev-loop.md -->
<!-- Run .specify/scripts/bash/sync-plugin-commands.sh sync to refresh -->

Read and execute the full command procedure from: plugins/sdd-dev-loop/commands/dev-loop.md
MD

  cat > "$F/plugins/sdd-debug/commands/debug.md" <<'MD'
---
name: debug
description: 10-step debugging workflow
allowed-tools: Bash, Read
---

# /debug
MD
  cat > "$F/plugins/sdd-debug/agents/auto-debug-agent.md" <<'MD'
---
name: auto-debug-agent
description: Automated debugging agent
model: claude-opus-4-6-20260205
---

Agent body.
MD
  cat > "$F/plugins/sdd-debug/skills/sdd-debug/SKILL.md" <<'MD'
---
name: sdd-debug
description: sdd-debug skill
---

Skill body.
MD
  cat > "$F/plugins/sdd-debug/hooks/hooks.json" <<'JSON'
{ "hooks": {} }
JSON
  cat > "$F/plugins/sdd-debug/hooks/scripts/debug-capture.sh" <<'SH'
#!/usr/bin/env bash
source "${CLAUDE_PLUGIN_ROOT}/lib/x.sh"
cat "plugins/sdd-debug/config/y.json"
SH
  chmod +x "$F/plugins/sdd-debug/hooks/scripts/debug-capture.sh"

  cat > "$F/plugins/sdd-git/commands/git-push.md" <<'MD'
---
name: git-push
description: sdd-git's git-push command
---

sdd-git body.
MD
  cat > "$F/plugins/loom-git/commands/git-push.md" <<'MD'
---
name: git-push
description: loom-git's git-push command
---

loom-git body.
MD

  cat > "$F/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [
        { "type": "command", "command": "bash plugins/sdd-debug/hooks/scripts/debug-capture.sh" },
        { "type": "command", "command": "bash plugins/sdd-governance/hooks/scripts/git-safety-gate.sh" }
      ]}
    ]
  }
}
JSON

  cp "$REG" "$F/.logic-loom/config/release-migrations.conf"
  cp "$LIB" "$F/.logic-loom/lib/release-migrations.sh"
  echo "FRAMEWORK_VERSION=7.0.0" > "$F/.logic-loom/config/architecture.conf"

  # finding 1: a tag NEVER establishes a baseline (fix BY DESIGN — see
  # resolve_baseline). These two tags (v9.0.0, v9.1.0) are stamped with
  # LogicLoom's own package.json name+version purely so the "does a tag ever
  # leak into the baseline, even a convincing one" assertions below have
  # something convincing to reject — resolve_baseline must ignore them
  # regardless of how genuine they look.
  cat > "$F/package.json" <<'JSON'
{ "name": "logic-loom", "version": "9.0.0" }
JSON

  cat > "$F/CLAUDE.md" <<'MD'
# CLAUDE.md — fixture

## Plugin Registry

| Plugin | Layer | Notes |
|---|---|---|
| `loom-git` | core tooling | git-push/finalize |

## Something Else

Nothing here.
MD

  ( cd "$F" && git add -A >/dev/null && git commit -q -m "commit A" )
  local A; A="$(git -C "$F" rev-parse HEAD)"
  printf '%s\n' "$A" > "$F/.sdd-sync-ref"
  ( cd "$F" && git add -A >/dev/null && git commit -q -m "commit A: stamp sync-ref" --allow-empty )
  A="$(git -C "$F" rev-parse HEAD)"
  git -C "$F" update-ref refs/tags/v9.0.0 "$A"

  echo "touched" > "$F/UNRELATED.txt"
  cat > "$F/package.json" <<'JSON'
{ "name": "logic-loom", "version": "9.1.0" }
JSON
  ( cd "$F" && git add -A >/dev/null && git commit -q -m "commit A2" )
  local A2; A2="$(git -C "$F" rev-parse HEAD)"
  git -C "$F" update-ref refs/tags/v9.1.0 "$A2"
  # Round-2 finding 1: a sync-ref is only a baseline when refs/loom-upstream/
  # main exists locally AND reaches it. A2 is a descendant of A (the
  # sync-ref commit), so this keeps every existing sync-ref-baseline
  # assertion below true under the tightened rule instead of silently
  # flipping them all to "no baseline" — FIX2 (below) deletes this ref
  # again for the fixtures that specifically want "no baseline at all".
  git -C "$F" update-ref refs/loom-upstream/main "$A2"

  # Uncommitted edits (§7-B): sdd-debug customized (1 changed, 1 added),
  # sdd-git customized (1 changed).
  echo "-- locally edited --" >> "$F/plugins/sdd-debug/commands/debug.md"
  echo "local notes" > "$F/plugins/sdd-debug/skills/sdd-debug/notes.md"
  echo "-- locally edited --" >> "$F/plugins/sdd-git/commands/git-push.md"

  printf '%s %s' "$A" "$A2"
}

echo ""
echo "B. Building the §7-B fixture (throwaway git repo)"
FIX1="$TMP/fixture1"
FIX1_AB="$(fixture_repo "$FIX1")"
FIX1_A="$(printf '%s' "$FIX1_AB" | awk '{print $1}')"
FIX1_A2="$(printf '%s' "$FIX1_AB" | awk '{print $2}')"
assert "fixture repo built (commit A resolves)" "[ -n '$FIX1_A' ]"
assert "fixture repo has two tags (v9.0.0, v9.1.0)" \
  "git -C '$FIX1' rev-parse -q --verify refs/tags/v9.0.0 >/dev/null 2>&1 && git -C '$FIX1' rev-parse -q --verify refs/tags/v9.1.0 >/dev/null 2>&1"

# ═══════════════════════════════════════════════════════════════════════════
# SECTION C — scan
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "C. scan --json parses; per-item shape and the three headline items"

bash "$RM" scan --json --root "$FIX1" > "$TMP/c1.json" 2>"$TMP/c1.err"
C1_RC=$?
assert "scan --json exits 0" "[ $C1_RC -eq 0 ]"
assert "scan --json output parses as JSON" "python3 -c 'import json; json.load(open(\"$TMP/c1.json\"))'"
assert "scan --json parses as ONE OBJECT with the fixed key set" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
assert isinstance(d, dict), \"not an object\"
want = {\"registry\",\"rows\",\"project_rows\",\"release\",\"orphan_check\",\"items\",\"dangling_hooks\",\"dangling_mcp\",\"decisions\",\"summary\"}
assert want <= set(d.keys()), sorted(d.keys())
'"
assert "every item id matches MG-NNN" \
  "python3 -c '
import json, re
d = json.load(open(\"$TMP/c1.json\"))
for it in d[\"items\"]:
    assert re.match(r\"^MG-[0-9]{3}\$\", it[\"id\"]), it
'"
assert "every item has blocked (bool), blocked_by (list), remove_command, move_command" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
for it in d[\"items\"]:
    assert isinstance(it[\"blocked\"], bool), it[\"id\"]
    assert isinstance(it[\"blocked_by\"], list), it[\"id\"]
    assert \"remove_command\" in it and \"move_command\" in it, it[\"id\"]
'"
assert "every deprecation reference carries a class" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
for it in d[\"items\"]:
    for r in it.get(\"references\", []):
        assert \"class\" in r, it[\"id\"]
'"

assert "sdd-dev-loop: pristine, baseline sync-ref:<A>, recommended REMOVE, not blocked" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"state\"] == \"pristine\", it
assert it[\"baseline\"].startswith(\"sync-ref:\"), it
assert it[\"recommended\"] == \"REMOVE\", it
assert it[\"blocked\"] is False, it
assert it[\"remove_command\"] == \"git rm -r '\''plugins/sdd-dev-loop'\''\", it
'"
assert "sdd-dev-loop references include the bridge wrapper, class bridge-wrapper" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert any(r[\"file\"] == \".claude/commands/dev-loop.md\" and r[\"class\"] == \"bridge-wrapper\" for r in it[\"references\"]), it[\"references\"]
'"

assert "sdd-debug: customized (1 changed, 1 added), CONVERT-TO-LOCAL, wired_hooks has debug-capture.sh" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-debug\")
assert it[\"state\"] == \"customized\", it
assert len(it[\"changed_files\"]) == 1 and len(it[\"added_files\"]) == 1, it
assert it[\"recommended\"] == \"CONVERT-TO-LOCAL\", it
assert any(\"debug-capture.sh\" in w[\"text\"] for w in it[\"wired_hooks\"]), it[\"wired_hooks\"]
'"

assert "sdd-git: customized, ADOPT-REPLACEMENT, counterpart loom-git/commands/git-push.md exists=true" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-git\")
assert it[\"state\"] == \"customized\", it
assert it[\"recommended\"] == \"ADOPT-REPLACEMENT\", it
cp = it[\"counterparts\"]
assert any(c[\"counterpart\"] == \"plugins/loom-git/commands/git-push.md\" and c[\"exists\"] is True for c in cp), cp
'"

assert "sdd-governance is NOT an item (dir absent)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
assert not any(i.get(\"path\") == \"plugins/sdd-governance\" for i in d[\"items\"])
'"
assert "…but appears in dangling_hooks (the settings.json line will dangle)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
assert any(\"sdd-governance\" in h[\"text\"] for h in d[\"dangling_hooks\"]), d[\"dangling_hooks\"]
'"

assert "the v7.0.0 receipt content row yields NO item in this fixture (TEMPLATE, no receipt)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c1.json\"))
assert not any(i.get(\"kind\") == \"content\" for i in d[\"items\"])
'"

echo ""
echo "C. baseline resolution (finding 1): sync-ref removed -> NEVER falls back to a tag, even two"
echo "   LogicLoom-stamped ones (v9.0.0, v9.1.0) sitting right there — baseline none, state unknown"
FIX2="$TMP/fixture2"; cp -R "$FIX1" "$FIX2"
rm -f "$FIX2/.sdd-sync-ref"
# Also drop the upstream-history ref FIX1 now carries (finding 1, above) —
# this fixture's whole point is "no baseline candidate resolves at all",
# and leaving refs/loom-upstream/main behind would let resolve_baseline's
# OWN upstream fallback (a real, different baseline route) resolve one,
# which is not what this section tests.
git -C "$FIX2" update-ref -d refs/loom-upstream/main
bash "$RM" scan --json --root "$FIX2" > "$TMP/c2.json" 2>"$TMP/c2.err"
assert "with .sdd-sync-ref removed, sdd-dev-loop baseline is none (a tag is never consulted, stamped or not)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c2.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"baseline\"] == \"none\", it[\"baseline\"]
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"

echo ""
echo "C. baseline resolution: no sync-ref AND no tags -> baseline none, state unknown, CONVERT-TO-LOCAL"
FIX3="$TMP/fixture3"; cp -R "$FIX2" "$FIX3"
# update-ref -d, not `git tag -d`: the fixture verbs stay within init/add/
# commit/update-ref (+ read-only), the set the design sanctions for a
# throwaway repo built inside a suite.
git -C "$FIX3" update-ref -d refs/tags/v9.0.0
git -C "$FIX3" update-ref -d refs/tags/v9.1.0
assert "fixture3 really has no tags" "[ -z \"\$(git -C '$FIX3' for-each-ref refs/tags/)\" ]"
bash "$RM" scan --json --root "$FIX3" > "$TMP/c3.json" 2>"$TMP/c3.err"
assert "with no sync-ref and no tags, sdd-dev-loop baseline is none, state unknown, CONVERT-TO-LOCAL" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c3.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"baseline\"] == \"none\", it[\"baseline\"]
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] == \"CONVERT-TO-LOCAL\", it
'"

echo ""
echo "C. decisions: keep = sdd-dev-loop"
FIX4="$TMP/fixture4"; cp -R "$FIX1" "$FIX4"
mkdir -p "$FIX4/.logic-loom/config"
echo "keep = sdd-dev-loop" > "$FIX4/.logic-loom/config/migration-decisions.conf"
bash "$RM" scan --json --root "$FIX4" > "$TMP/c4.json" 2>"$TMP/c4.err"
bash "$RM" scan --root "$FIX4" > "$TMP/c4.human.out" 2>"$TMP/c4.human.err"
assert "decision keep -> item recommended KEEP-AS-IS, summary.kept 1" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c4.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"decision\"] == \"keep\", it
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert d[\"summary\"][\"kept\"] == 1, d[\"summary\"]
'"
assert "decisions[] carries one entry, verb keep, consequence mentions 'floor test'" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c4.json\"))
assert len(d[\"decisions\"]) == 1, d[\"decisions\"]
dec = d[\"decisions\"][0]
assert dec[\"verb\"] == \"keep\" and dec[\"name\"] == \"sdd-dev-loop\", dec
assert \"floor test\" in dec[\"consequence\"], dec
'"
assert "human output contains 'Decisions in force'" \
  "grep -q 'Decisions in force' '$TMP/c4.human.out'"

echo ""
echo "C. decisions: keep = sdd-nonexistent -> stale"
FIX5="$TMP/fixture5"; cp -R "$FIX1" "$FIX5"
mkdir -p "$FIX5/.logic-loom/config"
echo "keep = sdd-nonexistent" > "$FIX5/.logic-loom/config/migration-decisions.conf"
bash "$RM" scan --json --root "$FIX5" > "$TMP/c5.json" 2>"$TMP/c5.err"
assert "a decision naming nothing on disk is reported stale" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/c5.json\"))
dec = d[\"decisions\"][0]
assert dec[\"name\"] == \"sdd-nonexistent\" and dec[\"stale\"] is True, dec
'"

echo ""
echo "C. empty fixture: no items at all"
FIX_EMPTY="$TMP/fixture-empty"
mkdir -p "$FIX_EMPTY/.logic-loom/config" "$FIX_EMPTY/.logic-loom/lib"
git init -q "$FIX_EMPTY"
cp "$REG" "$FIX_EMPTY/.logic-loom/config/release-migrations.conf"
cp "$LIB" "$FIX_EMPTY/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=7.0.0" > "$FIX_EMPTY/.logic-loom/config/architecture.conf"
( cd "$FIX_EMPTY" && git add -A >/dev/null && git commit -q -m init )
bash "$RM" scan --root "$FIX_EMPTY" > "$TMP/cempty.human.out" 2>"$TMP/cempty.human.err"
bash "$RM" scan --json --root "$FIX_EMPTY" > "$TMP/cempty.json" 2>"$TMP/cempty.json.err"
assert "empty fixture human output contains 'Release migrations: none pending.'" \
  "grep -qF 'Release migrations: none pending.' '$TMP/cempty.human.out'"
assert "empty fixture --json has items: []" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cempty.json\"))
assert d[\"items\"] == [], d[\"items\"]
'"
assert "empty fixture without decisions prints no MG- line and no 'Decisions in force' block (just the header lines + none pending)" \
  "! grep -q '^MG-' '$TMP/cempty.human.out' && ! grep -q 'Decisions in force' '$TMP/cempty.human.out'"

echo ""
echo "C. empty fixture WITH a keep line: both lines present"
FIX_EMPTY_KEEP="$TMP/fixture-empty-keep"; cp -R "$FIX_EMPTY" "$FIX_EMPTY_KEEP"
echo "keep = sdd-dev-loop" > "$FIX_EMPTY_KEEP/.logic-loom/config/migration-decisions.conf"
bash "$RM" scan --root "$FIX_EMPTY_KEEP" > "$TMP/cek.out" 2>&1
assert "'none pending' AND 'Decisions in force' both present" \
  "grep -qF 'Release migrations: none pending.' '$TMP/cek.out' && grep -q 'Decisions in force' '$TMP/cek.out'"

echo ""
echo "C. orphan pass: skipped without a Plugin Registry table, run (and catches) with one"
FIX_ORPHAN="$TMP/fixture-orphan"; cp -R "$FIX1" "$FIX_ORPHAN"
mkdir -p "$FIX_ORPHAN/plugins/loom-stray"
: > "$FIX_ORPHAN/plugins/loom-stray/README.md"
bash "$RM" scan --json --root "$FIX_ORPHAN" > "$TMP/corphan.json" 2>&1
assert "loom-stray (undeclared, unregistered) IS reported as kind orphan" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/corphan.json\"))
assert any(i.get(\"kind\") == \"orphan\" and i[\"path\"] == \"plugins/loom-stray\" for i in d[\"items\"]), d[\"items\"]
'"
rm "$FIX_ORPHAN/CLAUDE.md"
bash "$RM" scan --json --root "$FIX_ORPHAN" > "$TMP/corphan2.json" 2>&1
bash "$RM" scan --root "$FIX_ORPHAN" > "$TMP/corphan2.human.out" 2>&1
assert "with CLAUDE.md removed, orphan_check is 'skipped' and no orphan items appear" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/corphan2.json\"))
assert d[\"orphan_check\"] == \"skipped\", d[\"orphan_check\"]
assert not any(i.get(\"kind\") == \"orphan\" for i in d[\"items\"])
'"
assert "human output says 'orphan check: skipped'" \
  "grep -q 'orphan check: skipped' '$TMP/corphan2.human.out'"

echo ""
echo "C. .github/workflows blocks REMOVE (ci-workflow reference)"
FIX_CI="$TMP/fixture-ci"; cp -R "$FIX1" "$FIX_CI"
mkdir -p "$FIX_CI/.github/workflows"
echo "run: bash plugins/sdd-dev-loop/scripts/run.sh" > "$FIX_CI/.github/workflows/ci.yml"
bash "$RM" scan --json --root "$FIX_CI" > "$TMP/cci.json" 2>&1
assert "sdd-dev-loop is now blocked, blocked_by names the workflow file, class ci-workflow" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cci.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"blocked\"] is True, it
assert it[\"blocked_by\"][0][\"file\"] == \".github/workflows/ci.yml\", it[\"blocked_by\"]
assert any(r[\"class\"] == \"ci-workflow\" for r in it[\"references\"]), it[\"references\"]
'"

mkdir -p "$FIX_CI/.claude/agents"
echo "see plugins/sdd-debug/skills for the old flow" > "$FIX_CI/.claude/agents/helper.md"
bash "$RM" scan --json --root "$FIX_CI" > "$TMP/cci2.json" 2>&1
assert "sdd-debug references include .claude/agents/helper.md with class project-agent-or-skill (listed, never a block)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cci2.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-debug\")
assert any(r[\"file\"] == \".claude/agents/helper.md\" and r[\"class\"] == \"project-agent-or-skill\" for r in it[\"references\"]), it[\"references\"]
assert not any(b[\"file\"] == \".claude/agents/helper.md\" for b in it[\"blocked_by\"]), it[\"blocked_by\"]
'"
bash "$RM" plan sdd-dev-loop --root "$FIX_CI" > "$TMP/cci.plan.out" 2>&1
assert "human 'plan sdd-dev-loop' prints 'BLOCKED until:' naming the workflow" \
  "grep -q 'BLOCKED until: .*\\.github/workflows/ci\\.yml' '$TMP/cci.plan.out'"

echo ""
echo "C. mcp-server kind: dangling_mcp and remove text never name plugins/"
FIX_MCP="$TMP/fixture-mcp"; cp -R "$FIX1" "$FIX_MCP"
mkdir -p "$FIX_MCP/mcp-servers/sdd-marketplace"
: > "$FIX_MCP/mcp-servers/sdd-marketplace/index.js"
cat > "$FIX_MCP/.mcp.json" <<'JSON'
{ "mcpServers": { "sdd-marketplace": { "command": "node", "args": ["mcp-servers/sdd-marketplace/src/index.js"] } } }
JSON
( cd "$FIX_MCP" && git add -A >/dev/null && git commit -q -m "add sdd-marketplace" )
MCP_REF="$(git -C "$FIX_MCP" rev-parse HEAD)"
printf '%s\n' "$MCP_REF" > "$FIX_MCP/.sdd-sync-ref"
( cd "$FIX_MCP" && git add -A >/dev/null && git commit -q -m "advance sync-ref" )
# Round-2 finding 1: the sync-ref just advanced PAST FIX1's frozen
# refs/loom-upstream/main (still A2) — advance it too, so it still REACHES
# the new sync-ref commit (finding 1's ancestor rule).
git -C "$FIX_MCP" update-ref refs/loom-upstream/main "$(git -C "$FIX_MCP" rev-parse HEAD)"
bash "$RM" scan --json --root "$FIX_MCP" > "$TMP/cmcp.json" 2>&1
assert "sdd-marketplace is an item, kind mcp-server, remove_command git rm -r mcp-servers/sdd-marketplace" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cmcp.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"mcp-servers/sdd-marketplace\")
assert it[\"kind\"] == \"mcp-server\", it
assert it[\"remove_command\"] == \"git rm -r '\''mcp-servers/sdd-marketplace'\''\", it
assert any(r[\"class\"] == \"mcp-config\" for r in it[\"references\"]), it[\"references\"]
'"
bash "$RM" plan sdd-marketplace --root "$FIX_MCP" > "$TMP/cmcp.plan.out" 2>&1
assert "plan text mentions removing the .mcp.json entry and git rm -r mcp-servers/..." \
  "grep -q 'sdd-marketplace\": entry from .mcp.json' '$TMP/cmcp.plan.out' && grep -q 'git rm -r '\''mcp-servers/sdd-marketplace'\''' '$TMP/cmcp.plan.out'"
assert "plan text never names plugins/sdd-marketplace" \
  "! grep -q 'plugins/sdd-marketplace' '$TMP/cmcp.plan.out'"
# Finding 8 (low, round 5 review): a pristine REMOVE's plan text must state
# it is recoverable from history and name the exact command — never leave
# the reader to work out git recovery mechanics on their own after the fact.
assert "finding 8: plan text for a pristine REMOVE states it is recoverable and names the exact restore commands" \
  "grep -q 'recoverable: removing a pristine path never loses bytes' '$TMP/cmcp.plan.out' \
   && grep -qF \"git checkout HEAD -- 'mcp-servers/sdd-marketplace'\" '$TMP/cmcp.plan.out' \
   && grep -qF 'git revert <the removal commit>' '$TMP/cmcp.plan.out'"
# round-2 review, medium finding: the path is tracked at HEAD here (a plain
# committed fixture), so the ordinary advice fires, not the "not tracked at
# HEAD" branch — and the path in both printed commands is now single-quoted.
assert "…and the SECOND restore command (post-commit) is quoted the same way" \
  "grep -qF \"git checkout <commit-before-removal> -- 'mcp-servers/sdd-marketplace'\" '$TMP/cmcp.plan.out'"
rm -rf "$FIX_MCP/mcp-servers/sdd-marketplace"
bash "$RM" scan --json --root "$FIX_MCP" > "$TMP/cmcp2.json" 2>&1
assert "removing the dir: no item, dangling_mcp length 1" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cmcp2.json\"))
assert not any(i.get(\"path\") == \"mcp-servers/sdd-marketplace\" for i in d[\"items\"])
assert len(d[\"dangling_mcp\"]) == 1, d[\"dangling_mcp\"]
'"

echo ""
echo "C. project-owned content rows (project-migrations.conf) — bypass ownership scoping"
FIX_PROJ="$TMP/fixture-proj"; cp -R "$FIX1" "$FIX_PROJ"
echo 'content | plugins/sdd-debug/skills/sdd-debug/notes.md | present | pattern:notes | PROPOSE | - | v7.0.0 | proposal: x; why: y' \
  > "$FIX_PROJ/.logic-loom/config/project-migrations.conf"
bash "$RM" scan --json --root "$FIX_PROJ" > "$TMP/cproj.json" 2>&1
assert "the project row yields a content item, source project, matches non-empty" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cproj.json\"))
it = next(i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \"plugins/sdd-debug/skills/sdd-debug/notes.md\")
assert it[\"source\"] == \"project\", it
assert it[\"matches\"], it
'"
cat >> "$FIX_PROJ/.logic-loom/config/project-migrations.conf" <<'EOF'
content | plugins/sdd-debug/skills/sdd-debug/notes.md | present | pattern:local | PROPOSE | - | v7.0.0 | proposal: x2; why: y2
EOF
bash "$RM" scan --json --root "$FIX_PROJ" > "$TMP/cproj2.json" 2>&1
assert "a second project row on the same file yields a second MG- item" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cproj2.json\"))
items = [i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \"plugins/sdd-debug/skills/sdd-debug/notes.md\"]
assert len(items) == 2, items
'"

echo "keep = plugins/sdd-debug/skills/sdd-debug/notes.md@v7.0.0" > "$FIX_PROJ/.logic-loom/config/migration-decisions.conf"
bash "$RM" scan --json --root "$FIX_PROJ" > "$TMP/cproj3.json" 2>&1
assert "keep = <file>@v7.0.0 silences BOTH content rows on that file (one file, one release, one acknowledgment); summary.kept counts both" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cproj3.json\"))
items = [i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \"plugins/sdd-debug/skills/sdd-debug/notes.md\"]
assert len(items) == 2 and all(i[\"recommended\"] == \"KEEP-AS-IS\" for i in items), items
assert d[\"summary\"][\"kept\"] == 2, d[\"summary\"]
'"
# §15.2-I: `\|` inside a field decodes to a literal `|`, so a pattern may carry
# an ERE alternation. `notes\|zzz` must still match the file's "local notes".
cat >> "$FIX_PROJ/.logic-loom/config/project-migrations.conf" <<'EOF'
content | plugins/sdd-debug/skills/sdd-debug/notes.md | present | pattern:notes\|zzz | PROPOSE | - | v7.0.0 | proposal: x3; why: y3
EOF
bash "$RM" scan --json --root "$FIX_PROJ" > "$TMP/cproj4.json" 2>&1
assert "a project row with an escaped alternation (pattern:notes\\|zzz) is decoded and matches (matches non-empty)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cproj4.json\"))
items = [i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \"plugins/sdd-debug/skills/sdd-debug/notes.md\"]
assert len(items) == 3, items
assert all(i[\"matches\"] for i in items), items
'"

echo ""
echo "C. upstream-first registry: refs/loom-upstream/main wins over the local file"
# Commit a registry carrying one extra synthetic row, point refs/loom-upstream/main
# at that commit, then put the ORIGINAL registry back locally (a second commit) —
# so the row exists only upstream. Verbs used: add, commit, update-ref, show.
FIX_UP="$TMP/fixture-upstream"; cp -R "$FIX1" "$FIX_UP"
echo "plugin | sdd-synthetic | removed | none | REMOVE | v9.0.0 | v9.1.0 | test" >> "$FIX_UP/.logic-loom/config/release-migrations.conf"
( cd "$FIX_UP" && git add -A >/dev/null && git commit -q -m "upstream registry with sdd-synthetic" )
git -C "$FIX_UP" update-ref refs/loom-upstream/main HEAD
git -C "$FIX_UP" show "HEAD~1:.logic-loom/config/release-migrations.conf" > "$FIX_UP/.logic-loom/config/release-migrations.conf"
( cd "$FIX_UP" && git add -A >/dev/null && git commit -q -m "local registry without the row" )
assert "the local registry really lacks the synthetic row" \
  "! grep -q 'sdd-synthetic' '$FIX_UP/.logic-loom/config/release-migrations.conf'"
mkdir -p "$FIX_UP/plugins/sdd-synthetic"
echo "x" > "$FIX_UP/plugins/sdd-synthetic/x.md"
bash "$RM" scan --root "$FIX_UP" > "$TMP/cup.human.out" 2>&1
bash "$RM" scan --json --root "$FIX_UP" > "$TMP/cup.json" 2>&1
assert "human header says 'registry: upstream'" "grep -q '^registry: upstream' '$TMP/cup.human.out'"
assert "the upstream-only row yields an MG- item for plugins/sdd-synthetic" \
  "python3 -c '
import json, re
d = json.load(open(\"$TMP/cup.json\"))
assert d[\"registry\"] == \"upstream\", d[\"registry\"]
it = next((i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-synthetic\"), None)
assert it is not None, d[\"items\"]
assert re.match(r\"^MG-[0-9]{3}\$\", it[\"id\"]) and it[\"kind\"] == \"plugin\", it
'"

echo ""
echo "C. ADOPTED fixture: the v7.0.0 receipt content row"
FIX_ADOPT="$TMP/fixture-adopt"; cp -R "$FIX1" "$FIX_ADOPT"
cat > "$FIX_ADOPT/.logicloom-adopt-receipt.json" <<'JSON'
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    { "at": "2026-01-01T00:00:00Z", "status": "complete",
      "generator": "logicloom@6.6.1",
      "wrote": [
        { "kind": "dir", "path": "plugins/" },
        { "kind": "file", "path": "plugins/sdd-debug/commands/debug.md" }
      ], "skipped": [], "failed": [], "notAttempted": [] }
  ]
}
JSON
( cd "$FIX_ADOPT" && git add -A >/dev/null && git commit -q -m "adopt receipt" )
bash "$RM" scan --json --root "$FIX_ADOPT" > "$TMP/cadopt.json" 2>&1
assert "the v7.0.0 row yields a content item, kind content, path .logicloom-adopt-receipt.json, PROPOSE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cadopt.json\"))
it = next((i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \".logicloom-adopt-receipt.json\"), None)
assert it is not None, d[\"items\"]
assert it[\"recommended\"] == \"PROPOSE\", it
assert \"record-update-writes.sh --reconcile\" in it[\"proposal\"], it[\"proposal\"]
'"
echo "keep = .logicloom-adopt-receipt.json@v7.0.0" >> "$FIX_ADOPT/.logic-loom/config/migration-decisions.conf" 2>/dev/null \
  || { mkdir -p "$FIX_ADOPT/.logic-loom/config"; echo "keep = .logicloom-adopt-receipt.json@v7.0.0" > "$FIX_ADOPT/.logic-loom/config/migration-decisions.conf"; }
bash "$RM" scan --json --root "$FIX_ADOPT" > "$TMP/cadopt2.json" 2>&1
assert "keep = .logicloom-adopt-receipt.json@v7.0.0 -> KEEP-AS-IS, counted kept" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cadopt2.json\"))
it = next(i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \".logicloom-adopt-receipt.json\")
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert d[\"summary\"][\"kept\"] >= 1, d[\"summary\"]
'"
assert "the project notes.md row still yields an item in the ADOPTED fixture (project rows bypass scoping)" \
  "cp '$FIX_PROJ/.logic-loom/config/project-migrations.conf' '$FIX_ADOPT/.logic-loom/config/project-migrations.conf' \
   && bash '$RM' scan --json --root '$FIX_ADOPT' > '$TMP/cadopt-proj.json' 2>&1 \
   && python3 -c '
import json
d = json.load(open(\"$TMP/cadopt-proj.json\"))
assert any(i.get(\"kind\") == \"content\" and i[\"path\"] == \"plugins/sdd-debug/skills/sdd-debug/notes.md\" and i[\"source\"] == \"project\" for i in d[\"items\"]), d[\"items\"]
'"

# Ownership scoping (§14.1.3): an UPSTREAM content row on a file the receipt
# does not record is NOT evaluated in an ADOPTED repo — LogicLoom never claims
# text it did not ship. The same row IS evaluated once the receipt records the
# file, and always in a TEMPLATE clone. The temp registry is the real one plus
# one row, so the plugin items keep their normal shape.
ADOPT_UP_REG="$TMP/adopt-up-reg.conf"
cat "$REG" > "$ADOPT_UP_REG"
echo 'content | plugins/sdd-debug/skills/sdd-debug/SKILL.md | present | pattern:. | PROPOSE | - | v7.0.0 | proposal: p; why: w' >> "$ADOPT_UP_REG"
bash "$RM" scan --json --root "$FIX_ADOPT" --registry "$ADOPT_UP_REG" > "$TMP/cadopt-up1.json" 2>&1
assert "an UNRECORDED upstream content row on the SKILL.md is NOT an item in ADOPTED mode" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cadopt-up1.json\"))
assert not any(i.get(\"kind\") == \"content\" and i[\"path\"] == \"plugins/sdd-debug/skills/sdd-debug/SKILL.md\" for i in d[\"items\"]), d[\"items\"]
'"
python3 - "$FIX_ADOPT/.logicloom-adopt-receipt.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["runs"][0]["wrote"].append({"kind": "file", "path": "plugins/sdd-debug/skills/sdd-debug/SKILL.md"})
json.dump(d, open(p, "w"), indent=2)
PY
bash "$RM" scan --json --root "$FIX_ADOPT" --registry "$ADOPT_UP_REG" > "$TMP/cadopt-up2.json" 2>&1
assert "…but IS an item once the receipt records that file" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cadopt-up2.json\"))
it = next((i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \"plugins/sdd-debug/skills/sdd-debug/SKILL.md\"), None)
assert it is not None, d[\"items\"]
assert it[\"source\"] == \"upstream\" and it[\"matches\"], it
'"
bash "$RM" scan --json --root "$FIX1" --registry "$ADOPT_UP_REG" > "$TMP/ctmpl-up.json" 2>&1
assert "…and is an item in a TEMPLATE clone (no receipt: every matched file is evaluated)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/ctmpl-up.json\"))
assert any(i.get(\"kind\") == \"content\" and i[\"path\"] == \"plugins/sdd-debug/skills/sdd-debug/SKILL.md\" for i in d[\"items\"]), d[\"items\"]
'"

# finding 2 (fixed): .github/ is SCANNED in ADOPTED mode too — an adopter's
# own CI referencing a retired plugin's path must block REMOVE and be
# reported as theirs (this script still never proposes or writes a change
# under .github/ — it only reads it, same as every other reference class).
mkdir -p "$FIX_ADOPT/.github/workflows"
echo "run: bash plugins/sdd-dev-loop/scripts/run.sh" > "$FIX_ADOPT/.github/workflows/ci.yml"
bash "$RM" scan --json --root "$FIX_ADOPT" > "$TMP/cadopt-ci.json" 2>&1
assert "ADOPTED + ci.yml naming the plugin: sdd-dev-loop IS blocked, blocked_by names ci.yml, class ci-workflow" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cadopt-ci.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"blocked\"] is True, it
assert any(b[\"file\"] == \".github/workflows/ci.yml\" for b in it[\"blocked_by\"]), it[\"blocked_by\"]
assert any(r[\"class\"] == \"ci-workflow\" for r in it[\"references\"]), it[\"references\"]
'"
bash "$RM" plan sdd-dev-loop --root "$FIX_ADOPT" > "$TMP/cadopt-ci.plan.out" 2>&1
assert "ADOPTED plan text also names the workflow as BLOCKED until:" \
  "grep -q 'BLOCKED until: .*\\.github/workflows/ci\\.yml' '$TMP/cadopt-ci.plan.out'"
assert "…and the remove_command it prints still targets only the plugin, never a .github path" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cadopt-ci.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"remove_command\"] == \"git rm -r '\''plugins/sdd-dev-loop'\''\", it
'"

echo ""
echo "C. finding 3: a gitignored .claude/settings.local.json hook is scanned explicitly"
FIX_LOCAL="$TMP/fixture-local"; cp -R "$FIX1" "$FIX_LOCAL"
LOCAL_SETTINGS_NAME=".claude/settings.local.json"
printf '{\n  \"hooks\": { \"PreToolUse\": [ { \"matcher\": \"Bash\", \"hooks\": [\n    { \"type\": \"command\", \"command\": \"bash plugins/sdd-dev-loop/hooks/scripts/local.sh\" }\n  ]}]}\n}\n' > "$FIX_LOCAL/$LOCAL_SETTINGS_NAME"
echo "$LOCAL_SETTINGS_NAME" > "$FIX_LOCAL/.gitignore"
( cd "$FIX_LOCAL" && git add -A >/dev/null && git commit -q -m "gitignore local settings" )
assert "the fixture's local settings file really is gitignored (git grep --untracked would miss it)" \
  "git -C '$FIX_LOCAL' check-ignore -q '$LOCAL_SETTINGS_NAME'"
bash "$RM" scan --json --root "$FIX_LOCAL" > "$TMP/clocal.json" 2>&1
assert "sdd-dev-loop is blocked by the gitignored settings.local.json hook, class wired-hook" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/clocal.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"blocked\"] is True, it
assert any(b[\"file\"] == \".claude/settings.local.json\" for b in it[\"blocked_by\"]), it[\"blocked_by\"]
assert any(w[\"file\"] == \".claude/settings.local.json\" for w in it[\"wired_hooks\"]), it[\"wired_hooks\"]
'"

echo ""
echo "C. finding 1 (fix BY DESIGN): a tag can NEVER establish a baseline that leads to REMOVE"
FIX_FAKETAG="$TMP/fixture-faketag"
mkdir -p "$FIX_FAKETAG/.logic-loom/config" "$FIX_FAKETAG/.logic-loom/lib" "$FIX_FAKETAG/plugins/sdd-dev-loop"
git init -q "$FIX_FAKETAG"
cp "$REG" "$FIX_FAKETAG/.logic-loom/config/release-migrations.conf"
cp "$LIB" "$FIX_FAKETAG/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=6.6.2" > "$FIX_FAKETAG/.logic-loom/config/architecture.conf"
echo "pristine plugin body" > "$FIX_FAKETAG/plugins/sdd-dev-loop/marker.txt"
# an ADOPTER'S OWN product, tagged v2.3.1 — the vX.Y.Z shape a customer's own
# semver release tag is very likely to have, and NOT a LogicLoom release.
cat > "$FIX_FAKETAG/package.json" <<'JSON'
{ "name": "acme-widgets", "version": "2.3.1" }
JSON
( cd "$FIX_FAKETAG" && git add -A >/dev/null && git commit -q -m "customer release 2.3.1" )
git -C "$FIX_FAKETAG" update-ref refs/tags/v2.3.1 HEAD
bash "$RM" scan --json --root "$FIX_FAKETAG" > "$TMP/cfaketag.json" 2>&1
assert "an adopter's own v2.3.1 product tag is NEVER accepted as a baseline: baseline none, state unknown, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cfaketag.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"baseline\"] == \"none\", it
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"
# The adversarial case the review demanded: a tag CRAFTED to satisfy EVERY
# heuristic the old code checked — package.json name+version stamp (the
# TEMPLATE route) AND a matching architecture.conf FRAMEWORK_VERSION (the
# ADOPTED route) BOTH present on the same tagged commit — on a genuinely
# CUSTOMIZED retired plugin, in a repo that also carries the ADOPTED marker
# (.logic-loom/AGENTS.md). The old heuristic would have accepted this tag as
# a "genuine LogicLoom release" and recommended REMOVE on a customer's own
# customized content. The fix is structural (tags are never consulted for a
# baseline at all, ADOPTED or not), so this must stay baseline none / state
# unknown / never REMOVE no matter how convincing the forged tag is.
cat > "$FIX_FAKETAG/package.json" <<'JSON'
{ "name": "logic-loom", "version": "2.3.1" }
JSON
echo "FRAMEWORK_VERSION=2.3.1" > "$FIX_FAKETAG/.logic-loom/config/architecture.conf"
mkdir -p "$FIX_FAKETAG/.logic-loom"
: > "$FIX_FAKETAG/.logic-loom/AGENTS.md"
echo "a customer's own hand-edited body, NOT LogicLoom's shipped content" > "$FIX_FAKETAG/plugins/sdd-dev-loop/marker.txt"
( cd "$FIX_FAKETAG" && git add -A >/dev/null && git commit -q -m "forged tag: every old heuristic satisfied, on customized content" )
git -C "$FIX_FAKETAG" update-ref refs/tags/v2.3.1 HEAD
bash "$RM" scan --json --root "$FIX_FAKETAG" > "$TMP/crealtag.json" 2>&1
assert "…even a tag crafted to satisfy EVERY old heuristic (package.json stamp + architecture.conf stamp + ADOPTED marker) on customized content is NEVER accepted: baseline none, state unknown, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/crealtag.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"baseline\"] == \"none\", it
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"

echo ""
echo "C. finding 1: the adopt receipt's recorded sha256 for ONE file IS a valid baseline (ADOPTED-only, file-kind rows only)"
FIX_RECEIPT="$TMP/fixture-receipt"
mkdir -p "$FIX_RECEIPT/.logic-loom/config" "$FIX_RECEIPT/.logic-loom/lib" "$FIX_RECEIPT/docs"
git init -q "$FIX_RECEIPT"
cp "$LIB" "$FIX_RECEIPT/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.0" > "$FIX_RECEIPT/.logic-loom/config/architecture.conf"
echo "path | docs/old-note.md | removed | command:/replacement-cmd | REMOVE | v6.0.0 | v9.0.0 | test fixture for the receipt-sha256 baseline route" \
  > "$FIX_RECEIPT/.logic-loom/config/release-migrations.conf"
printf 'exactly what LogicLoom wrote here\n' > "$FIX_RECEIPT/docs/old-note.md"
RECEIPT_SHA="$(python3 -c '
import hashlib
print(hashlib.sha256(open("'"$FIX_RECEIPT"'/docs/old-note.md", "rb").read()).hexdigest())
')"
cat > "$FIX_RECEIPT/.logicloom-adopt-receipt.json" <<JSON
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-01-01T00:00:00.000Z",
      "generator": "logicloom-update-framework@1.0.0",
      "status": "complete",
      "only": [],
      "wrote": [
        { "target": "harness", "path": "docs/old-note.md", "kind": "file", "sha256": "$RECEIPT_SHA" }
      ],
      "skipped": [], "failed": [], "notAttempted": []
    }
  ]
}
JSON
( cd "$FIX_RECEIPT" && git add -A >/dev/null && git commit -q -m "adopted install" )
# Finding 7 (round 5 review): a receipt-sha256 candidate is only trusted
# once it is corroborated against refs/loom-upstream/main history — this
# fixture's one commit already carries the exact bytes RECEIPT_SHA was
# computed from, so pointing the ref at it is the corroborating blob.
git -C "$FIX_RECEIPT" update-ref refs/loom-upstream/main HEAD
bash "$RM" scan --json --root "$FIX_RECEIPT" > "$TMP/creceipt-pristine.json" 2>&1
assert "byte-identical to what the receipt recorded: baseline receipt-sha256:<hash>, pristine, REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt-pristine.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"receipt-sha256:$RECEIPT_SHA\", it
assert it[\"state\"] == \"pristine\", it
assert it[\"recommended\"] == \"REMOVE\", it
'"
echo "a customer edit, after the receipt was written" >> "$FIX_RECEIPT/docs/old-note.md"
bash "$RM" scan --json --root "$FIX_RECEIPT" > "$TMP/creceipt-customized.json" 2>&1
assert "…customized since: same baseline, state customized, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt-customized.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"receipt-sha256:$RECEIPT_SHA\", it
assert it[\"state\"] == \"customized\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"

# ─────────────────────────────────────────────────────────────────────────
# Round-5 finding 5 (medium, symlink-follow): _loom_rm_sha256_file's
# `[ -f "$f" ]` and Python's open() both DEREFERENCE a symlink. Same
# fixture as FIX_RECEIPT above (byte-identical content, corroborated
# against refs/loom-upstream/main so RECEIPT_SHA is a genuine upstream
# digest) — except the customer has since replaced docs/old-note.md ON
# DISK with a symlink to a file OUTSIDE the repository whose bytes happen
# to match RECEIPT_SHA. Before the fix, `[ -f symlink ]` was true and
# open() followed the link, so the hash matched and the file read back as
# pristine -> REMOVE, whose `git rm` would delete the symlink ENTRY itself
# (a path this tool never created) purely because of where it happens to
# point. The fix refuses to hash through a symlink at all.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "C. round-5 finding 5: a symlink at a receipt-sha256-baselined path is never read as pristine, even when its target's bytes match the recorded digest"
FIX_RECEIPT_SYMLINK="$TMP/fixture-receipt-symlink"
mkdir -p "$FIX_RECEIPT_SYMLINK/.logic-loom/config" "$FIX_RECEIPT_SYMLINK/.logic-loom/lib" "$FIX_RECEIPT_SYMLINK/docs"
git init -q "$FIX_RECEIPT_SYMLINK"
cp "$LIB" "$FIX_RECEIPT_SYMLINK/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.0" > "$FIX_RECEIPT_SYMLINK/.logic-loom/config/architecture.conf"
echo "path | docs/old-note.md | removed | command:/replacement-cmd | REMOVE | v6.0.0 | v9.0.0 | test fixture for the receipt-sha256 symlink-follow finding" \
  > "$FIX_RECEIPT_SYMLINK/.logic-loom/config/release-migrations.conf"
printf 'exactly what LogicLoom wrote here\n' > "$FIX_RECEIPT_SYMLINK/docs/old-note.md"
SYMLINK_RECEIPT_SHA="$(python3 -c '
import hashlib
print(hashlib.sha256(open("'"$FIX_RECEIPT_SYMLINK"'/docs/old-note.md", "rb").read()).hexdigest())
')"
cat > "$FIX_RECEIPT_SYMLINK/.logicloom-adopt-receipt.json" <<JSON
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-01-01T00:00:00.000Z",
      "generator": "logicloom-update-framework@1.0.0",
      "status": "complete",
      "only": [],
      "wrote": [
        { "target": "harness", "path": "docs/old-note.md", "kind": "file", "sha256": "$SYMLINK_RECEIPT_SHA" }
      ],
      "skipped": [], "failed": [], "notAttempted": []
    }
  ]
}
JSON
( cd "$FIX_RECEIPT_SYMLINK" && git add -A >/dev/null && git commit -q -m "adopted install (real file, corroborating commit)" )
git -C "$FIX_RECEIPT_SYMLINK" update-ref refs/loom-upstream/main HEAD
# The customer's own symlink replaces the tracked file on disk (unstaged),
# pointing OUTSIDE the repository at content with the SAME bytes.
SYMLINK_OUTSIDE="$TMP/fixture-receipt-symlink-outside"
mkdir -p "$SYMLINK_OUTSIDE"
printf 'exactly what LogicLoom wrote here\n' > "$SYMLINK_OUTSIDE/customer-owned.md"
rm -f "$FIX_RECEIPT_SYMLINK/docs/old-note.md"
ln -s "$SYMLINK_OUTSIDE/customer-owned.md" "$FIX_RECEIPT_SYMLINK/docs/old-note.md"
assert "sanity: the outside target's bytes really do match the recorded digest, and the tracked path really is a symlink on disk now" \
  "[ \"\$(python3 -c 'import hashlib; print(hashlib.sha256(open(\"'\"$SYMLINK_OUTSIDE\"'/customer-owned.md\", \"rb\").read()).hexdigest())')\" = \"\$SYMLINK_RECEIPT_SHA\" ] && [ -L '$FIX_RECEIPT_SYMLINK/docs/old-note.md' ]"
bash "$RM" scan --json --root "$FIX_RECEIPT_SYMLINK" > "$TMP/creceipt-symlink.json" 2>&1
assert "a symlink whose target byte-matches the receipt digest is NEVER read as pristine: state customized (or unknown), never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt-symlink.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"state\"] != \"pristine\", it
assert it[\"recommended\"] != \"REMOVE\", it
assert it[\"remove_command\"] == \"\", it
'"
assert "…and the symlink itself is untouched (still a symlink, same target)" \
  "[ -L '$FIX_RECEIPT_SYMLINK/docs/old-note.md' ] && [ \"\$(readlink '$FIX_RECEIPT_SYMLINK/docs/old-note.md')\" = '$SYMLINK_OUTSIDE/customer-owned.md' ]"

# Finding 7 (medium, round 5 review): a well-formed, trusted-generator,
# status=complete receipt entry is NOT enough on its own — it must also be
# CORROBORATED against refs/loom-upstream/main history. This fixture is
# byte-for-byte the FIX_RECEIPT pristine case above, MINUS the
# refs/loom-upstream/main ref: same trusted generator, same status
# "complete", same byte-identical content, same well-formed digest. Before
# this fix, that was already sufficient to read the file as pristine and
# recommend REMOVE on what could be a hand-edited receipt claiming a
# customer's own file as LogicLoom's. It must now fall through to no
# baseline instead.
echo ""
echo "C. finding 7: an uncorroborated receipt digest (no refs/loom-upstream/main reaching a matching blob) is never trusted alone"
FIX_RECEIPT_UNCORR="$TMP/fixture-receipt-uncorroborated"
mkdir -p "$FIX_RECEIPT_UNCORR/.logic-loom/config" "$FIX_RECEIPT_UNCORR/.logic-loom/lib" "$FIX_RECEIPT_UNCORR/docs"
git init -q "$FIX_RECEIPT_UNCORR"
cp "$LIB" "$FIX_RECEIPT_UNCORR/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.0" > "$FIX_RECEIPT_UNCORR/.logic-loom/config/architecture.conf"
echo "path | docs/old-note.md | removed | command:/replacement-cmd | REMOVE | v6.0.0 | v9.0.0 | uncorroborated-receipt fixture" \
  > "$FIX_RECEIPT_UNCORR/.logic-loom/config/release-migrations.conf"
printf 'exactly what LogicLoom wrote here\n' > "$FIX_RECEIPT_UNCORR/docs/old-note.md"
UNCORR_SHA="$(python3 -c '
import hashlib
print(hashlib.sha256(open("'"$FIX_RECEIPT_UNCORR"'/docs/old-note.md", "rb").read()).hexdigest())
')"
cat > "$FIX_RECEIPT_UNCORR/.logicloom-adopt-receipt.json" <<JSON
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-01-01T00:00:00.000Z",
      "generator": "logicloom-update-framework@1.0.0",
      "status": "complete",
      "only": [],
      "wrote": [
        { "target": "harness", "path": "docs/old-note.md", "kind": "file", "sha256": "$UNCORR_SHA" }
      ],
      "skipped": [], "failed": [], "notAttempted": []
    }
  ]
}
JSON
( cd "$FIX_RECEIPT_UNCORR" && git add -A >/dev/null && git commit -q -m "adopted install, no refs/loom-upstream/main" )
UNCORR_FIRST_COMMIT="$(git -C "$FIX_RECEIPT_UNCORR" rev-parse HEAD)"
assert "sanity: refs/loom-upstream/main really does not exist in this fixture" \
  "! git -C '$FIX_RECEIPT_UNCORR' rev-parse -q --verify refs/loom-upstream/main >/dev/null 2>&1"
bash "$RM" scan --json --root "$FIX_RECEIPT_UNCORR" > "$TMP/creceipt-uncorr.json" 2>&1
assert "no refs/loom-upstream/main at all: the receipt candidate is never trusted alone — baseline none, state unknown, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt-uncorr.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"none\", it
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"
# Positive control that this is about CORROBORATION and not merely about
# some other difference between the two fixtures: adding
# refs/loom-upstream/main at a commit whose docs/old-note.md does NOT match
# UNCORR_SHA (upstream shipped something else there) must still fail to
# corroborate — a ref existing is not enough, its HISTORY must contain the
# matching blob. Built as a genuinely DISJOINT commit via plumbing
# (hash-object/mktree/commit-tree), never a child of UNCORR_FIRST_COMMIT —
# a sequential `git commit` here would still carry that first commit in its
# own ancestry (git log -- <path> walks the WHOLE reachable history, not
# just the tip), which would corroborate for the wrong reason and defeat
# this negative control. Working tree/index untouched throughout.
UNREL_BLOB="$(printf 'a different upstream file entirely\n' | git -C "$FIX_RECEIPT_UNCORR" hash-object -w --stdin)"
UNREL_TREE="$(printf '100644 blob %s\tdocs/other.md\n' "$UNREL_BLOB" | git -C "$FIX_RECEIPT_UNCORR" mktree)"
UNREL_COMMIT="$(git -C "$FIX_RECEIPT_UNCORR" commit-tree "$UNREL_TREE" -m "upstream: unrelated, disjoint history — never shipped old-note.md's bytes")"
git -C "$FIX_RECEIPT_UNCORR" update-ref refs/loom-upstream/main "$UNREL_COMMIT"
bash "$RM" scan --json --root "$FIX_RECEIPT_UNCORR" > "$TMP/creceipt-uncorr2.json" 2>&1
assert "refs/loom-upstream/main exists but its (disjoint) history never shipped the matching blob: still baseline none, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt-uncorr2.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"none\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"
# Negative-to-positive delta: pointing refs/loom-upstream/main at the
# commit that DOES carry the matching blob (this fixture's very first
# commit, captured right after it was made) now corroborates it.
git -C "$FIX_RECEIPT_UNCORR" update-ref refs/loom-upstream/main "$UNCORR_FIRST_COMMIT"
bash "$RM" scan --json --root "$FIX_RECEIPT_UNCORR" > "$TMP/creceipt-corr.json" 2>&1
assert "…and once refs/loom-upstream/main reaches the commit that DOES carry the matching blob: baseline receipt-sha256:<hash>, pristine, REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt-corr.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"receipt-sha256:$UNCORR_SHA\", it
assert it[\"state\"] == \"pristine\", it
assert it[\"recommended\"] == \"REMOVE\", it
'"

echo ""
echo "C. the receipt route must read the digest the REAL writers store: \"sha256:<hex>\""
echo "   (packaging/adopt fsops.js sha256File and record-update-writes.sh's JSON helper both prefix it)"
# The fixture above fabricated a bare-hex digest; no shipped writer produces
# that. Against a real receipt the comparison must still work, and a digest
# that is not a sha256 at all must prove nothing.
FIX_RECEIPT2="$TMP/fixture-receipt-realformat"
mkdir -p "$FIX_RECEIPT2/.logic-loom/config" "$FIX_RECEIPT2/.logic-loom/lib" "$FIX_RECEIPT2/docs"
git init -q "$FIX_RECEIPT2"
cp "$LIB" "$FIX_RECEIPT2/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.0" > "$FIX_RECEIPT2/.logic-loom/config/architecture.conf"
echo "path | docs/old-note.md | removed | command:/replacement-cmd | REMOVE | v6.0.0 | v9.0.0 | real-format receipt digest" \
  > "$FIX_RECEIPT2/.logic-loom/config/release-migrations.conf"
printf 'exactly what LogicLoom wrote here\n' > "$FIX_RECEIPT2/docs/old-note.md"
RECEIPT2_SHA="$(python3 -c '
import hashlib
print(hashlib.sha256(open("'"$FIX_RECEIPT2"'/docs/old-note.md", "rb").read()).hexdigest())
')"
mk_receipt2() {  # $1 = the "sha256" field value, recorded verbatim
  cat > "$FIX_RECEIPT2/.logicloom-adopt-receipt.json" <<JSON
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-01-01T00:00:00.000Z",
      "generator": "logicloom-update-framework@1.0.0",
      "status": "complete",
      "only": [],
      "wrote": [
        { "target": "harness", "path": "docs/old-note.md", "kind": "file", "sha256": "$1" }
      ],
      "skipped": [], "failed": [], "notAttempted": []
    }
  ]
}
JSON
}
mk_receipt2 "sha256:$RECEIPT2_SHA"
( cd "$FIX_RECEIPT2" && git add -A >/dev/null && git commit -q -m "adopted install, real-format receipt" )
# Finding 7 (round 5 review): corroborate against refs/loom-upstream/main —
# same reasoning as FIX_RECEIPT above.
git -C "$FIX_RECEIPT2" update-ref refs/loom-upstream/main HEAD
bash "$RM" scan --json --root "$FIX_RECEIPT2" > "$TMP/creceipt2-pristine.json" 2>&1
assert "a real-format digest (\"sha256:<hex>\") on byte-identical content: baseline receipt-sha256:<bare hex>, pristine, REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt2-pristine.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"receipt-sha256:$RECEIPT2_SHA\", it
assert it[\"state\"] == \"pristine\", it
assert it[\"recommended\"] == \"REMOVE\", it
'"
echo "a customer edit, after the receipt was written" >> "$FIX_RECEIPT2/docs/old-note.md"
bash "$RM" scan --json --root "$FIX_RECEIPT2" > "$TMP/creceipt2-customized.json" 2>&1
assert "…customized since: state customized, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt2-customized.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"receipt-sha256:$RECEIPT2_SHA\", it
assert it[\"state\"] == \"customized\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"
# a recorded digest that is not a 64-hex sha256 at all (an older or
# placeholder entry — test_adopt_applier.sh's receipts carry "sha256:aaaa")
# proves nothing about the bytes on disk: no baseline, never REMOVE, even
# though the file is byte-identical to what LogicLoom wrote.
printf 'exactly what LogicLoom wrote here\n' > "$FIX_RECEIPT2/docs/old-note.md"
mk_receipt2 "sha256:aaaa"
bash "$RM" scan --json --root "$FIX_RECEIPT2" > "$TMP/creceipt2-malformed.json" 2>&1
assert "a malformed recorded digest (\"sha256:aaaa\") is unusable: baseline none, state unknown, never REMOVE — even on byte-identical content" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt2-malformed.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"none\", it
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"
# Round-2 finding 4: the assertion above is NOT discriminating on its own —
# a script with NO malformed-digest check at all (one that never reads the
# receipt route in the first place) produces the exact same "none"/"unknown"
# result on THIS fixture, for a completely different reason (there is no
# other baseline candidate here either way). Proving the REJECTION
# mechanism actually fired — not merely that the receipt route is absent —
# needs a DELTA: the SAME path, SAME fixture, differing ONLY in whether the
# recorded digest is well-formed, must resolve to a DIFFERENT baseline. A
# script that cannot parse/validate receipts at all would give "none" for
# BOTH runs (no delta); this fails closed only when the well-formed run
# resolves through the receipt route and the malformed run does not.
assert "…and the malformed digest actually MATTERS: baseline differs from the well-formed run on the identical fixture/path (proves the mechanism fired, not merely 'no receipt route')" \
  "python3 -c '
import json
well = json.load(open(\"$TMP/creceipt2-pristine.json\"))
mal = json.load(open(\"$TMP/creceipt2-malformed.json\"))
wit = next(i for i in well[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
mit = next(i for i in mal[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert wit[\"baseline\"] == \"receipt-sha256:$RECEIPT2_SHA\", wit
assert mit[\"baseline\"] == \"none\", mit
assert wit[\"baseline\"] != mit[\"baseline\"], (wit[\"baseline\"], mit[\"baseline\"])
'"

echo ""
echo "C. round-3 finding 2: a receipt digest is trusted ONLY from LogicLoom's own writers, status=complete"
FIX_RECEIPT3="$TMP/fixture-receipt-provenance"
mkdir -p "$FIX_RECEIPT3/.logic-loom/config" "$FIX_RECEIPT3/.logic-loom/lib" "$FIX_RECEIPT3/docs"
git init -q "$FIX_RECEIPT3"
cp "$LIB" "$FIX_RECEIPT3/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.0" > "$FIX_RECEIPT3/.logic-loom/config/architecture.conf"
echo "path | docs/old-note.md | removed | command:/replacement-cmd | REMOVE | v6.0.0 | v9.0.0 | receipt-provenance fixture" \
  > "$FIX_RECEIPT3/.logic-loom/config/release-migrations.conf"
printf 'exactly what LogicLoom wrote here\n' > "$FIX_RECEIPT3/docs/old-note.md"
RECEIPT3_SHA="$(python3 -c '
import hashlib
print(hashlib.sha256(open("'"$FIX_RECEIPT3"'/docs/old-note.md", "rb").read()).hexdigest())
')"
mk_receipt3() {  # $1 = generator string  $2 = status
  cat > "$FIX_RECEIPT3/.logicloom-adopt-receipt.json" <<JSON
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-01-01T00:00:00.000Z",
      "generator": "$1",
      "status": "$2",
      "only": [],
      "wrote": [
        { "target": "harness", "path": "docs/old-note.md", "kind": "file", "sha256": "sha256:$RECEIPT3_SHA" }
      ],
      "skipped": [], "failed": [], "notAttempted": []
    }
  ]
}
JSON
}
( cd "$FIX_RECEIPT3" && git add -A >/dev/null && git commit -q -m "adopted install" )
# Finding 7 (round 5 review): corroborate against refs/loom-upstream/main —
# same reasoning as FIX_RECEIPT above. Every mk_receipt3 variant below
# records the SAME $RECEIPT3_SHA against the SAME already-committed bytes,
# so one ref covers all of them; this fixture is about generator/status
# provenance, not corroboration, and must still exercise that check
# unblocked by the corroboration gate this section is not testing.
git -C "$FIX_RECEIPT3" update-ref refs/loom-upstream/main HEAD

# A run written by a FOREIGN generator (not one of LogicLoom's own two
# writers) must never establish a baseline, even with byte-identical content
# and a well-formed digest — the receipt is adopter-editable, so "the
# generator string says LogicLoom" proves nothing on its own.
mk_receipt3 "some-other-tool@3.1.4" "complete"
bash "$RM" scan --json --root "$FIX_RECEIPT3" > "$TMP/creceipt3-foreign.json" 2>&1
assert "a FOREIGN generator (some-other-tool@3.1.4), status complete, byte-identical + well-formed digest: baseline none, state unknown, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt3-foreign.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"none\", it
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"

# The npm installer's own generator shape (\"logicloom@<version>\" — see
# packaging/adopt/lib/plan.js's default pkgName) IS trusted, distinct from
# the v7 recorder's \"logicloom-update-framework@<version>\" (already proven
# above). status complete.
mk_receipt3 "logicloom@2.0.0" "complete"
bash "$RM" scan --json --root "$FIX_RECEIPT3" > "$TMP/creceipt3-npm.json" 2>&1
assert "the npm installer's generator shape (logicloom@2.0.0), status complete: baseline receipt-sha256:<hash>, pristine, REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt3-npm.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"receipt-sha256:$RECEIPT3_SHA\", it
assert it[\"state\"] == \"pristine\", it
assert it[\"recommended\"] == \"REMOVE\", it
'"

# A TRUSTED generator whose run never finished (status partial/in-progress)
# is not vouching for the bytes it left behind — never a baseline either.
for badstatus in partial in-progress; do
  mk_receipt3 "logicloom-update-framework@2.0.0" "$badstatus"
  bash "$RM" scan --json --root "$FIX_RECEIPT3" > "$TMP/creceipt3-$badstatus.json" 2>&1
  assert "a trusted generator but status=$badstatus (run never finished): baseline none, state unknown, never REMOVE" \
    "python3 -c '
import json
d = json.load(open(\"$TMP/creceipt3-$badstatus.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"none\", it
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"
done

# Sanity delta (same shape as the malformed-digest proof above): the SAME
# fixture/path resolves to a DIFFERENT baseline depending purely on
# generator/status, proving the provenance check actually fired.
assert "…and the trusted-generator, status=complete run really is what makes the difference (delta vs the foreign-generator run above)" \
  "python3 -c '
import json
trusted = json.load(open(\"$TMP/creceipt3-npm.json\"))
foreign = json.load(open(\"$TMP/creceipt3-foreign.json\"))
tit = next(i for i in trusted[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
fit = next(i for i in foreign[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert tit[\"baseline\"] != fit[\"baseline\"], (tit[\"baseline\"], fit[\"baseline\"])
'"

echo ""
echo "C. cross-file finding: a receipt-sha256 candidate that MATCHES DISK must win over a"
echo "   sync-ref candidate that merely EXISTS but does not — the mid-run clean-apply case"
echo "   (.sdd-sync-ref advances at Step 6/8, AFTER record-update-writes.sh runs at Step"
echo "   5/7b), which otherwise makes the receipt-sha256 route (finding 1's ADOPTED fix)"
echo "   a dead branch for the common case: a MODIFIED path, present at both the stale"
echo "   sync-ref commit and in the receipt"
# Two upstream commits (U0 old, U1 new) on disjoint lines, exactly like the
# .sdd-sync-ref forgery fixture above: U0 is what .sdd-sync-ref still names
# (not yet advanced); U1 is what refs/loom-upstream/main holds (what a
# clean-apply just wrote to disk) and record-update-writes.sh's real
# two-candidate resolver records into the receipt. Verbs (throwaway repo
# only): init, add, commit, branch, checkout, update-ref.
FIX_DEADBRANCH="$TMP/fixture-receipt-vs-stale-syncref"
mkdir -p "$FIX_DEADBRANCH/.logic-loom/config" "$FIX_DEADBRANCH/.logic-loom/lib" "$FIX_DEADBRANCH/docs"
git init -q "$FIX_DEADBRANCH"
cp "$LIB" "$FIX_DEADBRANCH/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.0" > "$FIX_DEADBRANCH/.logic-loom/config/architecture.conf"
echo "path | docs/note.md | removed | command:/replacement-cmd | REMOVE | v6.0.0 | v9.0.0 | dead-branch fixture" \
  > "$FIX_DEADBRANCH/.logic-loom/config/release-migrations.conf"
printf 'content v1 (old)\n' > "$FIX_DEADBRANCH/docs/note.md"
( cd "$FIX_DEADBRANCH" && git add -A >/dev/null && git commit -q -m "U0: old content" )
DB_U0="$(git -C "$FIX_DEADBRANCH" rev-parse HEAD)"
echo "$DB_U0" > "$FIX_DEADBRANCH/.sdd-sync-ref"
( cd "$FIX_DEADBRANCH" && git add .sdd-sync-ref >/dev/null && git commit -q -m "record sync ref" )
cat > "$FIX_DEADBRANCH/.logicloom-adopt-receipt.json" <<'JSON'
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    { "at": "2026-01-01T00:00:00.000Z", "generator": "logicloom-adopt@1.0.0",
      "status": "complete", "only": [], "wrote": [], "skipped": [], "failed": [], "notAttempted": [] }
  ]
}
JSON
( cd "$FIX_DEADBRANCH" && git add -A >/dev/null && git commit -q -m "adopt receipt (pre-existing, no docs/note.md entry yet)" )
( cd "$FIX_DEADBRANCH" && git branch upstream-scratch "$DB_U0" >/dev/null )
( cd "$FIX_DEADBRANCH" && git checkout -q upstream-scratch )
printf 'content v2 (new upstream bytes)\n' > "$FIX_DEADBRANCH/docs/note.md"
( cd "$FIX_DEADBRANCH" && git commit -q -am "U1: upstream modifies docs/note.md" )
DB_U1="$(git -C "$FIX_DEADBRANCH" rev-parse HEAD)"
( cd "$FIX_DEADBRANCH" && git update-ref refs/loom-upstream/main "$DB_U1" )
( cd "$FIX_DEADBRANCH" && git checkout -q - )
# Simulate a clean-apply having just written the new bytes to disk,
# uncommitted, BEFORE .sdd-sync-ref is advanced — record-update-writes.sh's
# real two-candidate resolver records the digest that matches disk (U1's).
printf 'content v2 (new upstream bytes)\n' > "$FIX_DEADBRANCH/docs/note.md"
bash "$RECORDER" docs/note.md --version 9.0.0 --root "$FIX_DEADBRANCH" >/dev/null
DB_SHA="$(python3 -c '
import hashlib
print(hashlib.sha256(open("'"$FIX_DEADBRANCH"'/docs/note.md", "rb").read()).hexdigest())
')"
bash "$RM" scan --json --root "$FIX_DEADBRANCH" > "$TMP/cdeadbranch.json" 2>&1
assert "receipt-sha256 (matches disk) wins over a stale-but-present sync-ref: baseline receipt-sha256:<hash>, pristine, REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/cdeadbranch.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/note.md\")
assert it[\"baseline\"] == \"receipt-sha256:$DB_SHA\", it
assert it[\"state\"] == \"pristine\", it
assert it[\"recommended\"] == \"REMOVE\", it
'"
# A genuine customer edit on top of the clean-apply content matches NEITHER
# candidate: falls back to the (stale) sync-ref, as before this fix —
# customized, never REMOVE. The ordering change must never widen who reads
# as pristine, only who does among candidates that ALREADY prove it.
printf 'content v2 (new upstream bytes)\ncustomer edit on top\n' > "$FIX_DEADBRANCH/docs/note.md"
bash "$RM" scan --json --root "$FIX_DEADBRANCH" > "$TMP/cdeadbranch-customized.json" 2>&1
# Round-2 finding 4: on its own, this assertion is NOT discriminating — a
# script with no two-candidate ordering logic at all (one that only ever
# consults sync-ref, never the receipt) reaches the IDENTICAL sync-ref
# fallback for the identical reason, since the receipt route was never in
# play for it either. What actually proves the ordering fix exists is that
# THIS SAME item, on THIS SAME fixture, resolved through the RECEIPT route a
# moment ago (the assertion right above) and now resolves through the
# SYNC-REF route once disk no longer matches either upstream candidate — a
# script lacking the two-candidate mechanism cannot produce that first half
# at all (it would show sync-ref there too), so bundling both halves into
# one assertion is what makes this fail against such a script.
assert "…and once the adopter edits on top of that: neither candidate matches disk, falls back to the stale sync-ref, customized, never REMOVE — proven against the SAME two-candidate mechanism that resolved receipt-sha256 a moment ago, not a coincidence of sync-ref being the only route this script has" \
  "python3 -c '
import json
pristine = json.load(open(\"$TMP/cdeadbranch.json\"))
d = json.load(open(\"$TMP/cdeadbranch-customized.json\"))
pit = next(i for i in pristine[\"items\"] if i[\"path\"] == \"docs/note.md\")
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/note.md\")
assert pit[\"baseline\"].startswith(\"receipt-sha256:\"), pit
assert it[\"baseline\"] == \"sync-ref:$DB_U0\", it
assert it[\"state\"] == \"customized\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"

echo ""
echo "C. .sdd-sync-ref is a baseline ONLY in the shape LogicLoom writes it (a hex object name)"
echo "   AND, when upstream history is present, only if upstream main reaches it — a customer's"
echo "   own commit written there must never read their customized bytes as pristine"
# Two disjoint lines in one throwaway repo: the upstream line U1 (ships
# sdd-dev-loop) -> U2 (retires it), with refs/loom-upstream/main = U2; and
# the customer line C1, branched from U1, where the customer customized the
# plugin. C1 is not reachable from upstream main — it is not LogicLoom's
# commit — yet before this fix, writing it into .sdd-sync-ref made the
# scanner diff the customized plugin against ITSELF: pristine, REMOVE.
# Verbs (throwaway repo only): init, add, commit, rm, checkout, update-ref.
FIX_SYNC="$TMP/fixture-syncref-forged"
mkdir -p "$FIX_SYNC/.logic-loom/config" "$FIX_SYNC/.logic-loom/lib" "$FIX_SYNC/plugins/sdd-dev-loop"
git init -q "$FIX_SYNC"
cp "$LIB" "$FIX_SYNC/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=7.0.0" > "$FIX_SYNC/.logic-loom/config/architecture.conf"
echo "plugin | sdd-dev-loop | native | native:/workflow,/loop,/goal | REMOVE | v4.0.0 | v6.2.0 | x" > "$FIX_SYNC/.logic-loom/config/release-migrations.conf"
echo "LogicLoom's shipped body" > "$FIX_SYNC/plugins/sdd-dev-loop/marker.txt"
( cd "$FIX_SYNC" && git add -A >/dev/null && git commit -q -m "U1: upstream ships sdd-dev-loop" )
SYNC_U1="$(git -C "$FIX_SYNC" rev-parse HEAD)"
( cd "$FIX_SYNC" && git rm -rq plugins/sdd-dev-loop >/dev/null && git commit -q -m "U2: upstream retires it" )
git -C "$FIX_SYNC" update-ref refs/loom-upstream/main HEAD
( cd "$FIX_SYNC" && git checkout -q "$SYNC_U1" && git checkout -q -b customer )
echo "the CUSTOMER's own edit — not LogicLoom's bytes" >> "$FIX_SYNC/plugins/sdd-dev-loop/marker.txt"
( cd "$FIX_SYNC" && git add -A >/dev/null && git commit -q -m "C1: customer customizes sdd-dev-loop" )
SYNC_C1="$(git -C "$FIX_SYNC" rev-parse HEAD)"
assert "fixture: the customer's commit is NOT reachable from refs/loom-upstream/main" \
  "! git -C '$FIX_SYNC' merge-base --is-ancestor '$SYNC_C1' refs/loom-upstream/main"
sync_scan() {  # $1 = .sdd-sync-ref content, $2 = json output path
  printf '%s\n' "$1" > "$FIX_SYNC/.sdd-sync-ref"
  bash "$RM" scan --json --root "$FIX_SYNC" > "$2" 2>&1
}
sync_scan "$SYNC_C1" "$TMP/csync-own.json"
assert "the customer's OWN commit sha in .sdd-sync-ref (upstream history present, commit not reachable from it): never a sync-ref baseline, never pristine, never REMOVE, no remove command" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/csync-own.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert not it[\"baseline\"].startswith(\"sync-ref:\"), it
assert it[\"state\"] != \"pristine\", it
assert it[\"recommended\"] != \"REMOVE\", it
assert it[\"remove_command\"] == \"\", it
'"
sync_scan "HEAD" "$TMP/csync-head.json"
assert "a symbolic name (HEAD) in .sdd-sync-ref is not the shape LogicLoom writes: never a sync-ref baseline, never pristine, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/csync-head.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert not it[\"baseline\"].startswith(\"sync-ref:\"), it
assert it[\"state\"] != \"pristine\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"
sync_scan "$SYNC_U1" "$TMP/csync-genuine.json"
assert "positive control: the genuine upstream commit (reachable from upstream main) IS the sync-ref baseline, and the customized plugin reads customized -> CONVERT-TO-LOCAL" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/csync-genuine.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"baseline\"] == \"sync-ref:$SYNC_U1\", it
assert it[\"state\"] == \"customized\", it
assert it[\"recommended\"] == \"CONVERT-TO-LOCAL\", it
'"
# Round-2 finding 1 (fix BY DESIGN, reversing round-1's permissive
# fallback): with no upstream history at all there is NO BASELINE, full
# stop — hex shape alone is NEVER enough, because there is nothing to check
# reachability against and a customer's own commit sha is indistinguishable
# from LogicLoom's record by shape. A symbolic name still never qualifies
# either (that part was already correct).
git -C "$FIX_SYNC" update-ref -d refs/loom-upstream/main
sync_scan "HEAD" "$TMP/csync-head-noup.json"
assert "…and with no upstream history, HEAD in .sdd-sync-ref is still rejected on shape: baseline none, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/csync-head-noup.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"baseline\"] == \"none\", it
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"
# The regression this fix closes: a GENUINELY hex, GENUINELY real upstream
# commit sha (SYNC_U1 — the very commit the positive control above accepted
# a moment ago, while refs/loom-upstream/main still existed) must now be
# rejected the instant that history is gone. Before this fix, hex shape
# alone would have re-admitted it as a baseline, silently reading the
# customized plugin as pristine again the moment refs/loom-upstream/main
# went missing (extract-proposals.sh --dry-run prunes it — see
# upstream_blob_sha's own comment on that in record-update-writes.sh).
sync_scan "$SYNC_U1" "$TMP/csync-genuine-noup.json"
assert "…and even a hex sha that WAS a genuine upstream commit is rejected once refs/loom-upstream/main is gone (no baseline to prove it against): baseline none, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/csync-genuine-noup.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"baseline\"] == \"none\", it
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"
# And the forged (customer) commit specifically, without upstream history —
# the task's own two-by-two matrix (forged sync-ref, with AND without
# refs/loom-upstream/main present) completed for the scanner half.
sync_scan "$SYNC_C1" "$TMP/csync-own-noup.json"
assert "…and the customer's OWN forged commit, now with no upstream history either: still baseline none, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/csync-own-noup.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-dev-loop\")
assert it[\"baseline\"] == \"none\", it
assert it[\"state\"] == \"unknown\", it
assert it[\"recommended\"] != \"REMOVE\", it
'"

echo ""
echo "C. finding 4 (formerly 5a): the printed/apply MOVE command re-checks the destination ITSELF and refuses rather than relying on a bare git mv's own failure"
# background reproduction: a bare git mv onto an existing destination already
# fails cleanly (non-destructive) — that was never the gap. The gap the
# reviewers flagged is that the RECOMMENDATION is computed at scan/plan time
# and never re-checked when it is actually run later; the fix below makes the
# printed/apply command re-check immediately before it acts, every time.
MVTEST="$TMP/movetest"
mkdir -p "$MVTEST"; git init -q "$MVTEST"
echo old > "$MVTEST/old.txt"; ( cd "$MVTEST" && git add -A >/dev/null && git commit -qm init )
echo new > "$MVTEST/new.txt"; ( cd "$MVTEST" && git add -A >/dev/null && git commit -qm addnew )
( cd "$MVTEST" && git mv old.txt new.txt >/dev/null 2>"$TMP/mv.err" )
MV_RC=$?
assert "a bare git mv onto an existing destination fails (non-zero), not silently" "[ $MV_RC -ne 0 ]"
assert "…and the freshly-added destination's content is untouched (no overwrite)" \
  "[ \"\$(cat '$MVTEST/new.txt')\" = new ]"

# the actual fix: build a MOVE fixture, capture the real move_command scan
# computes, then let a clean-add land at the destination AFTER that — exactly
# the same-run race the finding describes — and run the CAPTURED command
# for real.
MVFIX="$TMP/movefix"
mkdir -p "$MVFIX/.logic-loom/config" "$MVFIX/.logic-loom/lib" "$MVFIX/old"
git init -q "$MVFIX"
cp "$LIB" "$MVFIX/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=7.0.0" > "$MVFIX/.logic-loom/config/architecture.conf"
echo "thing" > "$MVFIX/old/thing.md"
( cd "$MVFIX" && git add -A >/dev/null && git commit -q -m "old/thing.md present" )
git -C "$MVFIX" rev-parse HEAD > "$MVFIX/.sdd-sync-ref"
( cd "$MVFIX" && git add -A >/dev/null && git commit -q -m "stamp sync-ref" )
# Round-2 finding 1: the sync-ref is only a baseline when refs/loom-upstream/
# main exists and reaches it.
git -C "$MVFIX" update-ref refs/loom-upstream/main HEAD
MVFIX_REG="$TMP/movefix-reg.conf"
echo 'path | old/thing.md | renamed | path:new/thing.md | MOVE | v6.0.0 | v9.0.0 | moved' > "$MVFIX_REG"

bash "$RM" scan --json --root "$MVFIX" --registry "$MVFIX_REG" > "$TMP/mvfix.json" 2>&1
MVFIX_CMD="$(python3 -c '
import json
d = json.load(open("'"$TMP"'/mvfix.json"))
it = next(i for i in d["items"] if i["path"] == "old/thing.md")
print(it["move_command"])
')"
assert "the computed move_command is non-empty" "[ -n \"\$MVFIX_CMD\" ]"

mkdir -p "$MVFIX/new"
echo "freshly added, must survive" > "$MVFIX/new/thing.md"
( cd "$MVFIX" && bash -c "$MVFIX_CMD" >"$TMP/mvfix-run.out" 2>"$TMP/mvfix-run.err" )
MVFIX_RUN_RC=$?
assert "running the CAPTURED move_command against a since-appeared destination: refuses (non-zero), never overwrites" \
  "[ $MVFIX_RUN_RC -ne 0 ]"
assert "…the refusal names the destination and tells the agent to re-run plan" \
  "grep -q 'new/thing.md already exists on disk' '$TMP/mvfix-run.err' && grep -q 're-run: release-migrations.sh plan old/thing.md' '$TMP/mvfix-run.err'"
assert "…and neither file was touched: destination content unchanged, source still present" \
  "[ \"\$(cat '$MVFIX/new/thing.md')\" = 'freshly added, must survive' ] && [ -f '$MVFIX/old/thing.md' ]"

# positive control: with no destination in the way, the SAME captured command
# performs the move.
rm -rf "$MVFIX/new"
( cd "$MVFIX" && bash -c "$MVFIX_CMD" >"$TMP/mvfix-run2.out" 2>"$TMP/mvfix-run2.err" )
MVFIX_RUN2_RC=$?
assert "…and with no destination in the way, the same captured command succeeds and actually moves the file" \
  "[ $MVFIX_RUN2_RC -eq 0 ] && [ ! -e '$MVFIX/old/thing.md' ] && [ -f '$MVFIX/new/thing.md' ]"

# ─────────────────────────────────────────────────────────────────────────
# Round-5 finding 9 (low, diagnostic-accuracy gap): `-e` alone is FALSE for
# a DANGLING symlink (target does not exist), so the guard's own friendly
# refusal message would not fire for one — bypassed straight to a bare
# `git mv`, which independently refuses to overwrite an existing lstat
# entry (confirmed above: a bare `git mv` onto a real pre-existing
# destination already fails cleanly). A FRESH fixture, not $MVFIX reused —
# $MVFIX's positive control just above already consumed its own
# old/thing.md -> new/thing.md move, so new/thing.md there is now a real
# tracked file, not an available slot for a dangling symlink.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "C. round-5 finding 9: the printed/apply MOVE command's own guard also fires for a DANGLING symlink at the destination, not only a real file"
MVFIX9="$TMP/movefix-dangling-symlink"
mkdir -p "$MVFIX9/.logic-loom/config" "$MVFIX9/.logic-loom/lib" "$MVFIX9/old"
git init -q "$MVFIX9"
cp "$LIB" "$MVFIX9/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=7.0.0" > "$MVFIX9/.logic-loom/config/architecture.conf"
echo "thing" > "$MVFIX9/old/thing.md"
( cd "$MVFIX9" && git add -A >/dev/null && git commit -q -m "old/thing.md present" )
git -C "$MVFIX9" rev-parse HEAD > "$MVFIX9/.sdd-sync-ref"
( cd "$MVFIX9" && git add -A >/dev/null && git commit -q -m "stamp sync-ref" )
git -C "$MVFIX9" update-ref refs/loom-upstream/main HEAD
MVFIX9_REG="$TMP/movefix9-reg.conf"
echo 'path | old/thing.md | renamed | path:new/thing.md | MOVE | v6.0.0 | v9.0.0 | moved' > "$MVFIX9_REG"
bash "$RM" scan --json --root "$MVFIX9" --registry "$MVFIX9_REG" > "$TMP/mvfix9.json" 2>&1
MVFIX9_CMD="$(python3 -c '
import json
d = json.load(open("'"$TMP"'/mvfix9.json"))
it = next(i for i in d["items"] if i["path"] == "old/thing.md")
print(it["move_command"])
')"
assert "the computed move_command is non-empty" "[ -n \"\$MVFIX9_CMD\" ]"
mkdir -p "$MVFIX9/new"
ln -s /nonexistent/round5-finding9-target "$MVFIX9/new/thing.md"
assert "sanity: the destination really is a dangling symlink now (-e false, -L true)" \
  "[ ! -e '$MVFIX9/new/thing.md' ] && [ -L '$MVFIX9/new/thing.md' ]"
( cd "$MVFIX9" && bash -c "$MVFIX9_CMD" >"$TMP/mvfix9-run.out" 2>"$TMP/mvfix9-run.err" )
MVFIX9_RUN_RC=$?
assert "running the CAPTURED move_command against a dangling symlink at the destination: refuses (non-zero), never overwrites" \
  "[ $MVFIX9_RUN_RC -ne 0 ]"
assert "…the refusal is THIS TOOL's own friendly message (not a bare git mv error), naming the destination and telling the agent to re-run plan" \
  "grep -q 'new/thing.md already exists on disk' '$TMP/mvfix9-run.err' && grep -q 're-run: release-migrations.sh plan old/thing.md' '$TMP/mvfix9-run.err'"
assert "…the dangling symlink itself is untouched (still a symlink, same target) and the source is still present" \
  "[ -L '$MVFIX9/new/thing.md' ] && [ \"\$(readlink '$MVFIX9/new/thing.md')\" = '/nonexistent/round5-finding9-target' ] && [ -f '$MVFIX9/old/thing.md' ]"

echo ""
echo "C. finding 5b (investigated, refuted as a live exploit): the removal guard's"
echo "   has_row check matches on (kind,name) only, not the row's release field —"
echo "   but the registry lint enforces AT MOST ONE row per (kind,name) globally,"
echo "   so within a single linted registry file there is no 'wrong release' row"
echo "   to collide with; check-release's has_row only ever reads REGISTRY_FILE"
echo "   (never project-migrations.conf), so a project-side collision cannot"
echo "   reach it either. Reproduced: lint rejects a duplicate (kind,name) pair."
DUPREG="$TMP/dup-registry.conf"
printf 'plugin | sdd-dup | removed | none | REMOVE | v4.0.0 | v5.0.0 | first\nplugin | sdd-dup | removed | none | REMOVE | v4.0.0 | v9.0.0 | second, different release\n' > "$DUPREG"
bash "$RM" lint --registry "$DUPREG" --root "$ROOT" > "$TMP/duplint.out" 2>&1
DUP_RC=$?
assert "a second row for the same (kind,name) at a different release: lint fails, 'duplicate deprecation name'" \
  "[ $DUP_RC -eq 1 ] && grep -q 'duplicate deprecation name sdd-dup' '$TMP/duplint.out'"

echo ""
echo "C. finding 6 (KORI CLASS): PROPOSE-ADVISORY content row on a fork-owned file"
FIX_KORI="$TMP/fixture-kori"; cp -R "$FIX1" "$FIX_KORI"
mkdir -p "$FIX_KORI/.logic-loom/memory"
cp "$ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.before" "$FIX_KORI/.logic-loom/memory/amendments.md"
bash "$RM" scan --json --root "$FIX_KORI" > "$TMP/ckori-old.json" 2>&1
assert "old alternative-line wording: fires, kind content, advisory true, recommended PROPOSE-ADVISORY" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/ckori-old.json\"))
it = next((i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \".logic-loom/memory/amendments.md\"), None)
assert it is not None, d[\"items\"]
assert it[\"advisory\"] is True, it
assert it[\"recommended\"] == \"PROPOSE-ADVISORY\", it
assert \"LogicLoom did not ship this text\" in it[\"reason\"], it[\"reason\"]
'"
bash "$RM" scan --root "$FIX_KORI" > "$TMP/ckori-old.human" 2>&1
assert "human output states plainly LogicLoom did not ship this text (advisory banner)" \
  "grep -q 'ADVISORY .*LogicLoom did not ship this text' '$TMP/ckori-old.human'"
cp "$ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.after" "$FIX_KORI/.logic-loom/memory/amendments.md"
bash "$RM" scan --json --root "$FIX_KORI" > "$TMP/ckori-new.json" 2>&1
assert "new additive '+3' wording: does NOT fire" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/ckori-new.json\"))
assert not any(i.get(\"kind\") == \"content\" and i[\"path\"] == \".logic-loom/memory/amendments.md\" for i in d[\"items\"]), d[\"items\"]
'"
# fires the same way in ADOPTED mode, with NO adopt-receipt entry for
# amendments.md — the ownership-scoping rule the receipt-based rows use does
# not apply to an advisory row (the harness never wrote this file).
mkdir -p "$FIX_ADOPT/.logic-loom/memory"
cp "$ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.before" "$FIX_ADOPT/.logic-loom/memory/amendments.md"
bash "$RM" scan --json --root "$FIX_ADOPT" > "$TMP/ckori-adopted.json" 2>&1
assert "fires the same way in ADOPTED mode with no receipt entry for amendments.md (never ownership-scoped)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/ckori-adopted.json\"))
it = next((i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \".logic-loom/memory/amendments.md\"), None)
assert it is not None, d[\"items\"]
assert it[\"advisory\"] is True, it
'"
assert "lint rejects PROPOSE-ADVISORY on a non-fork-owned target" \
  "printf 'content | some/random/file.md | present | pattern:x | PROPOSE-ADVISORY | - | v9.9.9 | proposal: a; why: b\n' > '$TMP/kori-bad.conf' \
   && ! bash '$RM' lint --registry '$TMP/kori-bad.conf' --root '$ROOT' >/dev/null 2>&1"
assert "…and accepts it on CLAUDE.local.md (an allowed fork-owned basename)" \
  "printf 'content | CLAUDE.local.md | present | pattern:x | PROPOSE-ADVISORY | - | v9.9.9 | proposal: a; why: b\n' > '$TMP/kori-ok.conf' \
   && bash '$RM' lint --registry '$TMP/kori-ok.conf' --root '$ROOT' >/dev/null 2>&1"
# reviewer (finding 6): the fork's REAL line is a markdown list item —
# `- 3 = it changes auth, payment, or customer-data logic` (kori-beta
# amendments.md:148; design §14.3 shows the same bulleted form). A pattern
# anchored `^[[:space:]]*3` never matched it. These assert the SHIPPED
# pattern (read back through the lib, so `\|` decoding is exercised too)
# against the real forms, and that no `+3` spelling fires.
KORI_PAT="$(printf '%s' "$KORIROW" | awk -F'\t' '{print $4}')"; KORI_PAT="${KORI_PAT#pattern:}"
kori_pat_hits() { printf '%s\n' "$1" | grep -qE -- "$KORI_PAT"; }
assert "KORI pattern matches the real fork form: '- 3 = it changes auth, payment, or customer-data logic' (bulleted)" \
  "kori_pat_hits '- 3 = it changes auth, payment, or customer-data logic'"
assert "…and the master doc's indented bare form: '  3 = it changes …'" \
  "kori_pat_hits '  3 = it changes auth, payment, or customer-data logic'"
assert "…and an em-dash separator: '  3 — it changes …'" \
  "kori_pat_hits '  3 — it changes auth, payment, or customer-data logic'"
assert "…and an asterisk bullet: '* 3 = it changes …'" \
  "kori_pat_hits '* 3 = it changes auth, payment, or customer-data logic'"
assert "…but NOT the new additive form: '  +3 — it changes …'" \
  "! kori_pat_hits '  +3 — it changes auth, payment, or customer-data logic'"
assert "…nor its bulleted spelling: '- +3 = it changes …'" \
  "! kori_pat_hits '- +3 = it changes auth, payment, or customer-data logic'"
assert "…nor a different score on the same line: '- 1 = it changes …'" \
  "! kori_pat_hits '- 1 = it changes auth, payment, or customer-data logic'"
assert "the .before fixture carries the real bulleted form (so check-release's fixture proof is of the real form, not a reconstruction)" \
  "grep -qF -- '- 3 = it changes auth, payment, or customer-data logic' '$ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.before'"
assert "the .after fixture carries the new form in BOTH spellings and neither fires" \
  "grep -qF -- '+3 — it changes auth' '$ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.after' \
   && grep -qF -- '- +3 = it changes auth' '$ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.after' \
   && ! grep -qE -- \"\$KORI_PAT\" '$ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.after'"
# the human/JSON output reports the REAL matched line (bullet included)
assert "scan on the real bulleted form reports the matched line verbatim, bullet and all" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/ckori-old.json\"))
it = next(i for i in d[\"items\"] if i.get(\"kind\") == \"content\" and i[\"path\"] == \".logic-loom/memory/amendments.md\")
assert any(m[\"text\"].startswith(\"- 3 = it changes auth\") for m in it[\"matches\"]), it[\"matches\"]
'"

# ═══════════════════════════════════════════════════════════════════════════
# SECTION D — convert
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "D. convert sdd-debug: dry-run, apply, idempotency"

snapshot() { find "$1" -type f ! -path '*/.git/*' | sort | xargs cksum 2>/dev/null; }

FD1="$TMP/fixtureD1"; cp -R "$FIX1" "$FD1"
SNAP_BEFORE="$(snapshot "$FD1")"
bash "$RM" convert sdd-debug --dry-run --root "$FD1" > "$TMP/d1.dry.out" 2>&1
D1_DRY_RC=$?
SNAP_AFTER_DRY="$(snapshot "$FD1")"
assert "dry-run exits 0" "[ $D1_DRY_RC -eq 0 ]"
assert "dry-run writes nothing (snapshot identical)" "[ \"\$SNAP_BEFORE\" = \"\$SNAP_AFTER_DRY\" ]"
assert "dry-run lists WRITE for the skill SKILL.md" \
  "grep -q 'WRITE .claude/skills/sdd-debug/SKILL.md' '$TMP/d1.dry.out'"
assert "dry-run lists WRITE for the converted command-as-skill" \
  "grep -q 'WRITE .claude/skills/debug/SKILL.md' '$TMP/d1.dry.out'"
assert "dry-run lists WRITE for the converted agent" \
  "grep -q 'WRITE .claude/agents/auto-debug-agent.md' '$TMP/d1.dry.out'"
assert "dry-run lists WRITE for the hook script under .claude/skills/" \
  "grep -q 'WRITE .claude/skills/sdd-debug/hooks/scripts/debug-capture.sh' '$TMP/d1.dry.out'"
assert "dry-run prints the 'Hooks (NOT wired)' section" \
  "grep -q 'Hooks (NOT wired)' '$TMP/d1.dry.out'"

bash "$RM" convert sdd-debug --apply --root "$FD1" > "$TMP/d1.apply.out" 2>&1
D1_APPLY_RC=$?
assert "apply exits 0" "[ $D1_APPLY_RC -eq 0 ]"
assert "apply wrote .claude/skills/sdd-debug/SKILL.md" "[ -f '$FD1/.claude/skills/sdd-debug/SKILL.md' ]"
assert "apply wrote .claude/skills/debug/SKILL.md" "[ -f '$FD1/.claude/skills/debug/SKILL.md' ]"
assert "apply wrote .claude/agents/auto-debug-agent.md" "[ -f '$FD1/.claude/agents/auto-debug-agent.md' ]"
assert "apply wrote the hook script" "[ -f '$FD1/.claude/skills/sdd-debug/hooks/scripts/debug-capture.sh' ]"
assert "the three markdown files carry the converted-from marker" \
  "grep -q 'converted-from: plugins/sdd-debug/' '$FD1/.claude/skills/sdd-debug/SKILL.md' \
   && grep -q 'converted-from: plugins/sdd-debug/' '$FD1/.claude/skills/debug/SKILL.md' \
   && grep -q 'converted-from: plugins/sdd-debug/' '$FD1/.claude/agents/auto-debug-agent.md'"
assert "the pinned agent model was rewritten to opus" \
  "grep -q '^model: opus\$' '$FD1/.claude/agents/auto-debug-agent.md'"
assert "the hook script is executable" "[ -x '$FD1/.claude/skills/sdd-debug/hooks/scripts/debug-capture.sh' ]"
assert "the hook script's paths were rewritten under .claude/skills/sdd-debug/" \
  "grep -q '.claude/skills/sdd-debug/lib/x.sh' '$FD1/.claude/skills/sdd-debug/hooks/scripts/debug-capture.sh' \
   && grep -q '.claude/skills/sdd-debug/config/y.json' '$FD1/.claude/skills/sdd-debug/hooks/scripts/debug-capture.sh'"
assert "no CLAUDE_PLUGIN_ROOT survives in the converted hook script" \
  "! grep -q 'CLAUDE_PLUGIN_ROOT' '$FD1/.claude/skills/sdd-debug/hooks/scripts/debug-capture.sh'"
CONV_MD="$FD1/.claude/skills/sdd-debug/CONVERTED.md"
assert "CONVERTED.md exists and lists EVERY written path (target <- source)" \
  "[ -f '$CONV_MD' ] \
   && grep -qF '.claude/skills/sdd-debug/SKILL.md <- plugins/sdd-debug/skills/sdd-debug/SKILL.md' '$CONV_MD' \
   && grep -qF '.claude/skills/debug/SKILL.md <- plugins/sdd-debug/commands/debug.md' '$CONV_MD' \
   && grep -qF '.claude/agents/auto-debug-agent.md <- plugins/sdd-debug/agents/auto-debug-agent.md' '$CONV_MD' \
   && grep -qF '.claude/skills/sdd-debug/hooks/scripts/debug-capture.sh <- plugins/sdd-debug/hooks/scripts/debug-capture.sh' '$CONV_MD'"
assert "CONVERTED.md carries the settings snippet (Hooks NOT wired) pointing at the converted hook script" \
  "grep -q 'Hooks (NOT wired)' '$CONV_MD' \
   && grep -qF '\"command\":\"bash .claude/skills/sdd-debug/hooks/scripts/debug-capture.sh\"' '$CONV_MD'"
assert "CONVERTED.md carries the dangling line (.claude/settings.json still wires plugins/sdd-debug/...)" \
  "grep -q 'dangle' '$CONV_MD' \
   && grep -qF '.claude/settings.json:' '$CONV_MD' \
   && grep -qF 'plugins/sdd-debug/hooks/scripts/debug-capture.sh' '$CONV_MD'"
assert ".claude/settings.json is byte-identical to before the convert" \
  "cksum '$FD1/.claude/settings.json' | awk '{print \$1,\$2}' > '$TMP/d1.settings.after'; \
   cksum '$FIX1/.claude/settings.json' | awk '{print \$1,\$2}' > '$TMP/d1.settings.before'; \
   diff -q '$TMP/d1.settings.before' '$TMP/d1.settings.after' >/dev/null"
assert "plugins/sdd-debug is byte-identical to before the convert" \
  "diff -rq '$FIX1/plugins/sdd-debug' '$FD1/plugins/sdd-debug' >/dev/null"
assert "migration-decisions.conf contains 'converted = sdd-debug' exactly once" \
  "[ \"\$(grep -c '^converted = sdd-debug\$' '$FD1/.logic-loom/config/migration-decisions.conf')\" -eq 1 ]"

SNAP_AFTER_APPLY="$(snapshot "$FD1")"
bash "$RM" convert sdd-debug --apply --root "$FD1" > "$TMP/d1.apply2.out" 2>&1
D1_APPLY2_RC=$?
SNAP_AFTER_APPLY2="$(snapshot "$FD1")"
assert "second --apply exits 0" "[ $D1_APPLY2_RC -eq 0 ]"
assert "second --apply writes nothing new (snapshot identical)" "[ \"\$SNAP_AFTER_APPLY\" = \"\$SNAP_AFTER_APPLY2\" ]"
assert "second --apply reports SKIP for every unit (no WRITE/WROTE)" \
  "! grep -qE '^(WRITE|WROTE) ' '$TMP/d1.apply2.out'"

bash "$RM" scan --json --root "$FD1" > "$TMP/d1.postscan.json" 2>&1
assert "after conversion, scan shows sdd-debug's decision as converted" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/d1.postscan.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-debug\")
assert it[\"decision\"] == \"converted\", it
'"

echo ""
echo "D. finding 1 (round 5 review): convert_hooks_and_support enumerates EVERY plugin-root file/dir generically, not a fixed list"
FD_GEN="$TMP/fixtureD-generic-enum"; cp -R "$FIX1" "$FD_GEN"
# A plugin-root file AND directory that were never on the old FIXED list
# (hooks/scripts/lib/config/templates/tests/README.md) — exactly the shape
# of the real repo's plugins/loom-governance/domain-briefs/ and a top-level
# LICENSE. Before finding 1's fix, convert_hooks_and_support never even
# looked at these — they were silently left off both disk AND the record.
echo "MIT" > "$FD_GEN/plugins/sdd-debug/LICENSE"
mkdir -p "$FD_GEN/plugins/sdd-debug/domain-data"
echo "extra shipped content" > "$FD_GEN/plugins/sdd-debug/domain-data/notes.txt"
bash "$RM" convert sdd-debug --apply --root "$FD_GEN" > "$TMP/dgen.apply.out" 2>&1
DGEN_RC=$?
assert "convert --apply exits 0 when everything, including the unlisted LICENSE/domain-data/, converts cleanly" \
  "[ $DGEN_RC -eq 0 ]"
assert "the top-level LICENSE file (never on the old fixed list) was converted" \
  "[ -f '$FD_GEN/.claude/skills/sdd-debug/LICENSE' ] && grep -qF 'MIT' '$FD_GEN/.claude/skills/sdd-debug/LICENSE'"
assert "the top-level domain-data/ directory (never on the old fixed list) was converted, recursively" \
  "[ -f '$FD_GEN/.claude/skills/sdd-debug/domain-data/notes.txt' ] && grep -qF 'extra shipped content' '$FD_GEN/.claude/skills/sdd-debug/domain-data/notes.txt'"
assert "CONVERTED.md's mapping ledger lists both previously-unreachable paths" \
  "grep -qF '.claude/skills/sdd-debug/LICENSE <- plugins/sdd-debug/LICENSE' '$FD_GEN/.claude/skills/sdd-debug/CONVERTED.md' \
   && grep -qF '.claude/skills/sdd-debug/domain-data/notes.txt <- plugins/sdd-debug/domain-data/notes.txt' '$FD_GEN/.claude/skills/sdd-debug/CONVERTED.md'"
assert "finding 2 positive control: once everything really is accounted for, the delete recommendation IS printed" \
  "grep -qF 'Next steps: delete plugins/sdd-debug' '$TMP/dgen.apply.out'"

echo ""
echo "D. finding 2 (round 5 review): an unconverted file (a STOP) withholds the delete recommendation and names what was not carried over"
FD_STOP="$TMP/fixtureD-withhold-delete"; cp -R "$FIX1" "$FD_STOP"
mkdir -p "$FD_STOP/.claude/skills/sdd-debug"
echo "someone else's file, no converted-from marker" > "$FD_STOP/.claude/skills/sdd-debug/README.md"
echo "shipped readme" > "$FD_STOP/plugins/sdd-debug/README.md"
bash "$RM" convert sdd-debug --apply --root "$FD_STOP" > "$TMP/dstop.apply.out" 2>&1
DSTOP_RC=$?
assert "one unmapped file (a pre-existing markerless README.md) makes convert --apply exit non-zero (STOPped)" \
  "[ $DSTOP_RC -ne 0 ] && grep -qF 'STOP README.md' '$TMP/dstop.apply.out'"
assert "…and the delete recommendation is WITHHELD, never printed unconditionally" \
  "! grep -qF 'Next steps: delete plugins/sdd-debug' '$TMP/dstop.apply.out' \
   && grep -qF 'Next steps: DO NOT delete plugins/sdd-debug yet.' '$TMP/dstop.apply.out'"
cat "$TMP/dstop.apply.out" > /tmp/DEBUG-dstop-apply.out 2>/dev/null || true
assert "…naming the exact file that was not carried over" \
  "grep -qF 'plugins/sdd-debug/README.md' '$TMP/dstop.apply.out'"
assert "…and CONVERTED.md's own Follow-ups section says the same, never 'delete plugins/sdd-debug once'" \
  "[ -f '$FD_STOP/.claude/skills/sdd-debug/CONVERTED.md' ] \
   && ! grep -qF 'delete plugins/sdd-debug once' '$FD_STOP/.claude/skills/sdd-debug/CONVERTED.md' \
   && grep -qF 'DO NOT delete plugins/sdd-debug yet' '$FD_STOP/.claude/skills/sdd-debug/CONVERTED.md'"

echo ""
echo "D. round-2 finding 2: decision=converted must NOT force REMOVE regardless of state"
# A plugin converted and COMMITTED (both CONVERTED.md and the 'converted =' line
# land in a real commit) stays REMOVE as long as it is untouched since — but
# once it is edited AFTER that committed decision, the recommendation must
# flip to KEEP-AS-IS (never silently discard a customer's post-conversion
# edit). A third fixture proves the "decision recorded but never committed"
# case is ALSO never a REMOVE (Governing principle: doubt -> KEEP and ASK).
FIX_CONV2="$TMP/fixture-converted-edited"
mkdir -p "$FIX_CONV2/.logic-loom/config" "$FIX_CONV2/.logic-loom/lib" "$FIX_CONV2/plugins/sdd-conv2/skills/sdd-conv2"
git init -q "$FIX_CONV2"
cp "$LIB" "$FIX_CONV2/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=7.0.0" > "$FIX_CONV2/.logic-loom/config/architecture.conf"
echo "plugin | sdd-conv2 | native | native:/workflow | REMOVE | v4.0.0 | v6.2.0 | round-2 finding 2 fixture" \
  > "$FIX_CONV2/.logic-loom/config/release-migrations.conf"
cat > "$FIX_CONV2/plugins/sdd-conv2/skills/sdd-conv2/SKILL.md" <<'MD'
---
name: sdd-conv2
description: round-2 finding 2 fixture
---

Body.
MD
( cd "$FIX_CONV2" && git add -A >/dev/null && git commit -q -m "plugin present" )
bash "$RM" convert sdd-conv2 --apply --root "$FIX_CONV2" >/dev/null 2>&1
( cd "$FIX_CONV2" && git add -A >/dev/null && git commit -q -m "convert sdd-conv2" )
bash "$RM" scan --json --root "$FIX_CONV2" > "$TMP/conv2-clean.json" 2>&1
assert "decision=converted, plugin UNCHANGED since the (committed) conversion decision -> REMOVE, as before" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/conv2-clean.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-conv2\")
assert it[\"decision\"] == \"converted\", it
assert it[\"recommended\"] == \"REMOVE\", it
'"
echo "-- edited after conversion --" >> "$FIX_CONV2/plugins/sdd-conv2/skills/sdd-conv2/SKILL.md"
bash "$RM" scan --json --root "$FIX_CONV2" > "$TMP/conv2-edited.json" 2>&1
assert "…but once plugins/sdd-conv2 is edited AFTER that committed decision: KEEP-AS-IS, reason names 'edited after conversion', never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/conv2-edited.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-conv2\")
assert it[\"decision\"] == \"converted\", it
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert \"edited after conversion\" in it[\"reason\"], it
'"
# An UNTRACKED file the customer dropped into plugins/sdd-conv2 after the
# committed decision is their bytes too — no commit vouches for it, and a
# REMOVE plan line on the directory recommends deleting it. A tracked-only
# diff (`git diff <decision-commit> -- plugins/sdd-conv2`) is blind to it and
# would say "unchanged" -> REMOVE. Restore the tracked edit first so the ONLY
# change is the untracked file.
( cd "$FIX_CONV2" && git checkout -q -- plugins/sdd-conv2/skills/sdd-conv2/SKILL.md )
echo "customer notes, never git-added" > "$FIX_CONV2/plugins/sdd-conv2/customer-notes.md"
bash "$RM" scan --json --root "$FIX_CONV2" > "$TMP/conv2-untracked.json" 2>&1
assert "…and an UNTRACKED file added under plugins/sdd-conv2 after the committed decision (tracked files byte-identical to it): KEEP-AS-IS, reason names 'edited after conversion', never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/conv2-untracked.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-conv2\")
assert it[\"decision\"] == \"converted\", it
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert \"edited after conversion\" in it[\"reason\"], it
assert it[\"remove_command\"] == \"\", it
'"
rm -f "$FIX_CONV2/plugins/sdd-conv2/customer-notes.md"
bash "$RM" scan --json --root "$FIX_CONV2" > "$TMP/conv2-restored.json" 2>&1
assert "…and with the untracked file gone and the tracked edit reverted, the same plugin is back to REMOVE (the untracked check is what flipped it, nothing else)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/conv2-restored.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-conv2\")
assert it[\"recommended\"] == \"REMOVE\", it
'"

FIX_CONV3="$TMP/fixture-converted-uncommitted"
mkdir -p "$FIX_CONV3/.logic-loom/config" "$FIX_CONV3/.logic-loom/lib" "$FIX_CONV3/plugins/sdd-conv3/skills/sdd-conv3"
git init -q "$FIX_CONV3"
cp "$LIB" "$FIX_CONV3/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=7.0.0" > "$FIX_CONV3/.logic-loom/config/architecture.conf"
echo "plugin | sdd-conv3 | native | native:/workflow | REMOVE | v4.0.0 | v6.2.0 | round-2 finding 2 fixture (uncommitted decision)" \
  > "$FIX_CONV3/.logic-loom/config/release-migrations.conf"
cat > "$FIX_CONV3/plugins/sdd-conv3/skills/sdd-conv3/SKILL.md" <<'MD'
---
name: sdd-conv3
description: round-2 finding 2 fixture
---

Body.
MD
( cd "$FIX_CONV3" && git add -A >/dev/null && git commit -q -m "plugin present" )
bash "$RM" convert sdd-conv3 --apply --root "$FIX_CONV3" >/dev/null 2>&1
# Deliberately NOT committed: CONVERTED.md and 'converted =' both sit only
# in the working tree, exactly like FD1 above.
bash "$RM" scan --json --root "$FIX_CONV3" > "$TMP/conv3.json" 2>&1
assert "decision=converted but the decision has no committed record at all (CONVERTED.md/migration-decisions.conf uncommitted): KEEP-AS-IS, reason names 'no committed record', never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/conv3.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-conv3\")
assert it[\"decision\"] == \"converted\", it
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert \"no committed record\" in it[\"reason\"], it
'"

# The decision-line route must date the decision to the commit that added
# THAT plugin's line, matched as a whole line — `git log -S"converted = foo"`
# is a substring count and also fires on "converted = foobar", so a
# same-prefix plugin converted EARLIER would date foo's decision to the
# wrong, older commit and diff the plugin against the wrong tree. Here:
# sdd-conv4-more is converted and committed first (C1), plugins/sdd-conv4 is
# then edited and committed (a PRE-conversion edit), and only then is
# sdd-conv4 converted, with just the decisions line committed (C2) and its
# CONVERTED.md left uncommitted so the decision-line route is the one in
# play. plugins/sdd-conv4 is untouched since C2, so the honest answer is
# REMOVE; dating the decision to C1 instead would see the pre-conversion
# edit and flip it to KEEP for a reason that is simply false.
FIX_CONV4="$TMP/fixture-converted-prefix-collision"
mkdir -p "$FIX_CONV4/.logic-loom/config" "$FIX_CONV4/.logic-loom/lib" \
  "$FIX_CONV4/plugins/sdd-conv4/skills/sdd-conv4" "$FIX_CONV4/plugins/sdd-conv4-more/skills/sdd-conv4-more"
git init -q "$FIX_CONV4"
cp "$LIB" "$FIX_CONV4/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=7.0.0" > "$FIX_CONV4/.logic-loom/config/architecture.conf"
{
  echo "plugin | sdd-conv4 | native | native:/workflow | REMOVE | v4.0.0 | v6.2.0 | prefix-collision fixture"
  echo "plugin | sdd-conv4-more | native | native:/workflow | REMOVE | v4.0.0 | v6.2.0 | prefix-collision fixture (the longer name)"
} > "$FIX_CONV4/.logic-loom/config/release-migrations.conf"
for cp4 in sdd-conv4 sdd-conv4-more; do
  cat > "$FIX_CONV4/plugins/$cp4/skills/$cp4/SKILL.md" <<MD
---
name: $cp4
description: prefix-collision fixture
---

Body.
MD
done
( cd "$FIX_CONV4" && git add -A >/dev/null && git commit -q -m "C0: both plugins present" )
bash "$RM" convert sdd-conv4-more --apply --root "$FIX_CONV4" >/dev/null 2>&1
( cd "$FIX_CONV4" && git add -A >/dev/null && git commit -q -m "C1: convert sdd-conv4-more (decision line: converted = sdd-conv4-more)" )
echo "-- edited BEFORE sdd-conv4 was converted --" >> "$FIX_CONV4/plugins/sdd-conv4/skills/sdd-conv4/SKILL.md"
( cd "$FIX_CONV4" && git add -A >/dev/null && git commit -q -m "C1.5: pre-conversion edit to plugins/sdd-conv4" )
bash "$RM" convert sdd-conv4 --apply --root "$FIX_CONV4" >/dev/null 2>&1
( cd "$FIX_CONV4" && git add .logic-loom/config/migration-decisions.conf >/dev/null && git commit -q -m "C2: decision line only (converted = sdd-conv4); CONVERTED.md left uncommitted" )
assert "prefix-collision fixture sanity: sdd-conv4's CONVERTED.md is uncommitted (decision-line route in play), and the decisions file holds both whole lines" \
  "[ -z \"\$(git -C '$FIX_CONV4' log --format=%H -- .claude/skills/sdd-conv4/CONVERTED.md)\" ] && grep -qxF 'converted = sdd-conv4' '$FIX_CONV4/.logic-loom/config/migration-decisions.conf' && grep -qxF 'converted = sdd-conv4-more' '$FIX_CONV4/.logic-loom/config/migration-decisions.conf'"
bash "$RM" scan --json --root "$FIX_CONV4" > "$TMP/conv4.json" 2>&1
assert "decision-line route, same-prefix plugin converted earlier: sdd-conv4's decision is dated to ITS OWN line's commit (whole-line match), the plugin is unchanged since -> REMOVE, not a false 'edited after conversion' from a substring match on 'converted = sdd-conv4-more'" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/conv4.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-conv4\")
assert it[\"decision\"] == \"converted\", it
assert it[\"recommended\"] == \"REMOVE\", it
more = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-conv4-more\")
assert more[\"decision\"] == \"converted\" and more[\"recommended\"] == \"REMOVE\", more
'"

echo ""
echo "D. round-3 finding 3 + finding 4: converted-plugin briefing consistency + gitignored files count as edits"
FIX_CONV5="$TMP/fixture-converted-ignored"
mkdir -p "$FIX_CONV5/.logic-loom/config" "$FIX_CONV5/.logic-loom/lib" "$FIX_CONV5/plugins/sdd-conv5/skills/sdd-conv5"
git init -q "$FIX_CONV5"
cp "$LIB" "$FIX_CONV5/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=7.0.0" > "$FIX_CONV5/.logic-loom/config/architecture.conf"
echo "plugin | sdd-conv5 | native | native:/workflow | REMOVE | v4.0.0 | v6.2.0 | round-3 finding 3/4 fixture" \
  > "$FIX_CONV5/.logic-loom/config/release-migrations.conf"
cat > "$FIX_CONV5/plugins/sdd-conv5/skills/sdd-conv5/SKILL.md" <<'MD'
---
name: sdd-conv5
description: round-3 finding 3/4 fixture
---

Body.
MD
echo "*.local" > "$FIX_CONV5/.gitignore"
( cd "$FIX_CONV5" && git add -A >/dev/null && git commit -q -m "plugin present" )
bash "$RM" convert sdd-conv5 --apply --root "$FIX_CONV5" >/dev/null 2>&1
( cd "$FIX_CONV5" && git add -A >/dev/null && git commit -q -m "convert sdd-conv5" )

bash "$RM" scan --json --root "$FIX_CONV5" > "$TMP/conv5-clean.json" 2>&1
assert "finding 3 baseline: unchanged converted plugin -> REMOVE, and the decisions briefing's consequence agrees ('delete it')" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/conv5-clean.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-conv5\")
assert it[\"recommended\"] == \"REMOVE\", it
dec = next(x for x in d[\"decisions\"] if x[\"name\"] == \"sdd-conv5\")
assert \"delete it\" in dec[\"consequence\"], dec
assert dec[\"stale\"] == False, dec
'"

# A GITIGNORED file added under plugins/sdd-conv5 after the committed
# conversion decision — invisible to a plain `ls-files --others
# --exclude-standard` (finding 4), but it is still a customer's bytes no
# commit vouches for.
echo "customer local state" > "$FIX_CONV5/plugins/sdd-conv5/scratch.local"
assert "sanity: scratch.local is untracked AND git-ignored ('git status --ignored' shows it as '!!')" \
  "git -C '$FIX_CONV5' status --porcelain=v1 --ignored -- plugins/sdd-conv5 | grep -qxF '!! plugins/sdd-conv5/scratch.local'"

bash "$RM" scan --json --root "$FIX_CONV5" > "$TMP/conv5-ignored.json" 2>&1
assert "finding 4: a GITIGNORED file added under plugins/sdd-conv5 flips the recommendation to KEEP-AS-IS (never REMOVE)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/conv5-ignored.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-conv5\")
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert it[\"remove_command\"] == \"\", it
'"
assert "finding 3: …and the decisions briefing stays in sync — it no longer says 'delete it', it says KEEP-AS-IS" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/conv5-ignored.json\"))
dec = next(x for x in d[\"decisions\"] if x[\"name\"] == \"sdd-conv5\")
assert \"delete it\" not in dec[\"consequence\"], dec
assert \"KEEP-AS-IS\" in dec[\"consequence\"], dec
'"
rm -f "$FIX_CONV5/plugins/sdd-conv5/scratch.local"

# ─────────────────────────────────────────────────────────────────────────
# Round-4 adversarial review. Three more routes to "REMOVE recommended over
# a customer's bytes", each reproduced against the round-3 tree before the
# fix and closed by it. Shared fixture builder: a plugin row with a genuine
# sync-ref baseline (refs/loom-upstream/main reaches the sync-ref commit).
# ─────────────────────────────────────────────────────────────────────────
mk_r4_fixture() {  # $1 = dir
  local d="$1"
  mkdir -p "$d/.logic-loom/config" "$d/.logic-loom/lib" "$d/plugins/sdd-r4/skills/sdd-r4" "$d/plugins/sdd-r4/commands"
  echo "FRAMEWORK_VERSION=7.0.0" > "$d/.logic-loom/config/architecture.conf"
  cp "$LIB" "$d/.logic-loom/lib/release-migrations.sh"
  echo "plugin | sdd-r4 | native | native:/workflow | REMOVE | v4.0.0 | v6.2.0 | round-4 fixture" \
    > "$d/.logic-loom/config/release-migrations.conf"
  printf -- '---\nname: sdd-r4\ndescription: round-4 fixture\n---\n\nBody.\n' > "$d/plugins/sdd-r4/skills/sdd-r4/SKILL.md"
  printf -- '---\ndescription: r4 cmd\n---\n\nDo the thing.\n' > "$d/plugins/sdd-r4/commands/r4.md"
  echo "*.local" > "$d/.gitignore"
  git init -q "$d"
  ( cd "$d" && git add -A >/dev/null && git commit -q -m "A" )
  printf '%s\n' "$(git -C "$d" rev-parse HEAD)" > "$d/.sdd-sync-ref"
  ( cd "$d" && git add -A >/dev/null && git commit -q -m "stamp sync-ref" )
  git -C "$d" update-ref refs/loom-upstream/main "$(git -C "$d" rev-parse HEAD)"
}

echo ""
echo "D. round-4: finding 4's OTHER half — resolve_state() (every non-converted row) also ignored gitignored files"
R4A="$TMP/r4-ignored-not-converted"
mk_r4_fixture "$R4A"
bash "$RM" scan --json --root "$R4A" > "$TMP/r4a-clean.json" 2>&1
assert "control: pristine plugins/sdd-r4 against its sync-ref baseline -> REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/r4a-clean.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-r4\")
assert it[\"baseline\"].startswith(\"sync-ref:\"), it
assert it[\"state\"] == \"pristine\" and it[\"recommended\"] == \"REMOVE\", it
'"
echo "customer local state" > "$R4A/plugins/sdd-r4/scratch.local"
assert "sanity: scratch.local is untracked AND git-ignored" \
  "git -C '$R4A' status --porcelain=v1 --ignored -- plugins/sdd-r4 | grep -qxF '!! plugins/sdd-r4/scratch.local'"
bash "$RM" scan --json --root "$R4A" > "$TMP/r4a-ignored.json" 2>&1
assert "a GITIGNORED file under a NOT-converted plugins/sdd-r4 (sync-ref baseline): state customized, never REMOVE, no remove_command, and the file is listed under added" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/r4a-ignored.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-r4\")
assert it[\"state\"] == \"customized\", it
assert it[\"recommended\"] != \"REMOVE\", it
assert it[\"remove_command\"] == \"\", it
assert \"plugins/sdd-r4/scratch.local\" in it[\"added_files\"], it
'"

echo ""
echo "D. round-4: converted plugin whose source was edited AFTER convert --apply but committed WITH the decision"
# The ordinary flow: /update-framework runs convert --apply, the user commits
# later at /git-push. An edit to the plugin in between lands in the SAME
# commit as CONVERTED.md, so \"unchanged since the decision commit\" is true
# and the edit — never carried into .claude/ — was recommended for git rm -r.
# The converter's own re-run classification (convert --dry-run: SKIP vs
# KEEP/WRITE/STOP) is what proves the on-disk conversion reflects the source.
R4B="$TMP/r4-edit-before-commit"
mk_r4_fixture "$R4B"
bash "$RM" convert sdd-r4 --apply --root "$R4B" >/dev/null 2>&1
echo "-- customer edit AFTER convert --apply, BEFORE the decision commit --" >> "$R4B/plugins/sdd-r4/skills/sdd-r4/SKILL.md"
( cd "$R4B" && git add -A >/dev/null && git commit -q -m "conversion + a later edit, committed together" )
assert "sanity: the working tree is byte-identical to the decision commit (the old gate saw nothing)" \
  "git -C '$R4B' diff --quiet HEAD -- plugins/sdd-r4 && [ -z \"\$(git -C '$R4B' ls-files --others --exclude-standard -- plugins/sdd-r4)\" ]"
bash "$RM" convert sdd-r4 --dry-run --root "$R4B" > "$TMP/r4b-dryrun.out" 2>&1 || true
assert "sanity: convert --dry-run re-render reports the drift (a KEEP line), so the evidence exists" \
  "grep -q '^KEEP .claude/skills/sdd-r4/SKILL.md modified-after-conversion' '$TMP/r4b-dryrun.out'"
bash "$RM" scan --json --root "$R4B" > "$TMP/r4b.json" 2>&1
assert "the un-converted edit is caught: KEEP-AS-IS, reason names the stale re-render and the decision commit, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/r4b.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-r4\")
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert it[\"remove_command\"] == \"\", it
assert \"re-render\" in it[\"reason\"] and \"decision commit\" in it[\"reason\"], it
'"
assert "…and the decisions briefing says the same (KEEP-AS-IS, never 'delete it') — one shared status, two surfaces" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/r4b.json\"))
dec = next(x for x in d[\"decisions\"] if x[\"name\"] == \"sdd-r4\")
assert \"KEEP-AS-IS\" in dec[\"consequence\"], dec
assert \"delete it\" not in dec[\"consequence\"], dec
assert dec[\"stale\"] == False, dec
'"
# Control: a clean, unedited conversion still re-renders all-SKIP -> REMOVE.
R4C="$TMP/r4-clean-conversion"
mk_r4_fixture "$R4C"
bash "$RM" convert sdd-r4 --apply --root "$R4C" >/dev/null 2>&1
( cd "$R4C" && git add -A >/dev/null && git commit -q -m "clean conversion" )
bash "$RM" scan --json --root "$R4C" > "$TMP/r4c.json" 2>&1
assert "control: a clean, unedited conversion still re-renders all-SKIP -> REMOVE (the gate is not a blanket KEEP)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/r4c.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-r4\")
assert it[\"recommended\"] == \"REMOVE\", it
dec = next(x for x in d[\"decisions\"] if x[\"name\"] == \"sdd-r4\")
assert \"delete it\" in dec[\"consequence\"], dec
'"
# The re-render runs cmd_convert in a command-substitution subshell; the
# parent's EXIT trap must not fire there. mk_r4_fixture commits the registry
# and points refs/loom-upstream/main at it, so every r4 scan serves the
# registry from a mktemp copy the trap removes — a converted row's nested
# dry-run must not delete the parent's copy out from under the decisions
# briefing, which re-reads the registry file after every item is scanned.
assert "…with the registry served from refs/loom-upstream/main (a temp copy): the converted row's nested dry-run does not remove the parent's temp registry — the briefing still resolves the row (stale=false) after the item" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/r4c.json\"))
assert d[\"registry\"] == \"upstream\", d[\"registry\"]
dec = next(x for x in d[\"decisions\"] if x[\"name\"] == \"sdd-r4\")
assert dec[\"stale\"] == False, dec
'"

echo ""
echo "D. round-4: finding 5 at EVERY use — a traversing name in an unlinted project registry never reaches scan/plan/convert"
R4D="$TMP/r4-project-traversal"
mk_r4_fixture "$R4D"
mkdir -p "$R4D/victim/skills/evil"
echo "customer bytes" > "$R4D/victim/keep.txt"
printf -- '---\nname: evil\n---\nx\n' > "$R4D/victim/skills/evil/SKILL.md"
( cd "$R4D" && git add -A >/dev/null && git commit -q -m "victim" )
git -C "$R4D" update-ref refs/loom-upstream/main "$(git -C "$R4D" rev-parse HEAD)"
echo "path | plugins/../victim | removed | none | REMOVE | v1.0.0 | v7.0.0 | traversal via project registry" \
  > "$R4D/.logic-loom/config/project-migrations.conf"
bash "$RM" scan --root "$R4D" > "$TMP/r4d-scan.out" 2>&1
assert "scan never lists an item for the traversing path row — no 'plugins/../victim' item, no git rm on it" \
  "! grep -q 'plugins/\.\./victim' '$TMP/r4d-scan.out'"
# scan reads registry rows with stderr silenced (every malformed row is
# dropped the same way, by design); `lint` is the surface that names it, and
# cmd_lint lints project-migrations.conf too.
assert "…and \`lint\` names the project-registry row as malformed with the finding-5 message (it is a parse error now, not only a lint rule)" \
  "! bash '$RM' lint --root '$R4D' >'$TMP/r4d-lint.out' 2>&1; grep -q \"must not be absolute or contain a '..'/'.' path segment\" '$TMP/r4d-lint.out'"
echo "plugin | ../victim | native | native:/x | REMOVE | v1.0.0 | v7.0.0 | traversal" \
  > "$R4D/.logic-loom/config/project-migrations.conf"
bash "$RM" convert ../victim --apply --root "$R4D" > "$TMP/r4d-conv.out" 2>&1
assert "convert refuses the traversing plugin name (no such row parses) and writes nothing: no .claude/victim/CONVERTED.md, no .claude/skills/evil/" \
  "grep -q 'no plugin-kind registry row' '$TMP/r4d-conv.out' && [ ! -e '$R4D/.claude/victim/CONVERTED.md' ] && [ ! -e '$R4D/.claude/skills/evil/SKILL.md' ]"

echo ""
echo "D. finding 4: convert preserves the executable bit on a rewritten skill file"
FD_EXE="$TMP/fixtureD-exe"
mkdir -p "$FD_EXE/.logic-loom/config" "$FD_EXE/.logic-loom/lib" "$FD_EXE/plugins/sdd-exe/skills/sdd-exe" "$FD_EXE/.claude"
cp "$REG" "$FD_EXE/.logic-loom/config/release-migrations.conf"
cp "$LIB" "$FD_EXE/.logic-loom/lib/release-migrations.sh"
cat >> "$FD_EXE/.logic-loom/config/release-migrations.conf" <<'EOF'
plugin | sdd-exe | removed | none | REMOVE | v4.0.0 | v6.2.0 | test fixture for the +x preservation defect
EOF
echo "FRAMEWORK_VERSION=6.6.2" > "$FD_EXE/.logic-loom/config/architecture.conf"
cat > "$FD_EXE/plugins/sdd-exe/skills/sdd-exe/SKILL.md" <<'MD'
---
name: sdd-exe
description: fixture for the write_text_target +x defect
---
Body.
MD
cat > "$FD_EXE/plugins/sdd-exe/skills/sdd-exe/run.sh" <<'SH'
#!/usr/bin/env bash
echo hi
SH
chmod +x "$FD_EXE/plugins/sdd-exe/skills/sdd-exe/run.sh"
bash "$RM" convert sdd-exe --apply --root "$FD_EXE" > "$TMP/dexe.apply.out" 2>&1
assert "convert --apply exits 0" "[ $? -eq 0 ]"
assert "the converted run.sh under .claude/skills/ is still executable (the source's +x bit survived the rewrite)" \
  "[ -x '$FD_EXE/.claude/skills/sdd-exe/run.sh' ]"
assert "…and its content still went through the (no-op) path-rewrite pass — not a plain byte copy" \
  "grep -q 'echo hi' '$FD_EXE/.claude/skills/sdd-exe/run.sh'"

echo ""
echo "D. convert sdd-dev-loop: the append path (command into an existing same-named skill)"

FD2="$TMP/fixtureD2"; cp -R "$FIX1" "$FD2"
SNAP2_BEFORE="$(snapshot "$FD2")"
bash "$RM" convert sdd-dev-loop --dry-run --root "$FD2" > "$TMP/d2.dry.out" 2>&1
assert "dry-run prints an APPEND line naming the section source" \
  "grep -q 'APPEND .claude/skills/dev-loop/SKILL.md' '$TMP/d2.dry.out'"
assert "dry-run notes the command frontmatter is kept in section, not merged" \
  "grep -q 'frontmatter: kept in section, not merged' '$TMP/d2.dry.out'"
assert "dry-run prints a NOTE that command frontmatter differs" \
  "grep -q 'NOTE .claude/skills/dev-loop/SKILL.md: command frontmatter differs' '$TMP/d2.dry.out'"
SNAP2_DRY="$(snapshot "$FD2")"
assert "dry-run writes nothing" "[ \"\$SNAP2_DRY\" = \"\$SNAP2_BEFORE\" ]"

bash "$RM" convert sdd-dev-loop --apply --root "$FD2" > "$TMP/d2.apply.out" 2>&1
assert "apply exits 0" "[ $? -eq 0 ]"
assert "the appended section carries start/end markers" \
  "grep -qF '<!-- converted-from: plugins/sdd-dev-loop/commands/dev-loop.md | logicloom-plugin-deprecations v1 | appended section -->' '$FD2/.claude/skills/dev-loop/SKILL.md' \
   && grep -qF '<!-- end converted-from: plugins/sdd-dev-loop/commands/dev-loop.md -->' '$FD2/.claude/skills/dev-loop/SKILL.md'"
assert "the appended section carries the 'Command procedure' heading" \
  "grep -q '## Command procedure (converted from commands/dev-loop.md)' '$FD2/.claude/skills/dev-loop/SKILL.md'"
assert "the appended section carries a yaml fence with the command frontmatter" \
  "grep -q '\`\`\`yaml' '$FD2/.claude/skills/dev-loop/SKILL.md' && grep -q 'allowed-tools: Bash' '$FD2/.claude/skills/dev-loop/SKILL.md'"
assert "CONVERTED.md lists it as an appended section" \
  "grep -q '(appended section)' '$FD2/.claude/skills/sdd-dev-loop/CONVERTED.md'"

bash "$RM" convert sdd-dev-loop --apply --root "$FD2" > "$TMP/d2.apply2.out" 2>&1
D2_APPLY2_RC=$?
assert "second apply reports SKIP up-to-date for the appended skill" \
  "grep -q 'SKIP .claude/skills/dev-loop/SKILL.md up-to-date' '$TMP/d2.apply2.out'"
assert "second apply exits 0" "[ $D2_APPLY2_RC -eq 0 ]"
SNAP2_AFTER_APPLY="$(snapshot "$FD2")"
bash "$RM" convert sdd-dev-loop --apply --root "$FD2" > "$TMP/d2.apply2b.out" 2>&1
SNAP2_AFTER_APPLY2="$(snapshot "$FD2")"
assert "second apply writes nothing new" "[ \"\$SNAP2_AFTER_APPLY\" = \"\$SNAP2_AFTER_APPLY2\" ]"

python3 -c "
import re
p = '$FD2/.claude/skills/dev-loop/SKILL.md'
s = open(p).read()
s = s.replace('## Command procedure (converted from commands/dev-loop.md)',
              'EDITED BY USER\n## Command procedure (converted from commands/dev-loop.md)')
open(p, 'w').write(s)
"
bash "$RM" convert sdd-dev-loop --apply --root "$FD2" > "$TMP/d2.apply3.out" 2>&1
assert "a line inserted between the markers -> third apply prints KEEP modified-after-conversion" \
  "grep -q 'KEEP .claude/skills/dev-loop/SKILL.md modified-after-conversion' '$TMP/d2.apply3.out'"
assert "the modified file is left unchanged by that apply" \
  "grep -q 'EDITED BY USER' '$FD2/.claude/skills/dev-loop/SKILL.md'"

echo ""
echo "D. Collision: a pre-existing markerless agent file stops that unit only"

FD3="$TMP/fixtureD3"; cp -R "$FIX1" "$FD3"
mkdir -p "$FD3/.claude/agents"
echo "pre-existing, not ours" > "$FD3/.claude/agents/auto-debug-agent.md"
bash "$RM" convert sdd-debug --apply --root "$FD3" > "$TMP/d3.apply.out" 2>&1
D3_RC=$?
assert "convert exits 2 on a collision" "[ $D3_RC -eq 2 ]"
assert "the pre-existing file is left untouched" \
  "[ \"\$(cat '$FD3/.claude/agents/auto-debug-agent.md')\" = 'pre-existing, not ours' ]"
assert "the skill units were still written despite the agent collision" \
  "[ -f '$FD3/.claude/skills/sdd-debug/SKILL.md' ] && [ -f '$FD3/.claude/skills/debug/SKILL.md' ]"

echo ""
echo "D. ADOPT-REPLACEMENT: convert sdd-git --customized-only stops at the counterpart"

FD4="$TMP/fixtureD4"; cp -R "$FIX1" "$FD4"
SNAP4_BEFORE="$(snapshot "$FD4")"
bash "$RM" convert sdd-git --dry-run --customized-only --root "$FD4" > "$TMP/d4.out" 2>&1
D4_RC=$?
SNAP4_AFTER="$(snapshot "$FD4")"
assert "exits 2" "[ $D4_RC -eq 2 ]"
assert "STOP names the counterpart plugin (loom-git)" \
  "grep -q 'STOP' '$TMP/d4.out' && grep -q 'loom-git' '$TMP/d4.out'"
assert "nothing was written (snapshot identical)" "[ \"\$SNAP4_BEFORE\" = \"\$SNAP4_AFTER\" ]"

echo ""
echo "D. Renamed-pristine: sdd-git without local edits recommends REMOVE naming loom-git;"
echo "   removing loom-git flips it to KEEP-AS-IS 'not installed yet'"

FD5="$TMP/fixtureD5"; cp -R "$FIX1" "$FD5"
# restore the committed copy with `git show` (read-only), not `git checkout`
git -C "$FD5" show HEAD:plugins/sdd-git/commands/git-push.md > "$FD5/plugins/sdd-git/commands/git-push.md"
bash "$RM" scan --json --root "$FD5" > "$TMP/d5.json" 2>&1
assert "sdd-git pristine now recommends REMOVE naming plugin:loom-git" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/d5.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-git\")
assert it[\"state\"] == \"pristine\", it
assert it[\"recommended\"] == \"REMOVE\", it
assert \"loom-git\" in it[\"reason\"], it
'"
rm -rf "$FD5/plugins/loom-git"
bash "$RM" scan --json --root "$FD5" > "$TMP/d5b.json" 2>&1
assert "with loom-git removed, sdd-git falls back to KEEP-AS-IS 'not installed yet'" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/d5b.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-git\")
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert \"not installed yet\" in it[\"reason\"], it
'"

echo ""
echo "D. Moved path (§15.2-F): MOVE, then REMOVE-blocked when upstream ships the new path,"
echo "   REMOVE once it is on disk, KEEP-AS-IS when the old copy is customized"

# A minimal throwaway repo: old/thing.md committed, sync-ref stamped, no tags.
# The row comes from a temp registry (--registry), so the upstream-registry
# resolution never interferes; refs/loom-upstream/main is used ONLY to answer
# "does upstream ship <new>". Verbs: init, add, commit, update-ref, rev-parse.
FD6="$TMP/fixtureD6"
mkdir -p "$FD6/.logic-loom/config" "$FD6/.logic-loom/lib" "$FD6/old"
git init -q "$FD6"
cp "$LIB" "$FD6/.logic-loom/lib/release-migrations.sh"
cp "$REG" "$FD6/.logic-loom/config/release-migrations.conf"
echo "FRAMEWORK_VERSION=7.0.0" > "$FD6/.logic-loom/config/architecture.conf"
echo "thing" > "$FD6/old/thing.md"
( cd "$FD6" && git add -A >/dev/null && git commit -q -m "old/thing.md present" )
git -C "$FD6" rev-parse HEAD > "$FD6/.sdd-sync-ref"
( cd "$FD6" && git add -A >/dev/null && git commit -q -m "stamp sync-ref" )
# Round-2 finding 1: the sync-ref is only a baseline when refs/loom-upstream/
# main exists and reaches it.
git -C "$FD6" update-ref refs/loom-upstream/main HEAD
MOVE_REG="$TMP/move-reg.conf"
echo 'path | old/thing.md | renamed | path:new/thing.md | MOVE | v6.0.0 | v9.0.0 | moved' > "$MOVE_REG"

bash "$RM" scan --json --root "$FD6" --registry "$MOVE_REG" > "$TMP/d6a.json" 2>&1
assert "pristine + new path absent everywhere -> MOVE, not blocked, move_command is a self-guarding git mv (finding 4)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/d6a.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"old/thing.md\")
assert it[\"kind\"] == \"path\" and it[\"state\"] == \"pristine\", it
assert it[\"recommended\"] == \"MOVE\" and it[\"blocked\"] is False, it
mc = it[\"move_command\"]
assert mc.startswith(\"if [ -e \"), mc
assert \"new/thing.md\" in mc, mc
assert \"git mv '\''old/thing.md'\'' '\''new/thing.md'\''\" in mc, mc
assert \"re-run: release-migrations.sh plan old/thing.md\" in mc, mc
assert it[\"remove_command\"] == \"\", it
'"
bash "$RM" plan old/thing.md --root "$FD6" --registry "$MOVE_REG" > "$TMP/d6a.plan.out" 2>&1
assert "plan text carries the guarded git mv line and the [m]ove menu" \
  "grep -qF 'git mv '\''old/thing.md'\'' '\''new/thing.md'\''' '$TMP/d6a.plan.out' && grep -qF '[m]ove' '$TMP/d6a.plan.out'"
assert "…and names re-run plan when the destination now exists (finding 4)" \
  "grep -qF 're-run plan old/thing.md to get a fresh recommendation' '$TMP/d6a.plan.out'"

# round-5 finding 3, residual gap found while adding test coverage: the SAME
# pristine fixture as above, but the registry row's REPLACEMENT path (not
# its `name`) carries a shell metacharacter/whitespace — proving the at-use
# guard in compute_recommendation (never only lint, which a project registry
# can skip) refuses to build a move command from an unsafe $newp, the same
# way finding 4's guard above refuses an unsafe $name.
UNSAFE_MOVE_REG="$TMP/unsafe-move-reg.conf"
echo "path | old/thing.md | renamed | path:new/evil name.md | MOVE | v6.0.0 | v9.0.0 | evil replacement path" > "$UNSAFE_MOVE_REG"
bash "$RM" scan --json --root "$FD6" --registry "$UNSAFE_MOVE_REG" > "$TMP/d6unsafe.json" 2>&1
assert "an UNLINTED registry row whose replacement path is unsafe: move_command is empty, KEEP-AS-IS, blocked, reason names the bad replacement path (never a malformed printed command)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/d6unsafe.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"old/thing.md\")
assert it[\"state\"] == \"pristine\", it
assert it[\"recommended\"] == \"KEEP-AS-IS\" and it[\"blocked\"] is True, it
assert it[\"move_command\"] == \"\" and it[\"remove_command\"] == \"\", it
assert \"replacement path\" in it[\"reason\"] and \"new/evil name.md\" in it[\"reason\"], it[\"reason\"]
'"
assert "…and the SAME row, LINTED first, is also rejected at lint time (belt-and-suspenders, not only the at-use guard)" \
  "! bash '$RM' lint --root '$FD6' --registry '$UNSAFE_MOVE_REG' >'$TMP/d6unsafe.lint.out' 2>&1; grep -q \"replacement path 'new/evil name.md' must contain only\" '$TMP/d6unsafe.lint.out'"

# new/thing.md committed and reachable at refs/loom-upstream/main, then removed
# from the working tree again (a further commit) — upstream ships it, disk lacks it.
mkdir -p "$FD6/new"; echo "new" > "$FD6/new/thing.md"
( cd "$FD6" && git add -A >/dev/null && git commit -q -m "upstream ships new/thing.md" )
git -C "$FD6" update-ref refs/loom-upstream/main HEAD
rm -rf "$FD6/new"
( cd "$FD6" && git add -A >/dev/null && git commit -q -m "local tree without new/thing.md" )
bash "$RM" scan --json --root "$FD6" --registry "$MOVE_REG" > "$TMP/d6b.json" 2>&1
assert "pristine + new path absent on disk but present at refs/loom-upstream/main -> REMOVE, blocked, 'accept its clean-add proposal first'" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/d6b.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"old/thing.md\")
assert it[\"recommended\"] == \"REMOVE\" and it[\"blocked\"] is True, it
assert \"accept its clean-add proposal first\" in it[\"reason\"], it[\"reason\"]
assert it[\"move_command\"] == \"\", it
assert it[\"blocked_by\"] and \"new/thing.md\" in it[\"blocked_by\"][0][\"file\"], it[\"blocked_by\"]
'"

mkdir -p "$FD6/new"; echo "new" > "$FD6/new/thing.md"
bash "$RM" scan --json --root "$FD6" --registry "$MOVE_REG" > "$TMP/d6c.json" 2>&1
assert "pristine + new path on disk -> REMOVE, not blocked, remove_command 'git rm old/thing.md' (file, not -r)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/d6c.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"old/thing.md\")
assert it[\"recommended\"] == \"REMOVE\" and it[\"blocked\"] is False, it
assert it[\"remove_command\"] == \"git rm '\''old/thing.md'\''\", it
'"

echo "extra" >> "$FD6/old/thing.md"
bash "$RM" scan --json --root "$FD6" --registry "$MOVE_REG" > "$TMP/d6d.json" 2>&1
assert "customized old copy -> KEEP-AS-IS 'carry your diff into new/thing.md'" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/d6d.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"old/thing.md\")
assert it[\"state\"] == \"customized\", it
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert \"carry your diff into new/thing.md\" in it[\"reason\"], it[\"reason\"]
'"

# ═══════════════════════════════════════════════════════════════════════════
# SECTION E — release gate (check-release)
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "E. check-release — real tree, and the row-declaration gate on temp roots"

case "$TREE_KIND" in
  maintainer)
    bash "$RM" check-release --root "$ROOT" > "$TMP/e0.out" 2>&1
    E0_RC=$?
    echo "     $(head -1 "$TMP/e0.out")"
    assert "check-release (no --since) exits 0 on the maintainer tree today (predates the floor)" \
      "[ $E0_RC -eq 0 ]"
    ;;
  sanitized)
    skip "release gate is a maintainer check — sanitized tree (CHANGELOG.md is stripped; the gate runs in the promote job)"
    ;;
esac

# Temp root builder: architecture.conf + a registry copy at the same relative
# path the script expects, no git needed (framework_version/loom_migration_rows
# are pure filesystem reads).
mk_temp_root() {  # $1 = dir, $2 = FRAMEWORK_VERSION, $3 = registry body (or "" to skip)
  local d="$1"
  mkdir -p "$d/.logic-loom/config" "$d/.logic-loom/lib"
  echo "FRAMEWORK_VERSION=$2" > "$d/.logic-loom/config/architecture.conf"
  cp "$LIB" "$d/.logic-loom/lib/release-migrations.sh"
  if [ -n "$3" ]; then
    printf '%s\n' "$3" > "$d/.logic-loom/config/release-migrations.conf"
  else
    : > "$d/.logic-loom/config/release-migrations.conf"
  fi
}

E1="$TMP/e-predates"
mk_temp_root "$E1" "6.6.2" ""
bash "$RM" check-release --root "$E1" > "$TMP/e1.out" 2>&1
assert "below the v7.0.0 floor: exit 0, 'predates'" \
  "[ $? -eq 0 ] && grep -q predates '$TMP/e1.out'"

E2="$TMP/e-norows"
mk_temp_root "$E2" "9.9.9" ""
bash "$RM" check-release --root "$E2" > "$TMP/e2.out" 2>&1
assert "9.9.9 with zero rows: exit 1, 'declares no migration'" \
  "[ $? -eq 1 ] && grep -q 'declares no migration' '$TMP/e2.out'"

E3="$TMP/e-nonesibling"
mk_temp_root "$E3" "9.9.9" "$(printf 'none | - | none | none | - | - | v9.9.9 | nothing\ncontent | x.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b')"
echo "x foo" > "$E3/x.md"
bash "$RM" check-release --root "$E3" > "$TMP/e3.out" 2>&1
assert "9.9.9 with a none row plus a sibling row: exit 1, 'contradiction'" \
  "[ $? -eq 1 ] && grep -qi 'contradiction' '$TMP/e3.out'"

E4="$TMP/e-nonenolog"
mk_temp_root "$E4" "9.9.9" "none | - | none | none | - | - | v9.9.9 | nothing changed"
bash "$RM" check-release --root "$E4" > "$TMP/e4.out" 2>&1
assert "the none-only row with no CHANGELOG.md: exit 0 (nothing to roll)" "[ $? -eq 0 ]"
assert "…and it says 'changelog: not present' (the sanitized-tree branch)" \
  "grep -q 'changelog: not present' '$TMP/e4.out'"
echo "not a changelog heading" > "$E4/CHANGELOG.md"
bash "$RM" check-release --root "$E4" > "$TMP/e4b.out" 2>&1
assert "the none-only row with a CHANGELOG.md lacking '## [9.9.9]': exit 1, 'roll the CHANGELOG'" \
  "[ $? -eq 1 ] && grep -q 'roll the CHANGELOG' '$TMP/e4b.out'"
echo "## [9.9.9] - 2099-01-01" > "$E4/CHANGELOG.md"
bash "$RM" check-release --root "$E4" > "$TMP/e4c.out" 2>&1
assert "…with the heading present: exit 0" "[ $? -eq 0 ]"

E5="$TMP/e-contentrow"
mk_temp_root "$E5" "9.9.9" "content | x.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e5xfix"
echo "x foo" > "$E5/x.md"
mkdir -p "$E5/tests/fixtures/release-migrations"
printf 'has foo (the problem state)\n' > "$E5/tests/fixtures/release-migrations/e5xfix.before"
printf 'no longer has it (fixed)\n' > "$E5/tests/fixtures/release-migrations/e5xfix.after"
echo "## [9.9.9]" > "$E5/CHANGELOG.md"
bash "$RM" check-release --root "$E5" > "$TMP/e5.out" 2>&1
assert "a content row + CHANGELOG heading with no ### Migrat subsection: exit 1" "[ $? -eq 1 ]"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E5/CHANGELOG.md"
bash "$RM" check-release --root "$E5" > "$TMP/e5b.out" 2>&1
assert "…with the ### Migrating subsection present: exit 0" "[ $? -eq 0 ]"

echo ""
echo "E. finding 7: check-release EXECUTES every content row of the release it checks"

E8="$TMP/e-execute-noproof"
mk_temp_root "$E8" "9.9.9" "content | y.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b"
echo "y foo" > "$E8/y.md"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E8/CHANGELOG.md"
bash "$RM" check-release --root "$E8" > "$TMP/e8.out" 2>&1
assert "a content row with NO fixture: and NO git history at all: fails closed with a precise message" \
  "[ $? -eq 1 ] && grep -q 'content row y.md@v9.9.9: cannot verify' '$TMP/e8.out'"
assert "…and it ALSO reports the current shipped copy still shows the un-fixed state (both proofs run)" \
  "grep -q 'content row y.md@v9.9.9: current tree.*still exhibits the pattern' '$TMP/e8.out'"

E9="$TMP/e-execute-fixture-ok"
mk_temp_root "$E9" "9.9.9" "content | z.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e9zfix"
mkdir -p "$E9/tests/fixtures/release-migrations"
printf 'has foo\n' > "$E9/tests/fixtures/release-migrations/e9zfix.before"
printf 'fixed, no longer has it\n' > "$E9/tests/fixtures/release-migrations/e9zfix.after"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E9/CHANGELOG.md"
bash "$RM" check-release --root "$E9" > "$TMP/e9.out" 2>&1
assert "a content row with a well-formed fixture: pair passes execution (exit 0)" "[ $? -eq 0 ]"
assert "…including the finding-5 scan-path proof (no 'fixture proof' failure line for it — TEMPLATE and ADOPTED both silent)" \
  "! grep -q 'fixture proof' '$TMP/e9.out'"

echo ""
echo "E. finding 5: check-release's fixture proof runs the REAL scan discovery path"
echo "   (emit_content_item), not just the pattern regex, for TEMPLATE and ADOPTED"

E9C="$TMP/e-execute-fixture-nested"
mk_temp_root "$E9C" "9.9.9" "content | docs/nested/dir/setting.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e9cfix"
mkdir -p "$E9C/tests/fixtures/release-migrations"
printf 'has foo\n' > "$E9C/tests/fixtures/release-migrations/e9cfix.before"
printf 'fixed, no longer has it\n' > "$E9C/tests/fixtures/release-migrations/e9cfix.after"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E9C/CHANGELOG.md"
bash "$RM" check-release --root "$E9C" > "$TMP/e9c.out" 2>&1
assert "a fixture-backed row at a NESTED path: the scan-path proof builds the tree correctly and passes in both modes (exit 0, no fixture-proof failure)" \
  "[ $? -eq 0 ] && ! grep -q 'fixture proof' '$TMP/e9c.out'"

E9D="$TMP/e-execute-fixture-absent-fate"
mk_temp_root "$E9D" "9.9.9" "content | marker.md | absent | pattern:fixed-marker | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e9dfix"
mkdir -p "$E9D/tests/fixtures/release-migrations"
printf 'no marker here — the problem state\n' > "$E9D/tests/fixtures/release-migrations/e9dfix.before"
printf 'fixed-marker now present\n' > "$E9D/tests/fixtures/release-migrations/e9dfix.after"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E9D/CHANGELOG.md"
bash "$RM" check-release --root "$E9D" > "$TMP/e9d.out" 2>&1
assert "a fate=absent fixture-backed row: the scan-path proof exercises the OTHER emit branch and passes in both modes" \
  "[ $? -eq 0 ] && ! grep -q 'fixture proof' '$TMP/e9d.out'"

# The fail-then-pass proof for finding 5 itself (the two cases above are
# positive controls and pass with or without the scan-path proof): a .before
# fixture the pattern-level check ACCEPTS but scan's real discovery would
# NEVER fire on. A NUL byte does it — `$(cat fixture)` drops NULs (a bash
# variable cannot hold one), so the pattern helper sees plain text and
# matches, while emit_content_item greps the file on disk with -I, which
# classifies it as binary and finds nothing. Before this proof existed such
# a row passed check-release and shipped a migration that could never fire.
E9E="$TMP/e-execute-fixture-binary"
mk_temp_root "$E9E" "9.9.9" "content | w.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e9efix"
mkdir -p "$E9E/tests/fixtures/release-migrations"
printf 'has foo\000but a NUL byte makes grep -I call it binary\n' > "$E9E/tests/fixtures/release-migrations/e9efix.before"
printf 'fixed, no longer has it\n' > "$E9E/tests/fixtures/release-migrations/e9efix.after"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E9E/CHANGELOG.md"
bash "$RM" check-release --root "$E9E" > "$TMP/e9e.out" 2>&1
assert "a .before fixture scan can never fire on (NUL byte -> grep -I binary) passes the pattern-level check but FAILS the scan-path proof: exit 1, naming both modes and the path" \
  "[ $? -eq 1 ] && grep -q 'fixture proof (TEMPLATE, scan path): the .before fixture at w.md does NOT produce a scan item' '$TMP/e9e.out' && grep -q 'fixture proof (ADOPTED, scan path): the .before fixture at w.md does NOT produce a scan item' '$TMP/e9e.out'"

# A proof that cannot run is a failure, not a silent pass: a content-row name
# spelled as a directory (docs/) is one scan's content_matches can never
# match, so the fixture cannot be placed at it — check-release must say so
# and fail rather than exit 0 with the row "declared".
E9F="$TMP/e-execute-fixture-unplaceable"
mk_temp_root "$E9F" "9.9.9" "content | docs/ | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e9ffix"
mkdir -p "$E9F/tests/fixtures/release-migrations"
printf 'has foo\n' > "$E9F/tests/fixtures/release-migrations/e9ffix.before"
printf 'fixed\n' > "$E9F/tests/fixtures/release-migrations/e9ffix.after"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E9F/CHANGELOG.md"
bash "$RM" check-release --root "$E9F" > "$TMP/e9f.out" 2>&1
assert "a row whose name (docs/) content_matches can never match: the scan-path proof cannot place the fixture and FAILS loudly (exit 1) instead of passing vacuously" \
  "[ $? -eq 1 ] && grep -q 'cannot place the fixture at docs/' '$TMP/e9f.out' && ! grep -q 'declares 1 migration row' '$TMP/e9f.out'"

# round-3 finding 5, at-use half: check-release never runs `lint` itself, so
# a bad row reaches _loom_rm_verify_fixture_scan_path directly even in a
# registry nobody linted. A name with a '..' segment must be refused BEFORE
# any mkdir/cp is attempted from it — never silently walked into a real path
# outside the scratch tree.
E9G="$TMP/e-execute-fixture-traversal"
mk_temp_root "$E9G" "9.9.9" "content | ../outside.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e9gfix"
mkdir -p "$E9G/tests/fixtures/release-migrations"
printf 'has foo\n' > "$E9G/tests/fixtures/release-migrations/e9gfix.before"
printf 'fixed, no longer has it\n' > "$E9G/tests/fixtures/release-migrations/e9gfix.after"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E9G/CHANGELOG.md"
[ -e "$E9G/../outside.md" ] && rm -f "$E9G/../outside.md"
bash "$RM" check-release --root "$E9G" > "$TMP/e9g.out" 2>&1
# Round-4: the row is now refused one layer earlier — by the parser every
# consumer shares (_loom_parse_row) — so check-release never builds a proof
# from it at all; the gate names the refused row and exits 1 instead of the
# misleading "declares no migration". The at-use guard inside
# _loom_rm_verify_fixture_scan_path stays as defense in depth.
assert "a fixture-backed content row whose name contains a '..' segment: check-release refuses the ROW outright (exit 1), naming the traversal" \
  "[ $? -eq 1 ] && grep -q \"registry row refused: LINT: line 1: name '../outside.md' must not be absolute or contain a '..'/'.' path segment\" '$TMP/e9g.out' && ! grep -q 'declares no migration' '$TMP/e9g.out'"
assert "…and nothing was ever written outside the scratch tree (no file materialized at \$E9G/../outside.md)" \
  "[ ! -e '$E9G/../outside.md' ]"
rm -f "$E9G/../outside.md" 2>/dev/null || true

# Finding 4 (medium, round 5 review): the E9G proof above only shows the
# PARSER refusing the row one layer earlier — it never actually reaches
# _loom_rm_verify_fixture_scan_path's own at-use guard at all, so a test
# suite that stopped there would keep passing even if that guard were
# deleted outright. Reach it DIRECTLY: `source` the script (in a subshell —
# release-migrations.sh now guards its own `main "$@"` behind a
# BASH_SOURCE-vs-$0 check specifically so this is possible, see its bottom)
# and call the function itself with a crafted traversing name, bypassing
# the parser entirely.
echo ""
echo "D. finding 4: the AT-USE traversal guard inside _loom_rm_verify_fixture_scan_path fires on its own, not merely one layer up in the shared parser"
UNIT_ROOT="$TMP/unit-guard-root"
mkdir -p "$UNIT_ROOT/.logic-loom/config" "$UNIT_ROOT/.logic-loom/lib"
cp "$LIB" "$UNIT_ROOT/.logic-loom/lib/release-migrations.sh"
: > "$UNIT_ROOT/.logic-loom/config/release-migrations.conf"
UNIT_BEFORE="$TMP/unit-guard-before.txt"; echo "before" > "$UNIT_BEFORE"
UNIT_AFTER="$TMP/unit-guard-after.txt"; echo "after" > "$UNIT_AFTER"

UNIT_RC_WITH_GUARD=0
UNIT_OUT_WITH_GUARD="$(
  source "$RM" --root "$UNIT_ROOT" >/dev/null 2>&1
  _loom_rm_verify_fixture_scan_path "unit-test" "../evil.md" "present" "foo" "PROPOSE" "$UNIT_BEFORE" "$UNIT_AFTER" 2>&1
)" || UNIT_RC_WITH_GUARD=$?
assert "with the guard present: calling _loom_rm_verify_fixture_scan_path DIRECTLY on a traversing name refuses (rc 1), naming the row" \
  "[ $UNIT_RC_WITH_GUARD -eq 1 ] && printf '%s' \"\$UNIT_OUT_WITH_GUARD\" | grep -qF 'refusing to build a filesystem path from it'"
assert "…and nothing was created outside this run's own scratch tree despite the crafted name" \
  "[ ! -e '$TMP/evil.md' ] && [ ! -e '/tmp/evil.md' ]"

# Prove the guard is WHAT refuses it — not some unrelated failure — by
# neutralizing ONLY that one check, in this same subshell (never in the
# shipped file), and showing the identical call then proceeds PAST the
# point the guard would have stopped it. This is the "fails without it"
# half finding 4 asks for, without deleting the guard from the real script.
UNIT_OUT_NO_GUARD="$(
  source "$RM" --root "$UNIT_ROOT" >/dev/null 2>&1
  loom_path_traversal_safe() { return 0; }   # neutralize the guard, in-process only
  _loom_rm_verify_fixture_scan_path "unit-test" "../evil.md" "present" "foo" "PROPOSE" "$UNIT_BEFORE" "$UNIT_AFTER" 2>&1
)"
assert "…and WITHOUT the guard (neutralized in-process, same call): it no longer refuses on the traversal check — proceeds past it instead" \
  "! printf '%s' \"\$UNIT_OUT_NO_GUARD\" | grep -qF 'refusing to build a filesystem path from it'"

# round-3 finding 1: the EXIT-trap cleanup for the scan-path proof's scratch
# trees must never word-split a TMPDIR containing a space. Reproduction: put
# TMPDIR at "<parent>/with space" — the scratch tree mktemp creates sits
# UNDER it, so its own path contains that same space — and put a REAL
# sibling directory at "<parent>/with" (the exact bogus first "word" an
# unquoted `for d in $list; do rm -rf "$d"; done` would produce by
# splitting on the embedded space). The sibling must survive; nothing under
# TMPDIR should be left behind either.
G1="$TMP/g-space-content"
mk_temp_root "$G1" "9.9.9" "content | w.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:g1fix"
mkdir -p "$G1/tests/fixtures/release-migrations"
printf 'has foo\n' > "$G1/tests/fixtures/release-migrations/g1fix.before"
printf 'fixed, no longer has it\n' > "$G1/tests/fixtures/release-migrations/g1fix.after"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$G1/CHANGELOG.md"

G1_TMPDIR_PARENT="$TMP/g-space-tmpdir"
mkdir -p "$G1_TMPDIR_PARENT"
G1_SIBLING="$G1_TMPDIR_PARENT/with"
mkdir -p "$G1_SIBLING"
echo "must survive cleanup" > "$G1_SIBLING/marker.txt"
G1_TMPDIR="$G1_TMPDIR_PARENT/with space"
mkdir -p "$G1_TMPDIR"

TMPDIR="$G1_TMPDIR" bash "$RM" check-release --root "$G1" > "$TMP/g1.out" 2>&1
G1_RC=$?
assert "TMPDIR containing a space: check-release still exits 0 (the fixture proof itself passes)" \
  "[ $G1_RC -eq 0 ]"
assert "TMPDIR containing a space: the sibling directory '.../with' (the bogus word-split target) survives the EXIT-trap cleanup, with its content intact" \
  "[ -f '$G1_SIBLING/marker.txt' ] && grep -qF 'must survive cleanup' '$G1_SIBLING/marker.txt'"
assert "TMPDIR containing a space: no scan-path proof scratch tree is left behind under TMPDIR after the run" \
  "[ -z \"\$(find '$G1_TMPDIR' -mindepth 1 -maxdepth 2 -name 'loom-rm-fixtureproof*' 2>/dev/null)\" ]"

# Finding 6 (low, round 5 review): the proof-tree EXIT cleanup used to be a
# plain check-then-rm-rf (case-match on a string prefix, then a separate
# `rm -rf` a moment later). Reach the new _loom_rm_safe_to_remove guard
# DIRECTLY (source the script, same technique as finding 4 above) and prove
# it refuses a symlinked entry and a path outside the sandbox, while still
# allowing a genuine scratch directory the same run created.
echo ""
echo "D. finding 6: _loom_rm_safe_to_remove refuses a symlink entry and a path outside the sandbox, allows a genuine scratch dir"
UNIT_CLEAN_VICTIM="$TMP/unit-cleanup-victim"
mkdir -p "$UNIT_CLEAN_VICTIM"
echo "must survive" > "$UNIT_CLEAN_VICTIM/marker.txt"
(
  source "$RM" --root "$UNIT_ROOT" >/dev/null 2>&1
  _loom_rm_proof_base >/dev/null
  REAL_DIR="$(mktemp -d "$_LOOM_RM_PROOF_BASE/fixtureproof.XXXXXX")"
  SYMLINK_ENTRY="$_LOOM_RM_PROOF_BASE/fixtureproof-evil-symlink"
  ln -s "$UNIT_CLEAN_VICTIM" "$SYMLINK_ENTRY"
  if _loom_rm_safe_to_remove "$REAL_DIR" "$_LOOM_RM_PROOF_BASE"; then echo "REAL_DIR=allowed"; else echo "REAL_DIR=refused"; fi
  if _loom_rm_safe_to_remove "$SYMLINK_ENTRY" "$_LOOM_RM_PROOF_BASE"; then echo "SYMLINK=allowed"; else echo "SYMLINK=refused"; fi
  if _loom_rm_safe_to_remove "$UNIT_CLEAN_VICTIM" "$_LOOM_RM_PROOF_BASE"; then echo "OUTSIDE_BASE=allowed"; else echo "OUTSIDE_BASE=refused"; fi
) > "$TMP/unit-safe-to-remove.out" 2>&1
assert "a genuine scratch dir this run created under the base: allowed" \
  "grep -qF 'REAL_DIR=allowed' '$TMP/unit-safe-to-remove.out'"
assert "a symlink entry sitting under the base: refused, never followed" \
  "grep -qF 'SYMLINK=refused' '$TMP/unit-safe-to-remove.out'"
assert "a path outside the base entirely: refused" \
  "grep -qF 'OUTSIDE_BASE=refused' '$TMP/unit-safe-to-remove.out'"
assert "…and the victim the symlink pointed at was never touched by any of this" \
  "[ -f '$UNIT_CLEAN_VICTIM/marker.txt' ] && grep -qF 'must survive' '$UNIT_CLEAN_VICTIM/marker.txt'"
rm -rf "$UNIT_CLEAN_VICTIM" 2>/dev/null || true

E10="$TMP/e-execute-fixture-broken-before"
mk_temp_root "$E10" "9.9.9" "content | w.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e10wfix"
mkdir -p "$E10/tests/fixtures/release-migrations"
printf 'does not have the target text at all\n' > "$E10/tests/fixtures/release-migrations/e10wfix.before"
printf 'fixed\n' > "$E10/tests/fixtures/release-migrations/e10wfix.after"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E10/CHANGELOG.md"
bash "$RM" check-release --root "$E10" > "$TMP/e10.out" 2>&1
assert "a fixture .before that does NOT reproduce the claimed problem state: fails closed, names the row" \
  "[ $? -eq 1 ] && grep -q 'content row w.md@v9.9.9: pattern does not reproduce the claimed prior state' '$TMP/e10.out'"

E11="$TMP/e-execute-fixture-broken-after"
mk_temp_root "$E11" "9.9.9" "content | v.md | present | pattern:foo | PROPOSE | - | v9.9.9 | proposal: a; why: b; fixture:e11vfix"
mkdir -p "$E11/tests/fixtures/release-migrations"
printf 'has foo\n' > "$E11/tests/fixtures/release-migrations/e11vfix.before"
printf 'still has foo — not actually fixed\n' > "$E11/tests/fixtures/release-migrations/e11vfix.after"
{ echo "## [9.9.9]"; echo "### Migrating from 9.8"; } > "$E11/CHANGELOG.md"
bash "$RM" check-release --root "$E11" > "$TMP/e11.out" 2>&1
assert "a fixture .after that still exhibits the pre-fix pattern: fails closed, names the row" \
  "[ $? -eq 1 ] && grep -q 'content row v.md@v9.9.9: its own fixture e11vfix.after still exhibits the pre-fix pattern' '$TMP/e11.out'"

E12="$TMP/e-execute-history"
mkdir -p "$E12/.logic-loom/config" "$E12/.logic-loom/lib"
git init -q "$E12"
echo "FRAMEWORK_VERSION=9.0.1" > "$E12/.logic-loom/config/architecture.conf"
cp "$LIB" "$E12/.logic-loom/lib/release-migrations.sh"
: > "$E12/.logic-loom/config/release-migrations.conf"
echo "no foo here" > "$E12/u.md"
( cd "$E12" && git add -A >/dev/null && git commit -q -m "commit 1: u.md pre-fix" )
git -C "$E12" update-ref refs/tags/v9.0.0 HEAD
echo "content | u.md | absent | pattern:fixed-marker | PROPOSE | - | v9.0.1 | proposal: a; why: b" > "$E12/.logic-loom/config/release-migrations.conf"
echo "fixed-marker now present" > "$E12/u.md"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E12/CHANGELOG.md"
( cd "$E12" && git add -A >/dev/null && git commit -q -m "commit 2: registry row + u.md fixed" )
bash "$RM" check-release --since auto --root "$E12" > "$TMP/e12.out" 2>&1
assert "a content row with NO fixture:, proven purely from git history (prev tag + current tree): exit 0" \
  "[ $? -eq 0 ] && grep -q 'previous release: v9.0.0' '$TMP/e12.out'"
rm -f "$E12/u.md"
bash "$RM" check-release --since auto --root "$E12" > "$TMP/e12b.out" 2>&1
assert "…and once the current shipped copy is deleted entirely, the after-proof is explicitly skipped (not a failure)" \
  "[ $? -eq 0 ] && grep -q 'content row u.md@v9.0.1: (no shipped current copy' '$TMP/e12b.out'"

E13="$TMP/e-execute-glob"
mkdir -p "$E13/.logic-loom/config" "$E13/.logic-loom/lib" "$E13/docs"
git init -q "$E13"
cp "$LIB" "$E13/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.1" > "$E13/.logic-loom/config/architecture.conf"
echo "old text foo here" > "$E13/docs/a.md"
: > "$E13/.logic-loom/config/release-migrations.conf"
( cd "$E13" && git add -A >/dev/null && git commit -q -m "commit 1: pre-fix" )
git -C "$E13" update-ref refs/tags/v9.0.0 HEAD
echo 'content | docs/*.md | present | pattern:foo | PROPOSE | - | v9.0.1 | proposal: a; why: b' > "$E13/.logic-loom/config/release-migrations.conf"
echo "fixed text, no marker" > "$E13/docs/a.md"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E13/CHANGELOG.md"
( cd "$E13" && git add -A >/dev/null && git commit -q -m "commit 2: registry row (glob) + a.md fixed" )
bash "$RM" check-release --since auto --root "$E13" > "$TMP/e13.out" 2>&1
assert "a GLOB content row (docs/*.md), proven via git ls-tree at the prev tag + the current tree: exit 0" "[ $? -eq 0 ]"
echo "still has foo, not fixed" > "$E13/docs/a.md"
bash "$RM" check-release --since auto --root "$E13" > "$TMP/e13b.out" 2>&1
assert "…and once the glob's current copy regresses to the un-fixed state: fails closed, names the matched file" \
  "[ $? -eq 1 ] && grep -q 'content row docs/\\*.md@v9.0.1: current tree.*(docs/a.md)' '$TMP/e13b.out'"

# reviewer (finding 7): the before-proof for a GLOB row must be satisfied by
# ANY file at the previous tag, not only the first ls-tree match — a clean
# docs/a.md ahead of the problem-bearing docs/b.md was a false fail-closed.
E14="$TMP/e-execute-glob-anymatch"
mkdir -p "$E14/.logic-loom/config" "$E14/.logic-loom/lib" "$E14/docs"
git init -q "$E14"
cp "$LIB" "$E14/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.1" > "$E14/.logic-loom/config/architecture.conf"
echo "clean, nothing here" > "$E14/docs/a.md"
echo "old text foo here" > "$E14/docs/b.md"
: > "$E14/.logic-loom/config/release-migrations.conf"
( cd "$E14" && git add -A >/dev/null && git commit -q -m "commit 1: a.md clean, b.md pre-fix" )
git -C "$E14" update-ref refs/tags/v9.0.0 HEAD
echo 'content | docs/*.md | present | pattern:foo | PROPOSE | - | v9.0.1 | proposal: a; why: b' > "$E14/.logic-loom/config/release-migrations.conf"
echo "fixed" > "$E14/docs/b.md"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E14/CHANGELOG.md"
( cd "$E14" && git add -A >/dev/null && git commit -q -m "commit 2: registry row (glob) + b.md fixed" )
bash "$RM" check-release --since auto --root "$E14" > "$TMP/e14.out" 2>&1
assert "a GLOB content row whose FIRST match at the prev tag (docs/a.md) is clean but a LATER one (docs/b.md) has the pattern: grounded, exit 0" \
  "[ $? -eq 0 ] && ! grep -q 'does not reproduce' '$TMP/e14.out'"
echo "nothing here either" > "$E14/docs/b.md"
( cd "$E14" && git add -A >/dev/null && git commit -q -m "commit 3: b.md never had it" )
git -C "$E14" update-ref refs/tags/v9.0.0 HEAD
bash "$RM" check-release --since auto --root "$E14" > "$TMP/e14b.out" 2>&1
assert "…and when NO file at the prev tag has it, the failure names every file it checked" \
  "[ $? -eq 1 ] && grep -q 'does not reproduce the claimed prior state (checked v9.0.0:docs/a.md, v9.0.0:docs/b.md)' '$TMP/e14b.out'"

echo ""
echo "E. finding 2: content_prev never resolves to the SAME release being checked"

# The release under test (v9.0.1) has ALREADY been tagged — a legitimate
# post-release audit. Two tags exist: v9.0.0 (the true pre-fix state) and
# v9.0.1 (== HEAD, the post-fix state, i.e. the version check-release is
# being asked to verify). loom_latest_tag_at_or_below("9.0.1") would return
# v9.0.1 itself (<=, not <); proving the row's PRIOR state against its own
# POST-fix content fails it closed for no real reason. loom_latest_tag_below
# (strict <) must resolve v9.0.0 instead.
E15="$TMP/e-content-prev-self-tag"
mkdir -p "$E15/.logic-loom/config" "$E15/.logic-loom/lib"
git init -q "$E15"
cp "$LIB" "$E15/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.1" > "$E15/.logic-loom/config/architecture.conf"
: > "$E15/.logic-loom/config/release-migrations.conf"
echo "no foo here" > "$E15/u.md"
( cd "$E15" && git add -A >/dev/null && git commit -q -m "commit 1: u.md pre-fix" )
git -C "$E15" update-ref refs/tags/v9.0.0 HEAD
echo "content | u.md | absent | pattern:fixed-marker | PROPOSE | - | v9.0.1 | proposal: a; why: b" > "$E15/.logic-loom/config/release-migrations.conf"
echo "fixed-marker now present" > "$E15/u.md"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E15/CHANGELOG.md"
( cd "$E15" && git add -A >/dev/null && git commit -q -m "commit 2: registry row + u.md fixed" )
git -C "$E15" update-ref refs/tags/v9.0.1 HEAD
bash "$RM" check-release --root "$E15" > "$TMP/e15.out" 2>&1
assert "the release being checked is ALSO tagged (v9.0.1 == HEAD): content_prev still resolves to the TRUE previous tag (v9.0.0), row proven, exit 0" \
  "[ $? -eq 0 ] && ! grep -q 'does not reproduce the claimed prior state' '$TMP/e15.out'"

echo ""
echo "E. finding 2: content_prev honors an explicit --since instead of silently recomputing its own"

# Two tags: v8.0.0 (the true pre-fix state) and v9.0.0 (the fix already
# landed there too, coincidentally — a stand-in for "the newest tag below
# the version being checked is NOT the release that actually introduced the
# fix"). --since auto would pick v9.0.0 (nearest-below) and fail the row
# closed (v9.0.0 does not show the problem state); an explicit --since
# v8.0.0 must be honored for content_prev too, not just the removal guard.
E16="$TMP/e-content-prev-explicit-since"
mkdir -p "$E16/.logic-loom/config" "$E16/.logic-loom/lib"
git init -q "$E16"
cp "$LIB" "$E16/.logic-loom/lib/release-migrations.sh"
: > "$E16/.logic-loom/config/release-migrations.conf"
echo "no foo here" > "$E16/u.md"
( cd "$E16" && git add -A >/dev/null && git commit -q -m "commit 1: u.md pre-fix (the TRUE prior state)" )
git -C "$E16" update-ref refs/tags/v8.0.0 HEAD
echo "fixed-marker now present" > "$E16/u.md"
( cd "$E16" && git add -A >/dev/null && git commit -q -m "commit 2: u.md already fixed here too (coincidence)" )
git -C "$E16" update-ref refs/tags/v9.0.0 HEAD
echo "FRAMEWORK_VERSION=9.0.1" > "$E16/.logic-loom/config/architecture.conf"
echo "content | u.md | absent | pattern:fixed-marker | PROPOSE | - | v9.0.1 | proposal: a; why: b" > "$E16/.logic-loom/config/release-migrations.conf"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E16/CHANGELOG.md"
( cd "$E16" && git add -A >/dev/null && git commit -q -m "commit 3: registry row for v9.0.1" )
bash "$RM" check-release --since auto --root "$E16" > "$TMP/e16-auto.out" 2>&1
assert "--since auto picks the nearest-below tag (v9.0.0), which does NOT show the problem state: fails closed" \
  "[ $? -eq 1 ] && grep -q 'content row u.md@v9.0.1: pattern does not reproduce the claimed prior state' '$TMP/e16-auto.out'"
bash "$RM" check-release --since v8.0.0 --root "$E16" > "$TMP/e16-explicit.out" 2>&1
assert "…but an EXPLICIT --since v8.0.0 (the release that actually introduced the fix) is honored for content_prev too: exit 0, no false failure" \
  "[ $? -eq 0 ] && ! grep -q 'does not reproduce the claimed prior state' '$TMP/e16-explicit.out'"

echo ""
echo "E. finding 3: the removal guard's window validation holds for ANY --since ref, or rejects it plainly"

# A non-version --since (a raw commit sha, standing in for a branch name or
# any other non-release ref) must never let the window check (a removed
# item's registry row must date the removal to (prev, version]) silently
# degrade to a (kind,name)-only match — it is rejected outright instead.
E17="$TMP/e-since-nonversion"
mkdir -p "$E17/.logic-loom/config" "$E17/.logic-loom/lib" "$E17/plugins/sdd-foo"
git init -q "$E17"
echo "FRAMEWORK_VERSION=9.0.1" > "$E17/.logic-loom/config/architecture.conf"
cp "$LIB" "$E17/.logic-loom/lib/release-migrations.sh"
: > "$E17/.logic-loom/config/release-migrations.conf"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E17/CHANGELOG.md"
echo "x" > "$E17/plugins/sdd-foo/x.md"
( cd "$E17" && git add -A >/dev/null && git commit -q -m "commit 1: sdd-foo present" )
E17_C1="$(git -C "$E17" rev-parse HEAD)"
rm -rf "$E17/plugins/sdd-foo"
echo "plugin | sdd-foo | removed | none | REMOVE | v9.0.0 | v9.9.0 | misdated on purpose — a non-version --since must never let this slide through as (declared)" > "$E17/.logic-loom/config/release-migrations.conf"
( cd "$E17" && git add -A >/dev/null && git commit -q -m "commit 2: sdd-foo removed" )
bash "$RM" check-release --since "$E17_C1" --root "$E17" > "$TMP/e17.out" 2>&1
assert "a non-version --since (a bare commit sha) is rejected with a precise reason, not silently downgraded to a weaker match" \
  "[ $? -eq 1 ] && grep -q 'does not resolve to a vX.Y.Z release tag' '$TMP/e17.out'"
assert "…and the guard body never ran at all (no 'previous release:' / 'removals since' line — rejected before either could print)" \
  "! grep -q 'previous release:' '$TMP/e17.out' && ! grep -q 'removals since' '$TMP/e17.out'"

echo ""
echo "E. finding 3 (round-2 half): --since must resolve as an actual TAG, a branch of the same name is not enough"
# A BRANCH named vX.Y.Z resolves fine via the plain `rev-parse <prev>^{commit}`
# used to test resolvability at all (git's short-name lookup checks
# refs/heads too) and IS version-shaped text -- so, unlike E17's bare-sha
# case above, it would sail past both the "resolves" and "is version-shaped"
# gates. Only a check that requires refs/tags/<prev> specifically (not just
# ANY ref of that name) catches it. Positive control (an actual TAG named
# v9.0.0 is accepted) already exists elsewhere in this file (the "…and
# --since v9.0.0 (strictly below) is accepted" assertion, finding 2/3
# section below) -- this proves the negative half: a same-named BRANCH,
# with NO tag of that name anywhere in the repo, is rejected.
E17B="$TMP/e-since-branch-not-tag"
mkdir -p "$E17B/.logic-loom/config" "$E17B/.logic-loom/lib"
git init -q "$E17B"
echo "FRAMEWORK_VERSION=9.0.1" > "$E17B/.logic-loom/config/architecture.conf"
cp "$LIB" "$E17B/.logic-loom/lib/release-migrations.sh"
: > "$E17B/.logic-loom/config/release-migrations.conf"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E17B/CHANGELOG.md"
( cd "$E17B" && git add -A >/dev/null && git commit -q -m "commit 1" )
git -C "$E17B" branch v9.0.0 HEAD >/dev/null
assert "fixture sanity: v9.0.0 resolves to a commit (via the branch) but refs/tags/v9.0.0 does NOT exist" \
  "git -C '$E17B' rev-parse -q --verify 'v9.0.0^{commit}' >/dev/null 2>&1 && ! git -C '$E17B' rev-parse -q --verify 'refs/tags/v9.0.0^{commit}' >/dev/null 2>&1"
bash "$RM" check-release --since v9.0.0 --root "$E17B" > "$TMP/e17b.out" 2>&1
assert "a BRANCH named v9.0.0 (version-shaped, resolves, but not a tag) is rejected with the tag-specific reason, not silently accepted" \
  "[ $? -eq 1 ] && grep -q 'looks like a release (vX.Y.Z) but does not name an actual release tag' '$TMP/e17b.out' && grep -q 'refs/tags/v9.0.0 does not exist' '$TMP/e17b.out'"
assert "…and it is NOT rejected via the non-version-ref reason (E17's case) — this is the round-2 tag-specific gate, a different reason" \
  "! grep -q 'does not resolve to a vX.Y.Z release tag' '$TMP/e17b.out'"
assert "…and the guard body never ran at all here either" \
  "! grep -q 'previous release:' '$TMP/e17b.out' && ! grep -q 'removals since' '$TMP/e17b.out'"

# The remaining way version-shaped --since text could slide past the guard:
# a name that resolves to NOTHING at all (a typo, a tag never fetched). Only
# `--since auto` may honestly find no previous release (E7 below pins that
# skip for a repo with no tags); an EXPLICIT --since that resolves to nothing
# is bad input and must be REJECTED (exit 1) — not printed as "removal guard
# skipped" with exit 0, which reads as a pass for a guard that never ran.
bash "$RM" check-release --since v0.0.1 --root "$E17B" > "$TMP/e17c.out" 2>&1
assert "an EXPLICIT --since naming a ref that does not exist at all (v0.0.1) is rejected (exit 1) with a precise reason — never silently 'removal guard skipped' with exit 0" \
  "[ $? -eq 1 ] && grep -q \"since 'v0.0.1' does not resolve to any commit\" '$TMP/e17c.out' && ! grep -q 'removal guard skipped' '$TMP/e17c.out'"

echo ""
echo "E. finding 2/3: an explicit --since AT or ABOVE the release being checked is rejected"
echo "   (it would prove every content row against its own post-fix content — finding 2, by hand)"
# Three tags: v9.0.0 (the true prior state), and v9.0.1 + v9.5.0 both at the
# post-fix HEAD. --since v9.0.1 (the release under check) and --since v9.5.0
# (after it) must each be refused with a precise reason — not accepted and
# then surfaced as a misleading "pattern does not reproduce the claimed prior
# state" — while --since v9.0.0 is accepted and the row proven.
E18="$TMP/e-since-not-below"
mkdir -p "$E18/.logic-loom/config" "$E18/.logic-loom/lib"
git init -q "$E18"
cp "$LIB" "$E18/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.1" > "$E18/.logic-loom/config/architecture.conf"
: > "$E18/.logic-loom/config/release-migrations.conf"
echo "no foo here" > "$E18/u.md"
( cd "$E18" && git add -A >/dev/null && git commit -q -m "commit 1: u.md pre-fix" )
git -C "$E18" update-ref refs/tags/v9.0.0 HEAD
echo "content | u.md | absent | pattern:fixed-marker | PROPOSE | - | v9.0.1 | proposal: a; why: b" > "$E18/.logic-loom/config/release-migrations.conf"
echo "fixed-marker now present" > "$E18/u.md"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E18/CHANGELOG.md"
( cd "$E18" && git add -A >/dev/null && git commit -q -m "commit 2: registry row + u.md fixed" )
git -C "$E18" update-ref refs/tags/v9.0.1 HEAD
git -C "$E18" update-ref refs/tags/v9.5.0 HEAD
for since_bad in v9.0.1 v9.5.0; do
  bash "$RM" check-release --since "$since_bad" --root "$E18" > "$TMP/e18-$since_bad.out" 2>&1
  assert "--since $since_bad while checking v9.0.1: rejected with a precise reason (exit 1), the guard body never runs, and NO false 'does not reproduce the claimed prior state' line" \
    "[ $? -eq 1 ] && grep -q \"since '$since_bad' is not BELOW the release being checked (v9.0.1)\" '$TMP/e18-$since_bad.out' && ! grep -q 'previous release:' '$TMP/e18-$since_bad.out' && ! grep -q 'does not reproduce the claimed prior state' '$TMP/e18-$since_bad.out'"
done
bash "$RM" check-release --since v9.0.0 --root "$E18" > "$TMP/e18-ok.out" 2>&1
assert "…and --since v9.0.0 (strictly below) is accepted: exit 0, guard ran against v9.0.0, row proven" \
  "[ $? -eq 0 ] && grep -q 'previous release: v9.0.0' '$TMP/e18-ok.out' && ! grep -q 'does not reproduce' '$TMP/e18-ok.out'"

echo ""
echo "E. removal guard — throwaway repo (git tags, real removal)"

E6="$TMP/e-removal"
mkdir -p "$E6/.logic-loom/config" "$E6/.logic-loom/lib" "$E6/plugins/sdd-foo"
git init -q "$E6"
echo "FRAMEWORK_VERSION=9.0.1" > "$E6/.logic-loom/config/architecture.conf"
cp "$LIB" "$E6/.logic-loom/lib/release-migrations.sh"
: > "$E6/.logic-loom/config/release-migrations.conf"
{ echo "## [9.0.1]"; echo "### Migrating from 9.0"; } > "$E6/CHANGELOG.md"
echo "x" > "$E6/plugins/sdd-foo/x.md"
( cd "$E6" && git add -A >/dev/null && git commit -q -m "commit 1: sdd-foo present" )
E6_C1="$(git -C "$E6" rev-parse HEAD)"
git -C "$E6" update-ref refs/tags/v9.0.0 "$E6_C1"
rm -rf "$E6/plugins/sdd-foo"
( cd "$E6" && git add -A >/dev/null && git commit -q -m "commit 2: sdd-foo removed" )

bash "$RM" check-release --since auto --root "$E6" > "$TMP/e6.out" 2>&1
assert "an undeclared removal since v9.0.0 fails the guard" \
  "[ $? -eq 1 ] && grep -q 'removed since v9.0.0 without a registry row: plugins/sdd-foo' '$TMP/e6.out'"

echo "plugin | sdd-foo | removed | none | REMOVE | v9.0.0 | v9.0.1 | x" > "$E6/.logic-loom/config/release-migrations.conf"
bash "$RM" check-release --since auto --root "$E6" > "$TMP/e6b.out" 2>&1
assert "with the registry row added: exit 0, names 'previous release: v9.0.0'" \
  "[ $? -eq 0 ] && grep -q 'previous release: v9.0.0' '$TMP/e6b.out'"
assert "…and the declared removal + structure line" \
  "grep -q 'removals since v9.0.0: plugins/sdd-foo (declared)' '$TMP/e6b.out' && grep -q 'structure verified' '$TMP/e6b.out'"

echo "none | - | none | none | - | - | v9.0.1 | nothing" > "$E6/.logic-loom/config/release-migrations.conf"
bash "$RM" check-release --since auto --root "$E6" > "$TMP/e6c.out" 2>&1
assert "a none row for v9.0.1 while sdd-foo was removed since v9.0.0: exit 1, contradiction" \
  "[ $? -eq 1 ] && grep -qi 'contradiction' '$TMP/e6c.out'"

echo "plugin | sdd-foo | removed | none | REMOVE | v9.0.0 | v9.0.1 | x" > "$E6/.logic-loom/config/release-migrations.conf"
bash "$RM" check-release --since v9.0.0 --root "$E6" > "$TMP/e6d.out" 2>&1
assert "explicit --since v9.0.0 behaves the same as --since auto" \
  "[ $? -eq 0 ] && grep -q 'previous release: v9.0.0' '$TMP/e6d.out'"

# finding 5b (reviewer: reproduced as REAL, then fixed): the guard matched a
# row on (kind, name) alone. Registry lint's one-row-per-name rule does not
# help here — the ONE row can simply carry the wrong release. An item present
# at the previous tag and gone now was removed in (prev, version]; a row dated
# outside that window (a FUTURE pre-declaration, or a STALE row claiming an
# earlier release already lacked it) does not declare THIS release's removal.
echo "plugin | sdd-foo | removed | none | REMOVE | v9.0.0 | v9.9.0 | pre-declared for a future release" > "$E6/.logic-loom/config/release-migrations.conf"
bash "$RM" check-release --since auto --root "$E6" > "$TMP/e6e.out" 2>&1
assert "5b: the only row for sdd-foo is dated v9.9.0 (future) while it was removed in v9.0.1: exit 1, names the window and the row's release" \
  "[ $? -eq 1 ] && grep -q 'removed since v9.0.0 but its registry row dates the removal outside (v9.0.0, v9.0.1]: plugins/sdd-foo (row says v9.9.0)' '$TMP/e6e.out'"
echo "plugin | sdd-foo | removed | none | REMOVE | v8.0.0 | v8.5.0 | stale: claims v8.5.0 lacked it, but v9.0.0 still had it" > "$E6/.logic-loom/config/release-migrations.conf"
bash "$RM" check-release --since auto --root "$E6" > "$TMP/e6f.out" 2>&1
assert "5b: …dated v8.5.0 (stale, not after the v9.0.0 tree that still had it): exit 1, same precise message" \
  "[ $? -eq 1 ] && grep -q 'plugins/sdd-foo (row says v8.5.0)' '$TMP/e6f.out'"
echo "plugin | sdd-foo | removed | none | REMOVE | v9.0.0 | v9.0.1 | x" > "$E6/.logic-loom/config/release-migrations.conf"
bash "$RM" check-release --since auto --root "$E6" > "$TMP/e6g.out" 2>&1
assert "5b: …and the correctly dated v9.0.1 row still passes (window is (prev, version], inclusive of version)" \
  "[ $? -eq 0 ] && grep -q 'removals since v9.0.0: plugins/sdd-foo (declared)' '$TMP/e6g.out'"
echo "none | - | none | none | - | - | v9.0.1 | nothing" > "$E6/.logic-loom/config/release-migrations.conf"
echo "plugin | sdd-foo | removed | none | REMOVE | v9.0.0 | v9.9.0 | future" >> "$E6/.logic-loom/config/release-migrations.conf"
bash "$RM" check-release --since auto --root "$E6" > "$TMP/e6h.out" 2>&1
assert "5b: a misdated row still counts as a removal against a v9.0.1 none row (contradiction reported, exit 1)" \
  "[ $? -eq 1 ] && grep -qi 'contradiction' '$TMP/e6h.out'"
echo "plugin | sdd-foo | removed | none | REMOVE | v9.0.0 | v9.0.1 | x" > "$E6/.logic-loom/config/release-migrations.conf"

E7="$TMP/e-notags"
mkdir -p "$E7/.logic-loom/config" "$E7/.logic-loom/lib"
git init -q "$E7"
echo "FRAMEWORK_VERSION=9.0.1" > "$E7/.logic-loom/config/architecture.conf"
cp "$LIB" "$E7/.logic-loom/lib/release-migrations.sh"
echo "plugin | sdd-foo | removed | none | REMOVE | v9.0.0 | v9.0.1 | x" > "$E7/.logic-loom/config/release-migrations.conf"
( cd "$E7" && git add -A >/dev/null && git commit -q -m init )
bash "$RM" check-release --since auto --root "$E7" > "$TMP/e7.out" 2>&1
assert "a repo with no tags: 'removal guard skipped', exit unaffected by the guard itself" \
  "grep -q 'removal guard skipped' '$TMP/e7.out'"

# ═══════════════════════════════════════════════════════════════════════════
# SECTION D/E addendum — reviewer round 1 (post round-5 builder). Every
# block below was first reproduced as a live defect against the round's
# starting tree, then closed; each carries the reproduction inline.
# Shared fixture: a plugin row with a genuine sync-ref baseline (same shape
# as mk_r4_fixture), plus one command unit so the converter has real work.
# ═══════════════════════════════════════════════════════════════════════════
mk_rv1_fixture() {  # $1 = dir, $2 = plugin name, $3 = registry row (default: a native row for $2)
  local d="$1" pl="$2" row="${3:-}"
  [ -n "$row" ] || row="plugin | $pl | native | native:/workflow | REMOVE | v4.0.0 | v6.2.0 | reviewer round-1 fixture"
  mkdir -p "$d/.logic-loom/config" "$d/.logic-loom/lib" "$d/plugins/$pl/skills/$pl" "$d/plugins/$pl/commands"
  echo "FRAMEWORK_VERSION=7.0.0" > "$d/.logic-loom/config/architecture.conf"
  cp "$LIB" "$d/.logic-loom/lib/release-migrations.sh"
  printf '%s\n' "$row" > "$d/.logic-loom/config/release-migrations.conf"
  printf -- '---\nname: %s\ndescription: reviewer round-1 fixture\n---\n\nBody.\n' "$pl" > "$d/plugins/$pl/skills/$pl/SKILL.md"
  printf -- '---\ndescription: rv1 cmd\n---\n\nDo the thing.\n' > "$d/plugins/$pl/commands/$pl-cmd.md"
  git init -q "$d"
  ( cd "$d" && git add -A >/dev/null && git commit -q -m "A" )
  printf '%s\n' "$(git -C "$d" rev-parse HEAD)" > "$d/.sdd-sync-ref"
  ( cd "$d" && git add -A >/dev/null && git commit -q -m "stamp sync-ref" )
  git -C "$d" update-ref refs/loom-upstream/main "$(git -C "$d" rev-parse HEAD)"
}

echo ""
echo "D. reviewer round 1: a 'converted =' decision never yields REMOVE while ANY file under plugins/<p> was left behind"
# Reproduction on the starting tree: plugins/sdd-rv1a/commands/helper.sh is
# a file no unit converter ever maps (COMMAND_UNITS is `commands/*.md` only,
# and commands/ is skipped by convert_hooks_and_support). convert --apply
# correctly said "DO NOT delete … not carried over: helper.sh" (finding 2)
# — and still recorded `converted = sdd-rv1a` for the units it did convert.
# The very next scan read the decision alone: decision commit found, no
# tracked diff, no untracked file, all-SKIP re-render -> "unchanged" ->
# REMOVE `git rm -r 'plugins/sdd-rv1a'` over helper.sh, bytes never carried
# into .claude/ and not provably LogicLoom's. plan printed the git rm.
RV1A="$TMP/rv1-incomplete"
mk_rv1_fixture "$RV1A" sdd-rv1a
printf '#!/bin/sh\necho customer helper\n' > "$RV1A/plugins/sdd-rv1a/commands/helper.sh"
( cd "$RV1A" && git add -A >/dev/null && git commit -q -m "customer helper under commands/" )
bash "$RM" convert sdd-rv1a --apply --root "$RV1A" > "$TMP/rv1a.convert.out" 2>&1
assert "sanity (finding 2, unchanged): convert --apply withholds its own delete step and names commands/helper.sh" \
  "grep -qF 'Next steps: DO NOT delete plugins/sdd-rv1a yet.' '$TMP/rv1a.convert.out' && grep -qF 'plugins/sdd-rv1a/commands/helper.sh' '$TMP/rv1a.convert.out'"
assert "…prints the machine-stable NEGATIVE accounting line" \
  "grep -qxF 'accounted: NOT every file under plugins/sdd-rv1a is carried over by this conversion' '$TMP/rv1a.convert.out'"
assert "…and still records 'converted = sdd-rv1a' for the units that did convert (the decision is real; what it must not imply is REMOVE)" \
  "grep -qxF 'converted = sdd-rv1a' '$RV1A/.logic-loom/config/migration-decisions.conf'"
( cd "$RV1A" && git add -A >/dev/null && git commit -q -m "convert sdd-rv1a (decision committed)" )
bash "$RM" scan --json --root "$RV1A" > "$TMP/rv1a.scan.json" 2>&1
assert "scan: decision=converted, decision COMMITTED, plugin untouched since — but one file was never carried over -> KEEP-AS-IS, remove_command EMPTY, reason names 'NOT every file' and the exact leftover path" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv1a.scan.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv1a\")
assert it[\"decision\"] == \"converted\", it
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert it[\"remove_command\"] == \"\", it
assert \"NOT every file\" in it[\"reason\"], it
assert \"plugins/sdd-rv1a/commands/helper.sh\" in it[\"reason\"], it
'"
assert "…and the decisions briefing agrees (finding-3 consistency): no 'delete it', names the leftover" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv1a.scan.json\"))
dec = next(x for x in d[\"decisions\"] if x[\"name\"] == \"sdd-rv1a\")
assert \"delete it\" not in dec[\"consequence\"], dec
assert \"NOT every file\" in dec[\"consequence\"], dec
assert \"plugins/sdd-rv1a/commands/helper.sh\" in dec[\"consequence\"], dec
'"
bash "$RM" plan sdd-rv1a --root "$RV1A" > "$TMP/rv1a.plan.out" 2>&1
assert "…and plan prints NO git rm line for it (recommended: KEEP-AS-IS)" \
  "! grep -q 'git rm' '$TMP/rv1a.plan.out' && grep -q 'recommended: KEEP-AS-IS' '$TMP/rv1a.plan.out'"

# Positive control + the dry-run wording: the SAME fixture shape with no
# leftover file must still reach REMOVE, so the accounting gate — not some
# unrelated change — is what flipped sdd-rv1a above. Along the way: a
# --dry-run must never print the delete step at all (nothing was written,
# so "once its converted commands/skills work" cannot yet hold — the old
# text told a reader who stopped at dry-run to delete unconverted bytes).
RV1B="$TMP/rv1-complete"
mk_rv1_fixture "$RV1B" sdd-rv1b
bash "$RM" convert sdd-rv1b --dry-run --root "$RV1B" > "$TMP/rv1b.dry.out" 2>&1
assert "dry-run (nothing written): the POSITIVE accounting line is printed…" \
  "grep -qF 'accounted: every file under plugins/sdd-rv1b is carried over' '$TMP/rv1b.dry.out'"
assert "…but NO 'Next steps: delete plugins/…' — it says nothing was written and to --apply first" \
  "! grep -qF 'Next steps: delete plugins/sdd-rv1b' '$TMP/rv1b.dry.out' && grep -qF 'nothing was written (dry-run)' '$TMP/rv1b.dry.out' && grep -qF 'convert sdd-rv1b --apply' '$TMP/rv1b.dry.out'"
bash "$RM" convert sdd-rv1b --apply --root "$RV1B" > "$TMP/rv1b.apply.out" 2>&1
assert "apply, everything accounted for: positive accounting line AND the delete step" \
  "grep -qF 'accounted: every file under plugins/sdd-rv1b is carried over' '$TMP/rv1b.apply.out' && grep -qF 'Next steps: delete plugins/sdd-rv1b once' '$TMP/rv1b.apply.out'"
( cd "$RV1B" && git add -A >/dev/null && git commit -q -m "convert sdd-rv1b" )
bash "$RM" scan --json --root "$RV1B" > "$TMP/rv1b.scan.json" 2>&1
assert "positive control: same shape, no leftover file, decision committed -> REMOVE (the accounting gate is the only difference from sdd-rv1a)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv1b.scan.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv1b\")
assert it[\"decision\"] == \"converted\", it
assert it[\"recommended\"] == \"REMOVE\", it
assert it[\"remove_command\"] == \"git rm -r '\''plugins/sdd-rv1b'\''\", it
'"

echo ""
echo "D. reviewer round 1: symlinks under plugins/<p> are never converted AND never silently dropped from the accounting"
# Reproduction on the starting tree: unconverted_plugin_files used
# `find -type f` (regular files only) and every unit converter walks
# `-type f` too (`find <link-to-dir>` without -L does not descend). Four
# customer symlinks — a root-level link to a directory of shared assets, a
# link to a file inside config/, a link inside the skill dir, and a
# dangling link — were neither converted nor listed, and convert --apply
# printed "Next steps: delete plugins/sdd-rv1c"; `git rm -r` would then
# remove four link entries this tool never created or carried over.
RV1C="$TMP/rv1-symlinks"
mk_rv1_fixture "$RV1C" sdd-rv1c
RV1C_OUT="$TMP/rv1c-outside"
mkdir -p "$RV1C_OUT/shared"
echo "customer shared asset" > "$RV1C_OUT/shared/a.txt"
echo "customer secret" > "$RV1C_OUT/secret.txt"
ln -s "$RV1C_OUT/shared" "$RV1C/plugins/sdd-rv1c/assets"
mkdir -p "$RV1C/plugins/sdd-rv1c/config"
ln -s "$RV1C_OUT/secret.txt" "$RV1C/plugins/sdd-rv1c/config/link.txt"
ln -s "$RV1C_OUT/secret.txt" "$RV1C/plugins/sdd-rv1c/skills/sdd-rv1c/linked.md"
ln -s "nowhere-dangling" "$RV1C/plugins/sdd-rv1c/dangling"
bash "$RM" convert sdd-rv1c --apply --root "$RV1C" > "$TMP/rv1c.convert.out" 2>&1
assert "convert --apply with four symlinks under the plugin: the delete step is WITHHELD" \
  "! grep -qF 'Next steps: delete plugins/sdd-rv1c' '$TMP/rv1c.convert.out' && grep -qF 'Next steps: DO NOT delete plugins/sdd-rv1c yet.' '$TMP/rv1c.convert.out'"
assert "…and every one of the four symlinks is named under 'Not carried over' (root link-to-dir, link in config/, link in the skill dir, dangling link)" \
  "grep -qF -- '- plugins/sdd-rv1c/assets' '$TMP/rv1c.convert.out' \
   && grep -qF -- '- plugins/sdd-rv1c/config/link.txt' '$TMP/rv1c.convert.out' \
   && grep -qF -- '- plugins/sdd-rv1c/skills/sdd-rv1c/linked.md' '$TMP/rv1c.convert.out' \
   && grep -qF -- '- plugins/sdd-rv1c/dangling' '$TMP/rv1c.convert.out'"
assert "…no symlink was converted (nothing named assets/link.txt/linked.md/dangling under .claude/), the real files were" \
  "[ ! -e '$RV1C/.claude/skills/sdd-rv1c/assets' ] && [ ! -e '$RV1C/.claude/skills/sdd-rv1c/config/link.txt' ] \
   && [ ! -e '$RV1C/.claude/skills/sdd-rv1c/linked.md' ] && [ ! -e '$RV1C/.claude/skills/sdd-rv1c/dangling' ] \
   && [ -f '$RV1C/.claude/skills/sdd-rv1c/SKILL.md' ] && [ -f '$RV1C/.claude/skills/sdd-rv1c-cmd/SKILL.md' ]"
assert "…the links and their targets are untouched (still symlinks, same targets; outside files intact)" \
  "[ -L '$RV1C/plugins/sdd-rv1c/assets' ] && [ -L '$RV1C/plugins/sdd-rv1c/config/link.txt' ] && [ -L '$RV1C/plugins/sdd-rv1c/dangling' ] \
   && grep -qF 'customer secret' '$RV1C_OUT/secret.txt' && grep -qF 'customer shared asset' '$RV1C_OUT/shared/a.txt'"
assert "…and CONVERTED.md's Follow-ups say DO NOT delete, naming a symlink" \
  "grep -qF 'DO NOT delete plugins/sdd-rv1c yet' '$RV1C/.claude/skills/sdd-rv1c/CONVERTED.md' && grep -qF 'plugins/sdd-rv1c/config/link.txt' '$RV1C/.claude/skills/sdd-rv1c/CONVERTED.md'"

echo ""
echo "D. round-3 review finding (high, data-loss): a symlink to a FILE at plugin root (LICENSE, say) is never converted"
# Reproduction on the starting tree: [ -d "$srcpath" ] is false for a link
# to a file, so convert_hooks_and_support's else-branch set
# files="$srcpath" — the link path itself, read via cat/copy_target exactly
# like a real file, written under .claude/skills/<p>/, and counted as
# carried over — contradicting the documented "a symlink anywhere under
# plugins/<p> is never converted" contract this same file's round-1 test
# above already pins for a link-to-DIRECTORY. This is the link-to-FILE case
# that check never covered.
RV3A="$TMP/rv3-file-symlink"
mk_rv1_fixture "$RV3A" sdd-rv3a
RV3A_OUT="$TMP/rv3a-outside"
mkdir -p "$RV3A_OUT"
echo "OUTSIDE LICENSE CONTENT" > "$RV3A_OUT/LICENSE"
ln -s "$RV3A_OUT/LICENSE" "$RV3A/plugins/sdd-rv3a/LICENSE"
bash "$RM" convert sdd-rv3a --dry-run --root "$RV3A" > "$TMP/rv3a.dryrun.out" 2>&1
assert "convert --dry-run: LICENSE (a symlink to a file) is never listed as a WRITE" \
  "! grep -q 'WRITE .claude/skills/sdd-rv3a/LICENSE' '$TMP/rv3a.dryrun.out'"
assert "…it is reported under 'Not carried over' and the delete step is withheld" \
  "! grep -qF 'Next steps: delete plugins/sdd-rv3a' '$TMP/rv3a.dryrun.out' \
   && grep -qF 'Next steps: DO NOT delete plugins/sdd-rv3a yet.' '$TMP/rv3a.dryrun.out' \
   && grep -qF -- '- plugins/sdd-rv3a/LICENSE' '$TMP/rv3a.dryrun.out'"
bash "$RM" convert sdd-rv3a --apply --root "$RV3A" > "$TMP/rv3a.apply.out" 2>&1
assert "convert --apply: the symlink's target content was never written under .claude/" \
  "[ ! -e '$RV3A/.claude/skills/sdd-rv3a/LICENSE' ] && ! grep -rq 'OUTSIDE LICENSE CONTENT' '$RV3A/.claude' 2>/dev/null"
assert "…the symlink and the outside file it points at are both untouched" \
  "[ -L '$RV3A/plugins/sdd-rv3a/LICENSE' ] && grep -qF 'OUTSIDE LICENSE CONTENT' '$RV3A_OUT/LICENSE'"

echo ""
echo "D. round-3 review finding (high, data-loss): a symlink named *.md directly under commands/ or agents/ is never converted"
# Reproduction on the starting tree: COMMAND_UNITS/AGENT_UNITS built with
# `find … -name '*.md'` and no -type f, so a symlink named foo.md matched by
# basename exactly like a real command/agent file; convert_command_unit and
# convert_agent_unit both `cat` their source unconditionally, so the link's
# TARGET content was read through and written into
# .claude/skills/<cmd>/SKILL.md or .claude/agents/<agent>.md.
RV3B="$TMP/rv3-cmd-agent-symlink"
mk_rv1_fixture "$RV3B" sdd-rv3b
mkdir -p "$RV3B/plugins/sdd-rv3b/agents"
RV3B_OUT="$TMP/rv3b-outside"
mkdir -p "$RV3B_OUT"
echo "SECRET COMMAND CONTENT FROM OUTSIDE" > "$RV3B_OUT/evilcmd.md"
echo "SECRET AGENT CONTENT FROM OUTSIDE" > "$RV3B_OUT/evilagent.md"
ln -s "$RV3B_OUT/evilcmd.md" "$RV3B/plugins/sdd-rv3b/commands/evilcmd.md"
ln -s "$RV3B_OUT/evilagent.md" "$RV3B/plugins/sdd-rv3b/agents/evilagent.md"
bash "$RM" convert sdd-rv3b --apply --root "$RV3B" > "$TMP/rv3b.apply.out" 2>&1
assert "convert --apply: the symlinked command never produces .claude/skills/evilcmd/SKILL.md" \
  "[ ! -e '$RV3B/.claude/skills/evilcmd/SKILL.md' ]"
assert "…the symlinked agent never produces .claude/agents/evilagent.md" \
  "[ ! -e '$RV3B/.claude/agents/evilagent.md' ]"
assert "…neither symlink's target content ever reached .claude/ (the secret strings appear nowhere under it)" \
  "! grep -rq 'SECRET COMMAND CONTENT FROM OUTSIDE' '$RV3B/.claude' 2>/dev/null && ! grep -rq 'SECRET AGENT CONTENT FROM OUTSIDE' '$RV3B/.claude' 2>/dev/null"
assert "…both are reported under 'Not carried over' and the delete step is withheld" \
  "grep -qF -- '- plugins/sdd-rv3b/commands/evilcmd.md' '$TMP/rv3b.apply.out' \
   && grep -qF -- '- plugins/sdd-rv3b/agents/evilagent.md' '$TMP/rv3b.apply.out' \
   && grep -qF 'Next steps: DO NOT delete plugins/sdd-rv3b yet.' '$TMP/rv3b.apply.out'"
assert "…both symlinks and the outside files they point at are untouched" \
  "[ -L '$RV3B/plugins/sdd-rv3b/commands/evilcmd.md' ] && [ -L '$RV3B/plugins/sdd-rv3b/agents/evilagent.md' ] \
   && grep -qF 'SECRET COMMAND CONTENT FROM OUTSIDE' '$RV3B_OUT/evilcmd.md' \
   && grep -qF 'SECRET AGENT CONTENT FROM OUTSIDE' '$RV3B_OUT/evilagent.md'"

echo ""
echo "D. round-3 review finding (low): CONVERTED.md says, in its own text, that it can go stale"
# render_converted_md now prepends a caveat naming that this record is
# written once and never rewritten -- a human reading it directly after a
# later edit to plugins/<p> should not take an unqualified 'delete' line at
# face value. The LIVE scan/plan decision (tested elsewhere in this file,
# "edited after conversion" fixtures) was never fooled by this staleness;
# this only pins that the on-disk file now says so itself.
RV3C="$TMP/rv3-converted-md-caveat"
mk_rv1_fixture "$RV3C" sdd-rv3c
bash "$RM" convert sdd-rv3c --apply --root "$RV3C" >/dev/null 2>&1
RV3C_CONVERTED="$RV3C/.claude/skills/sdd-rv3c/CONVERTED.md"
assert "CONVERTED.md exists" "[ -f '$RV3C_CONVERTED' ]"
assert "CONVERTED.md states it is written once and never rewritten" \
  "grep -qF 'written once, at conversion time, and never rewritten' '$RV3C_CONVERTED'"
assert "…and points at scan --json (or plan) for the current recommendation" \
  "grep -qF 'scan --json' '$RV3C_CONVERTED'"

echo ""
echo "D. round-3 REVIEWER finding (high, data-loss): a symlinked .claude-plugin/plugin.json (or a symlinked .claude-plugin/) is never converted"
# Reproduction on the starting tree: `-f` follows a symlink, so
# .claude-plugin/plugin.json -> <outside file> was copied (cp -p follows it
# too) into plugin.json.orig, mapped, counted as accounted, "delete
# plugins/<p>" printed and `converted =` recorded — finding 1's exact class,
# on the one plugin-root entry finding 1's generic loop deliberately skips
# by name. A symlinked .claude-plugin/ directory read through the same -f.
RV3D="$TMP/rv3-manifest-symlink"
mk_rv1_fixture "$RV3D" sdd-rv3d
mkdir -p "$RV3D/plugins/sdd-rv3d/.claude-plugin"
RV3D_OUT="$TMP/rv3d-outside"; mkdir -p "$RV3D_OUT"
echo '{"name":"OUTSIDE MANIFEST"}' > "$RV3D_OUT/plugin.json"
ln -s "$RV3D_OUT/plugin.json" "$RV3D/plugins/sdd-rv3d/.claude-plugin/plugin.json"
bash "$RM" convert sdd-rv3d --dry-run --root "$RV3D" > "$TMP/rv3d.dryrun.out" 2>&1
assert "convert --dry-run: a symlinked manifest is never listed as a WRITE of plugin.json.orig" \
  "! grep -q 'WRITE .claude/skills/sdd-rv3d/plugin.json.orig' '$TMP/rv3d.dryrun.out'"
bash "$RM" convert sdd-rv3d --apply --root "$RV3D" > "$TMP/rv3d.apply.out" 2>&1
assert "convert --apply: the outside manifest bytes never land under .claude/" \
  "[ ! -e '$RV3D/.claude/skills/sdd-rv3d/plugin.json.orig' ] && ! grep -rq 'OUTSIDE MANIFEST' '$RV3D/.claude' 2>/dev/null"
assert "…the link is named under 'Not carried over' and the delete step is withheld" \
  "grep -qF -- '- plugins/sdd-rv3d/.claude-plugin/plugin.json' '$TMP/rv3d.apply.out' \
   && grep -qF 'Next steps: DO NOT delete plugins/sdd-rv3d yet.' '$TMP/rv3d.apply.out'"
assert "…the symlink and the outside file it points at are untouched" \
  "[ -L '$RV3D/plugins/sdd-rv3d/.claude-plugin/plugin.json' ] && grep -qF 'OUTSIDE MANIFEST' '$RV3D_OUT/plugin.json'"
# `converted = sdd-rv3d` IS still recorded (deliberate, pre-existing: the
# decision records the units that did convert; the scan's `incomplete:`
# gate is what withholds REMOVE) — so prove that gate end to end here.
( cd "$RV3D" && git add -A >/dev/null && git commit -q -m "conversion with a symlinked manifest" )
bash "$RM" scan --json --root "$RV3D" > "$TMP/rv3d.scan.json" 2>&1
assert "…and after committing the conversion, scan says KEEP-AS-IS naming the symlinked manifest as not carried over — never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv3d.scan.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv3d\")
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert it[\"remove_command\"] == \"\", it
assert \"plugins/sdd-rv3d/.claude-plugin/plugin.json\" in it[\"reason\"], it
'"
RV3E="$TMP/rv3-manifest-dir-symlink"
mk_rv1_fixture "$RV3E" sdd-rv3e
RV3E_OUT="$TMP/rv3e-outside"; mkdir -p "$RV3E_OUT"
echo '{"name":"OUTSIDE MANIFEST DIR"}' > "$RV3E_OUT/plugin.json"
ln -s "$RV3E_OUT" "$RV3E/plugins/sdd-rv3e/.claude-plugin"
bash "$RM" convert sdd-rv3e --apply --root "$RV3E" > "$TMP/rv3e.apply.out" 2>&1
assert "a symlinked .claude-plugin/ directory: nothing behind it lands under .claude/, the link is named, the delete step is withheld" \
  "[ ! -e '$RV3E/.claude/skills/sdd-rv3e/plugin.json.orig' ] && ! grep -rq 'OUTSIDE MANIFEST DIR' '$RV3E/.claude' 2>/dev/null \
   && grep -qF -- '- plugins/sdd-rv3e/.claude-plugin' '$TMP/rv3e.apply.out' \
   && grep -qF 'Next steps: DO NOT delete plugins/sdd-rv3e yet.' '$TMP/rv3e.apply.out'"

echo ""
echo "D. round-3 REVIEWER finding (high, data-loss): plugins/<p> that is ITSELF a symlink is refused up front, never read through"
# Reproduction on the starting tree: `-d` follows the link, and every unit
# converter's `find "$plugin_dir/<sub>"` is a path THROUGH a symlinked
# component (resolved by every tool; only a link given AS the start point
# is left undescended). An outside tree's skills/commands/hooks were all
# rendered into .claude/, CONVERTED.md was written for it and `converted =`
# recorded, under a contract that says a symlink under plugins/ is never
# converted.
RV3F="$TMP/rv3-plugin-dir-symlink"
mkdir -p "$RV3F/.logic-loom/config" "$RV3F/.logic-loom/lib" "$RV3F/plugins"
echo "FRAMEWORK_VERSION=7.0.0" > "$RV3F/.logic-loom/config/architecture.conf"
cp "$LIB" "$RV3F/.logic-loom/lib/release-migrations.sh"
echo "plugin | sdd-rv3f | native | native:/workflow | REMOVE | v4.0.0 | v6.2.0 | rv3f fixture" > "$RV3F/.logic-loom/config/release-migrations.conf"
RV3F_OUT="$TMP/rv3f-outside/sdd-rv3f"
mkdir -p "$RV3F_OUT/skills/sdd-rv3f" "$RV3F_OUT/commands" "$RV3F_OUT/hooks"
printf -- '---\nname: sdd-rv3f\ndescription: OUTSIDE SKILL\n---\nBody.\n' > "$RV3F_OUT/skills/sdd-rv3f/SKILL.md"
printf -- '---\ndescription: OUTSIDE CMD\n---\nbody\n' > "$RV3F_OUT/commands/rv3f-cmd.md"
echo "echo OUTSIDE HOOK" > "$RV3F_OUT/hooks/h.sh"
ln -s "$RV3F_OUT" "$RV3F/plugins/sdd-rv3f"
git init -q "$RV3F"
( cd "$RV3F" && git add -A >/dev/null && git commit -q -m "A" )
bash "$RM" convert sdd-rv3f --apply --root "$RV3F" > "$TMP/rv3f.apply.out" 2>&1; RV3F_RC=$?
assert "convert --apply on a symlinked plugins/<p>: a STOP line naming the symlink, exit 2" \
  "[ $RV3F_RC -eq 2 ] && grep -qF 'STOP plugins/sdd-rv3f: is a symlink' '$TMP/rv3f.apply.out'"
assert "…nothing behind the link reached .claude/ (no OUTSIDE string anywhere under it), no CONVERTED.md" \
  "! grep -rq 'OUTSIDE' '$RV3F/.claude' 2>/dev/null && [ ! -e '$RV3F/.claude/skills/sdd-rv3f/CONVERTED.md' ]"
assert "…the machine-stable NOT-accounted line and DO NOT delete are printed; no 'converted =' recorded" \
  "grep -qF 'accounted: NOT every file under plugins/sdd-rv3f' '$TMP/rv3f.apply.out' \
   && grep -qF 'Next steps: DO NOT delete plugins/sdd-rv3f yet.' '$TMP/rv3f.apply.out' \
   && ! grep -qxF 'converted = sdd-rv3f' '$RV3F/.logic-loom/config/migration-decisions.conf' 2>/dev/null"
assert "…the link and its outside target are untouched" \
  "[ -L '$RV3F/plugins/sdd-rv3f' ] && grep -qF 'OUTSIDE SKILL' '$RV3F_OUT/skills/sdd-rv3f/SKILL.md'"
# A symlinked unit directory (commands/): explicit now, not a find quirk.
RV3G="$TMP/rv3-commands-dir-symlink"
mk_rv1_fixture "$RV3G" sdd-rv3g
rm -rf "$RV3G/plugins/sdd-rv3g/commands"
RV3G_OUT="$TMP/rv3g-outside"; mkdir -p "$RV3G_OUT"
printf -- '---\ndescription: OUTSIDE CMD\n---\nbody\n' > "$RV3G_OUT/x.md"
ln -s "$RV3G_OUT" "$RV3G/plugins/sdd-rv3g/commands"
bash "$RM" convert sdd-rv3g --apply --root "$RV3G" > "$TMP/rv3g.apply.out" 2>&1
assert "a symlinked commands/ directory: no unit is converted through it, the link is named, the delete step is withheld" \
  "[ ! -e '$RV3G/.claude/skills/x/SKILL.md' ] && ! grep -rq 'OUTSIDE CMD' '$RV3G/.claude' 2>/dev/null \
   && grep -qF -- '- plugins/sdd-rv3g/commands' '$TMP/rv3g.apply.out' \
   && grep -qF 'Next steps: DO NOT delete plugins/sdd-rv3g yet.' '$TMP/rv3g.apply.out'"

echo ""
echo "D. round-3 REVIEWER finding (high, data-loss): a skip-worktree / assume-unchanged local edit never reads as pristine"
# Reproduction on the starting tree: `git diff` trusts the index for an
# entry flagged skip-worktree (tag S in ls-files -v) or assume-unchanged
# (a lowercase tag) and never stats the working tree for it, so a local
# edit to a tracked plugin file was invisible to every "unchanged since
# <commit>" test: scan said REMOVE/pristine and plan printed the removal
# command. With assume-unchanged, RUNNING that printed command deletes the
# edited file outright (git rm re-checks nothing it was told not to look
# at) — probed on a scratch repo, git 2.54.
for rv3_flag in --skip-worktree --assume-unchanged; do
  RV3H="$TMP/rv3-index-flag$rv3_flag"
  mk_rv1_fixture "$RV3H" sdd-rv3h
  bash "$RM" scan --json --root "$RV3H" > "$TMP/rv3h-clean$rv3_flag.json" 2>&1
  assert "control ($rv3_flag fixture, before the flag): pristine plugins/sdd-rv3h -> REMOVE" \
    "python3 -c '
import json
d = json.load(open(\"$TMP/rv3h-clean$rv3_flag.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv3h\")
assert it[\"state\"] == \"pristine\" and it[\"recommended\"] == \"REMOVE\", it
'"
  git -C "$RV3H" update-index $rv3_flag plugins/sdd-rv3h/commands/sdd-rv3h-cmd.md
  echo "CUSTOMER LOCAL EDIT" >> "$RV3H/plugins/sdd-rv3h/commands/sdd-rv3h-cmd.md"
  assert "sanity ($rv3_flag): git diff and git status are both blind to the edit (the old gate saw nothing)" \
    "git -C '$RV3H' diff --quiet HEAD -- plugins/sdd-rv3h && [ -z \"\$(git -C '$RV3H' status --porcelain -- plugins/sdd-rv3h)\" ]"
  bash "$RM" scan --json --root "$RV3H" > "$TMP/rv3h$rv3_flag.json" 2>&1
  assert "$rv3_flag edit: state customized, never REMOVE, no remove_command, the flagged file listed under changed" \
    "python3 -c '
import json
d = json.load(open(\"$TMP/rv3h$rv3_flag.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv3h\")
assert it[\"state\"] == \"customized\", it
assert it[\"recommended\"] != \"REMOVE\", it
assert it[\"remove_command\"] == \"\", it
assert \"plugins/sdd-rv3h/commands/sdd-rv3h-cmd.md\" in it[\"changed_files\"], it
'"
  bash "$RM" plan sdd-rv3h --root "$RV3H" > "$TMP/rv3h$rv3_flag.plan" 2>&1
  assert "$rv3_flag edit: plan prints no removal command for plugins/sdd-rv3h" \
    "! grep -qF \"rm -r 'plugins/sdd-rv3h'\" '$TMP/rv3h$rv3_flag.plan'"
done
# The converted path: the same flag after the decision commit is "changed"
# (previously only the re-render gate happened to catch it, as
# render-stale; now the status names the cause directly).
RV3I="$TMP/rv3-index-flag-converted"
mk_rv1_fixture "$RV3I" sdd-rv3i
bash "$RM" convert sdd-rv3i --apply --root "$RV3I" >/dev/null 2>&1
( cd "$RV3I" && git add -A >/dev/null && git commit -q -m "converted" )
git -C "$RV3I" update-index --skip-worktree plugins/sdd-rv3i/commands/sdd-rv3i-cmd.md
echo "CUSTOMER LOCAL EDIT" >> "$RV3I/plugins/sdd-rv3i/commands/sdd-rv3i-cmd.md"
bash "$RM" scan --json --root "$RV3I" > "$TMP/rv3i.json" 2>&1
assert "converted plugin + a skip-worktree edit after the decision commit: KEEP-AS-IS, the reason names the index flag, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv3i.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv3i\")
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert it[\"remove_command\"] == \"\", it
assert \"skip-worktree\" in it[\"reason\"], it
'"

echo ""
echo "D. reviewer round 1: convert never writes THROUGH a symlink at a target (dangling links pass every -e guard)"
# Reproduction on the starting tree: `.claude/skills/sdd-rv1e/SKILL.md` is
# a DANGLING symlink to a path outside the repository. Every "target already
# exists" guard is `-e`/`-f`, false for a dangling link, so write_text_target
# ran `> target`, which follows the link — the converted SKILL.md landed at
# <outside>/victim.md, a path this tool has no business creating.
RV1E="$TMP/rv1-dangling-target"
mk_rv1_fixture "$RV1E" sdd-rv1e
RV1E_OUT="$TMP/rv1e-outside"
mkdir -p "$RV1E_OUT" "$RV1E/.claude/skills/sdd-rv1e"
ln -s "$RV1E_OUT/victim.md" "$RV1E/.claude/skills/sdd-rv1e/SKILL.md"
bash "$RM" convert sdd-rv1e --apply --root "$RV1E" > "$TMP/rv1e.convert.out" 2>&1
RV1E_RC=$?
assert "a symlink at a target: that unit ERRORs ('refusing to write through it'), naming the link; exit 2" \
  "[ $RV1E_RC -eq 2 ] && grep -qF 'ERROR .claude/skills/sdd-rv1e/SKILL.md: is a symlink' '$TMP/rv1e.convert.out' && grep -qF 'refusing to write through it' '$TMP/rv1e.convert.out'"
assert "…nothing was created at the link's target outside the tree" \
  "[ ! -e '$RV1E_OUT/victim.md' ]"
assert "…the symlink itself is untouched (still a symlink, same target — never followed, replaced or removed)" \
  "[ -L '$RV1E/.claude/skills/sdd-rv1e/SKILL.md' ] && [ \"\$(readlink '$RV1E/.claude/skills/sdd-rv1e/SKILL.md')\" = '$RV1E_OUT/victim.md' ]"
assert "…the delete step is withheld and no 'converted =' is recorded (a failed write is a failed conversion)" \
  "! grep -qF 'Next steps: delete plugins/sdd-rv1e' '$TMP/rv1e.convert.out' \
   && { [ ! -f '$RV1E/.logic-loom/config/migration-decisions.conf' ] || ! grep -qxF 'converted = sdd-rv1e' '$RV1E/.logic-loom/config/migration-decisions.conf'; }"

echo ""
echo "D. reviewer round 1: an EMPTY field is a malformed row in the one parser every consumer goes through"
# Reproduction: every consumer reads a row back with IFS=\$'\t' read — and a
# TAB is IFS whitespace, so an EMPTY field does not read as \"\": it is
# collapsed and every later field shifts left. The regression guard below
# is that fact about bash itself, so the parse-time rejection can be seen to
# be necessary rather than decorative.
RV1_SHIFT="$(IFS=$'\t' read -r _k _n _f <<< "$(printf 'plugin\t\tremoved')"; printf '%s|%s|%s' "$_k" "$_n" "$_f")"
assert "regression guard (bash, not the lib): IFS=TAB read collapses an empty field — name reads as 'removed', fate as '' (fields shift)" \
  "[ \"\$RV1_SHIFT\" = 'plugin|removed|' ]"
RV1D="$TMP/rv1-empty-fields"
mk_rv1_fixture "$RV1D" sdd-rv1d
{
  echo "plugin |  | removed | none | REMOVE | v1.0.0 | v2.0.0 | empty plugin name"
  echo "mcp-server |  | removed | none | REMOVE | v1.0.0 | v2.0.0 | empty mcp name"
  echo "path |  | removed | none | REMOVE | v1.0.0 | v2.0.0 | empty path name"
  echo "plugin | sdd-other |  | none | REMOVE | v1.0.0 | v2.0.0 | empty fate"
  echo "plugin | sdd-other2 | removed |  | REMOVE | v1.0.0 | v2.0.0 | empty replacement"
} > "$RV1D/.logic-loom/config/project-migrations.conf"
RV1D_ROWS_RC=0
RV1D_ROWS="$(loom_migration_rows "$RV1D/.logic-loom/config/project-migrations.conf" 2>"$TMP/rv1d.rows.err")" || RV1D_ROWS_RC=$?
assert "loom_migration_rows: every empty-field row is REJECTED (rc 1, zero rows on stdout), each named by field" \
  "[ $RV1D_ROWS_RC -eq 1 ] && [ -z \"\$RV1D_ROWS\" ] \
   && grep -qF 'field 2 (name) must not be empty' '$TMP/rv1d.rows.err' \
   && grep -qF 'field 3 (fate) must not be empty' '$TMP/rv1d.rows.err' \
   && grep -qF 'field 4 (replacement) must not be empty' '$TMP/rv1d.rows.err'"
bash "$RM" scan --json --root "$RV1D" > "$TMP/rv1d.scan.json" 2>"$TMP/rv1d.scan.err"
assert "scan on that unlinted project registry: the ONLY item is the genuine upstream row — nothing for 'plugins/', 'plugins/removed', 'mcp-servers/' or '' (no shifted row ever reaches emit_deprecation_item)" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv1d.scan.json\"))
paths = [i[\"path\"] for i in d[\"items\"]]
assert paths == [\"plugins/sdd-rv1d\"], paths
'"
assert "lint on it exits non-zero and reports the empty name as a parse error" \
  "! bash '$RM' lint --root '$RV1D' >'$TMP/rv1d.lint.out' 2>&1; grep -qF 'field 2 (name) must not be empty' '$TMP/rv1d.lint.out'"
mk_reg "none | - | none | none | - | - | v9.9.9 | a none row uses '-' for name/default/first_shipped, never an empty field" "rv1-none-dash.conf"
assert "positive control: a none row spelled with '-' (the documented shape) still parses and lints clean" \
  "loom_migration_rows '$TMP/rv1-none-dash.conf' >/dev/null 2>&1 && bash '$RM' lint --root '$ROOT' --registry '$TMP/rv1-none-dash.conf' >/dev/null 2>&1"

echo ""
echo "D. round-5 finding 4: a field containing a literal TAB byte is a malformed row in the one parser every consumer goes through"
# Reproduction: loom_migration_rows/loom_deprecation_rows re-serialize every
# field TAB-joined (printf '%s\t%s\t...'), and every consumer re-splits with
# IFS=\$'\t' read. A field that itself CONTAINS a tab produces one extra tab
# boundary on that line — read's positional split then shifts every field
# AFTER it left by one column, the same corruption class as an EMPTY field
# (the reviewer round 1 block just above), just triggered from inside a
# field instead of between two.
RV5_TAB_SHIFT="$(IFS=$'\t' read -r _k _n _f _r _d <<< "$(printf 'plugin\tgood-name\tevil-flag\tremoved\tnone')"; printf '%s|%s|%s|%s|%s' "$_k" "$_n" "$_f" "$_r" "$_d")"
assert "regression guard (bash, not the lib): an embedded tab inside what SHOULD be one field ('good-name<TAB>evil-flag') reads as two separate fields — everything after it shifts one column" \
  "[ \"\$RV5_TAB_SHIFT\" = 'plugin|good-name|evil-flag|removed|none' ]"
RV5D="$TMP/rv5-embedded-tab"
mk_rv1_fixture "$RV5D" sdd-rv5d
{
  printf 'plugin | good-name%sevil-flag | removed | none | REMOVE | v1.0.0 | v2.0.0 | embedded tab in name\n' "$(printf '\t')"
  printf 'path | docs/ok.md | removed | none%stail | REMOVE | v1.0.0 | v2.0.0 | embedded tab in replacement\n' "$(printf '\t')"
} > "$RV5D/.logic-loom/config/project-migrations.conf"
RV5D_ROWS_RC=0
RV5D_ROWS="$(loom_migration_rows "$RV5D/.logic-loom/config/project-migrations.conf" 2>"$TMP/rv5d.rows.err")" || RV5D_ROWS_RC=$?
assert "loom_migration_rows: every embedded-tab row is REJECTED (rc 1, zero rows on stdout), each named by the field that holds the tab" \
  "[ $RV5D_ROWS_RC -eq 1 ] && [ -z \"\$RV5D_ROWS\" ] \
   && grep -qF 'field 2 (name) must not contain a literal tab' '$TMP/rv5d.rows.err' \
   && grep -qF 'field 4 (replacement) must not contain a literal tab' '$TMP/rv5d.rows.err'"
bash "$RM" scan --json --root "$RV5D" > "$TMP/rv5d.scan.json" 2>"$TMP/rv5d.scan.err"
assert "scan on that unlinted project registry: the ONLY item is the genuine upstream row — no item for a truncated/shifted name ('good-name', 'docs/ok.md' with a corrupted fate/replacement) ever reaches emit_deprecation_item" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv5d.scan.json\"))
paths = [i[\"path\"] for i in d[\"items\"]]
assert paths == [\"plugins/sdd-rv5d\"], paths
'"
assert "lint on it exits non-zero and reports the embedded tab as a parse error, naming the field" \
  "! bash '$RM' lint --root '$RV5D' >'$TMP/rv5d.lint.out' 2>&1; grep -qF 'field 2 (name) must not contain a literal tab' '$TMP/rv5d.lint.out'"
RV5_TABNOTE="plugin | sdd-rv5-note | removed | none | REMOVE | v1.0.0 | v2.0.0 | note with$(printf '\t')embedded tab"
printf '%s\n' "$RV5_TABNOTE" > "$TMP/rv5-tabnote.conf"
RV5_TABNOTE_RC=0
loom_migration_rows "$TMP/rv5-tabnote.conf" >/dev/null 2>"$TMP/rv5-tabnote.err" || RV5_TABNOTE_RC=$?
assert "…the note field (f8, the last column) is rejected too, even though a tab there cannot shift anything — one honest invariant, no field this parser hands out ever holds the byte every consumer re-splits on" \
  "[ $RV5_TABNOTE_RC -eq 1 ] && grep -qF 'field 8 (note) must not contain a literal tab' '$TMP/rv5-tabnote.err'"
mk_reg "plugin | sdd-rv5-clean | removed | none | REMOVE | v1.0.0 | v2.0.0 | an ordinary row with no embedded tab anywhere" "rv5-clean.conf"
assert "positive control: an ordinary row with no embedded tab still parses and lints clean" \
  "loom_migration_rows '$TMP/rv5-clean.conf' >/dev/null 2>&1 && bash '$RM' lint --root '$ROOT' --registry '$TMP/rv5-clean.conf' >/dev/null 2>&1"

echo ""
echo "D. reviewer round 1: an option-shaped name ('-f') is rejected at lint AND at use — quoting cannot make git read it as a path"
if command -v _loom_lint_name_shell_safe >/dev/null 2>&1; then
  assert "_loom_lint_name_shell_safe: rejects a path name starting with '-' ('-f')" "! _loom_lint_name_shell_safe path '-f'"
  assert "_loom_lint_name_shell_safe: rejects a plugin name starting with '-' ('--cached')" "! _loom_lint_name_shell_safe plugin '--cached'"
  assert "_loom_lint_name_shell_safe: still accepts a '-' that is not leading ('docs/a-b.md')" "_loom_lint_name_shell_safe path 'docs/a-b.md'"
  assert "_loom_lint_name_shell_safe: a none row's '-' name is a different kind and stays exempt" "_loom_lint_name_shell_safe none '-'"
else
  skip "_loom_lint_name_shell_safe leading-dash checks" "function not defined"
fi
RV1F_LINT="$TMP/rv1-dash-lint"
mk_temp_root "$RV1F_LINT" "7.0.0" "path | -f | removed | none | REMOVE | v1.0.0 | v2.0.0 | option-shaped name"
assert "lint: a path row named '-f' fails, naming the rule" \
  "! bash '$RM' lint --root '$RV1F_LINT' >'$TMP/rv1f.lint.out' 2>&1; grep -qF \"must not start with '-'\" '$TMP/rv1f.lint.out'"
RV1F_MV="$TMP/rv1-dash-move-lint"
mk_temp_root "$RV1F_MV" "7.0.0" "path | old/thing.md | renamed | path:-x | MOVE | v1.0.0 | v2.0.0 | option-shaped replacement"
assert "lint: a MOVE row whose replacement path is '-x' fails too" \
  "! bash '$RM' lint --root '$RV1F_MV' >'$TMP/rv1f.mv.out' 2>&1; grep -qF \"replacement path '-x' must\" '$TMP/rv1f.mv.out'"
# At use: an UNLINTED registry carrying that row, the file present and
# pristine against the sync-ref. Reproduction on the starting tree: lint was
# clean and scan printed remove_command `git rm '-f'` — quoted, and still an
# option to git.
RV1F="$TMP/rv1-dash-at-use"
mk_rv1_fixture "$RV1F" sdd-rv1f "path | -f | removed | none | REMOVE | v1.0.0 | v2.0.0 | option-shaped name, unlinted"
echo "pristine" > "$RV1F/-f"
( cd "$RV1F" && git add -A >/dev/null && git commit -q -m "dash file" )
printf '%s\n' "$(git -C "$RV1F" rev-parse HEAD)" > "$RV1F/.sdd-sync-ref"
( cd "$RV1F" && git add -A >/dev/null && git commit -q -m "stamp" )
git -C "$RV1F" update-ref refs/loom-upstream/main "$(git -C "$RV1F" rev-parse HEAD)"
bash "$RM" scan --json --root "$RV1F" > "$TMP/rv1f.scan.json" 2>&1
assert "at use (unlinted registry, file pristine): the '-f' row is KEEP-AS-IS with an EMPTY remove_command and a reason naming the leading '-'" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv1f.scan.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"-f\")
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert it[\"remove_command\"] == \"\", it
assert \"starts with\" in it[\"reason\"], it
'"
bash "$RM" plan -f --root "$RV1F" > "$TMP/rv1f.plan.out" 2>&1 || true
assert "…and plan prints no git rm for it" "! grep -q 'git rm' '$TMP/rv1f.plan.out'"
# The same at-use guard covers whitespace/metacharacters in the NAME field
# of an unlinted registry (round 5 covered lint, and at-use only for a MOVE
# row's replacement path).
RV1G="$TMP/rv1-space-at-use"
mk_rv1_fixture "$RV1G" sdd-rv1g "path | docs/my notes.md | removed | none | REMOVE | v1.0.0 | v2.0.0 | whitespace in name, unlinted"
mkdir -p "$RV1G/docs"; echo "pristine" > "$RV1G/docs/my notes.md"
( cd "$RV1G" && git add -A >/dev/null && git commit -q -m "space file" )
printf '%s\n' "$(git -C "$RV1G" rev-parse HEAD)" > "$RV1G/.sdd-sync-ref"
( cd "$RV1G" && git add -A >/dev/null && git commit -q -m "stamp" )
git -C "$RV1G" update-ref refs/loom-upstream/main "$(git -C "$RV1G" rev-parse HEAD)"
bash "$RM" scan --json --root "$RV1G" > "$TMP/rv1g.scan.json" 2>&1
assert "at use: a NAME with whitespace in an unlinted registry is refused the same way (KEEP-AS-IS, empty remove_command) — not merely quoted" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv1g.scan.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/my notes.md\")
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert it[\"remove_command\"] == \"\", it
'"

# ═══════════════════════════════════════════════════════════════════════════
# SECTION G — round-2 review (2026-09-19): data-loss note_mapping ordering,
# symlink-parent writes, symlinked proof-tree base, pristine-baseline
# recovery advice, apply_path_rewrites failure handling.
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "G. data-loss finding: a write that genuinely FAILS must never be counted as accounted-for"
# Reproduction: plugins/sdd-g1fail/hooks/ has two files. Before convert
# --apply even runs, .claude/skills/sdd-g1fail/hooks/broken.sh already exists
# as a DANGLING symlink -- `-e` on it is false (so the unit converter takes
# the "write a new file" branch, not the "existing target" branch), but
# write_text_target's own symlink guard refuses it outright, exactly the
# "reviewer round 1 (write-through a symlink)" class this script already
# defends against elsewhere. good.sh has no such obstruction and writes
# cleanly. Before the note_mapping-ordering fix, broken.sh's source path was
# still added to MAP_LIST (note_mapping ran unconditionally before the write
# was attempted), so unconverted_plugin_files saw nothing missing and
# CONVERTED.md's Follow-ups section printed the unconditional delete line
# despite the failure.
G1F="$TMP/g1-write-fails-not-accounted"
mkdir -p "$G1F/plugins/sdd-g1fail/hooks" "$G1F/.logic-loom/config" "$G1F/.logic-loom/lib" "$G1F/.claude/skills/sdd-g1fail/hooks"
git init -q "$G1F"
echo "FRAMEWORK_VERSION=9.0.0" > "$G1F/.logic-loom/config/architecture.conf"
cp "$LIB" "$G1F/.logic-loom/lib/release-migrations.sh"
echo "plugin | sdd-g1fail | native | native:/workflow | REMOVE | v4.0.0 | v6.2.0 | round-2 data-loss repro fixture" \
  > "$G1F/.logic-loom/config/release-migrations.conf"
echo "echo good hook" > "$G1F/plugins/sdd-g1fail/hooks/good.sh"
echo "echo broken hook" > "$G1F/plugins/sdd-g1fail/hooks/broken.sh"
ln -s "/nonexistent/target/for/round-2/g1-test" "$G1F/.claude/skills/sdd-g1fail/hooks/broken.sh"
( cd "$G1F" && git add -A >/dev/null && git commit -q -m init ) >/dev/null 2>&1
G1F_OUT="$(bash "$RM" convert sdd-g1fail --apply --root "$G1F" 2>&1)"
G1F_RC=$?
assert "sanity: the dangling-symlink target really does refuse the write (ERROR line for broken.sh)" \
  "printf '%s\n' \"\$G1F_OUT\" | grep -q 'ERROR .claude/skills/sdd-g1fail/hooks/broken.sh: is a symlink'"
assert "sanity: the OTHER file in the same plugin still writes cleanly (WROTE good.sh)" \
  "printf '%s\n' \"\$G1F_OUT\" | grep -qF 'WROTE .claude/skills/sdd-g1fail/hooks/good.sh'"
assert "convert --apply exits stopped (rc 2) — a real write failure must not look clean" \
  "[ $G1F_RC -eq 2 ]"
assert "terminal output: the NEGATIVE accounting line (this half already worked pre-round-2, via WRITE_FAILED -> stopped)" \
  "printf '%s\n' \"\$G1F_OUT\" | grep -qxF 'accounted: NOT every file under plugins/sdd-g1fail is carried over by this conversion'"
G1F_CONVERTED="$G1F/.claude/skills/sdd-g1fail/CONVERTED.md"
assert "CONVERTED.md was written despite the failure (finalize_convert still ran)" \
  "[ -f '$G1F_CONVERTED' ]"
assert "…and its OWN Follow-ups section withholds the delete recommendation too — the fix under test" \
  "grep -qF 'DO NOT delete plugins/sdd-g1fail yet' '$G1F_CONVERTED'"
assert "…names the file whose write failed as not carried over" \
  "grep -qF 'plugins/sdd-g1fail/hooks/broken.sh' '$G1F_CONVERTED'"
assert "…and CONVERTED.md never prints the unconditional delete line (the bug: it used to, because broken.sh's source was still mapped)" \
  "! grep -qF 'delete plugins/sdd-g1fail once its converted commands/skills work' '$G1F_CONVERTED'"
assert "…while the file that DID write successfully is still listed as converted (good.sh is not collateral damage)" \
  "grep -qF '.claude/skills/sdd-g1fail/hooks/good.sh <- plugins/sdd-g1fail/hooks/good.sh' '$G1F_CONVERTED'"

echo ""
echo "G. low finding: an EMPTY directory under plugins/<p> is invisible to unconverted_plugin_files, so it never withholds the delete recommendation"
G2F="$TMP/g2-empty-dir-accounting"
mkdir -p "$G2F/plugins/sdd-g2empty/hooks" "$G2F/plugins/sdd-g2empty/emptydir" "$G2F/.logic-loom/config" "$G2F/.logic-loom/lib"
git init -q "$G2F"
echo "FRAMEWORK_VERSION=9.0.0" > "$G2F/.logic-loom/config/architecture.conf"
cp "$LIB" "$G2F/.logic-loom/lib/release-migrations.sh"
echo "plugin | sdd-g2empty | native | native:/workflow | REMOVE | v4.0.0 | v6.2.0 | round-2 empty-dir repro fixture" \
  > "$G2F/.logic-loom/config/release-migrations.conf"
echo "echo hook" > "$G2F/plugins/sdd-g2empty/hooks/h.sh"
( cd "$G2F" && git add -A >/dev/null && git commit -q -m init ) >/dev/null 2>&1
assert "sanity: plugins/sdd-g2empty/emptydir really is empty on disk" \
  "[ -z \"\$(find '$G2F/plugins/sdd-g2empty/emptydir' -mindepth 1)\" ]"
G2F_OUT="$(bash "$RM" convert sdd-g2empty --apply --root "$G2F" 2>&1)"
G2F_RC=$?
assert "convert --apply still succeeds (an empty directory is not a write failure)" \
  "[ $G2F_RC -eq 0 ] && printf '%s\n' \"\$G2F_OUT\" | grep -qF 'WROTE .claude/skills/sdd-g2empty/hooks/h.sh'"
assert "…but the empty directory is named — accounting notices it exists" \
  "printf '%s\n' \"\$G2F_OUT\" | grep -q 'plugins/sdd-g2empty/emptydir/ (empty directory'"
assert "…and the delete recommendation is withheld (the bug: it used to fire unconditionally, silent about the empty dir)" \
  "! printf '%s\n' \"\$G2F_OUT\" | grep -qxF 'accounted: every file under plugins/sdd-g2empty is carried over by this conversion (nothing STOPped, no write failed)'"

echo ""
echo "G. high finding: write_text_target/copy_target refuse when a PARENT directory component is a symlink, not only the final target"
UNIT_WRITE_ROOT="$TMP/unit-write-parent-symlink"
mkdir -p "$UNIT_WRITE_ROOT/.claude/skills" "$UNIT_WRITE_ROOT/.logic-loom/lib"
cp "$LIB" "$UNIT_WRITE_ROOT/.logic-loom/lib/release-migrations.sh"
UNIT_WRITE_VICTIM="$TMP/unit-write-parent-victim"
mkdir -p "$UNIT_WRITE_VICTIM"
ln -s "$UNIT_WRITE_VICTIM" "$UNIT_WRITE_ROOT/.claude/skills/evilplugin"
UNIT_WRITE_OUT="$(
  source "$RM" --root "$UNIT_WRITE_ROOT" >/dev/null 2>&1
  WRITE_FAILED="false"
  if write_text_target ".claude/skills/evilplugin/pwned.md" "pwned content"; then
    echo "WRITE_TEXT=succeeded"
  else
    echo "WRITE_TEXT=refused"
  fi
  echo "WRITE_FAILED=$WRITE_FAILED"
  WRITE_FAILED="false"
  echo "some source content" > "$TMP/unit-write-parent-src.txt"
  if copy_target ".claude/skills/evilplugin/pwned2.md" "$TMP/unit-write-parent-src.txt"; then
    echo "COPY_TARGET=succeeded"
  else
    echo "COPY_TARGET=refused"
  fi
  echo "WRITE_FAILED_2=$WRITE_FAILED"
)"
assert "write_text_target refuses when a PARENT directory (not the final target) is a symlink" \
  "printf '%s\n' \"\$UNIT_WRITE_OUT\" | grep -qF 'WRITE_TEXT=refused'"
assert "…and sets WRITE_FAILED=true" \
  "printf '%s\n' \"\$UNIT_WRITE_OUT\" | grep -qF 'WRITE_FAILED=true'"
assert "copy_target refuses the same way" \
  "printf '%s\n' \"\$UNIT_WRITE_OUT\" | grep -qF 'COPY_TARGET=refused'"
assert "…and also sets WRITE_FAILED=true" \
  "printf '%s\n' \"\$UNIT_WRITE_OUT\" | grep -qF 'WRITE_FAILED_2=true'"
assert "…and nothing was ever written OUTSIDE .claude/skills/ through the symlinked parent" \
  "[ ! -e '$UNIT_WRITE_VICTIM/pwned.md' ] && [ ! -e '$UNIT_WRITE_VICTIM/pwned2.md' ]"
# Positive control: a target under a REAL (non-symlinked) parent still writes
# normally — the new check does not over-refuse.
UNIT_WRITE_OK_OUT="$(
  source "$RM" --root "$UNIT_WRITE_ROOT" >/dev/null 2>&1
  WRITE_FAILED="false"
  if write_text_target ".claude/skills/realplugin/ok.md" "fine content"; then
    echo "WRITE_TEXT=succeeded"
  fi
  echo "WRITE_FAILED=$WRITE_FAILED"
)"
assert "control: a target under a genuine (non-symlinked) new directory still writes normally" \
  "printf '%s\n' \"\$UNIT_WRITE_OK_OUT\" | grep -qF 'WRITE_TEXT=succeeded' && printf '%s\n' \"\$UNIT_WRITE_OK_OUT\" | grep -qF 'WRITE_FAILED=false' && [ -f '$UNIT_WRITE_ROOT/.claude/skills/realplugin/ok.md' ]"

echo ""
echo "G. high finding: _loom_rm_safe_to_remove refuses when the BASE directory ITSELF is a symlink, not only an entry under it"
UNIT_BASE_VICTIM="$TMP/unit-base-symlink-victim"
mkdir -p "$UNIT_BASE_VICTIM"
echo "must survive" > "$UNIT_BASE_VICTIM/marker.txt"
UNIT_BASE_OUT="$(
  source "$RM" --root "$UNIT_ROOT" >/dev/null 2>&1
  SYMLINK_BASE="$TMP/unit-symlink-base"
  ln -sfn "$UNIT_BASE_VICTIM" "$SYMLINK_BASE"
  # $d is formed exactly as the real caller (_loom_rm_cleanup) forms it: the
  # base path plus an entry name, as a literal string -- it need not itself
  # be a symlink (marker.txt is a real file inside the victim dir); the base
  # component of the STRING is what was swapped for a symlink.
  CANDIDATE="$SYMLINK_BASE/marker.txt"
  if _loom_rm_safe_to_remove "$CANDIDATE" "$SYMLINK_BASE"; then echo "VIA_SYMLINK_BASE=allowed"; else echo "VIA_SYMLINK_BASE=refused"; fi
)"
assert "a symlinked BASE is refused outright, before any canonicalization can resolve through it" \
  "printf '%s\n' \"\$UNIT_BASE_OUT\" | grep -qF 'VIA_SYMLINK_BASE=refused'"
assert "…and the victim directory the symlinked base pointed at was never touched" \
  "[ -f '$UNIT_BASE_VICTIM/marker.txt' ] && grep -qF 'must survive' '$UNIT_BASE_VICTIM/marker.txt'"

echo ""
echo "G. medium finding: resolve_baseline's 'recoverable:' advice for a pristine receipt-sha256 baseline is quoted and names the right recovery path depending on HEAD-tracking"
FIX_UNTRACKED="$TMP/fixture-receipt-untracked-head"
mkdir -p "$FIX_UNTRACKED/.logic-loom/config" "$FIX_UNTRACKED/.logic-loom/lib" "$FIX_UNTRACKED/docs"
git init -q "$FIX_UNTRACKED"
cp "$LIB" "$FIX_UNTRACKED/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.0" > "$FIX_UNTRACKED/.logic-loom/config/architecture.conf"
echo "path | docs/untracked-note.md | removed | command:/replacement-cmd | REMOVE | v6.0.0 | v9.0.0 | receipt-sha256 baseline on a file never committed at HEAD" \
  > "$FIX_UNTRACKED/.logic-loom/config/release-migrations.conf"
( cd "$FIX_UNTRACKED" && git add -A >/dev/null && git commit -q -m "base, before docs/untracked-note.md exists anywhere" )
FIX_UNTRACKED_BASE_SHA="$(git -C "$FIX_UNTRACKED" rev-parse HEAD)"
printf 'exactly what LogicLoom wrote here (only ever committed upstream)\n' > "$FIX_UNTRACKED/docs/untracked-note.md"
( cd "$FIX_UNTRACKED" && git add -A >/dev/null && git commit -q -m "upstream tip: adds docs/untracked-note.md" )
git -C "$FIX_UNTRACKED" update-ref refs/loom-upstream/main HEAD
# Reset HEAD back to base (the file is no longer tracked there) but restore
# the identical bytes on disk, UNTRACKED — a receipt can name a file this
# repo's HEAD never had (e.g. corroborated purely via upstream history).
git -C "$FIX_UNTRACKED" reset -q --hard "$FIX_UNTRACKED_BASE_SHA"
# docs/ was never tracked at the base commit (it was empty when that commit
# was made — git does not track empty directories), so `reset --hard` can
# remove it along with the file: recreate it explicitly before writing.
mkdir -p "$FIX_UNTRACKED/docs"
printf 'exactly what LogicLoom wrote here (only ever committed upstream)\n' > "$FIX_UNTRACKED/docs/untracked-note.md"
assert "sanity: docs/untracked-note.md is NOT tracked at HEAD in this fixture" \
  "! git -C '$FIX_UNTRACKED' rev-parse --verify -q 'HEAD:docs/untracked-note.md' >/dev/null 2>&1"
UNTRACKED_SHA="$(python3 -c '
import hashlib
print(hashlib.sha256(open("'"$FIX_UNTRACKED"'/docs/untracked-note.md", "rb").read()).hexdigest())
')"
cat > "$FIX_UNTRACKED/.logicloom-adopt-receipt.json" <<JSON
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-01-01T00:00:00.000Z",
      "generator": "logicloom-update-framework@1.0.0",
      "status": "complete",
      "only": [],
      "wrote": [
        { "target": "harness", "path": "docs/untracked-note.md", "kind": "file", "sha256": "$UNTRACKED_SHA" }
      ],
      "skipped": [], "failed": [], "notAttempted": []
    }
  ]
}
JSON
UNTRACKED_PLAN_OUT="$(bash "$RM" plan docs/untracked-note.md --root "$FIX_UNTRACKED" 2>&1)"
assert "receipt-sha256 baseline reaches pristine/REMOVE here too (sanity before checking the advice text)" \
  "printf '%s\n' \"\$UNTRACKED_PLAN_OUT\" | grep -q 'recommended: REMOVE'"
assert "plan's recoverable advice for a file NOT tracked at HEAD says so plainly and warns the checkout command will NOT restore it (never the unqualified positive recommendation)" \
  "printf '%s\n' \"\$UNTRACKED_PLAN_OUT\" | grep -qF \"is not tracked at HEAD\" && printf '%s\n' \"\$UNTRACKED_PLAN_OUT\" | grep -qF 'will NOT restore it' && ! printf '%s\n' \"\$UNTRACKED_PLAN_OUT\" | grep -qF 'restores it'"

# Positive control: a FRESH fixture (never mutated afterward, unlike section
# C's FIX_RECEIPT, which later gets a customer edit appended to it and so is
# no longer pristine by this point in the suite) with docs/tracked-note.md
# committed to HEAD — the ordinary advice, quoted both places, must fire.
FIX_TRACKED="$TMP/fixture-receipt-tracked-head"
mkdir -p "$FIX_TRACKED/.logic-loom/config" "$FIX_TRACKED/.logic-loom/lib" "$FIX_TRACKED/docs"
git init -q "$FIX_TRACKED"
cp "$LIB" "$FIX_TRACKED/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.0" > "$FIX_TRACKED/.logic-loom/config/architecture.conf"
echo "path | docs/tracked-note.md | removed | command:/replacement-cmd | REMOVE | v6.0.0 | v9.0.0 | receipt-sha256 baseline on a file tracked at HEAD" \
  > "$FIX_TRACKED/.logic-loom/config/release-migrations.conf"
printf 'exactly what LogicLoom wrote here (tracked)\n' > "$FIX_TRACKED/docs/tracked-note.md"
TRACKED_SHA="$(python3 -c '
import hashlib
print(hashlib.sha256(open("'"$FIX_TRACKED"'/docs/tracked-note.md", "rb").read()).hexdigest())
')"
cat > "$FIX_TRACKED/.logicloom-adopt-receipt.json" <<JSON
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-01-01T00:00:00.000Z",
      "generator": "logicloom-update-framework@1.0.0",
      "status": "complete",
      "only": [],
      "wrote": [
        { "target": "harness", "path": "docs/tracked-note.md", "kind": "file", "sha256": "$TRACKED_SHA" }
      ],
      "skipped": [], "failed": [], "notAttempted": []
    }
  ]
}
JSON
( cd "$FIX_TRACKED" && git add -A >/dev/null && git commit -q -m "adopted install, docs/tracked-note.md committed" )
git -C "$FIX_TRACKED" update-ref refs/loom-upstream/main HEAD
assert "sanity: docs/tracked-note.md IS tracked at HEAD in this fixture" \
  "git -C '$FIX_TRACKED' rev-parse --verify -q 'HEAD:docs/tracked-note.md' >/dev/null 2>&1"
FIX_TRACKED_PLAN_OUT="$(bash "$RM" plan docs/tracked-note.md --root "$FIX_TRACKED" 2>&1)"
assert "control: a receipt-sha256 baseline that IS tracked at HEAD gets the ordinary, quoted recovery advice" \
  "printf '%s\n' \"\$FIX_TRACKED_PLAN_OUT\" | grep -qF \"git checkout HEAD -- 'docs/tracked-note.md'\" && printf '%s\n' \"\$FIX_TRACKED_PLAN_OUT\" | grep -qF \"git checkout <commit-before-removal> -- 'docs/tracked-note.md'\""

echo ""
echo "G. medium finding: record_converted_decision refuses a symlinked migration-decisions.conf (or a symlinked parent) rather than writing through it"
UNIT_DECISIONS_VICTIM="$TMP/unit-decisions-victim"
mkdir -p "$UNIT_DECISIONS_VICTIM"
UNIT_DECISIONS_OUT="$(
  source "$RM" --root "$UNIT_ROOT" >/dev/null 2>&1
  mkdir -p "$REPO_ROOT/.logic-loom/config-real"
  ln -sfn "$REPO_ROOT/.logic-loom/config-real" "$REPO_ROOT/.logic-loom/config-symlinked"
  DECISIONS_FILE="$REPO_ROOT/.logic-loom/config-symlinked/migration-decisions.conf"
  if record_converted_decision "some-plugin"; then echo "RECORD=succeeded"; else echo "RECORD=refused"; fi
)"
assert "record_converted_decision refuses when its parent directory is a symlink" \
  "printf '%s\n' \"\$UNIT_DECISIONS_OUT\" | grep -qF 'RECORD=refused'"
assert "…and nothing was written through the symlink into the real directory" \
  "[ ! -e '$UNIT_ROOT/.logic-loom/config-real/migration-decisions.conf' ]"

echo ""
echo "G. medium finding: apply_path_rewrites checks mktemp AND the sed pipeline, and falls back to unrewritten content (never empty) on either failure"
UNIT_REWRITE_STDERR="$TMP/unit-rewrite-stderr.out"
UNIT_REWRITE_OUT="$(
  source "$RM" --root "$UNIT_ROOT" >/dev/null 2>&1
  SKILL_UNITS="myskill"; COMMAND_UNITS=""; AGENT_UNITS=""
  WRITE_FAILED="false"
  # Force mktemp to fail deterministically by pointing TMPDIR at a path that
  # cannot hold a new file (a plain file, not a directory).
  BOGUS_TMPDIR="$TMP/unit-rewrite-bogus-tmpdir-is-a-file"
  : > "$BOGUS_TMPDIR"
  # apply_path_rewrites is called via $(...) here, so its own WRITE_FAILED
  # mutation would live only in THAT forked subshell -- check the exit
  # status of the assignment instead, same pattern the real call sites use.
  RESULT="$(TMPDIR="$BOGUS_TMPDIR" apply_path_rewrites 'plugins/myplugin/skills/myskill' myplugin 2>"$UNIT_REWRITE_STDERR")" || WRITE_FAILED="true"
  echo "RESULT=[$RESULT]"
  echo "WRITE_FAILED=$WRITE_FAILED"
)"
UNIT_REWRITE_STDERR_ERRORS="$(grep -c 'ERROR apply_path_rewrites' "$UNIT_REWRITE_STDERR" 2>/dev/null || echo 0)"
assert "a failed mktemp: WRITE_FAILED is set true" \
  "printf '%s\n' \"\$UNIT_REWRITE_OUT\" | grep -qF 'WRITE_FAILED=true'"
assert "…the original content is returned UNREWRITTEN, never empty, so a real write downstream still carries real bytes" \
  "printf '%s\n' \"\$UNIT_REWRITE_OUT\" | grep -qF 'RESULT=[plugins/myplugin/skills/myskill]'"
assert "…and an ERROR line was printed (to stderr, not mixed into the rendered content)" \
  "[ '$UNIT_REWRITE_STDERR_ERRORS' -ge 1 ]"
# Positive control: a normal call (no forced failure) still rewrites and
# leaves WRITE_FAILED alone.
UNIT_REWRITE_OK_OUT="$(
  source "$RM" --root "$UNIT_ROOT" >/dev/null 2>&1
  SKILL_UNITS="myskill"; COMMAND_UNITS=""; AGENT_UNITS=""
  WRITE_FAILED="false"
  RESULT="$(apply_path_rewrites 'see plugins/myplugin/skills/myskill for detail' myplugin)"
  echo "RESULT=[$RESULT]"
  echo "WRITE_FAILED=$WRITE_FAILED"
)"
assert "control: an ordinary call still performs the real rewrite" \
  "printf '%s\n' \"\$UNIT_REWRITE_OK_OUT\" | grep -qF 'RESULT=[see .claude/skills/myskill for detail]'"
assert "…and leaves WRITE_FAILED untouched (false)" \
  "printf '%s\n' \"\$UNIT_REWRITE_OK_OUT\" | grep -qF 'WRITE_FAILED=false'"

echo ""
echo "G. medium finding (regression): apply_path_rewrites' failure actually reaches WRITE_FAILED through the real call sites, not only in isolation"
# apply_path_rewrites is always invoked via \$(...) at every real call site,
# so its own internal WRITE_FAILED="true" mutation lives only in that ONE
# forked subshell and is invisible to the caller -- only the function's
# RETURN CODE survives the fork. Every call site above was fixed to check it
# explicitly (\`|| WRITE_FAILED="true"\`); this proves the fix at the CALL
# SITE level (convert_command_unit -> render_command_skill's own \$(...)
# capture -> apply_path_rewrites), monkey-patching only apply_path_rewrites
# itself (in-process, never the shipped file) so the test isolates the
# relay, not apply_path_rewrites' own internals (already covered above).
UNIT_RELAY_ROOT="$TMP/unit-relay-root"
mkdir -p "$UNIT_RELAY_ROOT/plugins/relayplug/commands" "$UNIT_RELAY_ROOT/.claude/skills" "$UNIT_RELAY_ROOT/.logic-loom/lib"
cp "$LIB" "$UNIT_RELAY_ROOT/.logic-loom/lib/release-migrations.sh"
echo "content" > "$UNIT_RELAY_ROOT/plugins/relayplug/commands/relaycmd.md"
UNIT_RELAY_OUT="$(
  source "$RM" --root "$UNIT_RELAY_ROOT" >/dev/null 2>&1
  apply_path_rewrites() { printf '%s\n' "$1"; return 1; }
  SKILL_UNITS=""; COMMAND_UNITS="relaycmd"; AGENT_UNITS=""
  # MAP_LIST is normally reset by cmd_convert before it calls any unit
  # converter; called directly (as this unit test does), note_mapping's
  # reference to it trips this script's `set -u` and aborts the WHOLE
  # enclosing subshell before WRITE_FAILED is ever echoed below.
  MAP_LIST=""; HOOKS_SNIPPET=""; STOPPED_SKILLS=""
  WRITE_FAILED="false"
  convert_command_unit relayplug relaycmd dry-run false >/dev/null 2>&1
  echo "WRITE_FAILED=$WRITE_FAILED"
)"
assert "convert_command_unit relays apply_path_rewrites' failure into WRITE_FAILED across two levels of \$(...) nesting (render_command_skill's own capture, then this call site's)" \
  "printf '%s\n' \"\$UNIT_RELAY_OUT\" | grep -qF 'WRITE_FAILED=true'"

# ── reviewer round 2 (post round-2 builder) ──────────────────────────────
# mk_rv2_fixture <dir> <plugin> — the smallest plugin that exercises both a
# skill unit (marker-classified) and a hooks/ support file (ledger-classified).
mk_rv2_fixture() {
  local F="$1" P="$2"
  mkdir -p "$F/plugins/$P/hooks" "$F/plugins/$P/skills/$P-skill" "$F/.logic-loom/config" "$F/.logic-loom/lib"
  git init -q "$F"
  echo "FRAMEWORK_VERSION=9.0.0" > "$F/.logic-loom/config/architecture.conf"
  cp "$LIB" "$F/.logic-loom/lib/release-migrations.sh"
  echo "plugin | $P | native | native:/workflow | REMOVE | v4.0.0 | v6.2.0 | reviewer round-2 fixture" \
    > "$F/.logic-loom/config/release-migrations.conf"
  echo "echo hook" > "$F/plugins/$P/hooks/h.sh"
  printf -- '---\nname: %s-skill\ndescription: fixture skill\n---\n\nSkill body.\n' "$P" > "$F/plugins/$P/skills/$P-skill/SKILL.md"
  ( cd "$F" && git add -A >/dev/null && git commit -q -m init ) >/dev/null 2>&1
}

echo ""
echo "G. reviewer round 2 (data-loss finding, residual): a re-run whose targets all read KEEP modified-after-conversion must not count those sources as carried over"
# Reproduction: convert --apply once (clean), commit, then edit the PLUGIN
# SOURCE (hooks/h.sh and skills/<s>/SKILL.md) and re-run convert --apply.
# Every target now exists and differs from what the current source renders
# to, so each unit prints "KEEP <target> modified-after-conversion" and
# writes nothing -- the new source bytes are NOT at the target -- yet the
# existing-target branch mapped the source unconditionally, so cmd_convert's
# terminal gate read the plugin as fully accounted for and printed the
# delete step over bytes that were never carried over. The finding's own
# evidence named this residual ("KEEP modified-after-conversion branches");
# the scan side already treats a KEEP line as render-stale / KEEP-AS-IS, so
# convert's own gate is the one surface that still contradicted it.
RV2K="$TMP/rv2-keep-differs"
mk_rv2_fixture "$RV2K" sdd-rv2k
RV2K_RUN1="$(bash "$RM" convert sdd-rv2k --apply --root "$RV2K" 2>&1)"
RV2K_RC1=$?
assert "sanity: the first convert --apply is clean (rc 0, positive accounted line)" \
  "[ $RV2K_RC1 -eq 0 ] && printf '%s\n' \"\$RV2K_RUN1\" | grep -qF 'accounted: every file under plugins/sdd-rv2k is carried over'"
RV2K_CONVERTED="$RV2K/.claude/skills/sdd-rv2k/CONVERTED.md"
assert "sanity: the first convert --apply's CONVERTED.md recommends 'delete' (nothing to keep yet)" \
  "grep -qF 'delete plugins/sdd-rv2k once its converted' '$RV2K_CONVERTED'"
RV2K_CONVERTED_CKSUM1="$(cksum "$RV2K_CONVERTED")"
( cd "$RV2K" && git add -A >/dev/null && git commit -q -m converted ) >/dev/null 2>&1
echo "echo RV2K-SOURCE-EDIT-AFTER-CONVERSION" >> "$RV2K/plugins/sdd-rv2k/hooks/h.sh"
echo "RV2K-SOURCE-EDIT-AFTER-CONVERSION" >> "$RV2K/plugins/sdd-rv2k/skills/sdd-rv2k-skill/SKILL.md"
RV2K_RUN2="$(bash "$RM" convert sdd-rv2k --apply --root "$RV2K" 2>&1)"
RV2K_RC2=$?
assert "sanity: the re-run classifies both edited units as KEEP modified-after-conversion (nothing overwritten)" \
  "printf '%s\n' \"\$RV2K_RUN2\" | grep -qxF 'KEEP .claude/skills/sdd-rv2k/hooks/h.sh modified-after-conversion' && printf '%s\n' \"\$RV2K_RUN2\" | grep -qxF 'KEEP .claude/skills/sdd-rv2k-skill/SKILL.md modified-after-conversion'"
assert "sanity: the new source bytes are NOT at either target (KEEP wrote nothing)" \
  "! grep -qF 'RV2K-SOURCE-EDIT-AFTER-CONVERSION' '$RV2K/.claude/skills/sdd-rv2k/hooks/h.sh' && ! grep -qF 'RV2K-SOURCE-EDIT-AFTER-CONVERSION' '$RV2K/.claude/skills/sdd-rv2k-skill/SKILL.md'"
assert "the re-run withholds the delete step: no positive accounted line (the bug: it printed one over bytes that are not at the target)" \
  "! printf '%s\n' \"\$RV2K_RUN2\" | grep -qF 'accounted: every file under plugins/sdd-rv2k is carried over'"
assert "…prints DO NOT delete instead" \
  "printf '%s\n' \"\$RV2K_RUN2\" | grep -qxF 'Next steps: DO NOT delete plugins/sdd-rv2k yet.'"
assert "…never prints the delete line" \
  "! printf '%s\n' \"\$RV2K_RUN2\" | grep -qF 'Next steps: delete plugins/sdd-rv2k'"
assert "…and names BOTH kept-but-differing sources, with the reason and the reconcile instruction" \
  "printf '%s\n' \"\$RV2K_RUN2\" | grep -qF 'plugins/sdd-rv2k/hooks/h.sh (target .claude/skills/sdd-rv2k/hooks/h.sh exists but differs from what this source renders to now' && printf '%s\n' \"\$RV2K_RUN2\" | grep -qF 'plugins/sdd-rv2k/skills/sdd-rv2k-skill/SKILL.md (target .claude/skills/sdd-rv2k-skill/SKILL.md exists but differs from what this source renders to now' && printf '%s\n' \"\$RV2K_RUN2\" | grep -qF 'reconcile by hand, then decide'"
assert "…while the run itself is still rc 0 (a KEEP is not a failure — the gate is what changed, same as the empty-directory case above)" \
  "[ $RV2K_RC2 -eq 0 ]"
RV2K_SCAN="$(bash "$RM" scan --root "$RV2K" 2>&1)"
assert "sanity (unchanged): the scan side already reads this plugin as KEEP-AS-IS after the source edit, never REMOVE" \
  "printf '%s\n' \"\$RV2K_SCAN\" | grep -qF 'recommended: KEEP-AS-IS' && ! printf '%s\n' \"\$RV2K_SCAN\" | grep -qF 'recommended: REMOVE'"

# ─────────────────────────────────────────────────────────────────────────
# Round-4 finding 5 (medium, CONVERTED.md staleness — round-3 only pinned
# the caveat SENTENCE's presence in a freshly-written file; it never edited
# plugins/<p> and re-ran convert --apply to confirm the file itself
# (correctly, BY DESIGN — see render_converted_md's own comment on
# tamper-evident dating) stays frozen rather than picking up the new
# recommendation. RV2K_RUN2 above is exactly that re-run — CONVERTED.md
# already existed going in, so finalize_convert's `[ -e ... ]` branch fires
# and returns before ever writing. Reproduce and pin BOTH halves the
# original finding named: the file on disk is untouched byte-for-byte (so a
# human opening it directly still sees the FIRST run's "delete" line, now
# wrong), while the LIVE path (scan, asserted just above) already has it
# right. That contrast is what makes the caveat sentence load-bearing
# rather than decorative.
# ─────────────────────────────────────────────────────────────────────────
RV2K_CONVERTED_CKSUM2="$(cksum "$RV2K_CONVERTED")"
assert "finding 5: CONVERTED.md is byte-for-byte UNCHANGED by the re-run (finalize_convert's existing-target branch never writes)" \
  "[ '$RV2K_CONVERTED_CKSUM1' = '$RV2K_CONVERTED_CKSUM2' ]"
assert "finding 5: …so the on-disk file STILL says 'delete' — the exact stale, now-wrong advice a human reading it directly would see" \
  "grep -qF 'delete plugins/sdd-rv2k once its converted' '$RV2K_CONVERTED' && ! grep -qF 'DO NOT delete plugins/sdd-rv2k yet' '$RV2K_CONVERTED'"
assert "finding 5: …and it still carries the caveat pointing away from itself, toward scan/plan, for the CURRENT recommendation" \
  "grep -qF 'written once, at conversion time, and never rewritten' '$RV2K_CONVERTED' && grep -qF 'scan --json' '$RV2K_CONVERTED'"

# The on-disk record takes the same gate: with CONVERTED.md removed, the
# hooks file (ledger-classified) STOPs as not-ours while the skill unit
# (marker-classified) still reads KEEP -- the freshly written CONVERTED.md
# must name the KEEP source under DO NOT delete, not print the delete line.
rm -f "$RV2K/.claude/skills/sdd-rv2k/CONVERTED.md"
RV2K_RUN3="$(bash "$RM" convert sdd-rv2k --apply --root "$RV2K" 2>&1)"
assert "sanity: without the ledger the hooks file STOPs (not ours) and the skill unit still KEEPs" \
  "printf '%s\n' \"\$RV2K_RUN3\" | grep -q '^STOP hooks/h.sh' && printf '%s\n' \"\$RV2K_RUN3\" | grep -qxF 'KEEP .claude/skills/sdd-rv2k-skill/SKILL.md modified-after-conversion'"
assert "the re-written CONVERTED.md's own Follow-ups names the KEEP-but-differing skill source under DO NOT delete" \
  "[ -f '$RV2K/.claude/skills/sdd-rv2k/CONVERTED.md' ] && grep -qF 'DO NOT delete plugins/sdd-rv2k yet' '$RV2K/.claude/skills/sdd-rv2k/CONVERTED.md' && grep -qF 'plugins/sdd-rv2k/skills/sdd-rv2k-skill/SKILL.md (target .claude/skills/sdd-rv2k-skill/SKILL.md exists but differs' '$RV2K/.claude/skills/sdd-rv2k/CONVERTED.md' && ! grep -qF 'delete plugins/sdd-rv2k once its converted' '$RV2K/.claude/skills/sdd-rv2k/CONVERTED.md'"

# Same gate when only the TARGET was edited (source untouched): the tool
# cannot tell a target edit from a source edit from both -- doubt is KEEP
# and ASK, the stance scan already takes ("reconcile by hand, then decide").
RV2T="$TMP/rv2-keep-differs-target-edit"
mk_rv2_fixture "$RV2T" sdd-rv2t
bash "$RM" convert sdd-rv2t --apply --root "$RV2T" >/dev/null 2>&1
( cd "$RV2T" && git add -A >/dev/null && git commit -q -m converted ) >/dev/null 2>&1
echo "echo RV2T-TARGET-EDIT" >> "$RV2T/.claude/skills/sdd-rv2t/hooks/h.sh"
RV2T_RUN2="$(bash "$RM" convert sdd-rv2t --apply --root "$RV2T" 2>&1)"
assert "a target edited after conversion (source untouched) reads KEEP and ALSO withholds the delete step — the tool cannot prove which side moved" \
  "printf '%s\n' \"\$RV2T_RUN2\" | grep -qxF 'KEEP .claude/skills/sdd-rv2t/hooks/h.sh modified-after-conversion' && printf '%s\n' \"\$RV2T_RUN2\" | grep -qxF 'Next steps: DO NOT delete plugins/sdd-rv2t yet.' && printf '%s\n' \"\$RV2T_RUN2\" | grep -qF 'plugins/sdd-rv2t/hooks/h.sh (target .claude/skills/sdd-rv2t/hooks/h.sh exists but differs'"
assert "…and the untouched skill unit (SKIP up-to-date) is not collateral: it is not listed as not carried over" \
  "printf '%s\n' \"\$RV2T_RUN2\" | grep -qxF 'SKIP .claude/skills/sdd-rv2t-skill/SKILL.md up-to-date' && ! printf '%s\n' \"\$RV2T_RUN2\" | grep -qF 'plugins/sdd-rv2t/skills/sdd-rv2t-skill/SKILL.md (target'"

# Positive control: an unedited re-run is all-SKIP and still earns the
# positive accounted line -- the new gate does not over-refuse.
RV2C="$TMP/rv2-keep-differs-control"
mk_rv2_fixture "$RV2C" sdd-rv2c
bash "$RM" convert sdd-rv2c --apply --root "$RV2C" >/dev/null 2>&1
RV2C_RUN2="$(bash "$RM" convert sdd-rv2c --apply --root "$RV2C" 2>&1)"
assert "control: an unedited re-run (all SKIP up-to-date) still reports every file accounted for and prints the delete step" \
  "printf '%s\n' \"\$RV2C_RUN2\" | grep -qxF 'SKIP .claude/skills/sdd-rv2c/hooks/h.sh up-to-date' && printf '%s\n' \"\$RV2C_RUN2\" | grep -qF 'accounted: every file under plugins/sdd-rv2c is carried over' && printf '%s\n' \"\$RV2C_RUN2\" | grep -qF 'Next steps: delete plugins/sdd-rv2c once'"

echo ""
echo "D. round-4 REVIEWER: a pre-existing target behind a SYMLINKED PARENT (or that is itself a non-dangling symlink) is refused on the classify path, never read through"
# Reproduction on the round-4 builder tree: convert --apply once (clean),
# commit, then move BOTH converted directories (.claude/skills/<p>-skill and
# .claude/skills/<p>) OUTSIDE the repository and leave symlinks in their
# place. The round-4 fix (_loom_rm_refuse_existing_symlink_target) checked
# the FINAL path component only; `[ -e ]` follows a symlinked parent just as
# readily, so the re-run classified every file SKIP through the links,
# mapped them, printed "accounted: every file … carried over" and "Next
# steps: delete plugins/<p>", and scan said REMOVE — while the only in-repo
# home of those bytes was a symlink into an unversioned directory. The
# write path has refused a symlinked parent since round 2
# (_loom_rm_refuse_symlink_parents) and MIGRATION_GUIDE.md states the
# guarantee for "a symlink at a target … or at any parent directory of one";
# the classify path now honours it too. Fail-then-pass: the round-4 builder
# copy of release-migrations.sh fails every "refused"/"withheld" assertion in
# this block (it prints SKIP lines and the delete step instead).
RV4S="$TMP/rv4-symlinked-parent"
mk_rv2_fixture "$RV4S" sdd-rv4s
bash "$RM" convert sdd-rv4s --apply --root "$RV4S" > "$TMP/rv4s.run1.out" 2>&1
assert "sanity: the first convert --apply is clean (positive accounted line)" \
  "grep -qF 'accounted: every file under plugins/sdd-rv4s is carried over' '$TMP/rv4s.run1.out'"
( cd "$RV4S" && git add -A >/dev/null && git commit -q -m converted ) >/dev/null 2>&1
RV4S_OUT="$TMP/rv4s-outside"
mkdir -p "$RV4S_OUT"
mv "$RV4S/.claude/skills/sdd-rv4s-skill" "$RV4S_OUT/sdd-rv4s-skill"
ln -s "$RV4S_OUT/sdd-rv4s-skill" "$RV4S/.claude/skills/sdd-rv4s-skill"
mv "$RV4S/.claude/skills/sdd-rv4s" "$RV4S_OUT/sdd-rv4s"
ln -s "$RV4S_OUT/sdd-rv4s" "$RV4S/.claude/skills/sdd-rv4s"
bash "$RM" convert sdd-rv4s --apply --root "$RV4S" > "$TMP/rv4s.run2.out" 2>&1
RV4S_RC2=$?
assert "re-run: every existing target behind a symlinked parent ERRORs, naming the PARENT link, and the run exits 2" \
  "[ $RV4S_RC2 -eq 2 ] && grep -qF 'ERROR .claude/skills/sdd-rv4s-skill/SKILL.md: already exists, but its parent directory .claude/skills/sdd-rv4s-skill is a symlink' '$TMP/rv4s.run2.out' && grep -qF 'ERROR .claude/skills/sdd-rv4s/hooks/h.sh: already exists, but its parent directory .claude/skills/sdd-rv4s is a symlink' '$TMP/rv4s.run2.out' && grep -qF 'ERROR .claude/skills/sdd-rv4s/CONVERTED.md: already exists, but its parent directory .claude/skills/sdd-rv4s is a symlink' '$TMP/rv4s.run2.out'"
assert "…nothing is classified on the far side of a link (no SKIP/KEEP line at all — the bug printed 'SKIP … up-to-date' for every file)" \
  "! grep -qE '^(SKIP|KEEP) ' '$TMP/rv4s.run2.out'"
assert "…the delete step is withheld: no positive accounted line, 'DO NOT delete', never 'Next steps: delete'" \
  "! grep -qF 'accounted: every file under plugins/sdd-rv4s is carried over' '$TMP/rv4s.run2.out' && grep -qxF 'Next steps: DO NOT delete plugins/sdd-rv4s yet.' '$TMP/rv4s.run2.out' && ! grep -qF 'Next steps: delete plugins/sdd-rv4s' '$TMP/rv4s.run2.out'"
assert "…both plugin sources are named under 'Not carried over' (their bytes were never counted through the links)" \
  "grep -qxF '    - plugins/sdd-rv4s/hooks/h.sh' '$TMP/rv4s.run2.out' && grep -qxF '    - plugins/sdd-rv4s/skills/sdd-rv4s-skill/SKILL.md' '$TMP/rv4s.run2.out'"
assert "…the links and the outside copies are untouched (still symlinks, same targets; outside files intact; nothing new under .claude/)" \
  "[ -L '$RV4S/.claude/skills/sdd-rv4s-skill' ] && [ \"\$(readlink '$RV4S/.claude/skills/sdd-rv4s-skill')\" = '$RV4S_OUT/sdd-rv4s-skill' ] && [ -L '$RV4S/.claude/skills/sdd-rv4s' ] && [ -f '$RV4S_OUT/sdd-rv4s-skill/SKILL.md' ] && [ -f '$RV4S_OUT/sdd-rv4s/hooks/h.sh' ] && [ -f '$RV4S_OUT/sdd-rv4s/CONVERTED.md' ] && [ \"\$(find '$RV4S/.claude/skills' -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')\" = '2' ]"
RV4S_SCAN="$(bash "$RM" scan --root "$RV4S" 2>&1)"
assert "…and scan reads the converted plugin as KEEP-AS-IS (render-stale: the re-render could not reproduce what is under .claude/), never REMOVE" \
  "printf '%s\n' \"\$RV4S_SCAN\" | grep -qF 'recommended: KEEP-AS-IS' && printf '%s\n' \"\$RV4S_SCAN\" | grep -qF 're-rendering plugins/sdd-rv4s now' && ! printf '%s\n' \"\$RV4S_SCAN\" | grep -qF 'recommended: REMOVE'"

# The FINAL-component case the round-4 builder closed but left untested: a
# non-dangling symlink AT a target (the dangling case is covered above, in
# section D "never writes THROUGH a symlink at a target").
RV4T="$TMP/rv4-symlinked-target"
mk_rv2_fixture "$RV4T" sdd-rv4t
bash "$RM" convert sdd-rv4t --apply --root "$RV4T" >/dev/null 2>&1
( cd "$RV4T" && git add -A >/dev/null && git commit -q -m converted ) >/dev/null 2>&1
RV4T_OUT="$TMP/rv4t-outside"
mkdir -p "$RV4T_OUT"
mv "$RV4T/.claude/skills/sdd-rv4t/hooks/h.sh" "$RV4T_OUT/h.sh"
ln -s "$RV4T_OUT/h.sh" "$RV4T/.claude/skills/sdd-rv4t/hooks/h.sh"
bash "$RM" convert sdd-rv4t --apply --root "$RV4T" > "$TMP/rv4t.run2.out" 2>&1
RV4T_RC2=$?
assert "a NON-dangling symlink AT a target: ERROR 'already exists but is a symlink', exit 2, delete withheld, the source named under Not carried over" \
  "[ $RV4T_RC2 -eq 2 ] && grep -qF 'ERROR .claude/skills/sdd-rv4t/hooks/h.sh: already exists but is a symlink' '$TMP/rv4t.run2.out' && ! grep -qF 'SKIP .claude/skills/sdd-rv4t/hooks/h.sh' '$TMP/rv4t.run2.out' && grep -qxF 'Next steps: DO NOT delete plugins/sdd-rv4t yet.' '$TMP/rv4t.run2.out' && grep -qxF '    - plugins/sdd-rv4t/hooks/h.sh' '$TMP/rv4t.run2.out'"
assert "…the untouched skill unit is not collateral (still SKIP up-to-date), and the link + outside file are untouched" \
  "grep -qxF 'SKIP .claude/skills/sdd-rv4t-skill/SKILL.md up-to-date' '$TMP/rv4t.run2.out' && [ -L '$RV4T/.claude/skills/sdd-rv4t/hooks/h.sh' ] && [ \"\$(readlink '$RV4T/.claude/skills/sdd-rv4t/hooks/h.sh')\" = '$RV4T_OUT/h.sh' ] && [ -f '$RV4T_OUT/h.sh' ]"

# The EIGHTH existing-target read: append_marked_section (a command with a
# home skill appends a marker-delimited section into that skill's SKILL.md).
# It was covered only transitively — the skill unit ERRORs on the same file
# first — so a symlinked SKILL.md must now produce that ERROR line TWICE
# (skill unit + command append) and never a 'SKIP … up-to-date' for it.
RV4C="$TMP/rv4-symlinked-append-target"
mk_rv2_fixture "$RV4C" sdd-rv4c
mkdir -p "$RV4C/plugins/sdd-rv4c/skills/sdd-rv4c-cmd" "$RV4C/plugins/sdd-rv4c/commands"
printf -- '---\nname: sdd-rv4c-cmd\ndescription: home skill\n---\n\nHome skill body.\n' > "$RV4C/plugins/sdd-rv4c/skills/sdd-rv4c-cmd/SKILL.md"
printf -- '---\nname: sdd-rv4c-cmd\ndescription: the command\n---\n\nCommand body.\n' > "$RV4C/plugins/sdd-rv4c/commands/sdd-rv4c-cmd.md"
( cd "$RV4C" && git add -A >/dev/null && git commit -q -m "add home-skill command" ) >/dev/null 2>&1
bash "$RM" convert sdd-rv4c --apply --root "$RV4C" > "$TMP/rv4c.run1.out" 2>&1
assert "sanity: the command was APPENDED into its home skill and the run was clean" \
  "grep -qF 'APPENDED .claude/skills/sdd-rv4c-cmd/SKILL.md' '$TMP/rv4c.run1.out' && grep -qF 'accounted: every file under plugins/sdd-rv4c is carried over' '$TMP/rv4c.run1.out'"
( cd "$RV4C" && git add -A >/dev/null && git commit -q -m converted ) >/dev/null 2>&1
RV4C_OUT="$TMP/rv4c-outside"
mkdir -p "$RV4C_OUT"
mv "$RV4C/.claude/skills/sdd-rv4c-cmd/SKILL.md" "$RV4C_OUT/SKILL.md"
ln -s "$RV4C_OUT/SKILL.md" "$RV4C/.claude/skills/sdd-rv4c-cmd/SKILL.md"
bash "$RM" convert sdd-rv4c --apply --root "$RV4C" > "$TMP/rv4c.run2.out" 2>&1
RV4C_RC2=$?
assert "a symlinked home-skill SKILL.md is refused by BOTH readers (skill unit and command append): the ERROR line appears twice, no SKIP for it, exit 2, delete withheld" \
  "[ $RV4C_RC2 -eq 2 ] && [ \"\$(grep -cF 'ERROR .claude/skills/sdd-rv4c-cmd/SKILL.md: already exists but is a symlink' '$TMP/rv4c.run2.out')\" = '2' ] && ! grep -qF 'SKIP .claude/skills/sdd-rv4c-cmd/SKILL.md' '$TMP/rv4c.run2.out' && grep -qxF 'Next steps: DO NOT delete plugins/sdd-rv4c yet.' '$TMP/rv4c.run2.out'"
assert "…and the command source is named under Not carried over alongside the skill source (neither was counted through the link)" \
  "grep -qxF '    - plugins/sdd-rv4c/commands/sdd-rv4c-cmd.md' '$TMP/rv4c.run2.out' && grep -qxF '    - plugins/sdd-rv4c/skills/sdd-rv4c-cmd/SKILL.md' '$TMP/rv4c.run2.out'"

echo ""
echo "G. reviewer round 2 (data-loss, fail-open): a '#' or '[' in the CHECKOUT PATH blinded the unit planner and the accounting (sed with REPO_ROOT interpolated as a pattern)"
# Reproduction: plan_convert_units and unconverted_plugin_files both stripped
# \$REPO_ROOT with `sed "s#^\$REPO_ROOT/##"`. A '#' in the checkout path is
# sed's delimiter here ("bad flag in substitute command"), a '[' opens an
# unbalanced bracket expression -- either way sed errors with EMPTY output,
# so SKILL_UNITS/COMMAND_UNITS/AGENT_UNITS came back empty (no skill,
# command or agent was ever converted -- only hooks/support, which use
# parameter expansion) AND the accounting saw zero files under plugins/<p>,
# printed the positive accounted line, recorded `converted =`, and the next
# scan said REMOVE with `git rm -r plugins/<p>` over a skill never carried
# into .claude/. Reproduced on the pre-fix tree for both characters.
rv2_odd_path_probe() {   # $1 = odd character, $2 = label
  local ODD="$1" LABEL="$2"
  local F="$TMP/rv2-odd${ODD}path/repo"
  mk_rv2_fixture "$F" "sdd-rv2$LABEL"
  mkdir -p "$F/plugins/sdd-rv2$LABEL/commands"
  echo "echo helper" > "$F/plugins/sdd-rv2$LABEL/commands/helper.sh"
  ( cd "$F" && git add -A >/dev/null && git commit -q -m helper ) >/dev/null 2>&1
  local OUT RC
  OUT="$(bash "$RM" convert "sdd-rv2$LABEL" --apply --root "$F" 2>&1)"
  RC=$?
  assert "[$LABEL] sanity: the fixture's checkout path really contains the character" \
    "case '$F' in *\"$ODD\"*) true ;; *) false ;; esac"
  assert "[$LABEL] no sed error leaks (the bug's fingerprint: 'sed: 1: ... bad flag' / 'unbalanced brackets')" \
    "! printf '%s\n' \"\$OUT\" | grep -q '^sed: '"
  assert "[$LABEL] the skill unit IS converted (WROTE .claude/skills/sdd-rv2$LABEL-skill/SKILL.md) — the bug left SKILL_UNITS empty and never wrote it" \
    "printf '%s\n' \"\$OUT\" | grep -qF 'WROTE .claude/skills/sdd-rv2$LABEL-skill/SKILL.md' && [ -f '$F/.claude/skills/sdd-rv2$LABEL-skill/SKILL.md' ]"
  assert "[$LABEL] commands/helper.sh (never converted by any unit) is reported as not carried over" \
    "printf '%s\n' \"\$OUT\" | grep -qF -- '- plugins/sdd-rv2$LABEL/commands/helper.sh'"
  assert "[$LABEL] the delete step is withheld (the bug printed the positive accounted line over an empty enumeration)" \
    "! printf '%s\n' \"\$OUT\" | grep -qF 'accounted: every file under plugins/sdd-rv2$LABEL is carried over' && printf '%s\n' \"\$OUT\" | grep -qxF 'Next steps: DO NOT delete plugins/sdd-rv2$LABEL yet.'"
  ( cd "$F" && git add -A >/dev/null && git commit -q -m converted ) >/dev/null 2>&1
  local SCAN; SCAN="$(bash "$RM" scan --root "$F" 2>&1)"
  assert "[$LABEL] end-to-end: the next scan is KEEP-AS-IS naming helper.sh, never REMOVE / git rm -r (the bug's full chain reached REMOVE)" \
    "printf '%s\n' \"\$SCAN\" | grep -qF 'recommended: KEEP-AS-IS' && printf '%s\n' \"\$SCAN\" | grep -qF 'commands/helper.sh' && ! printf '%s\n' \"\$SCAN\" | grep -qF 'recommended: REMOVE'"
  # cleanup the odd-named parent so the suite's own rm -rf never has to
  # deal with it in a surprising way
  rm -rf "$TMP/rv2-odd${ODD}path"
}
rv2_odd_path_probe '#' hash
rv2_odd_path_probe '[' bracket

echo ""
echo "G. reviewer round 2 (fail-open): an UNREADABLE directory under plugins/<p> is bytes this tool never saw — enumeration failure must withhold the delete step"
if [ "$(id -u)" -eq 0 ]; then
  skip "running as root: a chmod 000 directory is still readable, so the enumeration failure cannot be provoked"
else
  RV2U="$TMP/rv2-unreadable-subdir"
  mk_rv2_fixture "$RV2U" sdd-rv2u
  mkdir -p "$RV2U/plugins/sdd-rv2u/private"
  echo "customer bytes the tool cannot read" > "$RV2U/plugins/sdd-rv2u/private/secret.txt"
  ( cd "$RV2U" && git add -A >/dev/null && git commit -q -m private ) >/dev/null 2>&1
  chmod 000 "$RV2U/plugins/sdd-rv2u/private"
  RV2U_OUT="$(bash "$RM" convert sdd-rv2u --apply --root "$RV2U" 2>&1)"
  chmod 755 "$RV2U/plugins/sdd-rv2u/private"
  assert "sanity: private/secret.txt was never converted (find could not descend into it)" \
    "[ ! -e '$RV2U/.claude/skills/sdd-rv2u/private/secret.txt' ] && ! printf '%s\n' \"\$RV2U_OUT\" | grep -qF 'WROTE .claude/skills/sdd-rv2u/private/secret.txt'"
  assert "the enumeration failure is reported by name (find exited non-zero — nothing under the directory can be verified)" \
    "printf '%s\n' \"\$RV2U_OUT\" | grep -qF 'plugins/sdd-rv2u/ (could not fully enumerate'"
  assert "…and the delete step is withheld (the bug: a partial listing read as complete, and the positive accounted line fired over unseen bytes)" \
    "! printf '%s\n' \"\$RV2U_OUT\" | grep -qF 'accounted: every file under plugins/sdd-rv2u is carried over' && printf '%s\n' \"\$RV2U_OUT\" | grep -qxF 'Next steps: DO NOT delete plugins/sdd-rv2u yet.'"
fi

echo ""
echo "G. reviewer round 2 (data-loss finding, on-disk half): CONVERTED.md's own Follow-ups must withhold the delete step when a write failed in this run, exactly as the terminal does"
# Reproduction: force apply_path_rewrites to fail (TMPDIR is a plain file, so
# mktemp fails). Every text unit is then written UNREWRITTEN and mapped (the
# write itself succeeded), WRITE_FAILED marks the run stopped, and the
# terminal correctly says DO NOT delete -- but render_converted_md gated its
# Follow-ups on unconverted_plugin_files alone, which was empty, so the
# on-disk CONVERTED.md still printed the delete line. The finding named
# exactly this surface ("a user who reads only CONVERTED.md").
RV2W="$TMP/rv2-write-failed-converted-md"
mk_rv2_fixture "$RV2W" sdd-rv2w
RV2W_BOGUS="$TMP/rv2-bogus-tmpdir-is-a-file"
: > "$RV2W_BOGUS"
RV2W_OUT="$(TMPDIR="$RV2W_BOGUS" bash "$RM" convert sdd-rv2w --apply --root "$RV2W" 2>&1)"
RV2W_RC=$?
assert "sanity: the forced rewrite failure stops the run (rc 2) and the terminal withholds the delete step" \
  "[ $RV2W_RC -eq 2 ] && printf '%s\n' \"\$RV2W_OUT\" | grep -q 'ERROR apply_path_rewrites' && printf '%s\n' \"\$RV2W_OUT\" | grep -qxF 'Next steps: DO NOT delete plugins/sdd-rv2w yet.'"
RV2W_CONVERTED="$RV2W/.claude/skills/sdd-rv2w/CONVERTED.md"
assert "sanity: CONVERTED.md was still written (finalize_convert runs regardless)" \
  "[ -f '$RV2W_CONVERTED' ]"
assert "CONVERTED.md's Follow-ups says DO NOT delete and names the failed-write reason (the bug: it printed the delete line)" \
  "grep -qF 'DO NOT delete plugins/sdd-rv2w yet' '$RV2W_CONVERTED' && grep -qF 'a write failed' '$RV2W_CONVERTED'"
assert "…and never prints the unconditional delete line" \
  "! grep -qF 'delete plugins/sdd-rv2w once its converted commands/skills work' '$RV2W_CONVERTED'"

# ═══════════════════════════════════════════════════════════════════════════
# SECTION F — command/SKILL prose pins (§15.2-E)
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "F. command/SKILL prose pins"
echo "   (a prose pin proves the instruction is present in the right step, not that it is obeyed)"

for f in "$CMD_MD" "$SKILL_MD"; do
  base="$(basename "$f")"
  assert "$base: cites 'release-migrations.sh scan' verbatim" \
    "grep -qF 'bash plugins/loom-maintenance/scripts/release-migrations.sh scan' '$f'"
  assert "$base: cites 'record-update-writes.sh --version'" \
    "grep -qF 'record-update-writes.sh --version' '$f'"
  assert "$base: cites 'record-update-writes.sh --reconcile'" \
    "grep -qF 'record-update-writes.sh --reconcile' '$f'"
  assert "$base: cites 'Decisions in force'" \
    "grep -qF 'Decisions in force' '$f'"
  assert "$base: states 'a decision suppresses a proposal, never the fact'" \
    "grep -qF 'a decision suppresses a proposal, never the fact' '$f'"
  assert "$base: cites the '[m]ove' menu entry" \
    "grep -qF '[m]ove' '$f'"
done

CMD_STEP5_LINE="$(grep -n '^### Step 5' "$CMD_MD" | head -1 | cut -d: -f1)"
CMD_RECORDER_LINE="$(grep -n 'record-update-writes.sh --version' "$CMD_MD" | head -1 | cut -d: -f1)"
CMD_STEP6_LINE="$(grep -n '^### Step 6' "$CMD_MD" | head -1 | cut -d: -f1)"
assert "command: '### Step 5' < recorder line < '### Step 6'" \
  "[ -n '$CMD_STEP5_LINE' ] && [ -n '$CMD_RECORDER_LINE' ] && [ -n '$CMD_STEP6_LINE' ] \
   && [ '$CMD_STEP5_LINE' -lt '$CMD_RECORDER_LINE' ] && [ '$CMD_RECORDER_LINE' -lt '$CMD_STEP6_LINE' ]"

SKILL_STEP7_LINE="$(grep -n '^### Step 7:' "$SKILL_MD" | head -1 | cut -d: -f1)"
SKILL_RECORDER_LINE="$(grep -n 'record-update-writes.sh --version' "$SKILL_MD" | head -1 | cut -d: -f1)"
SKILL_STEP8_LINE="$(grep -n '^### Step 8:' "$SKILL_MD" | head -1 | cut -d: -f1)"
assert "SKILL: '### Step 7' < recorder line < '### Step 8'" \
  "[ -n '$SKILL_STEP7_LINE' ] && [ -n '$SKILL_RECORDER_LINE' ] && [ -n '$SKILL_STEP8_LINE' ] \
   && [ '$SKILL_STEP7_LINE' -lt '$SKILL_RECORDER_LINE' ] && [ '$SKILL_RECORDER_LINE' -lt '$SKILL_STEP8_LINE' ]"

echo ""
echo "G. round-4 finding 4 (low): the adopt-receipt-sha256 baseline comment no longer contradicts its own corroboration helper"
# _loom_rm_adopt_receipt_sha256's own comment used to say "Unlike a tag, an
# adopter cannot forge this" -- directly contradicted a few dozen lines
# later by _loom_rm_receipt_sha256_corroborated's comment, which spells out
# exactly how an adopter CAN hand-write a forged entry (both comments are in
# this same file, about the same receipt). Pin: the overclaim string is
# gone, the corroboration comment (the true story) is still there, and the
# baseline comment now points forward to it instead of asserting the
# opposite.
assert "release-migrations.sh no longer claims an adopter cannot forge the receipt-recorded sha256" \
  "! grep -qF 'Unlike a tag, an adopter cannot forge this' '$RM'"
assert "…the corroboration helper's own contradicting comment is still present (the true story, unchanged)" \
  "grep -qF 'hand-writing an entry that claims' '$RM'"
assert "…and the baseline comment now points forward to the corroboration helper by name" \
  "grep -qF 'see _loom_rm_receipt_sha256_corroborated below for' '$RM'"

echo ""
echo "H. round-4 finding 6 (high): a kind:\"dir\" receipt entry is corroborated against refs/loom-upstream/main's own tree history"
# A kind:"dir" entry carries no hash, so — unlike a kind:"file" entry, which
# build_entries/upstream_blob_sha and --reconcile's own byte-cmp already
# verify against a real blob at a provably-upstream commit — the ONLY gate
# on a directory claim used to be TRUSTED_GENERATOR_RE: a shape check on a
# string in the SAME hand-editable receipt the entry itself lives in. An
# attacker who simply writes a plausible generator string (it need not even
# be a real version — "logicloom@99.9.9" matches the regex) gets a
# kind:"dir" entry trusted at face value, with nothing checking whether
# LogicLoom's own history ever had anything at that path.
# loom_upstream_ever_had_dir (new this round, .logic-loom/lib/release-migrations.sh)
# closes that asymmetry: a directory claim is corroborated only when
# refs/loom-upstream/main's own reachable history ever held a TREE at that
# exact path — cheap, read-only, no crypto, same shape as the file-side
# _loom_rm_receipt_sha256_corroborated.
#
# NOTE on what this test does NOT claim: for the SPECIFIC case of a forged
# dir claim standing alone, --reconcile's own byte+path check
# (`git cat-file -e "$sync_ref:$f"` before any cmp) already refuses to
# RECONCILE or even print DIFFERS for a file under a directory upstream
# never had — reproduced below (OLD_RECON_OUT) as a positive control, so
# this suite does not claim a false RECONCILE was ever reachable that way.
# What loom_upstream_ever_had_dir closes is the asymmetry itself (a
# directory claim resting on a weaker gate than a file claim) and stops the
# forged directory from being swept AT ALL — not just from being recorded —
# which matters once anything else ever reads `recorded_dirs` for a
# decision that is not itself byte-gated the way reconcile's inner loop is.
# Fail-then-pass: loom_upstream_ever_had_dir does not exist before this
# round (sourcing the lib and calling it fails outright); after, it exists
# and correctly tells a real upstream directory apart from a fabricated one.
H_F="$TMP/finding6-dir-corroboration"
mkdir -p "$H_F/.logic-loom/real-dir" "$H_F/web/customer-app"
git init -q "$H_F"
( cd "$H_F" && git config user.email test@example.com && git config user.name Test )
echo "real-content" > "$H_F/.logic-loom/real-dir/a.sh"
( cd "$H_F" && git add -A >/dev/null && git commit -q -m "U1: upstream baseline (no web/ tree, ever)" )
H_SHA_A="$(git -C "$H_F" rev-parse HEAD)"
git -C "$H_F" update-ref refs/loom-upstream/main "$H_SHA_A"
echo "customer content, never LogicLoom's" > "$H_F/web/customer-app/config.json"
( cd "$H_F" && git add -A >/dev/null && git commit -q -m "customer's own app, untracked by upstream" )

assert "loom_upstream_ever_had_dir: a directory refs/loom-upstream/main genuinely shipped corroborates" \
  "( source '$LIB'; loom_upstream_ever_had_dir '.logic-loom/real-dir' '$H_F' )"
assert "loom_upstream_ever_had_dir: a directory refs/loom-upstream/main never had (a customer's own) does NOT corroborate" \
  "! ( source '$LIB'; loom_upstream_ever_had_dir 'web/customer-app' '$H_F' )"
assert "…nor a path that resolves to a FILE, not a directory, in upstream history" \
  "! ( source '$LIB'; loom_upstream_ever_had_dir '.logic-loom/real-dir/a.sh' '$H_F' )"
git -C "$H_F" update-ref -d refs/loom-upstream/main 2>/dev/null
assert "…and it refuses cleanly (rc 1) with no refs/loom-upstream/main at all, never a false pass" \
  "( source '$LIB'; ! loom_upstream_ever_had_dir '.logic-loom/real-dir' '$H_F' )"

# Positive control for the NOTE above: even on the PRE-round-4 recorder
# (which never calls loom_upstream_ever_had_dir at all), a forged dir claim
# alone never produces a false RECONCILE — the byte+path check already
# refuses it. Confirms the corroboration fix is closing the asymmetry, not
# papering over an actual false-RECONCILE this suite could reproduce.
cat > "$H_F/.logicloom-adopt-receipt.json" <<'JSON'
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-01-01T00:00:00.000Z",
      "generator": "logicloom-update-framework@99.9.9",
      "status": "complete",
      "wrote": [
        {"target": "harness", "path": "web/customer-app", "kind": "dir"}
      ],
      "skipped": [], "failed": [], "notAttempted": []
    }
  ]
}
JSON
echo "$H_SHA_A" > "$H_F/.sdd-sync-ref"
git -C "$H_F" update-ref refs/loom-upstream/main "$H_SHA_A"
H_RECON_OUT="$(bash "$RECORDER" --root "$H_F" --reconcile 2>&1)"
assert "control: even a forged-but-regex-passing generator claiming a never-upstream directory never RECONCILEs a file under it" \
  "! printf '%s' \"\$H_RECON_OUT\" | grep -qF 'RECONCILE web/customer-app/config.json'"
assert "…nor DIFFERS (the file is out of scope before any content comparison happens)" \
  "! printf '%s' \"\$H_RECON_OUT\" | grep -qF 'web/customer-app/config.json'"

# ═══════════════════════════════════════════════════════════════════════════
# SECTION D/E addendum — reviewer round 5 (post round-5 builder). Every block
# below was first reproduced as a live defect against the round's starting
# tree — a REMOVE / `git rm` recommendation printed over bytes this tool
# never proved LogicLoom's, or a conversion that carried a customer's
# repository metadata into .claude/ — then closed; each carries its
# reproduction inline. Fixtures reuse mk_rv1_fixture (above).
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "C. reviewer round 5 (high): a receipt-sha256 baseline never reads as pristine through a SYMLINKED PARENT directory"
# Reproduction on the starting tree: same fixture shape as FIX_RECEIPT (a
# path row; a trusted, corroborated receipt digest). The customer then moved
# docs/ OUTSIDE the repository and left `docs -> <outside>` in its place
# (unstaged). git's own diff reports a tracked file behind a symlinked
# leading path as DELETED, so the sync-ref/upstream baselines were already
# safe — but the receipt-sha256 route never asks git: _loom_rm_sha256_file's
# `[ -L ]` (round-5 finding 5) looks at the FINAL component only, `[ -f ]`
# and open() resolve the parent link, the hash matched, resolve_baseline
# picked the receipt candidate as the winner (by design: a receipt match
# beats a stale sync-ref) and resolve_state read it as pristine: state
# pristine, REMOVE, `git rm 'docs/old-note.md'` printed. Running that printed
# command in the fixture DELETED the file at the link's target, outside the
# repository (`git rm` unlinks by path and the kernel resolves the directory
# link) — a path this tool never created, gone.
RV5_SYM="$TMP/rv5-receipt-symlinked-parent"
RV5_SYM_OUT="$TMP/rv5-receipt-symlinked-parent-outside"
mkdir -p "$RV5_SYM/.logic-loom/config" "$RV5_SYM/.logic-loom/lib" "$RV5_SYM/docs" "$RV5_SYM_OUT"
git init -q "$RV5_SYM"
cp "$LIB" "$RV5_SYM/.logic-loom/lib/release-migrations.sh"
echo "FRAMEWORK_VERSION=9.0.0" > "$RV5_SYM/.logic-loom/config/architecture.conf"
echo "path | docs/old-note.md | removed | command:/replacement-cmd | REMOVE | v6.0.0 | v9.0.0 | reviewer round-5 symlinked-parent fixture" \
  > "$RV5_SYM/.logic-loom/config/release-migrations.conf"
printf 'exactly what LogicLoom wrote here\n' > "$RV5_SYM/docs/old-note.md"
RV5_SYM_SHA="$(python3 -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$RV5_SYM/docs/old-note.md")"
cat > "$RV5_SYM/.logicloom-adopt-receipt.json" <<JSON
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-01-01T00:00:00.000Z",
      "generator": "logicloom-update-framework@1.0.0",
      "status": "complete",
      "only": [],
      "wrote": [
        { "target": "harness", "path": "docs/old-note.md", "kind": "file", "sha256": "$RV5_SYM_SHA" }
      ],
      "skipped": [], "failed": [], "notAttempted": []
    }
  ]
}
JSON
( cd "$RV5_SYM" && git add -A >/dev/null && git commit -q -m "adopted install (corroborating commit)" )
git -C "$RV5_SYM" update-ref refs/loom-upstream/main HEAD
bash "$RM" scan --json --root "$RV5_SYM" > "$TMP/rv5-sym-control.json" 2>&1
assert "control (docs/ a real directory): the receipt-sha256 route still reads the pristine file as REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv5-sym-control.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"baseline\"] == \"receipt-sha256:$RV5_SYM_SHA\", it
assert it[\"state\"] == \"pristine\" and it[\"recommended\"] == \"REMOVE\", it
'"
mv "$RV5_SYM/docs" "$RV5_SYM_OUT/docs"
ln -s "$RV5_SYM_OUT/docs" "$RV5_SYM/docs"
assert "sanity: docs/ is now a symlink to a directory OUTSIDE the repo, the file behind it still byte-matches the receipt digest, and git itself already sees the tracked path as gone" \
  "[ -L '$RV5_SYM/docs' ] && [ -f '$RV5_SYM_OUT/docs/old-note.md' ] && ! git -C '$RV5_SYM' diff --quiet HEAD -- docs/old-note.md"
bash "$RM" scan --json --root "$RV5_SYM" > "$TMP/rv5-sym.json" 2>&1
assert "scan: never pristine, never REMOVE, no remove_command — the symlinked parent directory is named under changed" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv5-sym.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"docs/old-note.md\")
assert it[\"state\"] != \"pristine\", it
assert it[\"recommended\"] != \"REMOVE\", it
assert it[\"remove_command\"] == \"\", it
assert any(x.startswith(\"docs\") and \"symlink\" in x for x in it[\"changed_files\"]), it
'"
bash "$RM" plan docs/old-note.md --root "$RV5_SYM" > "$TMP/rv5-sym.plan" 2>&1
assert "plan: prints no git rm for it" "! grep -q 'git rm' '$TMP/rv5-sym.plan'"
assert "…and nothing was touched: the link, and the file on its far side, are intact" \
  "[ -L '$RV5_SYM/docs' ] && [ \"\$(cat '$RV5_SYM_OUT/docs/old-note.md')\" = 'exactly what LogicLoom wrote here' ]"

echo ""
echo "D. reviewer round 5 (medium): a nested git repository under plugins/<p> is never pristine, never converted into .claude/, and always withholds the delete step"
# Reproduction on the starting tree: the customer ran `git init` inside
# plugins/sdd-rv5g (their own history, their own commits) — and, in the
# second variant below, a `.git` FILE sits there instead (a gitdir pointer,
# as `git worktree` writes one). The OUTER repo's git cannot see either:
# `ls-files --others` never lists anything under a nested repository and
# `diff` is clean, so scan said pristine / REMOVE and plan printed
# `git rm -r 'plugins/sdd-rv5g'` over a directory holding history that is
# nobody's but the customer's. convert --apply then carried `.git/**` into
# `.claude/skills/sdd-rv5g/.git/` — a WROTE line for every hook sample,
# HEAD, config, the object store — which turns .claude/skills/sdd-rv5g into
# an EMBEDDED repository the outer repo can only ever hold as a 160000
# gitlink (reproduced: `git add .claude` warned "adding embedded git
# repository"), so the converted skill could never travel with the outer
# tree; the delete step was withheld only by the accident of the fresh
# repository's empty objects/info, objects/pack and refs/tags directories,
# and for the gitdir-pointer variant it printed `accounted: every file …
# carried over` and the delete step outright.
RV5G="$TMP/rv5-nested-git"
mk_rv1_fixture "$RV5G" sdd-rv5g
bash "$RM" scan --json --root "$RV5G" > "$TMP/rv5g-control.json" 2>&1
assert "control: without the nested repository the pristine plugin reads REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv5g-control.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv5g\")
assert it[\"state\"] == \"pristine\" and it[\"recommended\"] == \"REMOVE\", it
'"
( cd "$RV5G/plugins/sdd-rv5g" && git init -q && git add -A >/dev/null && git -c user.email=t@e -c user.name=T commit -q -m "customer's own nested history" )
assert "sanity: the outer repo's own git sees nothing (clean diff, nothing untracked) — the blind spot this block closes" \
  "git -C '$RV5G' diff --quiet HEAD -- plugins/sdd-rv5g && [ -z \"\$(git -C '$RV5G' ls-files --others --exclude-standard -- plugins/sdd-rv5g)\" ] && [ -d '$RV5G/plugins/sdd-rv5g/.git' ]"
bash "$RM" scan --json --root "$RV5G" > "$TMP/rv5g.json" 2>&1
assert "scan: never pristine, never REMOVE, no remove_command; the nested .git is named under added" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv5g.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv5g\")
assert it[\"state\"] != \"pristine\", it
assert it[\"recommended\"] != \"REMOVE\", it
assert it[\"remove_command\"] == \"\", it
assert any(x.startswith(\"plugins/sdd-rv5g/.git\") for x in it[\"added_files\"]), it
'"
bash "$RM" convert sdd-rv5g --dry-run --root "$RV5G" > "$TMP/rv5g.dry" 2>&1
assert "convert --dry-run: plans NO write under .claude/skills/sdd-rv5g/.git, reports the nested repository under 'Not carried over' and withholds the delete step" \
  "! grep -q '\\.claude/skills/sdd-rv5g/\\.git' '$TMP/rv5g.dry' && grep -q '^accounted: NOT' '$TMP/rv5g.dry' && grep -q -- '- plugins/sdd-rv5g/\\.git' '$TMP/rv5g.dry'"
bash "$RM" convert sdd-rv5g --apply --root "$RV5G" > "$TMP/rv5g.apply" 2>&1
assert "convert --apply: writes nothing named .git under .claude/ (no embedded repository is ever created); CONVERTED.md says DO NOT delete" \
  "[ ! -e '$RV5G/.claude/skills/sdd-rv5g/.git' ] && ! grep -q '^WROTE .claude/skills/sdd-rv5g/.git' '$TMP/rv5g.apply' && grep -q 'DO NOT delete plugins/sdd-rv5g' '$RV5G/.claude/skills/sdd-rv5g/CONVERTED.md'"
assert "…and the customer's nested repository is untouched (its HEAD still resolves)" \
  "git -C '$RV5G/plugins/sdd-rv5g' rev-parse -q --verify HEAD >/dev/null"
RV5GF="$TMP/rv5-nested-gitfile"
mk_rv1_fixture "$RV5GF" sdd-rv5gf
echo "gitdir: /somewhere/else/.git/worktrees/x" > "$RV5GF/plugins/sdd-rv5gf/.git"
bash "$RM" scan --json --root "$RV5GF" > "$TMP/rv5gf.json" 2>&1
assert "gitdir-pointer variant: scan never pristine / never REMOVE, the .git file named under added" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv5gf.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv5gf\")
assert it[\"state\"] != \"pristine\" and it[\"recommended\"] != \"REMOVE\", it
assert any(x.startswith(\"plugins/sdd-rv5gf/.git\") for x in it[\"added_files\"]), it
'"
bash "$RM" convert sdd-rv5gf --dry-run --root "$RV5GF" > "$TMP/rv5gf.dry" 2>&1
assert "gitdir-pointer variant: convert plans no WRITE of the .git file and withholds the delete step (this variant used to print 'accounted: every file … carried over')" \
  "! grep -q 'WRITE .claude/skills/sdd-rv5gf/.git' '$TMP/rv5gf.dry' && grep -q '^accounted: NOT' '$TMP/rv5gf.dry' && ! grep -q '^accounted: every' '$TMP/rv5gf.dry'"

echo ""
echo "D. reviewer round 5 (medium): a directory under plugins/<p> this user cannot read is never pristine — an enumeration that could not complete proves nothing"
# Reproduction on the starting tree: an UNTRACKED subdirectory the current
# user cannot read (mode 000 — left by another account, a container run, a
# botched chmod) under an otherwise pristine plugin. `git ls-files --others`
# (with or without --ignored) lists nothing under a directory it cannot
# open and still exits 0; `git diff` is clean; so scan said pristine /
# REMOVE with added_files == [] while plugins/sdd-rv5u/private/notes.md —
# bytes no commit vouches for — sat behind that door. unconverted_plugin_files()
# already treats a failed `find` as "nothing under it can be verified"
# (reviewer round 2); resolve_state now applies the same rule.
if [ "$(id -u)" = "0" ]; then
  skip "unreadable-subdirectory block: running as root, which can read a mode-000 directory — the blind spot cannot be reproduced"
else
  RV5U="$TMP/rv5-unreadable"
  mk_rv1_fixture "$RV5U" sdd-rv5u
  mkdir -p "$RV5U/plugins/sdd-rv5u/private"
  echo "customer bytes no commit vouches for" > "$RV5U/plugins/sdd-rv5u/private/notes.md"
  chmod 000 "$RV5U/plugins/sdd-rv5u/private"
  assert "sanity: the outer repo's own git lists nothing under the unreadable directory and its diff is clean — the blind spot this block closes" \
    "[ -z \"\$(git -C '$RV5U' ls-files --others --ignored --exclude-standard -- plugins/sdd-rv5u 2>/dev/null)\" ] && git -C '$RV5U' diff --quiet HEAD -- plugins/sdd-rv5u"
  bash "$RM" scan --json --root "$RV5U" > "$TMP/rv5u.json" 2>&1
  chmod 755 "$RV5U/plugins/sdd-rv5u/private"
  assert "scan: never pristine, never REMOVE, no remove_command; the directory is named under added as not fully enumerable" \
    "python3 -c '
import json
d = json.load(open(\"$TMP/rv5u.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv5u\")
assert it[\"state\"] != \"pristine\", it
assert it[\"recommended\"] != \"REMOVE\", it
assert it[\"remove_command\"] == \"\", it
assert any(\"could not fully enumerate\" in x for x in it[\"added_files\"]), it
'"
  assert "…and the customer's bytes are still there" \
    "[ \"\$(cat '$RV5U/plugins/sdd-rv5u/private/notes.md')\" = 'customer bytes no commit vouches for' ]"
fi


echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  E. Round-6 review findings"
echo "═══════════════════════════════════════════════════════════"

echo ""
echo "E1. medium finding: write_text_target's chmod +x failure used to be swallowed — the write still counted as succeeded"
UNIT_CHMOD_ROOT="$TMP/unit-chmod-fail"
mkdir -p "$UNIT_CHMOD_ROOT/.logic-loom/lib"
cp "$LIB" "$UNIT_CHMOD_ROOT/.logic-loom/lib/release-migrations.sh"
UNIT_CHMOD_STUBBIN="$TMP/unit-chmod-stubbin"
mkdir -p "$UNIT_CHMOD_STUBBIN"
cat > "$UNIT_CHMOD_STUBBIN/chmod" << 'STUBEOF'
#!/usr/bin/env bash
for a in "$@"; do
  case "$a" in
    +x|*+x*) exit 1 ;;
  esac
done
exec /bin/chmod "$@"
STUBEOF
chmod +x "$UNIT_CHMOD_STUBBIN/chmod"
echo "customer source, executable" > "$TMP/unit-chmod-src.sh"
chmod +x "$TMP/unit-chmod-src.sh"
UNIT_CHMOD_OUT="$(
  source "$RM" --root "$UNIT_CHMOD_ROOT" >/dev/null 2>&1
  WRITE_FAILED="false"
  PATH="$UNIT_CHMOD_STUBBIN:$PATH"
  if write_text_target "written.sh" "content" "$TMP/unit-chmod-src.sh"; then
    echo "WRITE_TEXT=succeeded"
  else
    echo "WRITE_TEXT=refused"
  fi
  echo "WRITE_FAILED=$WRITE_FAILED"
)"
assert "write_text_target returns FAILURE when chmod +x fails, even though the content write itself succeeded" \
  "printf '%s\n' \"\$UNIT_CHMOD_OUT\" | grep -qF 'WRITE_TEXT=refused'"
assert "…and sets WRITE_FAILED=true so the caller's accounting treats it as not carried over" \
  "printf '%s\n' \"\$UNIT_CHMOD_OUT\" | grep -qF 'WRITE_FAILED=true'"
# Positive control: same fixture, no stubbed chmod on PATH — the write must
# still succeed and preserve the executable bit, proving the new check does
# not over-refuse a normal, successful chmod.
UNIT_CHMOD_OK_OUT="$(
  source "$RM" --root "$UNIT_CHMOD_ROOT" >/dev/null 2>&1
  WRITE_FAILED="false"
  if write_text_target "written-ok.sh" "content" "$TMP/unit-chmod-src.sh"; then
    echo "WRITE_TEXT=succeeded"
  fi
  echo "WRITE_FAILED=$WRITE_FAILED"
)"
assert "control: a normal (non-stubbed) chmod still succeeds and reports no failure" \
  "printf '%s\n' \"\$UNIT_CHMOD_OK_OUT\" | grep -qF 'WRITE_TEXT=succeeded' && printf '%s\n' \"\$UNIT_CHMOD_OK_OUT\" | grep -qF 'WRITE_FAILED=false'"
assert "…and the target really is executable on disk" \
  "[ -x '$UNIT_CHMOD_ROOT/written-ok.sh' ]"

echo ""
echo "E2. high finding: a failed git ls-files enumeration (corrupt index, permission issue) used to read as 'nothing hidden/untracked' and could drive a pristine/REMOVE verdict"
RV6HID="$TMP/rv6-hidden-enum-fail"
mk_rv1_fixture "$RV6HID" sdd-rv6hid
RV6HID_STUBBIN="$TMP/rv6hid-stubbin"
mkdir -p "$RV6HID_STUBBIN"
REALGIT_BIN="$(command -v git)"
cat > "$RV6HID_STUBBIN/git" << STUBEOF
#!/usr/bin/env bash
args=("\$@")
if [ "\${args[0]}" = "-C" ]; then sub="\${args[2]}"; else sub="\${args[0]}"; fi
if [ "\$sub" = "ls-files" ]; then
  for a in "\$@"; do
    if [ "\$a" = "-v" ]; then
      echo "fake git: simulated ls-files -v failure" >&2
      exit 128
    fi
  done
fi
exec "$REALGIT_BIN" "\$@"
STUBEOF
chmod +x "$RV6HID_STUBBIN/git"
assert "control: without the stub, the fixture scans pristine/REMOVE (proves the stub-induced failure below is what flips it, not some unrelated fixture defect)" \
  "python3 -c '
import json, subprocess
out = subprocess.run([\"bash\", \"$RM\", \"scan\", \"--json\", \"--root\", \"$RV6HID\"], capture_output=True, text=True).stdout
d = json.loads(out)
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv6hid\")
assert it[\"state\"] == \"pristine\" and it[\"recommended\"] == \"REMOVE\", it
'"
RV6HID_JSON="$TMP/rv6hid.json"
PATH="$RV6HID_STUBBIN:$PATH" bash "$RM" scan --json --root "$RV6HID" > "$RV6HID_JSON" 2>"$TMP/rv6hid.err"
assert "with git ls-files -v failing: never pristine, never REMOVE — a failed enumeration is refused, not read as clean" \
  "python3 -c '
import json
d = json.load(open(\"$RV6HID_JSON\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv6hid\")
assert it[\"state\"] != \"pristine\", it
assert it[\"recommended\"] != \"REMOVE\", it
assert it[\"remove_command\"] == \"\", it
'"

echo ""
echo "E3. high finding: resolve_state's untracked/ignored git ls-files captures had the identical fail-open gap — a failed enumeration read as 'nothing untracked'"
RV6UNT="$TMP/rv6-untracked-enum-fail"
mk_rv1_fixture "$RV6UNT" sdd-rv6unt
RV6UNT_STUBBIN="$TMP/rv6unt-stubbin"
mkdir -p "$RV6UNT_STUBBIN"
cat > "$RV6UNT_STUBBIN/git" << STUBEOF
#!/usr/bin/env bash
args=("\$@")
if [ "\${args[0]}" = "-C" ]; then sub="\${args[2]}"; else sub="\${args[0]}"; fi
if [ "\$sub" = "ls-files" ]; then
  for a in "\$@"; do
    if [ "\$a" = "--others" ]; then
      echo "fake git: simulated ls-files --others failure" >&2
      exit 128
    fi
  done
fi
exec "$REALGIT_BIN" "\$@"
STUBEOF
chmod +x "$RV6UNT_STUBBIN/git"
RV6UNT_JSON="$TMP/rv6unt.json"
PATH="$RV6UNT_STUBBIN:$PATH" bash "$RM" scan --json --root "$RV6UNT" > "$RV6UNT_JSON" 2>"$TMP/rv6unt.err"
assert "with git ls-files --others failing: never pristine, never REMOVE" \
  "python3 -c '
import json
d = json.load(open(\"$RV6UNT_JSON\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv6unt\")
assert it[\"state\"] != \"pristine\", it
assert it[\"recommended\"] != \"REMOVE\", it
assert it[\"remove_command\"] == \"\", it
'"

echo ""
echo "E4. medium finding: content_matches' glob branch used to report success (rc 0) even when its 'find' pipeline failed partway, indistinguishable from 'nothing matched'"
UNIT_CM_ROOT="$TMP/unit-content-matches-fail"
mkdir -p "$UNIT_CM_ROOT/.logic-loom/lib" "$UNIT_CM_ROOT/docs"
cp "$LIB" "$UNIT_CM_ROOT/.logic-loom/lib/release-migrations.sh"
echo "some text" > "$UNIT_CM_ROOT/docs/note.md"
UNIT_CM_STUBBIN="$TMP/unit-content-matches-stubbin"
mkdir -p "$UNIT_CM_STUBBIN"
REALFIND_BIN="$(command -v find)"
cat > "$UNIT_CM_STUBBIN/find" << STUBEOF
#!/usr/bin/env bash
echo "fake find: simulated partial-enumeration failure" >&2
exit 1
STUBEOF
chmod +x "$UNIT_CM_STUBBIN/find"
UNIT_CM_OUT="$(
  source "$RM" --root "$UNIT_CM_ROOT" >/dev/null 2>&1
  PATH="$UNIT_CM_STUBBIN:$PATH"
  if content_matches "docs/*.md" > "$TMP/unit-cm-stdout.$$" 2>"$TMP/unit-cm-stderr.$$"; then
    echo "CONTENT_MATCHES_RC=0"
  else
    echo "CONTENT_MATCHES_RC=nonzero"
  fi
  rm -f "$TMP/unit-cm-stdout.$$" "$TMP/unit-cm-stderr.$$"
)"
assert "content_matches propagates a failed find's exit status instead of always returning 0" \
  "printf '%s\n' \"\$UNIT_CM_OUT\" | grep -qF 'CONTENT_MATCHES_RC=nonzero'"
# Positive control: without the stubbed find, the same glob still matches normally.
UNIT_CM_OK_OUT="$(
  source "$RM" --root "$UNIT_CM_ROOT" >/dev/null 2>&1
  if content_matches "docs/*.md" > "$TMP/unit-cm-ok.$$" 2>&1; then
    echo "CONTENT_MATCHES_RC=0 MATCHED=$(cat "$TMP/unit-cm-ok.$$")"
  fi
  rm -f "$TMP/unit-cm-ok.$$"
)"
assert "control: without the stub, content_matches succeeds and finds the real file" \
  "printf '%s\n' \"\$UNIT_CM_OK_OUT\" | grep -qF 'docs/note.md'"

echo ""
echo "E5. low finding: '--root' as the LAST argument (no value) used to hang every subcommand's arg-parsing loop forever (bash's shift N > \$# is a silent no-op, not an error)"
# Round-6 REVIEWER: this block used GNU `timeout`, which is not on stock
# macOS (it came from Homebrew coreutils on the machine that wrote it) —
# a suite that claims the bash 3.2 / stock-macOS floor must not depend on
# it, and with `timeout` absent every assertion here failed (rc 127), not
# skipped. Replaced by the pure-bash watchdog below (also used by E8).
# Runs the command in the background, kills it after $1 seconds, and returns
# the command's own status; a command the watchdog had to kill returns 143
# (128+SIGTERM), never the usage-error 1 the callers below look for, so
# "hung" and "refused promptly" stay distinguishable. The watchdog subshell's
# own fds go to /dev/null so a caller capturing this via `$(...)` is not held
# open by the sleeping watchdog after the command has already finished.
rv6_run_with_timeout() {  # $1 = seconds, $2... = command
  local secs="$1"; shift
  "$@" &
  local pid=$!
  ( sleep "$secs"; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local wd=$!
  wait "$pid"; local rc=$?
  kill "$wd" 2>/dev/null; wait "$wd" 2>/dev/null
  return "$rc"
}
for RV6CMD in lint scan plan check-release; do
  RV6ROOT_OUT="$(rv6_run_with_timeout 10 bash "$RM" "$RV6CMD" --root 2>&1)"
  RV6ROOT_RC=$?
  assert "'$RV6CMD --root' with no value terminates promptly (rc $RV6ROOT_RC, not the watchdog's 143) with a usage error" \
    "[ '$RV6ROOT_RC' -eq 1 ] && printf '%s\n' \"\$RV6ROOT_OUT\" | grep -qF -- '--root requires a value'"
done
RV6CONVERT_OUT="$(rv6_run_with_timeout 10 bash "$RM" convert somename --root 2>&1)"
RV6CONVERT_RC=$?
assert "'convert <name> --root' with no value terminates promptly (rc $RV6CONVERT_RC) with a usage error" \
  "[ '$RV6CONVERT_RC' -eq 1 ] && printf '%s\n' \"\$RV6CONVERT_OUT\" | grep -qF -- '--root requires a value'"

echo ""
echo "E6. medium finding (investigated, disposition: documented tradeoff, not a missed defect): ownership is inferred from byte equality, not cryptographically proven — MIGRATION_GUIDE.md's own Trust boundary section already says so in plain language"
MIGRATION_GUIDE="$ROOT/.docs/guides/MIGRATION_GUIDE.md"
assert "MIGRATION_GUIDE.md still carries the 'Trust boundary — the adopt receipt' section" \
  "grep -qF 'Trust boundary — the adopt receipt' '$MIGRATION_GUIDE'"
assert "…and states plainly that none of the three local records is cryptographically signed" \
  "grep -qF 'none of them is' '$MIGRATION_GUIDE' && grep -qi 'cryptographically signed' '$MIGRATION_GUIDE'"
assert "…and states this tool does not invent signing to close that gap (the disclosed limitation, not a silent one)" \
  "tr '\n' ' ' < '$MIGRATION_GUIDE' | grep -qF 'This tool does not invent signing to close that gap.'"
assert "…and documents the corroboration step (digest must ALSO match a blob refs/loom-upstream/main actually shipped) that bounds the practical impact" \
  "grep -qF 'Corroborate the digest against' '$MIGRATION_GUIDE'"

# ═══════════════════════════════════════════════════════════════════════════
# SECTION E addendum — REVIEWER round 6 (post round-6 builder). Every block
# below was first reproduced as a live defect against the round's starting
# tree — a REMOVE / `git rm` recommendation printed over bytes this tool
# never proved LogicLoom's, or a `convert` that never returns — then closed;
# each carries its reproduction inline. Fixtures reuse mk_rv1_fixture (above);
# rv6_run_with_timeout is defined at E5 above.
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "E7. HIGH (governing principle): the pristine test trusted the customer's own external diff driver / textconv — an EDITED tracked file read as pristine and got REMOVE"
# Reproduction on the starting tree (git 2.54): `git diff --quiet <base> --
# <path>` honours GIT_EXTERNAL_DIFF (env), diff.external (config) and a
# .gitattributes diff=<driver> (command or textconv) — when the driver's
# exit code is trusted (GIT_EXTERNAL_DIFF_TRUST_EXIT_CODE / diff.trustExitCode
# / diff.<driver>.trustExitCode), or for textconv even without that, git
# reports "no difference" for a file whose bytes DO differ. resolve_state
# then said pristine, changed_files [], REMOVE, `git rm -r plugins/<p>`,
# and the plan's "recoverable: removing a pristine path never loses bytes"
# line — over a customer edit. (`git rm` itself refuses a locally modified
# file, so the printed command stops short of deleting; the recommendation
# is the harm the governing principle names.) Nothing the customer set is
# wrong: external diffs are ordinary git usage. Closed by passing
# `--no-ext-diff --no-textconv` on every `git diff` this script runs for a
# decision — the comparison must be git's own blob-id compare, never a
# helper's opinion.
RV6EXT="$TMP/rv6-external-diff"
mk_rv1_fixture "$RV6EXT" sdd-rv6ext
RV6EXT_EDITED="plugins/sdd-rv6ext/commands/sdd-rv6ext-cmd.md"
echo "customer edit after adoption" >> "$RV6EXT/$RV6EXT_EDITED"
RV6EXT_LIAR="$TMP/rv6-liar-diff"
printf '#!/bin/sh\nexit 0\n' > "$RV6EXT_LIAR"; chmod +x "$RV6EXT_LIAR"
RV6EXT_TCONV="$TMP/rv6-liar-textconv"
printf '#!/bin/sh\necho same-for-everything\n' > "$RV6EXT_TCONV"; chmod +x "$RV6EXT_TCONV"
rv6_ext_check() {  # $1 = json file, $2 = label
  python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
it = next(i for i in d['items'] if i['path'] == 'plugins/sdd-rv6ext')
assert it['state'] != 'pristine', it
assert it['recommended'] != 'REMOVE', it
assert it['remove_command'] == '', it
assert sys.argv[2] in it['changed_files'], it
" "$1" "$RV6EXT_EDITED"
}
# (a) the environment-variable route, exactly as a shell that exports
#     GIT_EXTERNAL_DIFF=<tool> for every git command would present it
if GIT_EXTERNAL_DIFF="$RV6EXT_LIAR" GIT_EXTERNAL_DIFF_TRUST_EXIT_CODE=true git -C "$RV6EXT" diff --quiet HEAD -- plugins/sdd-rv6ext 2>/dev/null; then
  echo "  (this git honours a trusted external diff for --quiet: the pre-fix defect is provokable here)"
else
  skip "E7 reproduction note: this git version does not consult a trusted external diff for --quiet, so the pre-fix defect cannot be provoked on it — the assertions below still hold, but prove only the fixed behaviour"
fi
GIT_EXTERNAL_DIFF="$RV6EXT_LIAR" GIT_EXTERNAL_DIFF_TRUST_EXIT_CODE=true bash "$RM" scan --json --root "$RV6EXT" > "$TMP/rv6ext-env.json" 2>"$TMP/rv6ext-env.err"
assert "GIT_EXTERNAL_DIFF (trusted exit code) in the environment: the edited file is still customized, never pristine/REMOVE, and is named under changed_files" \
  "rv6_ext_check '$TMP/rv6ext-env.json' env"
# (b) the repo-config route (diff.external + diff.trustExitCode)
git -C "$RV6EXT" config diff.external "$RV6EXT_LIAR"
git -C "$RV6EXT" config diff.trustExitCode true
bash "$RM" scan --json --root "$RV6EXT" > "$TMP/rv6ext-cfg.json" 2>"$TMP/rv6ext-cfg.err"
assert "diff.external + diff.trustExitCode in the repository's own config: still customized, never pristine/REMOVE" \
  "rv6_ext_check '$TMP/rv6ext-cfg.json' config"
git -C "$RV6EXT" config --unset diff.external
git -C "$RV6EXT" config --unset diff.trustExitCode
# (c) the .gitattributes route: a diff=<driver> textconv (no trustExitCode
#     needed — a lossy converter that renders two different files to the same
#     text is enough). .gitattributes sits at the repo root, outside the
#     item's path, so it is not itself what flips the verdict.
echo "* diff=rv6tc" > "$RV6EXT/.gitattributes"
git -C "$RV6EXT" config diff.rv6tc.textconv "$RV6EXT_TCONV"
bash "$RM" scan --json --root "$RV6EXT" > "$TMP/rv6ext-attr.json" 2>"$TMP/rv6ext-attr.err"
assert ".gitattributes diff=<driver> with a lossy textconv: still customized, never pristine/REMOVE" \
  "rv6_ext_check '$TMP/rv6ext-attr.json' attr"
git -C "$RV6EXT" config --unset diff.rv6tc.textconv
rm -f "$RV6EXT/.gitattributes"
# (d) control: with no lying driver at all the same edit was ALWAYS caught,
#     so the three assertions above test the driver routes, not the edit.
bash "$RM" scan --json --root "$RV6EXT" > "$TMP/rv6ext-ctl.json" 2>"$TMP/rv6ext-ctl.err"
assert "control: with no external diff configured the edit is caught the ordinary way (customized, named under changed_files)" \
  "rv6_ext_check '$TMP/rv6ext-ctl.json' control"
# (e) source pin, independent of which git is installed: every `git diff`
#     this script runs carries both flags — a future call site cannot
#     silently reopen the route.
RV6_DIFF_SITES="$(grep -c 'git -C "\$REPO_ROOT" diff ' "$RM" | tr -d ' ')"
RV6_DIFF_GUARDED="$(grep -c 'git -C "\$REPO_ROOT" diff --no-ext-diff --no-textconv ' "$RM" | tr -d ' ')"
assert "source pin: every git diff call site in release-migrations.sh passes --no-ext-diff --no-textconv ($RV6_DIFF_GUARDED of $RV6_DIFF_SITES)" \
  "[ '$RV6_DIFF_SITES' -gt 0 ] && [ '$RV6_DIFF_SITES' -eq '$RV6_DIFF_GUARDED' ]"

echo ""
echo "E8. MEDIUM (hang, leaked process): a named pipe at plugin root made convert block forever"
# Reproduction on the starting tree: convert_hooks_and_support's generic
# plugin-root walk treated every non-directory, non-symlink entry as a
# regular file and ran `grep -Iq .` on it to decide text-vs-binary — on a
# FIFO that open() blocks until a writer appears, i.e. forever; killing the
# convert left that grep orphaned, still blocked on the pipe. Closed by
# converting only regular files (`-f`) from the plugin root and leaving
# anything else for unconverted_plugin_files' `! -type d` walk to report,
# the same "never converted, listed under Not carried over" contract a
# symlink already has.
RV6FIFO="$TMP/rv6-fifo-root"
mk_rv1_fixture "$RV6FIFO" sdd-rv6fifo
mkfifo "$RV6FIFO/plugins/sdd-rv6fifo/customer.pipe"
rv6_run_with_timeout 15 bash "$RM" convert sdd-rv6fifo --dry-run --root "$RV6FIFO" > "$TMP/rv6fifo.out" 2>&1
RV6FIFO_RC=$?
# Drain any reader the pre-fix code left blocked on the pipe: a writer's
# open() completes only when a reader is waiting, so background it and
# kill it if (post-fix) nothing ever opened the pipe.
( : > "$RV6FIFO/plugins/sdd-rv6fifo/customer.pipe" ) >/dev/null 2>&1 &
RV6FIFO_DRAIN=$!
sleep 1; kill "$RV6FIFO_DRAIN" 2>/dev/null; wait "$RV6FIFO_DRAIN" 2>/dev/null
assert "convert --dry-run terminates on its own with a FIFO at plugin root (rc $RV6FIFO_RC; 143 would mean the watchdog had to kill it)" \
  "[ '$RV6FIFO_RC' -ne 143 ] && [ '$RV6FIFO_RC' -ne 137 ]"
assert "…completes (rc 0 — an unconvertible entry is not a STOP, same as a symlink) and prints the machine-stable NOT-accounted line (the pipe is never converted)" \
  "[ '$RV6FIFO_RC' -eq 0 ] && grep -qxF 'accounted: NOT every file under plugins/sdd-rv6fifo is carried over by this conversion' '$TMP/rv6fifo.out'"
assert "…and names the pipe under 'Not carried over' so the delete step is withheld" \
  "grep -qF 'plugins/sdd-rv6fifo/customer.pipe' '$TMP/rv6fifo.out' && grep -qF 'Next steps: DO NOT delete plugins/sdd-rv6fifo yet.' '$TMP/rv6fifo.out'"
assert "…while the plugin's real files are still planned (the pipe is not collateral damage)" \
  "grep -qF 'WRITE .claude/skills/sdd-rv6fifo/SKILL.md <- plugins/sdd-rv6fifo/skills/sdd-rv6fifo/SKILL.md' '$TMP/rv6fifo.out'"

echo ""
echo "E9. LOW (parity with the round-2 empty-directory finding, scan side): git's untracked listing never lists a named pipe/socket/device or an empty directory, so scan read a plugin holding one as pristine/REMOVE"
# Reproduction on the starting tree: `git ls-files --others` (with or without
# --ignored) drops every entry that is not a regular file, symlink or
# directory (dir.c treats them as path_none) and cannot list an empty
# directory at all; `git diff` is clean. So plugins/<p>/commands/customer.pipe
# and plugins/<p>/scratch/ (empty) were invisible: state pristine, added_files
# [], REMOVE, `git rm -r plugins/<p>`. `git rm -r` leaves both behind (they
# hold no tracked bytes), so nothing is lost — but the recommendation claims
# the directory holds nothing but LogicLoom's bytes when it also holds a
# node this tool never created and never saw, the exact class the round-2
# empty-directory finding closed on the convert side ("nothing converts or
# lists it either"). Closed in _loom_rm_git_blind_spots, the one helper both
# resolve_state and the converted-plugin status read: both are now listed
# under `added`, so the item is customized and the user is asked.
RV6SP="$TMP/rv6-special-under-plugin"
mk_rv1_fixture "$RV6SP" sdd-rv6sp
mkfifo "$RV6SP/plugins/sdd-rv6sp/commands/customer.pipe"
assert "sanity: git's own listings are blind to the pipe (the blind spot this block closes)" \
  "[ -z \"\$(git -C '$RV6SP' ls-files --others --ignored --exclude-standard -- plugins/sdd-rv6sp 2>/dev/null)\" ] && [ -z \"\$(git -C '$RV6SP' ls-files --others --exclude-standard -- plugins/sdd-rv6sp 2>/dev/null)\" ] && git -C '$RV6SP' diff --quiet HEAD -- plugins/sdd-rv6sp"
bash "$RM" scan --json --root "$RV6SP" > "$TMP/rv6sp.json" 2>"$TMP/rv6sp.err"
assert "a named pipe under plugins/<p>: never pristine, never REMOVE, and the pipe is named under added_files" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv6sp.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv6sp\")
assert it[\"state\"] != \"pristine\", it
assert it[\"recommended\"] != \"REMOVE\", it
assert it[\"remove_command\"] == \"\", it
assert any(a.startswith(\"plugins/sdd-rv6sp/commands/customer.pipe\") for a in it[\"added_files\"]), it
'"
RV6ED="$TMP/rv6-emptydir-under-plugin"
mk_rv1_fixture "$RV6ED" sdd-rv6ed
mkdir "$RV6ED/plugins/sdd-rv6ed/scratch"
assert "sanity: git's own listings are blind to the empty directory too" \
  "[ -z \"\$(git -C '$RV6ED' ls-files --others --exclude-standard -- plugins/sdd-rv6ed 2>/dev/null)\" ] && git -C '$RV6ED' diff --quiet HEAD -- plugins/sdd-rv6ed"
bash "$RM" scan --json --root "$RV6ED" > "$TMP/rv6ed.json" 2>"$TMP/rv6ed.err"
assert "an empty directory under plugins/<p>: never pristine, never REMOVE, and the directory is named under added_files" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv6ed.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv6ed\")
assert it[\"state\"] != \"pristine\", it
assert it[\"recommended\"] != \"REMOVE\", it
assert any(a.startswith(\"plugins/sdd-rv6ed/scratch/\") for a in it[\"added_files\"]), it
'"
# Positive control: the same fixture with the node removed is pristine again
# — the new listing does not over-refuse an ordinary plugin.
rm -f "$RV6SP/plugins/sdd-rv6sp/commands/customer.pipe"
bash "$RM" scan --json --root "$RV6SP" > "$TMP/rv6sp-ctl.json" 2>"$TMP/rv6sp-ctl.err"
assert "control: with the pipe removed the plugin reads pristine/REMOVE again" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv6sp-ctl.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv6sp\")
assert it[\"state\"] == \"pristine\" and it[\"recommended\"] == \"REMOVE\", it
'"

# ═══════════════════════════════════════════════════════════════════════════
# SECTION F — round-7 (loop round 1). Every block below was reproduced
# against the starting tree (assertions FAIL there), then closed.
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  F. Round-7 review findings"
echo "═══════════════════════════════════════════════════════════"

echo ""
echo "F1. low finding: the EXIT cleanup's final 'rm -rf' of the proof base had no boundary check beyond 'not a symlink' — a base that is not the mktemp directory this run created is now refused"
# _loom_rm_cleanup removes $_LOOM_RM_PROOF_BASE wholesale. The per-entry
# loop is guarded by _loom_rm_safe_to_remove; the base itself was guarded
# only by -d / ! -L. A check-then-rm is inherently two operations in
# portable bash, so the race cannot be closed outright, but the base can be
# required to look like exactly what _loom_rm_proof_base creates (a direct
# mktemp child named loom-rm-fixtureproof-base.*, owned by this user) so a
# corrupted/overwritten variable can never aim `rm -rf` at an arbitrary
# directory.
F1_VICTIM="$TMP/rv7-not-our-base"
mkdir -p "$F1_VICTIM/inner"
echo "customer bytes" > "$F1_VICTIM/inner/f"
F1_OUT="$(
  source "$RM" --root "$UNIT_CHMOD_ROOT" >/dev/null 2>&1
  _LOOM_RM_PROOF_BASE="$F1_VICTIM"
  _LOOM_RM_PROOF_TMP_DIRS=""
  _loom_rm_cleanup
  if [ -e "$F1_VICTIM/inner/f" ]; then echo "VICTIM=survived"; else echo "VICTIM=deleted"; fi
  _LOOM_RM_PROOF_BASE=""
)"
assert "cleanup refuses to rm -rf a proof base that is not a loom-rm-fixtureproof-base.* mktemp directory" \
  "printf '%s\n' \"\$F1_OUT\" | grep -qF 'VICTIM=survived'"
F1_CTL_OUT="$(
  source "$RM" --root "$UNIT_CHMOD_ROOT" >/dev/null 2>&1
  _loom_rm_proof_base >/dev/null
  _b="$_LOOM_RM_PROOF_BASE"
  mkdir -p "$_b/child"; echo x > "$_b/child/f"
  _LOOM_RM_PROOF_TMP_DIRS="$_b/child"
  _loom_rm_cleanup
  if [ -e "$_b" ]; then echo "BASE=left"; else echo "BASE=removed"; fi
  _LOOM_RM_PROOF_BASE=""
)"
assert "control: a genuine mktemp-created proof base (and its children) is still fully cleaned up" \
  "printf '%s\n' \"\$F1_CTL_OUT\" | grep -qF 'BASE=removed'"

echo ""
echo "F2. low finding: after the plugin source is edited and 'convert --apply' re-run, the (never-rewritten) CONVERTED.md still says 'delete' — the run must now say so, loudly, without rewriting the file"
RV7K="$TMP/rv7-converted-md-stale"
mk_rv2_fixture "$RV7K" sdd-rv7k
RV7K_RUN1="$(bash "$RM" convert sdd-rv7k --apply --root "$RV7K" 2>&1)"
RV7K_CONVERTED="$RV7K/.claude/skills/sdd-rv7k/CONVERTED.md"
assert "control: the first (clean) convert --apply emits no stale-record NOTE" \
  "! printf '%s\n' \"\$RV7K_RUN1\" | grep -q '^NOTE '"
assert "sanity: the first run's CONVERTED.md recommends delete" \
  "grep -qF 'delete plugins/sdd-rv7k once its converted' '$RV7K_CONVERTED'"
( cd "$RV7K" && git add -A >/dev/null && git commit -q -m converted ) >/dev/null 2>&1
RV7K_RUN1B="$(bash "$RM" convert sdd-rv7k --apply --root "$RV7K" 2>&1)"
assert "control: an unchanged re-run (every target SKIP) emits no NOTE either" \
  "! printf '%s\n' \"\$RV7K_RUN1B\" | grep -q '^NOTE '"
RV7K_CKSUM1="$(cksum "$RV7K_CONVERTED")"
echo "echo RV7K-SOURCE-EDIT" >> "$RV7K/plugins/sdd-rv7k/hooks/h.sh"
RV7K_RUN2="$(bash "$RM" convert sdd-rv7k --apply --root "$RV7K" 2>&1)"
assert "the re-run after a source edit prints a NOTE naming CONVERTED.md as STALE (its 'delete' line is no longer current)" \
  "printf '%s\n' \"\$RV7K_RUN2\" | grep -q '^NOTE .claude/skills/sdd-rv7k/CONVERTED.md' && printf '%s\n' \"\$RV7K_RUN2\" | grep '^NOTE ' | grep -qF 'STALE'"
assert "…and points at DO NOT delete / scan for the current recommendation" \
  "printf '%s\n' \"\$RV7K_RUN2\" | grep '^NOTE ' | grep -qF 'DO NOT delete' && printf '%s\n' \"\$RV7K_RUN2\" | grep '^NOTE ' | grep -qF 'scan --json'"
assert "…while CONVERTED.md itself is still byte-for-byte unchanged (the ledger and its dating stay frozen; the record may be the customer's to edit)" \
  "[ '$RV7K_CKSUM1' = \"\$(cksum '$RV7K_CONVERTED')\" ]"
RV7K_SCAN="$(bash "$RM" scan --root "$RV7K" 2>&1)"
assert "…and the live scan path still says KEEP-AS-IS (the NOTE line is not mistaken for a re-render difference)" \
  "printf '%s\n' \"\$RV7K_SCAN\" | grep -qF 'recommended: KEEP-AS-IS' && ! printf '%s\n' \"\$RV7K_SCAN\" | grep -qF 'recommended: REMOVE'"

echo ""
echo "F3. low finding: '--registry' / '--since' as the LAST argument die with a raw 'unbound variable' shell error instead of a usage error (--root was fixed in round 6, its siblings were not)"
for RV7CMD in lint scan plan check-release; do
  RV7R_OUT="$(rv6_run_with_timeout 10 bash "$RM" "$RV7CMD" --registry 2>&1)"
  RV7R_RC=$?
  assert "'$RV7CMD --registry' with no value: clean usage error (rc 1, '--registry requires a value', no shell 'unbound variable')" \
    "[ '$RV7R_RC' -eq 1 ] && printf '%s\n' \"\$RV7R_OUT\" | grep -qF -- '--registry requires a value' && ! printf '%s\n' \"\$RV7R_OUT\" | grep -qF 'unbound variable'"
done
RV7C_OUT="$(rv6_run_with_timeout 10 bash "$RM" convert somename --registry 2>&1)"
RV7C_RC=$?
assert "'convert <name> --registry' with no value: clean usage error" \
  "[ '$RV7C_RC' -eq 1 ] && printf '%s\n' \"\$RV7C_OUT\" | grep -qF -- '--registry requires a value' && ! printf '%s\n' \"\$RV7C_OUT\" | grep -qF 'unbound variable'"
RV7S_OUT="$(rv6_run_with_timeout 10 bash "$RM" check-release --since 2>&1)"
RV7S_RC=$?
assert "'check-release --since' with no value: clean usage error" \
  "[ '$RV7S_RC' -eq 1 ] && printf '%s\n' \"\$RV7S_OUT\" | grep -qF -- '--since requires a value' && ! printf '%s\n' \"\$RV7S_OUT\" | grep -qF 'unbound variable'"

echo ""
echo "F4. HIGH (governing principle, loop-round-1 REVIEWER): a git clean filter (nbstripout / git-lfs / git-crypt / any filter.<driver>.clean) hid a working-tree edit from the pristine test — the edited file read as pristine and got REMOVE"
# Reproduction on the starting tree (git 2.54): `git diff --quiet <base> --
# <path>` compares the base blob against the working-tree file AS GIT READS
# IT — through the file's `filter=<driver>` clean command — so an edit the
# filter strips (a notebook's re-run cell outputs under nbstripout, a value
# a redaction filter blanks) hashes straight back to the tracked blob:
# state pristine, changed_files [], REMOVE, `git rm -r plugins/<p>` printed
# over a customer edit. E7's `--no-ext-diff --no-textconv` does not reach
# this: a clean filter is content conversion, not a diff helper. (`git
# status` / `git rm` flagged the file in the reproduction only because its
# SIZE changed — read-cache.c's sd_size shortcut — so a same-size edit would
# not even be refused by the printed command.) Nothing the customer set is
# wrong: clean filters are ordinary git usage. Closed by
# _loom_rm_filtered_paths: every TRACKED file under the item that carries a
# `filter` attribute (git check-attr, read-only) is listed under `changed`
# and the item is customized — doubt -> KEEP and ASK.
RV7F="$TMP/rv7-clean-filter"
mk_rv1_fixture "$RV7F" sdd-rv7f
RV7F_EDITED="plugins/sdd-rv7f/commands/sdd-rv7f-cmd.md"
printf '# LOCAL: customer edit the clean filter strips\n' >> "$RV7F/$RV7F_EDITED"
rv7f_check() {  # $1 = json file; the edited file must be customized and named under changed_files (an entry may carry a trailing " (reason)")
  python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
it = next(i for i in d['items'] if i['path'] == 'plugins/sdd-rv7f')
assert it['state'] != 'pristine', it
assert it['recommended'] != 'REMOVE', it
assert it['remove_command'] == '', it
assert any(c == sys.argv[2] or c.startswith(sys.argv[2] + ' ') for c in it['changed_files']), it
" "$1" "$RV7F_EDITED"
}
# (a) the purely local route: .git/info/attributes + filter.<d>.clean in the
#     repository's own config — nothing in the working tree hints at it
echo "$RV7F_EDITED filter=rv7strip" > "$RV7F/.git/info/attributes"
git -C "$RV7F" config filter.rv7strip.clean "sed '/^# LOCAL:/d'"
if git -C "$RV7F" diff --no-ext-diff --no-textconv --quiet HEAD -- plugins/sdd-rv7f 2>/dev/null; then
  echo "  (this git reads the working tree through the clean filter for --quiet: the pre-fix defect is provokable here)"
else
  skip "F4 reproduction note: this git version does not apply the clean filter in diff --quiet, so the pre-fix defect cannot be provoked on it — the assertions below still hold, but prove only the fixed behaviour"
fi
bash "$RM" scan --json --root "$RV7F" > "$TMP/rv7f-local.json" 2>"$TMP/rv7f-local.err"
assert ".git/info/attributes filter=<driver> + filter.<driver>.clean: the edited file is customized, never pristine/REMOVE, and is named under changed_files" \
  "rv7f_check '$TMP/rv7f-local.json'"
assert "…and the entry names the filter by driver, so the user knows WHY git diff cannot see the edit" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv7f-local.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv7f\")
assert any(\"filter=rv7strip\" in c for c in it[\"changed_files\"]), it
'"
RV7F_PLAN="$(bash "$RM" plan sdd-rv7f --root "$RV7F" 2>&1)"
assert "…and plan prints no git rm line for it (recommended: CONVERT-TO-LOCAL)" \
  "! printf '%s\n' \"\$RV7F_PLAN\" | grep -q 'git rm' && printf '%s\n' \"\$RV7F_PLAN\" | grep -q 'recommended: CONVERT-TO-LOCAL'"
rm -f "$RV7F/.git/info/attributes"
# (b) the tracked .gitattributes route (committed, so it is in HEAD; the
#     attributes file sits at the repo root, outside the item's path, so it
#     is not itself what flips the verdict)
echo "$RV7F_EDITED filter=rv7strip" > "$RV7F/.gitattributes"
( cd "$RV7F" && git add .gitattributes >/dev/null && git commit -q -m attrs ) >/dev/null 2>&1
bash "$RM" scan --json --root "$RV7F" > "$TMP/rv7f-tracked.json" 2>"$TMP/rv7f-tracked.err"
assert "a committed .gitattributes filter=<driver>: still customized, never pristine/REMOVE" \
  "rv7f_check '$TMP/rv7f-tracked.json'"
rm -f "$RV7F/.gitattributes"
( cd "$RV7F" && git add -A >/dev/null && git commit -q -m unattrs ) >/dev/null 2>&1
git -C "$RV7F" config --unset filter.rv7strip.clean
# (c) control: with no filter at all the same edit was ALWAYS caught, so
#     (a)/(b) test the filter route, not the edit
bash "$RM" scan --json --root "$RV7F" > "$TMP/rv7f-ctl.json" 2>"$TMP/rv7f-ctl.err"
assert "control: with no filter configured the edit is caught the ordinary way (customized, named under changed_files)" \
  "rv7f_check '$TMP/rv7f-ctl.json'"
# (d) what is NOT flagged — a `-filter` (explicitly unset) attribute and the
#     unspecified default — so the check cannot creep into refusing every
#     repository that mentions `filter` somewhere: a pristine plugin stays
#     pristine/REMOVE under it
RV7G="$TMP/rv7-clean-filter-pristine"
mk_rv1_fixture "$RV7G" sdd-rv7g
rv7g_json() {  # $1 = json file, $2 = expected state, $3 = expected recommended
  python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
it = next(i for i in d['items'] if i['path'] == 'plugins/sdd-rv7g')
assert it['state'] == sys.argv[2], it
assert it['recommended'] == sys.argv[3], it
" "$1" "$2" "$3"
}
echo "plugins/sdd-rv7g/commands/sdd-rv7g-cmd.md -filter" > "$RV7G/.git/info/attributes"
bash "$RM" scan --json --root "$RV7G" > "$TMP/rv7g-unset.json" 2>"$TMP/rv7g-unset.err"
assert "control: a pristine plugin whose file carries '-filter' (the attribute explicitly UNSET, so git applies no filter) still scans pristine/REMOVE" \
  "rv7g_json '$TMP/rv7g-unset.json' pristine REMOVE"
# (e) …but a bare `filter` (set, no driver) IS refused: git itself ignores
#     a driverless `filter`, yet refusing it costs nothing and keeps the
#     rule one line — any driver-shaped value is doubt, and doubt is KEEP
echo "plugins/sdd-rv7g/commands/sdd-rv7g-cmd.md filter" > "$RV7G/.git/info/attributes"
bash "$RM" scan --json --root "$RV7G" > "$TMP/rv7g-set.json" 2>"$TMP/rv7g-set.err"
assert "a bare 'filter' attribute (set, no driver named) on an otherwise pristine plugin: customized, never REMOVE — the file is listed under changed_files" \
  "rv7g_json '$TMP/rv7g-set.json' customized CONVERT-TO-LOCAL && python3 -c '
import json
d = json.load(open(\"$TMP/rv7g-set.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv7g\")
assert any(c.startswith(\"plugins/sdd-rv7g/commands/sdd-rv7g-cmd.md \") for c in it[\"changed_files\"]), it
assert it[\"remove_command\"] == \"\", it
'"
rm -f "$RV7G/.git/info/attributes"
# (f) the enumeration-failure route (same fail-closed class as E2/E3): a
#     `git check-attr` that cannot run proves nothing about filters, so the
#     path is refused, never read as "no filter applies"
RV7F_STUBBIN="$TMP/rv7f-stubbin"
mkdir -p "$RV7F_STUBBIN"
RV7F_REALGIT="$(command -v git)"
cat > "$RV7F_STUBBIN/git" << STUBEOF
#!/usr/bin/env bash
args=("\$@")
if [ "\${args[0]}" = "-C" ]; then sub="\${args[2]}"; else sub="\${args[0]}"; fi
if [ "\$sub" = "check-attr" ]; then
  echo "fake git: simulated check-attr failure" >&2
  exit 128
fi
exec "$RV7F_REALGIT" "\$@"
STUBEOF
chmod +x "$RV7F_STUBBIN/git"
PATH="$RV7F_STUBBIN:$PATH" bash "$RM" scan --json --root "$RV7G" > "$TMP/rv7g-attrfail.json" 2>"$TMP/rv7g-attrfail.err"
assert "with git check-attr failing: the (otherwise pristine) plugin is never pristine/REMOVE — a failed attribute check is refused, not read as 'no filter applies'" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv7g-attrfail.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv7g\")
assert it[\"state\"] != \"pristine\", it
assert it[\"recommended\"] != \"REMOVE\", it
assert it[\"remove_command\"] == \"\", it
assert any(\"could not check git attributes\" in c for c in it[\"changed_files\"]), it
'"
# (g) the converted-plugin status has the same blob compare ("unchanged
#     since the decision commit") and the same hole — closed at that call
#     site too, before the re-render gate, so the reason is the direct
#     "edited after conversion" one, not a render-stale fallback
RV7FC="$TMP/rv7-clean-filter-converted"
mk_rv2_fixture "$RV7FC" sdd-rv7fc
bash "$RM" convert sdd-rv7fc --apply --root "$RV7FC" >/dev/null 2>&1
( cd "$RV7FC" && git add -A >/dev/null && git commit -q -m converted ) >/dev/null 2>&1
echo "plugins/sdd-rv7fc/hooks/h.sh filter=rv7strip" > "$RV7FC/.git/info/attributes"
git -C "$RV7FC" config filter.rv7strip.clean "sed '/^# LOCAL:/d'"
printf '# LOCAL: post-conversion edit the clean filter strips\n' >> "$RV7FC/plugins/sdd-rv7fc/hooks/h.sh"
bash "$RM" scan --json --root "$RV7FC" > "$TMP/rv7fc.json" 2>"$TMP/rv7fc.err"
assert "converted-plugin status: a filtered file under the plugin is 'edited after conversion' (changed:), KEEP-AS-IS, no remove command — not merely caught downstream as render-stale" \
  "python3 -c '
import json
d = json.load(open(\"$TMP/rv7fc.json\"))
it = next(i for i in d[\"items\"] if i[\"path\"] == \"plugins/sdd-rv7fc\")
assert it[\"decision\"] == \"converted\", it
assert it[\"recommended\"] == \"KEEP-AS-IS\", it
assert it[\"remove_command\"] == \"\", it
assert \"edited after conversion\" in it[\"reason\"], it
assert \"clean filter\" in it[\"reason\"], it
'"
# (h) source pins, independent of which git is installed: both blob-compare
#     sites consult the helper, and the helper never masks the enumeration's
#     own exit status
RV7F_CALLS="$(grep -c '_loom_rm_filtered_paths "\$path"' "$RM" | tr -d ' ')"
assert "source pin: _loom_rm_filtered_paths is consulted at both blob-compare sites (resolve_state and the converted-plugin status) — $RV7F_CALLS call sites" \
  "[ '$RV7F_CALLS' -ge 2 ]"
assert "source pin: the helper returns the ls-files|check-attr pipeline's own status (no unconditional 'return 0' after the capture)" \
  "sed -n '/^_loom_rm_filtered_paths()/,/^}/p' '$RM' | grep -q 'return \"\$_fp_rc\"'"
# (i) prose pin: MIGRATION_GUIDE.md tells the user a clean filter makes a
#     file never-pristine, next to the external-diff rule it extends
assert "MIGRATION_GUIDE.md documents the clean-filter rule (filter=<driver> is never pristine) beside the --no-ext-diff rule" \
  "grep -qF 'filter=<driver>' '$ROOT/.docs/guides/MIGRATION_GUIDE.md' && tr '\n' ' ' < '$ROOT/.docs/guides/MIGRATION_GUIDE.md' | tr -s ' ' | grep -qi 'runs the clean filter when it reads the working-tree file'"

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  RESULTS: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
echo "═══════════════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ]
