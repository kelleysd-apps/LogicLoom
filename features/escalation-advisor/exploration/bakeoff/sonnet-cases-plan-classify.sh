#!/bin/sh
# Cases for the /update-loom engine's --plan, first half (package
# p0-engine-plan-classify): the three-way classification of every path, the
# channel map applied, the read-only export, plan.tsv / meta / diffs / sides.
# The notes layer is the next package; here a plan with no note must already be
# correct, and write_two_way_row (used by the notes layer) is proved through the
# TEST-ONLY --selftest-two-way subcommand.
# POSIX sh. Prints PASS/FAIL lines; exit status is the overall result.
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib.sh"

ENG_SRC=$UL_T_ROOT/plugins/loom-maintenance/scripts/update-loom.sh
LIB_SRC=$here/lib.sh

# ----------------------------------------------------------------- helpers
kv() { printf '%s\n' "$OUT" | sed -n "s/^$1=//p" | head -1; }          # KEY -> value from $OUT
ul_t_ne() { [ "$1" != "$2" ]; }
dash_n() { [ -x /bin/dash ] || return 0; /bin/dash -n "$1"; }
cg() { git -C "$W_CUST" "$@"; }
cc() { cg add -A >/dev/null 2>&1 && cg commit -q --allow-empty -m "$1"; }
nw() { # a fresh fixture world in its own temp dir
  nw_d=$(ul_t_tmp) || return 1
  ul_t_world "$nw_d" || { echo "FAIL  fixture world could not be built"; fail=1; return 1; }
}
run() { ul_t_run_engine "$@"; }
plan() { run --plan; ST=$(ul_t_state); }
cls() { ul_t_plan_class "$1"; }
prop() { ul_t_plan_proposed "$1"; }
det() { ul_t_plan_detail "$1"; }
norow() { [ -z "$(ul_t_plan_row "$1")" ]; }
exists() { [ -e "$1" ]; }
absent() { [ ! -e "$1" ]; }
contains() { grep -q -F -- "$2" "$1" 2>/dev/null; }          # FILE TEXT
row_is() { # PATH CLASS PROPOSED [DETAIL]
  [ "$(cls "$1")" = "$2" ] && [ "$(prop "$1")" = "$3" ] || return 1
  [ -z "${4:-}" ] || [ "$(det "$1")" = "$4" ]
}
nrows() { awk 'END { print NR + 0 }' "$ST/plan.tsv"; }
upe() { ul_t_edit "$W_UP" "$@"; }                              # edit + commit in the upstream
cue() { ul_t_edit "$W_CUST" "$@"; }                            # edit + commit in the customer
unix_root() { [ "$(id -u)" = 0 ]; }
bundle_ok() { c=$(cls plugins/loom-maintenance/updates/BUNDLE.sha256); [ -z "$c" ] || [ "$c" = take ]; }
ro_export() { unix_root && return 0; ! touch "$ST/export/zz-probe" 2>/dev/null; }

N=plugins/loom-maintenance/updates/7.0.0
S=plugins/loom-maintenance/scripts

# =================================================================== 0. syntax
ul_t_check "case file passes sh -n" sh -n "$here/cases-plan-classify.sh"
ul_t_check "case file passes dash -n" dash_n "$here/cases-plan-classify.sh"
ul_t_check "lib.sh passes sh -n" sh -n "$LIB_SRC"
ul_t_check "lib.sh passes dash -n" dash_n "$LIB_SRC"
ul_t_check "engine passes sh -n" sh -n "$ENG_SRC"
ul_t_check "engine passes dash -n" dash_n "$ENG_SRC"
ul_t_check "engine has no [[ ]]" ul_t_not grep -q '\[\[' "$ENG_SRC"
ul_t_check "engine has no local" ul_t_not grep -Eq '^[[:space:]]*local[[:space:]]' "$ENG_SRC"
ul_t_check 'engine has no var-slash-slash substitution' ul_t_not grep -Eq '\$\{[A-Za-z_0-9]+//' "$ENG_SRC"
ul_t_check "engine has no dollar-quote strings" ul_t_not grep -Eq "[$]'" "$ENG_SRC"

# ==================================================== 1. the default world
nw || ul_t_done
plan
ul_t_check "plan: exits 0" ul_t_eq "$RC" 0
ul_t_check "plan: result=planned" ul_t_eq "$(kv result)" planned
ul_t_check "plan: the settings file is posture/hold" row_is .claude/settings.json posture hold
ul_t_check "plan: the guide merges cleanly" row_is .docs/guides/FIXTURE.md merged-clean apply
ul_t_check "plan: the merged body keeps the customer's appendix edit" contains "$ST/merged/.docs/guides/FIXTURE.md" "extended by the customer"
ul_t_check "plan: the merged body carries the upstream sentence" contains "$ST/merged/.docs/guides/FIXTURE.md" "Run /update-loom to take improvements"
ul_t_check "plan: a new upstream hook is add/apply" row_is .claude/hooks/guard-dangerous-commands.sh add apply
ul_t_check "plan: a new upstream guide is add/apply" row_is .docs/guides/FIXTURE-2.md add apply
for f in fixture-doc-guidance.md fixture-doc-guidance.check.sh fixture-doc-followup.md fixture-doc-followup.check.sh \
         hooks-guard-dangerous.md hooks-guard-dangerous.check.sh settings-ask-restore.md settings-ask-restore.check.sh \
         amendments-ladder-plus-three.md amendments-ladder-plus-three.check.sh; do
  ul_t_check "plan: note file $f is add/apply, upstream-owned" row_is "$N/$f" add apply upstream-owned
done
ul_t_check "plan: the bundle is untouched or taken, never held" bundle_ok
ul_t_check "plan: the customer-only amendments file has no row" norow .logic-loom/memory/amendments.md
ul_t_check "plan: a file equal everywhere has no row (CLAUDE.md)" norow CLAUDE.md
ul_t_check "plan: a forbidden file equal everywhere has no row (web/app.js)" norow web/app.js
ul_t_check "plan: .sdd-sync-ref has no row" norow .sdd-sync-ref
ul_t_check "plan: the mode-only base file has no row" norow .claude/hooks/worktree-port-namespace.sh
ul_t_check "plan: class.posture=1 is printed" ul_t_eq "$(kv class.posture)" 1
ul_t_check "plan: class.merged-clean=1 is printed" ul_t_eq "$(kv class.merged-clean)" 1
ul_t_check "plan: class.add is printed" ul_t_has "$OUT" '^class\.add=[0-9][0-9]*$'
ul_t_check "plan: rows= matches plan.tsv" ul_t_eq "$(kv rows)" "$(nrows)"
ul_t_check "plan: plan= names plan.tsv" ul_t_eq "$(kv plan)" "$ST/plan.tsv"
ul_t_check "plan: not uptodate, so no uptodate line" ul_t_hasnt "$OUT" '^uptodate='
ul_t_check "plan: every plan row has exactly four columns" ul_t_eq "$(awk -F'\t' 'NF != 4' "$ST/plan.tsv" | wc -l | tr -d ' ')" 0
ul_t_check "plan: tools=saved" ul_t_eq "$(kv tools)" saved
ul_t_check "plan: upstream's json-valid.sh is saved" exists "$ST/tools/json-valid.sh"
ul_t_check "plan: upstream's json-flat.sh is saved" exists "$ST/tools/json-flat.sh"
# meta
ul_t_check "meta: base is commit 1" contains "$ST/meta" "base=$W_BASE"
ul_t_check "meta: base_rung=recorded" ul_t_has "$(cat "$ST/meta")" '^base_rung=recorded$'
ul_t_check "meta: upstream is commit 2" ul_t_has "$(cat "$ST/meta")" "^upstream=$W_HEAD\$"
ul_t_check "meta: head is the customer's HEAD" ul_t_has "$(cat "$ST/meta")" "^head=$(cg rev-parse HEAD)\$"
ul_t_check "meta: channel=template" ul_t_has "$(cat "$ST/meta")" '^channel=template$'
ul_t_check "meta: update_id has the contract shape" grep -Eq '^update_id=[0-9]{8}T[0-9]{6}Z-[0-9a-f]{12}$' "$ST/meta"
ul_t_check "meta: update_id ends in the upstream sha12" ul_t_has "$(cat "$ST/meta")" "^update_id=.*-$(printf '%s' "$W_HEAD" | cut -c1-12)\$"
ul_t_check "meta: time is ISO-8601 UTC" grep -Eq '^time=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$ST/meta"
ul_t_check "meta: no base_side line without an adopt settings file" ul_t_hasnt "$(cat "$ST/meta")" '^base_side='
ul_t_check "plan: prints the same update_id as meta" ul_t_eq "$(kv update_id)" "$(sed -n 's/^update_id=//p' "$ST/meta")"
# export
ul_t_check "export: holds HEAD's tree" contains "$ST/export/.docs/guides/FIXTURE.md" "extended by the customer"
ul_t_check "export: does not hold upstream-only files" absent "$ST/export/.docs/guides/FIXTURE-2.md"
ul_t_check "export: is read-only for a non-root user" ro_export
# diffs, sides, reviewer logs
ul_t_check "diffs: base-upstream diff for the merged-clean row" exists "$ST/diffs/.docs/guides/FIXTURE.md.base-upstream.diff"
ul_t_check "diffs: base-local diff for the merged-clean row" exists "$ST/diffs/.docs/guides/FIXTURE.md.base-local.diff"
ul_t_check "diffs: the base-upstream diff shows the upstream sentence" contains "$ST/diffs/.docs/guides/FIXTURE.md.base-upstream.diff" "Run /update-loom"
ul_t_check "diffs: the base-local diff shows the customer's edit" contains "$ST/diffs/.docs/guides/FIXTURE.md.base-local.diff" "extended by the customer"
ul_t_check "diffs: the hold row has both diffs too" exists "$ST/diffs/.claude/settings.json.base-upstream.diff"
ul_t_check "diffs: an add row has no diff" absent "$ST/diffs/.docs/guides/FIXTURE-2.md.base-upstream.diff"
ul_t_check "sides: base side saved for the merged-clean row" contains "$ST/adapt/base/.docs/guides/FIXTURE.md" "To update, run the update command"
ul_t_check "sides: theirs side saved" contains "$ST/adapt/theirs/.docs/guides/FIXTURE.md" "Run /update-loom"
ul_t_check "sides: mine side saved" contains "$ST/adapt/mine/.docs/guides/FIXTURE.md" "extended by the customer"
ul_t_check "sides: an add row saves no sides" absent "$ST/adapt/theirs/.docs/guides/FIXTURE-2.md"
ul_t_check "adapt.tsv: the settings row has note-ids - and three blob shas" ul_t_eq "$(awk -F'\t' '$1 == ".claude/settings.json" { print NF ":" $2 }' "$ST/adapt.tsv")" "5:-"
ul_t_check "adapt.tsv: the merged-clean row names the real blob shas" ul_t_eq "$(awk -F'\t' '$1 == ".docs/guides/FIXTURE.md" { print $3 " " $4 " " $5 }' "$ST/adapt.tsv")" "$(cg rev-parse "$W_BASE:.docs/guides/FIXTURE.md") $(cg rev-parse "$W_HEAD:.docs/guides/FIXTURE.md") $(cg rev-parse HEAD:.docs/guides/FIXTURE.md)"
ul_t_check "adapt.tsv: an add row is not listed" ul_t_eq "$(awk -F'\t' '$1 == ".docs/guides/FIXTURE-2.md"' "$ST/adapt.tsv" | wc -l | tr -d ' ')" 0
ul_t_check "reviewer: log for a merged-clean row names upstream's commit subject" contains "$ST/reviewer/.docs/guides/FIXTURE.md.log" head
ul_t_check "reviewer: log line starts with a short sha" grep -Eq '^[0-9a-f]{7,} head$' "$ST/reviewer/.docs/guides/FIXTURE.md.log"
ul_t_check "reviewer: log for an add row exists" exists "$ST/reviewer/.docs/guides/FIXTURE-2.md.log"
ul_t_check "reviewer: no log for a path with no row" absent "$ST/reviewer/CLAUDE.md.log"
# idempotent
cp "$ST/plan.tsv" "$ST/plan.first"
run --plan
ul_t_check "plan: a second run exits 0" ul_t_eq "$RC" 0
ul_t_check "plan: running twice gives the same plan.tsv" cmp -s "$ST/plan.tsv" "$ST/plan.first"
ul_t_check "plan: the second run rebuilt the export read-only" ro_export
ul_t_check "plan: working tree untouched by a plan" ul_t_eq "$(cg status --porcelain | wc -l | tr -d ' ')" 0
ul_t_check "plan: no remote created" ul_t_eq "$(cg remote | wc -l | tr -d ' ')" 0
# persistence across plans: mine/, last-smoke.log survive; the rebuilt items do not
mkdir -p "$ST/mine/20260101T000000Z-aaaaaaaaaaaa/x"
printf 'kept\n' > "$ST/mine/20260101T000000Z-aaaaaaaaaaaa/x/y"
printf 'smoke\n' > "$ST/last-smoke.log"
printf 'stale\n' > "$ST/checks.log"
mkdir -p "$ST/unresolved"; printf 'stale\n' > "$ST/unresolved/z.lost.diff"
run --plan
ul_t_check "persist: mine/ survives a plan" exists "$ST/mine/20260101T000000Z-aaaaaaaaaaaa/x/y"
ul_t_check "persist: last-smoke.log survives a plan" exists "$ST/last-smoke.log"
ul_t_check "rebuild: checks.log is rebuilt away" absent "$ST/checks.log"
ul_t_check "rebuild: unresolved/ is rebuilt away" absent "$ST/unresolved"
# write_two_way_row (selftest only)
rm -f "$ST/adapt.tsv.bak"
run --selftest-two-way CLAUDE.md
ul_t_check "two-way: selftest exits 0" ul_t_eq "$RC" 0
ul_t_check "two-way: row is two-way/hold" row_is CLAUDE.md two-way hold
ul_t_check "two-way: adapt row has base -" ul_t_eq "$(awk -F'\t' '$1 == "CLAUDE.md" { print $2 "|" $3 "|" $4 "|" $5 }' "$ST/adapt.tsv")" "-|-|$(cg rev-parse "$W_HEAD:CLAUDE.md")|$(cg rev-parse HEAD:CLAUDE.md)"
ul_t_check "two-way: theirs side saved" exists "$ST/adapt/theirs/CLAUDE.md"
ul_t_check "two-way: mine side saved" exists "$ST/adapt/mine/CLAUDE.md"
ul_t_check "two-way: no base side saved" absent "$ST/adapt/base/CLAUDE.md"
run --selftest-two-way CLAUDE.md
ul_t_check "two-way: calling twice leaves one plan row" ul_t_eq "$(awk -F'\t' '$1 == "CLAUDE.md"' "$ST/plan.tsv" | wc -l | tr -d ' ')" 1
ul_t_check "two-way: calling twice leaves one adapt row" ul_t_eq "$(awk -F'\t' '$1 == "CLAUDE.md"' "$ST/adapt.tsv" | wc -l | tr -d ' ')" 1
run --plan
ul_t_check "two-way: --plan does not call it" norow CLAUDE.md

# ========================================== 2. mutations: content classification
nw; cg rm -q .docs/guides/FIXTURE.md && cc "customer deletes the guide"; plan
ul_t_check "delete: customer deletes, upstream changed -> conflict/hold" row_is .docs/guides/FIXTURE.md conflict hold
ul_t_check "delete: the conflict has both diffs" exists "$ST/diffs/.docs/guides/FIXTURE.md.base-local.diff"
ul_t_check "delete: no mine side (the file is gone)" absent "$ST/adapt/mine/.docs/guides/FIXTURE.md"
ul_t_check "delete: adapt row says mine -" ul_t_eq "$(awk -F'\t' '$1 == ".docs/guides/FIXTURE.md" { print $5 }' "$ST/adapt.tsv")" "-"

nw
cue .docs/guides/FIXTURE.md '# Fixture guide

## Purpose

This guide exists so the update engine has a markdown file to merge.

## Running updates

The customer rewrote this paragraph in their own words.

## Appendix

Appendix text as shipped.'
plan
ul_t_check "same paragraph: both changed it -> conflict/hold" row_is .docs/guides/FIXTURE.md conflict hold
ul_t_check "same paragraph: base-upstream diff present" exists "$ST/diffs/.docs/guides/FIXTURE.md.base-upstream.diff"
ul_t_check "same paragraph: base-local diff present" exists "$ST/diffs/.docs/guides/FIXTURE.md.base-local.diff"
ul_t_check "same paragraph: no merged body saved" absent "$ST/merged/.docs/guides/FIXTURE.md"
ul_t_check "same paragraph: three sides saved" exists "$ST/adapt/mine/.docs/guides/FIXTURE.md"

nw
printf '# edited by the customer\n' >> "$W_CUST/$S/json-flat.sh"; cc "customer edits the engine"
plan
ul_t_check "engine file: a customer edit is take/apply upstream-owned, never keep" row_is "$S/json-flat.sh" take apply upstream-owned
cg rm -q "$S/json-valid.sh"; cc "customer deletes a script"; run --plan
ul_t_check "engine file: a customer deletion is add/apply upstream-owned" row_is "$S/json-valid.sh" add apply upstream-owned
mkdir -p "$W_CUST/$N"; printf 'junk\n' > "$W_CUST/$N/fixture-doc-guidance.md"; cc "customer writes a note file"; run --plan
ul_t_check "notes: a customer's own note file at an upstream path is take, not add-conflict" row_is "$N/fixture-doc-guidance.md" take apply upstream-owned
git -C "$W_UP" rm -q "$S/json-flat.sh" && git -C "$W_UP" commit -q -m "drop json-flat" || :
run --plan
ul_t_check "engine file: removed upstream while the customer holds it -> delete/apply upstream-owned" row_is "$S/json-flat.sh" delete apply upstream-owned
ul_t_check "plan: tools=absent when upstream lacks json-flat.sh" ul_t_eq "$(kv tools)" absent

nw
upe web/app.js 'changed upstream'
cue web/app.js 'changed local'
plan
ul_t_check "forbidden: web/app.js is excluded/skip/forbidden" row_is web/app.js excluded skip forbidden
ul_t_check "forbidden: no diff for it" absent "$ST/diffs/web/app.js.base-upstream.diff"
ul_t_check "forbidden: no side for it" absent "$ST/adapt/mine/web/app.js"
ul_t_check "forbidden: no reviewer log for a skip row" absent "$ST/reviewer/web/app.js.log"
ul_t_check "forbidden: no merged body" absent "$ST/merged/web/app.js"
ul_t_check "forbidden: exactly one row mentions it" ul_t_eq "$(awk -F'\t' '$1 == "web/app.js"' "$ST/plan.tsv" | wc -l | tr -d ' ')" 1
ul_t_check "forbidden: no adapt row" ul_t_eq "$(awk -F'\t' '$1 == "web/app.js"' "$ST/adapt.tsv" | wc -l | tr -d ' ')" 0

nw
upe features/mine.md 'upstream put a file here'
upe .brain/note.md 'upstream put a brain file here'
upe .logic-loom/memory/update-ledger.tsv 'x'
upe README.md 'a harmless new upstream readme'
plan
ul_t_check "forbidden: features/<file> is excluded" row_is features/mine.md excluded skip forbidden
ul_t_check "forbidden: .brain/<file> is excluded" row_is .brain/note.md excluded skip forbidden
ul_t_check "forbidden: the ledger is excluded" row_is .logic-loom/memory/update-ledger.tsv excluded skip forbidden
ul_t_check "forbidden: a non-forbidden new file is still add/apply" row_is README.md add apply
upe .brain/README.md 'a shipped brain readme'
run --plan
ul_t_check "forbidden: .brain/README.md stays touchable" row_is .brain/README.md add apply
upe features/README.md '# Features, updated'
run --plan
ul_t_check "forbidden: features/README.md stays touchable" row_is features/README.md take apply

nw
upe .logic-loom/config/gate-policy.conf '# Fixture gate policy: which operations ask and which run silent.
git.push = ask
git.merge = ask
git.commit = ask'
cue .logic-loom/config/gate-policy.conf '# Fixture gate policy: which operations ask and which run silent.
git.push = ask
git.merge = silent
git.commit = silent'
plan
ul_t_check "posture: gate-policy edited by both -> posture/hold" row_is .logic-loom/config/gate-policy.conf posture hold
ul_t_check "posture: it has both diffs" exists "$ST/diffs/.logic-loom/config/gate-policy.conf.base-local.diff"

nw
upe .logic-loom/config/gate-policy.conf '# Fixture gate policy: which operations ask and which run silent.
git.push = ask
git.merge = ask
git.commit = ask'
plan
ul_t_check "posture: gate-policy changed upstream only -> take/apply" row_is .logic-loom/config/gate-policy.conf take apply

nw
cue CLAUDE.md '# Fixture project
changed only by the customer'
plan
ul_t_check "keep: changed locally only -> keep/keep" row_is CLAUDE.md keep keep
ul_t_check "keep: a keep row has a reviewer log" exists "$ST/reviewer/CLAUDE.md.log"
ul_t_check "keep: a keep row saves no sides" absent "$ST/adapt/mine/CLAUDE.md"
ul_t_check "keep: ... and no adapt row" ul_t_eq "$(awk -F'\t' '$1 == "CLAUDE.md"' "$ST/adapt.tsv" | wc -l | tr -d ' ')" 0

nw
upe CLAUDE.md '# Fixture project
changed by upstream'
plan
ul_t_check "take: changed upstream, untouched locally -> take/apply" row_is CLAUDE.md take apply
nw
git -C "$W_UP" rm -q CLAUDE.md && git -C "$W_UP" commit -q -m "drop CLAUDE" || :
plan
ul_t_check "delete: removed upstream, untouched locally -> delete/apply" row_is CLAUDE.md delete apply
nw
git -C "$W_UP" rm -q CLAUDE.md && git -C "$W_UP" commit -q -m "drop CLAUDE" || :
cue CLAUDE.md '# Fixture project
the customer edited it'
plan
ul_t_check "deleted-upstream-kept: removed upstream, edited locally -> deleted-upstream-kept/hold" row_is CLAUDE.md deleted-upstream-kept hold
ul_t_check "deleted-upstream-kept: has sides and diffs" exists "$ST/adapt/mine/CLAUDE.md"

nw
upe docs-new.md 'new upstream file'
cue docs-new.md 'a different local file at the same path'
plan
ul_t_check "add-conflict: new upstream file, different local file -> add-conflict/hold" row_is docs-new.md add-conflict hold
ul_t_check "add-conflict: no base side" absent "$ST/adapt/base/docs-new.md"
ul_t_check "add-conflict: the other two sides saved" exists "$ST/adapt/theirs/docs-new.md"
nw
upe docs-new.md 'same text'
cue docs-new.md 'same text'
plan
ul_t_check "add equal: new upstream file already present identically -> no row" norow docs-new.md
nw
upe docs-new.md 'upstream only'
cue docs-mine.md 'customer only'
plan
ul_t_check "local-only: a customer-only file has no row" norow docs-mine.md
nw
cue web/mine.js 'customer product code'
cue features/mine/plan.md 'customer plan'
cue "$N/mine.md" 'a stray customer file in the notes tree'
plan
ul_t_check "local-only: customer product code is never listed" norow web/mine.js
ul_t_check "local-only: a customer plan is never listed" norow features/mine/plan.md
ul_t_check "local-only: a stray file in the notes tree is not deleted" norow "$N/mine.md"

nw
git -C "$W_UP" rm -q CLAUDE.md && git -C "$W_UP" commit -q -m drop || :
cg rm -q CLAUDE.md && cc "customer also deletes"
plan
ul_t_check "both deleted: no row" norow CLAUDE.md

nw
printf 'a\r\nb\r\n' > "$W_UP/crlf.txt"; ul_t_commit "$W_UP" "crlf" >/dev/null
printf 'a\nb\n' > "$W_CUST/crlf.txt"; cc "lf copy"
plan
ul_t_check "crlf: a line-ending-only difference is no row" norow crlf.txt

# the both-edited-identically case and the CRLF merge path
nw
upe CLAUDE.md '# Fixture project
same edit both sides'
cue CLAUDE.md '# Fixture project
same edit both sides'
plan
ul_t_check "same edit: both changed to the same content -> no row" norow CLAUDE.md

# ======================================================= 3. modes
nw
chmod +x "$W_UP/.claude/hooks/worktree-port-namespace.sh"; ul_t_commit "$W_UP" "exec bit" >/dev/null
plan
ul_t_check "mode: upstream flips the bit, customer untouched -> mode/apply" row_is .claude/hooks/worktree-port-namespace.sh mode apply
nw
chmod +x "$W_UP/.claude/hooks/worktree-port-namespace.sh"; ul_t_commit "$W_UP" "exec bit" >/dev/null
chmod +x "$W_CUST/.claude/hooks/worktree-port-namespace.sh"; cc "customer flips it too"
plan
ul_t_check "mode: both flipped the same way -> no row" norow .claude/hooks/worktree-port-namespace.sh
nw
chmod +x "$W_CUST/.claude/hooks/worktree-port-namespace.sh"; cc "customer flips it"
plan
ul_t_check "mode: only the customer flipped it -> keep/keep" row_is .claude/hooks/worktree-port-namespace.sh keep keep
nw
git -C "$W_UP" update-index --chmod=+x .claude/hooks/worktree-port-namespace.sh
git -C "$W_UP" commit -q -m "exec bit via index"
plan
ul_t_check "mode: an index-only mode flip is seen too" row_is .claude/hooks/worktree-port-namespace.sh mode apply

# ============================================================ 4. refusals
nw
echo 'more' >> "$W_CUST/CLAUDE.md"
run --plan
ST=$(ul_t_state)
ul_t_check "refuse dirty: exits 1" ul_t_eq "$RC" 1
ul_t_check "refuse dirty: result=aborted" ul_t_has "$OUT" '^result=aborted reason='
ul_t_check "refuse dirty: names the path" ul_t_has "$OUT" 'CLAUDE.md'
ul_t_check "refuse dirty: unchanged=yes" ul_t_has "$OUT" 'unchanged=yes$'
ul_t_check "refuse dirty: no plan.tsv written" absent "$ST/plan.tsv"
cg checkout -q -- CLAUDE.md
echo 'x' > "$W_CUST/plugins/untracked.sh"
run --plan
ul_t_check "refuse dirty: an untracked harness file refuses too" ul_t_has "$OUT" 'untracked.sh'
rm -f "$W_CUST/plugins/untracked.sh"
plan
ul_t_check "refuse dirty: clean again plans" ul_t_eq "$(kv result)" planned

nw
gd=$(cg rev-parse --absolute-git-dir)
mkdir -p "$gd/rebase-merge"
run --plan
ul_t_check "refuse in-progress: exits 1 with result=aborted" ul_t_has "$OUT" '^result=aborted reason='
ul_t_check "refuse in-progress: nothing written" absent "$(ul_t_state)/plan.tsv"
ul_t_check "refuse in-progress: names the unfinished operation" ul_t_has "$OUT" 'unfinished'
rmdir "$gd/rebase-merge"

nw
sd=$(ul_t_tmp)
git clone -q --depth 1 "file://$W_CUST" "$sd/shallow" 2>/dev/null
ul_t_git_config "$sd/shallow"
OUT=$(cd "$sd/shallow" && "$SH" "$sd/shallow/$S/update-loom.sh" --plan </dev/null 2>&1); RC=$?
ul_t_check "refuse shallow: exits 1" ul_t_eq "$RC" 1
ul_t_check "refuse shallow: reason says to unshallow" ul_t_has "$OUT" 'git fetch --unshallow first'
ul_t_check "refuse shallow: result=aborted unchanged=yes" ul_t_has "$OUT" '^result=aborted reason=.*unchanged=yes$'

nw
cue .claude/.logicloom-adopt-settings.json '{}'
run --plan
ul_t_check "refuse ambiguous: aborted without --channel" ul_t_has "$OUT" '^result=aborted reason='
ul_t_check "refuse ambiguous: says to pass --channel" ul_t_has "$OUT" '\-\-channel'
ul_t_check "refuse ambiguous: no plan.tsv" absent "$(ul_t_state)/plan.tsv"
run --channel template --plan
ST=$(ul_t_state)
ul_t_check "ambiguous + --channel template: plans" ul_t_eq "$(kv result)" planned
ul_t_check "ambiguous + --channel template: meta channel=template" ul_t_has "$(cat "$ST/meta")" '^channel=template$'
ul_t_check "ambiguous + --channel template: the template map is not applied" row_is .docs/guides/FIXTURE-2.md add apply
ul_t_check "ambiguous + --channel template: CLAUDE.md is not adopt-excluded" ul_t_ne "$(cls CLAUDE.md)" excluded

nw
plan
mkdir -p "$ST"
printf '%s\n' "$$" > "$ST/stage.lock"
run --plan
ul_t_check "refuse lock: a live stage.lock aborts" ul_t_has "$OUT" '^result=aborted reason=.*staging'
ul_t_check "refuse lock: names the pid" ul_t_has "$OUT" "$$"
ul_t_check "refuse lock: the existing plan is untouched" exists "$ST/plan.tsv"
printf '999999\n' > "$ST/stage.lock"
run --plan
ul_t_check "dead lock: a dead pid's lock is healed and the plan proceeds" ul_t_eq "$(kv result)" planned
ul_t_check "dead lock: the stale lock is gone" absent "$ST/stage.lock"

nw
plan
cp "$ST/plan.tsv" "$ST/plan.keep"
printf '%s\n' "$W_HEAD" > "$ST/staged"
run --plan
ul_t_check "refuse staged: aborted" ul_t_has "$OUT" '^result=aborted '
ul_t_check "refuse staged: exits 1" ul_t_eq "$RC" 1
ul_t_check "refuse staged: reason" ul_t_has "$OUT" 'reason=a staged update exists; run --finish or --abandon unchanged=yes'
ul_t_check "refuse staged: plan.tsv untouched" cmp -s "$ST/plan.tsv" "$ST/plan.keep"
ul_t_check "refuse staged: the staged file is left alone" exists "$ST/staged"

# ----------------------------------------------------------------- base ladder
nw
cg rm -q -f .sdd-sync-ref && cc "drop pointer"
run --plan
ul_t_check "base closest: refuses" ul_t_has "$OUT" '^result=aborted reason=base unconfirmed; run --set-base '
ul_t_check "base closest: prints the closest line" ul_t_has "$OUT" '^closest [0-9a-f]\{40\} [0-9][0-9]*$'
ul_t_check "base closest: unchanged=yes" ul_t_has "$OUT" 'unchanged=yes$'
ul_t_check "base closest: nothing planned" absent "$(ul_t_state)/plan.tsv"
run --set-base "$W_BASE"
plan
ul_t_check "base set: after --set-base the plan runs" ul_t_eq "$(kv result)" planned
ul_t_check "base set: base_rung=recorded" ul_t_has "$(cat "$ST/meta")" '^base_rung=recorded$'

nw
cg rm -q -f .sdd-sync-ref && cc "drop pointer"
eng=$(ul_t_tmp); cp "$W_CUST/$S/"*.sh "$eng/"
cg rm -r -q -f .logic-loom plugins .claude .docs features && cc "no harness files"
OUT=$(cd "$W_CUST" && "$SH" "$eng/update-loom.sh" --upstream-url "$W_UP" --i-am-pointing-at-a-fork --plan </dev/null 2>&1); RC=$?
ul_t_check "base none: refuses with the repair hint" ul_t_has "$OUT" 'see KNOWN_ISSUES.md or run npx logicloom@7 update-bootstrap'
ul_t_check "base none: result=aborted unchanged=yes" ul_t_has "$OUT" '^result=aborted reason=.*unchanged=yes$'

# ================================================= 5. uptodate
nw
printf '%s\n' "$W_HEAD" > "$W_CUST/.sdd-sync-ref"; cc "point at upstream head"
cg checkout -q "$W_HEAD" -- plugins/loom-maintenance/updates && cc "customer holds the notes already"
plan
ul_t_check "uptodate: base = upstream leaves only keep rows" ul_t_eq "$(awk -F'\t' '$2 != "keep"' "$ST/plan.tsv" | wc -l | tr -d ' ')" 0
ul_t_check "uptodate: uptodate=yes is printed" ul_t_eq "$(kv uptodate)" yes
ul_t_check "uptodate: keep rows are still counted" ul_t_has "$OUT" '^class.keep=[0-9]'

# ======================================== 6. the .gitignore exemption
nw
cue .gitignore 'plugins/'
upe plugins/other/x.txt 'upstream adds a file under an ignored tree'
plan
ul_t_check "ignore: an ignored path outside notes/scripts is dropped" norow plugins/other/x.txt
ul_t_check "ignore: a note path under an ignored tree is still classified" row_is "$N/fixture-doc-guidance.md" add apply upstream-owned
ul_t_check "ignore: the .gitignore itself is customer-only, no row" norow .gitignore
nw
cue .gitignore 'docs-ignored.md'
upe docs-ignored.md 'upstream adds an ignored file'
plan
ul_t_check "ignore: an ordinary ignored upstream-new path is dropped" norow docs-ignored.md

# ================================================ 7. adopted channel
RCPT='{"schema":"logicloom/adopt-receipt@1","runs":[{"status":"complete","only":["harness","hooks"]}]}'
adopt_world() { # [ONLY-JSON] : an adopted customer plus the upstream edits the cases read
  nw || return 1
  printf '%s\n' "${1:-$RCPT}" > "$W_CUST/.logicloom-adopt-receipt.json"
  cc "adopt receipt" || return 1
  upe lib/new.txt 'upstream adds a path outside the harness' || return 1
  upe CLAUDE.md '# Fixture project
changed upstream' || return 1
}
adopt_world
plan
ul_t_check "adopted: plans" ul_t_eq "$(kv result)" planned
ul_t_check "adopted: meta channel=adopted" ul_t_has "$(cat "$ST/meta")" '^channel=adopted$'
ul_t_check "adopted: a path with no harness group is adopter-owned/skip" row_is lib/new.txt adopter-owned skip "not harness-owned"
ul_t_check "adopted: CLAUDE.md is excluded/skip/adopt-excluded" row_is CLAUDE.md excluded skip adopt-excluded
ul_t_check "adopted: settings.json is posture/hold" row_is .claude/settings.json posture hold
ul_t_check "adopted: an installed-group hook is add/apply" row_is .claude/hooks/guard-dangerous-commands.sh add apply
ul_t_check "adopted: a harness guide merges cleanly" row_is .docs/guides/FIXTURE.md merged-clean apply
ul_t_check "adopted: notes are upstream-owned" row_is "$N/fixture-doc-guidance.md" add apply upstream-owned
ul_t_check "adopted: skip rows get no reviewer log" absent "$ST/reviewer/lib/new.txt.log"
ul_t_check "adopted: no base side without an adopt settings file" absent "$ST/adapt/base/.claude/settings.json"
ul_t_check "adopted: adapt row base is - for settings.json" ul_t_eq "$(awk -F'\t' '$1 == ".claude/settings.json" { print $3 }' "$ST/adapt.tsv")" "-"
ul_t_check "adopted: skip rows are counted" ul_t_has "$OUT" '^class.adopter-owned=1$'
ul_t_check "adopted: excluded rows are counted" ul_t_has "$OUT" '^class.excluded=1$'

adopt_world
cat > "$W_CUST/.claude/.logicloom-adopt-settings.json" <<'EOF'
{"adopt":"settings base side"}
EOF
cc "adopt settings"
plan
ul_t_check "adopt-settings: settings.json is posture/hold" row_is .claude/settings.json posture hold
ul_t_check "adopt-settings: the base side is the adopt settings file" contains "$ST/adapt/base/.claude/settings.json" "settings base side"
ul_t_check "adopt-settings: adapt row base is that file's blob" ul_t_eq "$(awk -F'\t' '$1 == ".claude/settings.json" { print $3 }' "$ST/adapt.tsv")" "$(cg rev-parse HEAD:.claude/.logicloom-adopt-settings.json)"
ul_t_check "adopt-settings: meta notes base_side=adopt-settings" ul_t_has "$(cat "$ST/meta")" '^base_side=adopt-settings$'
ul_t_check "adopt-settings: theirs is upstream's settings" contains "$ST/adapt/theirs/.claude/settings.json" "guard-dangerous-commands"

adopt_world '{"schema":"logicloom/adopt-receipt@1","runs":[{"status":"complete","only":["harness"]}]}'
plan
ul_t_check "group: a hooks path with only harness installed is adopter-owned" row_is .claude/hooks/guard-dangerous-commands.sh adopter-owned skip "group hooks not installed"
ul_t_check "group: a harness path is still planned" row_is .docs/guides/FIXTURE-2.md add apply
adopt_world '{"schema":"logicloom/adopt-receipt@1","runs":[{"status":"complete","only":["hooks"]}]}'
plan
ul_t_check "group: with only hooks installed a harness guide is adopter-owned" row_is .docs/guides/FIXTURE-2.md adopter-owned skip "group harness not installed"
ul_t_check "group: ... and the hook is planned" row_is .claude/hooks/guard-dangerous-commands.sh add apply

adopt_world
# a path that is excluded wins over the group test, even inside a harness prefix
upe .logic-loom/config/update-channels.conf "$(git -C "$W_UP" show HEAD:.logic-loom/config/update-channels.conf)
adopt-exclude = .docs/guides/FIXTURE-2.md"
plan
ul_t_check "adopted: adopt-exclude inside a harness prefix is excluded" row_is .docs/guides/FIXTURE-2.md excluded skip adopt-excluded
ul_t_check "adopted: lib/ new path is still adopter-owned" ul_t_eq "$(cls lib/new.txt)" adopter-owned

adopt_world
cue app/main.js 'the adopter product'
cue web/own.js 'the adopter web'
plan
ul_t_check "local-only: an adopter's own file is never listed" norow app/main.js
ul_t_check "local-only: ... nor its web code" norow web/own.js
ul_t_check "local-only: ... nor the receipt" norow .logicloom-adopt-receipt.json

# a both-added path inside a harness prefix is held, never overwritten
adopt_world
cue .docs/guides/FIXTURE-2.md 'the adopter already has a guide of this name'
plan
ul_t_check "adopted: both-added path inside a harness prefix -> add-conflict/hold" row_is .docs/guides/FIXTURE-2.md add-conflict hold

# a merge path is held in an adopted channel even when only upstream changed it
adopt_world
upe .gitignore 'node_modules/'
plan
ul_t_check "adopted: a merge path changed upstream only is posture/hold" row_is .gitignore posture hold
nw
upe .gitignore 'node_modules/'
plan
ul_t_check "template: the merge list is ignored, so .gitignore is a plain add" row_is .gitignore add apply

# renames
adopt_world
upe AGENTS.md '# upstream agents file'
plan
ul_t_check "rename: an upstream AGENTS.md is addressed at the adopted path" row_is .logic-loom/AGENTS.md add apply
ul_t_check "rename: ... and no row is left at the source path" norow AGENTS.md
ul_t_check "rename: the reviewer log is named for the adopted path" exists "$ST/reviewer/.logic-loom/AGENTS.md.log"
ul_t_check "rename: the log reads upstream's history for the source path" grep -q 'edit AGENTS.md' "$ST/reviewer/.logic-loom/AGENTS.md.log"
cue .logic-loom/AGENTS.md '# upstream agents file'
run --plan
ul_t_check "rename: an identical adopted copy is no row" norow .logic-loom/AGENTS.md
cue .logic-loom/AGENTS.md '# the adopter changed it'
run --plan
ul_t_check "rename: a different adopted copy is add-conflict/hold at the adopted path" row_is .logic-loom/AGENTS.md add-conflict hold
ul_t_check "rename: mine is read from the adopted path" contains "$ST/adapt/mine/.logic-loom/AGENTS.md" "the adopter changed it"
ul_t_check "rename: theirs is read from the source path" contains "$ST/adapt/theirs/.logic-loom/AGENTS.md" "upstream agents file"
adopt_world
upe AGENTS.md '# upstream agents file'
cue AGENTS.md '# the adopter has their own root agents file'
plan
ul_t_check "rename: the adopter's own root AGENTS.md is not the rename source" row_is .logic-loom/AGENTS.md add apply
nw
upe AGENTS.md '# upstream agents file'
plan
ul_t_check "rename: the template channel does not rename" row_is AGENTS.md add apply

# ============================================ 8. helpers keep their shape
nw
plan
sorted_plan() { cut -f1 "$ST/plan.tsv" | LC_ALL=C sort -c; }
ul_t_check "plan.tsv: sorted by path" sorted_plan
ul_t_check "plan.tsv: classes are in the closed vocabulary" ul_t_eq "$(awk -F'\t' '$2 !~ /^(take|delete|add|add-conflict|keep|deleted-upstream-kept|posture|conflict|merged-clean|mode|two-way|adopter-owned|excluded)$/' "$ST/plan.tsv" | wc -l | tr -d ' ')" 0
ul_t_check "plan.tsv: proposals are in the closed vocabulary" ul_t_eq "$(awk -F'\t' '$3 !~ /^(apply|hold|keep|skip)$/' "$ST/plan.tsv" | wc -l | tr -d ' ')" 0
ul_t_check "plan: --help names --plan as built" ul_t_hasnt "$(sh "$ENG_SRC" --help 2>&1)" 'not built yet) classify'

ul_t_done
