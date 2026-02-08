#!/usr/bin/env bash
# Tool Policy Validation Library
# T014: Policy validation for command safety
# Constitutional Principle XI: Input Validation and Output Sanitization

# ==============================================================================
# Configuration
# ==============================================================================

# Get repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"

# Policy file location
POLICY_FILE="$REPO_ROOT/.claude/policies/tool-restrictions.json"

# JSON parser (use Node.js helper if jq not available)
JSON_PARSER="$REPO_ROOT/.specify/lib/json-parse.cjs"

# Load logging if available
if [[ -f "$REPO_ROOT/.specify/lib/logging.sh" ]]; then
    source "$REPO_ROOT/.specify/lib/logging.sh"
else
    log_info() { echo "[INFO] $1" >&2; }
    log_warn() { echo "[WARN] $1" >&2; }
    log_error() { echo "[ERROR] $1" >&2; }
fi

# Cache for loaded policy
declare -g POLICY_LOADED=false
declare -gA POLICY_CACHE

# ==============================================================================
# JSON Parsing Helper
# ==============================================================================

# Parse JSON using jq or Node.js fallback
parse_json() {
    local json_input="$1"
    local query="$2"

    # Try jq first
    if command -v jq &>/dev/null; then
        echo "$json_input" | jq -r "$query" 2>/dev/null
    elif command -v node &>/dev/null && [[ -f "$JSON_PARSER" ]]; then
        # Use Node.js fallback
        echo "$json_input" | node "$JSON_PARSER" - "$query" 2>/dev/null
    else
        # No JSON parser available
        echo "null"
        return 1
    fi
}

# Parse JSON from file
parse_json_file() {
    local file="$1"
    local query="$2"

    # Try jq first
    if command -v jq &>/dev/null; then
        jq -r "$query" "$file" 2>/dev/null
    elif command -v node &>/dev/null && [[ -f "$JSON_PARSER" ]]; then
        # Use Node.js fallback
        node "$JSON_PARSER" "$file" "$query" 2>/dev/null
    else
        # No JSON parser available
        echo "null"
        return 1
    fi
}

# ==============================================================================
# Policy Loading
# ==============================================================================

# Load policy from JSON file
load_policy() {
    if [[ "$POLICY_LOADED" == "true" ]]; then
        return 0
    fi

    if [[ ! -f "$POLICY_FILE" ]]; then
        log_error "Policy file not found: $POLICY_FILE"
        return 1
    fi

    # Verify JSON is valid (check version field)
    local version=$(parse_json_file "$POLICY_FILE" ".version")
    if [[ -z "$version" || "$version" == "null" ]]; then
        log_error "Invalid JSON in policy file or JSON parser not available"
        return 1
    fi

    POLICY_LOADED=true
    log_info "Policy loaded from $POLICY_FILE"

    return 0
}

# ==============================================================================
# Policy Query Functions
# ==============================================================================

# Get all patterns for a policy category
get_policy_patterns() {
    local category="$1"

    if [[ ! -f "$POLICY_FILE" ]]; then
        echo "[]"
        return 1
    fi

    # Get patterns array - simplified approach
    parse_json_file "$POLICY_FILE" ".policies.$category.patterns" 2>/dev/null || echo "[]"
}

# Get action for a policy category
get_policy_action() {
    local category="$1"

    if [[ ! -f "$POLICY_FILE" ]]; then
        echo "warn"
        return 1
    fi

    local action=$(parse_json_file "$POLICY_FILE" ".policies.$category.action")
    echo "${action:-warn}"
}

# ==============================================================================
# Command Validation
# ==============================================================================

# Validate a command against all policies
validate_tool_call() {
    local command="$1"

    # Ensure policy is loaded
    load_policy || return 1

    # Check against each policy category
    local categories=("dangerous_commands" "git_operations" "file_operations" "network_operations" "privileged_operations")

    for category in "${categories[@]}"; do
        local result=$(check_policy_category "$command" "$category")

        # Extract status from JSON result using grep/sed (avoids fragile JSON parsing
        # when alternatives contain unescaped quotes from policy data)
        local status=$(echo "$result" | grep -o '"status":"[^"]*"' | head -1 | sed 's/"status":"//;s/"//')

        if [[ "$status" == "blocked" ]]; then
            # Blocked - return error
            echo "$result"
            log_error "Command blocked by policy" "{\"category\":\"$category\",\"command\":\"$command\"}"
            return 2
        elif [[ "$status" == "requires_approval" ]]; then
            # Requires approval
            echo "$result"
            log_warn "Command requires approval" "{\"category\":\"$category\",\"command\":\"$command\"}"
            return 3
        elif [[ "$status" == "warning" ]]; then
            # Warning but allowed
            echo "$result"
            log_warn "Command triggered warning" "{\"category\":\"$category\",\"command\":\"$command\"}"
            return 4
        fi
    done

    # No policy violations
    echo '{"status":"allowed","command":"'"$command"'"}'
    return 0
}

# Check command against specific policy category (simplified for bash without jq)
check_policy_category() {
    local command="$1"
    local category="$2"

    local action=$(get_policy_action "$category")

    # Get patterns from JSON file (simplified - read directly)
    local policy_json=$(cat "$POLICY_FILE" 2>/dev/null)

    # Extract patterns for this category using Node.js if available
    if command -v node &>/dev/null && [[ -f "$JSON_PARSER" ]]; then
        local pattern_count=$(echo "$policy_json" | node "$JSON_PARSER" - ".policies.$category.patterns" | grep -c "pattern" || echo 0)

        for i in $(seq 0 10); do
            local pattern=$(echo "$policy_json" | node "$JSON_PARSER" - ".policies.$category.patterns[$i].pattern" 2>/dev/null)
            if [[ -z "$pattern" || "$pattern" == "null" ]]; then
                break
            fi

            # Check if command matches pattern
            if echo "$command" | grep -qE "$pattern"; then
                local reason=$(echo "$policy_json" | node "$JSON_PARSER" - ".policies.$category.patterns[$i].reason")

                # Get alternatives (just first 3 for simplicity)
                local alt1=$(echo "$policy_json" | node "$JSON_PARSER" - ".policies.$category.patterns[$i].alternatives[0]" 2>/dev/null)
                local alt2=$(echo "$policy_json" | node "$JSON_PARSER" - ".policies.$category.patterns[$i].alternatives[1]" 2>/dev/null)
                local alt3=$(echo "$policy_json" | node "$JSON_PARSER" - ".policies.$category.patterns[$i].alternatives[2]" 2>/dev/null)

                # Build alternatives array
                local alternatives="["
                [[ -n "$alt1" && "$alt1" != "null" ]] && alternatives+="\"$alt1\","
                [[ -n "$alt2" && "$alt2" != "null" ]] && alternatives+="\"$alt2\","
                [[ -n "$alt3" && "$alt3" != "null" ]] && alternatives+="\"$alt3\""
                alternatives="${alternatives%,}]"

                # Pattern matched - determine action
                case "$action" in
                    block)
                        echo "{\"status\":\"blocked\",\"reason\":\"$reason\",\"pattern\":\"$pattern\",\"alternatives\":$alternatives}"
                        return 0
                        ;;
                    require_approval)
                        echo "{\"status\":\"requires_approval\",\"reason\":\"$reason\",\"pattern\":\"$pattern\"}"
                        return 0
                        ;;
                    warn)
                        echo "{\"status\":\"warning\",\"reason\":\"$reason\",\"pattern\":\"$pattern\",\"alternatives\":$alternatives}"
                        return 0
                        ;;
                esac
            fi
        done
    fi

    # No match
    echo '{"status":"allowed"}'
    return 0
}

# ==============================================================================
# Policy Reporting
# ==============================================================================

# Display policy violation message
display_policy_violation() {
    local result="$1"

    local status=$(echo "$result" | parse_json - ".status")
    local reason=$(echo "$result" | parse_json - ".reason")
    local pattern=$(echo "$result" | parse_json - ".pattern")

    echo ""
    echo "=========================================="
    echo "Policy Violation: $status"
    echo "=========================================="
    echo "Reason: $reason"
    echo "Pattern matched: $pattern"
    echo ""

    # Extract alternatives (simplified)
    local alternatives=$(echo "$result" | grep -o '"alternatives":\[.*\]' | sed 's/"alternatives"://g')

    if [[ -n "$alternatives" && "$alternatives" != "[]" ]]; then
        echo "SAFE ALTERNATIVES:"
        echo "$alternatives" | tr ',' '\n' | tr -d '[]"' | while IFS= read -r alt; do
            if [[ -n "$alt" ]]; then
                echo "  - $alt"
            fi
        done
        echo ""
    fi

    echo "=========================================="
}

# List all policy violations for a command
check_all_policies() {
    local command="$1"

    echo "Policy Check: $command"
    echo "========================================"

    local result=$(validate_tool_call "$command")
    local status=$(echo "$result" | parse_json - ".status")

    case "$status" in
        allowed)
            echo "✓ Command is allowed"
            ;;
        warning)
            echo "⚠ Warning:"
            display_policy_violation "$result"
            ;;
        requires_approval)
            echo "⊙ Requires approval:"
            display_policy_violation "$result"
            ;;
        blocked)
            echo "✗ Command is BLOCKED:"
            display_policy_violation "$result"
            ;;
    esac

    echo "========================================"
}

# ==============================================================================
# Policy Statistics
# ==============================================================================

# Get policy statistics
get_policy_stats() {
    if [[ ! -f "$POLICY_FILE" ]]; then
        echo "Policy file not found"
        return 1
    fi

    local total_policies=$(parse_json_file "$POLICY_FILE" ".metadata.total_policies")
    local total_patterns=$(parse_json_file "$POLICY_FILE" ".metadata.total_patterns")
    local version=$(parse_json_file "$POLICY_FILE" ".version")

    echo "Policy Statistics:"
    echo "  Version: ${version:-unknown}"
    echo "  Total policies: ${total_policies:-0}"
    echo "  Total patterns: ${total_patterns:-0}"
}

# ==============================================================================
# Testing Utilities
# ==============================================================================

# Test a command against policies (for testing)
test_policy() {
    local command="$1"

    check_all_policies "$command"
}

# ==============================================================================
# Export functions
# ==============================================================================

export -f load_policy
export -f validate_tool_call
export -f check_policy_category
export -f display_policy_violation
export -f check_all_policies
export -f get_policy_stats
export -f test_policy
export -f parse_json
export -f parse_json_file

# Initialize on source
load_policy || log_warn "Failed to load policy on initialization"
