#!/usr/bin/env bash
# Contract Tests: Constitution v3.2.0 (16 Principles)
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

echo "═══ Constitution v3.2.0 Contract Tests ═══"
echo ""

echo "Structure"
assert "constitution.md exists" "[ -f .logic-loom/memory/constitution.md ]"
assert "Title is v3.2.0" "grep -q '# LogicLoom Constitution v3.2.0' .logic-loom/memory/constitution.md"
assert "Version is v3.2.0" "grep -q 'v3.2.0' .logic-loom/memory/constitution.md"
assert "Has 16 enforceable principles" "grep -q '16 enforceable principles' .logic-loom/memory/constitution.md"
# Amendment dates + version-history rows exist on dev-main but are intentionally
# scrubbed from the published template (history-scrub.sh erases dev-history dates).
# Assert them only when a version-history table is present, so the suite passes on
# BOTH dev-main and the sanitized template.
if grep -qE '^\| [0-9]+\.[0-9]+\.[0-9]+ \|' .logic-loom/memory/constitution.md; then
  assert "v3.1.0 amendment date recorded" "grep -q 'Amended.*2026-05-28 (v3.1.0)' .logic-loom/memory/constitution.md"
  assert "v3.2.0 amendment date recorded" "grep -q '2026-06-15 (v3.2.0)' .logic-loom/memory/constitution.md"
  assert "v3.1.0 version-history row exists" "grep -qE '^\| 3.1.0 \|' .logic-loom/memory/constitution.md"
  assert "v3.2.0 version-history row exists" "grep -qE '^\| 3.2.0 \|' .logic-loom/memory/constitution.md"
fi
assert "Governance-vs-direction clause defers to VISION.md" "grep -q 'Governance vs. direction' .logic-loom/memory/constitution.md && grep -q 'VISION.md' .logic-loom/memory/constitution.md"

echo ""
echo "Immutable Principles (I-III)"
assert "Principle I: Library-First" "grep -q 'Principle I.*Library-First' .logic-loom/memory/constitution.md"
assert "Principle II: Test-First" "grep -q 'Principle II.*Test-First' .logic-loom/memory/constitution.md"
assert "Principle III: Contract-First" "grep -q 'Principle III.*Contract-First' .logic-loom/memory/constitution.md"

echo ""
echo "Quality & Safety (IV-IX)"
assert "Principle IV: Idempotent" "grep -q 'Principle IV.*Idempotent' .logic-loom/memory/constitution.md"
assert "Principle V: Progressive Enhancement" "grep -q 'Principle V.*Progressive' .logic-loom/memory/constitution.md"
assert "Principle VI: Git Operation Approval" "grep -q 'Principle VI.*Git' .logic-loom/memory/constitution.md"
assert "Principle VII: Observability" "grep -q 'Principle VII.*Observability' .logic-loom/memory/constitution.md"
assert "Principle VIII: Documentation Sync" "grep -q 'Principle VIII.*Documentation' .logic-loom/memory/constitution.md"
assert "Principle IX: Dependency Management" "grep -q 'Principle IX.*Dependency' .logic-loom/memory/constitution.md"

echo ""
echo "Workflow & Delegation (X-XV)"
assert "Principle X: Delegation & Context Isolation" "grep -q '### Principle X: Delegation & Context Isolation' .logic-loom/memory/constitution.md"
assert "Principle XI: Input Validation" "grep -q 'Principle XI.*Input' .logic-loom/memory/constitution.md"
assert "Principle XII: Design System" "grep -q 'Principle XII.*Design' .logic-loom/memory/constitution.md"
assert "Principle XIII: Access Control" "grep -q 'Principle XIII.*Access' .logic-loom/memory/constitution.md"
assert "Principle XIV: AI Model Selection" "grep -q 'Principle XIV.*Model' .logic-loom/memory/constitution.md"
assert "Principle XV: File Organization" "grep -q 'Principle XV.*File' .logic-loom/memory/constitution.md"

echo ""
echo "Plugin Architecture (XVI)"
assert "Principle XVI: Plugin-First Architecture" "grep -q 'Principle XVI.*Plugin-First' .logic-loom/memory/constitution.md"
assert "Principle XVI excludes RL metrics" "! grep -q 'MUST include .rl_metrics' .logic-loom/memory/constitution.md"

echo ""
echo "CLAUDE.md alignment"
assert "CLAUDE.md references 16 principles" "grep -q '16 principles' CLAUDE.md"
assert "CLAUDE.md has Principle XVI" "grep -q 'XVI.*Plugin-First' CLAUDE.md"

echo ""
echo "═══════════════════════════════════════"
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "═══════════════════════════════════════"
[ $FAIL -eq 0 ] && exit 0 || exit 1
