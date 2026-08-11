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

# policy.sh / logging.sh are now bash 3.2 compatible, so the guard ENFORCES on
# stock macOS (system bash is 3.2) with no install required. This re-exec is kept
# as belt-and-braces: when a bash 4+ is installed we prefer it, so the libs run on
# the interpreter they are primarily developed and CI-tested against.
# LOOM_GUARD_REEXEC prevents an exec loop; we only re-exec into a binary verified
# to be executable and bash-major >= 4. Falling through here is NOT a failure —
# execution continues on 3.2 and the policy is still applied.
if [[ "${BASH_VERSINFO[0]:-0}" -lt 4 && -z "${LOOM_GUARD_REEXEC:-}" ]]; then
    for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        [[ -x "$_b" ]] || continue
        if [[ "$("$_b" -c 'echo "${BASH_VERSINFO[0]}"' 2>/dev/null)" -ge 4 ]]; then
            LOOM_GUARD_REEXEC=1 exec "$_b" "$0" "$@"
        fi
    done
    unset _b
fi

# Fail open ONLY on a genuine infrastructure gap — the policy file itself is
# missing. Bash version is deliberately NOT a condition any more: the libs load on
# 3.2, so gating on it here would disable enforcement on every stock macOS box.
# The remaining fail-open paths below (unsourceable lib, absent validate_tool_call)
# are real breakage, not a supported configuration. git-safety-gate.sh and the
# other guards gate independently and fail SAFE. See governance-threat-model.md.
if [[ ! -f "$POLICY_LIB" ]]; then
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
        5) echo "[POLICY UNAVAILABLE] cannot evaluate: $COMMAND" >&2; exit 1 ;;
        *) exit 0 ;;
    esac
fi

# ----- PreToolUse hook mode -----
INPUT=$(cat)
# jq absent/broken would previously yield an empty COMMAND and silently allow — a
# fail-OPEN on a missing dependency. Distinguish "no jq" from "payload has no command".
if ! command -v jq >/dev/null 2>&1; then
    emit ask "Dangerous-command policy could not read the tool payload (jq unavailable); approve only if you are sure."
    exit 0
fi
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // .command // empty' 2>/dev/null || true)
[[ -z "$COMMAND" ]] && { emit allow; exit 0; }

set +e; result=$(validate_tool_call "$COMMAND" 2>/dev/null); ec=$?; set -e 2>/dev/null || true
case "$ec" in
    2) emit deny "Policy violation: $result" ;;
    3) emit ask  "Policy requires explicit approval for: $COMMAND" ;;
    # Matcher dependency missing — degrade to human approval, never a silent allow.
    5) emit ask  "Dangerous-command policy could not be evaluated (matcher unavailable); approve only if you are sure: $COMMAND" ;;
    *) emit allow ;;
esac
