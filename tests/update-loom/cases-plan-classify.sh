#!/bin/sh
# Cases for --plan, first half (package p0-engine-plan-classify): the refusals, the
# base ladder, the path universe, the channel map, the three-way classification
# (blobs AND modes), the read-only export and the plan.tsv / meta / diffs / sides /
# reviewer files. The notes layer is the next package; here --plan must produce a
# correct plan.tsv when no note exists.
# POSIX sh. Prints PASS/FAIL lines; exit status is the overall result.
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib.sh"

ENG_SRC=$UL_T_ROOT/plugins/loom-maintenance/scripts/update-loom.sh
TAB=$(printf '\t')

# ----------------------------------------------------------------- helpers
kv() { printf '%s\n' "$OUT" | sed -n "s/^$1=//p" | head -1; }
ul_t_ne() { [ "$1" != "$2" ]; }
dash_n() { [ -x /bin/dash ] || return 0; /bin/dash -n "$1"; }
cg() { git -C "$W_CUST" "$@"; }
cc() { cg add -A >/dev/null 2>&1 && cg commit -q --allow-empty -m "$1"; }
ug() { git -C "$W_UP" "$@"; }
nw() { # a fresh fixture world in its own temp dir
  nw_d=$(ul_t_tmp) || return 1
  ul_t_world "$nw_d" || { echo "FAIL  fixture world could not be built"; fail=1; return 1; }
}
run() { ul_t_run_engine "$@"; }
pl() { ul_t_run_engine --plan; }                 # plan the customer repo
ST() { ul_t_state; }
prow() { ul_t_plan_row "$1"; }                   # class TAB proposed TAB detail
pcl() { ul_t_plan_class "$1"; }
ppr() { prow "$1" | cut -f2; }
pdet() { prow "$1" | cut -f3; }
norow() { [ -z "$(prow "$1")" ]; }
meta() { sed -n "s/^$1=//p" "$(ST)/meta" | head -1; }
adapt_row() { awk -F'\t' -v p="$1" '$1 == p { print; exit }' "$(ST)/adapt.tsv" 2>/dev/null; }
filehas() { grep -Fq -- "$2" "$1" 2>/dev/null; }
up_edit() { ul_t_edit "$W_UP" "$1" "$2" "$3" >/dev/null; }     # commit an edit in the upstream repo
up_chmod_x() { chmod +x "$W_UP/$1" && ug update-index --chmod=+x -- "$1" && ug commit -q -m "chmod $1"; }
cust_chmod_x() { chmod +x "$W_CUST/$1" && cg update-index --chmod=+x -- "$1" && cg commit -q -m "chmod $1"; }
adopt() { # [GROUPS-JSON] : make the customer an adopted install
  printf '%s\n' "{\"schema\":\"logicloom/adopt-receipt@1\",\"runs\":[{\"status\":\"complete\",\"only\":${1:-[\"harness\",\"hooks\"]}}]}" > "$W_CUST/.logicloom-adopt-receipt.json"
  cc "adopt receipt"
}
EDITED_DOC=.docs/guides/FIXTURE.md
HOOK=.claude/hooks/worktree-port-namespace.sh
GUARD=.claude/hooks/guard-dangerous-commands.sh
NOTES=plugins/loom-maintenance/updates
SET=.claude/settings.json

# =================================================================== 0. syntax
ul_t_check "case file passes sh -n" sh -n "$here/cases-plan-classify.sh"
ul_t_check "case file passes dash -n" dash_n "$here/cases-plan-classify.sh"
ul_t_check "lib.sh passes sh -n" sh -n "$here/lib.sh"
ul_t_check "lib.sh passes dash -n" dash_n "$here/lib.sh"
ul_t_check "engine passes sh -n" sh -n "$ENG_SRC"
ul_t_check "engine passes dash -n" dash_n "$ENG_SRC"
ul_t_check "engine has no bash-isms in the plan code" ul_t_not grep -Eq '^[[:space:]]*(local|function)[[:space:]]|\[\[|<<<' "$ENG_SRC"

# ============================================================ 1. the default world
nw || ul_t_done
pl
ul_t_check "plan: exits 0" ul_t_eq "$RC" 0
ul_t_check "plan: first result line is result=planned" ul_t_eq "$(kv result)" planned
ul_t_check "plan: prints plan=<state>/plan.tsv" ul_t_eq "$(kv plan)" "$(ST)/plan.tsv"
ul_t_check "plan: plan.tsv exists" test -f "$(ST)/plan.tsv"
ul_t_check "plan: settings.json -> posture/hold" ul_t_eq "$(prow $SET | cut -f1,2)" "posture${TAB}hold"
ul_t_check "plan: FIXTURE.md -> merged-clean/apply" ul_t_eq "$(prow $EDITED_DOC | cut -f1,2)" "merged-clean${TAB}apply"
ul_t_check "plan: merged body is saved under state/merged" test -f "$(ST)/merged/$EDITED_DOC"
ul_t_check "plan: merged body keeps the customer's appendix edit" filehas "$(ST)/merged/$EDITED_DOC" 'Appendix text, extended by the customer'
ul_t_check "plan: merged body gains the upstream sentence" filehas "$(ST)/merged/$EDITED_DOC" 'Each one arrives with a plain sentence'
ul_t_check "plan: merged body has no conflict markers" ul_t_not filehas "$(ST)/merged/$EDITED_DOC" '<<<<<<<'
ul_t_check "plan: guard hook -> add/apply" ul_t_eq "$(prow $GUARD | cut -f1,2)" "add${TAB}apply"
ul_t_check "plan: FIXTURE-2.md -> add/apply" ul_t_eq "$(prow .docs/guides/FIXTURE-2.md | cut -f1,2)" "add${TAB}apply"
for n in amendments-ladder-plus-three fixture-doc-followup fixture-doc-guidance hooks-guard-dangerous settings-ask-restore; do
  ul_t_check "plan: note $n.md -> add/apply upstream-owned" ul_t_eq "$(prow $NOTES/7.0.0/$n.md)" "add${TAB}apply${TAB}upstream-owned"
  ul_t_check "plan: check $n.check.sh -> add/apply upstream-owned" ul_t_eq "$(prow $NOTES/7.0.0/$n.check.sh)" "add${TAB}apply${TAB}upstream-owned"
done
ul_t_check "plan: an identical BUNDLE.sha256 has no row" norow $NOTES/BUNDLE.sha256
ul_t_check "plan: customer-only amendments.md has no row" norow .logic-loom/memory/amendments.md
ul_t_check "plan: unchanged hook has no row" norow $HOOK
ul_t_check "plan: unchanged CLAUDE.md has no row" norow CLAUDE.md
ul_t_check "plan: unchanged web/app.js has no row" norow web/app.js
ul_t_check "plan: .sdd-sync-ref never gets a row" norow .sdd-sync-ref
ul_t_check "plan: the engine itself (equal everywhere) has no row" norow plugins/loom-maintenance/scripts/update-loom.sh
ul_t_check "plan: rows = the number of plan.tsv lines" ul_t_eq "$(kv rows)" "$(wc -l < "$(ST)/plan.tsv" | tr -d ' ')"
ul_t_check "plan: every plan.tsv row has four tab-separated columns" ul_t_eq "$(awk -F'\t' 'NF != 4 { n++ } END { print n + 0 }' "$(ST)/plan.tsv")" 0
ul_t_check "plan: class.add count is printed" ul_t_eq "$(kv class.add)" "$(awk -F'\t' '$2 == "add" { n++ } END { print n + 0 }' "$(ST)/plan.tsv")"
ul_t_check "plan: class.posture=1" ul_t_eq "$(kv class.posture)" 1
ul_t_check "plan: class.merged-clean=1" ul_t_eq "$(kv class.merged-clean)" 1
ul_t_check "plan: a class with no rows prints no class line" ul_t_eq "$(kv class.conflict)" ""
ul_t_check "plan: not up to date, so no uptodate line" ul_t_eq "$(kv uptodate)" ""

# meta
HEADC=$(cg rev-parse HEAD)
ul_t_check "meta: base is commit 1" ul_t_eq "$(meta base)" "$W_BASE"
ul_t_check "meta: base_rung=recorded" ul_t_eq "$(meta base_rung)" recorded
ul_t_check "meta: upstream is commit 2" ul_t_eq "$(meta upstream)" "$W_HEAD"
ul_t_check "meta: head is the customer's HEAD" ul_t_eq "$(meta head)" "$HEADC"
ul_t_check "meta: channel=template" ul_t_eq "$(meta channel)" template
ul_t_check "meta: update_id has the contract shape" ul_t_has "$(meta update_id)" '^[0-9]\{8\}T[0-9]\{6\}Z-[0-9a-f]\{12\}$'
UID_TAIL=$(meta update_id | sed 's/.*-//')
ul_t_check "meta: ... which is the first 12 of upstream" ul_t_eq "$UID_TAIL" "$(printf '%s' "$W_HEAD" | cut -c1-12)"
ul_t_check "meta: time is ISO-8601 UTC" ul_t_has "$(meta time)" '^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}Z$'
ul_t_check "plan prints base_rung and update_id too" ul_t_eq "$(kv update_id)" "$(meta update_id)"
ul_t_check "meta: no base_side line outside the adopted merge case" ul_t_eq "$(meta base_side)" ""

# tools
ul_t_check "plan: tools=saved" ul_t_eq "$(kv tools)" saved
ul_t_check "plan: upstream's json-valid.sh is saved" ul_t_eq "$(cat "$(ST)/tools/json-valid.sh")" "$(ug show HEAD:plugins/loom-maintenance/scripts/json-valid.sh)"
ul_t_check "plan: upstream's json-flat.sh is saved" ul_t_eq "$(cat "$(ST)/tools/json-flat.sh")" "$(ug show HEAD:plugins/loom-maintenance/scripts/json-flat.sh)"

# export
ul_t_check "export: the HEAD tree is there" test -f "$(ST)/export/CLAUDE.md"
ul_t_check "export: ... including a customer-only file" test -f "$(ST)/export/.logic-loom/memory/amendments.md"
ul_t_check "export: ... with the customer's content, not upstream's" filehas "$(ST)/export/$EDITED_DOC" 'extended by the customer'
if [ "$(id -u)" != 0 ]; then
  ul_t_check "export: read-only (creating a file inside fails)" ul_t_not sh -c "touch '$(ST)/export/zz-new' 2>/dev/null"
  ul_t_check "export: read-only (editing a file fails)" ul_t_not sh -c "echo x >> '$(ST)/export/CLAUDE.md' 2>/dev/null"
fi

# diffs, sides, adapt.tsv, reviewer
ul_t_check "diffs: held row has base-upstream diff" test -f "$(ST)/diffs/$SET.base-upstream.diff"
ul_t_check "diffs: held row has base-local diff" test -f "$(ST)/diffs/$SET.base-local.diff"
ul_t_check "diffs: merged-clean row has both diffs" test -f "$(ST)/diffs/$EDITED_DOC.base-local.diff" -a -f "$(ST)/diffs/$EDITED_DOC.base-upstream.diff"
ul_t_check "diffs: the base-upstream diff shows the upstream sentence" filehas "$(ST)/diffs/$EDITED_DOC.base-upstream.diff" 'plain sentence'
ul_t_check "diffs: the base-local diff shows the customer's edit" filehas "$(ST)/diffs/$EDITED_DOC.base-local.diff" 'extended by the customer'
ul_t_check "diffs: an add row (not held) has none" ul_t_not test -f "$(ST)/diffs/$GUARD.base-upstream.diff"
ul_t_check "sides: base side saved" filehas "$(ST)/adapt/base/$EDITED_DOC" 'Appendix text as shipped'
ul_t_check "sides: theirs side saved" filehas "$(ST)/adapt/theirs/$EDITED_DOC" 'plain sentence'
ul_t_check "sides: mine side saved" filehas "$(ST)/adapt/mine/$EDITED_DOC" 'extended by the customer'
ul_t_check "sides: settings.json mine side is the customer's file" filehas "$(ST)/adapt/mine/$SET" 'fixture@local'
ul_t_check "adapt.tsv: held row is listed with blob shas" ul_t_eq "$(adapt_row $SET)" "$SET${TAB}-${TAB}$(cg rev-parse $W_BASE:$SET)${TAB}$(ug rev-parse HEAD:$SET)${TAB}$(cg rev-parse HEAD:$SET)"
ul_t_check "adapt.tsv: a non-held, non-merged row is not listed" ul_t_eq "$(adapt_row $GUARD)" ""
ul_t_check "reviewer: log exists for the merged row" test -f "$(ST)/reviewer/$EDITED_DOC.log"
ul_t_check "reviewer: log mentions commit 2's subject" filehas "$(ST)/reviewer/$EDITED_DOC.log" 'head'
ul_t_check "reviewer: log names a short sha" ul_t_has "$(cat "$(ST)/reviewer/$EDITED_DOC.log")" "^$(printf '%s' "$W_HEAD" | cut -c1-7)"
ul_t_check "reviewer: an add row has a log too" test -f "$(ST)/reviewer/$GUARD.log"

# the customer repo is untouched
ul_t_check "plan: HEAD unchanged" ul_t_eq "$(cg rev-parse HEAD)" "$HEADC"
ul_t_check "plan: working tree still clean" ul_t_eq "$(cg status --porcelain | wc -l | tr -d ' ')" 0
ul_t_check "plan: no remote was created" ul_t_eq "$(cg remote | wc -l | tr -d ' ')" 0

# idempotent: twice yields the identical plan.tsv, with the read-only export in the way
cp "$(ST)/plan.tsv" "$(ul_t_tmp)/plan.first" 2>/dev/null
FIRST=$(cat "$(ST)/plan.tsv")
pl
ul_t_check "plan twice: second run exits 0" ul_t_eq "$RC" 0
ul_t_check "plan twice: identical plan.tsv" ul_t_eq "$(cat "$(ST)/plan.tsv")" "$FIRST"
ul_t_check "plan twice: export rebuilt" test -f "$(ST)/export/CLAUDE.md"

# rebuild only what is derived: nothing the customer's recovery depends on is deleted
S=$(ST)
mkdir -p "$S/mine/20200101T000000Z-aaaaaaaaaaaa/x" "$S/diffs/stale"
echo keep > "$S/mine/20200101T000000Z-aaaaaaaaaaaa/x/f"
echo keep > "$S/last-smoke.log"
echo stale > "$S/diffs/stale/old.diff"
echo stale > "$S/plan.tsv"
pl
ul_t_check "rebuild: mine/<update-id>/ survives a plan" ul_t_eq "$(cat "$S/mine/20200101T000000Z-aaaaaaaaaaaa/x/f")" keep
ul_t_check "rebuild: last-smoke.log survives a plan" ul_t_eq "$(cat "$S/last-smoke.log")" keep
ul_t_check "rebuild: a stale diff is gone" ul_t_not test -e "$S/diffs/stale/old.diff"
ul_t_check "rebuild: a stale plan.tsv is replaced" ul_t_not filehas "$S/plan.tsv" stale

# ====================================================== 2. refusals, one by one
nw
echo more >> "$W_CUST/CLAUDE.md"
pl
ul_t_check "dirty tree: exit 1" ul_t_eq "$RC" 1
ul_t_check "dirty tree: result=aborted ... unchanged=yes" ul_t_has "$OUT" '^result=aborted reason=.* unchanged=yes$'
ul_t_check "dirty tree: the reason names the path" ul_t_has "$OUT" 'CLAUDE.md'
ul_t_check "dirty tree: no plan.tsv was written" ul_t_not test -f "$(ST)/plan.tsv"
cg checkout -q -- CLAUDE.md
echo x > "$W_CUST/.docs/guides/stray.md"
pl
ul_t_check "dirty tree: an untracked harness file also refuses" ul_t_has "$OUT" '^result=aborted '
rm -f "$W_CUST/.docs/guides/stray.md"

gd=$(cg rev-parse --absolute-git-dir)
: > "$gd/MERGE_HEAD"
pl
ul_t_check "in progress: refused" ul_t_has "$OUT" '^result=aborted reason=.*unchanged=yes$'
ul_t_check "in progress: exit 1" ul_t_eq "$RC" 1
rm -f "$gd/MERGE_HEAD"

printf '%s\n' "$W_BASE" > "$gd/shallow"
pl
ul_t_check "shallow: refused" ul_t_has "$OUT" '^result=aborted '
ul_t_check "shallow: the reason says unshallow" ul_t_has "$OUT" 'git fetch --unshallow first'
rm -f "$gd/shallow"

# a staged update, a live lock
nw
S=$(ST); mkdir -p "$S"
printf '%s\n' "$W_HEAD" > "$S/staged"
pl
ul_t_check "staged: refused" ul_t_has "$OUT" '^result=aborted reason=a staged update exists; run --finish or --abandon unchanged=yes$'
ul_t_check "staged: the staged file is untouched" ul_t_eq "$(cat "$S/staged")" "$W_HEAD"
rm -f "$S/staged"
sleep 30 &
SLEEPER=$!
printf '%s\n' "$SLEEPER" > "$S/stage.lock"
pl
kill "$SLEEPER" 2>/dev/null
ul_t_check "live lock: refused" ul_t_has "$OUT" '^result=aborted reason=.*staging.* unchanged=yes$'
ul_t_check "live lock: the live pid is named" ul_t_has "$OUT" "$SLEEPER"
ul_t_check "live lock: the lock file is left alone" test -f "$S/stage.lock"
wait "$SLEEPER" 2>/dev/null
pl
ul_t_check "dead lock: healed, and the plan goes ahead" ul_t_eq "$(kv result)" planned
ul_t_check "dead lock: ... and the lock is gone" ul_t_not test -f "$S/stage.lock"

# fetch failure
nw
run --upstream-url "$W_UP/nowhere" --i-am-pointing-at-a-fork --plan
ul_t_check "fetch failure: refused" ul_t_has "$OUT" '^result=aborted reason=could not fetch upstream'
ul_t_check "fetch failure: exit 1" ul_t_eq "$RC" 1

# ============================================================ 3. the base ladder
nw
cg rm -q -f .sdd-sync-ref && cc "drop pointer"
pl
ul_t_check "closest: refused" ul_t_has "$OUT" '^result=aborted reason=base unconfirmed; run --set-base '
ul_t_check "closest: the closest line is printed" ul_t_has "$OUT" '^closest [0-9a-f]\{40\} [0-9]*$'
ul_t_check "closest: the reason names the same sha" ul_t_has "$OUT" "run --set-base $(printf '%s\n' "$OUT" | sed -n 's/^closest \([0-9a-f]*\) .*/\1/p' | head -1) unchanged=yes"
ul_t_check "closest: no plan.tsv" ul_t_not test -f "$(ST)/plan.tsv"
run --set-base "$W_BASE"
pl
ul_t_check "set-base then plan: planned" ul_t_eq "$(kv result)" planned
ul_t_check "set-base then plan: base_rung=recorded" ul_t_eq "$(meta base_rung)" recorded

# none: a customer with no harness file at all, and a pointer nobody can find
nw
cg rm -q -r -f .logic-loom plugins .claude .docs features .sdd-sync-ref && cc "no harness"
OUT=$(cd "$W_CUST" && "$SH" "$ENG_SRC" --plan </dev/null 2>&1); RC=$?
ul_t_check "none: refused" ul_t_has "$OUT" '^result=aborted reason=.*unchanged=yes$'
ul_t_check "none: the repair hint names KNOWN_ISSUES.md" ul_t_has "$OUT" 'KNOWN_ISSUES.md'
ul_t_check "none: ... and the bootstrap command" ul_t_has "$OUT" 'npx logicloom@7 update-bootstrap'
ul_t_check "none: exit 1" ul_t_eq "$RC" 1

# ======================================================== 4. channel, ambiguity
nw
mkdir -p "$W_CUST/.claude" && echo '{}' > "$W_CUST/.claude/.logicloom-adopt-settings.json"
cc "adopt fingerprint, no receipt"
pl
ul_t_check "ambiguous: refused without --channel" ul_t_has "$OUT" '^result=aborted reason=.*--channel.* unchanged=yes$'
ul_t_check "ambiguous: exit 1" ul_t_eq "$RC" 1
ul_t_check "ambiguous: no plan.tsv" ul_t_not test -f "$(ST)/plan.tsv"
run --channel template --plan
ul_t_check "ambiguous + --channel template: plan proceeds" ul_t_eq "$(kv result)" planned
ul_t_check "ambiguous + --channel template: meta channel=template" ul_t_eq "$(meta channel)" template
ul_t_check "ambiguous + --channel template: ordinary classification" ul_t_eq "$(pcl $EDITED_DOC)" merged-clean
run --channel adopted --plan
ul_t_check "ambiguous + --channel adopted: plan proceeds" ul_t_eq "$(kv result)" planned
ul_t_check "ambiguous + --channel adopted: meta channel=adopted" ul_t_eq "$(meta channel)" adopted
ul_t_check "ambiguous + --channel adopted: every optional group counts as not installed (hooks)" ul_t_eq "$(prow $GUARD)" "adopter-owned${TAB}skip${TAB}group hooks not installed"
ul_t_check "ambiguous + --channel adopted: the harness group still is" ul_t_eq "$(pcl $EDITED_DOC)" merged-clean

# ===================================================== 5. classification mutations
# customer deletes a file upstream changed
nw
cg rm -q -f $EDITED_DOC && cc "delete"
pl
ul_t_check "mutation: customer deleted, upstream changed -> conflict/hold" ul_t_eq "$(prow $EDITED_DOC | cut -f1,2)" "conflict${TAB}hold"
ul_t_check "mutation: ... with both diffs" test -f "$(ST)/diffs/$EDITED_DOC.base-upstream.diff" -a -f "$(ST)/diffs/$EDITED_DOC.base-local.diff"
ul_t_check "mutation: ... and a missing mine side" ul_t_not test -e "$(ST)/adapt/mine/$EDITED_DOC"
ul_t_check "mutation: ... the adapt row has - for mine" ul_t_eq "$(adapt_row $EDITED_DOC | cut -f5)" "-"

# same paragraph edited on both sides
nw
sed 's/To update, run the update command and accept the files it lists\./The customer rewrote this paragraph./' "$W_CUST/$EDITED_DOC" > "$W_CUST/x.tmp" && mv "$W_CUST/x.tmp" "$W_CUST/$EDITED_DOC" && cc "same paragraph"
pl
ul_t_check "mutation: same paragraph -> conflict/hold" ul_t_eq "$(prow $EDITED_DOC | cut -f1,2)" "conflict${TAB}hold"
ul_t_check "mutation: ... with both diffs present" test -f "$(ST)/diffs/$EDITED_DOC.base-upstream.diff" -a -f "$(ST)/diffs/$EDITED_DOC.base-local.diff"
ul_t_check "mutation: ... and no merged body" ul_t_not test -e "$(ST)/merged/$EDITED_DOC"
ul_t_check "mutation: ... three sides saved" test -f "$(ST)/adapt/base/$EDITED_DOC" -a -f "$(ST)/adapt/theirs/$EDITED_DOC" -a -f "$(ST)/adapt/mine/$EDITED_DOC"

# upstream-owned trees: engine, tools, bundle, notes
nw
E=plugins/loom-maintenance/scripts/update-loom.sh
echo '# a local edit' >> "$W_CUST/$E" && cc "edit engine"
echo '# edited' >> "$W_CUST/$NOTES/BUNDLE.sha256" && cc "edit bundle"
mkdir -p "$W_CUST/$NOTES/7.0.0"
printf '%s\n' 'locally edited note' > "$W_CUST/$NOTES/7.0.0/hooks-guard-dangerous.md" && cc "edit note"
echo rogue > "$W_CUST/$NOTES/7.0.0/rogue.md" && cc "rogue note"
echo '#!/bin/sh' > "$W_CUST/$NOTES/7.0.0/fixture-doc-guidance.check.sh" && cc "edit check"
pl
ul_t_check "upstream-owned: edited engine -> take/apply upstream-owned" ul_t_eq "$(prow $E)" "take${TAB}apply${TAB}upstream-owned"
ul_t_check "upstream-owned: the engine row is never keep" ul_t_ne "$(pcl $E)" keep
ul_t_check "upstream-owned: edited BUNDLE.sha256 -> take/apply upstream-owned" ul_t_eq "$(prow $NOTES/BUNDLE.sha256)" "take${TAB}apply${TAB}upstream-owned"
ul_t_check "upstream-owned: an edited note -> take/apply upstream-owned" ul_t_eq "$(prow $NOTES/7.0.0/hooks-guard-dangerous.md)" "take${TAB}apply${TAB}upstream-owned"
ul_t_check "upstream-owned: a rogue file in the notes tree -> delete/apply" ul_t_eq "$(prow $NOTES/7.0.0/rogue.md)" "delete${TAB}apply${TAB}upstream-owned"
ul_t_check "upstream-owned: an edited check -> take/apply" ul_t_eq "$(prow $NOTES/7.0.0/fixture-doc-guidance.check.sh)" "take${TAB}apply${TAB}upstream-owned"
ul_t_check "upstream-owned: no diffs for upstream-owned rows" ul_t_not test -e "$(ST)/diffs/$E.base-upstream.diff"

# forbidden tree
nw
up_edit web/app.js 'console.log("upstream edit");' "up web"
ul_t_edit "$W_CUST" web/app.js 'console.log("customer edit");' "cust web" >/dev/null
pl
ul_t_check "forbidden: both edited web/app.js -> excluded/skip/forbidden" ul_t_eq "$(prow web/app.js)" "excluded${TAB}skip${TAB}forbidden"
ul_t_check "forbidden: nothing else is written for it (no diffs)" ul_t_not test -e "$(ST)/diffs/web/app.js.base-upstream.diff"
ul_t_check "forbidden: ... no sides" ul_t_not test -e "$(ST)/adapt/mine/web/app.js"
ul_t_check "forbidden: ... no merged body" ul_t_not test -e "$(ST)/merged/web/app.js"
ul_t_check "forbidden: ... no reviewer log" ul_t_not test -e "$(ST)/reviewer/web/app.js.log"
ul_t_check "forbidden: the customer file is untouched" ul_t_eq "$(cat "$W_CUST/web/app.js")" 'console.log("customer edit");'
nw
ul_t_edit "$W_CUST" web/app.js 'console.log("customer edit");' "cust web" >/dev/null
ul_t_edit "$W_CUST" web/own-page.js 'x' "cust page" >/dev/null
pl
ul_t_check "forbidden: only the customer edited it -> no row (upstream changed nothing)" norow web/app.js
ul_t_check "forbidden: a customer-only product file -> no row" norow web/own-page.js
nw
up_edit apps/api/server.js 'new upstream file' "up apps"
pl
ul_t_check "forbidden: upstream adds a file under apps/ -> excluded/skip/forbidden" ul_t_eq "$(prow apps/api/server.js)" "excluded${TAB}skip${TAB}forbidden"
up_edit features/some-feature/vision.md 'v' "up features"
pl
ul_t_check "forbidden: features/<x>/ is forbidden" ul_t_eq "$(pcl features/some-feature/vision.md)" excluded
ul_t_check "forbidden: features/README.md is not" ul_t_ne "$(pcl features/README.md)" excluded
up_edit features/README.md '# Features, newer' "up features readme"
pl
ul_t_check "forbidden: features/README.md changes upstream -> take/apply" ul_t_eq "$(prow features/README.md | cut -f1,2)" "take${TAB}apply"

# modes
nw
up_chmod_x $HOOK
pl
ul_t_check "mode: upstream flips the exec bit, customer did not -> mode/apply" ul_t_eq "$(prow $HOOK | cut -f1,2)" "mode${TAB}apply"
ul_t_check "mode: ... the mode row carries a detail" ul_t_ne "$(pdet $HOOK)" ""
nw
up_chmod_x $HOOK
cust_chmod_x $HOOK
pl
ul_t_check "mode: both flipped to the same mode -> no row" norow $HOOK
nw
cust_chmod_x $HOOK
pl
ul_t_check "mode: only the customer flipped (base 644, HEAD 755, upstream 644) -> keep/keep" ul_t_eq "$(prow $HOOK | cut -f1,2)" "keep${TAB}keep"
nw
cust_chmod_x $HOOK
blob=$(ug rev-parse HEAD:$HOOK)
ug update-index --cacheinfo "120000,$blob,$HOOK" && ug commit -q -m "symlink mode"
pl
ul_t_check "mode: three different modes -> mode/hold" ul_t_eq "$(prow $HOOK | cut -f1,2)" "mode${TAB}hold"
nw
up_edit $HOOK '#!/bin/sh
echo changed upstream' "up hook content"
cust_chmod_x $HOOK
pl
ul_t_check "mode: content changed upstream, customer only flipped the bit -> take/apply" ul_t_eq "$(prow $HOOK | cut -f1,2)" "take${TAB}apply"

# keep, deleted-upstream-kept, take, delete, add-conflict, posture
nw
ul_t_edit "$W_CUST" CLAUDE.md '# my own claude file' "cust claude" >/dev/null
pl
ul_t_check "keep: customer changed, upstream did not -> keep/keep" ul_t_eq "$(prow CLAUDE.md | cut -f1,2)" "keep${TAB}keep"
ul_t_check "keep: ... no diffs are written for a keep row" ul_t_not test -e "$(ST)/diffs/CLAUDE.md.base-local.diff"
ug rm -q -f CLAUDE.md && ug commit -q -m "up deletes CLAUDE.md"
pl
ul_t_check "deleted-upstream-kept: upstream deleted, customer changed -> hold" ul_t_eq "$(prow CLAUDE.md | cut -f1,2)" "deleted-upstream-kept${TAB}hold"
nw
ug rm -q -f CLAUDE.md && ug commit -q -m "up deletes CLAUDE.md"
pl
ul_t_check "delete: upstream deleted, customer unchanged -> delete/apply" ul_t_eq "$(prow CLAUDE.md | cut -f1,2)" "delete${TAB}apply"
nw
up_edit CLAUDE.md '# upstream rewrote it' "up claude"
pl
ul_t_check "take: upstream changed, customer unchanged -> take/apply" ul_t_eq "$(prow CLAUDE.md | cut -f1,2)" "take${TAB}apply"
ul_t_check "take: ... no diffs for a take row" ul_t_not test -e "$(ST)/diffs/CLAUDE.md.base-upstream.diff"
nw
up_edit lib/new.txt 'upstream' "up new"
ul_t_edit "$W_CUST" lib/new.txt 'customer' "cust new" >/dev/null
pl
ul_t_check "add-conflict: new upstream file, different local file -> add-conflict/hold" ul_t_eq "$(prow lib/new.txt | cut -f1,2)" "add-conflict${TAB}hold"
ul_t_check "add-conflict: ... with the sides, base absent" ul_t_not test -e "$(ST)/adapt/base/lib/new.txt"
ul_t_check "add-conflict: ... theirs and mine saved" test -f "$(ST)/adapt/theirs/lib/new.txt" -a -f "$(ST)/adapt/mine/lib/new.txt"
ul_t_check "add-conflict: ... adapt.tsv base is -" ul_t_eq "$(adapt_row lib/new.txt | cut -f3)" "-"
nw
up_edit lib/same.txt 'identical' "up same"
ul_t_edit "$W_CUST" lib/same.txt 'identical' "cust same" >/dev/null
pl
ul_t_check "add: both added the same content -> no row" norow lib/same.txt
nw
G=.logic-loom/config/gate-policy.conf
printf 'git.push = ask\ngit.merge = ask\ngit.commit = silent\ngit.tag = ask\n' > "$W_CUST/$G" && cc "cust gate"
up_edit $G 'git.fetch = silent
git.push = ask
git.merge = ask
git.commit = silent' "up gate"
pl
ul_t_check "posture: gate-policy edited on both sides -> posture/hold" ul_t_eq "$(prow $G | cut -f1,2)" "posture${TAB}hold"
ul_t_check "posture: ... never merged-clean, so no merged body" ul_t_not test -e "$(ST)/merged/$G"
ul_t_check "posture: ... diffs and sides saved" test -f "$(ST)/diffs/$G.base-local.diff" -a -f "$(ST)/adapt/mine/$G"
nw
printf 'git.push = ask\ngit.merge = ask\ngit.commit = silent\n# same note\n' > "$W_CUST/$G" && cc "cust gate"
printf 'git.push = ask\ngit.merge = ask\ngit.commit = silent\n# same note\n' > "$W_UP/$G"; ul_t_commit "$W_UP" "up gate identical" >/dev/null
pl
ul_t_check "posture: both made the identical edit -> no row" norow $G
nw
up_edit $G 'git.push = ask' "up gate only"
pl
ul_t_check "posture: only upstream changed it -> take/apply (not held)" ul_t_eq "$(prow $G | cut -f1,2)" "take${TAB}apply"

# a .gitignore'd path: ignored, except the notes tree and the engine scripts
nw
printf 'plugins/\n.claude/hooks/\nlib/\n' > "$W_CUST/.gitignore" && cc "ignore"
up_edit lib/new.txt 'ignored upstream file' "up new"
pl
ul_t_check "gitignore: an ignored upstream-new path is not classified" norow lib/new.txt
ul_t_check "gitignore: an ignored hook path is not classified" norow $GUARD
ul_t_check "gitignore: the notes tree is still classified" ul_t_eq "$(prow $NOTES/7.0.0/hooks-guard-dangerous.md | cut -f1,2)" "add${TAB}apply"
printf 'plugins/\n' > "$W_CUST/.gitignore"; cc "ignore plugins"
echo '# edited' >> "$W_CUST/plugins/loom-maintenance/scripts/json-flat.sh" && cc "edit tool"
pl
ul_t_check "gitignore: an edited script under an ignored plugins/ is still classified take/apply" ul_t_eq "$(prow plugins/loom-maintenance/scripts/json-flat.sh)" "take${TAB}apply${TAB}upstream-owned"

# up to date
nw
cg reset -q --hard "$W_HEAD"
printf '%s\n' "$W_HEAD" > "$W_CUST/.sdd-sync-ref" && cc "base is the head"
pl
ul_t_check "up to date: plan succeeds" ul_t_eq "$(kv result)" planned
ul_t_check "up to date: rows=0" ul_t_eq "$(kv rows)" 0
ul_t_check "up to date: uptodate=yes" ul_t_eq "$(kv uptodate)" yes
ul_t_check "up to date: an empty plan.tsv" ul_t_eq "$(wc -c < "$(ST)/plan.tsv" | tr -d ' ')" 0
# keep/excluded/adopter-owned rows do not count as pending work
ul_t_edit "$W_CUST" CLAUDE.md '# mine' "cust claude" >/dev/null
up_edit CLAUDE.md '# theirs' "up claude"
printf '%s\n' "$(ug rev-parse HEAD)" > "$W_CUST/.sdd-sync-ref"; cc "advance base"
ul_t_edit "$W_CUST" CLAUDE.md '# mine again' "cust claude 2" >/dev/null
pl
ul_t_check "up to date: a lone keep row still says uptodate=yes" ul_t_eq "$(kv uptodate)" yes
ul_t_check "up to date: ... and rows counts it" ul_t_eq "$(kv rows)" 1

# ============================================================ 6. adopted channel
nw
adopt
up_edit lib/new.txt 'upstream adds a path the harness does not own' "up new"
up_edit CLAUDE.md '# upstream claude' "up claude"
pl
ul_t_check "adopted: plan proceeds" ul_t_eq "$(kv result)" planned
ul_t_check "adopted: meta channel=adopted" ul_t_eq "$(meta channel)" adopted
ul_t_check "adopted: a path with no harness group -> adopter-owned/skip" ul_t_eq "$(prow lib/new.txt)" "adopter-owned${TAB}skip${TAB}not harness-owned"
ul_t_check "adopted: CLAUDE.md -> excluded/skip adopt-excluded" ul_t_eq "$(prow CLAUDE.md)" "excluded${TAB}skip${TAB}adopt-excluded"
ul_t_check "adopted: settings.json -> posture/hold" ul_t_eq "$(prow $SET | cut -f1,2)" "posture${TAB}hold"
ul_t_check "adopted: no adopt-settings file -> base side is -" ul_t_eq "$(adapt_row $SET | cut -f3)" "-"
ul_t_check "adopted: ... no base side file" ul_t_not test -e "$(ST)/adapt/base/$SET"
ul_t_check "adopted: ... no base_side meta line" ul_t_eq "$(meta base_side)" ""
ul_t_check "adopted: the installed hooks group is classified" ul_t_eq "$(prow $GUARD | cut -f1,2)" "add${TAB}apply"
ul_t_check "adopted: a harness path is classified as usual" ul_t_eq "$(pcl $EDITED_DOC)" merged-clean
ul_t_check "adopted: skip rows get no reviewer log" ul_t_not test -e "$(ST)/reviewer/CLAUDE.md.log"
ul_t_check "adopted: skip rows get no diffs" ul_t_not test -e "$(ST)/diffs/CLAUDE.md.base-upstream.diff"
ul_t_check "adopted: a customer-only top-level file has no row" norow .logicloom-adopt-receipt.json
ul_t_edit "$W_CUST" src/app.py 'print(1)' "cust src" >/dev/null
pl
ul_t_check "adopted: a customer-only product file has no row" norow src/app.py

# the adopt-settings base side
nw
adopt
printf '{"adopt":"inserted"}\n' > "$W_CUST/.claude/.logicloom-adopt-settings.json" && cc "adopt settings"
pl
ul_t_check "adopt-settings: settings.json -> posture/hold" ul_t_eq "$(prow $SET | cut -f1,2)" "posture${TAB}hold"
ul_t_check "adopt-settings: the base side is the recorded insertion" ul_t_eq "$(cat "$(ST)/adapt/base/$SET")" '{"adopt":"inserted"}'
ul_t_check "adopt-settings: adapt.tsv base is that blob" ul_t_eq "$(adapt_row $SET | cut -f3)" "$(cg rev-parse HEAD:.claude/.logicloom-adopt-settings.json)"
ul_t_check "adopt-settings: meta notes base_side=adopt-settings" ul_t_eq "$(meta base_side)" adopt-settings
ul_t_check "adopt-settings: theirs is upstream's file" ul_t_eq "$(adapt_row $SET | cut -f4)" "$(ug rev-parse HEAD:$SET)"
ul_t_check "adopt-settings: the diffs exist" test -f "$(ST)/diffs/$SET.base-upstream.diff" -a -f "$(ST)/diffs/$SET.base-local.diff"
# .gitignore as the other merge path
nw
adopt
printf 'node_modules/\n' > "$W_CUST/.gitignore" && cc "cust gitignore"
up_edit .gitignore 'dist/' "up gitignore"
pl
ul_t_check "adopted: .gitignore (merge path) -> posture/hold" ul_t_eq "$(prow .gitignore | cut -f1,2)" "posture${TAB}hold"
ul_t_check "adopted: .gitignore has no adopt-settings base" ul_t_eq "$(adapt_row .gitignore | cut -f3)" "-"
nw
up_edit .gitignore 'dist/' "up gitignore"
pl
ul_t_check "template: .gitignore new upstream, none locally -> add/apply" ul_t_eq "$(prow .gitignore | cut -f1,2)" "add${TAB}apply"

# a group that is not installed
nw
adopt '["harness"]'
pl
ul_t_check "adopted, hooks not installed: hook path -> adopter-owned" ul_t_eq "$(prow $GUARD)" "adopter-owned${TAB}skip${TAB}group hooks not installed"
ul_t_check "adopted, hooks not installed: harness path still classified" ul_t_eq "$(pcl $EDITED_DOC)" merged-clean
ul_t_check "adopted, hooks not installed: counted in class lines" ul_t_ne "$(kv class.adopter-owned)" ""

# renames: AGENTS.md is addressed at .logic-loom/AGENTS.md on this side
nw
adopt
up_edit AGENTS.md 'agents v1' "up agents"
X=$(ug rev-parse HEAD)
up_edit AGENTS.md 'agents v2' "up agents 2"
mkdir -p "$W_CUST/.logic-loom"
printf 'agents v1\n' > "$W_CUST/.logic-loom/AGENTS.md"
printf '%s\n' "$X" > "$W_CUST/.sdd-sync-ref"
cc "adopted agents file at the renamed path"
pl
ul_t_check "rename: base is the pointer (a commit in upstream's history)" ul_t_eq "$(meta base)" "$X"
ul_t_check "rename: the row is at the adopted path" ul_t_eq "$(prow .logic-loom/AGENTS.md | cut -f1,2)" "take${TAB}apply"
ul_t_check "rename: ... and not at upstream's path" norow AGENTS.md
ul_t_check "rename: reviewer log is keyed by the adopted path, listing upstream's commits" filehas "$(ST)/reviewer/.logic-loom/AGENTS.md.log" 'agents 2'
nw
adopt
up_edit AGENTS.md 'agents new' "up agents"
mkdir -p "$W_CUST/.logic-loom"; printf 'mine\n' > "$W_CUST/.logic-loom/AGENTS.md"
cc "own agents file"
pl
ul_t_check "rename: new upstream AGENTS.md vs a different adopted file -> add-conflict/hold at the adopted path" ul_t_eq "$(prow .logic-loom/AGENTS.md | cut -f1,2)" "add-conflict${TAB}hold"
ul_t_check "rename: theirs side is upstream's AGENTS.md" ul_t_eq "$(cat "$(ST)/adapt/theirs/.logic-loom/AGENTS.md")" 'agents new'
ul_t_check "rename: mine side is the adopted file" ul_t_eq "$(cat "$(ST)/adapt/mine/.logic-loom/AGENTS.md")" mine
# in the template channel nothing is renamed
nw
up_edit AGENTS.md 'agents new' "up agents"
pl
ul_t_check "rename: template channel keeps upstream's path" ul_t_eq "$(prow AGENTS.md | cut -f1,2)" "add${TAB}apply"

# ======================================================= 7. write_two_way_row
nw
pl
run --selftest-two-way $EDITED_DOC
ul_t_check "two-way: selftest exits 0" ul_t_eq "$RC" 0
ul_t_check "two-way: the plan row becomes two-way/hold" ul_t_eq "$(prow $EDITED_DOC | cut -f1,2)" "two-way${TAB}hold"
ul_t_check "two-way: only one row for the path" ul_t_eq "$(awk -F'\t' -v p="$EDITED_DOC" '$1 == p { n++ } END { print n + 0 }' "$(ST)/plan.tsv")" 1
ul_t_check "two-way: adapt row has base -" ul_t_eq "$(adapt_row $EDITED_DOC)" "$EDITED_DOC${TAB}-${TAB}-${TAB}$(ug rev-parse HEAD:$EDITED_DOC)${TAB}$(cg rev-parse HEAD:$EDITED_DOC)"
ul_t_check "two-way: only one adapt row" ul_t_eq "$(awk -F'\t' -v p="$EDITED_DOC" '$1 == p { n++ } END { print n + 0 }' "$(ST)/adapt.tsv")" 1
ul_t_check "two-way: no base side file" ul_t_not test -e "$(ST)/adapt/base/$EDITED_DOC"
ul_t_check "two-way: theirs side is upstream's" filehas "$(ST)/adapt/theirs/$EDITED_DOC" 'plain sentence'
ul_t_check "two-way: mine side is the customer's" filehas "$(ST)/adapt/mine/$EDITED_DOC" 'extended by the customer'
ul_t_check "two-way: plan.tsv stays sorted by path" ul_t_eq "$(cut -f1 "$(ST)/plan.tsv" | LC_ALL=C sort -c 2>&1 | wc -l | tr -d ' ')" 0
nw
pl
run --selftest-two-way CLAUDE.md
ul_t_check "two-way: a path with no existing row gets one" ul_t_eq "$(prow CLAUDE.md | cut -f1,2)" "two-way${TAB}hold"
run --selftest-two-way
ul_t_check "two-way: usage error without a path" ul_t_eq "$RC" 2

ul_t_done
