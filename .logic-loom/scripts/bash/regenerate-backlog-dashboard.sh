#!/usr/bin/env bash
# regenerate-backlog-dashboard.sh — SessionStart hook: keep the backlog
# dashboard's markdown half current without dirtying the tree on every session.
#
# LOOM-0049 §3.5. Runs the two generators, and writes the regenerated page over
# the committed one ONLY IF the normalised bytes actually differ — an unchanged
# backlog therefore produces NO diff, session after session, and a genuinely
# changed one produces a real update with a real generated_at stamp.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHY "SKIP THE WRITE ON NO CHANGE" AND NOT "PIN SOURCE_DATE_EPOCH"
# ─────────────────────────────────────────────────────────────────────────────
# Both options were on the table (see check-generated-freshness.sh, which
# documents the same choice for its own comparison). Pinning the epoch here
# would make every regeneration byte-identical to the LAST one only if nothing
# changed — same outcome — but it would also freeze `generated_at` at some
# arbitrary fixed instant forever, so the one honest signal of "when was this
# last actually current" would read a lie on every real update too. Skipping
# the write when the NORMALISED content is unchanged keeps `generated_at`
# meaningful on a real change and produces zero diff on no change — strictly
# better for a file a human reads. Same normalisation function as the freshness
# gate (replace every ISO-8601 UTC stamp with a placeholder before diffing),
# reproduced here rather than sourced, because the gate's function is not
# exposed as a library and duplicating four lines of sed is cheaper than adding
# a new shared-lib dependency for one caller.
#
# ─────────────────────────────────────────────────────────────────────────────
# GITHUB REMOTE DERIVATION — the ONE place this whole feature runs git
# ─────────────────────────────────────────────────────────────────────────────
# build-backlog-index.sh and build-backlog-dashboard.sh both declare "runs NO
# git, ever" as a hard boundary (and test_backlog_dashboard.sh proves it with a
# PATH-shimmed git that fails loudly if called). THIS HOOK RUNS NO GIT EITHER.
#
# It briefly did. The first version resolved owner/repo from `git remote get-url
# origin` and passed it as --repo, on the reasoning that a wrapper may do what
# the wrapped scripts may not. That reasoning was fine and the conclusion was
# still wrong: the freshness gate regenerates WITHOUT the override, so the
# committed artifact carried the real repo while the gate's copy carried null,
# and the tracked file was permanently STALE. See the block above `--out`.
#
# ─────────────────────────────────────────────────────────────────────────────
# MUST NOT FAIL THE SESSION — same spirit as check-brain-signals.sh
# ─────────────────────────────────────────────────────────────────────────────
# Every failure path here — jq missing, no index sources, an unwritable output,
# not a git repo — is a silent no-op. This hook exits 0 unconditionally. A
# SessionStart hook that can redden a session over a missing optional tool is
# a worse failure mode than the dashboard simply staying as it was.
#
# bash 3.2 safe: no associative arrays, no mapfile, no [[ -v ]], no ${var,,}.
set -uo pipefail

# Belt-and-braces: force exit 0 no matter what happens below, even a failure
# mode this script did not anticipate. The trap on TMPD (set once it exists)
# REPLACES this one — bash traps do not stack — and does the same thing plus
# cleanup, so the guarantee holds continuously either way.
trap 'exit 0' EXIT

ROOT=""
if [ -z "${1:-}" ]; then
  _sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || exit 0
  ROOT="$(cd "$_sd/../../.." 2>/dev/null && pwd)" || exit 0   # scripts/bash -> .logic-loom -> repo root
else
  ROOT="$1"
fi
[ -d "$ROOT" ] || exit 0

SCRIPTS="$ROOT/.logic-loom/scripts/bash"
COLLECTOR="$SCRIPTS/build-backlog-index.sh"
RENDERER="$SCRIPTS/build-backlog-dashboard.sh"
[ -f "$COLLECTOR" ] || exit 0
[ -f "$RENDERER" ]  || exit 0

command -v jq >/dev/null 2>&1 || exit 0

OUT_REL="artifacts/backlog-dashboard.html"
OUT="$ROOT/$OUT_REL"

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t loomregen)" || exit 0
trap 'rm -rf "$TMPD"; exit 0' EXIT

# ── owner/repo comes from project.conf, and ONLY from project.conf ─────────
# An earlier version of this hook derived it from `git remote get-url origin`
# and passed it as --repo. That was wrong, and the freshness gate proved it:
# the gate regenerates WITHOUT the override, so it produced `GH_REPO = null`
# while the committed file carried the real value, and the tracked artifact was
# permanently STALE. Verified — the gate failed on exactly that line.
#
# `check-generated-freshness.sh` is fail-closed on a tracked artifact, so every
# input to that artifact must be deterministic and reachable by anyone who
# regenerates it. A git remote is neither: it differs between a fork, a mirror,
# and a clone with a renamed origin, and it is not what the gate reads.
# `project.conf`'s optional `repo = <owner>/<repo>` key IS deterministic, is what
# the collector already reads by default, and is what `/initialize-project` sets.
#
# So this hook passes no override at all. It regenerates; the collector resolves
# the repo the same way it does for everyone else. An adopter who has not
# declared `repo` gets a panel that says so, which is honest and is fixed by one
# line of config rather than by making a tracked file depend on a remote.

# ── build into scratch, never touching the real output path directly ───────
IDX="$TMPD/index.json"
bash "$COLLECTOR" "$ROOT" --out "$IDX" >/dev/null 2>"$TMPD/collector.err" || exit 0
[ -s "$IDX" ] || exit 0

FRESH="$TMPD/fresh.html"
bash "$RENDERER" "$ROOT" --index "$IDX" --out "$FRESH" >/dev/null 2>"$TMPD/renderer.err" || exit 0
[ -s "$FRESH" ] || exit 0

# ── write only if it actually changed, modulo the generated_at stamp ────────
normalise_ts() {
  sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z/<TIMESTAMP>/g' \
    < "$1" > "$2" 2>/dev/null
}

if [ -f "$OUT" ]; then
  normalise_ts "$FRESH" "$TMPD/fresh.norm"
  normalise_ts "$OUT"   "$TMPD/committed.norm"
  if diff -q "$TMPD/committed.norm" "$TMPD/fresh.norm" >/dev/null 2>&1; then
    exit 0   # unchanged — do not touch the file, do not dirty the tree
  fi
fi

mkdir -p "$(dirname "$OUT")" 2>/dev/null || exit 0
cp "$FRESH" "$OUT" 2>/dev/null || exit 0
exit 0
