#!/usr/bin/env bash
# Agent Stop Notification — SubagentStop observability hook (Principle VII).
#
# In the native-primitives model the main agent collects each subagent's result
# directly from the Task tool; there is NO external coordinator process and NO
# shared swarm-state file to reconcile. This hook therefore does no orchestration
# — it only records a best-effort observability line that a subagent finished,
# then allows continuation. Fails open on any infra gap (missing python3, no log
# dir, unwritable path) so it can never wedge a run.
set -euo pipefail

INPUT=$(cat 2>/dev/null || true)

AGENT_NAME="unknown"
if command -v python3 >/dev/null 2>&1; then
  AGENT_NAME=$(printf '%s' "$INPUT" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('agent_name') or d.get('agent_type') or 'unknown')" \
    2>/dev/null || echo "unknown")
fi

# Best-effort observability: append a line if the log dir already exists.
# Never create directories, never fail the hook on a write error.
LOG_FILE=".logic-loom/logs/subagent-activity.log"
if [ -d ".logic-loom/logs" ]; then
  printf 'subagent_stop agent=%s\n' "$AGENT_NAME" >>"$LOG_FILE" 2>/dev/null || true
fi

# Non-blocking: let the run continue.
echo '{"result":"allow"}'
