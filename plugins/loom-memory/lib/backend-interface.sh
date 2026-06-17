#!/usr/bin/env bash
# Memory Backend Interface
# Plugin: loom-memory v2.0.0
# Defines the pluggable search backend interface for memory retrieval.
#
# All backend implementations MUST source this file and implement:
#   backend_search(query, max_results, timeout_ms, scope) -> SearchResult lines
#   backend_index(file_path) -> 0 on success, 1 on failure
#   backend_reindex_all() -> 0 on success, 1 on failure
#   backend_health_check() -> 0 if healthy, 1 if unhealthy
#
# SearchResult line format (tab-separated):
#   SCORE<TAB>FILE_PATH<TAB>LINE_NUM<TAB>SNIPPET
#
# SearchOptions (passed as individual arguments):
#   max_results   - Maximum results to return (default: 10)
#   inject_count  - Results to inject into context (default: 5)
#   timeout_ms    - Timeout budget in ms (default: 3000)
#   scope         - Retrieval scope: "session" or "global" (default: "session")

set -euo pipefail

# ============================================
# Interface Version
# ============================================
BACKEND_INTERFACE_VERSION="2.0.0"

# ============================================
# SearchResult Schema
# ============================================
# Each result is a single line with tab-separated fields:
#   Field 1: score      - Float 0.0-1.0, relevance score
#   Field 2: file_path  - Absolute or repo-relative path to source file
#   Field 3: line_num   - Line number of match (0 if not applicable)
#   Field 4: snippet    - Text snippet (max 500 chars, newlines replaced with \n)
#
# Results MUST be sorted by score descending.

# ============================================
# Interface Function Stubs
# ============================================
# Backend implementations override these functions after sourcing this file.

# Search for relevant memory chunks.
# Args: $1=query, $2=max_results (default 10), $3=timeout_ms (default 3000), $4=scope (default "session")
# Output: SearchResult lines to stdout (tab-separated, one per line)
# Returns: 0 on success, 1 on error
backend_search() {
    echo "ERROR: backend_search() not implemented" >&2
    return 1
}

# Index a single file into the backend's search index.
# Args: $1=file_path (absolute path)
# Returns: 0 on success, 1 on failure
backend_index() {
    echo "ERROR: backend_index() not implemented" >&2
    return 1
}

# Rebuild the entire search index from scratch.
# Returns: 0 on success, 1 on failure
backend_reindex_all() {
    echo "ERROR: backend_reindex_all() not implemented" >&2
    return 1
}

# Check if the backend is operational.
# Returns: 0 if healthy, 1 if unhealthy
# Output: Optional status message to stdout
backend_health_check() {
    echo "ERROR: backend_health_check() not implemented" >&2
    return 1
}

# ============================================
# Shared Utilities
# ============================================

# Get the backend interface version
backend_interface_version() {
    echo "$BACKEND_INTERFACE_VERSION"
}

# Validate that a backend has implemented all required functions.
# Call this after sourcing a backend implementation to verify compliance.
# Returns: 0 if valid, 1 if missing implementations
backend_validate_implementation() {
    local backend_name="${1:-unknown}"
    local valid=0

    # Check each required function is no longer the stub
    for func in backend_search backend_index backend_reindex_all backend_health_check; do
        # Get function body and check it's not the stub
        local body
        body=$(declare -f "$func" 2>/dev/null || echo "")
        if [ -z "$body" ]; then
            echo "ERROR: $backend_name missing required function: $func" >&2
            valid=1
        elif echo "$body" | grep -q "not implemented"; then
            echo "ERROR: $backend_name has stub implementation for: $func" >&2
            valid=1
        fi
    done

    return $valid
}

# Format a search result line (helper for backend implementations)
# Args: $1=score, $2=file_path, $3=line_num, $4=snippet
format_search_result() {
    local score="$1"
    local file_path="$2"
    local line_num="${3:-0}"
    local snippet="${4:-}"

    # Replace newlines in snippet with literal \n
    snippet=$(echo "$snippet" | tr '\n' ' ' | cut -c1-500)

    printf "%s\t%s\t%s\t%s\n" "$score" "$file_path" "$line_num" "$snippet"
}

# Parse a search result line into variables
# Args: $1=result_line
# Sets: RESULT_SCORE, RESULT_FILE, RESULT_LINE, RESULT_SNIPPET
parse_search_result() {
    local line="$1"
    RESULT_SCORE=$(echo "$line" | cut -f1)
    RESULT_FILE=$(echo "$line" | cut -f2)
    RESULT_LINE=$(echo "$line" | cut -f3)
    RESULT_SNIPPET=$(echo "$line" | cut -f4)
}

# Apply top-K selection to results
# Reads results from stdin, outputs top K results
# Args: $1=K (number of results to keep)
top_k_results() {
    local k="${1:-5}"
    head -n "$k"
}
