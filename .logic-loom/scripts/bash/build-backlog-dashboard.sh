#!/usr/bin/env bash
# build-backlog-dashboard.sh — deterministic BACKLOG VIEWER generator.
#
# Reads the machine-readable index produced by build-backlog-index.sh and emits
# ONE self-contained HTML page at artifacts/backlog-dashboard.html.
# Zero LLM. jq + shell only. Fail-open. bash 3.2 safe.
#
# This delivers the viewer already promised by
# .docs/architecture/project-graph-convention.md §5.3 / §7: "one committed,
# inline-JS, CSP-safe single-file HTML viewer … opens offline, no server,
# regenerated on demand."
#
# ─────────────────────────────────────────────────────────────────────────────
# WHY THE INDEX IS INLINED AND NOT FETCHED
# ─────────────────────────────────────────────────────────────────────────────
# The obvious design — ship one static HTML that `fetch()`es its sibling
# backlog-index.json — DOES NOT WORK from `file://`, which is exactly how this
# page is meant to be opened (§5: "opens offline, no server").
#
# A document loaded over `file://` gets an OPAQUE origin. Fetch's scheme
# handling has no fetch scheme for `file:` — the request fails as a network
# error before CORS is even consulted, and no header on a local file could relax
# it because a local file serves no headers at all. Chrome states this as
# "URL scheme must be http or https for CORS request"; Firefox and Safari fail
# the same request under their own wording. XMLHttpRequest is blocked by the
# same opaque-origin rule (Chrome closed the `--allow-file-access-from-files`
# default in 2010). `<script src>` and `<link href>` to a sibling file DO load —
# but JSON is not a script, and turning the index into a `.js` file that assigns
# a global would mean generating a SECOND derived file and shipping a two-file
# "single-file viewer", which is the thing §5 rules out.
#
# So the index is INLINED as a snapshot at generation time. That makes the HTML
# genuinely self-contained: no fetch, no script src, no link href, no CDN, no
# webfont, no remote image — it renders correctly double-clicked from disk, on a
# machine with no network at all.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHERE IT LANDS: `artifacts/`, AND WHY THAT IS THE RIGHT SHELF
# ─────────────────────────────────────────────────────────────────────────────
# `artifacts/` is the repo-root home for STANDALONE DELIVERABLES — a page that
# states something, judged by the *who / what / why / where* test, and never a
# plan (sequencing belongs to plan.md / tasks.md). This page passes that test:
# it reports WHAT work exists, WHAT class it is, WHERE each item came from and
# WHAT state it is in. It orders nothing, assigns nothing and sequences nothing;
# the ordering it shows is the source file order it read. It is the same class of
# object as artifacts/harness-graph.html (what the harness is made of) and
# artifacts/logicloom-vision.html (what we decided), and it is opened the same
# way — double-clicked from disk.
#
# The one thing that makes it unlike its neighbours is that it is GENERATED. It
# is nonetheless COMMITTED, like them — placement follows what the file IS,
# tracking follows how it is PRODUCED, and the second question is answered
# below, not by the first.
#
# TEMPLATE STRIP INTERACTION — now load-bearing, where it once was belt-and-
# braces. `artifacts` is a WHOLESALE entry in template-strip-manifest.txt, so our
# own artifacts never ship to a cloner. That strip is TRACKED-CONTENT ONLY
# (strip-harness-dev.sh walks `git ls-files`). While this page was gitignored it
# was never a strip candidate at all and the two mechanisms were independent;
# now that it is tracked, the wholesale entry is the ONE thing keeping it out of
# a customer's tree. The entry was already wholesale for exactly this
# eventuality — do not narrow it to a glob.
#
# ─────────────────────────────────────────────────────────────────────────────
# THE OUTPUT IS TRACKED — AND WHAT THAT COSTS
# ─────────────────────────────────────────────────────────────────────────────
# `artifacts/backlog-dashboard.html` is GIT-TRACKED. It used to be gitignored,
# on the reasoning that a derived artifact should never be committed. That
# reasoning was sound about the cost and wrong about the balance: an ignored
# page exists only in the checkout that last ran this script, so the maintainer
# went looking for it in their main checkout and it was not there. Work here
# happens on worktrees and feature branches and always lands on dev-main, and
# dev state has to be consistent across that line. It is also what
# .docs/architecture/project-graph-convention.md §5.3/§7 asked for all along:
# "one committed, inline-JS, CSP-safe single-file HTML viewer".
#
# The cost is real and is NOT hand-waved. A tracked derived artifact diverges
# from its sources the moment someone edits a source without regenerating; this
# repo has been bitten by that class three times (dead scrub rules, orphaned
# test suites, a manifest advertising a stripped command). Warn-only linting
# does not hold — a warning IS how the manifest bug shipped. The cost is paid by
# a fail-closed gate that regenerates this page and fails if the committed copy
# differs:
#     .logic-loom/scripts/bash/check-generated-freshness.sh   (CI: plugin-tests.yml)
# Tracking is licensed by that gate. Remove the gate and this output must go
# back to being ignored.
#
# Customers never receive the page: `artifacts` is a WHOLESALE strip entry in
# template-strip-manifest.txt, so the directory is removed when the sanitized
# template is built. That entry — not a per-branch .gitignore, which is not a
# thing git reliably supports — is what keeps our content ours.
#
# Because the snapshot is frozen at generation time, the page says so IN THE
# PAGE — it prints the `source_digest` it was built from and states plainly that
# it does not live-update. An artifact that looks live and is not is worse than
# one that admits it is a snapshot.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHAT THE PAGE IS SHAPED LIKE: CLASS FIRST, THEN STATUS
# ─────────────────────────────────────────────────────────────────────────────
# The index aggregates DIFFERENT DOCUMENTS — a cross-cutting backlog, feature
# plans, spec task lists. `level` is the field that records which. Grouping by
# status alone flattens that away and makes a mixed index read as one list, so
# ITEM CLASS is the outer dimension here and status is the inner one.
#
# Every declared class gets a section EVEN WHEN IT IS EMPTY, and an empty section
# names the path it would have read from. That distinction is the point: without
# it a reader cannot tell "there is no feature work" from "the collector never
# looked at features/". An absent section is ambiguous; an empty one is a fact.
#
# UNKNOWN CLASSES AND UNKNOWN STATUSES ARE CARRIED THROUGH (LOOM-0022).
# The index's compatibility contract is PRODUCER STRICT, CONSUMER LIBERAL: a
# consumer must tolerate a `status` or `level` it does not recognise, carry it
# through verbatim, bucket it under a catch-all, never drop the item and never
# fail. This page is the index's first consumer and now honours that rule on both
# fields — status groups are derived from the DATA (known vocabulary first, in
# order, then any further status found, LC_ALL=C sorted), and any item whose
# `level` is not in the class table lands in an explicit "Other" section rather
# than vanishing. Both paths are asserted in tests/contract/test_backlog_dashboard.sh.
#
# ─────────────────────────────────────────────────────────────────────────────
# DETERMINISM
# ─────────────────────────────────────────────────────────────────────────────
# Same index -> byte-identical HTML. Item order comes from the index (already
# `LC_ALL=C sort`ed by id); class order is the class table's order; status order
# is the known vocabulary followed by `unique`-sorted extras (jq's `unique` is a
# total order over the values themselves, not locale-dependent). `generated_at`
# is CARRIED FROM THE INDEX and never re-stamped — the page dates the data, not
# the render.
#
# ─────────────────────────────────────────────────────────────────────────────
# LIVE DATA, WITHOUT BREAKING THE GATE: GITHUB ISSUES ARE FETCHED AT VIEW TIME
# ─────────────────────────────────────────────────────────────────────────────
# The markdown half (todos.md / backlog.md) is a snapshot, frozen at generation
# time, by design (see above). But a reader also wants to know what is open on
# GitHub RIGHT NOW, and freezing THAT at generation time would mean the page
# goes stale the moment anyone comments on an issue — worse, it would put issue
# data inside a byte-diffed, fail-closed-gated file, so an unrelated comment on
# GitHub would turn CI red on a commit that touched neither the backlog markdown
# nor this generator. LOOM-0049 resolves this by moving the fetch to VIEW time:
#
#   * this script bakes ONE constant into the page — the `owner/repo` string
#     read from the index's `.project.repo` field (itself sourced from
#     project.conf, or overridden by build-backlog-index.sh's `--repo` flag) —
#     validated to look like `owner/repo` and baked as `null` otherwise.
#   * the page's own inline script (its ONLY <script>, alongside the theme
#     toggle above) calls `fetch()` against
#     `https://api.github.com/repos/{owner}/{repo}/issues` WHEN THE FILE IS
#     OPENED, never here. This script issues no network request of any kind.
#   * that keeps the invariant check-generated-freshness.sh depends on: the
#     GENERATED BYTES are a pure function of todos.md + backlog.md (modulo the
#     generated_at normalisation the gate already applies) and of nothing else.
#     Issue data never touches the file this script writes.
#
# An optional token, read from `localStorage` (never baked into the file),
# raises the anonymous 60 req/hour GitHub limit to 5,000/hour and makes private
# repos readable. Every failure mode renders a STATED reason in the panel —
# no remote / not a GitHub remote, network error, rate limit, private repo, a
# malformed response — never a silently empty list.
#
# ─────────────────────────────────────────────────────────────────────────────
# BOUNDARIES
# ─────────────────────────────────────────────────────────────────────────────
#   * writes NOTHING except the output path (plus scratch under $TMPDIR)
#   * runs NO git, ever — the `owner/repo` baked into the page comes from the
#     INDEX (`.project.repo`), never from a git call this script makes itself
#   * makes NO network request itself — the issues fetch happens in the
#     reader's browser when the generated page is opened, not while this
#     script runs (see LIVE DATA above)
#   * does not run the collector and does not touch the index
#   * every interpolated value is HTML-escaped with jq's @html — titles are
#     human-authored markdown and legitimately contain <, &, quotes, backticks
#
# Usage:
#   build-backlog-dashboard.sh [ROOT] [--index FILE] [--out FILE] [--stdout]
#     ROOT         repo root (default: resolved from this script's location)
#     --index FILE index to read (default: <ROOT>/.logic-loom/backlog-index.json)
#     --out FILE   output path (default: <ROOT>/artifacts/backlog-dashboard.html)
#     --stdout     also echo the page to stdout
#
# Exit: 0 always, except a usage error (2) or an unwritable output path (1).
#       A MISSING INDEX is fail-open: a clear message naming the collector, no
#       output written, exit 0. A viewer generator must not gate a workflow.
set -uo pipefail

ROOT=""; OUT=""; IDX=""; ECHO_STDOUT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --out)     OUT="${2:-}"; shift 2 || true ;;
    --out=*)   OUT="${1#--out=}"; shift ;;
    --index)   IDX="${2:-}"; shift 2 || true ;;
    --index=*) IDX="${1#--index=}"; shift ;;
    --stdout)  ECHO_STDOUT=1; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    -*) echo "ERROR: unknown option '$1'" >&2; exit 2 ;;
    *)  [ -z "$ROOT" ] && ROOT="$1"; shift ;;
  esac
done

if [ -z "$ROOT" ]; then
  _sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT="$(cd "$_sd/../../.." && pwd)"   # scripts/bash -> .logic-loom -> repo root
fi
[ -d "$ROOT" ] || { echo "WARN: root '$ROOT' missing; nothing to render" >&2; exit 0; }
[ -n "$IDX" ] || IDX="$ROOT/.logic-loom/backlog-index.json"
[ -n "$OUT" ] || OUT="$ROOT/artifacts/backlog-dashboard.html"

command -v jq >/dev/null 2>&1 || {
  echo "WARN: jq not found — cannot render the backlog dashboard. Install jq (brew install jq) and re-run." >&2
  exit 0
}

if [ ! -f "$IDX" ]; then
  echo "WARN: backlog index not found at '${IDX#$ROOT/}'." >&2
  echo "      The dashboard renders a SNAPSHOT of the index; it does not collect." >&2
  echo "      Run the collector first:" >&2
  echo "        .logic-loom/scripts/bash/build-backlog-index.sh" >&2
  echo "      then re-run this script. Nothing was written." >&2
  exit 0
fi

rc=0
jq -e . "$IDX" >/dev/null 2>&1 || rc=$?
if [ "$rc" -ne 0 ]; then
  echo "WARN: '${IDX#$ROOT/}' is not valid JSON — regenerate it with" >&2
  echo "      .logic-loom/scripts/bash/build-backlog-index.sh . Nothing was written." >&2
  exit 0
fi

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t loombld)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

# ── scalar header fields, HTML-escaped at the source ─────────────────────────
meta() { jq -r "$1 // \"\" | tostring | @html" "$IDX" 2>/dev/null || printf ''; }
P_NAME="$(meta '.project.name')"
P_SLUG="$(meta '.project.slug')"
P_PREFIX="$(meta '.project.id_prefix')"
P_REPO="$(meta '.project.repo')"
GEN="$(meta '.generated_at')"
DIGEST="$(meta '.source_digest')"
SCHEMA="$(meta '.schema_version')"
N_TOTAL="$(jq -r '.items | length' "$IDX" 2>/dev/null || echo 0)"

# ── GH_REPO — the ONLY thing view-time issue fetching needs, baked as a JS
#    literal ("owner/repo" or null). Read RAW (not @html-escaped — meta() above
#    escapes for HTML body text, and this value goes into a JS string literal
#    instead, so it needs JSON escaping, which jq -n --arg gives it for free).
#    Validated to look like `owner/repo`; anything else (unset, a bare URL, a
#    free-text label) bakes `null` and the page's own script explains why it has
#    no issues panel rather than trying a request that cannot succeed.
GH_REPO_JSON="$(
  jq -n --arg r "$(jq -r '.project.repo // empty' "$IDX" 2>/dev/null)" \
    'if ($r | test("^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$")) then $r else null end' \
    2>/dev/null
)"
[ -n "$GH_REPO_JSON" ] || GH_REPO_JSON='null'

TITLE="$P_NAME"
[ -n "$TITLE" ] || TITLE="$P_SLUG"
[ -n "$TITLE" ] || TITLE="LogicLoom"

# =============================================================================
# CLASS TABLE — the item classes this viewer knows how to label.
# =============================================================================
# One row per class, three pipe-separated columns:
#
#   1  LEVEL   the index's `level` value (the contract field; never invented here)
#   2  LABEL   the human heading for the section
#   3  SOURCE  the path the collector reads that class from, shown verbatim on
#              the page — and shown ESPECIALLY when the class is EMPTY, so a
#              reader can tell "no work of this kind" from "nothing looked".
#
# ROW ORDER IS SECTION ORDER ON THE PAGE, and the first two rows are ordered on
# purpose: TODOS FIRST, then BACKLOG. They are the two halves of one stream —
# active work and deferred work, sharing a grammar and an id space — and a page
# that opened with the deferred half would bury the only section a reader opens
# it to act on. Everything else follows in collector authority order.
#
# This table MIRRORS the SOURCE TABLE in
# build-backlog-index.sh — level and path must agree, and
# tests/contract/test_backlog_dashboard.sh asserts that the two files declare the
# same (level, path) pairs so the mirror cannot drift silently.
#
# A level NOT in this table is not an error and is never dropped: it renders in
# the "Other" catch-all section below, per the index's consumer-liberal rule.
CLASS_TABLE='
todo|Todos — active work|.logic-loom/memory/todos.md
backlog|Backlog — deferred work|.logic-loom/memory/backlog.md
feature|Feature plans|features/*/plan.md
spec|Spec tasks|specs/*/tasks.md
'

CLASSES_JSON="$(
  printf '%s\n' "$CLASS_TABLE" \
  | awk -F'|' '$0 !~ /^[[:space:]]*(#|$)/ && NF >= 3 { printf("%s\t%s\t%s\n", $1, $2, $3) }' \
  | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t")
                 | { level: .[0], label: .[1], path: .[2] })'
)" || CLASSES_JSON='[]'
[ -n "$CLASSES_JSON" ] || CLASSES_JSON='[]'

# -- shared jq preamble: escaping, id slugs, status ordering ------------------
# STATUS ORDER IS DERIVED FROM THE DATA, not from a fixed list (LOOM-0022): the
# four known values first, in vocabulary order, then every OTHER status actually
# present, uniquely sorted. An unrecognised status therefore gets its own group
# and its own label instead of being silently omitted.
JQ_LIB='
  def esc: tostring | @html;
  def slug: tostring | gsub("[^A-Za-z0-9_-]"; "-");
  def known_status: ["open","in_progress","blocked","done"];
  def slabel: . as $s
    | ({"open":"Open","in_progress":"In progress","blocked":"Blocked","done":"Done"}[$s]
       // ($s + " (unrecognised status)"));
  def status_order($g):
    known_status as $k
    | $k + ($g | map(.status) | unique | map(select(. as $s | ($k | index($s)) == null)));
'

# -- summary -----------------------------------------------------------------
# Totals by status and by class, computed HERE and nowhere else. The index
# deliberately carries no rollups (see DELIBERATELY ABSENT in the collector) —
# aggregation is the consumer's job, which is what this is.
SUMMARY="$TMPD/summary.html"
jq -r --argjson classes "$CLASSES_JSON" "$JQ_LIB"'
  . as $x
  | ($x.items) as $it
  | ($classes | map(.level)) as $known_levels
  | "  <div class=\"summary\">\n"
  + "    <p class=\"tally-h\">Totals <span class=\"count\">" + ($it | length | tostring) + " item(s)</span></p>\n"
  + "    <ul class=\"tally by-status\">\n"
  + ( status_order($it)
      | map( . as $s
             | "      <li class=\"t-status\"><span class=\"badge b-" + ($s | slug) + "\">"
               + ($s | esc) + "</span> <b>" + ($it | map(select(.status == $s)) | length | tostring)
               + "</b></li>\n" )
      | join("") )
  + "    </ul>\n"
  + "    <ul class=\"tally by-class\">\n"
  + ( $classes
      | map( . as $c
             | "      <li class=\"t-class\"><a href=\"#cls-" + ($c.level | slug) + "\">"
               + ($c.label | esc) + "</a> <b>"
               + ($it | map(select(.level == $c.level)) | length | tostring) + "</b></li>\n" )
      | join("") )
  + ( ($it | map(select(.level as $l | ($known_levels | index($l)) == null))) as $o
      | if ($o | length) == 0 then ""
        else "      <li class=\"t-class t-other\"><a href=\"#cls-other\">Other</a> <b>"
             + ($o | length | tostring) + "</b></li>\n" end )
  + "    </ul>\n"
  + "  </div>\n"
' "$IDX" > "$SUMMARY" || { echo "ERROR: jq failed to render the summary" >&2; exit 1; }

# -- class sections, each grouped by status -----------------------------------
BODY="$TMPD/body.html"
jq -r --argjson classes "$CLASSES_JSON" "$JQ_LIB"'
  def blockers($ids):
    map( . as $b
         | if ($ids | index($b)) != null
           then "<a class=\"ref\" href=\"#item-" + ($b | esc) + "\">" + ($b | esc) + "</a>"
           elif ($b | startswith("external:"))
           then "<span class=\"ref external\" title=\"blocked on something outside this index\">"
                + ($b | ltrimstr("external:") | esc) + "</span>"
           else "<span class=\"ref dangling\" title=\"not present in this index\">" + ($b | esc) + "</span>"
           end )
    | join(", ");

  def item($ids):
      "    <article class=\"item\" id=\"item-" + (.id | esc) + "\">\n"
    + "      <div class=\"meta\">"
    + "<code class=\"iid\">" + (.id | esc) + "</code>"
    + "<span class=\"badge b-" + (.status | slug) + "\">" + (.status | esc) + "</span>"
    + "<span class=\"lvl\">" + (.level | esc) + "</span>"
    + "</div>\n"
    + "      <p class=\"title\">" + (.title | esc) + "</p>\n"
    + "      <p class=\"src\"><code>" + (.source.file | esc) + "</code>"
    + ( if ((.source.heading // "") | length) > 0
        then " &middot; <span class=\"heading\">" + (.source.heading | esc) + "</span>"
        else "" end )
    + "</p>\n"
    + ( if ((.blocked_on // []) | length) > 0
        then "      <p class=\"bo\"><span class=\"bo-l\">blocked on</span> "
             + (.blocked_on | blockers($ids)) + "</p>\n"
        else "" end )
    + "    </article>\n";

  # Status subgroups WITHIN one class. Only non-empty groups render — the class
  # section states its own total, and the page-level tally already lists every
  # status including the zeroes.
  def status_groups($g; $ids; $cid):
    status_order($g)
    | map( . as $s
           | ($g | map(select(.status == $s))) as $sg
           | if ($sg | length) == 0 then ""
             else "  <section class=\"grp\" id=\"grp-" + $cid + "-" + ($s | slug) + "\">\n"
                + "    <h3 class=\"grp-h\">" + ($s | slabel | esc)
                + " <span class=\"count\">" + ($sg | length | tostring) + "</span></h3>\n"
                + ($sg | map(item($ids)) | join(""))
                + "  </section>\n"
             end )
    | join("");

  . as $x
  | ($x.items | map(.id)) as $ids
  | ($classes | map(.level)) as $known_levels
  | ( $classes
      | map( . as $c
             | ($c.level | slug) as $cid
             | ($x.items | map(select(.level == $c.level))) as $g
             | "<section class=\"cls\" id=\"cls-" + $cid + "\">\n"
             + "  <h2 class=\"cls-h\">" + ($c.label | esc)
             + " <span class=\"count cls-count\">" + ($g | length | tostring) + "</span>"
             + " <span class=\"lvl-tag\">level: " + ($c.level | esc) + "</span></h2>\n"
             + "  <p class=\"cls-src\">source: <code>" + ($c.path | esc) + "</code></p>\n"
             + ( if ($g | length) == 0
                 then "  <p class=\"empty\">No items of this class. <code>" + ($c.path | esc)
                      + "</code> was read and contributed nothing — this section is empty because"
                      + " there is no work of this kind, not because the collector never looked.</p>\n"
                 else status_groups($g; $ids; $cid) end )
             + "</section>\n" )
      | join("") )
  + ( ($x.items | map(select(.level as $l | ($known_levels | index($l)) == null))) as $o
      | if ($o | length) == 0 then ""
        else "<section class=\"cls\" id=\"cls-other\">\n"
           + "  <h2 class=\"cls-h\">Other"
           + " <span class=\"count cls-count\">" + ($o | length | tostring) + "</span>"
           + " <span class=\"lvl-tag\">unrecognised level</span></h2>\n"
           + "  <p class=\"cls-src\">These items carry a <code>level</code> this viewer has no"
           + " section for. The index contract is producer-strict, consumer-liberal: an unknown"
           + " level is carried through verbatim and bucketed here, never coerced and never"
           + " dropped. Levels seen: <code>"
           + ($o | map(.level) | unique | map(esc) | join("</code>, <code>")) + "</code>.</p>\n"
           + status_groups($o; $ids; "other")
           + "</section>\n"
        end )
' "$IDX" > "$BODY" || { echo "ERROR: jq failed to render the item sections" >&2; exit 1; }

# ── assemble ─────────────────────────────────────────────────────────────────
# Static shell (CSS + the one small inline script) via a QUOTED heredoc so
# nothing in it is expanded; dynamic values are printf'd already-escaped.
PAGE="$TMPD/page.html"

cat > "$PAGE" <<'HEAD_EOF'
<!DOCTYPE html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
HEAD_EOF

printf '<title>%s — Backlog</title>\n' "$TITLE" >> "$PAGE"

cat >> "$PAGE" <<'CSS_EOF'
<style>
  :root {
    --ink:#15171c; --ink-soft:#3d4250; --thread:#6e7a99; --thread-dim:#9aa2b8;
    --ground:#f3f2ee; --panel:#fbfaf8; --rule:#d8d6d0;
    --indigo:#27358f; --indigo-tint:#e6e8f5;
    --madder:#a32c33; --ochre:#8f6317; --verdigris:#2c6a56; --slate:#4a5570;
    --madder-bg:#f7e7e7; --ochre-bg:#f7eedb; --verd-bg:#e2efe9; --slate-bg:#e8eaf0;
    --sans:system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif;
    --mono:ui-monospace,"SF Mono",SFMono-Regular,Menlo,Consolas,monospace;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --ink:#eceef4; --ink-soft:#b3b9c9; --thread:#8b95b3; --thread-dim:#616a85;
      --ground:#101218; --panel:#171a22; --rule:#2b3040;
      --indigo:#93a2ee; --indigo-tint:#1c2340;
      --madder:#e2757e; --ochre:#d5a44b; --verdigris:#5cb195; --slate:#8892b0;
      --madder-bg:#2c1b1e; --ochre-bg:#2b2317; --verd-bg:#14291f; --slate-bg:#1b1f2b;
    }
  }
  :root[data-theme="dark"] {
    --ink:#eceef4; --ink-soft:#b3b9c9; --thread:#8b95b3; --thread-dim:#616a85;
    --ground:#101218; --panel:#171a22; --rule:#2b3040;
    --indigo:#93a2ee; --indigo-tint:#1c2340;
    --madder:#e2757e; --ochre:#d5a44b; --verdigris:#5cb195; --slate:#8892b0;
    --madder-bg:#2c1b1e; --ochre-bg:#2b2317; --verd-bg:#14291f; --slate-bg:#1b1f2b;
  }
  :root[data-theme="light"] {
    --ink:#15171c; --ink-soft:#3d4250; --thread:#6e7a99; --thread-dim:#9aa2b8;
    --ground:#f3f2ee; --panel:#fbfaf8; --rule:#d8d6d0;
    --indigo:#27358f; --indigo-tint:#e6e8f5;
    --madder:#a32c33; --ochre:#8f6317; --verdigris:#2c6a56; --slate:#4a5570;
    --madder-bg:#f7e7e7; --ochre-bg:#f7eedb; --verd-bg:#e2efe9; --slate-bg:#e8eaf0;
  }
  * { box-sizing:border-box; }
  body {
    margin:0; background:var(--ground); color:var(--ink);
    font-family:var(--sans); font-size:15px; line-height:1.5;
    -webkit-font-smoothing:antialiased;
  }
  .wrap { max-width:60rem; margin:0 auto; padding:2rem 1.25rem 4rem; }
  header { border-bottom:1px solid var(--rule); padding-bottom:1rem; margin-bottom:1.25rem; }
  h1 { font-size:1.4rem; margin:0 0 .35rem; letter-spacing:-.01em; }
  .sub { color:var(--ink-soft); font-size:.85rem; margin:0; }
  .facts { display:flex; flex-wrap:wrap; gap:.4rem 1.25rem; margin:.8rem 0 0; padding:0; list-style:none;
           font-family:var(--mono); font-size:.75rem; color:var(--ink-soft); }
  .facts b { font-weight:600; color:var(--ink); }
  .facts .digest { word-break:break-all; }
  .snapshot {
    margin:1rem 0 0; padding:.7rem .85rem; border:1px solid var(--rule);
    border-left:3px solid var(--ochre); background:var(--ochre-bg);
    color:var(--ink); font-size:.82rem; border-radius:2px;
  }
  .snapshot code { font-family:var(--mono); font-size:.95em; }
  .toolbar { display:flex; gap:.5rem; align-items:center; margin-top:1rem; }
  button {
    font:inherit; font-size:.8rem; padding:.3rem .7rem; cursor:pointer;
    color:var(--ink); background:var(--panel);
    border:1px solid var(--rule); border-radius:3px;
  }
  button:hover { border-color:var(--thread); }
  /* Summary: total, by status, by class. The index carries no rollups by
     design — these numbers are computed here, from the items on this page. */
  .summary { border:1px solid var(--rule); border-radius:3px; background:var(--panel);
             padding:.75rem .9rem; margin:0 0 1.5rem; }
  .tally-h { margin:0 0 .5rem; font-size:.85rem; font-weight:600; }
  .tally { display:flex; flex-wrap:wrap; gap:.4rem .9rem; margin:0 0 .4rem;
           padding:0; list-style:none; font-size:.8rem; align-items:center; }
  .tally:last-child { margin-bottom:0; }
  .tally b { font-family:var(--mono); font-weight:600; }
  .tally a { color:var(--indigo); text-decoration:none; border-bottom:1px solid var(--rule); }
  .by-class { padding-top:.4rem; border-top:1px dashed var(--rule); }
  .t-other a { color:var(--madder); }

  /* CLASS is the outer dimension; status groups nest inside it. */
  .cls { margin:2rem 0 0; }
  .cls-h { font-size:1.05rem; margin:0 0 .2rem; padding-bottom:.35rem;
           border-bottom:2px solid var(--indigo); letter-spacing:-.005em; }
  .cls-src { margin:0 0 .4rem; font-size:.76rem; color:var(--ink-soft); }
  .cls-src code { font-family:var(--mono); }
  .lvl-tag { font-family:var(--mono); font-size:.7rem; font-weight:400; color:var(--thread-dim); }
  .grp { margin:1rem 0 0; }
  .grp-h { font-size:.9rem; margin:0 0 .5rem; padding-bottom:.25rem;
           border-bottom:1px solid var(--rule); letter-spacing:.02em; font-weight:600; }
  .count { font-family:var(--mono); font-size:.78rem; color:var(--ink-soft); font-weight:400; }
  .empty { color:var(--thread-dim); font-size:.85rem; margin:.2rem 0 0; font-style:italic; }
  .empty code { font-family:var(--mono); font-style:normal; }
  .item {
    background:var(--panel); border:1px solid var(--rule); border-radius:3px;
    padding:.7rem .85rem; margin:0 0 .5rem;
  }
  .item:target { border-color:var(--indigo); background:var(--indigo-tint); }
  .meta { display:flex; flex-wrap:wrap; gap:.5rem; align-items:center; }
  .iid { font-family:var(--mono); font-size:.8rem; color:var(--indigo); font-weight:600; }
  .badge {
    font-family:var(--mono); font-size:.68rem; text-transform:uppercase;
    letter-spacing:.04em; padding:.1rem .4rem; border-radius:2px; border:1px solid transparent;
  }
  .b-open        { background:var(--slate-bg);  color:var(--slate); }
  .b-in_progress { background:var(--ochre-bg);  color:var(--ochre); }
  .b-blocked     { background:var(--madder-bg); color:var(--madder); }
  .b-done        { background:var(--verd-bg);   color:var(--verdigris); }
  .lvl { font-family:var(--mono); font-size:.68rem; color:var(--thread-dim); }
  .title { margin:.35rem 0 .3rem; }
  .src { margin:0; font-size:.76rem; color:var(--ink-soft); }
  .src code { font-family:var(--mono); }
  .heading { color:var(--thread); }
  .bo { margin:.35rem 0 0; font-size:.78rem; }
  .bo-l { color:var(--ink-soft); }
  .ref { font-family:var(--mono); color:var(--indigo); }
  .ref.dangling { color:var(--madder); text-decoration:line-through; }
  /* An `external:` blocker is OUTSIDE the index by design, not a broken
     reference — it must not render as one. Plain text, no link, no strike. */
  .ref.external { font-family:inherit; color:var(--ink-soft); font-style:italic; }
  footer { margin-top:2.5rem; padding-top:1rem; border-top:1px solid var(--rule);
           color:var(--thread-dim); font-size:.75rem; }
  footer code { font-family:var(--mono); }

  /* Issues panel — populated at VIEW time by the page's own script, never at
     generation time. See build-backlog-dashboard.sh "LIVE DATA" for why. */
  .issues { margin:2rem 0 0; padding:.85rem .9rem; border:1px solid var(--rule);
            border-radius:3px; background:var(--panel); }
  .issues-h { font-size:1.05rem; margin:0 0 .5rem; }
  .issues-status { margin:0 0 .6rem; font-size:.82rem; color:var(--ink-soft); }
  .issues-token { display:flex; flex-wrap:wrap; gap:.4rem; align-items:center;
                  margin:0 0 .8rem; padding:.5rem .6rem; border:1px dashed var(--rule);
                  border-radius:3px; font-size:.78rem; color:var(--ink-soft); }
  .issues-token label { flex:1 1 100%; }
  .issues-token input { font:inherit; font-size:.8rem; padding:.25rem .5rem;
                         border:1px solid var(--rule); border-radius:3px;
                         background:var(--ground); color:var(--ink); min-width:14rem; }
  .issues-list { list-style:none; margin:0; padding:0; }
  .issue-item { display:flex; flex-wrap:wrap; gap:.4rem .5rem; align-items:baseline;
                padding:.4rem 0; border-top:1px solid var(--rule); }
  .issue-item:first-child { border-top:none; }
  .issue-num { font-family:var(--mono); font-size:.78rem; color:var(--indigo); }
  .issue-title { color:var(--ink); text-decoration:none; border-bottom:1px solid var(--rule); }
  .issue-title:hover { border-color:var(--thread); }
  .issue-labels { display:flex; flex-wrap:wrap; gap:.25rem; }
  .issue-label { font-family:var(--mono); font-size:.68rem; padding:.05rem .35rem;
                 border-radius:2px; background:var(--slate-bg); color:var(--slate); }
</style>
CSS_EOF

{
  printf '<div class="wrap">\n<header>\n'
  printf '  <h1>%s — backlog</h1>\n' "$TITLE"
  printf '  <p class="sub">A snapshot of the collected backlog index — every item class the\n'
  printf '  collector aggregates, each from its own source document. %s item(s).</p>\n' "$N_TOTAL"
  printf '  <ul class="facts">\n'
  [ -n "$P_SLUG" ]   && printf '    <li><b>project</b> %s</li>\n' "$P_SLUG"
  [ -n "$P_PREFIX" ] && printf '    <li><b>id prefix</b> %s</li>\n' "$P_PREFIX"
  [ -n "$P_REPO" ]   && printf '    <li><b>repo</b> %s</li>\n' "$P_REPO"
  printf '    <li><b>generated_at</b> %s</li>\n' "$GEN"
  printf '    <li><b>schema_version</b> %s</li>\n' "$SCHEMA"
  printf '  </ul>\n'
  printf '  <p class="facts digest"><b>source_digest</b>&nbsp;%s</p>\n' "$DIGEST"
  printf '  <p class="snapshot"><b>The item sections below are a snapshot, not a live view.</b>\n'
  printf '  The index was inlined when this file was generated; it does not re-read anything and\n'
  printf '  it does not update itself. If the digest above no longer matches the sources, what\n'
  printf '  you are reading is out of date. Regenerate with\n'
  printf '  <code>.logic-loom/scripts/bash/build-backlog-index.sh</code> then\n'
  printf '  <code>.logic-loom/scripts/bash/build-backlog-dashboard.sh</code>. The open-issues panel\n'
  printf '  below is the one exception — it fetches from GitHub every time this page is opened.</p>\n'
  printf '  <div class="toolbar"><button type="button" id="theme">Toggle theme</button></div>\n'
  printf '</header>\n<main>\n'
  printf '<section class="issues" id="issues">\n'
  printf '  <h2 class="issues-h">Open GitHub issues <span class="count" id="issues-count"></span></h2>\n'
  printf '  <p class="issues-status" id="issues-status">Loading…</p>\n'
  printf '  <div class="issues-token">\n'
  printf '    <label for="gh-token">Optional GitHub token — raises the 60/hour anonymous limit to\n'
  printf '    5,000/hour and lets this panel read a private repo. Stored only in this browser\n'
  printf '    (localStorage); never written into this file.</label>\n'
  printf '    <input type="password" id="gh-token" placeholder="ghp_...">\n'
  printf '    <button type="button" id="gh-token-save">Save</button>\n'
  printf '    <button type="button" id="gh-token-clear">Clear</button>\n'
  printf '  </div>\n'
  printf '  <ul class="issues-list" id="issues-list"></ul>\n'
  printf '</section>\n'
  cat "$SUMMARY"
  cat "$BODY"
  printf '</main>\n<footer>\n'
  printf '  Generated by <code>.logic-loom/scripts/bash/build-backlog-dashboard.sh</code> from\n'
  printf '  <code>.logic-loom/backlog-index.json</code> into\n'
  printf '  <code>artifacts/backlog-dashboard.html</code>. The index is a machine intermediate,\n'
  printf '  gitignored and regenerated on demand; this page is committed, and CI fails if it\n'
  printf '  no longer matches its sources.\n'
  printf '</footer>\n</div>\n'
} >> "$PAGE"

# The page's ONLY <script> tag. It stays a single tag across both features
# below (theme toggle + issues panel) — see the escaping test, which pins the
# page to exactly one <script>. Everything up to the GH_REPO line is STATIC
# (a quoted heredoc, nothing expanded); GH_REPO_JSON is the one value baked in
# from this run, printf'd unquoted between the two static halves.
cat >> "$PAGE" <<'JS_EOF'
<script>
  // Feature 1: a light/dark override on top of prefers-color-scheme.
  // No network, no storage of anything but the preference.
  (function () {
    var root = document.documentElement;
    try {
      var saved = localStorage.getItem("loom-backlog-theme");
      if (saved === "light" || saved === "dark") root.setAttribute("data-theme", saved);
    } catch (e) { /* file:// with storage disabled — the media query still works */ }
    var btn = document.getElementById("theme");
    if (!btn) return;
    btn.addEventListener("click", function () {
      var cur = root.getAttribute("data-theme");
      if (!cur) {
        cur = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches
          ? "dark" : "light";
      }
      var next = cur === "dark" ? "light" : "dark";
      root.setAttribute("data-theme", next);
      try { localStorage.setItem("loom-backlog-theme", next); } catch (e) { /* ignore */ }
    });
  })();

  // Feature 2: the open-issues panel. Fetches GitHub's REST API WHEN THIS PAGE
  // IS OPENED — never at generation time (see build-backlog-dashboard.sh
  // "LIVE DATA" for why that split matters to the freshness gate). The only
  // value baked in below is GH_REPO itself; everything else in this function
  // runs at view time in the reader's own browser.
  (function () {
JS_EOF

printf '    var GH_REPO = %s; // "owner/repo" from project.conf, or null\n' "$GH_REPO_JSON" >> "$PAGE"

cat >> "$PAGE" <<'JS_EOF'
    var statusEl = document.getElementById("issues-status");
    var listEl = document.getElementById("issues-list");
    var countEl = document.getElementById("issues-count");
    var tokenInput = document.getElementById("gh-token");
    var saveBtn = document.getElementById("gh-token-save");
    var clearBtn = document.getElementById("gh-token-clear");
    if (!statusEl || !listEl) return;

    var TOKEN_KEY = "loom-backlog-gh-token";
    function getToken() {
      try { return localStorage.getItem(TOKEN_KEY) || ""; } catch (e) { return ""; }
    }
    function setToken(v) {
      try {
        if (v) { localStorage.setItem(TOKEN_KEY, v); } else { localStorage.removeItem(TOKEN_KEY); }
      } catch (e) { /* storage disabled (e.g. file:// with storage off) — token just won't persist */ }
    }
    if (tokenInput) tokenInput.value = getToken();
    if (saveBtn) saveBtn.addEventListener("click", function () {
      setToken(tokenInput.value.replace(/^\s+|\s+$/g, ""));
      load();
    });
    if (clearBtn) clearBtn.addEventListener("click", function () {
      setToken("");
      if (tokenInput) tokenInput.value = "";
      load();
    });

    function setStatus(msg) { statusEl.textContent = msg; }

    function renderIssues(items) {
      listEl.textContent = "";
      if (countEl) countEl.textContent = String(items.length);
      if (items.length === 0) { setStatus("No open issues."); return; }
      setStatus("");
      items.forEach(function (issue) {
        var li = document.createElement("li");
        li.className = "issue-item";

        var num = document.createElement("code");
        num.className = "issue-num";
        num.textContent = "#" + issue.number;
        li.appendChild(num);

        var a = document.createElement("a");
        a.className = "issue-title";
        a.setAttribute("href", issue.html_url || "#");
        a.target = "_blank";
        a.rel = "noopener noreferrer";
        a.textContent = issue.title || "(untitled)";
        li.appendChild(a);

        if (issue.labels && issue.labels.length) {
          var labelsWrap = document.createElement("span");
          labelsWrap.className = "issue-labels";
          issue.labels.forEach(function (l) {
            var chip = document.createElement("span");
            chip.className = "issue-label";
            chip.textContent = (typeof l === "string") ? l : (l && l.name) || "";
            labelsWrap.appendChild(chip);
          });
          li.appendChild(labelsWrap);
        }

        listEl.appendChild(li);
      });
    }

    function load() {
      listEl.textContent = "";
      if (countEl) countEl.textContent = "";
      if (!GH_REPO) {
        setStatus("No GitHub repository detected for this project — declare one in " +
          ".logic-loom/config/project.conf's `repo` key (owner/repo), or this project has no " +
          "GitHub remote. Issues cannot be fetched.");
        return;
      }
      setStatus("Loading open issues from GitHub…");
      var url = "https://api.github.com/repos/" + GH_REPO + "/issues?state=open&per_page=100";
      var headers = { "Accept": "application/vnd.github+json" };
      var token = getToken();
      if (token) headers["Authorization"] = "Bearer " + token;
      fetch(url, { headers: headers })
        .then(function (res) {
          if (!res.ok) {
            if (res.status === 403 && res.headers.get("x-ratelimit-remaining") === "0") {
              throw new Error("GitHub API rate limit reached (60/hour without a token). " +
                "Add a token above to raise it to 5,000/hour.");
            }
            if (res.status === 404) {
              throw new Error("GitHub returned 404 — private repository, or the wrong remote. " +
                "Add a token above if this is a private repo you can access.");
            }
            throw new Error("GitHub returned HTTP " + res.status + ".");
          }
          return res.json();
        })
        .then(function (data) {
          if (!Array.isArray(data)) throw new Error("GitHub returned an unexpected response.");
          // The issues endpoint also returns pull requests; exclude anything
          // carrying a pull_request key so this panel stays issues-only.
          renderIssues(data.filter(function (it) { return !it.pull_request; }));
        })
        .catch(function (err) {
          setStatus((err && err.message) ? err.message :
            "Could not load issues — network error, or no network at all.");
        });
    }

    load();
  })();
</script>
JS_EOF

mkdir -p "$(dirname "$OUT")" 2>/dev/null || true
cp "$PAGE" "$OUT" || { echo "ERROR: cannot write '$OUT'" >&2; exit 1; }
[ "$ECHO_STDOUT" -eq 1 ] && cat "$OUT"

echo "backlog dashboard: $N_TOTAL item(s) -> ${OUT#$ROOT/}  (tracked snapshot; commit the result)" >&2
exit 0
