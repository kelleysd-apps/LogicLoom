#!/usr/bin/env bash
# termination-engine.sh — Termination condition engine for sdd-dev-loop plugin
#
# Evaluates a 6-layer termination hierarchy to determine when a dev-loop
# session should stop. Layers are evaluated in strict priority order and
# the first triggered condition wins.
#
# Termination Priority (FR-022):
#   1. Success:        composite grade >= quality threshold
#   2. Convergence:    grade delta < convergence_delta for convergence_window iterations
#   3. Budget:         tokens > budget_tokens OR cost > budget_cost
#   4. Max iterations: iteration_count > max_iterations
#   5. Stuck:          same error 3+ times OR oscillation detected
#   6. User interrupt: SIGINT received
#
# This file is designed to be sourced, not executed directly.
#
# Dependencies: bc (floating-point arithmetic), jq (JSON parsing)
# Constitutional Principle VII: Observability — termination reasons are structured

set -euo pipefail

# ==============================================================================
# Plugin Directory Resolution
# ==============================================================================

if [[ -z "${PLUGIN_DIR:-}" ]]; then
    PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Config paths
_TERM_THRESHOLDS_CONFIG="${PLUGIN_DIR}/config/thresholds.json"
_TERM_SAFETY_CONFIG="${PLUGIN_DIR}/config/safety-limits.json"

# Module-level state for user interrupt detection
_DEVLOOP_USER_INTERRUPTED=false

# ==============================================================================
# Internal Helpers
# ==============================================================================

# _term_bc_calc — Evaluate a floating-point expression via bc
_term_bc_calc() {
    echo "$1" | bc -l 2>/dev/null || echo "0"
}

# _term_bc_compare — Compare two floating-point numbers
# Returns: 0 (true) or 1 (false)
_term_bc_compare() {
    local a="$1" op="$2" b="$3"
    local result
    case "$op" in
        "<")  result=$(_term_bc_calc "$a < $b") ;;
        "<=") result=$(_term_bc_calc "$a <= $b") ;;
        ">")  result=$(_term_bc_calc "$a > $b") ;;
        ">=") result=$(_term_bc_calc "$a >= $b") ;;
        "==") result=$(_term_bc_calc "$a == $b") ;;
        *)    echo "ERROR: Unknown operator: $op" >&2; return 1 ;;
    esac
    [[ "$result" == "1" ]] && return 0 || return 1
}

# _setup_interrupt_handler — Register SIGINT trap for user interrupt detection
# Usage: Call once at session start
_setup_interrupt_handler() {
    trap '_DEVLOOP_USER_INTERRUPTED=true' INT
}

# ==============================================================================
# check_convergence — Check if quality grades have converged
# ==============================================================================
# Usage: check_convergence <grades_json_array>
#
# Grades have converged when the absolute difference between consecutive
# grades is less than convergence_delta for the last convergence_window
# iterations.
#
# Arguments:
#   grades_json_array — JSON array of recent composite grades (floats), e.g. [0.89, 0.891, 0.8912]
#
# Outputs: JSON object with convergence analysis:
#   {"converged": true/false, "window": N, "delta": <max_delta>, "threshold": <convergence_delta>}
# Returns: 0 if converged, 1 if not converged
check_convergence() {
    local grades_json="$1"

    # Load convergence config
    local conv_delta conv_window
    if [[ -f "$_TERM_THRESHOLDS_CONFIG" ]]; then
        conv_delta=$(jq -r '.convergence_delta' "$_TERM_THRESHOLDS_CONFIG")
        conv_window=$(jq -r '.convergence_window' "$_TERM_THRESHOLDS_CONFIG")
    else
        conv_delta="${DEVLOOP_CONVERGENCE_DELTA:-0.001}"
        conv_window="${DEVLOOP_CONVERGENCE_WINDOW:-3}"
    fi

    # Count grades
    local grade_count
    grade_count=$(echo "$grades_json" | jq 'length')

    # Need at least convergence_window + 1 grades to check window deltas
    if [[ "$grade_count" -lt $((conv_window + 1)) ]]; then
        jq -n \
            --argjson converged false \
            --argjson window "$conv_window" \
            --arg delta "N/A" \
            --arg threshold "$conv_delta" \
            --arg reason "insufficient_data" \
            '{converged: $converged, window: $window, delta: $delta, threshold: ($threshold | tonumber), reason: $reason}'
        return 1
    fi

    # Check the last conv_window consecutive deltas
    # We need the last (conv_window + 1) grades to compute conv_window deltas
    local max_delta="0"
    local all_below=true

    for ((i = grade_count - conv_window; i < grade_count; i++)); do
        local prev_idx=$((i - 1))
        local curr prev delta abs_delta
        curr=$(echo "$grades_json" | jq ".[$i]")
        prev=$(echo "$grades_json" | jq ".[$prev_idx]")
        delta=$(_term_bc_calc "$curr - $prev")
        abs_delta=$(echo "$delta" | tr -d '-')

        if _term_bc_compare "$abs_delta" ">" "$max_delta"; then
            max_delta="$abs_delta"
        fi

        if _term_bc_compare "$abs_delta" ">=" "$conv_delta"; then
            all_below=false
        fi
    done

    local converged
    if [[ "$all_below" == "true" ]]; then
        converged=true
    else
        converged=false
    fi

    jq -n \
        --argjson converged "$converged" \
        --argjson window "$conv_window" \
        --arg delta "$max_delta" \
        --arg threshold "$conv_delta" \
        '{converged: $converged, window: $window, delta: ($delta | tonumber), threshold: ($threshold | tonumber)}'

    if [[ "$converged" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# ==============================================================================
# check_budget — Check if session has exceeded token or cost budget
# ==============================================================================
# Usage: check_budget <session_state_json>
#
# Checks:
#   - tokens_spent > budget_tokens
#   - cost_spent > budget_cost_usd
#
# Arguments:
#   session_state_json — JSON object with fields:
#     {"tokens_spent": N, "cost_spent": F, "budget_tokens": N, "budget_cost_usd": F}
#     If budget fields are omitted, defaults are loaded from config/safety-limits.json
#
# Outputs: JSON object with budget analysis:
#   {"exhausted": true/false, "reason": "tokens"|"cost"|null, "details": {...}}
# Returns: 0 if budget exhausted, 1 if within budget
check_budget() {
    local session_json="$1"

    # Extract values with fallback to config defaults
    local tokens_spent cost_spent budget_tokens budget_cost

    tokens_spent=$(echo "$session_json" | jq -r '.tokens_spent // 0')
    cost_spent=$(echo "$session_json" | jq -r '.cost_spent // 0')

    # Load budget limits from session or config
    budget_tokens=$(echo "$session_json" | jq -r '.budget_tokens // null')
    budget_cost=$(echo "$session_json" | jq -r '.budget_cost_usd // null')

    if [[ "$budget_tokens" == "null" ]] && [[ -f "$_TERM_SAFETY_CONFIG" ]]; then
        budget_tokens=$(jq -r '.budget_tokens' "$_TERM_SAFETY_CONFIG")
    fi
    if [[ "$budget_cost" == "null" ]] && [[ -f "$_TERM_SAFETY_CONFIG" ]]; then
        budget_cost=$(jq -r '.budget_cost_usd' "$_TERM_SAFETY_CONFIG")
    fi

    # Default fallbacks
    budget_tokens="${budget_tokens:-500000}"
    budget_cost="${budget_cost:-10.00}"

    # Check token budget
    if _term_bc_compare "$tokens_spent" ">" "$budget_tokens"; then
        local token_pct
        token_pct=$(_term_bc_calc "($tokens_spent / $budget_tokens) * 100")
        jq -n \
            --argjson exhausted true \
            --arg reason "tokens" \
            --arg tokens_spent "$tokens_spent" \
            --arg budget_tokens "$budget_tokens" \
            --arg usage_pct "$token_pct" \
            '{exhausted: $exhausted, reason: $reason, details: {tokens_spent: ($tokens_spent | tonumber), budget_tokens: ($budget_tokens | tonumber), usage_pct: ($usage_pct | tonumber)}}'
        return 0
    fi

    # Check cost budget
    if _term_bc_compare "$cost_spent" ">" "$budget_cost"; then
        local cost_pct
        cost_pct=$(_term_bc_calc "($cost_spent / $budget_cost) * 100")
        jq -n \
            --argjson exhausted true \
            --arg reason "cost" \
            --arg cost_spent "$cost_spent" \
            --arg budget_cost "$budget_cost" \
            --arg usage_pct "$cost_pct" \
            '{exhausted: $exhausted, reason: $reason, details: {cost_spent: ($cost_spent | tonumber), budget_cost: ($budget_cost | tonumber), usage_pct: ($usage_pct | tonumber)}}'
        return 0
    fi

    # Within budget
    jq -n \
        --argjson exhausted false \
        --arg tokens_spent "$tokens_spent" \
        --arg budget_tokens "$budget_tokens" \
        --arg cost_spent "$cost_spent" \
        --arg budget_cost "$budget_cost" \
        '{exhausted: $exhausted, reason: null, details: {tokens_spent: ($tokens_spent | tonumber), budget_tokens: ($budget_tokens | tonumber), cost_spent: ($cost_spent | tonumber), budget_cost: ($budget_cost | tonumber)}}'
    return 1
}

# ==============================================================================
# check_oscillation — Detect oscillating code states via hash comparison
# ==============================================================================
# Usage: check_oscillation <hashes_json_array>
#
# Oscillation is detected when a code state hash appears more than once
# in the recent history, indicating the loop is flip-flopping between states.
#
# Arguments:
#   hashes_json_array — JSON array of code state hashes (strings), e.g.
#     ["abc123", "def456", "abc123", "def456"]
#
# Outputs: JSON object:
#   {"oscillating": true/false, "repeated_hash": "...", "occurrences": N}
# Returns: 0 if oscillation detected, 1 if no oscillation
check_oscillation() {
    local hashes_json="$1"

    # Use jq to find any hash that appears 2+ times
    local repeated
    repeated=$(echo "$hashes_json" | jq -r '
        group_by(.) |
        map(select(length > 1)) |
        if length > 0 then
            .[0] | {repeated_hash: .[0], occurrences: length}
        else
            {repeated_hash: null, occurrences: 0}
        end
    ')

    local repeated_hash occurrences
    repeated_hash=$(echo "$repeated" | jq -r '.repeated_hash')
    occurrences=$(echo "$repeated" | jq -r '.occurrences')

    if [[ "$repeated_hash" != "null" && "$occurrences" -ge 2 ]]; then
        jq -n \
            --argjson oscillating true \
            --arg repeated_hash "$repeated_hash" \
            --argjson occurrences "$occurrences" \
            '{oscillating: $oscillating, repeated_hash: $repeated_hash, occurrences: $occurrences}'
        return 0
    else
        jq -n \
            --argjson oscillating false \
            '{oscillating: $oscillating, repeated_hash: null, occurrences: 0}'
        return 1
    fi
}

# ==============================================================================
# check_stuck — Detect repeated identical errors
# ==============================================================================
# Usage: check_stuck <errors_json_array>
#
# Stuck is detected when the same error message appears 3 or more consecutive
# times in the recent error history, indicating no progress is being made.
#
# Arguments:
#   errors_json_array — JSON array of recent error strings, e.g.
#     ["TypeError: x is not a function", "TypeError: x is not a function", "TypeError: x is not a function"]
#
# Outputs: JSON object:
#   {"stuck": true/false, "repeated_error": "...", "consecutive_count": N}
# Returns: 0 if stuck detected, 1 if not stuck
check_stuck() {
    local errors_json="$1"
    local stuck_threshold="${DEVLOOP_STUCK_THRESHOLD:-3}"

    local error_count
    error_count=$(echo "$errors_json" | jq 'length')

    if [[ "$error_count" -lt "$stuck_threshold" ]]; then
        jq -n \
            --argjson stuck false \
            '{stuck: $stuck, repeated_error: null, consecutive_count: 0}'
        return 1
    fi

    # Check for consecutive identical errors from the end of the array
    local last_error consecutive_count
    last_error=$(echo "$errors_json" | jq -r '.[-1]')
    consecutive_count=0

    for ((i = error_count - 1; i >= 0; i--)); do
        local current_error
        current_error=$(echo "$errors_json" | jq -r ".[$i]")
        if [[ "$current_error" == "$last_error" ]]; then
            consecutive_count=$((consecutive_count + 1))
        else
            break
        fi
    done

    if [[ "$consecutive_count" -ge "$stuck_threshold" ]]; then
        jq -n \
            --argjson stuck true \
            --arg repeated_error "$last_error" \
            --argjson consecutive_count "$consecutive_count" \
            '{stuck: $stuck, repeated_error: $repeated_error, consecutive_count: $consecutive_count}'
        return 0
    else
        jq -n \
            --argjson stuck false \
            --argjson consecutive_count "$consecutive_count" \
            '{stuck: $stuck, repeated_error: null, consecutive_count: $consecutive_count}'
        return 1
    fi
}

# ==============================================================================
# check_all_layers — Evaluate all 6 termination layers in priority order
# ==============================================================================
# Usage: check_all_layers <session_state_json>
#
# Evaluates termination conditions in strict priority order. The first
# triggered condition is returned immediately (short-circuit evaluation).
#
# Arguments:
#   session_state_json — JSON object containing full session state:
#     {
#       "composite_grade": 0.89,
#       "quality_grades": [0.72, 0.81, 0.89],
#       "iteration_count": 3,
#       "tokens_spent": 125000,
#       "cost_spent": 3.75,
#       "budget_tokens": 500000,
#       "budget_cost_usd": 15.00,
#       "max_iterations": 25,
#       "recent_errors": ["err1", "err1", "err1"],
#       "code_state_hashes": ["abc", "def", "abc"]
#     }
#
# Outputs: JSON object with termination result:
#   {
#     "should_terminate": true/false,
#     "reason": "success"|"converged"|"budget_exhausted"|"max_iterations"|"stuck"|"user_interrupt"|null,
#     "layer": 1-6,
#     "details": {...}
#   }
# Returns: 0 if should terminate, 1 if should continue
check_all_layers() {
    local session_json="$1"

    # Extract fields
    local composite_grade quality_grades iteration_count max_iterations
    local recent_errors code_hashes

    composite_grade=$(echo "$session_json" | jq -r '.composite_grade // 0')
    quality_grades=$(echo "$session_json" | jq -c '.quality_grades // []')
    iteration_count=$(echo "$session_json" | jq -r '.iteration_count // 0')
    recent_errors=$(echo "$session_json" | jq -c '.recent_errors // []')
    code_hashes=$(echo "$session_json" | jq -c '.code_state_hashes // []')

    # Load max_iterations from session or config
    max_iterations=$(echo "$session_json" | jq -r '.max_iterations // null')
    if [[ "$max_iterations" == "null" ]] && [[ -f "$_TERM_SAFETY_CONFIG" ]]; then
        max_iterations=$(jq -r '.max_iterations' "$_TERM_SAFETY_CONFIG")
    fi
    max_iterations="${max_iterations:-25}"

    # Load quality threshold
    local quality_threshold
    quality_threshold=$(echo "$session_json" | jq -r '.quality_threshold // null')
    if [[ "$quality_threshold" == "null" ]] && [[ -f "$_TERM_THRESHOLDS_CONFIG" ]]; then
        quality_threshold=$(jq -r '.quality_threshold' "$_TERM_THRESHOLDS_CONFIG")
    fi
    quality_threshold="${quality_threshold:-0.95}"

    # ---- Layer 1: Success (grade >= threshold) ----
    if _term_bc_compare "$composite_grade" ">=" "$quality_threshold"; then
        jq -n \
            --argjson should_terminate true \
            --arg reason "success" \
            --argjson layer 1 \
            --arg grade "$composite_grade" \
            --arg threshold "$quality_threshold" \
            '{should_terminate: $should_terminate, reason: $reason, layer: $layer, details: {grade: ($grade | tonumber), threshold: ($threshold | tonumber)}}'
        return 0
    fi

    # ---- Layer 2: Convergence ----
    local conv_result
    if conv_result=$(check_convergence "$quality_grades" 2>/dev/null); then
        jq -n \
            --argjson should_terminate true \
            --arg reason "converged" \
            --argjson layer 2 \
            --argjson details "$conv_result" \
            '{should_terminate: $should_terminate, reason: $reason, layer: $layer, details: $details}'
        return 0
    fi

    # ---- Layer 3: Budget exhausted ----
    local budget_result
    if budget_result=$(check_budget "$session_json" 2>/dev/null); then
        jq -n \
            --argjson should_terminate true \
            --arg reason "budget_exhausted" \
            --argjson layer 3 \
            --argjson details "$budget_result" \
            '{should_terminate: $should_terminate, reason: $reason, layer: $layer, details: $details}'
        return 0
    fi

    # ---- Layer 4: Max iterations ----
    if [[ "$iteration_count" -gt "$max_iterations" ]]; then
        jq -n \
            --argjson should_terminate true \
            --arg reason "max_iterations" \
            --argjson layer 4 \
            --argjson iteration "$iteration_count" \
            --argjson max "$max_iterations" \
            '{should_terminate: $should_terminate, reason: $reason, layer: $layer, details: {iteration: $iteration, max_iterations: $max}}'
        return 0
    fi

    # ---- Layer 5: Stuck (repeated errors or oscillation) ----
    local stuck_result oscillation_result
    if stuck_result=$(check_stuck "$recent_errors" 2>/dev/null); then
        jq -n \
            --argjson should_terminate true \
            --arg reason "stuck" \
            --argjson layer 5 \
            --argjson details "$stuck_result" \
            '{should_terminate: $should_terminate, reason: $reason, layer: $layer, details: ($details + {type: "repeated_error"})}'
        return 0
    fi

    if oscillation_result=$(check_oscillation "$code_hashes" 2>/dev/null); then
        jq -n \
            --argjson should_terminate true \
            --arg reason "stuck" \
            --argjson layer 5 \
            --argjson details "$oscillation_result" \
            '{should_terminate: $should_terminate, reason: $reason, layer: $layer, details: ($details + {type: "oscillation"})}'
        return 0
    fi

    # ---- Layer 6: User interrupt ----
    if [[ "$_DEVLOOP_USER_INTERRUPTED" == "true" ]]; then
        jq -n \
            --argjson should_terminate true \
            --arg reason "user_interrupt" \
            --argjson layer 6 \
            '{should_terminate: $should_terminate, reason: $reason, layer: $layer, details: {signal: "SIGINT"}}'
        return 0
    fi

    # ---- No termination condition triggered ----
    jq -n \
        --argjson should_terminate false \
        --argjson iteration "$iteration_count" \
        --arg grade "$composite_grade" \
        --arg threshold "$quality_threshold" \
        '{should_terminate: $should_terminate, reason: null, layer: null, details: {iteration: ($iteration), grade: ($grade | tonumber), threshold: ($threshold | tonumber)}}'
    return 1
}

# ==============================================================================
# save_checkpoint — Serialize session state to a JSON checkpoint file
# ==============================================================================
# Usage: save_checkpoint <session_state_json> <checkpoint_path>
#
# Saves the full session state to a JSON file for later resumption.
# Creates parent directories if they do not exist. Adds a checkpoint
# timestamp and version marker.
#
# Arguments:
#   session_state_json — JSON string with full session state
#   checkpoint_path    — Absolute file path for the checkpoint
#
# Outputs: checkpoint file path on success
# Returns: 0 on success, 1 on failure
save_checkpoint() {
    local session_json="$1"
    local checkpoint_path="$2"

    # Create parent directory if needed
    local parent_dir
    parent_dir=$(dirname "$checkpoint_path")
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir"
    fi

    # Add checkpoint metadata
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local checkpoint_json
    checkpoint_json=$(echo "$session_json" | jq \
        --arg ts "$timestamp" \
        --arg version "1.0" \
        '. + {checkpoint_timestamp: $ts, checkpoint_version: $version}')

    # Write atomically (write to temp, then move)
    local tmp_file="${checkpoint_path}.tmp"
    echo "$checkpoint_json" > "$tmp_file"

    # Validate the JSON before finalizing
    if ! jq empty "$tmp_file" 2>/dev/null; then
        echo "ERROR: Generated checkpoint is not valid JSON" >&2
        rm -f "$tmp_file"
        return 1
    fi

    mv "$tmp_file" "$checkpoint_path"
    echo "$checkpoint_path"
    return 0
}

# ==============================================================================
# load_checkpoint — Deserialize session state from a JSON checkpoint file
# ==============================================================================
# Usage: load_checkpoint <checkpoint_path>
#
# Loads a previously saved checkpoint file and outputs the session state.
# Validates that the file contains valid JSON before returning.
#
# Arguments:
#   checkpoint_path — Absolute file path to the checkpoint
#
# Outputs: JSON session state to stdout
# Returns: 0 on success, 1 on failure (file missing or invalid JSON)
load_checkpoint() {
    local checkpoint_path="$1"

    if [[ ! -f "$checkpoint_path" ]]; then
        echo "ERROR: Checkpoint file not found: $checkpoint_path" >&2
        return 1
    fi

    # Validate JSON
    if ! jq empty "$checkpoint_path" 2>/dev/null; then
        echo "ERROR: Checkpoint file is not valid JSON: $checkpoint_path" >&2
        return 1
    fi

    # Output the checkpoint data
    jq '.' "$checkpoint_path"
    return 0
}
