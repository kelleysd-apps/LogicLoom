---
name: mcp-server-setup
description: |
  MCP (Model Context Protocol) server selection and configuration skill using
  Docker MCP Toolkit as the primary orchestration method. Guides dynamic server
  discovery, installation via Docker gateway, and fallback to direct installation.
  Should be executed after /initialize-project to extend Claude Code's capabilities.
allowed-tools: Read, Write, Edit, Bash, WebSearch, WebFetch, AskUserQuestion
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_feedback: null
---

# MCP Server Setup Skill

## Purpose

Configure MCP servers for your project using **Docker MCP Toolkit** as the primary method. The toolkit provides:

- **Dynamic Discovery**: Search 310+ servers via `mcp-find` tool
- **Runtime Composition**: Add servers during conversations via `mcp-add`
- **Containerized Execution**: No local dependency management
- **Unified Gateway**: Single entry point for all MCPs

## When to Use

**Trigger**: After `/initialize-project` completes, before first `/specify`

**Workflow Position**:
```
/create-prd → /initialize-project → [MCP Setup] → /specify → /plan → /tasks
```

## Constitutional Principles

| Principle | Enforcement |
|-----------|-------------|
| **IX (Dependency Management)** | MCP servers are dependencies requiring justification |
| **VI (Git Approval)** | Configuration changes need user approval |
| **XI (Input Validation)** | Validate MCP server sources before installation |

---

## Installation Methods (Priority Order)

### Method 1: Docker MCP Toolkit (Primary - Recommended)

Docker MCP Toolkit is **pre-installed** during framework setup. It provides dynamic server management through Claude Code tools.

#### Discovery Tools

| Tool | Purpose | Example |
|------|---------|---------|
| `mcp-find` | Search 310+ servers | "Find servers for PostgreSQL" |
| `mcp-add` | Add server to session | "Add the supabase server" |
| `mcp-config-set` | Configure credentials | "Set SUPABASE_URL for supabase" |
| `mcp-exec` | Execute any tool | "Execute search_docs from supabase" |
| `code-mode` | Combine multiple MCPs | "Create a tool using supabase and github" |

#### Discovery Example

```
User: "What MCP servers are available for database operations?"

Claude uses mcp-find: Searches catalog for "database"

Result: Found 15 servers including:
- supabase: Supabase PostgreSQL, Auth, Storage
- postgres: Direct PostgreSQL connection
- sqlite: SQLite database operations
- prisma: Prisma ORM integration
- firebase: Firebase/Firestore
```

#### Installation Example

```
User: "Add the supabase MCP server"

Claude uses mcp-add: Adds supabase to session

Result: Server enabled. Configure with:
- SUPABASE_URL
- SUPABASE_ANON_KEY
- SUPABASE_SERVICE_ROLE_KEY
```

#### Configuration Example

```
User: "Configure my Supabase credentials"

Claude uses mcp-config-set: Sets each credential

Alternative: Add to .env file and server reads automatically
```

### Method 2: Direct Installation (Fallback)

For servers not in Docker catalog or special requirements.

**When to use**:
- Server not found in Docker catalog
- Need specific version or configuration
- Custom/internal MCP servers

**Configuration in `.mcp.json`**:
```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@org/mcp-server-name"],
      "env": {
        "API_KEY": "env:SERVER_API_KEY"
      }
    }
  }
}
```

**GitHub Registry**: https://github.com/modelcontextprotocol/servers

### Method 3: Self-Contained Docker Images

For custom or self-hosted servers.

```json
{
  "mcpServers": {
    "custom-server": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "my-registry/my-mcp-server:latest"]
    }
  }
}
```

---

## Docker MCP Toolkit CLI Commands

### Server Management

| Command | Purpose |
|---------|---------|
| `docker mcp catalog show docker-mcp` | Browse all 310+ available servers |
| `docker mcp server enable <name>` | Enable a server from catalog |
| `docker mcp server ls` | List enabled servers |
| `docker mcp server disable <name>` | Disable a server |

### Configuration

| Command | Purpose |
|---------|---------|
| `docker mcp config read` | View current configuration |
| `docker mcp secret set <key> <value>` | Set a secret value |

### Tools

| Command | Purpose |
|---------|---------|
| `docker mcp tools ls` | List all available tools |
| `docker mcp tools inspect <name>` | Show tool details |
| `docker mcp tools call <name>` | Test a tool |

### Gateway

| Command | Purpose |
|---------|---------|
| `docker mcp gateway run` | Run the MCP gateway (used by Claude Code) |
| `docker mcp gateway run --dry-run` | Test configuration without starting |

---

## Server Categories

### Category 1: Core Infrastructure (Pre-configured)

These tools are available via Docker MCP gateway by default:

| Tool | Purpose | Always Available |
|------|---------|------------------|
| `mcp-find` | Search server catalog | Yes |
| `mcp-add` | Add servers dynamically | Yes |
| `mcp-config-set` | Configure servers | Yes |
| `mcp-exec` | Execute any tool | Yes |
| `code-mode` | Combine MCPs in JavaScript | Yes |
| `mcp-remove` | Remove servers | Yes |

### Category 2: Database & Backend

| Need | Docker Server | Fallback (npx) |
|------|---------------|----------------|
| Supabase | `supabase` | `npx -y @anthropic-ai/mcp-supabase` |
| PostgreSQL | `postgres` | `npx -y @anthropic-ai/mcp-postgres` |
| SQLite | `SQLite` | `npx -y @anthropic-ai/mcp-sqlite` |
| Prisma | `prisma` | `npx -y @prisma/mcp-prisma` |
| Firebase | `firebase` | `npx -y @anthropic-ai/mcp-firebase` |
| MongoDB | `mongodb` | `npx -y @anthropic-ai/mcp-mongodb` |

### Category 3: Cloud & Deployment

| Need | Docker Server | Fallback (npx) |
|------|---------------|----------------|
| AWS | `aws` or `aws-api` | `npx -y @anthropic-ai/mcp-aws` |
| GCP | `gcp` | `npx -y @anthropic-ai/mcp-gcp` |
| Azure | `azure` or `aks` | `npx -y @anthropic-ai/mcp-azure` |
| Vercel | `vercel` | `npx -y @anthropic-ai/mcp-vercel` |
| Netlify | `netlify` | `npx -y @anthropic-ai/mcp-netlify` |
| Docker | `docker` | `npx -y @anthropic-ai/mcp-docker` |

### Category 4: Browser & Testing

| Need | Docker Server | Fallback (npx) |
|------|---------------|----------------|
| Browser automation | `browsermcp` | `npx -y @anthropic-ai/mcp-browsermcp` |
| Playwright | `playwright` | `npx -y @anthropic-ai/mcp-playwright` |
| Puppeteer | `puppeteer` | `npx -y @anthropic-ai/mcp-puppeteer` |

### Category 5: Search & Documentation

| Need | Docker Server | Fallback (npx) |
|------|---------------|----------------|
| AI Search | `perplexity` | `npx -y @anthropic-ai/mcp-perplexity` |
| Brave Search | `brave-search` | `npx -y @anthropic-ai/mcp-brave-search` |
| GitHub | `github-official` | `npx -y @anthropic-ai/mcp-github` |
| Notion | `notion` | `npx -y @anthropic-ai/mcp-notion` |
| Confluence | `atlassian` | `npx -y @anthropic-ai/mcp-confluence` |
| Library docs | `context7` | `npx -y @anthropic-ai/mcp-context7` |

### Category 6: Communication & Collaboration

| Need | Docker Server | Fallback (npx) |
|------|---------------|----------------|
| Slack | `slack` | `npx -y @anthropic-ai/mcp-slack` |
| Linear | `linear` | `npx -y @anthropic-ai/mcp-linear` |
| Jira | `atlassian` | `npx -y @anthropic-ai/mcp-jira` |
| Asana | `asana` | `npx -y @anthropic-ai/mcp-asana` |

---

## Selection Procedure

### Step 1: Analyze PRD Requirements

Read the PRD and extract:

1. **Technology Stack** (from Technical Constraints section)
   - Database type (PostgreSQL, MySQL, SQLite, MongoDB, etc.)
   - Cloud provider (AWS, GCP, Azure, Vercel, etc.)
   - Frontend framework (React, Vue, Next.js, etc.)

2. **Integration Requirements** (from Integration Requirements section)
   - External APIs
   - Third-party services
   - Communication tools

3. **Testing Strategy** (from Principle II section)
   - E2E testing needs
   - Browser automation requirements

### Step 2: Search Docker Catalog First

For each requirement, search the Docker catalog:

```
Use mcp-find: "Find servers for [requirement]"
```

**Priority Logic**:
1. If found in Docker catalog → use `mcp-add`
2. If not found → fall back to direct installation

### Step 3: Map Requirements to MCPs

Create a mapping table for user:

```markdown
## MCP Selection for [Project Name]

| Requirement | Source (PRD Section) | Method | Server | Priority |
|-------------|---------------------|--------|--------|----------|
| PostgreSQL | Technical Constraints | Docker | supabase | Required |
| AWS deploy | Technical Constraints | Docker | aws | Required |
| E2E testing | Principle II | Docker | browsermcp | Required |
| GitHub | Integration | Docker | github-official | Recommended |
| Slack notify | Integration | Docker | slack | Optional |
```

### Step 4: Present Recommendations to User

```markdown
## Recommended MCP Servers

Based on your PRD, I recommend the following MCP servers:

### Required (for core functionality)
1. **supabase** - PostgreSQL database with auth and storage
   - Method: Docker Toolkit (`mcp-add`)
   - Credentials: SUPABASE_URL, SUPABASE_ANON_KEY

2. **aws** - AWS infrastructure access
   - Method: Docker Toolkit (`mcp-add`)
   - Credentials: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY

3. **browsermcp** - E2E testing with browser automation
   - Method: Docker Toolkit (`mcp-add`)
   - Credentials: None required

### Recommended (enhance workflow)
4. **github-official** - GitHub issues and PR integration
   - Method: Docker Toolkit (`mcp-add`)
   - Credentials: GITHUB_TOKEN

### Optional (nice to have)
5. **slack** - Team notifications
   - Method: Docker Toolkit (`mcp-add`)
   - Credentials: SLACK_BOT_TOKEN

Would you like me to add these servers? I'll configure each one and guide you through any credentials needed.
```

### Step 5: Install Selected MCPs

For each approved MCP:

**Docker Toolkit Method**:
```
1. Use mcp-add: "Add the [server] server"
2. Use mcp-config-set: "Configure [credential] for [server]"
   OR add credentials to .env file
3. Verify with mcp-exec or test operation
```

**Direct Installation Method** (fallback):
```json
// Add to .mcp.json
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

### Step 6: Configure Credentials

**For Docker Toolkit servers**:
- Use `mcp-config-set` for each credential
- Or create/update `.env` file with values

**For direct installation**:
- Add to `.mcp.json` with `env:VAR_NAME` syntax
- Add actual values to `.env`

**.env Template**:
```bash
# Database
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Cloud
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=us-east-1

# APIs
GITHUB_TOKEN=ghp_your-token
SLACK_BOT_TOKEN=xoxb-your-token
```

### Step 7: Verify Connections

Test each server:
```bash
docker mcp tools ls  # Should show all enabled server tools
```

Or in conversation:
```
"List all tables in my database" (tests supabase)
"Show my GitHub repositories" (tests github)
"Take a screenshot of https://example.com" (tests browsermcp)
```

---

## Domain-to-MCP Mapping

Based on domain skills, recommend appropriate MCPs:

| Domain | Skills | Recommended MCPs |
|--------|--------|------------------|
| **Backend** | backend-operations, api-design, service-architecture | aws/gcp/azure, postgres/supabase |
| **Frontend** | frontend-operations | browsermcp, github-official, context7 |
| **Database** | database-operations, schema-design | postgres, supabase, firebase |
| **Testing** | testing-operations, qa-validation | browsermcp, playwright |
| **Security** | security-operations | browsermcp, playwright |
| **Specification** | unified-specification, sdd-planning, sdd-tasks | github-official, notion, linear |
| **DevOps** | devops-operations, monitoring | aws/gcp/azure, docker |
| **Performance** | performance-operations | aws/gcp/azure, docker |

---

## Troubleshooting

### Docker MCP Toolkit Issues

| Issue | Solution |
|-------|----------|
| `docker mcp: command not found` | Run framework setup script or install manually |
| Gateway won't start | Check Docker daemon is running |
| Server not in catalog | Use direct installation method |
| OAuth errors | Use `.env` credentials instead of OAuth |
| Timeout errors | Increase timeout or check network |

**Manual Installation**:
```bash
# Download and install Docker MCP Toolkit
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
curl -sL "https://github.com/docker/mcp-gateway/releases/download/v0.30.0/docker-mcp-${OS}-${ARCH}.tar.gz" | tar -xz -C ~/.docker/cli-plugins/
chmod +x ~/.docker/cli-plugins/docker-mcp
```

### Direct Installation Issues

| Issue | Solution |
|-------|----------|
| MCP won't start | Check Node.js v18+ installed |
| npx not found | Install npm: `npm install -g npm` |
| Authentication errors | Verify env vars in .env |
| Port conflicts | Check for other processes on port |

### Verification Script

Run the verification script to check installation:
```bash
./.specify/scripts/bash/verify-mcp-toolkit.sh
```

---

## Security Considerations

1. **Credential Management**
   - Store all secrets in `.env`
   - Use `env:VAR_NAME` syntax in MCP config
   - Never hardcode credentials
   - Rotate credentials regularly
   - Ensure `.env` is in `.gitignore`

2. **Access Scope**
   - Use least-privilege API keys
   - Limit MCP access to needed resources
   - Review permissions before granting

3. **Docker Toolkit Security**
   - Containerized execution provides isolation
   - CPU limit: 1 core per container
   - Memory limit: 2GB per container
   - Request filtering blocks sensitive data

4. **Audit Trail**
   - Log MCP usage for sensitive operations
   - Monitor for unusual activity
   - Document all configured MCPs

---

## Output Template

After completing MCP setup, provide this summary:

```markdown
## MCP Configuration Complete

**Project**: [Name]
**Date**: [Date]
**Method**: Docker MCP Toolkit (primary)

### Installed MCPs

| MCP | Method | Purpose | Status |
|-----|--------|---------|--------|
| supabase | Docker Toolkit | Database access | ✓ Configured |
| aws | Docker Toolkit | Cloud deployment | ✓ Configured |
| browsermcp | Docker Toolkit | E2E testing | ✓ Ready |
| github-official | Direct Install | GitHub integration | ✓ Configured |

### Environment Variables Required

Add to `.env`:
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_ANON_KEY` - Supabase anonymous key
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `GITHUB_TOKEN` - GitHub personal access token

### Docker Toolkit Tools Available

- `mcp-find` - Search for more servers
- `mcp-add` - Add servers during development
- `mcp-exec` - Execute tools from any server
- `code-mode` - Combine MCPs in JavaScript

### Verification Commands

Test your MCP connections:
- "Query the users table" (tests supabase)
- "List S3 buckets" (tests aws)
- "Open https://example.com in browser" (tests browsermcp)
- "Show my GitHub repos" (tests github-official)

### Next Steps

1. Add credentials to `.env`
2. Test each MCP with a simple operation
3. Run `/specify` for first feature
4. MCPs are now available to all agents
```

---

## Quick Reference

### Most Common Operations

```
# Search for servers
Ask Claude: "Find MCP servers for [need]"

# Add a server
Ask Claude: "Add the [server] MCP server"

# Configure credentials
Ask Claude: "Configure [credential] for [server]"
Or: Add to .env file

# List available tools
Run: docker mcp tools ls

# Browse catalog
Run: docker mcp catalog show docker-mcp
```

### File Locations

| File | Purpose |
|------|---------|
| `.mcp.json` | Project MCP configuration (direct install) |
| `.env` | Credentials (never commit!) |
| `~/.docker/mcp/` | Docker MCP Toolkit config |
| `~/.docker/cli-plugins/docker-mcp` | Docker MCP CLI plugin |

---

**Skill Version**: 2.0.0
**Last Updated**: 2025-12-02
**Constitutional Version**: 1.6.0
**Docker MCP Toolkit Version**: v0.30.0

## RL Feedback Loop

After skill execution completes, the RL feedback mechanism updates metrics:

### Success Criteria
- Task completed without errors
- Output validated by verifier (if applicable)
- User satisfaction (implicit from follow-up)

### Feedback Collection
```
ON SKILL COMPLETION:
  1. Capture execution result (success/failure)
  2. Record token usage
  3. Calculate execution duration
  4. Update rl_metrics via EMA:
     - success_rate = 0.9 * old_rate + 0.1 * (1 if success else 0)
     - selection_weight = adjusted based on success_rate
  5. Log to .docs/rl-metrics/skill-performance.json
```

### Metrics Update Trigger
```python
# Pseudo-code for RL update
def update_rl_metrics(skill_name: str, success: bool, tokens: int):
    metrics = load_skill_metrics(skill_name)
    metrics['invocation_count'] += 1
    metrics['success_rate'] = 0.9 * metrics['success_rate'] + 0.1 * (1 if success else 0)
    metrics['avg_tokens'] = 0.9 * metrics['avg_tokens'] + 0.1 * tokens
    metrics['selection_weight'] = max(0.1, min(1.0, metrics['success_rate']))
    metrics['last_feedback'] = datetime.utcnow().isoformat()
    save_skill_metrics(skill_name, metrics)
```

## Verifier Integration

### Pre-Completion Validation
Before marking this skill as complete, invoke verifier validation:

```
VERIFIER_CHECK:
  1. Output format validation
  2. Constitutional compliance check
  3. Quality threshold verification
  4. Domain-specific validation rules
```

### Verifier Handoff
```json
{
  "skill": "mcp-server-setup",
  "output": "<skill_output>",
  "validation_required": ["format", "compliance", "quality"],
  "threshold": 0.85
}
```

### On Verification Failure
- Log failure reason
- Update rl_metrics with failure
- Report to user with remediation options
