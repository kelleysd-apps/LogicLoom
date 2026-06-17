---
name: create-plugin
version: 4.0.0
category: creation
description: Creates new SDD plugins following Plugin-First Architecture
triggers:
  - create plugin
  - new plugin
  - /create-plugin
  - add plugin
  - scaffold plugin
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
---

# Create Plugin

## Purpose

Creates new LogicLoom plugins following the Plugin-First Architecture (Principle XVI).
This skill ensures all new plugins are created with proper structure including
plugin.json manifest, governance dependency, and required components.

> **Domains are briefs, not plugins.** Technical domains (frontend, backend,
> database, testing, security, performance, devops) are **not** plugins — they
> live in the `plugins/loom-governance/domain-briefs/` registry and are
> surfaced via `get_domain_brief`. Do not scaffold `sdd-domain-*` plugins; to
> add a domain, edit a brief in the registry (see `plugins/CONTRIBUTING.md`).

## Constitutional Compliance

- **Principle I (Library-First)**: Plugins are standalone installable units
- **Principle III (Contract-First)**: plugin.json manifest defines the contract
- **Principle XVI (Plugin-First)**: All capabilities as discrete plugins

## Instructions

### Prerequisites

1. Constitutional compliance check must pass
2. User must provide:
   - Plugin name (`loom-*` prefix required for new plugins)
   - Target category
   - Key capabilities (commands, agents, skills)

### Step 1: Gather Requirements

Prompt user for:
```yaml
plugin_name: <required, loom-* prefix>
category: <orchestration | governance | creation | specification | integration | maintenance>
purpose: <brief description>
commands: <list of slash commands>
agents: <list of agent names>
```

New plugins use the `loom-` prefix. (`sdd-specification` keeps its legacy
prefix — it *is* the SDD workflow; do not rename it.)

### Step 2: Select Base Template

Based on category, scaffold from:
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
  "keywords": ["loom", "<category>"],
  "dependencies": ["loom-governance"]
}
```

### Step 5: Wire Into the Command Bridge

Plugins are bundled in-repo; expose their commands via the bridge:
```bash
bash .logic-loom/scripts/bash/sync-plugin-commands.sh sync
```

LogicLoom does **not** ship its own marketplace MCP. For third-party plugin
discovery use the **Anthropic Claude Code Plugin Marketplace** (`/plugin`) and
the **Docker MCP Toolkit** gateway.

### Step 6: Validate

Run plugin validation:
```bash
bash tests/contract/plugins/test_plugin_lifecycle.sh
```

## Examples

### Example 1: Create Orchestration Plugin

**Request**: "Create a plugin for AI/ML operations"

**Generated**: `plugins/loom-ai-ml/`
- plugin.json with dependencies: ["loom-governance"]
- agents/ai-ml-specialist.md
- skills/ai-ml-operations/SKILL.md
- commands/ai-ml.md

> If the request were "add an AI/ML *domain*", that is a brief, not a plugin —
> add `plugins/loom-governance/domain-briefs/ai-ml.md` instead.

### Example 2: Create Integration Plugin

**Request**: "Create a plugin for Slack notifications"

**Generated**: `plugins/loom-integration-slack/`
- plugin.json
- skills/slack-notifications/SKILL.md
- scripts/slack-webhook.sh
## Related Skills

- **creation/create-agent**: Create agents within plugins
- **creation/create-template**: Create plugin templates

---

*Constitutional Compliance: Principle XVI*
