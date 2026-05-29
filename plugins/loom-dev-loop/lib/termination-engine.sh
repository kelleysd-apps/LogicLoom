#!/usr/bin/env bash
# termination-engine.sh — Termination condition engine for loom-dev-loop plugin
#
# Evaluates a 6-layer termination hierarchy to determine when a dev-loop
# session should stop. Layers are evaluated in strict priority order and
# the first triggered condition wins.
#
# Termination Priority (FR-022):
#   1. Success:        composite grade >= quality threshold
#   2. Convergence:    grade delta < convergence_delta for convergence_window iterations
#   3. Budget:         tokens > budget_tokens OR cost > budget_cost
#   4. Max iterations: iteration_count >= max_iterations
#   5. Stuck:          same error 3+ times OR oscillation detected
#   6. User interrupt: SIGINT received
#
# All public functions use flag-style arguments: --session ID --workdir PATH
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

_term_bc_calc() {
    echo "$1" | bc -l 2>/dev/null || echo "0"
}

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

_setup_interrupt_handler() {
    trap '_DEVLOOP_USER_INTERRUPTED=true' INT
}

# _term_load_state — Load session state from disk
# Returns: JSON to stdout, exit 1 if not found
_term_load_state() {
    local session_id="$1" workdir="$2"
    local state_file="${workdir}/.dev-loop/sessions/${session_id}/state.json"
    if [[ ! -f "$state_file" ]]; then
        return 1
    fi
    cat "$state_file"
}

# ==============================================================================
# check_convergence — Check if quality grades have converged
# ==============================================================================
# Usage: check_convergence --grades '[...]' --delta 0.001 --consecutive 3
#
# Outputs: JSON with convergence analysis
# Returns: 0 if converged, 1 if not
check_convergence() {
    local grades_json="" conv_delta="" consecutive=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --grades)      grades_json="$2"; shift 2 ;;
            --delta)       conv_delta="$2"; shift 2 ;;
            --consecutive) consecutive="$2"; shift 2 ;;
            *)             shift ;;
        esac
    done

    # Validate delta > 0
    if [[ -n "$conv_delta" ]]; then
        local delta_valid
        delta_valid=$(_term_bc_calc "$conv_delta > 0")
        if [[ "$delta_valid" != "1" ]]; then
            echo "INVALID_DELTA: delta must be positive, got ${conv_delta}"
            return 1
        fi
    fi

    # Defaults from config
    if [[ -z "$conv_delta" ]]; then
        if [[ -f "$_TERM_THRESHOLDS_CONFIG" ]]; then
            conv_delta=$(jq -r '.convergence_delta' "$_TERM_THRESHOLDS_CONFIG")
        else
            conv_delta="${DEVLOOP_CONVERGENCE_DELTA:-0.001}"
        fi
    fi
    if [[ -z "$consecutive" ]]; then
        if [[ -f "$_TERM_THRESHOLDS_CONFIG" ]]; then
            consecutive=$(jq -r '.convergence_window' "$_TERM_THRESHOLDS_CONFIG")
        else
            consecutive="${DEVLOOP_CONVERGENCE_WINDOW:-3}"
        fi
    fi

    local grade_count
    grade_count=$(echo "$grades_json" | jq 'length')

    # Need at least consecutive grades to compute deltas
    if [[ "$grade_count" -lt "$consecutive" ]]; then
        echo "INSUFFICIENT_DATA: need at least ${consecutive} grades, got ${grade_count}"
        return 1
    fi

    # Compute deltas between the last consecutive grades
    # consecutive=3 means look at 3 grades, producing 2 deltas
    local num_deltas=$((consecutive - 1))
    local sum_improvement="0"
    local all_below=true
    local improvements_json="["
    local delta_idx=0

    for ((i = grade_count - consecutive + 1; i < grade_count; i++)); do
        local prev_idx=$((i - 1))
        local curr prev delta abs_delta
        curr=$(echo "$grades_json" | jq ".[$i]")
        prev=$(echo "$grades_json" | jq ".[$prev_idx]")
        delta=$(_term_bc_calc "$curr - $prev")
        abs_delta=$(echo "$delta" | tr -d '-')

        [[ $delta_idx -gt 0 ]] && improvements_json="${improvements_json},"
        improvements_json="${improvements_json}${abs_delta}"
        delta_idx=$((delta_idx + 1))
        sum_improvement=$(_term_bc_calc "$sum_improvement + $abs_delta")

        if _term_bc_compare "$abs_delta" ">" "$conv_delta"; then
            all_below=false
        fi
    done
    improvements_json="${improvements_json}]"

    local avg_improvement
    avg_improvement=$(_term_bc_calc "$sum_improvement / $num_deltas")

    local converged
    if [[ "$all_below" == "true" ]]; then
        converged=true
    else
        converged=false
    fi

    jq -n \
        --argjson converged "$converged" \
        --argjson last_improvements "$improvements_json" \
        --arg average_improvement "$avg_improvement" \
        '{converged: $converged, last_improvements: $last_improvements, average_improvement: ($average_improvement | tonumber)}'

    if [[ "$converged" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# ==============================================================================
# check_budget — Check if session has exceeded token or cost budget
# ==============================================================================
# Usage: check_budget --session ID --workdir PATH
#
# Outputs: JSON with budget analysis including budget_status
# Returns: 0 if budget exhausted, 1 if within budget
check_budget() {
    local session_id="" workdir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session) session_id="$2"; shift 2 ;;
            --workdir) workdir="$2"; shift 2 ;;
            *)         shift ;;
        esac
    done

    # Load session state
    local state_json
    state_json=$(_term_load_state "$session_id" "$workdir") || {
        echo "SESSION_NOT_FOUND: No session with id '${session_id}'"
        return 1
    }

    # Extract resource consumption
    local tokens_spent cost_spent budget_tokens budget_cost
    tokens_spent=$(echo "$state_json" | jq -r '.resources_consumed.total_tokens // 0')
    cost_spent=$(echo "$state_json" | jq -r '.resources_consumed.total_cost // 0')
    budget_tokens=$(echo "$state_json" | jq -r '.budget.tokens // 500000')
    budget_cost=$(echo "$state_json" | jq -r '.budget.cost // 10.00')

    # Calculate remaining and percent used
    local tokens_remaining cost_remaining tokens_pct cost_pct
    tokens_remaining=$(_term_bc_calc "$budget_tokens - $tokens_spent")
    cost_remaining=$(_term_bc_calc "$budget_cost - $cost_spent")
    tokens_pct=$(_term_bc_calc "($tokens_spent / $budget_tokens) * 100")
    cost_pct=$(_term_bc_calc "($cost_spent / $budget_cost) * 100")

    # Check if budget exhausted
    local exhausted=false
    if _term_bc_compare "$tokens_spent" ">" "$budget_tokens"; then
        exhausted=true
    elif _term_bc_compare "$cost_spent" ">" "$budget_cost"; then
        exhausted=true
    fi

    jq -n \
        --argjson budget_exhausted "$exhausted" \
        --arg tokens_spent "$tokens_spent" \
        --arg budget_tokens "$budget_tokens" \
        --arg tokens_remaining "$tokens_remaining" \
        --arg tokens_pct "$tokens_pct" \
        --arg cost_spent "$cost_spent" \
        --arg budget_cost "$budget_cost" \
        --arg cost_remaining "$cost_remaining" \
        --arg cost_pct "$cost_pct" \
        '{
            budget_exhausted: $budget_exhausted,
            budget_status: {
                tokens: {
                    spent: ($tokens_spent | tonumber),
                    limit: ($budget_tokens | tonumber),
                    remaining: ($tokens_remaining | tonumber),
                    percent_used: ($tokens_pct | tonumber)
                },
                cost: {
                    spent: ($cost_spent | tonumber),
                    limit: ($budget_cost | tonumber),
                    remaining: ($cost_remaining | tonumber),
                    percent_used: ($cost_pct | tonumber)
                }
            }
        }'

    if [[ "$exhausted" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# ==============================================================================
# check_oscillation — Detect oscillating code states via hash comparison
# ==============================================================================
# Usage: check_oscillation --session ID --workdir PATH
#
# Reads state_hashes.json from session directory.
# Outputs: JSON with oscillation analysis
# Returns: 0 if oscillation detected, 1 if not
check_oscillation() {
    local session_id="" workdir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session) session_id="$2"; shift 2 ;;
            --workdir) workdir="$2"; shift 2 ;;
            *)         shift ;;
        esac
    done

    # Verify session exists
    local sess_dir="${workdir}/.dev-loop/sessions/${session_id}"
    if [[ ! -d "$sess_dir" ]]; then
        echo "SESSION_NOT_FOUND: No session with id '${session_id}'"
        return 1
    fi

    local hashes_file="${sess_dir}/state_hashes.json"
    if [[ ! -f "$hashes_file" ]]; then
        echo "INSUFFICIENT_HISTORY: No state hashes recorded"
        return 1
    fi

    # Extract hashes array from iterations
    local iteration_count
    iteration_count=$(jq '.iterations | length' "$hashes_file")

    if [[ "$iteration_count" -lt 4 ]]; then
        echo "INSUFFICIENT_HISTORY: Need at least 4 iterations, got ${iteration_count}"
        return 1
    fi

    # Extract just the hash values
    local hashes_array
    hashes_array=$(jq '[.iterations[].hash]' "$hashes_file")

    # Find repeated hashes and detect cycle patterns
    local repeated_info
    repeated_info=$(echo "$hashes_array" | jq '
        group_by(.) |
        map(select(length > 1)) |
        if length > 0 then
            {
                has_repeats: true,
                repeated_states: [.[] | {hash: .[0], count: length}]
            }
        else
            {has_repeats: false, repeated_states: []}
        end
    ')

    local has_repeats
    has_repeats=$(echo "$repeated_info" | jq -r '.has_repeats')

    if [[ "$has_repeats" == "true" ]]; then
        # Detect cycle length by finding the shortest repeating pattern
        # For A-B-A-B, cycle_length = 2; for A-B-C-A-B-C, cycle_length = 3
        local cycle_length
        cycle_length=$(echo "$hashes_array" | jq '
            . as $arr |
            # Find first repeated hash
            (group_by(.) | map(select(length > 1)) | .[0][0]) as $first_repeat |
            # Find indices of this hash
            [range(length) | select($arr[.] == $first_repeat)] |
            # Cycle length is difference between first two occurrences
            if length >= 2 then .[1] - .[0] else 2 end
        ')

        local repeated_states
        repeated_states=$(echo "$repeated_info" | jq '.repeated_states')

        jq -n \
            --argjson oscillation_detected true \
            --argjson cycle_length "$cycle_length" \
            --argjson repeated_states "$repeated_states" \
            '{
                oscillation_detected: $oscillation_detected,
                oscillation_pattern: {
                    cycle_length: $cycle_length,
                    repeated_states: $repeated_states
                },
                recommendation: "Code state is oscillating between states. Consider a different approach or manual intervention."
            }'
        return 0
    else
        jq -n \
            --argjson oscillation_detected false \
            '{
                oscillation_detected: $oscillation_detected,
                oscillation_pattern: null,
                recommendation: null
            }'
        return 1
    fi
}

# ==============================================================================
# check_stuck — Detect repeated identical errors (internal helper)
# ==============================================================================
_check_stuck() {
    local errors_json="$1"
    local stuck_threshold="${2:-3}"

    local error_count
    error_count=$(echo "$errors_json" | jq 'length')

    if [[ "$error_count" -lt "$stuck_threshold" ]]; then
        echo '{"stuck": false}'
        return 1
    fi

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
        jq -n --argjson stuck true --arg err "$last_error" --argjson count "$consecutive_count" \
            '{stuck: $stuck, repeated_error: $err, consecutive_count: $count}'
        return 0
    else
        echo '{"stuck": false}'
        return 1
    fi
}

# ==============================================================================
# check_all_layers — Evaluate all 6 termination layers in priority order
# ==============================================================================
# Usage: check_all_layers --session ID --workdir PATH
#
# Outputs: JSON with should_terminate, layer_triggered, termination_reason,
#          and layer_results for all 6 layers
# Returns: 0 if should terminate, 1 if should continue
check_all_layers() {
    local session_id="" workdir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session) session_id="$2"; shift 2 ;;
            --workdir) workdir="$2"; shift 2 ;;
            *)         shift ;;
        esac
    done

    # Load session state
    local state_json
    state_json=$(_term_load_state "$session_id" "$workdir") || {
        echo "SESSION_NOT_FOUND: No session with id '${session_id}'"
        return 1
    }

    # Extract fields
    local composite_grade quality_grades iteration_count max_iterations
    local quality_threshold

    composite_grade=$(echo "$state_json" | jq -r '.current_grade // 0')
    quality_grades=$(echo "$state_json" | jq -c '.quality_history // []')
    iteration_count=$(echo "$state_json" | jq -r '.current_iteration // 0')
    max_iterations=$(echo "$state_json" | jq -r '.max_iterations // 25')
    quality_threshold=$(echo "$state_json" | jq -r '.quality_threshold // 0.95')

    # Initialize layer results
    local l1_triggered=false l2_triggered=false l3_triggered=false
    local l4_triggered=false l5_triggered=false l6_triggered=false
    local triggered_layer="null" triggered_reason="null"

    # ---- Layer 1: Success (grade >= threshold) ----
    if _term_bc_compare "$composite_grade" ">=" "$quality_threshold"; then
        l1_triggered=true
        if [[ "$triggered_layer" == "null" ]]; then
            triggered_layer=1
            triggered_reason="success"
        fi
    fi

    # ---- Layer 2: Convergence ----
    local conv_result
    conv_result=$(check_convergence --grades "$quality_grades" 2>/dev/null) && l2_triggered=true || true
    if [[ "$l2_triggered" == "true" && "$triggered_layer" == "null" ]]; then
        triggered_layer=2
        triggered_reason="converged"
    fi

    # ---- Layer 3: Budget ----
    local budget_result
    budget_result=$(check_budget --session "$session_id" --workdir "$workdir" 2>/dev/null) && l3_triggered=true || true
    if [[ "$l3_triggered" == "true" && "$triggered_layer" == "null" ]]; then
        triggered_layer=3
        triggered_reason="budget_exhausted"
    fi

    # ---- Layer 4: Max iterations ----
    if [[ "$iteration_count" -ge "$max_iterations" ]]; then
        l4_triggered=true
        if [[ "$triggered_layer" == "null" ]]; then
            triggered_layer=4
            triggered_reason="max_iterations"
        fi
    fi

    # ---- Layer 5: Stuck (errors or oscillation) ----
    local recent_errors
    recent_errors=$(echo "$state_json" | jq -c '.recent_errors // []')
    local stuck_result
    stuck_result=$(_check_stuck "$recent_errors" 2>/dev/null) && l5_triggered=true || true

    if [[ "$l5_triggered" != "true" ]]; then
        # Check oscillation too
        local osc_result
        osc_result=$(check_oscillation --session "$session_id" --workdir "$workdir" 2>/dev/null) && l5_triggered=true || true
    fi
    if [[ "$l5_triggered" == "true" && "$triggered_layer" == "null" ]]; then
        triggered_layer=5
        triggered_reason="stuck"
    fi

    # ---- Layer 6: User interrupt ----
    if [[ "$_DEVLOOP_USER_INTERRUPTED" == "true" ]]; then
        l6_triggered=true
        if [[ "$triggered_layer" == "null" ]]; then
            triggered_layer=6
            triggered_reason="user_interrupt"
        fi
    fi

    # Determine if should terminate
    local should_terminate=false
    if [[ "$triggered_layer" != "null" ]]; then
        should_terminate=true
    fi

    # Build output
    jq -n \
        --argjson should_terminate "$should_terminate" \
        --argjson layer_triggered "$triggered_layer" \
        --arg termination_reason "$triggered_reason" \
        --argjson l1 "$l1_triggered" \
        --argjson l2 "$l2_triggered" \
        --argjson l3 "$l3_triggered" \
        --argjson l4 "$l4_triggered" \
        --argjson l5 "$l5_triggered" \
        --argjson l6 "$l6_triggered" \
        '{
            should_terminate: $should_terminate,
            layer_triggered: (if $layer_triggered == 0 then null else $layer_triggered end),
            termination_reason: (if $termination_reason == "null" then null else $termination_reason end),
            layer_results: {
                layer_1_success: $l1,
                layer_2_convergence: $l2,
                layer_3_budget: $l3,
                layer_4_max_iterations: $l4,
                layer_5_stuck: $l5,
                layer_6_user_interrupt: $l6
            }
        }'

    if [[ "$should_terminate" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# ==============================================================================
# save_checkpoint — Save session state to a checkpoint file
# ==============================================================================
# Usage: save_checkpoint --session ID --workdir PATH [--name NAME]
#
# Outputs: JSON with checkpoint_path, checkpoint_size_bytes, state_captured
# Returns: 0 on success, 1 on failure
save_checkpoint() {
    local session_id="" workdir="" checkpoint_name=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session) session_id="$2"; shift 2 ;;
            --workdir) workdir="$2"; shift 2 ;;
            --name)    checkpoint_name="$2"; shift 2 ;;
            *)         shift ;;
        esac
    done

    # Load session state
    local state_json
    state_json=$(_term_load_state "$session_id" "$workdir") || {
        echo "SESSION_NOT_FOUND: No session with id '${session_id}'"
        return 1
    }

    local sess_dir="${workdir}/.dev-loop/sessions/${session_id}"
    local checkpoints_dir="${sess_dir}/checkpoints"
    mkdir -p "$checkpoints_dir"

    # Determine checkpoint filename
    local checkpoint_file
    if [[ -n "$checkpoint_name" ]]; then
        checkpoint_file="${checkpoints_dir}/${checkpoint_name}.json"
    else
        local timestamp
        timestamp=$(date +%s)
        checkpoint_file="${checkpoints_dir}/checkpoint_${timestamp}.json"
    fi

    # Add checkpoint metadata and write
    local timestamp_iso
    timestamp_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    echo "$state_json" | jq \
        --arg ts "$timestamp_iso" \
        --arg version "1.0" \
        '. + {checkpoint_timestamp: $ts, checkpoint_version: $version}' > "$checkpoint_file"

    # Get file size
    local file_size
    if [[ "$(uname)" == "Darwin" ]]; then
        file_size=$(stat -f%z "$checkpoint_file" 2>/dev/null || echo "0")
    else
        file_size=$(stat -c%s "$checkpoint_file" 2>/dev/null || echo "0")
    fi

    # Extract state_captured info
    local current_iteration quality_history resources_consumed
    current_iteration=$(echo "$state_json" | jq -r '.current_iteration // 0')
    quality_history=$(echo "$state_json" | jq -c '.quality_history // []')
    resources_consumed=$(echo "$state_json" | jq -c '.resources_consumed // {}')

    jq -n \
        --arg checkpoint_path "$checkpoint_file" \
        --argjson checkpoint_size_bytes "$file_size" \
        --argjson iteration "$current_iteration" \
        --argjson quality_history "$quality_history" \
        --argjson resources_consumed "$resources_consumed" \
        '{
            checkpoint_path: $checkpoint_path,
            checkpoint_size_bytes: $checkpoint_size_bytes,
            state_captured: {
                iteration: $iteration,
                quality_history: $quality_history,
                resources_consumed: $resources_consumed
            }
        }'

    return 0
}

# ==============================================================================
# load_checkpoint — Load session state from a checkpoint file
# ==============================================================================
# Usage: load_checkpoint <checkpoint_path>
#
# Outputs: JSON session state to stdout
# Returns: 0 on success, 1 on failure
load_checkpoint() {
    local checkpoint_path="$1"

    if [[ ! -f "$checkpoint_path" ]]; then
        echo "ERROR: Checkpoint file not found: $checkpoint_path" >&2
        return 1
    fi

    if ! jq empty "$checkpoint_path" 2>/dev/null; then
        echo "ERROR: Checkpoint file is not valid JSON: $checkpoint_path" >&2
        return 1
    fi

    jq '.' "$checkpoint_path"
    return 0
}
