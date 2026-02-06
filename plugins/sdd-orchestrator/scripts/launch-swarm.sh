#!/usr/bin/env bash
# Launch Swarm — Spawn coordinated agents in tmux sessions
set -euo pipefail

SWARM_ID="${1:-swarm-$(date +%s)}"
TASK_DESC="${2:-}"
BUDGET="${3:-10.00}"
MODEL="${4:-opus}"
FALLBACK="${5:-sonnet}"

if [ -z "$TASK_DESC" ]; then
  echo "Usage: launch-swarm.sh <swarm-id> <task-description> [budget] [model] [fallback]"
  exit 1
fi

echo "🚀 Launching swarm: ${SWARM_ID}"
echo "   Task: ${TASK_DESC}"
echo "   Budget: \$${BUDGET}"
echo "   Model: ${MODEL} (fallback: ${FALLBACK})"

# Create swarm session
tmux new-session -d -s "${SWARM_ID}-coordinator" 2>/dev/null || true

echo "✅ Swarm coordinator session created: ${SWARM_ID}-coordinator"
echo "   Agents will be spawned as tasks are ready"
