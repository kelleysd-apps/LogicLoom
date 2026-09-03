#!/usr/bin/env bash
# Contract Tests: no SHIPPED file cites a documentation path the adopt
# payload EXCLUDES (GitHub #81, #85 — the recurring defect class)
#
# ─────────────────────────────────────────────────────────────────────────────
# THE INVARIANT
# ─────────────────────────────────────────────────────────────────────────────
# packaging/adopt/payload-manifest.txt decides what the adopt package installs
# into someone else's repo. When a file the payload DOES ship names a doc path
# the payload EXCLUDES, an adopter following that reference gets sent to a file
# they do not have. This has been fixed one instance at a time (#81, #85) and
# keeps coming back because nothing gated the CLASS — only individual
# instances got noticed and patched.
#
# ─────────────────────────────────────────────────────────────────────────────
# THE DESIGN CONSTRAINT — READ THIS BEFORE TOUCHING THE REGEX BELOW
# ─────────────────────────────────────────────────────────────────────────────
# A naive grep for "any excluded path substring" produces a false-positive
# flood and would block every future release. Most references to an excluded
# path are RUNTIME WRITE TARGETS, not citations:
#   - `.docs/governance/audit/` is CREATED by hooks at runtime (`AUDIT_DIR=...`,
#     `mkdir -p`) — appears in >=6 shipped files. Not a defect.
#   - `.docs/memory/search-log.jsonl` is WRITTEN by
#     plugins/loom-memory/scripts/memory-log.sh. Not a defect.
#   - `.docs/archive/` shows up as `MEMORY_TIER_ARCHIVAL=` in architecture.conf.
#     Not a defect.
#
# THE FIX: flag ONLY references to a `.md` DOCUMENT under an excluded path. A
# document citation promises the reader a file to open; a directory or
# data-file path is somewhere the tool writes. This is enforced structurally —
# the extraction regex (see checker.js's MD_TOKEN below) requires a `.md`
# suffix AND a `/`, so a directory or a `.jsonl`/`.json`/config path can never
# even reach the exclude check. DO NOT loosen that regex "to catch more" —
# that reintroduces exactly the flood this test exists to avoid.
#
# A SECOND, narrower filter applies only to which *manifest exclude entries*
# participate: WILDCARD excludes (`features/*/`, `specs/*/`) are dropped from
# the citation check (though NOT from the shipped-file-set computation, where
# they still correctly prune what ships). A wildcard exclude removes an entire
# CATEGORY of adopter-owned per-instance content, not one specific payload
# document — a prose path matching that pattern (`specs/001-feature/spec.md`)
# is an illustrative example of the naming convention, not a promise to open a
# file the payload shipped. Verified empirically against this repo before
# adopting the rule: every current match against a wildcard exclude was a
# placeholder name (`foo`, `auth`, `001-feature`, `code-knowledge-graph`, ...).
#
# ─────────────────────────────────────────────────────────────────────────────
# MECHANISM
# ─────────────────────────────────────────────────────────────────────────────
#   1. Parse payload-manifest.txt via its own reference implementation,
#      packaging/adopt/lib/manifest.js (`load` + `isExcluded`) — never a
#      hand-rolled second copy of the grammar.
#   2. Determine the SHIPPED set via the planner
#      (`packaging/adopt/bin/logicloom.js init . --json`), which reports
#      DIRECTORY units, not every file: a path is shipped if it or an ancestor
#      directory was selected (bucket additive/keep-theirs/replace, granularity
#      "path") and no exclude covers it. NOTE: the planner exits 1 on THIS repo
#      because it reports the "ALREADY-ADOPTED" blocking precondition — it
#      still emits a complete, valid plan on stdout, so the helper below reads
#      stdout regardless of the planner's own exit code.
#   3. For each shipped file, extract `.md` path tokens and check each against
#      the manifest's exclude entries (literal ones only, per the wildcard
#      rule above).
#   4. FAIL, listing file:line and the offending path, when any survive.
#
# An ALLOWLIST (below) exists for a confirmed false positive: an entry must
# carry a one-line reason, and one is seeded here only because empirical
# inspection (reading the actual line, not guessing) showed it is not a
# citation — see each entry's comment. Never add an entry to hide a real
# violation.
#
# bash 3.2 safe: no associative arrays, no `${x^^}`, no `mapfile`, no `&>>`.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

MANIFEST_LIB="$ROOT/packaging/adopt/lib/manifest.js"
MANIFEST_FILE="$ROOT/packaging/adopt/payload-manifest.txt"
PLANNER_BIN="$ROOT/packaging/adopt/bin/logicloom.js"

echo "═══ Shipped-Path-References Contract Tests (adopt payload) ═══"
echo ""

# ── Vacuously green on a stripped tree, FAIL-CLOSED on rot ───────────────────
# `packaging` is a template-strip-manifest entry (payload-manifest.txt's own
# header: "THIS FILE IS MAINTAINER-ONLY... nothing under packaging/ ever
# reaches a customer or an adopter"), so on any shipped/customer tree
# packaging/adopt simply does not exist — there is no payload to check. Same
# shape and reason as test_adopt_payload_manifest.sh's own guard: an
# absent-and-untracked manifest is a legitimate skip; absent-but-TRACKED means
# it was deleted out from under the boundary, and that still fails.
IS_TRACKED=no
if git -C "$ROOT" ls-files --error-unmatch "$MANIFEST_FILE" >/dev/null 2>&1; then IS_TRACKED=yes; fi

if [ ! -f "$MANIFEST_FILE" ] && [ "$IS_TRACKED" = no ]; then
  echo "  ⏭  SKIP: no packaging/adopt/payload-manifest.txt and none tracked —"
  echo "     this is a stripped or customer tree, where packaging/ never exists."
  echo ""
  echo "Results: $PASS/$TOTAL passed, $FAIL failed"
  exit 0
fi

assert "manifest.js exists" "[ -f \"\$MANIFEST_LIB\" ]"
assert "payload-manifest.txt exists" "[ -f \"\$MANIFEST_FILE\" ]"
assert "adopt planner exists" "[ -f \"\$PLANNER_BIN\" ]"
assert "node is available" "command -v node >/dev/null 2>&1"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "════════════════════════════════"
  echo " Results: $PASS/$TOTAL passed, $FAIL failed"
  echo "❌ SOME TESTS FAILED (prerequisites missing)"
  exit 1
fi

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/loom-shipped-path-test.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ─────────────────────────────────────────────────────────────────────────
# The checker itself. Written out at run time (not committed) so this test
# file — the only artifact this suite owns — stays the single source of the
# logic. Reads packaging/adopt/lib/manifest.js as a library; never modifies
# it, never modifies the manifest.
# ─────────────────────────────────────────────────────────────────────────
CHECKER="$WORKDIR/checker.js"
cat > "$CHECKER" <<'NODE_EOF'
#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const REPO_ROOT = process.env.REPO_ROOT;
const MANIFEST_FILE = process.env.MANIFEST_FILE;
const MANIFEST_LIB = process.env.MANIFEST_LIB;
const SHIPPED_LIST_FILE = process.env.SHIPPED_LIST_FILE || '';
const PLANNER_BIN = process.env.PLANNER_BIN || '';
const ALLOWLIST_FILE = process.env.ALLOWLIST_FILE || '';

if (!REPO_ROOT || !MANIFEST_FILE || !MANIFEST_LIB) {
  console.error('checker.js: missing required env vars (REPO_ROOT, MANIFEST_FILE, MANIFEST_LIB)');
  process.exit(2);
}

const manifestLib = require(MANIFEST_LIB);
const parsed = manifestLib.load(MANIFEST_FILE);

// Narrower exclude set for the CITATION check only (see the header comment in
// the .sh wrapper for why wildcard excludes are dropped here but not from the
// shipped-set computation below).
const literalParsed = Object.assign({}, parsed, {
  excludes: parsed.excludes.filter((e) => e.path.indexOf('*') === -1),
});

function gitLsFiles(dir) {
  try {
    const out = cp.execFileSync('git', ['-C', REPO_ROOT, 'ls-files', '--', dir], { encoding: 'utf8' });
    return out.split('\n').filter(Boolean);
  } catch (e) {
    return [];
  }
}

let shippedFiles = [];
if (SHIPPED_LIST_FILE) {
  shippedFiles = fs.readFileSync(SHIPPED_LIST_FILE, 'utf8').split('\n').map((s) => s.trim()).filter(Boolean);
} else {
  // The planner exits non-zero whenever it reports a BLOCKING precondition
  // (e.g. ALREADY-ADOPTED, which THIS repo always is) even though it still
  // emits a complete, valid plan on stdout — `--json` is a report mode, not a
  // success/failure signal. Read stdout regardless of exit status; only fail
  // if that stdout is not parseable JSON.
  const bin = PLANNER_BIN || path.join(REPO_ROOT, 'packaging/adopt/bin/logicloom.js');
  const res = cp.spawnSync('node', [bin, 'init', REPO_ROOT, '--json'], { encoding: 'utf8', maxBuffer: 50 * 1024 * 1024 });
  if (res.error) {
    console.error('checker.js: failed to run planner: ' + res.error.message);
    process.exit(2);
  }
  let plan;
  try {
    plan = JSON.parse(res.stdout);
  } catch (e) {
    console.error('checker.js: planner did not emit valid JSON (exit ' + res.status + '): ' + e.message);
    process.exit(2);
  }

  // DIRECTORY units, not every file: a `dir` unit means every git-tracked
  // file beneath it ships UNLESS an exclude covers that specific descendant.
  // additive + keep-theirs + replace together are every unit the payload
  // would place, regardless of whether the diff target already has a copy.
  const roots = [];
  for (const bucket of ['additive', 'keep-theirs', 'replace']) {
    for (const u of (plan.buckets[bucket] || [])) {
      if (u.granularity === 'path' && (u.kind === 'file' || u.kind === 'dir')) {
        roots.push(u);
      }
    }
  }
  const seen = {};
  for (const u of roots) {
    const rel = u.sourcePath;
    if (u.kind === 'file') {
      if (!manifestLib.isExcluded(parsed, rel, false) && !seen[rel]) {
        seen[rel] = true;
        shippedFiles.push(rel);
      }
      continue;
    }
    const files = gitLsFiles(rel);
    for (const f of files) {
      if (manifestLib.isExcluded(parsed, f, false)) continue;
      if (!seen[f]) { seen[f] = true; shippedFiles.push(f); }
    }
  }
}

// ALLOWLIST_FILE: lines of "relFile::citedToken" — scoped to a specific
// (file, token) PAIR, not a bare token, so allowlisting one confirmed false
// positive can never blind the gate to a genuine citation of the same path
// from a DIFFERENT file.
let allow = [];
if (ALLOWLIST_FILE && fs.existsSync(ALLOWLIST_FILE)) {
  allow = fs.readFileSync(ALLOWLIST_FILE, 'utf8').split('\n').map((s) => s.trim()).filter(Boolean);
}

// A repo-relative-looking path token ending in `.md`, containing at least one
// `/` (so a bare mention like "the README.md file" never matches). The `.md`
// suffix requirement is what keeps this off runtime write targets BY
// CONSTRUCTION: a directory (`.docs/governance/audit`) or a data file
// (`*.jsonl`) never matches this pattern, so it never reaches the exclude
// check at all.
const MD_TOKEN = /[A-Za-z0-9_.\/-]*\/[A-Za-z0-9_.-]+\.md/g;

const findings = [];
for (const relFile of shippedFiles) {
  const abs = path.join(REPO_ROOT, relFile);
  let content;
  try {
    content = fs.readFileSync(abs, 'utf8');
  } catch (e) {
    continue;
  }
  const lines = content.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    MD_TOKEN.lastIndex = 0;
    let m;
    while ((m = MD_TOKEN.exec(line))) {
      const token = m[0].replace(/^\.\//, '');
      const key = relFile + '::' + token;
      if (allow.indexOf(key) !== -1) continue;
      const hit = manifestLib.isExcluded(literalParsed, token, false);
      if (hit) {
        findings.push(relFile + ':' + (i + 1) + ': ' + token + '  [excluded by manifest line ' + hit.lineNo + ': "' + hit.path + '"]');
      }
    }
  }
}

if (process.env.CHECKER_DEBUG) {
  console.error('shipped file count: ' + shippedFiles.length);
}

if (findings.length) {
  findings.forEach((f) => console.log(f));
  process.exit(1);
}
process.exit(0);
NODE_EOF

# ─────────────────────────────────────────────────────────────────────────
# ALLOWLIST — one entry per confirmed false positive, each with a reason.
# All seven were read in place (not guessed) before being added here. Do
# not add an entry to make a real finding disappear.
# ─────────────────────────────────────────────────────────────────────────
ALLOWLIST_KEYS=(
  ".logic-loom/adapters/HOSTS.md::.github/copilot-instructions.md"
  ".logic-loom/scripts/bash/check-dev-branch-base.sh::.docs/guides/dev-main-template-split.md"
  ".logic-loom/scripts/bash/history-scrub-rules.json::.docs/plans/loom-migration.md"
  ".logic-loom/scripts/bash/history-scrub-rules.json::.docs/governance/browser-automation-examples.md"
  ".logic-loom/scripts/bash/history-scrub-rules.json::.docs/governance/browser-mcp-setup.md"
  ".logic-loom/scripts/bash/template-strip-manifest.txt::.docs/guides/dev-main-template-split.md"
  ".logic-loom/scripts/bash/template-strip-manifest.txt::.github/pull_request_template.md"
  ".logic-loom/scripts/bash/history-scrub-rules.json::.docs/governance/hybrid-architecture.md"
  ".logic-loom/memory/backlog.md::.docs/reports/backlog-2026-08-13.md"
  ".docs/architecture/model-selection-policy.md::.docs/governance/hybrid-architecture.md"
  ".docs/architecture/model-selection-policy.md::.docs/governance/hybrid-architecture.md"
)
ALLOWLIST_REASONS=(
  "HOSTS.md's table names GitHub Copilot's OWN config-file convention (.github/copilot-instructions.md is Copilot's file, not a LogicLoom document); it is not a citation of a payload doc"
  "guarded by 'if [ -f \"\$ROOT/\$SPLIT_GUIDE\" ]' before the script cites it — the script's own comment states the citation is conditional and never fires against a sanitized adopter clone"
  "git-history scrub rule: the path sits inside a 'match' field quoting OLD commit text slated for deletion from history, not a live citation"
  "git-history scrub rule 'path' key naming which file the scrub ops apply to — metadata for a different process (history scrubbing), not a citation"
  "git-history scrub rule 'path' key naming which file the scrub ops apply to — metadata for a different process (history scrubbing), not a citation"
  "template-strip-manifest.txt entry: a DIFFERENT manifest listing what the maintainer-only template-release process removes, not a reader-facing citation"
  "template-strip-manifest.txt entry: same as above — strip-manifest metadata, not a citation"
  "git-history scrub rule 'path' key naming which file the scrub ops apply to — metadata for the history-scrub process, not a citation"
  "the SHIPPED backlog.md is not this file: template-strip-manifest.txt:74 stubs it from project-backlog-template.md, so the release replaces it. Verified against the v6.6.2 payload: zero occurrences of this token in the shipped copy"
  "maintainer bump touch-list. The two rows are now annotated in place as (LogicLoom repository only — not part of the adopt payload), so the reference no longer promises an adopter a file they lack; it tells them it is ours"
  "same row-pair as above, in the same touch-list table"
)
ALLOWLIST_FILE="$WORKDIR/allowlist.txt"
: > "$ALLOWLIST_FILE"
i=0
while [ "$i" -lt "${#ALLOWLIST_KEYS[@]}" ]; do
  printf '%s\n' "${ALLOWLIST_KEYS[$i]}" >> "$ALLOWLIST_FILE"
  i=$((i + 1))
done

run_checker() {
  # env: REPO_ROOT MANIFEST_FILE MANIFEST_LIB [SHIPPED_LIST_FILE] [PLANNER_BIN] [ALLOWLIST_FILE]
  node "$CHECKER"
}

# ═══════════════════════════════════════════════════════════════════════════
# A. THE GATE CAN FAIL — a fixture with a genuine violation must be caught
# ═══════════════════════════════════════════════════════════════════════════
echo "A. The gate can fail (fixture with a genuine excluded-doc citation)"

FIXTURE_A="$WORKDIR/fixture-a"
mkdir -p "$FIXTURE_A/shipped"
cat > "$FIXTURE_A/manifest.txt" <<'EOF'
include: shipped
exclude: docs/fake-excluded.md
EOF
cat > "$FIXTURE_A/shipped/fake-shipper.sh" <<'EOF'
#!/usr/bin/env bash
# See docs/fake-excluded.md for details on this made-up thing.
echo hi
EOF
printf '%s\n' "shipped/fake-shipper.sh" > "$FIXTURE_A/shipped-list.txt"

A_OUT="$WORKDIR/a.out"
(
  REPO_ROOT="$FIXTURE_A" \
  MANIFEST_FILE="$FIXTURE_A/manifest.txt" \
  MANIFEST_LIB="$MANIFEST_LIB" \
  SHIPPED_LIST_FILE="$FIXTURE_A/shipped-list.txt" \
  run_checker
) > "$A_OUT" 2>&1
A_EXIT=$?

assert "fixture A: gate exits non-zero on a genuine violation" "[ $A_EXIT -eq 1 ]"
assert "fixture A: gate reports file:line for the violation" \
  "grep -qF 'shipped/fake-shipper.sh:2: docs/fake-excluded.md' '$A_OUT'"

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# B. THE GATE IGNORES RUNTIME WRITE TARGETS — zero findings
# ═══════════════════════════════════════════════════════════════════════════
echo "B. The gate ignores runtime write targets (dirs, .jsonl, non-.md paths)"

FIXTURE_B="$WORKDIR/fixture-b"
mkdir -p "$FIXTURE_B/shipped"
cat > "$FIXTURE_B/manifest.txt" <<'EOF'
include: shipped
exclude: .docs/governance/audit
exclude: .docs/memory
exclude: docs/really-excluded.md
EOF
cat > "$FIXTURE_B/shipped/hook.sh" <<'EOF'
#!/usr/bin/env bash
AUDIT_DIR="$REPO_ROOT/.docs/governance/audit"
mkdir -p "$AUDIT_DIR"
LOG_FILE=".docs/memory/search-log.jsonl"
echo "wrote to $LOG_FILE"
# a non-excluded doc citation, for contrast — must also be zero findings
echo "see docs/policies/example.md for background"
EOF
printf '%s\n' "shipped/hook.sh" > "$FIXTURE_B/shipped-list.txt"

B_OUT="$WORKDIR/b.out"
(
  REPO_ROOT="$FIXTURE_B" \
  MANIFEST_FILE="$FIXTURE_B/manifest.txt" \
  MANIFEST_LIB="$MANIFEST_LIB" \
  SHIPPED_LIST_FILE="$FIXTURE_B/shipped-list.txt" \
  run_checker
) > "$B_OUT" 2>&1
B_EXIT=$?

assert "fixture B: gate exits zero — write targets are not citations" "[ $B_EXIT -eq 0 ]"
assert "fixture B: gate reports nothing" "[ ! -s '$B_OUT' ]"

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# C. AGAINST THE REAL REPO
# ═══════════════════════════════════════════════════════════════════════════
echo "C. Against the real repo — FAIL-CLOSED: any finding fails this suite"

C_OUT="$WORKDIR/c.out"
(
  REPO_ROOT="$ROOT" \
  MANIFEST_FILE="$MANIFEST_FILE" \
  MANIFEST_LIB="$MANIFEST_LIB" \
  PLANNER_BIN="$PLANNER_BIN" \
  ALLOWLIST_FILE="$ALLOWLIST_FILE" \
  run_checker
) > "$C_OUT" 2>&1
C_EXIT=$?

if [ "$C_EXIT" -eq 0 ]; then
  echo "     ✅ no shipped file cites an excluded document"
elif [ "$C_EXIT" -eq 1 ]; then
  echo "     ⚠️  findings against the CURRENT repo state (see run notes below):"
  sed 's/^/       /' "$C_OUT"
else
  echo "     ❌ checker errored (exit $C_EXIT) — see output:"
  sed 's/^/       /' "$C_OUT"
fi
assert "real-repo run completed (not a checker error)" "[ $C_EXIT -eq 0 ] || [ $C_EXIT -eq 1 ]"
# FAIL-CLOSED. A gate that reports violations without failing on them is not a
# gate. Every finding is either fixed or carries an allowlist entry with a
# verified reason; a NEW one must break the build rather than scroll past.
assert "no shipped file cites an excluded document (zero findings)" "[ $C_EXIT -eq 0 ]"

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
