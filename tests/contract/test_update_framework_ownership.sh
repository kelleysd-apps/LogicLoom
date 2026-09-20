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
# LOOM_TEST_RECORDER_SCRIPT lets a fail-then-pass proof point this suite at
# another copy of the recorder (e.g. `git show <sha>:plugins/.../record-update-writes.sh`
# saved to a scratch file) WITHOUT swapping files in the working tree. Every
# recorder call below passes --root, so the copy's own location is irrelevant.
RECORDER_SCRIPT="${LOOM_TEST_RECORDER_SCRIPT:-$REAL_ROOT/plugins/loom-maintenance/scripts/record-update-writes.sh}"

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

# sha256 of a git blob ($1 = repo dir, $2 = "<rev>:<path>") -- the independent
# oracle for "what did LogicLoom actually write there", computed WITHOUT going
# through record-update-writes.sh, so section I can check the recorder's
# output against ground truth rather than against itself.
sha256_of_blob() {
  git -C "$1" cat-file -p "$2" | python3 -c "
import hashlib, sys
print('sha256:' + hashlib.sha256(sys.stdin.buffer.read()).hexdigest())
"
}

# The REAL packaging code's verdict on one file. $1 = apply.js, $2 = receipt,
# $3 = repo-relative path, $4 = the file on disk. Prints two space-separated
# fields: "<MISSING|NULL|MATCH|MISMATCH> <recorded-sha256-or->". MATCH is the
# one verdict uninstallProcedure()'s step 1 reads as "safe to delete"; every
# other verdict is KEEP (or review) -- so an adopter's own bytes must never
# come back MATCH from this helper, whatever state the recorder was run in.
uninstall_verdict() {
  node -e '
    const fs = require("fs");
    const crypto = require("crypto");
    const a = require(process.argv[1]);
    const receipt = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
    const u = a.uninstallProcedure(receipt);
    const entry = u.remove.files.find(f => f.path === process.argv[3]);
    if (!entry) { process.stdout.write("MISSING -"); process.exit(0); }
    if (entry.sha256 === null) { process.stdout.write("NULL -"); process.exit(0); }
    const diskSha = "sha256:" + crypto.createHash("sha256").update(fs.readFileSync(process.argv[4])).digest("hex");
    process.stdout.write((entry.sha256 === diskSha ? "MATCH " : "MISMATCH ") + entry.sha256);
  ' "$1" "$2" "$3" "$4"
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

json_uninstall_stale_shape() {
  # $1 = receipt path. One line, five space-separated fields, describing the
  # receipt's top-level 'uninstall' as the recorder is expected to leave it:
  #   stale=<true|false|absent>   runnable=<yes|no>   byrun=<n|none>
  #   only=<yes|no>  (regenerate command names --apply --only)
  #   refusal=<yes|no> (it states the uncommitted-merge-target refusal)
  # 'runnable=yes' means a remove.files / dirsIfEmpty / steps list is present
  # -- i.e. something a reader could execute -- which a STALE marker must
  # never carry.
  python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
u = d.get('uninstall')
if u is None:
    print('stale=absent runnable=no byrun=none only=no refusal=no'); sys.exit(0)
stale = 'true' if u.get('stale') is True else 'false'
runnable = 'yes' if ('remove' in u or 'steps' in u) else 'no'
byrun = u.get('invalidatedByRun', 'none')
regen = str(u.get('regenerate', ''))
only = 'yes' if '--apply --only' in regen else 'no'
refusal = 'yes' if ('REFUSED' in regen and 'uncommitted' in regen) else 'no'
print('stale=%s runnable=%s byrun=%s only=%s refusal=%s' % (stale, runnable, byrun, only, refusal))
" "$1"
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
  # Round-2 finding 1: .sdd-sync-ref is a baseline for the recorder ONLY
  # when refs/loom-upstream/main exists locally and reaches it — the fetch
  # ref /update-framework's own extract step leaves behind. Every fixture
  # here models an adopted install mid-/post-update, where that ref is at
  # upstream's tip (C), which reaches A and B alike. Without it the strict
  # rule (correctly) refuses to record anything, so no assertion below
  # would be exercising record mode at all.
  git -C "$dir" update-ref refs/loom-upstream/main "$MAIN_SHA_C"
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
  # Round-2 finding 1 (see build_main_fixture): the fetch ref, at upstream's
  # tip C, which reaches the sync-ref commit B.
  git -C "$dir" update-ref refs/loom-upstream/main "$RECON_SHA_C"
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

# PRE-uninstall-rot fix: a cached 'uninstall' object was derived from runs[0]
# alone -- it cannot possibly list the paths just recorded into runs[1], so it
# is now provably stale. record-update-writes.sh replaces it with a STALE
# MARKER (rather than reimplementing apply.js's uninstallProcedure() as a
# second writer in bash, and rather than silently deleting the key) so the
# receipt never carries a wrong list under a key everything else treats as
# authoritative, yet still answers -- from the receipt itself, which is where
# the install report told the adopter to look -- why the list is gone and how
# to get it back; see the UNINSTALL comment near the top of the recorder.
assert "fixture's 'uninstall' sentinel is present before recording (sanity check)" \
  "[ '$UNINSTALL_BEFORE' = '{\"marker\": \"left as is\"}' ]"
UNINSTALL_SHAPE_AFTER="$(json_uninstall_stale_shape "$RECEIPT")"
assert "'uninstall' is replaced by a stale marker (stale=true) after recording, not left as the old cache" \
  "[ '$(printf '%s' "$UNINSTALL_SHAPE_AFTER" | cut -d' ' -f1)' = 'stale=true' ]"
assert "the stale marker carries NOTHING runnable (no remove.files, no steps)" \
  "[ '$(printf '%s' "$UNINSTALL_SHAPE_AFTER" | cut -d' ' -f2)' = 'runnable=no' ]"
assert "the stale marker names the run that invalidated it (invalidatedByRun == 1)" \
  "[ '$(printf '%s' "$UNINSTALL_SHAPE_AFTER" | cut -d' ' -f3)' = 'byrun=1' ]"
# `--only` is REQUIRED with `--apply` (packaging/adopt/bin/logicloom.js refuses
# a bare `--apply` with exit 2), so a regenerate command that omits it is one
# the adopter cannot run. Pin that the marker's command is a runnable one.
assert "the stale marker's regenerate command names --apply --only (a bare --apply is refused by the CLI)" \
  "[ '$(printf '%s' "$UNINSTALL_SHAPE_AFTER" | cut -d' ' -f4)' = 'only=yes' ]"
# A re-apply is REFUSED (nothing written, the marker stays) while a merge
# target has uncommitted changes -- the marker must say so rather than promise
# an unconditional no-op.
assert "the stale marker states the refusal condition (uncommitted merge-target changes)" \
  "[ '$(printf '%s' "$UNINSTALL_SHAPE_AFTER" | cut -d' ' -f5)' = 'refusal=yes' ]"
HELP_ONLY="$(bash "$RECORDER_SCRIPT" --help 2>/dev/null | grep -c -- '--apply --only' || true)"
assert "--help's regenerate command names --apply --only, never a bare --apply" "[ '$HELP_ONLY' -gt 0 ]"
HELP_NOOP_CLAIM="$(bash "$RECORDER_SCRIPT" --help 2>/dev/null | grep -ci 'idempotent' || true)"
assert "--help does not promise an unconditional 'idempotent' re-apply (it is refused on a dirty merge target)" \
  "[ '$HELP_NOOP_CLAIM' -eq 0 ]"
HELP_REFUSAL="$(bash "$RECORDER_SCRIPT" --help 2>/dev/null | grep -c 'REFUSED' || true)"
assert "--help states that the regenerate re-apply can be REFUSED (and when)" "[ '$HELP_REFUSAL' -gt 0 ]"

# And the property that makes deleting it safe: apply.js's uninstallProcedure()
# — the single source of truth — DOES cover the just-recorded paths when it is
# next computed fresh from the complete on-disk runs[] (i.e. what the adopter's
# next `npx logicloom init --apply` does). This is read-only: it only requires
# packaging/adopt/lib/apply.js, never runs it as a CLI, and proves runs[] alone
# (not the deleted cache) is what a correct uninstall listing is built from.
APPLY_LIB="$REAL_ROOT/packaging/adopt/lib/apply.js"
if [ -f "$APPLY_LIB" ] && command -v node >/dev/null 2>&1; then
  FRESH_HAS_B="$(node -e '
    const a = require(process.argv[1]);
    const fs = require("fs");
    const receipt = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
    const u = a.uninstallProcedure(receipt);
    const has = u.remove.files.some(f => f.path === ".logic-loom/scripts/bash/b.sh")
      && u.remove.files.some(f => f.path === ".logic-loom/newdir/n.sh");
    process.stdout.write(has ? "yes" : "no");
  ' "$APPLY_LIB" "$RECEIPT")"
  assert "apply.js's uninstallProcedure(), recomputed fresh from runs[], DOES cover the update-framework-recorded paths" \
    "[ '$FRESH_HAS_B' = 'yes' ]"
else
  skip "uninstallProcedure() covers update-framework-recorded paths" "packaging/adopt/lib/apply.js not present (stripped tree) or node unavailable"
fi

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

# Same PRE-uninstall-rot property as section C's record mode, exercised
# through --reconcile --apply's shared append-run path: the fixture's
# 'uninstall': {} is now stale (derived from run[0] alone) and must be
# replaced by the same stale marker, pointing at run 1.
RECON_UNINSTALL_SHAPE="$(json_uninstall_stale_shape "$RECON_RECEIPT")"
assert "--reconcile --apply also replaces the now-stale 'uninstall' with the stale marker" \
  "[ '$(printf '%s' "$RECON_UNINSTALL_SHAPE" | cut -d' ' -f1)' = 'stale=true' ]"
assert "--reconcile --apply's marker carries nothing runnable and names run 1" \
  "[ '$(printf '%s' "$RECON_UNINSTALL_SHAPE" | cut -d' ' -f2,3)' = 'runnable=no byrun=1' ]"

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
# E-quoted. Round-2 finding 5: --reconcile's `git ls-files` must be -z /
# NUL-delimited. Without -z, git C-quotes a path containing a quote,
# backslash, or non-ASCII byte in its default output; `while IFS= read -r f`
# then takes that quoted, ESCAPED LITERAL as the path, which never matches a
# real file on disk — the candidate is silently dropped, never reconciled.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "E-quoted. --reconcile is NUL-safe (git ls-files -z) — a quote-containing filename is not silently dropped"

QUOTE_F="$WORKDIR/reconcile-quoted"
mkdir -p "$QUOTE_F/.logic-loom/scripts/bash"
(
  cd "$QUOTE_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "a-content" > .logic-loom/scripts/bash/a.sh
  printf 'weird-content\n' > '.logic-loom/scripts/bash/weird"quote.sh'
  git add -A
  git commit -q -m "A: includes a quote-containing filename"
)
QUOTE_SHA="$(git -C "$QUOTE_F" rev-parse HEAD)"
echo "$QUOTE_SHA" > "$QUOTE_F/.sdd-sync-ref"
( cd "$QUOTE_F" && git add -A >/dev/null && git commit -q -m "stamp sync-ref" )
# Round-2 finding 1: the sync-ref is a baseline only when refs/loom-upstream/
# main exists and reaches it.
git -C "$QUOTE_F" update-ref refs/loom-upstream/main HEAD
cat > "$QUOTE_F/.logicloom-adopt-receipt.json" <<JSON
{"schema": "logicloom/adopt-receipt@1", "runs": [{"generator": "logicloom-update-framework@7.0.0", "status": "complete", "wrote": [
  {"target": "harness", "path": ".logic-loom/", "kind": "dir"},
  {"target": "harness", "path": ".logic-loom/scripts/", "kind": "dir"},
  {"target": "harness", "path": ".logic-loom/scripts/bash/", "kind": "dir"}
]}], "uninstall": {}}
JSON

QUOTE_EXPECT_LINE="RECONCILE .logic-loom/scripts/bash/weird\"quote.sh"
QUOTE_OUT="$(bash "$RECORDER_SCRIPT" --root "$QUOTE_F" --reconcile 2>&1)"
QUOTE_HAS_LINE=0
while IFS= read -r qline; do
  [ "$qline" = "$QUOTE_EXPECT_LINE" ] && QUOTE_HAS_LINE=1
done <<< "$QUOTE_OUT"
assert "--reconcile lists the exact quote-containing path as RECONCILE (git ls-files -z; a plain ls-files would C-quote it and the candidate would be silently dropped instead)" \
  "[ '$QUOTE_HAS_LINE' -eq 1 ]"

bash "$RECORDER_SCRIPT" --root "$QUOTE_F" --reconcile --apply >/dev/null 2>&1
QUOTE_RECORDED="$(python3 -c "
import json
d = json.load(open('$QUOTE_F/.logicloom-adopt-receipt.json'))
paths = [w['path'] for r in d['runs'] for w in r['wrote'] if w.get('kind') == 'file']
print('yes' if '.logic-loom/scripts/bash/weird\"quote.sh' in paths else 'no')
")"
assert "…and --apply records the byte-exact quote-containing path in the receipt (never a mangled/backslash-escaped variant)" \
  "[ '$QUOTE_RECORDED' = 'yes' ]"

# Odd-filename follow-through: git also permits a NEWLINE or a TAB in a
# filename. The recorder's entry format is tab-separated, one entry per line,
# so such a path cannot be recorded faithfully — and a `printf '%s\n' | sort
# -u` dedupe would even split a newline-named candidate in two and drop both
# halves without a word. The contract: never silently dropped, never
# mis-recorded — --reconcile names it on stderr as skipped, exits 0, still
# handles every other candidate, and --apply records nothing for it.
ODD_NL_NAME=$'.logic-loom/scripts/bash/new\nline.sh'
ODD_TAB_NAME=$'.logic-loom/scripts/bash/tab\tbed.sh'
(
  cd "$QUOTE_F"
  printf 'nl-content\n' > "$ODD_NL_NAME"
  printf 'tab-content\n' > "$ODD_TAB_NAME"
  printf 'plain-content\n' > .logic-loom/scripts/bash/plain-after.sh
  git add -A
  git commit -q -m "B: newline- and tab-named files, plus a plain one"
  git rev-parse HEAD > .sdd-sync-ref
  git update-ref refs/loom-upstream/main HEAD
)
ODD_ERR="$WORKDIR/odd-reconcile.err"
ODD_OUT="$(bash "$RECORDER_SCRIPT" --root "$QUOTE_F" --reconcile 2>"$ODD_ERR")"
ODD_RC=$?
assert "--reconcile with newline- and tab-named candidates present exits 0 (does not crash, does not refuse the whole run)" \
  "[ $ODD_RC -eq 0 ]"
assert "…still lists the plain candidate next to them as RECONCILE (the odd names did not poison the rest)" \
  "printf '%s\n' '$ODD_OUT' | grep -qF 'RECONCILE .logic-loom/scripts/bash/plain-after.sh'"
assert "…and names BOTH odd paths on stderr as skipped (never silently dropped)" \
  "[ \"\$(grep -c 'skipping a path whose name contains a tab or newline' '$ODD_ERR')\" -eq 2 ]"
bash "$RECORDER_SCRIPT" --root "$QUOTE_F" --reconcile --apply >/dev/null 2>&1
ODD_APPLY_RC=$?
ODD_RECORDED="$(python3 -c "
import json
d = json.load(open('$QUOTE_F/.logicloom-adopt-receipt.json'))
paths = [w['path'] for r in d['runs'] for w in r['wrote'] if w.get('kind') == 'file']
bad = [p for p in paths if ('\n' in p or '\t' in p or 'new' in p or 'tab' in p)]
print('plain' if '.logic-loom/scripts/bash/plain-after.sh' in paths and not bad else 'BAD:' + repr(bad) + repr(paths))
")"
assert "…--apply exits 0, records the plain candidate, and records NOTHING for either odd name — no mangled variant, no wrong-column entry" \
  "[ $ODD_APPLY_RC -eq 0 ] && [ '$ODD_RECORDED' = 'plain' ]"
ODD_REC_OUT="$(bash "$RECORDER_SCRIPT" --root "$QUOTE_F" --version v7.0.0 "$ODD_NL_NAME" 2>&1)"
ODD_REC_RC=$?
ODD_REC_SAYS_WHY=0
printf '%s' "$ODD_REC_OUT" | grep -q 'contains a tab or newline' && ODD_REC_SAYS_WHY=1
assert "record mode asked to record a newline-named path by name REFUSES (exit 2, says why) instead of writing a corrupt entry" \
  "[ $ODD_REC_RC -eq 2 ] && [ $ODD_REC_SAYS_WHY -eq 1 ]"

# ─────────────────────────────────────────────────────────────────────────
# E2. Same-run re-extraction after recording (finding: Step 3 extracts
# against the OLD sync-ref; Step 7b records/reconciles; Step 8 then advances
# .sdd-sync-ref straight past the recording with no re-extraction in between,
# so a real upstream change to a path unowned at Step 3 was permanently
# stranded even though this run's own recording would have unblocked it).
# The docs fix (WP2) inserts a re-check step, "Proposals unlocked by this
# run's recording", that re-runs extraction ONCE MORE against the SAME
# (still-unmoved) .sdd-sync-ref before Step 6/Step 8 moves it, and instructs
# comparing the result by path against Step 3's original list: any path Step
# 3 never listed is the unlock.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "E2. Same-run re-extraction after recording (the Step 3->7b->8 gap, closed)"

CMD_DOC="$REAL_ROOT/plugins/loom-maintenance/commands/update-framework.md"
SKILL_DOC="$REAL_ROOT/plugins/loom-maintenance/skills/framework-updater/SKILL.md"
assert "update-framework.md carries the phrase verbatim" \
  "grep -qF \"Proposals unlocked by this run's recording\" '$CMD_DOC'"
assert "framework-updater/SKILL.md carries the phrase verbatim" \
  "grep -qF \"Proposals unlocked by this run's recording\" '$SKILL_DOC'"
# Ordering, by line number (same idiom as test_release_migrations.sh §F): the
# re-check step must sit AFTER the recorder is invoked (Step 5 / Step 7b) and
# BEFORE the sync-ref is moved (Step 6 / Step 8) — a re-check step placed
# after the sync-ref already moved would be checking a ref that has already
# advanced past the very commits it needs to re-scan.
CMD_STEP5_LN="$(grep -n '^### Step 5:' "$CMD_DOC" | head -1 | cut -d: -f1)"
CMD_STEP6_LN="$(grep -n '^### Step 6:' "$CMD_DOC" | head -1 | cut -d: -f1)"
CMD_UNLOCK_LN="$(grep -nF "Proposals unlocked by this run's recording" "$CMD_DOC" | head -1 | cut -d: -f1)"
assert "update-framework.md: the re-check sits between Step 5 and Step 6 ($CMD_STEP5_LN < $CMD_UNLOCK_LN < $CMD_STEP6_LN)" \
  "[ '$CMD_STEP5_LN' -lt '$CMD_UNLOCK_LN' ] && [ '$CMD_UNLOCK_LN' -lt '$CMD_STEP6_LN' ]"
SKILL_STEP7B_LN="$(grep -n '^### Step 7b:' "$SKILL_DOC" | head -1 | cut -d: -f1)"
SKILL_STEP8_LN="$(grep -n '^### Step 8:' "$SKILL_DOC" | head -1 | cut -d: -f1)"
SKILL_UNLOCK_LN="$(grep -nF "Proposals unlocked by this run's recording" "$SKILL_DOC" | head -1 | cut -d: -f1)"
assert "SKILL.md: the re-check sits between Step 7b and Step 8 ($SKILL_STEP7B_LN < $SKILL_UNLOCK_LN < $SKILL_STEP8_LN)" \
  "[ '$SKILL_STEP7B_LN' -lt '$SKILL_UNLOCK_LN' ] && [ '$SKILL_UNLOCK_LN' -lt '$SKILL_STEP8_LN' ]"
assert "the re-check instructs re-running extraction against the SAME (unmoved) sync-ref (both docs)" \
  "grep -qF 'the same \`.sdd-sync-ref\`' '$CMD_DOC' && grep -qF 'the same \`.sdd-sync-ref\`' '$SKILL_DOC'"
assert "the re-check instructs comparing by path against Step 3's list (both docs), and the command doc names the unlock rule" \
  "grep -qF 'compare by path against' '$CMD_DOC' && grep -qF 'compare by path against' '$SKILL_DOC' \
   && grep -qF 'A path Step 3 never listed is the unlock' '$CMD_DOC'"

# The mechanism itself, proven end-to-end against the EXACT scenario the
# fixture above just built — not a fresh fixture, so this is provably the
# SAME single run the reconcile/apply assertions above just exercised, with
# .sdd-sync-ref never touched (still RECON_SHA_B; nothing in this suite ever
# runs the real Step 6/Step 8 "git rev-parse ... > .sdd-sync-ref" write):
#   RBC_OUT  = "Step 3" — extraction at B before this run recorded anything
#              (asserted above: m.sh silently suppressed, not even listed).
#   RBC2_OUT = "the re-check" — extraction at the SAME B, after --reconcile
#              --apply recorded newdir/ (asserted above: m.sh now offered).
# The doc's own algorithm is "a path Step 3 never listed is the unlock" — so
# assert that literally: m.sh must be ABSENT from RBC_OUT's path set and
# PRESENT in RBC2_OUT's, and it must be the ONLY path that differs between
# the two (the re-check does not spuriously unlock anything else).
assert "\$RECON_F/.sdd-sync-ref is still B — this is genuinely the SAME run, sync-ref never advanced" \
  "[ \"\$(cat '$RECON_F/.sdd-sync-ref')\" = '$RECON_SHA_B' ]"
assert "the unlock is EXACTLY the delta between Step 3's list (RBC_OUT) and the re-check (RBC2_OUT): {.logic-loom/newdir/m.sh}" \
  "python3 -c '
import json
before = json.load(open(\"$RBC_OUT\"))
after = json.load(open(\"$RBC2_OUT\"))
before_paths = {p[\"upstream_file\"] for p in before}
after_paths = {p[\"upstream_file\"] for p in after}
unlocked = after_paths - before_paths
assert unlocked == {\".logic-loom/newdir/m.sh\"}, unlocked
'"

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
  # Round-2 finding 1: --reconcile refuses a sync-ref that refs/loom-upstream/
  # main does not reach; this case is about ZERO candidates, not about that.
  git update-ref refs/loom-upstream/main HEAD
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
# I. Recorded digest is the UPSTREAM BLOB, never current (possibly
#    customised) disk bytes — round-2 cross-provider finding.
#
# THE BUG (pre-fix): plain record mode hashed the file's CURRENT bytes on
# disk. The documented use of plain record is precisely to record a file the
# adopter customised AFTER accepting it via /update-framework (see
# --reconcile's own "record it explicitly" hint, exercised in section E
# above) — so the customised bytes became the "recorded" digest, and
# apply.js's uninstallProcedure() reads a digest MATCH as "safe to delete":
# net effect, uninstall would delete the adopter's own edits.
#
# THE FIX: record the sha256 of the upstream blob at .sdd-sync-ref (falling
# back to refs/loom-upstream/main), so a customised file's recorded digest
# provably differs from its current disk bytes — a MISMATCH, which
# uninstallProcedure()'s own step-1 prose reads as KEEP. Proven end-to-end
# below against the real packaging code, not just against the recorder's own
# receipt fields.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "I. Recorded digest is the upstream blob, never current disk bytes"

DIGEST_F="$WORKDIR/digest-upstream"
mkdir -p "$DIGEST_F/.logic-loom/scripts/bash"
(
  cd "$DIGEST_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "upstream-original-content" > .logic-loom/scripts/bash/d.sh
  git add -A
  git commit -q -m "U1: upstream baseline"
)
DIGEST_SHA_U1="$(git -C "$DIGEST_F" rev-parse HEAD)"
echo "$DIGEST_SHA_U1" > "$DIGEST_F/.sdd-sync-ref"
# Round-2 finding 1: the sync-ref is a baseline only when refs/loom-upstream/
# main exists and reaches it (here: the same commit — reachability includes
# equality).
git -C "$DIGEST_F" update-ref refs/loom-upstream/main "$DIGEST_SHA_U1"
cat > "$DIGEST_F/.logicloom-adopt-receipt.json" <<JSON
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-08-31T00:00:00.000Z",
      "generator": "logicloom@7.0.0",
      "status": "complete",
      "wrote": [
        {"target": "harness", "path": ".logic-loom/", "kind": "dir"},
        {"target": "harness", "path": ".logic-loom/scripts/", "kind": "dir"},
        {"target": "harness", "path": ".logic-loom/scripts/bash/", "kind": "dir"}
      ],
      "skipped": [],
      "failed": [],
      "notAttempted": []
    }
  ],
  "uninstall": {}
}
JSON

# Simulate: the adopter accepted d.sh via /update-framework, THEN customised
# it -- exactly the scenario --reconcile's DIFFERS hint targets.
echo "adopter-customised-content" > "$DIGEST_F/.logic-loom/scripts/bash/d.sh"
DIGEST_CUSTOM_SHA="$(sha256_of "$DIGEST_F/.logic-loom/scripts/bash/d.sh")"
DIGEST_EXPECT_UPSTREAM_SHA="$(sha256_of_blob "$DIGEST_F" "${DIGEST_SHA_U1}:.logic-loom/scripts/bash/d.sh")"
assert "sanity: the upstream digest and the customised disk digest actually differ" \
  "[ '$DIGEST_EXPECT_UPSTREAM_SHA' != '$DIGEST_CUSTOM_SHA' ]"

DIGEST_RECORD_OUT="$(bash "$RECORDER_SCRIPT" --root "$DIGEST_F" --version v7.0.0 .logic-loom/scripts/bash/d.sh 2>&1)"
DIGEST_RECORD_EXIT=$?
assert "recording a customised file exits 0" "[ $DIGEST_RECORD_EXIT -eq 0 ]"

DIGEST_RECEIPT="$DIGEST_F/.logicloom-adopt-receipt.json"
DIGEST_GOT_SHA="$(json_run_wrote_sha "$DIGEST_RECEIPT" 1 ".logic-loom/scripts/bash/d.sh")"
assert "recorded sha256 for a customised file is the UPSTREAM blob's digest" \
  "[ '$DIGEST_GOT_SHA' = '$DIGEST_EXPECT_UPSTREAM_SHA' ]"
assert "recorded sha256 is NOT the customised file's own (current) disk digest" \
  "[ '$DIGEST_GOT_SHA' != '$DIGEST_CUSTOM_SHA' ]"

# End-to-end: build the uninstall procedure with the REAL packaging code and
# assert the customised file is not eligible for deletion -- per
# uninstallProcedure()'s own step-1 prose ("digest MATCHES -> delete;
# MISMATCHES -> KEEP"), a mismatch against the customised disk bytes is what
# "not in the delete list" means for a file this tool never deletes itself.
if [ -f "$APPLY_LIB" ] && command -v node >/dev/null 2>&1; then
  DIGEST_UNINSTALL_VERDICT="$(node -e '
    const fs = require("fs");
    const crypto = require("crypto");
    const a = require(process.argv[1]);
    const receipt = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
    const u = a.uninstallProcedure(receipt);
    const entry = u.remove.files.find(f => f.path === ".logic-loom/scripts/bash/d.sh");
    if (!entry) { process.stdout.write("MISSING"); process.exit(0); }
    const diskSha = "sha256:" + crypto.createHash("sha256").update(fs.readFileSync(process.argv[3])).digest("hex");
    process.stdout.write(entry.sha256 === diskSha ? "MATCH" : "MISMATCH");
  ' "$APPLY_LIB" "$DIGEST_RECEIPT" "$DIGEST_F/.logic-loom/scripts/bash/d.sh")"
  assert "end-to-end (real apply.js): the customised file's recorded entry IS present in remove.files (tracked)" \
    "[ '$DIGEST_UNINSTALL_VERDICT' != 'MISSING' ]"
  assert "end-to-end (real apply.js): the recorded digest MISMATCHES the customised disk bytes -> uninstall KEEPS it, never deletes the adopter's edit" \
    "[ '$DIGEST_UNINSTALL_VERDICT' = 'MISMATCH' ]"
else
  skip "end-to-end uninstall keep-on-mismatch for a customised file" "packaging/adopt/lib/apply.js not present (stripped tree) or node unavailable"
fi

# --reconcile's own recordings (section E, b.sh and n.sh) are byte-identical
# to sync-ref BY CONSTRUCTION (that is what makes them RECONCILE and not
# DIFFERS) -- but this asserts it against the independent blob-hash oracle,
# not merely against the disk file the recorder also read, so it actually
# pins "stamps the upstream digest" rather than an accident of equal inputs.
RECON_EXPECT_SHA_B="$(sha256_of_blob "$RECON_F" "${RECON_SHA_B}:.logic-loom/scripts/bash/b.sh")"
RECON_GOT_SHA_B="$(json_run_wrote_sha "$RECON_RECEIPT" 1 ".logic-loom/scripts/bash/b.sh")"
assert "--reconcile --apply also stamps the upstream blob's digest for b.sh (independent oracle)" \
  "[ '$RECON_GOT_SHA_B' = '$RECON_EXPECT_SHA_B' ]"
RECON_EXPECT_SHA_N="$(sha256_of_blob "$RECON_F" "${RECON_SHA_B}:.logic-loom/newdir/n.sh")"
RECON_GOT_SHA_N="$(json_run_wrote_sha "$RECON_RECEIPT" 1 ".logic-loom/newdir/n.sh")"
assert "--reconcile --apply also stamps the upstream blob's digest for n.sh (independent oracle)" \
  "[ '$RECON_GOT_SHA_N' = '$RECON_EXPECT_SHA_N' ]"

echo ""
echo "I-refusal. No resolvable upstream blob -> refuse, never guess from disk bytes"

NOBLOB_F="$WORKDIR/no-upstream-blob"
mkdir -p "$NOBLOB_F/.logic-loom/scripts/bash"
(
  cd "$NOBLOB_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "upstream-content" > .logic-loom/scripts/bash/known.sh
  git add -A
  git commit -q -m "U1"
)
NOBLOB_SHA="$(git -C "$NOBLOB_F" rev-parse HEAD)"
echo "$NOBLOB_SHA" > "$NOBLOB_F/.sdd-sync-ref"
# Round-2 finding 1: keep the sync-ref PROVABLE (refs/loom-upstream/main
# present and reaching it), so the refusal below is for the reason this
# section states — no blob for the path at either location — and not merely
# the provenance rule refusing the sync-ref first (I-forged-ref covers that).
git -C "$NOBLOB_F" update-ref refs/loom-upstream/main "$NOBLOB_SHA"
cat > "$NOBLOB_F/.logicloom-adopt-receipt.json" <<JSON
{"schema": "logicloom/adopt-receipt@1", "runs": [{"status": "complete", "wrote": [
  {"target": "harness", "path": ".logic-loom/", "kind": "dir"},
  {"target": "harness", "path": ".logic-loom/scripts/", "kind": "dir"},
  {"target": "harness", "path": ".logic-loom/scripts/bash/", "kind": "dir"}
]}], "uninstall": {}}
JSON
# A path present on disk (e.g. the adopter's own file) with NO blob at the
# (provable) sync-ref and none at refs/loom-upstream/main either.
echo "purely-local-content" > "$NOBLOB_F/.logic-loom/scripts/bash/local-only.sh"
NOBLOB_CKSUM_BEFORE="$(cksum "$NOBLOB_F/.logicloom-adopt-receipt.json")"
NOBLOB_OUT="$(bash "$RECORDER_SCRIPT" --root "$NOBLOB_F" --version v7.0.0 .logic-loom/scripts/bash/local-only.sh 2>&1)"
NOBLOB_EXIT=$?
assert "a path with no resolvable upstream blob (neither sync-ref nor refs/loom-upstream/main) is refused with a non-zero exit" \
  "[ $NOBLOB_EXIT -ne 0 ]"
NOBLOB_CKSUM_AFTER="$(cksum "$NOBLOB_F/.logicloom-adopt-receipt.json")"
assert "the refusal leaves the receipt untouched" "[ '$NOBLOB_CKSUM_BEFORE' = '$NOBLOB_CKSUM_AFTER' ]"
NOBLOB_HAS_MSG="$(printf '%s' "$NOBLOB_OUT" | grep -ci 'upstream' || true)"
assert "the refusal message mentions 'upstream' (never silently guesses from disk bytes)" "[ '$NOBLOB_HAS_MSG' -gt 0 ]"

echo ""
echo "I-fallback. refs/loom-upstream/main fallback (mid-run: sync-ref not yet advanced past a fresh clean-add)"

FALLBACK_F="$WORKDIR/upstream-fallback"
mkdir -p "$FALLBACK_F/.logic-loom/scripts/bash"
(
  cd "$FALLBACK_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "u1-content" > .logic-loom/scripts/bash/known.sh
  git add -A
  git commit -q -m "U1"
)
FALLBACK_SHA_U1="$(git -C "$FALLBACK_F" rev-parse HEAD)"
(
  cd "$FALLBACK_F"
  echo "u2-new-file-content" > .logic-loom/scripts/bash/fresh.sh
  git add -A
  git commit -q -m "U2: upstream adds fresh.sh"
)
FALLBACK_SHA_U2="$(git -C "$FALLBACK_F" rev-parse HEAD)"
# .sdd-sync-ref is still U1 (Step 8 advances it AFTER the recorder runs, per
# update-framework.md / SKILL.md) -- but this run's own ad-hoc fetch already
# populated refs/loom-upstream/main at U2, and the clean-add step just wrote
# fresh.sh's U2 bytes onto disk.
echo "$FALLBACK_SHA_U1" > "$FALLBACK_F/.sdd-sync-ref"
git -C "$FALLBACK_F" update-ref refs/loom-upstream/main "$FALLBACK_SHA_U2"
git -C "$FALLBACK_F" show "${FALLBACK_SHA_U2}:.logic-loom/scripts/bash/fresh.sh" > "$FALLBACK_F/.logic-loom/scripts/bash/fresh.sh"
cat > "$FALLBACK_F/.logicloom-adopt-receipt.json" <<JSON
{"schema": "logicloom/adopt-receipt@1", "runs": [{"status": "complete", "wrote": [
  {"target": "harness", "path": ".logic-loom/", "kind": "dir"},
  {"target": "harness", "path": ".logic-loom/scripts/", "kind": "dir"},
  {"target": "harness", "path": ".logic-loom/scripts/bash/", "kind": "dir"}
]}], "uninstall": {}}
JSON

FALLBACK_OUT="$(bash "$RECORDER_SCRIPT" --root "$FALLBACK_F" --version v7.0.0 .logic-loom/scripts/bash/fresh.sh 2>&1)"
FALLBACK_EXIT=$?
assert "a path absent at sync-ref but present at refs/loom-upstream/main is recorded via the fallback (exit 0)" \
  "[ $FALLBACK_EXIT -eq 0 ]"
FALLBACK_RECEIPT="$FALLBACK_F/.logicloom-adopt-receipt.json"
FALLBACK_GOT_SHA="$(json_run_wrote_sha "$FALLBACK_RECEIPT" 1 ".logic-loom/scripts/bash/fresh.sh")"
FALLBACK_EXPECT_SHA="$(sha256_of_blob "$FALLBACK_F" "${FALLBACK_SHA_U2}:.logic-loom/scripts/bash/fresh.sh")"
assert "recorded digest via the refs/loom-upstream/main fallback matches that ref's blob (independent oracle)" \
  "[ '$FALLBACK_GOT_SHA' = '$FALLBACK_EXPECT_SHA' ]"

# ─────────────────────────────────────────────────────────────────────────
# I-apply. Live run, clean-APPLY of an already-recorded file: the digest
#          must be what LogicLoom JUST WROTE, not the stale sync-ref blob.
#
# THE SECOND BUG (found reviewing the first fix). Resolving .sdd-sync-ref
# FIRST is right for a path that exists nowhere else -- but Step 7b runs the
# recorder DURING /update-framework, when .sdd-sync-ref still names the OLD
# commit and refs/loom-upstream/main the NEW one, and the clean-apply
# (`git show refs/loom-upstream/main:P > P`, SKILL.md Step 7) has just put
# the NEW bytes on disk. For a path that exists at BOTH commits (a
# modification -- the common case; the builder's I-fallback covers only an
# add), sync-ref-first stamps the OLD blob's digest. The install receipt
# already carries exactly that digest, so the entry is then dropped as
# "nothing new to record" and the receipt goes on saying "LogicLoom left
# <old bytes>" about a file that provably holds <new bytes> LogicLoom wrote.
# Safe direction (a MISMATCH reads as KEEP) -- but a stale digest and a
# broken promise (the marker's own untilThen text: "the sha256 of the bytes
# this harness left there").
#
# THE RULE that fixes it without ever guessing: both blobs are provably
# LogicLoom's. When the disk bytes are byte-identical to one of them, THAT
# blob is what LogicLoom wrote here (the OWNERSHIP RULE: a byte-identical
# copy of an upstream blob can only have come from upstream). The disk is
# consulted only to CHOOSE between two upstream digests; the recorded digest
# is always an upstream blob's, never the disk's own -- see I-break below.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "I-apply. Live clean-apply of a recorded file: the digest is the blob LogicLoom just wrote, not the stale sync-ref blob"

APPLY_F="$WORKDIR/live-clean-apply"
mkdir -p "$APPLY_F/.logic-loom/scripts/bash"
(
  cd "$APPLY_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "p-v1-content" > .logic-loom/scripts/bash/p.sh
  git add -A
  git commit -q -m "U1"
)
APPLY_SHA_U1="$(git -C "$APPLY_F" rev-parse HEAD)"
(
  cd "$APPLY_F"
  echo "p-v2-content" > .logic-loom/scripts/bash/p.sh
  git add -A
  git commit -q -m "U2: upstream modifies p.sh"
)
APPLY_SHA_U2="$(git -C "$APPLY_F" rev-parse HEAD)"
APPLY_SHA_P_U1="$(sha256_of_blob "$APPLY_F" "${APPLY_SHA_U1}:.logic-loom/scripts/bash/p.sh")"
APPLY_SHA_P_U2="$(sha256_of_blob "$APPLY_F" "${APPLY_SHA_U2}:.logic-loom/scripts/bash/p.sh")"
assert "sanity: U1 and U2 blobs of p.sh differ" "[ '$APPLY_SHA_P_U1' != '$APPLY_SHA_P_U2' ]"
# Install-time receipt: p.sh recorded with U1's digest -- what apply.js hashed
# when it wrote U1's bytes at `npx logicloom init` time.
APPLY_RECEIPT="$APPLY_F/.logicloom-adopt-receipt.json"
cat > "$APPLY_RECEIPT" <<JSON
{"schema": "logicloom/adopt-receipt@1", "runs": [{"status": "complete", "wrote": [
  {"target": "harness", "path": ".logic-loom/", "kind": "dir"},
  {"target": "harness", "path": ".logic-loom/scripts/", "kind": "dir"},
  {"target": "harness", "path": ".logic-loom/scripts/bash/", "kind": "dir"},
  {"target": "harness", "path": ".logic-loom/scripts/bash/p.sh", "kind": "file", "sha256": "$APPLY_SHA_P_U1"}
]}], "uninstall": {}}
JSON
# Mid-run state, exactly as Step 7b sees it: .sdd-sync-ref still U1, the
# scratch ref at U2, and the clean-apply has just landed U2's bytes.
echo "$APPLY_SHA_U1" > "$APPLY_F/.sdd-sync-ref"
git -C "$APPLY_F" update-ref refs/loom-upstream/main "$APPLY_SHA_U2"
git -C "$APPLY_F" show "${APPLY_SHA_U2}:.logic-loom/scripts/bash/p.sh" > "$APPLY_F/.logic-loom/scripts/bash/p.sh"
APPLY_DISK_SHA="$(sha256_of "$APPLY_F/.logic-loom/scripts/bash/p.sh")"
assert "sanity: the clean-apply left U2's bytes on disk" "[ '$APPLY_DISK_SHA' = '$APPLY_SHA_P_U2' ]"

APPLY_OUT="$(bash "$RECORDER_SCRIPT" --root "$APPLY_F" --version v7.0.0 .logic-loom/scripts/bash/p.sh 2>&1)"
APPLY_EXIT=$?
assert "live clean-apply: recorder exits 0" "[ $APPLY_EXIT -eq 0 ]"
APPLY_RUNS="$(json_runs_count "$APPLY_RECEIPT")"
assert "live clean-apply: a NEW run is appended -- the bytes LogicLoom just wrote are new information, not 'nothing new to record'" \
  "[ '$APPLY_RUNS' = '2' ]"
APPLY_GOT_SHA="$(json_run_wrote_sha "$APPLY_RECEIPT" 1 ".logic-loom/scripts/bash/p.sh" 2>/dev/null || true)"
assert "live clean-apply: the recorded digest is the U2 blob LogicLoom JUST WROTE (independent oracle)" \
  "[ '$APPLY_GOT_SHA' = '$APPLY_SHA_P_U2' ]"
assert "live clean-apply: the recorded digest is NOT the stale U1 (sync-ref) blob" \
  "[ '$APPLY_GOT_SHA' != '$APPLY_SHA_P_U1' ]"
if [ -f "$APPLY_LIB" ] && command -v node >/dev/null 2>&1; then
  APPLY_VERDICT="$(uninstall_verdict "$APPLY_LIB" "$APPLY_RECEIPT" ".logic-loom/scripts/bash/p.sh" "$APPLY_F/.logic-loom/scripts/bash/p.sh" | cut -d' ' -f1)"
  assert "end-to-end (real apply.js): a pristine clean-applied file MATCHES its recorded digest -- it is exactly what LogicLoom left, nothing of the adopter's is in it" \
    "[ '$APPLY_VERDICT' = 'MATCH' ]"
else
  skip "end-to-end MATCH for a pristine clean-applied file" "packaging/adopt/lib/apply.js not present (stripped tree) or node unavailable"
fi
# A second, identical call right after: same upstream digest already recorded -> nothing new.
APPLY_CKSUM_BEFORE="$(cksum "$APPLY_RECEIPT")"
APPLY_OUT2="$(bash "$RECORDER_SCRIPT" --root "$APPLY_F" --version v7.0.0 .logic-loom/scripts/bash/p.sh 2>&1)"
APPLY_CKSUM_AFTER="$(cksum "$APPLY_RECEIPT")"
assert "live clean-apply: a second identical call is a no-op (nothing new to record, receipt untouched)" \
  "printf '%s' '$APPLY_OUT2' | grep -q 'nothing new to record' && [ '$APPLY_CKSUM_BEFORE' = '$APPLY_CKSUM_AFTER' ]"

# ─────────────────────────────────────────────────────────────────────────
# I-break. Trying to make the recorder license deletion of bytes the
#          adopter wrote. GOVERNING PRINCIPLE: a customer's work is never
#          deleted, or recommended for deletion, on evidence that is not
#          provably LogicLoom's. The only verdict apply.js's step 1 reads as
#          "safe to delete" is MATCH, so in EVERY state below the real
#          packaging code must return something other than MATCH for a file
#          holding the adopter's own bytes -- and whatever digest the
#          recorder did stamp must be one of the upstream blobs, never the
#          disk's own. These pin the principle: they must pass before AND
#          after any change to the recorder.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "I-break. Trying to make the recorder license deletion of the adopter's own bytes"

# 1. Live window, BOTH upstream blobs exist (U1 at sync-ref, U2 at the
#    scratch ref), and the disk holds the adopter's OWN merge result -- the
#    conflict-review (c)/(d) outcome, then recorded by name.
BREAK1_F="$WORKDIR/break-live-customised"
mkdir -p "$BREAK1_F/.logic-loom/scripts/bash"
(
  cd "$BREAK1_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "p-v1-content" > .logic-loom/scripts/bash/p.sh
  git add -A
  git commit -q -m "U1"
  echo "p-v2-content" > .logic-loom/scripts/bash/p.sh
  git add -A
  git commit -q -m "U2"
)
BREAK1_SHA_U2="$(git -C "$BREAK1_F" rev-parse HEAD)"
BREAK1_SHA_U1="$(git -C "$BREAK1_F" rev-parse HEAD~1)"
BREAK1_SHA_P_U1="$(sha256_of_blob "$BREAK1_F" "${BREAK1_SHA_U1}:.logic-loom/scripts/bash/p.sh")"
BREAK1_SHA_P_U2="$(sha256_of_blob "$BREAK1_F" "${BREAK1_SHA_U2}:.logic-loom/scripts/bash/p.sh")"
BREAK1_RECEIPT="$BREAK1_F/.logicloom-adopt-receipt.json"
cat > "$BREAK1_RECEIPT" <<JSON
{"schema": "logicloom/adopt-receipt@1", "runs": [{"status": "complete", "wrote": [
  {"target": "harness", "path": ".logic-loom/", "kind": "dir"},
  {"target": "harness", "path": ".logic-loom/scripts/", "kind": "dir"},
  {"target": "harness", "path": ".logic-loom/scripts/bash/", "kind": "dir"},
  {"target": "harness", "path": ".logic-loom/scripts/bash/p.sh", "kind": "file", "sha256": "$BREAK1_SHA_P_U1"}
]}], "uninstall": {}}
JSON
echo "$BREAK1_SHA_U1" > "$BREAK1_F/.sdd-sync-ref"
git -C "$BREAK1_F" update-ref refs/loom-upstream/main "$BREAK1_SHA_U2"
printf 'p-v2-content\n# plus the adopter'"'"'s own merged addition\n' > "$BREAK1_F/.logic-loom/scripts/bash/p.sh"
BREAK1_DISK_SHA="$(sha256_of "$BREAK1_F/.logic-loom/scripts/bash/p.sh")"
assert "break-1 sanity: the adopter's bytes equal NEITHER upstream blob" \
  "[ '$BREAK1_DISK_SHA' != '$BREAK1_SHA_P_U1' ] && [ '$BREAK1_DISK_SHA' != '$BREAK1_SHA_P_U2' ]"
bash "$RECORDER_SCRIPT" --root "$BREAK1_F" --version v7.0.0 .logic-loom/scripts/bash/p.sh >/dev/null 2>&1
BREAK1_EXIT=$?
assert "break-1: recording the adopter's merged file by name does not fail (exit 0, recorded or dropped -- either is allowed)" \
  "[ $BREAK1_EXIT -eq 0 ]"
if [ -f "$APPLY_LIB" ] && command -v node >/dev/null 2>&1; then
  BREAK1_V="$(uninstall_verdict "$APPLY_LIB" "$BREAK1_RECEIPT" ".logic-loom/scripts/bash/p.sh" "$BREAK1_F/.logic-loom/scripts/bash/p.sh")"
  BREAK1_VERDICT="$(printf '%s' "$BREAK1_V" | cut -d' ' -f1)"
  BREAK1_LAST_SHA="$(printf '%s' "$BREAK1_V" | cut -d' ' -f2)"
  assert "break-1 (real apply.js): the adopter's merged bytes are NEVER a MATCH (verdict=$BREAK1_VERDICT) -> KEEP" \
    "[ '$BREAK1_VERDICT' = 'MISMATCH' ]"
  assert "break-1: whatever digest is on record is one of the two UPSTREAM blobs, never the disk's own" \
    "[ '$BREAK1_LAST_SHA' = '$BREAK1_SHA_P_U1' ] || [ '$BREAK1_LAST_SHA' = '$BREAK1_SHA_P_U2' ]"
  assert "break-1: the digest on record is not the adopter's disk digest" \
    "[ '$BREAK1_LAST_SHA' != '$BREAK1_DISK_SHA' ]"
else
  skip "break-1 end-to-end" "packaging/adopt/lib/apply.js not present (stripped tree) or node unavailable"
fi

# 2. The adopter's OWN file sits at a path upstream ADDS this run (the blob
#    exists at the scratch ref only; the proposal would be an add-conflict).
#    Recording it by name must establish ownership with the UPSTREAM digest
#    -- which then mismatches the adopter's bytes -> KEEP.
BREAK2_F="$WORKDIR/break-add-collision"
mkdir -p "$BREAK2_F/.logic-loom/scripts/bash"
(
  cd "$BREAK2_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "k-content" > .logic-loom/scripts/bash/k.sh
  git add -A
  git commit -q -m "U1"
  echo "upstream-q-content" > .logic-loom/scripts/bash/q.sh
  git add -A
  git commit -q -m "U2: upstream adds q.sh"
)
BREAK2_SHA_U2="$(git -C "$BREAK2_F" rev-parse HEAD)"
BREAK2_SHA_U1="$(git -C "$BREAK2_F" rev-parse HEAD~1)"
BREAK2_SHA_Q_U2="$(sha256_of_blob "$BREAK2_F" "${BREAK2_SHA_U2}:.logic-loom/scripts/bash/q.sh")"
BREAK2_RECEIPT="$BREAK2_F/.logicloom-adopt-receipt.json"
cat > "$BREAK2_RECEIPT" <<JSON
{"schema": "logicloom/adopt-receipt@1", "runs": [{"status": "complete", "wrote": [
  {"target": "harness", "path": ".logic-loom/", "kind": "dir"},
  {"target": "harness", "path": ".logic-loom/scripts/", "kind": "dir"},
  {"target": "harness", "path": ".logic-loom/scripts/bash/", "kind": "dir"}
]}], "uninstall": {}}
JSON
echo "$BREAK2_SHA_U1" > "$BREAK2_F/.sdd-sync-ref"
git -C "$BREAK2_F" update-ref refs/loom-upstream/main "$BREAK2_SHA_U2"
echo "the adopter wrote this q.sh long before upstream had one" > "$BREAK2_F/.logic-loom/scripts/bash/q.sh"
BREAK2_DISK_SHA="$(sha256_of "$BREAK2_F/.logic-loom/scripts/bash/q.sh")"
bash "$RECORDER_SCRIPT" --root "$BREAK2_F" --version v7.0.0 .logic-loom/scripts/bash/q.sh >/dev/null 2>&1
BREAK2_EXIT=$?
assert "break-2: an add-collision file recorded by name is accepted (exit 0)" "[ $BREAK2_EXIT -eq 0 ]"
BREAK2_GOT_SHA="$(json_run_wrote_sha "$BREAK2_RECEIPT" 1 ".logic-loom/scripts/bash/q.sh" 2>/dev/null || true)"
assert "break-2: the recorded digest is the UPSTREAM (scratch-ref) blob's, not the adopter's bytes" \
  "[ '$BREAK2_GOT_SHA' = '$BREAK2_SHA_Q_U2' ] && [ '$BREAK2_GOT_SHA' != '$BREAK2_DISK_SHA' ]"
if [ -f "$APPLY_LIB" ] && command -v node >/dev/null 2>&1; then
  BREAK2_VERDICT="$(uninstall_verdict "$APPLY_LIB" "$BREAK2_RECEIPT" ".logic-loom/scripts/bash/q.sh" "$BREAK2_F/.logic-loom/scripts/bash/q.sh" | cut -d' ' -f1)"
  assert "break-2 (real apply.js): the adopter's pre-existing q.sh is a MISMATCH -> KEEP, never deleted on this record's word" \
    "[ '$BREAK2_VERDICT' = 'MISMATCH' ]"
else
  skip "break-2 end-to-end" "packaging/adopt/lib/apply.js not present (stripped tree) or node unavailable"
fi

# 3. The adopter's own file that exists at NEITHER location: I-refusal above
#    (refused, exit 2, receipt untouched). 4. An adopter file that IS
#    byte-identical to an upstream blob comes back MATCH -- by construction
#    it holds nothing upstream does not; that is the OWNERSHIP RULE, and
#    exactly what --reconcile already records on its own. Not a break.

# ─────────────────────────────────────────────────────────────────────────
# I-stale-ref. A scratch ref left behind by an earlier run must not poison
#              a record made OUTSIDE a run. SKILL.md says refs/loom-upstream/
#              main is pruned after the run, but only extract-proposals.sh
#              --dry-run actually prunes it (extract-proposals.sh:762); the
#              extract path leaves it in place. So "the scratch ref exists"
#              does NOT mean "an update is in progress", and a rule that
#              blindly preferred it would stamp a NEWER blob's digest onto a
#              file that still holds the sync-ref bytes: a false MISMATCH
#              (safe, but wrong) for a provably pristine file. The
#              disk-match rule picks the sync-ref blob here.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "I-stale-ref. A leftover scratch ref must not mis-stamp a pristine sync-ref file"

STALE_F="$WORKDIR/stale-scratch-ref"
mkdir -p "$STALE_F/.logic-loom/scripts/bash"
(
  cd "$STALE_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "p-v1-content" > .logic-loom/scripts/bash/p.sh
  git add -A
  git commit -q -m "U1"
  echo "p-v2-content" > .logic-loom/scripts/bash/p.sh
  git add -A
  git commit -q -m "U2"
)
STALE_SHA_U2="$(git -C "$STALE_F" rev-parse HEAD)"
STALE_SHA_U1="$(git -C "$STALE_F" rev-parse HEAD~1)"
# Downstream never took U2: tree back at U1, sync-ref U1 -- but the scratch
# ref from an earlier (abandoned) run still points at U2.
git -C "$STALE_F" reset -q --hard "$STALE_SHA_U1"
# round-2 review: record-update-writes.sh stamps runs[].generator as
# "logicloom-update-framework@<VERSION>", and VERSION falls back to
# FRAMEWORK_VERSION in .logic-loom/config/architecture.conf when --version is
# not passed (as the calls below do not). Without this file VERSION is empty
# and the generator string has nothing after '@' -- which TRUSTED_GENERATOR_RE
# (requiring 1+ chars after '@', deliberately, so a bare "...@" typo/truncation
# is never trusted either) correctly does not match. Untracked is enough:
# default_version() reads it live off disk, never from git history.
mkdir -p "$STALE_F/.logic-loom/config"
printf 'FRAMEWORK_VERSION=7.0.0\n' > "$STALE_F/.logic-loom/config/architecture.conf"
echo "$STALE_SHA_U1" > "$STALE_F/.sdd-sync-ref"
git -C "$STALE_F" update-ref refs/loom-upstream/main "$STALE_SHA_U2"
STALE_SHA_P_U1="$(sha256_of_blob "$STALE_F" "${STALE_SHA_U1}:.logic-loom/scripts/bash/p.sh")"
STALE_SHA_P_U2="$(sha256_of_blob "$STALE_F" "${STALE_SHA_U2}:.logic-loom/scripts/bash/p.sh")"
STALE_DISK_SHA="$(sha256_of "$STALE_F/.logic-loom/scripts/bash/p.sh")"
assert "stale-ref sanity: disk holds the U1 (sync-ref) bytes, and the stale scratch ref's blob differs" \
  "[ '$STALE_DISK_SHA' = '$STALE_SHA_P_U1' ] && [ '$STALE_SHA_P_U1' != '$STALE_SHA_P_U2' ]"
STALE_RECEIPT="$STALE_F/.logicloom-adopt-receipt.json"
cat > "$STALE_RECEIPT" <<JSON
{"schema": "logicloom/adopt-receipt@1", "runs": [{"generator": "logicloom-update-framework@7.0.0", "status": "complete", "wrote": [
  {"target": "harness", "path": ".logic-loom/", "kind": "dir"},
  {"target": "harness", "path": ".logic-loom/scripts/", "kind": "dir"},
  {"target": "harness", "path": ".logic-loom/scripts/bash/", "kind": "dir"}
]}], "uninstall": {}}
JSON
STALE_RECON_OUT="$(bash "$RECORDER_SCRIPT" --root "$STALE_F" --reconcile 2>&1)"
assert "stale-ref: --reconcile still lists p.sh as RECONCILE (byte-identical to sync-ref)" \
  "printf '%s\n' '$STALE_RECON_OUT' | grep -qF 'RECONCILE .logic-loom/scripts/bash/p.sh'"
bash "$RECORDER_SCRIPT" --root "$STALE_F" --reconcile --apply >/dev/null 2>&1
STALE_GOT_SHA="$(json_run_wrote_sha "$STALE_RECEIPT" 1 ".logic-loom/scripts/bash/p.sh" 2>/dev/null || true)"
assert "stale-ref: --reconcile --apply stamps the SYNC-REF blob (== disk), not the stale scratch ref's newer blob" \
  "[ '$STALE_GOT_SHA' = '$STALE_SHA_P_U1' ]"
STALE_CKSUM_BEFORE="$(cksum "$STALE_RECEIPT")"
STALE_REC_OUT="$(bash "$RECORDER_SCRIPT" --root "$STALE_F" --version v7.0.0 .logic-loom/scripts/bash/p.sh 2>&1)"
STALE_CKSUM_AFTER="$(cksum "$STALE_RECEIPT")"
assert "stale-ref: a record-mode call for the same pristine file agrees (nothing new to record; receipt untouched)" \
  "printf '%s' '$STALE_REC_OUT' | grep -q 'nothing new to record' && [ '$STALE_CKSUM_BEFORE' = '$STALE_CKSUM_AFTER' ]"

# Round-2 finding 4: the "nothing new to record" assertion just above is NOT
# discriminating on its own — a BUGGY implementation that hashes the working
# tree's CURRENT bytes directly (instead of resolving an upstream blob)
# would ALSO say "nothing new to record" here, for the wrong reason: disk is
# still byte-identical to what was just reconciled. Prove the mechanism is
# actually "record an UPSTREAM blob, never disk bytes" with a customer edit:
# once disk diverges from BOTH upstream candidates, the resolvable upstream
# digest (the sync-ref blob) is UNCHANGED, so record mode must STILL say
# nothing new and append no run — a disk-hashing implementation would
# instead compute a NEW digest (the edited bytes' own) and append one.
STALE_RUNS_BEFORE_EDIT="$(json_runs_count "$STALE_RECEIPT")"
echo "customer edit, after both --reconcile and the pristine record-mode check above" >> "$STALE_F/.logic-loom/scripts/bash/p.sh"
STALE_EDIT_OUT="$(bash "$RECORDER_SCRIPT" --root "$STALE_F" --version v7.0.0 .logic-loom/scripts/bash/p.sh 2>&1)"
STALE_RUNS_AFTER_EDIT="$(json_runs_count "$STALE_RECEIPT")"
assert "stale-ref: record mode NEVER hashes disk bytes — after a customer edit, the resolvable upstream digest is unchanged, so it is still 'nothing new to record' and no run is appended (a disk-hashing implementation would append a new run with the CUSTOMIZED bytes' own digest instead)" \
  "printf '%s' '$STALE_EDIT_OUT' | grep -q 'nothing new to record' && [ '$STALE_RUNS_AFTER_EDIT' = '$STALE_RUNS_BEFORE_EDIT' ]"
git -C "$STALE_F" checkout -q -- .logic-loom/scripts/bash/p.sh 2>/dev/null \
  || printf 'p-v1-content\n' > "$STALE_F/.logic-loom/scripts/bash/p.sh"

if [ -f "$APPLY_LIB" ] && command -v node >/dev/null 2>&1; then
  STALE_VERDICT="$(uninstall_verdict "$APPLY_LIB" "$STALE_RECEIPT" ".logic-loom/scripts/bash/p.sh" "$STALE_F/.logic-loom/scripts/bash/p.sh" | cut -d' ' -f1)"
  assert "stale-ref (real apply.js): the pristine file MATCHES (no false mismatch from the leftover ref)" \
    "[ '$STALE_VERDICT' = 'MATCH' ]"
else
  skip "stale-ref end-to-end" "packaging/adopt/lib/apply.js not present (stripped tree) or node unavailable"
fi

# ─────────────────────────────────────────────────────────────────────────
# I-forged-ref. Round-2 finding 1 (recorder half — the scanner half is
# covered in tests/contract/test_release_migrations.sh's FIX_SYNC fixture).
# A .sdd-sync-ref naming a CUSTOMER's own commit (not LogicLoom's) must never
# let record mode record a digest against it — with OR without
# refs/loom-upstream/main present, since without it there is no baseline to
# even check reachability against. A genuine, ancestor sync-ref still works.
# This fixture carries the shared lib (.logic-loom/lib/release-migrations.sh)
# so the round-2 fix (loom_sync_ref_is_loom_record) is actually exercised,
# not the pre-round-2 fallback record-update-writes.sh uses when a --root
# tree does not carry it (see that fallback's own comment).
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "I-forged-ref. A forged (customer) sync-ref must never let record mode record against it"

FORGED_F="$WORKDIR/forged-syncref"
mkdir -p "$FORGED_F/.logic-loom/lib" "$FORGED_F/docs"
(
  cd "$FORGED_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "upstream body" > docs/upstream-only.md
  git add -A
  git commit -q -m "U1: upstream ships docs/upstream-only.md"
)
FORGED_U1="$(git -C "$FORGED_F" rev-parse HEAD)"
(
  cd "$FORGED_F"
  echo "more upstream work" > docs/unrelated.md
  git add -A
  git commit -q -m "U2: further upstream work"
)
FORGED_U2="$(git -C "$FORGED_F" rev-parse HEAD)"
git -C "$FORGED_F" branch customer "$FORGED_U1" >/dev/null
git -C "$FORGED_F" checkout -q customer
echo "the customer's own private file, never shipped upstream" > "$FORGED_F/docs/customer-only.md"
git -C "$FORGED_F" add -A
git -C "$FORGED_F" commit -q -m "C1: customer's own commit, off the upstream line"
FORGED_C1="$(git -C "$FORGED_F" rev-parse HEAD)"
# Deliberately stay checked out on "customer" (do NOT switch back to the
# upstream branch): record mode reads docs/customer-only.md off DISK, and
# that path was never committed on the upstream branch at all — switching
# back would delete it from the working tree (git checkout removes a
# tracked-there-but-not-here file) and every call below would fail on "not
# a regular file" before the forged-sync-ref check is ever reached, proving
# nothing about the mechanism under test. docs/upstream-only.md (the
# genuine-ancestor positive control below) is unaffected either way — it
# was committed at U1, an ancestor of "customer" too.
assert "forged-ref fixture: the customer's commit is NOT reachable from U2 (the upstream tip)" \
  "! git -C '$FORGED_F' merge-base --is-ancestor '$FORGED_C1' '$FORGED_U2'"

cp "$REAL_ROOT/.logic-loom/lib/release-migrations.sh" "$FORGED_F/.logic-loom/lib/release-migrations.sh"
cat > "$FORGED_F/.logicloom-adopt-receipt.json" <<'JSON'
{"schema": "logicloom/adopt-receipt@1", "runs": [{"status": "complete", "wrote": [], "skipped": [], "failed": [], "notAttempted": []}]}
JSON

echo "$FORGED_C1" > "$FORGED_F/.sdd-sync-ref"
git -C "$FORGED_F" update-ref refs/loom-upstream/main "$FORGED_U2"
FORGED_OUT_WITH="$(bash "$RECORDER_SCRIPT" --root "$FORGED_F" --version v7.0.0 docs/customer-only.md 2>&1)"
FORGED_RC_WITH=$?
assert "a forged (customer) sync-ref, WITH refs/loom-upstream/main present but unreachable from it, is refused — record mode exits non-zero and names the /update-framework remedy" \
  "[ $FORGED_RC_WITH -ne 0 ] && printf '%s' '$FORGED_OUT_WITH' | grep -q 'refusing to record' && printf '%s' '$FORGED_OUT_WITH' | grep -q '/update-framework'"

git -C "$FORGED_F" update-ref -d refs/loom-upstream/main
FORGED_OUT_NOUP="$(bash "$RECORDER_SCRIPT" --root "$FORGED_F" --version v7.0.0 docs/customer-only.md 2>&1)"
FORGED_RC_NOUP=$?
assert "…and WITHOUT refs/loom-upstream/main at all: also refused (hex shape alone proves nothing with no baseline to check it against)" \
  "[ $FORGED_RC_NOUP -ne 0 ] && printf '%s' '$FORGED_OUT_NOUP' | grep -q 'refusing to record'"

# positive control: a GENUINE ancestor sync-ref still works.
echo "$FORGED_U1" > "$FORGED_F/.sdd-sync-ref"
git -C "$FORGED_F" update-ref refs/loom-upstream/main "$FORGED_U2"
FORGED_OUT_GENUINE="$(bash "$RECORDER_SCRIPT" --root "$FORGED_F" --version v7.0.0 docs/upstream-only.md 2>&1)"
FORGED_RC_GENUINE=$?
# docs/upstream-only.md is being recorded for the first time in this
# fixture, so its ancestor directory (docs/) is recorded alongside it (see
# build_entries's own ancestor-recording contract) -- that is 2 entries, so
# the summary line reads "entries recorded" (plural), not "entry recorded".
# Assert the precise per-entry line instead of the pluralization-sensitive
# summary wording.
assert "…and a GENUINE ancestor sync-ref (a real upstream commit, reachable from refs/loom-upstream/main) still records normally" \
  "[ $FORGED_RC_GENUINE -eq 0 ] && printf '%s' '$FORGED_OUT_GENUINE' | grep -q 'RECORDED docs/upstream-only.md'"

# --reconcile's half of the same finding. The genuine record just above
# recorded docs/ as a dir, so docs/customer-only.md is now exactly what
# --reconcile looks for: an unrecorded file under a recorded directory. With
# the FORGED sync-ref it is byte-identical to "the sync-ref blob" (the
# customer committed it there), so a reconcile that only checks "resolves to
# a commit" prints `RECONCILE docs/customer-only.md` — a recommendation to
# stamp the customer's own file as LogicLoom's. It must refuse instead, for
# the provenance reason, with the remedy, and list nothing.
echo "$FORGED_C1" > "$FORGED_F/.sdd-sync-ref"
git -C "$FORGED_F" update-ref refs/loom-upstream/main "$FORGED_U2"
# (The recorder's messages contain apostrophes, so the outputs are reduced
# to flags here instead of being spliced into the eval'd condition.)
FORGED_RECON_WITH="$(bash "$RECORDER_SCRIPT" --root "$FORGED_F" --reconcile 2>&1)"
FORGED_RECON_RC_WITH=$?
FORGED_RECON_WITH_REASON=0
printf '%s' "$FORGED_RECON_WITH" | grep -q 'not provably LogicLoom' \
  && printf '%s' "$FORGED_RECON_WITH" | grep -q '/update-framework' && FORGED_RECON_WITH_REASON=1
FORGED_RECON_WITH_LISTED=0
printf '%s' "$FORGED_RECON_WITH" | grep -q 'RECONCILE docs/customer-only.md' && FORGED_RECON_WITH_LISTED=1
assert "--reconcile with a forged (customer) sync-ref, refs/loom-upstream/main present but not reaching it: exits 2, names the provenance reason and the /update-framework remedy" \
  "[ $FORGED_RECON_RC_WITH -eq 2 ] && [ $FORGED_RECON_WITH_REASON -eq 1 ]"
assert "…and it lists NOTHING: no 'RECONCILE docs/customer-only.md' recommendation on the customer's own file" \
  "[ $FORGED_RECON_WITH_LISTED -eq 0 ]"
git -C "$FORGED_F" update-ref -d refs/loom-upstream/main
FORGED_RECON_NOUP="$(bash "$RECORDER_SCRIPT" --root "$FORGED_F" --reconcile 2>&1)"
FORGED_RECON_RC_NOUP=$?
FORGED_RECON_NOUP_LISTED=0
printf '%s' "$FORGED_RECON_NOUP" | grep -q 'RECONCILE docs/customer-only.md' && FORGED_RECON_NOUP_LISTED=1
assert "--reconcile with a forged sync-ref and NO refs/loom-upstream/main: also exits 2 and lists nothing (a resolvable commit is not a provable one)" \
  "[ $FORGED_RECON_RC_NOUP -eq 2 ] && [ $FORGED_RECON_NOUP_LISTED -eq 0 ]"
FORGED_RECON_CKSUM_BEFORE="$(cksum "$FORGED_F/.logicloom-adopt-receipt.json")"
bash "$RECORDER_SCRIPT" --root "$FORGED_F" --reconcile --apply >/dev/null 2>&1
FORGED_RECON_CKSUM_AFTER="$(cksum "$FORGED_F/.logicloom-adopt-receipt.json")"
assert "…and --reconcile --apply against the forged sync-ref writes nothing (receipt byte-identical)" \
  "[ '$FORGED_RECON_CKSUM_BEFORE' = '$FORGED_RECON_CKSUM_AFTER' ]"

# ─────────────────────────────────────────────────────────────────────────
# I-forged-ref-nolib. The --root tree does NOT carry the shared lib. This is
# not a synthetic corner: .logic-loom/lib/release-migrations.sh first ships in
# the same release as the recorder, and /update-framework is proposal-based
# SELECTIVE adoption — a 6.x install can accept the recorder and decline (or
# not yet have applied) the lib. A recorder whose no-lib fallback reverted to
# the pre-round-2 rule (hex shape alone) would make exactly that tree the one
# place a forged sync-ref still records the customer's own digest as
# LogicLoom's. The rule must be the SAME strict rule with or without the lib.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "I-forged-ref-nolib. The same refusals hold on a --root tree that does not carry the shared lib"

rm -f "$FORGED_F/.logic-loom/lib/release-migrations.sh"
assert "nolib fixture sanity: the shared lib is absent from the --root tree" \
  "[ ! -e '$FORGED_F/.logic-loom/lib/release-migrations.sh' ]"
echo "$FORGED_C1" > "$FORGED_F/.sdd-sync-ref"
git -C "$FORGED_F" update-ref refs/loom-upstream/main "$FORGED_U2"
NOLIB_CKSUM_BEFORE="$(cksum "$FORGED_F/.logicloom-adopt-receipt.json")"
NOLIB_OUT_WITH="$(bash "$RECORDER_SCRIPT" --root "$FORGED_F" --version v7.0.0 docs/customer-only.md 2>&1)"
NOLIB_RC_WITH=$?
assert "nolib: a forged (customer) sync-ref WITH refs/loom-upstream/main present but not reaching it is refused (non-zero, 'refusing to record'), never recorded on hex shape alone" \
  "[ $NOLIB_RC_WITH -ne 0 ] && printf '%s' '$NOLIB_OUT_WITH' | grep -q 'refusing to record'"
git -C "$FORGED_F" update-ref -d refs/loom-upstream/main
NOLIB_OUT_NOUP="$(bash "$RECORDER_SCRIPT" --root "$FORGED_F" --version v7.0.0 docs/customer-only.md 2>&1)"
NOLIB_RC_NOUP=$?
assert "nolib: …and WITHOUT refs/loom-upstream/main: also refused, with the /update-framework remedy" \
  "[ $NOLIB_RC_NOUP -ne 0 ] && printf '%s' '$NOLIB_OUT_NOUP' | grep -q 'refusing to record' && printf '%s' '$NOLIB_OUT_NOUP' | grep -q '/update-framework'"
NOLIB_RECON_OUT="$(bash "$RECORDER_SCRIPT" --root "$FORGED_F" --reconcile 2>&1)"
NOLIB_RECON_RC=$?
NOLIB_RECON_LISTED=0
printf '%s' "$NOLIB_RECON_OUT" | grep -q 'RECONCILE docs/customer-only.md' && NOLIB_RECON_LISTED=1
assert "nolib: --reconcile against the forged sync-ref refuses (exit 2) and lists nothing" \
  "[ $NOLIB_RECON_RC -eq 2 ] && [ $NOLIB_RECON_LISTED -eq 0 ]"
NOLIB_CKSUM_AFTER="$(cksum "$FORGED_F/.logicloom-adopt-receipt.json")"
assert "nolib: every refusal above left the receipt byte-identical (nothing was stamped)" \
  "[ '$NOLIB_CKSUM_BEFORE' = '$NOLIB_CKSUM_AFTER' ]"
# positive control, still without the lib: a genuine ancestor sync-ref is
# accepted by the fallback rule too (docs/upstream-only.md is already
# recorded from the positive control above, so the honest answer is
# "nothing new" — exit 0, not a refusal).
echo "$FORGED_U1" > "$FORGED_F/.sdd-sync-ref"
git -C "$FORGED_F" update-ref refs/loom-upstream/main "$FORGED_U2"
NOLIB_OUT_GENUINE="$(bash "$RECORDER_SCRIPT" --root "$FORGED_F" --version v7.0.0 docs/upstream-only.md 2>&1)"
NOLIB_RC_GENUINE=$?
assert "nolib: a GENUINE ancestor sync-ref is still accepted by the fallback rule (exit 0, 'nothing new to record' for the already-recorded file — not a refusal)" \
  "[ $NOLIB_RC_GENUINE -eq 0 ] && printf '%s' '$NOLIB_OUT_GENUINE' | grep -q 'nothing new to record'"

# ─────────────────────────────────────────────────────────────────────────
# I-forged-generator (round-2 review, high finding). The receipt's `recorded`
# op (both JSON-tool backends) used to filter candidate runs on `status`
# alone -- never on `generator`. Unlike I-forged-ref above (a sync-ref commit
# that resolves but is not provably upstream's), THIS fixture keeps the
# sync-ref genuine and reachable -- the forgery is entirely inside the
# adopter-editable receipt: a hand-added run claiming a plausible status
# ("complete") and a directory `wrote` entry, under a generator string no
# real LogicLoom writer ever stamps. Before the fix, --reconcile treated that
# directory as framework-recorded regardless, so a git-tracked file under it
# that happens to be byte-identical to the sync-ref blob at that path (real
# risk: a customer's own file, or a copy the customer made from upstream by
# hand) was offered as RECONCILE -- labeled LogicLoom's own write on a
# generator string that is itself unverified local data. The fix restricts
# BOTH `recorded` op backends to TRUSTED_GENERATOR_RE
# (^(logicloom|logicloom-update-framework)@.+$), the exact regex
# release-migrations.sh's _loom_rm_adopt_receipt_sha256 already applies to
# the SAME receipt for the SAME reason.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "I-forged-generator. A hand-added receipt run with a forged 'generator' must never authorize --reconcile"

GENFORGE_F="$WORKDIR/forged-generator"
mkdir -p "$GENFORGE_F/.logic-loom/lib" "$GENFORGE_F/.logic-loom/genforge"
(
  cd "$GENFORGE_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "shared-content" > .logic-loom/genforge/shared.sh
  git add -A
  git commit -q -m "U1: upstream ships .logic-loom/genforge/shared.sh"
)
GENFORGE_U1="$(git -C "$GENFORGE_F" rev-parse HEAD)"
cp "$REAL_ROOT/.logic-loom/lib/release-migrations.sh" "$GENFORGE_F/.logic-loom/lib/release-migrations.sh"
echo "$GENFORGE_U1" > "$GENFORGE_F/.sdd-sync-ref"
git -C "$GENFORGE_F" update-ref refs/loom-upstream/main "$GENFORGE_U1"
# A forged run: plausible status, a `dir` entry for .logic-loom/genforge, but
# a generator string neither real writer ever stamps. Note it does NOT
# individually record shared.sh as a `file` -- only the directory -- which is
# exactly the shape that makes it a --reconcile candidate rather than a
# record-mode one.
cat > "$GENFORGE_F/.logicloom-adopt-receipt.json" <<'JSON'
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-01-01T00:00:00.000Z",
      "generator": "acme-totally-not-logicloom@1.2.3",
      "status": "complete",
      "wrote": [
        {"target": "harness", "path": ".logic-loom/genforge", "kind": "dir"}
      ],
      "skipped": [],
      "failed": [],
      "notAttempted": []
    }
  ]
}
JSON
GENFORGE_CKSUM_BEFORE="$(cksum "$GENFORGE_F/.logicloom-adopt-receipt.json")"
GENFORGE_RECON_OUT="$(bash "$RECORDER_SCRIPT" --root "$GENFORGE_F" --reconcile 2>&1)"
GENFORGE_RECON_RC=$?
GENFORGE_RECON_LISTED=0
printf '%s' "$GENFORGE_RECON_OUT" | grep -q 'RECONCILE .logic-loom/genforge/shared.sh' && GENFORGE_RECON_LISTED=1
assert "a forged-generator run's 'dir' entry is never treated as recorded: --reconcile lists NO RECONCILE line for the file under it" \
  "[ $GENFORGE_RECON_LISTED -eq 0 ]"
assert "…and --reconcile exits cleanly (nothing to record), it does not error out" \
  "[ $GENFORGE_RECON_RC -eq 0 ] && printf '%s' '$GENFORGE_RECON_OUT' | grep -q 'nothing to record'"
bash "$RECORDER_SCRIPT" --root "$GENFORGE_F" --reconcile --apply >/dev/null 2>&1
GENFORGE_CKSUM_AFTER="$(cksum "$GENFORGE_F/.logicloom-adopt-receipt.json")"
assert "…and --reconcile --apply writes nothing (receipt byte-identical — the forged dir was never a candidate to begin with)" \
  "[ '$GENFORGE_CKSUM_BEFORE' = '$GENFORGE_CKSUM_AFTER' ]"

# Positive control: the SAME fixture shape with a genuine generator string
# (record-update-writes.sh's own stamp) DOES reconcile — proving the
# generator check, not something else about the fixture, is what withheld
# the recommendation above.
GENFORGE_OK_F="$WORKDIR/forged-generator-control"
mkdir -p "$GENFORGE_OK_F/.logic-loom/lib" "$GENFORGE_OK_F/.logic-loom/genforge"
(
  cd "$GENFORGE_OK_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "shared-content" > .logic-loom/genforge/shared.sh
  git add -A
  git commit -q -m "U1: upstream ships .logic-loom/genforge/shared.sh"
)
GENFORGE_OK_U1="$(git -C "$GENFORGE_OK_F" rev-parse HEAD)"
cp "$REAL_ROOT/.logic-loom/lib/release-migrations.sh" "$GENFORGE_OK_F/.logic-loom/lib/release-migrations.sh"
echo "$GENFORGE_OK_U1" > "$GENFORGE_OK_F/.sdd-sync-ref"
git -C "$GENFORGE_OK_F" update-ref refs/loom-upstream/main "$GENFORGE_OK_U1"
cat > "$GENFORGE_OK_F/.logicloom-adopt-receipt.json" <<'JSON'
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-01-01T00:00:00.000Z",
      "generator": "logicloom-update-framework@7.0.0",
      "status": "complete",
      "wrote": [
        {"target": "harness", "path": ".logic-loom/genforge", "kind": "dir"}
      ],
      "skipped": [],
      "failed": [],
      "notAttempted": []
    }
  ]
}
JSON
GENFORGE_OK_RECON_OUT="$(bash "$RECORDER_SCRIPT" --root "$GENFORGE_OK_F" --reconcile 2>&1)"
assert "control: the identical fixture with a TRUSTED generator string DOES list RECONCILE for the same file" \
  "printf '%s' \"\$GENFORGE_OK_RECON_OUT\" | grep -q 'RECONCILE .logic-loom/genforge/shared.sh'"

# ─────────────────────────────────────────────────────────────────────────
# I-atomic-write (round-2 review, low finding). Both JSON-tool backends used
# to `open(path, 'w')` / `fs.writeFileSync(path, ...)` the receipt directly —
# no symlink check, no atomic temp-file+rename. Reproduction below proves
# the symlink half directly (a crash-mid-write proof for the atomicity half
# is impractical in a unit test, but the fix is the standard temp+rename
# pattern and the same-run positive control below proves it still produces
# valid JSON and leaves no stray .tmp<pid> file).
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "I-atomic-write. append-run refuses a symlinked receipt path rather than writing through it, and writes atomically"

ATOMIC_F="$WORKDIR/atomic-write"
mkdir -p "$ATOMIC_F/.logic-loom/lib" "$ATOMIC_F/docs"
(
  cd "$ATOMIC_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "note body" > docs/note.md
  git add -A
  git commit -q -m "U1: upstream ships docs/note.md"
)
cp "$REAL_ROOT/.logic-loom/lib/release-migrations.sh" "$ATOMIC_F/.logic-loom/lib/release-migrations.sh"
git -C "$ATOMIC_F" rev-parse HEAD > "$ATOMIC_F/.sdd-sync-ref"
git -C "$ATOMIC_F" update-ref refs/loom-upstream/main HEAD
ATOMIC_REAL_RECEIPT="$ATOMIC_F/.logicloom-adopt-receipt-real.json"
printf '{"schema": "logicloom/adopt-receipt@1", "runs": []}' > "$ATOMIC_REAL_RECEIPT"
ln -s "$ATOMIC_REAL_RECEIPT" "$ATOMIC_F/.logicloom-adopt-receipt.json"
ATOMIC_OUT="$(bash "$RECORDER_SCRIPT" --root "$ATOMIC_F" --version v7.0.0 docs/note.md 2>&1)"
ATOMIC_RC=$?
assert "record mode refuses a symlinked .logicloom-adopt-receipt.json rather than writing through it" \
  "[ $ATOMIC_RC -ne 0 ] && printf '%s\n' \"\$ATOMIC_OUT\" | grep -qi 'symlink'"
assert "…and the file the symlink pointed at is untouched (byte-identical to before the call)" \
  "grep -qxF '{\"schema\": \"logicloom/adopt-receipt@1\", \"runs\": []}' '$ATOMIC_REAL_RECEIPT'"
# Positive control: the ordinary (non-symlinked) path still records
# normally, produces valid JSON, and leaves no leftover temp file.
rm -f "$ATOMIC_F/.logicloom-adopt-receipt.json"
printf '{"schema": "logicloom/adopt-receipt@1", "runs": []}' > "$ATOMIC_F/.logicloom-adopt-receipt.json"
ATOMIC_OK_OUT="$(bash "$RECORDER_SCRIPT" --root "$ATOMIC_F" --version v7.0.0 docs/note.md 2>&1)"
ATOMIC_OK_RC=$?
assert "control: an ordinary (non-symlinked) record still succeeds" \
  "[ $ATOMIC_OK_RC -eq 0 ] && printf '%s\n' \"\$ATOMIC_OK_OUT\" | grep -qF 'RECORDED docs/note.md'"
assert "…produces valid, parseable JSON (the atomic-write path did not corrupt anything)" \
  "python3 -c \"import json; json.load(open('$ATOMIC_F/.logicloom-adopt-receipt.json'))\""
assert "…and no leftover .tmp<pid> file was left behind after a successful write" \
  "[ -z \"\$(find '$ATOMIC_F' -maxdepth 1 -name '.logicloom-adopt-receipt.json.tmp*' 2>/dev/null)\" ]"

# ─────────────────────────────────────────────────────────────────────────
# I-atomic-write, reviewer round 2: the temp file's name is PREDICTABLE
# (<receipt>.tmp<pid>), and both backends created it with a plain
# open(...,'w') / writeFileSync — which FOLLOWS a symlink already sitting
# at that name. A pre-planted `<receipt>.tmp<pid> -> <victim>` link then
# had the JSON written THROUGH it (truncating the victim, a file this tool
# never created) and the rename moved the link itself over the receipt.
# Deterministic reproduction without guessing a pid: LOOM_JSON_TOOL accepts
# a path to an executable, and a wrapper that plants the link at its OWN
# $$ and then `exec`s the real interpreter keeps that same pid — so the
# helper's os.getpid()/process.pid IS the planted name. The fix opens the
# temp file O_CREAT|O_EXCL ('wx'), which fails on ANY pre-existing entry,
# symlink included, and never follows it.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "I-atomic-write (reviewer round 2). append-run never writes through a pre-planted symlink at its own temp-file name"

rv2_plant_probe() {   # $1 = backend label (python3|node), $2 = wrapper basename (classifies the backend by name)
  local BE="$1" WRAP_NAME="$2"
  if ! command -v "$BE" >/dev/null 2>&1; then
    skip "I-atomic-write reviewer round 2 [$BE]" "$BE not installed"
    return 0
  fi
  local F="$WORKDIR/rv2-plant-$BE"
  mkdir -p "$F/.logic-loom/lib" "$F/docs" "$WORKDIR/rv2-wrap-$BE"
  (
    cd "$F"
    git init -q
    git config user.email test@example.com
    git config user.name Test
    echo "note body" > docs/note.md
    git add -A
    git commit -q -m "U1: upstream ships docs/note.md"
  )
  cp "$REAL_ROOT/.logic-loom/lib/release-migrations.sh" "$F/.logic-loom/lib/release-migrations.sh"
  git -C "$F" rev-parse HEAD > "$F/.sdd-sync-ref"
  git -C "$F" update-ref refs/loom-upstream/main HEAD
  local RECEIPT="$F/.logicloom-adopt-receipt.json" VICTIM="$F/docs/victim-the-tool-never-created.md"
  printf '{"schema": "logicloom/adopt-receipt@1", "runs": []}' > "$RECEIPT"
  echo "customer bytes that must survive" > "$VICTIM"
  local WRAP="$WORKDIR/rv2-wrap-$BE/$WRAP_NAME"
  {
    echo '#!/usr/bin/env bash'
    echo '# plant a symlink at the exact temp name the helper will compute (its pid == ours after exec)'
    echo 'ln -sfn "$RV2_VICTIM" "$RV2_RECEIPT.tmp$$"'
    echo "exec $BE \"\$@\""
  } > "$WRAP"
  chmod +x "$WRAP"
  local OUT RC
  OUT="$(LOOM_JSON_TOOL="$WRAP" RV2_VICTIM="$VICTIM" RV2_RECEIPT="$RECEIPT" bash "$RECORDER_SCRIPT" --root "$F" --version v7.0.0 docs/note.md 2>&1)"
  RC=$?
  assert "[$BE] sanity: the wrapper really planted a link at the helper's temp name (at least one <receipt>.tmp<pid> symlink exists)" \
    "[ -n \"\$(find '$F' -maxdepth 1 -name '.logicloom-adopt-receipt.json.tmp*' -type l 2>/dev/null)\" ]"
  assert "[$BE] the victim file the link pointed at is byte-identical to before (the bug: the receipt JSON was written THROUGH the link, truncating it)" \
    "grep -qxF 'customer bytes that must survive' '$VICTIM' && [ \"\$(wc -l < '$VICTIM' | tr -d ' ')\" = 1 ]"
  assert "[$BE] the receipt is still a regular file, not the planted link renamed over it" \
    "[ -f '$RECEIPT' ] && [ ! -L '$RECEIPT' ]"
  assert "[$BE] the run refuses loudly (non-zero, names the temp file) instead of silently succeeding" \
    "[ $RC -ne 0 ] && printf '%s\n' \"\$OUT\" | grep -qF 'refusing to create temp file'"
  # never leave the planted links behind for the suite's own cleanup to trip on
  find "$F" -maxdepth 1 -name '.logicloom-adopt-receipt.json.tmp*' -type l -exec rm -f {} + 2>/dev/null
}
rv2_plant_probe python3 python3-planting
rv2_plant_probe node node-planting

# ─────────────────────────────────────────────────────────────────────────
# J. receipt.uninstall as a STALE MARKER: every packaging reader survives it
#    (round-2 finding item 2). Exhaustive grep across the repo for a
#    programmatic reader of receipt.uninstall's internal shape (outside
#    apply.js's own two WRITE sites, and outside tests that only ever read a
#    receipt freshly written by apply.js itself) turns up none — the only
#    candidates are receipt.js's readReceipt()/priorRun()/provenance(), which
#    never touch the `uninstall` key at all, and apply.js's own
#    uninstallProcedure(), which unconditionally RECOMPUTES it. This section
#    proves that against the real code, on a receipt this suite's own
#    recorder actually left with a stale marker (section C, MAIN_F/RECEIPT,
#    asserted stale=true above) rather than a hand-built shape.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "J. receipt.uninstall as a stale marker: no packaging reader crashes on it"

RECEIPT_LIB="$REAL_ROOT/packaging/adopt/lib/receipt.js"
if [ -f "$RECEIPT_LIB" ] && [ -f "$APPLY_LIB" ] && command -v node >/dev/null 2>&1; then
  READER_SURVIVAL="$(node -e '
    const path = require("path");
    const fs = require("fs");
    const receiptLib = require(process.argv[1]);
    const applyLib = require(process.argv[2]);
    const receiptFile = process.argv[3];
    const root = path.dirname(receiptFile);
    const results = [];
    try {
      const r = receiptLib.readReceipt(root);
      results.push(r && r.schema ? "readReceipt:ok" : "readReceipt:BAD");
    } catch (e) { results.push("readReceipt:THROW:" + e.message); }
    try {
      const pr = receiptLib.priorRun(root);
      results.push(pr !== undefined ? "priorRun:ok" : "priorRun:BAD");
    } catch (e) { results.push("priorRun:THROW:" + e.message); }
    try {
      const prov = receiptLib.provenance(root);
      results.push(prov && Array.isArray(prov.wrote) ? "provenance:ok" : "provenance:BAD");
    } catch (e) { results.push("provenance:THROW:" + e.message); }
    try {
      const raw = JSON.parse(fs.readFileSync(receiptFile, "utf8"));
      const u = applyLib.uninstallProcedure(raw);
      results.push(u && u.remove && Array.isArray(u.remove.files) ? "uninstallProcedure-recompute:ok" : "uninstallProcedure-recompute:BAD");
    } catch (e) { results.push("uninstallProcedure-recompute:THROW:" + e.message); }
    process.stdout.write(results.join(","));
  ' "$RECEIPT_LIB" "$APPLY_LIB" "$RECEIPT")"
  assert "receipt.js's readReceipt() does not crash on a stale-marker uninstall" \
    "printf '%s' '$READER_SURVIVAL' | grep -q 'readReceipt:ok'"
  assert "receipt.js's priorRun() does not crash on a stale-marker uninstall" \
    "printf '%s' '$READER_SURVIVAL' | grep -q 'priorRun:ok'"
  assert "receipt.js's provenance() does not crash on a stale-marker uninstall" \
    "printf '%s' '$READER_SURVIVAL' | grep -q 'provenance:ok'"
  assert "apply.js's uninstallProcedure() recomputes cleanly from a receipt whose cached uninstall is a stale marker" \
    "printf '%s' '$READER_SURVIVAL' | grep -q 'uninstallProcedure-recompute:ok'"
  assert "no packaging reader THROWS (TypeError etc.) on the stale-marker shape" \
    "! printf '%s' '$READER_SURVIVAL' | grep -q 'THROW'"
else
  skip "packaging readers survive the stale-marker uninstall" "packaging/adopt/lib not present (stripped tree) or node unavailable"
fi

# ─────────────────────────────────────────────────────────────────────────
# Prose pin (round-3 finding 7): update-framework.md and SKILL.md used to
# describe a RECONCILE line as simply "byte-identical to the sync-ref copy
# — safe to record", with no mention that --reconcile itself refuses to run
# at all unless the sync-ref is provably LogicLoom's own record (the exact
# guard sections B/G above exercise via loom_sync_ref_is_loom_record). A
# prose pin proves the instruction is present in the right step, not that
# the mechanism is obeyed — the mechanism is what the rest of this suite
# proves.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "── Prose pin: RECONCILE precondition is documented, not just enforced ──"
CMD_MD="$REAL_ROOT/plugins/loom-maintenance/commands/update-framework.md"
SKILL_MD="$REAL_ROOT/plugins/loom-maintenance/skills/framework-updater/SKILL.md"
for f in "$CMD_MD" "$SKILL_MD"; do
  base="$(basename "$f")"
  assert "$base exists" "[ -f '$f' ]"
  if [ -f "$f" ]; then
    assert "$base: RECONCILE prose states the sync-ref must be provably LogicLoom's own record" \
      "grep -qF \"provably LogicLoom's own record\" '$f'"
    assert "$base: RECONCILE prose says what the refusal means (lists/records nothing)" \
      "grep -qF 'lists and records nothing' '$f'"
    assert "$base: RECONCILE prose still ties this to refs/loom-upstream/main" \
      "grep -qF 'refs/loom-upstream/main' '$f'"
  else
    skip "$base: RECONCILE precondition prose" "file not found"
    skip "$base: RECONCILE refusal-meaning prose" "file not found"
    skip "$base: RECONCILE refs/loom-upstream/main prose" "file not found"
  fi
done

# ─────────────────────────────────────────────────────────────────────────
# Round-3 review finding (medium): the 'recorded' op (both JSON-tool
# backends) trusted a run's wrote[] entries as already framework-owned for
# status in ('complete', 'partial', 'in-progress') — a wider set than
# release-migrations.sh's own baseline digest reader
# (_loom_rm_adopt_receipt_sha256), which trusts 'complete' only, with the
# reasoning spelled out there: a run that never finished is not vouching
# for the bytes it left behind. Two pieces of receipt-trust logic over the
# same hand-editable receipt, tightened in the same PR, disagreeing on the
# identical run. Proven here via the OBSERVABLE effect on build_entries():
# a directory recorded ONLY by an 'in-progress' run must not suppress a
# later COMPLETE run's own dir entry for that same ancestor — is_dir_recorded
# must read false until a run that actually finished vouches for it.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "── Round-3 finding: 'recorded' does not trust a partial/in-progress run's wrote[] as already framework-owned ──"
for badstatus in partial in-progress; do
  PARTIAL_F="$WORKDIR/partial-trust-$badstatus"
  mkdir -p "$PARTIAL_F/.logic-loom/partial-dir"
  (
    cd "$PARTIAL_F"
    git init -q
    git config user.email test@example.com
    git config user.name Test
    echo "q-content" > .logic-loom/partial-dir/q.sh
    git add -A
    git commit -q -m "A: upstream baseline"
  )
  PARTIAL_SHA_A="$(git -C "$PARTIAL_F" rev-parse HEAD)"
  cat > "$PARTIAL_F/.logicloom-adopt-receipt.json" <<JSON
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-08-31T00:00:00.000Z",
      "generator": "logicloom-update-framework@7.0.0",
      "status": "$badstatus",
      "wrote": [
        {"target": "harness", "path": ".logic-loom/partial-dir/", "kind": "dir"}
      ],
      "skipped": [], "failed": [], "notAttempted": []
    }
  ],
  "uninstall": {"marker": "left as is"}
}
JSON
  echo "$PARTIAL_SHA_A" > "$PARTIAL_F/.sdd-sync-ref"
  git -C "$PARTIAL_F" update-ref refs/loom-upstream/main "$PARTIAL_SHA_A"

  bash "$RECORDER_SCRIPT" --root "$PARTIAL_F" --version v7.0.0 .logic-loom/partial-dir/q.sh >/dev/null 2>&1
  PARTIAL_HAS_DIR="$(python3 -c "
import json
d = json.load(open('$PARTIAL_F/.logicloom-adopt-receipt.json'))
run1 = d['runs'][1] if len(d['runs']) > 1 else None
if run1 is None:
    print('NO_SECOND_RUN')
else:
    dirs = [w['path'] for w in run1.get('wrote', []) if w.get('kind') == 'dir']
    print('HAS_DIR' if '.logic-loom/partial-dir/' in dirs else 'NO_DIR')
")"
  assert "a dir recorded only by a status=$badstatus run: a later COMPLETE run still records its own dir entry for it (the partial run's claim is not trusted)" \
    "[ '$PARTIAL_HAS_DIR' = 'HAS_DIR' ]"
done

# ─────────────────────────────────────────────────────────────────────────
# Round-3 review finding (medium, over-claim): build_entries() records
# every not-yet-recorded ANCESTOR directory of a written file
# unconditionally — it never checks whether that directory already existed
# independent of this run. The stale-uninstall-marker's own untilThen text
# claimed "every kind:dir entry is a directory it created", which is a
# stronger claim than the code verifies (a customer's own pre-existing
# directory that happens to also receive one LogicLoom-written file is
# recorded exactly the same way). Pins the corrected wording, and that the
# two JSON-tool backends stay byte-identical (as their own "Byte-for-byte
# the same text" comment requires).
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "── Round-3 finding: the stale marker's untilThen text no longer claims to have created every kind:dir directory ──"
OVERCLAIM_F="$WORKDIR/marker-overclaim"
mkdir -p "$OVERCLAIM_F/.logic-loom/scripts/bash"
(
  cd "$OVERCLAIM_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "b1-content" > .logic-loom/scripts/bash/b.sh
  git add -A
  git commit -q -m "A"
)
OVERCLAIM_SHA_A="$(git -C "$OVERCLAIM_F" rev-parse HEAD)"
cat > "$OVERCLAIM_F/.logicloom-adopt-receipt.json" <<JSON
{"schema": "logicloom/adopt-receipt@1", "runs": [], "uninstall": {"marker": "left as is"}}
JSON
echo "$OVERCLAIM_SHA_A" > "$OVERCLAIM_F/.sdd-sync-ref"
git -C "$OVERCLAIM_F" update-ref refs/loom-upstream/main "$OVERCLAIM_SHA_A"
bash "$RECORDER_SCRIPT" --root "$OVERCLAIM_F" --version v7.0.0 .logic-loom/scripts/bash/b.sh >/dev/null 2>&1
# Force the marker to regenerate: append-run always replaces 'uninstall'
# with a fresh stale marker, so the run above already produced one.
UNTIL_THEN="$(python3 -c "
import json
d = json.load(open('$OVERCLAIM_F/.logicloom-adopt-receipt.json'))
print(d['uninstall']['untilThen'])
")"
assert "untilThen no longer says a kind:dir entry 'is a directory it created'" \
  "! printf '%s' \"\$UNTIL_THEN\" | grep -qF 'is a directory it created'"
assert "untilThen instead describes what a kind:dir entry actually means (holds a LogicLoom-written file)" \
  "printf '%s' \"\$UNTIL_THEN\" | grep -qF 'directory holding a' && printf '%s' \"\$UNTIL_THEN\" | grep -qF 'LogicLoom-written file'"
assert "untilThen explicitly disclaims creation/ownership (may have pre-existed)" \
  "printf '%s' \"\$UNTIL_THEN\" | grep -qF 'may have pre-existed'"
if command -v node >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  OVERCLAIM_NODE_F="$WORKDIR/marker-overclaim-node"
  mkdir -p "$OVERCLAIM_NODE_F/.logic-loom/scripts/bash"
  (
    cd "$OVERCLAIM_NODE_F"
    git init -q
    git config user.email test@example.com
    git config user.name Test
    echo "b1-content" > .logic-loom/scripts/bash/b.sh
    git add -A
    git commit -q -m "A"
  )
  OVERCLAIM_NODE_SHA_A="$(git -C "$OVERCLAIM_NODE_F" rev-parse HEAD)"
  cat > "$OVERCLAIM_NODE_F/.logicloom-adopt-receipt.json" <<JSON
{"schema": "logicloom/adopt-receipt@1", "runs": [], "uninstall": {"marker": "left as is"}}
JSON
  echo "$OVERCLAIM_NODE_SHA_A" > "$OVERCLAIM_NODE_F/.sdd-sync-ref"
  git -C "$OVERCLAIM_NODE_F" update-ref refs/loom-upstream/main "$OVERCLAIM_NODE_SHA_A"
  # Force the NODE backend explicitly (record mode's own default already
  # prefers python3 when both are present) so this exercises
  # staleUninstallMarker(), not stale_uninstall_marker() again.
  LOOM_JSON_TOOL=node bash "$RECORDER_SCRIPT" --root "$OVERCLAIM_NODE_F" --version v7.0.0 .logic-loom/scripts/bash/b.sh >/dev/null 2>&1
  NODE_UNTIL_THEN="$(python3 -c "
import json
d = json.load(open('$OVERCLAIM_NODE_F/.logicloom-adopt-receipt.json'))
print(d['uninstall']['untilThen'])
")"
  assert "the node backend produces the byte-identical untilThen text as the python backend" \
    "[ \"\$NODE_UNTIL_THEN\" = \"\$UNTIL_THEN\" ]"
else
  skip "node-backend byte-identical untilThen check" "node or python3 not on PATH"
fi

# ─────────────────────────────────────────────────────────────────────────
# Round-4 finding 3 (medium, ancestor-directory over-claim — round-3 only
# fixed the stale marker's PROSE; the round-3 test above pins that prose but
# never exercises the underlying behavior). build_entries() used to record
# EVERY not-yet-recorded ancestor of a written file as kind:dir, all the way
# to a wide top-level directory (plugins/, .claude/, .logic-loom/) — the
# exact directory a customer's own, entirely unrelated content also lives
# in. --reconcile then trusts every kind:dir entry as license to sweep
# `git ls-files -- "$d"` for that whole subtree. This fixture puts a written
# file two levels under plugins/loom-git/commands/ and a SEPARATE,
# unrelated upstream file directly under plugins/customer-owned/ — a
# sibling subtree record-update-writes.sh never touched and never recorded.
# Proves: (1) recording the written file also records its own immediate
# ancestors (plugins/loom-git/commands/, plugins/loom-git/) — the ancestor
# rule still works where this run can actually vouch for the directory —
# but STOPS at plugins/ itself, because plugins/ also holds
# customer-owned/notes.md, a file this call never wrote and has no entry
# for; (2) --reconcile, scoped only to the dirs this run could actually
# vouch for, never reaches into plugins/customer-owned/ at all — it does
# not even get a chance to run its byte-identity check, because the
# directory-level claim that would have licensed the sweep was never made.
# Fail-then-pass proof (this round): reverting _dir_is_fully_accounted's
# call in build_entries's ancestor loop (i.e. recording every ancestor
# unconditionally, as every prior round did) makes assertions 1 and 3 below
# fail — 'plugins' appears as a recorded dir, and the customer's file is
# offered as RECONCILE.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "── Round-4 finding 3: --reconcile's directory sweep never widens into a sibling subtree this run never wrote ──"
OVERWIDE_F="$WORKDIR/ancestor-overwide"
mkdir -p "$OVERWIDE_F/plugins/loom-git/commands" "$OVERWIDE_F/plugins/customer-owned"
(
  cd "$OVERWIDE_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "deep-content" > plugins/loom-git/commands/deep.md
  echo "notes-content, never touched by record-update-writes.sh" > plugins/customer-owned/notes.md
  git add -A
  git commit -q -m "U1: upstream baseline (both paths already exist here)"
)
OVERWIDE_SHA_A="$(git -C "$OVERWIDE_F" rev-parse HEAD)"
cat > "$OVERWIDE_F/.logicloom-adopt-receipt.json" <<'JSON'
{"schema": "logicloom/adopt-receipt@1", "runs": [], "uninstall": {}}
JSON
echo "$OVERWIDE_SHA_A" > "$OVERWIDE_F/.sdd-sync-ref"
git -C "$OVERWIDE_F" update-ref refs/loom-upstream/main "$OVERWIDE_SHA_A"

OVERWIDE_REC_OUT="$(bash "$RECORDER_SCRIPT" --root "$OVERWIDE_F" --version v7.0.0 plugins/loom-git/commands/deep.md 2>&1)"
OVERWIDE_DIRS="$(python3 -c "
import json
d = json.load(open('$OVERWIDE_F/.logicloom-adopt-receipt.json'))
print('\n'.join(sorted(w['path'].rstrip('/') for w in d['runs'][0]['wrote'] if w.get('kind') == 'dir')))
")"
assert "recording plugins/loom-git/commands/deep.md still records its own immediate ancestor (plugins/loom-git/commands/)" \
  "printf '%s\n' \"\$OVERWIDE_DIRS\" | grep -qxF 'plugins/loom-git/commands'"
assert "…and the next ancestor up (plugins/loom-git/) — it holds nothing else" \
  "printf '%s\n' \"\$OVERWIDE_DIRS\" | grep -qxF 'plugins/loom-git'"
assert "…but NOT the wide top-level plugins/ — it also holds customer-owned/notes.md, which this call never wrote or recorded" \
  "! printf '%s\n' \"\$OVERWIDE_DIRS\" | grep -qxF 'plugins'"

OVERWIDE_RECON_OUT="$(bash "$RECORDER_SCRIPT" --root "$OVERWIDE_F" --reconcile 2>&1)"
assert "--reconcile never lists RECONCILE for plugins/customer-owned/notes.md — plugins/ itself was never recorded, so the sweep never reaches its sibling subtree" \
  "! printf '%s' \"\$OVERWIDE_RECON_OUT\" | grep -qF 'RECONCILE plugins/customer-owned/notes.md'"
assert "…nor does it appear even as a DIFFERS candidate — the file is simply out of scope, not evaluated at all" \
  "! printf '%s' \"\$OVERWIDE_RECON_OUT\" | grep -qF 'plugins/customer-owned/notes.md'"

# ─────────────────────────────────────────────────────────────────────────
# Round-4 REVIEWER: the finding-3 fix above regressed the MULTI-file case.
# _dir_is_fully_accounted judges a directory by reading the entries file, so
# it only sees file entries written BEFORE it runs; the single interleaved
# pass (file, its ancestors, next file, ...) asked about
# plugins/loom-git/commands/ while b.md's entry did not exist yet, refused
# it, parked it in seen_dirs, and never asked again on b.md's own walk.
# Recording `a.md b.md` in ONE call — exactly how /update-framework invokes
# the recorder (`--version V <each written path>`) — therefore recorded NO
# ancestor at all, reopening the rot gap this script exists to close (a
# later upstream A under commands/ fails the ancestor rule, silently,
# forever). Reproduced on the round-4 builder tree: dirs recorded == [].
# The fix writes every file entry first and judges directories second,
# against the whole call. The customer-owned sibling keeps finding 3's
# narrowing honest: plugins/ itself must still NOT be recorded.
# Fail-then-pass: LOOM_TEST_RECORDER_SCRIPT=<round-4 builder copy> fails
# the two "IS recorded" assertions below and passes everything else.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "── Round-4 REVIEWER: recording SEVERAL files in one call still records the ancestors they jointly account for ──"
MULTI_F="$WORKDIR/ancestor-multifile"
mkdir -p "$MULTI_F/plugins/loom-git/commands" "$MULTI_F/plugins/customer-owned"
(
  cd "$MULTI_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "a-content" > plugins/loom-git/commands/a.md
  echo "b-content" > plugins/loom-git/commands/b.md
  echo "notes-content, never touched by record-update-writes.sh" > plugins/customer-owned/notes.md
  git add -A
  git commit -q -m "U1: upstream baseline"
)
MULTI_SHA_A="$(git -C "$MULTI_F" rev-parse HEAD)"
cat > "$MULTI_F/.logicloom-adopt-receipt.json" <<'JSON'
{"schema": "logicloom/adopt-receipt@1", "runs": [], "uninstall": {}}
JSON
echo "$MULTI_SHA_A" > "$MULTI_F/.sdd-sync-ref"
git -C "$MULTI_F" update-ref refs/loom-upstream/main "$MULTI_SHA_A"

MULTI_REC_OUT="$(bash "$RECORDER_SCRIPT" --root "$MULTI_F" --version v7.0.0 plugins/loom-git/commands/a.md plugins/loom-git/commands/b.md 2>&1)"
MULTI_REC_RC=$?
MULTI_DIRS="$(python3 -c "
import json
d = json.load(open('$MULTI_F/.logicloom-adopt-receipt.json'))
print('\n'.join(sorted(w['path'].rstrip('/') for w in d['runs'][0]['wrote'] if w.get('kind') == 'dir')))
")"
MULTI_FILES="$(python3 -c "
import json
d = json.load(open('$MULTI_F/.logicloom-adopt-receipt.json'))
print('\n'.join(sorted(w['path'] for w in d['runs'][0]['wrote'] if w.get('kind') == 'file')))
")"
assert "sanity: both files are recorded in one run (rc 0)" \
  "[ $MULTI_REC_RC -eq 0 ] && printf '%s\n' \"\$MULTI_FILES\" | grep -qxF 'plugins/loom-git/commands/a.md' && printf '%s\n' \"\$MULTI_FILES\" | grep -qxF 'plugins/loom-git/commands/b.md'"
assert "the shared immediate ancestor plugins/loom-git/commands/ IS recorded — every tracked file under it is in this same call (the bug: judged before b.md's entry existed, refused, never re-asked)" \
  "printf '%s\n' \"\$MULTI_DIRS\" | grep -qxF 'plugins/loom-git/commands'"
assert "…and plugins/loom-git/ above it, for the same reason" \
  "printf '%s\n' \"\$MULTI_DIRS\" | grep -qxF 'plugins/loom-git'"
assert "…but still NOT plugins/ — plugins/customer-owned/notes.md is unaccounted, so finding 3's narrowing survives the fix" \
  "! printf '%s\n' \"\$MULTI_DIRS\" | grep -qxF 'plugins'"
assert "the RECORDED lines name both files and both directories (never a directory this call cannot vouch for)" \
  "printf '%s\n' \"\$MULTI_REC_OUT\" | grep -qxF 'RECORDED plugins/loom-git/commands/' && printf '%s\n' \"\$MULTI_REC_OUT\" | grep -qxF 'RECORDED plugins/loom-git/' && ! printf '%s\n' \"\$MULTI_REC_OUT\" | grep -qxF 'RECORDED plugins/'"

# --reconcile --apply goes through the SAME builder ("exactly as record
# mode does"), with every RECONCILE path in one call — so two byte-identical,
# unrecorded files in one directory under an already-trusted kind:dir must
# record that directory too, not just the two files.
MULTI_R="$WORKDIR/ancestor-multifile-reconcile"
mkdir -p "$MULTI_R/plugins/loom-git/commands" "$MULTI_R/plugins/customer-owned"
(
  cd "$MULTI_R"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "a-content" > plugins/loom-git/commands/a.md
  echo "b-content" > plugins/loom-git/commands/b.md
  echo "notes-content" > plugins/customer-owned/notes.md
  git add -A
  git commit -q -m "U1: upstream baseline"
)
MULTI_R_SHA="$(git -C "$MULTI_R" rev-parse HEAD)"
cat > "$MULTI_R/.logicloom-adopt-receipt.json" <<'JSON'
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-08-31T00:00:00.000Z",
      "generator": "logicloom@6.6.2",
      "status": "complete",
      "wrote": [
        {"target": "harness", "path": "plugins/loom-git/", "kind": "dir"}
      ],
      "skipped": [], "failed": [], "notAttempted": []
    }
  ],
  "uninstall": {}
}
JSON
echo "$MULTI_R_SHA" > "$MULTI_R/.sdd-sync-ref"
git -C "$MULTI_R" update-ref refs/loom-upstream/main "$MULTI_R_SHA"
MULTI_R_OUT="$(bash "$RECORDER_SCRIPT" --root "$MULTI_R" --reconcile --apply 2>&1)"
MULTI_R_DIRS="$(python3 -c "
import json
d = json.load(open('$MULTI_R/.logicloom-adopt-receipt.json'))
print('\n'.join(sorted(w['path'].rstrip('/') for w in d['runs'][-1]['wrote'] if w.get('kind') == 'dir')))
")"
assert "sanity: --reconcile --apply offers and records BOTH byte-identical files under the trusted plugins/loom-git/" \
  "printf '%s\n' \"\$MULTI_R_OUT\" | grep -qxF 'RECONCILE plugins/loom-git/commands/a.md' && printf '%s\n' \"\$MULTI_R_OUT\" | grep -qxF 'RECONCILE plugins/loom-git/commands/b.md' && printf '%s\n' \"\$MULTI_R_OUT\" | grep -qF '3 entries recorded'"
assert "…and records plugins/loom-git/commands/ as a dir in that same run (both files it holds were recorded by this call)" \
  "printf '%s\n' \"\$MULTI_R_DIRS\" | grep -qxF 'plugins/loom-git/commands'"
assert "…never plugins/ (customer-owned/notes.md is unaccounted) and never the already-recorded plugins/loom-git/ again" \
  "! printf '%s\n' \"\$MULTI_R_DIRS\" | grep -qxF 'plugins' && ! printf '%s\n' \"\$MULTI_R_DIRS\" | grep -qxF 'plugins/loom-git'"

# ─────────────────────────────────────────────────────────────────────────
# Round-5 finding 3 (high, fail-open on enumeration failure):
# _dir_is_fully_accounted() used to feed its while-loop directly from
# `git ls-files -z ... 2>/dev/null || true` -- a FAILED enumeration (git
# exits non-zero: permission issue, corrupted object, anything) was masked
# by `|| true`, so the loop read zero lines, indistinguishable from a
# directory that legitimately holds nothing, and fell through to
# `return 0` (fully accounted). That licenses a kind:dir receipt entry --
# and later a --reconcile sweep of that whole subtree -- from an
# enumeration that never actually ran. This is the exact fail-open class
# unconverted_plugin_files() in release-migrations.sh already closed for
# `find` ("An enumeration that did not complete proves nothing about the
# tree: report the directory itself as unverifiable and stop"); this
# function's own `git ls-files` call was never given the same fix.
#
# Reproduced with a `git` shim placed ahead of PATH that fails ONLY the
# specific `-C <root> ls-files -z -- roundfive` call build_entries makes
# for this fixture's one ancestor directory -- every other git invocation
# (rev-parse, cat-file, the receipt's own bookkeeping) goes through to the
# real binary untouched, so this isolates exactly the one enumeration this
# function performs.
# Fail-then-pass: LOOM_TEST_RECORDER_SCRIPT=<pre-round-5 copy> makes the
# "must NOT be recorded" assertions below fail (roundfive/ IS recorded).
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "── Round-5 finding 3: a FAILED git ls-files enumeration must refuse the directory, never claim it as fully accounted ──"
FIVE_F="$WORKDIR/dir-accounted-enum-fail"
mkdir -p "$FIVE_F/roundfive"
(
  cd "$FIVE_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "leaf-content" > roundfive/leaf.sh
  git add -A
  git commit -q -m "R5 baseline"
)
FIVE_SHA="$(git -C "$FIVE_F" rev-parse HEAD)"
cat > "$FIVE_F/.logicloom-adopt-receipt.json" <<'JSON'
{"schema": "logicloom/adopt-receipt@1", "runs": [], "uninstall": {}}
JSON
echo "$FIVE_SHA" > "$FIVE_F/.sdd-sync-ref"
git -C "$FIVE_F" update-ref refs/loom-upstream/main "$FIVE_SHA"

# Control: an UNSHIMMED run on an identical twin fixture records the
# ancestor directory normally -- establishing that the shim below, not
# some other difference, is what changes the outcome.
FIVE_CTRL="$WORKDIR/dir-accounted-enum-fail-control"
mkdir -p "$FIVE_CTRL/roundfive"
(
  cd "$FIVE_CTRL"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "leaf-content" > roundfive/leaf.sh
  git add -A
  git commit -q -m "R5 baseline control"
)
FIVE_CTRL_SHA="$(git -C "$FIVE_CTRL" rev-parse HEAD)"
cat > "$FIVE_CTRL/.logicloom-adopt-receipt.json" <<'JSON'
{"schema": "logicloom/adopt-receipt@1", "runs": [], "uninstall": {}}
JSON
echo "$FIVE_CTRL_SHA" > "$FIVE_CTRL/.sdd-sync-ref"
git -C "$FIVE_CTRL" update-ref refs/loom-upstream/main "$FIVE_CTRL_SHA"
FIVE_CTRL_OUT="$(bash "$RECORDER_SCRIPT" --root "$FIVE_CTRL" --version v7.0.0 roundfive/leaf.sh 2>&1)"
assert "control (real git, no shim): the ancestor directory IS recorded when enumeration actually succeeds" \
  "printf '%s\n' \"\$FIVE_CTRL_OUT\" | grep -qxF 'RECORDED roundfive/'"

FD5_ROOT="$(cd "$FIVE_F" && pwd -P)"
FD5_FAILDIR="roundfive"
FD5_REAL_GIT="$(command -v git)"
export FD5_ROOT FD5_FAILDIR FD5_REAL_GIT
FIVE_BIN="$WORKDIR/fakebin-round5"
mkdir -p "$FIVE_BIN"
# (Round-5 REVIEWER: the recorder now passes the directory as the literal
# pathspec `:(literal)<dir>` — see _dir_is_fully_accounted — so the shim
# matches either spelling; what it fails is still exactly this one call.)
cat > "$FIVE_BIN/git" <<'GITSHIM'
#!/usr/bin/env bash
if [ "$1" = "-C" ] && [ "$2" = "$FD5_ROOT" ] && [ "$3" = "ls-files" ] && [ "$4" = "-z" ] && [ "$5" = "--" ] && { [ "$6" = "$FD5_FAILDIR" ] || [ "$6" = ":(literal)$FD5_FAILDIR" ]; }; then
  exit 1
fi
exec "$FD5_REAL_GIT" "$@"
GITSHIM
chmod +x "$FIVE_BIN/git"

FIVE_OUT="$(PATH="$FIVE_BIN:$PATH" bash "$RECORDER_SCRIPT" --root "$FIVE_F" --version v7.0.0 roundfive/leaf.sh 2>&1)"
FIVE_RC=$?
FIVE_DIRS="$(python3 -c "
import json
d = json.load(open('$FIVE_F/.logicloom-adopt-receipt.json'))
print('\n'.join(sorted(w['path'].rstrip('/') for w in d['runs'][0]['wrote'] if w.get('kind') == 'dir')))
")"
assert "the file itself is still recorded fine (rc 0) -- only the directory-level enumeration is made to fail" \
  "[ $FIVE_RC -eq 0 ] && printf '%s\n' \"\$FIVE_OUT\" | grep -qxF 'RECORDED roundfive/leaf.sh'"
assert "the RECORDED lines must NOT claim the directory -- git ls-files for it never actually completed" \
  "! printf '%s\n' \"\$FIVE_OUT\" | grep -qxF 'RECORDED roundfive/'"
assert "…and the receipt itself holds no kind:dir entry for roundfive (the bug: fail-open recorded it anyway)" \
  "! printf '%s\n' \"\$FIVE_DIRS\" | grep -qxF 'roundfive'"

# ─────────────────────────────────────────────────────────────────────────
# Round-5 finding 2 (reviewed: NOT a bug -- pinning the documented behavior).
# The claim: when sync-ref and upstream-main resolve to DIFFERENT blobs and
# disk matches NEITHER, upstream_blob_sha()'s trailing `for cand in
# "$sync_cand" "$up_cand"` loop falls through to `first_sha` (sync_cand's
# digest) and records it -- allegedly "a claim this call never verified".
# It is not: upstream_blob_sha()'s own THE CHOICE RULE comment (this file,
# just above the function) documents this exact branch by name -- "When it
# matches neither -- the adopter's own edit... the sync-ref blob is
# recorded; both candidates mismatch the disk anyway, so either keeps the
# file at uninstall, and sync-ref is the stable one." `first_sha` is never a
# hash of disk bytes -- it is `blob_sha256()`'s digest of a git blob this
# same function resolved and verified (via `cat-file -t == blob`) at either
# $SYNC_REF_NAME or refs/loom-upstream/main. That is exactly what "this tool
# never guesses" promises NOT to do (hash the file on disk and record THAT
# as if it were upstream's) -- it says nothing about which of two verified
# upstream digests wins a tie, and the tie-break is deterministic, named,
# and documented, not a guess. No data-loss chain exists either way: a
# receipt entry naming either candidate's digest keeps the customer's
# current (edited) file at uninstall time, since disk matches neither.
# This test pins the documented tie-break so a future change is a visible
# regression against explicit assertions, not silent drift.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "── Round-5 finding 2 (pin): sync-ref vs upstream-main disagreement, disk matching neither, records sync-ref's own upstream blob -- never disk bytes, never upstream-main's blob ──"
DISAGREE_F="$WORKDIR/upstream-blob-disagree"
mkdir -p "$DISAGREE_F"
(
  cd "$DISAGREE_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "sync-content" > f.sh
  git add -A
  git commit -q -m "U1: the version this repo actually synced to"
)
DISAGREE_SHA_SYNC="$(git -C "$DISAGREE_F" rev-parse HEAD)"
(
  cd "$DISAGREE_F"
  echo "main-content" > f.sh
  git add -A
  git commit -q -m "U2: upstream advanced further -- fetched but not yet accepted downstream"
)
DISAGREE_SHA_MAIN="$(git -C "$DISAGREE_F" rev-parse HEAD)"
# Disk still holds what U1 wrote (downstream never accepted U2's edit to
# f.sh), then the adopter edited it by hand -- a THIRD, distinct value.
git -C "$DISAGREE_F" checkout -q "$DISAGREE_SHA_SYNC" -- f.sh
echo "customer-edited-content" > "$DISAGREE_F/f.sh"
cat > "$DISAGREE_F/.logicloom-adopt-receipt.json" <<'JSON'
{"schema": "logicloom/adopt-receipt@1", "runs": [], "uninstall": {}}
JSON
echo "$DISAGREE_SHA_SYNC" > "$DISAGREE_F/.sdd-sync-ref"
git -C "$DISAGREE_F" update-ref refs/loom-upstream/main "$DISAGREE_SHA_MAIN"

DISAGREE_OUT="$(bash "$RECORDER_SCRIPT" --root "$DISAGREE_F" --version v7.0.0 f.sh 2>&1)"
DISAGREE_RC=$?
DISAGREE_GOT_SHA="$(json_run_wrote_sha "$DISAGREE_F/.logicloom-adopt-receipt.json" 0 "f.sh")"
DISAGREE_SYNC_SHA="$(sha256_of_blob "$DISAGREE_F" "${DISAGREE_SHA_SYNC}:f.sh")"
DISAGREE_MAIN_SHA="$(sha256_of_blob "$DISAGREE_F" "${DISAGREE_SHA_MAIN}:f.sh")"
DISAGREE_DISK_SHA="$(sha256_of "$DISAGREE_F/f.sh")"
assert "sanity: the three candidates are genuinely distinct (sync != main != disk)" \
  "[ \"\$DISAGREE_SYNC_SHA\" != \"\$DISAGREE_MAIN_SHA\" ] && [ \"\$DISAGREE_SYNC_SHA\" != \"\$DISAGREE_DISK_SHA\" ] && [ \"\$DISAGREE_MAIN_SHA\" != \"\$DISAGREE_DISK_SHA\" ]"
assert "record mode still succeeds (rc 0) -- a disagreement is not refused" \
  "[ $DISAGREE_RC -eq 0 ] && printf '%s\n' \"\$DISAGREE_OUT\" | grep -qxF 'RECORDED f.sh'"
assert "the recorded digest is sync-ref's blob -- the documented tie-break ('the sync-ref blob is recorded ... sync-ref is the stable one')" \
  "[ \"\$DISAGREE_GOT_SHA\" = \"\$DISAGREE_SYNC_SHA\" ]"
assert "…never upstream-main's blob" \
  "[ \"\$DISAGREE_GOT_SHA\" != \"\$DISAGREE_MAIN_SHA\" ]"
assert "…and never a hash of the disk bytes themselves (the 'never a guess' contract: only a verified upstream blob is ever recorded)" \
  "[ \"\$DISAGREE_GOT_SHA\" != \"\$DISAGREE_DISK_SHA\" ]"

# ─────────────────────────────────────────────────────────────────────────
# Round-5 finding 8 (low, silent-no-op): an empty VERSION -- no --version
# given AND .logic-loom/config/architecture.conf has no FRAMEWORK_VERSION
# line (or does not exist) -- flows straight into append-run, which embeds
# it as "logicloom-update-framework@" + version: nothing after the "@"
# when version is empty. TRUSTED_GENERATOR_RE requires `.+` after "@", so
# that run can never be trusted by any later read -- fail-safe, but was a
# SILENT one: the command printed RECORDED lines and exited 0 with no hint
# the run it just wrote was already dead on arrival. Both actual-write call
# sites (record mode's append-run and --reconcile --apply's) now warn on
# stderr instead -- a WARNING, not a refusal: an earlier version of this
# fix made it a hard `exit 2`, which broke several EXISTING, unrelated
# tests elsewhere in this suite (quote/newline-named candidates, multi-file
# ancestor recording, …) that legitimately call record mode or --reconcile
# --apply with no architecture.conf at all. A warning preserves every
# existing guarantee (still records, still rc 0, the receipt still gets
# exactly the same bytes as before this fix) while making the gap visible
# instead of silent.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "── Round-5 finding 8: record mode WARNS (not refuses) when no version can be determined (no --version, no FRAMEWORK_VERSION) ──"
NOVER_F="$WORKDIR/no-framework-version"
mkdir -p "$NOVER_F/docs"
(
  cd "$NOVER_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "content" > docs/a.md
  git add -A
  git commit -q -m "no architecture.conf at all"
)
NOVER_SHA="$(git -C "$NOVER_F" rev-parse HEAD)"
cat > "$NOVER_F/.logicloom-adopt-receipt.json" <<'JSON'
{"schema": "logicloom/adopt-receipt@1", "runs": [], "uninstall": {}}
JSON
echo "$NOVER_SHA" > "$NOVER_F/.sdd-sync-ref"
git -C "$NOVER_F" update-ref refs/loom-upstream/main "$NOVER_SHA"
NOVER_OUT="$(bash "$RECORDER_SCRIPT" --root "$NOVER_F" docs/a.md 2>"$WORKDIR/nover.err")"
NOVER_RC=$?
assert "record mode with no --version and no architecture.conf: still succeeds (rc 0), still records docs/a.md" \
  "[ $NOVER_RC -eq 0 ] && printf '%s\n' \"\$NOVER_OUT\" | grep -qxF 'RECORDED docs/a.md'"
assert "…but WARNS on stderr, naming the reason and the fix" \
  "grep -qF 'WARNING: could not determine a framework version' '$WORKDIR/nover.err' && grep -qF 'pass --version' '$WORKDIR/nover.err'"
NOVER_GEN="$(json_run_field "$NOVER_F/.logicloom-adopt-receipt.json" 0 generator)"
assert "…the recorded run's generator is exactly 'logicloom-update-framework@' (empty version, nothing after '@') -- the untrusted shape TRUSTED_GENERATOR_RE was always going to reject on its own, unchanged from before this fix" \
  "[ \"\$NOVER_GEN\" = 'logicloom-update-framework@' ]"
NOVER2_F="$WORKDIR/no-framework-version-explicit"
mkdir -p "$NOVER2_F/docs"
(
  cd "$NOVER2_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "content" > docs/a.md
  git add -A
  git commit -q -m "no architecture.conf, but --version given explicitly"
)
NOVER2_SHA="$(git -C "$NOVER2_F" rev-parse HEAD)"
cat > "$NOVER2_F/.logicloom-adopt-receipt.json" <<'JSON'
{"schema": "logicloom/adopt-receipt@1", "runs": [], "uninstall": {}}
JSON
echo "$NOVER2_SHA" > "$NOVER2_F/.sdd-sync-ref"
git -C "$NOVER2_F" update-ref refs/loom-upstream/main "$NOVER2_SHA"
NOVER2_OUT="$(bash "$RECORDER_SCRIPT" --root "$NOVER2_F" --version v7.0.0 docs/a.md 2>"$WORKDIR/nover2.err")"
NOVER2_RC=$?
assert "…and an explicit --version silences the warning entirely (rc 0, records docs/a.md, no WARNING on stderr)" \
  "[ $NOVER2_RC -eq 0 ] && printf '%s\n' \"\$NOVER2_OUT\" | grep -qxF 'RECORDED docs/a.md' && [ ! -s '$WORKDIR/nover2.err' ]"
NOVER2_GEN="$(json_run_field "$NOVER2_F/.logicloom-adopt-receipt.json" 0 generator)"
assert "…the recorded run's generator is trusted-shaped (logicloom-update-framework@v7.0.0 normalized to 7.0.0)" \
  "[ \"\$NOVER2_GEN\" = 'logicloom-update-framework@7.0.0' ]"
# Control: a listing-only --reconcile (no --apply, nothing to record) never
# reaches append-run at all, so it must NOT be affected by the missing
# version -- exactly the many fixtures elsewhere in this suite that already
# rely on that.
NOVER_RECON_F="$WORKDIR/no-framework-version-reconcile-listing"
mkdir -p "$NOVER_RECON_F/docs"
(
  cd "$NOVER_RECON_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "content" > docs/a.md
  git add -A
  git commit -q -m "no architecture.conf, nothing to reconcile"
)
NOVER_RECON_SHA="$(git -C "$NOVER_RECON_F" rev-parse HEAD)"
cat > "$NOVER_RECON_F/.logicloom-adopt-receipt.json" <<'JSON'
{"schema": "logicloom/adopt-receipt@1", "runs": [], "uninstall": {}}
JSON
echo "$NOVER_RECON_SHA" > "$NOVER_RECON_F/.sdd-sync-ref"
git -C "$NOVER_RECON_F" update-ref refs/loom-upstream/main "$NOVER_RECON_SHA"
NOVER_RECON_OUT="$(bash "$RECORDER_SCRIPT" --root "$NOVER_RECON_F" --reconcile 2>&1)"
NOVER_RECON_RC=$?
assert "control: a listing-only --reconcile with no architecture.conf and nothing to record is UNAFFECTED (rc 0, never mentions 'framework version')" \
  "[ $NOVER_RECON_RC -eq 0 ] && ! printf '%s\n' \"\$NOVER_RECON_OUT\" | grep -qF 'framework version'"

# ─────────────────────────────────────────────────────────────────────────
# Round-4 REVIEWER: --reconcile's candidate check (`-L` / `-f` on the final
# component) followed a symlinked ANCESTOR. Candidates are INDEX paths from
# `git ls-files`, so a recorded directory the adopter has since replaced
# (unstaged) with a symlink to a directory elsewhere — here, OUTSIDE the
# repository — still listed its old index paths; `-f` and `cmp` went
# through the link, RECONCILE was printed, and --apply RECORDED the index
# path with the upstream digest: a claim that LogicLoom wrote bytes that now
# live wherever the customer's link points (the receipt's later "digest
# matches -> delete" step would then unlink the file AT that target). Record
# mode already refuses the same path (canon_path resolves the parent with
# `pwd -P` and rejects anything outside the root); --reconcile now applies
# the same rule and skips it loudly — neither RECONCILE nor DIFFERS.
# Reproduced on the round-4 builder tree (RECONCILE printed, 3 entries
# recorded). Fail-then-pass: LOOM_TEST_RECORDER_SCRIPT=<that copy>.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "── Round-4 REVIEWER: --reconcile never lists or records an index path that goes through a symlinked directory ──"
SYMDIR_F="$WORKDIR/reconcile-symlinked-dir"
mkdir -p "$SYMDIR_F/.logic-loom/scripts/bash"
(
  cd "$SYMDIR_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "b-content" > .logic-loom/scripts/bash/b.sh
  git add -A
  git commit -q -m "S"
)
SYMDIR_SHA="$(git -C "$SYMDIR_F" rev-parse HEAD)"
cat > "$SYMDIR_F/.logicloom-adopt-receipt.json" <<'JSON'
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "at": "2026-08-31T00:00:00.000Z",
      "generator": "logicloom@6.6.2",
      "status": "complete",
      "wrote": [
        {"target": "harness", "path": ".logic-loom/scripts/bash/", "kind": "dir"}
      ],
      "skipped": [], "failed": [], "notAttempted": []
    }
  ],
  "uninstall": {}
}
JSON
echo "$SYMDIR_SHA" > "$SYMDIR_F/.sdd-sync-ref"
git -C "$SYMDIR_F" update-ref refs/loom-upstream/main "$SYMDIR_SHA"
SYMDIR_OUT="$WORKDIR/reconcile-symlinked-dir-outside"
mkdir -p "$SYMDIR_OUT"
mv "$SYMDIR_F/.logic-loom/scripts/bash" "$SYMDIR_OUT/bash"
ln -s "$SYMDIR_OUT/bash" "$SYMDIR_F/.logic-loom/scripts/bash"
assert "sanity: the index still lists the old path (nothing was staged), and on disk it now goes through a symlink to outside the repo" \
  "[ \"\$(git -C '$SYMDIR_F' ls-files -- .logic-loom/scripts/bash)\" = '.logic-loom/scripts/bash/b.sh' ] && [ -L '$SYMDIR_F/.logic-loom/scripts/bash' ] && [ -f '$SYMDIR_OUT/bash/b.sh' ]"
SYMDIR_CKSUM_BEFORE="$(cksum "$SYMDIR_F/.logicloom-adopt-receipt.json")"
SYMDIR_LIST_OUT="$(bash "$RECORDER_SCRIPT" --root "$SYMDIR_F" --reconcile 2>"$WORKDIR/symdir-list.err")"
SYMDIR_LIST_RC=$?
assert "--reconcile lists NEITHER RECONCILE nor DIFFERS for the path behind the link, and reports nothing to record (rc 0)" \
  "[ $SYMDIR_LIST_RC -eq 0 ] && ! printf '%s\n' \"\$SYMDIR_LIST_OUT\" | grep -qF 'b.sh' && printf '%s\n' \"\$SYMDIR_LIST_OUT\" | grep -qxF 'reconcile: nothing to record'"
assert "…and says why on stderr, naming the path and that a directory on its path is a symlink" \
  "grep -qF -- '--reconcile skipping .logic-loom/scripts/bash/b.sh: a directory on its path is a symlink' '$WORKDIR/symdir-list.err'"
bash "$RECORDER_SCRIPT" --root "$SYMDIR_F" --reconcile --apply >/dev/null 2>&1
SYMDIR_CKSUM_AFTER="$(cksum "$SYMDIR_F/.logicloom-adopt-receipt.json")"
assert "--reconcile --apply writes nothing (receipt byte-identical: the bug recorded b.sh plus two ancestor dirs as LogicLoom's)" \
  "[ '$SYMDIR_CKSUM_BEFORE' = '$SYMDIR_CKSUM_AFTER' ]"
assert "…the link and the outside file are untouched" \
  "[ -L '$SYMDIR_F/.logic-loom/scripts/bash' ] && [ \"\$(readlink '$SYMDIR_F/.logic-loom/scripts/bash')\" = '$SYMDIR_OUT/bash' ] && [ \"\$(cat '$SYMDIR_OUT/bash/b.sh')\" = 'b-content' ]"
assert "record mode refuses the same path for the same reason (it resolves outside the root) — the two modes agree" \
  "! bash \"\$RECORDER_SCRIPT\" --root '$SYMDIR_F' --version v7.0.0 .logic-loom/scripts/bash/b.sh >/dev/null 2>'$WORKDIR/symdir-record.err' && grep -qF 'resolves outside the root' '$WORKDIR/symdir-record.err'"

# ─────────────────────────────────────────────────────────────────────────
# Round-5 REVIEWER: _dir_is_fully_accounted() handed the directory name to
# `git ls-files -z -- "$dir"` as a raw PATHSPEC. A name beginning with ':'
# is pathspec MAGIC to git (`:colon` parses as an empty magic signature
# plus the pattern "colon"), so a directory named `:colon` enumerated as
# EMPTY with exit status 0 — indistinguishable from a directory holding
# nothing — and the finding-3 fix above (which checks git's exit status)
# could not see it: the loop read zero entries, returned "fully
# accounted", and `:colon/` was recorded as a kind:dir entry although
# `:colon/customer-own.md` is tracked and unrecorded. Reproduced on the
# round-5 builder tree (`RECORDED :colon/` printed; the plain-named twin
# `colon/` correctly refused). Every pathspec the recorder builds from a
# directory name is now `:(literal)<name>` — no magic, no wildcards, prefix
# (recursive) matching unchanged — which is also what lets a legitimately
# recorded ':'-named directory be reconciled at all (the raw form silently
# swept nothing). Fail-then-pass: LOOM_TEST_RECORDER_SCRIPT=<round-5
# builder copy>.
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "── Round-5 REVIEWER: a directory name git would read as pathspec magic (':colon') is enumerated literally — never claimed as fully accounted on an empty misparse ──"
COLON_F="$WORKDIR/dir-accounted-colon-magic"
mkdir -p "$COLON_F/:colon" "$COLON_F/:colon2"
(
  cd "$COLON_F"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  echo "leaf-content" > ":colon/leaf.sh"
  echo "the customer's own tracked file, never recorded" > ":colon/customer-own.md"
  echo "leaf-content-2" > ":colon2/leaf.sh"
  git add -A
  git commit -q -m "R5 reviewer baseline"
)
COLON_SHA="$(git -C "$COLON_F" rev-parse HEAD)"
cat > "$COLON_F/.logicloom-adopt-receipt.json" <<'JSON'
{"schema": "logicloom/adopt-receipt@1", "runs": [], "uninstall": {}}
JSON
echo "$COLON_SHA" > "$COLON_F/.sdd-sync-ref"
git -C "$COLON_F" update-ref refs/loom-upstream/main "$COLON_SHA"
assert "sanity: git's raw pathspec parse of ':colon' lists nothing (rc 0) while the literal form lists both tracked files — the misparse this block closes" \
  "[ -z \"\$(git -C '$COLON_F' ls-files -- ':colon' 2>/dev/null)\" ] && [ \"\$(git -C '$COLON_F' ls-files -- ':(literal):colon' | wc -l | tr -d ' ')\" = 2 ]"
COLON_OUT="$(bash "$RECORDER_SCRIPT" --root "$COLON_F" --version v7.0.0 ":colon/leaf.sh" ":colon2/leaf.sh" 2>&1)"
COLON_RC=$?
assert "both files record fine (rc 0)" \
  "[ $COLON_RC -eq 0 ] && printf '%s\n' \"\$COLON_OUT\" | grep -qxF 'RECORDED :colon/leaf.sh' && printf '%s\n' \"\$COLON_OUT\" | grep -qxF 'RECORDED :colon2/leaf.sh'"
assert ":colon/ must NOT be recorded — :colon/customer-own.md is tracked and unaccounted (the bug: the misparsed enumeration read as empty, so the directory was claimed)" \
  "! printf '%s\n' \"\$COLON_OUT\" | grep -qxF 'RECORDED :colon/' && [ \"\$(json_run_has_dir_entry '$COLON_F/.logicloom-adopt-receipt.json' 0 ':colon/')\" = no ]"
assert "control: :colon2/ (every tracked file under it recorded by this call) IS recorded — the literal pathspec still enumerates a ':'-named directory" \
  "printf '%s\n' \"\$COLON_OUT\" | grep -qxF 'RECORDED :colon2/' && [ \"\$(json_run_has_dir_entry '$COLON_F/.logicloom-adopt-receipt.json' 0 ':colon2/')\" = yes ]"
# --reconcile's sweep of a recorded ':'-named directory, and its upstream
# corroboration (loom_upstream_ever_had_dir), use the same literal form: the
# sync-ref commit had the tree, so the directory is corroborated, and the
# unrecorded byte-identical sibling committed below is listed.
echo "an unrecorded byte-identical sibling" > "$COLON_F/:colon2/sibling.md"
( cd "$COLON_F" && git add -A && git commit -q -m "sibling" )
COLON_SHA2="$(git -C "$COLON_F" rev-parse HEAD)"
echo "$COLON_SHA2" > "$COLON_F/.sdd-sync-ref"
git -C "$COLON_F" update-ref refs/loom-upstream/main "$COLON_SHA2"
COLON_RECON="$(bash "$RECORDER_SCRIPT" --root "$COLON_F" --reconcile 2>&1)"
assert "--reconcile sweeps the recorded ':colon2/' literally and lists the unrecorded sibling as RECONCILE (the raw pathspec swept nothing and corroborated nothing)" \
  "printf '%s\n' \"\$COLON_RECON\" | grep -qxF 'RECONCILE :colon2/sibling.md'"

# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
