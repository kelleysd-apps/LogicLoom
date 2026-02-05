#!/bin/bash
# =============================================================================
# select-skill.sh
# Task: T010
# Purpose: RL-enhanced skill selection from multiple candidates
#
# Usage: ./select-skill.sh <candidate1> [candidate2] [candidate3] ...
#
# Arguments:
#   candidates: Skill paths that match the current query
#
# Output:
#   Selected skill path based on RL weights
#
# Algorithm:
#   - Uses softmax with temperature for probabilistic selection
#   - Higher selection_weight = higher probability
#   - Temperature controls exploration vs exploitation
#
# Example:
#   ./select-skill.sh "domain/database-operations" "sdd-workflow/sdd-planning"
#
# Constitutional Compliance: FR-601, FR-602
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PERFORMANCE_FILE="$ROOT_DIR/.docs/rl-metrics/skill-performance.json"
SKILL_INDEX_FILE="$ROOT_DIR/.claude/skill-index.json"

# =============================================================================
# Configuration
# =============================================================================
SELECTION_TEMPERATURE=1.0  # 1.0 = balanced, <1.0 = exploit, >1.0 = explore
DEFAULT_WEIGHT=0.5

# =============================================================================
# Functions
# =============================================================================

log_info() {
    echo "[INFO] $(date -Iseconds) - $1" >&2
}

log_error() {
    echo "[ERROR] $(date -Iseconds) - $1" >&2
}

show_usage() {
    cat << EOF
Usage: $(basename "$0") <candidate1> [candidate2] [candidate3] ...

Arguments:
  candidates    One or more skill paths to select from

Output:
  Prints the selected skill path to stdout

Examples:
  # Single candidate (always selected)
  $(basename "$0") "sdd-workflow/sdd-specification"

  # Multiple candidates (RL selection)
  $(basename "$0") "domain/database-operations" "sdd-workflow/sdd-planning"

  # Use in script
  selected=\$($(basename "$0") "skill1" "skill2")

Selection Algorithm:
  Uses softmax probability distribution based on selection_weight:

  P(skill_i) = exp(weight_i / temperature) / sum(exp(weight_j / temperature))

  Temperature: $SELECTION_TEMPERATURE
  - < 1.0: More exploitation (prefer higher weights)
  - = 1.0: Balanced exploration/exploitation
  - > 1.0: More exploration (more uniform distribution)
EOF
}

# Get selection weight for a skill
get_skill_weight() {
    local skill_path="$1"

    # Try skill-performance.json first
    if [[ -f "$PERFORMANCE_FILE" ]]; then
        local weight
        weight=$(jq -r ".skills[\"$skill_path\"].current_weight // null" "$PERFORMANCE_FILE" 2>/dev/null)
        if [[ "$weight" != "null" ]] && [[ -n "$weight" ]]; then
            echo "$weight"
            return
        fi
    fi

    # Try skill-index.json
    if [[ -f "$SKILL_INDEX_FILE" ]]; then
        local weight
        weight=$(jq -r ".skills[] | select(.name == \"$(basename "$skill_path")\") | .rl_metrics.selection_weight // null" "$SKILL_INDEX_FILE" 2>/dev/null)
        if [[ "$weight" != "null" ]] && [[ -n "$weight" ]]; then
            echo "$weight"
            return
        fi
    fi

    # Default weight
    echo "$DEFAULT_WEIGHT"
}

# Calculate softmax probabilities
# Input: space-separated weights
# Output: space-separated probabilities
calculate_softmax() {
    local weights=("$@")
    local temperature="$SELECTION_TEMPERATURE"

    # Calculate exp(w/T) for each weight
    local exp_values=()
    local sum=0

    for w in "${weights[@]}"; do
        local exp_val
        exp_val=$(echo "scale=10; e($w / $temperature)" | bc -l)
        exp_values+=("$exp_val")
        sum=$(echo "scale=10; $sum + $exp_val" | bc -l)
    done

    # Calculate probabilities
    local probs=()
    for exp_val in "${exp_values[@]}"; do
        local prob
        prob=$(echo "scale=10; $exp_val / $sum" | bc -l)
        probs+=("$prob")
    done

    echo "${probs[*]}"
}

# Sample from probability distribution
# Returns index of selected item
sample_from_distribution() {
    local probs=("$@")

    # Generate random number 0-1
    local rand
    rand=$(echo "scale=10; $RANDOM / 32767" | bc -l)

    # Cumulative probability selection
    local cumulative=0
    for i in "${!probs[@]}"; do
        cumulative=$(echo "scale=10; $cumulative + ${probs[$i]}" | bc -l)
        if (( $(echo "$rand <= $cumulative" | bc -l) )); then
            echo "$i"
            return
        fi
    done

    # Fallback to last item
    echo "$((${#probs[@]} - 1))"
}

# Select skill using RL weights
select_skill() {
    local candidates=("$@")

    # Single candidate - return immediately
    if [[ ${#candidates[@]} -eq 1 ]]; then
        echo "${candidates[0]}"
        return
    fi

    # Get weights for all candidates
    local weights=()
    for skill in "${candidates[@]}"; do
        local weight
        weight=$(get_skill_weight "$skill")
        weights+=("$weight")
        log_info "Candidate: $skill (weight: $weight)"
    done

    # Calculate softmax probabilities
    local probs_str
    probs_str=$(calculate_softmax "${weights[@]}")
    IFS=' ' read -ra probs <<< "$probs_str"

    log_info "Softmax probabilities: ${probs[*]}"

    # Sample from distribution
    local selected_idx
    selected_idx=$(sample_from_distribution "${probs[@]}")

    local selected_skill="${candidates[$selected_idx]}"

    log_info "Selected: $selected_skill (index: $selected_idx, prob: ${probs[$selected_idx]})"

    # Output selected skill
    echo "$selected_skill"
}

# Deterministic selection (always highest weight)
select_skill_deterministic() {
    local candidates=("$@")

    # Single candidate - return immediately
    if [[ ${#candidates[@]} -eq 1 ]]; then
        echo "${candidates[0]}"
        return
    fi

    local best_skill=""
    local best_weight=0

    for skill in "${candidates[@]}"; do
        local weight
        weight=$(get_skill_weight "$skill")

        if (( $(echo "$weight > $best_weight" | bc -l) )); then
            best_weight="$weight"
            best_skill="$skill"
        fi
    done

    echo "$best_skill"
}

# =============================================================================
# Main
# =============================================================================

main() {
    local mode="probabilistic"

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --deterministic)
                mode="deterministic"
                shift
                ;;
            --temperature)
                SELECTION_TEMPERATURE="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done

    local candidates=("$@")

    if [[ ${#candidates[@]} -eq 0 ]]; then
        log_error "No candidate skills provided"
        show_usage
        exit 1
    fi

    log_info "RL Skill Selection: ${#candidates[@]} candidates"
    log_info "Mode: $mode, Temperature: $SELECTION_TEMPERATURE"

    local selected
    if [[ "$mode" == "deterministic" ]]; then
        selected=$(select_skill_deterministic "${candidates[@]}")
    else
        selected=$(select_skill "${candidates[@]}")
    fi

    # Output only the selected skill to stdout
    echo "$selected"
}

main "$@"
