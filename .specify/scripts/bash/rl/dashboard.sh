#!/usr/bin/env bash
#
# RL Metrics Dashboard
# Displays current skill performance metrics
#
# Usage: dashboard.sh [--json] [--top N]
#
# Part of DS-STAR RL Integration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
METRICS_FILE="$REPO_ROOT/.docs/rl-metrics/skill-performance.json"

OUTPUT_JSON=false
TOP_N=10

while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        --top)
            TOP_N="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [ "$OUTPUT_JSON" = "true" ]; then
    cat "$METRICS_FILE"
    exit 0
fi

python3 << PYTHON_EOF
import json
from datetime import datetime

TOP_N = $TOP_N

with open('$METRICS_FILE', 'r') as f:
    metrics = json.load(f)

print("╔══════════════════════════════════════════════════════════════════╗")
print("║              🎯 RL SKILL PERFORMANCE DASHBOARD                    ║")
print("╠══════════════════════════════════════════════════════════════════╣")
print(f"║  Last Updated: {metrics.get('last_updated', 'Never'):<47} ║")
print("╚══════════════════════════════════════════════════════════════════╝")
print()

# Aggregates
agg = metrics.get('aggregates', {})
print("📊 AGGREGATE METRICS")
print("─" * 50)
print(f"  Total Invocations:    {agg.get('total_invocations', 0):>10}")
print(f"  Total Successes:      {agg.get('total_successes', 0):>10}")
print(f"  Total Failures:       {agg.get('total_failures', 0):>10}")
print(f"  Average Success Rate: {agg.get('average_success_rate', 0.5):>10.2%}")
print()

# Top/Bottom skills by selection weight
skills = metrics.get('skills', {})
if skills:
    sorted_skills = sorted(skills.items(), key=lambda x: x[1].get('selection_weight', 0.5), reverse=True)
    
    print(f"🏆 TOP {TOP_N} SKILLS (by selection weight)")
    print("─" * 70)
    print(f"{'Skill':<30} {'Weight':>10} {'Success':>10} {'Invocations':>12}")
    print("─" * 70)
    
    for name, data in sorted_skills[:TOP_N]:
        weight = data.get('selection_weight', 0.5)
        success = data.get('success_rate', 0.5)
        invocations = data.get('invocation_count', 0)
        
        # Color coding (via symbols)
        if weight >= 0.8:
            indicator = "🟢"
        elif weight >= 0.5:
            indicator = "🟡"
        else:
            indicator = "🔴"
        
        print(f"{indicator} {name:<28} {weight:>9.4f} {success:>9.2%} {invocations:>12}")
    
    print()
    
    # Skills needing improvement
    low_performers = [s for s in sorted_skills if s[1].get('selection_weight', 0.5) < 0.5 and s[1].get('invocation_count', 0) >= 5]
    if low_performers:
        print("⚠️  SKILLS NEEDING IMPROVEMENT (weight < 0.5, invocations >= 5)")
        print("─" * 50)
        for name, data in low_performers[:5]:
            print(f"  • {name}: {data.get('selection_weight', 0.5):.4f}")
else:
    print("  No skill performance data yet. Run skills to collect metrics.")

print()
print("─" * 70)
print("💡 Tips:")
print("  • collect-feedback.sh <skill> success|failure - Record execution result")
print("  • sync-metrics.sh - Sync metrics to skill-index.json")
print("  • dashboard.sh --json - Output raw JSON")
PYTHON_EOF
