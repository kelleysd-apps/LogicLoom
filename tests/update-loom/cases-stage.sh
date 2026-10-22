#!/bin/sh
# Cases for --stage and --abandon (package p0-engine-stage-abandon): the one place
# the engine mutates git, inside a detached throwaway worktree. Refusals before any
# write, the commit, ledger and .applied record, hold-back with cascade, the gate
# (checks, invariants, json, hooks-resolve, protected trees, staged-path allowlist),
# self-heal of a killed stage, and --abandon.
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
pl() { ul_t_run_engine --plan; }
asv() { ul_t_run_engine --adapt-save "$1" "$2" "$3"; }
stg() { ul_t_run_engine --stage "$1"; }
UID_() { sed -n 's/^update_id=//p' "$(ST)/meta"; }
tags() { cg tag -l 'loom/pre-update-*'; }
aborted() { [ "$RC" = 1 ] && ul_t_has "$OUT" '^result=aborted '; }
aborted_with() { aborted && ul_t_has "$OUT" "$1"; }
unchanged() { ul_t_has "$OUT" ' unchanged=yes$'; }
clean_refusal() { aborted && unchanged && [ ! -e "$(ST)/staged" ] && [ ! -d "$(WT)" ] && [ -z "$(tags)" ]; }
show() { cg show "$1:$2" 2>/dev/null; }

SET=.claude/settings.json
AMD=.logic-loom/memory/amendments.md
DOC=.docs/guides/FIXTURE.md
DOC2=.docs/guides/FIXTURE-2.md
GUARD=.claude/hooks/guard-dangerous-commands.sh
LEDGER=.logic-loom/memory/update-ledger.tsv
HOOKS=hooks-guard-dangerous
SETASK=settings-ask-restore
GUIDE=fixture-doc-guidance
FOLLOW=fixture-doc-followup
LADDER=amendments-ladder-plus-three
NOTES=plugins/loom-maintenance/updates/7.0.0
BD=$(ul_t_tmp)

# decisions: the default set, then per-key overrides (a later line replaces the
# default line with the same first field)
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
# a planned world with the governance stub and the good settings body saved
setup() {
  nw || return 1
  ul_t_add_gov_stub "$W_CUST"
  pl
  ul_t_settings_variant good "$BD/good.json"
  asv $SET "$BD/good.json" $HOOKS,$SETASK
}
ledger_out() { git -C "$W_CUST" show "$1:$LEDGER" 2>/dev/null | awk -F'\t' -v i="$2" '$1 == i { o = $2 } END { print o }'; }
changed_set() { cg diff-tree --no-commit-id --name-only -r "$1" | LC_ALL=C sort; }

# =================================================================== 0. syntax
ul_t_check "case file passes sh -n" sh -n "$here/cases-stage.sh"
ul_t_check "case file passes dash -n" dash_n "$here/cases-stage.sh"
ul_t_check "engine passes sh -n" sh -n "$ENG_SRC"
ul_t_check "engine passes dash -n" dash_n "$ENG_SRC"
NEVER="reset --hard|git push|branch -D|worktree add -b|tag -d"
ul_t_check "engine never resets hard, pushes, deletes a branch or a tag" ul_t_not grep -Eq "$NEVER" "$ENG_SRC"
ul_t_check "engine has no bash-isms" ul_t_not grep -Eq '^[[:space:]]*(local|function)[[:space:]]|\[\[|<<<' "$ENG_SRC"

# ============================================================ 1. refusals
nw || ul_t_done
ul_t_add_gov_stub "$W_CUST"
mkdec "$BD/d0.tsv"
stg "$BD/d0.tsv"
ul_t_check "no plan: aborted, unchanged" aborted_with 'reason=no plan'
ul_t_check "no plan: exit 1 and the standard shape" unchanged
help_out=$(cd "$W_CUST" && "$SH" "$ENGINE" --help 2>&1)
ul_t_check "help: --stage is built" ul_t_hasnt "$help_out" 'stage.*not built'
ul_t_check "help: --abandon is built" ul_t_hasnt "$help_out" 'abandon.*not built'
ul_t_run_engine --abandon
ul_t_check "abandon with nothing staged: nothing-staged" ul_t_has "$OUT" '^result=nothing-staged'

pl
ul_t_settings_variant good "$BD/good.json"
asv $SET "$BD/good.json" $HOOKS,$SETASK
H0=$(cg rev-parse HEAD)
UID0=$(UID_)

mkdec "$BD/d.tsv"
printf 'junk\n' > "$W_CUST/untracked-harness.txt"
printf 'x\n' >> "$W_CUST/CLAUDE.md"
stg "$BD/d.tsv"
ul_t_check "dirty tree: aborted" aborted_with 'uncommitted'
ul_t_check "dirty tree: nothing left behind" clean_refusal
cg checkout -q -- CLAUDE.md; rm -f "$W_CUST/untracked-harness.txt"

stg "$BD/nothing-here.tsv"
ul_t_check "decisions file unreadable: aborted" clean_refusal
mkdec "$BD/d.tsv" "$SET${TAB}take"
stg "$BD/d.tsv"
ul_t_check "unknown decision value: aborted, names the line" aborted_with 'take'
ul_t_check "unknown decision value: nothing written" clean_refusal
mkdec "$BD/d.tsv" "note:$HOOKS${TAB}maybe"
stg "$BD/d.tsv"
ul_t_check "unknown note decision value: aborted" clean_refusal
mkdec "$BD/d.tsv" "$SET${TAB}adapted${TAB}informed=maybe"
stg "$BD/d.tsv"
ul_t_check "bad third field: aborted" clean_refusal
ul_t_decisions "$BD/d.tsv" "$AMD${TAB}hold"
stg "$BD/d.tsv"
ul_t_check "missing decision for the posture row: aborted" aborted_with 'settings.json'
ul_t_check "... and nothing left behind" clean_refusal
mkdec "$BD/d.tsv" "$SET${TAB}adapted"
grep -v "^$AMD" "$BD/d.tsv" > "$BD/d2.tsv"
stg "$BD/d2.tsv"
ul_t_check "missing decision for the two-way row: aborted" aborted_with 'amendments.md'
mkdec "$BD/d.tsv" "not/in/plan.txt${TAB}apply"
stg "$BD/d.tsv"
ul_t_check "a path that is not in the plan: aborted" aborted_with 'not/in/plan.txt'
mkdec "$BD/d.tsv" "$DOC2${TAB}adapted"
stg "$BD/d.tsv"
ul_t_check "adapted on FIXTURE-2.md (not a held row): aborted" aborted_with 'adapted'
mkdec "$BD/d.tsv" "$AMD${TAB}adapted"
stg "$BD/d.tsv"
ul_t_check "adapted without a saved body: aborted" aborted_with 'adapted'
mkdec "$BD/d.tsv" "$SET${TAB}take-theirs"
stg "$BD/d.tsv"
ul_t_check "take-theirs on the safety row without informed=yes: aborted" aborted_with 'informed'
ul_t_check "... and nothing left behind" clean_refusal
mkdec "$BD/d.tsv" "note:nope${TAB}apply"
stg "$BD/d.tsv"
ul_t_check "a note row for an unknown id: aborted" aborted_with 'nope'
grep -v "^note:$SETASK" "$BD/d0.tsv" > /dev/null
mkdec "$BD/d.tsv"
grep -v "^note:$SETASK" "$BD/d.tsv" > "$BD/d2.tsv"
stg "$BD/d2.tsv"
ul_t_check "an offered note without a decision: aborted" aborted_with "$SETASK"
mkdec "$BD/d.tsv" "note:$HOOKS${TAB}decline"
stg "$BD/d.tsv"
ul_t_check "decline on a safety note: aborted" aborted_with 'safety'
mkdec "$BD/d.tsv" "note:$HOOKS${TAB}decline-final"
stg "$BD/d.tsv"
ul_t_check "decline-final on a safety note: aborted" aborted_with 'safety'
mkdec "$BD/d.tsv" "note:$GUIDE${TAB}decline-final" "note:$FOLLOW${TAB}decline"
stg "$BD/d.tsv"
ul_t_check "decline-final on a note that is neither project-data nor check none: aborted" aborted_with 'decline-final'
mkdec "$BD/d.tsv" "note:$GUIDE${TAB}decline"
stg "$BD/d.tsv"
ul_t_check "decline guidance + apply followup: aborted (blocked)" aborted_with 'blocked'
mkdec "$BD/d.tsv" "note:$GUIDE${TAB}decline" "note:$FOLLOW${TAB}decline" "$DOC${TAB}apply"
stg "$BD/d.tsv"
ul_t_check "apply on a path whose covering notes are all declined: aborted" aborted_with 'declined'
ul_t_check "all those refusals left no tag, worktree or staged file" clean_refusal
ul_t_check "all those refusals left HEAD alone" ul_t_eq "$(cg rev-parse HEAD)" "$H0"

cg commit -q --allow-empty -m "after the plan"
mkdec "$BD/d.tsv"
stg "$BD/d.tsv"
ul_t_check "stale plan (a commit after --plan): aborted" aborted_with 'stale'
ul_t_check "... nothing left behind" clean_refusal

# ================================================== 2. the default stage
setup || ul_t_done
pl; asv $SET "$BD/good.json" $HOOKS,$SETASK
H0=$(cg rev-parse HEAD); UID0=$(UID_)
mkdec "$BD/d.tsv"
REFS0=$(cg for-each-ref | grep -v 'refs/tags/loom/pre-update' )
stg "$BD/d.tsv"
ul_t_check "default: exit 0" ul_t_eq "$RC" 0
ul_t_check "default: result=staged" ul_t_eq "$(kv result)" staged
S1=$(kv staged)
TAG1=$(kv tag)
ul_t_check "default: staged= a 40-hex sha" ul_t_has "$S1" '^[0-9a-f]\{40\}$'
ul_t_check "default: land= is the exact ff-only command" ul_t_eq "$(kv land)" "git merge --ff-only $S1"
ul_t_check "default: update_id= matches the plan" ul_t_eq "$(kv update_id)" "$UID0"
ul_t_check "default: tag= has the pre-update shape" ul_t_has "$TAG1" '^loom/pre-update-[0-9]\{8\}-[0-9]\{6\}'
ul_t_check "default: no held= line" ul_t_hasnt "$OUT" '^held='
ul_t_check "default: the commit's parent is the customer's HEAD" ul_t_eq "$(cg rev-parse "$S1^")" "$H0"
ul_t_check "default: live HEAD unchanged" ul_t_eq "$(cg rev-parse HEAD)" "$H0"
ul_t_check "default: live tree clean" ul_t_eq "$(cg status --porcelain)" ""
ul_t_check "default: the tag points at the customer's HEAD" ul_t_eq "$(cg rev-parse "$TAG1^{commit}")" "$H0"
ul_t_check "default: state/staged holds the sha" ul_t_eq "$(cat "$(ST)/staged")" "$S1"
ul_t_check "default: the lock is released" test ! -e "$(ST)/stage.lock"
ul_t_check "default: the worktree exists" test -d "$(WT)"
ul_t_check "default: settings.json is the adapted body" ul_t_eq "$(show "$S1" $SET | cmp - "$BD/good.json" && echo same)" same
ul_t_check "default: FIXTURE.md keeps the customer's Appendix" ul_t_has "$(show "$S1" $DOC)" 'extended by the customer'
ul_t_check "default: FIXTURE.md has upstream's sentence" ul_t_has "$(show "$S1" $DOC)" 'Run /update-loom to take improvements.'
ul_t_check "default: FIXTURE-2.md is added" ul_t_has "$(show "$S1" $DOC2)" 'After the guide'
ul_t_check "default: the guard script is added" ul_t_has "$(show "$S1" $GUARD)" '.'
ul_t_check "default: .sdd-sync-ref is upstream's head" ul_t_eq "$(show "$S1" .sdd-sync-ref)" "$W_HEAD"
ul_t_check "default: amendments.md untouched (held by decision)" ul_t_eq "$(show "$S1" $AMD)" "$(show "$H0" $AMD)"
ul_t_check "default: ledger has five rows" ul_t_eq "$(git -C "$W_CUST" show "$S1:$LEDGER" | awk 'END { print NR }')" 5
ul_t_check "default: ledger $GUIDE applied" ul_t_eq "$(ledger_out "$S1" $GUIDE)" applied
ul_t_check "default: ledger $FOLLOW applied" ul_t_eq "$(ledger_out "$S1" $FOLLOW)" applied
ul_t_check "default: ledger $HOOKS applied" ul_t_eq "$(ledger_out "$S1" $HOOKS)" applied
ul_t_check "default: ledger $SETASK applied" ul_t_eq "$(ledger_out "$S1" $SETASK)" applied
ul_t_check "default: ledger $LADDER held (its only path was held by decision)" ul_t_eq "$(ledger_out "$S1" $LADDER)" held
NB=$(git -C "$W_CUST" hash-object --no-filters "$(ST)/notes/$GUIDE.md")
ul_t_check "default: ledger row carries blob, upstream sha, date" ul_t_eq "$(git -C "$W_CUST" show "$S1:$LEDGER" | awk -F'\t' '$1 == "'$GUIDE'" && $3 == "'$NB'" && $4 == "'$W_HEAD'" && $5 ~ /^[0-9]+-[0-9][0-9]-[0-9][0-9]$/ { print "ok" }')" ok
REC=.logic-loom/memory/updates/$UID0.applied
RT=$(show "$S1" $REC)
ul_t_check "default: .applied record header update_id" ul_t_has "$RT" "^update_id=$UID0\$"
ul_t_check "default: .applied record header tag" ul_t_has "$RT" "^tag=$TAG1\$"
ul_t_check "default: .applied record header parent" ul_t_has "$RT" "^parent=$H0\$"
ul_t_check "default: .applied record header upstream" ul_t_has "$RT" "^upstream=$W_HEAD\$"
GB=$(cg rev-parse "$S1:$GUARD")
ul_t_check "default: .applied lists the guard script, before - after blob+mode" ul_t_has "$RT" "^$GUARD${TAB}$GB${TAB}100644${TAB}-${TAB}-\$"
ul_t_check "default: .applied lists settings.json with its before blob" ul_t_has "$RT" "^$SET${TAB}$(cg rev-parse "$S1:$SET")${TAB}100644${TAB}$(cg rev-parse "$H0:$SET")${TAB}100644\$"
ul_t_check "default: .applied does not list the amendments file" ul_t_hasnt "$RT" "^$AMD"
EXPECT=$(printf '%s\n' $GUARD $SET $DOC2 $DOC $LEDGER $REC .sdd-sync-ref \
  $NOTES/amendments-ladder-plus-three.check.sh $NOTES/amendments-ladder-plus-three.md \
  $NOTES/fixture-doc-followup.check.sh $NOTES/fixture-doc-followup.md \
  $NOTES/fixture-doc-guidance.check.sh $NOTES/fixture-doc-guidance.md \
  $NOTES/hooks-guard-dangerous.check.sh $NOTES/hooks-guard-dangerous.md \
  $NOTES/settings-ask-restore.check.sh $NOTES/settings-ask-restore.md | LC_ALL=C sort)
ul_t_check "default: the changed set equals the expectation (allowlist holds)" ul_t_eq "$(changed_set "$S1")" "$EXPECT"
ul_t_check "default: changed= counts it" ul_t_eq "$(kv changed)" "$(changed_set "$S1" | awk 'END { print NR }')"
ul_t_check "default: an adopter hook that does not exist warns, does not abort" ul_t_has "$OUT" '^warn hook scripts/hooks/guard-prod-db.sh'

# the live commit is one above HEAD, no other branch/ref moved
ul_t_check "default: no branch was created" ul_t_eq "$(cg for-each-ref refs/heads | awk 'END { print NR }')" 1

# ---- guards on a staged update
stg "$BD/d.tsv"
ul_t_check "second --stage while staged: aborted" aborted_with 'staged'
pl
ul_t_check "--plan while staged: aborted" aborted_with 'staged'

# ---- the selftest gates
cp -R "$(WT)" "$BD/wtcopy-unused" 2>/dev/null; rm -rf "$BD/wtcopy-unused"
ul_t_run_engine --selftest-tree-gate "$(WT)"
ul_t_check "tree gate: ok on the staged worktree" ul_t_has "$OUT" '^tree-gate=ok'
ul_t_run_engine --selftest-allowlist "$(WT)" "$BD/d.tsv"
ul_t_check "allowlist: ok on the staged worktree" ul_t_has "$OUT" '^allowlist=ok'
printf 'rogue\n' > "$(WT)/rogue.txt"
git -C "$(WT)" add -A >/dev/null 2>&1
git -C "$(WT)" commit -q -m rogue
ul_t_run_engine --selftest-allowlist "$(WT)" "$BD/d.tsv"
ul_t_check "allowlist: a path no note allows is named" ul_t_has "$OUT" '^allowlist=violation path=rogue.txt'
printf '// changed\n' >> "$(WT)/web/app.js"
git -C "$(WT)" add -A >/dev/null 2>&1
git -C "$(WT)" commit -q -m "touch web"
ul_t_run_engine --selftest-tree-gate "$(WT)"
ul_t_check "tree gate: a changed web/ tree is a mismatch" ul_t_has "$OUT" '^tree-gate=mismatch tree=web'

# ---- abandon
ul_t_run_engine --abandon
ul_t_check "abandon: result=abandoned with the tag" ul_t_has "$OUT" "^result=abandoned tag=$TAG1 unchanged=yes\$"
ul_t_check "abandon: no worktree" test ! -d "$(WT)"
ul_t_check "abandon: no staged file" test ! -e "$(ST)/staged"
ul_t_check "abandon: the tag is kept" ul_t_eq "$(tags)" "$TAG1"
ul_t_check "abandon: HEAD unchanged, tree clean" ul_t_eq "$(cg rev-parse HEAD):$(cg status --porcelain)" "$H0:"
ul_t_check "abandon: worktree list is back to one" ul_t_eq "$(cg worktree list | awk 'END { print NR }')" 1
ul_t_run_engine --abandon
ul_t_check "abandon again: nothing-staged" ul_t_has "$OUT" '^result=nothing-staged'
pl
ul_t_check "after abandon: --plan works again" ul_t_eq "$(kv result)" planned

# =================================================== 3. informed take-theirs
setup || ul_t_done
H0=$(cg rev-parse HEAD); UID0=$(UID_)
mkdec "$BD/d.tsv" "$SET${TAB}take-theirs${TAB}informed=yes"
stg "$BD/d.tsv"
ul_t_check "take-theirs informed=yes: staged" ul_t_eq "$(kv result)" staged
S2=$(kv staged)
ul_t_check "take-theirs: settings.json is upstream's" ul_t_eq "$(show "$S2" $SET)" "$(git -C "$W_UP" show "$W_HEAD:$SET")"
ul_t_check "take-theirs: the customer's file is backed up under mine/<id>/" ul_t_eq "$(cmp "$(ST)/mine/$UID0/$SET" "$W_CUST/$SET" && echo same)" same
ul_t_run_engine --abandon
ul_t_check "abandon keeps the customer's backup" test -f "$(ST)/mine/$UID0/$SET"
pl
ul_t_check "a re-plan keeps the customer's backup" test -f "$(ST)/mine/$UID0/$SET"

# ================================================ 4. declines and the ladder
setup || ul_t_done
mkdec "$BD/d.tsv" "note:$LADDER${TAB}decline-final"
stg "$BD/d.tsv"
ul_t_check "decline-final on the project-data ladder note: staged" ul_t_eq "$(kv result)" staged
S3=$(kv staged)
ul_t_check "ladder: ledger declined-final" ul_t_eq "$(ledger_out "$S3" $LADDER)" declined-final
ul_t_run_engine --abandon

setup || ul_t_done
H0=$(cg rev-parse HEAD)
mkdec "$BD/d.tsv" "note:$GUIDE${TAB}decline" "note:$FOLLOW${TAB}decline"
stg "$BD/d.tsv"
ul_t_check "both guide notes declined: staged" ul_t_eq "$(kv result)" staged
S4=$(kv staged)
ul_t_check "declined: FIXTURE.md not written" ul_t_eq "$(show "$S4" $DOC)" "$(show "$H0" $DOC)"
ul_t_check "declined: FIXTURE-2.md not written" ul_t_not cg cat-file -e "$S4:$DOC2"
ul_t_check "declined: ledger declined" ul_t_eq "$(ledger_out "$S4" $GUIDE)" declined
ul_t_run_engine --abandon

# =========================================================== 5. _unnoted
nw || ul_t_done
ul_t_add_gov_stub "$W_CUST"
printf '\nupstream adds a section\n' >> "$W_UP/CLAUDE.md"
printf '// upstream web change\n' >> "$W_UP/web/app.js"
ul_t_commit "$W_UP" "upstream edits CLAUDE.md and web" >/dev/null
pl
ul_t_settings_variant good "$BD/good.json"
asv $SET "$BD/good.json" $HOOKS,$SETASK
H0=$(cg rev-parse HEAD)
mkdec "$BD/d.tsv"
grep -v '^note:_unnoted' "$BD/d.tsv" > "$BD/d2.tsv"
stg "$BD/d2.tsv"
ul_t_check "note:_unnoted missing when the plan has _unnoted rows: aborted" aborted_with '_unnoted'
ul_t_check "... nothing left behind" clean_refusal
mkdec "$BD/d.tsv" "note:_unnoted${TAB}decline"
stg "$BD/d.tsv"
ul_t_check "_unnoted decline: staged" ul_t_eq "$(kv result)" staged
S5=$(kv staged)
ul_t_check "_unnoted decline: CLAUDE.md not in the commit" ul_t_hasnt "$(changed_set "$S5")" '^CLAUDE.md$'
ul_t_check "forbidden tree: web/app.js is not in the commit" ul_t_hasnt "$(changed_set "$S5")" '^web/'
ul_t_run_engine --abandon
mkdec "$BD/d.tsv" "note:_unnoted${TAB}apply"
stg "$BD/d.tsv"
S6=$(kv staged)
ul_t_check "_unnoted apply: CLAUDE.md is in the commit" ul_t_has "$(changed_set "$S6")" '^CLAUDE.md$'
ul_t_check "_unnoted apply: web/app.js still is not" ul_t_hasnt "$(changed_set "$S6")" '^web/'
ul_t_check "_unnoted apply: web/app.js equals the customer's" ul_t_eq "$(show "$S6" web/app.js)" "$(show "$H0" web/app.js)"
ul_t_run_engine --abandon

# ============================================================ 6. mode only
nw || ul_t_done
ul_t_add_gov_stub "$W_CUST"
chmod +x "$W_UP/.claude/hooks/worktree-port-namespace.sh"
ul_t_commit "$W_UP" "upstream chmod +x" >/dev/null
pl
ul_t_settings_variant good "$BD/good.json"
asv $SET "$BD/good.json" $HOOKS,$SETASK
mkdec "$BD/d.tsv"
stg "$BD/d.tsv"
S7=$(kv staged)
ul_t_check "mode-only change: staged" ul_t_eq "$(kv result)" staged
ul_t_check "mode-only change: the commit carries 100755" ul_t_has "$(cg ls-tree "$S7" .claude/hooks/worktree-port-namespace.sh)" '^100755 '
ul_t_run_engine --abandon

# ============================================================ 7. hold-back
nw || ul_t_done
ul_t_add_gov_stub "$W_CUST"
sed 's/Run \/update-loom to take improvements\./Never-present sentence./' "$W_UP/$NOTES/$GUIDE.check.sh" > "$BD/chk"
cp "$BD/chk" "$W_UP/$NOTES/$GUIDE.check.sh"
ul_t_commit "$W_UP" "guidance check can never pass" >/dev/null
pl
ul_t_settings_variant good "$BD/good.json"
asv $SET "$BD/good.json" $HOOKS,$SETASK
H0=$(cg rev-parse HEAD)
mkdec "$BD/d.tsv"
stg "$BD/d.tsv"
ul_t_check "hold-back: staged" ul_t_eq "$(kv result)" staged
S8=$(kv staged)
ul_t_check "hold-back: $GUIDE held" ul_t_has "$OUT" "^held=$GUIDE\$"
ul_t_check "hold-back: $FOLLOW held by cascade" ul_t_has "$OUT" "^held=$FOLLOW\$"
ul_t_check "hold-back: FIXTURE.md equals the customer's" ul_t_eq "$(show "$S8" $DOC)" "$(show "$H0" $DOC)"
ul_t_check "hold-back: FIXTURE-2.md absent from the commit" ul_t_not cg cat-file -e "$S8:$DOC2"
ul_t_check "hold-back: ledger held for the guide" ul_t_eq "$(ledger_out "$S8" $GUIDE)" held
ul_t_check "hold-back: ledger held for the follow-up" ul_t_eq "$(ledger_out "$S8" $FOLLOW)" held
ul_t_check "hold-back: the commit was amended (one commit above HEAD)" ul_t_eq "$(cg rev-list --count "$S8" "^$H0")" 1
UIDH=$(UID_)
ul_t_check "hold-back: the .applied record drops the held paths" ul_t_hasnt "$(show "$S8" .logic-loom/memory/updates/$UIDH.applied)" "^$DOC"
ul_t_run_engine --abandon

# ============================================ 8. gate failures, machinery
nw || ul_t_done
ul_t_add_gov_stub "$W_CUST"
cat > "$W_UP/$SET" <<'EOF'
{
  "hooks": {
    "SessionStart": [
      { "matcher": "", "hooks": [ { "type": "command", "command": "bash .claude/hooks/worktree-port-namespace.sh" } ] }
    ],
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "bash plugins/loom-governance/hooks/scripts/git-safety-gate.sh" } ] }
    ]
  },
  "permissions": {
    "deny": ["Bash(git push --force:*)"],
    "allow": ["Bash(git status:*)"],
    "ask": ["Bash(git restore:*)"]
  }
}
EOF
ul_t_commit "$W_UP" "upstream settings without the guard hook" >/dev/null
pl
H0=$(cg rev-parse HEAD)
mkdec "$BD/d.tsv" "$SET${TAB}take-theirs${TAB}informed=yes"
stg "$BD/d.tsv"
ul_t_check "safety check failing in the worktree: aborted failed=checks" aborted_with 'failed=checks'
ul_t_check "... unchanged=yes" unchanged
ul_t_check "... the worktree is gone" test ! -d "$(WT)"
ul_t_check "... no staged file" test ! -e "$(ST)/staged"
ul_t_check "... the tag is kept" test -n "$(tags)"
ul_t_check "... HEAD unchanged" ul_t_eq "$(cg rev-parse HEAD)" "$H0"
ul_t_check "... a log path is named" ul_t_has "$OUT" 'log='

nw || ul_t_done
ul_t_add_gov_stub "$W_CUST"
cg rm -q -f plugins/loom-maintenance/scripts/updates-checks.sh && cc "customer lost the checks runner"
pl
ul_t_settings_variant good "$BD/good.json"
asv $SET "$BD/good.json" $HOOKS,$SETASK
mkdec "$BD/d.tsv"
stg "$BD/d.tsv"
ul_t_check "updates-checks.sh missing with a safety note: failed=machinery" aborted_with 'failed=machinery'
ul_t_check "... unchanged" unchanged

# ================================================== 9. hooks-resolve
nw || ul_t_done
ul_t_add_gov_stub "$W_CUST"
pl
ul_t_settings_variant good "$BD/good0.json"
awk '/guard-dangerous-commands.sh/ { print "          { \"type\": \"command\", \"command\": \"bash .claude/hooks/nope.sh\" }," } { print }' "$BD/good0.json" > "$BD/nope.json"
asv $SET "$BD/nope.json" $HOOKS,$SETASK
mkdec "$BD/d.tsv"
stg "$BD/d.tsv"
ul_t_check "hook naming a missing harness script: failed=hooks-resolve" aborted_with 'failed=hooks-resolve'
ul_t_check "... unchanged" unchanged

# ================================================ 10. symlinked parent
nw || ul_t_done
ul_t_add_gov_stub "$W_CUST"
cg rm -q -r -f .docs/guides >/dev/null 2>&1
mkdir -p "$W_CUST/.docs"
ln -s ../elsewhere "$W_CUST/.docs/guides"
cc "customer makes .docs/guides a symlink"
pl
ul_t_settings_variant good "$BD/good.json"
asv $SET "$BD/good.json" $HOOKS,$SETASK
mkdec "$BD/d.tsv" "$DOC${TAB}keep-mine"
stg "$BD/d.tsv"
ul_t_check "symlinked parent: the write is refused (symlink)" aborted_with 'symlink'
ul_t_check "... unchanged" unchanged
ul_t_check "... worktree gone" test ! -d "$(WT)"

# ============================================== 11. killed stage, live lock
setup || ul_t_done
H0=$(cg rev-parse HEAD)
mkdec "$BD/d.tsv"
( cd "$W_CUST" && LOOM_TEST_SLEEP_BEFORE_COMMIT=1 LOOM_UPDATE_SH="$SH" "$SH" "$ENGINE" --stage "$BD/d.tsv" </dev/null >"$BD/bg.out" 2>&1 ) &
i=0
while [ ! -e "$(ST)/.test-sleeping" ] && [ "$i" -lt 100 ]; do sleep 0.2; i=$((i + 1)); done
ul_t_check "killed stage: reached the planted sleep" test -e "$(ST)/.test-sleeping"
LP=$(sed -n '1p' "$(ST)/stage.lock" 2>/dev/null)
pkill -P "$LP" 2>/dev/null
kill -9 "$LP" 2>/dev/null
sleep 1
ul_t_run_engine --status
ul_t_check "killed stage: --status heals" ul_t_has "$OUT" '^healed=yes'
ul_t_check "killed stage: worktree removed" test ! -d "$(WT)"
ul_t_check "killed stage: lock removed" test ! -e "$(ST)/stage.lock"
rm -f "$(ST)/.test-sleeping"
stg "$BD/d.tsv"
ul_t_check "killed stage: --stage then succeeds" ul_t_eq "$(kv result)" staged
ul_t_run_engine --abandon
sleep 30 &
SP=$!
printf '%s\n' "$SP" > "$(ST)/stage.lock"
stg "$BD/d.tsv"
ul_t_check "a live lock: aborted" aborted_with 'staging'
kill "$SP" 2>/dev/null
rm -f "$(ST)/stage.lock"

ul_t_done
