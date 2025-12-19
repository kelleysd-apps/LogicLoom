# Browser MCP Integration Setup Guide

**Version**: 1.0.0
**Feature**: 003-governance-browser-enhancement
**MCP Servers**: browsermcp, chrome-devtools

---

## Overview

This guide covers the setup and configuration of Browser MCP integration for the SDD Framework, enabling:

- **Browser automation** via Browser MCP extension
- **Chrome DevTools debugging** via DevTools MCP
- **Web scraping and testing** capabilities
- **Visual governance** (screenshot-based validation)

---

## Prerequisites

### Required

- ✅ **Node.js** (v18 or later) - For `npx` package execution
- ✅ **Chrome/Chromium** browser - For browser automation
- ✅ **SDD Framework** - Base framework must be installed

### Optional

- **Browser MCP Chrome Extension** - For enhanced browser control
- **Chrome DevTools Protocol knowledge** - For advanced debugging

---

## Installation Methods

### Method 1: Docker MCP Toolkit (Recommended)

The framework includes Docker MCP Toolkit which provides access to 310+ MCP servers including browser automation.

**Already configured in `.mcp.json`**:

```json
{
  "mcpServers": {
    "docker": {
      "command": "docker",
      "args": ["mcp", "gateway", "run"]
    }
  }
}
```

**Add browsermcp dynamically**:

```bash
# Ask Claude to add browsermcp
"Add the browsermcp server using Docker MCP Toolkit"

# Or use mcp-add tool directly (if you know the server name)
mcp-add browsermcp
```

**Advantages**:
- No local dependencies
- Containerized execution
- 310+ servers available
- Runtime installation

---

### Method 2: Direct npx Installation (Alternative)

**Already configured in `.mcp.json`**:

```json
{
  "mcpServers": {
    "browsermcp": {
      "type": "stdio",
      "command": "npx",
      "args": ["browsermcp@latest"],
      "description": "Browser automation via Browser MCP extension"
    },
    "chrome-devtools": {
      "type": "stdio",
      "command": "npx",
      "args": ["chrome-devtools-mcp@latest"],
      "description": "Chrome DevTools debugging via MCP"
    }
  }
}
```

**Advantages**:
- Direct execution (no Docker)
- Latest versions
- Simple configuration

**Disadvantages**:
- Requires Node.js locally
- No version pinning
- Less isolation

---

## Browser MCP Chrome Extension Setup

### Step 1: Install Extension

1. **Download Extension**:
   - Visit Chrome Web Store
   - Search for "Browser MCP" or "Model Context Protocol"
   - Click "Add to Chrome"

   *OR manually*:

   - Clone repository: `git clone https://github.com/modelcontextprotocol/servers.git`
   - Navigate to `servers/src/browsermcp`
   - Load unpacked extension in Chrome

2. **Verify Installation**:
   - Open Chrome Extensions page: `chrome://extensions`
   - Confirm "Browser MCP" is listed and enabled

### Step 2: Configure Extension

1. **Open Extension Settings**:
   - Click Browser MCP icon in Chrome toolbar
   - Select "Options" or "Settings"

2. **Enable MCP Server**:
   - Toggle "Enable MCP Server" to ON
   - Note the connection URL (typically `ws://localhost:3000`)

3. **Configure Permissions**:
   - Grant permissions for:
     - ✅ Read and change data on all websites
     - ✅ Manage tabs
     - ✅ Take screenshots
     - ✅ Access browser history (optional)

### Step 3: Test Connection

```bash
# Ask Claude to test browser MCP
"Test the browsermcp connection"

# Or test manually
npx browsermcp@latest --version
```

**Expected Output**: Version number or connection confirmation

---

## Chrome DevTools MCP Setup

### Step 1: Enable Remote Debugging

1. **Launch Chrome with Remote Debugging**:

   **Windows**:
   ```cmd
   "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9222
   ```

   **macOS**:
   ```bash
   /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222
   ```

   **Linux**:
   ```bash
   google-chrome --remote-debugging-port=9222
   ```

2. **Verify Remote Debugging**:
   - Open `http://localhost:9222/json` in browser
   - Should see JSON with open tabs

### Step 2: Configure DevTools MCP

**Already configured in `.mcp.json`**:

```json
{
  "chrome-devtools": {
    "type": "stdio",
    "command": "npx",
    "args": ["chrome-devtools-mcp@latest"],
    "description": "Chrome DevTools debugging via MCP"
  }
}
```

### Step 3: Test DevTools Connection

```bash
# Ask Claude to inspect browser console
"Use chrome-devtools to get console logs from the current page"
```

---

## Configuration Validation

### Verify .mcp.json

```bash
# Check MCP configuration
cat .mcp.json

# Should include both browsermcp and chrome-devtools
```

**Expected**:
```json
{
  "mcpServers": {
    "docker": {
      "command": "docker",
      "args": ["mcp", "gateway", "run"]
    },
    "browsermcp": {
      "type": "stdio",
      "command": "npx",
      "args": ["browsermcp@latest"],
      "description": "Browser automation via Browser MCP extension"
    },
    "chrome-devtools": {
      "type": "stdio",
      "command": "npx",
      "args": ["chrome-devtools-mcp@latest"],
      "description": "Chrome DevTools debugging via MCP"
    }
  }
}
```

### Test MCP Servers

```bash
# List available MCP tools
docker mcp tools ls

# Or ask Claude
"List all available MCP tools"
```

**Expected Tools** (browsermcp):
- `browser_navigate`
- `browser_screenshot`
- `browser_click`
- `browser_fill`
- `browser_console_logs`

**Expected Tools** (chrome-devtools):
- `devtools_get_console`
- `devtools_get_network`
- `devtools_performance_trace`
- `devtools_evaluate_js`

---

## Usage Examples

### Example 1: Navigate to URL

```bash
# Ask Claude
"Navigate to https://example.com and take a screenshot"
```

**Claude will**:
1. Use `browser_navigate` tool
2. Wait for page load
3. Use `browser_screenshot` tool
4. Save/display screenshot

---

### Example 2: Fill Form

```bash
# Ask Claude
"Go to the login page and fill in username 'test@example.com'"
```

**Claude will**:
1. Navigate to login page
2. Use `browser_click` to focus username field
3. Use `browser_fill` to enter email
4. Confirm completion

---

### Example 3: Get Console Logs

```bash
# Ask Claude
"Check the console for any errors on the current page"
```

**Claude will**:
1. Use `browser_console_logs` tool
2. Parse console output
3. Report errors/warnings

---

### Example 4: Network Inspection

```bash
# Ask Claude
"Show me all API calls made by this page"
```

**Claude will**:
1. Use `devtools_get_network` tool
2. Filter for XHR/Fetch requests
3. List endpoints and responses

---

## Security Considerations

### API Keys and Credentials

**Browser MCP**: No API keys required (runs locally)

**Chrome DevTools**: No credentials needed (local debugging port)

### Permissions

**Browser MCP Extension** requires:
- ✅ **Read/write all websites** - For automation and screenshots
- ⚠️ **Risk**: Extension has full page access
- 🔒 **Mitigation**: Only use on trusted sites, disable when not needed

**Chrome Remote Debugging**:
- ✅ **Local only** - Debugging port (9222) typically not exposed to network
- ⚠️ **Risk**: If exposed, full browser control possible
- 🔒 **Mitigation**: Use firewall, bind to localhost only

### Best Practices

1. **Disable when not in use**:
   ```bash
   # Disable Browser MCP extension
   # Chrome -> Extensions -> Browser MCP -> Toggle OFF
   ```

2. **Close debugging port**:
   ```bash
   # Close Chrome instance with remote debugging enabled
   # Launch normal Chrome instance
   ```

3. **Review MCP tool usage**:
   ```bash
   # Check governance audit logs
   cat .docs/governance/audit/$(date +%Y-%m-%d)/session-*.json
   ```

4. **No secrets in browser automation**:
   - Never automate login with real credentials
   - Use test accounts only
   - Avoid production environments

---

## Troubleshooting

### Browser MCP Not Found

**Symptom**: "MCP server 'browsermcp' not found"

**Fix**:
```bash
# Install manually
npm install -g browsermcp

# Or ensure npx is working
npx browsermcp@latest --version
```

---

### Extension Not Connecting

**Symptom**: Browser MCP extension shows "Disconnected"

**Checks**:
1. Is extension enabled? (`chrome://extensions`)
2. Is MCP server configured in `.mcp.json`?
3. Is Claude Code running with MCP support?

**Fix**:
```bash
# Restart Claude Code
# Reload extension (Chrome Extensions -> Reload)
```

---

### Remote Debugging Port Already in Use

**Symptom**: "Port 9222 already in use"

**Fix**:
```bash
# Find process using port
lsof -i :9222        # macOS/Linux
netstat -ano | findstr :9222    # Windows

# Kill Chrome instance
# Relaunch with --remote-debugging-port=9222
```

---

### Screenshots Not Working

**Symptom**: `browser_screenshot` tool fails

**Checks**:
1. Is page fully loaded?
2. Does extension have screenshot permission?
3. Is viewport visible (not minimized)?

**Fix**:
```bash
# Ensure Chrome window is visible
# Grant screenshot permission to extension
# Try manual screenshot (Extension icon -> Take Screenshot)
```

---

### Network Tab Empty

**Symptom**: `devtools_get_network` returns no data

**Checks**:
1. Was remote debugging enabled before page load?
2. Is DevTools Protocol recording network events?

**Fix**:
```bash
# Close page
# Relaunch Chrome with --remote-debugging-port=9222
# Navigate to page again
# Retry network inspection
```

---

## Performance Considerations

### Browser MCP
- **Latency**: ~100-500ms per operation (depends on page load)
- **Resource Usage**: Chrome instance (~200-500MB RAM)
- **Concurrency**: Single browser instance (one operation at a time)

### Chrome DevTools MCP
- **Latency**: ~50-200ms per query
- **Resource Usage**: Minimal (protocol overhead only)
- **Concurrency**: Multiple connections possible

### Optimization Tips

1. **Reuse browser instances**:
   - Keep Chrome open for multiple operations
   - Avoid launching new instances per task

2. **Batch operations**:
   ```bash
   "Navigate to example.com, fill login form, and take screenshot"
   # Better than 3 separate requests
   ```

3. **Use headless mode** (for automation without UI):
   ```bash
   google-chrome --headless --remote-debugging-port=9222
   ```

---

## Related Documentation

- **Browser Automation Examples**: `.docs/governance/browser-automation-examples.md`
- **MCP Configuration**: `CLAUDE.md` (MCP Server Configuration section)
- **Docker MCP Toolkit**: See CLAUDE.md for `mcp-find` and `mcp-add` tools
- **Governance Architecture**: `.docs/governance/hybrid-architecture.md`

---

## Version History

**v1.0.0** (2025-12-19)
- Initial setup guide
- Browser MCP extension configuration
- Chrome DevTools MCP setup
- Security best practices
- Troubleshooting guide

---

*This guide is part of Feature 003: Governance Browser Enhancement*
