#!/bin/sh
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib.sh"

d=$(ul_t_tmp) || exit 1
ul_t_world "$d" || exit 1
ul_t_run_engine --plan
st=$(ul_t_state)
ul_t_check 'plan succeeds' ul_t_eq "$RC" 0
ul_t_check 'settings held as posture' ul_t_eq "$(ul_t_plan_class .claude/settings.json)" posture
ul_t_check 'settings proposal held' ul_t_eq "$(ul_t_plan_field .claude/settings.json 3)" hold
ul_t_check 'guide clean-merges' ul_t_eq "$(ul_t_plan_class .docs/guides/FIXTURE.md)" merged-clean
ul_t_check 'merge retains customer text' grep -q 'extended by the customer' "$st/merged/.docs/guides/FIXTURE.md"
ul_t_check 'merge retains upstream text' grep -q 'plain sentence' "$st/merged/.docs/guides/FIXTURE.md"
ul_t_check 'new hook added' ul_t_eq "$(ul_t_plan_class .claude/hooks/guard-dangerous-commands.sh)" add
ul_t_check 'new guide added' ul_t_eq "$(ul_t_plan_class .docs/guides/FIXTURE-2.md)" add
ul_t_check 'customer-only amendment absent' ul_t_not grep -q '^\.logic-loom/memory/amendments.md' "$st/plan.tsv"
ul_t_check 'notes upstream-owned' awk -F '\t' '$1 ~ /^plugins\/loom-maintenance\/updates\// && $4 == "upstream-owned" { n++ } END { exit !(n >= 6) }' "$st/plan.tsv"
ul_t_check 'meta records base rung' grep -qx "base_rung=recorded" "$st/meta"
ul_t_check 'meta update id shape' awk -F= '$1=="update_id" { exit !($2 ~ /^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{12}$/) }' "$st/meta"
ul_t_check 'export exists' test -f "$st/export/.docs/guides/FIXTURE.md"
ul_t_check 'reviewer log has upstream subject' grep -q 'head' "$st/reviewer/.docs/guides/FIXTURE.md.log"
cp "$st/plan.tsv" "$d/first.tsv"
ul_t_run_engine --plan
ul_t_check 'second plan succeeds' ul_t_eq "$RC" 0
ul_t_check 'plan is idempotent' cmp "$d/first.tsv" "$st/plan.tsv"

d2=$(ul_t_tmp) || exit 1
ul_t_world "$d2" || exit 1
git -C "$W_CUST" rm -q .docs/guides/FIXTURE.md && ul_t_commit "$W_CUST" delete >/dev/null
ul_t_run_engine --plan
ul_t_check 'local delete conflicts with upstream edit' ul_t_eq "$(ul_t_plan_class .docs/guides/FIXTURE.md)" conflict

d3=$(ul_t_tmp) || exit 1
ul_t_world "$d3" || exit 1
printf '\ncustomer engine edit\n' >> "$W_CUST/plugins/loom-maintenance/scripts/update-loom.sh"
ul_t_commit "$W_CUST" engine-edit >/dev/null
ul_t_run_engine --plan
ul_t_check 'engine remains upstream-owned' ul_t_eq "$(ul_t_plan_class plugins/loom-maintenance/scripts/update-loom.sh)" take

d4=$(ul_t_tmp) || exit 1
ul_t_world "$d4" || exit 1
printf 'dirty\n' >> "$W_CUST/.docs/guides/FIXTURE.md"
ul_t_run_engine --plan
ul_t_check 'dirty tree aborts' ul_t_has "$OUT" 'result=aborted reason=.*FIXTURE.md'

d5=$(ul_t_tmp) || exit 1
ul_t_world "$d5" || exit 1
ul_t_run_engine --selftest-two-way .docs/guides/FIXTURE.md
st=$(ul_t_state)
ul_t_check 'two-way helper writes row' grep -q "$(printf '^.docs/guides/FIXTURE.md\ttwo-way\thold\t')" "$st/plan.tsv"
ul_t_check 'two-way helper writes absent base marker' grep -qx - "$st/adapt/base/.docs/guides/FIXTURE.md"
ul_t_check 'two-way helper saves theirs' test -s "$st/adapt/theirs/.docs/guides/FIXTURE.md"
ul_t_check 'two-way helper saves mine' test -s "$st/adapt/mine/.docs/guides/FIXTURE.md"

ul_t_done
