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
- Default: `plugins/sdd-governance/skills/<skill-name>/SKILL.md`

### Step 4: Include RL Metrics
Add default rl_metrics frontmatter (success_rate: 0.5, selection_weight: 0.5).

### Step 5: Report
Show: skill path, RL metrics, usage instructions.

## Usage
```
/create-skill api-design
/create-skill api-design --category sdd-domain-backend
/create-skill api-design --category sdd-workflow
```
