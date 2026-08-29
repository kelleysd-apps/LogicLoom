#!/usr/bin/env bash
# check-brain-record.sh — FAIL-CLOSED integrity gate for the `.brain/` record.
#
# Five deterministic checks. Reads frontmatter and file existence ONLY. Writes
# NOTHING. Runs NO git. Exit 0 = the record holds together.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHY THIS EXISTS, AND WHY IT IS THE *ONLY* PART OF THE ROUTINE THAT GATES
# ─────────────────────────────────────────────────────────────────────────────
# `/distill` promotes captures from `.brain/raw/` into pages under `.brain/wiki/`
# and records what it did in `.brain/DISTILL-LOG.md`. Every one of those is a
# CLAIM about another file. The defect class this repo spent a release cycle
# removing is exactly that: a claim nothing verifies.
#
# Three signals exist around this routine and only ONE of them is a gate:
#
#   RECORD INTEGRITY  "does the routine's own record hold together?"  -> HERE, FAIL-CLOSED
#   LIVENESS          "did the pass run recently?"                    -> advisory, never blocks
#   LOAD              "is there a backlog?"                           -> advisory, never blocks
#
# A fail-closed gate must assert something the change in front of it can be
# responsible for. "The log says run 2026-09-04 promoted capture X into page Y,
# and page Y does not exist" is deterministic, and it is never a false alarm on
# an unrelated PR. "You have not distilled in 40 days" is not caused by the PR it
# would block — gating on that blocks unrelated work, and the trained response is
# to bypass it. That is the false-positive fatigue that kills a gate. Worse, a
# cloner who never adopts the routine would inherit a permanently red build,
# which is the fastest possible route to this script being deleted.
#
# ─────────────────────────────────────────────────────────────────────────────
# VACUOUS ON AN EMPTY OR ABSENT `.brain/` — A LIVE GATE, NOT A DEAD ONE
# ─────────────────────────────────────────────────────────────────────────────
# With no `.brain/` at all, every check has nothing to range over and the script
# exits 0. Same on a `.brain/` holding only README.md. That is the shipped state
# for a cloner who never opts in, and it is deliberate: this ships, it runs in
# their CI on day one, it is green, and it starts covering THEIR record the first
# time they have one. It is not switched on later by a step nobody remembers.
#
# ─────────────────────────────────────────────────────────────────────────────
# THE FIVE CHECKS
# ─────────────────────────────────────────────────────────────────────────────
#  1. Every `.brain/raw/**` capture has a parseable frontmatter `status` of
#     `unprocessed` or `processed`.
#     WHY: this port does not delete a capture after distilling it, so `status`
#     is the ONLY thing separating pending from done. A capture with no
#     parseable status is invisible to the pass forever — a silent skip. This
#     check is the entire mitigation for that.
#  2. Every `processed` capture carries `distilled-into:` naming a `.brain/wiki/`
#     page that EXISTS, or `discarded: "<reason>"`. Neither present = a claim
#     nothing backs. Both present = two answers to one question.
#  3. Every `.brain/wiki/**` page has a non-empty `sources:`.
#     WHY: a wiki page is a distillation. Without a citable origin it is an
#     assertion, and an assertion in a knowledge base is the thing being
#     prevented.
#  4. Every promoted-form entry in `DISTILL-LOG.md` names a wiki page that
#     exists. (`- promoted: <src> -> <wiki>` / `- extended: <src> -> <wiki>`.)
#  5. If `.brain/wiki/` is non-empty, `DISTILL-LOG.md` exists.
#
# ─────────────────────────────────────────────────────────────────────────────
# THE DISCIPLINE THAT KEEPS THE CONTRACT PORTABLE
# ─────────────────────────────────────────────────────────────────────────────
# NO SCRIPT MAY EVER PARSE A `.brain/wiki/` PAGE'S BODY. This one reads
# frontmatter keys and file existence, nothing else. The moment a gate depends on
# prose structure, the contract stops being portable and `.brain/` becomes
# "something parses it", which is a different design with different rules.
#
# README.md files anywhere under `.brain/` are conventions documentation, not
# captures or pages, and are exempt from every check.
#
# bash 3.2 safe: no associative arrays, no mapfile, no `[[ -v ]]`, no ${v,,}.
# Overridable for testing: LOOM_BRAIN_ROOT (defaults to <repo>/.brain).
#
#   Run it:  bash .logic-loom/scripts/bash/check-brain-record.sh
#   Flags:   -q / --quiet   errors only (no per-check OK lines)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${LOOM_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
BRAIN="${LOOM_BRAIN_ROOT:-$REPO_ROOT/.brain}"

QUIET=0
case "${1:-}" in
  -q|--quiet) QUIET=1 ;;
  "") ;;
  -h|--help) sed -n '2,70p' "${BASH_SOURCE[0]}"; exit 0 ;;
  *) echo "check-brain-record.sh: unknown option '$1'" >&2; exit 2 ;;
esac

ERRORS=0
say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; ERRORS=$((ERRORS + 1)); }

# ── Vacuous exit ─────────────────────────────────────────────────────────────
if [ ! -d "$BRAIN" ]; then
  say "check-brain-record.sh: no .brain/ in this tree — nothing to check (vacuously OK)."
  exit 0
fi

# ── Frontmatter reader ───────────────────────────────────────────────────────
# Emits the raw value of KEY from the leading `---` ... `---` block, or nothing.
# Deliberately NOT a grep over the whole file: a `status:` line inside the body
# (a code fence, a quoted example) is not frontmatter, and a `grep` for
# `status: unprocessed` also misses the quoted form `status: "unprocessed"`.
# Both forms occur in real captures, and grepping for one of them caused a
# recorded miss in the system this routine was ported from.
fm_value() { # file key -> value (unquoted, trimmed) or empty
  local file="$1" key="$2"
  awk -v key="$key" '
    NR == 1 {
      if ($0 != "---") exit 0          # no frontmatter block at all
      inblock = 1; next
    }
    inblock && $0 == "---" { exit 0 }  # end of block, key not found
    inblock {
      # match `key:` at column 1 only — nested keys are not top-level keys
      if (index($0, key ":") == 1) {
        v = substr($0, length(key) + 2)
        sub(/^[ \t]+/, "", v)
        sub(/[ \t]+$/, "", v)
        # strip one layer of matching quotes
        if (v ~ /^".*"$/) v = substr(v, 2, length(v) - 2)
        else if (v ~ /^'"'"'.*'"'"'$/) v = substr(v, 2, length(v) - 2)
        print v
        exit 0
      }
    }
  ' "$file" 2>/dev/null
}

# True when KEY is present in the frontmatter block at all, even with an empty
# scalar value (a `sources:` heading a YAML list has no inline value).
#
# NOTE ON THE awk IDIOM, because the obvious spelling is wrong: `exit 0` inside
# a rule does NOT set the final status when an END block exists — control jumps
# to END and END's own `exit` overrides it. So these set a FLAG and exit exactly
# once, in END. Written the natural way, every one of these returned "not
# found" and the gate failed a well-formed record.
fm_has_key() { # file key -> 0/1
  local file="$1" key="$2"
  awk -v key="$key" '
    NR == 1 { if ($0 != "---") exit 1; inblock = 1; next }
    inblock && $0 == "---" { inblock = 0 }
    inblock { if (index($0, key ":") == 1) found = 1 }
    END { exit (found ? 0 : 1) }
  ' "$file" 2>/dev/null
}

# A YAML list under KEY has at least one `- item` line before the block ends.
fm_list_nonempty() { # file key -> 0/1
  local file="$1" key="$2"
  awk -v key="$key" '
    NR == 1 { if ($0 != "---") exit 1; inblock = 1; next }
    inblock && $0 == "---" { inblock = 0 }
    inblock {
      if (inkey && $0 ~ /^[ \t]+-[ \t]*[^ \t]/) { found = 1 }
      else if (inkey && $0 ~ /^[^ \t]/) { inkey = 0 }
      if (index($0, key ":") == 1) inkey = 1
    }
    END { exit (found ? 0 : 1) }
  ' "$file" 2>/dev/null
}

# Resolve a `distilled-into:` value to a path on disk. Accepts a repo-relative
# path or a `[[slug]]` wikilink; a wikilink is resolved by finding
# `.brain/wiki/**/<slug>.md`. Echoes the resolved path, or nothing.
resolve_wiki_ref() { # ref -> path or empty
  local ref="$1" slug hit
  case "$ref" in
    "") return 0 ;;
    \[\[*\]\])
      slug="${ref#[[}"; slug="${slug%]]}"
      # a wikilink may carry a display alias: [[slug|Display]]
      case "$slug" in *\|*) slug="${slug%%|*}" ;; esac
      [ -n "$slug" ] || return 0
      hit="$(find "$BRAIN/wiki" -type f -name "${slug}.md" 2>/dev/null | head -1)"
      [ -n "$hit" ] && printf '%s' "$hit"
      return 0 ;;
    /*) [ -f "$ref" ] && printf '%s' "$ref"; return 0 ;;
    .brain/*)
      [ -f "$REPO_ROOT/$ref" ] && printf '%s' "$REPO_ROOT/$ref"; return 0 ;;
    *)
      # bare path relative to the brain root, e.g. `wiki/concepts/foo.md`
      [ -f "$BRAIN/$ref" ] && printf '%s' "$BRAIN/$ref"; return 0 ;;
  esac
}

# Every markdown file under a layer, README.md excluded. Newline-separated.
layer_files() { # subdir -> paths
  [ -d "$BRAIN/$1" ] || return 0
  find "$BRAIN/$1" -type f -name '*.md' ! -name 'README.md' 2>/dev/null | LC_ALL=C sort
}

# ── Check 1: every capture has a parseable status ────────────────────────────
CAPTURES="$(layer_files raw)"
CAPTURE_COUNT=0
if [ -n "$CAPTURES" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    CAPTURE_COUNT=$((CAPTURE_COUNT + 1))
    st="$(fm_value "$f" status)"
    case "$st" in
      unprocessed|processed) ;;
      "") fail "[1] ${f#$REPO_ROOT/}: no parseable frontmatter \`status\` (a capture with no status is invisible to /distill forever)" ;;
      *)  fail "[1] ${f#$REPO_ROOT/}: status '$st' is not \`unprocessed\` or \`processed\`" ;;
    esac
  done <<EOF
$CAPTURES
EOF
fi
say "[1] captures with a parseable status: $CAPTURE_COUNT checked"

# ── Check 2: processed captures back their claim ─────────────────────────────
PROCESSED_COUNT=0
if [ -n "$CAPTURES" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ "$(fm_value "$f" status)" = "processed" ] || continue
    PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
    rel="${f#$REPO_ROOT/}"
    into="$(fm_value "$f" distilled-into)"
    disc="$(fm_value "$f" discarded)"
    if [ -n "$into" ] && [ -n "$disc" ]; then
      fail "[2] $rel: carries BOTH \`distilled-into\` and \`discarded\` — two answers to one question"
      continue
    fi
    if [ -n "$disc" ]; then
      continue                                   # a stated reason is sufficient
    fi
    if [ -z "$into" ]; then
      fail "[2] $rel: processed but carries neither \`distilled-into:\` nor \`discarded:\` — a claim nothing backs"
      continue
    fi
    target="$(resolve_wiki_ref "$into")"
    if [ -z "$target" ]; then
      fail "[2] $rel: \`distilled-into: $into\` does not resolve to an existing .brain/wiki/ page"
    fi
  done <<EOF
$CAPTURES
EOF
fi
say "[2] processed captures backing their claim: $PROCESSED_COUNT checked"

# ── Check 3: every wiki page cites its sources ───────────────────────────────
PAGES="$(layer_files wiki)"
PAGE_COUNT=0
if [ -n "$PAGES" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    PAGE_COUNT=$((PAGE_COUNT + 1))
    rel="${f#$REPO_ROOT/}"
    if ! fm_has_key "$f" sources; then
      fail "[3] $rel: no \`sources:\` in frontmatter — a page with no citable origin is an assertion"
      continue
    fi
    inline="$(fm_value "$f" sources)"
    if [ -z "$inline" ] && ! fm_list_nonempty "$f" sources; then
      fail "[3] $rel: \`sources:\` is empty"
    fi
  done <<EOF
$PAGES
EOF
fi
say "[3] wiki pages citing sources: $PAGE_COUNT checked"

# ── Check 4: promoted-form log entries resolve ───────────────────────────────
LOG="$BRAIN/DISTILL-LOG.md"
PROMOTED_COUNT=0
if [ -f "$LOG" ]; then
  # Grammar: `- promoted: <src> -> <wiki path>` (also `- extended:`). Anything
  # else on the line is not a promoted-form entry and is not this gate's business.
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    PROMOTED_COUNT=$((PROMOTED_COUNT + 1))
    target="${line##*-> }"
    # trim trailing whitespace without bash 4
    while [ "${target% }" != "$target" ] || [ "${target%	}" != "$target" ]; do
      target="${target% }"; target="${target%	}"
    done
    resolved="$(resolve_wiki_ref "$target")"
    if [ -z "$resolved" ]; then
      fail "[4] DISTILL-LOG.md: entry claims '-> $target' but no such .brain/wiki/ page exists"
    fi
  done <<EOF
$(grep -E '^[[:space:]]*-[[:space:]]*(promoted|extended):[[:space:]].*->[[:space:]]' "$LOG" 2>/dev/null || true)
EOF
fi
say "[4] promoted-form log entries resolving: $PROMOTED_COUNT checked"

# ── Check 5: a non-empty wiki implies a log ──────────────────────────────────
if [ "$PAGE_COUNT" -gt 0 ] && [ ! -f "$LOG" ]; then
  fail "[5] .brain/wiki/ has $PAGE_COUNT page(s) but .brain/DISTILL-LOG.md does not exist — pages appeared with no record of a run"
fi
say "[5] non-empty wiki implies a run log: OK"

# ── Verdict ──────────────────────────────────────────────────────────────────
if [ "$ERRORS" -eq 0 ]; then
  if [ "$CAPTURE_COUNT" -eq 0 ] && [ "$PAGE_COUNT" -eq 0 ]; then
    say "check-brain-record.sh: .brain/ holds no captures and no pages — vacuously OK."
  else
    say "check-brain-record.sh: record holds ($CAPTURE_COUNT capture(s), $PAGE_COUNT page(s))."
  fi
  exit 0
fi

printf '\ncheck-brain-record.sh: %s problem(s) in the .brain/ record.\n' "$ERRORS" >&2
printf 'Contract: .brain/README.md · plugins/loom-orchestrator/skills/distillation-pass/SKILL.md\n' >&2
exit 1
