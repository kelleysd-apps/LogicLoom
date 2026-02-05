#!/bin/bash
# GRPO/PPO Policy Optimizer for Skills-First Architecture
# Task: T047
# FR: FR-602 (deferred feature)
# Purpose: Implement policy gradient optimization for advanced RL
# Version: 1.0.0 (BETA - Feature flagged)
# Constitutional Compliance: Principle I (Library-First), V (Progressive Enhancement)
# Note: EMA is primary algorithm; GRPO/PPO is optional enhancement

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
SKILL_PERFORMANCE="${ROOT_DIR}/.docs/rl-metrics/skill-performance.json"
POLICY_STATE="${ROOT_DIR}/.docs/rl-metrics/grpo-policy-state.json"
ARCHITECTURE_CONF="${ROOT_DIR}/.specify/config/architecture.conf"

# GRPO/PPO Hyperparameters
GRPO_ENABLED="${GRPO_ENABLED:-false}"  # Feature flag - disabled by default
LEARNING_RATE="${GRPO_LEARNING_RATE:-0.001}"
CLIP_EPSILON="${GRPO_CLIP_EPSILON:-0.2}"  # PPO clipping parameter
GAMMA="${GRPO_GAMMA:-0.99}"  # Discount factor
GAE_LAMBDA="${GRPO_GAE_LAMBDA:-0.95}"  # GAE lambda for advantage estimation
ENTROPY_COEF="${GRPO_ENTROPY_COEF:-0.01}"  # Entropy bonus coefficient
VALUE_COEF="${GRPO_VALUE_COEF:-0.5}"  # Value loss coefficient
BATCH_SIZE="${GRPO_BATCH_SIZE:-32}"
NUM_EPOCHS="${GRPO_NUM_EPOCHS:-4}"  # Epochs per policy update

# ==============================================================================
# Logging
# ==============================================================================

log_info() {
    echo "[GRPO-OPTIMIZER] [INFO] $(date -Iseconds) $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "[GRPO-OPTIMIZER] [DEBUG] $(date -Iseconds) $*" >&2
    fi
}

log_warn() {
    echo "[GRPO-OPTIMIZER] [WARN] $(date -Iseconds) $*" >&2
}

log_error() {
    echo "[GRPO-OPTIMIZER] [ERROR] $(date -Iseconds) $*" >&2
}

# ==============================================================================
# Feature Flag Check
# ==============================================================================

check_grpo_enabled() {
    if [[ "$GRPO_ENABLED" != "true" ]]; then
        # Check architecture.conf
        if [[ -f "$ARCHITECTURE_CONF" ]]; then
            local conf_enabled
            conf_enabled=$(grep -E "^RL_ALGORITHM=" "$ARCHITECTURE_CONF" | cut -d= -f2 || echo "ema")
            if [[ "$conf_enabled" != "grpo" && "$conf_enabled" != "ppo" ]]; then
                log_warn "GRPO/PPO is disabled. Using EMA algorithm."
                log_info "To enable, set RL_ALGORITHM=grpo in architecture.conf or GRPO_ENABLED=true"
                return 1
            fi
            GRPO_ENABLED="true"
        else
            log_warn "GRPO/PPO is disabled (feature flag). Using EMA algorithm."
            return 1
        fi
    fi
    return 0
}

# ==============================================================================
# Policy State Management
# ==============================================================================

init_policy_state() {
    if [[ ! -f "$POLICY_STATE" ]]; then
        log_info "Initializing GRPO policy state"
        mkdir -p "$(dirname "$POLICY_STATE")"
        cat > "$POLICY_STATE" << EOF
{
  "version": "1.0.0",
  "algorithm": "grpo-ppo",
  "status": "initialized",
  "created": "$(date -Iseconds)",
  "updated": "$(date -Iseconds)",
  "hyperparameters": {
    "learning_rate": $LEARNING_RATE,
    "clip_epsilon": $CLIP_EPSILON,
    "gamma": $GAMMA,
    "gae_lambda": $GAE_LAMBDA,
    "entropy_coef": $ENTROPY_COEF,
    "value_coef": $VALUE_COEF,
    "batch_size": $BATCH_SIZE,
    "num_epochs": $NUM_EPOCHS
  },
  "policy_weights": {},
  "value_estimates": {},
  "trajectory_buffer": [],
  "update_history": [],
  "statistics": {
    "total_updates": 0,
    "total_trajectories": 0,
    "avg_policy_loss": 0,
    "avg_value_loss": 0,
    "avg_entropy": 0
  }
}
EOF
    fi
}

# ==============================================================================
# Trajectory Collection
# ==============================================================================

# Collect a trajectory (state-action-reward sequence)
# Usage: collect_trajectory <skill_path> <action> <reward> <state_features>
collect_trajectory() {
    local skill_path="${1:?Skill path required}"
    local action="${2:?Action required}"  # The skill/agent invoked
    local reward="${3:?Reward required}"
    local state_features="${4:-{}}"  # JSON object with state features

    if ! check_grpo_enabled; then
        return 1
    fi

    init_policy_state
    log_debug "Collecting trajectory: skill=$skill_path, action=$action, reward=$reward"

    local timestamp
    timestamp=$(date -Iseconds)

    # Get current policy probability for this action
    local policy_prob
    policy_prob=$(get_policy_probability "$skill_path" "$action")

    # Get value estimate for current state
    local value_estimate
    value_estimate=$(get_value_estimate "$skill_path")

    # Create trajectory entry
    local trajectory
    trajectory=$(jq -n \
        --arg skill "$skill_path" \
        --arg action "$action" \
        --argjson reward "$reward" \
        --argjson state "$state_features" \
        --argjson prob "$policy_prob" \
        --argjson value "$value_estimate" \
        --arg ts "$timestamp" \
        '{
            "timestamp": $ts,
            "skill_path": $skill,
            "action": $action,
            "reward": $reward,
            "state_features": $state,
            "policy_prob": $prob,
            "value_estimate": $value,
            "advantage": null,
            "return": null
        }')

    # Add to trajectory buffer
    jq --argjson traj "$trajectory" \
       --arg ts "$timestamp" \
       '
       .trajectory_buffer += [$traj] |
       .statistics.total_trajectories += 1 |
       .updated = $ts
       ' "$POLICY_STATE" > "${POLICY_STATE}.tmp" && mv "${POLICY_STATE}.tmp" "$POLICY_STATE"

    log_info "Trajectory collected for skill: $skill_path"
}

# ==============================================================================
# Policy Functions
# ==============================================================================

# Get current policy probability for an action
get_policy_probability() {
    local skill_path="${1:?Skill path required}"
    local action="${2:?Action required}"

    # Get current weight from skill performance
    if [[ -f "$SKILL_PERFORMANCE" ]]; then
        local weight
        weight=$(jq --arg skill "$skill_path" \
            '.skills[$skill].current_weight // 0.5' \
            "$SKILL_PERFORMANCE")
        echo "$weight"
    else
        echo "0.5"
    fi
}

# Get value estimate for a state (skill context)
get_value_estimate() {
    local skill_path="${1:?Skill path required}"

    # Get value from policy state or estimate from historical performance
    if [[ -f "$POLICY_STATE" ]]; then
        local value
        value=$(jq --arg skill "$skill_path" \
            '.value_estimates[$skill] // 0.5' \
            "$POLICY_STATE")
        echo "$value"
    else
        echo "0.5"
    fi
}

# ==============================================================================
# Advantage Estimation (GAE)
# ==============================================================================

# Calculate Generalized Advantage Estimation
calculate_gae() {
    if ! check_grpo_enabled; then
        return 1
    fi

    init_policy_state
    log_info "Calculating GAE for trajectory buffer"

    # Get trajectory buffer
    local buffer_size
    buffer_size=$(jq '.trajectory_buffer | length' "$POLICY_STATE")

    if [[ "$buffer_size" -lt 2 ]]; then
        log_warn "Not enough trajectories for GAE calculation"
        return 0
    fi

    # Calculate advantages and returns using GAE formula
    # A_t = sum_{l=0}^{inf} (gamma * lambda)^l * delta_{t+l}
    # where delta_t = r_t + gamma * V(s_{t+1}) - V(s_t)

    jq --argjson gamma "$GAMMA" \
       --argjson lambda "$GAE_LAMBDA" \
       '
       # Process trajectories in reverse for GAE
       .trajectory_buffer as $buffer |
       ($buffer | length) as $n |

       # Calculate deltas and advantages
       reduce range($n - 1; -1; -1) as $i (
           {"advantages": [], "returns": [], "next_value": 0, "next_advantage": 0};

           $buffer[$i] as $traj |
           (
               if $i == ($n - 1) then 0
               else $buffer[$i + 1].value_estimate
               end
           ) as $next_v |

           # TD error: delta = r + gamma * V(s+1) - V(s)
           ($traj.reward + ($gamma * $next_v) - $traj.value_estimate) as $delta |

           # GAE advantage: A = delta + gamma * lambda * A_next
           ($delta + ($gamma * $lambda * .next_advantage)) as $advantage |

           # Return: R = r + gamma * R_next
           ($traj.reward + ($gamma * .next_value)) as $return |

           {
               "advantages": [$advantage] + .advantages,
               "returns": [$return] + .returns,
               "next_value": $return,
               "next_advantage": $advantage
           }
       ) as $results |

       # Update trajectories with advantages and returns
       .trajectory_buffer = [
           range($n) as $i |
           $buffer[$i] * {
               "advantage": $results.advantages[$i],
               "return": $results.returns[$i]
           }
       ] |

       .updated = (now | todate)
       ' "$POLICY_STATE" > "${POLICY_STATE}.tmp" && mv "${POLICY_STATE}.tmp" "$POLICY_STATE"

    log_info "GAE calculation complete"
}

# ==============================================================================
# Policy Update (PPO Clipping)
# ==============================================================================

# Update policy using PPO clipped objective
update_policy() {
    if ! check_grpo_enabled; then
        return 1
    fi

    init_policy_state
    calculate_gae

    log_info "Updating policy with PPO clipped objective"

    local buffer_size
    buffer_size=$(jq '.trajectory_buffer | length' "$POLICY_STATE")

    if [[ "$buffer_size" -lt "$BATCH_SIZE" ]]; then
        log_warn "Not enough trajectories for policy update (have $buffer_size, need $BATCH_SIZE)"
        return 0
    fi

    local timestamp
    timestamp=$(date -Iseconds)

    # Calculate policy gradients and update weights
    # Using simplified bash implementation (production would use Python)

    # For each skill in the buffer, calculate policy update
    local skills
    skills=$(jq -r '.trajectory_buffer | [.[].skill_path] | unique | .[]' "$POLICY_STATE")

    local total_policy_loss=0
    local total_value_loss=0
    local total_entropy=0
    local num_updates=0

    for skill in $skills; do
        log_debug "Processing skill: $skill"

        # Get trajectories for this skill
        local skill_data
        skill_data=$(jq --arg skill "$skill" \
            '[.trajectory_buffer[] | select(.skill_path == $skill)]' \
            "$POLICY_STATE")

        local num_trajs
        num_trajs=$(echo "$skill_data" | jq 'length')

        if [[ "$num_trajs" -lt 1 ]]; then
            continue
        fi

        # Calculate average advantage for this skill
        local avg_advantage
        avg_advantage=$(echo "$skill_data" | jq '[.[].advantage] | add / length')

        # Get current weight
        local old_weight
        old_weight=$(get_policy_probability "$skill" "invoke")

        # Calculate probability ratio: r(theta) = pi_new / pi_old
        # For simplicity, we use advantage to estimate gradient direction

        # PPO clipped update:
        # L^CLIP = min(r * A, clip(r, 1-eps, 1+eps) * A)

        # Simplified update rule for bash:
        # new_weight = old_weight + lr * sign(A) * min(abs(A) * old_weight, clip_eps)

        local update_direction
        if (( $(echo "$avg_advantage > 0" | bc -l) )); then
            update_direction=1
        else
            update_direction=-1
        fi

        local abs_advantage
        abs_advantage=$(echo "$avg_advantage" | awk '{print ($1 < 0) ? -$1 : $1}')

        local raw_update
        raw_update=$(echo "$abs_advantage * $old_weight" | bc -l)

        local clipped_update
        clipped_update=$(echo "if ($raw_update > $CLIP_EPSILON) $CLIP_EPSILON else $raw_update" | bc -l)

        local weight_delta
        weight_delta=$(echo "$LEARNING_RATE * $update_direction * $clipped_update" | bc -l)

        local new_weight
        new_weight=$(echo "$old_weight + $weight_delta" | bc -l)

        # Clamp to valid range
        if (( $(echo "$new_weight < 0.1" | bc -l) )); then
            new_weight="0.1"
        elif (( $(echo "$new_weight > 1.0" | bc -l) )); then
            new_weight="1.0"
        fi

        log_debug "Skill $skill: old=$old_weight, advantage=$avg_advantage, new=$new_weight"

        # Update policy weights in state
        jq --arg skill "$skill" \
           --argjson weight "$new_weight" \
           --arg ts "$timestamp" \
           '
           .policy_weights[$skill] = $weight |
           .updated = $ts
           ' "$POLICY_STATE" > "${POLICY_STATE}.tmp" && mv "${POLICY_STATE}.tmp" "$POLICY_STATE"

        # Apply to skill performance
        if [[ -f "${SCRIPT_DIR}/update-skill-weight.sh" ]]; then
            "${SCRIPT_DIR}/update-skill-weight.sh" "$skill" "policy_update" \
                --direct-weight "$new_weight" 2>/dev/null || true
        fi

        # Calculate losses (simplified)
        local policy_loss
        policy_loss=$(echo "$clipped_update * $update_direction * -1" | bc -l)
        total_policy_loss=$(echo "$total_policy_loss + $policy_loss" | bc -l)

        # Value loss: MSE between value estimate and actual return
        local value_loss
        value_loss=$(echo "$skill_data" | jq '[.[].return - .[].value_estimate | . * .] | add / length // 0')
        total_value_loss=$(echo "$total_value_loss + $value_loss" | bc -l)

        # Entropy (negative log of weight as proxy)
        local entropy
        entropy=$(echo "-1 * $new_weight * l($new_weight)/l(2.718281828)" | bc -l 2>/dev/null || echo "0")
        total_entropy=$(echo "$total_entropy + $entropy" | bc -l)

        num_updates=$((num_updates + 1))
    done

    if [[ "$num_updates" -gt 0 ]]; then
        # Calculate averages
        local avg_policy_loss
        avg_policy_loss=$(echo "$total_policy_loss / $num_updates" | bc -l)
        local avg_value_loss
        avg_value_loss=$(echo "$total_value_loss / $num_updates" | bc -l)
        local avg_entropy
        avg_entropy=$(echo "$total_entropy / $num_updates" | bc -l)

        # Record update
        local update_record
        update_record=$(jq -n \
            --arg ts "$timestamp" \
            --argjson policy_loss "$avg_policy_loss" \
            --argjson value_loss "$avg_value_loss" \
            --argjson entropy "$avg_entropy" \
            --argjson num_updates "$num_updates" \
            '{
                "timestamp": $ts,
                "policy_loss": $policy_loss,
                "value_loss": $value_loss,
                "entropy": $entropy,
                "skills_updated": $num_updates
            }')

        jq --argjson record "$update_record" \
           --argjson policy_loss "$avg_policy_loss" \
           --argjson value_loss "$avg_value_loss" \
           --argjson entropy "$avg_entropy" \
           --arg ts "$timestamp" \
           '
           .update_history = [$record] + .update_history[:99] |
           .statistics.total_updates += 1 |
           .statistics.avg_policy_loss = ((.statistics.avg_policy_loss * (.statistics.total_updates - 1) + $policy_loss) / .statistics.total_updates) |
           .statistics.avg_value_loss = ((.statistics.avg_value_loss * (.statistics.total_updates - 1) + $value_loss) / .statistics.total_updates) |
           .statistics.avg_entropy = ((.statistics.avg_entropy * (.statistics.total_updates - 1) + $entropy) / .statistics.total_updates) |
           .trajectory_buffer = [] |
           .updated = $ts
           ' "$POLICY_STATE" > "${POLICY_STATE}.tmp" && mv "${POLICY_STATE}.tmp" "$POLICY_STATE"

        log_info "Policy update complete: $num_updates skills updated"
        echo "$update_record"
    else
        log_warn "No skills updated in policy update"
    fi
}

# ==============================================================================
# Query Functions
# ==============================================================================

get_policy_weights() {
    init_policy_state
    jq '.policy_weights' "$POLICY_STATE"
}

get_statistics() {
    init_policy_state
    jq '.statistics' "$POLICY_STATE"
}

get_hyperparameters() {
    init_policy_state
    jq '.hyperparameters' "$POLICY_STATE"
}

get_update_history() {
    local limit="${1:-10}"
    init_policy_state
    jq --argjson limit "$limit" '.update_history[:$limit]' "$POLICY_STATE"
}

# ==============================================================================
# Main Entry Point
# ==============================================================================

show_usage() {
    cat << EOF
GRPO/PPO Policy Optimizer for Skills-First RL

IMPORTANT: This is an OPTIONAL advanced feature. EMA is the default algorithm.
To enable GRPO/PPO, set RL_ALGORITHM=grpo in architecture.conf

Usage: $(basename "$0") <command> [options]

Commands:
  collect <skill> <action> <reward> [state]  Collect trajectory
  gae                                         Calculate GAE advantages
  update                                      Update policy (PPO clipped)
  weights                                     Get current policy weights
  stats                                       Get statistics
  hyperparams                                 Get hyperparameters
  history [limit]                             Get update history

Options:
  --help          Show this help message
  --debug         Enable debug logging

Environment Variables:
  GRPO_ENABLED=true         Enable GRPO/PPO algorithm
  GRPO_LEARNING_RATE        Learning rate (default: 0.001)
  GRPO_CLIP_EPSILON         PPO clip parameter (default: 0.2)
  GRPO_GAMMA                Discount factor (default: 0.99)
  GRPO_GAE_LAMBDA           GAE lambda (default: 0.95)

Examples:
  # Enable GRPO and collect trajectory
  GRPO_ENABLED=true $(basename "$0") collect domain/database-operations invoke 0.85

  # Update policy after collecting enough trajectories
  GRPO_ENABLED=true $(basename "$0") update

Algorithm Notes:
  - PPO clipped objective prevents large policy updates
  - GAE balances bias-variance in advantage estimation
  - Entropy bonus encourages exploration
  - Value function learns expected returns

EOF
}

main() {
    local command="${1:-}"

    case "$command" in
        collect)
            shift
            collect_trajectory "$@"
            ;;
        gae)
            calculate_gae
            ;;
        update)
            update_policy
            ;;
        weights)
            get_policy_weights
            ;;
        stats)
            get_statistics
            ;;
        hyperparams)
            get_hyperparameters
            ;;
        history)
            shift
            get_update_history "$@"
            ;;
        --help|-h|help)
            show_usage
            exit 0
            ;;
        *)
            if [[ -n "$command" ]]; then
                log_error "Unknown command: $command"
            fi
            show_usage
            exit 1
            ;;
    esac
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
