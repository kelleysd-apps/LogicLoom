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

Each proposal includes a release_tag field associating it with the
upstream release (e.g., v4.1.0) it belongs to. Use --dry-run to see
which releases have been published since your last sync.

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

# List release tags in the sync-ref..upstream/main range
# Output: newline-separated "tag commit_hash" pairs, newest first
list_tags_in_range() {
    local sync_ref="$1"
    local upstream_ref="${2:-upstream/main}"

    # Get all tags that point to commits in the range
    git -C "$REPO_ROOT" log --format='%H' "$sync_ref..$upstream_ref" 2>/dev/null | while read -r commit; do
        local tag
        tag=$(git -C "$REPO_ROOT" tag --points-at "$commit" 2>/dev/null | grep -E '^v[0-9]' | head -1)
        if [ -n "$tag" ]; then
            echo "$tag $commit"
        fi
    done
}

# Find which release tag a file change belongs to
# Returns the earliest tag whose commit includes the change
find_tag_for_file() {
    local file_path="$1"
    local sync_ref="$2"
    local upstream_ref="${3:-upstream/main}"

    # Walk commits that touched this file, find the earliest tagged one
    local commits
    commits=$(git -C "$REPO_ROOT" log --format='%H' "$sync_ref..$upstream_ref" -- "$file_path" 2>/dev/null)

    for commit in $commits; do
        local tag
        tag=$(git -C "$REPO_ROOT" tag --points-at "$commit" 2>/dev/null | grep -E '^v[0-9]' | head -1)
        if [ -n "$tag" ]; then
            echo "$tag"
            return
        fi
    done

    # Check if any tag in range contains commits that touched this file
    local range_tags
    range_tags=$(list_tags_in_range "$sync_ref" "$upstream_ref")
    if [ -n "$range_tags" ]; then
        echo "$range_tags" | while read -r tag commit; do
            if git -C "$REPO_ROOT" diff --name-only "$sync_ref..$commit" 2>/dev/null | grep -qF "$file_path"; then
                echo "$tag"
                return
            fi
        done | head -1
    fi

    echo ""
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
        .logic-loom/memory/*)      echo "governance" ;;
        .logic-loom/scripts/*)     echo "script" ;;
        .logic-loom/config/*)      echo "config" ;;
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

        # Find which release tag this change belongs to
        local release_tag
        release_tag=$(find_tag_for_file "$file_path" "$sync_ref" "$upstream_ref")

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

        local tag_json="null"
        [ -n "$release_tag" ] && tag_json="\"$release_tag\""

        proposals="${proposals}
    {
      \"id\": \"$padded_id\",
      \"type\": \"$ptype\",
      \"category\": \"$category\",
      \"description\": \"$description\",
      \"upstream_file\": \"$file_path\",
      \"downstream_exists\": $downstream_exists,
      \"change_type\": \"$change_type\",
      \"release_tag\": $tag_json,
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

                    # Show release tags in range
                    TAGS_IN_RANGE=$(list_tags_in_range "$SYNC_REF" "upstream/main")
                    if [ -n "$TAGS_IN_RANGE" ]; then
                        TAG_COUNT=$(echo "$TAGS_IN_RANGE" | wc -l | xargs)
                        echo "Releases in range: $TAG_COUNT"
                        echo "$TAGS_IN_RANGE" | while read -r tag commit; do
                            TAG_DATE=$(git -C "$REPO_ROOT" log -1 --format='%ci' "$commit" 2>/dev/null | cut -d' ' -f1)
                            echo "  $tag ($TAG_DATE)"
                        done
                    else
                        echo "Releases in range: none (untagged changes)"
                    fi
                fi
            else
                echo "No upstream remote configured."
                echo "  git remote add upstream https://github.com/kelleysd-apps/logic-loom.git"
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
