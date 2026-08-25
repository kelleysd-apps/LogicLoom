#!/usr/bin/env bash
# Contract Tests: a SHIPPED fail-closed gate must not demand a STRIPPED path
#
# ─────────────────────────────────────────────────────────────────────────────
# THE INVARIANT
# ─────────────────────────────────────────────────────────────────────────────
# Two things ship to a customer's clone: the strip manifest's DECISIONS (as
# absences — the files it removes are simply not there) and the CI workflow
# .github/workflows/plugin-tests.yml, which a cloner's very first push runs.
#
# Those two must not contradict each other. A CI step that hard-requires a path
# `template-strip-manifest.txt` deliberately deletes is a gate that fails on
# every customer, forever, for a file the release intentionally removed. The
# customer did not write the gate, cannot satisfy it, and has no way to know it
# was never meant for them.
#
# This has now shipped TWICE in the same shape:
#   1. check-generated-freshness.sh demanded artifacts/backlog-dashboard.html and
#      .logic-loom/graph/graph-bridge.jsonl. The manifest removes `artifacts` and
#      `.logic-loom/graph` WHOLESALE (manifest lines 152 / 173). Exit 1 on a
#      sanitized tree — verified empirically before this suite existed.
#   2. Six shipped contract suites asserted on maintainer-only files
#      (the strip manifest itself, history-scrub-rules.json, promote.md, the
#      non-empty dev backlog) that the same manifest removes.
#
# Its converse — "a tracked GENERATED artifact must be DECIDED (stripped or
# explicitly allowed to ship)" — is already covered by
# tests/contract/test_generated_artifacts_declared.sh. This suite is the other
# direction: nothing that SHIPS may DEMAND what the manifest REMOVES.
#
# ─────────────────────────────────────────────────────────────────────────────
# HOW IT IS CHECKED — a static SUSPECT list, then an EMPIRICAL verdict
# ─────────────────────────────────────────────────────────────────────────────
#   1. Read the plain (non-`stub:`, non-`warn:`) entries of the strip manifest.
#      Those are the paths that DISAPPEAR on a sanitized tree. `stub:` entries
#      still exist post-strip (with replaced content), so they are NOT demands
#      that can fail on absence and are excluded.
#   2. Read every single-line `run: bash …` / `run: python3 …` step out of
#      plugin-tests.yml — the exact set a cloner's CI executes.
#   3. SUSPECTS: step scripts whose NON-COMMENT source mentions a stripped path.
#      (Comments are excluded on purpose: a stripped path named in a comment is
#      documentation, and the fix for both blockers above was largely to ADD
#      comments explaining the strip interaction. Penalising that would push the
#      reasoning out of the file.)
#   4. VERDICT, empirically: build a throwaway stripped tree with the REAL
#      strip-harness-dev.sh, and RUN each suspect there. Exit 0 = it copes with
#      the absence. Nonzero = it demands what the release removes: violation,
#      with its own output as the evidence.
#
# WHY NOT A PURELY STATIC RULE: the first draft flagged any suspect that did not
# use a recognised "guard idiom", and produced FOUR false positives out of six —
# test_graph_bridge.sh checks its seed "if present", test_freeze_scope.sh writes
# its own `.loom-active-feature` under a fixture root, and so on. Every guard
# idiom is spelled differently, most resolve the path through a variable, and a
# rule that forces authors to annotate around it is a rule that gets annotated
# around. Running the thing answers the actual question — "would a cloner's CI
# go red?" — with no vocabulary to agree on.
#
# COST is bounded by construction: only SUSPECTS run, not all 35 steps. Today
# that is a handful. A step that never mentions a stripped path cannot be broken
# by the strip and is never executed here.
#
# MAINTAINER-TREE ONLY: this needs the strip manifest and the stripper, both of
# which are themselves stripped. On a sanitized/customer tree there is nothing to
# compare and the invariant is not about their repo — the suite says so and skips.
#
# ─────────────────────────────────────────────────────────────────────────────
# IT PROVES ITSELF
# ─────────────────────────────────────────────────────────────────────────────
# The last section PLANTS a violation in a throwaway fixture (a shipped-looking
# gate that demands a stripped path, with no provenance guard) and asserts the
# scanner reports it. A detector nobody has watched detect anything is a
# detector that quietly stopped working; this one is exercised every run.
#
# Overridable for that self-test: LOOM_STRIP_MANIFEST, LOOM_CI_WORKFLOW,
# LOOM_GATE_ROOT.
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

MANIFEST="${LOOM_STRIP_MANIFEST:-$ROOT/.logic-loom/scripts/bash/template-strip-manifest.txt}"
CI_WF="${LOOM_CI_WORKFLOW:-$ROOT/.github/workflows/plugin-tests.yml}"

echo "======================================="
echo " Shipped Gates vs Strip Manifest"
echo "======================================="
echo ""

# ── helpers ─────────────────────────────────────────────────────────────────

# stripped_paths <manifest> — plain removal entries only (no stub:, no warn:).
stripped_paths() {
  sed -e 's/#.*$//' "$1" \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | grep -v '^$' \
    | grep -v '^stub:' \
    | grep -v '^warn:'
}

# ci_steps <workflow> — single-line bash/python3 run: steps, command text only.
ci_steps() {
  grep -hoE '^[[:space:]]+run: (bash|python3) .+$' "$1" | sed -E 's/^[[:space:]]+run: //'
}

# ci_run_total <workflow> — EVERY `run:` declaration in the file, derived or not.
ci_run_total() { grep -cE '^[[:space:]]+run:' "$1" || true; }

# provenance_consumers <root> — every file in the tree that CONSUMES the
# tree-provenance helper, one relative path per line, sorted. This is the
# AUTHORITATIVE list section 7 accounts against, and it is DERIVED from the tree
# being tested rather than hardcoded: a hardcoded roster of eight names is a
# coverage floor with extra steps.
#
# Membership is "mentions the helper file OR calls either of its two public
# functions" — the same three spellings the suites actually use. It is
# deliberately broader than the run loop's own filter used to be, and the run
# loop now takes its candidates FROM here, so the two can never disagree about
# who is in scope.
provenance_consumers() {
  ( cd "$1" 2>/dev/null \
      && grep -rlE 'tree-provenance\.sh|loom_tree_kind|loom_require_consistent_tree' \
           --exclude-dir=.git . 2>/dev/null ) \
    | sed 's#^\./##' | sort -u
}

# ci_underived_steps <workflow> — the STEP NAME of every `run:` declaration that
# ci_steps() does NOT pick up (a multi-line `run: |` block, `run: npm test`,
# `run: ./script.sh`, …). One name per line, in file order.
ci_underived_steps() {
  awk '
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ {
      name = $0
      sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/, "", name)
      sub(/[[:space:]]+$/, "", name)
      next
    }
    /^[[:space:]]+run:[[:space:]]/ {
      cmd = $0
      sub(/^[[:space:]]+run:[[:space:]]*/, "", cmd)
      if (cmd ~ /^(bash|python3) .+$/) next
      print (name == "" ? "(unnamed step)" : name)
    }
  ' "$1"
}

# script_of <step-command> — the script path (2nd word).
script_of() { printf '%s' "$1" | awk '{print $2}'; }

# is_stripped <rel-path> <manifest> — is this path itself removed by the strip?
is_stripped() {
  local p="$1" e
  while IFS= read -r e; do
    [ -z "$e" ] && continue
    case "$p" in "$e"|"$e"/*) return 0 ;; esac
  done <<EOF
$(stripped_paths "$2")
EOF
  return 1
}

# scan_suspects [root] — emit "<step-command>" for each shipped CI step whose
# script mentions a stripped path outside a comment. STATIC and deliberately
# over-inclusive: this is the shortlist to RUN, not the verdict.
scan_suspects() {
  local root="${1:-$ROOT}" step scr entry
  while IFS= read -r step; do
    [ -z "$step" ] && continue
    scr="$(script_of "$step")"
    [ -f "$root/$scr" ] || continue             # not on disk here
    is_stripped "$scr" "$MANIFEST" && continue  # the gate itself does not ship
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      if sed -e 's/[[:space:]]*#.*$//' "$root/$scr" | grep -qF "$entry"; then
        echo "$step"
        break
      fi
    done <<EOF
$(stripped_paths "$MANIFEST")
EOF
  done <<EOF
$(ci_steps "$CI_WF")
EOF
}

# build_stripped_tree <dest> — a throwaway tree with the REAL strip applied.
# Reuses strip-harness-dev.sh rather than reimplementing the manifest semantics,
# so this can never disagree with what the release actually does. Returns 1 if
# the tooling to do it is absent (sanitized tree).
build_stripped_tree() {
  local dest="$1"
  [ -f "$ROOT/.logic-loom/scripts/bash/strip-harness-dev.sh" ] || return 1
  rm -rf "$dest"; mkdir -p "$dest" || return 1
  # Copy the TRACKED WORKING TREE, not `git archive HEAD`. The distinction is
  # the whole point of running this before a commit: HEAD is the state that
  # already shipped, and a contract test that only ever sees HEAD cannot fail on
  # the change you are about to make. (Caught the hard way — the first draft used
  # `git archive HEAD` and reported a fix as still broken because the fix was
  # uncommitted.) `git ls-files` is the same tracked-content model the stripper
  # itself uses.
  # `--cached --others --exclude-standard` = tracked PLUS new-but-not-ignored:
  # the set that is about to be committed. A new file added in the same change
  # as the gate that needs it must be present, or this reports a phantom break.
  #
  # …but `--cached` also lists TRACKED-BUT-DELETED paths — a file `rm`'d and not
  # yet committed, which is an utterly ordinary mid-cleanup state (and exactly the
  # kind of change this suite exists to guard). `tar` cannot stat those and exits
  # nonzero, so the whole builder failed and the suite went red with a message
  # pointing at the strip pipeline rather than at itself. Verified: with three
  # tracked-but-deleted files present this reported 25/27; restoring them gave
  # 32/32. So: drop paths that are not on disk, and ONLY those. An untracked-but-
  # PRESENT file still goes in (that is the `--others` intent above); a symlink,
  # including a dangling one, is on disk and still goes in.
  #
  # The old `2>/dev/null` here is what turned that into a mystery — it swallowed
  # `tar: …: Cannot stat`. Diagnostics are now captured and REPRINTED on failure,
  # so a genuine tar/git error is still loud and this still fails when it should.
  local tarerr="$dest.build.err"
  if ! { ( cd "$ROOT" && git ls-files -z --cached --others --exclude-standard \
             | while IFS= read -r -d '' f; do
                 [ -e "$f" ] || [ -L "$f" ] || continue   # tracked-but-deleted
                 printf '%s\0' "$f"
               done \
             | tar --null -T - -cf - ) | tar -x -C "$dest"; } 2>"$tarerr"; then
    echo "  ⚠ build_stripped_tree: copying the tracked working tree failed:" >&2
    tail -12 "$tarerr" | sed 's/^/       /' >&2
    rm -f "$tarerr"
    return 1
  fi
  rm -f "$tarerr"
  # Same three steps, in the same order, as promote-to-main.yml's build:
  # sanitize-for-template -> strip-harness-dev -> history-scrub. Running only the
  # stripper produced a tree no release ever emits, and reported two phantom
  # failures in test_project_identity.sh (which asserts on values history-scrub
  # resets). history-scrub.sh strips ITSELF, so — exactly like CI — it is invoked
  # from the source copy with LOOM_SCRUB_ROOT pointed at the tree.
  # Same reasoning as above about silence: keep the normal run quiet, but keep the
  # output so a failure here names the stage that failed instead of collapsing to
  # a bare "a stripped tree can be built: FAIL".
  local striperr="$dest.strip.err"
  if ! ( cd "$dest" \
        && git init -q . \
        && git add -A \
        && bash .logic-loom/scripts/bash/sanitize-for-template.sh \
        && bash .logic-loom/scripts/bash/strip-harness-dev.sh \
        && LOOM_SCRUB_ROOT="$dest" bash "$ROOT/.logic-loom/scripts/bash/history-scrub.sh" \
        && git add -A ) >"$striperr" 2>&1; then
    echo "  ⚠ build_stripped_tree: the sanitize/strip/scrub pipeline failed:" >&2
    tail -12 "$striperr" | sed 's/^/       /' >&2
    rm -f "$striperr"
    return 1
  fi
  rm -f "$striperr"
  return 0
}

# ── 1. inputs ───────────────────────────────────────────────────────────────
# Sections 1-2 need the manifest + stripper, which are themselves stripped. On a
# sanitized/customer tree they are absent BY DESIGN and the invariant is about
# OUR release, not their repo — so skip rather than fail. Sections 3-6 assert on
# shipped files and always run.
echo "1. Inputs"
SKIPPED=0
skip() { SKIPPED=$((SKIPPED + 1)); echo "  ⏭  SKIP: $1"; }

# WHICH KIND OF TREE — ask the SHARED helper, not two ad-hoc `[ -f ]` tests.
#
# This suite used to decide maintainer-vs-sanitized itself, from the presence of
# exactly two files (the strip manifest and the stripper). That is the same
# silent-skip defect it exists to catch, turned inward: delete either file on
# dev-main and this suite announced "sanitized tree", skipped sections 1-2 — the
# entire empirical stripped-tree run, the only part that proves anything — and
# still exited 0 with "ALL TESTS PASSED". Verified before this change: on a
# maintainer checkout with strip-harness-dev.sh removed it reported 21/21 passed,
# 2 skipped, exit 0, having run none of the invariant.
#
# tests/lib/tree-provenance.sh exists precisely so that "which kind of tree is
# this" is computed once, the same way, everywhere — and so that a PARTIAL
# marker set is a hard FAILURE rather than a downgrade to skip-mode. This suite
# is the last one that was not using it. It has no reason to be the exception:
# it does not test the helper, and the helper is trustworthy at this point in
# the run. So: an inconsistent tree stops this suite dead, loudly, exactly as it
# does the other six.
source "$ROOT/tests/lib/tree-provenance.sh"
loom_require_consistent_tree "$ROOT" || {
  echo "   (test_shipped_gates_vs_strip refuses to run on an inconsistent tree:" >&2
  echo "    it would skip its entire empirical half and still report success.)" >&2
  exit 1
}

MAINTAINER_TREE=0
[ "$(loom_tree_kind "$ROOT")" = "maintainer" ] && MAINTAINER_TREE=1

if [ "$MAINTAINER_TREE" -eq 0 ]; then
  skip "sections 1-2 — sanitized tree (no strip manifest / stripper: both are stripped)"
  echo ""
else
  assert "strip manifest readable: $MANIFEST" "[ -f '$MANIFEST' ]"
  assert "customer CI workflow readable: $CI_WF" "[ -f '$CI_WF' ]"
  # ── FULL ACCOUNTING, NOT A COVERAGE FLOOR ───────────────────────────────
  # This was `need >= 20` against a real 37. That is the softened-floor idiom
  # deleted from promote-to-main.yml in this same cycle (see its "The floor is
  # therefore gone" comment), reintroduced one file over: a floor of 20 lets 17
  # of 37 declarations — 46% — drop out of the suspect scan without a word, and
  # ci_steps() cannot see a `run: |` block, a `run: npm test` or a
  # `run: ./script.sh` BY CONSTRUCTION. Silent narrowing of THIS scan is how a
  # shipped-gate-vs-strip blocker gets through, because a step that is never
  # derived is never scanned and never run against the stripped tree.
  #
  # So: every `run:` declaration in plugin-tests.yml must land in exactly one of
  # two buckets, and the two must add up to the total.
  #   DERIVED   — ci_steps() picks it up; eligible for the suspect scan below.
  #   ACCOUNTED — listed by STEP NAME in the heredoc below WITH a reason.
  # Anything else is UNCLASSIFIED and fails, naming the step. A STALE accounting
  # line (one matching no real underived step) fails too, so an excuse cannot
  # outlive the step it excused. Add a CI step and it is accounted for here with
  # no edit to this file; narrow the derivation and this goes red instead of
  # quietly covering less than it did yesterday.
  # (Read into the variable directly, NOT via \$(cat <<ACC). bash mis-parses a
  # quoted heredoc inside a command substitution when the body contains an
  # apostrophe, which a plain-English reason will sooner or later.)
  IFS='' read -r -d '' ACCOUNTED_REASONS <<'ACC' || true
Constitutional Compliance Check :: multi-line `run: |` block behind a step-level `if:`; a best-effort advisory report (`|| true`) that cannot redden a cloner's first push, so it cannot be a shipped gate demanding a stripped path.
ACC
  N_TOTAL="$(ci_run_total "$CI_WF")"
  N_STEPS="$(ci_steps "$CI_WF" | grep -c . || true)"
  UNDERIVED="$(ci_underived_steps "$CI_WF")"
  N_UNDER="$(printf '%s\n' "$UNDERIVED" | grep -c . || true)"
  N_SUM=$((N_STEPS + N_UNDER))

  assert "every run: declaration is classified ($N_STEPS derived + $N_UNDER underived = $N_SUM, total $N_TOTAL)" \
    "[ '$N_SUM' -eq '$N_TOTAL' ]"
  assert "the derivation still yields steps to scan (got $N_STEPS)" \
    "[ '$N_STEPS' -ge 1 ]"

  UNCLASSIFIED=""
  while IFS= read -r nm; do
    [ -z "$nm" ] && continue
    if ! printf '%s\n' "$ACCOUNTED_REASONS" | grep -qF "$nm ::"; then
      UNCLASSIFIED="${UNCLASSIFIED}${nm}; "
    fi
  done <<EOF
$UNDERIVED
EOF
  assert "no UNCLASSIFIED run: step — underivable and unaccounted (got: ${UNCLASSIFIED:-none})" \
    '[ -z "$UNCLASSIFIED" ]'

  STALE=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    nm="${line%% ::*}"
    if ! printf '%s\n' "$UNDERIVED" | grep -qxF "$nm"; then
      STALE="${STALE}${nm}; "
    fi
  done <<EOF
$ACCOUNTED_REASONS
EOF
  assert "no STALE accounting line — excuses a step that no longer exists (got: ${STALE:-none})" \
    '[ -z "$STALE" ]'
  N_STRIP="$(stripped_paths "$MANIFEST" | grep -c . || true)"
  assert "strip manifest declares removals (got $N_STRIP)" "[ '$N_STRIP' -ge 5 ]"
  echo ""

  # ── 2. THE INVARIANT ──────────────────────────────────────────────────────
  echo "2. No shipped CI gate demands a stripped path"
  SUSPECTS="$(scan_suspects "$ROOT")"
  N_SUS="$(printf '%s' "$SUSPECTS" | grep -c . || true)"
  echo "  suspects (mention a stripped path outside a comment): $N_SUS"

  STRIPPED_TREE="$(mktemp -d 2>/dev/null || mktemp -d -t loomstrip)"
  if build_stripped_tree "$STRIPPED_TREE/tree"; then
    assert "a stripped tree can be built with the real strip-harness-dev.sh" "true"
    VIOL=""
    while IFS= read -r step; do
      [ -z "$step" ] && continue
      out="$( cd "$STRIPPED_TREE/tree" && eval "$step" 2>&1 )"
      rc=$?
      if [ "$rc" -eq 0 ]; then
        echo "  ✓ copes with the strip: $step"
      else
        VIOL="${VIOL}${step}"$'\n'
        echo "  ✗ FAILS on a stripped tree (exit $rc): $step"
        printf '%s\n' "$out" | tail -12 | sed 's/^/       /'
      fi
    done <<EOF
$SUSPECTS
EOF
    if [ -n "$VIOL" ]; then
      echo "     ────────────────────────────────────────────────────────────"
      echo "     These SHIP and a cloner's FIRST push runs them, but they demand"
      echo "     a path template-strip-manifest.txt deliberately removes."
      echo "     Fix the SCRIPT — derive from the git index, or source"
      echo "     tests/lib/tree-provenance.sh and skip the maintainer-only"
      echo "     assertions. Do NOT narrow the strip manifest to suit a test."
    fi
    assert "no shipped CI step fails on a stripped tree" "[ -z \"\$VIOL\" ]"
  else
    assert "a stripped tree can be built with the real strip-harness-dev.sh" "false"
  fi
  rm -rf "$STRIPPED_TREE"
  echo ""
fi

# ── 3. the freshness gate specifically (blocker 1, named so it stays named) ──
echo "3. check-generated-freshness.sh derives its set from the git index"
FRESH="$ROOT/.logic-loom/scripts/bash/check-generated-freshness.sh"
assert "the freshness gate ships (it is not strip-manifested)" \
  "! is_stripped '.logic-loom/scripts/bash/check-generated-freshness.sh' '$MANIFEST'"
assert "it reads the git index rather than assuming the artifacts exist" \
  "grep -q 'ls-files' '$FRESH'"
assert "an ABSENT-BUT-TRACKED artifact still FAILS (the rot case keeps its teeth)" \
  "grep -q 'the tracked artifact is MISSING from the tree' '$FRESH'"
assert "it REFUSES rather than passing when the index is unreadable" \
  "grep -q 'REFUSING' '$FRESH'"
echo ""

# ── 4. /initialize-project: three paths, one list ───────────────────────────
# The removal used to exist in only two of the three. The command file — the one
# an agent actually executes — had no CI-removal step at all, so an agent-driven
# init left branch-topology-guard.yml in place and every PR the customer opened
# into main was rejected.
echo "4. All three /initialize-project paths remove the same maintainer CI"
EXPECTED_WF="branch-topology-guard.yml
leak-guard.yml
promote-to-main.yml
release-tag.yml"

removed_set() { # <file> -> sorted unique workflow basenames on rm/for-wf lines
  grep -E 'rm -f|for wf in' "$1" 2>/dev/null \
    | grep -oE '\.github/workflows/[A-Za-z0-9._-]+\.yml' \
    | sed 's#.*/##' | sort -u
}

INIT_SH="$ROOT/init-project.sh"
INIT_SKILL="$ROOT/plugins/loom-maintenance/skills/project-initialization/SKILL.md"
INIT_CMD="$ROOT/plugins/loom-maintenance/commands/initialize-project.md"

for f in "$INIT_SH" "$INIT_SKILL" "$INIT_CMD"; do
  assert "init path exists: ${f#$ROOT/}" "[ -f '$f' ]"
done

S_SH="$(removed_set "$INIT_SH")"
S_SKILL="$(removed_set "$INIT_SKILL")"
S_CMD="$(removed_set "$INIT_CMD")"

assert "init-project.sh removes exactly the four maintainer workflows" \
  "[ \"\$S_SH\" = \"\$EXPECTED_WF\" ]"
assert "project-initialization SKILL.md removes exactly the same four" \
  "[ \"\$S_SKILL\" = \"\$EXPECTED_WF\" ]"
assert "initialize-project.md (the executed command) removes exactly the same four" \
  "[ \"\$S_CMD\" = \"\$EXPECTED_WF\" ]"
assert "none of the three removes plugin-tests.yml (it validates the shipped harness)" \
  "! printf '%s\n%s\n%s\n' \"\$S_SH\" \"\$S_SKILL\" \"\$S_CMD\" | grep -q 'plugin-tests.yml'"
echo ""

# ── 5. the guard that ships tells its inheritor how to get rid of it ────────
# branch-topology-guard.yml MUST ship (a pull_request workflow is evaluated from
# the BASE branch), so a cloner inherits it. Someone who adopted LogicLoom via
# /update-framework never ran /initialize-project and never had it removed —
# their PRs into main start failing a rule about OUR release topology. There is
# no machinery for that case on purpose; there is a message.
echo "5. The inherited guard explains its own removal"
BTG="$ROOT/.github/workflows/branch-topology-guard.yml"
assert "branch-topology-guard.yml exists" "[ -f '$BTG' ]"
assert "it ships (not strip-manifested — the base branch must carry it)" \
  "! is_stripped '.github/workflows/branch-topology-guard.yml' '$MANIFEST'"
assert "its header tells a cloner to delete it, with the command" \
  "grep -q 'rm .github/workflows/branch-topology-guard.yml' '$BTG'"
assert "its header names the /update-framework adopter who never ran init" \
  "grep -q 'update-framework' '$BTG'"
UF="$ROOT/plugins/loom-maintenance/commands/update-framework.md"
assert "/update-framework warns about inherited maintainer CI" \
  "grep -q 'branch-topology-guard.yml' '$UF'"
echo ""

# ── 6. SELF-TEST: plant a violation, require the machinery to catch it ─────
# Split in two, because the machinery has two halves and each can rot alone:
#   (a) the STATIC shortlist — does a gate that mentions a stripped path get
#       onto the run list, and does a mention in a COMMENT stay off it?
#   (b) the EMPIRICAL verdict — of two gates that BOTH mention the path, does
#       the one that dies on absence fail and the one that copes pass?
echo "6. Self-test — a planted violation is caught"
FIXD="$(mktemp -d 2>/dev/null || mktemp -d -t loomgates)"
trap 'rm -rf "$FIXD"' EXIT
mkdir -p "$FIXD/tests/contract" "$FIXD/.github/workflows"

cat > "$FIXD/manifest.txt" <<'FIXEOF'
# fixture strip manifest
stub: VISION.md :: .logic-loom/templates/project-vision-template.md
warn: something/deferred
artifacts
FIXEOF

cat > "$FIXD/.github/workflows/ci.yml" <<'FIXEOF'
jobs:
  contract-tests:
    steps:
      - name: Planted gate
        run: bash tests/contract/planted_gate.sh
      - name: Compliant gate
        run: bash tests/contract/compliant_gate.sh
      - name: Comment-only gate
        run: bash tests/contract/comment_only_gate.sh
FIXEOF

# Demands the stripped path unconditionally — the shape of both real blockers.
cat > "$FIXD/tests/contract/planted_gate.sh" <<'FIXEOF'
#!/usr/bin/env bash
[ -f artifacts/backlog-dashboard.html ] || { echo "the tracked artifact is MISSING"; exit 1; }
FIXEOF
# Same demand, but it asks the index first.
cat > "$FIXD/tests/contract/compliant_gate.sh" <<'FIXEOF'
#!/usr/bin/env bash
git ls-files --error-unmatch -- artifacts/backlog-dashboard.html >/dev/null 2>&1 || exit 0
[ -f artifacts/backlog-dashboard.html ] || { echo "missing"; exit 1; }
FIXEOF
# Mentions it only in a comment — must never reach the run list.
cat > "$FIXD/tests/contract/comment_only_gate.sh" <<'FIXEOF'
#!/usr/bin/env bash
# artifacts/backlog-dashboard.html is stripped from the template on purpose.
echo ok
FIXEOF

MANIFEST="$FIXD/manifest.txt"
CI_WF="$FIXD/.github/workflows/ci.yml"
SUS="$(scan_suspects "$FIXD")"
assert "(a) the unconditional gate lands on the suspect list" \
  "printf '%s' \"\$SUS\" | grep -q 'planted_gate.sh'"
assert "(a) the index-aware gate lands on it too (mentioning it is enough)" \
  "printf '%s' \"\$SUS\" | grep -q 'compliant_gate.sh'"
assert "(a) a comment-only mention does NOT land on it" \
  "! printf '%s' \"\$SUS\" | grep -q 'comment_only_gate.sh'"

# (b) run both suspects in a directory where the stripped path is absent and
#     git has an empty index — i.e. what a customer clone looks like.
( cd "$FIXD" && git init -q . >/dev/null 2>&1 && git add -A >/dev/null 2>&1 ) || true
( cd "$FIXD" && bash tests/contract/planted_gate.sh >/dev/null 2>&1 ); PLANTED_RC=$?
( cd "$FIXD" && bash tests/contract/compliant_gate.sh >/dev/null 2>&1 ); COMPLIANT_RC=$?
assert "(b) the unconditional gate FAILS when the stripped path is absent (rc=$PLANTED_RC)" \
  "[ '$PLANTED_RC' -ne 0 ]"
assert "(b) the index-aware gate PASSES on the same tree (rc=$COMPLIANT_RC)" \
  "[ '$COMPLIANT_RC' -eq 0 ]"

# Restore the real inputs for anything downstream.
MANIFEST="${LOOM_STRIP_MANIFEST:-$ROOT/.logic-loom/scripts/bash/template-strip-manifest.txt}"
CI_WF="${LOOM_CI_WORKFLOW:-$ROOT/.github/workflows/plugin-tests.yml}"
echo ""

# ── 7. A CUSTOMER WORKING NORMALLY CANNOT TURN A SHIPPED SUITE RED ──────────
# Section 2 runs the shipped gates against a FRESHLY stripped tree — the state a
# customer's repo is in for about five minutes, before they do any work in it.
# That blind spot let a real defect through: tests/lib/tree-provenance.sh listed
# `CHANGELOG.md` among the maintainer-only marker files whose presence/absence
# decides maintainer-vs-sanitized. A customer starting a changelog — an utterly
# ordinary thing to do in a repo you own — flipped exactly one marker to
# present, classified their tree `inconsistent` (a deliberate hard failure), and
# took ALL SIX strip-aware contract suites red at "0/0 passed": zero assertions
# run, six gates failing, for a file they were entitled to create.
#
# So the invariant this section encodes is broader than section 2's:
#
#     A customer working normally in their own repository must not be able to
#     turn a shipped suite red.
#
# Method: build the sanitized tree, then make it look like a real project
# somebody has actually worked in — a changelog, a README they edited, their own
# app workspace and package.json, a docs/ folder, their own CI workflow, a
# LICENSE, some source — and only THEN run the shipped gates. Every one of those
# is a path our template does not ship, which is the point: a shipped gate must
# be indifferent to files that are none of its business.
#
# SCOPE — which shipped gates run here: the ones that consult
# tests/lib/tree-provenance.sh, i.e. every gate whose behaviour depends on what
# kind of tree it is standing on. Those are exactly the gates a stray
# customer-authored file can mislead. Running all ~35 CI steps a second time
# costs minutes for no added signal: a gate that never asks about provenance
# cannot be confused by a customer's CHANGELOG.md, and section 2 already runs
# the ones that touch stripped paths.
#
# That scope is DERIVED and then FULLY ACCOUNTED FOR — the same philosophy as
# section 1's `run:` accounting, deliberately, so a reader does not find two
# different philosophies in one suite. provenance_consumers() greps the
# customer tree for the helper; every name it returns must land in exactly one
# of two buckets, and the two must add up to the derived total:
#   RUN       — it is a shipped CI step and was executed against this tree.
#   ACCOUNTED — named in the heredoc below WITH a reason.
# Anything else is UNCLASSIFIED and fails, naming the file; a STALE accounting
# line (one matching no derived consumer) fails too, so an excuse cannot outlive
# the thing it excused.
#
# MAINTAINER-TREE ONLY, same as sections 1-2: building a sanitized tree needs
# the stripper, which is itself stripped.
echo "7. A customer-worked sanitized tree keeps every shipped gate green"
if [ "$MAINTAINER_TREE" -eq 0 ]; then
  skip "section 7 — sanitized tree (cannot build a sanitized tree without the stripper)"
  echo ""
else
  CUSTD="$(mktemp -d 2>/dev/null || mktemp -d -t loomcust)"
  if build_stripped_tree "$CUSTD/tree"; then
    CT="$CUSTD/tree"

    # ── make it look like somebody's real project ──────────────────────────
    # The changelog: the exact file that caused the defect.
    printf '# Changelog\n\n## [0.2.0] - 2026-01-04\n- Shipped the thing.\n' > "$CT/CHANGELOG.md"
    # A README they edited (ours ships; a customer rewrites it on day one).
    printf '\n## Our project\n\nNotes we added after cloning.\n' >> "$CT/README.md"
    # Their own product workspace, per the harness/product boundary.
    mkdir -p "$CT/web/src"
    printf '{ "name": "customer-app", "version": "0.2.0", "private": true }\n' > "$CT/web/package.json"
    printf 'export const hello = () => "hi";\n' > "$CT/web/src/index.js"
    # Their own docs, their own CI, their own licence.
    mkdir -p "$CT/docs"
    printf '# Architecture\n\nHow our app is put together.\n' > "$CT/docs/architecture.md"
    mkdir -p "$CT/.github/workflows"
    printf 'name: CI\non: [push]\njobs:\n  build:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n' \
      > "$CT/.github/workflows/ci.yml"
    printf 'MIT License\n\nCopyright (c) 2026 A Customer\n' > "$CT/LICENSE"
    ( cd "$CT" && git add -A >/dev/null 2>&1 ) || true

    assert "the customer-worked tree really does have a CHANGELOG.md" \
      "[ -f '$CT/CHANGELOG.md' ]"
    assert "...and it is still a sanitized tree (no maintainer-only file returned)" \
      "[ ! -f '$CT/.logic-loom/scripts/bash/strip-harness-dev.sh' ]"

    # (a) The classifier itself must still say `sanitized`, not `inconsistent`.
    #     Sourced from the CUSTOMER's copy of the helper — that is the code that
    #     actually runs in their CI.
    CT_KIND="$( cd "$CT" && bash -c '. tests/lib/tree-provenance.sh && loom_tree_kind "$PWD"' 2>&1 )"
    assert "tree-provenance classifies the customer-worked tree as sanitized (got: $CT_KIND)" \
      "[ \"\$CT_KIND\" = 'sanitized' ]"

    # (b) And every provenance-consuming shipped gate must still come out green.
    #
    # The authoritative list is derived from the tree, not typed out here.
    # (Read into the variable directly, NOT via \$(cat <<ACC) — bash mis-parses a
    # quoted heredoc inside a command substitution when the body contains an
    # apostrophe, which a plain-English reason will sooner or later.)
    IFS='' read -r -d '' PROV_ACCOUNTED <<'PACC' || true
tests/lib/tree-provenance.sh :: the classifier itself, not a gate that consumes it. Its own admission test covers the marker list; running it here would be testing the ruler with the ruler.
tests/contract/test_shipped_gates_vs_strip.sh :: this suite. Provenance-adjacent but re-entrant — one level of recursion is enough, and a second proves nothing extra.
.github/workflows/promote-to-main.yml :: the maintainer release driver. It only NAMES the helper in a comment, it is workflow_dispatch-only so a customer's push never runs it, and /initialize-project deletes it (section 4). Not a gate a stray customer file can redden.
PACC

    DERIVED_CONSUMERS="$(provenance_consumers "$CT")"
    N_DERIVED="$(printf '%s\n' "$DERIVED_CONSUMERS" | grep -c . || true)"
    assert "the derivation still finds provenance consumers on the customer tree (got $N_DERIVED)" \
      "[ '$N_DERIVED' -ge 1 ]"

    CUST_VIOL=""
    N_RAN=0
    RAN_CONSUMERS=""
    while IFS= read -r step; do
      [ -z "$step" ] && continue
      scr="$(script_of "$step")"
      [ -f "$CT/$scr" ] || continue
      # Candidates come from the DERIVED list — one authority, not a second
      # private filter that can drift away from it.
      printf '%s\n' "$DERIVED_CONSUMERS" | grep -qxF "$scr" || continue
      printf '%s\n' "$PROV_ACCOUNTED" | grep -qF "$scr ::" && continue
      N_RAN=$((N_RAN + 1))
      RAN_CONSUMERS="${RAN_CONSUMERS}${scr}"$'\n'
      out="$( cd "$CT" && eval "$step" 2>&1 )"
      rc=$?
      if [ "$rc" -eq 0 ]; then
        echo "  ✓ green on a customer-worked tree: $scr"
      else
        CUST_VIOL="${CUST_VIOL}${scr}"$'\n'
        echo "  ✗ RED on a customer-worked tree (exit $rc): $scr"
        printf '%s\n' "$out" | tail -12 | sed 's/^/       /'
      fi
    done <<EOF
$(ci_steps "$CI_WF")
EOF

    # ── FULL ACCOUNTING, NOT A COVERAGE FLOOR ─────────────────────────────
    # This was `need >= 5` against a real 8 — the softened-floor idiom deleted
    # from promote-to-main.yml and from section 1 of this very file in the same
    # cycle. A floor of 5 lets THREE of the eight provenance-consuming gates
    # stop being found — renamed, dropped from plugin-tests.yml, or filtered out
    # by a derivation that quietly stopped matching them — and still reports
    # success. A gate silently falling out of its own coverage list is precisely
    # the failure this suite exists to detect, so it may not be the one failure
    # the suite tolerates in itself.
    UNCLASSIFIED_PROV=""
    while IFS= read -r c; do
      [ -z "$c" ] && continue
      printf '%s' "$RAN_CONSUMERS" | grep -qxF "$c" && continue
      printf '%s\n' "$PROV_ACCOUNTED" | grep -qF "$c ::" && continue
      UNCLASSIFIED_PROV="${UNCLASSIFIED_PROV}${c}; "
    done <<EOF
$DERIVED_CONSUMERS
EOF
    assert "no UNCLASSIFIED provenance consumer — derived but neither run nor accounted (got: ${UNCLASSIFIED_PROV:-none})" \
      '[ -z "$UNCLASSIFIED_PROV" ]'

    PROV_STALE=""
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      nm="${line%% ::*}"
      if ! printf '%s\n' "$DERIVED_CONSUMERS" | grep -qxF "$nm"; then
        PROV_STALE="${PROV_STALE}${nm}; "
      fi
    done <<EOF
$PROV_ACCOUNTED
EOF
    assert "no STALE provenance accounting line — excuses a consumer that no longer exists (got: ${PROV_STALE:-none})" \
      '[ -z "$PROV_STALE" ]'

    N_PROV_ACC="$(printf '%s\n' "$PROV_ACCOUNTED" | grep -c . || true)"
    assert "every provenance consumer is classified ($N_RAN run + $N_PROV_ACC accounted = $((N_RAN + N_PROV_ACC)), derived $N_DERIVED)" \
      "[ '$((N_RAN + N_PROV_ACC))' -eq '$N_DERIVED' ]"
    if [ -n "$CUST_VIOL" ]; then
      echo "     ────────────────────────────────────────────────────────────"
      echo "     These went RED because of files the CUSTOMER created in their"
      echo "     own repository. Nothing above is exotic — a changelog, a README"
      echo "     edit, an app workspace, docs, a CI file, a licence."
      echo "     Fix the GATE. If the cause is tree-provenance.sh, the marker"
      echo "     list has taken on a path a customer can plausibly author; see"
      echo "     the admission test in tests/lib/tree-provenance.sh."
    fi
    assert "no shipped gate goes red on a customer-worked sanitized tree" \
      "[ -z \"\$CUST_VIOL\" ]"
  else
    assert "a customer-worked sanitized tree can be built" "false"
  fi
  rm -rf "$CUSTD"
  echo ""
fi

echo "======================================="
echo " Results: $PASS/$TOTAL passed, $FAIL failed, $SKIPPED skipped"
echo "======================================="
[ "$FAIL" -eq 0 ] || { echo "❌ SOME TESTS FAILED"; exit 1; }
echo "✅ ALL TESTS PASSED"
exit 0
