#!/usr/bin/env bash
# validate-environments.sh — READER + VALIDATOR for .logic-loom/config/environments.conf
#
# WHAT IT DOES: parses the environment declaration, checks it for coherence, and
# prints the promotion order.
#
# WHAT IT DOES NOT DO, EVER: deploy anything, invoke the `deploy` seam, run git,
# create a branch, or write a file. It is read-only by construction. The harness
# ships the DECLARATION and the GATE STRUCTURE; deploy execution belongs to the
# product behind the `deploy` seam.
#
# Checks:
#   1. no key outside an `environment = <name>` block
#   2. no duplicate environment name
#   3. no unknown key                              (WARNING — ignored, not fatal)
#   4. `requires_approval` is true|false           (ERROR)
#   5. every `promotes_from` names a declared env  (ERROR)
#   6. the promotion order is acyclic              (ERROR, names the cycle)
#
# Exit: 0 = valid (including "nothing declared" and warnings-only)
#       1 = validation errors
#       2 = usage error
#
# An ABSENT config exits 0: a project with no environments declared is normal.
#
# Usage: validate-environments.sh [CONF] [--root REPO_ROOT] [--quiet]
#   CONF     default: $LOOM_ENVIRONMENTS_CONF, else <repo-root>/.logic-loom/config/environments.conf
#   --quiet  suppress the report; print only warnings/errors and set the exit code
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

CONF=""; ROOT=""; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root)   ROOT="${2:-}"; shift 2 || true ;;
    --root=*) ROOT="${1#--root=}"; shift ;;
    --quiet|-q) QUIET=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    -*) echo "ERROR: unknown option '$1'" >&2; exit 2 ;;
    *)  [ -z "$CONF" ] && CONF="$1"; shift ;;
  esac
done

_sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -n "$ROOT" ] || ROOT="$(cd "$_sd/../../.." && pwd)"
[ -n "$CONF" ] || CONF="${LOOM_ENVIRONMENTS_CONF:-$ROOT/.logic-loom/config/environments.conf}"

say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; WARNINGS=$((WARNINGS + 1)); }
err()  { printf 'ERROR: %s\n' "$*" >&2; ERRORS=$((ERRORS + 1)); }

WARNINGS=0
ERRORS=0

# ── absent / unreadable config: normal, not an error ─────────────────────────
if [ ! -f "$CONF" ]; then
  say "environments: no declaration at '$CONF' — nothing declared (this is normal)."
  exit 0
fi
if [ ! -r "$CONF" ]; then
  err "config exists but is not readable: '$CONF'"
  exit 1
fi

# ── parse ────────────────────────────────────────────────────────────────────
# Records accumulate as newline-separated, `|`-delimited lines:
#   name|branch|promotes_from|requires_approval|deploy
# `|` and not tab: tab is an IFS-whitespace character, so `read` would collapse
# runs of it and silently shift the fields of any record with an empty value.
# A value containing `|` is rejected below so the delimiter stays unambiguous.
RECORDS=""
NAMES=""          # newline-separated, declaration order
cur_name=""; cur_branch=""; cur_from=""; cur_appr=""; cur_deploy=""
have_env=0
lineno=0

trim() { # value -> trimmed
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

flush_record() {
  [ -n "$cur_name" ] || return 0
  RECORDS="${RECORDS}${cur_name}|${cur_branch}|${cur_from}|${cur_appr}|${cur_deploy}
"
  cur_branch=""; cur_from=""; cur_appr=""; cur_deploy=""
}

name_declared() { # name -> 0 if present in NAMES
  local n="$1" x
  printf '%s\n' "$NAMES" | grep -qxF "$n"
}

while IFS= read -r line || [ -n "$line" ]; do
  lineno=$((lineno + 1))
  line="${line%%#*}"                 # strip comment
  line="$(trim "$line")"
  [ -n "$line" ] || continue

  case "$line" in
    *=*) ;;
    *) warn "line $lineno: not a 'key = value' line, ignored: '$line'"; continue ;;
  esac

  key="$(trim "${line%%=*}")"
  val="$(trim "${line#*=}")"

  case "$key" in
    environment)
      flush_record
      have_env=1
      case "$val" in
        "")            err "line $lineno: 'environment' needs a name"; cur_name=""; continue ;;
        *[!A-Za-z0-9_-]*) err "line $lineno: invalid environment name '$val' (allowed: A-Z a-z 0-9 _ -)"; cur_name=""; continue ;;
      esac
      if name_declared "$val"; then
        err "line $lineno: duplicate environment name '$val'"
        cur_name=""; continue
      fi
      cur_name="$val"
      NAMES="${NAMES}${val}
"
      ;;
    branch|promotes_from|requires_approval|deploy)
      if [ "$have_env" -eq 0 ]; then
        err "line $lineno: '$key' appears before any 'environment = <name>' — it belongs to no environment"
        continue
      fi
      [ -n "$cur_name" ] || continue   # block opener was rejected; skip its keys
      case "$val" in
        *'|'*) err "line $lineno: '$key' value may not contain '|'"; continue ;;
      esac
      case "$key" in
        branch)        cur_branch="$val" ;;
        promotes_from) cur_from="$val" ;;
        deploy)        cur_deploy="$val" ;;
        requires_approval)
          case "$val" in
            true|false) cur_appr="$val" ;;
            *) err "line $lineno: requires_approval must be 'true' or 'false', got '$val'" ;;
          esac
          ;;
      esac
      ;;
    *)
      warn "line $lineno: unknown key '$key' — ignored (known keys: environment, branch, promotes_from, requires_approval, deploy)"
      ;;
  esac
done < "$CONF"
flush_record

RECORDS="$(printf '%s' "$RECORDS")"
NAMES="$(printf '%s' "$NAMES")"

if [ -z "$RECORDS" ]; then
  if [ "$ERRORS" -ne 0 ]; then
    say "environments: no valid environment declared (see errors above)."
    exit 1
  fi
  say "environments: none declared in '$CONF' (this is normal)."
  [ "$WARNINGS" -ne 0 ] && say "environments: $WARNINGS warning(s)."
  exit 0
fi

field() { # record-line, index -> field
  printf '%s' "$1" | cut -d'|' -f"$2"
}

pred_of() { # name -> its promotes_from (may be empty)
  printf '%s\n' "$RECORDS" | while IFS='|' read -r n b f a d; do
    [ "$n" = "$1" ] && { printf '%s' "$f"; break; }
  done
}

# ── predecessor must exist, and must not be the environment itself ──────────
# NOTE: every loop over $RECORDS below uses a heredoc, never a pipe. A pipe puts
# the loop body in a subshell, where the ERRORS counter and $PLACED would be
# mutated and then thrown away.
while IFS='|' read -r n b f a d; do
  [ -n "$n" ] || continue
  [ -n "$f" ] || continue
  if ! name_declared "$f"; then
    err "environment '$n' names predecessor '$f', which is not declared"
  fi
  if [ "$f" = "$n" ]; then
    err "environment '$n' names itself as its predecessor"
  fi
done <<EOF
$RECORDS
EOF

# ── cycle detection (Kahn-style pruning over a single-predecessor graph) ─────
# Repeatedly place any environment whose predecessor is empty, unresolvable
# (already reported), or already placed. Whatever never places is in a cycle or
# downstream of one.
PLACED=""
placed_count=0
total_count="$(printf '%s\n' "$NAMES" | grep -c . || true)"
progress=1
while [ "$progress" -eq 1 ]; do
  progress=0
  while IFS='|' read -r n b f a d; do
    [ -n "$n" ] || continue
    printf '%s\n' "$PLACED" | grep -qxF "$n" && continue
    if [ -z "$f" ] || ! name_declared "$f" || printf '%s\n' "$PLACED" | grep -qxF "$f"; then
      PLACED="${PLACED}${n}
"
      placed_count=$((placed_count + 1))
      progress=1
    fi
  done <<EOF
$RECORDS
EOF
done

UNPLACED=""
while IFS='|' read -r n b f a d; do
  [ -n "$n" ] || continue
  printf '%s\n' "$PLACED" | grep -qxF "$n" || UNPLACED="${UNPLACED}${n}
"
done <<EOF
$RECORDS
EOF

if [ -n "$(printf '%s' "$UNPLACED")" ]; then
  # Walk from the first unplaced node until a name repeats — that walk's tail is
  # the cycle. Bounded by the number of environments, so it always terminates.
  start="$(printf '%s\n' "$UNPLACED" | grep . | head -1)"
  seen=""; path=""; node="$start"; steps=0
  while [ -n "$node" ] && [ "$steps" -le "$total_count" ]; do
    if printf '%s\n' "$seen" | grep -qxF "$node"; then
      # trim path to start at the repeated node
      cyc="$(printf '%s\n' "$path" | sed -n "/^${node}\$/,\$p" | grep .)"
      chain="$(printf '%s\n' "$cyc" | tr '\n' '@' | sed 's/@$//; s/@/ -> /g')"
      err "cycle in promotion order (following promotes_from): $chain -> $node"
      break
    fi
    seen="${seen}${node}
"
    path="${path}${node}
"
    node="$(pred_of "$node")"
    steps=$((steps + 1))
  done
  [ "$ERRORS" -ne 0 ] || err "cycle in promotion order involving: $(printf '%s\n' "$UNPLACED" | grep . | tr '\n' ' ')"
fi

# ── report ───────────────────────────────────────────────────────────────────
if [ "$ERRORS" -eq 0 ]; then
  say "environments: $total_count declared in '$CONF'"
  say ""
  say "Promotion order:"
  step=0
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    step=$((step + 1))
    rec="$(printf '%s\n' "$RECORDS" | grep "^${n}|")"
    b="$(field "$rec" 2)"; f="$(field "$rec" 3)"; a="$(field "$rec" 4)"; dep="$(field "$rec" 5)"
    [ -n "$a" ] || a="false"
    gate="no approval"
    [ "$a" = "true" ] && gate="APPROVAL REQUIRED"
    from="(start of chain)"
    [ -n "$f" ] && from="from '$f'"
    say "  $step. $n — $from; branch: ${b:-<none>}; $gate"
    if [ -n "$dep" ]; then
      if [ -e "$ROOT/$dep" ]; then
        say "       deploy seam: $dep (present — product-owned; the harness never runs it)"
      else
        say "       deploy seam: $dep (NOT PRESENT — yours to provide)"
      fi
    else
      say "       deploy seam: <undeclared> — this environment has no deploy script; the harness ships none"
    fi
  done <<EOF
$PLACED
EOF
  say ""
  say "Reminder: nothing here is enforced. No deploy was run and no git command was issued."
fi

[ "$WARNINGS" -ne 0 ] && say "environments: $WARNINGS warning(s)."
if [ "$ERRORS" -ne 0 ]; then
  say "environments: $ERRORS error(s) — declaration is not valid."
  exit 1
fi
exit 0
