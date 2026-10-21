#!/bin/sh
# End-to-end journeys for /update-loom (package p0-e2e-floor): the unit case files
# prove each piece; this file proves the seams. Each scenario is one scripted customer
# journey in a fresh world (plan, digest, adapt-save, stage, land, finish, undo), asserted
# at every step. Every journey ends with the same two checks: the customer's working tree
# is clean, and the forbidden trees (web, features) are exactly what they were.
# POSIX sh. Prints PASS/FAIL lines; exit status is the overall result.
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib.sh"

ENG_SRC=$UL_T_ROOT/plugins/loom-maintenance/scripts/update-loom.sh
TAB=$(printf '\t')
NL='
'

kv() { printf '%s\n' "$OUT" | sed -n "s/^$1=//p" | head -1; }
dash_n() { [ -x /bin/dash ] || return 0; /bin/dash -n "$1"; }
cg() { git -C "$W_CUST" "$@"; }
ug() { git -C "$W_UP" "$@"; }
cc() { cg add -A >/dev/null 2>&1 && cg commit -q --allow-empty -m "$1"; }
ST() { ul_t_state; }
WT() { ul_t_wt; }
pl() { ul_t_run_engine --plan; }
asv() { ul_t_run_engine --adapt-save "$1" "$2" "$3"; }
mku() { ul_t_run_engine --mark-unresolved "$1" "$2"; }
stg() { ul_t_run_engine --stage "$1"; }
fin() { ul_t_run_engine --finish; }
und() { ul_t_run_engine --undo "$@"; }
UID_() { sed -n 's/^update_id=//p' "$(ST)/meta"; }
meta() { sed -n "s/^$1=//p" "$(ST)/meta" | head -1; }
tags() { cg tag -l 'loom/pre-update-*'; }
show() { cg show "$1:$2" 2>/dev/null; }
NC() { ul_t_notes_col "$1" "$2"; }
prow() { ul_t_plan_row "$1"; }
adapt_row() { awk -F'\t' -v p="$1" '$1 == p { print; exit }' "$(ST)/adapt.tsv" 2>/dev/null; }
tree_clean() { [ -z "$(git -C "${1:-$W_CUST}" status --porcelain)" ]; }
forb() { git -C "${1:-$W_CUST}" rev-parse HEAD:web HEAD:features 2>/dev/null | tr '\n' ' '; }
filehas() { grep -Fq -- "$2" "$1" 2>/dev/null; }
state_gone() { [ ! -e "$(ST)/staged" ] && [ ! -e "$(ST)/stage.info" ] && [ ! -d "$(WT)" ] && [ ! -e "$(ST)/stage.lock" ]; }
aborted() { [ "$RC" = 1 ] && ul_t_has "$OUT" '^result=aborted '; }
aborted_with() { aborted && ul_t_has "$OUT" "$1"; }
refused_with() { [ "$RC" = 1 ] && ul_t_has "$OUT" '^result=refused ' && ul_t_has "$OUT" "$1"; }
nw() { # new world (UL_T_STOCK=1 for a stock copy), with the governance stub, and the forbidden trees noted
  nw_d=$(ul_t_tmp) || return 1
  ul_t_world "$nw_d" || { echo "FAIL  fixture world could not be built"; fail=1; return 1; }
  ul_t_add_gov_stub "$W_CUST"
  FB0=$(forb)
}
# the two checks that close every journey
journey_end() { # LABEL
  ul_t_check "$1: the customer's working tree is clean" tree_clean
  ul_t_check "$1: the forbidden trees (web, features) never changed" ul_t_eq "$(forb)" "$FB0"
}

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
ALLNOTES="$LADDER $GUIDE $FOLLOW $HOOKS $SETASK"
KORI_BEFORE=$UL_T_ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.before
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
# every note applied (the stock copy has no held row): ids, then _unnoted
mkall() { # FILE
  : > "$1"
  for ma_n in $ALLNOTES _unnoted; do printf 'note:%s\tapply\n' "$ma_n" >> "$1"; done
}
# adapt-save the good settings body for the settings group
adapt_settings() {
  ul_t_settings_variant good "$BD/good.json" || return 1
  asv $SET "$BD/good.json" $HOOKS,$SETASK
}
# the ladder: the customer's file (the kori .before text) with the bare "3 = auth" lines
# removed and the "+3 on top" wording appended; the result is $BD/ladder.after.
# (The kori .after fixture is the maintainer's own fix and edits more lines than this
# note's pattern allows, so the adapter body is derived from the .before text.)
adapt_ladder() {
  awk '
    /^[[:space:]-]*3[[:space:]]*=[[:space:]]*it changes auth, payment, or customer-data logic/ { next }
    { print }
    END { print ""; print "Plus, on top of whichever reversibility line applies:"; print "+3 - it changes auth, payment, or customer-data logic" }
  ' "$(ul_t_adapt_body $AMD)" > "$BD/ladder.after" || return 1
  asv $AMD "$BD/ladder.after" $LADDER
}
# stage, then land the staged commit: sets S TAG; PASS line when it staged
stage_land() { # DECISIONS-FILE LABEL
  stg "$1"
  S=$(kv staged); TAG=$(kv tag)
  ul_t_check "$2: --stage staged" ul_t_eq "$(kv result)" staged
  ul_t_check "$2: the staged commit lands as a fast-forward" ul_t_land
}
# the .applied record paths at COMMIT
rec_paths() { git -C "$1" show "$2:$3" 2>/dev/null | awk -F'\t' 'NF >= 5 { print $1 }'; }
# 0 when every path of the record at COMMIT is, at HEAD of REPO, what it was at PRE
restored() { # REPO COMMIT PRE REC
  rs_ok=0
  for rs_p in $(rec_paths "$1" "$2" "$4") $LEDGER $4 .sdd-sync-ref; do
    rs_a=$(git -C "$1" ls-tree HEAD -- "$rs_p" 2>/dev/null)
    rs_b=$(git -C "$1" ls-tree "$3" -- "$rs_p" 2>/dev/null)
    if [ "$rs_a" != "$rs_b" ]; then rs_ok=1; echo "differs: $rs_p" >&2; fi
  done
  return $rs_ok
}
# a minimal upstream note, so a journey can plant its own check
up_note() { # ID CHECKBODY
  {
    printf -- '---\nid: %s\ntitle: E2E note %s\npurpose: A note planted by an end-to-end journey.\ntouches:\n  - .docs/guides/%s.md\n' "$1" "$1" "$1"
    printf 'adds: []\nrequires: []\nsafety: false\ndone-when:\n  - "the test passes"\ncheck: %s.check.sh\nproject-data: false\n---\n\nBody of %s.\n' "$1" "$1"
  } > "$W_UP/$NOTES/$1.md"
  printf '%s\n' "$2" > "$W_UP/$NOTES/$1.check.sh"
  ul_t_commit "$W_UP" "note $1" >/dev/null
}

# =================================================================== 0. syntax
ul_t_check "case file passes sh -n" sh -n "$here/cases-e2e.sh"
ul_t_check "case file passes dash -n" dash_n "$here/cases-e2e.sh"
ul_t_check "engine passes sh -n" sh -n "$ENG_SRC"
ul_t_check "engine passes dash -n" dash_n "$ENG_SRC"
NEVER="reset --hard|git push|branch -D|worktree add -b|tag -d"
ul_t_check "engine never resets hard, pushes, deletes a branch or a tag" ul_t_not grep -Eq "$NEVER" "$ENG_SRC"
ul_t_check "the kori ladder fixture exists" test -f "$KORI_BEFORE"

# ===================================================== 1. STOCK COPY, full loop
UL_T_STOCK=1
nw || ul_t_done
UL_T_STOCK=0
H0=$(cg rev-parse HEAD)
ul_t_run_engine --status
ul_t_check "stock: --status channel=template" ul_t_eq "$(kv channel)" template
ul_t_check "stock: --status base is commit 1" ul_t_eq "$(kv base)" "$W_BASE"
ul_t_check "stock: --status tree clean, no ledger" ul_t_eq "$(kv clean):$(kv ledger_rows)" "yes:0"
ul_t_run_engine --detect-base
ul_t_check "stock: --detect-base recorded, commit 1" ul_t_eq "$(printf '%s\n' "$OUT" | sed -n 1p)" "recorded $W_BASE"
pl
ul_t_check "stock: planned" ul_t_eq "$(kv result)" planned
ul_t_check "stock: every note is untouched=yes" ul_t_eq "$(awk -F'\t' '$8 != "yes"' "$(ST)/notes.tsv" | wc -l | tr -d ' '):$(awk 'END { print NR }' "$(ST)/notes.tsv")" "0:5"
ul_t_check "stock: no hold row in the plan" ul_t_eq "$(awk -F'\t' '$3 == "hold"' "$(ST)/plan.tsv" | wc -l | tr -d ' ')" 0
ul_t_check "stock: the overlap groups are present" ul_t_eq "$(awk 'END { print NR }' "$(ST)/groups.tsv")" 4
ul_t_check "stock: settings.json is a plain take" ul_t_eq "$(prow $SET | cut -f1,2)" "take${TAB}apply"
UID0=$(UID_); REC=$APPLIED/$UID0.applied
mkall "$BD/stock.tsv"
stage_land "$BD/stock.tsv" "stock"
fin
ul_t_check "stock: finish applied" ul_t_has "$OUT" "^result=applied commit=$S tag=$TAG update_id=$UID0 held=none\$"
ul_t_check "stock: the update's content is live" ul_t_has "$(cat "$W_CUST/$DOC")" 'Run /update-loom to take improvements.'
ul_t_check "stock: the guard script and the follow-up guide were added" test -f "$W_CUST/$GUARD" -a -f "$W_CUST/$DOC2"
ul_t_check "stock: five ledger rows" ul_t_eq "$(show HEAD $LEDGER | awk 'END { print NR }')" 5
pl
ul_t_check "stock: a second plan is up to date" ul_t_eq "$(kv uptodate)" yes
CL=$(ul_t_clone_fresh) || ul_t_done
ul_t_run_in "$CL" --undo
ul_t_check "stock: --undo from a fresh clone undid the update" ul_t_has "$OUT" "^result=undone commit=[0-9a-f]\{40\} undid=$S update_id=$UID0\$"
ul_t_check "stock: undo restored every recorded path" restored "$CL" "$S" "$H0" "$REC"
ul_t_check "stock: undo restored commit 1's content of the guide" ul_t_eq "$(cat "$CL/$DOC")" "$(show $H0 $DOC)"
ul_t_check "stock: undo removed the added files" test ! -e "$CL/$GUARD" -a ! -e "$CL/$DOC2" -a ! -e "$CL/$LEDGER"
ul_t_check "stock: undo left the clone's tree clean and the forbidden trees alone" ul_t_eq "$(tree_clean "$CL" && echo clean):$(forb "$CL")" "clean:$FB0"
journey_end "stock"

# =============================================== 2. CUSTOMISED COPY, full loop
nw || ul_t_done
H0=$(cg rev-parse HEAD)
pl
ul_t_check "custom: planned" ul_t_eq "$(kv result)" planned
UID0=$(UID_); REC=$APPLIED/$UID0.applied
# the digest: the question set the skill would ask, read from the columns that drive it
HELD=$(awk -F'\t' '$3 == "hold" { print $1 }' "$(ST)/plan.tsv" | LC_ALL=C sort | tr '\n' ' ')
ul_t_check "custom: exactly two held rows need a decision (settings.json, amendments.md)" ul_t_eq "$HELD" "$SET $AMD "
ul_t_check "custom: the settings row is one group of two safety-linked notes" ul_t_eq "$(adapt_row $SET | cut -f2)" "$HOOKS,$SETASK"
ul_t_check "custom: ... which groups.tsv shows as one group" ul_t_has "$(cat "$(ST)/groups.tsv")" "^g1${TAB}$HOOKS,$SETASK\$"
ul_t_check "custom: the hooks note is the safety note of that group" ul_t_eq "$(NC $HOOKS 3)$(NC $SETASK 3)" truefalse
ul_t_check "custom: the ladder note is project-data on a two-way row (Adapt or Leave)" ul_t_eq "$(NC $LADDER 9):$(prow $AMD | cut -f1,2)" "true:two-way${TAB}hold"
ul_t_check "custom: the guidance note is listed, not asked (merged-clean, applied, customer-touched)" ul_t_eq "$(prow $DOC | cut -f1,2):$(NC $GUIDE 8)" "merged-clean${TAB}apply:no"
ul_t_check "custom: the follow-up note is listed, not asked (untouched, an add)" ul_t_eq "$(prow $DOC2 | cut -f1,2):$(NC $FOLLOW 8)" "add${TAB}apply:yes"
ul_t_check "custom: every note is offered" ul_t_eq "$(awk -F'\t' '$11 == "a"' "$(ST)/notes.tsv" | wc -l | tr -d ' ')" 5
# the adapter's two bodies
ul_t_check "custom: the good settings body is saved" ul_t_has "$(adapt_settings; echo "$OUT")" "^saved=$SET notes=$HOOKS,$SETASK rules="
ul_t_check "custom: the ladder body is saved" ul_t_has "$(adapt_ladder; echo "$OUT")" "^saved=$AMD notes=$LADDER rules=R4"
mkdec "$BD/d.tsv" "$AMD${TAB}adapted"
stage_land "$BD/d.tsv" "custom"
fin
ul_t_check "custom: finish applied with no held note" ul_t_has "$OUT" "^result=applied commit=$S tag=$TAG update_id=$UID0 held=none\$"
live=$(cat "$W_CUST/$SET")
ul_t_check "custom: live settings.json is valid JSON" sh "$W_CUST/plugins/loom-maintenance/scripts/json-valid.sh" "$W_CUST/$SET"
ul_t_check "custom: live settings has the guard hook" ul_t_has "$live" 'guard-dangerous-commands.sh'
ul_t_check "custom: live settings has the restored ask entry" ul_t_has "$live" 'Bash(git restore:\*)'
ul_t_check "custom: live settings keeps the adopter hook" ul_t_has "$live" 'guard-prod-db.sh'
ul_t_check "custom: live settings keeps enabledPlugins" ul_t_has "$live" 'fixture@local'
ul_t_check "custom: live settings keeps the customer's own deny entry" ul_t_has "$live" 'Bash(rm -rf:\*)'
ul_t_check "custom: amendments.md equals the saved ladder body" ul_t_eq "$(cmp "$W_CUST/$AMD" "$BD/ladder.after" && echo same)" same
ul_t_check "custom: ... which differs from the .before text" ul_t_not cmp -s "$W_CUST/$AMD" "$KORI_BEFORE"
ul_t_check "custom: FIXTURE.md has the customer's appendix and upstream's sentence" ul_t_eq "$(grep -c 'extended by the customer' "$W_CUST/$DOC"):$(grep -c 'Run /update-loom to take improvements.' "$W_CUST/$DOC")" "1:1"
ul_t_check "custom: FIXTURE-2.md and the guard script were added" test -f "$W_CUST/$DOC2" -a -f "$W_CUST/$GUARD"
ul_t_check "custom: the ledger has five applied rows" ul_t_eq "$(show HEAD $LEDGER | awk -F'\t' '$2 == "applied"' | wc -l | tr -d ' ')" 5
ul_t_check "custom: the applied record is committed" ul_t_has "$(show HEAD $REC)" "^update_id=$UID0\$"
CL=$(ul_t_clone_fresh) || ul_t_done
ul_t_run_in "$CL" --undo
ul_t_check "custom: --undo from a fresh clone undid the update" ul_t_has "$OUT" "^result=undone commit=[0-9a-f]\{40\} undid=$S update_id=$UID0\$"
ul_t_check "custom: undo restored every recorded path" restored "$CL" "$S" "$H0" "$REC"
ul_t_check "custom: amendments.md is back to the .before content" ul_t_eq "$(cmp "$CL/$AMD" "$KORI_BEFORE" && echo same)" same
ul_t_check "custom: settings.json is the customer's original" ul_t_eq "$(cat "$CL/$SET")" "$(show $H0 $SET)"
ul_t_check "custom: the guide is the customer's original" ul_t_eq "$(cat "$CL/$DOC")" "$(show $H0 $DOC)"
ul_t_check "custom: undo left the clone's tree clean" tree_clean "$CL"
journey_end "custom"

# ============================== 3. SAFETY-UNRESOLVED, STOP (hold on settings.json)
nw || ul_t_done
H0=$(cg rev-parse HEAD)
pl
ul_t_settings_variant no-adopter "$BD/noadopter.json"
asv $SET "$BD/noadopter.json" $HOOKS,$SETASK
ul_t_check "stop: a body that drops the adopter hook is refused (R1)" refused_with 'reason=invariant rule=R1'
mku $SET $HOOKS
ul_t_check "stop: --mark-unresolved accepted for the safety note" ul_t_has "$OUT" "^unresolved=$SET lost=[0-9][0-9]*\$"
ul_t_check "stop: the lost diff names the adopter's hook script" filehas "$(ST)/unresolved/$SET.lost.diff" 'scripts/hooks/guard-prod-db.sh'
mkdec "$BD/d.tsv" "$SET${TAB}hold"
stg "$BD/d.tsv"
ul_t_check "stop: --stage aborts with safety-unresolved" aborted_with 'safety-unresolved'
ul_t_check "stop: ... unchanged=yes" ul_t_has "$OUT" ' unchanged=yes$'
ul_t_check "stop: nothing staged, no worktree, no tag" ul_t_eq "$([ -e "$(ST)/staged" ] && echo staged)$([ -d "$(WT)" ] && echo wt)$(tags)" ""
ul_t_check "stop: HEAD unchanged" ul_t_eq "$(cg rev-parse HEAD)" "$H0"
journey_end "stop"

# ============================ 4. SAFETY-UNRESOLVED, REPLACE (take-theirs informed)
nw || ul_t_done
H0=$(cg rev-parse HEAD)
pl
UID0=$(UID_); REC=$APPLIED/$UID0.applied
asv $SET "$BD/noadopter.json" $HOOKS,$SETASK
mku $SET $HOOKS
mkdec "$BD/d.tsv" "$SET${TAB}take-theirs${TAB}informed=yes"
stage_land "$BD/d.tsv" "replace"
ul_t_check "replace: the customer's settings file is kept under mine/<id>/" ul_t_eq "$(cat "$(ST)/mine/$UID0/$SET")" "$(show $H0 $SET)"
fin
ul_t_check "replace: finish applied, with the tag in the report" ul_t_has "$OUT" "^result=applied commit=$S tag=$TAG update_id=$UID0 "
ul_t_check "replace: the live settings lack the adopter hook (the documented loss)" ul_t_hasnt "$(cat "$W_CUST/$SET")" 'guard-prod-db.sh'
ul_t_check "replace: ... and carry upstream's guard hook" ul_t_has "$(cat "$W_CUST/$SET")" 'guard-dangerous-commands.sh'
ul_t_check "replace: the backup survives finish" test -f "$(ST)/mine/$UID0/$SET"
und
ul_t_check "replace: --undo undid it" ul_t_has "$OUT" '^result=undone '
ul_t_check "replace: the adopter hook is back" ul_t_has "$(cat "$W_CUST/$SET")" 'guard-prod-db.sh'
ul_t_check "replace: settings.json is the customer's original" ul_t_eq "$(cat "$W_CUST/$SET")" "$(show $H0 $SET)"
ul_t_check "replace: the backup is never deleted" test -f "$(ST)/mine/$UID0/$SET"
journey_end "replace"

# =========================================== 5. HOLD-BACK CASCADE, full flow
nw || ul_t_done
sed 's/Run \/update-loom to take improvements\./Never-present sentence./' "$W_UP/$NOTES/$GUIDE.check.sh" > "$BD/chk"
cp "$BD/chk" "$W_UP/$NOTES/$GUIDE.check.sh"
ul_t_commit "$W_UP" "guidance check can never pass" >/dev/null
H0=$(cg rev-parse HEAD)
pl
adapt_settings >/dev/null
mkdec "$BD/d.tsv"
stage_land "$BD/d.tsv" "cascade"
ul_t_check "cascade: staged reports both held notes" ul_t_eq "$(printf '%s\n' "$OUT" | grep -c '^held=')" 2
fin
ul_t_check "cascade: finish applied" ul_t_has "$OUT" '^result=applied '
ul_t_check "cascade: finish reports the guidance note held" ul_t_has "$OUT" " held=.*$GUIDE"
ul_t_check "cascade: finish reports the follow-up note held" ul_t_has "$OUT" " held=.*$FOLLOW"
ul_t_check "cascade: the guide is untouched, the follow-up never written" ul_t_eq "$(cat "$W_CUST/$DOC"):$(test -e "$W_CUST/$DOC2" && echo has)" "$(show $H0 $DOC):"
ul_t_check "cascade: the ledger holds both (and the ladder, held by decision)" ul_t_eq "$(show HEAD $LEDGER | awk -F'\t' '$2 == "held" { print $1 }' | LC_ALL=C sort | tr '\n' ' ')" "$LADDER $FOLLOW $GUIDE "
pl
ul_t_check "cascade: a later plan succeeds" ul_t_eq "$(kv result)" planned
ul_t_check "cascade: ... offers the guidance note again via ledger rule (c)" ul_t_eq "$(NC $GUIDE 11)" c
ul_t_check "cascade: ... and the follow-up note via rule (c), blocked by the guidance" ul_t_eq "$(NC $FOLLOW 11):$(NC $FOLLOW 5)" "c:$GUIDE"
journey_end "cascade"

# ============================================ 6. HANDOVER WITH TAG and WITHOUT
# with the pre-update tag: base recovered, settings is a three-way posture row
nw || ul_t_done
cg tag loom/pre-update-20260101-000000 HEAD
printf '%s\n' "$W_HEAD" > "$W_CUST/.sdd-sync-ref"; cc "the old updater advanced the pointer"
H0=$(cg rev-parse HEAD)
pl
UID0=$(UID_)
ul_t_check "handover+tag: base_rung=handover, base is commit 1" ul_t_eq "$(meta base_rung):$(meta base)" "handover:$W_BASE"
ul_t_check "handover+tag: settings.json is a posture row (three-way)" ul_t_eq "$(prow $SET | cut -f1,2)" "posture${TAB}hold"
ul_t_check "handover+tag: adapt-save accepts the good body" ul_t_has "$(adapt_settings; echo "$OUT")" "^saved=$SET "
mkdec "$BD/d.tsv"
stage_land "$BD/d.tsv" "handover+tag"
fin
ul_t_check "handover+tag: finish applied" ul_t_has "$OUT" '^result=applied '
ul_t_check "handover+tag: the guard hook is live beside the adopter hook" ul_t_eq "$(grep -c 'guard-dangerous-commands.sh' "$W_CUST/$SET"):$(grep -c 'guard-prod-db.sh' "$W_CUST/$SET")" "1:1"
journey_end "handover+tag"
# without the tag: the base is the recorded stamp, so the rows are two-way
nw || ul_t_done
printf '%s\n' "$W_HEAD" > "$W_CUST/.sdd-sync-ref"
mkdir -p "$W_CUST/.claude/hooks" && git -C "$W_UP" show "$W_HEAD:$GUARD" > "$W_CUST/$GUARD"
cc "the old updater advanced the pointer and wrote the guard script, no tag"
H0=$(cg rev-parse HEAD)
pl
UID0=$(UID_)
ul_t_check "handover no tag: base_rung=recorded, base is commit 2" ul_t_eq "$(meta base_rung):$(meta base)" "recorded:$W_HEAD"
ul_t_check "handover no tag: settings.json is a two-way row" ul_t_eq "$(prow $SET | cut -f1,2)" "two-way${TAB}hold"
ul_t_check "handover no tag: adapt-save accepts the good body" ul_t_has "$(adapt_settings; echo "$OUT")" "^saved=$SET "
mkdec "$BD/d.tsv" "$DOC${TAB}hold" "$DOC2${TAB}hold"
stage_land "$BD/d.tsv" "handover no tag"
fin
ul_t_check "handover no tag: finish applied" ul_t_has "$OUT" '^result=applied '
ul_t_check "handover no tag: the guard hook is live beside the adopter hook" ul_t_eq "$(grep -c 'guard-dangerous-commands.sh' "$W_CUST/$SET"):$(grep -c 'guard-prod-db.sh' "$W_CUST/$SET")" "1:1"
journey_end "handover no tag"

# ================================================= 7. AMBIGUOUS CHANNEL, then adopted
nw || ul_t_done
mkdir -p "$W_CUST/.claude/rules" && echo x > "$W_CUST/.claude/rules/logicloom-governance.md"
printf '{"adopt":"inserted"}\n' > "$W_CUST/.claude/.logicloom-adopt-settings.json"
cc "an adopted-looking tree with no receipt"
ul_t_edit "$W_UP" CLAUDE.md '# upstream claude' "up claude" >/dev/null
pl
ul_t_check "ambiguous: --plan refuses and names --channel" ul_t_has "$OUT" '^result=aborted reason=.*--channel.* unchanged=yes$'
ul_t_check "ambiguous: nothing was planned" ul_t_not test -f "$(ST)/plan.tsv"
ul_t_run_engine --channel adopted --plan
ul_t_check "ambiguous + --channel adopted: planned as adopted" ul_t_eq "$(kv result):$(meta channel)" "planned:adopted"
ul_t_check "adopted: CLAUDE.md is excluded (adopt-excluded)" ul_t_eq "$(prow CLAUDE.md)" "excluded${TAB}skip${TAB}adopt-excluded"
ul_t_check "adopted: settings.json is a posture row" ul_t_eq "$(prow $SET | cut -f1,2)" "posture${TAB}hold"
ul_t_check "adopted: its base side is the recorded adopt-settings insertion" ul_t_eq "$(cat "$(ST)/adapt/base/$SET"):$(meta base_side)" '{"adopt":"inserted"}:adopt-settings'
ul_t_check "adopted: the base side blob is the adopt-settings file's" ul_t_eq "$(adapt_row $SET | cut -f3)" "$(cg rev-parse HEAD:.claude/.logicloom-adopt-settings.json)"
journey_end "ambiguous"

# =============================================== 8. A CHECK THAT WRITES
nw || ul_t_done
H0=$(cg rev-parse HEAD)
up_note wr-junk "#!/bin/sh${NL}echo x > \"\$REPO_ROOT/junk\"${NL}exit 0"
pl
ul_t_check "check writes: --plan aborts, unchanged=yes" ul_t_has "$OUT" '^result=aborted reason=check wr-junk wrote junk (check-wrote=junk) unchanged=yes$'
ul_t_check "check writes: exit 1" ul_t_eq "$RC" 1
ul_t_check "check writes: nothing in state beyond the log (no plan, notes, meta, groups)" ul_t_eq "$(for f in plan.tsv notes.tsv meta groups.tsv adapt.tsv staged; do [ -e "$(ST)/$f" ] && echo "$f"; done)" ""
ul_t_check "check writes: the live tree has no junk, HEAD unchanged" ul_t_eq "$(test -e "$W_CUST/junk" && echo junk):$(cg rev-parse HEAD)" ":$H0"
journey_end "check-wrote"

# =================================================== 9. SHALLOW CLONE refusal
nw || ul_t_done
gd=$(cg rev-parse --absolute-git-dir)
printf '%s\n' "$W_BASE" > "$gd/shallow"
pl
ul_t_check "shallow: --plan refuses and says unshallow" ul_t_has "$OUT" '^result=aborted reason=.*git fetch --unshallow first.* unchanged=yes$'
ul_t_check "shallow: nothing was planned" ul_t_not test -f "$(ST)/plan.tsv"
rm -f "$gd/shallow"
pl
ul_t_check "shallow: once unshallowed the plan runs" ul_t_eq "$(kv result)" planned
journey_end "shallow"

# =============================================== 10. KILLED --stage, heal, stage
nw || ul_t_done
H0=$(cg rev-parse HEAD)
pl
adapt_settings >/dev/null
mkdec "$BD/d.tsv"
( cd "$W_CUST" && LOOM_TEST_SLEEP_BEFORE_COMMIT=1 LOOM_UPDATE_SH="$SH" "$SH" "$ENGINE" --stage "$BD/d.tsv" </dev/null >"$BD/bg.out" 2>&1 ) &
BGP=$!
i=0
while [ ! -e "$(ST)/.test-sleeping" ] && [ "$i" -lt 100 ]; do sleep 0.2; i=$((i + 1)); done
ul_t_check "killed: the stage reached the planted sleep" test -e "$(ST)/.test-sleeping"
LP=$(sed -n '1p' "$(ST)/stage.lock" 2>/dev/null)
pkill -P "$LP" 2>/dev/null
kill -9 "$LP" 2>/dev/null
wait "$BGP" 2>/dev/null
sleep 1
ul_t_check "killed: a worktree and a tag were left behind" ul_t_eq "$([ -d "$(WT)" ] && echo wt):$([ -n "$(tags)" ] && echo tag)" "wt:tag"
ul_t_run_engine --status
ul_t_check "killed: --status heals" ul_t_has "$OUT" '^healed=yes'
ul_t_check "killed: the worktree and lock are gone, nothing staged" ul_t_eq "$([ -d "$(WT)" ] && echo wt)$([ -e "$(ST)/stage.lock" ] && echo lock)$([ -e "$(ST)/staged" ] && echo staged)" ""
rm -f "$(ST)/.test-sleeping"
stage_land "$BD/d.tsv" "killed"
fin
ul_t_check "killed: the retried update finishes applied" ul_t_has "$OUT" '^result=applied '
ul_t_check "killed: HEAD is above the pre-update commit" ul_t_eq "$(cg rev-parse HEAD^)" "$H0"
journey_end "killed"

# ================================================== 11. DECLINE SNOOZE
nw || ul_t_done
pl
adapt_settings >/dev/null
UID0=$(UID_)
mkdec "$BD/d.tsv" "note:$GUIDE${TAB}decline" "note:$FOLLOW${TAB}decline"
stage_land "$BD/d.tsv" "snooze"
fin
ul_t_check "snooze: finish applied" ul_t_has "$OUT" '^result=applied '
ul_t_check "snooze: the ledger records the guidance note as declined" ul_t_eq "$(show HEAD $LEDGER | awk -F'\t' -v i=$GUIDE '$1 == i { print $2 }')" declined
pl
ul_t_check "snooze: a later plan lists the guidance note as snoozed" ul_t_eq "$(NC $GUIDE 12):$(NC $GUIDE 6)" "yes:yes"
ul_t_check "snooze: ... and the follow-up is blocked by it" ul_t_eq "$(NC $FOLLOW 5)" $GUIDE
printf '\nA later edit to the note text.\n' >> "$W_UP/$NOTES/$GUIDE.md"
ul_t_commit "$W_UP" "edit the guidance note" >/dev/null
pl
ul_t_check "snooze: a changed note is offered again, unsnoozed" ul_t_eq "$(NC $GUIDE 12):$(NC $GUIDE 6)" "no:yes"
ug reset -q --hard HEAD~1
pl
ul_t_check "snooze: (note back to the declined text) snoozed again" ul_t_eq "$(NC $GUIDE 12)" yes
ul_t_run_engine --plan --revisit
ul_t_check "snooze: --revisit unsnoozes it" ul_t_eq "$(NC $GUIDE 12):$(meta revisit)" "no:yes"
journey_end "snooze"

# ================================== 12. UNKNOWN DECISION and STALE PLAN at stage
nw || ul_t_done
H0=$(cg rev-parse HEAD)
pl
adapt_settings >/dev/null
mkdec "$BD/d.tsv" "$SET${TAB}take"
stg "$BD/d.tsv"
ul_t_check "unknown decision: aborted, names it, unchanged" aborted_with "take.* unchanged=yes"
ul_t_check "unknown decision: nothing left behind" ul_t_eq "$([ -e "$(ST)/staged" ] && echo staged)$([ -d "$(WT)" ] && echo wt)$(tags)" ""
mkdec "$BD/d.tsv"
cg commit -q --allow-empty -m "a commit after the plan"
stg "$BD/d.tsv"
ul_t_check "stale plan: aborted, says stale, unchanged" aborted_with "stale.* unchanged=yes"
ul_t_check "stale plan: nothing left behind" ul_t_eq "$([ -e "$(ST)/staged" ] && echo staged)$([ -d "$(WT)" ] && echo wt)$(tags)" ""
pl
adapt_settings >/dev/null
stage_land "$BD/d.tsv" "stale recovery"
fin
ul_t_check "stale plan: re-plan, stage, finish applies" ul_t_has "$OUT" '^result=applied '
journey_end "unknown+stale"

ul_t_done
