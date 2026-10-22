#!/bin/sh
# Cases for the third round of Phase-0 review fixes to the update engine:
#   1  --undo: a git failure listing the record directory is not "nothing to undo"
#   2  --undo: a git failure listing the update commit's paths refuses (forbidden check fails closed)
#   3  --finish (moved on): a record-read failure keeps the retry state, a retry then succeeds
#   4  --finish: a marker (staged / stage.info) that cannot be removed is cleanup=incomplete
#   5  check-time permission lock restores the ORIGINAL modes
#   6  an early exit prints no "cg_unlock: not found"
# POSIX sh. Prints PASS/FAIL lines; exit status is the overall result.
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib.sh"

ENG_SRC=$UL_T_ROOT/plugins/loom-maintenance/scripts/update-loom.sh
TAB=$(printf '\t')

kv() { printf '%s\n' "$OUT" | sed -n "s/^$1=//p" | head -1; }
dash_n() { [ -x /bin/dash ] || return 0; /bin/dash -n "$1"; }
ne() { [ "$1" != "$2" ]; }
cg() { git -C "$W_CUST" "$@"; }
nw() {
  nw_d=$(ul_t_tmp) || return 1
  ul_t_world "$nw_d" || { echo "FAIL  fixture world could not be built"; fail=1; return 1; }
}
ST() { ul_t_state; }
pl() { ul_t_run_engine --plan; }
asv() { ul_t_run_engine --adapt-save "$1" "$2" "$3"; }
stg() { ul_t_run_engine --stage "$1"; }
fin() { ul_t_run_engine --finish; }
und() { ul_t_run_engine --undo; }

SET=.claude/settings.json
AMD=.logic-loom/memory/amendments.md
HOOKS=hooks-guard-dangerous
SETASK=settings-ask-restore
GUIDE=fixture-doc-guidance
FOLLOW=fixture-doc-followup
LADDER=amendments-ladder-plus-three
BD=$(ul_t_tmp)

mkdec() { # FILE
  ul_t_decisions "$1" \
    "$SET${TAB}adapted" "$AMD${TAB}hold" \
    "note:$HOOKS${TAB}apply" "note:$SETASK${TAB}apply" "note:$GUIDE${TAB}apply" \
    "note:$FOLLOW${TAB}apply" "note:$LADDER${TAB}apply" "note:_unnoted${TAB}apply"
}
setup() { # a world with the governance stub, planned, good settings saved
  nw || return 1
  ul_t_add_gov_stub "$W_CUST"
  pl
  ul_t_settings_variant good "$BD/good.json"
  asv $SET "$BD/good.json" $HOOKS,$SETASK
  mkdec "$BD/d.tsv"
}
can_block() { # 0 when a read-only file really blocks this user (not root)
  cb_d=$(ul_t_tmp) || return 1
  chmod 555 "$cb_d"
  if ( : > "$cb_d/x" ) 2>/dev/null; then chmod 755 "$cb_d"; return 1; fi
  chmod 755 "$cb_d"
  return 0
}
shim_with() { # BODY -> the shim dir with hook.sh = BODY
  sw_d=$(ul_t_shim_make) || return 1
  printf '%s\n' "$1" > "$sw_d/hook.sh"
  printf '%s' "$sw_d"
}
modes() { ls -ld "$1" | cut -c1-10; }

# =================================================================== 0. syntax
ul_t_check "case file passes sh -n" sh -n "$here/cases-review-fixes-3.sh"
ul_t_check "case file passes dash -n" dash_n "$here/cases-review-fixes-3.sh"
ul_t_check "engine passes sh -n" sh -n "$ENG_SRC"
ul_t_check "engine passes dash -n" dash_n "$ENG_SRC"

# ====================== 1. --undo: ls-tree failure is not "nothing to undo"
setup || ul_t_done
stg "$BD/d.tsv"
ul_t_land
fin
ul_t_check "1 fixture: finished" ul_t_has "$OUT" '^result=applied '
H1=$(cg rev-parse HEAD)
SHIM=$(shim_with 'case " $* " in *" ls-tree "*) echo "fatal: shim" >&2; exit 128;; esac')
ul_t_run_engine_shim "$SHIM" --undo
ul_t_check "1: a failing ls-tree is not result=nothing-to-undo" ul_t_not ul_t_has "$OUT" '^result=nothing-to-undo'
ul_t_check "1: ... it refuses with a reason" ul_t_has "$OUT" '^result=refused reason=.'
ul_t_check "1: ... exit non-zero" ne "$RC" 0
ul_t_check "1: ... HEAD did not move" ul_t_eq "$(cg rev-parse HEAD)" "$H1"
und
ul_t_check "1: with a working git the undo goes through" ul_t_has "$OUT" '^result=undone '
nw || ul_t_done
und
ul_t_check "1: a repository that genuinely has no records is still nothing-to-undo" ul_t_has "$OUT" '^result=nothing-to-undo'
ul_t_check "1: ... exit 0" ul_t_eq "$RC" 0

# ====================== 2. --undo: diff-tree failure refuses
setup || ul_t_done
stg "$BD/d.tsv"
ul_t_land
fin
H2=$(cg rev-parse HEAD)
SHIM=$(shim_with 'case " $* " in *" diff-tree "*) echo "fatal: shim" >&2; exit 128;; esac')
ul_t_run_engine_shim "$SHIM" --undo
ul_t_check "2: a failing diff-tree is refused" ul_t_has "$OUT" '^result=refused reason=.'
ul_t_check "2: ... not undone" ul_t_not ul_t_has "$OUT" '^result=undone'
ul_t_check "2: ... exit non-zero" ne "$RC" 0
ul_t_check "2: ... HEAD did not move" ul_t_eq "$(cg rev-parse HEAD)" "$H2"

# ====================== 3. moved-on finish: a record-read failure keeps the retry state
setup || ul_t_done
stg "$BD/d.tsv"
S=$(kv staged)
ul_t_land
ul_t_edit "$W_CUST" "notes-of-mine.txt" "committed right after landing" "customer commits before finish" >/dev/null
SHIM=$(shim_with 'case " $* " in *" diff-tree "*) echo "fatal: shim" >&2; exit 128;; esac')
ul_t_run_engine_shim "$SHIM" --finish
ul_t_check "3: a record-read failure is not reported as moved-on" ul_t_not ul_t_has "$OUT" '^result=moved-on'
ul_t_check "3: ... it is reported as a failure" ul_t_has "$OUT" '^result=record-read-failed '
ul_t_check "3: ... exit non-zero" ne "$RC" 0
ul_t_check "3: ... staged and stage.info are kept" test -f "$(ST)/staged" -a -f "$(ST)/stage.info"
ul_t_check "3: ... and the lock is released" test ! -e "$(ST)/stage.lock"
fin
ul_t_check "3: the retry with a working git reports moved-on" ul_t_has "$OUT" '^result=moved-on '
ul_t_check "3: ... and the smoke ran (no record-unreadable skip)" ul_t_has "$OUT" '^smoke=passed$'
ul_t_check "3: ... and the retry markers are now gone" ul_t_eq "$(test -e "$(ST)/staged" && echo staged)" ""
# git show failing for the record
setup || ul_t_done
stg "$BD/d.tsv"
ul_t_land
ul_t_edit "$W_CUST" "notes-of-mine.txt" "again" "customer commits before finish" >/dev/null
SHIM=$(shim_with 'case " $* " in *" show "*) echo "fatal: shim" >&2; exit 128;; esac')
ul_t_run_engine_shim "$SHIM" --finish
ul_t_check "3: a failing git show of the record keeps the retry state too" ul_t_eq "$(printf '%s' "$OUT" | grep -c '^result=record-read-failed '):$(test -f "$(ST)/staged" && echo kept)" "1:kept"

# ====================== 4. a marker that cannot be removed is cleanup=incomplete
setup || ul_t_done
stg "$BD/d.tsv"
ul_t_land
SHIM=$(ul_t_shim_make)
printf '#!/bin/sh\nfor a in "$@"; do case $a in */staged|*/stage.info) echo "rm: shim: cannot remove" >&2; exit 1;; esac; done\nexec /bin/rm "$@"\n' > "$SHIM/rm"
chmod +x "$SHIM/rm"
ul_t_run_engine_shim "$SHIM" --finish
ul_t_check "4: the primary result is kept" ul_t_has "$OUT" '^result=applied '
ul_t_check "4: ... plus cleanup=incomplete" ul_t_has "$OUT" '^cleanup=incomplete reason=.'
ul_t_check "4: ... exit non-zero" ne "$RC" 0
ul_t_check "4: ... the staged marker survived (that is why)" test -f "$(ST)/staged"
fin
ul_t_check "4: finish again once rm works: ends clean, exit 0 or a clear state" ul_t_eq "$(test -e "$(ST)/staged" && echo staged)" ""

# ====================== 5. check-time lock restores the original modes
if can_block; then
  nw || ul_t_done
  ul_t_add_gov_stub "$W_CUST"
  mkdir -p "$(ST)/mine/u1"
  printf 'a\n' > "$(ST)/mine/u1/ro.txt"
  printf 'b\n' > "$(ST)/mine/u1/gw.txt"
  chmod 444 "$(ST)/mine/u1/ro.txt"
  chmod 664 "$(ST)/mine/u1/gw.txt"
  printf 'log\n' > "$(ST)/last-smoke.log"
  chmod 444 "$(ST)/last-smoke.log"
  m_ro=$(modes "$(ST)/mine/u1/ro.txt"); m_gw=$(modes "$(ST)/mine/u1/gw.txt"); m_d=$(modes "$(ST)/mine/u1"); m_l=$(modes "$(ST)/last-smoke.log")
  pl
  ul_t_check "5 fixture: the plan ran" ul_t_eq "$(kv result)" planned
  ul_t_check "5: a read-only backup stays read-only" ul_t_eq "$(modes "$(ST)/mine/u1/ro.txt")" "$m_ro"
  ul_t_check "5: a group-writable backup keeps its modes" ul_t_eq "$(modes "$(ST)/mine/u1/gw.txt")" "$m_gw"
  ul_t_check "5: the directory keeps its modes" ul_t_eq "$(modes "$(ST)/mine/u1")" "$m_d"
  ul_t_check "5: a read-only smoke log stays read-only" ul_t_eq "$(modes "$(ST)/last-smoke.log")" "$m_l"
  chmod u+w "$(ST)/last-smoke.log" "$(ST)/mine/u1/ro.txt" 2>/dev/null
else
  ul_t_check "5: skipped (a read-only file does not stop this user)" true
fi

# ====================== 6. an early exit prints no "not found"
nw || ul_t_done
ul_t_run_engine --no-such-subcommand
ul_t_check "6: an early usage error exits non-zero" ne "$RC" 0
ul_t_check "6: ... and prints no cg_unlock: not found" ul_t_hasnt "$OUT" 'not found'
ul_t_run_engine --undo a b
ul_t_check "6: an early argument error prints no 'not found' either" ul_t_hasnt "$OUT" 'not found'

ul_t_done
