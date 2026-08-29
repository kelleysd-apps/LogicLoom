#!/usr/bin/env bash
# Contract Tests: the adopt package's two file merges (research § 6 PRE-7, PRE-8)
#
# packaging/adopt/merge/ holds the ONLY two genuine merges in the adopt design —
# everything else in payload-manifest.txt is additive or excluded. Both are
# standalone units an applier will call; the applier does not exist yet, and
# this suite is what keeps them honest until it does.
#
# What it pins:
#   MERGE 1 — .claude/settings.json
#     1. The shipped fragment is byte-equivalent to THIS repo's live hooks
#        block. A hook added to .claude/settings.json and not to the fragment
#        would ship an adopter a thinner governance floor than we run.
#     2. Additive into a file the adopter owns: their keys survive verbatim,
#        their formatting survives (tabs included), their own hooks survive.
#     3. Idempotent — a second run is a byte-for-byte no-op.
#     4. Refusal, three ways: an edit inside our region, a deletion inside it,
#        and our hooks present with no provenance record.
#     5. Dry-run writes nothing.
#
#   MERGE 2 — .gitignore
#     6. Ship/drop coverage in BOTH directions against gitignore-decisions.txt,
#        and every non-comment line of this repo's own .gitignore classified —
#        so a rule added upstream cannot slip into the adopter block unreviewed.
#     7. The four hostile patterns never ship (.vscode/, package-lock.json,
#        dist/, build/) — kori-beta tracks .vscode/settings.json and a 464 KB
#        lock file.
#     8. Append-only: every pre-existing line survives, in order.
#     9. A dirty .gitignore is REPORTED, not appended to — the kori trap, where
#        private-docs rules live only in the working tree.
#    10. Idempotent; refuses on an edit inside the fence.
#
# bash 3.2 safe: no associative arrays, no mapfile, no [[ -v ]], no ${var,,}.
# No `sed -i` (GNU/BSD divergence) — every mutation goes through a temp file.
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

MERGE_DIR="$ROOT/packaging/adopt/merge"
SETTINGS_MERGE="$MERGE_DIR/merge_settings_json.py"
GITIGNORE_MERGE="$MERGE_DIR/merge-gitignore.sh"
FRAGMENT="$MERGE_DIR/settings-hooks-fragment.json"
BLOCK="$MERGE_DIR/gitignore-block.txt"
DECISIONS="$MERGE_DIR/gitignore-decisions.txt"

echo "🧪 Adopt Merges Contract Tests"
echo "=============================="
echo ""

# ── Vacuously green on a stripped tree, FAIL-CLOSED on rot ───────────────────
# Same shape and same reason as test_adopt_payload_manifest.sh: `packaging` is a
# template-strip-manifest entry, so none of this exists in a shipped tree, and
# test_shipped_gates_vs_strip.sh runs the CI steps against a freshly stripped
# tree and requires exit 0. Absent-and-untracked is a legitimate skip;
# absent-but-TRACKED means the unit was deleted out from under the boundary,
# and that still fails.
IS_TRACKED=no
if git -C "$ROOT" ls-files --error-unmatch "$SETTINGS_MERGE" >/dev/null 2>&1; then IS_TRACKED=yes; fi

if [ ! -f "$SETTINGS_MERGE" ] && [ "$IS_TRACKED" = no ]; then
  echo "  ⏭  SKIP: no packaging/adopt/merge/ and none tracked — this is a"
  echo "     stripped or customer tree, where packaging/ never exists."
  echo ""
  echo "Results: $PASS/$TOTAL passed, $FAIL failed"
  exit 0
fi

for f in "$SETTINGS_MERGE" "$GITIGNORE_MERGE" "$FRAGMENT" "$BLOCK" "$DECISIONS"; do
  assert "exists: ${f#$ROOT/}" "[ -f \"$f\" ]"
done
if [ ! -f "$SETTINGS_MERGE" ] || [ ! -f "$GITIGNORE_MERGE" ] || \
   [ ! -f "$FRAGMENT" ] || [ ! -f "$BLOCK" ] || [ ! -f "$DECISIONS" ]; then
  echo ""; echo "Results: $PASS/$TOTAL passed, $FAIL failed"; exit 1
fi

WORK="$(mktemp -d -t loom-adopt-merges.XXXXXX)" || exit 1
trap 'rm -rf "$WORK"' EXIT

PY=python3
command -v python3 >/dev/null 2>&1 || { echo "  ❌ python3 not on PATH"; exit 1; }

echo ""
echo "── MERGE 1 · .claude/settings.json ──────────────────────────────────────"

# 1. The fragment is this repo's live hooks block, canonically identical.
#    NOT a text diff: key order and whitespace are irrelevant, VALUES are not.
$PY - "$ROOT/.claude/settings.json" "$FRAGMENT" > "$WORK/sync" 2>&1 <<'PYEOF'
import json, sys
live = json.load(open(sys.argv[1])).get("hooks")
frag = json.load(open(sys.argv[2])).get("hooks")
c = lambda o: json.dumps(o, sort_keys=True, separators=(",", ":"))
sys.stdout.write("SYNCED" if c(live) == c(frag) else "DRIFT")
PYEOF
assert "fragment matches this repo's live .claude/settings.json hooks block" \
  "grep -q SYNCED \"$WORK/sync\""

assert "fragment contains no statusLine key (hooks only — PRE-7)" \
  "! grep -q statusLine \"$FRAGMENT\""

# 2. Additive into a file the adopter owns, in THEIR style.
#    Tab indent, a compact one-line hook entry, their own PreToolUse group, and
#    a statusLine we must not touch.
printf '{\n\t"permissions": {\n\t\t"allow": ["Bash(npm test)"]\n\t},\n\t"hooks": {\n\t\t"PreToolUse": [\n\t\t\t{\n\t\t\t\t"matcher": "Bash",\n\t\t\t\t"hooks": [{"type": "command", "command": "bash scripts/their-own.sh"}]\n\t\t\t}\n\t\t]\n\t},\n\t"statusLine": {"type": "command", "command": "bash mine.sh"}\n}\n' \
  > "$WORK/theirs.json"
cp "$WORK/theirs.json" "$WORK/theirs.orig"

$PY "$SETTINGS_MERGE" --target "$WORK/theirs.json" --fragment "$FRAGMENT" \
  --record "$WORK/theirs.rec" > "$WORK/dry.out" 2>"$WORK/dry.err"
RC=$?
assert "dry-run exits 0" "[ $RC -eq 0 ]"
assert "dry-run reports status: merged" "grep -q 'status: merged' \"$WORK/dry.err\""
assert "5. dry-run writes NOTHING to the target" \
  "diff -q \"$WORK/theirs.json\" \"$WORK/theirs.orig\" >/dev/null"
assert "dry-run writes no provenance record" "[ ! -f \"$WORK/theirs.rec\" ]"
assert "dry-run output is valid JSON" \
  "$PY -c 'import json,sys; json.load(open(sys.argv[1]))' \"$WORK/dry.out\""
assert "adopter's tab indentation survives" \
  "grep -q '^\\t\"permissions\"' \"$WORK/dry.out\""
assert "adopter's compact one-line hook entry survives verbatim" \
  "grep -q 'scripts/their-own.sh\"}]' \"$WORK/dry.out\""
assert "adopter's statusLine is untouched" \
  "grep -q '\"statusLine\": {\"type\": \"command\", \"command\": \"bash mine.sh\"}' \"$WORK/dry.out\""
assert "adopter's permissions key is untouched" \
  "grep -q '\"allow\": \\[\"Bash(npm test)\"\\]' \"$WORK/dry.out\""

# Every non-hooks key must be VALUE-identical after the merge, and their own
# hook entry must still be in the PreToolUse array.
$PY - "$WORK/theirs.orig" "$WORK/dry.out" > "$WORK/keep" 2>&1 <<'PYEOF'
import json, sys
a = json.load(open(sys.argv[1])); b = json.load(open(sys.argv[2]))
c = lambda o: json.dumps(o, sort_keys=True, separators=(",", ":"))
ok = all(k == "hooks" or c(b.get(k)) == c(v) for k, v in a.items())
ok = ok and c(a["hooks"]["PreToolUse"][0]) in [c(g) for g in b["hooks"]["PreToolUse"]]
ok = ok and len(b["hooks"]["PreToolUse"]) > len(a["hooks"]["PreToolUse"])
sys.stdout.write("KEPT" if ok else "LOST")
PYEOF
assert "keep-theirs: every non-hooks key survives by value" "grep -q KEPT \"$WORK/keep\""

# The merged file must actually carry all of our hook groups.
$PY - "$FRAGMENT" "$WORK/dry.out" > "$WORK/added" 2>&1 <<'PYEOF'
import json, sys
frag = json.load(open(sys.argv[1]))["hooks"]
got = json.load(open(sys.argv[2])).get("hooks", {})
c = lambda o: json.dumps(o, sort_keys=True, separators=(",", ":"))
ok = all(c(g) in [c(x) for x in got.get(ev, [])]
         for ev, gs in frag.items() for g in gs)
sys.stdout.write("ALL" if ok else "MISSING")
PYEOF
assert "every LogicLoom hook group is present after the merge" \
  "grep -q ALL \"$WORK/added\""

# 3. Idempotency.
$PY "$SETTINGS_MERGE" --target "$WORK/theirs.json" --fragment "$FRAGMENT" \
  --record "$WORK/theirs.rec" --write >/dev/null 2>&1
cp "$WORK/theirs.json" "$WORK/after1.json"
$PY "$SETTINGS_MERGE" --target "$WORK/theirs.json" --fragment "$FRAGMENT" \
  --record "$WORK/theirs.rec" --write >/dev/null 2>"$WORK/run2.err"
assert "3. second run is a byte-for-byte no-op" \
  "diff -q \"$WORK/after1.json\" \"$WORK/theirs.json\" >/dev/null"
assert "second run reports status: nochange" \
  "grep -q 'status: nochange' \"$WORK/run2.err\""

# 4a. Human edit INSIDE our region -> refuse, target untouched.
cp "$WORK/after1.json" "$WORK/edited.json"; cp "$WORK/theirs.rec" "$WORK/edited.rec"
$PY - "$WORK/edited.json" <<'PYEOF'
import sys
p = sys.argv[1]; s = open(p).read()
open(p, "w").write(s.replace('"timeout": 3000', '"timeout": 9999', 1))
PYEOF
cp "$WORK/edited.json" "$WORK/edited.pre"
$PY "$SETTINGS_MERGE" --target "$WORK/edited.json" --fragment "$FRAGMENT" \
  --record "$WORK/edited.rec" --write >/dev/null 2>"$WORK/refuse1.err"
RC=$?
assert "4a. an edit inside our region REFUSES (exit 10)" "[ $RC -eq 10 ]"
assert "4a. refusal names the reason" "grep -q '^refused:' \"$WORK/refuse1.err\""
assert "4a. refusal leaves the human edit in place" \
  "diff -q \"$WORK/edited.pre\" \"$WORK/edited.json\" >/dev/null"

# 4b. Human DELETES one of our hook entries -> refuse (not silently re-added).
cp "$WORK/after1.json" "$WORK/del.json"; cp "$WORK/theirs.rec" "$WORK/del.rec"
$PY - "$WORK/del.json" <<'PYEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["hooks"]["PreToolUse"][-1]["hooks"].pop()
open(p, "w").write(json.dumps(d, indent=2) + "\n")
PYEOF
cp "$WORK/del.json" "$WORK/del.pre"
$PY "$SETTINGS_MERGE" --target "$WORK/del.json" --fragment "$FRAGMENT" \
  --record "$WORK/del.rec" --write >/dev/null 2>&1
RC=$?
assert "4b. a deletion inside our region REFUSES (exit 10)" "[ $RC -eq 10 ]"
assert "4b. refusal does not re-add the deleted entry" \
  "diff -q \"$WORK/del.pre\" \"$WORK/del.json\" >/dev/null"

# 4c. Our hooks present, no provenance record -> refuse rather than duplicate.
cp "$WORK/after1.json" "$WORK/norec.json"
$PY "$SETTINGS_MERGE" --target "$WORK/norec.json" --fragment "$FRAGMENT" \
  --record "$WORK/absent.rec" --write >/dev/null 2>"$WORK/refuse3.err"
RC=$?
assert "4c. LogicLoom hooks with no provenance record REFUSES (exit 10)" "[ $RC -eq 10 ]"
assert "4c. refusal explains it cannot tell which entries are ours" \
  "grep -qi 'provenance record' \"$WORK/refuse3.err\""

# A file the adopter does not have yet is a clean create, not a refusal.
$PY "$SETTINGS_MERGE" --target "$WORK/fresh.json" --fragment "$FRAGMENT" \
  --record "$WORK/fresh.rec" --write >/dev/null 2>&1
assert "an absent settings.json is created, not refused" "[ -f \"$WORK/fresh.json\" ]"
assert "the created file is valid JSON with our hooks" \
  "$PY -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d[\"hooks\"] else 1)' \"$WORK/fresh.json\""

# A target that is not JSON must refuse, not corrupt.
printf 'not json at all\n' > "$WORK/bad.json"
$PY "$SETTINGS_MERGE" --target "$WORK/bad.json" --fragment "$FRAGMENT" \
  --record "$WORK/bad.rec" --write >/dev/null 2>&1
RC=$?
assert "an unparseable target REFUSES (exit 10)" "[ $RC -eq 10 ]"
assert "an unparseable target is left untouched" \
  "grep -q 'not json at all' \"$WORK/bad.json\""

echo ""
echo "── MERGE 2 · .gitignore ─────────────────────────────────────────────────"

# 6. Ship/drop coverage, both directions.
grep -E '^ship: ' "$DECISIONS" | sed -e 's/^ship: //' -e 's/[[:space:]]*$//' > "$WORK/ship.txt"
grep -E '^drop: ' "$DECISIONS" | sed -e 's/^drop: //' -e 's/[[:space:]]*::.*$//' -e 's/[[:space:]]*$//' > "$WORK/drop.txt"

assert "decisions file classifies something as ship" "[ -s \"$WORK/ship.txt\" ]"
assert "decisions file classifies something as drop" "[ -s \"$WORK/drop.txt\" ]"

MISSING=""
while IFS= read -r p; do
  [ -n "$p" ] || continue
  grep -qxF "$p" "$BLOCK" || MISSING="$MISSING $p"
done < "$WORK/ship.txt"
assert "6a. every ship: pattern is in gitignore-block.txt (missing:$MISSING)" \
  "[ -z \"$MISSING\" ]"

LEAKED=""
while IFS= read -r p; do
  [ -n "$p" ] || continue
  if grep -qxF "$p" "$BLOCK"; then LEAKED="$LEAKED $p"; fi
done < "$WORK/drop.txt"
assert "6b. no drop: pattern leaked into gitignore-block.txt (leaked:$LEAKED)" \
  "[ -z \"$LEAKED\" ]"

# Every non-comment line of THIS repo's .gitignore must be classified. This is
# the anti-rot clause: a rule added upstream is a decision someone has to make.
grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$ROOT/.gitignore" \
  | sed -e 's/[[:space:]]*$//' | sort -u > "$WORK/repo.txt"
cat "$WORK/ship.txt" "$WORK/drop.txt" | sed -e 's/[[:space:]]*$//' | sort -u > "$WORK/classified.txt"
UNCLASSIFIED="$(comm -23 "$WORK/repo.txt" "$WORK/classified.txt" | tr '\n' ' ')"
assert "6c. every .gitignore rule is classified ship or drop (unclassified: $UNCLASSIFIED)" \
  "[ -z \"$(printf '%s' \"$UNCLASSIFIED\" | tr -d ' ')\" ]"

# 7. The hostile four. Named individually — this is the finding the whole
#    curation exists for, so it gets an assertion each rather than a loop
#    whose failure would not say which one leaked.
assert "7a. .vscode/ never ships (kori-beta TRACKS .vscode/settings.json)" \
  "! grep -qxF '.vscode/' \"$BLOCK\""
assert "7b. package-lock.json never ships (kori-beta tracks a 464 KB lock file)" \
  "! grep -qxF 'package-lock.json' \"$BLOCK\""
assert "7c. dist/ never ships (build-system opinion, and redundant)" \
  "! grep -qxF 'dist/' \"$BLOCK\""
assert "7d. build/ never ships (tracked SOURCE in some projects)" \
  "! grep -qxF 'build/' \"$BLOCK\""
assert "7e. node_modules/ never ships (the adopter's package manager's business)" \
  "! grep -qxF 'node_modules/' \"$BLOCK\""

# 8/9/10. Behaviour, in a throwaway git repo.
REPO="$WORK/repo"; mkdir -p "$REPO"
( cd "$REPO" && git init -q . && \
  printf 'node_modules/\ndist/\n# their comment\ntheir-thing/\n' > .gitignore && \
  git add .gitignore && \
  git -c user.email=t@t -c user.name=t commit -qm init ) >/dev/null 2>&1
cp "$REPO/.gitignore" "$WORK/gi.orig"

# 9. Dirty tree -> report and refuse. This is the kori trap.
printf 'docs/private/\n' >> "$REPO/.gitignore"
cp "$REPO/.gitignore" "$WORK/gi.dirty"
bash "$GITIGNORE_MERGE" --target "$REPO/.gitignore" --block "$BLOCK" --write \
  >/dev/null 2>"$WORK/dirty.err"
RC=$?
assert "9a. a dirty .gitignore REFUSES (exit 10)" "[ $RC -eq 10 ]"
assert "9b. the refusal REPORTS the porcelain status line" \
  "grep -q 'M .gitignore' \"$WORK/dirty.err\""
assert "9c. the refusal explains the uncommitted-intent risk" \
  "grep -qi 'uncommitted changes' \"$WORK/dirty.err\""
assert "9d. the dirty target is left exactly as it was" \
  "diff -q \"$WORK/gi.dirty\" \"$REPO/.gitignore\" >/dev/null"

# --allow-dirty overrides, loudly.
bash "$GITIGNORE_MERGE" --target "$REPO/.gitignore" --block "$BLOCK" \
  --allow-dirty >/dev/null 2>"$WORK/allow.err"
assert "9e. --allow-dirty proceeds and still warns" \
  "grep -qi 'allow-dirty' \"$WORK/allow.err\" && grep -q 'status: merged' \"$WORK/allow.err\""

( cd "$REPO" && git add .gitignore && \
  git -c user.email=t@t -c user.name=t commit -qm private ) >/dev/null 2>&1
cp "$REPO/.gitignore" "$WORK/gi.clean"

# Dry-run writes nothing.
bash "$GITIGNORE_MERGE" --target "$REPO/.gitignore" --block "$BLOCK" \
  > "$WORK/gi.dry" 2>/dev/null
assert "dry-run leaves the .gitignore untouched" \
  "diff -q \"$WORK/gi.clean\" \"$REPO/.gitignore\" >/dev/null"
assert "dry-run prints the would-be result on stdout" \
  "grep -q 'LogicLoom adopt' \"$WORK/gi.dry\""

bash "$GITIGNORE_MERGE" --target "$REPO/.gitignore" --block "$BLOCK" --write \
  >/dev/null 2>"$WORK/append.err"
assert "8a. append on a clean tree succeeds" "grep -q 'status: merged' \"$WORK/append.err\""

# 8. Append-only: every pre-existing line survives, in order, at the top.
head -n "$(wc -l < "$WORK/gi.clean" | tr -d ' ')" "$REPO/.gitignore" > "$WORK/gi.head"
assert "8b. every pre-existing line survives verbatim and in order" \
  "diff -q \"$WORK/gi.clean\" \"$WORK/gi.head\" >/dev/null"
assert "8c. the block is fenced by a begin marker" \
  "grep -q '>>> LogicLoom adopt' \"$REPO/.gitignore\""
assert "8d. the block is fenced by an end marker" \
  "grep -q '<<< LogicLoom adopt' \"$REPO/.gitignore\""
assert "8e. the hostile patterns are absent from the RESULT, not just the block" \
  "! grep -qxF '.vscode/' \"$REPO/.gitignore\" && ! grep -qxF 'package-lock.json' \"$REPO/.gitignore\""

cp "$REPO/.gitignore" "$WORK/gi.after1"

# 10. Idempotency.
bash "$GITIGNORE_MERGE" --target "$REPO/.gitignore" --block "$BLOCK" --write \
  --allow-dirty >/dev/null 2>"$WORK/gi.run2.err"
assert "10a. second run is a byte-for-byte no-op" \
  "diff -q \"$WORK/gi.after1\" \"$REPO/.gitignore\" >/dev/null"
assert "10b. second run reports status: nochange" \
  "grep -q 'status: nochange' \"$WORK/gi.run2.err\""

# 10c. Human edit inside the fence -> refuse.
$PY - "$REPO/.gitignore" <<'PYEOF'
import sys
p = sys.argv[1]; s = open(p).read()
open(p, "w").write(s.replace(".docs/research/", ".docs/research/  # mine", 1))
PYEOF
cp "$REPO/.gitignore" "$WORK/gi.edited"
bash "$GITIGNORE_MERGE" --target "$REPO/.gitignore" --block "$BLOCK" --write \
  --allow-dirty >/dev/null 2>"$WORK/gi.refuse.err"
RC=$?
assert "10c. an edit inside the fence REFUSES (exit 10)" "[ $RC -eq 10 ]"
assert "10d. the refusal shows the diff" "grep -q 'mine' \"$WORK/gi.refuse.err\""
assert "10e. the human edit is left in place" \
  "diff -q \"$WORK/gi.edited\" \"$REPO/.gitignore\" >/dev/null"

# A duplicated fence is ambiguous, not something to guess at.
cat "$WORK/gi.after1" "$WORK/gi.after1" > "$REPO/.gitignore"
bash "$GITIGNORE_MERGE" --target "$REPO/.gitignore" --block "$BLOCK" --write \
  --allow-dirty >/dev/null 2>"$WORK/gi.dup.err"
RC=$?
assert "a duplicated managed block REFUSES (exit 10)" "[ $RC -eq 10 ]"
assert "the duplicate refusal says the region is ambiguous" \
  "grep -qi 'ambiguous' \"$WORK/gi.dup.err\""

echo ""
echo "── Portability ──────────────────────────────────────────────────────────"
assert "merge-gitignore.sh parses under the bash 3.2 floor" \
  "/bin/bash -n \"$GITIGNORE_MERGE\""
# No jq: an adopter's machine is not guaranteed to have it. python3 is already a
# CI dependency of this repo (plugin-tests.yml sets up python and runs
# validate-plugin-manifests.py), so the JSON work goes there.
assert "the shell unit never invokes jq" \
  "! grep -qE '(^|[^[:alnum:]_])jq([[:space:]]|$)' \"$GITIGNORE_MERGE\""
assert "the python unit imports only the standard library" \
  "! grep -qE '^(import|from) ' \"$SETTINGS_MERGE\" | grep -qvE '^(import|from) (argparse|json|os|re|sys|__future__)'"

# Neither unit may run a git MUTATION. Checked by allowlist over every
# non-comment `git ` invocation, not by a denylist of verbs — a denylist misses
# the verb nobody thought of.
: > "$WORK/gitcalls"
for f in "$GITIGNORE_MERGE" "$SETTINGS_MERGE"; do
  # Strip comments and BACKTICKED PROSE first: the dirty-tree refusal message
  # names `git checkout` as the thing that would eat an uncommitted rule, and
  # that is documentation, not an invocation.
  sed -e 's/^[[:space:]]*//' -e 's/`[^`]*`//g' "$f" \
    | grep -v '^#' | grep -oE 'git [-A-Za-z0-9_"$ ]*' >> "$WORK/gitcalls" || true
done
BADGIT=""
while IFS= read -r call; do
  [ -n "$call" ] || continue
  case "$call" in
    *status*|*rev-parse*|*ls-files*|*" -C "*status*|*" -C "*rev-parse*) ;;
    *) BADGIT="$BADGIT [$call]" ;;
  esac
done < "$WORK/gitcalls"
assert "every git invocation is read-only (status/rev-parse/ls-files) — found:$BADGIT" \
  "[ -z \"$BADGIT\" ]"

echo ""
echo "========================================"
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
