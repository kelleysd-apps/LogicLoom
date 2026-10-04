#!/bin/sh
# Cases for plugins/loom-maintenance/scripts/security-invariants.sh (rules R1-R5
# of design 1.10). POSIX sh. Prints PASS/FAIL lines; exit status is the overall
# result. Fixtures live in tests/update-loom/fixtures/invariants/, named by case.
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib.sh"

scripts="$UL_T_ROOT/plugins/loom-maintenance/scripts"
si="$scripts/security-invariants.sh"
fx="$UL_T_FIX/invariants"
tmp=$(ul_t_tmp)

S_SET=.claude/settings.json
S_TR=.claude/policies/tool-restrictions.json
S_GP=.logic-loom/config/gate-policy.conf
S_GV=.logic-loom/config/governance.conf
S_AM=.logic-loom/memory/amendments.md

# run ARGS... : OUT (stdout+stderr), RC, LAST (last output line)
run() {
  OUT=$("$SH" "$si" "$@" 2>&1 </dev/null)
  RC=$?
  LAST=$(printf '%s\n' "$OUT" | tail -1)
}

verdict() { # RC RULE [DETAIL-SUBSTRING]
  [ "$RC" = "$1" ] || return 1
  case $LAST in "rule=$2"|"rule=$2 "*) ;; *) return 1;; esac
  if [ -n "${3:-}" ]; then
    case $LAST in *"$3"*) ;; *) return 1;; esac
  fi
  return 0
}

t() { # NAME RC RULE DETAIL -- ARGS...
  t_n=$1; t_rc=$2; t_rule=$3; t_det=$4
  shift 5
  run "$@"
  if verdict "$t_rc" "$t_rule" "$t_det"; then
    printf 'PASS  %s\n' "$t_n"
  else
    printf 'FAIL  %s\n' "$t_n"
    printf '      expected rc=%s rule=%s detail~%s\n      got      rc=%s last=%s\n' "$t_rc" "$t_rule" "$t_det" "$RC" "$LAST"
    fail=1
  fi
}

# ts NAME RC RULE DETAIL CAND [opts...] : .claude/settings.json against s-mine.json
ts() {
  ts_n=$1; ts_rc=$2; ts_rule=$3; ts_det=$4; ts_c=$5
  shift 5
  t "$ts_n" "$ts_rc" "$ts_rule" "$ts_det" -- --surface "$S_SET" --mine "$fx/s-mine.json" --candidate "$ts_c" "$@"
}

# ================================================================== the script
ul_t_check "invariants: the script exists" test -f "$si"
ul_t_check "invariants: the script parses under sh -n" sh -n "$si"
if [ -x /bin/dash ]; then
  ul_t_check "invariants: the script parses under dash -n" /bin/dash -n "$si"
fi

# Marker for the write-nothing assertion at the end.
: > "$tmp/marker"

# ================================================================== no rule
printf 'hello\n' > "$tmp/foo.txt"
t "surface foo.txt has no rule: exit 0, rule=none" 0 none "" -- --surface foo.txt --mine "$tmp/foo.txt" --candidate "$tmp/foo.txt"
t "surface script.sh has no rule even when the candidate differs" 0 none "" -- --surface scripts/x.sh --mine "$tmp/foo.txt" --candidate "$fx/md-empty.md"

# usage errors are exit 2 with an error line, never a silent pass
run --mine "$fx/s-mine.json" --candidate "$fx/s-same.json"
ul_t_check "usage: a missing --surface is exit 2 with an error line" test "$RC" = 2 -a "${LAST%% *}" = error
run --surface "$S_SET" --mine "$fx/s-mine.json" --candidate "$tmp/does-not-exist.json"
ul_t_check "usage: a missing candidate file is exit 2 with an error line" test "$RC" = 2 -a "${LAST%% *}" = error
run --surface "$S_SET" --mine "$fx/s-mine.json" --candidate "$fx/s-same.json" --bogus
ul_t_check "usage: an unknown option is exit 2 with an error line" test "$RC" = 2 -a "${LAST%% *}" = error

# ============================================================ settings: pass
ts "settings: an unchanged candidate passes every rule" 0 ok "" "$fx/s-same.json"

# ====================================================================== R1
ts "R1 pass: the adopter hook survives, a listed harness hook is dropped" 0 ok "" \
  "$fx/s-r1-harness-dropped.json" --removes "$fx/removes-old-hook.txt"
ts "R1 fail: the adopter hook is dropped, the detail names the command" 1 R1 "guard-prod-db.sh" \
  "$fx/s-r1-adopter-dropped.json"
ts "R1 fail: the adopter hook keeps its command but its matcher changes Bash -> empty" 1 R1 "matcher" \
  "$fx/s-r1-matcher-changed.json"
ts "R1 fail: the matcher-change detail names the command and both matchers" 1 R1 "guard-prod-db.sh" \
  "$fx/s-r1-matcher-changed.json"
ts "R1 fail: a harness hook dropped and not listed in removes" 1 R1 "old-hook.sh" \
  "$fx/s-r1-harness-dropped.json"
ts "R1 fail: removes names only a prefix of the harness hook path" 1 R1 "old-hook.sh" \
  "$fx/s-r1-harness-dropped.json" --removes "$fx/removes-prefix-only.txt"
ts "R1 fail: an adopter hook named in removes is still preserved" 1 R1 "guard-prod-db.sh" \
  "$fx/s-r1-adopter-dropped.json" --removes "$fx/removes-adopter-hook.txt"
ts "R1 fail: both dropped, the removes list only covers the harness one" 1 R1 "guard-prod-db.sh" \
  "$fx/s-r1-both-dropped.json" --removes "$fx/removes-old-hook.txt"
ts "R1 pass: a candidate may ADD a hook (insertions are the note's business)" 0 ok "" \
  "$fx/s-same.json" --theirs "$fx/s-theirs.json"

# R1 on hand-built shapes: embedded line break, no .sh token, $CLAUDE_PROJECT_DIR spelling
cat > "$tmp/h-mine.json" <<'EOF'
{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"bash scripts/hooks/g.sh"},{"type":"command","command":"node tools/guard.js"}]}]}}
EOF
cat > "$tmp/h-cand-newline.json" <<'EOF'
{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"bash scripts/hooks/g.sh\nid"},{"type":"command","command":"node tools/guard.js"}]}]}}
EOF
t "R1 fail: a command with an extra line appended is a different command" 1 R1 "g.sh" -- \
  --surface "$S_SET" --mine "$tmp/h-mine.json" --candidate "$tmp/h-cand-newline.json" --theirs "$tmp/h-mine.json"
cat > "$tmp/h-cand-nojs.json" <<'EOF'
{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"bash scripts/hooks/g.sh"}]}]}}
EOF
printf 'tools/guard.js\n' > "$tmp/removes-js.txt"
t "R1 fail: a hook with no .sh token counts as the adopter's and survives removes" 1 R1 "guard.js" -- \
  --surface "$S_SET" --mine "$tmp/h-mine.json" --candidate "$tmp/h-cand-nojs.json" --theirs "$tmp/h-mine.json" --removes "$tmp/removes-js.txt"
cat > "$tmp/h-mine-env.json" <<'EOF'
{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/old-hook.sh"}]}]}}
EOF
printf '{"hooks":{}}\n' > "$tmp/h-cand-empty-hooks.json"
printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"bash scripts/hooks/other.sh"}]}]}}\n' > "$tmp/h-cand-other.json"
t "R1 pass: a \$CLAUDE_PROJECT_DIR spelling of a harness hook is removable by its path" 0 ok "" -- \
  --surface "$S_SET" --mine "$tmp/h-mine-env.json" --candidate "$tmp/h-cand-other.json" --theirs "$tmp/h-cand-other.json" --removes "$fx/removes-old-hook.txt"
t "R1 fail: the same hook is NOT removable without the removes entry" 1 R1 "old-hook.sh" -- \
  --surface "$S_SET" --mine "$tmp/h-mine-env.json" --candidate "$tmp/h-cand-other.json" --theirs "$tmp/h-cand-other.json"

# ====================================================================== R2 settings
ts "R2 fail: the deny list shrinks" 1 R2 "git push --force" "$fx/s-deny-shrunk.json"
ts "R2 pass: the deny list grows" 0 ok "" "$fx/s-deny-grown.json"
ts "R2 pass: allow gains an entry that is in theirs" 0 ok "" "$fx/s-allow-theirs.json" --theirs "$fx/s-theirs.json"
ts "R2 fail: allow gains an entry that is in neither mine nor theirs" 1 R2 "curl" "$fx/s-allow-unknown.json" --theirs "$fx/s-theirs.json"
ts "R2 fail: allow gains an entry and there is no --theirs at all" 1 R2 "npm test" "$fx/s-allow-theirs.json"
ts "R2 fail: an ask entry is dropped" 1 R2 "git reset" "$fx/s-ask-dropped.json"
ts "R2 pass: an ask entry that moved to deny is not a loss" 0 ok "" "$fx/s-ask-to-deny.json"
ts "R2 relaxes: exactly the exempted deny entry may go" 0 ok "" "$fx/s-deny-shrunk.json" --relaxes "$fx/relax-deny-force.tsv"
ts "R2 relaxes: a relax for a different entry does not exempt it" 1 R2 "git push --force" "$fx/s-deny-shrunk.json" --relaxes "$fx/relax-deny-other.tsv"
ts "R2 relaxes: a relax row for another surface does not count" 1 R2 "git push --force" "$fx/s-deny-shrunk.json" --relaxes "$fx/relax-other-surface.tsv"
ts "R2 relaxes: the list must match too (an ask relax does not exempt a deny)" 1 R2 "git push --force" "$fx/s-deny-shrunk.json" --relaxes "$fx/relax-ask-reset.tsv"
ts "R2 relaxes: an ask entry may be dropped when its row is listed" 0 ok "" "$fx/s-ask-dropped.json" --relaxes "$fx/relax-ask-reset.tsv"
ts "R2 relaxes: an allow gain may be exempted when its row is listed" 0 ok "" "$fx/s-allow-unknown.json" --relaxes "$fx/relax-allow-curl.tsv"

# ====================================================================== R5 settings
ts "R5 fail: invalid JSON is refused with rule=R5" 1 R5 "not valid JSON" "$fx/s-invalid.json"
ts "R5 fail: the enabledPlugins key is dropped" 1 R5 "enabledPlugins" "$fx/s-no-plugins.json"
ts "R5 fail: a new top-level key that is in neither mine nor theirs" 1 R5 "mystery" "$fx/s-newkey-mystery.json" --theirs "$fx/s-theirs.json"
ts "R5 pass: a new top-level key that upstream also has" 0 ok "" "$fx/s-newkey-statusline.json" --theirs "$fx/s-theirs.json"
ts "R5 fail: that same new key with no --theirs" 1 R5 "statusLine" "$fx/s-newkey-statusline.json"
printf '{"a":"x\\n/b"}\n' > "$tmp/spoof.json"
t "R5 fail: a string with an embedded line break then a slash cannot be compared safely" 1 R5 "line break" -- \
  --surface foo.json --mine "$tmp/spoof.json" --candidate "$tmp/spoof.json" --theirs "$tmp/spoof.json"
ts "R5 fail: an invalid upstream file (theirs) is refused" 1 R5 "upstream" "$fx/s-same.json" --theirs "$fx/s-invalid.json"
run --surface "$S_SET" --mine "$fx/s-invalid.json" --candidate "$fx/s-same.json" --theirs "$fx/s-same.json"
ul_t_check "R5 fail: a current file that is not valid JSON cannot be preserved" verdict 1 R5 "current"

# --tools: the validator comes from the given directory
mkdir "$tmp/tools"
cp "$scripts/json-valid.sh" "$scripts/json-flat.sh" "$tmp/tools/"
ts "tools: --tools pointing at a copy of the validators works" 0 ok "" "$fx/s-same.json" --tools "$tmp/tools"
mkdir "$tmp/notools"
ts "tools: --tools pointing at a directory with no validators fails closed" 1 R5 "" "$fx/s-same.json" --tools "$tmp/notools"

# ----------------------------------------------------- shape independence
compact() { # IN OUT : strip whitespace outside strings, join to one line
  awk '
  { sub(/\r$/, ""); buf = buf $0 "\n" }
  END {
    n = length(buf); out = ""; instr = 0; esc = 0
    for (i = 1; i <= n; i++) {
      c = substr(buf, i, 1)
      if (instr) {
        out = out c
        if (esc) esc = 0
        else if (c == "\\") esc = 1
        else if (c == "\"") instr = 0
        continue
      }
      if (c == "\"") { instr = 1; out = out c; continue }
      if (c == " " || c == "\t" || c == "\n" || c == "\r") continue
      out = out c
    }
    printf "%s", out
  }' "$1" > "$2"
}
crlf() { awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$1" > "$2"; }
for n in s-mine s-same s-r1-adopter-dropped s-r1-matcher-changed s-deny-shrunk s-ask-dropped s-no-plugins s-allow-unknown s-theirs; do
  compact "$fx/$n.json" "$tmp/$n.compact.json"
  crlf "$fx/$n.json" "$tmp/$n.crlf.json"
done
ul_t_check "shape: the compact fixture really is one line" test "$(wc -l < "$tmp/s-mine.compact.json" | tr -d ' ')" = 0
ul_t_check "shape: the CRLF fixture really has carriage returns" grep -q "$(printf '\r')" "$tmp/s-mine.crlf.json"
for form in compact crlf; do
  t "shape $form: unchanged candidate passes" 0 ok "" -- --surface "$S_SET" --mine "$tmp/s-mine.$form.json" --candidate "$tmp/s-same.$form.json"
  t "shape $form: dropped adopter hook fails R1 like the pretty file" 1 R1 "guard-prod-db.sh" -- --surface "$S_SET" --mine "$tmp/s-mine.$form.json" --candidate "$tmp/s-r1-adopter-dropped.$form.json"
  t "shape $form: changed matcher fails R1 like the pretty file" 1 R1 "matcher" -- --surface "$S_SET" --mine "$tmp/s-mine.$form.json" --candidate "$tmp/s-r1-matcher-changed.$form.json"
  t "shape $form: shrunk deny fails R2 like the pretty file" 1 R2 "git push --force" -- --surface "$S_SET" --mine "$tmp/s-mine.$form.json" --candidate "$tmp/s-deny-shrunk.$form.json"
  t "shape $form: dropped ask fails R2 like the pretty file" 1 R2 "git reset" -- --surface "$S_SET" --mine "$tmp/s-mine.$form.json" --candidate "$tmp/s-ask-dropped.$form.json"
  t "shape $form: dropped enabledPlugins fails R5 like the pretty file" 1 R5 "enabledPlugins" -- --surface "$S_SET" --mine "$tmp/s-mine.$form.json" --candidate "$tmp/s-no-plugins.$form.json"
  t "shape $form: allow gained from theirs passes" 0 ok "" -- --surface "$S_SET" --mine "$tmp/s-mine.$form.json" --candidate "$fx/s-allow-theirs.json" --theirs "$tmp/s-theirs.$form.json"
done
run --surface "$S_SET" --mine "$fx/s-mine.json" --candidate "$fx/s-r1-adopter-dropped.json"; pretty_out=$OUT
run --surface "$S_SET" --mine "$tmp/s-mine.compact.json" --candidate "$tmp/s-r1-adopter-dropped.crlf.json"; mixed_out=$OUT
ul_t_check "shape: pretty and compact-vs-CRLF runs print identical output" test "$pretty_out" = "$mixed_out"

# ----------------------------------------------------- missing --mine
t "missing mine: R1 and R2 pass trivially when theirs carries the content" 0 ok "" -- \
  --surface "$S_SET" --mine "$tmp/absent.json" --candidate "$fx/s-same.json" --theirs "$fx/s-same.json"
t "missing mine: R5 still validates the candidate" 1 R5 "not valid JSON" -- \
  --surface "$S_SET" --mine "$tmp/absent.json" --candidate "$fx/s-invalid.json" --theirs "$fx/s-same.json"
t "missing mine: R5 still checks the candidate keys against theirs" 1 R5 "mystery" -- \
  --surface "$S_SET" --mine "$tmp/absent.json" --candidate "$fx/s-newkey-mystery.json" --theirs "$fx/s-same.json"

# ====================================================================== tool-restrictions
tt() { # NAME RC RULE DETAIL CAND [opts...]
  tt_n=$1; tt_rc=$2; tt_rule=$3; tt_det=$4; tt_c=$5
  shift 5
  t "$tt_n" "$tt_rc" "$tt_rule" "$tt_det" -- --surface "$S_TR" --mine "$fx/tr-mine.json" --candidate "$tt_c" "$@"
}
tt "R2 tool-restrictions: an unchanged file passes" 0 ok "" "$fx/tr-same.json"
tt "R2 tool-restrictions: action block -> warn fails" 1 R2 "dangerous_commands" "$fx/tr-warn.json"
tt "R2 tool-restrictions: a pattern removed fails" 1 R2 "mkfs" "$fx/tr-pattern-removed.json"
tt "R2 tool-restrictions: a pattern added passes" 0 ok "" "$fx/tr-pattern-added.json"
tt "R2 tool-restrictions: a whole policy removed fails" 1 R2 "secrets" "$fx/tr-policy-removed.json"
tt "R2 tool-restrictions: a pattern relax exempts exactly that pattern" 0 ok "" "$fx/tr-pattern-removed.json" --relaxes "$fx/relax-tr-pattern.tsv"
tt "R2 tool-restrictions: an action relax exempts the downgrade" 0 ok "" "$fx/tr-warn.json" --relaxes "$fx/relax-tr-action.tsv"
tt "R2 tool-restrictions: a pattern relax does not exempt an action downgrade" 1 R2 "dangerous_commands" "$fx/tr-warn.json" --relaxes "$fx/relax-tr-pattern.tsv"
tt "R5 tool-restrictions: a dropped top-level key (version) fails with no exclusions" 1 R5 "version" "$fx/tr-version-dropped.json"
tt "R5 tool-restrictions: invalid JSON fails" 1 R5 "not valid JSON" "$fx/s-invalid.json"

# other *.json surfaces: R5 only
t "other json: R5 only, an unchanged file passes" 0 ok "" -- --surface .claude/policies/other.json --mine "$fx/tr-mine.json" --candidate "$fx/tr-same.json"
t "other json: a block -> warn downgrade is NOT an R2 matter here" 0 ok "" -- --surface .claude/policies/other.json --mine "$fx/tr-mine.json" --candidate "$fx/tr-warn.json"
t "other json: a dropped key still fails R5" 1 R5 "version" -- --surface .claude/policies/other.json --mine "$fx/tr-mine.json" --candidate "$fx/tr-version-dropped.json"

# ====================================================================== gate-policy.conf
tg() { # NAME RC RULE DETAIL CAND [opts...]
  tg_n=$1; tg_rc=$2; tg_rule=$3; tg_det=$4; tg_c=$5
  shift 5
  t "$tg_n" "$tg_rc" "$tg_rule" "$tg_det" -- --surface "$S_GP" --mine "$fx/gp-mine.conf" --candidate "$tg_c" "$@"
}
tg "R2 gate-policy: an unchanged file passes" 0 ok "" "$fx/gp-same.conf"
tg "R2 gate-policy: ask -> silent fails, the detail names the op" 1 R2 "git.push" "$fx/gp-push-silent.conf"
tg "R2 gate-policy: silent -> ask passes" 0 ok "" "$fx/gp-commit-ask.conf"
tg "R2 gate-policy: an op line dropped fails" 1 R2 "git.pull" "$fx/gp-pull-dropped.conf"
tg "R2 gate-policy: a verdict relax exempts exactly that op" 0 ok "" "$fx/gp-pull-silent.conf" --relaxes "$fx/gp-relax-pull.tsv"
tg "R2 gate-policy: a verdict relax for another op does not" 1 R2 "git.pull" "$fx/gp-pull-silent.conf" --relaxes "$fx/gp-relax-push.tsv"
tg "R2 gate-policy: a relax row for another surface does not" 1 R2 "git.pull" "$fx/gp-pull-silent.conf" --relaxes "$fx/gp-relax-other-surface.tsv"
tg "R2 gate-policy: a silent line placed before the ask line wins (first occurrence)" 1 R2 "git.pull" "$fx/gp-pull-shadowed.conf"
t "R2 gate-policy: a missing mine passes trivially" 0 ok "" -- --surface "$S_GP" --mine "$tmp/absent.conf" --candidate "$fx/gp-push-silent.conf"

# ====================================================================== governance.conf
tv() { # NAME RC RULE DETAIL CAND [opts...]
  tv_n=$1; tv_rc=$2; tv_rule=$3; tv_det=$4; tv_c=$5
  shift 5
  t "$tv_n" "$tv_rc" "$tv_rule" "$tv_det" -- --surface "$S_GV" --mine "$fx/gv-mine.conf" --candidate "$tv_c" "$@"
}
tv "R2 governance: an unchanged file passes" 0 ok "" "$fx/gv-same.conf"
tv "R2 governance: a protected_paths line dropped fails, the detail names it" 1 R2 "scripts/hooks" "$fx/gv-dropped.conf"
tv "R2 governance: a protected_paths line added passes" 0 ok "" "$fx/gv-added.conf"
tv "R2 governance: a relax exempts exactly that path" 0 ok "" "$fx/gv-dropped.conf" --relaxes "$fx/gv-relax-hooks.tsv"

# ====================================================================== R3 markdown
tm() { # NAME RC RULE DETAIL CAND [opts...]
  tm_n=$1; tm_rc=$2; tm_rule=$3; tm_det=$4; tm_c=$5
  shift 5
  t "$tm_n" "$tm_rc" "$tm_rule" "$tm_det" -- --surface CLAUDE.md --mine "$fx/md-mine.md" --candidate "$tm_c" "$@"
}
tm "R3 pass: an unchanged file" 0 ok "" "$fx/md-same.md"
tm "R3 fail: a heading dropped, the detail names it" 1 R3 "Directory structure" "$fx/md-heading-dropped.md"
tm "R3 pass: the dropped heading is listed in may-drop-headings" 0 ok "" "$fx/md-heading-dropped.md" --may-drop-headings "$fx/md-maydrop-dirstruct.txt"
tm "R3 pass: may-drop-headings tolerates padding, blank and unrelated lines" 0 ok "" "$fx/md-heading-dropped.md" --may-drop-headings "$fx/md-maydrop-padded.txt"
tm "R3 fail: may-drop-headings names a different heading" 1 R3 "Directory structure" "$fx/md-heading-dropped.md" --may-drop-headings "$fx/md-maydrop-other.txt"
tm "R3 fail: an empty candidate" 1 R3 "empty" "$fx/md-empty.md"
tm "R3 fail: a whitespace-only candidate is empty" 1 R3 "empty" "$fx/md-blank.md"
tm "R3 pass: a candidate with a new heading" 0 ok "" "$fx/md-new-heading.md"
tm "R3 pass: a level-4 heading is not a retained heading" 0 ok "" "$fx/md-level4-dropped.md"
t "R3 pass: a missing mine has nothing to retain" 0 ok "" -- --surface CLAUDE.md --mine "$tmp/absent.md" --candidate "$fx/md-same.md"
t "R3 fail: a missing mine still needs a non-empty candidate" 1 R3 "empty" -- --surface CLAUDE.md --mine "$tmp/absent.md" --candidate "$fx/md-empty.md"
crlf "$fx/md-mine.md" "$tmp/md-mine.crlf.md"
crlf "$fx/md-heading-dropped.md" "$tmp/md-dropped.crlf.md"
t "R3 shape crlf: a CRLF mine against an LF candidate keeps its headings" 0 ok "" -- --surface CLAUDE.md --mine "$tmp/md-mine.crlf.md" --candidate "$fx/md-same.md"
t "R3 shape crlf: a CRLF file with a dropped heading still fails" 1 R3 "Directory structure" -- --surface CLAUDE.md --mine "$tmp/md-mine.crlf.md" --candidate "$tmp/md-dropped.crlf.md"

# ====================================================================== R4 project-data
ladder_before=$UL_T_ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.before
ladder_after=$UL_T_ROOT/tests/fixtures/release-migrations/kori-amendments-ladder.after
pat='^[[:space:]-]*3[[:space:]]*=[[:space:]]*it changes auth, payment, or customer-data logic'
sed -e 's/^- 3 = it changes auth, payment, or customer-data logic$/- +3 = it changes auth, payment, or customer-data logic, on top of the reversibility line/' \
    -e 's/^  3 = it changes auth, payment, or customer-data logic$/  +3 = it changes auth, payment, or customer-data logic, on top of the reversibility line/' \
    "$ladder_before" > "$tmp/ladder-fixed.md"
grep -v -E "$pat" "$ladder_before" > "$tmp/ladder-deleted-only.md"
sed -e '/^Width:$/d' "$tmp/ladder-fixed.md" > "$tmp/ladder-width-dropped.md"
ul_t_check "R4 fixture: the fixed ladder differs from the before file" ul_t_not cmp -s "$ladder_before" "$tmp/ladder-fixed.md"
tp() { # NAME RC RULE DETAIL CAND [opts...]
  tp_n=$1; tp_rc=$2; tp_rule=$3; tp_det=$4; tp_c=$5
  shift 5
  t "$tp_n" "$tp_rc" "$tp_rule" "$tp_det" -- --surface "$S_AM" --project-data --mine "$ladder_before" --candidate "$tp_c" "$@"
}
tp "R4 pass: only the two pattern lines are deleted (kori ladder, both forms), new lines inserted" 0 ok "" "$tmp/ladder-fixed.md" --pattern "$pat"
tp "R4 pass: pure deletion of the pattern lines" 0 ok "" "$tmp/ladder-deleted-only.md" --pattern "$pat"
tp "R4 pass: an unchanged file" 0 ok "" "$ladder_before" --pattern "$pat"
tp "R4 fail: a non-pattern line is also deleted, the detail shows the line" 1 R4 "Width:" "$tmp/ladder-width-dropped.md" --pattern "$pat"
tp "R4 fail: the kori after-file edits lines outside the pattern" 1 R4 "Cost if this turns out wrong:" "$ladder_after" --pattern "$pat"
tp "R4 fail: a wiped file" 1 R4 "empty" "$fx/md-empty.md" --pattern "$pat"
tp "R4 fail: a missing --pattern" 1 R4 "pattern" "$tmp/ladder-fixed.md"
tp "R4 fail: an empty --pattern" 1 R4 "pattern" "$tmp/ladder-fixed.md" --pattern ""
tp "R4 fail: a --pattern that is not a valid expression" 1 R4 "pattern" "$tmp/ladder-fixed.md" --pattern "["
grep -v '^## Directory structure$' "$fx/md-mine.md" > "$tmp/md-heading-line-only.md"
t "R4 only: a project-data markdown file is not subject to R3 heading retention" 0 ok "" -- \
  --surface "$S_AM" --project-data --mine "$fx/md-mine.md" --candidate "$tmp/md-heading-line-only.md" --pattern '^## Directory structure$'
t "R3 control: the same heading-only deletion on a non-project-data file fails R3" 1 R3 "Directory structure" -- \
  --surface CLAUDE.md --mine "$fx/md-mine.md" --candidate "$tmp/md-heading-line-only.md"
t "R4 pass: a missing mine is all insertions" 0 ok "" -- --surface "$S_AM" --project-data --mine "$tmp/absent.md" --candidate "$tmp/ladder-fixed.md" --pattern "$pat"
t "R4 fail: a blank deleted line does not match the pattern" 1 R4 "" -- \
  --surface "$S_AM" --project-data --mine "$fx/md-mine.md" --candidate "$fx/md-heading-dropped.md" --pattern '^## '
t "project-data on a non-markdown surface is still R4" 1 R4 "pattern" -- --surface README.txt --project-data --mine "$ladder_before" --candidate "$tmp/ladder-fixed.md"

# ====================================================================== adversarial (review round)
# Each case below was a vacuous pass before the review fix it names.

# -- json-flat spoofing: an escaped slash (\/) decodes to / and starts a fake record
t "spoof: a command embedding a newline then an ESCAPED slash is refused (rule=R5), not read as the preserved hook" 1 R5 "line break" -- \
  --surface "$S_SET" --mine "$fx/r1-spoof-mine.json" --candidate "$fx/r1-spoof-escaped-slash.json" --theirs "$fx/r1-spoof-mine.json"
t "spoof: the same spoof with a plain slash is still refused" 1 R5 "line break" -- \
  --surface "$S_SET" --mine "$fx/r1-spoof-mine.json" --candidate "$fx/r1-spoof-plain-slash.json" --theirs "$fx/r1-spoof-mine.json"
t "spoof control: the honest mine file passes against itself" 0 ok "" -- \
  --surface "$S_SET" --mine "$fx/r1-spoof-mine.json" --candidate "$fx/r1-spoof-mine.json"

# -- object-indexed lists: {"0": ...} flattens like [ ... ] but Claude Code runs no hook from it
ts "shape: hooks written as objects with digit keys are refused (rule=R5) even though every triple is present" 1 R5 "digit" "$fx/s-objhooks.json"
ts "shape: a digit key split across lines (key, newline, colon) is still refused" 1 R5 "digit" "$fx/s-objhooks-split.json"
t "shape: tool-restrictions patterns written as an object with digit keys are refused" 1 R5 "digit" -- \
  --surface "$S_TR" --mine "$fx/tr-mine.json" --candidate "$fx/tr-objpatterns.json"
t "shape control: a plain *.json surface with digit keys is only R5 key-checked (digit keys are legal there)" 0 ok "" -- \
  --surface .claude/other.json --mine "$fx/tr-objpatterns.json" --candidate "$fx/tr-objpatterns.json"

# -- disableAllHooks is a one-key kill switch for every hook R1 preserves
t "R1: disableAllHooks false -> true is refused as a hook loss" 1 R1 "disableAllHooks" -- \
  --surface "$S_SET" --mine "$fx/s-dah-mine.json" --candidate "$fx/s-dah-flipped.json" --theirs "$fx/s-dah-mine.json"
t "R1: disableAllHooks unchanged passes" 0 ok "" -- \
  --surface "$S_SET" --mine "$fx/s-dah-mine.json" --candidate "$fx/s-dah-same.json"
t "R1: a candidate that ADDS disableAllHooks true to a file without it is refused under R1 first" 1 R1 "disableAllHooks" -- \
  --surface "$S_SET" --mine "$fx/s-prompt-mine.json" --candidate "$fx/s-dah-flipped.json" --theirs "$fx/s-dah-flipped.json"

# -- permissions posture outside the three lists (defaultMode, disableBypassPermissionsMode, additionalDirectories)
t "R2 posture: defaultMode default -> bypassPermissions is refused" 1 R2 "defaultMode" -- \
  --surface "$S_SET" --mine "$fx/s-posture-mine.json" --candidate "$fx/s-posture-bypass.json" --theirs "$fx/s-posture-mine.json"
t "R2 posture: dropping disableBypassPermissionsMode is refused" 1 R2 "disableBypassPermissionsMode" -- \
  --surface "$S_SET" --mine "$fx/s-posture-mine.json" --candidate "$fx/s-posture-switch-dropped.json"
t "R2 posture: an additionalDirectories entry in neither mine nor theirs is refused" 1 R2 "additionalDirectories" -- \
  --surface "$S_SET" --mine "$fx/s-posture-mine.json" --candidate "$fx/s-posture-adddir.json" --theirs "$fx/s-posture-mine.json"
t "R2 posture: an additionalDirectories entry that upstream carries passes" 0 ok "" -- \
  --surface "$S_SET" --mine "$fx/s-posture-mine.json" --candidate "$fx/s-posture-adddir.json" --theirs "$fx/s-posture-theirs-adddir.json"
t "R2 posture: unchanged posture passes" 0 ok "" -- \
  --surface "$S_SET" --mine "$fx/s-posture-mine.json" --candidate "$fx/s-posture-same.json"
t "R2 posture: a relax row <surface> TAB defaultMode TAB bypassPermissions exempts exactly that change" 0 ok "" -- \
  --surface "$S_SET" --mine "$fx/s-posture-mine.json" --candidate "$fx/s-posture-bypass.json" --relaxes "$fx/relax-posture-defaultmode.tsv"
t "R2 posture: a relax row for another sub-key does not exempt defaultMode" 1 R2 "defaultMode" -- \
  --surface "$S_SET" --mine "$fx/s-posture-mine.json" --candidate "$fx/s-posture-bypass.json" --relaxes "$fx/relax-posture-switch.tsv"
t "R2 posture: upstream carrying the loosened value does not license changing MY value" 1 R2 "defaultMode" -- \
  --surface "$S_SET" --mine "$fx/s-posture-mine.json" --candidate "$fx/s-posture-bypass.json" --theirs "$fx/s-posture-bypass.json"

# -- prompt-type hooks are hooks too
t "R1: a prompt-type hook dropped is refused, the detail quotes the prompt" 1 R1 "prod database" -- \
  --surface "$S_SET" --mine "$fx/s-prompt-mine.json" --candidate "$fx/s-prompt-dropped.json" --theirs "$fx/s-prompt-mine.json"
t "R1: a prompt-type hook moved to another matcher is refused" 1 R1 "matcher" -- \
  --surface "$S_SET" --mine "$fx/s-prompt-mine.json" --candidate "$fx/s-prompt-matcher.json" --theirs "$fx/s-prompt-mine.json"
t "R1: a prompt-type hook kept passes" 0 ok "" -- \
  --surface "$S_SET" --mine "$fx/s-prompt-mine.json" --candidate "$fx/s-prompt-same.json"
t "R1: a prompt-type hook is the adopter's: removes cannot name it away" 1 R1 "prod database" -- \
  --surface "$S_SET" --mine "$fx/s-prompt-mine.json" --candidate "$fx/s-prompt-dropped.json" --removes "$fx/removes-prompt-text.txt"

# -- gate-policy: mode.<x> = enforce|relax is a verdict too, and keys carry capitals
tg2() { # NAME RC RULE DETAIL MINE CAND [opts...]
  tg2_n=$1; tg2_rc=$2; tg2_rule=$3; tg2_det=$4; tg2_m=$5; tg2_c=$6
  shift 6
  t "$tg2_n" "$tg2_rc" "$tg2_rule" "$tg2_det" -- --surface "$S_GP" --mine "$tg2_m" --candidate "$tg2_c" "$@"
}
tg2 "R2 gate-policy: mode.bypassPermissions enforce -> relax is refused, the detail names the key" 1 R2 "mode.bypassPermissions" "$fx/gp-mode-mine.conf" "$fx/gp-mode-relaxed.conf"
# governance-verdicts.sh reads an absent mode line as enforce (_loom_gate_mode_action
# falls back to the enforce defaults), so dropping one loses nothing; an absent OP
# line falls to a built-in default that may be silent, so that one stays a loss.
tg2 "R2 gate-policy: an enforce mode line dropped passes (absent mode = enforce)" 0 ok "" "$fx/gp-mode-mine.conf" "$fx/gp-mode-dontask-dropped.conf"
tg2 "R2 gate-policy: modes unchanged pass" 0 ok "" "$fx/gp-mode-mine.conf" "$fx/gp-mode-same.conf"
tg2 "R2 gate-policy: relax -> enforce (tightening) passes" 0 ok "" "$fx/gp-mode-mine-relaxed.conf" "$fx/gp-mode-same.conf"
tg2 "R2 gate-policy: a verdict relax row for mode.bypassPermissions exempts it" 0 ok "" "$fx/gp-mode-mine.conf" "$fx/gp-mode-relaxed.conf" --relaxes "$fx/gp-relax-mode.tsv"
tg2 "R2 gate-policy: mine's FIRST line wins too (silent shadowing ask in mine preserves nothing)" 0 ok "" "$fx/gp-mine-shadowed.conf" "$fx/gp-pull-silent.conf"

# -- inputs that exist but cannot be read must be an error, never an empty side
cp "$fx/gp-mine.conf" "$tmp/unreadable.conf"; chmod 000 "$tmp/unreadable.conf"
cp "$fx/s-mine.json" "$tmp/unreadable.json"; chmod 000 "$tmp/unreadable.json"
if [ -r "$tmp/unreadable.conf" ]; then
  printf 'PASS  unreadable-file cases skipped: this user can read mode-000 files (root)\n'
else
  run --surface "$S_GP" --mine "$tmp/unreadable.conf" --candidate "$fx/gp-push-silent.conf"
  ul_t_check "usage: an unreadable --mine conf is exit 2 with an error line, not an empty mine" test "$RC" = 2 -a "${LAST%% *}" = error
  run --surface "$S_SET" --mine "$tmp/unreadable.json" --candidate "$fx/s-r1-adopter-dropped.json"
  ul_t_check "usage: an unreadable --mine json is exit 2 with an error line" test "$RC" = 2 -a "${LAST%% *}" = error
  run --surface "$S_SET" --mine "$fx/s-mine.json" --candidate "$tmp/unreadable.json"
  ul_t_check "usage: an unreadable --candidate is exit 2 with an error line" test "$RC" = 2 -a "${LAST%% *}" = error
  run --surface "$S_SET" --mine "$fx/s-mine.json" --candidate "$fx/s-r1-harness-dropped.json" --removes "$tmp/unreadable.conf"
  ul_t_check "usage: an unreadable --removes file is exit 2, not an empty list" test "$RC" = 2 -a "${LAST%% *}" = error
  run --surface CLAUDE.md --mine "$tmp/unreadable.conf" --candidate "$fx/md-same.md"
  ul_t_check "usage: an unreadable markdown --mine is exit 2" test "$RC" = 2 -a "${LAST%% *}" = error
fi
chmod 644 "$tmp/unreadable.conf" "$tmp/unreadable.json"
run --surface "$S_SET" --mine "$tmp" --candidate "$fx/s-same.json" --theirs "$fx/s-same.json"
ul_t_check "usage: a --mine that is a directory is exit 2 with an error line" test "$RC" = 2 -a "${LAST%% *}" = error
run --surface "$S_SET" --mine "$fx/s-mine.json" --candidate "$tmp"
ul_t_check "usage: a --candidate that is a directory is exit 2 with an error line" test "$RC" = 2 -a "${LAST%% *}" = error

# -- the JSON tools are trusted, so they are proven alive before anything is judged
mkdir "$tmp/badtools"
printf '#!/bin/sh\nexit 0\n' > "$tmp/badtools/json-flat.sh"
printf '#!/bin/sh\nexit 0\n' > "$tmp/badtools/json-valid.sh"
ts "tools: a tools dir whose scripts exit 0 printing nothing fails closed (rule=R5), never rule=ok" 1 R5 "tools" "$fx/s-r1-adopter-dropped.json" --tools "$tmp/badtools"
mkdir "$tmp/yestools"
cp "$scripts/json-flat.sh" "$tmp/yestools/"
printf '#!/bin/sh\nexit 0\n' > "$tmp/yestools/json-valid.sh"
ts "tools: a validator that accepts everything fails the self-test" 1 R5 "tools" "$fx/s-same.json" --tools "$tmp/yestools"

# -- a tool failing mid-run must never read as an empty side
mkdir "$tmp/fakebin"
printf '#!/bin/sh\nexit 1\n' > "$tmp/fakebin/awk"; chmod 755 "$tmp/fakebin/awk"
OUT=$(PATH="$tmp/fakebin:$PATH" "$SH" "$si" --surface "$S_GP" --mine "$fx/gp-mine.conf" --candidate "$fx/gp-push-silent.conf" 2>&1 </dev/null); RC=$?; LAST=$(printf '%s\n' "$OUT" | tail -1)
ul_t_check "tools: a failing awk makes the gate-policy rule refuse, not pass" test "$RC" != 0 -a "$LAST" != rule=ok
OUT=$(PATH="$tmp/fakebin:$PATH" "$SH" "$si" --surface CLAUDE.md --mine "$fx/md-mine.md" --candidate "$fx/md-heading-dropped.md" 2>&1 </dev/null); RC=$?; LAST=$(printf '%s\n' "$OUT" | tail -1)
ul_t_check "tools: a failing awk makes the markdown rule refuse, not pass" test "$RC" != 0 -a "$LAST" != rule=ok
OUT=$(PATH="$tmp/fakebin:$PATH" "$SH" "$si" --surface "$S_SET" --mine "$fx/s-mine.json" --candidate "$fx/s-r1-adopter-dropped.json" 2>&1 </dev/null); RC=$?; LAST=$(printf '%s\n' "$OUT" | tail -1)
ul_t_check "tools: a failing awk makes the settings rules refuse, not pass" test "$RC" != 0 -a "$LAST" != rule=ok

# ====================================================================== all violations are listed
run --surface "$S_SET" --mine "$fx/s-mine.json" --candidate "$fx/s-r1-both-dropped.json"
ul_t_check "output: every violation prints a violation line before the rule line" test "$(printf '%s\n' "$OUT" | grep -c '^violation R1 ')" -ge 2
ul_t_check "output: the last line is rule=R<n> detail=<sentence>" ul_t_has "$LAST" '^rule=R1 detail=.'
run --surface "$S_SET" --mine "$fx/s-mine.json" --candidate "$fx/s-deny-shrunk.json"
ul_t_check "output: a single violation prints one violation line and the rule line" test "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" = 2

# ====================================================================== housekeeping
# The script writes nothing outside $TMPDIR, and cleans what it wrote there.
td=$(ul_t_tmp)
OUT=$(TMPDIR="$td" "$SH" "$si" --surface "$S_SET" --mine "$fx/s-mine.json" --candidate "$fx/s-r1-both-dropped.json" 2>&1 </dev/null)
ul_t_check "housekeeping: a failing run leaves nothing behind in TMPDIR" test -z "$(ls -A "$td")"
OUT=$(TMPDIR="$td" "$SH" "$si" --surface "$S_SET" --mine "$fx/s-mine.json" --candidate "$fx/s-same.json" 2>&1 </dev/null)
ul_t_check "housekeeping: a passing run leaves nothing behind in TMPDIR" test -z "$(ls -A "$td")"
found=$(find "$fx" "$si" -newer "$tmp/marker" 2>/dev/null)
ul_t_check "housekeeping: nothing under the fixtures or the script itself was written by any case" test -z "$found"

ul_t_done
