#!/usr/bin/env bash
# Extract Enhancement Proposals from Upstream History
# Plugin: sdd-maintenance (Additive Update Framework)
# Feature: 005-agent-architecture-refactor
#
# Reads .sdd-sync-ref, diffs upstream's own history, and outputs
# categorized enhancement proposals for selective adoption.
#
# Usage:
#   bash extract-proposals.sh              # Full extraction
#   bash extract-proposals.sh --dry-run    # Show what would be extracted
#   bash extract-proposals.sh --help       # Show usage
#
# Output: JSON array of enhancement proposals to stdout

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SYNC_REF_FILE="$REPO_ROOT/.sdd-sync-ref"

# ============================================
# Usage
# ============================================

show_help() {
    cat <<'EOF'
Extract Enhancement Proposals from Upstream History

Usage:
  extract-proposals.sh              Full extraction from upstream
  extract-proposals.sh --dry-run    Show sync-ref and upstream status
  extract-proposals.sh --help       Show this help

Reads .sdd-sync-ref to determine the last sync point, then diffs
upstream's own history (sync-ref..upstream/main) to extract discrete
enhancement proposals. Never compares downstream vs upstream content.

Output: JSON array of enhancement proposals
EOF
}

# ============================================
# Functions
# ============================================

# Read sync reference
read_sync_ref() {
    if [ -f "$SYNC_REF_FILE" ]; then
        cat "$SYNC_REF_FILE" | tr -d '[:space:]'
    else
        echo ""
    fi
}

# Categorize a file change into proposal type
categorize_change() {
    local file_path="$1"
    local change_type="$2"  # A=added, M=modified, D=deleted, R=renamed

    case "$file_path" in
        plugins/*/commands/*)   echo "command" ;;
        plugins/*/skills/*)     echo "skill" ;;
        plugins/*/agents/*)     echo "agent" ;;
        plugins/*)              echo "plugin" ;;
        .specify/memory/*)      echo "governance" ;;
        .specify/scripts/*)     echo "script" ;;
        .specify/config/*)      echo "config" ;;
        .claude/*)              echo "config" ;;
        tests/*)                echo "test" ;;
        CLAUDE.md|AGENTS.md)    echo "config" ;;
        mcp-servers/*)          echo "mcp" ;;
        *)                      echo "other" ;;
    esac
}

# Generate proposal description from change
describe_change() {
    local file_path="$1"
    local change_type="$2"
    local category="$3"

    case "$change_type" in
        A) echo "New ${category}: ${file_path}" ;;
        M) echo "Updated ${category}: ${file_path}" ;;
        D) echo "Removed upstream: ${file_path}" ;;
        R*) echo "Renamed/restructured: ${file_path}" ;;
        *) echo "Changed: ${file_path}" ;;
    esac
}

# Determine proposal type from change type
proposal_type() {
    local change_type="$1"

    case "$change_type" in
        A) echo "new-file" ;;
        M) echo "modified-content" ;;
        D) echo "info" ;;
        R*) echo "structural-change" ;;
        *) echo "modified-content" ;;
    esac
}

# Extract proposals from upstream diff
extract_proposals() {
    local sync_ref="$1"
    local upstream_ref="${2:-upstream/main}"

    # Get list of changed files with status
    local changes
    changes=$(git -C "$REPO_ROOT" diff --name-status "$sync_ref..$upstream_ref" 2>/dev/null || echo "")

    if [ -z "$changes" ]; then
        echo "[]"
        return
    fi

    local proposals="["
    local first=true
    local id=1

    while IFS=$'\t' read -r status file_path; do
        [ -z "$status" ] && continue
        [ -z "$file_path" ] && continue

        local change_type="${status:0:1}"
        local category
        category=$(categorize_change "$file_path" "$change_type")
        local description
        description=$(describe_change "$file_path" "$change_type" "$category")
        local ptype
        ptype=$(proposal_type "$change_type")

        # Check if file exists downstream
        local downstream_exists="false"
        [ -f "$REPO_ROOT/$file_path" ] && downstream_exists="true"

        # For modifications, check if it's a structural change
        local breaking="false"
        if [ "$change_type" = "R" ] || echo "$status" | grep -q "R[0-9]"; then
            ptype="structural-change"
            breaking="true"
        fi

        if [ "$first" = true ]; then
            first=false
        else
            proposals="${proposals},"
        fi

        local padded_id
        padded_id=$(printf "EP-%03d" "$id")

        proposals="${proposals}
    {
      \"id\": \"$padded_id\",
      \"type\": \"$ptype\",
      \"category\": \"$category\",
      \"description\": \"$description\",
      \"upstream_file\": \"$file_path\",
      \"downstream_exists\": $downstream_exists,
      \"change_type\": \"$change_type\",
      \"status\": \"pending\",
      \"breaking\": $breaking
    }"

        id=$((id + 1))
    done <<< "$changes"

    proposals="${proposals}
  ]"

    echo "$proposals"
}

# ============================================
# Main
# ============================================

case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --dry-run)
        SYNC_REF=$(read_sync_ref)
        if [ -z "$SYNC_REF" ]; then
            echo "No .sdd-sync-ref found. Run initial setup first."
            echo "  echo \$(git rev-parse HEAD) > .sdd-sync-ref"
        else
            echo "Current sync-ref: $SYNC_REF"
            echo "Sync-ref date: $(git -C "$REPO_ROOT" log -1 --format='%ci' "$SYNC_REF" 2>/dev/null || echo 'unknown')"

            # Check if upstream exists
            if git -C "$REPO_ROOT" remote | grep -q upstream; then
                UPSTREAM_HEAD=$(git -C "$REPO_ROOT" rev-parse upstream/main 2>/dev/null || echo "unknown")
                echo "Upstream HEAD: $UPSTREAM_HEAD"

                if [ "$SYNC_REF" = "$UPSTREAM_HEAD" ]; then
                    echo "Status: UP TO DATE"
                else
                    CHANGE_COUNT=$(git -C "$REPO_ROOT" diff --name-only "$SYNC_REF..upstream/main" 2>/dev/null | wc -l | xargs)
                    echo "Status: $CHANGE_COUNT files changed upstream since last sync"
                fi
            else
                echo "No upstream remote configured."
                echo "  git remote add upstream https://github.com/kelleysd-apps/sdd-agentic-framework.git"
            fi
        fi
        exit 0
        ;;
    *)
        SYNC_REF=$(read_sync_ref)
        if [ -z "$SYNC_REF" ]; then
            echo "Error: No .sdd-sync-ref found." >&2
            echo "Initialize with: echo \$(git rev-parse HEAD) > .sdd-sync-ref" >&2
            exit 1
        fi

        # Check upstream remote
        if ! git -C "$REPO_ROOT" remote | grep -q upstream; then
            echo "Error: No upstream remote configured." >&2
            echo "Add with: git remote add upstream <url>" >&2
            exit 1
        fi

        extract_proposals "$SYNC_REF" "upstream/main"
        ;;
esac
