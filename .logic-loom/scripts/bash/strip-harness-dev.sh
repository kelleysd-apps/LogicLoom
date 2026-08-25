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

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${BLUE}LogicLoom strip-harness-dev (manifest: $MANIFEST)${NC}"

[ -f "$MANIFEST" ] || { echo "FATAL: manifest not found: $MANIFEST"; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "FATAL: not a git work tree"; exit 1; }

TRACKED="$(git ls-files)"

# write_stub <target-path> <template-path>
# CONTENT-REPLACE <target> with <template>. Both are repo-relative; both come
# from the manifest `stub: <path> :: <template>` entry — there is NO default
# template and no fallback body. A missing/undeclared template ABORTS the strip.
#
# WHY NO FALLBACK: this function used to be write_vision_stub(), hardcoded to the
# project-vision template for EVERY stub: target, with an inline heredoc copy of
# that template as a fallback. With one stub entry that was invisible; the second
# entry (.logic-loom/memory/backlog.md) would have shipped a PRODUCT VISION stub
# in place of the backlog. A wrong stub ships silently and looks plausible; a
# failed release is loud and cheap. So: resolve or abort.
write_stub() {
  local target="$1" template="$2"
  if [ -z "$template" ]; then
    echo "FATAL: manifest stub entry for '$target' declares no template." >&2
    echo "       Grammar: stub: <path> :: <template>  (see $MANIFEST)" >&2
    exit 1
  fi
  if [ ! -f "$REPO_ROOT/$template" ]; then
    echo "FATAL: stub template not found: $template (declared for '$target')" >&2
    echo "       Refusing to ship an unstubbed or wrongly-stubbed file." >&2
    exit 1
  fi
  cp "$REPO_ROOT/$template" "$REPO_ROOT/$target"
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
    spec="$(printf '%s' "${line#stub:}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    case "$spec" in
      *::*)
        target="$(printf '%s' "${spec%%::*}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        template="$(printf '%s' "${spec#*::}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        ;;
      *)
        target="$spec"; template=""
        ;;
    esac
    write_stub "$target" "$template"
    echo -e "${GREEN}  stub  ${NC}$target <- $template"
    continue
  fi

  if [[ "$line" == warn:* ]]; then
    pat="$(printf '%s' "${line#warn:}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    echo -e "${YELLOW}  keep  ${NC}$pat (deferred — not stripped)"
    continue
  fi

  strip_entry "$line"
done < "$MANIFEST"

# --- Re-derive the plugin→command bridge manifest -----------------------------
# .claude/commands/.bridge-manifest.json SHIPS (it is how Claude Code discovers
# slash commands), but it is a DERIVED index of .claude/commands/*.md. Stripping
# a maintainer-only command (e.g. /promote: both the plugin source and its bridge
# wrapper are manifest entries above) leaves the index advertising a command the
# shipped tree no longer contains.
#
# Fix it by RE-DERIVING rather than by teaching either side about the other:
# the bridge stays ignorant of release topology (it has no "maintainer-only"
# concept and should not grow one — that lives in template-strip-manifest.txt),
# and the strip step does not hand-edit a generated file. `prune` is the right
# verb: it drops orphaned wrappers and rewrites the manifest, without re-adding
# anything `sync` would resurrect. Output is deterministic, so on a tree with
# nothing stripped this is a no-op.
BRIDGE="$REPO_ROOT/.logic-loom/scripts/bash/sync-plugin-commands.sh"
if [ -f "$BRIDGE" ]; then
  bash "$BRIDGE" prune >/dev/null
  echo -e "${GREEN}  regen ${NC}.claude/commands/.bridge-manifest.json (post-strip)"
else
  echo -e "${YELLOW}  warn  ${NC}sync-plugin-commands.sh absent — bridge manifest NOT re-derived"
fi

# --- Prune each plugin's declared agents/skills/commands inventory ------------
# Mirrors the bridge-manifest re-derivation immediately above, for the SAME
# reason: a strip entry can remove a command file (e.g. plugins/loom-maintenance/
# commands/promote.md) while `plugins/loom-maintenance/.claude-plugin/plugin.json`
# still lists `promote` in its `commands.list`. That manifest is validated —
# .logic-loom/scripts/python/validate-plugin-manifests.py and
# tests/contract/test_plugin_manifest_schema.sh both require every declared
# `agents`/`skills`/`commands` entry to have a backing file on disk — so a strip
# that removes a file without also removing its manifest entry ships a tree that
# fails its own manifest validator on first CI run. (This is exactly the LOOM
# bug the strip manifest's own comment on promote.md used to describe as "no
# test validates against files" — that comment was stale; the validator does.)
#
# Fixed the same way as the bridge manifest: RE-DERIVE, don't hand-edit. The
# strip step does not learn which specific entries are release-sensitive (that
# stays declared once, in template-strip-manifest.txt); it just prunes any
# manifest entry whose backing file the strip already removed, using the exact
# same on-disk convention the validator itself uses (agents/commands -> `<name>
# .md`; skills -> a subdirectory named `<name>`). An entry is DROPPED, never
# ADDED — this only removes references to files that are now gone; it never
# invents a declaration for a file that happens to exist on disk. Deterministic
# and idempotent: on a tree where nothing was stripped, every declared entry
# still has a backing file, so no manifest is rewritten.
if command -v python3 >/dev/null 2>&1; then
  # NOTE: the heredoc is NOT wrapped in $( ) — bash 3.2 (the floor this repo
  # targets) mis-parses quotes inside a heredoc nested in command substitution,
  # and an apostrophe in a Python comment below was enough to break the whole
  # script with "unexpected EOF". Redirect to a temp file and read it back.
  PRUNE_LOG="$(mktemp 2>/dev/null || mktemp -t loomprune)"
  REPO_ROOT="$REPO_ROOT" python3 - > "$PRUNE_LOG" <<'PY'
import json
import os
import sys

repo_root = os.environ["REPO_ROOT"]
plugins_dir = os.path.join(repo_root, "plugins")
if not os.path.isdir(plugins_dir):
    sys.exit(0)


def backing_exists(plugin_dir, kind, entry):
    # Same convention as validate-plugin-manifests.py's _inventory_on_disk():
    # agents/commands -> `<name>.md`; skills -> a subdirectory named `<name>`.
    if kind == "skills":
        return os.path.isdir(os.path.join(plugin_dir, "skills", entry))
    return os.path.isfile(os.path.join(plugin_dir, kind, entry + ".md"))


for name in sorted(os.listdir(plugins_dir)):
    plugin_dir = os.path.join(plugins_dir, name)
    manifest = os.path.join(plugin_dir, ".claude-plugin", "plugin.json")
    if not os.path.isfile(manifest):
        continue
    with open(manifest, encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, dict):
        continue

    changed = False
    for kind in ("agents", "skills", "commands"):
        block = data.get(kind)
        if not isinstance(block, dict) or "list" not in block:
            continue
        declared = block["list"]
        if not isinstance(declared, list):
            continue
        pruned = [
            entry for entry in declared
            if isinstance(entry, str) and backing_exists(plugin_dir, kind, entry)
        ]
        if pruned != declared:
            block["list"] = pruned
            changed = True

    if changed:
        with open(manifest, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2)
            fh.write("\n")
        print(os.path.relpath(manifest, repo_root))
PY
  while IFS= read -r line; do
    [ -n "$line" ] && echo -e "${GREEN}  prune ${NC}$line (post-strip manifest inventory)"
  done < "$PRUNE_LOG"
  rm -f "$PRUNE_LOG"
else
  echo -e "${YELLOW}  warn  ${NC}python3 absent — plugin manifest inventories NOT re-derived"
fi

# Release order is  sanitize-for-template.sh -> strip-harness-dev.sh (this) ->
# history-scrub.sh -> sanitization-audit.sh  (.github/workflows/promote-to-main.yml,
# "Build sanitized tree from dev-main"). This message used to name
# sanitize-for-template.sh as the NEXT step; it runs BEFORE this script, and this
# script has just deleted it from the tree, so following that advice pointed at a
# file that no longer exists. The two steps that really do come next are also
# stripped by this pass, so they must be run from a copy preserved beforehand.
echo -e "${GREEN}Done.${NC} Next: history-scrub.sh, then sanitization-audit.sh"
echo -e "       (both are stripped from this tree — run them from a copy taken"
echo -e "        BEFORE the strip; sanitize-for-template.sh already ran, before this.)"
