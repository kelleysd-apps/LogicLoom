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
- Architecture: system, design, planning → `plugins/sdd-creation/agents/`
- Backend: develop, backend, API → `plugins/sdd-domain-backend/agents/`
- Frontend: frontend, UI, component → `plugins/sdd-domain-frontend/agents/`
- Quality/Testing: test, qa, review → `plugins/sdd-domain-testing/agents/`
- Security: security, auth, encryption → `plugins/sdd-domain-security/agents/`
- Database: database, sql, pipeline → `plugins/sdd-domain-database/agents/`
- Product: requirement, spec, user → `plugins/sdd-specification/agents/`
- Operations: deploy, devops, monitor → `plugins/sdd-domain-devops/agents/`
- Performance: optimize, cache, benchmark → `plugins/sdd-domain-performance/agents/`

### Step 4: Create Agent
```bash
echo '{"name": "AGENT_NAME", "description": "DESCRIPTION"}' | .specify/scripts/bash/create-agent.sh --json
```

### Step 5: Verify and Report
Check agent file exists, show location, provide usage instructions.
