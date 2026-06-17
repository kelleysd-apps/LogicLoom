# Release Management Policy

**Version**: 1.0.0
**Effective Date**: TBD
**Authority**: Constitution v3.1.0 - Principle VIII (Documentation Synchronization)
**Review Cycle**: Quarterly

---

## Purpose

This policy establishes release standards, versioning, and procedures for the LogicLoom framework, ensuring predictable, well-documented, and traceable releases following constitutional principles.

---

## Constitutional Alignment

This policy enforces:
- **Principle VIII**: Documentation Synchronization - All releases fully documented
- **Principle VI**: Git Operation Approval - No autonomous release tagging
- **Principle VII**: Observability - All releases logged and traced
- **All Principles**: Releases validate constitutional compliance

---

## Scope

All software releases from repositories using the LogicLoom framework must follow this policy, including:
- Application releases
- Library releases
- Framework releases
- API releases

---

## Semantic Versioning

### Version Format

Follow **Semantic Versioning 2.0.0** (semver):

```
{major}.{minor}.{patch}[-{pre-release}][+{build-metadata}]
```

**Examples**:
- `1.0.0` - Major release
- `1.2.3` - Minor with patches
- `2.0.0-beta.1` - Pre-release
- `1.0.0+20251107` - With build metadata

### Version Components

#### Major (X.0.0)

**When to increment**:
- Breaking changes (API incompatibilities)
- Removed functionality
- Major architectural changes
- Incompatible dependency updates

**Examples**:
- `1.x.x → 2.0.0`: Removed old authentication API
- `2.x.x → 3.0.0`: Changed database schema (breaking)

**Impact**: Users must update code to migrate

#### Minor (x.Y.0)

**When to increment**:
- New features (backward compatible)
- New functionality added
- Deprecations (but not removals)
- Performance improvements

**Examples**:
- `1.0.x → 1.1.0`: Added user profile feature
- `1.1.x → 1.2.0`: Added API pagination

**Impact**: Users can upgrade without code changes

#### Patch (x.y.Z)

**When to increment**:
- Bug fixes (backward compatible)
- Security patches
- Documentation fixes
- Internal refactoring

**Examples**:
- `1.2.0 → 1.2.1`: Fixed password reset bug
- `1.2.1 → 1.2.2`: Security patch for XSS

**Impact**: Users should upgrade (no changes needed)

### Pre-release Versions

**Format**: `{version}-{identifier}.{number}`

**Types**:
- `alpha`: Early testing (unstable, incomplete)
- `beta`: Feature complete, testing for bugs
- `rc`: Release candidate (final testing)

**Examples**:
- `2.0.0-alpha.1` - First alpha
- `2.0.0-beta.2` - Second beta
- `2.0.0-rc.1` - Release candidate

**Ordering**:
```
1.0.0-alpha.1 < 1.0.0-alpha.2 < 1.0.0-beta.1 < 1.0.0-beta.2 < 1.0.0-rc.1 < 1.0.0
```

### Build Metadata

**Format**: `{version}+{metadata}`

**Examples**:
- `1.0.0+20251107` - Date
- `1.0.0+sha.5114f85` - Git commit
- `1.0.0+build.123` - Build number

**Note**: Build metadata DOES NOT affect version precedence

---

## Release Types

### Stable Release

**Definition**: Production-ready, fully tested release

**Versioning**: `X.Y.Z` (no pre-release identifier)

**Requirements**:
- All tests pass (unit, integration, E2E)
- Security scan clear
- Performance benchmarks met
- Documentation complete
- Migration guide (if major)
- Deployed to staging for ≥48 hours
- Team approval

**Frequency**: As needed (recommended: monthly for minor, quarterly for major)

### Pre-release

**Definition**: Not production-ready, for testing purposes

**Versioning**: `X.Y.Z-{alpha|beta|rc}.N`

**Requirements**:
- Tests pass
- Documented known issues
- Clear "do not use in production" warning
- Feedback mechanism provided

**Purpose**:
- Get early feedback
- Test in production-like environments
- Validate breaking changes

### Hotfix Release

**Definition**: Emergency patch for critical production issues

**Versioning**: Increment patch: `X.Y.Z → X.Y.(Z+1)`

**Requirements**:
- Fix critical bug only (minimal changes)
- Tests for the bug
- Expedited review process
- Deployed within hours

**Example**: `1.2.3` (has critical bug) → `1.2.4` (hotfix)

---

## Release Workflow

### Step 1: Release Planning

**Determine release type**:
- Major: Breaking changes or major features
- Minor: New features (backward compatible)
- Patch: Bug fixes only

**Create release proposal**:
```markdown
# Release Proposal: v1.2.0

## Type: Minor

## Target Date: 2025-11-15

## Included Features:
- #42: User authentication
- #55: API pagination
- #67: Email notifications

## Breaking Changes: None

## Migration Required: No

## Dependencies:
- Upgrade bcrypt to v5.1.0
- Add nodemailer dependency

## Testing Plan:
- Unit tests: All pass
- Integration tests: All pass
- E2E tests: Critical flows
- Performance: Load test with 1000 concurrent users

## Documentation:
- API docs updated
- CHANGELOG updated
- Migration guide (N/A)

## Approvals:
- [ ] Team lead
- [ ] Architect (if major)
```

### Step 2: Release Preparation

**Create release branch** (if using Git Flow):
```bash
git checkout -b release/v1.2.0 develop
```

**Version bump**:
```bash
npm version minor  # 1.1.5 → 1.2.0
```

**Update CHANGELOG.md**:
```markdown
# Changelog

## [1.2.0] - 2025-11-15

### Added
- User authentication with JWT (#42)
- API pagination for all list endpoints (#55)
- Email notification system (#67)

### Changed
- Updated bcrypt to v5.1.0

### Deprecated
- Old authentication method (will be removed in v2.0.0)

### Fixed
- None

### Security
- Patched XSS vulnerability in user input
```

**Update documentation**:
- API documentation
- User guides
- README (if needed)
- Migration guides (if breaking changes)

### Step 3: Release Testing

**Test in staging**:
```bash
# Deploy to staging
deploy-to-staging release/v1.2.0

# Run full test suite
npm run test:all

# Run E2E tests
npm run test:e2e

# Run performance tests
npm run test:performance

# Manual testing
- Test critical user flows
- Test new features
- Test edge cases
```

**Minimum staging duration**:
- Patch: 4 hours
- Minor: 24 hours
- Major: 48 hours

### Step 4: Release Approval

**Approval requirements**:

| Release Type | Approvers | Notice |
|--------------|-----------|--------|
| Patch | 1 (team lead) | 4 hours |
| Minor | 1 (team lead) | 24 hours |
| Major | 2 (lead + architect) | 48 hours |
| Breaking | Team consensus | 1 week |

**Approval checklist**:
- [ ] All tests pass
- [ ] Staging deployment successful
- [ ] Documentation updated
- [ ] CHANGELOG updated
- [ ] No critical bugs
- [ ] Team notified
- [ ] Release notes prepared

### Step 5: Release Execution

**Merge to main**:
```bash
# Merge release branch to main
git checkout main
git merge --no-ff release/v1.2.0
```

**Tag release**:
```bash
# Create annotated tag
git tag -a v1.2.0 -m "Release v1.2.0

- User authentication with JWT
- API pagination
- Email notifications

See CHANGELOG.md for full details."

# Push tag
git push origin v1.2.0
```

**Merge back to develop** (if using Git Flow):
```bash
git checkout develop
git merge --no-ff release/v1.2.0
git push origin develop
```

**Delete release branch**:
```bash
git branch -d release/v1.2.0
git push origin --delete release/v1.2.0
```

### Step 6: Release Deployment

**Deploy to production**:
```bash
# Deploy tagged version
deploy-to-production v1.2.0
```

**Verify deployment**:
- Health checks pass
- Smoke tests pass
- No error spikes
- Key metrics normal

### Step 7: Release Communication

**Create GitHub Release**:
```bash
gh release create v1.2.0 \
  --title "v1.2.0 - User Authentication & Pagination" \
  --notes-file release-notes/v1.2.0.md
```

**Release notes template**:
```markdown
# v1.2.0 - User Authentication & Pagination

Released: 2025-11-15

## ✨ New Features

### User Authentication
Added JWT-based authentication system. Users can now:
- Register with email and password
- Log in and receive access tokens
- Reset forgotten passwords

See [Authentication Guide](docs/auth.md) for details.

### API Pagination
All list endpoints now support pagination:
```
GET /api/users?page=1&limit=20
```

## 🔧 Improvements

- Performance: Reduced API response time by 30%
- Security: Updated bcrypt to v5.1.0

## 📚 Documentation

- [Authentication Guide](docs/auth.md)
- [Pagination Guide](docs/pagination.md)
- [Migration Guide](docs/migration/v1.2.0.md) (not required)

## 🔗 Links

- [Full Changelog](CHANGELOG.md)
- [Documentation](https://docs.example.com)
- [Release Milestone](https://github.com/org/repo/milestone/5)

## 📦 Installation

```bash
npm install package@1.2.0
```

## 🙏 Contributors

- @developer1 (#42, #55)
- @developer2 (#67)
```

**Announce release**:
- Team chat/Slack
- Mailing list (if applicable)
- Social media (if public)
- Status page

### Step 8: Post-Release

**Monitor**:
- First 1 hour: Intensive monitoring
- First 24 hours: Regular checks
- First week: Daily review

**Collect feedback**:
- Bug reports
- Feature requests
- Performance issues
- User feedback

**Post-release review** (within 1 week):
- What went well?
- What went wrong?
- How to improve?
- Update process

---

## Release Artifacts

### Required Artifacts

1. **Git Tag**:
   - Annotated tag (not lightweight)
   - Version number (v1.2.0)
   - Release notes in tag message

2. **GitHub Release**:
   - Title and description
   - Release notes
   - Binary assets (if applicable)
   - Checksum file

3. **CHANGELOG.md**:
   - Version and date
   - All changes documented
   - Links to issues/PRs

4. **Documentation**:
   - Updated API docs
   - Updated user guides
   - Migration guide (if major)

5. **Build Artifacts** (if applicable):
   - Compiled binaries
   - Docker images
   - NPM packages
   - Checksums

### Optional Artifacts

- Release announcement blog post
- Demo video
- Updated screenshots
- Marketing materials

---

## Versioning Strategies

### Libraries and Frameworks

**Strategy**: Strict semver

**Rationale**: Libraries are dependencies; breaking changes impact users

**Rules**:
- Major: Any breaking change
- Minor: New features, deprecations
- Patch: Bug fixes only

**Example**: LogicLoom framework itself follows this

### Applications

**Strategy**: Calendar versioning or semver

**Rationale**: Apps don't have API consumers; flexibility acceptable

**Options**:
- Semver: `1.2.3`
- CalVer: `2025.11.0` (year.month.patch)
- Incremental: `build-1234`

**Choose based on**: Release frequency, team preference

### APIs

**Strategy**: Semver with API version in URL

**Rationale**: Multiple versions coexist

**Example**:
- API v1: `api.example.com/v1/users` (stable: v1.5.2)
- API v2: `api.example.com/v2/users` (beta: v2.0.0-beta.3)

**Rule**: Major version in URL, full semver for implementation

---

## Deprecation Policy

### Deprecation Process

1. **Announce** deprecation in release notes
2. **Mark** deprecated in code (with comments/annotations)
3. **Warn** users (console warnings, logs)
4. **Wait** for deprecation period
5. **Remove** in next major version

### Deprecation Period

| Change Type | Minimum Period |
|-------------|----------------|
| Minor feature | 1 minor version |
| Major feature | 2 minor versions (6 months) |
| Core API | 1 major version (1 year) |

### Example

```typescript
/**
 * @deprecated since v1.2.0, will be removed in v2.0.0
 * Use newMethod() instead
 */
function oldMethod() {
  console.warn('oldMethod is deprecated, use newMethod instead');
  // implementation
}
```

**Timeline**:
- v1.0.0: oldMethod exists
- v1.2.0: oldMethod deprecated, newMethod added
- v2.0.0: oldMethod removed

---

## Changelog Management

### Format

Follow **Keep a Changelog** format:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Feature in progress

## [1.2.0] - 2025-11-15

### Added
- User authentication with JWT (#42)
- API pagination (#55)

### Changed
- Updated bcrypt dependency

### Deprecated
- Old auth method (use JWT instead)

### Removed
- None

### Fixed
- Password reset email bug (#88)

### Security
- Patched XSS vulnerability

## [1.1.0] - 2025-10-15
...
```

### Categories

- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security fixes

---

## Release Checklist

### Pre-Release

- [ ] All features merged to develop/main
- [ ] Version number determined
- [ ] CHANGELOG.md updated
- [ ] Documentation updated
- [ ] Migration guide created (if major)
- [ ] Tests pass (unit, integration, E2E)
- [ ] Security scan clear
- [ ] Performance benchmarks met

### Release

- [ ] Release branch created (if using Git Flow)
- [ ] Version bumped in package.json/pyproject.toml
- [ ] Release tested in staging
- [ ] Approval obtained
- [ ] Release branch merged to main
- [ ] Git tag created
- [ ] GitHub release created
- [ ] Deployed to production
- [ ] Smoke tests pass

### Post-Release

- [ ] Release announced
- [ ] Documentation published
- [ ] Release branch deleted
- [ ] Monitoring verified
- [ ] Feedback collected
- [ ] Post-release review scheduled

---

## Hotfix Procedure

### Emergency Hotfix

**When**: Critical production bug

**Process** (expedited):

```bash
# 1. Create hotfix branch from main
git checkout -b hotfix/critical-bug main

# 2. Fix the bug (minimal changes)
git commit -m "fix: critical bug description"

# 3. Bump patch version
npm version patch  # 1.2.0 → 1.2.1

# 4. Test (abbreviated)
npm test

# 5. Merge to main
git checkout main
git merge --no-ff hotfix/critical-bug

# 6. Tag
git tag -a v1.2.1 -m "Hotfix v1.2.1 - Critical bug fix"
git push origin v1.2.1

# 7. Merge to develop
git checkout develop
git merge --no-ff hotfix/critical-bug

# 8. Deploy immediately
deploy-to-production v1.2.1

# 9. Announce
announce-hotfix v1.2.1

# 10. Delete hotfix branch
git branch -d hotfix/critical-bug
```

**Timeline**: ≤3 hours from bug detection to deployment

---

## Release Metrics

### Track These Metrics

- Release frequency
- Lead time (feature complete → released)
- Hotfix frequency
- Rollback rate
- Time to deploy
- Adoption rate (for libraries)

### Targets

| Metric | Target |
|--------|--------|
| Release frequency | Monthly (minor), Quarterly (major) |
| Lead time | <1 week |
| Hotfix rate | <5% of releases |
| Rollback rate | <2% |
| Time to deploy | <30 minutes |

---

## Tools

### Version Management

- **npm version**: Auto-update package.json and create git tag
- **semantic-release**: Automated version management and release

### Release Automation

- **GitHub Actions**: Automate release workflow
- **gh cli**: Create releases from command line

### Changelog Generation

- **conventional-changelog**: Generate CHANGELOG from commit messages
- **release-please**: Automated releases and changelogs

---

## References

- Constitution v3.1.0: `.logic-loom/memory/constitution.md`
- Semantic Versioning: https://semver.org/
- Keep a Changelog: https://keepachangelog.com/
- Conventional Commits: https://www.conventionalcommits.org/
- Deployment Policy: `.docs/policies/deployment-policy.md`
- Branching Strategy: `.docs/policies/branching-strategy-policy.md`

---

**Policy Owner**: Product Department
**Last Reviewed**: TBD
**Next Review**: TBD
