#!/bin/bash
# Task List Validation Script
#
# Validates task lists for completeness, dependencies, and executability

#
# EXIT CODES (contract -- the caller MUST be able to tell these apart)
#
#   0  validated; document PASSED
#   1  validated; document FAILED a required check
#   2  validated; document has warnings and --strict was given
#   3  SCRIPT ERROR -- bad arguments, or the file is missing/unreadable.
#      Nothing was validated. No JSON is emitted on this path.
#
# 0/1/2 always emit the full report (JSON in --json mode) INCLUDING the real
# score, so a failing document is diagnosable. 3 emits an error on stderr only.
# Never conflate 3 with 1: "the document is bad" and "the gate never ran" are
# different facts, and a gate that reports the second as the first is not a gate.

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
            echo ""
            echo "Exit codes:"
            echo "  0  validated, passed"
            echo "  1  validated, FAILED a required check (report still printed)"
            echo "  2  validated, warnings under --strict"
            echo "  3  script error (bad option, missing/unreadable file)"
            exit 0
            ;;
        -*)
            # An unrecognised FLAG is a script error, not a filename.
            # Falling through to the positional case below turned
            # `--jsonn` into a file named "--jsonn" and then into a
            # "file not found" -- loud, but misleadingly so.
            echo "ERROR: unknown option: $1" >&2
            echo "Run '$0 --help' for usage." >&2
            exit 3
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
# Missing or unreadable input is a SCRIPT ERROR (3), never a validation
# failure (1). Silently scoring an absent file zero would be the same
# defect this contract exists to prevent, pointed the other way.
if [ ! -f "$TASKS_FILE" ]; then
    echo "ERROR: Tasks file not found: $TASKS_FILE" >&2
    exit 3
fi
if [ ! -r "$TASKS_FILE" ]; then
    echo "ERROR: file is not readable: $TASKS_FILE" >&2
    exit 3
fi

# Validation results.
#
# bash 3.2 (stock macOS `/bin/bash`) has no associative arrays, and this repo
# declares 3.2 the floor for `.logic-loom/scripts/` — see
# `.docs/policies/shell-idiom-policy.md`. Two parallel indexed arrays plus a
# linear lookup give the same map semantics. As a bonus they iterate in
# INSERTION order; `${!CHECKS[@]}` on bash 4 iterated in hash order, so the
# JSON `checks` object and the detail listing are now stable across bash
# versions instead of merely stable per-version.
CHECK_NAMES=()
CHECK_DESCS=()
CHECK_RESULTS=()

# Index of a check name, or -1. Always exits 0 so `set -e` stays out of it.
_check_index() {
    local want="$1" i=0 n=${#CHECK_NAMES[@]}
    while [ "$i" -lt "$n" ]; do
        if [ "${CHECK_NAMES[$i]}" = "$want" ]; then printf '%s' "$i"; return 0; fi
        i=$((i + 1))
    done
    printf '%s' "-1"
    return 0
}

# Description for a check name ("" when unknown, matching the old
# unset-associative-array read).
check_desc() {
    local i
    i=$(_check_index "$1")
    [ "$i" -ge 0 ] && printf '%s' "${CHECK_DESCS[$i]}"
    return 0
}

# Result (PASS/FAIL/WARN) for a check name, "" when unknown.
check_result() {
    local i
    i=$(_check_index "$1")
    [ "$i" -ge 0 ] && printf '%s' "${CHECK_RESULTS[$i]}"
    return 0
}

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

# Count tasks.
# NOTE: `grep -c` prints "0" and exits 1 on no match, so `|| echo "0"` appends a
# second line ("0\n0") and breaks every arithmetic comparison downstream.
# `|| true` keeps grep's own "0". See .docs/policies/shell-idiom-policy.md §1.
TASK_COUNT=$(grep -cE "^- \[[ x]\]" "$TASKS_FILE" 2>/dev/null || true); TASK_COUNT=${TASK_COUNT:-0}

# Count parallel tasks (marked with [P])
PARALLEL_TASK_COUNT=$(grep -cE "\[P\]" "$TASKS_FILE" 2>/dev/null || true); PARALLEL_TASK_COUNT=${PARALLEL_TASK_COUNT:-0}

# Count completed tasks
COMPLETED_TASK_COUNT=$(grep -cE "^- \[x\]" "$TASKS_FILE" 2>/dev/null || true); COMPLETED_TASK_COUNT=${COMPLETED_TASK_COUNT:-0}

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

    # Append; the new entry is always the last index.
    local idx=${#CHECK_NAMES[@]}
    CHECK_NAMES[$idx]="$check_name"
    CHECK_DESCS[$idx]="$description"
    CHECK_RESULTS[$idx]=""

    if $check_func; then
        CHECK_RESULTS[$idx]="PASS"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        if [ "$severity" = "required" ]; then
            CHECK_RESULTS[$idx]="FAIL"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            CHECK_RESULTS[$idx]="WARN"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
        fi
    fi

    # ALWAYS returns 0, deliberately. A failed check is a RESULT, not a script
    # error: it is recorded in FAILED_CHECKS and reported by the output block
    # below. run_check is called BARE at top level under `set -e`, so returning
    # 1 for a failed required check killed the script mid-run before it emitted
    # a single byte -- the gate scored documents that PASSED and said NOTHING
    # about documents that FAILED. Pass/fail is signalled by the exit code at
    # the bottom of this file (see EXIT CODES in the header). No caller reads
    # this return value.
    return 0
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
    for check in "${CHECK_NAMES[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        result="$(check_result "$check")"
        description="$(check_desc "$check")"
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
        for check in "${CHECK_NAMES[@]}"; do
            result="$(check_result "$check")"
            description="$(check_desc "$check")"

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

        if [ "$(check_result has_test_tasks)" != "PASS" ]; then
            echo "  • Add test-related tasks (Principle II: Test-First Development)"
            echo "    Example: '- [ ] Write unit tests for core logic'"
        fi
        if [ "$(check_result has_contract_tasks)" != "PASS" ]; then
            echo "  • Add contract definition tasks (Principle III: Contract-First)"
            echo "    Example: '- [ ] Define API contract for endpoints'"
        fi
        if [ "$(check_result has_dependencies)" != "PASS" ]; then
            echo "  • Document task dependencies to clarify execution order"
            echo "    Example: '- [ ] Task B (depends on Task A)'"
        fi
        if [ "$(check_result has_parallel_markers)" != "PASS" ]; then
            echo "  • Mark tasks that can be executed in parallel with [P]"
            echo "    Example: '- [ ] [P] Independent task that can run in parallel'"
        fi
        if [ "$(check_result sufficient_tasks)" != "PASS" ]; then
            echo "  • Break down work into more granular tasks (currently: $TASK_COUNT tasks)"
        fi
        if [ "$(check_result reasonable_count)" != "PASS" ]; then
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
