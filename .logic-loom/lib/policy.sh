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
JSON_PARSER="$REPO_ROOT/.logic-loom/lib/json-parse.cjs"

# Load logging if available
if [[ -f "$REPO_ROOT/.logic-loom/lib/logging.sh" ]]; then
    source "$REPO_ROOT/.logic-loom/lib/logging.sh"
else
    log_info() { echo "[INFO] $1" >&2; }
    log_warn() { echo "[WARN] $1" >&2; }
    log_error() { echo "[ERROR] $1" >&2; }
fi

# Cache for loaded policy.
# Plain top-level assignment (not `declare -g`) so this lib loads on bash 3.2 —
# macOS ships 3.2 as /bin/bash, and `declare -g` is a bash 4+ builtin option. At
# script scope a plain assignment is already global, so behaviour is identical.
POLICY_LOADED=false

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
        elif [[ "$status" == "unavailable" ]]; then
            # Cannot evaluate policy at all — fail SAFE (ask a human), not open.
            echo "$result"
            log_error "Policy matcher unavailable" "{\"category\":\"$category\"}"
            return 5
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

# ------------------------------------------------------------------------------
# Reduce a command string to the part that is CODE, for pattern matching.
#
# Why: patterns are matched against the raw command string, so a command that
# merely QUOTES a dangerous example as DATA (a PR body, a commit message) used to
# be blocked. We strip those data arguments — but only where provably safe:
#
#   1. Only for programs that take arbitrary prose as data (gh/git/glab/jq/curl).
#      Interpreters (bash -c, sh -c, eval, xargs) are NEVER stripped — there the
#      quoted content IS code.
#   2. Only for values with no shell expansion (no `$`, no backtick). A value like
#      -m "$(rm -rf /)" is executed by the SHELL before the program ever starts, so
#      it must stay visible to the matcher. The negated character classes below are
#      what enforce that, and they carry the whole security load of this function.
#
# Anything not provably data is left untouched. The failure direction is therefore
# a false positive (annoying, visible), never a false negative (silent, unsafe).
#
# Known residual: heredoc bodies are not stripped, so a heredoc quoting a dangerous
# string still false-positives. That fails safe; use --body-file / -F <file>.
# ------------------------------------------------------------------------------
_policy_strip_data_args() {
    local command="$1"
    local argv0="${command%%[[:space:]]*}"
    argv0="${argv0##*/}"

    case "$argv0" in
        gh|git|glab|jq|curl) ;;
        *) printf '%s' "$command"; return 0 ;;
    esac

    printf '%s' "$command" | sed -E \
        -e 's/(--body-file|--body|--message|--title|--data-raw|--data|-m|-F|-d|-t)([[:space:]]+|=)"[^"$`]*"/\1 DATA/g' \
        -e "s/(--body-file|--body|--message|--title|--data-raw|--data|-m|-F|-d|-t)([[:space:]]+|=)'[^'\$\`]*'/\1 DATA/g"
}

# Anchor a policy pattern to a real command position.
#
# Every pattern in tool-restrictions.json begins with a command word (rm, git,
# pkill, chmod, curl, sudo, mv...). Matching them unanchored meant they also fired
# on the same words appearing mid-string as prose. This prefix requires the match to
# sit at the start of the string, or right after a shell operator or an opening
# quote/substitution — i.e. somewhere a command can actually begin.
#
# It deliberately also allows leading env assignments, option flags, and known
# wrapper commands, so `sudo rm -rf /`, `env FOO=1 rm -rf /`, `command rm -rf /`
# and `xargs -I{} rm -rf /` still match. Without that allowance, anchoring would
# LOSE true positives — the one outcome worse than the false positives it fixes.
# The leading `path` term is load-bearing: without it, `/bin/rm -rf /` would stop
# matching, which the OLD unanchored regex caught. Anchoring must never lose a true
# positive, so any absolute/relative path qualifier is allowed before the command.
_policy_match_anchor() {
    local wrap='(command|exec|sudo|nohup|nice|time|timeout|setsid|builtin|env|stdbuf|xargs|then|else|do|if|while|until)'
    local assign='([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)'
    local opt='(-[^[:space:]]+[[:space:]]+)'
    local path='([A-Za-z0-9_.-]*/)*'
    printf '%s' "(^|[;&|(){}!\`\"'])[[:space:]]*(${assign}|${opt}|${wrap}[[:space:]]+)*${path}"
}

# Check command against specific policy category (simplified for bash without jq)
check_policy_category() {
    local command="$1"
    local category="$2"

    local action=$(get_policy_action "$category")

    # Get patterns from JSON file (simplified - read directly)
    local policy_json=$(cat "$POLICY_FILE" 2>/dev/null)

    # Match against the CODE portion of the command, not quoted prose data.
    local scan_target
    scan_target=$(_policy_strip_data_args "$command")
    local anchor
    anchor=$(_policy_match_anchor)

    # Extract patterns for this category using Node.js if available
    if command -v node &>/dev/null && [[ -f "$JSON_PARSER" ]]; then
        # Bound is a runaway guard only; the loop breaks on the first absent index.
        # It was previously 10, which silently ignored any 12th pattern in a category.
        for i in $(seq 0 99); do
            local pattern=$(echo "$policy_json" | node "$JSON_PARSER" - ".policies.$category.patterns[$i].pattern" 2>/dev/null)
            if [[ -z "$pattern" || "$pattern" == "null" ]]; then
                break
            fi

            # Check if command matches pattern, anchored to a real command position.
            # grep exits 2 on a malformed regex. Treating that as "no match" would be a
            # silent fail-open on a typo'd pattern, so surface it as matcher failure.
            local grep_ec
            if echo "$scan_target" | grep -qE "${anchor}${pattern}"; then
                grep_ec=0
            else
                grep_ec=$?
            fi
            if [[ $grep_ec -eq 2 ]]; then
                echo "{\"status\":\"unavailable\",\"reason\":\"policy pattern failed to compile in category $category\"}"
                return 0
            fi
            if [[ $grep_ec -eq 0 ]]; then
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
    else
        # The matcher's dependency is missing, so NO pattern can be evaluated.
        # This used to fall through to "allowed" — the entire dangerous-command
        # policy silently stopped enforcing, with no signal anywhere. Report the
        # condition instead so the caller can degrade to human approval rather
        # than to a silent permit.
        echo '{"status":"unavailable","reason":"policy matcher unavailable (node or json-parse.cjs missing)"}'
        return 0
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

# ==============================================================================
# Loom freeze-scope helper (Principle XI — Stage 11, gstack-D)
# ==============================================================================

# loom_check_freeze_scope <target_path> <owns_list>
#   target_path: path relative to repo root (e.g. "features/foo/plan.md")
#   owns_list:   newline-separated list of allowed path patterns
#                (glob-style; trailing-slash or directory match grants children)
#
# Returns: 0 if target_path is within owns_list scope (allow)
#          1 if target_path is outside owns_list scope (deny)
#
# Used by .claude/hooks/freeze-write-scope.sh during /swarm implement runs.
loom_check_freeze_scope() {
    local target="$1"
    local owns="$2"

    # Empty owns list means "no restriction declared" → allow
    [ -n "$owns" ] || return 0
    [ -n "$target" ] || return 1

    local owned
    while IFS= read -r owned; do
        [ -z "$owned" ] && continue
        # Strip leading "./" and trailing "/" for consistent matching
        owned="${owned#./}"
        owned="${owned%/}"
        [ -z "$owned" ] && continue
        case "$target" in
            $owned|$owned/*)
                return 0
                ;;
        esac
    done <<< "$owns"

    return 1
}

export -f load_policy
export -f validate_tool_call
export -f check_policy_category
export -f display_policy_violation
export -f check_all_policies
export -f get_policy_stats
export -f test_policy
export -f parse_json
export -f parse_json_file
export -f loom_check_freeze_scope

# Initialize on source
load_policy || log_warn "Failed to load policy on initialization"
