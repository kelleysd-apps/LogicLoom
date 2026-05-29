---
name: create-agent
description: Create a new specialized subagent with constitutional compliance and proper department classification.
model: opus
---

# /create-agent Command

**AGENT REQUIREMENT**: This command should be executed by the subagent-architect.

**If you are NOT the subagent-architect**, delegate immediately:
```
Use the Task tool to invoke subagent-architect:
- description: "Execute /create-agent command"
- prompt: "Execute the /create-agent command. Arguments: $ARGUMENTS"
```

## Execution Instructions (for subagent-architect)

### Step 1: Parse Arguments
- If no arguments: Start interactive mode (ask for name and description)
- If one argument: Use as agent name, ask for description
- If two+ arguments: First is name, rest is description

### Step 2: Validate Name
Must be kebab-case. Check for existing agent with same name.

### Step 3: Determine Plugin
Analyze description keywords to select target plugin:
- Architecture: system, design, planning → `plugins/loom-creation/agents/`
- Orchestration: swarm, team, review, research → `plugins/loom-orchestrator/agents/`
- Dev loop: iterate, autonomous, edit-test-debug → `plugins/loom-dev-loop/agents/`
- Git: commit, push, PR → `plugins/loom-git/agents/`
- Governance: constitution, compliance, hook → `plugins/loom-governance/agents/`
- Product/Spec: requirement, spec, user story → `plugins/sdd-specification/agents/`

> **Domains are briefs, not plugins.** Technical domains (frontend, backend,
> database, testing, security, performance, devops) are **not** plugins — they
> live in the `plugins/loom-governance/domain-briefs/` registry and are
> surfaced via `get_domain_brief`. Do not place an agent in a `sdd-domain-*`
> directory; pick the real owning plugin above. If no clear match, default to
> `loom-creation`.

### Step 4: Create Agent
```bash
echo '{"name": "AGENT_NAME", "description": "DESCRIPTION"}' | .logic-loom/scripts/bash/create-agent.sh --json
```

### Step 5: Verify and Report
Check agent file exists, show location, provide usage instructions.
