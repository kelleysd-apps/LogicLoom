#!/usr/bin/env bash
# check-brain-signals.sh — ADVISORY liveness + load signals for the `.brain/` layer.
#
# Prints a short notice on stdout, or NOTHING. Always exits 0. Writes no repo
# file. Runs NO git. It cannot block, fail, or slow anything down meaningfully.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHAT THIS IS NOT
# ─────────────────────────────────────────────────────────────────────────────
# It is not a gate. The fail-closed gate is check-brain-record.sh, and it gates a
# different question. A gate must assert something the change in front of it
# caused; "you have not distilled in 40 days" is not that. Gating on it would
# block unrelated work, train bypass, and hand every cloner who never adopts the
# routine a permanently red build.
#
# So this is a nudge in a context window, not a red build. That is the correct
# strength for a habit signal, and it is also its ceiling: someone who ignores a
# line of advisory text for six weeks gets exactly the outcome the design warns
# about, and nothing here prevents it. Said plainly rather than dressed up.
#
# ─────────────────────────────────────────────────────────────────────────────
# TWO SIGNALS, MEASURED DIFFERENTLY ON PURPOSE
# ─────────────────────────────────────────────────────────────────────────────
#   LOAD      "is there a backlog?"     = count of `status: unprocessed` captures
#   LIVENESS  "did the pass run?"       = age of the NEWEST .brain/DISTILL-LOG.md entry
#
# Queue depth is the right shape and the wrong reading for liveness: a pass that
# ran and cleared the queue, and a pass nobody ever installed over a repo where
# nobody captured anything, BOTH read zero. In the system this was ported from,
# depth read zero on eight of its last ten runs. Log age is exact, needs no
# knowledge of scheduling, and cannot be faked by an empty queue.
#
# ─────────────────────────────────────────────────────────────────────────────
# SILENCE RULES — the reason this stays worth reading
# ─────────────────────────────────────────────────────────────────────────────
#  - Silent when there are NO unprocessed captures AND no DISTILL-LOG.md.
#    An unadopted routine must make no noise. Same structural-silence discipline
#    check-dev-branch-base.sh uses to stay quiet in a customer clone.
#  - The liveness warning requires an old log AND at least one unprocessed
#    capture. The conjunction is the whole point: a quiet month over an empty
#    queue is not a fault, and warning about it is the nagging that gets an
#    advisory tuned out.
#  - Once per session per state (see --once), not once per prompt.
#  - `advisory_enabled = false` in .logic-loom/config/brain.conf silences both.
#
# Thresholds: .logic-loom/config/brain.conf. One key each, no wildcard.
#
# ─────────────────────────────────────────────────────────────────────────────
# HOW IT REACHES THE MODEL
# ─────────────────────────────────────────────────────────────────────────────
# Through the existing UserPromptSubmit preflight injection, via the loom-memory
# search output that governance-preflight.sh already injects as
# `additionalContext`. It rides that hook rather than modifying it: the preflight
# hook is on the governance protected-path list, and the cheapest change to a
# governance surface is none.
#
# HONEST LIMITS of riding that path, stated rather than discovered later:
#   - memory-search.sh is skipped for prompts under ~12 characters, so a session
#     of one-word replies may not see the notice.
#   - it runs under a 2s timeout; a very large `.brain/raw/` could be cut off.
#   - `MEMORY_ENABLED=false` in the loom-memory config silences this too.
# All three degrade to silence, never to a wrong answer.
#
# bash 3.2 safe: no associative arrays, no mapfile, no `[[ -v ]]`, no ${v,,}.
# Testing overrides: LOOM_BRAIN_ROOT, LOOM_BRAIN_CONF, LOOM_BRAIN_STATE_DIR,
#                    LOOM_BRAIN_TODAY (YYYY-MM-DD).
#
#   Flags:  --once   suppress if this exact notice already fired this session

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${LOOM_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
BRAIN="${LOOM_BRAIN_ROOT:-$REPO_ROOT/.brain}"
CONF="${LOOM_BRAIN_CONF:-$REPO_ROOT/.logic-loom/config/brain.conf}"

ONCE=0
[ "${1:-}" = "--once" ] && ONCE=1

# Nothing to say about a tree with no brain layer.
[ -d "$BRAIN" ] || exit 0

# ── Config ───────────────────────────────────────────────────────────────────
_conf_get() { # key -> value or empty; never sources the file, first match wins
  local key="$1" line rest
  [ -r "$CONF" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    while [ "${line# }" != "$line" ] || [ "${line#	}" != "$line" ]; do
      line="${line# }"; line="${line#	}"
    done
    case "$line" in "$key"*) ;; *) continue ;; esac
    rest="${line#"$key"}"
    while [ "${rest# }" != "$rest" ] || [ "${rest#	}" != "$rest" ]; do
      rest="${rest# }"; rest="${rest#	}"
    done
    case "$rest" in =*) ;; *) continue ;; esac
    rest="${rest#=}"; rest="${rest%%#*}"
    while [ "${rest# }" != "$rest" ] || [ "${rest#	}" != "$rest" ]; do
      rest="${rest# }"; rest="${rest#	}"
    done
    while [ "${rest% }" != "$rest" ] || [ "${rest%	}" != "$rest" ]; do
      rest="${rest% }"; rest="${rest%	}"
    done
    printf '%s' "$rest"; return 0
  done < "$CONF"
  return 0
}

_num_or() { # value default -> a non-negative integer
  case "$1" in
    ''|*[!0-9]*) printf '%s' "$2" ;;
    *)           printf '%s' "$1" ;;
  esac
}

ENABLED="$(_conf_get advisory_enabled)"
[ "$ENABLED" = "false" ] && exit 0

LOAD_MAX="$(_num_or "$(_conf_get load_max_unprocessed)" 5)"
LOAD_AGE="$(_num_or "$(_conf_get load_max_age_days)" 21)"
LIVE_AGE="$(_num_or "$(_conf_get liveness_max_age_days)" 30)"

# ── Portable date helpers (BSD and GNU) ──────────────────────────────────────
_today_epoch() {
  if [ -n "${LOOM_BRAIN_TODAY:-}" ]; then
    _date_epoch "$LOOM_BRAIN_TODAY"; return
  fi
  date +%s
}
_date_epoch() { # YYYY-MM-DD -> epoch seconds, empty on failure
  local d="$1" e
  e="$(date -j -f '%Y-%m-%d' "$d" '+%s' 2>/dev/null)" || e=""
  [ -n "$e" ] || e="$(date -d "$d" '+%s' 2>/dev/null)" || e=""
  printf '%s' "$e"
}
_file_epoch() { # path -> mtime epoch, empty on failure
  local f="$1" e
  e="$(stat -f '%m' "$f" 2>/dev/null)" || e=""
  [ -n "$e" ] || e="$(stat -c '%Y' "$f" 2>/dev/null)" || e=""
  printf '%s' "$e"
}
_days_since() { # epoch -> whole days, empty if input empty
  local e="$1" now
  [ -n "$e" ] || return 0
  now="$(_today_epoch)"
  [ -n "$now" ] || return 0
  printf '%s' "$(( (now - e) / 86400 ))"
}

# Same frontmatter reader as the gate: parse the block, never grep the file.
# Quoted (`status: "unprocessed"`) and unquoted YAML both occur, and grepping
# for one form caused a recorded miss in the system this was ported from.
fm_value() {
  local file="$1" key="$2"
  awk -v key="$key" '
    NR == 1 { if ($0 != "---") exit 0; inblock = 1; next }
    inblock && $0 == "---" { exit 0 }
    inblock {
      if (index($0, key ":") == 1) {
        v = substr($0, length(key) + 2)
        sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
        if (v ~ /^".*"$/) v = substr(v, 2, length(v) - 2)
        else if (v ~ /^'"'"'.*'"'"'$/) v = substr(v, 2, length(v) - 2)
        print v; exit 0
      }
    }
  ' "$file" 2>/dev/null
}

# ── LOAD: count unprocessed captures, find the oldest ────────────────────────
UNPROCESSED=0
OLDEST_DAYS=""
if [ -d "$BRAIN/raw" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ "$(fm_value "$f" status)" = "unprocessed" ] || continue
    UNPROCESSED=$((UNPROCESSED + 1))
    # Age from the capture's own `date:` when it has one; file mtime otherwise.
    # mtime is a proxy and it resets on a fresh checkout — acceptable for an
    # advisory, and stated rather than hidden.
    e="$(_date_epoch "$(fm_value "$f" date)")"
    [ -n "$e" ] || e="$(_file_epoch "$f")"
    d="$(_days_since "$e")"
    [ -n "$d" ] || continue
    if [ -z "$OLDEST_DAYS" ] || [ "$d" -gt "$OLDEST_DAYS" ]; then OLDEST_DAYS="$d"; fi
  done <<EOF
$(find "$BRAIN/raw" -type f -name '*.md' ! -name 'README.md' 2>/dev/null | LC_ALL=C sort)
EOF
fi

# ── LIVENESS: age of the newest DISTILL-LOG.md entry ─────────────────────────
LOG="$BRAIN/DISTILL-LOG.md"
LOG_DAYS=""
LOG_DATE=""
if [ -f "$LOG" ]; then
  LOG_DATE="$(grep -Eo '^##[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2}' "$LOG" 2>/dev/null \
              | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}' | LC_ALL=C sort -r | head -1)"
  [ -n "$LOG_DATE" ] && LOG_DAYS="$(_days_since "$(_date_epoch "$LOG_DATE")")"
fi

# ── MIGRATION: a legacy memory store nothing points at any more ──────────────
# The memory backend default is `repo` (<repo>/.brain/memory). It used to be
# `project` ($HOME/.claude/projects/<slug>/memory). A project that upgrades
# across that flip without answering the question would leave its old lessons
# in a directory the resolver no longer returns — stranded, and silently.
#
# THIS IS DETECTION, NOT RESOLUTION, AND THE DISTINCTION IS THE WHOLE POINT.
# Making the RESOLVER probe for this was designed and then rejected: the slug is
# derived from the checkout path, so a probe resolves differently in a worktree
# than in the main checkout of the same project — two stores, neither aware of
# the other, which is the exact defect the resolver exists to kill. It also
# turns a reviewable one-line config diff into a filesystem side effect with no
# diff anywhere. So the resolver stays a pure function of (env, conf), and the
# stranding is surfaced HERE, to a human, by something that never blocks and
# never moves anyone's files.
#
# It self-clears two ways, both of them the user answering the question:
# emptying/moving the legacy directory, or setting `memory_backend = project`.
MIGRATION=0
LEGACY_DIR=""
LEGACY_COUNT=0
_resolver="$REPO_ROOT/.logic-loom/scripts/bash/resolve-memory-backend.sh"
if [ -x "$_resolver" ] || [ -r "$_resolver" ]; then
  _backend="$(bash "$_resolver" --backend 2>/dev/null)"
  if [ "$_backend" = "repo" ]; then
    _slug="$(printf '%s' "$REPO_ROOT" | sed 's|/|-|g')"
    LEGACY_DIR="$HOME/.claude/projects/$_slug/memory"
    if [ -d "$LEGACY_DIR" ]; then
      # Regular files only. An empty directory is not memory, and Claude Code
      # creates that tree for reasons unrelated to /retro.
      LEGACY_COUNT="$(find "$LEGACY_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')"
      LEGACY_COUNT="$(_num_or "$LEGACY_COUNT" 0)"
      [ "$LEGACY_COUNT" -gt 0 ] && MIGRATION=1
    fi
  fi
fi

# ── Structural silence: unadopted routine makes no noise ─────────────────────
if [ "$UNPROCESSED" -eq 0 ] && [ ! -f "$LOG" ] && [ "$MIGRATION" -eq 0 ]; then
  exit 0
fi

# ── Decide ───────────────────────────────────────────────────────────────────
WARN_LOAD=0
if [ "$UNPROCESSED" -gt "$LOAD_MAX" ]; then
  WARN_LOAD=1
elif [ -n "$OLDEST_DAYS" ] && [ "$UNPROCESSED" -gt 0 ] && [ "$OLDEST_DAYS" -gt "$LOAD_AGE" ]; then
  WARN_LOAD=1
fi

# The conjunction is deliberate: an old log over an EMPTY queue is not a fault.
WARN_LIVE=0
if [ "$UNPROCESSED" -gt 0 ]; then
  if [ -z "$LOG_DAYS" ]; then
    WARN_LIVE=1                        # captures exist and the pass has never run
  elif [ "$LOG_DAYS" -gt "$LIVE_AGE" ]; then
    WARN_LIVE=1
  fi
fi

[ "$WARN_LOAD" -eq 0 ] && [ "$WARN_LIVE" -eq 0 ] && [ "$MIGRATION" -eq 0 ] && exit 0

# ── Anti-nag: once per (repo, state) ─────────────────────────────────────────
# Keyed on the STATE, not just the repo, so the notice returns when the numbers
# actually change — and stays quiet while they do not.
if [ "$ONCE" -eq 1 ]; then
  STATE_DIR="${LOOM_BRAIN_STATE_DIR:-${TMPDIR:-/tmp}}"
  STATE_KEY="$(printf '%s|%s|%s|%s|%s|%s|%s' \
      "$REPO_ROOT" "${CLAUDE_SESSION_ID:-nosession}" \
      "$UNPROCESSED" "${OLDEST_DAYS:-}" "${LOG_DATE:-}" "$WARN_LIVE$WARN_LOAD" \
      "$MIGRATION:$LEGACY_COUNT" \
    | (cksum) 2>/dev/null | awk '{print $1}')"
  STATE_FILE="$STATE_DIR/loom-brain-advisory-$STATE_KEY"
  [ -f "$STATE_FILE" ] && exit 0
  : > "$STATE_FILE" 2>/dev/null || true
fi

# ── Emit ─────────────────────────────────────────────────────────────────────
printf '**BRAIN LAYER ADVISORY** (from `.brain/` — advisory only, never a gate):\n'
if [ "$WARN_LOAD" -eq 1 ]; then
  if [ -n "$OLDEST_DAYS" ]; then
    printf -- '- Load: %s unprocessed capture(s) under `.brain/raw/`; oldest is %s day(s) old.\n' \
      "$UNPROCESSED" "$OLDEST_DAYS"
  else
    printf -- '- Load: %s unprocessed capture(s) under `.brain/raw/`.\n' "$UNPROCESSED"
  fi
fi
if [ "$WARN_LIVE" -eq 1 ]; then
  if [ -n "$LOG_DATE" ]; then
    printf -- '- Liveness: the newest `.brain/DISTILL-LOG.md` entry is %s (%s day(s) ago).\n' \
      "$LOG_DATE" "$LOG_DAYS"
  else
    printf -- '- Liveness: captures exist and `.brain/DISTILL-LOG.md` has no dated entry — the pass has not run here.\n'
  fi
fi
if [ "$MIGRATION" -eq 1 ]; then
  printf -- '- Migration: durable memory now resolves to `.brain/memory/`, but %s file(s) still sit in the previous location `%s`.\n' \
    "$LEGACY_COUNT" "$LEGACY_DIR"
  printf -- '  Nothing reads them there any more. Move them into `.brain/memory/`, or set `memory_backend = project` in `.logic-loom/config/memory-backend.conf` to keep writing where they are. Either answer silences this line. The harness will not move them for you.\n'
fi
if [ "$WARN_LOAD" -eq 1 ] || [ "$WARN_LIVE" -eq 1 ]; then
  printf -- '- Run `/distill` when convenient. It runs no `git` and leaves its changes in the working tree.\n'
fi
printf -- '- Mention this once, briefly. Do not block the user'"'"'s task on it.\n'

exit 0
