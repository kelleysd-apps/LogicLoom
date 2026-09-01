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

### Step 3: Determine Department
Agents are created under `.claude/agents/<department>/` — **project scope, never
a plugin.** A plugin-declared agent does not load in this repository: nothing
registers `plugins/` as a Claude Code marketplace, so the declaration is inert
and any dispatch silently degrades to a generic agent with none of the declared
model tier or tool restrictions. Five agents sat in that state until LOOM-0052
moved them out; do not put a sixth there.

`.claude/agents/` is scanned RECURSIVELY, so the department subdirectory is
organisation only — identity comes from the `name` frontmatter field, not the
path. `create-agent.sh` already writes to the right place
(`AGENTS_DIR="${REPO_ROOT}/.claude/agents"`, line 17); this step only picks the
department folder:

- Architecture: system, design, planning → `.claude/agents/architecture/`
- Orchestration: swarm, team, review, research → `.claude/agents/orchestration/`
- Git: commit, push, PR → `.claude/agents/git/`
- Governance: constitution, compliance, hook → `.claude/agents/governance/`
- Product/Spec: requirement, spec, user story → `.claude/agents/product/`

Keep `name` unique across the whole tree: two files declaring the same name mean
only one loads, chosen by filesystem read order.

> **Domains are briefs, not plugins.** Technical domains (frontend, backend,
> database, testing, security, performance, devops) are **not** plugins — they
> live in the `plugins/loom-governance/domain-briefs/` registry and are
> surfaced via `get_domain_brief`. Do not place an agent in a `sdd-domain-*`
> directory; pick the department above. If no clear match, default to
> `architecture`.

### Step 4: Create Agent
```bash
echo '{"name": "AGENT_NAME", "description": "DESCRIPTION"}' | .logic-loom/scripts/bash/create-agent.sh --json
```

### Step 5: Verify and Report
Check agent file exists, show location, provide usage instructions.
