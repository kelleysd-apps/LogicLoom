#!/usr/bin/env bash
# Memory Flush Mechanism
# Plugin: sdd-memory v2.0.0
# Persists critical session decisions, patterns, and errors to searchable markdown.
#
# Flush files are saved to the working tier and are searchable by the memory system.
# They follow the retention policy (session-scoped by default).
#
# Usage:
#   source memory-flush.sh
#   memory_flush "session-abc123"
#   memory_flush_save "extracted content" "session-abc123"

set -euo pipefail

FLUSH_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUSH_PLUGIN_DIR="$(cd "$FLUSH_LIB_DIR/.." && pwd)"
FLUSH_REPO_ROOT="$(cd "$FLUSH_PLUGIN_DIR/../.." && pwd)"

# Working memory directory for flush files
FLUSH_OUTPUT_DIR="$FLUSH_PLUGIN_DIR/working"

# Ensure output directory exists
mkdir -p "$FLUSH_OUTPUT_DIR"

# ============================================
# Content Extraction
# ============================================

# Parse content for extractable knowledge.
# Extracts decisions, patterns, errors, and architectural choices from raw text.
# Args: $1=content (raw session text or log)
# Output: Structured extraction with labeled sections
memory_flush_extract() {
    local content="${1:-}"

    if [ -z "$content" ]; then
        echo ""
        return 0
    fi

    local decisions=""
    local patterns=""
    local errors=""
    local architectural=""

    # ── Extract Key Decisions ──
    # Look for decision indicators: "decided", "chose", "will use", "going with",
    # "selected", "approved", "confirmed", "agreed"
    local decision_lines
    decision_lines=$(echo "$content" | grep -i -E \
        '(decided|decision:|chose|chosen|will use|going with|selected|approved|confirmed|agreed to|we will|approach:)' \
        2>/dev/null || true)

    if [ -n "$decision_lines" ]; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            # Trim whitespace and limit length
            line=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-200)
            decisions="${decisions}- ${line}
"
        done <<< "$decision_lines"
    fi

    # ── Extract Patterns Discovered ──
    # Look for pattern indicators: "pattern", "convention", "standard", "best practice",
    # "rule:", "always", "never", "must"
    local pattern_lines
    pattern_lines=$(echo "$content" | grep -i -E \
        '(pattern:|convention:|standard:|best practice|rule:|naming:|format:|structure:)' \
        2>/dev/null || true)

    if [ -n "$pattern_lines" ]; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            line=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-200)
            patterns="${patterns}- ${line}
"
        done <<< "$pattern_lines"
    fi

    # ── Extract Errors Resolved ──
    # Look for error indicators: "error", "fix", "resolved", "bug", "issue",
    # "workaround", "caused by", "solution"
    local error_lines
    error_lines=$(echo "$content" | grep -i -E \
        '(error:|fix:|fixed|resolved|bug:|issue:|workaround:|caused by|solution:|broke|broken|failed)' \
        2>/dev/null || true)

    if [ -n "$error_lines" ]; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            line=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-200)
            errors="${errors}- ${line}
"
        done <<< "$error_lines"
    fi

    # ── Extract Architectural Choices ──
    # Look for architecture indicators: "architecture", "design", "component",
    # "interface", "contract", "schema", "API", "layer"
    local arch_lines
    arch_lines=$(echo "$content" | grep -i -E \
        '(architecture:|design:|component:|interface:|contract:|schema:|api:|layer:|module:|plugin:|service:)' \
        2>/dev/null || true)

    if [ -n "$arch_lines" ]; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            line=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-200)
            architectural="${architectural}- ${line}
"
        done <<< "$arch_lines"
    fi

    # ── Build output ──
    local output=""

    if [ -n "$decisions" ]; then
        output="${output}## Key Decisions
${decisions}
"
    else
        output="${output}## Key Decisions
- No explicit decisions extracted from session content.

"
    fi

    if [ -n "$patterns" ]; then
        output="${output}## Patterns Discovered
${patterns}
"
    else
        output="${output}## Patterns Discovered
- No explicit patterns extracted from session content.

"
    fi

    if [ -n "$errors" ]; then
        output="${output}## Errors Resolved
${errors}
"
    else
        output="${output}## Errors Resolved
- No errors resolved during this session.

"
    fi

    if [ -n "$architectural" ]; then
        output="${output}## Architectural Choices
${architectural}
"
    else
        output="${output}## Architectural Choices
- No architectural choices extracted from session content.

"
    fi

    echo "$output"
}

# ============================================
# Save
# ============================================

# Save extracted knowledge to a flush file in working memory.
# Args: $1=content (extracted/structured content), $2=session_id
# Output: Path to saved file
memory_flush_save() {
    local content="${1:-}"
    local session_id="${2:-unknown}"

    if [ -z "$content" ]; then
        echo "ERROR: No content to save" >&2
        return 1
    fi

    # Generate timestamp
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date "+%Y-%m-%dT%H:%M:%S%z")

    local file_timestamp
    file_timestamp=$(date +"%Y%m%d-%H%M%S" 2>/dev/null || date "+%Y%m%d-%H%M%S")

    local flush_file="$FLUSH_OUTPUT_DIR/flush-${file_timestamp}.md"

    # Build the flush document
    cat > "$flush_file" <<FLUSH_EOF
# Memory Flush -- ${session_id}
**Timestamp**: ${timestamp}
**Session**: ${session_id}

${content}
FLUSH_EOF

    echo "$flush_file"
}

# ============================================
# Main Flush Function
# ============================================

# Extract key decisions, patterns, and errors from the current session
# and persist to searchable markdown in working memory.
# Args: $1=session_id
# Output: Path to saved flush file, or empty on failure
memory_flush() {
    local session_id="${1:-${CLAUDE_SESSION_ID:-unknown}}"

    # Collect session content from multiple sources
    local session_content=""

    # Source 1: Recent devloop session files (if they exist)
    local devloop_sessions_dir="$FLUSH_REPO_ROOT/.devloop/sessions"
    if [ -d "$devloop_sessions_dir" ]; then
        local recent_files
        recent_files=$(find "$devloop_sessions_dir" -name "*.md" -type f -mmin -120 2>/dev/null | head -5) || true
        for f in $recent_files; do
            [ -f "$f" ] || continue
            local file_content
            file_content=$(cat "$f" 2>/dev/null || true)
            session_content="${session_content}
${file_content}"
        done
    fi

    # Source 2: Recent memory log entries
    local memory_log="$FLUSH_REPO_ROOT/.docs/memory/search-log.jsonl"
    if [ -f "$memory_log" ]; then
        local recent_log
        recent_log=$(tail -20 "$memory_log" 2>/dev/null || true)
        session_content="${session_content}
${recent_log}"
    fi

    # Source 3: Recent git commit messages (last 10 commits from this session)
    local git_messages
    git_messages=$(git -C "$FLUSH_REPO_ROOT" log --oneline -10 --format="%s" 2>/dev/null || true)
    if [ -n "$git_messages" ]; then
        session_content="${session_content}
${git_messages}"
    fi

    # Source 4: Any existing working memory files from this session
    if [ -d "$FLUSH_OUTPUT_DIR" ]; then
        for f in "$FLUSH_OUTPUT_DIR"/*; do
            [ -f "$f" ] || continue
            local basename
            basename=$(basename "$f")
            [ "$basename" = ".gitkeep" ] && continue
            # Only include files that reference our session
            if grep -q "$session_id" "$f" 2>/dev/null; then
                local existing_content
                existing_content=$(cat "$f" 2>/dev/null || true)
                session_content="${session_content}
${existing_content}"
            fi
        done
    fi

    if [ -z "$session_content" ]; then
        echo "No session content found to flush." >&2
        return 0
    fi

    # Extract structured knowledge
    local extracted
    extracted=$(memory_flush_extract "$session_content")

    if [ -z "$extracted" ]; then
        echo "No extractable knowledge found." >&2
        return 0
    fi

    # Save to flush file
    local saved_path
    saved_path=$(memory_flush_save "$extracted" "$session_id")

    echo "$saved_path"
}
