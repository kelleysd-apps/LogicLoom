---
description: Create a new agent skill with procedural guidance templates for workflow automation
---

> ⚠️ **DEPRECATED**: This command has moved to `plugins/sdd-creation/commands/create-plugin.md`.
> The plugin version is the canonical source. This monolithic version will be removed in v5.0.
> 
> **Plugin-First Architecture (Principle XVI)**: All commands now live within their respective plugins.


Create a standalone skill or a skill associated with an existing agent.

## Usage

```
/create-skill skill-name [options]
/create-skill skill-name --agent agent-name
/create-skill skill-name --category sdd-workflow
```

## Arguments

**Required**:
- `skill-name`: Kebab-case name for the skill (e.g., `api-design`, `deployment-automation`)

**Optional**:
- `--agent agent-name`: Associate this skill with an existing agent
- `--category category-name`: Skill category (sdd-workflow, validation, technical, integration)
- `--description "text"`: Brief description of what the skill does

## Execution Steps

### Step 1: Parse Arguments

Extract skill name and options from arguments:
```bash
SKILL_NAME="first-argument"
AGENT_NAME="value after --agent flag (if present)"
CATEGORY="value after --category flag (if present)"
DESCRIPTION="value after --description flag (if present)"
```

### Step 2: Validate Skill Name

Check format:
- Must be kebab-case (lowercase with hyphens)
- No special characters except hyphens
- Not empty

### Step 3: Determine Category

If `--category` not provided, determine automatically:

**If `--agent` is provided**, look up the agent's department:
- Product department → `sdd-workflow`
- Quality department → `validation`
- Operations department → `integration`
- Other departments → `technical`

**If no agent**, prompt user or default to `technical`

### Step 4: Check for Existing Skill

Verify skill doesn't already exist:
```bash
find .claude/skills -name "${SKILL_NAME}" -type d
```

If found, error and exit.

### Step 5: Create Skill Structure

```bash
SKILL_DIR=".claude/skills/${CATEGORY}/${SKILL_NAME}"
mkdir -p "${SKILL_DIR}"
```

### Step 6: Generate SKILL.md

Create SKILL.md with template structure:

**Frontmatter** (YAML):
```yaml
---
name: skill-name
description: |
  Brief description of what this skill does and when to use it.
  [TODO if not provided via --description flag]
allowed-tools: Read, Write, Bash, Grep, Glob
---
```

**Sections**:
1. When to Use
2. Procedure (Step-by-step instructions)
3. Constitutional Compliance
4. Examples
5. Agent Collaboration (if --agent provided)
6. Validation
7. Troubleshooting
8. Notes

See `.specify/templates/skill-template.md` for complete structure.

### Step 7: Report Creation

```
✓ Skill created: .claude/skills/{category}/{skill-name}/SKILL.md

Next steps:
1. Edit SKILL.md to add procedure steps
2. Define trigger keywords
3. Add concrete examples
4. Specify validation steps

[If --agent provided]:
This skill is associated with {agent-name} agent.
Reference this agent in the "Agent Collaboration" section.
```

## Examples

### Example 1: Standalone Skill

```
/create-skill database-migration --category technical --description "Automated database migration procedures"
```

Creates: `.claude/skills/technical/database-migration/SKILL.md`

### Example 2: Agent-Associated Skill

```
/create-skill planning-agent --agent planning-agent
```

Creates: `.claude/skills/sdd-workflow/planning-agent/SKILL.md`
(Category auto-determined from planning-agent's Product department)

### Example 3: Custom Workflow Skill

```
/create-skill feature-validation --category validation
```

Creates: `.claude/skills/validation/feature-validation/SKILL.md`

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
- Specification/plan/task validation

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

## Implementation

Use the skill creation functions from `create-agent.sh`:

```bash
#!/bin/bash
# Source the create-agent script functions
source /workspaces/sdd-agentic-framework/.specify/scripts/bash/create-agent.sh

# Parse arguments
SKILL_NAME="$1"
shift

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent)
            AGENT_NAME="$2"
            shift 2
            ;;
        --category)
            CATEGORY="$2"
            shift 2
            ;;
        --description)
            DESCRIPTION="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Validate skill name
if [[ ! "$SKILL_NAME" =~ ^[a-z]+(-[a-z]+)*$ ]]; then
    echo "Error: Skill name must be kebab-case"
    exit 1
fi

# If agent provided, get its department
if [[ -n "$AGENT_NAME" ]]; then
    # Find agent file to get department
    AGENT_FILE=$(find .claude/agents -name "${AGENT_NAME}.md" -type f)
    if [[ -z "$AGENT_FILE" ]]; then
        echo "Error: Agent '${AGENT_NAME}' not found"
        exit 1
    fi
    # Extract department from path
    DEPARTMENT=$(dirname "$AGENT_FILE" | xargs basename)
    # Auto-determine category if not provided
    if [[ -z "$CATEGORY" ]]; then
        CATEGORY=$(determine_skill_category "$DEPARTMENT")
    fi
fi

# Default category if still not set
CATEGORY="${CATEGORY:-technical}"

# Default description if not provided
DESCRIPTION="${DESCRIPTION:-Procedural guidance for ${SKILL_NAME}}"

# Create skill
create_skill_for_agent "$SKILL_NAME" "${DEPARTMENT:-engineering}" "$DESCRIPTION"
```

## Validation

After creation, verify:

- [ ] SKILL.md file exists at correct path
- [ ] YAML frontmatter is valid
- [ ] Skill name matches directory name
- [ ] Category is valid (sdd-workflow, validation, technical, integration)
- [ ] If --agent provided, agent collaboration section references the agent
- [ ] All TODO placeholders are present for user to fill

## Notes

- Skills use progressive disclosure to reduce context usage
- Skills provide "how-to" guidance while agents handle autonomous execution
- Each skill should focus on ONE workflow or procedure
- Skills can reference multiple agents for delegation
- Users can create supporting files (scripts/, templates/, reference.md, examples.md)
- Skills are loaded dynamically - only when needed

## Related Commands

- `/create-agent` - Creates an agent (may suggest creating a skill)
- `/specify` - Uses the sdd-specification skill
- `/plan` - Uses the sdd-planning skill
- `/tasks` - Uses the sdd-tasks skill
