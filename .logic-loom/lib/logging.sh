#!/usr/bin/env bash
# Structured Logging Library for LogicLoom
# Constitutional Principle VII: Observability and Structured Logging
#
# Provides JSON-formatted logging with:
# - Multiple log levels (DEBUG, INFO, WARN, ERROR)
# - Colorized console output
# - Plain JSON file output
# - Operation tracking with start/end
# - Context metadata support
# - Environment-aware (CLAUDE_LOG_LEVEL)

# ==============================================================================
# Configuration
# ==============================================================================

# Default log level (can be overridden by CLAUDE_LOG_LEVEL environment variable)
: "${CLAUDE_LOG_LEVEL:=INFO}"

# Log directory
LOG_DIR=".logic-loom/logs"
LOG_FILE="${LOG_DIR}/operations/$(date +%Y-%m-%d).log"

# Color codes for console output
COLOR_RESET='\033[0m'
COLOR_DEBUG='\033[0;36m'    # Cyan
COLOR_INFO='\033[0;32m'     # Green
COLOR_WARN='\033[0;33m'     # Yellow
COLOR_ERROR='\033[0;31m'    # Red
COLOR_BOLD='\033[1m'

# Log level priorities (for filtering)
declare -A LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
)

# ==============================================================================
# Private Functions
# ==============================================================================

# Get current log level priority
_get_log_level_priority() {
    local level="${1:-INFO}"
    echo "${LOG_LEVELS[$level]:-1}"
}

# Check if message should be logged based on level
_should_log() {
    local message_level="$1"
    local current_level="${CLAUDE_LOG_LEVEL:-INFO}"

    local message_priority=$(_get_log_level_priority "$message_level")
    local current_priority=$(_get_log_level_priority "$current_level")

    [[ $message_priority -ge $current_priority ]]
}

# Get color for log level
_get_color() {
    local level="$1"
    case "$level" in
        DEBUG) echo -n "$COLOR_DEBUG" ;;
        INFO)  echo -n "$COLOR_INFO" ;;
        WARN)  echo -n "$COLOR_WARN" ;;
        ERROR) echo -n "$COLOR_ERROR" ;;
        *)     echo -n "$COLOR_RESET" ;;
    esac
}

# Escape JSON string
_escape_json() {
    local str="$1"
    # Escape backslashes, quotes, newlines, tabs
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\t'/\\t}"
    str="${str//$'\r'/\\r}"
    echo "$str"
}

# Create JSON log entry
_create_json_log() {
    local level="$1"
    local message="$2"
    local context="$3"

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local escaped_message=$(_escape_json "$message")

    # Build JSON object
    local json="{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$escaped_message\""

    if [[ -n "$context" ]]; then
        # Context should be raw JSON, not escaped as string
        json="$json,\"context\":$context"
    fi

    json="$json}"
    echo "$json"
}

# Write log to file
_write_to_file() {
    local json_log="$1"

    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"

    # Write to log file (plain JSON, one per line)
    echo "$json_log" >> "$LOG_FILE"
}

# Write log to console (colorized)
_write_to_console() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%H:%M:%S")

    local color=$(_get_color "$level")
    local level_padded=$(printf "%-5s" "$level")

    echo -e "${COLOR_BOLD}[${timestamp}]${COLOR_RESET} ${color}${level_padded}${COLOR_RESET} ${message}" >&2
}

# Core logging function
_log() {
    local level="$1"
    local message="$2"
    local context="${3:-}"

    # Check if we should log this level
    if ! _should_log "$level"; then
        return 0
    fi

    # Create JSON log entry
    local json_log=$(_create_json_log "$level" "$message" "$context")

    # Write to file
    _write_to_file "$json_log"

    # Write to console
    _write_to_console "$level" "$message"
}

# ==============================================================================
# Public API
# ==============================================================================

# Log debug message
# Usage: log_debug "message" ["context_json"]
log_debug() {
    local message="$1"
    local context="${2:-}"
    _log "DEBUG" "$message" "$context"
}

# Log info message
# Usage: log_info "message" ["context_json"]
log_info() {
    local message="$1"
    local context="${2:-}"
    _log "INFO" "$message" "$context"
}

# Log warning message
# Usage: log_warn "message" ["context_json"]
log_warn() {
    local message="$1"
    local context="${2:-}"
    _log "WARN" "$message" "$context"
}

# Log error message
# Usage: log_error "message" ["context_json"]
log_error() {
    local message="$1"
    local context="${2:-}"
    _log "ERROR" "$message" "$context"
}

# Track operation start
# Usage: log_operation_start "operation_name" ["details"]
# Returns: Operation ID (timestamp-based)
log_operation_start() {
    local operation="$1"
    local details="${2:-}"
    local operation_id="$(date +%s%N)"

    local context="{\"operation\":\"$operation\",\"operation_id\":\"$operation_id\",\"phase\":\"start\""
    if [[ -n "$details" ]]; then
        local escaped_details=$(_escape_json "$details")
        context="$context,\"details\":\"$escaped_details\""
    fi
    context="$context}"

    _log "INFO" "Operation started: $operation" "$context"

    # Store operation start time for duration calculation
    export "OPERATION_START_${operation_id}=$(date +%s%N)"

    echo "$operation_id"
}

# Track operation end
# Usage: log_operation_end "operation_id" "operation_name" "status" ["details"]
log_operation_end() {
    local operation_id="$1"
    local operation="$2"
    local status="$3"
    local details="${4:-}"

    # Calculate duration
    local start_var="OPERATION_START_${operation_id}"
    local start_time="${!start_var:-$(date +%s%N)}"
    local end_time=$(date +%s%N)
    local duration_ns=$((end_time - start_time))
    local duration_ms=$((duration_ns / 1000000))

    local context="{\"operation\":\"$operation\",\"operation_id\":\"$operation_id\",\"phase\":\"end\",\"status\":\"$status\",\"duration_ms\":$duration_ms"
    if [[ -n "$details" ]]; then
        local escaped_details=$(_escape_json "$details")
        context="$context,\"details\":\"$escaped_details\""
    fi
    context="$context}"

    local level="INFO"
    if [[ "$status" == "error" || "$status" == "failed" ]]; then
        level="ERROR"
    fi

    _log "$level" "Operation ended: $operation ($status, ${duration_ms}ms)" "$context"

    # Clean up stored start time
    unset "$start_var"
}

# ==============================================================================
# Initialization
# ==============================================================================

# Ensure log directory structure exists
_init_logging() {
    mkdir -p "$LOG_DIR/operations"
    mkdir -p "$LOG_DIR/errors"
    mkdir -p "$LOG_DIR/metrics"
}

# Initialize on source
_init_logging
