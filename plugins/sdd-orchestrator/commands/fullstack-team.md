---
name: fullstack-team
description: Launch parallel frontend + backend + database specialists for cross-domain feature development
model: opus
---

# /fullstack-team Command

**SKILL ACTIVATION**: Read and execute `plugins/sdd-orchestrator/skills/team-orchestration/SKILL.md`

## Execution Instructions

### Step 1: Load Skill
Read `plugins/sdd-orchestrator/skills/team-orchestration/SKILL.md` and follow its procedure in **parallel fullstack** mode (frontend + backend + database).

### Step 2: Execute Development
Use the Task tool to spawn 3 parallel domain workers with skill briefs from `extract_skill_brief()` in `.logic-loom/scripts/bash/common.sh`. Assign file ownership boundaries to prevent conflicts.

**Usage**: `/fullstack-team "Build user profile page with API and database schema"`
