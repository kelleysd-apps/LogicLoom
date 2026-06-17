#!/usr/bin/env bash
# Memory Context Search
# Plugin: loom-memory v2.0.0
# Searches project memory using pluggable backends and returns relevant context.
#
# Usage: bash memory-search.sh "user message content"
# Output: Formatted context block for additionalContext injection
#
# v2.0 changes:
#   - Pluggable backend interface (keyword, hybrid)
#   - BM25 + vector hybrid search with configurable weights
#   - Retention policy enforcement (lazy cleanup on each search)
#   - Scoped retrieval (session vs global)
#   - Backward compatible: defaults to v1.0 keyword-only behavior
#
# Designed to complete within 3-5 seconds. Fails gracefully (empty output on error).

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
LIB_DIR="$PLUGIN_DIR/lib"

# Load v1.0 config (backward compatible defaults)
CONF_FILE="$PLUGIN_DIR/config/memory.conf"
MEMORY_ENABLED="true"
MEMORY_MAX_TOKENS="2000"
MEMORY_CONFIDENCE_THRESHOLD="0.7"
MEMORY_MAX_CHUNKS="5"

if [ -f "$CONF_FILE" ]; then
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs | sed 's/^"//' | sed 's/"$//')
        case "$key" in
            MEMORY_ENABLED) MEMORY_ENABLED="$value" ;;
            MEMORY_MAX_TOKENS) MEMORY_MAX_TOKENS="$value" ;;
            MEMORY_CONFIDENCE_THRESHOLD) MEMORY_CONFIDENCE_THRESHOLD="$value" ;;
            MEMORY_MAX_CHUNKS) MEMORY_MAX_CHUNKS="$value" ;;
        esac
    done < "$CONF_FILE"
fi

# Load v2.0 config (overrides defaults)
CONF_V2_FILE="$PLUGIN_DIR/config/memory-v2.conf"
MEMORY_BACKEND="keyword"
INJECT_COUNT="5"
INJECT_POSITION="beginning"
MEMORY_TIMEOUT_MS="3000"
SCOPE_MODE="session"

if [ -f "$CONF_V2_FILE" ]; then
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs | sed 's/^"//' | sed 's/"$//')
        case "$key" in
            MEMORY_BACKEND) MEMORY_BACKEND="$value" ;;
            INJECT_COUNT) INJECT_COUNT="$value" ;;
            INJECT_POSITION) INJECT_POSITION="$value" ;;
            MEMORY_TIMEOUT_MS) MEMORY_TIMEOUT_MS="$value" ;;
            SCOPE_MODE) SCOPE_MODE="$value" ;;
            MEMORY_ENABLED) MEMORY_ENABLED="$value" ;;
            MEMORY_MAX_TOKENS) MEMORY_MAX_TOKENS="$value" ;;
            MEMORY_CONFIDENCE_THRESHOLD) MEMORY_CONFIDENCE_THRESHOLD="$value" ;;
            MEMORY_MAX_CHUNKS) MEMORY_MAX_CHUNKS="$value" ;;
        esac
    done < "$CONF_V2_FILE"
fi

# ============================================
# Retention Lazy Check
# ============================================

_run_retention_check() {
    if [ -f "$LIB_DIR/retention.sh" ]; then
        # Run retention lazy check in background (non-blocking)
        (
            source "$LIB_DIR/retention.sh"
            retention_lazy_check
        ) 2>/dev/null &
    fi
}

# ============================================
# Backend Selection
# ============================================

# Select and source the appropriate backend
_select_backend() {
    case "$MEMORY_BACKEND" in
        hybrid)
            if [ -f "$LIB_DIR/hybrid-search.sh" ]; then
                source "$LIB_DIR/hybrid-search.sh"
            else
                # Fall back to keyword if hybrid not available
                source "$LIB_DIR/keyword-backend.sh"
            fi
            ;;
        bm25)
            if [ -f "$LIB_DIR/bm25-search.sh" ]; then
                source "$LIB_DIR/bm25-search.sh"
            else
                source "$LIB_DIR/keyword-backend.sh"
            fi
            ;;
        vector)
            if [ -f "$LIB_DIR/vector-search.sh" ]; then
                source "$LIB_DIR/vector-search.sh"
            else
                source "$LIB_DIR/keyword-backend.sh"
            fi
            ;;
        keyword|*)
            source "$LIB_DIR/keyword-backend.sh"
            ;;
    esac
}

# ============================================
# Output Formatting
# ============================================

# Convert backend SearchResult lines to formatted context for injection.
# Input: SearchResult lines on stdin (SCORE\tFILE\tLINE\tSNIPPET)
# Output: Formatted markdown context block
_format_results() {
    local inject_count="$1"
    local max_tokens="$2"
    local confidence_threshold="$3"

    local results=""
    local count=0

    while IFS=$'\t' read -r score file_path line_num snippet; do
        [ -z "$score" ] && continue
        [ "$count" -ge "$inject_count" ] && break

        # Apply confidence threshold
        local above_threshold
        above_threshold=$(awk "BEGIN { print ($score >= $confidence_threshold) ? 1 : 0 }")
        [ "$above_threshold" -eq 0 ] && continue

        # Format as context entry
        results="${results}
---[memory:${file_path}:${line_num}:score=${score}]---
${snippet}"
        count=$((count + 1))
    done

    if [ -z "$results" ] || [ "$count" -eq 0 ]; then
        echo "No relevant context found."
        return
    fi

    # Estimate token count (rough: 4 chars per token)
    local char_count=${#results}
    local est_tokens=$((char_count / 4))

    # Truncate if over budget
    if [ "$est_tokens" -gt "$max_tokens" ]; then
        local max_chars=$((max_tokens * 4))
        results="${results:0:$max_chars}
... (truncated to ${max_tokens} token budget)"
    fi

    cat <<EOF
**MEMORY CONTEXT** (auto-retrieved from project knowledge):
${results}

_Memory search by loom-memory v2.0 (backend: ${MEMORY_BACKEND}). Confidence threshold: ${confidence_threshold}_
EOF
}

# ============================================
# Main
# ============================================

main() {
    local message="${1:-}"

    # Check if enabled
    if [ "$MEMORY_ENABLED" != "true" ]; then
        exit 0
    fi

    # Need a message to search
    if [ -z "$message" ]; then
        echo "No relevant context found."
        exit 0
    fi

    # Run retention lazy check (non-blocking background process)
    _run_retention_check

    # Select and source backend
    _select_backend

    # Execute search via backend interface
    local search_results
    search_results=$(backend_search "$message" "$INJECT_COUNT" "$MEMORY_TIMEOUT_MS" "$SCOPE_MODE" 2>/dev/null) || search_results=""

    # Format results for injection
    if [ -n "$search_results" ]; then
        echo "$search_results" | _format_results "$INJECT_COUNT" "$MEMORY_MAX_TOKENS" "$MEMORY_CONFIDENCE_THRESHOLD"
    else
        echo "No relevant context found."
    fi
}

main "$@"
