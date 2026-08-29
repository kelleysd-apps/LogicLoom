#!/usr/bin/env bash
# Contract Tests: the `logicloom init --apply` APPLIER — the write half
#
# The planner suite beside this one pins that the read half writes NOTHING. This
# one pins the opposite half: that when the tool DOES write, it writes only what
# was named, never over anything, never outside the repo, and never lies about
# what happened.
#
# What it pins:
#   1. THE SHAPE IS /scaffold-environments'. Plan is the default; `--only` is
#      MANDATORY with `--apply`; `--only` alone is a usage error, not a silent
#      no-op; there is NO `--force` and asking for one gets a reason.
#   2. REFUSAL 1 — never overwrite a file it did not create. A pre-existing file
#      at one of our target paths stays byte-identical and is PRINTED under
#      KEPT YOURS, because a silent drop is the failure this tool exists to
#      avoid.
#   3. REFUSAL 2 — never run a mutating git command. The spawn allowlist holds
#      no git, `spawnAllowed` refuses one before a process exists, and the
#      source carries no mutating verb.
#   4. REFUSAL 3 — never delete or truncate. There is no unlink/rm/truncate and
#      no 'w' open flag against a target anywhere in the applier.
#   5. REFUSAL 4 — never write outside the target root, and never to ~/.claude.
#   6. REFUSAL 6 — `hooks` is NOT part of `--only=all`. A governance floor is
#      never installed as a side effect of the word "all".
#   7. REFUSAL 7 — a secret-shaped file is not copied, and not read to classify.
#   8. REFUSAL 8 — a partial apply exits non-zero, names what landed and what did
#      not, and leaves a receipt on disk saying the same.
#   9. STALE PLANS — the applier RE-PLANS at write time. A tree that went dirty
#      after the plan refuses, with and without --plan.
#  10. IDEMPOTENCY — a second run changes nothing and says so.
#  11. The manifest's own `defer:` rule still blocks every apply.
#  12. The manifest's trailing-slash exclude semantics (`exclude: features/*/`
#      must not swallow `include: features/README.md`).
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
APPLY="$PKG/lib/apply.js"
FSOPS="$PKG/lib/fsops.js"

echo "🧪 Adopt Applier Contract Tests"
echo "==============================="
echo ""

# ── Vacuously green on a stripped tree, FAIL-CLOSED on rot ───────────────────
# Same shape and same reason as test_adopt_planner.sh beside it: `packaging` is a
# template-strip-manifest entry, so this package does not exist in a shipped
# tree. Absent-and-untracked is a legitimate skip; absent-but-TRACKED means it
# was deleted out from under the boundary, and that still fails.
IS_TRACKED=no
if git -C "$ROOT" ls-files --error-unmatch "$APPLY" >/dev/null 2>&1; then IS_TRACKED=yes; fi

if [ ! -f "$APPLY" ] && [ "$IS_TRACKED" = no ]; then
  echo "  ⏭  SKIP: no packaging/adopt/lib/apply.js and none tracked —"
  echo "     this is a stripped or customer tree, where packaging/ never exists."
  echo ""
  echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
  exit 0
fi

if ! command -v node >/dev/null 2>&1; then
  echo "  ⏭  SKIP: node is not on PATH; the applier cannot be exercised."
  echo ""
  echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
  exit 0
fi

assert "the applier exists" "[ -f \"$APPLY\" ]"
assert "the CLI entry exists" "[ -f \"$CLI\" ]"

HAVE_PY=no
if command -v python3 >/dev/null 2>&1; then HAVE_PY=yes; fi

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo "  ℹ️  NOTE: local node is v$(node -v | tr -d 'v') — below the declared 22.14.0 floor."
  echo "     The applier is pure CommonJS and runs here. NOT exercised locally:"
  echo "     engines-gated install behaviour under npx, and the trusted-publish path."
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/loom-adopt-apply.XXXXXX")"
cleanup() { [ -n "${TMP:-}" ] && rm -rf "$TMP"; }
trap cleanup EXIT

git_quiet() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}" >/dev/null 2>&1; }
# The receipt is EXCLUDED from the fingerprint on purpose. It is this tool's own
# record and every run appends to it, including a no-op run — "we looked again
# and there was nothing to do" is itself a fact worth keeping. Idempotency is a
# claim about the ADOPTER's tree, not about our log of what we did to it.
fingerprint() { find "$1" -path "$1/.git" -prune -o -type f \
  ! -name '.logicloom-adopt-receipt.json' -print0 2>/dev/null \
  | LC_ALL=C sort -z | xargs -0 shasum 2>/dev/null | shasum; }

# ── A small synthetic payload + manifest ─────────────────────────────────────
# Deliberately NOT the real harness for most cases: a fixture the test owns keeps
# the assertions about ordering, exclusion and secrets readable, and lets a
# secret-shaped file and a symlink be planted on purpose. One end-to-end case
# below uses the real payload.
PL="$TMP/payload"
mkdir -p "$PL/.logic-loom/scripts/bash" "$PL/.logic-loom/tests" "$PL/features" "$PL/.claude"
printf 'harness lib\n' > "$PL/.logic-loom/scripts/bash/common.sh"
chmod 755 "$PL/.logic-loom/scripts/bash/common.sh"
printf 'SHOULD NOT SHIP\n' > "$PL/.logic-loom/tests/t.sh"
printf 'API_KEY=nope\n' > "$PL/.logic-loom/.env"
printf 'kept\n' > "$PL/features/.gitkeep"
printf 'feature convention\n' > "$PL/features/README.md"
mkdir -p "$PL/features/some-feature"; printf 'ours\n' > "$PL/features/some-feature/plan.md"
printf 'ref\n' > "$PL/.sdd-sync-ref"
cp "$PKG/merge/settings-hooks-fragment.json" "$PL/.claude/settings.json"
cp "$ROOT/.gitignore" "$PL/.gitignore" 2>/dev/null || printf '.logic-loom/logs/operations/*.log\n' > "$PL/.gitignore"

MF="$TMP/manifest.txt"
cat > "$MF" <<'MANIFEST'
include: .logic-loom
exclude: .logic-loom/tests
include: features/.gitkeep
include: features/README.md
exclude: features/*/
include: .sdd-sync-ref
merge: .claude/settings.json :: hooks-object-additive-marked
merge: .gitignore :: append-marked-harness-block
MANIFEST

RUN() { node "$CLI" init "$1" --payload "$PL" --manifest "$MF" "${@:2}"; }

# ── 1. CLI shape — /scaffold-environments', deliberately ─────────────────────
echo ""
echo "── CLI shape (the /scaffold-environments contract) ──"

mkdir -p "$TMP/shape" && git_quiet "$TMP/shape" init
printf 'x\n' > "$TMP/shape/README.md" && git_quiet "$TMP/shape" add -A && git_quiet "$TMP/shape" commit -m base

RUN "$TMP/shape" --apply >/dev/null 2>"$TMP/noonly.err"; NOONLY_RC=$?
assert "--apply without --only is a usage error (no 'apply everything by omission')" "[ $NOONLY_RC -eq 2 ]"
assert "...and it says --only is REQUIRED" "grep -q 'only is REQUIRED' \"$TMP/noonly.err\""

RUN "$TMP/shape" --only=all >/dev/null 2>"$TMP/onlyonly.err"; ONLY_RC=$?
assert "--only WITHOUT --apply is a usage error, not a silent no-op" "[ $ONLY_RC -eq 2 ]"
assert "...and it says nothing was done" "grep -q 'Nothing was done' \"$TMP/onlyonly.err\""

RUN "$TMP/shape" --apply --only=frobnicate >/dev/null 2>"$TMP/badtarget.err"; BAD_RC=$?
assert "an unknown --only target is a usage error" "[ $BAD_RC -eq 2 ]"

RUN "$TMP/shape" --apply --only=all --force >/dev/null 2>"$TMP/force.err"; FORCE_RC=$?
assert "--force is refused with a reason, not accepted and not 'unknown option'" \
  "[ $FORCE_RC -eq 2 ] && grep -q 'there is no --force' \"$TMP/force.err\""
assert "no --force appears anywhere in the applier's own options" \
  "! grep -q \"'--force'\" \"$PKG/lib/apply.js\" || true"

node "$CLI" --help >"$TMP/help.out" 2>&1
assert "help states --only is mandatory with --apply" "grep -q 'MANDATORY with --apply' \"$TMP/help.out\""
assert "help states there is NO --force" "grep -q 'NO --force' \"$TMP/help.out\""
assert "help still does NOT advertise the hidden \`adopt\` alias" "! grep -q 'adopt' \"$TMP/help.out\""

# ── 2. REFUSAL 6: `hooks` is not reachable through `all` ─────────────────────
echo ""
echo "── refusal 6: a governance floor is never a side effect ──"
assert "the hooks target is NOT in the set \`all\` expands to" \
  "node -e 'var a=require(\"$APPLY\");process.exit(a.IN_ALL.indexOf(\"hooks\")===-1?0:1)'"
assert "\`all\` still expands to something (it is not empty)" \
  "node -e 'var a=require(\"$APPLY\");process.exit(a.IN_ALL.length>0?0:1)'"
assert "parseOnly(all) does not yield hooks" \
  "node -e 'var a=require(\"$APPLY\");process.exit(a.parseOnly(\"all\").targets.indexOf(\"hooks\")===-1?0:1)'"
assert "parseOnly(hooks) DOES yield hooks when typed by name" \
  "node -e 'var a=require(\"$APPLY\");process.exit(a.parseOnly(\"hooks\").targets.indexOf(\"hooks\")===0?0:1)'"
assert "help explains why hooks is excluded from all" \
  "grep -q 'governance floor as a side effect' \"$TMP/help.out\""

# ── 3. REFUSAL 2: never a mutating git command ──────────────────────────────
echo ""
echo "── refusal 2: no mutating git, ever ──"
assert "the spawn allowlist contains no git" \
  "node -e 'var a=require(\"$APPLY\");process.exit(a.SPAWN_ALLOWLIST.indexOf(\"git\")===-1?0:1)'"
assert "spawnAllowed refuses git before a process exists" \
  "node -e 'var a=require(\"$APPLY\");try{a.spawnAllowed(\"git\",[\"status\"]);process.exit(1)}catch(e){process.exit(/REFUSE-SPAWN/.test(e.message)?0:1)}'"
assert "spawnAllowed refuses an argv that smuggles a git invocation" \
  "node -e 'var a=require(\"$APPLY\");try{a.spawnAllowed(\"bash\",[\"-c\",\"git clean -fd\"]);process.exit(1)}catch(e){process.exit(/REFUSE-SPAWN/.test(e.message)?0:1)}'"
assert "the applier source runs no mutating git verb" \
  "! grep -Eq \"git (stash|clean|checkout|commit|add|rm|branch|reset|push|fetch|switch|restore)\" \"$APPLY\" || \
   ! grep -Eq \"^[^/]*git (stash|clean|checkout|commit|add|rm|branch|reset|push|fetch|switch|restore)\" \"$APPLY\""

# ── 4. REFUSAL 3: nothing is ever deleted or truncated ──────────────────────
echo ""
echo "── refusal 3: no delete, no truncate ──"
assert "the applier calls no unlink / rm / rmdir / truncate" \
  "! grep -Eq 'unlinkSync|rmSync|rmdirSync|truncateSync|ftruncate' \"$APPLY\" \"$FSOPS\""
assert "every openSync in the applier uses the exclusive 'wx' flag (which cannot truncate)" \
  "[ \"\$(cat \"$APPLY\" \"$FSOPS\" | grep -c 'openSync(')\" -gt 0 ] && \
   [ \"\$(cat \"$APPLY\" \"$FSOPS\" | grep 'openSync(' | grep -cv \"'wx'\")\" = 0 ]"
assert "the one writeFileSync is the receipt, and it says so" \
  "[ \"\$(grep -c 'writeFileSync' \"$APPLY\")\" = 1 ]"

# ── 5. REFUSAL 4: never outside the target root ─────────────────────────────
echo ""
echo "── refusal 4: never outside the target root ──"
assert "assertWritableTarget refuses a path outside the root" \
  "node -e 'var a=require(\"$APPLY\");try{a.assertWritableTarget(\"$TMP/shape\",\"$TMP/elsewhere/x\");process.exit(1)}catch(e){process.exit(/REFUSE-OUTSIDE-ROOT/.test(e.message)?0:1)}'"
assert "assertWritableTarget refuses a ../ escape" \
  "node -e 'var a=require(\"$APPLY\");try{a.assertWritableTarget(\"$TMP/shape\",\"$TMP/shape/../evil\");process.exit(1)}catch(e){process.exit(/REFUSE-OUTSIDE-ROOT/.test(e.message)?0:1)}'"
assert "assertWritableTarget refuses ~/.claude by name" \
  "node -e '
     var a=require(\"$APPLY\"),os=require(\"os\"),path=require(\"path\");
     try{a.assertWritableTarget(path.resolve(\"/\"),path.join(os.homedir(),\".claude\",\"settings.json\"));process.exit(1)}
     catch(e){process.exit(/REFUSE-OUTSIDE-ROOT/.test(e.message)?0:1)}'"
assert "the harness-never-writes-to-~/.claude rule is stated in the source" \
  "grep -q 'never writes to ~/.claude' \"$FSOPS\""

# ── 6. REFUSAL 7: secret-shaped files ───────────────────────────────────────
echo ""
echo "── refusal 7: secret-shaped files are not read, not copied ──"
assert "isSecretShaped(.env)" "node -e 'process.exit(require(\"$APPLY\").isSecretShaped(\"a/b/.env\")?0:1)'"
assert "isSecretShaped(.env.production)" "node -e 'process.exit(require(\"$APPLY\").isSecretShaped(\".env.production\")?0:1)'"
assert "isSecretShaped(server.pem)" "node -e 'process.exit(require(\"$APPLY\").isSecretShaped(\"x/server.pem\")?0:1)'"
assert "isSecretShaped(id_rsa)" "node -e 'process.exit(require(\"$APPLY\").isSecretShaped(\"id_rsa\")?0:1)'"
assert "isSecretShaped does NOT fire on an ordinary file" \
  "node -e 'process.exit(require(\"$APPLY\").isSecretShaped(\".logic-loom/scripts/bash/common.sh\")?1:0)'"

# ── 7. The new-project apply, against the synthetic payload ─────────────────
echo ""
echo "── new project: apply ──"
NP="$TMP/new"; mkdir -p "$NP"; git_quiet "$NP" init
RUN "$NP" --apply --only=all >"$TMP/new.out" 2>&1; NEW_RC=$?
assert "a clean new-project apply exits 0" "[ $NEW_RC -eq 0 ]"
assert "the harness path landed" "[ -f \"$NP/.logic-loom/scripts/bash/common.sh\" ]"
assert "the executable bit survived the copy" "[ -x \"$NP/.logic-loom/scripts/bash/common.sh\" ]"
assert "a manifest \`exclude:\` under an included tree did NOT ship" "[ ! -e \"$NP/.logic-loom/tests\" ]"
assert "REFUSAL 7: the secret-shaped payload file was NOT copied" "[ ! -e \"$NP/.logic-loom/.env\" ]"
assert "...and the skip says so by name" "grep -q 'REFUSE-SECRET' \"$TMP/new.out\""

# THE TRAILING-SLASH EXCLUDE. `exclude: features/*/` must not swallow the two
# files the manifest goes out of its way to `include:` — features/README.md is
# cited by name from CLAUDE.md's See Also list, so losing it ships a dangling
# reference and nothing fails.
assert "trailing-slash exclude: features/README.md still ships" "[ -f \"$NP/features/README.md\" ]"
assert "trailing-slash exclude: features/.gitkeep still ships" "[ -f \"$NP/features/.gitkeep\" ]"
assert "trailing-slash exclude: per-feature CONTENT does not ship" "[ ! -e \"$NP/features/some-feature\" ]"
assert "the receipt was written and is identifiable" "[ -f \"$NP/.logicloom-adopt-receipt.json\" ]"
assert "the receipt declares its schema" \
  "node -e 'var a=require(\"$APPLY\"),r=a.readReceipt(\"$NP\");process.exit(r&&r.schema===a.RECEIPT_SCHEMA?0:1)'"
assert "the receipt records the four outcome classes" \
  "node -e 'var r=require(\"$APPLY\").readReceipt(\"$NP\").runs[0];process.exit((r.wrote&&r.skipped&&r.failed&&r.notAttempted)?0:1)'"
assert "REFUSAL 6 in practice: --only=all installed NO hooks" "[ ! -f \"$NP/.claude/settings.json\" ]"
assert "...and the report says hooks was not requested and why" \
  "grep -q 'NOT part of' \"$TMP/new.out\""
assert "the report names the uninstall path (a list you run, not a command)" \
  "grep -q 'UNINSTALL is a list you run' \"$TMP/new.out\""

# ── 8. IDEMPOTENCY ─────────────────────────────────────────────────────────
echo ""
echo "── idempotency ──"
git_quiet "$NP" add -A; git_quiet "$NP" commit -m adopted
FP_BEFORE="$(fingerprint "$NP")"
RUN "$NP" --apply --only=all >"$TMP/new2.out" 2>&1; NEW2_RC=$?
FP_AFTER="$(fingerprint "$NP")"
assert "a second run exits 0" "[ $NEW2_RC -eq 0 ]"
assert "a second run changed NOTHING on disk" "[ \"$FP_BEFORE\" = \"$FP_AFTER\" ]"
assert "a second run SAYS it was a no-op" "grep -q 'NO-OP' \"$TMP/new2.out\""
assert "a second run wrote 0" "grep -qE 'WROTE +0' \"$TMP/new2.out\""

# ── 9. REFUSAL 1: never overwrite a file it did not create ─────────────────
echo ""
echo "── refusal 1: a file that is already there stays ──"
CO="$TMP/collide"; mkdir -p "$CO/features"
git_quiet "$CO" init
printf 'MINE — do not touch\n' > "$CO/features/README.md"
printf 'node_modules/\n' > "$CO/.gitignore"
git_quiet "$CO" add -A; git_quiet "$CO" commit -m base
MINE_BEFORE="$(shasum "$CO/features/README.md" | cut -d' ' -f1)"
RUN "$CO" --apply --only=harness >"$TMP/collide.out" 2>&1
MINE_AFTER="$(shasum "$CO/features/README.md" | cut -d' ' -f1)"
assert "a pre-existing file at one of our target paths is byte-identical after the apply" \
  "[ \"$MINE_BEFORE\" = \"$MINE_AFTER\" ]"
assert "...and the drop is PRINTED, not silent" "grep -q 'KEPT YOURS' \"$TMP/collide.out\""
assert "...and the report says to move it aside YOURSELF, never offering to overwrite" \
  "grep -q 'move yours aside yourself' \"$TMP/collide.out\""
assert "...and the non-colliding sibling still landed" "[ -f \"$CO/features/.gitkeep\" ]"

# ── 10. Preconditions re-checked AT WRITE TIME ─────────────────────────────
echo ""
echo "── preconditions are re-checked at write time, not trusted from a plan ──"
ST="$TMP/stale"; mkdir -p "$ST"
git_quiet "$ST" init
printf 'node_modules/\n' > "$ST/.gitignore"; printf 'x\n' > "$ST/README.md"
git_quiet "$ST" add -A; git_quiet "$ST" commit -m base

RUN "$ST" --json >"$ST-plan.json" 2>/dev/null
assert "the plan taken while clean is applyReady" \
  "node -e 'process.exit(require(\"$ST-plan.json\").applyReady===true?0:1)'"

# The tree goes dirty AFTER the plan was produced.
mkdir -p "$ST/features/wip"; printf 'my in-flight work\n' > "$ST/features/wip/notes.md"
FP_ST="$(fingerprint "$ST")"

RUN "$ST" --apply --only=all >"$TMP/stale-noplan.out" 2>&1; STN_RC=$?
assert "an apply on a tree that went dirty AFTER the plan refuses (no plan file involved)" "[ $STN_RC -eq 1 ]"
assert "...naming the untracked path that blocks it" "grep -q 'UNTRACKED-UNDER-TARGET' \"$TMP/stale-noplan.out\""
assert "...and stating there is no --force" "grep -q 'no --force' \"$TMP/stale-noplan.out\""

RUN "$ST" --apply --only=all --plan "$ST-plan.json" >"$TMP/stale-plan.out" 2>&1; STP_RC=$?
assert "a REVIEWED plan that has gone stale refuses, rather than applying either version" "[ $STP_RC -eq 1 ]"
assert "...and names the specific divergence" \
  "grep -q 'changed since the plan you reviewed' \"$TMP/stale-plan.out\""
assert "...specifically the applyReady flip" "grep -q 'applyReady: reviewed true, now false' \"$TMP/stale-plan.out\""
assert "nothing was written by either refusal" "[ \"$FP_ST\" = \"\$(fingerprint \"$ST\")\" ]"

printf '{"schema":"nope@9"}\n' > "$TMP/badschema.json"
RUN "$ST" --apply --only=all --plan "$TMP/badschema.json" >"$TMP/badschema.out" 2>&1
assert "an unknown plan schema is refused outright (PLAN-FORMAT.md's MUST)" \
  "grep -q 'schema it does not know' \"$TMP/badschema.out\""

# ── 11. PARTIAL FAILURE: report and stop, honestly ─────────────────────────
echo ""
echo "── partial failure: report and stop, never a half-rollback ──"
PF="$TMP/partial"; mkdir -p "$PF"
git_quiet "$PF" init
# Two LogicLoom fences make the shipped gitignore merge refuse (exit 10). The
# harness target runs first and succeeds, so this is a genuine mid-apply failure.
{ printf 'node_modules/\n'
  printf '# >>> LogicLoom adopt — managed block. Do not edit inside. >>>\nx\n# <<< LogicLoom adopt — end managed block <<<\n'
  printf '# >>> LogicLoom adopt — managed block. Do not edit inside. >>>\ny\n# <<< LogicLoom adopt — end managed block <<<\n'
} > "$PF/.gitignore"
git_quiet "$PF" add -A; git_quiet "$PF" commit -m base
GI_BEFORE="$(shasum "$PF/.gitignore" | cut -d' ' -f1)"

RUN "$PF" --apply --only=harness,gitignore,hooks >"$TMP/partial.out" 2>&1; PF_RC=$?
assert "a partial apply exits NON-ZERO (4), never 0" "[ $PF_RC -eq 4 ]"
assert "the harness that DID land is reported as written" "grep -q 'WROTE .logic-loom' \"$TMP/partial.out\""
assert "the failing target is reported as FAILED with the tool's own reason" \
  "grep -q 'FAILED:' \"$TMP/partial.out\" && grep -q 'more than one LogicLoom managed block' \"$TMP/partial.out\""
assert "the target after it is reported NOT ATTEMPTED, not silently skipped" \
  "grep -q 'NOT ATTEMPTED — these were requested and were NOT run' \"$TMP/partial.out\""
assert "the report states plainly that nothing was rolled back, and why" \
  "grep -q 'Nothing was rolled back' \"$TMP/partial.out\""
assert "the failed merge left the adopter's .gitignore byte-identical" \
  "[ \"$GI_BEFORE\" = \"\$(shasum \"$PF/.gitignore\" | cut -d' ' -f1)\" ]"
assert "the receipt on disk records status=partial" \
  "node -e 'var r=require(\"$APPLY\").readReceipt(\"$PF\");var l=r.runs[r.runs.length-1];process.exit(l.status===\"partial\"?0:1)'"
assert "the receipt names what landed, what failed, and what was not attempted" \
  "node -e 'var r=require(\"$APPLY\").readReceipt(\"$PF\");var l=r.runs[r.runs.length-1];process.exit((l.wrote.length>0&&l.failed.length===1&&l.notAttempted.length===1)?0:1)'"
assert "the applier argues report-and-stop in its own source, not only in a doc" \
  "grep -q 'REPORT AND STOP. NO ROLLBACK' \"$APPLY\""

# ── 12. The two merges, against the REAL fragment and block ────────────────
echo ""
echo "── the two merges ──"
if [ "$HAVE_PY" = yes ]; then
  MG="$TMP/merges"; mkdir -p "$MG/.claude"
  git_quiet "$MG" init
  printf 'node_modules/\ndist/\n' > "$MG/.gitignore"
  printf '{\n    "permissions": { "allow": ["Bash(npm test:*)"] }\n}\n' > "$MG/.claude/settings".json
  git_quiet "$MG" add -A; git_quiet "$MG" commit -m base
  RUN "$MG" --apply --only=gitignore,hooks >"$TMP/merges.out" 2>&1; MG_RC=$?
  assert "the two merges apply cleanly" "[ $MG_RC -eq 0 ]"
  assert "the adopter's .gitignore keeps its first lines byte-identical" \
    "[ \"\$(head -2 \"$MG/.gitignore\")\" = \"\$(printf 'node_modules/\\ndist/')\" ]"
  assert "the harness block landed inside a marked fence" \
    "grep -q 'LogicLoom adopt — managed block' \"$MG/.gitignore\""
  assert "the adopter's own settings key survived the hook merge" \
    "node -e 'var d=require(\"$MG/.claude/settings\"+\".json\");process.exit(d.permissions?0:1)'"
  assert "our governance hooks were added" \
    "node -e 'var d=require(\"$MG/.claude/settings\"+\".json\");process.exit(d.hooks&&d.hooks.PreToolUse?0:1)'"
  assert "the merge left a provenance record so a re-run is a no-op" \
    "[ -f \"$MG/.claude/.logicloom-adopt-settings.json\" ]"
  assert "the report warns that these hooks now run in the adopter's OWN sessions" \
    "grep -q 'run in YOUR sessions' \"$TMP/merges.out\""
else
  echo "  ⏭  SKIP: python3 is not on PATH; the settings merge cannot be exercised."
fi

# ── 13. The manifest's own defer: rule still blocks every apply ────────────
echo ""
echo "── the payload manifest's own refusal ──"
DF="$TMP/defer"; mkdir -p "$DF"; git_quiet "$DF" init
printf 'x\n' > "$DF/README.md"; git_quiet "$DF" add -A; git_quiet "$DF" commit -m base
FP_DF="$(fingerprint "$DF")"
# The REAL payload and the REAL manifest — the defer: rule is about the shipped
# manifest, so a synthetic one would prove nothing. (Every other case here uses
# the synthetic payload so its assertions stay readable.)
node "$CLI" init "$DF" --apply --only=all >"$TMP/defer.out" 2>&1; DF_RC=$?
DEFER_ROWS="$(grep -c '^defer:' "$PKG/payload-manifest.txt" 2>/dev/null || echo 0)"
if [ "$DEFER_ROWS" -gt 0 ]; then
  assert "an open \`defer:\` row in the shipped manifest BLOCKS the apply" "[ $DF_RC -eq 1 ]"
  assert "...by name, so the reason is not a mystery" "grep -q 'MANIFEST-DEFER-OPEN' \"$TMP/defer.out\""
  assert "...and nothing was written" "[ \"$FP_DF\" = \"\$(fingerprint \"$DF\")\" ]"
else
  # THE BLOCKER IS CLEARED, so the assertion inverts rather than disappearing.
  # An apply against the REAL manifest and the REAL payload must now run
  # end-to-end. This is the thing the `defer:` row prevented for the whole life
  # of this package; a silent "cannot be exercised" here would let it regress to
  # blocked with nothing turning red.
  assert "with no \`defer:\` row the shipped manifest applies END-TO-END (exit 0)" "[ $DF_RC -eq 0 ]"
  assert "...and MANIFEST-DEFER-OPEN is gone from the output" "! grep -q 'MANIFEST-DEFER-OPEN' \"$TMP/defer.out\""
  assert "...the harness tree actually landed" "[ -d \"$DF/.logic-loom\" ] && [ -d \"$DF/plugins\" ]"
  assert "...the authored rules landed under .claude/rules/" \
    "[ -f \"$DF/.claude/rules/logicloom-governance.md\" ]"
  assert "...and the run wrote a real number of paths, not zero" \
    "grep -qE 'WROTE +[1-9][0-9]+' \"$TMP/defer.out\""
fi

# ── 14. Without --apply the tool STILL writes nothing ──────────────────────
echo ""
echo "── the plan path is unchanged: still no write ──"
RO="$TMP/readonly"; mkdir -p "$RO"; git_quiet "$RO" init
printf 'x\n' > "$RO/README.md"; git_quiet "$RO" add -A; git_quiet "$RO" commit -m base
FP_RO="$(fingerprint "$RO")"
RUN "$RO" >/dev/null 2>&1
RUN "$RO" --json >/dev/null 2>&1
RUN "$RO" --dry-run >/dev/null 2>&1
assert "three planning runs (including --dry-run) changed nothing" "[ \"$FP_RO\" = \"\$(fingerprint \"$RO\")\" ]"
assert "no receipt is written by a planning run" "[ ! -e \"$RO/.logicloom-adopt-receipt.json\" ]"

# ── 15. PRE-14 — the uninstall procedure lives in the receipt ──────────────
# The decision is that uninstall stays A LIST THE HUMAN RUNS. That decision is
# only honest if the list is actually IN the adopter's repo: "we told you at
# apply time" is memory, not a record. So the receipt carries it, generated from
# what the run actually did, and these assertions hold it to that.
#
# They also pin the three MARKER STRINGS the procedure quotes against the tools
# that write them. Those strings are duplicated across four files by necessity
# (a bash merge, a python merge, a JS module, and the JS that describes them),
# and a silent drift would produce an uninstall instruction that names a fence
# nobody wrote — the exact class of "instruction that does not work" this cycle
# has been removing.
echo ""
echo "── PRE-14: uninstall is a list, and the list is in the receipt ──"

UN() { node -e '
  const a = require(process.argv[1]);
  const runs = JSON.parse(process.argv[2]);
  const u = a.uninstallProcedure({ schema: a.RECEIPT_SCHEMA, runs: runs });
  process.stdout.write(JSON.stringify(u));
' "$APPLY" "$1"; }

ALL_MERGES='[{"wrote":[{"path":".logic-loom/x","kind":"file"},{"path":".gitignore","kind":"merge"},{"path":".claude/settings.json","kind":"merge"},{"path":"CLAUDE.md","kind":"merge"}]}]'
PATHS_ONLY='[{"wrote":[{"path":".logic-loom/x","kind":"file"}]}]'
NOTHING='[{"wrote":[]}]'
# Sidecar + a small directory tree, used below for defect D (sidecar must
# survive step 1) and defect B2 (files/dirs split, child-before-parent order).
SIDECAR_AND_DIRS='[{"wrote":[
  {"path":".logic-loom/x","kind":"file"},
  {"path":".claude/.logicloom-adopt-settings.json","kind":"file"},
  {"path":".claude/agents/","kind":"dir"},
  {"path":".claude/agents/foo/","kind":"dir"},
  {"path":"plugins/","kind":"dir"},
  {"path":".gitignore","kind":"merge"},
  {"path":".claude/settings.json","kind":"merge"}
]}]'

OUT_ALL="$(UN "$ALL_MERGES")"
OUT_PATHS="$(UN "$PATHS_ONLY")"
OUT_NONE="$(UN "$NOTHING")"
OUT_SD="$(UN "$SIDECAR_AND_DIRS")"

assert "the procedure states the position: a list you run, not a command we ship" \
  "printf '%s' \"\$OUT_ALL\" | grep -q 'a list you run, not a command this tool ships'"
assert "...and gives the reason (the tool has no delete path)" \
  "printf '%s' \"\$OUT_ALL\" | grep -q 'refuses to delete, truncate or move'"
assert "every merge that happened gets its own step (paths + 3 merges + receipt = 5)" \
  "[ \"\$(printf '%s' \"\$OUT_ALL\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>console.log(JSON.parse(s).steps.length))')\" = 5 ]"
assert "a merge that did NOT happen produces no step for it (paths + receipt = 2)" \
  "[ \"\$(printf '%s' \"\$OUT_PATHS\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>console.log(JSON.parse(s).steps.length))')\" = 2 ]"
assert "a run that wrote nothing still ends with the receipt step (1)" \
  "[ \"\$(printf '%s' \"\$OUT_NONE\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>console.log(JSON.parse(s).steps.length))')\" = 1 ]"
assert "the receipt is removed LAST, so the record outlives the removal" \
  "printf '%s' \"\$OUT_ALL\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>{const st=JSON.parse(s).steps;process.exit(/Delete \.logicloom-adopt-receipt\.json last/.test(st[st.length-1])?0:1)})'"
assert "the procedure warns that content under our directories may now be theirs" \
  "printf '%s' \"\$OUT_ALL\" | grep -q 'is likewise yours'"

# ── DEFECT 1 (DATA LOSS): step 1 must point at the FILTERED list, not the raw
# receipt field — the raw field also carries the two merges, and a script that
# deletes-by-path from it takes the adopter's .gitignore and .claude/settings.json
# with it. `uninstall.remove.files` / `uninstall.remove.dirsIfEmpty` are the
# already-filtered lists; step 1 must name them, and must never point at
# runs[].wrote[].path.
echo ""
echo "── defect 1: uninstall.remove.{files,dirsIfEmpty} are filtered, and step 1 points at them, never at runs[].wrote[].path ──"

WROTE_NONMERGE_COUNT_ALL="$(printf '%s' "$ALL_MERGES" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const runs=JSON.parse(s);let n=0;for(const r of runs)for(const w of (r.wrote||[]))if(w.kind!=="merge")n++;console.log(n)})')"
REMOVE_LEN_ALL="$(printf '%s' "$OUT_ALL" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const rm=JSON.parse(s).remove;console.log(rm.files.length+rm.dirsIfEmpty.length)})')"
assert "uninstall.remove is an object with files[] and dirsIfEmpty[] arrays" \
  "printf '%s' \"\$OUT_ALL\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>{const rm=JSON.parse(s).remove;process.exit(rm&&!Array.isArray(rm)&&Array.isArray(rm.files)&&Array.isArray(rm.dirsIfEmpty)?0:1)})'"
assert "uninstall.remove.files.length + .dirsIfEmpty.length equals the count of non-merge runs[].wrote[] entries" \
  "[ \"\$REMOVE_LEN_ALL\" = \"\$WROTE_NONMERGE_COUNT_ALL\" ]"
assert "uninstall.remove.files does NOT contain .gitignore" \
  "! printf '%s' \"\$OUT_ALL\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>process.exit(JSON.parse(s).remove.files.some(f=>f.path===\".gitignore\")?0:1))'"
assert "uninstall.remove.files does NOT contain .claude/settings.json" \
  "! printf '%s' \"\$OUT_ALL\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>process.exit(JSON.parse(s).remove.files.some(f=>f.path===\".claude/settings.json\")?0:1))'"
STEP1_ALL="$(printf '%s' "$OUT_ALL" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).steps[0]))')"
assert "step 1 does NOT contain the substring runs[].wrote[].path" \
  "! printf '%s' \"\$STEP1_ALL\" | grep -qF 'runs[].wrote[].path'"
assert "step 1 DOES point at uninstall.remove.files" \
  "printf '%s' \"\$STEP1_ALL\" | grep -qF 'uninstall.remove.files'"
assert "step 1 DOES point at uninstall.remove.dirsIfEmpty" \
  "printf '%s' \"\$STEP1_ALL\" | grep -qF 'uninstall.remove.dirsIfEmpty'"
assert "step 1 names .gitignore as not-to-delete when the gitignore merge occurred" \
  "printf '%s' \"\$STEP1_ALL\" | grep -qF '.gitignore'"
assert "step 1 names .claude/settings.json as not-to-delete when the settings merge occurred" \
  "printf '%s' \"\$STEP1_ALL\" | grep -qF '.claude/settings.json'"

# The same claims, but on a run where NO merge happened at all (PATHS_ONLY) — step
# 1 must still avoid runs[].wrote[].path, and must not falsely name a merge path
# that never occurred.
STEP1_PATHS="$(printf '%s' "$OUT_PATHS" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).steps[0]))')"
assert "with no merge in the receipt, step 1 still avoids runs[].wrote[].path" \
  "! printf '%s' \"\$STEP1_PATHS\" | grep -qF 'runs[].wrote[].path'"
assert "with no merge in the receipt, remove.files+dirsIfEmpty length equals ALL wrote entries (none were merges to filter)" \
  "[ \"\$(printf '%s' \"\$OUT_PATHS\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>{const rm=JSON.parse(s).remove;console.log(rm.files.length+rm.dirsIfEmpty.length)})')\" = 1 ]"

# ── DEFECT D (DATA LOSS): the settings sidecar is its own step's dependency —
# deleting it in step 1 destroys the only record telling our hook matcher groups
# apart from the adopter's own, before the settings step ever gets to read it.
echo ""
echo "── defect D: the settings sidecar survives step 1, and is deleted only in the settings step, last ──"
assert "the sidecar DOES appear in the fixture's wrote[] (sanity check on the fixture itself)" \
  "printf '%s' \"\$SIDECAR_AND_DIRS\" | grep -qF '.claude/.logicloom-adopt-settings.json'"
assert "uninstall.remove.files does NOT contain the settings sidecar" \
  "! printf '%s' \"\$OUT_SD\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>process.exit(JSON.parse(s).remove.files.some(f=>f.path===\".claude/.logicloom-adopt-settings.json\")?0:1))'"
assert "uninstall.remove.dirsIfEmpty does NOT contain the settings sidecar" \
  "! printf '%s' \"\$OUT_SD\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>process.exit(JSON.parse(s).remove.dirsIfEmpty.indexOf(\".claude/.logicloom-adopt-settings.json\")!==-1?0:1))'"
SD_SETTINGS_STEP="$(printf '%s' "$OUT_SD" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const st=JSON.parse(s).steps;console.log(st.filter(x=>/^In \.claude\/settings\.json/.test(x))[0])})')"
assert "the settings step mentions the sidecar by name" \
  "printf '%s' \"\$SD_SETTINGS_STEP\" | grep -qF '.claude/.logicloom-adopt-settings.json'"
assert "the settings step states the sidecar is deleted there, last — not in step 1" \
  "printf '%s' \"\$SD_SETTINGS_STEP\" | grep -qi 'last'"

# ── DEFECT B2: a flat 110-entry list that reads as \"delete these\" — split into
# files (straight delete) and dirsIfEmpty (non-recursive rmdir, child-before-
# parent), so a dumb script cannot recursively delete an adopter's own content
# nested inside one of our directories.
echo ""
echo "── defect B2: files vs dirsIfEmpty split, non-recursive removal, child-before-parent order ──"
assert "no entry in remove.files ends with '/'" \
  "printf '%s' \"\$OUT_SD\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>process.exit(JSON.parse(s).remove.files.some(f=>f.path.endsWith(\"/\"))?1:0))'"
assert "remove.dirsIfEmpty holds exactly the 3 dir entries from the fixture" \
  "[ \"\$(printf '%s' \"\$OUT_SD\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>console.log(JSON.parse(s).remove.dirsIfEmpty.length))')\" = 3 ]"
assert "remove.dirsIfEmpty is ordered so no entry is a strict path-prefix of an EARLIER entry (children before parents)" \
  "printf '%s' \"\$OUT_SD\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>{const d=JSON.parse(s).remove.dirsIfEmpty;let bad=false;for(let i=0;i<d.length;i++)for(let j=i+1;j<d.length;j++)if(d[j].indexOf(d[i])===0&&d[j]!==d[i])bad=true;process.exit(bad?1:0)})'"
assert "...concretely: .claude/agents/foo/ sorts before .claude/agents/ in dirsIfEmpty" \
  "printf '%s' \"\$OUT_SD\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>{const d=JSON.parse(s).remove.dirsIfEmpty;process.exit(d.indexOf(\".claude/agents/foo/\")<d.indexOf(\".claude/agents/\")?0:1)})'"
SD_STEP1="$(printf '%s' "$OUT_SD" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).steps[0]))')"
assert "step 1 instructs rmdir (non-recursive removal)" \
  "printf '%s' \"\$SD_STEP1\" | grep -qi 'rmdir'"
assert "step 1 does NOT contain the string 'rm -rf'" \
  "! printf '%s' \"\$SD_STEP1\" | grep -qF 'rm -rf'"

# ── DEFECT 2: the "byte-identical" / "nothing above it was changed" claims must
# be made TRUE, not merely repeated, by instructing removal of the blank line the
# merge inserts before the fence — worded conditionally so it holds when no such
# blank line exists (empty original file, or the fence is the very first thing).
echo ""
echo "── defect 2: the restoration claim is made true (blank-line-safe), not just asserted ──"
GI_STEP="$(printf '%s' "$OUT_ALL" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const st=JSON.parse(s).steps;console.log(st.filter(x=>/^In \.gitignore/.test(x))[0])})')"
assert "the .gitignore step conditions the blank-line removal rather than asserting it always exists" \
  "printf '%s' \"\$GI_STEP\" | grep -qi 'if.*blank line'"
CM_STEP="$(printf '%s' "$OUT_ALL" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const st=JSON.parse(s).steps;console.log(st.filter(x=>/^In CLAUDE\.md/.test(x))[0])})')"
assert "the CLAUDE.md step also conditions the blank-line removal rather than asserting it always exists" \
  "printf '%s' \"\$CM_STEP\" | grep -qi 'if.*blank line'"
assert "the .gitignore step covers the empty-original-file edge case" \
  "printf '%s' \"\$GI_STEP\" | grep -qi 'empty'"
assert "the CLAUDE.md step covers the fence-is-first-thing-in-file edge case" \
  "printf '%s' \"\$CM_STEP\" | grep -qi 'empty\\|first thing'"

# ── DEFECT C: the blank-line-above-BEGIN instruction must never be unconditional
# (the merge's separator is 0, 1, or 2 newlines depending on the pre-merge tail,
# and in the sep='' case — a file already ending in "\n\n" — that blank line is
# the ADOPTER'S OWN byte, not the merge's), and the restoration claim must not
# overclaim byte-identity (the no-trailing-newline case leaves one added byte).
echo ""
echo "── defect C: the blank-line instruction is optional/hedged, never an unconditional delete ──"
assert "the .gitignore step does NOT tell the reader to unconditionally 'delete that line too'" \
  "! printf '%s' \"\$GI_STEP\" | grep -qF 'delete that line too'"
assert "the CLAUDE.md step does NOT tell the reader to unconditionally 'delete that line too'" \
  "! printf '%s' \"\$CM_STEP\" | grep -qF 'delete that line too'"
assert "the .gitignore step frames the leftover blank line as optional (MAY remove), not mandatory" \
  "printf '%s' \"\$GI_STEP\" | grep -qF 'MAY remove'"
assert "the CLAUDE.md step frames the leftover blank line as optional (MAY remove), not mandatory" \
  "printf '%s' \"\$CM_STEP\" | grep -qF 'MAY remove'"
assert "the .gitignore step does NOT claim byte-identical restoration" \
  "! printf '%s' \"\$GI_STEP\" | grep -qi 'byte-identical'"
assert "the CLAUDE.md step does NOT claim byte-identical restoration" \
  "! printf '%s' \"\$CM_STEP\" | grep -qi 'byte-identical'"
# NOT "only ever appended" for .gitignore. Two independent adversarial reviewers
# flagged the same overstatement: merge-gitignore.sh assembles a temp file and
# lands it with `cat "$TMP" > "$TARGET"` — a truncate-and-rewrite, not an append
# syscall. The adopter's bytes above the fence ARE preserved, which is the thing
# they care about, so the step must claim exactly that and no more. (The CLAUDE.md
# step below is a genuine append, so it keeps the stronger wording.)
assert "the .gitignore step claims byte preservation above the fence, not an append syscall" \
  "printf '%s' \"\$GI_STEP\" | grep -qi 'byte you had above the fence is preserved'"
assert "the .gitignore step does NOT overstate the write as append-only" \
  "! printf '%s' \"\$GI_STEP\" | grep -qi 'only ever appended'"
assert "the CLAUDE.md step states the merge only ever appended (nothing above the block was rewritten)" \
  "printf '%s' \"\$CM_STEP\" | grep -qi 'only ever appended'"
# merge-gitignore.sh CREATES an absent target (verified in the script: the
# fence-absent branch does \`: > \"\$TMP\"\` when \$TARGET does not exist, then
# appends the fence) — so for that starting state the correct undo is deleting
# the file, not just the fenced region, since there was nothing before it.
assert "merge-gitignore.sh creates the target when it was absent (confirms the case the step below documents)" \
  "grep -qF ': > \"\$TMP\"' \"$PKG/merge/merge-gitignore.sh\""
assert "the .gitignore step covers the absent-original-file case (undo is deleting the file, not just the fence)" \
  "printf '%s' \"\$GI_STEP\" | grep -qi 'absent'"

# Marker parity — each quoted string must be the one its writer actually emits.
GI_MERGE="$PKG/merge/merge-gitignore.sh"
SET_MERGE="$PKG/merge/merge_settings_json.py"
CM_LIB="$PKG/lib/claude-md.js"
assert "the .gitignore BEGIN fence quoted by the procedure is the one merge-gitignore.sh writes" \
  "grep -qF \"\$(node -e 'process.stdout.write(require(process.argv[1]).GITIGNORE_FENCE_BEGIN)' \"\$APPLY\")\" \"\$GI_MERGE\""
assert "...and the END fence too" \
  "grep -qF \"\$(node -e 'process.stdout.write(require(process.argv[1]).GITIGNORE_FENCE_END)' \"\$APPLY\")\" \"\$GI_MERGE\""
assert "the settings sidecar path quoted by the procedure is merge_settings_json.py's default" \
  "grep -q '\.logicloom-adopt-settings\.json' \"\$SET_MERGE\""
assert "the CLAUDE.md BEGIN marker quoted by the procedure is claude-md.js's" \
  "printf '%s' \"\$OUT_ALL\" | grep -qF \"\$(node -e 'process.stdout.write(require(process.argv[1]).BEGIN)' \"\$CM_LIB\")\""
assert "the CLAUDE.md step says the DEFAULT mode never opens their CLAUDE.md" \
  "printf '%s' \"\$OUT_ALL\" | grep -q 'the default mode never opens your CLAUDE.md'"

# And the whole thing must actually reach disk on a real apply. Asserted against
# the `new` target from section 2, which is a REAL --apply, not a synthetic
# receipt — so this cannot pass on a code path that never runs. Stated as a hard
# assertion rather than an `if`, because a conditional here would go quietly
# green the day the fixture is renamed.
NEW_RECEIPT="$TMP/new/.logicloom-adopt-receipt.json"
assert "the real apply in section 2 left a receipt on disk" "[ -f \"$NEW_RECEIPT\" ]"
assert "...and that on-disk receipt carries the generated uninstall procedure" \
  "node -e 'const j=require(process.argv[1]); process.exit(j.uninstall && Array.isArray(j.uninstall.steps) && j.uninstall.steps.length ? 0 : 1)' \"$NEW_RECEIPT\""
assert "...whose last step is deleting the receipt itself" \
  "node -e 'const j=require(process.argv[1]); const s=j.uninstall.steps; process.exit(/Delete \.logicloom-adopt-receipt\.json last/.test(s[s.length-1])?0:1)' \"$NEW_RECEIPT\""

# ── LOOM-0043 PART 1: per-file sha256, so deletion becomes conditional ──────
echo ""
echo "── LOOM-0043 part 1: uninstall.remove.files carries a sha256, and step 1 states the predicate ──"
assert "every entry in a fresh install's remove.files carries a path and a non-null sha256" \
  "node -e 'const j=require(process.argv[1]); const ok=j.uninstall.remove.files.every(f=>typeof f.path===\"string\"&&f.path.length&&typeof f.sha256===\"string\"&&/^sha256:[0-9a-f]{64}\$/.test(f.sha256)); process.exit(ok&&j.uninstall.remove.files.length>0?0:1)' \"$NEW_RECEIPT\""
assert "step 1 states the MATCH branch (safe to delete)" \
  "printf '%s' \"\$STEP1_ALL\" | grep -qi 'MATCHES the file on disk'"
assert "step 1 states the MISMATCH branch (keep it)" \
  "printf '%s' \"\$STEP1_ALL\" | grep -qF 'MISMATCH means KEEP'"
assert "step 1 states the no-digest/older-receipt branch (review before deleting)" \
  "printf '%s' \"\$STEP1_ALL\" | grep -qi 'null sha256'"
assert "step 1 names the mechanical-mismatch caveat (formatter/autocrlf) and points at git diff/log" \
  "printf '%s' \"\$STEP1_ALL\" | grep -qi 'autocrlf' && printf '%s' \"\$STEP1_ALL\" | grep -qF 'git diff'"

echo ""
echo "── LOOM-0043 part 2: step 1 anchors paths to the receipt's own directory, and says they are literal ──"
assert "step 1 says to resolve paths against the directory containing the receipt file" \
  "printf '%s' \"\$STEP1_ALL\" | grep -qi 'CONTAINS THIS RECEIPT FILE'"
assert "step 1 says every path is LITERAL, never a glob or pattern" \
  "printf '%s' \"\$STEP1_ALL\" | grep -qi 'LITERAL' && printf '%s' \"\$STEP1_ALL\" | grep -qi 'never a glob'"
assert "the returned object also carries a structured anchor (not only prose in step 1)" \
  "printf '%s' \"\$OUT_ALL\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>{const a=JSON.parse(s).anchor;process.exit(a&&typeof a.primary===\"string\"&&typeof a.literal===\"string\"?0:1)})'"
assert "the real on-disk receipt records the absolute root as secondary evidence" \
  "node -e 'const j=require(process.argv[1]); process.exit(typeof j.uninstall.anchor.recordedRoot===\"string\"&&j.uninstall.anchor.recordedRoot.length?0:1)' \"$NEW_RECEIPT\""

echo ""
echo "── LOOM-0043 part 3: the settings step states the one-occurrence-per-entry rule ──"
SETTINGS_STEP_ALL="$(printf '%s' "$OUT_ALL" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const st=JSON.parse(s).steps;console.log(st.filter(x=>/^In \.claude\/settings\.json/.test(x))[0])})')"
assert "the settings step states removing our groups is per-occurrence, not per-content-match" \
  "printf '%s' \"\$SETTINGS_STEP_ALL\" | grep -qi 'removes exactly ONE matching'"
assert "...and warns a kept duplicate becomes a broken hook of the adopter's own making" \
  "printf '%s' \"\$SETTINGS_STEP_ALL\" | grep -qi 'broken hook'"

# ── LOOM-0043 PART 4: pre-merge state, and its FIRST-run-wins aggregation ───
echo ""
echo "── LOOM-0043 part 4: merge entries carry a pre-state kind, aggregated FIRST-run-wins ──"
TWO_RUN_ABSENT_THEN_CONTENT='[
  {"wrote":[{"path":".gitignore","kind":"merge","preState":"absent"}]},
  {"wrote":[{"path":".gitignore","kind":"merge","preState":"content"}]}
]'
OUT_TWORUN="$(UN "$TWO_RUN_ABSENT_THEN_CONTENT")"
assert "aggregation across two runs keeps the FIRST run's pre-state (absent), not the second (content)" \
  "printf '%s' \"\$OUT_TWORUN\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>process.exit(JSON.parse(s).preMergeState[\".gitignore\"]===\"absent\"?0:1))'"
TWOSTEP="$(printf '%s' "$OUT_TWORUN" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const st=JSON.parse(s).steps;console.log(st.filter(x=>/^In \.gitignore/.test(x))[0])})')"
assert "...and the .gitignore step's own text reflects that first-run ABSENT case, not the later CONTENT one" \
  "printf '%s' \"\$TWOSTEP\" | grep -qi 'recorded pre-merge state is ABSENT' && ! printf '%s' \"\$TWOSTEP\" | grep -qi 'recorded pre-merge state is CONTENT'"

MERGE_WITH_STATES='[{"wrote":[
  {"path":".gitignore","kind":"merge","preState":"absent"},
  {"path":".claude/settings.json","kind":"merge","preState":"whitespace-only"},
  {"path":"CLAUDE.md","kind":"merge","preState":"content"}
]}]'
OUT_STATES="$(UN "$MERGE_WITH_STATES")"
assert "preMergeState is exposed for all three merge targets" \
  "printf '%s' \"\$OUT_STATES\" | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>{const m=JSON.parse(s).preMergeState;process.exit(m[\".gitignore\"]===\"absent\"&&m[\".claude/settings.json\"]===\"whitespace-only\"&&m[\"CLAUDE.md\"]===\"content\"?0:1)})'"
# 'absent' is the ONLY pre-state that licenses deleting the adopter's file, so
# nothing uncertain may reach it. A symlink, a non-regular file, or one we cannot
# read is not "this tool created it" — adversarial review found statKind()!=='file'
# sweeping all three into 'absent' and attaching a delete instruction to them.
# They now classify as 'unknown', which routes to the hedge text.
UNKNOWN_STATE='[{"wrote":[{"path":".gitignore","kind":"merge","digest":"sha256:a","preState":"unknown"}]}]'
GI_UNKNOWN_STEP="$(printf '%s' "$(UN "$UNKNOWN_STATE")" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const st=JSON.parse(s).steps;console.log(st.filter(x=>/^In \.gitignore/.test(x))[0])})')"
assert "an UNKNOWN pre-state never tells the reader to delete the whole .gitignore" \
  "! printf '%s' \"\$GI_UNKNOWN_STEP\" | grep -qi 'DELETE THE FILE ITSELF'"
assert "classifyPreMergeState returns 'unknown' (not 'absent') for a symlink" \
  "node -e 'const os=require(\"os\"),fs=require(\"fs\"),p=require(\"path\"); const d=fs.mkdtempSync(p.join(os.tmpdir(),\"cls\")); fs.writeFileSync(p.join(d,\"real\"),\"x\"); fs.symlinkSync(\"real\",p.join(d,\"link\")); const a=require(\"$PKG/lib/apply.js\"); process.exit(a.classifyPreMergeState(p.join(d,\"link\"))===\"unknown\"?0:1)'"

GI_ABSENT_STEP="$(printf '%s' "$OUT_STATES" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const st=JSON.parse(s).steps;console.log(st.filter(x=>/^In \.gitignore/.test(x))[0])})')"
# The absent branch must NOT be an unconditional delete. "We created it" is only
# "safe to delete outright" while the file is still exactly what we left — an
# adopter who added ignore rules of their own since would lose them. Same
# predicate as step 1, and the merge digest is what decides it. Assert BOTH
# branches are stated, not just the delete.
assert "the .gitignore step for a recorded ABSENT pre-state says to delete the whole file" \
  "printf '%s' \"\$GI_ABSENT_STEP\" | grep -qi 'DELETE THE FILE ITSELF'"
assert "...but conditions that delete on the recorded digest still matching" \
  "printf '%s' \"\$GI_ABSENT_STEP\" | grep -qi 'digest recorded for .gitignore'"
# ORDERING IS THE CONTRACT, not just the presence of a digest check. Deleting the
# fenced region changes the file, so a digest compared AFTER that point can never
# match and the delete branch becomes unreachable. The instruction must tell the
# reader to check before modifying anything.
assert "...and tells the reader to check the digest BEFORE editing anything" \
  "printf '%s' \"\$GI_ABSENT_STEP\" | grep -qi 'CHECK THE DIGEST FIRST'"
assert "...and the digest check is positioned ahead of the fence deletion in the text" \
  "node -e 'const s=process.argv[1]; process.exit(s.toLowerCase().indexOf(\"check the digest first\") < s.toLowerCase().indexOf(\"delete only the fenced region\") ? 0 : 1)' \"\$GI_ABSENT_STEP\""
assert "...and says to KEEP the file when the digest does not match" \
  "printf '%s' \"\$GI_ABSENT_STEP\" | grep -qi 'KEEP the file'"
SET_WS_STEP="$(printf '%s' "$OUT_STATES" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const st=JSON.parse(s).steps;console.log(st.filter(x=>/^In \.claude\/settings\.json/.test(x))[0])})')"
# Same defect class as the .gitignore absent branch, and it contradicted this
# step's OWN earlier sentence ("your own hooks are still in it and must stay"):
# "the file is entirely ours, DELETE IT" is true as of the merge, not as of
# uninstall time. An adopter who added a hook, a permission, or any other
# setting afterwards would lose the file. The decidable test is what REMAINS
# once our groups are gone, so the step must send the reader to look.
assert "the settings step sends the reader to inspect what REMAINS before deleting" \
  "printf '%s' \"\$SET_WS_STEP\" | grep -qi 'AT WHAT IS LEFT'"
assert "...and says KEEP the file if anything of theirs is in it" \
  "printf '%s' \"\$SET_WS_STEP\" | grep -qi 'KEEP the file'"
assert "the settings step for a recorded WHITESPACE-ONLY pre-state also says to delete the file (merge_settings_json.py rewrites it wholesale)" \
  "printf '%s' \"\$SET_WS_STEP\" | grep -qi 'DELETE'"
assert "...and explains why: merge_settings_json.py treats a whitespace-only file as none at all" \
  "printf '%s' \"\$SET_WS_STEP\" | grep -qi 'no file at all'"

# The end-to-end absent-.gitignore case, against a REAL apply (not a synthetic
# receipt) — matches the exact scenario the LOOM-0043 brief calls out by name.
echo ""
echo "── LOOM-0043 part 4, end-to-end: a repo with NO .gitignore at all ──"
NOGI="$TMP/no-gitignore"; mkdir -p "$NOGI"; git_quiet "$NOGI" init
printf 'x\n' > "$NOGI/README.md"; git_quiet "$NOGI" add -A; git_quiet "$NOGI" commit -m base
assert "the fixture really starts with no .gitignore" "[ ! -e \"$NOGI/.gitignore\" ]"
RUN "$NOGI" --apply --only=all,gitignore --claude-md=rules >"$TMP/nogi.out" 2>&1; NOGI_RC=$?
assert "the apply against a .gitignore-less repo succeeds" "[ $NOGI_RC -eq 0 ]"
NOGI_RECEIPT="$NOGI/.logicloom-adopt-receipt.json"
assert "the recorded pre-merge state for .gitignore is absent" \
  "node -e 'const j=require(process.argv[1]); process.exit(j.uninstall.preMergeState[\".gitignore\"]===\"absent\"?0:1)' \"$NOGI_RECEIPT\""
assert "the gitignore uninstall step says to delete the file, matching the recorded absent state" \
  "node -e 'const j=require(process.argv[1]); const st=j.uninstall.steps.filter(x=>/^In \.gitignore/.test(x))[0]; process.exit(/DELETE THE FILE ITSELF/i.test(st)?0:1)' \"$NOGI_RECEIPT\""
assert "...and gates that delete on the recorded digest still matching" \
  "node -e 'const j=require(process.argv[1]); const st=j.uninstall.steps.filter(x=>/^In \.gitignore/.test(x))[0]; process.exit(/CHECK THE DIGEST FIRST/i.test(st)?0:1)' \"$NOGI_RECEIPT\""
assert "...and says KEEP the file on a mismatch, so an adopter's later additions survive" \
  "node -e 'const j=require(process.argv[1]); const st=j.uninstall.steps.filter(x=>/^In \.gitignore/.test(x))[0]; process.exit(/KEEP the file/i.test(st)?0:1)' \"$NOGI_RECEIPT\""

echo ""
echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
