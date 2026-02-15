#!/usr/bin/env bash
# Keyword Backend (v1.0 compatible)
# Plugin: sdd-memory v2.0.0
# Wraps the existing grep-based keyword search as a pluggable backend.
#
# This is the default backend that preserves all v1.0 behavior.
# It implements the backend interface defined in backend-interface.sh.

set -euo pipefail

KEYWORD_BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYWORD_PLUGIN_DIR="$(cd "$KEYWORD_BACKEND_DIR/.." && pwd)"
KEYWORD_REPO_ROOT="$(cd "$KEYWORD_PLUGIN_DIR/../.." && pwd)"

# Source the backend interface
source "$KEYWORD_BACKEND_DIR/backend-interface.sh"

# ============================================
# Configuration (from memory.conf or memory-v2.conf)
# ============================================

STOP_WORDS="${STOP_WORDS:-the a an is are was were be been being have has had do does did will would shall should may might can could of in to for on with at by from as into through during before after above below between out off over under}"

# ============================================
# Internal Functions
# ============================================

# Extract keywords from a query (remove stop words, short words)
_keyword_extract() {
    local message="$1"
    local words
    words=$(echo "$message" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' | sort -u)

    local keywords=""
    for word in $words; do
        [ ${#word} -lt 3 ] && continue
        if ! echo " $STOP_WORDS " | grep -qi " $word "; then
            keywords="${keywords:+$keywords }$word"
        fi
    done
    echo "$keywords"
}

# Search a single directory for keyword matches
_keyword_search_dir() {
    local search_path="$1"
    local keyword="$2"
    local max_per_keyword="${3:-3}"

    [ -e "$search_path" ] || return 0

    local matches
    matches=$(grep -ril "$keyword" "$search_path" 2>/dev/null | head -"$max_per_keyword") || true

    for match_file in $matches; do
        [ -f "$match_file" ] || continue
        # Skip binary/large files
        local file_size
        file_size=$(wc -c < "$match_file" 2>/dev/null || echo "999999")
        [ "$file_size" -gt 50000 ] && continue

        # Get line number of first match
        local line_info
        line_info=$(grep -n -m 1 -i "$keyword" "$match_file" 2>/dev/null | head -1) || continue
        local line_num
        line_num=$(echo "$line_info" | cut -d: -f1)
        [ -z "$line_num" ] && continue

        # Get surrounding context (2 lines before and after)
        local start=$((line_num > 2 ? line_num - 2 : 1))
        local end=$((line_num + 2))
        local context
        context=$(sed -n "${start},${end}p" "$match_file" 2>/dev/null) || continue

        # Score: count keyword occurrences in file
        local match_count
        match_count=$(grep -ci "$keyword" "$match_file" 2>/dev/null || echo "0")

        # Normalize score (simple: match_count / 10, capped at 1.0)
        local score
        if [ "$match_count" -ge 10 ]; then
            score="1.0"
        else
            # Use awk for float division
            score=$(awk "BEGIN {printf \"%.2f\", $match_count / 10}")
        fi

        local rel_path="${match_file#$KEYWORD_REPO_ROOT/}"
        format_search_result "$score" "$rel_path" "$line_num" "$context"
    done
}

# ============================================
# Backend Interface Implementation
# ============================================

backend_search() {
    local query="${1:-}"
    local max_results="${2:-10}"
    local timeout_ms="${3:-3000}"
    local scope="${4:-session}"

    if [ -z "$query" ]; then
        return 0
    fi

    local keywords
    keywords=$(_keyword_extract "$query")

    if [ -z "$keywords" ]; then
        return 0
    fi

    # Determine search paths based on scope
    local current_branch
    current_branch=$(git -C "$KEYWORD_REPO_ROOT" branch --show-current 2>/dev/null || echo "dev-main")

    local search_paths=()

    if [ "$scope" = "session" ]; then
        # Session scope: working + recall tiers only
        [ -d "$KEYWORD_REPO_ROOT/specs" ] && search_paths+=("$KEYWORD_REPO_ROOT/specs")
        [ -d "$KEYWORD_REPO_ROOT/.devloop/sessions" ] && search_paths+=("$KEYWORD_REPO_ROOT/.devloop/sessions")
        [ -d "$KEYWORD_REPO_ROOT/.docs" ] && search_paths+=("$KEYWORD_REPO_ROOT/.docs")
    else
        # Global scope: all tiers
        [ -d "$KEYWORD_REPO_ROOT/specs" ] && search_paths+=("$KEYWORD_REPO_ROOT/specs")
        [ -d "$KEYWORD_REPO_ROOT/.devloop/sessions" ] && search_paths+=("$KEYWORD_REPO_ROOT/.devloop/sessions")
        [ -d "$KEYWORD_REPO_ROOT/.docs" ] && search_paths+=("$KEYWORD_REPO_ROOT/.docs")
        [ -d "$KEYWORD_REPO_ROOT/.specify/memory" ] && search_paths+=("$KEYWORD_REPO_ROOT/.specify/memory")
        [ -d "$KEYWORD_REPO_ROOT/plugins" ] && search_paths+=("$KEYWORD_REPO_ROOT/plugins")
    fi

    # Search across all paths for all keywords, collect results
    local all_results=""
    for search_path in "${search_paths[@]}"; do
        for keyword in $keywords; do
            local results
            results=$(_keyword_search_dir "$search_path" "$keyword" 3)
            if [ -n "$results" ]; then
                all_results="${all_results}${results}
"
            fi
        done
    done

    # Sort by score descending, deduplicate by file, limit to max_results
    if [ -n "$all_results" ]; then
        echo "$all_results" | grep -v '^$' | sort -t$'\t' -k1 -rn | \
            awk -F'\t' '!seen[$2]++' | head -n "$max_results"
    fi

    return 0
}

backend_index() {
    # Keyword backend doesn't maintain an index — grep searches live
    return 0
}

backend_reindex_all() {
    # No index to rebuild for keyword search
    return 0
}

backend_health_check() {
    # Keyword backend is always healthy (just grep)
    echo "keyword backend: healthy (grep-based, no index required)"
    return 0
}
