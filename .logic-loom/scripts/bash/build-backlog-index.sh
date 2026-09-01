#!/usr/bin/env bash
# build-backlog-index.sh — deterministic BACKLOG COLLECTOR (the machine contract layer).
#
# Reads the human-authored task sources, emits ONE small machine-readable index.
# Zero LLM. grep/awk/jq only. Fail-open on missing tooling. bash 3.2 safe.
#
# ─────────────────────────────────────────────────────────────────────────────
# LINTER ADVISES THE AUTHOR; THE COLLECTOR REFUSES TO PUBLISH SOMETHING WRONG
# ─────────────────────────────────────────────────────────────────────────────
# The two scripts over these sources have DIFFERENT contracts, on purpose:
#
#   lint-backlog.sh  is authoring feedback for a human mid-thought. It reports
#                    every defect it finds and exits 0 by default, because a
#                    linter that blocks a commit gets disabled, and then nothing
#                    is checked at all.
#
#   THIS SCRIPT      produces an artifact other things CONSUME. A consumer that
#                    reads the index cannot distinguish "this item does not
#                    exist" from "the collector dropped it" — so the collector
#                    must never drop anything quietly. On a defect that would
#                    make the index misrepresent its sources it FAILS: non-zero
#                    exit, nothing written, any previous index left byte-for-byte
#                    untouched. A stale-but-true index beats a fresh-but-lying
#                    one, because the consumer can detect staleness (that is what
#                    `source_digest` is for) and cannot detect a silent drop.
#
# The fatal set is deliberately narrow — see FATAL DEFECTS below.
#
# ─────────────────────────────────────────────────────────────────────────────
# SOURCES, in order of authority
# ─────────────────────────────────────────────────────────────────────────────
#   1. .logic-loom/memory/todos.md     cross-cutting work, ACTIVE   level "todo"
#   2. .logic-loom/memory/backlog.md   cross-cutting work, DEFERRED level "backlog"
#   3. features/*/plan.md              feature task DAGs            level "feature"
#   4. specs/*/tasks.md                SDD waterfall checkboxes     level "spec"
#
# Sources 1 and 2 are TWO STREAMS OF ONE THING. They share a grammar (specified
# once, in backlog.md), a parser (parse_item_file below), a linter, and — the
# load-bearing part — ONE ID SPACE: a `blocked_on:` reference crosses freely
# between them, so a duplicate id across the two files is exactly as fatal as a
# duplicate within one. They differ only in scope and in the `level` they carry.
#
# Every source is OPTIONAL. Zero sources is a normal state (a fresh clone has no
# features and no specs) and produces a valid index with an empty `items` array,
# exit 0.
#
# That list is not prose describing code — it is the SOURCE TABLE below, and the
# collection loop walks it. See ADDING A SOURCE.
#
# ─────────────────────────────────────────────────────────────────────────────
# ADDING A SOURCE — the one extension point
# ─────────────────────────────────────────────────────────────────────────────
# Adding another item class is a DECLARED change: one row in `SOURCE_TABLE`
# plus one parser function. Nothing else in this script changes — the collection
# loop, the fatal gate, the digest and the emit step are all class-agnostic.
#
#   1. Write a parser function. It is a plain filter: called as
#          <parser> <ABSOLUTE-FILE> <REPO-RELATIVE-PATH> <QUALIFIER>
#      and it writes TAB-separated rows to stdout, one per item:
#          level<TAB>id<TAB>status<TAB>blocked_on<TAB>file<TAB>heading<TAB>title
#      `blocked_on` is a comma-joined string ("" for none). A defect the parser
#      wants to treat as FATAL is written to the SAME stdout as
#          !ERR<TAB>message
#      and `collect` splits the two streams. QUALIFIER is the directory name
#      that disambiguates project-local ids (see column 1 below); it is the
#      empty string for a fixed single-file source, and such a parser may ignore
#      its third argument.
#   2. Add one row to SOURCE_TABLE.
#   3. Add the new `level` value to the CONSUMER-FACING vocabulary note in the
#      COMPATIBILITY CONTRACT below, and to the class table in
#      build-backlog-dashboard.sh (the contract test asserts the two agree).
#
# THE ONE RULE THAT MUST HOLD. A new `level` value is an ADDITIVE schema change:
# `schema_version` does NOT bump (see ADDITIVE in the COMPATIBILITY CONTRACT).
# That is only safe because every consumer is required to CARRY AN UNKNOWN LEVEL
# THROUGH rather than drop the item — bucket it under a catch-all, never coerce
# it to a known value, never fail. A consumer that filters on a hardcoded list
# of levels silently loses the entire new class the day it is added, and loses
# it invisibly, which is the failure this index exists to prevent. If you add a
# level, check the consumers honour that rule; do not assume it.
#
# DELIBERATELY NOT A PLUGIN SYSTEM. There is no config file, no source
# directory scanned for drop-in parsers, no registration call. A table of three
# literal rows and a `case` on `*` is the whole mechanism (Principle V,
# Progressive Enhancement): the extension point is meant to be OBVIOUS and
# DOCUMENTED, not dynamic. Adding a source should require reading this file.
#
# ─────────────────────────────────────────────────────────────────────────────
# THE OUTPUT IS UNTRACKED — ON PURPOSE
# ─────────────────────────────────────────────────────────────────────────────
# `.logic-loom/backlog-index.json` is gitignored and MUST STAY THAT WAY.
#
# A tracked derived artifact diverges from its sources the moment someone edits a
# source without regenerating. That is not a hypothetical here — this repo has
# been bitten by that exact class three times:
#
#   * dead scrub rules in history-scrub-rules.json, matching paths that no longer
#     existed (now guarded by tests/contract/test_scrub_rules_match.sh);
#   * orphaned test suites registered nowhere, protecting nothing (now guarded by
#     tests/contract/test_suite_registration.sh);
#   * a plugin manifest advertising a command that had been stripped from disk
#     (LOOM-0012 — still open).
#
# Each of those needed a NEW GUARD to make the drift detectable. Untracked +
# regenerate-on-demand needs no guard: the index cannot be stale relative to the
# working tree because it is rebuilt from the working tree, and it cannot be
# stale in someone else's clone because it does not travel there. Staleness
# becomes structurally impossible rather than merely detectable.
#
# THE LINE, AND WHY THE INDEX IS ON THIS SIDE OF IT. The rule is not "no derived
# artifact is ever tracked" — it is that the only derived artifact worth paying
# the staleness cost for is THE ONE A HUMAN OPENS. This index has no standalone
# reader; it exists to be fed to build-backlog-dashboard.sh. Nothing is lost by
# regenerating it, so nothing justifies tracking it, so it stays ignored.
#
# The DASHBOARD is on the other side of that line and IS tracked: an ignored
# page existed only in the checkout that last ran the generator, which made it
# absent exactly when someone went looking for it. The cost that buys is paid in
# full by a fail-closed gate — .logic-loom/scripts/bash/check-generated-
# freshness.sh regenerates the page and fails CI if the committed copy differs.
# Note what that gate does NOT check: this index. There is no committed copy of
# it to disagree with the sources, so there is nothing to gate.
#
# `.logic-loom/graph/graph-bridge.jsonl` — a generated index of this whole repo,
# git-tracked, and the artifact that leaked the maintainer's private domain into
# the public v6.4.0 template (hence tests/contract/test_generated_artifacts_
# declared.sh) — was long cited here as the shape to avoid, because it was
# tracked with NO freshness guard at all. It is now covered by the same gate.
#
# ─────────────────────────────────────────────────────────────────────────────
# SCHEMA (version 1) — brutally small on purpose
# ─────────────────────────────────────────────────────────────────────────────
# {
#   "schema_version": 1,
#   "generated_at":   "2026-08-20T00:00:00Z",
#   "source_digest":  "<sha256 over the concatenated content of every source>",
#   "project": { "slug": "...", "name": "...", "id_prefix": "...", "repo": "..." },
#   "items": [
#     { "id": "LOOM-0002",
#       "title": "Inject amendments.md into the governance preflight",
#       "status": "blocked",
#       "blocked_on": ["LOOM-0001"],
#       "source": { "file": ".logic-loom/memory/backlog.md",
#                   "heading": "Governance and constitution" },
#       "level": "backlog" }
#   ]
# }
#
# `blocked_on` — TWO KINDS OF BLOCKER, ONE ARRAY
# Every entry is a string. An entry is EITHER:
#   * an ID REFERENCE — resolves against `.items[].id` in this same index; or
#   * an EXTERNAL BLOCKER — the literal prefix `external:` followed by a
#     free-text reason, e.g. "external:maintainer decision on the proposal".
#
# A consumer distinguishes them by that prefix and nothing else: an entry
# starting with `external:` is outside the index by definition and MUST NOT be
# reported as a dangling reference; every other entry MUST resolve to an item id.
# That is the whole distinction — there is deliberately no taxonomy of blocker
# kinds, no `blocker_type` field, and no structure inside the reason.
#
# It exists because real blockers are not always other items. Two live ones here
# are a human decision (a maintainer answering a proposal) and an action in
# another repository. Before this, such items were `status:blocked` with an EMPTY
# `blocked_on`, and a daily brief could say an item was blocked but never why.
#
# `external` is a RESERVED prefix: no feature directory and no spec directory may
# be named `external`, because feature/spec task ids are qualified `<dir>:<id>`
# and would otherwise be indistinguishable from an external blocker.
#
# `repo` appears ONLY when declared in project.conf. `project` values are echoed
# verbatim, including the `__UNSET__` placeholder of an unstamped clone — an
# unstamped project should read as unstamped, not as absent.
#
# `source` is DERIVED, never authored: `file` is the repo-relative source path,
# `heading` is the nearest preceding heading (backlog.md / tasks.md) or the
# enclosing sprint name (plan.md). backlog.md's grammar forbids hand-written
# source pointers precisely so this stays a tool's job.
#
# `source_digest` — WHAT IT IS ACTUALLY FOR, STATED NARROWLY
# It is a sha256 over the concatenated content of every source file, in the
# deterministic order they were collected. Its ONLY honest use is LOCAL STALENESS
# DETECTION by something that can re-read those sources: recompute the digest,
# compare, regenerate if it differs.
#
# It is NOT a revision descriptor and NOT a portable version stamp. A remote
# aggregator holding only this JSON CANNOT recompute it — it does not have the
# source files — so for that consumer the digest is an opaque token that is equal
# or not equal to another one it was given. It answers "did the sources change
# between these two indexes I hold?" and nothing else. It carries no ordering (no
# before/after), no provenance, and no link to a commit. Do not read more into it
# than that; a consumer that needs "which revision is this" needs a different
# field, which does not exist yet (tracked as a backlog item, deliberately
# deferred until a consumer actually needs it).
#
# ─────────────────────────────────────────────────────────────────────────────
# DELIBERATELY ABSENT — do not add these back
# ─────────────────────────────────────────────────────────────────────────────
#   * per-item timestamps — cannot be obtained honestly without git-blame
#     archaeology, and this script runs no git by construction. A consumer that
#     wants "what changed" diffs two index snapshots; that answer is real,
#     whereas a hand-maintained date is a claim nobody verifies.
#   * owner — single-maintainer harness; wrong on a fork on day one.
#   * estimate / story points — unverifiable, nothing consumes them.
#   * percent complete — the four-value status IS the progress model.
#   * priority — file order is the priority.
#   * any pre-computed aggregation or rollup (counts by status, blocked chains,
#     "N% done") — the moment derived numbers sit beside source data in the same
#     object, a consumer cannot tell which is which, and the rollup is the first
#     thing to disagree with the items it was computed from. Consumers aggregate.
#
# Add a field only when a consumer exists that CANNOT WORK without it.
#
# ─────────────────────────────────────────────────────────────────────────────
# DETERMINISM
# ─────────────────────────────────────────────────────────────────────────────
# Same inputs -> byte-identical output. Items are `LC_ALL=C sort`ed by id. The one
# unavoidable exception is `generated_at`: set SOURCE_DATE_EPOCH to freeze it
# (the contract test does exactly this to prove byte-identity).
#
# ─────────────────────────────────────────────────────────────────────────────
# COMPATIBILITY CONTRACT — read this before adding anything to the schema
# ─────────────────────────────────────────────────────────────────────────────
# `schema_version` is a single integer. It is the ONLY compatibility signal; a
# consumer version-gates on it and on nothing else.
#
# PRODUCER IS STRICT, CONSUMER IS LIBERAL. These are different obligations and
# conflating them is what turns a closed enum into a breaking change:
#
#   PRODUCER (this script, at schema_version 1) emits `status` only from
#   { open, in_progress, blocked, done } and `level` only from
#   { todo, backlog, feature, spec }. A source value outside those is a FATAL defect —
#   the collector refuses to publish rather than inventing a mapping.
#
#   CONSUMER of an index MUST tolerate a `status` or `level` it does not
#   recognise, because a later schema_version 1 producer may emit one (see
#   ADDITIVE below). Required behaviour on an unrecognised value:
#     * carry it through VERBATIM — never coerce, never map to a known value;
#     * never drop the item — an item with an unknown status is still work;
#     * bucket it under a catch-all ("other") rather than omitting it;
#     * never fail. An unknown value is not an error at the same major version.
#   The same applies to unknown OBJECT KEYS: ignore them, do not fail on them.
#
# ADDITIVE — same `schema_version`, no consumer change required:
#   * a new OPTIONAL field on an item or at top level;
#   * a new value added to the `status` or `level` vocabulary;
#   * a new `source` sub-key.
#   All of these are safe only because of the consumer rule above. Adding a
#   vocabulary value without that rule already written down is what makes the
#   first such addition break every existing reader.
#
# BREAKING — REQUIRES bumping `schema_version`:
#   * removing or renaming any field, or making an optional field required;
#   * changing a field's JSON type (e.g. `blocked_on` string -> object);
#   * changing the MEANING of an existing field or of an existing value;
#   * changing id syntax, the `<dir>:<id>` qualification form, or the
#     `external:` blocked_on marker;
#   * changing the definition of `source_digest`.
#
# A consumer that reads a HIGHER `schema_version` than it understands must say so
# and stop, not guess. A consumer that reads a LOWER one may proceed.
#
# This is a stated rule, not machinery: nothing here validates a consumer, and
# there is no negotiation, no capability list, and no migration engine. One
# integer and a paragraph is the whole mechanism, on purpose.
#
# ─────────────────────────────────────────────────────────────────────────────
# FATAL DEFECTS — the collector refuses to publish
# ─────────────────────────────────────────────────────────────────────────────
# On any of these: every defect is printed to stderr, NOTHING is written, and the
# exit code is 3. A previously generated index is left exactly as it was.
#
#   1. DUPLICATE ID, anywhere across ALL sources after qualification. An id is
#      the consumer's primary key. Two rows sharing one is not a merge — it is an
#      index where "the item with id X" has no answer, and which row a consumer
#      picks depends on its own iteration order.
#   2. A LINE BELOW `## Items` IN todos.md OR backlog.md THAT LOOKS LIKE AN ITEM
#      AND DOES NOT PARSE — missing ` — ` separator, malformed id, missing `status:` tag, or a
#      `status:` value outside the closed vocabulary. By the shared grammar the
#      `## Items` section contains items and nothing else, so a `- [ ]` line there
#      IS a claim of work; dropping it makes real work invisible to every
#      consumer while it still looks tracked to the human who wrote it.
#   3. A TASK IN features/*/plan.md WITH A `status:` OUTSIDE THE VOCABULARY — an
#      explicitly declared value that is explicitly wrong.
#
# NOT FATAL — the one deliberate exception:
#   a `- [ ]` line in specs/*/tasks.md with no task id is WARNED and skipped.
#   tasks.md has no `## Items` boundary, so a checkbox in it is not necessarily a
#   task — SDD task files legitimately carry plain checklist lines. Treating
#   those as items would be the mirror error, and failing on them would make the
#   whole index hostage to someone's prose.
#
# ─────────────────────────────────────────────────────────────────────────────
# BOUNDARIES
# ─────────────────────────────────────────────────────────────────────────────
#   * writes NOTHING except the output path (plus scratch files under $TMPDIR)
#   * runs NO git, ever
#   * validates only the FATAL set above. Everything else — prefix conformance,
#     checkbox/status agreement, dangling blockers — is lint-backlog.sh's job and
#     is advisory there. The collector is not a linter; it is a publisher with a
#     refusal.
#
# Usage:
#   build-backlog-index.sh [ROOT] [--out FILE] [--stdout] [--repo OWNER/REPO]
#     ROOT             repo root (default: resolved from this script's location)
#     --out FILE       output path (default: <ROOT>/.logic-loom/backlog-index.json)
#     --stdout         also echo the index to stdout
#     --repo OWNER/REPO  overrides project.conf's optional `repo` key in the
#                      emitted `.project.repo` field. This script still runs NO
#                      git of its own — see BOUNDARIES above — so the value is
#                      supplied ALREADY RESOLVED by the caller (e.g. a wrapper
#                      that ran `git remote get-url origin` itself). Anyone
#                      running this by hand without the flag gets exactly what
#                      project.conf declares, same as before this flag existed.
#
# Exit: 0  success (including the zero-sources case)
#       1  unwritable output path, or jq failed to assemble
#       2  usage error
#       3  fatal source defect — see FATAL DEFECTS; nothing was written
set -uo pipefail

ROOT=""; OUT=""; ECHO_STDOUT=0; REPO_OVERRIDE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out)     OUT="${2:-}"; shift 2 || true ;;
    --out=*)   OUT="${1#--out=}"; shift ;;
    --stdout)  ECHO_STDOUT=1; shift ;;
    --repo)    REPO_OVERRIDE="${2:-}"; shift 2 || true ;;
    --repo=*)  REPO_OVERRIDE="${1#--repo=}"; shift ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    -*) echo "ERROR: unknown option '$1'" >&2; exit 2 ;;
    *)  [ -z "$ROOT" ] && ROOT="$1"; shift ;;
  esac
done

if [ -z "$ROOT" ]; then
  _sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT="$(cd "$_sd/../../.." && pwd)"   # scripts/bash -> .logic-loom -> repo root
fi
[ -d "$ROOT" ] || { echo "WARN: root '$ROOT' missing; nothing to collect" >&2; exit 0; }
[ -n "$OUT" ] || OUT="$ROOT/.logic-loom/backlog-index.json"

command -v jq >/dev/null 2>&1 || {
  echo "WARN: jq not found — cannot emit the backlog index. Install jq (brew install jq) and re-run." >&2
  exit 0
}

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t loombli)" || exit 1
trap 'rm -rf "$TMPD"' EXIT
TSV="$TMPD/items.tsv"; : > "$TSV"
SRCLIST="$TMPD/sources.txt"; : > "$SRCLIST"
ERRS="$TMPD/errors.txt"; : > "$ERRS"

# Parsers emit item rows and error rows on the SAME stdout stream; error rows
# carry the `!ERR` sentinel in field 1. Splitting them here (rather than having
# awk write a second file directly) keeps every parser a plain filter and avoids
# each awk process truncating a shared error file on open.
collect() { # reads a parser's stdout on stdin
  while IFS= read -r _l || [ -n "$_l" ]; do
    case "$_l" in
      '!ERR	'*) printf '%s\n' "${_l#\!ERR	}" >> "$ERRS" ;;
      '') ;;
      *) printf '%s\n' "$_l" >> "$TSV" ;;
    esac
  done
}

# ═════════════════════════════════════════════════════════════════════════════
# SOURCE TABLE — the declared list of item classes. THE extension point.
# ═════════════════════════════════════════════════════════════════════════════
# One row per class, three pipe-separated columns:
#
#   1  PATH PATTERN   repo-relative. Either a FIXED FILE
#                     (".logic-loom/memory/backlog.md") or a ONE-LEVEL GLOB
#                     ("features/*/plan.md"). In the glob form the `*` segment
#                     names the containing directory, and that directory name is
#                     passed to the parser as the QUALIFIER so project-local ids
#                     (`t1`, `T001`) can be namespaced `<dir>:<id>` and not
#                     collide across features. Only that one shape is supported;
#                     a deeper or multi-`*` pattern is a code change, on purpose.
#   2  LEVEL          the `level` value every item from this source carries.
#                     Must be in the vocabulary stated in the COMPATIBILITY
#                     CONTRACT above — adding one there is ADDITIVE.
#   3  PARSER         shell function, called: <parser> ABS REL QUALIFIER
#
# Rows are walked TOP TO BOTTOM (authority order); within a row, matching files
# are LC_ALL=C sorted. Blank lines and `#` lines are ignored. Every source is
# OPTIONAL — a pattern that matches nothing contributes nothing and is not an
# error. To add a class, add a row here and a parser below. See ADDING A SOURCE
# in the header.
SOURCE_TABLE='
.logic-loom/memory/todos.md|todo|parse_todos
.logic-loom/memory/backlog.md|backlog|parse_backlog
features/*/plan.md|feature|parse_plan
specs/*/tasks.md|spec|parse_tasks
'

# ── project identity (parsed as text; NEVER sourced) ─────────────────────────
CONF="${LOOM_PROJECT_CONF:-$ROOT/.logic-loom/config/project.conf}"
P_SLUG=""; P_NAME=""; P_PREFIX=""; P_REPO=""
if [ -r "$CONF" ]; then
  while IFS= read -r cline || [ -n "$cline" ]; do
    cline="${cline%%#*}"
    case "$cline" in *=*) ;; *) continue ;; esac
    ckey="$(printf '%s' "${cline%%=*}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    cval="$(printf '%s' "${cline#*=}"  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    case "$ckey" in
      project_slug) [ -z "$P_SLUG" ]   && P_SLUG="$cval" ;;
      project_name) [ -z "$P_NAME" ]   && P_NAME="$cval" ;;
      id_prefix)    [ -z "$P_PREFIX" ] && P_PREFIX="$cval" ;;
      repo)         [ -z "$P_REPO" ]   && P_REPO="$cval" ;;
    esac
  done < "$CONF"
fi
# --repo on the command line wins over project.conf's declared value — the
# caller resolved it (typically from `git remote`) closer to the moment it is
# used, which project.conf's own comment names as the more trustworthy source.
[ -n "$REPO_OVERRIDE" ] && P_REPO="$REPO_OVERRIDE"

# ── PARSER: todos.md / backlog.md  (levels "todo" / "backlog") ────────────────────────────────────────────────────────────
# Items live ONLY below `## Items`, to the next `## ` or EOF. Fenced blocks are
# skipped everywhere — without that rule the grammar's own worked examples become
# real items. Emits: level id status blocked_on file heading title
#
# A `- [ ]` line in that section that does not parse is a FATAL defect, not a
# warning: by the grammar the section holds items and nothing else, so an
# unparseable line there is real work that would silently reach no consumer.
#
# `blocked_on` entries are split on comma and each entry is TRIMMED — internal
# whitespace is preserved, because an `external:` entry carries a free-text
# reason. (The pre-external parser stripped all whitespace, which was harmless
# only while every entry was an id.)
#
# ONE PARSER, TWO STREAMS. todos.md and backlog.md share a grammar by design —
# it is specified once, in backlog.md, and `todos.md` points at it rather than
# restating it. Forking the parser would be implementing a second grammar that
# no document specifies, so the only per-stream difference is the `level`
# stamped on each row. `parse_todos` and `parse_backlog` are one-line wrappers
# so the SOURCE_TABLE contract stays exactly three columns and every parser is
# still called with the documented three arguments.
parse_item_file() { # $1 = absolute file  $2 = repo-relative path  $3 = level
  awk -v FILE="$2" -v LEVEL="$3" '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    function err(msg) { printf("!ERR\t%s: %s\n", FILE, msg) }
    # SEP / SEPLEN: the id/title separator " <em dash> ". Its LENGTH is measured,
    # never hardcoded, because awk implementations disagree about the unit.
    # A byte-oriented awk (BSD/onetrue awk, mawk, gawk under LC_ALL=C) reports
    # length(SEP) == 5 (space + 3 UTF-8 bytes + space); gawk in ANY multibyte
    # locale — including LANG=C.UTF-8, the default on GitHub-hosted Linux
    # runners — reports 3, because index()/substr() there count CHARACTERS.
    # The old literal `p + 5` silently sliced two characters off the front of
    # every title on such a host (id, status and file stayed correct, which is
    # why only the title-bearing assertion caught it). length(SEP) is right
    # under both, in any locale.
    BEGIN { ins = 0; fence = 0; heading = ""; SEP = " \342\200\224 "; SEPLEN = length(SEP) }
    {
      line = $0
      if (line ~ /^[[:space:]]*(```|~~~)/) { fence = 1 - fence; next }
      if (fence) next
      if (line ~ /^## /) { ins = (line ~ /^## Items[[:space:]]*$/) ? 1 : 0; heading = ""; next }
      if (!ins) next
      if (line ~ /^#+[[:space:]]/) { h = line; sub(/^#+[[:space:]]*/, "", h); heading = trim(h); next }
      if (line !~ /^- \[[ x]\] /) next

      rest = substr(line, 7)
      p = index(rest, SEP)                        # " <em dash> "
      if (p == 0) {
        err(sprintf("line %d: no \xe2\x80\x94 separator between id and title: %s", NR, line)); next
      }
      id = trim(substr(rest, 1, p - 1))
      after = substr(rest, p + SEPLEN)            # past " <em dash> " — see SEPLEN above

      if (id !~ /^[A-Z][A-Z0-9]*-[0-9][0-9][0-9][0-9][0-9]*$/) {
        err(sprintf("line %d: malformed id \x27%s\x27 (want PREFIX-NNNN, 4+ digits)", NR, id)); next
      }
      if (match(after, /`status:[A-Za-z_]+`/) == 0) {
        err(sprintf("line %d: %s has no `status:` tag", NR, id)); next
      }
      title  = trim(substr(after, 1, RSTART - 1))
      status = substr(after, RSTART + 8, RLENGTH - 9)
      if (status != "open" && status != "in_progress" && status != "blocked" && status != "done") {
        err(sprintf("line %d: %s has status \x27%s\x27 outside the closed vocabulary (open|in_progress|blocked|done)", NR, id, status))
        next
      }
      bo = ""
      if (match(after, /`blocked_on:[^`]*`/) > 0) {
        raw = substr(after, RSTART + 12, RLENGTH - 13)
        n = split(raw, ba, ",")
        for (i = 1; i <= n; i++) {
          v = trim(ba[i]); gsub(/\t/, " ", v)
          if (v != "") bo = (bo == "" ? v : bo "," v)
        }
      }
      gsub(/\t/, " ", title)
      printf("%s\t%s\t%s\t%s\t%s\t%s\t%s\n", LEVEL, id, status, bo, FILE, heading, title)
    }
  ' "$1"
}

parse_todos()   { parse_item_file "$1" "$2" todo; }
parse_backlog() { parse_item_file "$1" "$2" backlog; }

# ── PARSER: features/*/plan.md  (level "feature") ────────────────────────────────────────────────────
# The plan DAG lives in leading YAML frontmatter. Task ids are PROJECT-LOCAL and
# short (`t1`), so two features would collide in one index — they are qualified
# here as `<feature>:<task-id>`. `blocked_on` refs are qualified the same way, so
# a ref resolves against an id that is actually IN the index. `heading` is the
# enclosing sprint name, the plan's structural analogue of a markdown heading.
parse_plan() { # $1 = absolute file  $2 = repo-relative path  $3 = feature name
  awk -v FILE="$2" -v FEAT="$3" '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    function unquote(s) {
      s = trim(s)
      if (s ~ /^".*"$/ || s ~ /^\x27.*\x27$/) s = substr(s, 2, length(s) - 2)
      return s
    }
    function flush() {
      if (id == "") return
      if (status == "") status = "open"
      if (status != "open" && status != "in_progress" && status != "blocked" && status != "done") {
        printf("!ERR\t%s: task %s has status \x27%s\x27 outside the closed vocabulary (open|in_progress|blocked|done)\n", FILE, id, status)
        id = ""; return
      }
      gsub(/\t/, " ", desc)
      printf("feature\t%s:%s\t%s\t%s\t%s\t%s\t%s\n", FEAT, id, status, bo, FILE, sprint, desc)
      id = ""
    }
    BEGIN { fm = 0; id = ""; desc = ""; status = ""; bo = ""; sprint = ""; inbo = 0 }
    {
      line = $0
      if (NR == 1 && line == "---") { fm = 1; next }
      if (fm == 0) next
      if (line == "---") { flush(); fm = 2; exit }
      sub(/[[:space:]]+#.*$/, "", line)             # strip trailing comment
      if (trim(line) == "") next

      if (line ~ /^[[:space:]]*-[[:space:]]+name:[[:space:]]*/) {
        flush(); inbo = 0
        s = line; sub(/^[[:space:]]*-[[:space:]]+name:[[:space:]]*/, "", s); sprint = unquote(s); next
      }
      if (line ~ /^[[:space:]]*-[[:space:]]+id:[[:space:]]*/) {
        flush(); inbo = 0
        s = line; sub(/^[[:space:]]*-[[:space:]]+id:[[:space:]]*/, "", s)
        id = unquote(s); desc = ""; status = ""; bo = ""; next
      }
      if (id == "") next

      if (line ~ /^[[:space:]]*blocked_on:[[:space:]]*$/) { inbo = 1; next }
      if (line ~ /^[[:space:]]*blocked_on:[[:space:]]*\[/) {
        s = line; sub(/^[[:space:]]*blocked_on:[[:space:]]*\[/, "", s); sub(/\][[:space:]]*$/, "", s)
        n = split(s, a, ",")
        for (i = 1; i <= n; i++) { v = unquote(a[i]); if (v != "") { v = FEAT ":" v; bo = (bo == "" ? v : bo "," v) } }
        inbo = 0; next
      }
      if (inbo == 1) {
        if (line ~ /^[[:space:]]*-[[:space:]]+/) {
          s = line; sub(/^[[:space:]]*-[[:space:]]+/, "", s); v = unquote(s)
          if (v != "") { v = FEAT ":" v; bo = (bo == "" ? v : bo "," v) }
          next
        }
        inbo = 0
      }
      if (line ~ /^[[:space:]]*description:[[:space:]]*/) {
        s = line; sub(/^[[:space:]]*description:[[:space:]]*/, "", s); desc = unquote(s); next
      }
      if (line ~ /^[[:space:]]*status:[[:space:]]*/) {
        s = line; sub(/^[[:space:]]*status:[[:space:]]*/, "", s); status = unquote(s); next
      }
    }
    END { if (fm == 1) flush() }
  ' "$1"
}

# ── PARSER: specs/*/tasks.md  (level "spec") ──────────────────────────────────────────────────────
# SDD checkboxes: `- [ ] T001 Description`, optionally `[P]`. There is no status
# tag in this format, so the checkbox IS the status: `[x]` -> done, else open.
# That is the one place a checkbox is load-bearing, and only because the SDD
# format has nothing else. Ids are qualified `<spec-dir>:<task-id>`.
#
# THE ONE NON-FATAL PARSE PATH: a checkbox line here with no task id is warned
# and skipped, not fatal. tasks.md has no `## Items` boundary, so a checkbox in
# it is not necessarily a task — SDD task files legitimately carry plain
# checklist lines, and failing on those would hold the whole index hostage to
# someone's prose. See FATAL DEFECTS in the header.
parse_tasks() { # $1 = absolute file  $2 = repo-relative path  $3 = spec dir name
  awk -v FILE="$2" -v SPEC="$3" '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    BEGIN { fence = 0; heading = "" }
    {
      line = $0
      if (line ~ /^[[:space:]]*(```|~~~)/) { fence = 1 - fence; next }
      if (fence) next
      if (line ~ /^#+[[:space:]]/) { h = line; sub(/^#+[[:space:]]*/, "", h); heading = trim(h); next }
      if (line !~ /^- \[[ x]\] /) next
      box = substr(line, 4, 1)
      rest = trim(substr(line, 7))
      if (match(rest, /^[A-Z][A-Z0-9]*[0-9][0-9][0-9]+/) == 0) {
        printf("WARN: %s: checkbox line has no task id, skipped: %s\n", FILE, line) > "/dev/stderr"; next
      }
      id = substr(rest, 1, RLENGTH)
      title = trim(substr(rest, RLENGTH + 1))
      sub(/^\[P\][[:space:]]*/, "", title)
      status = (box == "x") ? "done" : "open"
      gsub(/\t/, " ", title)
      printf("spec\t%s:%s\t%s\t\t%s\t%s\t%s\n", SPEC, id, status, FILE, heading, title)
    }
  ' "$1"
}

# ── COLLECTION LOOP — walks SOURCE_TABLE; knows nothing about any class ──────
# Every class-specific fact lives in the table row and its parser. This loop
# only expands a pattern, records the file in SRCLIST (which feeds
# `source_digest`), and hands each match to the declared parser.
expand_source() { # $1 = repo-relative pattern -> absolute paths on stdout, sorted
  case "$1" in
    *'*'*)
      _dir="${1%%/\**}"                       # "features/*/plan.md" -> "features"
      _leaf="${1##*/}"                        #                      -> "plan.md"
      [ -d "$ROOT/$_dir" ] || return 0
      find "$ROOT/$_dir" -mindepth 2 -maxdepth 2 -name "$_leaf" -type f 2>/dev/null \
        | LC_ALL=C sort
      ;;
    *)
      [ -f "$ROOT/$1" ] && printf '%s\n' "$ROOT/$1"
      ;;
  esac
  return 0
}

while IFS='|' read -r s_pat s_level s_parser; do
  [ -n "${s_pat:-}" ] || continue
  case "$s_pat" in \#*) continue ;; esac
  [ -n "${s_level:-}" ] && [ -n "${s_parser:-}" ] || {
    echo "WARN: malformed SOURCE_TABLE row '$s_pat' — want PATTERN|LEVEL|PARSER; skipped" >&2
    continue
  }
  command -v "$s_parser" >/dev/null 2>&1 || {
    echo "WARN: SOURCE_TABLE row '$s_pat' names parser '$s_parser', which is not defined; skipped" >&2
    continue
  }
  while IFS= read -r s_file; do
    [ -n "$s_file" ] || continue
    s_rel="${s_file#$ROOT/}"
    case "$s_pat" in
      *'*'*) s_qual="$(basename "$(dirname "$s_file")")" ;;
      *)     s_qual="" ;;
    esac
    printf '%s\n' "$s_rel" >> "$SRCLIST"
    "$s_parser" "$s_file" "$s_rel" "$s_qual" | collect
  done <<EOF
$(expand_source "$s_pat")
EOF
done <<EOF
$SOURCE_TABLE
EOF

# ── FATAL GATE ───────────────────────────────────────────────────────────────
# Everything above only COLLECTED. Nothing is written until this passes.
#
# Duplicate ids are detected here rather than per-parser because the id space is
# shared across all three sources: `LOOM-0001` from backlog.md and `alpha:t1`
# from a plan land in the same array and are keyed the same way by a consumer.
# A per-file check would miss a cross-file collision entirely.
#
# It also removes a quiet determinism hazard: with duplicate keys, which of two
# equal-id rows sorted first depended on `sort`'s last-resort whole-line
# comparison — stable in practice, but the index still had a primary key that
# answered to two different rows.
TAB="$(printf '\t')"
DUPES="$(cut -d "$TAB" -f2 "$TSV" 2>/dev/null | LC_ALL=C sort | uniq -d)"
if [ -n "$DUPES" ]; then
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    _where="$(grep -F "$TAB$d$TAB" "$TSV" 2>/dev/null \
      | awk -F"$TAB" '{ printf("%s%s (\"%s\")", (NR>1 ? " and " : ""), $5, $7) }')"
    printf '%s\n' "duplicate id '$d' — minted more than once; ids are the consumer's primary key and are never reused. Seen in: ${_where:-<unknown>}" >> "$ERRS"
  done <<EOF
$DUPES
EOF
fi

if [ -s "$ERRS" ]; then
  {
    echo "ERROR: backlog sources have fatal defects — the index was NOT written."
    echo "       A consumer cannot tell a dropped item from a nonexistent one, so"
    echo "       the collector refuses to publish an index that misrepresents its"
    echo "       sources. Any previously generated index is left untouched."
    echo ""
    sed 's/^/  * /' "$ERRS"
    echo ""
    echo "       Fix the sources, then re-run. For the full picture of every"
    echo "       authoring defect (including advisory ones), run:"
    echo "         ./.logic-loom/scripts/bash/lint-backlog.sh"
  } >&2
  exit 3
fi

# ── source digest ────────────────────────────────────────────────────────────
# sha256 over the concatenated content of every source file, in the deterministic
# order they were collected. Zero sources -> the digest of the empty string,
# which is still a stable, comparable value.
SHACMD=""
if command -v shasum >/dev/null 2>&1; then SHACMD="shasum -a 256"
elif command -v sha256sum >/dev/null 2>&1; then SHACMD="sha256sum"; fi
DIGEST=""
if [ -n "$SHACMD" ]; then
  rc=0
  DIGEST="$( { while IFS= read -r s; do [ -n "$s" ] && cat "$ROOT/$s"; done < "$SRCLIST"; } | $SHACMD | awk '{print $1}' )" || rc=$?
  [ "$rc" -eq 0 ] || DIGEST=""
fi
[ -n "$DIGEST" ] || echo "WARN: no sha256 tool found; source_digest will be empty" >&2

# ── generated_at (SOURCE_DATE_EPOCH freezes it for determinism proofs) ───────
GEN=""
if [ -n "${SOURCE_DATE_EPOCH:-}" ]; then
  GEN="$(date -u -r "$SOURCE_DATE_EPOCH" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
      || date -u -d "@$SOURCE_DATE_EPOCH" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)"
fi
[ -n "$GEN" ] || GEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── emit ─────────────────────────────────────────────────────────────────────
SORTED="$TMPD/items.sorted.tsv"   # TAB is set at the fatal gate above
LC_ALL=C sort -t "$TAB" -k2,2 "$TSV" > "$SORTED" 2>/dev/null || cp "$TSV" "$SORTED"

JSON="$TMPD/index.json"
jq -R -n \
  --arg gen "$GEN" --arg dig "$DIGEST" \
  --arg slug "$P_SLUG" --arg name "$P_NAME" --arg prefix "$P_PREFIX" --arg repo "$P_REPO" '
  {
    schema_version: 1,
    generated_at:   $gen,
    source_digest:  $dig,
    project: ({ slug: $slug, name: $name, id_prefix: $prefix }
              + (if $repo == "" then {} else { repo: $repo } end)),
    items: [ inputs
             | select(length > 0)
             | split("\t")
             | { id:         .[1],
                 title:      .[6],
                 status:     .[2],
                 blocked_on: (if (.[3] // "") == "" then [] else (.[3] | split(",")) end),
                 source:     { file: .[4], heading: .[5] },
                 level:      .[0] } ]
  }' < "$SORTED" > "$JSON" || {
    echo "ERROR: jq failed to assemble the index" >&2; exit 1; }

mkdir -p "$(dirname "$OUT")" 2>/dev/null || true
cp "$JSON" "$OUT" || { echo "ERROR: cannot write '$OUT'" >&2; exit 1; }
[ "$ECHO_STDOUT" -eq 1 ] && cat "$OUT"

N="$(jq '.items | length' "$OUT" 2>/dev/null || echo '?')"
echo "backlog index: $N item(s) -> ${OUT#$ROOT/}  (untracked by design; regenerate on demand)" >&2
exit 0
