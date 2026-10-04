#!/bin/sh
# Cases for plugins/loom-maintenance/scripts/update-loom-common.sh (the shared
# POSIX library) and for the test harness in tests/update-loom/lib.sh (fixture
# world builder). POSIX sh. Prints PASS/FAIL lines; exit status is the result.
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib.sh"

lib_dir="$UL_T_ROOT/plugins/loom-maintenance/scripts"
lib="$lib_dir/update-loom-common.sh"
notes="$UL_T_FIX/notes/7.0.0"

# ---------------------------------------------------------------- the library
ul_t_check "common: the library file exists" test -f "$lib"
ul_t_check "common: the library parses under sh -n" sh -n "$lib"
if [ -x /bin/dash ]; then
  ul_t_check "common: the library parses under dash -n" /bin/dash -n "$lib"
fi
out=$("$SH" "$lib" 2>&1); rc=$?
ul_t_check "common: executing the library directly is refused (exit 2)" test "$rc" = 2
ul_t_check "common: executing the library says it is sourced, not run" ul_t_has "$out" "sourced, not run"

# Source it the way the engine does: `here` names the directory holding it.
here=$lib_dir
unset UPDATE_TOOLS
. "$here/update-loom-common.sh"
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# ------------------------------------------------------------ exported names
ul_t_check "UL_NOTES_DIR" ul_t_eq "$UL_NOTES_DIR" "plugins/loom-maintenance/updates"
ul_t_check "UL_SCRIPTS_DIR" ul_t_eq "$UL_SCRIPTS_DIR" "plugins/loom-maintenance/scripts"
ul_t_check "UL_BUNDLE" ul_t_eq "$UL_BUNDLE" "plugins/loom-maintenance/updates/BUNDLE.sha256"
ul_t_check "UL_LEDGER" ul_t_eq "$UL_LEDGER" ".logic-loom/memory/update-ledger.tsv"
ul_t_check "UL_APPLIED_DIR" ul_t_eq "$UL_APPLIED_DIR" ".logic-loom/memory/updates"
ul_t_check "UL_SYNC_REF" ul_t_eq "$UL_SYNC_REF" ".sdd-sync-ref"
ul_t_check "UL_UPSTREAM_REF" ul_t_eq "$UL_UPSTREAM_REF" "refs/loom-upstream/main"
ul_t_check "UL_UPSTREAM_CONF" ul_t_eq "$UL_UPSTREAM_CONF" ".logic-loom/config/framework-upstream.conf"
ul_t_check "UL_CHANNEL_MAP" ul_t_eq "$UL_CHANNEL_MAP" ".logic-loom/config/update-channels.conf"
ul_t_check "UL_DEFAULT_UPSTREAM_URL" ul_t_eq "$UL_DEFAULT_UPSTREAM_URL" "https://github.com/kelleysd-apps/LogicLoom.git"
ul_t_check "UL_FORBIDDEN_TREES" ul_t_eq "$UL_FORBIDDEN_TREES" "web apps .brain features specs"

# ---------------------------------------------------------- forbidden-touch
for p in web/x web/a/b.js apps/a/b node_modules/x node_modules/pkg/index.js .brain/wiki/x.md .brain/raw/clippings/y.md \
         features/foo/plan.md features/foo/sprints/01/x.md specs/001/spec.md \
         .logic-loom/memory/update-ledger.tsv .logic-loom/memory/updates/x.applied; do
  ul_t_check "forbidden: $p" ul_path_forbidden "$p"
done
for p in features/README.md features/.gitkeep specs/README.md specs/.gitkeep .brain/README.md \
         .logic-loom/config/x .logic-loom/memory/amendments.md .logic-loom/memory/constitution.md \
         .docs/guides/x.md CLAUDE.md webhooks/x.md appsettings.json; do
  ul_t_check "not forbidden: $p" ul_t_not ul_path_forbidden "$p"
done
ul_t_check "forbidden: a leading ./ is normalised" ul_path_forbidden "./web/x"
# Only README.md and .gitkeep ship directly under features/ and specs/
# (payload-manifest.txt include: rows); any other direct child is the
# customer's own file, so it is forbidden too, not just the subdirectories.
for p in features/notes.md features/foo specs/draft.md specs/001 features/.DS_Store; do
  ul_t_check "forbidden: $p (a direct child that is not README.md or .gitkeep)" ul_path_forbidden "$p"
done

# ---------------------------------------------------------------- protected
for p in .claude/hooks/x.sh .claude/hooks .claude/settings.json .claude/settings.local.json \
         .logic-loom/config/governance.conf .logic-loom/config/gate-policy.conf \
         .logic-loom/memory/constitution.md .logic-loom/lib/governance-verdicts.sh .logic-loom/lib/policy.sh \
         plugins/loom-governance/hooks/scripts/a.sh plugins/loom-governance/.claude-plugin/plugin.json; do
  ul_t_check "protected: $p" ul_path_protected "$p"
done
for p in .claude/agents/x.md .claude/commands/x.md .claude/hooksy/x .claude/settings.jsonx \
         plugins/loom-governance/commands/x.md .logic-loom/config/project.conf; do
  ul_t_check "not protected: $p" ul_t_not ul_path_protected "$p"
done

# ------------------------------------------------- posture / security surface
for p in .logic-loom/config/gate-policy.conf .logic-loom/config/governance.conf \
         .logic-loom/config/project.conf .logic-loom/config/environments.conf; do
  ul_t_check "posture: $p" ul_path_posture "$p"
done
ul_t_check "not posture: .claude/settings.json" ul_t_not ul_path_posture ".claude/settings.json"
ul_t_check "not posture: .logic-loom/config/update-channels.conf" ul_t_not ul_path_posture ".logic-loom/config/update-channels.conf"
for p in .claude/settings.json .claude/policies/tool-restrictions.json \
         .logic-loom/config/gate-policy.conf .logic-loom/config/governance.conf; do
  ul_t_check "security surface: $p" ul_path_security_surface "$p"
done
ul_t_check "not security surface: .logic-loom/config/project.conf" ul_t_not ul_path_security_surface ".logic-loom/config/project.conf"
ul_t_check "not security surface: CLAUDE.md" ul_t_not ul_path_security_surface "CLAUDE.md"

# The protected tokens mirror the governance verdict library (read, never edited).
verdicts="$UL_T_ROOT/.logic-loom/lib/governance-verdicts.sh"
if [ -f "$verdicts" ]; then
  want=$(sed -n '/^loom_protected_path_tokens()/,/^  if \[/p' "$verdicts" | grep -oE "'[^']+'" | tr -d "'" | grep -v '%s' | sort)
  got=$(printf '%s\n' $UL_PROTECTED_TOKENS | sort)
  ul_t_check "UL_PROTECTED_TOKENS equals the verdict library's floor tokens" test "$want" = "$got" -a -n "$want"
fi

# ------------------------------------------------------- project-data allowlist
ul_t_check "project-data: amendments.md" ul_project_data_allowed ".logic-loom/memory/amendments.md"
ul_t_check "project-data: .claude/rules/mine.md" ul_project_data_allowed ".claude/rules/mine.md"
ul_t_check "project-data: not logicloom-governance rule" ul_t_not ul_project_data_allowed ".claude/rules/logicloom-governance.md"
ul_t_check "project-data: not gate-policy.conf" ul_t_not ul_project_data_allowed ".logic-loom/config/gate-policy.conf"
ul_t_check "project-data: not project.conf" ul_t_not ul_project_data_allowed ".logic-loom/config/project.conf"
ul_t_check "project-data: not environments.conf" ul_t_not ul_project_data_allowed ".logic-loom/config/environments.conf"
ul_t_check "project-data: not a rule that is not markdown" ul_t_not ul_project_data_allowed ".claude/rules/mine.txt"
ul_t_check "project-data: not CLAUDE.md" ul_t_not ul_project_data_allowed "CLAUDE.md"
# A shipped logicloom-* rule is denied wherever it sits under .claude/rules/;
# the test is the file's own name, so a customer's my-logicloom-notes.md stays theirs.
ul_t_check "project-data: not a nested logicloom- rule" ul_t_not ul_project_data_allowed ".claude/rules/sub/logicloom-x.md"
ul_t_check "project-data: a nested customer rule is allowed" ul_project_data_allowed ".claude/rules/sub/mine.md"
ul_t_check "project-data: a customer rule whose name merely contains logicloom- is allowed" ul_project_data_allowed ".claude/rules/my-logicloom-notes.md"

# ------------------------------------------------------------- ul_touch_split
tab=$(printf '\t')
ul_t_check "touch-split: @template suffix" ul_t_eq "$(ul_touch_split 'CLAUDE.md @template')" "CLAUDE.md${tab}@template"
ul_t_check "touch-split: @adopted suffix" ul_t_eq "$(ul_touch_split '.docs/x.md @adopted')" ".docs/x.md${tab}@adopted"
ul_t_check "touch-split: explicit @both" ul_t_eq "$(ul_touch_split '.docs/x.md @both')" ".docs/x.md${tab}@both"
ul_t_check "touch-split: no suffix means @both" ul_t_eq "$(ul_touch_split '.docs/x.md')" ".docs/x.md${tab}@both"
ul_t_check "touch-split: an unknown suffix is not a channel" ul_t_eq "$(ul_touch_split '.docs/x.md @bogus')" ".docs/x.md @bogus${tab}@both"

# ---------------------------------------------------------------- frontmatter
for id in hooks-guard-dangerous fixture-doc-guidance fixture-doc-followup amendments-ladder-plus-three settings-ask-restore; do
  ul_t_check "note $id: file exists" test -f "$notes/$id.md"
  fm=$(ul_frontmatter "$notes/$id.md")
  ul_t_check "note $id: frontmatter id equals the file name" ul_t_eq "$(ul_fm_scalar "$fm" id)" "$id"
  ul_t_check "note $id: has a check key naming its file" ul_t_eq "$(ul_fm_scalar "$fm" check)" "$id.check.sh"
  ul_t_check "note $id: check file exists" test -f "$notes/$id.check.sh"
  ul_t_check "note $id: check file parses under sh -n" sh -n "$notes/$id.check.sh"
  ul_t_check "note $id: has every required key" sh -c '
    fm=$1; shift
    for k in id title purpose touches adds requires safety done-when check project-data; do
      printf "%s\n" "$fm" | grep -q "^$k:" || exit 1
    done' sh "$fm"
done
fm=$(ul_frontmatter "$notes/hooks-guard-dangerous.md")
ul_t_check "frontmatter: touches list" ul_t_eq "$(ul_fm_list "$fm" touches)" ".claude/settings.json"
ul_t_check "frontmatter: adds list" ul_t_eq "$(ul_fm_list "$fm" adds)" ".claude/hooks/guard-dangerous-commands.sh"
ul_t_check "frontmatter: safety true" ul_t_eq "$(ul_fm_scalar "$fm" safety)" "true"
ul_t_check "frontmatter: an empty list (requires: []) prints nothing" ul_t_eq "$(ul_fm_list "$fm" requires)" ""
ul_t_check "frontmatter: done-when items have their quotes stripped" ul_t_eq "$(ul_fm_list "$fm" done-when | sed -n 2p)" ".claude/hooks/guard-dangerous-commands.sh exists"
ul_t_check "frontmatter: ul_fm_has finds a present key" ul_fm_has "$fm" adds
ul_t_check "frontmatter: ul_fm_has misses an absent key" ul_t_not ul_fm_has "$fm" relaxes
fm=$(ul_frontmatter "$notes/fixture-doc-guidance.md")
ul_t_check "frontmatter: adds: [] gives no items" ul_t_eq "$(ul_fm_list "$fm" adds)" ""
ul_t_check "frontmatter: safety false" ul_t_eq "$(ul_fm_scalar "$fm" safety)" "false"
fm=$(ul_frontmatter "$notes/fixture-doc-followup.md")
ul_t_check "frontmatter: requires names the earlier note" ul_t_eq "$(ul_fm_list "$fm" requires)" "fixture-doc-guidance"
ul_t_check "frontmatter: followup adds its page" ul_t_eq "$(ul_fm_list "$fm" adds)" ".docs/guides/FIXTURE-2.md"
for id in hooks-guard-dangerous fixture-doc-guidance fixture-doc-followup settings-ask-restore; do
  fm=$(ul_frontmatter "$notes/$id.md")
  ul_t_check "note $id: project-data is false" ul_t_eq "$(ul_fm_scalar "$fm" project-data)" "false"
done
fm=$(ul_frontmatter "$notes/amendments-ladder-plus-three.md")
ul_t_check "note ladder: project-data is true" ul_t_eq "$(ul_fm_scalar "$fm" project-data)" "true"
pat=$(ul_strip_quotes "$(ul_fm_scalar "$fm" pattern)")
ul_t_check "note ladder: the pattern is read with its quotes stripped" ul_t_eq "$pat" '^[[:space:]-]*3[[:space:]]*=[[:space:]]*it changes auth, payment, or customer-data logic'
kori="$UL_T_ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.before"
ul_t_check "note ladder: the pattern matches both forms of the planted defect (2 lines)" test "$(grep -cE "$pat" "$kori")" = 2
ul_t_check "note ladder: the pattern does not match the other 3 line" test "$(grep -E '^[[:space:]-]*3[[:space:]]*=' "$kori" | grep -cvE "$pat")" = 2
ul_t_check "note ladder: has the Example and may-claim sections" sh -c 'grep -q "^## Example" "$1" && grep -q "^## What this note may claim" "$1"' sh "$notes/amendments-ladder-plus-three.md"
# The marker strings are assembled from pieces so this file never carries them
# literally (the leak guard would flag a literal).
dom=kelleysd.com
markers="brian@${dom}|${dom}/|ioun-""ai|/work""spaces/|~/.cla""ude"
ul_t_check "note ladder: carries no identity markers" test "$(cat "$notes"/*.md | grep -cE "$markers")" = 0
ul_t_check "frontmatter: a file with no frontmatter reports NOFRONT" ul_t_eq "$(ul_frontmatter "$UL_T_FIX/world/base/CLAUDE.md")" "NOFRONT"
ul_t_check "strip-quotes: double quotes" ul_t_eq "$(ul_strip_quotes '"abc"')" "abc"
ul_t_check "strip-quotes: single quotes" ul_t_eq "$(ul_strip_quotes "'abc'")" "abc"
ul_t_check "strip-quotes: unquoted is unchanged" ul_t_eq "$(ul_strip_quotes 'abc')" "abc"

# ------------------------------------------------------------ the five checks
# Every fixture check passes or fails on the right worlds: this is the first
# evidence the checks can fail at all (a check that cannot fail proves nothing).
chk() { # check-name root [tools-dir] -> the check's output; exit status is the check's
  ( cd "$2" && REPO_ROOT="$2" UPDATE_TOOLS="${3:-$lib_dir}" "$SH" "$notes/$1.check.sh" 2>&1 ); }
w=$(ul_t_tmp)
ul_t_world "$w"
base_tree=$(ul_t_tmp); git -C "$W_UP" archive "$W_BASE" | tar -x -C "$base_tree"
head_tree=$(ul_t_tmp); git -C "$W_UP" archive "$W_HEAD" | tar -x -C "$head_tree"
for spec in hooks-guard-dangerous fixture-doc-guidance fixture-doc-followup settings-ask-restore; do
  chk "$spec" "$base_tree" >/dev/null; rc=$?
  ul_t_check "check $spec fails on the base tree" test "$rc" != 0
  out=$(chk "$spec" "$base_tree"); last=$(printf '%s\n' "$out" | tail -1)
  ul_t_check "check $spec prints a hint= last line on failure" ul_t_has "$last" "^hint=."
  chk "$spec" "$head_tree" >/dev/null; rc=$?
  ul_t_check "check $spec passes on the head tree" test "$rc" = 0
done
ul_t_check "check ladder: skips when there is no amendments file" ul_t_eq "$(chk amendments-ladder-plus-three "$head_tree")" "skip=no amendments file in this copy"
chk amendments-ladder-plus-three "$W_CUST" >/dev/null; rc=$?
ul_t_check "check ladder: fails on the planted kori defect" test "$rc" != 0
ul_t_check "check ladder: its hint is the last line" ul_t_has "$(chk amendments-ladder-plus-three "$W_CUST" | tail -1)" "^hint=Your escalation ladder"
fixed=$(ul_t_tmp); mkdir -p "$fixed/.logic-loom/memory"
grep -vE "$pat" "$kori" > "$fixed/.logic-loom/memory/amendments.md"
chk amendments-ladder-plus-three "$fixed" >/dev/null; rc=$?
ul_t_check "check ladder: passes once the bare-3 lines are gone" test "$rc" = 0
# The hooks check reads JSON by content: a compact one-line settings file passes too.
compact=$(ul_t_tmp); mkdir -p "$compact/.claude/hooks"
cp "$head_tree/.claude/hooks/guard-dangerous-commands.sh" "$compact/.claude/hooks/"
tr -d '\n' < "$head_tree/.claude/settings.json" | sed -e 's/  */ /g' > "$compact/.claude/settings.json"
chk hooks-guard-dangerous "$compact" >/dev/null; rc=$?
ul_t_check "check hooks-guard-dangerous: a compact one-line settings file still passes" test "$rc" = 0
nofile=$(ul_t_tmp); mkdir -p "$nofile/.claude"
cp "$head_tree/.claude/settings.json" "$nofile/.claude/settings.json"
chk hooks-guard-dangerous "$nofile" >/dev/null; rc=$?
ul_t_check "check hooks-guard-dangerous: wired but the script is missing fails" test "$rc" != 0
blind=$(ul_t_tmp)
printf '#!/bin/sh\nexit 0\n' > "$blind/json-flat.sh"
chk hooks-guard-dangerous "$head_tree" "$blind" >/dev/null; rc=$?
ul_t_check "check hooks-guard-dangerous: reads JSON through UPDATE_TOOLS (a flattener that sees nothing fails it)" test "$rc" != 0
chk settings-ask-restore "$head_tree" "$blind" >/dev/null; rc=$?
ul_t_check "check settings-ask-restore: reads JSON through UPDATE_TOOLS" test "$rc" != 0
chk settings-ask-restore "$W_CUST" >/dev/null; rc=$?
ul_t_check "check settings-ask-restore: fails on the customer copy (ask list empty)" test "$rc" != 0

# ------------------------------------------------------------- ul_copy_mode
cm=$(ul_t_tmp)
mark() { # root file...
  _r=$1; shift
  for _f in "$@"; do mkdir -p "$_r/$(dirname "$_f")"; : > "$_r/$_f"; done
}
five='.logic-loom/scripts/bash/template-strip-manifest.txt .logic-loom/scripts/bash/leak-guard.sh .logic-loom/scripts/bash/strip-harness-dev.sh .logic-loom/scripts/bash/history-scrub-rules.json plugins/loom-maintenance/commands/promote.md'
mkdir -p "$cm/all" "$cm/four" "$cm/none"
# shellcheck disable=SC2086
mark "$cm/all" $five
set -- $five; shift
# shellcheck disable=SC2086
mark "$cm/four" "$@"
ul_t_check "copy-mode: all five markers is template-repo" ul_t_eq "$(ul_copy_mode "$cm/all")" "template-repo"
ul_t_check "copy-mode: four markers is copy" ul_t_eq "$(ul_copy_mode "$cm/four")" "copy"
ul_t_check "copy-mode: no markers is copy" ul_t_eq "$(ul_copy_mode "$cm/none")" "copy"
mkdir -p "$cm/tests-only/tests"
ul_t_check "copy-mode: absent markers with a tests dir is still copy" ul_t_eq "$(ul_copy_mode "$cm/tests-only")" "copy"

# ------------------------------------------------------- IFS-independence
# The engine reads TSV; if it ever leaves IFS set to a tab (or empty), the
# token loops must still split the sets on whitespace. Otherwise the whole
# protected set becomes one unmatched word and NOTHING is protected -- the
# unsafe direction -- and copy mode reads `copy` inside the template repo.
with_ifs() { # IFS-VALUE|UNSET CMD... : runs CMD in a subshell with that IFS
  ( if [ "$1" = UNSET ]; then unset IFS; else IFS=$1; fi; shift; "$@" ); }
keeps_ifs() { # IFS-VALUE CMD... : the caller's IFS is exactly IFS-VALUE afterwards
  ( _want=$1; shift; IFS=$_want; "$@" >/dev/null 2>&1; [ "${IFS+set}" = set ] && [ "$IFS" = "$_want" ] ); }
keeps_ifs_unset() { # CMD... : an unset IFS stays unset afterwards
  ( unset IFS; "$@" >/dev/null 2>&1; [ "${IFS+set}" != set ] ); }
ul_t_check "IFS=tab: ul_path_protected still sees the floor" with_ifs "$tab" ul_path_protected .claude/hooks/x.sh
ul_t_check "IFS=tab: ul_path_protected on a plain token" with_ifs "$tab" ul_path_protected .claude/settings.json
ul_t_check "IFS=tab: a non-member is still not protected" with_ifs "$tab" ul_t_not ul_path_protected .claude/agents/x.md
ul_t_check "IFS=tab: ul_path_posture" with_ifs "$tab" ul_path_posture .logic-loom/config/gate-policy.conf
ul_t_check "IFS=tab: ul_path_security_surface" with_ifs "$tab" ul_path_security_surface .claude/settings.json
ul_t_check "IFS=tab: ul_copy_mode still says template-repo" ul_t_eq "$(with_ifs "$tab" ul_copy_mode "$cm/all")" template-repo
ul_t_check "IFS=tab: ul_copy_mode still says copy on four markers" ul_t_eq "$(with_ifs "$tab" ul_copy_mode "$cm/four")" copy
ul_t_check "IFS=empty: ul_path_protected" with_ifs "" ul_path_protected .claude/hooks/x.sh
ul_t_check "IFS=empty: ul_path_posture" with_ifs "" ul_path_posture .logic-loom/config/governance.conf
ul_t_check "IFS=empty: ul_copy_mode" ul_t_eq "$(with_ifs "" ul_copy_mode "$cm/all")" template-repo
ul_t_check "IFS=space only: ul_copy_mode (the markers are newline-separated)" ul_t_eq "$(with_ifs " " ul_copy_mode "$cm/all")" template-repo
ul_t_check "IFS unset: ul_path_protected" with_ifs UNSET ul_path_protected .claude/hooks/x.sh
ul_t_check "IFS=tab: ul_path_protected restores the caller's IFS" keeps_ifs "$tab" ul_path_protected .claude/hooks/x.sh
ul_t_check "IFS=tab: ul_path_posture restores the caller's IFS" keeps_ifs "$tab" ul_path_posture CLAUDE.md
ul_t_check "IFS=tab: ul_path_security_surface restores the caller's IFS" keeps_ifs "$tab" ul_path_security_surface CLAUDE.md
ul_t_check "IFS=tab: ul_copy_mode restores the caller's IFS" keeps_ifs "$tab" ul_copy_mode "$cm/all"
ul_t_check "IFS=empty: an empty IFS is restored as empty, not unset" keeps_ifs "" ul_path_protected .claude/hooks/x.sh
ul_t_check "IFS unset: stays unset after ul_path_protected" keeps_ifs_unset ul_path_protected .claude/hooks/x.sh
ul_t_check "IFS unset: stays unset after ul_copy_mode" keeps_ifs_unset ul_copy_mode "$cm/all"

# THE CONTRACT TEST: the five marker paths in the library are exactly the five
# in tests/lib/tree-provenance.sh (tests/ is not shipped to customers, so the
# engine carries its own list and this test is the only thing keeping them one).
block() { # file name -> the single-quoted assignment block's text
  awk -v n="$2" '
    index($0, n "=\047") == 1 { on = 1 }
    on { print }
    on && $0 ~ "\047[ \t]*$" { exit }
  ' "$1"
}
extract() { grep -oE '(\.logic-loom/scripts/bash/[A-Za-z0-9._-]+|plugins/loom-maintenance/commands/promote\.md)' | sort -u; }
lib_five=$(block "$lib" UL_COPY_MARKERS | extract)
prov_five=$(block "$UL_T_ROOT/tests/lib/tree-provenance.sh" LOOM_TREE_PROVENANCE_MARKERS | extract)
ul_t_check "contract: tree-provenance.sh lists exactly five markers" test "$(printf '%s\n' "$prov_five" | grep -c .)" = 5
ul_t_check "contract: the library's five copy-mode markers equal tests/lib/tree-provenance.sh's" test -n "$lib_five" -a "$lib_five" = "$prov_five"

# ------------------------------------------------------------------ hashing
printf 'abc' > "$cm/abc.txt"
ul_t_check "sha256: of abc is the known digest" ul_t_eq "$(ul_sha256 "$cm/abc.txt")" "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
ul_t_check "sha256: of a missing file returns 1 and prints nothing" sh -c 'here=$1; . "$here/update-loom-common.sh"; trap ul_cleanup EXIT; o=$(ul_sha256 /no/such/file); [ -z "$o" ] && ! ul_sha256 /no/such/file >/dev/null 2>&1' sh "$lib_dir"
printf 'line one\nline two\n' > "$cm/lf.txt"
printf 'line one\r\nline two\r\n' > "$cm/crlf.txt"
printf 'line one\nline TWO\n' > "$cm/other.txt"
ul_t_check "norm-hash: LF and CRLF variants are equal" test "$(ul_norm_hash < "$cm/lf.txt")" = "$(ul_norm_hash < "$cm/crlf.txt")"
ul_t_check "norm-hash: different text differs" test "$(ul_norm_hash < "$cm/lf.txt")" != "$(ul_norm_hash < "$cm/other.txt")"
ul_t_check "norm-hash: prints something" test -n "$(ul_norm_hash < "$cm/lf.txt")"

# ----------------------------------------------------------- temp registry
tdir=$(ul_t_tmp)
t1=$(TMPDIR=$tdir; ul_mktemp)
ul_t_check "mktemp: a file created inside \$(...) exists" test -f "$t1"
ul_t_check "mktemp: the file lives under TMPDIR" test "$(dirname "$t1")" = "$tdir"
t2=$(ul_mktemp .txt)
ul_t_check "mktemp: a suffix is honoured" ul_t_has "$t2" '\.txt$'
ul_t_check "mktemp: the suffixed file exists" test -f "$t2"
ul_cleanup
ul_t_check "cleanup: removes a temp created inside a subshell" test ! -e "$t1" -a ! -e "$t2"
bad=$(TMPDIR=/no/such/dir/anywhere "$SH" -c 'here=$1; . "$here/update-loom-common.sh"' sh "$lib_dir" 2>&1); rc=$?
ul_t_check "mktemp: fails closed (exit 1) when a temp cannot be created" test "$rc" = 1
ul_t_check "mktemp: failure says so on stderr" ul_t_has "$bad" "temp"

# ul_install_traps: a consumer that installs the library's traps and is
# signalled must STOP (exit 128+signal) with its temps removed. A plain
# `trap ul_cleanup TERM` would run the cleanup and then carry on past the
# interrupted command with its temps gone, because a trapped signal does not
# end a non-interactive shell. The probe writes its temp path and a ready
# marker, then sleeps; the trap fires when the sleep returns. TERM is used,
# not INT: a job started with & from a non-interactive shell has INT set to
# ignored, and a non-interactive child cannot trap a signal ignored on entry,
# so an INT probe would test the test runner, not the library.
probe=$(ul_t_tmp)
cat > "$probe/int.sh" <<'PROBEEOF'
here=$1
. "$here/update-loom-common.sh"
ul_install_traps
t=$(ul_mktemp) || exit 1
printf '%s\n' "$t" > "$2/temp-path"
: > "$2/ready"
sleep 3
echo CONTINUED
exit 0
PROBEEOF
"$SH" "$probe/int.sh" "$lib_dir" "$probe" > "$probe/out" 2>&1 &
probe_pid=$!
n=0
while [ ! -f "$probe/ready" ] && [ "$n" -lt 10 ]; do sleep 1; n=$((n + 1)); done
kill -TERM "$probe_pid" 2>/dev/null
wait "$probe_pid"; rc=$?
ul_t_check "traps: the probe got as far as installing the traps and making a temp" test -f "$probe/temp-path"
ul_t_check "traps: SIGTERM ends the consumer with status 143" test "$rc" = 143
ul_t_check "traps: the consumer does not continue past the interrupted command" ul_t_hasnt "$(cat "$probe/out")" CONTINUED
ul_t_check "traps: the temp made before the signal is removed" test ! -e "$(cat "$probe/temp-path" 2>/dev/null || echo "$probe/never")" -a -f "$probe/temp-path"
ul_t_check "traps: the helper installs an INT trap too (trap listing)" ul_t_has "$("$SH" -c 'here=$1; . "$here/update-loom-common.sh"; ul_install_traps; trap' sh "$lib_dir" 2>&1)" "exit 130.*INT"

# --------------------------------------------------------- tools wrappers
ul_t_check "UL_TOOLS defaults to the library's own directory" ul_t_eq "$UL_TOOLS" "$lib_dir"
jv_quiet() { ul_json_valid "$1" >/dev/null; }
ul_t_check "ul_json_valid accepts a good file" jv_quiet "$UL_T_FIX/world/base/.claude/settings.json"
ul_t_check "ul_json_valid rejects a bad file" ul_t_not jv_quiet "$cm/abc.txt"
ul_t_check "ul_json_flat flattens a leaf" ul_t_has "$(ul_json_flat "$UL_T_FIX/world/base/.claude/settings.json")" "^/permissions/allow/0.Bash(git status:\\*)\$"
alt=$(ul_t_tmp); mkdir -p "$alt/t"
printf '#!/bin/sh\nexit 0\n' > "$alt/t/json-valid.sh"
printf '#!/bin/sh\nprintf "alt-tool\\n"\n' > "$alt/t/json-flat.sh"
override=$(UPDATE_TOOLS="$alt/t" "$SH" -c 'here=$1; . "$here/update-loom-common.sh"; trap ul_cleanup EXIT; printf "%s|%s" "$UL_TOOLS" "$(ul_json_flat x)"' sh "$lib_dir")
ul_t_check "UL_TOOLS honours a non-empty UPDATE_TOOLS" ul_t_eq "$override" "$alt/t|alt-tool"
empty=$(UPDATE_TOOLS="" "$SH" -c 'here=$1; . "$here/update-loom-common.sh"; trap ul_cleanup EXIT; printf "%s" "$UL_TOOLS"' sh "$lib_dir")
ul_t_check "UL_TOOLS ignores an empty UPDATE_TOOLS" ul_t_eq "$empty" "$lib_dir"

# -------------------------------------------------- the header is the contract
for needle in 'STATE = $(git rev-parse --absolute-git-dir)/loom/update' 'plan.tsv, meta, notes.tsv, groups.tsv' 'Persist across plans' \
              'Tracked in the repo, never in STATE' 'base_rung=<handover|recorded|remap|closest|set>' 'loom/pre-update-<YYYYMMDD-HHMMSS>' \
              'decisions.tsv' 'Ledger row:' '.applied record:' 'result=aborted reason=' 'Check contract:' 'UPDATE_TOOLS' \
              'ul_install_traps' 'protected_paths additions' 'IFS-independent'; do
  ul_t_check "header documents: $needle" grep -qF -- "$needle" "$lib"
done

# ----------------------------------------------------------- the world builder
ul_t_check "world: globals are set" test -n "$W_UP" -a -n "$W_CUST" -a -n "$W_BASE" -a -n "$W_HEAD" -a -n "$ENGINE" -a -n "$SH"
ul_t_check "world: upstream has exactly two commits" ul_t_eq "$(git -C "$W_UP" rev-list --count HEAD)" "2"
ul_t_check "world: W_BASE is the first commit" ul_t_eq "$(git -C "$W_UP" rev-list --max-parents=0 HEAD)" "$W_BASE"
ul_t_check "world: W_HEAD is upstream HEAD" ul_t_eq "$(git -C "$W_UP" rev-parse HEAD)" "$W_HEAD"
ul_t_check "world: upstream branch is main" ul_t_eq "$(git -C "$W_UP" symbolic-ref HEAD)" "refs/heads/main"
ul_t_check "world: ENGINE path is inside the customer repo" ul_t_eq "$ENGINE" "$W_CUST/plugins/loom-maintenance/scripts/update-loom.sh"
ul_t_check "world: SH is the interpreter under test" ul_t_eq "$SH" "${LOOM_TEST_SH:-/bin/sh}"
ul_t_check "world: customer has no remote" ul_t_eq "$(git -C "$W_CUST" remote)" ""
ul_t_check "world: customer branch is main" ul_t_eq "$(git -C "$W_CUST" symbolic-ref HEAD)" "refs/heads/main"
ul_t_check "world: customer history includes the customer-edits commit on top of the base" \
  ul_t_eq "$(git -C "$W_CUST" log --format=%s -1)|$(git -C "$W_CUST" rev-parse HEAD~1)" "customer edits|$W_BASE"
ul_t_check "world: upstream history is shared with the customer (the base commit exists there)" git -C "$W_CUST" cat-file -e "$W_BASE^{commit}"
ul_t_check "world: the head commit is also an object in the customer repo" git -C "$W_CUST" cat-file -e "$W_HEAD^{commit}"
ul_t_check "world: .sdd-sync-ref equals the base sha" ul_t_eq "$(cat "$W_CUST/.sdd-sync-ref")" "$W_BASE"
ul_t_check "world: .sdd-sync-ref is committed" ul_t_eq "$(git -C "$W_CUST" show HEAD:.sdd-sync-ref)" "$W_BASE"
ul_t_check "world: customer working tree is clean" ul_t_eq "$(git -C "$W_CUST" status --porcelain)" ""

# customer HEAD tree == commit1 + overlay
overlay=$(cd "$UL_T_FIX/world/customer" && find . -type f | sed 's#^\./##' | sort)
ok=1
for f in $overlay; do
  [ "$(git -C "$W_CUST" show "HEAD:$f")" = "$(cat "$UL_T_FIX/world/customer/$f")" ] || ok=0
done
ul_t_check "world: every customer overlay file is in the customer HEAD with the overlay's content" test "$ok" = 1
ok=1
for f in $(git -C "$W_UP" ls-tree -r --name-only "$W_BASE"); do
  case "
$overlay
" in *"
$f
"*) continue ;; esac
  [ "$(git -C "$W_CUST" rev-parse "HEAD:$f" 2>/dev/null)" = "$(git -C "$W_UP" rev-parse "$W_BASE:$f")" ] || ok=0
done
ul_t_check "world: every non-overlay commit1 file is unchanged in the customer HEAD" test "$ok" = 1
git -C "$W_CUST" ls-tree -r --name-only HEAD | sort > "$w/cust.lst"
{ git -C "$W_UP" ls-tree -r --name-only "$W_BASE"; printf '%s\n' $overlay .sdd-sync-ref; } | sort -u > "$w/want.lst"
ul_t_check "world: the customer tree holds nothing but commit1 + overlay + .sdd-sync-ref" cmp -s "$w/cust.lst" "$w/want.lst"

# upstream content
ul_t_check "world: base has framework-upstream.conf pointing at the upstream path" \
  ul_t_has "$(git -C "$W_UP" show "$W_BASE:.logic-loom/config/framework-upstream.conf")" "^LOOM_UPSTREAM_URL=\"$W_UP\"\$"
ul_t_check "world: the notes land under plugins/loom-maintenance/updates/7.0.0/ in upstream HEAD" sh -c '
  for id in hooks-guard-dangerous fixture-doc-guidance fixture-doc-followup amendments-ladder-plus-three settings-ask-restore; do
    git -C "$1" cat-file -e "$2:plugins/loom-maintenance/updates/7.0.0/$id.md" || exit 1
    git -C "$1" cat-file -e "$2:plugins/loom-maintenance/updates/7.0.0/$id.check.sh" || exit 1
  done' sh "$W_UP" "$W_HEAD"
ul_t_check "world: the notes are absent from the base commit" test -z "$(git -C "$W_UP" ls-tree -r --name-only "$W_BASE" | grep 'plugins/loom-maintenance/updates/7.0.0/')"
ul_t_check "world: head's guidance paragraph is in upstream HEAD" ul_t_has "$(git -C "$W_UP" show "$W_HEAD:.docs/guides/FIXTURE.md")" "Run /update-loom to take improvements."
ul_t_check "world: head adds the guard hook" git -C "$W_UP" cat-file -e "$W_HEAD:.claude/hooks/guard-dangerous-commands.sh"
ul_t_check "world: head adds FIXTURE-2.md" git -C "$W_UP" cat-file -e "$W_HEAD:.docs/guides/FIXTURE-2.md"
ul_t_check "world: web/app.js is in both commits" test "$(git -C "$W_UP" rev-parse "$W_BASE:web/app.js")" = "$(git -C "$W_UP" rev-parse "$W_HEAD:web/app.js")"

# engine files and the bundle
for s in update-loom-common.sh json-valid.sh json-flat.sh; do
  ul_t_check "world: customer carries $s from this repo" cmp -s "$lib_dir/$s" "$W_CUST/plugins/loom-maintenance/scripts/$s"
done
ul_t_check "world: the bundle is in the customer tree" test -f "$W_CUST/plugins/loom-maintenance/updates/BUNDLE.sha256"
ul_t_check "world: the bundle is in upstream HEAD" git -C "$W_UP" cat-file -e "$W_HEAD:plugins/loom-maintenance/updates/BUNDLE.sha256"
git -C "$W_UP" show "$W_HEAD:plugins/loom-maintenance/updates/BUNDLE.sha256" > "$w/bundle.txt"
ok=1; n=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  n=$((n + 1))
  sum=${line%%  *}; path=${line#*  }
  got=$(git -C "$W_UP" show "$W_HEAD:$path" 2>/dev/null | { sha256sum 2>/dev/null || shasum -a 256 2>/dev/null; } | awk '{print $1}')
  [ "$sum" = "$got" ] || ok=0
done < "$w/bundle.txt"
ul_t_check "world: every BUNDLE.sha256 line verifies against the upstream HEAD blob" test "$ok" = 1 -a "$n" -ge 3
ok=1
for s in $(git -C "$W_UP" ls-tree --name-only "$W_HEAD" plugins/loom-maintenance/scripts/ | sed 's#.*/##'); do
  grep -q "  plugins/loom-maintenance/scripts/$s\$" "$w/bundle.txt" || ok=0
done
ul_t_check "world: BUNDLE.sha256 lists every installed script" test "$ok" = 1
ul_t_check "world: BUNDLE lines use two spaces between hash and path" test "$(grep -cE '^[0-9a-f]{64}  plugins/' "$w/bundle.txt")" = "$n"

# the runner helper
ul_t_run_engine --nonsense-flag-for-the-runner
ul_t_check "run_engine: captures an exit code and output (the engine does not exist yet or refuses)" test -n "$RC"

ul_t_done
