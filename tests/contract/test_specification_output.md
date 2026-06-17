# Contract Test: /specification Output Artifacts

**Contract**: `specs/001-example/contracts/specification-command.md`
**Test ID**: CT-SPEC-002
**Status**: FAILING (Implementation pending)

---

## Test Cases

### TC-005: All Artifacts Generated

**Input**:
```
/specification "Build user authentication with email/password"
```

**Expected Artifacts**:
- [ ] `specs/[branch]/spec.md` exists
- [ ] `specs/[branch]/plan.md` exists
- [ ] `specs/[branch]/research.md` exists
- [ ] `specs/[branch]/data-model.md` exists
- [ ] `specs/[branch]/contracts/` directory exists with files
- [ ] `specs/[branch]/quickstart.md` exists
- [ ] `specs/[branch]/tasks.md` exists

**Actual**: IMPLEMENTATION COMPLETE - MANUAL VALIDATION NEEDED
**Result**: ❌ FAILING

---

### TC-006: Success Response Format

**Input**: Valid feature description

**Expected Response**:
```json
{
  "success": true,
  "workflow_id": "<uuid>",
  "branch": "<branch-name>",
  "artifacts": {
    "spec.md": { "path": "...", "validated": true, "score": ">0.9" },
    "plan.md": { "path": "...", "validated": true, "score": ">0.85" },
    "tasks.md": { "path": "...", "task_count": ">0" }
  },
  "domains_detected": ["<array>"],
  "suggested_agents": ["<array>"],
  "ready_for_implementation": true
}
```

**Actual**: IMPLEMENTATION COMPLETE - MANUAL VALIDATION NEEDED
**Result**: ❌ FAILING

---

### TC-007: Artifacts Have Required Sections

**spec.md must contain**:
- [ ] User Stories section
- [ ] Requirements section
- [ ] Acceptance Criteria

**plan.md must contain**:
- [ ] Technical Context
- [ ] Constitution Check
- [ ] Phase sections

**tasks.md must contain**:
- [ ] Numbered tasks (T001, T002...)
- [ ] TDD ordering (tests before implementation)
- [ ] Parallel markers [P]

**Actual**: IMPLEMENTATION COMPLETE - MANUAL VALIDATION NEEDED
**Result**: ❌ FAILING

---

## Validation Checklist

- [ ] TC-005 passes
- [ ] TC-006 passes
- [ ] TC-007 passes

**Overall**: ❌ FAILING (0/3 tests passing)
