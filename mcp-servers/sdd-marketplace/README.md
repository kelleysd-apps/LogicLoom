# SDD Plugin Marketplace — MCP Server

An MCP (Model Context Protocol) server that provides tools for managing SDD framework plugins. Connects any project using the SDD framework to the plugin registry.

## Quick Start

The marketplace is pre-configured in `.mcp.json`. Claude Code automatically connects on session start.

```bash
# Verify connection
# In Claude Code, say: "List my installed plugins"
# Claude uses marketplace-list tool automatically
```

## Available Tools

| Tool | Description |
|------|-------------|
| `marketplace-list` | List installed plugins with versions and RL metrics |
| `marketplace-validate` | Validate plugin against governance standards |
| `marketplace-search` | Search the plugin registry |
| `marketplace-install` | Install a plugin from the registry |
| `marketplace-update` | Update installed plugin(s) |
| `marketplace-publish` | Publish plugin to registry (dry-run) |

## Example Usage

```
User: "Show me my installed plugins"
→ marketplace-list (format: table)

User: "Find authentication plugins"  
→ marketplace-search (query: "authentication")

User: "Install the AI/ML domain plugin"
→ marketplace-install (plugin_name: "sdd-domain-ai-ml")

User: "Validate my custom plugin"
→ marketplace-validate (plugin_path: "./plugins/my-plugin")

User: "Check for plugin updates"
→ marketplace-update (dry_run: true)
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SDD_PLUGINS_DIR` | `./plugins` | Path to plugins directory |
| `SDD_REGISTRY_URL` | GitHub marketplace repo | Registry source URL |

### .mcp.json Entry

```json
{
  "mcpServers": {
    "sdd-marketplace": {
      "type": "stdio",
      "command": "node",
      "args": ["mcp-servers/sdd-marketplace/src/index.js"],
      "env": {
        "SDD_PLUGINS_DIR": "./plugins"
      }
    }
  }
}
```

## Connecting Downstream Projects

Any project using the SDD framework connects by:

1. Copy `mcp-servers/sdd-marketplace/` to your project (or reference via npm)
2. Add the MCP server entry to your `.mcp.json`
3. Start a Claude Code session — marketplace tools are automatically available

```bash
# Option A: Copy from framework
cp -r path/to/sdd-framework/mcp-servers/sdd-marketplace ./mcp-servers/

# Option B: Install via npm (when published)
npm install @kelleysd-apps/sdd-plugin-marketplace
```

## Development

```bash
# Install dependencies
cd mcp-servers/sdd-marketplace
npm install

# Run tests
npm test

# Run directly (for debugging)
node src/index.js
```

## Registry

The local registry at `registry/registry.json` contains the official plugin catalog. It's seeded with all 13 framework plugins and can be extended with community contributions.

## Architecture

```
Claude Code Session
    ↕ MCP (stdio)
SDD Marketplace Server
    ↕ filesystem
plugins/ directory + registry.json
```

The server runs as a local stdio process — no network calls needed for local operations (list, validate). Registry searches and installs use the configured registry URL.
