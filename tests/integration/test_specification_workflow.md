# Integration Test: Full Specification Workflow (TS-001)

**Scenario**: Complete specification workflow from description
**Test ID**: IT-SPEC-001
**Status**: FAILING (Implementation pending)

---

## Test Setup

**Preconditions**:
- Clean repository
- No existing spec directory for test branch
- Valid feature description provided

**Test Input**:
```
/specification "Build a REST API for user management with CRUD operations and JWT authentication"
```

---

## Test Execution Steps

### Step 1: Command Invocation
```
Action: Run /specification command
Expected: Workflow initializes
```
- [ ] Command accepted
- [ ] Workflow state file created
- [ ] Phase 1 (spec) starts

### Step 2: Specification Phase
```
Action: spec.md generation
Expected: Valid specification with score >= 0.90
```
- [ ] spec.md created
- [ ] Contains User Stories section
- [ ] Contains Requirements section
- [ ] Contains Acceptance Criteria
- [ ] Validation score >= 0.90

### Step 3: Planning Phase
```
Action: Plan artifacts generation
Expected: All planning artifacts created
```
- [ ] research.md created (technical decisions)
- [ ] data-model.md created (User, JWT entities)
- [ ] contracts/ directory created
- [ ] At least 1 contract file (e.g., create-user.md)
- [ ] quickstart.md created (test scenarios)
- [ ] plan.md created
- [ ] Plan validation score >= 0.85

### Step 4: Tasks Phase
```
Action: tasks.md generation
Expected: Numbered, ordered task list
```
- [ ] tasks.md created
- [ ] Tasks numbered (T001, T002, etc.)
- [ ] TDD ordering (tests before implementation)
- [ ] Parallel markers [P] present
- [ ] Task count > 10

### Step 5: Completion
```
Action: Workflow completes
Expected: Success response with all details
```
- [ ] All 7 artifacts exist
- [ ] Domains detected (expected: backend, database, security)
- [ ] Agents suggested
- [ ] Workflow state shows "complete"
- [ ] Summary displayed to user

---

## Expected Final State

```
specs/[branch]/
├── spec.md         ✓ (score >= 0.90)
├── plan.md         ✓ (score >= 0.85)
├── research.md     ✓
├── data-model.md   ✓
├── contracts/      ✓ (1+ files)
├── quickstart.md   ✓
└── tasks.md        ✓ (10+ tasks)
```

---

## Validation Checklist

- [ ] All 7 artifacts created
- [ ] spec.md validation >= 0.90
- [ ] plan.md validation >= 0.85
- [ ] Tasks follow TDD ordering
- [ ] Domains correctly detected
- [ ] Agents correctly suggested
- [ ] Total time < 5 minutes
- [ ] No errors during execution

---

## Current Status

**Result**: ❌ FAILING (Implementation pending)

**Reason**: Unified specification skill not yet implemented
