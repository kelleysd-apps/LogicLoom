#!/usr/bin/env bash
# tests/lib/tree-provenance.sh — sourceable helper: what KIND of tree am I on?
#
# ═════════════════════════════════════════════════════════════════════════════
# WHY THIS EXISTS
# ═════════════════════════════════════════════════════════════════════════════
# `.logic-loom/scripts/bash/strip-harness-dev.sh` (driven by
# `template-strip-manifest.txt`) builds the SANITIZED public template shipped to
# customers. Several contract suites under tests/contract/ assert on files that
# manifest REMOVES from that sanitized tree — e.g.
# `plugins/loom-maintenance/commands/promote.md`, the strip manifest itself,
# `.logic-loom/scripts/bash/history-scrub-rules.json`. Those suites also SHIP —
# they run in a customer's own CI via .github/workflows/plugin-tests.yml — so
# every cloner's very first push went red on assertions that were never true of
# their tree, checking a maintainer-only file that promotion had, by design,
# already deleted.
#
# The fix is NOT "loosen the assertion everywhere" — that would silently weaken
# the suites on the dev-main line where the files DO exist and the assertions
# ARE meaningful. It is "know which kind of tree you are standing on, and only
# skip the specific assertions that cannot possibly hold on the other kind."
# This file is the single shared answer to "which kind of tree is this", so that
# answer is computed once, the same way, everywhere it is asked.
#
# ═════════════════════════════════════════════════════════════════════════════
# THE RULE
# ═════════════════════════════════════════════════════════════════════════════
# A fixed list of MAINTAINER-ONLY marker paths — every one of them a target of
# a bare (non-`stub:`, non-`warn:`) entry in template-strip-manifest.txt, i.e.
# REMOVED wholesale by strip-harness-dev.sh — is checked for existence on disk
# under ROOT:
#
#   .logic-loom/scripts/bash/template-strip-manifest.txt
#   .logic-loom/scripts/bash/leak-guard.sh
#   .logic-loom/scripts/bash/strip-harness-dev.sh
#   .logic-loom/scripts/bash/history-scrub-rules.json
#   plugins/loom-maintenance/commands/promote.md
#
#   ALL present -> "maintainer"   (dev-main / a maintainer checkout)
#   ALL absent  -> "sanitized"    (a promoted / customer tree)
#   MIXED       -> "inconsistent"
#
# ═════════════════════════════════════════════════════════════════════════════
# WHAT QUALIFIES AS A MARKER — TWO CONDITIONS, BOTH REQUIRED
# ═════════════════════════════════════════════════════════════════════════════
# A marker must satisfy BOTH:
#
#   (1) It exists on the dev line and is REMOVED by the strip — i.e. it is the
#       target of a bare (non-`stub:`, non-`warn:`) entry in
#       template-strip-manifest.txt, and is a stable individual FILE (not a
#       directory, not a glob), so "present on disk" is unambiguous.
#
#   (2) A customer, working normally in a project they own, would NEVER
#       independently create a file at that exact path.
#
# Condition (2) is the one that is easy to forget, and forgetting it is a
# CUSTOMER-FACING BUG, not a cosmetic one. `inconsistent` is a deliberate hard
# failure (see the next section) — so any marker a customer might create on
# their own turns every guarded suite red in THEIR repo for something they
# legitimately did. That is the exact defect class the provenance helper exists
# to fix, reintroduced one level up.
#
#   REJECTED: CHANGELOG.md  — do not add it back.
#   It satisfies (1): the manifest removes it (the harness's own version
#   history is maintainer-only). It fails (2) catastrophically: `CHANGELOG.md`
#   is a universal, convention-driven filename at the repository root. A
#   customer who clones the sanitized template and starts a changelog — an
#   utterly ordinary thing for any project to do — flips exactly one marker to
#   present and classifies their own tree as `inconsistent`. Verified
#   empirically before this list was trimmed: on a real sanitized tree with a
#   hand-written CHANGELOG.md, ALL SIX strip-aware contract suites exited 1
#   with "0/0 passed" — zero assertions run, six red gates, in a repo the
#   customer owns.
#
# The five markers that remain all live inside LogicLoom's own namespaces —
# `.logic-loom/scripts/bash/` and `plugins/loom-maintenance/commands/` — with
# harness-specific basenames (`strip-harness-dev.sh`, `leak-guard.sh`,
# `history-scrub-rules.json`, `template-strip-manifest.txt`, `promote.md`).
# Those directories ship, but their inventory is the harness's, and a customer
# writing their own code has no reason to author a file at any of those paths.
# The generic-filename hazard that sinks CHANGELOG.md does not reach them:
# `promote.md` is a common-ish word, but only at
# `plugins/loom-maintenance/commands/promote.md` — inside a plugin the customer
# did not write — and a customer adding their own command there is authoring
# harness content, not doing ordinary project work.
#
# FIVE MARKERS IS ENOUGH. The classification only needs the maintainer and
# sanitized populations to be separable, and the strip is all-or-nothing: it
# removes every one of these in a single pass, so on any real tree the five
# move together and unanimity is trivially reached. Extra markers do not make
# the maintainer/sanitized call more certain — one correct marker would decide
# it. What the extra markers buy is `inconsistent` DETECTION: the chance that a
# partial/corrupt strip, or a marker that drifted out of sync with the
# manifest, is noticed rather than silently read as one clean kind. Dropping
# from six to five costs one independent chance to notice such drift, and
# nothing else — the five remaining are four separate files under
# `.logic-loom/scripts/bash/` plus one under `plugins/`, spanning both strip
# regions, so a partial strip that missed a region still trips the mixed
# result. And the marker we dropped was not merely redundant for that purpose:
# it was actively generating FALSE `inconsistent` verdicts on healthy customer
# trees, which is strictly worse than one fewer true-positive chance.
#
# ═════════════════════════════════════════════════════════════════════════════
# WHY "inconsistent" IS A THIRD OUTCOME, NOT AN ERROR SWALLOWED INTO A GUESS
# ═════════════════════════════════════════════════════════════════════════════
# The whole point of this helper is to let a suite SKIP an assertion it cannot
# meet on a sanitized tree. A naive "if any marker is missing, treat this as
# sanitized and skip" would make deleting ONE marker on the dev line — say, an
# accidental `rm` of the strip manifest, or a future refactor that drops
# history-scrub-rules.json without updating this list — silently downgrade
# EVERY guarded assertion in EVERY one of these suites to skip-mode. That is
# strictly worse than the bug this file exists to fix: instead of one suite
# failing loudly on a real regression, six suites would go quiet at once.
#
# So a MIXED result is never treated as "close enough to sanitized" or "close
# enough to maintainer" — it is its own outcome, and callers MUST treat it as a
# hard FAILURE. `loom_require_consistent_tree` below is the enforcement point:
# it fails loudly, names which markers are present and which are absent, and
# never returns 0 on an inconsistent tree. No caller may special-case its way
# around that — an inconsistent tree means this file's premise (that a tree is
# cleanly one kind or the other) has stopped holding, and that is a bug to fix,
# not a state to route around.
#
# ═════════════════════════════════════════════════════════════════════════════
# HOW A CALLER USES THIS
# ═════════════════════════════════════════════════════════════════════════════
#   source "$ROOT/tests/lib/tree-provenance.sh"
#   case "$(loom_tree_kind "$ROOT")" in
#     maintainer)   assert "..." "..." ;;
#     sanitized)    echo "  ⏭  SKIP: <name> — sanitized tree (maintainer-only file)" ;;
#     inconsistent) loom_require_consistent_tree "$ROOT" || exit 1 ;;
#   esac
#
# Or, when a whole suite should refuse to proceed on an inconsistent tree
# up front:
#   loom_require_consistent_tree "$ROOT" || exit 1
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
# ═════════════════════════════════════════════════════════════════════════════

# The marker list. One path per line.
#
# ADMISSION TEST (both conditions — see "WHAT QUALIFIES AS A MARKER" above):
#   (1) present on the dev line AND removed by the strip — a "bare" (non-stub,
#       non-warn) entry in template-strip-manifest.txt naming a stable
#       individual FILE, not a directory and not a glob; AND
#   (2) a path a customer would NEVER independently create in their own
#       project.
#
# CHANGELOG.md is the rejected example: it passes (1) and fails (2), and adding
# it back turns all six strip-aware suites red on any customer tree that has a
# changelog. Do not re-add it. The regression test that catches this lives in
# tests/contract/test_shipped_gates_vs_strip.sh § "customer-worked tree".
LOOM_TREE_PROVENANCE_MARKERS='.logic-loom/scripts/bash/template-strip-manifest.txt
.logic-loom/scripts/bash/leak-guard.sh
.logic-loom/scripts/bash/strip-harness-dev.sh
.logic-loom/scripts/bash/history-scrub-rules.json
plugins/loom-maintenance/commands/promote.md'

# _loom_tree_provenance_root [ROOT] — resolve ROOT the same way every contract
# suite in this repo already does: explicit arg, else `git rev-parse
# --show-toplevel` from this file's location, else two directories up
# (tests/lib -> repo root).
_loom_tree_provenance_root() {
  local given="${1:-}"
  if [ -n "$given" ]; then
    printf '%s\n' "$given"
    return 0
  fi
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local top
  if top="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)"; then
    printf '%s\n' "$top"
  else
    printf '%s\n' "$(cd "$script_dir/../.." && pwd)"
  fi
}

# loom_tree_kind [ROOT] — echoes exactly one of: maintainer | sanitized | inconsistent
loom_tree_kind() {
  local root
  root="$(_loom_tree_provenance_root "${1:-}")"
  local present=0 absent=0 m
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    if [ -f "$root/$m" ]; then
      present=$((present + 1))
    else
      absent=$((absent + 1))
    fi
  done <<EOF
$LOOM_TREE_PROVENANCE_MARKERS
EOF
  if [ "$absent" -eq 0 ]; then
    echo "maintainer"
  elif [ "$present" -eq 0 ]; then
    echo "sanitized"
  else
    echo "inconsistent"
  fi
}

# loom_require_consistent_tree [ROOT] — prints a loud, actionable error and
# returns 1 when the tree is `inconsistent`; silently returns 0 otherwise
# (maintainer or sanitized). Callers that only need the boolean gate (not the
# kind itself) can call this directly instead of switching on loom_tree_kind.
loom_require_consistent_tree() {
  local root
  root="$(_loom_tree_provenance_root "${1:-}")"
  local kind
  kind="$(loom_tree_kind "$root")"
  if [ "$kind" != "inconsistent" ]; then
    return 0
  fi
  echo "" >&2
  echo "❌ INCONSISTENT TREE PROVENANCE — refusing to guess maintainer vs. sanitized." >&2
  echo "   Some maintainer-only marker files exist under '$root' and some do not:" >&2
  local m
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    if [ -f "$root/$m" ]; then
      echo "     present: $m" >&2
    else
      echo "     ABSENT:  $m" >&2
    fi
  done <<EOF
$LOOM_TREE_PROVENANCE_MARKERS
EOF
  echo "" >&2
  echo "   This is never a skip condition. On a real maintainer (dev-main) tree" >&2
  echo "   ALL of these markers exist; on a real sanitized (promoted/customer) tree" >&2
  echo "   NONE of them do. A mixed result means either the tree is corrupt, or one" >&2
  echo "   marker has drifted out of sync with the strip manifest (see the header of" >&2
  echo "   tests/lib/tree-provenance.sh) — either way it must be fixed, not skipped" >&2
  echo "   around, or every guarded suite would silently downgrade to skip-mode the" >&2
  echo "   next time a single marker file goes missing." >&2
  echo "" >&2
  return 1
}
