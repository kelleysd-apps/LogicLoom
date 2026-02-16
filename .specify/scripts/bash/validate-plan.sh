#!/bin/bash
# Implementation Plan Validation Script
#
# Validates implementation plan files for completeness and alignment
# with constitutional principles (Library-First, Test-First, Contract-First)

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
PLAN_FILE=""
FEATURE_DIR=""
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
            PLAN_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --json              Output in JSON format"
            echo "  --verbose, -v       Verbose output"
            echo "  --strict            Enable strict validation"
            echo "  --file, -f FILE     Plan file to validate"
            echo "  --help, -h          Show this help message"
            exit 0
            ;;
        *)
            PLAN_FILE="$1"
            shift
            ;;
    esac
done

# Auto-detect plan file if not provided
if [ -z "$PLAN_FILE" ]; then
    eval $(get_feature_paths)
    PLAN_FILE="$IMPL_PLAN"
    FEATURE_DIR="$FEATURE_DIR"
else
    FEATURE_DIR=$(dirname "$PLAN_FILE")
fi

# Validate file exists
if [ ! -f "$PLAN_FILE" ]; then
    echo "ERROR: Plan file not found: $PLAN_FILE" >&2
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
    local size=$(stat -f%z "$PLAN_FILE" 2>/dev/null || stat -c%s "$PLAN_FILE" 2>/dev/null)
    [ "$size" -gt 200 ]
}

validate_has_title() {
    grep -qE "^# " "$PLAN_FILE"
}

validate_has_architecture() {
    grep -qiE "(## architecture|## system design|## technical approach)" "$PLAN_FILE"
}

validate_has_tech_stack() {
    grep -qiE "(## tech stack|## technology|## technologies|## tools)" "$PLAN_FILE"
}

validate_mentions_library_first() {
    grep -qiE "(library|package|module|reusable)" "$PLAN_FILE"
}

validate_mentions_testing() {
    grep -qiE "(test|testing|TDD|jest|vitest|playwright|cypress)" "$PLAN_FILE"
}

validate_mentions_contracts() {
    grep -qiE "(contract|API|interface|schema)" "$PLAN_FILE"
}

validate_has_data_model_reference() {
    grep -qiE "(data model|entity|database|schema)" "$PLAN_FILE" || [ -f "$FEATURE_DIR/data-model.md" ]
}

validate_has_contracts_reference() {
    grep -qiE "(contract|API spec|endpoint)" "$PLAN_FILE" || [ -d "$FEATURE_DIR/contracts" ]
}

validate_has_implementation_steps() {
    grep -qiE "(## implementation|## steps|## plan|## approach)" "$PLAN_FILE"
}

validate_has_dependencies() {
    grep -qiE "(## dependencies|## requirements|## prerequisites)" "$PLAN_FILE"
}

validate_has_security_considerations() {
    grep -qiE "(security|authentication|authorization|validation)" "$PLAN_FILE"
}

# Check for supporting artifact files
validate_research_file_exists() {
    [ -f "$FEATURE_DIR/research.md" ]
}

validate_data_model_exists() {
    [ -f "$FEATURE_DIR/data-model.md" ]
}

validate_contracts_dir_exists() {
    [ -d "$FEATURE_DIR/contracts" ] && [ -n "$(ls -A "$FEATURE_DIR/contracts" 2>/dev/null)" ]
}

validate_quickstart_exists() {
    [ -f "$FEATURE_DIR/quickstart.md" ]
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

# Execute validation checks - Plan Content
run_check "file_not_empty" validate_file_not_empty "required" "File has substantial content (>200 bytes)"
run_check "has_title" validate_has_title "required" "File has a title (# heading)"
run_check "has_architecture" validate_has_architecture "required" "Contains architecture/design section"
run_check "has_tech_stack" validate_has_tech_stack "required" "Specifies technology stack"
run_check "has_implementation_steps" validate_has_implementation_steps "required" "Defines implementation approach"

# Constitutional Principle Checks
run_check "mentions_library_first" validate_mentions_library_first "recommended" "Addresses Library-First (Principle I)"
run_check "mentions_testing" validate_mentions_testing "recommended" "Addresses Test-First (Principle II)"
run_check "mentions_contracts" validate_mentions_contracts "recommended" "Addresses Contract-First (Principle III)"

# Additional Quality Checks
run_check "has_data_model_reference" validate_has_data_model_reference "recommended" "References data model or entities"
run_check "has_contracts_reference" validate_has_contracts_reference "recommended" "References contracts or APIs"
run_check "has_dependencies" validate_has_dependencies "recommended" "Lists dependencies/prerequisites"
run_check "has_security_considerations" validate_has_security_considerations "recommended" "Addresses security considerations"

# Artifact File Checks
run_check "research_exists" validate_research_file_exists "recommended" "Research file exists (research.md)"
run_check "data_model_exists" validate_data_model_exists "recommended" "Data model file exists (data-model.md)"
run_check "contracts_exist" validate_contracts_dir_exists "recommended" "Contracts directory exists with files"
run_check "quickstart_exists" validate_quickstart_exists "recommended" "Quickstart file exists (quickstart.md)"

# Calculate validation score
VALIDATION_SCORE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

# Determine overall status
OVERALL_STATUS="PASS"
if [ $FAILED_CHECKS -gt 0 ]; then
    OVERALL_STATUS="FAIL"
elif [ $WARNING_CHECKS -gt 5 ] && $STRICT; then
    OVERALL_STATUS="WARN"
fi

# Output results
if $JSON_MODE; then
    # JSON output
    echo "{"
    echo "  \"file\": \"$PLAN_FILE\","
    echo "  \"feature_dir\": \"$FEATURE_DIR\","
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
    echo -e "${BLUE}  Implementation Plan Validation${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
    echo -e "${GREEN}File:${NC} $PLAN_FILE"
    echo -e "${GREEN}Feature Directory:${NC} $FEATURE_DIR"
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

        echo "  Content Checks:"
        for check in file_not_empty has_title has_architecture has_tech_stack has_implementation_steps; do
            if [ -n "${RESULTS[$check]}" ]; then
                result="${RESULTS[$check]}"
                description="${CHECKS[$check]}"
                if [ "$result" = "PASS" ]; then
                    echo -e "    ${GREEN}✅ PASS${NC}: $description"
                elif [ "$result" = "FAIL" ]; then
                    echo -e "    ${RED}❌ FAIL${NC}: $description"
                else
                    echo -e "    ${YELLOW}⚠  WARN${NC}: $description"
                fi
            fi
        done

        echo ""
        echo "  Constitutional Principle Checks:"
        for check in mentions_library_first mentions_testing mentions_contracts; do
            if [ -n "${RESULTS[$check]}" ]; then
                result="${RESULTS[$check]}"
                description="${CHECKS[$check]}"
                if [ "$result" = "PASS" ]; then
                    echo -e "    ${GREEN}✅ PASS${NC}: $description"
                else
                    echo -e "    ${YELLOW}⚠  WARN${NC}: $description"
                fi
            fi
        done

        echo ""
        echo "  Artifact Checks:"
        for check in research_exists data_model_exists contracts_exist quickstart_exists; do
            if [ -n "${RESULTS[$check]}" ]; then
                result="${RESULTS[$check]}"
                description="${CHECKS[$check]}"
                if [ "$result" = "PASS" ]; then
                    echo -e "    ${GREEN}✅ PASS${NC}: $description"
                else
                    echo -e "    ${YELLOW}⚠  WARN${NC}: $description"
                fi
            fi
        done
        echo ""
    fi

    # Provide recommendations
    if [ $FAILED_CHECKS -gt 0 ] || [ $WARNING_CHECKS -gt 0 ]; then
        echo -e "${YELLOW}Recommendations:${NC}"

        if [ "${RESULTS[mentions_library_first]}" != "PASS" ]; then
            echo "  • Address Principle I: Library-First Architecture"
            echo "    Plan should explain how features will be implemented as reusable libraries"
        fi
        if [ "${RESULTS[mentions_testing]}" != "PASS" ]; then
            echo "  • Address Principle II: Test-First Development"
            echo "    Plan should include testing strategy and TDD approach"
        fi
        if [ "${RESULTS[mentions_contracts]}" != "PASS" ]; then
            echo "  • Address Principle III: Contract-First Design"
            echo "    Plan should define API contracts and interfaces"
        fi
        if [ "${RESULTS[data_model_exists]}" != "PASS" ]; then
            echo "  • Create data-model.md to define entities and relationships"
        fi
        if [ "${RESULTS[contracts_exist]}" != "PASS" ]; then
            echo "  • Create contracts/ directory with API contract specifications"
        fi
        if [ "${RESULTS[research_exists]}" != "PASS" ]; then
            echo "  • Create research.md to document technical decisions"
        fi
        if [ "${RESULTS[quickstart_exists]}" != "PASS" ]; then
            echo "  • Create quickstart.md with test scenarios and examples"
        fi
    fi

    if [ "$OVERALL_STATUS" = "PASS" ]; then
        echo -e "${GREEN}✅ Implementation plan validation passed!${NC}"
    elif [ "$OVERALL_STATUS" = "FAIL" ]; then
        echo -e "${RED}❌ Implementation plan validation failed. Address required checks above.${NC}"
    else
        echo -e "${YELLOW}⚠  Implementation plan has warnings. Consider addressing recommendations.${NC}"
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
