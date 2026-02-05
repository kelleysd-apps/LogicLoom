#!/bin/bash
# Credit Assignment Module for Skills-First Architecture
# Task: T046
# FR: FR-602
# Purpose: Track LLM requests per skill/agent and distribute rewards based on contribution
# Version: 1.0.0
# Constitutional Compliance: Principle I (Library-First), VII (Observability)

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
CREDIT_LOG="${ROOT_DIR}/.docs/rl-metrics/credit-assignment.json"
SKILL_PERFORMANCE="${ROOT_DIR}/.docs/rl-metrics/skill-performance.json"

# Credit distribution weights
# These determine how reward is distributed among participants
DEFAULT_SKILL_CREDIT_WEIGHT=0.4  # Skill orchestration contribution
DEFAULT_AGENT_CREDIT_WEIGHT=0.5  # Agent execution contribution
DEFAULT_CONTEXT_CREDIT_WEIGHT=0.1  # Context provision contribution

# ==============================================================================
# Logging
# ==============================================================================

log_info() {
    echo "[CREDIT-ASSIGNMENT] [INFO] $(date -Iseconds) $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "[CREDIT-ASSIGNMENT] [DEBUG] $(date -Iseconds) $*" >&2
    fi
}

log_warn() {
    echo "[CREDIT-ASSIGNMENT] [WARN] $(date -Iseconds) $*" >&2
}

log_error() {
    echo "[CREDIT-ASSIGNMENT] [ERROR] $(date -Iseconds) $*" >&2
}

# ==============================================================================
# Credit Log Management
# ==============================================================================

# Initialize credit assignment log if it doesn't exist
init_credit_log() {
    if [[ ! -f "$CREDIT_LOG" ]]; then
        log_info "Initializing credit assignment log"
        mkdir -p "$(dirname "$CREDIT_LOG")"
        cat > "$CREDIT_LOG" << 'EOF'
{
  "version": "1.0.0",
  "description": "Credit assignment tracking for RL reward distribution",
  "created": null,
  "updated": null,
  "config": {
    "skill_credit_weight": 0.4,
    "agent_credit_weight": 0.5,
    "context_credit_weight": 0.1,
    "max_history_entries": 1000
  },
  "active_sessions": {},
  "completed_sessions": [],
  "statistics": {
    "total_sessions": 0,
    "total_skills_credited": 0,
    "total_agents_credited": 0,
    "avg_requests_per_session": 0
  }
}
EOF
        # Set created timestamp
        local created_ts
        created_ts=$(date -Iseconds)
        jq --arg ts "$created_ts" '.created = $ts | .updated = $ts' "$CREDIT_LOG" > "${CREDIT_LOG}.tmp" && mv "${CREDIT_LOG}.tmp" "$CREDIT_LOG"
    fi
}

# ==============================================================================
# Session Management
# ==============================================================================

# Start a new credit tracking session
# Usage: start_session <session_id> <skill_path> [agent_name]
start_session() {
    local session_id="${1:?Session ID required}"
    local skill_path="${2:?Skill path required}"
    local agent_name="${3:-}"

    init_credit_log
    log_info "Starting credit session: $session_id for skill: $skill_path"

    local start_ts
    start_ts=$(date -Iseconds)

    # Create session entry
    local session_json
    session_json=$(jq -n \
        --arg id "$session_id" \
        --arg skill "$skill_path" \
        --arg agent "$agent_name" \
        --arg start "$start_ts" \
        '{
            "session_id": $id,
            "skill_path": $skill,
            "primary_agent": $agent,
            "start_time": $start,
            "end_time": null,
            "status": "active",
            "participants": [],
            "request_log": [],
            "total_requests": 0,
            "credit_distribution": null
        }')

    # Add to active sessions
    jq --arg id "$session_id" \
       --argjson session "$session_json" \
       --arg ts "$start_ts" \
       '.active_sessions[$id] = $session | .updated = $ts' \
       "$CREDIT_LOG" > "${CREDIT_LOG}.tmp" && mv "${CREDIT_LOG}.tmp" "$CREDIT_LOG"

    log_info "Session $session_id started"
    echo "$session_id"
}

# ==============================================================================
# Request Tracking
# ==============================================================================

# Log an LLM request within a session
# Usage: log_request <session_id> <participant_type> <participant_name> <tokens_used>
log_request() {
    local session_id="${1:?Session ID required}"
    local participant_type="${2:?Participant type required}"  # skill, agent, context-analyzer
    local participant_name="${3:?Participant name required}"
    local tokens_used="${4:?Tokens used required}"

    log_debug "Logging request: session=$session_id, type=$participant_type, name=$participant_name, tokens=$tokens_used"

    local request_ts
    request_ts=$(date -Iseconds)

    # Create request entry
    local request_json
    request_json=$(jq -n \
        --arg type "$participant_type" \
        --arg name "$participant_name" \
        --argjson tokens "$tokens_used" \
        --arg ts "$request_ts" \
        '{
            "timestamp": $ts,
            "participant_type": $type,
            "participant_name": $name,
            "tokens_used": $tokens
        }')

    # Add request to session and update participant list
    jq --arg id "$session_id" \
       --argjson request "$request_json" \
       --arg type "$participant_type" \
       --arg name "$participant_name" \
       --arg ts "$request_ts" \
       '
       # Add request to log
       .active_sessions[$id].request_log += [$request] |
       .active_sessions[$id].total_requests += 1 |

       # Update or add participant
       (
         .active_sessions[$id].participants as $participants |
         if ($participants | map(select(.name == $name)) | length) > 0 then
           .active_sessions[$id].participants = [
             $participants[] |
             if .name == $name then
               .request_count += 1 |
               .total_tokens += ($request.tokens_used | tonumber)
             else .
             end
           ]
         else
           .active_sessions[$id].participants += [{
             "type": $type,
             "name": $name,
             "request_count": 1,
             "total_tokens": ($request.tokens_used | tonumber)
           }]
         end
       ) |
       .updated = $ts
       ' "$CREDIT_LOG" > "${CREDIT_LOG}.tmp" && mv "${CREDIT_LOG}.tmp" "$CREDIT_LOG"

    log_debug "Request logged for session $session_id"
}

# ==============================================================================
# Credit Calculation
# ==============================================================================

# Calculate contribution weights for all participants in a session
# Returns JSON with credit assignments
calculate_contribution() {
    local session_id="${1:?Session ID required}"

    log_info "Calculating contribution for session: $session_id"

    # Get session data
    local session_data
    session_data=$(jq --arg id "$session_id" '.active_sessions[$id]' "$CREDIT_LOG")

    if [[ "$session_data" == "null" ]]; then
        log_error "Session not found: $session_id"
        return 1
    fi

    # Calculate total tokens across all participants
    local total_tokens
    total_tokens=$(echo "$session_data" | jq '[.participants[].total_tokens] | add // 0')

    if [[ "$total_tokens" == "0" || "$total_tokens" == "null" ]]; then
        log_warn "No tokens recorded for session: $session_id"
        echo '{"credits": [], "total_tokens": 0}'
        return 0
    fi

    # Calculate raw contribution ratio based on tokens
    # Then apply type-based weight adjustments
    local credits
    credits=$(echo "$session_data" | jq --argjson total "$total_tokens" \
        --argjson skill_weight "$DEFAULT_SKILL_CREDIT_WEIGHT" \
        --argjson agent_weight "$DEFAULT_AGENT_CREDIT_WEIGHT" \
        --argjson context_weight "$DEFAULT_CONTEXT_CREDIT_WEIGHT" \
        '
        # Calculate raw token ratio for each participant
        .participants | map({
            name: .name,
            type: .type,
            tokens: .total_tokens,
            raw_ratio: (.total_tokens / $total),
            type_weight: (
                if .type == "skill" then $skill_weight
                elif .type == "agent" then $agent_weight
                elif .type == "context-analyzer" then $context_weight
                else 0.3
                end
            )
        }) |

        # Calculate weighted contribution
        map(. + {
            weighted_contribution: (.raw_ratio * .type_weight)
        }) |

        # Normalize to sum to 1.0
        (map(.weighted_contribution) | add) as $total_weighted |
        map(. + {
            credit: (
                if $total_weighted > 0 then
                    (.weighted_contribution / $total_weighted)
                else
                    0
                end
            )
        })
        ')

    # Format output
    jq -n \
        --argjson credits "$credits" \
        --argjson total "$total_tokens" \
        --arg session "$session_id" \
        '{
            "session_id": $session,
            "total_tokens": $total,
            "credits": $credits
        }'
}

# ==============================================================================
# Reward Distribution
# ==============================================================================

# Distribute reward to participants based on credit assignment
# Usage: distribute_reward <session_id> <total_reward> <outcome>
distribute_reward() {
    local session_id="${1:?Session ID required}"
    local total_reward="${2:?Total reward required}"
    local outcome="${3:?Outcome required}"  # success, failure, partial

    log_info "Distributing reward for session: $session_id, reward=$total_reward, outcome=$outcome"

    # Calculate contribution
    local contribution
    contribution=$(calculate_contribution "$session_id")

    if [[ $? -ne 0 ]]; then
        log_error "Failed to calculate contribution for session: $session_id"
        return 1
    fi

    # Apply outcome modifier
    local outcome_modifier
    case "$outcome" in
        success)
            outcome_modifier=1.0
            ;;
        partial)
            outcome_modifier=0.5
            ;;
        failure)
            outcome_modifier=0.1
            ;;
        *)
            outcome_modifier=0.5
            log_warn "Unknown outcome: $outcome, using 0.5 modifier"
            ;;
    esac

    local end_ts
    end_ts=$(date -Iseconds)

    # Calculate individual rewards
    local distributed_rewards
    distributed_rewards=$(echo "$contribution" | jq \
        --argjson total_reward "$total_reward" \
        --argjson modifier "$outcome_modifier" \
        '
        .credits | map({
            participant: .name,
            type: .type,
            credit_ratio: .credit,
            base_reward: ($total_reward * .credit),
            adjusted_reward: ($total_reward * .credit * $modifier),
            tokens_used: .tokens
        })
        ')

    # Create credit distribution record
    local distribution_record
    distribution_record=$(jq -n \
        --argjson rewards "$distributed_rewards" \
        --argjson total "$total_reward" \
        --arg outcome "$outcome" \
        --argjson modifier "$outcome_modifier" \
        --arg ts "$end_ts" \
        '{
            "timestamp": $ts,
            "total_reward": $total,
            "outcome": $outcome,
            "outcome_modifier": $modifier,
            "distributions": $rewards
        }')

    # Update session with distribution and mark complete
    jq --arg id "$session_id" \
       --argjson distribution "$distribution_record" \
       --arg ts "$end_ts" \
       '
       # Store credit distribution
       .active_sessions[$id].credit_distribution = $distribution |
       .active_sessions[$id].end_time = $ts |
       .active_sessions[$id].status = "completed" |

       # Move to completed sessions
       .completed_sessions = [.active_sessions[$id]] + .completed_sessions |

       # Trim completed sessions to max history
       .completed_sessions = .completed_sessions[:(.config.max_history_entries // 1000)] |

       # Remove from active sessions
       del(.active_sessions[$id]) |

       # Update statistics
       .statistics.total_sessions += 1 |
       .statistics.total_skills_credited += ([$distribution.distributions[] | select(.type == "skill")] | length) |
       .statistics.total_agents_credited += ([$distribution.distributions[] | select(.type == "agent")] | length) |

       .updated = $ts
       ' "$CREDIT_LOG" > "${CREDIT_LOG}.tmp" && mv "${CREDIT_LOG}.tmp" "$CREDIT_LOG"

    # Apply rewards to skill performance
    echo "$distributed_rewards" | jq -c '.[]' | while read -r reward_entry; do
        local participant_name
        local participant_type
        local adjusted_reward

        participant_name=$(echo "$reward_entry" | jq -r '.participant')
        participant_type=$(echo "$reward_entry" | jq -r '.type')
        adjusted_reward=$(echo "$reward_entry" | jq -r '.adjusted_reward')

        if [[ "$participant_type" == "skill" ]]; then
            log_info "Applying reward $adjusted_reward to skill: $participant_name"
            # Call update-skill-weight.sh if it exists
            if [[ -x "${SCRIPT_DIR}/update-skill-weight.sh" ]]; then
                "${SCRIPT_DIR}/update-skill-weight.sh" "$participant_name" "$outcome" --reward "$adjusted_reward" 2>/dev/null || true
            fi
        fi
    done

    log_info "Reward distribution complete for session: $session_id"
    echo "$distribution_record"
}

# ==============================================================================
# Query Functions
# ==============================================================================

# Get active sessions
get_active_sessions() {
    init_credit_log
    jq '.active_sessions | keys' "$CREDIT_LOG"
}

# Get session details
get_session() {
    local session_id="${1:?Session ID required}"
    init_credit_log

    # Check active sessions first
    local session
    session=$(jq --arg id "$session_id" '.active_sessions[$id] // null' "$CREDIT_LOG")

    if [[ "$session" != "null" ]]; then
        echo "$session"
        return 0
    fi

    # Check completed sessions
    session=$(jq --arg id "$session_id" '.completed_sessions[] | select(.session_id == $id)' "$CREDIT_LOG")

    if [[ -n "$session" ]]; then
        echo "$session"
        return 0
    fi

    log_error "Session not found: $session_id"
    return 1
}

# Get statistics
get_statistics() {
    init_credit_log
    jq '.statistics' "$CREDIT_LOG"
}

# Get participant credit history
get_participant_history() {
    local participant_name="${1:?Participant name required}"
    local limit="${2:-10}"

    init_credit_log

    jq --arg name "$participant_name" --argjson limit "$limit" \
        '[.completed_sessions[] |
         select(.credit_distribution.distributions[] | .participant == $name) |
         {
            session_id: .session_id,
            end_time: .end_time,
            outcome: .credit_distribution.outcome,
            credit: (.credit_distribution.distributions[] | select(.participant == $name) | .credit_ratio),
            reward: (.credit_distribution.distributions[] | select(.participant == $name) | .adjusted_reward)
         }
        ][:$limit]' "$CREDIT_LOG"
}

# ==============================================================================
# Main Entry Point
# ==============================================================================

show_usage() {
    cat << EOF
Credit Assignment Module for Skills-First RL

Usage: $(basename "$0") <command> [options]

Commands:
  start <session_id> <skill_path> [agent]   Start a credit tracking session
  log <session_id> <type> <name> <tokens>   Log an LLM request
  calculate <session_id>                     Calculate contribution for session
  distribute <session_id> <reward> <outcome> Distribute reward to participants
  active                                     List active sessions
  session <session_id>                       Get session details
  stats                                      Get statistics
  history <participant> [limit]              Get participant credit history

Options:
  --help          Show this help message
  --debug         Enable debug logging

Examples:
  # Start a session for database operations skill
  $(basename "$0") start sess_001 domain/database-operations database-specialist

  # Log LLM requests during execution
  $(basename "$0") log sess_001 skill database-operations 150
  $(basename "$0") log sess_001 agent database-specialist 850

  # Calculate and distribute reward
  $(basename "$0") distribute sess_001 0.85 success

Environment Variables:
  DEBUG=true                Enable debug output
  CREDIT_LOG               Override credit log path

EOF
}

main() {
    local command="${1:-}"

    case "$command" in
        start)
            shift
            start_session "$@"
            ;;
        log)
            shift
            log_request "$@"
            ;;
        calculate)
            shift
            calculate_contribution "$@"
            ;;
        distribute)
            shift
            distribute_reward "$@"
            ;;
        active)
            get_active_sessions
            ;;
        session)
            shift
            get_session "$@"
            ;;
        stats)
            get_statistics
            ;;
        history)
            shift
            get_participant_history "$@"
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
