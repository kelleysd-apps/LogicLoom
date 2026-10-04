#!/bin/sh
# Test harness for the /update-loom engine family. POSIX sh, SOURCED by every
# tests/update-loom/cases-*.sh with `here` set to tests/update-loom:
#
#   here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
#   . "$here/lib.sh"
#   ... cases ...
#   ul_t_done
#
# It provides assertions (ul_t_check and friends), throwaway repos, and the
# fixture-world builder. It deliberately knows NOTHING about the engine's own
# subcommands beyond the runner ul_t_run_engine, so a later package cannot be
# surprised by what this file assumes.
#
# Hermetic git: the user's global and system git config (hooks, signing,
# templates) must never reach a fixture repo, so both are disabled for every
# git this harness (and the engine it runs) starts.

set -u

UL_T_DIR=${here:?lib.sh needs here=<tests/update-loom>}
UL_T_ROOT=$(CDPATH= cd -- "$UL_T_DIR/../.." && pwd)
UL_T_FIX=$UL_T_DIR/fixtures
SH=${LOOM_TEST_SH:-/bin/sh}
fail=0

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
GIT_CONFIG_NOSYSTEM=1
GIT_CONFIG_GLOBAL=/dev/null
GIT_TERMINAL_PROMPT=0
export GIT_CONFIG_NOSYSTEM GIT_CONFIG_GLOBAL GIT_TERMINAL_PROMPT

# ------------------------------------------------------------------ temp files
# A file-backed registry, so a temp made inside $(...) is still cleaned up.
UL_T_REG=$(mktemp "${TMPDIR:-/tmp}/ul-t-registry.XXXXXX") || {
  echo "error could not create a temp registry under ${TMPDIR:-/tmp}" >&2
  exit 1
}

ul_t_tmp() { # -> prints a fresh temp directory (registered for cleanup)
  ul_tt_d=$(mktemp -d "${TMPDIR:-/tmp}/ul-t.XXXXXX") || return 1
  printf '%s\n' "$ul_tt_d" >> "$UL_T_REG"
  printf '%s' "$ul_tt_d"
}

ul_t_cleanup() {
  if [ -f "$UL_T_REG" ]; then
    while IFS= read -r ul_tc_d; do
      case $ul_tc_d in
        "${TMPDIR:-/tmp}"/ul-t.*) chmod -R u+w "$ul_tc_d" 2>/dev/null; rm -rf "$ul_tc_d";;
      esac
    done < "$UL_T_REG"
    rm -f "$UL_T_REG"
  fi
  if command -v ul_cleanup >/dev/null 2>&1; then ul_cleanup; fi
  return 0
}
trap ul_t_cleanup EXIT
trap 'ul_t_cleanup; exit 130' INT
trap 'ul_t_cleanup; exit 143' TERM

# ------------------------------------------------------------------ assertions
ul_t_check() { # NAME CMD... : PASS/FAIL line; a FAIL sets fail=1
  ul_tk_n=$1; shift
  if "$@"; then
    printf 'PASS  %s\n' "$ul_tk_n"
  else
    printf 'FAIL  %s\n' "$ul_tk_n"
    fail=1
  fi
}
ul_t_has() { printf '%s\n' "$1" | grep -q -- "$2"; }          # STR PATTERN (BRE)
ul_t_hasnt() { ! printf '%s\n' "$1" | grep -q -- "$2"; }      # STR PATTERN (BRE)
ul_t_hasline() { printf '%s\n' "$1" | grep -Fxq -- "$2"; }    # STR LINE (whole-line, literal)
ul_t_eq() { [ "$1" = "$2" ]; }                                 # A B
ul_t_not() { ! "$@"; }                                         # CMD... : succeeds when CMD fails
ul_t_done() { # call last: exit status is the overall result
  if [ "$fail" = 0 ]; then exit 0; fi
  exit 1
}

# ------------------------------------------------------------------ throwaway git
ul_t_git_config() { # DIR
  git -C "$1" config user.email t@example.invalid
  git -C "$1" config user.name t
  git -C "$1" config commit.gpgsign false
  git -C "$1" config core.autocrlf false
}

ul_t_git_init() { # DIR : an empty repo whose branch is main
  mkdir -p "$1" || return 1
  git -c init.defaultBranch=main init -q "$1" || return 1
  ul_t_git_config "$1"
  git -C "$1" symbolic-ref HEAD refs/heads/main
}

ul_t_commit() { # DIR MSG : stage everything, commit, print the sha
  git -C "$1" add -A || return 1
  git -C "$1" commit -q --allow-empty -m "$2" || return 1
  git -C "$1" rev-parse HEAD
}

# ---------------------------------------------------------------- engine files
# The scripts of the family, in bundle order. Only those that exist in THIS
# repo are installed: the harness works at every stage of the build.
UL_T_SCRIPTS='update-loom.sh update-loom-common.sh json-valid.sh json-flat.sh security-invariants.sh updates-lint.sh updates-checks.sh'

ul_t_install_engine() { # DIR
  mkdir -p "$1/plugins/loom-maintenance/scripts" || return 1
  for ul_ti_f in $UL_T_SCRIPTS; do
    if [ -f "$UL_T_ROOT/plugins/loom-maintenance/scripts/$ul_ti_f" ]; then
      cp "$UL_T_ROOT/plugins/loom-maintenance/scripts/$ul_ti_f" "$1/plugins/loom-maintenance/scripts/$ul_ti_f" || return 1
    fi
  done
}

# Independent of the library under test: sha256sum, else shasum, else openssl.
ul_t_sha256() { # FILE
  if command -v sha256sum >/dev/null 2>&1; then
    ul_ts_h=$(sha256sum "$1" 2>/dev/null) && [ -n "$ul_ts_h" ] && { printf '%s\n' "${ul_ts_h%% *}"; return 0; }
  fi
  if command -v shasum >/dev/null 2>&1; then
    ul_ts_h=$(shasum -a 256 "$1" 2>/dev/null) && [ -n "$ul_ts_h" ] && { printf '%s\n' "${ul_ts_h%% *}"; return 0; }
  fi
  if command -v openssl >/dev/null 2>&1; then
    ul_ts_h=$(openssl dgst -sha256 "$1" 2>/dev/null) && [ -n "$ul_ts_h" ] && { printf '%s\n' "${ul_ts_h##* }"; return 0; }
  fi
  return 1
}

ul_t_write_bundle() { # DIR : one `<sha256>  <path>` line per installed script
  mkdir -p "$1/plugins/loom-maintenance/updates" || return 1
  ul_tw_out=$1/plugins/loom-maintenance/updates/BUNDLE.sha256
  : > "$ul_tw_out" || return 1
  for ul_tw_f in $UL_T_SCRIPTS; do
    [ -f "$1/plugins/loom-maintenance/scripts/$ul_tw_f" ] || continue
    ul_tw_h=$(ul_t_sha256 "$1/plugins/loom-maintenance/scripts/$ul_tw_f") || return 1
    printf '%s  %s\n' "$ul_tw_h" "plugins/loom-maintenance/scripts/$ul_tw_f" >> "$ul_tw_out"
  done
}

# ------------------------------------------------------------ the fixture world
# ul_t_world DIR builds DIR/upstream (two commits) and DIR/customer (a clone
# reset to commit 1, no remote, plus the customer's own edits) and sets:
#   W_UP W_CUST   the two repo paths (canonical)
#   W_BASE        upstream commit 1 (what the customer's .sdd-sync-ref names)
#   W_HEAD        upstream commit 2 (the update on offer)
#   ENGINE        the engine as installed in the customer repo
#   SH            the interpreter under test
ul_t_world() { # DIR
  ul_tw_dir=$(CDPATH= cd -- "$1" && pwd -P) || return 1
  W_UP=$ul_tw_dir/upstream
  W_CUST=$ul_tw_dir/customer
  SH=${LOOM_TEST_SH:-/bin/sh}

  ul_t_git_init "$W_UP" || return 1
  cp -R "$UL_T_FIX/world/base/." "$W_UP/" || return 1
  ul_t_install_engine "$W_UP" || return 1
  printf 'LOOM_UPSTREAM_URL="%s"\n' "$W_UP" > "$W_UP/.logic-loom/config/framework-upstream.conf" || return 1
  ul_t_write_bundle "$W_UP" || return 1
  W_BASE=$(ul_t_commit "$W_UP" "base") || return 1

  cp -R "$UL_T_FIX/world/head/." "$W_UP/" || return 1
  mkdir -p "$W_UP/plugins/loom-maintenance/updates" || return 1
  cp -R "$UL_T_FIX/notes/." "$W_UP/plugins/loom-maintenance/updates/" || return 1
  ul_t_write_bundle "$W_UP" || return 1
  W_HEAD=$(ul_t_commit "$W_UP" "head") || return 1

  git clone -q "$W_UP" "$W_CUST" || return 1
  ul_t_git_config "$W_CUST"
  git -C "$W_CUST" checkout -q -B main "$W_BASE" || return 1
  git -C "$W_CUST" remote remove origin || return 1
  cp -R "$UL_T_FIX/world/customer/." "$W_CUST/" || return 1
  printf '%s\n' "$W_BASE" > "$W_CUST/.sdd-sync-ref" || return 1
  ul_t_commit "$W_CUST" "customer edits" >/dev/null || return 1

  ENGINE=$W_CUST/plugins/loom-maintenance/scripts/update-loom.sh
}

# Runs the customer's engine under the interpreter being tested: stdout and
# stderr into $OUT, the exit code into $RC. stdin is closed.
ul_t_run_engine() { # ARGS...
  OUT=$(cd "$W_CUST" && "$SH" "$ENGINE" "$@" </dev/null 2>&1)
  RC=$?
}
