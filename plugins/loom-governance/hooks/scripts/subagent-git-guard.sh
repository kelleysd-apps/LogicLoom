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
# Detection scope / known limitation: this is a STRING gate over the literal
# Bash command. It detects `git` as a command word even behind a path prefix
# (e.g. `/usr/bin/git`, `./git`, `cd x && /usr/bin/git push`). It does NOT, and
# cannot, see git invoked through interpreter / script / eval indirection —
# `python -c "...subprocess git..."`, `bash some-script.sh` (git inside the
# script), `eval "$cmd"`, or variable indirection (`G=git; $G push`). Those are
# inherent limitations of any string-level gate and are intentionally out of
# scope here.
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

# Decision via the shared verdict lib (the L2 "verdict function" seam — see
# .docs/architecture/governance-threat-model.md). This hook is the Claude Code
# reference ADAPTER: it parses the payload, calls the verdict function, and maps
# the verdict to a PreToolUse decision. Off-host adapters call the SAME function.
# The git word-boundary detection (path prefixes /usr/bin/git, ./git; substrings
# like "digit"/"github" excluded) lives in loom_git_is_invoke. Fail OPEN on an
# infra gap (missing lib), matching guard-dangerous-commands' posture.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERDICT_LIB="$(cd "$SCRIPT_DIR/../../../.." && pwd)/.logic-loom/lib/governance-verdicts.sh"
# shellcheck disable=SC1090
{ [ -f "$VERDICT_LIB" ] && source "$VERDICT_LIB"; } 2>/dev/null || true

if declare -f loom_verdict_subagent_git >/dev/null 2>&1; then
  if [ "$(loom_verdict_subagent_git "$COMMAND" "$AGENT_ID")" = "deny" ]; then
    AGENT_TYPE="$(json_get '.agent_type' || true)"
    deny "Git is restricted to the main agent (direct user request only). Subagent '${AGENT_TYPE:-unknown}' may not run git — return findings to the main agent, which will run git with user approval. Blocked: '${COMMAND}'"
  fi
  allow
fi

# Fail-SAFE fallback (verdict lib unavailable): this is the LAST line against a
# subagent's destructive git (git clean/reset/checkout). The lib is normally
# present and self-protected; if it is somehow gone we DENY any subagent git
# inline rather than failing open — the deny that this hook exists to enforce
# must not evaporate because a dependency went missing.
if [ -n "$AGENT_ID" ] && printf '%s' "$COMMAND" | grep -qE '(^|[^[:alnum:]_])([^[:space:]]*/)?git([[:space:]]|$)'; then
  AGENT_TYPE="$(json_get '.agent_type' || true)"
  deny "Git is restricted to the main agent (verdict lib unavailable — failing safe). Subagent '${AGENT_TYPE:-unknown}' may not run git. Blocked: '${COMMAND}'"
fi
allow
