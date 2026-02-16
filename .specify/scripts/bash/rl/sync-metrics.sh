#!/usr/bin/env bash
#
# RL Metrics Sync Script
# Synchronizes skill-performance.json metrics back to skill-index.json
#
# Usage: sync-metrics.sh [--dry-run]
#
# Part of DS-STAR RL Integration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
METRICS_FILE="$REPO_ROOT/.docs/rl-metrics/skill-performance.json"
# Note: Plugin manifests at plugins/*/plugin.json are the authoritative source for RL metrics
SKILL_INDEX="$REPO_ROOT/.claude/skill-index.json"

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
fi

echo "📊 RL Metrics Sync"
echo "   Source: $METRICS_FILE"
echo "   Target: $SKILL_INDEX"
echo "   Dry run: $DRY_RUN"
echo ""

python3 << PYTHON_EOF
import json
from datetime import datetime

DRY_RUN = $( [ "$DRY_RUN" = "true" ] && echo "True" || echo "False" )

# Load both files
with open('$METRICS_FILE', 'r') as f:
    perf_metrics = json.load(f)

with open('$SKILL_INDEX', 'r') as f:
    skill_index = json.load(f)

updated_count = 0

# Update each skill in skill-index.json
for skill in skill_index.get('skills', []):
    skill_name = skill.get('name')
    if skill_name and skill_name in perf_metrics.get('skills', {}):
        perf = perf_metrics['skills'][skill_name]
        
        # Update rl_metrics in skill-index
        if 'rl_metrics' not in skill:
            skill['rl_metrics'] = {}
        
        old_weight = skill['rl_metrics'].get('selection_weight', 0.5)
        
        skill['rl_metrics']['success_rate'] = perf.get('success_rate', 0.5)
        skill['rl_metrics']['selection_weight'] = perf.get('selection_weight', 0.5)
        skill['rl_metrics']['invocation_count'] = perf.get('invocation_count', 0)
        skill['rl_metrics']['avg_tokens'] = perf.get('avg_tokens', 0)
        skill['rl_metrics']['last_updated'] = datetime.utcnow().isoformat() + 'Z'
        
        new_weight = skill['rl_metrics']['selection_weight']
        
        if old_weight != new_weight:
            print(f"  ✓ {skill_name}: weight {old_weight:.4f} → {new_weight:.4f}")
            updated_count += 1

# Update statistics
if updated_count > 0:
    skill_index['statistics']['rl_statistics'] = {
        'avg_selection_weight': perf_metrics['aggregates'].get('average_success_rate', 0.5),
        'total_invocations': perf_metrics['aggregates'].get('total_invocations', 0),
        'avg_success_rate': perf_metrics['aggregates'].get('average_success_rate', 0.5),
        'last_sync': datetime.utcnow().isoformat() + 'Z'
    }

print(f"\n  Skills updated: {updated_count}")

if not DRY_RUN and updated_count > 0:
    with open('$SKILL_INDEX', 'w') as f:
        json.dump(skill_index, f, indent=2)
    print("  ✅ skill-index.json updated")
else:
    print("  ℹ️  No changes written (dry run or no updates)")
PYTHON_EOF

echo ""
echo "✅ Sync complete"
