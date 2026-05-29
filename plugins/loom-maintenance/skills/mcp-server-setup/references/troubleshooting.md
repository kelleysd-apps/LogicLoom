# MCP Troubleshooting Guide

## Docker MCP Toolkit Issues

| Issue | Solution |
|-------|----------|
| `docker mcp: command not found` | Run framework setup script or install manually (see below) |
| Gateway won't start | Check Docker daemon is running: `docker info` |
| Server not in catalog | Use direct installation method via `.mcp.json` |
| OAuth errors | Use `.env` credentials instead of OAuth |
| Timeout errors | Increase timeout or check network connectivity |

### Manual Docker MCP Installation

```bash
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
curl -sL "https://github.com/docker/mcp-gateway/releases/download/v0.30.0/docker-mcp-${OS}-${ARCH}.tar.gz" | tar -xz -C ~/.docker/cli-plugins/
chmod +x ~/.docker/cli-plugins/docker-mcp
```

## Direct Installation Issues

| Issue | Solution |
|-------|----------|
| MCP won't start | Check Node.js v18+ installed |
| npx not found | Install npm: `npm install -g npm` |
| Authentication errors | Verify env vars in `.env` match expected names |
| Port conflicts | Check for other processes on the port |

## Verification

Run the verification script:
```bash
./.logic-loom/scripts/bash/verify-mcp-toolkit.sh
```

Or test in conversation:
- "Query the users table" (tests database MCP)
- "Show my GitHub repositories" (tests github MCP)
- "Take a screenshot of https://example.com" (tests browser MCP)

## File Locations

| File | Purpose |
|------|---------|
| `.mcp.json` | Project MCP configuration (direct install) |
| `.env` | Credentials (never commit!) |
| `~/.docker/mcp/` | Docker MCP Toolkit config |
| `~/.docker/cli-plugins/docker-mcp` | Docker MCP CLI plugin |
