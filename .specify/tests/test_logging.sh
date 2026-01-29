#!/usr/bin/env bash
# Unit Tests for Structured Logging Library
# Constitutional Principle II: Test-First Development
#
# Test Coverage:
# - All logging functions (log_info, log_warn, log_error, log_debug)
# - JSON format correctness
# - Log level filtering
# - File and console output
# - Operation tracking (start/end with duration)
# - Context metadata support

set -e

# ==============================================================================
# Test Setup
# ==============================================================================

# Get repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Source the logging library
source ".specify/lib/logging.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Temporary test log file
TEST_LOG_DIR=".specify/logs/test"
TEST_LOG_FILE="$TEST_LOG_DIR/test-$(date +%s).log"
mkdir -p "$TEST_LOG_DIR"

# Override LOG_FILE for testing
LOG_FILE="$TEST_LOG_FILE"

# Colors for test output
TEST_COLOR_PASS='\033[0;32m'
TEST_COLOR_FAIL='\033[0;31m'
TEST_COLOR_RESET='\033[0m'

# ==============================================================================
# Test Helpers
# ==============================================================================

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$expected" == "$actual" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${TEST_COLOR_PASS}✓${TEST_COLOR_RESET} $test_name"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${TEST_COLOR_FAIL}✗${TEST_COLOR_RESET} $test_name"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$haystack" == *"$needle"* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${TEST_COLOR_PASS}✓${TEST_COLOR_RESET} $test_name"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${TEST_COLOR_FAIL}✗${TEST_COLOR_RESET} $test_name"
        echo "  Expected to contain: $needle"
        echo "  Actual haystack: $haystack"
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local test_name="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if grep -q "$pattern" "$file" 2>/dev/null; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${TEST_COLOR_PASS}✓${TEST_COLOR_RESET} $test_name"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${TEST_COLOR_FAIL}✗${TEST_COLOR_RESET} $test_name"
        echo "  File: $file"
        echo "  Expected pattern: $pattern"
        return 1
    fi
}

assert_valid_json() {
    local json_string="$1"
    local test_name="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    if echo "$json_string" | python3 -m json.tool >/dev/null 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${TEST_COLOR_PASS}✓${TEST_COLOR_RESET} $test_name"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${TEST_COLOR_FAIL}✗${TEST_COLOR_RESET} $test_name"
        echo "  Invalid JSON: $json_string"
        return 1
    fi
}

# Clean test log file
clean_test_log() {
    rm -f "$TEST_LOG_FILE"
    touch "$TEST_LOG_FILE"
}

# ==============================================================================
# Test Suite 1: Basic Logging Functions
# ==============================================================================

test_log_info() {
    echo ""
    echo "=== Test Suite 1: Basic Logging Functions ==="
    echo ""

    clean_test_log

    # Test log_info
    log_info "Test info message"
    assert_file_contains "$TEST_LOG_FILE" "\"level\":\"INFO\"" "log_info writes INFO level"
    assert_file_contains "$TEST_LOG_FILE" "Test info message" "log_info writes message"
}

test_log_warn() {
    clean_test_log

    # Test log_warn
    log_warn "Test warning message"
    assert_file_contains "$TEST_LOG_FILE" "\"level\":\"WARN\"" "log_warn writes WARN level"
    assert_file_contains "$TEST_LOG_FILE" "Test warning message" "log_warn writes message"
}

test_log_error() {
    clean_test_log

    # Test log_error
    log_error "Test error message"
    assert_file_contains "$TEST_LOG_FILE" "\"level\":\"ERROR\"" "log_error writes ERROR level"
    assert_file_contains "$TEST_LOG_FILE" "Test error message" "log_error writes message"
}

test_log_debug() {
    clean_test_log

    # Test log_debug with DEBUG level enabled
    export CLAUDE_LOG_LEVEL=DEBUG
    log_debug "Test debug message"
    assert_file_contains "$TEST_LOG_FILE" "\"level\":\"DEBUG\"" "log_debug writes DEBUG level"
    assert_file_contains "$TEST_LOG_FILE" "Test debug message" "log_debug writes message"

    # Reset log level
    export CLAUDE_LOG_LEVEL=INFO
}

# ==============================================================================
# Test Suite 2: JSON Format Validation
# ==============================================================================

test_json_format() {
    echo ""
    echo "=== Test Suite 2: JSON Format Validation ==="
    echo ""

    clean_test_log

    log_info "Test JSON format"

    # Read last line from log file
    local json_line=$(tail -n 1 "$TEST_LOG_FILE")

    # Validate JSON structure
    assert_valid_json "$json_line" "Log output is valid JSON"

    # Check required fields
    assert_contains "$json_line" "\"timestamp\":" "JSON contains timestamp"
    assert_contains "$json_line" "\"level\":" "JSON contains level"
    assert_contains "$json_line" "\"message\":" "JSON contains message"
}

test_json_with_context() {
    clean_test_log

    log_info "Test with context" "{\"user\":\"test\",\"action\":\"create\"}"

    local json_line=$(tail -n 1 "$TEST_LOG_FILE")

    assert_contains "$json_line" "\"context\":" "JSON contains context field"
    assert_contains "$json_line" "\"user\":\"test\"" "Context contains user field"
}

# ==============================================================================
# Test Suite 3: Log Level Filtering
# ==============================================================================

test_log_level_filtering() {
    echo ""
    echo "=== Test Suite 3: Log Level Filtering ==="
    echo ""

    clean_test_log

    # Set log level to WARN (should filter out INFO and DEBUG)
    export CLAUDE_LOG_LEVEL=WARN

    log_debug "This should not appear"
    log_info "This should not appear"
    log_warn "This should appear"
    log_error "This should also appear"

    local line_count=$(wc -l < "$TEST_LOG_FILE")
    assert_equals "2" "$line_count" "WARN level filters out DEBUG and INFO"

    # Verify WARN and ERROR are present
    assert_file_contains "$TEST_LOG_FILE" "This should appear" "WARN message logged"
    assert_file_contains "$TEST_LOG_FILE" "This should also appear" "ERROR message logged"

    # Reset log level
    export CLAUDE_LOG_LEVEL=INFO
}

test_debug_level_shows_all() {
    clean_test_log

    # Set log level to DEBUG (should show all)
    export CLAUDE_LOG_LEVEL=DEBUG

    log_debug "Debug message"
    log_info "Info message"
    log_warn "Warn message"
    log_error "Error message"

    local line_count=$(wc -l < "$TEST_LOG_FILE")
    assert_equals "4" "$line_count" "DEBUG level shows all messages"

    # Reset log level
    export CLAUDE_LOG_LEVEL=INFO
}

# ==============================================================================
# Test Suite 4: Operation Tracking
# ==============================================================================

test_operation_tracking() {
    echo ""
    echo "=== Test Suite 4: Operation Tracking ==="
    echo ""

    clean_test_log

    # Start operation
    local op_id=$(log_operation_start "test-operation" "Test details")

    # Verify operation ID returned
    [[ -n "$op_id" ]] && echo -e "${TEST_COLOR_PASS}✓${TEST_COLOR_RESET} log_operation_start returns operation ID" || echo -e "${TEST_COLOR_FAIL}✗${TEST_COLOR_RESET} log_operation_start returns operation ID"
    TESTS_RUN=$((TESTS_RUN + 1))
    [[ -n "$op_id" ]] && TESTS_PASSED=$((TESTS_PASSED + 1)) || TESTS_FAILED=$((TESTS_FAILED + 1))

    # Verify start log
    assert_file_contains "$TEST_LOG_FILE" "Operation started: test-operation" "Operation start logged"
    assert_file_contains "$TEST_LOG_FILE" "\"phase\":\"start\"" "Start phase recorded"

    # Simulate some work
    sleep 0.1

    # End operation
    log_operation_end "$op_id" "test-operation" "success" "Operation completed"

    # Verify end log
    assert_file_contains "$TEST_LOG_FILE" "Operation ended: test-operation" "Operation end logged"
    assert_file_contains "$TEST_LOG_FILE" "\"phase\":\"end\"" "End phase recorded"
    assert_file_contains "$TEST_LOG_FILE" "\"status\":\"success\"" "Status recorded"
    assert_file_contains "$TEST_LOG_FILE" "\"duration_ms\":" "Duration calculated"
}

test_operation_failure_tracking() {
    clean_test_log

    local op_id=$(log_operation_start "failing-operation")
    log_operation_end "$op_id" "failing-operation" "error" "Something went wrong"

    assert_file_contains "$TEST_LOG_FILE" "\"status\":\"error\"" "Error status recorded"
    assert_file_contains "$TEST_LOG_FILE" "\"level\":\"ERROR\"" "Failed operation logs as ERROR"
}

# ==============================================================================
# Test Suite 5: Special Characters and Edge Cases
# ==============================================================================

test_special_characters() {
    echo ""
    echo "=== Test Suite 5: Special Characters ==="
    echo ""

    clean_test_log

    # Test with quotes
    log_info "Message with \"quotes\""
    local json_line=$(tail -n 1 "$TEST_LOG_FILE")
    assert_valid_json "$json_line" "Handles double quotes"

    # Test with newlines
    log_info "Message with
newline"
    json_line=$(tail -n 1 "$TEST_LOG_FILE")
    assert_valid_json "$json_line" "Handles newlines"

    # Test with backslashes
    log_info "Path: C:\\Users\\test"
    json_line=$(tail -n 1 "$TEST_LOG_FILE")
    assert_valid_json "$json_line" "Handles backslashes"
}

# ==============================================================================
# Test Suite 6: File Output
# ==============================================================================

test_file_output() {
    echo ""
    echo "=== Test Suite 6: File and Directory Creation ==="
    echo ""

    clean_test_log

    # Verify log file created
    [[ -f "$TEST_LOG_FILE" ]] && echo -e "${TEST_COLOR_PASS}✓${TEST_COLOR_RESET} Log file created" || echo -e "${TEST_COLOR_FAIL}✗${TEST_COLOR_RESET} Log file created"
    TESTS_RUN=$((TESTS_RUN + 1))
    [[ -f "$TEST_LOG_FILE" ]] && TESTS_PASSED=$((TESTS_PASSED + 1)) || TESTS_FAILED=$((TESTS_FAILED + 1))

    # Verify log directory structure
    [[ -d ".specify/logs/operations" ]] && echo -e "${TEST_COLOR_PASS}✓${TEST_COLOR_RESET} operations/ directory exists" || echo -e "${TEST_COLOR_FAIL}✗${TEST_COLOR_RESET} operations/ directory exists"
    TESTS_RUN=$((TESTS_RUN + 1))
    [[ -d ".specify/logs/operations" ]] && TESTS_PASSED=$((TESTS_PASSED + 1)) || TESTS_FAILED=$((TESTS_FAILED + 1))

    [[ -d ".specify/logs/errors" ]] && echo -e "${TEST_COLOR_PASS}✓${TEST_COLOR_RESET} errors/ directory exists" || echo -e "${TEST_COLOR_FAIL}✗${TEST_COLOR_RESET} errors/ directory exists"
    TESTS_RUN=$((TESTS_RUN + 1))
    [[ -d ".specify/logs/errors" ]] && TESTS_PASSED=$((TESTS_PASSED + 1)) || TESTS_FAILED=$((TESTS_FAILED + 1))

    [[ -d ".specify/logs/metrics" ]] && echo -e "${TEST_COLOR_PASS}✓${TEST_COLOR_RESET} metrics/ directory exists" || echo -e "${TEST_COLOR_FAIL}✗${TEST_COLOR_RESET} metrics/ directory exists"
    TESTS_RUN=$((TESTS_RUN + 1))
    [[ -d ".specify/logs/metrics" ]] && TESTS_PASSED=$((TESTS_PASSED + 1)) || TESTS_FAILED=$((TESTS_FAILED + 1))
}

# ==============================================================================
# Run All Tests
# ==============================================================================

echo "=========================================="
echo "Structured Logging Library - Unit Tests"
echo "=========================================="

test_log_info
test_log_warn
test_log_error
test_log_debug

test_json_format
test_json_with_context

test_log_level_filtering
test_debug_level_shows_all

test_operation_tracking
test_operation_failure_tracking

test_special_characters

test_file_output

# ==============================================================================
# Test Summary
# ==============================================================================

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Tests run:    $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo ""

# Clean up test log file
rm -f "$TEST_LOG_FILE"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${TEST_COLOR_PASS}All tests passed!${TEST_COLOR_RESET}"
    exit 0
else
    echo -e "${TEST_COLOR_FAIL}Some tests failed.${TEST_COLOR_RESET}"
    exit 1
fi
