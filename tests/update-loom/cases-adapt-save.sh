#!/bin/sh
# Cases for --adapt-save and --mark-unresolved (package p0-engine-adapt-save): the
# deterministic gate between the read-only adapter and the tree. Every refusal in
# order, each of R1-R5 through the subcommand (not only through the invariants
# script), line-ending preservation, and the safety-unresolved state.
# POSIX sh. Prints PASS/FAIL lines; exit status is the overall result.
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib.sh"

ENG_SRC=$UL_T_ROOT/plugins/loom-maintenance/scripts/update-loom.sh
TAB=$(printf '\t')
CR=$(printf '\r')

kv() { printf '%s\n' "$OUT" | sed -n "s/^$1=//p" | head -1; }
dash_n() { [ -x /bin/dash ] || return 0; /bin/dash -n "$1"; }
cg() { git -C "$W_CUST" "$@"; }
cc() { cg add -A >/dev/null 2>&1 && cg commit -q --allow-empty -m "$1"; }
ug() { git -C "$W_UP" "$@"; }
nw() {
  nw_d=$(ul_t_tmp) || return 1
  ul_t_world "$nw_d" || { echo "FAIL  fixture world could not be built"; fail=1; return 1; }
}
pl() { ul_t_run_engine --plan; }
ST() { ul_t_state; }
prow() { ul_t_plan_row "$1"; }
filehas() { grep -Fq -- "$2" "$1" 2>/dev/null; }
adapt_row() { awk -F'\t' -v p="$1" '$1 == p { print; exit }' "$(ST)/adapt.tsv" 2>/dev/null; }
tsv_n() { [ -f "$1" ] || { echo 0; return 0; }; awk -F'\t' -v p="$2" '$1 == p { n++ } END { print n + 0 }' "$1"; }
adapted_n() { tsv_n "$(ST)/adapted.tsv" "$1"; }
unres_n() { tsv_n "$(ST)/unresolved.tsv" "$1"; }
asv() { ul_t_run_engine --adapt-save "$1" "$2" "$3"; }          # PATH BODY IDS
mku() { ul_t_run_engine --mark-unresolved "$1" "$2"; }          # PATH NOTE
refused() { [ "$RC" = 1 ] && ul_t_has "$OUT" '^result=refused reason='; }
refused_with() { refused && ul_t_has "$OUT" "$1"; }
first_line() { printf '%s\n' "$OUT" | sed -n '1p'; }
merged_is() { cmp -s "$(ST)/merged/$1" "$2"; }
no_merged() { [ ! -e "$(ST)/merged/$1" ]; }
refs() { cg for-each-ref; }

SET=.claude/settings.json
AMD=.logic-loom/memory/amendments.md
DOC=.docs/guides/FIXTURE.md
DOC2=.docs/guides/FIXTURE-2.md
HOOKS=hooks-guard-dangerous
SETASK=settings-ask-restore
GUIDE=fixture-doc-guidance
LADDER=amendments-ladder-plus-three
NOTES=plugins/loom-maintenance/updates/7.0.0
SENT='Run /update-loom to take improvements.'
SETIDS=$HOOKS,$SETASK

BD=$(ul_t_tmp)

# =================================================================== 0. syntax
ul_t_check "case file passes sh -n" sh -n "$here/cases-adapt-save.sh"
ul_t_check "case file passes dash -n" dash_n "$here/cases-adapt-save.sh"
ul_t_check "lib.sh passes sh -n" sh -n "$here/lib.sh"
ul_t_check "lib.sh passes dash -n" dash_n "$here/lib.sh"
ul_t_check "engine passes sh -n" sh -n "$ENG_SRC"
ul_t_check "engine passes dash -n" dash_n "$ENG_SRC"
ul_t_check "engine has no bash-isms in the adapt-save code" ul_t_not grep -Eq '^[[:space:]]*(local|function)[[:space:]]|\[\[|<<<' "$ENG_SRC"

# ============================================================ 1. refusals, in order
nw || ul_t_done
ul_t_run_engine --help
ul_t_check "help: lists --adapt-save" ul_t_has "$OUT" '--adapt-save <path>'
ul_t_check "help: --adapt-save is not marked unbuilt" ul_t_hasnt "$OUT" 'adapt-save.*not built'
ul_t_check "help: lists --mark-unresolved" ul_t_has "$OUT" '--mark-unresolved <path>'
ul_t_check "help: --mark-unresolved is not marked unbuilt" ul_t_hasnt "$OUT" 'mark-unresolved.*not built'
printf 'x\n' > "$BD/x.txt"
asv $SET "$BD/x.txt" $SETIDS
ul_t_check "no plan: refused" refused_with 'reason=no plan'
ul_t_check "no plan: exit 1" ul_t_eq "$RC" 1
mku $SET $HOOKS
ul_t_check "no plan: --mark-unresolved is refused too" refused_with 'reason=no plan'

pl
REFS0=$(refs)
ul_t_check "default: planned" ul_t_eq "$(kv result)" planned
ul_t_check "default: settings.json is a posture/hold row" ul_t_eq "$(prow $SET | cut -f1,2)" "posture${TAB}hold"
ul_t_check "default: settings.json lists both notes" ul_t_eq "$(adapt_row $SET | cut -f2)" "$SETIDS"
ul_t_check "helper: ul_t_adapt_body names the mine side" test -f "$(ul_t_adapt_body $SET)"

ul_t_settings_variant good "$BD/good.json"
ul_t_check "variant: the good body is valid JSON" sh "$(ST)/tools/json-valid.sh" "$BD/good.json"
: > "$BD/empty.txt"
asv $SET "$BD/empty.txt" $SETIDS
ul_t_check "empty body: refused" refused_with 'reason=.*empty'
asv $SET "$BD/nothing-here.json" $SETIDS
ul_t_check "missing body: refused" refused_with 'reason=.*body'
asv .docs/guides/FIXTURE-2.md "$BD/good.json" $GUIDE
ul_t_check "path with no adapt.tsv row: refused" refused_with 'reason=.*FIXTURE-2.md'
printf '%s\t-\t-\t-\t-\n' web/app.js >> "$(ST)/adapt.tsv"
asv web/app.js "$BD/good.json" -
ul_t_check "forbidden path (row injected): refused as forbidden" refused_with 'reason=.*forbidden'
printf '%s\t-\t-\t-\t-\n' .logic-loom/memory/update-ledger.tsv >> "$(ST)/adapt.tsv"
asv .logic-loom/memory/update-ledger.tsv "$BD/good.json" -
ul_t_check "the ledger is forbidden too" refused_with 'reason=.*forbidden'
asv $SET "$BD/good.json" "$GUIDE"
ul_t_check "an id not approved for the path (fixture-doc-guidance): refused" refused_with "reason=.*$GUIDE"
asv $SET "$BD/good.json" nope-not-a-note
ul_t_check "an unknown id: refused" refused_with 'reason=.*nope-not-a-note'
asv $SET "$BD/good.json" "$HOOKS,nope"
ul_t_check "one good id and one unknown id: refused" refused_with 'reason=.*nope'
asv $SET "$BD/good.json" ""
ul_t_check "empty note-ids: refused" refused_with 'reason=.*note'
asv $SET "$BD/good.json" -
ul_t_check "note-ids - on a row that lists notes: refused" refused_with 'reason=.*note'
ul_t_run_engine --adapt-save $SET
ul_t_check "wrong argument count is a usage error (exit 2)" ul_t_eq "$RC" 2
ul_t_check "... and prints one error line" ul_t_has "$(first_line)" '^error '
ul_t_check "refusals so far saved nothing under merged/" no_merged $SET
ul_t_check "refusals so far wrote no adapted.tsv row" ul_t_eq "$(adapted_n $SET)" 0

# json first
ul_t_settings_variant invalid "$BD/invalid.json"
asv $SET "$BD/invalid.json" $SETIDS
ul_t_check "invalid JSON: refused" refused
ul_t_check "... by json-valid, naming json" ul_t_has "$OUT" 'reason=.*json'
ul_t_check "... before the invariants ran (no rule=)" ul_t_hasnt "$OUT" 'rule='
ul_t_check "invalid JSON: nothing saved" no_merged $SET
cp "$(ST)/tools/json-valid.sh" "$BD/json-valid.sh.bak"
rm -f "$(ST)/tools/json-valid.sh"
asv $SET "$BD/good.json" $SETIDS
ul_t_check "json-valid.sh not saved at plan time: refused outright" refused_with 'reason=.*json-valid'
cp "$BD/json-valid.sh.bak" "$(ST)/tools/json-valid.sh"

# R1-R5 through the subcommand
ul_t_settings_variant no-adopter "$BD/no-adopter.json"
asv $SET "$BD/no-adopter.json" $SETIDS
ul_t_check "dropping the adopter hook: refused with rule=R1" refused_with 'reason=invariant rule=R1 detail='
ul_t_check "R1: nothing saved" no_merged $SET
ul_t_settings_variant no-rmrf "$BD/no-rmrf.json"
asv $SET "$BD/no-rmrf.json" $SETIDS
ul_t_check "dropping Bash(rm -rf:*) from deny: rule=R2" refused_with 'reason=invariant rule=R2 detail='
ul_t_settings_variant extra-allow "$BD/extra-allow.json"
asv $SET "$BD/extra-allow.json" $SETIDS
ul_t_check "an allow entry absent from both sides: rule=R2" refused_with 'reason=invariant rule=R2 detail='
ul_t_settings_variant no-plugins "$BD/no-plugins.json"
asv $SET "$BD/no-plugins.json" $SETIDS
ul_t_check "removing enabledPlugins: rule=R5" refused_with 'reason=invariant rule=R5 detail='
ul_t_check "R5: nothing saved" no_merged $SET
ul_t_check "R-refusals wrote no adapted.tsv row" ul_t_eq "$(adapted_n $SET)" 0

# the good save
asv $SET "$BD/good.json" $SETIDS
ul_t_check "good settings.json: exits 0" ul_t_eq "$RC" 0
ul_t_check "good settings.json: one saved line, in the contract shape" ul_t_eq "$OUT" "saved=$SET notes=$SETIDS rules=R1,R2,R5"
ul_t_check "good settings.json: byte-identical body under merged/" merged_is $SET "$BD/good.json"
ul_t_check "good settings.json: adapted.tsv has the row" ul_t_eq "$(awk -F'\t' -v p=$SET '$1 == p' "$(ST)/adapted.tsv")" "$SET${TAB}$SETIDS"
asv $SET "$BD/good.json" $HOOKS
ul_t_check "saving again with a subset of the ids succeeds" ul_t_eq "$OUT" "saved=$SET notes=$HOOKS rules=R1,R2,R5"
ul_t_check "... and replaces the row (one row per path)" ul_t_eq "$(adapted_n $SET)" 1
ul_t_check "... with the new ids" ul_t_eq "$(awk -F'\t' -v p=$SET '$1 == p { print $2 }' "$(ST)/adapted.tsv")" "$HOOKS"
ul_t_check "the engine never touched the working tree" ul_t_eq "$(cg status --porcelain)" ""
ul_t_check "the engine never moved a ref" ul_t_eq "$(refs)" "$REFS0"
ul_t_check "no temp file is left in merged/" ul_t_eq "$(find "$(ST)/merged" -name '.update-loom.*' | wc -l | tr -d ' ')" 0

# =============================================================== 2. the ladder note
asv $AMD "$BD/good.json" $LADDER
ul_t_check "ladder: a settings body for amendments.md is an R4 refusal" refused_with 'reason=invariant rule=R4'
awk '
  /^[[:space:]-]*3[[:space:]]*=[[:space:]]*it changes auth, payment, or customer-data logic/ { next }
  { print }
  END { print ""; print "Plus, on top of whichever reversibility line applies:"; print "+3 - it changes auth, payment, or customer-data logic" }
' "$(ul_t_adapt_body $AMD)" > "$BD/ladder.after"
asv $AMD "$BD/ladder.after" $LADDER
ul_t_check "ladder: the .after body is saved" ul_t_eq "$OUT" "saved=$AMD notes=$LADDER rules=R4"
ul_t_check "ladder: ... byte-identical" merged_is $AMD "$BD/ladder.after"
grep -v '^Width:' "$BD/ladder.after" > "$BD/ladder.extra-delete"
asv $AMD "$BD/ladder.extra-delete" $LADDER
ul_t_check "ladder: a body that also deletes an unrelated line: rule=R4" refused_with 'reason=invariant rule=R4 detail='
printf '\n' > "$BD/blank.txt"
asv $AMD "$BD/blank.txt" $LADDER
ul_t_check "ladder: a wiped (blank) body: rule=R4" refused_with 'reason=invariant rule=R4 detail='
printf 'nothing is left\n' > "$BD/wiped.txt"
asv $AMD "$BD/wiped.txt" $LADDER
ul_t_check "ladder: a one-line body (wipe): rule=R4" refused_with 'reason=invariant rule=R4 detail='
asv $AMD "$BD/ladder.after" $HOOKS
ul_t_check "ladder: the hooks note is not listed for amendments.md" refused_with "reason=.*$HOOKS"

# ===================================== 3. a two-way prose row (R3), may-drop-headings
nw
printf '%s\n' "$W_HEAD" > "$W_CUST/.sdd-sync-ref"; cc "pointer at commit 2"
pl
ul_t_check "two-way: FIXTURE.md is a two-way/hold row" ul_t_eq "$(prow $DOC | cut -f1,2)" "two-way${TAB}hold"
{ cat "$(ul_t_adapt_body $DOC)"; printf '\n%s\n' "$SENT"; } > "$BD/doc.good"
asv $DOC "$BD/doc.good" "$(adapt_row $DOC | cut -f2)"
ul_t_check "two-way: a body keeping every heading and adding the sentence is saved with R3" ul_t_eq "$OUT" "saved=$DOC notes=$GUIDE rules=R3"
awk '/^## Appendix/ { skip = 1 } !skip { print }' "$BD/doc.good" > "$BD/doc.nopx"
asv $DOC "$BD/doc.nopx" $GUIDE
ul_t_check "two-way: dropping ## Appendix: rule=R3" refused_with 'reason=invariant rule=R3 detail='

nw
printf '%s\n' "$W_HEAD" > "$W_CUST/.sdd-sync-ref"; cc "pointer at commit 2"
awk '/^project-data:/ { print "may-drop-headings:"; print "  - Appendix" } { print }' "$W_UP/$NOTES/$GUIDE.md" > "$BD/guide.note"
cp "$BD/guide.note" "$W_UP/$NOTES/$GUIDE.md"
ul_t_commit "$W_UP" "note may drop the Appendix" >/dev/null
pl
ul_t_check "may-drop: the re-plan sees the new note" ul_t_eq "$(kv result)" planned
{ cat "$(ul_t_adapt_body $DOC)"; printf '\n%s\n' "$SENT"; } > "$BD/doc.good"
awk '/^## Appendix/ { skip = 1 } !skip { print }' "$BD/doc.good" > "$BD/doc.nopx"
asv $DOC "$BD/doc.nopx" $GUIDE
ul_t_check "may-drop: the same body is saved when the note names Appendix" ul_t_eq "$OUT" "saved=$DOC notes=$GUIDE rules=R3"
sed 's/^## Purpose/## Aim/' "$BD/doc.nopx" > "$BD/doc.renamed"
asv $DOC "$BD/doc.renamed" $GUIDE
ul_t_check "may-drop: ... but another heading still may not go" refused_with 'reason=invariant rule=R3 detail='

# ================================================================== 4. line endings
nw
printf '%s\n' "$W_HEAD" > "$W_CUST/.sdd-sync-ref"
sed "s/\$/$CR/" "$W_CUST/$DOC" > "$BD/crlf.md" && cp "$BD/crlf.md" "$W_CUST/$DOC"
cc "customer file is CRLF"
pl
{ tr -d '\r' < "$(ul_t_adapt_body $DOC)"; printf '\n%s\n' "$SENT"; } > "$BD/doc.lf"
asv $DOC "$BD/doc.lf" $GUIDE
ul_t_check "crlf: an LF body from the adapter is saved" ul_t_eq "$OUT" "saved=$DOC notes=$GUIDE rules=R3"
ul_t_check "crlf: ... the saved file is the body with CRLF endings" ul_t_eq "$(tr -d '\r' < "$(ST)/merged/$DOC" | cmp - "$BD/doc.lf" && echo same)" same
ul_t_check "crlf: ... every line ends in CR" ul_t_eq "$(grep -c "$CR\$" "$(ST)/merged/$DOC")" "$(wc -l < "$BD/doc.lf" | tr -d ' ')"
asv $DOC "$BD/crlf.md" $GUIDE
ul_t_check "crlf: a CRLF body is not doubled" ul_t_eq "$(grep -c "$CR$CR" "$(ST)/merged/$DOC")" 0

# an LF customer file stays LF even when the adapter hands over CRLF
nw
printf '%s\n' "$W_HEAD" > "$W_CUST/.sdd-sync-ref"; cc "pointer at commit 2"
pl
{ cat "$(ul_t_adapt_body $DOC)"; printf '\n%s\n' "$SENT"; } | sed "s/\$/$CR/" > "$BD/doc.crlf-in"
asv $DOC "$BD/doc.crlf-in" $GUIDE
ul_t_check "lf customer: a CRLF body is saved as LF" ul_t_eq "$(grep -c "$CR" "$(ST)/merged/$DOC")" 0

# ================================================================ 5. stale plans
nw
pl
ul_t_settings_variant good "$BD/good.json"
cg commit -q --allow-empty -m "something after the plan"
asv $SET "$BD/good.json" $SETIDS
ul_t_check "stale: a commit after --plan refuses" refused_with 'reason=.*stale'
ul_t_check "stale: ... and saves nothing" no_merged $SET
mku $SET $HOOKS
ul_t_check "stale: --mark-unresolved refuses too" refused_with 'reason=.*stale'
pl
asv $SET "$BD/good.json" $SETIDS
ul_t_check "stale: a fresh --plan makes it work again" ul_t_has "$OUT" "^saved=$SET "
cg update-ref refs/loom-upstream/main "$W_BASE"
asv $SET "$BD/good.json" $SETIDS
ul_t_check "stale: upstream head moved away from the plan: refused" refused_with 'reason=.*stale'

# ================================================================== 6. symlinks
nw
rm -f "$W_CUST/$SET" && ln -s ../elsewhere.json "$W_CUST/$SET"
cc "customer replaces settings.json by a symlink"
pl
ul_t_check "symlink at HEAD: the plan still has a settings.json row" ul_t_eq "$(prow $SET | cut -f2)" hold
printf '{ "hooks": {} }\n' > "$BD/any.json"
asv $SET "$BD/any.json" "$(adapt_row $SET | cut -f2)"
ul_t_check "symlink at HEAD: refused" refused_with 'reason=.*symlink'
ul_t_check "symlink at HEAD: nothing saved" no_merged $SET

nw
POL=.claude/policies/tool-restrictions.json
sed 's/block/warn/' "$W_UP/$POL" > "$BD/tr.edited"
cp "$BD/tr.edited" "$W_UP/$POL"
ul_t_commit "$W_UP" "upstream edits the policy" >/dev/null
cg rm -q -r -f .claude/policies >/dev/null 2>&1
ln -s ../elsewhere "$W_CUST/.claude/policies"
cc "customer replaces the policies directory by a symlink"
pl
ul_t_check "symlinked parent: the file has an adapt row (deleted locally, changed upstream)" ul_t_eq "$(adapt_row $POL | cut -f1)" "$POL"
cp "$BD/tr.edited" "$BD/tr.body"
asv $POL "$BD/tr.body" -
ul_t_check "symlinked parent: refused" refused_with 'reason=.*symlink'
ul_t_check "symlinked parent: nothing saved" no_merged $POL

# ============================================================ 7. --mark-unresolved
nw
pl
REFS1=$(refs)
mku $SET $HOOKS
ul_t_check "unresolved: a safety note on its row is accepted" ul_t_has "$OUT" "^unresolved=$SET lost=[0-9][0-9]*$"
LOST=$(printf '%s\n' "$OUT" | sed -n 's/.* lost=//p')
ul_t_check "unresolved: the lost diff is written" test -s "$(ST)/unresolved/$SET.lost.diff"
ul_t_check "unresolved: ... and shows the adopter hook that would be lost" filehas "$(ST)/unresolved/$SET.lost.diff" 'guard-prod-db.sh'
EXPECT=$(diff -u "$(ST)/adapt/mine/$SET" "$(ST)/adapt/theirs/$SET" | sed '1,2d' | grep -c '^-')
ul_t_check "unresolved: lost= counts the removed lines of mine" ul_t_eq "$LOST" "$EXPECT"
ul_t_check "unresolved: ... which is more than zero" test "$LOST" -gt 0
ul_t_check "unresolved: the lost diff names no timestamp or temp path" ul_t_eq "$(sed -n '1p' "$(ST)/unresolved/$SET.lost.diff")" "--- mine/$SET"
ul_t_check "unresolved: unresolved.tsv row" ul_t_eq "$(cat "$(ST)/unresolved.tsv")" "$SET${TAB}$HOOKS"
mku $SET $HOOKS
ul_t_check "unresolved: marking twice keeps one row" ul_t_eq "$(unres_n $SET)" 1
mku $SET $SETASK
ul_t_check "unresolved: a non-safety note that lists the path: refused, hold it instead" refused_with 'hold it instead'
mku $SET $GUIDE
ul_t_check "unresolved: a note that does not list the path (fixture-doc-guidance): refused" refused_with "reason=.*$GUIDE"
mku $DOC $GUIDE
ul_t_check "unresolved: a non-safety note on its own path: refused, hold it instead" refused_with 'hold it instead'
mku .docs/guides/FIXTURE-2.md $HOOKS
ul_t_check "unresolved: a path with no adapt.tsv row: refused" refused_with 'reason=.*FIXTURE-2.md'
mku $SET nope
ul_t_check "unresolved: an unknown note: refused" refused_with 'reason=.*nope'
ul_t_run_engine --mark-unresolved $SET
ul_t_check "unresolved: wrong argument count is a usage error (exit 2)" ul_t_eq "$RC" 2
ul_t_settings_variant good "$BD/good2.json"
asv $SET "$BD/good2.json" $SETIDS
ul_t_check "unresolved: a later successful save clears the unresolved row" ul_t_eq "$(unres_n $SET)" 0
ul_t_check "unresolved: ... and its lost diff" ul_t_not test -e "$(ST)/unresolved/$SET.lost.diff"
mku $SET $HOOKS
ul_t_check "unresolved: marking after a save drops the adapted.tsv row" ul_t_eq "$(adapted_n $SET)" 0
ul_t_check "unresolved: the engine never touched the working tree" ul_t_eq "$(cg status --porcelain)" ""
ul_t_check "unresolved: the engine never moved a ref" ul_t_eq "$(refs)" "$REFS1"
pl
ul_t_check "re-plan: unresolved.tsv is derived state and is rebuilt away" ul_t_not test -e "$(ST)/unresolved.tsv"
ul_t_check "re-plan: so is the lost diff" ul_t_not test -e "$(ST)/unresolved/$SET.lost.diff"

ul_t_done
