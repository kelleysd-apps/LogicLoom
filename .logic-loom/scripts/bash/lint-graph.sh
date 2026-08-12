#!/usr/bin/env bash
# lint-graph.sh — fail-open linter over graph-bridge.jsonl (Phase 1).
# WARNS on dangling covers (code-path missing on disk) and dangling links-to
# (target note missing); INFO on orphan notes (no edges). ALWAYS exits 0.
#
# Usage: lint-graph.sh [JSONL] [--root REPO_ROOT]
#   JSONL   default: <repo-root>/.logic-loom/graph/graph-bridge.jsonl
#   --root  repo root used to test path existence (default: resolved from script)
set -euo pipefail

JSONL=""; ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 || true ;;
    --root=*) ROOT="${1#--root=}"; shift ;;
    *) [ -z "$JSONL" ] && JSONL="$1"; shift ;;
  esac
done
_sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -n "$ROOT" ] || ROOT="$(cd "$_sd/../../.." && pwd)"
[ -n "$JSONL" ] || JSONL="$ROOT/.logic-loom/graph/graph-bridge.jsonl"

if ! command -v jq >/dev/null 2>&1; then
  echo "INFO: jq not found; skipping lint (fail-open)"; echo "graph-lint: 0 warnings, 0 infos"; exit 0
fi
if [ ! -f "$JSONL" ]; then
  echo "INFO: bridge file '$JSONL' not found; nothing to lint (fail-open)"
  echo "graph-lint: 0 warnings, 0 infos"; exit 0
fi

warn=0; info=0

# --- gather node ids that appear as an edge endpoint (for orphan detection) ---
EDGED="$(mktemp)"; trap 'rm -f "$EDGED"' EXIT
jq -r 'select(.type=="relation") | .from, .to' "$JSONL" 2>/dev/null | LC_ALL=C sort -u > "$EDGED" || true

# --- dangling covers: covers-edge target (code-path) missing on disk ---------
while IFS= read -r p; do
  [ -n "$p" ] || continue
  if [ ! -e "$ROOT/$p" ]; then echo "WARN: dangling covers -> missing code path '$p'"; warn=$((warn+1)); fi
done < <(jq -r 'select(.type=="relation" and .relationType=="covers") | .to' "$JSONL" 2>/dev/null | LC_ALL=C sort -u || true)

# --- dangling links-to: target note not present as a file --------------------
while IFS= read -r p; do
  [ -n "$p" ] || continue
  if [ ! -f "$ROOT/$p" ]; then echo "WARN: dangling links-to -> missing note '$p'"; warn=$((warn+1)); fi
done < <(jq -r 'select(.type=="relation" and .relationType=="links-to") | .to' "$JSONL" 2>/dev/null | LC_ALL=C sort -u || true)

# --- orphan notes: note-entity with no incident edge -------------------------
while IFS= read -r n; do
  [ -n "$n" ] || continue
  grep -qxF "$n" "$EDGED" || { echo "INFO: orphan note (no edges) '$n'"; info=$((info+1)); }
done < <(jq -r 'select(.type=="entity" and .entityType=="note") | .name' "$JSONL" 2>/dev/null | LC_ALL=C sort -u || true)

echo "graph-lint: $warn warnings, $info infos"
exit 0
