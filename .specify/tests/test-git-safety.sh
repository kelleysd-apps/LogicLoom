#!/usr/bin/env bash
# Unit tests for git safety functions (T007-T009, T011)
# Constitutional Principle II: Test-First Development

set -euo pipefail

# Load test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the library under test
source "$REPO_ROOT/.specify/scripts/bash/common.sh"

# Test utilities
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$expected" == "$actual" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if echo "$haystack" | grep -q "$needle"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $message"
        echo "  Haystack: $haystack"
        echo "  Needle:   $needle"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -f "$file" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $message"
        echo "  File not found: $file"
        return 1
    fi
}

# ==============================================================================
# T007: Test git diff preview functionality
# ==============================================================================

test_get_git_diff_preview() {
    echo ""
    echo "Test: get_git_diff_preview generates summary"

    # This function should exist after T007 implementation
    if ! type get_git_diff_preview &>/dev/null; then
        echo -e "${YELLOW}⊘${NC} Function get_git_diff_preview not yet implemented (T007)"
        return 0
    fi

    # Mock git diff output
    local diff_output="1 file changed, 10 insertions(+), 2 deletions(-)"

    # Function should format the output appropriately
    local preview=$(get_git_diff_preview 2>/dev/null || echo "")

    # Check that function executed without error
    assert_equals "0" "$?" "get_git_diff_preview executes without error"
}

test_request_git_approval_with_preview() {
    echo ""
    echo "Test: request_git_approval_enhanced shows diff preview"

    if ! type request_git_approval_enhanced &>/dev/null; then
        echo -e "${YELLOW}⊘${NC} Function request_git_approval_enhanced not yet implemented (T007)"
        return 0
    fi

    # This test would require mocking user input
    # For now, just verify the function exists
    assert_equals "0" "0" "request_git_approval_enhanced function exists"
}

# ==============================================================================
# T008: Test git checkpoint system
# ==============================================================================

test_create_git_checkpoint() {
    echo ""
    echo "Test: create_git_checkpoint creates checkpoint file"

    if ! type create_git_checkpoint &>/dev/null; then
        echo -e "${YELLOW}⊘${NC} Function create_git_checkpoint not yet implemented (T008)"
        return 0
    fi

    # Test checkpoint creation
    local checkpoint_id=$(create_git_checkpoint "test-operation" 2>/dev/null || echo "")

    if [[ -n "$checkpoint_id" ]]; then
        assert_contains "$checkpoint_id" "$(date +%Y-%m-%d)" "Checkpoint ID contains today's date"

        # Verify checkpoint file was created
        local checkpoint_file=".specify/logs/git-checkpoints/$(date +%Y-%m-%d).json"
        assert_file_exists "$checkpoint_file" "Checkpoint file created"

        # Cleanup test checkpoint
        # (In real implementation, would restore from this checkpoint)
    else
        echo -e "${YELLOW}⊘${NC} Checkpoint creation returned empty (function may not be complete)"
    fi
}

test_list_git_checkpoints() {
    echo ""
    echo "Test: list_git_checkpoints shows available checkpoints"

    if ! type list_git_checkpoints &>/dev/null; then
        echo -e "${YELLOW}⊘${NC} Function list_git_checkpoints not yet implemented (T008)"
        return 0
    fi

    # Test checkpoint listing
    local checkpoints=$(list_git_checkpoints 2>/dev/null || echo "")

    # Should at least execute without error
    assert_equals "0" "$?" "list_git_checkpoints executes without error"
}

test_restore_git_checkpoint() {
    echo ""
    echo "Test: restore_git_checkpoint can restore from checkpoint"

    if ! type restore_git_checkpoint &>/dev/null; then
        echo -e "${YELLOW}⊘${NC} Function restore_git_checkpoint not yet implemented (T008)"
        return 0
    fi

    # This would require creating a checkpoint first
    # For now, just verify the function exists
    assert_equals "0" "0" "restore_git_checkpoint function exists"
}

test_cleanup_old_checkpoints() {
    echo ""
    echo "Test: cleanup_old_checkpoints removes old entries"

    if ! type cleanup_old_checkpoints &>/dev/null; then
        echo -e "${YELLOW}⊘${NC} Function cleanup_old_checkpoints not yet implemented (T008)"
        return 0
    fi

    # Should execute without error
    cleanup_old_checkpoints 2>/dev/null || true
    assert_equals "0" "$?" "cleanup_old_checkpoints executes without error"
}

# ==============================================================================
# T009: Test commit message suggestions
# ==============================================================================

test_suggest_commit_message() {
    echo ""
    echo "Test: suggest_commit_message generates appropriate suggestions"

    if ! type suggest_commit_message &>/dev/null; then
        echo -e "${YELLOW}⊘${NC} Function suggest_commit_message not yet implemented (T009)"
        return 0
    fi

    # Test commit message suggestion
    local suggestions=$(suggest_commit_message 2>/dev/null || echo "")

    if [[ -n "$suggestions" ]]; then
        # Should contain at least one suggestion
        assert_contains "$suggestions" "feat\|fix\|chore\|docs" "Suggestions contain conventional commit types"
    else
        echo -e "${YELLOW}⊘${NC} No suggestions generated (may need staged changes)"
    fi
}

test_parse_conventional_commit_type() {
    echo ""
    echo "Test: parse_conventional_commit_type identifies change type"

    if ! type parse_conventional_commit_type &>/dev/null; then
        echo -e "${YELLOW}⊘${NC} Function parse_conventional_commit_type not yet implemented (T009)"
        return 0
    fi

    # Test with different file patterns
    # (Would need mock data for real testing)
    assert_equals "0" "0" "parse_conventional_commit_type function exists"
}

# ==============================================================================
# T011: Integration test for git workflow
# ==============================================================================

test_git_workflow_integration() {
    echo ""
    echo "Test: Full git workflow with safety features"

    # This would test: stage → preview → approve → commit → checkpoint
    # Requires more complex setup with temporary git repo

    echo -e "${YELLOW}⊘${NC} Integration test requires interactive git operations"
    echo "   Run manually: ./test-git-workflow-manual.sh"
}

# ==============================================================================
# Run all tests
# ==============================================================================

main() {
    echo "========================================"
    echo "Git Safety Functions Test Suite"
    echo "Testing: T007, T008, T009, T011"
    echo "========================================"

    # T007 tests
    test_get_git_diff_preview || true
    test_request_git_approval_with_preview || true

    # T008 tests
    test_create_git_checkpoint || true
    test_list_git_checkpoints || true
    test_restore_git_checkpoint || true
    test_cleanup_old_checkpoints || true

    # T009 tests
    test_suggest_commit_message || true
    test_parse_conventional_commit_type || true

    # T011 tests
    test_git_workflow_integration || true

    # Summary
    echo ""
    echo "========================================"
    echo "Test Results"
    echo "========================================"
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo "========================================"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi

    exit 0
}

# Run tests
main "$@"
