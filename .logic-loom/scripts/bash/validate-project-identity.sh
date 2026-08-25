#!/usr/bin/env bash
# validate-project-identity.sh — READER + VALIDATOR for .logic-loom/config/project.conf
#
# WHAT IT DOES: parses the project identity declaration, checks it, and prints it.
#
# WHAT IT DOES NOT DO, EVER: write a file, run git, resolve a remote, contact a
# network, or stamp the identity for you. It is read-only by construction. The
# harness ships the DECLARATION and the READER; stamping belongs to
# `/initialize-project` (or your own hands).
#
# Checks:
#   1. every required key present                  (ERROR when missing)
#   2. no duplicate key                            (ERROR)
#   3. project_slug matches [a-z0-9][a-z0-9-]*     (ERROR)
#   4. id_prefix matches [A-Z][A-Z0-9]{1,5}        (ERROR)
#   5. project_name is non-empty                   (ERROR)
#   6. `__UNSET__` placeholder still in place      (WARNING — a fresh clone that
#                                                   has not run /initialize-project
#                                                   is a normal state, not a fault)
#   7. unknown key                                 (WARNING — ignored, not fatal)
#
# Exit: 0 = valid (including "absent", "unstamped", and warnings-only)
#       1 = validation errors
#       2 = usage error
#
# An ABSENT config exits 0: a project that has not declared an identity is normal.
#
# Usage: validate-project-identity.sh [CONF] [--root REPO_ROOT] [--quiet]
#   CONF     default: $LOOM_PROJECT_CONF, else <repo-root>/.logic-loom/config/project.conf
#   --quiet  suppress the report; print only warnings/errors and set the exit code
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

PLACEHOLDER="__UNSET__"

CONF=""; ROOT=""; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root)   ROOT="${2:-}"; shift 2 || true ;;
    --root=*) ROOT="${1#--root=}"; shift ;;
    --quiet|-q) QUIET=1; shift ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    -*) echo "ERROR: unknown option '$1'" >&2; exit 2 ;;
    *)  [ -z "$CONF" ] && CONF="$1"; shift ;;
  esac
done

_sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -n "$ROOT" ] || ROOT="$(cd "$_sd/../../.." && pwd)"
[ -n "$CONF" ] || CONF="${LOOM_PROJECT_CONF:-$ROOT/.logic-loom/config/project.conf}"

WARNINGS=0
ERRORS=0

say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; WARNINGS=$((WARNINGS + 1)); }
err()  { printf 'ERROR: %s\n' "$*" >&2; ERRORS=$((ERRORS + 1)); }

# ── absent / unreadable config: normal, not an error ─────────────────────────
if [ ! -f "$CONF" ]; then
  say "project identity: no declaration at '$CONF' — nothing declared (this is normal)."
  exit 0
fi
if [ ! -r "$CONF" ]; then
  err "config exists but is not readable: '$CONF'"
  exit 1
fi

# ── parse ────────────────────────────────────────────────────────────────────
# A project has exactly one identity, so there is no block opener: every key is
# top-level and may appear at most once. Values are held in plain scalars; SEEN
# is a newline-separated list of the keys encountered, used for duplicate
# detection and for distinguishing "absent" from "present but empty".
SLUG=""; NAME=""; PREFIX=""; REPO=""
SEEN=""
lineno=0

trim() { # value -> trimmed
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

key_seen() { # key -> 0 if already recorded
  printf '%s\n' "$SEEN" | grep -qxF "$1"
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
    project_slug|project_name|id_prefix|repo)
      if key_seen "$key"; then
        err "line $lineno: duplicate key '$key' — a project has exactly one identity"
        continue
      fi
      SEEN="${SEEN}${key}
"
      case "$key" in
        project_slug) SLUG="$val" ;;
        project_name) NAME="$val" ;;
        id_prefix)    PREFIX="$val" ;;
        repo)         REPO="$val" ;;
      esac
      ;;
    *)
      warn "line $lineno: unknown key '$key' — ignored (known keys: project_slug, project_name, id_prefix, repo)"
      ;;
  esac
done < "$CONF"

# ── required keys present ────────────────────────────────────────────────────
for k in project_slug project_name id_prefix; do
  key_seen "$k" || err "required key '$k' is missing from '$CONF'"
done

# ── placeholder detection runs BEFORE format validation ──────────────────────
# An unstamped clone must read as "not initialized yet" (WARNING), never as
# "malformed" (ERROR) — the placeholder is deliberately not a legal slug, so
# checking format first would report the shipped file as broken.
UNSTAMPED=0
[ "$SLUG"   = "$PLACEHOLDER" ] && UNSTAMPED=$((UNSTAMPED + 1))
[ "$NAME"   = "$PLACEHOLDER" ] && UNSTAMPED=$((UNSTAMPED + 1))
[ "$PREFIX" = "$PLACEHOLDER" ] && UNSTAMPED=$((UNSTAMPED + 1))

if [ "$UNSTAMPED" -gt 0 ]; then
  warn "project identity is UNSTAMPED: $UNSTAMPED of 3 required values are still the '$PLACEHOLDER' placeholder."
  warn "  Run /initialize-project, or edit '$CONF' by hand. Until then this project has no stable identity"
  warn "  and anything aggregating across projects has nothing to key on. This is normal on a fresh clone."
fi

# ── format validation (skipped per-key when that key is a placeholder) ───────
if key_seen project_slug && [ "$SLUG" != "$PLACEHOLDER" ]; then
  if [ -z "$SLUG" ]; then
    err "project_slug is empty — it is the machine key and must be set"
  else
    case "$SLUG" in
      [a-z0-9]*) : ;;
      *) err "invalid project_slug '$SLUG' — must start with a lowercase letter or digit" ;;
    esac
    case "$SLUG" in
      *[!a-z0-9-]*) err "invalid project_slug '$SLUG' — allowed characters: a-z 0-9 - (lowercase kebab)" ;;
    esac
  fi
fi

if key_seen id_prefix && [ "$PREFIX" != "$PLACEHOLDER" ]; then
  if [ -z "$PREFIX" ]; then
    err "id_prefix is empty — it is used to mint task ids and must be set"
  else
    case "$PREFIX" in
      [A-Z]*) : ;;
      *) err "invalid id_prefix '$PREFIX' — must start with an uppercase letter" ;;
    esac
    case "$PREFIX" in
      *[!A-Z0-9]*) err "invalid id_prefix '$PREFIX' — allowed characters: A-Z 0-9 (uppercase)" ;;
    esac
    plen=${#PREFIX}
    if [ "$plen" -lt 2 ] || [ "$plen" -gt 6 ]; then
      err "invalid id_prefix '$PREFIX' — must be 2 to 6 characters (got $plen)"
    fi
  fi
fi

if key_seen project_name && [ "$NAME" != "$PLACEHOLDER" ] && [ -z "$NAME" ]; then
  err "project_name is empty — it is the human display name and must be set"
fi

# ── report ───────────────────────────────────────────────────────────────────
if [ "$ERRORS" -eq 0 ]; then
  if [ "$UNSTAMPED" -gt 0 ]; then
    say "project identity: declared but UNSTAMPED in '$CONF'"
    say ""
    say "  slug:   ${SLUG:-<unset>}"
    say "  name:   ${NAME:-<unset>}"
    say "  prefix: ${PREFIX:-<unset>}"
    say ""
    say "Stamp it with /initialize-project before relying on cross-project identity."
  else
    say "project identity: valid in '$CONF'"
    say ""
    say "  slug:   $SLUG        (machine key — immutable once set)"
    say "  name:   $NAME"
    say "  prefix: $PREFIX       (task ids mint as ${PREFIX}-001, ${PREFIX}-002, …)"
    if [ -n "$REPO" ]; then
      say "  repo:   $REPO        (declared label — NOT verified; the git remote is the truth)"
    else
      say "  repo:   <undeclared> (optional; the git remote is the truth either way)"
    fi
  fi
  say ""
  say "Reminder: nothing here is enforced. No file was written and no git command was issued."
fi

[ "$WARNINGS" -ne 0 ] && say "project identity: $WARNINGS warning(s)."
if [ "$ERRORS" -ne 0 ]; then
  say "project identity: $ERRORS error(s) — declaration is not valid."
  exit 1
fi
exit 0
