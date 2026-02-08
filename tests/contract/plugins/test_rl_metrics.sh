#!/usr/bin/env bash
# Contract Tests: RL Metrics System
set -euo pipefail

PASS=0; FAIL=0; TOTAL=0

assert() {
  TOTAL=$((TOTAL + 1))
  local desc="$1"; local condition="$2"
  if eval "$condition"; then
    echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

echo "═══ RL Metrics Contract Tests ═══"
echo ""

echo "T1.5: RL metrics in governance hooks"
assert "rl-metrics-capture.sh exists" "[ -f plugins/sdd-governance/hooks/scripts/rl-metrics-capture.sh ]"
assert "rl-metrics-capture.sh is executable" "[ -x plugins/sdd-governance/hooks/scripts/rl-metrics-capture.sh ]"
assert "Uses EMA algorithm" "grep -q 'EMA\|ema\|learning_rate\|lr' plugins/sdd-governance/hooks/scripts/rl-metrics-capture.sh"
assert "Updates success_rate" "grep -q 'success_rate' plugins/sdd-governance/hooks/scripts/rl-metrics-capture.sh"
assert "Updates selection_weight" "grep -q 'selection_weight' plugins/sdd-governance/hooks/scripts/rl-metrics-capture.sh"

echo ""
echo "T3.4: Per-plugin RL metrics baseline"
PLUGINS_WITH_RL=0
PLUGINS_TOTAL=0
for plugin_dir in plugins/sdd-*/; do
  name=$(basename "$plugin_dir")
  manifest="${plugin_dir}.claude-plugin/plugin.json"
  if [ -f "$manifest" ]; then
    PLUGINS_TOTAL=$((PLUGINS_TOTAL + 1))
    has_rl=$(python3 -c "
import json
d=json.load(open('$manifest'))
rl=d.get('rl_metrics',{})
ok=all(k in rl for k in ['success_rate','selection_weight','invocation_count'])
print('yes' if ok else 'no')
" 2>/dev/null || echo "no")
    if [ "$has_rl" = "yes" ]; then
      PLUGINS_WITH_RL=$((PLUGINS_WITH_RL + 1))
    else
      echo "  ⚠️  ${name} missing rl_metrics fields"
    fi
  fi
done
assert "All plugins have complete rl_metrics" "[ $PLUGINS_WITH_RL -eq $PLUGINS_TOTAL ]"

echo ""
echo "T3.4.1: RL metrics values are valid"
for plugin_dir in plugins/sdd-*/; do
  name=$(basename "$plugin_dir")
  manifest="${plugin_dir}.claude-plugin/plugin.json"
  if [ -f "$manifest" ]; then
    valid=$(python3 -c "
import json
d=json.load(open('$manifest'))
rl=d.get('rl_metrics',{})
sr=rl.get('success_rate',0)
sw=rl.get('selection_weight',0)
ic=rl.get('invocation_count',0)
ok=(0<=sr<=1) and (0.1<=sw<=1.0) and (ic>=0)
print('yes' if ok else 'no')
" 2>/dev/null || echo "no")
    assert "${name}: rl_metrics values in valid range" "[ '$valid' = 'yes' ]"
  fi
done

echo ""
echo "T5.2: RL feedback scripts"
assert "collect-feedback.sh exists" "[ -f .specify/scripts/bash/rl/collect-feedback.sh ]"
assert "sync-metrics.sh exists" "[ -f .specify/scripts/bash/rl/sync-metrics.sh ]"
assert "dashboard.sh exists" "[ -f .specify/scripts/bash/rl/dashboard.sh ]"

echo ""
echo "═══════════════════════════════════════"
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "═══════════════════════════════════════"
[ $FAIL -eq 0 ] && exit 0 || exit 1
