---
name: specification
description: Unified SDD workflow — generates spec, plan, and tasks in one command.
model: opus
---

# /specification Command

**SKILL ACTIVATION**: Activate the unified-specification skill at `plugins/sdd-specification/skills/unified-specification/SKILL.md`.

## Execution Instructions

### Step 1: Branch Setup
Ask user about branch preference. Run `.specify/scripts/bash/create-new-feature.sh --json "$ARGUMENTS"` if new branch.

### Step 2: Phase 1 — Specification
Load `.specify/templates/spec-template.md`, fill from $ARGUMENTS, validate via `.specify/scripts/bash/validate-spec.sh`.

### Step 3: Phase 2 — Planning
Run `.specify/scripts/bash/setup-plan.sh --json`, execute plan template Phases 0-1, validate via `.specify/scripts/bash/validate-plan.sh`.

### Step 4: Phase 3 — Tasks
Run `.specify/scripts/bash/check-task-prerequisites.sh --json`, generate tasks.md with dependency ordering.

### Step 5: Quality Gates
- Spec completeness: ≥90%
- Plan quality: ≥85%
- Task coverage: all contracts/entities have tasks

### Step 6: Report
Show all 7 artifacts created, validation scores, suggested next steps.

## Options
| Option | Description |
|--------|-------------|
| `--branch <name>` | Create or use specific branch |
| `--resume` | Resume interrupted workflow |
| `--phase <spec\|plan\|tasks>` | Start from specific phase |

## Usage
```
/specification "Build user authentication with email and password"
/specification --resume
```
