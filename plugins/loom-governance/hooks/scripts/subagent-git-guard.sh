#!/usr/bin/env bash
# Subagent Git Guard — PreToolUse hook (Bash matcher), Principle VI hardening.
#
# Git operations may ONLY be run by the MAIN agent, acting on a direct user
# request. Subagents (spawned via the Task/Agent tool) must NEVER run git — a
# stray `git clean`/`reset` from a subagent is what can silently destroy
# uncommitted work.
#
# Detection (empirically verified): when a tool call originates from a subagent,
# Claude Code includes an `agent_id` (and `agent_type`) field in the PreToolUse
# stdin JSON. The main agent's calls have NO `agent_id`. So:
#   - agent_id present  + git command -> DENY (hard block)
#   - agent_id absent (main agent)    -> ALLOW here; the git-safety-gate hook
#                                        still forces user approval ("ask").
#
# Input:  PreToolUse JSON via stdin, e.g.
#   {"tool_name":"Bash","agent_id":"a8e...","agent_type":"general-purpose",
#    "tool_input":{"command":"git clean -fd"}}
# Output: hookSpecificOutput decision (deny / allow).
set -euo pipefail

INPUT=$(cat)

json_get() { # key
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null && return
  fi
  printf '%s' "$INPUT" | python3 -c \
    "import sys,json
d=json.load(sys.stdin)
keys='${1//[.\"]/ }'.split()
v=d
for k in keys:
    v=v.get(k) if isinstance(v,dict) else None
print(v if v is not None else '')" 2>/dev/null
}

AGENT_ID="$(json_get '.agent_id' || true)"
COMMAND="$(json_get '.tool_input.command' || true)"
[ -z "$COMMAND" ] && COMMAND="$(json_get '.command' || true)"

allow() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}\n'
  exit 0
}
deny() {
  local reason="$1" esc
  esc=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$esc"
  exit 0
}

# Main agent (no agent_id) -> not our concern; let git-safety-gate handle approval.
[ -z "$AGENT_ID" ] && allow
[ -z "$COMMAND" ] && allow

# Subagent context: deny ANY git invocation (mutating or read-only).
# Matched as a command word so non-git Bash and substrings like "digit" pass.
if printf '%s' "$COMMAND" | grep -qE '(^|[;&|(`[:space:]])git([[:space:]]|$)'; then
  AGENT_TYPE="$(json_get '.agent_type' || true)"
  deny "Git is restricted to the main agent (direct user request only). Subagent '${AGENT_TYPE:-unknown}' may not run git — return findings to the main agent, which will run git with user approval. Blocked: '${COMMAND}'"
fi

allow
