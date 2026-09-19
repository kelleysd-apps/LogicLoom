#!/usr/bin/env bash
# Contract Tests: the adopted-repo rot gap (v7.0.0 WP4)
#
# THE GAP: a file first ADDED through /update-framework (a `clean-add`) is
# never recorded into .logicloom-adopt-receipt.json — `apply.js` writes the
# receipt only at install time; /update-framework never writes to it at all.
# extract-proposals.sh's ownership filter (`adopt_file_recorded` /
# `adopt_offer_added_path`) only offers an M|D|R* proposal, or an A proposal
# under a recorded ancestor directory, for a path the receipt says THIS
# repo's own tooling wrote. So the file's next upstream edit — and any new
# file later added under a directory an update-added file created — is
# silently suppressed as "not installed here" forever.
#
# This suite proves the gap exists on today's code (the assertions in
# section A pass without plugins/loom-maintenance/scripts/record-update-writes.sh
# existing at all — they pin the MECHANISM, not the fix), then proves the fix
# closes it: record-update-writes.sh (new) plus the one extract-proposals.sh
# stderr change (sections B–H) all fail until both are implemented.
#
# Sourcing pattern (as tests/contract/test_update_framework_adopted.sh:24-28
# does): the real extract-proposals.sh is SOURCED into a subshell with
# REPO_ROOT repointed at a throwaway fixture; its main block is guarded by
# `[ "${BASH_SOURCE[0]}" = "${0}" ]`, so sourcing never runs --dry-run/network
# I/O. Every fixture is a real, throwaway git repo built INSIDE this script
# (the sanctioned pattern: `git init/add/commit/checkout/reset` inside a test
# process are not visible to, and not run by, the agent-side git guard —
# this file is executed as `bash tests/contract/test_update_framework_ownership.sh`).
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}, no &>>.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0; SKIP=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}
skip() { SKIP=$((SKIP + 1)); echo "  ⏭  SKIP: $1 — $2"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if REAL_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  REAL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
EXTRACT_SCRIPT="$REAL_ROOT/plugins/loom-maintenance/scripts/extract-proposals.sh"
RECORDER_SCRIPT="$REAL_ROOT/plugins/loom-maintenance/scripts/record-update-writes.sh"

echo "═══ Adopted-Repo Ownership Contract Tests (the update-framework rot gap) ═══"
echo ""

assert "extract-proposals.sh exists" "[ -f \"\$EXTRACT_SCRIPT\" ]"
if [ ! -f "$EXTRACT_SCRIPT" ]; then
  echo ""
  echo "════════════════════════════════"
  echo " Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
  echo "❌ SOME TESTS FAILED"
  exit 1
fi
# record-update-writes.sh is NOT required to exist for section A (the gap,
# proven) to run and pass -- that section pins today's mechanism using only
# extract-proposals.sh. Every assertion from section C onward that actually
# invokes the recorder legitimately FAILS (not errors out) when it is
# missing: `bash "$RECORDER_SCRIPT" ...` on a nonexistent path just fails,
# and this script has no `set -e` at top level, so it keeps going and still
# prints an honest Results line.
assert "record-update-writes.sh exists" "[ -f \"\$RECORDER_SCRIPT\" ]"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/loom-ownership-test.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ─────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────

sha256_of() {
  python3 -c "
import hashlib, sys
print('sha256:' + hashlib.sha256(open(sys.argv[1], 'rb').read()).hexdigest())
" "$1"
}

# rc 0 + prints the resolution if $2 (upstream_file) appears in the proposals
# JSON array at $1; rc 1 if it does not appear at all.
proposals_resolution() {
  python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
for p in data:
    if p.get('upstream_file') == sys.argv[2]:
        print(p.get('resolution', ''))
        sys.exit(0)
sys.exit(1)
" "$1" "$2"
}

proposal_present() {
  python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
sys.exit(0 if any(p.get('upstream_file') == sys.argv[2] for p in data) else 1)
" "$1" "$2"
}

json_runs_count() {
  python3 -c "
import json, sys
print(len(json.load(open(sys.argv[1]))['runs']))
" "$1"
}

json_run_field() {
  # $1 = receipt path, $2 = run index, $3 = field
  python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
v = d['runs'][int(sys.argv[2])][sys.argv[3]]
print(v if isinstance(v, str) else json.dumps(v))
" "$1" "$2" "$3"
}

json_run_wrote_file_paths_sorted() {
  # $1 = receipt path, $2 = run index -- comma-joined, sorted "path" of every
  # kind:file entry in that run (dir entries excluded)
  python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
print(','.join(sorted(w['path'] for w in d['runs'][int(sys.argv[2])]['wrote'] if w.get('kind') == 'file')))
" "$1" "$2"
}

json_run_wrote_sha() {
  # $1 = receipt path, $2 = run index, $3 = path -- prints its sha256 (or nothing)
  python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
for w in d['runs'][int(sys.argv[2])]['wrote']:
    if w['path'] == sys.argv[3]:
        print(w.get('sha256', ''))
" "$1" "$2" "$3"
}

json_run_has_dir_entry() {
  # $1 = receipt path, $2 = run index, $3 = dir path (with trailing slash)
  python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
paths = [w['path'] for w in d['runs'][int(sys.argv[2])]['wrote'] if w.get('kind') == 'dir']
print('yes' if sys.argv[3] in paths else 'no')
" "$1" "$2" "$3"
}

json_snapshot() {
  # $1 = receipt path, $2 = top-level key -- deterministic string snapshot
  python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
print(json.dumps(d.get(sys.argv[2]), sort_keys=True))
" "$1" "$2"
}

json_all_recorded_file_paths() {
  python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
paths = set()
for r in d['runs']:
    for w in r.get('wrote', []):
        if w.get('kind') == 'file':
            paths.add(w['path'])
print(','.join(sorted(paths)))
" "$1"
}

# ─────────────────────────────────────────────────────────────────────────
# Fixture builders
# ─────────────────────────────────────────────────────────────────────────

# Builds the linear upstream history A -> B -> C described in the package
# brief, then resets the working tree/HEAD back to A (downstream starts
# un-updated). Sets globals MAIN_SHA_A / MAIN_SHA_B / MAIN_SHA_C. Leaves a
# usable receipt recording only A's paths, and .sdd-sync-ref = A.
build_main_fixture() {
  local dir="$1"
  mkdir -p "$dir/.logic-loom/scripts/bash" "$dir/.logic-loom/config" \
           "$dir/plugins/loom-git/commands" "$dir/.logic-loom/newdir"
  (
    cd "$dir"
    git init -q
    git config user.email test@example.com
    git config user.name Test
    echo "a-content" > .logic-loom/scripts/bash/a.sh
    echo "x-content" > plugins/loom-git/commands/x.md
    printf 'FRAMEWORK_VERSION=6.6.2\n' > .logic-loom/config/architecture.conf
    git add -A
    git commit -q -m "A: upstream baseline"
  )
  MAIN_SHA_A="$(git -C "$dir" rev-parse HEAD)"

  (
    cd "$dir"
    echo "b1-content" > .logic-loom/scripts/bash/b.sh
    echo "c1-content" > .logic-loom/scripts/bash/c.sh
    echo "n1-content" > .logic-loom/newdir/n.sh
    git add -A
    git commit -q -m "B: upstream adds b.sh, c.sh, n.sh"
  )
  MAIN_SHA_B="$(git -C "$dir" rev-parse HEAD)"

  (
    cd "$dir"
    echo "b2-modified-content" > .logic-loom/scripts/bash/b.sh
    echo "m1-content" > .logic-loom/newdir/m.sh
    git add -A
    git commit -q -m "C: upstream modifies b.sh, adds m.sh"
  )
  MAIN_SHA_C="$(git -C "$dir" rev-parse HEAD)"

  # Downstream has not accepted anything past A yet.
  git -C "$dir" reset -q --hard "$MAIN_SHA_A"

  local sha_a sha_x sha_conf
  sha_a="$(sha256_of "$dir/.logic-loom/scripts/bash/a.sh")"
  sha_x="$(sha256_of "$dir/plugins/loom-git/commands/x.md")"
  sha_conf="$(sha256_of "$dir/.logic-loom/config/architecture.conf")"
  cat > "$dir/.logicloom-adopt-receipt.json" <<JSON
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-08-31T00:00:00.000Z",
      "generator": "logicloom@6.6.1",
      "status": "complete",
      "wrote": [
        {"target": "harness", "path": ".logic-loom/", "kind": "dir"},
        {"target": "harness", "path": ".logic-loom/scripts/", "kind": "dir"},
        {"target": "harness", "path": ".logic-loom/scripts/bash/", "kind": "dir"},
        {"target": "harness", "path": ".logic-loom/config/", "kind": "dir"},
        {"target": "harness", "path": "plugins/", "kind": "dir"},
        {"target": "harness", "path": "plugins/loom-git/", "kind": "dir"},
        {"target": "harness", "path": "plugins/loom-git/commands/", "kind": "dir"},
        {"target": "harness", "path": ".logic-loom/scripts/bash/a.sh", "kind": "file", "sha256": "$sha_a"},
        {"target": "harness", "path": "plugins/loom-git/commands/x.md", "kind": "file", "sha256": "$sha_x"},
        {"target": "harness", "path": ".logic-loom/config/architecture.conf", "kind": "file", "sha256": "$sha_conf"}
      ],
      "skipped": [],
      "failed": [],
      "notAttempted": []
    }
  ],
  "uninstall": {"marker": "left as is"}
}
JSON
  echo "$MAIN_SHA_A" > "$dir/.sdd-sync-ref"
}

# Separate, smaller fixture for --reconcile: A -> B, downstream accepted
# b.sh, c.sh AND .logic-loom/newdir/n.sh (copied to match B) but recorded
# NONE of them; c.sh was then edited locally, so it no longer matches the
# sync-ref blob. n.sh sits under a directory the receipt never recorded —
# the "directory created by an accepted add" half of the gap. Upstream
# commit C then adds .logic-loom/newdir/m.sh, so the suite can assert that
# a reconcile which records n.sh ALSO records newdir/ and thereby lets m.sh
# through the ancestor rule. Sets RECON_SHA_B / RECON_SHA_C.
build_reconcile_fixture() {
  local dir="$1"
  mkdir -p "$dir/.logic-loom/scripts/bash" "$dir/plugins/loom-git/commands" \
           "$dir/.logic-loom/config" "$dir/.logic-loom/newdir"
  (
    cd "$dir"
    git init -q
    git config user.email test@example.com
    git config user.name Test
    echo "a-content" > .logic-loom/scripts/bash/a.sh
    echo "x-content" > plugins/loom-git/commands/x.md
    printf 'FRAMEWORK_VERSION=6.6.2\n' > .logic-loom/config/architecture.conf
    git add -A
    git commit -q -m "A"
  )
  local sha_b
  (
    cd "$dir"
    echo "b-original" > .logic-loom/scripts/bash/b.sh
    echo "c-original" > .logic-loom/scripts/bash/c.sh
    echo "n-original" > .logic-loom/newdir/n.sh
    git add -A
    git commit -q -m "B"
  )
  sha_b="$(git -C "$dir" rev-parse HEAD)"
  RECON_SHA_B="$sha_b"
  (
    cd "$dir"
    echo "m-original" > .logic-loom/newdir/m.sh
    git add -A
    git commit -q -m "C: upstream adds newdir/m.sh"
  )
  RECON_SHA_C="$(git -C "$dir" rev-parse HEAD)"
  # Downstream stopped at B; C stays in the object store as upstream's future.
  git -C "$dir" reset -q --hard "$sha_b"

  # c.sh edited locally AFTER the (simulated) accept -- it must never be
  # auto-recorded, only b.sh and n.sh (still byte-identical to the B blobs)
  # may be.
  (
    cd "$dir"
    echo "c-edited-locally" > .logic-loom/scripts/bash/c.sh
    git add -A
    git commit -q -m "local edit to c.sh after accepting B"
  )

  local sha_a sha_x sha_conf
  sha_a="$(sha256_of "$dir/.logic-loom/scripts/bash/a.sh")"
  sha_x="$(sha256_of "$dir/plugins/loom-git/commands/x.md")"
  sha_conf="$(sha256_of "$dir/.logic-loom/config/architecture.conf")"
  cat > "$dir/.logicloom-adopt-receipt.json" <<JSON
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-08-31T00:00:00.000Z",
      "generator": "logicloom@6.6.2",
      "status": "complete",
      "wrote": [
        {"target": "harness", "path": ".logic-loom/", "kind": "dir"},
        {"target": "harness", "path": ".logic-loom/scripts/", "kind": "dir"},
        {"target": "harness", "path": ".logic-loom/scripts/bash/", "kind": "dir"},
        {"target": "harness", "path": ".logic-loom/config/", "kind": "dir"},
        {"target": "harness", "path": "plugins/", "kind": "dir"},
        {"target": "harness", "path": "plugins/loom-git/", "kind": "dir"},
        {"target": "harness", "path": "plugins/loom-git/commands/", "kind": "dir"},
        {"target": "harness", "path": ".logic-loom/scripts/bash/a.sh", "kind": "file", "sha256": "$sha_a"},
        {"target": "harness", "path": "plugins/loom-git/commands/x.md", "kind": "file", "sha256": "$sha_x"},
        {"target": "harness", "path": ".logic-loom/config/architecture.conf", "kind": "file", "sha256": "$sha_conf"}
      ],
      "skipped": [],
      "failed": [],
      "notAttempted": []
    }
  ],
  "uninstall": {}
}
JSON
  echo "$sha_b" > "$dir/.sdd-sync-ref"
}

extract_between() {
  # $1 = repo root, $2 = sync_ref, $3 = upstream_ref, $4 = stdout file, $5 = stderr file
  (
    set -euo pipefail
    # shellcheck disable=SC1090
    source "$EXTRACT_SCRIPT"
    REPO_ROOT="$1"
    extract_proposals "$2" "$3"
  ) > "$4" 2> "$5"
}

# ─────────────────────────────────────────────────────────────────────────
# A. The gap, proven — passes on TODAY's code (pins the mechanism)
# ─────────────────────────────────────────────────────────────────────────
echo "A. The gap, proven"

MAIN_F="$WORKDIR/main"
build_main_fixture "$MAIN_F"

AB_OUT="$WORKDIR/ab.json"; AB_ERR="$WORKDIR/ab.err"
extract_between "$MAIN_F" "$MAIN_SHA_A" "$MAIN_SHA_B" "$AB_OUT" "$AB_ERR"

RES_B_AB="$(proposals_resolution "$AB_OUT" ".logic-loom/scripts/bash/b.sh" 2>/dev/null || echo ABSENT)"
assert "A->B: b.sh offered as clean-add" "[ '$RES_B_AB' = 'clean-add' ]"
RES_C_AB="$(proposals_resolution "$AB_OUT" ".logic-loom/scripts/bash/c.sh" 2>/dev/null || echo ABSENT)"
assert "A->B: c.sh offered as clean-add" "[ '$RES_C_AB' = 'clean-add' ]"
RES_N_AB="$(proposals_resolution "$AB_OUT" ".logic-loom/newdir/n.sh" 2>/dev/null || echo ABSENT)"
assert "A->B: n.sh offered as clean-add" "[ '$RES_N_AB' = 'clean-add' ]"

# Simulate accepting the three clean-adds: write the upstream blobs into the
# working tree, advance .sdd-sync-ref to B, commit. Nothing here touches the
# receipt -- exactly what /update-framework does today.
(
  cd "$MAIN_F"
  git checkout -q "$MAIN_SHA_B" -- \
    .logic-loom/scripts/bash/b.sh .logic-loom/scripts/bash/c.sh .logic-loom/newdir/n.sh
  git commit -q -m "accept clean-add up to B"
)
echo "$MAIN_SHA_B" > "$MAIN_F/.sdd-sync-ref"

# Snapshot right here -- post-accept, pre-record -- reused by section C.
SNAPSHOT_DIR="$WORKDIR/snapshot-post-accept"
cp -R "$MAIN_F" "$SNAPSHOT_DIR"

BC_OUT="$WORKDIR/bc.json"; BC_ERR="$WORKDIR/bc.err"
extract_between "$MAIN_F" "$MAIN_SHA_B" "$MAIN_SHA_C" "$BC_OUT" "$BC_ERR"

assert "B->C (gap): b.sh is NOT offered (never recorded)" "! proposal_present '$BC_OUT' '.logic-loom/scripts/bash/b.sh'"
assert "B->C (gap): m.sh is NOT offered (ancestor dir never recorded)" "! proposal_present '$BC_OUT' '.logic-loom/newdir/m.sh'"
NOT_INSTALLED_COUNT="$(grep -c '1 not-installed-here' "$BC_ERR" || true)"
assert "B->C (gap) stderr: 'Suppressed:' names 1 not-installed-here" "[ '$NOT_INSTALLED_COUNT' -gt 0 ]"

# ─────────────────────────────────────────────────────────────────────────
# B. extract-proposals.sh: name the suppressed paths + the reconcile hint
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "B. extract-proposals.sh names what it suppressed"

NAMES_B="$(grep -cF 'not-installed-here: .logic-loom/scripts/bash/b.sh' "$BC_ERR" || true)"
assert "B->C stderr names the suppressed path" "[ '$NAMES_B' -gt 0 ]"
HINT_LINE="$(grep -c -- '--reconcile' "$BC_ERR" || true)"
assert "B->C stderr carries the --reconcile hint" "[ '$HINT_LINE' -gt 0 ]"
STDOUT_STILL_JSON="$(python3 -c "
import json
d = json.load(open('$BC_OUT'))
print('yes' if isinstance(d, list) else 'no')
")"
assert "B->C stdout stays a pure JSON array despite the new stderr lines" "[ '$STDOUT_STILL_JSON' = 'yes' ]"

# ─────────────────────────────────────────────────────────────────────────
# C. The recorder — record mode
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "C. record-update-writes.sh — record mode"

RECEIPT="$MAIN_F/.logicloom-adopt-receipt.json"
RUN0_BEFORE="$(python3 -c "
import json
d = json.load(open('$RECEIPT'))
print(json.dumps(d['runs'][0], sort_keys=True))
")"
UNINSTALL_BEFORE="$(json_snapshot "$RECEIPT" "uninstall")"

RECORD_OUT="$(bash "$RECORDER_SCRIPT" --root "$MAIN_F" --version v7.0.0 \
  .logic-loom/scripts/bash/b.sh .logic-loom/newdir/n.sh 2>&1)"
RECORD_EXIT=$?
assert "recorder (b.sh, n.sh) exits 0" "[ $RECORD_EXIT -eq 0 ]"

RUN_COUNT="$(json_runs_count "$RECEIPT")"
assert "receipt now has 2 runs" "[ '$RUN_COUNT' = '2' ]"

RUN1_GEN="$(json_run_field "$RECEIPT" 1 generator)"
assert "run[1].generator == logicloom-update-framework@7.0.0" \
  "[ '$RUN1_GEN' = 'logicloom-update-framework@7.0.0' ]"
RUN1_STATUS="$(json_run_field "$RECEIPT" 1 status)"
assert "run[1].status == complete" "[ '$RUN1_STATUS' = 'complete' ]"
RUN1_ONLY="$(python3 -c "
import json
d = json.load(open('$RECEIPT'))
print(','.join(d['runs'][1]['only']))
")"
assert "run[1].only == ['update-framework']" "[ '$RUN1_ONLY' = 'update-framework' ]"

EXPECT_SHA_B="$(sha256_of "$MAIN_F/.logic-loom/scripts/bash/b.sh")"
GOT_SHA_B="$(json_run_wrote_sha "$RECEIPT" 1 ".logic-loom/scripts/bash/b.sh")"
assert "run[1].wrote has b.sh with the correct sha256" "[ '$GOT_SHA_B' = '$EXPECT_SHA_B' ]"

EXPECT_SHA_N="$(sha256_of "$MAIN_F/.logic-loom/newdir/n.sh")"
GOT_SHA_N="$(json_run_wrote_sha "$RECEIPT" 1 ".logic-loom/newdir/n.sh")"
assert "run[1].wrote has n.sh with the correct sha256" "[ '$GOT_SHA_N' = '$EXPECT_SHA_N' ]"

HAS_NEWDIR="$(json_run_has_dir_entry "$RECEIPT" 1 ".logic-loom/newdir/")"
assert "run[1].wrote has a {kind dir} entry for .logic-loom/newdir/" "[ '$HAS_NEWDIR' = 'yes' ]"
HAS_SCRIPTS_BASH_DIR="$(json_run_has_dir_entry "$RECEIPT" 1 ".logic-loom/scripts/bash/")"
assert "run[1].wrote has NO dir entry for .logic-loom/scripts/bash/ (already recorded)" \
  "[ '$HAS_SCRIPTS_BASH_DIR' = 'no' ]"

RUN0_AFTER="$(python3 -c "
import json
d = json.load(open('$RECEIPT'))
print(json.dumps(d['runs'][0], sort_keys=True))
")"
assert "run[0] is byte-identical (structurally) before/after recording" "[ '$RUN0_BEFORE' = '$RUN0_AFTER' ]"
UNINSTALL_AFTER="$(json_snapshot "$RECEIPT" "uninstall")"
assert "'uninstall' key is untouched" "[ '$UNINSTALL_BEFORE' = '$UNINSTALL_AFTER' ]"

BC2_OUT="$WORKDIR/bc2.json"; BC2_ERR="$WORKDIR/bc2.err"
extract_between "$MAIN_F" "$MAIN_SHA_B" "$MAIN_SHA_C" "$BC2_OUT" "$BC2_ERR"
RES_B_BC2="$(proposals_resolution "$BC2_OUT" ".logic-loom/scripts/bash/b.sh" 2>/dev/null || echo ABSENT)"
assert "B->C after recording: b.sh now offered as clean-apply" "[ '$RES_B_BC2' = 'clean-apply' ]"
RES_M_BC2="$(proposals_resolution "$BC2_OUT" ".logic-loom/newdir/m.sh" 2>/dev/null || echo ABSENT)"
assert "B->C after recording: m.sh now offered as clean-add" "[ '$RES_M_BC2' = 'clean-add' ]"

RECEIPT_CKSUM_BEFORE="$(cksum "$RECEIPT")"
SECOND_OUT="$(bash "$RECORDER_SCRIPT" --root "$MAIN_F" --version v7.0.0 \
  .logic-loom/scripts/bash/b.sh .logic-loom/newdir/n.sh)"
SECOND_HAS_MSG="$(printf '%s' "$SECOND_OUT" | grep -c 'nothing new to record' || true)"
assert "a second identical recorder call prints 'nothing new to record'" "[ '$SECOND_HAS_MSG' -gt 0 ]"
RUN_COUNT2="$(json_runs_count "$RECEIPT")"
assert "run count stays 2 after the second identical call" "[ '$RUN_COUNT2' = '2' ]"
RECEIPT_CKSUM_AFTER="$(cksum "$RECEIPT")"
assert "receipt cksum unchanged after the second identical call" \
  "[ '$RECEIPT_CKSUM_BEFORE' = '$RECEIPT_CKSUM_AFTER' ]"

# ─────────────────────────────────────────────────────────────────────────
# D. JSON tool — python3 vs node byte-identical; LOOM_JSON_TOOL
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "D. JSON tool selection (python3, else node)"

if command -v node >/dev/null 2>&1; then
  TOOLS_PY="$WORKDIR/tools-py"; TOOLS_NODE="$WORKDIR/tools-node"
  cp -R "$SNAPSHOT_DIR" "$TOOLS_PY"
  cp -R "$SNAPSHOT_DIR" "$TOOLS_NODE"
  LOOM_JSON_TOOL=python3 bash "$RECORDER_SCRIPT" --root "$TOOLS_PY" --version v7.0.0 \
    .logic-loom/scripts/bash/b.sh .logic-loom/newdir/n.sh >/dev/null
  LOOM_JSON_TOOL=node bash "$RECORDER_SCRIPT" --root "$TOOLS_NODE" --version v7.0.0 \
    .logic-loom/scripts/bash/b.sh .logic-loom/newdir/n.sh >/dev/null
  TOOLS_MATCH="$(python3 -c "
import re
a = open('$TOOLS_PY/.logicloom-adopt-receipt.json').read()
b = open('$TOOLS_NODE/.logicloom-adopt-receipt.json').read()
a = re.sub(r'\"at\": \"[^\"]*\"', '\"at\": \"NORMALIZED\"', a)
b = re.sub(r'\"at\": \"[^\"]*\"', '\"at\": \"NORMALIZED\"', b)
print('MATCH' if a == b else 'DIFFER')
")"
  assert "python3 and node produce byte-identical receipts (modulo 'at')" "[ '$TOOLS_MATCH' = 'MATCH' ]"
else
  skip "python3 and node produce byte-identical receipts" "node not on PATH"
fi

TOOLS_BAD="$WORKDIR/tools-bad"
cp -R "$SNAPSHOT_DIR" "$TOOLS_BAD"
BAD_CKSUM_BEFORE="$(cksum "$TOOLS_BAD/.logicloom-adopt-receipt.json")"
BAD_OUT="$(LOOM_JSON_TOOL=/nonexistent/tool bash "$RECORDER_SCRIPT" --root "$TOOLS_BAD" \
  .logic-loom/scripts/bash/b.sh 2>&1)"
BAD_EXIT=$?
assert "LOOM_JSON_TOOL=/nonexistent/tool exits 2" "[ $BAD_EXIT -eq 2 ]"
BAD_HAS_PY="$(printf '%s' "$BAD_OUT" | grep -c 'python3' || true)"
BAD_HAS_NODE="$(printf '%s' "$BAD_OUT" | grep -c 'node' || true)"
assert "LOOM_JSON_TOOL=/nonexistent/tool message names python3 and node" \
  "[ '$BAD_HAS_PY' -gt 0 ] && [ '$BAD_HAS_NODE' -gt 0 ]"
BAD_CKSUM_AFTER="$(cksum "$TOOLS_BAD/.logicloom-adopt-receipt.json")"
assert "LOOM_JSON_TOOL=/nonexistent/tool leaves the receipt untouched" \
  "[ '$BAD_CKSUM_BEFORE' = '$BAD_CKSUM_AFTER' ]"

# ─────────────────────────────────────────────────────────────────────────
# E. --reconcile
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "E. --reconcile"

RECON_F="$WORKDIR/reconcile"
build_reconcile_fixture "$RECON_F"
RECON_RECEIPT="$RECON_F/.logicloom-adopt-receipt.json"

# The directory half of the gap, before reconcile: upstream B->C adds
# .logic-loom/newdir/m.sh; newdir/ is not recorded, so m.sh is suppressed.
RBC_OUT="$WORKDIR/rbc.json"; RBC_ERR="$WORKDIR/rbc.err"
extract_between "$RECON_F" "$RECON_SHA_B" "$RECON_SHA_C" "$RBC_OUT" "$RBC_ERR"
assert "reconcile fixture B->C (gap): m.sh NOT offered while newdir/ is unrecorded" \
  "! proposal_present '$RBC_OUT' '.logic-loom/newdir/m.sh'"

RECON_CKSUM_BEFORE="$(cksum "$RECON_RECEIPT")"
RECON_OUT="$(bash "$RECORDER_SCRIPT" --root "$RECON_F" --reconcile)"
RECON_HAS_RECONCILE_B="$(printf '%s\n' "$RECON_OUT" | grep -cF 'RECONCILE .logic-loom/scripts/bash/b.sh' || true)"
assert "--reconcile prints RECONCILE for b.sh (byte-identical to sync-ref)" "[ '$RECON_HAS_RECONCILE_B' -gt 0 ]"
RECON_HAS_RECONCILE_N="$(printf '%s\n' "$RECON_OUT" | grep -cF 'RECONCILE .logic-loom/newdir/n.sh' || true)"
assert "--reconcile prints RECONCILE for n.sh (under an unrecorded dir)" "[ '$RECON_HAS_RECONCILE_N' -gt 0 ]"
RECON_HAS_DIFFERS_C="$(printf '%s\n' "$RECON_OUT" | grep -cF 'DIFFERS .logic-loom/scripts/bash/c.sh' || true)"
assert "--reconcile prints DIFFERS for c.sh (locally edited)" "[ '$RECON_HAS_DIFFERS_C' -gt 0 ]"
RECON_HAS_HINT="$(printf '%s\n' "$RECON_OUT" | grep -c 'record it explicitly' || true)"
assert "--reconcile prints the explicit-record hint" "[ '$RECON_HAS_HINT' -gt 0 ]"
RECON_HAS_RERUN="$(printf '%s\n' "$RECON_OUT" | grep -c -- 're-run with --apply' || true)"
assert "--reconcile (no --apply) ends with the re-run hint" "[ '$RECON_HAS_RERUN' -gt 0 ]"
RECON_CKSUM_AFTER="$(cksum "$RECON_RECEIPT")"
assert "--reconcile (no --apply) leaves the receipt cksum unchanged" \
  "[ '$RECON_CKSUM_BEFORE' = '$RECON_CKSUM_AFTER' ]"

RECON_APPLY_OUT="$(bash "$RECORDER_SCRIPT" --root "$RECON_F" --reconcile --apply)"
RECON_APPLY_HAS_RERUN="$(printf '%s\n' "$RECON_APPLY_OUT" | grep -c -- 're-run with --apply' || true)"
assert "--reconcile --apply does not tell the user to re-run with --apply" "[ '$RECON_APPLY_HAS_RERUN' -eq 0 ]"
RECON_RUNS="$(json_runs_count "$RECON_RECEIPT")"
assert "--reconcile --apply appends run 2" "[ '$RECON_RUNS' = '2' ]"
RECON_RUN1_GEN="$(json_run_field "$RECON_RECEIPT" 1 generator)"
assert "reconcile-apply run generator uses the fixture's own stamp (6.6.2)" \
  "[ '$RECON_RUN1_GEN' = 'logicloom-update-framework@6.6.2' ]"
RECON_RUN1_ONLY="$(python3 -c "
import json
d = json.load(open('$RECON_RECEIPT'))
print(','.join(d['runs'][1]['only']))
")"
assert "reconcile-apply run.only == ['reconcile']" "[ '$RECON_RUN1_ONLY' = 'reconcile' ]"
RECON_RUN1_FILES="$(json_run_wrote_file_paths_sorted "$RECON_RECEIPT" 1)"
assert "reconcile-apply records b.sh and n.sh only (never the DIFFERS c.sh)" \
  "[ '$RECON_RUN1_FILES' = '.logic-loom/newdir/n.sh,.logic-loom/scripts/bash/b.sh' ]"
RECON_HAS_NEWDIR="$(json_run_has_dir_entry "$RECON_RECEIPT" 1 ".logic-loom/newdir/")"
assert "reconcile-apply ALSO records the unrecorded ancestor .logic-loom/newdir/ as a dir (exactly as record mode)" \
  "[ '$RECON_HAS_NEWDIR' = 'yes' ]"
RECON_HAS_BASH_DIR="$(json_run_has_dir_entry "$RECON_RECEIPT" 1 ".logic-loom/scripts/bash/")"
assert "reconcile-apply adds NO dir entry for the already-recorded .logic-loom/scripts/bash/" \
  "[ '$RECON_HAS_BASH_DIR' = 'no' ]"

RECORDED_FILES="$(json_all_recorded_file_paths "$RECON_RECEIPT")"
C_STILL_UNRECORDED="$(printf '%s' "$RECORDED_FILES" | grep -c '.logic-loom/scripts/bash/c.sh' || true)"
assert "c.sh is still unrecorded after --reconcile --apply" "[ '$C_STILL_UNRECORDED' -eq 0 ]"

# The directory half of the gap, after reconcile: m.sh is now offered.
RBC2_OUT="$WORKDIR/rbc2.json"; RBC2_ERR="$WORKDIR/rbc2.err"
extract_between "$RECON_F" "$RECON_SHA_B" "$RECON_SHA_C" "$RBC2_OUT" "$RBC2_ERR"
RES_M_RBC2="$(proposals_resolution "$RBC2_OUT" ".logic-loom/newdir/m.sh" 2>/dev/null || echo ABSENT)"
assert "reconcile fixture B->C after --reconcile --apply: m.sh offered as clean-add" \
  "[ '$RES_M_RBC2' = 'clean-add' ]"

bash "$RECORDER_SCRIPT" --root "$RECON_F" .logic-loom/scripts/bash/c.sh >/dev/null
RECON_RUNS2="$(json_runs_count "$RECON_RECEIPT")"
assert "explicit 'record-update-writes.sh c.sh' appends run 3" "[ '$RECON_RUNS2' = '3' ]"

RECON_CKSUM_BEFORE2="$(cksum "$RECON_RECEIPT")"
bash "$RECORDER_SCRIPT" --root "$RECON_F" --reconcile --apply >/dev/null
RECON_CKSUM_AFTER2="$(cksum "$RECON_RECEIPT")"
assert "a second --reconcile --apply appends no run" "[ '$RECON_CKSUM_BEFORE2' = '$RECON_CKSUM_AFTER2' ]"

# ─────────────────────────────────────────────────────────────────────────
# F. Refusals
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "F. Refusals"

NORECEIPT_F="$WORKDIR/no-receipt"
mkdir -p "$NORECEIPT_F"
NORECEIPT_OUT="$(bash "$RECORDER_SCRIPT" --root "$NORECEIPT_F" foo.txt 2>&1)"
NORECEIPT_EXIT=$?
assert "no receipt: exit 2" "[ $NORECEIPT_EXIT -eq 2 ]"
NORECEIPT_HAS_MSG="$(printf '%s' "$NORECEIPT_OUT" | grep -ci 'template clone' || true)"
assert "no receipt: message names 'template clone'" "[ '$NORECEIPT_HAS_MSG' -gt 0 ]"

BADSCHEMA_F="$WORKDIR/bad-schema"
mkdir -p "$BADSCHEMA_F"
printf '{"schema": "logicloom/adopt-receipt@2", "runs": []}' > "$BADSCHEMA_F/.logicloom-adopt-receipt.json"
BADSCHEMA_CKSUM_BEFORE="$(cksum "$BADSCHEMA_F/.logicloom-adopt-receipt.json")"
bash "$RECORDER_SCRIPT" --root "$BADSCHEMA_F" foo.txt >/dev/null 2>&1
BADSCHEMA_EXIT=$?
assert "schema logicloom/adopt-receipt@2: exit 2" "[ $BADSCHEMA_EXIT -eq 2 ]"
BADSCHEMA_CKSUM_AFTER="$(cksum "$BADSCHEMA_F/.logicloom-adopt-receipt.json")"
assert "schema mismatch: receipt byte-identical" "[ '$BADSCHEMA_CKSUM_BEFORE' = '$BADSCHEMA_CKSUM_AFTER' ]"

OUTSIDE_F="$WORKDIR/outside-root"
mkdir -p "$OUTSIDE_F"
printf '{"schema": "logicloom/adopt-receipt@1", "runs": [{"status": "complete", "wrote": []}]}' \
  > "$OUTSIDE_F/.logicloom-adopt-receipt.json"
bash "$RECORDER_SCRIPT" --root "$OUTSIDE_F" ../x >/dev/null 2>&1
OUTSIDE_EXIT=$?
assert "'../x' (outside the root): exit 2" "[ $OUTSIDE_EXIT -eq 2 ]"

# ─────────────────────────────────────────────────────────────────────────
# G. Template-clone inertness (extract-proposals.sh, receipt-less repo)
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "G. Template-clone inertness"

INERT_F="$WORKDIR/inert"
mkdir -p "$INERT_F/.logic-loom/scripts/bash"
(
  cd "$INERT_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "a" > .logic-loom/scripts/bash/a.sh
  git add -A
  git commit -q -m "A"
)
INERT_SHA_A="$(git -C "$INERT_F" rev-parse HEAD)"
(
  cd "$INERT_F"
  echo "a-modified" > .logic-loom/scripts/bash/a.sh
  git add -A
  git commit -q -m "B"
)
INERT_SHA_B="$(git -C "$INERT_F" rev-parse HEAD)"
git -C "$INERT_F" reset -q --hard "$INERT_SHA_A"

INERT_OUT="$WORKDIR/inert.json"; INERT_ERR="$WORKDIR/inert.err"
extract_between "$INERT_F" "$INERT_SHA_A" "$INERT_SHA_B" "$INERT_OUT" "$INERT_ERR"

INERT_HAS_ADOPTED="$(grep -c 'ADOPTED REPO' "$INERT_ERR" || true)"
assert "template clone: stderr has no 'ADOPTED REPO'" "[ '$INERT_HAS_ADOPTED' -eq 0 ]"
INERT_HAS_NOTINSTALLED="$(grep -c 'not-installed-here:' "$INERT_ERR" || true)"
assert "template clone: stderr has no 'not-installed-here:'" "[ '$INERT_HAS_NOTINSTALLED' -eq 0 ]"
INERT_HAS_RECONCILE="$(grep -c -- '--reconcile' "$INERT_ERR" || true)"
assert "template clone: stderr has no '--reconcile' hint" "[ '$INERT_HAS_RECONCILE' -eq 0 ]"
INERT_IS_ARRAY="$(python3 -c "
import json
d = json.load(open('$INERT_OUT'))
print('yes' if isinstance(d, list) else 'no')
")"
assert "template clone: stdout parses as a JSON array" "[ '$INERT_IS_ARRAY' = 'yes' ]"

# ─────────────────────────────────────────────────────────────────────────
# H. Edge cases a customer's tree can hit that the happy-path fixtures do not
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "H. Edge cases"

# (i) --reconcile with ZERO candidates: the receipt records a directory that
# has no tracked files under it yet. Under bash 3.2 (stock macOS), expanding
# an empty array with "${arr[@]}" is an unbound-variable error under set -u,
# so this case must be exercised under /bin/bash too when it exists.
EMPTY_F="$WORKDIR/empty-candidates"
mkdir -p "$EMPTY_F"
(
  cd "$EMPTY_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "readme" > README.md
  git add -A
  git commit -q -m "A"
  git rev-parse HEAD > .sdd-sync-ref
)
printf '{"schema": "logicloom/adopt-receipt@1", "runs": [{"status": "complete", "wrote": [{"target": "harness", "path": ".logic-loom/", "kind": "dir"}]}]}\n' \
  > "$EMPTY_F/.logicloom-adopt-receipt.json"
EMPTY_OUT="$(bash "$RECORDER_SCRIPT" --root "$EMPTY_F" --reconcile 2>&1)"
EMPTY_EXIT=$?
assert "--reconcile with zero candidates exits 0" "[ $EMPTY_EXIT -eq 0 ]"
EMPTY_HAS_NOTHING="$(printf '%s\n' "$EMPTY_OUT" | grep -c 'reconcile: nothing to record' || true)"
assert "--reconcile with zero candidates prints 'reconcile: nothing to record'" "[ '$EMPTY_HAS_NOTHING' -gt 0 ]"
if [ -x /bin/bash ]; then
  EMPTY32_OUT="$(/bin/bash "$RECORDER_SCRIPT" --root "$EMPTY_F" --reconcile 2>&1)"
  EMPTY32_EXIT=$?
  assert "--reconcile with zero candidates exits 0 under /bin/bash ($(/bin/bash -c 'echo ${BASH_VERSION%%(*}'))" \
    "[ $EMPTY32_EXIT -eq 0 ]"
  EMPTY32_UNBOUND="$(printf '%s\n' "$EMPTY32_OUT" | grep -c 'unbound variable' || true)"
  assert "--reconcile with zero candidates: no 'unbound variable' under /bin/bash" "[ '$EMPTY32_UNBOUND' -eq 0 ]"
else
  skip "--reconcile with zero candidates under /bin/bash" "/bin/bash not present"
fi

# (ii) The same file named twice, under two spellings, is recorded ONCE.
DUP_F="$WORKDIR/dup-spellings"
cp -R "$SNAPSHOT_DIR" "$DUP_F"
bash "$RECORDER_SCRIPT" --root "$DUP_F" --version v7.0.0 \
  .logic-loom/scripts/bash/b.sh ./.logic-loom/scripts/bash/b.sh >/dev/null
DUP_COUNT="$(python3 -c "
import json
d = json.load(open('$DUP_F/.logicloom-adopt-receipt.json'))
print(sum(1 for w in d['runs'][-1]['wrote'] if w['path'] == '.logic-loom/scripts/bash/b.sh'))
")"
assert "a path named twice (two spellings) yields exactly one file entry in the run" "[ '$DUP_COUNT' = '1' ]"

# (iii) A symlink is not a regular file: refused, receipt untouched.
LINK_F="$WORKDIR/symlink"
cp -R "$SNAPSHOT_DIR" "$LINK_F"
ln -s scripts/bash/b.sh "$LINK_F/.logic-loom/link-to-b.sh"
LINK_CKSUM_BEFORE="$(cksum "$LINK_F/.logicloom-adopt-receipt.json")"
bash "$RECORDER_SCRIPT" --root "$LINK_F" --version v7.0.0 .logic-loom/link-to-b.sh >/dev/null 2>&1
LINK_EXIT=$?
assert "a symlink path is refused with exit 2" "[ $LINK_EXIT -eq 2 ]"
LINK_CKSUM_AFTER="$(cksum "$LINK_F/.logicloom-adopt-receipt.json")"
assert "a refused symlink leaves the receipt untouched" "[ '$LINK_CKSUM_BEFORE' = '$LINK_CKSUM_AFTER' ]"

# (iv) --reconcile with a .sdd-sync-ref that does not resolve (an adopted
# install before /update-framework has ever fetched upstream): exit 2,
# nothing written, and the message says what to do.
NOREF_F="$WORKDIR/unresolvable-ref"
cp -R "$SNAPSHOT_DIR" "$NOREF_F"
echo "0123456789abcdef0123456789abcdef01234567" > "$NOREF_F/.sdd-sync-ref"
NOREF_CKSUM_BEFORE="$(cksum "$NOREF_F/.logicloom-adopt-receipt.json")"
NOREF_OUT="$(bash "$RECORDER_SCRIPT" --root "$NOREF_F" --reconcile 2>&1)"
NOREF_EXIT=$?
assert "--reconcile with an unresolvable .sdd-sync-ref exits 2" "[ $NOREF_EXIT -eq 2 ]"
NOREF_HAS_HINT="$(printf '%s\n' "$NOREF_OUT" | grep -c 'update-framework' || true)"
assert "--reconcile with an unresolvable .sdd-sync-ref names /update-framework as the fix" "[ '$NOREF_HAS_HINT' -gt 0 ]"
NOREF_CKSUM_AFTER="$(cksum "$NOREF_F/.logicloom-adopt-receipt.json")"
assert "--reconcile with an unresolvable .sdd-sync-ref leaves the receipt untouched" \
  "[ '$NOREF_CKSUM_BEFORE' = '$NOREF_CKSUM_AFTER' ]"

# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
