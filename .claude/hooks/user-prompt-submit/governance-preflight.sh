#!/usr/bin/env bash
# UserPromptSubmit Hook: Governance Preflight Check
# Constitutional Principle X enforcement
# Version: 1.1.0
#
# This hook automatically injects constitutional governance context
# on every user message to ensure compliance with all 15 principles.
#
# Input: JSON via stdin (Claude Code hook contract)
# Output: JSON with hookEventName and additionalContext

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SETTINGS_FILE="$REPO_ROOT/.claude/settings.json"
AUDIT_DIR="$REPO_ROOT/.docs/governance/audit"
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%s)-$$}"
TIMESTAMP=$(date -Iseconds 2>/dev/null || date "+%Y-%m-%dT%H:%M:%S%z")
DATE=$(date "+%Y-%m-%d")

# ============================================
# Functions
# ============================================

# Extract agent from settings.json (with or without jq)
get_agent_role() {
    if command -v jq &> /dev/null; then
        jq -r '.agent // "task-orchestrator"' "$SETTINGS_FILE" 2>/dev/null || echo "task-orchestrator"
    else
        # Pure bash fallback
        grep -o '"agent"[[:space:]]*:[[:space:]]*"[^"]*"' "$SETTINGS_FILE" 2>/dev/null | \
            sed 's/.*"\([^"]*\)".*/\1/' || echo "task-orchestrator"
    fi
}

# Create audit log
create_audit_log() {
    local agent_role="$1"
    local input_summary="$2"

    # Create audit directory structure
    mkdir -p "$AUDIT_DIR/$DATE"

    local audit_file="$AUDIT_DIR/$DATE/session-$SESSION_ID.json"

    # Create audit log entry (pure bash JSON generation)
    cat > "$audit_file" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "session_id": "$SESSION_ID",
  "event_type": "context_injection",
  "decision_type": "context_injection",
  "layer": "hook",
  "agent_role": "$agent_role",
  "input_summary": "$input_summary",
  "output": {
    "action": "inject_governance_context",
    "blocked": false
  },
  "constitutional_principles": ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV"],
  "duration_ms": 0
}
EOF
}

# Generate governance context message
generate_governance_context() {
    local agent_role="$1"

    cat <<'EOF'

---

**CONSTITUTIONAL GOVERNANCE REMINDER**

You are operating under the Specification-Driven Development Constitution v1.6.0 with 15 enforceable principles.

**MANDATORY PRE-FLIGHT CHECK (4 Steps):**

1. **CONSTITUTION ACKNOWLEDGMENT**
   - Confirm awareness of all 15 principles (I-XV)
   - Key principles: II (Test-First), VI (Git Approval), X (Agent Delegation)

2. **DOMAIN ANALYSIS**
   - Scan message for domain keywords
   - Identify: frontend, backend, database, testing, security, performance, etc.

3. **DELEGATION DECISION**
   - 0 domains → may execute directly
   - 1 domain → MUST delegate to specialist agent
   - 2+ domains → MUST delegate to task-orchestrator

4. **EXECUTION AUTHORIZATION**
   - Confirm all steps complete
   - Output compliance summary
   - Proceed with action

**CRITICAL PRINCIPLES:**
- **Principle VI (IMMUTABLE)**: NO autonomous git operations without explicit user approval
- **Principle X (CRITICAL)**: Specialized work → specialized agents
- **Principle II (IMMUTABLE)**: TDD mandatory, >80% coverage

**Compliance Summary Format:**
```
Constitutional Compliance Check:
- Domain(s): [none | single: <domain> | multi: <domains>]
- Delegation: [direct execution | <agent-name>]
- Git operations: [none planned | will request approval]
- Proceeding with: [action description]
```

---
EOF
}

# ============================================
# Main Logic
# ============================================

# Read input from stdin
INPUT=$(cat)

# Extract first 100 chars of user message for audit log (if possible)
INPUT_SUMMARY=$(echo "$INPUT" | head -c 100 | tr -d '\n\r')

# Get agent role from settings
AGENT_ROLE=$(get_agent_role)

# Create audit log (background, non-blocking)
create_audit_log "$AGENT_ROLE" "$INPUT_SUMMARY" &

# Generate governance context
GOVERNANCE_CONTEXT=$(generate_governance_context "$AGENT_ROLE")

# Output JSON with hookEventName and additionalContext (Claude Code hook contract)
# Using jq for proper JSON escaping, with pure bash fallback
if command -v jq &> /dev/null; then
    ESCAPED_CONTEXT=$(echo "$GOVERNANCE_CONTEXT" | jq -Rs '.')
    cat <<EOF
{
  "blocked": false,
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": $ESCAPED_CONTEXT
  }
}
EOF
else
    # Pure bash fallback - escape for JSON
    ESCAPED_CONTEXT=$(echo "$GOVERNANCE_CONTEXT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')
    cat <<EOF
{
  "blocked": false,
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "$ESCAPED_CONTEXT"
  }
}
EOF
fi

exit 0
