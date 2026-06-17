# Code Review Policy

**Version**: 1.0.0
**Effective Date**: TBD
**Authority**: Constitution v3.2.0 - Principle VIII (Documentation Synchronization)
**Review Cycle**: Quarterly

---

## Purpose

This policy establishes standards and procedures for code review within the LogicLoom framework, ensuring all code changes meet quality, security, and constitutional compliance requirements before merging.

---

## Constitutional Alignment

This policy enforces:
- **Principle II**: Test-First Development - Reviews verify tests exist
- **Principle III**: Contract-First Design - Reviews check contract compliance
- **Principle VI**: Git Operation Approval - Reviews gate all merges
- **Principle VIII**: Documentation Synchronization - Reviews verify docs updated
- **Principle XI**: Input Validation & Output Sanitization - Reviews check security

---

## Scope

All code changes require review before merging to main branches, including:
- Feature implementations
- Bug fixes
- Refactoring
- Documentation updates
- Configuration changes
- Dependency updates

**Exceptions**: None. All changes require review.

---

## Review Requirements

### Minimum Reviewers

| Change Type | Minimum Reviewers | Special Requirements |
|-------------|------------------|---------------------|
| Feature code | 1 | Must include domain expert |
| Bug fix | 1 | Original author if available |
| Refactoring | 1 | Architect review if major |
| Security-related | 2 | security-operations skill or quality-assessor agent |
| Infrastructure | 1 | monitoring skill or framework-sync-agent |
| Breaking change | 2 | Team consensus required |

### Reviewer Qualifications

Reviewers must:
- ✅ Have domain expertise in the changed area
- ✅ Understand the constitutional principles
- ✅ Be familiar with the project codebase
- ✅ Not be the original author (no self-approval)

---

## Review Checklist

### Constitutional Compliance

- [ ] **Principle I**: Is feature implemented as standalone library?
- [ ] **Principle II**: Are tests written first and passing?
- [ ] **Principle III**: Are contracts defined and followed?
- [ ] **Principle VI**: No unapproved git operations in scripts?
- [ ] **Principle VII**: Are operations observable with logs?
- [ ] **Principle VIII**: Is documentation updated alongside code?
- [ ] **Principle IX**: Are dependencies declared and pinned?
- [ ] **Principle XI**: Is input validated and output sanitized?

### Code Quality

- [ ] **Readability**: Code is clear and self-documenting
- [ ] **Simplicity**: Follows YAGNI and progressive enhancement
- [ ] **DRY**: No unnecessary duplication
- [ ] **Naming**: Variables, functions, classes well-named
- [ ] **Comments**: Complex logic explained with comments
- [ ] **Formatting**: Consistent style (linter passing)

### Testing

- [ ] **Tests Exist**: Unit, integration, and/or E2E tests included
- [ ] **Tests Pass**: All tests passing in CI/CD
- [ ] **Coverage**: Code coverage meets threshold (≥80%)
- [ ] **Test Quality**: Tests are meaningful, not just for coverage
- [ ] **Edge Cases**: Edge cases and error paths tested

### Security

- [ ] **No Secrets**: No hardcoded credentials or API keys
- [ ] **Input Validation**: All user inputs validated
- [ ] **Output Encoding**: Outputs properly escaped/sanitized
- [ ] **Authz/Authn**: Authorization checks in place
- [ ] **Dependencies**: No known vulnerable dependencies
- [ ] **OWASP**: No OWASP Top 10 vulnerabilities introduced

### Performance

- [ ] **No Regressions**: Performance not degraded
- [ ] **Scalability**: Code scales with data/users
- [ ] **Resource Usage**: Memory/CPU usage reasonable
- [ ] **Database**: Queries optimized, indexes appropriate

### Documentation

- [ ] **README Updated**: If feature/API changes
- [ ] **API Docs**: Public APIs documented
- [ ] **Comments**: Complex algorithms explained
- [ ] **ADRs**: Architectural decisions recorded
- [ ] **Changelog**: CHANGELOG.md updated if applicable

---

## Review Process

### 1. Author Preparation

Before requesting review:
1. Run all tests locally (`npm test` or equivalent)
2. Run linter (`npm run lint`)
3. Run constitutional compliance check: `.logic-loom/scripts/bash/constitutional-check.sh`
4. Update documentation
5. Self-review changes
6. Write descriptive PR description

### 2. Review Request

Create pull request with:
- **Title**: Clear, concise description
- **Description**:
  - What changed and why
  - How to test
  - Screenshots (if UI changes)
  - Constitutional compliance notes
- **Reviewers**: Assign appropriate domain experts
- **Labels**: Add relevant labels (feature, bug, security, etc.)

### 3. Reviewer Responsibilities

Reviewers must:
1. Review within **24 hours** (or notify of delay)
2. Use review checklist above
3. Leave constructive, actionable feedback
4. Approve, request changes, or comment
5. Re-review after changes

### 4. Addressing Feedback

Authors must:
1. Respond to all comments
2. Make requested changes or explain why not
3. Request re-review after updates
4. Resolve conversations as addressed

### 5. Approval & Merge

Requirements for merge:
- ✅ All required approvals received
- ✅ All CI/CD checks passing
- ✅ All conversations resolved
- ✅ No merge conflicts
- ✅ Constitutional compliance verified

**Merge Strategy**: Squash merge preferred for feature branches

---

## Review Guidelines

### For Reviewers

**DO**:
- ✅ Be respectful and constructive
- ✅ Explain the "why" behind suggestions
- ✅ Praise good code
- ✅ Ask questions to understand intent
- ✅ Suggest alternatives, not just problems
- ✅ Focus on important issues first

**DON'T**:
- ❌ Nitpick style if linter handles it
- ❌ Block on personal preference (unless constitutional)
- ❌ Request changes without explanation
- ❌ Approve without actually reviewing
- ❌ Be condescending or rude

### For Authors

**DO**:
- ✅ Keep PRs small and focused
- ✅ Respond promptly to feedback
- ✅ Be open to suggestions
- ✅ Explain reasoning if disagreeing
- ✅ Test thoroughly before requesting review

**DON'T**:
- ❌ Submit huge PRs (>500 lines)
- ❌ Mix unrelated changes
- ❌ Get defensive about feedback
- ❌ Ignore comments
- ❌ Force push after review started

---

## Review Priorities

### P0: Blocking Issues (Must Fix)
- Constitutional violations
- Security vulnerabilities
- Breaking changes without migration
- Tests failing or missing
- Critical bugs

### P1: Important Issues (Should Fix)
- Performance regressions
- Poor error handling
- Missing documentation
- Code quality issues
- Incomplete test coverage

### P2: Nice to Have (Optional)
- Style improvements (if not automated)
- Refactoring opportunities
- Future enhancements
- Minor optimizations

---

## Special Review Types

### Security Review

For security-related changes:
1. **Mandatory**: security-operations skill or quality-assessor agent review
2. **Threat Model**: Document attack vectors
3. **Security Tests**: Include security-specific tests
4. **Penetration Test**: For major changes
5. **Compliance**: Verify OWASP compliance

### Architectural Review

For significant architectural changes:
1. **ADR Required**: Architectural Decision Record
2. **Team Discussion**: Synchronous meeting
3. **Consensus**: Agreement from architects
4. **Migration Plan**: For breaking changes
5. **Rollback Plan**: How to revert if needed

### Dependency Review

For dependency updates:
1. **Justification**: Why is update needed?
2. **Security Audit**: No known vulnerabilities
3. **License Check**: Compatible licenses
4. **Breaking Changes**: Review changelog
5. **Testing**: Comprehensive testing after update

---

## Review Tools

### Automated Checks

Required before review:
- **Linting**: ESLint, Prettier, or equivalent
- **Tests**: All tests must pass
- **Coverage**: Code coverage threshold
- **Security Scan**: Dependency vulnerability check
- **Constitutional Check**: `.logic-loom/scripts/bash/constitutional-check.sh`

### Review Aids

Use these tools to assist review:
- **GitHub PR**: For code review interface
- **Constitutional Check**: Automated principle verification
- **Spec Validation**: For specification changes
- **Plan Validation**: For implementation plan changes
- **Task Validation**: For task list changes

---

## Metrics & Tracking

Track the following metrics:
- **Review Time**: Time from PR creation to first review
- **Merge Time**: Time from PR creation to merge
- **Review Rounds**: Number of review cycles
- **Approval Rate**: Percentage approved without changes
- **Defect Escape**: Bugs found in code review vs production

**Targets**:
- First review within 24 hours
- Merge within 3 business days
- ≥95% test coverage on new code
- Zero critical security issues

---

## Escalation

If review blocked or contentious:
1. **Discussion**: Schedule synchronous discussion
2. **Mediation**: Involve team lead or architect
3. **Decision**: Team consensus or lead decision
4. **Document**: Record decision and reasoning

---

## Exceptions

### Emergency Hotfixes

For production-critical bugs:
- Single reviewer acceptable
- Merge immediately after approval
- Post-merge review within 24 hours
- Retrospective required

### Documentation-Only Changes

For pure documentation updates:
- Single reviewer acceptable
- Faster approval acceptable
- Focus on accuracy and clarity

---

## Continuous Improvement

This policy is reviewed quarterly. Suggest improvements via:
1. Team retrospectives
2. PR to this policy document
3. Discussion in team meetings

---

## Appendix A: Review Comment Templates

### Blocking Issue
```
🚨 BLOCKING: [Issue description]

Constitutional Principle: [Principle number and name]

Required Action: [Specific fix needed]

Why: [Explanation]
```

### Suggestion
```
💡 SUGGESTION: [Suggestion description]

Consider: [Alternative approach]

Benefits: [Why this is better]
```

### Question
```
❓ QUESTION: [Question]

Context: [Why you're asking]
```

### Praise
```
✅ NICE: [What's good]

Why: [Specific reason]
```

---

## References

- Constitution v3.2.0: `.logic-loom/memory/constitution.md`
- Testing domain brief: `plugins/loom-governance/domain-briefs/testing.md` (via `get_domain_brief testing`)
- Security domain brief: `plugins/loom-governance/domain-briefs/security.md` (via `get_domain_brief security`)
- Quality Assessor Agent: `plugins/sdd-specification/agents/quality-assessor.md`

---

**Policy Owner**: Architecture Department
**Last Reviewed**: TBD
**Next Review**: TBD
