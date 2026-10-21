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
# --finish refuses a dirty tree, so a case that wants the LIVE disk to differ from the
# landed commit while git still reports a clean tree hides the path from git first
# (skip-worktree: status and diff both say clean, the disk is what the smoke reads).
sneak() { cg update-index --skip-worktree -- "$1"; }
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
# Each case tampers with the LIVE disk after landing but hides the tamper from git
# (sneak), because --finish refuses a dirty tree: the staged commit passed its own gate
# and the smoke is what catches the difference.
reverted_ok() { # REASON : the invariant set every auto-revert must leave behind
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
sneak "$GUARD"
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

# ---- a dirty tree is refused BEFORE anything is acquired or run, and nothing is discarded
dirty_refusal() { # PATH : the refusal names PATH, exit 1, the update is still staged and landed
  [ "$RC" = 1 ] && ul_t_has "$OUT" "^result=refused reason=dirty-tree paths=.*$1" \
    && [ "$(cg rev-parse HEAD)" = "$S" ] \
    && [ "$(cat "$(ST)/staged")" = "$S" ] && [ -f "$(ST)/stage.info" ] && [ -d "$(WT)" ] \
    && [ ! -e "$(ST)/stage.lock" ] && [ "$(tags)" = "$TAG" ] \
    && [ ! -e "$(ST)/last-smoke.log" ]
}
upd || ul_t_done
printf 'edited after landing\n' >> "$W_CUST/$DOC2"
cp "$W_CUST/$DOC2" "$BD/doc2.keep"
fin
ul_t_check "an uncommitted edit to a harness file: refused, dirty-tree, names the path, nothing run" dirty_refusal "$DOC2"
ul_t_check "... the edit is byte-for-byte intact" cmp -s "$W_CUST/$DOC2" "$BD/doc2.keep"
ul_t_check "... no ledger row, no revert commit: the update is still applied" ul_t_eq "$(subject HEAD | cut -c1-6)" "LogicL"
cg checkout -q -- "$DOC2"
fin
ul_t_check "... after the edit is put back, --finish applies" ul_t_has "$OUT" '^result=applied '

upd || ul_t_done
printf 'staged edit\n' >> "$W_CUST/$DOC2"
cg add "$DOC2"
cg show ":$DOC2" > "$BD/idx.keep"
fin
ul_t_check "a STAGED (index-only) harness edit: refused, dirty-tree, names the path" dirty_refusal "$DOC2"
ul_t_check "... the index entry is intact" ul_t_eq "$(cg show ":$DOC2")" "$(cat "$BD/idx.keep")"
ul_t_check "... the edit is still staged" ul_t_has "$(cg diff --cached --name-only)" "$DOC2"
cg reset -q -- "$DOC2" >/dev/null 2>&1
cg checkout -q -- "$DOC2"

upd || ul_t_done
printf 'my own words\n' >> "$W_CUST/CLAUDE.md"
cp "$W_CUST/CLAUDE.md" "$BD/claude.keep"
fin
ul_t_check "an uncommitted edit to a NON-harness file: refused too, dirty-tree" dirty_refusal 'CLAUDE.md'
ul_t_check "... the edit is byte-for-byte intact" cmp -s "$W_CUST/CLAUDE.md" "$BD/claude.keep"

upd || ul_t_done
cp "$(git -C "$W_CUST" rev-parse --absolute-git-dir)/index" "$BD/index.bak"
printf 'not an index at all\n' > "$(git -C "$W_CUST" rev-parse --absolute-git-dir)/index"
fin
ul_t_check "an unreadable index (git status fails): refused, never read as a clean tree" ul_t_has "$OUT" '^result=refused reason=dirty-tree paths=git-status-failed'
ul_t_check "... exit 1, nothing was run" ul_t_eq "$RC:$(test -e "$(ST)/last-smoke.log" && echo log)" "1:"
cp "$BD/index.bak" "$(git -C "$W_CUST" rev-parse --absolute-git-dir)/index"
ul_t_check "the engine no longer has a path that checks files out of the working tree" ul_t_not grep -q 'fin_reset_harness' "$ENG_SRC"

# ---- harness-diff. With the dirty-tree gate in front, a tracked divergence cannot exist
# on a clean tree at HEAD == staged, so the smoke's last step is a belt-and-braces
# re-verification, and it is fail-closed. The cases drive it with a git that says the
# tree differs, and with a git whose diff fails.
upd || ul_t_done
SH1=$(ul_t_shim_make)
printf '%s\n' 'case " $* " in *" diff --name-only HEAD "*) printf "%s\n" ".docs/guides/FIXTURE.md"; exit 0;; esac' > "$SH1/hook.sh"
ul_t_run_engine_shim "$SH1" --finish
ul_t_check "a harness file that differs from the commit (reported by git): reverted, reason=harness-diff" reverted_ok harness-diff
ul_t_check "harness-diff: the log names the file" ul_t_has "$(cat "$(ST)/last-smoke.log" 2>/dev/null)" "$DOC"

upd || ul_t_done
SH2=$(ul_t_shim_make)
printf '%s\n' 'case " $* " in *" diff --name-only HEAD "*) echo "fatal: simulated" >&2; exit 128;; esac' > "$SH2/hook.sh"
ul_t_run_engine_shim "$SH2" --finish
ul_t_check "git diff failing during the smoke is a failed smoke, never a clean one (fail closed)" reverted_ok harness-diff
ul_t_check "... the log says git failed" ul_t_has "$(cat "$(ST)/last-smoke.log" 2>/dev/null)" 'git diff failed'

upd || ul_t_done
STUB=plugins/loom-governance/hooks/scripts/git-safety-gate.sh
sneak "$STUB"
rm -f "$W_CUST/$STUB"
fin
ul_t_check "a hook naming a harness script that is gone from disk: reverted, reason=hooks-resolve" reverted_ok hooks-resolve

# A relaxed deny list on the live disk: the smoke fails (invariants). The edit is to a
# file the revert must rewrite, so git refuses to overwrite it: the result is
# reverted-failed with the customer's disk edit intact. Nothing is discarded.
upd || ul_t_done
sneak "$SET"
sed 's/, "Bash(rm -rf:\*)"//' "$W_CUST/$SET" > "$BD/normf.json"
cp "$BD/normf.json" "$W_CUST/$SET"
fin
ul_t_check "a relaxed deny list in the live settings.json: the smoke fails with reason=invariants" ul_t_has "$OUT" '^result=reverted-failed .*reason=invariants'
ul_t_check "... git declined to overwrite the edited file: HEAD is still the landed commit" ul_t_eq "$(cg rev-parse HEAD)" "$S"
ul_t_check "... the disk edit is intact, byte for byte" cmp -s "$W_CUST/$SET" "$BD/normf.json"
ul_t_check "... the tag is kept and the state is cleared" ul_t_eq "$(tags):$(state_gone && echo gone)" "$TAG:gone"

# ---- reverted-failed: the revert commit does not restore the content. A git that
# reports success but leaves a tampered file in the revert commit stands for any such
# cause (a customer filter, a hook the engine did not suppress).
upd || ul_t_done
SH3=$(ul_t_shim_make)
cat > "$SH3/hook.sh" <<EOT
case " \$* " in *" revert --no-edit "*)
  "\$REAL" "\$@"; rc=\$?
  printf 'tampered\\n' >> "$W_CUST/$DOC"
  "\$REAL" -C "$W_CUST" add "$DOC"
  "\$REAL" -C "$W_CUST" -c core.hooksPath=/dev/null commit -q --amend --no-edit --no-verify
  exit \$rc;;
esac
EOT
sneak "$GUARD"
rm -f "$W_CUST/$GUARD"
ul_t_run_engine_shim "$SH3" --finish
ul_t_check "revert that reports success but leaves content wrong: reverted-failed" ul_t_has "$OUT" "^result=reverted-failed pre_update_tag=$TAG mismatched=.*$DOC"
ul_t_check "reverted-failed: exit 1" ul_t_eq "$RC" 1
ul_t_check "reverted-failed: HEAD is not the pre-update tag's commit (no rewind)" ul_t_not test "$(cg rev-parse HEAD)" = "$H0"
ul_t_check "reverted-failed: HEAD is not the landed commit either (the revert commit stays)" ul_t_not test "$(cg rev-parse HEAD)" = "$S"
ul_t_check "reverted-failed: the working tree matches HEAD (nothing half-done)" tree_clean
ul_t_check "reverted-failed: the tag is kept" ul_t_eq "$(tags)" "$TAG"
ul_t_check "reverted-failed: nothing waits in .git/loom to be finished" state_gone
ul_t_check "reverted-failed: last-smoke.log exists" test -s "$(ST)/last-smoke.log"

# ---- the content check after a revert is fail-closed: a tree git cannot read is not a match
upd || ul_t_done
SH4=$(ul_t_shim_make)
cat > "$SH4/hook.sh" <<EOT
case " \$* " in
  *" revert --no-edit "*) "\$REAL" "\$@"; rc=\$?; : > "$SH4/reverted"; exit \$rc;;
  *" ls-tree "*) if [ -e "$SH4/reverted" ]; then echo "fatal: simulated" >&2; exit 128; fi;;
esac
EOT
sneak "$GUARD"
rm -f "$W_CUST/$GUARD"
ul_t_run_engine_shim "$SH4" --finish
ul_t_check "git unable to read the trees after the revert: reverted-failed, never reverted" ul_t_has "$OUT" '^result=reverted-failed '
ul_t_check "... every recorded path is reported as unverified" ul_t_has "$OUT" "mismatched=.*$DOC"
ul_t_check "... not claimed as a clean revert" ul_t_hasnt "$OUT" '^result=reverted '

# ---- the customer's git hooks never run inside the engine's revert (finish or undo)
install_hooks() {
  mkdir -p "$W_CUST/.git/hooks"
  cat > "$W_CUST/.git/hooks/pre-commit" <<'EOT'
#!/bin/sh
: > .git/ul-hook-ran
printf 'pre-commit touched this\n' >> .docs/guides/FIXTURE.md
git add .docs/guides/FIXTURE.md
EOT
  cat > "$W_CUST/.git/hooks/prepare-commit-msg" <<'EOT'
#!/bin/sh
: > .git/ul-hook-ran
EOT
  cat > "$W_CUST/.git/hooks/post-commit" <<'EOT'
#!/bin/sh
: > .git/ul-hook-ran
unset GIT_INDEX_FILE
printf 'post-commit tampered\n' >> .docs/guides/FIXTURE.md
git add .docs/guides/FIXTURE.md
git commit -q --amend --no-edit --no-verify
EOT
  chmod +x "$W_CUST/.git/hooks/pre-commit" "$W_CUST/.git/hooks/prepare-commit-msg" "$W_CUST/.git/hooks/post-commit"
  rm -f "$W_CUST/.git/ul-hook-ran"
}
upd || ul_t_done
install_hooks
sneak "$GUARD"
rm -f "$W_CUST/$GUARD"
fin
ul_t_check "customer hooks (pre-commit edits a file, post-commit amends): the automatic revert is unaffected" reverted_ok checks
ul_t_check "... no customer hook ran at all" test ! -e "$W_CUST/.git/ul-hook-ran"
ul_t_check "... the guide is exactly the pre-update one" ul_t_eq "$(cat "$W_CUST/$DOC")" "$(show $H0 $DOC)"
upd || ul_t_done
fin
install_hooks
und
ul_t_check "customer hooks do not touch --undo either: undone" ul_t_has "$OUT" '^result=undone '
ul_t_check "... no customer hook ran" test ! -e "$W_CUST/.git/ul-hook-ran"
ul_t_check "... every recorded path equals the pre-update tree" restored "$W_CUST" "$S" "$H0" "$REC"
rm -f "$W_CUST/.git/hooks/pre-commit" "$W_CUST/.git/hooks/prepare-commit-msg" "$W_CUST/.git/hooks/post-commit"

# ---- HEAD is re-read under the lock, right before the revert
# LOOM_TEST_PAUSE_BEFORE_REVERT=1 makes --finish touch state/.test-paused after a failed
# smoke and wait for state/.test-go. The case moves HEAD in between: no revert may follow.
upd || ul_t_done
sneak "$GUARD"
rm -f "$W_CUST/$GUARD"
( cd "$W_CUST" && LOOM_TEST_PAUSE_BEFORE_REVERT=1 LOOM_UPDATE_SH="$SH" "$SH" "$ENGINE" --finish </dev/null >"$BD/bg.out" 2>&1 ) &
BGP=$!
i=0
while [ ! -e "$(ST)/.test-paused" ] && [ "$i" -lt 100 ]; do sleep 0.2; i=$((i + 1)); done
ul_t_check "race: --finish reached the pause after the failed smoke" test -e "$(ST)/.test-paused"
ul_t_check "race: the lock is held by --finish while it works" test -s "$(ST)/stage.lock"
pl
ul_t_check "race: a --plan meanwhile is refused (the lock is live)" ul_t_has "$OUT" '^result=aborted reason=another update is staging'
ul_t_edit "$W_CUST" "notes-of-mine.txt" "committed during the smoke" "customer commits during the smoke" >/dev/null
HR=$(cg rev-parse HEAD)
: > "$(ST)/.test-go"
wait "$BGP"
OUT=$(cat "$BD/bg.out")
ul_t_check "race: HEAD moved during the smoke, so no revert: reverted-failed with reason=head-moved" ul_t_has "$OUT" '^result=reverted-failed .*reason=head-moved'
ul_t_check "race: nothing was reverted (HEAD is the customer's commit)" ul_t_eq "$(cg rev-parse HEAD)" "$HR"
ul_t_check "race: the customer's file is still there" test -f "$W_CUST/notes-of-mine.txt"
ul_t_check "race: the lock is released and the state is cleared" state_gone
ul_t_check "race: the tag is kept" ul_t_eq "$(tags)" "$TAG"
und
ul_t_check "race: --undo then reverses the update" ul_t_has "$OUT" '^result=undone '

# the lock is taken BEFORE staged and HEAD are read: a live lock refuses --finish
upd || ul_t_done
sleep 30 &
SP=$!
printf '%s\n' "$SP" > "$(ST)/stage.lock"
fin
kill "$SP" 2>/dev/null
ul_t_check "a live lock held by someone else: --finish is refused, nothing run" ul_t_has "$OUT" '^result=aborted reason=another update is staging'
ul_t_check "... the update is untouched" ul_t_eq "$(cat "$(ST)/staged")" "$S"
rm -f "$(ST)/stage.lock"

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
ul_t_check "moved-on: the smoke ran report-only against the current tree and passed" ul_t_has "$OUT" '^smoke=passed$'
ul_t_check "moved-on: the smoke wrote its log" test -s "$(ST)/last-smoke.log"
ul_t_check "moved-on: no revert was made (HEAD is the customer's commit)" ul_t_eq "$(subject HEAD)" "customer commits before finish"
und
ul_t_check "moved-on: --undo then reverses the update" ul_t_has "$OUT" '^result=undone '
ul_t_check "moved-on: the customer's own commit survives the undo" test -f "$W_CUST/notes-of-mine.txt"

# moved on AND the landed settings/hooks are broken: reported, never reverted automatically
upd || ul_t_done
cg rm -q -f "$GUARD" >/dev/null 2>&1
cg commit -q -m "customer deletes the guard script"
HM=$(cg rev-parse HEAD)
fin
ul_t_check "moved-on with a broken landed hook: still moved-on, exit 1" ul_t_has "$OUT" "^result=moved-on staged=$S head=$HM\$"
ul_t_check "moved-on with a broken landed hook: smoke=failed with its reason" ul_t_has "$OUT" '^smoke=failed reason=checks'
ul_t_check "moved-on with a broken landed hook: nothing was reverted" ul_t_eq "$(cg rev-parse HEAD)" "$HM"
ul_t_check "moved-on with a broken landed hook: the state is cleared" state_gone

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
