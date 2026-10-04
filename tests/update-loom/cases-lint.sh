#!/bin/sh
# Cases for plugins/loom-maintenance/scripts/updates-lint.sh (the note linter).
# POSIX sh. Prints PASS/FAIL lines; exit status is the overall result.
#
# Every rule has one planted-defect tree under tests/update-loom/fixtures/lint/<case>/
# (a tiny tree: plugins/loom-maintenance/updates/<release>/ notes plus the files
# they touch). The one rule that needs a sensitive string, id-marker, is built at
# test time from pieces so no tracked file carries the string.
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib.sh"

scripts="$UL_T_ROOT/plugins/loom-maintenance/scripts"
linter="$scripts/updates-lint.sh"
fx="$UL_T_FIX/lint"
notes="$UL_T_FIX/notes/7.0.0"
tab=$(printf '\t')

# lintr ROOT [ARGS...] : sets LOUT (stdout+stderr) and LRC.
lintr() {
  _root=$1; shift
  LOUT=$("$SH" "$linter" --root "$_root" "$@" 2>&1)
  LRC=$?
}
lint() { _c=$1; shift; lintr "$fx/$_c" "$@"; } # CASE [ARGS...]

# expect_problem NAME CASE NOTEID RULE PROBLEMS WARNINGS NOTES
expect_problem() {
  lint "$2"
  ul_t_check "$1: exits 1" ul_t_eq "$LRC" 1
  ul_t_check "$1: reports $4 on $3" ul_t_has "$LOUT" "^problem [^ ]*/$3\\.md $4: "
  ul_t_check "$1: summary line" ul_t_has "$LOUT" "^notes=$7 problems=$5 warnings=$6\$"
}
# expect_clean NAME CASE WARNINGS NOTES
expect_clean() {
  lint "$2"
  ul_t_check "$1: exits 0" ul_t_eq "$LRC" 0
  ul_t_check "$1: no problem lines" ul_t_hasnt "$LOUT" "^problem "
  ul_t_check "$1: summary line" ul_t_has "$LOUT" "^notes=$4 problems=0 warnings=$3\$"
}

# ------------------------------------------------------------------ the script
ul_t_check "lint: the script exists" test -f "$linter"
ul_t_check "lint: the script parses under sh -n" sh -n "$linter"
if [ -x /bin/dash ]; then
  ul_t_check "lint: the script parses under dash -n" /bin/dash -n "$linter"
fi
ul_t_check "lint: the script starts with a sh shebang" sh -c "head -n 1 '$linter' | grep -Fxq '#!/bin/sh'"
ul_t_check "lint: the script sets set -u" grep -q '^set -u' "$linter"

# ------------------------------------------------------ clean trees stay clean
expect_clean "baseline note" ok-baseline 0 1
expect_clean "protected path with a check" ok-protected-with-check 0 1
expect_clean "project-data note whose file is absent from the tree" ok-project-data 0 1
expect_clean "all three channel suffixes, @adopted path absent on disk" ok-channels 0 1
expect_clean "allowed check-body shapes raise no false positive" ok-check-body 0 1
expect_clean "requires an earlier release" ok-requires-earlier 0 2
expect_clean "releases sort as versions (10.0.0 may require 9.0.0)" ok-requires-numeric 0 2
expect_clean "relaxes on a non-safety note" ok-relaxes 0 1
expect_clean "may-drop-headings with a .md touch" ok-may-drop-md 0 1
expect_clean "removes-only note (touches empty, removed path absent)" ok-removes-only 0 1
expect_clean "README.md in a release folder is not a note" ok-readme-ignored 0 1
expect_clean "two notes sharing a path are not warned" overlap-two 0 2
expect_clean "notes in different releases do not form a group" overlap-cross-release 0 3

lint empty-tree
ul_t_check "no notes dir: exits 0" ul_t_eq "$LRC" 0
ul_t_check "no notes dir: summary" ul_t_hasline "$LOUT" "notes=0 problems=0 warnings=0"

# ------------------------------------------- the five real notes, in a world
w=$(ul_t_tmp)
ul_t_world "$w"
lintr "$W_UP"
ul_t_check "five real notes: exits 0" ul_t_eq "$LRC" 0
ul_t_check "five real notes: 0 problems" ul_t_hasnt "$LOUT" "^problem "
# Exactly 0 warnings, and why: every note names an executable check (no
# check: none warning), and the only shared path is .claude/settings.json held by
# two notes (the group is warned only above two).
ul_t_check "five real notes: exact summary (0 warnings: no check none, largest overlap group is 2)" \
  ul_t_hasline "$LOUT" "notes=5 problems=0 warnings=0"
ul_t_check "five real notes: no warn lines" ul_t_hasnt "$LOUT" "^warn "

# The customer's tree plus the notes: touches rows (FIXTURE-2.md is not applied
# yet) only hold in upstream's own tree, so the full lint finds them and
# --no-tree-rules does not.
cp -R "$notes/." "$W_CUST/plugins/loom-maintenance/updates/7.0.0/" 2>/dev/null || {
  mkdir -p "$W_CUST/plugins/loom-maintenance/updates/7.0.0"
  cp -R "$notes/." "$W_CUST/plugins/loom-maintenance/updates/7.0.0/"
}
lintr "$W_CUST"
ul_t_check "customer tree, full lint: touches-exists on the unapplied add" \
  ul_t_has "$LOUT" "^problem [^ ]*/fixture-doc-followup\\.md touches-exists: "
lintr "$W_CUST" --no-tree-rules
ul_t_check "customer tree, --no-tree-rules: clean" ul_t_eq "$LRC" 0
ul_t_check "customer tree, --no-tree-rules: summary" ul_t_hasline "$LOUT" "notes=5 problems=0 warnings=0"

# Removing a check from a real note is reported.
w2=$(ul_t_tmp)
ul_t_world "$w2"
rm -f "$W_UP/plugins/loom-maintenance/updates/7.0.0/settings-ask-restore.check.sh"
lintr "$W_UP"
ul_t_check "real note with its check removed: check-missing" \
  ul_t_has "$LOUT" "^problem [^ ]*/settings-ask-restore\\.md check-missing: "
ul_t_check "real note with its check removed: exits 1" ul_t_eq "$LRC" 1

# ------------------------------------------- LH rules, ported (frontmatter)
expect_problem "id differs from the file name" id-mismatch alpha id-mismatch 1 0 1
expect_problem "done-when key absent" missing-done-when alpha missing-key 1 0 1
ul_t_check "missing key names the key" ul_t_has "$(lint missing-done-when; printf '%s' "$LOUT")" "missing-key: .*done-when"
expect_problem "done-when with no items" empty-done-when alpha done-when-empty 1 0 1
expect_problem "check key absent" missing-check-key alpha missing-key 1 0 1
expect_problem "touches with no items and no removes" touches-empty alpha touches-empty 1 0 1
expect_problem "quoted-empty purpose counts as empty" purpose-quoted-empty alpha empty-key 1 0 1
expect_problem "folded purpose is not one line" purpose-folded alpha purpose-multiline 1 0 1
expect_problem "purpose continued on a second line" purpose-continued alpha purpose-multiline 1 0 1
expect_problem "safety is not true or false" bad-safety alpha safety-value 1 0 1
expect_problem "project-data is not true or false" bad-project-data alpha project-data-value 1 0 1
expect_problem "no frontmatter" no-frontmatter alpha no-frontmatter 1 0 1
expect_problem "check names a file that is absent" check-missing alpha check-missing 1 0 1
expect_problem "check is a path, not a sibling file name" check-path alpha check-name 1 0 1
expect_problem "check file with a syntax error" check-syntax alpha check-syntax 1 0 1
expect_problem "id reused in a later release" duplicate-id alpha id-duplicate 1 0 2
ul_t_check "duplicate id is reported on the later note" ul_t_has "$(lint duplicate-id; printf '%s' "$LOUT")" "^problem [^ ]*/7\\.1\\.0/alpha\\.md id-duplicate: "
expect_problem "quoted-blank purpose counts as empty" purpose-blank-quoted alpha empty-key 1 0 1
expect_problem "quoted-blank done-when item counts as no item" done-when-blank alpha done-when-empty 1 0 1
expect_problem "a list key written as a scalar (requires: beta) is refused" list-form-requires alpha list-form 1 0 1
lint list-form-touches
ul_t_check "a list key written as a scalar (touches: path): list-form" ul_t_has "$LOUT" "^problem [^ ]*/alpha\\.md list-form: "
ul_t_check "... and the list itself is empty" ul_t_has "$LOUT" "^problem [^ ]*/alpha\\.md touches-empty: "
ul_t_check "... summary" ul_t_hasline "$LOUT" "notes=1 problems=2 warnings=0"
# A duplicate list key: the library (what the engine reads notes with) takes every
# occurrence's items as part of the list, so a second touches: block would reach the
# engine unlinted unless the linter refuses the duplicate AND judges its rows.
lib_here=$here; here=$scripts; . "$scripts/update-loom-common.sh"; here=$lib_here
dk_fm=$(ul_frontmatter "$fx/duplicate-key/plugins/loom-maintenance/updates/7.0.0/alpha.md")
ul_t_check "library: both touches lists are read on a duplicate key" \
  ul_t_eq "$(ul_fm_list "$dk_fm" touches | tr '\n' ' ')" "docs/a.md web/app.js "
lint duplicate-key
ul_t_check "duplicate list key: duplicate-key" ul_t_has "$LOUT" "^problem [^ ]*/alpha\\.md duplicate-key: "
ul_t_check "duplicate list key: the second list's rows are judged too (forbidden-path)" \
  ul_t_has "$LOUT" "^problem [^ ]*/alpha\\.md forbidden-path: .*web/app\\.js"
ul_t_check "duplicate list key: exits 1" ul_t_eq "$LRC" 1
ul_t_check "duplicate list key: summary" ul_t_hasline "$LOUT" "notes=1 problems=2 warnings=0"

# --------------------------------------------------- new rules 1-4 (touches)
expect_problem "rule 1: channel suffix not in the set" bad-channel alpha touches-channel 1 0 1
expect_problem "rule 2: touches path absent on disk" touches-absent alpha touches-exists 1 0 1
expect_problem "rule 3: removes path still present" removes-present alpha removes-present 1 0 1
expect_problem "rule 4: touches under features/x/" forbidden-path alpha forbidden-path 1 0 1
expect_problem "touches path escaping the repo" row-path-parent alpha row-path 1 0 1
expect_problem "rule 1: channel suffix glued to the path (no space)" channel-glued alpha touches-channel 1 0 1

# the ledger and the applied dir are forbidden too: build trees on the fly
t=$(ul_t_tmp)
cp -R "$fx/ok-baseline/." "$t/"
mkdir -p "$t/.logic-loom/memory"
printf 'x\n' > "$t/.logic-loom/memory/update-ledger.tsv"
nf="$t/plugins/loom-maintenance/updates/7.0.0/alpha.md"
awk '{ print } /^touches:/ { print "  - .logic-loom/memory/update-ledger.tsv" }' "$nf" > "$t/x.tmp" && mv "$t/x.tmp" "$nf"
lintr "$t"
ul_t_check "rule 4: the ledger is forbidden" ul_t_has "$LOUT" "^problem [^ ]*/alpha\\.md forbidden-path: "
t=$(ul_t_tmp)
cp -R "$fx/ok-baseline/." "$t/"
mkdir -p "$t/.logic-loom/memory/updates"
printf 'x\n' > "$t/.logic-loom/memory/updates/x.applied"
nf="$t/plugins/loom-maintenance/updates/7.0.0/alpha.md"
awk '{ print } /^adds:/ { print "  - .logic-loom/memory/updates/x.applied" }' "$nf" | sed 's/^adds: \[\]$/adds:/' > "$t/x.tmp" && mv "$t/x.tmp" "$nf"
lintr "$t"
ul_t_check "rule 4: an adds row under the applied dir is forbidden" ul_t_has "$LOUT" "^problem [^ ]*/alpha\\.md forbidden-path: "

# --no-tree-rules turns the two on-disk rules off and nothing else
lint touches-absent --no-tree-rules
ul_t_check "--no-tree-rules: absent touches path is not reported" ul_t_eq "$LRC" 0
lint removes-present --no-tree-rules
ul_t_check "--no-tree-rules: present removes path is not reported" ul_t_eq "$LRC" 0
lint forbidden-path --no-tree-rules
ul_t_check "--no-tree-rules: the forbidden set still applies" ul_t_has "$LOUT" "forbidden-path: "

# ---------------------------------------------------- rule 5: project-data
expect_problem "rule 5: project-data without a pattern" project-data-no-pattern alpha project-data-pattern 1 0 1
expect_problem "rule 5: project-data with a quoted-empty pattern" project-data-empty-pattern alpha project-data-pattern 1 0 1
expect_problem "rule 5: project-data with two touches rows" project-data-two-touches alpha project-data-touches 1 0 1
expect_problem "rule 5: project-data touching a shipped file" project-data-not-allowed alpha project-data-allowed 1 0 1
expect_problem "rule 5: project-data with safety true" project-data-safety alpha project-data-safety 1 0 1
expect_problem "rule 5: project-data without the Example section" project-data-no-example alpha project-data-sections 1 0 1
expect_problem "rule 5: project-data without the may-claim section" project-data-no-claim alpha project-data-sections 1 0 1
expect_problem "rule 5: pattern that does not compile" project-data-bad-pattern alpha pattern-compiles 1 0 1

# ------------------------------------------- rules 6 and 7: checks required
expect_problem "rule 6: protected path with check none" protected-no-check alpha protected-needs-check 1 0 1
expect_problem "rule 6: posture path with check none" posture-no-check alpha protected-needs-check 1 0 1
expect_problem "rule 7: safety note with check none" safety-check-none alpha check-none-safety 1 0 1

lint ok-check-none
ul_t_check "rule 7: check none on a plain note is allowed (exit 0)" ul_t_eq "$LRC" 0
ul_t_check "rule 7: ... with the exact warning text" \
  ul_t_has "$LOUT" "^warn [^ ]*/alpha\\.md check: none means this note is offered once and never re-verified\$"
ul_t_check "rule 7: ... counted as one warning" ul_t_hasline "$LOUT" "notes=1 problems=0 warnings=1"

# ------------------------------------------------------------ rule 8: requires
lint requires-cycle
ul_t_check "rule 8: cycle exits 1" ul_t_eq "$LRC" 1
ul_t_check "rule 8: cycle reported on alpha" ul_t_has "$LOUT" "^problem [^ ]*/alpha\\.md requires-cycle: "
ul_t_check "rule 8: cycle reported on beta" ul_t_has "$LOUT" "^problem [^ ]*/beta\\.md requires-cycle: "
ul_t_check "rule 8: cycle summary" ul_t_has "$LOUT" "^notes=2 problems=2 warnings=0\$"
expect_problem "rule 8: requires an id that is no note" requires-unknown alpha requires-unknown 1 0 1
expect_problem "rule 8: requires a note in a later release" requires-later alpha requires-later 1 0 2
expect_problem "rule 8: 9.0.0 requiring 10.0.0 is a later release" requires-later-numeric alpha requires-later 1 0 2
expect_problem "rule 8: a safety note may not require a non-safety note" safety-requires-nonsafety alpha requires-safety 1 0 2

# ------------------------------------------------------------ rule 9: relaxes
expect_problem "rule 9: relaxes on a safety note" relaxes-safety alpha relaxes-safety 1 0 1
expect_problem "rule 9: relaxes entry in the wrong shape" relaxes-format alpha relaxes-format 1 0 1
expect_problem "rule 9: relaxes names a path the note does not touch" relaxes-path alpha relaxes-path 1 0 1
# the tab form is accepted as well as the documented :: form
t=$(ul_t_tmp)
cp -R "$fx/ok-relaxes/." "$t/"
nf="$t/plugins/loom-maintenance/updates/7.0.0/alpha.md"
awk -v tb="$tab" '/^  - \.claude\/settings\.json :: / { print "  - .claude/settings.json" tb "permissions.deny" tb "Bash(git push --force:*)"; next } { print }' "$nf" > "$t/x.tmp" && mv "$t/x.tmp" "$nf"
lintr "$t"
ul_t_check "rule 9: the tab-separated entry form is accepted" ul_t_eq "$LRC" 0

# ------------------------------------------------- rule 10: may-drop-headings
expect_problem "rule 10: may-drop-headings with no .md touch" may-drop-no-md alpha may-drop-headings 1 0 1

# ----------------------------------------------------- rule 11: overlap groups
lint overlap-three
ul_t_check "rule 11: a group of three exits 0" ul_t_eq "$LRC" 0
ul_t_check "rule 11: one overlap warning" ul_t_has "$LOUT" "^warn [^ ]*/7\\.0\\.0/alpha\\.md overlap: "
ul_t_check "rule 11: the group warning names all three" ul_t_has "$LOUT" "overlap: .*alpha.*beta.*gamma"
ul_t_check "rule 11: summary counts one warning" ul_t_has "$LOUT" "^notes=3 problems=0 warnings=1\$"

# --------------------------------------------------------- rule 12: check body
expect_problem "rule 12: curl in a check" check-curl alpha check-body-net 1 0 1
expect_problem "rule 12: wget in a check" check-wget alpha check-body-net 1 0 1
expect_problem "rule 12: git commit in a check" check-git-commit alpha check-body-git 1 0 1
expect_problem "rule 12: redirect to ./out" check-writes-out alpha check-body-redirect 1 0 1
expect_problem "rule 12: append redirect to a plain file" check-append-out alpha check-body-redirect 1 0 1
expect_problem "rule 12: eval in a check" check-eval alpha check-body-eval 1 0 1
expect_problem "rule 12: rm -rf in a check" check-rm alpha check-body-rm 1 0 1
expect_problem "rule 12: sourcing a working-tree file" check-source alpha check-body-source 1 0 1
expect_problem "rule 12: a check that mentions none of its paths" check-vacuous alpha check-body-vacuous 1 0 1
expect_problem "rule 12: sourcing a single-quoted path" check-source-quoted alpha check-body-source 1 0 1
expect_problem "rule 12: >| clobber redirect to a plain file" check-clobber-out alpha check-body-redirect 1 0 1
expect_problem "rule 12: an awk program that prints to a file (inside single quotes)" check-awk-print-out alpha check-body-redirect 1 0 1
expect_problem "rule 12: a redirect inside \$( ) inside double quotes" check-subst-out alpha check-body-redirect 1 0 1
expect_problem "rule 12: a path mentioned only in the hint= message is still vacuous" check-vacuous-hint alpha check-body-vacuous 1 0 1

# ------------------------------------------------------------ rule 13: markers
# Built from pieces so this file and the linter hold no marker string whole.
m1=brian@kelleysd; m1=$m1.com
m2=kelleysd; m2=$m2.com/
m3=ioun; m3=$m3-ai
m4=/workspace; m4=${m4}s/
m5='~/.claude'
n=0
for m in "$m1" "$m2" "$m3" "$m4" "$m5"; do
  n=$((n + 1))
  t=$(ul_t_tmp)
  cp -R "$fx/ok-baseline/." "$t/"
  printf '\nSee %s for details.\n' "$m" >> "$t/plugins/loom-maintenance/updates/7.0.0/alpha.md"
  lintr "$t"
  ul_t_check "rule 13: marker $n in a note body" ul_t_has "$LOUT" "^problem [^ ]*/alpha\\.md id-marker: "
  ul_t_check "rule 13: marker $n summary" ul_t_hasline "$LOUT" "notes=1 problems=1 warnings=0"
  t=$(ul_t_tmp)
  cp -R "$fx/ok-baseline/." "$t/"
  printf '# a code comment mentioning %s\n' "$m" >> "$t/plugins/loom-maintenance/updates/7.0.0/alpha.check.sh"
  lintr "$t"
  ul_t_check "rule 13: marker $n in a check body (even in a comment)" ul_t_has "$LOUT" "^problem [^ ]*/alpha\\.md id-marker: "
done

# ------------------------------------------------- rule 14: --upstream / --base
# A world where upstream flips git.merge from ask to silent in gate-policy.conf.
posture_world() { # DIR SAFETY CHANGE(flip|comment) TOUCHES(gate|none)
  ul_t_world "$1" || return 1
  _rel=plugins/loom-maintenance/updates/7.1.0
  mkdir -p "$W_UP/$_rel"
  case $3 in
    flip) sed 's/^git.merge = ask$/git.merge = silent/' "$W_UP/.logic-loom/config/gate-policy.conf" > "$W_UP/g.tmp";;
    comment) sed 's/^# Fixture gate policy.*/# Fixture gate policy, reworded./' "$W_UP/.logic-loom/config/gate-policy.conf" > "$W_UP/g.tmp";;
  esac
  mv "$W_UP/g.tmp" "$W_UP/.logic-loom/config/gate-policy.conf"
  if [ "$4" = gate ]; then _t=.logic-loom/config/gate-policy.conf; else _t=.docs/guides/FIXTURE.md; fi
  cat > "$W_UP/$_rel/posture-flip.md" <<EOF
---
id: posture-flip
title: A verdict changes
purpose: The merge verdict changes in the shipped gate policy.
touches:
  - $_t
adds: []
requires: []
safety: $2
done-when:
  - "the gate policy carries the new verdict"
check: posture-flip.check.sh
project-data: false
---

## What changed and why

The verdict changed.

## What a stock file looks like after

The file carries the new verdict.
EOF
  cat > "$W_UP/$_rel/posture-flip.check.sh" <<EOF
#!/bin/sh
# Check: the gate policy file exists. $_t
set -u
root=\${REPO_ROOT:-.}
if [ -f "\$root/$_t" ]; then
  exit 0
fi
printf 'hint=The file is missing.\n'
exit 1
EOF
  P_H3=$(ul_t_commit "$W_UP" "posture") || return 1
}
pw=$(ul_t_tmp)
posture_world "$pw" false flip gate
lintr "$W_UP" --base "$W_BASE" --upstream "$P_H3"
ul_t_check "rule 14: verdict flipped under safety false is a problem" \
  ul_t_has "$LOUT" "^problem [^ ]*/posture-flip\\.md posture-safety: "
ul_t_check "rule 14: exits 1" ul_t_eq "$LRC" 1
lintr "$W_UP"
ul_t_check "rule 14: without --upstream/--base the rule does not run" ul_t_hasnt "$LOUT" "posture-safety"

pw=$(ul_t_tmp)
posture_world "$pw" true flip gate
lintr "$W_UP" --base "$W_BASE" --upstream "$P_H3"
ul_t_check "rule 14: the same flip under safety true is clean" ul_t_hasnt "$LOUT" "posture-safety"

pw=$(ul_t_tmp)
posture_world "$pw" false comment gate
lintr "$W_UP" --base "$W_BASE" --upstream "$P_H3"
ul_t_check "rule 14: a comment-only change under safety false is clean" ul_t_hasnt "$LOUT" "posture-safety"

pw=$(ul_t_tmp)
posture_world "$pw" false flip none
lintr "$W_UP" --base "$W_BASE" --upstream "$P_H3"
ul_t_check "rule 14: a note that does not touch the posture file is not judged" ul_t_hasnt "$LOUT" "posture-safety"

# protected_paths lines count the same way
pw=$(ul_t_tmp)
ul_t_world "$pw"
sed 's/^protected_paths = .*/protected_paths = .logic-loom\/config\/memory-backend.conf/' "$W_UP/.logic-loom/config/governance.conf" > "$W_UP/g.tmp"
printf 'protected_paths = .logic-loom/config/extra.conf\n' >> "$W_UP/g.tmp"
mv "$W_UP/g.tmp" "$W_UP/.logic-loom/config/governance.conf"
mkdir -p "$W_UP/plugins/loom-maintenance/updates/7.1.0"
cat > "$W_UP/plugins/loom-maintenance/updates/7.1.0/protect-more.md" <<'EOF'
---
id: protect-more
title: One more path is protected
purpose: The governance configuration protects one more path.
touches:
  - .logic-loom/config/governance.conf
adds: []
requires: []
safety: false
done-when:
  - "the governance configuration lists the extra path"
check: protect-more.check.sh
project-data: false
---

## What changed and why

One more path.

## What a stock file looks like after

One more line.
EOF
cat > "$W_UP/plugins/loom-maintenance/updates/7.1.0/protect-more.check.sh" <<'EOF'
#!/bin/sh
# Check: .logic-loom/config/governance.conf lists the extra path.
set -u
root=${REPO_ROOT:-.}
if grep -F 'extra.conf' "$root/.logic-loom/config/governance.conf" >/dev/null 2>&1; then
  exit 0
fi
printf 'hint=The extra path is not listed.\n'
exit 1
EOF
h3=$(ul_t_commit "$W_UP" "protected")
lintr "$W_UP" --base "$W_BASE" --upstream "$h3"
ul_t_check "rule 14: a changed protected_paths line under safety false is a problem" \
  ul_t_has "$LOUT" "^problem [^ ]*/protect-more\\.md posture-safety: "

# only one of the two flags is a usage error
lintr "$W_UP" --upstream "$h3"
ul_t_check "rule 14: --upstream without --base exits 2" ul_t_eq "$LRC" 2
lintr "$W_UP" --base "$W_BASE" --upstream 0000000000000000000000000000000000000000
ul_t_check "rule 14: an unknown revision exits 2" ul_t_eq "$LRC" 2

# The rule fails closed: a diff git cannot produce is reported as a problem, never
# read as "nothing changed". A git in front of the real one refuses `diff` only.
fb=$(ul_t_tmp)
realgit=$(command -v git)
cat > "$fb/git" <<EOF
#!/bin/sh
for a in "\$@"; do case \$a in diff) echo 'fatal: fixture refusal' >&2; exit 128;; esac; done
exec '$realgit' "\$@"
EOF
chmod +x "$fb/git"
LOUT=$(PATH="$fb:$PATH" "$SH" "$linter" --root "$W_UP" --base "$W_BASE" --upstream "$h3" 2>&1); LRC=$?
ul_t_check "rule 14: a diff git cannot produce is a problem, not a pass" \
  ul_t_has "$LOUT" "^problem [^ ]*/protect-more\\.md posture-safety: .*could not compare"
ul_t_check "rule 14: ... exits 1" ul_t_eq "$LRC" 1

# --------------------------------------------------------- options and roots
lintr "$fx/ok-baseline" --bogus
ul_t_check "an unknown option exits 2" ul_t_eq "$LRC" 2
lintr "$fx/no-such-dir"
ul_t_check "a --root that is not a directory exits 2" ul_t_eq "$LRC" 2

# an unreadable release folder is an error, never "no notes" (skipped as root,
# whom permissions do not bind)
if [ "$(id -u)" != 0 ]; then
  t=$(ul_t_tmp)
  cp -R "$fx/ok-baseline/." "$t/"
  chmod 000 "$t/plugins/loom-maintenance/updates/7.0.0"
  lintr "$t"
  chmod 755 "$t/plugins/loom-maintenance/updates/7.0.0"
  ul_t_check "unreadable release folder: exits 1" ul_t_eq "$LRC" 1
  ul_t_check "unreadable release folder: an error line names it" ul_t_has "$LOUT" "^error .*7\\.0\\.0"
  ul_t_check "unreadable release folder: no notes= summary" ul_t_hasnt "$LOUT" "^notes="
fi

# --notes-dir
t=$(ul_t_tmp)
mkdir -p "$t/docs" "$t/elsewhere"
cp "$fx/ok-baseline/docs/a.md" "$t/docs/a.md"
cp -R "$fx/ok-baseline/plugins/loom-maintenance/updates/." "$t/elsewhere/"
lintr "$t" --notes-dir elsewhere
ul_t_check "--notes-dir: lints the named folder" ul_t_hasline "$LOUT" "notes=1 problems=0 warnings=0"
lintr "$t"
ul_t_check "--notes-dir: the default folder is not there" ul_t_hasline "$LOUT" "notes=0 problems=0 warnings=0"

# default root: the git toplevel of cwd, else cwd
t=$(ul_t_tmp)
cp -R "$fx/ok-baseline/." "$t/"
LOUT=$(cd "$t" && "$SH" "$linter" 2>&1); LRC=$?
ul_t_check "default root outside git is cwd" ul_t_hasline "$LOUT" "notes=1 problems=0 warnings=0"
ul_t_git_init "$t/repo"
cp -R "$fx/ok-baseline/." "$t/repo/"
mkdir -p "$t/repo/sub/dir"
LOUT=$(cd "$t/repo/sub/dir" && "$SH" "$linter" 2>&1); LRC=$?
ul_t_check "default root inside a git repo is its toplevel" ul_t_hasline "$LOUT" "notes=1 problems=0 warnings=0"

# the finding line shape: problem <note path relative to --root> <reason>
lint id-mismatch
ul_t_check "finding lines name the note by its path under --root" \
  ul_t_has "$LOUT" "^problem plugins/loom-maintenance/updates/7.0.0/alpha\\.md id-mismatch: "

# running it under both interpreters gives the same answer on a planted case
if [ -x /bin/dash ]; then
  d=$(/bin/dash "$linter" --root "$fx/id-mismatch" 2>&1)
  b=$(/bin/sh "$linter" --root "$fx/id-mismatch" 2>&1)
  ul_t_check "dash and sh agree on a planted case" ul_t_eq "$d" "$b"
fi

# the linter leaves no temp files behind
ptmp=$(ul_t_tmp)
TMPDIR=$ptmp "$SH" "$linter" --root "$fx/id-mismatch" >/dev/null 2>&1
ul_t_check "no temp files left behind" ul_t_eq "$(ls "$ptmp" | wc -l | tr -d ' ')" 0

ul_t_done
