---
description: Create a new specialized subagent with constitutional compliance and proper department classification.
---

> ⚠️ **DEPRECATED**: This command has moved to `plugins/sdd-creation/commands/create-agent.md`.
> The plugin version is the canonical source. This monolithic version will be removed in v5.0.
> 
> **Plugin-First Architecture (Principle XVI)**: All commands now live within their respective plugins.


**AGENT REQUIREMENT**: This command should be executed by the subagent-architect.

**If you are NOT the subagent-architect**, delegate this work immediately:
```
Use the Task tool to invoke subagent-architect:
- subagent_type: "subagent-architect"
- description: "Execute /create-agent command"
- prompt: "Execute the /create-agent command. Arguments: $ARGUMENTS"
```

The subagent-architect is specialized for:
- Creating SDD-compliant agents
- Constitutional agent workflows
- Agent department classification
- Tool access restrictions
- Agent memory structure initialization

---

## Execution Instructions (for subagent-architect)

Given the agent name and description provided as arguments, do this:

1. Parse the arguments:
   - If no arguments: Start interactive mode
   - If one argument: Use as agent name, ask for description
   - If two+ arguments: First is name, rest is description

2. Validate the agent name:
   - Must be in kebab-case format (lowercase with hyphens)
   - Check for existing agents with same name

3. Analyze the description to determine department:
   - Architecture: system, design, planning, integration keywords
   - Engineering: develop, backend, frontend, api, code keywords
   - Quality: test, qa, review, audit, security keywords
   - Data: database, sql, pipeline, analytics keywords
   - Product: requirement, user, ux, feature keywords
   - Operations: deploy, devops, monitor, incident keywords

4. Execute agent creation:
   ```bash
   echo '{"name": "AGENT_NAME", "description": "DESCRIPTION"}' | .specify/scripts/bash/create-agent.sh --json
   ```

5. Verify the agent was created successfully:
   - Check for agent file in `.claude/agents/AGENT_NAME.md`
   - Verify constitutional compliance
   - Confirm memory structure created

6. Report results:
   - Show agent name, department, and location
   - Provide usage instructions: "Use the AGENT_NAME agent to..."
   - Display any validation warnings

The script will automatically:
- Set appropriate tool restrictions based on department
- Include constitutional references
- Create memory structure in `.docs/agents/`
- Log creation to audit trail

Note: All agents must comply with constitutional requirements and governance policies.