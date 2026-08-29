#!/usr/bin/env bash
# Contract Tests: the .sdd-sync-ref published at a release tag is REACHABLE
#
# THE DEFECT THIS PINS (LOOM-0036, live in v6.4.1 and v6.5.0):
#   Both tags carry .sdd-sync-ref = c6092b08 — a dev-main MERGE commit that
#   `main` has never contained. `git clone --branch v6.5.0` therefore hands the
#   adopter a baseline that extract-proposals.sh cannot resolve, and
#   /update-framework dies with ".sdd-sync-ref is NOT reachable from upstream
#   main". The cause: promote-to-main.yml composed the snapshot tree straight
#   from dev-main, and dev-main's own .sdd-sync-ref is never advanced — it is
#   permanently stale. The pre-existing gate in release-tag.yml checks that the
#   snapshot COMMIT is an ancestor of main; it never read the TREE, so a stale
#   VALUE inside a perfectly reachable commit sailed straight through it.
#
# WHAT THIS SUITE COVERS
#   1. STRUCTURE — compose stamps the baseline before write-tree; both
#      workflows carry a reachability gate; neither fix routes through a new
#      remap-table entry in extract-proposals.sh.
#   2. BEHAVIOUR (real git, no shims) — a throwaway repository under $HOME
#      replays the compose/advance sequence BOTH ways. The OLD sequence must be
#      REJECTED by the gate; the NEW one must pass. The release-tag.yml tagging
#      step's own `run:` body is then EXTRACTED from the YAML and EXECUTED
#      against that repository (with a real bare remote), proving the tag lands
#      on the sync-ref commit and that a stale baseline is refused.
#
# WHAT IT DOES NOT COVER — plainly:
#   * No GitHub Actions runner, no API. Step wiring (`steps.*.outputs`) is
#     substituted, not executed.
#   * `push:` workflows run the copy of the file AT THE PUSHED COMMIT, so this
#     fix cannot apply to v6.5.0 or any existing tag. It first takes effect on
#     the NEXT release. No test can change that.
#   * Existing published tags are not repairable; this suite asserts nothing
#     about them.
#
# Skips cleanly when the workflows are absent (a customer project after
# /initialize-project removes both).
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0; SKIP=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}
skip() { SKIP=$((SKIP + 1)); echo "  ⏭️  SKIP: $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

PROMOTE_WF="$ROOT/.github/workflows/promote-to-main.yml"
TAG_WF="$ROOT/.github/workflows/release-tag.yml"
EXTRACT="$ROOT/plugins/loom-maintenance/scripts/extract-proposals.sh"

echo "═══════════════════════════════════════════════════════════"
echo "  CONTRACT: released .sdd-sync-ref is reachable from main"
echo "═══════════════════════════════════════════════════════════"

# Sandbox under $HOME (never /tmp): the behavioural half builds a real repo.
SANDBOX="$(mktemp -d "${HOME}/.loom-syncref-test.XXXXXX")"
cleanup() { [ -n "${SANDBOX:-}" ] && rm -rf "$SANDBOX"; }
trap cleanup EXIT

echo ""
echo "1. Structure — the fix is in the workflows, not in a remap table"

if [ ! -f "$PROMOTE_WF" ]; then
  skip "promote-to-main.yml absent (customer project) — structural checks"
else
  assert "compose stamps .sdd-sync-ref before write-tree" \
    "awk '/name: Compose single-parent release commit/,/name: Advance/' \"\$PROMOTE_WF\" \
       | grep -vE '^[[:space:]]*#' | grep -q 'sdd-sync-ref'"
  # Order matters: a stamp AFTER write-tree would not be in the tree.
  ORDER="$SANDBOX/compose-order.txt"
  awk '/name: Compose single-parent release commit/,/name: Advance/' "$PROMOTE_WF" \
    | grep -vE '^[[:space:]]*#' \
    | grep -nE '> \.sdd-sync-ref|write-tree' > "$ORDER"
  assert "the stamp precedes write-tree in the compose step" \
    "[ \"\$(head -1 \"\$ORDER\" | grep -c 'sdd-sync-ref')\" = 1 ]"
  assert "promote-to-main.yml has a published-sync-ref reachability step" \
    "grep -q 'Verify published .sdd-sync-ref is reachable' \"\$PROMOTE_WF\""
  assert "that gate asserts ancestry of the value, not just the commit" \
    "awk '/name: Verify published .sdd-sync-ref is reachable/,0' \"\$PROMOTE_WF\" \
       | grep -q 'merge-base --is-ancestor'"
  assert "the direct-push path tags the sync-ref commit, not the raw snapshot" \
    "awk '/name: Publish via direct push/,0' \"\$PROMOTE_WF\" \
       | grep -vE '^[[:space:]]*#' | grep -q 'git tag .* steps.sync.outputs.commit'"
fi

if [ ! -f "$TAG_WF" ]; then
  skip "release-tag.yml absent (customer project) — structural checks"
else
  assert "release-tag.yml reads the TAG TARGET's tree, not only the commit" \
    "grep -q 'cat-file blob' \"\$TAG_WF\""
  assert "release-tag.yml refuses to publish an unreachable baseline" \
    "grep -q 'RELEASE BROKEN' \"\$TAG_WF\" && grep -q 'not reachable from main' \"\$TAG_WF\""
  assert "release-tag.yml states the remap table is NOT the fix" \
    "grep -qi 'do NOT add a remap entry' \"\$TAG_WF\""
fi

if [ ! -f "$EXTRACT" ]; then
  skip "extract-proposals.sh absent — remap-table check"
else
  assert "no remap entry was added for the dev-main SHA c6092b0" \
    "! grep -q 'c6092b0' \"\$EXTRACT\""
fi

echo ""
echo "2. Behaviour — replay compose/advance in a real repository"

# ---- Build the fixture repo ------------------------------------------------
# Shape mirrors the real one: a `main` line, and a `dev-main` line carrying its
# OWN, never-advanced .sdd-sync-ref pointing at a dev-main-only commit.
REPO="$SANDBOX/repo"
BARE="$SANDBOX/origin.git"
export GIT_AUTHOR_NAME=loom-test GIT_AUTHOR_EMAIL=loom@test
export GIT_COMMITTER_NAME=loom-test GIT_COMMITTER_EMAIL=loom@test
G() { git -C "$REPO" "$@"; }

git init -q --bare "$BARE" >/dev/null 2>&1
git init -q -b main "$REPO" >/dev/null 2>&1 || { git init -q "$REPO"; git -C "$REPO" checkout -q -b main; }
echo "harness" > "$REPO/README.md"
echo "0000000000000000000000000000000000000000" > "$REPO/.sdd-sync-ref"
G add -A >/dev/null; G commit -qm "root"
G commit -q --allow-empty -m "release: v9.9.8 sanitized template"
MAIN_TIP="$(G rev-parse HEAD)"

# dev-main: diverges, and carries a stale .sdd-sync-ref naming a dev-main-only
# commit — exactly the c6092b08 shape.
G checkout -q -b dev-main
G commit -q --allow-empty -m "merge: sync dev-main with main"
DEV_ONLY="$(G rev-parse HEAD)"
printf '%s\n' "$DEV_ONLY" > "$REPO/.sdd-sync-ref"
echo "feature" > "$REPO/feature.txt"
G add -A >/dev/null; G commit -qm "feat: something"

assert "fixture: dev-main's baseline is NOT reachable from main" \
  "! G merge-base --is-ancestor \"\$DEV_ONLY\" \"\$MAIN_TIP\""

# ---- Extract the promote-to-main reachability gate --------------------------
# Extraction is awk, not PyYAML: PyYAML is NOT in the python3 stdlib and is not
# reliably importable on a CI runner, and a behavioural half that silently skips
# is a suite that protects nothing. The two `${{ steps.*.outputs.commit }}`
# expressions are the only interpolation in the body; they become shell vars.
GATE_BODY="$SANDBOX/promote-gate.sh"
if [ -f "$PROMOTE_WF" ]; then
  awk '
    /^      - name: Verify published \.sdd-sync-ref is reachable$/ { instep = 1; next }
    instep && /^        run: \|$/ { inrun = 1; next }
    inrun && /^      - name: / { exit }
    inrun { sub(/^          /, ""); print }
  ' "$PROMOTE_WF" \
    | sed -e 's/\${{[[:space:]]*steps\.compose\.outputs\.commit[[:space:]]*}}/$C1_IN/g' \
          -e 's/\${{[[:space:]]*steps\.sync\.outputs\.commit[[:space:]]*}}/$C2_IN/g' \
    > "$GATE_BODY"
fi

if [ ! -s "$GATE_BODY" ]; then
  skip "could not extract the promote-to-main gate (python3/yaml missing?)"
else
  assert "the extracted gate body parses under bash" "bash -n \"\$GATE_BODY\""
  assert "no GitHub expression survived substitution in the gate body" \
    "! grep -q '\${{' \"\$GATE_BODY\""

  # -- OLD sequence (the defect): compose the tree straight from dev-main.
  G read-tree dev-main >/dev/null
  OLD_TREE="$(G write-tree)"
  OLD_C1="$(printf 'release: v9.9.9 sanitized template\n' | G commit-tree "$OLD_TREE" -p "$MAIN_TIP")"
  G read-tree "$OLD_C1" >/dev/null
  G checkout-index -a -f 2>/dev/null || true
  printf '%s\n' "$OLD_C1" > "$REPO/.sdd-sync-ref"
  G add .sdd-sync-ref >/dev/null
  OLD_C2="$(printf 'chore: advance .sdd-sync-ref to v9.9.9\n' | G commit-tree "$(G write-tree)" -p "$OLD_C1")"

  assert "fixture: the OLD snapshot really does carry the dev-main SHA" \
    "[ \"\$(G cat-file blob \"\$OLD_C1:.sdd-sync-ref\" | tr -d '[:space:]')\" = \"\$DEV_ONLY\" ]"

  ( cd "$REPO" && C1_IN="$OLD_C1" C2_IN="$OLD_C2" bash "$GATE_BODY" ) \
    > "$SANDBOX/old.out" 2>&1
  OLD_RC=$?
  assert "the gate REJECTS the old compose sequence (nonzero exit)" "[ \"\$OLD_RC\" != 0 ]"
  assert "it names the unreachable baseline in the error" \
    "grep -q 'NOT an ancestor' \"\$SANDBOX/old.out\""
  assert "it points at the compose step as the fix, not a remap entry" \
    "grep -qi 'remap' \"\$SANDBOX/old.out\""

  # -- NEW sequence (the fix): stamp the baseline to main's tip before write-tree.
  G read-tree dev-main >/dev/null
  G checkout-index -a -f 2>/dev/null || true
  printf '%s\n' "$MAIN_TIP" > "$REPO/.sdd-sync-ref"
  G add -A >/dev/null
  NEW_C1="$(printf 'release: v9.9.9 sanitized template\n' | G commit-tree "$(G write-tree)" -p "$MAIN_TIP")"
  printf '%s\n' "$NEW_C1" > "$REPO/.sdd-sync-ref"
  G add .sdd-sync-ref >/dev/null
  NEW_C2="$(printf 'chore: advance .sdd-sync-ref to v9.9.9\n' | G commit-tree "$(G write-tree)" -p "$NEW_C1")"

  ( cd "$REPO" && C1_IN="$NEW_C1" C2_IN="$NEW_C2" bash "$GATE_BODY" ) \
    > "$SANDBOX/new.out" 2>&1
  NEW_RC=$?
  assert "the gate ACCEPTS the stamped compose sequence (exit 0)" "[ \"\$NEW_RC\" = 0 ]"
  assert "the snapshot's baseline is now an ancestor of the snapshot" \
    "G merge-base --is-ancestor \"\$MAIN_TIP\" \"\$NEW_C1\""
  assert "the sync-ref commit's baseline is the snapshot itself" \
    "[ \"\$(G cat-file blob \"\$NEW_C2:.sdd-sync-ref\" | tr -d '[:space:]')\" = \"\$NEW_C1\" ]"
  assert "single-parent preserved: the snapshot's only parent is main" \
    "[ \"\$(G log -1 --format=%P \"\$NEW_C1\")\" = \"\$MAIN_TIP\" ]"
  assert "single-parent preserved: the sync-ref commit's only parent is the snapshot" \
    "[ \"\$(G log -1 --format=%P \"\$NEW_C2\")\" = \"\$NEW_C1\" ]"
fi

echo ""
echo "3. Behaviour — run release-tag.yml's tagging step against real git"

TAG_BODY="$SANDBOX/tag-step.sh"
if [ -f "$TAG_WF" ]; then
  awk '
    /^      - name: Tag the sanitized snapshot if this push landed a release$/ { instep = 1; next }
    instep && /^        run: \|$/ { inrun = 1; next }
    inrun && /^      - name: / { exit }
    inrun { sub(/^          /, ""); print }
  ' "$TAG_WF" > "$TAG_BODY"
fi

if [ ! -s "$TAG_BODY" ]; then
  skip "could not extract the release-tag tagging step"
else
  assert "the extracted tagging body parses under bash" "bash -n \"\$TAG_BODY\""
  assert "the tagging body carries no GitHub expression to substitute" \
    "! grep -q '\${{' \"\$TAG_BODY\""

  # Build the BAD chain: the sync-ref commit cannot be validated (its subject
  # names a different version), so the step falls back to the snapshot — whose
  # tree still carries the stale dev-main baseline.
  G read-tree dev-main >/dev/null
  G checkout-index -a -f 2>/dev/null || true
  BAD_C1="$(printf 'release: v9.9.9 sanitized template\n' | G commit-tree "$(G write-tree)" -p "$MAIN_TIP")"
  printf '%s\n' "$BAD_C1" > "$REPO/.sdd-sync-ref"
  G add .sdd-sync-ref >/dev/null
  BAD_C2="$(printf 'chore: advance .sdd-sync-ref to v0.0.1\n' | G commit-tree "$(G write-tree)" -p "$BAD_C1")"

  G remote add origin "$BARE" 2>/dev/null || G remote set-url origin "$BARE"

  # -- BAD first: it must run while no v9.9.9 tag exists anywhere, or the step's
  # idempotence branch would short-circuit before reaching the gate.
  G checkout -q -f --detach "$BAD_C2"
  ( cd "$REPO" && bash "$TAG_BODY" ) > "$SANDBOX/tag-bad.out" 2>&1
  BAD_RC=$?
  assert "a stale baseline is REFUSED rather than tagged (nonzero exit)" \
    "[ \"\$BAD_RC\" != 0 ]"
  assert "no tag was created for the refused release" \
    "! G rev-parse -q --verify 'refs/tags/v9.9.9' >/dev/null 2>&1"
  # Discriminate from the PRE-EXISTING guard, which also prints "RELEASE BROKEN":
  # that one checks the snapshot COMMIT's ancestry (satisfied here). Only the new
  # TREE-reading gate can produce "the tree at ... carries .sdd-sync-ref".
  assert "the refusal came from the TREE gate, not the older commit gate" \
    "grep -q 'the tree at' \"\$SANDBOX/tag-bad.out\" \
     && grep -q \"carries .sdd-sync-ref='\$DEV_ONLY'\" \"\$SANDBOX/tag-bad.out\""
  assert "the refusal explains the adopter-visible consequence" \
    "grep -qi 'update-framework' \"\$SANDBOX/tag-bad.out\" \
     && grep -qi 'do NOT add a remap entry' \"\$SANDBOX/tag-bad.out\""

  # -- GOOD: the stamped chain. The tag must land on the sync-ref commit.
  G checkout -q -f --detach "$NEW_C2"
  ( cd "$REPO" && bash "$TAG_BODY" ) > "$SANDBOX/tag-good.out" 2>&1
  GOOD_RC=$?
  assert "a well-formed release tags cleanly (exit 0)" "[ \"\$GOOD_RC\" = 0 ]"
  assert "the tag lands on the sync-ref commit, not the raw snapshot" \
    "[ \"\$(G rev-parse -q --verify 'refs/tags/v9.9.9^{commit}')\" = \"\$NEW_C2\" ]"
  assert "the tagged tree's baseline is reachable from main" \
    "G merge-base --is-ancestor \
       \"\$(G cat-file blob 'v9.9.9:.sdd-sync-ref' | tr -d '[:space:]')\" \"\$NEW_C2\""
  assert "the tag was pushed to origin" \
    "git -C \"\$BARE\" rev-parse -q --verify 'refs/tags/v9.9.9' >/dev/null 2>&1"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  RESULTS: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
echo "═══════════════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ]
