#!/usr/bin/env bash
# =============================================================================
# LogicLoom — build-time DEV-HISTORY scrubber (dev-main → clean public template)
# Purpose: remove development-PROCESS history NARRATIVE that is EMBEDDED inside
#          shipped product files, so the public template reads as a clean harness
#          stood up for the first time — while KEEPING the current product-version
#          IDENTITY. Complements strip-harness-dev.sh (which removes whole
#          harness-dev FILES); this scrubs history *within* files that ship.
#
# DATA-DRIVEN: all edits live in history-scrub-rules.json (generated from the
# history-surface classification). Ops: drop-section | delete-line | genericize.
# leak-guard.sh asserts the post-scrub markers are ABSENT (the safety net).
#
# DESTRUCTIVE + IDEMPOTENT. Pure text edits — does NOT require git. Runs ONLY in
# CI during a promotion build, AFTER strip-harness-dev + sanitize-for-template,
# from a PRESERVED copy (this script + its rules are manifest-stripped from the
# tree, so — like leak-guard — run it from /tmp/loom-audit-tools and target the
# tree via LOOM_SCRUB_ROOT). dev-main is NEVER edited; only the snapshot is.
#
# Usage:
#   LOOM_SCRUB_ROOT="$PWD" bash /tmp/loom-audit-tools/history-scrub.sh
#   bash .logic-loom/scripts/bash/history-scrub.sh --dry-run    # report only
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Rules travel WITH the script (preserved together). Target tree is overridable.
RULES="${LOOM_SCRUB_RULES:-$SCRIPT_DIR/history-scrub-rules.json}"
TARGET_ROOT="${LOOM_SCRUB_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

command -v python3 >/dev/null 2>&1 || { echo "FATAL: python3 required"; exit 1; }
[ -f "$RULES" ] || { echo "FATAL: rules not found: $RULES"; exit 1; }
[ -d "$TARGET_ROOT" ] || { echo "FATAL: target root not found: $TARGET_ROOT"; exit 1; }

echo "history-scrub: rules=$RULES target=$TARGET_ROOT dry=$DRY"

LOOM_SCRUB_ROOT="$TARGET_ROOT" LOOM_SCRUB_RULES="$RULES" LOOM_SCRUB_DRY="$DRY" python3 - <<'PY'
import json, os, re, sys

root  = os.environ["LOOM_SCRUB_ROOT"]
rules = json.load(open(os.environ["LOOM_SCRUB_RULES"], encoding="utf-8"))
dry   = os.environ["LOOM_SCRUB_DRY"] == "1"

def level(line):
    m = re.match(r'^(#{1,6})\s', line)
    return len(m.group(1)) if m else 0

def drop_section(text, heading):
    """Remove a markdown section: from the heading line to the next heading of
    equal-or-higher level, or a '---' rule, or EOF."""
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
    """Drop every full line that constitutes the (possibly multi-line) literal
    match block. Exact rstrip-equality keeps it from over-deleting."""
    targets = {m.rstrip() for m in match.split('\n') if m.strip()}
    if not targets:
        return text, False
    out, changed = [], False
    for ln in text.split('\n'):
        if ln.rstrip() in targets:
            changed = True; continue
        out.append(ln)
    return '\n'.join(out), changed

def genericize(text, frm, to):
    """Literal substring replace, ALL occurrences (per coverage note: e.g. the
    3 'Plugin-First Architecture v4.0' sites in constitutional-check.sh)."""
    if frm and frm in text:
        return text.replace(frm, to), True
    return text, False

def collapse(text):
    """Tidy artifacts left by removals: >=2 blank lines -> 1; a '---' immediately
    following another '---' (blanks ignored) is dropped."""
    text = re.sub(r'\n{3,}', '\n\n', text)
    out = []
    for ln in text.split('\n'):
        if ln.strip() == '---':
            prev = next((x for x in reversed(out) if x.strip() != ''), None)
            if prev is not None and prev.strip() == '---':
                continue
        out.append(ln)
    return '\n'.join(out)

OP = {'drop-section': drop_section, 'delete-line': delete_line, 'genericize': genericize}

total_applied = total_missed = files_changed = files_missing = 0
miss_report = []

for rule in rules['scrubRules']:
    rel = rule['path']
    path = os.path.join(root, rel)
    if not os.path.isfile(path):
        files_missing += 1
        # A file legitimately removed by strip (e.g. nothing here) — not an error.
        continue
    text = open(path, encoding='utf-8').read()
    orig = text
    applied = missed = 0
    for op in rule['ops']:
        kind = op['op']
        if kind == 'genericize':
            text, ok = genericize(text, op['match'], op.get('replacement', ''))
        elif kind == 'drop-section':
            text, ok = drop_section(text, op['match'])
        elif kind == 'delete-line':
            text, ok = delete_line(text, op['match'])
        else:
            ok = False
        if ok:
            applied += 1
        else:
            missed += 1
            miss_report.append(f"  MISS {rel} [{kind}] {op['match'].splitlines()[0][:70]!r}")
    if text != orig:
        text = collapse(text)
        if not dry:
            open(path, 'w', encoding='utf-8').write(text)
        files_changed += 1
    total_applied += applied
    total_missed += missed
    print(f"  {'(dry) ' if dry else ''}{rel}: {applied} applied, {missed} missed")

print(f"\nhistory-scrub: {files_changed} files changed, {total_applied} ops applied, "
      f"{total_missed} missed, {files_missing} rule-files absent (likely strip-removed).")
if miss_report:
    print("MISSED ops (rule did not match — verify vs leak-guard HISTORY markers):")
    print('\n'.join(miss_report))
# Missed ops are warnings, not fatal: leak-guard's HISTORY_MARKERS scan is the
# hard gate that fails the build if any dev-history actually survived.
PY
echo "history-scrub: done."
