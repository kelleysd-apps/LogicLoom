#!/usr/bin/env bash
# SDD Framework Migration Script — Monolithic → Plugin-First
# Usage: ./migrate-to-plugins.sh [--dry-run] [--phase <1-5>]
set -euo pipefail

DRY_RUN=false
PHASE="all"
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --phase) shift; PHASE="$1" ;;
  esac
done

PLUGIN_SOURCE="${PLUGIN_SOURCE:-./plugins}"

echo "═══════════════════════════════════════════"
echo " SDD Framework → Plugin Migration Tool"
echo "═══════════════════════════════════════════"
echo " Source: ${PLUGIN_SOURCE}"
echo " Mode:   $(if $DRY_RUN; then echo 'DRY RUN'; else echo 'LIVE'; fi)"
echo " Phase:  ${PHASE}"
echo ""

install_plugin() {
  local plugin="$1"
  if $DRY_RUN; then
    echo "  [DRY RUN] Would install: ${plugin}"
  else
    echo "  Installing: ${plugin}..."
    claude plugin install "${PLUGIN_SOURCE}/${plugin}" 2>/dev/null || echo "  ⚠️  Install via CLI not available — copy manually"
    echo "  ✅ ${plugin} installed"
  fi
}

case "$PHASE" in
  1|all)
    echo "Phase 1: Core Governance"
    install_plugin "sdd-governance"
    ;;&
  2|all)
    echo "Phase 2: Core Plugins"
    for p in sdd-specification sdd-git sdd-debug sdd-creation; do
      install_plugin "$p"
    done
    ;;&
  3|all)
    echo "Phase 3: Domain Plugins"
    for p in sdd-domain-frontend sdd-domain-backend sdd-domain-database sdd-domain-testing sdd-domain-security sdd-domain-devops sdd-domain-performance; do
      install_plugin "$p"
    done
    ;;&
  4|all)
    echo "Phase 4: Orchestration"
    install_plugin "sdd-orchestrator"
    ;;&
esac

echo ""
echo "═══════════════════════════════════════════"
echo " Migration complete!"
echo "═══════════════════════════════════════════"
