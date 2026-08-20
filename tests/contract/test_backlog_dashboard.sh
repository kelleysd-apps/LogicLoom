#!/usr/bin/env bash
# Contract Tests: backlog dashboard generator (the human-facing viewer layer)
#
# Artifact under test:
#   .logic-loom/scripts/bash/build-backlog-dashboard.sh — reads the index emitted
#   by build-backlog-index.sh and renders ONE self-contained HTML page at
#   .logic-loom/backlog-dashboard.html.
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
#   * THE OUTPUT IS GITIGNORED AND UNTRACKED — same decision as the index, one
#     step stronger: the page embeds a FROZEN snapshot, so a tracked copy would
#     disagree with both the index and the sources.
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

PASS=0; FAIL=0; TOTAL=0
assert() {
  TOTAL=$((TOTAL + 1)); local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$ROOT"

GEN="$ROOT/.logic-loom/scripts/bash/build-backlog-dashboard.sh"
COLLECTOR="$ROOT/.logic-loom/scripts/bash/build-backlog-index.sh"
OUT_REL=".logic-loom/backlog-dashboard.html"
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
assert "page opens with a DOCTYPE" "head -1 '$PAGE' | grep -qi '^<!DOCTYPE html>'"
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

# ── 3. Grouping by status, with resolvable blocked_on links ──────────────────
echo "3. Items grouped by status; blocked_on renders as on-page links"
assert "all four status groups are present" \
  "grep -q 'id=\"grp-open\"' '$PAGE' && grep -q 'id=\"grp-in_progress\"' '$PAGE' && grep -q 'id=\"grp-blocked\"' '$PAGE' && grep -q 'id=\"grp-done\"' '$PAGE'"
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

# ── 9. The output path is gitignored and untracked ───────────────────────────
# Same load-bearing decision as the index, and stronger: this page embeds a
# FROZEN snapshot of the index, so a tracked copy could disagree with the index
# AND with the sources.
echo "9. The dashboard is gitignored and NOT tracked"
assert ".gitignore declares the dashboard path" \
  "grep -qxF '.logic-loom/backlog-dashboard.html' '$ROOT/.gitignore'"
assert "the ignore rule carries its rationale" \
  "grep -q 'Backlog dashboard (DERIVED' '$ROOT/.gitignore'"
TRACKED="$(git ls-files 2>/dev/null | grep -xF "$OUT_REL" || true)"
assert "git does not track the dashboard" "[ -z \"\$TRACKED\" ]"
GR="$TMP/gitignore-probe"
mkdir -p "$GR/.logic-loom"
cp "$ROOT/.gitignore" "$GR/.gitignore"
( cd "$GR" && git init -q . && git config user.email t@t && git config user.name t ) >/dev/null 2>&1
printf '<!DOCTYPE html>' > "$GR/$OUT_REL"
PROBE="$(cd "$GR" && git status --porcelain 2>/dev/null | grep -F 'backlog-dashboard.html' || true)"
assert "a dashboard file is invisible to git status under this .gitignore" "[ -z \"\$PROBE\" ]"
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
assert "strip manifest exists" "[ -f '$MANIFEST' ]"
assert "manifest strips artifacts/ WHOLESALE (not a fragile *.html glob)" \
  "grep -qE '^artifacts[[:space:]]*(#.*)?\$' '$MANIFEST'"
assert "the manifest entry carries its reason" \
  "grep -q 'Repo-root .artifacts/.' '$MANIFEST'"
assert "artifacts/ is documented in CLAUDE.md's directory structure" \
  "grep -q '^artifacts/' '$ROOT/CLAUDE.md'"
assert "artifacts/ has its own section in the file-structure policy" \
  "grep -q '^### artifacts/' '$ROOT/.docs/policies/file-structure-policy.md'"
assert "the policy states artifacts are never a plan" \
  "grep -qi 'never a plan' '$ROOT/.docs/policies/file-structure-policy.md'"
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
  assert "the real index has at least one item" "[ \"$REAL_N\" -ge 1 ]"
  assert "every index item reached the page" "[ \"$RENDERED\" = \"$REAL_N\" ]"
  assert "the real page has zero external references" \
    "! grep -qE 'http://|https://|//cdn' '$TMP/real.html'"
  SUM="$(grep -oE '<span class=\"count\">[0-9]+' "$TMP/real.html" | grep -oE '[0-9]+' | awk '{s+=$1} END {print s+0}')"
  assert "the four group counts sum to the item total" "[ \"\$SUM\" = \"$REAL_N\" ]"
else
  echo "     (collector absent — live check skipped)"
fi
echo ""

echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
