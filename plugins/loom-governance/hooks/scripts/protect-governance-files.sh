#!/usr/bin/env bash
# Protect Governance Files — PreToolUse hook (Write/Edit + Bash), Principle VI/governance.
#
# The model has Write/Edit/Bash access to the very files that govern it — the
# hook scripts, settings.json, the constitution, governance.conf. Left open, a
# model (or a subagent) can soften or delete its own guardrails (observed in the
# wild — Claude Code RFC #45427). This hook makes the governance surface
# self-protecting:
#   - a SUBAGENT (agent_id present) editing a protected path  -> DENY (hard)
#   - the MAIN agent editing a protected path                 -> ASK (human approval,
#                                                                like git mutations)
#   - anything else                                           -> ALLOW
#
# It is NOT airtight (a string gate can't see interpreter/eval indirection — see
# subagent-git-guard's note); it is one layer of defense-in-depth, not a sandbox.
#
# Input:  PreToolUse JSON via stdin (Write/Edit/MultiEdit/NotebookEdit or Bash).
# Output: hookSpecificOutput decision (deny / ask / allow).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# plugins/loom-governance/hooks/scripts -> repo root is 4 up
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

INPUT=$(cat)

json_get() { # jq-path
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

allow() { printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}\n'; exit 0; }
decide() { # deny|ask  reason
  local d="$1" reason="$2" esc
  esc=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$d" "$esc"
  exit 0
}

AGENT_ID="$(json_get '.agent_id' || true)"
TOOL="$(json_get '.tool_name' || true)"

# Protected governance surface (repo-root-relative path prefixes).
is_protected() { # rel_path -> 0 if protected
  case "$1" in
    .claude/hooks/*|.claude/hooks \
    |.claude/settings.json|.claude/settings.local.json \
    |.logic-loom/config/governance.conf \
    |.logic-loom/memory/constitution.md \
    |plugins/loom-governance/hooks/*|plugins/loom-governance/hooks \
    |plugins/loom-governance/.claude-plugin/plugin.json) return 0 ;;
  esac
  return 1
}

# Canonicalize a path and make it repo-root-relative for matching.
rel_of() { # raw_path -> relative path (or raw if outside repo)
  local p="$1" canon
  if command -v python3 >/dev/null 2>&1; then
    canon=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$p" 2>/dev/null)
  fi
  [ -n "${canon:-}" ] || canon=$(printf '%s' "$p" | sed 's://*:/:g')
  case "$canon" in
    "$REPO_ROOT"/*) printf '%s' "${canon:${#REPO_ROOT}+1}" ;;
    /*)             printf '%s' "$canon" ;;   # absolute, outside repo
    *)              printf '%s' "$canon" ;;   # already relative
  esac
}

gate() { # rel_path  verb-desc
  is_protected "$1" || return 0
  if [ -n "$AGENT_ID" ]; then
    decide deny "Governance file '$1' may NOT be modified by a subagent ('$(json_get '.agent_type')'). The hooks/constitution/settings that enforce governance are main-agent + explicit-user-approval only. Return the proposed change to the main agent."
  else
    decide ask "About to modify a GOVERNANCE file: '$1'. This changes the rules that enforce the constitution (hooks/settings/constitution/governance.conf). Approve only if you intend to change governance itself."
  fi
}

case "$TOOL" in
  Write|Edit|MultiEdit|NotebookEdit)
    FP="$(json_get '.tool_input.file_path' || true)"
    [ -z "$FP" ] && FP="$(json_get '.tool_input.notebook_path' || true)"
    [ -z "$FP" ] && allow
    gate "$(rel_of "$FP")" "write"
    ;;
  Bash)
    CMD="$(json_get '.tool_input.command' || true)"
    [ -z "$CMD" ] && allow
    # Only care about MUTATING bash that targets a protected path. Reads
    # (cat/grep/source of a governance file) are fine.
    if printf '%s' "$CMD" | grep -qE '(>>?|[[:space:]]tee[[:space:]]|dd[[:space:]]+[^|]*of=|sed[[:space:]]+-i|[[:space:]]rm[[:space:]]|[[:space:]]mv[[:space:]]|truncate|chmod|chown|install[[:space:]])'; then
      # Scan each protected token; if the command mentions it, gate.
      for prot in ".claude/hooks" ".claude/settings.json" ".claude/settings.local.json" \
                  ".logic-loom/config/governance.conf" ".logic-loom/memory/constitution.md" \
                  "plugins/loom-governance/hooks" "plugins/loom-governance/.claude-plugin/plugin.json"; do
        if printf '%s' "$CMD" | grep -qF "$prot"; then
          if [ -n "$AGENT_ID" ]; then
            decide deny "Subagent ('$(json_get '.agent_type')') may not modify governance file '$prot' via Bash. Governance changes are main-agent + user-approval only."
          else
            decide ask "Bash command appears to MODIFY a governance path ('$prot'). Approve only if you intend to change governance itself. Command: $CMD"
          fi
        fi
      done
    fi
    ;;
esac

allow
