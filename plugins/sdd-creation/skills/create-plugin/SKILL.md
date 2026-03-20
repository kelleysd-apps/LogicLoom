---
name: create-plugin
version: 4.0.0
category: creation
description: Creates new SDD plugins following Plugin-First Architecture v4.0
triggers:
  - create plugin
  - new plugin
  - /create-plugin
  - add plugin
  - scaffold plugin
rl_metrics:
  success_rate: 0.0
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
progressive-disclosure:
  layer-1-metadata:
    description: "Creates new SDD plugins with manifest, agents, skills, and commands"
    triggers: [create plugin, new plugin, /create-plugin]
    primary-agent: subagent-architect
  layer-2-instructions: true
  layer-3-examples: true
agent-invocations:
  - agent: subagent-architect
    context-subset:
      - plugin_name
      - plugin_category
      - plugin_purpose
      - commands
      - agents
    expected-output: plugin_scaffold
ds-star:
  pre-execution: validation/message-preflight
  post-verification: true
  auto-debug: conditional
---

# Create Plugin

## Purpose

Creates new SDD plugins following the Plugin-First Architecture v4.0 (Principle XVI).
This skill ensures all new plugins are created with proper structure including
plugin.json manifest, governance dependency, RL metrics, and required components.

## Constitutional Compliance

- **Principle I (Library-First)**: Plugins are standalone installable units
- **Principle III (Contract-First)**: plugin.json manifest defines the contract
- **Principle XVI (Plugin-First)**: All capabilities as discrete plugins

## Instructions

### Prerequisites

1. Constitutional compliance check must pass
2. User must provide:
   - Plugin name (sdd-* prefix required)
   - Target category
   - Key capabilities (commands, agents, skills)

### Step 1: Gather Requirements

Prompt user for:
```yaml
plugin_name: <required, sdd-* prefix>
category: <domain | orchestration | governance | creation | specification | integration | maintenance>
purpose: <brief description>
commands: <list of slash commands>
agents: <list of agent names>
```

### Step 2: Select Base Template

Based on category, scaffold from:
- `domain` → copy from `plugins/sdd-domain-template/`
- `orchestration` → minimal scaffold with agent + command
- Other → minimal scaffold with plugin.json

### Step 3: Generate Plugin Structure

```
plugins/<plugin-name>/
  .claude-plugin/plugin.json    # Required manifest
  commands/                      # Slash commands
  agents/                        # Agent definitions
  skills/                        # Skill definitions
  scripts/                       # Automation scripts
  hooks/on-install.sh           # Lifecycle hook
  README.md                      # Documentation
```

### Step 4: Create plugin.json

```json
{
  "name": "<plugin-name>",
  "version": "1.0.0",
  "description": "<purpose>",
  "author": "kelleysd-apps",
  "license": "MIT",
  "keywords": ["sdd", "<category>"],
  "dependencies": ["sdd-governance"],
  "rl_metrics": {
    "success_rate": 0.5,
    "selection_weight": 0.5,
    "invocation_count": 0,
    "avg_tokens": 0,
    "last_updated": "<ISO timestamp>"
  }
}
```

### Step 5: Register in Marketplace

Add entry to marketplace registry:
```bash
# Via MCP tool
marketplace-install --plugin-name <name> --source local
```

### Step 6: Validate

Run plugin validation:
```bash
# Via MCP tool
marketplace-validate --plugin-name <name>
```

## Examples

### Example 1: Create Domain Plugin

**Request**: "Create a plugin for AI/ML operations"

**Generated**: `plugins/sdd-domain-ai-ml/`
- plugin.json with dependencies: ["sdd-governance"]
- agents/ai-ml-specialist.md
- skills/ai-ml-operations/SKILL.md
- commands/ai-ml.md

### Example 2: Create Integration Plugin

**Request**: "Create a plugin for Slack notifications"

**Generated**: `plugins/sdd-integration-slack/`
- plugin.json
- skills/slack-notifications/SKILL.md
- scripts/slack-webhook.sh
## Related Skills

- **creation/create-agent**: Create agents within plugins
- **creation/create-template**: Create plugin templates

---

*Plugin-First Architecture: v4.0.0*
*Constitutional Compliance: Principle XVI*
