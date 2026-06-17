---
name: create-skill
description: Create a new agent skill with procedural guidance templates for workflow automation.
model: opus
---

# /create-skill Command

## Execution Instructions

### Step 1: Parse Arguments
Extract skill name (kebab-case), optional `--agent` and `--category` flags.

### Step 2: Load Skill Template
Read: `.logic-loom/templates/skill-template.md`

### Step 3: Generate Skill
Create SKILL.md at appropriate location:
- If `--agent`: `plugins/<plugin>/skills/<skill-name>/SKILL.md`
- If `--category`: `plugins/<plugin>/skills/<skill-name>/SKILL.md`
- Default: `plugins/loom-governance/skills/<skill-name>/SKILL.md`

### Step 4: Report
Show: skill path, usage instructions.

## Usage
```
/create-skill api-design
/create-skill api-design --category loom-orchestrator
/create-skill api-design --plugin loom-creation
```

> **Note**: Technical domains (frontend, backend, database, testing, security,
> performance, devops) are **briefs**, not plugins — they live in the
> `plugins/loom-governance/domain-briefs/` registry and are surfaced via
> `get_domain_brief`. Do not target a skill at a `--category sdd-domain-*`;
> use a real plugin (`loom-*`, or `sdd-specification` for the legacy SDD
> workflow) instead.
