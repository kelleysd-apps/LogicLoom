#!/bin/bash
# Task List Validation Script
#
# Validates task lists for completeness, dependencies, and executability

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
TASKS_FILE=""
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
            TASKS_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --json              Output in JSON format"
            echo "  --verbose, -v       Verbose output"
            echo "  --strict            Enable strict validation"
            echo "  --file, -f FILE     Tasks file to validate"
            echo "  --help, -h          Show this help message"
            exit 0
            ;;
        *)
            TASKS_FILE="$1"
            shift
            ;;
    esac
done

# Auto-detect tasks file if not provided
if [ -z "$TASKS_FILE" ]; then
    eval $(get_feature_paths)
    TASKS_FILE="$FEATURE_DIR/tasks.md"
fi

# Validate file exists
if [ ! -f "$TASKS_FILE" ]; then
    echo "ERROR: Tasks file not found: $TASKS_FILE" >&2
    exit 1
fi

# Initialize validation results
declare -A CHECKS
declare -A RESULTS
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Analyze tasks file
TASK_COUNT=0
PARALLEL_TASK_COUNT=0
COMPLETED_TASK_COUNT=0
HAS_DEPENDENCIES=false
HAS_TEST_TASKS=false
HAS_CONTRACT_TASKS=false

# Count tasks
TASK_COUNT=$(grep -cE "^- \[[ x]\]" "$TASKS_FILE" || echo "0")

# Count parallel tasks (marked with [P])
PARALLEL_TASK_COUNT=$(grep -cE "\[P\]" "$TASKS_FILE" || echo "0")

# Count completed tasks
COMPLETED_TASK_COUNT=$(grep -cE "^- \[x\]" "$TASKS_FILE" || echo "0")

# Check for dependencies
if grep -qiE "(depends on|dependency|prerequisite|after|before)" "$TASKS_FILE"; then
    HAS_DEPENDENCIES=true
fi

# Check for test-related tasks
if grep -qiE "(test|testing|TDD|unit test|integration test)" "$TASKS_FILE"; then
    HAS_TEST_TASKS=true
fi

# Check for contract-related tasks
if grep -qiE "(contract|API spec|interface|schema)" "$TASKS_FILE"; then
    HAS_CONTRACT_TASKS=true
fi

# Define validation checks

validate_file_not_empty() {
    local size=$(stat -f%z "$TASKS_FILE" 2>/dev/null || stat -c%s "$TASKS_FILE" 2>/dev/null)
    [ "$size" -gt 100 ]
}

validate_has_title() {
    grep -qE "^# " "$TASKS_FILE"
}

validate_has_tasks() {
    [ "$TASK_COUNT" -gt 0 ]
}

validate_sufficient_tasks() {
    [ "$TASK_COUNT" -ge 3 ]
}

validate_has_checkboxes() {
    grep -qE "^- \[[ x]\]" "$TASKS_FILE"
}

validate_has_test_tasks() {
    [ "$HAS_TEST_TASKS" = true ]
}

validate_has_contract_tasks() {
    [ "$HAS_CONTRACT_TASKS" = true ]
}

validate_has_dependencies() {
    [ "$HAS_DEPENDENCIES" = true ]
}

validate_has_parallel_markers() {
    [ "$PARALLEL_TASK_COUNT" -gt 0 ]
}

validate_not_all_completed() {
    [ "$COMPLETED_TASK_COUNT" -lt "$TASK_COUNT" ]
}

validate_reasonable_task_count() {
    [ "$TASK_COUNT" -le 50 ]  # Not too many tasks (should be broken down)
}

validate_has_sections() {
    grep -qE "^##" "$TASKS_FILE"
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
run_check "has_tasks" validate_has_tasks "required" "Contains at least one task"
run_check "has_checkboxes" validate_has_checkboxes "required" "Tasks use checkbox format [ ] or [x]"
run_check "sufficient_tasks" validate_sufficient_tasks "recommended" "Has sufficient tasks (≥3)"
run_check "has_test_tasks" validate_has_test_tasks "recommended" "Includes test-related tasks (Principle II)"
run_check "has_contract_tasks" validate_has_contract_tasks "recommended" "Includes contract tasks (Principle III)"
run_check "has_dependencies" validate_has_dependencies "recommended" "Documents task dependencies"
run_check "has_parallel_markers" validate_has_parallel_markers "recommended" "Marks parallel-executable tasks [P]"
run_check "not_all_completed" validate_not_all_completed "optional" "Has incomplete tasks (work remaining)"
run_check "reasonable_count" validate_reasonable_task_count "optional" "Task count is reasonable (≤50)"
run_check "has_sections" validate_has_sections "optional" "Organizes tasks into sections"

# Calculate validation score
VALIDATION_SCORE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

# Determine overall status
OVERALL_STATUS="PASS"
if [ $FAILED_CHECKS -gt 0 ]; then
    OVERALL_STATUS="FAIL"
elif [ $WARNING_CHECKS -gt 4 ] && $STRICT; then
    OVERALL_STATUS="WARN"
fi

# Calculate progress percentage
PROGRESS_PCT=0
if [ "$TASK_COUNT" -gt 0 ]; then
    PROGRESS_PCT=$((COMPLETED_TASK_COUNT * 100 / TASK_COUNT))
fi

# Output results
if $JSON_MODE; then
    # JSON output
    echo "{"
    echo "  \"file\": \"$TASKS_FILE\","
    echo "  \"status\": \"$OVERALL_STATUS\","
    echo "  \"score\": $VALIDATION_SCORE,"
    echo "  \"total_checks\": $TOTAL_CHECKS,"
    echo "  \"passed\": $PASSED_CHECKS,"
    echo "  \"failed\": $FAILED_CHECKS,"
    echo "  \"warnings\": $WARNING_CHECKS,"
    echo "  \"tasks\": {"
    echo "    \"total\": $TASK_COUNT,"
    echo "    \"completed\": $COMPLETED_TASK_COUNT,"
    echo "    \"parallel\": $PARALLEL_TASK_COUNT,"
    echo "    \"progress_pct\": $PROGRESS_PCT"
    echo "  },"
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
    echo -e "${BLUE}  Task List Validation${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
    echo -e "${GREEN}File:${NC} $TASKS_FILE"
    echo -e "${GREEN}Status:${NC} $OVERALL_STATUS"
    echo -e "${GREEN}Score:${NC} $VALIDATION_SCORE%"
    echo ""

    echo -e "${YELLOW}Task Statistics:${NC}"
    echo "  Total Tasks: $TASK_COUNT"
    echo "  Completed: $COMPLETED_TASK_COUNT ($PROGRESS_PCT%)"
    echo "  Parallel Tasks: $PARALLEL_TASK_COUNT"
    echo ""

    echo -e "${YELLOW}Validation Results:${NC}"
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

        if [ "${RESULTS[has_test_tasks]}" != "PASS" ]; then
            echo "  • Add test-related tasks (Principle II: Test-First Development)"
            echo "    Example: '- [ ] Write unit tests for core logic'"
        fi
        if [ "${RESULTS[has_contract_tasks]}" != "PASS" ]; then
            echo "  • Add contract definition tasks (Principle III: Contract-First)"
            echo "    Example: '- [ ] Define API contract for endpoints'"
        fi
        if [ "${RESULTS[has_dependencies]}" != "PASS" ]; then
            echo "  • Document task dependencies to clarify execution order"
            echo "    Example: '- [ ] Task B (depends on Task A)'"
        fi
        if [ "${RESULTS[has_parallel_markers]}" != "PASS" ]; then
            echo "  • Mark tasks that can be executed in parallel with [P]"
            echo "    Example: '- [ ] [P] Independent task that can run in parallel'"
        fi
        if [ "${RESULTS[sufficient_tasks]}" != "PASS" ]; then
            echo "  • Break down work into more granular tasks (currently: $TASK_COUNT tasks)"
        fi
        if [ "${RESULTS[reasonable_count]}" != "PASS" ]; then
            echo "  • Task list may be too detailed ($TASK_COUNT tasks). Consider grouping."
        fi
    fi

    if [ "$OVERALL_STATUS" = "PASS" ]; then
        echo -e "${GREEN}✅ Task list validation passed!${NC}"
    elif [ "$OVERALL_STATUS" = "FAIL" ]; then
        echo -e "${RED}❌ Task list validation failed. Address required checks above.${NC}"
    else
        echo -e "${YELLOW}⚠  Task list has warnings. Consider addressing recommendations.${NC}"
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
