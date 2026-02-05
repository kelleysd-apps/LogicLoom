#!/usr/bin/env bash
#
# RL Feedback Collection Script
# Updates skill metrics based on execution results
#
# Usage: collect-feedback.sh <skill-name> <success|failure> [tokens]
#
# Part of DS-STAR RL Integration (FR-701, FR-708)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
METRICS_FILE="$REPO_ROOT/.docs/rl-metrics/skill-performance.json"
SKILL_INDEX="$REPO_ROOT/.claude/skill-index.json"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <skill-name> <success|failure> [tokens]"
    echo ""
    echo "Arguments:"
    echo "  skill-name   Name of the skill (e.g., 'api-design', 'git-push-workflow')"
    echo "  result       'success' or 'failure'"
    echo "  tokens       Optional: number of tokens used"
    echo ""
    echo "Example:"
    echo "  $0 api-design success 1500"
    exit 1
}

# Validate arguments
if [ $# -lt 2 ]; then
    usage
fi

SKILL_NAME="$1"
RESULT="$2"
TOKENS="${3:-0}"

# Validate result
if [[ "$RESULT" != "success" && "$RESULT" != "failure" ]]; then
    echo -e "${RED}Error: Result must be 'success' or 'failure'${NC}"
    exit 1
fi

# Check if metrics file exists
if [ ! -f "$METRICS_FILE" ]; then
    echo -e "${RED}Error: Metrics file not found at $METRICS_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}📊 Collecting RL Feedback${NC}"
echo "   Skill: $SKILL_NAME"
echo "   Result: $RESULT"
echo "   Tokens: $TOKENS"

# Update metrics using Python (for JSON manipulation)
python3 << PYTHON_EOF
import json
from datetime import datetime

LEARNING_RATE = 0.1
MIN_WEIGHT = 0.1
MAX_WEIGHT = 1.0

# Load metrics file
with open('$METRICS_FILE', 'r') as f:
    metrics = json.load(f)

skill_name = '$SKILL_NAME'
success = '$RESULT' == 'success'
tokens = int('$TOKENS')

# Initialize skill entry if not exists
if skill_name not in metrics['skills']:
    metrics['skills'][skill_name] = {
        'success_rate': 0.5,
        'selection_weight': 0.5,
        'invocation_count': 0,
        'avg_tokens': 0,
        'last_feedback': None,
        'history': []
    }

skill = metrics['skills'][skill_name]

# Apply EMA update
old_rate = skill['success_rate']
new_rate = (1 - LEARNING_RATE) * old_rate + LEARNING_RATE * (1.0 if success else 0.0)

old_tokens = skill['avg_tokens']
new_tokens = (1 - LEARNING_RATE) * old_tokens + LEARNING_RATE * tokens if tokens > 0 else old_tokens

# Update selection weight based on success rate
new_weight = max(MIN_WEIGHT, min(MAX_WEIGHT, new_rate))

# Update skill metrics
skill['success_rate'] = round(new_rate, 4)
skill['selection_weight'] = round(new_weight, 4)
skill['invocation_count'] += 1
skill['avg_tokens'] = round(new_tokens, 2)
skill['last_feedback'] = datetime.now(datetime.UTC).isoformat() + 'Z'

# Add to history
skill['history'].append({
    'timestamp': skill['last_feedback'],
    'success': success,
    'tokens': tokens,
    'rate_before': round(old_rate, 4),
    'rate_after': round(new_rate, 4)
})

# Keep only last 100 history entries
skill['history'] = skill['history'][-100:]

# Update aggregates
metrics['aggregates']['total_invocations'] += 1
if success:
    metrics['aggregates']['total_successes'] += 1
else:
    metrics['aggregates']['total_failures'] += 1

total = metrics['aggregates']['total_invocations']
successes = metrics['aggregates']['total_successes']
metrics['aggregates']['average_success_rate'] = round(successes / total, 4) if total > 0 else 0.5

# Update last_updated
metrics['last_updated'] = datetime.now(datetime.UTC).isoformat() + 'Z'

# Save metrics file
with open('$METRICS_FILE', 'w') as f:
    json.dump(metrics, f, indent=2)

print(f"\n✅ Metrics updated for {skill_name}")
print(f"   Success rate: {old_rate:.2%} → {new_rate:.2%}")
print(f"   Selection weight: {new_weight:.4f}")
print(f"   Total invocations: {skill['invocation_count']}")
PYTHON_EOF

echo ""
echo -e "${GREEN}✅ RL feedback collected successfully${NC}"
