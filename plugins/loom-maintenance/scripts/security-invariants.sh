#!/bin/sh
# security-invariants.sh -- the deterministic rules R1-R5 of design 1.10 that sit
# between the adapter and the tree. The same code runs inside --adapt-save (refuse
# the body), in the --stage gate (fail the commit) and in post-landing smoke
# (auto-undo). Pure POSIX sh + awk over json-flat.sh output and conf lines; it reads
# files, writes nothing outside $TMPDIR (its own temp files, removed on exit) and
# runs no git.
#
# Usage:
#   sh security-invariants.sh --surface <repo-relative path> --mine <file> \
#        --candidate <file> [--theirs <file>] [--relaxes <file>] [--removes <file>] \
#        [--may-drop-headings <file>] [--pattern <ERE>] [--project-data] [--tools <dir>]
#
#   --surface   the repo-relative path being judged; it alone selects the rules.
#   --mine      the customer's current file (HEAD). A path that does not exist means
#               "mine is empty": R1/R2 have nothing to preserve, R3 nothing to retain.
#   --candidate the file the adapter (or the gate) proposes. Must exist.
#   --theirs    upstream's file. A path that does not exist (or no option) = empty.
#   --relaxes   rows `<surface> TAB <list> TAB <entry>`; only rows whose surface equals
#               --surface count. <list> is deny|allow|ask (settings.json), pattern|action
#               (tool-restrictions.json), verdict (gate-policy.conf), protected_paths
#               (governance.conf). Exactly the listed entries are exempt, nothing else.
#   --removes   one repo-relative path per line (blank and # lines ignored): hook
#               scripts an approved note removes.
#   --may-drop-headings  one heading text per line (the words after the hashes).
#   --pattern   a grep -E expression naming the defect lines of a project-data note.
#   --project-data  the note is project-data: only R4 applies, whatever the surface.
#   --tools     directory holding json-valid.sh and json-flat.sh (upstream's copies
#               saved at plan time); default UL_TOOLS (UPDATE_TOOLS, else this directory).
#
# Rules, chosen by --surface (a --project-data note is R4 only):
#   .claude/settings.json                     R1, R2 (permissions), R5
#   .claude/policies/tool-restrictions.json   R2 (policy actions and patterns), R5
#   .logic-loom/config/gate-policy.conf       R2 (verdict lines)
#   .logic-loom/config/governance.conf        R2 (protected_paths lines)
#   any other *.json                          R5
#   any other *.md                            R3
#   anything else                             no rule: prints `rule=none`, exit 0
#
#   R1 hooks        every (event, matcher, command) triple in mine is in the candidate
#                   with the SAME matcher, unless the command contains a --removes path
#                   (whole-path match, so `.claude/hooks/old-hook.s` does not name
#                   `.claude/hooks/old-hook.sh`). Adopter triples are never removable: a
#                   command whose first *.sh token is not under .claude/hooks/,
#                   .logic-loom/ or plugins/ (a command with no .sh token counts as the
#                   adopter's). A prompt-type hook (`"type": "prompt"`, identified by
#                   its `prompt` text, shown as `prompt: <text>`) is a hook too and is
#                   always the adopter's. The matcher of hooks[Event][i] applies to every
#                   hook in it; an absent matcher is the empty string. A candidate whose
#                   top-level `disableAllHooks` is true when mine's is not switches every
#                   hook off at once and is refused under R1.
#   R2 permissions  candidate.deny >= mine.deny; candidate.allow <= mine.allow + theirs.allow;
#                   candidate.ask >= (mine.ask - candidate.deny). Every other entry under
#                   `permissions` (defaultMode, disableBypassPermissionsMode,
#                   additionalDirectories, anything else) is posture: each (key, value) of
#                   mine must still be in the candidate, and each (key, value) of the
#                   candidate must be in mine or theirs. A relaxes row `<surface> TAB <key>
#                   TAB <value>` exempts that key from the first test and that (key, value)
#                   from the second.
#   R2 tool-restr.  every policy in mine keeps its name and an action no weaker
#                   (block > warn > info; a missing policy is a violation) and every
#                   pattern value of mine stays under the same policy.
#   R2 gate-policy  every op that mine sets to `ask` is still `ask` in the candidate, and
#                   every `mode.<x>` that mine sets to `enforce` is still `enforce` when
#                   the candidate carries it (an absent mode line is enforce by default in
#                   governance-verdicts.sh; an absent op line is a loss). The FIRST line for
#                   a key wins on both sides (as governance-verdicts.sh reads it), and any
#                   `silent`/`relax` line for such a key anywhere in the candidate is
#                   refused. A relaxes row `<surface> TAB verdict TAB <key>` exempts a key.
#   R2 governance   every `protected_paths = <value>` line of mine is in the candidate
#                   (values compared after trimming and dropping a trailing /* or /).
#   R3 retention    every line of mine matching ^#{1,3}[space] appears verbatim in the
#                   candidate unless its heading text is in --may-drop-headings; the
#                   candidate must have a non-blank line.
#   R4 bounded edit every line `diff mine candidate` deletes matches --pattern;
#                   insertions are free; the candidate must be non-blank; a missing or
#                   empty --pattern is a violation.
#   R5 shape        the candidate (and mine, and theirs when given) parses as JSON; every
#                   top-level key of mine other than hooks and permissions (settings.json
#                   only; no exclusions elsewhere) exists in the candidate; every top-level
#                   key of the candidate exists in mine or theirs. Two refusals protect the
#                   flattened reading itself: a string holding a `\n` escape followed by a
#                   slash (plain `/` or escaped `\/`) would imitate another entry; and, on
#                   settings.json and tool-restrictions.json, an object key made only of
#                   digits (`{"0": ...}`) flattens exactly like an array element while
#                   Claude Code runs no hook and applies no pattern from it. Before any
#                   JSON is judged the tools directory is proven alive on a known document
#                   (flatten it, accept it, reject a broken one); a directory that fails
#                   that self-test is an R5 refusal, never an empty reading.
#
# Output (stdout):
#   exit 0  `rule=ok` (every applicable rule holds) or `rule=none` (no rule applies).
#   exit 1  one `violation R<n> <detail>` line per violation (R1..R5 order, then file
#           order), then the last line `rule=R<n> detail=<first violation, one sentence>`.
#   exit 2  a usage error: a single `error <sentence>` line. This includes an input
#           file that exists but is not a regular readable file (a directory, mode 000):
#           such a side is never read as empty.
#
# Every awk that feeds a rule is checked: a tool failing mid-run records a violation for
# that rule instead of leaving an empty side that would pass.
#
# Limits, stated: R1 pins the command STRING, so it cannot judge whether a new upstream
# hook is wanted (that is the note's purpose) and a redirect upstream intends must come
# as an upstream take with --removes naming the old script. R3 reads every `#`..`###`
# line, including one inside a code fence, as a heading (the safe side); setext (underlined)
# headings are not headings to R3. The digit-key refusal reads raw JSON text (whitespace
# removed, so a key split across lines is still seen); its only false positives are keys
# that themselves contain `"<digits>"`, and a false positive is a refusal.

set -u

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$here/update-loom-common.sh"
ul_install_traps

si_usage() { # SENTENCE
  printf 'error %s\n' "$1"
  exit 2
}

# ---------------------------------------------------------------- arguments
si_surface=
si_mine=
si_cand=
si_theirs=
si_relaxes=
si_removes=
si_maydrop=
si_pattern=
si_projdata=0
si_have_mine=0
si_have_cand=0
si_tools=

while [ $# -gt 0 ]; do
  case $1 in
    --project-data) si_projdata=1; shift ;;
    --surface|--mine|--candidate|--theirs|--relaxes|--removes|--may-drop-headings|--pattern|--tools)
      [ $# -ge 2 ] || si_usage "$1 needs a value"
      si_opt=$1
      si_val=$2
      shift 2
      case $si_opt in
        --surface) si_surface=$si_val ;;
        --mine) si_mine=$si_val; si_have_mine=1 ;;
        --candidate) si_cand=$si_val; si_have_cand=1 ;;
        --theirs) si_theirs=$si_val ;;
        --relaxes) si_relaxes=$si_val ;;
        --removes) si_removes=$si_val ;;
        --may-drop-headings) si_maydrop=$si_val ;;
        --pattern) si_pattern=$si_val ;;
        --tools) si_tools=$si_val ;;
      esac
      ;;
    *) si_usage "unknown option: $1" ;;
  esac
done

[ -n "$si_surface" ] || si_usage "--surface is required"
[ "$si_have_mine" = 1 ] || si_usage "--mine is required (a path that does not exist means mine is empty)"
[ "$si_have_cand" = 1 ] || si_usage "--candidate is required"
[ -n "$si_tools" ] && UL_TOOLS=$si_tools

# An input that exists must be a regular, readable file: a directory or an
# unreadable file is an error, never an empty side (an empty side passes R1-R3
# trivially, which is exactly what a wrong path must not do). A path that does
# not exist is "empty" only for the optional inputs.
si_check_input() { # OPTION PATH REQUIRED(1|0)
  if [ -z "$2" ]; then
    [ "$3" = 1 ] && si_usage "$1 needs a path"
    return 0
  fi
  if [ -e "$2" ] || [ -L "$2" ]; then
    [ -f "$2" ] || si_usage "$1 is not a regular file: $2"
    [ -r "$2" ] || si_usage "$1 exists but cannot be read: $2"
  elif [ "$3" = 1 ]; then
    si_usage "the $1 file does not exist: $2"
  fi
  return 0
}
si_check_input --candidate "$si_cand" 1
si_check_input --mine "$si_mine" 0
si_check_input --theirs "$si_theirs" 0
si_check_input --relaxes "$si_relaxes" 0
si_check_input --removes "$si_removes" 0
si_check_input --may-drop-headings "$si_maydrop" 0

while :; do
  case $si_surface in
    ./*) si_surface=${si_surface#./} ;;
    *) break ;;
  esac
done

# ------------------------------------------------------------- rule selection
si_kind=
if [ "$si_projdata" = 1 ]; then
  si_kind=projdata
else
  case $si_surface in
    .claude/settings.json) si_kind=settings ;;
    .claude/policies/tool-restrictions.json) si_kind=toolr ;;
    .logic-loom/config/gate-policy.conf) si_kind=gate ;;
    .logic-loom/config/governance.conf) si_kind=gov ;;
    *.json) si_kind=json ;;
    *.md) si_kind=md ;;
    *) si_kind= ;;
  esac
fi

if [ -z "$si_kind" ]; then
  printf 'rule=none\n'
  exit 0
fi

# ------------------------------------------------------------------ plumbing
LC_ALL=C
export LC_ALL

si_viol=$(ul_mktemp) || exit 1

si_add() { # RULE SENTENCE
  printf '%s\t%s\n' "$1" "$2" >> "$si_viol"
}

# A tool (awk, sort) that fails while a rule is being evaluated must refuse the
# candidate, never leave an empty side that the rule then reads as "nothing lost".
si_toolfail() { # RULE
  si_add "$1" "an internal tool failed while this rule was being evaluated, so the candidate cannot be judged and is refused"
}

# Shared awk helpers, prepended to every awk program below.
SI_AWK_LIB='
function splitpath(p, a,   n, i, c, cur, L) {
  split("", a)
  n = 0; cur = ""; i = 1; L = length(p)
  while (i <= L) {
    c = substr(p, i, 1)
    if (c == "\\") { cur = cur substr(p, i, 2); i += 2; continue }
    if (c == "/") { a[++n] = cur; cur = ""; i++; continue }
    cur = cur c; i++
  }
  a[++n] = cur
  return n
}
function isword(c) {
  if (c == "") return 0
  return index("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-", c) > 0
}
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function emit(rule, msg) { printf "%s\t%s\n", rule, msg }
'

si_tag() { # TAG FILE [cr] : every line of FILE prefixed with TAG TAB (a missing file prints
           # nothing); returns awk's status so a caller can refuse on a tool failure
  [ -f "$2" ] || return 0
  if [ "${3:-}" = cr ]; then
    awk -v t="$1" '{ sub(/\r$/, ""); print t "\t" $0 }' "$2"
  else
    awk -v t="$1" '{ print t "\t" $0 }' "$2"
  fi
}

# The JSON tools are trusted input (upstream's copies saved at plan time), so they are
# proven alive before anything is judged with them: a directory whose scripts are
# missing, truncated or accept everything must be an R5 refusal, never an empty reading
# of every side. Returns 1 (and records the violation) when the self-test fails.
si_tools_selftest() {
  st_doc=$(ul_mktemp) || exit 1
  st_bad=$(ul_mktemp) || exit 1
  st_got=$(ul_mktemp) || exit 1
  st_want=$(ul_mktemp) || exit 1
  printf '{"a":[{"b":"c"}],"d":true}\n' > "$st_doc"
  printf '{"a":\n' > "$st_bad"
  printf '/a/0/b\tc\n/d\ttrue\n' > "$st_want"
  st_ok=1
  ul_json_valid "$st_doc" >/dev/null 2>&1 || st_ok=0
  if ul_json_valid "$st_bad" >/dev/null 2>&1; then st_ok=0; fi
  if ul_json_flat "$st_doc" 2>/dev/null | sort > "$st_got"; then
    cmp -s "$st_got" "$st_want" || st_ok=0
  else
    st_ok=0
  fi
  if ul_json_flat "$st_bad" >/dev/null 2>&1; then st_ok=0; fi
  if [ "$st_ok" = 1 ]; then return 0; fi
  si_add R5 "the JSON tools in $UL_TOOLS did not pass their self-test, so no JSON file can be judged with them"
  return 1
}

# An object key made only of digits flattens exactly like an array index, so a hooks
# block or a patterns list written as {"0": ...} would satisfy R1/R2 while Claude Code
# runs no hook and applies no pattern from it. Read on the raw text with all whitespace
# removed (a key split across lines is still seen); inside a JSON string a quote is
# always escaped, so `"<digits>":` can only be an object key. Returns 0 when such a key
# is present.
si_has_digit_key() { # FILE
  tr -d ' \t\r\n' < "$1" | grep -E '"[0-9]+":' >/dev/null 2>&1
}

# fl_load FILE OUT LABEL : the flattened leaves of FILE into OUT, one `path TAB value`
# per record, a newline inside a value encoded as \001 (json-flat.sh prints a value
# with a line break over several lines). A missing FILE is an empty document. Returns 1
# and records an R5 violation when FILE cannot be read safely.
fl_load() {
  fl_f=$1
  fl_o=$2
  fl_l=$3
  if [ -z "$fl_f" ] || [ ! -f "$fl_f" ]; then
    : > "$fl_o"
    return 0
  fi
  # A `\n` escape followed by a slash -- plain, or the equally legal `\/` escape that
  # json-flat.sh decodes to `/` -- would start a line that this loader reads as a new
  # record. Refused before flattening.
  if grep -E '\\n\\?/' "$fl_f" >/dev/null 2>&1; then
    si_add R5 "the $fl_l file has a string with an embedded line break followed by a slash, which could imitate another entry, so it cannot be compared safely"
    return 1
  fi
  if [ "$si_kind" = settings ] || [ "$si_kind" = toolr ]; then
    if si_has_digit_key "$fl_f"; then
      si_add R5 "the $fl_l file has an object key made only of digits where a list is expected (hooks and patterns must be arrays), so it cannot be compared safely"
      return 1
    fi
  fi
  fl_raw=$(ul_mktemp) || exit 1
  if ! ul_json_flat "$fl_f" > "$fl_raw" 2>/dev/null; then
    fl_why=$(grep '^reason=' "$fl_raw" 2>/dev/null | tail -n 1)
    [ -n "$fl_why" ] || fl_why='reason=it could not be read'
    si_add R5 "the $fl_l file is not valid JSON (${fl_why#reason=})"
    return 1
  fi
  if ! awk '
  function flush() { if (have) printf "%s\t%s\n", path, val; have = 0 }
  {
    c = substr($0, 1, 1)
    if (c == "/" || (NR == 1 && c == "\t")) {
      flush()
      i = index($0, "\t")
      if (i == 0) { path = $0; val = "" } else { path = substr($0, 1, i - 1); val = substr($0, i + 1) }
      have = 1
    } else if (have) {
      val = val "\001" $0
    }
  }
  END { flush() }' "$fl_raw" > "$fl_o"; then
    si_toolfail R5
    return 1
  fi
  return 0
}

si_load_json() { # sets F_M F_C F_T; returns 1 when any of them could not be read
  F_M=$(ul_mktemp) || exit 1
  F_C=$(ul_mktemp) || exit 1
  F_T=$(ul_mktemp) || exit 1
  si_tools_selftest || return 1
  si_lj=0
  fl_load "$si_mine" "$F_M" current || si_lj=1
  fl_load "$si_cand" "$F_C" candidate || si_lj=1
  fl_load "$si_theirs" "$F_T" upstream || si_lj=1
  return "$si_lj"
}

# The relaxes rows for THIS surface as `list TAB entry` lines.
si_relax_rows() {
  [ -n "$si_relaxes" ] && [ -f "$si_relaxes" ] || return 0
  awk -v s="$si_surface" '
  { sub(/\r$/, "") }
  {
    i = index($0, "\t"); if (i == 0) next
    f = substr($0, 1, i - 1)
    while (substr(f, 1, 2) == "./") f = substr(f, 3)
    if (f != s) next
    print substr($0, i + 1)
  }' "$si_relaxes"
}

# --------------------------------------------------------------------- R1
# si_sorted CMD FLATFILE OUT : run the extractor CMD on FLATFILE, sort -u into OUT;
# returns 1 when the extractor itself failed (its output is then not trusted).
si_sorted() {
  ss_raw=$(ul_mktemp) || exit 1
  "$1" "$2" > "$ss_raw" || return 1
  sort -u "$ss_raw" > "$3" || return 1
  return 0
}

si_triples_raw() { # FLATFILE : `event TAB matcher TAB command` per hook (unsorted)
  awk "$SI_AWK_LIB"'
  {
    i = index($0, "\t"); if (i == 0) next
    path = substr($0, 1, i - 1); val = substr($0, i + 1)
    n = splitpath(path, a)
    if (a[2] != "hooks") next
    if (n == 5 && a[5] == "matcher") m[a[3] SUBSEP a[4]] = val
    else if (n == 7 && a[5] == "hooks" && a[7] == "command") { k++; ce[k] = a[3]; ci[k] = a[4]; cc[k] = val }
    else if (n == 7 && a[5] == "hooks" && a[7] == "prompt") { k++; ce[k] = a[3]; ci[k] = a[4]; cc[k] = "prompt: " val }
  }
  END {
    for (j = 1; j <= k; j++) {
      key = ce[j] SUBSEP ci[j]
      printf "%s\t%s\t%s\n", ce[j], ((key in m) ? m[key] : ""), cc[j]
    }
  }' "$1"
}

rule_r1() {
  r1_m=$(ul_mktemp) || exit 1
  r1_c=$(ul_mktemp) || exit 1
  r1_x=$(ul_mktemp) || exit 1
  r1_all=$(ul_mktemp) || exit 1
  si_sorted si_triples_raw "$F_M" "$r1_m" || si_toolfail R1
  si_sorted si_triples_raw "$F_C" "$r1_c" || si_toolfail R1
  if [ -n "$si_removes" ] && [ -f "$si_removes" ]; then
    awk '
    { sub(/\r$/, ""); sub(/^[ \t]+/, ""); sub(/[ \t]+$/, "") }
    $0 == "" || substr($0, 1, 1) == "#" { next }
    { while (substr($0, 1, 2) == "./") $0 = substr($0, 3); print }' "$si_removes" > "$r1_x" || si_toolfail R1
  fi
  # disableAllHooks: one key that switches every hook off. The candidate may carry it
  # as true only when mine already did.
  r1_dc=$(awk -F '\t' '$1 == "/disableAllHooks" { print $2; exit }' "$F_C") || si_toolfail R1
  r1_dm=$(awk -F '\t' '$1 == "/disableAllHooks" { print $2; exit }' "$F_M") || si_toolfail R1
  if [ "$r1_dc" = true ] && [ "$r1_dm" != true ]; then
    si_add R1 "the candidate sets disableAllHooks to true, which switches every hook off, and your file did not"
  fi
  : > "$r1_all"
  si_tag X "$r1_x" >> "$r1_all" || si_toolfail R1
  si_tag C "$r1_c" >> "$r1_all" || si_toolfail R1
  si_tag M "$r1_m" >> "$r1_all" || si_toolfail R1
  awk "$SI_AWK_LIB"'
  function normtok(t) {
    gsub(/["\047]/, "", t)
    sub(/^\$CLAUDE_PROJECT_DIR\//, "", t)
    sub(/^\$\{CLAUDE_PROJECT_DIR\}\//, "", t)
    while (substr(t, 1, 2) == "./") t = substr(t, 3)
    sub(/[;&|)]+$/, "", t)
    return t
  }
  function scripttok(cmd,   n, i, t, a) {
    n = split(cmd, a, /[ \t\001]+/)
    for (i = 1; i <= n; i++) {
      if (a[i] == "") continue
      t = normtok(a[i])
      if (t ~ /\.sh$/) return t
    }
    return ""
  }
  function isadopter(cmd,   t) {
    if (index(cmd, "prompt: ") == 1) return 1
    t = scripttok(cmd)
    if (t == "") return 1
    if (index(t, ".claude/hooks/") == 1 || index(t, ".logic-loom/") == 1 || index(t, "plugins/") == 1) return 0
    return 1
  }
  function inpath(cmd, p,   s, pos, off, abs, before, after) {
    if (p == "") return 0
    off = 0; s = cmd
    while ((pos = index(s, p)) > 0) {
      abs = off + pos
      before = (abs > 1) ? substr(cmd, abs - 1, 1) : ""
      after = substr(cmd, abs + length(p), 1)
      if (!isword(before) && !isword(after)) return 1
      off = abs
      s = substr(cmd, off + 1)
    }
    return 0
  }
  function removed(cmd,   k) {
    for (k = 1; k <= nx; k++) if (inpath(cmd, xs[k])) return 1
    return 0
  }
  {
    tag = substr($0, 1, 1); rest = substr($0, 3)
    if (tag == "X") { xs[++nx] = rest; next }
    i1 = index(rest, "\t"); ev = substr(rest, 1, i1 - 1)
    r2 = substr(rest, i1 + 1); i2 = index(r2, "\t")
    mt = substr(r2, 1, i2 - 1); cm = substr(r2, i2 + 1)
    if (tag == "C") { cand[ev SUBSEP mt SUBSEP cm] = 1; candm[ev SUBSEP cm] = mt; next }
    nm++; me[nm] = ev; mm[nm] = mt; mc[nm] = cm
  }
  END {
    for (k = 1; k <= nm; k++) {
      ev = me[k]; mt = mm[k]; cm = mc[k]
      if ((ev SUBSEP mt SUBSEP cm) in cand) continue
      ad = isadopter(cm)
      if (!ad && removed(cm)) continue
      if ((ev SUBSEP cm) in candm) {
        emit("R1", "the hook command \"" cm "\" for event " ev " changed its matcher from \"" mt "\" to \"" candm[ev SUBSEP cm] "\"")
      } else if (ad) {
        emit("R1", "the hook command \"" cm "\" (event " ev ", matcher \"" mt "\") is missing from the candidate; it is your own hook and is always kept")
      } else {
        emit("R1", "the hook command \"" cm "\" (event " ev ", matcher \"" mt "\") is missing from the candidate and no approved note removes it")
      }
    }
  }' "$r1_all" >> "$si_viol" || si_toolfail R1
}

# --------------------------------------------------------------- R2: settings
# `list TAB entry` for the three lists; `posture:<key> TAB value` for every other
# leaf under permissions (defaultMode, disableBypassPermissionsMode,
# additionalDirectories/<i>, anything else), keyed by the first component only so a
# re-indexed array still compares as a set of (key, value).
si_perms_raw() { # FLATFILE (unsorted)
  awk "$SI_AWK_LIB"'
  {
    i = index($0, "\t"); if (i == 0) next
    path = substr($0, 1, i - 1); val = substr($0, i + 1)
    n = splitpath(path, a)
    if (n < 3 || a[2] != "permissions") next
    if (n == 4 && (a[3] == "deny" || a[3] == "allow" || a[3] == "ask")) print a[3] "\t" val
    else if (a[3] != "deny" && a[3] != "allow" && a[3] != "ask") print "posture:" a[3] "\t" val
  }' "$1"
}

rule_r2_perms() {
  rp_m=$(ul_mktemp) || exit 1
  rp_c=$(ul_mktemp) || exit 1
  rp_t=$(ul_mktemp) || exit 1
  rp_x=$(ul_mktemp) || exit 1
  rp_all=$(ul_mktemp) || exit 1
  si_sorted si_perms_raw "$F_M" "$rp_m" || si_toolfail R2
  si_sorted si_perms_raw "$F_C" "$rp_c" || si_toolfail R2
  si_sorted si_perms_raw "$F_T" "$rp_t" || si_toolfail R2
  si_relax_rows > "$rp_x" || si_toolfail R2
  : > "$rp_all"
  si_tag X "$rp_x" >> "$rp_all" || si_toolfail R2
  si_tag M "$rp_m" >> "$rp_all" || si_toolfail R2
  si_tag C "$rp_c" >> "$rp_all" || si_toolfail R2
  si_tag T "$rp_t" >> "$rp_all" || si_toolfail R2
  awk "$SI_AWK_LIB"'
  {
    tag = substr($0, 1, 1); rest = substr($0, 3)
    i = index(rest, "\t"); if (i == 0) next
    l = substr(rest, 1, i - 1); v = substr(rest, i + 1)
    if (tag == "X") {
      if (l == "deny" || l == "allow" || l == "ask") { rel[l SUBSEP v] = 1 }
      else { rel["posture:" l SUBSEP v] = 1; relkey["posture:" l] = 1 }
      next
    }
    k = l SUBSEP v
    if (tag == "M") { m[k] = 1; if (l != "allow") { nm++; ml[nm] = l; mv[nm] = v } }
    else if (tag == "C") { c[k] = 1; nc++; cl[nc] = l; cv[nc] = v }
    else if (tag == "T") t[k] = 1
  }
  END {
    for (j = 1; j <= nm; j++) {
      l = ml[j]; v = mv[j]; k = l SUBSEP v
      if (l == "deny") {
        if (!(k in c) && !(k in rel)) emit("R2", "the deny entry \"" v "\" was removed from permissions")
      } else if (l == "ask") {
        if (!(k in c) && !(("deny" SUBSEP v) in c) && !(k in rel)) emit("R2", "the ask entry \"" v "\" was dropped from permissions and did not move to deny")
      } else {
        if (!(k in c) && !(l in relkey)) emit("R2", "the permissions setting " substr(l, 9) " = \"" v "\" from your file is missing or changed in the candidate")
      }
    }
    for (j = 1; j <= nc; j++) {
      l = cl[j]; v = cv[j]; k = l SUBSEP v
      if (l == "allow") {
        if (!(k in m) && !(k in t) && !(k in rel)) emit("R2", "the allow entry \"" v "\" is new and is in neither your file nor the upstream file")
      } else if (l != "deny" && l != "ask") {
        if (!(k in m) && !(k in t) && !(k in rel)) emit("R2", "the permissions setting " substr(l, 9) " = \"" v "\" in the candidate comes from neither your file nor the upstream file")
      }
    }
  }' "$rp_all" >> "$si_viol" || si_toolfail R2
}

# ------------------------------------------------- R2: tool-restrictions.json
si_policies_raw() { # FLATFILE : `A TAB name TAB action` and `P TAB name TAB pattern` (unsorted)
  awk "$SI_AWK_LIB"'
  {
    i = index($0, "\t"); if (i == 0) next
    path = substr($0, 1, i - 1); val = substr($0, i + 1)
    n = splitpath(path, a)
    if (a[2] != "policies") next
    if (n == 4 && a[4] == "action") print "A\t" a[3] "\t" val
    else if (n == 6 && a[4] == "patterns" && a[6] == "pattern") print "P\t" a[3] "\t" val
  }' "$1"
}

rule_r2_toolr() {
  rt_m=$(ul_mktemp) || exit 1
  rt_c=$(ul_mktemp) || exit 1
  rt_x=$(ul_mktemp) || exit 1
  rt_all=$(ul_mktemp) || exit 1
  si_sorted si_policies_raw "$F_M" "$rt_m" || si_toolfail R2
  si_sorted si_policies_raw "$F_C" "$rt_c" || si_toolfail R2
  si_relax_rows > "$rt_x" || si_toolfail R2
  : > "$rt_all"
  si_tag X "$rt_x" >> "$rt_all" || si_toolfail R2
  si_tag M "$rt_m" >> "$rt_all" || si_toolfail R2
  si_tag C "$rt_c" >> "$rt_all" || si_toolfail R2
  awk "$SI_AWK_LIB"'
  function rank(s) {
    s = tolower(s)
    if (s == "block") return 3
    if (s == "warn") return 2
    if (s == "info") return 1
    return 0
  }
  {
    tag = substr($0, 1, 1); rest = substr($0, 3)
    if (tag == "X") {
      i = index(rest, "\t"); if (i == 0) next
      kind = substr(rest, 1, i - 1); v = substr(rest, i + 1)
      if (kind == "pattern") relpat[v] = 1
      else if (kind == "action") relact[v] = 1
      next
    }
    kind = substr(rest, 1, 1); r2 = substr(rest, 3)
    i = index(r2, "\t"); if (i == 0) next
    name = substr(r2, 1, i - 1); v = substr(r2, i + 1)
    if (tag == "M") {
      if (kind == "A") { nma++; man[nma] = name; mav[nma] = v }
      else { nmp++; mpn[nmp] = name; mpv[nmp] = v }
    } else {
      if (kind == "A") cact[name] = v
      else cpat[name SUBSEP v] = 1
    }
  }
  END {
    for (j = 1; j <= nma; j++) {
      name = man[j]; was = mav[j]
      if (name in relact) continue
      if (!(name in cact)) { emit("R2", "the policy \"" name "\" (action " was ") has no action in the candidate, so it was removed"); continue }
      if (cact[name] != was && rank(cact[name]) < rank(was)) emit("R2", "the policy \"" name "\" action went from " was " to " cact[name])
    }
    for (j = 1; j <= nmp; j++) {
      name = mpn[j]; v = mpv[j]
      if ((name SUBSEP v) in cpat) continue
      if (v in relpat) continue
      emit("R2", "the policy \"" name "\" lost the pattern \"" v "\"")
    }
  }' "$rt_all" >> "$si_viol" || si_toolfail R2
}

# --------------------------------------------------- R2: gate-policy.conf
# Two kinds of key, read the way governance-verdicts.sh reads them (first line for a
# key wins, `#` starts a comment): `<op> = ask|silent` and `mode.<x> = enforce|relax`.
# The strict value (ask, enforce) of mine must survive. An op line missing from the
# candidate is a loss (its built-in default may be silent); a mode line missing from
# the candidate is not (an absent mode is enforce). Any loose line (silent, relax) for
# such a key anywhere in the candidate is refused, whatever line comes first.
rule_r2_gate() {
  rg_x=$(ul_mktemp) || exit 1
  rg_all=$(ul_mktemp) || exit 1
  si_relax_rows > "$rg_x" || si_toolfail R2
  : > "$rg_all"
  si_tag X "$rg_x" >> "$rg_all" || si_toolfail R2
  si_tag M "$si_mine" cr >> "$rg_all" || si_toolfail R2
  si_tag C "$si_cand" cr >> "$rg_all" || si_toolfail R2
  awk "$SI_AWK_LIB"'
  function strict(v) { return (v == "ask" || v == "enforce") }
  function loose(v) { return (v == "silent" || v == "relax") }
  {
    tag = substr($0, 1, 1); line = substr($0, 3)
    if (tag == "X") {
      i = index(line, "\t"); if (i == 0) next
      if (substr(line, 1, i - 1) == "verdict") rel[substr(line, i + 1)] = 1
      next
    }
    line = trim(line)
    if (line == "" || substr(line, 1, 1) == "#") next
    i = index(line, "=")
    if (i == 0) next
    key = trim(substr(line, 1, i - 1))
    rest = substr(line, i + 1)
    j = index(rest, "#"); if (j > 0) rest = substr(rest, 1, j - 1)
    rest = trim(rest)
    if (key !~ /^[A-Za-z0-9._-]+$/) next
    split(rest, w, /[ \t]+/)
    if (tag == "M") {
      if (!(key in mfirst)) { mfirst[key] = w[1]; nm++; mop[nm] = key }
    } else if (tag == "C") {
      if (!(key in first)) first[key] = rest
      if (loose(w[1])) hasloose[key] = 1
    }
  }
  END {
    for (j = 1; j <= nm; j++) {
      op = mop[j]
      was = mfirst[op]
      if (!strict(was)) continue
      if (op in rel) continue
      ismode = (substr(op, 1, 5) == "mode.")
      if (!(op in first)) {
        if (!ismode) emit("R2", "the operation " op " was set to " was " and its line is missing from the candidate")
        continue
      }
      if (first[op] != was) { emit("R2", "the setting " op " was " was " and is now \"" first[op] "\" in the candidate"); continue }
      if (op in hasloose) emit("R2", "the setting " op " was " was " and the candidate also carries a line that loosens it")
    }
  }' "$rg_all" >> "$si_viol" || si_toolfail R2
}

# -------------------------------------------------- R2: governance.conf
rule_r2_gov() {
  rv_x=$(ul_mktemp) || exit 1
  rv_all=$(ul_mktemp) || exit 1
  si_relax_rows > "$rv_x" || si_toolfail R2
  : > "$rv_all"
  si_tag X "$rv_x" >> "$rv_all" || si_toolfail R2
  si_tag M "$si_mine" cr >> "$rv_all" || si_toolfail R2
  si_tag C "$si_cand" cr >> "$rv_all" || si_toolfail R2
  awk "$SI_AWK_LIB"'
  function normval(v) {
    v = trim(v)
    sub(/\/\*$/, "", v)
    sub(/\/+$/, "", v)
    return v
  }
  {
    tag = substr($0, 1, 1); line = substr($0, 3)
    if (tag == "X") {
      i = index(line, "\t"); if (i == 0) next
      if (substr(line, 1, i - 1) == "protected_paths") { v = substr(line, i + 1); rel[v] = 1; rel[normval(v)] = 1 }
      next
    }
    line = trim(line)
    if (line == "" || substr(line, 1, 1) == "#") next
    i = index(line, "=")
    if (i == 0) next
    key = trim(substr(line, 1, i - 1))
    if (key != "protected_paths") next
    rest = substr(line, i + 1)
    j = index(rest, "#"); if (j > 0) rest = substr(rest, 1, j - 1)
    v = trim(rest)
    if (v == "") next
    if (tag == "M") { if (!(normval(v) in mseen)) { mseen[normval(v)] = 1; nm++; mval[nm] = v } }
    else cset[normval(v)] = 1
  }
  END {
    for (j = 1; j <= nm; j++) {
      v = mval[j]
      if (normval(v) in cset) continue
      if (v in rel || normval(v) in rel) continue
      emit("R2", "the protected_paths line \"" v "\" was removed")
    }
  }' "$rv_all" >> "$si_viol" || si_toolfail R2
}

# ------------------------------------------------------------------- R3
rule_r3() {
  r3_d=$(ul_mktemp) || exit 1
  r3_all=$(ul_mktemp) || exit 1
  if [ -n "$si_maydrop" ] && [ -f "$si_maydrop" ]; then
    awk '{ sub(/\r$/, ""); sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); if ($0 != "") print }' "$si_maydrop" > "$r3_d" || si_toolfail R3
  fi
  : > "$r3_all"
  si_tag D "$r3_d" >> "$r3_all" || si_toolfail R3
  si_tag M "$si_mine" cr >> "$r3_all" || si_toolfail R3
  si_tag C "$si_cand" cr >> "$r3_all" || si_toolfail R3
  awk "$SI_AWK_LIB"'
  {
    tag = substr($0, 1, 1); line = substr($0, 3)
    if (tag == "D") { dset[line] = 1; next }
    if (tag == "C") { cset[line] = 1; if (line ~ /[^ \t]/) nonblank = 1; next }
    if (line ~ /^# / || line ~ /^## / || line ~ /^### /) { if (!(line in mseen)) { mseen[line] = 1; nm++; mh[nm] = line } }
  }
  END {
    if (!nonblank) { emit("R3", "the candidate is empty, so every heading of your file would be lost"); exit }
    for (j = 1; j <= nm; j++) {
      h = mh[j]
      if (h in cset) continue
      text = h
      sub(/^#+[ \t]+/, "", text); sub(/[ \t]+$/, "", text)
      if (text in dset) continue
      emit("R3", "the heading \"" h "\" from your file is missing from the candidate and no approved note lets it go")
    }
  }' "$r3_all" >> "$si_viol" || si_toolfail R3
}

# ------------------------------------------------------------------- R4
rule_r4() {
  if [ -z "$si_pattern" ]; then
    si_add R4 "no pattern was given for this project-data file, so no deletion can be allowed"
    return 0
  fi
  if ! grep '[^[:space:]]' "$si_cand" >/dev/null 2>&1; then
    si_add R4 "the candidate is empty, so the whole file would be wiped"
    return 0
  fi
  r4_m=$si_mine
  if [ ! -f "$r4_m" ]; then
    r4_m=$(ul_mktemp) || exit 1
  fi
  r4_diff=$(ul_mktemp) || exit 1
  r4_del=$(ul_mktemp) || exit 1
  r4_bad=$(ul_mktemp) || exit 1
  diff "$r4_m" "$si_cand" > "$r4_diff" 2>/dev/null
  r4_rc=$?
  if [ "$r4_rc" -gt 1 ]; then
    si_add R4 "the candidate could not be compared with your file"
    return 0
  fi
  if ! awk '
  substr($0, 1, 2) == "< " || $0 == "<" { t = substr($0, 3); sub(/\r$/, "", t); print t }' "$r4_diff" > "$r4_del"; then
    si_toolfail R4
    return 0
  fi
  grep -E -v -e "$si_pattern" "$r4_del" > "$r4_bad" 2>/dev/null
  r4_rc=$?
  if [ "$r4_rc" -gt 1 ]; then
    si_add R4 "the pattern is not a valid extended regular expression"
    return 0
  fi
  [ "$r4_rc" = 0 ] || return 0
  r4_n=0
  while IFS= read -r r4_line; do
    r4_n=$((r4_n + 1))
    if [ "$r4_n" -le 5 ]; then
      if [ -z "$r4_line" ]; then
        si_add R4 "the candidate deletes a blank line, which is outside the allowed pattern"
      else
        si_add R4 "the candidate deletes a line outside the allowed pattern: \"$r4_line\""
      fi
    fi
  done < "$r4_bad"
  if [ "$r4_n" -gt 5 ]; then
    si_add R4 "the candidate deletes $((r4_n - 5)) more lines outside the allowed pattern"
  fi
}

# ------------------------------------------------------------------- R5
si_keys_raw() { # FLATFILE : top-level keys (first path component, raw), unsorted
  awk "$SI_AWK_LIB"'
  {
    i = index($0, "\t"); if (i == 0) next
    n = splitpath(substr($0, 1, i - 1), a)
    print (n >= 2) ? a[2] : ""
  }' "$1"
}

rule_r5() { # EXCLUDE (1 = ignore hooks and permissions on the mine side)
  r5_m=$(ul_mktemp) || exit 1
  r5_c=$(ul_mktemp) || exit 1
  r5_t=$(ul_mktemp) || exit 1
  r5_all=$(ul_mktemp) || exit 1
  si_sorted si_keys_raw "$F_M" "$r5_m" || si_toolfail R5
  si_sorted si_keys_raw "$F_C" "$r5_c" || si_toolfail R5
  si_sorted si_keys_raw "$F_T" "$r5_t" || si_toolfail R5
  : > "$r5_all"
  si_tag M "$r5_m" >> "$r5_all" || si_toolfail R5
  si_tag C "$r5_c" >> "$r5_all" || si_toolfail R5
  si_tag T "$r5_t" >> "$r5_all" || si_toolfail R5
  awk -v excl="$1" "$SI_AWK_LIB"'
  {
    tag = substr($0, 1, 1); k = substr($0, 3)
    if (tag == "M") { nm++; mk[nm] = k; m[k] = 1 }
    else if (tag == "C") { nc++; ck[nc] = k; c[k] = 1 }
    else t[k] = 1
  }
  END {
    for (j = 1; j <= nm; j++) {
      k = mk[j]
      if (excl == 1 && (k == "hooks" || k == "permissions")) continue
      if (!(k in c)) emit("R5", "the top-level key \"" k "\" from your file is missing from the candidate")
    }
    for (j = 1; j <= nc; j++) {
      k = ck[j]
      if (!(k in m) && !(k in t)) emit("R5", "the top-level key \"" k "\" in the candidate comes from neither your file nor the upstream file")
    }
  }' "$r5_all" >> "$si_viol" || si_toolfail R5
}

# ------------------------------------------------------------------ dispatch
case $si_kind in
  settings)
    if si_load_json; then
      rule_r1
      rule_r2_perms
      rule_r5 1
    fi
    ;;
  toolr)
    if si_load_json; then
      rule_r2_toolr
      rule_r5 0
    fi
    ;;
  json)
    if si_load_json; then
      rule_r5 0
    fi
    ;;
  gate) rule_r2_gate ;;
  gov) rule_r2_gov ;;
  md) rule_r3 ;;
  projdata) rule_r4 ;;
esac

# ------------------------------------------------------------------- report
if [ ! -s "$si_viol" ]; then
  printf 'rule=ok\n'
  exit 0
fi

si_ordered=$(ul_mktemp) || exit 1
si_final=$(ul_mktemp) || exit 1
si_tab=$(printf '\t')
for si_r in R1 R2 R3 R4 R5; do
  awk -v p="$si_r$si_tab" 'index($0, p) == 1' "$si_viol"
done > "$si_ordered"
tr '\001\r\t' '   ' < "$si_ordered" | cut -c1-400 > "$si_final"

while IFS= read -r si_line; do
  printf 'violation %s\n' "$si_line"
done < "$si_final"
si_first=$(head -n 1 "$si_final")
printf 'rule=%s detail=%s\n' "${si_first%% *}" "${si_first#* }"
exit 1
