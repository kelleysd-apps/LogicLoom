#!/usr/bin/env bash
# build-backlog-dashboard.sh — deterministic BACKLOG VIEWER generator.
#
# Reads the machine-readable index produced by build-backlog-index.sh and emits
# ONE self-contained HTML page at .logic-loom/backlog-dashboard.html.
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
# THE OUTPUT IS UNTRACKED — ON PURPOSE, AND FOR THE SAME REASON AS THE INDEX
# ─────────────────────────────────────────────────────────────────────────────
# Inlining makes this page a SECOND derived artifact, one further removed from
# the sources than the index is. `.logic-loom/backlog-dashboard.html` is
# gitignored and MUST STAY THAT WAY.
#
# A tracked derived artifact diverges from its sources the moment someone edits
# a source without regenerating; this repo has been bitten by that class three
# times (dead scrub rules, orphaned test suites, a manifest advertising a
# stripped command). Each needed a NEW GUARD to make the drift detectable.
# Untracked + regenerate-on-demand needs no guard: the page cannot be stale
# relative to the working tree because it is rebuilt from it, and it cannot be
# stale in someone else's clone because it does not travel there.
#
# Because the snapshot is frozen at generation time, the page says so IN THE
# PAGE — it prints the `source_digest` it was built from and states plainly that
# it does not live-update. An artifact that looks live and is not is worse than
# one that admits it is a snapshot.
#
# ─────────────────────────────────────────────────────────────────────────────
# DETERMINISM
# ─────────────────────────────────────────────────────────────────────────────
# Same index -> byte-identical HTML. Item order comes from the index (already
# `LC_ALL=C sort`ed by id); grouping order is the fixed status vocabulary; every
# `sort` here runs under LC_ALL=C. `generated_at` is CARRIED FROM THE INDEX and
# never re-stamped — the page dates the data, not the render.
#
# ─────────────────────────────────────────────────────────────────────────────
# BOUNDARIES
# ─────────────────────────────────────────────────────────────────────────────
#   * writes NOTHING except the output path (plus scratch under $TMPDIR)
#   * runs NO git, ever
#   * does not run the collector and does not touch the index
#   * every interpolated value is HTML-escaped with jq's @html — titles are
#     human-authored markdown and legitimately contain <, &, quotes, backticks
#
# Usage:
#   build-backlog-dashboard.sh [ROOT] [--index FILE] [--out FILE] [--stdout]
#     ROOT         repo root (default: resolved from this script's location)
#     --index FILE index to read (default: <ROOT>/.logic-loom/backlog-index.json)
#     --out FILE   output path (default: <ROOT>/.logic-loom/backlog-dashboard.html)
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
[ -n "$OUT" ] || OUT="$ROOT/.logic-loom/backlog-dashboard.html"

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

TITLE="$P_NAME"
[ -n "$TITLE" ] || TITLE="$P_SLUG"
[ -n "$TITLE" ] || TITLE="LogicLoom"

# ── grouped item sections ────────────────────────────────────────────────────
# Order: the closed status vocabulary, fixed. Within a group: index order, which
# the collector already fixed as LC_ALL=C sort by id.
BODY="$TMPD/body.html"
jq -r '
  def slabel: {"open":"Open","in_progress":"In progress","blocked":"Blocked","done":"Done"};
  . as $x
  | ($x.items | map(.id)) as $ids
  | ["open","in_progress","blocked","done"]
  | map(
      . as $s
      | ($x.items | map(select(.status == $s))) as $g
      | "<section class=\"grp\" id=\"grp-" + $s + "\">\n"
      + "  <h2 class=\"grp-h\">" + (slabel[$s]) + " <span class=\"count\">" + ($g | length | tostring) + "</span></h2>\n"
      + ( if ($g | length) == 0 then "  <p class=\"empty\">No items.</p>\n"
          else ( $g | map(
              "  <article class=\"item\" id=\"item-" + (.id | @html) + "\">\n"
            + "    <div class=\"meta\">"
            + "<code class=\"iid\">" + (.id | @html) + "</code>"
            + "<span class=\"badge b-" + (.status | @html) + "\">" + (.status | @html) + "</span>"
            + "<span class=\"lvl\">" + (.level | @html) + "</span>"
            + "</div>\n"
            + "    <p class=\"title\">" + (.title | @html) + "</p>\n"
            + "    <p class=\"src\"><code>" + (.source.file | @html) + "</code>"
            + ( if ((.source.heading // "") | length) > 0
                then " &middot; <span class=\"heading\">" + (.source.heading | @html) + "</span>"
                else "" end )
            + "</p>\n"
            + ( if ((.blocked_on // []) | length) > 0
                then "    <p class=\"bo\"><span class=\"bo-l\">blocked on</span> "
                     + ( .blocked_on
                         | map( . as $b
                                | if ($ids | index($b)) != null
                                  then "<a class=\"ref\" href=\"#item-" + ($b | @html) + "\">" + ($b | @html) + "</a>"
                                  elif ($b | startswith("external:"))
                                  then "<span class=\"ref external\" title=\"blocked on something outside this index\">"
                                       + ($b | ltrimstr("external:") | @html) + "</span>"
                                  else "<span class=\"ref dangling\" title=\"not present in this index\">" + ($b | @html) + "</span>"
                                  end )
                         | join(", ") )
                     + "</p>\n"
                else "" end )
            + "  </article>\n" ) | join("") )
          end )
      + "</section>\n" )
  | join("")
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
  .grp { margin:2rem 0 0; }
  .grp-h { font-size:1rem; margin:0 0 .6rem; padding-bottom:.3rem;
           border-bottom:1px solid var(--rule); letter-spacing:.02em; }
  .count { font-family:var(--mono); font-size:.78rem; color:var(--ink-soft); font-weight:400; }
  .empty { color:var(--thread-dim); font-size:.85rem; margin:.2rem 0 0; font-style:italic; }
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
</style>
CSS_EOF

{
  printf '<div class="wrap">\n<header>\n'
  printf '  <h1>%s — backlog</h1>\n' "$TITLE"
  printf '  <p class="sub">A snapshot of the collected backlog index. %s item(s).</p>\n' "$N_TOTAL"
  printf '  <ul class="facts">\n'
  [ -n "$P_SLUG" ]   && printf '    <li><b>project</b> %s</li>\n' "$P_SLUG"
  [ -n "$P_PREFIX" ] && printf '    <li><b>id prefix</b> %s</li>\n' "$P_PREFIX"
  [ -n "$P_REPO" ]   && printf '    <li><b>repo</b> %s</li>\n' "$P_REPO"
  printf '    <li><b>generated_at</b> %s</li>\n' "$GEN"
  printf '    <li><b>schema_version</b> %s</li>\n' "$SCHEMA"
  printf '  </ul>\n'
  printf '  <p class="facts digest"><b>source_digest</b>&nbsp;%s</p>\n' "$DIGEST"
  printf '  <p class="snapshot"><b>This page is a snapshot, not a live view.</b> The index was\n'
  printf '  inlined when this file was generated; it does not re-read anything and it does not\n'
  printf '  update itself. If the digest above no longer matches the sources, what you are\n'
  printf '  reading is out of date. Regenerate with\n'
  printf '  <code>.logic-loom/scripts/bash/build-backlog-index.sh</code> then\n'
  printf '  <code>.logic-loom/scripts/bash/build-backlog-dashboard.sh</code>.</p>\n'
  printf '  <div class="toolbar"><button type="button" id="theme">Toggle theme</button></div>\n'
  printf '</header>\n<main>\n'
  cat "$BODY"
  printf '</main>\n<footer>\n'
  printf '  Generated by <code>.logic-loom/scripts/bash/build-backlog-dashboard.sh</code> from\n'
  printf '  <code>.logic-loom/backlog-index.json</code>. Both are derived artifacts, gitignored\n'
  printf '  and regenerated on demand — never committed.\n'
  printf '</footer>\n</div>\n'
} >> "$PAGE"

cat >> "$PAGE" <<'JS_EOF'
<script>
  // The page's only script: a light/dark override on top of prefers-color-scheme.
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
</script>
JS_EOF

mkdir -p "$(dirname "$OUT")" 2>/dev/null || true
cp "$PAGE" "$OUT" || { echo "ERROR: cannot write '$OUT'" >&2; exit 1; }
[ "$ECHO_STDOUT" -eq 1 ] && cat "$OUT"

echo "backlog dashboard: $N_TOTAL item(s) -> ${OUT#$ROOT/}  (untracked snapshot; regenerate on demand)" >&2
exit 0
