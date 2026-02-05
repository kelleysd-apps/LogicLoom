#!/bin/bash
# Legacy Pattern Report Script
# Task: T051
# FR: FR-503
# Purpose: Report direct agent invocations (legacy pattern), track migration progress
# Version: 1.0.0
# Constitutional Compliance: Principle VII (Observability), X (Skills-First)

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
ARCHITECTURE_CONF="${ROOT_DIR}/.specify/config/architecture.conf"
MIGRATION_LOG="${ROOT_DIR}/.docs/rl-metrics/migration-tracking.json"
SKILL_INDEX="${ROOT_DIR}/.claude/skill-index.json"
AGENT_INDEX="${ROOT_DIR}/.claude/agent-index.json"

# Pattern detection settings
LEGACY_PATTERNS=(
    "delegate to.*agent"
    "invoke.*agent directly"
    "call.*specialist"
    "use.*agent"
    "Task tool.*agent"
    "subagent_type:"
)

SKILLS_FIRST_PATTERNS=(
    "activate skill"
    "invoke skill"
    "skill orchestrat"
    "skills-first"
    "skill-index"
    "SKILL.md"
)

# ==============================================================================
# Logging
# ==============================================================================

log_info() {
    echo "[LEGACY-REPORT] [INFO] $(date -Iseconds) $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "[LEGACY-REPORT] [DEBUG] $(date -Iseconds) $*" >&2
    fi
}

log_warn() {
    echo "[LEGACY-REPORT] [WARN] $(date -Iseconds) $*" >&2
}

log_error() {
    echo "[LEGACY-REPORT] [ERROR] $(date -Iseconds) $*" >&2
}

# ==============================================================================
# Migration Log Management
# ==============================================================================

init_migration_log() {
    if [[ ! -f "$MIGRATION_LOG" ]]; then
        log_info "Initializing migration tracking log"
        mkdir -p "$(dirname "$MIGRATION_LOG")"
        cat > "$MIGRATION_LOG" << 'EOF'
{
  "version": "1.0.0",
  "description": "Migration tracking from legacy agent patterns to skills-first",
  "created": null,
  "updated": null,
  "config": {
    "target_completion": "2027-01-13",
    "warning_threshold": 0.20,
    "blocking_threshold": 0.05
  },
  "daily_tracking": [],
  "pattern_occurrences": {
    "legacy": [],
    "skills_first": []
  },
  "statistics": {
    "total_legacy_detected": 0,
    "total_skills_first_detected": 0,
    "migration_progress_pct": 0
  }
}
EOF
        local created_ts
        created_ts=$(date -Iseconds)
        jq --arg ts "$created_ts" '.created = $ts | .updated = $ts' "$MIGRATION_LOG" > "${MIGRATION_LOG}.tmp" && mv "${MIGRATION_LOG}.tmp" "$MIGRATION_LOG"
    fi
}

# ==============================================================================
# Pattern Detection
# ==============================================================================

# Scan file for legacy patterns
scan_file_for_legacy() {
    local file_path="${1:?File path required}"

    if [[ ! -f "$file_path" ]]; then
        return 0
    fi

    local matches=()

    for pattern in "${LEGACY_PATTERNS[@]}"; do
        local count
        count=$(grep -ciE "$pattern" "$file_path" 2>/dev/null || echo "0")
        if [[ "$count" -gt 0 ]]; then
            matches+=("$pattern:$count")
        fi
    done

    if [[ ${#matches[@]} -gt 0 ]]; then
        echo "${matches[*]}"
    fi
}

# Scan file for skills-first patterns
scan_file_for_skills_first() {
    local file_path="${1:?File path required}"

    if [[ ! -f "$file_path" ]]; then
        return 0
    fi

    local matches=()

    for pattern in "${SKILLS_FIRST_PATTERNS[@]}"; do
        local count
        count=$(grep -ciE "$pattern" "$file_path" 2>/dev/null || echo "0")
        if [[ "$count" -gt 0 ]]; then
            matches+=("$pattern:$count")
        fi
    done

    if [[ ${#matches[@]} -gt 0 ]]; then
        echo "${matches[*]}"
    fi
}

# Scan directory for patterns
scan_directory() {
    local directory="${1:?Directory required}"
    local file_pattern="${2:-*.md}"

    log_info "Scanning directory: $directory"

    local legacy_count=0
    local skills_first_count=0
    local files_with_legacy=()
    local files_with_skills_first=()

    while IFS= read -r -d '' file; do
        local legacy_matches
        legacy_matches=$(scan_file_for_legacy "$file")

        local skills_matches
        skills_matches=$(scan_file_for_skills_first "$file")

        if [[ -n "$legacy_matches" ]]; then
            local file_legacy_count
            file_legacy_count=$(echo "$legacy_matches" | tr ' ' '\n' | cut -d: -f2 | awk '{s+=$1} END {print s}')
            legacy_count=$((legacy_count + file_legacy_count))
            files_with_legacy+=("$file:$file_legacy_count")
        fi

        if [[ -n "$skills_matches" ]]; then
            local file_skills_count
            file_skills_count=$(echo "$skills_matches" | tr ' ' '\n' | cut -d: -f2 | awk '{s+=$1} END {print s}')
            skills_first_count=$((skills_first_count + file_skills_count))
            files_with_skills_first+=("$file:$file_skills_count")
        fi
    done < <(find "$directory" -name "$file_pattern" -type f -print0 2>/dev/null)

    jq -n \
        --arg directory "$directory" \
        --argjson legacy_count "$legacy_count" \
        --argjson skills_first_count "$skills_first_count" \
        --argjson legacy_files "$(printf '%s\n' "${files_with_legacy[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')" \
        --argjson skills_files "$(printf '%s\n' "${files_with_skills_first[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')" \
        '{
            "directory": $directory,
            "legacy_pattern_count": $legacy_count,
            "skills_first_pattern_count": $skills_first_count,
            "files_with_legacy_patterns": $legacy_files,
            "files_with_skills_first_patterns": $skills_files
        }'
}

# ==============================================================================
# Analysis
# ==============================================================================

# Analyze current architecture mode
analyze_mode() {
    log_info "Analyzing current architecture mode..."

    local current_mode="unknown"
    local legacy_warnings="unknown"
    local legacy_blocking="unknown"
    local migration_phase="unknown"

    if [[ -f "$ARCHITECTURE_CONF" ]]; then
        current_mode=$(grep -E "^ARCHITECTURE_MODE=" "$ARCHITECTURE_CONF" | cut -d= -f2 || echo "hybrid")
        legacy_warnings=$(grep -E "^LEGACY_WARNINGS=" "$ARCHITECTURE_CONF" | cut -d= -f2 || echo "true")
        legacy_blocking=$(grep -E "^LEGACY_BLOCKING=" "$ARCHITECTURE_CONF" | cut -d= -f2 || echo "false")
        migration_phase=$(grep -E "^MIGRATION_PHASE=" "$ARCHITECTURE_CONF" | cut -d= -f2 || echo "1")
    fi

    jq -n \
        --arg mode "$current_mode" \
        --arg warnings "$legacy_warnings" \
        --arg blocking "$legacy_blocking" \
        --arg phase "$migration_phase" \
        '{
            "current_mode": $mode,
            "legacy_warnings_enabled": ($warnings == "true"),
            "legacy_blocking_enabled": ($blocking == "true"),
            "migration_phase": ($phase | tonumber)
        }'
}

# Calculate migration progress
calculate_progress() {
    log_info "Calculating migration progress..."

    # Scan key directories
    local claude_scan
    claude_scan=$(scan_directory "${ROOT_DIR}/.claude" "*.md")

    local specify_scan
    specify_scan=$(scan_directory "${ROOT_DIR}/.specify" "*.md")

    local total_legacy
    total_legacy=$(echo "$claude_scan $specify_scan" | jq -s '[.[].legacy_pattern_count] | add')

    local total_skills_first
    total_skills_first=$(echo "$claude_scan $specify_scan" | jq -s '[.[].skills_first_pattern_count] | add')

    local total_patterns
    total_patterns=$((total_legacy + total_skills_first))

    local progress_pct
    if [[ "$total_patterns" -gt 0 ]]; then
        progress_pct=$(echo "scale=2; $total_skills_first * 100 / $total_patterns" | bc)
    else
        progress_pct="0"
    fi

    local legacy_ratio
    if [[ "$total_patterns" -gt 0 ]]; then
        legacy_ratio=$(echo "scale=4; $total_legacy / $total_patterns" | bc)
    else
        legacy_ratio="0"
    fi

    jq -n \
        --argjson legacy "$total_legacy" \
        --argjson skills_first "$total_skills_first" \
        --argjson total "$total_patterns" \
        --arg progress "$progress_pct" \
        --arg legacy_ratio "$legacy_ratio" \
        '{
            "legacy_pattern_count": $legacy,
            "skills_first_pattern_count": $skills_first,
            "total_patterns": $total,
            "migration_progress_pct": ($progress | tonumber),
            "legacy_ratio": ($legacy_ratio | tonumber),
            "assessment": (
                if ($progress | tonumber) >= 95 then "complete"
                elif ($progress | tonumber) >= 80 then "near_complete"
                elif ($progress | tonumber) >= 50 then "in_progress"
                elif ($progress | tonumber) >= 20 then "early_stage"
                else "not_started"
                end
            )
        }'
}

# ==============================================================================
# Reporting
# ==============================================================================

# Generate migration report
generate_report() {
    local format="${1:-json}"

    log_info "Generating migration report..."

    local mode
    mode=$(analyze_mode)

    local progress
    progress=$(calculate_progress)

    local claude_scan
    claude_scan=$(scan_directory "${ROOT_DIR}/.claude" "*.md")

    local specify_scan
    specify_scan=$(scan_directory "${ROOT_DIR}/.specify" "*.md")

    case "$format" in
        json)
            jq -n \
                --argjson mode "$mode" \
                --argjson progress "$progress" \
                --argjson claude_scan "$claude_scan" \
                --argjson specify_scan "$specify_scan" \
                '{
                    "report": {
                        "title": "Legacy Pattern Migration Report",
                        "generated": (now | todate),
                        "version": "1.0.0"
                    },
                    "architecture": $mode,
                    "migration_progress": $progress,
                    "scans": {
                        ".claude": $claude_scan,
                        ".specify": $specify_scan
                    },
                    "recommendations": (
                        if $progress.migration_progress_pct >= 80 then
                            ["Consider enabling LEGACY_BLOCKING=true"]
                        elif $progress.migration_progress_pct >= 50 then
                            ["Continue migrating legacy patterns", "Review files with highest legacy count"]
                        else
                            ["Focus on key agent files first", "Use migrate-agent-to-skill.sh tool"]
                        end
                    )
                }'
            ;;
        markdown)
            generate_markdown_report "$mode" "$progress" "$claude_scan" "$specify_scan"
            ;;
        summary)
            echo "$progress"
            ;;
        *)
            log_error "Unknown format: $format"
            return 1
            ;;
    esac
}

# Generate markdown report
generate_markdown_report() {
    local mode="${1}"
    local progress="${2}"
    local claude_scan="${3}"
    local specify_scan="${4}"

    cat << EOF
# Legacy Pattern Migration Report

**Generated**: $(date -Iseconds)
**Version**: 1.0.0

## Architecture Status

| Setting | Value |
|---------|-------|
| Current Mode | $(echo "$mode" | jq -r '.current_mode') |
| Legacy Warnings | $(echo "$mode" | jq -r '.legacy_warnings_enabled') |
| Legacy Blocking | $(echo "$mode" | jq -r '.legacy_blocking_enabled') |
| Migration Phase | $(echo "$mode" | jq -r '.migration_phase') |

## Migration Progress

| Metric | Value |
|--------|-------|
| Legacy Patterns | $(echo "$progress" | jq -r '.legacy_pattern_count') |
| Skills-First Patterns | $(echo "$progress" | jq -r '.skills_first_pattern_count') |
| Migration Progress | $(echo "$progress" | jq -r '.migration_progress_pct')% |
| Assessment | $(echo "$progress" | jq -r '.assessment') |

## Legacy Pattern Visualization

\`\`\`
Migration Progress: $(echo "$progress" | jq -r '.migration_progress_pct')%

[$(printf '=%.0s' $(seq 1 $(echo "$progress" | jq -r 'if .migration_progress_pct > 0 then (.migration_progress_pct / 2 | floor) else 0 end')))$(printf ' %.0s' $(seq 1 $(echo "$progress" | jq -r '50 - (if .migration_progress_pct > 0 then (.migration_progress_pct / 2 | floor) else 0 end)'))))]

Skills-First: $(echo "$progress" | jq -r '.skills_first_pattern_count') | Legacy: $(echo "$progress" | jq -r '.legacy_pattern_count')
\`\`\`

## Scan Results

### .claude Directory

- Legacy Patterns: $(echo "$claude_scan" | jq -r '.legacy_pattern_count')
- Skills-First Patterns: $(echo "$claude_scan" | jq -r '.skills_first_pattern_count')

**Files with Legacy Patterns:**
$(echo "$claude_scan" | jq -r '.files_with_legacy_patterns[] // "None"')

### .specify Directory

- Legacy Patterns: $(echo "$specify_scan" | jq -r '.legacy_pattern_count')
- Skills-First Patterns: $(echo "$specify_scan" | jq -r '.skills_first_pattern_count')

**Files with Legacy Patterns:**
$(echo "$specify_scan" | jq -r '.files_with_legacy_patterns[] // "None"')

## Recommendations

$(
    progress_pct=$(echo "$progress" | jq -r '.migration_progress_pct')
    if (( $(echo "$progress_pct >= 80" | bc -l) )); then
        echo "1. Consider enabling \`LEGACY_BLOCKING=true\` in architecture.conf"
        echo "2. Final review of remaining legacy patterns"
        echo "3. Update documentation to reflect skills-first completion"
    elif (( $(echo "$progress_pct >= 50" | bc -l) )); then
        echo "1. Continue migrating legacy patterns to skills-first"
        echo "2. Review files with highest legacy pattern counts"
        echo "3. Use migrate-agent-to-skill.sh for remaining agents"
    else
        echo "1. Focus on migrating key agent files first"
        echo "2. Use migrate-agent-to-skill.sh tool for batch migration"
        echo "3. Update CLAUDE.md with skills-first references"
    fi
)

## Next Steps

1. Run \`migrate-agent-to-skill.sh\` on remaining legacy agents
2. Update agent references to consolidated agents
3. Verify skill-index.json includes all new skills
4. Re-run this report to track progress

---

*Report generated by legacy-pattern-report.sh v1.0.0*
EOF
}

# Track daily progress
track_daily() {
    log_info "Recording daily migration progress..."

    init_migration_log

    local progress
    progress=$(calculate_progress)

    local timestamp
    timestamp=$(date -Iseconds)

    local date_key
    date_key=$(date +%Y-%m-%d)

    jq --arg date "$date_key" \
       --argjson progress "$progress" \
       --arg ts "$timestamp" \
       '
       # Add or update daily tracking
       .daily_tracking = (
           [.daily_tracking[] | select(.date != $date)] +
           [{
               "date": $date,
               "legacy_count": $progress.legacy_pattern_count,
               "skills_first_count": $progress.skills_first_pattern_count,
               "progress_pct": $progress.migration_progress_pct,
               "timestamp": $ts
           }]
       ) |
       # Keep last 90 days
       .daily_tracking = (.daily_tracking | sort_by(.date) | .[-90:]) |
       # Update statistics
       .statistics.total_legacy_detected = $progress.legacy_pattern_count |
       .statistics.total_skills_first_detected = $progress.skills_first_pattern_count |
       .statistics.migration_progress_pct = $progress.migration_progress_pct |
       .updated = $ts
       ' "$MIGRATION_LOG" > "${MIGRATION_LOG}.tmp" && mv "${MIGRATION_LOG}.tmp" "$MIGRATION_LOG"

    log_info "Daily progress recorded: $(echo "$progress" | jq -r '.migration_progress_pct')%"
    echo "$progress"
}

# ==============================================================================
# Main Entry Point
# ==============================================================================

show_usage() {
    cat << EOF
Legacy Pattern Migration Report Tool

Usage: $(basename "$0") <command> [options]

Commands:
  report [format]        Generate migration report (json|markdown|summary)
  progress              Calculate migration progress only
  mode                  Show current architecture mode
  scan <directory>      Scan specific directory for patterns
  track                 Record daily progress to migration log
  history               Show migration history

Options:
  --help          Show this help message
  --debug         Enable debug logging

Examples:
  # Get migration progress
  $(basename "$0") progress

  # Generate markdown report
  $(basename "$0") report markdown > migration-report.md

  # Scan specific directory
  $(basename "$0") scan .claude/agents

  # Track daily progress
  $(basename "$0") track

Legacy Patterns Detected:
  - "delegate to.*agent"
  - "invoke.*agent directly"
  - "call.*specialist"
  - "use.*agent"

Skills-First Patterns Detected:
  - "activate skill"
  - "invoke skill"
  - "skills-first"
  - "SKILL.md"

EOF
}

main() {
    local command="${1:-}"

    case "$command" in
        report)
            shift
            generate_report "${1:-json}"
            ;;
        progress)
            calculate_progress
            ;;
        mode)
            analyze_mode
            ;;
        scan)
            shift
            scan_directory "${1:?Directory required}" "${2:-*.md}"
            ;;
        track)
            track_daily
            ;;
        history)
            init_migration_log
            jq '.daily_tracking' "$MIGRATION_LOG"
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
