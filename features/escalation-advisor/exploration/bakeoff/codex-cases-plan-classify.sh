#!/bin/sh
# Contract cases for --plan's path universe, three-way classifier and read-only
# plan artefacts. Notes are deliberately not interpreted in this package.
set -u

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib.sh"

TAB=$(printf '\t')
kv() { printf '%s\n' "$OUT" | sed -n "s/^$1=//p" | head -1; }
cg() { git -C "$W_CUST" "$@"; }
ug() { git -C "$W_UP" "$@"; }
commit_customer() { ul_t_commit "$W_CUST" "$1" >/dev/null; }
commit_upstream() { W_HEAD=$(ul_t_commit "$W_UP" "$1") || return 1; }
nw() {
  pc_d=$(ul_t_tmp) || return 1
  ul_t_world "$pc_d" || return 1
}
run() { ul_t_run_engine "$@"; }
row_is() { [ "$(ul_t_plan_field "$1" 2)" = "$2" ] && [ "$(ul_t_plan_field "$1" 3)" = "$3" ]; }
row_detail() { ul_t_plan_field "$1" 4; }
no_row() { [ -z "$(ul_t_plan_class "$1")" ]; }
dash_n() { [ ! -x /bin/dash ] || /bin/dash -n "$1"; }
no_writable_files() { [ -z "$(find "$1" -type f -perm +222 -print -quit)" ]; }
cannot_touch() { ! touch "$1" 2>/dev/null; }

# Tests are syntax-checked by both supported interpreters.
ul_t_check "plan case passes sh -n" sh -n "$here/cases-plan-classify.sh"
ul_t_check "plan case passes dash -n" dash_n "$here/cases-plan-classify.sh"

# ------------------------------------------------------------- default world
nw || ul_t_done
# Make the bundle visibly differ so the upstream-owned override itself is covered.
rm -f "$W_CUST/plugins/loom-maintenance/updates/BUNDLE.sha256"
commit_customer "customer lacks updater bundle"
CUSTOMER_HEAD=$(cg rev-parse HEAD)
run --plan
STATE=$(ul_t_state)
ul_t_check "plan: default run succeeds" ul_t_eq "$RC" 0
ul_t_check "plan: settings is posture/hold" row_is .claude/settings.json posture hold
ul_t_check "plan: guide clean-merges" row_is .docs/guides/FIXTURE.md merged-clean apply
ul_t_check "plan: merged guide keeps customer appendix" grep -Fq 'extended by the customer' "$STATE/merged/.docs/guides/FIXTURE.md"
ul_t_check "plan: merged guide takes upstream sentence" grep -Fq 'Run /update-loom to take improvements.' "$STATE/merged/.docs/guides/FIXTURE.md"
ul_t_check "plan: hook is add/apply" row_is .claude/hooks/guard-dangerous-commands.sh add apply
ul_t_check "plan: follow-up guide is add/apply" row_is .docs/guides/FIXTURE-2.md add apply
for p in \
  plugins/loom-maintenance/updates/7.0.0/amendments-ladder-plus-three.md \
  plugins/loom-maintenance/updates/7.0.0/fixture-doc-followup.md \
  plugins/loom-maintenance/updates/7.0.0/fixture-doc-guidance.md \
  plugins/loom-maintenance/updates/7.0.0/hooks-guard-dangerous.md \
  plugins/loom-maintenance/updates/7.0.0/settings-ask-restore.md; do
  ul_t_check "plan: $p is upstream-owned add/apply" row_is "$p" add apply
  ul_t_check "plan: $p says upstream-owned" ul_t_eq "$(row_detail "$p")" upstream-owned
done
ul_t_check "plan: BUNDLE follows upstream" row_is plugins/loom-maintenance/updates/BUNDLE.sha256 add apply
ul_t_check "plan: BUNDLE says upstream-owned" ul_t_eq "$(row_detail plugins/loom-maintenance/updates/BUNDLE.sha256)" upstream-owned
ul_t_check "plan: customer-only amendments has no row" no_row .logic-loom/memory/amendments.md
ul_t_check "plan: meta base" grep -Fxq "base=$W_BASE" "$STATE/meta"
ul_t_check "plan: meta base rung" grep -Fxq 'base_rung=recorded' "$STATE/meta"
ul_t_check "plan: meta upstream" grep -Fxq "upstream=$W_HEAD" "$STATE/meta"
ul_t_check "plan: meta head" grep -Fxq "head=$CUSTOMER_HEAD" "$STATE/meta"
ul_t_check "plan: meta channel" grep -Fxq 'channel=template' "$STATE/meta"
UPDATE_ID=$(sed -n 's/^update_id=//p' "$STATE/meta")
ul_t_check "plan: update id shape" expr "$UPDATE_ID" : '[0-9][0-9]*T[0-9][0-9]*Z-[0-9a-f][0-9a-f]*$' >/dev/null
ul_t_check "plan: export exists" test -f "$STATE/export/.docs/guides/FIXTURE.md"
ul_t_check "plan: export files have no write bits" no_writable_files "$STATE/export"
ul_t_check "plan: export refuses a new touched file" cannot_touch "$STATE/export/write-probe"
ul_t_check "plan: upstream JSON tools were saved" ul_t_eq "$(kv tools)" saved
ul_t_check "plan: stdout names plan.tsv" ul_t_eq "$(kv plan)" "$STATE/plan.tsv"
ul_t_check "plan: stdout reports rows" test "$(kv rows)" -gt 0
ul_t_check "plan: stdout reports posture count" ul_t_has "$OUT" '^class.posture='
ul_t_check "plan: held settings base side exists" test -f "$STATE/adapt/base/.claude/settings.json"
ul_t_check "plan: held settings upstream side exists" test -f "$STATE/adapt/theirs/.claude/settings.json"
ul_t_check "plan: held settings local side exists" test -f "$STATE/adapt/mine/.claude/settings.json"
ul_t_check "plan: held settings base-upstream diff exists" test -f "$STATE/diffs/.claude/settings.json.base-upstream.diff"
ul_t_check "plan: held settings base-local diff exists" test -f "$STATE/diffs/.claude/settings.json.base-local.diff"
ul_t_check "plan: reviewer log names upstream subject" grep -Fq 'head' "$STATE/reviewer/.docs/guides/FIXTURE.md.log"
cp "$STATE/plan.tsv" "$pc_d/first-plan.tsv"
run --plan
ul_t_check "plan: second run succeeds" ul_t_eq "$RC" 0
ul_t_check "plan: plan.tsv is idempotent" cmp -s "$pc_d/first-plan.tsv" "$STATE/plan.tsv"
run --selftest-two-way .claude/policies/tool-restrictions.json
ul_t_check "two-way helper: writes class and hold" row_is .claude/policies/tool-restrictions.json two-way hold
ul_t_check "two-way helper: records a dash base" awk -F '\t' -v p=.claude/policies/tool-restrictions.json '$1 == p && $3 == "-" { ok=1 } END { exit !ok }' "$STATE/adapt.tsv"

# --------------------------------------------------------- conflict variants
nw
rm -f "$W_CUST/.docs/guides/FIXTURE.md"; commit_customer "delete guide"
run --plan
ul_t_check "plan: locally deleted/upstream changed is conflict/hold" row_is .docs/guides/FIXTURE.md conflict hold

nw
awk '{ if ($0 == "To update, run the update command and accept the files it lists.") print "The customer rewrote this same paragraph."; else print }' "$W_CUST/.docs/guides/FIXTURE.md" > "$pc_d/guide"
mv "$pc_d/guide" "$W_CUST/.docs/guides/FIXTURE.md"; commit_customer "rewrite guide paragraph"
run --plan; STATE=$(ul_t_state)
ul_t_check "plan: overlapping prose edit is conflict/hold" row_is .docs/guides/FIXTURE.md conflict hold
ul_t_check "plan: conflict has base-upstream diff" test -f "$STATE/diffs/.docs/guides/FIXTURE.md.base-upstream.diff"
ul_t_check "plan: conflict has base-local diff" test -f "$STATE/diffs/.docs/guides/FIXTURE.md.base-local.diff"

nw
printf '\n# customer edit\n' >> "$W_CUST/plugins/loom-maintenance/scripts/update-loom.sh"; commit_customer "edit engine"
ENGINE=$W_CUST/plugins/loom-maintenance/scripts/update-loom.sh
run --plan
ul_t_check "plan: edited engine is still take/apply" row_is plugins/loom-maintenance/scripts/update-loom.sh take apply
ul_t_check "plan: edited engine is upstream-owned" ul_t_eq "$(row_detail plugins/loom-maintenance/scripts/update-loom.sh)" upstream-owned

nw
printf 'console.log("upstream changed product");\n' > "$W_UP/web/app.js"; commit_upstream "upstream product collision"
run --plan
ul_t_check "plan: changed product path is excluded/skip" row_is web/app.js excluded skip
ul_t_check "plan: product row says forbidden" ul_t_eq "$(row_detail web/app.js)" forbidden

# --------------------------------------------------------------- file modes
nw
chmod +x "$W_UP/.claude/hooks/worktree-port-namespace.sh"
ug update-index --chmod=+x .claude/hooks/worktree-port-namespace.sh
ug commit -q -m "make namespace hook executable"; W_HEAD=$(ug rev-parse HEAD)
run --plan
ul_t_check "plan: upstream-only mode change applies" row_is .claude/hooks/worktree-port-namespace.sh mode apply

nw
chmod +x "$W_CUST/.claude/hooks/worktree-port-namespace.sh"
cg update-index --chmod=+x .claude/hooks/worktree-port-namespace.sh
cg commit -q -m "make namespace hook executable"
chmod +x "$W_UP/.claude/hooks/worktree-port-namespace.sh"
ug update-index --chmod=+x .claude/hooks/worktree-port-namespace.sh
ug commit -q -m "make namespace hook executable"; W_HEAD=$(ug rev-parse HEAD)
run --plan
ul_t_check "plan: matching mode changes make no row" no_row .claude/hooks/worktree-port-namespace.sh

nw
chmod +x "$W_CUST/.claude/hooks/worktree-port-namespace.sh"
cg update-index --chmod=+x .claude/hooks/worktree-port-namespace.sh
cg commit -q -m "local executable hook"
run --plan
ul_t_check "plan: local-only mode change is keep" row_is .claude/hooks/worktree-port-namespace.sh keep keep

nw
printf 'git.push = silent\n' >> "$W_CUST/.logic-loom/config/gate-policy.conf"; commit_customer "customer gate posture"
printf 'git.restore = ask\n' >> "$W_UP/.logic-loom/config/gate-policy.conf"; commit_upstream "upstream gate posture"
run --plan
ul_t_check "plan: both-changed posture file is held" row_is .logic-loom/config/gate-policy.conf posture hold

# One world covers the remaining content branches without hiding one behind another.
nw
printf '\ncustomer governance note\n' >> "$W_CUST/.logic-loom/config/governance.conf"
printf '\ncustomer project convention\n' >> "$W_CUST/CLAUDE.md"
printf 'customer collision\n' > "$W_CUST/.docs/guides/COLLIDE.md"
commit_customer "classification matrix customer sides"
rm -f "$W_UP/CLAUDE.md" "$W_UP/plugins/loom-maintenance/updates/BUNDLE.sha256" \
  "$W_UP/plugins/loom-maintenance/scripts/json-valid.sh" "$W_UP/plugins/loom-maintenance/scripts/json-flat.sh"
printf 'upstream collision\n' > "$W_UP/.docs/guides/COLLIDE.md"
commit_upstream "classification matrix upstream sides"
run --plan
ul_t_check "plan: local-only content change is keep" row_is .logic-loom/config/governance.conf keep keep
ul_t_check "plan: upstream deletion plus local edit is held" row_is CLAUDE.md deleted-upstream-kept hold
ul_t_check "plan: differently added files are held" row_is .docs/guides/COLLIDE.md add-conflict hold
ul_t_check "plan: updater-owned upstream deletion applies" row_is plugins/loom-maintenance/updates/BUNDLE.sha256 delete apply
ul_t_check "plan: missing upstream JSON tools are reported" ul_t_eq "$(kv tools)" absent
ul_t_check "plan: an unchanged file has no row" no_row .claude/policies/tool-restrictions.json

# --------------------------------------------------------------- refusals
nw
printf x >> "$W_CUST/.docs/guides/FIXTURE.md"
run --plan
ul_t_check "plan: dirty tree aborts" ul_t_hasline "$OUT" "result=aborted reason=working tree has uncommitted changes:  M .docs/guides/FIXTURE.md unchanged=yes"

nw
gd=$(cg rev-parse --absolute-git-dir); printf x > "$gd/MERGE_HEAD"
run --plan
ul_t_check "plan: in-progress operation aborts" ul_t_has "$OUT" 'reason=a merge, rebase, cherry-pick or revert is in progress'
rm -f "$gd/MERGE_HEAD"

nw
gd=$(cg rev-parse --absolute-git-dir); mkdir -p "$gd/loom/update"; printf '%s\n' deadbeef > "$gd/loom/update/staged"
run --plan
ul_t_check "plan: staged update aborts" ul_t_has "$OUT" 'reason=a staged update exists; run --finish or --abandon'

nw
gd=$(cg rev-parse --absolute-git-dir); mkdir -p "$gd/loom/update"; printf '%s\n' $$ > "$gd/loom/update/stage.lock"
run --plan
ul_t_check "plan: live stage lock aborts" ul_t_has "$OUT" 'reason=stage.lock is held by live pid'
rm -f "$gd/loom/update/stage.lock"

nw
SHALLOW=$pc_d/shallow
git clone -q --depth=1 "file://$W_CUST" "$SHALLOW"
W_CUST=$SHALLOW
ENGINE=$W_CUST/plugins/loom-maintenance/scripts/update-loom.sh
run --plan
ul_t_check "plan: shallow clone aborts" ul_t_has "$OUT" 'reason=run git fetch --unshallow first'

nw
rm -f "$W_CUST/.sdd-sync-ref"; commit_customer "drop base pointer"
run --plan
ul_t_check "plan: closest base is refused" ul_t_has "$OUT" '^closest '
ul_t_check "plan: closest refusal requires set-base" ul_t_has "$OUT" 'reason=base unconfirmed; run --set-base '

nw
mkdir -p "$W_CUST/.claude/rules"; printf x > "$W_CUST/.claude/rules/logicloom-fingerprint.md"
run --plan
ul_t_check "plan: ambiguous channel aborts without override" ul_t_has "$OUT" 'reason=channel is ambiguous; rerun with --channel template or --channel adopted'
run --channel template --plan
ul_t_check "plan: channel override proceeds" ul_t_eq "$RC" 0

# -------------------------------------------------------- adopted channel map
nw
printf '%s\n' '{"schema":"logicloom/adopt-receipt@1","runs":[{"status":"complete","only":["harness","hooks"]}]}' > "$W_CUST/.logicloom-adopt-receipt.json"
mkdir -p "$W_CUST/.claude"
cp "$W_CUST/.claude/settings.json" "$W_CUST/.claude/.logicloom-adopt-settings.json"
printf 'customer adopted agents\n' > "$W_CUST/.logic-loom/AGENTS.md"
commit_customer "record adopted install"
mkdir -p "$W_UP/lib"; printf 'upstream library\n' > "$W_UP/lib/new.txt"
printf '\nUpstream template-only change.\n' >> "$W_UP/CLAUDE.md"
printf 'upstream root agents\n' > "$W_UP/AGENTS.md"
commit_upstream "adopted channel additions"
run --plan; STATE=$(ul_t_state)
ul_t_check "plan: adopted non-harness path is adopter-owned" row_is lib/new.txt adopter-owned skip
ul_t_check "plan: adopted template-only file is excluded" row_is CLAUDE.md excluded skip
ul_t_check "plan: adopted exclude detail" ul_t_eq "$(row_detail CLAUDE.md)" adopt-excluded
ul_t_check "plan: adopted settings stays posture/hold" row_is .claude/settings.json posture hold
ul_t_check "plan: adopted settings uses insertion as base" cmp -s "$W_CUST/.claude/.logicloom-adopt-settings.json" "$STATE/adapt/base/.claude/settings.json"
ul_t_check "plan: rename source is re-addressed to adopted target" row_is .logic-loom/AGENTS.md add-conflict hold
ul_t_check "plan: rename source itself is not emitted" no_row AGENTS.md

nw
printf '%s\n' '{"schema":"logicloom/adopt-receipt@1","runs":[{"status":"complete","only":["harness","hooks"]}]}' > "$W_CUST/.logicloom-adopt-receipt.json"
printf 'plugins/\n' > "$W_CUST/.gitignore"; commit_customer "ignore plugins locally"
mkdir -p "$W_UP/plugins/loom-maintenance/updates/7.0.0"
printf '%s\n' 'upstream note despite ignore' > "$W_UP/plugins/loom-maintenance/updates/7.0.0/ignored.md"; commit_upstream "add ignored note"
run --plan
ul_t_check "plan: updater notes bypass customer gitignore" row_is plugins/loom-maintenance/updates/7.0.0/ignored.md add apply

ul_t_done
