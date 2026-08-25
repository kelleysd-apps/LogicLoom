#!/usr/bin/env bash
# Contract Tests: backlog dashboard generator (the human-facing viewer layer)
#
# Artifact under test:
#   .logic-loom/scripts/bash/build-backlog-dashboard.sh — reads the index emitted
#   by build-backlog-index.sh and renders ONE self-contained HTML page at
#   artifacts/backlog-dashboard.html.
#
# What this suite guards, and why each one is here:
#
#   * SELF-CONTAINED, ZERO EXTERNAL REFERENCES — the load-bearing property. The
#     page is meant to be double-clicked from disk (project-graph-convention §5:
#     "opens offline, no server"). A `file://` document has an OPAQUE origin: it
#     cannot fetch() a sibling JSON, and any CDN/webfont/remote-image reference
#     is a silent blank on a machine with no network. So the generator INLINES a
#     snapshot of the index, and this suite asserts nothing off-file crept back
#     in — no http/https URL, no protocol-relative //cdn, no <script src=, no
#     <link href=. This is the single assertion most likely to catch a
#     well-meaning future edit ("just pull in a nicer font").
#   * DETERMINISM — same index, byte-identical HTML. generated_at is CARRIED from
#     the index, never re-stamped, so there is no per-run variable at all and the
#     proof needs no SOURCE_DATE_EPOCH.
#   * MISSING INDEX IS FAIL-OPEN AND SAYS SO — a viewer generator must not gate a
#     workflow. Clear message naming the collector, nothing written, exit 0.
#   * ESCAPING — titles come from human-authored markdown and legitimately
#     contain <, &, quotes and backticks. Proven with an XSS-shaped fixture: the
#     payload must appear entity-escaped, and the page must still carry exactly
#     one <script> (its own theme toggle).
#   * CLASS IS A FIRST-CLASS DIMENSION — the index AGGREGATES different documents
#     (cross-cutting backlog, feature plans, spec tasks) and `level` records
#     which. A class section renders for EVERY declared class, including the
#     empty ones, and an empty one names the path it would have read from: an
#     absent section is ambiguous ("no work" or "never looked?"), an empty one is
#     a fact. Proven on a THREE-CLASS fixture, because the real repo exercises
#     only one class today and would leave the other two paths untested.
#   * THE CLASS TABLE MIRRORS THE COLLECTOR'S SOURCE TABLE — two declarations in
#     two files, so the suite asserts they name the same (level, path) pairs. A
#     new source is one row in each; this is the guard that makes forgetting the
#     second row loud instead of silent.
#   * CONSUMER-LIBERAL COMPATIBILITY (LOOM-0022) — the index contract is producer
#     strict / consumer liberal. An unrecognised `status` OR `level` must be
#     carried through verbatim, bucketed under a catch-all, never coerced, never
#     dropped, never fatal. Proven with a fixture carrying both.
#   * THE OUTPUT IS TRACKED, AND A FAIL-CLOSED GATE LICENSES THAT — it lives in
#     `artifacts/` because of WHAT it is (a standalone deliverable opened from
#     disk), and it is COMMITTED like its neighbours because it is the artifact a
#     human actually opens: while gitignored it existed only in whichever
#     checkout last ran the generator. Tracking a derived artifact reintroduces
#     staleness, so the suite asserts BOTH halves — not ignored, AND covered by
#     .logic-loom/scripts/bash/check-generated-freshness.sh, which regenerates
#     the page and FAILS on a difference (in CI, via plugin-tests.yml). Warn-only
#     is not sufficient; a warning is how the manifest bug shipped. The INDEX
#     stays ignored: track only what a human opens, and a machine intermediate
#     has no committed copy to be stale. Note also that .gitignore is not
#     branch-scoped, so "ignore on dev, ship on main" is not a real mechanism —
#     the customer-facing half is the wholesale `artifacts` strip at promote.
#   * WRITES NOTHING but its output path — shasum-manifest diff of a fixture tree.
#   * RUNS NO GIT — runtime PATH shim, not a source grep.
#   * THE artifacts/ SHIPPING DEFECT STAYS CLOSED (LOOM-0009 / VISION #5) —
#     artifacts/*.html are git-tracked, hand-authored LogicLoom-internal pages
#     that were in NO strip list and shipped to customers. The manifest entry and
#     the two documentation surfaces are asserted here so the fix cannot silently
#     regress.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0; SKIP=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}
# skip <desc> <reason> — NOT counted in PASS/FAIL/TOTAL. See tests/lib/tree-provenance.sh.
skip() {
  SKIP=$((SKIP + 1))
  echo "  ⏭  SKIP: $1 — $2"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

# shellcheck source=../lib/tree-provenance.sh
source "$ROOT/tests/lib/tree-provenance.sh"
if ! loom_require_consistent_tree "$ROOT"; then
  echo "════════════════════════════════"
  echo " Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
  exit 1
fi
TREE_KIND="$(loom_tree_kind "$ROOT")"

GEN="$ROOT/.logic-loom/scripts/bash/build-backlog-dashboard.sh"
COLLECTOR="$ROOT/.logic-loom/scripts/bash/build-backlog-index.sh"
OUT_REL="artifacts/backlog-dashboard.html"
IDX_REL=".logic-loom/backlog-index.json"
MANIFEST="$ROOT/.logic-loom/scripts/bash/template-strip-manifest.txt"

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t loombdash)"
trap 'rm -rf "$TMP"' EXIT

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Contract Tests: Backlog Dashboard (self-contained HTML)  ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# ── 0. Present and syntactically sound ───────────────────────────────────────
echo "0. Generator present and parses"
assert "build-backlog-dashboard.sh exists" "[ -f '$GEN' ]"
assert "generator passes bash -n" "bash -n '$GEN' >/dev/null 2>&1"
HAVE_JQ=0; command -v jq >/dev/null 2>&1 && HAVE_JQ=1
assert "jq available (required for the generator)" "[ $HAVE_JQ -eq 1 ]"
echo ""

if [ $HAVE_JQ -ne 1 ] || [ ! -f "$GEN" ]; then
  echo "════════════════════════════════"
  echo " Results: $PASS/$TOTAL passed, $FAIL failed"
  echo "❌ SOME TESTS FAILED"
  exit 1
fi

# ── fixture: every status, a resolvable blocker, a DANGLING blocker ──────────
FX="$TMP/fx"; mkdir -p "$FX/.logic-loom"
cat > "$FX/$IDX_REL" <<'IDX_EOF'
{
  "schema_version": 1,
  "generated_at": "2026-01-02T03:04:05Z",
  "source_digest": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  "project": { "slug": "acme-widgets", "name": "ACME Widgets", "id_prefix": "LOOM", "repo": "acme/widgets" },
  "items": [
    { "id": "LOOM-0001", "title": "An open item", "status": "open",
      "blocked_on": [], "source": { "file": ".logic-loom/memory/backlog.md", "heading": "Governance" }, "level": "backlog" },
    { "id": "LOOM-0002", "title": "A running item", "status": "in_progress",
      "blocked_on": [], "source": { "file": ".logic-loom/memory/backlog.md", "heading": "Governance" }, "level": "backlog" },
    { "id": "LOOM-0003", "title": "A blocked item", "status": "blocked",
      "blocked_on": ["LOOM-0001", "LOOM-0404"], "source": { "file": ".logic-loom/memory/backlog.md", "heading": "Hygiene" }, "level": "backlog" },
    { "id": "LOOM-0004", "title": "A finished item", "status": "done",
      "blocked_on": [], "source": { "file": ".logic-loom/memory/backlog.md", "heading": "Hygiene" }, "level": "backlog" },
    { "id": "alpha:t1", "title": "A feature task", "status": "open",
      "blocked_on": [], "source": { "file": "features/alpha/plan.md", "heading": "01-foundations" }, "level": "feature" }
  ]
}
IDX_EOF

PAGE="$FX/$OUT_REL"

# ── 1. Renders a valid, self-describing page ─────────────────────────────────
echo "1. Renders a page carrying identity, generated_at and schema_version"
bash "$GEN" "$FX" >/dev/null 2>"$TMP/run1.err"; RC1=$?
assert "generator exits 0" "[ $RC1 -eq 0 ]"
assert "wrote the page at the default path" "[ -f '$PAGE' ]"
assert "page opens with a DOCTYPE" "grep -qi '^<!DOCTYPE html>' <<< \"\$(head -1 '$PAGE')\""
assert "page carries a <title>" "grep -q '<title>' '$PAGE'"
assert "project name appears" "grep -q 'ACME Widgets' '$PAGE'"
assert "project slug appears" "grep -q 'acme-widgets' '$PAGE'"
assert "generated_at is CARRIED from the index, not re-stamped" \
  "grep -q '2026-01-02T03:04:05Z' '$PAGE'"
assert "schema_version is shown" "grep -q 'schema_version' '$PAGE'"
echo ""

# ── 2. Staleness is stated, not implied ──────────────────────────────────────
# The page is a frozen snapshot. An artifact that LOOKS live and is not is worse
# than one that admits what it is, so the digest and the disclaimer are asserted.
echo "2. Staleness indicator: digest shown, snapshot stated plainly"
assert "source_digest is displayed in full" \
  "grep -q '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' '$PAGE'"
assert "the page says it is a snapshot" "grep -qi 'snapshot' '$PAGE'"
assert "the page denies live-updating" \
  "grep -qiE 'not a live view|does not update itself|does not live-update' '$PAGE'"
assert "the page names the regeneration command" \
  "grep -q 'build-backlog-index.sh' '$PAGE' && grep -q 'build-backlog-dashboard.sh' '$PAGE'"
echo ""

# ── 3. Class sections outside, status groups inside, blocked_on links ────────
# The outer dimension is item CLASS, because the index aggregates DIFFERENT
# documents and `level` is what records which one an item came from. Status is
# the inner dimension. Group ids are therefore `grp-<class>-<status>`.
echo "3. Class sections outside; status groups inside; blocked_on links resolve"
assert "a section exists for every declared class" \
  "grep -q 'id=\"cls-backlog\"' '$PAGE' && grep -q 'id=\"cls-feature\"' '$PAGE' && grep -q 'id=\"cls-spec\"' '$PAGE'"
assert "status groups are nested per class, not global" \
  "grep -q 'id=\"grp-backlog-open\"' '$PAGE' && grep -q 'id=\"grp-backlog-done\"' '$PAGE' && grep -q 'id=\"grp-feature-open\"' '$PAGE'"
assert "no legacy global status group survives" \
  "! grep -q 'id=\"grp-open\"' '$PAGE'"
assert "every fixture item rendered (5 articles)" \
  "[ \"\$(grep -c 'class=\"item\"' '$PAGE')\" = '5' ]"
assert "each item is an anchor target" "grep -q 'id=\"item-LOOM-0003\"' '$PAGE'"
assert "source file is shown" "grep -q 'features/alpha/plan.md' '$PAGE'"
assert "source heading is shown" "grep -q '01-foundations' '$PAGE'"
assert "a resolvable blocker becomes a link to the item on the page" \
  "grep -q 'href=\"#item-LOOM-0001\"' '$PAGE'"
assert "a DANGLING blocker is NOT linked (it is not on the page)" \
  "! grep -q 'href=\"#item-LOOM-0404\"' '$PAGE' && grep -q 'LOOM-0404' '$PAGE'"
echo ""

# ── 3b. A class with ZERO items is REPRESENTED, not omitted ──────────────────
# This is the whole reason class is a dimension. An absent section is ambiguous:
# a reader cannot tell "there is no spec work" from "the collector never looked
# at specs/". An empty section that names its source path is unambiguous.
#
# THE TODO STREAM IS ONE OF THE EMPTY CLASSES HERE, ON PURPOSE. todos.md and
# backlog.md are two halves of one stream, and a project can legitimately have
# nothing active — an all-deferred state has to read as "nothing here", never as
# "the todos file was not looked at".
echo "3b. An empty class renders as empty-with-its-source-path"
assert "the empty 'spec' class still has a section" "grep -q 'id=\"cls-spec\"' '$PAGE'"
assert "the empty 'todo' STREAM still has a section (all-deferred is a real state)" \
  "grep -q 'id=\"cls-todo\"' '$PAGE'"
assert "the empty todo stream names todos.md, so 'nothing here' != 'never looked'" \
  "grep -q '.logic-loom/memory/todos.md' '$PAGE'"
assert "both empty classes show a count of 0" \
  "[ \"\$(grep -c '<span class=\"count cls-count\">0<' '$PAGE')\" = '2' ]"
assert "the empty class names the path it would have read" \
  "grep -q 'specs/\*/tasks.md' '$PAGE'"
assert "the empty class says so in words, not by absence" \
  "grep -q 'No items of this class' '$PAGE'"
assert "the empty section distinguishes 'no work' from 'never looked'" \
  "grep -qi 'not because the collector never looked' '$PAGE'"
echo ""

# ── 3c. Summary: totals, by status, by class ─────────────────────────────────
# The index deliberately carries NO rollups (see DELIBERATELY ABSENT in the
# collector) — aggregation is the consumer's job. This is the consumer doing it.
echo "3c. Summary carries total, per-status counts and per-class counts"
assert "a summary block exists" "grep -q 'class=\"summary\"' '$PAGE'"
assert "the total is stated" "grep -q '5 item(s)' '$PAGE'"
assert "a per-status tally is present" "grep -q 'class=\"tally by-status\"' '$PAGE'"
assert "a per-class tally is present" "grep -q 'class=\"tally by-class\"' '$PAGE'"
assert "the per-class tally links to each class section" \
  "grep -q 'href=\"#cls-backlog\"' '$PAGE' && grep -q 'href=\"#cls-spec\"' '$PAGE'"
assert "class counts sum to the item total" \
  "[ \"\$(grep -oE '<span class=\"count cls-count\">[0-9]+' '$PAGE' | grep -oE '[0-9]+\$' | awk '{s+=\$1} END {print s+0}')\" = '5' ]"
echo ""

# ── 4. Dual light/dark ───────────────────────────────────────────────────────
echo "4. Dual light/dark: media query plus a data-theme override"
assert "prefers-color-scheme block present" "grep -q 'prefers-color-scheme: dark' '$PAGE'"
assert "data-theme=\"dark\" override present" "grep -q 'data-theme=\"dark\"' '$PAGE'"
assert "data-theme=\"light\" override present" "grep -q 'data-theme=\"light\"' '$PAGE'"
echo ""

# ── 5. ZERO external references ──────────────────────────────────────────────
# THE property that makes file:// work. Checked as absence, so any new off-file
# reference — CDN, webfont, remote image, external stylesheet — fails here.
echo "5. Self-contained: zero external references of any kind"
assert "no http:// URL anywhere" "! grep -q 'http://' '$PAGE'"
assert "no https:// URL anywhere" "! grep -q 'https://' '$PAGE'"
assert "no protocol-relative //cdn reference" "! grep -q '//cdn' '$PAGE'"
assert "no <script src=" "! grep -qE '<script[^>]+src=' '$PAGE'"
assert "no <link href=" "! grep -qE '<link[^>]+href=' '$PAGE'"
assert "no CSS url() (webfont / remote image)" "! grep -q 'url(' '$PAGE'"
assert "no @import" "! grep -q '@import' '$PAGE'"
assert "no runtime fetch() of the index — it is INLINED" "! grep -q 'fetch(' '$PAGE'"
assert "no XMLHttpRequest" "! grep -q 'XMLHttpRequest' '$PAGE'"
assert "every href is an on-page fragment" \
  "[ \"\$(grep -oE 'href=\"[^\"]*\"' '$PAGE' | grep -cv 'href=\"#')\" = '0' ]"
echo ""

# ── 6. Determinism ───────────────────────────────────────────────────────────
# No SOURCE_DATE_EPOCH needed: generated_at comes from the index, so the render
# has no per-run variable at all.
echo "6. Deterministic: same index -> byte-identical HTML"
bash "$GEN" "$FX" --out "$TMP/det-a.html" >/dev/null 2>&1
bash "$GEN" "$FX" --out "$TMP/det-b.html" >/dev/null 2>&1
assert "two runs are byte-identical" "cmp -s '$TMP/det-a.html' '$TMP/det-b.html'"
echo ""

# ── 7. Missing index: fail-open, clear, nothing written ──────────────────────
echo "7. Missing index fails OPEN with a message naming the collector"
EMPTY="$TMP/empty"; mkdir -p "$EMPTY"
bash "$GEN" "$EMPTY" >"$TMP/miss.out" 2>"$TMP/miss.err"; RCM=$?
assert "exits 0 (a viewer generator never gates a workflow)" "[ $RCM -eq 0 ]"
assert "says the index was not found" "grep -qi 'index not found' '$TMP/miss.err'"
assert "names the collector to run" "grep -q 'build-backlog-index.sh' '$TMP/miss.err'"
assert "says nothing was written" "grep -qi 'nothing was written' '$TMP/miss.err'"
assert "wrote no output file" "[ ! -f '$EMPTY/$OUT_REL' ]"
assert "created no partial output directory content" \
  "[ -z \"\$(ls -A '$EMPTY' 2>/dev/null)\" ]"
BADJ="$TMP/badjson"; mkdir -p "$BADJ/.logic-loom"
printf 'not json at all' > "$BADJ/$IDX_REL"
bash "$GEN" "$BADJ" >/dev/null 2>"$TMP/bad.err"; RCB=$?
assert "a corrupt index also fails open, exit 0" "[ $RCB -eq 0 ]"
assert "corrupt index message names the collector" "grep -q 'build-backlog-index.sh' '$TMP/bad.err'"
assert "corrupt index writes no page" "[ ! -f '$BADJ/$OUT_REL' ]"
echo ""

# ── 8. Escaping, proven with an XSS-shaped fixture ───────────────────────────
echo "8. Every interpolated value is HTML-escaped"
XF="$TMP/xss"; mkdir -p "$XF/.logic-loom"
cat > "$XF/$IDX_REL" <<'XSS_EOF'
{
  "schema_version": 1,
  "generated_at": "2026-01-02T03:04:05Z",
  "source_digest": "beef",
  "project": { "slug": "<img src=x onerror=alert(1)>", "name": "A & B \"quoted\" 'single'", "id_prefix": "LOOM" },
  "items": [
    { "id": "LOOM-0001",
      "title": "<script>alert('xss')</script> & `backtick` <b>bold</b> \"q\" 'q'",
      "status": "open",
      "blocked_on": ["LOOM-0002\" onmouseover=alert(2) x=\""],
      "source": { "file": "<i>a.md</i>", "heading": "<em>h</em>" },
      "level": "backlog" }
  ]
}
XSS_EOF
bash "$GEN" "$XF" >/dev/null 2>&1
XP="$XF/$OUT_REL"
assert "the XSS fixture rendered" "[ -f '$XP' ]"
assert "no raw <script>alert( survived from the title" "! grep -q '<script>alert(' '$XP'"
assert "the title payload appears entity-escaped instead" \
  "grep -q '&lt;script&gt;alert(&apos;xss&apos;)&lt;/script&gt;' '$XP'"
# NOTE: the strings "onerror=alert" and "onmouseover=alert" DO appear in the page
# — as inert TEXT, because the `<` and `"` that would make them an element or an
# attribute are entity-escaped. So the assertion is about the DELIMITERS, not the
# payload: a grep for the payload alone would fail on correct output.
assert "no raw <img tag injected from the project slug" "! grep -q '<img' '$XP'"
assert "the slug payload appears entity-escaped instead" "grep -q '&lt;img src=x onerror=alert(1)&gt;' '$XP'"
assert "a bare & became &amp;" "grep -q 'A &amp; B' '$XP'"
assert "double quotes became &quot;" "grep -q '&quot;quoted&quot;' '$XP'"
assert "no raw <b> injected from the title" "! grep -q '<b>bold</b>' '$XP'"
assert "no raw <i>/<em> injected from the source pointer" \
  "! grep -q '<i>a.md</i>' '$XP' && ! grep -q '<em>h</em>' '$XP'"
assert "an attribute-breaking blocker id cannot close its attribute" \
  "! grep -q 'LOOM-0002\" onmouseover' '$XP'"
assert "that blocker's quote is escaped to &quot; instead" \
  "grep -q 'LOOM-0002&quot; onmouseover' '$XP'"
assert "the page carries exactly ONE <script> — its own theme toggle" \
  "[ \"\$(grep -c '<script' '$XP')\" = '1' ]"
echo ""

# ── 9. The output path is TRACKED, and a fail-closed gate licenses that ──────
# This page is the thing a HUMAN opens, and while it was gitignored it existed
# only in whichever checkout last ran the generator. It is now tracked. The
# staleness cost that buys is not hand-waved: a fail-closed freshness gate
# regenerates the page and fails if the committed copy differs. Tracking without
# the gate is the defect, so both halves are asserted here.
#
# The INDEX stays ignored — the distinction is deliberate: track only the
# artifact a human reads; a machine intermediate with no standalone reader has
# nothing to gate because there is no committed copy to disagree.
echo "9. The dashboard is TRACKED, and the freshness gate licenses it"
assert ".gitignore no longer ignores the dashboard" \
  "! grep -qxF 'artifacts/backlog-dashboard.html' '$ROOT/.gitignore'"
assert ".gitignore records WHY it is tracked, not just silence" \
  "grep -q 'artifacts/backlog-dashboard.html is deliberately NOT listed here' '$ROOT/.gitignore'"
assert ".gitignore states the mechanism is strip-at-promote, not a per-branch ignore" \
  "grep -q 'NOT branch-scoped' '$ROOT/.gitignore'"
assert "the machine intermediate (the index) IS still ignored" \
  "grep -qxF '.logic-loom/backlog-index.json' '$ROOT/.gitignore'"
GR="$TMP/gitignore-probe"
mkdir -p "$GR/$(dirname "$OUT_REL")" "$GR/.logic-loom"
cp "$ROOT/.gitignore" "$GR/.gitignore"
( cd "$GR" && git init -q . && git config user.email t@t && git config user.name t ) >/dev/null 2>&1
printf '<!DOCTYPE html>' > "$GR/$OUT_REL"
printf '{}' > "$GR/.logic-loom/backlog-index.json"
# -uall, not the default: git COLLAPSES an untracked directory to `?? artifacts/`,
# which would make this probe silently test nothing.
PROBE="$(cd "$GR" && git status --porcelain -uall 2>/dev/null | grep -F 'backlog-dashboard.html' || true)"
assert "a dashboard file IS visible to git status under this .gitignore" "[ -n \"\$PROBE\" ]"
IPROBE="$(cd "$GR" && git status --porcelain -uall 2>/dev/null | grep -F 'backlog-index.json' || true)"
assert "an index file is still INVISIBLE to git status under this .gitignore" "[ -z \"\$IPROBE\" ]"
# The gate itself.
GATE="$ROOT/.logic-loom/scripts/bash/check-generated-freshness.sh"
assert "the freshness gate script exists" "[ -f '$GATE' ]"
assert "the gate covers the dashboard" "grep -q 'artifacts/backlog-dashboard.html' '$GATE'"
assert "the gate is wired into CI" \
  "grep -q 'check-generated-freshness.sh' '$ROOT/.github/workflows/plugin-tests.yml'"
# Fail-CLOSED, not warn-only — a warning is exactly how the manifest bug shipped.
assert "the gate exits non-zero on drift (fail-closed)" "grep -q 'exit 1' '$GATE'"
echo ""

# ── 10. Writes nothing outside its output path ───────────────────────────────
echo "10. Writes nothing but its output path"
manifest_of() { # $1 = dir  $2 = repo-relative path to exclude
  ( cd "$1" && find . -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
      case "${f#./}" in "$2") continue ;; esac
      printf '%s  ' "$f"; shasum -a 256 "$f" 2>/dev/null | awk '{print $1}'
    done )
}
FX2="$TMP/fx2"; rm -rf "$FX2"; cp -R "$FX" "$FX2"; rm -f "$FX2/$OUT_REL"
manifest_of "$FX2" "$OUT_REL" > "$TMP/before.txt"
bash "$GEN" "$FX2" >/dev/null 2>&1
manifest_of "$FX2" "$OUT_REL" > "$TMP/after.txt"
assert "no file in the fixture tree changed except the output" \
  "diff -q '$TMP/before.txt' '$TMP/after.txt' >/dev/null 2>&1"
assert "the index itself was not modified" \
  "grep -q 'backlog-index.json' '$TMP/after.txt'"
assert "the output itself WAS written" "[ -f '$FX2/$OUT_REL' ]"
echo ""

# ── 11. Runs no git ──────────────────────────────────────────────────────────
echo "11. Runs no git (runtime PATH shim, not a source grep)"
mkdir -p "$TMP/shim"
cat > "$TMP/shim/git" <<'SHIM_EOF'
#!/bin/sh
echo "$@" >> "$GIT_SHIM_LOG"
exit 1
SHIM_EOF
chmod +x "$TMP/shim/git"
: > "$TMP/git-calls.log"
FX3="$TMP/fx3"; rm -rf "$FX3"; cp -R "$FX" "$FX3"
GIT_SHIM_LOG="$TMP/git-calls.log" PATH="$TMP/shim:$PATH" bash "$GEN" "$FX3" >/dev/null 2>&1
assert "generator invoked git zero times" "[ ! -s '$TMP/git-calls.log' ]"
echo ""

# ── 12. The artifacts/ shipping defect stays closed (LOOM-0009 / VISION #5) ──
# artifacts/harness-graph.html and artifacts/logicloom-vision.html are tracked,
# hand-authored LogicLoom-internal pages. They were in NO strip list and shipped
# to customers verbatim. The convention now ships; the contents do not.
echo "12. artifacts/ is declared, and our own artifacts are stripped"
if [ "$TREE_KIND" = "sanitized" ]; then
  skip "strip manifest exists" \
    "strip manifest present — sanitized tree (maintainer-only file)"
  skip "manifest strips artifacts/ WHOLESALE (not a fragile *.html glob)" \
    "strip manifest present — sanitized tree (maintainer-only file)"
  skip "the manifest entry carries its reason" \
    "strip manifest present — sanitized tree (maintainer-only file)"
else
assert "strip manifest exists" "[ -f '$MANIFEST' ]"
assert "manifest strips artifacts/ WHOLESALE (not a fragile *.html glob)" \
  "grep -qE '^artifacts[[:space:]]*(#.*)?\$' '$MANIFEST'"
assert "the manifest entry carries its reason" \
  "grep -q 'Repo-root .artifacts/.' '$MANIFEST'"
fi
assert "artifacts/ is documented in CLAUDE.md's directory structure" \
  "grep -q '^artifacts/' '$ROOT/CLAUDE.md'"
assert "artifacts/ has its own section in the file-structure policy" \
  "grep -q '^### artifacts/' '$ROOT/.docs/policies/file-structure-policy.md'"
assert "the policy states artifacts are never a plan" \
  "grep -qi 'never a plan' '$ROOT/.docs/policies/file-structure-policy.md'"
# The dashboard is a GENERATED artifact living in artifacts/ and gitignored
# per-file. The policy has to say that explicitly, or the next reader concludes
# artifacts/ is tracked-only and puts the page back under .logic-loom/.
assert "the policy separates placement (what it IS) from tracking (how it is MADE)" \
  "grep -qi 'Placement follows what a file IS' '$ROOT/.docs/policies/file-structure-policy.md'"
assert "the policy names the generated dashboard as the worked example" \
  "grep -q 'artifacts/backlog-dashboard.html' '$ROOT/.docs/policies/file-structure-policy.md'"
assert "the policy states the track-only-what-a-human-opens rule" \
  "grep -qi 'Track only what a human opens' '$ROOT/.docs/policies/file-structure-policy.md'"
assert "the policy names the gate as the licence to track a generated file" \
  "grep -q 'check-generated-freshness.sh' '$ROOT/.docs/policies/file-structure-policy.md'"
assert "the policy warns that .gitignore is not branch-scoped" \
  "grep -qi 'not branch-scoped' '$ROOT/.docs/policies/file-structure-policy.md'"
assert "CLAUDE.md's directory block records the same exception" \
  "grep -q 'artifacts/backlog-dashboard.html' '$ROOT/CLAUDE.md'"
# Now that the dashboard is TRACKED, the wholesale `artifacts` strip is the ONE
# thing keeping it out of a customer's tree — it is no longer belt-and-braces.
# The strip walks `git ls-files`, so a tracked artifact IS a strip candidate.
if [ "$TREE_KIND" = "sanitized" ]; then
  skip "the strip is tracked-content only (which is why a tracked artifact reaches it)" \
    "strip-harness-dev.sh is itself stripped — sanitized tree (maintainer-only file)"
  skip "the manifest records that the wholesale entry is now load-bearing for the dashboard" \
    "strip manifest present — sanitized tree (maintainer-only file)"
else
assert "the strip is tracked-content only (which is why a tracked artifact reaches it)" \
  "grep -q 'git ls-files' '$ROOT/.logic-loom/scripts/bash/strip-harness-dev.sh'"
assert "the manifest records that the wholesale entry is now load-bearing for the dashboard" \
  "grep -q 'artifacts/backlog-dashboard.html' '$MANIFEST'"
fi
assert ".gitignore does not ignore the artifacts/ directory either" \
  "! grep -qxE 'artifacts/?' '$ROOT/.gitignore'"
echo ""

# ── 13. Live check against the REAL repo ─────────────────────────────────────
# Guards a vacuous pass: if rendering broke, every fixture assertion above could
# still be green while the real page came out empty.
echo "13. Live: the real index renders, and every item reaches the page"
if [ -f "$COLLECTOR" ]; then
  bash "$COLLECTOR" "$ROOT" --out "$TMP/real.json" >/dev/null 2>&1
  bash "$GEN" "$ROOT" --index "$TMP/real.json" --out "$TMP/real.html" >/dev/null 2>&1
  REAL_N="$(jq -r '.items | length' "$TMP/real.json" 2>/dev/null || echo 0)"
  RENDERED="$(grep -c 'class="item"' "$TMP/real.html" 2>/dev/null || echo 0)"
  echo "     (index: $REAL_N item(s); rendered: $RENDERED article(s))"
  assert "the real page was rendered" "[ -f '$TMP/real.html' ]"
  if [ "$TREE_KIND" = "sanitized" ]; then
    # .logic-loom/memory/todos.md and backlog.md are empty stubs by design on a
    # sanitized tree (see the collector suite's tree-provenance note), so the
    # real index legitimately has zero items here.
    skip "the real index has at least one item" \
      "todos.md/backlog.md are empty stubs by design — sanitized tree"
    skip "every index item reached the page" \
      "todos.md/backlog.md are empty stubs by design — sanitized tree"
  else
  assert "the real index has at least one item" "[ \"$REAL_N\" -ge 1 ]"
  assert "every index item reached the page" "[ \"$RENDERED\" = \"$REAL_N\" ]"
  fi
  assert "the real page has zero external references" \
    "! grep -qE 'http://|https://|//cdn' '$TMP/real.html'"
  SUM="$(grep -oE '<span class=\"count cls-count\">[0-9]+' "$TMP/real.html" | grep -oE '[0-9]+$' | awk '{s+=$1} END {print s+0}')"
  assert "the class counts sum to the item total" "[ \"\$SUM\" = \"$REAL_N\" ]"
  # Today's repo carries backlog items only. The other two classes MUST still
  # appear, empty and with their paths — that is the assertion that would fail
  # if a future edit made a class section conditional on having items.
  assert "all three declared classes have a section on the real page" \
    "grep -q 'id=\"cls-backlog\"' '$TMP/real.html' && grep -q 'id=\"cls-feature\"' '$TMP/real.html' && grep -q 'id=\"cls-spec\"' '$TMP/real.html'"
  assert "the real page carries no 'Other' section (no unknown level in this repo)" \
    "! grep -q 'id=\"cls-other\"' '$TMP/real.html'"
else
  echo "     (collector absent — live check skipped)"
fi
echo ""

# ── 14. Consumer-liberal: unknown status AND unknown level (LOOM-0022) ───────
# The index contract is PRODUCER STRICT, CONSUMER LIBERAL. This page is the
# index's first consumer. An unrecognised `status` or `level` must be carried
# through verbatim, bucketed under a catch-all, never coerced to a known value,
# never dropped, never fatal. Not reachable from today's collector (its fatal
# gate rejects an out-of-vocabulary status) — which is exactly why it is proven
# here against a hand-written index, the way a second producer would write one.
echo "14. Unknown status and unknown level are carried through, not dropped"
LIB="$TMP/liberal"; mkdir -p "$LIB/.logic-loom"
cat > "$LIB/$IDX_REL" <<'LIB_EOF'
{
  "schema_version": 1,
  "generated_at": "2026-01-02T03:04:05Z",
  "source_digest": "cafe",
  "project": { "slug": "future", "name": "Future Producer", "id_prefix": "LOOM" },
  "items": [
    { "id": "LOOM-0001", "title": "A known item", "status": "open",
      "blocked_on": [], "source": { "file": ".logic-loom/memory/backlog.md", "heading": "H" }, "level": "backlog" },
    { "id": "LOOM-0002", "title": "A future status", "status": "deferred",
      "blocked_on": [], "source": { "file": ".logic-loom/memory/backlog.md", "heading": "H" }, "level": "backlog" },
    { "id": "runbook:r1", "title": "A future level", "status": "open",
      "blocked_on": [], "source": { "file": "runbooks/x/steps.md", "heading": "S" }, "level": "runbook" },
    { "id": "runbook:r2", "title": "A future level AND status", "status": "waiting",
      "blocked_on": [], "source": { "file": "runbooks/x/steps.md", "heading": "S" }, "level": "runbook" }
  ]
}
LIB_EOF
bash "$GEN" "$LIB" >/dev/null 2>"$TMP/lib.err"; RCL=$?
LP="$LIB/$OUT_REL"
assert "an unknown status/level is NOT fatal — exit 0" "[ $RCL -eq 0 ]"
assert "the page was written" "[ -f '$LP' ]"
assert "ALL FOUR items reached the page — none dropped" \
  "[ \"\$(grep -c 'class=\"item\"' '$LP')\" = '4' ]"
assert "the unknown-status item is present by id" "grep -q 'id=\"item-LOOM-0002\"' '$LP'"
assert "the unknown status is carried through VERBATIM, not coerced" \
  "grep -q '>deferred<' '$LP'"
assert "the unknown status gets its own group, labelled as unrecognised" \
  "grep -q 'id=\"grp-backlog-deferred\"' '$LP' && grep -q 'deferred (unrecognised status)' '$LP'"
assert "the unknown status is counted in the page tally" \
  "grep -q 'class=\"badge b-deferred\"' '$LP'"
assert "the unknown LEVEL lands in an explicit Other catch-all section" \
  "grep -q 'id=\"cls-other\"' '$LP'"
assert "the Other section names the level(s) it saw, verbatim" \
  "grep -q '>runbook<' '$LP'"
assert "the Other section states the consumer-liberal rule it is honouring" \
  "grep -qi 'never coerced and never dropped' '$LP'"
assert "both unknown-level items are inside it" \
  "grep -q 'id=\"item-runbook:r1\"' '$LP' && grep -q 'id=\"item-runbook:r2\"' '$LP'"
assert "the class counts still sum to the item total WITH the catch-all" \
  "[ \"\$(grep -oE '<span class=\"count cls-count\">[0-9]+' '$LP' | grep -oE '[0-9]+\$' | awk '{s+=\$1} END {print s+0}')\" = '4' ]"
assert "known classes are still declared even with an Other section present" \
  "grep -q 'id=\"cls-feature\"' '$LP'"
echo ""

# ── 15. FOUR-CLASS proof, end to end through the real collector ──────────────
# The real repo has todo + backlog items only, so the feature and spec paths are
# untested in practice. This builds a repo-shaped fixture with all four source
# documents populated, runs the ACTUAL collector over it, and renders. It proves
# the collector's SOURCE TABLE and the dashboard's CLASS TABLE agree in fact,
# not just on paper.
#
# It also proves the todo/backlog pair behaves as ONE stream in TWO files: a
# cross-stream `blocked_on:` (a deferred item blocked on an active one) has to
# resolve to an on-page link, which it can only do if both files land in one
# index with one id space.
echo "15. Four-class fixture: todos + backlog + feature plan + spec tasks all render"
if [ -f "$COLLECTOR" ]; then
  T3="$TMP/three"
  mkdir -p "$T3/.logic-loom/memory" "$T3/.logic-loom/config" \
           "$T3/features/alpha" "$T3/specs/001-widgets"
  cat > "$T3/.logic-loom/config/project.conf" <<'CONF_EOF'
project_slug=tri
project_name=Tri Class
id_prefix=TRI
CONF_EOF
  {
    printf '# Todos\n\n## Items\n\n'
    printf '### Governance\n\n'
    printf -- '- [ ] TRI-0001 — An active open item `status:open`\n'
    printf -- '- [ ] TRI-0002 — An active blocked item `status:blocked` `blocked_on:TRI-0001`\n'
    printf -- '- [x] TRI-0003 — An active done item `status:done`\n'
  } > "$T3/.logic-loom/memory/todos.md"
  {
    printf '# Backlog\n\n## Items\n\n'
    printf '### Deferred\n\n'
    printf -- '- [ ] TRI-0004 — A deferred item `status:open`\n'
    # CROSS-STREAM blocker: deferred item, blocked on an ACTIVE todo in the
    # OTHER file. One id space is the only thing that makes this resolve.
    printf -- '- [ ] TRI-0005 — A deferred item blocked on an active one `status:blocked` `blocked_on:TRI-0001`\n'
  } > "$T3/.logic-loom/memory/backlog.md"
  cat > "$T3/features/alpha/plan.md" <<'PLAN_EOF'
---
sprints:
  - name: 01-foundations
    tasks:
      - id: t1
        description: Lay the foundation
        status: done
      - id: t2
        description: Build on it
        status: in_progress
        blocked_on: [t1]
  - name: 02-polish
    tasks:
      - id: t3
        description: Polish it
---

# Plan
PLAN_EOF
  cat > "$T3/specs/001-widgets/tasks.md" <<'TASK_EOF'
# Tasks

## Phase 1
- [x] T001 Write the contract test
- [ ] T002 [P] Implement the widget
- [ ] not a task, just a checklist line
TASK_EOF
  bash "$COLLECTOR" "$T3" --out "$TMP/three.json" >/dev/null 2>"$TMP/three.err"; RC3=$?
  bash "$GEN" "$T3" --index "$TMP/three.json" --out "$TMP/three.html" >/dev/null 2>&1
  T3P="$TMP/three.html"
  N3="$(jq -r '.items | length' "$TMP/three.json" 2>/dev/null || echo 0)"
  echo "     (collector exit $RC3; index: $N3 item(s); levels: $(jq -rc '[.items[].level]|unique' "$TMP/three.json" 2>/dev/null))"
  assert "the collector accepted the four-source fixture" "[ $RC3 -eq 0 ]"
  assert "it collected all 10 items (3 todo + 2 backlog + 3 feature + 2 spec)" "[ \"\$N3\" = '10' ]"
  assert "the index carries all four levels" \
    "[ \"\$(jq -rc '[.items[].level]|unique|join(\",\")' '$TMP/three.json')\" = 'backlog,feature,spec,todo' ]"
  assert "todo and backlog items are distinguished by level, not by id shape" \
    "[ \"\$(jq -r '.items[]|select(.id==\"TRI-0001\")|.level' '$TMP/three.json')\" = 'todo' ] && [ \"\$(jq -r '.items[]|select(.id==\"TRI-0004\")|.level' '$TMP/three.json')\" = 'backlog' ]"
  assert "every item reached the page" \
    "[ \"\$(grep -c 'class=\"item\"' '$T3P')\" = \"\$N3\" ]"
  assert "all four class sections rendered" \
    "grep -q 'id=\"cls-todo\"' '$T3P' && grep -q 'id=\"cls-backlog\"' '$T3P' && grep -q 'id=\"cls-feature\"' '$T3P' && grep -q 'id=\"cls-spec\"' '$T3P'"
  assert "TODOS render BEFORE backlog on the page" \
    "[ \"\$(grep -n 'id=\"cls-todo\"' '$T3P' | head -1 | cut -d: -f1)\" -lt \"\$(grep -n 'id=\"cls-backlog\"' '$T3P' | head -1 | cut -d: -f1)\" ]"
  assert "no class is empty in this fixture (no empty-section text)" \
    "! grep -q 'No items of this class' '$T3P'"
  assert "per-class counts are 3 / 2 / 3 / 2 in table order" \
    "[ \"\$(grep -oE '<span class=\"count cls-count\">[0-9]+' '$T3P' | grep -oE '[0-9]+\$' | tr '\\n' ' ')\" = '3 2 3 2 ' ]"
  assert "each class shows the source document it came from" \
    "grep -q '.logic-loom/memory/todos.md' '$T3P' && grep -q '.logic-loom/memory/backlog.md' '$T3P' && grep -q 'features/\*/plan.md' '$T3P' && grep -q 'specs/\*/tasks.md' '$T3P'"
  assert "a CROSS-STREAM blocker resolves: deferred TRI-0005 links to active TRI-0001" \
    "grep -q 'href=\"#item-TRI-0001\"' <<< \"\$(grep -A6 'id=\"item-TRI-0005\"' '$T3P')\""
  assert "feature ids are namespaced by their feature directory" \
    "grep -q 'id=\"item-alpha:t2\"' '$T3P'"
  assert "spec ids are namespaced by their spec directory" \
    "grep -q 'id=\"item-001-widgets:T001\"' '$T3P'"
  assert "a feature blocker resolves to an on-page link" \
    "grep -q 'href=\"#item-alpha:t1\"' '$T3P'"
  assert "status grouping still happens INSIDE each class" \
    "grep -q 'id=\"grp-feature-done\"' '$T3P' && grep -q 'id=\"grp-feature-in_progress\"' '$T3P' && grep -q 'id=\"grp-spec-done\"' '$T3P'"
  assert "the sprint name is carried as the feature item's heading" \
    "grep -q '02-polish' '$T3P'"
  assert "the three-class page is still self-contained" \
    "! grep -qE 'http://|https://|//cdn|@import|<script[^>]+src=|<link[^>]+href=' '$T3P'"
else
  echo "     (collector absent — three-class proof skipped)"
fi
echo ""

# ── 16. The class table MIRRORS the collector's source table ─────────────────
# Two declarations in two files. A new item class is one row in each; forgetting
# the second row would silently bucket a whole class into "Other". This is the
# guard that makes that loud. It compares the (level, path) pairs only — labels
# are the viewer's business.
echo "16. Dashboard CLASS_TABLE and collector SOURCE_TABLE declare the same classes"
if [ -f "$COLLECTOR" ]; then
  # collector row:  PATH|LEVEL|PARSER   -> normalise to "<level> <path>"
  sed -n "/^SOURCE_TABLE='\$/,/^'\$/p" "$COLLECTOR" | grep '|' \
    | awk -F'|' '{ print $2 " " $1 }' | LC_ALL=C sort > "$TMP/src-pairs.txt"
  # dashboard row:  LEVEL|LABEL|PATH    -> normalise to "<level> <path>"
  sed -n "/^CLASS_TABLE='\$/,/^'\$/p" "$GEN" | grep '|' \
    | awk -F'|' '{ print $1 " " $3 }' | LC_ALL=C sort > "$TMP/cls-pairs.txt"
  echo "     (collector: $(tr '\n' ';' < "$TMP/src-pairs.txt"))"
  echo "     (dashboard: $(tr '\n' ';' < "$TMP/cls-pairs.txt"))"
  assert "the collector declares a SOURCE_TABLE" "grep -q '^SOURCE_TABLE=' '$COLLECTOR'"
  assert "the dashboard declares a CLASS_TABLE" "grep -q '^CLASS_TABLE=' '$GEN'"
  assert "both tables are non-empty" "[ -s '$TMP/src-pairs.txt' ] && [ -s '$TMP/cls-pairs.txt' ]"
  assert "they declare the SAME (level, path) pairs" \
    "diff -q '$TMP/src-pairs.txt' '$TMP/cls-pairs.txt' >/dev/null 2>&1"
  assert "the collector documents how to add a source" \
    "grep -q 'ADDING A SOURCE' '$COLLECTOR'"
  assert "it states that a new level is an ADDITIVE schema change" \
    "grep -qi 'ADDITIVE schema change' '$COLLECTOR'"
  assert "it states the rule every consumer must honour" \
    "grep -qi 'CARRY AN UNKNOWN LEVEL' '$COLLECTOR'"
  assert "it rules out a plugin system / config file (Principle V)" \
    "grep -qi 'NOT A PLUGIN SYSTEM' '$COLLECTOR'"
else
  echo "     (collector absent — table parity skipped)"
fi
echo ""

echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
