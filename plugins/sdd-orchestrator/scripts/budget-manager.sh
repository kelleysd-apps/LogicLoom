#!/usr/bin/env bash
# Swarm Budget Manager — Allocate and track budgets across swarm agents
set -euo pipefail

COMMAND="${1:-help}"
SWARM_ID="${2:-}"
BUDGET_FILE=".claude/swarm-budgets.json"

case "$COMMAND" in
  allocate)
    # Allocate budget across agents
    TOTAL_BUDGET="${3:-10.00}"
    AGENT_COUNT="${4:-1}"
    STRATEGY="${5:-equal}"  # equal | weighted
    
    if [ "$STRATEGY" = "equal" ]; then
      PER_AGENT=$(python3 -c "print(round($TOTAL_BUDGET / $AGENT_COUNT, 2))")
    fi
    
    echo "{\"swarm_id\":\"$SWARM_ID\",\"total_budget\":$TOTAL_BUDGET,\"per_agent\":$PER_AGENT,\"strategy\":\"$STRATEGY\"}"
    ;;
    
  check)
    # Check if agent is within budget
    AGENT_ID="${3:-}"
    SPENT="${4:-0}"
    LIMIT="${5:-0}"
    
    if python3 -c "exit(0 if $SPENT < $LIMIT else 1)"; then
      echo "{\"status\":\"ok\",\"remaining\":$(python3 -c "print(round($LIMIT - $SPENT, 2))")}"
    else
      echo "{\"status\":\"exceeded\",\"overage\":$(python3 -c "print(round($SPENT - $LIMIT, 2))")}"
    fi
    ;;
    
  report)
    # Generate budget report
    if [ -f "$BUDGET_FILE" ]; then
      python3 -c "
import json
with open('$BUDGET_FILE') as f:
    data = json.load(f)
total = sum(a.get('spent', 0) for a in data.get('agents', []))
print(f'Total spent: \${total:.2f}')
for a in data.get('agents', []):
    print(f'  {a[\"name\"]}: \${a.get(\"spent\", 0):.2f} / \${a.get(\"budget\", 0):.2f}')
"
    else
      echo "No budget data found"
    fi
    ;;
    
  *)
    echo "Usage: budget-manager.sh <allocate|check|report> <swarm-id> [args...]"
    ;;
esac
