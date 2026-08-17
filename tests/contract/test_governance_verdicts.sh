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

echo "subagent-git (§7.3 read-only ALLOWLIST; everything else → deny)"
check "subagent + git push → deny"        deny  "$(loom_verdict_subagent_git 'git push origin main' 'a8e')"
check "subagent + /usr/bin/git clean → deny" deny "$(loom_verdict_subagent_git 'cd /tmp && /usr/bin/git clean -fd' 'a8e')"
check "subagent + non-git → allow"         allow "$(loom_verdict_subagent_git 'ls -la' 'a8e')"
check "subagent + 'github' substring → allow" allow "$(loom_verdict_subagent_git 'echo github gitignore digit' 'a8e')"
check "main agent + git push → allow (not this guard)" allow "$(loom_verdict_subagent_git 'git push' '')"
# §7.3: read-only git from a subagent is legitimate exploration and is ALLOWED.
# (Supersedes the pre-§7.3 fixture "subagent + git status → deny".) The guarantee
# is now "a subagent never MUTATES git" — the allowlist below is the whole of it.
check "subagent + git status → allow"      allow "$(loom_verdict_subagent_git 'git status' 'a8e')"
check "subagent + git log --grep=push → allow" allow "$(loom_verdict_subagent_git 'git log --grep=push' 'a8e')"
check "subagent + git diff HEAD → allow"   allow "$(loom_verdict_subagent_git 'git diff HEAD' 'a8e')"
check "subagent + git branch -a → allow"   allow "$(loom_verdict_subagent_git 'git branch -a' 'a8e')"
check "subagent + git worktree list → allow" allow "$(loom_verdict_subagent_git 'git worktree list' 'a8e')"
check "subagent + git stash list → allow"  allow "$(loom_verdict_subagent_git 'git stash list' 'a8e')"
check "subagent + git config --get → allow" allow "$(loom_verdict_subagent_git 'git config --get user.name' 'a8e')"
check "subagent + git -C /tmp/x status → allow" allow "$(loom_verdict_subagent_git 'git -C /tmp/x status' 'a8e')"
check "subagent + git reflog show → allow" allow "$(loom_verdict_subagent_git 'git reflog show' 'a8e')"
# Write forms of read/write subcommands stay denied.
check "subagent + git branch newfeature → deny" deny "$(loom_verdict_subagent_git 'git branch newfeature' 'a8e')"
check "subagent + git tag v1 → deny"       deny  "$(loom_verdict_subagent_git 'git tag v1' 'a8e')"
check "subagent + bare git stash → deny"   deny  "$(loom_verdict_subagent_git 'git stash' 'a8e')"
check "subagent + git remote add → deny"   deny  "$(loom_verdict_subagent_git 'git remote add o u' 'a8e')"
check "subagent + git worktree add → deny" deny  "$(loom_verdict_subagent_git 'git worktree add ../w b' 'a8e')"
check "subagent + git config key value → deny" deny "$(loom_verdict_subagent_git 'git config user.name bob' 'a8e')"
check "subagent + git fetch → deny (writes refs)" deny "$(loom_verdict_subagent_git 'git fetch' 'a8e')"
check "subagent + git reflog expire → deny" deny "$(loom_verdict_subagent_git 'git reflog expire --all' 'a8e')"
check "subagent + git notes add → deny"    deny  "$(loom_verdict_subagent_git 'git notes add' 'a8e')"
check "subagent + git bisect start → deny" deny  "$(loom_verdict_subagent_git 'git bisect start' 'a8e')"
check "subagent + git submodule update → deny" deny "$(loom_verdict_subagent_git 'git submodule update' 'a8e')"
# Code-execution / repo-redirection globals: `git -c core.fsmonitor=<cmd> status`
# EXECUTES <cmd>, so a "read" subcommand is no protection.
check "subagent + git -c core.fsmonitor → deny" deny "$(loom_verdict_subagent_git 'git -c core.fsmonitor=evil status' 'a8e')"
check "subagent + git -c core.pager=!sh → deny" deny "$(loom_verdict_subagent_git 'git -c core.pager=!sh log' 'a8e')"
check "subagent + git --git-dir → deny"    deny  "$(loom_verdict_subagent_git 'git --git-dir=/other status' 'a8e')"
check "subagent + git --work-tree → deny"  deny  "$(loom_verdict_subagent_git 'git --work-tree=/tmp status' 'a8e')"
# Smuggling: command substitution in the same command line.
check "subagent + git status \$(rm -rf) → deny" deny "$(loom_verdict_subagent_git 'git status $(rm -rf /tmp/x)' 'a8e')"
check "subagent + git log --format=\$(id) → deny" deny "$(loom_verdict_subagent_git 'git log --format=$(id)' 'a8e')"

# ── Upstream review G1: git's ENVIRONMENT is a complete bypass of the global-flag
# allowlist. Rule implemented: ANY leading assignment on the subagent read path
# is denied (categorical, not a GIT_* enumeration).
check "subagent + GIT_EXTERNAL_DIFF=… git diff → deny" deny "$(loom_verdict_subagent_git 'GIT_EXTERNAL_DIFF=/tmp/evil git diff' 'a8e')"
check "subagent + GIT_SSH_COMMAND=… git → deny"  deny "$(loom_verdict_subagent_git 'GIT_SSH_COMMAND=/tmp/evil git log' 'a8e')"
check "subagent + GIT_PAGER=… git log → deny"    deny "$(loom_verdict_subagent_git 'GIT_PAGER=/tmp/evil git log' 'a8e')"
check "subagent + GIT_EDITOR=… git status → deny" deny "$(loom_verdict_subagent_git 'GIT_EDITOR=/tmp/evil git status' 'a8e')"
check "subagent + GIT_DIR=… git status → deny"   deny "$(loom_verdict_subagent_git 'GIT_DIR=/other git status' 'a8e')"
check "subagent + GIT_WORK_TREE=… git status → deny" deny "$(loom_verdict_subagent_git 'GIT_WORK_TREE=/tmp git status' 'a8e')"
check "subagent + GIT_CONFIG=… git config --get → deny" deny "$(loom_verdict_subagent_git 'GIT_CONFIG=/tmp/x git config --get user.name' 'a8e')"
check "subagent + GIT_CONFIG_GLOBAL=… git log → deny" deny "$(loom_verdict_subagent_git 'GIT_CONFIG_GLOBAL=/tmp/x git log' 'a8e')"
check "subagent + GIT_ALTERNATE_OBJECT_DIRECTORIES=… → deny" deny "$(loom_verdict_subagent_git 'GIT_ALTERNATE_OBJECT_DIRECTORIES=/tmp git cat-file -p HEAD' 'a8e')"
check "subagent + LD_PRELOAD=… git status → deny" deny "$(loom_verdict_subagent_git 'LD_PRELOAD=/tmp/e.so git status' 'a8e')"
check "subagent + DYLD_INSERT_LIBRARIES=… → deny" deny "$(loom_verdict_subagent_git 'DYLD_INSERT_LIBRARIES=/tmp/e.dylib git status' 'a8e')"
check "subagent + PATH=… git status → deny"      deny "$(loom_verdict_subagent_git 'PATH=/tmp/evil git status' 'a8e')"
check "subagent + IFS=… git status → deny"       deny "$(loom_verdict_subagent_git 'IFS=. git status' 'a8e')"
check "subagent + BASH_ENV=… git status → deny"  deny "$(loom_verdict_subagent_git 'BASH_ENV=/tmp/e git status' 'a8e')"
check "subagent + env GIT_DIR=/x git status → deny" deny "$(loom_verdict_subagent_git 'env GIT_DIR=/x git status' 'a8e')"
check "subagent + cd x && GIT_PAGER=… git log → deny" deny "$(loom_verdict_subagent_git 'cd /r && GIT_PAGER=/tmp/e git log' 'a8e')"
# `env` with no assignment is still just a prefix word — unchanged.
check "subagent + env git status → allow"        allow "$(loom_verdict_subagent_git 'env git status' 'a8e')"

# ── Upstream review G2: file-writing / program-running args AFTER the subcommand,
# in both `--flag=value` and `--flag value` spelling, plus bundled short flags.
check "subagent + git log --output=f → deny"     deny "$(loom_verdict_subagent_git 'git log --output=/tmp/f' 'a8e')"
check "subagent + git log --output f → deny"     deny "$(loom_verdict_subagent_git 'git log --output /tmp/f' 'a8e')"
check "subagent + git show --output=f → deny"    deny "$(loom_verdict_subagent_git 'git show --output=/tmp/f' 'a8e')"
check "subagent + git diff --ext-diff → deny"    deny "$(loom_verdict_subagent_git 'git diff --ext-diff' 'a8e')"
check "subagent + git blame --textconv → deny"   deny "$(loom_verdict_subagent_git 'git blame --textconv f' 'a8e')"
check "subagent + git grep -O <cmd> → deny"      deny "$(loom_verdict_subagent_git 'git grep -O /tmp/evil pat' 'a8e')"
check "subagent + git grep -nO <cmd> → deny (bundled)" deny "$(loom_verdict_subagent_git 'git grep -nO /tmp/evil pat' 'a8e')"
check "subagent + git grep --open-files-in-pager= → deny" deny "$(loom_verdict_subagent_git 'git grep --open-files-in-pager=/tmp/evil pat' 'a8e')"
check "subagent + git log --upload-pack=… → deny" deny "$(loom_verdict_subagent_git 'git log --upload-pack=/tmp/evil' 'a8e')"
# Short flags that merely LOOK dangerous stay allowed (no over-denial):
check "subagent + git grep -c pat → allow"       allow "$(loom_verdict_subagent_git 'git grep -c pat' 'a8e')"
check "subagent + git log -c HEAD → allow"       allow "$(loom_verdict_subagent_git 'git log -c HEAD' 'a8e')"
check "subagent + git -C /Opt/x status → allow"  allow "$(loom_verdict_subagent_git 'git -C /Opt/x status' 'a8e')"

# ── Upstream review G3: reads that escape the repo or hit the network.
check "subagent + git blame --contents /etc/passwd → deny" deny "$(loom_verdict_subagent_git 'git blame --contents /etc/passwd HEAD -- f' 'a8e')"
check "subagent + git blame --contents=… → deny" deny "$(loom_verdict_subagent_git 'git blame --contents=/etc/passwd HEAD' 'a8e')"
check "subagent + git ls-remote → deny (network)" deny "$(loom_verdict_subagent_git 'git ls-remote origin' 'a8e')"
check "subagent + git ls-remote --heads → deny"  deny "$(loom_verdict_subagent_git 'git ls-remote --heads https://x/y' 'a8e')"
check "subagent + git submodule status → deny"   deny "$(loom_verdict_subagent_git 'git submodule status --recursive' 'a8e')"
check "subagent + git submodule summary → deny"  deny "$(loom_verdict_subagent_git 'git submodule summary' 'a8e')"
# Plain blame (no --contents) is still a legitimate read.
check "subagent + git blame f → allow"           allow "$(loom_verdict_subagent_git 'git blame f' 'a8e')"

# ── Upstream review G4: end-of-options / flag-shaped names. Documented behavior.
check "subagent + git branch -- newname → deny"  deny "$(loom_verdict_subagent_git 'git branch -- newname' 'a8e')"
check "subagent + git branch --list newname → deny (conservative)" deny "$(loom_verdict_subagent_git 'git branch --list newname' 'a8e')"
check "subagent + git branch --list → allow"     allow "$(loom_verdict_subagent_git 'git branch --list' 'a8e')"
check "subagent + git tag --list v1 → allow (pattern)" allow "$(loom_verdict_subagent_git 'git tag --list v1' 'a8e')"
check "subagent + git tag -- v1 → deny"          deny "$(loom_verdict_subagent_git 'git tag -- v1' 'a8e')"

# ── ALLOW regression sample (must be unchanged by the G1-G4 hardening).
check "subagent + git status → allow (regression)" allow "$(loom_verdict_subagent_git 'git status' 'a8e')"
check "subagent + git log --oneline -20 → allow" allow "$(loom_verdict_subagent_git 'git log --oneline -20' 'a8e')"
check "subagent + git -C /tmp/x status → allow (regression)" allow "$(loom_verdict_subagent_git 'git -C /tmp/x status' 'a8e')"
check "subagent + git --no-pager log → allow"    allow "$(loom_verdict_subagent_git 'git --no-pager log' 'a8e')"
check "subagent + git config --get → allow (regression)" allow "$(loom_verdict_subagent_git 'git config --get user.name' 'a8e')"

# ── Main-agent verdicts are UNCHANGED by the subagent hardening.
check "main + GIT_DIR=/x git status → allow (unchanged)" allow "$(loom_verdict_git_mutation 'GIT_DIR=/x git status')"
check "main + git status → allow (unchanged)"    allow "$(loom_verdict_git_mutation 'git status')"
check "main + git commit -m x → ask (unchanged)" ask   "$(loom_verdict_git_mutation 'git commit -m x')"
check "main + git push → ask (unchanged)"        ask   "$(loom_verdict_git_mutation 'git push')"
check "main + gh pr merge 1 → ask (unchanged)"   ask   "$(loom_verdict_gh_mutation 'gh pr merge 1')"
check "main + gh pr list → allow (unchanged)"    allow "$(loom_verdict_gh_mutation 'gh pr list')"

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
