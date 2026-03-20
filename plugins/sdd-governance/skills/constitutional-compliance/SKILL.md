---
name: constitutional-compliance
description: |
  Validate constitutional compliance for specifications, plans, tasks, code, and operations
  using the SDD Framework Constitution v3.0.0 (16 principles). Use when checking if work
  follows constitutional requirements or executing compliance validation.

  This skill provides guidance on applying all 16 constitutional principles and running
  automated compliance checks. It ensures all work adheres to immutable, critical, and
  standard principles governing architecture, quality, workflow, and safety.

  Triggered by: User request for "constitutional check", "compliance validation",
  "does this follow the constitution?", or before major milestones (commit, PR, release).
allowed-tools: Read, Bash, Grep
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_feedback: null
---

# Constitutional Compliance Skill

## When to Use

Activate this skill when:
- Checking if work follows constitutional principles
- Before creating pull requests or commits
- User asks "does this comply with the constitution?"
- Validating specifications, plans, or task lists
- Code review focusing on constitutional adherence
- Before releases or major milestones

**Trigger Keywords**: constitutional, compliance, constitution check, validate principles, follows rules

**Critical Moments**:
- After creating specification (validate Principle VIII)
- After creating plan (validate Principles I, II, III)
- Before committing code (validate all applicable principles)
- Before creating PR (full constitutional review)
- Before release (comprehensive audit)

## Procedure

### Step 1: Read the Constitution

**Load the constitution**:
```bash
Read: .specify/memory/constitution.md
```

**Understand the 16 principles** organized in 3 tiers:

**Immutable Principles (I-III)** - NON-NEGOTIABLE:
- **Principle I**: Library-First Architecture
- **Principle II**: Test-First Development
- **Principle III**: Contract-First Design

**Quality & Safety Principles (IV-IX)** - STANDARD:
- **Principle IV**: Idempotent Operations
- **Principle V**: Progressive Enhancement
- **Principle VI**: Git Operation Approval
- **Principle VII**: Observability
- **Principle VIII**: Documentation Synchronization
- **Principle IX**: Dependency Management

**Workflow & Delegation Principles (X-XVI)** - CRITICAL/STANDARD:
- **Principle X**: Agent Delegation Protocol (CRITICAL)
- **Principle XI**: Input Validation & Output Sanitization (CRITICAL)
- **Principle XII**: Design System Compliance
- **Principle XIII**: Access Control
- **Principle XIV**: AI Model Selection
- **Principle XV**: File and Folder Organization
- **Principle XVI**: Plugin-First Architecture

### Step 2: Run Automated Compliance Check

**Execute the constitutional check script**:
```bash
.specify/scripts/bash/constitutional-check.sh
```

**Script checks for**:
- Principle I: Library-first architecture evidence
- Principle II: Test files and TDD workflow
- Principle III: Contract definitions
- Principle VI: No autonomous git operations
- Principle VII: Logging and observability
- Principle VIII: Documentation synchronization
- Principle IX: Declared dependencies
- Principle X: Agent delegation references
- Principle XI: Input validation patterns

**Interpret results**:
- ✅ PASSING: Principle compliance detected
- ⚠️ SKIPPED: Check not applicable to current context
- ❌ FAILING: Principle violation detected

### Step 3: Manual Principle Review

Some principles require human judgment. Review manually:

#### Principle IV: Idempotent Operations
**Check**:
- Can operations be safely repeated?
- Do operations check current state before acting?
- Are operations deterministic (same input → same output)?

**Examples**:
```typescript
// ✅ Idempotent
async function ensureUserExists(email: string) {
  const existing = await db.users.findByEmail(email);
  if (existing) return existing; // Already exists, return it
  return await db.users.create({ email });
}

// ❌ Not Idempotent
async function createUser(email: string) {
  return await db.users.create({ email }); // Fails if user exists
}
```

#### Principle V: Progressive Enhancement
**Check**:
- Does implementation start with simplest solution?
- Is complexity added only when needed (YAGNI)?
- Can features be enabled incrementally?

**Red Flags**:
- Premature optimization
- Over-engineered solutions
- Features not in specification

#### Principle XII: Design System Compliance
**Check** (for UI work):
- Uses design system components?
- Follows design tokens (colors, spacing, typography)?
- Matches design mockups?

#### Principle XIII: Access Control
**Check** (for user-facing features):
- Authentication implemented?
- Authorization checks at every boundary?
- Role-based access control (RBAC)?
- Row-level security (RLS) in database?

#### Principle XIV: AI Model Selection
**Check** (for AI-assisted work):
- Haiku for quick, straightforward tasks?
- Sonnet for complex, multi-step work?
- Opus for critical, high-stakes decisions?

### Step 4: Context-Specific Compliance

**For Specifications**:
- [ ] Principle VIII: Documentation includes spec.md
- [ ] Principle X: Identifies required domains/agents

**For Plans**:
- [ ] Principle I: Describes library-first architecture
- [ ] Principle II: Includes testing strategy
- [ ] Principle III: Defines contracts before implementation
- [ ] Principle VIII: Generates all required artifacts
- [ ] Principle IX: Lists all dependencies with versions

**For Tasks**:
- [ ] Principle II: Test tasks before implementation tasks
- [ ] Principle III: Contract test tasks included
- [ ] Principle X: Identifies agents for task execution

**For Code**:
- [ ] Principle I: Implemented as standalone library
- [ ] Principle II: Tests written and passing
- [ ] Principle III: Contracts implemented as specified
- [ ] Principle VII: Logging for key operations
- [ ] Principle XI: Input validation and output sanitization
- [ ] Principle XIII: Authorization checks (if user-facing)

**For Git Operations**:
- [ ] Principle VI: User approval obtained BEFORE git operations

**For Scripts**:
- [ ] Principle IV: Idempotent (safe to re-run)
- [ ] Principle VI: Requests approval for git operations
- [ ] Principle VII: Logs operations and outcomes

### Step 5: Report Compliance Status

**Provide compliance report**:
```
🏛️ Constitutional Compliance Report

Automated Checks: X/9 passing, Y skipped, Z failing

✅ Immutable Principles (I-III):
- Principle I (Library-First): [status]
- Principle II (Test-First): [status]
- Principle III (Contract-First): [status]

✅ Quality & Safety (IV-IX):
- Principle IV (Idempotent): [status - manual review]
- Principle V (Progressive): [status - manual review]
- Principle VI (Git Approval): [status]
- Principle VII (Observability): [status]
- Principle VIII (Documentation): [status]
- Principle IX (Dependencies): [status]

✅ Workflow & Delegation (X-XVI):
- Principle X (Agent Delegation): [status]
- Principle XI (Validation/Sanitization): [status]
- Principle XII (Design System): [status - manual review]
- Principle XIII (Access Control): [status - manual review]
- Principle XIV (AI Model Selection): [status - manual review]
- Principle XV (File Organization): [status]
- Principle XVI (Plugin-First): [status]

Overall Status: [COMPLIANT / NON-COMPLIANT / NEEDS REVIEW]

Violations: [list any violations]
Warnings: [list any concerns]
Recommendations: [suggested improvements]
```

### Step 6: Violation Resolution

**If violations found**:

1. **STOP** - Do not proceed with non-compliant work
2. **Report** - Clearly identify which principle(s) violated
3. **Explain** - Why it violates (reference constitution)
4. **Suggest** - How to fix the violation
5. **Verify** - Re-check after fix applied

**Immutable Principle Violations** (I-III):
- **BLOCKING** - Cannot proceed without fix
- Must be resolved before any commit/merge

**Critical Principle Violations** (X, XI):
- **HIGH PRIORITY** - Must resolve before release
- May be acceptable for WIP but must be tracked

**Standard Principle Violations** (IV-IX, XII-XIV):
- **SHOULD FIX** - Address before PR
- Document if intentional exception (rare)

## Constitutional Compliance

This skill EMBODIES constitutional compliance:

- **Principle VI**: Never runs git operations without approval
- **Principle VIII**: Ensures documentation stays synchronized
- **Principle X**: Part of quality gate for agent delegation
- **Uses constitutional check script**: `.specify/scripts/bash/constitutional-check.sh`

## Examples

### Example 1: Pre-Commit Compliance Check

**User Request**: "Check if my changes comply with the constitution before I commit"

**Skill Execution**:
1. Read constitution
2. Run: `.specify/scripts/bash/constitutional-check.sh`
3. Automated results: 8/9 passing, 1 skipped (design system N/A)
4. Manual review:
   - Principle IV: Code is idempotent ✅
   - Principle V: No premature optimization ✅
   - Principle XIII: Authorization checks present ✅
5. Report: COMPLIANT - safe to commit

### Example 2: Plan Compliance Validation

**User Request**: "Validate my implementation plan follows constitutional principles"

**Skill Execution**:
1. Read constitution
2. Run: `.specify/scripts/bash/constitutional-check.sh`
3. Automated results: 5/9 passing
   - ❌ FAILING: Principle II - No testing strategy mentioned
   - ❌ FAILING: Principle III - No contracts defined
4. Manual review:
   - Plan missing required artifacts
5. Report: NON-COMPLIANT
   - **Violation**: Principles II & III (immutable)
   - **Fix**: Add testing strategy section, generate contracts/
   - **Block**: Cannot proceed to tasks without fixing

### Example 3: Code Review Compliance

**User Request**: "Review this PR for constitutional compliance"

**Skill Execution**:
1. Read constitution
2. Run automated check
3. Automated results: 9/9 passing ✅
4. Manual review of code:
   - **Principle XI**: Input validation present ✅
   - **Principle XIII**: Authorization checks present ✅
   - **Principle V**: No unnecessary complexity ✅
5. Report: COMPLIANT - approve PR

## Validation

Verify the skill executed correctly:

- [ ] Constitution read and understood
- [ ] Automated check executed
- [ ] Automated results interpreted correctly
- [ ] Manual review performed for judgment-based principles
- [ ] Context-specific checks performed (spec/plan/task/code)
- [ ] Compliance report generated
- [ ] Violations clearly identified (if any)
- [ ] Fixes suggested for violations
- [ ] Overall status determined (compliant/non-compliant/needs-review)

## Troubleshooting

### Issue: Automated check fails with "Constitution not found"

**Cause**: Not in repository root directory

**Solution**:
- Run from repository root
- Use absolute path to constitution: `/workspaces/sdd-agentic-framework/.specify/memory/constitution.md`

### Issue: Many principles show "SKIPPED"

**Cause**: Checks not applicable to current work type

**Solution**:
- This is normal - not all principles apply to all work
- Focus on PASSING and FAILING statuses
- Skipped checks don't indicate problems

### Issue: Unclear if code violates Principle XI

**Cause**: Input validation can be subtle

**Solution**:
- Look for: zod schemas, joi validation, input type checking
- Check all user inputs (forms, query params, path params, headers)
- Check all external data (API responses, file uploads, database reads)
- If no validation found → violation

### Issue: Don't know which principles apply to current work

**Cause**: Constitution has 16 principles

**Solution**:
- **All work**: I, II, III (immutable - always apply)
- **APIs/Services**: VII, IX, XI
- **UI work**: XII, XIII
- **Scripts**: IV, VI, VII
- **AI-assisted**: XIV
- **Architecture**: I, III, IX, X

## Notes

- Constitutional compliance is NON-NEGOTIABLE for immutable principles
- Automated check catches ~60% of violations
- Manual review required for judgment-based principles
- Run before every commit, PR, and release
- Violations of I, II, III are BLOCKING - cannot merge
- Document any intentional exceptions (should be very rare)
- Constitution is living document - may be amended via checklist process
- All agents and skills must comply with constitution
## Related Skills

- **sdd-specification**: Uses Principle VIII (documentation sync)
- **sdd-planning**: Validates Principles I, II, III compliance
- **sdd-tasks**: Ensures test-first task ordering (Principle II)
- **domain-detection**: Part of Principle X (agent delegation)

## References

- Constitution v3.0.0: `.specify/memory/constitution.md`
- Constitution Update Checklist: `.specify/memory/constitution_update_checklist.md`
- Automated Check Script: `.specify/scripts/bash/constitutional-check.sh`
- Testing Policy: `.docs/policies/testing-policy.md` (Principle II)
- Security Policy: `.docs/policies/security-policy.md` (Principle XI)
- Code Review Policy: `.docs/policies/code-review-policy.md`
