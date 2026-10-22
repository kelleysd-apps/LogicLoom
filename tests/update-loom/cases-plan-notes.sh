#!/bin/sh
# Cases for --plan, second half (package p0-engine-plan-notes): the notes layer.
# Which notes are offered (the ledger rule), notes.tsv columns, overlap groups,
# applicability checks against the read-only export with write detection, two-way
# rows, adapt.tsv note ids, transaction.txt and the up-to-date verdict.
# POSIX sh. Prints PASS/FAIL lines; exit status is the overall result.
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib.sh"

ENG_SRC=$UL_T_ROOT/plugins/loom-maintenance/scripts/update-loom.sh
TAB=$(printf '\t')
NL='
'

kv() { printf '%s\n' "$OUT" | sed -n "s/^$1=//p" | head -1; }
ul_t_ne() { [ "$1" != "$2" ]; }
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
norow() { [ -z "$(prow "$1")" ]; }
meta() { sed -n "s/^$1=//p" "$(ST)/meta" | head -1; }
adapt_row() { awk -F'\t' -v p="$1" '$1 == p { print; exit }' "$(ST)/adapt.tsv" 2>/dev/null; }
filehas() { grep -Fq -- "$2" "$1" 2>/dev/null; }
NC() { ul_t_notes_col "$1" "$2"; }
isnote() { [ -n "$(NC "$1" 1)" ]; }
NOTES=plugins/loom-maintenance/updates
SET=.claude/settings.json
AMD=.logic-loom/memory/amendments.md
DOC=.docs/guides/FIXTURE.md
SENT='Run /update-loom to take improvements.'
LADDER=amendments-ladder-plus-three
GUIDE=fixture-doc-guidance
FOLLOW=fixture-doc-followup
HOOKS=hooks-guard-dangerous
SETASK=settings-ask-restore
IDS="$LADDER $GUIDE $FOLLOW $HOOKS $SETASK"
nblob() { ug rev-parse "HEAD:$NOTES/7.0.0/$1.md"; }       # the note's blob at upstream
lineno() { grep -n "^$1$TAB" "$(ST)/notes.tsv" | head -1 | cut -d: -f1; }
cust_has_sentence() { printf '\n%s\n' "$SENT" >> "$W_CUST/$DOC"; cc "customer already has the sentence"; }

# up_note ID "REQUIRES (space separated)" "TOUCHES rows separated by |" CHECKBODY|none
up_note() {
  un_f=$W_UP/$NOTES/7.0.0/$1.md
  {
    printf -- '---\nid: %s\ntitle: Test note %s\npurpose: A test note for the cases.\ntouches:\n' "$1" "$1"
    printf '%s\n' "$3" | tr '|' '\n' | while IFS= read -r un_r; do [ -n "$un_r" ] && printf '  - %s\n' "$un_r"; done
    printf 'adds: []\nrequires:'
    if [ -z "$2" ]; then printf ' []\n'; else printf '\n'; for un_q in $2; do printf '  - %s\n' "$un_q"; done; fi
    printf 'safety: false\ndone-when:\n  - "the test passes"\n'
    if [ "$4" = none ]; then printf 'check: none\n'; else printf 'check: %s.check.sh\n' "$1"; fi
    printf 'project-data: false\n---\n\nBody of %s.\n' "$1"
  } > "$un_f"
  if [ "$4" != none ]; then printf '%s\n' "$4" > "$W_UP/$NOTES/7.0.0/$1.check.sh"; fi
  ul_t_commit "$W_UP" "note $1" >/dev/null
}
PASSCHK="#!/bin/sh${NL}exit 0"
FAILCHK="#!/bin/sh${NL}printf 'hint=not yet\\n'${NL}exit 1"

# =================================================================== 0. syntax
ul_t_check "case file passes sh -n" sh -n "$here/cases-plan-notes.sh"
ul_t_check "case file passes dash -n" dash_n "$here/cases-plan-notes.sh"
ul_t_check "lib.sh passes sh -n" sh -n "$here/lib.sh"
ul_t_check "lib.sh passes dash -n" dash_n "$here/lib.sh"
ul_t_check "engine passes sh -n" sh -n "$ENG_SRC"
ul_t_check "engine passes dash -n" dash_n "$ENG_SRC"

# ============================================================ 1. the default world
nw || ul_t_done
HEADC=$(cg rev-parse HEAD)
pl
ul_t_check "default: exits 0" ul_t_eq "$RC" 0
ul_t_check "default: result=planned" ul_t_eq "$(kv result)" planned
ul_t_check "default: notes=5 groups=4 blocked=0 twoway=1" ul_t_has "$OUT" '^notes=5 groups=4 blocked=0 twoway=1$'
ul_t_check "default: class.two-way=1 is counted" ul_t_eq "$(kv class.two-way)" 1
ul_t_check "default: not up to date" ul_t_eq "$(kv uptodate)" ""
ul_t_check "default: notes.tsv has five rows" ul_t_eq "$(wc -l < "$(ST)/notes.tsv" | tr -d ' ')" 5
ul_t_check "default: every notes.tsv row has twelve columns" ul_t_eq "$(awk -F'\t' 'NF != 12 { n++ } END { print n + 0 }' "$(ST)/notes.tsv")" 0
for n in $IDS; do
  ul_t_check "default: $n is offered via (a)" ul_t_eq "$(NC $n 11)" a
  ul_t_check "default: $n is not declined-before" ul_t_eq "$(NC $n 6)" no
  ul_t_check "default: $n is not snoozed" ul_t_eq "$(NC $n 12)" no
  ul_t_check "default: $n path column is notes/$n.md" ul_t_eq "$(NC $n 2)" "notes/$n.md"
  ul_t_check "default: $n note copied into state/notes" test -f "$(ST)/notes/$n.md"
  ul_t_check "default: $n check copied into state/notes" test -f "$(ST)/notes/$n.check.sh"
  ul_t_check "default: checks.log records $n as failing" ul_t_has "$(cat "$(ST)/checks.log")" "^$n exit=1 last=hint="
done
ul_t_check "default: the saved note is upstream's blob" ul_t_eq "$(git -C "$W_CUST" hash-object "$(ST)/notes/$HOOKS.md")" "$(nblob $HOOKS)"
ul_t_check "default: safety column (hooks note true)" ul_t_eq "$(NC $HOOKS 3)" true
ul_t_check "default: safety column (settings note false)" ul_t_eq "$(NC $SETASK 3)" false
ul_t_check "default: touches column, suffix-free" ul_t_eq "$(NC $HOOKS 4)" "$SET"
ul_t_check "default: check column is the file name" ul_t_eq "$(NC $HOOKS 10)" "$HOOKS.check.sh"
ul_t_check "default: project-data column (ladder true)" ul_t_eq "$(NC $LADDER 9)" true
ul_t_check "default: project-data column (hooks false)" ul_t_eq "$(NC $HOOKS 9)" false
ul_t_check "default: hooks and settings share group g1" ul_t_eq "$(NC $HOOKS 7)$(NC $SETASK 7)" g1g1
ul_t_check "default: the other notes are in other groups" ul_t_eq "$(NC $LADDER 7) $(NC $GUIDE 7) $(NC $FOLLOW 7)" "g4 g3 g2"
ul_t_check "default: groups.tsv lists the shared group" ul_t_has "$(cat "$(ST)/groups.tsv")" "^g1${TAB}$HOOKS,$SETASK\$"
ul_t_check "default: groups.tsv has four groups" ul_t_eq "$(wc -l < "$(ST)/groups.tsv" | tr -d ' ')" 4
ul_t_check "default: followup is not blocked (its requirement is offered)" ul_t_eq "$(NC $FOLLOW 5)" -
ul_t_check "default: no note is blocked" ul_t_eq "$(awk -F'\t' '$5 != "-" { n++ } END { print n + 0 }' "$(ST)/notes.tsv")" 0
ul_t_check "default: guidance is ordered before followup" [ "$(lineno $GUIDE)" -lt "$(lineno $FOLLOW)" ]
ul_t_check "default: untouched=yes for the pure add (followup)" ul_t_eq "$(NC $FOLLOW 8)" yes
ul_t_check "default: untouched=no for guidance (merged-clean)" ul_t_eq "$(NC $GUIDE 8)" no
ul_t_check "default: untouched=no for hooks (settings posture)" ul_t_eq "$(NC $HOOKS 8)" no
ul_t_check "default: untouched=no for settings-ask" ul_t_eq "$(NC $SETASK 8)" no
ul_t_check "default: untouched=no for the ladder (two-way row)" ul_t_eq "$(NC $LADDER 8)" no
# two-way row for the project-data file
ul_t_check "default: amendments.md gets a two-way/hold row" ul_t_eq "$(prow $AMD | cut -f1,2)" "two-way${TAB}hold"
ul_t_check "default: adapt row for amendments.md: ids, base -, theirs -, mine set" ul_t_eq "$(adapt_row $AMD)" "$AMD${TAB}$LADDER${TAB}-${TAB}-${TAB}$(cg rev-parse HEAD:$AMD)"
ul_t_check "default: mine side of the two-way row is saved" filehas "$(ST)/adapt/mine/$AMD" 'it changes auth'
ul_t_check "default: no theirs side for the two-way row" ul_t_not test -e "$(ST)/adapt/theirs/$AMD"
ul_t_check "default: adapt note-ids for settings.json" ul_t_eq "$(adapt_row $SET | cut -f2)" "$HOOKS,$SETASK"
ul_t_check "default: adapt note-ids for FIXTURE.md" ul_t_eq "$(adapt_row $DOC | cut -f2)" "$GUIDE"
ul_t_check "default: settings.json is still posture/hold" ul_t_eq "$(prow $SET | cut -f1,2)" "posture${TAB}hold"
# transaction.txt
TX=$(cat "$(ST)/transaction.txt")
ul_t_check "transaction: tag line" ul_t_has "$TX" '^tag loom/pre-update-[0-9]\{8\}-[0-9]\{6\}$'
ul_t_check "transaction: detached worktree line" ul_t_hasline "$TX" "worktree add --detach $(ST)/wt HEAD"
ul_t_check "transaction: commit line" ul_t_hasline "$TX" "commit \"LogicLoom update to $(printf '%s' "$W_HEAD" | cut -c1-12)\""
ul_t_check "transaction: merge line" ul_t_hasline "$TX" "then: git merge --ff-only <staged sha> (you approve this)"
ul_t_check "transaction: write line for settings.json" ul_t_hasline "$TX" "write $SET"
ul_t_check "transaction: write line for the two-way file" ul_t_hasline "$TX" "write $AMD"
ul_t_check "transaction: ledger line per offered note" ul_t_eq "$(grep -c '^ledger ' "$(ST)/transaction.txt")" 5
ul_t_check "transaction: ledger line names a note" ul_t_hasline "$TX" "ledger $GUIDE"
ul_t_check "transaction: a keep/skip row gets no write line" ul_t_hasnt "$TX" '^write web/'
# side effects
ul_t_check "default: HEAD unchanged" ul_t_eq "$(cg rev-parse HEAD)" "$HEADC"
ul_t_check "default: working tree clean" ul_t_eq "$(cg status --porcelain | wc -l | tr -d ' ')" 0
ul_t_check "default: no sentinel left behind" ul_t_not test -e "$(ST)/.sentinel"
if [ "$(id -u)" != 0 ]; then
  ul_t_check "default: export is read-only again after the checks" ul_t_not sh -c "touch '$(ST)/export/zz-new' 2>/dev/null"
fi
# deterministic
cp "$(ST)/notes.tsv" "$(ST)/../n1.tsv"; cp "$(ST)/plan.tsv" "$(ST)/../p1.tsv"; cp "$(ST)/groups.tsv" "$(ST)/../g1.tsv"
pl
ul_t_check "deterministic: same notes.tsv" ul_t_eq "$(cat "$(ST)/notes.tsv")" "$(cat "$(ST)/../n1.tsv")"
ul_t_check "deterministic: same plan.tsv" ul_t_eq "$(cat "$(ST)/plan.tsv")" "$(cat "$(ST)/../p1.tsv")"
ul_t_check "deterministic: same groups.tsv" ul_t_eq "$(cat "$(ST)/groups.tsv")" "$(cat "$(ST)/../g1.tsv")"
ul_t_check "revisit: no revisit line in meta by default" ul_t_eq "$(meta revisit)" ""

# ================================================================ 2. the ledger
nw
cust_has_sentence
ul_t_ledger_append "$W_CUST" $GUIDE applied "$(nblob $GUIDE)"
pl
ul_t_check "ledger applied + check passes: plan succeeds" ul_t_eq "$(kv result)" planned
ul_t_check "ledger applied + check passes: guidance not offered" ul_t_not isnote $GUIDE
ul_t_check "ledger applied + check passes: followup not blocked" ul_t_eq "$(NC $FOLLOW 5)" -
ul_t_check "ledger applied + check passes: four notes remain" ul_t_has "$OUT" '^notes=4 '
ul_t_check "ledger applied + check passes: its check still ran (checks.log)" ul_t_has "$(cat "$(ST)/checks.log")" "^$GUIDE exit=0 "

nw
ul_t_ledger_append "$W_CUST" $GUIDE applied "$(nblob $GUIDE)"
pl
ul_t_check "ledger applied + check fails: offered via (b)" ul_t_eq "$(NC $GUIDE 11)" b
ul_t_check "ledger applied + check fails: not declined-before" ul_t_eq "$(NC $GUIDE 6)" no
ul_t_check "ledger applied + check fails: not snoozed" ul_t_eq "$(NC $GUIDE 12)" no

nw
OLDB=$(nblob $GUIDE)
ul_t_ledger_append "$W_CUST" $GUIDE declined "$OLDB"
pl
ul_t_check "declined + check fails + same blob: offered via (b)" ul_t_eq "$(NC $GUIDE 11)" b
ul_t_check "declined + same blob: declined-before=yes" ul_t_eq "$(NC $GUIDE 6)" yes
ul_t_check "declined + same blob: snoozed=yes" ul_t_eq "$(NC $GUIDE 12)" yes
ul_t_check "declined + same blob: followup is blocked by it" ul_t_eq "$(NC $FOLLOW 5)" $GUIDE
ul_t_check "declined + same blob: blocked count is 1" ul_t_has "$OUT" ' blocked=1 '
pl_rev() { ul_t_run_engine --plan --revisit; }
pl_rev
ul_t_check "declined + --revisit: snoozed=no" ul_t_eq "$(NC $GUIDE 12)" no
ul_t_check "declined + --revisit: still declined-before=yes" ul_t_eq "$(NC $GUIDE 6)" yes
ul_t_check "declined + --revisit: meta records revisit=yes" ul_t_eq "$(meta revisit)" yes
ul_t_run_engine --revisit --plan
ul_t_check "--revisit is accepted before the subcommand too" ul_t_eq "$(kv result)" planned
# a changed note blob un-snoozes
printf '\nA later edit to the note text.\n' >> "$W_UP/$NOTES/7.0.0/$GUIDE.md"
ul_t_commit "$W_UP" "edit the guidance note" >/dev/null
pl
ul_t_check "declined + changed blob: snoozed=no" ul_t_eq "$(NC $GUIDE 12)" no
ul_t_check "declined + changed blob: declined-before=yes" ul_t_eq "$(NC $GUIDE 6)" yes

nw
ul_t_ledger_append "$W_CUST" $LADDER declined-final "$(nblob $LADDER)"
pl
ul_t_check "declined-final: not offered although the check fails" ul_t_not isnote $LADDER
ul_t_check "declined-final: no two-way row for the file" norow $AMD

nw
ul_t_ledger_append "$W_CUST" $GUIDE held "$(nblob $GUIDE)"
pl
ul_t_check "held: offered via (c)" ul_t_eq "$(NC $GUIDE 11)" c
ul_t_check "held: its dependent is blocked" ul_t_eq "$(NC $FOLLOW 5)" $GUIDE

nw
rm -f "$W_CUST/$AMD"; cc "customer deletes amendments"
ul_t_ledger_append "$W_CUST" $LADDER acknowledged "$(nblob $LADDER)"
pl
ul_t_check "acknowledged + file absent: not offered" ul_t_not isnote $LADDER

# blocked by a declined requirement whose check passes
nw
cust_has_sentence
ul_t_ledger_append "$W_CUST" $GUIDE declined "$(nblob $GUIDE)"
pl
ul_t_check "declined + check passes: guidance not offered" ul_t_not isnote $GUIDE
ul_t_check "declined + check passes: followup blocked=guidance" ul_t_eq "$(NC $FOLLOW 5)" $GUIDE
# a dependent of a blocked note is blocked too
up_note third "$FOLLOW" ".docs/guides/FIXTURE-3.md" none
pl
ul_t_check "blocked is transitive: third blocked by followup" ul_t_eq "$(NC third 5)" $FOLLOW

# ================================================================= 3. a cycle
nw
up_note cyc-a "cyc-b" ".docs/guides/ca.md" none
up_note cyc-b "cyc-a" ".docs/guides/cb.md" none
pl
ul_t_check "cycle: aborted" ul_t_has "$OUT" '^result=aborted reason=.* unchanged=yes$'
ul_t_check "cycle: exit 1" ul_t_eq "$RC" 1
ul_t_check "cycle: the reason names the cycle" ul_t_has "$OUT" 'cycle'
ul_t_check "cycle: no plan.tsv is left behind" ul_t_not test -f "$(ST)/plan.tsv"
ul_t_check "cycle: no notes.tsv is left behind" ul_t_not test -f "$(ST)/notes.tsv"

# ============================================================== 4. write detection
nw
HEADC=$(cg rev-parse HEAD)
up_note wr-junk "" ".docs/guides/w1.md" "#!/bin/sh${NL}echo x > \"\$REPO_ROOT/junk\"${NL}exit 0"
pl
ul_t_check "check writes a file: aborted" ul_t_has "$OUT" '^result=aborted reason=.* unchanged=yes$'
ul_t_check "check writes a file: exit 1" ul_t_eq "$RC" 1
ul_t_check "check writes a file: reason says check-wrote" ul_t_has "$OUT" 'check-wrote'
ul_t_check "check writes a file: reason names the note" ul_t_has "$OUT" 'wr-junk'
ul_t_check "check writes a file: reason names junk" ul_t_has "$OUT" 'junk'
ul_t_check "check writes a file: no plan.tsv" ul_t_not test -f "$(ST)/plan.tsv"
ul_t_check "check writes a file: the customer repo is untouched" ul_t_eq "$(cg rev-parse HEAD)$(cg status --porcelain | wc -l | tr -d ' ')" "${HEADC}0"
ul_t_check "check writes a file: the live tree has no junk" ul_t_not test -e "$W_CUST/junk"
if [ "$(id -u)" != 0 ]; then
  ul_t_check "check writes a file: the export is read-only again" ul_t_not sh -c "touch '$(ST)/export/zz-new' 2>/dev/null"
fi
ug reset -q --hard HEAD~1
up_note wr-rm "" ".docs/guides/w2.md" "#!/bin/sh${NL}rm -f \"\$REPO_ROOT/CLAUDE.md\"${NL}exit 0"
pl
ul_t_check "check deletes a file: aborted, naming it" ul_t_has "$OUT" '^result=aborted reason=.*CLAUDE.md'
ug reset -q --hard HEAD~1
up_note wr-edit "" ".docs/guides/w3.md" "#!/bin/sh${NL}echo more >> \"\$REPO_ROOT/CLAUDE.md\"${NL}exit 0"
pl
ul_t_check "check edits a file in place: aborted, naming it" ul_t_has "$OUT" '^result=aborted reason=.*CLAUDE.md'
ug reset -q --hard HEAD~1
up_note wr-tmp "" ".docs/guides/w4.md" "#!/bin/sh${NL}echo x > \"\${TMPDIR:-/tmp}/ul-check-scratch.\$\$\"${NL}rm -f \"\${TMPDIR:-/tmp}/ul-check-scratch.\$\$\"${NL}exit 0"
pl
ul_t_check "check writing under TMPDIR is fine" ul_t_eq "$(kv result)" planned
ul_t_check "check writing under TMPDIR: the note is offered" ul_t_eq "$(NC wr-tmp 11)" a
ug reset -q --hard HEAD~1
up_note wr-ref "" ".docs/guides/w5.md" "#!/bin/sh${NL}git update-ref refs/heads/zz-check HEAD 2>/dev/null${NL}exit 0"
pl
ul_t_check "check changes a git ref: aborted" ul_t_has "$OUT" '^result=aborted reason=.*check wr-ref '
cg update-ref -d refs/heads/zz-check 2>/dev/null

# ================================================================ 5. skip= result
nw
rm -f "$W_CUST/$AMD"; cc "customer has no amendments file"
pl
ul_t_check "skip: plan succeeds" ul_t_eq "$(kv result)" planned
ul_t_check "skip: the ladder note is listed (ledger empty)" ul_t_eq "$(NC $LADDER 11)" a
ul_t_check "skip: untouched=yes" ul_t_eq "$(NC $LADDER 8)" yes
ul_t_check "skip: checks.log carries the skip reason" ul_t_has "$(cat "$(ST)/checks.log")" "^$LADDER exit=0 last=skip="
ul_t_check "skip: no two-way row" norow $AMD
ul_t_check "skip: no adapt row" ul_t_eq "$(adapt_row $AMD)" ""
ul_t_check "skip: no two-way rows at all" ul_t_eq "$(kv class.two-way)" ""

# a project-data file that is already fine needs no row either
nw
printf '%s\n' '# my own rules' > "$W_CUST/$AMD"; cc "customer already fixed it"
pl
ul_t_check "project-data pass: offered via (a)" ul_t_eq "$(NC $LADDER 11)" a
ul_t_check "project-data pass: no two-way row" norow $AMD

# ================================================================= 6. the handover
nw
cg tag loom/pre-update-20260101-000000 HEAD
printf '%s\n' "$W_HEAD" > "$W_CUST/.sdd-sync-ref"; cc "the old updater advanced the pointer"
pl
ul_t_check "handover: base_rung=handover" ul_t_eq "$(meta base_rung)" handover
ul_t_check "handover: base is commit 1" ul_t_eq "$(meta base)" "$W_BASE"
ul_t_check "handover: settings.json is posture/hold" ul_t_eq "$(prow $SET | cut -f1,2)" "posture${TAB}hold"
ul_t_check "handover: the adapt row has a real base sha" ul_t_eq "$(adapt_row $SET | cut -f3)" "$(cg rev-parse $W_BASE:$SET)"
ul_t_check "handover: the hooks note is offered" ul_t_eq "$(NC $HOOKS 11)" a

nw
printf '%s\n' "$W_HEAD" > "$W_CUST/.sdd-sync-ref"; cc "pointer at commit 2"
pl
ul_t_check "no tag: base_rung=recorded" ul_t_eq "$(meta base_rung)" recorded
ul_t_check "no tag: base is commit 2" ul_t_eq "$(meta base)" "$W_HEAD"
ul_t_check "no tag: settings.json becomes a two-way row" ul_t_eq "$(prow $SET | cut -f1,2)" "two-way${TAB}hold"
ul_t_check "no tag: FIXTURE.md becomes a two-way row" ul_t_eq "$(prow $DOC | cut -f1,2)" "two-way${TAB}hold"
ul_t_check "no tag: the two-way adapt row has base -" ul_t_eq "$(adapt_row $SET | cut -f3)" -
ul_t_check "no tag: the two-way adapt row has upstream's blob as theirs" ul_t_eq "$(adapt_row $SET | cut -f4)" "$(ug rev-parse HEAD:$SET)"
ul_t_check "no tag: settings note ids on the two-way row" ul_t_eq "$(adapt_row $SET | cut -f2)" "$HOOKS,$SETASK"
ul_t_check "no tag: FIXTURE-2.md (deleted locally, check fails) is two-way too" ul_t_eq "$(prow .docs/guides/FIXTURE-2.md | cut -f1,2)" "two-way${TAB}hold"
ul_t_check "no tag: that row has no mine side" ul_t_eq "$(adapt_row .docs/guides/FIXTURE-2.md | cut -f5)" -
ul_t_check "no tag: the add-only guard hook stays a plain keep row" ul_t_eq "$(prow .claude/hooks/guard-dangerous-commands.sh | cut -f1)" keep
ul_t_check "no tag: twoway count covers settings, FIXTURE.md, FIXTURE-2.md and amendments" ul_t_has "$OUT" ' twoway=4$'

# ================================================================ 7. shared paths
nw
up_note ua "" ".docs/guides/shared.md|.docs/guides/ua-only.md" none
up_note ub "" ".docs/guides/shared.md" none
pl
ul_t_check "shared path: both notes are offered" ul_t_eq "$(NC ua 11)$(NC ub 11)" aa
ul_t_check "shared path: same group in notes.tsv" ul_t_eq "$(NC ua 7)" "$(NC ub 7)"
ul_t_check "shared path: groups.tsv lists them together" ul_t_has "$(cat "$(ST)/groups.tsv")" "^$(NC ua 7)${TAB}ua,ub\$"
ul_t_check "shared path: it is not the group of the other notes" ul_t_ne "$(NC ua 7)" "$(NC $HOOKS 7)"
ul_t_check "shared path: groups=5" ul_t_has "$OUT" ' groups=5 '

# a note with no ledger row and check none is offered via (a) and listed
ul_t_check "check none: offered via (a)" ul_t_eq "$(NC ua 10)$(NC ua 11)" nonea
ul_t_check "check none: no checks.log line" ul_t_hasnt "$(cat "$(ST)/checks.log")" '^ua '
ul_t_check "check none: no two-way row for a path with no class" norow .docs/guides/shared.md

# ============================================================ 8. the channel suffix
nw
up_note chan "" ".docs/guides/for-template.md @template|.docs/guides/for-adopted.md @adopted|.docs/guides/both.md" none
pl
ul_t_check "channel (template): the @adopted row is ignored, suffixes stripped" ul_t_eq "$(NC chan 4)" ".docs/guides/for-template.md,.docs/guides/both.md"
nw
printf '%s\n' '{"schema":"logicloom/adopt-receipt@1","runs":[{"status":"complete","only":["harness","hooks"]}]}' > "$W_CUST/.logicloom-adopt-receipt.json"; cc "adopt receipt"
up_note chan "" ".docs/guides/for-template.md @template|.docs/guides/for-adopted.md @adopted|.docs/guides/both.md" none
pl
ul_t_check "channel (adopted): the @template row is ignored" ul_t_eq "$(NC chan 4)" ".docs/guides/for-adopted.md,.docs/guides/both.md"

# ============================================================== 9. malformed notes
nw
printf -- '---\nid: bad-one\ntitle: Missing purpose\ntouches: []\nadds: []\nrequires: []\nsafety: false\ncheck: none\nproject-data: false\n---\nbody\n' > "$W_UP/$NOTES/7.0.0/bad-one.md"
ul_t_commit "$W_UP" "bad note" >/dev/null
pl
ul_t_check "malformed (no purpose): aborted" ul_t_has "$OUT" '^result=aborted reason=note bad-one is malformed: .* unchanged=yes$'
ul_t_check "malformed: exit 1" ul_t_eq "$RC" 1
ul_t_check "malformed: nothing planned" ul_t_not test -f "$(ST)/plan.tsv"
ug reset -q --hard HEAD~1
printf -- '---\nid: other-name\ntitle: T\npurpose: P\ntouches: []\nadds: []\nrequires: []\nsafety: false\ncheck: none\nproject-data: false\n---\nbody\n' > "$W_UP/$NOTES/7.0.0/bad-two.md"
ul_t_commit "$W_UP" "id differs" >/dev/null
pl
ul_t_check "malformed (id differs from the file name): aborted" ul_t_has "$OUT" '^result=aborted reason=note bad-two is malformed: '
ug reset -q --hard HEAD~1
printf -- '---\nid: bad-three\ntitle: T\npurpose: P\ntouches: []\nadds: []\nrequires: []\ncheck: none\nproject-data: false\n---\nbody\n' > "$W_UP/$NOTES/7.0.0/bad-three.md"
ul_t_commit "$W_UP" "no safety" >/dev/null
pl
ul_t_check "malformed (no safety): aborted" ul_t_has "$OUT" '^result=aborted reason=note bad-three is malformed: '
ug reset -q --hard HEAD~1
printf -- '---\nid: bad-four\ntitle: T\npurpose: P\ntouches:\n  - web/app.js\nadds: []\nrequires: []\nsafety: false\ncheck: none\nproject-data: false\n---\nbody\n' > "$W_UP/$NOTES/7.0.0/bad-four.md"
ul_t_commit "$W_UP" "forbidden touch" >/dev/null
pl
ul_t_check "malformed (touches a forbidden path): aborted" ul_t_has "$OUT" '^result=aborted reason=note bad-four is malformed: '

# ============================================================== 10. upstream tools
nw
ug rm -q plugins/loom-maintenance/scripts/json-valid.sh && ug commit -q -m "drop json-valid.sh"
pl
ul_t_check "no json-valid.sh upstream + a held .json: aborted" ul_t_has "$OUT" '^result=aborted reason=.*json-valid.sh.* unchanged=yes$'
ul_t_check "no json-valid.sh upstream + a held .json: names the file" ul_t_has "$OUT" "$SET"
nw
git -C "$W_CUST" checkout -q "$W_BASE" -- $SET && cc "customer back to the stock settings"
ug rm -q plugins/loom-maintenance/scripts/json-valid.sh && ug commit -q -m "drop json-valid.sh"
pl
ul_t_check "no json-valid.sh upstream, no held .json: plan proceeds" ul_t_eq "$(kv result)" planned
ul_t_check "... and says tools=absent" ul_t_eq "$(kv tools)" absent

# ============================================================== 11. fully applied
nw
cg checkout -q "$W_HEAD" -- . && cg rm -q -f "$AMD" && cc "customer is at upstream's head"
for n in $IDS; do ul_t_ledger_append "$W_CUST" $n applied "$(nblob $n)"; done
pl
ul_t_check "fully applied: plan succeeds" ul_t_eq "$(kv result)" planned
ul_t_check "fully applied: notes=0" ul_t_has "$OUT" '^notes=0 groups=0 blocked=0 twoway=0$'
ul_t_check "fully applied: uptodate=yes" ul_t_eq "$(kv uptodate)" yes
ul_t_check "fully applied: notes.tsv is empty" ul_t_eq "$(wc -c < "$(ST)/notes.tsv" | tr -d ' ')" 0
ul_t_check "fully applied: every check ran and passed" ul_t_eq "$(grep -c ' exit=0 ' "$(ST)/checks.log")" 5

ul_t_done
