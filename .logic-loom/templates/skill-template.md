# Skill Template

This template provides the structure for creating Agent Skills in the LogicLoom.

## What Are Agent Skills?

**Agent Skills** are self-contained directories with instructions and scripts that Claude dynamically loads using progressive disclosure. Skills provide procedural "how-to" knowledge, while agents handle delegation and orchestration.

## Skill File Structure

```
.claude/skills/category/skill-name/
├── SKILL.md          # Required: Instructions + YAML frontmatter
├── reference.md      # Optional: Detailed documentation
├── examples.md       # Optional: Usage examples
├── scripts/          # Optional: Executable utilities
│   └── process.sh
└── templates/        # Optional: Reusable content
    └── template.txt
```

## SKILL.md Template

```markdown
---
name: skill-name
description: |
  Brief description of what this skill does and when to use it.
  Maximum 1024 characters. Be specific about trigger conditions.

  Example: "Use when creating feature specifications following SDD methodology.
  Triggered by /specify command or user request for requirements documentation."
allowed-tools: Read, Write, Bash, Grep, Glob
---

# Skill Name

## When to Use

Describe the specific situations that should trigger this skill:
- User requests specific type of work
- Slash command invoked
- Particular phase of workflow
- Domain-specific task detected

## Task Brief

<!-- This section is extracted by extract_skill_brief() and injected into Task tool
     prompts when spawning team workers. Keep it concise and self-contained.
     It should contain the essential domain knowledge a worker needs to perform
     tasks in this skill's domain without access to the full SKILL.md. -->

You are a [DOMAIN] specialist working on a team task. Your expertise includes:
- [Key capability 1]
- [Key capability 2]
- [Key capability 3]

**Quality Standards**:
- [Standard 1]
- [Standard 2]

**File Ownership**: You own files matching: `[glob pattern]`

## Procedure

Provide step-by-step instructions:

1. **Step Name**: Description of what to do
   - Sub-step or clarification
   - Expected outcome

2. **Step Name**: Next action
   - Details
   - Commands to run (if applicable)

3. **Step Name**: Final action
   - Validation
   - Reporting

## Constitutional Compliance

List applicable constitutional principles:

- **Principle I (Library-First Architecture)**: How this skill ensures library-first
- **Principle II (Test-First Development)**: How this skill enforces TDD
- **Principle VI (Git Operation Approval)**: Any git operations require approval
- **Principle VIII (Documentation Synchronization)**: Documentation requirements

## Examples

### Example 1: [Scenario Name]

**User Request**: "Description of what user asked for"

**Skill Activation**:
```
[Show how the skill would be used]
```

**Expected Output**:
```
[Show what the skill produces]
```

### Example 2: [Another Scenario]

[Repeat format]

## Agent Collaboration

List agents this skill should reference or collaborate with:

- **Agent Name**: When to delegate to this agent
- **Agent Name**: What work this agent handles

## Supporting Files

If your skill has supporting files (scripts, templates, reference docs):

### Scripts (`scripts/` directory)

- `script-name.sh`: Description of what it does
  - Usage: `./script-name.sh [args]`
  - Requirements: bash, jq, etc.

### Templates (`templates/` directory)

- `template-name.txt`: Description of template
  - Used in: Step X of procedure
  - Variables: LIST, OF, VARIABLES

### Reference Documentation (`reference.md`)

- Detailed technical information
- API references
- Algorithm explanations

### Examples (`examples.md`)

- Extended usage examples
- Common patterns
- Edge cases

## Validation

How to verify the skill executed correctly:

- [ ] Checklist item 1
- [ ] Checklist item 2
- [ ] Checklist item 3

## Troubleshooting

Common issues and solutions:

### Issue: [Problem description]

**Cause**: Why this happens

**Solution**: How to fix it

## Notes

Additional considerations:
- Performance implications
- Known limitations
- Future enhancements
- Related skills
```

## Skill Categories

### sdd-workflow/
Core SDD methodology workflows (Priority 1)
- Specification creation
- Implementation planning
- Task generation

### validation/
Quality gates and compliance checking (Priority 2)
- Constitutional compliance
- Domain detection
- Specification validation
- Plan validation
- Task validation

### technical/
Domain-specific technical procedures (Priority 3)
- API contract design
- Test-first development
- Database design
- Security patterns
- Performance optimization

### integration/
External system integrations (Priority 4)
- MCP server integration
- CI/CD integration
- Monitoring setup

## Skill Naming Conventions

- Use kebab-case: `skill-name`
- Be descriptive: `sdd-specification` not `spec`
- Include domain: `api-contract-design` not `contracts`
- Verb-based for actions: `validate-plan`, `detect-domain`
- Noun-based for domains: `constitutional-compliance`, `test-first-development`

## Best Practices

1. **Progressive Disclosure**: Start with metadata (YAML), provide core instructions in SKILL.md, defer details to supporting files

2. **Constitutional Alignment**: Every skill must reference applicable constitutional principles

3. **Agent Collaboration**: Skills guide procedures, agents handle delegation. Make this distinction clear.

4. **Focused Scope**: Each skill should do ONE thing well. Create multiple skills rather than one complex skill.

5. **Self-Documenting**: Skills should be clear enough that Claude can execute them without additional context

6. **Validation**: Always include validation steps so Claude knows if the skill executed successfully

7. **Examples**: Provide concrete examples showing input → process → output

8. **Tool Restrictions**: Use `allowed-tools` to limit which tools the skill can use (security/efficiency)

## Skill Metadata Guidelines

### name
- Required
- Kebab-case
- Unique across all skills
- Matches directory name

### description
- Required
- Maximum 1024 characters
- Include trigger conditions
- Include expected outcomes
- Use YAML multiline syntax (`|`) for readability

### allowed-tools (optional)
- Comma-separated list
- Available tools: Read, Write, Edit, MultiEdit, Bash, Grep, Glob, Task, TaskCreate, TaskUpdate, TaskList, TaskGet
- Omit to allow all tools
- Use to enforce least privilege

## Constitutional Requirements for Skills

All skills must comply with:

- **Principle VI**: No autonomous git operations
- **Principle VIII**: Documentation must stay synchronized
- **Principle X**: Clear agent delegation triggers
- **Principle XIV**: Use appropriate AI model (haiku for quick tasks)

Skills that handle security-sensitive operations must comply with:

- **Principle XI**: Input validation and output sanitization

Skills that modify code must comply with:

- **Principle II**: Test-first development
- **Principle III**: Contract-first design

## Skill Review Checklist

Before creating a new skill, verify:

- [ ] Skill has unique, descriptive name
- [ ] Description clearly states trigger conditions
- [ ] SKILL.md follows template structure
- [ ] Procedure is step-by-step and executable
- [ ] Constitutional principles are referenced
- [ ] Agent collaboration is specified
- [ ] Examples demonstrate usage
- [ ] Validation steps are included
- [ ] Tool restrictions are appropriate
- [ ] Skill doesn't duplicate existing skill/agent functionality

## Skill vs Agent Decision Tree

```
Does this provide procedural "how-to" knowledge?
├─ YES: Create a SKILL
│  └─ Self-contained procedure with step-by-step instructions
└─ NO: Does this require delegation/orchestration?
   ├─ YES: Create an AGENT
   │  └─ Autonomous specialist that invokes Task tool
   └─ NO: Enhance existing skill or agent
```

## References

- Constitution v3.0.0: `.logic-loom/memory/constitution.md`
- Agent Template: `.logic-loom/templates/agent-template.md`
- Skills Integration Analysis: `.docs/skills-integration-analysis.md`
- Skills Executive Summary: `.docs/skills-integration-executive-summary.md`
- Anthropic Blog: https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- Claude Code Docs: https://code.claude.com/docs/en/skills

---

**Template Version**: 1.0.0
**Last Updated**: 2025-11-07
**Owner**: Architecture Department (subagent-architect)
