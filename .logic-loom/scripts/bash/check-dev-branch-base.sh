#!/usr/bin/env bash
# check-dev-branch-base.sh — LOOM-0024
#
# WHAT IT CATCHES
# ---------------
# LogicLoom's default branch is `main`, and that is CORRECT: `main` is the
# public sanitized template line that GitHub's "Use this template" clones.
# `origin/HEAD` is not stale; the default genuinely IS the production line, so
# the standard fix (`git remote set-head origin --auto`, make integration the
# default) is inapplicable here — see
# `.docs/policies/environment-promotion-policy.md` § 2.2.
#
# The consequence, observed in this repository: tooling that creates a worktree
# "off the default branch" — `EnterWorktree` does exactly this — bases dev work
# on the sanitized release snapshot instead of on `dev-main`. Nothing errors.
# Files that exist in dev and are STRIPPED at promote read as "missing"; stubbed
# files read as "incomplete". A review agent then produces findings that are
# artifacts of the wrong tree.
#
# This guard makes that loud. It DETECTS ONLY — it never runs git, never writes
# into the repository or into .git, and never changes a branch. It prints what
# happened, why it is wrong for dev work, and the exact command to fix it.
#
# WHY IT CANNOT FIRE IN A CUSTOMER CLONE
# --------------------------------------
# It is keyed on the TOPOLOGY, never on the branch name. It requires BOTH a
# `main` line and a `dev-main` line to be present (local head or origin ref).
# A customer's "Use this template" copy has `main` and no `dev-main` anywhere,
# so the guard is structurally silent there. LogicLoom's inversion is not a
# universal rule and this file must never treat it as one.
#
# WHY A SHA COMPARISON, NOT A BRANCH-NAME COMPARISON
# --------------------------------------------------
# `EnterWorktree` creates a NEW branch (e.g. `worktree-foo`) whose starting
# point is `origin/<default>`. Its branch name says nothing. What gives it away
# is that HEAD sits exactly on a `main`-line tip and on no `dev-main` tip. That
# signal is exact at session start — the moment the wrong base was chosen and
# before any analysis has been done on it. Once real commits land on top, the
# tip match is gone and this guard goes quiet; detecting that would require
# ancestry, which would require git. Stated plainly rather than papered over.
#
# NO GIT — DELIBERATELY
# ---------------------
# Branch inventory and the checked-out branch come from
# `detect-environment-topology.sh --format kv` (same directory), which reads
# refs straight off the filesystem for the reasons in its own header: provably
# non-mutating, works under `subagent-git-guard`, testable against a hand-built
# .git. That detector does not report object ids, so the four SHAs this guard
# needs are resolved here with the same technique — loose ref file, then
# `packed-refs`. Anything unreadable is treated as absent and the guard stays
# silent. It never guesses.
#
# SURFACES (registered in .claude/settings.json)
# ----------------------------------------------
# SessionStart      — the session binds to a checkout; warn before any work.
# UserPromptSubmit  — fires ONCE per (repo root, HEAD sha), because entering a
#                     worktree mid-session may not re-run SessionStart. The
#                     once-marker lives in TMPDIR, never in the repo or in .git.
#
# Usage (also the test entry point):
#   check-dev-branch-base.sh [--root DIR] [--event SessionStart|UserPromptSubmit]
#                            [--format json|text] [--no-marker]
# Exit: always 0. This guard advises; it never blocks.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

ROOT=""; EVENT="SessionStart"; FORMAT="json"; USE_MARKER="auto"
while [ $# -gt 0 ]; do
  case "$1" in
    --root)      ROOT="${2:-}"; shift 2 || true ;;
    --root=*)    ROOT="${1#--root=}"; shift ;;
    --event)     EVENT="${2:-}"; shift 2 || true ;;
    --event=*)   EVENT="${1#--event=}"; shift ;;
    --format)    FORMAT="${2:-}"; shift 2 || true ;;
    --format=*)  FORMAT="${1#--format=}"; shift ;;
    --no-marker) USE_MARKER="no"; shift ;;
    -h|--help)   sed -n '2,64p' "$0"; exit 0 ;;
    *) shift ;;   # tolerate unknown args: a hook must never fail on its caller
  esac
done

case "$EVENT" in SessionStart|UserPromptSubmit) ;; *) EVENT="SessionStart" ;; esac
case "$FORMAT" in json|text) ;; *) FORMAT="json" ;; esac

# Drain stdin so the harness never blocks on us.
if [ ! -t 0 ]; then cat >/dev/null 2>&1 || true; fi

_sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || _sd="."
[ -n "$ROOT" ] || ROOT="$(cd "$_sd/../../.." 2>/dev/null && pwd)" || ROOT=""

# ── silent exit (the overwhelmingly common path) ─────────────────────────────
emit_silent() {
  if [ "$FORMAT" = "text" ]; then
    exit 0
  fi
  if [ "$EVENT" = "UserPromptSubmit" ]; then
    printf '{"blocked":false,"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":""}}\n'
  else
    printf '{"hookEventName":"SessionStart"}\n'
  fi
  exit 0
}

[ -n "$ROOT" ] && [ -d "$ROOT" ] || emit_silent

# ── locate the git directory (same technique as the detector) ────────────────
# `.git` is a directory normally; in a linked worktree it is a FILE holding
# `gitdir: <path>`, whose private dir has an almost-empty refs/ — the shared
# refs live at its `commondir`. HEAD is private; branch refs are shared.
GITDIR=""; COMMONDIR=""
if [ -d "$ROOT/.git" ]; then
  GITDIR="$ROOT/.git"; COMMONDIR="$GITDIR"
elif [ -f "$ROOT/.git" ]; then
  _p="$(sed -n 's/^gitdir:[[:space:]]*//p' "$ROOT/.git" 2>/dev/null | head -1)"
  if [ -n "$_p" ]; then
    case "$_p" in /*) : ;; *) _p="$ROOT/$_p" ;; esac
    if [ -d "$_p" ]; then
      GITDIR="$_p"
      _c="$(sed -n '1p' "$_p/commondir" 2>/dev/null)"
      if [ -n "$_c" ]; then
        case "$_c" in /*) COMMONDIR="$_c" ;; *) COMMONDIR="$_p/$_c" ;; esac
      else
        COMMONDIR="$GITDIR"
      fi
    fi
  fi
fi
[ -n "$GITDIR" ] || emit_silent
[ -n "$COMMONDIR" ] && [ -d "$COMMONDIR" ] || COMMONDIR="$GITDIR"

# ── ref resolution: loose file first, then packed-refs ───────────────────────
# Returns the object id, or empty if the ref does not exist / is not readable.
# A symbolic loose ref (`ref: refs/...`) is followed once, which is all real
# repositories need.
resolve_ref() { # $1 = e.g. refs/heads/main
  local _r="$1" _v=""
  if [ -f "$COMMONDIR/$_r" ]; then
    _v="$(sed -n '1p' "$COMMONDIR/$_r" 2>/dev/null | tr -d '[:space:]')"
    case "$_v" in
      ref:*) _v="$(resolve_ref "${_v#ref:}")" ;;
    esac
  fi
  if [ -z "$_v" ] && [ -f "$COMMONDIR/packed-refs" ]; then
    _v="$(sed -n "s|^\([0-9a-fA-F][0-9a-fA-F]*\)[[:space:]]\{1,\}${_r}\$|\1|p" \
          "$COMMONDIR/packed-refs" 2>/dev/null | head -1)"
  fi
  case "$_v" in
    [0-9a-fA-F][0-9a-fA-F]*) printf '%s' "$_v" ;;
    *) : ;;
  esac
}

# ── topology gate: does this repo actually have LogicLoom's inversion? ───────
# BOTH lines must be present. Delegated to the detector for the local-branch
# inventory (its parsing of loose refs + packed-refs is already tested), with
# the origin refs resolved here so a clone that has `dev-main` only as a remote
# ref still counts as LogicLoom-shaped.
DETECTOR="$_sd/detect-environment-topology.sh"
KV=""
if [ -f "$DETECTOR" ]; then
  KV="$(bash "$DETECTOR" --root "$ROOT" --format kv 2>/dev/null)" || KV=""
fi
[ -n "$KV" ] || emit_silent

LOCAL_BRANCHES="$(printf '%s\n' "$KV" | sed -n 's/^branches=//p' | head -1)"
CURRENT_BRANCH="$(printf '%s\n' "$KV" | sed -n 's/^current_branch=//p' | head -1)"
[ -n "$CURRENT_BRANCH" ] || CURRENT_BRANCH="unknown"

has_local_branch() { # $1 = branch name
  case " $LOCAL_BRANCHES " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

MAIN_LOCAL="$(resolve_ref refs/heads/main)"
MAIN_ORIGIN="$(resolve_ref refs/remotes/origin/main)"
DEV_LOCAL="$(resolve_ref refs/heads/dev-main)"
DEV_ORIGIN="$(resolve_ref refs/remotes/origin/dev-main)"

HAS_MAIN=false
if has_local_branch main || [ -n "$MAIN_LOCAL" ] || [ -n "$MAIN_ORIGIN" ]; then HAS_MAIN=true; fi
HAS_DEV=false
if has_local_branch dev-main || [ -n "$DEV_LOCAL" ] || [ -n "$DEV_ORIGIN" ]; then HAS_DEV=true; fi

# THE false-positive guard. A customer clone has main and no dev-main → silent.
[ "$HAS_MAIN" = true ] && [ "$HAS_DEV" = true ] || emit_silent

# ── where is HEAD actually sitting? ──────────────────────────────────────────
HEAD_SHA=""
if [ -f "$GITDIR/HEAD" ]; then
  _h="$(sed -n '1p' "$GITDIR/HEAD" 2>/dev/null | tr -d '[:space:]')"
  case "$_h" in
    ref:*)                   HEAD_SHA="$(resolve_ref "${_h#ref:}")" ;;
    [0-9a-fA-F][0-9a-fA-F]*) HEAD_SHA="$_h" ;;                       # detached
  esac
fi
[ -n "$HEAD_SHA" ] || emit_silent

sha_is() { # $1 = candidate tip (may be empty)
  [ -n "$1" ] && [ "$1" = "$HEAD_SHA" ]
}

ON_MAIN_TIP=false
if sha_is "$MAIN_LOCAL" || sha_is "$MAIN_ORIGIN"; then ON_MAIN_TIP=true; fi
ON_DEV_TIP=false
if sha_is "$DEV_LOCAL" || sha_is "$DEV_ORIGIN"; then ON_DEV_TIP=true; fi

# On a dev-main tip — including the case where the two lines happen to coincide
# — there is nothing wrong. Anywhere off both tips we cannot tell without
# ancestry, and we do not guess.
[ "$ON_MAIN_TIP" = true ] || emit_silent
[ "$ON_DEV_TIP" = false ] || emit_silent

# ── FIRE ─────────────────────────────────────────────────────────────────────
WHICH_TIP="main"
if sha_is "$MAIN_ORIGIN"; then WHICH_TIP="origin/main"; fi
if sha_is "$MAIN_LOCAL";  then WHICH_TIP="main"; fi

if [ "$CURRENT_BRANCH" = "main" ]; then
  REMEDY="  git switch dev-main          # this checkout belongs on the integration line"
elif [ "$CURRENT_BRANCH" = "detached" ] || [ "$CURRENT_BRANCH" = "unknown" ]; then
  REMEDY="  git switch dev-main          # HEAD is detached on the template tip"
else
  REMEDY="  # Branch '${CURRENT_BRANCH}' was started from ${WHICH_TIP} and has no commits
  # of its own yet, so re-base it onto the integration line:
  git fetch origin dev-main && git reset --hard origin/dev-main
  # (If it DOES have work worth keeping, rebase instead:
  #    git rebase --onto origin/dev-main ${WHICH_TIP} ${CURRENT_BRANCH})"
fi

# ── once-per-(root, HEAD) marker for the UserPromptSubmit surface ────────────
# SessionStart always speaks. UserPromptSubmit would otherwise repeat on every
# prompt — including during /promote, which legitimately works on `main`. The
# marker lives in TMPDIR: it is not a git operation and touches neither the
# repository nor .git.
if [ "$EVENT" = "UserPromptSubmit" ] && [ "$USE_MARKER" != "no" ]; then
  _key="$(printf '%s|%s' "$ROOT" "$HEAD_SHA" | tr -c '[:alnum:]' '-' | cut -c1-120)"
  _dir="${TMPDIR:-/tmp}/loom-branch-base-guard"
  _marker="$_dir/$_key"
  if [ -f "$_marker" ]; then
    emit_silent
  fi
  mkdir -p "$_dir" 2>/dev/null || true
  : > "$_marker" 2>/dev/null || true
fi

# The dev-main/template split RUNBOOK is maintainer-only: template-strip-manifest
# .txt removes .docs/guides/dev-main-template-split.md, so it is absent from any
# sanitized template clone. This guard SHIPS, so it must not hand a reader a path
# that is not there. Cite the runbook only when it exists; the policy reference
# below it ships unconditionally and carries the same decision (§ 2.2).
SPLIT_GUIDE=".docs/guides/dev-main-template-split.md"
EXTRA_REF=""
if [ -f "$ROOT/$SPLIT_GUIDE" ]; then
  EXTRA_REF="
             ${SPLIT_GUIDE} § Worktrees"
fi

MESSAGE=""
IFS='' read -r -d '' MESSAGE <<MSG || true
WRONG BASE — this checkout is sitting on the sanitized TEMPLATE line.

  What happened : HEAD (${HEAD_SHA}) is exactly the tip of ${WHICH_TIP}.
                  Checked-out branch: ${CURRENT_BRANCH}
                  Tooling that creates a branch or worktree "off the default
                  branch" resolved that to 'main'. In THIS repository 'main' is
                  correct as the default — it is the public template line that
                  "Use this template" clones — so nothing errored.

  Why it's wrong: 'main' is a sanitized single-parent snapshot. Harness-dev
                  files are STRIPPED from it at promote time and others ship as
                  stubs. Analysis run here reports stripped files as "missing"
                  and stubs as "incomplete" — findings that are artifacts of the
                  wrong tree, not defects. Dev work belongs on the integration
                  line, 'dev-main', named explicitly.

  Fix (run these yourself — this guard runs no git):
${REMEDY}

  Then re-do any exploration or review already performed in this checkout; its
  conclusions are about the template, not about dev.

  Reference: .docs/policies/environment-promotion-policy.md § 2.2 (LOOM-0024)${EXTRA_REF}
MSG

if [ "$FORMAT" = "text" ]; then
  printf '%s\n' "$MESSAGE"
  exit 0
fi

escaped=${MESSAGE//\\/\\\\}
escaped=${escaped//\"/\\\"}
escaped=${escaped//$'\n'/\\n}

if [ "$EVENT" = "UserPromptSubmit" ]; then
  printf '{"blocked":false,"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$escaped"
else
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$escaped"
fi
exit 0
