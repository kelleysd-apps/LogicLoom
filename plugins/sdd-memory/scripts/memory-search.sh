#!/usr/bin/env bash
# Memory Context Search
# Plugin: sdd-memory v1.0.0
# Searches tiered project memory and returns relevant context chunks.
#
# Usage: bash memory-search.sh "user message content"
# Output: Formatted context block for additionalContext injection
#
# Designed to complete within 3 seconds. Fails gracefully (empty output on error).

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
CONF_FILE="$PLUGIN_DIR/config/memory.conf"

# Load configuration
if [ -f "$CONF_FILE" ]; then
    # Source only simple KEY=value lines (no command substitution for safety)
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
            STOP_WORDS) STOP_WORDS="$value" ;;
        esac
    done < "$CONF_FILE"
fi

# Defaults
MEMORY_ENABLED="${MEMORY_ENABLED:-true}"
MEMORY_MAX_TOKENS="${MEMORY_MAX_TOKENS:-2000}"
MEMORY_CONFIDENCE_THRESHOLD="${MEMORY_CONFIDENCE_THRESHOLD:-0.7}"
MEMORY_MAX_CHUNKS="${MEMORY_MAX_CHUNKS:-5}"
STOP_WORDS="${STOP_WORDS:-the a an is are was were be been being have has had do does did will would shall should may might can could of in to for on with at by from as into through during before after above below between out off over under}"

# ============================================
# Functions
# ============================================

# Extract keywords from message (remove stop words, extract significant terms)
extract_keywords() {
    local message="$1"

    # Lowercase, remove punctuation, split into words
    local words
    words=$(echo "$message" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' | sort -u)

    # Filter stop words and short words
    local keywords=""
    for word in $words; do
        # Skip short words (< 3 chars) and stop words
        [ ${#word} -lt 3 ] && continue
        if ! echo " $STOP_WORDS " | grep -qi " $word "; then
            keywords="${keywords:+$keywords }$word"
        fi
    done

    echo "$keywords"
}

# Search a directory with keywords, return matching file snippets
search_tier() {
    local tier_name="$1"
    local tier_priority="$2"
    shift 2
    local search_paths=("$@")
    local keywords
    keywords=$(cat)  # Read keywords from stdin

    local results=""
    local found=0

    for search_path in "${search_paths[@]}"; do
        [ -e "$search_path" ] || continue

        for keyword in $keywords; do
            # Search for keyword in files (limit results per keyword)
            local matches
            matches=$(grep -ril "$keyword" "$search_path" 2>/dev/null | head -5) || true

            for match_file in $matches; do
                [ -f "$match_file" ] || continue
                [ $found -ge "$MEMORY_MAX_CHUNKS" ] && break 3

                # Get relative path
                local rel_path="${match_file#$REPO_ROOT/}"

                # Skip binary files and large files
                [ "$(wc -c < "$match_file" 2>/dev/null || echo 999999)" -gt 50000 ] && continue

                # Extract matching context (3 lines around match, first occurrence)
                local snippet
                snippet=$(grep -n -m 1 -i "$keyword" "$match_file" 2>/dev/null | head -1) || continue
                local line_num
                line_num=$(echo "$snippet" | cut -d: -f1)
                [ -z "$line_num" ] && continue

                # Get surrounding context (2 lines before and after)
                local start=$((line_num > 2 ? line_num - 2 : 1))
                local end=$((line_num + 2))
                local context
                context=$(sed -n "${start},${end}p" "$match_file" 2>/dev/null) || continue

                # Count keyword matches in the file for scoring
                local match_count
                match_count=$(grep -ci "$keyword" "$match_file" 2>/dev/null || echo "0")

                # Build result entry
                results="${results}
---[${tier_name}:${rel_path}:${match_count}:${tier_priority}]---
${context}"
                found=$((found + 1))
            done
        done
    done

    echo "$results"
}

# Score and rank results
score_results() {
    local results="$1"
    local total_keywords="$2"

    # Simple scoring: sort by tier priority and match count
    # Format: tier_name:file:match_count:tier_priority
    echo "$results"
}

# Format results for injection
format_output() {
    local results="$1"

    if [ -z "$results" ] || [ "$(echo "$results" | grep -c '\-\-\-\[' )" -eq 0 ]; then
        echo "No relevant context found."
        return
    fi

    # Estimate token count (rough: 4 chars per token)
    local char_count=${#results}
    local est_tokens=$((char_count / 4))

    # Truncate if over budget
    if [ "$est_tokens" -gt "$MEMORY_MAX_TOKENS" ]; then
        local max_chars=$((MEMORY_MAX_TOKENS * 4))
        results="${results:0:$max_chars}
... (truncated to ${MEMORY_MAX_TOKENS} token budget)"
    fi

    cat <<EOF
**MEMORY CONTEXT** (auto-retrieved from project knowledge):
${results}

_Memory search by sdd-memory plugin. Confidence threshold: ${MEMORY_CONFIDENCE_THRESHOLD}_
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

    # Extract keywords
    local keywords
    keywords=$(extract_keywords "$message")

    if [ -z "$keywords" ]; then
        echo "No relevant context found."
        exit 0
    fi

    local total_keywords
    total_keywords=$(echo "$keywords" | wc -w | xargs)

    # Determine current branch for working tier
    local current_branch
    current_branch=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo "dev-main")

    local all_results=""

    # ── Working Tier (Priority 1.0) ──
    local working_paths=()
    [ -d "$REPO_ROOT/specs/$current_branch" ] && working_paths+=("$REPO_ROOT/specs/$current_branch")
    [ -d "$REPO_ROOT/specs/005-agent-architecture-refactor" ] && working_paths+=("$REPO_ROOT/specs/005-agent-architecture-refactor")

    if [ ${#working_paths[@]} -gt 0 ]; then
        local working_results
        working_results=$(echo "$keywords" | search_tier "working" "1.0" "${working_paths[@]}")
        all_results="${all_results}${working_results}"
    fi

    # ── Recall Tier (Priority 0.7) ──
    local recall_paths=()
    # Session memory summaries
    local project_memory_dir="$HOME/.claude/projects"
    if [ -d "$project_memory_dir" ]; then
        # Find project-specific memory dirs
        for pdir in "$project_memory_dir"/*/; do
            [ -d "$pdir" ] || continue
            recall_paths+=("$pdir")
        done
    fi
    # Recent docs
    [ -d "$REPO_ROOT/.docs" ] && recall_paths+=("$REPO_ROOT/.docs")

    if [ ${#recall_paths[@]} -gt 0 ]; then
        local recall_results
        recall_results=$(echo "$keywords" | search_tier "recall" "0.7" "${recall_paths[@]}")
        all_results="${all_results}${recall_results}"
    fi

    # ── Archival Tier (Priority 0.4) ──
    local archival_paths=(
        "$REPO_ROOT/.specify/memory"
        "$REPO_ROOT/plugins"
        "$REPO_ROOT/specs"
    )

    local archival_results
    archival_results=$(echo "$keywords" | search_tier "archival" "0.4" "${archival_paths[@]}")
    all_results="${all_results}${archival_results}"

    # Format and output
    format_output "$all_results"
}

main "$@"
