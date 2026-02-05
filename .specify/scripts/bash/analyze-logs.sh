#!/usr/bin/env bash
# Log Analysis Utility for SDD Framework
# Constitutional Principle VII: Observability and Structured Logging
#
# Analyzes structured JSON logs to generate summaries, metrics, and reports
#
# Usage:
#   ./analyze-logs.sh                     # Analyze today's logs
#   ./analyze-logs.sh --date 2025-01-09   # Analyze specific date
#   ./analyze-logs.sh --level ERROR       # Filter by log level
#   ./analyze-logs.sh --operation create-feature  # Filter by operation
#   ./analyze-logs.sh --export metrics    # Export metrics summary
#   ./analyze-logs.sh --help              # Show help

set -e

# ==============================================================================
# Configuration
# ==============================================================================

# Get repository root (works from any location)
if REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
    : # git command succeeded
else
    # Fallback if not in git repo
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fi

LOG_DIR="$REPO_ROOT/.specify/logs"
OUTPUT_DIR="$LOG_DIR/analysis"
OUTPUT_DIR="$LOG_DIR/analysis"

# Default filters
FILTER_DATE=$(date +%Y-%m-%d)
FILTER_LEVEL=""
FILTER_OPERATION=""
EXPORT_FORMAT="console"

# Color codes
COLOR_RESET='\033[0m'
COLOR_BOLD='\033[1m'
COLOR_BLUE='\033[0;34m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_RED='\033[0;31m'

# ==============================================================================
# Helper Functions
# ==============================================================================

show_help() {
    cat <<EOF
${COLOR_BOLD}SDD Framework Log Analysis Utility${COLOR_RESET}

Analyzes structured JSON logs to generate summaries, metrics, and reports.

${COLOR_BOLD}USAGE:${COLOR_RESET}
    $(basename "$0") [OPTIONS]

${COLOR_BOLD}OPTIONS:${COLOR_RESET}
    --date DATE          Analyze logs from specific date (YYYY-MM-DD)
                         Default: today (${FILTER_DATE})

    --level LEVEL        Filter by log level (DEBUG, INFO, WARN, ERROR)
                         Default: all levels

    --operation OP       Filter by operation name
                         Default: all operations

    --export FORMAT      Export format: console, json, csv, metrics
                         Default: console

    --help               Show this help message

${COLOR_BOLD}EXAMPLES:${COLOR_RESET}
    # Analyze today's logs
    $(basename "$0")

    # Analyze specific date
    $(basename "$0") --date 2025-01-09

    # Show only errors
    $(basename "$0") --level ERROR

    # Show create-feature operations
    $(basename "$0") --operation create-feature

    # Export metrics to JSON
    $(basename "$0") --export metrics

${COLOR_BOLD}OUTPUT:${COLOR_RESET}
    The utility generates:
    - Operation summaries (count, success rate, avg duration)
    - Error analysis (frequency, patterns)
    - Performance metrics (timing statistics)
    - Git operation audit trail

EOF
}

# Check if log file exists
check_log_file() {
    local log_file="$LOG_DIR/operations/${FILTER_DATE}.log"
    if [[ ! -f "$log_file" ]]; then
        echo -e "${COLOR_RED}Error: No log file found for date: ${FILTER_DATE}${COLOR_RESET}" >&2
        echo "Expected file: $log_file" >&2
        exit 1
    fi
    echo "$log_file"
}

# Parse JSON log line
parse_json_field() {
    local json="$1"
    local field="$2"

    # Simple JSON extraction (works for non-nested fields)
    echo "$json" | grep -oP "\"$field\":\s*\"?\K[^,}\"]*" | head -1
}

# Filter logs by level
filter_by_level() {
    local log_file="$1"
    if [[ -n "$FILTER_LEVEL" ]]; then
        grep "\"level\":\"$FILTER_LEVEL\"" "$log_file" || true
    else
        cat "$log_file"
    fi
}

# Filter logs by operation
filter_by_operation() {
    if [[ -n "$FILTER_OPERATION" ]]; then
        grep "\"operation\":\"$FILTER_OPERATION\"" || true
    else
        cat
    fi
}

# ==============================================================================
# Analysis Functions
# ==============================================================================

# Generate operation summary
analyze_operations() {
    local filtered_logs="$1"

    echo -e "\n${COLOR_BOLD}=== Operation Summary ===${COLOR_RESET}\n"

    # Count operations by type
    local operations=$(echo "$filtered_logs" | grep '"operation":' | \
        grep -oP '"operation":\s*"\K[^"]+' | sort | uniq -c | sort -rn)

    if [[ -z "$operations" ]]; then
        echo "No operations found."
        return
    fi

    printf "%-10s %s\n" "Count" "Operation"
    printf "%-10s %s\n" "-----" "---------"
    echo "$operations" | while read count op; do
        printf "${COLOR_BLUE}%-10s${COLOR_RESET} %s\n" "$count" "$op"
    done
}

# Analyze operation timing
analyze_timing() {
    local filtered_logs="$1"

    echo -e "\n${COLOR_BOLD}=== Operation Timing ===${COLOR_RESET}\n"

    # Extract completed operations with duration
    local timing_data=$(echo "$filtered_logs" | grep '"phase":"end"' | grep '"duration_ms":')

    if [[ -z "$timing_data" ]]; then
        echo "No timing data found."
        return
    fi

    # Group by operation and calculate stats
    declare -A operation_durations
    declare -A operation_counts

    while IFS= read -r line; do
        local op=$(echo "$line" | grep -oP '"operation":\s*"\K[^"]+')
        local duration=$(echo "$line" | grep -oP '"duration_ms":\s*\K[0-9]+')

        if [[ -n "$op" && -n "$duration" ]]; then
            operation_durations["$op"]="${operation_durations[$op]:-0}+$duration"
            operation_counts["$op"]=$((${operation_counts[$op]:-0} + 1))
        fi
    done <<< "$timing_data"

    # Display timing summary
    printf "%-30s %-10s %-15s %-15s\n" "Operation" "Count" "Avg Duration" "Total Time"
    printf "%-30s %-10s %-15s %-15s\n" "---------" "-----" "------------" "----------"

    for op in "${!operation_counts[@]}"; do
        local total=$(echo "${operation_durations[$op]}" | bc)
        local count=${operation_counts[$op]}
        local avg=$((total / count))
        printf "${COLOR_GREEN}%-30s${COLOR_RESET} %-10s %-15s %-15s\n" \
            "$op" "$count" "${avg}ms" "${total}ms"
    done
}

# Analyze errors
analyze_errors() {
    local filtered_logs="$1"

    echo -e "\n${COLOR_BOLD}=== Error Analysis ===${COLOR_RESET}\n"

    local errors=$(echo "$filtered_logs" | grep '"level":"ERROR"')

    if [[ -z "$errors" ]]; then
        echo -e "${COLOR_GREEN}No errors found.${COLOR_RESET}"
        return
    fi

    local error_count=$(echo "$errors" | wc -l)
    echo -e "${COLOR_RED}Total Errors: $error_count${COLOR_RESET}\n"

    # Show error messages
    echo "Recent Errors:"
    echo "$errors" | tail -10 | while IFS= read -r line; do
        local message=$(echo "$line" | grep -oP '"message":\s*"\K[^"]+')
        local timestamp=$(echo "$line" | grep -oP '"timestamp":\s*"\K[^"]+')
        echo -e "  ${COLOR_YELLOW}[$timestamp]${COLOR_RESET} $message"
    done
}

# Analyze git operations
analyze_git_operations() {
    local filtered_logs="$1"

    echo -e "\n${COLOR_BOLD}=== Git Operation Audit Trail ===${COLOR_RESET}\n"

    local git_ops=$(echo "$filtered_logs" | grep 'Git operation')

    if [[ -z "$git_ops" ]]; then
        echo "No git operations found."
        return
    fi

    local total_ops=$(echo "$git_ops" | wc -l)
    local approved=$(echo "$git_ops" | grep '"user_approved":true' | wc -l)
    local denied=$(echo "$git_ops" | grep '"user_approved":false' | wc -l)

    echo "Total Git Operations: $total_ops"
    echo -e "${COLOR_GREEN}Approved: $approved${COLOR_RESET}"
    echo -e "${COLOR_RED}Denied: $denied${COLOR_RESET}"

    # Show recent git operations
    echo -e "\nRecent Git Operations:"
    echo "$git_ops" | tail -5 | while IFS= read -r line; do
        local message=$(echo "$line" | grep -oP '"message":\s*"\K[^"]+')
        local timestamp=$(echo "$line" | grep -oP '"timestamp":\s*"\K[^"]+')
        local approved=$(echo "$line" | grep -q '"user_approved":true' && echo "✓" || echo "✗")
        echo -e "  ${COLOR_YELLOW}[$timestamp]${COLOR_RESET} $approved $message"
    done
}

# Generate metrics export
export_metrics() {
    local filtered_logs="$1"

    echo -e "\n${COLOR_BOLD}=== Metrics Export ===${COLOR_RESET}\n"

    local total_logs=$(echo "$filtered_logs" | wc -l)
    local info_count=$(echo "$filtered_logs" | grep -c '"level":"INFO"' || echo 0)
    local warn_count=$(echo "$filtered_logs" | grep -c '"level":"WARN"' || echo 0)
    local error_count=$(echo "$filtered_logs" | grep -c '"level":"ERROR"' || echo 0)
    local debug_count=$(echo "$filtered_logs" | grep -c '"level":"DEBUG"' || echo 0)

    if [[ "$EXPORT_FORMAT" == "json" ]]; then
        cat <<EOF
{
  "date": "$FILTER_DATE",
  "total_logs": $total_logs,
  "log_levels": {
    "info": $info_count,
    "warn": $warn_count,
    "error": $error_count,
    "debug": $debug_count
  },
  "operations": {
    "total": $(echo "$filtered_logs" | grep -c '"operation":' || echo 0)
  }
}
EOF
    elif [[ "$EXPORT_FORMAT" == "csv" ]]; then
        echo "metric,value"
        echo "date,$FILTER_DATE"
        echo "total_logs,$total_logs"
        echo "info_logs,$info_count"
        echo "warn_logs,$warn_count"
        echo "error_logs,$error_count"
        echo "debug_logs,$debug_count"
    else
        echo "Date: $FILTER_DATE"
        echo "Total Logs: $total_logs"
        echo "  INFO:  $info_count"
        echo "  WARN:  $warn_count"
        echo "  ERROR: $error_count"
        echo "  DEBUG: $debug_count"
    fi
}

# ==============================================================================
# Main Execution
# ==============================================================================

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --date)
            FILTER_DATE="$2"
            shift 2
            ;;
        --level)
            FILTER_LEVEL="$2"
            shift 2
            ;;
        --operation)
            FILTER_OPERATION="$2"
            shift 2
            ;;
        --export)
            EXPORT_FORMAT="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information." >&2
            exit 1
            ;;
    esac
done

# Main analysis
echo -e "${COLOR_BOLD}=========================================="
echo "SDD Framework Log Analysis"
echo -e "==========================================${COLOR_RESET}"
echo "Date: $FILTER_DATE"
[[ -n "$FILTER_LEVEL" ]] && echo "Level Filter: $FILTER_LEVEL"
[[ -n "$FILTER_OPERATION" ]] && echo "Operation Filter: $FILTER_OPERATION"

# Get log file
LOG_FILE=$(check_log_file)
echo "Log File: $LOG_FILE"

# Filter logs
FILTERED_LOGS=$(filter_by_level "$LOG_FILE" | filter_by_operation)

if [[ -z "$FILTERED_LOGS" ]]; then
    echo -e "\n${COLOR_YELLOW}No logs match the specified filters.${COLOR_RESET}"
    exit 0
fi

# Run analysis based on export format
if [[ "$EXPORT_FORMAT" == "metrics" || "$EXPORT_FORMAT" == "json" || "$EXPORT_FORMAT" == "csv" ]]; then
    export_metrics "$FILTERED_LOGS"
else
    analyze_operations "$FILTERED_LOGS"
    analyze_timing "$FILTERED_LOGS"
    analyze_errors "$FILTERED_LOGS"
    analyze_git_operations "$FILTERED_LOGS"
    export_metrics "$FILTERED_LOGS"
fi

echo -e "\n${COLOR_BOLD}Analysis complete.${COLOR_RESET}\n"
