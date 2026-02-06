# SDD Plugin Marketplace — MCP Server

An MCP (Model Context Protocol) server that provides tools for managing SDD framework plugins. Connects any project using the SDD framework to the plugin registry.

## Quick Start

The marketplace is pre-configured in `.mcp.json`. Claude Code automatically connects on session start.

```bash
# Verify connection
# In Claude Code, say: "List my installed plugins"
# Claude uses marketplace-list tool automatically
```

### First-Time Setup

After cloning or updating the framework, install MCP server dependencies:

```bash
# Automatic (via setup script):
./.specify/scripts/setup.sh

# Manual (if needed):
cd mcp-servers/sdd-marketplace && npm install
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

## Authentication (Private Registry)

The plugin marketplace registry (`kelleysd-apps/sdd-plugins-marketplace`) is a **private** repository.
Plugin installation uses `git clone` under the hood, which requires GitHub authentication.

### Supported Auth Methods

| Method | Setup | Works? |
|--------|-------|--------|
| **GitHub CLI (recommended)** | `gh auth login` | ✅ |
| **HTTPS + keyring** | `git config credential.helper osxkeychain` (macOS) | ✅ |
| **SSH keys** | Requires registry URL change to `git@github.com:...` | ⚠️ needs config |
| **GITHUB_TOKEN env** | `export GITHUB_TOKEN=ghp_...` | ✅ |

### Verify Authentication

```bash
# Check GitHub CLI auth
gh auth status

# Verify git can access the registry
git ls-remote https://github.com/kelleysd-apps/sdd-plugins-marketplace.git
```

### Downstream Project Setup

When connecting a downstream project to the marketplace:

1. Ensure `gh auth login` is configured on the machine
2. Copy `mcp-servers/sdd-marketplace/` to your project
3. Run `cd mcp-servers/sdd-marketplace && npm install`
4. Add the MCP server entry to your `.mcp.json`
5. Start a Claude Code session — marketplace tools are automatically available

## Registry

The local registry at `registry/registry.json` contains the official plugin catalog.
Each plugin entry includes:
- `name`, `version`, `description`
- `source`: Object with `repo` (git URL), `path` (subdirectory), `type` (install method)
- `components`: Count of skills, agents, commands
- `dependencies`: Required plugins (most depend on `sdd-governance`)

### Source Types

| Type | Description | Install Method |
|------|-------------|----------------|
| `github-subdirectory` | Plugin in a subdirectory of a mono-repo | Sparse checkout |
| `direct` | Standalone plugin repository | Full `git clone` |
| local path | Local filesystem path | `cp -r` |

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

## Architecture

```
Claude Code Session
    ↕ MCP (stdio)
SDD Marketplace Server
    ↕ filesystem
plugins/ directory + registry.json
    ↕ git (sparse checkout)
sdd-plugins-marketplace (private GitHub repo)
```

The server runs as a local stdio process — no network calls needed for local operations (list, validate). Registry searches use the local `registry.json`. Plugin installation uses git sparse checkout to fetch individual plugins from the registry repo.
