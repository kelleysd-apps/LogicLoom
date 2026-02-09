#!/usr/bin/env bash
# Memory Search Logger
# Plugin: sdd-memory v1.0.0
# Logs memory search metrics for observability (Principle VII)
#
# Usage: bash memory-log.sh "query" "results"
# Output: Appends to .docs/memory/search-log.jsonl

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../" && pwd)"
LOG_DIR="$REPO_ROOT/.docs/memory"
LOG_FILE="$LOG_DIR/search-log.jsonl"

# Create log directory
mkdir -p "$LOG_DIR"

QUERY="${1:-}"
RESULTS="${2:-}"
TIMESTAMP=$(date -Iseconds 2>/dev/null || date "+%Y-%m-%dT%H:%M:%S%z")
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"

# Count results
CHUNK_COUNT=$(echo "$RESULTS" | grep -c '\-\-\-\[' 2>/dev/null || echo "0")
CHAR_COUNT=${#RESULTS}
EST_TOKENS=$((CHAR_COUNT / 4))

# Extract keywords used
KEYWORDS=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' ' ' | xargs)

# Append log entry (JSONL format)
cat >> "$LOG_FILE" <<EOF
{"timestamp":"$TIMESTAMP","session":"$SESSION_ID","query_length":${#QUERY},"keywords":"$KEYWORDS","chunks_found":$CHUNK_COUNT,"tokens_injected":$EST_TOKENS,"chars":$CHAR_COUNT}
EOF
