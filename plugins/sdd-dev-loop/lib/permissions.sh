#!/usr/bin/env bash
# permissions.sh — Permission enforcement library for sdd-dev-loop plugin
#
# Thin wrapper that sources the combined permissions-sandbox.sh library.
# This file exists as a module entry point per the T026 task specification.
# All permission functions are implemented in permissions-sandbox.sh.
#
# Exported functions:
#   check_permission()         — Evaluate operation against L0-L3 tiers
#   get_tier_for_operation()   — Classify operation into L0/L1/L2/L3
#   is_git_branch_op()         — Detect git branch create/switch/delete (always blocked)
#   is_git_push_op()           — Detect git push (requires per-action approval)
#   request_approval()         — Prompt user for L2/L3 operations
#   load_session_permissions() — Read approved permissions for current session
#   grant_session_permission() — Record L2 session-level grant
#
# Permission Tiers:
#   L0: implicit allow (read-only operations)
#   L1: default granted for workspace-only writes
#   L2: per-session approval required (network/VCS)
#   L3: per-action approval required (high-risk)
#   Blocked operations are ALWAYS denied regardless of approval
#
# This file is designed to be sourced, not executed directly.
#
# Dependencies: jq (JSON parsing), permissions-sandbox.sh
# Constitutional Principle VI: Git Approval — no autonomous git operations

set -euo pipefail

# ==============================================================================
# Plugin Directory Resolution
# ==============================================================================

if [[ -z "${PLUGIN_DIR:-}" ]]; then
    PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Source the combined implementation if not already loaded
if ! type -t check_permission &>/dev/null; then
    source "${PLUGIN_DIR}/lib/permissions-sandbox.sh"
fi

# ==============================================================================
# Convenience Wrappers (T026 API)
# ==============================================================================

# get_tier_for_operation — Public wrapper for _perm_get_tier_for_operation
# Usage: get_tier_for_operation <operation_name>
# Outputs: tier string (L0, L1, L2, L3) or "unknown"
get_tier_for_operation() {
    _perm_get_tier_for_operation "$@"
}

# is_git_branch_op — Detect git branch create/switch/delete (ALWAYS blocked)
# Usage: is_git_branch_op <operation_name>
# Returns: 0 if the operation is a git branch op, 1 otherwise
is_git_branch_op() {
    local operation="$1"
    case "$operation" in
        git_branch_create|git_branch_switch|git_branch_delete)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# is_git_push_op — Detect git push operation (requires per-action approval)
# Usage: is_git_push_op <operation_name>
# Returns: 0 if the operation is git_push, 1 otherwise
is_git_push_op() {
    local operation="$1"
    [[ "$operation" == "git_push" ]] && return 0 || return 1
}
