#!/usr/bin/env bash
# governance-verdicts.sh — shared allow|ask|deny decision logic for the four
# LogicLoom enforcement guarantees (Principle VI git-gate + subagent-git-deny,
# governance-file protection, plan-as-DAG freeze-write-scope).
#
# This is the L2 "verdict function" seam (see
# .docs/architecture/governance-threat-model.md → Provider portability). The
# Claude Code PreToolUse hooks are the REFERENCE adapter: they parse the hook
# JSON, call the verdict function below, and emit a permissionDecision. Off-host
# adapters (a git pre-push hook, a PATH git-wrapper, a CI gate, another host's
# pre-tool-use mechanism) call the SAME functions, so any host's enforcement can
# be conformance-tested against ONE source of truth
# (tests/contract/test_governance_verdicts.sh — the golden fixtures).
#
# Contract:
#   - loom_verdict_* functions echo exactly one of: allow | ask | deny
#   - loom_*_is_* / loom_*_match predicates return status 0 (true) / 1 (false)
#   - No stdin/stdout I/O beyond the echoed verdict; no exit; safe to source
#     under `set -euo pipefail` (predicates are used only inside conditionals).
#
# The regexes/path-sets/glob logic below are copied VERBATIM from the reference
# hooks (git-safety-gate.sh, subagent-git-guard.sh, protect-governance-files.sh,
# freeze-write-scope.sh). Changing a guarantee means changing it HERE; the
# conformance test pins the behavior.

# ─────────────────────────────────────────────────────────────────────────────
# Git invocation + mutation detection (verbatim from git-safety-gate.sh)
# ─────────────────────────────────────────────────────────────────────────────
# `git` as a command word that may carry a path prefix (/usr/bin/git, ./git) and
# may sit inside a compound command (cd x && git ...). Substrings like
# "digit"/"github"/"gitignore" do NOT match.
LOOM_GIT_INVOKE='(^|[^[:alnum:]_])([^[:space:]]*/)?git([[:space:]]|$)'
# A MUTATING git subcommand token anywhere in the command. Read-only ops
# (status/log/diff/show/fetch/plain branch/rev-parse/ls-files) are absent.
# NOTE (known, accepted): matching is "anywhere in line", so a read-only command
# that merely MENTIONS a token (e.g. `git log --grep=push`) is conservatively
# gated to "ask" — this errs toward asking (Principle VI), the SAFE direction.
# Tokens added per the Phase-1-3 gate review to close dangerous false-ALLOWS:
# restore (discards working tree), update-ref/symbolic-ref (write refs),
# filter-branch/fast-import (rewrite history). A subcommand-anchored matcher that
# also covers worktree add / submodule / reflog expire / gc --prune without
# over-asking on their read forms is a tracked follow-up.
LOOM_GIT_MUTATION='(^|[^[:alnum:]-])(push|pull|commit|merge|rebase|reset|checkout|switch|tag|stash|cherry-pick|revert|am|apply|clean|rm|mv|restore|update-ref|symbolic-ref|filter-branch|fast-import)([^[:alnum:]-]|$)'
LOOM_GIT_BRANCH_DEL='(^|[^[:alnum:]_])git([[:space:]]|$).*branch[[:space:]]+(-[^[:space:]]*[dDmM]|--delete|--move)'
LOOM_GIT_REMOTE_WRITE='(^|[^[:alnum:]_])git([[:space:]]|$).*remote[[:space:]]+(add|remove|rm|rename|set-url)'

loom_git_is_invoke() { # command -> 0 if a git invocation
  printf '%s' "$1" | grep -qE "$LOOM_GIT_INVOKE"
}

loom_git_is_mutation() { # command -> 0 if a MUTATING git command
  loom_git_is_invoke "$1" || return 1
  if printf '%s' "$1" | grep -qE "$LOOM_GIT_MUTATION"; then return 0; fi
  if printf '%s' "$1" | grep -qE "$LOOM_GIT_BRANCH_DEL"; then return 0; fi
  if printf '%s' "$1" | grep -qE "$LOOM_GIT_REMOTE_WRITE"; then return 0; fi
  return 1
}

# Subagent (non-empty agent_id) may NOT run ANY git (mutating or read-only).
loom_verdict_subagent_git() { # command agent_id -> allow|deny
  local cmd="$1" agent_id="$2"
  if [ -n "$agent_id" ] && loom_git_is_invoke "$cmd"; then
    echo deny; return 0
  fi
  echo allow; return 0
}

# Main-agent MUTATING git requires explicit approval.
loom_verdict_git_mutation() { # command -> allow|ask
  if loom_git_is_mutation "$1"; then echo ask; return 0; fi
  echo allow; return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Governance-file protection (verbatim from protect-governance-files.sh)
# ─────────────────────────────────────────────────────────────────────────────
loom_path_is_protected() { # repo-relative path -> 0 if protected
  case "$1" in
    .claude/hooks/*|.claude/hooks \
    |.claude/settings.json|.claude/settings.local.json \
    |.logic-loom/config/governance.conf \
    |.logic-loom/memory/constitution.md \
    |.logic-loom/lib/governance-verdicts.sh|.logic-loom/lib/policy.sh \
    |plugins/loom-governance/hooks/*|plugins/loom-governance/hooks \
    |plugins/loom-governance/.claude-plugin/plugin.json) return 0 ;;
  esac
  return 1
}

# Editing a protected path -> subagent deny / main ask / else allow.
loom_verdict_protected_path() { # rel_path agent_id -> allow|ask|deny
  local rel="$1" agent_id="$2"
  if loom_path_is_protected "$rel"; then
    if [ -n "$agent_id" ]; then echo deny; else echo ask; fi
    return 0
  fi
  echo allow; return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Freeze write-scope (verbatim glob logic from freeze-write-scope.sh)
# ─────────────────────────────────────────────────────────────────────────────
# Match a repo-relative target against a newline-separated glob list; each entry
# matches itself or anything beneath it. Inputs are assumed already canonicalized
# / repo-root-relative (the hook does realpath canonicalization upstream).
loom_freeze_match() { # rel_target list -> 0 if target matches any entry
  local rel_target="$1" list="$2" entry
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    entry="${entry#./}"; entry="${entry%/}"
    [ -z "$entry" ] && continue
    case "$rel_target" in
      $entry|$entry/*) return 0 ;;
    esac
  done <<< "$list"
  return 1
}

# freeze-list hit -> deny; no owns -> allow; owns hit -> allow; otherwise deny.
loom_verdict_freeze_scope() { # rel_target owns_list freeze_list -> allow|deny
  local rel_target="$1" owns_list="$2" freeze_list="$3"
  if [ -n "$freeze_list" ] && loom_freeze_match "$rel_target" "$freeze_list"; then
    echo deny; return 0
  fi
  if [ -z "$owns_list" ]; then echo allow; return 0; fi
  if loom_freeze_match "$rel_target" "$owns_list"; then echo allow; return 0; fi
  echo deny; return 0
}
