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
    # Check if agent is within budget; recommend fallback model if near limit
    AGENT_ID="${3:-}"
    SPENT="${4:-0}"
    LIMIT="${5:-0}"
    FALLBACK_MODEL="${FALLBACK_MODEL:-claude-sonnet-4-5-20250929}"
    FALLBACK_THRESHOLD="${FALLBACK_THRESHOLD:-0.80}"  # Switch at 80% budget
    
    if python3 -c "exit(0 if $SPENT < $LIMIT else 1)"; then
      # Check if nearing budget — recommend fallback model to reduce cost
      near_limit=$(python3 -c "print('yes' if ($SPENT / max($LIMIT, 0.01)) >= $FALLBACK_THRESHOLD else 'no')")
      remaining=$(python3 -c "print(round($LIMIT - $SPENT, 2))")
      if [ "$near_limit" = "yes" ]; then
        echo "{\"status\":\"warning\",\"remaining\":$remaining,\"recommendation\":\"switch_to_fallback\",\"fallback_model\":\"$FALLBACK_MODEL\"}"
      else
        echo "{\"status\":\"ok\",\"remaining\":$remaining}"
      fi
    else
      echo "{\"status\":\"exceeded\",\"overage\":$(python3 -c "print(round($SPENT - $LIMIT, 2))"),\"action\":\"terminate_or_fallback\",\"fallback_model\":\"$FALLBACK_MODEL\"}"
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
