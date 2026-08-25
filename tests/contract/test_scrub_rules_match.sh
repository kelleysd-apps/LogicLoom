#!/usr/bin/env bash
# Contract Tests: every history-scrub rule still matches something
#
# Closes the class behind a real, 7-week-silent rot: history-scrub-rules.json
# pinned 19 dated-stamp rules to LITERAL dates ("**Last Updated**: 2026-06-15").
# The docs were updated, the literals stopped matching, and because a missed op
# is only a WARNING in history-scrub.sh (leak-guard is the hard gate), nobody
# noticed — stale date stamps shipped into two releases before the
# delete-line-regex op was added on 2026-08-13.
#
# The invariant: a scrub rule that matches NOTHING is dead weight that silently
# stops scrubbing. Every op in every rule must match its target file at least
# once, or be on the EXCLUSIONS list below with a stated reason.
#
# Matching is done by REPLAYING history-scrub.sh's own matcher semantics
# (drop-section / delete-line / delete-line-regex / genericize) against the
# current tree, in file order and cumulatively — exactly as the scrubber applies
# them — but purely in memory. Nothing is written; the tree is not modified.
#
# A missing TARGET FILE fails loudly here. history-scrub.sh deliberately treats
# an absent rule-file as benign ("likely strip-removed") because it runs on an
# already-stripped snapshot; on dev-main, where this suite runs, an absent target
# means the rule points at a file that no longer exists.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
# Overridable for meta-testing: LOOM_SCRUB_RULES.
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

RULES="${LOOM_SCRUB_RULES:-$ROOT/.logic-loom/scripts/bash/history-scrub-rules.json}"

# ── EXCLUSIONS ───────────────────────────────────────────────────────────────
# Rules allowed to match nothing. Format, one per line:
#     <target path><TAB-free ' :: '><first line of the rule's `match` string>
# Every entry needs a reason. An exclusion that STARTS matching again is
# reported as stale and fails — the list may not rot the way the rules did.
#
# ⚠ THE LIST IS EMPTY BY DESIGN. The 10 permanent no-ops this suite originally
# carried here were DELETED from history-scrub-rules.json instead (2026-08-15,
# 136 ops → 126, 51 rules → 47). Carrying a permanent no-op as an exclusion is a
# slower version of the rot this test exists to prevent — an exclusion is for a
# no-op that is expected to start matching again, not for a dead rule.
#
# The mechanism and the stale-exclusion check in section 4 stay in place: they
# guard any FUTURE entry. Before adding one, be sure the rule is temporarily
# dormant rather than permanently dead — if it can never fire again, delete the
# rule.
EXCLUSIONS=""

is_excluded() {
  local key="$1" e
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    [ "$e" = "$key" ] && return 0
  done <<EOF
$EXCLUSIONS
EOF
  return 1
}

echo "═══ History-Scrub Rules Match Something ═══"
echo ""

echo "0. Inputs present"
if [ "$TREE_KIND" = "sanitized" ]; then
  # history-scrub-rules.json is itself a maintainer-only strip-manifest entry
  # (it exists to scrub OUR dev-line identity markers before promotion) — it
  # cannot exist on a sanitized tree, and neither can anything this suite
  # checks against it. Skip the whole body rather than a hard fail: this is
  # the expected, by-design state of a customer/promoted checkout, not a
  # defect. See tests/lib/tree-provenance.sh for why this is a narrow, named
  # skip rather than a silent early-exit.
  skip "rules file present: ${RULES#$ROOT/}" \
    "history-scrub-rules.json is stripped — sanitized tree (maintainer-only file)"
  skip "every rule's target file exists" \
    "history-scrub-rules.json is stripped — sanitized tree (maintainer-only file)"
  skip "every scrub op matches its target at least once" \
    "history-scrub-rules.json is stripped — sanitized tree (maintainer-only file)"
  skip "replay is live and every op kind is known" \
    "history-scrub-rules.json is stripped — sanitized tree (maintainer-only file)"
  skip "no stale EXCLUSIONS entry" \
    "history-scrub-rules.json is stripped — sanitized tree (maintainer-only file)"
  echo ""
  echo "════════════════════════════════"
  echo " Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
  echo "✅ ALL TESTS PASSED (nothing to check on a sanitized tree)"
  exit 0
fi
assert "rules file present: ${RULES#$ROOT/}" "[ -f \"\$RULES\" ]"
assert "python3 available (rule matcher)" "command -v python3 >/dev/null 2>&1"
if [ ! -f "$RULES" ] || ! command -v python3 >/dev/null 2>&1; then
  echo ""
  echo "════════════════════════════════"
  echo " Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
  echo "❌ SOME TESTS FAILED"
  exit 1
fi

# ── Replay history-scrub.sh's matchers, report only ──────────────────────────
# Emits one record per line:
#   MISSINGFILE<TAB><path>
#   OP<TAB><path><TAB><kind><TAB>HIT|MISS<TAB><first line of match>
REPORT="$(LOOM_SCRUB_ROOT="$ROOT" LOOM_SCRUB_RULES="$RULES" python3 - <<'PY'
import json, os, re

root  = os.environ["LOOM_SCRUB_ROOT"]
rules = json.load(open(os.environ["LOOM_SCRUB_RULES"], encoding="utf-8"))

# --- matchers copied from history-scrub.sh (detection only, no writes) -------
def level(line):
    m = re.match(r'^(#{1,6})\s', line)
    return len(m.group(1)) if m else 0

def drop_section(text, heading):
    lines = text.split('\n')
    hs = heading.strip()
    idx = None
    for i, ln in enumerate(lines):
        if ln.strip() == hs or ln.startswith(heading):
            idx = i; break
    if idx is None:
        return text, False
    tl = level(lines[idx]) or 99
    j = idx + 1
    while j < len(lines):
        lv = level(lines[j])
        if (lv > 0 and lv <= tl) or lines[j].strip() == '---':
            break
        j += 1
    return '\n'.join(lines[:idx] + lines[j:]), True

def delete_line(text, match):
    targets = {m.rstrip() for m in match.split('\n') if m.strip()}
    if not targets:
        return text, False
    out, changed = [], False
    for ln in text.split('\n'):
        if ln.rstrip() in targets:
            changed = True; continue
        out.append(ln)
    return '\n'.join(out), changed

def delete_line_regex(text, pattern):
    try:
        rx = re.compile(pattern)
    except re.error:
        return text, False
    out, changed = [], False
    for ln in text.split('\n'):
        if rx.search(ln):
            changed = True; continue
        out.append(ln)
    return text if not changed else '\n'.join(out), changed

def genericize(text, frm, to):
    if frm and frm in text:
        return text.replace(frm, to), True
    return text, False
# ---------------------------------------------------------------------------

for rule in rules['scrubRules']:
    rel  = rule['path']
    path = os.path.join(root, rel)
    if not os.path.isfile(path):
        print("MISSINGFILE\t%s" % rel)
        continue
    text = open(path, encoding='utf-8').read()
    for op in rule['ops']:
        kind = op['op']
        m    = op.get('match', '')
        if kind == 'genericize':
            text, ok = genericize(text, m, op.get('replacement', ''))
        elif kind == 'drop-section':
            text, ok = drop_section(text, m)
        elif kind == 'delete-line':
            text, ok = delete_line(text, m)
        elif kind == 'delete-line-regex':
            text, ok = delete_line_regex(text, m)
        else:
            ok = False
            kind = "UNKNOWN-OP:" + kind
        first = (m.splitlines() or [''])[0]
        print("OP\t%s\t%s\t%s\t%s" % (rel, kind, "HIT" if ok else "MISS", first))
PY
)"
PY_STATUS=$?
assert "rule matcher ran without error" "[ $PY_STATUS -eq 0 ] && [ -n \"\$REPORT\" ]"

# ── 1. Every rule targets a file that exists ─────────────────────────────────
echo ""
echo "1. Every rule's target file exists"
MISSING_FILES="$(grep '^MISSINGFILE	' <<< "$REPORT" | cut -f2)"
[ -n "$MISSING_FILES" ] && { echo "     MISSING TARGET FILE(S) — the rule points at a path that is gone.";
  echo "     Delete the rule block from ${RULES#$ROOT/}, or fix its \"path\":";
  printf '%s\n' "$MISSING_FILES" | sed 's/^/       - /'; }
assert "no scrub rule targets a missing file" "[ -z \"\$MISSING_FILES\" ]"

# ── 2. Every op matches at least once ────────────────────────────────────────
echo ""
echo "2. Every scrub op matches its target at least once"
OP_COUNT=0; HIT_COUNT=0
DEAD=""; EXCUSED=""
while IFS=$'\t' read -r tag rel kind status first; do
  [ "$tag" = "OP" ] || continue
  OP_COUNT=$((OP_COUNT + 1))
  key="${rel} :: ${first}"
  if [ "$status" = "HIT" ]; then
    HIT_COUNT=$((HIT_COUNT + 1))
    continue
  fi
  if is_excluded "$key"; then
    EXCUSED="${EXCUSED}[${kind}] ${key}"$'\n'
  else
    DEAD="${DEAD}[${kind}] ${key}"$'\n'
  fi
done <<EOF
$REPORT
EOF

echo "     (replayed $OP_COUNT ops; $HIT_COUNT matched)"
if [ -n "$EXCUSED" ]; then
  echo "     documented no-ops (see EXCLUSIONS in this file — all flagged for DELETION):"
  printf '%s' "$EXCUSED" | sed 's/^/       - /'
fi
if [ -n "$DEAD" ]; then
  echo "     DEAD SCRUB RULE(S) — the pattern matches nothing in its target file:"
  printf '%s' "$DEAD" | sed 's/^/       - /'
  echo "     This is the exact rot that shipped stale date stamps: a missed op is"
  echo "     only a warning at build time. Either fix the pattern (dated stamps"
  echo "     MUST use delete-line-regex), DELETE the rule if it is a permanent"
  echo "     no-op, or add it to EXCLUSIONS above with a stated reason."
fi
assert "no scrub rule matches nothing" "[ -z \"\$DEAD\" ]"

# ── 3. The replay is live, and every op kind is understood ───────────────────
echo ""
echo "3. Replay is live and every op kind is known"
assert "ops were replayed" "[ \$OP_COUNT -gt 0 ]"
assert "most ops still match (>=80%)" "[ \$((HIT_COUNT * 100)) -ge \$((OP_COUNT * 80)) ]"
assert "no unknown op kind in the ruleset" \
  "! grep -q 'UNKNOWN-OP:' <<< \"\$REPORT\""

# ── 4. No stale exclusion ────────────────────────────────────────────────────
# An exclusion whose op now matches must be removed, or it silently protects a
# rule that no longer needs protecting.
echo ""
echo "4. No stale EXCLUSIONS entry"
HIT_KEYS="$(grep '^OP	' <<< "$REPORT" | awk -F'\t' '$4=="HIT"{print $2 " :: " $5}')"
ALL_KEYS="$(grep '^OP	' <<< "$REPORT" | awk -F'\t' '{print $2 " :: " $5}')"
STALE=""
while IFS= read -r e; do
  [ -n "$e" ] || continue
  if grep -qxF -- "$e" <<< "$HIT_KEYS"; then
    STALE="${STALE}${e}   (now matches — remove the exclusion)"$'\n'
  elif ! grep -qxF -- "$e" <<< "$ALL_KEYS"; then
    STALE="${STALE}${e}   (no such rule — remove the exclusion)"$'\n'
  fi
done <<EOF
$EXCLUSIONS
EOF
[ -n "$STALE" ] && { echo "     STALE EXCLUSIONS:"; printf '%s' "$STALE" | sed 's/^/       - /'; }
assert "no stale EXCLUSIONS entry" "[ -z \"\$STALE\" ]"

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed, $SKIP skipped"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
