# Plugin Marketplace — MCP Middleware Design

> **⚠️ REMOVED / HISTORICAL** — This design is no longer part of the framework.
> The in-house `mcp-servers/sdd-marketplace/` package and its GitHub plugin
> registry were **cut**. Plugin discovery and install are now delegated to two
> external ecosystems:
>
> 1. **Anthropic Claude Code Plugin Marketplace** — first-party plugin discovery
>    and install (via the `/plugin` commands and the marketplace browser).
> 2. **Docker MCP Toolkit** — 310+ containerized MCP servers via the unified
>    gateway (`mcp-find`, `mcp-add`, `mcp-config-set`, `mcp-exec`, `code-mode`).
>
> The cross-project RL metrics described in the "RL Integration" section below
> were also removed; the framework relies on native model judgment rather than
> tracked `selection_weight`/`success_rate` telemetry. The remainder of this
> document is retained verbatim **as historical record only** and does not
> describe current behavior.

**Status**: Phase A+B Complete — MCP Server + GitHub Registry Live
**Spec**: 004-plugin-first-architecture (T4.6.1-T4.6.6)
**Priority**: HIGH — User-requested for next milestone
**Date**: 2026-01-15

## Architecture

The marketplace is implemented as an **MCP server** that connects the SDD framework to a remote plugin registry. This allows any project using the framework to discover, install, and update plugins via MCP tools.

### Connection Pattern

```
┌─────────────────────────┐       ┌──────────────────────────┐
│  SDD Framework Project  │       │  Marketplace MCP Server   │
│                         │       │  (middleware)              │
│  .mcp.json:             │       │                           │
│    "sdd-marketplace": { │──────▶│  Tools:                   │
│      "command": "npx",  │       │    marketplace-search     │
│      "args": [...]      │       │    marketplace-install    │
│    }                    │       │    marketplace-update     │
│                         │       │    marketplace-publish    │
│  Claude Code:           │       │    marketplace-list       │
│    "Find auth plugins"  │       │    marketplace-validate   │
│    → MCP tool call      │       │                           │
│    → installs to        │       │  Registry:                │
│      plugins/           │       │    GitHub repo / npm / API│
└─────────────────────────┘       └──────────────────────────┘
```

### MCP Server Definition

```json
// .mcp.json addition
{
  "mcpServers": {
    "sdd-marketplace": {
      "type": "stdio",
      "command": "npx",
      "args": ["sdd-plugin-marketplace@latest"],
      "description": "SDD Plugin Marketplace — search, install, update plugins",
      "env": {
        "SDD_PLUGINS_DIR": "./plugins",
        "SDD_REGISTRY_URL": "https://github.com/kelleysd-apps/sdd-plugins-marketplace"
      }
    }
  }
}
```

### MCP Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `marketplace-search` | Search plugin registry by keyword/domain | `query`, `category?`, `limit?` |
| `marketplace-install` | Download and install a plugin | `plugin_name`, `version?` |
| `marketplace-update` | Update installed plugin(s) | `plugin_name?` (all if omitted) |
| `marketplace-publish` | Publish plugin to registry | `plugin_path`, `--dry-run?` |
| `marketplace-list` | List installed plugins with versions | `--outdated?` |
| `marketplace-validate` | Validate plugin against standards | `plugin_path` |

### Registry Structure (GitHub-based)

```
sdd-plugins-marketplace/
  registry.json               # Plugin index
  plugins/
    sdd-domain-frontend/
      metadata.json           # Version history, downloads, ratings
      versions/
        0.1.0.tar.gz
        0.2.0.tar.gz
    sdd-domain-ai-ml/
      metadata.json
      versions/
        0.1.0.tar.gz
```

### Alternative: npm-based Registry

```bash
# Plugins published as npm packages
npm publish --registry=https://npm.pkg.github.com

# Install via MCP tool
marketplace-install sdd-domain-ai-ml
# → npm install @kelleysd-apps/sdd-domain-ai-ml --prefix=./plugins
```

## Implementation Plan

### Phase A: MCP Server Scaffold (1-2 days) ✅ COMPLETE

1. ✅ Created `mcp-servers/sdd-marketplace/` package
2. ✅ Implemented MCP server protocol (stdio transport, 6 tools)
3. ✅ Implemented `marketplace-list` (local inventory)
4. ✅ Implemented `marketplace-validate` (plugin.json + structure check)
5. ✅ Added to `.mcp.json`
6. ✅ Created registry.json seeded with 13 plugins
7. ✅ 18/18 tests passing

### Phase B: Registry Backend (2-3 days)

1. Create GitHub repo: `kelleysd-apps/sdd-plugins-marketplace`
2. Create `registry.json` schema
3. Seed with all 13 current plugins
4. Implement `marketplace-search`
5. Implement `marketplace-install` (git clone + extract)

### Phase C: Publish Flow (1-2 days)

1. Implement `marketplace-publish` with validation
2. Add CI: auto-validate on PR to marketplace repo
3. Version management (semver)
4. Implement `marketplace-update`

### Phase D: Framework Integration (1 day)

1. Add `.mcp.json` entry in framework template
2. Update `/initialize-project` to configure marketplace
3. Add to `migrate-to-plugins.sh`
4. Document in CLAUDE.md

## Security Considerations

- All published plugins validated against governance standards
- `loom-governance` dependency enforced for all registry plugins
- Plugin sandboxing via allowed-tools restrictions
- Version pinning to prevent supply-chain attacks
- Signature verification for community plugins (future)

## Connection to Downstream Projects

Any project using the SDD framework connects to the marketplace by:

1. Having `sdd-marketplace` in `.mcp.json` (added during `/initialize-project`)
2. Using Claude Code to search/install: "Find plugins for authentication"
3. MCP server handles download, validation, and placement in `plugins/`
4. Plugin auto-discovery picks up new plugin immediately

```
# Example user interaction
User: "Find me a plugin for AI/ML workflows"
Claude: Uses marketplace-search tool → returns sdd-domain-ai-ml
User: "Install it"
Claude: Uses marketplace-install tool → downloads to plugins/sdd-domain-ai-ml/
Claude: "Plugin installed. It provides 3 skills and 1 agent for ML workflows."
```

## RL Integration

Marketplace tracks cross-project RL metrics:
- Install count per plugin
- Average success_rate across installations
- Community ratings (future)
- Global selection_weight recommendations
