#!/bin/sh
# Cases for the /update-loom engine's plan-free surface (package
# p0-engine-status-base): --status, --detect-base, --set-base, --bootstrap-copy,
# and the helpers every later package leans on (write_path, lock and heal, channel
# detection, the channel map, the trust root, fetch).
# POSIX sh. Prints PASS/FAIL lines; exit status is the overall result.
#
# Besides the public subcommands the engine has a few TEST-ONLY subcommands
# (--selftest-*), documented in its header, which expose helpers that have no
# public command yet. They exist so every helper has an assertion that fails
# without it; nothing else uses them.
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib.sh"

ENG_DIR=$UL_T_ROOT/plugins/loom-maintenance/scripts
ENG_SRC=$ENG_DIR/update-loom.sh
MAP_SRC=$UL_T_ROOT/.logic-loom/config/update-channels.conf
MANIFEST_SRC=$UL_T_ROOT/packaging/adopt/payload-manifest.txt

BAD1=6c4c42067161bf77e3e1af0ff91691319bd2fbdc
GOOD1=a2ed86231e097886f58e7fd0e5161648c6e6cfa3
BAD2=c6d040f36ecb6ef4a5365e9434b4e31dc741e4ac
GOOD2=75551c3574eea3f54a92d044da2e1a92b4e9590c

# ----------------------------------------------------------------- helpers
kv() { printf '%s\n' "$OUT" | sed -n "s/^$1=//p" | head -1; }          # KEY -> value from $OUT
firstline() { printf '%s\n' "$OUT" | sed -n '1p'; }
keys() { printf '%s\n' "$OUT" | sed 's/=.*//' | tr '\n' ' '; }
TAB=$(printf '\t')
ul_t_ne() { [ "$1" != "$2" ]; }
dash_n() { [ -x /bin/dash ] || return 0; /bin/dash -n "$1"; }
cg() { git -C "$W_CUST" "$@"; }
cc() { cg add -A >/dev/null 2>&1 && cg commit -q --allow-empty -m "$1"; }  # commit everything in the customer
gitdir() { cg rev-parse --absolute-git-dir; }
nw() { # a fresh fixture world in its own temp dir
  nw_d=$(ul_t_tmp) || return 1
  ul_t_world "$nw_d" || { echo "FAIL  fixture world could not be built"; fail=1; return 1; }
  ENGINE_SAVED=$ENGINE
}
run() { ul_t_run_engine "$@"; }
head_file() { cg show "HEAD:$1" 2>/dev/null; }

# =================================================================== 0. syntax
ul_t_check "engine exists" test -f "$ENG_SRC"
ul_t_check "engine passes sh -n" sh -n "$ENG_SRC"
ul_t_check "engine passes dash -n" dash_n "$ENG_SRC"
ul_t_check "case file passes sh -n" sh -n "$here/cases-status-base.sh"
ul_t_check "case file passes dash -n" dash_n "$here/cases-status-base.sh"
ul_t_check "engine starts with #!/bin/sh" ul_t_eq "$(head -1 "$ENG_SRC" 2>/dev/null)" '#!/bin/sh'
ul_t_check "engine sets set -u" grep -q '^set -u' "$ENG_SRC"
# the language rule: no bash-isms in the engine
ul_t_check "engine has no [[ ]]" ul_t_not grep -q '\[\[' "$ENG_SRC"
ul_t_check "engine has no local" ul_t_not grep -Eq '^[[:space:]]*local[[:space:]]' "$ENG_SRC"
ul_t_check "engine has no function keyword" ul_t_not grep -Eq '^[[:space:]]*function[[:space:]]' "$ENG_SRC"
ul_t_check "engine has no here-string" ul_t_not grep -q '<<<' "$ENG_SRC"
ul_t_check "engine has no array syntax" ul_t_not grep -Eq '[A-Za-z_]+=\(' "$ENG_SRC"
ul_t_check "engine never reads stdin (exec </dev/null)" grep -q '^exec </dev/null' "$ENG_SRC"

# ====================================================== 1. --status, the world
nw || ul_t_done
run --status
ul_t_check "status exits 0" ul_t_eq "$RC" 0
ul_t_check "status: channel=template" ul_t_eq "$(kv channel)" template
ul_t_check "status: upstream_url is the committed URL" ul_t_eq "$(kv upstream_url)" "$W_UP"
ul_t_check "status: upstream_url_default=no" ul_t_eq "$(kv upstream_url_default)" no
ul_t_check "status: base is commit 1" ul_t_eq "$(kv base)" "$W_BASE"
ul_t_check "status: upstream_head is commit 2" ul_t_eq "$(kv upstream_head)" "$W_HEAD"
ul_t_check "status: clean=yes" ul_t_eq "$(kv clean)" yes
ul_t_check "status: in_progress=no" ul_t_eq "$(kv in_progress)" no
ul_t_check "status: shallow=no" ul_t_eq "$(kv shallow)" no
ul_t_check "status: bundle=complete" ul_t_eq "$(kv bundle)" complete
ul_t_check "status: engine=current" ul_t_eq "$(kv engine)" current
ul_t_check "status: staged=none" ul_t_eq "$(kv staged)" none
ul_t_check "status: ledger_rows=0" ul_t_eq "$(kv ledger_rows)" 0
ul_t_check "status: copy_mode=copy" ul_t_eq "$(kv copy_mode)" copy
ul_t_check "status: keys come in the contract order" ul_t_eq "$(keys)" "channel upstream_url upstream_url_default base upstream_head clean in_progress shallow bundle engine staged ledger_rows copy_mode "
ul_t_check "status fetched upstream into refs/loom-upstream/main" ul_t_eq "$(cg rev-parse refs/loom-upstream/main)" "$W_HEAD"
ul_t_check "status created no remote" ul_t_eq "$(cg remote | wc -l | tr -d ' ')" 0
ul_t_check "status wrote nothing to the working tree" ul_t_eq "$(cg status --porcelain | wc -l | tr -d ' ')" 0

# base when the pointer file is gone
cg rm -q -f .sdd-sync-ref && cc "drop pointer"
run --status
ul_t_check "status: base=unknown with no .sdd-sync-ref" ul_t_eq "$(kv base)" unknown

# ---------------------------------------------------------------- clean
nw
mkdir -p "$W_CUST/.claude" && echo '{}' > "$W_CUST/.claude/launch.json"
run --status
ul_t_check "clean: an untracked .claude/launch.json is ignored" ul_t_eq "$(kv clean)" yes
echo '#!/bin/sh' > "$W_CUST/plugins/x.sh"
run --status
ul_t_check "clean: an untracked plugins/x.sh makes it dirty" ul_t_eq "$(kv clean)" no
rm -f "$W_CUST/plugins/x.sh"
echo 'x' > "$W_CUST/.docs/guides/new.md"
run --status
ul_t_check "clean: an untracked file under a harness prefix makes it dirty" ul_t_eq "$(kv clean)" no
rm -f "$W_CUST/.docs/guides/new.md"
run --status
ul_t_check "clean: back to yes once the stray file is gone" ul_t_eq "$(kv clean)" yes
echo 'more' >> "$W_CUST/CLAUDE.md"
run --status
ul_t_check "clean: a modified tracked file makes it dirty" ul_t_eq "$(kv clean)" no
cg checkout -q -- CLAUDE.md
echo 'more' >> "$W_CUST/.docs/guides/FIXTURE.md"
run --status
ul_t_check "clean: a modified tracked harness file makes it dirty" ul_t_eq "$(kv clean)" no
cg checkout -q -- .docs/guides/FIXTURE.md
# a customer's own status.showUntrackedFiles=no must not hide an untracked harness file
cg config status.showUntrackedFiles no
echo '#!/bin/sh' > "$W_CUST/plugins/x.sh"
run --status
ul_t_check "clean: status.showUntrackedFiles=no cannot hide an untracked harness file" ul_t_eq "$(kv clean)" no
rm -f "$W_CUST/plugins/x.sh"
cg config --unset status.showUntrackedFiles
run --status
ul_t_check "clean: yes again with the stray file gone and the setting removed" ul_t_eq "$(kv clean)" yes
# a git status that FAILS is not a clean tree (fail closed): corrupt the index
gd=$(gitdir)
cp "$gd/index" "$gd/index.saved"
printf 'garbage' > "$gd/index"
run --status
ul_t_check "clean: a failing git status (corrupt index) reports clean=no" ul_t_eq "$(kv clean)" no
ul_t_check "clean: ... and says why" ul_t_eq "$(kv clean_error)" "git status failed in this repository"
ul_t_check "clean: ... and status still exits 0" ul_t_eq "$RC" 0
# the fetch must not read the index (git's default submodule recursion does), so an
# index problem is reported as exactly that and not as a fetch failure
ul_t_check "fetch: a corrupt index does not stop the fetch" ul_t_eq "$(kv upstream_head)" "$W_HEAD"
ul_t_check "fetch: ... so no fetch_error is printed" ul_t_eq "$(kv fetch_error)" ""
run --set-base "$W_HEAD"
ul_t_check "set-base: a failing git status is refused" ul_t_ne "$RC" 0
ul_t_check "set-base: the refusal names the working tree state, not uncommitted changes" ul_t_has "$OUT" '^error could not read the working tree state'
ul_t_check "set-base: ... and the pointer is untouched" ul_t_eq "$(cat "$W_CUST/.sdd-sync-ref")" "$W_BASE"
mv "$gd/index.saved" "$gd/index"
run --status
ul_t_check "clean: back to yes with the index restored" ul_t_eq "$(kv clean)" yes
ul_t_check "clean: no clean_error line on a healthy repo" ul_t_eq "$(kv clean_error)" ""

# ---------------------------------------------------------- in_progress
gd=$(gitdir)
for m in MERGE_HEAD REBASE_HEAD CHERRY_PICK_HEAD REVERT_HEAD; do
  : > "$gd/$m"
  run --status
  ul_t_check "in_progress=yes with $m" ul_t_eq "$(kv in_progress)" yes
  rm -f "$gd/$m"
done
for d in rebase-merge rebase-apply; do
  mkdir -p "$gd/$d"
  run --status
  ul_t_check "in_progress=yes with $d/" ul_t_eq "$(kv in_progress)" yes
  rmdir "$gd/$d"
done
run --status
ul_t_check "in_progress=no again when the markers are gone" ul_t_eq "$(kv in_progress)" no

# ----------------------------------------------------------------- bundle
nw
B=plugins/loom-maintenance/scripts
rm -f "$W_CUST/$B/json-flat.sh"
run --status
ul_t_check "bundle: a deleted file is reported missing" ul_t_eq "$(kv bundle)" "incomplete missing=$B/json-flat.sh"
cg checkout -q -- "$B/json-flat.sh"
echo '# edited' >> "$W_CUST/$B/json-valid.sh"
run --status
ul_t_check "bundle: a file whose hash differs is reported missing" ul_t_eq "$(kv bundle)" "incomplete missing=$B/json-valid.sh"
echo '# edited' >> "$W_CUST/$B/json-flat.sh"
run --status
ul_t_check "bundle: several missing files are comma-joined in bundle order" ul_t_eq "$(kv bundle)" "incomplete missing=$B/json-valid.sh,$B/json-flat.sh"
cg checkout -q -- "$B/json-flat.sh" "$B/json-valid.sh"
rm -f "$W_CUST/plugins/loom-maintenance/updates/BUNDLE.sha256"
run --status
ul_t_check "bundle: no BUNDLE.sha256 is bundle=absent" ul_t_eq "$(kv bundle)" absent

# ----------------------------------------------------------------- engine
nw
cp "$ENGINE" "$W_CUST/$B/update-loom-orig.sh"
echo '# a local edit' >> "$ENGINE"
OUT=$(cd "$W_CUST" && "$SH" "$W_CUST/$B/update-loom-orig.sh" --status </dev/null 2>&1); RC=$?
ul_t_check "engine=stale when the local engine differs from upstream's" ul_t_eq "$(kv engine)" stale
ul_t_check "a local engine edit also breaks the bundle" ul_t_eq "$(kv bundle)" "incomplete missing=$B/update-loom.sh"
cg checkout -q -- "$B/update-loom.sh"
OUT=$(cd "$W_CUST" && "$SH" "$ENG_SRC" --status </dev/null 2>&1); RC=$?
ul_t_check "engine=current again once the local copy matches" ul_t_eq "$(kv engine)" current
ul_t_check "status reads the repo it runs in, not the one the script sits in" ul_t_eq "$(kv base)" "$W_BASE"
rm -f "$ENGINE"
OUT=$(cd "$W_CUST" && "$SH" "$W_CUST/$B/update-loom-orig.sh" --status </dev/null 2>&1); RC=$?
ul_t_check "engine=stale when the local engine is missing" ul_t_eq "$(kv engine)" stale
rm -f "$W_CUST/$B/update-loom-orig.sh"

# ------------------------------------------------- fetch failure, still prints the rest
nw
run --upstream-url "$W_UP/does-not-exist" --i-am-pointing-at-a-fork --status
ul_t_check "fetch failure: status still exits 0" ul_t_eq "$RC" 0
ul_t_check "fetch failure: upstream_head=unknown" ul_t_eq "$(kv upstream_head)" unknown
ul_t_check "fetch failure: fetch_error is printed" ul_t_has "$OUT" '^fetch_error=could not fetch upstream from '
ul_t_check "fetch failure: engine=unknown with no fetch" ul_t_eq "$(kv engine)" unknown
ul_t_check "fetch failure: the rest is still printed" ul_t_eq "$(kv clean)" yes
ul_t_check "fetch failure: no refs/loom-upstream/main was created" ul_t_not cg rev-parse -q --verify refs/loom-upstream/main

# --------------------------------------------------------------- trust root
nw
printf 'LOOM_UPSTREAM_URL="/definitely/not/a/repo"\n' > "$W_CUST/.logic-loom/config/framework-upstream.conf"
run --status
ul_t_check "trust root: a working-tree edit of the conf is ignored" ul_t_eq "$(kv upstream_url)" "$W_UP"
ul_t_check "trust root: the committed URL is what was fetched" ul_t_eq "$(kv upstream_head)" "$W_HEAD"
cg checkout -q -- .logic-loom/config/framework-upstream.conf
LOOM_UPSTREAM_URL=/definitely/not/a/repo; export LOOM_UPSTREAM_URL
run --status
unset LOOM_UPSTREAM_URL
ul_t_check "trust root: the LOOM_UPSTREAM_URL env var is not honoured" ul_t_eq "$(kv upstream_url)" "$W_UP"
run --upstream-url /somewhere/else --status
ul_t_check "trust root: --upstream-url alone exits non-zero" ul_t_ne "$RC" 0
ul_t_check "trust root: --upstream-url alone names the second flag" ul_t_has "$OUT" '^error --upstream-url needs --i-am-pointing-at-a-fork'
run --upstream-url /somewhere/else --i-am-pointing-at-a-fork --status
ul_t_check "trust root: both flags are accepted" ul_t_eq "$(kv upstream_url)" /somewhere/else
ul_t_check "trust root: an override makes upstream_url_default=no" ul_t_eq "$(kv upstream_url_default)" no
run --status --upstream-url "$W_UP" --i-am-pointing-at-a-fork
ul_t_check "trust root: the global options also work after the subcommand" ul_t_eq "$(kv upstream_url)" "$W_UP"

# conf forms. insteadOf makes any github URL fail fast and offline.
cg config "url.$(ul_t_tmp)/nowhere/.insteadOf" https://github.com/
printf 'LOOM_UPSTREAM_REPO="owner/name"\n' > "$W_CUST/.logic-loom/config/framework-upstream.conf"; cc "repo form"
run --status
ul_t_check "conf: LOOM_UPSTREAM_REPO becomes a github URL" ul_t_eq "$(kv upstream_url)" https://github.com/owner/name.git
ul_t_check "conf: a github URL that differs from the default is flagged" ul_t_eq "$(kv upstream_url_default)" no
printf 'LOOM_UPSTREAM_REPO="owner/name"\nLOOM_UPSTREAM_URL="https://example.invalid/x.git"\n' > "$W_CUST/.logic-loom/config/framework-upstream.conf"; cc "both"
run --status
ul_t_check "conf: LOOM_UPSTREAM_URL wins over LOOM_UPSTREAM_REPO" ul_t_eq "$(kv upstream_url)" https://example.invalid/x.git
printf '# nothing here\n' > "$W_CUST/.logic-loom/config/framework-upstream.conf"; cc "none"
run --status
ul_t_check "conf: no key falls back to the shipped default URL" ul_t_eq "$(kv upstream_url)" https://github.com/kelleysd-apps/LogicLoom.git
ul_t_check "conf: the shipped default reports upstream_url_default=yes" ul_t_eq "$(kv upstream_url_default)" yes
printf "LOOM_UPSTREAM_URL='https://example.invalid/single.git' # trailing\n" > "$W_CUST/.logic-loom/config/framework-upstream.conf"; cc "single"
run --status
ul_t_check "conf: single quotes and a trailing comment are stripped" ul_t_eq "$(kv upstream_url)" https://example.invalid/single.git
cg rm -q -f .logic-loom/config/framework-upstream.conf; cc "no conf"
run --status
ul_t_check "conf: a missing conf falls back to the shipped default URL" ul_t_eq "$(kv upstream_url)" https://github.com/kelleysd-apps/LogicLoom.git

# ---------------------------------------------------------- channel detection
nw
# The receipt shape is the installer's (packaging/adopt/lib/apply.js:896-924): one run
# per `--apply`, each with status complete|partial (aborted or crashed otherwise) and
# the `only` list it was asked for, `all` already expanded (apply.js:651). The
# INSTALLED groups are the union over completed and partial runs (receipt.js:53-76):
# `--only=all` then `--only=hooks` is two runs, and the second does not uninstall the
# first.
SC='{"schema":"logicloom/adopt-receipt@1","runs":[{"status":"complete","only":["harness","hooks"]}]}'
printf '%s\n' "$SC" > "$W_CUST/.logicloom-adopt-receipt.json"
run --status
ul_t_check "channel: a valid receipt is adopted" ul_t_eq "$(kv channel)" adopted
run --selftest-channel
ul_t_check "channel: receipt groups come from the completed run's only list" ul_t_eq "$(kv groups)" harness,hooks
printf '%s\n' '{"schema":"logicloom/adopt-receipt@1","runs":[{"at":"a","status":"complete","only":["harness"]},{"at":"b","status":"complete","only":["rules","hooks"]}]}' > "$W_CUST/.logicloom-adopt-receipt.json"
run --selftest-channel
ul_t_check "channel: groups are the UNION of every completed run, in run order" ul_t_eq "$(kv groups)" harness,rules,hooks
printf '%s\n' '{"schema":"logicloom/adopt-receipt@1","runs":[{"at":"a","status":"complete","only":["harness"]},{"at":"b","status":"partial","only":["hooks"]}]}' > "$W_CUST/.logicloom-adopt-receipt.json"
run --selftest-channel
ul_t_check "channel: a partial run counts towards the union" ul_t_eq "$(kv groups)" harness,hooks
printf '%s\n' '{"schema":"logicloom/adopt-receipt@1","runs":[{"at":"a","status":"complete","only":["harness"]},{"at":"b","status":"aborted","only":["rules","hooks"]}]}' > "$W_CUST/.logicloom-adopt-receipt.json"
run --selftest-channel
ul_t_check "channel: an aborted run adds nothing" ul_t_eq "$(kv groups)" harness
printf '%s\n' '{"schema":"logicloom/adopt-receipt@1","runs":[{"at":"a","status":"complete","only":["harness"]},{"at":"b","only":["rules"]}]}' > "$W_CUST/.logicloom-adopt-receipt.json"
run --selftest-channel
ul_t_check "channel: a run that never recorded a status (crashed) adds nothing" ul_t_eq "$(kv groups)" harness
printf '%s\n' '{"schema":"logicloom/adopt-receipt@1","runs":[{"at":"a","status":"complete","only":["harness"]},{"at":"b","status":"complete","only":["harness","hooks"]}]}' > "$W_CUST/.logicloom-adopt-receipt.json"
run --selftest-channel
ul_t_check "channel: a group named by two runs is listed once" ul_t_eq "$(kv groups)" harness,hooks
printf '%s\n' '{"schema":"logicloom/adopt-receipt@1","runs":[{"at":"a","status":"complete","only":["harness"]},{"at":"b","status":"complete","only":[]}]}' > "$W_CUST/.logicloom-adopt-receipt.json"
run --selftest-channel
ul_t_check "channel: a completed run with an empty only list means every group" ul_t_eq "$(kv groups)" all
printf '%s\n' '{"schema":"logicloom/adopt-receipt@1","runs":[{"at":"a","status":"aborted","only":["harness"]}]}' > "$W_CUST/.logicloom-adopt-receipt.json"
run --status
ul_t_check "channel: a receipt whose only run aborted is ambiguous" ul_t_eq "$(kv channel)" ambiguous
ul_t_check "channel: ... with a notice that no install completed" ul_t_eq "$(kv notice)" "your adopt receipt records no completed install run"
printf '%s\n' '{"schema":"logicloom/adopt-receipt@1","runs":[]}' > "$W_CUST/.logicloom-adopt-receipt.json"
run --status
ul_t_check "channel: a receipt with no runs is ambiguous" ul_t_eq "$(kv channel)" ambiguous
run --selftest-channel
ul_t_check "channel: ... and its groups are none" ul_t_eq "$(kv groups)" none
printf '%s\n' '{"schema":"logicloom/adopt-receipt@1","runs":[{"status":"complete","only":["harness","hooks"]}]}' > "$W_CUST/.logicloom-adopt-receipt.json"
run --channel template --status
ul_t_check "channel: --channel template on an adopted tree is refused" ul_t_ne "$RC" 0
ul_t_check "channel: the refusal says the override disagrees" ul_t_has "$OUT" '^error --channel template disagrees'
run --channel adopted --status
ul_t_check "channel: --channel adopted on an adopted tree is fine" ul_t_eq "$(kv channel)" adopted
printf '{"schema":' > "$W_CUST/.logicloom-adopt-receipt.json"
run --status
ul_t_check "channel: a broken receipt is ambiguous" ul_t_eq "$(kv channel)" ambiguous
ul_t_check "channel: a broken receipt carries the damaged notice" ul_t_eq "$(kv notice)" "your adopt receipt is damaged"
ul_t_check "channel: the notice follows the channel line" ul_t_eq "$(printf '%s\n' "$OUT" | sed -n 2p)" "notice=your adopt receipt is damaged"
run --channel template --status
ul_t_check "channel: --channel template resolves an ambiguous tree" ul_t_eq "$(kv channel)" template
run --channel adopted --status
ul_t_check "channel: --channel adopted resolves an ambiguous tree" ul_t_eq "$(kv channel)" adopted
run --channel bogus --status
ul_t_check "channel: --channel with another value is refused" ul_t_ne "$RC" 0
printf '{"schema":"something/else@1","runs":[]}\n' > "$W_CUST/.logicloom-adopt-receipt.json"
run --status
ul_t_check "channel: a receipt with another schema is ambiguous" ul_t_eq "$(kv channel)" ambiguous
rm -f "$W_CUST/.logicloom-adopt-receipt.json"
run --status
ul_t_check "channel: no receipt, no fingerprint is template" ul_t_eq "$(kv channel)" template
ul_t_check "channel: template carries no notice" ul_t_eq "$(kv notice)" ""
run --channel adopted --status
ul_t_check "channel: --channel adopted on a plain template tree is refused" ul_t_ne "$RC" 0
ul_t_check "channel: the refusal says the override disagrees" ul_t_has "$OUT" '^error --channel adopted disagrees'
run --channel template --status
ul_t_check "channel: --channel template on a plain template tree is fine" ul_t_eq "$(kv channel)" template
mkdir -p "$W_CUST/.claude/rules" && echo x > "$W_CUST/.claude/rules/logicloom-governance.md"
run --status
ul_t_check "channel: a logicloom-*.md rule is an adoption fingerprint" ul_t_eq "$(kv channel)" ambiguous
ul_t_check "channel: a fingerprint alone carries no notice" ul_t_eq "$(kv notice)" ""
rm -rf "$W_CUST/.claude/rules"
echo '{}' > "$W_CUST/.claude/.logicloom-adopt-settings.json"
run --status
ul_t_check "channel: the adopt settings insertion is a fingerprint" ul_t_eq "$(kv channel)" ambiguous
rm -f "$W_CUST/.claude/.logicloom-adopt-settings.json"
echo x > "$W_CUST/.logic-loom/AGENTS.md"
run --status
ul_t_check "channel: .logic-loom/AGENTS.md without a root AGENTS.md is a fingerprint" ul_t_eq "$(kv channel)" ambiguous
echo y > "$W_CUST/AGENTS.md"
run --status
ul_t_check "channel: .logic-loom/AGENTS.md beside a root AGENTS.md is not" ul_t_eq "$(kv channel)" template
ul_t_check "channel: an ambiguous status still prints the rest" ul_t_eq "$(kv bundle)" complete

# ------------------------------------------------------------------ shallow
nw
SHAL=$(ul_t_tmp)/shallow
git clone -q --depth 1 "file://$W_CUST" "$SHAL" 2>/dev/null
ul_t_git_config "$SHAL"
W_CUST_SAVED=$W_CUST; W_CUST=$SHAL; ENGINE=$SHAL/plugins/loom-maintenance/scripts/update-loom.sh
run --status
ul_t_check "shallow: a depth-1 clone prints shallow=yes" ul_t_eq "$(kv shallow)" yes
ul_t_check "shallow: status still exits 0" ul_t_eq "$RC" 0
run --detect-base
ul_t_check "shallow: detect-base prints shallow=yes" ul_t_eq "$(kv shallow)" yes
W_CUST=$W_CUST_SAVED; ENGINE=$ENGINE_SAVED

# ------------------------------------------------------------- not a repo
NOGIT=$(ul_t_tmp)
OUT=$(cd "$NOGIT" && "$SH" "$ENG_SRC" --status </dev/null 2>&1); RC=$?
ul_t_check "outside a repo: exits 1" ul_t_eq "$RC" 1
ul_t_check "outside a repo: says so" ul_t_has "$OUT" '^error not inside a git repository'

# ------------------------------------------------------------------- usage
nw
run --no-such-subcommand
ul_t_check "unknown subcommand exits 2" ul_t_eq "$RC" 2
ul_t_check "unknown subcommand prints usage" ul_t_has "$OUT" '[Uu]sage'
run
ul_t_check "no subcommand exits 2" ul_t_eq "$RC" 2
run --help
ul_t_check "--help exits 0" ul_t_eq "$RC" 0
ul_t_check "--help lists --detect-base" ul_t_has "$OUT" '--detect-base'

# ============================================================ 2. --detect-base
nw
run --detect-base
ul_t_check "detect-base: fresh world is recorded <commit1>" ul_t_eq "$(firstline)" "recorded $W_BASE"
ul_t_check "detect-base: recorded= line" ul_t_eq "$(kv recorded)" "$W_BASE"
ul_t_check "detect-base: shallow=no line" ul_t_eq "$(kv shallow)" no
ul_t_check "detect-base: the verdict is the FIRST line" ul_t_eq "$(printf '%s\n' "$OUT" | sed -n '1p' | cut -c1-8)" "recorded"
ul_t_check "detect-base: fetched upstream" ul_t_eq "$(cg rev-parse refs/loom-upstream/main)" "$W_HEAD"

# the known-bad stamps live in the engine, exactly the two the old extractor holds
ul_t_check "remap table: stamp 1 is in the engine" grep -q "$BAD1" "$ENG_SRC"
ul_t_check "remap table: target 1 is in the engine" grep -q "$GOOD1" "$ENG_SRC"
ul_t_check "remap table: stamp 2 is in the engine" grep -q "$BAD2" "$ENG_SRC"
ul_t_check "remap table: target 2 is in the engine" grep -q "$GOOD2" "$ENG_SRC"
ul_t_check "remap table: the engine names exactly four 40-hex commits (not widened)" ul_t_eq "$(grep -Eo '[0-9a-f]{40}' "$ENG_SRC" 2>/dev/null | sort -u | wc -l | tr -d ' ')" 4
# the old extractor is retired in a later phase (design section 6); compare while it exists
OLDX=$UL_T_ROOT/plugins/loom-maintenance/scripts/extract-proposals.sh
if [ -f "$OLDX" ]; then
  ul_t_check "remap table: it matches the old extractor's table" ul_t_eq "$(grep -Eo '[0-9a-f]{40}' "$OLDX" | sort -u | tr '\n' ' ')" "$(grep -Eo '[0-9a-f]{40}' "$ENG_SRC" 2>/dev/null | sort -u | tr '\n' ' ')"
fi
run --selftest-remap "$BAD1"
ul_t_check "remap: stamp 1 maps to target 1" ul_t_eq "$(firstline)" "$GOOD1"
run --selftest-remap "$BAD2"
ul_t_check "remap: stamp 2 maps to target 2" ul_t_eq "$(firstline)" "$GOOD2"
run --selftest-remap c6092b0862562f306769ce742be5665fa0827c10
ul_t_check "remap: the stamp the v6.3.0/v6.4.1/v6.5.0 tag clones carry is NOT in the table (design 3.3)" ul_t_eq "$(firstline)" ""
run --selftest-remap deadbeef
ul_t_check "remap: an unknown value maps to nothing" ul_t_eq "$(firstline)" ""

# garbage and missing stamps fall to the closest rung
GARBAGE=this-is-not-a-sha
printf '%s\n' "$GARBAGE" > "$W_CUST/.sdd-sync-ref"; cc "garbage"
run --detect-base
ul_t_check "detect-base: a garbage stamp falls to closest" ul_t_eq "$(firstline)" "closest $W_BASE 2"
ul_t_check "detect-base: the garbage stamp is echoed back" ul_t_eq "$(kv recorded)" "$GARBAGE"
printf '%s\n' "$BAD1" > "$W_CUST/.sdd-sync-ref"; cc "known bad, target not in this repo"
run --detect-base
ul_t_check "detect-base: a known-bad stamp whose target is unreachable falls to closest" ul_t_eq "$(firstline)" "closest $W_BASE 2"
printf '%s\n' "$W_CUST" > "$W_CUST/.sdd-sync-ref"; cc "path in the file"
run --detect-base
ul_t_check "detect-base: option-shaped garbage is treated as garbage" ul_t_eq "$(printf '%s\n' "$(firstline)" | cut -d' ' -f1)" closest
printf '%s\n' "-n$W_BASE" > "$W_CUST/.sdd-sync-ref"; cc "dash"
run --detect-base
ul_t_check "detect-base: a stamp starting with a dash is garbage" ul_t_eq "$(printf '%s\n' "$(firstline)" | cut -d' ' -f1)" closest

# the remap rung, run through a copy of the engine whose table points at this fixture
nw
FAKEBAD=1111111111111111111111111111111111111111
EC=$(ul_t_tmp)/eng; mkdir -p "$EC"
cp "$ENG_DIR"/*.sh "$EC/" 2>/dev/null
sed -e "s/$BAD1/$FAKEBAD/g" -e "s/$GOOD1/$W_BASE/g" "$ENG_SRC" > "$EC/update-loom.sh" 2>/dev/null
printf '%s\n' "$FAKEBAD" > "$W_CUST/.sdd-sync-ref"; cc "fake known-bad stamp"
ENGINE=$EC/update-loom.sh
run --detect-base
ul_t_check "detect-base: a known-bad stamp with a reachable target is remap <sha>" ul_t_eq "$(firstline)" "remap $W_BASE"
ul_t_check "detect-base: remap echoes the stamp it replaced" ul_t_eq "$(kv recorded)" "$FAKEBAD"
ENGINE=$ENGINE_SAVED

# closest: an exact match wins with n=0
nw
cg rm -q -f .logic-loom/memory/amendments.md
cg checkout -q "$W_BASE" -- .docs/guides/FIXTURE.md
cg rm -q -f .sdd-sync-ref
cc "harness files back to commit 1; pointer removed"
run --detect-base
ul_t_check "detect-base: no pointer and an identical harness tree is closest <sha> 0" ul_t_eq "$(firstline)" "closest $W_BASE 0"
ul_t_check "detect-base: recorded=missing with no pointer" ul_t_eq "$(kv recorded)" missing
echo 'my edit' >> "$W_CUST/.docs/guides/FIXTURE.md"; cc "one harness file edited"
run --detect-base
ul_t_check "detect-base: one differing harness file is closest <sha> 1" ul_t_eq "$(firstline)" "closest $W_BASE 1"
echo 'a stray product file' > "$W_CUST/web/other.js"; echo 'readme' > "$W_CUST/NOTES.md"; cc "files outside the harness"
run --detect-base
ul_t_check "detect-base: files outside the harness prefixes do not count" ul_t_eq "$(firstline)" "closest $W_BASE 1"

# closest: a repo with no harness files has nothing to match
nw
EC=$(ul_t_tmp)/eng; mkdir -p "$EC"; cp "$ENG_DIR"/*.sh "$EC/" 2>/dev/null
cg rm -r -q -f .logic-loom plugins .claude .docs features .sdd-sync-ref
cc "no harness at all"
ENGINE=$EC/update-loom.sh
run --upstream-url "$W_UP" --i-am-pointing-at-a-fork --detect-base
ul_t_check "detect-base: a tree with no harness files is none" ul_t_eq "$(firstline)" none
ul_t_check "detect-base: none still prints recorded=missing" ul_t_eq "$(kv recorded)" missing
ENGINE=$ENGINE_SAVED

# handover
nw
cg tag loom/pre-update-20260101-000000          # on the customer-edits commit, whose pointer is commit 1
printf '%s\n' "$W_HEAD" > "$W_CUST/.sdd-sync-ref"; cc "old updater advanced the pointer"
run --detect-base
ul_t_check "detect-base: empty ledger + surviving tag recovers the older stamp" ul_t_eq "$(firstline)" "handover $W_BASE"
ul_t_check "detect-base: handover still reports the recorded stamp" ul_t_eq "$(kv recorded)" "$W_HEAD"
mkdir -p "$W_CUST/.logic-loom/memory"
printf 'some-note\tapplied\tabc\t%s\t2026-10-01\n' "$W_HEAD" > "$W_CUST/.logic-loom/memory/update-ledger.tsv"; cc "one ledger row"
run --detect-base
ul_t_check "detect-base: with a ledger row the handover rung is skipped" ul_t_eq "$(firstline)" "recorded $W_HEAD"
run --status
ul_t_check "status: ledger_rows counts the committed rows" ul_t_eq "$(kv ledger_rows)" 1
printf '# a comment\n\n' >> "$W_CUST/.logic-loom/memory/update-ledger.tsv"; cc "comments and blank lines"
run --status
ul_t_check "status: ledger_rows ignores # lines and blanks" ul_t_eq "$(kv ledger_rows)" 1

nw
ORPH=$(cg commit-tree "$(cg rev-parse 'HEAD^{tree}')" -m orphan </dev/null)
cg tag loom/pre-update-20260101-000000 "$ORPH"
printf '%s\n' "$W_HEAD" > "$W_CUST/.sdd-sync-ref"; cc "advance"
run --detect-base
ul_t_check "detect-base: a tag that is not an ancestor of HEAD gives recorded" ul_t_eq "$(firstline)" "recorded $W_HEAD"

nw
cg tag loom/pre-update-20260101-000000
cc "nothing changed"
run --detect-base
ul_t_check "detect-base: a tag whose stamp equals the recorded one gives recorded" ul_t_eq "$(firstline)" "recorded $W_BASE"

nw
printf '%s\n' "$GARBAGE" > "$W_CUST/.sdd-sync-ref"; cc "garbage stamp"
cg tag loom/pre-update-20260101-000000
printf '%s\n' "$W_HEAD" > "$W_CUST/.sdd-sync-ref"; cc "advance"
run --detect-base
ul_t_check "detect-base: a tag whose stamp is not a real commit gives recorded" ul_t_eq "$(firstline)" "recorded $W_HEAD"

nw
cg tag loom/pre-update-20260101-000000
printf '%s\n' "$W_HEAD" > "$W_CUST/.sdd-sync-ref"; cc "advance"
cg tag some/other-tag HEAD
run --detect-base
ul_t_check "detect-base: only loom/pre-update-* tags count" ul_t_eq "$(firstline)" "handover $W_BASE"
cg tag -d loom/pre-update-20260101-000000 >/dev/null
run --detect-base
ul_t_check "detect-base: with no tag at all it is recorded" ul_t_eq "$(firstline)" "recorded $W_HEAD"

# ============================================================= 3. --set-base
nw
before=$(cg rev-parse HEAD)
run --set-base "$W_BASE"
ul_t_check "set-base: an unchanged value exits 0" ul_t_eq "$RC" 0
ul_t_check "set-base: an unchanged value prints base=" ul_t_eq "$(kv base)" "$W_BASE"
ul_t_check "set-base: an unchanged value makes no commit" ul_t_eq "$(cg rev-parse HEAD)" "$before"
run --set-base "$W_HEAD"
ul_t_check "set-base: exits 0" ul_t_eq "$RC" 0
ul_t_check "set-base: prints base=<sha>" ul_t_eq "$(kv base)" "$W_HEAD"
ul_t_check "set-base: HEAD:.sdd-sync-ref has the new value" ul_t_eq "$(head_file .sdd-sync-ref)" "$W_HEAD"
ul_t_check "set-base: the working file ends with a newline and holds the full sha" ul_t_eq "$(cat "$W_CUST/.sdd-sync-ref")" "$W_HEAD"
ul_t_check "set-base: one new commit" ul_t_eq "$(cg rev-list --count "$before..HEAD")" 1
ul_t_check "set-base: the commit touches only .sdd-sync-ref" ul_t_eq "$(cg show --stat --format= HEAD | grep -c '|')" 1
ul_t_check "set-base: ... and it is that file" ul_t_has "$(cg show --stat --format= HEAD)" '\.sdd-sync-ref'
ul_t_check "set-base: the commit subject is the recorded wording" ul_t_eq "$(cg log -1 --format=%s)" "Record the LogicLoom base this copy updates from"
ul_t_check "set-base: the tree is clean afterwards" ul_t_eq "$(cg status --porcelain | wc -l | tr -d ' ')" 0
after=$(cg rev-parse HEAD)
run --set-base "$W_HEAD"
ul_t_check "set-base: a second identical call makes no new commit" ul_t_eq "$(cg rev-parse HEAD)" "$after"
run --set-base "$W_HEAD"
ul_t_check "set-base: a second identical call still prints base=" ul_t_eq "$(kv base)" "$W_HEAD"

OWN=$(cg rev-parse HEAD)
run --set-base "$OWN"
ul_t_check "set-base: a commit not reachable from upstream is refused" ul_t_ne "$RC" 0
ul_t_check "set-base: the refusal names the sha" ul_t_has "$OUT" "^error $OWN is not reachable from upstream"
ul_t_check "set-base: a refused call leaves the pointer alone" ul_t_eq "$(cat "$W_CUST/.sdd-sync-ref")" "$W_HEAD"
run --set-base not-a-sha
ul_t_check "set-base: a non-sha is refused" ul_t_ne "$RC" 0
ul_t_check "set-base: a non-sha gets the same error" ul_t_has "$OUT" '^error not-a-sha is not reachable from upstream'
run --set-base
ul_t_check "set-base: no argument is refused" ul_t_ne "$RC" 0
run --set-base --channel
ul_t_check "set-base: an option as the value is refused" ul_t_ne "$RC" 0

nw
echo 'edit' >> "$W_CUST/CLAUDE.md"
run --set-base "$W_HEAD"
ul_t_check "set-base: a dirty tree is refused" ul_t_ne "$RC" 0
ul_t_check "set-base: the refusal says the tree is not clean" ul_t_has "$OUT" '^error .*uncommitted'
ul_t_check "set-base: a refused call writes nothing" ul_t_eq "$(cat "$W_CUST/.sdd-sync-ref")" "$W_BASE"
cg checkout -q -- CLAUDE.md
printf '%s\n' "$GARBAGE" > "$W_CUST/.sdd-sync-ref"
run --set-base "$W_HEAD"
ul_t_check "set-base: a modified .sdd-sync-ref alone does not count as dirty" ul_t_eq "$(kv base)" "$W_HEAD"
ul_t_check "set-base: ... and it was committed" ul_t_eq "$(head_file .sdd-sync-ref)" "$W_HEAD"
cg rm -q -f .sdd-sync-ref; cc "pointer gone"
run --set-base "$W_BASE"
ul_t_check "set-base: restores a missing pointer" ul_t_eq "$(head_file .sdd-sync-ref)" "$W_BASE"

# ======================================================= 4. write_path (helper)
nw
WT=$(ul_t_tmp)/wt
ul_t_git_init "$WT"
SRC=$(ul_t_tmp)/src.sh
printf '#!/bin/sh\necho hi\n' > "$SRC"
write() { run --selftest-write-path "$WT" "$@"; }
write bin/tool.sh "$SRC" 100755
ul_t_check "write_path: exits 0" ul_t_eq "$RC" 0
ul_t_check "write_path: the content lands" ul_t_eq "$(cat "$WT/bin/tool.sh")" "$(cat "$SRC")"
ul_t_check "write_path: a 100755 entry is executable on disk" test -x "$WT/bin/tool.sh"
ul_t_check "write_path: a 100755 entry is 100755 in the index" ul_t_eq "$(git -C "$WT" ls-files -s bin/tool.sh | cut -d' ' -f1)" 100755
ul_t_check "write_path: no temp file is left behind" ul_t_eq "$(ls -A "$WT/bin" | tr '\n' ' ')" "tool.sh "
git -C "$WT" config core.filemode false
write bin/other.sh "$SRC" 100755
ul_t_check "write_path: index mode is right even with core.filemode=false" ul_t_eq "$(git -C "$WT" ls-files -s bin/other.sh | cut -d' ' -f1)" 100755
write bin/plain.txt "$SRC" 100644
ul_t_check "write_path: a 100644 entry is not executable" ul_t_not test -x "$WT/bin/plain.txt"
ul_t_check "write_path: a 100644 entry is 100644 in the index" ul_t_eq "$(git -C "$WT" ls-files -s bin/plain.txt | cut -d' ' -f1)" 100644
write bin/tool.sh "$SRC" 100644
ul_t_check "write_path: rewriting with 100644 drops the executable bit" ul_t_not test -x "$WT/bin/tool.sh"
ul_t_check "write_path: ... and the index follows" ul_t_eq "$(git -C "$WT" ls-files -s bin/tool.sh | cut -d' ' -f1)" 100644
printf 'new body\n' > "$SRC"
write bin/tool.sh "$SRC" 100644
ul_t_check "write_path: a rewrite replaces the content" ul_t_eq "$(cat "$WT/bin/tool.sh")" "new body"
write deep/er/path/f.txt "$SRC" 100644
ul_t_check "write_path: missing parent directories are created" test -f "$WT/deep/er/path/f.txt"
ul_t_check "write_path: the new file is staged" ul_t_eq "$(git -C "$WT" ls-files deep/er/path/f.txt)" deep/er/path/f.txt

ELSE=$(ul_t_tmp)
ln -s "$ELSE" "$WT/lib"
write lib/x.sh "$SRC" 100644
ul_t_check "write_path: a symlinked parent is refused" ul_t_ne "$RC" 0
ul_t_check "write_path: the refusal names the symlink" ul_t_has "$OUT" '^error symlink in path lib'
ul_t_check "write_path: nothing was written through the symlink" ul_t_eq "$(ls -A "$ELSE" | wc -l | tr -d ' ')" 0
mkdir -p "$WT/a"; ln -s "$ELSE" "$WT/a/b"
write a/b/c/x.sh "$SRC" 100644
ul_t_check "write_path: a nested symlinked component is refused" ul_t_ne "$RC" 0
ul_t_check "write_path: the nested refusal names the component" ul_t_has "$OUT" '^error symlink in path a/b'
ul_t_check "write_path: no directories were created through it" ul_t_eq "$(ls -A "$ELSE" | wc -l | tr -d ' ')" 0
ln -s "$ELSE/target.txt" "$WT/linkfile"
write linkfile "$SRC" 100644
ul_t_check "write_path: a symlink at the path itself is refused" ul_t_ne "$RC" 0
ul_t_check "write_path: ... and nothing was written through it" ul_t_not test -e "$ELSE/target.txt"
write ../escape.txt "$SRC" 100644
ul_t_check "write_path: a .. component is refused" ul_t_ne "$RC" 0
write /abs/escape.txt "$SRC" 100644
ul_t_check "write_path: an absolute path is refused" ul_t_ne "$RC" 0
write bin "$SRC" 100644
ul_t_check "write_path: a directory at the path is refused" ul_t_ne "$RC" 0
write bin/new.sh "$SRC" 120000
ul_t_check "write_path: a symlink mode is refused" ul_t_ne "$RC" 0
write bin/new.sh "$SRC.missing" 100644
ul_t_check "write_path: a missing source is refused" ul_t_ne "$RC" 0
ul_t_check "write_path: a refused write leaves no temp file" ul_t_eq "$(ls -A "$WT/bin" | tr '\n' ' ')" "other.sh plain.txt tool.sh "

# ============================================================ 5. lock and heal
nw
gd=$(gitdir); st=$gd/loom/update
mkdir -p "$st"
cg worktree add -q --detach "$st/wt" HEAD
DEAD=$(sh -c 'echo $$')
pid_dead() { ! kill -0 "$1" 2>/dev/null; }
ul_t_check "lock: the dead pid is really dead" pid_dead "$DEAD"
printf '%s\n' "$DEAD" > "$st/stage.lock"
run --status
ul_t_check "lock: a dead lock plus a registered worktree prints healed=yes" ul_t_eq "$(kv healed)" yes
ul_t_check "lock: the worktree is no longer registered" ul_t_eq "$(cg worktree list | grep -c 'loom/update/wt')" 0
ul_t_check "lock: the worktree directory is gone" ul_t_not test -d "$st/wt"
ul_t_check "lock: the stale lock is removed" ul_t_not test -e "$st/stage.lock"
ul_t_check "lock: healing leaves the tree clean" ul_t_eq "$(kv clean)" yes
run --status
ul_t_check "lock: a second status has nothing to heal" ul_t_eq "$(kv healed)" ""

cg worktree add -q --detach "$st/wt" HEAD
printf '%s\n' "$$" > "$st/stage.lock"
run --status
ul_t_check "lock: a live pid prints lock=held pid=N" ul_t_eq "$(kv lock)" "held pid=$$"
ul_t_check "lock: a live lock leaves the worktree alone" test -d "$st/wt"
ul_t_check "lock: a live lock is not healed" ul_t_eq "$(kv healed)" ""
ul_t_check "lock: a live lock stays" test -f "$st/stage.lock"
rm -f "$st/stage.lock"

run --status
ul_t_check "lock: no lock and a leftover worktree is healed" ul_t_eq "$(kv healed)" yes
ul_t_check "lock: ... and the worktree is gone" ul_t_not test -d "$st/wt"

cg worktree add -q --detach "$st/wt" HEAD
printf '%s\n' "$W_HEAD" > "$st/staged"
run --status
ul_t_check "status: staged=<sha> reads the staged file" ul_t_eq "$(kv staged)" "$W_HEAD"
ul_t_check "lock: a staged commit awaiting landing keeps its worktree (no lock)" test -d "$st/wt"
ul_t_check "lock: ... and prints no healed line" ul_t_eq "$(kv healed)" ""
printf '%s\n' "$DEAD" > "$st/stage.lock"
run --status
ul_t_check "lock: a dead lock is healed even when a staged file exists" ul_t_eq "$(kv healed)" yes
ul_t_check "lock: ... the stale lock is gone" ul_t_not test -e "$st/stage.lock"
ul_t_check "lock: the staged file itself is not deleted by healing" test -f "$st/staged"
# the worktree is what keeps the staged commit reachable until it lands or --stage
# starts over (with force); a dead lock is no reason to throw it away
ul_t_check "lock: ... and the worktree holding the staged commit is kept" test -d "$st/wt"
ul_t_check "lock: ... and stays registered" ul_t_eq "$(cg worktree list | grep -c 'loom/update/wt')" 1
rm -f "$st/staged"

# lock_acquire / lock_release through the test-only subcommand
run --selftest-lock
ul_t_check "lock: acquire succeeds on a clean state" ul_t_has "$OUT" '^lock=acquired pid='
ul_t_check "lock: the exit trap releases the lock" ul_t_not test -e "$st/stage.lock"
printf '%s\n' "$$" > "$st/stage.lock"
run --selftest-lock
ul_t_check "lock: a live pid refuses" ul_t_ne "$RC" 0
ul_t_check "lock: the refusal names the pid" ul_t_has "$OUT" "^error another update is staging (pid $$)"
ul_t_check "lock: a refused acquire leaves the live lock alone" ul_t_eq "$(cat "$st/stage.lock")" "$$"
printf '%s\n' "$DEAD" > "$st/stage.lock"
cg worktree add -q --detach "$st/wt" HEAD
run --selftest-lock
ul_t_check "lock: a dead pid is taken over" ul_t_has "$OUT" '^lock=acquired pid='
ul_t_check "lock: taking over a dead lock clears the old worktree" ul_t_not test -d "$st/wt"
ul_t_check "lock: ... and released again at exit" ul_t_not test -e "$st/stage.lock"
printf 'not-a-pid\n' > "$st/stage.lock"
run --selftest-lock
ul_t_check "lock: a garbage lock file counts as stale" ul_t_has "$OUT" '^lock=acquired pid='

# a terminated holder still releases (TERM becomes an exit, so the EXIT trap runs)
( cd "$W_CUST" && exec "$SH" "$ENGINE" --selftest-lock 20 </dev/null >"$st/hold.out" 2>&1 ) &
HOLD=$!
n=0; while [ ! -f "$st/stage.lock" ] && [ "$n" -lt 20 ]; do sleep 1; n=$((n + 1)); done
ul_t_check "lock: a holder writes its own pid" ul_t_eq "$(cat "$st/stage.lock" 2>/dev/null)" "$HOLD"
kill -TERM "$HOLD" 2>/dev/null
n=0; while kill -0 "$HOLD" 2>/dev/null && [ "$n" -lt 10 ]; do sleep 1; n=$((n + 1)); done
wait "$HOLD" 2>/dev/null
ul_t_check "lock: a TERM releases the lock" ul_t_not test -e "$st/stage.lock"

# ======================================================= 6. --bootstrap-copy
nw
chmod +x "$W_UP/plugins/loom-maintenance/scripts/json-flat.sh"
chmod -x "$W_UP/plugins/loom-maintenance/scripts/json-valid.sh"
ul_t_commit "$W_UP" "one script executable, one not" >/dev/null
run --bootstrap-copy
gd=$(gitdir); BD=$gd/loom/bootstrap
ul_t_check "bootstrap-copy exits 0" ul_t_eq "$RC" 0
ul_t_check "bootstrap-copy prints bootstrap_dir" ul_t_eq "$(kv bootstrap_dir)" "$BD"
ul_t_check "bootstrap-copy prints the engine path" ul_t_eq "$(kv engine)" "$BD/update-loom.sh"
ul_t_check "bootstrap-copy: update-loom.sh is upstream's, byte for byte" ul_t_eq "$(cg show "refs/loom-upstream/main:plugins/loom-maintenance/scripts/update-loom.sh" | cksum)" "$(cksum < "$BD/update-loom.sh")"
for f in update-loom-common.sh json-valid.sh json-flat.sh; do
  ul_t_check "bootstrap-copy: $f is copied" ul_t_eq "$(cg show "refs/loom-upstream/main:plugins/loom-maintenance/scripts/$f" | cksum)" "$(cksum < "$BD/$f")"
done
ul_t_check "upstream really has json-flat.sh as 100755" ul_t_eq "$(cg ls-tree refs/loom-upstream/main plugins/loom-maintenance/scripts/json-flat.sh | cut -d' ' -f1)" 100755
ul_t_check "upstream really has json-valid.sh as 100644" ul_t_eq "$(cg ls-tree refs/loom-upstream/main plugins/loom-maintenance/scripts/json-valid.sh | cut -d' ' -f1)" 100644
ul_t_check "bootstrap-copy: mode follows the tree (100755 is executable)" test -x "$BD/json-flat.sh"
ul_t_check "bootstrap-copy: mode follows the tree (100644 is not)" ul_t_not test -x "$BD/json-valid.sh"
ul_t_check "bootstrap-copy: touches nothing in the working tree" ul_t_eq "$(cg status --porcelain | wc -l | tr -d ' ')" 0
echo stale > "$BD/leftover.sh"
run --bootstrap-copy
ul_t_check "bootstrap-copy: clears what an earlier copy left" ul_t_not test -e "$BD/leftover.sh"
OUT=$(cd "$W_CUST" && "$SH" "$BD/update-loom.sh" --status </dev/null 2>&1); RC=$?
ul_t_check "bootstrap-copy: the copy runs from inside .git and finds the repo" ul_t_eq "$(kv base)" "$W_BASE"
ul_t_check "bootstrap-copy: the copy reports the same upstream" ul_t_eq "$(kv upstream_head)" "$(cg rev-parse refs/loom-upstream/main)"

nw
run --upstream-url "$W_UP/nope" --i-am-pointing-at-a-fork --bootstrap-copy
ul_t_check "bootstrap-copy: no fetch and no earlier ref is an error" ul_t_ne "$RC" 0
ul_t_check "bootstrap-copy: ... naming the fetch" ul_t_has "$OUT" '^error could not fetch upstream from '
run --status
run --upstream-url "$W_UP/nope" --i-am-pointing-at-a-fork --bootstrap-copy
ul_t_check "bootstrap-copy: a failed refresh falls back to the ref fetched earlier" ul_t_eq "$RC" 0
ul_t_check "bootstrap-copy: ... and says so" ul_t_has "$OUT" '^notice=could not refresh upstream'

# ================================================== 7. the channel map (shipped)
# a repo with no map anywhere reads the built-in copy
BIN=$(ul_t_tmp); ul_t_git_init "$BIN/r"
printf 'x\n' > "$BIN/r/f"; ul_t_commit "$BIN/r" init >/dev/null
W_CUST_SAVED=$W_CUST; W_CUST=$BIN/r; ENGINE=$ENG_SRC
run --selftest-map dump
NOMAP_DUMP=$OUT
run --selftest-map dump --builtin
BUILTIN_DUMP=$OUT
ul_t_check "map: with no map anywhere the built-in is used" ul_t_eq "$NOMAP_DUMP" "$BUILTIN_DUMP"
ul_t_check "map: the built-in is non-empty" ul_t_has "$BUILTIN_DUMP" "^harness${TAB}"
# normalised dump of the shipped file, written independently of the engine
norm_map() { awk -F'=' '
  /^[ \t]*#/ || /^[ \t]*$/ { next }
  { k=$1; v=substr($0, index($0,"=")+1); gsub(/^[ \t]+|[ \t]+$/,"",k); gsub(/^[ \t]+|[ \t]+$/,"",v)
    n=index(v," :: "); a=v; b=""
    if (n>0) { a=substr(v,1,n-1); b=substr(v,n+4) }
    if (k=="manifest-version") print "version\t" a
    else if (k=="harness") print "harness\t" a "\t" b
    else if (k=="adopt-exclude") print "exclude\t" a
    else if (k=="rename") print "rename\t" a "\t" b
    else if (k=="merge") print "merge\t" a }' "$1"; }
SHIPPED=$(norm_map "$MAP_SRC" 2>/dev/null | sort)
ul_t_check "map: the shipped file exists" test -f "$MAP_SRC"
ul_t_check "map: the shipped file is not empty" test -n "$SHIPPED"
ul_t_check "map: the built-in copy equals the shipped file" ul_t_eq "$(printf '%s\n' "$BUILTIN_DUMP" | sort)" "$SHIPPED"
mkdir -p "$BIN/r/.logic-loom/config"
cp "$MAP_SRC" "$BIN/r/.logic-loom/config/update-channels.conf" 2>/dev/null
ul_t_commit "$BIN/r" "ship the map" >/dev/null
run --selftest-map dump
ul_t_check "map: the file loaded from HEAD equals the shipped file" ul_t_eq "$(printf '%s\n' "$OUT" | sort)" "$SHIPPED"
ul_t_check "map: manifest-version is 1" ul_t_has "$OUT" "^version${TAB}1\$"
ul_t_check "map: .logic-loom is group harness" ul_t_has "$OUT" "^harness${TAB}\\.logic-loom${TAB}harness\$"

if [ -f "$MANIFEST_SRC" ]; then
  # drift guard against the payload manifest: every include has a harness row, every exclude an adopt-exclude row
  INC=$(awk '/^include:/ { sub(/^include:[ \t]*/,""); sub(/[ \t]*#.*/,""); print }' "$MANIFEST_SRC" | sort)
  EXC=$(awk '/^exclude:/ { sub(/^exclude:[ \t]*/,""); sub(/[ \t]*#.*/,""); print }' "$MANIFEST_SRC" | sort)
  MH=$(printf '%s\n' "$BUILTIN_DUMP" | awk -F'\t' '$1=="harness" { print $2 }' | sort)
  ME=$(printf '%s\n' "$BUILTIN_DUMP" | awk -F'\t' '$1=="exclude" { print $2 }' | sort)
  ul_t_check "map: harness rows are exactly the manifest's include rows" ul_t_eq "$MH" "$INC"
  ul_t_check "map: adopt-exclude rows are exactly the manifest's exclude rows" ul_t_eq "$ME" "$EXC"
  ul_t_check "map: .claude/hooks is the only hooks group" ul_t_eq "$(printf '%s\n' "$BUILTIN_DUMP" | awk -F'\t' '$1=="harness" && $3=="hooks" { print $2 }')" .claude/hooks
  ul_t_check "map: the rename row matches the manifest" ul_t_has "$BUILTIN_DUMP" "^rename${TAB}AGENTS.md${TAB}.logic-loom/AGENTS.md\$"
  ul_t_check "map: merge rows match the manifest" ul_t_eq "$(printf '%s\n' "$BUILTIN_DUMP" | awk -F'\t' '$1=="merge" { print $2 }' | sort | tr '\n' ' ')" ".claude/settings.json .gitignore "
fi

mp() { run --selftest-map path "$1"; }
mp .claude/hooks/x.sh;                          ul_t_check "path: .claude/hooks/x.sh is group hooks" ul_t_has "$OUT" '^group=hooks excluded=no merge=no rename=-$'
mp .claude/commands/a.md;                       ul_t_check "path: .claude/commands/a.md is group harness" ul_t_has "$OUT" '^group=harness excluded=no merge=no'
mp .claude/hooksx/a.sh;                         ul_t_check "path: a longer name does not match a prefix" ul_t_has "$OUT" '^group=- '
mp .claude/settings.json;                       ul_t_check "path: settings.json is a merge path with no group" ul_t_has "$OUT" '^group=- excluded=no merge=yes'
mp tests/foo.sh;                                ul_t_check "path: tests/foo.sh is excluded" ul_t_has "$OUT" '^group=- excluded=yes'
mp tests;                                       ul_t_check "path: tests itself is excluded" ul_t_has "$OUT" '^group=- excluded=yes'
mp features/README.md;                          ul_t_check "path: features/README.md stays harness-owned" ul_t_has "$OUT" '^group=harness excluded=no'
mp features/foo/vision.md;                      ul_t_check "path: features/<name>/ files are excluded" ul_t_has "$OUT" '^group=- excluded=yes'
mp features/.gitkeep;                           ul_t_check "path: features/.gitkeep is harness" ul_t_has "$OUT" '^group=harness excluded=no'
mp .docs/guides/dev-main-template-split.md;     ul_t_check "path: a carve-out under a harness prefix is excluded" ul_t_has "$OUT" '^group=harness excluded=yes'
mp .docs/guides/other.md;                       ul_t_check "path: another guide is not excluded" ul_t_has "$OUT" '^group=harness excluded=no'
mp .logic-loom/tests/a.sh;                      ul_t_check "path: .logic-loom/tests is excluded" ul_t_has "$OUT" '^group=harness excluded=yes'
mp .docs/agents/a/b/decisions/x.md;             ul_t_check "path: a glob exclude matches" ul_t_has "$OUT" '^group=- excluded=yes'
mp .docs/agents/agent-registry.json;            ul_t_check "path: the registry file is harness" ul_t_has "$OUT" '^group=harness excluded=no'
mp lib/foo.js;                                  ul_t_check "path: a path outside every prefix has no group" ul_t_has "$OUT" '^group=- excluded=no merge=no rename=-$'
mp AGENTS.md;                                   ul_t_check "path: AGENTS.md renames into .logic-loom" ul_t_has "$OUT" 'rename=.logic-loom/AGENTS.md$'
mp .sdd-sync-ref;                               ul_t_check "path: .sdd-sync-ref is harness" ul_t_has "$OUT" '^group=harness excluded=no'

W_CUST=$W_CUST_SAVED; ENGINE=$ENGINE_SAVED

# the upstream copy of the map wins over HEAD's, then HEAD's over the built-in
nw
printf 'harness = extra-dir :: harness\n' >> "$W_UP/.logic-loom/config/update-channels.conf"
ul_t_commit "$W_UP" "upstream adds a prefix" >/dev/null
run --status
mp extra-dir/a
ul_t_check "map: the upstream copy is preferred over HEAD's" ul_t_has "$OUT" '^group=harness '
printf 'harness = head-only :: harness\n' >> "$W_CUST/.logic-loom/config/update-channels.conf"; cc "head adds a prefix"
mp head-only/a
ul_t_check "map: a row only in HEAD's copy is ignored while upstream's copy exists" ul_t_has "$OUT" '^group=- '
cg update-ref -d refs/loom-upstream/main
mp head-only/a
ul_t_check "map: without an upstream copy HEAD's is used" ul_t_has "$OUT" '^group=harness '
printf '# comment\n\nmanifest-version = 1\n  harness   =   spaced/dir   ::   hooks  \n' > "$W_CUST/.logic-loom/config/update-channels.conf"; cc "spacing"
mp spaced/dir/x
ul_t_check "map: spaces around = and :: are trimmed" ul_t_has "$OUT" '^group=hooks '

ul_t_done
