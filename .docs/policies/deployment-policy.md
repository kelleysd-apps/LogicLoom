# Deployment Policy

**Version**: 1.2.0
**Effective Date**: TBD
**Authority**: Constitution v3.2.0 - Principle VII (Observability)
**Review Cycle**: Quarterly

---

## Purpose

This policy establishes deployment standards, procedures, and safeguards for the LogicLoom framework, ensuring reliable, observable, and reversible deployments following constitutional principles.

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

## Environment Declaration (`environments.conf`)

Everything in this policy below this section is **prose**. This section is the
one part a machine can read.

`.logic-loom/config/environments.conf` is where your project **declares** its
environments and the order changes promote through them. A reader/validator
ships with it:

```bash
./.logic-loom/scripts/bash/validate-environments.sh
```

### What the harness ships, and what it does not

| Ships with LogicLoom | Yours to provide |
|---|---|
| The declaration schema (`environments.conf`) | Which cloud, which CI provider |
| The promotion order and its coherence checks | Deploy commands and build steps |
| The `requires_approval` gate **structure** | The real gate (e.g. a GitHub Environment with required reviewers) |
| The `deploy` **seam** — a place to name your script | The deploy script itself |
| A read-only validator that never deploys and never runs git | Secrets store, migration runner, rollback mechanics |

**The harness provides no deploy execution.** It will not run your deployment,
inspect it, or have an opinion about how it works. `deploy` is a **seam**: it
names a product-owned script so the declaration can point at the thing that does
the work without the harness owning that thing. If you leave `deploy` out, the
environment simply has no deploy script — that is a valid declaration.

**Nothing here is enforced.** No hook reads this file. `requires_approval` is a
declaration your CI or your reviewer is expected to honour; the harness will not
notice if you deviate. Principle VI still governs the git operations you run
yourself — the approval gate on any promotion that touches git comes from the
git-safety hook, not from this file.

### The declaration

Same `key = value` grammar as the sibling configs. `environment = <name>` opens
a block; the keys after it belong to that block.

| Key | Meaning |
|---|---|
| `environment` | Block opener. The environment's name. Required, unique. |
| `branch` | The branch this environment tracks. Free text — **the harness creates no branches and verifies none.** Omit it if a tag or manual dispatch advances the environment instead. |
| `requires_approval` | `true` / `false`. Whether promotion *into* this environment needs a human approval. Defaults to `false`. |
| `promotes_from` | The environment immediately before this one. Omit for the first in a chain. Must name a declared environment; the order must be acyclic. |
| `deploy` | The product-owned deploy script. The seam. Never provided by the harness. |

Example (this is what ships in the file, commented out):

```conf
environment       = dev
branch            = main
requires_approval = false
deploy            = web/scripts/deploy-dev.sh

environment       = staging
branch            = release
promotes_from     = dev
requires_approval = false
deploy            = web/scripts/deploy-staging.sh

environment       = prod
branch            = release
promotes_from     = staging
requires_approval = true
deploy            = web/scripts/deploy-prod.sh
```

### Shipped with nothing declared

`environments.conf` ships with **every declaration commented out**. An active
default would assert branches and a topology your project does not have — the
same defect that made this policy describe a repo that did not exist (see
Version History 1.1.0). Principle V (Progressive Enhancement) says the same
thing from the other side: do not ship a three-environment pipeline before one
environment is proven in use.

**One environment is a perfectly good answer.** So is none — a project with no
environments declared is normal, and the validator exits 0 on an absent or empty
file.

### The validator

Read-only. It parses, checks, and reports. It never deploys, never invokes the
`deploy` seam, never runs git, never creates a branch, and never writes a file.

It **errors** on: a key outside any environment block, a duplicate environment
name, a `promotes_from` naming an environment that is not declared, a cycle in
the promotion order (naming the cycle), and a `requires_approval` that is not
`true`/`false`.

It **warns** on an unknown key and carries on. That is deliberate: the sibling
configs skip lines they do not recognise rather than failing, so this one does
not fail either — but it says so out loud, because a typo'd key here would
otherwise silently do nothing.

### On a promotion command

There is no customer-facing promotion command, and this task did not add one.
The maintainer-only `/promote` name is already taken and is stripped from
customer copies by exact path, so a customer-facing `/promote <env>` would
collide with it. If one is ever added, it needs a **different name** — the
working suggestion is `/deploy-promote <env>` — or a manifest restructure.
Until that is decided, the declaration is read by humans, by agents, and by the
validator; promotion itself is run by your own CI.

---

## Deployment Environments

The three environments below are **roles**, not branch names. LogicLoom ships no
deployment machinery and defines no environment branches — **which branch (or
tag, or manual dispatch) advances which environment is a decision your project
makes**, and it belongs in your own copy of this policy. The triggers named below
are stated as roles precisely so they cannot rot into a description of branches
that do not exist.

> **Nothing in this section is enforced.** There is no hook, no check, and no
> workflow behind it. It is a template for the deployment discipline your project
> should adopt; the harness will not notice if you deviate.

### Development (dev)

**Purpose**: Active development and testing

**Characteristics**:
- Frequent deployments (multiple per day)
- May be unstable
- Uses development dependencies
- Debug mode enabled
- No user data

**Deployment trigger**: continuous, on every change that lands in the mainline
(or in your integration branch, if you run one). Record the concrete trigger
here.

### Staging

**Purpose**: Pre-production verification

**Characteristics**:
- Production-like configuration
- Production-like data (anonymized)
- Performance testing
- User acceptance testing
- Integration testing

**Deployment trigger**: on each release candidate — a tag, a release branch, or a
manual dispatch. Record the concrete trigger here.

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

**LogicLoom ships none of the pipelines below.** They are shapes to adapt. Each
`trigger:` is written as a role — substitute the branch, tag, or dispatch event
your project actually uses.

**Development** (Automatic):
```yaml
deploy-dev:
  trigger: <changes landing on your mainline>
  steps:
    - run CI pipeline
    - deploy to dev environment
    - run smoke tests
```

**Staging** (Automatic):
```yaml
deploy-staging:
  trigger: <release candidate — tag, release branch, or dispatch>
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

- Constitution v3.2.0: `.logic-loom/memory/constitution.md`
- Code Review Policy: `.docs/policies/code-review-policy.md`
- Testing Policy: `.docs/policies/testing-policy.md`
- Security Policy: `.docs/policies/security-policy.md`
- Branching Strategy: `.docs/policies/branching-strategy-policy.md`
- Release Management: `.docs/policies/release-management-policy.md`

---

## Version History

| Version | Change |
|---|---|
| 1.2.0 | Added the **Environment Declaration** section: `.logic-loom/config/environments.conf` (schema) + `validate-environments.sh` (read-only reader/validator). The prose environment model in this policy now has a machine-readable counterpart. States plainly that the harness ships no deploy execution and that `deploy` is a product-owned seam. Ships with every declaration commented out. No promotion command was added — the `/promote` name collision is unresolved and is documented rather than worked around. |
| 1.1.0 | Environments are now described as **roles** rather than branch names. Removed the assertions that deployment is automatic on push to `develop` / `staging` — neither branch exists, and the framework defines no environment branches. Stated plainly that no deployment machinery ships and none of this section is enforced. |
| 1.0.0 | Initial policy. |

---

**Policy Owner**: Operations Department (monitoring skill)
**Last Reviewed**: TBD
**Next Review**: TBD
