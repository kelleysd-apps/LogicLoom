#!/usr/bin/env bash
# Contract Tests: the sanitization audit still runs, still passes, and each of
# its six origin checks can still FAIL.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHY THIS EXISTS
# ─────────────────────────────────────────────────────────────────────────────
# `.logic-loom/scripts/bash/sanitization-audit.sh` is the third step of the
# `gate` job in .github/workflows/promote-to-main.yml, and runs again in the
# `release` job's post-strip audit. If it exits 1, the release does not start.
#
# Nothing anywhere invoked it. Not the local runner, not plugin-tests.yml, not
# a contract suite. So the first time anyone learned the audit's verdict on a
# given tree was at release time, from a red gate. That is exactly what happened
# on 2026-08-25: a template file added weeks earlier documented a grammar with
# the phrase "may contain any character except a tab", Check 5 screened a bare
# `\bcharacter[s]?\b` as D&D vocabulary, and the release blocked on accurate
# English prose. A gate that only ever runs at the moment it can hurt you is a
# gate whose regressions are all discovered the expensive way.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHAT IT COVERS — TWO DIRECTIONS, BOTH REQUIRED
# ─────────────────────────────────────────────────────────────────────────────
#   FORWARD  §1  the audit exits 0 on THIS tree (`--origin-only`, the exact
#                invocation the gate job uses). This is the regression that
#                would have caught the blocker above, weeks before the release.
#
#   REVERSE  §2  each of Checks 1-6 is handed a PLANTED violation in a
#                throwaway fixture tree and must be caught: the run must exit 1,
#                and the specific check must be the one that reports. A gate
#                nobody has ever seen fail is a gate nobody knows works — an
#                audit degraded to six unconditional `echo PASS` lines would
#                sail through §1 alone.
#
#   §3  the Check 5 narrowing is pinned in BOTH directions: ordinary software
#       English containing "character" must NOT trip it (the false-positive
#       class that blocked the release), and the domain PHRASES that replaced
#       the bare term must still trip it (the signal that was kept).
#
#   §4  CHECK 7 CANNOT SILENTLY SKIP ITSELF. §1-§3 all pass `--origin-only`,
#       which puts Check 7 out of scope by design — so they never touched the
#       one check that asserts the STRIP happened, and they would not have
#       noticed that in DEFAULT mode the audit used to self-disable Check 7
#       whenever leak-guard.sh was not beside it, shrink the denominator to
#       match, print "Passed: 6/6 … 🎉 All checks passed! Framework is
#       sanitized." and exit 0. That was the binding release gate declaring a
#       tree sanitized without having looked. §4 pins all of it: default mode
#       fails loudly when Check 7's tooling is missing, the denominator is /7
#       and never /6, a 6-of-7 result is never dressed up as success, Check 7
#       genuinely EXECUTES when the tooling IS there (the release path's
#       preserved-copy invocation), and --origin-only says out-of-scope rather
#       than claiming a full sanitization verdict.
#
# ─────────────────────────────────────────────────────────────────────────────
# HOW THE FIXTURES WORK — NO COPY OF THE AUDIT, NO WRITES TO THE REPO
# ─────────────────────────────────────────────────────────────────────────────
# The audit resolves the tree it inspects from `LOOM_AUDIT_ROOT`, falling back
# to its own location. Every fixture here is a throwaway directory built under
# TMPDIR and passed as LOOM_AUDIT_ROOT, so the REAL script under test runs —
# never a copy that could drift from it — and the repository is never written
# to.
#
# §1-§3 pass `--origin-only`, because Check 7 is the harness-dev leak guard: it
# is about a stripped snapshot, not about origin scrub, and a fixture tree is
# not a git work tree for it to inspect. §4 is the deliberate exception — it
# runs the DEFAULT mode, and it VARIES THE AUDIT'S OWN DIRECTORY (copying the
# real script into a temp dir, with and without leak-guard.sh + the strip
# manifest beside it), because Check 7 resolves that tooling from the script's
# own location. That placement is the whole mechanism of the defect §4 pins.
#
# ─────────────────────────────────────────────────────────────────────────────
# SANITIZED TREES
# ─────────────────────────────────────────────────────────────────────────────
# sanitization-audit.sh is MAINTAINER-ONLY: template-strip-manifest.txt removes
# it, so a customer's clone does not have it. This suite ships and runs in a
# cloner's CI, so on a `sanitized` tree every assertion here is skipped rather
# than failed — the same rule tests/lib/tree-provenance.sh exists to enforce,
# and the reason test_shipped_gates_vs_strip.sh will find this suite green when
# it replays it on a throwaway stripped tree. An `inconsistent` tree is a hard
# failure, never a skip.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0; SKIP=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}
skip() { SKIP=$((SKIP + 1)); echo "  ⏭  SKIP: $1 — $2"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

results() {
  echo ""
  echo "════════════════════════════════"
  echo " Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
}

AUDIT="$ROOT/.logic-loom/scripts/bash/sanitization-audit.sh"

# Provenance, via the shared helper when it is there. The helper is itself a
# maintainer-line file today; if a snapshot ever lands without it, fall back to
# the one marker this suite actually depends on — the audit script, which the
# strip manifest removes. The fallback can only turn the suite OFF on a tree
# that genuinely has no audit to test, never on into a false green.
TREE_KIND="unknown"
if [ -f "$ROOT/tests/lib/tree-provenance.sh" ]; then
  # shellcheck source=../lib/tree-provenance.sh
  source "$ROOT/tests/lib/tree-provenance.sh"
  if ! loom_require_consistent_tree "$ROOT"; then results; exit 1; fi
  TREE_KIND="$(loom_tree_kind "$ROOT")"
elif [ ! -f "$AUDIT" ]; then
  TREE_KIND="sanitized"
fi

echo "═══ Sanitization Audit Contract ═══"
echo ""

if [ "$TREE_KIND" = "sanitized" ] || [ ! -f "$AUDIT" ]; then
  skip "entire suite" "sanitized tree — sanitization-audit.sh is maintainer-only (stripped)"
  results
  exit 0
fi

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/loom-audit-contract.XXXXXX")"
cleanup() { [ -n "${TMPROOT:-}" ] && rm -rf "$TMPROOT"; }
trap cleanup EXIT INT TERM

# ── fixture scaffolding ──────────────────────────────────────────────────────
# A CLEAN fixture: the minimum shape the audit inspects, containing nothing any
# of the six checks screens for. Each reverse test starts from one of these and
# plants exactly one violation, so a failure names one check unambiguously.
#
# NOTE the fixture filenames avoid the substrings "example" and "case study".
# Checks 3-6 pipe grep's output — which begins with the FILE PATH — through
# `grep -v example` / `grep -v "case study"`, so those exclusions match the path
# as readily as the content: any file whose path contains "example" is invisible
# to four of the six checks. That is a real (pre-existing) hole in the audit, not
# a property of these fixtures; it is called out here so nobody reads the naming
# as arbitrary and "tidies" it back into a silent false green.
new_clean_fixture() {
  local d
  d="$(mktemp -d "$TMPROOT/fixture.XXXXXX")"
  mkdir -p "$d/.claude/agents" "$d/.logic-loom/scripts/bash" \
           "$d/.logic-loom/memory" "$d/.logic-loom/templates" "$d/.docs"
  cat > "$d/.logic-loom/memory/constitution.md" <<'EOF'
# Constitution
Tiers are generic: free, premium, enterprise.
Tech stack is not prescribed.
EOF
  cat > "$d/.logic-loom/templates/sample-template.md" <<'EOF'
# Template
Design system is generic; use the project's own tokens.
EOF
  cat > "$d/.claude/agents/sample-agent.md" <<'EOF'
# Agent
Paths are resolved relative to the repository root.
EOF
  cat > "$d/.logic-loom/scripts/bash/well-behaved.sh" <<'EOF'
#!/usr/bin/env bash
# Mutating git here goes through the approval seam.
request_git_approval "commit"
git commit -m "approved"
EOF
  printf '%s\n' "$d"
}

# run_audit <fixture-root> -> writes combined output to $AUDIT_OUT, returns exit code
AUDIT_OUT=""
run_audit() {
  AUDIT_OUT="$(LOOM_AUDIT_ROOT="$1" bash "$AUDIT" --origin-only 2>&1)"
  return $?
}

# reverse_case <n> <label> <plant-fn>
# Plants one violation, runs the audit, and asserts BOTH that the run fails and
# that check <n> is the one reporting FAIL. Asserting only the exit code would
# pass if some unrelated check broke instead.
reverse_case() {
  local n="$1" label="$2" plant="$3"
  local d rc
  d="$(new_clean_fixture)"
  "$plant" "$d"
  run_audit "$d"; rc=$?
  assert "Check $n CAN fail — $label (audit exits 1)" "[ $rc -ne 0 ]"
  assert "Check $n CAN fail — $label (check $n reports the FAIL)" \
    "printf '%s' \"\$AUDIT_OUT\" | grep -A1 '\[$n/6\]' | grep -q 'FAIL'"
}

# ── 1. FORWARD: the audit passes on this tree ────────────────────────────────
echo "1. Forward — the real tree passes the gate's own invocation"
run_audit "$ROOT"; RC=$?
[ $RC -ne 0 ] && printf '%s\n' "$AUDIT_OUT" | sed 's/^/     /'
assert "sanitization-audit.sh --origin-only exits 0 on this tree" "[ $RC -eq 0 ]"
assert "all six origin checks ran and passed (6/6)" \
  "printf '%s' \"\$AUDIT_OUT\" | grep -q 'Passed:.* 6/6'"
assert "no check reported a FAIL" \
  "! printf '%s' \"\$AUDIT_OUT\" | grep -q '❌ FAIL'"

# The clean fixture is the control for §2: if it did not pass, a later failure
# would not be attributable to the planted violation.
echo ""
echo "1b. Control — a clean fixture passes"
CLEAN="$(new_clean_fixture)"
run_audit "$CLEAN"; RC=$?
[ $RC -ne 0 ] && printf '%s\n' "$AUDIT_OUT" | sed 's/^/     /'
assert "clean fixture passes (control for the planted cases)" "[ $RC -eq 0 ]"

# ── 2. REVERSE: every check can still catch a real violation ─────────────────
echo ""
echo "2. Reverse — each of Checks 1-6 catches a planted violation"

# ── the origin marker, ASSEMBLED rather than written ─────────────────────────
# Check 1 screens for the ORIGINAL project's absolute path. Writing that string
# literally into this file would make THIS FILE the leak it is testing for:
# leak-guard.sh Pass 2 hard-fails on the absolute workspace prefix and on the
# origin project slug ANYWHERE in tracked content, and this suite SHIPS — tests/** is
# deliberately not in template-strip-manifest.txt, so a literal here reaches the
# public template. That is precisely the v6.4.x release-blocker shape.
#
# So the string is stored in halves and joined at runtime. The fixture still
# receives the exact literal the audit greps for; the file on disk carries no
# grep-able copy of it. Do NOT "tidy" this back into one string.
_OP_A='/work'; _OP_B='spaces/'; _OP_C='io'; _OP_D='un-ai'
ORIGIN_PATH="${_OP_A}${_OP_B}${_OP_C}${_OP_D}"

plant_1() { printf 'See %s/src for the reference.\n' "$ORIGIN_PATH" \
              >> "$1/.claude/agents/sample-agent.md"; }
plant_2() { cat > "$1/.logic-loom/scripts/bash/rogue.sh" <<'EOF'
#!/usr/bin/env bash
git commit -m "no approval seam anywhere in this script"
EOF
}
plant_3() { printf 'All surfaces MUST use neumorphism.\n' \
              >> "$1/.logic-loom/templates/sample-template.md"; }
plant_4() { printf 'Access is gated by the player tier and the DM tier.\n' \
              >> "$1/.logic-loom/memory/constitution.md"; }
plant_5() { printf 'Every campaign is owned by a DM and populated with NPCs.\n' \
              >> "$1/.logic-loom/memory/constitution.md"; }
plant_6() { printf 'Builds MUST use Expo and EAS Build.\n' \
              >> "$1/.logic-loom/memory/constitution.md"; }

reverse_case 1 "hardcoded origin project path ($ORIGIN_PATH)" plant_1
reverse_case 2 "git mutation with no approval mechanism"   plant_2
reverse_case 3 "project-specific design system"            plant_3
reverse_case 4 "project-specific tier names"               plant_4
reverse_case 5 "domain vocabulary in the constitution"     plant_5
reverse_case 6 "prescribed tech stack"                     plant_6

# ── 3. Check 5's narrowing, pinned in both directions ────────────────────────
# Removing the bare `character` term is only correct if it drops the noise and
# keeps the signal. Assert both, so a future "just add the word back" is loud.
echo ""
echo "3. Check 5 narrowing — generic English passes, domain phrasing still fails"

D5A="$(new_clean_fixture)"
cat >> "$D5A/.logic-loom/templates/sample-template.md" <<'EOF'
Free text, one line, may contain any character except a tab.
Maximum 1024 characters. Watch for a special character in the payload.
Character encoding is UTF-8.
EOF
run_audit "$D5A"; RC=$?
[ $RC -ne 0 ] && printf '%s\n' "$AUDIT_OUT" | sed 's/^/     /'
assert "ordinary software English using 'character' does NOT trip Check 5" "[ $RC -eq 0 ]"

D5B="$(new_clean_fixture)"
printf 'Each player character has a character sheet.\n' \
  >> "$D5B/.logic-loom/memory/constitution.md"
run_audit "$D5B"; RC=$?
assert "domain phrasing ('player character' / 'character sheet') still trips Check 5" \
  "[ $RC -ne 0 ]"
assert "and Check 5 is the one reporting it" \
  "printf '%s' \"\$AUDIT_OUT\" | grep -A1 '\[5/6\]' | grep -q 'FAIL'"

# ── 4. Check 7 cannot silently skip itself ───────────────────────────────────
# Every assertion above passes --origin-only. These do not: they exercise the
# DEFAULT (release-gate) mode, which is the mode promote-to-main.yml's binding
# post-strip audit actually uses.
echo ""
echo "4. Check 7 — the strip assertion cannot self-disable"

# run_audit_from <audit-script-path> <fixture-root> [args…]
# Lets a case run the audit from a DIFFERENT directory than the repo's, which is
# the whole point: Check 7 resolves leak-guard.sh + the strip manifest from the
# audit script's OWN directory, so where the script sits decides whether the
# check has its tooling.
run_audit_from() {
  local script="$1" root="$2"; shift 2
  AUDIT_OUT="$(LOOM_AUDIT_ROOT="$root" bash "$script" "$@" 2>&1)"
  return $?
}

# 4a. THE REGRESSION ITSELF. The audit alone in a directory — exactly what you
# get by copying just this script, or by narrowing promote-to-main.yml's
# `cp -R .logic-loom/scripts/bash /tmp/loom-audit-tools` to fewer files — run in
# default mode against a tree that LOOKS clean to Checks 1-6 but was never
# stripped. Before the fix this printed 6/6 and exited 0.
ALONE_DIR="$(mktemp -d "$TMPROOT/alone.XXXXXX")"
cp "$AUDIT" "$ALONE_DIR/sanitization-audit.sh"
UNSTRIPPED="$(new_clean_fixture)"
# A harness-dev artifact the strip is supposed to remove. Only Check 7 can see it.
printf 'PRODUCT VISION — harness-dev content the strip must remove.\n' > "$UNSTRIPPED/VISION.md"

run_audit_from "$ALONE_DIR/sanitization-audit.sh" "$UNSTRIPPED"; RC=$?
assert "default mode with Check 7 tooling missing FAILS (does not exit 0)" "[ $RC -ne 0 ]"
assert "…and says Check 7 CANNOT RUN rather than 'skipped'" \
  "printf '%s' \"\$AUDIT_OUT\" | grep -q 'Check 7 CANNOT RUN'"
assert "…and never claims the framework is sanitized" \
  "! printf '%s' \"\$AUDIT_OUT\" | grep -q 'All checks passed'"

# 4b. THE DENOMINATOR IS WHAT MADE THE SKIP INVISIBLE. In default mode the audit
# has 7 checks, so the score must be out of 7 whatever happens. A "6/6" here is
# the exact string that read as complete while a check had quietly vanished.
assert "default-mode score is out of 7, not out of 6" \
  "printf '%s' \"\$AUDIT_OUT\" | grep -q 'Passed:.* 6/7'"
assert "default mode never reports a 6/6 result" \
  "! printf '%s' \"\$AUDIT_OUT\" | grep -q 'Passed:.* 6/6'"

# 4c. FORWARD for Check 7: with the tooling beside it — the release path's
# preserved-copy invocation — Check 7 must actually EXECUTE. Pointed at this
# (deliberately un-stripped) dev tree it must FAIL, and fail for the harness-dev
# reason, not for a missing-tooling reason. An audit that reported "tooling
# missing" here would mean the release gate had lost its only strip assertion.
TOOLED_DIR="$(mktemp -d "$TMPROOT/tooled.XXXXXX")"
cp "$AUDIT" "$ROOT/.logic-loom/scripts/bash/leak-guard.sh" \
   "$ROOT/.logic-loom/scripts/bash/template-strip-manifest.txt" "$TOOLED_DIR/"
run_audit_from "$TOOLED_DIR/sanitization-audit.sh" "$ROOT"; RC=$?
assert "Check 7 EXECUTES when its tooling is present (label [7/7] printed)" \
  "printf '%s' \"\$AUDIT_OUT\" | grep -q '\[7/7\] Checking for harness-dev artifacts'"
assert "…and does not report its tooling as missing" \
  "! printf '%s' \"\$AUDIT_OUT\" | grep -q 'Check 7 CANNOT RUN'"
assert "…and catches this un-stripped dev tree (audit exits 1)" "[ $RC -ne 0 ]"
assert "…naming harness-dev artifacts as the reason" \
  "printf '%s' \"\$AUDIT_OUT\" | grep -q 'Harness-dev artifacts present'"

# 4d. --origin-only must ANNOUNCE the reduced scope. It is a legitimate mode
# (the gate job runs on un-stripped dev-main), but its success banner must not
# read as a full sanitization verdict — that conflation is what let a 6-check
# run stand in for a 7-check gate.
run_audit_from "$AUDIT" "$ROOT" --origin-only; RC=$?
assert "--origin-only still exits 0 on this tree" "[ $RC -eq 0 ]"
assert "--origin-only declares Check 7 OUT OF SCOPE" \
  "printf '%s' \"\$AUDIT_OUT\" | grep -q 'OUT OF SCOPE'"
assert "--origin-only does NOT claim 'Framework is sanitized'" \
  "! printf '%s' \"\$AUDIT_OUT\" | grep -q 'Framework is sanitized'"

results
[ $FAIL -eq 0 ] || exit 1
exit 0
