#!/usr/bin/env bash
# Retention Policy Enforcement
# Plugin: loom-memory v2.0.0
# Enforces TTL-based retention policies for memory tiers.
#
# Tiers:
#   - Working: session-scoped (cleared on new session)
#   - Recall:  time-based TTL (default 14 days, configurable)
#   - Archival: permanent (never expired)
#
# Cleanup is lazy — called during search but only runs full sweep
# every RETENTION_CHECK_INTERVAL_MIN minutes.
#
# Usage:
#   source retention.sh
#   retention_lazy_check        # Call on every search (cheap)
#   retention_cleanup "all"     # Force full cleanup
#   retention_is_expired "/path/to/file" "working"

set -euo pipefail

RETENTION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RETENTION_PLUGIN_DIR="$(cd "$RETENTION_LIB_DIR/.." && pwd)"

# ============================================
# Configuration
# ============================================

RETENTION_CONF_FILE="$RETENTION_PLUGIN_DIR/config/memory-v2.conf"

# Defaults (overridden by config file)
WORKING_TTL="${WORKING_TTL:-session}"
RECALL_TTL="${RECALL_TTL:-14d}"
ARCHIVAL_TTL="${ARCHIVAL_TTL:-permanent}"

# How often (in minutes) to run a full cleanup sweep
RETENTION_CHECK_INTERVAL_MIN="${RETENTION_CHECK_INTERVAL_MIN:-10}"

# Timestamp file to track last cleanup run
RETENTION_LAST_RUN_FILE="$RETENTION_PLUGIN_DIR/.retention-last-run"

# Memory tier directories
WORKING_DIR="$RETENTION_PLUGIN_DIR/working"
RECALL_DIR="$RETENTION_PLUGIN_DIR/recall"
ARCHIVAL_DIR="$RETENTION_PLUGIN_DIR/archival"

# Load configuration from memory-v2.conf
_retention_load_config() {
    [ -f "$RETENTION_CONF_FILE" ] || return 0

    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs | sed 's/^"//' | sed 's/"$//')
        case "$key" in
            WORKING_TTL)  WORKING_TTL="$value" ;;
            RECALL_TTL)   RECALL_TTL="$value" ;;
            ARCHIVAL_TTL) ARCHIVAL_TTL="$value" ;;
        esac
    done < "$RETENTION_CONF_FILE"
}

# Load config on source
_retention_load_config

# ============================================
# Directory Initialization
# ============================================

# Ensure memory tier directories exist with .gitkeep files
_retention_ensure_dirs() {
    for dir in "$WORKING_DIR" "$RECALL_DIR" "$ARCHIVAL_DIR"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
        fi
        if [ ! -f "$dir/.gitkeep" ]; then
            touch "$dir/.gitkeep"
        fi
    done
}

# Initialize directories on source
_retention_ensure_dirs

# ============================================
# TTL Parsing
# ============================================

# Parse a TTL value into seconds.
# Args: $1=ttl_string (e.g., "14d", "session", "permanent")
# Output: seconds as integer, or "session" / "permanent" for special values
_retention_parse_ttl_seconds() {
    local ttl="$1"

    case "$ttl" in
        session)
            echo "session"
            ;;
        permanent)
            echo "permanent"
            ;;
        *d)
            # Days: strip trailing 'd', multiply by 86400
            local days="${ttl%d}"
            echo $(( days * 86400 ))
            ;;
        *h)
            # Hours: strip trailing 'h', multiply by 3600
            local hours="${ttl%h}"
            echo $(( hours * 3600 ))
            ;;
        *m)
            # Minutes: strip trailing 'm', multiply by 60
            local mins="${ttl%m}"
            echo $(( mins * 60 ))
            ;;
        *)
            # Default: treat as days if numeric
            if [[ "$ttl" =~ ^[0-9]+$ ]]; then
                echo $(( ttl * 86400 ))
            else
                echo "permanent"
            fi
            ;;
    esac
}

# ============================================
# Public Functions
# ============================================

# Get TTL for a tier from config.
# Args: $1=tier ("working", "recall", "archival")
# Output: TTL string (e.g., "session", "14d", "permanent")
retention_get_ttl() {
    local tier="${1:-}"

    case "$tier" in
        working)  echo "$WORKING_TTL" ;;
        recall)   echo "$RECALL_TTL" ;;
        archival) echo "$ARCHIVAL_TTL" ;;
        *)
            echo "ERROR: Unknown tier: $tier" >&2
            return 1
            ;;
    esac
}

# Check if a single file is expired for its tier.
# Args: $1=file_path, $2=tier ("working", "recall", "archival")
# Returns: 0 if expired (should be removed), 1 if still valid
retention_is_expired() {
    local file_path="${1:-}"
    local tier="${2:-}"

    if [ ! -f "$file_path" ]; then
        return 1
    fi

    # Skip .gitkeep files — never expire
    local basename
    basename=$(basename "$file_path")
    if [ "$basename" = ".gitkeep" ]; then
        return 1
    fi

    local ttl
    ttl=$(retention_get_ttl "$tier") || return 1

    local ttl_seconds
    ttl_seconds=$(_retention_parse_ttl_seconds "$ttl")

    case "$ttl_seconds" in
        permanent)
            # Archival tier: never expires
            return 1
            ;;
        session)
            # Working tier: expired if session ID doesn't match current session
            local current_session="${CLAUDE_SESSION_ID:-}"
            if [ -z "$current_session" ]; then
                # No session ID available — cannot determine, keep file
                return 1
            fi
            # Check if file contains or is tagged with current session ID
            # Convention: working memory files are named with session prefix
            # or contain session ID in first line
            if echo "$basename" | grep -q "$current_session"; then
                return 1  # Matches current session — still valid
            fi
            # Check first line for session tag
            local first_line
            first_line=$(head -1 "$file_path" 2>/dev/null || echo "")
            if echo "$first_line" | grep -q "$current_session"; then
                return 1  # Matches current session — still valid
            fi
            # Session ID does not match — expired
            return 0
            ;;
        *)
            # Time-based TTL: compare file modification time
            local now
            now=$(date +%s)
            local file_mtime
            # macOS uses stat -f, Linux uses stat -c
            if stat -f "%m" "$file_path" >/dev/null 2>&1; then
                file_mtime=$(stat -f "%m" "$file_path")
            else
                file_mtime=$(stat -c "%Y" "$file_path" 2>/dev/null || echo "$now")
            fi
            local age=$(( now - file_mtime ))
            if [ "$age" -gt "$ttl_seconds" ]; then
                return 0  # Expired
            else
                return 1  # Still valid
            fi
            ;;
    esac
}

# Run cleanup on memory files for a given scope.
# Args: $1=scope ("working", "recall", "all")
# Archival tier is never touched.
# Returns: number of files removed (via stdout)
retention_cleanup() {
    local scope="${1:-all}"
    local removed=0

    # Working tier cleanup
    if [ "$scope" = "working" ] || [ "$scope" = "all" ]; then
        if [ -d "$WORKING_DIR" ]; then
            for file in "$WORKING_DIR"/*; do
                [ -f "$file" ] || continue
                if retention_is_expired "$file" "working"; then
                    rm -f "$file"
                    removed=$((removed + 1))
                fi
            done
        fi
    fi

    # Recall tier cleanup
    if [ "$scope" = "recall" ] || [ "$scope" = "all" ]; then
        if [ -d "$RECALL_DIR" ]; then
            for file in "$RECALL_DIR"/*; do
                [ -f "$file" ] || continue
                if retention_is_expired "$file" "recall"; then
                    rm -f "$file"
                    removed=$((removed + 1))
                fi
            done
        fi
    fi

    # Archival tier: never touched
    # (intentionally no archival cleanup)

    echo "$removed"
}

# Lightweight check called on each search.
# Only runs full cleanup every RETENTION_CHECK_INTERVAL_MIN minutes.
# Returns: 0 always (non-blocking, best-effort)
retention_lazy_check() {
    local now
    now=$(date +%s)

    # Check if enough time has elapsed since last run
    if [ -f "$RETENTION_LAST_RUN_FILE" ]; then
        local last_run
        last_run=$(cat "$RETENTION_LAST_RUN_FILE" 2>/dev/null || echo "0")
        local interval_seconds=$(( RETENTION_CHECK_INTERVAL_MIN * 60 ))
        local elapsed=$(( now - last_run ))

        if [ "$elapsed" -lt "$interval_seconds" ]; then
            # Too soon — skip cleanup
            return 0
        fi
    fi

    # Update last-run timestamp
    echo "$now" > "$RETENTION_LAST_RUN_FILE"

    # Run full cleanup (non-blocking: capture output but don't print)
    local removed
    removed=$(retention_cleanup "all" 2>/dev/null || echo "0")

    if [ "$removed" -gt 0 ]; then
        # Log cleanup activity for observability (Principle VII)
        echo "[retention] Cleaned up $removed expired memory files" >&2
    fi

    return 0
}
