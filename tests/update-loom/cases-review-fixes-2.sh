#!/bin/sh
# Cases for the second round of Phase-0 review fixes to the update engine:
#   A  --plan re-reads `staged` (and the other unlocked preconditions) after it holds the lock
#   B  a git failure while reading a record's paths fails the revert verification closed
#   C  cleanup failures (worktree removal / prune) are never reported as plain success
#   D  check scripts: permission hardening, content fingerprints, finish-time detection
# D is DETECTION plus permission hardening, not a sandbox: a check runs as the user and can
# still chmod back. POSIX sh. Prints PASS/FAIL lines; exit status is the overall result.
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
WT() { ul_t_wt; }
pl() { ul_t_run_engine --plan; }
asv() { ul_t_run_engine --adapt-save "$1" "$2" "$3"; }
stg() { ul_t_run_engine --stage "$1"; }
fin() { ul_t_run_engine --finish; }
abn() { ul_t_run_engine --abandon; }
sneak() { cg update-index --skip-worktree -- "$1"; }

SET=.claude/settings.json
AMD=.logic-loom/memory/amendments.md
GUARD=.claude/hooks/guard-dangerous-commands.sh
HOOKS=hooks-guard-dangerous
SETASK=settings-ask-restore
GUIDE=fixture-doc-guidance
FOLLOW=fixture-doc-followup
LADDER=amendments-ladder-plus-three
NOTES=plugins/loom-maintenance/updates/7.0.0
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
# The probe replaces the check of the fixture-doc-guidance note in UPSTREAM. Its mode is
# the content of probe-mode in the state dir; the state dir is found from REPO_ROOT for
# the plan export and the staging worktree (REPO_ROOT/..) and from git for the live repo
# (finish). `live` is the customer repository whichever of the three it runs in.
probe_install() {
  cat > "$W_UP/$NOTES/$GUIDE.check.sh" <<'EOT'
#!/bin/sh
set -u
root=${REPO_ROOT:-.}
if [ -f "$root/../probe-mode" ]; then st=$(cd "$root/.." && pwd); else st=$root/.git/loom/update; fi
live=$(cd "$st/../../.." && pwd)
mode=$(cat "$st/probe-mode" 2>/dev/null || echo none)
case $mode in
  rm-mine) rm -rf "$st/mine" 2>/dev/null;;
  rm-mine-chmod) chmod -R u+w "$st/mine"; rm -rf "$st/mine";;
  perm-report) if [ -w "$st/mine/u1/file.txt" ]; then echo writable > "$live/../perm-seen"; else echo readonly > "$live/../perm-seen"; fi;;
  overwrite-untracked) cp "$st/probe-mode" "$live/scratch-notes.txt";;
  write-live) cp "$st/probe-mode" "$live/finish-wrote.txt";;
  slow) : > "$live/../probe-running"; sleep 3;;
esac
doc="$root/.docs/guides/FIXTURE.md"
if [ -f "$doc" ] && grep -F 'Run /update-loom to take improvements.' "$doc" >/dev/null 2>&1; then exit 0; fi
printf 'hint=not yet\n'
exit 1
EOT
  # the linter refuses a check that removes files recursively or redirects output outside
  # TMPDIR, and --stage runs the linter, so only the plan-time cases (which never lint) get
  # those modes; the stage and finish cases write with cp
  if [ "${1:-}" != full ]; then
    grep -v -e 'rm -rf' -e perm-seen -e probe-running "$W_UP/$NOTES/$GUIDE.check.sh" > "$W_UP/$NOTES/$GUIDE.check.sh.t" && mv "$W_UP/$NOTES/$GUIDE.check.sh.t" "$W_UP/$NOTES/$GUIDE.check.sh"
  fi
  ul_t_commit "$W_UP" "probe check" >/dev/null
}
setup_probe() { # MODE : probe installed, planned with MODE, good settings saved
  nw || return 1
  ul_t_add_gov_stub "$W_CUST"
  probe_install || return 1
  mkdir -p "$(ST)"
  printf '%s\n' "$1" > "$(ST)/probe-mode"
  pl
  ul_t_settings_variant good "$BD/good.json" 2>/dev/null
  asv $SET "$BD/good.json" $HOOKS,$SETASK
  mkdec "$BD/d.tsv"
}
mine_backup() { mkdir -p "$(ST)/mine/u1" && printf 'backup\n' > "$(ST)/mine/u1/file.txt"; }
mine_writable() { [ -w "$(ST)/mine" ] && [ -w "$(ST)/mine/u1" ] && [ -w "$(ST)/mine/u1/file.txt" ]; }
can_block() { # 0 when a read-only directory really blocks this user (not root)
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

# =================================================================== 0. syntax
ul_t_check "case file passes sh -n" sh -n "$here/cases-review-fixes-2.sh"
ul_t_check "case file passes dash -n" dash_n "$here/cases-review-fixes-2.sh"
ul_t_check "engine passes sh -n" sh -n "$ENG_SRC"
ul_t_check "engine passes dash -n" dash_n "$ENG_SRC"
ul_t_check "engine never resets hard, pushes, deletes a branch or a tag" ul_t_not grep -Eq 'reset --hard|git push|branch -D|worktree add -b|tag -d' "$ENG_SRC"

# ====================== A. --plan re-checks `staged` after it holds the lock
setup || ul_t_done
rm -f "$(ST)/.test-go"
( cd "$W_CUST" && LOOM_TEST_PAUSE_BEFORE_PLAN_LOCK=1 LOOM_UPDATE_SH="$SH" exec "$SH" "$ENGINE" --plan </dev/null >"$BD/bg.out" 2>&1 ) &
BGP=$!
i=0
while [ ! -e "$(ST)/.test-plan-paused" ] && [ "$i" -lt 100 ]; do sleep 0.2; i=$((i + 1)); done
ul_t_check "A: --plan reached the window between the staged read and the lock" test -e "$(ST)/.test-plan-paused"
stg "$BD/d.tsv"
ul_t_check "A: a --stage finishes inside that window" ul_t_eq "$(kv result)" staged
S=$(kv staged)
sum1=$(cat "$(ST)/plan.tsv" "$(ST)/meta" "$(ST)/notes.tsv" | cksum)
: > "$(ST)/.test-go"
wait "$BGP"
OUT=$(cat "$BD/bg.out")
ul_t_check "A: the plan then refuses with the staged-exists message" ul_t_has "$OUT" '^result=aborted reason=a staged update exists; run --finish or --abandon'
ul_t_check "A: ... unchanged=yes" ul_t_has "$OUT" 'unchanged=yes'
ul_t_check "A: the plan left the state untouched" ul_t_eq "$(cat "$(ST)/plan.tsv" "$(ST)/meta" "$(ST)/notes.tsv" | cksum)" "$sum1"
ul_t_check "A: the staged marker and worktree are still there" ul_t_eq "$(cat "$(ST)/staged"):$(test -d "$(WT)" && echo wt)" "$S:wt"
ul_t_check "A: the lock is released" test ! -e "$(ST)/stage.lock"

# ====================== B. a git failure reading a record fails the verification closed
setup || ul_t_done
stg "$BD/d.tsv"
ul_t_land
fin
ul_t_check "B fixture: finished" ul_t_has "$OUT" '^result=applied '
SHIM=$(shim_with 'd=$(dirname "$0")
case " $* " in
  *" revert "*) "$REAL" "$@"; rc=$?; : > "$d/mark"; exit $rc;;
  *" show "*) if [ -f "$d/mark" ]; then echo "fatal: shim" >&2; exit 128; fi;;
esac')
H1=$(cg rev-parse HEAD)
ul_t_run_engine_shim "$SHIM" --undo
ul_t_check "B: --undo whose record cannot be read after the revert is not 'undone'" ul_t_not ul_t_has "$OUT" '^result=undone'
ul_t_check "B: ... it reports reverted-failed" ul_t_has "$OUT" '^result=reverted-failed '
ul_t_check "B: ... exit 1" ul_t_eq "$RC" 1
ul_t_check "B: ... the mismatch names the unreadable record" ul_t_has "$OUT" 'mismatched=.*record'
ul_t_check "B: ... the revert commit was left (nothing rewound)" ul_t_eq "$(cg rev-list --count "$H1..HEAD")" 1

setup || ul_t_done
stg "$BD/d.tsv"
ul_t_land
sneak "$GUARD"
rm -f "$W_CUST/$GUARD"
SHIM=$(shim_with 'd=$(dirname "$0")
case " $* " in
  *" revert "*) "$REAL" "$@"; rc=$?; : > "$d/mark"; exit $rc;;
  *" show "*) if [ -f "$d/mark" ]; then echo "fatal: shim" >&2; exit 128; fi;;
esac')
ul_t_run_engine_shim "$SHIM" --finish
ul_t_check "B: --finish revert whose record cannot be read is not 'reverted'" ul_t_not ul_t_has "$OUT" '^result=reverted reason'
ul_t_check "B: ... it reports reverted-failed" ul_t_has "$OUT" '^result=reverted-failed '

# ====================== C. cleanup failures are not reported as success
# C1: the orphan --abandon path (no `staged`, a leftover worktree that cannot be removed)
setup || ul_t_done
stg "$BD/d.tsv"
ul_t_check "C1 fixture: staged" ul_t_eq "$(kv result)" staged
if can_block; then
  rm -f "$(ST)/staged" "$(ST)/stage.info"
  chmod 555 "$(ST)"
  abn
  chmod 755 "$(ST)"
  ul_t_check "C1: orphan abandon with an undeletable worktree: result=abandon-incomplete" ul_t_has "$OUT" '^result=abandon-incomplete reason='
  ul_t_check "C1: ... exit 1" ul_t_eq "$RC" 1
  ul_t_check "C1: ... it did not claim nothing-staged" ul_t_not ul_t_has "$OUT" '^result=nothing-staged'
  abn
  ul_t_check "C1: retried once the block is gone: nothing-staged" ul_t_has "$OUT" '^result=nothing-staged'
  ul_t_check "C1: ... and the worktree is gone" test ! -d "$(WT)"
else
  ul_t_check "C1: skipped (a read-only directory does not stop this user)" true
fi

# C2: stg_wt_remove fails when the git registration survives (worktree remove/prune fail)
setup || ul_t_done
stg "$BD/d.tsv"
SHIM=$(shim_with 'case " $* " in *" worktree remove "*|*" worktree prune "*) echo "fatal: shim" >&2; exit 1;; esac')
ul_t_run_engine_shim "$SHIM" --abandon
ul_t_check "C2: --abandon with worktree remove/prune failing: abandon-incomplete" ul_t_has "$OUT" '^result=abandon-incomplete reason='
ul_t_check "C2: ... exit 1" ul_t_eq "$RC" 1
ul_t_check "C2: ... staged and stage.info are kept for a retry" test -f "$(ST)/staged" -a -f "$(ST)/stage.info"
abn
ul_t_check "C2: retried with a working git: abandoned" ul_t_has "$OUT" '^result=abandoned '
ul_t_check "C2: ... no worktree is registered any more" ul_t_eq "$(cg worktree list --porcelain | grep -c 'loom/update/wt')" 0

# C3: fu_clear_state keeps the retry markers and the callers say so
setup || ul_t_done
stg "$BD/d.tsv"
ul_t_land
SHIM=$(shim_with 'case " $* " in *" worktree remove "*|*" worktree prune "*) echo "fatal: shim" >&2; exit 1;; esac')
ul_t_run_engine_shim "$SHIM" --finish
ul_t_check "C3: finish with the worktree cleanup failing still reports applied" ul_t_has "$OUT" '^result=applied '
ul_t_check "C3: ... plus cleanup=incomplete on its own line" ul_t_has "$OUT" '^cleanup=incomplete reason=.'
ul_t_check "C3: ... exit non-zero" ne "$RC" 0
ul_t_check "C3: ... staged and stage.info are kept" test -f "$(ST)/staged" -a -f "$(ST)/stage.info"
fin
ul_t_check "C3: finish again once git works: applied, clean" ul_t_has "$OUT" '^result=applied '
ul_t_check "C3: ... exit 0 and the markers are gone" ul_t_eq "$RC:$(test -e "$(ST)/staged" && echo staged)" "0:"

setup || ul_t_done
stg "$BD/d.tsv"
ul_t_land
sneak "$GUARD"
rm -f "$W_CUST/$GUARD"
ul_t_run_engine_shim "$SHIM" --finish
ul_t_check "C3: the automatic-revert path keeps its primary result" ul_t_has "$OUT" '^result=reverted reason='
ul_t_check "C3: ... plus cleanup=incomplete, exit 1" ul_t_eq "$(printf '%s\n' "$OUT" | grep -c '^cleanup=incomplete reason=.'):$RC" "1:1"
ul_t_check "C3: ... staged and stage.info are kept" test -f "$(ST)/staged" -a -f "$(ST)/stage.info"

# ====================== D. check scripts: permission hardening, fingerprints, finish
# (detection plus permission hardening, not a sandbox: a check runs as the user and can chmod back)
if can_block; then
  # D1: rm -rf state/mine fails while the check runs
  nw || ul_t_done
  ul_t_add_gov_stub "$W_CUST"
  probe_install full
  mkdir -p "$(ST)"
  mine_backup
  printf 'rm-mine\n' > "$(ST)/probe-mode"
  pl
  ul_t_check "D1: a check that runs rm -rf on state/mine leaves the backup intact" test -f "$(ST)/mine/u1/file.txt"
  ul_t_check "D1: ... and the plan still completes" ul_t_eq "$(kv result)" planned
  ul_t_check "D1: ... permissions are restored after a normal run" mine_writable
  # a check that chmods back is, as ever, only detected (the residual)
  nw || ul_t_done
  ul_t_add_gov_stub "$W_CUST"
  probe_install full
  mkdir -p "$(ST)"
  mine_backup
  printf 'rm-mine-chmod\n' > "$(ST)/probe-mode"
  pl
  ul_t_check "D1 residual: a check that chmods back and deletes mine/ is detected, naming it" ul_t_has "$OUT" '^result=aborted reason=check .*mine'
  # during the check the backup is read-only
  nw || ul_t_done
  ul_t_add_gov_stub "$W_CUST"
  probe_install full
  mkdir -p "$(ST)"
  mine_backup
  printf 'perm-report\n' > "$(ST)/probe-mode"
  rm -f "$W_CUST/../perm-seen"
  pl
  ul_t_check "D1: while a plan-time check runs, the mine/ backup is read-only" ul_t_eq "$(cat "$W_CUST/../perm-seen" 2>/dev/null)" readonly
  ul_t_check "D1: ... and writable again afterwards" mine_writable
  # restored after an abort
  nw || ul_t_done
  ul_t_add_gov_stub "$W_CUST"
  probe_install full
  mkdir -p "$(ST)"
  mine_backup
  printf 'a log\n' > "$(ST)/last-smoke.log"
  printf 'overwrite-untracked\n' > "$(ST)/probe-mode"
  printf 'xxxxxxxxxxxxxxxxxxx\n' > "$W_CUST/scratch-notes.txt"
  pl
  ul_t_check "D1: restored after an aborted run: mine/" mine_writable
  ul_t_check "D1: restored after an aborted run: last-smoke.log" test -w "$(ST)/last-smoke.log"
  # restored after a TERM during a check
  nw || ul_t_done
  ul_t_add_gov_stub "$W_CUST"
  probe_install full
  mkdir -p "$(ST)"
  mine_backup
  printf 'a log\n' > "$(ST)/last-smoke.log"
  printf 'slow\n' > "$(ST)/probe-mode"
  rm -f "$W_CUST/../probe-running"
  ( cd "$W_CUST" && LOOM_UPDATE_SH="$SH" exec "$SH" "$ENGINE" --plan </dev/null >"$BD/bg.out" 2>&1 ) &
  BGP=$!
  i=0
  while [ ! -e "$W_CUST/../probe-running" ] && [ "$i" -lt 100 ]; do sleep 0.2; i=$((i + 1)); done
  kill -TERM "$BGP" 2>/dev/null
  wait "$BGP" 2>/dev/null
  ul_t_check "D1: restored after the run was terminated: mine/" mine_writable
  ul_t_check "D1: restored after the run was terminated: last-smoke.log" test -w "$(ST)/last-smoke.log"
  ul_t_check "D1: the terminated run released its lock" test ! -e "$(ST)/stage.lock"
else
  ul_t_check "D1: skipped (a read-only directory does not stop this user)" true
fi

# D2: overwriting an existing UNTRACKED customer file (same size, same status) is detected
nw || ul_t_done
ul_t_add_gov_stub "$W_CUST"
probe_install
mkdir -p "$(ST)"
printf 'overwrite-untracked\n' > "$(ST)/probe-mode"
printf 'xxxxxxxxxxxxxxxxxxx\n' > "$W_CUST/scratch-notes.txt"
pl
ul_t_check "D2 plan-time: an in-place overwrite of an untracked file is detected, naming it" ul_t_has "$OUT" '^result=aborted reason=check .*scratch-notes.txt'
setup_probe none || ul_t_done
printf 'xxxxxxxxxxxxxxxxxxx\n' > "$W_CUST/scratch-notes.txt"
printf 'overwrite-untracked\n' > "$(ST)/probe-mode"
stg "$BD/d.tsv"
ul_t_check "D2 stage-time: the same overwrite is detected, naming it" ul_t_has "$OUT" '^result=aborted failed=checks reason=.*scratch-notes.txt'
ul_t_check "D2 stage-time: ... nothing stays staged" test ! -e "$(ST)/staged"

# D3: a check run during --finish is watched too
setup_probe none || ul_t_done
stg "$BD/d.tsv"
ul_t_check "D3 fixture: staged" ul_t_eq "$(kv result)" staged
ul_t_land
printf 'write-live\n' > "$(ST)/probe-mode"
fin
ul_t_check "D3: a finish-time check that writes is a smoke failure (reverted, reason=checks)" ul_t_has "$OUT" '^result=reverted reason=checks '
ul_t_check "D3: ... the detail names the path" ul_t_has "$OUT" '^detail=.*finish-wrote.txt'

# E is a comment only (the accepted sub-second window before `git revert`).
ul_t_check "E: the accepted window is documented at the revert" grep -q 'accepted' "$ENG_SRC"

ul_t_done
