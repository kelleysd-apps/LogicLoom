#!/bin/bash

# Create Skill Command Wrapper
# This script is called when the /create-skill command is used

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Department to category mapping
determine_skill_category() {
    local department=$1
    case "$department" in
        product)
            echo "sdd-workflow"
            ;;
        quality)
            echo "validation"
            ;;
        operations)
            echo "integration"
            ;;
        *)
            echo "technical"
            ;;
    esac
}

# Generate skill template
generate_skill_template() {
    local skill_file=$1
    local skill_name=$2
    local agent_name=$3
    local description=$4
    local department=$5

    # Determine default tools based on department
    local default_tools="Read, Write, Bash, Grep, Glob"
    case "$department" in
        product)
            default_tools="Read, Write, Bash, Grep, Glob, TodoWrite"
            ;;
        operations)
            default_tools="Read, Bash, Grep, Glob"
            ;;
        quality)
            default_tools="Read, Bash, Grep, Glob"
            ;;
    esac

    cat > "$skill_file" <<EOF
---
name: ${skill_name}
description: |
  ${description}

  This skill provides step-by-step procedural guidance for tasks handled by
  the ${agent_name} agent. Use when you need to understand the workflow or
  execute tasks that ${agent_name} would typically handle.

  Triggered by: [TODO: Add trigger phrases]
allowed-tools: ${default_tools}
---

# ${skill_name} Skill

## When to Use

Activate this skill when:
- [TODO: Add specific trigger conditions]
- User requests work that ${agent_name} handles
- [TODO: Add workflow phase or command]
- [TODO: Add domain-specific scenarios]

**Trigger Keywords**: [TODO: Add comma-separated keywords]

**Prerequisites**: [TODO: Add any required preconditions]

## Procedure

### Step 1: [TODO: Initialization/Setup]

**Action**: [TODO: Describe what to do in this step]

\`\`\`bash
# TODO: Add commands if applicable
# Example: script.sh --flag value
\`\`\`

**Expected Outcome**: [TODO: What should result from this step]

### Step 2: [TODO: Main Processing]

**Action**: [TODO: Describe core processing steps]

**Details**:
- [TODO: Important sub-step or consideration]
- [TODO: Another important detail]
- [TODO: Edge case handling]

**Expected Outcome**: [TODO: What should be produced]

### Step 3: [TODO: Validation/Completion]

**Action**: [TODO: Describe validation or finalization steps]

**Checklist**:
- [ ] [TODO: Validation item 1]
- [ ] [TODO: Validation item 2]
- [ ] [TODO: Validation item 3]

**Expected Outcome**: [TODO: Final deliverable or state]

## Constitutional Compliance

### Principle I: Library-First Architecture
[TODO: How this skill ensures features start as standalone libraries]

### Principle II: Test-First Development
[TODO: How this skill enforces writing tests before implementation]

### Principle VI: Git Operation Approval
- **CRITICAL**: NO autonomous git operations
- Request user approval for ANY git commands
- Document git operations in procedure steps

### Principle VIII: Documentation Synchronization
[TODO: How this skill maintains documentation]

### Principle X: Agent Delegation Protocol
When to delegate to ${agent_name}:
- [TODO: Complex scenarios requiring agent autonomy]
- [TODO: Multi-step orchestration]
- [TODO: Specialized domain work]

## Examples

### Example 1: [TODO: Common Scenario Name]

**User Request**: "[TODO: What the user asked for]"

**Skill Execution**:
1. [TODO: First action taken]
2. [TODO: Second action taken]
3. [TODO: Final action taken]

**Generated Output**:
\`\`\`
[TODO: Show what files/artifacts were created]
\`\`\`

**Validation**: [TODO: How to verify success]

### Example 2: [TODO: Alternative Scenario]

**User Request**: "[TODO: Different user request]"

**Skill Execution**:
1. [TODO: Steps for this scenario]

**Expected Result**: [TODO: Outcome]

## Agent Collaboration

### ${agent_name}
**When to delegate**: [TODO: Situations requiring this agent's autonomy]

**What they handle**: [TODO: Specific capabilities of this agent]

**Handoff format**: [TODO: How to invoke the agent]

### Related Agents
[TODO: List other agents this skill might reference]
- **agent-name**: [TODO: When and why to use this agent]

## Validation

Verify the skill executed correctly:

- [ ] [TODO: Primary deliverable created]
- [ ] [TODO: Quality check passed]
- [ ] [TODO: Constitutional compliance verified]
- [ ] [TODO: Documentation updated]
- [ ] [TODO: User notified of next steps]

## Troubleshooting

### Issue: [TODO: Common Problem 1]

**Cause**: [TODO: Why this problem occurs]

**Solution**: [TODO: Step-by-step resolution]

**Prevention**: [TODO: How to avoid this in the future]

### Issue: [TODO: Common Problem 2]

**Cause**: [TODO: Root cause]

**Solution**: [TODO: Fix procedure]

## Notes

**Important Considerations**:
- [TODO: Critical information about this procedure]
- [TODO: Performance implications]
- [TODO: Known limitations]

**Best Practices**:
- [TODO: Recommended approach]
- [TODO: Tips for efficiency]

**Related Skills**:
- **skill-name**: [TODO: How this skill relates]
- **skill-name**: [TODO: Workflow sequence]

## Supporting Files

This skill directory can include:

### scripts/ (optional)
Executable utilities to automate parts of the procedure

### templates/ (optional)
Reusable content templates for generated artifacts

### reference.md (optional)
Detailed technical documentation and API references

### examples.md (optional)
Extended usage examples and edge cases

---

**Skill Version**: 1.0.0
**Created**: $(date +%Y-%m-%d)
**Last Updated**: $(date +%Y-%m-%d)
**Department**: ${department}
**Associated Agent**: ${agent_name}
EOF
}

# Parse command arguments
# Expected formats:
#   /create-skill skill-name
#   /create-skill skill-name --agent agent-name
#   /create-skill skill-name --category category-name
#   /create-skill skill-name --description "text"

if [[ $# -eq 0 ]]; then
    echo "Usage: /create-skill skill-name [options]"
    echo ""
    echo "Options:"
    echo "  --agent agent-name          Associate with existing agent"
    echo "  --category category-name    Skill category (sdd-workflow, validation, technical, integration)"
    echo "  --description \"text\"        Brief description of the skill"
    echo ""
    echo "Examples:"
    echo "  /create-skill my-skill --agent planning-agent"
    echo "  /create-skill api-testing --category validation"
    echo "  /create-skill deployment --category integration --description \"Deployment procedures\""
    exit 1
fi

# Parse arguments
SKILL_NAME="$1"
shift

AGENT_NAME=""
CATEGORY=""
DESCRIPTION=""

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
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate skill name
if [[ ! "$SKILL_NAME" =~ ^[a-z]+(-[a-z]+)*$ ]]; then
    echo -e "${RED}✗ Invalid skill name. Must be kebab-case (lowercase with hyphens)${NC}"
    exit 1
fi

# If agent provided, get its department
DEPARTMENT="engineering"  # Default
if [[ -n "$AGENT_NAME" ]]; then
    AGENT_FILE=$(find "${REPO_ROOT}/.claude/agents" -name "${AGENT_NAME}.md" -type f 2>/dev/null | head -1)
    if [[ -z "$AGENT_FILE" ]]; then
        echo -e "${RED}✗ Agent '${AGENT_NAME}' not found${NC}"
        exit 1
    fi
    # Extract department from path
    DEPARTMENT=$(dirname "$AGENT_FILE" | xargs basename)
    echo -e "${GREEN}✓ Found agent in department: ${DEPARTMENT}${NC}"
fi

# Auto-determine category if not provided
if [[ -z "$CATEGORY" ]]; then
    CATEGORY=$(determine_skill_category "$DEPARTMENT")
    echo -e "${BLUE}ℹ  Auto-determined category: ${CATEGORY}${NC}"
fi

# Default description if not provided
if [[ -z "$DESCRIPTION" ]]; then
    if [[ -n "$AGENT_NAME" ]]; then
        DESCRIPTION="Procedural guidance for ${AGENT_NAME} agent workflows"
    else
        DESCRIPTION="Procedural guidance for ${SKILL_NAME}"
    fi
fi

# Create skill directory
SKILL_DIR="${REPO_ROOT}/plugins/sdd-domain-${CATEGORY}/skills/${SKILL_NAME}"

if [[ -d "$SKILL_DIR" ]]; then
    echo -e "${RED}✗ Skill '${SKILL_NAME}' already exists in category '${CATEGORY}'${NC}"
    exit 1
fi

echo -e "${YELLOW}▶ Creating skill: ${SKILL_NAME}${NC}"
mkdir -p "$SKILL_DIR"

# Generate SKILL.md
SKILL_FILE="${SKILL_DIR}/SKILL.md"
AGENT_NAME_FOR_TEMPLATE="${AGENT_NAME:-${SKILL_NAME}}"
generate_skill_template "$SKILL_FILE" "$SKILL_NAME" "$AGENT_NAME_FOR_TEMPLATE" "$DESCRIPTION" "$DEPARTMENT"

echo -e "${GREEN}✓ Skill created successfully!${NC}"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✨ Skill: ${SKILL_NAME}${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Category:${NC} ${CATEGORY}"
echo -e "${BLUE}Location:${NC} plugins/sdd-domain-${CATEGORY}/skills/${SKILL_NAME}/SKILL.md"
if [[ -n "$AGENT_NAME" ]]; then
    echo -e "${BLUE}Associated Agent:${NC} ${AGENT_NAME}"
fi
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Edit the skill file to add detailed procedure steps"
echo "  2. Replace [TODO] placeholders with actual content"
echo "  3. Add specific trigger keywords"
echo "  4. Include concrete examples"
echo "  5. Define validation steps"
echo ""
