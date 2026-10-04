#!/bin/sh
# update-loom-common.sh -- the shared POSIX library of the /update-loom engine family.
#
# SOURCED, never executed: the engine, the linter, the checks runner and the
# invariants script each do `here=<dir holding this file>; . "$here/update-loom-common.sh"`.
# Set `here` (or UL_COMMON_DIR) before sourcing: a sourced file cannot learn its own
# location in POSIX sh, and UL_TOOLS below defaults to that directory.
# Language rule for the whole family: POSIX sh + awk only (no arrays, no [[ ]], no
# `local`, no $'..', no ${var//}, no `function` keyword, no here-strings). Invoke
# sibling scripts as `sh <path>`, never rely on the exec bit.
#
# ======================================================================================
# THE BINDING PHASE 0 CONTRACT (state layout, TSV columns, vocabularies). Later workers
# read this header; change it only together with every file that implements it.
# ======================================================================================
#
# STATE = $(git rev-parse --absolute-git-dir)/loom/update
# Rebuilt by --plan (rm -rf, then recreate): plan.tsv, meta, notes.tsv, groups.tsv, notes/<id>.md, notes/<id>.check.sh, adapt.tsv, adapt/base|theirs|mine/<path>, adapt/out/ (the skill writes adapter output here), merged/<path>, adapted.tsv, diffs/<path>.base-upstream.diff and <path>.base-local.diff, reviewer/<path>.log, export/ (read-only `git archive HEAD` export; chmod -R u+w before any rm), tools/json-valid.sh and tools/json-flat.sh (UPSTREAM's copies saved at plan time), unresolved/<path>.lost.diff, transaction.txt, checks.log.
# Persist across plans: mine/<update-id>/<path> (customer's file backed up before a take-theirs/apply on a held row), stage.lock (pid), wt/ (detached throwaway worktree), staged (one line: the staged commit sha), last-smoke.log.
# Tracked in the repo, never in STATE: .logic-loom/memory/update-ledger.tsv (ledger), .logic-loom/memory/updates/<update-id>.applied (applied record), .sdd-sync-ref (base pointer). All three are written by --stage INTO THE WORKTREE so they travel inside the update commit.
# meta lines: base=<sha>, base_rung=<handover|recorded|remap|closest|set>, upstream=<sha>, head=<sha>, channel=<template|adopted|ambiguous>, update_id=<YYYYMMDDTHHMMSSZ>-<upstream sha12>, time=<ISO-8601 UTC>.
# Tag written by --stage: loom/pre-update-<YYYYMMDD-HHMMSS> (same shape the 6.x skill used; the handover base rung searches this glob). Commit subject: `LogicLoom update to <upstream sha12>`.
# plan.tsv: path TAB class TAB proposed TAB detail. class in take|delete|add|add-conflict|keep|deleted-upstream-kept|posture|conflict|merged-clean|mode|two-way|adopter-owned|excluded; proposed in apply|hold|keep|skip. Unchanged paths produce no row.
# notes.tsv: id TAB notes/<id>.md TAB safety(true|false) TAB touches(comma-joined paths, channel suffix stripped) TAB blocked(-|<blocker id>) TAB declined-before(yes|no) TAB group(gN) TAB untouched(yes|no) TAB project-data(true|false) TAB check(<file name>|none) TAB offer(a|b|c).
# groups.tsv: gN TAB id,id,...  The pseudo-id _unnoted names the group of plan rows no note covers (only when such rows exist).
# adapt.tsv: path TAB note-ids(comma-joined or -) TAB base(sha or -) TAB theirs(sha or -) TAB mine(sha or -). A two-way row has base -.
# adapted.tsv: path TAB note-ids (written by --adapt-save).
# decisions.tsv (written by the skill, read by --stage): path rows `<path> TAB <apply|take-theirs|keep-mine|hold|adapted>[ TAB informed=yes ]`; note rows `note:<id> TAB <apply|acknowledge|decline|decline-final>`; `note:_unnoted TAB apply|decline`. Any other value is refused before anything is touched.
# Ledger row: id TAB outcome TAB note-blob(sha of the note .md at upstream) TAB upstream-sha TAB date; outcome in applied|acknowledged|declined|declined-final|held; lines starting # are ignored; no header.
# .applied record: header lines update_id=, tag=, parent=(HEAD before the update), base=, upstream=, channel=, date=; then one line per touched path: path TAB blob_after(sha|-) TAB mode_after(100644|100755|-) TAB blob_before(sha|-) TAB mode_before(100644|100755|-).
# Engine stdout: key=value lines; a refusal prints `result=aborted reason=<sentence> unchanged=yes` and exits 1; an unexpected error prints `error <sentence>` and exits 1.
# Check contract: `sh <check>` with REPO_ROOT (the tree under test) and UPDATE_TOOLS (a dir holding json-valid.sh and json-flat.sh) exported, cwd = REPO_ROOT. exit 0 = purpose holds; exit 0 with last stdout line `skip=<reason>` = not applicable in this copy; non-zero with last line `hint=<one plain sentence>` = fails. A check must read JSON via `sh "${UPDATE_TOOLS:-$REPO_ROOT/plugins/loom-maintenance/scripts}/json-flat.sh"`, write nothing outside $TMPDIR, run no git except show|ls-tree|cat-file|rev-parse, no curl|wget|nc|ssh, no eval, no rm -r.
#
# ======================================================================================
# Exported names (all prefixed ul_ / UL_). Path functions are LEXICAL: they strip a
# leading ./ and a trailing / and compare text; resolving `..`, absolute paths and
# symlinks is the engine's write_path job, never this library's. The token loops are
# IFS-independent: each saves the caller's IFS, splits on space/tab/newline, and puts
# the caller's IFS back (set, empty or unset) before returning, so an engine that reads
# TSV with a global IFS cannot silently empty a protected set.
# ======================================================================================
#   UL_NOTES_DIR UL_SCRIPTS_DIR UL_BUNDLE UL_LEDGER UL_APPLIED_DIR UL_SYNC_REF
#   UL_UPSTREAM_REF UL_UPSTREAM_CONF UL_CHANNEL_MAP UL_DEFAULT_UPSTREAM_URL
#   UL_PROTECTED_TOKENS  ul_path_protected PATH      (the FLOOR tokens of .logic-loom/lib/
#                                                     governance-verdicts.sh only; a fork's
#                                                     governance.conf protected_paths additions
#                                                     and a renamed framework dir are NOT consulted)
#   UL_POSTURE_FILES     ul_path_posture PATH
#   UL_SECURITY_SURFACE  ul_path_security_surface PATH
#   UL_FORBIDDEN_TREES   ul_path_forbidden PATH      (the forbidden-touch set)
#   ul_project_data_allowed PATH                     (the project-data allowlist)
#   ul_frontmatter FILE | ul_fm_scalar FM KEY | ul_fm_list FM KEY | ul_fm_has FM KEY | ul_strip_quotes VALUE
#   ul_touch_split ROW                               (prints `path TAB channel`)
#   UL_COPY_MARKERS      ul_copy_mode ROOT           (template-repo | copy)
#   ul_install_traps | ul_mktemp [suffix] | ul_cleanup
#                        (call ul_install_traps ONCE right after sourcing: it sets `trap
#                         ul_cleanup EXIT` and turns INT/TERM into exits so that trap runs.
#                         Never `trap ul_cleanup INT`: a trapped signal does not end a
#                         non-interactive shell, so that form deletes the temps and then
#                         carries on. A consumer that needs its own EXIT trap writes one that
#                         calls ul_cleanup itself. Call `x=$(ul_mktemp) || exit 1`, because an
#                         exit inside $(...) ends only that subshell.)
#   ul_sha256 FILE | ul_norm_hash < stdin
#   UL_TOOLS | ul_json_valid FILE | ul_json_flat FILE

case $0 in
  *update-loom-common.sh) echo 'error this file is sourced, not run' >&2; exit 2;;
esac

set -u

# --------------------------------------------------------------------- locations
UL_NOTES_DIR=plugins/loom-maintenance/updates
UL_SCRIPTS_DIR=plugins/loom-maintenance/scripts
UL_BUNDLE=$UL_NOTES_DIR/BUNDLE.sha256
UL_LEDGER=.logic-loom/memory/update-ledger.tsv
UL_APPLIED_DIR=.logic-loom/memory/updates
UL_SYNC_REF=.sdd-sync-ref
UL_UPSTREAM_REF=refs/loom-upstream/main
UL_UPSTREAM_CONF=.logic-loom/config/framework-upstream.conf
UL_CHANNEL_MAP=.logic-loom/config/update-channels.conf
UL_DEFAULT_UPSTREAM_URL=https://github.com/kelleysd-apps/LogicLoom.git

# Where this file lives: UL_COMMON_DIR, else the caller's `here`, else the
# directory of the script that sourced it, else the shipped relative path.
ul__dir=
if [ -n "${UL_COMMON_DIR:-}" ]; then
  ul__dir=$UL_COMMON_DIR
elif [ -n "${here:-}" ] && [ -f "$here/update-loom-common.sh" ]; then
  ul__dir=$here
else
  ul__d=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)
  if [ -n "$ul__d" ] && [ -f "$ul__d/update-loom-common.sh" ]; then ul__dir=$ul__d; fi
fi
[ -n "$ul__dir" ] || ul__dir=$UL_SCRIPTS_DIR
UL_COMMON_DIR=$ul__dir
# Directory holding json-valid.sh / json-flat.sh: a non-empty UPDATE_TOOLS wins.
UL_TOOLS=${UPDATE_TOOLS:-$UL_COMMON_DIR}

# ------------------------------------------------------------------ temp registry
# Every call site runs ul_mktemp inside $(...), a subshell, where a shell VARIABLE
# assignment never escapes; so the registry is a FILE (filesystem I/O persists past
# the subshell). Created at source time, under TMPDIR, failing closed.
UL_TMP_REGISTRY=$(mktemp "${TMPDIR:-/tmp}/ul-registry.XXXXXX") || {
  echo "error could not create a temp registry under ${TMPDIR:-/tmp}" >&2
  exit 1
}

ul_mktemp() { # [suffix] -> prints the new temp file's path
  ul_mt_f=$(mktemp "${TMPDIR:-/tmp}/ul-update.XXXXXX") || {
    echo "error could not create a temp file under ${TMPDIR:-/tmp}" >&2
    exit 1
  }
  printf '%s\n' "$ul_mt_f" >> "$UL_TMP_REGISTRY"
  if [ -n "${1:-}" ]; then
    ul_mt_g=$ul_mt_f$1
    mv "$ul_mt_f" "$ul_mt_g" || {
      echo "error could not create a temp file under ${TMPDIR:-/tmp}" >&2
      exit 1
    }
    printf '%s\n' "$ul_mt_g" >> "$UL_TMP_REGISTRY"
    ul_mt_f=$ul_mt_g
  fi
  printf '%s' "$ul_mt_f"
}

ul_cleanup() {
  [ -f "$UL_TMP_REGISTRY" ] || return 0
  while IFS= read -r ul_ct_f; do
    [ -n "$ul_ct_f" ] && rm -f "$ul_ct_f"
  done < "$UL_TMP_REGISTRY"
  rm -f "$UL_TMP_REGISTRY"
  return 0
}

# The traps a consumer installs once, right after sourcing. INT and TERM become
# exits so the EXIT trap runs and the script STOPS; a trapped signal on its own
# does not end a non-interactive shell (it runs the trap, then continues with
# the next command -- with the temps already gone). 130/143 = 128 + signal.
ul_install_traps() {
  trap ul_cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
}

# ------------------------------------------------------------- IFS save/restore
# The token sets below are whitespace-separated strings walked with `for`, which
# splits on IFS. Each walker saves the caller's IFS, uses the default separators
# and restores exactly what it found (set, empty or unset). One slot; the
# walkers never call one another, so it is never nested.
ul__tab=$(printf '\t')
ul__nl='
'
UL_IFS=" $ul__tab$ul__nl"
ul__ifs_save() {
  if [ "${IFS+set}" = set ]; then ul__ifs_had=1; ul__ifs_old=$IFS; else ul__ifs_had=0; ul__ifs_old=; fi
  IFS=$UL_IFS
}
ul__ifs_restore() {
  if [ "$ul__ifs_had" = 1 ]; then IFS=$ul__ifs_old; else unset IFS; fi
}

# ------------------------------------------------------------------ path classes
# Sets UL_P to the argument without leading ./ and trailing /.
ul__np() {
  UL_P=${1:-}
  while :; do
    case $UL_P in ./*) UL_P=${UL_P#./};; *) break;; esac
  done
  while :; do
    case $UL_P in ?*/) UL_P=${UL_P%/};; *) break;; esac
  done
}

# The governance surface, as path tokens. Mirrors loom_protected_path_tokens in
# .logic-loom/lib/governance-verdicts.sh (the cases suite compares them).
UL_PROTECTED_TOKENS='.claude/hooks .claude/settings.json .claude/settings.local.json .logic-loom/config/governance.conf .logic-loom/config/gate-policy.conf .logic-loom/memory/constitution.md .logic-loom/lib/governance-verdicts.sh .logic-loom/lib/policy.sh plugins/loom-governance/hooks plugins/loom-governance/.claude-plugin/plugin.json'
UL_POSTURE_FILES='.logic-loom/config/gate-policy.conf .logic-loom/config/governance.conf .logic-loom/config/project.conf .logic-loom/config/environments.conf'
UL_SECURITY_SURFACE='.claude/settings.json .claude/policies/tool-restrictions.json .logic-loom/config/gate-policy.conf .logic-loom/config/governance.conf'
UL_FORBIDDEN_TREES='web apps .brain features specs'

ul_path_protected() { # PATH -> 0 when PATH is a token or sits under a token directory
  ul__np "$1"
  ul_pp_r=1
  ul__ifs_save
  for ul_pp_t in $UL_PROTECTED_TOKENS; do
    if [ "$UL_P" = "$ul_pp_t" ]; then ul_pp_r=0; break; fi
    case $UL_P in "$ul_pp_t"/*) ul_pp_r=0; break;; esac
  done
  ul__ifs_restore
  return $ul_pp_r
}

ul_path_posture() { # PATH
  ul__np "$1"
  ul_pp_r=1
  ul__ifs_save
  for ul_pp_t in $UL_POSTURE_FILES; do
    if [ "$UL_P" = "$ul_pp_t" ]; then ul_pp_r=0; break; fi
  done
  ul__ifs_restore
  return $ul_pp_r
}

ul_path_security_surface() { # PATH
  ul__np "$1"
  ul_pp_r=1
  ul__ifs_save
  for ul_pp_t in $UL_SECURITY_SURFACE; do
    if [ "$UL_P" = "$ul_pp_t" ]; then ul_pp_r=0; break; fi
  done
  ul__ifs_restore
  return $ul_pp_r
}

# The forbidden-touch set: product code, the project's own plans and knowledge,
# and the engine's own records. Under features/ and specs/ exactly README.md
# and .gitkeep ship (payload-manifest.txt include: rows), so those four and
# .brain/README.md stay touchable; every other path under those trees is the
# customer's own -- the subdirectories AND any other direct child.
ul_path_forbidden() { # PATH
  ul__np "$1"
  case $UL_P in
    web|web/*|apps|apps/*|node_modules|node_modules/*) return 0;;
    .brain/README.md) return 1;;
    .brain|.brain/*) return 0;;
    features/README.md|features/.gitkeep|specs/README.md|specs/.gitkeep) return 1;;
    features|features/*|specs|specs/*) return 0;;
    "$UL_LEDGER") return 0;;
    "$UL_APPLIED_DIR"/*) return 0;;
  esac
  return 1
}

# Fork-authored files LogicLoom never ships: the only files a project-data note
# may touch. gate-policy, project and environments config SHIP, so they are
# posture files, not project data. A shipped logicloom-*.md rule is denied
# wherever it sits under .claude/rules/ (the test is the file's own name).
ul_project_data_allowed() { # PATH
  ul__np "$1"
  case $UL_P in
    .logic-loom/memory/amendments.md) return 0;;
    .claude/rules/*.md)
      case ${UL_P##*/} in logicloom-*) return 1;; esac
      return 0;;
  esac
  return 1
}

# ------------------------------------------------------------------ frontmatter
# The text between the first two --- lines, CRLF-insensitive; the single line
# NOFRONT when the file has no frontmatter.
ul_frontmatter() { # FILE
  awk '
    { sub(/\r$/, "") }
    NR == 1 && $0 !~ /^---[ \t]*$/ { print "NOFRONT"; exit }
    NR == 1 { next }
    /^---[ \t]*$/ { exit }
    { print }
  ' "$1"
}

# One single-line key's value, trimmed. Empty when absent (ul_fm_has tells the
# empty-but-present case apart).
ul_fm_scalar() { # FM KEY
  printf '%s\n' "$1" | awk -v k="$2" '
    $0 ~ "^" k ":" {
      line = $0
      sub("^" k ":", "", line)
      sub(/^[ \t]+/, "", line)
      sub(/[ \t]+$/, "", line)
      print line
      exit
    }
  '
}

# A list key's items, one per line, a wrapping pair of double quotes stripped.
# Nothing for `key: []` or a missing key. The items are the indented `  - item`
# lines straight after the key.
ul_fm_list() { # FM KEY
  printf '%s\n' "$1" | awk -v k="$2" '
    BEGIN { inlist = 0 }
    inlist && /^[ \t]+-[ \t]/ {
      line = $0
      sub(/^[ \t]+-[ \t]*/, "", line)
      sub(/[ \t]+$/, "", line)
      print line
      next
    }
    inlist { inlist = 0 }
    $0 ~ "^" k ":" {
      rest = $0
      sub("^" k ":", "", rest)
      sub(/^[ \t]+/, "", rest)
      sub(/[ \t]+$/, "", rest)
      if (rest == "") { inlist = 1 }
      next
    }
  ' | sed -e 's/^"\(.*\)"$/\1/'
}

ul_fm_has() { # FM KEY
  printf '%s\n' "$1" | grep -q "^$2:"
}

# One wrapping pair of matching quotes (double or single) removed.
ul_strip_quotes() { # VALUE
  printf '%s' "$1" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\\(.*\\)'\$/\\1/"
}

# A touches/adds/removes row -> `path TAB channel`; channel is the trailing
# @template|@adopted|@both token, or @both when there is none.
ul_touch_split() { # ROW
  printf '%s\n' "$1" | awk '
    {
      sub(/^[ \t]+/, "")
      sub(/[ \t]+$/, "")
      ch = "@both"
      path = $0
      n = split($0, a, /[ \t]+/)
      if (n >= 2 && a[n] ~ /^@(template|adopted|both)$/) {
        ch = a[n]
        path = substr($0, 1, length($0) - length(a[n]))
        sub(/[ \t]+$/, "", path)
      }
      printf "%s\t%s\n", path, ch
    }
  '
}

# ------------------------------------------------------------------- copy mode
# The five maintainer-only markers: every one is REMOVED wholesale by the
# template strip, so a customer copy lacks them. THE SAME FIVE as
# LOOM_TREE_PROVENANCE_MARKERS in tests/lib/tree-provenance.sh. tests/ is not
# shipped, so this engine carries its own list; tests/update-loom/cases-common.sh
# asserts the two are identical.
UL_COPY_MARKERS='.logic-loom/scripts/bash/template-strip-manifest.txt
.logic-loom/scripts/bash/leak-guard.sh
.logic-loom/scripts/bash/strip-harness-dev.sh
.logic-loom/scripts/bash/history-scrub-rules.json
plugins/loom-maintenance/commands/promote.md'

# template-repo only when ALL five exist; anything else (none, or a mix) is a
# customer copy -- the safe direction.
ul_copy_mode() { # ROOT
  ul_cm_root=${1:-.}
  ul_cm_r=template-repo
  ul__ifs_save
  for ul_cm_m in $UL_COPY_MARKERS; do
    [ -f "$ul_cm_root/$ul_cm_m" ] || { ul_cm_r=copy; break; }
  done
  ul__ifs_restore
  printf '%s\n' "$ul_cm_r"
}

# ---------------------------------------------------------------------- hashing
ul_sha256() { # FILE -> hex digest; returns 1, printing nothing, when no tool can
  [ -f "${1:-}" ] || return 1
  if command -v sha256sum >/dev/null 2>&1; then
    if ul_h=$(sha256sum "$1" 2>/dev/null) && [ -n "$ul_h" ]; then
      printf '%s\n' "${ul_h%% *}"; return 0
    fi
  fi
  if command -v shasum >/dev/null 2>&1; then
    if ul_h=$(shasum -a 256 "$1" 2>/dev/null) && [ -n "$ul_h" ]; then
      printf '%s\n' "${ul_h%% *}"; return 0
    fi
  fi
  if command -v openssl >/dev/null 2>&1; then
    if ul_h=$(openssl dgst -sha256 "$1" 2>/dev/null) && [ -n "$ul_h" ]; then
      printf '%s\n' "${ul_h##* }"; return 0
    fi
  fi
  return 1
}

# CRLF-insensitive content fingerprint of stdin: `<cksum>-<size>`.
ul_norm_hash() {
  tr -d '\r' | cksum | awk '{ print $1 "-" $2 }'
}

# ------------------------------------------------------------------- json tools
ul_json_valid() { # FILE -> json-valid.sh's own output and exit status
  sh "$UL_TOOLS/json-valid.sh" "$1"
}

ul_json_flat() { # FILE -> path TAB value per leaf
  sh "$UL_TOOLS/json-flat.sh" "$1"
}
