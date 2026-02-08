---
name: swarm
description: Spawn coordinated multi-agent swarm for complex tasks. Analyzes domains, creates execution plan, and launches agents with budget controls.
model: opus
---

# /swarm Command

**AGENT REQUIREMENT**: This command requires the swarm-coordinator agent.

**If you are NOT the swarm-coordinator**, delegate immediately:
```
Use the Task tool to invoke swarm-coordinator:
- description: "Execute /swarm command"
- prompt: "Analyze and orchestrate multi-agent swarm for: $ARGUMENTS"
```

## Execution Instructions (for swarm-coordinator)

### Step 1: Analyze Task
- Parse $ARGUMENTS for domain keywords
- Detect required domains: frontend, backend, database, security, testing, performance, devops
- Determine complexity and scope

### Step 2: Create Execution Plan
Build dependency graph:
```
Identify:
  - Which agents are needed (based on detected domains)
  - Dependency ordering (database before backend, backend before frontend)
  - Parallel opportunities (independent domains)
  - Budget allocation per agent
```

### Step 3: Allocate Budget
```bash
TOTAL_BUDGET=${BUDGET:-10.00}
AGENT_COUNT=<detected agents>
PER_AGENT_BUDGET=$(echo "$TOTAL_BUDGET / $AGENT_COUNT" | bc -l)
```

### Step 4: Spawn Agents via Task Tool
For each agent in the execution plan:
```
Use the Task tool:
- description: "Swarm agent: [domain]-specialist"
- prompt: |
    You are the [domain]-specialist agent in a swarm.
    TASK: $ARGUMENTS
    YOUR ROLE: [domain-specific instructions]
    DEPENDENCIES: [outputs from previous agents]
    
    Save results to: .docs/teams/swarm-$TIMESTAMP/[domain]-output.md
```

### Step 5: Coordinate Dependencies
- Monitor Task tool completions
- Feed outputs from completed agents to dependent agents
- Handle failures: retry once, then report to user

### Step 6: Merge Results
After all agents complete, consolidate outputs into unified report.

### Step 7: Report
Present: task summary, agents used, cost breakdown, outputs produced.

## Agent Spawning Details
Each agent runs with:
- Independent budget limit (`--max-budget-usd`)
- Model fallback (`--fallback-model sonnet`)
- State file for coordination

## Cost Controls
- **Team budget**: Total spend limit across all swarm agents
- **Per-agent allocation**: Budget ÷ agent count (or priority-weighted)
- **Kill switch**: Terminate agents exceeding individual budget

## Usage
```
/swarm "Build user authentication with React UI, Express API, PostgreSQL"
/swarm "Optimize database queries and add caching layer" --budget 10.00
/swarm "Full code review for security and performance" --team review-team
```
