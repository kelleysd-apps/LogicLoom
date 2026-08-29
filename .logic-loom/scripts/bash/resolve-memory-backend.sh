#!/usr/bin/env bash
# resolve-memory-backend.sh — resolve WHERE durable cross-session memory is written.
#
# Reads .logic-loom/config/memory-backend.conf (plus env overrides) and prints an
# ABSOLUTE directory path. Writes nothing unless asked (--ensure). Runs NO git.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHY THIS EXISTS
# ─────────────────────────────────────────────────────────────────────────────
# The memory destination used to be hardcoded in prose inside the /retro skill
# ($HOME/.claude/projects/<slug>/memory/) — a fine default and a bad contract,
# because nothing could point it anywhere else without editing the skill.
#
# One resolver, one answer, one place to change it.
#
# ─────────────────────────────────────────────────────────────────────────────
# TWO BACKENDS. THERE IS NO THIRD, AND THE DELETED ONE IS WORTH NAMING.
# ─────────────────────────────────────────────────────────────────────────────
#   repo      <repo>/.brain/memory/ — IN-TREE and versioned. THE DEFAULT.
#   project   $HOME/.claude/projects/<slug>/memory/ — per-machine, outside the
#             repo, invisible to anything that is not Claude Code.
#
# A third backend briefly existed: an absolute path, configured per machine,
# pointing at whatever external knowledge store the operator happened to keep.
# It is DELETED, and not commented out as a future option, because it inverted
# the relationship. The project's brain is SELF-CONTAINED — .brain/ is this
# project's own vault, and an external store reads IT. The project never reaches
# out to somebody else's directory. A config key naming a path that exists on
# exactly one machine is one person's setup shipped as a product feature.
#
# ─────────────────────────────────────────────────────────────────────────────
# CONTRACT
# ─────────────────────────────────────────────────────────────────────────────
#   resolve-memory-backend.sh              -> absolute path, exit 0
#   resolve-memory-backend.sh --path       -> same (explicit)
#   resolve-memory-backend.sh --backend    -> `repo` | `project`
#   resolve-memory-backend.sh --ensure     -> mkdir -p the path, then print it
#   resolve-memory-backend.sh --explain    -> human-readable resolution trace
#
# FAIL-SAFE, NOT FAIL-CLOSED. An unrecognised backend WARNS on stderr and falls
# back to the resolved default, exit 0. Losing a retrospective's lessons to a
# config typo is worse than writing them to the default store and saying so out
# loud. `--ensure` is the ONLY mode that can fail (exit 1), and only when mkdir
# itself fails.
#
# ─────────────────────────────────────────────────────────────────────────────
# THE DEFAULT IS `repo`, AND THIS RESOLVER IS A PURE FUNCTION OF (env, conf)
# ─────────────────────────────────────────────────────────────────────────────
# `repo` is the default because memory is project knowledge: it should travel
# with the code, survive a machine change, be reviewable in a diff, and be
# readable by any tool with filesystem access. `.brain/memory/` is stripped at
# template release, so a cloner never inherits anyone's lessons.
#
# WHAT THIS RESOLVER DELIBERATELY DOES NOT DO, because it was designed, built,
# and then removed on review: it does NOT probe the filesystem for a legacy
# store and quietly hold the default there. A "default that depends on whether a
# directory happens to be non-empty" fails in four ways this repo would actually
# hit, and one of them is fatal:
#
#   - WORKTREES. REPO_ROOT is the worktree's own path, so the `project` slug
#     differs per worktree. A probe would resolve `project` in the main checkout
#     and `repo` in a worktree of the SAME project — two stores, neither aware
#     of the other. That is verbatim the defect this resolver exists to kill,
#     and the swarm pack is worktree-based, so it is the normal path.
#   - A MOVED OR RENAMED REPO changes the slug, so the probe finds nothing and
#     silently resolves `repo` — orphaning the old store at exactly the moment
#     the migration was supposed to catch it, and staying silent because the
#     notice was conditioned on the same probe that just failed.
#   - IT MAKES THE DESTINATION UNAUDITABLE. With an explicit key, moving memory
#     is a one-line diff someone can see in review. With a probe, creating one
#     file under a directory Claude Code already owns redirects every future
#     read and write with no diff anywhere.
#   - CI AND A LAPTOP WOULD DISAGREE BY CONSTRUCTION ($HOME and checkout path
#     both differ), so any test asserting a resolved path has two right answers.
#
# So resolution is pure, and the migration is handled where it belongs: the
# shipped conf states `memory_backend` EXPLICITLY, and a stranded legacy store
# is surfaced by check-brain-signals.sh — an advisory a human reads, that never
# blocks and never moves anyone's files. Detection, not resolution.
#
# PRECEDENCE (highest first)
#   LOOM_MEMORY_BACKEND  >  memory_backend in the conf  >  built-in `repo`
#
# bash 3.2 safe: no associative arrays, no mapfile, no `[[ -v ]]`, no ${v,,}.
# Overridable for testing: LOOM_MEMORY_CONF (config path), LOOM_REPO_ROOT.

set -uo pipefail

# ── Repo root ────────────────────────────────────────────────────────────────
# Resolved from this script's location, NOT from git — a subagent may run this
# and the git guard exists precisely so shell like this does not reach for git.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${LOOM_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
CONF="${LOOM_MEMORY_CONF:-$REPO_ROOT/.logic-loom/config/memory-backend.conf}"

MODE="path"
case "${1:-}" in
  ""|--path)  MODE="path" ;;
  --backend)  MODE="backend" ;;
  --ensure)   MODE="ensure" ;;
  --explain)  MODE="explain" ;;
  -h|--help)
    sed -n '2,85p' "${BASH_SOURCE[0]}"
    exit 0 ;;
  *)
    echo "resolve-memory-backend.sh: unknown option '$1'" >&2
    echo "  usage: resolve-memory-backend.sh [--path|--backend|--ensure|--explain]" >&2
    exit 2 ;;
esac

# ── Config reader ────────────────────────────────────────────────────────────
# Never sources the file. First occurrence of a key wins (same rule as
# governance.conf's `mode`). Strips inline comments and surrounding quotes.
_conf_get() { # key -> value on stdout, empty if absent
  local key="$1" line rest
  [ -f "$CONF" ] || return 0
  [ -r "$CONF" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    # left-trim
    while [ "${line# }" != "$line" ] || [ "${line#	}" != "$line" ]; do
      line="${line# }"; line="${line#	}"
    done
    case "$line" in
      "$key"*) ;;
      *) continue ;;
    esac
    rest="${line#"$key"}"
    while [ "${rest# }" != "$rest" ] || [ "${rest#	}" != "$rest" ]; do
      rest="${rest# }"; rest="${rest#	}"
    done
    case "$rest" in
      =*) ;;
      *) continue ;;                      # `memory_backendX = ...` is not the key
    esac
    rest="${rest#=}"
    rest="${rest%%#*}"                    # strip inline comment
    # trim both ends
    while [ "${rest# }" != "$rest" ] || [ "${rest#	}" != "$rest" ]; do
      rest="${rest# }"; rest="${rest#	}"
    done
    while [ "${rest% }" != "$rest" ] || [ "${rest%	}" != "$rest" ]; do
      rest="${rest% }"; rest="${rest%	}"
    done
    # strip one layer of matching quotes
    case "$rest" in
      \"*\") rest="${rest#\"}"; rest="${rest%\"}" ;;
      \'*\') rest="${rest#\'}"; rest="${rest%\'}" ;;
    esac
    printf '%s' "$rest"
    return 0
  done < "$CONF"
  return 0
}

# ── Paths ────────────────────────────────────────────────────────────────────
# The `project` slug is this repo's absolute path with every `/` replaced by `-`
# — the convention Claude Code itself uses for ~/.claude/projects/<slug>/.
_project_path() {
  local slug
  slug="$(printf '%s' "$REPO_ROOT" | sed 's|/|-|g')"
  printf '%s' "$HOME/.claude/projects/$slug/memory"
}
_repo_path() { printf '%s' "$REPO_ROOT/.brain/memory"; }

# ── Resolve the backend name ─────────────────────────────────────────────────
REQUESTED="${LOOM_MEMORY_BACKEND:-}"
SOURCE="env LOOM_MEMORY_BACKEND"
if [ -z "$REQUESTED" ]; then
  REQUESTED="$(_conf_get memory_backend)"
  SOURCE="$CONF"
fi
if [ -z "$REQUESTED" ]; then
  REQUESTED="repo"
  if [ -f "$CONF" ]; then
    SOURCE="built-in default (key absent or empty in $CONF)"
  else
    SOURCE="built-in default (no config file)"
  fi
fi

BACKEND="$REQUESTED"
FALLBACK_REASON=""
case "$BACKEND" in
  repo|project) ;;
  *)
    FALLBACK_REASON="unrecognised memory_backend '$REQUESTED' (expected repo|project)"
    BACKEND="repo"
    ;;
esac

# ── Resolve the path ─────────────────────────────────────────────────────────
case "$BACKEND" in
  project) MEMORY_PATH="$(_project_path)" ;;
  repo)    MEMORY_PATH="$(_repo_path)" ;;
esac

[ -n "$FALLBACK_REASON" ] && \
  echo "resolve-memory-backend.sh: $FALLBACK_REASON — falling back to '$BACKEND'." >&2

# ── Emit ─────────────────────────────────────────────────────────────────────
case "$MODE" in
  backend)
    printf '%s\n' "$BACKEND"
    ;;
  path)
    printf '%s\n' "$MEMORY_PATH"
    ;;
  ensure)
    if ! mkdir -p "$MEMORY_PATH" 2>/dev/null; then
      echo "resolve-memory-backend.sh: could not create '$MEMORY_PATH'" >&2
      exit 1
    fi
    printf '%s\n' "$MEMORY_PATH"
    ;;
  explain)
    echo "memory backend resolution"
    echo "  repo root      : $REPO_ROOT"
    if [ -f "$CONF" ]; then
      echo "  config file    : $CONF"
    else
      echo "  config file    : $CONF (absent)"
    fi
    echo "  requested      : ${REQUESTED:-<none>}   (from: $SOURCE)"
    if [ -n "$FALLBACK_REASON" ]; then
      echo "  fallback       : $FALLBACK_REASON"
    fi
    echo "  resolved       : $BACKEND"
    echo "  memory path    : $MEMORY_PATH"
    if [ -d "$MEMORY_PATH" ]; then
      echo "  exists         : yes"
    else
      echo "  exists         : no (created on demand with --ensure)"
    fi
    case "$BACKEND" in
      project) echo "  note           : per-machine, outside the repo, never committed." ;;
      repo)    echo "  note           : IN-TREE and versioned; stripped at template release." ;;
    esac
    ;;
esac

exit 0
