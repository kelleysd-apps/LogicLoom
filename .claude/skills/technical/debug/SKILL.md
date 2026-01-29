# Debug Skill

---
name: debug
description: |
  Interactive debugging workflow for Vercel deployment issues, API endpoint failures,
  and production runtime errors. Systematic diagnosis and verification of fixes.

  **When to Use**:
  - Vercel deployment fails (build errors, function deployment issues, 404 endpoints)
  - API endpoint errors (500 errors, timeout issues, missing routes)
  - Production runtime issues (silent failures, incorrect behavior)
  - Local vs production discrepancies (works locally but fails on Vercel)
  - TypeScript compilation errors blocking deployments
  - Serverless function issues (cold starts, memory limits, timeouts)

  **Workflow**: 10-step systematic diagnosis with max 5 iterations before user escalation

  **Delegates To**: backend-architect, database-specialist, security-specialist, devops-engineer

allowed-tools: Read, Write, Bash, Grep, Glob, Edit, WebFetch
---

## Overview

The `/debug` skill provides a **systematic 10-step debugging workflow** specifically designed for production issues, deployment failures, and runtime errors. It enforces verification at each step and automatically delegates to specialized agents when complex architectural issues are identified.

### Key Features

- **Systematic workflow** with clear pass/fail criteria at each step
- **Vercel-specific troubleshooting** (function limits, platform dependencies, serverless issues)
- **TypeScript error resolution** (exactOptionalPropertyTypes, index signatures)
- **Automatic specialist delegation** when architectural/security/performance issues found
- **Iteration limit enforcement** (maximum 5 cycles before user escalation)
- **Constitutional compliance** (Principles II, VI, VIII, X)

---

## The 10-Step Workflow

### Step 1: Issue Identification

**Purpose**: Gather context and understand the symptom

**Actions**:
- Identify symptom type (deployment failure, runtime error, 404, 500, etc.)
- Determine when issue started (recent change, specific commit)
- Check if it works locally (local build, dev server)
- Verify deployment target (Vercel preview, production)

**Commands**:
```bash
# Get recent deployments
vercel ls --yes

# Check specific deployment logs
vercel logs <deployment-url> --yes
```

**Expected Outcome**: Clear understanding of issue type and scope

**Pass Criteria**: ✅ Issue type identified, scope understood

---

### Step 2: Local Verification

**Purpose**: Isolate platform-specific vs code issues

**Actions**:
- Run TypeScript compilation check
- Build client locally
- Simulate Vercel build

**Commands**:
```bash
# TypeScript compilation check
npx tsc --noEmit

# Client build
npm run build:client

# Vercel build simulation
vercel build --yes
```

**Pass Criteria**:
- ✅ TypeScript: 0 errors
- ✅ Client build: SUCCESS
- ✅ Vercel build: SUCCESS

**Decision Tree**:
- Local build **fails** → Fix compilation errors before proceeding
- Local build **succeeds** but Vercel fails → Proceed to Step 3 (platform-specific issues)

**If Verification Fails**: Return to this step after applying fixes

---

### Step 3: Vercel-Specific Diagnostics

**Purpose**: Check for platform-specific issues and limits

**Actions**:
- Count serverless functions (Hobby plan limit: 12)
- Verify Vercel configuration
- Check environment variables
- Look for platform-specific dependencies

**Commands**:
```bash
# Count functions
find api -name "*.ts" -type f | wc -l

# Check configuration
cat vercel.json

# Check for platform-specific optional dependencies
cat package-lock.json | grep -A 5 "optionalDependencies"
```

**Verification Checklist**:
- [ ] `functions` configuration correct
- [ ] `includeFiles` includes all dependencies
- [ ] `maxDuration` within plan limits
- [ ] `rewrites` configured correctly
- [ ] All required env vars set in Vercel dashboard
- [ ] No Windows-specific dependencies in lockfile

**Common Issues**:
- Windows-specific dependencies (`@esbuild/win32-x64`) break Linux builds
- `package-lock.json` with platform-specific binaries
- Native modules not compatible with Vercel's environment
- Exceeding function count limits

**Pass Criteria**: ✅ All platform-specific checks pass

---

### Step 4: API Endpoint Diagnosis

**Purpose**: Debug 404 and 500 errors in API endpoints

#### For 404 Errors

**Commands**:
```bash
# Verify file exists in git
git ls-files | grep "api/v1/<endpoint-path>"

# Check file structure
ls -la api/v1/<endpoint-path>

# Verify export
grep -n "export default" api/v1/<endpoint-path>/*.ts
```

**Routing Patterns**:
- Flat file: `api/v1/sync.ts` → `/api/v1/sync`
- Directory: `api/v1/sync/index.ts` → `/api/v1/sync`
- Dynamic: `api/v1/[id].ts` → `/api/v1/:id`

#### For 500 Errors

**Commands**:
```bash
# Check runtime logs
vercel logs <deployment-url> --yes

# Look for uncaught exceptions
grep -r "Error:" api/
```

**Common Causes**:
- Missing environment variables
- Database connection failures
- Unhandled promise rejections
- Import path errors (relative vs absolute)
- Missing dependencies in production

**Pass Criteria**: ✅ Root cause identified

---

### Step 5: TypeScript Error Resolution

**Purpose**: Fix common TypeScript compilation errors

#### Error Categories & Solutions

**1. `exactOptionalPropertyTypes` Errors**

```typescript
// ❌ WRONG - assigns undefined to optional property
return { status, error: maybeUndefined };

// ✅ CORRECT - conditionally add property
const result = { status };
if (maybeUndefined) result.error = maybeUndefined;
return result;
```

**2. Index Signature Errors**

```typescript
// ❌ WRONG - direct property access on unknown object
const value = obj.someProperty;

// ✅ CORRECT - bracket notation with type assertion
const value = obj['someProperty'] as string | undefined;
```

**3. Missing Required Parameters**

- Check function signatures
- Verify all required fields in insert operations
- Match schema definitions exactly

**Pass Criteria**: ✅ TypeScript compilation succeeds (0 errors)

---

### Step 6: Fix Implementation

**Purpose**: Apply targeted fixes based on diagnosis

**Implementation Rules**:
1. Apply targeted fixes to identified issues
2. Maintain type safety (no `any` shortcuts)
3. Build objects conditionally for optional properties
4. Use proper error handling (try/catch, error boundaries)

**Import Path Corrections**:

```bash
# For flat file at api/v1/sync.ts
# Use: ../../server/db

# For directory file at api/v1/sync/index.ts
# Use: ../../../server/db
```

**Pattern**: Count directory depth to determine `../` levels

**Pass Criteria**: ✅ Fixes applied, code compiles locally

---

### Step 7: Verification Process

**Purpose**: Ensure fixes work before deployment

**Commands**:

```bash
# Clean build
rm -rf dist .vercel/output
npm run build:client

# TypeScript check
npx tsc --noEmit

# Vercel build
vercel build --yes
```

**Pass Criteria**: All commands succeed with 0 errors

**Deployment**:

```bash
git add <modified-files>
git commit -m "fix: <concise description of fix>"
git push origin <branch-name>
```

**Post-Deployment Testing**:

```bash
# For API endpoints
curl -X POST https://<deployment-url>/api/v1/<endpoint> \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

**Pass Criteria**:
- ✅ Deployment succeeds (green check)
- ✅ Endpoint returns expected status (200, not 404/500)
- ✅ Response body matches expected format
- ✅ No console errors in runtime logs

**Constitutional Compliance** (Principle VI):
- **NO automatic git operations** without user approval
- Always show what will be committed
- Get approval for commit message
- User decides when to push

---

### Step 8: Regression Check

**Purpose**: Verify no new issues introduced

**Verification Checklist**:
- [ ] Other API endpoints still work
- [ ] No new TypeScript errors introduced
- [ ] No new runtime errors in logs
- [ ] Deployment time within normal range
- [ ] Function count still within limits

**Test Related Functionality**:
- If fixed auth endpoint → test login/logout
- If fixed database query → test CRUD operations
- If fixed webhook → trigger test event

**Pass Criteria**: ✅ No regressions detected

---

### Step 9: Completion Report

**Purpose**: Document root cause and verification results

**Only execute when ALL verification passes**

**Report Format**:

```
✅ Debug Session Complete

Issue: [Original issue description]
Root Cause: [What was wrong]
Fix Applied: [What was changed]

Files Modified:
- [file-path:line-range] - [change description]
- [file-path:line-range] - [change description]

Verification Results:
✅ TypeScript build: PASS (0 errors)
✅ Local Vercel build: PASS
✅ Deployment: SUCCESS
✅ Endpoint test: PASS (expected response)
✅ Regression check: PASS (no new issues)

Deployment URL: https://[preview-url]
Status: VERIFIED AND READY
```

**Constitutional Compliance** (Principle VIII - Documentation Sync):
- If fixing API endpoints, check if API docs need updates
- Update CLAUDE.md if debugging reveals new patterns
- Document workarounds for platform-specific issues

---

### Step 10: Iteration Handling

**Purpose**: Prevent infinite debugging loops

**Iteration Rules**:
- Maximum **5 diagnostic cycles** per debug session
- If ANY verification step fails → return to Step 2 (Local Verification)
- Each iteration captures new error details and updates analysis

**Iteration Tracking**:
```
Iteration 1: [Issue identified] → [Fix attempted] → [Result]
Iteration 2: [New error found] → [Fix attempted] → [Result]
...
```

**Escalation Message** (if 5 iterations reached):

```
⚠️ Debug Iteration Limit Reached

After 5 diagnostic cycles, the issue persists. Manual intervention recommended.

Summary of attempts:
1. [Iteration 1 summary]
2. [Iteration 2 summary]
...

Current state: [Description]
Recommended next steps:
- [Specific action 1]
- [Specific action 2]
- [Escalation path if needed]

Consider delegating to:
- backend-architect (API architecture issues)
- database-specialist (query/schema problems)
- security-specialist (auth/security issues)
- devops-engineer (infrastructure/CI-CD problems)
```

---

## Agent Delegation Protocol

### When to Delegate

**Principle X Compliance**: Specialized work MUST be delegated to specialized agents.

| Specialist | When to Delegate |
|------------|------------------|
| `backend-architect` | API architecture issues, system design problems, service orchestration |
| `database-specialist` | Query optimization, schema issues, connection pool problems, RLS policies |
| `security-specialist` | Authentication, authorization, vulnerability fixes, CSP/CORS issues |
| `devops-engineer` | CI/CD pipeline issues, infrastructure problems, deployment automation |

### Delegation Pattern

```
Task tool:
  subagent_type: "backend-architect"
  description: "Debug and fix [issue]"
  prompt: |
    Debug the following production issue:
    [Issue description with logs]

    Apply fixes and verify deployment succeeds.
    Report verification results.
```

### Delegation Triggers

**Automatic delegation when**:
- Issue requires architectural changes (not just bug fixes)
- Security vulnerabilities identified
- Database schema changes needed
- Infrastructure/deployment automation needed
- Issue spans multiple domains

---

## Vercel-Specific Reference

### Function Count Limits

| Plan | Function Limit | Notes |
|------|----------------|-------|
| Hobby | 12 | Free tier |
| Pro | 100 | Paid tier |
| Enterprise | Unlimited | Custom |

**Monitoring**:
```bash
find api -name "*.ts" -type f | wc -l
```

**Solutions when approaching limit**:
1. Consolidate related endpoints
2. Use query parameters for routing
3. Upgrade plan
4. Restructure API architecture

### Common Platform Issues

**Windows-Specific Dependencies**:
- Symptom: Works locally (Windows) but 404 on Vercel (Linux)
- Cause: `package-lock.json` with `@esbuild/win32-x64`
- Fix: Remove `package-lock.json`, let Vercel regenerate for Linux

**Environment Variables**:
- Always set in Vercel dashboard
- Redeploy after env var changes
- Use `env:VAR_NAME` in vercel.json

**Cold Starts**:
- First request to function slower (normal behavior)
- Subsequent requests faster
- Monitor timeout limits (10s Hobby, 60s Pro)

---

## Constitutional Compliance Summary

### Principle II: Test-First Development

- If tests exist for modified code, verify they pass
- Add tests for bug fixes to prevent regression
- Integration tests should cover the fixed scenario

### Principle VI: Git Operation Approval (CRITICAL)

- **NO automatic commits** without user context
- Always show what will be committed
- Get approval for commit message
- User decides when to push

### Principle VIII: Documentation Synchronization

- If fixing API endpoints, check if API docs need updates
- Update CLAUDE.md if debugging reveals new patterns
- Document workarounds for platform-specific issues

### Principle X: Agent Delegation Protocol

- Delegate to specialists when appropriate (see Agent Delegation section)
- Do NOT attempt complex architectural fixes directly
- Use Task tool for specialist invocation

---

## Performance Characteristics

| Phase | Duration | Notes |
|-------|----------|-------|
| **Diagnostic phase** | 1-2 minutes | Issue identification, local verification |
| **Fix implementation** | 5-15 minutes | Depends on complexity |
| **Verification** | 2-5 minutes | Includes deployment wait time |
| **Total per iteration** | 8-22 minutes | Single iteration cycle |

---

## Troubleshooting Common Issues

### Issue: Local build succeeds but Vercel fails

**Causes**:
- Platform-specific dependencies in `package-lock.json`
- Environment variables missing in Vercel
- Native modules incompatible with Vercel runtime
- File path case sensitivity (Windows vs Linux)

**Solutions**:
1. Remove `package-lock.json` if platform-specific
2. Verify env vars in Vercel dashboard
3. Check for native module usage
4. Ensure consistent file path casing

---

### Issue: Endpoint returns 404 despite file existing

**Causes**:
- Incorrect export (`export default function` vs `export default async function`)
- File structure mismatch (index.ts in wrong location)
- Vercel function limit reached (12 max on Hobby)
- Route conflict with rewrites in vercel.json

**Solutions**:
1. Verify `export default` in handler file
2. Check file path matches expected route
3. Count API functions: `find api -name "*.ts" | wc -l`
4. Review vercel.json rewrites configuration

---

### Issue: TypeScript errors only in Vercel build

**Causes**:
- Different TypeScript version
- Stricter compiler options in production
- Missing type definitions
- `exactOptionalPropertyTypes` enabled

**Solutions**:
1. Match TypeScript versions (package.json)
2. Build locally with `vercel build`
3. Install missing @types packages
4. Fix optional property assignments (see Step 5)

---

### Issue: Deployment succeeds but runtime 500 errors

**Causes**:
- Missing environment variables
- Database connection failures
- Unhandled promise rejections
- Cold start timeouts

**Solutions**:
1. Check Vercel logs: `vercel logs <url>`
2. Verify all env vars set and correct
3. Add try/catch to async handlers
4. Increase function timeout if needed

---

## Real-World Examples

### Example 1: Vercel Function Count Limit

**User Request**: "deployment failed. investigate and debug"

**Execution**:

1. **Issue Identification**: Vercel deployment shows "Error" status
2. **Local Verification**: Local builds succeed ✅
3. **Vercel Diagnostics**: Count API functions → 15 found, **limit is 12** ❌
4. **Root Cause**: Exceeding Hobby plan limit
5. **Fix**: Consolidate 3 sync endpoints into 1 with query parameters
   - Combined `health.ts`, `monday-to-beehiiv.ts`, `supabase-to-monday.ts`
   - Into `sync/index.ts` with `?action=` routing
   - Deleted stub `collect-analytics.ts`
6. **Verification**: Reduced to 12 functions, deployment succeeds ✅
7. **Result**: Issue resolved in **1 iteration**

**Files Modified**:
- Created: `api/v1/sync/index.ts` - Consolidated sync endpoints
- Deleted: `api/v1/sync/health.ts`, `monday-to-beehiiv.ts`, `supabase-to-monday.ts`
- Updated: `.github/workflows/failsafe-reconciliation.yml:30` - New endpoint URLs

---

### Example 2: TypeScript `exactOptionalPropertyTypes` Errors

**User Request**: "still failed. dont stop debugging till you confirm it deploys successfully"

**Execution**:

1. **Issue Identification**: Build fails with TS2375 errors
2. **Local Verification**: `npx tsc --noEmit` shows multiple errors ❌
3. **Error Category**: Optional property assignment violations
4. **Root Cause**: Assigning `undefined` to optional properties
5. **Fix Pattern Applied**:

   ```typescript
   // Before
   return { status, error: maybeUndefined };

   // After
   const result = { status };
   if (maybeUndefined) result.error = maybeUndefined;
   return result;
   ```

6. **Files Fixed**:
   - `api/v1/sync/index.ts:326` - ComponentHealth return
   - `api/v1/webhooks/index.ts:180` - Event handler types
   - `server/services/external/monday.client.ts:250` - Conditional inserts
   - `server/services/external/beehiiv.client.ts:145` - Result objects
7. **Verification**: TypeScript compilation succeeds ✅
8. **Result**: **4 files fixed, 0 errors**

---

## Related Skills and Commands

| Skill/Command | Relationship | When to Use |
|---------------|-------------|-------------|
| `/specify` | Preventive | Create feature specifications to prevent bugs |
| `/plan` | Preventive | Design implementation to avoid common issues |
| `/tasks` | Complementary | Break down debugging tasks into subtasks |
| `constitutional-compliance` | Validation | Ensure fixes follow all principles |
| `backend-architect` | Delegation | API redesign, system architecture issues |
| `database-specialist` | Delegation | Query optimization, schema issues |
| `security-specialist` | Delegation | Auth/authorization, security vulnerabilities |
| `devops-engineer` | Delegation | CI/CD failures, infrastructure configuration |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| **v1.0.0** | 2026-01-10 | Initial debug skill for Vercel deployment debugging |

---

**Skill Version**: 1.0.0
**Framework Version**: 3.1.1
**Constitutional Compliance**: Principles II, VI, VIII, X
**Maintained By**: SDD Agentic Framework Team
