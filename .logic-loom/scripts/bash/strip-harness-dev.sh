#!/bin/bash
# =============================================================================
# LogicLoom — strip harness-dev artifacts (dev-main → sanitized public main)
# Purpose: Remove OUR harness-development record from a tree being promoted to
#          the customer-facing template. Manifest-driven (template-strip-
#          manifest.txt) so "what is harness-dev" lives in ONE place, shared
#          with leak-guard.sh — they use the SAME tracked-content matcher so a
#          strip and its guard can never disagree.
#
# TRACKED-CONTENT MODEL: operates on `git ls-files` (tracked paths only).
# Gitignored runtime state never enters the checkout, so a tracked `.gitkeep`
# under an otherwise-runtime dir survives untouched.
#
# DESTRUCTIVE + IDEMPOTENT. Run ONLY on a fresh checkout/worktree of dev-main in
# CI — never in place against a working tree with uncommitted work.
#
# Usage:   bash .logic-loom/scripts/bash/strip-harness-dev.sh
# Verify:  bash .logic-loom/scripts/bash/leak-guard.sh   (non-destructive)
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

MANIFEST="$SCRIPT_DIR/template-strip-manifest.txt"
STUB_TEMPLATE="$REPO_ROOT/.logic-loom/templates/project-vision-template.md"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${BLUE}LogicLoom strip-harness-dev (manifest: $MANIFEST)${NC}"

[ -f "$MANIFEST" ] || { echo "FATAL: manifest not found: $MANIFEST"; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "FATAL: not a git work tree"; exit 1; }

TRACKED="$(git ls-files)"

write_vision_stub() {
  local target="$REPO_ROOT/$1"
  if [ -f "$STUB_TEMPLATE" ]; then
    cp "$STUB_TEMPLATE" "$target"
  else
    # Fallback stub if the template is somehow absent (keeps references resolving).
    cat > "$target" <<'STUB'
# PRODUCT VISION — <Your Product>

> A LIVING root-level north-star for THIS project (distinct from per-feature
> `features/<name>/vision.md`). Scaffolded/filled by `/initialize-project`.
> Replace every placeholder; new tasks are generated FROM this document.

## North Star
<One sentence: the change this product makes in the world.>

## Why we exist (the bet)
<The core hypothesis this product is testing.>

## Who this is for
<Primary users / customers and the job they hire this product to do.>

## What success looks like
- **Qualitative**: <what "good" feels like for a user>
- **Quantitative**: <measurable targets>

## Strategic Pillars (each pillar seeds tasks)
1. **<Pillar>** — <why it matters>

## What this is NOT (explicit non-goals)
- <a thing you are deliberately not doing>

## Open Threads (the live backlog — generate tasks from here)
- <open question or bet to resolve>

## Keeping this document alive
Review at every retro. A fresh session should re-orient from VISION.md + memory
+ CLAUDE.md alone. Read alongside CLAUDE.md, AGENTS.md, and project memory.
STUB
  fi
}

# Remove every tracked path matching a manifest glob (and prune emptied dirs).
strip_entry() {
  local pat="$1" any=0 f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
      $pat|$pat/*)
        rm -f "$REPO_ROOT/$f"
        any=1
        ;;
    esac
  done <<EOF
$TRACKED
EOF
  if [ "$any" -eq 1 ]; then
    echo -e "${GREEN}  strip ${NC}$pat"
    # prune now-empty directories left behind (ignore failures)
    find "$REPO_ROOT" -type d -empty -not -path '*/.git/*' -delete 2>/dev/null || true
  fi
}

while IFS= read -r raw; do
  line="${raw%%#*}"                       # drop inline comment
  line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [ -z "$line" ] && continue

  if [[ "$line" == stub:* ]]; then
    target="$(printf '%s' "${line#stub:}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    write_vision_stub "$target"
    echo -e "${GREEN}  stub  ${NC}$target"
    continue
  fi

  if [[ "$line" == warn:* ]]; then
    pat="$(printf '%s' "${line#warn:}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    echo -e "${YELLOW}  keep  ${NC}$pat (deferred — not stripped)"
    continue
  fi

  strip_entry "$line"
done < "$MANIFEST"

echo -e "${GREEN}Done.${NC} Next: sanitize-for-template.sh, then sanitization-audit.sh"
