#!/bin/sh
# Cases for --finish and --undo (package p0-engine-finish-undo): the post-landing
# smoke with its automatic revert, the revert verified by CONTENT (never by git's exit
# code), and --undo of one recorded update from any clone, including a clone with no
# .git/loom state and no tag.
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
fin() { ul_t_run_engine --finish; }
und() { ul_t_run_engine --undo "$@"; }
UID_() { sed -n 's/^update_id=//p' "$(ST)/meta"; }
tags() { cg tag -l 'loom/pre-update-*'; }
has_obj() { git -C "$1" cat-file -e "$2" 2>/dev/null; }
show() { cg show "$1:$2" 2>/dev/null; }

SET=.claude/settings.json
AMD=.logic-loom/memory/amendments.md
DOC=.docs/guides/FIXTURE.md
DOC2=.docs/guides/FIXTURE-2.md
GUARD=.claude/hooks/guard-dangerous-commands.sh
LEDGER=.logic-loom/memory/update-ledger.tsv
APPLIED=.logic-loom/memory/updates
HOOKS=hooks-guard-dangerous
SETASK=settings-ask-restore
GUIDE=fixture-doc-guidance
FOLLOW=fixture-doc-followup
LADDER=amendments-ladder-plus-three
NOTES=plugins/loom-maintenance/updates/7.0.0
JV=plugins/loom-maintenance/scripts/json-valid.sh
BD=$(ul_t_tmp)

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
# plan, stage and land (no --finish): sets H0 UID0 S TAG REC; extra args are decision overrides
upd() {
  setup || return 1
  H0=$(cg rev-parse HEAD); UID0=$(UID_)
  REC=$APPLIED/$UID0.applied
  mkdec "$BD/d.tsv" "$@"
  stg "$BD/d.tsv"
  S=$(kv staged); TAG=$(kv tag)
  [ "$(kv result)" = staged ] || { echo "FAIL  fixture: stage did not stage: $OUT"; fail=1; return 1; }
  ul_t_land || { echo "FAIL  fixture: land failed"; fail=1; return 1; }
}
# the paths of the .applied record at COMMIT
rec_paths() { git -C "$1" show "$2:$3" 2>/dev/null | awk -F'\t' 'NF >= 5 { print $1 }'; }
# 0 when every path of the record at COMMIT is, at HEAD of REPO, exactly what it was at PRE
restored() { # REPO COMMIT PRE REC
  rs_ok=0
  for rs_p in $(rec_paths "$1" "$2" "$4") $LEDGER $4 .sdd-sync-ref; do
    rs_a=$(git -C "$1" ls-tree HEAD -- "$rs_p" 2>/dev/null)
    rs_b=$(git -C "$1" ls-tree "$3" -- "$rs_p" 2>/dev/null)
    if [ "$rs_a" != "$rs_b" ]; then rs_ok=1; echo "differs: $rs_p" >&2; fi
  done
  return $rs_ok
}
subject() { cg log -1 --format=%s "$1"; }
refused() { [ "$RC" = 1 ] && ul_t_has "$OUT" '^result=refused '; }
refused_with() { refused && ul_t_has "$OUT" "$1"; }
state_gone() { [ ! -e "$(ST)/staged" ] && [ ! -e "$(ST)/stage.info" ] && [ ! -d "$(WT)" ] && [ ! -e "$(ST)/stage.lock" ]; }
tree_clean() { [ -z "$(cg status --porcelain)" ]; }
sec_ok() { ul_t_has "$1" "^$2"; }

# =================================================================== 0. syntax
ul_t_check "case file passes sh -n" sh -n "$here/cases-finish-undo.sh"
ul_t_check "case file passes dash -n" dash_n "$here/cases-finish-undo.sh"
ul_t_check "engine passes sh -n" sh -n "$ENG_SRC"
ul_t_check "engine passes dash -n" dash_n "$ENG_SRC"
NEVER="reset --hard|git push|branch -D|worktree add -b|tag -d"
ul_t_check "engine never resets hard, pushes, deletes a branch or a tag" ul_t_not grep -Eq "$NEVER" "$ENG_SRC"
ul_t_check "engine never force-pushes, force-deletes or rewrites history" ul_t_not grep -Eq 'push --force|--force-with-lease|filter-branch|update-ref -d|branch -d|clean -f' "$ENG_SRC"
ul_t_check "engine has no bash-isms" ul_t_not grep -Eq '^[[:space:]]*(local|function)[[:space:]]|\[\[|<<<' "$ENG_SRC"
nw || ul_t_done
help_out=$(cd "$W_CUST" && "$SH" "$ENGINE" --help 2>&1)
ul_t_check "help: --finish is built" ul_t_hasnt "$help_out" 'finish.*not built'
ul_t_check "help: --undo is built" ul_t_hasnt "$help_out" 'undo.*not built'
ul_t_run_engine --finish
ul_t_check "finish with nothing staged: not-landed, staged=none" ul_t_has "$OUT" '^result=not-landed staged=none head=[0-9a-f]\{40\}$'
ul_t_check "finish with nothing staged: exit 1" ul_t_eq "$RC" 1
ul_t_run_engine --undo
ul_t_check "undo with no update recorded: nothing-to-undo, exit 0" ul_t_has "$OUT" '^result=nothing-to-undo'
ul_t_check "undo with no update recorded: exit 0" ul_t_eq "$RC" 0
ul_t_run_engine --undo no-such-id
ul_t_check "undo of an id with no record: refused" refused_with 'no-such-id'

# ======================================================== 1. the happy path
setup || ul_t_done
H0=$(cg rev-parse HEAD); UID0=$(UID_); REC=$APPLIED/$UID0.applied
mkdec "$BD/d.tsv" "note:$LADDER${TAB}decline-final"
stg "$BD/d.tsv"
S1=$(kv staged); TAG1=$(kv tag)
ul_t_check "happy: staged" ul_t_eq "$(kv result)" staged
fin
ul_t_check "finish before landing: not-landed with both shas" ul_t_has "$OUT" "^result=not-landed staged=$S1 head=$H0\$"
ul_t_check "finish before landing: exit 1" ul_t_eq "$RC" 1
ul_t_check "finish before landing: the staged update is untouched" ul_t_eq "$(cat "$(ST)/staged"):$(test -d "$(WT)" && echo wt)" "$S1:wt"
ul_t_check "finish before landing: HEAD unchanged" ul_t_eq "$(cg rev-parse HEAD)" "$H0"
ul_t_land
fin
ul_t_check "happy: exit 0" ul_t_eq "$RC" 0
ul_t_check "happy: result=applied with commit, tag, update id and held" ul_t_has "$OUT" "^result=applied commit=$S1 tag=$TAG1 update_id=$UID0 held=none\$"
ul_t_check "happy: next= points at /git-push" ul_t_has "$OUT" '^next=run /git-push when ready$'
ul_t_check "happy: HEAD is the staged commit (no revert)" ul_t_eq "$(cg rev-parse HEAD)" "$S1"
ul_t_check "happy: state/staged, stage.info, worktree and lock are gone" state_gone
ul_t_check "happy: the worktree list is back to one" ul_t_eq "$(cg worktree list | awk 'END { print NR }')" 1
ul_t_check "happy: the pre-update tag is kept" ul_t_eq "$(tags)" "$TAG1"
ul_t_check "happy: last-smoke.log is written" test -s "$(ST)/last-smoke.log"
ul_t_check "happy: live settings.json is valid JSON" sh "$W_CUST/$JV" "$W_CUST/$SET"
ul_t_check "happy: live settings.json carries the guard hook" ul_t_has "$(cat "$W_CUST/$SET")" 'guard-dangerous-commands.sh'
ul_t_check "happy: the ledger has five rows in HEAD" ul_t_eq "$(show HEAD $LEDGER | awk 'END { print NR }')" 5
ul_t_check "happy: the .applied record is in HEAD" ul_t_has "$(show HEAD $REC)" "^update_id=$UID0\$"
ul_t_check "happy: the tree is clean" tree_clean
ul_t_run_engine --status
ul_t_check "happy: --status staged=none" ul_t_has "$OUT" '^staged=none$'
ul_t_check "happy: --status ledger_rows=5" ul_t_has "$OUT" '^ledger_rows=5$'
ul_t_check "happy: --status base is upstream's commit 2" ul_t_has "$OUT" "^base=$W_HEAD\$"
pl
ul_t_check "happy: a second plan is up to date" ul_t_eq "$(kv uptodate)" yes
fin
ul_t_check "finish again: not-landed, staged=none" ul_t_has "$OUT" '^result=not-landed staged=none head='
ul_t_check "finish again: exit 1" ul_t_eq "$RC" 1

# ---- held notes are reported, backups and logs survive
upd || ul_t_done
fin
ul_t_check "held: result=applied" ul_t_has "$OUT" "^result=applied commit=$S "
ul_t_check "held: held= lists the held note" ul_t_has "$OUT" " held=$LADDER\$"
ul_t_check "held: the amendments file is untouched" ul_t_eq "$(show HEAD $AMD)" "$(show $H0 $AMD)"

# ---- take-theirs keeps the customer's backup, and the invariants accept upstream's own file
setup || ul_t_done
H0=$(cg rev-parse HEAD); UID0=$(UID_); REC=$APPLIED/$UID0.applied
mkdec "$BD/d.tsv" "$SET${TAB}take-theirs${TAB}informed=yes" "note:$HOOKS${TAB}apply"
stg "$BD/d.tsv"
ul_t_check "take-theirs: staged" ul_t_eq "$(kv result)" staged
ul_t_land
fin
ul_t_check "take-theirs: finish applied (upstream's own file is never an invariant violation)" ul_t_has "$OUT" '^result=applied '
ul_t_check "take-theirs: the customer's backup under mine/<id>/ is still there" test -f "$(ST)/mine/$UID0/$SET"
ul_t_check "take-theirs: last-smoke.log is still there" test -f "$(ST)/last-smoke.log"
pl
ul_t_check "a re-plan keeps both" test -f "$(ST)/mine/$UID0/$SET"

# ============================================ 2. smoke failure: auto-revert
# Each case tampers with the LIVE tree after landing (uncommitted), so the staged
# commit passed its own gate and the smoke is what catches the difference.
reverted_ok() { # TAGSHA : the invariant set every auto-revert must leave behind
  [ "$RC" = 1 ] && ul_t_has "$OUT" "^result=reverted reason=$1 tag=$TAG log=.*last-smoke.log\$" \
    && [ "$(subject HEAD | cut -c1-6)" = Revert ] \
    && [ "$(cg rev-parse HEAD^)" = "$S" ] \
    && restored "$W_CUST" "$S" "$H0" "$REC" \
    && [ ! -e "$W_CUST/$LEDGER" ] \
    && [ "$(cat "$W_CUST/.sdd-sync-ref")" = "$W_BASE" ] \
    && [ "$(tags)" = "$TAG" ] \
    && state_gone && tree_clean
}

upd || ul_t_done
rm -f "$W_CUST/$GUARD"
fin
ul_t_check "smoke failure (the guard script is gone): reverted, reason=checks, and every restore invariant holds" reverted_ok checks
ul_t_check "reverted: the ledger is absent at HEAD" ul_t_not has_obj "$W_CUST" "HEAD:$LEDGER"
ul_t_check "reverted: the record is absent at HEAD" ul_t_not has_obj "$W_CUST" "HEAD:$REC"
ul_t_check "reverted: the guard script is back to absent in the tree" test ! -e "$W_CUST/$GUARD"
ul_t_check "reverted: the log says why" ul_t_has "$(cat "$(ST)/last-smoke.log" 2>/dev/null)" 'checks'
ul_t_check "reverted: HEAD is not the pre-update tag's commit (a revert commit, not a rewind)" ul_t_not test "$(cg rev-parse HEAD)" = "$H0"
ul_t_check "reverted: the staged commit is still in history" cg merge-base --is-ancestor "$S" HEAD
pl
ul_t_check "reverted: a plan afterwards offers the update again" ul_t_eq "$(kv result)" planned
ul_t_check "reverted: the notes are offered again (ledger empty)" ul_t_has "$OUT" '^notes=5 '

upd || ul_t_done
printf 'edited after landing\n' >> "$W_CUST/$DOC2"
fin
ul_t_check "a harness file differing from the commit: reverted, reason=harness-diff" reverted_ok harness-diff
ul_t_check "harness-diff: the log records the reset of the tracked file" ul_t_has "$(cat "$(ST)/last-smoke.log" 2>/dev/null)" "$DOC2"

upd || ul_t_done
sed 's/Run \/update-loom to take improvements\./Gone./' "$W_CUST/$DOC" > "$BD/doc.edit" && cp "$BD/doc.edit" "$W_CUST/$DOC"
fin
ul_t_check "a non-safety check failing in a copy is a WARN, so the reason is the tree diff, not checks" reverted_ok harness-diff

upd || ul_t_done
awk '/guard-dangerous-commands.sh/ { print "          { \"type\": \"command\", \"command\": \"bash .claude/hooks/nope.sh\" }," } { print }' "$W_CUST/$SET" > "$BD/nope.json"
cp "$BD/nope.json" "$W_CUST/$SET"
fin
ul_t_check "a hook naming a missing harness script: reverted, reason=hooks-resolve" reverted_ok hooks-resolve

upd || ul_t_done
sed 's/, "Bash(rm -rf:\*)"//' "$W_CUST/$SET" > "$BD/normf.json"
cp "$BD/normf.json" "$W_CUST/$SET"
fin
ul_t_check "a relaxed deny list in the live settings.json: reverted, reason=invariants" reverted_ok invariants

# ---- reverted-failed: the revert commit does not restore the content
upd || ul_t_done
mkdir -p "$W_CUST/.git/hooks"
cat > "$W_CUST/.git/hooks/post-commit" <<'EOF'
#!/bin/sh
[ -f .git/ul-tamper ] || exit 0
rm -f .git/ul-tamper
unset GIT_INDEX_FILE
printf 'tampered by a hook\n' >> .docs/guides/FIXTURE.md
git add .docs/guides/FIXTURE.md
git commit -q --amend --no-edit --no-verify
EOF
chmod +x "$W_CUST/.git/hooks/post-commit"
: > "$W_CUST/.git/ul-tamper"
rm -f "$W_CUST/$GUARD"
fin
ul_t_check "revert that reports success but leaves content wrong: reverted-failed" ul_t_has "$OUT" "^result=reverted-failed pre_update_tag=$TAG mismatched=.*$DOC"
ul_t_check "reverted-failed: exit 1" ul_t_eq "$RC" 1
ul_t_check "reverted-failed: HEAD is not the pre-update tag's commit (no rewind)" ul_t_not test "$(cg rev-parse HEAD)" = "$H0"
ul_t_check "reverted-failed: HEAD is not the landed commit either (the revert commit stays)" ul_t_not test "$(cg rev-parse HEAD)" = "$S"
ul_t_check "reverted-failed: the working tree matches HEAD (nothing half-done)" tree_clean
ul_t_check "reverted-failed: the tag is kept" ul_t_eq "$(tags)" "$TAG"
ul_t_check "reverted-failed: nothing waits in .git/loom to be finished" state_gone
ul_t_check "reverted-failed: last-smoke.log exists" test -s "$(ST)/last-smoke.log"
rm -f "$W_CUST/.git/hooks/post-commit"

# ======================================== 3. --undo from a clone with no state
upd || ul_t_done
cp "$(ST)/plan.tsv" "$BD/plan0.tsv" 2>/dev/null
fin
ul_t_check "undo fixture: the update finished" ul_t_has "$OUT" '^result=applied '
CL=$(ul_t_clone_fresh) || ul_t_done
ul_t_check "clone: no tag and no loom state" ul_t_eq "$(git -C "$CL" tag -l | awk 'END { print NR }')$(test -d "$(git -C "$CL" rev-parse --absolute-git-dir)/loom" && echo state)" 0
ul_t_run_in "$CL" --undo
ul_t_check "clone undo: result=undone with commit and undid" ul_t_has "$OUT" "^result=undone commit=[0-9a-f]\{40\} undid=$S update_id=$UID0\$"
ul_t_check "clone undo: exit 0" ul_t_eq "$RC" 0
RV=$(printf '%s\n' "$OUT" | sed -n 's/^result=undone commit=\([0-9a-f]*\) .*/\1/p')
ul_t_check "clone undo: HEAD is the revert commit and its parent is the update" ul_t_eq "$(git -C "$CL" rev-parse HEAD):$(git -C "$CL" rev-parse HEAD^)" "$RV:$S"
ul_t_check "clone undo: every recorded path, the ledger and the record equal the pre-update tree" restored "$CL" "$S" "$H0" "$REC"
ul_t_check "clone undo: the ledger is gone" ul_t_not has_obj "$CL" "HEAD:$LEDGER"
ul_t_check "clone undo: the .applied record is gone" ul_t_not has_obj "$CL" "HEAD:$REC"
ul_t_check "clone undo: .sdd-sync-ref is commit 1 again" ul_t_eq "$(git -C "$CL" show HEAD:.sdd-sync-ref)" "$W_BASE"
ul_t_check "clone undo: the files on disk equal the pre-update files" ul_t_eq "$(cat "$CL/$DOC")" "$(show $H0 $DOC)"
ul_t_check "clone undo: the added file is gone from disk" test ! -e "$CL/$DOC2"
ul_t_check "clone undo: the tree is clean" ul_t_eq "$(git -C "$CL" status --porcelain)" ""
ul_t_check "clone undo: the output says what was restored" ul_t_has "$OUT" '^note=.*ledger.*\.applied.*\.sdd-sync-ref'
ul_t_run_in "$CL" --undo
ul_t_check "clone undo again: nothing-to-undo" ul_t_has "$OUT" '^result=nothing-to-undo'
ul_t_check "clone undo again: exit 0" ul_t_eq "$RC" 0
ul_t_run_in "$CL" --plan
ul_t_check "clone plan after undo: planned" ul_t_eq "$(kv result)" planned
ul_t_check "clone plan after undo: base is commit 1 again" ul_t_eq "$(kv base)" "$W_BASE"
ul_t_check "clone plan after undo: the notes are offered again" ul_t_has "$OUT" '^notes=5 '
CS=$CL/.git/loom/update
ul_t_check "clone plan after undo: the classes equal the original plan's" ul_t_eq "$(awk -F'\t' '{ print $1 "\t" $2 "\t" $3 }' "$CS/plan.tsv" | LC_ALL=C sort)" "$(awk -F'\t' '{ print $1 "\t" $2 "\t" $3 }' "$BD/plan0.tsv" | LC_ALL=C sort)"
ul_t_check "clone plan after undo: the follow-up file is an add again" ul_t_eq "$(awk -F'\t' -v p="$DOC2" '$1 == p { print $2 }' "$CS/plan.tsv")" "$(awk -F'\t' -v p="$DOC2" '$1 == p { print $2 }' "$BD/plan0.tsv")"
# the original clone still has its state; its tag is a convenience only
ul_t_run_engine --status
ul_t_check "original customer: finish left nothing staged" ul_t_has "$OUT" '^staged=none$'

# ================================================ 4. overlap and unrelated edits
upd || ul_t_done
fin
ul_t_edit "$W_CUST" "$DOC" "customer rewrote the guide after the update" "customer edits the guide" >/dev/null
HB=$(cg rev-parse HEAD)
und
ul_t_check "overlap: refused" refused_with 'reason=later changes overlap the update'
ul_t_check "overlap: names the path" ul_t_has "$OUT" "paths=.*$DOC"
ul_t_check "overlap: exit 1" ul_t_eq "$RC" 1
ul_t_check "overlap: HEAD unchanged, tree clean" ul_t_eq "$(cg rev-parse HEAD):$(cg status --porcelain)" "$HB:"
ul_t_check "overlap: no revert in progress" test ! -e "$(git -C "$W_CUST" rev-parse --absolute-git-dir)/REVERT_HEAD"

upd || ul_t_done
fin
ul_t_edit "$W_CUST" "notes-of-mine.txt" "an unrelated file" "customer adds an unrelated file" >/dev/null
und
ul_t_check "unrelated edit: undone" ul_t_has "$OUT" '^result=undone '
ul_t_check "unrelated edit: the customer's own file stays" test -f "$W_CUST/notes-of-mine.txt"
ul_t_check "unrelated edit: the update's files are gone" ul_t_eq "$(cat "$W_CUST/$DOC")" "$(show $H0 $DOC)"
ul_t_check "unrelated edit: the ledger is gone" test ! -e "$W_CUST/$LEDGER"

# an edit that was put back exactly is not an overlap
upd || ul_t_done
fin
ul_t_edit "$W_CUST" "$DOC" "somebody else's text" "customer edits the guide" >/dev/null
git -C "$W_CUST" show "$S:$DOC" > "$W_CUST/$DOC"
cc "customer puts the guide back as the update left it"
und
ul_t_check "an edit put back exactly: undone (the later commits changed nothing in the end)" ul_t_has "$OUT" '^result=undone '
ul_t_check "... and the guide is the pre-update one" ul_t_eq "$(cat "$W_CUST/$DOC")" "$(show $H0 $DOC)"

# the staged commit landed, then the customer committed on top before --finish
upd || ul_t_done
ul_t_edit "$W_CUST" "notes-of-mine.txt" "committed right after landing" "customer commits before finish" >/dev/null
fin
ul_t_check "finish after HEAD moved past the staged commit: moved-on, exit 1" ul_t_has "$OUT" "^result=moved-on staged=$S head="
ul_t_check "moved-on: exit 1" ul_t_eq "$RC" 1
ul_t_check "moved-on: the staged state is cleared so a new --stage is possible" state_gone
ul_t_check "moved-on: the tag is kept" ul_t_eq "$(tags)" "$TAG"
und
ul_t_check "moved-on: --undo then reverses the update" ul_t_has "$OUT" '^result=undone '
ul_t_check "moved-on: the customer's own commit survives the undo" test -f "$W_CUST/notes-of-mine.txt"

# the engine's own bookkeeping edited later: the revert conflicts, is aborted, and a person decides
upd || ul_t_done
fin
printf 'customer-chose-this\n' > "$W_CUST/.sdd-sync-ref"
cc "customer hand-edits the pointer"
HC=$(cg rev-parse HEAD)
und
ul_t_check "conflict in the bookkeeping: reverted-failed" ul_t_has "$OUT" '^result=reverted-failed .*mismatched=.*\.sdd-sync-ref'
ul_t_check "conflict: names the pre-update tag (taken from the record)" ul_t_has "$OUT" "pre_update_tag=$TAG"
ul_t_check "conflict: exit 1" ul_t_eq "$RC" 1
ul_t_check "conflict: the revert was aborted, HEAD and tree are as they were" ul_t_eq "$(cg rev-parse HEAD):$(cg status --porcelain)" "$HC:"
ul_t_check "conflict: no revert left in progress" test ! -e "$(git -C "$W_CUST" rev-parse --absolute-git-dir)/REVERT_HEAD"

# ================================================ 5. two updates, newest first
upd "note:$LADDER${TAB}decline-final" || ul_t_done
fin
UIDA=$UID0; SA=$S; H0A=$H0; RECA=$REC
mkdir -p "$W_UP/$NOTES"
cat > "$W_UP/$NOTES/claude-md-line.md" <<'EOF'
---
id: claude-md-line
title: CLAUDE.md gets one more line
purpose: The project instructions carry the line the second release adds.
touches:
  - CLAUDE.md
adds: []
requires: []
safety: false
done-when:
  - "CLAUDE.md has the second-release line"
check: none
project-data: false
---

## What changed and why

One line is added to `CLAUDE.md`.

## What a stock file looks like after

`CLAUDE.md` ends with `Second release line.`
EOF
printf 'Second release line.\n' >> "$W_UP/CLAUDE.md"
ul_t_commit "$W_UP" "second release" >/dev/null
W_HEAD2=$(ug rev-parse HEAD)
pl
UIDB=$(UID_)
ul_t_check "second update: planned with one offered note" ul_t_has "$OUT" '^notes=1 '
ul_t_decisions "$BD/d2.tsv" "note:claude-md-line${TAB}apply"
stg "$BD/d2.tsv"
if [ "$(kv result)" != staged ]; then
  ul_t_decisions "$BD/d2.tsv" "note:claude-md-line${TAB}apply" "note:_unnoted${TAB}apply"
  stg "$BD/d2.tsv"
fi
ul_t_check "second update: staged" ul_t_eq "$(kv result)" staged
SB=$(kv staged); TAGB=$(kv tag)
und
ul_t_check "undo while an update is staged: refused" refused_with 'staged'
ul_t_land
fin
ul_t_check "second update: applied" ul_t_has "$OUT" '^result=applied '
ul_t_check "second update: CLAUDE.md has the line" ul_t_has "$(cat "$W_CUST/CLAUDE.md")" 'Second release line.'
HAB=$(cg rev-parse HEAD)
und "$UIDA"
ul_t_check "undo the older update beneath a newer one: refused" refused_with 'older update'
ul_t_check "... and lists the newer record" ul_t_has "$OUT" "$UIDB"
ul_t_check "... HEAD unchanged" ul_t_eq "$(cg rev-parse HEAD)" "$HAB"
und
ul_t_check "default undo takes the newest: undone" ul_t_has "$OUT" "^result=undone commit=[0-9a-f]\{40\} undid=$SB update_id=$UIDB\$"
ul_t_check "default undo: CLAUDE.md is back" ul_t_not grep -q 'Second release line.' "$W_CUST/CLAUDE.md"
ul_t_check "default undo: the first update is untouched (ledger still has five rows)" ul_t_eq "$(show HEAD $LEDGER | awk 'END { print NR }')" 5
ul_t_check "default undo: .sdd-sync-ref is the first update's upstream" ul_t_eq "$(cat "$W_CUST/.sdd-sync-ref")" "$W_HEAD"
und
ul_t_check "second default undo: now the first update is undone" ul_t_has "$OUT" "^result=undone commit=[0-9a-f]\{40\} undid=$SA update_id=$UIDA\$"
ul_t_check "after both: every first-update path equals pre-update" restored "$W_CUST" "$SA" "$H0A" "$RECA"
und
ul_t_check "after both: nothing-to-undo" ul_t_has "$OUT" '^result=nothing-to-undo'

# ====================================================== 6. refusals of --undo
upd || ul_t_done
fin
HF=$(cg rev-parse HEAD)
printf 'dirty\n' >> "$W_CUST/CLAUDE.md"
und
ul_t_check "dirty tree: refused" refused_with 'uncommitted'
cg checkout -q -- CLAUDE.md
GDIR=$(git -C "$W_CUST" rev-parse --absolute-git-dir)
: > "$GDIR/REVERT_HEAD"
und
ul_t_check "revert in progress: refused" refused_with 'unfinished'
rm -f "$GDIR/REVERT_HEAD"
ul_t_check "refusals changed nothing" ul_t_eq "$(cg rev-parse HEAD):$(cg status --porcelain)" "$HF:"

# a record whose parent= line was edited and committed
TR=$(show HEAD $REC | sed "s/^parent=.*/parent=0000000000000000000000000000000000000000/")
printf '%s\n' "$TR" > "$W_CUST/$REC"
cc "customer edits the record"
HT=$(cg rev-parse HEAD)
und
ul_t_check "tampered record (parent= edited): refused" refused
ul_t_check "tampered record: says the record does not match" ul_t_has "$OUT" '^result=refused reason=.*record'
ul_t_check "tampered record: HEAD unchanged" ul_t_eq "$(cg rev-parse HEAD)" "$HT"

# a hand-made record in a commit that is not an update commit
upd || ul_t_done
fin
HP=$(cg rev-parse HEAD)
printf 'update_id=99990101T000000Z-aaaaaaaaaaaa\ntag=loom/pre-update-x\nparent=%s\nbase=%s\nupstream=%s\nchannel=template\ndate=2026-01-01T00:00:00Z\nCLAUDE.md\t-\t-\t-\t-\n' "$HP" "$W_BASE" "$W_HEAD" > "$BD/fake.rec"
mkdir -p "$W_CUST/$APPLIED"
cp "$BD/fake.rec" "$W_CUST/$APPLIED/99990101T000000Z-aaaaaaaaaaaa.applied"
cc "just a commit that adds a record"
und
ul_t_check "a record added by a commit that is not an update commit: refused" refused_with 'does not look like an update'
ul_t_check "that refusal changed nothing" ul_t_eq "$(cg status --porcelain)" ""
# the same, with the right subject, a matching parent, and a forbidden path in the record
HP2=$(cg rev-parse HEAD)
printf 'update_id=99990101T000000Z-bbbbbbbbbbbb\ntag=loom/pre-update-x\nparent=%s\nbase=%s\nupstream=%s\nchannel=template\ndate=2026-01-01T00:00:00Z\nweb/app.js\t-\t-\t-\t-\n' "$HP2" "$W_BASE" "$W_HEAD" > "$BD/fake2.rec"
cp "$BD/fake2.rec" "$W_CUST/$APPLIED/99990101T000000Z-bbbbbbbbbbbb.applied"
cg add -A >/dev/null 2>&1; cg commit -q -m "LogicLoom update to bbbbbbbbbbbb"
und
ul_t_check "a record listing a forbidden path: refused" refused_with 'forbidden'
ul_t_check "... names the path" ul_t_has "$OUT" 'web/app.js'
ul_t_check "forbidden refusal: HEAD and tree unchanged" ul_t_eq "$(cg status --porcelain)" ""

ul_t_done
