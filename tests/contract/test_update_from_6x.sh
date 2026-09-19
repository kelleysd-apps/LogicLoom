#!/usr/bin/env bash
# Contract Test: v7.0.0 arrives through an OLD (v6.6.2) /update-framework
#
# THE CLAIM UNDER TEST (the maintainer's condition for accepting the renamed
# release-migration files, per the v7 design doc §14 and the compat-package
# brief): a 6.x customer never gets THIS tree's copy of extract-proposals.sh,
# framework-updater/SKILL.md or update-framework.md — they run the versions
# npm/git already gave them at v6.6.2. So the only honest way to prove "older
# installs still receive the v7 machinery" is to run THEIR OLD SCRIPT, unmodified,
# against a tree shaped like their tree, and read what it actually offers.
#
# This suite does exactly that, twice — once for a plain template clone, once
# for an `npx logicloom init`-adopted repo — using the REAL v6.6.2 tag content
# (never this tree's copies of the old scripts):
#
#   1. Build a v6.6.2 fixture with `git archive v6.6.2` (template) or by running
#      the real v6.6.2-era `packaging/adopt` CLI under node (adopted).
#   2. Build the upstream tip a customer would actually fetch: THIS tree's
#      tracked working tree run through the SAME three-step build that
#      .github/workflows/promote-to-main.yml runs at release —
#      sanitize-for-template -> strip-harness-dev -> history-scrub (from a
#      preserved copy, since it strips itself) — exactly as
#      tests/contract/test_shipped_gates_vs_strip.sh's build_stripped_tree()
#      does. NOT HEAD^{tree}: dev-main carries maintainer-only files the
#      template never ships, and a strip-manifest or scrub-rule change could
#      drop or rewrite a machinery file on the way out. Asserting against the
#      raw dev-main tree would stay green through exactly that regression.
#      (Why the tracked WORKING tree and not HEAD: HEAD is the state that
#      already shipped; a contract test that only sees HEAD cannot fail on the
#      change you are about to commit — the lesson recorded in
#      build_stripped_tree(). In CI the two coincide.)
#   3. Point the fixture's `refs/loom-upstream/main` at a commit carrying that
#      sanitized tree, grafted onto the fixture's own `.sdd-sync-ref` lineage
#      with `git commit-tree`, entirely inside the FIXTURE's own throwaway .git
#      (never this repo's), so the ancestry check `extract-proposals.sh`
#      requires actually holds. (Why a graft, not a plain fetch of this branch's
#      tip: the real public template branch was re-rooted at v6.2.0, so it does
#      not share history with this internal dev branch — see the design doc §0.
#      A future `/promote` will make this real; the graft simulates that
#      landing without running the publish half of the pipeline.)
#   4. SOURCE the fixture's OWN `extract-proposals.sh` (the file that shipped in
#      v6.6.2 — verified byte-identical to the tag, §A/§E below) and call its
#      real `extract_proposals()` function. Assert every v7-machinery file in
#      tests/fixtures/update-from-6x/v7-machinery-paths.txt is offered as
#      clean-add/clean-apply — never missing, never silently dropped.
#   5. In the template fixture, simulate accepting those proposals and run the
#      FIXTURE'S OWN, just-accepted `release-migrations.sh scan` (not this
#      tree's copy pointed at the fixture with --root) once, to show the new
#      tool actually runs on what a moment ago was a 6.x tree — with the
#      sibling files the customer actually has. This is what caught the
#      extract-proposals.sh row: release-migrations.sh sources
#      "$SCRIPT_DIR/extract-proposals.sh" and calls detect_adopt_mode, which
#      the v6.6.2 extractor does not define; a customer who accepted the scan
#      but not the extractor got `detect_adopt_mode: command not found` on
#      stderr and silently lost ADOPTED detection.
#
# A CONTROL CASE (§B, run first) proves the check itself is not vacuous: pointed
# at an upstream with NO changes, the same checker must report every path
# MISSING. If it ever reported them present there, the real assertions in §C/§E
# would be trivially true and worthless.
#
# FINDING, stated up front because it changes what "prove nothing is suppressed"
# means here: v6.6.2's extract-proposals.sh (verified at §A) has NO ownership/
# ADOPTED-mode filtering at all — `grep -c adopt_file_recorded` on it is 0. That
# filtering (the "rot gap" WP4 closes) landed in 39b59d5 (2026-09-02), after the
# v6.6.2 stamp and in no shipped tag or npm version (npm carries 6.6.0–6.6.2
# only); an old customer's installed script cannot suppress anything by it,
# because it does not have the code that suppresses. So the failure mode this
# suite actually guards is simpler and unconditional: the OLD script's plain
# sync-ref..upstream diff must still name every v7 file. If it does not — for
# ANY reason, ownership-shaped or otherwise — §C/§E fail with the exact path
# list and this is a release blocker.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}, no `sort -V`.
# Every fixture is a real, throwaway git repo built INSIDE this script (the
# sanctioned pattern per test_update_framework_ownership.sh's own header): this
# file runs as `bash tests/contract/test_update_from_6x.sh`, a separate process
# the agent-side git guard does not (and need not) reach inside of. The only
# git calls that are not plain reads (`git commit-tree`, `git write-tree`,
# `update-ref`) always run with a throwaway fixture as their OWN git dir;
# `alternates` only grants READ access to this repo's objects — nothing is ever
# written to, or mutated in, the real LogicLoom checkout. The object-store path
# is resolved with `rev-parse --git-path objects`, so this also works from a
# linked worktree (where `.git` is a file, and `$REAL_ROOT/.git/objects` does
# not exist — that hardcoded path is exactly how the first version of this
# suite reported a false 10-assertion RELEASE BLOCKER from a worktree).
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0; SKIP=0
assert() {
  TOTAL=$((TOTAL + 1)); desc="$1"; condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}
skip_note() { SKIP=$((SKIP + 1)); echo "  ⏭  SKIP: $1"; }

echo "═══ update-from-6x compat: v7.0.0 through an OLD /update-framework ═══"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if REAL_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  REAL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
FIXTURES_DIR="$REAL_ROOT/tests/fixtures/update-from-6x"
MACHINERY_LIST="$FIXTURES_DIR/v7-machinery-paths.txt"
NEW_SCAN="$REAL_ROOT/plugins/loom-maintenance/scripts/release-migrations.sh"
STRIP_SCRIPT="$REAL_ROOT/.logic-loom/scripts/bash/strip-harness-dev.sh"
SANITIZE_SCRIPT="$REAL_ROOT/.logic-loom/scripts/bash/sanitize-for-template.sh"
SCRUB_SCRIPT="$REAL_ROOT/.logic-loom/scripts/bash/history-scrub.sh"

# shellcheck source=/dev/null
source "$REAL_ROOT/tests/lib/tree-provenance.sh"
TREE_KIND="$(loom_tree_kind "$REAL_ROOT")"
echo "tree kind: $TREE_KIND"
echo ""

if [ "$TREE_KIND" = "inconsistent" ]; then
  loom_require_consistent_tree "$REAL_ROOT" || true
  echo "═══════════════════════════════════════"
  echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed, ${SKIP} skipped"
  echo "═══════════════════════════════════════"
  exit 1
fi

if [ "$TREE_KIND" = "sanitized" ]; then
  skip_note "this is a maintainer-only check — it rebuilds a real v6.6.2 fixture from THIS repo's own git history (git archive v6.6.2, git show <dev-main commit>:packaging/adopt) and runs the release strip pipeline, none of which a sanitized/promoted customer tree carries"
  echo ""
  echo "Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
  echo "✅ ALL TESTS PASSED (nothing to run on a sanitized tree)"
  exit 0
fi

assert "the machinery-paths fixture exists" "[ -f \"\$MACHINERY_LIST\" ]"
assert "the new release-migrations.sh scan script exists in this tree" "[ -f \"\$NEW_SCAN\" ]"
assert "the release strip pipeline exists in this tree (sanitize, strip, scrub)" \
  "[ -f \"\$SANITIZE_SCRIPT\" ] && [ -f \"\$STRIP_SCRIPT\" ] && [ -f \"\$SCRUB_SCRIPT\" ]"
if [ ! -f "$MACHINERY_LIST" ] || [ ! -f "$NEW_SCAN" ] \
   || [ ! -f "$SANITIZE_SCRIPT" ] || [ ! -f "$STRIP_SCRIPT" ] || [ ! -f "$SCRUB_SCRIPT" ]; then
  echo ""
  echo "Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
  echo "❌ SOME TESTS FAILED"
  exit 1
fi

# ── Preconditions ────────────────────────────────────────────────────────────
# On a maintainer tree (dev-main / this checkout) with a normal, unshallowed
# clone, v6.6.2 is always resolvable — CI's plugin-tests.yml checks out with
# `fetch-depth: 0`. So on THIS tree kind a missing tag is a real, hard FAIL,
# not a skip: it means the checkout is shallow/broken, and every assertion
# below would otherwise silently not run.
#
# `^{commit}` — v6.6.2 is a lightweight tag today, but a bare `rev-parse v6.6.2`
# on an ANNOTATED tag returns the tag object, which `commit-tree -p` rejects.
V662_SHA=""
if V662_SHA="$(git -C "$REAL_ROOT" rev-parse 'v6.6.2^{commit}' 2>/dev/null)"; then :; else V662_SHA=""; fi
assert "tag v6.6.2 resolves to a commit in this repo's history" "[ -n \"\$V662_SHA\" ]"

if [ -z "$V662_SHA" ]; then
  echo ""
  echo "  This suite needs the real v6.6.2 tag (git fetch --tags) to build a"
  echo "  faithful fixture — see the file header for why HEAD's own copies of"
  echo "  the old scripts must never be substituted. On a maintainer tree this"
  echo "  means the checkout is shallow or tags were not fetched — fix the"
  echo "  checkout (fetch-depth: 0, tags included), do not weaken this check."
  echo ""
  echo "Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
  echo "❌ SOME TESTS FAILED"
  exit 1
fi

# This repo's object store, resolved the way git itself resolves it. In a plain
# checkout this is `.git/objects` (relative to the repo); in a linked worktree
# it is the ABSOLUTE path of the main repository's store. Normalised to an
# absolute, symlink-free path because it is written verbatim into a fixture's
# alternates file.
REAL_OBJECTS="$(git -C "$REAL_ROOT" rev-parse --git-path objects 2>/dev/null)"
case "$REAL_OBJECTS" in
  /*) ;;
  *)  REAL_OBJECTS="$REAL_ROOT/$REAL_OBJECTS" ;;
esac
if [ -d "$REAL_OBJECTS" ]; then REAL_OBJECTS="$(cd "$REAL_OBJECTS" && pwd -P)"; fi
assert "this repo's object store resolves (plain checkout OR linked worktree)" "[ -d \"\$REAL_OBJECTS\" ]"

HEAD_TREE="$(git -C "$REAL_ROOT" rev-parse 'HEAD^{tree}')"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/loom-update-from-6x.XXXXXX")"
cleanup() { [ -n "${TMP:-}" ] && rm -rf "$TMP"; }
trap cleanup EXIT

git_quiet() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}" >/dev/null 2>&1; }

# objects_dir_of <repo-dir> — that repo's object store, absolute.
objects_dir_of() {
  od="$(git -C "$1" rev-parse --git-path objects 2>/dev/null)"
  case "$od" in /*) ;; *) od="$1/$od" ;; esac
  printf '%s' "$od"
}

# ── Helpers ──────────────────────────────────────────────────────────────────

# archive_v662_tree <dest-dir>  — the REAL sanitized v6.6.2 tag tree, nothing else
archive_v662_tree() {
  mkdir -p "$1"
  git -C "$REAL_ROOT" archive v6.6.2 | tar -x -C "$1"
}

# init_fixture_repo <dir> <sync-ref-value>  — git init, commit the tree as-is,
# then stamp .sdd-sync-ref and commit that separately (mirrors how a real
# template clone's sync-ref commit sits one commit after the payload).
init_fixture_repo() {
  ( cd "$1" \
    && git init -q -b main \
    && git add -A \
    && git -c user.email=t@t -c user.name=t commit -q -m "v6.6.2 fixture payload" \
    && printf '%s\n' "$2" > .sdd-sync-ref \
    && git add .sdd-sync-ref \
    && git -c user.email=t@t -c user.name=t commit -q -m "stamp .sdd-sync-ref"
  )
}

# build_sanitized_upstream_tree — copies THIS tree's tracked working tree (plus
# untracked-but-not-ignored, minus tracked-but-deleted: the set about to be
# committed, exactly as test_shipped_gates_vs_strip.sh's build_stripped_tree()
# copies it) into $SANITIZED, runs the same three steps in the same order as
# promote-to-main.yml's "Build sanitized tree from dev-main" (sanitize ->
# strip -> scrub from the PRESERVED copy, since strip removes the scrubber),
# and echoes the resulting git TREE sha. Its objects live in $SANITIZED/.git and
# are read by the fixtures through `alternates`. Returns 1 on any failure; the
# build log is $TMP/sanitize.log.
build_sanitized_upstream_tree() {
  rm -rf "$SANITIZED"; mkdir -p "$SANITIZED" || return 1
  if ! ( cd "$REAL_ROOT" && git ls-files -z --cached --others --exclude-standard \
           | while IFS= read -r -d '' f; do
               [ -e "$f" ] || [ -L "$f" ] || continue   # tracked-but-deleted
               printf '%s\0' "$f"
             done \
           | tar --null -T - -cf - ) | tar -x -C "$SANITIZED" 2>"$TMP/sanitize.log"; then
    return 1
  fi
  ( cd "$SANITIZED" \
    && git init -q -b main \
    && git add -A \
    && bash .logic-loom/scripts/bash/sanitize-for-template.sh \
    && bash .logic-loom/scripts/bash/strip-harness-dev.sh \
    && LOOM_SCRUB_ROOT="$SANITIZED" bash "$SCRUB_SCRIPT" \
    && git add -A ) >> "$TMP/sanitize.log" 2>&1 || return 1
  git -C "$SANITIZED" write-tree
}

# graft_synthetic_upstream <fixture-dir> <parent-sha> <content-tree-sha>
# Sets refs/loom-upstream/main, inside the FIXTURE's own .git, to a commit
# whose tree is <content-tree-sha> and whose parent is <parent-sha> — i.e. "the
# named tree, arriving as a descendant of the fixture's own baseline". Reads
# this repo's objects (and the sanitized tree's) via `alternates` — never
# writes to either. Echoes the synthetic commit sha.
graft_synthetic_upstream() {
  fdir="$1"; parent="$2"; tree="$3"
  fobj="$(objects_dir_of "$fdir")"
  mkdir -p "$fobj/info"
  {
    echo "$REAL_OBJECTS"
    [ -n "${SANITIZED_OBJECTS:-}" ] && echo "$SANITIZED_OBJECTS"
    true
  } > "$fobj/info/alternates"
  ( cd "$fdir" \
    && syn="$(git commit-tree "$tree" -p "$parent" -m "synthetic upstream tip (test fixture only; not a real release commit)")" \
    && git update-ref refs/loom-upstream/main "$syn" \
    && echo "$syn"
  )
}

# A tiny standalone runner, written once to $TMP: sourced in a FRESH bash
# process (never a subshell forked from this already-deep call stack — a
# `(set -euo pipefail; source ...)` subshell nested inside this script's own
# function calls was observed to leave bash 3.2's BASH_SOURCE array unusable,
# which extract-proposals.sh's own REPO_ROOT computation depends on). This
# gives the sourced script exactly the fresh, top-level BASH_SOURCE[0] it
# expects, and its `set -euo pipefail` / any `exit N` only ever ends this
# child process, never this test script.
EXTRACT_RUNNER="$TMP/run-extract.sh"
cat > "$EXTRACT_RUNNER" <<'RUNNER_EOF'
set -euo pipefail
source "$1"
SYNC_REF="$(ensure_sync_ref)"
extract_proposals "$SYNC_REF" "${LOOM_UPSTREAM_REF:-refs/loom-upstream/main}"
RUNNER_EOF

# extract_with_fixture_script <fixture-dir> <out-json> <out-err>
# Runs the FIXTURE's OWN extract-proposals.sh (never this tree's copy) and
# calls its real extract_proposals(). Returns extract's exit code.
extract_with_fixture_script() {
  fdir="$1"; out="$2"; err="$3"
  bash "$EXTRACT_RUNNER" "$fdir/plugins/loom-maintenance/scripts/extract-proposals.sh" \
    > "$out" 2> "$err"
  echo $?
}

# resolution_for <proposals-json> <upstream-file-path>
# Line-oriented, not a JSON parser: v6.6.2's script embeds a raw tab in a
# rename's upstream_file value (old<TAB>new), which is invalid-as-JSON but
# stable line-by-line — awk over "key": "value" lines survives that where a
# JSON parser chokes on it. Prints the resolution, or "" if the path never
# appears as an upstream_file.
resolution_for() {
  awk -v target="$2" '
    /"upstream_file":/ {
      line=$0
      sub(/^[^"]*"upstream_file":[[:space:]]*"/, "", line)
      sub(/",?[[:space:]]*$/, "", line)
      cur=line
      next
    }
    /"resolution":/ {
      line=$0
      sub(/^[^"]*"resolution":[[:space:]]*"/, "", line)
      sub(/",?[[:space:]]*$/, "", line)
      if (cur == target) { print line; found=1 }
      next
    }
    END { if (!found) print "" }
  ' "$1"
}

# assert_machinery <label> <proposals-json> <expect-offered: yes|no>
# Walks the fixture list; when expect-offered=yes each row's resolution must
# equal the expected value in v7-machinery-paths.txt, else it is "suppressed"
# and named. When expect-offered=no (the control case) every row must be ""
# (absent) — this control run is EXPECTED to show every path missing, and the
# assertion below is written so THAT (not the opposite) is the passing case.
assert_machinery() {
  label="$1"; json="$2"; mode="$3"
  bad_list=""
  bad_count=0
  ok_count=0
  while IFS="$(printf '\t')" read -r mpath mexpect; do
    case "$mpath" in ''|'#'*) continue ;; esac
    got="$(resolution_for "$json" "$mpath")"
    if [ "$mode" = "yes" ]; then
      if [ "$got" = "$mexpect" ]; then
        ok_count=$((ok_count + 1))
      else
        bad_count=$((bad_count + 1))
        got_display="$got"; [ -z "$got_display" ] && got_display="MISSING (suppressed)"
        bad_list="${bad_list}      - $mpath -> $got_display (expected $mexpect)
"
      fi
    else
      if [ -z "$got" ]; then
        ok_count=$((ok_count + 1))
      else
        bad_count=$((bad_count + 1))
        bad_list="${bad_list}      - $mpath -> unexpectedly offered as '$got' (control case expected it absent)
"
      fi
    fi
  done < "$MACHINERY_LIST"

  if [ "$bad_count" -eq 0 ]; then
    assert "$label: all $ok_count v7-machinery path(s) $([ "$mode" = yes ] && echo 'offered, none suppressed' || echo 'correctly absent (control)')" "true"
  else
    echo "  RELEASE BLOCKER — $label: $bad_count of $((ok_count + bad_count)) v7-machinery path(s) failed:"
    printf '%s' "$bad_list"
    assert "$label: all v7-machinery paths $([ "$mode" = yes ] && echo offered || echo absent)" "false"
  fi
}

# ══ §A — locate the fixture's own v6.6.2 extract-proposals.sh and pin it ════
echo "── §A: the v6.6.2 tag's own extract-proposals.sh (never this tree's copy) ──"
V662_EP="$TMP/v662-extract-proposals.sh"
git -C "$REAL_ROOT" show "v6.6.2:plugins/loom-maintenance/scripts/extract-proposals.sh" > "$V662_EP" 2>/dev/null || true
assert "v6.6.2's extract-proposals.sh is readable from the tag" "[ -s \"\$V662_EP\" ]"
# NOTE the idiom: `grep -c` with zero matches prints "0" AND exits 1, so
# `|| echo 0` would append a SECOND "0" line and break `-eq` — `|| true`
# keeps grep's own "0" stdout and only swallows the nonzero exit.
ADOPT_MECH_COUNT="$(grep -c 'adopt_file_recorded\|ADOPT_MODE\|detect_adopt_mode' "$V662_EP" 2>/dev/null || true)"
ADOPT_MECH_COUNT="${ADOPT_MECH_COUNT:-0}"
assert "FINDING pinned: v6.6.2's script has NO ownership/ADOPTED-mode filter (count=0)" "[ \"\$ADOPT_MECH_COUNT\" -eq 0 ]"
echo ""

# ══ §A′ — the upstream tip a customer would actually fetch: the SANITIZED tree ═
echo "── §A′: build the sanitized upstream tree (promote-to-main.yml's own three steps) ──"
SANITIZED="$TMP/sanitized"
SANITIZED_OBJECTS=""
SAN_TREE=""
if SAN_TREE="$(build_sanitized_upstream_tree)"; then :; else SAN_TREE=""; fi
assert "sanitized tree built (sanitize-for-template -> strip-harness-dev -> history-scrub)" "[ -n \"\$SAN_TREE\" ]"
if [ -z "$SAN_TREE" ]; then
  echo ""
  echo "  The release strip pipeline failed on a copy of this tree — the last lines:"
  tail -15 "$TMP/sanitize.log" 2>/dev/null | sed 's/^/    /'
  echo "  Until it builds, nothing below can say what a customer's upstream would carry."
  echo ""
  echo "Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
  echo "❌ SOME TESTS FAILED"
  exit 1
fi
SANITIZED_OBJECTS="$(objects_dir_of "$SANITIZED")"
assert "sanitized tree differs from the raw dev-main tree (the strip did something)" "[ \"\$SAN_TREE\" != \"\$HEAD_TREE\" ]"
# Two paths that MUST be gone from anything a customer fetches — proof that the
# tree the fixtures are pointed at is release-shaped, not dev-main-shaped.
assert "sanitized tree has no packaging/ (the npm installer never ships in the template)" \
  "! git -C \"\$SANITIZED\" cat-file -e \"\$SAN_TREE:packaging/adopt/bin/logicloom.js\" 2>/dev/null"
assert "sanitized tree has no strip-harness-dev.sh (the release tooling strips itself)" \
  "! git -C \"\$SANITIZED\" cat-file -e \"\$SAN_TREE:.logic-loom/scripts/bash/strip-harness-dev.sh\" 2>/dev/null"
echo ""

# ══ §B — CONTROL CASE: same checker, an upstream with no changes ════════════
echo "── §B: control case (checker must report every path MISSING when nothing changed) ──"
CTRL="$TMP/control"
archive_v662_tree "$CTRL"
init_fixture_repo "$CTRL" "$V662_SHA"
V662_TREE="$(git -C "$REAL_ROOT" rev-parse 'v6.6.2^{tree}')"
# upstream tip's TREE == v6.6.2's own tree: a real "no changes since your
# version" state (a new commit, but a no-op diff — commit-tree needs a
# distinct commit, not the tag itself, so `ensure_sync_ref`'s ancestry check
# has something to walk).
CTRL_SYN="$(graft_synthetic_upstream "$CTRL" "$V662_SHA" "$V662_TREE")"
assert "control: synthetic (no-op) upstream tip was created" "[ -n \"\$CTRL_SYN\" ]"
CTRL_JSON="$TMP/control.json"; CTRL_ERR="$TMP/control.err"
CTRL_RC="$(extract_with_fixture_script "$CTRL" "$CTRL_JSON" "$CTRL_ERR")"
assert "control: extraction exits 0 on a no-op range" "[ \"\$CTRL_RC\" = 0 ]"
assert_machinery "control (upstream == sync-ref, no changes)" "$CTRL_JSON" "no"
echo ""

# ══ §C — TEMPLATE CLONE fixture ══════════════════════════════════════════════
echo "── §C: template clone at v6.6.2, upstream = this branch's SANITIZED tree ──"
TEMPLATE="$TMP/template"
archive_v662_tree "$TEMPLATE"
init_fixture_repo "$TEMPLATE" "$V662_SHA"
TEMPLATE_SYN="$(graft_synthetic_upstream "$TEMPLATE" "$V662_SHA" "$SAN_TREE")"
assert "template: synthetic upstream tip was created" "[ -n \"\$TEMPLATE_SYN\" ]"
assert "template: .sdd-sync-ref is reachable from the synthetic upstream tip" \
  "git -C \"\$TEMPLATE\" merge-base --is-ancestor \"\$V662_SHA\" refs/loom-upstream/main"

TEMPLATE_JSON="$TMP/template.json"; TEMPLATE_ERR="$TMP/template.err"
TEMPLATE_RC="$(extract_with_fixture_script "$TEMPLATE" "$TEMPLATE_JSON" "$TEMPLATE_ERR")"
assert "template: the fixture's own (v6.6.2) extract-proposals.sh exits 0" "[ \"\$TEMPLATE_RC\" = 0 ]"
assert_machinery "template clone" "$TEMPLATE_JSON" "yes"
echo ""

# ══ §D — accept the proposals, then run the FIXTURE'S OWN new scan ═════════
echo "── §D: simulate acceptance, then run the fixture's own accepted scan on the (former) 6.x tree ──"
if [ "$TEMPLATE_RC" = 0 ]; then
  while IFS="$(printf '\t')" read -r mpath mexpect; do
    case "$mpath" in ''|'#'*) continue ;; esac
    mkdir -p "$TEMPLATE/$(dirname "$mpath")"
    git -C "$TEMPLATE" show "refs/loom-upstream/main:$mpath" > "$TEMPLATE/$mpath" 2>/dev/null || true
  done < "$MACHINERY_LIST"
  git_quiet "$TEMPLATE" add -A
  git_quiet "$TEMPLATE" commit -m "simulate accepting the v7-machinery clean-add/clean-apply proposals"

  FIXTURE_SCAN="$TEMPLATE/plugins/loom-maintenance/scripts/release-migrations.sh"
  FIXTURE_EP="$TEMPLATE/plugins/loom-maintenance/scripts/extract-proposals.sh"
  assert "accepted: the fixture now holds its own release-migrations.sh" "[ -f \"\$FIXTURE_SCAN\" ]"
  # release-migrations.sh sources "$SCRIPT_DIR/extract-proposals.sh" — its
  # SIBLING, i.e. whatever copy the customer has — and calls detect_adopt_mode.
  # If the accepted set did not include the new extractor, the customer's scan
  # runs against the v6.6.2 one and that call is `command not found`.
  FIXTURE_EP_COUNT="$(grep -c 'detect_adopt_mode' "$FIXTURE_EP" 2>/dev/null || true)"
  FIXTURE_EP_COUNT="${FIXTURE_EP_COUNT:-0}"
  assert "accepted: the fixture's sibling extract-proposals.sh now defines detect_adopt_mode" "[ \"\$FIXTURE_EP_COUNT\" -gt 0 ]"

  SCAN_OUT="$TMP/new-scan.out"; SCAN_ERR="$TMP/new-scan.err"
  # The FIXTURE's copy, from the fixture, with no --root: exactly the command a
  # customer runs, against exactly the sibling files a customer has.
  ( cd "$TEMPLATE" && bash plugins/loom-maintenance/scripts/release-migrations.sh scan ) > "$SCAN_OUT" 2> "$SCAN_ERR"
  SCAN_RC=$?
  assert "new scan: exits 0 on the now-updated former-6.x tree" "[ \"\$SCAN_RC\" = 0 ]"
  assert "new scan: parsed the upstream registry" "grep -q '^registry: upstream' \"\$SCAN_OUT\""
  assert "new scan: printed a summary line (ran to completion)" "grep -q '^Summary:' \"\$SCAN_OUT\""
  assert "new scan: no 'command not found' — every function the accepted scan calls arrived with it" \
    "! grep -q 'command not found' \"\$SCAN_ERR\""
  assert "new scan: no fatal/not-found noise on stderr" "! grep -qiE 'not found|fatal|traceback' \"\$SCAN_ERR\""
  if [ -s "$SCAN_ERR" ]; then
    echo "  (scan stderr was:)"; sed 's/^/    /' "$SCAN_ERR" | head -10
  fi
else
  skip_note "§D: template extraction (§C) did not exit 0 — nothing to accept"
fi
echo ""

# ══ §E — ADOPTED install fixture (npx logicloom init, v6.6.2-era code) ═════
echo "── §E: adopted install, built with the real v6.6.2-era packaging/adopt ──"
HAVE_NODE=no
if command -v node >/dev/null 2>&1; then HAVE_NODE=yes; fi

# `packaging/` is sanitized out of the public v6.6.2 tag entirely (verified:
# `git ls-tree v6.6.2 packaging/` is empty) — the npm package is built from the
# dev-main commit that stamped the release. Anchor on that commit's own
# message ("chore(release): stamp v6.6.2 …"), not on any commit that merely
# mentions v6.6.2 while touching packaging/adopt; the byte-identical check
# below is the guard if that anchor ever drifts.
ADOPT_SRC_COMMIT=""
if [ "$HAVE_NODE" = yes ]; then
  ADOPT_SRC_COMMIT="$(git -C "$REAL_ROOT" log --all --format='%h' --grep='stamp v6.6.2' -- packaging/adopt 2>/dev/null | awk 'NR==1{print $1}')"
fi

if [ "$HAVE_NODE" != yes ]; then
  skip_note "§E: node is not on PATH; the v6.6.2-era npm installer cannot be exercised"
elif [ -z "$ADOPT_SRC_COMMIT" ]; then
  skip_note "§E: no dev-main commit found stamping v6.6.2 under packaging/adopt — cannot locate the v6.6.2-era installer (packaging/ ships to no public tag; it is maintainer-only tooling)"
else
  # Pin that the extract-proposals.sh this commit carries is what actually
  # shipped, so the ADOPTED half tests the real thing.
  ADOPT_EP="$TMP/adopt-src-extract-proposals.sh"
  git -C "$REAL_ROOT" show "$ADOPT_SRC_COMMIT:plugins/loom-maintenance/scripts/extract-proposals.sh" > "$ADOPT_EP" 2>/dev/null || true
  assert "§E: $ADOPT_SRC_COMMIT's extract-proposals.sh is byte-identical to v6.6.2's shipped copy" \
    "diff -q \"\$V662_EP\" \"\$ADOPT_EP\" >/dev/null 2>&1"

  DEV_FULL="$TMP/dev-full-v662"
  mkdir -p "$DEV_FULL"
  git -C "$REAL_ROOT" archive "$ADOPT_SRC_COMMIT" | tar -x -C "$DEV_FULL"
  ADOPT_CLI="$DEV_FULL/packaging/adopt/bin/logicloom.js"
  assert "§E: the v6.6.2-era adopt CLI exists at that commit" "[ -f \"\$ADOPT_CLI\" ]"

  ADOPTED="$TMP/adopted"
  mkdir -p "$ADOPTED"
  git_quiet "$ADOPTED" init -b main
  git_quiet "$ADOPTED" commit --allow-empty -m "customer's own repo (pre-adopt)"

  ADOPT_RUN_OUT="$TMP/adopt-run.out"
  node "$ADOPT_CLI" init "$ADOPTED" --apply --only=all > "$ADOPT_RUN_OUT" 2>&1
  ADOPT_RC=$?
  assert "§E: \`npx logicloom init --apply --only=all\` exits 0" "[ \"\$ADOPT_RC\" = 0 ]"
  assert "§E: the receipt was written" "[ -f \"\$ADOPTED/.logicloom-adopt-receipt.json\" ]"
  assert "§E: the harness landed (.logic-loom/, plugins/)" "[ -d \"\$ADOPTED/.logic-loom\" ] && [ -d \"\$ADOPTED/plugins\" ]"

  if [ "$ADOPT_RC" = 0 ] && [ -d "$ADOPTED/.logic-loom" ]; then
    # The DEV-FALLBACK payload source (used because packaging/adopt/payload/ is
    # only populated by the npm publish build step, not committed) carries
    # dev-main's OWN internal .sdd-sync-ref, not the sanitized release's. A
    # real `logicloom@6.6.2` package's payload is built from the sanitized
    # release, so correct this one field to what it actually shipped.
    V662_OWN_SYNC_REF="$(git -C "$REAL_ROOT" show v6.6.2:.sdd-sync-ref 2>/dev/null | tr -d '[:space:]')"
    assert "§E: v6.6.2's own .sdd-sync-ref stamp is readable" "[ -n \"\$V662_OWN_SYNC_REF\" ]"
    printf '%s\n' "$V662_OWN_SYNC_REF" > "$ADOPTED/.sdd-sync-ref"
    git_quiet "$ADOPTED" add -A
    git_quiet "$ADOPTED" commit -m "adopted via npx logicloom init --apply --only=all (v6.6.2 payload)"

    ADOPTED_SYN="$(graft_synthetic_upstream "$ADOPTED" "$V662_SHA" "$SAN_TREE")"
    assert "§E: synthetic upstream tip created for the adopted fixture" "[ -n \"\$ADOPTED_SYN\" ]"
    assert "§E: adopted .sdd-sync-ref is reachable from the synthetic upstream tip" \
      "git -C \"\$ADOPTED\" merge-base --is-ancestor \"\$V662_OWN_SYNC_REF\" refs/loom-upstream/main"

    ADOPTED_JSON="$TMP/adopted.json"; ADOPTED_ERR="$TMP/adopted.err"
    ADOPTED_EXTRACT_RC="$(extract_with_fixture_script "$ADOPTED" "$ADOPTED_JSON" "$ADOPTED_ERR")"
    assert "§E: the adopted fixture's own extract-proposals.sh exits 0" "[ \"\$ADOPTED_EXTRACT_RC\" = 0 ]"
    assert_machinery "adopted install" "$ADOPTED_JSON" "yes"
  else
    skip_note "§E: adopt --apply did not produce a usable install — skipping the extraction half"
  fi
fi
echo ""

# ── Report ───────────────────────────────────────────────────────────────────
echo "═══════════════════"
echo "Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
if [ "$FAIL" -eq 0 ]; then
  echo "✅ ALL TESTS PASSED"
  exit 0
else
  echo "❌ SOME TESTS FAILED"
  exit 1
fi
