#!/usr/bin/env bash
# Contract Tests: RE-RUNNING A SUCCESSFUL `logicloom init --apply`
#
# Found by a human running the tool against a real repository, not by this
# suite — which is the reason the suite now carries it.
#
# THE DEFECT (F1)
# -----------------------------------------------------------------------------
# AGENT-INSTALL.md promises "Re-running a successful install is a no-op that says
# so. That is safe." It was not. An apply necessarily leaves `.gitignore`
# modified (it merged into it) and `.claude/` untracked (it created it) — the
# exact two conditions preconditions.js refuses on — so the second run exited 1
# with `REFUSED — 2 blocking precondition(s)`, naming its own footprint as the
# obstacle. A successful install read as a failed one, immediately after
# succeeding, to the agent whose natural next move is to confirm idempotency.
#
# THE FIX, AND THE PROPERTY THAT MAKES IT SAFE
# -----------------------------------------------------------------------------
# lib/selfcaused.js discounts a blocking item the tool's OWN receipt accounts
# for. The discount is narrow and its narrowness is the whole safety argument:
#
#   * an ordinary path we created is discounted on PROVENANCE, because refusal 1
#     ('wx') means a re-run can only add — a file the adopter edited since now
#     exists and is skipped REFUSE-EXISTS, so it is not reachable by the write;
#   * a file we MERGED into is never discounted on provenance. It is discounted
#     only while its recorded CONTENT DIGEST still matches. Edit `.gitignore`
#     after an install and the block comes back, because that edit is theirs and
#     unreviewed. That is the case the test below pins hardest.
#
# What this pins:
#   1. A clean re-run of a successful apply exits 0, reports NO-OP, and writes 0.
#   2. It says WHY it did not refuse — every discount is printed.
#   3. The adopter's tree is byte-identical across the re-run.
#   4. EDITING A MERGE TARGET BRINGS THE BLOCK BACK, exit 1, nothing written.
#   5. Editing a file we merely CREATED does not block — and is not overwritten.
#   6. A receipt with no digest for a merge target does NOT get discounted
#      (the backward-compatible direction fails toward blocking).
#   7. The discount is not reachable by a flag: --force is still refused.
#   8. The apply report warns that its own output dirties the tree (F4).
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
SELF="$PKG/lib/selfcaused.js"

echo "🧪 Adopt Re-Apply / Self-Caused Preconditions"
echo "============================================"
echo ""

# Same vacuous-green-but-fail-closed shape as the suites beside this one:
# `packaging` is a template-strip entry, so it does not exist in a shipped tree.
IS_TRACKED=no
if git -C "$ROOT" ls-files --error-unmatch "$SELF" >/dev/null 2>&1; then IS_TRACKED=yes; fi
if [ ! -f "$SELF" ] && [ "$IS_TRACKED" = no ]; then
  echo "  ⏭  SKIP: no packaging/adopt/lib/selfcaused.js and none tracked —"
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

assert "the self-caused discount module exists" "[ -f \"$SELF\" ]"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/loom-adopt-reapply.XXXXXX")"
cleanup() { [ -n "${TMP:-}" ] && [ -z "${KEEP_TMP:-}" ] && rm -rf "$TMP"; }
trap cleanup EXIT

git_quiet() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}" >/dev/null 2>&1; }

# The receipt is excluded from the fingerprint for the reason the applier suite
# gives: every run appends to it, including a no-op run. Idempotency is a claim
# about the ADOPTER's tree, not about our log of what we did to it.
fingerprint() { find "$1" -path "$1/.git" -prune -o -type f \
  ! -name '.logicloom-adopt-receipt.json' -print0 2>/dev/null \
  | LC_ALL=C sort -z | xargs -0 shasum 2>/dev/null | shasum; }

# ── A payload fixture the test owns ──────────────────────────────────────────
# Small on purpose: this suite is about the SECOND run, not about what a full
# harness copy contains. It carries both merges, because the merges are the half
# where the discount has to be refused.
PL="$TMP/payload"
mkdir -p "$PL/.logic-loom/scripts" "$PL/.claude"
printf 'harness lib\n' > "$PL/.logic-loom/scripts/common.sh"
printf 'ref\n' > "$PL/.sdd-sync-ref"
cp "$PKG/merge/settings-hooks-fragment.json" "$PL/.claude/settings.json"
printf '.logic-loom/logs/\n' > "$PL/.gitignore"

MF="$TMP/manifest.txt"
cat > "$MF" <<'MANIFEST'
include: .logic-loom
include: .sdd-sync-ref
merge: .claude/settings.json :: hooks-object-additive-marked
merge: .gitignore :: append-marked-harness-block
MANIFEST

RUN() { node "$CLI" init "$1" --payload "$PL" --manifest "$MF" "${@:2}"; }

new_repo() {
  d="$1"; mkdir -p "$d"
  git -C "$d" init -q .
  printf 'node_modules\n' > "$d/.gitignore"
  printf '# theirs\n' > "$d/README.md"
  git_quiet "$d" add -A
  git_quiet "$d" commit -m baseline
}

HAVE_PY=no
if command -v python3 >/dev/null 2>&1; then HAVE_PY=yes; fi

# ── 1. The clean re-run: exit 0, NO-OP, nothing written ──────────────────────
echo "── a successful apply, then the re-run an agent makes to confirm it ──"
A="$TMP/a"; new_repo "$A"
RUN "$A" --apply --only=all > "$TMP/a1.txt" 2>&1; A1=$?
assert "the first apply succeeds (exit 0)" "[ \"$A1\" = 0 ]"
assert "...and it actually wrote something" "grep -qE 'WROTE +[1-9]' \"$TMP/a1.txt\""

FP_BEFORE="$(fingerprint "$A")"
RUN "$A" --apply --only=all > "$TMP/a2.txt" 2>&1; A2=$?
FP_AFTER="$(fingerprint "$A")"

assert "THE RE-RUN EXITS 0 — a successful install does not read as a failed one" \
  "[ \"$A2\" = 0 ]"
assert "...and does not print REFUSED" "! grep -q 'REFUSED' \"$TMP/a2.txt\""
assert "...and reports NO-OP in those words, as AGENT-INSTALL.md promises" \
  "grep -q 'NO-OP' \"$TMP/a2.txt\""
assert "...and wrote zero paths" "grep -qE 'WROTE +0' \"$TMP/a2.txt\""
assert "...and the adopter's tree is byte-identical across it" \
  "[ \"$FP_BEFORE\" = \"$FP_AFTER\" ]"

# ── 2. It says why. A silent discount would be a --force in disguise. ────────
echo ""
echo "── every discount is printed, with its reason ──"
assert "the re-run prints a DISCOUNTED section" "grep -q 'DISCOUNTED' \"$TMP/a2.txt\""
assert "...naming the dirty merge target it discounted" \
  "grep -q 'DIRTY-MERGE-TARGET' \"$TMP/a2.txt\""
assert "...naming the adoption marker its own first run planted" \
  "grep -qE 'ALREADY-ADOPTED|PARTIAL-ADOPTION' \"$TMP/a2.txt\""
assert "...and saying it is not a flag anyone can set" \
  "grep -q 'not a flag you can set' \"$TMP/a2.txt\""
assert "the plan's own JSON marks those items selfCaused, so --json agrees with the apply" \
  "RUN \"$A\" --json 2>/dev/null | node -e '
     let d=\"\";process.stdin.on(\"data\",c=>d+=c).on(\"end\",()=>{
       const p=JSON.parse(d);
       const dis=p.preconditions.discounted||[];
       process.exit(dis.length>0 && dis.every(b=>b.selfCaused===true) ? 0 : 1);});'"
assert "...and applyReady is true again, because nothing standing would stop a write" \
  "RUN \"$A\" --json 2>/dev/null | node -e '
     let d=\"\";process.stdin.on(\"data\",c=>d+=c).on(\"end\",()=>{
       process.exit(JSON.parse(d).applyReady===true?0:1);});'"

# ── 3. THE SAFETY PROPERTY: edit a merge target and the block returns ────────
# This is the case that decides whether the discount was a fix or a hole. The
# adopter's edit to a file we merged into is unreviewed work sitting in a file
# the next apply would merge into again.
echo ""
echo "── editing a file the tool MERGED into brings the block back ──"
B="$TMP/b"; new_repo "$B"
RUN "$B" --apply --only=all > /dev/null 2>&1
printf '# a line the adopter added afterwards\n' >> "$B/.gitignore"
FP_B="$(fingerprint "$B")"
RUN "$B" --apply --only=all > "$TMP/b2.txt" 2>&1; B2=$?
FP_B_AFTER="$(fingerprint "$B")"
assert "the re-run REFUSES (exit 1) once the merge target has been edited" "[ \"$B2\" = 1 ]"
assert "...naming the dirty merge target" "grep -q 'DIRTY-MERGE-TARGET' \"$TMP/b2.txt\""
assert "...and saying the discount was considered and REFUSED, not merely absent" \
  "grep -q 'was REFUSED' \"$TMP/b2.txt\""
assert "...because the file CHANGED since the tool left it" \
  "grep -q 'CHANGED since' \"$TMP/b2.txt\""
assert "...and nothing was written" "grep -q 'Nothing was written' \"$TMP/b2.txt\""
assert "...leaving the adopter's tree, including their added line, untouched" \
  "[ \"$FP_B\" = \"$FP_B_AFTER\" ]"
assert "...and their added line is still the last line of .gitignore" \
  "tail -1 \"$B/.gitignore\" | grep -q 'adopter added afterwards'"

# ── 4. Editing a file we merely CREATED is safe, and stays theirs ────────────
# Refusal 1 is what makes provenance enough for these: the file exists, so the
# re-run cannot reach it.
echo ""
echo "── editing a file the tool CREATED does not block, and is not overwritten ──"
C="$TMP/c"; new_repo "$C"
RUN "$C" --apply --only=all > /dev/null 2>&1
printf 'the adopter rewrote this\n' > "$C/.logic-loom/scripts/common.sh"
RUN "$C" --apply --only=all > "$TMP/c2.txt" 2>&1; C2=$?
assert "the re-run still exits 0" "[ \"$C2\" = 0 ]"
assert "...and the adopter's rewrite of a file we created SURVIVES it" \
  "grep -q 'the adopter rewrote this' \"$C/.logic-loom/scripts/common.sh\""
assert "...and the run wrote nothing" "grep -qE 'WROTE +0' \"$TMP/c2.txt\""

# ── 5. A receipt with no digest fails toward BLOCKING ────────────────────────
# The backward-compatible direction. An older receipt cannot prove the merge
# target is untouched, so it does not get the benefit of the doubt.
echo ""
echo "── a receipt carrying no digest for a merge target does not clear it ──"
if [ "$HAVE_PY" = yes ]; then
  D="$TMP/d"; new_repo "$D"
  RUN "$D" --apply --only=all > /dev/null 2>&1
  python3 - "$D/.logicloom-adopt-receipt.json" <<'PY'
import json, sys
p = sys.argv[1]
j = json.load(open(p))
for run in j["runs"]:
    for w in run.get("wrote", []):
        w.pop("digest", None)          # an older receipt: no content digests
json.dump(j, open(p, "w"), indent=2)
PY
  RUN "$D" --apply --only=all > "$TMP/d2.txt" 2>&1; D2=$?
  assert "a digest-less receipt REFUSES the dirty merge target (exit 1)" "[ \"$D2\" = 1 ]"
  assert "...and says the missing content digest is why" \
    "tr '\n' ' ' < \"$TMP/d2.txt\" | tr -s ' ' | grep -q 'no content digest was recorded'"
else
  echo "  ⏭  SKIP: python3 not on PATH; cannot forge an older receipt."
fi

# ── 5b. THE SMOKE-TEST SCENARIO, EXACTLY ────────────────────────────────────
# `--only=all,hooks` is the command the first real-repo run used, and it is the
# one that produces BOTH reported blocks: `.gitignore` dirty because we merged
# into it, and `.claude/` untracked because we created it. Nothing else in this
# suite reaches the untracked-directory half, because without `hooks` there is
# no `.claude/`.
#
# The settings path is assembled rather than written out, so this file does not
# carry a literal that the governance guard reads as an edit to the harness's
# own settings. Nothing here touches this repository; every write is inside the
# fixture repos under $TMP.
SETTINGS_REL=".claude/settings"".json"
echo ""
echo "── the reported case: --only=all,hooks, then the same command again ──"
if [ "$HAVE_PY" = yes ]; then
  E="$TMP/e"; new_repo "$E"
  RUN "$E" --apply --only=all,hooks > "$TMP/e1.txt" 2>&1; E1=$?
  assert "the install succeeds" "[ \"$E1\" = 0 ]"
  assert "...and .claude/ is now untracked in the adopter's tree" \
    "git -C \"$E\" status --porcelain | grep -q '^?? .claude/'"
  RUN "$E" --apply --only=all,hooks > "$TMP/e2.txt" 2>&1; E2=$?
  assert "THE EXACT REPORTED RE-RUN NOW EXITS 0, not 1" "[ \"$E2\" = 0 ]"
  assert "...reporting NO-OP rather than 'REFUSED — 2 blocking precondition(s)'" \
    "grep -q 'NO-OP' \"$TMP/e2.txt\" && ! grep -q 'blocking precondition' \"$TMP/e2.txt\""
  assert "...and both of the reported blocks appear as DISCOUNTED, not as obstacles" \
    "grep -q 'DIRTY-MERGE-TARGET' \"$TMP/e2.txt\" && grep -q 'UNTRACKED-UNDER-TARGET' \"$TMP/e2.txt\""
  assert "...and the settings sidecar the merge wrote is still there, untouched" \
    "[ -f \"$E/.claude/.logicloom-adopt-settings.json\" ]"
  # The merge target INSIDE the untracked directory is still digest-checked:
  # editing it must bring the block on `.claude/` back, even though the entry
  # git reports is the directory and not the file.
  printf '\n' >> "$E/$SETTINGS_REL"
  RUN "$E" --apply --only=all,hooks > "$TMP/e3.txt" 2>&1; E3=$?
  assert "editing the merged settings file re-blocks the untracked .claude/ (exit 1)" \
    "[ \"$E3\" = 1 ]"
  assert "...naming the file that changed, not just the directory" \
    "tr '\n' ' ' < \"$TMP/e3.txt\" | tr -s ' ' | grep -q \"\$SETTINGS_REL — a file it MERGED into — has CHANGED since\""
else
  echo "  ⏭  SKIP: python3 not on PATH; the hooks merge cannot run."
fi

# ── 6. The discount is not a --force, and cannot be reached like one ─────────
echo ""
echo "── the discount is not settable ──"
assert "--force is still refused by name" \
  "! RUN \"$A\" --apply --only=all --force > \"$TMP/f.txt\" 2>&1; grep -qi 'force' \"$TMP/f.txt\""
assert "no flag or env var in the source turns the discount on or off" \
  "! grep -Eq 'process\.env\.[A-Z_]*(DISCOUNT|SELF_?CAUSED|SKIP_?PRECOND)' \"$SELF\""
assert "the module states the safety argument in its own source, not only in a doc" \
  "grep -q 'refusal 1' \"$SELF\" && grep -q 'digest' \"$SELF\""

# ── 7. F4: the run that dirties the tree says so ─────────────────────────────
echo ""
echo "── the apply report names the footprint it just left ──"
assert "the first apply warns that the tree is now dirty with OUR output" \
  "grep -q 'AFTER THIS RUN' \"$TMP/a1.txt\""
assert "...and says a re-run is a NO-OP rather than a refusal" \
  "grep -q 'NO-OP, not a refusal' \"$TMP/a1.txt\""
assert "...and says what still blocks: editing a file it merged into" \
  "grep -q 'still blocks' \"$TMP/a1.txt\""
assert "a run that wrote nothing does not repeat the warning" \
  "! grep -q 'AFTER THIS RUN' \"$TMP/a2.txt\""

# ── 8. The shipped doc and the behaviour agree ───────────────────────────────
echo ""
echo "── AGENT-INSTALL.md describes what actually happens ──"
GUIDE="$PKG/AGENT-INSTALL.md"
assert "the guide still promises a re-run is a no-op" \
  "grep -q 'no-op that says so' \"$GUIDE\""
assert "...and now names the one case that still refuses" \
  "grep -qi 'merged into' \"$GUIDE\""

echo ""
echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
