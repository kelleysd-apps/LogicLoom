#!/bin/sh
# Cases for plugins/loom-maintenance/scripts/updates-checks.sh (the standalone
# checks runner). POSIX sh. Prints PASS/FAIL lines; exit status is the result.
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib.sh"

scripts="$UL_T_ROOT/plugins/loom-maintenance/scripts"
runner="$scripts/updates-checks.sh"
fx="$UL_T_FIX/lint"
notes="$UL_T_FIX/notes/7.0.0"

# The five maintainer-only markers, from the library under test.
lib_here=$here
here=$scripts
. "$scripts/update-loom-common.sh"
here=$lib_here

# runr ARGS... : sets COUT and CRC.
runr() {
  COUT=$("$SH" "$runner" "$@" 2>&1)
  CRC=$?
}
# line COUT-prefix : the first output line that starts with PREFIX
has_line() { printf '%s\n' "$COUT" | grep -q -- "$1"; }
no_line() { ! printf '%s\n' "$COUT" | grep -q -- "$1"; }
last_line() { printf '%s\n' "$COUT" | tail -n 1; }

# plant_markers DIR : the five files that make a tree a template repo
plant_markers() {
  printf '%s\n' "$UL_COPY_MARKERS" | while IFS= read -r _m; do
    mkdir -p "$1/$(dirname "$_m")"
    printf '#\n' > "$1/$_m"
  done
}

# ------------------------------------------------------------------ the script
ul_t_check "checks: the script exists" test -f "$runner"
ul_t_check "checks: the script parses under sh -n" sh -n "$runner"
if [ -x /bin/dash ]; then
  ul_t_check "checks: the script parses under dash -n" /bin/dash -n "$runner"
fi
ul_t_check "checks: the script starts with a sh shebang" sh -c "head -n 1 '$runner' | grep -Fxq '#!/bin/sh'"
ul_t_check "checks: the script sets set -u" grep -q '^set -u' "$runner"

# ------------------------------------------------- the customer tree (copy mode)
w=$(ul_t_tmp)
ul_t_world "$w"
mkdir -p "$W_CUST/plugins/loom-maintenance/updates/7.0.0"
cp -R "$notes/." "$W_CUST/plugins/loom-maintenance/updates/7.0.0/"
cust_runner=$W_CUST/plugins/loom-maintenance/scripts/updates-checks.sh
COUT=$(cd "$W_CUST" && "$SH" "$cust_runner" 2>&1); CRC=$?
ul_t_check "customer: the installed copy runs with the default root" test -n "$COUT"
runr --root "$W_CUST"
ul_t_check "customer: exits 1 (a safety check fails)" ul_t_eq "$CRC" 1
ul_t_check "customer: mode=copy" has_line '^mode=copy$'
ul_t_check "customer: the linter ran and passed" has_line '^PASS updates-lint$'
ul_t_check "customer: hooks-guard-dangerous is FAIL" has_line '^FAIL hooks-guard-dangerous$'
ul_t_check "customer: fixture-doc-guidance is WARN" has_line '^WARN fixture-doc-guidance$'
ul_t_check "customer: amendments-ladder-plus-three is WARN (defect present)" has_line '^WARN amendments-ladder-plus-three$'
ul_t_check "customer: fixture-doc-followup is WARN" has_line '^WARN fixture-doc-followup$'
ul_t_check "customer: settings-ask-restore is WARN" has_line '^WARN settings-ask-restore$'
ul_t_check "customer: summary is notes=5 failed=1" ul_t_eq "$(last_line)" "notes=5 failed=1"
# the failing check's hint is replayed after the per-note lines
ul_t_check "customer: the safety hint is replayed" \
  has_line '^hint=The dangerous-command guard is not wired into .claude/settings.json'
hint_n=$(printf '%s\n' "$COUT" | grep -n '^hint=' | head -n 1 | cut -d: -f1)
fail_n=$(printf '%s\n' "$COUT" | grep -n '^FAIL hooks-guard-dangerous$' | head -n 1 | cut -d: -f1)
ul_t_check "customer: the hint comes after the FAIL line" test "$hint_n" -gt "$fail_n"
ul_t_check "customer: only the failing note's hint is replayed (not the WARN hints)" \
  no_line '^hint=Restoring files from git'
# version order, then id order
order=$(printf '%s\n' "$COUT" | grep -E '^(PASS|WARN|FAIL|SKIP) [a-z]' | grep -v updates-lint | awk '{ print $2 }' | tr '\n' ' ')
ul_t_check "customer: notes run in id order within the release" \
  ul_t_eq "$order" "amendments-ladder-plus-three fixture-doc-followup fixture-doc-guidance hooks-guard-dangerous settings-ask-restore "

# ---------------------------------------- the upstream head, exported, no amendments
ex=$(ul_t_tmp)
git -C "$W_UP" archive HEAD | tar -x -C "$ex"
ul_t_check "head export: carries the notes" test -f "$ex/plugins/loom-maintenance/updates/7.0.0/hooks-guard-dangerous.md"
ul_t_check "head export: has no amendments file" ul_t_not test -e "$ex/.logic-loom/memory/amendments.md"
runr --root "$ex"
ul_t_check "head export: exits 0" ul_t_eq "$CRC" 0
ul_t_check "head export: mode=copy (no markers)" has_line '^mode=copy$'
ul_t_check "head export: hooks-guard-dangerous PASS" has_line '^PASS hooks-guard-dangerous$'
ul_t_check "head export: fixture-doc-guidance PASS" has_line '^PASS fixture-doc-guidance$'
ul_t_check "head export: fixture-doc-followup PASS" has_line '^PASS fixture-doc-followup$'
ul_t_check "head export: settings-ask-restore PASS" has_line '^PASS settings-ask-restore$'
ul_t_check "head export: the absent amendments file is a SKIP, not a PASS" \
  has_line '^SKIP amendments-ladder-plus-three no amendments file in this copy$'
ul_t_check "head export: nothing FAILs or WARNs" no_line '^\(FAIL\|WARN\) '
ul_t_check "head export: summary is notes=5 ok" ul_t_eq "$(last_line)" "notes=5 ok"

# ------------------------------------------------------------------ --only
runr --root "$W_CUST" --only settings-ask-restore
ul_t_check "--only: a WARN-only run exits 0" ul_t_eq "$CRC" 0
ul_t_check "--only: the chosen note is reported" has_line '^WARN settings-ask-restore$'
ul_t_check "--only: no other note is run" no_line '^\(PASS\|WARN\|FAIL\|SKIP\) \(fixture\|hooks\|amend\)'
ul_t_check "--only: summary counts one note" ul_t_eq "$(last_line)" "notes=1 ok"
runr --root "$W_CUST" --only hooks-guard-dangerous
ul_t_check "--only: a failing safety note exits 1" ul_t_eq "$CRC" 1
ul_t_check "--only: its summary is notes=1 failed=1" ul_t_eq "$(last_line)" "notes=1 failed=1"
ul_t_check "--only: the hint is replayed" has_line '^hint=The dangerous-command guard'
runr --root "$W_CUST" --only no-such-note
ul_t_check "--only: an unknown id is a failure" ul_t_eq "$CRC" 1
ul_t_check "--only: an unknown id is named" has_line '^FAIL no-such-note$'

# ------------------------------------------------------------ no notes at all
runr --root "$fx/empty-tree"
ul_t_check "no notes dir: notes=none" ul_t_eq "$COUT" "notes=none"
ul_t_check "no notes dir: exits 0" ul_t_eq "$CRC" 0
t=$(ul_t_tmp)
mkdir -p "$t/plugins/loom-maintenance/updates/7.0.0"
printf '# docs\n' > "$t/plugins/loom-maintenance/updates/7.0.0/README.md"
runr --root "$t"
ul_t_check "a README only: notes=none" ul_t_eq "$COUT" "notes=none"

# ------------------------------------------- notes present, the linter absent
solo=$(ul_t_tmp)
for f in updates-checks.sh update-loom-common.sh json-valid.sh json-flat.sh; do
  cp "$scripts/$f" "$solo/$f"
done
t=$(ul_t_tmp)
cp -R "$fx/ok-baseline/." "$t/"
COUT=$("$SH" "$solo/updates-checks.sh" --root "$t" 2>&1); CRC=$?
ul_t_check "no linter beside the runner: exits 1" ul_t_eq "$CRC" 1
ul_t_check "no linter beside the runner: FAIL updates-lint" has_line '^FAIL updates-lint$'
ul_t_check "no linter beside the runner: the summary says failed" has_line '^notes=1 failed='

# ------------------------------------------ the linter's own verdict is reported
runr --root "$fx/id-mismatch"
ul_t_check "a note the linter rejects: exits 1" ul_t_eq "$CRC" 1
ul_t_check "a note the linter rejects: FAIL updates-lint" has_line '^FAIL updates-lint$'
ul_t_check "a note the linter rejects: the linter's own lines are shown" has_line '^problem .*id-mismatch'

# --------------------------------------------- safety fails closed in every copy
runr --root "$fx/safety-check-none"
ul_t_check "safety note with check none: FAIL" has_line '^FAIL alpha$'
runr --root "$fx/bad-safety"
ul_t_check "malformed safety value: FAIL (treated as a safety note)" has_line '^FAIL alpha$'
runr --root "$fx/check-missing"
ul_t_check "non-safety note with a missing check file, copy mode: WARN" has_line '^WARN alpha$'
t=$(ul_t_tmp)
cp -R "$fx/check-missing/." "$t/"
plant_markers "$t"
runr --root "$t"
ul_t_check "non-safety note with a missing check file, template mode: FAIL" has_line '^FAIL alpha$'
# a safety note with a missing check file is FAIL in copy mode too
t=$(ul_t_tmp)
cp -R "$fx/check-missing/." "$t/"
sed 's/^safety: false/safety: true/' "$t/plugins/loom-maintenance/updates/7.0.0/alpha.md" > "$t/x.tmp" && mv "$t/x.tmp" "$t/plugins/loom-maintenance/updates/7.0.0/alpha.md"
runr --root "$t"
ul_t_check "safety note with a missing check file, copy mode: FAIL" has_line '^FAIL alpha$'
# check: none on a non-safety note is not an error (offered once, never re-verified)
runr --root "$fx/ok-check-none"
ul_t_check "non-safety check none: PASS" has_line '^PASS alpha$'
ul_t_check "non-safety check none: exits 0" ul_t_eq "$CRC" 0

# ---------------------------------------------- template-repo mode is stricter
# The same sabotage (the guidance sentence removed) in a copy and in a template.
copy_t=$(ul_t_tmp)
git -C "$W_UP" archive HEAD | tar -x -C "$copy_t"
cp "$UL_T_FIX/world/base/.docs/guides/FIXTURE.md" "$copy_t/.docs/guides/FIXTURE.md"
runr --root "$copy_t"
ul_t_check "copy mode: a failing non-safety check is WARN" has_line '^WARN fixture-doc-guidance$'
ul_t_check "copy mode: ... and the run stays green" ul_t_eq "$CRC" 0
ul_t_check "copy mode: ... summary ok" ul_t_eq "$(last_line)" "notes=5 ok"
tmpl_t=$(ul_t_tmp)
git -C "$W_UP" archive HEAD | tar -x -C "$tmpl_t"
plant_markers "$tmpl_t"
cp "$UL_T_FIX/world/base/.docs/guides/FIXTURE.md" "$tmpl_t/.docs/guides/FIXTURE.md"
runr --root "$tmpl_t"
ul_t_check "template mode: mode=template-repo" has_line '^mode=template-repo$'
ul_t_check "template mode: a failing non-safety check is FAIL" has_line '^FAIL fixture-doc-guidance$'
ul_t_check "template mode: the run fails" ul_t_eq "$CRC" 1
ul_t_check "template mode: summary notes=5 failed=1" ul_t_eq "$(last_line)" "notes=5 failed=1"
ul_t_check "template mode: the hint is replayed" has_line '^hint=The guide does not yet tell you to run /update-loom'
# four markers is still a customer copy
four=$(ul_t_tmp)
git -C "$W_UP" archive HEAD | tar -x -C "$four"
plant_markers "$four"
rm -f "$four/plugins/loom-maintenance/commands/promote.md"
cp "$UL_T_FIX/world/base/.docs/guides/FIXTURE.md" "$four/.docs/guides/FIXTURE.md"
runr --root "$four"
ul_t_check "four of five markers: still copy mode" has_line '^mode=copy$'

# ----------------------------------------------- skip= and exported variables
t=$(ul_t_tmp)
cp -R "$fx/ok-baseline/." "$t/"
cat > "$t/plugins/loom-maintenance/updates/7.0.0/alpha.check.sh" <<'EOF'
#!/bin/sh
# Check: skipped here.
set -u
[ -f docs/a.md ]
printf 'something first\n'
printf 'skip=not applicable in this copy\n'
exit 0
EOF
runr --root "$t"
ul_t_check "a check whose last line is skip= is SKIP" has_line '^SKIP alpha not applicable in this copy$'
ul_t_check "a SKIP is not a PASS" no_line '^PASS alpha$'
ul_t_check "a SKIP keeps the run green" ul_t_eq "$CRC" 0
# a skip= line that is not the last line is not a skip
cat > "$t/plugins/loom-maintenance/updates/7.0.0/alpha.check.sh" <<'EOF'
#!/bin/sh
# Check: early skip line.
set -u
[ -f docs/a.md ]
printf 'skip=early\n'
printf 'something after\n'
exit 0
EOF
runr --root "$t"
ul_t_check "skip= before the last line is a plain PASS" has_line '^PASS alpha$'
# skip= with a non-zero exit is a failure, not a skip
cat > "$t/plugins/loom-maintenance/updates/7.0.0/alpha.check.sh" <<'EOF'
#!/bin/sh
# Check: skip line with a failing exit.
set -u
[ -f docs/a.md ]
printf 'skip=but failing\n'
exit 1
EOF
runr --root "$t"
ul_t_check "skip= with a non-zero exit is not a skip" no_line '^SKIP alpha'

# UPDATE_TOOLS, REPO_ROOT and cwd as the check sees them (a safety note's hint is replayed)
t=$(ul_t_tmp)
cp -R "$fx/ok-baseline/." "$t/"
t_real=$(CDPATH= cd -- "$t" && pwd -P)
sed 's/^safety: false/safety: true/' "$t/plugins/loom-maintenance/updates/7.0.0/alpha.md" > "$t/x.tmp" && mv "$t/x.tmp" "$t/plugins/loom-maintenance/updates/7.0.0/alpha.md"
cat > "$t/plugins/loom-maintenance/updates/7.0.0/alpha.check.sh" <<'EOF'
#!/bin/sh
# Check: reports what it was handed. docs/a.md
set -u
[ -f docs/a.md ] && printf 'hint=tools=%s root=%s cwd=%s\n' "${UPDATE_TOOLS:-unset}" "${REPO_ROOT:-unset}" "$(pwd -P)"
exit 1
EOF
runr --root "$t"
ul_t_check "UPDATE_TOOLS defaults to the runner's own directory" has_line "^hint=tools=$scripts root=$t_real cwd=$t_real\$"
other=$(ul_t_tmp)
runr --root "$t" --tools "$other"
ul_t_check "UPDATE_TOOLS follows --tools" has_line "^hint=tools=$other root=$t_real cwd=$t_real\$"
ul_t_check "REPO_ROOT is the tree under test and cwd is its root" has_line "root=$t_real cwd=$t_real"

# a check run from a customer tree reads JSON through the exported tools dir
runr --root "$W_CUST" --tools "$scripts" --only settings-ask-restore
ul_t_check "a check finds json-flat.sh through UPDATE_TOOLS" has_line '^WARN settings-ask-restore$'
bare=$(ul_t_tmp)
git -C "$W_UP" archive HEAD | tar -x -C "$bare"
rm -f "$bare/plugins/loom-maintenance/scripts/json-flat.sh" "$bare/plugins/loom-maintenance/scripts/json-valid.sh"
runr --root "$bare" --tools "$scripts"
ul_t_check "a tree without the json tools still passes when --tools names them" has_line '^PASS settings-ask-restore$'

# ------------------------------------------------------- hint replay ordering
runr --root "$W_CUST"
last=$(last_line)
ul_t_check "the final line is the summary" ul_t_has "$last" '^notes=[0-9]* \(ok\|failed=[0-9]*\)$'

# --------------------------------------------------------------- failing closed
# No scratch space: the runner stops with an error instead of reporting zero notes.
COUT=$(TMPDIR=/nonexistent/ul-t "$SH" "$runner" --root "$fx/ok-baseline" 2>&1); CRC=$?
ul_t_check "unusable TMPDIR: exits 1" ul_t_eq "$CRC" 1
ul_t_check "unusable TMPDIR: no notes= line is printed" no_line '^notes='
# A release folder that cannot be read is an error, never notes=none (an unreadable
# folder of safety notes must not read as "nothing to check"). Permissions do not
# bind root, so the case is skipped there.
if [ "$(id -u)" != 0 ]; then
  t=$(ul_t_tmp)
  cp -R "$fx/ok-baseline/." "$t/"
  chmod 000 "$t/plugins/loom-maintenance/updates/7.0.0"
  runr --root "$t"
  chmod 755 "$t/plugins/loom-maintenance/updates/7.0.0"
  ul_t_check "unreadable release folder: exits 1" ul_t_eq "$CRC" 1
  ul_t_check "unreadable release folder: an error line names it" has_line '^error .*7\.0\.0'
  ul_t_check "unreadable release folder: no notes= line" no_line '^notes='
fi

# ------------------------------------------------------------- both interpreters
if [ -x /bin/dash ]; then
  d=$(/bin/dash "$runner" --root "$W_CUST" 2>&1)
  b=$(/bin/sh "$runner" --root "$W_CUST" 2>&1)
  ul_t_check "dash and sh agree on the customer tree" ul_t_eq "$d" "$b"
fi

# ------------------------------------------------------------ options and roots
runr --root "$fx/no-such-dir"
ul_t_check "a --root that is not a directory exits 2" ul_t_eq "$CRC" 2
runr --bogus
ul_t_check "an unknown option exits 2" ul_t_eq "$CRC" 2

ptmp=$(ul_t_tmp)
TMPDIR=$ptmp "$SH" "$runner" --root "$W_CUST" >/dev/null 2>&1
ul_t_check "no temp files left behind" ul_t_eq "$(ls "$ptmp" | wc -l | tr -d ' ')" 0

ul_t_done
