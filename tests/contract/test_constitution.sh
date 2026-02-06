#!/usr/bin/env bash
# Contract Tests: Constitution v3.0.0 (16 Principles)
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

echo "═══ Constitution v3.0.0 Contract Tests ═══"
echo ""

echo "Structure"
assert "constitution.md exists" "[ -f .specify/memory/constitution.md ]"
assert "Version is v3.0.0" "grep -q 'v3.0.0' .specify/memory/constitution.md"
assert "Has 16 Principles header" "grep -q '16 Principles' .specify/memory/constitution.md"

echo ""
echo "Immutable Principles (I-III)"
assert "Principle I: Library-First" "grep -q 'Principle I.*Library-First' .specify/memory/constitution.md"
assert "Principle II: Test-First" "grep -q 'Principle II.*Test-First' .specify/memory/constitution.md"
assert "Principle III: Contract-First" "grep -q 'Principle III.*Contract-First' .specify/memory/constitution.md"

echo ""
echo "Quality & Safety (IV-IX)"
assert "Principle IV: Idempotent" "grep -q 'Principle IV.*Idempotent' .specify/memory/constitution.md"
assert "Principle V: Progressive Enhancement" "grep -q 'Principle V.*Progressive' .specify/memory/constitution.md"
assert "Principle VI: Git Operation Approval" "grep -q 'Principle VI.*Git' .specify/memory/constitution.md"
assert "Principle VII: Observability" "grep -q 'Principle VII.*Observability' .specify/memory/constitution.md"
assert "Principle VIII: Documentation Sync" "grep -q 'Principle VIII.*Documentation' .specify/memory/constitution.md"
assert "Principle IX: Dependency Management" "grep -q 'Principle IX.*Dependency' .specify/memory/constitution.md"

echo ""
echo "Workflow & Delegation (X-XV)"
assert "Principle X: Skills-First Delegation" "grep -q 'Principle X.*Delegation' .specify/memory/constitution.md"
assert "Principle XI: Input Validation" "grep -q 'Principle XI.*Input' .specify/memory/constitution.md"
assert "Principle XII: Design System" "grep -q 'Principle XII.*Design' .specify/memory/constitution.md"
assert "Principle XIII: Access Control" "grep -q 'Principle XIII.*Access' .specify/memory/constitution.md"
assert "Principle XIV: AI Model Selection" "grep -q 'Principle XIV.*Model' .specify/memory/constitution.md"
assert "Principle XV: File Organization" "grep -q 'Principle XV.*File' .specify/memory/constitution.md"

echo ""
echo "Plugin Architecture (XVI)"
assert "Principle XVI: Plugin-First Architecture" "grep -q 'Principle XVI.*Plugin-First' .specify/memory/constitution.md"
assert "XVI requires manifest" "grep -q 'Manifest Required' .specify/memory/constitution.md"
assert "XVI requires governance dependency" "grep -q 'Governance Dependency' .specify/memory/constitution.md"
assert "XVI has protected plugins" "grep -q 'Protected Plugins' .specify/memory/constitution.md"
assert "XVI requires RL metrics" "grep -q 'RL Metrics' .specify/memory/constitution.md"

echo ""
echo "CLAUDE.md alignment"
assert "CLAUDE.md references 16 principles" "grep -q '16 principles' CLAUDE.md"
assert "CLAUDE.md has Principle XVI" "grep -q 'XVI.*Plugin-First' CLAUDE.md"
assert "CLAUDE.md references v3.0.0" "grep -q 'v3.0.0' CLAUDE.md"

echo ""
echo "═══════════════════════════════════════"
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "═══════════════════════════════════════"
[ $FAIL -eq 0 ] && exit 0 || exit 1
