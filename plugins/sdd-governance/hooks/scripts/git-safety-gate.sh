#!/usr/bin/env bash
# Git Safety Gate — Principle VI enforcement via PreToolUse hook
# Checks if a Bash command contains git operations and blocks without approval
set -euo pipefail

# Read the tool input from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null || echo "")

# Git operation patterns that require approval
GIT_PATTERNS="^git (push|pull|commit|merge|rebase|checkout|branch -[dD]|reset|tag|stash|cherry-pick|revert|am|format-patch)"

if echo "$COMMAND" | grep -qE "$GIT_PATTERNS"; then
  # Output warning but don't block — governance agent handles actual gating
  echo '{"result":"warn","message":"⚠️ Git operation detected. Principle VI requires explicit user approval."}' 
else
  echo '{"result":"allow"}'
fi
