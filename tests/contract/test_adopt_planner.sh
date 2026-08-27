#!/usr/bin/env bash
# Contract Tests: the `logicloom init` planner — detect, classify, plan
#
# packaging/adopt/ is the read-only half of the adopt CLI: it detects what a
# target repository already has, classifies the payload against it into four
# buckets, and prints a plan. It has NO WRITE PATH. This suite pins the
# properties that make that safe to run against a repository nobody owns.
#
# What it pins:
#   1. THE CLASSIFIER'S DECISIONS — the substance. Real fixture repos are built
#      and the four buckets are asserted by rule id, not by count alone.
#   2. `replace` is EMPTY. Not "small" — empty. REPLACE_ALLOWLIST is a claim
#      that our copy beats theirs, which a classifier cannot compute, so it must
#      stay a hand-written list and it must stay empty until someone argues a
#      row onto it.
#   3. keep-theirs is the DEFAULT for every collision, INCLUDING the unknown
#      case (their settings.json does not parse). Failing toward theirs is the
#      fail-safe direction.
#   4. `obsolete` is report-only and root-anchored, so it does not fill with
#      documentation path fragments.
#   5. NO REMEDY EVER SAYS `git stash`. A stash is a git mutation that succeeds
#      silently and puts the work one `git stash drop` from gone.
#   6. THE PLANNER WRITES NOTHING. Asserted by fingerprinting a fixture repo
#      before and after a run.
#   7. MODE DETECTION — new-project vs existing-project, and the erring-toward-
#      existing rule (a lone README.md is an existing project, not an empty one).
#   8. The CLI shape: bare invocation exits non-zero without doing anything;
#      unknown subcommand likewise; `adopt` is a working hidden alias.
#
# bash 3.2 safe: no associative arrays, no mapfile, no [[ -v ]], no ${var,,}.
# NOTE: packaging/ is NOT in tests/contract/test_bash32_floor.sh's scan scope
# (its roots are .logic-loom, .claude/hooks, tests, and declared plugins), but
# THIS FILE is under tests/ and therefore IS scanned. It is written to the floor.
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

echo "🧪 Adopt Planner Contract Tests"
echo "==============================="
echo ""

# ── Vacuously green on a stripped tree, FAIL-CLOSED on rot ───────────────────
# `packaging` is a template-strip-manifest entry, so this package does not exist
# in any shipped tree — and plugin-tests.yml runs this suite as a CI step, which
# tests/contract/test_shipped_gates_vs_strip.sh executes against a freshly
# stripped tree and requires to exit 0. Same shape and same reason as
# test_adopt_payload_manifest.sh beside it: a live gate, not a dead one.
#
# The teeth are kept by the TRACKED file. Absent-and-untracked (a stripped tree)
# is a legitimate skip; absent-but-TRACKED means it was deleted out from under
# the boundary, and that still fails.
IS_TRACKED=no
if git -C "$ROOT" ls-files --error-unmatch "$CLI" >/dev/null 2>&1; then IS_TRACKED=yes; fi

if [ ! -f "$CLI" ] && [ "$IS_TRACKED" = no ]; then
  echo "  ⏭  SKIP: no packaging/adopt/bin/logicloom.js and none tracked —"
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

assert "the CLI entry exists" "[ -f \"$CLI\" ]"
assert "the package manifest exists" "[ -f \"$PKG/package.json\" ]"
assert "the plan-format contract exists" "[ -f \"$PKG/PLAN-FORMAT.md\" ]"

# ── Node floor ───────────────────────────────────────────────────────────────
# Declared >=22.14.0 because npm trusted publishing requires it (PRE-12). The
# local runner may be older; that is recorded, not enforced, since this suite
# exercises the planner rather than the publish path.
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
assert "package.json declares the Node >=22.14.0 floor (PRE-12)" \
  "grep -q '\">=22.14.0\"' \"$PKG/package.json\""
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo "  ℹ️  NOTE: local node is v$(node -v | tr -d 'v') — below the declared 22.14.0 floor."
  echo "     The planner is pure CommonJS and runs here, but engines-gated install"
  echo "     behaviour and the trusted-publish path are NOT exercised locally."
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/loom-adopt-planner.XXXXXX")"
cleanup() { [ -n "${TMP:-}" ] && rm -rf "$TMP"; }
trap cleanup EXIT

git_quiet() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}" >/dev/null 2>&1; }

# ── CLI shape ────────────────────────────────────────────────────────────────
echo ""
echo "── CLI shape ──"

node "$CLI" >"$TMP/bare.out" 2>"$TMP/bare.err"; BARE_RC=$?
assert "a bare invocation exits non-zero (never defaults to doing something)" "[ $BARE_RC -eq 2 ]"
assert "a bare invocation says nothing was done" "grep -q 'Nothing was done' \"$TMP/bare.err\""

node "$CLI" frobnicate >/dev/null 2>"$TMP/unk.err"; UNK_RC=$?
assert "an unknown subcommand exits non-zero" "[ $UNK_RC -eq 2 ]"
assert "an unknown subcommand says nothing was done" "grep -q 'Nothing was done' \"$TMP/unk.err\""

node "$CLI" --help >"$TMP/help.out" 2>&1
assert "usage advertises the \`init\` subcommand" "grep -q 'init ' \"$TMP/help.out\""
assert "usage states init is currently the only subcommand" \
  "grep -q 'ONLY subcommand' \"$TMP/help.out\""
assert "usage does NOT advertise the hidden \`adopt\` alias" \
  "! grep -q 'adopt' \"$TMP/help.out\""

# ── Fixture A: a NEW project (empty dir, no git) ─────────────────────────────
echo ""
echo "── mode detection ──"

mkdir -p "$TMP/new-bare"
node "$CLI" init "$TMP/new-bare" --json >"$TMP/new-bare.json" 2>/dev/null
assert "an empty directory is detected as new-project" \
  "node -e 'p=require(\"$TMP/new-bare.json\");process.exit(p.mode.mode===\"new-project\"?0:1)'"
assert "the new-project verdict carries a stated reason" \
  "node -e 'p=require(\"$TMP/new-bare.json\");process.exit(p.mode.reason.length>20?0:1)'"
assert "a new project has NOTHING in keep-theirs / replace / obsolete" \
  "node -e 'p=require(\"$TMP/new-bare.json\");c=p.counts;process.exit((c[\"keep-theirs\"]===0&&c.replace===0&&c.obsolete===0)?0:1)'"
assert "a new project has every unit in additive" \
  "node -e 'p=require(\"$TMP/new-bare.json\");process.exit((p.counts.additive===p.counts.total&&p.counts.total>0)?0:1)'"

mkdir -p "$TMP/new-git" && git_quiet "$TMP/new-git" init
node "$CLI" init "$TMP/new-git" --json >"$TMP/new-git.json" 2>/dev/null
assert "a directory holding only .git is still new-project" \
  "node -e 'p=require(\"$TMP/new-git.json\");process.exit(p.mode.mode===\"new-project\"?0:1)'"
assert "NO-COMMITS is a WARNING in new-project, not blocking (nothing to lose)" \
  "node -e 'p=require(\"$TMP/new-git.json\");b=p.preconditions.blocking.filter(x=>x.code===\"NO-COMMITS\");w=p.preconditions.warnings.filter(x=>x.code===\"NO-COMMITS\");process.exit((b.length===0&&w.length===1)?0:1)'"

# THE ERRING-TOWARD-EXISTING RULE. A lone README.md is NOT an empty directory.
mkdir -p "$TMP/lone-readme" && printf '# hi\n' > "$TMP/lone-readme/README.md"
node "$CLI" init "$TMP/lone-readme" --json >"$TMP/lone.json" 2>/dev/null
assert "a directory with only a README.md is EXISTING, not new (errs toward safe)" \
  "node -e 'p=require(\"$TMP/lone.json\");process.exit(p.mode.mode===\"existing-project\"?0:1)'"

mkdir -p "$TMP/lone-ds" && printf '' > "$TMP/lone-ds/.DS_Store"
node "$CLI" init "$TMP/lone-ds" --json >"$TMP/ds.json" 2>/dev/null
assert ".DS_Store alone does NOT make a directory an existing project" \
  "node -e 'p=require(\"$TMP/ds.json\");process.exit(p.mode.mode===\"new-project\"?0:1)'"

# ── Fixture B: an EXISTING project with real collisions ──────────────────────
echo ""
echo "── classifier decisions ──"

EX="$TMP/existing"
mkdir -p "$EX/.docs/policies" "$EX/.docs/architecture" "$EX/specs" "$EX/src"
git_quiet "$EX" init
printf 'node_modules/\n' > "$EX/.gitignore"
printf '# Proj\n\nSee `src/gone.md` and `nowhere/gone.md`.\n' > "$EX/CLAUDE.md"
printf 'policy\n' > "$EX/.docs/policies/keep.md"
printf 'arch\n'   > "$EX/.docs/architecture/keep.md"
printf 'theirs\n' > "$EX/specs/README.md"
printf 'x\n'      > "$EX/src/app.js"
git_quiet "$EX" add -A
git_quiet "$EX" commit -m baseline

node "$CLI" init "$EX" --json >"$TMP/ex.json" 2>/dev/null
assert "an existing project is detected as existing-project" \
  "node -e 'p=require(\"$TMP/ex.json\");process.exit(p.mode.mode===\"existing-project\"?0:1)'"

# R3 — a colliding directory goes to keep-theirs, never additive.
assert "R3: .docs/policies collides and is classified keep-theirs" \
  "node -e 'p=require(\"$TMP/ex.json\");u=p.buckets[\"keep-theirs\"].filter(x=>x.targetPath===\".docs/policies\");process.exit((u.length===1&&u[0].rule===\"R3\")?0:1)'"
assert "R3: a colliding file (specs/README.md) is keep-theirs, action=skip" \
  "node -e 'p=require(\"$TMP/ex.json\");u=p.buckets[\"keep-theirs\"].filter(x=>x.targetPath===\"specs/README.md\");process.exit((u.length===1&&u[0].action===\"skip\")?0:1)'"
assert "every keep-theirs unit carries action=skip (an applier must not write one)" \
  "node -e 'p=require(\"$TMP/ex.json\");process.exit(p.buckets[\"keep-theirs\"].every(u=>u.action===\"skip\")?0:1)'"
assert "every keep-theirs unit carries a non-empty reason (the drop is never silent)" \
  "node -e 'p=require(\"$TMP/ex.json\");process.exit(p.buckets[\"keep-theirs\"].every(u=>u.reason&&u.reason.length>10)?0:1)'"

# R2 — a non-colliding path goes to additive.
assert "R2: .logic-loom has no counterpart and is additive" \
  "node -e 'p=require(\"$TMP/ex.json\");u=p.buckets.additive.filter(x=>x.targetPath===\".logic-loom\");process.exit((u.length===1&&u[0].rule===\"R2\")?0:1)'"

# Granularity — this is what makes four buckets sufficient.
assert "granularity: .claude/settings.json is classified per json-key, not per file" \
  "node -e 'p=require(\"$TMP/ex.json\");a=[].concat(p.buckets.additive,p.buckets[\"keep-theirs\"]);u=a.filter(x=>x.granularity===\"json-key\");process.exit(u.length>=8?0:1)'"
assert "granularity: .gitignore is classified per line, not per file" \
  "node -e 'p=require(\"$TMP/ex.json\");a=[].concat(p.buckets.additive,p.buckets[\"keep-theirs\"]);u=a.filter(x=>x.granularity===\"line\");process.exit(u.length>=10?0:1)'"
assert "every json-key unit matches on (event,matcher,command), never an array index" \
  "node -e 'p=require(\"$TMP/ex.json\");a=[].concat(p.buckets.additive,p.buckets[\"keep-theirs\"]);u=a.filter(x=>x.granularity===\"json-key\");process.exit(u.every(x=>x.selector&&x.selector.event&&typeof x.selector.matcher===\"string\"&&x.selector.command)?0:1)'"

# REPLACE — empty, everywhere, always.
assert "replace is EMPTY for the existing-project fixture" \
  "node -e 'p=require(\"$TMP/ex.json\");process.exit(p.counts.replace===0?0:1)'"
assert "REPLACE_ALLOWLIST in lib/classify.js holds no active entries" \
  "node -e 'c=require(\"$PKG/lib/classify.js\");process.exit(c.REPLACE_ALLOWLIST.length===0?0:1)'"
assert "no collision can reach \`replace\` without an explicit allowlist row" \
  "node -e 'c=require(\"$PKG/lib/classify.js\");process.exit(c.replaceEntryFor(\".docs/policies\")===null?0:1)'"

# OBSOLETE — report-only, root-anchored.
assert "obsolete finds the root-anchored broken citation (src/gone.md)" \
  "node -e 'p=require(\"$TMP/ex.json\");process.exit(p.buckets.obsolete.some(o=>o.reference===\"src/gone.md\")?0:1)'"
assert "obsolete IGNORES an unanchored path fragment (nowhere/gone.md)" \
  "node -e 'p=require(\"$TMP/ex.json\");process.exit(p.buckets.obsolete.some(o=>o.reference===\"nowhere/gone.md\")?1:0)'"
assert "every obsolete finding is action=report-only" \
  "node -e 'p=require(\"$TMP/ex.json\");process.exit(p.buckets.obsolete.every(o=>o.action===\"report-only\")?0:1)'"

# ── keep-theirs is the fail-safe direction when the answer is UNKNOWN ────────
echo ""
echo "── fail-safe direction ──"
# Their settings.json does not parse. The classifier must NOT conclude "absent"
# and install over it. Exercised through the library rather than a fixture file,
# because .claude/settings.json is on the governance protected-path list.
assert "unknown counterpart (their settings.json is invalid JSON) => keep-theirs, not additive" \
  "node -e '
    var c=require(\"$PKG/lib/classify.js\");
    var unit={id:\"u\",granularity:\"json-key\",kind:\"json-key\",sourcePath:\".claude/settings.json\",targetPath:\".claude/settings.json\",action:\"merge-json-key\",payloadPresent:true,selector:{event:\"PreToolUse\",matcher:\"Bash\",command:\"bash x.sh\"}};
    var ctx={root:\"/nonexistent\",payloadRoot:\"/nonexistent\",surfaces:{claude:{settings:{kind:\"file\",parse:\"invalid\",reason:\"boom\"}},gitignore:{kind:\"absent\"}}};
    var r=c.classifyUnit(unit,ctx);
    process.exit((r.bucket===\"keep-theirs\"&&r.rule===\"R3\")?0:1);'"
assert "same command under a DIFFERENT matcher counts as present, not absent" \
  "node -e '
    var c=require(\"$PKG/lib/classify.js\");
    var unit={selector:{event:\"PreToolUse\",matcher:\"Bash\",command:\"bash x.sh\"}};
    var st={kind:\"file\",parse:\"ok\",value:{hooks:{PreToolUse:[{matcher:\"Write\",hooks:[{type:\"command\",command:\"bash x.sh\"}]}]}}};
    var r=c.settingsCounterpart(st,unit);
    process.exit((r.exists===true&&r.identical===false)?0:1);'"
assert "R4: an identical hook command under the same matcher is keep-theirs (already installed)" \
  "node -e '
    var c=require(\"$PKG/lib/classify.js\");
    var unit={selector:{event:\"PreToolUse\",matcher:\"Bash\",command:\"bash x.sh\"}};
    var st={kind:\"file\",parse:\"ok\",value:{hooks:{PreToolUse:[{matcher:\"Bash\",hooks:[{type:\"command\",command:\"bash x.sh\"}]}]}}};
    var r=c.settingsCounterpart(st,unit);
    process.exit((r.exists===true&&r.identical===true)?0:1);'"

# ── already-adopted: this repo must never propose reinstalling itself ────────
echo ""
echo "── already adopted ──"
node "$CLI" init "$ROOT" --json >"$TMP/self.json" 2>/dev/null; SELF_RC=$?
assert "planning against LogicLoom itself reports adoption state 'adopted'" \
  "node -e 'p=require(\"$TMP/self.json\");process.exit(p.target.adoption.state===\"adopted\"?0:1)'"
assert "already-adopted is BLOCKING (never proposes a reinstall)" \
  "node -e 'p=require(\"$TMP/self.json\");process.exit(p.preconditions.blocking.some(b=>b.code===\"ALREADY-ADOPTED\")?0:1)'"
assert "already-adopted makes applyReady false" \
  "node -e 'p=require(\"$TMP/self.json\");process.exit(p.applyReady===false?0:1)'"
assert "a blocked plan exits 1, not 0" "[ $SELF_RC -eq 1 ]"
assert "the already-adopted remedy points at /update-framework, not a reinstall" \
  "node -e 'p=require(\"$TMP/self.json\");b=p.preconditions.blocking.filter(x=>x.code===\"ALREADY-ADOPTED\")[0];process.exit(/update-framework/.test(b.remedy)?0:1)'"

# ── preconditions: dirty and untracked, and NEVER a stash ────────────────────
echo ""
echo "── preconditions ──"

DIRTY="$TMP/dirty"
mkdir -p "$DIRTY/.docs/policies"
git_quiet "$DIRTY" init
printf 'node_modules/\n' > "$DIRTY/.gitignore"
printf 'p\n' > "$DIRTY/.docs/policies/keep.md"
git_quiet "$DIRTY" add -A
git_quiet "$DIRTY" commit -m baseline
printf 'coverage/\n' >> "$DIRTY/.gitignore"          # dirty MERGE target
mkdir -p "$DIRTY/features/wip" && printf 'work\n' > "$DIRTY/features/wip/notes.md"   # untracked under a target

node "$CLI" init "$DIRTY" --json >"$TMP/dirty.json" 2>/dev/null; DIRTY_RC=$?
assert "a dirty merge target (.gitignore) is reported BLOCKING by name" \
  "node -e 'p=require(\"$TMP/dirty.json\");process.exit(p.preconditions.blocking.some(b=>b.code===\"DIRTY-MERGE-TARGET\"&&b.path===\".gitignore\")?0:1)'"
assert "untracked work under a target path is reported BLOCKING by name" \
  "node -e 'p=require(\"$TMP/dirty.json\");process.exit(p.preconditions.blocking.some(b=>b.code===\"UNTRACKED-UNDER-TARGET\"&&/features/.test(b.path))?0:1)'"
assert "a blocked plan still produced full buckets (the plan always runs)" \
  "node -e 'p=require(\"$TMP/dirty.json\");process.exit(p.counts.total>0?0:1)'"
assert "a blocked plan exits 1" "[ $DIRTY_RC -eq 1 ]"

# git collapses untracked directories to `?? features/`; the blocking item must
# name a path that EXISTS, or the printed cp -a remedy fails when run.
assert "each blocking remedy names an existing path (grouped by the real dirty entry)" \
  "node -e '
    var fs=require(\"fs\"),path=require(\"path\");
    var p=require(\"$TMP/dirty.json\");
    var bad=p.preconditions.blocking.filter(function(b){
      var m=/cp -a \"([^\"]+)\"/.exec(b.remedy||\"\"); if(!m) return false;
      return !fs.existsSync(m[1]);
    });
    if(bad.length) console.error(JSON.stringify(bad,null,2));
    process.exit(bad.length===0?0:1);'"

# THE STASH RULE — across every fixture planned in this suite.
STASH_HITS=0
for f in "$TMP"/*.json; do
  if node -e '
      var p=require(process.argv[1]);
      var all=[].concat(p.preconditions.blocking,p.preconditions.warnings);
      var hit=all.some(function(i){return /stash/i.test((i.remedy||"")+" "+(i.detail||""));});
      process.exit(hit?0:1);' "$f" 2>/dev/null; then
    STASH_HITS=$((STASH_HITS + 1)); echo "     stash mentioned in: $f"
  fi
done
assert "NO precondition remedy or detail ever proposes \`git stash\` (checked across all fixtures)" \
  "[ $STASH_HITS -eq 0 ]"
assert "the source of preconditions.js contains the no-stash rationale, not just the behaviour" \
  "grep -q 'NEVER PROPOSE' \"$PKG/lib/preconditions.js\""

# ── the planner writes NOTHING ───────────────────────────────────────────────
echo ""
echo "── read-only guarantee ──"

fingerprint() { find "$1" -print0 2>/dev/null | LC_ALL=C sort -z | xargs -0 ls -ldT 2>/dev/null | cksum; }
BEFORE="$(fingerprint "$EX")"
node "$CLI" init "$EX" >/dev/null 2>&1
node "$CLI" init "$EX" --json >/dev/null 2>&1
AFTER="$(fingerprint "$EX")"
assert "two full planner runs changed NOTHING in the target repo" "[ \"$BEFORE\" = \"$AFTER\" ]"

EX_STATUS="$(git -C "$EX" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
assert "the target repo is still clean after planning (git agrees)" "[ \"$EX_STATUS\" = 0 ]"

# ── the read-only git allowlist ──────────────────────────────────────────────
echo ""
echo "── git allowlist ──"
assert "git-ro refuses a mutating verb (commit)" \
  "node -e 'var g=require(\"$PKG/lib/git-ro.js\");try{g.run(\"$EX\",[\"commit\",\"-m\",\"x\"]);process.exit(1)}catch(e){process.exit(/non-allowlisted/.test(e.message)?0:1)}'"
assert "git-ro refuses a code-executing global flag (-c)" \
  "node -e 'var g=require(\"$PKG/lib/git-ro.js\");try{g.run(\"$EX\",[\"status\",\"-c\",\"core.pager=sh\"]);process.exit(1)}catch(e){process.exit(/code-executing/.test(e.message)?0:1)}'"
assert "git-ro's allowlist is a subset of the subagent read-only guard's verbs" \
  "node -e '
    var g=require(\"$PKG/lib/git-ro.js\");
    var ok=[\"status\",\"log\",\"diff\",\"show\",\"branch\",\"tag\",\"stash\",\"rev-parse\",\"config\",\"worktree\",\"ls-files\",\"ls-tree\",\"cat-file\",\"describe\",\"blame\",\"shortlog\",\"remote\"];
    process.exit(g.ALLOWED_VERBS.every(function(v){return ok.indexOf(v)!==-1;})?0:1);'"

# ── plan format ──────────────────────────────────────────────────────────────
echo ""
echo "── plan format ──"
assert "the plan declares its schema" \
  "node -e 'p=require(\"$TMP/ex.json\");process.exit(/^logicloom\\/adopt-plan@/.test(p.schema)?0:1)'"
assert "PLAN-FORMAT.md documents the schema the planner actually emits" \
  "node -e 'var fs=require(\"fs\");var p=require(\"$TMP/ex.json\");var d=fs.readFileSync(\"$PKG/PLAN-FORMAT.md\",\"utf8\");process.exit(d.indexOf(p.schema)!==-1?0:1)'"
assert "applyReady is exactly (no blocking AND no errors)" \
  "node -e 'p=require(\"$TMP/ex.json\");process.exit(p.applyReady===(p.preconditions.blocking.length===0&&p.errors.length===0)?0:1)'"
assert "the four buckets are all present in the emitted plan" \
  "node -e 'p=require(\"$TMP/ex.json\");b=p.buckets;process.exit((b.additive&&b[\"keep-theirs\"]&&b.replace&&b.obsolete)?0:1)'"
assert "an open manifest defer: row blocks the apply (the manifest's own rule)" \
  "node -e 'p=require(\"$TMP/ex.json\");process.exit((p.defers.length===0)||p.preconditions.blocking.some(b=>b.code===\"MANIFEST-DEFER-OPEN\")?0:1)'"
assert "the named limits about tests/ and .github/ are in the plan output" \
  "node -e 'p=require(\"$TMP/ex.json\");var s=p.notes.join(\" \");process.exit((/tests\\//.test(s)&&/\\.github/.test(s))?0:1)'"

echo ""
echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
