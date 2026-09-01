#!/usr/bin/env bash
# Contract Tests: adopt-package payload boundary
#
# packaging/adopt/payload-manifest.txt is the reviewable PROPOSAL for which
# subset of the harness the npm adopt package installs into someone else's repo
# (research § 6 PRE-1). The installer is not written yet; this suite is the
# manifest's only consumer, and it exists so the boundary cannot drift or be
# edited into something harmful before the installer arrives.
#
# What it pins:
#   1. Grammar — every non-comment line carries a known verb.
#   2. The non-negotiable exclusion: .github/ and all five workflows. No
#      adopt-side path removes them, so nothing downstream removes
#      them, and branch-topology-guard.yml then fails every PR they open.
#   3. The other required exclusions: tests/, package.json, and the
#      template-clone onboarding files.
#   4. The required inclusions: the harness core.
#   5. Coherence — no path both included and excluded; every include/rename/
#      merge SOURCE exists in the tree, so a row cannot rot silently.
#   6. packaging/ never ships: it is a template-strip-manifest entry, and this
#      manifest excludes it too.
#   7. The PRE-12 Node-floor note survives, dated + sourced + re-checkable, still
#      naming the command that would confirm it.
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

MANIFEST="${LOOM_ADOPT_MANIFEST:-$ROOT/packaging/adopt/payload-manifest.txt}"
STRIP_MANIFEST="$ROOT/.logic-loom/scripts/bash/template-strip-manifest.txt"

echo "🧪 Adopt Payload Manifest Contract Tests"
echo "========================================"
echo ""
echo "Manifest: $MANIFEST"
echo ""

# ── Vacuously green on a stripped tree, FAIL-CLOSED on rot ───────────────────
# `packaging` is a template-strip-manifest entry, so this manifest does not exist
# in any shipped tree — and plugin-tests.yml runs this suite as a CI step, which
# tests/contract/test_shipped_gates_vs_strip.sh executes against a freshly
# stripped tree and requires to exit 0. Same shape and same reason as
# check-brain-record.sh, which is vacuously green on a README-only .brain/: a
# live gate, not a dead one.
#
# The teeth are kept by the TRACKED test. Absent-and-untracked (a stripped tree,
# or a clone that never had packaging/) is a legitimate skip. Absent-but-TRACKED
# means the file was deleted out from under the boundary, and that still fails.
IS_TRACKED=no
if git -C "$ROOT" ls-files --error-unmatch "$MANIFEST" >/dev/null 2>&1; then IS_TRACKED=yes; fi

if [ ! -f "$MANIFEST" ] && [ "$IS_TRACKED" = no ]; then
  echo "  ⏭  SKIP: no packaging/adopt/payload-manifest.txt and none tracked —"
  echo "     this is a stripped or customer tree, where packaging/ never exists."
  echo ""
  echo "Results: $PASS/$TOTAL passed, $FAIL failed"
  exit 0
fi

assert "payload manifest exists (it is tracked, so it must be on disk)" "[ -f \"$MANIFEST\" ]"
if [ ! -f "$MANIFEST" ]; then
  echo ""; echo "Results: $PASS/$TOTAL passed, $FAIL failed"; exit 1
fi

# ── Parse ────────────────────────────────────────────────────────────────────
# Drop comments and blanks. Every surviving line must be `<verb>: <rest>`.
BODY="$(sed -e 's/[[:space:]]*$//' "$MANIFEST" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$')"

# Bare (no `::`) left-hand path for a given verb.
paths_for() {
  printf '%s\n' "$BODY" \
    | grep -E "^$1:[[:space:]]" \
    | sed -E "s/^$1:[[:space:]]*//" \
    | sed -E 's/[[:space:]]*::.*$//' \
    | sed -E 's/[[:space:]]*$//'
}

INCLUDES="$(paths_for include)"
EXCLUDES="$(paths_for exclude)"
RENAMES="$(paths_for rename)"
MERGES="$(paths_for merge)"
DEFERS="$(paths_for defer)"
AUTHORS="$(paths_for author)"

has_line() { printf '%s\n' "$1" | grep -qxF "$2"; }

echo "── 1. Grammar ──"
BAD_VERBS="$(printf '%s\n' "$BODY" | grep -vE '^(include|exclude|rename|merge|defer|author):[[:space:]]+[^[:space:]]' || true)"
assert "every non-comment line uses a known verb (include|exclude|rename|merge|defer|author)" \
  "[ -z \"\$(printf '%s' \"$BAD_VERBS\")\" ]"
# rename/merge/defer each require the ` :: ` field — same reason the strip
# manifest's `stub:` aborts without its template: the wrong default is worse
# than a hard failure.
for v in rename merge defer author; do
  MISSING="$(printf '%s\n' "$BODY" | grep -E "^$v:" | grep -v '::' || true)"
  assert "every '$v:' line carries the ':: <field>' half" "[ -z \"\$(printf '%s' \"$MISSING\")\" ]"
done
assert "at least one include: entry" "[ -n \"$INCLUDES\" ]"
assert "at least one exclude: entry" "[ -n \"$EXCLUDES\" ]"
echo ""

echo "── 2. The non-negotiable row: .github/ is excluded ──"
assert "'.github' is an exclude: entry (the directory, not a file list)" \
  "has_line \"\$EXCLUDES\" '.github'"
# Nothing may be included from under .github/ — this is the planted-violation
# check. Adding `include: .github` (or any path beneath it) turns this red.
GH_INCLUDED="$(printf '%s\n' "$INCLUDES" "$RENAMES" "$MERGES" | grep -E '^\.github(/|$)' || true)"
assert "no include:/rename:/merge: entry resolves under .github/" \
  "[ -z \"\$(printf '%s' \"$GH_INCLUDED\")\" ]"
# All five workflows must actually be covered by that exclusion.
WF_UNCOVERED=""
for wf in branch-topology-guard.yml leak-guard.yml plugin-tests.yml promote-to-main.yml release-tag.yml; do
  p=".github/workflows/$wf"
  [ -f "$ROOT/$p" ] || continue
  covered=no
  for e in $EXCLUDES; do
    case "$p" in "$e"|"$e"/*) covered=yes ;; esac
  done
  [ "$covered" = yes ] || WF_UNCOVERED="$WF_UNCOVERED $wf"
done
assert "all five .github/workflows/*.yml are covered by an exclude: entry" \
  "[ -z \"\$WF_UNCOVERED\" ]"
# The manifest must state WHY, since the reason is the whole row: nothing on the
# adopt side removes these, so the payload is the only place the exclusion can
# happen.
#
# CHANGED with PRE-13. The old assertion pinned the phrase "never runs
# /initialize-project" — a claim that turned out to be FALSE (this payload ships
# plugins/ and .claude/commands/, so the command IS in an adopter's palette) and
# that a passing test was helping keep in the file. The row's reason is the
# absence of a downstream REMOVER, not the absence of a downstream RUNNER.
assert "manifest records that no adopt-side path removes the maintainer workflows" \
  "grep -qi 'NO ADOPT-SIDE PATH REMOVES' \"$MANIFEST\""
# And it must not quietly regain the false claim.
assert "manifest does not assert an adopter never runs /initialize-project" \
  "! grep -q 'An npm adopter\$' \"$MANIFEST\""
# The skip is only SAFE because .github/ is excluded here; the manifest has to
# say so, because that is the coupling a future editor would otherwise break.
assert "manifest records that /initialize-project SKIPS its CI removal when adopted" \
  "grep -qi 'SKIPS its CI-removal step' \"$MANIFEST\""
assert "manifest names branch-topology-guard.yml as the breaking workflow" \
  "grep -q 'branch-topology-guard.yml' \"$MANIFEST\""
echo ""

echo "── 3. Other required exclusions ──"
for p in tests package.json README.md START_HERE.md TEMPLATE_INIT.md \
         KNOWN_ISSUES.md init-project.sh fix-line-endings.sh packaging; do
  assert "'$p' is excluded" "has_line \"\$EXCLUDES\" '$p'"
done
echo ""

echo "── 4. Required inclusions: the harness core ──"
for p in .logic-loom plugins .claude/hooks .claude/commands .claude/context .sdd-sync-ref; do
  assert "'$p' is included" "has_line \"\$INCLUDES\" '$p'"
done
echo ""

echo "── 5. Coherence ──"
# No path may be BOTH an include and an exclude at the same level. (An exclude
# NESTED under an include is the documented carve-out form and is fine.)
CONTRADICT=""
for i in $INCLUDES; do
  if has_line "$EXCLUDES" "$i"; then CONTRADICT="$CONTRADICT $i"; fi
done
assert "no path is both include: and exclude: at the same level" "[ -z \"\$CONTRADICT\" ]"

# Every include/rename/merge SOURCE must exist in the working tree, so a row
# cannot silently point at a path that was renamed or deleted. Globs are skipped.
MISSING_SRC=""
for p in $INCLUDES $RENAMES $MERGES $DEFERS; do
  case "$p" in *[*?]*) continue ;; esac
  [ -e "$ROOT/$p" ] || MISSING_SRC="$MISSING_SRC $p"
done
assert "every include:/rename:/merge:/defer: source exists in the tree" \
  "[ -z \"\$MISSING_SRC\" ]"

# ── `author:` rows — the harness's operating instructions ──────────────────
# Their sources resolve against the PACKAGE root (packaging/adopt/), not the
# repo root, which is the whole reason they are a separate verb. Checked here on
# that basis, so a row pointing at a path only a dev checkout has cannot pass.
PKGDIR="$(dirname "$MANIFEST")"
assert "the manifest carries author: rows for the .claude/rules/ files" "[ -n \"$AUTHORS\" ]"
MISSING_AUTHOR=""
for a in $AUTHORS; do
  [ -f "$PKGDIR/$a" ] || MISSING_AUTHOR="$MISSING_AUTHOR $a"
done
assert "every author: source exists under the package root" "[ -z \"\$MISSING_AUTHOR\" ]"
# Every author row must install under .claude/rules/ — that is the load path the
# whole decision rests on, and an author row installing elsewhere is a different
# decision wearing this one's clothes.
BAD_DST="$(printf '%s\n' "$BODY" | grep -E '^author:' | sed -E 's/.*::[[:space:]]*//' | grep -v '^\.claude/rules/' || true)"
assert "every author: row installs under .claude/rules/" "[ -z \"\$(printf '%s' \"$BAD_DST\")\" ]"
# Our OWN CLAUDE.md never ships. The rules were authored for an adopter, not
# carved out of ours; a `rename:`/`include:` of CLAUDE.md would undo that.
assert "our own CLAUDE.md is excluded, never shipped" "has_line \"\$EXCLUDES\" 'CLAUDE.md'"
CLAUDE_SHIPPED="$(printf '%s\n' "$INCLUDES" "$RENAMES" | grep -xF 'CLAUDE.md' || true)"
assert "no include:/rename: row ships our CLAUDE.md" "[ -z \"\$(printf '%s' \"$CLAUDE_SHIPPED\")\" ]"
# The integration modes are a product decision and must stay reviewable HERE,
# in the file the maintainer edits to overrule the boundary.
for m in rules import none; do
  assert "the manifest names the '$m' integration mode" "grep -qE '^#   $m' \"$MANIFEST\""
done
assert "the manifest names the non-interactive selector" \
  "grep -q 'LOOM_ADOPT_CLAUDE_MD' \"$MANIFEST\" && grep -q -- '--claude-md' \"$MANIFEST\""
assert "the manifest records that .claude/rules/ is invisible to build-graph-bridge.sh" \
  "grep -q 'build-graph-bridge.sh' \"$MANIFEST\""

# A `defer:` is an unresolved decision. It must be visible, not silent: the
# manifest has to say the installer refuses to run while one stands.
if [ -n "$DEFERS" ]; then
  assert "manifest states the installer refuses to run while a defer: stands" \
    "grep -qi 'installer must refuse' \"$MANIFEST\""
fi
echo ""

echo "── 6. packaging/ is maintainer-only on BOTH sides ──"
assert "template-strip-manifest.txt carries the 'packaging' strip entry" \
  "grep -qx 'packaging' \"$STRIP_MANIFEST\""
assert "the payload manifest itself lives under packaging/" \
  "case \"$MANIFEST\" in */packaging/*) true ;; *) false ;; esac"
echo ""

echo "── 7. PRE-12 Node floor note ──"
assert "manifest carries a Node-floor note for the publish workflow" \
  "grep -qi 'trusted publishing' \"$MANIFEST\""
# The note was UNVERIFIED; it is now VERIFIED 2026-08-27 against the primary
# source. The assertion's job is unchanged in kind: stop the note being quietly
# PROMOTED to unsourced fact, and stop it quietly ROTTING once npm moves the
# floor. So it now pins that the claim is dated, sourced, and re-checkable.
assert "the Node floor carries a VERIFIED date, not a bare claim" \
  "grep -qE 'VERIFIED [0-9]{4}-[0-9]{2}-[0-9]{2}' \"$MANIFEST\""
assert "the exact floor figures survive" \
  "grep -q '22.14.0' \"$MANIFEST\" && grep -q '11.5.1' \"$MANIFEST\""
assert "the source URL is recorded" \
  "grep -q 'docs.npmjs.com/trusted-publishers' \"$MANIFEST\""
assert "a re-check command survives so the note cannot rot silently" \
  "grep -q 'curl -s https://docs.npmjs.com/trusted-publishers' \"$MANIFEST\""
assert "the GitHub-hosted-runner constraint is recorded" \
  "grep -qi 'self-hosted' \"$MANIFEST\""
assert "the note warns publish-adopt.yml needs its own setup-node" \
  "grep -q 'setup-node' \"$MANIFEST\""
echo ""

echo "── .brain/README.md ships: structure travels, content does not ──"
# The adopter got NOTHING under .brain/ because it was excluded "defensively as
# our record" — but the strip manifest had already reduced .brain/ to a stubbed
# README before the payload ever saw the tree, so the exclusion threw away safe
# STRUCTURE. Meanwhile initialize-project.md instructs the agent that ".brain/
# keeps just its README.md", a file the npm path never installed.
#
# BOTH lines are asserted because removing the exclusion alone ships nothing:
# the copier selects a path only when an `include:` matches it, and no include
# covered .brain. Verified against the real assembler — 276 files before, 277
# after.
assert ".brain/README.md is explicitly included in the payload" \
  "grep -qE '^include:[[:space:]]+\.brain/README\.md[[:space:]]*$' \"$MANIFEST\""
assert "...and .brain is NOT excluded, which would beat that include" \
  "! grep -qE '^exclude:[[:space:]]+\.brain[[:space:]]*$' \"$MANIFEST\""
# The content must stay ours. Only the README may be named; a future include of
# raw/, wiki/, index/ or memory/ would ship a knowledge base to a stranger.
assert "no .brain path other than README.md is included" \
  "! grep -E '^include:[[:space:]]+\.brain/' \"$MANIFEST\" | grep -qv 'README\.md'"
echo ""

echo "── The smoke-test brief must never ship to an adopter ──"
# Not a style rule — shipping it breaks the test it describes. The brief's
# section 5a probes a fresh session with a governance question to find out
# whether `.claude/rules/` loaded, and the brief states the correct answer.
# Installed under `.docs/guides/`, it lands inside the loom-memory search scope
# that governance-preflight.sh injects on every prompt, so the probe can be
# answered from the injected answer key with rules never loading — a false PASS
# on the one question `--claude-md=rules` exists to settle. `.docs/guides` is an
# include:, so only an explicit exclude: keeps it out.
assert "adopt-smoke-test.md is excluded from the payload" \
  "grep -qE '^exclude:[[:space:]]+\.docs/guides/adopt-smoke-test\.md[[:space:]]*$' \"$MANIFEST\""
assert "the exclusion carries its reason, so nobody deletes it as redundant" \
  "grep -qi 'rules.*load\|answer key\|false PASS' \"$MANIFEST\""
echo ""

echo "── artifacts/ ships: structure travels, content does not (LOOM-0049) ──"
# Same shape as the .brain/README.md block above, and for the identical reason:
# BOTH halves are required. Removing the exclusion alone ships nothing (the
# copier selects a path only when an include: matches it); the include alone
# would select nothing if template-strip-manifest.txt still removed the whole
# `artifacts` directory (it no longer does — see that manifest's own LOOM-0049
# comment for why the wholesale form had to become per-file).
assert "artifacts/.gitkeep is explicitly included in the payload" \
  "grep -qE '^include:[[:space:]]+artifacts/\.gitkeep[[:space:]]*\$' \"$MANIFEST\""
assert "artifacts/README.md is explicitly included in the payload" \
  "grep -qE '^include:[[:space:]]+artifacts/README\.md[[:space:]]*\$' \"$MANIFEST\""
assert "...and artifacts (the whole directory) is NOT excluded, which would beat those includes" \
  "! grep -qE '^exclude:[[:space:]]+artifacts[[:space:]]*\$' \"$MANIFEST\""
# The content must stay ours. Each of our three own artifact pages is excluded
# individually; a fourth path under artifacts/ appearing here unexcluded would
# be a new LogicLoom-authored page shipping to a customer unnoticed.
for _f in backlog-dashboard.html harness-graph.html logicloom-vision.html; do
  assert "artifacts/$_f is explicitly excluded from the payload" \
    "grep -qE '^exclude:[[:space:]]+artifacts/$_f[[:space:]]*\$' \"$MANIFEST\""
done
echo ""

echo "── check-generated-freshness.sh now SHIPS to the adopt package (LOOM-0049) ──"
# It used to be excluded because the adopter had no source for what it
# regenerates. That reason expired: todos.md, backlog.md and both backlog
# generators all ship now, so the gate has every input it needs.
assert "check-generated-freshness.sh is NOT excluded from the payload" \
  "! grep -qE '^exclude:[[:space:]]+\.logic-loom/scripts/bash/check-generated-freshness\.sh[[:space:]]*\$' \"$MANIFEST\""
assert "the manifest records WHY it now ships (the reason expired, not just deleted silently)" \
  "grep -qi 'expired' \"$MANIFEST\" && grep -q 'check-generated-freshness.sh' \"$MANIFEST\""
echo ""

echo "========================================"
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
