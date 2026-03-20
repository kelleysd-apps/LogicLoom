---
name: project-initialization
description: |
  Post-PRD project initialization skill for the /initialize-project command.
  Guides constitution customization, agent training, and workflow configuration
  based on completed Product Requirements Document. Ensures framework is
  tailored to specific project needs while maintaining constitutional compliance.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_feedback: null
---

# Project Initialization Skill

## Purpose

This skill provides procedural guidance for initializing a project after PRD completion. It ensures:

1. **Constitution Customization** - All 16 principles adapted to project needs
2. **Agent Training** - Custom agents created and configured
3. **Workflow Configuration** - Documentation updated for project context
4. **SSOT Integrity** - All documents remain synchronized

## Constitutional Principles Enforced

| Principle | Enforcement |
|-----------|-------------|
| **II (Test-First)** | Extract testing requirements from PRD |
| **VI (Git Approval)** | NO automatic git operations |
| **VIII (Doc Sync)** | Update all dependent documents |
| **X (Agent Delegation)** | Create agents identified in PRD |
| **XIV (Model Selection)** | Configure agent model preferences |
| **XV (File Organization)** | Follow directory structure rules |

---

## Pre-Initialization Checklist

Before starting, verify:

```
[ ] PRD exists at .docs/prd/prd.md
[ ] PRD completeness checklist is satisfied
[ ] User has approved initialization
[ ] Current branch is appropriate for changes
```

### PRD Completeness Validation

Required PRD sections for initialization:

1. **Executive Summary** - Project name, vision, success metrics
2. **User Personas** - At least primary persona defined
3. **Core Features** - MVP features with acceptance criteria
4. **Constitutional Principles** - All 16 principles addressed
5. **Technical Constraints** - Required/prohibited technologies
6. **Release Strategy** - MVP scope defined

**Validation Command**:
```bash
# Check PRD exists
test -f .docs/prd/prd.md && echo "PRD found" || echo "PRD MISSING - run /create-prd first"
```

---

## Initialization Procedures

### Procedure 1: PRD Analysis

**Goal**: Extract all project-specific customizations from PRD

**Steps**:

1. **Read PRD completely**:
   ```
   Read .docs/prd/prd.md
   ```

2. **Extract project metadata**:
   - Project name (from header)
   - Vision statement (Executive Summary)
   - Primary focus areas (from features and constraints)
   - Target domains (from user personas and features)

3. **Map PRD to domains**:

   | PRD Section | Domain Trigger | Suggested Agent |
   |-------------|----------------|-----------------|
   | UI features | frontend | frontend-operations skill (sdd-domain-frontend) |
   | API requirements | backend | api-design skill (sdd-domain-backend) |
   | Database schemas | database | schema-design skill (sdd-domain-database) |
   | Security requirements | security | security-operations skill (sdd-domain-security) |
   | Performance targets | performance | performance-operations skill (sdd-domain-performance) |

4. **Extract principle customizations**:
   For each of the 16 principles, note:
   - Project-specific guidance from PRD
   - Exceptions documented
   - Custom thresholds defined
   - Examples relevant to project

5. **Identify custom agents**:
   From PRD Principle X section:
   - Agent name
   - Purpose
   - Domain
   - Required tools
   - Model preference

---

### Procedure 2: Constitution Customization

**Goal**: Apply project-specific customizations to constitution

**File**: `.specify/memory/constitution.md`

**Steps**:

1. **Create backup**:
   ```bash
   cp .specify/memory/constitution.md .specify/memory/constitution.md.backup
   ```

2. **Update header metadata**:
   ```markdown
   **Project Customization**: [Project Name]
   **Customization Date**: [Current Date]
   **PRD Reference**: .docs/prd/prd.md
   ```

3. **Apply principle customizations**:

   For each principle (I-XVI), add project-specific section if PRD has customizations:

   ```markdown
   ### Principle [N]: [Name]

   [Existing content unchanged...]

   **Project Customization** ([Project Name]):
   - [Customization 1 from PRD]
   - [Customization 2 from PRD]
   - Threshold: [if different from default]
   - Exception: [if any, with justification]
   ```

4. **Common customization patterns**:

   **Principle II (Test-First)**:
   ```markdown
   **Project Customization** ([Project Name]):
   - Test Framework: [from PRD Technical Constraints]
   - Coverage Threshold: [from PRD, default 80%]
   - E2E Strategy: [from PRD]
   - Contract Testing: [from PRD]
   ```

   **Principle III (Contract-First)**:
   ```markdown
   **Project Customization** ([Project Name]):
   - API Standard: [OpenAPI/GraphQL from PRD]
   - Versioning: [from PRD]
   - Contract Location: specs/[feature]/contracts/
   ```

   **Principle X (Agent Delegation)**:
   ```markdown
   **Project Customization** ([Project Name]):
   - Custom Agents:
     - [agent-1]: [purpose]
     - [agent-2]: [purpose]
   - Primary Domains: [from PRD analysis]
   ```

   **Principle XII (Design System)**:
   ```markdown
   **Project Customization** ([Project Name]):
   - Design System: [name from PRD]
   - WCAG Level: [from PRD, default AA]
   - Responsive: [requirements from PRD]
   ```

   **Principle XIII (Access Control)**:
   ```markdown
   **Project Customization** ([Project Name]):
   - Access Tiers: [from PRD]
   - Gating Strategy: [from PRD]
   ```

5. **Update version**:
   - Increment patch version (e.g., 1.5.0 → 1.5.1)
   - Update "Last Amended" date

6. **Validate changes**:
   ```bash
   ./.specify/scripts/bash/constitutional-check.sh
   ```

---

### Procedure 3: Agent Training

**Goal**: Create and configure project-specific agents

**Steps**:

1. **For each custom agent in PRD**:

   a. **Get user approval**:
      ```
      Creating agent: [agent-name]
      Purpose: [purpose from PRD]
      Domain: [domain]

      Proceed? (y/n)
      ```

   b. **Use /create-agent command**:
      ```
      /create-agent [agent-name] "[purpose from PRD]"
      ```

   c. **Configure agent file**:
      - Set appropriate tools based on domain
      - Configure model (default: opus)
      - Add project-specific instructions

2. **Update agent context**:

   For each new agent, create context file:
   ```
   .docs/agents/[dept]/[agent]/context.md
   ```

   Content:
   ```markdown
   # [Agent Name] - Project Context

   ## Project: [Name]

   ### Project Overview
   [Vision from PRD]

   ### Agent Scope for This Project
   [Specific responsibilities from PRD]

   ### Key Constraints
   - [Constraint 1 from PRD]
   - [Constraint 2 from PRD]

   ### Success Criteria
   - [From PRD success metrics relevant to this agent]

   ### Integration Points
   - Works with: [other agents]
   - Hands off to: [downstream agents]
   ```

3. **Update AGENTS.md**:
   - Add new agents to appropriate department
   - Update agent count
   - Follow tandem rules with CLAUDE.md

---

### Procedure 4: Workflow Document Updates

**Goal**: Ensure all framework docs reflect project customizations

**Documents to update**:

1. **CLAUDE.md**:

   Add project overview section after commands:
   ```markdown
   ## Project: [Name]

   ### Overview
   [Vision from PRD]

   ### Primary Domains
   - [Domain 1]: [Primary agent]
   - [Domain 2]: [Primary agent]

   ### Project-Specific Workflows
   [Any custom workflows from PRD]
   ```

   Update custom agent references:
   - Add to domain→agent mapping table
   - Update agent count references

2. **Agent collaboration triggers**:

   Update `.specify/memory/agent-collaboration-triggers.md`:
   - Add new domain→agent mappings
   - Document custom agent collaboration points

3. **Project README** (if exists):
   - Verify project description matches PRD
   - Update available commands list

---

### Procedure 5: Configuration Setup

**Goal**: Create project-specific configuration files

**Steps**:

1. **Project config** (optional):

   Create `.specify/config/project.conf`:
   ```bash
   # Project Configuration
   # Generated from PRD: [date]

   PROJECT_NAME="[name]"
   PRIMARY_DOMAINS="[domains]"

   # Quality Thresholds
   TEST_COVERAGE_THRESHOLD=80  # Override from PRD
   SPEC_COMPLETENESS_THRESHOLD=0.90

   # Custom Agent Models
   DEFAULT_AGENT_MODEL=opus
   ```

2. **Design system placeholder** (if needed):

   If PRD Principle XII specifies design system:
   ```
   Create directory: src/design-system/
   Create file: src/design-system/README.md with structure from PRD
   ```

3. **Access control reference** (if needed):

   If PRD Principle XIII defines tiers:
   ```
   Create file: .docs/access-control.md
   Document tiers and feature gates from PRD
   ```

---

### Procedure 5.5: MCP Server Setup (Docker MCP Toolkit)

**Goal**: Configure MCP servers for the project using Docker MCP Toolkit

**Skill Reference**: `plugins/sdd-maintenance/skills/mcp-server-setup/SKILL.md`

**Docker MCP Toolkit** is pre-installed during framework setup and provides:
- Dynamic discovery of 310+ servers via `mcp-find` tool
- Runtime installation via `mcp-add` tool
- Containerized execution (no local dependencies)

**Steps**:

1. **Verify Docker MCP Toolkit**:
   ```bash
   docker mcp version      # Should show v0.30.0 or later
   docker mcp tools ls     # Should show mcp-find, mcp-add, etc.
   ```

2. **Analyze PRD for MCP requirements**:
   - Extract database type from Technical Constraints
   - Identify cloud provider needs
   - Note integration requirements
   - Review testing strategy

3. **Search Docker catalog**:
   For each requirement:
   ```
   Use mcp-find: "Find servers for [requirement]"
   ```

4. **Present recommendations to user with tiers**:
   - Required (core functionality)
   - Recommended (workflow enhancement)
   - Optional (nice to have)

5. **Install with user approval**:
   For each approved server:
   ```
   Use mcp-add: "Add the [server] server"
   Use mcp-config-set: "Set [credential] for [server]"
   ```

6. **Fallback for servers not in Docker catalog**:
   Add to `.mcp.json` with npx configuration

7. **Guide credential setup**:
   - Identify required environment variables
   - Guide user to add to `.env` file
   - Never commit credentials

8. **Verify connections**:
   ```bash
   docker mcp tools ls  # Should show all enabled server tools
   ```

---

### Procedure 6: Validation and Reporting

**Goal**: Verify initialization and report results

**Steps**:

1. **Run validation checks**:
   ```bash
   # Constitutional compliance
   ./.specify/scripts/bash/constitutional-check.sh

   # Sanitization (framework integrity)
   ./.specify/scripts/bash/sanitization-audit.sh
   ```

2. **Verify document sync**:
   - Constitution version matches CLAUDE.md references
   - Agent count matches across CLAUDE.md and AGENTS.md
   - All new agents registered

3. **Generate report**:

   ```markdown
   # Project Initialization Report

   **Project**: [name]
   **Date**: [date]
   **PRD**: .docs/prd/prd.md

   ## Constitution Updates
   - Version: [old] → [new]
   - Principles customized: [count]
   - Exceptions documented: [count]

   ## Agents
   - Created: [count]
     - [agent-1]: [purpose]
     - [agent-2]: [purpose]
   - Modified: [count]

   ## Files Modified
   1. .specify/memory/constitution.md
   2. CLAUDE.md
   3. AGENTS.md
   4. [other files]

   ## Validation Results
   - Constitutional check: [PASS/FAIL]
   - Sanitization audit: [PASS/FAIL]

   ## Next Steps
   1. Review constitution customizations
   2. Run `/specify` for first MVP feature from PRD
   3. Begin TDD implementation cycle

   ## Commands
   - `/specify "[MVP Feature 1]"` - Start first feature
   - `/plan` - After /specify completes
   - `/tasks` - After /plan completes
   ```

---

## Error Recovery

### PRD Not Found
```
Error: PRD not found at .docs/prd/prd.md

Resolution:
1. Run `/create-prd` to create Product Requirements Document
2. Complete all required PRD sections
3. Re-run `/initialize-project`
```

### PRD Incomplete
```
Error: PRD missing required sections

Missing:
- [ ] Constitutional Principles (Section X)
- [ ] Release Strategy (MVP definition)

Resolution:
1. Edit .docs/prd/prd.md
2. Complete missing sections
3. Re-run `/initialize-project`
```

### Constitution Conflict
```
Error: Constitution customization conflicts detected

Conflict:
- Principle [N]: [description of conflict]

Resolution:
1. Review PRD requirements
2. Resolve conflict manually
3. Re-run `/initialize-project`
```

### Rollback Procedure

If initialization fails:

1. Restore constitution backup:
   ```bash
   cp .specify/memory/constitution.md.backup .specify/memory/constitution.md
   ```

2. Revert CLAUDE.md changes (if any)

3. Delete incomplete agent files

4. Report failure and manual recovery steps

---

## Quality Checklist

Before completing initialization, verify:

```
[ ] PRD analyzed completely
[ ] All 16 principles reviewed for customizations
[ ] Constitution updated with project specifics
[ ] Custom agents created per PRD Principle X
[ ] CLAUDE.md updated with project context
[ ] AGENTS.md updated with new agents
[ ] Agent collaboration triggers updated
[ ] Constitutional check passes
[ ] Sanitization audit passes
[ ] User approved all changes
[ ] Next steps provided to user
```

---

## Agent Collaboration Points

This skill may require delegation to:

| Task | Delegate To |
|------|-------------|
| Create custom agent | subagent-architect |
| Frontend agent config | frontend-operations skill (sdd-domain-frontend) |
| Backend agent config | api-design skill (sdd-domain-backend) |
| Security review | security-operations skill (sdd-domain-security) |
| Testing setup | testing-operations skill (sdd-domain-testing) |

---

**Skill Version**: 1.0.0
**Last Updated**: 2025-11-30
**Constitutional Version**: 1.5.0+
**Required PRD Version**: 1.0.0+
