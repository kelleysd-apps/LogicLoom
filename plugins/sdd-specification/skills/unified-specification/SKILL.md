---
name: unified-specification
version: 1.0.0
description: |
  Unified specification workflow that consolidates /specify, /plan, and /tasks
  into a single orchestrated command. Generates all 7 SDD artifacts in sequence
  with quality gates between phases.
  
  Triggered by: /specification command, "create full specification", 
  "generate complete spec", "unified specification workflow"

allowed-tools: Read, Write, Bash, Grep, Glob, Skill
triggers:
  - /specification
  - unified specification
  - complete specification workflow
  - generate full spec
category: sdd-workflow
constitutional_principles:
  - VI (Git Approval for branch operations)
  - VIII (Documentation Synchronization)
  - X (Skills-First Delegation)
---

# Unified Specification Skill

## Overview

This skill orchestrates the complete SDD specification workflow, generating
all design artifacts in a single execution with quality gates between phases.

**Replaces**: `/specify` + `/plan` + `/tasks` (3 commands → 1 command)

## When to Use

Activate this skill when:
- User invokes `/specification <feature-description>`
- User requests "create a complete specification"
- User wants to go from feature idea to executable tasks
- Starting a new feature requiring full SDD workflow

## Procedure

### Step 0: Initialize Workflow

**Create workflow state**:
```bash
# Determine spec directory
BRANCH=$(git branch --show-current)
SPECS_DIR="specs/${BRANCH}"
STATE_FILE="${SPECS_DIR}/.workflow-state.json"

# Create directory if needed
mkdir -p "${SPECS_DIR}"

# Initialize state
cat > "${STATE_FILE}" << EOF
{
  "version": "1.0.0",
  "feature_branch": "${BRANCH}",
  "feature_description": "$ARGUMENTS",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "current_phase": "spec",
  "phases": {
    "spec": { "status": "pending" },
    "plan": { "status": "pending" },
    "tasks": { "status": "pending" }
  },
  "artifacts": {},
  "quality_gates": {}
}
EOF
```

**Check for resume**:
```
IF --resume flag AND state file exists:
  Load state file
  Resume from current_phase
ELSE IF state file exists:
  Ask: "Previous workflow found. Resume or start fresh?"
```

### Step 1: Specification Phase (spec.md)

**Update state**: `current_phase: "spec"`, `phases.spec.status: "running"`

**Ask about branch** (Principle VI):
```
"Would you like to create a new feature branch, or work on the current branch?"
- If new branch: Request approval, then create
- If current branch: Continue
```

**Invoke sdd-specification skill**:
```
Skill: sdd-specification
Input: $ARGUMENTS (feature description)
Output: spec.md
```

**Quality Gate Check**:
```
Run: .logic-loom/scripts/bash/validate-spec.sh --file ${SPECS_DIR}/spec.md

IF score < 0.90:
  Report: "Specification quality: ${score} (threshold: 0.90)"
  Report: Recommendations for improvement
  
  IF retry_count < 3:
    Ask: "Refine specification and retry? (y/n)"
    IF yes: Refine and re-validate
  ELSE:
    Ask: "Proceed despite low quality? (y/n/abort)"
```

**Update state on success**:
```json
{
  "phases.spec.status": "complete",
  "phases.spec.completed_at": "<timestamp>",
  "artifacts.spec.md": { "exists": true, "validated": true, "score": 0.95 },
  "quality_gates.spec_completeness": 0.95
}
```

### Step 2: Planning Phase (plan.md + artifacts)

**Update state**: `current_phase: "plan"`, `phases.plan.status: "running"`

**Invoke sdd-planning skill**:
```
Skill: sdd-planning
Input: spec.md path
Output: plan.md, research.md, data-model.md, contracts/, quickstart.md
```

**Quality Gate Check**:
```
Run: .logic-loom/scripts/bash/validate-plan.sh --file ${SPECS_DIR}/plan.md

IF score < 0.85:
  Report: "Plan quality: ${score} (threshold: 0.85)"
  Report: Recommendations
  Ask: "Refine or proceed?"
```

**Update state on success**:
```json
{
  "phases.plan.status": "complete",
  "artifacts": {
    "plan.md": { "exists": true, "validated": true, "score": 0.88 },
    "research.md": { "exists": true },
    "data-model.md": { "exists": true },
    "contracts/": { "exists": true, "count": 3 },
    "quickstart.md": { "exists": true }
  },
  "quality_gates.plan_quality": 0.88
}
```

### Step 3: Tasks Phase (tasks.md)

**Update state**: `current_phase: "tasks"`, `phases.tasks.status: "running"`

**Invoke sdd-tasks skill**:
```
Skill: sdd-tasks
Input: plan.md and all artifacts
Output: tasks.md
```

**Quality Gate Check**:
```
Verify:
- All contracts have test tasks
- All entities have implementation tasks
- TDD ordering maintained (tests before implementation)
```

**Update state on success**:
```json
{
  "phases.tasks.status": "complete",
  "artifacts.tasks.md": { "exists": true, "task_count": 25 },
  "current_phase": "complete"
}
```

### Step 4: Completion Report

**Run domain detection**:
```bash
.logic-loom/scripts/bash/detect-phase-domain.sh --file ${SPECS_DIR}/spec.md
```

**Generate completion report**:
```
✅ Unified Specification Workflow Complete!

Branch: ${BRANCH}
Duration: ${duration} seconds

📄 Artifacts Created:
  ✓ spec.md         (score: 0.95)
  ✓ plan.md         (score: 0.88)
  ✓ research.md
  ✓ data-model.md
  ✓ contracts/      (3 files)
  ✓ quickstart.md
  ✓ tasks.md        (25 tasks, 12 parallel)

🎯 Domains Detected: ${domains}
👥 Suggested Agents: ${agents}
📋 Delegation: ${strategy}

Ready for implementation! Run tasks from tasks.md following TDD order.
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--branch <name>` | Specify branch name | current |
| `--resume` | Resume from last checkpoint | false |
| `--phase <phase>` | Start from specific phase | spec |
| `--skip-validation` | Skip quality gates (warning) | false |

## Error Handling

### Phase Failure
```
IF any phase fails:
  Save current state to file
  Report: "Workflow paused at ${phase}"
  Report: "Run '/specification --resume' to continue"
```

### State Corruption
```
IF state file unreadable:
  Report: "State file corrupted"
  Ask: "Delete and restart? (y/n)"
```

## Constitutional Compliance

### Principle VI: Git Approval
- Branch creation requires explicit user approval
- Script uses `request_git_approval()` function

### Principle VIII: Documentation Sync
- All 7 artifacts generated together
- Cross-references maintained

### Principle X: Skills-First
- Orchestrates existing skills (sdd-specification, sdd-planning, sdd-tasks)
- Does not duplicate skill logic

## Examples

### Example 1: Basic Usage
```
User: /specification "Build user authentication with JWT"

Output:
🚀 Starting Unified Specification Workflow

📝 Phase 1: Specification
   → Generating spec.md...
   → Validating... Score: 94% ✓

📊 Phase 2: Planning
   → Generating research.md... ✓
   → Generating data-model.md... ✓
   → Generating contracts/... ✓ (4 files)
   → Generating quickstart.md... ✓
   → Generating plan.md... ✓
   → Validating... Score: 87% ✓

✅ Phase 3: Tasks
   → Generating tasks.md... ✓
   → Total: 28 tasks (15 parallel)

✅ Complete! All artifacts in specs/feature-branch/
```

### Example 2: Resume After Interruption
```
User: /specification --resume

Output:
📂 Loading workflow state...
   Last phase: plan (complete)
   Resuming from: tasks

✅ Phase 3: Tasks
   → Generating tasks.md... ✓

✅ Complete!
```

## Validation

After execution, verify:
- [ ] All 7 artifacts exist in specs directory
- [ ] State file shows "complete"
- [ ] Quality gates passed or user approved override
- [ ] Domain detection ran
- [ ] Completion report displayed
## Task Brief

You are the Specification Orchestrator for the complete SDD workflow. You sequence
the spec -> plan -> tasks pipeline, enforcing quality gates between phases.

**Required context**: feature-description (what to build), user-requirements (user needs).
Optional: constraints (technical limits), scope-boundaries (what's in/out).

**Execution model**: You orchestrate existing skills (sdd-specification, sdd-planning,
sdd-tasks) -- you do NOT duplicate their logic. Each phase produces artifacts that
feed the next phase.

**What you do NOT do**:
- Choose which phase to execute (the workflow determines this)
- Make architectural decisions (delegate to domain specialists)
- Skip phases (workflow enforces sequence)

**Phase sequencing**:
1. Spec phase: generate spec.md, validate >= 90% quality
2. Plan phase: generate plan.md + 4 artifacts, validate >= 85% quality
3. Tasks phase: generate tasks.md, verify TDD ordering and contract coverage

**Resume capability**: Workflow state saved to .workflow-state.json. On interruption,
resume from the last completed phase via `--resume` flag.

---

## Related Skills

- `sdd-specification` - Phase 1 implementation
- `sdd-planning` - Phase 2 implementation
- `sdd-tasks` - Phase 3 implementation
- `domain-detection` - Agent suggestion

## Deprecation Notice

This skill **replaces** the following workflow:
```
OLD: /specify → /plan → /tasks (3 commands, manual handoffs)
NEW: /specification (1 command, automated workflow)
```

The old commands remain available with deprecation warnings for 6 months.
