#!/usr/bin/env bash
# build-graph-bridge.sh — deterministic CODE↔DOCS bridge generator (Phase 1).
# Harvests edges already present in the markdown corpus and emits graph-bridge.jsonl
# (Anthropic memory-server shape) to stdout. Zero-LLM, rg+jq only, fail-open.
#
# Usage:
#   build-graph-bridge.sh [CORPUS_ROOT] [--out FILE]
#     CORPUS_ROOT  optional repo root (default: repo root resolved from script location)
#     --out FILE   also write JSONL to FILE (dir created); still echoed to stdout
#
# Schema (one JSON object per line):
#   entity   {"type":"entity","name":"<repo-rel-path>","entityType":"note"|"code-path","observations":["title"]}
#   relation {"type":"relation","from":"<id>","to":"<id>","relationType":"links-to"|"mentions"|"covers"|"decided-by"}
# Node ids are repo-relative paths. See features/code-knowledge-graph/exploration/project-graph-design.md §3.3.
set -euo pipefail

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
command -v jq >/dev/null 2>&1 || { echo "WARN: jq not found; emitting nothing" >&2; exit 0; }
[ -d "$ROOT" ] || { echo "WARN: corpus root '$ROOT' missing; emitting nothing" >&2; exit 0; }
command -v python3 >/dev/null 2>&1 || echo "WARN: python3 not found; relative link/covers edges will be skipped (path resolution degraded)" >&2

# Portable extractor: use a REAL rg binary when one is on PATH; otherwise grep -oE.
# Both take an ERE and a file, printing each match on its own line (no capture magic;
# capture stripping is done by the caller with sed for grep/rg parity).
HAVE_RG=0
if command -v rg >/dev/null 2>&1 && [ -z "$(type -t rg 2>/dev/null | grep function)" ]; then HAVE_RG=1; fi
xo() { # $1=ERE  $2=file  -> matched substrings, one per line
  if [ "$HAVE_RG" = 1 ]; then rg --no-config -oN -e "$1" "$2" 2>/dev/null || true
  else grep -oE "$1" "$2" 2>/dev/null || true; fi
}
xheading() { # first markdown H1 of a file, heading text only
  if [ "$HAVE_RG" = 1 ]; then rg --no-config -m1 -oN -e '^#[[:space:]].+' "$1" 2>/dev/null | sed 's/^#[[:space:]]*//'
  else grep -m1 -oE '^#[[:space:]].+' "$1" 2>/dev/null | sed 's/^#[[:space:]]*//'; fi
}

# --- collect corpus notes (fail-open on missing dirs) ------------------------
NOTES="$(mktemp)"; trap 'rm -f "$NOTES"' EXIT
{
  for d in .docs features specs; do
    [ -d "$ROOT/$d" ] && find "$ROOT/$d" -type f -name '*.md' 2>/dev/null
  done
  for r in README.md CLAUDE.md AGENTS.md START_HERE.md VISION.md; do
    [ -f "$ROOT/$r" ] && printf '%s\n' "$ROOT/$r"
  done
  true   # ensure the group exits 0 even if the last [ -f ] test failed (pipefail)
} | sed "s#^$ROOT/##" \
  | grep -vE '^(\.docs/architecture/project-graph-convention\.md$|features/code-knowledge-graph/)' \
  | LC_ALL=C sort -u > "$NOTES" || true   # exclude the graph's own meta-docs — their link/wikilink EXAMPLES are illustrative, not real edges

# helper: emit an entity line via jq (safe quoting)
emit_entity() { # $1=name $2=entityType $3=observation
  jq -cn --arg n "$1" --arg t "$2" --arg o "$3" \
    '{type:"entity",name:$n,entityType:$t,observations:[$o]}'
}
emit_rel() { # $1=from $2=to $3=relationType
  jq -cn --arg f "$1" --arg t "$2" --arg r "$3" \
    '{type:"relation",from:$f,to:$t,relationType:$r}'
}
# resolve a link/path relative to a note's dir, canonicalize .. , return repo-rel or empty
resolve() { # $1=note-repo-rel  $2=raw-target
  local base_dir tgt clean
  base_dir="$(dirname "$1")"; tgt="$2"
  case "$tgt" in /*) clean="${tgt#/}" ;; *) clean="$base_dir/$tgt" ;; esac
  # normalize with python (portable, no realpath dependency); must stay inside repo
  clean="$(cd "$ROOT" 2>/dev/null && python3 - "$clean" <<'PY' 2>/dev/null || true
import os,sys
p=os.path.normpath(sys.argv[1])
print("" if p.startswith("..") or os.path.isabs(p) else p)
PY
)"
  printf '%s' "$clean"
}

ENT="$(mktemp)"; REL="$(mktemp)"; trap 'rm -f "$NOTES" "$ENT" "$REL"' EXIT

# --- pass 1: every note is a note-entity (title = first heading or basename) --
while IFS= read -r note; do
  [ -n "$note" ] || continue
  title="$(xheading "$ROOT/$note" || true)"
  [ -n "$title" ] || title="$(basename "$note")"
  emit_entity "$note" "note" "$title" >> "$ENT"
done < "$NOTES"

# a note exists on disk? (used to distinguish links-to target vs dangling)
is_note() { grep -qxF "$1" "$NOTES"; }

# strip fenced code blocks (``` … ```) so code-sample paths don't become edges
NC="$(mktemp)"; trap 'rm -f "$NOTES" "$ENT" "$REL" "$NC"' EXIT
strip_fences() { awk '/^[[:space:]]*(```|~~~)/{f=!f;next} !f{print}' "$1" 2>/dev/null; }

# --- pass 2: harvest edges per note -----------------------------------------
while IFS= read -r note; do
  [ -n "$note" ] || continue
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
    is_note "$tgt" || emit_entity "$tgt" "note" "$(basename "$tgt")" >> "$ENT"
  done < <(xo '\]\([^)]+\.md(#[^)]*)?\)' "$f")

  while IFS= read -r m; do
    [ -n "$m" ] || continue
    wl="$(printf '%s' "$m" | sed -E 's/^\[\[//; s/\]\]$//')"
    # wikilink → strip alias/anchor, resolve to a note whose basename matches
    base="${wl%%|*}"; base="${base%%#*}"
    base="$(printf '%s' "$base" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$base" ] || continue
    # skip wikilink targets carrying regex/path metacharacters (junk nodes / ERE-injection)
    printf '%s' "$base" | grep -q '[][(){}|*?^$\\]' && continue || true
    hit="$(grep -iE "(^|/)${base//./\\.}(\.md)?$" "$NOTES" 2>/dev/null | head -1 || true)"
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
      emit_entity "$bt" "code-path" "$(basename "$bt")" >> "$ENT"
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
        emit_entity "$cp" "code-path" "$(basename "$cp")" >> "$ENT"   # dangling covers still emitted → linter warns
        emit_rel "$note" "$cp" "covers" >> "$REL"
        emit_rel "$cp" "$note" "decided-by" >> "$REL"                 # inverse
      done
  fi
done < "$NOTES"

# --- dedupe + deterministic order, then stream out --------------------------
OUTBUF="$(LC_ALL=C sort -u "$ENT"; LC_ALL=C sort -u "$REL")"
if [ -n "$OUT" ]; then
  mkdir -p "$(dirname "$OUT")" 2>/dev/null || true
  if [ -n "$OUTBUF" ]; then printf '%s\n' "$OUTBUF" > "$OUT" || echo "WARN: could not write $OUT" >&2
  else : > "$OUT"; fi   # empty corpus → empty file, not a lone blank line
fi
[ -n "$OUTBUF" ] && printf '%s\n' "$OUTBUF" || true   # never emit a lone blank line
