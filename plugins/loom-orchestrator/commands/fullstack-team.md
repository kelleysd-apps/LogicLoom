---
name: fullstack-team
description: Launch parallel frontend + backend + database specialists for cross-domain feature development
model: opus
---

# /fullstack-team Command

**SKILL ACTIVATION**: Read and execute `plugins/loom-orchestrator/skills/team-orchestration/SKILL.md`

## Execution Instructions

### Step 1: Load Skill
Read `plugins/loom-orchestrator/skills/team-orchestration/SKILL.md` and follow its procedure in **parallel fullstack** mode (frontend + backend + database).

### Step 2: Execute Development
Use the Task tool to spawn 3 parallel domain workers. Inject each worker's domain brief via `get_domain_brief frontend`, `get_domain_brief backend`, and `get_domain_brief database` from `.logic-loom/scripts/bash/common.sh`, which reads the domain-brief registry at `plugins/loom-governance/domain-briefs/<domain>.md`. Assign file ownership boundaries to prevent conflicts.

**Usage**: `/fullstack-team "Build user profile page with API and database schema"`
