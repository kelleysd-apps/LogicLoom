#!/usr/bin/env bash
# Git Safety Gate — Principle VI enforcement via PreToolUse hook (Bash matcher)
#
# Forces explicit user approval for git operations that mutate repository state.
# Read-only git commands (status, log, diff, show, branch listing) pass through.
#
# Enforcement is hook-side and model-independent: a mutating git command emits a
# PreToolUse decision of "ask", which makes Claude Code surface the approval
# prompt regardless of any allowlist. This is the teeth behind "NO autonomous
# git operations" — it does not rely on the model reading CLAUDE.md.
#
# Known limitation: this is a STRING gate. It catches `git` behind a path
# prefix (/usr/bin/git, ./git) and global flags before the subcommand
# (git -C /r push, git -c k=v commit). It does NOT see git run through
# interpreter / script / eval indirection (python -c, bash script.sh, eval,
# variable indirection like `G=git; $G push`) — inherent to any string gate.
#
# Input:  Claude Code PreToolUse JSON via stdin, e.g.
#   {"tool_name":"Bash","tool_input":{"command":"git push origin main"}}
# Output: JSON decision (current hookSpecificOutput schema):
#   ask  -> {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#            "permissionDecision":"ask","permissionDecisionReason":"..."}}
#   allow-> {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#            "permissionDecision":"allow"}}
set -euo pipefail

INPUT=$(cat)

extract_command() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '.tool_input.command // .command // empty' 2>/dev/null && return
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c \
      "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command', d.get('command','')))" \
      2>/dev/null && return
  fi
  printf '%s' "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"command"[^"]*"//; s/"$//'
}

COMMAND="$(extract_command || true)"

emit_allow() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}\n'
  exit 0
}

emit_ask() {
  local reason="$1" esc
  esc=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$esc"
  exit 0
}

[ -z "$COMMAND" ] && emit_allow

# Detection is two-stage and decoupled from subcommand adjacency, so global
# git flags between `git` and the subcommand (e.g. `git -C /r push`,
# `git -c k=v commit`, `git --git-dir=x push`) are still caught.
#
# Stage 1 — is this a git invocation at all? `git` as a command word that may
# carry a path prefix (/usr/bin/git, ./git) and may be inside a compound
# command (cd x && git ...). Substrings like "digit"/"github"/"gitignore" do
# not match (boundary is a non-identifier char + optional path component).
GIT_INVOKE='(^|[^[:alnum:]_])([^[:space:]]*/)?git([[:space:]]|$)'

# Stage 2 — does the command contain a MUTATING git subcommand token anywhere?
# Read-only ops (status, log, diff, show, fetch, plain branch, rev-parse,
# ls-files, config, etc.) are intentionally absent and pass through.
# `branch` is only mutating with a -d/-D/-m/-M flag; `remote` only with a
# write subcommand. Tokens are bounded so e.g. "pushd" / "committed" don't hit.
GIT_MUTATION='(^|[^[:alnum:]-])(push|pull|commit|merge|rebase|reset|checkout|switch|tag|stash|cherry-pick|revert|am|apply|clean|rm|mv)([^[:alnum:]-]|$)'
GIT_BRANCH_DEL='(^|[^[:alnum:]_])git([[:space:]]|$).*branch[[:space:]]+(-[^[:space:]]*[dDmM]|--delete|--move)'
GIT_REMOTE_WRITE='(^|[^[:alnum:]_])git([[:space:]]|$).*remote[[:space:]]+(add|remove|rm|rename|set-url)'

if printf '%s' "$COMMAND" | grep -qE "$GIT_INVOKE"; then
  if printf '%s' "$COMMAND" | grep -qE "$GIT_MUTATION" \
     || printf '%s' "$COMMAND" | grep -qE "$GIT_BRANCH_DEL" \
     || printf '%s' "$COMMAND" | grep -qE "$GIT_REMOTE_WRITE"; then
    emit_ask "Principle VI: git operation requires explicit user approval — '${COMMAND}'"
  fi
fi

emit_allow
