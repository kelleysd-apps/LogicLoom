#!/usr/bin/env bash
# rl-feedback-engine.sh — RL (Reinforcement Learning) feedback library for sdd-dev-loop plugin
#
# Provides functions for tracking skill and model performance metrics across
# dev-loop sessions using EMA-weighted success rates and UCB1 exploration scores.
# Updates RLMetrics entities and syncs with plugin manifests (plugins/*/plugin.json).
#
# This file is designed to be sourced, not executed directly.
#
# Dependencies: bc (floating-point arithmetic), jq (JSON parsing)
# Constitutional Principle VII: Observability — all metrics tracked and auditable
# Constitutional Principle VIII: Documentation Sync — metrics synced with plugin manifests
# Constitutional Principle XIV: AI Model Selection — per-model tracking informs selection

set -euo pipefail

# ==============================================================================
# Plugin Directory Resolution
# ==============================================================================

if [[ -z "${PLUGIN_DIR:-}" ]]; then
    PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# ==============================================================================
# Internal Helpers
# ==============================================================================

# _rl_bc_calc — Evaluate a floating-point expression via bc
_rl_bc_calc() {
    echo "$1" | bc -l 2>/dev/null || echo "0"
}

# _rl_bc_compare — Compare two floating-point numbers
# Returns: 0 (true) or 1 (false)
_rl_bc_compare() {
    local a="$1" op="$2" b="$3"
    local result
    case "$op" in
        "<")  result=$(_rl_bc_calc "$a < $b") ;;
        "<=") result=$(_rl_bc_calc "$a <= $b") ;;
        ">")  result=$(_rl_bc_calc "$a > $b") ;;
        ">=") result=$(_rl_bc_calc "$a >= $b") ;;
        "==") result=$(_rl_bc_calc "$a == $b") ;;
        *)    echo "ERROR: Unknown operator: $op" >&2; return 1 ;;
    esac
    [[ "$result" == "1" ]] && return 0 || return 1
}

# _rl_iso8601_now — Get current UTC timestamp in ISO 8601 format
_rl_iso8601_now() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# ==============================================================================
# ema_update — Compute new EMA rate from current rate and outcome
# ==============================================================================
# Usage: ema_update --current-rate <rate> --outcome <success|failure> --alpha <alpha>
#
# Formula: new_rate = (1 - alpha) * old_rate + alpha * outcome
# Where outcome is encoded as: success = 1.0, failure = 0.0
#
# Outputs: new rate (float in [0.0, 1.0]) to stdout
# Returns: 0 on success
ema_update() {
    local current_rate="" outcome="" alpha=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --current-rate) current_rate="$2"; shift 2 ;;
            --outcome)      outcome="$2"; shift 2 ;;
            --alpha)        alpha="$2"; shift 2 ;;
            *)              shift ;;
        esac
    done

    # Default alpha
    alpha="${alpha:-0.1}"

    # Encode outcome
    local outcome_value
    if [[ "$outcome" == "success" ]]; then
        outcome_value="1.0"
    else
        outcome_value="0.0"
    fi

    # Compute EMA: new_rate = (1 - alpha) * old_rate + alpha * outcome_value
    local new_rate
    new_rate=$(_rl_bc_calc "(1 - $alpha) * $current_rate + $alpha * $outcome_value")

    echo "$new_rate"
}

# ==============================================================================
# clamp_weight — Clamp selection_weight to [0.1, 1.0]
# ==============================================================================
# Usage: clamp_weight <value>
#
# Ensures no skill is ever completely excluded (minimum 0.1) or over-weighted
# (maximum 1.0).
#
# Outputs: clamped value (float)
# Returns: 0 on success
clamp_weight() {
    local value="$1"

    if _rl_bc_compare "$value" "<" "0.1"; then
        echo "0.1"
    elif _rl_bc_compare "$value" ">" "1.0"; then
        echo "1.0"
    else
        echo "$value"
    fi
}

# ==============================================================================
# ucb1_score — Compute UCB1 exploration/exploitation score
# ==============================================================================
# Usage: ucb1_score --success-rate <rate> --count <count> --total <total>
#
# Formula: ucb1 = success_rate + sqrt(2 * ln(total) / count)
# If count == 0, returns infinity (always explore untried skills).
#
# Outputs: UCB1 score (float) to stdout
# Returns: 0 on success
ucb1_score() {
    local success_rate="" count="" total=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --success-rate) success_rate="$2"; shift 2 ;;
            --count)        count="$2"; shift 2 ;;
            --total)        total="$2"; shift 2 ;;
            *)              shift ;;
        esac
    done

    # If count is 0, return infinity (always explore untried skills)
    if [[ "$count" == "0" ]]; then
        echo "inf"
        return 0
    fi

    # If total is 0, just return success_rate
    if [[ "$total" == "0" ]]; then
        echo "$success_rate"
        return 0
    fi

    # Compute UCB1: success_rate + sqrt(2 * ln(total) / count)
    local ucb1
    ucb1=$(_rl_bc_calc "$success_rate + sqrt(2 * l($total) / $count)")

    echo "$ucb1"
}

# ==============================================================================
# update_avg_tokens — Cumulative moving average for token tracking
# ==============================================================================
# Usage: update_avg_tokens <old_avg> <new_tokens> <new_count>
#
# Formula: new_avg = old_avg + (new_tokens - old_avg) / new_count
#
# Outputs: updated average (float)
# Returns: 0 on success
update_avg_tokens() {
    local old_avg="$1"
    local new_tokens="$2"
    local new_count="$3"

    if [[ "$new_count" -le 0 ]]; then
        echo "$old_avg"
        return 0
    fi

    local new_avg
    new_avg=$(_rl_bc_calc "$old_avg + ($new_tokens - $old_avg) / $new_count")
    echo "$new_avg"
}

# ==============================================================================
# update_avg_duration — Cumulative moving average for duration tracking
# ==============================================================================
# Usage: update_avg_duration <old_avg> <new_duration> <new_count>
#
# Formula: new_avg = old_avg + (new_duration - old_avg) / new_count
#
# Outputs: updated average (float)
# Returns: 0 on success
update_avg_duration() {
    local old_avg="$1"
    local new_duration="$2"
    local new_count="$3"

    if [[ "$new_count" -le 0 ]]; then
        echo "$old_avg"
        return 0
    fi

    local new_avg
    new_avg=$(_rl_bc_calc "$old_avg + ($new_duration - $old_avg) / $new_count")
    echo "$new_avg"
}

# ==============================================================================
# update_per_task_type — Update per-task-type sub-metrics
# ==============================================================================
# Usage: update_per_task_type <metrics_json> <task_type> <outcome> <tokens> <duration_ms> <alpha>
#
# Updates the per_task_type sub-object for the specified task type (tactic or strategy).
#
# Outputs: updated metrics JSON to stdout
# Returns: 0 on success
update_per_task_type() {
    local metrics_json="$1"
    local task_type="$2"
    local outcome="$3"
    local tokens="$4"
    local duration_ms="$5"
    local alpha="${6:-0.1}"

    # Read current sub-metrics
    local sub_rate sub_count sub_avg_tokens sub_avg_duration
    sub_rate=$(echo "$metrics_json" | jq -r ".per_task_type.${task_type}.success_rate")
    sub_count=$(echo "$metrics_json" | jq -r ".per_task_type.${task_type}.invocation_count")
    sub_avg_tokens=$(echo "$metrics_json" | jq -r ".per_task_type.${task_type}.avg_tokens")
    sub_avg_duration=$(echo "$metrics_json" | jq -r ".per_task_type.${task_type}.avg_duration_ms")

    # Update EMA for sub success_rate
    local new_sub_rate
    new_sub_rate=$(ema_update --current-rate "$sub_rate" --outcome "$outcome" --alpha "$alpha")

    # Increment sub count
    local new_sub_count=$((sub_count + 1))

    # Update sub averages
    local new_sub_avg_tokens new_sub_avg_duration
    new_sub_avg_tokens=$(update_avg_tokens "$sub_avg_tokens" "$tokens" "$new_sub_count")
    new_sub_avg_duration=$(update_avg_duration "$sub_avg_duration" "$duration_ms" "$new_sub_count")

    # Update the metrics JSON with new sub-metrics
    echo "$metrics_json" | jq \
        --arg task_type "$task_type" \
        --arg new_rate "$new_sub_rate" \
        --argjson new_count "$new_sub_count" \
        --arg new_tokens "$new_sub_avg_tokens" \
        --arg new_duration "$new_sub_avg_duration" \
        '.per_task_type[$task_type] = {
            success_rate: ($new_rate | tonumber),
            invocation_count: $new_count,
            avg_tokens: ($new_tokens | tonumber),
            avg_duration_ms: ($new_duration | tonumber)
        }'
}

# ==============================================================================
# update_task_type_metrics — Alias for update_per_task_type (test-expected name)
# ==============================================================================
# Usage: update_task_type_metrics <metrics_json> <task_type> <outcome> <tokens> <duration_ms> [alpha]
update_task_type_metrics() {
    update_per_task_type "$@"
}

# ==============================================================================
# load_metrics — Read metrics from a JSON file
# ==============================================================================
# Usage: load_metrics <metrics_file_path>
#
# Reads and outputs the metrics JSON from the specified file.
#
# Outputs: JSON metrics object to stdout
# Returns: 0 on success, 1 if file not found or invalid JSON
load_metrics() {
    local metrics_file="$1"

    if [[ ! -f "$metrics_file" ]]; then
        echo "ERROR: Metrics file not found: $metrics_file" >&2
        return 1
    fi

    if ! jq empty "$metrics_file" 2>/dev/null; then
        echo "ERROR: Invalid JSON in metrics file: $metrics_file" >&2
        return 1
    fi

    jq '.' "$metrics_file"
}

# ==============================================================================
# save_metrics — Write updated metrics to a JSON file
# ==============================================================================
# Usage: save_metrics <metrics_json> <metrics_file_path>
#
# Writes the metrics JSON to the specified file atomically.
#
# Returns: 0 on success, 1 on failure
save_metrics() {
    local metrics_json="$1"
    local metrics_file="$2"

    # Create parent directory if needed
    local parent_dir
    parent_dir=$(dirname "$metrics_file")
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir"
    fi

    # Write atomically via temp file
    local tmp_file="${metrics_file}.tmp"
    echo "$metrics_json" | jq '.' > "$tmp_file"

    if ! jq empty "$tmp_file" 2>/dev/null; then
        echo "ERROR: Generated metrics is not valid JSON" >&2
        rm -f "$tmp_file"
        return 1
    fi

    mv "$tmp_file" "$metrics_file"
    return 0
}

# ==============================================================================
# record_feedback — Record a feedback entry and update all metrics
# ==============================================================================
# Usage: record_feedback --metrics-file <path> --outcome <success|failure>
#                        --tokens <N> --duration-ms <N> --task-type <tactic|strategy>
#
# Full feedback recording pipeline:
#   1. Load current metrics from file
#   2. Update success_rate via EMA
#   3. Update selection_weight via clamp
#   4. Increment invocation_count
#   5. Update avg_tokens and avg_duration_ms via cumulative moving average
#   6. Append to history
#   7. Update last_feedback
#   8. Update per_task_type sub-metrics
#   9. Save updated metrics to file
#
# Outputs: JSON summary of changes to stdout
# Returns: 0 on success, 1 on failure
record_feedback() {
    local metrics_file="" outcome="" tokens="" duration_ms="" task_type=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --metrics-file) metrics_file="$2"; shift 2 ;;
            --outcome)      outcome="$2"; shift 2 ;;
            --tokens)       tokens="$2"; shift 2 ;;
            --duration-ms)  duration_ms="$2"; shift 2 ;;
            --task-type)    task_type="$2"; shift 2 ;;
            *)              shift ;;
        esac
    done

    # Load current metrics
    local metrics
    metrics=$(load_metrics "$metrics_file")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Read current values
    local old_rate old_weight old_count old_avg_tokens old_avg_duration alpha
    old_rate=$(echo "$metrics" | jq -r '.success_rate')
    old_weight=$(echo "$metrics" | jq -r '.selection_weight')
    old_count=$(echo "$metrics" | jq -r '.invocation_count')
    old_avg_tokens=$(echo "$metrics" | jq -r '.avg_tokens')
    old_avg_duration=$(echo "$metrics" | jq -r '.avg_duration_ms')
    alpha=$(echo "$metrics" | jq -r '.ema_alpha // 0.1')

    # Step 1: Update success_rate via EMA
    local new_rate
    new_rate=$(ema_update --current-rate "$old_rate" --outcome "$outcome" --alpha "$alpha")

    # Step 2: Update selection_weight
    local new_weight
    new_weight=$(clamp_weight "$new_rate")

    # Step 3: Increment invocation_count
    local new_count=$((old_count + 1))

    # Step 4: Update averages
    local new_avg_tokens new_avg_duration
    new_avg_tokens=$(update_avg_tokens "$old_avg_tokens" "$tokens" "$new_count")
    new_avg_duration=$(update_avg_duration "$old_avg_duration" "$duration_ms" "$new_count")

    # Step 5: Build new history entry
    local timestamp
    timestamp=$(_rl_iso8601_now)

    local history_entry
    history_entry=$(jq -n \
        --arg timestamp "$timestamp" \
        --arg outcome "$outcome" \
        --argjson tokens "$tokens" \
        --argjson duration_ms "$duration_ms" \
        '{timestamp: $timestamp, outcome: $outcome, tokens: $tokens, duration_ms: $duration_ms}')

    # Step 6: Build last_feedback
    local last_feedback="$history_entry"

    # Step 7: Update main metrics
    metrics=$(echo "$metrics" | jq \
        --arg new_rate "$new_rate" \
        --arg new_weight "$new_weight" \
        --argjson new_count "$new_count" \
        --arg new_avg_tokens "$new_avg_tokens" \
        --arg new_avg_duration "$new_avg_duration" \
        --argjson history_entry "$history_entry" \
        --argjson last_feedback "$last_feedback" \
        '.success_rate = ($new_rate | tonumber) |
         .selection_weight = ($new_weight | tonumber) |
         .invocation_count = $new_count |
         .avg_tokens = ($new_avg_tokens | tonumber) |
         .avg_duration_ms = ($new_avg_duration | tonumber) |
         .history = (.history + [$history_entry]) |
         .last_feedback = $last_feedback')

    # Step 8: Update per_task_type sub-metrics
    if [[ -n "$task_type" && ("$task_type" == "tactic" || "$task_type" == "strategy") ]]; then
        metrics=$(update_per_task_type "$metrics" "$task_type" "$outcome" "$tokens" "$duration_ms" "$alpha")
    fi

    # Step 9: Save updated metrics
    save_metrics "$metrics" "$metrics_file"

    # Output summary
    jq -n \
        --arg old_rate "$old_rate" \
        --arg new_rate "$new_rate" \
        --arg old_weight "$old_weight" \
        --arg new_weight "$new_weight" \
        --argjson old_count "$old_count" \
        --argjson new_count "$new_count" \
        --arg outcome "$outcome" \
        '{
            outcome: $outcome,
            success_rate: {old: ($old_rate | tonumber), new: ($new_rate | tonumber)},
            selection_weight: {old: ($old_weight | tonumber), new: ($new_weight | tonumber)},
            invocation_count: {old: $old_count, new: $new_count}
        }'
}

# ==============================================================================
# select_skill — Use UCB1 for exploration-exploitation skill selection
# ==============================================================================
# Usage: select_skill <skills_json_array>
#
# Takes a JSON array of skill metric objects and returns the skill with the
# highest UCB1 score.
#
# Arguments:
#   skills_json_array — JSON array where each element has:
#     {"skill_name": "...", "success_rate": N, "invocation_count": N}
#
# Outputs: skill_name of the selected skill
# Returns: 0 on success
select_skill() {
    local skills_json="$1"

    # Compute total invocations across all skills
    local total_invocations
    total_invocations=$(echo "$skills_json" | jq '[.[].invocation_count] | add // 0')

    # If no invocations at all, pick the first skill
    if [[ "$total_invocations" == "0" ]]; then
        echo "$skills_json" | jq -r '.[0].skill_name'
        return 0
    fi

    # Compute UCB1 for each skill and find the maximum
    local best_skill=""
    local best_score="-1"

    local skill_count
    skill_count=$(echo "$skills_json" | jq 'length')

    for ((i = 0; i < skill_count; i++)); do
        local skill_name rate count
        skill_name=$(echo "$skills_json" | jq -r ".[$i].skill_name")
        rate=$(echo "$skills_json" | jq -r ".[$i].success_rate")
        count=$(echo "$skills_json" | jq -r ".[$i].invocation_count")

        local score
        score=$(ucb1_score --success-rate "$rate" --count "$count" --total "$total_invocations")

        # Handle infinity (untried skills always win)
        if [[ "$score" == "inf" ]]; then
            echo "$skill_name"
            return 0
        fi

        if _rl_bc_compare "$score" ">" "$best_score"; then
            best_score="$score"
            best_skill="$skill_name"
        fi
    done

    echo "$best_skill"
}
