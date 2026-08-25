#!/usr/bin/env bash
# lint-backlog.sh — authoring linter for the backlog SOURCES.
#
# Lints what a HUMAN wrote, not what the collector produced. The index
# (.logic-loom/backlog-index.json) is derived and untracked; linting it would be
# linting a mirror. Everything below reads BOTH cross-cutting streams —
# .logic-loom/memory/todos.md (active) and .logic-loom/memory/backlog.md
# (deferred) — and, for the status vocabulary only, features/*/plan.md.
#
# ─────────────────────────────────────────────────────────────────────────────
# TWO FILES, ONE ID SPACE — WHY THIS LINTER SPANS BOTH
# ─────────────────────────────────────────────────────────────────────────────
# todos.md and backlog.md are two streams of one thing: same grammar (specified
# once, in backlog.md), same parser, same ids. An item moves between them by
# cut-and-paste and KEEPS ITS ID, and `blocked_on:` references cross freely — a
# deferred item is routinely blocked on an active decision.
#
# That makes uniqueness a CROSS-FILE property. A linter that checked each file
# alone would pass two files that both minted LOOM-0030, and the author would
# only find out when the collector refused to publish. So the id set, the
# duplicate check and the blocker resolution here are all computed over the
# UNION of both files, and a duplicate finding names the file each occurrence
# came from.
#
# The same reasoning gives this script `--next-id`: the id counter is DERIVED
# (highest id present in either file, plus one) rather than stored in a footer,
# because a stored counter lives in one file and goes silently wrong the moment
# an item is appended to the other. This is the one implementation of that
# derivation.
#
# ─────────────────────────────────────────────────────────────────────────────
# THIS SCRIPT ADVISES THE AUTHOR; THE COLLECTOR REFUSES TO PUBLISH
# ─────────────────────────────────────────────────────────────────────────────
# The split between this and build-backlog-index.sh is deliberate, and the two
# halves have different contracts:
#
#   THIS SCRIPT      is authoring feedback for a human mid-thought. It reports
#                    EVERY defect it finds — including ones nothing downstream
#                    cares about — and exits 0 by default. A linter over a
#                    hand-maintained prose file will eventually disagree with a
#                    human who is right; if that disagreement blocks a commit,
#                    the linter gets disabled and then nothing is checked at all.
#
#   THE COLLECTOR    produces the artifact other things CONSUME, so it FAILS
#                    (exit 3, nothing written, any previous index untouched) on
#                    the narrow set of defects that would make the index
#                    misrepresent its sources: a duplicate id anywhere across all
#                    sources, an unparseable item line below `## Items`, and an
#                    out-of-vocabulary plan task status. A consumer cannot tell a
#                    dropped item from a nonexistent one — so nothing gets
#                    dropped quietly.
#
# Practical consequence: this script is the WIDER net and the SOFTER one. Classes
# 1, 2 and 5 below are also fatal to the collector; 3, 4 and 6 are advisory only
# and never stop an index being published.
#
# ─────────────────────────────────────────────────────────────────────────────
# DEFECT CLASSES
# ─────────────────────────────────────────────────────────────────────────────
#   1. unparseable      a `- [ ]` line below `## Items` that does not match the
#                       item grammar (missing em-dash separator, malformed id,
#                       no `status:` tag). These are items the collector DROPS —
#                       the most dangerous defect, because the line looks like
#                       work but reaches no consumer.
#   2. duplicate-id     the same id minted twice. Ids are immutable and never
#                       reused; a duplicate silently merges two pieces of work.
#   3. prefix-mismatch  an id whose prefix is not the declared `id_prefix` from
#                       .logic-loom/config/project.conf. SKIPPED when the project
#                       is unstamped (`__UNSET__`) or the config is absent —
#                       there is nothing to check against, and a fresh clone must
#                       not be told its backlog is wrong.
#   4. unknown-blocker  `blocked_on:` naming an id that exists in NEITHER stream
#                       (todos.md nor backlog.md). A dangling blocker never
#                       clears. A reference that crosses from one file to the
#                       other is NORMAL and resolves — the id space is shared.
#                       AWARE OF EXTERNAL BLOCKERS: an entry beginning with the
#                       literal `external:` is a free-text reason for a blocker
#                       OUTSIDE the index (a maintainer decision, an action in
#                       another repo) and is NOT checked against the id set —
#                       flagging it would be flagging the feature. The one thing
#                       checked on an external entry is that the reason is not
#                       empty: bare `external:` says "blocked, reason withheld",
#                       which is exactly the state the marker exists to end.
#   5. bad-status       a `status:` value outside the closed vocabulary
#                       (open | in_progress | blocked | done). Also checked for
#                       `status:` in features/*/plan.md, same vocabulary.
#   6. checkbox-mismatch  `- [x]` without `status:done`, or `status:done` without
#                       `- [x]`. The grammar documents this as an AUTHORING lint
#                       and nothing more: the collector reads `status:` and
#                       ignores the box, so this is never an ambiguity — it is a
#                       human-facing file telling a human the wrong thing.
#
# ─────────────────────────────────────────────────────────────────────────────
# WARN BY DEFAULT — exit 0. `--strict` exits 1.
# ─────────────────────────────────────────────────────────────────────────────
# .docs/architecture/project-graph-convention.md names a BLOCKING linter as an
# explicit tripwire, and the sibling lint-graph.sh always exits 0 for that reason.
# A linter over a HAND-MAINTAINED prose file will eventually disagree with a human
# who is right; if that disagreement blocks a commit, the linter gets disabled and
# then nothing is checked at all. So: report loudly, never block.
#
# `--strict` exists for CI, which is a different contract — a pipeline failing is
# a signal to a maintainer, not friction on an author mid-thought.
#
# THE CONTRACT TEST USES BOTH: `--strict` for the per-defect fixtures (a fixture
# built to be broken must prove the linter FIRES, and an exit code is the only
# unambiguous proof), and the DEFAULT mode against the real backlog (which is
# allowed to carry legitimate findings without turning the suite red). Real
# repo content must never gate the test suite.
#
# Usage: lint-backlog.sh [ROOT] [--strict] [--quiet]
#        lint-backlog.sh [ROOT] --next-id      # print the next id to mint, exit 0
# Exit: 0 = no findings, or findings in default mode
#       1 = findings in --strict mode
#       2 = usage error
#
# bash 3.2 safe. Runs no git. Writes nothing.
set -uo pipefail

ROOT=""; STRICT=0; QUIET=0; NEXT_ID=0
while [ $# -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    --next-id) NEXT_ID=1; shift ;;
    --quiet|-q) QUIET=1; shift ;;
    -h|--help) sed -n '2,60p' "$0"; exit 0 ;;
    -*) echo "ERROR: unknown option '$1'" >&2; exit 2 ;;
    *) [ -z "$ROOT" ] && ROOT="$1"; shift ;;
  esac
done
if [ -z "$ROOT" ]; then
  _sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT="$(cd "$_sd/../../.." && pwd)"
fi

FINDINGS=0
say()    { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
finding(){ FINDINGS=$((FINDINGS + 1)); printf '%s: %s\n' "${1}" "${2}" >&2; }

TODOS="${LOOM_TODOS_FILE:-$ROOT/.logic-loom/memory/todos.md}"
BACKLOG="${LOOM_BACKLOG_FILE:-$ROOT/.logic-loom/memory/backlog.md}"
CONF="${LOOM_PROJECT_CONF:-$ROOT/.logic-loom/config/project.conf}"

# Both streams are OPTIONAL and either may be absent (a fresh clone that has not
# adopted the split, or a project that only ever files deferred work). Absent is
# not a finding; absent BOTH is nothing to lint.
SOURCES=""
[ -f "$TODOS" ]   && SOURCES="$SOURCES$TODOS
"
[ -f "$BACKLOG" ] && SOURCES="$SOURCES$BACKLOG
"
if [ -z "$SOURCES" ]; then
  say "backlog lint: no todos.md and no backlog.md under '$ROOT' — nothing to lint (this is normal)."
  exit 0
fi

# ── declared id_prefix (text parse; never sourced) ───────────────────────────
PREFIX=""
if [ -r "$CONF" ]; then
  PREFIX="$(sed 's/[[:space:]]*#.*$//' "$CONF" \
    | grep -E '^[[:space:]]*id_prefix[[:space:]]*=' \
    | head -1 | sed -E 's/^[[:space:]]*id_prefix[[:space:]]*=[[:space:]]*//; s/[[:space:]]*$//')"
fi
[ "$PREFIX" = "__UNSET__" ] && PREFIX=""

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t loomlint)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

# ── pass 1: line-level classification, over BOTH streams ────────────────────
# Emits, tab-separated, with the repo-relative FILE in field 2 so every finding
# below can name where it came from — and so a duplicate id can name BOTH files:
#   BAD    <file> <lineno> <reason> <line>
#   STATUS <file> <lineno> <id> <badvalue>
#   BOX    <file> <lineno> <id> <box> <status>
#   ITEM   <file> <lineno> <id> <status> <blocked_on>
: > "$TMPD/rec.tsv"
while IFS= read -r srcfile; do
  [ -n "$srcfile" ] || continue
  awk -v SRC="${srcfile#$ROOT/}" '
  function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
  # SEP / SEPLEN: the id/title separator " <em dash> ". Its LENGTH is MEASURED,
  # never hardcoded, because awk implementations disagree about the unit. A
  # byte-oriented awk (BSD/onetrue awk, mawk, gawk under LC_ALL=C) reports
  # length(SEP) == 5 (space + 3 UTF-8 bytes + space); gawk in ANY multibyte
  # locale — including LANG=C.UTF-8, the default on GitHub-hosted Linux runners
  # — reports 3, because index()/substr() there count CHARACTERS. A literal
  # `p + 5` overshoots by two characters on such a host and eats the front of
  # every title. The collector (build-backlog-index.sh, parse_item_file) measures
  # the same way for the same reason — fix both or neither.
  BEGIN { ins = 0; fence = 0; SEP = " \342\200\224 "; SEPLEN = length(SEP) }
  {
    line = $0
    if (line ~ /^[[:space:]]*(```|~~~)/) { fence = 1 - fence; next }
    if (fence) next
    if (line ~ /^## /) { ins = (line ~ /^## Items[[:space:]]*$/) ? 1 : 0; next }
    if (!ins) next
    if (line !~ /^- \[[ x]\] /) next

    box  = substr(line, 4, 1)
    rest = substr(line, 7)
    p = index(rest, SEP)                     # " <em dash> "
    if (p == 0) { printf("BAD\t%s\t%d\tno \342\200\224 separator between id and title\t%s\n", SRC, NR, line); next }
    id    = trim(substr(rest, 1, p - 1))
    after = substr(rest, p + SEPLEN)         # past " <em dash> " — see SEPLEN above

    if (id !~ /^[A-Z][A-Z0-9]*-[0-9][0-9][0-9][0-9][0-9]*$/) {
      printf("BAD\t%s\t%d\tmalformed id \x27%s\x27 (want PREFIX-NNNN, 4+ digits)\t%s\n", SRC, NR, id, line); next
    }
    if (match(after, /`status:[A-Za-z_]*`/) == 0) {
      printf("BAD\t%s\t%d\tno `status:` tag\t%s\n", SRC, NR, line); next
    }
    status = substr(after, RSTART + 8, RLENGTH - 9)
    if (status != "open" && status != "in_progress" && status != "blocked" && status != "done") {
      printf("STATUS\t%s\t%d\t%s\t%s\n", SRC, NR, id, status); next
    }
    bo = ""
    if (match(after, /`blocked_on:[^`]*`/) > 0) {
      # Split on comma and TRIM each entry — internal whitespace is preserved
      # because an `external:` entry carries a free-text reason.
      raw = substr(after, RSTART + 12, RLENGTH - 13)
      n = split(raw, ba, ",")
      for (i = 1; i <= n; i++) {
        v = trim(ba[i]); gsub(/\t/, " ", v)
        if (v != "") bo = (bo == "" ? v : bo "," v)
      }
    }
    printf("BOX\t%s\t%d\t%s\t%s\t%s\n", SRC, NR, id, box, status)
    printf("ITEM\t%s\t%d\t%s\t%s\t%s\n", SRC, NR, id, status, bo)
  }
' "$srcfile" >> "$TMPD/rec.tsv"
done <<SRC_EOF
$SOURCES
SRC_EOF

# ── the id set, over BOTH files ──────────────────────────────────────────────
# `ids.txt` is bare ids (blocker resolution); `id-file.tsv` keeps the file each
# came from so a duplicate finding can name both occurrences.
grep "^ITEM	" "$TMPD/rec.tsv" 2>/dev/null | awk -F'\t' '{ print $4 "\t" $2 }' > "$TMPD/id-file.tsv" || : > "$TMPD/id-file.tsv"
cut -f1 "$TMPD/id-file.tsv" > "$TMPD/ids.txt" 2>/dev/null || : > "$TMPD/ids.txt"

# ── --next-id: the DERIVED counter, computed once, here ──────────────────────
# next id = (highest id present in EITHER file) + 1. Compared NUMERICALLY on the
# digits, never lexically, and re-padded to the width it was found at (minimum
# four), so LOOM-0999 -> LOOM-1000 and LOOM-9999 -> LOOM-10000 both come out
# right. The prefix is the declared id_prefix when there is one, else the prefix
# already in use.
#
# THE COUNTER IS NOT STORED ANYWHERE. With two files sharing one id space, a
# written-down "next id" lives in one of them and is silently wrong the moment
# an item is appended to the other. Deriving it removes the thing that could
# drift.
if [ "$NEXT_ID" -eq 1 ]; then
  awk -F'\t' -v DECL="$PREFIX" '
    { id = $1
      pfx = id; sub(/-[0-9]+$/, "", pfx)
      num = id; sub(/^.*-/, "", num)
      w = length(num) + 0
      if (num + 0 > best + 0) { best = num + 0; bestpfx = pfx }
      if (w > width) width = w
    }
    END {
      if (width < 4) width = 4
      p = (DECL != "" ? DECL : (bestpfx != "" ? bestpfx : "ITEM"))
      printf("%s-%0*d\n", p, width, best + 1)
    }' "$TMPD/id-file.tsv"
  exit 0
fi

say "backlog lint: $(printf '%s' "$SOURCES" | sed "s#^$ROOT/##" | tr '\n' ' ')"

# 1. unparseable
while IFS="$(printf '\t')" read -r kind rel lineno reason rest; do
  [ "$kind" = "BAD" ] || continue
  finding "unparseable" "$rel:$lineno — $reason"
done < "$TMPD/rec.tsv"

# 5a. bad status value (todos / backlog)
while IFS="$(printf '\t')" read -r kind rel lineno id bad; do
  [ "$kind" = "STATUS" ] || continue
  finding "bad-status" "$rel:$lineno — $id has status '$bad'; vocabulary is open|in_progress|blocked|done"
done < "$TMPD/rec.tsv"

# 6. checkbox/status mismatch
while IFS="$(printf '\t')" read -r kind rel lineno id box status; do
  [ "$kind" = "BOX" ] || continue
  if [ "$status" = "done" ] && [ "$box" != "x" ]; then
    finding "checkbox-mismatch" "$rel:$lineno — $id is status:done but the box is '[ ]' (want '[x]')"
  elif [ "$status" != "done" ] && [ "$box" = "x" ]; then
    finding "checkbox-mismatch" "$rel:$lineno — $id is '[x]' but status is '$status' (the box is '[x]' if and only if status:done)"
  fi
done < "$TMPD/rec.tsv"

# 2. duplicate ids — ACROSS BOTH STREAMS, not within one file.
# The id space is shared because blocked_on references cross the two files, so
# the same id minted once in todos.md and once in backlog.md is exactly the
# collision this check exists to catch. The finding names every file it was seen
# in; the collector treats the same defect as fatal and refuses to publish.
while IFS= read -r dup; do
  [ -n "$dup" ] || continue
  _in="$(grep "^$dup	" "$TMPD/id-file.tsv" 2>/dev/null | cut -f2 | LC_ALL=C sort -u | tr '\n' ' ')"
  finding "duplicate-id" "'$dup' is minted more than once (in: ${_in% }) — ids are immutable, never reused, and unique across todos.md and backlog.md"
done <<DUP_EOF
$(LC_ALL=C sort "$TMPD/ids.txt" | uniq -d)
DUP_EOF

# 3. prefix mismatch
if [ -n "$PREFIX" ]; then
  while IFS="$(printf '\t')" read -r kind rel lineno id status bo; do
    [ "$kind" = "ITEM" ] || continue
    case "$id" in
      "$PREFIX"-*) ;;
      *) finding "prefix-mismatch" "$rel:$lineno — '$id' does not use the declared id_prefix '$PREFIX'" ;;
    esac
  done < "$TMPD/rec.tsv"
else
  say "  (prefix-mismatch skipped: no stamped id_prefix in ${CONF#$ROOT/})"
fi

# 4. blocked_on referencing an unknown id (external: entries are exempt)
#
# An entry is EITHER an id reference — which must resolve against the id set in
# this file — OR an external blocker: the literal prefix `external:` plus a
# free-text reason for something outside the index. Checking an external entry
# against the id set would guarantee a false positive on every correctly authored
# one, so the prefix is tested first and short-circuits.
while IFS="$(printf '\t')" read -r kind rel lineno id status bo; do
  [ "$kind" = "ITEM" ] || continue
  [ -n "$bo" ] || continue
  oldifs="$IFS"; IFS=,
  for ref in $bo; do
    IFS="$oldifs"
    [ -n "$ref" ] || continue
    case "$ref" in
      external:*)
        reason="${ref#external:}"
        reason="$(printf '%s' "$reason" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        [ -n "$reason" ] || finding "unknown-blocker" \
          "$rel:$lineno — $id has a bare 'external:' blocker with no reason; state what it is blocked on outside this index"
        ;;
      *)
        grep -qxF "$ref" "$TMPD/ids.txt" || \
          finding "unknown-blocker" "$rel:$lineno — $id is blocked_on '$ref', which is not an id in todos.md or backlog.md (an out-of-index blocker is written 'external:<reason>')"
        ;;
    esac
    IFS=,
  done
  IFS="$oldifs"
done < "$TMPD/rec.tsv"

# ── plan.md status vocabulary ────────────────────────────────────────────────
# Same closed vocabulary, different file. Only the vocabulary is checked here —
# the plan DAG has its own structural validator territory (freeze/ownership).
if [ -d "$ROOT/features" ]; then
  while IFS= read -r pf; do
    [ -n "$pf" ] || continue
    prel="${pf#$ROOT/}"
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      pl="${hit%%:*}"; pv="${hit#*:}"
      finding "bad-status" "$prel:$pl — task status '$pv'; vocabulary is open|in_progress|blocked|done"
    done <<EOF2
$(awk '
  BEGIN { fm = 0 }
  { if (NR == 1 && $0 == "---") { fm = 1; next }
    if (fm == 0) next
    if ($0 == "---") exit
    line = $0; sub(/[[:space:]]+#.*$/, "", line)
    if (line ~ /^[[:space:]]*status:[[:space:]]*/) {
      v = line; sub(/^[[:space:]]*status:[[:space:]]*/, "", v)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      gsub(/^"|"$|^\x27|\x27$/, "", v)
      if (v != "" && v != "open" && v != "in_progress" && v != "blocked" && v != "done")
        printf("%d:%s\n", NR, v)
    } }' "$pf")
EOF2
  done <<EOF3
$(find "$ROOT/features" -mindepth 2 -maxdepth 2 -name plan.md -type f 2>/dev/null | LC_ALL=C sort)
EOF3
fi

# ── report ───────────────────────────────────────────────────────────────────
ITEM_N="$(grep -c "^ITEM	" "$TMPD/rec.tsv" 2>/dev/null)" || ITEM_N=0
say ""
if [ "$FINDINGS" -eq 0 ]; then
  say "backlog lint: $ITEM_N item(s) parsed, 0 findings."
  exit 0
fi
say "backlog lint: $ITEM_N item(s) parsed, $FINDINGS finding(s)."
if [ "$STRICT" -eq 1 ]; then
  say "backlog lint: --strict — exiting 1."
  exit 1
fi
say "backlog lint: warn-only (default). Re-run with --strict to make findings fatal."
exit 0
