#!/usr/bin/env bash
# Guard hook: validates Bash commands against tool-restriction policies.
#
# Primary mode (PreToolUse hook): reads Claude Code PreToolUse JSON from stdin,
# extracts the Bash command, validates it via .logic-loom/lib/policy.sh, and
# emits a hookSpecificOutput decision:
#   policy block    -> permissionDecision "deny"
#   policy approval -> permissionDecision "ask"
#   warn / allow    -> permissionDecision "allow"
# Enforcement is hook-side and model-independent.
#
# CLI fallback: `guard-dangerous-commands.sh "<command>"` prints a human-readable
# verdict and exits non-zero when blocked (used by tests / manual checks).
#
# Input (hook):  {"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}
#
# NOTE: no `set -u` — the sourced policy.sh / logging.sh libs use associative
# array literals that trip `set -u`; a crashing hook must never gate a command.
set -o pipefail
: "${DEBUG:=0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

POLICY_LIB="$REPO_ROOT/.logic-loom/lib/policy.sh"

fail_open() { # never block on infrastructure gaps
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}\n'
    exit 0
}

# policy.sh / logging.sh require bash 4+ (associative arrays, declare -g).
# On older bash (e.g. macOS system bash 3.2) the libs cannot load — fail open
# quietly rather than spam stderr or block. git-safety-gate.sh handles the
# critical git gating independently of this library.
if [[ "${BASH_VERSINFO[0]:-0}" -lt 4 || ! -f "$POLICY_LIB" ]]; then
    [[ $# -gt 0 ]] && exit 0   # CLI mode: no opinion
    fail_open
fi
# shellcheck source=/dev/null
source "$POLICY_LIB" 2>/dev/null || { [[ $# -gt 0 ]] && exit 0; fail_open; }
type validate_tool_call >/dev/null 2>&1 || { [[ $# -gt 0 ]] && exit 0; fail_open; }

emit() { # permissionDecision [reason]
    local decision="$1" reason="${2:-}"
    if [[ -n "$reason" ]]; then
        local esc; esc=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$decision" "$esc"
    else
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s"}}\n' "$decision"
    fi
}

# ----- CLI fallback mode -----
if [[ $# -gt 0 ]]; then
    COMMAND="$1"
    set +e; result=$(validate_tool_call "$COMMAND" 2>/dev/null); ec=$?; set -e 2>/dev/null || true
    case "$ec" in
        2) echo "[BLOCKED] $COMMAND" >&2; display_policy_violation "$result" >&2; exit 1 ;;
        3) echo "[APPROVAL REQUIRED] $COMMAND" >&2; exit 1 ;;
        4) echo "[WARNING] $COMMAND" >&2; exit 0 ;;
        *) exit 0 ;;
    esac
fi

# ----- PreToolUse hook mode -----
INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // .command // empty' 2>/dev/null || true)
[[ -z "$COMMAND" ]] && { emit allow; exit 0; }

set +e; result=$(validate_tool_call "$COMMAND" 2>/dev/null); ec=$?; set -e 2>/dev/null || true
case "$ec" in
    2) emit deny "Policy violation: $result" ;;
    3) emit ask  "Policy requires explicit approval for: $COMMAND" ;;
    *) emit allow ;;
esac
