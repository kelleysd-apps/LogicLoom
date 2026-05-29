---
name: team-orchestration
description: |
  Orchestrates agent team templates — spawns agents according to team composition,
  manages execution phases, handles budget allocation, and coordinates result merging.
  Includes domain-brief injection, swarm coordination, and domain-aware task
  decomposition using the model's native routing judgment.
allowed-tools: Read, Write, Bash, Grep, Glob
---

# Team Orchestration Skill

## Task Brief

You are the central orchestration skill for multi-agent team workflows. Your job is to
analyze incoming requests, decompose work into domain-specific tasks, spawn and
coordinate workers, manage budgets, and merge results.

**Key responsibilities:**
- Detect domains from user requests using native model judgment
- Inject the matching domain brief into each worker via `get_domain_brief <domain>`
  (registry at `plugins/loom-governance/domain-briefs/<domain>.md`)
- Manage task graphs with dependency ordering for sequential/parallel execution
- Allocate token budgets across workers proportional to task complexity
- Monitor worker progress via state files (`.claude/multi-agent-swarm.local.md`)
- Use tmux sessions for process management and git worktrees for parallel branch work
- Handle capability gaps via the Anthropic Claude Code Plugin Marketplace or Docker
  MCP Toolkit, or scaffold a new plugin with `/create-plugin`
- Merge results from all workers and generate cost summaries

**Constitutional constraints:**
- Principle VI: ALL git operations require explicit user approval
- Principle X: Delegate specialized work to specialized domain agents
- Principle XIV: Use the flagship Opus model by default (resolved via `models.conf`)
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

## Domain-Brief Injection

Before spawning workers, resolve the brief for each detected domain:

1. **Match domains** from the user request using native model judgment (no RL
   scoring — the model routes directly)
2. **Inject the brief**: for each domain, call `get_domain_brief <domain>` from
   `.logic-loom/scripts/bash/common.sh` and place its output in the worker's prompt
3. **Gap detection**: if a capability is missing, browse the Anthropic Claude Code
   Plugin Marketplace or the Docker MCP Toolkit (310+ containerized servers)
4. **On-demand creation**: offer `/create-plugin` when no existing capability fits

### Domain-Brief Registry

The seven technical-domain briefs live in the governance core (the former
`sdd-domain-*` plugins were collapsed into this registry). Resolve via
`get_domain_brief <domain>`:

| Domain | Registry file |
|--------|---------------|
| Frontend | `plugins/loom-governance/domain-briefs/frontend.md` |
| Backend | `plugins/loom-governance/domain-briefs/backend.md` |
| Database | `plugins/loom-governance/domain-briefs/database.md` |
| Testing | `plugins/loom-governance/domain-briefs/testing.md` |
| Security | `plugins/loom-governance/domain-briefs/security.md` |
| Performance | `plugins/loom-governance/domain-briefs/performance.md` |
| DevOps | `plugins/loom-governance/domain-briefs/devops.md` |

## Swarm Coordination Protocol

For multi-agent swarm execution:

1. **Analyze** task description to detect domains and complexity
2. **Create execution plan** with dependency graph and ordering
3. **Spawn worker agents** with appropriate budget and model settings
4. **Monitor progress** via state files per agent
5. **Resolve dependencies** and trigger next-phase agents when predecessors complete
6. **Merge results** from parallel agents into unified output
7. **Report outcomes** with cost summary

### Execution Patterns

- **Sequential**: Task -> Agent A -> Agent B -> Agent C -> Result
- **Parallel**: Task -> Agent A + Agent B (independent) -> Merged Result
- **Validation**: Primary Work -> QA Agent -> Quality Gate
- **Gap-Fill**: No Match -> Anthropic Marketplace / Docker MCP Toolkit -> Install/Create -> Route -> Execute

## Budget & Cost Management

- Allocate token budgets proportional to task complexity per domain
- Track actual usage vs. budget per agent
- Include cost breakdown in final execution report

## Quality Gates

### Pre-Orchestration
- Verify request is complete and clear
- Map required domains to domain briefs via `get_domain_brief`
- Identify capability gaps

### Mid-Workflow
- Verify each agent output meets requirements
- Check cross-agent consistency
- Validate dependencies are satisfied

### Post-Workflow
- Confirm all requirements met
- Verify solution completeness
- Generate execution report

## Error Handling

- **Capability not found**: Browse the Anthropic Marketplace / Docker MCP Toolkit, suggest install, or offer `/create-plugin`
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
