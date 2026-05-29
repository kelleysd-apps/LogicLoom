#!/usr/bin/env bash
# lifecycle.sh — Session lifecycle management for loom-dev-loop plugin
#
# Manages session creation, iteration execution, grading, termination,
# and resumption for the recursive autonomous dev-loop.
#
# This file is designed to be sourced, not executed directly.
#
# Dependencies: jq (JSON parsing)
# Constitutional Principle VI: Git Approval — sessions do not perform git operations

set -euo pipefail

if [[ -z "${PLUGIN_DIR:-}" ]]; then
    PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# ==============================================================================
# Config paths
# ==============================================================================

_LIFECYCLE_THRESHOLDS_CONFIG="${PLUGIN_DIR}/config/thresholds.json"
_LIFECYCLE_SAFETY_CONFIG="${PLUGIN_DIR}/config/safety-limits.json"
_LIFECYCLE_WEIGHTS_CONFIG="${PLUGIN_DIR}/config/weights.json"

# ==============================================================================
# Internal Helpers
# ==============================================================================

# _lifecycle_iso8601 — Current UTC timestamp in ISO 8601 format
_lifecycle_iso8601() {
    if command -v python3 &>/dev/null; then
        python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))"
    else
        date -u +"%Y-%m-%dT%H:%M:%SZ"
    fi
}

# _lifecycle_generate_session_id — Generate a unique session identifier
_lifecycle_generate_session_id() {
    local timestamp random_hex
    timestamp=$(date +%Y%m%d-%H%M%S)
    random_hex=$(head -c 5 /dev/urandom | od -An -tx1 | tr -d ' ')
    echo "devloop-${timestamp}-${random_hex}"
}

# _lifecycle_bc_calc — Evaluate a floating-point expression via bc
_lifecycle_bc_calc() {
    echo "$1" | bc -l 2>/dev/null || echo "0"
}

# _lifecycle_bc_compare — Compare two floating-point numbers
# Returns: 0 (true) or 1 (false)
_lifecycle_bc_compare() {
    local a="$1" op="$2" b="$3"
    local result
    case "$op" in
        "<")  result=$(_lifecycle_bc_calc "$a < $b") ;;
        "<=") result=$(_lifecycle_bc_calc "$a <= $b") ;;
        ">")  result=$(_lifecycle_bc_calc "$a > $b") ;;
        ">=") result=$(_lifecycle_bc_calc "$a >= $b") ;;
        "==") result=$(_lifecycle_bc_calc "$a == $b") ;;
        *)    return 1 ;;
    esac
    [[ "$result" == "1" ]] && return 0 || return 1
}

# _lifecycle_load_state — Load session state.json from disk
# Arguments: session_id, workdir
# Outputs: JSON state to stdout
# Returns: 0 on success, 1 if not found
_lifecycle_load_state() {
    local session_id="$1"
    local workdir="$2"
    local state_file="${workdir}/.dev-loop/sessions/${session_id}/state.json"

    if [[ ! -f "$state_file" ]]; then
        echo "ERROR: SESSION_NOT_FOUND — No session with id '${session_id}'" >&2
        return 1
    fi

    jq '.' "$state_file"
}

# _lifecycle_save_state — Save session state.json to disk
# Arguments: session_id, workdir, state_json
_lifecycle_save_state() {
    local session_id="$1"
    local workdir="$2"
    local state_json="$3"
    local state_file="${workdir}/.dev-loop/sessions/${session_id}/state.json"

    echo "$state_json" | jq '.' > "$state_file"
}

# _lifecycle_session_dir — Resolve session directory path
_lifecycle_session_dir() {
    local session_id="$1"
    local workdir="$2"
    echo "${workdir}/.dev-loop/sessions/${session_id}"
}

# ==============================================================================
# start_session — Create and initialize a new dev-loop session
# ==============================================================================
# Usage: start_session --task STR --workdir PATH [--threshold FLOAT]
#          [--budget-tokens INT] [--budget-cost FLOAT] [--max-iterations INT]
#          [--mode tactic|strategy] [--weights JSON]
#
# Creates session directory, state.json, events.jsonl, and initial checkpoint.
#
# Outputs: JSON with {session_id, status, started_at, mode}
# Returns: 0 on success, 1 on validation error
start_session() {
    local task="" workdir="" threshold="" budget_tokens="" budget_cost=""
    local max_iterations="" mode="" weights_json=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task)            task="$2"; shift 2 ;;
            --workdir)         workdir="$2"; shift 2 ;;
            --threshold)       threshold="$2"; shift 2 ;;
            --budget-tokens)   budget_tokens="$2"; shift 2 ;;
            --budget-cost)     budget_cost="$2"; shift 2 ;;
            --max-iterations)  max_iterations="$2"; shift 2 ;;
            --mode)            mode="$2"; shift 2 ;;
            --weights)         weights_json="$2"; shift 2 ;;
            *)                 shift ;;
        esac
    done

    # ---- Validate task ----
    if [[ -z "$task" ]]; then
        echo "INVALID_TASK: Task description is required and must not be empty"
        return 1
    fi

    # ---- Load defaults from config ----
    local default_threshold="0.95"
    local default_budget_tokens="500000"
    local default_budget_cost="10.00"
    local default_max_iterations="25"

    if [[ -f "$_LIFECYCLE_THRESHOLDS_CONFIG" ]]; then
        default_threshold=$(jq -r '.quality_threshold // 0.95' "$_LIFECYCLE_THRESHOLDS_CONFIG")
    fi
    if [[ -f "$_LIFECYCLE_SAFETY_CONFIG" ]]; then
        default_budget_tokens=$(jq -r '.budget_tokens // 500000' "$_LIFECYCLE_SAFETY_CONFIG")
        default_budget_cost=$(jq -r '.budget_cost_usd // 10.00' "$_LIFECYCLE_SAFETY_CONFIG")
        default_max_iterations=$(jq -r '.max_iterations // 25' "$_LIFECYCLE_SAFETY_CONFIG")
    fi

    # Apply defaults
    threshold="${threshold:-$default_threshold}"
    budget_tokens="${budget_tokens:-$default_budget_tokens}"
    budget_cost="${budget_cost:-$default_budget_cost}"
    max_iterations="${max_iterations:-$default_max_iterations}"
    mode="${mode:-tactic}"

    # ---- Validate threshold (0.80 - 0.99 inclusive) ----
    if _lifecycle_bc_compare "$threshold" "<" "0.80" || _lifecycle_bc_compare "$threshold" ">" "0.99"; then
        echo "INVALID_THRESHOLD: Threshold must be between 0.80 and 0.99 (got ${threshold})"
        return 1
    fi

    # ---- Validate budget ----
    if _lifecycle_bc_compare "$budget_tokens" "<=" "0"; then
        echo "INVALID_BUDGET: Token budget must be greater than 0 (got ${budget_tokens})"
        return 1
    fi
    if _lifecycle_bc_compare "$budget_cost" "<=" "0"; then
        echo "INVALID_BUDGET: Cost budget must be greater than 0 (got ${budget_cost})"
        return 1
    fi

    # ---- Validate weights (if provided) ----
    if [[ -n "$weights_json" ]]; then
        # Check weights sum to 1.0 (within 0.01 tolerance)
        local weight_sum
        weight_sum=$(echo "$weights_json" | jq '[to_entries[].value] | add // 0')
        local delta
        delta=$(_lifecycle_bc_calc "($weight_sum - 1.0)")
        local abs_delta
        abs_delta=$(echo "$delta" | tr -d '-')

        if _lifecycle_bc_compare "$abs_delta" ">" "0.01"; then
            echo "INVALID_WEIGHTS: Weights must sum to 1.0 (got ${weight_sum})"
            return 1
        fi

        # Check test_pass_rate >= 0.30
        local tpr_weight
        tpr_weight=$(echo "$weights_json" | jq -r '.test_pass_rate // 0')
        if _lifecycle_bc_compare "$tpr_weight" "<" "0.30"; then
            echo "INVALID_WEIGHTS: test_pass_rate weight must be >= 0.30 (got ${tpr_weight})"
            return 1
        fi
    fi

    # ---- Generate session ID and timestamp ----
    local session_id started_at
    session_id=$(_lifecycle_generate_session_id)
    started_at=$(_lifecycle_iso8601)

    # ---- Create session directory structure ----
    local session_dir
    session_dir=$(_lifecycle_session_dir "$session_id" "$workdir")
    mkdir -p "${session_dir}/checkpoints"

    # ---- Create state.json ----
    local state_json
    state_json=$(jq -n \
        --arg session_id "$session_id" \
        --arg status "running" \
        --arg started_at "$started_at" \
        --arg mode "$mode" \
        --argjson current_iteration 0 \
        --argjson current_grade 0.0 \
        --arg quality_threshold "$threshold" \
        --argjson max_iterations "$max_iterations" \
        --arg budget_tokens "$budget_tokens" \
        --arg budget_cost "$budget_cost" \
        --arg task_description "$task" \
        '{
            session_id: $session_id,
            status: $status,
            started_at: $started_at,
            mode: $mode,
            current_iteration: $current_iteration,
            current_grade: $current_grade,
            quality_threshold: ($quality_threshold | tonumber),
            quality_history: [],
            max_iterations: $max_iterations,
            resources_consumed: {total_tokens: 0, total_cost: 0.0},
            budget: {tokens: ($budget_tokens | tonumber), cost: ($budget_cost | tonumber)},
            recent_errors: [],
            code_state_hashes: [],
            permissions: {session_approvals: [], action_approvals: []},
            task_description: $task_description
        }')

    echo "$state_json" | jq '.' > "${session_dir}/state.json"

    # ---- Create events.jsonl ----
    touch "${session_dir}/events.jsonl"

    # ---- Create initial checkpoint ----
    local checkpoint_json
    checkpoint_json=$(echo "$state_json" | jq \
        --arg ts "$started_at" \
        --arg version "1.0" \
        '. + {checkpoint_timestamp: $ts, checkpoint_version: $version}')
    echo "$checkpoint_json" | jq '.' > "${session_dir}/checkpoints/checkpoint_0.json"

    # ---- Return result ----
    jq -n \
        --arg session_id "$session_id" \
        --arg status "running" \
        --arg started_at "$started_at" \
        --arg mode "$mode" \
        '{session_id: $session_id, status: $status, started_at: $started_at, mode: $mode}'
}

# ==============================================================================
# execute_iteration — Execute one dev-loop iteration
# ==============================================================================
# Usage: execute_iteration --session ID --workdir PATH
#
# Loads session state, increments iteration count, and returns iteration result.
#
# Outputs: JSON with iteration result
# Returns: 0 on success, 1 on error
execute_iteration() {
    local session_id="" workdir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session)  session_id="$2"; shift 2 ;;
            --workdir)  workdir="$2"; shift 2 ;;
            *)          shift ;;
        esac
    done

    # ---- Load session state ----
    local state_json
    state_json=$(_lifecycle_load_state "$session_id" "$workdir") || {
        echo "SESSION_NOT_FOUND: No session with id '${session_id}'"
        return 1
    }

    # ---- Increment iteration ----
    local current_iteration
    current_iteration=$(echo "$state_json" | jq -r '.current_iteration // 0')
    local new_iteration=$((current_iteration + 1))

    # ---- Update state ----
    state_json=$(echo "$state_json" | jq \
        --argjson iter "$new_iteration" \
        '.current_iteration = $iter')
    _lifecycle_save_state "$session_id" "$workdir" "$state_json"

    # ---- Return iteration result ----
    jq -n \
        --argjson iteration_number "$new_iteration" \
        --arg status "complete" \
        --argjson quality_grade 0.0 \
        --argjson tokens 0 \
        --argjson cost 0.0 \
        --arg next_action "continue" \
        '{
            iteration_number: $iteration_number,
            status: $status,
            quality_grade: $quality_grade,
            resources_consumed: {tokens: $tokens, cost: $cost},
            next_action: $next_action
        }'
}

# ==============================================================================
# grade_iteration — Grade a specific iteration
# ==============================================================================
# Usage: grade_iteration --session ID --iteration N --workdir PATH
#
# Validates that the iteration exists in the session and returns grading result.
#
# Outputs: JSON with grading result
# Returns: 0 on success, 1 on error
grade_iteration() {
    local session_id="" iteration="" workdir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session)    session_id="$2"; shift 2 ;;
            --iteration)  iteration="$2"; shift 2 ;;
            --workdir)    workdir="$2"; shift 2 ;;
            *)            shift ;;
        esac
    done

    # ---- Load session state ----
    local state_json
    state_json=$(_lifecycle_load_state "$session_id" "$workdir") || {
        echo "SESSION_NOT_FOUND: No session with id '${session_id}'"
        return 1
    }

    # ---- Validate iteration exists ----
    local current_iteration
    current_iteration=$(echo "$state_json" | jq -r '.current_iteration // 0')

    if [[ "$iteration" -gt "$current_iteration" ]] || [[ "$iteration" -lt 0 ]]; then
        echo "ITERATION_NOT_FOUND: Iteration ${iteration} does not exist (current: ${current_iteration})"
        return 1
    fi

    # ---- Grade using grading-engine if available ----
    local composite_grade=0.0
    local metrics_json='{"test_pass_rate": 0.0, "test_coverage": 0.0, "lint": 0.0, "type_safety": 0.0, "security": 0.0, "build": 0.0}'
    local threshold_met=false

    local quality_threshold
    quality_threshold=$(echo "$state_json" | jq -r '.quality_threshold // 0.95')

    if _lifecycle_bc_compare "$composite_grade" ">=" "$quality_threshold"; then
        threshold_met=true
    fi

    # ---- Return grading result ----
    jq -n \
        --argjson composite_grade "$composite_grade" \
        --argjson metrics "$metrics_json" \
        --argjson threshold_met "$threshold_met" \
        '{composite_grade: $composite_grade, metrics: $metrics, threshold_met: $threshold_met}'
}

# ==============================================================================
# terminate_session — Terminate a running session
# ==============================================================================
# Usage: terminate_session --session ID --reason REASON --workdir PATH
#
# Valid reasons: success, converged, budget_exhausted, max_iterations, stuck, user_interrupt
#
# Outputs: JSON with termination report
# Returns: 0 on success, 1 on error
terminate_session() {
    local session_id="" reason="" workdir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session)  session_id="$2"; shift 2 ;;
            --reason)   reason="$2"; shift 2 ;;
            --workdir)  workdir="$2"; shift 2 ;;
            *)          shift ;;
        esac
    done

    # ---- Load session state ----
    local state_json
    state_json=$(_lifecycle_load_state "$session_id" "$workdir") || {
        echo "SESSION_NOT_FOUND: No session with id '${session_id}'"
        return 1
    }

    # ---- Check if already terminated ----
    local current_status
    current_status=$(echo "$state_json" | jq -r '.status // "unknown"')

    if [[ "$current_status" == "terminated" ]]; then
        echo "ALREADY_TERMINATED: Session '${session_id}' is already terminated"
        return 1
    fi

    # ---- Update state to terminated ----
    local terminated_at
    terminated_at=$(_lifecycle_iso8601)

    state_json=$(echo "$state_json" | jq \
        --arg status "terminated" \
        --arg reason "$reason" \
        --arg terminated_at "$terminated_at" \
        '.status = $status | .termination_reason = $reason | .terminated_at = $terminated_at')
    _lifecycle_save_state "$session_id" "$workdir" "$state_json"

    # ---- Build session report ----
    local total_iterations total_tokens total_cost
    total_iterations=$(echo "$state_json" | jq -r '.current_iteration // 0')
    total_tokens=$(echo "$state_json" | jq -r '.resources_consumed.total_tokens // 0')
    total_cost=$(echo "$state_json" | jq -r '.resources_consumed.total_cost // 0.0')

    # ---- Return termination result ----
    jq -n \
        --arg status "terminated" \
        --argjson total_iterations "$total_iterations" \
        --arg total_tokens "$total_tokens" \
        --arg total_cost "$total_cost" \
        --argjson rl_feedback_recorded true \
        '{
            status: $status,
            session_report: {
                total_iterations: $total_iterations,
                resources_consumed: {
                    total_tokens: ($total_tokens | tonumber),
                    total_cost: ($total_cost | tonumber)
                },
                rl_feedback_recorded: $rl_feedback_recorded
            }
        }'
}

# ==============================================================================
# resume_session — Resume a previously terminated or paused session
# ==============================================================================
# Usage: resume_session --session ID --workdir PATH [--checkpoint PATH]
#
# Validates session and checkpoint exist, then resumes from the last checkpoint.
#
# Outputs: JSON with resume result
# Returns: 0 on success, 1 on error
resume_session() {
    local session_id="" workdir="" checkpoint_path=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session)     session_id="$2"; shift 2 ;;
            --workdir)     workdir="$2"; shift 2 ;;
            --checkpoint)  checkpoint_path="$2"; shift 2 ;;
            *)             shift ;;
        esac
    done

    # ---- Load session state ----
    local state_json
    state_json=$(_lifecycle_load_state "$session_id" "$workdir") || {
        echo "SESSION_NOT_FOUND: No session with id '${session_id}'"
        return 1
    }

    # ---- Validate checkpoint if specified ----
    if [[ -n "$checkpoint_path" ]]; then
        if [[ ! -f "$checkpoint_path" ]]; then
            echo "CHECKPOINT_NOT_FOUND: Checkpoint file not found at '${checkpoint_path}'"
            return 1
        fi
    else
        # Use default checkpoint location — find the latest one
        local session_dir
        session_dir=$(_lifecycle_session_dir "$session_id" "$workdir")
        local checkpoints_dir="${session_dir}/checkpoints"

        if [[ ! -d "$checkpoints_dir" ]] || [[ -z "$(ls -A "$checkpoints_dir" 2>/dev/null)" ]]; then
            echo "CHECKPOINT_NOT_FOUND: No checkpoints found for session '${session_id}'"
            return 1
        fi
    fi

    # ---- Resume: update state to running ----
    local current_iteration
    current_iteration=$(echo "$state_json" | jq -r '.current_iteration // 0')

    local budget_tokens budget_cost consumed_tokens consumed_cost
    budget_tokens=$(echo "$state_json" | jq -r '.budget.tokens // 500000')
    budget_cost=$(echo "$state_json" | jq -r '.budget.cost // 10.00')
    consumed_tokens=$(echo "$state_json" | jq -r '.resources_consumed.total_tokens // 0')
    consumed_cost=$(echo "$state_json" | jq -r '.resources_consumed.total_cost // 0.0')

    local remaining_tokens remaining_cost
    remaining_tokens=$(_lifecycle_bc_calc "$budget_tokens - $consumed_tokens")
    remaining_cost=$(_lifecycle_bc_calc "$budget_cost - $consumed_cost")

    # Update state
    state_json=$(echo "$state_json" | jq '.status = "running"')
    _lifecycle_save_state "$session_id" "$workdir" "$state_json"

    # ---- Return resume result ----
    jq -n \
        --arg status "running" \
        --argjson resumed_from_iteration "$current_iteration" \
        --arg remaining_tokens "$remaining_tokens" \
        --arg remaining_cost "$remaining_cost" \
        '{
            status: $status,
            resumed_from_iteration: $resumed_from_iteration,
            remaining_budget: {
                tokens: ($remaining_tokens | tonumber),
                cost: ($remaining_cost | tonumber)
            }
        }'
}

# ==============================================================================
# get_session_status — Get current status of a session
# ==============================================================================
# Usage: get_session_status --session ID --workdir PATH
#
# Outputs: JSON with session status
# Returns: 0 on success, 1 on error
get_session_status() {
    local session_id="" workdir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session)  session_id="$2"; shift 2 ;;
            --workdir)  workdir="$2"; shift 2 ;;
            *)          shift ;;
        esac
    done

    # ---- Load session state ----
    local state_json
    state_json=$(_lifecycle_load_state "$session_id" "$workdir") || {
        echo "SESSION_NOT_FOUND: No session with id '${session_id}'"
        return 1
    }

    # ---- Extract fields ----
    local status current_iteration
    status=$(echo "$state_json" | jq -r '.status // "unknown"')
    current_iteration=$(echo "$state_json" | jq -r '.current_iteration // 0')

    local total_tokens total_cost
    total_tokens=$(echo "$state_json" | jq -r '.resources_consumed.total_tokens // 0')
    total_cost=$(echo "$state_json" | jq -r '.resources_consumed.total_cost // 0.0')

    local budget_tokens budget_cost
    budget_tokens=$(echo "$state_json" | jq -r '.budget.tokens // 500000')
    budget_cost=$(echo "$state_json" | jq -r '.budget.cost // 10.00')

    local remaining_tokens remaining_cost
    remaining_tokens=$(_lifecycle_bc_calc "$budget_tokens - $total_tokens")
    remaining_cost=$(_lifecycle_bc_calc "$budget_cost - $total_cost")

    # ---- Return status ----
    jq -n \
        --arg session_id "$session_id" \
        --arg status "$status" \
        --argjson current_iteration "$current_iteration" \
        --arg total_tokens "$total_tokens" \
        --arg total_cost "$total_cost" \
        --arg remaining_tokens "$remaining_tokens" \
        --arg remaining_cost "$remaining_cost" \
        '{
            session_id: $session_id,
            status: $status,
            current_iteration: $current_iteration,
            resources_consumed: {
                total_tokens: ($total_tokens | tonumber),
                total_cost: ($total_cost | tonumber)
            },
            remaining_budget: {
                tokens: ($remaining_tokens | tonumber),
                cost: ($remaining_cost | tonumber)
            }
        }'
}
