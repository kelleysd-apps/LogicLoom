#!/usr/bin/env bash
# Agent Stop Notification — Notify swarm coordinator when an agent completes
set -euo pipefail

INPUT=$(cat)
AGENT_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('agent_name','unknown'))" 2>/dev/null || echo "unknown")

# Read state file if it exists
STATE_FILE=".claude/multi-agent-swarm.local.md"
if [ -f "$STATE_FILE" ]; then
  COORDINATOR=$(python3 -c "
import re
with open('$STATE_FILE') as f:
    content = f.read()
m = re.search(r'coordinator_session:\s*(.+)', content)
print(m.group(1).strip() if m else 'unknown')
  " 2>/dev/null || echo "unknown")
  
  # Notify coordinator via tmux if session exists
  if tmux has-session -t "$COORDINATOR" 2>/dev/null; then
    tmux send-keys -t "$COORDINATOR" "echo 'Agent ${AGENT_NAME} completed'" Enter
  fi
fi

echo '{"result":"allow"}'
