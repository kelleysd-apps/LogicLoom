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
# The path-sets/glob logic below mirrors the reference hooks (git-safety-gate.sh,
# subagent-git-guard.sh, protect-governance-files.sh, freeze-write-scope.sh);
# those hooks keep only a last-resort inline fallback for when this lib is
# missing. Changing a guarantee means changing it HERE; the conformance test
# pins the behavior.

# ─────────────────────────────────────────────────────────────────────────────
# Git invocation + mutation detection
# ─────────────────────────────────────────────────────────────────────────────
# Detection is COMMAND-POSITION anchored, not substring / token-anywhere.
#
# INVOCATION: a command counts as git only when `git` (optionally path-prefixed:
# /usr/bin/git, ./git) is the command WORD of a shell segment — it starts the
# line or follows one of  ;  &&  ||  |  (  )  {  }  `  — possibly behind
# VAR=value assignments or a sudo/env-style prefix. So `git status`,
# `cd /x && git commit`, `sudo git clean`, `env FOO=1 git push` DO match, while
# `grep --exclude-dir=.git`, `sed -i.bak s/x/y/ f`, `ls foo/.git/config`,
# `echo "check git status later"`, `digit`, `legit`, `gitlab` do NOT — all of
# which the previous "git as any word" regex false-DENIED for subagents.
#
# MUTATION: subcommand-anchored. Git global flags (-C <path>, -c <k=v>,
# --git-dir=..., --work-tree=..., --no-pager, ...) are skipped and the first
# non-flag argument — the SUBCOMMAND — is matched against the mutating set, so
# `git log --grep=push`, `git stash list`, `git tag -l`, `git branch -a` are
# reads. The previous matcher scanned the whole line for a mutation token and
# false-`ask`ed on all of them (the follow-up flagged in the old comment here).
#
# Known limitation (unchanged): a string gate cannot see interpreter/eval
# indirection (`bash script.sh`, `eval "$c"`, `G=git; $G push`).

# Always-mutating git subcommands. Read-only ops (status/log/diff/show/fetch/
# rev-parse/ls-files/...) are absent. restore (discards working tree),
# update-ref/symbolic-ref (write refs) and filter-branch/fast-import (rewrite
# history) are here per the Phase-1-3 gate review.
LOOM_GIT_MUTATION_SUBCOMMANDS='push pull commit merge rebase reset checkout switch cherry-pick revert am apply clean rm mv restore update-ref symbolic-ref filter-branch fast-import'
# `git remote <verb>` verbs that write (bare / -v listing stays a read).
LOOM_GIT_REMOTE_WRITE_VERBS='add remove rm rename set-url'
# `git stash <verb>` verbs that are read-only (anything else, incl. bare, writes).
LOOM_GIT_STASH_READ_VERBS='list show'
# Words that may precede the real command word inside a segment.
LOOM_GIT_CMD_PREFIXES='sudo env command nohup nice time exec builtin stdbuf ionice'

_loom_in_list() { # token space-separated-list -> 0 if token is in list
  case " $2 " in *" $1 "*) return 0 ;; esac
  return 1
}

_loom_ltrim() { # string -> string without leading whitespace
  local s="$1"
  printf '%s' "${s#"${s%%[![:space:]]*}"}"
}

_loom_first_arg() { # string -> first whitespace-delimited token (may be empty)
  local s
  s="$(_loom_ltrim "$1")"
  printf '%s' "${s%%[[:space:]]*}"
}

# Split a command line at shell command separators so that every resulting line
# begins at a command position. bash 3.2 safe (tr; no arrays, no mapfile).
_loom_split_segments() { # command -> one segment per line
  printf '%s' "$1" | tr ';|&(){}`' '\n\n\n\n\n\n\n\n'
}

# If this segment's command word is git, echo the remainder starting at that
# word (i.e. "git <args...>"); otherwise return 1.
_loom_git_after_prefix() { # segment -> 0 + echoes "git ..."
  local s tok expect_arg=0
  s="$1"
  while :; do
    s="$(_loom_ltrim "$s")"
    [ -n "$s" ] || return 1
    tok="${s%%[[:space:]]*}"
    if [ "$expect_arg" = 1 ]; then
      expect_arg=0; s="${s#"$tok"}"; continue
    fi
    case "$tok" in
      git|*/git) printf '%s' "$s"; return 0 ;;
    esac
    case "$tok" in
      *=*)                        ;;              # VAR=value prefix
      -u|-g|--user|--group)       expect_arg=1 ;; # e.g. sudo -u <user> git ...
      -*)                         ;;              # option to a prefix word
      *) _loom_in_list "${tok##*/}" "$LOOM_GIT_CMD_PREFIXES" || return 1 ;;
    esac
    s="${s#"$tok"}"
  done
}

# `git branch <args>` — mutating when it creates/renames/copies/deletes a branch
# or sets upstream. Plain listing (bare, -a, -r, -v, --list, --contains X, ...)
# is a read. Preserves the old -d/-D/-m/--delete/--move special case.
_loom_git_branch_mutates() { # args-after-'branch' -> 0 if mutating
  local s="$1" tok expect_arg=0
  while :; do
    s="$(_loom_ltrim "$s")"
    [ -n "$s" ] || break
    tok="${s%%[[:space:]]*}"
    if [ "$expect_arg" = 1 ]; then expect_arg=0; s="${s#"$tok"}"; continue; fi
    case "$tok" in
      -d|-D|-m|-M|-c|-C|-f|-u \
      |--delete|--move|--copy|--force|--edit-description \
      |--set-upstream|--set-upstream-to|--set-upstream-to=*|--unset-upstream) return 0 ;;
      --contains|--no-contains|--merged|--no-merged|--points-at|--sort|--format) expect_arg=1 ;;
      -*) ;;                                      # listing / formatting flags
      *) return 0 ;;                              # a branch NAME -> create/rename
    esac
    s="${s#"$tok"}"
  done
  return 1
}

# `git tag <args>` — mutating when it creates/deletes/signs a tag. Pure listing
# (bare, -l/--list, -n5, --contains X, ...) is a read.
_loom_git_tag_mutates() { # args-after-'tag' -> 0 if mutating
  local s="$1" tok expect_arg=0 saw_list=0 saw_name=0
  while :; do
    s="$(_loom_ltrim "$s")"
    [ -n "$s" ] || break
    tok="${s%%[[:space:]]*}"
    if [ "$expect_arg" = 1 ]; then expect_arg=0; s="${s#"$tok"}"; continue; fi
    case "$tok" in
      -d|-D|-a|-s|-u|-f|-m|-F \
      |--delete|--annotate|--sign|--local-user|--force|--message|--file|--edit|--create-reflog) return 0 ;;
      -l|--list) saw_list=1 ;;
      --contains|--no-contains|--merged|--no-merged|--points-at|--sort|--format) expect_arg=1; saw_list=1 ;;
      -*) ;;                                      # -n5, --column, --color, ...
      *) saw_name=1 ;;
    esac
    s="${s#"$tok"}"
  done
  [ "$saw_name" = 1 ] && [ "$saw_list" = 0 ] && return 0
  return 1
}

# One segment -> 0 if it is a MUTATING git invocation.
_loom_seg_git_mutates() { # segment -> 0 if mutating git
  local s tok sub="" expect_arg=0 first
  s="$(_loom_git_after_prefix "$1")" || return 1
  tok="${s%%[[:space:]]*}"; s="${s#"$tok"}"       # drop the `git` word itself
  while :; do                                     # skip git GLOBAL flags
    s="$(_loom_ltrim "$s")"
    [ -n "$s" ] || break
    tok="${s%%[[:space:]]*}"
    if [ "$expect_arg" = 1 ]; then expect_arg=0; s="${s#"$tok"}"; continue; fi
    case "$tok" in
      -C|-c|--git-dir|--work-tree|--namespace|--exec-path|--super-prefix|--config-env|--attr-source) expect_arg=1 ;;
      -*) ;;                                      # --no-pager, --git-dir=x, ...
      *) sub="$tok"; s="${s#"$tok"}"; break ;;    # <- the SUBCOMMAND
    esac
    s="${s#"$tok"}"
  done
  [ -n "$sub" ] || return 1                       # bare `git` / global flags only
  if _loom_in_list "$sub" "$LOOM_GIT_MUTATION_SUBCOMMANDS"; then return 0; fi
  case "$sub" in
    stash)
      first="$(_loom_first_arg "$s")"
      _loom_in_list "$first" "$LOOM_GIT_STASH_READ_VERBS" && return 1
      return 0 ;;
    remote)
      first="$(_loom_first_arg "$s")"
      _loom_in_list "$first" "$LOOM_GIT_REMOTE_WRITE_VERBS" && return 0
      return 1 ;;
    branch) _loom_git_branch_mutates "$s" && return 0; return 1 ;;
    tag)    _loom_git_tag_mutates "$s"    && return 0; return 1 ;;
  esac
  return 1
}

loom_git_is_invoke() { # command -> 0 if git is invoked at a command position
  local seg
  while IFS= read -r seg; do
    if _loom_git_after_prefix "$seg" >/dev/null; then return 0; fi
  done <<< "$(_loom_split_segments "$1")"
  return 1
}

loom_git_is_mutation() { # command -> 0 if a MUTATING git command
  local seg
  while IFS= read -r seg; do
    if _loom_seg_git_mutates "$seg"; then return 0; fi
  done <<< "$(_loom_split_segments "$1")"
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
