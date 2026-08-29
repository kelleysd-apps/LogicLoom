#!/usr/bin/env bash
# build-graph-bridge.sh — deterministic CODE↔DOCS bridge generator (Phase 1).
# Harvests edges already present in the markdown corpus and emits graph-bridge.jsonl
# (Anthropic memory-server shape) to stdout. Zero-LLM, rg+jq only.
#
# Usage:
#   build-graph-bridge.sh [CORPUS_ROOT] [--out FILE]
#     CORPUS_ROOT  optional repo root (default: repo root resolved from script location)
#     --out FILE   also write JSONL to FILE (dir created); still echoed to stdout
#
# Exit: 0 output written (an EMPTY file when the tree genuinely has no corpus —
#         announced on stderr, never silent) · 4 unusable environment (no jq, or
#         CORPUS_ROOT is not a directory) · 5 a corpus was found but produced zero
#         lines, which is impossible from content alone · 6 the output file could
#         not be written · any other non-zero: an unexpected failure, reported on
#         stderr by the `on_err` trap with the failing line, command and toolchain.
#       It NEVER exits 0 without either writing --out or saying why on stderr.
#
# Schema (one JSON object per line):
#   entity   {"type":"entity","name":"<repo-rel-path>","entityType":"note"|"code-path","observations":["title"]}
#   relation {"type":"relation","from":"<id>","to":"<id>","relationType":"links-to"|"mentions"|"covers"|"decided-by"}
# Node ids are repo-relative paths. See features/code-knowledge-graph/exploration/project-graph-design.md §3.3.
#
# ─────────────────────────────────────────────────────────────────────────────
# SILENCE IS A DEFECT — WHY THIS SCRIPT SHOUTS
# ─────────────────────────────────────────────────────────────────────────────
# This builder used to be able to die mid-corpus under `set -e` and say NOTHING:
# no message, no output file, just a non-zero exit that its only caller
# (check-generated-freshness.sh) threw away. On CI that surfaced as the gate
# GUESSING — "the builder produced nothing" — which is a symptom, not a cause,
# and named neither the failing command nor the line.
#
# Two rules now hold:
#   1. Every abnormal termination is REPORTED on stderr with the failing line,
#      the failing command, its exit status, and the toolchain in use (the
#      `on_err` trap below). A crash can no longer be silent.
#   2. "No output" is never left for a downstream caller to infer. See
#      "EMPTY OUTPUT" at the foot of this file for which empty is legitimate.
#
# ─────────────────────────────────────────────────────────────────────────────
# LC_ALL=C IS PINNED, DELIBERATELY
# ─────────────────────────────────────────────────────────────────────────────
# This artifact is committed and byte-compared by a fail-closed gate, so the
# SAME corpus must produce the SAME bytes on a developer's macOS/BSD toolchain
# and on CI's GNU/Linux one. Locale is the largest source of disagreement
# between them: `[A-Za-z0-9]` and `[[:space:]]` are locale-defined ranges (GNU
# grep in a UTF-8 locale matches characters BSD grep does not), `sort` collation
# is locale-defined, and GNU grep switches a file with locale-invalid bytes into
# binary mode where `-o` prints nothing at all. Pinning LC_ALL=C makes every
# extractor byte-oriented on both platforms, which is the only way the byte
# comparison downstream can mean anything. Verified output-neutral on this
# corpus (identical under C, en_US.UTF-8 and C.UTF-8).
set -Eeuo pipefail
export LC_ALL=C LANG=C

# Stage marker, so a crash report says WHAT the builder was doing, not only where.
STAGE="startup"

on_err() { # $1 = line number of the failing command
  _rc=$?
  {
    echo "ERROR: build-graph-bridge.sh FAILED — exit $_rc at line ${1:-?} (stage: $STAGE)"
    echo "  failing command: ${BASH_COMMAND:-?}"
    echo "  bash=${BASH_VERSION:-?} awk=$(command -v awk 2>/dev/null || echo MISSING)" \
         "grep=$(command -v grep 2>/dev/null || echo MISSING)" \
         "sed=$(command -v sed 2>/dev/null || echo MISSING)" \
         "jq=$(command -v jq 2>/dev/null || echo MISSING)" \
         "python3=$(command -v python3 2>/dev/null || echo MISSING)" \
         "rg_used=${HAVE_RG:-?} LC_ALL=${LC_ALL:-unset}"
    echo "  NO OUTPUT WAS WRITTEN. This is a BUILDER failure, not a stale artifact."
  } >&2
  exit "$_rc"
}
trap 'on_err $LINENO' ERR

# --- arg parse (fail-open) ---------------------------------------------------
ROOT=""; OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="${2:-}"; shift 2 || true ;;
    --out=*) OUT="${1#--out=}"; shift ;;
    *) [ -z "$ROOT" ] && ROOT="$1"; shift ;;
  esac
done
if [ -z "$ROOT" ]; then
  _sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT="$(cd "$_sd/../../.." && pwd)"   # scripts/bash -> .logic-loom -> repo root
fi
# Normalise away trailing slashes: every path below is built as "$ROOT/x" and the
# repo-relative ids are made by stripping "$ROOT/". A caller-supplied "repo/"
# would otherwise yield "repo//x" and leave the ids absolute.
while [ "${ROOT%/}" != "$ROOT" ] && [ "$ROOT" != "/" ]; do ROOT="${ROOT%/}"; done
STAGE="preflight"
# A BROKEN TOOLCHAIN IS NOT AN EMPTY CORPUS. Both of the next two used to warn
# and `exit 0` with no file — indistinguishable, to any caller, from "there was
# nothing to index", which is precisely how a CI failure got reported as a stale
# artifact. jq is not optional: every line of output is minted by it, so without
# it this builder cannot produce a correct empty result either — it can only
# produce no result. Say so, and exit non-zero.
command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq not found on PATH — build-graph-bridge.sh cannot emit anything." >&2
  echo "  Every output line is minted by jq; there is no degraded mode." >&2
  echo "  Install jq (macOS: brew install jq · Debian/Ubuntu: apt-get install jq)." >&2
  exit 4; }
[ -d "$ROOT" ] || {
  echo "ERROR: corpus root '$ROOT' is not a directory — nothing can be harvested." >&2
  echo "  Usage: build-graph-bridge.sh [CORPUS_ROOT] [--out FILE]" >&2
  exit 4; }
command -v python3 >/dev/null 2>&1 || echo "WARN: python3 not found; relative link/covers edges will be skipped (path resolution degraded)" >&2

# Portable extractor: use a REAL rg binary when one is on PATH; otherwise grep -oE.
# Both take an ERE and a file, printing each match on its own line (no capture magic;
# capture stripping is done by the caller with sed for grep/rg parity).
HAVE_RG=0
if command -v rg >/dev/null 2>&1 && [ -z "$(type -t rg 2>/dev/null | grep function)" ]; then HAVE_RG=1; fi
# `-a` / `--text` on BOTH branches: GNU grep silently switches a file it deems
# binary into a mode where `-o` prints NOTHING (BSD grep does not), so without it
# one stray byte would drop every edge in that file on CI only, and the two
# platforms would disagree on the committed bytes. LC_ALL=C (pinned above) plus
# -a makes the extractors byte-oriented and identical on both.
xo() { # $1=ERE  $2=file  -> matched substrings, one per line
  if [ "$HAVE_RG" = 1 ]; then rg --no-config -a -oN -e "$1" "$2" 2>/dev/null || true
  else grep -a -oE "$1" "$2" 2>/dev/null || true; fi
}
xheading() { # first markdown H1 of a file, heading text only
  # `|| true` on both branches: no H1 is normal, and with `pipefail` a no-match
  # grep/rg (exit 1) would otherwise make this function a landmine for any future
  # caller that forgets to guard it.
  if [ "$HAVE_RG" = 1 ]; then rg --no-config -a -m1 -oN -e '^#[[:space:]].+' "$1" 2>/dev/null | sed 's/^#[[:space:]]*//' || true
  else grep -a -m1 -oE '^#[[:space:]].+' "$1" 2>/dev/null | sed 's/^#[[:space:]]*//' || true; fi
}

# --- collect corpus notes (fail-open on missing dirs) ------------------------
STAGE="collecting corpus"
NOTES="$(mktemp)"; trap 'rm -f "$NOTES"' EXIT
{
  for d in .docs features specs; do
    [ -d "$ROOT/$d" ] && find "$ROOT/$d" -type f -name '*.md' 2>/dev/null
  done
  for r in README.md CLAUDE.md AGENTS.md START_HERE.md VISION.md; do
    [ -f "$ROOT/$r" ] && printf '%s\n' "$ROOT/$r"
  done
  true   # ensure the group exits 0 even if the last [ -f ] test failed (pipefail)
} | while IFS= read -r _p; do printf '%s\n' "${_p#"$ROOT"/}"; done \
  | grep -vE '^(\.docs/architecture/project-graph-convention\.md$|features/code-knowledge-graph/)' \
  | LC_ALL=C sort -u > "$NOTES" || true   # exclude the graph's own meta-docs — their link/wikilink EXAMPLES are illustrative, not real edges
# The absolute-prefix strip above is a LITERAL prefix removal, not `sed
# "s#^$ROOT/##"`. $ROOT is a filesystem path being interpolated into a regex
# there: a repo checked out under a directory containing `.`, `#`, `*`, `[` or
# `\` (a worktree named `v6.5.0`, say) either matched too much or broke the
# expression, and the corpus quietly came out wrong. Parameter expansion has no
# such reading of its argument.

# How many corpus notes exist is the fact that decides, at the foot of this file,
# whether "no output" is legitimate or a bug. Captured here, at the source.
NOTE_COUNT="$(LC_ALL=C awk 'END{print NR+0}' "$NOTES" 2>/dev/null || echo 0)"

# helper: emit an entity line via jq (safe quoting)
emit_entity() { # $1=name $2=entityType $3=observation
  jq -cn --arg n "$1" --arg t "$2" --arg o "$3" \
    '{type:"entity",name:$n,entityType:$t,observations:[$o]}'
}
emit_rel() { # $1=from $2=to $3=relationType
  jq -cn --arg f "$1" --arg t "$2" --arg r "$3" \
    '{type:"relation",from:$f,to:$t,relationType:$r}'
}
# The path-normalising program, held in a variable and fed to `python3 -c`.
#
# IT USED TO BE A HEREDOC INSIDE THE COMMAND SUBSTITUTION IN resolve(), AND THAT
# IS WHAT BROKE CI. The construct was:
#
#     clean="$(cd "$ROOT" && python3 - "$clean" <<'PY' 2>/dev/null || true
#     ...program...
#     PY
#     )"
#
# bash 3.2 parses a command substitution lazily, at EXPANSION time, with a parser
# that accepts a `|| true` sitting between the `<<'PY'` operator and the heredoc
# body. bash 5.2 (ubuntu-latest ships 5.2.21) rewrote that: a command
# substitution is parsed as a complete unit, the heredoc is consumed where it is
# introduced, and the orphaned `|| true)` is then a hard
#     syntax error near unexpected token `||'
# reported AT EXPANSION TIME — so resolve() returned 1, `set -e` killed the
# builder, and the whole thing surfaced only as an empty output file.
#
# Three properties made it survive every check we had:
#   * `bash -n` is CLEAN on 3.2 AND on 5.2 — a syntax-only pass does not parse
#     the body of a command substitution, so no static check could see it. The
#     bash 3.2 floor suite could not have caught it either: this is the mirror
#     case, a construct 3.2 accepts and 5.2 rejects.
#   * The macOS dev box is bash 3.2.57, where it genuinely works.
#   * resolve() is only reached by a note containing a markdown `.md` link, and
#     the first such note is the 26th in sort order — so 25 files processed
#     cleanly before the first failure, which is why the crash looked data-shaped.
#
# The fix is not to move the `|| true`. It is to have NO HEREDOC INSIDE A COMMAND
# SUBSTITUTION at all: that pairing is the fragile thing, and `python3 -c` with
# the program in a variable is immune to how any bash parses it.
PY_NORMPATH='import os,sys
p=os.path.normpath(sys.argv[1])
print("" if p.startswith("..") or os.path.isabs(p) else p)'

# resolve a link/path relative to a note's dir, canonicalize .. , return repo-rel or empty
resolve() { # $1=note-repo-rel  $2=raw-target
  local base_dir tgt clean
  base_dir="$(dirname "$1")"; tgt="$2"
  case "$tgt" in /*) clean="${tgt#/}" ;; *) clean="$base_dir/$tgt" ;; esac
  # normalize with python (portable, no realpath dependency); must stay inside repo
  clean="$(cd "$ROOT" 2>/dev/null && python3 -c "$PY_NORMPATH" "$clean" 2>/dev/null || true)"
  printf '%s' "$clean"
}

ENT="$(mktemp)"; REL="$(mktemp)"; trap 'rm -f "$NOTES" "$ENT" "$REL"' EXIT

# --- pass 1: every note is a note-entity (title = first heading or basename) --
STAGE="pass 1 (note entities)"
while IFS= read -r note; do
  [ -n "$note" ] || continue
  STAGE="pass 1 (note entities) — $note"
  title="$(xheading "$ROOT/$note" || true)"
  [ -n "$title" ] || title="${note##*/}"
  emit_entity "$note" "note" "$title" >> "$ENT"
done < "$NOTES"

# a note exists on disk? (used to distinguish links-to target vs dangling)
# `--` end-of-options: the argument is harvested from document text, and a target
# beginning with `-` would otherwise be read as a grep option (GNU grep exits 2
# with a usage error; BSD grep behaves differently again).
is_note() { grep -qxF -- "$1" "$NOTES"; }

# strip fenced code blocks (``` … ```) so code-sample paths don't become edges
NC="$(mktemp)"; trap 'rm -f "$NOTES" "$ENT" "$REL" "$NC"' EXIT
strip_fences() { awk '/^[[:space:]]*(```|~~~)/{f=!f;next} !f{print}' "$1" 2>/dev/null; }

# --- pass 2: harvest edges per note -----------------------------------------
STAGE="pass 2 (edge harvest)"
while IFS= read -r note; do
  [ -n "$note" ] || continue
  # Per-note stage marker: a crash report then names the FILE that broke the
  # harvest, which is the single most useful fact when the failure is a corpus
  # datum a toolchain cannot chew (the whole class this hardening came from).
  STAGE="pass 2 (edge harvest) — $note"
  f="$ROOT/$note"
  strip_fences "$f" > "$NC"; f="$NC"   # harvest note body from de-fenced copy

  # (a) links-to  — markdown [text](relative.md) and [[wikilink]]
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    raw="$(printf '%s' "$m" | sed -E 's/^\]\(//; s/\)$//; s/#.*$//')"   # ](path.md#x) -> path.md
    [ -n "$raw" ] || continue
    tgt="$(resolve "$note" "$raw")"
    [ -n "$tgt" ] || continue
    emit_rel "$note" "$tgt" "links-to" >> "$REL"
    # dangling targets are still emitted as note-entities so the linter can flag them
    is_note "$tgt" || emit_entity "$tgt" "note" "${tgt##*/}" >> "$ENT"
  done < <(xo '\]\([^)]+\.md(#[^)]*)?\)' "$f")

  while IFS= read -r m; do
    [ -n "$m" ] || continue
    wl="$(printf '%s' "$m" | sed -E 's/^\[\[//; s/\]\]$//')"
    # wikilink → strip alias/anchor, resolve to a note whose basename matches
    base="${wl%%|*}"; base="${base%%#*}"
    base="$(printf '%s' "$base" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$base" ] || continue
    # skip wikilink targets carrying regex/path metacharacters (junk nodes / ERE-injection)
    # A `case` glob, not `printf … | grep -q`: grep -q exits at the first match and
    # closes the pipe, so with `pipefail` the pipeline's status could be printf's
    # SIGPIPE (141) rather than grep's 0 — the `continue` then did not fire and the
    # junk target leaked through, non-deterministically, depending on how the two
    # processes raced. No fork, no pipe, no race.
    case "$base" in
      *'['*|*']'*|*'('*|*')'*|*'{'*|*'}'*|*'|'*|*'*'*|*'?'*|*'^'*|*'$'*|*'\'*) continue ;;
    esac
    hit="$(grep -a -iE "(^|/)${base//./\\.}(\.md)?$" "$NOTES" 2>/dev/null | head -1 || true)"
    if [ -n "$hit" ]; then emit_rel "$note" "$hit" "links-to" >> "$REL"
    else
      emit_entity "${base}.md" "note" "$base" >> "$ENT"   # dangling wikilink node
      emit_rel "$note" "${base}.md" "links-to" >> "$REL"
    fi
  done < <(xo '\[\[[^]]+\]\]' "$f")

  # (b) mentions — inline `backtick path` resolving to an EXISTING repo file
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    bt="$(printf '%s' "$m" | sed 's/^`//; s/`$//')"
    case "$bt" in */*) ;; *) continue ;; esac   # require a dir component; bare basenames (e.g. vision.md) are placeholders and collide on a case-insensitive FS
    # a code-path mention resolves to an EXISTING repo file that is NOT itself a
    # corpus note (notes are their own node-type; avoid a note/code-path id collision)
    if [ -f "$ROOT/$bt" ] && ! is_note "$bt"; then
      emit_entity "$bt" "code-path" "${bt##*/}" >> "$ENT"
      emit_rel "$note" "$bt" "mentions" >> "$REL"
    fi
  done < <(xo '`[A-Za-z0-9_][A-Za-z0-9_./-]+\.[A-Za-z0-9]+`' "$f")

  # (c) covers — leading YAML frontmatter `covers:` (inline array or block list)
  fm="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f{print}' "$f" 2>/dev/null || true)"
  if [ -n "$fm" ]; then
    covers_line="$(printf '%s\n' "$fm" | grep -oE '^covers:[[:space:]]*\[[^]]*\]' 2>/dev/null | sed -E 's/^covers:[[:space:]]*\[//; s/\]$//' || true)"
    {
      [ -n "$covers_line" ] && printf '%s\n' "$covers_line" | tr ',' '\n'
      printf '%s\n' "$fm" | awk '/^covers:[[:space:]]*$/{c=1;next} c&&/^[[:space:]]*-[[:space:]]+/{sub(/^[[:space:]]*-[[:space:]]+/,"");print;next} c{exit}'
    } 2>/dev/null | while IFS= read -r cp; do
        cp="$(printf '%s' "$cp" | sed 's/^[[:space:]"'\''`]*//;s/[[:space:]"'\''`]*$//')"
        [ -n "$cp" ] || continue
        emit_entity "$cp" "code-path" "${cp##*/}" >> "$ENT"   # dangling covers still emitted → linter warns
        emit_rel "$note" "$cp" "covers" >> "$REL"
        emit_rel "$cp" "$note" "decided-by" >> "$REL"                 # inverse
      done
  fi
done < "$NOTES"

# --- dedupe + deterministic order, then stream out --------------------------
STAGE="sorting and emitting"
OUTBUF="$(LC_ALL=C sort -u "$ENT"; LC_ALL=C sort -u "$REL")"

# ─────────────────────────────────────────────────────────────────────────────
# EMPTY OUTPUT — WHICH EMPTY IS LEGITIMATE, AND WHICH IS A BUG
# ─────────────────────────────────────────────────────────────────────────────
# "The builder produced nothing" is two different events wearing one face, and
# leaving a downstream gate to tell them apart is what turned a crash into a
# staleness report. They are separated HERE, at the only place that holds the
# fact that decides it: how many corpus notes were found.
#
#   NO CORPUS (NOTE_COUNT == 0) — LEGITIMATE, exit 0 with an empty file.
#     A sanitized template clone genuinely has no `.docs/`, `features/` or
#     `specs/` tree and need not have any of the five root markdown files. There
#     is nothing to index, an empty bridge is the CORRECT answer, and failing a
#     customer's first push for having no docs yet is the exact blocker class the
#     freshness gate already shipped once. It is announced on stderr rather than
#     passed in silence, so an empty file is never a mystery.
#
#   CORPUS PRESENT BUT ZERO LINES (NOTE_COUNT > 0, no output) — NEVER LEGITIMATE.
#     Pass 1 emits ONE entity per note UNCONDITIONALLY, before any edge harvesting
#     — no link, no wikilink, no frontmatter required. So N notes in means at
#     least N entity lines out, always. Zero lines from a non-empty corpus cannot
#     be a corpus fact; it can only be a broken toolchain or a broken pass. Exit
#     non-zero, name the count, and REFUSE TO WRITE — writing an empty file here
#     would hand the gate a plausible-looking artifact to diff and report as
#     merely "stale".
if [ "${NOTE_COUNT:-0}" -eq 0 ]; then
  echo "NOTE: no markdown corpus found under '$ROOT' (.docs/, features/, specs/ and the" >&2
  echo "  five root markdown files are all absent) — emitting an empty bridge. This is" >&2
  echo "  the correct result for a tree with no docs to index, not a failure." >&2
elif [ -z "$OUTBUF" ]; then
  echo "ERROR: harvested $NOTE_COUNT corpus note(s) but produced ZERO graph lines." >&2
  echo "  Pass 1 emits one entity per note unconditionally, so this is impossible" >&2
  echo "  from corpus content alone — the toolchain or a harvest pass is broken." >&2
  echo "  Re-run with 'bash -x' to see the failing stage. Nothing was written." >&2
  exit 5
fi

if [ -n "$OUT" ]; then
  mkdir -p "$(dirname "$OUT")" 2>/dev/null || true
  if [ -n "$OUTBUF" ]; then
    printf '%s\n' "$OUTBUF" > "$OUT" || {
      echo "ERROR: could not write '$OUT' (permissions? full disk? missing parent?)." >&2
      exit 6; }
  else
    : > "$OUT" || { echo "ERROR: could not create '$OUT'." >&2; exit 6; }
  fi   # empty corpus → empty file, not a lone blank line
fi
[ -n "$OUTBUF" ] && printf '%s\n' "$OUTBUF" || true   # never emit a lone blank line
