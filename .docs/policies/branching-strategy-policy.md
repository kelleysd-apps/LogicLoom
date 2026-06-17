# Branching Strategy Policy

**Version**: 1.0.0
**Effective Date**: 2025-11-07
**Authority**: Constitution v3.1.0 - Principle VI (Git Operation Approval)
**Review Cycle**: Quarterly

---

## Purpose

This policy establishes Git branching standards and workflows for the LogicLoom framework, ensuring clean history, collaborative development, and safe integration following constitutional principles.

---

## Constitutional Alignment

This policy enforces:
- **Principle VI**: Git Operation Approval - No autonomous git operations without user approval
- **Principle VIII**: Documentation Synchronization - Branches track documentation changes
- **All Principles**: Branch names and conventions support constitutional workflow

---

## Scope

All Git repositories using the LogicLoom framework must follow this branching strategy, including:
- Application repositories
- Library repositories
- Infrastructure repositories
- Documentation repositories

---

## Branch Types

### Main Branches

#### main (or master)

**Purpose**: Production-ready code

**Characteristics**:
- Always deployable
- Protected (no direct pushes)
- Requires PR and approval
- Tagged with version numbers
- Represents current production state

**Naming**: `main` (preferred) or `master` (legacy)

**Protection Rules**:
- ✅ Require PR before merging
- ✅ Require ≥1 approval
- ✅ Require status checks to pass
- ✅ Require up-to-date branch
- ❌ No force pushes
- ❌ No deletions

#### develop (optional)

**Purpose**: Integration branch for ongoing development

**Characteristics**:
- Latest development changes
- May be unstable
- Integration testing
- Auto-deploys to development environment

**Naming**: `develop`

**When to Use**:
- Teams ≥5 developers
- Continuous integration workflow
- Need for stable main branch

**When to Skip**:
- Small teams (<5 developers)
- GitHub Flow (direct to main)

---

### Supporting Branches

#### Feature Branches

**Purpose**: Develop new features or enhancements

**Naming Convention**:
```
{feature-number}-{short-description}
```

**Examples**:
- `001-user-authentication`
- `042-pagination-api`
- `123-fix-memory-leak`

**LogicLoom Convention** (when user approves):
- User specifies feature description
- System generates: `###-feature-name`
- Format: 3-digit number + kebab-case description
- Example: "Add user profile" → `001-user-profile`

**Branch From**: `main` (or `develop` if using)

**Merge Into**: `main` (or `develop`)

**Lifetime**: Until feature complete and merged (typically 1-7 days)

**Workflow**:
```bash
# Create feature branch (with user approval per Principle VI)
git checkout -b 001-user-authentication main

# Work on feature
git add .
git commit -m "feat: implement user authentication"

# Keep up to date with main
git fetch origin
git rebase origin/main

# Push to remote
git push -u origin 001-user-authentication

# Create pull request
gh pr create --base main --head 001-user-authentication
```

**Delete After Merge**: Yes (keep history clean)

#### Hotfix Branches

**Purpose**: Emergency fixes for production issues

**Naming Convention**:
```
hotfix/{issue-description}
```

**Examples**:
- `hotfix/password-reset-bug`
- `hotfix/security-xss-vulnerability`
- `hotfix/database-connection-timeout`

**Branch From**: `main`

**Merge Into**: `main` AND `develop` (if exists)

**Lifetime**: Short (hours, not days)

**Workflow**:
```bash
# Create hotfix branch
git checkout -b hotfix/password-reset-bug main

# Fix the issue (minimal changes)
git add .
git commit -m "fix: resolve password reset email bug"

# Push and create PR
git push -u origin hotfix/password-reset-bug
gh pr create --base main --head hotfix/password-reset-bug

# After merge to main, also merge to develop
git checkout develop
git merge hotfix/password-reset-bug
git push origin develop
```

**Fast-Track Approval**: Yes (single approver for emergencies)

#### Release Branches (optional)

**Purpose**: Prepare for production release

**Naming Convention**:
```
release/v{major}.{minor}.{patch}
```

**Examples**:
- `release/v1.2.0`
- `release/v2.0.0-beta.1`

**Branch From**: `develop`

**Merge Into**: `main` AND `develop`

**Lifetime**: Until release deployed (typically 1-3 days)

**When to Use**:
- Formal release process
- Version-specific testing
- Release candidates

**Workflow**:
```bash
# Create release branch from develop
git checkout -b release/v1.2.0 develop

# Bump version, update changelog
npm version minor
git add .
git commit -m "chore: bump version to 1.2.0"

# Test and fix bugs (no new features)
# ...

# Merge to main and tag
git checkout main
git merge --no-ff release/v1.2.0
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin main --tags

# Merge back to develop
git checkout develop
git merge --no-ff release/v1.2.0
git push origin develop

# Delete release branch
git branch -d release/v1.2.0
git push origin --delete release/v1.2.0
```

---

## Branching Workflows

### GitHub Flow (Recommended for Small Teams)

**Simple workflow**: feature branches → main

```
main
 ├─ 001-feature-a ─→ PR ─→ main
 ├─ 002-feature-b ─→ PR ─→ main
 └─ 003-feature-c ─→ PR ─→ main
```

**Characteristics**:
- Single main branch (always deployable)
- Feature branches for all work
- PR and review before merge
- Deploy from main frequently

**Best For**:
- Small teams (<5 developers)
- Continuous deployment
- Simple release process

**LogicLoom Default**: GitHub Flow

### Git Flow (Optional for Large Teams)

**Complex workflow**: feature branches → develop → release → main

```
main ← release/v1.0 ← develop
                      ├─ 001-feature-a
                      ├─ 002-feature-b
                      └─ 003-feature-c
```

**Characteristics**:
- Two main branches (main + develop)
- Release branches for preparation
- Hotfix branches for emergencies
- Formal versioning

**Best For**:
- Large teams (≥5 developers)
- Scheduled releases
- Complex QA process

---

## Branch Naming Rules

### Format

```
{type}/{identifier}-{description}
```

**Type**: feature, hotfix, release, docs, chore
**Identifier**: Number or issue ID
**Description**: Kebab-case short description

### Rules

1. **Use lowercase**: `feature/001-user-auth` not `Feature/001-User-Auth`
2. **Use kebab-case**: `user-authentication` not `user_authentication`
3. **Be descriptive**: `fix-memory-leak` not `fix-bug`
4. **Be concise**: `add-pagination` not `add-pagination-to-user-list-with-sorting`
5. **Include identifier**: `001-feature` not `feature` (helps tracking)

### Examples

**Good**:
- `001-user-authentication`
- `042-api-pagination`
- `hotfix/security-xss-fix`
- `release/v1.2.0`
- `docs/api-documentation`

**Bad**:
- `my-branch` (not descriptive)
- `Feature-Branch` (not lowercase)
- `user_auth` (not kebab-case)
- `branch` (too vague)

---

## Commit Messages

### Format

Follow Conventional Commits specification:

```
{type}({scope}): {subject}

{body}

{footer}
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting (no code change)
- `refactor`: Code restructure (no behavior change)
- `perf`: Performance improvement
- `test`: Adding or updating tests
- `chore`: Build process, dependencies
- `ci`: CI/CD configuration

### Examples

**Good**:
```
feat(auth): add JWT token authentication

Implement JWT-based authentication with refresh tokens.
Users can now log in with email/password and receive
access tokens valid for 1 hour.

Closes #42
```

```
fix(api): resolve pagination offset error

The pagination offset was incorrectly calculated for
page sizes > 100. Now uses correct formula.

Fixes #123
```

**Bad**:
```
Update stuff
```
```
fix bug
```
```
WIP
```

### LogicLoom Commits

Include framework attribution:

```
feat(auth): implement user authentication system

[Feature description]

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## Pull Request Workflow

### Creating PRs

**PR Title**: Same as commit message format
```
feat(auth): add JWT token authentication
```

**PR Description Template**:
```markdown
## Summary
Brief description of changes

## Changes
- Added JWT authentication
- Created login endpoint
- Updated user model

## Testing
- [x] Unit tests pass
- [x] Integration tests pass
- [x] Manual testing complete

## Constitutional Compliance
- [x] Principle I: Library-first (auth library created)
- [x] Principle II: Test-first (tests written before code)
- [x] Principle III: Contract-first (API contract defined)

## Screenshots (if UI changes)
[Add screenshots]

## Related Issues
Closes #42
```

### PR Review Process

See Code Review Policy (`.docs/policies/code-review-policy.md`) for details.

**Summary**:
1. Author creates PR with description
2. CI/CD runs automated checks
3. Reviewer(s) review code
4. Address feedback
5. Approval obtained
6. Merge to target branch
7. Delete feature branch

---

## Branch Protection

### Main Branch Protection

**Required settings** for `main`:

```yaml
protection:
  required_pull_request_reviews:
    required_approving_review_count: 1
    dismiss_stale_reviews: true
    require_code_owner_reviews: false

  required_status_checks:
    strict: true
    contexts:
      - ci/tests
      - ci/lint
      - ci/security-scan

  enforce_admins: true

  restrictions:
    users: []
    teams: []

  allow_force_pushes: false
  allow_deletions: false

  required_linear_history: false
  required_signatures: false
```

### Develop Branch Protection (if using)

**Recommended settings** for `develop`:

- Require PR: Yes
- Required approvals: 1
- Required status checks: All
- Allow force pushes: No

---

## Merging Strategies

### Squash Merge (Recommended)

**When**: Feature branches → main

**Benefits**:
- Clean, linear history
- Each feature = one commit
- Easy to revert
- Simple history

**How**:
```bash
# GitHub: Use "Squash and merge" button
# CLI:
git merge --squash 001-feature
git commit -m "feat: add user authentication"
```

### Merge Commit

**When**: Release branches, hotfixes

**Benefits**:
- Preserves full history
- Shows branch points
- Useful for auditing

**How**:
```bash
git merge --no-ff release/v1.2.0
```

### Rebase

**When**: Updating feature branch with main

**Benefits**:
- Linear history
- No merge commits
- Clean log

**How**:
```bash
git checkout 001-feature
git rebase main
```

**Warning**: Never rebase public/shared branches

---

## Branch Lifecycle

### Feature Branch Lifecycle

```
1. CREATE (with user approval, Principle VI)
   └─ git checkout -b 001-feature main

2. DEVELOP
   └─ Write tests → Implement → Commit → Push

3. SYNC (daily)
   └─ git fetch && git rebase origin/main

4. REVIEW
   └─ Create PR → Address feedback → Approval

5. MERGE
   └─ Squash merge to main

6. DELETE
   └─ git branch -d 001-feature
   └─ git push origin --delete 001-feature

7. DEPLOY
   └─ main auto-deploys or manual trigger
```

**Typical Duration**: 1-7 days

### Stale Branch Policy

**Definition**: Branch with no commits for >14 days

**Policy**:
- Automated reminder at 14 days
- Automated closure warning at 21 days
- Automated closure at 28 days (with notification)

**Developer Responsibility**:
- Keep branches active (commit/sync regularly)
- Close unused branches
- Finish or abandon work

---

## Constitutional Compliance

### Principle VI: Git Operation Approval

**CRITICAL**: No autonomous Git operations without user approval

**Applies to**:
- Branch creation
- Branch deletion
- Commits
- Pushes
- Merges
- Rebases

**Implementation**:
```bash
# ❌ BAD: Automatic branch creation
git checkout -b auto-branch

# ✅ GOOD: Request approval first
echo "Create branch 001-feature? (y/n)"
read approval
if [ "$approval" = "y" ]; then
  git checkout -b 001-feature main
fi
```

**Scripts**: All automation scripts must request approval before git operations

### Framework Branch Creation

When user invokes a feature-bootstrapping command (`/create-prd`, `/swarm explore`, or `/specification`):

1. **Ask user**: "Would you like to create a new feature branch?"
2. **If yes**, ask: "What branch name format? (feature-name for the vision/PRD/plan pack, ###-feature-name for the SDD waterfall pack)"
3. **User approves**: Create branch
4. **User denies**: Use current branch

**No Assumption**: Never assume permission for git operations

---

## Best Practices

### DO

- ✅ Create feature branch for every feature/bug
- ✅ Keep branches short-lived (≤7 days)
- ✅ Sync with main daily
- ✅ Write descriptive commit messages
- ✅ Delete branches after merge
- ✅ Use PR for all changes to main
- ✅ Follow naming conventions
- ✅ Request git approval (Principle VI)

### DON'T

- ❌ Commit directly to main
- ❌ Force push to shared branches
- ❌ Keep stale branches
- ❌ Use vague branch names
- ❌ Mix multiple features in one branch
- ❌ Commit secrets or credentials
- ❌ Skip testing before PR
- ❌ Perform autonomous git operations

---

## Troubleshooting

### Merge Conflicts

**When**: Merging or rebasing with conflicting changes

**Resolution**:
```bash
# 1. Update your branch
git fetch origin
git rebase origin/main

# 2. Resolve conflicts in editor
# Edit conflicting files

# 3. Stage resolved files
git add conflicted-file.ts

# 4. Continue rebase
git rebase --continue

# 5. Push (may need force-with-lease)
git push --force-with-lease
```

### Diverged Branches

**When**: Local and remote have different histories

**Resolution**:
```bash
# Check status
git status

# Option 1: Pull with rebase (preferred)
git pull --rebase origin 001-feature

# Option 2: Force push (dangerous, use carefully)
git push --force-with-lease origin 001-feature
```

### Accidental Commit to Main

**When**: Committed to main instead of feature branch

**Resolution**:
```bash
# 1. Create feature branch at current commit
git branch 001-feature

# 2. Reset main to previous commit
git reset --hard origin/main

# 3. Switch to feature branch
git checkout 001-feature

# 4. Push feature branch
git push -u origin 001-feature
```

---

## Tools and Automation

### Branch Management Scripts

**List stale branches**:
```bash
git for-each-ref --sort=-committerdate refs/heads/ \
  --format='%(refname:short)|%(committerdate:relative)' \
  | awk -F'|' '$2 !~ /ago/ || $2 ~ /weeks ago|months ago/'
```

**Delete merged branches**:
```bash
git branch --merged main | grep -v "main" | xargs git branch -d
```

### Git Hooks

**Pre-commit** (validate commits):
```bash
#!/bin/sh
# .git/hooks/pre-commit

# Run linter
npm run lint || exit 1

# Check for secrets
if git diff --cached | grep -E '(API_KEY|SECRET|PASSWORD).*='; then
  echo "❌ Potential secret detected"
  exit 1
fi
```

**Pre-push** (validate tests):
```bash
#!/bin/sh
# .git/hooks/pre-push

# Run tests
npm test || exit 1
```

---

## Integration with LogicLoom Framework

### Vision/PRD/Plan Workflow Pack Flow

`/create-prd` and `/swarm explore` respect Principle VI:
1. User invokes: `/create-prd "User authentication feature"` (or `/swarm explore ...`)
2. System asks: "Create new feature branch?"
3. User approves: "Yes"
4. System asks: "Branch name? (suggest: user-authentication)"
5. User confirms: "user-authentication"
6. System creates: `git checkout -b user-authentication main`
7. System creates: `features/user-authentication/vision.md` (and later `plan.md`)

### SDD Waterfall Workflow Pack Flow

`/specification` respects Principle VI:
1. User invokes: `/specification "User authentication feature"`
2. System creates branch `001-user-authentication` and `specs/001-user-authentication/spec.md`

### Feature Directories

Branch name matches feature directory:
```
Vision/PRD/Plan pack:
Branch: user-authentication
Features: features/user-authentication/
          ├── vision.md
          ├── plan.md
          └── retro.md

SDD waterfall pack:
Branch: 001-user-authentication
Specs:  specs/001-user-authentication/
        ├── spec.md
        ├── plan.md
        ├── tasks.md
        └── contracts/
```

---

## Metrics

Track these branching metrics:

- Branch lifetime (average)
- Stale branches (count)
- Merge conflicts (frequency)
- Time to merge (PR creation → merge)
- Branch naming compliance
- Direct pushes to main (should be 0)

---

## References

- Constitution v3.1.0: `.logic-loom/memory/constitution.md` (Principle VI)
- Code Review Policy: `.docs/policies/code-review-policy.md`
- Deployment Policy: `.docs/policies/deployment-policy.md`
- Release Management: `.docs/policies/release-management-policy.md`
- Conventional Commits: https://www.conventionalcommits.org/
- Git Flow: https://nvie.com/posts/a-successful-git-branching-model/
- GitHub Flow: https://guides.github.com/introduction/flow/

---

**Policy Owner**: Architecture Department
**Last Reviewed**: 2025-11-07
**Next Review**: 2026-02-07
