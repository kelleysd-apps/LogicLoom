# Deployment Policy

**Version**: 1.0.0
**Effective Date**: 2025-11-07
**Authority**: Constitution v3.0.0 - Principle VII (Observability)
**Review Cycle**: Quarterly

---

## Purpose

This policy establishes deployment standards, procedures, and safeguards for the SDD Framework, ensuring reliable, observable, and reversible deployments following constitutional principles.

---

## Constitutional Alignment

This policy enforces:
- **Principle IV**: Idempotent Operations - Deployments are repeatable and safe
- **Principle V**: Progressive Enhancement - Gradual rollout and feature flags
- **Principle VI**: Git Operation Approval - No autonomous deployments
- **Principle VII**: Observability - All deployments logged and monitored
- **Principle IX**: Dependency Management - Dependencies declared and verified

---

## Scope

All deployments to production and production-like environments must follow this policy, including:
- Application code deployments
- Infrastructure changes
- Database migrations
- Configuration updates
- Dependency updates
- Hotfixes and patches

---

## Deployment Principles

### 1. Zero-Downtime Deployments

**Requirement**: Deployments must not cause service interruptions

**Strategies**:
- Blue-green deployments
- Rolling deployments
- Canary deployments
- Feature flags for new functionality

### 2. Automated Deployments

**Requirement**: Manual deployments are discouraged; automation is preferred

**Benefits**:
- Consistency and repeatability
- Reduced human error
- Faster deployment cycles
- Clear audit trail

### 3. Rollback Capability

**Requirement**: Every deployment must have a rollback plan

**Requirements**:
- Rollback procedure documented
- Rollback tested in staging
- Rollback executable within 5 minutes
- Database migrations reversible

### 4. Progressive Rollout

**Requirement**: New versions deployed gradually, not all-at-once

**Stages**:
1. Development environment
2. Staging environment
3. Production canary (1-5% traffic)
4. Production partial (25% traffic)
5. Production full (100% traffic)

---

## Deployment Environments

### Development (dev)

**Purpose**: Active development and testing

**Characteristics**:
- Frequent deployments (multiple per day)
- May be unstable
- Uses development dependencies
- Debug mode enabled
- No user data

**Deployment**: Automatic on push to `develop` branch

### Staging (staging)

**Purpose**: Pre-production verification

**Characteristics**:
- Production-like configuration
- Production-like data (anonymized)
- Performance testing
- User acceptance testing
- Integration testing

**Deployment**: Automatic on push to `staging` branch

**Requirements**:
- All tests pass
- Performance benchmarks meet targets
- Security scan passes

### Production (prod)

**Purpose**: Live user-facing environment

**Characteristics**:
- Stable releases only
- Real user data
- High availability
- Full monitoring
- Disaster recovery

**Deployment**: Manual trigger after approval

**Requirements**:
- Staging deployment successful for ≥24 hours
- All smoke tests pass
- Team approval obtained
- Rollback plan documented
- Runbook updated

---

## Deployment Workflow

### Step 1: Pre-Deployment Checks

**Required Checks**:
- [ ] All tests passing (unit, integration, E2E)
- [ ] Code review approved
- [ ] Security scan clear
- [ ] Performance benchmarks acceptable
- [ ] Database migration tested
- [ ] Rollback plan documented
- [ ] Deployment runbook updated

**Automated Checks** (CI/CD):
```yaml
pre-deployment:
  - run: npm test
  - run: npm run lint
  - run: npm audit
  - run: npm run build
  - run: npm run test:e2e
```

### Step 2: Deployment Approval

**Approval Requirements**:

| Deployment Type | Approvers Required | Notice Period |
|----------------|-------------------|---------------|
| Hotfix | 1 (on-call engineer) | Immediate |
| Minor release | 1 (team lead) | 4 hours |
| Major release | 2 (team lead + architect) | 24 hours |
| Breaking change | Team consensus | 48 hours |

**Approval Process**:
1. Create deployment request (ticket/issue)
2. Notify required approvers
3. Wait for approval
4. Proceed with deployment

### Step 3: Database Migrations

**If database changes required**:

1. **Create Migration**:
   ```bash
   npm run migration:create -- add_users_table
   ```

2. **Test Migration** (staging):
   ```bash
   npm run migration:up    # Apply
   npm run migration:down  # Rollback
   npm run migration:up    # Re-apply
   ```

3. **Backup Production Database**:
   ```bash
   pg_dump production > backup_$(date +%Y%m%d_%H%M%S).sql
   ```

4. **Run Migration** (production):
   ```bash
   npm run migration:up
   ```

**Migration Requirements**:
- Migrations are reversible
- Migrations are idempotent
- Migrations tested in staging
- Database backed up before migration

### Step 4: Deployment Execution

**Blue-Green Deployment** (Recommended):
```bash
# 1. Deploy to green environment
deploy-to-environment green

# 2. Run smoke tests on green
run-smoke-tests green

# 3. Switch traffic to green
switch-traffic blue -> green

# 4. Monitor for 10 minutes
monitor-health-checks

# 5. If healthy: decommission blue
# 6. If issues: switch back to blue (rollback)
```

**Rolling Deployment** (Alternative):
```bash
# 1. Deploy to 1 instance
deploy-to-instance instance-1

# 2. Health check
if healthy:
  # 3. Deploy to remaining instances gradually
  deploy-to-instance instance-2
  deploy-to-instance instance-3
  # ...
```

**Canary Deployment** (New features):
```bash
# 1. Deploy canary with feature flag
deploy-canary --feature-flag=new_feature

# 2. Route 5% traffic to canary
set-traffic-split canary=5% stable=95%

# 3. Monitor metrics for 1 hour
monitor-canary-metrics

# 4. If healthy: gradually increase
set-traffic-split canary=25% stable=75%
set-traffic-split canary=50% stable=50%
set-traffic-split canary=100% stable=0%

# 5. If issues: rollback
set-traffic-split canary=0% stable=100%
```

### Step 5: Post-Deployment Verification

**Smoke Tests** (Must pass):
- [ ] Application starts successfully
- [ ] Health check endpoint returns 200
- [ ] Database connection established
- [ ] Critical user flows work (login, core features)
- [ ] No error spikes in logs

**Monitoring Checks** (First 10 minutes):
- [ ] Error rate < baseline + 10%
- [ ] Response time < baseline + 20%
- [ ] CPU/Memory within normal range
- [ ] No database connection errors
- [ ] No 5xx errors

**If Issues Detected**:
1. Execute rollback immediately
2. Investigate root cause
3. Fix issue
4. Re-test in staging
5. Retry deployment

### Step 6: Deployment Communication

**Announce Deployment**:
```markdown
📢 Deployment Announcement

Environment: Production
Version: v1.2.3
Deployed By: [Name]
Deployed At: 2025-11-07 14:30 UTC

Changes:
- Added user profile feature
- Fixed password reset bug
- Updated dependencies

Rollback Plan: Documented in runbook
Monitoring: https://monitoring-dashboard-link

Status: ✅ Healthy
```

**Communication Channels**:
- Team Slack/chat
- Status page (if user-facing)
- Deployment log/dashboard

---

## Rollback Procedures

### When to Rollback

Rollback immediately if:
- Error rate > baseline + 50%
- Response time > baseline + 100%
- Critical feature broken
- Data corruption detected
- Security vulnerability exposed

### Rollback Execution

**Application Rollback**:
```bash
# Blue-Green: Switch traffic back
switch-traffic green -> blue

# Rolling: Deploy previous version
deploy-version v1.2.2

# Canary: Route to stable
set-traffic-split canary=0% stable=100%
```

**Database Rollback**:
```bash
# Run down migration
npm run migration:down

# Or restore from backup (if migration not reversible)
psql production < backup_20251107_143000.sql
```

**Rollback Timeline**:
- Decision: Within 2 minutes of issue detection
- Execution: Within 5 minutes of decision
- Verification: Within 3 minutes of execution
- Total: ≤10 minutes from detection to stable

### Post-Rollback

After rollback:
1. **Announce**: Notify team and users of rollback
2. **Investigate**: Root cause analysis
3. **Fix**: Address the issue
4. **Test**: Verify fix in staging
5. **Document**: Update runbook with learnings
6. **Retry**: Schedule new deployment

---

## Feature Flags

### Purpose

Feature flags enable:
- Gradual rollout to subset of users
- A/B testing
- Quick disabling of problematic features
- Decoupling deployment from release

### Implementation

```typescript
// Feature flag configuration
const featureFlags = {
  newUserProfile: {
    enabled: true,
    rollout: 25, // 25% of users
    environments: ['staging', 'production']
  }
};

// Usage in code
if (featureFlags.isEnabled('newUserProfile', user)) {
  // Show new profile
} else {
  // Show old profile
}
```

### Feature Flag Management

**Best Practices**:
- Default to disabled for new features
- Start with small rollout percentage
- Monitor metrics during rollout
- Remove flags after full rollout
- Don't accumulate technical debt (clean up flags)

**Flag Lifecycle**:
1. Create flag (disabled, 0% rollout)
2. Enable in staging
3. Enable in production (5% → 25% → 50% → 100%)
4. Remove flag after stable

---

## Deployment Checklist

### Pre-Deployment

- [ ] All pre-deployment checks passed
- [ ] Approvals obtained
- [ ] Rollback plan documented
- [ ] Runbook updated
- [ ] Team notified of deployment window
- [ ] Monitoring dashboards open
- [ ] On-call engineer available

### During Deployment

- [ ] Database backup created (if DB changes)
- [ ] Migration executed successfully (if applicable)
- [ ] Application deployed to environment
- [ ] Smoke tests executed and passed
- [ ] Health checks passing
- [ ] No error spikes

### Post-Deployment

- [ ] Deployment announced
- [ ] Monitoring checked (10 minutes)
- [ ] User-facing features verified
- [ ] Documentation updated
- [ ] Deployment ticket closed
- [ ] Post-deployment review scheduled (if issues)

---

## Monitoring and Observability

### Required Metrics

**Application Metrics**:
- Request rate
- Error rate
- Response time (p50, p95, p99)
- Throughput

**System Metrics**:
- CPU usage
- Memory usage
- Disk I/O
- Network I/O

**Business Metrics**:
- User signups
- Active users
- Core feature usage
- Conversion rates

### Alerting

**Critical Alerts** (Page on-call):
- Error rate > 10%
- Response time > 5s (p95)
- Service down
- Database connection errors

**Warning Alerts** (Notify team):
- Error rate > 5%
- Response time > 2s (p95)
- CPU/Memory > 80%
- Disk space < 20%

### Logging

**Log All Deployments**:
```json
{
  "event": "deployment",
  "version": "v1.2.3",
  "environment": "production",
  "deployed_by": "engineer@example.com",
  "deployed_at": "2025-11-07T14:30:00Z",
  "status": "success",
  "duration_seconds": 45,
  "rollback": false
}
```

**Log Levels**:
- ERROR: Deployment failures
- WARN: Rollbacks, retries
- INFO: Successful deployments
- DEBUG: Detailed deployment steps

---

## Emergency Procedures

### Hotfix Deployment

**When Needed**:
- Critical production bug
- Security vulnerability
- Data corruption

**Fast-Track Process**:
1. Create hotfix branch from `main`
2. Implement minimal fix
3. Test in staging (abbreviated)
4. Get single approval (on-call engineer)
5. Deploy immediately
6. Monitor closely
7. Post-mortem within 24 hours

**Hotfix Timeline**:
- Fix development: ≤2 hours
- Testing: ≤30 minutes
- Approval: ≤15 minutes
- Deployment: ≤10 minutes
- Total: ≤3 hours

### Disaster Recovery

**Scenarios**:
- Complete service outage
- Data loss
- Infrastructure failure

**Recovery Procedure**:
1. **Assess**: Determine scope and impact
2. **Communicate**: Notify users and team
3. **Restore**: From most recent backup
4. **Verify**: Data integrity and service health
5. **Post-Mortem**: Root cause and prevention

**Recovery Time Objectives**:
- RTO (Recovery Time Objective): 1 hour
- RPO (Recovery Point Objective): 15 minutes

---

## Deployment Automation (CI/CD)

### Continuous Integration

**Trigger**: On every push to any branch

**Pipeline**:
```yaml
ci:
  - checkout code
  - install dependencies
  - run linter
  - run unit tests
  - run integration tests
  - build artifacts
  - security scan
  - publish artifacts
```

### Continuous Deployment

**Development** (Automatic):
```yaml
deploy-dev:
  trigger: push to develop branch
  steps:
    - run CI pipeline
    - deploy to dev environment
    - run smoke tests
```

**Staging** (Automatic):
```yaml
deploy-staging:
  trigger: push to staging branch
  steps:
    - run CI pipeline
    - deploy to staging environment
    - run E2E tests
    - run performance tests
    - notify team
```

**Production** (Manual):
```yaml
deploy-production:
  trigger: manual approval
  steps:
    - verify staging healthy ≥24 hours
    - run pre-deployment checks
    - await approval
    - backup database
    - run migrations
    - deploy blue-green
    - run smoke tests
    - switch traffic
    - monitor
```

---

## Deployment Metrics

### Track These Metrics

- Deployment frequency
- Lead time (commit to production)
- Change failure rate
- Mean time to recovery (MTTR)
- Rollback rate

### Targets (DevOps Research)

| Metric | Target (Elite Performers) |
|--------|---------------------------|
| Deployment frequency | Multiple per day |
| Lead time | < 1 hour |
| Change failure rate | < 15% |
| MTTR | < 1 hour |
| Rollback rate | < 5% |

---

## Compliance

### Audit Requirements

All deployments must be auditable:
- Who deployed
- What was deployed (version, changes)
- When deployed (timestamp)
- Where deployed (environment)
- Why deployed (ticket reference)
- Outcome (success/failure/rollback)

### Retention

Deployment logs retained for:
- 90 days (standard deployments)
- 1 year (production deployments)
- 3 years (compliance-sensitive industries)

---

## References

- Constitution v3.0.0: `.specify/memory/constitution.md`
- Code Review Policy: `.docs/policies/code-review-policy.md`
- Testing Policy: `.docs/policies/testing-policy.md`
- Security Policy: `.docs/policies/security-policy.md`
- Branching Strategy: `.docs/policies/branching-strategy-policy.md`
- Release Management: `.docs/policies/release-management-policy.md`

---

**Policy Owner**: Operations Department (monitoring skill)
**Last Reviewed**: 2025-11-07
**Next Review**: 2026-02-07
