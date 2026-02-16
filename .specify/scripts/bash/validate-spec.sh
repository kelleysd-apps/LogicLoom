#!/bin/bash
# Specification Validation Script
#
# Validates specification files for completeness, structure, and quality
# based on constitutional requirements and best practices

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"

# Source common functions
source "$SCRIPT_DIR/common.sh"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
JSON_MODE=false
VERBOSE=false
SPEC_FILE=""
STRICT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_MODE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --strict)
            STRICT=true
            shift
            ;;
        --file|-f)
            SPEC_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --json              Output in JSON format"
            echo "  --verbose, -v       Verbose output"
            echo "  --strict            Enable strict validation (all checks must pass)"
            echo "  --file, -f FILE     Specification file to validate"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --file specs/001-feature/spec.md"
            echo "  $0 --strict --file specs/002-auth/spec.md"
            exit 0
            ;;
        *)
            SPEC_FILE="$1"
            shift
            ;;
    esac
done

# Auto-detect spec file if not provided
if [ -z "$SPEC_FILE" ]; then
    eval $(get_feature_paths)
    SPEC_FILE="$FEATURE_SPEC"
fi

# Validate file exists
if [ ! -f "$SPEC_FILE" ]; then
    echo "ERROR: Specification file not found: $SPEC_FILE" >&2
    exit 1
fi

# Initialize validation results
declare -A CHECKS
declare -A RESULTS
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Define validation checks
validate_file_not_empty() {
    local size=$(stat -f%z "$SPEC_FILE" 2>/dev/null || stat -c%s "$SPEC_FILE" 2>/dev/null)
    if [ "$size" -gt 100 ]; then
        return 0
    else
        return 1
    fi
}

validate_has_title() {
    grep -qE "^# " "$SPEC_FILE"
}

validate_has_overview() {
    grep -qiE "(## overview|## summary|## description)" "$SPEC_FILE"
}

validate_has_requirements() {
    grep -qiE "(## requirements|## functional requirements|## user stories)" "$SPEC_FILE"
}

validate_has_acceptance_criteria() {
    grep -qiE "(## acceptance criteria|## success criteria|## definition of done)" "$SPEC_FILE"
}

validate_has_user_stories() {
    grep -qiE "(as a|user story|user stories)" "$SPEC_FILE"
}

validate_has_non_functional() {
    grep -qiE "(## non-functional|## constraints|## assumptions|## dependencies)" "$SPEC_FILE"
}

validate_has_scope() {
    grep -qiE "(## scope|## in scope|## out of scope)" "$SPEC_FILE"
}

validate_reasonable_length() {
    local line_count=$(wc -l < "$SPEC_FILE")
    if [ "$line_count" -ge 50 ]; then
        return 0
    else
        return 1
    fi
}

validate_no_todos() {
    if grep -qiE "TODO|FIXME|XXX|HACK" "$SPEC_FILE"; then
        return 1
    else
        return 0
    fi
}

# Run validation checks
run_check() {
    local check_name="$1"
    local check_func="$2"
    local severity="$3"  # required, recommended, optional
    local description="$4"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    CHECKS["$check_name"]="$description"

    if $check_func; then
        RESULTS["$check_name"]="PASS"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        if [ "$severity" = "required" ]; then
            RESULTS["$check_name"]="FAIL"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            return 1
        else
            RESULTS["$check_name"]="WARN"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            return 0
        fi
    fi
}

# Execute validation checks
run_check "file_not_empty" validate_file_not_empty "required" "File has substantial content (>100 bytes)"
run_check "has_title" validate_has_title "required" "File has a title (# heading)"
run_check "has_overview" validate_has_overview "required" "Contains overview/summary section"
run_check "has_requirements" validate_has_requirements "required" "Contains requirements section"
run_check "has_acceptance_criteria" validate_has_acceptance_criteria "recommended" "Contains acceptance criteria"
run_check "has_user_stories" validate_has_user_stories "recommended" "Contains user stories"
run_check "has_non_functional" validate_has_non_functional "recommended" "Contains non-functional requirements"
run_check "has_scope" validate_has_scope "recommended" "Defines scope boundaries"
run_check "reasonable_length" validate_reasonable_length "recommended" "Has reasonable length (≥50 lines)"
run_check "no_todos" validate_no_todos "optional" "No TODO/FIXME placeholders"

# Calculate validation score
VALIDATION_SCORE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

# Determine overall status
OVERALL_STATUS="PASS"
if [ $FAILED_CHECKS -gt 0 ]; then
    OVERALL_STATUS="FAIL"
elif [ $WARNING_CHECKS -gt 3 ] && $STRICT; then
    OVERALL_STATUS="WARN"
fi

# Output results
if $JSON_MODE; then
    # JSON output
    echo "{"
    echo "  \"file\": \"$SPEC_FILE\","
    echo "  \"status\": \"$OVERALL_STATUS\","
    echo "  \"score\": $VALIDATION_SCORE,"
    echo "  \"total_checks\": $TOTAL_CHECKS,"
    echo "  \"passed\": $PASSED_CHECKS,"
    echo "  \"failed\": $FAILED_CHECKS,"
    echo "  \"warnings\": $WARNING_CHECKS,"
    echo "  \"checks\": {"

    first=true
    for check in "${!CHECKS[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        result="${RESULTS[$check]}"
        description="${CHECKS[$check]}"
        echo -n "    \"$check\": {\"result\": \"$result\", \"description\": \"$description\"}"
    done
    echo ""
    echo "  }"
    echo "}"
else
    # Human-readable output
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Specification Validation${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
    echo -e "${GREEN}File:${NC} $SPEC_FILE"
    echo -e "${GREEN}Status:${NC} $OVERALL_STATUS"
    echo -e "${GREEN}Score:${NC} $VALIDATION_SCORE%"
    echo ""

    echo -e "${YELLOW}Results:${NC}"
    echo "  ✅ Passed: $PASSED_CHECKS/$TOTAL_CHECKS"
    if [ $FAILED_CHECKS -gt 0 ]; then
        echo -e "  ${RED}❌ Failed: $FAILED_CHECKS/$TOTAL_CHECKS${NC}"
    fi
    if [ $WARNING_CHECKS -gt 0 ]; then
        echo -e "  ${YELLOW}⚠  Warnings: $WARNING_CHECKS/$TOTAL_CHECKS${NC}"
    fi
    echo ""

    if $VERBOSE || [ $FAILED_CHECKS -gt 0 ] || [ $WARNING_CHECKS -gt 0 ]; then
        echo -e "${BLUE}Detailed Results:${NC}"
        for check in "${!CHECKS[@]}"; do
            result="${RESULTS[$check]}"
            description="${CHECKS[$check]}"

            if [ "$result" = "PASS" ]; then
                echo -e "  ${GREEN}✅ PASS${NC}: $description"
            elif [ "$result" = "FAIL" ]; then
                echo -e "  ${RED}❌ FAIL${NC}: $description"
            else
                echo -e "  ${YELLOW}⚠  WARN${NC}: $description"
            fi
        done
        echo ""
    fi

    # Provide recommendations
    if [ $FAILED_CHECKS -gt 0 ] || [ $WARNING_CHECKS -gt 0 ]; then
        echo -e "${YELLOW}Recommendations:${NC}"

        if [ "${RESULTS[has_acceptance_criteria]}" != "PASS" ]; then
            echo "  • Add acceptance criteria to define success metrics"
        fi
        if [ "${RESULTS[has_user_stories]}" != "PASS" ]; then
            echo "  • Include user stories in 'As a... I want... So that...' format"
        fi
        if [ "${RESULTS[has_non_functional]}" != "PASS" ]; then
            echo "  • Document non-functional requirements (performance, security, etc.)"
        fi
        if [ "${RESULTS[has_scope]}" != "PASS" ]; then
            echo "  • Define what is in scope and out of scope"
        fi
        if [ "${RESULTS[reasonable_length]}" != "PASS" ]; then
            echo "  • Expand specification with more detail (currently < 50 lines)"
        fi
        if [ "${RESULTS[no_todos]}" != "PASS" ]; then
            echo "  • Remove TODO/FIXME placeholders or complete them"
        fi
    fi

    if [ "$OVERALL_STATUS" = "PASS" ]; then
        echo -e "${GREEN}✅ Specification validation passed!${NC}"
    elif [ "$OVERALL_STATUS" = "FAIL" ]; then
        echo -e "${RED}❌ Specification validation failed. Address required checks above.${NC}"
    else
        echo -e "${YELLOW}⚠  Specification has warnings. Consider addressing recommendations.${NC}"
    fi
fi

# Exit with appropriate code
if [ "$OVERALL_STATUS" = "FAIL" ]; then
    exit 1
elif [ "$OVERALL_STATUS" = "WARN" ] && $STRICT; then
    exit 2
else
    exit 0
fi
