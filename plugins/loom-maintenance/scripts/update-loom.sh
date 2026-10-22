#!/bin/sh
# update-loom.sh -- the /update-loom engine: a deterministic, POSIX sh + awk
# program that does every file and git step of a LogicLoom update, so the skill
# (the only thing that talks to the user) never has to improvise one.
#
# This file holds the skeleton and the subcommands that need no plan:
#   --status            channel, upstream, base, tree state, bundle, engine (read-only,
#                       apart from the fetch into refs/loom-upstream/main and healing
#                       a crashed stage's leftovers). clean=no carries a clean_error=
#                       line when git status itself failed, so the skill does not ask
#                       the customer to commit changes that are not there.
#   --detect-base       which upstream commit this copy was last updated from
#   --set-base <sha>    record that commit in .sdd-sync-ref (one commit, that file only)
#   --bootstrap-copy    copy upstream's engine into <gitdir>/loom/bootstrap/ and print
#                       where, so a stale local engine can be replaced for one update
# plus the internal helpers the later subcommands call: write_path, lock_acquire /
# lock_release / heal_stale, channel detection, the channel map reader, the trust
# root (upstream_url) and fetch_upstream.
# --stage and --abandon are built (see the section above cmd_stage); so are --finish
# (post-landing smoke, automatic content-verified revert) and --undo (reverse one recorded
# update from any clone), in the section above cmd_selftest_tree_gate.
# --plan is built (cmd_plan: classify, then the notes layer: offered notes, checks,
# groups, two-way rows, transaction.txt). --adapt-save and --mark-unresolved are built
# (cmd_adapt_save, cmd_mark_unresolved): the gate between the read-only adapter and the
# tree. Neither runs git beyond read-only plumbing, and both write only under the state
# directory (merged/, adapted.tsv, unresolved/, unresolved.tsv).
# TEST-ONLY subcommands (no skill or command uses them; the cases do, so every
# helper has an assertion that fails without it):
#   --selftest-write-path WT PATH SRC MODE   write_path
#   --selftest-lock [SECONDS]                lock_acquire, hold, exit-trap release
#   --selftest-channel                       the resolved channel, notice and groups
#   --selftest-map dump [--builtin]          the parsed channel map
#   --selftest-map path PATH                 group / excluded / merge / rename of PATH
#   --selftest-remap SHA                     the known-bad stamp table
#   --selftest-two-way PATH                  write_two_way_row against the last plan
#   --selftest-tree-gate WT                  the protected-tree equality gate on a worktree
#   --selftest-allowlist WT DECISIONS        the staged-path allowlist on a worktree's HEAD commit
#
# Global options (accepted before or after the subcommand):
#   --upstream-url <url>           refused unless --i-am-pointing-at-a-fork is also given
#   --i-am-pointing-at-a-fork
#   --revisit                      --plan only: a declined note whose check still fails is
#                                  listed as snoozed=no even if its text did not change
#   --channel template|adopted     settles an ambiguous detection; refused when the
#                                  detection is unambiguous and disagrees
#
# Contract: stdout is key=value lines (or one verdict line first); an unexpected
# problem prints `error <sentence>` and exits 1; usage errors exit 2. stdin is never
# read. The shared state layout, TSV columns and vocabularies are the header of
# update-loom-common.sh, which this file sources. Language rule: POSIX sh + awk only.

set -u
exec </dev/null

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 1
if [ ! -f "$here/update-loom-common.sh" ]; then
  echo "error update-loom-common.sh is missing next to this script"
  exit 1
fi
. "$here/update-loom-common.sh"
ul_install_traps

LOCK_HELD=0
lock_release() { # drop stage.lock if THIS process holds it
  if [ "$LOCK_HELD" = 1 ]; then
    rm -f "$state/stage.lock"
    LOCK_HELD=0
  fi
  return 0
}
ul_exit() { # the EXIT trap: restore check-time permissions, release a held lock, then the shared temp cleanup
  cg_unlock
  lock_release
  ul_cleanup
}
trap ul_exit EXIT

usage() {
  cat <<'ULUSAGEEOF'
Usage: update-loom.sh [--upstream-url URL --i-am-pointing-at-a-fork] [--channel template|adopted] [--revisit] <subcommand>

  --status              channel, upstream, base, tree state, bundle and engine status
  --detect-base         which upstream commit this copy was last updated from
  --set-base <sha>      record that commit in .sdd-sync-ref
  --bootstrap-copy      copy upstream's engine into <gitdir>/loom/bootstrap/
  --plan                classify every path, then offer notes and run their checks
  --adapt-save <path> <bodyfile> <note-ids>
                        validate an adapted file (R1-R5) and save it under the state
  --mark-unresolved <path> <note-id>
                        a safety note's file could not be adapted: record what would be lost
  --stage <decisions.tsv>
                        build the update commit in a detached worktree (never touches your tree)
  --abandon             drop a staged update: remove the worktree, keep the tag
  --finish              after you landed the staged commit: smoke the live tree, revert on failure
  --undo [<update-id>]  reverse one recorded update (default: the newest) from any clone
  --help                this text
ULUSAGEEOF
}

# ------------------------------------------------------ global option scan
OPT_URL=
OPT_CHANNEL=
OPT_FORK=0
OPT_REVISIT=0
ul_n=$#
while [ "$ul_n" -gt 0 ]; do
  ul_a=$1; shift; ul_n=$((ul_n - 1))
  case $ul_a in
    --upstream-url|--channel)
      if [ "$ul_n" -lt 1 ]; then
        echo "error $ul_a needs a value"
        exit 2
      fi
      ul_v=$1; shift; ul_n=$((ul_n - 1))
      if [ "$ul_a" = --upstream-url ]; then OPT_URL=$ul_v; else OPT_CHANNEL=$ul_v; fi;;
    --i-am-pointing-at-a-fork) OPT_FORK=1;;
    --revisit) OPT_REVISIT=1;;
    *) set -- "$@" "$ul_a";;
  esac
done

cmd=${1:-}
[ "$#" -gt 0 ] && shift

case $cmd in
  --help|-h) usage; exit 0;;
  --status|--detect-base|--set-base|--bootstrap-copy|--plan|--adapt-save|--mark-unresolved|--stage|--abandon|--finish|--undo) ;;
  --selftest-write-path|--selftest-lock|--selftest-channel|--selftest-map|--selftest-remap|--selftest-two-way|--selftest-tree-gate|--selftest-allowlist) ;;
  *) usage >&2; exit 2;;
esac

if [ -n "$OPT_URL" ] && [ "$OPT_FORK" != 1 ]; then
  echo "error --upstream-url needs --i-am-pointing-at-a-fork"
  exit 1
fi
case $OPT_CHANNEL in
  ''|template|adopted) ;;
  *) echo "error --channel must be template or adopted"; exit 2;;
esac

# ---------------------------------------------------------------- location
root=$(git rev-parse --show-toplevel 2>/dev/null) || root=
if [ -z "$root" ]; then
  echo "error not inside a git repository"
  exit 1
fi
gd=$(git -C "$root" rev-parse --absolute-git-dir 2>/dev/null) || gd=
if [ -z "$gd" ]; then
  echo "error could not find the git directory"
  exit 1
fi
state=$gd/loom/update

# ----------------------------------------------------------------- git helpers
blob_sha() { # COMMIT PATH -> the blob sha, nothing when the path is absent
  git -C "$root" rev-parse -q --verify "$1:$2" 2>/dev/null
}

norm_hash() { # COMMIT PATH -> CRLF-insensitive fingerprint, nothing when absent
  nh_s=$(blob_sha "$1" "$2") || return 0
  [ -n "$nh_s" ] || return 0
  git -C "$root" show "$1:$2" 2>/dev/null | ul_norm_hash
}

in_progress() { # 0 when a merge, rebase, cherry-pick or revert is unfinished
  for ip_m in MERGE_HEAD REBASE_HEAD CHERRY_PICK_HEAD REVERT_HEAD; do
    [ -e "$gd/$ip_m" ] && return 0
  done
  for ip_d in rebase-merge rebase-apply; do
    [ -d "$gd/$ip_d" ] && return 0
  done
  return 1
}

is_shallow() {
  [ "$(git -C "$root" rev-parse --is-shallow-repository 2>/dev/null)" = true ]
}

# ------------------------------------------------------------- the trust root
# Value of KEY from conf text on stdin: quotes and a trailing comment stripped.
conf_val() { # KEY
  awk -v key="$1" '
    { sub(/\r$/, ""); line = $0; sub(/^[ \t]+/, "", line) }
    index(line, key) == 1 {
      rest = substr(line, length(key) + 1)
      sub(/^[ \t]*/, "", rest)
      if (substr(rest, 1, 1) != "=") next
      rest = substr(rest, 2)
      sub(/^[ \t]*/, "", rest)
      c = substr(rest, 1, 1)
      if (c == "\"" || c == "\047") {
        rest = substr(rest, 2)
        e = index(rest, c)
        if (e > 0) rest = substr(rest, 1, e - 1)
      } else {
        sub(/[ \t]*#.*/, "", rest)
        sub(/[ \t]+$/, "", rest)
      }
      print rest
      exit
    }'
}

# The URL updates are pulled from. Read from the COMMITTED HEAD blob of the conf,
# never the working tree, and never from the environment: an edit nobody committed
# cannot repoint the updater. --upstream-url (with --i-am-pointing-at-a-fork) is the
# one override.
upstream_url() {
  if [ -n "$OPT_URL" ]; then
    printf '%s' "$OPT_URL"
    return 0
  fi
  uu_conf=$(git -C "$root" show "HEAD:$UL_UPSTREAM_CONF" 2>/dev/null) || uu_conf=
  uu_u=$(printf '%s\n' "$uu_conf" | conf_val LOOM_UPSTREAM_URL)
  if [ -z "$uu_u" ]; then
    uu_r=$(printf '%s\n' "$uu_conf" | conf_val LOOM_UPSTREAM_REPO)
    [ -n "$uu_r" ] && uu_u=https://github.com/$uu_r.git
  fi
  [ -n "$uu_u" ] || uu_u=$UL_DEFAULT_UPSTREAM_URL
  printf '%s' "$uu_u"
}

UPSTREAM_URL=$(upstream_url)
FETCHED=0
FETCH_ERROR=
FETCH_NOWRITE=

# Fetch-only into the namespaced ref: no remote is created, no tag is pulled, no
# branch moves. Submodule recursion is off: git's default (on-demand) reads the
# INDEX to look for gitlinks, so a corrupt index would fail the fetch and be
# reported as a network problem (is_clean is where an index problem is reported);
# and the harness has no submodules, so there is nothing for it to find in a
# customer's repo that does. Sets FETCHED=1 on success, FETCH_ERROR on failure.
fetch_upstream() {
  fu_url=$UPSTREAM_URL
  FETCH_ERROR="could not fetch upstream from $fu_url"
  case $fu_url in -*) return 1;; esac
  if [ -z "$FETCH_NOWRITE" ]; then
    if git fetch -h 2>&1 | grep -q -- '--no-write-fetch-head'; then
      FETCH_NOWRITE=--no-write-fetch-head
    else
      FETCH_NOWRITE=-
    fi
  fi
  if [ "$FETCH_NOWRITE" = - ]; then
    GIT_TERMINAL_PROMPT=0 git -C "$root" fetch -q --no-tags --no-recurse-submodules -- "$fu_url" "+refs/heads/main:$UL_UPSTREAM_REF" >/dev/null 2>&1 || return 1
  else
    GIT_TERMINAL_PROMPT=0 git -C "$root" fetch -q --no-tags --no-recurse-submodules "$FETCH_NOWRITE" -- "$fu_url" "+refs/heads/main:$UL_UPSTREAM_REF" >/dev/null 2>&1 || return 1
  fi
  FETCH_ERROR=
  FETCHED=1
  return 0
}

upstream_head() { # -> the fetched upstream commit, nothing when there is none
  git -C "$root" rev-parse -q --verify "$UL_UPSTREAM_REF^{commit}" 2>/dev/null
}

# ------------------------------------------------------------ the channel map
# update-channels.conf says which paths the harness owns. Preference: upstream's copy
# (it knows the newest layout), then HEAD's, then the built-in copy below, which equals
# the shipped file. A copy with no `harness` row is skipped as unusable: an empty map
# would make every untracked file look harmless.
ul_default_map() {
  cat <<'ULMAPEOF'
# Channel map for the update engine (plugins/loom-maintenance/scripts/update-loom.sh).
# It says which paths the harness owns, which an adopted install never receives,
# which are renamed on adoption and which are merged in place. Read by
# update-loom.sh from the upstream copy first, then from this file at HEAD, then
# from a built-in copy that equals this file.
#
# HAND-DERIVED in Phase 0 from packaging/adopt/payload-manifest.txt (the adopt
# installer payload manifest). From Phase 3 on this file is REGENERATED from that
# manifest at promote and a freshness gate fails when they differ. Do not hand
# edit it after that; edit the manifest.
#
# Grammar (one row per line; # starts a comment; blank lines are ignored):
#   manifest-version = <n>
#   harness = <path> :: <group>      a harness-owned path: a directory prefix or one
#                                    file. <group> is the adopt payload group an
#                                    adopted install records in its receipt, so a
#                                    path whose group is not installed there is
#                                    adopter-owned. .claude/hooks is group hooks,
#                                    everything else is group harness.
#   adopt-exclude = <pattern>        never installed into an adopted repo. A plain
#                                    path matches itself and everything under it. A
#                                    trailing / matches only what is under it. A
#                                    pattern may use shell * wildcards, which also
#                                    cross / (features/*/ is every sub-directory of
#                                    features/, not features/README.md).
#   rename = <upstream path> :: <adopted path>
#   merge = <path>                   changed in place in an adopted repo, so it is
#                                    always held when both sides changed.
manifest-version = 1

harness = .logic-loom :: harness
harness = plugins :: harness
harness = .claude/hooks :: hooks
harness = .claude/commands :: harness
harness = .claude/context :: harness
harness = .claude/agents :: harness
harness = .claude/policies :: harness
harness = .claude/schemas :: harness
harness = .sdd-sync-ref :: harness
harness = .brain/README.md :: harness
harness = features/.gitkeep :: harness
harness = features/README.md :: harness
harness = specs/.gitkeep :: harness
harness = specs/README.md :: harness
harness = artifacts/.gitkeep :: harness
harness = artifacts/README.md :: harness
harness = .docs/policies :: harness
harness = .docs/architecture :: harness
harness = .docs/guides :: harness
harness = .docs/references :: harness
harness = .docs/agents/agent-registry.json :: harness
harness = .docs/agents/shared/task-handoffs :: harness

adopt-exclude = .logic-loom/scripts/bash/update-agent-context.sh
adopt-exclude = .logic-loom/tests
adopt-exclude = .logic-loom/graph
adopt-exclude = .claude/statusline.sh
adopt-exclude = features/*/
adopt-exclude = specs/*/
adopt-exclude = artifacts/backlog-dashboard.html
adopt-exclude = artifacts/harness-graph.html
adopt-exclude = artifacts/logicloom-vision.html
adopt-exclude = .docs/guides/dev-main-template-split.md
adopt-exclude = .docs/guides/adopt-smoke-test.md
adopt-exclude = .docs/agents/*/*/decisions
adopt-exclude = .docs/history
adopt-exclude = .docs/reviews
adopt-exclude = CLAUDE.md
adopt-exclude = .github
adopt-exclude = tests
adopt-exclude = package.json
adopt-exclude = package-lock.json
adopt-exclude = README.md
adopt-exclude = START_HERE.md
adopt-exclude = TEMPLATE_INIT.md
adopt-exclude = KNOWN_ISSUES.md
adopt-exclude = init-project.sh
adopt-exclude = fix-line-endings.sh
adopt-exclude = .mcp.json
adopt-exclude = .editorconfig
adopt-exclude = .gitattributes
adopt-exclude = .pylintrc
adopt-exclude = .env.example
adopt-exclude = VISION.md
adopt-exclude = CHANGELOG.md
adopt-exclude = packaging
adopt-exclude = .docs/design
adopt-exclude = .docs/reports
adopt-exclude = .docs/archive
adopt-exclude = .docs/plans
adopt-exclude = .docs/memory
adopt-exclude = .docs/governance
adopt-exclude = .logic-loom/plans
adopt-exclude = .logic-loom/logs
adopt-exclude = .loom-active-feature
adopt-exclude = .loom-worktree-env

rename = AGENTS.md :: .logic-loom/AGENTS.md

merge = .claude/settings.json
merge = .gitignore
ULMAPEOF
}

# FILE -> normalised rows, tab separated:
#   version TAB n | harness TAB prefix TAB group | exclude TAB pattern
#   | rename TAB src TAB dst | merge TAB path
ul_parse_map() {
  awk '
    { sub(/\r$/, "") }
    /^[ \t]*#/ || /^[ \t]*$/ { next }
    {
      i = index($0, "=")
      if (i == 0) next
      k = substr($0, 1, i - 1); v = substr($0, i + 1)
      sub(/^[ \t]+/, "", k); sub(/[ \t]+$/, "", k)
      sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
      a = v; b = ""
      j = index(v, " :: ")
      if (j > 0) {
        a = substr(v, 1, j - 1); b = substr(v, j + 4)
        sub(/[ \t]+$/, "", a); sub(/^[ \t]+/, "", b); sub(/[ \t]+$/, "", b)
      }
      if (k == "manifest-version") print "version\t" a
      else if (k == "harness") { if (b == "") b = "harness"; print "harness\t" a "\t" b }
      else if (k == "adopt-exclude") print "exclude\t" a
      else if (k == "rename") print "rename\t" a "\t" b
      else if (k == "merge") print "merge\t" a
    }' "$1"
}

UL_MAP=
UL_MAP_SRC=
FORCE_BUILTIN=0

channel_map_load() {
  [ -z "$UL_MAP" ] || return 0
  cm_raw=$(ul_mktemp) || exit 1
  UL_MAP=$(ul_mktemp) || exit 1
  UL_MAP_SRC=builtin
  if [ "$FORCE_BUILTIN" != 1 ]; then
    for cm_src in upstream head; do
      if [ "$cm_src" = upstream ]; then
        git -C "$root" show "$UL_UPSTREAM_REF:$UL_CHANNEL_MAP" > "$cm_raw" 2>/dev/null || continue
      else
        git -C "$root" show "HEAD:$UL_CHANNEL_MAP" > "$cm_raw" 2>/dev/null || continue
      fi
      ul_parse_map "$cm_raw" > "$UL_MAP"
      if grep -q "^harness$ul__tab" "$UL_MAP"; then
        UL_MAP_SRC=$cm_src
        return 0
      fi
    done
  fi
  ul_default_map > "$cm_raw"
  ul_parse_map "$cm_raw" > "$UL_MAP"
  UL_MAP_SRC=builtin
}

manifest_version() { channel_map_load; awk -F'\t' '$1 == "version" { print $2; exit }' "$UL_MAP"; }
harness_prefixes() { channel_map_load; awk -F'\t' '$1 == "harness" { print $2 "\t" $3 }' "$UL_MAP"; }
adopt_excludes() { channel_map_load; awk -F'\t' '$1 == "exclude" { print $2 }' "$UL_MAP"; }
renames() { channel_map_load; awk -F'\t' '$1 == "rename" { print $2 "\t" $3 }' "$UL_MAP"; }
merge_paths() { channel_map_load; awk -F'\t' '$1 == "merge" { print $2 }' "$UL_MAP"; }

path_harness_group() { # PATH -> the payload group of the longest matching prefix, or nothing
  channel_map_load
  ul__np "$1"
  ph_p=$UL_P
  ph_best=
  ph_len=-1
  while IFS=$ul__tab read -r ph_k ph_a ph_b; do
    [ "$ph_k" = harness ] || continue
    case $ph_p in
      "$ph_a"|"$ph_a"/*)
        if [ "${#ph_a}" -gt "$ph_len" ]; then ph_best=$ph_b; ph_len=${#ph_a}; fi;;
    esac
  done < "$UL_MAP"
  printf '%s' "$ph_best"
}

# 0 when PATH is excluded from an adopted install. A plain row matches the path and
# everything under it; a row ending in / matches only what is under it; * crosses /.
path_adopt_excluded() { # PATH
  channel_map_load
  ul__np "$1"
  ae_p=$UL_P
  while IFS=$ul__tab read -r ae_k ae_a ae_b; do
    [ "$ae_k" = exclude ] || continue
    case $ae_a in
      */) case $ae_p in $ae_a*) return 0;; esac;;
      *) case $ae_p in $ae_a|$ae_a/*) return 0;; esac;;
    esac
  done < "$UL_MAP"
  return 1
}

path_is_merge() { # PATH
  channel_map_load
  ul__np "$1"
  pm_p=$UL_P
  while IFS=$ul__tab read -r pm_k pm_a pm_b; do
    [ "$pm_k" = merge ] || continue
    [ "$pm_p" = "$pm_a" ] && return 0
  done < "$UL_MAP"
  return 1
}

path_rename() { # PATH -> the adopted path, nothing when PATH is not renamed
  channel_map_load
  ul__np "$1"
  pr_p=$UL_P
  while IFS=$ul__tab read -r pr_k pr_a pr_b; do
    [ "$pr_k" = rename ] || continue
    if [ "$pr_p" = "$pr_a" ]; then printf '%s' "$pr_b"; return 0; fi
  done < "$UL_MAP"
  return 0
}

# 0 when PATH is, or sits under, a harness prefix. A trailing slash marks a directory
# (git collapses an untracked directory to `dir/`): a directory that CONTAINS a prefix
# counts too, the safe direction.
path_in_harness() { # PATH
  channel_map_load
  pi_dir=0
  case $1 in
    \"*) pi_q=${1#\"}; pi_q=${pi_q%\"}; set -- "$pi_q";;
  esac
  case $1 in */) pi_dir=1;; esac
  ul__np "$1"
  pi_p=$UL_P
  while IFS=$ul__tab read -r pi_k pi_a pi_b; do
    [ "$pi_k" = harness ] || continue
    case $pi_p in "$pi_a"|"$pi_a"/*) return 0;; esac
    if [ "$pi_dir" = 1 ]; then
      case $pi_a in "$pi_p"/*) return 0;; esac
    fi
  done < "$UL_MAP"
  return 1
}

# Lines of `git status --porcelain` that make the tree not clean: every tracked change,
# and every untracked path that sits under a harness prefix. An untracked file outside
# the harness (kori has .claude/launch.json) is not the update's business.
# Fail closed: a `git status` that FAILS (a corrupt or locked index) prints nothing on
# stdout, and nothing is what a clean tree prints too, so its exit status is checked
# and a failure is reported as the one offender line CO_STATUS_FAILED. The untracked
# mode is pinned to `normal`: a customer's own status.showUntrackedFiles=no would
# otherwise hide every untracked harness file from this check.
CO_STATUS_FAILED='error git status failed'
clean_offenders() {
  channel_map_load
  co_out=$(git -C "$root" status --porcelain --untracked-files=normal 2>/dev/null)
  co_rc=$?
  if [ "$co_rc" -ne 0 ]; then
    printf '%s\n' "$CO_STATUS_FAILED"
    return 0
  fi
  [ -n "$co_out" ] || return 0
  printf '%s\n' "$co_out" | while IFS= read -r co_l; do
    case $co_l in
      '?? '*)
        co_p=${co_l#'?? '}
        if path_in_harness "$co_p"; then printf '%s\n' "$co_l"; fi;;
      '!! '*) ;;
      *) printf '%s\n' "$co_l";;
    esac
  done
}

is_clean() {
  ic_o=$(clean_offenders)
  [ -z "$ic_o" ]
}

status_failed() { # OFFENDERS -> 0 when the offenders say git status itself failed
  case $1 in *"$CO_STATUS_FAILED"*) return 0;; esac
  return 1
}

# -------------------------------------------------------------------- channel
CH=template
CH_NOTICE=
CH_GROUPS=all

# Sets CH (template|adopted|ambiguous), CH_NOTICE and CH_GROUPS (a comma list, `all`
# or `none`) from what is on disk, fail-closed (design 1.4). ambiguous is treated as
# adopted with every optional group uninstalled.
detect_channel() {
  CH=template; CH_NOTICE=; CH_GROUPS=all
  dc_rc=$root/.logicloom-adopt-receipt.json
  if [ -e "$dc_rc" ]; then
    CH=ambiguous; CH_GROUPS=none
    if [ ! -f "$UL_TOOLS/json-valid.sh" ] || [ ! -f "$UL_TOOLS/json-flat.sh" ]; then
      CH_NOTICE="the JSON tools are missing, so your adopt receipt could not be read"
      return 0
    fi
    if ! ul_json_valid "$dc_rc" >/dev/null 2>&1; then
      CH_NOTICE="your adopt receipt is damaged"
      return 0
    fi
    dc_flat=$(ul_mktemp) || exit 1
    ul_json_flat "$dc_rc" > "$dc_flat" 2>/dev/null
    dc_schema=$(awk -F'\t' '$1 == "/schema" { print $2; exit }' "$dc_flat")
    if [ "$dc_schema" != logicloom/adopt-receipt@1 ]; then
      CH_NOTICE="your adopt receipt has a format this updater does not know"
      return 0
    fi
    # The installed groups are the UNION of the `only` lists of every run whose
    # status is complete or partial (the installer's own reading of its receipt,
    # packaging/adopt/lib/receipt.js provenance(): `--only=all` then `--only=hooks`
    # is two runs, and the second does not uninstall the first). An aborted run, or
    # one that never recorded a status (it crashed), adds nothing. `all` is already
    # expanded to group names when the receipt is written. A usable run with no
    # `only` entries means every group. No usable run at all: nothing is known to be
    # installed, so the copy is ambiguous (adopted-superset) with a notice.
    # Pass 1 keys each entry by run and index (json-flat's row order is not the
    # document's), sort puts them in run order, pass 2 dedupes and joins.
    dc_groups=$(awk -F'\t' '
      {
        n = split($1, a, "/")
        if (a[2] != "runs" || a[3] !~ /^[0-9]+$/) next
        run = a[3] + 0
        if (n == 4 && a[4] == "status") st[run] = $2
        if (n == 5 && a[4] == "only" && a[5] ~ /^[0-9]+$/) {
          r++; ri[r] = run; ii[r] = a[5] + 0; v[r] = $2; has[run] = 1
        }
      }
      END {
        usable = 0
        for (k in st) {
          if (st[k] == "complete" || st[k] == "partial") {
            usable++; ok[k] = 1
            if (!(k in has)) print "ALL"
          }
        }
        if (usable == 0) { print "NONE"; exit }
        for (i = 1; i <= r; i++) if (ri[i] in ok) printf "%08d %08d %s\n", ri[i], ii[i], v[i]
      }' "$dc_flat" | sort | awk '
      $0 == "NONE" { none = 1; next }
      $0 == "ALL" { all = 1; next }
      {
        g = substr($0, 19)
        if (g != "" && !(g in seen)) { seen[g] = 1; out = out (out == "" ? "" : ",") g }
      }
      END {
        if (none) print "none"
        else if (all || out == "") print "all"
        else print out
      }')
    if [ "$dc_groups" = none ]; then
      CH_NOTICE="your adopt receipt records no completed install run"
      return 0
    fi
    CH=adopted
    CH_GROUPS=$dc_groups
    return 0
  fi
  if [ -e "$root/.claude/.logicloom-adopt-settings.json" ]; then
    CH=ambiguous; CH_GROUPS=none; return 0
  fi
  for dc_f in "$root"/.claude/rules/logicloom-*.md; do
    if [ -e "$dc_f" ]; then CH=ambiguous; CH_GROUPS=none; return 0; fi
  done
  if [ -e "$root/.logic-loom/AGENTS.md" ] && [ ! -e "$root/AGENTS.md" ]; then
    CH=ambiguous; CH_GROUPS=none; return 0
  fi
  return 0
}

CHANNEL=template
# detect_channel plus --channel: the override settles an ambiguous tree and is refused
# when the tree is unambiguous and disagrees.
resolve_channel() {
  detect_channel
  CHANNEL=$CH
  if [ -n "$OPT_CHANNEL" ]; then
    if [ "$CH" = ambiguous ] || [ "$CH" = "$OPT_CHANNEL" ]; then
      CHANNEL=$OPT_CHANNEL
    else
      echo "error --channel $OPT_CHANNEL disagrees with what this copy looks like ($CH)"
      exit 1
    fi
  fi
}

# ------------------------------------------------------------ bundle + engine
# One word: absent | complete | incomplete missing=<a,b> | unverifiable.
bundle_status() {
  bs_f=$root/$UL_BUNDLE
  if [ ! -f "$bs_f" ]; then printf 'absent'; return 0; fi
  bs_missing=
  bs_rows=0
  bs_cr=$(printf '\r')
  while IFS= read -r bs_l || [ -n "$bs_l" ]; do
    bs_l=${bs_l%"$bs_cr"}
    case $bs_l in ''|'#'*) continue;; esac
    bs_h=${bs_l%% *}
    case $bs_h in ''|*[!0-9a-fA-F]*) continue;; esac
    [ "${#bs_h}" -eq 64 ] || continue
    bs_p=${bs_l#"$bs_h"}
    while :; do
      case $bs_p in ' '*) bs_p=${bs_p# };; *) break;; esac
    done
    case $bs_p in '*'*) bs_p=${bs_p#?};; esac
    [ -n "$bs_p" ] || continue
    bs_rows=$((bs_rows + 1))
    if [ ! -f "$root/$bs_p" ]; then
      bs_missing=${bs_missing:+$bs_missing,}$bs_p
      continue
    fi
    bs_got=$(ul_sha256 "$root/$bs_p") || { printf 'unverifiable'; return 0; }
    bs_got=$(printf '%s' "$bs_got" | tr 'A-F' 'a-f')
    bs_want=$(printf '%s' "$bs_h" | tr 'A-F' 'a-f')
    if [ "$bs_got" != "$bs_want" ]; then
      bs_missing=${bs_missing:+$bs_missing,}$bs_p
    fi
  done < "$bs_f"
  if [ "$bs_rows" -eq 0 ]; then printf 'unverifiable'; return 0; fi
  if [ -n "$bs_missing" ]; then printf 'incomplete missing=%s' "$bs_missing"; else printf 'complete'; fi
}

# current | stale | unknown. unknown: no successful fetch this run, or upstream has no
# copy. A missing local copy is stale (it needs the bootstrap copy).
engine_status() {
  es_loc=$root/$UL_SCRIPTS_DIR/update-loom.sh
  if [ "$FETCHED" != 1 ]; then printf 'unknown'; return 0; fi
  es_up=$(git -C "$root" rev-parse -q --verify "$UL_UPSTREAM_REF:$UL_SCRIPTS_DIR/update-loom.sh" 2>/dev/null) || es_up=
  if [ -z "$es_up" ]; then printf 'unknown'; return 0; fi
  if [ ! -f "$es_loc" ]; then printf 'stale'; return 0; fi
  es_lh=$(git -C "$root" hash-object -- "$es_loc" 2>/dev/null) || es_lh=
  if [ "$es_lh" = "$es_up" ]; then printf 'current'; else printf 'stale'; fi
}

# ------------------------------------------------------------------ the ledger
ledger_rows() { # the tracked ledger's rows at HEAD, # lines and blanks dropped
  git -C "$root" show "HEAD:$UL_LEDGER" 2>/dev/null | awk '/^[ \t]*#/ || /^[ \t]*$/ { next } { print }'
}

ledger_row_count() { ledger_rows | awk 'END { print NR + 0 }'; }

ledger_outcome() { # ID -> the last outcome recorded for that note id, or nothing
  ledger_rows | awk -F'\t' -v id="$1" '$1 == id { o = $2 } END { if (o != "") print o }'
}

staged_value() {
  sv_v=
  if [ -f "$state/staged" ]; then sv_v=$(sed -n '1p' "$state/staged" 2>/dev/null | tr -d ' \t\r\n'); fi
  printf '%s' "${sv_v:-none}"
}

# ------------------------------------------------------------- safe file writes
# Writes SRCFILE as WT/PATH with every parent component lstat-ed ([ -L ]): a symlink
# anywhere in the path, or at the path itself, refuses. The body goes to a temp
# regular file in the same directory and is renamed into place, so a reader never
# sees half a file. MODE is 100644 or 100755. Touches no git state.
write_file_safe() { # WT PATH SRCFILE MODE
  wf_wt=$1; wf_p=$2; wf_src=$3; wf_mode=$4
  case $wf_p in
    ''|/*) echo "error unsafe path $wf_p"; return 1;;
  esac
  case $wf_mode in
    100644|100755) ;;
    *) echo "error unsupported mode $wf_mode for $wf_p"; return 1;;
  esac
  if [ ! -f "$wf_src" ]; then echo "error source file is missing: $wf_src"; return 1; fi
  wf_cur=$wf_wt
  wf_rel=
  wf_rest=$wf_p
  while [ -n "$wf_rest" ]; do
    case $wf_rest in
      */*) wf_c=${wf_rest%%/*}; wf_rest=${wf_rest#*/};;
      *) wf_c=$wf_rest; wf_rest=;;
    esac
    case $wf_c in
      ''|.) continue;;
      ..) echo "error unsafe path $wf_p"; return 1;;
    esac
    wf_rel=${wf_rel:+$wf_rel/}$wf_c
    wf_cur=$wf_cur/$wf_c
    if [ -L "$wf_cur" ]; then
      echo "error symlink in path $wf_rel"
      return 1
    fi
  done
  if [ -d "$wf_cur" ]; then echo "error $wf_p is a directory"; return 1; fi
  wf_dir=$(dirname -- "$wf_cur")
  mkdir -p "$wf_dir" || { echo "error could not create the directory for $wf_p"; return 1; }
  wf_tmp=$(mktemp "$wf_dir/.update-loom.XXXXXX") || { echo "error could not create a temp file for $wf_p"; return 1; }
  if ! cat "$wf_src" > "$wf_tmp"; then
    rm -f "$wf_tmp"
    echo "error could not write $wf_p"
    return 1
  fi
  case $wf_mode in
    100755) chmod 755 "$wf_tmp";;
    *) chmod 644 "$wf_tmp";;
  esac
  if ! mv -f "$wf_tmp" "$wf_cur"; then
    rm -f "$wf_tmp"
    echo "error could not place $wf_p"
    return 1
  fi
  return 0
}

# write_file_safe, then stage the path in WT and record the mode in the index. With
# core.filemode=false git ignores the executable bit on disk, so `update-index
# --chmod` sets it directly; without it a 100755 file would be staged 100644.
write_path() { # WT PATH SRCFILE MODE
  write_file_safe "$1" "$2" "$3" "$4" || return 1
  git -C "$1" add -f -- "$2" >/dev/null 2>&1 || { echo "error could not stage $2"; return 1; }
  case $4 in 100755) wp_c=+x;; *) wp_c=-x;; esac
  git -C "$1" update-index --chmod=$wp_c -- "$2" >/dev/null 2>&1 || { echo "error could not record the mode of $2"; return 1; }
  return 0
}

# ---------------------------------------------------------------- lock + heal
lock_pid_live() { # PID
  case ${1:-} in ''|*[!0-9]*) return 1;; esac
  kill -0 "$1" 2>/dev/null
}

# The updater deletes recursively under its state directory (the throwaway worktree,
# the rebuilt plan folders). Those deletes are only allowed when the state directory
# has the expected shape and neither it nor any ancestor up to the git directory is a
# symlink: a link at .git/loom or .git/loom/update could otherwise aim `rm -rf` at a
# directory outside the repository. Returns 1 when it is not safe.
state_dir_safe() {
  case $state in ?*/loom/update) ;; *) return 1;; esac
  sd_p=$state
  while [ "$sd_p" != "$gd" ]; do
    if [ -L "$sd_p" ]; then return 1; fi
    sd_n=$(dirname -- "$sd_p")
    if [ "$sd_n" = "$sd_p" ]; then return 1; fi
    sd_p=$sd_n
  done
  return 0
}

HEALED=
LOCK_LIVE=

# Clears what a stage that was killed mid-run leaves behind: a stage.lock whose pid is
# gone, and the detached worktree. A live lock is left alone (returns 1, LOCK_LIVE=pid).
# Without `force`, the worktree is kept whenever `staged` exists: --stage writes that
# file last, so a staged commit is complete and waiting to land, and the worktree is
# what keeps it reachable until the merge (a dead lock beside it only means the stage
# process did not get to release the lock). --stage's own start passes `force` and
# starts over.
heal_stale() { # [force]
  hs_force=${1:-}
  HEALED=
  LOCK_LIVE=
  hs_lk=$state/stage.lock
  if [ -f "$hs_lk" ]; then
    hs_pid=$(sed -n '1p' "$hs_lk" 2>/dev/null | tr -d ' \t\r\n')
    if lock_pid_live "$hs_pid"; then
      LOCK_LIVE=$hs_pid
      return 1
    fi
    rm -f "$hs_lk"
    cg_unlock force   # a run killed mid-check (SIGKILL) may have left the backups read-only
    HEALED=yes
  fi
  if [ "$hs_force" != force ] && [ -f "$state/staged" ]; then
    return 0
  fi
  hs_wt=$state/wt
  hs_phys=
  if [ -d "$state" ]; then
    hs_dir=$(CDPATH= cd -- "$state" 2>/dev/null && pwd -P) || hs_dir=
    [ -n "$hs_dir" ] && hs_phys=$hs_dir/wt
  fi
  hs_reg=$(git -C "$root" worktree list --porcelain 2>/dev/null | awk -v a="$hs_wt" -v b="$hs_phys" '$1 == "worktree" { p = substr($0, 10); if (p == a || (b != "" && p == b)) { print "1"; exit } }')
  if [ -d "$hs_wt" ] && state_dir_safe && [ ! -L "$hs_wt" ]; then
    git -C "$root" worktree remove --force "$hs_wt" >/dev/null 2>&1
    chmod -R u+w "$hs_wt" 2>/dev/null
    rm -rf "$hs_wt"
    HEALED=yes
  fi
  if [ -n "$hs_reg" ]; then
    git -C "$root" worktree prune >/dev/null 2>&1
    HEALED=yes
  fi
  return 0
}

# `keep` heals without `force`: a staged update's worktree is kept (--plan, --finish and
# the state writers take the lock but must not clear a staged update's worktree).
lock_acquire() { # [keep]
  mkdir -p "$state" || { echo "error could not create $state"; return 1; }
  if [ "${1:-}" = keep ]; then
    la_heal=
  else
    la_heal=force
  fi
  if ! heal_stale $la_heal; then
    echo "error another update is staging (pid $LOCK_LIVE)"
    return 1
  fi
  if ( set -C; printf '%s\n' "$$" > "$state/stage.lock" ) 2>/dev/null; then
    LOCK_HELD=1
    return 0
  fi
  la_other=$(sed -n '1p' "$state/stage.lock" 2>/dev/null | tr -d ' \t\r\n')
  echo "error another update is staging (pid ${la_other:-unknown})"
  return 1
}

# ------------------------------------------------------------------ base helpers
recorded_stamp() { # the pointer as committed at HEAD, whitespace stripped
  git -C "$root" show "HEAD:$UL_SYNC_REF" 2>/dev/null | tr -d ' \t\r\n'
}

# STR -> prints the full sha when STR is a commit reachable from upstream's head.
# Hex only: a value starting with a dash, or holding a path or a revision expression,
# is never passed to git.
reach_full() {
  case ${1:-} in ''|*[!0-9a-fA-F]*) return 1;; esac
  [ "${#1}" -ge 7 ] || return 1
  rf_s=$(git -C "$root" rev-parse -q --verify "$1^{commit}" 2>/dev/null) || return 1
  [ -n "$rf_s" ] || return 1
  git -C "$root" merge-base --is-ancestor "$rf_s" "$UPSTREAM_HEAD" 2>/dev/null || return 1
  printf '%s' "$rf_s"
}

# Two shipped releases stamped .sdd-sync-ref with a commit that exists only on a
# release branch (their release PRs were squash-merged). This is the fixed historical
# repair list the old extractor kept, ported unchanged and NOT widened: add an entry
# only for a stamp that actually shipped and has an unambiguous main-branch twin.
remap_known_bad() { # STAMP -> the mapped main commit, or nothing
  case $1 in
    6c4c42067161bf77e3e1af0ff91691319bd2fbdc) printf '%s' a2ed86231e097886f58e7fd0e5161648c6e6cfa3;;
    c6d040f36ecb6ef4a5365e9434b4e31dc741e4ac) printf '%s' 75551c3574eea3f54a92d044da2e1a92b4e9590c;;
    *) printf '%s' '';;
  esac
}

UPSTREAM_HEAD=

# Rung 3. Walks upstream's first-parent history (newest first, at most 400 commits) and
# counts, for each commit, the harness-owned paths that differ from HEAD. The newest
# exact match wins; otherwise the fewest differences, newest on a tie. .sdd-sync-ref is
# left out of the comparison: it is the very pointer being repaired. Sets CL_SHA and
# CL_N, returns 1 when nothing can be matched (no harness files in HEAD, or no history).
closest_search() {
  CL_SHA=; CL_N=
  cs_pf=$(ul_mktemp) || exit 1
  harness_prefixes | awk -F'\t' -v s="$UL_SYNC_REF" '$1 != s { print $1 }' > "$cs_pf"
  set --
  while IFS= read -r cs_p; do
    [ -n "$cs_p" ] && set -- "$@" "$cs_p"
  done < "$cs_pf"
  [ "$#" -gt 0 ] || return 1
  cs_any=$(git -C "$root" ls-tree -r --name-only HEAD -- "$@" 2>/dev/null | sed -n '1p')
  [ -n "$cs_any" ] || return 1
  cs_best=; cs_bn=
  for cs_c in $(git -C "$root" rev-list --first-parent -n 400 "$UL_UPSTREAM_REF" 2>/dev/null); do
    if cs_o=$(git -C "$root" diff --ignore-cr-at-eol --name-only "$cs_c" HEAD -- "$@" 2>/dev/null); then
      :
    else
      cs_o=$(git -C "$root" diff --name-only "$cs_c" HEAD -- "$@" 2>/dev/null) || continue
    fi
    cs_n=$(printf '%s\n' "$cs_o" | awk 'NF { n++ } END { print n + 0 }')
    if [ -z "$cs_bn" ] || [ "$cs_n" -lt "$cs_bn" ]; then cs_best=$cs_c; cs_bn=$cs_n; fi
    [ "$cs_n" -eq 0 ] && break
  done
  [ -n "$cs_best" ] || return 1
  CL_SHA=$cs_best; CL_N=$cs_bn
  return 0
}

# ===================================================================== plan
# Globals of one planning run (the sh family has no `local`; every name here is
# prefixed PL_ or pp_ so no helper above can collide with it).
PL_BASE=
PL_RUNG=
PL_UP=
PL_HEAD=
PL_INST=
PL_SIDEBASE=-
PL_ADOPT_BASE_USED=0
PL_SIDE_FAIL=0
RN_SRCS=
RN_DSTS=
MERGE_PATHS=

abort_plan() { # REASON : the one refusal shape; nothing has been touched yet
  printf 'result=aborted reason=%s unchanged=yes\n' "$1"
  exit 1
}

offender_paths() { # `git status --porcelain` lines -> up to five paths, comma-joined
  printf '%s\n' "$1" | awk '
    NF == 0 { next }
    { n++; if (n <= 5) { p = substr($0, 4); out = out (out == "" ? "" : ", ") p } }
    END { printf "%s", out; if (n > 5) printf " (and %d more)", n - 5 }'
}

# The payload groups an adopted copy has installed: the receipt's union, `all`, or --
# for an ambiguous copy settled with --channel adopted -- only the core group.
plan_groups_load() {
  case $CH_GROUPS in
    all) PL_INST=all;;
    none) PL_INST=harness;;
    *) PL_INST=$CH_GROUPS;;
  esac
}

group_installed() { # GROUP
  [ "$PL_INST" = all ] && return 0
  case ",$PL_INST," in *",$1,"*) return 0;; esac
  return 1
}

plan_maps_load() { # the rename and merge lists, as newline-separated strings
  RN_SRCS=
  RN_DSTS=
  MERGE_PATHS=
  [ "$CHANNEL" = adopted ] || return 0
  RN_SRCS=$(renames | awk -F'\t' '{ print $1 }')
  RN_DSTS=$(renames | awk -F'\t' '{ print $2 }')
  MERGE_PATHS=$(merge_paths)
}

# The path this copy keeps UPSTREAM_PATH at. Only the adopted channel renames
# (AGENTS.md lives at .logic-loom/AGENTS.md); the upstream side always keeps the
# upstream name, and every other side of the three is read at this one.
local_path_for() { # UPSTREAM_PATH
  lpf_r=
  if [ "$CHANNEL" = adopted ]; then
    case "$ul__nl$RN_SRCS$ul__nl" in
      *"$ul__nl$1$ul__nl"*) lpf_r=$(path_rename "$1");;
    esac
  fi
  if [ -n "$lpf_r" ]; then printf '%s' "$lpf_r"; else printf '%s' "$1"; fi
}

entry_at() { # COMMIT PATH -> `mode sha`, or `- -` when the path is not a file there
  ea_l=$(git --literal-pathspecs -C "$root" ls-tree "$1" -- "$2" 2>/dev/null | sed -n '1p')
  if [ -n "$ea_l" ]; then
    ea_meta=${ea_l%%"$ul__tab"*}
    set -- $ea_meta
    if [ "$#" -ge 3 ]; then
      case $2 in blob|commit) printf '%s %s' "$1" "$3"; return 0;; esac
    fi
  fi
  printf '%s' '- -'
}

sha_norm() { # SHA MODE -> CRLF-insensitive fingerprint; nothing when the side is absent
  case ${1:-} in -|'') return 0;; esac
  if [ "${2:-}" = 160000 ]; then printf 'gitlink-%s' "$1"; return 0; fi
  git -C "$root" cat-file blob "$1" 2>/dev/null | ul_norm_hash
}

save_side() { # SHA DEST : the blob as a regular file; `-` writes nothing
  case ${1:-} in -|'') return 0;; esac
  mkdir -p "$(dirname -- "$2")" 2>/dev/null
  if git -C "$root" cat-file blob "$1" > "$2.part" 2>/dev/null && mv -f "$2.part" "$2" 2>/dev/null; then
    return 0
  fi
  rm -f "$2.part" "$2"
  PL_SIDE_FAIL=$((PL_SIDE_FAIL + 1))
  return 1
}

plan_reviewer_log() { # `git log base..upstream -- <upstream path>`: the reviewer agent has no git
  prl_f=$state/reviewer/$pp_lp.log
  mkdir -p "$(dirname -- "$prl_f")" 2>/dev/null
  git --literal-pathspecs -C "$root" -c log.showSignature=false log --no-color --format='%h %s' "$PL_BASE..$PL_UP" -- "$pp_p" > "$prl_f" 2>/dev/null
  return 0
}

plan_sides() { # base / theirs / mine into state/adapt, and the adapt.tsv row
  save_side "$PL_SIDEBASE" "$state/adapt/base/$pp_lp"
  save_side "$pp_us" "$state/adapt/theirs/$pp_lp"
  save_side "$pp_hs" "$state/adapt/mine/$pp_lp"
  printf '%s\t-\t%s\t%s\t%s\n' "$pp_lp" "$PL_SIDEBASE" "$pp_us" "$pp_hs" >> "$state/adapt.tsv"
}

# Diffs are made from the saved sides, so a renamed path and the adopt-settings base
# read like any other; a missing side diffs against /dev/null.
plan_diffs() {
  pdf_d=$state/diffs/$pp_lp
  mkdir -p "$(dirname -- "$pdf_d")" 2>/dev/null
  pdf_b=base/$pp_lp; [ -f "$state/adapt/$pdf_b" ] || pdf_b=/dev/null
  pdf_t=theirs/$pp_lp; [ -f "$state/adapt/$pdf_t" ] || pdf_t=/dev/null
  pdf_m=mine/$pp_lp; [ -f "$state/adapt/$pdf_m" ] || pdf_m=/dev/null
  git -c diff.noprefix=false -c diff.mnemonicPrefix=false -C "$state/adapt" diff --no-index --no-color --no-ext-diff --no-textconv -- "$pdf_b" "$pdf_t" > "$pdf_d.base-upstream.diff" 2>/dev/null
  git -c diff.noprefix=false -c diff.mnemonicPrefix=false -C "$state/adapt" diff --no-index --no-color --no-ext-diff --no-textconv -- "$pdf_b" "$pdf_m" > "$pdf_d.base-local.diff" 2>/dev/null
  return 0
}

# One plan.tsv row for pp_lp, and the files that go with it: a reviewer log for every
# non-skip row; sides, adapt.tsv row and both diffs for a hold or merged-clean row.
plan_row() { # CLASS PROPOSED DETAIL
  printf '%s\t%s\t%s\t%s\n' "$pp_lp" "$1" "$2" "$3" >> "$state/plan.tsv"
  if [ "$2" != skip ]; then plan_reviewer_log; fi
  if [ "$2" = hold ] || [ "$1" = merged-clean ]; then
    plan_sides
    plan_diffs
  fi
}

# A row for a path the engine will never touch. It is written only when upstream changed
# the path since the base AND this copy differs from upstream, so the customer sees that
# upstream moved something the engine leaves alone -- and a customer's own product
# files, which upstream does not have, do not bury the plan.
skip_row() { # CLASS DETAIL
  if [ "$pp_uch" = 1 ] && [ "$pp_hdu" = 1 ]; then plan_row "$1" skip "$2"; fi
  return 0
}

# Three-way merge of the saved blobs. A clean merge keeps its body for --stage.
plan_merge() {
  pm_b=$(ul_mktemp) || exit 1
  pm_h=$(ul_mktemp) || exit 1
  pm_u=$(ul_mktemp) || exit 1
  pm_o=$(ul_mktemp) || exit 1
  git -C "$root" cat-file blob "$pp_bs" > "$pm_b" 2>/dev/null
  git -C "$root" cat-file blob "$pp_hs" > "$pm_h" 2>/dev/null
  git -C "$root" cat-file blob "$pp_us" > "$pm_u" 2>/dev/null
  if git -C "$root" merge-file -p -L mine -L base -L theirs "$pm_h" "$pm_b" "$pm_u" > "$pm_o" 2>/dev/null; then
    mkdir -p "$(dirname -- "$state/merged/$pp_lp")" 2>/dev/null
    cp "$pm_o" "$state/merged/$pp_lp"
    plan_row merged-clean apply "three-way merge was clean"
  else
    plan_row conflict hold "three-way merge left conflict markers"
  fi
  rm -f "$pm_b" "$pm_h" "$pm_u" "$pm_o"
}

# The heart (LH:update.sh:546-687, minus the skill-pack and registry branches). Arguments
# are the path under its UPSTREAM name and its three tree entries (mode, sha; `-` =
# absent) at base, HEAD and upstream.
process_path() { # P BM BS HM HS UM US
  pp_p=$1; pp_bm=$2; pp_bs=$3; pp_hm=$4; pp_hs=$5; pp_um=$6; pp_us=$7
  pp_lp=$pp_p
  case /$pp_p/ in
    */../*|*/./*|*//*|*/[.][gG][iI][tT]/*) return 0;;
  esac
  if [ "$CHANNEL" = adopted ]; then
    case "$ul__nl$RN_DSTS$ul__nl" in
      *"$ul__nl$pp_p$ul__nl"*)
        # a rename target is the same file as its source; the source's row covers it
        if [ "$pp_bs" = - ] && [ "$pp_us" = - ]; then return 0; fi;;
    esac
    case "$ul__nl$RN_SRCS$ul__nl" in
      *"$ul__nl$pp_p$ul__nl"*)
        pp_t=$(path_rename "$pp_p")
        if [ -n "$pp_t" ] && [ "$pp_t" != "$pp_p" ]; then
          pp_lp=$pp_t
          set -- $(entry_at HEAD "$pp_lp"); pp_hm=$1; pp_hs=$2
          # the base is an upstream commit, so the source name is its name; the
          # target name is tried only when the source is not there
          if [ "$pp_bs" = - ]; then set -- $(entry_at "$PL_BASE" "$pp_lp"); pp_bm=$1; pp_bs=$2; fi
        fi;;
    esac
  fi
  PL_SIDEBASE=$pp_bs
  if [ "$pp_bs" = "$pp_hs" ] && [ "$pp_hs" = "$pp_us" ] && [ "$pp_bm" = "$pp_hm" ] && [ "$pp_hm" = "$pp_um" ]; then
    return 0
  fi

  pp_bn=$(sha_norm "$pp_bs" "$pp_bm")
  if [ "$pp_hs" = "$pp_bs" ]; then pp_hn=$pp_bn; else pp_hn=$(sha_norm "$pp_hs" "$pp_hm"); fi
  if [ "$pp_us" = "$pp_bs" ]; then pp_un=$pp_bn
  elif [ "$pp_us" = "$pp_hs" ]; then pp_un=$pp_hn
  else pp_un=$(sha_norm "$pp_us" "$pp_um"); fi
  pp_uch=0
  if [ "$pp_un" != "$pp_bn" ] || [ "$pp_um" != "$pp_bm" ]; then pp_uch=1; fi
  pp_hdu=0
  if [ "$pp_hn" != "$pp_un" ] || [ "$pp_hm" != "$pp_um" ]; then pp_hdu=1; fi

  # (a) the forbidden-touch set, both channels
  if ul_path_forbidden "$pp_lp" || ul_path_forbidden "$pp_p"; then
    skip_row excluded forbidden
    return 0
  fi

  # (b) the channel map, adopted copies only
  if [ "$CHANNEL" = adopted ]; then
    if path_adopt_excluded "$pp_p" || path_adopt_excluded "$pp_lp"; then
      skip_row excluded adopt-excluded
      return 0
    fi
    case "$ul__nl$MERGE_PATHS$ul__nl" in
      *"$ul__nl$pp_lp$ul__nl"*)
        if [ -n "$pp_hn" ] && [ -n "$pp_un" ]; then
          # changed in place by the installer: never merged, always a person's call
          if [ "$pp_hdu" = 1 ] && [ "$pp_uch" = 1 ]; then
            PL_SIDEBASE=-
            if [ "$pp_lp" = .claude/settings.json ]; then
              pp_as=$(git -C "$root" rev-parse -q --verify "HEAD:.claude/.logicloom-adopt-settings.json" 2>/dev/null) || pp_as=
              if [ -n "$pp_as" ]; then PL_SIDEBASE=$pp_as; PL_ADOPT_BASE_USED=1; fi
            fi
            plan_row posture hold "merge file in an adopted install: held for review"
          fi
          return 0
        fi;;
    esac
    pp_g=$(path_harness_group "$pp_lp")
    if [ -z "$pp_g" ]; then
      skip_row adopter-owned "not harness-owned"
      return 0
    fi
    if ! group_installed "$pp_g"; then
      skip_row adopter-owned "group $pp_g not installed"
      return 0
    fi
  fi

  # (0) the notes tree, the engine and its tools: upstream-owned, never held or kept
  case $pp_p in
    "$UL_NOTES_DIR"/*|"$UL_SCRIPTS_DIR"/*)
      if [ "$pp_hdu" = 0 ]; then return 0; fi
      if [ -z "$pp_hn" ]; then plan_row add apply upstream-owned
      elif [ -z "$pp_un" ]; then plan_row delete apply upstream-owned
      else plan_row take apply upstream-owned; fi
      return 0;;
  esac

  # (1) absent in base
  if [ "$pp_bs" = - ]; then
    if [ -n "$pp_un" ]; then
      if [ -z "$pp_hn" ]; then
        plan_row add apply "new upstream file"
      elif [ "$pp_hn" != "$pp_un" ]; then
        plan_row add-conflict hold "new upstream file, and a different local file already exists"
      fi
    fi
    return 0
  fi

  pp_hc=0; if [ "$pp_hn" != "$pp_bn" ]; then pp_hc=1; fi
  pp_uc=0; if [ "$pp_un" != "$pp_bn" ]; then pp_uc=1; fi

  # (2) equal blobs everywhere: only the modes can differ
  if [ "$pp_hc" = 0 ] && [ "$pp_uc" = 0 ]; then
    if [ "$pp_hm" = "$pp_um" ]; then return 0; fi
    if [ "$pp_hm" = "$pp_bm" ]; then plan_row mode apply "upstream changed the file mode to $pp_um"; return 0; fi
    if [ "$pp_um" = "$pp_bm" ]; then plan_row keep keep "file mode changed locally only"; return 0; fi
    plan_row mode hold "the file mode differs from both upstream's and the base's"
    return 0
  fi
  # (3) upstream changed it, this copy did not
  if [ "$pp_uc" = 1 ] && [ "$pp_hc" = 0 ]; then
    if [ -z "$pp_un" ]; then plan_row delete apply "deleted upstream, unchanged locally"
    else plan_row take apply "changed upstream, unchanged locally"; fi
    return 0
  fi
  # (4) this copy changed it, upstream did not
  if [ "$pp_hc" = 1 ] && [ "$pp_uc" = 0 ]; then
    plan_row keep keep "changed locally only"
    return 0
  fi
  # both changed. The same change on both sides needs nothing.
  if [ "$pp_hn" = "$pp_un" ]; then return 0; fi
  if [ -z "$pp_un" ]; then
    plan_row deleted-upstream-kept hold "deleted upstream, changed locally"      # (5)
  elif [ -z "$pp_hn" ]; then
    plan_row conflict hold "deleted locally, changed upstream"                   # (6)
  elif ul_path_posture "$pp_lp" || [ "$pp_lp" = .claude/settings.json ]; then
    plan_row posture hold "posture file changed on both sides; always held for review"
  else
    case "$pp_bm$pp_hm$pp_um" in
      *120000*|*160000*) plan_row conflict hold "a symlink or submodule changed on both sides";;
      *) plan_merge;;
    esac
  fi
  return 0
}

# Adds (or replaces) the two-way held row for one path: base -, theirs = upstream's blob,
# mine = this copy's. The notes layer calls it for a `keep` path an offered note touches.
# PATH is the UPSTREAM name; the row is written at local_path_for(PATH). Needs PL_BASE,
# PL_UP, PL_HEAD and CHANNEL (cmd_plan sets them; --selftest-two-way reads them from meta).
write_two_way_row() { # UPSTREAM_PATH
  w2_p=$1
  w2_l=$(local_path_for "$w2_p")
  w2_u=$(git -C "$root" rev-parse -q --verify "$PL_UP:$w2_p" 2>/dev/null) || w2_u=-
  w2_h=$(git -C "$root" rev-parse -q --verify "$PL_HEAD:$w2_l" 2>/dev/null) || w2_h=-
  rm -f "$state/adapt/base/$w2_l" "$state/adapt/theirs/$w2_l" "$state/adapt/mine/$w2_l"
  save_side "$w2_u" "$state/adapt/theirs/$w2_l"
  save_side "$w2_h" "$state/adapt/mine/$w2_l"
  w2_t=$(ul_mktemp) || exit 1
  for w2_f in plan.tsv adapt.tsv; do
    [ -f "$state/$w2_f" ] || : > "$state/$w2_f"
    awk -F'\t' -v p="$w2_l" '$1 != p' "$state/$w2_f" > "$w2_t"
    cp "$w2_t" "$state/$w2_f"
  done
  printf '%s\ttwo-way\thold\t%s\n' "$w2_l" "no common base; compared two-way" >> "$state/plan.tsv"
  printf '%s\t-\t-\t%s\t%s\n' "$w2_l" "$w2_u" "$w2_h" >> "$state/adapt.tsv"
  for w2_f in plan.tsv adapt.tsv; do
    LC_ALL=C sort -t "$ul__tab" -k1,1 "$state/$w2_f" > "$w2_t"
    cp "$w2_t" "$state/$w2_f"
  done
  return 0
}

# ===================================================================== the notes layer
# Runs from plan_after_classify: plan.tsv and adapt.tsv are complete and sorted. It
# reads the notes under upstream's tree (never the working tree), decides which are
# offered (design 1.5), runs their checks against the read-only export, adds the
# two-way rows, and writes notes.tsv, groups.tsv, transaction.txt and the note ids in
# adapt.tsv. Every temp name is a global NT_* because the sh family has no `local`.
NT_WORK=
NT_LED=
NT_CK=
NT_OFF=
NT_ORD=
NT_BLK=
NT_GRP=
NT_PM=
NT_N=0
NT_G=0
NT_B=0
NT_T=0
NT_LIST=
NT_BAD=
NT_U=

notes_relock() { # the export is read-only whenever no check is running
  if [ -d "$state/export" ]; then chmod -R a-w "$state/export" 2>/dev/null; fi
  return 0
}

# A refusal from inside the notes layer: the half-written plan goes, so nothing can
# stage from it, and the standard refusal line is printed.
notes_abort() { # REASON
  notes_relock
  rm -f "$state/.sentinel"
  for na_f in plan.tsv notes.tsv groups.tsv adapt.tsv transaction.txt meta; do
    rm -f "$state/$na_f"
  done
  abort_plan "$1"
}

nt_split() { # COMMA-LIST : one item per line, nothing for `-` or empty
  case ${1:-} in ''|-) return 0;; esac
  printf '%s\n' "$1" | tr ',' '\n'
}

nt_in() { # FILE ID : 0 when ID is the first column of a row of FILE
  awk -F'\t' -v id="$2" '$1 == id { f = 1; exit } END { exit f ? 0 : 1 }' "$1"
}

nt_led_get() { # ID FIELD(outcome|blob) -> the last ledger row's value, nothing when none
  awk -F'\t' -v id="$1" -v f="$2" '$1 == id { o = $2; b = $3; h = 1 } END { if (h) print (f == "blob" ? b : o) }' "$NT_LED"
}

nt_class() { # LOCALPATH -> its plan.tsv class, nothing when there is no row
  awk -F'\t' -v p="$1" '$1 == p { print $2; exit }' "$state/plan.tsv"
}

nt_rows() { # FM KEY -> `path TAB channel` per list item
  ul_fm_list "$1" "$2" | while IFS= read -r nt_r; do
    [ -n "$nt_r" ] && ul_touch_split "$nt_r"
  done
  return 0
}

# FM KEY : NT_LIST = the channel-filtered paths, comma-joined; NT_BAD = the first path
# the updater must never touch (or an unsafe one), if any.
nt_scan_rows() {
  NT_LIST=
  NT_BAD=
  nt_sr=$(ul_mktemp) || exit 1
  nt_rows "$1" "$2" > "$nt_sr"
  while IFS=$ul__tab read -r nt_sp nt_sc <&4; do
    [ -n "$nt_sp" ] || continue
    case /$nt_sp/ in
      //*|*/../*|*/./*|*//*) [ -n "$NT_BAD" ] || NT_BAD=$nt_sp;;
    esac
    if ul_path_forbidden "$nt_sp"; then [ -n "$NT_BAD" ] || NT_BAD=$nt_sp; fi
    case $nt_sc in
      @both|"@$CHANNEL") NT_LIST=${NT_LIST:+$NT_LIST,}$nt_sp;;
    esac
  done 4< "$nt_sr"
  return 0
}

# Every <release>/<id>.md in upstream's tree -> state/notes/ and NT_WORK, one row of
# `id rel safety touches adds removes requires check project-data blob` per note
# (`-` for an empty list). A note the linter would reject refuses the whole plan.
notes_collect() {
  nc_l=$(ul_mktemp) || exit 1
  git -c core.quotepath=off -C "$root" ls-tree -r --name-only "$PL_UP" -- "$UL_NOTES_DIR" 2>/dev/null | LC_ALL=C sort > "$nc_l"
  NT_WORK=$(ul_mktemp) || exit 1
  : > "$NT_WORK"
  mkdir -p "$state/notes" || { echo "error could not create $state/notes"; exit 1; }
  while IFS= read -r nc_p <&3; do
    case $nc_p in
      "$UL_NOTES_DIR"/*/*.md) ;;
      *) continue;;
    esac
    nc_rest=${nc_p#"$UL_NOTES_DIR"/}
    case $nc_rest in */*/*) continue;; esac
    nc_rel=${nc_rest%%/*}
    nc_stem=${nc_rest#*/}
    nc_stem=${nc_stem%.md}
    case $nc_stem in
      ''|.*|*[!A-Za-z0-9._-]*) notes_abort "note $nc_stem is malformed: the file name is not a plain id";;
    esac
    nc_f=$state/notes/$nc_stem.md
    if ! git -C "$root" show "$PL_UP:$nc_p" > "$nc_f" 2>/dev/null; then
      notes_abort "note $nc_stem is malformed: it could not be read from upstream"
    fi
    nc_fm=$(ul_frontmatter "$nc_f")
    case $nc_fm in
      NOFRONT|'') notes_abort "note $nc_stem is malformed: it has no frontmatter";;
    esac
    nc_id=$(ul_strip_quotes "$(ul_fm_scalar "$nc_fm" id)")
    [ -n "$nc_id" ] || notes_abort "note $nc_stem is malformed: it has no id"
    [ "$nc_id" = "$nc_stem" ] || notes_abort "note $nc_stem is malformed: its id ($nc_id) differs from the file name"
    [ -n "$(ul_fm_scalar "$nc_fm" title)" ] || notes_abort "note $nc_id is malformed: it has no title"
    [ -n "$(ul_fm_scalar "$nc_fm" purpose)" ] || notes_abort "note $nc_id is malformed: it has no purpose"
    nc_sf=$(ul_strip_quotes "$(ul_fm_scalar "$nc_fm" safety)")
    case $nc_sf in
      true|false) ;;
      '') notes_abort "note $nc_id is malformed: it has no safety";;
      *) notes_abort "note $nc_id is malformed: safety must be true or false";;
    esac
    if nt_in "$NT_WORK" "$nc_id"; then notes_abort "note $nc_id is malformed: the id appears twice"; fi
    nt_scan_rows "$nc_fm" touches
    [ -z "$NT_BAD" ] || notes_abort "note $nc_id is malformed: it touches $NT_BAD, which the updater never changes"
    nc_t=${NT_LIST:--}
    nt_scan_rows "$nc_fm" adds
    [ -z "$NT_BAD" ] || notes_abort "note $nc_id is malformed: it adds $NT_BAD, which the updater never changes"
    nc_a=${NT_LIST:--}
    nt_scan_rows "$nc_fm" removes
    [ -z "$NT_BAD" ] || notes_abort "note $nc_id is malformed: it removes $NT_BAD, which the updater never changes"
    nc_r=${NT_LIST:--}
    nc_q=$(ul_fm_list "$nc_fm" requires | tr '\n' ',' | sed 's/,$//')
    [ -n "$nc_q" ] || nc_q=-
    nc_c=$(ul_strip_quotes "$(ul_fm_scalar "$nc_fm" check)")
    [ -n "$nc_c" ] || nc_c=none
    nc_d=$(ul_strip_quotes "$(ul_fm_scalar "$nc_fm" project-data)")
    [ "$nc_d" = true ] || nc_d=false
    if [ "$nc_c" != none ]; then
      case $nc_c in
        */*|.*|*[!A-Za-z0-9._-]*) notes_abort "note $nc_id is malformed: the check must be a plain file name";;
      esac
      if ! git -C "$root" show "$PL_UP:$UL_NOTES_DIR/$nc_rel/$nc_c" > "$state/notes/$nc_id.check.sh" 2>/dev/null; then
        rm -f "$state/notes/$nc_id.check.sh"
        notes_abort "note $nc_id is malformed: its check $nc_c is missing upstream"
      fi
    fi
    nc_b=$(git -C "$root" rev-parse -q --verify "$PL_UP:$nc_p" 2>/dev/null) || nc_b=-
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$nc_id" "$nc_rel" "$nc_sf" "$nc_t" "$nc_a" "$nc_r" "$nc_q" "$nc_c" "$nc_d" "$nc_b" >> "$NT_WORK"
  done 3< "$nc_l"
  return 0
}

# ------------------------------------------------- check-script write DETECTION
# A note's check is shell that the updater runs. This is DETECTION plus permission
# hardening, NOT a sandbox: a check runs as the user, so it can still chmod a path back
# and then write to it, or write anywhere outside the places watched here -- the
# hardening only turns an ACCIDENTAL delete or overwrite into a failure, and the
# detection reports a deliberate one after the fact. Around every check (plan, stage and
# finish) the engine
#   - makes state/mine/ (the customer's backups) and last-smoke.log read-only, and
#     restores them when the check returns, on every exit path (the EXIT trap, which INT
#     and TERM reach; only SIGKILL leaves them read-only, and the next heal restores them);
#   - takes a snapshot of (a) the live repository as git sees it (HEAD plus
#     `git status --porcelain=v1 -uall`, tracked and untracked changes) plus a content
#     fingerprint (cksum and size) of every untracked, non-ignored file, so an in-place
#     overwrite that leaves the status line unchanged is seen, and (b) the updater's own
#     state directory (an `ls -ld` listing, every path newer than a sentinel, and a
#     fingerprint of every file), except export/ and wt/, which the callers already watch.
# Any difference aborts the caller with the first changed path in CG_W. A check that
# rewrites a tracked file with identical status, or touches a path outside these two
# places, is not seen. A file over 32 MiB is fingerprinted by size alone.
CG_LB=; CG_SB=; CG_SENT=; CG_W=; CG_LOCKED=0

cg_fp() { # FILE LABEL : one `LABEL cksum size path` line for a regular file
  [ -f "$1" ] && [ ! -L "$1" ] || return 0
  cf_n=$(wc -c < "$1" 2>/dev/null | tr -d ' \t')
  if [ "${cf_n:-0}" -gt 33554432 ] 2>/dev/null; then
    cf_c=big
  else
    cf_c=$(cksum < "$1" 2>/dev/null | awk '{ print $1 "-" $2 }')
  fi
  printf '%s %s %s %s\n' "$2" "${cf_c:-unreadable}" "${cf_n:-?}" "$1"
}

cg_lock() { # read-only for the customer's backups and the smoke log while a check runs
  if [ -d "$state/mine" ] && [ ! -L "$state/mine" ]; then chmod -R a-w "$state/mine" 2>/dev/null; fi
  if [ -f "$state/last-smoke.log" ] && [ ! -L "$state/last-smoke.log" ]; then chmod a-w "$state/last-smoke.log" 2>/dev/null; fi
  CG_LOCKED=1
}

cg_unlock() { # idempotent; also called from the EXIT trap and from heal_stale (force)
  if [ "${CG_LOCKED:-0}" = 1 ] || [ "${1:-}" = force ]; then
    if [ -d "$state/mine" ] && [ ! -L "$state/mine" ]; then chmod -R u+w "$state/mine" 2>/dev/null; fi
    if [ -f "$state/last-smoke.log" ] && [ ! -L "$state/last-smoke.log" ]; then chmod u+w "$state/last-smoke.log" 2>/dev/null; fi
    CG_LOCKED=0
  fi
  return 0
}

cg_live() {
  printf 'L HEAD %s\n' "$(git -C "$root" rev-parse HEAD 2>&1)"
  git -C "$root" status --porcelain=v1 -uall 2>&1 | sed 's/^/L /'
  git -C "$root" -c core.quotepath=off ls-files -o --exclude-standard 2>/dev/null | sed -n '1,5000p' | while IFS= read -r cl_p; do
    cg_fp "$root/$cl_p" U
  done
}

cg_state() {
  find "$state" \( -path "$state/export" -o -path "$state/wt" \) -prune -o -exec ls -ld {} + 2>/dev/null | LC_ALL=C sort | sed 's/^/S /'
  find "$state" \( -path "$state/export" -o -path "$state/wt" \) -prune -o -newer "$CG_SENT" -print 2>/dev/null | LC_ALL=C sort | sed 's/^/N /'
  find "$state" \( -path "$state/export" -o -path "$state/wt" \) -prune -o -type f -print 2>/dev/null | LC_ALL=C sort | sed -n '1,5000p' | while IFS= read -r cs_p; do
    cg_fp "$cs_p" F
  done
}

cg_begin() {
  CG_LB=$(ul_mktemp) || exit 1
  CG_SB=$(ul_mktemp) || exit 1
  CG_SENT=$(ul_mktemp) || exit 1
  cg_lock
  cg_live > "$CG_LB"
  : > "$CG_SENT"
  cg_state > "$CG_SB"
}

cg_end() { # sets CG_W (empty when nothing changed)
  CG_W=
  ce_a=$(ul_mktemp) || exit 1
  ce_b=$(ul_mktemp) || exit 1
  cg_live > "$ce_a"
  cg_state > "$ce_b"
  cg_unlock
  ce_d=$({ LC_ALL=C diff "$CG_LB" "$ce_a"; LC_ALL=C diff "$CG_SB" "$ce_b"; } | sed -n 's/^[<>] //p' | sed -n '1p')
  [ -n "$ce_d" ] || return 0
  case $ce_d in
    'L HEAD '*) CG_W=HEAD;;
    'L '*) ce_p=${ce_d#L ???}; CG_W=$ce_p;;
    'U '*) ce_p=$(printf '%s\n' "${ce_d#U }" | awk '{ sub(/^[^ ]+ [^ ]+ /, ""); print }'); CG_W=${ce_p#"$root"/};;
    'F '*) ce_p=$(printf '%s\n' "${ce_d#F }" | awk '{ sub(/^[^ ]+ [^ ]+ /, ""); print }'); CG_W=loom/update${ce_p#"$state"};;
    'N '*) ce_p=${ce_d#N }; CG_W=loom/update${ce_p#"$state"};;
    'S '*) ce_p=$(printf '%s\n' "${ce_d#S }" | awk '{ for (i = 1; i <= 8; i++) sub(/^[ \t]*[^ \t]+/, ""); sub(/^[ \t]+/, ""); print }'); CG_W=loom/update${ce_p#"$state"};;
    *) CG_W=$ce_d;;
  esac
  [ -n "$CG_W" ] || CG_W=unknown
  return 0
}

# Runs every note's check against the export, one at a time. The export is made
# writable only for this loop so that a write is DETECTED (a new, removed or newer
# path, or a changed ref) rather than merely failing; it is locked again after.
# NT_CK gets `id TAB exit TAB class` (class pass|skip|fail|none); checks.log gets
# `<id> exit=<n> last=<last line>`.
notes_run_checks() {
  NT_CK=$(ul_mktemp) || exit 1
  : > "$NT_CK"
  : > "$state/checks.log"
  nk_b=$(ul_mktemp) || exit 1
  nk_a=$(ul_mktemp) || exit 1
  nk_nb=$(ul_mktemp) || exit 1
  nk_na=$(ul_mktemp) || exit 1
  chmod -R u+w "$state/export" 2>/dev/null
  while IFS=$ul__tab read -r nk_id nk_rel nk_sf nk_t nk_ad nk_rm nk_rq nk_c nk_d nk_blob <&3; do
    if [ "$nk_c" = none ]; then
      printf '%s\t-\tnone\n' "$nk_id" >> "$NT_CK"
      continue
    fi
    find "$state/export" 2>/dev/null | LC_ALL=C sort > "$nk_b"
    nk_rb=$(git -C "$root" for-each-ref 2>/dev/null)
    : > "$state/.sentinel"
    find "$state/export" -newer "$state/.sentinel" 2>/dev/null | LC_ALL=C sort > "$nk_nb"
    cg_begin
    nk_out=$(cd "$state/export" && REPO_ROOT="$state/export" UPDATE_TOOLS="$state/tools" sh "$state/notes/$nk_id.check.sh" </dev/null 2>/dev/null)
    nk_rc=$?
    cg_end
    find "$state/export" 2>/dev/null | LC_ALL=C sort > "$nk_a"
    find "$state/export" -newer "$state/.sentinel" 2>/dev/null | LC_ALL=C sort > "$nk_na"
    nk_ra=$(git -C "$root" for-each-ref 2>/dev/null)
    nk_last=${nk_out##*"$ul__nl"}
    printf '%s exit=%s last=%s\n' "$nk_id" "$nk_rc" "$nk_last" >> "$state/checks.log"
    nk_w=$(LC_ALL=C comm -13 "$nk_b" "$nk_a" | sed -n '1p')
    [ -n "$nk_w" ] || nk_w=$(LC_ALL=C comm -23 "$nk_b" "$nk_a" | sed -n '1p')
    [ -n "$nk_w" ] || nk_w=$(LC_ALL=C comm -13 "$nk_nb" "$nk_na" | sed -n '1p')
    if [ -n "$nk_w" ]; then
      nk_w=${nk_w#"$state/export"}
      nk_w=${nk_w#/}
      [ -n "$nk_w" ] || nk_w=.
      notes_abort "check $nk_id wrote $nk_w (check-wrote=$nk_w)"
    fi
    if [ "$nk_rb" != "$nk_ra" ]; then
      notes_abort "check $nk_id changed a git ref (check-wrote=refs)"
    fi
    if [ -n "$CG_W" ]; then
      notes_abort "check $nk_id wrote $CG_W outside the export (check-wrote=$CG_W)"
    fi
    nk_cl=fail
    if [ "$nk_rc" -eq 0 ]; then
      case $nk_last in skip=*) nk_cl=skip;; *) nk_cl=pass;; esac
    fi
    printf '%s\t%s\t%s\n' "$nk_id" "$nk_rc" "$nk_cl" >> "$NT_CK"
  done 3< "$NT_WORK"
  rm -f "$state/.sentinel"
  notes_relock
  return 0
}

# The offering rule (design 1.5). NT_OFF rows are the NT_WORK fields plus
# offer declined-before snoozed check-class. Order of tests: (a) no ledger row,
# (c) held, (b) the check fails and the row is not declined-final.
notes_offer() {
  NT_OFF=$(ul_mktemp) || exit 1
  : > "$NT_OFF"
  while IFS=$ul__tab read -r no_id no_rel no_sf no_t no_ad no_rm no_rq no_c no_d no_blob <&3; do
    no_lo=$(nt_led_get "$no_id" outcome)
    no_lb=$(nt_led_get "$no_id" blob)
    no_cl=$(awk -F'\t' -v id="$no_id" '$1 == id { print $3; exit }' "$NT_CK")
    no_off=
    if ! awk -F'\t' -v id="$no_id" '$1 == id { f = 1; exit } END { exit f ? 0 : 1 }' "$NT_LED"; then
      no_off=a
    elif [ "$no_lo" = held ]; then
      no_off=c
    elif [ "$no_cl" = fail ] && [ "$no_lo" != declined-final ]; then
      no_off=b
    fi
    [ -n "$no_off" ] || continue
    no_dc=no
    no_sn=no
    if [ "$no_off" = b ] && [ "$no_lo" = declined ]; then
      no_dc=yes
      if [ "$no_blob" = "$no_lb" ] && [ "$OPT_REVISIT" != 1 ]; then no_sn=yes; fi
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$no_id" "$no_rel" "$no_sf" "$no_t" "$no_ad" "$no_rm" "$no_rq" "$no_c" "$no_d" "$no_blob" "$no_off" "$no_dc" "$no_sn" "$no_cl" >> "$NT_OFF"
  done 3< "$NT_WORK"
  return 0
}

# Kahn's algorithm over `requires` among the offered notes; ties by release folder,
# then id. A cycle refuses the plan. NT_ORD = NT_OFF in that order.
notes_order() {
  NT_ORD=$(ul_mktemp) || exit 1
  LC_ALL=C awk -F'\t' '
    { n++; line[n] = $0; id[n] = $1; key[n] = $2 "\t" $1; idx[$1] = n; req[n] = $7 }
    END {
      for (i = 1; i <= n; i++) {
        nd[i] = 0
        if (req[i] != "-") {
          m = split(req[i], r, ",")
          for (k = 1; k <= m; k++) if (r[k] in idx) { nd[i]++; dep[i, nd[i]] = idx[r[k]] }
        }
      }
      for (s = 1; s <= n; s++) {
        best = 0
        for (i = 1; i <= n; i++) {
          if (fin[i]) continue
          ok = 1
          for (k = 1; k <= nd[i]; k++) if (!fin[dep[i, k]]) { ok = 0; break }
          if (ok && (best == 0 || key[i] < key[best])) best = i
        }
        if (best == 0) {
          rest = ""
          for (i = 1; i <= n; i++) if (!fin[i]) rest = rest (rest == "" ? "" : ",") id[i]
          print "CYCLE\t" rest
          exit
        }
        fin[best] = 1
        print line[best]
      }
    }' "$NT_OFF" > "$NT_ORD"
  no_cy=$(sed -n 's/^CYCLE	//p' "$NT_ORD" | sed -n '1p')
  if [ -n "$no_cy" ]; then notes_abort "the notes require each other in a cycle: $no_cy"; fi
  return 0
}

# NT_BLK = `id TAB blocker|-`. The first `requires` id whose last ledger outcome is
# declined, declined-final or held; or which is itself blocked (transitive); or which
# is in upstream's tree, not offered and not applied or acknowledged.
notes_blocked() {
  NT_BLK=$(ul_mktemp) || exit 1
  : > "$NT_BLK"
  nb_rq=$(ul_mktemp) || exit 1
  while IFS=$ul__tab read -r nb_id nb_rest <&3; do
    nb_b=-
    nb_q=$(awk -F'\t' -v id="$nb_id" '$1 == id { print $7; exit }' "$NT_ORD")
    nt_split "$nb_q" > "$nb_rq"
    while IFS= read -r nb_r <&4; do
      nb_lo=$(nt_led_get "$nb_r" outcome)
      case $nb_lo in
        declined|declined-final|held) nb_b=$nb_r; break;;
      esac
      if nt_in "$NT_ORD" "$nb_r"; then
        nb_rb=$(awk -F'\t' -v id="$nb_r" '$1 == id { print $2; exit }' "$NT_BLK")
        if [ -n "$nb_rb" ] && [ "$nb_rb" != - ]; then nb_b=$nb_r; break; fi
      elif nt_in "$NT_WORK" "$nb_r"; then
        case $nb_lo in
          applied|acknowledged) ;;
          *) nb_b=$nb_r; break;;
        esac
      fi
    done 4< "$nb_rq"
    printf '%s\t%s\n' "$nb_id" "$nb_b" >> "$NT_BLK"
  done 3< "$NT_ORD"
  NT_B=$(awk -F'\t' '$2 != "-" { n++ } END { print n + 0 }' "$NT_BLK")
  return 0
}

# NT_PM = `local-path TAB id TAB kind` for every path an offered note names; kind is
# ta (touches or adds) or r (removes). The path is translated to this copy's name.
notes_pathmap() {
  NT_PM=$(ul_mktemp) || exit 1
  : > "$NT_PM"
  np_l=$(ul_mktemp) || exit 1
  while IFS=$ul__tab read -r np_id np_rel np_sf np_t np_ad np_rm np_rest <&3; do
    for np_k in t a r; do
      case $np_k in t) np_v=$np_t;; a) np_v=$np_ad;; r) np_v=$np_rm;; esac
      nt_split "$np_v" > "$np_l"
      while IFS= read -r np_p <&4; do
        [ -n "$np_p" ] || continue
        np_lp=$(local_path_for "$np_p")
        if [ "$np_k" = r ]; then np_kind=r; else np_kind=ta; fi
        printf '%s\t%s\t%s\n' "$np_lp" "$np_id" "$np_kind" >> "$NT_PM"
      done 4< "$np_l"
    done
  done 3< "$NT_ORD"
  return 0
}

# Two-way rows (design 1.5, last paragraph). For each offered note and each touches
# path: a customer-changed (`keep`) path whose check FAILED; for a project-data note,
# the customer's file when it exists and its check did not pass (never when the file
# is absent: nothing to adapt, the note is only acknowledged).
notes_twoway() {
  nw_l=$(ul_mktemp) || exit 1
  while IFS=$ul__tab read -r nw_id nw_rel nw_sf nw_t nw_ad nw_rm nw_rq nw_c nw_d nw_blob nw_off nw_dc nw_sn nw_cl <&3; do
    nt_split "$nw_t" > "$nw_l"
    while IFS= read -r nw_p <&4; do
      [ -n "$nw_p" ] || continue
      nw_lp=$(local_path_for "$nw_p")
      nw_cls=$(nt_class "$nw_lp")
      if [ "$nw_d" = true ]; then
        set -- $(entry_at HEAD "$nw_lp")
        [ "$1" != - ] || continue
        case $nw_cl in fail|none) ;; *) continue;; esac
        case $nw_cls in ''|keep|two-way) write_two_way_row "$nw_p";; esac
      else
        if [ "$nw_cls" = keep ] && [ "$nw_cl" = fail ]; then write_two_way_row "$nw_p"; fi
      fi
    done 4< "$nw_l"
  done 3< "$NT_ORD"
  return 0
}

# NU : yes when the customer never changed any touches or adds path of the note.
notes_untouched() { # TOUCHES ADDS
  NT_U=yes
  nu_l=$(ul_mktemp) || exit 1
  { nt_split "$1"; nt_split "$2"; } > "$nu_l"
  while IFS= read -r nu_p <&4; do
    [ -n "$nu_p" ] || continue
    nu_cls=$(nt_class "$(local_path_for "$nu_p")")
    case $nu_cls in
      ''|add|take|mode) ;;
      *) NT_U=no; break;;
    esac
  done 4< "$nu_l"
  return 0
}

# Overlap groups: union-find over the paths each offered note names. Groups are numbered
# by their smallest path (C order), a note with no paths after them. Plan rows no
# offered note covers form one more group whose only member is the pseudo-id _unnoted.
notes_groups() {
  NT_GRP=$(ul_mktemp) || exit 1
  LC_ALL=C awk -F'\t' '
    { n++; id[n] = $1; par[n] = n
      for (f = 4; f <= 6; f++) {
        if ($f == "-") continue
        m = split($f, a, ",")
        for (k = 1; k <= m; k++) {
          p = a[k]
          if (p in owner) {
            x = owner[p]; while (par[x] != x) x = par[x]
            y = n; while (par[y] != y) y = par[y]
            if (x != y) par[y] = x
          } else owner[p] = n
          pp[++np] = p
        }
      }
    }
    END {
      for (i = 1; i <= n; i++) { x = i; while (par[x] != x) x = par[x]; root[i] = x }
      for (j = 1; j <= np; j++) { r = root[owner[pp[j]]]; if (!(r in minp) || pp[j] < minp[r]) minp[r] = pp[j] }
      nr = 0
      for (i = 1; i <= n; i++) {
        r = root[i]
        if (!(r in seen)) { seen[r] = 1; roots[++nr] = r; key[r] = (r in minp) ? minp[r] : "~~~~" id[i] }
      }
      for (a1 = 2; a1 <= nr; a1++) {
        v = roots[a1]; b1 = a1 - 1
        while (b1 >= 1 && key[roots[b1]] > key[v]) { roots[b1 + 1] = roots[b1]; b1-- }
        roots[b1 + 1] = v
      }
      for (g = 1; g <= nr; g++) num[roots[g]] = g
      for (i = 1; i <= n; i++) printf "%s\tg%d\n", id[i], num[root[i]]
    }' "$NT_ORD" > "$NT_GRP"
  awk -F'\t' '
    { if (!($2 in ids)) { ord[++n] = $2 }
      ids[$2] = ids[$2] (ids[$2] == "" ? "" : ",") $1 }
    END { for (g = 1; g <= n; g++) { k = "g" g; print k "\t" ids[k] } }' "$NT_GRP" > "$state/groups.tsv"
  NT_G=$(awk 'END { print NR + 0 }' "$state/groups.tsv")
  # plan rows nothing covers (the notes tree and the engine are upstream-owned and left out)
  ng_un=$(awk -F'\t' '
    FNR == NR { covered[$1] = 1; next }
    $4 == "upstream-owned" { next }
    $2 ~ /^(take|add|delete|merged-clean|mode|conflict|add-conflict|deleted-upstream-kept|posture)$/ && !($1 in covered) { n++ }
    END { print n + 0 }' "$NT_PM" "$state/plan.tsv")
  if [ "$ng_un" -gt 0 ]; then
    NT_G=$((NT_G + 1))
    printf 'g%s\t_unnoted\n' "$NT_G" >> "$state/groups.tsv"
  fi
  return 0
}

notes_layer() {
  notes_collect
  nl_led=$(ledger_rows)
  NT_LED=$(ul_mktemp) || exit 1
  printf '%s\n' "$nl_led" | awk -F'\t' 'NF >= 2 { print $1 "\t" $2 "\t" $3 }' > "$NT_LED"
  notes_run_checks
  notes_offer
  notes_order
  NT_N=$(awk 'END { print NR + 0 }' "$NT_ORD")
  notes_blocked
  notes_pathmap
  notes_twoway

  nl_j=$(awk -F'\t' '$3 == "hold" && $1 ~ /[.]json$/ { print $1; exit }' "$state/plan.tsv")
  if [ -n "$nl_j" ] && [ ! -s "$state/tools/json-valid.sh" ]; then
    notes_abort "upstream ships no json-valid.sh, so the held JSON file $nl_j cannot be checked"
  fi

  notes_groups
  : > "$state/notes.tsv"
  while IFS=$ul__tab read -r nl_id nl_rel nl_sf nl_t nl_ad nl_rm nl_rq nl_c nl_d nl_blob nl_off nl_dc nl_sn nl_cl <&3; do
    nl_b=$(awk -F'\t' -v id="$nl_id" '$1 == id { print $2; exit }' "$NT_BLK")
    nl_g=$(awk -F'\t' -v id="$nl_id" '$1 == id { print $2; exit }' "$NT_GRP")
    notes_untouched "$nl_t" "$nl_ad"
    printf '%s\tnotes/%s.md\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$nl_id" "$nl_id" "$nl_sf" "$nl_t" "${nl_b:--}" "$nl_dc" "$nl_g" "$NT_U" "$nl_d" "$nl_c" "$nl_off" "$nl_sn" >> "$state/notes.tsv"
  done 3< "$NT_ORD"

  # note ids on every adapt.tsv row
  nl_t2=$(ul_mktemp) || exit 1
  awk -F'\t' -v OFS='\t' '
    FNR == NR { if ($3 == "ta" && !(($1, $2) in seen)) { seen[$1, $2] = 1; ids[$1] = ids[$1] (ids[$1] == "" ? "" : ",") $2 } next }
    { $2 = ($1 in ids) ? ids[$1] : "-"; print }' "$NT_PM" "$state/adapt.tsv" > "$nl_t2"
  cp "$nl_t2" "$state/adapt.tsv"

  NT_T=$(awk -F'\t' '$2 == "two-way" { n++ } END { print n + 0 }' "$state/plan.tsv")

  # what --stage will do, in plain lines the skill reads back to the customer
  {
    printf 'tag loom/pre-update-%s\n' "$(date -u +%Y%m%d-%H%M%S)"
    printf 'worktree add --detach %s/wt HEAD\n' "$state"
    printf 'commit "LogicLoom update to %s"\n' "$(printf '%s' "$PL_UP" | cut -c1-12)"
    printf 'then: git merge --ff-only <staged sha> (you approve this)\n'
    awk -F'\t' '$3 == "apply" || $3 == "hold" { print "write " $1 }' "$state/plan.tsv"
    awk -F'\t' '{ print "ledger " $1 }' "$NT_ORD"
  } > "$state/transaction.txt"
  return 0
}

# Classification is done: plan.tsv and adapt.tsv are complete and sorted, and the
# state directory holds the sides. The notes layer (above) goes here.
plan_after_classify() {
  notes_layer
  return 0
}

# Everything --plan rebuilds. Nothing else under the state directory is touched: the
# customer's backups (mine/<update-id>/), the stage lock, the throwaway worktree, the
# staged marker and the last smoke log outlive a re-plan.
plan_reset_state() {
  state_dir_safe || { echo "error refusing to rebuild a state directory that is unexpected or is, or sits under, a symlink"; exit 1; }
  mkdir -p "$state" || { echo "error could not create $state"; exit 1; }
  for prs_f in plan.tsv meta notes.tsv groups.tsv adapt.tsv adapted.tsv unresolved.tsv transaction.txt checks.log; do
    rm -f "$state/$prs_f"
  done
  for prs_d in notes adapt merged diffs reviewer export tools unresolved; do
    if [ -e "$state/$prs_d" ]; then
      chmod -R u+w "$state/$prs_d" 2>/dev/null
      rm -rf "$state/$prs_d"
    fi
  done
  mkdir -p "$state/diffs" "$state/merged" "$state/reviewer" "$state/adapt" "$state/tools" || { echo "error could not create $state"; exit 1; }
  : > "$state/plan.tsv"
  : > "$state/adapt.tsv"
}

plan_universe() { # -> state-independent temp file of `path bm bs hm hs um us` rows, sorted
  pu_b=$(ul_mktemp) || exit 1
  pu_h=$(ul_mktemp) || exit 1
  pu_u=$(ul_mktemp) || exit 1
  pu_t=$(ul_mktemp) || exit 1
  git -c core.quotepath=off -C "$root" ls-tree -r "$PL_BASE" > "$pu_b" 2>/dev/null || { echo "error could not list the base tree"; exit 1; }
  git -c core.quotepath=off -C "$root" ls-tree -r HEAD > "$pu_h" 2>/dev/null || { echo "error could not list HEAD"; exit 1; }
  git -c core.quotepath=off -C "$root" ls-tree -r "$PL_UP" > "$pu_u" 2>/dev/null || { echo "error could not list upstream"; exit 1; }
  awk -F'\t' -v SYNC="$UL_SYNC_REF" -v B="$pu_b" -v H="$pu_h" '
    # three listings: base, HEAD, upstream. A listing line is
    # `<mode> <type> <sha>TAB<path>`; the path is everything after the first tab.
    {
      tag = (FILENAME == B) ? "b" : ((FILENAME == H) ? "h" : "u")
      i = index($0, "\t"); if (i == 0) next
      n = split(substr($0, 1, i - 1), a, " ")
      path = substr($0, i + 1)
      if (n < 3 || (a[2] != "blob" && a[2] != "commit")) next
      mode[tag, path] = a[1]; sha[tag, path] = a[3]; seen[path] = 1
    }
    END {
      for (p in seen) {
        if (index(p, "\t") || p == SYNC) continue
        printf "%s", p
        for (k = 1; k <= 3; k++) {
          t = substr("bhu", k, 1)
          printf "\t%s\t%s", ((t, p) in mode) ? mode[t, p] : "-", ((t, p) in sha) ? sha[t, p] : "-"
        }
        printf "\n"
      }
    }' "$pu_b" "$pu_h" "$pu_u" | LC_ALL=C sort -t "$ul__tab" -k1,1 > "$pu_t"
  # drop what the customer's own ignore rules cover -- except the notes tree and the
  # engine's scripts, which are upstream-owned whatever the customer ignores
  pu_i=$(ul_mktemp) || exit 1
  pu_p=$(ul_mktemp) || exit 1
  cut -f1 "$pu_t" > "$pu_p"
  git -c core.quotepath=off -C "$root" check-ignore --stdin < "$pu_p" > "$pu_i" 2>/dev/null
  pu_rc=$?
  if [ "$pu_rc" -gt 1 ]; then
    # one bad path (beyond a symlink, say) fails the whole batch: ask one path at a time
    : > "$pu_i"
    while IFS= read -r pu_x; do
      if git -C "$root" check-ignore -q -- "$pu_x" 2>/dev/null; then printf '%s\n' "$pu_x" >> "$pu_i"; fi
    done < "$pu_p"
  fi
  PU_OUT=$(ul_mktemp) || exit 1
  awk -F'\t' -v IGN="$pu_i" -v ND="$UL_NOTES_DIR/" -v SD="$UL_SCRIPTS_DIR/" '
    BEGIN { while ((getline l < IGN) > 0) ig[l] = 1 }
    ($1 in ig) && index($1, ND) != 1 && index($1, SD) != 1 { next }
    { print }' "$pu_t" > "$PU_OUT"
}

cmd_plan() {
  # ---- refusals, in the documented order: nothing has been touched
  resolve_channel
  channel_map_load
  pl_off=$(clean_offenders)
  if [ -n "$pl_off" ]; then
    if status_failed "$pl_off"; then abort_plan "git status failed in this repository"; fi
    abort_plan "your working tree has uncommitted changes: $(offender_paths "$pl_off")"
  fi
  if in_progress; then abort_plan "a merge, rebase, cherry-pick or revert is unfinished; finish or abort it first"; fi
  if is_shallow; then abort_plan "run git fetch --unshallow first"; fi
  if [ "$CH" = ambiguous ] && [ -z "$OPT_CHANNEL" ]; then
    pl_n=${CH_NOTICE:-this copy looks like both a template clone and an adopted install}
    abort_plan "the channel is ambiguous ($pl_n); run again with --channel template or --channel adopted"
  fi
  state_dir_safe || abort_plan "the update state directory (.git/loom/update) is, or sits under, a symlink; refusing to use it"
  if ! heal_stale; then abort_plan "another update is staging (pid $LOCK_LIVE)"; fi
  if [ -f "$state/staged" ]; then abort_plan "a staged update exists; run --finish or --abandon"; fi
  if [ "${LOOM_TEST_PAUSE_BEFORE_PLAN_LOCK:-}" = 1 ]; then
    # test-only: stop between the unlocked precondition reads and the lock, until
    # state/.test-go exists, so a case can finish a --stage in that window
    mkdir -p "$state"
    : > "$state/.test-plan-paused"
    pl_w=0
    while [ ! -e "$state/.test-go" ] && [ "$pl_w" -lt 60 ]; do sleep 1; pl_w=$((pl_w + 1)); done
    rm -f "$state/.test-plan-paused" "$state/.test-go"
  fi
  # the whole plan runs under the stage lock, so a --stage cannot start while the plan
  # replaces plan.tsv, notes and merged/ (the exit trap releases it)
  lock_acquire keep || abort_plan "another update is staging"
  # ---- every precondition read above was read WITHOUT the lock: a --stage or --finish, or
  # the customer, may have changed things since. Read the ones that matter again now; the
  # lock is released by the exit trap and nothing has been written yet.
  if [ -f "$state/staged" ]; then abort_plan "a staged update exists; run --finish or --abandon"; fi
  pl_off=$(clean_offenders)
  if [ -n "$pl_off" ]; then
    if status_failed "$pl_off"; then abort_plan "git status failed in this repository"; fi
    abort_plan "your working tree has uncommitted changes: $(offender_paths "$pl_off")"
  fi
  if in_progress; then abort_plan "a merge, rebase, cherry-pick or revert is unfinished; finish or abort it first"; fi

  # ---- fetch, then the three commits
  if ! fetch_upstream; then abort_plan "$FETCH_ERROR"; fi
  UPSTREAM_HEAD=$(upstream_head) || UPSTREAM_HEAD=
  [ -n "$UPSTREAM_HEAD" ] || abort_plan "upstream has no main branch"
  UL_MAP=            # upstream's own copy of the channel map is now the freshest
  channel_map_load
  detect_base_verdict
  set -- $db_verdict
  case ${1:-} in
    handover|recorded|remap) PL_BASE=${2:-}; PL_RUNG=$1;;
    closest)
      printf '%s\n' "$db_verdict"
      abort_plan "base unconfirmed; run --set-base ${2:-}";;
    *) abort_plan "the update pointer is missing or cannot be found in upstream's history; see KNOWN_ISSUES.md or run npx logicloom@7 update-bootstrap";;
  esac
  PL_UP=$UPSTREAM_HEAD
  PL_HEAD=$(git -C "$root" rev-parse HEAD 2>/dev/null) || { echo "error could not read HEAD"; exit 1; }
  plan_groups_load
  plan_maps_load
  PL_ADOPT_BASE_USED=0
  PL_SIDE_FAIL=0

  # ---- rebuild the derived state, then meta
  plan_reset_state
  pl_id="$(date -u +%Y%m%dT%H%M%SZ)-$(printf '%s' "$PL_UP" | cut -c1-12)"
  {
    printf 'base=%s\n' "$PL_BASE"
    printf 'base_rung=%s\n' "$PL_RUNG"
    printf 'upstream=%s\n' "$PL_UP"
    printf 'head=%s\n' "$PL_HEAD"
    printf 'channel=%s\n' "$CHANNEL"
    printf 'update_id=%s\n' "$pl_id"
    printf 'time=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [ "$OPT_REVISIT" = 1 ]; then printf 'revisit=yes\n'; fi
  } > "$state/meta"

  # ---- upstream's JSON tools, for the checks and --adapt-save
  pl_tools=saved
  for pl_t in json-valid.sh json-flat.sh; do
    if git -C "$root" show "$UL_UPSTREAM_REF:$UL_SCRIPTS_DIR/$pl_t" > "$state/tools/$pl_t" 2>/dev/null && [ -s "$state/tools/$pl_t" ]; then
      :
    else
      rm -f "$state/tools/$pl_t"
      pl_tools=absent
    fi
  done

  # ---- the read-only export of HEAD
  pl_tar=$(ul_mktemp) || exit 1
  if ! git -C "$root" archive --format=tar HEAD > "$pl_tar" 2>/dev/null; then
    echo "error could not export HEAD"; exit 1
  fi
  mkdir -p "$state/export" || { echo "error could not create the export directory"; exit 1; }
  if ! tar -xf "$pl_tar" -C "$state/export" 2>/dev/null; then
    echo "error could not unpack the export of HEAD"; exit 1
  fi
  chmod -R a-w "$state/export" 2>/dev/null

  # ---- classify
  plan_universe
  while IFS=$ul__tab read -r pl_p pl_bm pl_bs pl_hm pl_hs pl_um pl_us <&3; do
    [ -n "$pl_p" ] || continue
    process_path "$pl_p" "$pl_bm" "$pl_bs" "$pl_hm" "$pl_hs" "$pl_um" "$pl_us"
  done 3< "$PU_OUT"
  if [ "$PL_ADOPT_BASE_USED" = 1 ]; then printf 'base_side=adopt-settings\n' >> "$state/meta"; fi
  plan_after_classify

  # ---- report
  pl_rows=$(awk 'END { print NR + 0 }' "$state/plan.tsv")
  pl_pending=$(awk -F'\t' '$2 != "keep" && $2 != "excluded" && $2 != "adopter-owned" { n++ } END { print n + 0 }' "$state/plan.tsv")
  printf 'result=planned\n'
  printf 'channel=%s\n' "$CHANNEL"
  printf 'base=%s\n' "$PL_BASE"
  printf 'base_rung=%s\n' "$PL_RUNG"
  printf 'upstream=%s\n' "$PL_UP"
  printf 'head=%s\n' "$PL_HEAD"
  printf 'update_id=%s\n' "$pl_id"
  printf 'tools=%s\n' "$pl_tools"
  if [ "$PL_SIDE_FAIL" -gt 0 ]; then printf 'warning=%s side file(s) could not be saved\n' "$PL_SIDE_FAIL"; fi
  awk -F'\t' '{ c[$2]++ } END { for (k in c) print k "\t" c[k] }' "$state/plan.tsv" | LC_ALL=C sort | awk -F'\t' '{ print "class." $1 "=" $2 }'
  printf 'rows=%s\n' "$pl_rows"
  printf 'notes=%s groups=%s blocked=%s twoway=%s\n' "$NT_N" "$NT_G" "$NT_B" "$NT_T"
  printf 'plan=%s/plan.tsv\n' "$state"
  if [ "$pl_pending" -eq 0 ] && [ "$NT_N" -eq 0 ]; then printf 'uptodate=yes\n'; fi
  return 0
}

# ============================================== --adapt-save and --mark-unresolved
# The deterministic gate between the read-only adapter agent and the tree (design
# 1.10, 2.1, 2.2 steps 4 and 6). The skill hands a body file over; nothing reaches
# state/merged/ unless every refusal below passed and security-invariants.sh accepted
# it. A refusal prints ONE line `result=refused reason=<...>`, exits 1 and touches
# nothing. Both subcommands write only under the state directory.

as_refuse() { # REASON
  printf 'result=refused reason=%s\n' "$1"
  exit 1
}

# Refusals shared by both subcommands: a plan exists and is still current. The plan
# is stale when HEAD or the fetched upstream commit is no longer what --plan saw; no
# network is touched.
as_plan_current() {
  [ -f "$state/plan.tsv" ] && [ -f "$state/adapt.tsv" ] && [ -f "$state/meta" ] || as_refuse "no plan found; run --plan first"
  state_dir_safe || as_refuse "the update state directory is, or sits under, a symlink; refusing to use it"
  # both writers change state/merged, adapted.tsv and unresolved.tsv: hold the stage lock
  if ! heal_stale; then as_refuse "another update is staging (pid $LOCK_LIVE)"; fi
  lock_acquire keep >/dev/null || as_refuse "another update is staging"
  as_mh=$(meta_val head)
  as_mu=$(meta_val upstream)
  as_ch=$(git -C "$root" rev-parse HEAD 2>/dev/null) || as_ch=
  as_cu=$(upstream_head) || as_cu=
  if [ -z "$as_mh" ] || [ -z "$as_mu" ] || [ "$as_ch" != "$as_mh" ] || [ "$as_cu" != "$as_mu" ]; then
    as_refuse "the plan is stale (HEAD or upstream moved since --plan); run --plan again"
  fi
  CHANNEL=$(meta_val channel)
  channel_map_load
  plan_maps_load
  return 0
}

as_row_ids() { # PATH -> the note-ids column of its adapt.tsv row (empty when no row)
  awk -F'\t' -v p="$1" '$1 == p { print $2; exit }' "$state/adapt.tsv"
}

as_has_row() { # PATH
  awk -F'\t' -v p="$1" '$1 == p { f = 1; exit } END { exit f ? 0 : 1 }' "$state/adapt.tsv"
}

# The upstream name of a local path: the rename source when the adopted channel keeps
# the path under another name, else the path itself.
as_upstream_name() { # LOCALPATH
  as_un=$(renames | awk -F'\t' -v p="$1" '$2 == p { print $1; exit }')
  if [ -n "$as_un" ] && [ "$CHANNEL" = adopted ]; then printf '%s' "$as_un"; else printf '%s' "$1"; fi
}

# 0 when PATH is a symlink at HEAD or upstream, or when any component of it in the
# read-only export is one (a body written through such a path would land elsewhere).
as_symlink() { # PATH
  set -- $(entry_at HEAD "$1") "$1"
  as_hm=$1; as_p=$3
  [ "$as_hm" = 120000 ] && return 0
  set -- $(entry_at "$(meta_val upstream)" "$(as_upstream_name "$as_p")")
  [ "$1" = 120000 ] && return 0
  as_cur=$state/export
  as_rest=$as_p
  while [ -n "$as_rest" ]; do
    case $as_rest in
      */*) as_c=${as_rest%%/*}; as_rest=${as_rest#*/};;
      *) as_c=$as_rest; as_rest=;;
    esac
    [ -n "$as_c" ] || continue
    as_cur=$as_cur/$as_c
    [ -L "$as_cur" ] && return 0
  done
  return 1
}

as_note_fm() { # ID -> the note's frontmatter (the copy saved at plan time)
  ul_frontmatter "$state/notes/$1.md"
}

# The rules --surface selects (the same table as security-invariants.sh's header).
as_rules() { # PATH PROJECT-DATA(true|false)
  if [ "$2" = true ]; then printf 'R4'; return 0; fi
  case $1 in
    .claude/settings.json) printf 'R1,R2,R5';;
    .claude/policies/tool-restrictions.json) printf 'R2,R5';;
    .logic-loom/config/gate-policy.conf|.logic-loom/config/governance.conf) printf 'R2';;
    *.json) printf 'R5';;
    *.md) printf 'R3';;
    *) printf 'none';;
  esac
}

# The relaxes / removes / may-drop-headings inputs of security-invariants.sh for a
# comma list of note ids (`-` = none). Shared by --adapt-save and the --stage gate.
# Sets INV_RX INV_RM INV_MD (temp files), INV_PD (true|false) and INV_PAT; returns 1
# with INV_ERR set when a note file is missing from the plan state.
inv_inputs() { # NOTE-IDS
  INV_RX=$(ul_mktemp) || exit 1
  INV_RM=$(ul_mktemp) || exit 1
  INV_MD=$(ul_mktemp) || exit 1
  : > "$INV_RX"; : > "$INV_RM"; : > "$INV_MD"
  INV_PD=false
  INV_PAT=
  INV_ERR=
  [ "$1" != - ] || return 0
  iv_l=$(ul_mktemp) || exit 1
  nt_split "$1" > "$iv_l"
  while IFS= read -r iv_i <&5; do
    [ -n "$iv_i" ] || continue
    if [ ! -f "$state/notes/$iv_i.md" ]; then
      INV_ERR="the note file for $iv_i is missing from the plan state; run --plan again"
      return 1
    fi
    iv_fm=$(as_note_fm "$iv_i")
    ul_fm_list "$iv_fm" relaxes | awk -v tb="$ul__tab" '{ s = $0; gsub(/ :: /, tb, s); print s }' >> "$INV_RX"
    ul_fm_list "$iv_fm" removes | while IFS= read -r iv_r; do
      [ -n "$iv_r" ] || continue
      iv_rp=$(ul_touch_split "$iv_r" | cut -f1)
      local_path_for "$iv_rp"; printf '\n'
    done >> "$INV_RM"
    ul_fm_list "$iv_fm" may-drop-headings >> "$INV_MD"
    if [ "$(ul_fm_scalar "$iv_fm" project-data)" = true ]; then
      INV_PD=true
      if [ -z "$INV_PAT" ]; then INV_PAT=$(ul_strip_quotes "$(ul_fm_scalar "$iv_fm" pattern)"); fi
    fi
  done 5< "$iv_l"
  return 0
}

cmd_adapt_save() { # PATH BODYFILE NOTE-IDS
  if [ "$#" -ne 3 ]; then echo "error --adapt-save takes <path> <bodyfile> <note-ids>"; exit 2; fi
  as_path=$1; as_body=$2; as_ids=$3
  as_plan_current
  if [ ! -f "$as_body" ] || [ ! -r "$as_body" ]; then as_refuse "the body file is missing or unreadable: $as_body"; fi
  if [ ! -s "$as_body" ]; then as_refuse "the adapted body is empty"; fi
  as_has_row "$as_path" || as_refuse "$as_path is not a held or two-way path in the current plan"
  if ul_path_forbidden "$as_path"; then as_refuse "$as_path is in the forbidden set; an update never touches it"; fi
  if as_symlink "$as_path"; then as_refuse "$as_path is a symlink, or sits under one; an adapted body is never written through it"; fi

  # every id must be one the plan lists for this path; `-` rows accept only `-`
  as_listed=$(as_row_ids "$as_path")
  if [ -z "$as_ids" ]; then as_refuse "note-ids is empty; list the notes this body was adapted for"; fi
  if [ "$as_listed" = - ]; then
    [ "$as_ids" = - ] || as_refuse "$as_path has no notes in the plan, so the only note-ids accepted is -"
  else
    as_bad=
    as_idl=$(ul_mktemp) || exit 1
    nt_split "$as_ids" > "$as_idl"
    as_n=0
    while IFS= read -r as_i <&3; do
      [ -n "$as_i" ] || continue
      as_n=$((as_n + 1))
      case ",$as_listed," in *",$as_i,"*) ;; *) as_bad="$as_bad $as_i";; esac
    done 3< "$as_idl"
    [ "$as_n" -gt 0 ] || as_refuse "note-ids names no note listed for $as_path"
    [ -z "$as_bad" ] || as_refuse "note id(s) not listed for $as_path in the current plan:$as_bad"
  fi

  # line endings follow the customer's file; the body that is judged is the body saved
  as_cand=$(ul_mktemp) || exit 1
  as_lf=$(ul_mktemp) || exit 1
  as_mine=$state/adapt/mine/$as_path
  as_crlf=0
  if [ -f "$as_mine" ] && grep -q "$(printf '\r')" "$as_mine" 2>/dev/null; then as_crlf=1; fi
  tr -d '\r' < "$as_body" > "$as_lf" 2>/dev/null
  if [ "$as_crlf" = 1 ]; then
    awk '{ printf "%s\r\n", $0 }' "$as_lf" > "$as_cand"
  else
    cp "$as_lf" "$as_cand"
  fi

  case $as_path in
    *.json)
      # upstream's own validator, saved at plan time; never the customer's copy
      if [ ! -s "$state/tools/json-valid.sh" ]; then
        as_refuse "$as_path is JSON but json-valid.sh was not saved at plan time; refusing rather than risk writing broken JSON"
      fi
      as_jvo=$(sh "$state/tools/json-valid.sh" "$as_cand" 2>&1)
      if [ "$?" -ne 0 ]; then
        as_jvr=$(printf '%s\n' "$as_jvo" | sed -n 's/^reason=//p' | tail -1)
        as_refuse "the adapted body is not valid json${as_jvr:+: $as_jvr}"
      fi;;
  esac

  # what the approved notes (only those) allow
  inv_inputs "$as_ids" || as_refuse "$INV_ERR"
  as_rx=$INV_RX; as_rm=$INV_RM; as_md=$INV_MD; as_pd=$INV_PD; as_pat=$INV_PAT

  set -- --surface "$as_path"
  [ -f "$as_mine" ] && set -- "$@" --mine "$as_mine"
  [ -f "$state/adapt/theirs/$as_path" ] && set -- "$@" --theirs "$state/adapt/theirs/$as_path"
  set -- "$@" --candidate "$as_cand" --tools "$state/tools" --relaxes "$as_rx" --removes "$as_rm" --may-drop-headings "$as_md"
  if [ "$as_pd" = true ]; then set -- "$@" --pattern "$as_pat" --project-data; fi
  as_out=$(sh "$here/security-invariants.sh" "$@" 2>&1)
  as_rc=$?
  if [ "$as_rc" -ne 0 ]; then
    as_last=$(printf '%s\n' "$as_out" | tail -1)
    case $as_last in
      rule=*) as_refuse "invariant $as_last";;
      *) as_refuse "invariant rule=none detail=the invariants script could not judge the body: $as_last";;
    esac
  fi

  # save: a temp file in the destination directory renamed into place, every parent lstat-ed
  write_file_safe "$state/merged" "$as_path" "$as_cand" 100644 || exit 1
  as_t=$(ul_mktemp) || exit 1
  for as_f in adapted.tsv unresolved.tsv; do
    [ -f "$state/$as_f" ] || continue
    awk -F'\t' -v p="$as_path" '$1 != p' "$state/$as_f" > "$as_t"
    cp "$as_t" "$state/$as_f"
  done
  printf '%s\t%s\n' "$as_path" "$as_ids" >> "$state/adapted.tsv"
  # a body now exists, so an earlier "could not adapt" mark no longer stands
  rm -f "$state/unresolved/$as_path.lost.diff"
  printf 'saved=%s notes=%s rules=%s\n' "$as_path" "$as_ids" "$(as_rules "$as_path" "$as_pd")"
  return 0
}

# A safety note's file could not be adapted (the adapter said cannot-adapt, or
# --adapt-save refused). The engine records what a full replacement would lose; the
# skill shows it and the customer chooses (design 2.2 step 6). Nothing is replaced.
cmd_mark_unresolved() { # PATH NOTE-ID
  if [ "$#" -ne 2 ]; then echo "error --mark-unresolved takes <path> <note-id>"; exit 2; fi
  mu_path=$1; mu_id=$2
  as_plan_current
  as_has_row "$mu_path" || as_refuse "$mu_path is not a held or two-way path in the current plan"
  mu_listed=$(as_row_ids "$mu_path")
  case ",$mu_listed," in
    *",$mu_id,"*) ;;
    *) as_refuse "note $mu_id is not listed for $mu_path in the current plan";;
  esac
  mu_safety=$(awk -F'\t' -v id="$mu_id" '$1 == id { print $3; exit }' "$state/notes.tsv" 2>/dev/null)
  if [ "$mu_safety" != true ]; then as_refuse "note $mu_id is not a safety note; hold it instead"; fi

  mu_m=$state/adapt/mine/$mu_path
  mu_t=$state/adapt/theirs/$mu_path
  [ -f "$mu_m" ] || mu_m=/dev/null
  [ -f "$mu_t" ] || mu_t=/dev/null
  mu_d=$state/unresolved/$mu_path.lost.diff
  mkdir -p "$(dirname -- "$mu_d")" || { echo "error could not create the unresolved directory"; exit 1; }
  mu_raw=$(ul_mktemp) || exit 1
  diff -u "$mu_m" "$mu_t" > "$mu_raw" 2>/dev/null
  if [ "$?" -gt 1 ]; then echo "error could not diff the two sides of $mu_path"; exit 1; fi
  # the first two lines carry paths and timestamps; replace them with stable labels
  awk -v a="--- mine/$mu_path" -v b="+++ theirs/$mu_path" 'NR == 1 { print a; next } NR == 2 { print b; next } { print }' "$mu_raw" > "$mu_d.part" \
    && mv -f "$mu_d.part" "$mu_d" || { rm -f "$mu_d.part"; echo "error could not write $mu_d"; exit 1; }
  mu_lost=$(awk 'NR > 2 && /^-/ { n++ } END { print n + 0 }' "$mu_d")

  mu_x=$(ul_mktemp) || exit 1
  [ -f "$state/unresolved.tsv" ] || : > "$state/unresolved.tsv"
  awk -F'\t' -v p="$mu_path" '$1 != p' "$state/unresolved.tsv" > "$mu_x"
  cp "$mu_x" "$state/unresolved.tsv"
  printf '%s\t%s\n' "$mu_path" "$mu_id" >> "$state/unresolved.tsv"
  # an unresolved file has no adapted body
  if [ -f "$state/adapted.tsv" ]; then
    awk -F'\t' -v p="$mu_path" '$1 != p' "$state/adapted.tsv" > "$mu_x"
    cp "$mu_x" "$state/adapted.tsv"
  fi
  printf 'unresolved=%s lost=%s\n' "$mu_path" "$mu_lost"
  return 0
}

meta_val() { # KEY -> the value from state/meta
  sed -n "s/^$1=//p" "$state/meta" 2>/dev/null | sed -n '1p'
}

cmd_selftest_two_way() { # PATH
  [ -n "${1:-}" ] || { echo "error --selftest-two-way needs a path"; exit 2; }
  [ -f "$state/meta" ] || { echo "error no plan found; run --plan first"; exit 1; }
  PL_BASE=$(meta_val base)
  PL_UP=$(meta_val upstream)
  PL_HEAD=$(meta_val head)
  CHANNEL=$(meta_val channel)
  channel_map_load
  plan_maps_load
  write_two_way_row "$1"
  printf 'two-way=%s\n' "$(local_path_for "$1")"
}

# =============================================================== subcommands
cmd_status() {
  if heal_stale; then :; fi
  resolve_channel
  fetch_upstream || :
  channel_map_load
  st_def=yes
  [ "$UPSTREAM_URL" = "$UL_DEFAULT_UPSTREAM_URL" ] || st_def=no
  st_base=$(recorded_stamp)
  [ -n "$st_base" ] || st_base=unknown
  st_uh=$(upstream_head) || st_uh=
  if [ "$FETCHED" != 1 ] || [ -z "$st_uh" ]; then st_uh=unknown; fi
  st_off=$(clean_offenders)
  st_clean=yes; [ -z "$st_off" ] || st_clean=no
  st_ip=no; in_progress && st_ip=yes
  st_sh=no; is_shallow && st_sh=yes
  printf 'channel=%s\n' "$CHANNEL"
  if [ -n "$CH_NOTICE" ]; then printf 'notice=%s\n' "$CH_NOTICE"; fi
  printf 'upstream_url=%s\n' "$UPSTREAM_URL"
  printf 'upstream_url_default=%s\n' "$st_def"
  printf 'base=%s\n' "$st_base"
  printf 'upstream_head=%s\n' "$st_uh"
  if [ -n "$FETCH_ERROR" ]; then printf 'fetch_error=%s\n' "$FETCH_ERROR"; fi
  printf 'clean=%s\n' "$st_clean"
  if status_failed "$st_off"; then printf 'clean_error=git status failed in this repository\n'; fi
  printf 'in_progress=%s\n' "$st_ip"
  printf 'shallow=%s\n' "$st_sh"
  printf 'bundle=%s\n' "$(bundle_status)"
  printf 'engine=%s\n' "$(engine_status)"
  printf 'staged=%s\n' "$(staged_value)"
  printf 'ledger_rows=%s\n' "$(ledger_row_count)"
  printf 'copy_mode=%s\n' "$(ul_copy_mode "$root")"
  if [ "$HEALED" = yes ]; then printf 'healed=yes\n'; fi
  if [ -n "$LOCK_LIVE" ]; then printf 'lock=held pid=%s\n' "$LOCK_LIVE"; fi
  return 0
}

# The base ladder (design 2.2 step 1). Sets db_verdict (`<rung> <sha> [n]` or `none`) and
# db_rec (the pointer as committed). Needs UPSTREAM_HEAD and the channel map.
detect_base_verdict() {
  db_rec=$(recorded_stamp)
  db_verdict=
  db_full=$(reach_full "$db_rec") || db_full=

  # (0) handover: the old updater advanced the pointer and tagged what it was before
  if [ -n "$db_full" ] && [ "$(ledger_row_count)" = 0 ]; then
    db_tag=$(git -C "$root" for-each-ref --sort=-refname --sort=-creatordate --format='%(refname)' 'refs/tags/loom/pre-update-*' 2>/dev/null | sed -n '1p')
    if [ -n "$db_tag" ] && git -C "$root" merge-base --is-ancestor "$db_tag" HEAD 2>/dev/null; then
      db_old=$(git -C "$root" show "$db_tag:$UL_SYNC_REF" 2>/dev/null | tr -d ' \t\r\n')
      if db_oldfull=$(reach_full "$db_old") && [ "$db_oldfull" != "$db_full" ]; then
        db_verdict="handover $db_oldfull"
      fi
    fi
  fi
  # (1) recorded
  if [ -z "$db_verdict" ] && [ -n "$db_full" ]; then
    db_verdict="recorded $db_full"
  fi
  # (2) the two known-bad stamps
  if [ -z "$db_verdict" ] && [ -n "$db_rec" ]; then
    db_map=$(remap_known_bad "$db_rec")
    if [ -n "$db_map" ] && db_mapfull=$(reach_full "$db_map"); then
      db_verdict="remap $db_mapfull"
    fi
  fi
  # (3) closest harness match in upstream's public history
  if [ -z "$db_verdict" ] && closest_search; then
    db_verdict="closest $CL_SHA $CL_N"
  fi
  [ -n "$db_verdict" ] || db_verdict=none
}

cmd_detect_base() {
  if ! fetch_upstream; then
    echo "error $FETCH_ERROR"
    exit 1
  fi
  UPSTREAM_HEAD=$(upstream_head) || UPSTREAM_HEAD=
  if [ -z "$UPSTREAM_HEAD" ]; then
    echo "error upstream has no main branch"
    exit 1
  fi
  channel_map_load
  detect_base_verdict
  db_sh=no; is_shallow && db_sh=yes
  printf '%s\n' "$db_verdict"
  printf 'recorded=%s\n' "${db_rec:-missing}"
  printf 'shallow=%s\n' "$db_sh"
  return 0
}

cmd_set_base() { # SHA
  sb=${1:-}
  case $sb in
    ''|-*) echo "error --set-base needs a commit sha"; exit 2;;
  esac
  if ! fetch_upstream; then
    echo "error $FETCH_ERROR"
    exit 1
  fi
  UPSTREAM_HEAD=$(upstream_head) || UPSTREAM_HEAD=
  if [ -z "$UPSTREAM_HEAD" ]; then
    echo "error upstream has no main branch"
    exit 1
  fi
  if ! sb_full=$(reach_full "$sb"); then
    echo "error $sb is not reachable from upstream"
    exit 1
  fi
  channel_map_load
  sb_off=$(clean_offenders | grep -v " $UL_SYNC_REF\$")
  if status_failed "$sb_off"; then
    echo "error could not read the working tree state (git status failed in this repository)"
    exit 1
  fi
  if [ -n "$sb_off" ]; then
    echo "error your working tree has uncommitted changes; commit or stash them first"
    exit 1
  fi
  sb_tmp=$(ul_mktemp) || exit 1
  sb_head=$(recorded_stamp)
  if [ "$sb_head" = "$sb_full" ]; then
    # Already the committed value: put HEAD's exact bytes back (the working file may
    # hold a stale edit) and commit nothing.
    git -C "$root" show "HEAD:$UL_SYNC_REF" > "$sb_tmp" 2>/dev/null
  else
    printf '%s\n' "$sb_full" > "$sb_tmp"
  fi
  write_file_safe "$root" "$UL_SYNC_REF" "$sb_tmp" 100644 || exit 1
  if [ "$sb_head" != "$sb_full" ]; then
    if ! git -C "$root" add -- "$UL_SYNC_REF" >/dev/null 2>&1 \
       || ! git -C "$root" commit -q -m "Record the LogicLoom base this copy updates from" -- "$UL_SYNC_REF" >/dev/null 2>&1; then
      echo "error could not record the base"
      exit 1
    fi
  fi
  printf 'base=%s\n' "$sb_full"
  return 0
}

cmd_bootstrap_copy() {
  if fetch_upstream; then
    :
  elif [ -n "$(upstream_head)" ]; then
    echo "notice=could not refresh upstream; using the copy fetched earlier"
  else
    echo "error $FETCH_ERROR"
    exit 1
  fi
  bc_dir=$gd/loom/bootstrap
  bc_list=$(ul_mktemp) || exit 1
  if ! git -C "$root" -c core.quotepath=off ls-tree -r "$UL_UPSTREAM_REF:$UL_SCRIPTS_DIR" > "$bc_list" 2>/dev/null; then
    echo "error upstream has no $UL_SCRIPTS_DIR"
    exit 1
  fi
  if [ -L "$gd/loom" ] || [ -L "$bc_dir" ]; then
    echo "error $gd/loom is, or holds, a symlink; refusing to rebuild the bootstrap copy"
    exit 1
  fi
  rm -rf "$bc_dir"
  mkdir -p "$bc_dir" || { echo "error could not create $bc_dir"; exit 1; }
  bc_tmp=$(ul_mktemp) || exit 1
  bc_n=0
  while IFS= read -r bc_l; do
    bc_meta=${bc_l%%"$ul__tab"*}
    bc_rel=${bc_l#*"$ul__tab"}
    set -- $bc_meta
    [ "$#" -ge 3 ] || continue
    [ "$2" = blob ] || continue
    case $1 in 100644|100755) ;; *) continue;; esac
    git -C "$root" cat-file blob "$3" > "$bc_tmp" 2>/dev/null || { echo "error could not read $bc_rel from upstream"; exit 1; }
    write_file_safe "$bc_dir" "$bc_rel" "$bc_tmp" "$1" || exit 1
    bc_n=$((bc_n + 1))
  done < "$bc_list"
  if [ ! -f "$bc_dir/update-loom.sh" ]; then
    echo "error upstream has no update-loom.sh"
    exit 1
  fi
  printf 'bootstrap_dir=%s\n' "$bc_dir"
  printf 'engine=%s\n' "$bc_dir/update-loom.sh"
  return 0
}

# ============================================================ --stage and --abandon
# The one place the engine mutates git, and only inside a detached throwaway worktree
# under <gitdir>/loom/update/wt: one commit "LogicLoom update to <upstream12>" that the
# skill later lands with a typed `git merge --ff-only <sha>`. The live tree, HEAD and
# every branch are never touched. Nothing here pushes, resets or deletes a branch or tag.
#
# Decisions (closed vocabulary, refused before anything is touched):
#   path rows  `<path> TAB apply|take-theirs|keep-mine|hold|adapted[ TAB informed=yes]`
#   note rows  `note:<id> TAB apply|acknowledge|decline|decline-final`; `note:_unnoted
#              TAB apply|decline` (required when groups.tsv has _unnoted)
#   every proposed=hold plan row needs a path row (take-theirs, keep-mine, hold, adapted);
#   `apply` is refused on a held row, take-theirs/adapted on a row that is not held.
#   A row is WRITTEN only when it has no covering note and is upstream-owned, or a
#   covering note (or _unnoted) is decided `apply`; `acknowledge` and the declines never
#   approve a write.
# Ledger outcomes: apply -> applied, except `held` when every plan row of the note was
# left unwritten by decision (keep-mine/hold); acknowledge -> acknowledged; decline ->
# declined; decline-final -> declined-final; hold-back rewrites a held note to `held`.
# The .applied record lists the CONTENT paths written (not the ledger, the record itself
# or .sdd-sync-ref), with blob/mode before (HEAD) and after (the worktree index).
# Gate order (fail closed): checks (updates-checks.sh, every safety note PASS|SKIP),
# invariants R1-R5 on security surfaces (an informed take-theirs path is exempt),
# settings.json json-valid, hooks-resolve (liveness only, never executes), protected
# trees, staged-path allowlist. Abort: `result=aborted failed=<gate> reason=... log=...
# unchanged=yes`, worktree removed, tag kept.
# State added by --stage: run/ (relocated engine copy), stage.log, stage.info (tag=,
# update_id=, parent=, upstream=), staged, wt/, mine/<update-id>/.
# Test-only: LOOM_TEST_SLEEP_BEFORE_COMMIT=1 touches state/.test-sleeping and sleeps 30s
# before the commit. LOOM_UPDATE_SH names the interpreter used to re-exec and to run
# sibling scripts and checks (default sh).
UL_SH=${LOOM_UPDATE_SH:-sh}
ST_DP=; ST_DN=; ST_PM=; ST_WR=; ST_LR=; ST_HELD=; ST_WARN=
STG_WT=; STG_TAG=; STG_ERR=; STG_UID=; STG_UP=; STG_HEAD=; STG_BASE=; STG_RUN=
STG_PRE_HEAD=; STG_PRE_STATUS=
SR_C=; SR_P=; SR_D=

stg_log() { printf '%s\n' "$*" >> "$state/stage.log"; }

# 0 when git still lists the staging worktree as registered. Fail closed: when git cannot
# list worktrees at all the answer is "yes, registered" -- unknown is not clean.
stg_wt_registered() {
  swr_phys=
  if [ -d "$state" ]; then
    swr_d=$(CDPATH= cd -- "$state" 2>/dev/null && pwd -P) || swr_d=
    [ -n "$swr_d" ] && swr_phys=$swr_d/wt
  fi
  swr_t=$(ul_mktemp) || return 0
  git -C "$root" worktree list --porcelain > "$swr_t" 2>/dev/null || return 0
  swr_n=$(awk -v a="$state/wt" -v b="$swr_phys" '$1 == "worktree" { p = substr($0, 10); if (p == a || (b != "" && p == b)) { print "1"; exit } }' "$swr_t")
  [ -n "$swr_n" ]
}

# 0 when anything of the staging worktree is left: the folder, or git's registration of it.
stg_wt_leftover() {
  [ -e "$state/wt" ] && return 0
  [ -L "$state/wt" ] && return 0
  stg_wt_registered
}

SW_WHY=
# Returns 1 when the worktree FOLDER or git's REGISTRATION of it survives (or the guard
# refused), with SW_WHY saying which: callers that report an outcome (--abandon, the
# finish clean-up) must not claim a clean result then.
stg_wt_remove() { # remove the throwaway worktree (guarded: only <gitdir>/loom/update/wt)
  SW_WHY=
  state_dir_safe || { SW_WHY="the update state directory is, or sits under, a symlink"; return 1; }
  sw_wt=$state/wt
  if [ -L "$sw_wt" ]; then SW_WHY="$sw_wt is a symlink"; return 1; fi
  git -C "$root" worktree remove --force "$sw_wt" >/dev/null 2>&1
  if [ -d "$sw_wt" ]; then
    chmod -R u+w "$sw_wt" 2>/dev/null
    rm -rf "$sw_wt"
  fi
  git -C "$root" worktree prune >/dev/null 2>&1
  if [ -e "$sw_wt" ]; then SW_WHY="the staging worktree folder $sw_wt could not be removed"; return 1; fi
  if stg_wt_registered; then SW_WHY="git still lists $sw_wt as a worktree (git worktree prune did not clear it)"; return 1; fi
  return 0
}

# Abort after the worktree exists: remove it, keep the tag, say whether the live tree moved.
stg_abort() { # FAILED REASON
  stg_log "abort failed=$1 reason=$2"
  sa_cl=
  stg_wt_remove || sa_cl=$SW_WHY
  rm -f "$state/staged" "$state/stage.info"
  sa_h=$(git -C "$root" rev-parse HEAD 2>/dev/null)
  sa_s=$(git -C "$root" status --porcelain 2>/dev/null)
  sa_u=no
  if [ "$sa_h" = "$STG_PRE_HEAD" ] && [ "$sa_s" = "$STG_PRE_STATUS" ]; then sa_u=yes; fi
  printf 'result=aborted failed=%s reason=%s log=%s/stage.log' "$1" "$2" "$state"
  if [ -n "$STG_TAG" ]; then printf ' tag=%s' "$STG_TAG"; fi
  printf ' unchanged=%s\n' "$sa_u"
  if [ -n "$sa_cl" ]; then printf 'cleanup=incomplete reason=%s\n' "$sa_cl"; fi
  if [ -s "$ST_WARN" ]; then cat "$ST_WARN"; fi
  exit 1
}

stg_pre() { # REASON [FAILED] : refusal before anything was written
  printf 'result=aborted%s reason=%s unchanged=yes\n' "${2:+ failed=$2}" "$1"
  exit 1
}

# ------------------------------------------------------------- decision lookups
dp_get() { awk -F'\t' -v p="$1" '$1 == p { print $2; exit }' "$ST_DP"; }
dp_inf() { awk -F'\t' -v p="$1" '$1 == p { print $3; exit }' "$ST_DP"; }
dn_get() { awk -F'\t' -v p="$1" '$1 == p { print $2; exit }' "$ST_DN"; }
nf_get() { awk -F'\t' -v i="$1" -v n="$2" '$1 == i { print $n; exit }' "$state/notes.tsv"; }

stg_row() { # PATH -> SR_C SR_P SR_D; 1 when PATH is not a plan row
  sr_l=$(awk -F'\t' -v p="$1" '$1 == p { print $2 "\t" $3 "\t" $4; exit }' "$state/plan.tsv")
  [ -n "$sr_l" ] || return 1
  SR_C=${sr_l%%"$ul__tab"*}; sr_l=${sr_l#*"$ul__tab"}
  SR_P=${sr_l%%"$ul__tab"*}; SR_D=${sr_l#*"$ul__tab"}
  return 0
}

stg_cover() { awk -F'\t' -v p="$1" '$1 == p { print $2 }' "$ST_PM" | LC_ALL=C sort -u; }

stg_groups_has_unnoted() { awk -F'\t' '$2 == "_unnoted" { f = 1 } END { exit f ? 0 : 1 }' "$state/groups.tsv"; }

stg_approved() { # PATH DETAIL -> 0 when the covering notes (or _unnoted) approve a write
  sap_ids=$(stg_cover "$1")
  if [ -z "$sap_ids" ]; then
    [ "$2" = upstream-owned ] && return 0
    [ "$(dn_get _unnoted)" = apply ]
    return
  fi
  for sap_i in $sap_ids; do
    [ "$(dn_get "$sap_i")" = apply ] && return 0
  done
  return 1
}

# ------------------------------------------------------------------ parse + validate
stg_parse() { # FILE : fills ST_DP and ST_DN, or refuses on the first malformed line
  ST_DP=$(ul_mktemp) || exit 1
  ST_DN=$(ul_mktemp) || exit 1
  sp_raw=$(ul_mktemp) || exit 1
  awk -F'\t' '
    BEGIN {
      n = split("apply take-theirs keep-mine hold adapted", a, " "); for (i = 1; i <= n; i++) PV[a[i]] = 1
      n = split("apply acknowledge decline decline-final", a, " "); for (i = 1; i <= n; i++) NV[a[i]] = 1
    }
    { sub(/\r$/, "") }
    /^[ \t]*#/ || /^[ \t]*$/ { next }
    {
      key = $1; val = $2
      if (NF < 2 || NF > 3 || key == "") { print "E\t" $0; next }
      if (NF == 3 && $3 != "informed=yes") { print "E\t" $0; next }
      if (key ~ /^note:/) {
        id = substr(key, 6)
        if (NF != 2 || id == "" || !(val in NV)) { print "E\t" $0; next }
        if (id == "_unnoted" && val != "apply" && val != "decline") { print "E\t" $0; next }
        if (("N" id) in seen) { print "E\t" $0; next }
        seen["N" id] = 1
        print "N\t" id "\t" val
      } else {
        if (!(val in PV)) { print "E\t" $0; next }
        if (("P" key) in seen) { print "E\t" $0; next }
        seen["P" key] = 1
        print "P\t" key "\t" val "\t" ($3 == "informed=yes" ? "yes" : "no")
      }
    }' "$1" > "$sp_raw" 2>/dev/null
  sp_e=$(awk -F'\t' '$1 == "E" { sub(/^E\t/, ""); print; exit }' "$sp_raw")
  if [ -n "$sp_e" ]; then
    stg_pre "unknown or malformed decision: $(printf '%s' "$sp_e" | tr '\t' ' ')"
  fi
  awk -F'\t' '$1 == "P" { print $2 "\t" $3 "\t" $4 }' "$sp_raw" > "$ST_DP"
  awk -F'\t' '$1 == "N" { print $2 "\t" $3 }' "$sp_raw" > "$ST_DN"
}

stg_pathmap() {
  ST_PM=$(ul_mktemp) || exit 1
  : > "$ST_PM"
  spm_l=$(ul_mktemp) || exit 1
  while IFS=$ul__tab read -r spm_id spm_rest <&3; do
    [ -f "$state/notes/$spm_id.md" ] || stg_pre "the note file for $spm_id is missing from the plan state; run --plan again"
    spm_fm=$(ul_frontmatter "$state/notes/$spm_id.md")
    for spm_k in touches adds removes; do
      nt_scan_rows "$spm_fm" "$spm_k"
      nt_split "$NT_LIST" > "$spm_l"
      while IFS= read -r spm_p <&4; do
        [ -n "$spm_p" ] || continue
        spm_lp=$(local_path_for "$spm_p")
        case $spm_k in removes) spm_kind=r;; *) spm_kind=ta;; esac
        printf '%s\t%s\t%s\n' "$spm_lp" "$spm_id" "$spm_kind" >> "$ST_PM"
      done 4< "$spm_l"
    done
  done 3< "$state/notes.tsv"
}

stg_validate() {
  # ---- path rows
  while IFS=$ul__tab read -r v_p v_d v_i <&3; do
    stg_row "$v_p" || stg_pre "$v_p is not a row of the current plan"
    case $SR_P in
      keep|skip)
        case $v_d in keep-mine|hold) ;; *) stg_pre "$v_p is not a writable row; its only decisions are keep-mine or hold";; esac;;
      apply)
        case $v_d in take-theirs|adapted) stg_pre "$v_d is only for held rows, and $v_p is not held";; esac;;
      hold)
        [ "$v_d" != apply ] || stg_pre "$v_p is held; decide take-theirs, keep-mine, hold or adapted";;
    esac
    if [ "$v_d" = adapted ]; then
      if ! awk -F'\t' -v p="$v_p" '$1 == p { f = 1 } END { exit f ? 0 : 1 }' "$state/adapted.tsv" 2>/dev/null || [ ! -f "$state/merged/$v_p" ]; then
        stg_pre "adapted on $v_p has no saved adapted body (run --adapt-save)"
      fi
    fi
    if [ "$SR_P" = hold ] && [ "$v_d" != take-theirs ] && awk -F'\t' -v p="$v_p" '$1 == p { f = 1 } END { exit f ? 0 : 1 }' "$state/unresolved.tsv" 2>/dev/null; then
      stg_pre "$v_p is safety-unresolved: its only decision is take-theirs with informed=yes (or stop the update)"
    fi
    if [ "$v_d" = take-theirs ] && [ "$v_i" != yes ]; then
      for v_n in $(stg_cover "$v_p"); do
        if [ "$(nf_get "$v_n" 3)" = true ]; then
          stg_pre "take-theirs on $v_p replaces a file a safety note covers ($v_n); it needs informed=yes in the same row"
        fi
      done
    fi
    case $v_d in
      apply|take-theirs|adapted)
        stg_approved "$v_p" "$SR_D" || stg_pre "$v_p cannot be written: the notes that cover it are declined or not applied; a declined note's paths are never written";;
    esac
  done 3< "$ST_DP"
  # ---- every held row needs a decision
  while IFS=$ul__tab read -r v_p v_c v_pr v_dt <&3; do
    [ "$v_pr" = hold ] || continue
    [ -n "$(dp_get "$v_p")" ] || stg_pre "$v_p is held and has no decision (take-theirs, keep-mine, hold or adapted)"
  done 3< "$state/plan.tsv"
  # ---- note rows
  while IFS=$ul__tab read -r v_id v_d <&3; do
    [ "$v_id" = _unnoted ] && continue
    awk -F'\t' -v i="$v_id" '$1 == i { f = 1 } END { exit f ? 0 : 1 }' "$state/notes.tsv" || stg_pre "note:$v_id is not an offered note in the plan"
  done 3< "$ST_DN"
  if stg_groups_has_unnoted && [ -z "$(dn_get _unnoted)" ]; then
    stg_pre "note:_unnoted has no decision (apply or decline)"
  fi
  while IFS=$ul__tab read -r v_id v_rest <&3; do
    v_d=$(dn_get "$v_id")
    [ -n "$v_d" ] || stg_pre "note $v_id is offered and has no decision (apply, acknowledge, decline or decline-final)"
    v_sf=$(nf_get "$v_id" 3)
    case $v_d in
      decline|decline-final) [ "$v_sf" != true ] || stg_pre "note $v_id is a safety note (safety); it cannot be declined";;
    esac
    if [ "$v_d" = decline-final ] && [ "$(nf_get "$v_id" 9)" != true ] && [ "$(nf_get "$v_id" 10)" != none ]; then
      stg_pre "decline-final is only for a project-data note or a note with no check; $v_id is neither"
    fi
    if [ "$v_d" = apply ]; then
      for v_r in $(ul_fm_list "$(ul_frontmatter "$state/notes/$v_id.md")" requires); do
        if awk -F'\t' -v i="$v_r" '$1 == i { f = 1 } END { exit f ? 0 : 1 }' "$state/notes.tsv"; then
          case $(dn_get "$v_r") in decline|decline-final) stg_pre "note $v_id is blocked: it requires $v_r, which is declined";; esac
        else
          case $(ledger_outcome "$v_r") in declined|declined-final|held) stg_pre "note $v_id is blocked: it requires $v_r, recorded $(ledger_outcome "$v_r") in the ledger";; esac
        fi
      done
    fi
  done 3< "$state/notes.tsv"
}

# ------------------------------------------------------------------ writes
stg_chain_ok() { # PATH : 1 (STG_ERR) when any component is a symlink in the worktree
  sc_cur=$STG_WT; sc_rest=$1; sc_rel=
  while [ -n "$sc_rest" ]; do
    case $sc_rest in
      */*) sc_c=${sc_rest%%/*}; sc_rest=${sc_rest#*/};;
      *) sc_c=$sc_rest; sc_rest=;;
    esac
    [ -n "$sc_c" ] || continue
    sc_rel=${sc_rel:+$sc_rel/}$sc_c
    sc_cur=$sc_cur/$sc_c
    if [ -L "$sc_cur" ]; then STG_ERR="symlink in path $sc_rel"; return 1; fi
  done
  return 0
}

stg_modeok() { case $1 in 100644|100755) return 0;; esac; STG_ERR="unsupported file mode $1 for $2"; return 1; }

stg_put() { # PATH SHA MODE : the blob as wt/PATH through write_path
  stg_modeok "$3" "$1" || return 1
  sp_t=$(ul_mktemp) || exit 1
  git -C "$root" cat-file blob "$2" > "$sp_t" 2>/dev/null || { STG_ERR="could not read the blob for $1"; return 1; }
  sp_o=$(write_path "$STG_WT" "$1" "$sp_t" "$3") || { STG_ERR=${sp_o#error }; return 1; }
  printf '%s\n' "$1" >> "$ST_WR"
  return 0
}

stg_put_file() { # PATH FILE MODE
  stg_modeok "$3" "$1" || return 1
  sp_o=$(write_path "$STG_WT" "$1" "$2" "$3") || { STG_ERR=${sp_o#error }; return 1; }
  printf '%s\n' "$1" >> "$ST_WR"
  return 0
}

stg_remove() { # PATH
  stg_chain_ok "$1" || return 1
  git -C "$STG_WT" rm -q -f --ignore-unmatch -- "$1" >/dev/null 2>&1 || { STG_ERR="could not remove $1"; return 1; }
  printf '%s\n' "$1" >> "$ST_WR"
  return 0
}

stg_backup() { # PATH : the customer's file, kept under mine/<update-id>/
  set -- "$1" $(entry_at HEAD "$1")
  [ "$2" != - ] || return 0
  sb_t=$(ul_mktemp) || exit 1
  git -C "$root" cat-file blob "$3" > "$sb_t" 2>/dev/null || { STG_ERR="could not back up $1"; return 1; }
  sb_o=$(write_file_safe "$state/mine/$STG_UID" "$1" "$sb_t" 100644) || { STG_ERR="could not back up $1: ${sb_o#error }"; return 1; }
  return 0
}

stg_head_mode() { # PATH FALLBACK -> 100644|100755
  set -- $(entry_at HEAD "$1") "$2"
  case $1 in 100644|100755) printf '%s' "$1";; *) printf '%s' "${3:-100644}";; esac
}

stg_rows() {
  while IFS=$ul__tab read -r r_p r_c r_pr r_dt <&3; do
    case $r_pr in apply|hold) ;; *) continue;; esac
    if ul_path_forbidden "$r_p"; then
      printf 'warn forbidden path %s skipped\n' "$r_p" >> "$ST_WARN"
      continue
    fi
    r_d=$(dp_get "$r_p")
    r_up=$(as_upstream_name "$r_p")
    set -- $(entry_at "$STG_UP" "$r_up")
    r_um=$1; r_us=$2
    r_act=
    if [ "$r_pr" = apply ]; then
      case $r_d in keep-mine|hold) continue;; esac
      stg_approved "$r_p" "$r_dt" || continue
      case $r_c in
        take|add) r_act=upstream;;
        mode) r_act=mode;;
        delete) r_act=delete;;
        merged-clean) r_act=merged;;
        *) continue;;
      esac
    else
      case $r_d in
        take-theirs) r_act=theirs;;
        adapted) r_act=merged;;
        *) continue;;
      esac
    fi
    case $r_act in
      upstream)
        if [ "$r_dt" = upstream-owned ]; then stg_backup_changed "$r_p" || stg_abort write "$STG_ERR"; fi
        stg_put "$r_p" "$r_us" "$r_um" || stg_abort write "$STG_ERR";;
      theirs)
        stg_backup "$r_p" || stg_abort write "$STG_ERR"
        if [ "$r_us" = - ]; then stg_remove "$r_p" || stg_abort write "$STG_ERR"
        else stg_put "$r_p" "$r_us" "$r_um" || stg_abort write "$STG_ERR"; fi;;
      mode)
        set -- $(entry_at HEAD "$r_p")
        stg_put "$r_p" "$2" "$r_um" || stg_abort write "$STG_ERR";;
      delete)
        stg_backup_changed "$r_p" || stg_abort write "$STG_ERR"
        stg_remove "$r_p" || stg_abort write "$STG_ERR";;
      merged)
        if [ "$r_pr" = hold ]; then stg_backup "$r_p" || stg_abort write "$STG_ERR"; fi
        stg_put_file "$r_p" "$state/merged/$r_p" "$(stg_head_mode "$r_p" "${r_um#-}")" || stg_abort write "$STG_ERR";;
    esac
  done 3< "$state/plan.tsv"
}

# Back up the customer's copy of an upstream-owned file only when it differs from the base.
stg_backup_changed() { # PATH
  set -- "$1" $(entry_at HEAD "$1") $(entry_at "$(meta_val base)" "$(as_upstream_name "$1")")
  [ "$3" != - ] || return 0
  [ "$3" != "$5" ] || return 0
  stg_backup "$1"
}

# ------------------------------------------------------------ ledger + record
stg_note_outcome() { # ID -> applied|held|acknowledged|declined|declined-final
  case $(dn_get "$1") in
    acknowledge) printf 'acknowledged'; return 0;;
    decline) printf 'declined'; return 0;;
    decline-final) printf 'declined-final'; return 0;;
  esac
  sn_rows=0; sn_wrote=0
  sn_f=$(ul_mktemp) || exit 1
  awk -F'\t' -v i="$1" '$2 == i { print $1 }' "$ST_PM" | LC_ALL=C sort -u > "$sn_f"
  while IFS= read -r sn_p <&4; do
    stg_row "$sn_p" || continue
    case $SR_P in
      apply|hold)
        sn_rows=1
        if grep -Fxq -- "$sn_p" "$ST_WR" 2>/dev/null; then sn_wrote=1; fi;;
    esac
  done 4< "$sn_f"
  if [ "$sn_rows" = 1 ] && [ "$sn_wrote" = 0 ]; then printf 'held'; else printf 'applied'; fi
}

stg_ledger_rows() { # ST_LR = id TAB outcome TAB blob
  ST_LR=$(ul_mktemp) || exit 1
  : > "$ST_LR"
  while IFS=$ul__tab read -r sl_id sl_rest <&3; do
    sl_b=$(git -C "$root" hash-object --no-filters "$state/notes/$sl_id.md" 2>/dev/null) || sl_b=-
    printf '%s\t%s\t%s\n' "$sl_id" "$(stg_note_outcome "$sl_id")" "$sl_b" >> "$ST_LR"
  done 3< "$state/notes.tsv"
}

stg_ledger_emit() {
  se_t=$(ul_mktemp) || exit 1
  git -C "$root" show "HEAD:$UL_LEDGER" > "$se_t" 2>/dev/null || : > "$se_t"
  if [ -s "$se_t" ] && [ -n "$(tail -c 1 "$se_t")" ]; then printf '\n' >> "$se_t"; fi
  se_d=$(date -u +%Y-%m-%d)
  awk -F'\t' -v up="$STG_UP" -v d="$se_d" '{ printf "%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, up, d }' "$ST_LR" >> "$se_t"
  sed_o=$(write_path "$STG_WT" "$UL_LEDGER" "$se_t" 100644) || stg_abort write "${sed_o#error }"
}

stg_record_emit() {
  sr_t=$(ul_mktemp) || exit 1
  {
    printf 'update_id=%s\n' "$STG_UID"
    printf 'tag=%s\n' "$STG_TAG"
    printf 'parent=%s\n' "$STG_HEAD"
    printf 'base=%s\n' "$STG_BASE"
    printf 'upstream=%s\n' "$STG_UP"
    printf 'channel=%s\n' "$CHANNEL"
    printf 'date=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    LC_ALL=C sort -u "$ST_WR" | while IFS= read -r sr_p; do
      [ -n "$sr_p" ] || continue
      set -- $(entry_at HEAD "$sr_p")
      sr_bm=$1; sr_bs=$2
      sr_a=$(git -C "$STG_WT" ls-files -s -- "$sr_p" 2>/dev/null | sed -n '1p')
      if [ -n "$sr_a" ]; then
        sr_am=${sr_a%% *}; sr_r=${sr_a#* }; sr_as=${sr_r%% *}
      else
        sr_am=-; sr_as=-
      fi
      printf '%s\t%s\t%s\t%s\t%s\n' "$sr_p" "$sr_as" "$sr_am" "$sr_bs" "$sr_bm"
    done
  } > "$sr_t"
  sr_o=$(write_path "$STG_WT" "$UL_APPLIED_DIR/$STG_UID.applied" "$sr_t" 100644) || stg_abort write "${sr_o#error }"
}

# ------------------------------------------------------------------ checks
stg_status_snapshot() { git -C "$STG_WT" status --porcelain --untracked-files=all 2>/dev/null; }

stg_run_check() { # ID -> rc in SC_RC; aborts when the check wrote anything
  scr_b=$(stg_status_snapshot)
  scr_rb=$(git -C "$root" for-each-ref 2>/dev/null)
  scr_fb=$(find "$STG_WT" -path "$STG_WT/.git" -prune -o -type f -print 2>/dev/null | LC_ALL=C sort)
  scr_hb=$(git -C "$STG_WT" rev-parse HEAD 2>/dev/null)
  cg_begin
  scr_out=$(cd "$STG_WT" && REPO_ROOT="$STG_WT" UPDATE_TOOLS="$state/tools" $UL_SH "$state/notes/$1.check.sh" </dev/null 2>/dev/null)
  SC_RC=$?
  cg_end
  scr_ha=$(git -C "$STG_WT" rev-parse HEAD 2>/dev/null)
  scr_a=$(stg_status_snapshot)
  scr_ra=$(git -C "$root" for-each-ref 2>/dev/null)
  scr_fa=$(find "$STG_WT" -path "$STG_WT/.git" -prune -o -type f -print 2>/dev/null | LC_ALL=C sort)
  stg_log "check $1 exit=$SC_RC last=${scr_out##*"$ul__nl"}"
  if [ "$scr_hb" != "$scr_ha" ]; then
    stg_abort checks "check $1 moved the worktree HEAD (check-wrote=head)"
  fi
  if [ -n "$CG_W" ]; then
    stg_abort checks "check $1 wrote $CG_W outside the worktree (check-wrote=$CG_W)"
  fi
  if [ "$scr_b" != "$scr_a" ] || [ "$scr_rb" != "$scr_ra" ] || [ "$scr_fb" != "$scr_fa" ]; then
    stg_abort checks "check $1 wrote into the worktree or changed a ref"
  fi
}

stg_changed() { git -C "$STG_WT" diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null | LC_ALL=C sort; }

# Like stg_changed, but into FILE and fail closed: when git cannot list the commit's paths
# the caller must stop, because an empty list would read as "nothing to check" and let the
# invariants, the hold-back and the allowlist pass over a commit they never looked at.
stg_changed_to() { # FILE
  sct_t=$(ul_mktemp) || exit 1
  git -C "$STG_WT" diff-tree --no-commit-id --name-only -r HEAD > "$sct_t" 2>/dev/null || return 1
  LC_ALL=C sort "$sct_t" > "$1"
}

stg_restore_head() { # PATH : back to the customer's HEAD content, or gone when HEAD lacked it
  set -- "$1" $(entry_at HEAD "$1")
  if [ "$2" = - ]; then
    stg_chain_ok "$1" || return 1
    git -C "$STG_WT" rm -q -f --ignore-unmatch -- "$1" >/dev/null 2>&1
    return $?
  fi
  srh_t=$(ul_mktemp) || exit 1
  git -C "$root" cat-file blob "$3" > "$srh_t" 2>/dev/null || { STG_ERR="could not read HEAD's $1"; return 1; }
  srh_o=$(write_path "$STG_WT" "$1" "$srh_t" "$2") || { STG_ERR=${srh_o#error }; return 1; }
  return 0
}

stg_note_paths() { awk -F'\t' -v i="$1" '$2 == i { print $1 }' "$ST_PM" | LC_ALL=C sort -u; }

stg_holdback() {
  ST_HELD=$(ul_mktemp) || exit 1
  : > "$ST_HELD"
  hb_ch=$(ul_mktemp) || exit 1
  stg_changed_to "$hb_ch" || stg_abort commit "git could not list the paths the update commit changed"
  hb_cand=$(ul_mktemp) || exit 1
  : > "$hb_cand"
  hb_ap=$(ul_mktemp) || exit 1       # applied non-safety notes
  : > "$hb_ap"
  while IFS=$ul__tab read -r hb_id hb_rest <&3; do
    [ "$(dn_get "$hb_id")" = apply ] || continue
    [ "$(nf_get "$hb_id" 3)" = true ] && continue
    printf '%s\n' "$hb_id" >> "$hb_ap"
    [ "$(nf_get "$hb_id" 10)" != none ] || continue
    [ -f "$state/notes/$hb_id.check.sh" ] || continue
    hb_np=$(ul_mktemp) || exit 1
    stg_note_paths "$hb_id" > "$hb_np"
    if grep -Fxqf "$hb_np" "$hb_ch" 2>/dev/null; then printf '%s\n' "$hb_id" >> "$hb_cand"; fi
  done 3< "$state/notes.tsv"
  while IFS= read -r hb_id <&3; do
    stg_run_check "$hb_id"
    if [ "$SC_RC" -ne 0 ]; then printf '%s\n' "$hb_id" >> "$ST_HELD"; fi
  done 3< "$hb_cand"
  [ -s "$ST_HELD" ] || return 0
  # widen to a fixed point: a shared path, or a (transitive) requires on a held note
  hb_grew=1
  while [ "$hb_grew" = 1 ]; do
    hb_grew=0
    hb_hp=$(ul_mktemp) || exit 1
    : > "$hb_hp"
    while IFS= read -r hb_h <&3; do stg_note_paths "$hb_h" >> "$hb_hp"; done 3< "$ST_HELD"
    while IFS= read -r hb_o <&3; do
      grep -Fxq -- "$hb_o" "$ST_HELD" && continue
      hb_op=$(ul_mktemp) || exit 1
      stg_note_paths "$hb_o" > "$hb_op"
      hb_add=0
      if [ -s "$hb_op" ] && grep -Fxqf "$hb_op" "$hb_hp" 2>/dev/null; then hb_add=1; fi
      for hb_r in $(ul_fm_list "$(ul_frontmatter "$state/notes/$hb_o.md")" requires); do
        grep -Fxq -- "$hb_r" "$ST_HELD" && hb_add=1
      done
      if [ "$hb_add" = 1 ]; then printf '%s\n' "$hb_o" >> "$ST_HELD"; hb_grew=1; fi
    done 3< "$hb_ap"
  done
  # what has to be restored, and what a safety note forbids restoring
  hb_rs=$(ul_mktemp) || exit 1
  : > "$hb_rs"
  while IFS= read -r hb_h <&3; do
    stg_note_paths "$hb_h" | while IFS= read -r hb_p; do
      grep -Fxq -- "$hb_p" "$hb_ch" && printf '%s\n' "$hb_p"
    done >> "$hb_rs"
  done 3< "$ST_HELD"
  LC_ALL=C sort -u "$hb_rs" -o "$hb_rs"
  hb_sp=$(ul_mktemp) || exit 1
  : > "$hb_sp"
  while IFS=$ul__tab read -r hb_id hb_rest <&3; do
    [ "$(nf_get "$hb_id" 3)" = true ] && stg_note_paths "$hb_id" >> "$hb_sp"
  done 3< "$state/notes.tsv"
  if [ -s "$hb_rs" ] && [ -s "$hb_sp" ]; then
    hb_bad=$(grep -Fxf "$hb_sp" "$hb_rs" | sed -n '1p')
    if [ -n "$hb_bad" ]; then
      stg_abort hold-back "a held note's change to $hb_bad cannot be reverted because a safety note also touches it; holding it back would leave it live"
    fi
  fi
  while IFS= read -r hb_p <&3; do
    [ -n "$hb_p" ] || continue
    stg_restore_head "$hb_p" || stg_abort hold-back "could not restore $hb_p to your version: $STG_ERR"
  done 3< "$hb_rs"
  grep -Fvxf "$hb_rs" "$ST_WR" > "$ST_WR.n" 2>/dev/null; mv -f "$ST_WR.n" "$ST_WR"
  awk -F'\t' -v OFS='\t' 'FNR == NR { h[$1] = 1; next } ($1 in h) { $2 = "held" } { print }' "$ST_HELD" "$ST_LR" > "$ST_LR.n"
  mv -f "$ST_LR.n" "$ST_LR"
  stg_ledger_emit
  stg_record_emit
  git -C "$STG_WT" add -A >/dev/null 2>&1
  stg_commit amend || stg_abort hold-back "could not amend the update commit after holding a note back"
}

stg_commit() { # [amend]
  if [ "${1:-}" = amend ]; then
    git -C "$STG_WT" -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -q --amend --no-edit --no-verify >/dev/null 2>&1
  else
    git -C "$STG_WT" -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -q --no-verify -m "LogicLoom update to $(printf '%s' "$STG_UP" | cut -c1-12)" >/dev/null 2>&1
  fi
}

# ------------------------------------------------------------------ the gate
stg_allowlist() { # WT -> 0 ok; else AL_BAD names the first path no note allows
  sal_ok=$(ul_mktemp) || exit 1
  : > "$sal_ok"
  while IFS=$ul__tab read -r sal_id sal_rest <&3; do
    [ "$(dn_get "$sal_id")" = apply ] || continue
    grep -Fxq -- "$sal_id" "$ST_HELD" 2>/dev/null && continue
    stg_note_paths "$sal_id" >> "$sal_ok"
  done 3< "$state/notes.tsv"
  while IFS=$ul__tab read -r sal_p sal_c sal_pr sal_dt <&3; do
    case $sal_pr in apply|hold) ;; *) continue;; esac
    [ -z "$(stg_cover "$sal_p")" ] || continue
    if [ "$sal_dt" = upstream-owned ] || [ "$(dn_get _unnoted)" = apply ]; then printf '%s\n' "$sal_p" >> "$sal_ok"; fi
  done 3< "$state/plan.tsv"
  { printf '%s\n' "$UL_SYNC_REF" "$UL_LEDGER" "$UL_APPLIED_DIR/$STG_UID.applied"; } >> "$sal_ok"
  sal_ch=$(ul_mktemp) || exit 1
  if ! git -C "$1" diff-tree --no-commit-id --name-only -r HEAD > "$sal_ch" 2>/dev/null; then
    AL_BAD='(git could not list the commit)'
    return 1
  fi
  AL_BAD=$(grep -Fxvf "$sal_ok" "$sal_ch" | sed -n '1p')
  [ -z "$AL_BAD" ]
}

stg_tree_listing() { # REV-OR-WT TREE
  git -C "$1" ls-tree HEAD:"$2" 2>/dev/null | case $2 in
    features|specs|.brain) awk -F'\t' '$2 != "README.md" && $2 != ".gitkeep"';;
    *) cat;;
  esac
}

stg_treegate() { # WT -> 0 ok; else TG_BAD names the tree
  TG_BAD=
  for stg_t in $UL_FORBIDDEN_TREES; do
    if [ "$(stg_tree_listing "$root" "$stg_t")" != "$(stg_tree_listing "$1" "$stg_t")" ]; then TG_BAD=$stg_t; return 1; fi
  done
  return 0
}

# Every hook script .claude/settings.json names must exist, be readable and parse. Shared
# by the --stage gate (on the worktree) and the --finish smoke (on the live tree).
# TREE is the tree to read, JSONFLAT upstream's json-flat.sh. Returns 0, or 1 with HK_MSG
# set when a HARNESS script is bad; a missing adopter script is a warning appended to the
# file HK_WARN names (nowhere when unset). Never runs a hook.
HK_MSG=
HK_WARN=
hk_resolve() { # TREE JSONFLAT
  HK_MSG=
  [ -f "$1/.claude/settings.json" ] || return 0
  [ -s "$2" ] || return 0
  hk_f=$(ul_mktemp) || exit 1
  hk_s=$(ul_mktemp) || exit 1
  $UL_SH "$2" "$1/.claude/settings.json" > "$hk_f" 2>/dev/null || { HK_MSG="settings.json could not be read to find its hooks"; return 1; }
  awk -F'\t' '$1 ~ /^\/hooks\/[^\/]+\/[0-9]+\/hooks\/[0-9]+\/command$/ {
      n = split($2, t, /[ \t]+/)
      for (i = 1; i <= n; i++) { s = t[i]; gsub(/^["\047]|["\047]$/, "", s); if (s ~ /\.sh$/) { print s; break } }
    }' "$hk_f" | LC_ALL=C sort -u > "$hk_s"
  while IFS= read -r hk_p <&3; do
    case $hk_p in /*|\$*|~*) continue;; esac
    hk_w=
    if [ ! -f "$1/$hk_p" ]; then hk_w="does not exist"
    elif [ ! -r "$1/$hk_p" ]; then hk_w="is not readable"
    elif ! $UL_SH -n "$1/$hk_p" >/dev/null 2>&1 && ! { command -v bash >/dev/null 2>&1 && bash -n "$1/$hk_p" >/dev/null 2>&1; }; then hk_w="does not parse"
    fi
    [ -n "$hk_w" ] || continue
    if path_in_harness "$hk_p"; then
      HK_MSG="hook script $hk_p $hk_w, and it is a harness script"
      return 1
    fi
    if [ -n "$HK_WARN" ]; then printf 'warn hook %s %s (an adopter script; not gated)\n' "$hk_p" "$hk_w" >> "$HK_WARN"; fi
  done 3< "$hk_s"
  return 0
}

stg_hooks_resolve() {
  HK_WARN=$ST_WARN
  hk_resolve "$STG_WT" "$state/tools/json-flat.sh" || stg_abort hooks-resolve "$HK_MSG"
}

stg_gate() {
  # ---- checks
  sg_safety=$(awk -F'\t' '$3 == "true" { print $1 }' "$state/notes.tsv")
  if [ -n "$sg_safety" ]; then
    sg_hb=$(git -C "$STG_WT" rev-parse HEAD 2>/dev/null)
    cg_begin
    sg_o=$(cd "$STG_WT" && $UL_SH "$STG_RUN/updates-checks.sh" --root "$STG_WT" --tools "$state/tools" 2>&1)
    sg_rc=$?
    cg_end
    if [ "$(git -C "$STG_WT" rev-parse HEAD 2>/dev/null)" != "$sg_hb" ]; then stg_abort checks "the checks runner moved the worktree HEAD (check-wrote=head)"; fi
    if [ -n "$CG_W" ]; then stg_abort checks "the checks runner wrote $CG_W outside the worktree (check-wrote=$CG_W)"; fi
    printf '%s\n' "$sg_o" > "$state/checks-stage.log"
    stg_log "updates-checks exit=$sg_rc"
    printf '%s\n' "$sg_o" >> "$state/stage.log"
    if [ -n "$(stg_status_snapshot)" ]; then stg_abort checks "the checks runner wrote into the worktree"; fi
    sg_fail=$(printf '%s\n' "$sg_o" | sed -n 's/^FAIL //p' | tr '\n' ' ')
    [ -z "$sg_fail" ] || stg_abort checks "a safety check failed in the worktree: $sg_fail"
    [ "$sg_rc" -eq 0 ] || stg_abort checks "the checks runner exited $sg_rc"
    for sg_n in $sg_safety; do
      printf '%s\n' "$sg_o" | grep -Eq "^(PASS|SKIP) $sg_n( |\$)" || stg_abort checks "safety note $sg_n has no passing check result"
    done
  fi
  # ---- invariants on every security surface in the commit
  sg_ch=$(ul_mktemp) || exit 1
  stg_changed_to "$sg_ch" || stg_abort invariants "git could not list the paths the update commit changed"
  while IFS= read -r sg_p; do
    ul_path_security_surface "$sg_p" && printf '%s\n' "$sg_p"
  done < "$sg_ch" > "$state/.surfaces"
  while IFS= read -r sg_p <&3; do
    [ -n "$sg_p" ] || continue
    if [ "$(dp_get "$sg_p")" = take-theirs ] && [ "$(dp_inf "$sg_p")" = yes ]; then continue; fi
    [ -f "$STG_WT/$sg_p" ] || stg_abort invariants "$sg_p was removed, and a security surface may not be"
    sg_ids=
    for sg_n in $(stg_cover "$sg_p"); do
      if [ "$(dn_get "$sg_n")" = apply ] && ! grep -Fxq -- "$sg_n" "$ST_HELD" 2>/dev/null; then sg_ids=${sg_ids:+$sg_ids,}$sg_n; fi
    done
    inv_inputs "${sg_ids:--}" || stg_abort invariants "$INV_ERR"
    sg_m=$(ul_mktemp) || exit 1
    sg_th=$(ul_mktemp) || exit 1
    set -- $(entry_at HEAD "$sg_p")
    sg_ha=
    if [ "$2" != - ]; then git -C "$root" cat-file blob "$2" > "$sg_m" 2>/dev/null; sg_ha=1; fi
    set -- $(entry_at "$STG_UP" "$(as_upstream_name "$sg_p")")
    sg_ua=
    if [ "$2" != - ]; then git -C "$root" cat-file blob "$2" > "$sg_th" 2>/dev/null; sg_ua=1; fi
    set -- --surface "$sg_p"
    [ -n "$sg_ha" ] && set -- "$@" --mine "$sg_m"
    [ -n "$sg_ua" ] && set -- "$@" --theirs "$sg_th"
    set -- "$@" --candidate "$STG_WT/$sg_p" --tools "$state/tools" --relaxes "$INV_RX" --removes "$INV_RM" --may-drop-headings "$INV_MD"
    sg_o=$($UL_SH "$here/security-invariants.sh" "$@" 2>&1)
    sg_rc=$?
    if [ "$sg_rc" -ne 0 ]; then
      stg_abort invariants "$sg_p: $(printf '%s\n' "$sg_o" | tail -1)"
    fi
  done 3< "$state/.surfaces"
  rm -f "$state/.surfaces"
  # ---- settings.json valid JSON
  if [ -f "$STG_WT/.claude/settings.json" ]; then
    if [ ! -s "$state/tools/json-valid.sh" ]; then
      if grep -Fxq .claude/settings.json "$sg_ch"; then stg_abort machinery "settings.json changed but json-valid.sh was not saved at plan time"; fi
    else
      $UL_SH "$state/tools/json-valid.sh" "$STG_WT/.claude/settings.json" >/dev/null 2>&1 || stg_abort json "settings.json in the update is not valid JSON"
    fi
  fi
  # ---- hooks resolve
  stg_hooks_resolve
  # ---- protected trees, staged-path allowlist
  stg_treegate "$STG_WT" || stg_abort tree "the protected tree $TG_BAD differs from your branch"
  stg_allowlist "$STG_WT" || stg_abort allowlist "the update commit changes $AL_BAD, which no approved note allows"
}

# ------------------------------------------------------------------ the command
stg_relocate() { # DECISIONS-FILE : copy the family to state/run and re-exec from there, once
  [ "${LOOM_UPDATE_RELOCATED:-0}" != 1 ] || return 0
  case $state in ?*/loom/update) ;; *) echo "error refusing to use an unexpected state directory"; exit 1;; esac
  mkdir -p "$state/run" || { echo "error could not create $state/run"; exit 1; }
  for sr_f in update-loom.sh update-loom-common.sh json-valid.sh json-flat.sh security-invariants.sh updates-checks.sh updates-lint.sh; do
    if [ -f "$here/$sr_f" ]; then
      cp "$here/$sr_f" "$state/run/$sr_f" || { echo "error could not copy $sr_f to $state/run"; exit 1; }
    else
      rm -f "$state/run/$sr_f"
    fi
  done
  set --
  [ -n "$OPT_URL" ] && set -- "$@" --upstream-url "$OPT_URL"
  [ "$OPT_FORK" = 1 ] && set -- "$@" --i-am-pointing-at-a-fork
  [ -n "$OPT_CHANNEL" ] && set -- "$@" --channel "$OPT_CHANNEL"
  LOOM_UPDATE_RELOCATED=1
  LOOM_UPDATE_ROOT=$root
  export LOOM_UPDATE_RELOCATED LOOM_UPDATE_ROOT
  exec $UL_SH "$state/run/update-loom.sh" "$@" --stage "$stg_dec" </dev/null
}

stg_context() { # selftests: CHANNEL, maps, ids
  CHANNEL=$(meta_val channel)
  channel_map_load
  plan_maps_load
  STG_UID=$(meta_val update_id)
  STG_UP=$(meta_val upstream)
}

cmd_stage() { # DECISIONS-FILE
  if [ "$#" -ne 1 ]; then echo "error --stage takes <decisions.tsv>"; exit 2; fi
  stg_dec=$1
  case $stg_dec in /*) ;; *) stg_dec=$(cd "$(dirname -- "$stg_dec")" 2>/dev/null && pwd)/$(basename -- "$stg_dec");; esac
  stg_relocate
  unset LOOM_UPDATE_RELOCATED LOOM_UPDATE_ROOT
  STG_RUN=$state/run
  ST_WARN=$(ul_mktemp) || exit 1
  : > "$ST_WARN"
  mkdir -p "$state" || { echo "error could not create $state"; exit 1; }
  : > "$state/stage.log"
  if ! heal_stale; then stg_pre "another update is staging (pid $LOCK_LIVE)"; fi
  if [ -f "$state/staged" ]; then stg_pre "a staged update exists; run --finish or --abandon"; fi
  lock_acquire || stg_pre "another update is staging"
  # ---- refusals, nothing written to the tree
  [ -f "$state/plan.tsv" ] && [ -f "$state/adapt.tsv" ] && [ -f "$state/meta" ] && [ -f "$state/notes.tsv" ] || stg_pre "no plan found; run --plan first"
  resolve_channel
  channel_map_load
  so=$(clean_offenders)
  if [ -n "$so" ]; then
    if status_failed "$so"; then stg_pre "git status failed in this repository"; fi
    stg_pre "your working tree has uncommitted changes: $(offender_paths "$so")"
  fi
  if in_progress; then stg_pre "a merge, rebase, cherry-pick or revert is unfinished; finish or abort it first"; fi
  fetch_upstream || stg_pre "$FETCH_ERROR"
  STG_HEAD=$(git -C "$root" rev-parse HEAD 2>/dev/null) || stg_pre "could not read HEAD"
  STG_UP=$(upstream_head) || STG_UP=
  if [ "$STG_HEAD" != "$(meta_val head)" ] || [ -z "$STG_UP" ] || [ "$STG_UP" != "$(meta_val upstream)" ]; then
    stg_pre "the plan is stale (HEAD or upstream moved since --plan); run --plan again"
  fi
  stg_context
  STG_BASE=$(meta_val base)
  [ -r "$stg_dec" ] && [ -f "$stg_dec" ] || stg_pre "the decisions file is missing or unreadable: $stg_dec"
  stg_parse "$stg_dec"
  stg_pathmap
  stg_validate
  if awk -F'\t' '$3 == "true" { f = 1 } END { exit f ? 0 : 1 }' "$state/notes.tsv"; then
    [ -f "$STG_RUN/updates-checks.sh" ] && [ -s "$state/tools/json-valid.sh" ] || stg_pre "a safety note is in the plan, but updates-checks.sh or json-valid.sh is missing, so it cannot be checked" machinery
  fi
  # ---- the transaction
  STG_PRE_HEAD=$STG_HEAD
  STG_PRE_STATUS=$(git -C "$root" status --porcelain 2>/dev/null)
  stg_ts=$(date -u +%Y%m%d-%H%M%S)
  STG_TAG=loom/pre-update-$stg_ts
  stg_n=2
  while git -C "$root" rev-parse -q --verify "refs/tags/$STG_TAG" >/dev/null 2>&1; do
    STG_TAG=loom/pre-update-$stg_ts-$stg_n
    stg_n=$((stg_n + 1))
  done
  git -C "$root" tag "$STG_TAG" "$STG_HEAD" >/dev/null 2>&1 || stg_pre "could not create the pre-update tag"
  STG_WT=$state/wt
  stg_wt_remove
  git -C "$root" worktree add -q --detach "$STG_WT" "$STG_HEAD" >/dev/null 2>&1 || stg_abort worktree "could not create the worktree to build the update in"
  ST_WR=$(ul_mktemp) || exit 1
  : > "$ST_WR"
  stg_rows
  stg_ledger_rows
  stg_ledger_emit
  stg_record_emit
  sy_t=$(ul_mktemp) || exit 1
  printf '%s\n' "$STG_UP" > "$sy_t"
  sy_o=$(write_path "$STG_WT" "$UL_SYNC_REF" "$sy_t" 100644) || stg_abort write "${sy_o#error }"
  git -C "$STG_WT" add -A >/dev/null 2>&1
  if git -C "$STG_WT" diff --cached --quiet; then stg_abort nothing "nothing to apply; you are up to date"; fi
  if [ "${LOOM_TEST_SLEEP_BEFORE_COMMIT:-}" = 1 ]; then
    : > "$state/.test-sleeping"
    sleep 30
  fi
  stg_commit || stg_abort commit "could not commit the update in the worktree"
  stg_holdback
  stg_gate
  # ---- success
  STG_SHA=$(git -C "$STG_WT" rev-parse HEAD 2>/dev/null) || stg_abort commit "could not read the staged commit"
  printf '%s\n' "$STG_SHA" > "$state/staged"
  {
    printf 'tag=%s\n' "$STG_TAG"
    printf 'update_id=%s\n' "$STG_UID"
    printf 'parent=%s\n' "$STG_HEAD"
    printf 'upstream=%s\n' "$STG_UP"
  } > "$state/stage.info"
  printf 'result=staged\n'
  printf 'staged=%s\n' "$STG_SHA"
  printf 'tag=%s\n' "$STG_TAG"
  while IFS= read -r stg_h; do [ -n "$stg_h" ] && printf 'held=%s\n' "$stg_h"; done < "$ST_HELD"
  printf 'changed=%s\n' "$(stg_changed | awk 'END { print NR + 0 }')"
  printf 'land=git merge --ff-only %s\n' "$STG_SHA"
  printf 'update_id=%s\n' "$STG_UID"
  if [ -s "$ST_WARN" ]; then cat "$ST_WARN"; fi
  return 0
}

cmd_abandon() {
  if ! heal_stale; then stg_pre "another update is staging (pid $LOCK_LIVE)"; fi
  if [ ! -f "$state/staged" ]; then
    heal_stale force || :
    if stg_wt_leftover; then
      # an orphan worktree (no `staged`) that the clean-up could not remove is not "nothing staged"
      printf 'result=abandon-incomplete reason=%s\n' "a leftover staging worktree at $state/wt could not be removed (is the folder read-only, or is git unable to prune it?); fix that and run --abandon again"
      exit 1
    fi
    printf 'result=nothing-staged\n'
    return 0
  fi
  ab_sha=$(staged_value)
  if [ "$ab_sha" != none ] && git -C "$root" merge-base --is-ancestor "$ab_sha" HEAD 2>/dev/null; then
    stg_pre "the staged commit already landed on your branch; run --finish or --undo"
  fi
  ab_tag=$(sed -n 's/^tag=//p' "$state/stage.info" 2>/dev/null | sed -n '1p')
  if ! stg_wt_remove; then
    # keep staged and stage.info so --abandon can be run again once the cause is gone
    printf 'result=abandon-incomplete reason=%s\n' "${SW_WHY:-the staging worktree $state/wt could not be removed} (is the folder read-only, or is the update state directory a symlink?); the staged update is kept, fix that and run --abandon again"
    exit 1
  fi
  rm -f "$state/staged" "$state/stage.info" "$state/stage.lock"
  printf 'result=abandoned tag=%s unchanged=yes\n' "${ab_tag:-unknown}"
  return 0
}

# ------------------------------------------------------------ finish and undo
# --finish is the post-landing smoke on the LIVE tree, with an automatic revert when it
# fails. --undo reverses one recorded update from any clone. Both revert with
# `git revert --no-edit <commit>` and then check the CONTENT of every path the update's
# .applied record lists (plus the ledger, the record and .sdd-sync-ref, which travelled
# inside the commit) against the commit's first parent: git's exit code is never trusted
# alone, and a mismatch is reported, never repaired by rewinding history. Nothing here
# pushes, resets or deletes a ref.

fu_log() { printf '%s\n' "$*" >> "$state/last-smoke.log"; }

fu_join() { awk 'NR > 1 { printf "," } { printf "%s", $0 } END { printf "\n" }'; }

fu_rec_path() { # COMMIT -> the .applied record the commit added, nothing when none
  git -C "$root" diff-tree --no-commit-id --name-only -r --diff-filter=A "$1" 2>/dev/null \
    | awk -v d="$UL_APPLIED_DIR/" 'index($0, d) == 1 && substr($0, length(d) + 1) !~ /\// && $0 ~ /\.applied$/ { print; exit }'
}

fu_rec_get() { # COMMIT RECPATH KEY -> the header value
  git -C "$root" show "$1:$2" 2>/dev/null | sed -n "s/^$3=//p" | sed -n '1p'
}

# Fail closed: git's status is checked BEFORE the record is parsed, because a pipe would
# hide it and an empty list reads as "the record lists nothing" -- every verification built
# on it would then pass. Returns 1, printing nothing, when git could not read the record.
fu_rec_paths() { # COMMIT RECPATH -> the content paths the record lists
  frp_t=$(ul_mktemp) || return 1
  git -C "$root" show "$1:$2" > "$frp_t" 2>/dev/null || return 1
  awk -F'\t' 'NF >= 5 { print $1 }' "$frp_t"
}

# Like entry_at, but a git failure is reported (return 1) instead of read as "absent":
# a tree verification that cannot read the tree must fail, not pass.
fu_entry() { # REV PATH -> `mode sha` or `- -`; 1 when git itself failed
  fe_o=$(git --literal-pathspecs -C "$root" ls-tree "$1" -- "$2" 2>/dev/null) || return 1
  fe_l=$(printf '%s\n' "$fe_o" | sed -n '1p')
  if [ -n "$fe_l" ]; then
    fe_meta=${fe_l%%"$ul__tab"*}
    set -- $fe_meta
    if [ "$#" -ge 3 ]; then
      case $2 in blob|commit) printf '%s %s' "$1" "$3"; return 0;; esac
    fi
  fi
  printf '%s' '- -'
}

# The paths whose blob or mode at HEAD is not what COMMIT^ had (absent there -> absent now).
# Fail closed: a path git cannot read on either side counts as mismatched.
fu_mismatch() { # COMMIT RECPATH -> comma-joined, nothing when every path matches
  fm_l=$(ul_mktemp) || exit 1
  fm_rp=$(ul_mktemp) || exit 1
  if ! fu_rec_paths "$1" "$2" > "$fm_rp"; then
    # the record cannot be read, so the revert cannot be verified: that is a mismatch
    printf '%s\n' "record-unreadable"
    return 0
  fi
  { cat "$fm_rp"; printf '%s\n' "$UL_LEDGER" "$2" "$UL_SYNC_REF"; } | LC_ALL=C sort -u > "$fm_l"
  while IFS= read -r fm_p <&3; do
    [ -n "$fm_p" ] || continue
    if ! fm_a=$(fu_entry HEAD "$fm_p") || ! fm_b=$(fu_entry "$1^" "$fm_p"); then
      printf '%s\n' "$fm_p"
      continue
    fi
    [ "$fm_a" = "$fm_b" ] || printf '%s\n' "$fm_p"
  done 3< "$fm_l" | fu_join | sed '/^$/d'
}

# git revert --no-edit COMMIT, then verify. Sets FU_OK (yes|no), FU_MIS (the mismatched
# or conflicting paths, `-` when git refused for another reason), FU_NEW (the revert
# commit when one was made) and FU_ERR. A revert that stopped part way is aborted with
# `git revert --abort`; a revert that "succeeded" over wrong content is left as a commit.
# The customer's git hooks are switched off exactly as the staging worktree's commits
# are (core.hooksPath at /dev/null, signing off): a pre-commit or post-commit hook must
# not be able to change what the revert leaves behind.
fu_revert() { # COMMIT RECPATH
  FU_OK=no; FU_MIS=; FU_NEW=; FU_ERR=
  fr_out=$(git -C "$root" -c core.hooksPath=/dev/null -c commit.gpgsign=false revert --no-edit "$1" 2>&1)
  fr_rc=$?
  FU_ERR=$(printf '%s\n' "$fr_out" | sed -n '1p')
  if [ "$fr_rc" -eq 0 ]; then
    FU_NEW=$(git -C "$root" rev-parse HEAD 2>/dev/null)
    FU_MIS=$(fu_mismatch "$1" "$2")
    [ -n "$FU_MIS" ] || FU_OK=yes
    return 0
  fi
  fr_cf=$(git -C "$root" diff --name-only --diff-filter=U 2>/dev/null | LC_ALL=C sort -u | fu_join | sed '/^$/d')
  if in_progress; then git -C "$root" revert --abort >/dev/null 2>&1; fi
  FU_MIS=$fr_cf
  [ -n "$FU_MIS" ] || FU_MIS=$(fu_mismatch "$1" "$2")
  [ -n "$FU_MIS" ] || FU_MIS=-
  return 0
}

# The staged update is finished, one way or another. The retry markers (staged, stage.info)
# go only when the worktree clean-up really finished: otherwise they stay, FU_CLEAN says
# why and this returns 1, so the caller keeps its primary result (the update WAS applied,
# reverted or moved on) but adds the cleanup=incomplete line and exits non-zero.
FU_CLEAN=
fu_clear_state() {
  FU_CLEAN=
  if stg_wt_remove; then
    rm -f "$state/staged" "$state/stage.info"
    return 0
  fi
  FU_CLEAN=$SW_WHY
  fu_log "cleanup incomplete: $FU_CLEAN; staged and stage.info are kept so --finish or --abandon can be run again"
  return 1
}

fu_cleanup_line() { # prints the cleanup=incomplete line when fu_clear_state failed
  if [ -n "$FU_CLEAN" ]; then
    printf 'cleanup=incomplete reason=%s; staged and stage.info are kept, so run --finish or --abandon again once that is fixed\n' "$FU_CLEAN"
  fi
}

# ---- the smoke. Sets SM_REASON (checks|invariants|json|hooks-resolve|harness-diff) and
# SM_DETAIL on failure. Every step is logged to last-smoke.log. Stops at the first failure.
fin_smoke() { # COMMIT RECPATH UPSTREAM
  SM_REASON=; SM_DETAIL=
  fs_commit=$1; fs_up=$3
  fs_tools=$state/tools
  if [ ! -s "$fs_tools/json-flat.sh" ] || [ ! -s "$fs_tools/json-valid.sh" ]; then fs_tools=$root/$UL_SCRIPTS_DIR; fi
  # 1. every note's own check, run by the live checks runner
  fs_ck=$root/$UL_SCRIPTS_DIR/updates-checks.sh
  if [ -f "$fs_ck" ]; then
    cg_begin
    fs_o=$(cd "$root" && $UL_SH "$fs_ck" --root "$root" 2>&1)
    fs_rc=$?
    cg_end
    fu_log "-- checks (exit $fs_rc)"
    printf '%s\n' "$fs_o" >> "$state/last-smoke.log"
    if [ -n "$CG_W" ]; then
      fu_log "-- checks: a check wrote $CG_W (detection, not a sandbox)"
      SM_REASON=checks; SM_DETAIL="a check wrote $CG_W (check-wrote=$CG_W)"; return 1
    fi
    fs_f=$(printf '%s\n' "$fs_o" | sed -n 's/^FAIL //p' | tr '\n' ' ')
    if [ -n "$fs_f" ]; then SM_REASON=checks; SM_DETAIL="failed: $fs_f"; return 1; fi
    if [ "$fs_rc" -ne 0 ]; then SM_REASON=checks; SM_DETAIL="the checks runner exited $fs_rc"; return 1; fi
  elif awk -F'\t' '$3 == "true" { f = 1 } END { exit f ? 0 : 1 }' "$state/notes.tsv" 2>/dev/null; then
    fu_log "-- checks: updates-checks.sh is missing and a safety note is in the update"
    SM_REASON=checks; SM_DETAIL="a safety note is in the update but updates-checks.sh is missing"; return 1
  else
    fu_log "-- checks: updates-checks.sh is missing; no safety note, skipped"
  fi
  # 2. the security-invariants on every security surface the commit touched
  fs_ids=$(git -C "$root" show "$fs_commit:$UL_LEDGER" 2>/dev/null | awk -F'\t' -v up="$fs_up" '$4 == up && $2 == "applied" { print $1 }' | LC_ALL=C sort -u | fu_join | sed '/^$/d')
  fs_ch=$(ul_mktemp) || exit 1
  if ! git -C "$root" diff-tree --no-commit-id --name-only -r "$fs_commit" > "$fs_ch" 2>/dev/null; then
    fu_log "-- invariants: git could not list the paths the update commit changed"
    SM_REASON=invariants; SM_DETAIL="git could not list the paths the update commit changed, so the security surfaces cannot be checked"; return 1
  fi
  while IFS= read -r fs_p; do
    ul_path_security_surface "$fs_p" && printf '%s\n' "$fs_p"
  done < "$fs_ch" > "$state/.surfaces"
  while IFS= read -r fs_p <&3; do
    [ -n "$fs_p" ] || continue
    set -- $(entry_at "$fs_commit^" "$fs_p")
    fs_hm=$1; fs_hs=$2
    if [ ! -f "$root/$fs_p" ]; then
      if [ "$fs_hs" = - ]; then continue; fi
      rm -f "$state/.surfaces"
      fu_log "-- invariants: $fs_p was removed"
      SM_REASON=invariants; SM_DETAIL="$fs_p was removed, and a security surface may not be"; return 1
    fi
    set -- $(entry_at "$fs_up" "$(as_upstream_name "$fs_p")")
    fs_ts=$2
    if [ "$fs_ts" != - ] && [ "$(git -C "$root" hash-object -- "$root/$fs_p" 2>/dev/null)" = "$fs_ts" ]; then
      fu_log "-- invariants: $fs_p is upstream's own file; accepted"
      continue
    fi
    if ! inv_inputs "${fs_ids:--}"; then
      rm -f "$state/.surfaces"
      SM_REASON=invariants; SM_DETAIL=$INV_ERR; return 1
    fi
    fs_m=$(ul_mktemp) || exit 1
    fs_th=$(ul_mktemp) || exit 1
    set -- --surface "$fs_p"
    if [ "$fs_hs" != - ]; then git -C "$root" cat-file blob "$fs_hs" > "$fs_m" 2>/dev/null; set -- "$@" --mine "$fs_m"; fi
    if [ "$fs_ts" != - ]; then git -C "$root" cat-file blob "$fs_ts" > "$fs_th" 2>/dev/null; set -- "$@" --theirs "$fs_th"; fi
    set -- "$@" --candidate "$root/$fs_p" --tools "$fs_tools" --relaxes "$INV_RX" --removes "$INV_RM" --may-drop-headings "$INV_MD"
    if [ ! -f "$here/security-invariants.sh" ]; then
      rm -f "$state/.surfaces"
      SM_REASON=invariants; SM_DETAIL="security-invariants.sh is missing, so $fs_p cannot be checked"; return 1
    fi
    fs_o=$($UL_SH "$here/security-invariants.sh" "$@" 2>&1)
    fs_rc=$?
    fu_log "-- invariants $fs_p (exit $fs_rc)"
    printf '%s\n' "$fs_o" >> "$state/last-smoke.log"
    if [ "$fs_rc" -ne 0 ]; then
      rm -f "$state/.surfaces"
      SM_REASON=invariants; SM_DETAIL="$fs_p: $(printf '%s\n' "$fs_o" | tail -1)"; return 1
    fi
  done 3< "$state/.surfaces"
  rm -f "$state/.surfaces"
  # 3. settings.json is valid JSON
  if [ -f "$root/.claude/settings.json" ]; then
    if [ -s "$fs_tools/json-valid.sh" ]; then
      if ! $UL_SH "$fs_tools/json-valid.sh" "$root/.claude/settings.json" >/dev/null 2>&1; then
        fu_log "-- json: settings.json is not valid JSON"
        SM_REASON=json; SM_DETAIL="settings.json is not valid JSON"; return 1
      fi
    elif grep -Fxq .claude/settings.json "$fs_ch"; then
      fu_log "-- json: settings.json changed but json-valid.sh is missing"
      SM_REASON=json; SM_DETAIL="settings.json changed but json-valid.sh is missing"; return 1
    fi
  fi
  # 4. every hook script settings.json names resolves (the same function as the stage gate)
  HK_WARN=$state/last-smoke.log
  if ! hk_resolve "$root" "$fs_tools/json-flat.sh"; then
    fu_log "-- hooks-resolve: $HK_MSG"
    SM_REASON=hooks-resolve; SM_DETAIL=$HK_MSG; return 1
  fi
  # 5. no tracked file the update owns differs from the commit
  FS_DIFF=$(fu_dirty "$fs_commit")
  if [ -n "$FS_DIFF" ]; then
    fu_log "-- harness-diff: tracked files differ from the update commit (a checkout-time line-ending change, or an edit made after landing):"
    printf '%s\n' "$FS_DIFF" >> "$state/last-smoke.log"
    SM_REASON=harness-diff; SM_DETAIL=$(printf '%s\n' "$FS_DIFF" | fu_join); return 1
  fi
  fu_log "-- smoke passed"
  return 0
}

# Tracked files whose working-tree content differs from HEAD and which the update owns:
# under a harness prefix, or touched by the update commit itself (settings.json is a merge
# path, not a harness prefix, but the update just rewrote it). Untracked files and the
# customer's other edits are never listed. Fail closed: when git cannot answer, the one
# line `git diff failed ...` is printed, which is a difference, never "nothing differs".
# Since --finish refuses a dirty tree first, this is a belt-and-braces re-verification of
# the tree the smoke just judged; it cannot fire on a clean tree unless git itself errs.
fu_dirty() { # COMMIT
  fd_ch=$(ul_mktemp) || exit 1
  fd_df=$(ul_mktemp) || exit 1
  if ! git -C "$root" diff-tree --no-commit-id --name-only -r "$1" > "$fd_ch" 2>/dev/null \
     || ! git -C "$root" diff --name-only HEAD > "$fd_df" 2>/dev/null; then
    printf '%s\n' 'git diff failed (the tree could not be verified against the update commit)'
    return 0
  fi
  while IFS= read -r fd_p <&3; do
    [ -n "$fd_p" ] || continue
    if grep -Fxq -- "$fd_p" "$fd_ch" || path_in_harness "$fd_p"; then printf '%s\n' "$fd_p"; fi
  done 3< "$fd_df"
}

# --finish's dirty-tree gate: tracked changes in the working tree OR the index, and
# untracked files under a harness prefix (the same test --stage and --undo apply). Runs
# before anything is acquired or run, and nothing is ever checked out over the customer's
# edits: a revert that cannot proceed over them is refused by git itself.
fin_dirty_refuse() {
  fd_o=$(clean_offenders)
  [ -n "$fd_o" ] || return 0
  if status_failed "$fd_o"; then
    printf 'result=refused reason=dirty-tree paths=git-status-failed\n'
  else
    printf 'result=refused reason=dirty-tree paths=%s\n' "$(printf '%s\n' "$fd_o" | awk 'NF { print substr($0, 4) }' | fu_join)"
  fi
  printf 'note=commit or stash your changes, then run --finish again; nothing was run and nothing was changed\n'
  exit 1
}

# Sets FI_SHA, FI_HEAD and FI_KIND: none (nothing staged) | landed (HEAD is the staged
# commit) | movedon (the staged commit is in HEAD's history) | notlanded.
fin_look() {
  FI_SHA=$(staged_value)
  FI_HEAD=$(git -C "$root" rev-parse HEAD 2>/dev/null) || { echo "error could not read HEAD"; exit 1; }
  if [ "$FI_SHA" = none ]; then
    FI_KIND=none
  elif [ "$FI_SHA" = "$FI_HEAD" ]; then
    FI_KIND=landed
  elif git -C "$root" merge-base --is-ancestor "$FI_SHA" HEAD 2>/dev/null; then
    FI_KIND=movedon
  else
    FI_KIND=notlanded
  fi
}

# The record and the values the smoke needs, from the staged commit. FI_REC empty when
# the commit carries no .applied record.
fin_prepare() { # COMMIT
  fi_rec=$(fu_rec_path "$1")
  fi_uid=; fi_tag=; fi_up=
  if [ -n "$fi_rec" ]; then
    fi_uid=$(fu_rec_get "$1" "$fi_rec" update_id)
    fi_tag=$(fu_rec_get "$1" "$fi_rec" tag)
    fi_up=$(fu_rec_get "$1" "$fi_rec" upstream)
  fi
  CHANNEL=$(meta_val channel)
  [ -n "$CHANNEL" ] || { resolve_channel; CHANNEL=$CH; }
  channel_map_load
  plan_maps_load
}

cmd_finish() {
  if [ "$#" -ne 0 ]; then echo "error --finish takes no arguments"; exit 2; fi
  state_dir_safe || stg_pre "the update state directory is, or sits under, a symlink; refusing to use it"
  if ! heal_stale; then stg_pre "another update is staging (pid $LOCK_LIVE)"; fi
  # ---- a first, read-only look: the answers that need no lock and change nothing
  fin_look
  case $FI_KIND in
    none|notlanded)
      printf 'result=not-landed staged=%s head=%s\n' "$FI_SHA" "$FI_HEAD"
      exit 1;;
    landed) fin_dirty_refuse;;
  esac
  # ---- take the lock, THEN read staged and HEAD again: that is the reading acted on
  lock_acquire keep || stg_pre "another update is staging"
  fin_look
  case $FI_KIND in
    none|notlanded)
      printf 'result=not-landed staged=%s head=%s\n' "$FI_SHA" "$FI_HEAD"
      exit 1;;
    movedon) fin_moved_on;;
    landed) fin_dirty_refuse;;
  esac
  fi_sha=$FI_SHA
  fin_prepare "$fi_sha"
  [ -n "$fi_rec" ] || stg_pre "the staged commit carries no .applied record"
  { [ -n "$fi_uid" ] && [ -n "$fi_up" ]; } || stg_pre "the staged commit's .applied record could not be read from git"
  fu_log "=== finish $(date -u +%Y-%m-%dT%H:%M:%SZ) commit=$fi_sha tag=$fi_tag update_id=$fi_uid"
  if fin_smoke "$fi_sha" "$fi_rec" "$fi_up"; then
    fi_held=$(git -C "$root" show "$fi_sha:$UL_LEDGER" 2>/dev/null | awk -F'\t' -v up="$fi_up" '$4 == up && $2 == "held" { print $1 }' | LC_ALL=C sort -u | fu_join | sed '/^$/d')
    fu_clear_state || :
    printf 'result=applied commit=%s tag=%s update_id=%s held=%s\n' "$fi_sha" "$fi_tag" "$fi_uid" "${fi_held:-none}"
    fu_cleanup_line
    if [ -n "$FU_CLEAN" ]; then exit 1; fi
    printf 'next=run /git-push when ready\n'
    return 0
  fi
  # ---- the smoke failed: revert the landed commit, silently, and verify by content
  fu_log "smoke failed: $SM_REASON: $SM_DETAIL"
  if [ "${LOOM_TEST_PAUSE_BEFORE_REVERT:-}" = 1 ]; then
    # test-only: stop here until state/.test-go exists, so a case can move HEAD
    : > "$state/.test-paused"
    fi_w=0
    while [ ! -e "$state/.test-go" ] && [ "$fi_w" -lt 60 ]; do sleep 1; fi_w=$((fi_w + 1)); done
    rm -f "$state/.test-paused" "$state/.test-go"
  fi
  # HEAD is read again right before the revert: if anything moved it during the smoke,
  # the revert would undo the wrong thing, so none is attempted. The sub-second window
  # between this read and `git revert` below is accepted: closing it would need a lock
  # git itself does not offer, and a revert that meets a changed tree conflicts, is
  # aborted and is reported (reverted-failed), never forced.
  fi_now=$(git -C "$root" rev-parse HEAD 2>/dev/null)
  if [ "$fi_now" != "$fi_sha" ]; then
    fu_log "HEAD moved during the smoke ($fi_sha -> ${fi_now:-unreadable}); no revert attempted"
    fu_clear_state || :
    printf 'result=reverted-failed pre_update_tag=%s mismatched=- reason=head-moved head=%s log=%s/last-smoke.log\n' \
      "$fi_tag" "${fi_now:-unknown}" "$state"
    printf 'detail=the smoke failed (%s: %s) and HEAD moved while it ran, so no revert was attempted\n' "$SM_REASON" "$SM_DETAIL"
    fu_cleanup_line
    printf 'note=nothing was reverted; --undo reverses the update, and the tag above is the way back\n'
    exit 1
  fi
  fu_revert "$fi_sha" "$fi_rec"
  fu_log "revert: ok=$FU_OK new=$FU_NEW mismatched=${FU_MIS:--} git=$FU_ERR"
  fu_clear_state || :
  if [ "$FU_OK" = yes ]; then
    printf 'result=reverted reason=%s tag=%s log=%s/last-smoke.log\n' "$SM_REASON" "$fi_tag" "$state"
    printf 'detail=%s\n' "$SM_DETAIL"
    printf 'revert=%s\n' "$FU_NEW"
    fu_cleanup_line
    exit 1
  fi
  printf 'result=reverted-failed pre_update_tag=%s mismatched=%s reason=%s head=%s log=%s/last-smoke.log\n' \
    "$fi_tag" "$FU_MIS" "$SM_REASON" "$(git -C "$root" rev-parse HEAD 2>/dev/null)" "$state"
  printf 'detail=%s\n' "$SM_DETAIL"
  printf 'note=nothing was rewound; a person decides from here, and the tag above is the way back\n'
  fu_cleanup_line
  exit 1
}

# HEAD has moved past the staged commit: nothing is reverted automatically, but the smoke
# still runs, report-only, against the current tree, so landed settings and hooks are
# never left unchecked in silence. The staged state is cleared either way.
fin_moved_on() {
  SM_REASON=; SM_DETAIL=
  fin_prepare "$FI_SHA"
  mo_line=
  if [ -z "$fi_rec" ]; then
    mo_line='smoke=skipped reason=no-record'
  elif [ -z "$fi_uid" ] || [ -z "$fi_up" ]; then
    mo_line='smoke=skipped reason=record-unreadable'
  else
    fu_log "=== finish (moved-on, report-only smoke) $(date -u +%Y-%m-%dT%H:%M:%SZ) commit=$FI_SHA head=$FI_HEAD"
    if fin_smoke "$FI_SHA" "$fi_rec" "$fi_up"; then
      mo_line='smoke=passed'
    else
      mo_line="smoke=failed reason=$SM_REASON"
      fu_log "smoke failed (report-only): $SM_REASON: $SM_DETAIL"
    fi
  fi
  fu_clear_state || :
  printf 'result=moved-on staged=%s head=%s\n' "$FI_SHA" "$FI_HEAD"
  printf '%s\n' "$mo_line"
  if [ "$mo_line" != 'smoke=passed' ] && [ -n "$SM_DETAIL" ]; then printf 'detail=%s\n' "$SM_DETAIL"; fi
  printf 'note=the staged commit is in your history but HEAD has moved past it, so nothing was reverted automatically; the smoke above is report-only (log: %s/last-smoke.log); --undo reverses the update\n' "$state"
  fu_cleanup_line
  exit 1
}

ud_refuse() { # REASON [SUFFIX]
  printf 'result=refused reason=%s%s\n' "$1" "${2:+ $2}"
  exit 1
}

cmd_undo() { # [UPDATE-ID]
  if [ "$#" -gt 1 ]; then echo "error --undo takes at most one update id"; exit 2; fi
  ud_id=${1:-}
  if ! heal_stale; then stg_pre "another update is staging (pid $LOCK_LIVE)"; fi
  [ ! -f "$state/staged" ] || ud_refuse "a staged update exists; run --finish or --abandon first"
  if in_progress; then ud_refuse "a merge, rebase, cherry-pick or revert is unfinished; finish or abort it first"; fi
  ud_off=$(clean_offenders)
  if [ -n "$ud_off" ]; then
    if status_failed "$ud_off"; then ud_refuse "git status failed in this repository"; fi
    ud_refuse "your working tree has uncommitted changes: $(offender_paths "$ud_off")"
  fi
  ud_list=$(ul_mktemp) || exit 1
  git -C "$root" ls-tree --name-only "HEAD:$UL_APPLIED_DIR" 2>/dev/null | awk '/\.applied$/ { sub(/\.applied$/, ""); print }' | LC_ALL=C sort > "$ud_list"
  if [ -z "$ud_id" ]; then
    ud_id=$(tail -n 1 "$ud_list")
    if [ -z "$ud_id" ]; then
      printf 'result=nothing-to-undo\n'
      return 0
    fi
  else
    case $ud_id in *[!A-Za-z0-9._-]*|.*) ud_refuse "that is not an update id: $ud_id";; esac
    grep -Fxq -- "$ud_id" "$ud_list" || ud_refuse "no record for update $ud_id in this branch"
  fi
  ud_rec=$UL_APPLIED_DIR/$ud_id.applied
  # ---- find the one commit that added the record, and make sure it is an update commit
  ud_adds=$(git --literal-pathspecs -C "$root" log --diff-filter=A --format=%H HEAD -- "$ud_rec" 2>/dev/null)
  ud_n=$(printf '%s\n' "$ud_adds" | awk 'NF { n++ } END { print n + 0 }')
  [ "$ud_n" -eq 1 ] || ud_refuse "the update commit cannot be found ($ud_n commits add $ud_rec)"
  ud_c=$ud_adds
  case $(git -C "$root" log -1 --format=%s "$ud_c" 2>/dev/null) in
    "LogicLoom update to"*) ;;
    *) ud_refuse "the commit that added $ud_rec does not look like an update commit";;
  esac
  ud_par=$(git -C "$root" rev-parse -q --verify "$ud_c^1" 2>/dev/null)
  if [ -z "$ud_par" ] || [ "$ud_par" != "$(fu_rec_get "$ud_c" "$ud_rec" parent)" ]; then
    ud_refuse "the update commit's first parent does not match the record's parent line"
  fi
  if [ "$(git -C "$root" rev-parse "$ud_c:$ud_rec" 2>/dev/null)" != "$(git -C "$root" rev-parse "HEAD:$ud_rec" 2>/dev/null)" ]; then
    ud_refuse "the record at HEAD is not the one the update commit added (the record was edited since)"
  fi
  git -C "$root" merge-base --is-ancestor "$ud_c" HEAD 2>/dev/null || ud_refuse "the update commit is not part of this branch's history"
  # ---- newer updates sit above it
  ud_newer=$(awk -v id="$ud_id" '$0 > id' "$ud_list" | LC_ALL=C sort | fu_join | sed '/^$/d')
  if [ -n "$ud_newer" ]; then
    ud_refuse "undoing an older update beneath newer ones is refused; undo the newer ones first" "newer=$ud_newer"
  fi
  # ---- the forbidden set, in the record and in the commit itself
  # Paths are read a line at a time: a path with a space in it stays one path.
  ud_bad=
  ud_paths=$(ul_mktemp) || exit 1
  fu_rec_paths "$ud_c" "$ud_rec" > "$ud_paths" || ud_refuse "the update record could not be read from git"
  while IFS= read -r ud_p <&3; do
    [ -n "$ud_p" ] || continue
    if ul_path_forbidden "$ud_p"; then ud_bad=${ud_bad:+$ud_bad,}$ud_p; fi
  done 3< "$ud_paths"
  ud_touched=$(ul_mktemp) || exit 1
  git -C "$root" -c core.quotepath=off diff-tree --no-commit-id --name-only -r "$ud_c" > "$ud_touched" 2>/dev/null
  while IFS= read -r ud_p <&3; do
    [ -n "$ud_p" ] || continue
    case $ud_p in "$UL_LEDGER"|"$UL_SYNC_REF"|"$UL_APPLIED_DIR"/*) continue;; esac
    if ul_path_forbidden "$ud_p"; then ud_bad=${ud_bad:+$ud_bad,}$ud_p; fi
  done 3< "$ud_touched"
  [ -z "$ud_bad" ] || ud_refuse "the update touches a path no update may touch" "paths=$ud_bad (forbidden)"
  # ---- later changes to any recorded path. A path a later commit touched counts as
  # overlapping unless it is, byte for byte and mode for mode, what the update left (an
  # edit that was put back, or the undo of a newer update that touched the same file).
  ud_ov=
  while IFS= read -r ud_p <&3; do
    [ -n "$ud_p" ] || continue
    # fail closed: a path git cannot read on either side counts as overlapping
    if ! ud_lg=$(git --literal-pathspecs -C "$root" log --format=%H -n 1 "$ud_c..HEAD" -- "$ud_p" 2>/dev/null); then
      ud_ov=${ud_ov:+$ud_ov,}$ud_p
    elif [ -n "$ud_lg" ]; then
      if ! ud_ea=$(fu_entry HEAD "$ud_p") || ! ud_eb=$(fu_entry "$ud_c" "$ud_p") || [ "$ud_ea" != "$ud_eb" ]; then
        ud_ov=${ud_ov:+$ud_ov,}$ud_p
      fi
    fi
  done 3< "$ud_paths"
  [ -z "$ud_ov" ] || ud_refuse "later changes overlap the update" "paths=$ud_ov"
  lock_acquire || stg_pre "another update is staging"
  ud_tag=$(fu_rec_get "$ud_c" "$ud_rec" tag)
  fu_revert "$ud_c" "$ud_rec"
  if [ "$FU_OK" = yes ]; then
    printf 'result=undone commit=%s undid=%s update_id=%s\n' "$FU_NEW" "$ud_c" "$ud_id"
    printf 'note=the ledger, the .applied record and .sdd-sync-ref were inside the update commit, so they are restored with it\n'
    return 0
  fi
  printf 'result=reverted-failed mismatched=%s pre_update_tag=%s head=%s\n' "$FU_MIS" "${ud_tag:-unknown}" "$(git -C "$root" rev-parse HEAD 2>/dev/null)"
  printf 'note=nothing was rewound; a person decides from here\n'
  exit 1
}

cmd_selftest_tree_gate() { # WT
  [ -d "${1:-}" ] || { echo "error --selftest-tree-gate needs a worktree"; exit 2; }
  if stg_treegate "$1"; then printf 'tree-gate=ok\n'; else printf 'tree-gate=mismatch tree=%s\n' "$TG_BAD"; fi
}

cmd_selftest_allowlist() { # WT DECISIONS
  [ -d "${1:-}" ] && [ -f "${2:-}" ] || { echo "error --selftest-allowlist takes WT DECISIONS"; exit 2; }
  stg_context
  stg_parse "$2"
  stg_pathmap
  ST_HELD=$(ul_mktemp) || exit 1
  : > "$ST_HELD"
  if stg_allowlist "$1"; then printf 'allowlist=ok\n'; else printf 'allowlist=violation path=%s\n' "$AL_BAD"; fi
}

# ------------------------------------------------------------- test-only
cmd_selftest_channel() {
  resolve_channel
  printf 'channel=%s\n' "$CHANNEL"
  if [ -n "$CH_NOTICE" ]; then printf 'notice=%s\n' "$CH_NOTICE"; fi
  printf 'groups=%s\n' "$CH_GROUPS"
}

cmd_selftest_map() { # dump [--builtin] | path PATH
  case ${1:-} in
    dump)
      [ "${2:-}" = --builtin ] && FORCE_BUILTIN=1
      channel_map_load
      cat "$UL_MAP";;
    path)
      [ -n "${2:-}" ] || { echo "error --selftest-map path needs a path"; exit 2; }
      channel_map_load
      sm_g=$(path_harness_group "$2"); [ -n "$sm_g" ] || sm_g=-
      sm_e=no; path_adopt_excluded "$2" && sm_e=yes
      sm_m=no; path_is_merge "$2" && sm_m=yes
      sm_r=$(path_rename "$2"); [ -n "$sm_r" ] || sm_r=-
      printf 'group=%s excluded=%s merge=%s rename=%s\n' "$sm_g" "$sm_e" "$sm_m" "$sm_r";;
    *) echo "error --selftest-map takes dump or path"; exit 2;;
  esac
}

cmd_selftest_lock() { # [SECONDS]
  lock_acquire || exit 1
  printf 'lock=acquired pid=%s\n' "$$"
  sl_i=0
  while [ "$sl_i" -lt "${1:-0}" ]; do
    sleep 1
    sl_i=$((sl_i + 1))
  done
  return 0
}

# ----------------------------------------------------------------- dispatch
case $cmd in
  --status) cmd_status;;
  --detect-base) cmd_detect_base;;
  --set-base) cmd_set_base "$@";;
  --bootstrap-copy) cmd_bootstrap_copy;;
  --plan) cmd_plan;;
  --adapt-save) cmd_adapt_save "$@";;
  --mark-unresolved) cmd_mark_unresolved "$@";;
  --stage) cmd_stage "$@";;
  --abandon) cmd_abandon;;
  --finish) cmd_finish "$@";;
  --undo) cmd_undo "$@";;
  --selftest-tree-gate) cmd_selftest_tree_gate "$@";;
  --selftest-allowlist) cmd_selftest_allowlist "$@";;
  --selftest-write-path)
    if [ "$#" -ne 4 ]; then echo "error --selftest-write-path takes WT PATH SRC MODE"; exit 2; fi
    write_path "$1" "$2" "$3" "$4" || exit 1
    printf 'written=%s\n' "$2";;
  --selftest-lock) cmd_selftest_lock "$@";;
  --selftest-channel) cmd_selftest_channel;;
  --selftest-map) cmd_selftest_map "$@";;
  --selftest-two-way) cmd_selftest_two_way "$@";;
  --selftest-remap) printf '%s\n' "$(remap_known_bad "${1:-}")";;
esac
exit 0
