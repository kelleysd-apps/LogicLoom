---
name: review-team
description: Launch parallel security + quality + performance reviewers for comprehensive code review
model: opus
---

# /review-team Command

**SKILL ACTIVATION**: Read and execute `plugins/sdd-orchestrator/skills/team-orchestration/SKILL.md`

## Execution Instructions

### Step 1: Load Skill
Read `plugins/sdd-orchestrator/skills/team-orchestration/SKILL.md` and follow its procedure in **parallel review** mode (security + quality + performance).

### Step 2: Execute Review
Use the Task tool to spawn 3 parallel review workers with skill briefs from `extract_skill_brief()` in `.specify/scripts/bash/common.sh`. Synthesize findings after all complete.

**Usage**: `/review-team` (reviews current branch changes)
