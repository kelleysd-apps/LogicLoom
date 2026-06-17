#!/usr/bin/env bash
# Cleanup Governance Audit Logs
# Removes old audit logs while preserving recent sessions
# Constitutional Principle IV: Idempotent Operations
# Version: 1.0.0

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AUDIT_DIR="$REPO_ROOT/.docs/governance/audit"
CLEANUP_LOG="$AUDIT_DIR/cleanup.log"

# Default values
DRY_RUN=true
DAYS_TO_KEEP=30
SESSIONS_TO_KEEP=10
FORCE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# Functions
# ============================================

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Cleanup old governance audit logs while preserving recent sessions.

OPTIONS:
    --force             Actually delete files (default: dry-run)
    --days N            Keep logs from last N days (default: 30)
    --sessions N        Keep at least N most recent sessions (default: 10)
    --help              Show this help message

EXAMPLES:
    # Dry-run (shows what would be deleted)
    $0

    # Delete logs older than 30 days
    $0 --force

    # Keep last 60 days
    $0 --force --days 60

    # Keep only last 5 sessions
    $0 --force --sessions 5

Constitutional Compliance:
    ✅ Principle IV: Idempotent (safe to run multiple times)
    ✅ Principle VII: Observability (logs cleanup actions)
    ✅ Principle VI: No git operations

EOF
    exit 0
}

log_action() {
    local message="$1"
    local timestamp=$(date -Iseconds 2>/dev/null || date "+%Y-%m-%dT%H:%M:%S")

    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $message"

    # Log to cleanup log file
    if [ -d "$AUDIT_DIR" ]; then
        echo "[$timestamp] $message" >> "$CLEANUP_LOG"
    fi
}

# ============================================
# Argument Parsing
# ============================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            DRY_RUN=false
            shift
            ;;
        --days)
            DAYS_TO_KEEP="$2"
            shift 2
            ;;
        --sessions)
            SESSIONS_TO_KEEP="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# ============================================
# Main Logic
# ============================================

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Governance Audit Log Cleanup${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "Audit Directory: $AUDIT_DIR"
echo "Mode: $([ "$DRY_RUN" = true ] && echo "DRY-RUN (no deletions)" || echo "FORCE (will delete)")"
echo "Keep logs from last: $DAYS_TO_KEEP days"
echo "Keep at least: $SESSIONS_TO_KEEP most recent sessions"
echo ""

# Check if audit directory exists
if [ ! -d "$AUDIT_DIR" ]; then
    echo -e "${YELLOW}⚠${NC}  Audit directory does not exist: $AUDIT_DIR"
    echo "Nothing to clean up."
    exit 0
fi

# Calculate cutoff date (N days ago)
if date --version >/dev/null 2>&1; then
    # GNU date
    CUTOFF_DATE=$(date -d "$DAYS_TO_KEEP days ago" +%Y-%m-%d)
else
    # BSD date (macOS)
    CUTOFF_DATE=$(date -v-${DAYS_TO_KEEP}d +%Y-%m-%d)
fi

log_action "Cutoff date: $CUTOFF_DATE (anything older will be deleted)"
echo ""

# Find all date directories
DATE_DIRS=$(find "$AUDIT_DIR" -maxdepth 1 -type d -name "20*-*-*" 2>/dev/null | sort || echo "")

if [ -z "$DATE_DIRS" ]; then
    echo -e "${YELLOW}⚠${NC}  No audit log directories found"
    exit 0
fi

TOTAL_DIRS=0
OLD_DIRS=0
DELETED_DIRS=0
PRESERVED_DIRS=0

# Count total session files across all directories
TOTAL_SESSIONS=$(find "$AUDIT_DIR" -type f -name "session-*.json" 2>/dev/null | wc -l || echo 0)
RECENT_SESSIONS=0

echo -e "${BLUE}Analyzing audit logs...${NC}"
echo ""

# First pass: identify recent sessions to preserve
RECENT_SESSION_FILES=$(find "$AUDIT_DIR" -type f -name "session-*.json" 2>/dev/null | xargs ls -t | head -n $SESSIONS_TO_KEEP || echo "")

# Second pass: process directories
for dir in $DATE_DIRS; do
    ((TOTAL_DIRS++))

    dir_date=$(basename "$dir")

    # Check if directory is older than cutoff
    if [[ "$dir_date" < "$CUTOFF_DATE" ]]; then
        ((OLD_DIRS++))

        # Check if any session files in this directory are in the "keep" list
        has_recent_sessions=false
        for session_file in "$dir"/session-*.json; do
            [ -f "$session_file" ] || continue

            if echo "$RECENT_SESSION_FILES" | grep -q "$(basename "$session_file")"; then
                has_recent_sessions=true
                break
            fi
        done

        if [ "$has_recent_sessions" = true ]; then
            echo -e "${GREEN}✅ PRESERVE${NC}: $dir_date (contains recent sessions)"
            ((PRESERVED_DIRS++))
        else
            session_count=$(find "$dir" -type f -name "session-*.json" 2>/dev/null | wc -l || echo 0)

            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}🗑️  WOULD DELETE${NC}: $dir_date ($session_count sessions)"
            else
                echo -e "${RED}🗑️  DELETING${NC}: $dir_date ($session_count sessions)"
                rm -rf "$dir"
                ((DELETED_DIRS++))
                log_action "Deleted directory: $dir_date ($session_count sessions)"
            fi
        fi
    else
        echo -e "${GREEN}✅ KEEP${NC}: $dir_date (within $DAYS_TO_KEEP day window)"
    fi
done

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Cleanup Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "Total date directories: $TOTAL_DIRS"
echo "Old directories (>$DAYS_TO_KEEP days): $OLD_DIRS"
echo "Preserved (recent sessions): $PRESERVED_DIRS"

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}Would delete: $((OLD_DIRS - PRESERVED_DIRS)) directories${NC}"
    echo ""
    echo -e "${YELLOW}⚠${NC}  This was a DRY-RUN. No files were deleted."
    echo "Run with --force to actually delete files."
else
    echo -e "${RED}Deleted: $DELETED_DIRS directories${NC}"
    echo ""
    log_action "Cleanup complete: deleted $DELETED_DIRS directories"
fi

echo ""
echo -e "${GREEN}✅ Cleanup complete${NC}"
echo ""

# Idempotency check
if [ "$DRY_RUN" = false ]; then
    echo "You can safely run this command again - it is idempotent."
fi

exit 0
