# Agent SDK Integration Research

**Status**: Research Phase
**Spec**: 004-plugin-first-architecture (T5.1.1-T5.1.3)
**Date**: 2026-01-15

## Overview

The Claude Code Agent SDK provides a programmatic interface for creating and managing AI agents. This document tracks research into integrating the Agent SDK with the SDD plugin architecture.

## Integration Points

### 1. Plugin → Agent SDK Mapping

Each plugin's `agents/` directory contains agent definitions in Markdown format. The Agent SDK integration would:

```
Plugin Agent Definition (.md)  →  Agent SDK Runtime Instance
  - name, description          →  agent.name, agent.description
  - tools                      →  agent.tools[]
  - model                      →  agent.model
  - behavioral guidelines      →  agent.system_prompt
```

### 2. Swarm Coordination

The sdd-orchestrator plugin's swarm capabilities map to Agent SDK multi-agent patterns:

```
launch-swarm.sh (tmux)  →  Agent SDK parallel execution
Stop hooks              →  Agent SDK completion callbacks
Budget controls         →  Agent SDK token tracking
```

### 3. RL Metrics Collection

Agent SDK can provide richer metrics than PostToolUse hooks:

```
Current: PostToolUse → rl-metrics-capture.sh → plugin.json
Future:  Agent SDK events → RL pipeline → plugin.json + analytics
```

## Research Questions

| # | Question | Status |
|---|----------|--------|
| 1 | Does Agent SDK support custom tool definitions? | 🔍 Needs research |
| 2 | Can Agent SDK agents share context across instances? | 🔍 Needs research |
| 3 | What's the Agent SDK pricing model for multi-agent? | 🔍 Needs research |
| 4 | Can we run Agent SDK agents in Docker containers? | 🔍 Needs research |
| 5 | How does Agent SDK handle agent-to-agent communication? | 🔍 Needs research |

## Proposed Architecture

```
┌──────────────────────────────────────────┐
│  SDD Plugin System                        │
│                                           │
│  plugins/sdd-<name>/                     │
│    agents/<agent>.md  ────────┐          │
│    skills/SKILL.md            │          │
│    hooks/hooks.json           │          │
│                               ▼          │
│  ┌────────────────────────────────────┐  │
│  │  Agent SDK Bridge (future)         │  │
│  │                                    │  │
│  │  - Parse .md agent definitions     │  │
│  │  - Create Agent SDK instances      │  │
│  │  - Map skills → tool definitions   │  │
│  │  - Pipe RL metrics to EMA engine   │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

## Next Steps

1. Monitor Claude Code Agent SDK release announcements
2. Prototype agent .md → SDK conversion script
3. Test SDK multi-agent coordination vs tmux swarms
4. Evaluate SDK's RL/feedback capabilities
5. Design bridge plugin: `sdd-agent-sdk-bridge`

## References

- Plugin architecture: `specs/004-plugin-first-architecture/`
- Swarm implementation: `plugins/sdd-orchestrator/`
- RL metrics: `plugins/sdd-governance/hooks/scripts/rl-metrics-capture.sh`
