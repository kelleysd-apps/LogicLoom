---
description: Initialize project after PRD completion - customizes constitution, agents, and workflows based on project needs.
---

> ⚠️ **DEPRECATED**: This command has moved to `plugins/sdd-maintenance/commands/initialize-project.md`.
> The plugin version is the canonical source. This monolithic version will be removed in v5.0.
> 
> **Plugin-First Architecture (Principle XVI)**: All commands now live within their respective plugins.


**AGENT REQUIREMENT**: This command should be executed by the prd-specialist agent.

**If you are NOT the prd-specialist**, delegate this work immediately:
```
Use the Task tool to invoke prd-specialist:
- subagent_type: "prd-specialist"
- description: "Execute /initialize-project command"
- prompt: "Execute the /initialize-project command to customize the framework based on the completed PRD. Arguments: $ARGUMENTS"
```

The prd-specialist is specialized for:
- PRD analysis and interpretation
- Constitutional customization
- Project-specific workflow configuration
- Agent training and modification
- SSOT integration across framework documents

---

## Execution Instructions (for prd-specialist)

### Prerequisites Check

1. **Verify PRD exists and is complete**:
   - Check for `.docs/prd/prd.md`
   - Validate PRD completeness using review checklist
   - If PRD missing or incomplete, abort and inform user to run `/create-prd` first

2. **Load supporting skill**:
   - Read `.claude/skills/project-initialization/SKILL.md` for detailed procedural guidance

---

## Initialization Workflow

### Phase 1: PRD Analysis

1. **Read the completed PRD** at `.docs/prd/prd.md`
2. **Extract key customizations**:
   - Project name and vision
   - Constitutional principle customizations (all 15 principles)
   - Custom agents identified in Principle X section
   - Technical constraints and requirements
   - Access tiers (from Principle XIII)
   - Design system requirements (from Principle XII)
   - Success metrics for validation

3. **Create initialization report**:
   ```markdown
   ## PRD Analysis Summary

   **Project**: [name]
   **Focus Areas**: [frontend/backend/fullstack/data/etc.]
   **Detected Domains**: [list from trigger keywords]

   ### Customizations Required
   - Constitution updates: [count]
   - Custom agents: [count]
   - Workflow modifications: [list]
   ```

---

### Phase 2: Constitution Customization

**File**: `.specify/memory/constitution.md`

For each principle (I-XV), apply project-specific customizations from PRD:

1. **Read current constitution** (ensure backup exists)
2. **Apply principle customizations**:
   - Add project-specific guidance under each principle
   - Document exceptions with justifications
   - Update quality thresholds if specified
   - Add project-specific examples where helpful

3. **Update metadata**:
   - Add project customization note at top
   - Update "Last Amended" date
   - Increment patch version (e.g., 1.5.0 → 1.5.1)

4. **Validation**:
   - Run `.specify/scripts/bash/constitutional-check.sh`
   - Ensure no conflicts between customizations

**Example customization format**:
```markdown
### Principle II: Test-First Development (IMMUTABLE - NON-NEGOTIABLE)

[Existing content...]

**Project Customization** ([Project Name]):
- Test framework: Jest + React Testing Library
- Coverage threshold: 85% (above default 80%)
- E2E tool: Playwright
- Contract testing: MSW for API mocking
```

---

### Phase 3: Agent Training and Modification

**Based on PRD Principle X (Agent Delegation Protocol)**:

1. **Review existing agents** in `.claude/agents/`
2. **Create custom agents** identified in PRD:
   - Use `/create-agent` command for each
   - Apply PRD-specified purposes and scopes
   - Configure domain-specific tool restrictions

3. **Update agent context files**:
   - Create/update `.docs/agents/[dept]/[agent]/context.md`
   - Include project-specific knowledge
   - Document project constraints and preferences

4. **Update AGENTS.md**:
   - Add new agents to registry
   - Update department listings
   - Follow tandem update rules with CLAUDE.md

---

### Phase 4: Workflow Document Updates

Update the following files with project-specific guidance:

1. **CLAUDE.md** (main instructions):
   - Add project overview section
   - Update domain→agent mappings if new agents created
   - Add project-specific workflow notes
   - Ensure tandem sync with AGENTS.md

2. **README.md** (if exists):
   - Verify project description accuracy
   - Update workflow section with project specifics

3. **Agent collaboration triggers**:
   - Update `.specify/memory/agent-collaboration-triggers.md`
   - Add any new domain→agent mappings

---

### Phase 5: Project-Specific Configuration

1. **Create project config** (if needed):
   - `.specify/config/project.conf` with project-specific thresholds
   - Environment template updates

2. **Design system setup** (from Principle XII):
   - If design system specified in PRD, create placeholder structure
   - Document design tokens and component requirements

3. **Access control setup** (from Principle XIII):
   - Document access tiers defined in PRD
   - Create feature gating reference

---

### Phase 6: MCP Server Selection and Setup

**Skill Reference**: `.claude/skills/integration/mcp-server-setup/SKILL.md`

MCP (Model Context Protocol) servers extend Claude Code's capabilities. This phase ensures the right tools are available for your project using **Docker MCP Toolkit** as the primary method.

**Docker MCP Toolkit** is pre-installed during framework setup and provides:
- Dynamic discovery of 310+ servers via `mcp-find` tool
- Runtime installation via `mcp-add` tool
- Containerized execution (no local dependencies)

1. **Verify Docker MCP Toolkit**:
   ```bash
   docker mcp version      # Should show v0.30.0 or later
   docker mcp tools ls     # Should show mcp-find, mcp-add, etc.
   ```

2. **Analyze PRD for MCP requirements**:
   - Extract database type from Technical Constraints
   - Identify cloud provider needs
   - Note integration requirements (APIs, services)
   - Review testing strategy for browser automation needs

3. **Search Docker catalog for matches**:

   For each requirement, use `mcp-find`:
   ```
   Use mcp-find: "Find servers for [requirement]"
   ```

   | PRD Requirement | Docker Server | Fallback |
   |-----------------|---------------|----------|
   | PostgreSQL/Supabase | `supabase` | npx install |
   | AWS deployment | `aws` | npx install |
   | GCP deployment | `gcp` | npx install |
   | E2E testing | `browsermcp` | npx install |
   | GitHub integration | `github-official` | npx install |
   | Documentation lookup | `context7` | npx install |

4. **Present recommendations to user**:
   ```markdown
   ## Recommended MCP Servers

   Based on your PRD, I recommend:

   ### Required (for core functionality)
   - **[server]**: [purpose] - Method: Docker Toolkit (`mcp-add`)

   ### Recommended (enhance workflow)
   - **[server]**: [purpose] - Method: Docker Toolkit (`mcp-add`)

   Would you like me to add these servers?
   ```

5. **Install via Docker Toolkit** (with user approval):

   For each approved server:
   ```
   Use mcp-add: "Add the [server] server"
   Use mcp-config-set: "Set [credential] for [server]"
   ```

   Or guide user to add credentials to `.env` file.

6. **Fallback to direct installation** (if server not in Docker catalog):

   Add to `.mcp.json`:
   ```json
   {
     "mcpServers": {
       "server-name": {
         "command": "npx",
         "args": ["-y", "@org/mcp-server"],
         "env": { "API_KEY": "env:API_KEY" }
       }
     }
   }
   ```

7. **Verify MCP connections**:
   ```bash
   docker mcp tools ls  # Should show all enabled server tools
   ```

   Or test with a simple operation in conversation.

**User Approval Required**: All MCP installations and configuration changes

---

### Phase 7: Validation and Report

1. **Run validation checks**:
   ```bash
   # Constitutional compliance
   ./.specify/scripts/bash/constitutional-check.sh

   # Sanitization (ensure framework integrity)
   ./.specify/scripts/bash/sanitization-audit.sh
   ```

2. **Generate initialization report**:
   - Files created/modified
   - Agents created
   - Constitution changes
   - Recommended next steps

3. **Output completion summary**:
   ```markdown
   ## Project Initialization Complete ✓

   **Project**: [name]
   **PRD**: .docs/prd/prd.md
   **Constitution**: Updated with [X] customizations
   **Agents**: [X] new, [Y] modified

   ### Files Modified
   - .specify/memory/constitution.md
   - CLAUDE.md
   - AGENTS.md
   - [other files...]

   ### Custom Agents Created
   - [agent-1]: [purpose]
   - [agent-2]: [purpose]

   ### MCP Servers Configured
   - [mcp-1]: [purpose] - [status]
   - [mcp-2]: [purpose] - [status]

   ### Environment Variables Added
   - [VAR_NAME]: [description] (add to .env)

   ### Next Steps
   1. Review constitution customizations
   2. Add any missing credentials to `.env`
   3. Test MCP connections
   4. Run `/specify` for first MVP feature
   5. Begin TDD implementation cycle

   ### Commands to Continue
   - `/specify "Feature from MVP list"` - Create feature specification
   - `/plan` - Generate implementation plan (after /specify)
   - `/tasks` - Create task list (after /plan)
   ```

---

## User Approval Gates

This command requires user approval for:

1. **Constitution modification** - Show proposed changes before applying
2. **Agent creation** - Confirm each new agent before creating
3. **MCP installation** - Confirm recommended MCPs before configuring
4. **Git operations** - If any git operations needed (Principle VI)

Never perform these operations without explicit user approval.

---

## Error Handling

| Error | Resolution |
|-------|------------|
| PRD not found | Inform user to run `/create-prd` first |
| PRD incomplete | List missing sections, ask user to complete |
| Constitution conflict | Show conflict, ask user to resolve |
| Agent creation fails | Report error, suggest manual creation |
| Validation fails | Show errors, suggest fixes |

---

## Rollback

If initialization fails mid-way:
1. Constitution backup preserved at `.specify/memory/constitution.md.backup`
2. Report which operations completed vs failed
3. Provide manual recovery steps

---

**Related Commands**:
- `/create-prd` - Create Product Requirements Document (prerequisite)
- `/create-agent` - Create specialized agent
- `/specify` - Create feature specification (next step)
- `/plan` - Generate implementation plan
- `/tasks` - Create task list

**Supporting Skills**:
- `.claude/skills/project-initialization/SKILL.md` - Core initialization procedures
- `.claude/skills/integration/mcp-server-setup/SKILL.md` - MCP server selection and configuration
