---
name: debug
description: Debug deployment/runtime issues using 10-step systematic workflow with max 5 iterations.
model: opus
---

# /debug Command

**SKILL ACTIVATION**: Activate the sdd-debug skill at `plugins/sdd-debug/skills/sdd-debug/SKILL.md`.

## Execution Instructions

### Step 1: Issue Identification
Gather context: symptom type, when it started, works locally?, deployment target.

### Step 2: Local Verification
Run: `npx tsc --noEmit`, build locally, simulate Vercel build.

### Step 3: Platform Diagnostics
Check function limits, configuration, environment variables, platform dependencies.

### Step 4: API Endpoint Diagnosis
Debug 404/500 errors: verify file exists, check exports, validate routing.

### Step 5: TypeScript Error Resolution
Fix exactOptionalPropertyTypes, index signatures, missing parameters.

### Step 6: Fix Implementation
Apply targeted fixes maintaining type safety.

### Step 7: Verification
Clean build, TypeScript check, Vercel build — all must pass.

### Step 8: Regression Check
Verify no new issues introduced.

### Step 9: Completion Report
Document root cause, fix applied, verification results.

### Step 10: Iteration Handling
Max 5 cycles. If persists, escalate with summary and recommendations.
Delegate to specialist skills as needed (Principle X): backend-operations, database-operations, security-operations, devops-operations.
