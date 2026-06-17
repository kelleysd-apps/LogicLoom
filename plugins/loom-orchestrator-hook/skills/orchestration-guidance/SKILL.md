---
name: orchestration-guidance
version: 1.0.0
description: |
  Produces orchestration guidance for Claude Code sessions. Analyzes user messages
  for domain keywords, recommends specialist agents, and provides constitutional
  governance context. Triggered by the preflight hook on every UserPromptSubmit.

  This skill provides GUIDANCE, not persona override. Claude Code retains its
  native capabilities while receiving contextual recommendations.

allowed-tools: Read, Bash, Grep
triggers:
  - UserPromptSubmit hook
  - orchestration guidance
  - domain detection
category: orchestration
constitutional_principles:
  - X (Agent Delegation)
  - XVI (Plugin-First Architecture)
---

# Orchestration Guidance Skill

## Overview

This skill is invoked by the preflight hook (`governance-preflight.sh`) on every
user message. It produces orchestration guidance that is injected as
`additionalContext` — helping Claude Code make informed decisions about domain
routing and constitutional compliance.

## Key Design Principle

**Guidance, not override.** This skill does NOT replace Claude Code's native
capabilities. It augments Claude Code's context with:
- Detected domain(s) from the user's message
- Recommended specialist agent(s) for those domains
- Constitutional governance reminders
- Slash command routing (if applicable)

## Procedure

### Step 1: Domain Detection

Scan user message for domain keywords defined in `config/domains.conf`.
Extract unique domains and their corresponding agents.

### Step 2: Delegation Recommendation

Based on detected domains:
- 0 domains: "No specialized domain detected — direct execution appropriate"
- 1 domain: "Domain detected: [X]. Consider using [X]-operations skill"
- 2+ domains: "Multiple domains detected: [X, Y]. Consider multi-skill-workflow or team-orchestration"

### Step 3: Constitutional Context

Include governance reminder with key principles:
- Principle VI: Git approval required
- Principle X: Specialized work to specialists
- Principle II: TDD mandatory

### Step 4: Command Routing

If a slash command is detected, include routing context to the appropriate
plugin command file.

## Output Format

The output is a text block injected as `additionalContext`:

```
Constitutional Compliance Check:
- Domain(s): [detected domains]
- Delegation: [recommended agent or direct execution]
- Git operations: [none planned | will request approval]
- Proceeding with: [action description]
```

## Configuration

Domain-to-agent mappings are defined in `config/domains.conf`. Downstream
projects can customize this file to match their agent registry.
