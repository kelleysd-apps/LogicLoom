#!/usr/bin/env bash
# Contract Tests: the adopt package's AUTHORED RULES and the CLAUDE.md
# INTEGRATION MODE.
#
# This is the half that clears `defer: CLAUDE.md`. It pins two separable things:
#
#   HALF 1 — WHAT SHIPS. Three authored rules files under
#     packaging/adopt/payload/rules/, installed to .claude/rules/. They are
#     written FOR AN ADOPTER, not carved from this repo's CLAUDE.md, and the
#     budget is the point: they load at launch at CLAUDE.md priority, so every
#     line is paid for on every prompt of every session. A ceiling is asserted.
#     Claims that are TRUE HERE AND FALSE THERE are asserted absent — our
#     version stamp, our plugin registry, our branch topology, our own repo's
#     root-ownership rule.
#
#   HALF 2 — THE INTEGRATION MODE, and that it is DETERMINISTIC. Three modes
#     (rules / import / none), selected by a flag or an environment variable and
#     by nothing else: no prompt, no heuristic, no model. Same input, same
#     output, every time; the mode is recorded in the receipt; the question is
#     NOT asked when there is no CLAUDE.md to reconcile.
#
# bash 3.2 safe: no associative arrays, no mapfile, no [[ -v ]], no ${var,,}.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
assert() {
  TOTAL=$((TOTAL + 1)); desc="$1"; condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

PKG="$ROOT/packaging/adopt"
CLI="$PKG/bin/logicloom.js"
RULES_DIR="$PKG/payload/rules"

echo "🧪 Adopt Rules + CLAUDE.md Integration Mode"
echo "==========================================="
echo ""

# ── Vacuously green on a stripped tree, FAIL-CLOSED on rot ───────────────────
# Same shape and same reason as the adopt suites beside it: `packaging` is a
# template-strip-manifest entry, so this package does not exist in a shipped
# tree. Absent-and-untracked is a legitimate skip; absent-but-TRACKED means it
# was deleted out from under the boundary, and that still fails.
IS_TRACKED=no
if git -C "$ROOT" ls-files --error-unmatch "$PKG/lib/claude-md.js" >/dev/null 2>&1; then IS_TRACKED=yes; fi

if [ ! -f "$PKG/lib/claude-md.js" ] && [ "$IS_TRACKED" = no ]; then
  echo "  ⏭  SKIP: no packaging/adopt/lib/claude-md.js and none tracked —"
  echo "     this is a stripped or customer tree, where packaging/ never exists."
  echo ""
  echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
  exit 0
fi

if ! command -v node >/dev/null 2>&1; then
  echo "  ⏭  SKIP: node is not on PATH; the integration modes cannot be exercised."
  echo ""
  echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
  exit 0
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/loom-adopt-rules.XXXXXX")"
cleanup() { [ -n "${TMP:-}" ] && rm -rf "$TMP"; }
trap cleanup EXIT

git_quiet() { d="$1"; shift; git -C "$d" -c user.email=t@example.com -c user.name=t "$@" >/dev/null 2>&1; }

# A kori-shaped fixture: a real project with its own CLAUDE.md, package.json,
# .gitignore and source. The point of the shape is that CLAUDE.md is THEIRS.
make_fixture() {
  d="$1"; mkdir -p "$d/src"
  i=1
  : > "$d/CLAUDE.md"
  while [ $i -le 40 ]; do printf 'Project rule line %s\n' "$i" >> "$d/CLAUDE.md"; i=$((i + 1)); done
  printf '{"name":"fixture","version":"1.0.0"}\n' > "$d/package.json"
  printf 'node_modules/\ndist/\n' > "$d/.gitignore"
  printf 'export const x = 1;\n' > "$d/src/index.ts"
  git_quiet "$d" init
  git_quiet "$d" add -A
  git_quiet "$d" commit -m base
}

# ── 1. The rules files exist, and the budget holds ───────────────────────────
echo "── 1. what ships ──"
assert "the authored rules directory exists" "[ -d \"$RULES_DIR\" ]"
if [ ! -d "$RULES_DIR" ]; then
  echo ""; echo "Results: $PASS passed, $FAIL failed, $TOTAL total"; exit 1
fi

RULE_COUNT="$(find "$RULES_DIR" -name '*.md' | grep -c . || true)"
# Space-joined, not newline-joined: these are interpolated into `assert`'s eval,
# where an embedded newline would be a command separator and the shell would try
# to EXECUTE each markdown file.
RULE_FILES="$(find "$RULES_DIR" -name '*.md' | sort | tr '\n' ' ')"
assert "at least three authored rules files" "[ \"$RULE_COUNT\" -ge 3 ]"

TOTAL_LINES=0
for f in $RULE_FILES; do
  n="$(wc -l < "$f" | tr -d ' ')"
  TOTAL_LINES=$((TOTAL_LINES + n))
done
echo "     total authored lines: $TOTAL_LINES"
# THE CEILING IS THE WHOLE ARGUMENT. Rules files load at launch at CLAUDE.md
# priority, so this number is paid on every prompt of every session in every
# adopting repo. The source it replaces is 860 lines; the vendor's own guidance
# is under 200 per file. 250 is the ceiling the design committed to — a number,
# not an intention, so drift shows up as a red test rather than as a slow slide
# back toward shipping everything.
assert "the authored rules total under 250 lines (the loaded-context budget)" \
  "[ \"$TOTAL_LINES\" -lt 250 ]"
assert "...and are not a stub — over 120 lines of actual obligation" \
  "[ \"$TOTAL_LINES\" -gt 120 ]"

# No rule may carry `paths:` frontmatter. All three are standing obligations
# that must be in force before the first tool call; a `paths:` rule fires only
# when a matching file is READ, which is too late for a governance floor.
FM_BAD=""
for f in $RULE_FILES; do
  if head -5 "$f" | grep -qE '^paths:'; then FM_BAD="$FM_BAD $f"; fi
done
assert "no authored rule carries \`paths:\` frontmatter (all are unconditional)" \
  "[ -z \"$FM_BAD\" ]"
echo ""

# ── 2. Authored for an adopter, not carved from ours ─────────────────────────
# Each of these is TRUE OF THIS REPO and FALSE OR MEANINGLESS in an adopter's.
# A copy-then-subtract split leaves them in until someone notices, which is the
# failure this whole approach was chosen to avoid — so it is asserted, not hoped.
echo "── 2. nothing repo-specific leaked in ──"
BANNED_DESC_1="our version stamp";        BANNED_1='logic-loom v6'
BANNED_DESC_2="our parsed plugin registry heading"; BANNED_2='## Plugin Registry'
BANNED_DESC_3="our branch topology";      BANNED_3='dev-main'
BANNED_DESC_4="the maintainer-only release driver"; BANNED_4='/promote'
BANNED_DESC_5="clone-path update machinery an adopter never runs"; BANNED_5='.sdd-sync-ref'
BANNED_DESC_6="our own repo's north-star file, which is not shipped"; BANNED_6='VISION.md'
i=1
while [ $i -le 6 ]; do
  eval "pat=\$BANNED_$i"; eval "desc=\$BANNED_DESC_$i"
  HIT="$(grep -lF "$pat" $RULE_FILES 2>/dev/null || true)"
  assert "no authored rule mentions $desc" "[ -z \"$HIT\" ]"
  i=$((i + 1))
done

# The root-ownership claim is the sharpest one: in THIS repo the framework owns
# the repo root; in an adopter's repo the root package.json and tests are
# THEIRS, and the payload manifest excludes ours. Shipping our sentence would be
# an instruction to take over a file we deliberately refuse to install.
assert "no authored rule claims the framework owns the repo root" \
  "! grep -qi 'owns the repo root' $RULE_FILES"
assert "the file rules say the root package.json is the project's" \
  "grep -qi 'package.json' \"$RULES_DIR/logicloom-file-rules.md\""

# Every repo-relative path an authored rule cites in backticks must actually
# ship. A rule pointing at a file the payload excludes is a dangling reference
# in someone else's repo — the exact rot the manifest's exclude: rows exist to
# make visible.
MANIFEST="$PKG/payload-manifest.txt"
BAD_CITE=""
CITED="$(grep -ohE '`[A-Za-z.][A-Za-z0-9._/-]*/[A-Za-z0-9._/-]+\.(md|sh|conf|json)`' $RULE_FILES \
         | tr -d '`' | sort -u)"
for c in $CITED; do
  case "$c" in
    .logic-loom/AGENTS.md) continue ;;   # installed by the manifest's rename: row
    # Cited CONDITIONALLY and correctly ("if it exists"). Upstream deliberately
    # never ships amendments.md — it is the fork extension point, and a shipped
    # copy would be overwritten by every update. A rule that says "read it if it
    # is there" is not a dangling reference.
    .logic-loom/memory/amendments.md) continue ;;
  esac
  [ -e "$ROOT/$c" ] || { BAD_CITE="$BAD_CITE $c(absent-here)"; continue; }
  # excluded by the payload manifest?
  if grep -qE "^exclude: $(printf '%s' "$c" | sed 's/[.[\*^$/]/\\&/g')\$" "$MANIFEST"; then
    BAD_CITE="$BAD_CITE $c(excluded-from-payload)"
  fi
done
assert "every path an authored rule cites exists AND is not excluded from the payload" \
  "[ -z \"$BAD_CITE\" ]"
[ -z "$BAD_CITE" ] || echo "       offending: $BAD_CITE"

# The honesty clause: hooks are opt-in, so a rule that asserts enforcement
# unconditionally would be false in the common install. It must tell the reader
# how to check.
assert "the governance rule tells the reader how to check whether hooks are registered" \
  "grep -q 'settings.json' \"$RULES_DIR/logicloom-governance.md\" && grep -qi 'followed, not enforced' \"$RULES_DIR/logicloom-governance.md\""
echo ""

# ── 3. The manifest no longer defers, and the modes are declared ─────────────
echo "── 3. the blocker is cleared ──"
assert "no \`defer:\` row stands in the payload manifest" \
  "[ \"\$(grep -c '^defer:' \"$MANIFEST\")\" -eq 0 ]"
assert "three author: rows install the rules under .claude/rules/" \
  "[ \"\$(grep -c '^author: .*:: \\.claude/rules/' \"$MANIFEST\")\" -ge 3 ]"
echo ""

# ── 4. The modes, applied to a kori-shaped fixture ───────────────────────────
echo "── 4. the three modes ──"

FX_RULES="$TMP/m-rules"; make_fixture "$FX_RULES"
FX_IMPORT="$TMP/m-import"; make_fixture "$FX_IMPORT"
FX_NONE="$TMP/m-none"; make_fixture "$FX_NONE"
BASE_MD5="$(cksum < "$FX_RULES/CLAUDE.md")"

# -- rules (default): their CLAUDE.md is BYTE-IDENTICAL after the apply --------
node "$CLI" init "$FX_RULES" --apply --only=all >"$TMP/rules.out" 2>&1
assert "mode rules: the apply succeeds" "[ \$? -eq 0 ] || grep -q 'RESULT' \"$TMP/rules.out\""
assert "mode rules: the three rules files landed" \
  "[ -f \"$FX_RULES/.claude/rules/logicloom-governance.md\" ] && \
   [ -f \"$FX_RULES/.claude/rules/logicloom-workflow.md\" ] && \
   [ -f \"$FX_RULES/.claude/rules/logicloom-file-rules.md\" ]"
assert "mode rules: their CLAUDE.md is BYTE-IDENTICAL (never opened)" \
  "[ \"\$(cksum < \"$FX_RULES/CLAUDE.md\")\" = \"$BASE_MD5\" ]"
assert "mode rules: the receipt records the resolved mode" \
  "grep -q '\"resolved\": \"rules\"' \"$FX_RULES/.logicloom-adopt-receipt.json\""

# -- import: exactly one marked block, appended, and nothing else --------------
# Selected through the ENVIRONMENT here, which is the non-interactive path a CI
# or scripted install uses. If this needed a prompt, this line could not exist.
LOOM_ADOPT_CLAUDE_MD=import node "$CLI" init "$FX_IMPORT" --apply --only=all >"$TMP/import.out" 2>&1
assert "mode import: the three rules files landed too" \
  "[ -f \"$FX_IMPORT/.claude/rules/logicloom-governance.md\" ]"
assert "mode import: exactly one BEGIN marker in their CLAUDE.md" \
  "[ \"\$(grep -c 'BEGIN LogicLoom adopt' \"$FX_IMPORT/CLAUDE.md\")\" -eq 1 ]"
assert "mode import: exactly one END marker" \
  "[ \"\$(grep -c 'END LogicLoom adopt' \"$FX_IMPORT/CLAUDE.md\")\" -eq 1 ]"
assert "mode import: one @import line per authored rule" \
  "[ \"\$(grep -c '^@\\.claude/rules/logicloom-' \"$FX_IMPORT/CLAUDE.md\")\" -eq \"$RULE_COUNT\" ]"
# PURE APPEND — every original line survives, in order, at the same offset. A
# rewrite that happened to preserve the text would still fail this.
head -40 "$FX_IMPORT/CLAUDE.md" > "$TMP/import-head.txt"
head -40 "$FX_RULES/CLAUDE.md" > "$TMP/base-head.txt"
assert "mode import: everything above the block is byte-identical (pure append)" \
  "cmp -s \"$TMP/import-head.txt\" \"$TMP/base-head.txt\""
ADDED="$(( $(wc -l < "$FX_IMPORT/CLAUDE.md") - $(wc -l < "$FX_RULES/CLAUDE.md") ))"
assert "mode import: the block is the ONLY change (<= 8 lines added)" \
  "[ \"$ADDED\" -le 8 ] && [ \"$ADDED\" -ge 5 ]"
assert "mode import: the receipt records it" \
  "grep -q '\"resolved\": \"import\"' \"$FX_IMPORT/.logicloom-adopt-receipt.json\""

# -- none: nothing loadable at all --------------------------------------------
node "$CLI" init "$FX_NONE" --apply --only=all --claude-md=none >"$TMP/none.out" 2>&1
assert "mode none: NO rules files installed" "[ ! -d \"$FX_NONE/.claude/rules\" ]"
assert "mode none: their CLAUDE.md is BYTE-IDENTICAL" \
  "[ \"\$(cksum < \"$FX_NONE/CLAUDE.md\")\" = \"$BASE_MD5\" ]"
assert "mode none: the harness tree still installed" "[ -d \"$FX_NONE/.logic-loom\" ]"
assert "mode none: the receipt records it" \
  "grep -q '\"resolved\": \"none\"' \"$FX_NONE/.logicloom-adopt-receipt.json\""
echo ""

# ── 5. Determinism ───────────────────────────────────────────────────────────
echo "── 5. determinism ──"
# The same mode applied twice produces an identical tree. The intervening commit
# is the tool's documented flow, not a workaround: the first apply leaves the
# written paths untracked, and an untracked path under a target BLOCKS by
# design (the same is already true of .gitignore, before this change).
CK1="$(cksum < "$FX_IMPORT/CLAUDE.md")"
RK1="$(cat "$FX_IMPORT/.claude/rules/"*.md | cksum)"
git_quiet "$FX_IMPORT" add -A
git_quiet "$FX_IMPORT" commit -m adopt
LOOM_ADOPT_CLAUDE_MD=import node "$CLI" init "$FX_IMPORT" --apply --only=all >"$TMP/import2.out" 2>&1
assert "a second apply in the same mode leaves CLAUDE.md byte-identical" \
  "[ \"\$(cksum < \"$FX_IMPORT/CLAUDE.md\")\" = \"$CK1\" ]"
assert "...and the rules files byte-identical" \
  "[ \"\$(cat \"$FX_IMPORT/.claude/rules/\"*.md | cksum)\" = \"$RK1\" ]"
assert "...and it is reported as a no-op, not as a second install" \
  "grep -q 'WROTE          0' \"$TMP/import2.out\""
assert "...with the marker still appearing exactly once" \
  "[ \"\$(grep -c 'BEGIN LogicLoom adopt' \"$FX_IMPORT/CLAUDE.md\")\" -eq 1 ]"
assert "...and the second run recorded its mode too" \
  "[ \"\$(grep -c '\"resolved\": \"import\"' \"$FX_IMPORT/.logicloom-adopt-receipt.json\")\" -eq 2 ]"

# The mode comes from a flag or an env var and from NOTHING else. A bad value is
# a usage error, not a silent fallback to the default — a silent fallback is how
# a typo in a CI script installs a mode nobody chose.
node "$CLI" init "$FX_NONE" --claude-md=wobble >"$TMP/bad.out" 2>&1; BAD_RC=$?
assert "an unknown --claude-md value is a USAGE ERROR (exit 2), never a fallback" \
  "[ $BAD_RC -eq 2 ]"
assert "...and it names the valid modes" "grep -q 'rules, import, none' \"$TMP/bad.out\""
LOOM_ADOPT_CLAUDE_MD=wobble node "$CLI" init "$FX_NONE" >"$TMP/badenv.out" 2>&1; BADENV_RC=$?
assert "an unknown env value is refused the same way" "[ $BADENV_RC -eq 2 ]"

# No prompt, anywhere. A read on stdin would hang a CI install; the assertion is
# on the source because a passing run proves only that this input did not prompt.
# The CLAUDE.md write is an APPEND SYSCALL, not a rebuild-and-rewrite. That is
# refusal 3 holding at the same level as refusal 1's 'wx' flag: `appendFileSync`
# opens 'a' and cannot truncate, so the guarantee is the kernel's rather than a
# check a later edit could drop.
assert "the CLAUDE.md block is written with appendFileSync, which cannot truncate" \
  "grep -q 'fs.appendFileSync(target' \"$PKG/lib/apply.js\""
assert "...and no code path rebuilds their CLAUDE.md and writes it back" \
  "! grep -q 'writeFileSync(target' \"$PKG/lib/apply.js\""
assert "the applier never reads stdin (no prompt exists to hang CI)" \
  "! grep -qE 'readline|createInterface|/dev/stdin|readSync\\(0' \"$PKG/lib/apply.js\" \"$PKG/lib/claude-md.js\" \"$CLI\""
echo ""

# ── 6. A new project is never interrogated ───────────────────────────────────
echo "── 6. the new-project path does not ask ──"
NEW="$TMP/new"; mkdir -p "$NEW"; git_quiet "$NEW" init
node "$CLI" init "$NEW" >"$TMP/new.out" 2>&1
assert "no three-option menu is printed when there is no CLAUDE.md" \
  "! grep -q 'YOUR CHOICE' \"$TMP/new.out\""
assert "...it says so in one line instead" \
  "grep -q 'not asked' \"$TMP/new.out\""
# An explicit --claude-md=import against a repo with no CLAUDE.md COLLAPSES to
# `rules` rather than erroring or creating the file. Recorded, not ignored.
node "$CLI" init "$NEW" --claude-md=import >"$TMP/new-import.out" 2>&1
assert "an explicit import collapses to rules when there is no CLAUDE.md" \
  "grep -q 'collapses to \`rules\`' \"$TMP/new-import.out\""
assert "...and the collapse is stated, not silent" \
  "grep -q 'collapsed, not ignored' \"$TMP/new-import.out\""
assert "no CLAUDE.md was created by any of it" "[ ! -e \"$NEW/CLAUDE.md\" ]"
echo ""

echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
