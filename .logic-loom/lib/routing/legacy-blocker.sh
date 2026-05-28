#!/bin/bash
# Legacy Pattern Blocker
# Task: T059
# Purpose: Block direct agent invocations in skills-first mode
# Version: 1.0.0
# Constitutional Compliance: Principle X (Skills-First)

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
ARCHITECTURE_CONF="${ROOT_DIR}/.logic-loom/config/architecture.conf"
BLOCK_LOG="${ROOT_DIR}/.docs/rl-metrics/legacy-blocks.json"

# Emergency override (set via environment variable)
LEGACY_OVERRIDE="${LEGACY_OVERRIDE:-false}"

# ==============================================================================
# Logging
# ==============================================================================

log_info() {
    echo "[LEGACY-BLOCKER] [INFO] $(date -Iseconds) $*" >&2
}

log_warn() {
    echo "[LEGACY-BLOCKER] [WARN] $(date -Iseconds) $*" >&2
}

log_error() {
    echo "[LEGACY-BLOCKER] [ERROR] $(date -Iseconds) $*" >&2
}

log_block() {
    echo "[LEGACY-BLOCKER] [BLOCK] $(date -Iseconds) $*" >&2
}

# ==============================================================================
# Block Log Management
# ==============================================================================

init_block_log() {
    if [[ ! -f "$BLOCK_LOG" ]]; then
        mkdir -p "$(dirname "$BLOCK_LOG")"
        cat > "$BLOCK_LOG" << 'EOF'
{
  "version": "1.0.0",
  "created": null,
  "updated": null,
  "config": {
    "max_entries": 1000
  },
  "blocked_attempts": [],
  "statistics": {
    "total_blocks": 0,
    "blocks_by_agent": {},
    "blocks_by_reason": {}
  }
}
EOF
        local ts
        ts=$(date -Iseconds)
        jq --arg ts "$ts" '.created = $ts | .updated = $ts' "$BLOCK_LOG" > "${BLOCK_LOG}.tmp" && mv "${BLOCK_LOG}.tmp" "$BLOCK_LOG"
    fi
}

# Log a blocked attempt
log_blocked_attempt() {
    local agent_name="${1:?Agent name required}"
    local reason="${2:-direct_invocation}"
    local context="${3:-}"

    init_block_log

    local ts
    ts=$(date -Iseconds)

    jq --arg agent "$agent_name" \
       --arg reason "$reason" \
       --arg context "$context" \
       --arg ts "$ts" \
       '
       .blocked_attempts = [{
           "timestamp": $ts,
           "agent": $agent,
           "reason": $reason,
           "context": $context
       }] + .blocked_attempts[:(.config.max_entries - 1)] |
       .statistics.total_blocks += 1 |
       .statistics.blocks_by_agent[$agent] = ((.statistics.blocks_by_agent[$agent] // 0) + 1) |
       .statistics.blocks_by_reason[$reason] = ((.statistics.blocks_by_reason[$reason] // 0) + 1) |
       .updated = $ts
       ' "$BLOCK_LOG" > "${BLOCK_LOG}.tmp" && mv "${BLOCK_LOG}.tmp" "$BLOCK_LOG"
}

# ==============================================================================
# Mode Detection
# ==============================================================================

# Get current architecture mode
get_architecture_mode() {
    if [[ -f "$ARCHITECTURE_CONF" ]]; then
        grep -E "^ARCHITECTURE_MODE=" "$ARCHITECTURE_CONF" | cut -d= -f2 || echo "hybrid"
    else
        echo "hybrid"
    fi
}

# Check if legacy blocking is enabled
is_blocking_enabled() {
    if [[ -f "$ARCHITECTURE_CONF" ]]; then
        local blocking
        blocking=$(grep -E "^LEGACY_BLOCKING=" "$ARCHITECTURE_CONF" | cut -d= -f2 || echo "false")
        [[ "$blocking" == "true" ]]
    else
        return 1
    fi
}

# Check if override is active
is_override_active() {
    [[ "$LEGACY_OVERRIDE" == "true" ]]
}

# ==============================================================================
# Legacy Agent Detection
# ==============================================================================

# List of legacy agent names (pre-consolidation)
LEGACY_AGENTS=(
    "frontend-specialist"
    "full-stack-developer"
    "devops-engineer"
    "performance-engineer"
    "specification-agent"
    "planning-agent"
    "tasks-agent"
    "prd-specialist"
    "testing-specialist"
    "security-specialist"
    "subagent-architect"
    "task-orchestrator"
)

# Check if agent name is a legacy agent
is_legacy_agent() {
    local agent_name="${1:?Agent name required}"

    for legacy in "${LEGACY_AGENTS[@]}"; do
        if [[ "$agent_name" == "$legacy" ]]; then
            return 0
        fi
    done
    return 1
}

# Get consolidated replacement for legacy agent
get_consolidated_replacement() {
    local agent_name="${1:?Agent name required}"

    case "$agent_name" in
        frontend-specialist|full-stack-developer)
            echo "implementation-specialist"
            ;;
        devops-engineer|performance-engineer)
            echo "operations-specialist"
            ;;
        specification-agent|planning-agent|tasks-agent|prd-specialist)
            echo "specification-orchestrator"
            ;;
        testing-specialist|security-specialist)
            echo "quality-specialist"
            ;;
        subagent-architect)
            echo "system-architect"
            ;;
        task-orchestrator)
            echo "workflow-coordinator"
            ;;
        *)
            echo ""
            ;;
    esac
}

# ==============================================================================
# Blocking Logic
# ==============================================================================

# Check if invocation should be blocked
should_block() {
    local agent_name="${1:?Agent name required}"
    local invocation_type="${2:-direct}"  # direct or skill

    # Check override first
    if is_override_active; then
        log_warn "Override active - allowing legacy pattern"
        return 1  # Don't block
    fi

    local mode
    mode=$(get_architecture_mode)

    case "$mode" in
        skills-first)
            # In skills-first mode, block direct agent invocations
            if [[ "$invocation_type" == "direct" ]]; then
                if is_blocking_enabled; then
                    return 0  # Block
                else
                    log_warn "Legacy pattern detected but blocking not enabled"
                    return 1  # Don't block (warning only)
                fi
            fi
            ;;
        hybrid)
            # In hybrid mode, warn but don't block
            if [[ "$invocation_type" == "direct" ]]; then
                log_warn "Legacy pattern detected in hybrid mode"
            fi
            return 1  # Don't block
            ;;
        legacy-agents)
            # Legacy mode - allow everything
            return 1  # Don't block
            ;;
    esac

    return 1  # Default: don't block
}

# Block an invocation attempt
block_invocation() {
    local agent_name="${1:?Agent name required}"
    local reason="${2:-direct_invocation}"
    local context="${3:-}"

    log_block "Blocked direct invocation of: $agent_name"
    log_blocked_attempt "$agent_name" "$reason" "$context"

    # Provide migration guidance
    local replacement
    replacement=$(get_consolidated_replacement "$agent_name")

    cat << EOF

=== LEGACY PATTERN BLOCKED ===

Direct agent invocation is not allowed in skills-first mode.

Blocked Agent: $agent_name
Reason: $reason

=== MIGRATION GUIDANCE ===

EOF

    if [[ -n "$replacement" ]]; then
        cat << EOF
This agent has been consolidated into: $replacement

To invoke this agent correctly:
1. Use a skill that invokes $replacement
2. Or update your invocation to use skills-first pattern

Example skills that invoke $replacement:
EOF
        # List skills that invoke the replacement agent
        list_skills_for_agent "$replacement"
    else
        cat << EOF
Use the appropriate skill to orchestrate this work.
Skills route to agents automatically.

To find the right skill:
1. Check .claude/skill-index.json
2. Match your task to skill triggers
3. Invoke the skill, not the agent

EOF
    fi

    cat << EOF

=== EMERGENCY OVERRIDE ===

If you absolutely must use direct invocation:
  LEGACY_OVERRIDE=true <command>

This should only be used for emergencies.

EOF

    return 1
}

# List skills that invoke a specific agent
list_skills_for_agent() {
    local agent_name="${1:?Agent name required}"
    local skill_index="${ROOT_DIR}/.claude/skill-index.json"

    if [[ -f "$skill_index" ]]; then
        jq -r --arg agent "$agent_name" \
            '.skills[] | select(.["agent-invocations"][]?.agent == $agent) | "  - \(.category)/\(.name)"' \
            "$skill_index" 2>/dev/null || echo "  (No skills found)"
    else
        echo "  (Skill index not found)"
    fi
}

# ==============================================================================
# Validation Functions
# ==============================================================================

# Validate an invocation request
validate_invocation() {
    local agent_name="${1:?Agent name required}"
    local invocation_type="${2:-direct}"
    local context="${3:-}"

    log_info "Validating invocation: agent=$agent_name, type=$invocation_type"

    # Check if it's a legacy agent
    if is_legacy_agent "$agent_name"; then
        log_warn "Legacy agent detected: $agent_name"

        if should_block "$agent_name" "$invocation_type"; then
            block_invocation "$agent_name" "legacy_agent" "$context"
            return 1
        fi
    fi

    # Check if direct invocation should be blocked
    if [[ "$invocation_type" == "direct" ]] && should_block "$agent_name" "$invocation_type"; then
        block_invocation "$agent_name" "direct_invocation" "$context"
        return 1
    fi

    log_info "Invocation allowed: $agent_name"
    return 0
}

# ==============================================================================
# Query Functions
# ==============================================================================

# Get blocking statistics
get_statistics() {
    init_block_log
    jq '.statistics' "$BLOCK_LOG"
}

# Get recent blocks
get_recent_blocks() {
    local limit="${1:-10}"
    init_block_log
    jq --argjson limit "$limit" '.blocked_attempts[:$limit]' "$BLOCK_LOG"
}

# Get current status
get_status() {
    local mode
    mode=$(get_architecture_mode)

    local blocking_enabled
    if is_blocking_enabled; then
        blocking_enabled="true"
    else
        blocking_enabled="false"
    fi

    local override_active
    if is_override_active; then
        override_active="true"
    else
        override_active="false"
    fi

    jq -n \
        --arg mode "$mode" \
        --arg blocking "$blocking_enabled" \
        --arg override "$override_active" \
        '{
            "architecture_mode": $mode,
            "blocking_enabled": ($blocking == "true"),
            "override_active": ($override == "true"),
            "legacy_agents_count": 12,
            "status": (
                if $mode == "skills-first" and $blocking == "true" then "blocking"
                elif $mode == "skills-first" then "warning"
                elif $mode == "hybrid" then "warning"
                else "permissive"
                end
            )
        }'
}

# ==============================================================================
# Main Entry Point
# ==============================================================================

show_usage() {
    cat << EOF
Legacy Pattern Blocker

Usage: $(basename "$0") <command> [options]

Commands:
  validate <agent> [type] [context]   Validate invocation (block if needed)
  check <agent>                       Check if agent is legacy
  replacement <agent>                 Get consolidated replacement
  status                              Get current blocking status
  stats                               Get blocking statistics
  recent [limit]                      Get recent blocks

Options:
  --help          Show this help message

Environment Variables:
  LEGACY_OVERRIDE=true    Emergency override (allows legacy patterns)

Examples:
  # Validate an invocation
  $(basename "$0") validate frontend-specialist direct

  # Check if agent is legacy
  $(basename "$0") check frontend-specialist

  # Get replacement agent
  $(basename "$0") replacement devops-engineer

  # Get status
  $(basename "$0") status

Architecture Modes:
  - skills-first: Block direct invocations (if LEGACY_BLOCKING=true)
  - hybrid: Warn but allow (Phase 1-2)
  - legacy-agents: Allow everything (emergency fallback)

EOF
}

main() {
    local command="${1:-}"

    case "$command" in
        validate)
            shift
            validate_invocation "$@"
            ;;
        check)
            shift
            if is_legacy_agent "${1:?Agent name required}"; then
                echo "true"
                exit 0
            else
                echo "false"
                exit 0
            fi
            ;;
        replacement)
            shift
            get_consolidated_replacement "${1:?Agent name required}"
            ;;
        status)
            get_status
            ;;
        stats)
            get_statistics
            ;;
        recent)
            shift
            get_recent_blocks "${1:-10}"
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
