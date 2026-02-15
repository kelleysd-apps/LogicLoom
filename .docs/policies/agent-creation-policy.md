# Agent Creation Policy & Standards

**Version**: 1.0.0
**Effective Date**: 2025-01-17
**Policy Owner**: System Architecture Team

## Purpose

This document defines the standards, workflows, and requirements for creating and managing subagents within the Claude Code framework. All agent creation must follow these policies to ensure consistency, constitutional compliance, and proper integration.

## Agent Architecture Overview

### Directory Structure

```
.claude/agents/          # Agent definitions
├── architecture/        # System design and planning agents
├── engineering/         # Development and implementation agents
├── quality/            # Testing and review agents
├── data/              # Data management agents
├── product/           # Product and UX agents
└── operations/        # DevOps and maintenance agents

.docs/agents/           # Agent memory and knowledge
└── [mirrored structure with agent folders]
```

### Department Classifications

#### Architecture Department
**Purpose**: High-level system design and technical planning
**Typical Agents**: system-architect, solution-designer, integration-specialist
**Tool Access**: Read, Grep, Glob, WebSearch, TaskCreate, TaskUpdate
**Memory Focus**: Patterns, decisions, references

#### Engineering Department
**Purpose**: Code implementation and development
**Typical Agents**: backend-engineer, frontend-engineer, devops-engineer
**Tool Access**: Full development tools (Read, Write, Edit, MultiEdit, Bash, Grep, Glob)
**Memory Focus**: Standards, snippets, troubleshooting

#### Quality Department
**Purpose**: Testing, review, and quality assurance
**Typical Agents**: test-architect, qa-engineer, code-reviewer, security-auditor
**Tool Access**: Read, Grep, Glob, Bash (limited), WebSearch
**Memory Focus**: Test patterns, checklists, metrics

#### Data Department
**Purpose**: Database and data pipeline management
**Typical Agents**: data-architect, database-engineer, analytics-engineer
**Tool Access**: Read, Edit, Bash (SQL focus), Grep, Glob
**Memory Focus**: Schemas, migrations, optimizations

#### Product Department
**Purpose**: Requirements analysis and user experience
**Typical Agents**: product-analyst, ux-researcher, requirements-analyst
**Tool Access**: Read, WebSearch, TaskCreate, TaskUpdate
**Memory Focus**: Personas, journeys, feedback

#### Operations Department
**Purpose**: Deployment, monitoring, and incident response
**Typical Agents**: release-manager, incident-responder, documentation-specialist
**Tool Access**: Read, Bash, Grep, TaskCreate, TaskUpdate
**Memory Focus**: Runbooks, incidents, releases

## Agent Creation Workflow

### Phase 1: Analysis
1. Review request for agent purpose and capabilities
2. Analyze existing agents to avoid duplication
3. Determine appropriate department classification
4. Define required tool access based on responsibilities
5. Identify memory requirements and references

### Phase 2: Configuration
1. Generate agent definition file with YAML frontmatter
2. Include constitutional reference (mandatory)
3. Define specialized system prompt
4. Set appropriate tool restrictions
5. Configure memory path references

### Phase 3: Validation
1. Verify constitutional compliance
2. Check tool access appropriateness
3. Validate memory structure creation
4. Ensure no naming conflicts
5. Test agent invocation

### Phase 4: Documentation
1. Update agent registry
2. Create initial memory structure
3. Document in department index
4. Log creation in audit trail

## Agent Definition Standards

### Required Components

```yaml
---
name: agent-identifier        # Kebab-case, unique
description: Clear purpose    # One-line description
tools: Tool1, Tool2          # Restricted by department
model: inherit               # Usually inherit, specify when needed
---
```

### System Prompt Structure

1. **Constitutional Adherence** (mandatory)
   - Reference to `.specify/memory/constitution.md`
   - Git operations restrictions

2. **Core Responsibilities**
   - Primary functions
   - Scope boundaries
   - Interaction patterns

3. **Memory References**
   - Department memory paths
   - Shared knowledge bases
   - Learning persistence paths

4. **Working Principles**
   - Department-specific guidelines
   - Constitutional principles application
   - Collaboration protocols

5. **Specialized Knowledge**
   - Domain expertise
   - Technical specifications
   - Best practices

## Tool Access Matrix

| Department    | Read | Write | Edit | Bash | Grep | Glob | WebSearch | Task Tools | MCP Tools |
|--------------|------|-------|------|------|------|------|-----------|-----------|-----------|
| Architecture | ✅   | ❌    | ❌   | ⚠️   | ✅   | ✅   | ✅        | ✅        | ⚠️        |
| Engineering  | ✅   | ✅    | ✅   | ✅   | ✅   | ✅   | ✅        | ✅        | ✅        |
| Quality      | ✅   | ❌    | ⚠️   | ⚠️   | ✅   | ✅   | ✅        | ✅        | ❌        |
| Data         | ✅   | ⚠️    | ✅   | ⚠️   | ✅   | ✅   | ⚠️        | ✅        | ⚠️        |
| Product      | ✅   | ❌    | ❌   | ❌   | ⚠️   | ⚠️   | ✅        | ✅        | ❌        |
| Operations   | ✅   | ⚠️    | ⚠️   | ✅   | ✅   | ✅   | ⚠️        | ✅        | ⚠️        |

Legend: ✅ Full Access | ⚠️ Limited/Conditional | ❌ No Access

## Naming Conventions

### Agent Files
- Format: `role-function.md`
- Examples: `backend-engineer.md`, `test-architect.md`
- Use kebab-case exclusively
- Keep names concise but descriptive

### Memory Folders
- Mirror agent structure
- Use plural forms for categories
- Examples: `patterns/`, `decisions/`, `standards/`

## Constitutional Compliance

### Mandatory Elements
1. Every agent MUST reference constitution.md
2. Git operations restrictions MUST be included
3. Test-first principles MUST be emphasized
4. Library-first approach MUST be mentioned

### Update Protocol
When constitution.md changes:
1. Run `update-all-agents.sh` script
2. Validate all agents for compliance
3. Update agent-governance.md if needed
4. Document changes in amendment log

## Quality Gates

### Pre-Creation Checks
- [ ] Purpose clearly defined
- [ ] No duplicate functionality
- [ ] Department classification appropriate
- [ ] Tool access justified

### Post-Creation Validation
- [ ] Constitution reference present
- [ ] Git restrictions included
- [ ] Memory paths valid
- [ ] Agent invocable
- [ ] Documentation complete

## Audit and Compliance

### Creation Log
All agent creations logged to:
`.docs/agents/audit/creation-log.json`

### Regular Reviews
- Monthly: Tool access audit
- Quarterly: Agent effectiveness review
- Annually: Policy update assessment

## Amendment Process

1. Propose changes with rationale
2. Impact analysis on existing agents
3. Review period (minimum 3 days)
4. Update all affected agents
5. Version bump and changelog

## Exceptions

Exceptions require:
- Written justification
- Architecture team approval
- Time-bound exception period
- Remediation plan

---

**Next Review Date**: 2025-04-17
**Contact**: System Architecture Team