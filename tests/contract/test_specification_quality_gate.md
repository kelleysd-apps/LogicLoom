# Contract Test: /specification Quality Gate Handling

**Contract**: `specs/001-example/contracts/specification-command.md`
**Test ID**: CT-SPEC-003
**Status**: FAILING (Implementation pending)

---

## Test Cases

### TC-008: Spec Quality Gate Failure

**Input**: Vague feature description that produces low-quality spec

**Expected**:
- Spec generated
- Quality score < 0.90 threshold
- Error response with:
  - `error_code: "VALIDATION_FAILED"`
  - `phase: "spec"`
  - `recommendations: [array of improvements]`
  - `can_retry: true`

**Actual**: IMPLEMENTATION COMPLETE - MANUAL VALIDATION NEEDED
**Result**: ❌ FAILING

---

### TC-009: Plan Quality Gate Failure

**Setup**: Good spec exists
**Input**: Technical constraints that prevent good plan

**Expected**:
- Spec phase passes
- Plan generated
- Quality score < 0.85 threshold
- Error response with:
  - `error_code: "VALIDATION_FAILED"`
  - `phase: "plan"`
  - `recommendations: [array of improvements]`

**Actual**: IMPLEMENTATION COMPLETE - MANUAL VALIDATION NEEDED
**Result**: ❌ FAILING

---

### TC-010: Skip Validation Option

**Input**:
```
/specification "feature" --skip-validation
```

**Expected**:
- Warning issued about skipping validation
- Workflow proceeds without quality gates
- All artifacts generated
- Response includes `validation_skipped: true`

**Actual**: IMPLEMENTATION COMPLETE - MANUAL VALIDATION NEEDED
**Result**: ❌ FAILING

---

### TC-011: Retry After Failure

**Setup**: Previous run failed quality gate
**Input**: `/specification --resume` with refined description

**Expected**:
- State file loaded
- Failed phase re-executed
- Quality gate re-checked
- Proceeds if passing

**Actual**: IMPLEMENTATION COMPLETE - MANUAL VALIDATION NEEDED
**Result**: ❌ FAILING

---

## Validation Checklist

- [ ] TC-008 passes
- [ ] TC-009 passes
- [ ] TC-010 passes
- [ ] TC-011 passes

**Overall**: ❌ FAILING (0/4 tests passing)
