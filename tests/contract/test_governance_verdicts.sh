#!/usr/bin/env bash
# Golden-fixture conformance test for the L2 verdict functions
# (.logic-loom/lib/governance-verdicts.sh). These fixtures are the shared
# contract every enforcement adapter (the Claude Code hooks today; off-host git
# hooks / PATH wrappers / CI gates tomorrow) must satisfy before its matrix cell
# in governance-threat-model.md may be labeled "enforced". Host-agnostic: any
# POSIX-ish shell with bash can run it.
set -uo pipefail

LIB=".logic-loom/lib/governance-verdicts.sh"
PASS=0; FAIL=0; TOTAL=0

# shellcheck disable=SC1090
source "$LIB"

check() { # desc  expected  actual
  TOTAL=$((TOTAL + 1))
  if [ "$2" = "$3" ]; then echo "  ✅ PASS: $1"; PASS=$((PASS + 1))
  else echo "  ❌ FAIL: $1 (expected '$2', got '$3')"; FAIL=$((FAIL + 1)); fi
}

echo "═══ Governance Verdict Conformance (golden fixtures) ═══"
echo ""

echo "subagent-git-deny (any git from a subagent → deny)"
check "subagent + git push → deny"        deny  "$(loom_verdict_subagent_git 'git push origin main' 'a8e')"
check "subagent + git status → deny"       deny  "$(loom_verdict_subagent_git 'git status' 'a8e')"
check "subagent + /usr/bin/git clean → deny" deny "$(loom_verdict_subagent_git 'cd /tmp && /usr/bin/git clean -fd' 'a8e')"
check "subagent + non-git → allow"         allow "$(loom_verdict_subagent_git 'ls -la' 'a8e')"
check "subagent + 'github' substring → allow" allow "$(loom_verdict_subagent_git 'echo github gitignore digit' 'a8e')"
check "main agent + git push → allow (not this guard)" allow "$(loom_verdict_subagent_git 'git push' '')"

echo ""
echo "git-mutation gate (main-agent mutating git → ask)"
check "git push → ask"            ask   "$(loom_verdict_git_mutation 'git push origin main')"
check "git commit → ask"          ask   "$(loom_verdict_git_mutation 'git commit -m x')"
check "git -C /r push → ask"      ask   "$(loom_verdict_git_mutation 'git -C /r push')"
check "git branch -d x → ask"     ask   "$(loom_verdict_git_mutation 'git branch -d feature')"
check "git remote add → ask"      ask   "$(loom_verdict_git_mutation 'git remote add o url')"
check "git clean -fd → ask"       ask   "$(loom_verdict_git_mutation 'git clean -fd')"
check "git status → allow"        allow "$(loom_verdict_git_mutation 'git status')"
check "git log → allow"           allow "$(loom_verdict_git_mutation 'git log --oneline')"
check "git branch (list) → allow" allow "$(loom_verdict_git_mutation 'git branch')"
check "non-git 'digit' → allow"   allow "$(loom_verdict_git_mutation 'echo digit')"
# Gate-review additions: close dangerous false-ALLOWs (data-affecting subcommands)
check "git restore → ask"         ask   "$(loom_verdict_git_mutation 'git restore file.ts')"
check "git update-ref → ask"      ask   "$(loom_verdict_git_mutation 'git update-ref refs/heads/main HEAD~5')"
check "git symbolic-ref → ask"    ask   "$(loom_verdict_git_mutation 'git symbolic-ref HEAD refs/heads/x')"
check "git filter-branch → ask"   ask   "$(loom_verdict_git_mutation 'git filter-branch --force')"
check "git fast-import → ask"     ask   "$(loom_verdict_git_mutation 'git fast-import < dump')"
# gh gate additions: `git worktree add/remove/prune` was ungated for the main agent.
check "git worktree add → ask"    ask   "$(loom_verdict_git_mutation 'git worktree add ../wt br')"
check "git worktree remove → ask" ask   "$(loom_verdict_git_mutation 'git worktree remove ../wt')"
check "git worktree prune → ask"  ask   "$(loom_verdict_git_mutation 'git worktree prune')"
check "git worktree list → allow" allow "$(loom_verdict_git_mutation 'git worktree list')"
check "bare git worktree → allow" allow "$(loom_verdict_git_mutation 'git worktree')"

echo ""
echo "gh gate (main-agent consequential gh → ask; read-only gh → allow)"
check "gh pr create → ask"     ask   "$(loom_verdict_gh_mutation 'gh pr create --title t')"
check "gh pr merge → ask"      ask   "$(loom_verdict_gh_mutation 'gh pr merge 12 --squash')"
check "gh pr review → ask"     ask   "$(loom_verdict_gh_mutation 'gh pr review 12 --approve')"
check "gh workflow run → ask"  ask   "$(loom_verdict_gh_mutation 'gh workflow run promote-to-main.yml')"
check "gh run cancel → ask"    ask   "$(loom_verdict_gh_mutation 'gh run cancel 55')"
check "gh release create → ask" ask  "$(loom_verdict_gh_mutation 'gh release create v1.0.0')"
check "gh repo delete → ask"   ask   "$(loom_verdict_gh_mutation 'gh repo delete o/r --yes')"
check "gh issue create → ask"  ask   "$(loom_verdict_gh_mutation 'gh issue create --title t')"
check "gh alias set → ask"     ask   "$(loom_verdict_gh_mutation 'gh alias set pm "pr merge"')"
check "gh secret set → ask"    ask   "$(loom_verdict_gh_mutation 'gh secret set TOKEN --body v')"
check "gh auth login → ask"    ask   "$(loom_verdict_gh_mutation 'gh auth login')"
# The laundering vector: merges a PR without the word "merge" anywhere useful.
check "gh api -X PUT .../merge → ask" ask "$(loom_verdict_gh_mutation 'gh api -X PUT repos/o/r/pulls/9/merge')"
check "gh api --method POST → ask"    ask "$(loom_verdict_gh_mutation 'gh api --method POST repos/o/r/issues')"
check "gh pr list → allow"     allow "$(loom_verdict_gh_mutation 'gh pr list')"
check "gh pr view → allow"     allow "$(loom_verdict_gh_mutation 'gh pr view 12')"
check "gh pr checks → allow"   allow "$(loom_verdict_gh_mutation 'gh pr checks 12')"
check "gh run watch → allow"   allow "$(loom_verdict_gh_mutation 'gh run watch 55')"
check "gh repo view → allow"   allow "$(loom_verdict_gh_mutation 'gh repo view o/r')"
check "gh workflow view → allow" allow "$(loom_verdict_gh_mutation 'gh workflow view ci.yml')"
check "gh api (no method) → allow"    allow "$(loom_verdict_gh_mutation 'gh api repos/o/r/pulls')"
check "gh api -X GET → allow"         allow "$(loom_verdict_gh_mutation 'gh api -X GET repos/o/r/pulls')"
check "gh auth status → allow" allow "$(loom_verdict_gh_mutation 'gh auth status')"
check "gh label list → allow"  allow "$(loom_verdict_gh_mutation 'gh label list')"
check "gh in prose → allow"    allow "$(loom_verdict_gh_mutation 'echo \"run gh pr merge later\"')"
check "'github' substring → allow" allow "$(loom_verdict_gh_mutation 'ls github/ghost')"
check "cd && gh pr merge → ask"    ask "$(loom_verdict_gh_mutation 'cd /r && gh pr merge 12')"

echo ""
echo "subagent-gh-deny (any gh from a subagent → deny)"
check "subagent + gh pr merge → deny" deny "$(loom_verdict_subagent_gh 'gh pr merge 12' 'a8e')"
check "subagent + gh pr list → deny"  deny "$(loom_verdict_subagent_gh 'gh pr list' 'a8e')"
check "subagent + non-gh → allow"     allow "$(loom_verdict_subagent_gh 'ls -la' 'a8e')"
check "subagent + 'github' word → allow" allow "$(loom_verdict_subagent_gh 'ls github/ghost' 'a8e')"
check "main agent + gh pr merge → allow (not this guard)" allow "$(loom_verdict_subagent_gh 'gh pr merge 12' '')"

echo ""
echo "governance-file protection (subagent deny / main ask / else allow)"
check ".claude/hooks/x.sh + subagent → deny"  deny  "$(loom_verdict_protected_path '.claude/hooks/x.sh' 'a8e')"
check ".claude/hooks/x.sh + main → ask"        ask   "$(loom_verdict_protected_path '.claude/hooks/x.sh' '')"
check "constitution.md + main → ask"           ask   "$(loom_verdict_protected_path '.logic-loom/memory/constitution.md' '')"
check "settings.json + subagent → deny"        deny  "$(loom_verdict_protected_path '.claude/settings.json' 'a8e')"
check "loom-governance hooks + subagent → deny" deny "$(loom_verdict_protected_path 'plugins/loom-governance/hooks/scripts/x.sh' 'a8e')"
check "normal src file + main → allow"         allow "$(loom_verdict_protected_path 'src/app.ts' '')"
check "normal src file + subagent → allow"     allow "$(loom_verdict_protected_path 'src/app.ts' 'a8e')"
# Gate-review addition: the verdict lib itself must be self-protecting (it is now
# load-bearing — failing open if it's blanked was a real regression).
check "verdict lib + subagent → deny" deny "$(loom_verdict_protected_path '.logic-loom/lib/governance-verdicts.sh' 'a8e')"
check "verdict lib + main → ask"      ask  "$(loom_verdict_protected_path '.logic-loom/lib/governance-verdicts.sh' '')"
check "policy.sh + subagent → deny"   deny "$(loom_verdict_protected_path '.logic-loom/lib/policy.sh' 'a8e')"

echo ""
echo "freeze write-scope (freeze-hit deny / no-owns allow / owns-hit allow / else deny)"
check "in owns → allow"          allow "$(loom_verdict_freeze_scope 'features/x/src/a.ts' 'features/x/src' '')"
check "owns exact → allow"       allow "$(loom_verdict_freeze_scope 'features/x/src' 'features/x/src' '')"
check "outside owns → deny"      deny  "$(loom_verdict_freeze_scope 'features/x/other.ts' 'features/x/src' '')"
check "freeze beats owns → deny" deny  "$(loom_verdict_freeze_scope 'features/x/.docs/r.md' 'features/x' 'features/x/.docs')"
check "no owns declared → allow" allow "$(loom_verdict_freeze_scope 'anything/at/all.ts' '' '')"

echo ""
echo "════════════════════════════════"
echo " Results: $PASS/$TOTAL passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
[ $FAIL -eq 0 ] && exit 0 || exit 1
