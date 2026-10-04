#!/bin/sh
# updates-checks.sh -- the standalone checks runner of the /update-loom engine family.
#
# Usage: sh updates-checks.sh [--root DIR] [--tools DIR] [--only <id>]
#
# Runs the check of every improvement note, cumulatively across every release folder
# (never only the newest) in version order, and fails closed for a safety note.
# POSIX sh + awk only; set -u; the shared library is sourced from this script's own
# directory.
#
#   --root DIR   the tree under test (default: the git toplevel of the current
#                directory, else the current directory)
#   --tools DIR  the directory holding json-valid.sh and json-flat.sh that every
#                check sees as UPDATE_TOOLS (default: this script's own directory)
#   --only ID    run only the note with that id (the engine uses this in hold-back);
#                the linter is skipped, so an unrelated note cannot fail the re-run
#
# Rules
#   - No notes (no notes folder, or only README.md): print `notes=none`, exit 0. A
#     tree older than the notes must never fail an update or a test run. A release
#     folder that cannot be read is `error ...` on stderr and exit 1, never notes=none,
#     and no scratch space under TMPDIR is the same (the shared library exits 1).
#   - Otherwise print `mode=<template-repo|copy>` (ul_copy_mode: all five maintainer
#     markers present means the template repo, anything else a customer copy), then run
#     the linter beside this script first. A missing or failing linter is
#     `FAIL updates-lint`. In a copy the linter gets --no-tree-rules: touches and
#     removes rows only hold in upstream's own tree.
#   - For every note, read id, safety and check from the frontmatter and run the check as
#       (cd ROOT && REPO_ROOT=ROOT UPDATE_TOOLS=TOOLS sh <check>)
#     capturing stdout. Exit 0 with a last line skip=<reason> is `SKIP <id> <reason>`;
#     any other exit 0 is `PASS <id>`; a non-zero exit is FAIL for a safety note in any
#     copy, WARN for any other note in a customer copy, and FAIL for any other note in
#     the template repo.
#   - A safety note with check: none, with a check file that is missing or unreadable,
#     or with a safety value that is not true or false is FAIL. A non-safety note with
#     check: none passes (offered once, never re-verified); with a missing check file it
#     is WARN in a copy and FAIL in the template repo.
#   - Per-note lines: `PASS <id>`, `WARN <id>`, `FAIL <id>`, `SKIP <id> <reason>`; an
#     indented line under a WARN or FAIL may say why. When something FAILed, each
#     failing check's last line (hint=...) is replayed verbatim just before the final
#     line, so a plain reason survives a tail of a long run. WARN hints are not replayed.
#   - Final line: `notes=<n> ok` (exit 0) or `notes=<n> failed=<k>` (exit 1).
#     A usage error exits 2.
#
# Not done here: detecting a check that writes into the tree. The engine runs checks
# against an export and verifies before and after; this runner runs them in place.

set -u
LC_ALL=C
export LC_ALL

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 1
. "$here/update-loom-common.sh"
ul_install_traps

nl='
'

usage_error() { # sentence
  printf 'error %s\n' "$1" >&2
  printf 'usage: sh updates-checks.sh [--root DIR] [--tools DIR] [--only ID]\n' >&2
  exit 2
}

# ----------------------------------------------------------------- arguments
root=
tools=
only=
while [ $# -gt 0 ]; do
  case $1 in
    --root) [ $# -ge 2 ] || usage_error "--root needs a directory"; root=$2; shift 2;;
    --tools) [ $# -ge 2 ] || usage_error "--tools needs a directory"; tools=$2; shift 2;;
    --only) [ $# -ge 2 ] || usage_error "--only needs a note id"; only=$2; shift 2;;
    *) usage_error "unknown argument: $1";;
  esac
done

if [ -z "$root" ]; then
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root=
  [ -n "$root" ] || root=$(pwd)
fi
root_in=$root
root=$(CDPATH= cd -- "$root_in" 2>/dev/null && pwd -P) || usage_error "--root is not a directory: $root_in"

if [ -z "$tools" ]; then
  tools=$here
else
  case $tools in
    /*) :;;
    *) tools=$(CDPATH= cd -- "$tools" 2>/dev/null && pwd) || usage_error "--tools is not a directory: $tools";;
  esac
fi

ndir=$root/$UL_NOTES_DIR

# --------------------------------------------------------- enumerate the notes
f_list=$(ul_mktemp) || exit 1
rels=
if [ -d "$ndir" ]; then
  for d in "$ndir"/*/; do
    [ -d "$d" ] || continue
    d=${d%/}
    if [ ! -r "$d" ] || [ ! -x "$d" ]; then
      # an unreadable folder of notes is an error, never notes=none: a folder of
      # safety notes that cannot be listed must not read as "nothing to check"
      printf 'error the release folder %s cannot be read, so its notes cannot be checked\n' "${d#"$root"/}" >&2
      exit 1
    fi
    rels="$rels${d##*/}$nl"
  done
fi
total=0
if [ -n "$rels" ]; then
  rels_sorted=$(printf '%s' "$rels" | sort -t. -k1,1n -k2,2n -k3,3n)
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    for f in "$ndir/$rel"/*.md; do
      [ -f "$f" ] || continue
      b=${f##*/}
      [ "$b" = README.md ] && continue
      printf '%s|%s\n' "${b%.md}" "$f" >> "$f_list"
      total=$((total + 1))
    done
  done <<EOF
$rels_sorted
EOF
fi

if [ "$total" -eq 0 ]; then
  printf 'notes=none\n'
  exit 0
fi

mode=$(ul_copy_mode "$root")
printf 'mode=%s\n' "$mode"

failed=0
hints=
REPO_ROOT=$root
UPDATE_TOOLS=$tools
export REPO_ROOT UPDATE_TOOLS

# ----------------------------------------------------------------- the linter
if [ -z "$only" ]; then
  if [ -f "$here/updates-lint.sh" ]; then
    lint_flags=
    [ "$mode" = copy ] && lint_flags=--no-tree-rules
    lint_out=$(sh "$here/updates-lint.sh" --root "$root" $lint_flags 2>&1 </dev/null)
    lint_rc=$?
    if [ "$lint_rc" -eq 0 ]; then
      printf 'PASS updates-lint\n'
    else
      failed=$((failed + 1))
      printf 'FAIL updates-lint\n'
    fi
    # the linter's findings (its own notes= summary line is left out, so the last line
    # of this run is the only line that starts with notes=)
    printf '%s\n' "$lint_out" | grep -E '^(problem|warn) ' || true
    if [ "$lint_rc" -ne 0 ] && ! printf '%s\n' "$lint_out" | grep -q '^problem '; then
      printf '  the linter failed to run: %s\n' "$lint_out"
    fi
  else
    failed=$((failed + 1))
    printf 'FAIL updates-lint\n'
    printf '  updates-lint.sh is missing beside the checks runner, and notes exist\n'
  fi
fi

# ----------------------------------------------------------- every note's check
ran=0
while IFS='|' read -r n_fid n_abs <&3; do
  fm=$(ul_frontmatter "$n_abs")
  id=
  safety_raw=
  check=
  if [ "$fm" != NOFRONT ]; then
    id=$(ul_strip_quotes "$(ul_fm_scalar "$fm" id)")
    safety_raw=$(ul_strip_quotes "$(ul_fm_scalar "$fm" safety)")
    check=$(ul_strip_quotes "$(ul_fm_scalar "$fm" check)")
  fi
  [ -n "$id" ] || id=$n_fid
  if [ -n "$only" ] && [ "$only" != "$id" ] && [ "$only" != "$n_fid" ]; then
    continue
  fi
  ran=$((ran + 1))

  malformed=0
  case $safety_raw in
    true) is_safety=1;;
    false) is_safety=0;;
    *) is_safety=1; malformed=1;;
  esac

  if [ "$malformed" = 1 ]; then
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$id"
    printf '  the safety value is not true or false, so the note is treated as a safety note and fails\n'
    continue
  fi

  if [ -z "$check" ] || [ "$check" = none ]; then
    if [ "$is_safety" = 1 ]; then
      failed=$((failed + 1))
      printf 'FAIL %s\n' "$id"
      printf '  a safety note names no check file\n'
      hints="${hints}hint=The update $id is a safety fix with nothing to prove it landed. Take the update so its check comes back.$nl"
    else
      printf 'PASS %s\n' "$id"
    fi
    continue
  fi

  case $check in
    */*) checkpath=/nonexistent/$check;;
    *) checkpath=${n_abs%/*}/$check;;
  esac
  if [ ! -f "$checkpath" ] || [ ! -r "$checkpath" ]; then
    if [ "$is_safety" = 0 ] && [ "$mode" = copy ]; then
      printf 'WARN %s\n' "$id"
      printf '  the check file %s is missing or unreadable\n' "$check"
    else
      failed=$((failed + 1))
      printf 'FAIL %s\n' "$id"
      printf '  the check file %s is missing or unreadable\n' "$check"
      if [ "$is_safety" = 1 ]; then
        hints="${hints}hint=The update $id is a safety fix and its check file is missing. Take the update so the check comes back.$nl"
      fi
    fi
    continue
  fi

  out=$( (cd "$root" && sh "$checkpath") 2>/dev/null </dev/null )
  rc=$?
  last=${out##*"$nl"}
  if [ "$rc" -eq 0 ]; then
    case $last in
      skip=*) printf 'SKIP %s %s\n' "$id" "${last#skip=}";;
      *) printf 'PASS %s\n' "$id";;
    esac
  elif [ "$is_safety" = 0 ] && [ "$mode" = copy ]; then
    printf 'WARN %s\n' "$id"
    case $last in hint=*) printf '  %s\n' "${last#hint=}";; esac
  else
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$id"
    printf '  the check exited %s\n' "$rc"
    case $last in hint=*) hints="$hints$last$nl";; esac
  fi
done 3< "$f_list"

if [ -n "$only" ] && [ "$ran" -eq 0 ]; then
  failed=$((failed + 1))
  printf 'FAIL %s\n' "$only"
  printf '  no note with that id\n'
fi

# -------------------------------------------------------------------- summary
if [ "$failed" -gt 0 ] && [ -n "$hints" ]; then
  printf '%s' "$hints"
fi
if [ "$failed" -eq 0 ]; then
  printf 'notes=%s ok\n' "$ran"
  exit 0
fi
printf 'notes=%s failed=%s\n' "$ran" "$failed"
exit 1
