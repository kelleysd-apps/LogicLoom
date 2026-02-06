#!/usr/bin/env bash
# RL Metrics Capture — PostToolUse hook for per-plugin metrics tracking
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
METRICS_FILE="$PLUGIN_ROOT/.claude-plugin/plugin.json"

# Read tool result from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")
SUCCESS=$(echo "$INPUT" | python3 -c "import sys,json; r=json.load(sys.stdin); print('true' if r.get('error') is None else 'false')" 2>/dev/null || echo "true")

# Update RL metrics in plugin.json if it exists
if [ -f "$METRICS_FILE" ]; then
  python3 -c "
import json, sys
from datetime import datetime

with open('$METRICS_FILE', 'r') as f:
    data = json.load(f)

metrics = data.get('rl_metrics', {})
lr = 0.1  # EMA learning rate
outcome = 1.0 if '$SUCCESS' == 'true' else 0.0
old_rate = metrics.get('success_rate', 0.5)
metrics['success_rate'] = round(((1 - lr) * old_rate) + (lr * outcome), 4)
metrics['selection_weight'] = round(max(0.1, min(1.0, metrics['success_rate'])), 4)
metrics['invocation_count'] = metrics.get('invocation_count', 0) + 1
metrics['last_updated'] = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
data['rl_metrics'] = metrics

with open('$METRICS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" 2>/dev/null || true
fi

echo '{"result":"allow"}'
