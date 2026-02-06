---
name: team-orchestration
description: |
  Orchestrates agent team templates — spawns agents according to team composition,
  manages execution phases, handles budget allocation, and coordinates result merging.
allowed-tools: Read, Write, Bash, Grep, Glob
---

# Team Orchestration Skill

## Procedure

1. Load team template from command invocation
2. Parse team composition (agents, execution mode, budget allocation)
3. For sequential phases: spawn agents in order, wait for completion
4. For parallel phases: spawn all agents simultaneously
5. Monitor via state files and Stop hooks
6. After all phases: invoke synthesizer to merge results
7. Generate team execution report with cost breakdown
