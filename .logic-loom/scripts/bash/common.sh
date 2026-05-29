#!/usr/bin/env bash
# (Moved to scripts/bash/) Common functions and variables for all scripts
# Constitutional Principle VII: Observability - Structured logging integrated

# ==============================================================================
# Load Structured Logging Library
# ==============================================================================

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"

# Source logging library if available
if [[ -f "$REPO_ROOT/.logic-loom/lib/logging.sh" ]]; then
    source "$REPO_ROOT/.logic-loom/lib/logging.sh"
    LOGGING_ENABLED=true
else
    # Fallback: Define no-op logging functions if library not found
    LOGGING_ENABLED=false
    log_info() { echo "[INFO] $1" >&2; }
    log_warn() { echo "[WARN] $1" >&2; }
    log_error() { echo "[ERROR] $1" >&2; }
    log_debug() { [[ "${CLAUDE_LOG_LEVEL:-INFO}" == "DEBUG" ]] && echo "[DEBUG] $1" >&2; }
    log_operation_start() { echo "$1" >&2; echo "op-$(date +%s)"; }
    log_operation_end() { echo "[DONE] $2 ($3)" >&2; }
fi

# ==============================================================================
# Core Repository Functions
# ==============================================================================

get_repo_root() {
    git rev-parse --show-toplevel
}

get_current_branch() {
    git rev-parse --abbrev-ref HEAD
}

check_feature_branch() {
    local branch="$1"
    if [[ ! "$branch" =~ ^[0-9]{3}- ]]; then
        log_error "Not on a feature branch. Current branch: $branch" "{\"branch\":\"$branch\"}"
        echo "ERROR: Not on a feature branch. Current branch: $branch" >&2
        echo "Feature branches should be named like: 001-feature-name" >&2
        return 1
    fi
    log_debug "Feature branch validated: $branch" "{\"branch\":\"$branch\"}"
    return 0
}

get_feature_dir() {
    echo "$1/specs/$2"
}

get_feature_paths() {
    local repo_root=$(get_repo_root)
    local current_branch=$(get_current_branch)
    local feature_dir=$(get_feature_dir "$repo_root" "$current_branch")

    log_debug "Feature paths calculated" "{\"repo_root\":\"$repo_root\",\"branch\":\"$current_branch\",\"feature_dir\":\"$feature_dir\"}"

    cat <<EOF
REPO_ROOT='$repo_root'
CURRENT_BRANCH='$current_branch'
FEATURE_DIR='$feature_dir'
FEATURE_SPEC='$feature_dir/spec.md'
IMPL_PLAN='$feature_dir/plan.md'
TASKS='$feature_dir/tasks.md'
RESEARCH='$feature_dir/research.md'
DATA_MODEL='$feature_dir/data-model.md'
QUICKSTART='$feature_dir/quickstart.md'
CONTRACTS_DIR='$feature_dir/contracts'
EOF
}

check_file() {
    local file="$1"
    local label="$2"
    if [[ -f "$file" ]]; then
        echo "  ✓ $label"
        log_debug "File exists: $label" "{\"path\":\"$file\"}"
    else
        echo "  ✗ $label"
        log_debug "File missing: $label" "{\"path\":\"$file\"}"
    fi
}

check_dir() {
    local dir="$1"
    local label="$2"
    if [[ -d "$dir" && -n $(ls -A "$dir" 2>/dev/null) ]]; then
        echo "  ✓ $label"
        log_debug "Directory exists and not empty: $label" "{\"path\":\"$dir\"}"
    else
        echo "  ✗ $label"
        log_debug "Directory missing or empty: $label" "{\"path\":\"$dir\"}"
    fi
}

# ==============================================================================
# Git Operation Approval Function
# Constitutional Principle VI: NO automatic git operations without explicit user approval
# ==============================================================================

request_git_approval() {
    local operation="$1"
    local details="$2"

    # Log the approval request
    log_info "Git operation approval requested" "{\"operation\":\"$operation\",\"details\":\"$details\"}"

    echo ""
    echo "=========================================="
    echo "Git Operation Approval Required"
    echo "=========================================="
    echo "Operation: $operation"
    echo "Details: $details"
    echo ""
    echo "Constitutional Principle VI requires explicit approval for all git operations."
    echo ""
    read -p "Approve this operation? (y/n): " APPROVAL
    echo ""

    if [[ "$APPROVAL" =~ ^[Yy]$ ]]; then
        echo "✓ Operation approved by user"
        log_info "Git operation approved by user" "{\"operation\":\"$operation\",\"user_approved\":true}"
        return 0
    else
        echo "✗ Operation cancelled by user"
        log_warn "Git operation cancelled by user" "{\"operation\":\"$operation\",\"user_approved\":false}"
        return 1
    fi
}

# ==============================================================================
# T007: Enhanced Git Approval with Diff Preview
# Sprint 2: Git Safety Enhancements
# ==============================================================================

# Get git diff preview summary
get_git_diff_preview() {
    local diff_type="${1:-cached}"  # cached (staged) or HEAD (unstaged)

    if [[ "$diff_type" == "cached" ]]; then
        # Show staged changes
        git diff --cached --stat 2>/dev/null || echo "No staged changes"
    else
        # Show all changes
        git diff --stat 2>/dev/null || echo "No changes"
    fi
}

# Enhanced git approval with diff preview
request_git_approval_enhanced() {
    local operation="$1"
    local details="$2"
    local show_preview="${3:-true}"  # Show diff preview by default

    # Log the approval request
    log_info "Git operation approval requested (enhanced)" "{\"operation\":\"$operation\",\"details\":\"$details\",\"preview\":$show_preview}"

    echo ""
    echo "=========================================="
    echo "Git Operation Approval Required"
    echo "=========================================="
    echo "Operation: $operation"
    echo "Details: $details"
    echo ""

    # Show diff preview if requested
    if [[ "$show_preview" == "true" && "$operation" == *"Commit"* ]]; then
        echo "Changes to be committed:"
        echo "----------------------------------------"
        get_git_diff_preview "cached"
        echo "----------------------------------------"
        echo ""
        read -p "View full diff? (y/n): " VIEW_DIFF
        if [[ "$VIEW_DIFF" =~ ^[Yy]$ ]]; then
            echo ""
            git diff --cached
            echo ""
        fi
    fi

    echo "Constitutional Principle VI requires explicit approval for all git operations."
    echo ""
    read -p "Approve this operation? (y/n): " APPROVAL
    echo ""

    if [[ "$APPROVAL" =~ ^[Yy]$ ]]; then
        echo "✓ Operation approved by user"
        log_info "Git operation approved by user" "{\"operation\":\"$operation\",\"user_approved\":true}"
        return 0
    else
        echo "✗ Operation cancelled by user"
        log_warn "Git operation cancelled by user" "{\"operation\":\"$operation\",\"user_approved\":false}"
        return 1
    fi
}

# ==============================================================================
# T008: Git Checkpoint System
# Sprint 2: Git Safety Enhancements
# ==============================================================================

# Create git checkpoint
create_git_checkpoint() {
    local operation="$1"
    local details="${2:-}"

    # Get current state
    local commit_sha=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local checkpoint_id=$(date +%s)

    # Checkpoint file
    local checkpoint_dir="$REPO_ROOT/.logic-loom/logs/git-checkpoints"
    local checkpoint_file="$checkpoint_dir/$(date +%Y-%m-%d).json"

    # Ensure directory exists
    mkdir -p "$checkpoint_dir"

    # Create checkpoint entry
    local checkpoint_entry=$(cat <<EOF
{
  "checkpoint_id": "$checkpoint_id",
  "timestamp": "$timestamp",
  "operation": "$operation",
  "details": "$details",
  "commit_sha": "$commit_sha",
  "branch": "$branch"
}
EOF
)

    # Append to daily checkpoint file (JSON lines format)
    echo "$checkpoint_entry" >> "$checkpoint_file"

    # Log checkpoint creation
    log_info "Git checkpoint created" "{\"checkpoint_id\":\"$checkpoint_id\",\"operation\":\"$operation\",\"commit\":\"$commit_sha\",\"branch\":\"$branch\"}"

    echo "✓ Checkpoint created: $checkpoint_id"
    echo "  Commit: $commit_sha"
    echo "  Branch: $branch"
    echo "  Operation: $operation"

    echo "$checkpoint_id"
}

# List git checkpoints
list_git_checkpoints() {
    local days="${1:-7}"  # Show last 7 days by default

    local checkpoint_dir="$REPO_ROOT/.logic-loom/logs/git-checkpoints"

    if [[ ! -d "$checkpoint_dir" ]]; then
        echo "No checkpoints found"
        return 0
    fi

    echo "Git Checkpoints (last $days days):"
    echo "========================================"

    # Find checkpoint files from last N days
    find "$checkpoint_dir" -name "*.json" -type f -mtime -"$days" | sort -r | while read -r file; do
        echo ""
        echo "File: $(basename "$file")"
        echo "----------------------------------------"

        # Parse and display each checkpoint entry
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local checkpoint_id=$(echo "$line" | jq -r '.checkpoint_id // "unknown"')
                local timestamp=$(echo "$line" | jq -r '.timestamp // "unknown"')
                local operation=$(echo "$line" | jq -r '.operation // "unknown"')
                local commit=$(echo "$line" | jq -r '.commit_sha // "unknown"' | cut -c1-8)
                local branch=$(echo "$line" | jq -r '.branch // "unknown"')

                echo "  [$checkpoint_id] $timestamp"
                echo "    Operation: $operation"
                echo "    Commit: $commit"
                echo "    Branch: $branch"
                echo ""
            fi
        done < "$file"
    done

    echo "========================================"
}

# Restore from git checkpoint
restore_git_checkpoint() {
    local checkpoint_id="$1"

    if [[ -z "$checkpoint_id" ]]; then
        echo "ERROR: Checkpoint ID required"
        echo "Usage: restore_git_checkpoint <checkpoint_id>"
        return 1
    fi

    # Find checkpoint entry
    local checkpoint_dir="$REPO_ROOT/.logic-loom/logs/git-checkpoints"
    local checkpoint_entry=""

    # Search through checkpoint files
    for file in "$checkpoint_dir"/*.json; do
        if [[ -f "$file" ]]; then
            checkpoint_entry=$(grep -F "\"checkpoint_id\": \"$checkpoint_id\"" "$file" | head -1 || echo "")
            if [[ -n "$checkpoint_entry" ]]; then
                break
            fi
        fi
    done

    if [[ -z "$checkpoint_entry" ]]; then
        echo "ERROR: Checkpoint $checkpoint_id not found"
        return 1
    fi

    # Extract checkpoint details
    local commit_sha=$(echo "$checkpoint_entry" | jq -r '.commit_sha')
    local branch=$(echo "$checkpoint_entry" | jq -r '.branch')
    local operation=$(echo "$checkpoint_entry" | jq -r '.operation')

    echo "Found checkpoint:"
    echo "  ID: $checkpoint_id"
    echo "  Commit: $commit_sha"
    echo "  Branch: $branch"
    echo "  Operation: $operation"
    echo ""

    # Request approval for restore
    if ! request_git_approval "Restore Checkpoint" "Restore to commit $commit_sha on branch $branch"; then
        return 1
    fi

    # Restore the checkpoint
    echo "Restoring checkpoint..."

    # Checkout the branch
    git checkout "$branch" 2>/dev/null || {
        echo "ERROR: Failed to checkout branch $branch"
        return 1
    }

    # Reset to the checkpoint commit
    git reset --hard "$commit_sha" || {
        echo "ERROR: Failed to reset to commit $commit_sha"
        return 1
    }

    echo "✓ Checkpoint restored successfully"
    log_info "Git checkpoint restored" "{\"checkpoint_id\":\"$checkpoint_id\",\"commit\":\"$commit_sha\",\"branch\":\"$branch\"}"

    return 0
}

# Cleanup old checkpoints (older than 30 days)
cleanup_old_checkpoints() {
    local days="${1:-30}"

    local checkpoint_dir="$REPO_ROOT/.logic-loom/logs/git-checkpoints"

    if [[ ! -d "$checkpoint_dir" ]]; then
        echo "No checkpoints to clean up"
        return 0
    fi

    echo "Cleaning up checkpoints older than $days days..."

    # Find and remove old checkpoint files (use temp file to avoid subshell counter bug)
    local deleted_count=0
    local old_files
    old_files=$(find "$checkpoint_dir" -name "*.json" -type f -mtime +"$days" -print 2>/dev/null || echo "")

    if [[ -n "$old_files" ]]; then
        while IFS= read -r file; do
            rm -f "$file"
            deleted_count=$((deleted_count + 1))
            echo "  Removed: $(basename "$file")"
        done <<< "$old_files"
    fi

    if [[ $deleted_count -eq 0 ]]; then
        echo "✓ No old checkpoints to remove"
    else
        echo "✓ Cleaned up $deleted_count checkpoint file(s)"
    fi

    log_info "Git checkpoints cleaned up" "{\"days\":$days,\"count\":$deleted_count}"

    return 0
}

# ==============================================================================
# T009: Commit Message Suggestions
# Sprint 2: Git Safety Enhancements
# ==============================================================================

# Parse conventional commit type from staged changes
parse_conventional_commit_type() {
    # Analyze staged files to determine commit type
    local changes=$(git diff --cached --name-status 2>/dev/null)

    if [[ -z "$changes" ]]; then
        echo "chore"
        return 0
    fi

    # Count different types of changes
    local new_files=$(echo "$changes" | grep -c "^A" || echo 0)
    local modified_files=$(echo "$changes" | grep -c "^M" || echo 0)
    local deleted_files=$(echo "$changes" | grep -c "^D" || echo 0)

    # Check file patterns
    local has_tests=$(echo "$changes" | grep -c "test\|spec" || echo 0)
    local has_docs=$(echo "$changes" | grep -c "\.md$\|README\|docs/" || echo 0)
    local has_config=$(echo "$changes" | grep -c "package\.json\|\.config\|\.rc$" || echo 0)

    # Determine commit type based on patterns
    if [[ $has_tests -gt 0 && $new_files -gt 0 ]]; then
        echo "test"
    elif [[ $has_docs -gt 0 ]]; then
        echo "docs"
    elif [[ $new_files -gt $modified_files ]]; then
        echo "feat"
    elif [[ $deleted_files -gt 0 ]]; then
        echo "refactor"
    elif [[ $has_config -gt 0 ]]; then
        echo "chore"
    else
        echo "fix"
    fi
}

# Suggest commit messages based on staged changes
suggest_commit_message() {
    # Get staged changes summary
    local stat=$(git diff --cached --stat 2>/dev/null | tail -1)

    if [[ -z "$stat" ]]; then
        echo "No staged changes to commit"
        return 1
    fi

    # Parse file count and line changes
    local file_count=$(echo "$stat" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo 0)
    local insertions=$(echo "$stat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
    local deletions=$(echo "$stat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)

    # Get changed files
    local changed_files=$(git diff --cached --name-only 2>/dev/null | head -5)

    # Determine conventional commit type
    local commit_type=$(parse_conventional_commit_type)

    echo "Commit Message Suggestions:"
    echo "========================================"
    echo "Changes: $file_count file(s), +$insertions, -$deletions"
    echo ""
    echo "Suggested messages:"
    echo ""

    # Generate 2-3 suggestions based on commit type
    case "$commit_type" in
        feat)
            echo "1. feat: Add new functionality to $(echo "$changed_files" | head -1 | xargs basename | cut -d. -f1)"
            echo "2. feat: Implement $(echo "$changed_files" | wc -l) new features"
            echo "3. feat: Add $(echo "$changed_files" | head -1 | xargs basename)"
            ;;
        fix)
            echo "1. fix: Resolve issue in $(echo "$changed_files" | head -1 | xargs basename | cut -d. -f1)"
            echo "2. fix: Update $(echo "$changed_files" | wc -l) files to fix bug"
            echo "3. fix: Correct behavior in $(echo "$changed_files" | head -1 | xargs basename)"
            ;;
        docs)
            echo "1. docs: Update documentation for $(echo "$changed_files" | head -1 | xargs basename | cut -d. -f1)"
            echo "2. docs: Improve $(echo "$changed_files" | wc -l) documentation file(s)"
            echo "3. docs: Update README and guides"
            ;;
        test)
            echo "1. test: Add tests for $(echo "$changed_files" | head -1 | xargs basename | cut -d. -f1)"
            echo "2. test: Expand test coverage (+$insertions lines)"
            echo "3. test: Add $(echo "$changed_files" | wc -l) test file(s)"
            ;;
        refactor)
            echo "1. refactor: Restructure $(echo "$changed_files" | head -1 | xargs basename | cut -d. -f1)"
            echo "2. refactor: Simplify code ($deletions lines removed)"
            echo "3. refactor: Improve $(echo "$changed_files" | wc -l) files"
            ;;
        chore)
            echo "1. chore: Update configuration and dependencies"
            echo "2. chore: Maintain $(echo "$changed_files" | wc -l) files"
            echo "3. chore: Update build and tooling"
            ;;
        *)
            echo "1. chore: Update $(echo "$changed_files" | head -1 | xargs basename)"
            echo "2. Update $file_count file(s) with $insertions insertions"
            ;;
    esac

    echo ""
    echo "========================================"
    echo "Changed files:"
    echo "$changed_files"
    echo "========================================"

    log_info "Commit message suggestions generated" "{\"type\":\"$commit_type\",\"files\":$file_count,\"insertions\":$insertions,\"deletions\":$deletions}"
}

# ==============================================================================
# Skill-Brief Extraction (Spec 006 - Agent Simplification)
# ==============================================================================

# Extract the Task Brief section from a plugin's SKILL.md file.
# Used to inject domain skill knowledge into Task tool prompts
# when spawning team workers (replacing custom agent definitions).
#
# Args: $1=plugin_name (e.g. "sdd-domain-backend")
#       $2=skill_name (e.g. "backend-operations")
# Output: Brief text from the ## Task Brief section, or empty string if missing
# Returns: 0 always (graceful degradation)
extract_skill_brief() {
    local plugin_name="${1:-}"
    local skill_name="${2:-}"

    if [ -z "$plugin_name" ] || [ -z "$skill_name" ]; then
        return 0
    fi

    local skill_file="$REPO_ROOT/plugins/$plugin_name/skills/$skill_name/SKILL.md"

    if [ ! -f "$skill_file" ]; then
        return 0
    fi

    # Extract content between "## Task Brief" and the next ## heading (or EOF)
    local in_brief=false
    local brief=""

    while IFS= read -r line; do
        if echo "$line" | grep -q '^## Task Brief'; then
            in_brief=true
            continue
        fi

        if [ "$in_brief" = true ]; then
            # Stop at next ## heading
            if echo "$line" | grep -q '^## '; then
                break
            fi
            brief="${brief}${line}
"
        fi
    done < "$skill_file"

    # Trim leading/trailing blank lines (macOS compatible)
    brief=$(echo "$brief" | sed '/^[[:space:]]*$/d')

    echo "$brief"
}

# Return the consolidated worker brief for a technical domain from the
# governance-core domain-brief registry (replaces the former sdd-domain-* plugins).
#
# Args:    $1=domain (e.g. "backend", "frontend")
# Output:  Task Brief text for injection into a swarm/team worker prompt, or empty
# Returns: 0 always (graceful degradation)
get_domain_brief() {
    local domain="${1:-}"
    [ -n "$domain" ] || return 0

    # Resolve the governance core plugin dir (loom-governance after rename;
    # loom-governance before). First match wins.
    local gov_dir
    for gov_dir in loom-governance loom-governance; do
        local brief_file="$REPO_ROOT/plugins/$gov_dir/domain-briefs/${domain}.md"
        if [ -f "$brief_file" ]; then
            # Emit content from the "## Task Brief" heading to EOF (skip the header).
            awk '/^## Task Brief/{f=1;next} f' "$brief_file"
            return 0
        fi
    done
    return 0
}

# ==============================================================================
# Logging Status
# ==============================================================================

if [[ "$LOGGING_ENABLED" == "true" ]]; then
    log_debug "common.sh loaded with structured logging enabled" "{\"log_level\":\"${CLAUDE_LOG_LEVEL:-INFO}\"}"
else
    echo "[WARN] Structured logging library not found, using fallback logging" >&2
fi
