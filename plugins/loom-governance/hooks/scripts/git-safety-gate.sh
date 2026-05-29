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

# Mutating git subcommands that require explicit user approval (Principle VI).
# Matched anywhere in the command so compound forms (e.g. `cd x && git push`)
# are caught. Read-only ops (status, log, diff, show, fetch, plain branch,
# rev-parse, ls-files) are intentionally NOT listed and pass through.
GIT_MUTATION='(^|[;&|[:space:]])git[[:space:]]+(push|pull|commit|merge|rebase|reset|checkout|switch|tag|stash|cherry-pick|revert|am|apply|clean|rm|mv|branch[[:space:]]+-[dDmM]|push[[:space:]]|remote[[:space:]]+(add|remove|set-url))'

if printf '%s' "$COMMAND" | grep -qE "$GIT_MUTATION"; then
  emit_ask "Principle VI: git operation requires explicit user approval — '${COMMAND}'"
fi

emit_allow
