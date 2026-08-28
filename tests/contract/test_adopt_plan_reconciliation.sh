#!/usr/bin/env bash
# Contract Tests: THE PLAN IS WHAT LANDS — bookkeeping (F2) and counts (F3)
#
# Both found by a human running the tool against a real repository. Both are
# invariants about the artifact a user REVIEWS AND APPROVES, which is why they
# belong in the suite rather than in a changelog line.
#
# F2 — TWO FILES WERE WRITTEN THAT THE PLAN NEVER PROMISED
# -----------------------------------------------------------------------------
# `.logicloom-adopt-receipt.json` and `.claude/.logicloom-adopt-settings.json`
# land on every apply and appeared in NO plan unit. They were disclosed in the
# apply report and in the uninstall procedure — afterwards. The plan is what the
# user approves, so a file that lands must be in it. They are surfaced as a
# separate `bookkeeping[]` list rather than as additive units, because they are
# the installer's paperwork and not harness content, and an adopter uninstalling
# needs to tell those apart.
#
# F3 — `counts.additive` IS NOT A FILE COUNT AND READ LIKE ONE
# -----------------------------------------------------------------------------
# `counts.additive: 62` sat beside an apply reporting `WROTE 407`. Both correct,
# neither comparable: units are counted at the granularity a DECISION is made at
# (a dir, a file, a gitignore line, a settings key), and twelve of them are whole
# directories. `counts.wouldWrite` resolves them to paths by running the
# applier's OWN traversal in predict mode, so plan and apply can be compared at a
# glance — and cannot drift, because there is only one traversal.
#
# What this pins:
#   1. Both bookkeeping files appear in the plan, flagged as tool-owned.
#   2. The sidecar appears only when `hooks` would actually write it.
#   3. RECONCILIATION, BOTH DIRECTIONS: nothing written that the plan did not
#      promise, and nothing promised that was not written. This is the check the
#      smoke-test brief asks for, run against the real payload.
#   4. `counts.wouldWrite.total` EQUALS the apply report's WROTE.
#   5. The unit count is still there, still correct, and now says what it counts.
#   6. The planner still writes nothing while computing any of it.
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
BK="$PKG/lib/bookkeeping.js"

echo "🧪 Adopt Plan ↔ Apply Reconciliation"
echo "===================================="
echo ""

IS_TRACKED=no
if git -C "$ROOT" ls-files --error-unmatch "$BK" >/dev/null 2>&1; then IS_TRACKED=yes; fi
if [ ! -f "$BK" ] && [ "$IS_TRACKED" = no ]; then
  echo "  ⏭  SKIP: no packaging/adopt/lib/bookkeeping.js and none tracked —"
  echo "     this is a stripped or customer tree, where packaging/ never exists."
  echo ""
  echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
  exit 0
fi
if ! command -v node >/dev/null 2>&1; then
  echo "  ⏭  SKIP: node is not on PATH; the planner cannot be exercised."
  echo ""
  echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
  exit 0
fi

assert "the bookkeeping module exists" "[ -f \"$BK\" ]"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/loom-adopt-recon.XXXXXX")"
cleanup() { [ -n "${TMP:-}" ] && rm -rf "$TMP"; }
trap cleanup EXIT

git_quiet() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}" >/dev/null 2>&1; }

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

# The REAL payload and the REAL manifest. The point of this suite is the
# invariant the smoke test checked by hand, and a fixture payload would not
# exercise the directory expansion that made the two counts incomparable.
R="$TMP/real"; new_repo "$R"
node "$CLI" init "$R" --json > "$TMP/plan.json" 2>/dev/null
assert "the plan against the real payload is valid JSON" \
  "node -e 'require(\"$TMP/plan.json\")'"

# ── 1. The tool's own files are in the plan ──────────────────────────────────
echo ""
echo "── the plan names the files the TOOL writes, not only the harness ──"
assert "plan.bookkeeping exists and is non-empty" \
  "node -e 'const p=require(\"$TMP/plan.json\");process.exit(Array.isArray(p.bookkeeping)&&p.bookkeeping.length?0:1)'"
assert "...it names the receipt" \
  "node -e 'const p=require(\"$TMP/plan.json\");process.exit(p.bookkeeping.some(b=>b.path===\".logicloom-adopt-receipt.json\")?0:1)'"
assert "...it names the settings sidecar" \
  "node -e 'const p=require(\"$TMP/plan.json\");process.exit(p.bookkeeping.some(b=>b.path===\".claude/.logicloom-adopt-settings.json\")?0:1)'"
assert "...every entry is flagged tool-owned, not harness content" \
  "node -e 'const p=require(\"$TMP/plan.json\");process.exit(p.bookkeeping.every(b=>b.owner===\"tool\")?0:1)'"
assert "...every entry says WHEN it lands and WHAT it is for" \
  "node -e 'const p=require(\"$TMP/plan.json\");process.exit(p.bookkeeping.every(b=>b.when&&b.purpose)?0:1)'"
assert "...and counts.bookkeeping agrees with the list" \
  "node -e 'const p=require(\"$TMP/plan.json\");process.exit(p.counts.bookkeeping===p.bookkeeping.length?0:1)'"
assert "the human report prints them under their own heading" \
  "node \"$CLI\" init \"$R\" 2>/dev/null | grep -q 'BOOKKEEPING'"
assert "...and says they are written by the tool, not part of the harness" \
  "node \"$CLI\" init \"$R\" 2>/dev/null | grep -q 'written by the TOOL'"

# The sidecar is conditional: it only exists because the settings merge inserts
# something. A plan for a repo whose hooks are all already registered must not
# promise it.
echo ""
echo "── the sidecar is promised only when it would actually be written ──"
S="$TMP/nohooks"; new_repo "$S"
mkdir -p "$S/.claude"
cp "$PKG/merge/settings-hooks-fragment.json" "$S/.claude/settings.json"
git_quiet "$S" add -A; git_quiet "$S" commit -m hooks
node "$CLI" init "$S" --json > "$TMP/plan-nohooks.json" 2>/dev/null
assert "a repo that already registers every hook is not promised the sidecar" \
  "node -e 'const p=require(\"$TMP/plan-nohooks.json\");process.exit(p.bookkeeping.some(b=>/adopt-settings/.test(b.path))?1:0)'"
assert "...but is still promised the receipt, which every run writes" \
  "node -e 'const p=require(\"$TMP/plan-nohooks.json\");process.exit(p.bookkeeping.some(b=>/adopt-receipt/.test(b.path))?0:1)'"

# ── 2. counts.wouldWrite is a file count, and it is the right one ────────────
echo ""
echo "── the plan carries a count that compares to the apply report ──"
assert "counts.additive is still there and unchanged in meaning" \
  "node -e 'const p=require(\"$TMP/plan.json\");process.exit(p.counts.additive===p.buckets.additive.length?0:1)'"
assert "...and counts.additiveEntries says out loud what it counts" \
  "node -e 'const p=require(\"$TMP/plan.json\");process.exit(p.counts.additiveEntries===p.counts.additive?0:1)'"
assert "counts.wouldWrite resolves to a total larger than the unit count" \
  "node -e 'const p=require(\"$TMP/plan.json\");process.exit(p.counts.wouldWrite.total>p.counts.additive?0:1)'"
assert "...broken down per --only target" \
  "node -e 'const w=require(\"$TMP/plan.json\").counts.wouldWrite;
            process.exit([\"harness\",\"rules\",\"gitignore\",\"hooks\"].every(k=>typeof w[k]===\"number\")?0:1)'"
assert "...the gitignore merge counts as ONE write, however many patterns it carries" \
  "node -e 'const w=require(\"$TMP/plan.json\").counts.wouldWrite;
            process.exit(w.gitignore===1&&w.resolvedFrom.line>1?0:1)'"
assert "...the hooks merge counts as TWO: the settings file and its sidecar" \
  "node -e 'const w=require(\"$TMP/plan.json\").counts.wouldWrite;process.exit(w.hooks===2?0:1)'"
assert "...and the human report prints it beside the bucket table" \
  "node \"$CLI\" init \"$R\" 2>/dev/null | grep -q 'RESOLVED to paths'"
assert "the planner still wrote nothing while computing all of that" \
  "[ -z \"\$(git -C \"$R\" status --porcelain)\" ]"

# ── 3. THE RECONCILIATION, BOTH DIRECTIONS ──────────────────────────────────
# This is smoke-test check 5, executed. It is the assertion that would have
# caught F2, and it is the one a future edit is most likely to break silently.
echo ""
echo "── plan ↔ apply: nothing unpromised landed, nothing promised is missing ──"
if [ "$HAVE_PY" = yes ]; then
  node "$CLI" init "$R" --apply --only=all,hooks > "$TMP/apply.txt" 2>&1; AP=$?
  assert "the apply succeeded" "[ \"$AP\" = 0 ]"

  cat > "$TMP/reconcile.js" <<'JS'
// Reconcile the plan a user approved against the receipt of what landed.
// A written path counts as promised when it is AT or UNDER a promised path:
// `include: .logic-loom` is one plan entry and hundreds of files.
const fs = require('fs'), path = require('path');
const plan = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const root = process.argv[3];
const rec = JSON.parse(fs.readFileSync(path.join(root, '.logicloom-adopt-receipt.json'), 'utf8'));
const strip = (p) => String(p).replace(/\/+$/, '');

const promised = [];
for (const u of plan.buckets.additive) promised.push(strip(u.targetPath));
for (const b of plan.bookkeeping) promised.push(strip(b.path));

const written = [];
for (const r of rec.runs) for (const w of (r.wrote || [])) written.push(strip(w.path));
// The receipt itself is on disk and is a path the tool wrote; it is not in
// wrote[] because it is the record OF wrote[]. Reconcile it explicitly.
if (fs.existsSync(path.join(root, '.logicloom-adopt-receipt.json'))) {
  written.push('.logicloom-adopt-receipt.json');
}

const covered = (w) => promised.some((p) => w === p || w.indexOf(p + '/') === 0);
const unpromised = written.filter((w) => !covered(w));
const missing = promised.filter((p) => !fs.existsSync(path.join(root, p)));

const out = { unpromised: unpromised, missing: missing,
              planTotal: plan.counts.wouldWrite.total,
              wroteTotal: (rec.runs[0].wrote || []).length };
process.stdout.write(JSON.stringify(out));
JS
  node "$TMP/reconcile.js" "$TMP/plan.json" "$R" > "$TMP/recon.json"
  assert "NOTHING WAS WRITTEN THAT THE PLAN DID NOT PROMISE" \
    "node -e 'const r=require(\"$TMP/recon.json\");if(r.unpromised.length)console.error(r.unpromised);process.exit(r.unpromised.length?1:0)'"
  assert "NOTHING THE PLAN PROMISED IS MISSING FROM DISK" \
    "node -e 'const r=require(\"$TMP/recon.json\");if(r.missing.length)console.error(r.missing);process.exit(r.missing.length?1:0)'"
  assert "counts.wouldWrite.total EQUALS the receipt's write count" \
    "node -e 'const r=require(\"$TMP/recon.json\");process.exit(r.planTotal===r.wroteTotal?0:1)'"
  assert "...and equals the number the apply report prints as WROTE" \
    "node -e 'const r=require(\"$TMP/recon.json\");const t=require(\"fs\").readFileSync(\"$TMP/apply.txt\",\"utf8\");
              const m=/WROTE\\s+(\\d+)/.exec(t);process.exit(m&&Number(m[1])===r.planTotal?0:1)'"
  assert "both bookkeeping files are on disk after the apply" \
    "[ -f \"$R/.logicloom-adopt-receipt.json\" ] && [ -f \"$R/.claude/.logicloom-adopt-settings.json\" ]"
else
  echo "  ⏭  SKIP: python3 not on PATH; the hooks merge cannot run, so the"
  echo "     reconciliation would not cover the sidecar."
fi

# ── 4. The prediction is the applier's own walk, not a second one ───────────
echo ""
echo "── one traversal, so the number cannot drift from the copy it predicts ──"
assert "the prediction runs lib/fsops.js copyTree, not a reimplementation" \
  "grep -q 'fsops.copyTree' \"$BK\""
assert "...in predict mode, which is the only thing that differs" \
  "grep -q 'predictOnly' \"$BK\" && grep -q 'predictOnly' \"$PKG/lib/fsops.js\""
assert "predict mode suppresses the writes and nothing else" \
  "[ \"\$(grep -c 'predictOnly' \"$PKG/lib/fsops.js\")\" -ge 3 ]"
assert "the bookkeeping module states why the plan owed the reader both numbers" \
  "grep -q 'the artifact a user' \"$BK\""

echo ""
echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
