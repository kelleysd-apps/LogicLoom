---
name: git-push-workflow
description: |
  Complete git workflow from commit to PR with merge conflict resolution.
  Handles staging, commit, push, and PR creation with user approval at
  every git operation (Principle VI compliance).

  Triggered by: /git-push, "push my changes", "create a PR",
  "commit and push", "submit for review"
allowed-tools: Read, Bash, Grep
category: git
---

# Git Push Workflow Skill

## Purpose

Complete git workflow: stage → commit → push → PR, with **mandatory user approval at every git operation** (Principle VI).

## When to Use

- User invokes `/git-push`
- User wants to commit, push, or create a PR
- After `/finalize` validates compliance

---

## Procedure

### Stage 1: Review Changes

Show the user what will be committed:
- Run `git status` to list changed files
- Run `git diff --stat` for a summary
- Offer to show full diff if requested

If no changes exist, ask whether to push existing unpushed commits.

### Stage 2: Prepare Commit

1. Analyze the changes and **suggest a commit message** based on file patterns and diff content
2. Present the suggestion and let the user accept, edit, or provide their own
3. Show the full commit preview (files + message)

**PRINCIPLE VI CHECKPOINT**: Ask the user to explicitly approve the commit before proceeding. Do NOT commit without a clear "yes."

### Stage 3: Execute Commit

Only after explicit approval:
1. Stage the relevant files (prefer specific files over `git add -A`)
2. Commit with the approved message
3. Report the commit SHA and summary

### Stage 4: Push

1. Show what will be pushed (branch, remote, commit count)

**PRINCIPLE VI CHECKPOINT**: Ask the user to approve the push. Do NOT push without a clear "yes."

2. Execute `git push -u origin <branch>`
3. Handle push failures:
   - **Non-fast-forward**: Offer to pull and rebase first
   - **Auth failure**: Report and suggest `gh auth login`

If `--no-pr` flag was set, skip to completion.

### Stage 5: Create Pull Request

1. Detect the default branch via `gh repo view`
2. Ask the user which branch to target
3. Generate PR title (from commits) and body (summary + test plan)
4. Show PR preview

**PRINCIPLE VI CHECKPOINT**: Ask the user to approve PR creation. Do NOT create without a clear "yes."

5. Create PR via `gh pr create`
6. Report PR number and URL

### Stage 6: Check Merge Status

1. Query PR merge status via `gh pr view`
2. If **clean** → report ready to merge
3. If **conflicts** → report conflicting files with resolution recommendations
4. If **blocked** → report which branch protections are blocking
5. If **CI failing** → report and suggest checking logs

### Stage 7: Conflict Resolution (if needed)

If conflicts detected:
1. List each conflicting file with conflict type
2. Recommend resolution strategy per file
3. **Ask approval** before attempting resolution
4. Create a backup branch before resolving
5. Resolve, commit resolution, push
6. Re-check merge status (max 5 iterations)

### Stage 8: Final Report

```
Git Push Workflow Complete!

PR #[number]: [title]
URL: [url]
Status: [Ready to merge / CI pending / Conflicts]

Summary:
  ✓ Changes committed ([sha])
  ✓ Pushed to origin/[branch]
  ✓ PR created targeting [target]
  [✓/⚠] Merge status: [clean/conflicts/blocked]
```

---

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `-m, --message` | Commit message | Auto-generated |
| `-t, --target` | PR target branch | Default branch |
| `--draft` | Create draft PR | false |
| `--no-pr` | Push only, skip PR | false |
| `--skip-commit` | Push existing commits | false |

## Error Recovery

| Error | Response |
|-------|----------|
| No changes | Offer to push existing commits |
| Auth failed | Report: run `gh auth login` |
| Push rejected | Offer pull + rebase first |
| PR already exists | Offer to update existing PR |
| Max conflict iterations | Report: manual resolution needed |

## Critical Rules

1. **EVERY git operation requires explicit user approval** — commit, push, PR create, conflict resolution
2. **Never force-push** unless the user explicitly requests it
3. **Never push to main/master** without warning the user
4. Include `Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>` in commits
