---
name: mcp-server-setup
description: |
  MCP server selection and configuration using Docker MCP Toolkit as the primary
  method. Guides discovery, installation, and credential setup. Run after
  /initialize-project to extend Claude Code's capabilities.

  Triggered by: "set up MCP servers", "configure MCP", "add MCP server",
  "what MCP servers are available", "install database MCP"
allowed-tools: Read, Write, Edit, Bash, WebSearch, WebFetch, AskUserQuestion
category: maintenance
---

# MCP Server Setup Skill

## Purpose

Configure MCP servers for the project using **Docker MCP Toolkit** (primary) or direct installation (fallback).

**Workflow position**: `/create-prd` → `/initialize-project` → **MCP Setup** → `/specification`

---

## Procedure

### Step 1: Analyze Project Requirements

Read the PRD and extract:
1. **Technology stack** — database, cloud provider, frontend framework
2. **Integration needs** — external APIs, third-party services
3. **Testing strategy** — browser automation, E2E requirements

### Step 2: Search Docker Catalog

For each requirement, search using the `mcp-find` tool:
```
"Find MCP servers for [requirement]"
```

**Priority**: Docker catalog first → direct installation fallback.

For the full server catalog, read `references/server-catalog.md`.

### Step 3: Build Recommendation Table

Present a mapping to the user:

```markdown
| Requirement | Method | Server | Priority |
|-------------|--------|--------|----------|
| PostgreSQL | Docker Toolkit | supabase | Required |
| AWS deploy | Docker Toolkit | aws | Required |
| E2E testing | Docker Toolkit | browsermcp | Required |
| GitHub | Docker Toolkit | github-official | Recommended |
```

### Step 4: Install Approved MCPs

**Docker Toolkit** (preferred):
1. Use `mcp-add` to add the server
2. Use `mcp-config-set` to configure credentials (or add to `.env`)
3. Verify with `mcp-exec` or a test operation

**Direct installation** (fallback — for servers not in Docker catalog):
Add to `.mcp.json`:
```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@org/mcp-server"],
      "env": {
        "API_KEY": "env:API_KEY"
      }
    }
  }
}
```

### Step 5: Configure Credentials

Add credentials to `.env` (never commit this file):
```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
AWS_ACCESS_KEY_ID=your-access-key
GITHUB_TOKEN=ghp_your-token
```

### Step 6: Verify Connections

Test each server:
```bash
docker mcp tools ls  # List all enabled server tools
```

Or test in conversation with a simple query per server.

### Step 7: Output Summary

```markdown
## MCP Configuration Complete

| MCP | Method | Purpose | Status |
|-----|--------|---------|--------|
| supabase | Docker Toolkit | Database | Configured |
| aws | Docker Toolkit | Cloud | Configured |
| browsermcp | Docker Toolkit | E2E testing | Ready |
```

---

## Docker MCP Toolkit CLI Reference

### Server Management

| Command | Purpose |
|---------|---------|
| `docker mcp catalog show docker-mcp` | Browse 310+ available servers |
| `docker mcp server enable <name>` | Enable a server |
| `docker mcp server ls` | List enabled servers |
| `docker mcp server disable <name>` | Disable a server |

### Configuration & Tools

| Command | Purpose |
|---------|---------|
| `docker mcp config read` | View current config |
| `docker mcp secret set <key> <value>` | Set a secret |
| `docker mcp tools ls` | List available tools |
| `docker mcp tools call <name>` | Test a tool |
| `docker mcp gateway run` | Start the gateway |

---

## Security

1. Store all secrets in `.env` — use `env:VAR_NAME` syntax in MCP config
2. Never hardcode credentials
3. Use least-privilege API keys
4. Docker Toolkit provides container isolation (1 CPU, 2GB RAM per container)
5. Ensure `.env` is in `.gitignore`

## References

- **Server catalog**: `references/server-catalog.md` — full tables of 310+ servers by category
- **Troubleshooting**: `references/troubleshooting.md` — Docker and direct install issues
- **GitHub Registry**: https://github.com/modelcontextprotocol/servers
