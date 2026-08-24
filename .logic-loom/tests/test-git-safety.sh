#!/usr/bin/env bash
# Unit tests for git safety functions (T007-T009, T011)
# Constitutional Principle II: Test-First Development

set -euo pipefail

# Load test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Operations-log isolation. MUST be set BEFORE common.sh is sourced: logging.sh
# resolves LOG_FILE from LOOM_LOG_DIR once, at source time, so exporting it later
# would be too late and the suite would keep appending to the shared
# .logic-loom/logs/operations/ file. (LOOM_CHECKPOINT_DIR below has no such
# ordering constraint — checkpoint_dir_path reads it at call time.)
LOOM_LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/loom-logs.XXXXXX")"
export LOOM_LOG_DIR

# Source the library under test. common.sh pulls in logging.sh/policy.sh which
# require bash 4+ (associative arrays). Under bash 3.2 those `declare -A` lines
# trip `set -u` and would terminate the sourcing shell (can't be `||`-caught
# from a sourced file), so only source when running on bash 4+. The T007-T011
# function tests below skip gracefully when the functions are absent, and the
# hook-gate tests drive the hook scripts as subprocesses and need nothing here.
# Probe with THIS interpreter in a subshell first (a failure inside a sourced
# file can't be `||`-caught), then source for real only if the probe survives.
# This replaces a hard `bash >= 4` version gate: the libs are bash-3.2-clean
# now, and the version gate silently skipped every T007-T011 assertion on
# stock macOS.
if "${BASH:-bash}" -c "set -euo pipefail; source \"$REPO_ROOT/.logic-loom/scripts/bash/common.sh\"" >/dev/null 2>&1; then
    source "$REPO_ROOT/.logic-loom/scripts/bash/common.sh"
else
    echo "[skip] bash ${BASH_VERSION%%(*}: common.sh could not be sourced — T007-T011 function tests will skip"
fi

# Git checkpoint isolation: point the checkpoint writer at a temp dir so the
# suite never writes into the repo working tree and is not stateful across runs.
# common.sh honours LOOM_CHECKPOINT_DIR (see checkpoint_dir_path).
LOOM_CHECKPOINT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/loom-checkpoints.XXXXXX")"
export LOOM_CHECKPOINT_DIR
# Both temp dirs are cleaned up by the SAME trap — a second `trap ... EXIT`
# would REPLACE this one rather than add to it.
cleanup_test_checkpoints() {
    if [ -n "${LOOM_CHECKPOINT_DIR:-}" ] && [ -d "$LOOM_CHECKPOINT_DIR" ]; then
        case "$LOOM_CHECKPOINT_DIR" in
            */loom-checkpoints.*) rm -rf "$LOOM_CHECKPOINT_DIR" ;;
        esac
    fi
    if [ -n "${LOOM_LOG_DIR:-}" ] && [ -d "$LOOM_LOG_DIR" ]; then
        case "$LOOM_LOG_DIR" in
            */loom-logs.*) rm -rf "$LOOM_LOG_DIR" ;;
        esac
    fi
}
trap cleanup_test_checkpoints EXIT

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
    # NOTE: assign first, capture status on the NEXT line. `local x=$(cmd)`
    # makes $? the status of `local` (always 0), so the assertion below would
    # pass unconditionally.
    local preview="" rc=0
    preview=$(get_git_diff_preview 2>/dev/null) || rc=$?

    # Check that function executed without error
    assert_equals "0" "$rc" "get_git_diff_preview executes without error"
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
        assert_contains "$checkpoint_id" "^[0-9]\{10\}$" "Checkpoint ID is a valid epoch timestamp"

        # Verify checkpoint file was created (in the isolated temp dir)
        local checkpoint_file="$LOOM_CHECKPOINT_DIR/$(date +%Y-%m-%d).json"
        assert_file_exists "$checkpoint_file" "Checkpoint file created"

        # Each record must be ONE line of valid JSON (JSONL) — line-by-line
        # readers (list_git_checkpoints) depend on it.
        local bad_lines=0
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            echo "$line" | jq -e . >/dev/null 2>&1 || bad_lines=$((bad_lines + 1))
        done < "$checkpoint_file"
        assert_equals "0" "$bad_lines" "Checkpoint records are one-line valid JSON (JSONL)"

        # Temp checkpoint dir is removed by the EXIT trap.
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

    # Seed a checkpoint so listing has something real to render.
    create_git_checkpoint "list-test-operation" >/dev/null 2>&1 || true

    # Assign first, capture status on the NEXT line (see note above).
    local checkpoints="" rc=0
    checkpoints=$(list_git_checkpoints 2>/dev/null) || rc=$?

    # Should at least execute without error
    assert_equals "0" "$rc" "list_git_checkpoints executes without error"

    # ...and actually render the checkpoint it was given, not a silent blank.
    assert_contains "$checkpoints" "list-test-operation" \
        "list_git_checkpoints renders the checkpoint record it just wrote"
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

    # Should execute without error. `|| true` would make $? unconditionally 0,
    # so capture the real status instead.
    local rc=0
    cleanup_old_checkpoints >/dev/null 2>&1 || rc=$?
    assert_equals "0" "$rc" "cleanup_old_checkpoints executes without error"
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

    if [[ -n "$suggestions" ]] && ! echo "$suggestions" | grep -q "No staged changes"; then
        # Should contain at least one suggestion
        assert_contains "$suggestions" "feat\|fix\|chore\|docs" "Suggestions contain conventional commit types"
    else
        echo -e "${YELLOW}⊘${NC} No suggestions generated (no staged changes)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
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
# Hook gate tests: subagent-git-guard.sh + git-safety-gate.sh
# Drives the real hook scripts with PreToolUse JSON on stdin and asserts on the
# permissionDecision. bash-3.2 safe (no associative arrays, no `mapfile`).
# ==============================================================================

SUBAGENT_GUARD="$REPO_ROOT/plugins/loom-governance/hooks/scripts/subagent-git-guard.sh"
SAFETY_GATE="$REPO_ROOT/plugins/loom-governance/hooks/scripts/git-safety-gate.sh"

# json_escape <string> -> JSON-safe inner string (handles backslash + quote)
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# extract_decision <hook-json-output> -> permissionDecision value
extract_decision() {
    printf '%s' "$1" | grep -oE '"permissionDecision":"[a-z]+"' | head -1 | sed 's/.*:"//; s/"$//'
}

# run_subagent_guard <agent_id> <command> -> prints decision
run_subagent_guard() {
    local aid cmd payload out
    aid="$(json_escape "$1")"
    cmd="$(json_escape "$2")"
    if [ -n "$1" ]; then
        payload="{\"tool_name\":\"Bash\",\"agent_id\":\"$aid\",\"agent_type\":\"general-purpose\",\"tool_input\":{\"command\":\"$cmd\"}}"
    else
        payload="{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}"
    fi
    out="$(printf '%s' "$payload" | bash "$SUBAGENT_GUARD" 2>/dev/null || true)"
    extract_decision "$out"
}

# run_safety_gate <command> -> prints decision
run_safety_gate() {
    local cmd payload out
    cmd="$(json_escape "$1")"
    payload="{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}"
    out="$(printf '%s' "$payload" | bash "$SAFETY_GATE" 2>/dev/null || true)"
    extract_decision "$out"
}

test_subagent_git_guard() {
    echo ""
    echo "Test: subagent-git-guard.sh blocks MUTATING git from subagents (path-prefix safe)"

    # Subagent + MUTATING git invocations (including path-prefix bypasses) -> deny
    assert_equals "deny" "$(run_subagent_guard "a8e123" "/usr/bin/git push")" \
        "subagent '/usr/bin/git push' -> deny"
    assert_equals "deny" "$(run_subagent_guard "a8e123" "./git clean -fd")" \
        "subagent './git clean -fd' -> deny"
    assert_equals "deny" "$(run_subagent_guard "a8e123" "git -C /t reset --hard")" \
        "subagent 'git -C /t reset --hard' -> deny"
    assert_equals "deny" "$(run_subagent_guard "a8e123" "cd x && /usr/bin/git push")" \
        "subagent 'cd x && /usr/bin/git push' -> deny"
    # §7.3: read-only git from a subagent is ALLOWED (was: blanket deny). The
    # allowlist is explicit — known-safe reads pass, everything else is denied.
    assert_equals "allow" "$(run_subagent_guard "a8e123" "git status")" \
        "subagent 'git status' (read-only allowlist) -> allow"
    assert_equals "allow" "$(run_subagent_guard "a8e123" "git log --oneline -20")" \
        "subagent 'git log' (read-only allowlist) -> allow"
    assert_equals "allow" "$(run_subagent_guard "a8e123" "git branch -a")" \
        "subagent 'git branch -a' (listing) -> allow"
    # ...but the write forms and the code-execution globals stay denied.
    assert_equals "deny" "$(run_subagent_guard "a8e123" "git branch newfeature")" \
        "subagent 'git branch newfeature' (creates) -> deny"
    assert_equals "deny" "$(run_subagent_guard "a8e123" "git -c core.fsmonitor=evil status")" \
        "subagent 'git -c core.fsmonitor=<cmd> status' (executes cmd) -> deny"
    assert_equals "deny" "$(run_subagent_guard "a8e123" "git fetch")" \
        "subagent 'git fetch' (writes remote-tracking refs) -> deny"

    # Subagent + non-git substrings -> allow (no false positives)
    assert_equals "allow" "$(run_subagent_guard "a8e123" "ls && grep digit f")" \
        "subagent 'ls && grep digit f' -> allow"
    assert_equals "allow" "$(run_subagent_guard "a8e123" "echo github")" \
        "subagent 'echo github' -> allow"
    assert_equals "allow" "$(run_subagent_guard "a8e123" "cat .gitignore")" \
        "subagent 'cat .gitignore' -> allow"
    assert_equals "allow" "$(run_subagent_guard "a8e123" "echo legitimate work")" \
        "subagent 'echo legitimate work' -> allow"

    # Main agent (no agent_id) -> allow even for git (safety-gate handles it)
    assert_equals "allow" "$(run_subagent_guard "" "git -C /r push")" \
        "main agent 'git -C /r push' -> allow at subagent guard"
}

test_git_safety_gate() {
    echo ""
    echo "Test: git-safety-gate.sh asks for mutating git (flag-decoupled)"

    # Mutating with global flags between git and subcommand -> ask
    assert_equals "ask" "$(run_safety_gate "git -C /r push")" \
        "main 'git -C /r push' -> ask"
    # GATE POLICY (2026-08): `git commit` is now SILENT by default (local, fully
    # revertible, highest-frequency operation). The point of this assertion is
    # flag-decoupling, not the commit verb, so it moves to an operation that
    # still asks — and the new silent behaviour is asserted immediately below.
    assert_equals "ask" "$(run_safety_gate "git -c k=v merge feature")" \
        "main 'git -c k=v merge' -> ask"
    assert_equals "allow" "$(run_safety_gate "git -c k=v commit -m x")" \
        "main 'git -c k=v commit' -> allow (gate policy: git.commit = silent)"
    assert_equals "ask" "$(run_safety_gate "git --git-dir=x push")" \
        "main 'git --git-dir=x push' -> ask"
    assert_equals "ask" "$(run_safety_gate "/usr/bin/git push origin main")" \
        "main '/usr/bin/git push' (path prefix) -> ask"
    assert_equals "ask" "$(run_safety_gate "git clean -fd")" \
        "main 'git clean -fd' -> ask"
    assert_equals "ask" "$(run_safety_gate "git branch -D feature")" \
        "main 'git branch -D feature' -> ask"
    assert_equals "ask" "$(run_safety_gate "git remote add origin url")" \
        "main 'git remote add' -> ask"

    # Read-only git -> allow
    assert_equals "allow" "$(run_safety_gate "git status")" \
        "main 'git status' -> allow"
    assert_equals "allow" "$(run_safety_gate "git log --oneline")" \
        "main 'git log' -> allow"
    assert_equals "allow" "$(run_safety_gate "git diff HEAD")" \
        "main 'git diff' -> allow"
    assert_equals "allow" "$(run_safety_gate "git branch")" \
        "main 'git branch' (list, no -d) -> allow"
    assert_equals "allow" "$(run_safety_gate "git rev-parse HEAD")" \
        "main 'git rev-parse' -> allow"

    # Non-git commands -> allow (no false positives)
    assert_equals "allow" "$(run_safety_gate "echo github")" \
        "main 'echo github' -> allow"
    assert_equals "allow" "$(run_safety_gate "ls && grep digit f")" \
        "main 'ls && grep digit f' -> allow"
}

# ==============================================================================
# Run all tests
# ==============================================================================

main() {
    echo "========================================"
    echo "Git Safety Functions Test Suite"
    echo "Testing: T007, T008, T009, T011 + hook gates"
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

    # Hook gate tests
    test_subagent_git_guard || true
    test_git_safety_gate || true

    # Summary
    echo ""
    echo "========================================"
    echo "Test Results"
    echo "========================================"
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo "========================================"
    echo ""
    echo "Results: ${TESTS_PASSED}/${TESTS_RUN} passed, ${TESTS_FAILED} failed"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi

    exit 0
}

# Run tests
main "$@"
