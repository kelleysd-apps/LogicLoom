#!/usr/bin/env bash
# Governance Metrics Generator
# Analyzes audit logs and generates compliance metrics
# Constitutional Principle VII: Observability & Structured Logging
# Version: 1.0.0

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AUDIT_DIR="$REPO_ROOT/.docs/governance/audit"

# Default values
OUTPUT_FORMAT="text"
DATE_RANGE="all"
START_DATE=""
END_DATE=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# Functions
# ============================================

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Generate governance metrics from audit logs.

OPTIONS:
    --format FORMAT     Output format: text (default) or markdown
    --date YYYY-MM-DD   Show metrics for specific date
    --start YYYY-MM-DD  Start date for date range
    --end YYYY-MM-DD    End date for date range
    --help              Show this help message

EXAMPLES:
    # Show all-time metrics (text format)
    $0

    # Show metrics for specific date
    $0 --date 2025-12-19

    # Show metrics for date range
    $0 --start 2025-12-01 --end 2025-12-19

    # Generate markdown report
    $0 --format markdown

Constitutional Compliance:
    ✅ Principle VII: Observability (metrics reporting)
    ✅ Principle VI: No git operations

EOF
    exit 0
}

# ============================================
# Argument Parsing
# ============================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --date)
            DATE_RANGE="single"
            START_DATE="$2"
            END_DATE="$2"
            shift 2
            ;;
        --start)
            DATE_RANGE="range"
            START_DATE="$2"
            shift 2
            ;;
        --end)
            END_DATE="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# ============================================
# Validation
# ============================================

if [ ! -d "$AUDIT_DIR" ]; then
    echo -e "${RED}❌ Audit directory not found: $AUDIT_DIR${NC}"
    echo ""
    echo "No audit logs to analyze."
    echo "Audit logs will be created when the governance hook is used."
    exit 1
fi

# ============================================
# Data Collection
# ============================================

# Find all session files based on date range
SESSION_FILES=""

if [ "$DATE_RANGE" = "all" ]; then
    SESSION_FILES=$(find "$AUDIT_DIR" -type f -name "session-*.json" 2>/dev/null || echo "")
elif [ "$DATE_RANGE" = "single" ] || [ "$DATE_RANGE" = "range" ]; then
    # Build find command for date range
    for date_dir in "$AUDIT_DIR"/*; do
        [ -d "$date_dir" ] || continue

        dir_date=$(basename "$date_dir")

        # Check if directory is within range
        include=false
        if [ "$DATE_RANGE" = "single" ]; then
            [ "$dir_date" = "$START_DATE" ] && include=true
        elif [ "$DATE_RANGE" = "range" ]; then
            if [ -n "$START_DATE" ] && [ -n "$END_DATE" ]; then
                [[ ! "$dir_date" < "$START_DATE" ]] && [[ ! "$dir_date" > "$END_DATE" ]] && include=true
            elif [ -n "$START_DATE" ]; then
                [[ ! "$dir_date" < "$START_DATE" ]] && include=true
            elif [ -n "$END_DATE" ]; then
                [[ ! "$dir_date" > "$END_DATE" ]] && include=true
            fi
        fi

        if [ "$include" = true ]; then
            SESSION_FILES="$SESSION_FILES $(find "$date_dir" -type f -name "session-*.json" 2>/dev/null || echo "")"
        fi
    done
fi

if [ -z "$SESSION_FILES" ]; then
    echo -e "${YELLOW}⚠️  No audit logs found for the specified date range${NC}"
    exit 0
fi

# ============================================
# Metrics Calculation
# ============================================

TOTAL_EVENTS=0
EVENT_TYPES=()
DECISION_TYPES=()
LAYERS=()

declare -A EVENT_TYPE_COUNT
declare -A DECISION_TYPE_COUNT
declare -A LAYER_COUNT

# Process each session file
for session_file in $SESSION_FILES; do
    [ -f "$session_file" ] || continue

    if command -v jq >/dev/null 2>&1; then
        # Use jq if available
        EVENT_TYPE=$(jq -r '.event_type // "unknown"' "$session_file" 2>/dev/null || echo "unknown")
        DECISION_TYPE=$(jq -r '.decision_type // "unknown"' "$session_file" 2>/dev/null || echo "unknown")
        LAYER=$(jq -r '.layer // "unknown"' "$session_file" 2>/dev/null || echo "unknown")
    else
        # Pure bash fallback
        EVENT_TYPE=$(grep -o '"event_type"[[:space:]]*:[[:space:]]*"[^"]*"' "$session_file" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "unknown")
        DECISION_TYPE=$(grep -o '"decision_type"[[:space:]]*:[[:space:]]*"[^"]*"' "$session_file" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "unknown")
        LAYER=$(grep -o '"layer"[[:space:]]*:[[:space:]]*"[^"]*"' "$session_file" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "unknown")
    fi

    ((TOTAL_EVENTS++))

    # Count by event type
    EVENT_TYPE_COUNT[$EVENT_TYPE]=$((${EVENT_TYPE_COUNT[$EVENT_TYPE]:-0} + 1))

    # Count by decision type
    DECISION_TYPE_COUNT[$DECISION_TYPE]=$((${DECISION_TYPE_COUNT[$DECISION_TYPE]:-0} + 1))

    # Count by layer
    LAYER_COUNT[$LAYER]=$((${LAYER_COUNT[$LAYER]:-0} + 1))
done

# ============================================
# Output Generation
# ============================================

if [ "$OUTPUT_FORMAT" = "markdown" ]; then
    # Markdown format
    echo "# Governance Metrics Report"
    echo ""
    echo "**Generated**: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "**Period**: $( [ "$DATE_RANGE" = "all" ] && echo "All time" || echo "$START_DATE to $END_DATE" )"
    echo "**Total Events**: $TOTAL_EVENTS"
    echo ""

    echo "## Event Type Distribution"
    echo ""
    echo "| Event Type | Count | Percentage |"
    echo "|------------|-------|------------|"
    for event_type in "${!EVENT_TYPE_COUNT[@]}"; do
        count=${EVENT_TYPE_COUNT[$event_type]}
        percentage=$((count * 100 / TOTAL_EVENTS))
        echo "| $event_type | $count | $percentage% |"
    done
    echo ""

    echo "## Decision Type Distribution"
    echo ""
    echo "| Decision Type | Count | Percentage |"
    echo "|---------------|-------|------------|"
    for decision_type in "${!DECISION_TYPE_COUNT[@]}"; do
        count=${DECISION_TYPE_COUNT[$decision_type]}
        percentage=$((count * 100 / TOTAL_EVENTS))
        echo "| $decision_type | $count | $percentage% |"
    done
    echo ""

    echo "## Layer Distribution"
    echo ""
    echo "| Layer | Count | Percentage |"
    echo "|-------|-------|------------|"
    for layer in "${!LAYER_COUNT[@]}"; do
        count=${LAYER_COUNT[$layer]}
        percentage=$((count * 100 / TOTAL_EVENTS))
        echo "| $layer | $count | $percentage% |"
    done
    echo ""

else
    # Text format (default)
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Governance Metrics Report${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Period: $( [ "$DATE_RANGE" = "all" ] && echo "All time" || echo "$START_DATE to $END_DATE" )"
    echo "Total Events: $TOTAL_EVENTS"
    echo ""

    echo -e "${BLUE}Event Type Distribution:${NC}"
    for event_type in "${!EVENT_TYPE_COUNT[@]}"; do
        count=${EVENT_TYPE_COUNT[$event_type]}
        percentage=$((count * 100 / TOTAL_EVENTS))
        printf "  %-30s %5d (%3d%%)\n" "$event_type" "$count" "$percentage"
    done
    echo ""

    echo -e "${BLUE}Decision Type Distribution:${NC}"
    for decision_type in "${!DECISION_TYPE_COUNT[@]}"; do
        count=${DECISION_TYPE_COUNT[$decision_type]}
        percentage=$((count * 100 / TOTAL_EVENTS))
        printf "  %-30s %5d (%3d%%)\n" "$decision_type" "$count" "$percentage"
    done
    echo ""

    echo -e "${BLUE}Layer Distribution:${NC}"
    for layer in "${!LAYER_COUNT[@]}"; do
        count=${LAYER_COUNT[$layer]}
        percentage=$((count * 100 / TOTAL_EVENTS))
        printf "  %-30s %5d (%3d%%)\n" "$layer" "$count" "$percentage"
    done
    echo ""

    echo -e "${GREEN}✅ Metrics report complete${NC}"
    echo ""
fi

exit 0
