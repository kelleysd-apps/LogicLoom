#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# LogicLoom off-host git-approval adapter (L2 ENFORCEMENT ADAPTER, non-Claude)
# ─────────────────────────────────────────────────────────────────────────────
# Enforces Principle VI (no autonomous git mutation) + the subagent-git-deny
# spirit on ANY host with a POSIX shell — Codex CLI, Cursor, Gemini CLI, Aider,
# a plain terminal, or CI — by calling the SAME verdict functions the Claude
# Code hooks use (.logic-loom/lib/governance-verdicts.sh). This is the reference
# adapter that PROVES the L2 adapter contract is real, not just documented
# (see .docs/architecture/governance-threat-model.md → Provider portability).
#
# On Claude Code, git-safety-gate.sh turns a mutating git into an interactive
# "ask" via PreToolUse. OFF Claude Code there is no PreToolUse approval channel,
# so the analog is: BLOCK an autonomous (non-interactive) mutating git unless a
# human approves — either via a /dev/tty prompt or the LOOM_GIT_APPROVED=1 token.
#
# Why this adapter fails CLOSED (the hooks fail open): on Claude Code the hook is
# one backstop among several (permissions, PR review). Off Claude Code this
# adapter is the ONLY backstop, so it errs safe — if it cannot classify a
# command (verdict lib missing) it refuses a possible mutation rather than
# waving it through.
#
# Usage:
#   . .logic-loom/adapters/git-approval-gate.sh
#   loom_git_approval_gate "<full git command line>"   # 0 = allow, 1 = block
#
# Env:
#   LOOM_GIT_APPROVED=1            explicit human approval (allow this mutation)
#   LOOM_GIT_ASSUME_NONINTERACTIVE=1   skip the TTY prompt (force autonomous path)
#   LOOM_VERDICT_LIB=<path>        override the shared verdict lib location

_lga_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
LOOM_VERDICT_LIB="${LOOM_VERDICT_LIB:-$_lga_dir/../lib/governance-verdicts.sh}"
# shellcheck disable=SC1090
[ -f "$LOOM_VERDICT_LIB" ] && . "$LOOM_VERDICT_LIB"

loom_git_approval_gate() { # full-git-command -> 0 allow / 1 block
  local cmd="$1"

  if ! declare -f loom_verdict_git_mutation >/dev/null 2>&1; then
    # Fail CLOSED: cannot classify. Refuse ANY git invocation (not a leaky
    # mutation-substring subset that both misses `git tag`/`git switch` and
    # false-blocks `ls pushpin.txt`). Only git command lines are gated here.
    if printf '%s' "$cmd" | grep -qE '(^|[^[:alnum:]_])([^[:space:]]*/)?git([[:space:]]|$)'; then
      echo "loom-git-gate: verdict lib unavailable; BLOCKING git (cannot classify): $cmd" >&2
      return 1
    fi
    return 0
  fi

  # Not git, or read-only git -> allow.
  [ "$(loom_verdict_git_mutation "$cmd")" = "ask" ] || return 0

  # Mutating git below this point.
  if [ "${LOOM_GIT_APPROVED:-}" = "1" ]; then
    return 0
  fi

  if [ "${LOOM_GIT_ASSUME_NONINTERACTIVE:-}" != "1" ] && [ -r /dev/tty ] && [ -w /dev/tty ]; then
    printf 'LogicLoom (Principle VI) — approve git mutation? [y/N] %s ' "$cmd" > /dev/tty
    local ans=""
    read -r ans < /dev/tty || ans=""
    case "$ans" in
      [yY]|[yY][eE][sS]) return 0 ;;
      *) echo "loom-git-gate: git mutation declined." >&2; return 1 ;;
    esac
  fi

  echo "loom-git-gate: BLOCKED autonomous git mutation (Principle VI). Approve with LOOM_GIT_APPROVED=1 or run interactively. Command: $cmd" >&2
  return 1
}
