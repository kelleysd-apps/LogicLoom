#!/usr/bin/env bash
# =============================================================================
# Adopt-package MERGE 2 — .gitignore  (research § 6 PRE-8)
# -----------------------------------------------------------------------------
# WHAT THIS IS
#   A standalone, testable unit. It appends ONLY the harness-specific ignore
#   rules to a .gitignore the adopter owns, inside a marked fence. It is not the
#   applier: dry-run by default, it prints the resulting file and writes
#   nothing.
#
#   It NEVER reorders, rewrites, or removes a line the adopter already has. The
#   fence is appended at the end; everything above it is byte-identical.
#
# WHAT IT SHIPS, AND WHAT IT REFUSES TO SHIP
#   gitignore-block.txt, curated line by line against gitignore-decisions.txt.
#   Copying our .gitignore wholesale would append `.vscode/`, `package-lock.json`
#   and `dist/`/`build/` into someone else's repo — verified against kori-beta,
#   which TRACKS .vscode/settings.json and a 464 KB package-lock.json. The
#   decisions file records every ship and every drop with its reason, and
#   tests/contract/test_adopt_merges.sh holds the two files to each other.
#
# THE DIRTY-TREE CHECK, AND WHY IT IS HERE
#   Verified in kori-beta: its private-docs protection is five .gitignore rules
#   that exist ONLY as an uncommitted working-tree change, while docs/README.md
#   claims they live in .git/info/exclude — which is empty. The doc is wrong and
#   the protection is one `git checkout` from vanishing.
#
#   Appending on top of that would bury an intent that is not yet in git inside
#   a block we then claim to manage. So: if the target .gitignore has uncommitted
#   changes, this REPORTS and refuses. Committing first is the adopter's call,
#   not ours to make silently. `--allow-dirty` overrides, loudly.
#
#   This runs `git status --porcelain` and nothing else. It performs no git
#   mutation, ever.
#
# IDEMPOTENCY AND THE REFUSAL
#   * fence absent          -> append it
#   * fence present, body identical to the block -> NO-OP, exit 0
#   * fence present, body differs -> REFUSE. Someone edited inside our region;
#     overwriting it is exactly the clobber this unit exists to prevent.
#   * more than one fence   -> REFUSE (ambiguous region)
#   * unterminated fence    -> REFUSE
#
# EXIT CODES
#   0   appended, or already present (no-op)
#   10  refused — reason on stderr, target untouched
#   1   usage / unreadable input
#
# bash 3.2 safe: no associative arrays, no mapfile, no [[ -v ]], no ${var,,}.
# =============================================================================
set -uo pipefail

BEGIN_MARK="# >>> LogicLoom adopt — managed block. Do not edit inside. >>>"
END_MARK="# <<< LogicLoom adopt — end managed block <<<"

usage() {
  cat <<'EOF'
usage: merge-gitignore.sh --target <path> --block <path> [--write] [--allow-dirty]

  --target       the adopter's .gitignore (may not exist)
  --block        gitignore-block.txt
  --write        write the result; without it the merged file goes to stdout
                 and nothing is written
  --allow-dirty  proceed even though the target has uncommitted changes
EOF
}

TARGET=""
BLOCK=""
WRITE=0
ALLOW_DIRTY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    --block) BLOCK="${2:-}"; shift 2 ;;
    --write) WRITE=1; shift ;;
    --allow-dirty) ALLOW_DIRTY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [ -z "$TARGET" ] || [ -z "$BLOCK" ]; then
  echo "error: --target and --block are both required" >&2
  usage >&2
  exit 1
fi
if [ ! -f "$BLOCK" ]; then
  echo "error: block file not found: $BLOCK" >&2
  exit 1
fi
# A block without a trailing newline would run its last pattern into the end
# marker. Catch it here rather than emitting a corrupt fence.
if [ -s "$BLOCK" ] && [ -n "$(tail -c 1 "$BLOCK")" ]; then
  echo "error: block file does not end with a newline: $BLOCK" >&2
  exit 1
fi

refuse() { echo "refused: $1" >&2; exit 10; }

# ── The dirty-tree report ────────────────────────────────────────────────────
# Read-only. `git status --porcelain -- <path>` prints nothing for a clean or
# untracked-but-unmodified path and a status line otherwise. Outside a work
# tree there is nothing to check and the question does not arise.
TARGET_DIR="$(cd "$(dirname "$TARGET")" 2>/dev/null && pwd)"
if [ -n "$TARGET_DIR" ] && git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ -f "$TARGET" ]; then
    DIRTY="$(git -C "$TARGET_DIR" status --porcelain -- "$TARGET" 2>/dev/null)"
    if [ -n "$DIRTY" ]; then
      echo "$DIRTY" >&2
      if [ "$ALLOW_DIRTY" -eq 1 ]; then
        echo "warning: target .gitignore has uncommitted changes; proceeding because --allow-dirty was given" >&2
      else
        refuse "$TARGET has uncommitted changes (shown above). Appending on top of \
an ignore rule that is not yet committed buries an intent one \`git checkout\` \
from vanishing — the exact failure verified in kori-beta, whose private-docs \
rules live only in the working tree while its docs claim .git/info/exclude. \
Commit or stash the .gitignore first, or re-run with --allow-dirty."
      fi
    fi
  fi
fi

# ── Locate the fence ─────────────────────────────────────────────────────────
BEGIN_COUNT=0
END_COUNT=0
BEGIN_LINE=0
END_LINE=0
if [ -f "$TARGET" ]; then
  n=0
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    if [ "$line" = "$BEGIN_MARK" ]; then
      BEGIN_COUNT=$((BEGIN_COUNT + 1)); BEGIN_LINE=$n
    elif [ "$line" = "$END_MARK" ]; then
      END_COUNT=$((END_COUNT + 1)); END_LINE=$n
    fi
  done < "$TARGET"
fi

if [ "$BEGIN_COUNT" -gt 1 ] || [ "$END_COUNT" -gt 1 ]; then
  refuse "$TARGET contains more than one LogicLoom managed block; the region is \
ambiguous. Reduce it to one by hand."
fi
if [ "$BEGIN_COUNT" -ne "$END_COUNT" ]; then
  refuse "$TARGET has an unterminated LogicLoom managed block (begin=$BEGIN_COUNT \
end=$END_COUNT). Repair the fence by hand."
fi
if [ "$BEGIN_COUNT" -eq 1 ] && [ "$END_LINE" -lt "$BEGIN_LINE" ]; then
  refuse "$TARGET has the LogicLoom end marker before its begin marker."
fi

TMP="$(mktemp -t loom-gitignore.XXXXXX)" || { echo "error: mktemp failed" >&2; exit 1; }
trap 'rm -f "$TMP" "$TMP.body"' EXIT

if [ "$BEGIN_COUNT" -eq 1 ]; then
  # ── Fence present: compare, then no-op or refuse ───────────────────────────
  sed -n "$((BEGIN_LINE + 1)),$((END_LINE - 1))p" "$TARGET" > "$TMP.body"
  if diff -q "$TMP.body" "$BLOCK" >/dev/null 2>&1; then
    echo "status: nochange" >&2
    [ "$WRITE" -eq 1 ] || cat "$TARGET"
    exit 0
  fi
  echo "--- managed block in $TARGET" >&2
  echo "+++ $BLOCK" >&2
  diff "$TMP.body" "$BLOCK" >&2
  refuse "the LogicLoom managed block in $TARGET differs from the shipped block \
(diff above). That means someone edited inside our region, or the harness \
version changed. Refusing to clobber it — reconcile by hand, or delete the \
fenced block and re-run."
fi

# ── Fence absent: append ─────────────────────────────────────────────────────
if [ -f "$TARGET" ]; then
  cat "$TARGET" > "$TMP"
  # Guarantee the adopter's last line is terminated before we append, without
  # touching any byte of it.
  if [ -s "$TMP" ] && [ -n "$(tail -c 1 "$TMP")" ]; then
    printf '\n' >> "$TMP"
  fi
  if [ -s "$TMP" ]; then
    printf '\n' >> "$TMP"
  fi
else
  : > "$TMP"
fi

printf '%s\n' "$BEGIN_MARK" >> "$TMP"
cat "$BLOCK" >> "$TMP"
printf '%s\n' "$END_MARK" >> "$TMP"

if [ "$WRITE" -eq 1 ]; then
  cat "$TMP" > "$TARGET"
else
  cat "$TMP"
fi
echo "status: merged" >&2
exit 0
