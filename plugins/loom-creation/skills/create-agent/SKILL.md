---
name: create-agent
description: Create a new specialized subagent with constitutional compliance and proper plugin classification
allowed-tools: Read, Write, Bash, Grep, Glob
---

# create-agent Skill

Create a new agent definition file with constitutional compliance, proper plugin classification, and SDD agent template format.

## Procedure

### Step 1: Parse Arguments

- If no arguments: Start interactive mode (ask for name and description)
- If one argument: Use as agent name, ask for description
- If two+ arguments: First is name, rest is description

### Step 2: Validate Name

- Must be kebab-case (e.g., `my-agent-name`)
- Check for existing agent with same name across all plugins
- Reject if name conflicts with an existing agent

### Step 3: Determine Target Plugin

Analyze description keywords to select the target plugin:

| Keywords | Target Plugin |
|----------|--------------|
| system, design, planning, architecture | loom-creation |
| orchestration, swarm, team, review, research | loom-orchestrator |
| dev-loop, iterate, autonomous | loom-dev-loop |
| commit, push, PR, git | loom-git |
| constitution, compliance, hook, governance | loom-governance |
| requirement, spec, user story | sdd-specification |

If no clear match, default to `loom-creation`.

> **Domains are briefs, not plugins.** Technical domains (frontend, backend,
> database, testing, security, performance, devops) are **not** plugins — they
> live in the `plugins/loom-governance/domain-briefs/` registry and are
> surfaced via `get_domain_brief`. Never place an agent in an `sdd-domain-*`
> directory; pick the real owning plugin above.

### Step 4: Create Agent File

1. Read template: `.logic-loom/templates/agent-template.md` (if exists) or generate from SDD agent format
2. Populate: name, description, model (default: claude-opus-4-8), tools, responsibilities
3. Write to: `plugins/{target-plugin}/agents/{agent-name}.md`

### Step 5: Update Plugin Manifest

Update the target plugin's `plugin.json` to increment agent count and add to agent list.

### Step 6: Verify and Report

- Confirm agent file exists and is well-formed
- Show file path and usage instructions
- Remind about AGENTS.md update if needed

## Constitutional Compliance

- **Principle X**: New agents must have clear specialization
- **Principle XVI**: Agents must live within plugin directories
- **Principle VI**: No git operations without approval

## Task Brief

When spawning a worker to create an agent, include this context:

> You are creating a new SDD agent definition. Follow the SDD agent template format with: frontmatter (name, description, model), responsibilities section, tools section, delegation protocol, and constitutional compliance notes. Place the file in the correct plugin's agents/ directory.
