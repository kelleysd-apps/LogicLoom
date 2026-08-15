#!/usr/bin/env bash
# governance-verdicts.sh — shared allow|ask|deny decision logic for the LogicLoom
# enforcement guarantees (Principle VI git-gate + subagent-git-deny, the matching
# gh-gate + subagent-gh-deny, governance-file protection, plan-as-DAG
# freeze-write-scope).
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
# `git worktree <verb>` verbs that WRITE. `list` (and bare `git worktree`, which is
# a usage error) stay reads. `add`/`remove` create and destroy checkouts — an agent
# that can add a worktree can stage work outside the approved tree, and `remove`
# can discard uncommitted work, so both are mutations.
LOOM_GIT_WORKTREE_WRITE_VERBS='add remove prune move repair lock unlock'
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

# If this segment's command word is <name>, echo the remainder starting at that
# word (i.e. "<name> <args...>"); otherwise return 1. ONE tokenizer, shared by the
# git and gh gates — do not add a second one.
_loom_cmd_after_prefix() { # segment name -> 0 + echoes "<name> ..."
  local s tok expect_arg=0 name="$2"
  s="$1"
  while :; do
    s="$(_loom_ltrim "$s")"
    [ -n "$s" ] || return 1
    tok="${s%%[[:space:]]*}"
    if [ "$expect_arg" = 1 ]; then
      expect_arg=0; s="${s#"$tok"}"; continue
    fi
    case "$tok" in
      "$name"|*/"$name") printf '%s' "$s"; return 0 ;;
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

# If this segment's command word is git, echo the remainder starting at that
# word (i.e. "git <args...>"); otherwise return 1.
_loom_git_after_prefix() { # segment -> 0 + echoes "git ..."
  _loom_cmd_after_prefix "$1" git
}

# Same, for the GitHub CLI.
_loom_gh_after_prefix() { # segment -> 0 + echoes "gh ..."
  _loom_cmd_after_prefix "$1" gh
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
    worktree)
      first="$(_loom_first_arg "$s")"
      _loom_in_list "$first" "$LOOM_GIT_WORKTREE_WRITE_VERBS" && return 0
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
# GitHub CLI (`gh`) invocation + consequential-operation detection
# ─────────────────────────────────────────────────────────────────────────────
# Principle VI covers "no autonomous repository mutation", and `gh` mutates the
# repository just as surely as `git` does — it just does it server-side. Before
# this gate, `gh pr create`, `gh pr merge` and `gh workflow run` all returned
# ALLOW for both the main agent and subagents: an agent could open a PR, merge to
# a protected branch, or dispatch the release workflow with zero approval, while
# a plain `git commit` was gated. This closes that inversion.
#
# Same command-position anchoring as git (shared _loom_cmd_after_prefix /
# _loom_split_segments / _loom_in_list — there is exactly ONE tokenizer here), so
# `echo "run gh pr merge later"`, `--body "gh pr merge"` and `github`/`ghost` do
# not match, while `cd x && gh pr merge`, `sudo gh release delete` do.
#
# Read-only gh (pr list/view/checks/diff/status, run list/view/watch, issue
# list/view, repo view, release list/view, workflow list/view, auth status,
# label list, and `gh api` without a write method) stays ALLOW: gating reads
# would train the user to click through approvals.

# `gh` global flags that consume the following token (so it is not mistaken for
# the noun). gh's genuinely global flags are few; --repo/--hostname are the ones
# that can precede the noun.
LOOM_GH_GLOBAL_ARG_FLAGS='-R --repo --hostname'

# HTTP methods that mutate. `gh api -X PUT repos/o/r/pulls/N/merge` merges a PR
# without ever containing the word "merge" — the laundering vector this catches.
LOOM_GH_WRITE_METHODS='POST PUT PATCH DELETE'

# `gh api <args>` -> 0 if this is a WRITE call.
# Explicit method wins (so `-X GET` is a read even alongside other flags). With no
# method flag, field flags (-f/-F/--field/--raw-field/--input) still imply POST —
# that is gh's own documented default, and is a second laundering vector.
_loom_gh_api_writes() { # args-after-'api' -> 0 if writing
  local s="$1" tok method="" fieldish=0 expect_method=0
  while :; do
    s="$(_loom_ltrim "$s")"
    [ -n "$s" ] || break
    tok="${s%%[[:space:]]*}"
    if [ "$expect_method" = 1 ]; then
      expect_method=0; method="$tok"; s="${s#"$tok"}"; continue
    fi
    case "$tok" in
      -X|--method)                              expect_method=1 ;;
      --method=*)                               method="${tok#--method=}" ;;
      -X*)                                      method="${tok#-X}" ;;
      -f|-F|--field|--raw-field|--input)        fieldish=1 ;;
      --field=*|--raw-field=*|--input=*)        fieldish=1 ;;
      -f*|-F*)                                  fieldish=1 ;;
      *)                                        ;;
    esac
    s="${s#"$tok"}"
  done
  if [ -n "$method" ]; then
    method="$(printf '%s' "$method" | tr '[:lower:]' '[:upper:]')"
    _loom_in_list "$method" "$LOOM_GH_WRITE_METHODS" && return 0
    return 1
  fi
  [ "$fieldish" = 1 ] && return 0
  return 1
}

# One segment -> 0 if it is a CONSEQUENTIAL gh invocation (needs approval).
_loom_seg_gh_mutates() { # segment -> 0 if consequential gh
  local s tok noun="" verb="" expect_arg=0
  s="$(_loom_gh_after_prefix "$1")" || return 1
  tok="${s%%[[:space:]]*}"; s="${s#"$tok"}"       # drop the `gh` word itself
  while :; do                                     # find the NOUN (gh's group)
    s="$(_loom_ltrim "$s")"
    [ -n "$s" ] || break
    tok="${s%%[[:space:]]*}"
    if [ "$expect_arg" = 1 ]; then expect_arg=0; s="${s#"$tok"}"; continue; fi
    case "$tok" in
      -R|--repo|--hostname) expect_arg=1 ;;
      -*) ;;                                      # --help, --version, ...
      *) noun="$tok"; s="${s#"$tok"}"; break ;;
    esac
    s="${s#"$tok"}"
  done
  [ -n "$noun" ] || return 1                      # bare `gh` -> usage, a read
  if [ "$noun" = "api" ]; then
    _loom_gh_api_writes "$s" && return 0
    return 1
  fi
  expect_arg=0
  while :; do                                     # find the VERB
    s="$(_loom_ltrim "$s")"
    [ -n "$s" ] || break
    tok="${s%%[[:space:]]*}"
    if [ "$expect_arg" = 1 ]; then expect_arg=0; s="${s#"$tok"}"; continue; fi
    case "$tok" in
      -R|--repo|--hostname) expect_arg=1 ;;
      -*) ;;
      *) verb="$tok"; break ;;
    esac
    s="${s#"$tok"}"
  done
  case "$noun $verb" in
    'pr create'|'pr merge'|'pr close'|'pr reopen'|'pr review'|'pr edit') return 0 ;;
    'workflow run'|'workflow enable'|'workflow disable')                 return 0 ;;
    'run rerun'|'run cancel')                                            return 0 ;;
    'release create'|'release delete'|'release edit')                    return 0 ;;
    'repo delete'|'repo archive'|'repo edit')                            return 0 ;;
    'issue create'|'issue close'|'issue edit'|'issue delete'|'issue pin') return 0 ;;
    'alias set')                                                         return 0 ;;
    'secret set'|'variable set'|'ssh-key add')                           return 0 ;;
    'auth login'|'auth refresh')                                         return 0 ;;
  esac
  return 1
}

loom_gh_is_invoke() { # command -> 0 if gh is invoked at a command position
  local seg
  while IFS= read -r seg; do
    if _loom_gh_after_prefix "$seg" >/dev/null; then return 0; fi
  done <<< "$(_loom_split_segments "$1")"
  return 1
}

loom_gh_is_mutation() { # command -> 0 if a CONSEQUENTIAL gh command
  local seg
  while IFS= read -r seg; do
    if _loom_seg_gh_mutates "$seg"; then return 0; fi
  done <<< "$(_loom_split_segments "$1")"
  return 1
}

# Main-agent CONSEQUENTIAL gh requires explicit approval.
loom_verdict_gh_mutation() { # command -> allow|ask
  if loom_gh_is_mutation "$1"; then echo ask; return 0; fi
  echo allow; return 0
}

# Subagent (non-empty agent_id) may NOT run ANY gh — read-only included.
# Deliberately categorical, mirroring subagent-git-deny: a subagent has no
# business creating PRs, merging, or dispatching workflows, and a read/write
# split would be one classification bug away from a silent merge. Findings go
# back to the main agent, which runs gh under the approval gate.
loom_verdict_subagent_gh() { # command agent_id -> allow|deny
  local cmd="$1" agent_id="$2"
  if [ -n "$agent_id" ] && loom_gh_is_invoke "$cmd"; then
    echo deny; return 0
  fi
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
