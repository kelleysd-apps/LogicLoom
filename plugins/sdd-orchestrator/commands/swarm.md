---
name: swarm
description: Spawn coordinated multi-agent swarm for complex tasks. Analyzes domains, creates execution plan, and launches agents with budget controls.
model: opus
---

# /swarm Command

## Usage
```
/swarm "<task description>" [--budget <usd>] [--team <template>] [--model <model>]
```

## Behavior

1. **Analyze** task description for domain keywords
2. **Detect** required domains (frontend, backend, database, security, etc.)
3. **Plan** execution phases (sequential dependencies, parallel opportunities)
4. **Allocate** budget across agents
5. **Spawn** agents with `--max-budget-usd` and `--fallback-model`
6. **Coordinate** via state files and Stop hooks
7. **Merge** results and report

## Examples
```
/swarm "Build user authentication with React UI, Express API, PostgreSQL"
/swarm "Optimize database queries and add caching layer" --budget 10.00
/swarm "Full code review for security and performance" --team review-team
```

## Agent Spawning
Each agent runs in a separate process with:
- Independent budget limit (`--max-budget-usd`)
- Model fallback (`--fallback-model sonnet`)
- Permission delegation (`--permission-mode delegate`)
- State file for coordination (`.claude/multi-agent-swarm.local.md`)

## Cost Controls
- **Team budget**: Total spend limit across all swarm agents
- **Per-agent allocation**: Budget ÷ agent count (or priority-weighted)
- **Automatic fallback**: Opus → Sonnet when quota depletes
- **Kill switch**: Terminate agents exceeding individual budget
