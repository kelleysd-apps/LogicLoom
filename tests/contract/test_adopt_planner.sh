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
# NOTE: packaging/adopt/ IS in tests/contract/test_bash32_floor.sh's scan scope
# (wholesale, alongside .logic-loom, .claude/hooks and tests) — its merge
# scripts run on the ADOPTER'S bash, which is stock macOS 3.2 just as often as
# ours is. THIS FILE is under tests/ and is therefore ALSO scanned in its own
# right. Both are written to the floor.
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
# >=22.14.0 was a PUBLISH-time constraint (npm trusted publishing, PRE-12) that
# had been copied into the package's RUNTIME `engines` field, warning or
# blocking every adopter below 22.14 for a requirement the CLI itself does not
# have: it uses only node:{child_process,crypto,fs,os,path} core builtins and
# two `??` operators. The runtime floor is now the one this repo actually
# PROVES: every adopt contract suite (this one included) runs under
# node-version: '20' in .github/workflows/plugin-tests.yml, so >=20.0.0 is
# evidence-backed rather than merely plausible — 18 is EOL and untested here.
# 22.14.0 stays where it belongs, in publish-adopt.yml's trusted-publish step.
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
assert "package.json declares the evidence-backed runtime Node floor (>=20.0.0), not the publish-time one" \
  "grep -q '\">=20.0.0\"' \"$PKG/package.json\""
assert "package.json no longer asserts the publish-only >=22.14.0 floor as a runtime requirement" \
  "! grep -q '\">=22.14.0\"' \"$PKG/package.json\""
if [ "$NODE_MAJOR" -lt 20 ]; then
  echo "  ℹ️  NOTE: local node is v$(node -v | tr -d 'v') — below the declared 20.0.0 floor."
  echo "     The planner is pure CommonJS and may still run here, but this is not the"
  echo "     supported floor."
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

# ── execution environment ─────────────────────────────────────────────────────
# The ADOPTER'S machine, not their repo: what would actually run an apply.
# python3/bash/git/node are probed and the plan records what was FOUND
# (resolved path + version), never a bare boolean — and every item here is a
# WARNING, never blocking, because `--only` (which target the adopter even
# wants) is not known until apply time (bin/logicloom.js parses it strictly
# after this plan already exists).
echo ""
echo "── execution environment ──"

assert "the plan carries an ENVIRONMENT section naming python3/bash/git/node" \
  "node -e 'p=require(\"$TMP/ex.json\");w=p.preconditions.warnings.filter(x=>x.code===\"ENVIRONMENT\");e=w[0]&&w[0].environment;process.exit((w.length===1&&e&&e.python3&&e.bash&&e.git&&e.node)?0:1)'"
assert "the environment section records WHAT WAS FOUND (path + version), not just booleans" \
  "node -e '
    p=require(\"$TMP/ex.json\");
    e=p.preconditions.warnings.filter(x=>x.code===\"ENVIRONMENT\")[0].environment;
    var ok=[\"python3\",\"bash\",\"git\",\"node\"].every(function(k){
      var r=e[k];
      return typeof r.detail===\"string\" && r.detail.length>5 && (\"resolvedPath\" in r) && (\"version\" in r);
    });
    process.exit(ok?0:1);'"
assert "ENVIRONMENT is never a blocking item" \
  "node -e 'p=require(\"$TMP/ex.json\");process.exit(p.preconditions.blocking.some(b=>b.code===\"ENVIRONMENT\")?1:0)'"
assert "on a healthy machine (this test runner), python3/bash/git all report usable" \
  "node -e 'p=require(\"$TMP/ex.json\");e=p.preconditions.warnings.filter(x=>x.code===\"ENVIRONMENT\")[0].environment;process.exit((e.python3.usable&&e.bash.usable&&e.git.usable)?0:1)'"

# ── detection never throws, even against a hostile/stubbed PATH ─────────────
# The stub PATH carries real `node` and `git` (symlinked) so the CLI itself and
# its read-only git calls still run, plus a python3 STUB that answers instantly
# but is not Python 3 (simulating a wrapper/alias, not a real interpreter), and
# NO bash at all.
STUBDIR="$TMP/stubpath"
mkdir -p "$STUBDIR"
REAL_NODE="$(command -v node)"
REAL_GIT="$(command -v git)"
ln -sf "$REAL_NODE" "$STUBDIR/node"
ln -sf "$REAL_GIT" "$STUBDIR/git"
cat > "$STUBDIR/python3" <<'PYEOF'
#!/bin/sh
echo "2 2.7.18"
exit 0
PYEOF
chmod +x "$STUBDIR/python3"

PATH="$STUBDIR" node "$CLI" init "$EX" --json >"$TMP/stub-unusable.json" 2>"$TMP/stub-unusable.err"; STUB1_RC=$?
assert "the planner did not crash against a hostile PATH (valid JSON was produced)" \
  "node -e 'require(\"$TMP/stub-unusable.json\");process.exit(0)' 2>/dev/null"
assert "an unusable (non-Python-3) python3 on PATH yields PYTHON3-UNUSABLE" \
  "node -e 'p=require(\"$TMP/stub-unusable.json\");process.exit(p.preconditions.warnings.some(w=>w.code===\"PYTHON3-UNUSABLE\")?0:1)'"
assert "PYTHON3-UNUSABLE names the resolved stub path in its detail" \
  "node -e '
    var path=require(\"path\");
    p=require(\"$TMP/stub-unusable.json\");
    w=p.preconditions.warnings.filter(x=>x.code===\"PYTHON3-UNUSABLE\")[0];
    var expect=path.join(\"$STUBDIR\",\"python3\");
    process.exit(w.detail.indexOf(expect)!==-1?0:1);'"
assert "PYTHON3-UNUSABLE is a warning, never blocking (--only is unknown at plan time)" \
  "node -e 'p=require(\"$TMP/stub-unusable.json\");process.exit(p.preconditions.blocking.some(b=>b.code===\"PYTHON3-UNUSABLE\")?1:0)'"
assert "bash absent from PATH yields BASH-MISSING" \
  "node -e 'p=require(\"$TMP/stub-unusable.json\");process.exit(p.preconditions.warnings.some(w=>w.code===\"BASH-MISSING\")?0:1)'"
assert "BASH-MISSING is a warning, never blocking" \
  "node -e 'p=require(\"$TMP/stub-unusable.json\");process.exit(p.preconditions.blocking.some(b=>b.code===\"BASH-MISSING\")?1:0)'"
assert "applyReady is unaffected by env warnings (still computed, not poisoned)" \
  "node -e 'p=require(\"$TMP/stub-unusable.json\");process.exit(typeof p.applyReady===\"boolean\"?0:1)'"

rm -f "$STUBDIR/python3"
PATH="$STUBDIR" node "$CLI" init "$EX" --json >"$TMP/stub-missing.json" 2>/dev/null
assert "python3 entirely absent from PATH yields PYTHON3-MISSING, not UNUSABLE" \
  "node -e 'p=require(\"$TMP/stub-missing.json\");c=p.preconditions.warnings.map(w=>w.code);process.exit((c.indexOf(\"PYTHON3-MISSING\")!==-1&&c.indexOf(\"PYTHON3-UNUSABLE\")===-1)?0:1)'"

PATH="$STUBDIR" node "$CLI" init "$EX" >"$TMP/stub-missing.txt" 2>"$TMP/stub-missing.err"
assert "the TEXT report (not just --json) also survives a broken environment" \
  "grep -q 'Execution environment' \"$TMP/stub-missing.txt\""
assert "the text report names the missing python3 by code" \
  "grep -q 'PYTHON3-MISSING' \"$TMP/stub-missing.txt\""

# ── node floor: below-floor is a WARNING and can never become blocking ───────
assert "meetsFloor(): node below the declared floor compares false" \
  "node -e 'var d=require(\"$PKG/lib/detect.js\");process.exit(d.meetsFloor(\"v16.20.0\",\">=20.0.0\")===false?0:1)'"
assert "meetsFloor(): node exactly at the declared floor compares true" \
  "node -e 'var d=require(\"$PKG/lib/detect.js\");process.exit(d.meetsFloor(\"v20.0.0\",\">=20.0.0\")===true?0:1)'"
assert "meetsFloor(): node above the declared floor compares true" \
  "node -e 'var d=require(\"$PKG/lib/detect.js\");process.exit(d.meetsFloor(\"v20.11.0\",\">=20.0.0\")===true?0:1)'"
assert "a node below the declared floor yields NODE-BELOW-DECLARED-FLOOR as a WARNING, never blocking" \
  "node -e '
    var detect=require(\"$PKG/lib/detect.js\");
    var pre=require(\"$PKG/lib/preconditions.js\");
    var d=detect.detect(\"$EX\");
    d.environment.node=Object.assign({},d.environment.node,{version:\"v16.20.0\",declaredFloor:\">=20.0.0\",meetsFloor:false});
    var r=pre.evaluate(d, [], {});
    var w=r.warnings.some(function(x){return x.code===\"NODE-BELOW-DECLARED-FLOOR\";});
    var b=r.blocking.some(function(x){return x.code===\"NODE-BELOW-DECLARED-FLOOR\";});
    process.exit((w&&!b)?0:1);'"

# ── package.json declares an honest runtime floor ────────────────────────────
assert "engines.node is a real, evidence-backed runtime floor (20), not the publish-time 22.14.0 requirement" \
  "node -e 'var pkg=require(\"$PKG/package.json\");process.exit(pkg.engines.node===\">=20.0.0\"?0:1)'"

# ── jq: presence-only, worded around session-runtime hook behaviour ──────────
echo ""
echo "── jq / win32 / nested install ──"

assert "jq usable on this runner is recorded in the environment section" \
  "node -e 'p=require(\"$TMP/ex.json\");e=p.preconditions.warnings.filter(x=>x.code===\"ENVIRONMENT\")[0].environment;process.exit(e.jq?0:1)'"

assert "probeJq(): presence-only, no version probe, never throws when jq is absent" \
  "node -e '
    var detect=require(\"$PKG/lib/detect.js\");
    var save=process.env.PATH;
    process.env.PATH=\"$TMP/stubpath-empty\";
    var fs=require(\"fs\"); fs.mkdirSync(\"$TMP/stubpath-empty\",{recursive:true});
    var r=detect.probeJq();
    process.env.PATH=save;
    process.exit((r.present===false&&r.usable===false&&r.version===\"unknown\")?0:1);'"

assert "jq missing while python3 IS usable: the warning says the python3 fallback still works" \
  "node -e '
    var pre=require(\"$PKG/lib/preconditions.js\");
    var env={python3:{present:true,usable:true,version:\"3.11.0\",resolvedPath:\"/usr/bin/python3\",detail:\"usable\"},
             bash:{present:true,usable:true,version:\"5.2\",resolvedPath:\"/bin/bash\",detail:\"usable\"},
             git:{present:true,usable:true,version:\"2.40.0\",resolvedPath:\"/usr/bin/git\",detail:\"usable\"},
             node:{present:true,usable:true,version:\"v20.0.0\",declaredFloor:\">=20.0.0\",meetsFloor:true,detail:\"ok\"},
             jq:{present:false,usable:false,version:\"unknown\",resolvedPath:null,detail:\"not found on PATH\"},
             platform:\"darwin\"};
    var items=pre.evaluateEnvironment(env);
    var w=items.filter(function(i){return i.code===\"JQ-MISSING\";});
    process.exit((w.length===1&&w[0].severity===\"warning\"&&/still enforce correctly/.test(w[0].detail))?0:1);'"

assert "jq AND python3 both absent: the warning says the guards fail OPEN" \
  "node -e '
    var pre=require(\"$PKG/lib/preconditions.js\");
    var env={python3:{present:false,usable:false,version:\"unknown\",resolvedPath:null,detail:\"not found on PATH\"},
             bash:{present:true,usable:true,version:\"5.2\",resolvedPath:\"/bin/bash\",detail:\"usable\"},
             git:{present:true,usable:true,version:\"2.40.0\",resolvedPath:\"/usr/bin/git\",detail:\"usable\"},
             node:{present:true,usable:true,version:\"v20.0.0\",declaredFloor:\">=20.0.0\",meetsFloor:true,detail:\"ok\"},
             jq:{present:false,usable:false,version:\"unknown\",resolvedPath:null,detail:\"not found on PATH\"},
             platform:\"darwin\"};
    var items=pre.evaluateEnvironment(env);
    var w=items.filter(function(i){return i.code===\"JQ-MISSING\";});
    process.exit((w.length===1&&/fail OPEN/.test(w[0].detail))?0:1);'"

assert "JQ-MISSING is a warning, never blocking" \
  "node -e '
    var pre=require(\"$PKG/lib/preconditions.js\");
    var env={python3:{present:false,usable:false},bash:{present:true,usable:true},
             git:{present:true,usable:true},node:{present:true,usable:true,meetsFloor:true},
             jq:{present:false,usable:false},platform:\"darwin\"};
    var items=pre.evaluateEnvironment(env);
    process.exit(items.some(function(i){return i.code===\"JQ-MISSING\"&&i.severity===\"warning\";})?0:1);'"

# ── win32: an honest POSIX-only posture, warning-only ─────────────────────────
assert "platform=win32 yields WIN32-POSIX-ONLY as a warning" \
  "node -e '
    var pre=require(\"$PKG/lib/preconditions.js\");
    var env={python3:{present:true,usable:true},bash:{present:true,usable:true},
             git:{present:true,usable:true},node:{present:true,usable:true,meetsFloor:true},
             jq:{present:true,usable:true},platform:\"win32\"};
    var items=pre.evaluateEnvironment(env);
    var w=items.filter(function(i){return i.code===\"WIN32-POSIX-ONLY\";});
    process.exit((w.length===1&&w[0].severity===\"warning\")?0:1);'"
assert "platform=darwin/linux never yields WIN32-POSIX-ONLY" \
  "node -e '
    var pre=require(\"$PKG/lib/preconditions.js\");
    var env={python3:{present:true,usable:true},bash:{present:true,usable:true},
             git:{present:true,usable:true},node:{present:true,usable:true,meetsFloor:true},
             jq:{present:true,usable:true},platform:\"darwin\"};
    var items=pre.evaluateEnvironment(env);
    process.exit(items.some(function(i){return i.code===\"WIN32-POSIX-ONLY\";})?1:0);'"

# ── nested install: target root vs git toplevel ───────────────────────────────
MONO="$TMP/mono"
mkdir -p "$MONO/packages/foo"
git_quiet "$MONO" init
git_quiet "$MONO" commit --allow-empty -m baseline

node "$CLI" init "$MONO/packages/foo" --json >"$TMP/mono-nested.json" 2>/dev/null; MONO_RC=$?
assert "installing INTO a git subdirectory is BLOCKING (NESTED-GIT-INSTALL)" \
  "node -e 'p=require(\"$TMP/mono-nested.json\");process.exit(p.preconditions.blocking.some(b=>b.code===\"NESTED-GIT-INSTALL\")?0:1)'"
assert "the nested-install remedy names the real repository root" \
  "node -e '
    var fs=require(\"fs\");
    p=require(\"$TMP/mono-nested.json\");
    b=p.preconditions.blocking.filter(x=>x.code===\"NESTED-GIT-INSTALL\")[0];
    var expect=fs.realpathSync(\"$MONO\");
    process.exit(b.remedy.indexOf(expect)!==-1?0:1);'"
assert "nested-install makes applyReady false" \
  "node -e 'p=require(\"$TMP/mono-nested.json\");process.exit(p.applyReady===false?0:1)'"
assert "a nested-install plan exits 1" "[ $MONO_RC -eq 1 ]"

node "$CLI" init "$MONO" --json >"$TMP/mono-root.json" 2>/dev/null
assert "installing AT the git toplevel itself is NOT flagged nested" \
  "node -e 'p=require(\"$TMP/mono-root.json\");process.exit(p.preconditions.blocking.some(b=>b.code===\"NESTED-GIT-INSTALL\")?1:0)'"
assert "installing at the toplevel of a fresh EXISTING repo is still applyReady (once baseline exists)" \
  "node -e 'p=require(\"$TMP/mono-root.json\");process.exit(p.applyReady===true?0:1)'"

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
