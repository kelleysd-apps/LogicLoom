#!/bin/sh
# Cases for the Phase-0 review fixes to the update engine (package p0-review-fixes):
# the lock around --plan / --adapt-save / --mark-unresolved, the symlink guard on the
# updater's recursive deletes, --abandon reporting a failed worktree removal, a check
# that commits in the staging worktree, check-script write DETECTION that now covers the
# live repository and the updater's own state directory, and --undo reading record
# paths line by line. (The --finish/--undo fixes live in cases-finish-undo.sh.)
# POSIX sh. Prints PASS/FAIL lines; exit status is the overall result.
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib.sh"

ENG_SRC=$UL_T_ROOT/plugins/loom-maintenance/scripts/update-loom.sh
TAB=$(printf '\t')

kv() { printf '%s\n' "$OUT" | sed -n "s/^$1=//p" | head -1; }
dash_n() { [ -x /bin/dash ] || return 0; /bin/dash -n "$1"; }
cg() { git -C "$W_CUST" "$@"; }
ug() { git -C "$W_UP" "$@"; }
cc() { cg add -A >/dev/null 2>&1 && cg commit -q --allow-empty -m "$1"; }
nw() {
  nw_d=$(ul_t_tmp) || return 1
  ul_t_world "$nw_d" || { echo "FAIL  fixture world could not be built"; fail=1; return 1; }
}
ST() { ul_t_state; }
WT() { ul_t_wt; }
GD() { git -C "$W_CUST" rev-parse --absolute-git-dir; }
pl() { ul_t_run_engine --plan; }
asv() { ul_t_run_engine --adapt-save "$1" "$2" "$3"; }
mku() { ul_t_run_engine --mark-unresolved "$1" "$2"; }
stg() { ul_t_run_engine --stage "$1"; }
fin() { ul_t_run_engine --finish; }
und() { ul_t_run_engine --undo "$@"; }
tags() { cg tag -l 'loom/pre-update-*'; }
show() { cg show "$1:$2" 2>/dev/null; }
sneak() { cg update-index --skip-worktree -- "$1"; }

SET=.claude/settings.json
AMD=.logic-loom/memory/amendments.md
DOC=.docs/guides/FIXTURE.md
HOOKS=hooks-guard-dangerous
SETASK=settings-ask-restore
GUIDE=fixture-doc-guidance
FOLLOW=fixture-doc-followup
LADDER=amendments-ladder-plus-three
NOTES=plugins/loom-maintenance/updates/7.0.0
BD=$(ul_t_tmp)
APPLIED=.logic-loom/memory/updates

mkdec() { # FILE [LINE...]
  mk_f=$1; shift
  ul_t_decisions "$mk_f.base" \
    "$SET${TAB}adapted" "$AMD${TAB}hold" \
    "note:$HOOKS${TAB}apply" "note:$SETASK${TAB}apply" "note:$GUIDE${TAB}apply" \
    "note:$FOLLOW${TAB}apply" "note:$LADDER${TAB}apply" "note:_unnoted${TAB}apply"
  cp "$mk_f.base" "$mk_f"
  for mk_l in "$@"; do
    mk_k=${mk_l%%"$TAB"*}
    awk -F'\t' -v k="$mk_k" '$1 != k' "$mk_f" > "$mk_f.t" && mv "$mk_f.t" "$mk_f"
    printf '%s\n' "$mk_l" >> "$mk_f"
  done
}
# a world with the governance stub, planned, with the good settings body saved
setup() {
  nw || return 1
  ul_t_add_gov_stub "$W_CUST"
  pl
  ul_t_settings_variant good "$BD/good.json"
  asv $SET "$BD/good.json" $HOOKS,$SETASK
}
# like setup, but a probe is installed first (see probe_install) and the plan is made
# with the given probe mode
setup_probe() { # MODE
  nw || return 1
  ul_t_add_gov_stub "$W_CUST"
  probe_install || return 1
  mkdir -p "$(ST)"
  printf '%s\n' "$1" > "$(ST)/probe-mode"
  pl
  ul_t_settings_variant good "$BD/good.json" 2>/dev/null
}

# The probe replaces the check of the fixture-doc-guidance note in UPSTREAM. What it
# does is chosen by the file state/probe-mode (REPO_ROOT/.. is the state dir for the
# plan-time export and the stage-time worktree alike):
#   lock        print the pid held in state/stage.lock as the last line, exit 1
#   touch-app   append to the live repo's web/app.js (REPO_ROOT/../../../..)
#   rm-log      delete the updater's own state/last-smoke.log
#   rm-mine     delete a customer backup under state/mine
#   commit-wt   commit in the staging worktree (only where REPO_ROOT has a .git entry)
#   none        behave like the original check
probe_install() {
  cat > "$W_UP/$NOTES/$GUIDE.check.sh" <<'EOT'
#!/bin/sh
set -u
root=${REPO_ROOT:-.}
st=$root/..
mode=$(cat "$st/probe-mode" 2>/dev/null || echo none)
case $mode in
  lock) printf 'lock=%s\n' "$(cat "$st/stage.lock" 2>/dev/null || echo none)"; exit 1;;
  touch-app) printf 'x\n' >> "$root/../../../../web/app.js";;
  rm-log) rm -f "$st/last-smoke.log";;
  rm-mine) rm -rf "$st/mine";;
  commit-wt) if [ -e "$root/.git" ]; then git -C "$root" -c core.hooksPath=/dev/null commit -q --allow-empty -m probe; fi;;
esac
doc="$root/.docs/guides/FIXTURE.md"
if [ -f "$doc" ] && grep -F 'Run /update-loom to take improvements.' "$doc" >/dev/null 2>&1; then exit 0; fi
printf 'hint=not yet\n'
exit 1
EOT
  ul_t_commit "$W_UP" "probe check" >/dev/null
}

# =================================================================== 0. syntax
ul_t_check "case file passes sh -n" sh -n "$here/cases-review-fixes.sh"
ul_t_check "case file passes dash -n" dash_n "$here/cases-review-fixes.sh"
ul_t_check "engine passes sh -n" sh -n "$ENG_SRC"
ul_t_check "engine passes dash -n" dash_n "$ENG_SRC"
ul_t_check "engine never resets hard, pushes, deletes a branch or a tag" ul_t_not grep -Eq 'reset --hard|git push|branch -D|worktree add -b|tag -d' "$ENG_SRC"

# ============================== 1. --plan holds the stage lock for its whole duration
setup_probe lock || ul_t_done
ul_t_check "plan with the lock probe: planned" ul_t_eq "$(kv result)" planned
LOCKSEEN=$(sed -n 's/^.* last=lock=//p' "$(ST)/checks.log" | head -1)
ul_t_check "plan: while the checks ran, stage.lock held a pid" ul_t_has "$LOCKSEEN" '^[0-9][0-9]*$'
ul_t_check "plan: the lock is released when it finishes" test ! -e "$(ST)/stage.lock"

nw || ul_t_done
pl
sleep 30 &
SP=$!
printf '%s\n' "$SP" > "$(ST)/stage.lock"
sum0=$(cat "$(ST)/plan.tsv" "$(ST)/meta" "$(ST)/notes.tsv" | cksum)
pl
ul_t_check "a live lock: --plan refuses with the staging message" ul_t_has "$OUT" '^result=aborted reason=another update is staging'
ul_t_check "a live lock: --plan leaves the state untouched" ul_t_eq "$(cat "$(ST)/plan.tsv" "$(ST)/meta" "$(ST)/notes.tsv" | cksum)" "$sum0"
kill "$SP" 2>/dev/null
rm -f "$(ST)/stage.lock"

setup || ul_t_done
ul_t_check "adapt-save releases the lock when done" test ! -e "$(ST)/stage.lock"
sleep 30 &
SP=$!
printf '%s\n' "$SP" > "$(ST)/stage.lock"
ls -lR "$(ST)/adapt" "$(ST)/merged" > "$BD/tree0" 2>&1
cksum "$(ST)/adapt.tsv" "$(ST)/adapted.tsv" >> "$BD/tree0" 2>&1
ul_t_settings_variant good "$BD/good2.json"
asv $SET "$BD/good2.json" $HOOKS,$SETASK
ul_t_check "a live lock: --adapt-save is refused" ul_t_has "$OUT" '^result=refused reason=another update is staging'
ul_t_check "a live lock: --adapt-save exits 1" ul_t_eq "$RC" 1
mku $SET $HOOKS
ul_t_check "a live lock: --mark-unresolved is refused" ul_t_has "$OUT" '^result=refused reason=another update is staging'
ls -lR "$(ST)/adapt" "$(ST)/merged" > "$BD/tree1" 2>&1
cksum "$(ST)/adapt.tsv" "$(ST)/adapted.tsv" >> "$BD/tree1" 2>&1
ul_t_check "a live lock: the state is untouched by either" ul_t_eq "$(cat "$BD/tree1")" "$(cat "$BD/tree0")"
ul_t_check "a live lock: no unresolved record was written" test ! -e "$(ST)/unresolved.tsv"
kill "$SP" 2>/dev/null
rm -f "$(ST)/stage.lock"
mku $SET $HOOKS
ul_t_check "no lock: --mark-unresolved works again" ul_t_has "$OUT" "^unresolved=$SET "
ul_t_check "... and releases the lock" test ! -e "$(ST)/stage.lock"

# ============================== 2. the symlink guard on the updater's recursive deletes
sentinel() { # DIR : a directory the updater must never delete from
  mkdir -p "$1/notes" "$1/wt" "$1/export" "$1/merged" || return 1
  echo keep > "$1/notes/keep.txt"; echo keep > "$1/wt/keep.txt"
  echo keep > "$1/export/keep.txt"; echo keep > "$1/merged/keep.txt"
}
sentinel_ok() { # DIR
  [ -f "$1/notes/keep.txt" ] && [ -f "$1/wt/keep.txt" ] && [ -f "$1/export/keep.txt" ] && [ -f "$1/merged/keep.txt" ]
}
nw || ul_t_done
SENT=$(ul_t_tmp)/sent
sentinel "$SENT"
mkdir -p "$(GD)/loom"
ln -s "$SENT" "$(GD)/loom/update"
pl
ul_t_check "state dir is a symlink: --plan refuses" ul_t_has "$OUT" '^result=aborted reason=.*symlink'
ul_t_check "state dir is a symlink: --plan deleted nothing behind the link" sentinel_ok "$SENT"
ul_t_run_engine --status
ul_t_check "state dir is a symlink: --status (stale-state heal) deleted nothing behind the link" sentinel_ok "$SENT"
echo aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa > "$SENT/staged"
ul_t_run_engine --abandon
ul_t_check "state dir is a symlink: --abandon deleted nothing behind the link" sentinel_ok "$SENT"
ul_t_check "state dir is a symlink: --abandon did not report success" ul_t_not ul_t_has "$OUT" '^result=abandoned'
rm -f "$(GD)/loom/update"

nw || ul_t_done
SENT2=$(ul_t_tmp)/sent
mkdir -p "$SENT2/update"
sentinel "$SENT2/update"
rm -rf "$(GD)/loom"
ln -s "$SENT2" "$(GD)/loom"
pl
ul_t_check ".git/loom is a symlink: --plan refuses" ul_t_has "$OUT" '^result=aborted reason=.*symlink'
ul_t_check ".git/loom is a symlink: nothing behind the link was deleted" sentinel_ok "$SENT2/update"
ul_t_run_engine --status
ul_t_check ".git/loom is a symlink: --status deleted nothing" sentinel_ok "$SENT2/update"
ul_t_run_engine --bootstrap-copy
ul_t_check ".git/loom is a symlink: --bootstrap-copy deleted nothing" sentinel_ok "$SENT2/update"
rm -f "$(GD)/loom"

# ============================================ 3. --abandon reports a failed removal
ul_t_can_block() { # 0 when a read-only directory really blocks this user (not root)
  cb_d=$(ul_t_tmp) || return 1
  chmod 555 "$cb_d"
  if ( : > "$cb_d/x" ) 2>/dev/null; then chmod 755 "$cb_d"; return 1; fi
  chmod 755 "$cb_d"
  return 0
}
setup || ul_t_done
mkdec "$BD/d.tsv"
stg "$BD/d.tsv"
S=$(kv staged)
ul_t_check "abandon fixture: staged" ul_t_eq "$(kv result)" staged
if ul_t_can_block; then
  chmod 555 "$(ST)"
  ul_t_run_engine --abandon
  chmod 755 "$(ST)"
  ul_t_check "abandon with the worktree undeletable: result=abandon-incomplete with a reason" ul_t_has "$OUT" '^result=abandon-incomplete reason='
  ul_t_check "abandon-incomplete: exit 1" ul_t_eq "$RC" 1
  ul_t_check "abandon-incomplete: enough state is kept to retry (staged and stage.info)" test -f "$(ST)/staged" -a -f "$(ST)/stage.info"
  ul_t_check "abandon-incomplete: it did not claim success" ul_t_not ul_t_has "$OUT" '^result=abandoned'
  ul_t_run_engine --abandon
  ul_t_check "abandon retried once the block is gone: abandoned" ul_t_has "$OUT" '^result=abandoned '
  ul_t_check "... and the worktree is gone" test ! -d "$(WT)"
else
  ul_t_check "abandon with an undeletable worktree: skipped (running as a user a read-only directory does not stop)" true
fi

# ================= 4. a check that commits in the staging worktree is caught
setup_probe commit-wt || ul_t_done
ul_t_settings_variant good "$BD/good.json"
asv $SET "$BD/good.json" $HOOKS,$SETASK
mkdec "$BD/d.tsv"
H0=$(cg rev-parse HEAD)
stg "$BD/d.tsv"
ul_t_check "a check that advances the worktree HEAD: the stage is aborted" ul_t_has "$OUT" '^result=aborted failed=checks reason=.*HEAD'
ul_t_check "... exit 1" ul_t_eq "$RC" 1
ul_t_check "... the live tree is unchanged" ul_t_eq "$(cg rev-parse HEAD):$(cg status --porcelain)" "$H0:"
ul_t_check "... nothing stays staged" test ! -e "$(ST)/staged"

# ============ 5. check-script write detection covers the live repo and the state dir
# (detection, not a sandbox: a check is unsandboxed shell)
setup_probe touch-app || ul_t_done
ul_t_check "plan-time: a check that appends to the live web/app.js is detected" ul_t_has "$OUT" '^result=aborted reason=check .*(check-wrote=web/app.js)'
ul_t_check "plan-time: ... and the half-written plan is gone" test ! -e "$(ST)/plan.tsv"
cg checkout -q -- web/app.js

nw || ul_t_done
ul_t_add_gov_stub "$W_CUST"
probe_install
mkdir -p "$(ST)"
printf 'rm-log\n' > "$(ST)/probe-mode"
printf 'a smoke log\n' > "$(ST)/last-smoke.log"
pl
ul_t_check "plan-time: a check that deletes last-smoke.log is detected, naming it" ul_t_has "$OUT" '^result=aborted reason=check .*last-smoke.log'
ul_t_check "plan-time: ... as a check-wrote reason" ul_t_has "$OUT" 'check-wrote='

nw || ul_t_done
ul_t_add_gov_stub "$W_CUST"
probe_install
mkdir -p "$(ST)/mine/u1"
printf 'backup\n' > "$(ST)/mine/u1/file.txt"
printf 'rm-mine\n' > "$(ST)/probe-mode"
pl
ul_t_check "plan-time: a check that deletes a mine/ backup is detected" ul_t_has "$OUT" '^result=aborted reason=check .*mine'

# the same two at stage time (the check runs in the staging worktree)
setup_probe none || ul_t_done
ul_t_check "stage-time fixture: planned with the probe idle" ul_t_eq "$(kv result)" planned
asv $SET "$BD/good.json" $HOOKS,$SETASK
printf 'touch-app\n' > "$(ST)/probe-mode"
mkdec "$BD/d.tsv"
H0=$(cg rev-parse HEAD)
stg "$BD/d.tsv"
ul_t_check "stage-time: a check that appends to the live web/app.js is detected" ul_t_has "$OUT" '^result=aborted failed=checks reason=.*web/app.js'
ul_t_check "stage-time: ... nothing stays staged and the tag is kept" ul_t_eq "$(test -e "$(ST)/staged" && echo staged):$(tags | awk 'END { print NR }')" ":1"
ul_t_check "stage-time: ... HEAD did not move" ul_t_eq "$(cg rev-parse HEAD)" "$H0"
cg checkout -q -- web/app.js

setup_probe none || ul_t_done
asv $SET "$BD/good.json" $HOOKS,$SETASK
printf 'a smoke log\n' > "$(ST)/last-smoke.log"
printf 'rm-log\n' > "$(ST)/probe-mode"
mkdec "$BD/d.tsv"
stg "$BD/d.tsv"
ul_t_check "stage-time: a check that deletes last-smoke.log is detected" ul_t_has "$OUT" '^result=aborted failed=checks reason=.*last-smoke.log'

# ================================= 6. --undo reads record paths line by line (a space)
nw || ul_t_done
ul_t_add_gov_stub "$W_CUST"
mkdir -p "$W_UP/.docs/guides"
printf '# two words\nfirst\n' > "$W_UP/.docs/guides/two words.md"
ul_t_commit "$W_UP" "upstream adds a file whose name has a space" >/dev/null
pl
ul_t_settings_variant good "$BD/good.json"
asv $SET "$BD/good.json" $HOOKS,$SETASK
mkdec "$BD/d.tsv"
H0=$(cg rev-parse HEAD)
stg "$BD/d.tsv"
ul_t_check "space path: staged" ul_t_eq "$(kv result)" staged
S=$(kv staged)
ul_t_land
fin
ul_t_check "space path: finish applied" ul_t_has "$OUT" '^result=applied '
ul_t_check "space path: the file landed" test -f "$W_CUST/.docs/guides/two words.md"
REC_ALL=$(cg ls-tree -r --name-only HEAD "$APPLIED" | while IFS= read -r rp; do cg show "HEAD:$rp"; done)
ul_t_check "space path: the record lists it whole" ul_t_has "$REC_ALL" 'two words.md'
printf 'the customer rewrote it\n' >> "$W_CUST/.docs/guides/two words.md"
cc "customer edits the spaced file"
HB=$(cg rev-parse HEAD)
und
ul_t_check "space path: a later edit to it is an overlap, refused, naming the whole path" ul_t_has "$OUT" '^result=refused reason=later changes overlap the update paths=.*two words.md'
ul_t_check "space path: nothing changed" ul_t_eq "$(cg rev-parse HEAD):$(cg status --porcelain)" "$HB:"

ul_t_done
