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

# Decision via the shared verdict lib (the L2 "verdict function" seam — see
# .docs/architecture/governance-threat-model.md). This hook is the Claude Code
# reference ADAPTER for the git-mutation gate; off-host adapters (a git
# pre-push hook, a CI gate) call the SAME loom_verdict_git_mutation function.
# The two-stage detection (git invocation incl. /usr/bin/git, ./git, global
# flags like `git -C /r push`; then a MUTATING subcommand token, branch -d/-m,
# remote write — read-only ops pass through) lives in loom_git_is_mutation.
# Fail OPEN on an infra gap (missing lib), matching guard-dangerous-commands.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERDICT_LIB="$(cd "$SCRIPT_DIR/../../../.." && pwd)/.logic-loom/lib/governance-verdicts.sh"
# shellcheck disable=SC1090
{ [ -f "$VERDICT_LIB" ] && source "$VERDICT_LIB"; } 2>/dev/null || true

if declare -f loom_verdict_git_mutation >/dev/null 2>&1; then
  if [ "$(loom_verdict_git_mutation "$COMMAND")" = "ask" ]; then
    emit_ask "Principle VI: git operation requires explicit user approval — '${COMMAND}'"
  fi
  emit_allow
fi

# Fail-SAFE fallback (verdict lib unavailable): inline-detect a mutating git and
# still force approval rather than failing open. The lib is normally present and
# self-protected; this last-resort copy keeps Principle VI from silently lapsing.
_GIT_INVOKE='(^|[^[:alnum:]_])([^[:space:]]*/)?git([[:space:]]|$)'
_GIT_MUT='(^|[^[:alnum:]-])(push|pull|commit|merge|rebase|reset|checkout|switch|tag|stash|cherry-pick|revert|am|apply|clean|rm|mv|restore|update-ref|symbolic-ref|filter-branch|fast-import)([^[:alnum:]-]|$)'
if printf '%s' "$COMMAND" | grep -qE "$_GIT_INVOKE" && printf '%s' "$COMMAND" | grep -qE "$_GIT_MUT"; then
  emit_ask "Principle VI: git operation requires explicit user approval (verdict lib unavailable — failing safe) — '${COMMAND}'"
fi
emit_allow
