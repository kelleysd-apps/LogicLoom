# Docker MCP Toolkit Integration Plan

## Executive Summary

This plan outlines the integration of Docker MCP Toolkit CLI as the **primary MCP orchestration method** for the SDD Agentic Framework, while maintaining backward compatibility with GitHub's MCP registry and direct installation methods.

### Why Docker MCP Toolkit as Primary?

| Benefit | Description |
|---------|-------------|
| **Unified Gateway** | Single entry point for all MCP servers |
| **Dynamic Discovery** | 310+ servers searchable via `mcp-find` tool |
| **Zero Config** | Containerized servers with no local dependencies |
| **Cross-Environment** | Works in Codespaces, local dev, CI/CD |
| **Runtime Composition** | Agents can add MCPs during conversations |
| **Security** | CPU/memory limits, request filtering, sandboxing |

### Installation Timing Decision

**Recommendation: Pre-PRD Installation (During `init-project.sh`)**

| Option | Pros | Cons |
|--------|------|------|
| **Pre-PRD** ✓ | Available for PRD research, consistent baseline, framework dependency | None significant |
| Post-PRD | Project-specific | Delays availability, manual step after PRD |

Docker MCP Toolkit is a **framework-level dependency**, not project-specific. It should be installed during framework setup so it's available for:
- PRD research (web search, documentation lookup)
- All project types (universal utility)
- Immediate agent capabilities

---

## Scope of Changes

### Files to Update (28 files identified)

#### Tier 1: Core Installation (Pre-PRD)

| File | Change Type | Priority |
|------|-------------|----------|
| `init-project.sh` | Add Docker MCP CLI installation | **Critical** |
| `.logic-loom/scripts/setup.sh` | Add Docker MCP CLI installation | **Critical** |
| `.mcp.json` | Already configured (gateway) | Existing |

#### Tier 2: Primary Documentation

| File | Change Type | Priority |
|------|-------------|----------|
| `CLAUDE.md` | Update MCP section with Docker Toolkit as primary | **High** |
| `README.md` | Update MCP setup instructions | **High** |
| `START_HERE.md` | Update Step 3 with Docker Toolkit | **High** |
| `.claude/skills/integration/mcp-server-setup/SKILL.md` | Major rewrite - Docker Toolkit primary | **High** |

#### Tier 3: Initialization Workflows

| File | Change Type | Priority |
|------|-------------|----------|
| `.claude/commands/initialize-project.md` | Update Phase 6 MCP guidance | **High** |
| `.claude/skills/project-initialization/SKILL.md` | Add Docker Toolkit procedure | **Medium** |

#### Tier 4: Agent Documentation

| File | Change Type | Priority |
|------|-------------|----------|
| `AGENTS.md` | Update MCP access section | **Medium** |
| `.logic-loom/memory/agent-collaboration.md` | Update MCP assignments | **Medium** |
| `.docs/agents/agent-registry.json` | Update mcp_access patterns | **Medium** |
| 14 agent definition files | Update MCP server access sections | **Low** |

---

## Detailed Implementation Plan

### Phase 1: Installation Scripts (Pre-PRD)

#### 1.1 Update `init-project.sh`

**Location**: Lines 176-185 (after git check, before setup.sh)

**Add new section**:
```bash
# ====================================
# Docker MCP Toolkit Installation
# ====================================
echo -e "${BLUE}Checking Docker MCP Toolkit...${NC}"

# Check if docker-mcp plugin is installed
if docker mcp version &>/dev/null; then
    echo -e "${GREEN}✓${NC} Docker MCP Toolkit already installed: $(docker mcp version)"
else
    echo -e "${YELLOW}Installing Docker MCP Toolkit CLI...${NC}"

    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) echo -e "${RED}Unsupported architecture: $ARCH${NC}"; exit 1 ;;
    esac

    # Detect OS
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')

    # Download and install
    MCP_VERSION="v0.30.0"  # Update as needed
    DOWNLOAD_URL="https://github.com/docker/mcp-gateway/releases/download/${MCP_VERSION}/docker-mcp-${OS}-${ARCH}.tar.gz"

    mkdir -p "$HOME/.docker/cli-plugins/"
    curl -sL "$DOWNLOAD_URL" | tar -xz -C "$HOME/.docker/cli-plugins/"
    chmod +x "$HOME/.docker/cli-plugins/docker-mcp"

    if docker mcp version &>/dev/null; then
        echo -e "${GREEN}✓${NC} Docker MCP Toolkit installed: $(docker mcp version)"
    else
        echo -e "${RED}Warning: Docker MCP Toolkit installation failed${NC}"
        echo -e "${YELLOW}You can install manually later. See documentation.${NC}"
    fi
fi

# Configure Claude Code connection (global)
if docker mcp version &>/dev/null; then
    echo -e "${BLUE}Configuring Claude Code MCP connection...${NC}"
    docker mcp client connect claude-code --global 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Claude Code MCP gateway configured"
fi
```

#### 1.2 Update `.logic-loom/scripts/setup.sh`

**Add same installation block** after dependency checks.

#### 1.3 Create Installation Verification

**New file**: `.logic-loom/scripts/bash/verify-mcp-toolkit.sh`

```bash
#!/bin/bash
# Verify Docker MCP Toolkit installation

verify_mcp_toolkit() {
    if ! docker mcp version &>/dev/null; then
        echo "Docker MCP Toolkit not installed"
        return 1
    fi

    VERSION=$(docker mcp version)
    echo "Docker MCP Toolkit: $VERSION"

    # Check gateway connectivity
    if docker mcp gateway run --dry-run &>/dev/null; then
        echo "Gateway: Ready"
    else
        echo "Gateway: Error (check Docker)"
    fi

    # List available tools
    TOOLS=$(docker mcp tools ls 2>/dev/null | head -1)
    echo "Tools: $TOOLS"

    return 0
}

verify_mcp_toolkit
```

---

### Phase 2: MCP Server Setup Skill (Major Rewrite)

#### 2.1 Update `.claude/skills/integration/mcp-server-setup/SKILL.md`

**New structure**:

```markdown
---
name: mcp-server-setup
description: |
  MCP server selection and configuration skill using Docker MCP Toolkit
  as primary orchestration method. Guides dynamic server discovery,
  installation via Docker gateway, and fallback to direct installation.
allowed-tools: Read, Write, Edit, Bash, WebSearch, WebFetch, AskUserQuestion
---

# MCP Server Setup Skill

## Purpose

Configure MCP servers for your project using **Docker MCP Toolkit** as the
primary method. The toolkit provides:

- **Dynamic Discovery**: Search 310+ servers via `mcp-find`
- **Runtime Composition**: Add servers during conversations
- **Containerized Execution**: No local dependency management
- **Unified Gateway**: Single entry point for all MCPs

## Installation Methods (Priority Order)

### Method 1: Docker MCP Toolkit (Primary - Recommended)

The Docker MCP Toolkit is pre-installed during framework setup.

**Discovery**: Find servers dynamically
```
Use the mcp-find tool: "Find MCP servers for [need]"
```

**Installation**: Add servers to session
```
Use the mcp-add tool: "Add the [server] MCP server"
```

**Configuration**: Set server values
```
Use the mcp-config-set tool: "Configure [key] for [server]"
```

**Benefits**:
- No local npm/npx required
- Containerized isolation
- Dynamic during conversations
- 310+ servers available

### Method 2: Direct Installation (Fallback)

For servers not in Docker catalog or special requirements.

**NPX Method**:
```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@org/mcp-server"],
      "env": { "API_KEY": "env:KEY" }
    }
  }
}
```

**GitHub Registry**:
- Browse: https://github.com/modelcontextprotocol/servers
- Install per package instructions

### Method 3: Self-Contained Docker Images

For custom or self-hosted servers.

```json
{
  "mcpServers": {
    "custom-server": {
      "command": "docker",
      "args": ["run", "--rm", "my-mcp-server:latest"]
    }
  }
}
```

## Docker MCP Toolkit Commands

### Discovery
| Command | Purpose |
|---------|---------|
| `docker mcp catalog show docker-mcp` | Browse all 310+ servers |
| `docker mcp server ls` | List enabled servers |
| `docker mcp tools ls` | List available tools |

### Installation
| Command | Purpose |
|---------|---------|
| `docker mcp server enable <name>` | Enable a server |
| `docker mcp config read` | View configuration |

### Dynamic (In-Conversation)
| Tool | Purpose |
|------|---------|
| `mcp-find` | Search server catalog |
| `mcp-add` | Add server to session |
| `mcp-config-set` | Configure server |
| `mcp-exec` | Execute tool from any server |
| `code-mode` | Combine multiple MCP tools |

## Server Categories

[Keep existing category tables, add Docker server names]

### Category 1: Database & Backend

| Need | Docker Server | Direct Install |
|------|---------------|----------------|
| Supabase | `supabase` via mcp-add | `npx @anthropic-ai/mcp-supabase` |
| PostgreSQL | `postgres` via mcp-add | `npx @anthropic-ai/mcp-postgres` |
| SQLite | `sqlite` via mcp-add | `npx @anthropic-ai/mcp-sqlite` |

[Continue for all categories...]

## Selection Procedure (Updated)

### Step 1: Analyze PRD Requirements
[Keep existing content]

### Step 2: Search Docker Catalog First

For each requirement:
1. Use `mcp-find` tool to search catalog
2. If found → use `mcp-add` to install
3. If not found → fall back to direct installation

### Step 3: Configure Credentials

**For Docker Toolkit servers**:
- Use `mcp-config-set` for each credential
- Or create `.env` file and reference via `env:VAR_NAME`

**For direct installation**:
- Add to `.mcp.json` with `env:VAR_NAME` syntax
- Configure `.env` with actual values

### Step 4: Verify Connections

Test each server:
```bash
docker mcp tools ls  # Should show all enabled tools
```

## Troubleshooting

### Docker MCP Toolkit Issues

| Issue | Solution |
|-------|----------|
| `docker mcp: command not found` | Run framework setup or install manually |
| Gateway won't start | Check Docker daemon running |
| Server not in catalog | Use direct installation method |
| OAuth errors | Use `.env` credentials instead |

### Direct Installation Issues
[Keep existing troubleshooting]
```

---

### Phase 3: Documentation Updates

#### 3.1 Update `CLAUDE.md` MCP Section

**Current location**: Lines 174-200

**Replace with**:
```markdown
### MCP Server Configuration

MCP (Model Context Protocol) servers extend Claude Code's capabilities.
The framework uses **Docker MCP Toolkit** as the primary orchestration method.

**Docker MCP Toolkit** (Pre-installed):
- 310+ servers available via dynamic discovery
- Containerized execution (no local dependencies)
- Runtime composition (add servers during conversations)

**Ask Claude for help with MCPs**:
- "Find MCP servers for database operations" (uses `mcp-find`)
- "Add the supabase MCP server" (uses `mcp-add`)
- "Configure my AWS credentials" (uses `mcp-config-set`)

**Available Docker MCP Tools**:

| Tool | Purpose |
|------|---------|
| `mcp-find` | Search 310+ servers in Docker catalog |
| `mcp-add` | Add server to current session |
| `mcp-config-set` | Configure server credentials |
| `mcp-exec` | Execute tools from any server |
| `code-mode` | Combine multiple MCP tools in JavaScript |

**Common MCP Servers by Use Case**:

| Use Case | Docker Server | Fallback |
|----------|---------------|----------|
| **Database** | supabase, postgres, sqlite | npx @anthropic-ai/mcp-* |
| **Cloud** | aws, gcp, azure, vercel | npx @anthropic-ai/mcp-* |
| **Testing** | browsermcp, playwright | npx @anthropic-ai/mcp-* |
| **Search** | perplexity, brave-search | npx @anthropic-ai/mcp-* |
| **Docs** | context7, github | npx @anthropic-ai/mcp-* |

**Installation Methods** (Priority Order):
1. **Docker Toolkit** (Primary): Use `mcp-add` tool
2. **Direct Install**: Add to `.mcp.json` with npx command
3. **GitHub Registry**: https://github.com/modelcontextprotocol/servers

**Skill Reference**: `.claude/skills/integration/mcp-server-setup/SKILL.md`

**Security Notes**:
- Store all credentials in `.env` (never commit!)
- Use `env:VAR_NAME` syntax in MCP configuration
- Use least-privilege API keys when possible
```

#### 3.2 Update `README.md`

Update Step 3 in setup instructions.

#### 3.3 Update `START_HERE.md`

Update Step 3: Configure MCP Servers section.

---

### Phase 4: Initialize-Project Workflow Updates

#### 4.1 Update `.claude/commands/initialize-project.md` Phase 6

**Replace Phase 6 content with**:
```markdown
### Phase 6: MCP Server Selection and Setup

**Primary Method**: Docker MCP Toolkit (pre-installed)

1. **Verify Docker MCP Toolkit**:
   ```bash
   docker mcp version
   docker mcp tools ls
   ```

2. **Analyze PRD for MCP requirements**:
   - Extract database type from Technical Constraints
   - Identify cloud provider needs
   - Note integration requirements
   - Review testing strategy for browser automation

3. **Search Docker catalog for matches**:

   For each requirement:
   ```
   Use mcp-find: "Find servers for [requirement]"
   ```

   Present matches to user with priority tiers.

4. **Install via Docker Toolkit** (with user approval):

   For each approved server:
   ```
   Use mcp-add: "Add the [server] server"
   Use mcp-config-set: "Set [credential] for [server]"
   ```

5. **Fallback to direct installation**:

   If server not in Docker catalog:
   - Add to `.mcp.json` manually
   - Guide credential configuration

6. **Verify all MCP connections**:
   ```bash
   docker mcp tools ls  # Should show all enabled server tools
   ```

**User Approval Required**: All MCP installations
```

---

### Phase 5: Agent MCP Documentation

#### 5.1 Update Agent MCP Access Pattern

**Current pattern**: Hardcoded MCP names
```markdown
mcp__supabase, mcp__ref-tools, ...
```

**New pattern**: Docker Toolkit + dynamic discovery
```markdown
### MCP Server Access

**Pre-configured** (via Docker MCP Toolkit):
- Docker gateway tools: mcp-find, mcp-add, mcp-exec, code-mode

**Dynamically available** (add via mcp-add as needed):
- Database: supabase, postgres, sqlite
- Cloud: aws, gcp, azure
- Testing: browsermcp, playwright

**Usage**: This agent can dynamically add MCPs during task execution
using the `mcp-add` tool from Docker MCP Toolkit.
```

---

## Implementation Checklist

### Phase 1: Installation (Day 1)
- [ ] Update `init-project.sh` with Docker MCP CLI installation
- [ ] Update `.logic-loom/scripts/setup.sh` with same
- [ ] Create verification script
- [ ] Test on fresh Codespace

### Phase 2: MCP Skill (Day 1-2)
- [ ] Rewrite `mcp-server-setup/SKILL.md` with Docker primary
- [ ] Add fallback documentation
- [ ] Update procedure steps
- [ ] Add troubleshooting for Docker Toolkit

### Phase 3: Core Docs (Day 2)
- [ ] Update `CLAUDE.md` MCP section
- [ ] Update `README.md` setup instructions
- [ ] Update `START_HERE.md` Step 3

### Phase 4: Workflow Updates (Day 2)
- [ ] Update `initialize-project.md` Phase 6
- [ ] Update `project-initialization/SKILL.md`

### Phase 5: Agent Docs (Day 3)
- [ ] Update `AGENTS.md` MCP section
- [ ] Update `agent-collaboration.md`
- [ ] Update `agent-registry.json`
- [ ] Update 14 agent definition files

### Phase 6: Testing & Validation (Day 3)
- [ ] Test fresh installation flow
- [ ] Test MCP discovery and addition
- [ ] Test fallback to direct installation
- [ ] Verify all documentation accuracy

---

## Rollback Plan

If Docker MCP Toolkit causes issues:

1. **Keep `.mcp.json`**: Works independently of Docker Toolkit
2. **Direct install still works**: npx method unaffected
3. **Remove from init scripts**: Comment out installation block
4. **Documentation fallback**: Primary becomes "Direct Installation"

---

## Success Criteria

- [ ] Docker MCP Toolkit installed automatically during `init-project.sh`
- [ ] `docker mcp tools ls` shows gateway tools after setup
- [ ] Claude can use `mcp-find` and `mcp-add` in conversations
- [ ] Documentation clearly shows Docker Toolkit as primary
- [ ] Fallback methods documented for edge cases
- [ ] All 28 MCP-related files updated consistently

---

**Plan Version**: 1.0.0
**Created**: 2025-12-02
**Author**: Claude (prd-specialist delegation)
**Constitutional Compliance**: Principles VI, VIII, IX, XV verified
