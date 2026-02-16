---
name: plan
description: Generate implementation plan from specification with research and contracts.
model: opus
---

# /plan Command

**SKILL**: This command uses the sdd-planning skill.

## Execution Instructions

### Step 1: Initialize
Run: `.specify/scripts/bash/setup-plan.sh --json` — parse JSON for FEATURE_SPEC, IMPL_PLAN, SPECS_DIR, BRANCH.

### Step 2: Analyze Specification
Read the feature spec and constitution at `.specify/memory/constitution.md`.

### Step 3: Execute Plan Template
Load `.specify/templates/plan-template.md` and run Phases 0-1:
- Phase 0: Generate `research.md`
- Phase 1: Generate `data-model.md`, `contracts/`, `quickstart.md`

### Step 4: Validate
Run: `.specify/scripts/bash/validate-plan.sh --file IMPL_PLAN`

### Step 5: Domain Detection
Run: `.specify/scripts/bash/detect-phase-domain.sh --file IMPL_PLAN`

### Step 6: Report
Show: branch, file paths, validation score, suggested agents, readiness for /tasks.
