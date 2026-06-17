---
name: project-initialization
description: |
  Post-PRD project initialization — customizes constitution, creates agents,
  and configures workflows based on the completed Product Requirements Document.

  Triggered by: /initialize-project, "initialize project", "set up project",
  "customize framework for project"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task
category: maintenance
---

# Project Initialization Skill

## Purpose

Initialize a project after PRD completion: customize constitution, create agents, update docs, and configure MCP servers.

**Workflow**: `/create-prd` → **`/initialize-project`** → MCP Setup → `/specification`

---

## Pre-Initialization Checklist

Before starting, verify:
1. PRD exists at `.docs/prd/prd.md`
2. PRD has all required sections (Executive Summary, Personas, Features, Principles, Constraints, Release Strategy)
3. User has approved initialization

---

## Procedure

### Step 1: Analyze PRD

Read `.docs/prd/prd.md` and extract:

1. **Project metadata** — name, vision, primary focus areas
2. **Target domains** — which domain skills will be needed (frontend, backend, database, etc.)
3. **Principle customizations** — project-specific thresholds, exceptions, constraints
4. **Custom agents** — any agents identified in PRD Principle X section
5. **Tech stack** — database, cloud provider, frameworks (for MCP setup)

### Step 2: Customize Constitution

File: `.logic-loom/memory/constitution.md`

1. Create a backup: `cp constitution.md constitution.md.backup`
2. Add project metadata header (name, date, PRD reference)
3. For each principle with PRD customizations, add a `**Project Customization**` subsection
4. Increment patch version and update "Last Amended" date
5. Run `.logic-loom/scripts/bash/constitutional-check.sh` to validate

For customization templates, read `references/constitution-customization.md`.

### Step 3: Create Custom Agents

For each agent identified in the PRD:

1. **Get user approval** for each agent before creating
2. Use `/create-agent [name] "[purpose]"` to scaffold
3. Configure tools, model, and project-specific instructions
4. Create agent context at `.docs/agents/[dept]/[agent]/context.md`
5. Update AGENTS.md (tandem update with CLAUDE.md)

### Step 4: Update Framework Documents

1. **CLAUDE.md** — Add project overview section with name, vision, primary domains, custom workflows
2. **AGENTS.md** — Register new agents, update counts
3. **Agent collaboration triggers** — Add new domain→agent mappings to `.logic-loom/memory/agent-collaboration-triggers.md`

### Step 5: Configure MCP Servers

Delegate to the MCP server setup skill:
1. Read `plugins/loom-maintenance/skills/mcp-server-setup/SKILL.md`
2. Follow its procedure to analyze PRD requirements and install MCP servers

### Step 6: Optional Configuration

If PRD specifies:
- **Design system** (Principle XII): Create `src/design-system/` directory with README
- **Access tiers** (Principle XIII): Create `.docs/access-control.md` documenting tiers
- **Project config**: Create `.logic-loom/config/project.conf` with thresholds

### Step 7: Remove maintainer-only template-release CI

The template ships with CI that releases + guards the **LogicLoom template itself**,
not the customer's project. Remove it from the new project (keep `plugin-tests.yml`
— it validates the harness the customer is using):

```bash
rm -f .github/workflows/promote-to-main.yml   # promotes dev-main -> sanitized main (maintainer-only)
rm -f .github/workflows/leak-guard.yml        # identity-marker backstop for the template's main
```

State clearly in the report that these were removed and why (they would otherwise
run — and fail/no-op — in the customer's CI and reference a release model the
customer is not operating).

### Step 8: Validate and Report

1. Run constitutional compliance check and sanitization audit
2. Verify document sync (constitution version matches CLAUDE.md references, agent counts match)
3. Generate initialization report:

```
Project Initialization Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Project: [name]
Constitution: [old] → [new version]
Principles customized: [count]
Agents created: [count]
Files modified: [list]
Validation: PASS/FAIL

Next Steps:
1. Review constitution customizations
2. Run /specification "[MVP Feature 1]"
3. Begin TDD implementation cycle
```

---

## Critical Rules

1. **Principle VI**: NO automatic git operations — all changes need user approval before commit
2. **Principle VIII**: Every document update must keep CLAUDE.md and AGENTS.md synchronized
3. **Principle XV**: All files created in correct directories per convention

## References

- **Customization patterns**: `references/constitution-customization.md` — templates for each principle
- **MCP setup**: `plugins/loom-maintenance/skills/mcp-server-setup/SKILL.md`
- **Constitution**: `.logic-loom/memory/constitution.md`
