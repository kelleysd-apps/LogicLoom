#!/bin/bash
# Skill Coverage Audit Script
# Task: T050
# FR: FR-503
# Purpose: Audit skill coverage per agent, identify gaps in portfolios
# Version: 1.0.0
# Constitutional Compliance: Principle VII (Observability), X (Skills-First)

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SKILL_INDEX="${ROOT_DIR}/.claude/skill-index.json"
AGENT_INDEX="${ROOT_DIR}/.claude/agent-index.json"
SKILLS_DIR="${ROOT_DIR}/.claude/skills"
AGENTS_DIR="${ROOT_DIR}/.claude/agents"

# ==============================================================================
# Logging
# ==============================================================================

log_info() {
    echo "[AUDIT] [INFO] $(date -Iseconds) $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "[AUDIT] [DEBUG] $(date -Iseconds) $*" >&2
    fi
}

log_warn() {
    echo "[AUDIT] [WARN] $(date -Iseconds) $*" >&2
}

log_error() {
    echo "[AUDIT] [ERROR] $(date -Iseconds) $*" >&2
}

# ==============================================================================
# Data Loading
# ==============================================================================

# Load skill index
load_skill_index() {
    if [[ ! -f "$SKILL_INDEX" ]]; then
        log_error "Skill index not found: $SKILL_INDEX"
        return 1
    fi
    cat "$SKILL_INDEX"
}

# Load agent index
load_agent_index() {
    if [[ ! -f "$AGENT_INDEX" ]]; then
        log_error "Agent index not found: $AGENT_INDEX"
        return 1
    fi
    cat "$AGENT_INDEX"
}

# ==============================================================================
# Coverage Analysis
# ==============================================================================

# Analyze skill coverage for all agents
analyze_coverage() {
    log_info "Analyzing skill coverage..."

    local skill_index
    local agent_index

    skill_index=$(load_skill_index)
    agent_index=$(load_agent_index)

    if [[ -z "$skill_index" || -z "$agent_index" ]]; then
        log_error "Failed to load indices"
        return 1
    fi

    # Get all skills that invoke agents
    local skills_with_agents
    skills_with_agents=$(echo "$skill_index" | jq -r '
        [.skills[] |
         select(.["agent-invocations"] != null) |
         {
           skill: "\(.category)/\(.name)",
           agents: [.["agent-invocations"][].agent]
         }
        ]')

    # Get all agents with their skill portfolios
    local agents_coverage
    agents_coverage=$(echo "$agent_index" | jq '
        [.domain_agents[], .ds_star_agents[] |
         {
           name: .name,
           portfolio: .["skill-portfolio"] // [],
           ds_star_role: .["ds-star-role"] // null
         }
        ]')

    # For each agent, find skills that invoke it
    local coverage_report
    coverage_report=$(jq -n \
        --argjson skills "$skills_with_agents" \
        --argjson agents "$agents_coverage" \
        '
        {
            "timestamp": (now | todate),
            "agents": [
                $agents[] | . as $agent |
                {
                    "name": $agent.name,
                    "declared_portfolio": $agent.portfolio,
                    "skills_invoking": [
                        $skills[] |
                        select(.agents | contains([$agent.name])) |
                        .skill
                    ],
                    "is_ds_star": ($agent.ds_star_role != null),
                    "coverage_match": (
                        ($agent.portfolio | sort) ==
                        ([$skills[] | select(.agents | contains([$agent.name])) | .skill] | sort)
                    )
                }
            ]
        }')

    echo "$coverage_report"
}

# Find agents without invoking skills
find_uninvoked_agents() {
    log_info "Finding agents without invoking skills..."

    local coverage
    coverage=$(analyze_coverage)

    echo "$coverage" | jq '
        .agents |
        map(select(.skills_invoking | length == 0)) |
        map(.name)'
}

# Find skills without agent invocations
find_orphan_skills() {
    log_info "Finding skills without agent invocations..."

    local skill_index
    skill_index=$(load_skill_index)

    echo "$skill_index" | jq '
        [.skills[] |
         select(.["agent-invocations"] == null or (.["agent-invocations"] | length == 0)) |
         "\(.category)/\(.name)"
        ]'
}

# Calculate coverage statistics
calculate_statistics() {
    log_info "Calculating coverage statistics..."

    local coverage
    coverage=$(analyze_coverage)

    local skill_index
    skill_index=$(load_skill_index)

    local agent_index
    agent_index=$(load_agent_index)

    # Total counts
    local total_skills
    total_skills=$(echo "$skill_index" | jq '.skills | length')

    local total_agents
    total_agents=$(echo "$agent_index" | jq '.statistics.total_agents')

    local domain_agents
    domain_agents=$(echo "$agent_index" | jq '.domain_agents | length')

    local ds_star_agents
    ds_star_agents=$(echo "$agent_index" | jq '.ds_star_agents | length')

    # Coverage counts
    local agents_with_skills
    agents_with_skills=$(echo "$coverage" | jq '[.agents[] | select(.skills_invoking | length > 0)] | length')

    local skills_with_agents
    skills_with_agents=$(echo "$skill_index" | jq '[.skills[] | select(.["agent-invocations"] != null and (.["agent-invocations"] | length > 0))] | length')

    local portfolio_matches
    portfolio_matches=$(echo "$coverage" | jq '[.agents[] | select(.coverage_match == true)] | length')

    # Calculate percentages
    local agent_coverage_pct
    agent_coverage_pct=$(echo "scale=2; $agents_with_skills * 100 / $total_agents" | bc)

    local skill_coverage_pct
    skill_coverage_pct=$(echo "scale=2; $skills_with_agents * 100 / $total_skills" | bc)

    local portfolio_match_pct
    portfolio_match_pct=$(echo "scale=2; $portfolio_matches * 100 / $total_agents" | bc)

    # Generate statistics JSON
    jq -n \
        --argjson total_skills "$total_skills" \
        --argjson total_agents "$total_agents" \
        --argjson domain_agents "$domain_agents" \
        --argjson ds_star_agents "$ds_star_agents" \
        --argjson agents_with_skills "$agents_with_skills" \
        --argjson skills_with_agents "$skills_with_agents" \
        --argjson portfolio_matches "$portfolio_matches" \
        --arg agent_coverage_pct "$agent_coverage_pct" \
        --arg skill_coverage_pct "$skill_coverage_pct" \
        --arg portfolio_match_pct "$portfolio_match_pct" \
        '{
            "timestamp": (now | todate),
            "totals": {
                "skills": $total_skills,
                "agents": $total_agents,
                "domain_agents": $domain_agents,
                "ds_star_agents": $ds_star_agents
            },
            "coverage": {
                "agents_with_skills": $agents_with_skills,
                "skills_with_agents": $skills_with_agents,
                "portfolio_matches": $portfolio_matches
            },
            "percentages": {
                "agent_coverage": ($agent_coverage_pct | tonumber),
                "skill_coverage": ($skill_coverage_pct | tonumber),
                "portfolio_match": ($portfolio_match_pct | tonumber)
            },
            "assessment": (
                if ($agent_coverage_pct | tonumber) >= 90 then "excellent"
                elif ($agent_coverage_pct | tonumber) >= 70 then "good"
                elif ($agent_coverage_pct | tonumber) >= 50 then "moderate"
                else "needs_improvement"
                end
            )
        }'
}

# ==============================================================================
# Gap Analysis
# ==============================================================================

# Identify gaps in skill portfolios
analyze_gaps() {
    log_info "Analyzing skill portfolio gaps..."

    local coverage
    coverage=$(analyze_coverage)

    # Find gaps: skills that invoke agent but not in portfolio, and vice versa
    echo "$coverage" | jq '
        .agents |
        map(
            select(.is_ds_star == false) |
            {
                agent: .name,
                in_portfolio_not_invoking: (
                    .declared_portfolio - .skills_invoking
                ),
                invoking_not_in_portfolio: (
                    .skills_invoking - .declared_portfolio
                ),
                has_gaps: (
                    ((.declared_portfolio - .skills_invoking) | length) > 0 or
                    ((.skills_invoking - .declared_portfolio) | length) > 0
                )
            }
        ) |
        map(select(.has_gaps == true))'
}

# Generate recommendations
generate_recommendations() {
    log_info "Generating recommendations..."

    local gaps
    gaps=$(analyze_gaps)

    local uninvoked
    uninvoked=$(find_uninvoked_agents)

    local orphan
    orphan=$(find_orphan_skills)

    local stats
    stats=$(calculate_statistics)

    jq -n \
        --argjson gaps "$gaps" \
        --argjson uninvoked "$uninvoked" \
        --argjson orphan "$orphan" \
        --argjson stats "$stats" \
        '{
            "timestamp": (now | todate),
            "statistics": $stats,
            "recommendations": (
                [
                    if ($uninvoked | length) > 0 then
                        {
                            "priority": "high",
                            "issue": "Agents without invoking skills",
                            "agents": $uninvoked,
                            "action": "Create skills that invoke these agents"
                        }
                    else empty end,

                    if ($orphan | length) > 0 then
                        {
                            "priority": "medium",
                            "issue": "Skills without agent invocations",
                            "skills": $orphan,
                            "action": "Add agent-invocations or mark as utility skills"
                        }
                    else empty end,

                    if ($gaps | length) > 0 then
                        {
                            "priority": "medium",
                            "issue": "Portfolio mismatches",
                            "count": ($gaps | length),
                            "action": "Synchronize skill portfolios with actual invocations"
                        }
                    else empty end,

                    if ($stats.percentages.agent_coverage < 80) then
                        {
                            "priority": "high",
                            "issue": "Low agent coverage",
                            "current": $stats.percentages.agent_coverage,
                            "target": 80,
                            "action": "Create skills for uncovered agents"
                        }
                    else empty end
                ]
            ),
            "gaps": $gaps
        }'
}

# ==============================================================================
# Reporting
# ==============================================================================

# Generate full audit report
generate_report() {
    local format="${1:-json}"

    log_info "Generating audit report..."

    local coverage
    coverage=$(analyze_coverage)

    local stats
    stats=$(calculate_statistics)

    local recommendations
    recommendations=$(generate_recommendations)

    case "$format" in
        json)
            jq -n \
                --argjson coverage "$coverage" \
                --argjson stats "$stats" \
                --argjson recommendations "$recommendations" \
                '{
                    "report": {
                        "title": "Skill Coverage Audit Report",
                        "generated": (now | todate),
                        "version": "1.0.0"
                    },
                    "statistics": $stats,
                    "coverage_details": $coverage.agents,
                    "recommendations": $recommendations.recommendations,
                    "gaps": $recommendations.gaps
                }'
            ;;
        markdown)
            generate_markdown_report "$coverage" "$stats" "$recommendations"
            ;;
        summary)
            echo "$stats"
            ;;
        *)
            log_error "Unknown format: $format"
            return 1
            ;;
    esac
}

# Generate markdown format report
generate_markdown_report() {
    local coverage="${1}"
    local stats="${2}"
    local recommendations="${3}"

    cat << EOF
# Skill Coverage Audit Report

**Generated**: $(date -Iseconds)
**Version**: 1.0.0

## Summary Statistics

| Metric | Value |
|--------|-------|
| Total Skills | $(echo "$stats" | jq -r '.totals.skills') |
| Total Agents | $(echo "$stats" | jq -r '.totals.agents') |
| Domain Agents | $(echo "$stats" | jq -r '.totals.domain_agents') |
| DS-STAR Agents | $(echo "$stats" | jq -r '.totals.ds_star_agents') |
| Agent Coverage | $(echo "$stats" | jq -r '.percentages.agent_coverage')% |
| Skill Coverage | $(echo "$stats" | jq -r '.percentages.skill_coverage')% |
| Portfolio Match | $(echo "$stats" | jq -r '.percentages.portfolio_match')% |

## Assessment

**Overall Status**: $(echo "$stats" | jq -r '.assessment')

## Agent Coverage Details

$(echo "$coverage" | jq -r '
    .agents[] |
    "### " + .name + "\n\n" +
    "- **Portfolio**: " + (.declared_portfolio | join(", ")) + "\n" +
    "- **Skills Invoking**: " + (.skills_invoking | join(", ")) + "\n" +
    "- **DS-STAR**: " + (if .is_ds_star then "Yes" else "No" end) + "\n" +
    "- **Match**: " + (if .coverage_match then "Yes" else "No" end) + "\n"
')

## Recommendations

$(echo "$recommendations" | jq -r '
    .recommendations[] |
    "### " + .priority + " Priority: " + .issue + "\n\n" +
    "**Action**: " + .action + "\n"
')

## Gaps Details

$(echo "$recommendations" | jq -r '
    if .gaps | length > 0 then
        .gaps[] |
        "### " + .agent + "\n\n" +
        (if .in_portfolio_not_invoking | length > 0 then
            "- **In portfolio but not invoking**: " + (.in_portfolio_not_invoking | join(", ")) + "\n"
        else "" end) +
        (if .invoking_not_in_portfolio | length > 0 then
            "- **Invoking but not in portfolio**: " + (.invoking_not_in_portfolio | join(", ")) + "\n"
        else "" end)
    else
        "No gaps detected."
    end
')

---

*Report generated by skill-coverage-audit.sh v1.0.0*
EOF
}

# ==============================================================================
# Main Entry Point
# ==============================================================================

show_usage() {
    cat << EOF
Skill Coverage Audit Tool

Usage: $(basename "$0") <command> [options]

Commands:
  coverage               Full coverage analysis
  stats                  Coverage statistics only
  gaps                   Portfolio gap analysis
  uninvoked              List agents without invoking skills
  orphan                 List skills without agent invocations
  recommendations        Generate recommendations
  report [format]        Generate full report (json|markdown|summary)

Options:
  --help          Show this help message
  --debug         Enable debug logging

Examples:
  # Get coverage statistics
  $(basename "$0") stats

  # Find portfolio gaps
  $(basename "$0") gaps

  # Generate markdown report
  $(basename "$0") report markdown > audit-report.md

  # Get JSON report
  $(basename "$0") report json | jq '.recommendations'

Requirements:
  - .claude/skill-index.json must exist
  - .claude/agent-index.json must exist

EOF
}

main() {
    local command="${1:-}"

    case "$command" in
        coverage)
            analyze_coverage
            ;;
        stats)
            calculate_statistics
            ;;
        gaps)
            analyze_gaps
            ;;
        uninvoked)
            find_uninvoked_agents
            ;;
        orphan)
            find_orphan_skills
            ;;
        recommendations)
            generate_recommendations
            ;;
        report)
            shift
            generate_report "${1:-json}"
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
