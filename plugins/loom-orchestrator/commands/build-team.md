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
Use the Task tool to spawn 3 sequential workers. Inject the relevant domain brief into each worker's prompt via `get_domain_brief <domain>` (e.g. `get_domain_brief backend`) from `.logic-loom/scripts/bash/common.sh`, which reads the domain-brief registry at `plugins/loom-governance/domain-briefs/<domain>.md`. Each worker's output feeds the next.

**Usage**: `/build-team "Build user authentication with JWT tokens"`
