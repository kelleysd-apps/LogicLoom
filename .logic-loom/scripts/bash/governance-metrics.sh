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

# Per-key counters.
#
# bash 3.2 (stock macOS `/bin/bash`) has no associative arrays and this repo
# declares 3.2 the floor for `.logic-loom/scripts/` — see
# `.docs/policies/shell-idiom-policy.md`. Keys here are DYNAMIC (they come out
# of the audit JSON), so a `case` won't do: each counter is two parallel
# indexed arrays with a linear upsert. Keys land in FIRST-SEEN order, where
# `${!EVENT_TYPE_COUNT[@]}` used bash's hash order.
#
# Deliberately three near-identical functions rather than one `eval`-driven
# helper: the keys are untrusted log content, and `eval` on them is exactly the
# indirection a shell should not be doing.
EVENT_TYPE_KEYS=();    EVENT_TYPE_VALS=()
DECISION_TYPE_KEYS=(); DECISION_TYPE_VALS=()
LAYER_KEYS=();         LAYER_VALS=()

bump_event_type() {
    local key="$1" i=0 n=${#EVENT_TYPE_KEYS[@]}
    while [ "$i" -lt "$n" ]; do
        if [ "${EVENT_TYPE_KEYS[$i]}" = "$key" ]; then
            EVENT_TYPE_VALS[$i]=$(( ${EVENT_TYPE_VALS[$i]} + 1 ))
            return 0
        fi
        i=$((i + 1))
    done
    EVENT_TYPE_KEYS[$n]="$key"
    EVENT_TYPE_VALS[$n]=1
}

bump_decision_type() {
    local key="$1" i=0 n=${#DECISION_TYPE_KEYS[@]}
    while [ "$i" -lt "$n" ]; do
        if [ "${DECISION_TYPE_KEYS[$i]}" = "$key" ]; then
            DECISION_TYPE_VALS[$i]=$(( ${DECISION_TYPE_VALS[$i]} + 1 ))
            return 0
        fi
        i=$((i + 1))
    done
    DECISION_TYPE_KEYS[$n]="$key"
    DECISION_TYPE_VALS[$n]=1
}

bump_layer() {
    local key="$1" i=0 n=${#LAYER_KEYS[@]}
    while [ "$i" -lt "$n" ]; do
        if [ "${LAYER_KEYS[$i]}" = "$key" ]; then
            LAYER_VALS[$i]=$(( ${LAYER_VALS[$i]} + 1 ))
            return 0
        fi
        i=$((i + 1))
    done
    LAYER_KEYS[$n]="$key"
    LAYER_VALS[$n]=1
}

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

    # NOT `((TOTAL_EVENTS++))`: post-increment evaluates to the OLD value, so
    # the very first event returns 0 -> status 1 -> `set -e` kills the script.
    TOTAL_EVENTS=$((TOTAL_EVENTS + 1))

    # Count by event type
    bump_event_type "$EVENT_TYPE"

    # Count by decision type
    bump_decision_type "$DECISION_TYPE"

    # Count by layer
    bump_layer "$LAYER"
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
    _i=0
    while [ "$_i" -lt "${#EVENT_TYPE_KEYS[@]}" ]; do
        event_type="${EVENT_TYPE_KEYS[$_i]}"
        count=${EVENT_TYPE_VALS[$_i]}
        percentage=$((count * 100 / TOTAL_EVENTS))
        echo "| $event_type | $count | $percentage% |"
        _i=$((_i + 1))
    done
    echo ""

    echo "## Decision Type Distribution"
    echo ""
    echo "| Decision Type | Count | Percentage |"
    echo "|---------------|-------|------------|"
    _i=0
    while [ "$_i" -lt "${#DECISION_TYPE_KEYS[@]}" ]; do
        decision_type="${DECISION_TYPE_KEYS[$_i]}"
        count=${DECISION_TYPE_VALS[$_i]}
        percentage=$((count * 100 / TOTAL_EVENTS))
        echo "| $decision_type | $count | $percentage% |"
        _i=$((_i + 1))
    done
    echo ""

    echo "## Layer Distribution"
    echo ""
    echo "| Layer | Count | Percentage |"
    echo "|-------|-------|------------|"
    _i=0
    while [ "$_i" -lt "${#LAYER_KEYS[@]}" ]; do
        layer="${LAYER_KEYS[$_i]}"
        count=${LAYER_VALS[$_i]}
        percentage=$((count * 100 / TOTAL_EVENTS))
        echo "| $layer | $count | $percentage% |"
        _i=$((_i + 1))
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
    _i=0
    while [ "$_i" -lt "${#EVENT_TYPE_KEYS[@]}" ]; do
        event_type="${EVENT_TYPE_KEYS[$_i]}"
        count=${EVENT_TYPE_VALS[$_i]}
        percentage=$((count * 100 / TOTAL_EVENTS))
        printf "  %-30s %5d (%3d%%)\n" "$event_type" "$count" "$percentage"
        _i=$((_i + 1))
    done
    echo ""

    echo -e "${BLUE}Decision Type Distribution:${NC}"
    _i=0
    while [ "$_i" -lt "${#DECISION_TYPE_KEYS[@]}" ]; do
        decision_type="${DECISION_TYPE_KEYS[$_i]}"
        count=${DECISION_TYPE_VALS[$_i]}
        percentage=$((count * 100 / TOTAL_EVENTS))
        printf "  %-30s %5d (%3d%%)\n" "$decision_type" "$count" "$percentage"
        _i=$((_i + 1))
    done
    echo ""

    echo -e "${BLUE}Layer Distribution:${NC}"
    _i=0
    while [ "$_i" -lt "${#LAYER_KEYS[@]}" ]; do
        layer="${LAYER_KEYS[$_i]}"
        count=${LAYER_VALS[$_i]}
        percentage=$((count * 100 / TOTAL_EVENTS))
        printf "  %-30s %5d (%3d%%)\n" "$layer" "$count" "$percentage"
        _i=$((_i + 1))
    done
    echo ""

    echo -e "${GREEN}✅ Metrics report complete${NC}"
    echo ""
fi

exit 0
