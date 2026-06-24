#!/usr/bin/env bash
# Conformance test for the off-host git-approval adapter (Phase 2). Proves the
# adapter enforces Principle VI using the SAME conformance-tested verdict
# functions as the Claude Code hooks, in a non-interactive (autonomous) context
# — i.e. a non-Claude host's enforcement adapter actually gates autonomous git.
set -uo pipefail
PASS=0; FAIL=0; TOTAL=0
check(){ TOTAL=$((TOTAL+1)); if [ "$2" = "$3" ]; then echo "  ✅ PASS: $1"; PASS=$((PASS+1));
  else echo "  ❌ FAIL: $1 (expected '$2' got '$3')"; FAIL=$((FAIL+1)); fi; }

ADAPTER=".logic-loom/adapters/git-approval-gate.sh"

# Run the gate in a forced-autonomous subshell; echo allow|block by exit status.
gate(){ # cmd  approved(0/1)
  if env LOOM_GIT_ASSUME_NONINTERACTIVE=1 LOOM_GIT_APPROVED="${2:-}" \
       bash -c '. "'"$ADAPTER"'"; loom_git_approval_gate "$1"' _ "$1" </dev/null >/dev/null 2>&1
  then echo allow; else echo block; fi
}

echo "═══ Off-host Git-Approval Adapter Conformance (Phase 2) ═══"
echo ""

echo "adapter sources the shared verdict lib (single source)"
check "loom_verdict_git_mutation available after sourcing" yes \
  "$(bash -c '. "'"$ADAPTER"'"; declare -f loom_verdict_git_mutation >/dev/null 2>&1 && echo yes || echo no')"

echo ""
echo "autonomous (non-interactive) git mutations are BLOCKED"
check "git push (autonomous) → block"        block "$(gate 'git push origin main')"
check "git commit (autonomous) → block"      block "$(gate 'git commit -m x')"
check "git rebase (autonomous) → block"      block "$(gate 'git rebase main')"
check "git reset --hard (autonomous) → block" block "$(gate 'git reset --hard HEAD~1')"
check "/usr/bin/git push (path prefix) → block" block "$(gate 'cd /tmp && /usr/bin/git push')"

echo ""
echo "explicit approval token lets a mutation through"
check "git push + LOOM_GIT_APPROVED=1 → allow"   allow "$(gate 'git push origin main' 1)"
check "git commit + LOOM_GIT_APPROVED=1 → allow" allow "$(gate 'git commit -m x' 1)"

echo ""
echo "read-only git and non-git pass through"
check "git status → allow"  allow "$(gate 'git status')"
check "git log → allow"     allow "$(gate 'git log --oneline')"
check "git branch (list) → allow" allow "$(gate 'git branch')"
check "non-git 'ls -la' → allow"  allow "$(gate 'ls -la')"
check "non-git 'echo github' → allow" allow "$(gate 'echo github digit')"

echo ""
echo "degraded mode (verdict lib missing) fails CLOSED for any git, allows non-git"
dgate(){ # cmd -> allow|block with the verdict lib forced absent
  if env LOOM_GIT_ASSUME_NONINTERACTIVE=1 LOOM_VERDICT_LIB=/nonexistent/none.sh \
       bash -c '. "'"$ADAPTER"'"; loom_git_approval_gate "$1"' _ "$1" </dev/null >/dev/null 2>&1
  then echo allow; else echo block; fi
}
check "degraded: git tag → block (no leaky subset)"    block "$(dgate 'git tag v1')"
check "degraded: git switch → block"                   block "$(dgate 'git switch -c x')"
check "degraded: git status → block (refuse all git)"  block "$(dgate 'git status')"
check "degraded: 'ls pushpin.txt' → allow (not git)"   allow "$(dgate 'ls pushpin.txt')"
check "degraded: 'cat commitlog.md' → allow (not git)" allow "$(dgate 'cat commitlog.md')"

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
