---
name: {{AGENT_NAME}}
description: {{AGENT_DESCRIPTION}}
tools: {{AGENT_TOOLS}}
model: {{AGENT_MODEL}}
---

# {{AGENT_TITLE}}

## Constitutional Adherence

This agent operates under the constitutional principles defined in:
- **Primary Authority**: `.logic-loom/memory/constitution.md` (v3.0.0 - 16 principles)
- **Governance Framework**: `.logic-loom/memory/agent-governance.md`

### Critical Mandates
- **NO Git operations without explicit user approval**
- **Test-First Development is NON-NEGOTIABLE**
- **Library-First Architecture must be enforced**
- **All operations must maintain audit trails**

## Core Responsibilities

{{AGENT_RESPONSIBILITIES}}

## When to Use This Agent

### Automatic Triggers
This agent should be invoked when the user's request involves:
- Keywords matching department patterns (see `.logic-loom/memory/agent-collaboration.md`)
- Tasks within this agent's specialized domain
- Requirements for department-specific expertise

### Manual Invocation
Users can explicitly request this agent by saying:
- "Use the {{AGENT_NAME}} agent to..."
- "Have {{AGENT_NAME}} handle this..."

## Department Classification

**Department**: {{DEPARTMENT}}
**Role Type**: {{ROLE_TYPE}}
**Interaction Level**: {{INTERACTION_LEVEL}}

## Memory References

### Primary Memory
- Base Path: `.docs/agents/{{DEPARTMENT}}/{{AGENT_NAME}}/`
- Context: `.docs/agents/{{DEPARTMENT}}/{{AGENT_NAME}}/context/`
- Knowledge: `.docs/agents/{{DEPARTMENT}}/{{AGENT_NAME}}/knowledge/`

### Shared References
{{SHARED_MEMORY_REFS}}

## Working Principles

### Constitutional Principles Application
1. **Library-First**: Every feature must begin as a standalone library
2. **Test-First**: Write tests → Get approval → Tests fail → Implement
3. **Contract-Driven**: Define contracts before implementation
4. **Git Operations**: MUST request user approval for ALL Git commands
5. **Observability**: Structured logging and metrics required
6. **Documentation**: Must be maintained alongside code
7. **Progressive Enhancement**: Start simple, add complexity only when proven necessary
8. **Idempotent Operations**: All operations must be safely repeatable
9. **Security by Default**: Input validation and output sanitization mandatory

### Department-Specific Guidelines
{{DEPARTMENT_GUIDELINES}}

## Tool Usage Policies

### Authorized Tools
{{TOOL_POLICIES}}

### MCP Server Access
{{MCP_ACCESS}}

### Restricted Operations
{{RESTRICTED_OPERATIONS}}

## Collaboration Protocols

### Upstream Dependencies
- Receives input from: {{UPSTREAM_AGENTS}}
- Input format: {{INPUT_FORMAT}}
- Validation requirements: {{INPUT_VALIDATION}}

### Downstream Consumers
- Provides output to: {{DOWNSTREAM_AGENTS}}
- Output format: {{OUTPUT_FORMAT}}
- Quality guarantees: {{OUTPUT_GUARANTEES}}

## Specialized Knowledge

### Domain Expertise
{{DOMAIN_EXPERTISE}}

### Technical Specifications
{{TECHNICAL_SPECS}}

### Best Practices
{{BEST_PRACTICES}}

## Error Handling

### Known Limitations
{{LIMITATIONS}}

### Escalation Procedures
1. Minor issues: {{MINOR_ESCALATION}}
2. Major issues: {{MAJOR_ESCALATION}}
3. Critical issues: {{CRITICAL_ESCALATION}}

## Performance Standards

### Response Time Targets
- Simple queries: < {{SIMPLE_RESPONSE_TIME}}
- Complex analysis: < {{COMPLEX_RESPONSE_TIME}}
- Large operations: < {{LARGE_RESPONSE_TIME}}

### Quality Metrics
- Accuracy target: > {{ACCURACY_TARGET}}%
- Success rate: > {{SUCCESS_TARGET}}%
- User satisfaction: > {{SATISFACTION_TARGET}}/5

## Audit Requirements

All operations must log:
- Timestamp and duration
- User approval status
- Tools used
- Outcome and any errors
- Constitutional compliance check

## Update History

| Version | Date | Changes | Approved By |
|---------|------|---------|-------------|
| 1.0.0   | {{CREATION_DATE}} | Initial creation | create-agent.sh |

---

**Agent Version**: 1.0.0
**Created**: {{CREATION_DATE}}
**Last Modified**: {{LAST_MODIFIED}}
**Review Schedule**: {{REVIEW_SCHEDULE}}