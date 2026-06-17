---
name: specification
description: Unified SDD workflow — generates spec, plan, and tasks in one command.
model: opus
---

# /specification Command

**SKILL ACTIVATION**: Read and execute `plugins/sdd-specification/skills/unified-specification/SKILL.md`

Pass the user's feature description as the primary argument. The skill handles all 3 phases (specification, planning, tasks) with quality gates.

## Execution Instructions

### Step 1: Load Skill
Read `plugins/sdd-specification/skills/unified-specification/SKILL.md` and follow its procedure.

### Step 2: Execute Phases
The skill runs 3 phases sequentially: Specification, Planning, Tasks. Each phase uses validation scripts (`.logic-loom/scripts/bash/validate-spec.sh`, etc.) and quality gates.

**Usage**: `/specification "Build user authentication with email and password"`
