---
name: build-team
description: Launch sequential architect → implementor → reviewer team for feature development
model: opus
---

# /build-team Command

**SKILL ACTIVATION**: Read and execute `plugins/loom-orchestrator/skills/team-orchestration/SKILL.md`

## Execution Instructions

### Step 1: Load Skill
Read `plugins/loom-orchestrator/skills/team-orchestration/SKILL.md` and follow its procedure in **sequential** mode (architect → implementor → reviewer).

### Step 2: Execute Pipeline
Use the Task tool to spawn 3 sequential workers with domain skill briefs extracted via `extract_skill_brief()` from `.logic-loom/scripts/bash/common.sh`. Each worker's output feeds the next.

**Usage**: `/build-team "Build user authentication with JWT tokens"`
