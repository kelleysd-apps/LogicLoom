---
name: create-plugin
description: Create a new SDD plugin with constitutional compliance (Plugin-First Architecture v4.0)
model: opus
---

# /create-plugin Command

**AGENT REQUIREMENT**: This command should be executed by the subagent-architect agent.

**If you are NOT the subagent-architect**, delegate immediately:
```
Use the Task tool to invoke subagent-architect:
- description: "Execute /create-plugin command"
- prompt: "Create a new SDD plugin. Arguments: $ARGUMENTS"
```

## Execution Instructions (for subagent-architect)

### Step 1: Parse Arguments
- Extract plugin name from $ARGUMENTS (must be kebab-case, prefixed with `sdd-`)
- If no arguments: prompt user for plugin name and description

### Step 2: Validate Plugin Name
```bash
# Must be kebab-case, prefixed with sdd- or sdd-domain-
echo "$PLUGIN_NAME" | grep -qE '^sdd-(domain-)?[a-z0-9]+(-[a-z0-9]+)*$'
```
- Check for existing plugin: `ls plugins/$PLUGIN_NAME 2>/dev/null`

### Step 3: Create Plugin Structure
```bash
PLUGIN_DIR="plugins/$PLUGIN_NAME"
mkdir -p "$PLUGIN_DIR/.claude-plugin"
mkdir -p "$PLUGIN_DIR/commands"
mkdir -p "$PLUGIN_DIR/skills"
mkdir -p "$PLUGIN_DIR/agents"
mkdir -p "$PLUGIN_DIR/hooks"
mkdir -p "$PLUGIN_DIR/scripts"
```

### Step 4: Generate plugin.json Manifest
Write `.claude-plugin/plugin.json` with:
- name, version (1.0.0), description
- dependencies: ["loom-governance"]
- rl_metrics with default values
- Keywords from description

### Step 5: Generate README.md
Write `README.md` with plugin overview, structure, and usage.

### Step 6: Sync Command Bridge
```bash
bash .logic-loom/scripts/bash/sync-plugin-commands.sh sync
```

### Step 7: Report Completion
- Show created directory structure
- Show manifest contents
- Remind about Principle XVI compliance

## Constitutional Compliance
- **Principle XVI**: Plugin-First Architecture — all capabilities as plugins
- **Principle IX**: Dependencies declared in manifest
- **Principle VII**: RL metrics included for observability

## Usage
```
/create-plugin sdd-domain-rust "Rust development domain plugin"
/create-plugin sdd-analytics "Analytics and metrics tracking"
```
