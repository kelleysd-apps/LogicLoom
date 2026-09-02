#!/usr/bin/env bash
# Contract Tests: adopted-repo awareness in extract-proposals.sh (GitHub #84)
#
# extract-proposals.sh gained adopted-repo filtering: a checkout produced by
# `npx logicloom init` into someone else's existing repo (ADOPTED) must not be
# offered the same upstream proposals as a template clone (TEMPLATE) — most of
# them target paths the adopter never had, or a merge channel that must never
# be silently overwritten. That logic was written by a worker with no shell
# and has NEVER been executed. This suite sources the script directly (it
# guards its main block with `[ "${BASH_SOURCE[0]}" = "${0}" ]`, so sourcing
# does not run --dry-run/network I/O) and calls its functions to prove the
# behavior, or find where it breaks.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}, no &>>.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if REAL_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  REAL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
EXTRACT_SCRIPT="$REAL_ROOT/plugins/loom-maintenance/scripts/extract-proposals.sh"

echo "═══ Adopted-Repo Awareness Contract Tests (extract-proposals.sh) ═══"
echo ""

assert "extract-proposals.sh exists" "[ -f \"\$EXTRACT_SCRIPT\" ]"
if [ ! -f "$EXTRACT_SCRIPT" ]; then
  echo ""
  echo "════════════════════════════════"
  echo " Results: $PASS/$TOTAL passed, $FAIL failed"
  echo "❌ SOME TESTS FAILED"
  exit 1
fi

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/loom-adopt-test.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ─────────────────────────────────────────────────────────────────────────
# A. TEMPLATE-CLONE INERTNESS
# ─────────────────────────────────────────────────────────────────────────
echo "A. Template-clone inertness"

# A1: defaults, WITHOUT ever calling detect_adopt_mode — a caller (test or
# otherwise) that only sources the file and calls extract_proposals directly
# must still see the template posture.
(
  set -euo pipefail
  # shellcheck disable=SC1090
  source "$EXTRACT_SCRIPT"
  [ "$ADOPT_MODE" = "TEMPLATE" ] || exit 1
  [ "$ADOPT_DETECTED_BY" = "" ] || exit 1
  [ "$ADOPT_WROTE" = "" ] || exit 1
  [ "$ADOPT_RECEIPT_USABLE" = "false" ] || exit 1
  [ "$ADOPT_GENERATOR_VERSION" = "" ] || exit 1
)
A1_EXIT=$?
assert "globals default to TEMPLATE posture without ever calling detect_adopt_mode" "[ $A1_EXIT -eq 0 ]"

# A2: a repo with neither the receipt nor .logic-loom/AGENTS.md — detect_adopt_mode
# explicitly called still leaves ADOPT_MODE=TEMPLATE.
TEMPLATE_REPO="$WORKDIR/template-clone"
mkdir -p "$TEMPLATE_REPO/.logic-loom"
(
  set -euo pipefail
  # shellcheck disable=SC1090
  source "$EXTRACT_SCRIPT"
  REPO_ROOT="$TEMPLATE_REPO"
  detect_adopt_mode
  [ "$ADOPT_MODE" = "TEMPLATE" ] || exit 1
)
A2_EXIT=$?
assert "detect_adopt_mode on a repo with no receipt and no .logic-loom/AGENTS.md leaves ADOPT_MODE=TEMPLATE" "[ $A2_EXIT -eq 0 ]"

# ─────────────────────────────────────────────────────────────────────────
# B. DETECTION
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "B. Detection"

RECEIPT_REPO="$WORKDIR/receipt-repo"
mkdir -p "$RECEIPT_REPO/.logic-loom"

# B1: usable receipt -> ADOPTED, detected_by receipt, RECEIPT_USABLE=true.
cat > "$RECEIPT_REPO/.logicloom-adopt-receipt.json" <<'JSON'
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "status": "complete",
      "generator": "logicloom-adopt@1.2.3",
      "wrote": [
        {"kind": "dir", "path": "plugins/"},
        {"kind": "dir", "path": ".logic-loom/"}
      ]
    }
  ]
}
JSON
(
  set -euo pipefail
  # shellcheck disable=SC1090
  source "$EXTRACT_SCRIPT"
  REPO_ROOT="$RECEIPT_REPO"
  detect_adopt_mode
  [ "$ADOPT_MODE" = "ADOPTED" ] || exit 1
  [ "$ADOPT_DETECTED_BY" = "receipt" ] || exit 1
  [ "$ADOPT_RECEIPT_USABLE" = "true" ] || exit 1
)
B1_EXIT=$?
assert "usable receipt (schema logicloom/adopt-receipt@1) -> ADOPT_MODE=ADOPTED, detected_by=receipt, RECEIPT_USABLE=true" "[ $B1_EXIT -eq 0 ]"

# B2: receipt ABSENT, but .logic-loom/AGENTS.md present -> ADOPTED via fallback,
# RECEIPT_USABLE=false.
FALLBACK_REPO="$WORKDIR/fallback-repo"
mkdir -p "$FALLBACK_REPO/.logic-loom"
: > "$FALLBACK_REPO/.logic-loom/AGENTS.md"
(
  set -euo pipefail
  # shellcheck disable=SC1090
  source "$EXTRACT_SCRIPT"
  REPO_ROOT="$FALLBACK_REPO"
  detect_adopt_mode
  [ "$ADOPT_MODE" = "ADOPTED" ] || exit 1
  [ "$ADOPT_DETECTED_BY" = "fallback" ] || exit 1
  [ "$ADOPT_RECEIPT_USABLE" = "false" ] || exit 1
)
B2_EXIT=$?
assert "no receipt but .logic-loom/AGENTS.md present -> ADOPTED via fallback, RECEIPT_USABLE=false" "[ $B2_EXIT -eq 0 ]"

# B3: receipt with WRONG schema string must NOT be usable. Also drop in
# .logic-loom/AGENTS.md so we can see whether it correctly falls through to
# the fallback tell (still ADOPTED, but detected_by=fallback / not usable).
BADSCHEMA_REPO="$WORKDIR/badschema-repo"
mkdir -p "$BADSCHEMA_REPO/.logic-loom"
: > "$BADSCHEMA_REPO/.logic-loom/AGENTS.md"
cat > "$BADSCHEMA_REPO/.logicloom-adopt-receipt.json" <<'JSON'
{
  "schema": "logicloom/adopt-receipt@2",
  "runs": [
    {"status": "complete", "wrote": [{"kind": "dir", "path": "plugins/"}]}
  ]
}
JSON
(
  set -euo pipefail
  # shellcheck disable=SC1090
  source "$EXTRACT_SCRIPT"
  REPO_ROOT="$BADSCHEMA_REPO"
  detect_adopt_mode
  [ "$ADOPT_RECEIPT_USABLE" = "false" ] || exit 1
  [ "$ADOPT_DETECTED_BY" != "receipt" ] || exit 1
)
B3_EXIT=$?
assert "receipt with wrong schema string is not treated as usable (falls through, not detected_by=receipt)" "[ $B3_EXIT -eq 0 ]"

# B4: wrote unioned across MULTIPLE runs[] entries; complete/partial/in-progress
# all accepted; some-other-status run is ignored.
MULTIRUN_REPO="$WORKDIR/multirun-repo"
mkdir -p "$MULTIRUN_REPO/.logic-loom"
cat > "$MULTIRUN_REPO/.logicloom-adopt-receipt.json" <<'JSON'
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {"status": "complete", "wrote": [{"kind": "dir", "path": "plugins/"}]},
    {"status": "partial", "wrote": [{"kind": "dir", "path": ".logic-loom/"}]},
    {"status": "in-progress", "wrote": [{"kind": "file", "path": ".gitignore"}]},
    {"status": "aborted", "wrote": [{"kind": "dir", "path": "should-not-appear/"}]}
  ]
}
JSON
(
  set -euo pipefail
  # shellcheck disable=SC1090
  source "$EXTRACT_SCRIPT"
  REPO_ROOT="$MULTIRUN_REPO"
  detect_adopt_mode
  [ "$ADOPT_RECEIPT_USABLE" = "true" ] || exit 1
  adopt_dir_recorded "plugins/" || exit 1
  adopt_dir_recorded ".logic-loom" || exit 1
  adopt_file_recorded ".gitignore" || exit 1
  adopt_dir_recorded "should-not-appear" && exit 1
  exit 0
)
B4_EXIT=$?
assert "wrote is unioned across multiple runs[] entries; complete/partial/in-progress accepted, other status ignored" "[ $B4_EXIT -eq 0 ]"

# ─────────────────────────────────────────────────────────────────────────
# C. THE FIVE ADDED-PATH CASES (adopt_offer_added_path)
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "C. Added-path OFFER/SUPPRESS cases"

# Build a temp git repo whose commit at sync_ref contains real upstream paths,
# so the "existed upstream at sync_ref" probe (git cat-file -e sync_ref:dir)
# has something real to find.
GITREPO="$WORKDIR/added-path-repo"
mkdir -p "$GITREPO"
(
  cd "$GITREPO"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test"
  mkdir -p .logic-loom/tests .github/workflows tests/contract plugins/loom-existing
  : > .logic-loom/tests/placeholder.sh
  : > .github/workflows/placeholder.yml
  : > tests/contract/placeholder.sh
  : > plugins/loom-existing/placeholder.md
  : > TEMPLATE_INIT.md
  git add -A
  git commit -q -m "sync-ref baseline"
)
SYNC_REF_SHA="$(git -C "$GITREPO" rev-parse HEAD)"

# Fixture: usable receipt recording plugins/ and .logic-loom/ as kind:'dir',
# deliberately NOT recording .logic-loom/tests, .github, .github/workflows, or
# tests/contract.
CASES_REPO="$WORKDIR/cases-repo"
mkdir -p "$CASES_REPO/.logic-loom"
cat > "$CASES_REPO/.logicloom-adopt-receipt.json" <<'JSON'
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "status": "complete",
      "wrote": [
        {"kind": "dir", "path": "plugins/"},
        {"kind": "dir", "path": ".logic-loom/"}
      ]
    }
  ]
}
JSON

run_offer_case() {
  local path="$1"
  (
    set -euo pipefail
    # shellcheck disable=SC1090
    source "$EXTRACT_SCRIPT"
    REPO_ROOT="$CASES_REPO"
    detect_adopt_mode
    adopt_offer_added_path "$path" "$SYNC_REF_SHA"
  )
}

# NOTE: adopt_offer_added_path shells out to `git -C "$REPO_ROOT" cat-file -e
# "${sync_ref}:${dir}"`, so REPO_ROOT for this probe must be a git repo that
# actually has $SYNC_REF_SHA. We set REPO_ROOT=$GITREPO for the git probe but
# still need the receipt read from CASES_REPO. Since detect_adopt_mode reads
# from $REPO_ROOT/.logicloom-adopt-receipt.json, point REPO_ROOT at a repo that
# is BOTH a git checkout containing the sync-ref commit AND holds the receipt.
cp "$CASES_REPO/.logicloom-adopt-receipt.json" "$GITREPO/.logicloom-adopt-receipt.json"
COMBINED_REPO="$GITREPO"

run_offer_case2() {
  local path="$1"
  (
    set -euo pipefail
    # shellcheck disable=SC1090
    source "$EXTRACT_SCRIPT"
    REPO_ROOT="$COMBINED_REPO"
    detect_adopt_mode
    adopt_offer_added_path "$path" "$SYNC_REF_SHA"
  )
}

run_offer_case2 "plugins/loom-new/x.md"
assert "plugins/loom-new/x.md (ancestor plugins/ recorded) -> OFFER" "[ $? -eq 0 ]"

run_offer_case2 ".logic-loom/tests/x.sh"
assert ".logic-loom/tests/x.sh (existed upstream, .logic-loom/tests NOT recorded) -> SUPPRESS" "[ $? -eq 1 ]"

run_offer_case2 ".github/workflows/release-tag.yml"
assert ".github/workflows/release-tag.yml (existed upstream, no ancestor recorded) -> SUPPRESS" "[ $? -eq 1 ]"

run_offer_case2 "TEMPLATE_INIT.md"
assert "TEMPLATE_INIT.md (root file, no ancestors) -> SUPPRESS" "[ $? -eq 1 ]"

run_offer_case2 "tests/contract/test_release_publication.sh"
assert "tests/contract/test_release_publication.sh (existed upstream, tests/contract NOT recorded) -> SUPPRESS" "[ $? -eq 1 ]"

# Slash-insensitivity: receipt dir entries carry a trailing slash
# (".logic-loom/") while diff paths do not. Directly assert adopt_dir_recorded
# matches both forms so the comparison is provably slash-insensitive.
(
  set -euo pipefail
  # shellcheck disable=SC1090
  source "$EXTRACT_SCRIPT"
  REPO_ROOT="$COMBINED_REPO"
  detect_adopt_mode
  adopt_dir_recorded ".logic-loom" || exit 1
  adopt_dir_recorded ".logic-loom/" || exit 1
  adopt_dir_recorded "plugins" || exit 1
  adopt_dir_recorded "plugins/" || exit 1
)
SLASH_EXIT=$?
assert "adopt_dir_recorded matches recorded dir with and without trailing slash (slash-insensitive)" "[ $SLASH_EXIT -eq 0 ]"

# ─────────────────────────────────────────────────────────────────────────
# D. MERGE SUPPRESSION
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "D. Merge suppression (adopt_merge_recorded)"

MERGE_REPO="$WORKDIR/merge-repo"
mkdir -p "$MERGE_REPO/.logic-loom"
cat > "$MERGE_REPO/.logicloom-adopt-receipt.json" <<'JSON'
{
  "schema": "logicloom/adopt-receipt@1",
  "runs": [
    {
      "status": "complete",
      "wrote": [
        {"kind": "merge", "path": ".gitignore"},
        {"kind": "merge", "path": ".claude/settings.json"}
      ]
    }
  ]
}
JSON
(
  set -euo pipefail
  # shellcheck disable=SC1090
  source "$EXTRACT_SCRIPT"
  REPO_ROOT="$MERGE_REPO"
  detect_adopt_mode
  [ "$ADOPT_RECEIPT_USABLE" = "true" ] || exit 1
  adopt_merge_recorded ".gitignore" || exit 1
  adopt_merge_recorded ".claude/settings.json" || exit 1
)
D1_EXIT=$?
assert "with a usable receipt, a kind:'merge' path (.gitignore, .claude/settings.json) is recognized by adopt_merge_recorded" "[ $D1_EXIT -eq 0 ]"

# D2: with NO usable receipt (template clone), the hardcoded fallback still
# covers .gitignore and .claude/settings.json.
(
  set -euo pipefail
  # shellcheck disable=SC1090
  source "$EXTRACT_SCRIPT"
  REPO_ROOT="$TEMPLATE_REPO"
  detect_adopt_mode
  [ "$ADOPT_RECEIPT_USABLE" = "false" ] || exit 1
  adopt_merge_recorded ".gitignore" || exit 1
  adopt_merge_recorded ".claude/settings.json" || exit 1
)
D2_EXIT=$?
assert "with no usable receipt, hardcoded fallback still covers .gitignore and .claude/settings.json" "[ $D2_EXIT -eq 0 ]"

# D3: CLAUDE.md is NOT guessed as a merge target without receipt data.
(
  set -euo pipefail
  # shellcheck disable=SC1090
  source "$EXTRACT_SCRIPT"
  REPO_ROOT="$TEMPLATE_REPO"
  detect_adopt_mode
  [ "$ADOPT_RECEIPT_USABLE" = "false" ] || exit 1
  adopt_merge_recorded "CLAUDE.md" && exit 1
  exit 0
)
D3_EXIT=$?
assert "CLAUDE.md is NOT guessed as a merge target without receipt data (fallback covers only .gitignore/.claude/settings.json)" "[ $D3_EXIT -eq 0 ]"

# D4: also confirm CLAUDE.md is not a merge target even WITH a usable receipt
# that simply never recorded it (i.e. only recorded merge targets count).
(
  set -euo pipefail
  # shellcheck disable=SC1090
  source "$EXTRACT_SCRIPT"
  REPO_ROOT="$MERGE_REPO"
  detect_adopt_mode
  [ "$ADOPT_RECEIPT_USABLE" = "true" ] || exit 1
  adopt_merge_recorded "CLAUDE.md" && exit 1
  exit 0
)
D4_EXIT=$?
assert "CLAUDE.md is not a merge target with a usable receipt that never recorded it" "[ $D4_EXIT -eq 0 ]"

# ─────────────────────────────────────────────────────────────────────────
# E. FALLBACK-ONLY (RECEIPT_USABLE=false) DENY-LIST BEHAVIOR
# ─────────────────────────────────────────────────────────────────────────
# Regression coverage for the defect where, under fallback-only detection
# (ADOPT_RECEIPT_USABLE=false), ADOPT_WROTE is empty and the M/D/R ownership
# rule required a path to appear in `wrote` as kind:'file' -- with nothing in
# `wrote`, EVERY proposal was suppressed, silently. extract-proposals.sh must
# instead fall back to a conservative DENY-LIST that suppresses only known-
# dangerous / known-not-ours paths and OFFERS everything else.
echo ""
echo "E. Fallback-only (RECEIPT_USABLE=false) deny-list behavior"

E_REPO="$WORKDIR/fallback-denylist-repo"
mkdir -p "$E_REPO/.logic-loom/scripts/bash" "$E_REPO/plugins/loom-git/commands" \
         "$E_REPO/.github/workflows" "$E_REPO/tests/contract" "$E_REPO/plugins/x"
(
  cd "$E_REPO"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "old" > .logic-loom/AGENTS.md
  echo "old" > .logic-loom/scripts/bash/new-thing.sh
  echo "old" > plugins/loom-git/commands/x.md
  echo "old" > CLAUDE.md
  echo "old" > package.json
  echo "old" > .github/workflows/release-tag.yml
  echo "old" > tests/contract/x.sh
  echo "old" > TEMPLATE_INIT.md
  echo "old" > plugins/x/README.md
  git add -A
  git commit -q -m "sync-ref baseline"
)
E_SYNC_REF="$(git -C "$E_REPO" rev-parse HEAD)"
(
  cd "$E_REPO"
  echo "new" > .logic-loom/scripts/bash/new-thing.sh
  echo "new" > plugins/loom-git/commands/x.md
  echo "new" > CLAUDE.md
  echo "new" > package.json
  echo "new" > .github/workflows/release-tag.yml
  echo "new" > tests/contract/x.sh
  echo "new" > TEMPLATE_INIT.md
  echo "new" > plugins/x/README.md
  echo "new" > .logic-loom/AGENTS.md
  git add -A
  git commit -q -m "upstream changes"
)
E_UPSTREAM="$(git -C "$E_REPO" rev-parse HEAD)"
# No .logicloom-adopt-receipt.json anywhere -> fallback-only detection via
# .logic-loom/AGENTS.md (already present from the baseline commit above).

run_e_extract() {
  (
    set -euo pipefail
    # shellcheck disable=SC1090
    source "$EXTRACT_SCRIPT"
    REPO_ROOT="$E_REPO"
    extract_proposals "$E_SYNC_REF" "$E_UPSTREAM"
  )
}

E_STDOUT="$WORKDIR/e-stdout.json"
E_STDERR="$WORKDIR/e-stderr.txt"
run_e_extract >"$E_STDOUT" 2>"$E_STDERR"
E_EXIT=$?
assert "extract_proposals under fallback-only detection exits 0" "[ $E_EXIT -eq 0 ]"

assert "fallback-only detection OFFERS a legitimate harness file (.logic-loom/scripts/bash/new-thing.sh)" \
  "grep -qF '\"upstream_file\": \".logic-loom/scripts/bash/new-thing.sh\"' '$E_STDOUT'"
assert "fallback-only detection OFFERS a legitimate harness file (plugins/loom-git/commands/x.md)" \
  "grep -qF '\"upstream_file\": \"plugins/loom-git/commands/x.md\"' '$E_STDOUT'"

assert "fallback-only detection SUPPRESSES root CLAUDE.md" \
  "! grep -qF '\"upstream_file\": \"CLAUDE.md\"' '$E_STDOUT'"
assert "fallback-only detection SUPPRESSES root package.json" \
  "! grep -qF '\"upstream_file\": \"package.json\"' '$E_STDOUT'"
assert "fallback-only detection SUPPRESSES .github/workflows/release-tag.yml" \
  "! grep -qF '\"upstream_file\": \".github/workflows/release-tag.yml\"' '$E_STDOUT'"
assert "fallback-only detection SUPPRESSES tests/contract/x.sh" \
  "! grep -qF '\"upstream_file\": \"tests/contract/x.sh\"' '$E_STDOUT'"
assert "fallback-only detection SUPPRESSES TEMPLATE_INIT.md" \
  "! grep -qF '\"upstream_file\": \"TEMPLATE_INIT.md\"' '$E_STDOUT'"

assert "plugins/x/README.md is OFFERED (root-file rule anchored at root, not substring)" \
  "grep -qF '\"upstream_file\": \"plugins/x/README.md\"' '$E_STDOUT'"
assert ".logic-loom/AGENTS.md is OFFERED (root-file rule anchored at root, not substring)" \
  "grep -qF '\"upstream_file\": \".logic-loom/AGENTS.md\"' '$E_STDOUT'"

assert "degraded-filtering notice reaches stderr" \
  "grep -qF 'DEGRADED FILTERING' '$E_STDERR'"

# E-regression: adopt_denylist_suppressed itself -- direct unit coverage of
# the deny-list predicate used above, independent of the git fixture.
(
  set -euo pipefail
  # shellcheck disable=SC1090
  source "$EXTRACT_SCRIPT"
  adopt_denylist_suppressed "CLAUDE.md" || exit 1
  adopt_denylist_suppressed "AGENTS.md" || exit 1
  adopt_denylist_suppressed "README.md" || exit 1
  adopt_denylist_suppressed "package.json" || exit 1
  adopt_denylist_suppressed ".github/workflows/x.yml" || exit 1
  adopt_denylist_suppressed "tests/contract/x.sh" || exit 1
  adopt_denylist_suppressed "TEMPLATE_INIT.md" || exit 1
  adopt_denylist_suppressed ".logic-loom/AGENTS.md" && exit 1
  adopt_denylist_suppressed "plugins/x/README.md" && exit 1
  adopt_denylist_suppressed ".logic-loom/scripts/bash/new-thing.sh" && exit 1
  exit 0
)
E_UNIT_EXIT=$?
assert "adopt_denylist_suppressed: root files + .github/ + tests/ + TEMPLATE_INIT.md suppressed, non-root lookalikes are not" "[ $E_UNIT_EXIT -eq 0 ]"

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
