---
name: swarm
description: Spawn coordinated multi-agent swarm for complex tasks. Analyzes domains, creates execution plan, and launches workers with budget controls.
model: opus
---

# /swarm Command

**SKILL ACTIVATION**: Read and execute `plugins/sdd-orchestrator/skills/team-orchestration/SKILL.md`

## Execution Instructions

### Step 1: Load Skill
Read `plugins/sdd-orchestrator/skills/team-orchestration/SKILL.md` and follow its procedure in **swarm** mode (auto-detect domains, phased execution with budget controls).

### Step 2: Execute Swarm
Analyze task for domain keywords, load relevant skill briefs via `extract_skill_brief()` from `.specify/scripts/bash/common.sh`, plan execution phases, and spawn parallel workers per phase with budget tracking.

**Usage**: `/swarm "Build auth with React UI, Express API, PostgreSQL"`
