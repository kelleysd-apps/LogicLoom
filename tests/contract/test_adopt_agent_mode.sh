#!/usr/bin/env bash
# Contract Tests: the adopt package driven by a CODING AGENT, and the
# plan/apply parity that makes the plan honest enough to drive it with.
#
# WHY THIS SUITE EXISTS
# -----------------------------------------------------------------------------
# `logicloom init` served a person reading a terminal. An agent installing this
# on a user's behalf needs two things that report does not give it: the set of
# decisions the user must actually make, as data, and a procedure it can read
# before it has LogicLoom. Both now ship, and both are only worth anything if
# they cannot drift from what the tool does.
#
# What it pins:
#   A. PLAN/APPLY PARITY — the defect this suite was opened for. The plan's
#      merge units come from the SAME artifacts the merges ship
#      (merge/gitignore-block.txt, merge/settings-hooks-fragment.json), so the
#      plan cannot promise a line the apply will not write, nor omit one it
#      will. Held in BOTH directions, plus the three dead patterns by name.
#   B. `decisions[]` — present, derived (never a second hardcoded list), and
#      complete enough to act on: every entry names its flag, every option
#      carries a consequence, `hooks` is never in the default.
#   C. `applicable: false` on a question that is not a question — an agent must
#      not interrogate a user about a CLAUDE.md that does not exist.
#   D. MECHANICAL DERIVATION — the actual claim. Take the JSON, build an apply
#      command from the decision defaults with no human judgement, run it, and
#      the install lands.
#   E. `--agent-guide` — resolves no repository, writes nothing, and states the
#      refusals an agent would otherwise try to "help" past.
#   F. NON-REGRESSION — the human report is still the review artifact.
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
GUIDE="$PKG/AGENT-INSTALL.md"
BLOCK="$PKG/merge/gitignore-block.txt"
FRAGMENT="$PKG/merge/settings-hooks-fragment.json"

echo "🧪 Adopt — Agent-Drivable Install Contract Tests"
echo "==============================================="
echo ""

# ── Vacuously green on a stripped tree, FAIL-CLOSED on rot ───────────────────
# Same shape and same reason as test_adopt_merges.sh: `packaging` is a
# template-strip-manifest entry, so none of this exists in a shipped tree.
IS_TRACKED=no
if git -C "$ROOT" ls-files --error-unmatch "$CLI" >/dev/null 2>&1; then IS_TRACKED=yes; fi
if [ ! -f "$CLI" ] && [ "$IS_TRACKED" = no ]; then
  echo "  ⏭  SKIP: no packaging/adopt/ and none tracked — stripped or customer tree."
  echo ""
  echo "Results: $PASS/$TOTAL passed, $FAIL failed"
  exit 0
fi

for f in "$CLI" "$GUIDE" "$BLOCK" "$FRAGMENT"; do
  assert "exists: ${f#$ROOT/}" "[ -f \"$f\" ]"
done
if [ ! -f "$CLI" ] || [ ! -f "$GUIDE" ] || [ ! -f "$BLOCK" ] || [ ! -f "$FRAGMENT" ]; then
  echo ""; echo "Results: $PASS/$TOTAL passed, $FAIL failed"; exit 1
fi

command -v node >/dev/null 2>&1 || { echo "  ❌ node not on PATH"; exit 1; }

WORK="$(mktemp -d -t loom-adopt-agent.XXXXXX)" || exit 1
trap 'rm -rf "$WORK"' EXIT
git_quiet() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}" >/dev/null 2>&1; }

# Three target shapes, built once and reused: an empty directory, an existing
# project carrying the two merge targets plus a CLAUDE.md, and one that BLOCKS.
EMPTY="$WORK/empty"; mkdir -p "$EMPTY"; git_quiet "$EMPTY" init

EX="$WORK/existing"; mkdir -p "$EX/.claude"; git_quiet "$EX" init
printf '# My project\n\nProject rules.\n' > "$EX/CLAUDE.md"
printf '{\n  "hooks": {\n    "PreToolUse": [\n      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "echo mine" } ] }\n    ]\n  }\n}\n' \
  > "$EX/.claude/settings.json"
printf 'node_modules/\n.env\n.logic-loom/state/\n' > "$EX/.gitignore"
printf '{"name":"mine"}\n' > "$EX/package.json"
git_quiet "$EX" add -A; git_quiet "$EX" commit -m base

BL="$WORK/blocked"; mkdir -p "$BL"; git_quiet "$BL" init
printf 'x\n' > "$BL/README.md"; git_quiet "$BL" add README.md; git_quiet "$BL" commit -m base
mkdir -p "$BL/.claude/hooks"; printf '#!/bin/sh\n' > "$BL/.claude/hooks/mine.sh"

node "$CLI" init "$EMPTY" --json > "$WORK/empty.json" 2>"$WORK/empty.err"
node "$CLI" init "$EX"    --json > "$WORK/ex.json"    2>"$WORK/ex.err"
node "$CLI" init "$BL"    --json > "$WORK/bl.json"    2>"$WORK/bl.err"

J() { node -e "
  const p = require('$1');
  const f = new Function('p', 'return (' + process.argv[1] + ');');
  const v = f(p);
  process.stdout.write(Array.isArray(v) ? v.join(',') : String(v));
" "$2"; }

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "── A · plan/apply parity for the two merges ─────────────────────────────"
# THE DEFECT. The plan listed 27 .gitignore line units derived by filtering
# LogicLoom's own .gitignore by harness-owned prefix. The apply ships
# gitignore-block.txt, which is 29 CURATED patterns. Three of the plan's were
# deliberately dropped from the block (dead in our own harness) and five of the
# block's were never in the plan (no prefix matches `**/…`). The plan is the
# artifact under review; it may not overstate or understate the write.

node -e '
const fs = require("fs");
const plan = require(process.argv[1]);
const block = fs.readFileSync(process.argv[2], "utf8").split("\n")
  .map(l => l.trim()).filter(l => l.length && l.charAt(0) !== "#");
const units = plan.buckets.additive.concat(plan.buckets["keep-theirs"])
  .filter(u => u.granularity === "line").map(u => u.value);
const over  = units.filter(v => block.indexOf(v) === -1);
const under = block.filter(v => units.indexOf(v) === -1);
fs.writeFileSync(process.argv[3], JSON.stringify({
  units: units.length, block: block.length, over: over, under: under
}));
' "$WORK/empty.json" "$BLOCK" "$WORK/gi.parity.json"

GI_UNITS="$(J "$WORK/gi.parity.json" 'p.units')"
GI_BLOCK="$(J "$WORK/gi.parity.json" 'p.block')"
assert "the plan's .gitignore line-unit count equals the shipped block's ($GI_UNITS = $GI_BLOCK)" \
  "[ \"$GI_UNITS\" = \"$GI_BLOCK\" ] && [ \"$GI_UNITS\" -gt 0 ]"
assert "no planned .gitignore line is absent from the shipped block (overstating: $(J "$WORK/gi.parity.json" 'p.over'))" \
  "[ -z \"$(J "$WORK/gi.parity.json" 'p.over')\" ]"
assert "no shipped .gitignore pattern is absent from the plan (understating: $(J "$WORK/gi.parity.json" 'p.under'))" \
  "[ -z \"$(J "$WORK/gi.parity.json" 'p.under')\" ]"

# The three by name. Each is dead in the harness itself and each is recorded as
# a `drop:` in merge/gitignore-decisions.txt; a plan that promises them is
# promising a line no apply will ever write.
for dead in '.devloop/' 'test-checkpoint-*' '.claude/skill-index.json.bak'; do
  assert "the plan never promises the dropped pattern '$dead'" \
    "! grep -qF '\"gitignore-line:$dead\"' \"$WORK/empty.json\""
done
# And five the block ships that no prefix filter matched.
for shipped in '**/.claude/settings.local.json' '**/CLAUDE.local.md' 'vector_helper.py'; do
  assert "the plan lists the shipped pattern '$shipped'" \
    "grep -qF '\"gitignore-line:$shipped\"' \"$WORK/empty.json\""
done

assert "every .gitignore line unit names its merge source" \
  "node -e 'p=require(\"$WORK/empty.json\");process.exit(p.buckets.additive.filter(u=>u.granularity===\"line\").every(u=>u.mergeSource===\"merge/gitignore-block.txt\")?0:1)'"

# Same parity for the settings fragment. It held by test today; it now holds by
# construction, and both directions are asserted so it stays that way.
node -e '
const fs = require("fs");
const plan = require(process.argv[1]);
const frag = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const f = [];
for (const ev of Object.keys(frag.hooks || {}))
  for (const g of frag.hooks[ev] || [])
    for (const h of (g.hooks || [])) f.push(ev + "|" + (g.matcher || "") + "|" + h.command);
const units = plan.buckets.additive.concat(plan.buckets["keep-theirs"])
  .filter(u => u.granularity === "json-key")
  .map(u => u.selector.event + "|" + u.selector.matcher + "|" + u.selector.command);
fs.writeFileSync(process.argv[3], JSON.stringify({
  units: units.length, frag: f.length,
  over: units.filter(v => f.indexOf(v) === -1),
  under: f.filter(v => units.indexOf(v) === -1)
}));
' "$WORK/empty.json" "$FRAGMENT" "$WORK/hk.parity.json"

assert "the plan's hook-unit count equals the shipped fragment's ($(J "$WORK/hk.parity.json" 'p.units') = $(J "$WORK/hk.parity.json" 'p.frag'))" \
  "[ \"$(J "$WORK/hk.parity.json" 'p.units')\" = \"$(J "$WORK/hk.parity.json" 'p.frag')\" ] && [ \"$(J "$WORK/hk.parity.json" 'p.units')\" -gt 0 ]"
assert "no planned hook command is absent from the shipped fragment" \
  "[ -z \"$(J "$WORK/hk.parity.json" 'p.over')\" ]"
assert "no shipped hook command is absent from the plan" \
  "[ -z \"$(J "$WORK/hk.parity.json" 'p.under')\" ]"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "── B · decisions[] — present, derived, actionable ───────────────────────"

assert "the plan carries a decisions array" \
  "node -e 'p=require(\"$WORK/ex.json\");process.exit(Array.isArray(p.decisions)&&p.decisions.length?0:1)'"
assert "the schema version is UNCHANGED — decisions is an additive field within @1" \
  "node -e 'p=require(\"$WORK/ex.json\");process.exit(p.schema===\"logicloom/adopt-plan@1\"?0:1)'"
assert "decision ids are the two real choices: targets, claude-md" \
  "[ \"$(J "$WORK/ex.json" 'p.decisions.map(d=>d.id)')\" = 'targets,claude-md' ]"

# DERIVED, not a second hardcoded list. The target options must BE apply.js's
# TARGETS keys and the mode options must BE claude-md.js's MODES — so adding
# either adds an option automatically instead of drifting silently.
assert "targets options are derived from lib/apply.js TARGETS (not hardcoded)" \
  "node -e '
     const A=require(\"$PKG/lib/apply\"), p=require(\"$WORK/ex.json\");
     const d=p.decisions.find(x=>x.id===\"targets\");
     process.exit(JSON.stringify(d.options.map(o=>o.value))===JSON.stringify(A.ALL_TARGETS)?0:1)'"
assert "claude-md options are derived from lib/claude-md.js MODES (not hardcoded)" \
  "node -e '
     const C=require(\"$PKG/lib/claude-md\"), p=require(\"$WORK/ex.json\");
     const d=p.decisions.find(x=>x.id===\"claude-md\");
     process.exit(JSON.stringify(d.options.map(o=>o.value))===JSON.stringify(C.MODES)?0:1)'"

assert "every decision names the EXACT flag that sets it" \
  "node -e 'p=require(\"$WORK/ex.json\");process.exit(p.decisions.every(d=>typeof d.flag===\"string\"&&d.flag.indexOf(\"--\")===0&&typeof d.flagForm===\"string\")?0:1)'"
assert "every decision carries a default with a stated reason" \
  "node -e 'p=require(\"$WORK/ex.json\");process.exit(p.decisions.every(d=>d.default&&d.default.value&&d.default.why&&d.default.why.length>20)?0:1)'"
assert "every option carries a summary AND a consequence" \
  "node -e 'p=require(\"$WORK/ex.json\");process.exit(p.decisions.every(d=>d.options.every(o=>o.summary&&o.consequence&&o.consequence.length>20))?0:1)'"
assert "the targets decision is REQUIRED — there is no apply-everything-by-omission" \
  "node -e 'p=require(\"$WORK/ex.json\");process.exit(p.decisions.find(d=>d.id===\"targets\").required===true?0:1)'"

# REFUSAL 6, restated where an agent reads it. A governance floor must never be
# reachable by the word \"all\".
assert "'hooks' is an option but is NOT in the default expansion" \
  "node -e '
     p=require(\"$WORK/ex.json\");d=p.decisions.find(x=>x.id===\"targets\");
     const h=d.options.find(o=>o.value===\"hooks\");
     process.exit(h && h.inDefault===false && d.default.expandsTo.indexOf(\"hooks\")===-1 ? 0 : 1)'"
assert "the hooks consequence says it changes what the user's own sessions may do" \
  "node -e '
     p=require(\"$WORK/ex.json\");d=p.decisions.find(x=>x.id===\"targets\");
     process.exit(/sessions may do/i.test(d.options.find(o=>o.value===\"hooks\").consequence)?0:1)'"
assert "only claude-md's 'import' is flagged as touching a file the adopter owns" \
  "node -e '
     p=require(\"$WORK/ex.json\");d=p.decisions.find(x=>x.id===\"claude-md\");
     process.exit(d.options.every(o=>(o.value===\"import\")===(o.touchesYourFiles.length>0))?0:1)'"
assert "option counts are reported so an agent can skip a no-op target" \
  "node -e '
     p=require(\"$WORK/ex.json\");d=p.decisions.find(x=>x.id===\"targets\");
     process.exit(d.options.every(o=>typeof o.wouldWrite===\"number\"&&typeof o.noOp===\"boolean\"&&o.noOp===(o.wouldWrite===0))?0:1)'"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "── C · a question that is not a question is marked not-applicable ───────"
# An agent must not interrogate its user about a CLAUDE.md that does not exist.

assert "with a CLAUDE.md present, the claude-md decision IS applicable" \
  "node -e 'p=require(\"$WORK/ex.json\");process.exit(p.decisions.find(d=>d.id===\"claude-md\").applicable===true?0:1)'"
assert "with NO CLAUDE.md, the claude-md decision is applicable:false" \
  "node -e 'p=require(\"$WORK/empty.json\");process.exit(p.decisions.find(d=>d.id===\"claude-md\").applicable===false?0:1)'"
assert "...and it says WHY, rather than just going quiet" \
  "node -e 'p=require(\"$WORK/empty.json\");const d=p.decisions.find(x=>x.id===\"claude-md\");process.exit(d.notApplicableReason&&d.notApplicableReason.length>20?0:1)'"
assert "a requested import with no CLAUDE.md reports the COLLAPSE in the decision" \
  "node \"$CLI\" init \"$EMPTY\" --claude-md=import --json > \"$WORK/coll.json\" 2>/dev/null;
   node -e 'p=require(\"$WORK/coll.json\");const d=p.decisions.find(x=>x.id===\"claude-md\");
            process.exit(d.resolved.collapsed===true&&d.resolved.value===\"rules\"?0:1)'"

# A BLOCKED plan still carries the decisions — an agent should be able to tell
# the user what the choices WILL be while relaying the remedy.
assert "a blocking plan is applyReady:false" \
  "node -e 'p=require(\"$WORK/bl.json\");process.exit(p.applyReady===false?0:1)'"
assert "...and still carries decisions, so the agent can explain what is ahead" \
  "node -e 'p=require(\"$WORK/bl.json\");process.exit(Array.isArray(p.decisions)&&p.decisions.length===2?0:1)'"
assert "...and every blocking item carries a remedy the HUMAN runs, never a stash" \
  "node -e 'p=require(\"$WORK/bl.json\");process.exit(p.preconditions.blocking.every(b=>b.remedy&&b.remedy.indexOf(\"git stash\")===-1)?0:1)'"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "── D · an agent can derive the apply command MECHANICALLY ───────────────"
# The actual claim under test. No human judgement in the loop: read the JSON,
# take each decision's default, emit the flags, run it.

MECH="$WORK/mech"; mkdir -p "$MECH"; git_quiet "$MECH" init
printf 'x\n' > "$MECH/README.md"; printf 'node_modules/\n' > "$MECH/.gitignore"
git_quiet "$MECH" add -A; git_quiet "$MECH" commit -m base
node "$CLI" init "$MECH" --json > "$WORK/mech.json" 2>/dev/null

# The derivation, written as an agent would: applicable decisions only, default
# values only, flagForm's flag name only. Nothing about this repository is known
# to it.
ARGS="$(node -e '
const p = require(process.argv[1]);
const out = [];
for (const d of p.decisions) {
  if (!d.applicable) continue;
  out.push(d.flag + "=" + d.default.value);
}
process.stdout.write(out.join(" "));
' "$WORK/mech.json")"
assert "the derived flag list is exactly the applicable defaults" \
  "[ \"$ARGS\" = '--only=all' ]"

node "$CLI" init "$MECH" --apply $ARGS > "$WORK/mech.out" 2>&1; MECH_RC=$?
assert "the mechanically derived apply command succeeds (exit 0, got $MECH_RC)" \
  "[ $MECH_RC -eq 0 ]"
assert "...and the harness tree landed" "[ -d \"$MECH/.logic-loom\" ]"
assert "...and the rules files landed" \
  "ls \"$MECH/.claude/rules/\" 2>/dev/null | grep -q 'logicloom-'"
assert "...and the fenced .gitignore block landed" \
  "grep -q 'LogicLoom adopt' \"$MECH/.gitignore\""
assert "...and the adopter's own first .gitignore line is byte-identical" \
  "[ \"\$(head -1 \"$MECH/.gitignore\")\" = 'node_modules/' ]"
assert "...and 'all' did NOT reach the governance hooks (refusal 6)" \
  "! grep -q 'logic-loom' \"$MECH/.claude/settings.json\" 2>/dev/null"
assert "...and a receipt records what was written" \
  "[ -f \"$MECH/.logicloom-adopt-receipt.json\" ]"

# THE PARITY CLAIM, END TO END. Every pattern the plan promised is in the file
# the apply wrote, and the fence holds nothing the plan did not promise.
node -e '
const fs = require("fs");
const plan = require(process.argv[1]);
const all = fs.readFileSync(process.argv[2], "utf8").split("\n");
let begin = -1;
for (let i = 0; i < all.length; i++) if (all[i].indexOf(">>> LogicLoom adopt") !== -1) { begin = i; break; }
const fenced = all.slice(begin).map(l => l.trim())
  .filter(l => l.length && l.charAt(0) !== "#");
const promised = plan.buckets.additive.filter(u => u.granularity === "line").map(u => u.value);
fs.writeFileSync(process.argv[3], JSON.stringify({
  promised: promised.length,
  missing: promised.filter(v => fenced.indexOf(v) === -1),
  extra: fenced.filter(v => promised.indexOf(v) === -1)
}));
' "$WORK/mech.json" "$MECH/.gitignore" "$WORK/land.json"

assert "every .gitignore pattern the plan promised was actually written (missing: $(J "$WORK/land.json" 'p.missing'))" \
  "[ -z \"$(J "$WORK/land.json" 'p.missing')\" ]"
assert "the written fence holds nothing the plan did not promise (extra: $(J "$WORK/land.json" 'p.extra')" \
  "[ -z \"$(J "$WORK/land.json" 'p.extra')\" ]"
assert "...and that is a non-zero number of patterns, not a vacuous pass" \
  "[ \"$(J "$WORK/land.json" 'p.promised')\" -gt 20 ]"

# The apply's own report must not claim a pattern it did not ship. With parity
# by construction the deliberately-dropped count is now zero, and the report
# says nothing about drops — the claim is that it never says a wrong number.
assert "the apply report no longer reports .gitignore patterns as unshipped" \
  "! grep -q \"own .gitignore are deliberately NOT\" \"$WORK/mech.out\""

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "── E · --agent-guide: findable, read-only, unambiguous about refusals ───"

node "$CLI" init --agent-guide > "$WORK/guide.out" 2>"$WORK/guide.err"; G_RC=$?
assert "--agent-guide exits 0" "[ $G_RC -eq 0 ]"
assert "--agent-guide needs no target directory, payload or git" \
  "[ -s \"$WORK/guide.out\" ] && [ ! -s \"$WORK/guide.err\" ]"
assert "--agent-guide prints the shipped AGENT-INSTALL.md verbatim" \
  "diff -q \"$GUIDE\" \"$WORK/guide.out\" >/dev/null"

# Writes nothing. Run it from inside a repo and fingerprint before/after.
FP_BEFORE="$(find "$MECH" -type f ! -name '.logicloom-adopt-receipt.json' -print0 2>/dev/null | LC_ALL=C sort -z | xargs -0 shasum 2>/dev/null | shasum)"
( cd "$MECH" && node "$CLI" init --agent-guide >/dev/null 2>&1 )
FP_AFTER="$(find "$MECH" -type f ! -name '.logicloom-adopt-receipt.json' -print0 2>/dev/null | LC_ALL=C sort -z | xargs -0 shasum 2>/dev/null | shasum)"
assert "--agent-guide writes nothing into the repository it is run from" \
  "[ \"$FP_BEFORE\" = \"$FP_AFTER\" ]"

# THE REFUSALS. An agent that does not know these will try to "help" past a
# block — stash the user's work, delete the colliding file, retry with force.
assert "the guide states there is no --force" "grep -q 'no \`--force\`' \"$GUIDE\""
assert "the guide states it never deletes, truncates, moves or overwrites" \
  "grep -qi 'never deletes, truncates, moves, or overwrites' \"$GUIDE\""
assert "the guide states it never runs mutating git" \
  "grep -qi 'never runs mutating git' \"$GUIDE\""
assert "the guide names 'git stash' as a thing it never does" \
  "grep -q 'git stash' \"$GUIDE\""
assert "the guide tells the agent to relay the remedy and STOP on a block" \
  "grep -qi 'Relay the remedy' \"$GUIDE\""
assert "the guide states hooks is not in --only=all" \
  "grep -q 'not in \`--only=all\`' \"$GUIDE\""
assert "the guide documents every exit code the CLI can return" \
  "for c in 0 1 2 3 4; do grep -q \"\\\`\$c\\\`\" \"$GUIDE\" || exit 1; done"

# DISCOVERABILITY — three routes, and each must actually point at the file.
assert "route 1: --help advertises --agent-guide" \
  "node \"$CLI\" init --help 2>&1 | grep -q -- '--agent-guide'"
assert "route 2: the plan JSON carries agentGuide with the command that prints it" \
  "node -e 'p=require(\"$WORK/ex.json\");process.exit(p.agentGuide&&p.agentGuide.file===\"AGENT-INSTALL.md\"&&/--agent-guide/.test(p.agentGuide.command)?0:1)'"
assert "route 3: the human report carries a pointer to it" \
  "node \"$CLI\" init \"$EX\" 2>/dev/null | grep -q -- '--agent-guide'"

# ── route 3, PINNED: the pointer LEADS the report, it does not trail it ──────
# The defect this pins: the pointer used to be the report's FOOTER. On a real
# existing repository that put it at line 249 of 250, so an agent that shells
# out, reads from byte zero and starts acting never reached it — and parsed
# prose written for a human instead. Position, not presence, was the defect, so
# presence alone is not the assertion.
#
# N = 12, and the number is chosen, not rounded to:
#   * the longest header the renderer can emit is the NON-TTY one — title,
#     8 fixed lines, one line per decision (2 today), rule — which lands the
#     `===` rule at line 11 and every pointer line at or above 10. N=12 is that
#     plus two lines of headroom, so adding a third decision does not break it.
#   * the SMALLEST plan section that could precede the pointer is the rule +
#     blank + MODE + a wrapped `why` — 5 lines minimum, and the existing-project
#     report's next block is 9 more. So any regression that demotes the pointer
#     back below plan content overshoots 12 immediately. The bound is tight
#     enough to fail on the actual defect and loose enough not to fail on prose.
POINTER_MAX_LINES=12
# `set -o pipefail` is on and a BLOCKED plan exits 1 by design, so the report is
# captured first — otherwise the assertion would fail on the exit code rather
# than on the thing it is testing.
head_of() { node "$CLI" init "$1" > "$WORK/head.out" 2>/dev/null; head -"$POINTER_MAX_LINES" "$WORK/head.out"; }
head_has_pointer() { head_of "$1" | grep -q -- '--agent-guide'; }

assert "PIPED: pointer within the first $POINTER_MAX_LINES lines — existing project" \
  "head_has_pointer \"$EX\""
assert "PIPED: pointer within the first $POINTER_MAX_LINES lines — new project" \
  "head_has_pointer \"$EMPTY\""
assert "PIPED: a BLOCKING report does not crowd the pointer out" \
  "head_has_pointer \"$BL\""

# The TTY branch, exercised through the renderer directly rather than through a
# pty. `script(1)` is spelled differently on macOS and on the ubuntu-latest
# runner, and a portability wart in a test is a worse trade than calling the
# function whose behaviour is actually under test.
tty_head() { node -e '
  const r = require(process.argv[1] + "/lib/render");
  const out = r.render(require(process.argv[2]), { isTTY: true }).split("\n");
  process.stdout.write(out.slice(0, Number(process.argv[3])).join("\n"));
' "$PKG" "$1" "$POINTER_MAX_LINES"; }

assert "TTY: pointer within the first $POINTER_MAX_LINES lines — existing project" \
  "tty_head \"$WORK/ex.json\" | grep -q -- '--agent-guide'"
assert "TTY: pointer within the first $POINTER_MAX_LINES lines — new project" \
  "tty_head \"$WORK/empty.json\" | grep -q -- '--agent-guide'"
assert "TTY: a BLOCKING report does not crowd the pointer out" \
  "tty_head \"$WORK/bl.json\" | grep -q -- '--agent-guide'"

# The TTY branch must stay SHORT — the whole point of splitting it is that the
# human report is not degraded to serve an agent. Two lines, plus the title.
assert "TTY: the pointer costs a human exactly 2 lines" \
  "[ \"\$(tty_head \"$WORK/ex.json\" | grep -c 'Do not parse this report\|install procedure')\" = 2 ]"

# The non-TTY branch is the ENHANCEMENT, never the mechanism: it must say MORE
# than the TTY branch, and it must summarise the decisions and applyReady so an
# agent that reads nothing else still knows what its user has to decide.
assert "PIPED: the captured-output header is fuller than the TTY one" \
  "head_of \"$EX\" | grep -q 'CAPTURED OUTPUT'"
assert "PIPED: the header names --json as the thing to re-run with" \
  "head_of \"$EX\" | grep -q -- '--json'"
assert "PIPED: the header summarises the decisions inline" \
  "head_of \"$EX\" | grep -q 'decisions to put to your user'"
assert "PIPED: a blocked plan says applyReady NO in the header, not 200 lines down" \
  "head_of \"$BL\" | grep -q 'applyReady: NO'"
assert "the TTY header is NOT the captured-output one (the human report is not degraded)" \
  "tty_head \"$WORK/ex.json\" | grep -qv 'CAPTURED OUTPUT'"

# --json is untouched in both directions: a caller that already asked for data
# gets exactly the bytes it asked for, TTY or not.
assert "--json output is not affected by the header at all" \
  "node \"$CLI\" init \"$EX\" --json 2>/dev/null | head -1 | grep -q '^{$'"
assert "the guide is in package.json files[] — it must survive npm pack" \
  "node -e 'p=require(\"$PKG/package.json\");process.exit(p.files.indexOf(\"AGENT-INSTALL.md\")===-1?1:0)'"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "── F · the human report is unchanged as the review artifact ─────────────"

node "$CLI" init "$EX" > "$WORK/report.txt" 2>/dev/null
assert "the existing-project report still leads with PLAN (read-only) on LINE 1" \
  "head -1 \"$WORK/report.txt\" | grep -q 'PLAN (read-only'"
assert "the four-bucket classification section is still printed" \
  "grep -q 'Classification (4 buckets)' \"$WORK/report.txt\""
assert "the CLAUDE.md integration menu is still printed" \
  "grep -q 'CLAUDE.md INTEGRATION' \"$WORK/report.txt\""
assert "the no-write claim is still the closing statement of substance" \
  "grep -q 'Nothing was written. This command has no write path.' \"$WORK/report.txt\""
node "$CLI" init "$EMPTY" > "$WORK/report2.txt" 2>/dev/null
assert "the new-project report is still its own shape" \
  "head -1 \"$WORK/report2.txt\" | grep -q 'NEW PROJECT'"

# The planner still has no write path — the whole invariant this package rests
# on, re-asserted after adding two fields to its output.
FPE_BEFORE="$(find "$EX" -type f -print0 2>/dev/null | LC_ALL=C sort -z | xargs -0 shasum 2>/dev/null | shasum)"
node "$CLI" init "$EX" --json >/dev/null 2>&1
FPE_AFTER="$(find "$EX" -type f -print0 2>/dev/null | LC_ALL=C sort -z | xargs -0 shasum 2>/dev/null | shasum)"
assert "planning still writes nothing to the target repository" \
  "[ \"$FPE_BEFORE\" = \"$FPE_AFTER\" ]"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
