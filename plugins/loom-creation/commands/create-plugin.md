---
name: create-plugin
description: Create a new LogicLoom plugin with constitutional compliance (Plugin-First Architecture)
model: opus
---

# /create-plugin Command

**AGENT REQUIREMENT**: This command should be executed by the subagent-architect agent.

**If you are NOT the subagent-architect**, delegate immediately:
```
Use the Task tool to invoke subagent-architect:
- description: "Execute /create-plugin command"
- prompt: "Create a new LogicLoom plugin. Arguments: $ARGUMENTS"
```

> **Domains are briefs, not plugins.** Technical domains (frontend, backend,
> database, testing, security, performance, devops) live in the
> `plugins/loom-governance/domain-briefs/` registry and are surfaced via
> `get_domain_brief`. Do **not** create `sdd-domain-*` plugins — to add or
> change a domain, edit a brief in the registry (see `plugins/CONTRIBUTING.md`).

## Execution Instructions (for subagent-architect)

### Step 1: Parse Arguments
- Extract plugin name from $ARGUMENTS (must be kebab-case, prefixed with `loom-`)
- If no arguments: prompt user for plugin name and description

### Step 2: Validate Plugin Name
```bash
# Must be kebab-case, prefixed with loom-
echo "$PLUGIN_NAME" | grep -qE '^loom-[a-z0-9]+(-[a-z0-9]+)*$'
```
- New plugins use the `loom-` prefix. (`sdd-specification` keeps its legacy
  prefix — it *is* the SDD workflow; do not rename it.)
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

## Distribution

New plugins are bundled in-repo under `plugins/` and exposed through the
command bridge (`.logic-loom/scripts/bash/sync-plugin-commands.sh`). LogicLoom
does **not** ship its own marketplace MCP — for third-party plugin discovery
use the **Anthropic Claude Code Plugin Marketplace** (`/plugin`) and the
**Docker MCP Toolkit** gateway.

## Usage
```
/create-plugin loom-analytics "Analytics and metrics tracking"
/create-plugin loom-integration-slack "Slack notification integration"
```

> Need a new technical domain (e.g. Rust)? That's a **brief**, not a plugin —
> add `plugins/loom-governance/domain-briefs/rust.md` and wire detection
> keywords in `plugins/loom-orchestrator-hook/config/domains.conf`.
