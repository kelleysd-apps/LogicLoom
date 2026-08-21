#!/usr/bin/env bash
# check-generated-freshness.sh — FAIL-CLOSED staleness gate for the repo's
# git-TRACKED generated artifacts.
#
# Regenerates each tracked derived artifact into a scratch directory and fails if
# the committed copy differs. Writes NOTHING into the repo. Runs NO git that
# mutates anything. Exit 0 = every tracked artifact is current.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHY THIS EXISTS
# ─────────────────────────────────────────────────────────────────────────────
# A tracked derived artifact diverges from its sources the moment someone edits a
# source without regenerating. This repo has been bitten by that class three
# times (dead scrub rules, four orphaned test suites, a manifest advertising a
# stripped command). Two of those three had a WARN-ONLY lint pointed at them and
# still shipped — a warning is a suggestion, and drift accumulates behind it.
# The only mechanism that holds is regenerate-and-diff, failing the build.
#
# So: tracking a derived artifact is allowed here ONLY while this gate covers it.
# If you add a tracked generated file, add it to this script in the same change.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHY A SEPARATE SCRIPT AND NOT A `--check` MODE ON EACH GENERATOR
# ─────────────────────────────────────────────────────────────────────────────
# Both generators are FAIL-OPEN by explicit contract — build-backlog-dashboard.sh
# documents "a viewer generator must not gate a workflow" and exits 0 on a
# missing index; build-graph-bridge.sh warns and exits 0 with no jq. A `--check`
# mode would put fail-CLOSED behaviour inside a fail-OPEN tool, and the next
# reader could not tell from the exit code which contract was in force. It would
# also duplicate the normalisation logic below in two places, in two languages of
# artifact (HTML, JSONL), with no shared test.
#
# One gate, one command for a contributor, one CI step, one place to add the
# next artifact.
#
# ─────────────────────────────────────────────────────────────────────────────
# THE TIMESTAMP PROBLEM, AND WHAT THIS GATE DOES ABOUT IT
# ─────────────────────────────────────────────────────────────────────────────
# The dashboard carries a `generated_at` ISO-8601 UTC stamp. It is not minted by
# the dashboard generator — it is CARRIED FROM THE INDEX, which the gate must
# also regenerate, so the regenerated side's stamp is "now" while the committed
# side's stamp is "whenever it was last regenerated". A naive byte-diff would
# therefore fail on EVERY run, always, for a reason that has nothing to do with
# staleness. That is the false-failure this gate has to design out.
#
# Three options were available:
#
#   (a) FREEZE the regenerated side only (SOURCE_DATE_EPOCH, which
#       build-backlog-index.sh already honours). Insufficient alone: the
#       COMMITTED file was produced by a normal run and carries a real stamp, so
#       the two sides still differ. Freezing fixes reproducibility of the
#       regenerated side; it does not make the pair comparable.
#   (b) EXCLUDE the generated_at LINE. Rejected: the stamp appears in the page
#       more than once (the header fact line AND the inlined index snapshot), the
#       page is not line-oriented HTML, and a line-based exclusion silently stops
#       matching the moment the emitter's formatting changes — a gate that
#       quietly compares less than it claims to.
#   (c) NORMALISE the FIELD on BOTH sides — replace every ISO-8601 UTC timestamp
#       with a fixed placeholder in the regenerated copy and in a scratch copy of
#       the committed file, then diff. Location-independent, format-independent,
#       and symmetric.
#
# This gate does (c), and ALSO (a) — belt and braces, for different reasons:
#   * (c) is what makes the comparison correct. It is applied IDENTICALLY to both
#     sides, so the only way the diff can fail is a genuine content difference.
#   * (a) is what makes the scratch index reproducible for a human debugging a
#     failure: two runs of the gate produce byte-identical scratch files, so
#     `diff` output is about the artifact and not about the clock.
#
# Known and accepted narrowing: a backlog item whose TITLE literally contains an
# ISO-8601 UTC timestamp would have that substring normalised too — on both
# sides, so it cannot cause a FALSE FAILURE; it can only make the gate blind to a
# change confined to that one substring. That is a strictly smaller blind spot
# than option (b), which is blind to whole lines.
#
# graph-bridge.jsonl needs none of this: it has no timestamp and no per-run
# variable at all, so it is compared BYTE-FOR-BYTE with no normalisation.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHAT IS CHECKED
# ─────────────────────────────────────────────────────────────────────────────
#   artifacts/backlog-dashboard.html    (build-backlog-index.sh -> build-backlog-dashboard.sh)
#   .logic-loom/graph/graph-bridge.jsonl (build-graph-bridge.sh)
#
# NOT checked, on purpose: .logic-loom/backlog-index.json. It is gitignored — a
# machine intermediate with no standalone reader. There is no committed copy to
# be stale, so there is nothing to gate.
#
# Usage:
#   check-generated-freshness.sh [ROOT] [--only dashboard|graph]
# Exit: 0 fresh · 1 stale (or a required generator/tool missing) · 2 usage error.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

ROOT=""; ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --only)   ONLY="${2:-}"; shift 2 || true ;;
    --only=*) ONLY="${1#--only=}"; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    -*) echo "usage: $(basename "$0") [ROOT] [--only dashboard|graph]" >&2; exit 2 ;;
    *)  [ -z "$ROOT" ] && ROOT="$1"; shift ;;
  esac
done
case "$ONLY" in ""|dashboard|graph) ;; *)
  echo "usage: --only takes 'dashboard' or 'graph'" >&2; exit 2 ;;
esac

if [ -z "$ROOT" ]; then
  _sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT="$(cd "$_sd/../../.." && pwd)"   # scripts/bash -> .logic-loom -> repo root
fi
[ -d "$ROOT" ] || { echo "ERROR: root '$ROOT' is not a directory" >&2; exit 2; }

SCRIPTS="$ROOT/.logic-loom/scripts/bash"
TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t loomfresh)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

FAILED=0

# normalise_ts <in> <out> — replace every ISO-8601 UTC stamp with a placeholder.
# Applied to BOTH sides of the dashboard comparison; see the header.
normalise_ts() {
  sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z/<TIMESTAMP>/g' \
    < "$1" > "$2"
}

fail_header() {
  echo ""
  echo "❌ STALE: $1"
  echo ""
}

# ── 1. artifacts/backlog-dashboard.html ──────────────────────────────────────
if [ "$ONLY" = "" ] || [ "$ONLY" = "dashboard" ]; then
  DASH_REL="artifacts/backlog-dashboard.html"
  DASH="$ROOT/$DASH_REL"
  COLLECTOR="$SCRIPTS/build-backlog-index.sh"
  RENDERER="$SCRIPTS/build-backlog-dashboard.sh"

  if [ ! -f "$COLLECTOR" ] || [ ! -f "$RENDERER" ]; then
    fail_header "$DASH_REL — its generator is missing"
    echo "  Expected both of:"
    echo "    $COLLECTOR"
    echo "    $RENDERER"
    FAILED=1
  elif [ ! -f "$DASH" ]; then
    fail_header "$DASH_REL — the tracked artifact is MISSING from the tree"
    echo "  This file is tracked and must be regenerated and committed. Run:"
    echo ""
    echo "    ./.logic-loom/scripts/bash/build-backlog-index.sh"
    echo "    ./.logic-loom/scripts/bash/build-backlog-dashboard.sh"
    echo ""
    FAILED=1
  else
    # SOURCE_DATE_EPOCH freezes the regenerated stamp -> reproducible scratch.
    SOURCE_DATE_EPOCH=0 bash "$COLLECTOR" "$ROOT" --out "$TMPD/index.json" \
      >/dev/null 2>"$TMPD/collector.err"
    crc=$?
    if [ "$crc" -ne 0 ] || [ ! -s "$TMPD/index.json" ]; then
      fail_header "$DASH_REL — the collector refused to build an index (exit $crc)"
      sed 's/^/  /' "$TMPD/collector.err" 2>/dev/null | head -30
      echo ""
      echo "  Fix the backlog sources first, then regenerate:"
      echo ""
      echo "    ./.logic-loom/scripts/bash/lint-backlog.sh"
      echo "    ./.logic-loom/scripts/bash/build-backlog-index.sh"
      echo "    ./.logic-loom/scripts/bash/build-backlog-dashboard.sh"
      echo ""
      FAILED=1
    else
      bash "$RENDERER" "$ROOT" --index "$TMPD/index.json" --out "$TMPD/dash.html" \
        >/dev/null 2>&1
      if [ ! -s "$TMPD/dash.html" ]; then
        fail_header "$DASH_REL — the renderer produced no page"
        FAILED=1
      else
        normalise_ts "$TMPD/dash.html" "$TMPD/fresh.norm"
        normalise_ts "$DASH"           "$TMPD/committed.norm"
        if diff -q "$TMPD/committed.norm" "$TMPD/fresh.norm" >/dev/null 2>&1; then
          echo "✅ fresh: $DASH_REL"
        else
          fail_header "$DASH_REL differs from what its sources produce"
          echo "  The committed page no longer matches .logic-loom/memory/backlog.md,"
          echo "  features/*/plan.md and specs/*/tasks.md. Regenerate and commit it:"
          echo ""
          echo "    ./.logic-loom/scripts/bash/build-backlog-index.sh"
          echo "    ./.logic-loom/scripts/bash/build-backlog-dashboard.sh"
          echo ""
          echo "  (The index is gitignored; only the dashboard is committed.)"
          echo "  First differing lines (committed < , regenerated > ), timestamps normalised:"
          diff "$TMPD/committed.norm" "$TMPD/fresh.norm" 2>/dev/null | head -20 | sed 's/^/    /'
          echo ""
          FAILED=1
        fi
      fi
    fi
  fi
fi

# ── 2. .logic-loom/graph/graph-bridge.jsonl ──────────────────────────────────
# No timestamp, no per-run variable -> byte-for-byte, no normalisation.
#
# One residual, recorded so it is not rediscovered as a mystery: the generator
# emits a `mentions` edge only for a backtick-quoted path that EXISTS on disk, so
# its output depends on the working tree, not only on tracked content. A file
# that is present locally but absent from a CI checkout (i.e. gitignored) would
# make the two disagree. Audited at the time this gate was added: the only such
# node was artifacts/backlog-dashboard.html, which this same change made tracked,
# so the set is now empty. If this check ever fails ONLY in CI, that is the first
# thing to look for.
if [ "$ONLY" = "" ] || [ "$ONLY" = "graph" ]; then
  GB_REL=".logic-loom/graph/graph-bridge.jsonl"
  GB="$ROOT/$GB_REL"
  BUILDER="$SCRIPTS/build-graph-bridge.sh"

  if [ ! -f "$BUILDER" ]; then
    fail_header "$GB_REL — build-graph-bridge.sh is missing"
    FAILED=1
  elif [ ! -f "$GB" ]; then
    fail_header "$GB_REL — the tracked artifact is MISSING from the tree"
    echo "  Regenerate and commit it:"
    echo ""
    echo "    ./.logic-loom/scripts/bash/build-graph-bridge.sh --out .logic-loom/graph/graph-bridge.jsonl"
    echo ""
    FAILED=1
  else
    bash "$BUILDER" "$ROOT" --out "$TMPD/graph-bridge.jsonl" >/dev/null 2>&1
    if [ ! -f "$TMPD/graph-bridge.jsonl" ]; then
      fail_header "$GB_REL — the builder produced nothing"
      FAILED=1
    elif diff -q "$GB" "$TMPD/graph-bridge.jsonl" >/dev/null 2>&1; then
      echo "✅ fresh: $GB_REL"
    else
      fail_header "$GB_REL differs from what the markdown corpus produces"
      echo "  A doc was added, moved, renamed or re-linked without rebuilding the"
      echo "  bridge. Regenerate and commit it:"
      echo ""
      echo "    ./.logic-loom/scripts/bash/build-graph-bridge.sh --out .logic-loom/graph/graph-bridge.jsonl"
      echo ""
      echo "  First differing lines (committed < , regenerated > ):"
      diff "$GB" "$TMPD/graph-bridge.jsonl" 2>/dev/null | head -20 | sed 's/^/    /'
      echo ""
      FAILED=1
    fi
  fi
fi

if [ "$FAILED" -ne 0 ]; then
  echo "Generated-artifact freshness check FAILED."
  echo "These files are tracked BECAUSE this gate keeps them honest — regenerate,"
  echo "then commit the result alongside the source change that caused the drift."
  exit 1
fi

echo "Generated-artifact freshness check passed."
exit 0
