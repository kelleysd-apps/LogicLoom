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
# Not built yet (they print `error not implemented`): --plan --adapt-save
# --mark-unresolved --stage --abandon --finish --undo.
#
# TEST-ONLY subcommands (no skill or command uses them; the cases do, so every
# helper has an assertion that fails without it):
#   --selftest-write-path WT PATH SRC MODE   write_path
#   --selftest-lock [SECONDS]                lock_acquire, hold, exit-trap release
#   --selftest-channel                       the resolved channel, notice and groups
#   --selftest-map dump [--builtin]          the parsed channel map
#   --selftest-map path PATH                 group / excluded / merge / rename of PATH
#   --selftest-remap SHA                     the known-bad stamp table
#
# Global options (accepted before or after the subcommand):
#   --upstream-url <url>           refused unless --i-am-pointing-at-a-fork is also given
#   --i-am-pointing-at-a-fork
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
ul_exit() { # the EXIT trap: release a held lock, then the shared temp cleanup
  lock_release
  ul_cleanup
}
trap ul_exit EXIT

usage() {
  cat <<'ULUSAGEEOF'
Usage: update-loom.sh [--upstream-url URL --i-am-pointing-at-a-fork] [--channel template|adopted] <subcommand>

  --status              channel, upstream, base, tree state, bundle and engine status
  --detect-base         which upstream commit this copy was last updated from
  --set-base <sha>      record that commit in .sdd-sync-ref
  --bootstrap-copy      copy upstream's engine into <gitdir>/loom/bootstrap/
  --plan                (not built yet) classify every path and the offered notes
  --adapt-save          (not built yet) validate and save an adapted file
  --mark-unresolved     (not built yet)
  --stage               (not built yet) build the update commit in a detached worktree
  --abandon             (not built yet)
  --finish              (not built yet)
  --undo                (not built yet)
  --help                this text
ULUSAGEEOF
}

# ------------------------------------------------------ global option scan
OPT_URL=
OPT_CHANNEL=
OPT_FORK=0
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
    *) set -- "$@" "$ul_a";;
  esac
done

cmd=${1:-}
[ "$#" -gt 0 ] && shift

case $cmd in
  --help|-h) usage; exit 0;;
  --status|--detect-base|--set-base|--bootstrap-copy|--plan|--adapt-save|--mark-unresolved|--stage|--abandon|--finish|--undo) ;;
  --selftest-write-path|--selftest-lock|--selftest-channel|--selftest-map|--selftest-remap) ;;
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
  if [ -d "$hs_wt" ]; then
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

lock_acquire() {
  mkdir -p "$state" || { echo "error could not create $state"; return 1; }
  if ! heal_stale force; then
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
  db_rec=$(recorded_stamp)
  db_sh=no; is_shallow && db_sh=yes
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
  --plan|--adapt-save|--mark-unresolved|--stage|--abandon|--finish|--undo)
    echo "error not implemented"
    exit 1;;
  --selftest-write-path)
    if [ "$#" -ne 4 ]; then echo "error --selftest-write-path takes WT PATH SRC MODE"; exit 2; fi
    write_path "$1" "$2" "$3" "$4" || exit 1
    printf 'written=%s\n' "$2";;
  --selftest-lock) cmd_selftest_lock "$@";;
  --selftest-channel) cmd_selftest_channel;;
  --selftest-map) cmd_selftest_map "$@";;
  --selftest-remap) printf '%s\n' "$(remap_known_bad "${1:-}")";;
esac
exit 0
