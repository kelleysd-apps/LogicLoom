#!/usr/bin/env bash
# permissions-sandbox.sh — Permission enforcement & sandbox isolation for loom-dev-loop plugin
#
# Provides functions to enforce the L0-L3 permission tier system, sandbox
# file operations to the workspace boundary, check resource limits, and
# manage approval workflows for protected operations.
#
# Permission Tiers (from config/safety-limits.json):
#   L0 Read-Only:   implicit approval (always permitted)
#   L1 Safe Write:  default_granted (workspace-only writes)
#   L2 Network/VCS: per_session approval required
#   L3 High-Risk:   per_action_always approval required
#
# Blocked operations from config are ALWAYS denied regardless of any approval.
#
# This file is designed to be sourced, not executed directly.
#
# Dependencies: jq (JSON parsing)
# Constitutional Principle VI: Git Approval — no autonomous git operations
# Constitutional Principle XI: Input Validation — validate all operation requests

set -euo pipefail

# ==============================================================================
# Plugin Directory Resolution
# ==============================================================================

if [[ -z "${PLUGIN_DIR:-}" ]]; then
    PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Config paths
_PERM_SAFETY_CONFIG="${PLUGIN_DIR}/config/safety-limits.json"

# ==============================================================================
# Internal Helpers
# ==============================================================================

# _perm_json — Wrapper around jq that always produces compact single-line output.
# All arguments are passed through to jq with -c (compact) prepended.
# This ensures JSON output embeds cleanly in shell variable interpolation.
_perm_json() {
    jq -c "$@"
}

# _perm_json_null — jq -c -n (compact, null input) — for constructing JSON from scratch
_perm_json_null() {
    jq -c -n "$@"
}

# _perm_load_config — Load safety-limits.json from the config directory
# Outputs: JSON string of the full config (compact)
_perm_load_config() {
    if [[ -f "$_PERM_SAFETY_CONFIG" ]]; then
        _perm_json '.' "$_PERM_SAFETY_CONFIG"
    else
        echo "ERROR: Safety config not found at $_PERM_SAFETY_CONFIG" >&2
        return 1
    fi
}

# _perm_get_tier_for_operation — Classify an operation into L0/L1/L2/L3
# Arguments: operation_name
# Outputs: tier string (L0, L1, L2, L3) or "unknown"
_perm_get_tier_for_operation() {
    local operation="$1"
    local config
    config=$(_perm_load_config) || return 1

    # Use a single jq call to find which tier contains the operation
    local result
    result=$(echo "$config" | jq -r --arg op "$operation" '
        .permission_tiers | to_entries[] |
        select(.value.operations // [] | index($op)) |
        .key
    ' | head -1)

    if [[ -n "$result" ]]; then
        echo "$result"
    else
        echo "unknown"
    fi
    return 0
}

# _perm_get_approval_type — Get the approval type for a tier
# Arguments: tier (L0, L1, L2, L3)
# Outputs: approval type string
_perm_get_approval_type() {
    local tier="$1"
    local config
    config=$(_perm_load_config) || return 1

    echo "$config" | jq -r --arg tier "$tier" '.permission_tiers[$tier].approval // "unknown"'
}

# _perm_is_blocked — Check if operation is in the blocked_operations list
# Arguments: operation_name
# Returns: 0 if blocked, 1 if not blocked
_perm_is_blocked() {
    local operation="$1"
    local config
    config=$(_perm_load_config) || return 1

    local count
    count=$(echo "$config" | jq -r --arg op "$operation" \
        '.blocked_operations // [] | map(select(. == $op)) | length')

    [[ "$count" -gt 0 ]] && return 0 || return 1
}

# _perm_load_session_state — Load session state from the session directory
# Arguments: session_id, workdir
# Outputs: JSON session state (compact)
_perm_load_session_state() {
    local session_id="$1"
    local workdir="$2"
    local state_file="${workdir}/.dev-loop/sessions/${session_id}/state.json"

    if [[ ! -f "$state_file" ]]; then
        return 1
    fi

    # Read file contents; sanitize escaped quotes that may appear from heredoc expansion
    local raw_content
    raw_content=$(cat "$state_file")

    # Try jq directly first; if it fails, sanitize backslash-escaped quotes and retry
    if echo "$raw_content" | _perm_json '.' 2>/dev/null; then
        return 0
    fi

    # Sanitize: remove backslash before double-quotes inside arrays (e.g., [\"L2\"] -> ["L2"])
    local sanitized
    sanitized=$(echo "$raw_content" | sed 's/\\"/"/g')
    echo "$sanitized" | _perm_json '.' 2>/dev/null || return 1
}

# _perm_session_has_approval — Check if session has a specific tier approval
# Arguments: session_state_json, tier
# Returns: 0 if approved, 1 if not
_perm_session_has_approval() {
    local session_json="$1"
    local tier="$2"

    local found
    found=$(echo "$session_json" | jq -r --arg tier "$tier" \
        '.permissions.session_approvals // [] | map(select(. == $tier)) | length')

    [[ "$found" -gt 0 ]] && return 0 || return 1
}

# _perm_resolve_path — Resolve a path to its canonical absolute form
# Arguments: path
# Outputs: canonical path (resolves .., symlinks where possible)
_perm_resolve_path() {
    local path="$1"
    # Use Python for reliable path resolution (handles non-existent paths too)
    python3 -c "import os; print(os.path.realpath('$path'))" 2>/dev/null || echo "$path"
}

# ==============================================================================
# check_permission — Evaluate operation against L0-L3 tiers
# ==============================================================================
# Usage: check_permission --session <id> --operation <op> --workdir <dir> [--force-approve true] [--list-tiers]
#
# Evaluates whether an operation is allowed given the current session's
# permission state. Returns a JSON result with allowed/denied status,
# the resolved tier, and the approval type.
#
# Arguments (flag-style):
#   --session <session_id>    — Session identifier
#   --operation <op_name>     — Operation to check (e.g., "read_file", "git_push")
#   --workdir <dir>           — Working directory root
#   --force-approve true      — Attempt to force-approve (blocked ops still blocked)
#   --list-tiers              — List all tiers and return
#
# Outputs: Compact JSON object (single line):
#   {"allowed": true/false, "tier": "L0-L3", "approval": "...", "error": "..."}
# Returns: 0 on success (function executed), regardless of allowed/denied
check_permission() {
    local session_id="" operation="" workdir="" force_approve="" list_tiers=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session)    session_id="$2"; shift 2 ;;
            --operation)  operation="$2"; shift 2 ;;
            --workdir)    workdir="$2"; shift 2 ;;
            --force-approve) force_approve="$2"; shift 2 ;;
            --list-tiers) list_tiers=true; shift ;;
            *) shift ;;
        esac
    done

    # Handle --list-tiers: return tier structure from config
    if [[ "$list_tiers" == "true" ]]; then
        local config
        config=$(_perm_load_config) || {
            _perm_json_null '{"error": "CONFIG_NOT_FOUND", "tiers": {}}'
            return 0
        }
        echo "$config" | _perm_json '{tiers: .permission_tiers}'
        return 0
    fi

    # Validate: operation is required
    if [[ -z "$operation" ]]; then
        _perm_json_null '{"error": "INVALID_OPERATION", "allowed": false, "message": "Operation parameter is required"}'
        return 0
    fi

    # Validate: session must exist
    if [[ -n "$session_id" && -n "$workdir" ]]; then
        local session_state
        if ! session_state=$(_perm_load_session_state "$session_id" "$workdir" 2>/dev/null); then
            _perm_json_null --arg sid "$session_id" \
                '{"error": "SESSION_NOT_FOUND", "allowed": false, "message": ("Session not found: " + $sid)}'
            return 0
        fi
    else
        _perm_json_null '{"error": "SESSION_NOT_FOUND", "allowed": false, "message": "Session ID and workdir required"}'
        return 0
    fi

    # Step 1: Check if operation is blocked (always denied regardless of anything)
    if _perm_is_blocked "$operation"; then
        _perm_json_null --arg op "$operation" --arg tier "L3" --arg approval "per_action_always" \
            '{"allowed": false, "tier": $tier, "approval": $approval, "error": "OPERATION_BLOCKED", "message": ("Operation permanently blocked: " + $op)}'
        return 0
    fi

    # Step 2: Determine the tier for this operation
    local tier
    tier=$(_perm_get_tier_for_operation "$operation")

    # Unknown operations are treated as blocked (fail-safe)
    if [[ "$tier" == "unknown" ]]; then
        _perm_json_null --arg op "$operation" \
            '{"allowed": false, "tier": "unknown", "approval": "denied", "error": "OPERATION_BLOCKED", "message": ("Unknown operation blocked (fail-safe): " + $op)}'
        return 0
    fi

    # Step 3: Get the approval type for this tier
    local approval
    approval=$(_perm_get_approval_type "$tier")

    # Step 4: Evaluate permission based on tier
    case "$tier" in
        L0)
            # L0: Always allowed (implicit)
            _perm_json_null --arg tier "$tier" --arg approval "$approval" \
                '{"allowed": true, "tier": $tier, "approval": $approval}'
            ;;

        L1)
            # L1: Default granted for workspace-only writes
            _perm_json_null --arg tier "$tier" --arg approval "$approval" \
                '{"allowed": true, "tier": $tier, "approval": $approval}'
            ;;

        L2)
            # L2: Requires session-level approval
            if _perm_session_has_approval "$session_state" "L2"; then
                _perm_json_null --arg tier "$tier" --arg approval "$approval" \
                    '{"allowed": true, "tier": $tier, "approval": $approval}'
            else
                _perm_json_null --arg tier "$tier" --arg approval "$approval" --arg op "$operation" \
                    '{"allowed": false, "tier": $tier, "approval": $approval, "error": "APPROVAL_REQUIRED", "message": ("Session-level approval required for " + $tier + " operation: " + $op)}'
            fi
            ;;

        L3)
            # L3: Always requires per-action approval — session approval is NOT sufficient
            _perm_json_null --arg tier "$tier" --arg approval "$approval" --arg op "$operation" \
                '{"allowed": false, "tier": $tier, "approval": $approval, "error": "APPROVAL_REQUIRED", "message": ("Per-action approval required for " + $tier + " operation: " + $op)}'
            ;;
    esac

    return 0
}

# ==============================================================================
# request_approval — Request approval for an L2/L3 operation
# ==============================================================================
# Usage: request_approval --session <id> --tier <L2|L3> [--operation <op>] --workdir <dir>
#
# Creates an approval request for the specified tier. Returns a pending
# approval token that must be confirmed by the user.
#
# Arguments (flag-style):
#   --session <session_id>  — Session identifier
#   --tier <L2|L3>          — Permission tier to request
#   --operation <op_name>   — Operation name (required for L3)
#   --workdir <dir>         — Working directory root
#
# Outputs: Compact JSON object:
#   {"status": "pending", "tier": "L2|L3", "scope": "session|per_action", ...}
# Returns: 0 on success
request_approval() {
    local session_id="" tier="" operation="" workdir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session)   session_id="$2"; shift 2 ;;
            --tier)      tier="$2"; shift 2 ;;
            --operation) operation="$2"; shift 2 ;;
            --workdir)   workdir="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    # Validate tier is provided
    if [[ -z "$tier" ]]; then
        _perm_json_null '{"error": "INVALID_TIER", "message": "Tier parameter is required"}'
        return 0
    fi

    # Validate tier is L0-L3
    if [[ "$tier" != "L0" && "$tier" != "L1" && "$tier" != "L2" && "$tier" != "L3" ]]; then
        _perm_json_null --arg tier "$tier" \
            '{"error": "INVALID_TIER", "message": ("Invalid tier: " + $tier + ". Must be L0, L1, L2, or L3")}'
        return 0
    fi

    # Determine scope based on tier
    local scope
    case "$tier" in
        L0|L1) scope="implicit" ;;
        L2)    scope="session" ;;
        L3)    scope="per_action" ;;
    esac

    # Generate approval token
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if [[ "$tier" == "L3" ]]; then
        _perm_json_null \
            --arg status "pending" \
            --arg tier "$tier" \
            --arg scope "$scope" \
            --arg operation "${operation:-unknown}" \
            --arg session "$session_id" \
            --arg timestamp "$timestamp" \
            '{"status": $status, "tier": $tier, "scope": $scope, "operation": $operation, "session": $session, "requested_at": $timestamp, "message": ("Per-action approval required for " + $tier + " operation: " + $operation)}'
    else
        _perm_json_null \
            --arg status "pending" \
            --arg tier "$tier" \
            --arg scope "$scope" \
            --arg session "$session_id" \
            --arg timestamp "$timestamp" \
            '{"status": $status, "tier": $tier, "scope": $scope, "session": $session, "requested_at": $timestamp, "message": ("Session-level approval required for " + $tier + " operations")}'
    fi

    return 0
}

# ==============================================================================
# enforce_sandbox — Verify file operations stay within workspace boundary
# ==============================================================================
# Usage: enforce_sandbox --session <id> --operation <op> --target <path> --workdir <dir>
#
# Validates that a file operation target path resolves to a location within
# the workspace directory. Prevents path traversal attacks (../../etc/passwd).
#
# Arguments (flag-style):
#   --session <session_id>  — Session identifier
#   --operation <op_name>   — Operation being performed
#   --target <file_path>    — Target file/directory path
#   --workdir <dir>         — Workspace root directory
#
# Outputs: Compact JSON object:
#   {"allowed": true/false, "error": "SANDBOX_VIOLATION"|null, ...}
# Returns: 0 on success
enforce_sandbox() {
    local session_id="" operation="" target="" workdir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session)   session_id="$2"; shift 2 ;;
            --operation) operation="$2"; shift 2 ;;
            --target)    target="$2"; shift 2 ;;
            --workdir)   workdir="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    # Validate target is provided
    if [[ -z "$target" ]]; then
        _perm_json_null '{"error": "INVALID_TARGET", "allowed": false, "message": "Target path is required"}'
        return 0
    fi

    # Validate workdir is provided
    if [[ -z "$workdir" ]]; then
        _perm_json_null '{"error": "INVALID_TARGET", "allowed": false, "message": "Workdir is required"}'
        return 0
    fi

    # Resolve both paths to canonical form to prevent path traversal
    local resolved_target resolved_workspace
    resolved_target=$(_perm_resolve_path "$target")
    resolved_workspace=$(_perm_resolve_path "${workdir}/workspace")

    # Check if target is within the workspace directory
    if [[ "$resolved_target" == "$resolved_workspace"* ]]; then
        _perm_json_null \
            --arg target "$target" \
            --arg resolved "$resolved_target" \
            --arg workspace "$resolved_workspace" \
            --arg operation "${operation:-unknown}" \
            '{"allowed": true, "target": $target, "resolved_target": $resolved, "workspace": $workspace, "operation": $operation}'
    else
        _perm_json_null \
            --arg target "$target" \
            --arg resolved "$resolved_target" \
            --arg workspace "$resolved_workspace" \
            --arg operation "${operation:-unknown}" \
            '{"allowed": false, "error": "SANDBOX_VIOLATION", "target": $target, "resolved_target": $resolved, "workspace": $workspace, "operation": $operation, "message": "Target path is outside the workspace boundary"}'
    fi

    return 0
}

# ==============================================================================
# check_resource_limits — Verify resource usage against configured limits
# ==============================================================================
# Usage: check_resource_limits [--memory <mb>] [--cpu <cores>] [--disk <gb>] --workdir <dir>
#
# Loads resource limits from config/safety-limits.json and compares against
# provided current usage values. If no usage values are provided, returns
# the configured limits.
#
# Arguments (flag-style):
#   --memory <mb>     — Current memory usage in MB
#   --cpu <cores>     — Current CPU core usage
#   --disk <gb>       — Current disk usage in GB
#   --workdir <dir>   — Working directory root
#
# Outputs: Compact JSON object:
#   {"within_bounds": true/false, "limits": {...}, "current": {...}, "violations": {...}}
# Returns: 0 on success
check_resource_limits() {
    local memory="" cpu="" disk="" workdir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --memory)  memory="$2"; shift 2 ;;
            --cpu)     cpu="$2"; shift 2 ;;
            --disk)    disk="$2"; shift 2 ;;
            --workdir) workdir="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    # Load resource limits from config
    local config
    config=$(_perm_load_config) || {
        _perm_json_null '{"error": "CONFIG_NOT_FOUND", "within_bounds": false}'
        return 0
    }

    local limit_memory limit_cpu limit_disk
    limit_memory=$(echo "$config" | jq -r '.resource_limits.memory_mb')
    limit_cpu=$(echo "$config" | jq -r '.resource_limits.cpu_cores')
    limit_disk=$(echo "$config" | jq -r '.resource_limits.disk_gb')

    # If no usage values provided, just return the limits
    if [[ -z "$memory" && -z "$cpu" && -z "$disk" ]]; then
        _perm_json_null \
            --argjson mem "$limit_memory" \
            --argjson cpu "$limit_cpu" \
            --argjson disk "$limit_disk" \
            '{"within_bounds": true, "limits": {"memory_mb": $mem, "cpu_cores": $cpu, "disk_gb": $disk}}'
        return 0
    fi

    # Default current values to 0 if not provided
    memory="${memory:-0}"
    cpu="${cpu:-0}"
    disk="${disk:-0}"

    # Check each limit and build violations object
    local within_bounds=true
    local violations="{}"

    # Memory check
    if [[ "$memory" -gt "$limit_memory" ]]; then
        within_bounds=false
        violations=$(echo "$violations" | _perm_json \
            --argjson current "$memory" \
            --argjson limit "$limit_memory" \
            '. + {"memory_mb": {"current": $current, "limit": $limit}}')
    fi

    # CPU check
    if [[ "$cpu" -gt "$limit_cpu" ]]; then
        within_bounds=false
        violations=$(echo "$violations" | _perm_json \
            --argjson current "$cpu" \
            --argjson limit "$limit_cpu" \
            '. + {"cpu_cores": {"current": $current, "limit": $limit}}')
    fi

    # Disk check
    if [[ "$disk" -gt "$limit_disk" ]]; then
        within_bounds=false
        violations=$(echo "$violations" | _perm_json \
            --argjson current "$disk" \
            --argjson limit "$limit_disk" \
            '. + {"disk_gb": {"current": $current, "limit": $limit}}')
    fi

    local bounds_bool
    if [[ "$within_bounds" == "true" ]]; then
        bounds_bool=true
    else
        bounds_bool=false
    fi

    _perm_json_null \
        --argjson within_bounds "$bounds_bool" \
        --argjson limit_mem "$limit_memory" \
        --argjson limit_cpu "$limit_cpu" \
        --argjson limit_disk "$limit_disk" \
        --argjson cur_mem "$memory" \
        --argjson cur_cpu "$cpu" \
        --argjson cur_disk "$disk" \
        --argjson violations "$violations" \
        '{"within_bounds": $within_bounds, "limits": {"memory_mb": $limit_mem, "cpu_cores": $limit_cpu, "disk_gb": $limit_disk}, "current": {"memory_mb": $cur_mem, "cpu_cores": $cur_cpu, "disk_gb": $cur_disk}, "violations": $violations}'

    return 0
}

# ==============================================================================
# is_operation_blocked — Check if an operation is permanently blocked
# ==============================================================================
# Usage: is_operation_blocked --operation <op_name> --workdir <dir>
#
# Checks the blocked_operations list in config/safety-limits.json.
# Unknown operations are treated as blocked (fail-safe principle).
#
# Arguments (flag-style):
#   --operation <op_name>  — Operation to check
#   --workdir <dir>        — Working directory root
#
# Outputs: Compact JSON object:
#   {"blocked": true/false, "operation": "...", "reason": "..."}
# Returns: 0 on success
is_operation_blocked() {
    local operation="" workdir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --operation) operation="$2"; shift 2 ;;
            --workdir)   workdir="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ -z "$operation" ]]; then
        _perm_json_null '{"blocked": true, "operation": "", "reason": "No operation specified"}'
        return 0
    fi

    # Check if in blocked_operations list
    if _perm_is_blocked "$operation"; then
        _perm_json_null --arg op "$operation" \
            '{"blocked": true, "operation": $op, "reason": ("Operation is permanently blocked by safety configuration: " + $op)}'
        return 0
    fi

    # Check if operation is known (exists in any tier)
    local tier
    tier=$(_perm_get_tier_for_operation "$operation")

    if [[ "$tier" == "unknown" ]]; then
        # Unknown operations are blocked (fail-safe)
        _perm_json_null --arg op "$operation" \
            '{"blocked": true, "operation": $op, "reason": ("Unknown operation blocked by fail-safe policy: " + $op)}'
        return 0
    fi

    # Known, non-blocked operation
    _perm_json_null --arg op "$operation" --arg tier "$tier" \
        '{"blocked": false, "operation": $op, "tier": $tier}'

    return 0
}

# ==============================================================================
# grant_session_permission — Record an L2 session-level approval grant
# ==============================================================================
# Usage: grant_session_permission <session_id> <tier> <workdir>
#
# Writes the tier to the session's permissions.session_approvals array.
#
# Arguments:
#   session_id — Session identifier
#   tier       — Tier to grant (L2)
#   workdir    — Working directory root
#
# Outputs: Updated session state JSON
# Returns: 0 on success, 1 on failure
grant_session_permission() {
    local session_id="$1"
    local tier="$2"
    local workdir="$3"

    local state_file="${workdir}/.dev-loop/sessions/${session_id}/state.json"

    if [[ ! -f "$state_file" ]]; then
        echo "ERROR: Session state not found: $state_file" >&2
        return 1
    fi

    # Add tier to session_approvals if not already present
    local updated
    updated=$(_perm_json --arg tier "$tier" \
        '.permissions.session_approvals = (
            (.permissions.session_approvals // []) |
            if any(. == $tier) then . else . + [$tier] end
        )' "$state_file")

    echo "$updated" > "$state_file"
    echo "$updated"
    return 0
}

# ==============================================================================
# load_session_permissions — Read approved permissions for current session
# ==============================================================================
# Usage: load_session_permissions <session_id> <workdir>
#
# Reads the session state and returns the current permission grants.
#
# Arguments:
#   session_id — Session identifier
#   workdir    — Working directory root
#
# Outputs: JSON object with session permissions
# Returns: 0 on success, 1 on failure
load_session_permissions() {
    local session_id="$1"
    local workdir="$2"

    local session_state
    if ! session_state=$(_perm_load_session_state "$session_id" "$workdir"); then
        echo "ERROR: Session not found: $session_id" >&2
        return 1
    fi

    echo "$session_state" | _perm_json '.permissions // {"session_approvals": [], "action_approvals": []}'
    return 0
}

# ==============================================================================
# Sandbox Setup Functions (Docker & OS-level)
# ==============================================================================

# setup_docker_sandbox — Create Docker container with security constraints
# Usage: setup_docker_sandbox <workspace_path> [container_name]
#
# Creates a Docker container with:
#   - Non-root UID 1000
#   - Read-only root filesystem
#   - Writable /workspace volume
#   - Network restrictions (--network none)
#   - Resource limits (2GB RAM, 1 CPU, 10GB disk)
#
# Arguments:
#   workspace_path  — Host path to mount as /workspace
#   container_name  — Optional container name (default: devloop-sandbox-<timestamp>)
#
# Outputs: Compact JSON object with container details
# Returns: 0 on success, 1 on failure
setup_docker_sandbox() {
    local workspace_path="$1"
    local container_name="${2:-devloop-sandbox-$(date +%s)}"

    # Load resource limits from config
    local config
    config=$(_perm_load_config) || return 1

    local memory_mb cpu_cores
    memory_mb=$(echo "$config" | jq -r '.resource_limits.memory_mb')
    cpu_cores=$(echo "$config" | jq -r '.resource_limits.cpu_cores')

    # Check if Docker is available
    if ! command -v docker &>/dev/null; then
        _perm_json_null '{"success": false, "error": "Docker not available", "method": "docker"}'
        return 1
    fi

    # Create the container
    local container_id
    container_id=$(docker create \
        --name "$container_name" \
        --user 1000:1000 \
        --read-only \
        --tmpfs /tmp:rw,noexec,nosuid \
        --volume "${workspace_path}:/workspace:rw" \
        --network none \
        --memory "${memory_mb}m" \
        --cpus "$cpu_cores" \
        --pids-limit 256 \
        --security-opt no-new-privileges \
        ubuntu:22.04 \
        /bin/bash 2>/dev/null) || {
        _perm_json_null --arg err "Failed to create Docker container" \
            '{"success": false, "error": $err, "method": "docker"}'
        return 1
    }

    _perm_json_null \
        --arg container_id "$container_id" \
        --arg container_name "$container_name" \
        --arg workspace "$workspace_path" \
        --argjson memory_mb "$memory_mb" \
        --argjson cpu_cores "$cpu_cores" \
        '{"success": true, "method": "docker", "container_id": $container_id, "container_name": $container_name, "workspace": $workspace, "constraints": {"user": "1000:1000", "read_only_root": true, "network": "none", "memory_mb": $memory_mb, "cpu_cores": $cpu_cores, "pids_limit": 256, "no_new_privileges": true}}'

    return 0
}

# setup_os_sandbox — Create OS-level sandbox (macOS seatbelt or Linux bubblewrap)
# Usage: setup_os_sandbox <workspace_path>
#
# macOS: Generates a sandbox-exec seatbelt profile
# Linux: Uses bubblewrap (bwrap) with seccomp
#
# Arguments:
#   workspace_path — Path to restrict operations to
#
# Outputs: Compact JSON object with sandbox details
# Returns: 0 on success, 1 on failure
setup_os_sandbox() {
    local workspace_path="$1"

    local os_type
    os_type=$(uname -s)

    case "$os_type" in
        Darwin)
            # macOS: Generate seatbelt profile
            local profile_path="${workspace_path}/.devloop-sandbox.sb"
            local resolved_workspace
            resolved_workspace=$(_perm_resolve_path "$workspace_path")

            # Create seatbelt profile
            cat > "$profile_path" <<SEATBELT
(version 1)
(deny default)
(allow process-exec)
(allow process-fork)
(allow file-read* (subpath "${resolved_workspace}"))
(allow file-write* (subpath "${resolved_workspace}"))
(allow file-read* (subpath "/usr"))
(allow file-read* (subpath "/bin"))
(allow file-read* (subpath "/Library"))
(allow file-read* (subpath "/System"))
(allow file-read-metadata)
(allow sysctl-read)
(deny network*)
SEATBELT

            _perm_json_null \
                --arg method "seatbelt" \
                --arg profile "$profile_path" \
                --arg workspace "$resolved_workspace" \
                '{"success": true, "method": $method, "profile_path": $profile, "workspace": $workspace, "constraints": {"file_read": "workspace + system", "file_write": "workspace only", "network": "denied", "process": "allowed"}}'
            ;;

        Linux)
            # Linux: Check for bubblewrap
            if ! command -v bwrap &>/dev/null; then
                _perm_json_null '{"success": false, "error": "bubblewrap (bwrap) not available", "method": "bubblewrap"}'
                return 1
            fi

            local resolved_workspace
            resolved_workspace=$(_perm_resolve_path "$workspace_path")

            _perm_json_null \
                --arg method "bubblewrap" \
                --arg workspace "$resolved_workspace" \
                '{"success": true, "method": $method, "workspace": $workspace, "bwrap_args": ["--ro-bind", "/usr", "/usr", "--ro-bind", "/bin", "/bin", "--ro-bind", "/lib", "/lib", "--bind", $workspace, "/workspace", "--tmpfs", "/tmp", "--unshare-net", "--unshare-pid", "--die-with-parent"], "constraints": {"file_read": "workspace + system", "file_write": "workspace only", "network": "unshared", "pid_namespace": "isolated"}}'
            ;;

        *)
            _perm_json_null --arg os "$os_type" \
                '{"success": false, "error": ("Unsupported OS for sandbox: " + $os), "method": "none"}'
            return 1
            ;;
    esac

    return 0
}

# detect_sandbox_method — Determine best available sandbox method
# Usage: detect_sandbox_method
#
# Checks Docker availability first, then falls back to OS-level sandbox.
#
# Outputs: Compact JSON object with recommended method
# Returns: 0 on success
detect_sandbox_method() {
    if command -v docker &>/dev/null; then
        local docker_running=false
        if docker info &>/dev/null 2>&1; then
            docker_running=true
        fi

        if [[ "$docker_running" == "true" ]]; then
            _perm_json_null '{"method": "docker", "available": true, "fallback": null}'
            return 0
        fi
    fi

    local os_type
    os_type=$(uname -s)

    case "$os_type" in
        Darwin)
            if command -v sandbox-exec &>/dev/null; then
                _perm_json_null '{"method": "seatbelt", "available": true, "fallback": "none"}'
            else
                _perm_json_null '{"method": "none", "available": false, "fallback": null}'
            fi
            ;;
        Linux)
            if command -v bwrap &>/dev/null; then
                _perm_json_null '{"method": "bubblewrap", "available": true, "fallback": "none"}'
            else
                _perm_json_null '{"method": "none", "available": false, "fallback": null}'
            fi
            ;;
        *)
            _perm_json_null --arg os "$os_type" '{"method": "none", "available": false, "os": $os}'
            ;;
    esac

    return 0
}

# enforce_resource_limits — Check and enforce memory/CPU/disk bounds per iteration
# Usage: enforce_resource_limits <workspace_path>
#
# Reads current resource usage and compares against config limits.
# This is a wrapper around check_resource_limits that auto-detects current usage.
#
# Arguments:
#   workspace_path — Workspace directory to check disk usage for
#
# Outputs: Compact JSON object from check_resource_limits
# Returns: 0 if within bounds, 1 if exceeded
enforce_resource_limits() {
    local workspace_path="$1"

    # Get current disk usage in GB (approximate)
    local disk_gb=0
    if [[ -d "$workspace_path" ]]; then
        local disk_kb
        disk_kb=$(du -sk "$workspace_path" 2>/dev/null | cut -f1 || echo "0")
        disk_gb=$(( disk_kb / 1048576 ))  # KB to GB
    fi

    # Get memory info (platform-dependent)
    local memory_mb=0
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # macOS: get process memory via ps
        memory_mb=$(ps -o rss= -p $$ 2>/dev/null | awk '{print int($1/1024)}' || echo "0")
    else
        # Linux: get from /proc
        if [[ -f /proc/self/status ]]; then
            memory_mb=$(awk '/VmRSS/{print int($2/1024)}' /proc/self/status 2>/dev/null || echo "0")
        fi
    fi

    check_resource_limits --memory "$memory_mb" --cpu 1 --disk "$disk_gb" --workdir "$(dirname "$workspace_path")"
}

# teardown_sandbox — Cleanup Docker container or sandbox profile
# Usage: teardown_sandbox <method> <identifier>
#
# Arguments:
#   method     — "docker", "seatbelt", or "bubblewrap"
#   identifier — Container name/ID or profile path
#
# Outputs: Compact JSON cleanup result
# Returns: 0 on success
teardown_sandbox() {
    local method="$1"
    local identifier="$2"

    case "$method" in
        docker)
            if command -v docker &>/dev/null; then
                docker rm -f "$identifier" &>/dev/null || true
                _perm_json_null --arg method "$method" --arg id "$identifier" \
                    '{"success": true, "method": $method, "cleaned": $id}'
            else
                _perm_json_null '{"success": false, "error": "Docker not available"}'
            fi
            ;;
        seatbelt)
            # Remove the seatbelt profile file
            if [[ -f "$identifier" ]]; then
                rm -f "$identifier"
                _perm_json_null --arg method "$method" --arg profile "$identifier" \
                    '{"success": true, "method": $method, "cleaned": $profile}'
            else
                _perm_json_null --arg profile "$identifier" \
                    '{"success": true, "method": "seatbelt", "message": "Profile already removed", "path": $profile}'
            fi
            ;;
        bubblewrap)
            # Bubblewrap cleans up on process exit; nothing to do
            _perm_json_null '{"success": true, "method": "bubblewrap", "message": "Bubblewrap sandbox is process-scoped"}'
            ;;
        *)
            _perm_json_null --arg method "$method" \
                '{"success": false, "error": ("Unknown sandbox method: " + $method)}'
            return 1
            ;;
    esac

    return 0
}

# validate_workspace_boundary — Verify all file operations within workspace
# Usage: validate_workspace_boundary <target_path> <workspace_path>
#
# A simpler wrapper around enforce_sandbox for quick boundary checks.
#
# Arguments:
#   target_path    — Path to validate
#   workspace_path — Workspace root
#
# Returns: 0 if within boundary, 1 if outside
validate_workspace_boundary() {
    local target_path="$1"
    local workspace_path="$2"

    local resolved_target resolved_workspace
    resolved_target=$(_perm_resolve_path "$target_path")
    resolved_workspace=$(_perm_resolve_path "$workspace_path")

    if [[ "$resolved_target" == "$resolved_workspace"* ]]; then
        return 0
    else
        return 1
    fi
}
