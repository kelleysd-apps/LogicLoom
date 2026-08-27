#!/usr/bin/env bash
# Contract Tests: init-project.sh never destroys a README it did not write
#
# WHY THIS SUITE EXISTS (and why only this one of the three PRE-5 defects got a test)
#
# `init-project.sh` is live onboarding — it is the first command in README.md,
# START_HERE.md and TEMPLATE_INIT.md, so a new adopter runs it before anything
# else. It archives the shipped framework README to FRAMEWORK_README.md and then
# writes a generated project README.
#
# The archive step was guarded (`[ ! -f FRAMEWORK_README.md ]`); the write step
# was NOT. So a SECOND run — an adopter re-running setup after changing their
# project name, which the script's own prompts invite — silently replaced a
# README the user had since hand-written with the generated boilerplate. Data
# loss, no prompt, no backup, exit 0.
#
# This is worth pinning rather than merely fixing because the conditional that
# fixes it wraps a ~90-line heredoc containing the README body. That body is
# ordinary content that gets edited (branding, command list, directory tree), and
# an editor rewriting the heredoc is exactly the person most likely to drop the
# `if`/`fi` around it and reintroduce the bug. The test fails the moment they do.
#
# Deliberately NOT tested (see the PRE-5 report):
#   * update-agent-context.sh — DELETED, not repaired. A test asserting a deleted
#     file stays deleted is a tombstone: it pins a decision no code can violate.
#   * the bump-version.sh stamp-site COUNT — the count was removed from prose
#     rather than restated, so there is no claim left to verify. A test asserting
#     "12 sites" would fail on every legitimate new stamp site: cost, no value.
#
# METHOD: the README region of init-project.sh is extracted between two stable
# anchors and run in a sandbox with the two variables it consumes stubbed. The
# region is executed, not read — a read-only assertion about source text would
# not have caught the original bug, which was structural. The anchors themselves
# are asserted first, so if someone moves them this suite FAILS loudly instead of
# silently testing an empty string.
#
# bash 3.2 safe: no associative arrays, no mapfile, no [[ -v ]], no ${var,,}.
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

TARGET="$ROOT/init-project.sh"

SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t loominit)"
cleanup() { [ -n "${SANDBOX:-}" ] && rm -rf "$SANDBOX"; }
trap cleanup EXIT

echo "=== init-project.sh README idempotency ==="
echo ""

echo "--- Preconditions ---"
assert "init-project.sh exists" "[ -f '$TARGET' ]"
assert "init-project.sh parses" "bash -n '$TARGET' 2>/dev/null"

START_ANCHOR='^# Archive framework README'
END_ANCHOR='^# Initialize git if not already'
assert "start anchor present (README region)" \
  "grep -qE '$START_ANCHOR' '$TARGET'"
assert "end anchor present (README region)" \
  "grep -qE '$END_ANCHOR' '$TARGET'"

BLOCK="$SANDBOX/readme-block.sh"
{
  echo 'BLUE=; GREEN=; YELLOW=; RED=; NC='
  echo 'PROJECT_NAME="AdopterApp"'
  echo 'PROJECT_DESCRIPTION="An adopter project."'
  sed -n "/$START_ANCHOR/,/$END_ANCHOR/p" "$TARGET" | sed '$d'
} > "$BLOCK"

assert "extracted region is non-trivial" "[ \"\$(wc -l < '$BLOCK')\" -gt 20 ]"
assert "extracted region parses standalone" "bash -n '$BLOCK' 2>/dev/null"
assert "extracted region contains the generated-README write" \
  "grep -q 'cat > README.md' '$BLOCK'"

run_block() { ( cd "$1" && bash "$BLOCK" >/dev/null 2>&1 ); }

# ---------------------------------------------------------------------------
# Case 1 — first run on a fresh clone: archive the framework README, generate ours
# ---------------------------------------------------------------------------
echo ""
echo "--- Case 1: first run archives and generates ---"
C1="$SANDBOX/case1"; mkdir -p "$C1"
printf '# LogicLoom\n\nFramework docs.\n' > "$C1/README.md"
run_block "$C1"

assert "C1: FRAMEWORK_README.md created" "[ -f '$C1/FRAMEWORK_README.md' ]"
assert "C1: framework README content preserved in the archive" \
  "grep -q 'Framework docs.' '$C1/FRAMEWORK_README.md'"
assert "C1: README.md replaced with the generated project README" \
  "grep -q 'AdopterApp' '$C1/README.md'"

# ---------------------------------------------------------------------------
# Case 2 — THE DEFECT. Re-run after the user wrote their own README.
# ---------------------------------------------------------------------------
echo ""
echo "--- Case 2: re-run must not destroy the user's README ---"
USER_README='# AdopterApp

Hand-written by the adopter. Do not clobber.
'
printf '%s' "$USER_README" > "$C1/README.md"
BEFORE_SUM="$(shasum "$C1/README.md" | awk '{print $1}')"
run_block "$C1"
AFTER_SUM="$(shasum "$C1/README.md" | awk '{print $1}')"

assert "C2: user's README.md is byte-identical after a second run" \
  "[ '$BEFORE_SUM' = '$AFTER_SUM' ]"
assert "C2: user's README.md still carries their words" \
  "grep -q 'Do not clobber' '$C1/README.md'"
assert "C2: the generated boilerplate did NOT overwrite it" \
  "! grep -q 'Built with \[LogicLoom\]' '$C1/README.md'"
assert "C2: the archived FRAMEWORK_README.md was not re-archived over" \
  "grep -q 'Framework docs.' '$C1/FRAMEWORK_README.md'"

# A third run must be equally inert — idempotency is not a one-shot property.
run_block "$C1"
THIRD_SUM="$(shasum "$C1/README.md" | awk '{print $1}')"
assert "C2: a third run is also inert" "[ '$BEFORE_SUM' = '$THIRD_SUM' ]"

# ---------------------------------------------------------------------------
# Case 3 — no README at all: still generate one, and invent no archive
# ---------------------------------------------------------------------------
echo ""
echo "--- Case 3: no README present ---"
C3="$SANDBOX/case3"; mkdir -p "$C3"
run_block "$C3"

assert "C3: project README generated when none existed" \
  "grep -q 'AdopterApp' '$C3/README.md' 2>/dev/null"
assert "C3: no phantom FRAMEWORK_README.md created" \
  "[ ! -f '$C3/FRAMEWORK_README.md' ]"

echo ""
echo "======================================"
echo "Total:  $TOTAL"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "======================================"
[ "$FAIL" -eq 0 ]
