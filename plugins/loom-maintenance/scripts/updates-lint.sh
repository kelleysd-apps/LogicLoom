#!/bin/sh
# updates-lint.sh -- the improvement-note linter of the /update-loom engine family.
#
# Usage: sh updates-lint.sh [--root DIR] [--notes-dir DIR] [--no-tree-rules]
#                           [--upstream SHA --base SHA]
#
# Lints every <release>/<id>.md under the notes folder (default UL_NOTES_DIR from
# update-loom-common.sh) of the tree rooted at --root (default: the git toplevel of
# the current directory, else the current directory). README.md is documentation,
# not a note. POSIX sh + awk only; set -u; the shared library is sourced from this
# script's own directory.
#
# Output, one line per finding, then one summary line:
#   problem <note> <rule-name>: <plain sentence>
#   warn <note> <plain sentence>
#   notes=<n> problems=<p> warnings=<w>
# <note> is the note's path relative to --root. Exit 1 when there is at least one
# problem line, exit 2 for a usage error, otherwise 0.
#
# Options
#   --notes-dir DIR   the notes folder, relative to --root (or absolute)
#   --no-tree-rules   skip the two rules that compare note rows with the files on
#                     disk (touches-exists and removes-present). They hold only in
#                     upstream's own tree; a customer's tree has not applied the
#                     notes yet. updates-checks.sh passes this flag in a customer copy.
#   --upstream SHA --base SHA
#                     also run the posture rule (below); both revisions must exist
#                     in the repository at --root.
#
# The rules (the first word of each problem's text names the rule):
#   no-frontmatter  missing-key  duplicate-key  list-form  empty-key  touches-empty
#   done-when-empty  id-mismatch  id-duplicate  safety-value  project-data-value
#   purpose-multiline
#   check-name  check-missing  check-syntax          the check is a sibling file that parses
#   touches-channel   a row's @suffix is not @both, @template or @adopted
#   row-path          a row is not one repo-relative path
#   touches-exists    a touches path is absent on disk (not for an @adopted row or a
#                     project-data note, whose file is never shipped)
#   removes-present   a removes path is still on disk
#   forbidden-path    a touches, adds or removes row sits under the forbidden set
#   project-data-allowed / -pattern / -safety / -touches / -sections
#   pattern-compiles  a pattern: that grep -E rejects
#   protected-needs-check   a note on a protected, posture or security-surface path
#                           names no check
#   check-none-safety       safety: true with check: none
#   requires-unknown / requires-later / requires-cycle / requires-safety
#   relaxes-safety / relaxes-format / relaxes-path
#   may-drop-headings    only when some touches row ends in .md
#   check-body-git / -net / -eval / -rm / -source / -redirect / -vacuous
#   id-marker         a maintainer identity string in a note or check
#   posture-safety    (only with --upstream/--base) a verdict or protected_paths line
#                     changed in a posture file the note touches, safety is not true
# and two warnings: check: none (offered once, never re-verified) and overlap (more
# than two notes of one release share files).
#
# The frontmatter forms the rules read:
#   relaxes:        one entry per item, written  path :: list :: entry  (the form this
#                   linter documents; a TAB between the three fields is accepted too)
#   removes:        list of paths that must be absent once the note applies
#   pattern:        a grep -E expression naming the defect lines
#   may-drop-headings:  list of headings an adaptation may remove from a prose file
#   Every list is block form: the key, then one indented "- item" line per item.
#   `key: []` is an empty list; an inline `[a, b]` list or a bare value on a list
#   key's line is refused (list-form), and a key written twice is refused
#   (duplicate-key), because the engine reads every occurrence of a list key as
#   part of the list. A blank or quoted-blank item counts as no item.
#   A touches, adds or removes row may end in @both, @template or @adopted (default
#   @both); channel names are per row, not per note.
#
# The check-body rules (check-body-*) read the check file with comments removed and
# are string rules: defence in depth, not a sandbox. Single-quoted text is not
# scanned for commands, so write prose and patterns in single quotes; the one thing
# read inside single quotes is an awk print or printf whose output goes to a quoted
# file (print > "file"), which counts as a redirection. A > inside double quotes is
# not a redirection, except inside a $( ) command substitution, whose text is code.
# A heredoc body is scanned as code. The mention rule (check-body-vacuous) does not
# count a path that appears only inside a hint= or skip= message. Known limits: a
# command named through a variable, or inside a backquoted substitution within double
# quotes, is not seen; the engine's write detection is the second line.
#
# Speed: a run spawns few processes on purpose (the cases suite lints a hundred
# trees). The frontmatter is read in one awk pass, with the same reading rules as
# ul_fm_scalar / ul_fm_list / ul_fm_has in update-loom-common.sh (a key at column 0,
# a list is the indented "- item" lines after it, one wrapping pair of double quotes
# stripped from an item); the check body is scanned and judged in one awk pass.

set -u
LC_ALL=C
export LC_ALL

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 1
. "$here/update-loom-common.sh"
ul_install_traps

tab=$(printf '\t')
nl='
'

usage_error() { # sentence
  printf 'error %s\n' "$1" >&2
  printf 'usage: sh updates-lint.sh [--root DIR] [--notes-dir DIR] [--no-tree-rules] [--upstream SHA --base SHA]\n' >&2
  exit 2
}

# ----------------------------------------------------------------- arguments
root=
ndir_arg=
no_tree=0
up=
base=
while [ $# -gt 0 ]; do
  case $1 in
    --root) [ $# -ge 2 ] || usage_error "--root needs a directory"; root=$2; shift 2;;
    --notes-dir) [ $# -ge 2 ] || usage_error "--notes-dir needs a directory"; ndir_arg=$2; shift 2;;
    --no-tree-rules) no_tree=1; shift;;
    --upstream) [ $# -ge 2 ] || usage_error "--upstream needs a revision"; up=$2; shift 2;;
    --base) [ $# -ge 2 ] || usage_error "--base needs a revision"; base=$2; shift 2;;
    *) usage_error "unknown argument: $1";;
  esac
done

if [ -z "$root" ]; then
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root=
  [ -n "$root" ] || root=$(pwd)
fi
root_in=$root
root=$(CDPATH= cd -- "$root_in" 2>/dev/null && pwd -P) || usage_error "--root is not a directory: $root_in"

ndir=${ndir_arg:-$UL_NOTES_DIR}
case $ndir in
  /*) nabs=$ndir;;
  *) nabs=$root/$ndir;;
esac
nabs=${nabs%/}

if [ -n "$up$base" ]; then
  [ -n "$up" ] && [ -n "$base" ] || usage_error "--upstream and --base go together"
  git -C "$root" rev-parse --verify --quiet "$up^{commit}" >/dev/null 2>&1 || usage_error "--upstream is not a revision in this repository: $up"
  git -C "$root" rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1 || usage_error "--base is not a revision in this repository: $base"
fi

# --------------------------------------------------------------------- temps
mk() { _t=$(ul_mktemp) || exit 1; printf '%s' "$_t"; }
f_idx=$(mk); f_meta=$(mk); f_edges=$(mk); f_paths=$(mk); f_needles=$(mk); f_out=$(mk)

np=0
nw=0
problem() { np=$((np + 1)); printf 'problem %s %s\n' "$1" "$2"; } # note, sentence
warn() { nw=$((nw + 1)); printf 'warn %s %s\n' "$1" "$2"; }

# ID markers a note or check may not carry. Each is assembled from two pieces so
# that this file does not hold the whole string (the leak guard greps tracked files).
mk_a=brian@kelleysd; mk_a=$mk_a.com
mk_b=kelleysd; mk_b=$mk_b.com/
mk_c=ioun; mk_c=$mk_c-ai
mk_d=/workspace; mk_d=${mk_d}s/
mk_e='~/.claude'

# ------------------------------------------------------------------- helpers
norm_path() { # PATH -> NP_V without a leading ./ and a trailing /
  NP_V=$1
  while :; do
    case $NP_V in ./*) NP_V=${NP_V#./};; *) break;; esac
  done
  while :; do
    case $NP_V in ?*/) NP_V=${NP_V%/};; *) break;; esac
  done
}

strip_q() { # VALUE -> SQ_V : one wrapping pair of matching quotes removed
  SQ_V=$1
  case $SQ_V in
    \"*\") SQ_V=${SQ_V#\"}; SQ_V=${SQ_V%\"};;
    \'*\') SQ_V=${SQ_V#\'}; SQ_V=${SQ_V%\'};;
  esac
}

blank() { # VALUE -> 0 when it holds no character other than whitespace
  case $1 in *[![:space:]]*) return 1;; esac
  return 0
}

# The frontmatter reader: stdin is the frontmatter text. Tab-separated records:
#   H key            the key is present (a line starting key: at column 0)
#   S key value      its trimmed single-line value (first occurrence of a key only,
#                    as ul_fm_scalar reads it)
#   L key item       one list item (quote-stripped, empty when blank); items are read
#                    under EVERY occurrence of the key, as ul_fm_list reads them
#   D key            the key appears a second time
#   M purpose        the purpose runs over more than one line
fm_extract() {
  awk '
    BEGIN { tb = sprintf("%c", 9) }
    {
      line = $0
      if (inlist && line ~ /^[ \t]+-[ \t]/) {
        item = line
        sub(/^[ \t]+-[ \t]*/, "", item)
        sub(/[ \t]+$/, "", item)
        if (item ~ /^".*"$/ && length(item) >= 2) { item = substr(item, 2, length(item) - 2) }
        if (item ~ /^[ \t]*$/) { item = "" }
        print "L" tb key tb item
        next
      }
      inlist = 0
      if (afterpurpose) {
        afterpurpose = 0
        if (line ~ /^[ \t]+[^ \t]/) { print "M" tb "purpose" }
      }
      if (line ~ /^[A-Za-z0-9_-]+:/) {
        k = line
        sub(/:.*/, "", k)
        key = k
        rest = line
        sub(/^[^:]*:/, "", rest)
        sub(/^[ \t]+/, "", rest)
        sub(/[ \t]+$/, "", rest)
        if (rest == "") { inlist = 1 }
        if (k in seen) { print "D" tb k; next }
        seen[k] = 1
        print "H" tb key
        print "S" tb key tb rest
        if (key == "purpose") {
          afterpurpose = 1
          if (rest ~ /^[>|]/) { print "M" tb "purpose" }
        }
      }
    }
  '
}

# analyze_check FILE : the check-body rules in one pass. Reads the needles file
# (f_needles, one string per line) and prints `rule|detail` per finding. It scans the
# file with comments removed: T text has single-quoted spans blanked (what could be
# a command), C text keeps them (for the mention test).
analyze_check() {
  awk -v needles="$f_needles" '
    BEGIN {
      sq = sprintf("%c", 39); dq = sprintf("%c", 34); q = 0; nf = 0; nn = 0
      hre1 = sq "[^" sq "]*(hint|skip)=[^" sq "]*" sq
      hre2 = dq "[^" dq "]*(hint|skip)=[^" dq "]*" dq
      while ((getline ln < needles) > 0) { if (ln != "") { nn++; need[nn] = ln } }
    }
    function srcbad(t,   s, n, p, i, x, w) {
      s = t
      gsub(/[;|&(`{]/, "\n", s)
      n = split(s, p, "\n")
      for (i = 1; i <= n; i++) {
        x = p[i]
        sub(/^[ \t]+/, "", x)
        while (x ~ /^(then|do|else|elif|if|while|until|!)[ \t]+/) {
          sub(/^(then|do|else|elif|if|while|until|!)[ \t]+/, "", x)
        }
        if (x ~ /^(\.|source)[ \t]+/) {
          sub(/^(\.|source)[ \t]+/, "", x)
          split(x, w, /[ \t]+/)
          if (w[1] == "" || substr(w[1], 1, 1) == sq) { return "a quoted path" }
          if (w[1] !~ /[$]\{?TMPDIR/) { return w[1] }
        }
      }
      return ""
    }
    {
      line = $0
      n = length(line)
      c = ""; t = ""; prev = " "
      for (i = 1; i <= n; i++) {
        ch = substr(line, i, 1)
        if (q == 1) {
          c = c ch; sqt = sqt ch
          if (ch == sq) { q = 0; t = t sq }
          prev = ch
          continue
        }
        if (q == 2) {
          if (ch == "\\") { c = c ch substr(line, i + 1, 1); t = t ch substr(line, i + 1, 1); i++; prev = "x"; continue }
          if (ch == "$" && substr(line, i + 1, 1) == "(") {
            # a command substitution inside the string: its text is code until the ) that closes it
            c = c "$("; t = t "$("; i++; nf++; depth[nf] = 1; q = 0; prev = "("
            continue
          }
          c = c ch; t = t ch
          if (ch == dq) { q = 0 }
          prev = ch
          continue
        }
        if (nf > 0) {
          if (ch == "(") { depth[nf]++ }
          else if (ch == ")") {
            depth[nf]--
            if (depth[nf] == 0) { nf--; c = c ch; t = t ch; q = 2; prev = ch; continue }
          }
        }
        if (ch == "#" && (i == 1 || prev == " " || prev == "\t" || prev == ";" || prev == "|" || prev == "&" || prev == "(")) { break }
        if (ch == sq) { q = 1; c = c ch; t = t sq; prev = ch; continue }
        if (ch == dq) { q = 2; c = c ch; t = t ch; prev = ch; continue }
        if (ch == "\\") { c = c ch substr(line, i + 1, 1); t = t ch substr(line, i + 1, 1); i++; prev = "x"; continue }
        if (ch == ">") {
          j = i + 1
          if (substr(line, j, 1) == ">") { j++ }
          if (substr(line, j, 1) == "|") { j++ }
          if (substr(line, j, 1) != "&") {
            rest = substr(line, j)
            sub(/^[ \t]+/, "", rest)
            tok = ""; qq = 0
            for (k = 1; k <= length(rest); k++) {
              x = substr(rest, k, 1)
              if (qq == 0 && (x == " " || x == "\t" || x == ";" || x == "|" || x == "&" || x == ")")) { break }
              if (x == dq) { qq = (qq == 0) ? 2 : 0 }
              tok = tok x
            }
            if (redir == "" && tok !~ /[$]TMPDIR/ && tok !~ /[$]\{TMPDIR/ && tok !~ /\/dev\/null/) { redir = tok }
          }
        }
        c = c ch; t = t ch; prev = ch
      }
      if (q == 1) { sqt = sqt "\n" }
      m = c
      gsub(hre1, "", m); gsub(hre2, "", m)
      mtext = mtext m "\n"
      s = t
      while (gitbad == "" && match(s, /(^|[^A-Za-z0-9_.-])git[ \t]+[^ \t;|&)<>]+/)) {
        m = substr(s, RSTART, RLENGTH)
        s = substr(s, RSTART + RLENGTH)
        sub(/^[^g]*git[ \t]+/, "", m)
        if (m !~ /^(show|ls-tree|cat-file|rev-parse)$/) { gitbad = m }
      }
      if (!netbad && t ~ /(^|[^A-Za-z0-9_.-])(curl|wget|ssh|netcat|nc)([ \t]|$)/) { netbad = 1 }
      if (!evalbad && t ~ /(^|[^A-Za-z0-9_.-])eval([^A-Za-z0-9_]|$)/) { evalbad = 1 }
      if (!rmbad && t ~ /(^|[^A-Za-z0-9_.-])rm[ \t]+(-[A-Za-z-]*[ \t]+)*(-[A-Za-z]*[rR][A-Za-z]*|--recursive)([ \t]|$)/) { rmbad = 1 }
      if (srcbad_v == "") { srcbad_v = srcbad(t) }
    }
    END {
      if (gitbad != "") { print "check-body-git|the check runs git " gitbad ", and a check may run only git show, ls-tree, cat-file or rev-parse" }
      if (netbad) { print "check-body-net|the check calls curl, wget, nc or ssh, and a check may not use the network" }
      if (evalbad) { print "check-body-eval|the check uses eval, and a check may not" }
      if (rmbad) { print "check-body-rm|the check removes files recursively, and a check may not" }
      if (srcbad_v != "") { print "check-body-source|the check sources " srcbad_v ", and a check may source only a file under TMPDIR" }
      if (redir == "") {
        s = sqt
        while (awkout == "" && match(s, /(print|printf)[^;{}\n]*>>?[ \t]*"[^"]*"/)) {
          m = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
          sub(/^.*>[ \t]*"/, "", m); sub(/"$/, "", m)
          if (m !~ /^\/dev\// && m !~ /TMPDIR/) { awkout = m }
        }
        if (awkout != "") { redir = awkout " from an awk program" }
      }
      if (redir != "") { print "check-body-redirect|the check redirects output to " redir ", and a check may write only under TMPDIR or to /dev/null" }
      if (nn > 0) {
        hit = 0
        for (i = 1; i <= nn; i++) { if (index(mtext, need[i]) > 0) { hit = 1; break } }
        if (!hit) { print "check-body-vacuous|the check mentions none of the paths the note touches or removes and not its pattern outside a hint or skip message, so it tests nothing" }
      }
    }
  ' "$1"
}

# posture_changed PATH : 0 when base..upstream changes a verdict or protected_paths
# line, 1 when it does not, 2 when git could not produce the diff (the caller then
# reports a problem: a comparison that did not happen is never read as "unchanged")
posture_changed() {
  pc_d=$(git -C "$root" diff --no-ext-diff --no-color --unified=0 "$base" "$up" -- "$1" 2>/dev/null) || return 2
  printf '%s\n' "$pc_d" |
    grep -E -q '^[+-][[:space:]]*([A-Za-z0-9_.-]+[[:space:]]*=[[:space:]]*(ask|silent)([[:space:]]|#|$)|protected_paths)'
}

# lint_rows KIND LIST : the per-row rules; appends kind|path|channel to ROWS
lint_rows() {
  while IFS= read -r lr_row; do
    [ -n "$lr_row" ] || continue
    case $lr_row in
      *[![:space:]]@template|*[![:space:]]@adopted|*[![:space:]]@both)
        lr_glued=${lr_row##*@}
        problem "$n_relnote" "touches-channel: the $1 row $lr_row runs @$lr_glued into the path, and a channel name is written after a space"
        lr_row=${lr_row%@*};;
    esac
    lr_last=${lr_row##*[[:space:]]}
    case $lr_last in
      @template|@adopted|@both) :;;
      @*)
        problem "$n_relnote" "touches-channel: the $1 row $lr_row ends in $lr_last, which is not @both, @template or @adopted"
        lr_row=${lr_row%"$lr_last"}
        while :; do case $lr_row in *[[:space:]]) lr_row=${lr_row%?};; *) break;; esac; done;;
    esac
    lr_ts=$(ul_touch_split "$lr_row")
    lr_path=${lr_ts%"$tab"*}
    lr_ch=${lr_ts##*"$tab"}
    case $lr_path in
      '')
        problem "$n_relnote" "row-path: the $1 row $lr_row names no path"
        continue;;
      *[[:space:]]*)
        # adds rows may be plain words; a touches or removes row is one path
        if [ "$1" != adds ]; then
          problem "$n_relnote" "row-path: the $1 row $lr_row is more than one path"
        fi
        continue;;
      /*|..|../*|*/../*|*/..)
        problem "$n_relnote" "row-path: the $1 row $lr_path is not a path inside the repository"
        continue;;
    esac
    norm_path "$lr_path"; lr_np=$NP_V
    if ul_path_forbidden "$lr_np"; then
      problem "$n_relnote" "forbidden-path: the $1 row $lr_np is in a place a note may never name (product code, the project's own plans and knowledge, or the engine's own records)"
    fi
    if ul_path_protected "$lr_np" || ul_path_posture "$lr_np" || ul_path_security_surface "$lr_np"; then
      ln_prot=1
    fi
    if [ "$no_tree" = 0 ]; then
      case $1 in
        touches)
          if [ "$ln_pdata" != true ] && [ "$lr_ch" != @adopted ] && [ ! -e "$root/$lr_np" ] && [ ! -L "$root/$lr_np" ]; then
            problem "$n_relnote" "touches-exists: the touches path $lr_np does not exist in the tree"
          fi;;
        removes)
          if [ -e "$root/$lr_np" ] || [ -L "$root/$lr_np" ]; then
            problem "$n_relnote" "removes-present: the removes path $lr_np is still in the tree"
          fi;;
      esac
    fi
    if [ "$1" = touches ]; then
      case $lr_np in *.md) ln_md=1;; esac
    fi
    ROWS="$ROWS$1|$lr_np|$lr_ch$nl"
    printf '%s|%s|%s|%s\n' "$n_rel" "$n_id" "$n_relnote" "$lr_np" >> "$f_paths"
  done <<EOF
$2
EOF
}

# --------------------------------------------------------------- one note
lint_note() {
  ln_dir=${n_abs%/*}
  ln_fm=$(ul_frontmatter "$n_abs")
  if [ "$ln_fm" = NOFRONT ]; then
    problem "$n_relnote" "no-frontmatter: the file has no --- frontmatter block at the top"
    return 0
  fi

  fm_have=' '; v_id=; v_title=; v_purpose=; v_safety=; v_check=; v_pdata=; v_pattern=; v_multi=0
  L_touches=; L_adds=; L_removes=; L_requires=; L_done=; L_relaxes=; L_mdh=
  ln_dups=; ln_scalar_lists=
  ln_rec=$(printf '%s\n' "$ln_fm" | fm_extract)
  while IFS="$tab" read -r k_kind k_key k_val; do
    case $k_kind in
      H) fm_have="$fm_have$k_key ";;
      D) ln_dups="$ln_dups $k_key";;
      M) v_multi=1;;
      S) case $k_key in
           id) v_id=$k_val;;
           title) v_title=$k_val;;
           purpose) v_purpose=$k_val;;
           safety) v_safety=$k_val;;
           check) v_check=$k_val;;
           project-data) v_pdata=$k_val;;
           pattern) v_pattern=$k_val;;
           touches|adds|removes|requires|done-when|relaxes|may-drop-headings)
             # a list key carries nothing on its own line, or [] for an empty list
             ln_v=$k_val
             while :; do
               case $ln_v in
                 *' '*) ln_v=${ln_v%% *}${ln_v#* };;
                 *"$tab"*) ln_v=${ln_v%%"$tab"*}${ln_v#*"$tab"};;
                 *) break;;
               esac
             done
             case $ln_v in ''|'[]') :;; *) ln_scalar_lists="$ln_scalar_lists $k_key";; esac;;
         esac;;
      L) [ -n "$k_val" ] || continue
         case $k_key in
           touches) L_touches="$L_touches$k_val$nl";;
           adds) L_adds="$L_adds$k_val$nl";;
           removes) L_removes="$L_removes$k_val$nl";;
           requires) L_requires="$L_requires$k_val$nl";;
           done-when) L_done="$L_done$k_val$nl";;
           relaxes) L_relaxes="$L_relaxes$k_val$nl";;
           may-drop-headings) L_mdh="$L_mdh$k_val$nl";;
         esac;;
    esac
  done <<EOF
$ln_rec
EOF

  ln_missing=
  for ln_k in id title purpose touches adds requires safety done-when check project-data; do
    case $fm_have in *" $ln_k "*) :;; *) ln_missing="$ln_missing $ln_k";; esac
  done
  if [ -n "$ln_missing" ]; then
    problem "$n_relnote" "missing-key: these frontmatter keys are missing:$ln_missing"
    return 0
  fi
  if [ -n "$ln_dups" ]; then
    problem "$n_relnote" "duplicate-key: these keys appear more than once:$ln_dups, and a key is written once because every occurrence of a list key is read as part of the list"
  fi
  if [ -n "$ln_scalar_lists" ]; then
    problem "$n_relnote" "list-form: these list keys carry a value on the key line:$ln_scalar_lists, and a list is the key alone followed by indented - item lines, or [] for none"
  fi

  ln_empty=
  strip_q "$v_id"; blank "$SQ_V" && ln_empty="$ln_empty id"
  strip_q "$v_title"; blank "$SQ_V" && ln_empty="$ln_empty title"
  strip_q "$v_purpose"; blank "$SQ_V" && ln_empty="$ln_empty purpose"
  strip_q "$v_safety"; blank "$SQ_V" && ln_empty="$ln_empty safety"
  strip_q "$v_check"; blank "$SQ_V" && ln_empty="$ln_empty check"
  strip_q "$v_pdata"; blank "$SQ_V" && ln_empty="$ln_empty project-data"
  if [ -n "$ln_empty" ]; then
    problem "$n_relnote" "empty-key: these keys are present but carry no value:$ln_empty"
    return 0
  fi

  strip_q "$v_check"; ln_check=$SQ_V
  strip_q "$v_pattern"; ln_pattern=$SQ_V
  ln_safety=$v_safety
  ln_pdata=$v_pdata
  ln_prot=0
  ln_md=0
  ROWS=

  printf '%s|%s|%s|%s\n' "$n_id" "$n_rel" "$n_relnote" "$ln_safety" >> "$f_meta"
  while IFS= read -r ln_q; do
    [ -n "$ln_q" ] && printf '%s|%s\n' "$n_id" "$ln_q" >> "$f_edges"
  done <<EOF
$L_requires
EOF

  if [ -z "$L_touches" ] && [ -z "$L_removes" ]; then
    problem "$n_relnote" "touches-empty: touches has no items, and a note must touch a file or remove one"
  fi
  [ -n "$L_done" ] || problem "$n_relnote" "done-when-empty: done-when has no items, and a note needs at least one statement that holds once it is applied"
  if [ "$v_id" != "$n_id" ]; then
    problem "$n_relnote" "id-mismatch: the id $v_id does not match the file name $n_id"
  fi
  case $ln_safety in
    true|false) :;;
    *) problem "$n_relnote" "safety-value: safety must be true or false, not $ln_safety";;
  esac
  case $ln_pdata in
    true|false) :;;
    *) problem "$n_relnote" "project-data-value: project-data must be true or false, not $ln_pdata";;
  esac
  if [ "$v_multi" = 1 ]; then
    problem "$n_relnote" "purpose-multiline: purpose must be one line"
  fi

  # the rows (rules 1-4) and the flags they set
  lint_rows touches "$L_touches"
  lint_rows adds "$L_adds"
  lint_rows removes "$L_removes"

  # rule 5: project-data
  if [ -n "$ln_pattern" ]; then
    grep -E -e "$ln_pattern" /dev/null >/dev/null 2>&1
    if [ $? -gt 1 ]; then
      problem "$n_relnote" "pattern-compiles: the pattern does not compile as a grep -E expression"
    fi
  fi
  if [ "$ln_pdata" = true ]; then
    [ "$ln_safety" != true ] || problem "$n_relnote" "project-data-safety: a project-data note may not be a safety note"
    ln_nt=0
    while IFS='|' read -r ln_rk ln_rp ln_rc; do
      [ "$ln_rk" = touches ] || continue
      ln_nt=$((ln_nt + 1))
      if ! ul_project_data_allowed "$ln_rp"; then
        problem "$n_relnote" "project-data-allowed: $ln_rp is not a file a project-data note may touch, because LogicLoom ships it"
      fi
    done <<EOF
$ROWS
EOF
    if [ "$ln_nt" != 1 ]; then
      problem "$n_relnote" "project-data-touches: a project-data note touches exactly one file, not $ln_nt"
    fi
    [ -n "$ln_pattern" ] || problem "$n_relnote" "project-data-pattern: a project-data note needs a non-empty pattern"
    if ! grep -q '^## What this note may claim[[:space:]]*$' "$n_abs" || ! grep -q '^## Example[[:space:]]*$' "$n_abs"; then
      problem "$n_relnote" "project-data-sections: a project-data note needs the sections What this note may claim and Example"
    fi
  fi

  # rules 6, 7 and the check file
  case $ln_check in
    none)
      if [ "$ln_safety" = true ]; then
        problem "$n_relnote" "check-none-safety: a safety note must name a check file, not none"
      elif [ "$ln_prot" = 1 ]; then
        problem "$n_relnote" "protected-needs-check: a note on a protected, posture or security-surface path must name a check file, not none"
      else
        warn "$n_relnote" "check: none means this note is offered once and never re-verified"
      fi;;
    */*)
      problem "$n_relnote" "check-name: the check must be the name of a file beside the note, not a path";;
    *)
      if [ ! -f "$ln_dir/$ln_check" ] || [ ! -s "$ln_dir/$ln_check" ]; then
        problem "$n_relnote" "check-missing: the check file $ln_check is missing or empty beside the note"
      elif ! sh -n "$ln_dir/$ln_check" >/dev/null 2>&1; then
        problem "$n_relnote" "check-syntax: the check file $ln_check does not parse as shell"
      else
        : > "$f_needles"
        while IFS='|' read -r ln_rk ln_rp ln_rc; do
          case $ln_rk in touches|removes) printf '%s\n' "$ln_rp" >> "$f_needles";; esac
        done <<EOF
$ROWS
EOF
        [ -z "$ln_pattern" ] || printf '%s\n' "$ln_pattern" >> "$f_needles"
        ln_ab=$(analyze_check "$ln_dir/$ln_check")
        while IFS='|' read -r ab_rule ab_msg; do
          [ -n "$ab_rule" ] && problem "$n_relnote" "$ab_rule: $ab_msg"
        done <<EOF
$ln_ab
EOF
      fi;;
  esac

  # rule 9: relaxes
  if [ -n "$L_relaxes" ]; then
    if [ "$ln_safety" = true ]; then
      problem "$n_relnote" "relaxes-safety: a safety note may not relax anything"
    else
      while IFS= read -r ln_rx; do
        [ -n "$ln_rx" ] || continue
        ln_ok=$(printf '%s\n' "$ln_rx" | awk -v tb="$tab" '
          {
            s = $0
            gsub(/ :: /, tb, s)
            n = split(s, f, tb)
            ok = (n == 3)
            for (i = 1; i <= n; i++) { v = f[i]; gsub(/^[ \t]+|[ \t]+$/, "", v); if (v == "") { ok = 0 } }
            if (ok) { v = f[1]; gsub(/^[ \t]+|[ \t]+$/, "", v); print "ok " v } else { print "bad" }
          }')
        case $ln_ok in
          ok\ *)
            norm_path "${ln_ok#ok }"
            case $ROWS in
              touches\|"$NP_V"\|*|*"${nl}touches|$NP_V|"*) :;;
              *) problem "$n_relnote" "relaxes-path: the relaxes entry names $NP_V, which the note does not touch";;
            esac;;
          *) problem "$n_relnote" "relaxes-format: a relaxes entry is written path :: list :: entry, with all three parts";;
        esac
      done <<EOF
$L_relaxes
EOF
    fi
  fi

  # rule 10: may-drop-headings
  if [ -n "$L_mdh" ] && [ "$ln_md" = 0 ]; then
    problem "$n_relnote" "may-drop-headings: may-drop-headings is for a note that touches a .md file, and this one touches none"
  fi

  # rule 13: identity markers in the note and its check
  ln_hit=$(grep -F -o -m 1 -e "$mk_a" -e "$mk_b" -e "$mk_c" -e "$mk_d" -e "$mk_e" "$n_abs" 2>/dev/null)
  if [ -n "$ln_hit" ]; then
    problem "$n_relnote" "id-marker: the note contains $ln_hit, which must not appear in a shipped note"
  elif [ "$ln_check" != none ] && [ -f "$ln_dir/$ln_check" ]; then
    ln_hit=$(grep -F -o -m 1 -e "$mk_a" -e "$mk_b" -e "$mk_c" -e "$mk_d" -e "$mk_e" "$ln_dir/$ln_check" 2>/dev/null)
    if [ -n "$ln_hit" ]; then
      problem "$n_relnote" "id-marker: the check $ln_check contains $ln_hit, which must not appear in a shipped check"
    fi
  fi

  # rule 14: a verdict or protected_paths change must come from a safety note
  if [ -n "$up" ] && [ "$ln_safety" != true ]; then
    while IFS='|' read -r ln_rk ln_rp ln_rc; do
      [ "$ln_rk" = touches ] || continue
      ul_path_posture "$ln_rp" || continue
      posture_changed "$ln_rp"
      case $? in
        0) problem "$n_relnote" "posture-safety: the upstream change to $ln_rp alters a verdict or a protected_paths line, so this note must be safety: true"
           break;;
        2) problem "$n_relnote" "posture-safety: could not compare $ln_rp between the base and upstream revisions, so a verdict change cannot be ruled out and this note is not accepted"
           break;;
      esac
    done <<EOF
$ROWS
EOF
  fi
}

# ------------------------------------------------------------ enumerate notes
rels=
if [ -d "$nabs" ]; then
  for d in "$nabs"/*/; do
    [ -d "$d" ] || continue
    d=${d%/}
    if [ ! -r "$d" ] || [ ! -x "$d" ]; then
      # an unreadable folder of notes is an error, never "no notes to lint"
      printf 'error the release folder %s cannot be read, so its notes cannot be linted\n' "${d#"$root"/}" >&2
      exit 1
    fi
    rels="$rels${d##*/}$nl"
  done
fi
notes_n=0
rank_list=
if [ -n "$rels" ]; then
  rels_sorted=$(printf '%s' "$rels" | sort -t. -k1,1n -k2,2n -k3,3n)
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    rank_list="$rank_list $rel"
    for f in "$nabs/$rel"/*.md; do
      [ -f "$f" ] || continue
      b=${f##*/}
      [ "$b" = README.md ] && continue
      case $f in "$root"/*) rn=${f#"$root"/};; *) rn=$f;; esac
      printf '%s|%s|%s|%s\n' "$rel" "${b%.md}" "$rn" "$f" >> "$f_idx"
      notes_n=$((notes_n + 1))
    done
  done <<EOF
$rels_sorted
EOF
fi

# id-duplicate: the same id in two release folders makes `requires` ambiguous
if [ "$notes_n" -gt 1 ]; then
  awk -F'|' '
    ($2 in seen) { print $3 "|" seen[$2]; next }
    { seen[$2] = $3 }
  ' "$f_idx" > "$f_out"
  while IFS='|' read -r dup_note dup_first; do
    problem "$dup_note" "id-duplicate: this id is already used by $dup_first, and an id is never reused"
  done < "$f_out"
fi

while IFS='|' read -r n_rel n_id n_relnote n_abs <&3; do
  lint_note
done 3< "$f_idx"

# ---------------------------------------------------- rule 8: requires graph
if [ -s "$f_edges" ]; then
  awk -F'|' -v ranks="$rank_list" -v metaf="$f_meta" '
    function reaches(s,   sp, cur, m, i, nx, parts) {
      gen++
      sp = 0
      stk[++sp] = s
      while (sp > 0) {
        cur = stk[sp--]
        m = split(adj[cur], parts, " ")
        for (i = 1; i <= m; i++) {
          nx = parts[i]
          if (nx == s) { return 1 }
          if (seen[nx] != gen) { seen[nx] = gen; stk[++sp] = nx }
        }
      }
      return 0
    }
    BEGIN {
      nr = split(ranks, rl, " ")
      for (i = 1; i <= nr; i++) { rank[rl[i]] = i }
      while ((getline line < metaf) > 0) {
        split(line, m, "|")
        mrel[m[1]] = m[2]; mnote[m[1]] = m[3]; msafe[m[1]] = m[4]
      }
    }
    {
      from = $1; to = $2
      adj[from] = adj[from] " " to
      nodes[from] = 1
      if (!(to in mrel)) {
        print "requires-unknown|" mnote[from] "|requires " to ", which is not a note in any release folder"
      } else if (rank[mrel[to]] > rank[mrel[from]]) {
        print "requires-later|" mnote[from] "|requires " to ", which ships in the later release " mrel[to]
      } else if (msafe[from] == "true" && msafe[to] == "false") {
        print "requires-safety|" mnote[from] "|a safety note may not require " to ", which is not a safety note"
      }
    }
    END {
      for (n in nodes) {
        if (reaches(n)) { print "requires-cycle|" mnote[n] "|" n " is part of a requires cycle" }
      }
    }
  ' "$f_edges" > "$f_out"
  while IFS='|' read -r rq_rule rq_note rq_msg; do
    problem "$rq_note" "$rq_rule: $rq_msg"
  done < "$f_out"
fi

# --------------------------------------------------- rule 11: overlap groups
if [ "$notes_n" -gt 2 ] && [ -s "$f_paths" ]; then
  awk -F'|' '
    function find(x) { while (par[x] != x) { x = par[x] } return x }
    function union(a, b,   ra, rb) { ra = find(a); rb = find(b); if (ra != rb) { par[rb] = ra } }
    {
      k = $1 "|" $2
      if (!(k in par)) { par[k] = k; order[++n] = k; rel[k] = $1; id[k] = $2; note[k] = $3 }
      pk = $1 "|" $4
      if (pk in owner) { union(owner[pk], k) } else { owner[pk] = k }
    }
    END {
      for (i = 1; i <= n; i++) {
        r = find(order[i])
        size[r]++
        names[r] = names[r] (names[r] == "" ? "" : ", ") id[order[i]]
        if (first[r] == "") { first[r] = note[order[i]]; grel[r] = rel[order[i]] }
      }
      for (i = 1; i <= n; i++) {
        r = order[i]
        if (par[r] == r && size[r] > 2) { print first[r] "|" grel[r] "|" names[r] }
      }
    }
  ' "$f_paths" > "$f_out"
  while IFS='|' read -r ov_note ov_rel ov_names; do
    warn "$ov_note" "overlap: $ov_names share files in release $ov_rel, so they are approved as one group"
  done < "$f_out"
fi

# -------------------------------------------------------------------- report
printf 'notes=%s problems=%s warnings=%s\n' "$notes_n" "$np" "$nw"
if [ "$np" -gt 0 ]; then exit 1; fi
exit 0
