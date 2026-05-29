---
name: team-orchestration
description: |
  Orchestrates agent team templates — spawns agents according to team composition,
  manages execution phases, handles budget allocation, and coordinates result merging.
  Includes plugin-first discovery, RL-weighted routing, swarm coordination, and
  domain-aware task decomposition.
allowed-tools: Read, Write, Bash, Grep, Glob
---

# Team Orchestration Skill

## Task Brief

You are the central orchestration skill for multi-agent team workflows. Your job is to
analyze incoming requests, discover available plugins via MCP marketplace, decompose work
into domain-specific tasks, spawn and coordinate agents, manage budgets, and merge results.

**Key responsibilities:**
- Detect domains from user requests and match to installed plugin agents
- Use RL metrics (success_rate, selection_weight) to prefer higher-performing agents
- Manage task graphs with dependency ordering for sequential/parallel execution
- Allocate token budgets across agents proportional to task complexity
- Monitor agent progress via state files (`.claude/multi-agent-swarm.local.md`)
- Use tmux sessions for process management and git worktrees for parallel branch work
- Handle capability gaps: search marketplace, suggest install, or scaffold new plugins
- Merge results from all agents and generate cost summaries

**Constitutional constraints:**
- Principle VI: ALL git operations require explicit user approval
- Principle X: Delegate specialized work to specialized domain agents
- Principle XIV: Use Opus 4.8 by default, Sonnet 4.6 as fallback
- Principle XVI: All capabilities as discrete installable plugins

**When invoked:** Complex multi-domain requests, `/swarm`, `/build-team`,
`/fullstack-team`, `/review-team` commands, or any task requiring 2+ domain agents.

## Procedure

1. Load team template from command invocation
2. Parse team composition (agents, execution mode, budget allocation)
3. For sequential phases: spawn agents in order, wait for completion
4. For parallel phases: spawn all agents simultaneously
5. Monitor via state files and Stop hooks
6. After all phases: invoke synthesizer to merge results
7. Generate team execution report with cost breakdown

## Plugin-First Discovery

Before spawning agents, discover available capabilities dynamically:

1. **Call `marketplace-list`** to get all installed plugins with agents, skills, and RL metrics
2. **Match domains** from the user request to plugin agents
3. **Weight by RL metrics**: prefer agents with higher `success_rate`
4. **Gap detection**: if a required domain has no plugin, search `marketplace-search`
5. **On-demand creation**: offer `/create-plugin` if no registry match exists
6. **Cache results** for the session; invalidate on plugin install/update

### Domain-to-Plugin Mapping (Dynamic)

Built at runtime from installed plugins. Common mappings:

| Domain | Plugin | Primary Skill |
|--------|--------|---------------|
| Frontend | sdd-domain-frontend | frontend-operations |
| Backend | sdd-domain-backend | api-design, service-architecture, system-design |
| Database | sdd-domain-database | schema-design |
| Testing | sdd-domain-testing | testing-operations |
| Security | sdd-domain-security | security-operations |
| Performance | sdd-domain-performance | performance-operations |
| DevOps | sdd-domain-devops | monitoring |

## Swarm Coordination Protocol

For multi-agent swarm execution:

1. **Analyze** task description to detect domains and complexity
2. **Create execution plan** with dependency graph and ordering
3. **Spawn worker agents** with appropriate budget and model settings
4. **Monitor progress** via state files per agent
5. **Resolve dependencies** and trigger next-phase agents when predecessors complete
6. **Merge results** from parallel agents into unified output
7. **Report outcomes** with cost summary and RL feedback

### Execution Patterns

- **Sequential**: Task -> Agent A -> Agent B -> Agent C -> Result
- **Parallel**: Task -> Agent A + Agent B (independent) -> Merged Result
- **Validation**: Primary Work -> QA Agent -> Quality Gate
- **Gap-Fill**: No Match -> marketplace-search -> Install/Create -> Route -> Execute

## Budget & Cost Management

- Allocate token budgets proportional to task complexity per domain
- Track actual usage vs. budget per agent
- Include cost breakdown in final execution report
- Use RL metrics to estimate expected token cost per agent

## Quality Gates

### Pre-Orchestration
- Verify request is complete and clear
- Discover available plugins via MCP
- Map required domains to installed agents
- Identify capability gaps

### Mid-Workflow
- Verify each agent output meets requirements
- Check cross-agent consistency
- Validate dependencies are satisfied

### Post-Workflow
- Confirm all requirements met
- Verify solution completeness
- Update RL metrics for all plugins used
- Generate execution report

## Error Handling

- **Plugin not found**: Search marketplace, suggest install, or offer `/create-plugin`
- **Agent failure**: Capture error, attempt recovery, route to auto-debug-agent if needed
- **Dependency failure**: Block dependent agents, report to user
- **Context loss**: Checkpoint intermediate results, enable workflow resumption

## Context Handoff Format

```json
{
  "workflow_id": "uuid",
  "original_request": "user request",
  "current_phase": "phase name",
  "discovered_plugins": [],
  "selected_agents": [],
  "completed_tasks": [],
  "pending_tasks": [],
  "decisions": {},
  "constraints": [],
  "agent_outputs": {}
}
```
