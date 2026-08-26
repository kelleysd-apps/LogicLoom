#!/usr/bin/env bash
# Contract Tests: the release path PUBLISHES a GitHub Release, not just a tag
#
# THE GAP THIS PINS: between v6.2.0 and v6.5.0, .github/workflows/release-tag.yml
# pushed five tags (6.3.0, 6.3.1, 6.4.0, 6.4.1, 6.5.0) and created zero GitHub
# Releases. Nothing failed — the step did not exist. The Releases page showed
# v6.2.0 as "Latest" through five releases, and no command asserted otherwise.
#
# WHAT THIS SUITE COVERS
#   1. STRUCTURE — release-tag.yml has a Release step, it creates a DRAFT, it
#      verifies the tag rather than inventing one, and it never falls back to
#      --generate-notes (on a single-parent sanitized line that renders one
#      content-free commit and looks like a record).
#   2. BEHAVIOUR — the step's `run:` body is EXTRACTED from the YAML and
#      EXECUTED against shimmed `git` and `gh`, over the repo's real
#      CHANGELOG.md. Five scenarios: happy path, already-exists (idempotence),
#      missing section, missing provenance trailer, no release on this push.
#   3. HAND-OFF — /promote's procedure verifies the Release exists and FAILS the
#      hand-off when it does not; /promote-prod documents the same step.
#
# STRIP-AWARE (tests/lib/tree-provenance.sh). This suite SHIPS, so it runs in a
# customer's CI on a sanitized tree where CHANGELOG.md and
# plugins/loom-maintenance/commands/promote.md are REMOVED and
# .logic-loom/memory/backlog.md is STUBBED to a template. The behavioural
# scenarios therefore run against a SYNTHETIC changelog fixture on every tree;
# only the assertions that can only hold on the dev line — the real v6.5.0
# notes, /promote's procedure, LOOM-0035 — are guarded and skipped there.
#
# WHAT IT DOES NOT COVER — say this plainly rather than implying more:
#   * No GitHub API is called. `gh` is a shim that records its argv. That the
#     real `gh release create --draft --verify-tag` succeeds with the job's
#     `contents: write` token is UNVERIFIED here and is first proven by the
#     v6.6.0 release run.
#   * Step wiring is not executed: the suite runs ONE step's body in isolation,
#     so it cannot prove the tagging step really exports REL_TAG/REL_SNAP into
#     the next step's environment via $GITHUB_ENV (that is asserted textually).
#   * `push:` workflows run the copy of the file at the pushed commit, so this
#     step cannot run for v6.5.0 (already released) and first runs for v6.6.0.
#     No test can change that.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
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
cd "$ROOT"

WF="$ROOT/.github/workflows/release-tag.yml"
PROMOTE="$ROOT/plugins/loom-maintenance/commands/promote.md"
PROMOTE_PROD="$ROOT/plugins/loom-maintenance/commands/promote-prod.md"
CHANGELOG="$ROOT/CHANGELOG.md"

# shellcheck source=tests/lib/tree-provenance.sh
. "$ROOT/tests/lib/tree-provenance.sh"
TREE_KIND="$(loom_tree_kind "$ROOT")"
[ "$TREE_KIND" = "inconsistent" ] && { loom_require_consistent_tree "$ROOT"; exit 1; }
skip() { echo "  ⏭  SKIP: $1 — sanitized tree (maintainer-only file)"; }

SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t loomrel)"
cleanup() { [ -n "${SANDBOX:-}" ] && rm -rf "$SANDBOX"; }
trap cleanup EXIT

echo "════════════════════════════════════════════"
echo " Release publication contract"
echo "════════════════════════════════════════════"

echo ""
echo "1. The workflow has a Release step, and it is a draft"

assert "release-tag.yml exists" "[ -f \"\$WF\" ]"
assert "a step creates a GitHub Release" "grep -q 'gh release create' \"\$WF\""
assert "the Release is created as a DRAFT (not published by CI)" \
  "grep -q -- '--draft' \"\$WF\""
assert "it verifies the tag rather than inventing one (--verify-tag)" \
  "grep -q -- '--verify-tag' \"\$WF\""
assert "notes come from a file, not an inline string" \
  "grep -q -- '--notes-file' \"\$WF\""
# Comment lines are excluded: the workflow explains in prose WHY it rejects both
# of these, and prose must not be mistaken for the behaviour it argues against.
WF_CODE="$SANDBOX/release-tag.code"
grep -vE '^[[:space:]]*#' "$WF" > "$WF_CODE"
assert "no --generate-notes fallback (one content-free commit is not a record)" \
  "! grep -q -- '--generate-notes' \"\$WF_CODE\""
assert "idempotence is checked BEFORE creating (gh release view)" \
  "grep -q 'gh release view' \"\$WF\""
assert "an existing Release is never overwritten (no gh release edit)" \
  "! grep -q 'gh release edit' \"\$WF_CODE\""
assert "notes are sourced via the Source-dev-main provenance trailer" \
  "grep -q 'Source-dev-main' \"\$WF\""
assert "the tagging step hands identity to the next step via GITHUB_ENV" \
  "grep -q 'REL_TAG=\$VER' \"\$WF\" && grep -q 'GITHUB_ENV' \"\$WF\""
assert "the file states that CHANGELOG.md is stripped from this tree" \
  "grep -qi 'strip' \"\$WF\" && grep -q 'CHANGELOG.md' \"\$WF\""
assert "the file states the change takes effect one release later" \
  "grep -qi 'v6.6.0' \"\$WF\""

echo ""
echo "2. Extract the step body and run it against shims (no API calls)"

BODY="$SANDBOX/step-body.sh"
awk '
  /^      - name: Create a draft GitHub Release from the CHANGELOG section$/ { instep = 1; next }
  instep && /^        run: \|$/ { inrun = 1; next }
  inrun && /^      - name: / { exit }
  inrun { sub(/^          /, ""); print }
' "$WF" > "$BODY"

assert "the step body extracted from the YAML is non-trivial" \
  "[ \"\$(wc -l < \"\$BODY\" | tr -d ' ')\" -gt 30 ]"
assert "the extracted body parses under bash" "bash -n \"\$BODY\""

# ---- Shims -----------------------------------------------------------------
# `git` answers only the four read-only forms the body uses, from fixture files.
# `gh` records its argv and reports existence from a flag file. Neither touches
# a network, a repository, or the real binaries.
BIN="$SANDBOX/bin"
mkdir -p "$BIN"

cat > "$BIN/git" <<'GITSHIM'
#!/usr/bin/env bash
case "$1" in
  log)
    # `git log -1 --format=%B <sha>` — the snapshot commit message.
    cat "$LOOM_FIX/commit-body.txt" 2>/dev/null; exit 0 ;;
  cat-file)
    # `git cat-file -e <sha>^{commit}` — object presence.
    [ -f "$LOOM_FIX/dev-object-present" ] && exit 0; exit 1 ;;
  fetch)
    exit 0 ;;
  show)
    # `git show <dev>:CHANGELOG.md`
    cat "$LOOM_FIX/CHANGELOG.md" 2>/dev/null; exit 0 ;;
esac
echo "git shim: unexpected form: $*" >&2
exit 127
GITSHIM

cat > "$BIN/gh" <<'GHSHIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$LOOM_FIX/gh-calls.log"
if [ "$1" = "release" ] && [ "$2" = "view" ]; then
  [ -f "$LOOM_FIX/release-exists" ] && exit 0
  exit 1
fi
if [ "$1" = "release" ] && [ "$2" = "create" ]; then
  # Preserve the notes file the body wrote, for content assertions.
  while [ $# -gt 0 ]; do
    if [ "$1" = "--notes-file" ]; then cp "$2" "$LOOM_FIX/notes-passed.md"; fi
    shift
  done
  : > "$LOOM_FIX/created"
  exit 0
fi
exit 0
GHSHIM
chmod +x "$BIN/git" "$BIN/gh"

# A SYNTHETIC changelog, so the behavioural scenarios are identical on a
# maintainer tree and on a customer's sanitized tree (where CHANGELOG.md is
# stripped). Shaped exactly like the real one: Keep-a-Changelog headings, a
# blank line straight after the heading, and a trailing blank line before the
# next section — both of which the extraction must trim.
SYNTH="$SANDBOX/synthetic-changelog.md"
printf '%s\n' \
  '# Changelog' \
  '' \
  '## [6.5.0] - 2026-08-25' \
  '' \
  'Covers the line since v6.4.1.' \
  '' \
  '### Added' \
  '' \
  '- a thing that shipped' \
  '' \
  '' \
  '## [6.4.1] - 2026-08-13' \
  '' \
  '- PREVIOUS SECTION MUST NOT LEAK' > "$SYNTH"

# Fresh fixture dir per scenario. $2 (optional) overrides the changelog source.
new_fixture() {
  FIX="$SANDBOX/fix-$1"
  rm -rf "$FIX"; mkdir -p "$FIX"
  cp "${2:-$SYNTH}" "$FIX/CHANGELOG.md"
  printf '%s\n\n%s\n' \
    "release: v6.5.0 sanitized template" \
    "Source-dev-main: 66b2e1bd285dc4705e11a728e2b1ed59e2451e0b" > "$FIX/commit-body.txt"
  : > "$FIX/dev-object-present"
}

run_body() {
  ( PATH="$BIN:$PATH" LOOM_FIX="$FIX" RUNNER_TEMP="$FIX" \
    REL_TAG="${1-v6.5.0}" REL_SNAP="${2-deadbeefdeadbeefdeadbeefdeadbeefdeadbeef}" \
    bash "$BODY" ) > "$FIX/stdout.txt" 2> "$FIX/stderr.txt"
  echo $?
}

echo ""
echo "2a. Happy path — a draft Release is created from the matching section"
new_fixture happy
RC="$(run_body)"
assert "exits 0" "[ \"\$RC\" = 0 ]"
assert "a Release was created" "[ -f \"\$FIX/created\" ]"
assert "created as a draft" "grep -q -- '--draft' \"\$FIX/gh-calls.log\""
assert "created with --verify-tag" "grep -q -- '--verify-tag' \"\$FIX/gh-calls.log\""
assert "created for tag v6.5.0" "grep -q 'release create v6.5.0' \"\$FIX/gh-calls.log\""
assert "notes were handed over as a file" "[ -f \"\$FIX/notes-passed.md\" ]"
# The notes must be the 6.5.0 SECTION: its own content, and nothing from 6.4.x.
assert "notes carry the 6.5.0 section's opening line" \
  "grep -q 'Covers the line since v6.4.1' \"\$FIX/notes-passed.md\""
assert "notes include the section's subsection heading" \
  "grep -q '^### Added' \"\$FIX/notes-passed.md\""
assert "notes do NOT leak the previous section's body" \
  "! grep -q 'MUST NOT LEAK' \"\$FIX/notes-passed.md\""
assert "notes do NOT include the '## [6.5.0]' heading itself" \
  "! grep -q '^## \\[6.5.0\\]' \"\$FIX/notes-passed.md\""
assert "notes STOP before the previous release section" \
  "! grep -q '^## \\[6.4' \"\$FIX/notes-passed.md\""
assert "notes do not start with a blank line" \
  "[ -n \"\$(head -1 \"\$FIX/notes-passed.md\" | tr -d '[:space:]')\" ]"
assert "notes do not end with a blank line" \
  "[ -n \"\$(tail -1 \"\$FIX/notes-passed.md\" | tr -d '[:space:]')\" ]"
assert "the run says the Release is NOT published" \
  "grep -qi 'not published' \"\$FIX/stdout.txt\""

echo ""
echo "2b. Idempotence — an existing Release is left untouched"
new_fixture exists
: > "$FIX/release-exists"
RC="$(run_body)"
assert "exits 0 (a re-run must not fail)" "[ \"\$RC\" = 0 ]"
assert "no Release was created" "[ ! -f \"\$FIX/created\" ]"
assert "no create call was made at all" \
  "! grep -q 'release create' \"\$FIX/gh-calls.log\""
assert "it says the Release was left as-is" \
  "grep -qi 'already exists' \"\$FIX/stdout.txt\""

echo ""
echo "2c. No matching CHANGELOG section — fail loudly, never an empty Release"
new_fixture nosection
printf '%s\n' '# Changelog' '' '## [6.4.1] - 2026-08-13' '' '- something' > "$FIX/CHANGELOG.md"
RC="$(run_body)"
assert "exits non-zero" "[ \"\$RC\" != 0 ]"
assert "no Release was created" "[ ! -f \"\$FIX/created\" ]"
assert "it emits a workflow error naming the missing section" \
  "grep -q '::error::' \"\$FIX/stdout.txt\" && grep -q '6.5.0' \"\$FIX/stdout.txt\""

echo ""
echo "2d. No provenance trailer — the notes source is unknown, so refuse"
new_fixture notrailer
printf '%s\n' 'release: v6.5.0 sanitized template' > "$FIX/commit-body.txt"
RC="$(run_body)"
assert "exits non-zero" "[ \"\$RC\" != 0 ]"
assert "no Release was created" "[ ! -f \"\$FIX/created\" ]"
assert "the error names the missing trailer" \
  "grep -q 'Source-dev-main' \"\$FIX/stdout.txt\""

echo ""
echo "2e. This push landed no release — a clean no-op"
new_fixture norelease
RC="$(run_body '' '')"
assert "exits 0" "[ \"\$RC\" = 0 ]"
assert "no Release was created" "[ ! -f \"\$FIX/created\" ]"
assert "no gh call was made" "[ ! -s \"\$FIX/gh-calls.log\" ]"

echo ""
echo "2f. The REAL CHANGELOG.md — the exact v6.5.0 notes (dev line only)"
if [ "$TREE_KIND" = "sanitized" ] || [ ! -f "$CHANGELOG" ]; then
  skip "real-CHANGELOG extraction (CHANGELOG.md is removed by the strip)"
else
  new_fixture real "$CHANGELOG"
  RC="$(run_body)"
  assert "exits 0 on the repo's own CHANGELOG" "[ \"\$RC\" = 0 ]"
  assert "a draft Release was created" "[ -f \"\$FIX/created\" ]"
  assert "notes open with the real 6.5.0 summary paragraph" \
    "grep -q 'Covers the .dev-main. line since v6.4.1' \"\$FIX/notes-passed.md\""
  assert "notes stop before the previous release section" \
    "! grep -q '^## \\[6.4' \"\$FIX/notes-passed.md\""
  assert "notes are substantial (a real section, not a stub)" \
    "[ \"\$(wc -l < \"\$FIX/notes-passed.md\" | tr -d ' ')\" -gt 50 ]"
  assert "notes fit GitHub's 125000-character release-body limit" \
    "[ \"\$(wc -c < \"\$FIX/notes-passed.md\" | tr -d ' ')\" -lt 125000 ]"
fi

echo ""
echo "3. The hand-off asserts the Release actually happened"

if [ "$TREE_KIND" = "sanitized" ]; then
  skip "/promote procedure (promote.md is removed by the strip)"
else
assert "/promote exists" "[ -f \"\$PROMOTE\" ]"
assert "/promote verifies the Release with gh release view" \
  "grep -q 'gh release view' \"\$PROMOTE\""
assert "/promote reports the Release URL and tag" \
  "grep -q 'gh release view' \"\$PROMOTE\" && grep -q 'tagName' \"\$PROMOTE\""
assert "/promote reports the draft state" \
  "grep -q 'isDraft' \"\$PROMOTE\""
assert "/promote treats a missing Release as a hand-off FAILURE" \
  "grep -q 'FAILURE STATE' \"\$PROMOTE\" && grep -qi 'a tag is not a release' \"\$PROMOTE\""
assert "/promote states the one-release lag explicitly" \
  "grep -qi 'one-release lag' \"\$PROMOTE\" && grep -q 'v6.6.0' \"\$PROMOTE\""
assert "/promote says the maintainer publishes the draft (CI does not)" \
  "grep -qi 'publish' \"\$PROMOTE\""
fi

assert "/promote-prod exists" "[ -f \"\$PROMOTE_PROD\" ]"
assert "/promote-prod documents the GitHub Release step" \
  "grep -qi 'github release' \"\$PROMOTE_PROD\""
assert "/promote-prod is honest that it cannot drive this today (LOOM-0035)" \
  "grep -q 'LOOM-0035' \"\$PROMOTE_PROD\""

echo ""
echo "4. The backlog records the consolidation obligation"
BACKLOG="$ROOT/.logic-loom/memory/backlog.md"
if [ "$TREE_KIND" = "sanitized" ]; then
  skip "LOOM-0035 (backlog.md is stubbed to a template by the strip)"
else
assert "LOOM-0035 names GitHub Release publication as an obligation" \
  "awk '/LOOM-0035/{f=1} f&&/^- \\[/&&!/LOOM-0035/{exit} f' \"\$BACKLOG\" | grep -qi 'github release'"
fi

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
