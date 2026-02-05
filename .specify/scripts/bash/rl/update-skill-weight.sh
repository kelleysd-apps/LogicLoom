#!/bin/bash
# =============================================================================
# update-skill-weight.sh
# Task: T009
# Purpose: Update skill selection weight using EMA (Exponential Moving Average)
#
# Usage: ./update-skill-weight.sh <skill-path> <outcome> [tokens_used] [user_satisfaction]
#
# Arguments:
#   skill-path: Full skill path (e.g., "sdd-workflow/sdd-specification")
#   outcome: success | failure | partial
#   tokens_used: (optional) Tokens used in this invocation
#   user_satisfaction: (optional) User satisfaction score 0-1
#
# Example:
#   ./update-skill-weight.sh "sdd-workflow/sdd-specification" success 1200 0.9
#
# Constitutional Compliance: Principle VII (Observability)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PERFORMANCE_FILE="$ROOT_DIR/.docs/rl-metrics/skill-performance.json"
LOG_DIR="$ROOT_DIR/.docs/audit"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# =============================================================================
# Configuration (from evaluation_config)
# =============================================================================
LEARNING_RATE=0.1
REWARD_WEIGHT_SUCCESS=0.5
REWARD_WEIGHT_TOKEN_EFFICIENCY=0.3
REWARD_WEIGHT_USER_SATISFACTION=0.2
MIN_WEIGHT=0.1
MAX_WEIGHT=1.0
MAX_HISTORY_ENTRIES=100

# =============================================================================
# Functions
# =============================================================================

log_info() {
    echo "[INFO] $(date -Iseconds) - $1"
}

log_error() {
    echo "[ERROR] $(date -Iseconds) - $1" >&2
}

show_usage() {
    cat << EOF
Usage: $(basename "$0") <skill-path> <outcome> [tokens_used] [user_satisfaction]

Arguments:
  skill-path          Full skill path (e.g., "sdd-workflow/sdd-specification")
  outcome             success | failure | partial
  tokens_used         (optional) Tokens used in this invocation (default: 0)
  user_satisfaction   (optional) User satisfaction score 0-1 (default: 0.5)

Examples:
  $(basename "$0") "sdd-workflow/sdd-specification" success 1200 0.9
  $(basename "$0") "domain/database-operations" failure 500
  $(basename "$0") "validation/message-preflight" success

Outcome Types:
  success  - Task completed without errors (reward boost)
  failure  - Task failed or produced errors (reward penalty)
  partial  - Task partially completed (neutral reward)

EMA Algorithm:
  selection_weight(t+1) = alpha * reward + (1 - alpha) * selection_weight(t)

  Where:
  - alpha = learning_rate = $LEARNING_RATE
  - reward = $REWARD_WEIGHT_SUCCESS * outcome_score +
             $REWARD_WEIGHT_TOKEN_EFFICIENCY * token_efficiency +
             $REWARD_WEIGHT_USER_SATISFACTION * user_satisfaction
EOF
}

# Calculate outcome score (0-1)
calculate_outcome_score() {
    local outcome="$1"
    case "$outcome" in
        success) echo "1.0" ;;
        partial) echo "0.5" ;;
        failure) echo "0.0" ;;
        *)
            log_error "Invalid outcome: $outcome"
            exit 1
            ;;
    esac
}

# Calculate token efficiency (0-1)
# Lower tokens = higher efficiency
calculate_token_efficiency() {
    local tokens_used="$1"
    local avg_tokens="$2"

    if [[ "$avg_tokens" -eq 0 ]] || [[ "$tokens_used" -eq 0 ]]; then
        echo "0.5"  # Default if no baseline
        return
    fi

    # Efficiency = min(1, avg/current)
    # If current < avg, efficiency > 1, capped at 1
    # If current > avg, efficiency < 1
    local efficiency
    efficiency=$(echo "scale=4; a=$avg_tokens; b=$tokens_used; if(a/b > 1) 1 else a/b" | bc)
    echo "$efficiency"
}

# Calculate final reward
calculate_reward() {
    local outcome_score="$1"
    local token_efficiency="$2"
    local user_satisfaction="$3"

    local reward
    reward=$(echo "scale=4; $REWARD_WEIGHT_SUCCESS * $outcome_score + $REWARD_WEIGHT_TOKEN_EFFICIENCY * $token_efficiency + $REWARD_WEIGHT_USER_SATISFACTION * $user_satisfaction" | bc)
    echo "$reward"
}

# Update weight using EMA
calculate_new_weight() {
    local current_weight="$1"
    local reward="$2"

    local new_weight
    new_weight=$(echo "scale=4; $LEARNING_RATE * $reward + (1 - $LEARNING_RATE) * $current_weight" | bc)

    # Clamp to [MIN_WEIGHT, MAX_WEIGHT]
    if (( $(echo "$new_weight < $MIN_WEIGHT" | bc -l) )); then
        new_weight="$MIN_WEIGHT"
    elif (( $(echo "$new_weight > $MAX_WEIGHT" | bc -l) )); then
        new_weight="$MAX_WEIGHT"
    fi

    echo "$new_weight"
}

# Update the skill-performance.json file
update_performance_file() {
    local skill_path="$1"
    local outcome="$2"
    local tokens_used="$3"
    local user_satisfaction="$4"
    local timestamp="$5"

    # Check if file exists
    if [[ ! -f "$PERFORMANCE_FILE" ]]; then
        log_error "Performance file not found: $PERFORMANCE_FILE"
        exit 1
    fi

    # Read current skill data
    local current_weight
    local invocation_count
    local success_count
    local failure_count
    local partial_count
    local total_tokens
    local avg_tokens

    current_weight=$(jq -r ".skills[\"$skill_path\"].current_weight // 0.5" "$PERFORMANCE_FILE")
    invocation_count=$(jq -r ".skills[\"$skill_path\"].invocation_count // 0" "$PERFORMANCE_FILE")
    success_count=$(jq -r ".skills[\"$skill_path\"].success_count // 0" "$PERFORMANCE_FILE")
    failure_count=$(jq -r ".skills[\"$skill_path\"].failure_count // 0" "$PERFORMANCE_FILE")
    partial_count=$(jq -r ".skills[\"$skill_path\"].partial_count // 0" "$PERFORMANCE_FILE")
    total_tokens=$(jq -r ".skills[\"$skill_path\"].total_tokens // 0" "$PERFORMANCE_FILE")

    # Calculate average tokens for efficiency comparison
    if [[ "$invocation_count" -gt 0 ]]; then
        avg_tokens=$((total_tokens / invocation_count))
    else
        avg_tokens=0
    fi

    # Calculate reward components
    local outcome_score
    local token_efficiency
    local reward
    local new_weight

    outcome_score=$(calculate_outcome_score "$outcome")
    token_efficiency=$(calculate_token_efficiency "$tokens_used" "$avg_tokens")
    reward=$(calculate_reward "$outcome_score" "$token_efficiency" "$user_satisfaction")
    new_weight=$(calculate_new_weight "$current_weight" "$reward")

    # Calculate weight delta
    local weight_delta
    weight_delta=$(echo "scale=4; $new_weight - $current_weight" | bc)

    # Update counts
    local new_invocation_count=$((invocation_count + 1))
    local new_total_tokens=$((total_tokens + tokens_used))

    case "$outcome" in
        success) success_count=$((success_count + 1)) ;;
        failure) failure_count=$((failure_count + 1)) ;;
        partial) partial_count=$((partial_count + 1)) ;;
    esac

    # Create learning history entry
    local learning_entry
    learning_entry=$(cat << EOF
{
  "timestamp": "$timestamp",
  "reward": $reward,
  "weight_before": $current_weight,
  "weight_after": $new_weight,
  "weight_delta": $weight_delta,
  "outcome": "$outcome",
  "tokens_used": $tokens_used
}
EOF
)

    # Update the JSON file using jq
    local temp_file
    temp_file=$(mktemp)

    jq --arg skill "$skill_path" \
       --argjson new_weight "$new_weight" \
       --argjson invocation_count "$new_invocation_count" \
       --argjson success_count "$success_count" \
       --argjson failure_count "$failure_count" \
       --argjson partial_count "$partial_count" \
       --argjson total_tokens "$new_total_tokens" \
       --argjson learning_entry "$learning_entry" \
       --arg timestamp "$timestamp" \
       '
       # Update skill entry
       .skills[$skill].current_weight = $new_weight |
       .skills[$skill].invocation_count = $invocation_count |
       .skills[$skill].success_count = $success_count |
       .skills[$skill].failure_count = $failure_count |
       .skills[$skill].partial_count = $partial_count |
       .skills[$skill].total_tokens = $total_tokens |

       # Add learning history entry (keep max 100)
       .skills[$skill].learning_history = (.skills[$skill].learning_history + [$learning_entry] | .[-100:]) |

       # Update global metrics
       .last_updated = $timestamp |
       .total_invocations = (.total_invocations + 1)
       ' "$PERFORMANCE_FILE" > "$temp_file"

    mv "$temp_file" "$PERFORMANCE_FILE"

    # Output result
    cat << EOF
Skill Weight Updated:
  Skill: $skill_path
  Outcome: $outcome
  Reward: $reward
  Weight: $current_weight -> $new_weight (delta: $weight_delta)
  Invocations: $new_invocation_count
  Tokens: $tokens_used (efficiency: $token_efficiency)
EOF

    # Log to audit file
    local audit_entry
    audit_entry=$(cat << EOF
{"timestamp":"$timestamp","skill":"$skill_path","outcome":"$outcome","reward":$reward,"weight_before":$current_weight,"weight_after":$new_weight,"tokens_used":$tokens_used}
EOF
)
    echo "$audit_entry" >> "$LOG_DIR/rl-weight-updates.log"
}

# =============================================================================
# Main
# =============================================================================

main() {
    local skill_path="${1:-}"
    local outcome="${2:-}"
    local tokens_used="${3:-0}"
    local user_satisfaction="${4:-0.5}"

    # Validate arguments
    if [[ -z "$skill_path" ]] || [[ -z "$outcome" ]]; then
        show_usage
        exit 1
    fi

    # Validate outcome
    case "$outcome" in
        success|failure|partial) ;;
        *)
            log_error "Invalid outcome: $outcome. Must be: success | failure | partial"
            exit 1
            ;;
    esac

    # Validate numeric arguments
    if ! [[ "$tokens_used" =~ ^[0-9]+$ ]]; then
        log_error "tokens_used must be a non-negative integer"
        exit 1
    fi

    if ! [[ "$user_satisfaction" =~ ^[0-9]*\.?[0-9]+$ ]]; then
        log_error "user_satisfaction must be a number between 0 and 1"
        exit 1
    fi

    local timestamp
    timestamp=$(date -Iseconds)

    log_info "Updating skill weight for: $skill_path"

    update_performance_file "$skill_path" "$outcome" "$tokens_used" "$user_satisfaction" "$timestamp"

    log_info "Weight update complete"
}

main "$@"
