---
name: create-plugin
description: Create a new SDD plugin with constitutional compliance (Plugin-First Architecture v4.0)
model: opus
---
# /create-plugin Command

Create a new SDD plugin following Plugin-First Architecture (Principle XVI).

## Usage

```
/create-plugin <plugin-name> [options]
/create-plugin sdd-domain-ai-ml --category domain
/create-plugin sdd-custom-workflow --category orchestration
```

## Arguments

**Required**:
- `plugin-name`: Kebab-case plugin name (must start with `sdd-` prefix)

**Optional**:
- `--category <type>`: Plugin category (domain, orchestration, governance, creation, specification, integration)
- `--description "text"`: Brief description of the plugin
- `--from-template <template>`: Use sdd-domain-template as scaffold base

## Execution Steps

### Step 1: Validate Plugin Name
- Must be kebab-case with `sdd-` prefix
- Must not conflict with existing plugins
- Check: `ls plugins/ | grep <name>`

### Step 2: Scaffold Plugin Structure

```
plugins/<plugin-name>/
  .claude-plugin/
    plugin.json          # Manifest (required)
  commands/              # Slash commands
  agents/                # Agent definitions
  skills/                # Skill definitions
  scripts/               # Automation scripts
  hooks/                 # Lifecycle hooks
    on-install.sh
  README.md
```

### Step 3: Generate plugin.json Manifest

```json
{
  "name": "<plugin-name>",
  "version": "1.0.0",
  "description": "<description>",
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

### Step 4: Create Domain Agent (if category=domain)
- Copy from sdd-domain-template as base
- Customize for specific domain

### Step 5: Register in Marketplace
- Add entry to `mcp-servers/sdd-marketplace/registry/registry.json`
- Validate with `marketplace-validate` MCP tool

### Step 6: Validate Plugin
- Check plugin.json is valid JSON
- Verify sdd-governance dependency
- Ensure at least one command, agent, or skill exists

## Plugin Categories

| Category | Purpose | Example |
|----------|---------|---------|
| `domain` | Domain-specific expertise | sdd-domain-ai-ml |
| `orchestration` | Workflow coordination | sdd-orchestrator |
| `governance` | Compliance & rules | sdd-governance |
| `creation` | Entity creation | sdd-creation |
| `specification` | SDD workflow phases | sdd-specification |
| `integration` | External integrations | sdd-integration |
| `maintenance` | Framework operations | sdd-maintenance |

## Constitutional Compliance

- **Principle I (Library-First)**: Plugins are standalone installable units
- **Principle III (Contract-First)**: plugin.json manifest defines the contract
- **Principle XVI (Plugin-First)**: All capabilities as discrete plugins

## Related Commands

- `/create-agent` - Creates an agent within a plugin
- `/specification` - Uses SDD specification workflow
