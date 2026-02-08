#!/bin/bash

# Agent Creation Tool
# Version: 1.0.0
# Purpose: Automated agent creation with constitutional compliance

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
    source "${SCRIPT_DIR}/common.sh"
fi

# Constants
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AGENTS_DIR="${REPO_ROOT}/.claude/agents"
DOCS_DIR="${REPO_ROOT}/.docs/agents"
TEMPLATE_FILE="${REPO_ROOT}/.specify/templates/agent-template.md"
CONSTITUTION_FILE="${REPO_ROOT}/.specify/memory/constitution.md"
GOVERNANCE_FILE="${REPO_ROOT}/.specify/memory/agent-governance.md"
POLICY_FILE="${REPO_ROOT}/.docs/policies/agent-creation-policy.md"
AUDIT_LOG="${DOCS_DIR}/audit/creation-log.json"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Department definitions with their characteristics
declare -A DEPARTMENTS=(
    ["architecture"]="System design and planning"
    ["engineering"]="Development and implementation"
    ["quality"]="Testing and review"
    ["data"]="Data management and pipelines"
    ["product"]="Requirements and UX"
    ["operations"]="DevOps and maintenance"
)

# Tool access matrix by department
declare -A DEPT_TOOLS=(
    ["architecture"]="Read, Grep, Glob, WebSearch, TodoWrite"
    ["engineering"]="Read, Write, Edit, MultiEdit, Bash, Grep, Glob, WebSearch, TodoWrite"
    ["quality"]="Read, Grep, Glob, Bash, WebSearch, TodoWrite"
    ["data"]="Read, Edit, Bash, Grep, Glob, TodoWrite"
    ["product"]="Read, WebSearch, TodoWrite"
    ["operations"]="Read, Bash, Grep, Glob, TodoWrite"
)

# MCP access matrix by department
declare -A DEPT_MCP=(
    ["architecture"]="mcp__ref-tools, mcp__supabase__search_docs, mcp__perplexity, mcp__claude-context"
    ["engineering"]="mcp__ide, mcp__supabase, mcp__ref-tools, mcp__browsermcp, mcp__claude-context"
    ["quality"]="mcp__ide__executeCode, mcp__ide__getDiagnostics, mcp__ref-tools"
    ["data"]="mcp__supabase, mcp__supabase__apply_migration, mcp__supabase__execute_sql"
    ["product"]="mcp__ref-tools, mcp__browsermcp, mcp__perplexity"
    ["operations"]="mcp__supabase__deploy_edge_function, mcp__supabase__get_logs, mcp__supabase__create_project"
)

# Functions
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        Agent Creation Tool v1.0        ║${NC}"
    echo -e "${BLUE}║     Constitutional Compliance Mode     ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo
}

validate_prerequisites() {
    echo -e "${YELLOW}▶ Validating prerequisites...${NC}"

    if [[ ! -f "$CONSTITUTION_FILE" ]]; then
        echo -e "${RED}✗ Constitution file not found at $CONSTITUTION_FILE${NC}"
        exit 1
    fi

    if [[ ! -f "$GOVERNANCE_FILE" ]]; then
        echo -e "${RED}✗ Governance file not found at $GOVERNANCE_FILE${NC}"
        exit 1
    fi

    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        echo -e "${RED}✗ Template file not found at $TEMPLATE_FILE${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ All prerequisites validated${NC}"
}

analyze_existing_agents() {
    local proposed_name=$1
    echo -e "${YELLOW}▶ Analyzing existing agent architecture...${NC}"

    # Count agents by department
    for dept in "${!DEPARTMENTS[@]}"; do
        if [[ -d "${AGENTS_DIR}/${dept}" ]]; then
            count=$(find "${AGENTS_DIR}/${dept}" -name "*.md" -type f 2>/dev/null | wc -l)
            echo -e "  ${dept}: ${count} agents"
        fi
    done

    # Check for duplicate
    if find "${AGENTS_DIR}" -name "${proposed_name}.md" -type f 2>/dev/null | grep -q .; then
        echo -e "${RED}✗ Agent with name '${proposed_name}' already exists${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ No naming conflicts detected${NC}"
    return 0
}

determine_department() {
    local purpose=$1
    local suggested_dept=""

    echo -e "${YELLOW}▶ Analyzing purpose to determine department...${NC}" >&2

    # Keyword matching for department suggestion
    if echo "$purpose" | grep -qiE "architect|design|system|integration|planning"; then
        suggested_dept="architecture"
    elif echo "$purpose" | grep -qiE "develop|implement|backend|frontend|api|code"; then
        suggested_dept="engineering"
    elif echo "$purpose" | grep -qiE "test|qa|quality|review|audit|security"; then
        suggested_dept="quality"
    elif echo "$purpose" | grep -qiE "data|database|sql|pipeline|analytics|etl"; then
        suggested_dept="data"
    elif echo "$purpose" | grep -qiE "product|requirement|user|ux|feature|story"; then
        suggested_dept="product"
    elif echo "$purpose" | grep -qiE "deploy|release|devops|incident|monitor|operation"; then
        suggested_dept="operations"
    else
        suggested_dept="engineering" # Default
    fi

    echo -e "${GREEN}✓ Suggested department: ${suggested_dept}${NC}" >&2
    echo "$suggested_dept"
}

create_agent_file() {
    local agent_name=$1
    local department=$2
    local description=$3
    local tools=$4
    local responsibilities=$5
    local mcp_access="${DEPT_MCP[$department]:-none}"

    local agent_file="${AGENTS_DIR}/${department}/${agent_name}.md"

    echo -e "${YELLOW}▶ Creating agent definition...${NC}"

    # Create department directory if it doesn't exist
    mkdir -p "${AGENTS_DIR}/${department}"

    # Create agent from template
    cp "$TEMPLATE_FILE" "$agent_file"

    # Replace placeholders
    sed -i "s|{{AGENT_NAME}}|${agent_name}|g" "$agent_file"
    sed -i "s|{{AGENT_DESCRIPTION}}|${description}|g" "$agent_file"
    sed -i "s|{{AGENT_TOOLS}}|${tools}|g" "$agent_file"
    sed -i "s|{{MCP_ACCESS}}|${mcp_access}|g" "$agent_file"
    sed -i "s|{{AGENT_MODEL}}|inherit|g" "$agent_file"
    sed -i "s|{{AGENT_TITLE}}|${agent_name//-/ } Agent|g" "$agent_file"
    sed -i "s|{{DEPARTMENT}}|${department}|g" "$agent_file"
    sed -i "s|{{AGENT_RESPONSIBILITIES}}|${responsibilities}|g" "$agent_file"
    sed -i "s|{{CREATION_DATE}}|$(date +%Y-%m-%d)|g" "$agent_file"
    sed -i "s|{{LAST_MODIFIED}}|$(date +%Y-%m-%d)|g" "$agent_file"

    # Set department-specific values
    case $department in
        "architecture")
            sed -i "s|{{ROLE_TYPE}}|Design \& Planning|g" "$agent_file"
            sed -i "s|{{INTERACTION_LEVEL}}|Strategic|g" "$agent_file"
            ;;
        "engineering")
            sed -i "s|{{ROLE_TYPE}}|Implementation|g" "$agent_file"
            sed -i "s|{{INTERACTION_LEVEL}}|Tactical|g" "$agent_file"
            ;;
        "quality")
            sed -i "s|{{ROLE_TYPE}}|Validation & Review|g" "$agent_file"
            sed -i "s|{{INTERACTION_LEVEL}}|Audit|g" "$agent_file"
            ;;
        "data")
            sed -i "s|{{ROLE_TYPE}}|Data Management|g" "$agent_file"
            sed -i "s|{{INTERACTION_LEVEL}}|Analytical|g" "$agent_file"
            ;;
        "product")
            sed -i "s|{{ROLE_TYPE}}|Requirements & UX|g" "$agent_file"
            sed -i "s|{{INTERACTION_LEVEL}}|User-Focused|g" "$agent_file"
            ;;
        "operations")
            sed -i "s|{{ROLE_TYPE}}|DevOps and Monitoring|g" "$agent_file"
            sed -i "s|{{INTERACTION_LEVEL}}|Operational|g" "$agent_file"
            ;;
        *)
            sed -i "s|{{ROLE_TYPE}}|Specialized|g" "$agent_file"
            sed -i "s|{{INTERACTION_LEVEL}}|Domain-Specific|g" "$agent_file"
            ;;
    esac

    # Replace remaining placeholders with defaults
    sed -i "s|{{SHARED_MEMORY_REFS}}|- Department knowledge: \${REPO_ROOT}/.docs/agents/${department}/|g" "$agent_file"
    sed -i "s|{{DEPARTMENT_GUIDELINES}}|- Follow ${department} best practices\n- Collaborate with other ${department} agents|g" "$agent_file"
    sed -i "s|{{TOOL_POLICIES}}|${tools}|g" "$agent_file"
    sed -i "s|{{RESTRICTED_OPERATIONS}}|- No unauthorized Git operations\n- No production changes without approval|g" "$agent_file"
    sed -i "s|{{UPSTREAM_AGENTS}}|As configured|g" "$agent_file"
    sed -i "s|{{INPUT_FORMAT}}|Markdown/JSON|g" "$agent_file"
    sed -i "s|{{INPUT_VALIDATION}}|Type and format checking|g" "$agent_file"
    sed -i "s|{{DOWNSTREAM_AGENTS}}|As configured|g" "$agent_file"
    sed -i "s|{{OUTPUT_FORMAT}}|Markdown/JSON|g" "$agent_file"
    sed -i "s|{{OUTPUT_GUARANTEES}}|Accurate and validated|g" "$agent_file"
    sed -i "s|{{DOMAIN_EXPERTISE}}|${department} domain knowledge|g" "$agent_file"
    sed -i "s|{{TECHNICAL_SPECS}}|As per department standards|g" "$agent_file"
    sed -i "s|{{BEST_PRACTICES}}|Industry best practices for ${department}|g" "$agent_file"
    sed -i "s|{{LIMITATIONS}}|Tool access restrictions|g" "$agent_file"
    sed -i "s|{{MINOR_ESCALATION}}|Log and continue|g" "$agent_file"
    sed -i "s|{{MAJOR_ESCALATION}}|Alert user and wait|g" "$agent_file"
    sed -i "s|{{CRITICAL_ESCALATION}}|Stop and request help|g" "$agent_file"
    sed -i "s|{{SIMPLE_RESPONSE_TIME}}|2s|g" "$agent_file"
    sed -i "s|{{COMPLEX_RESPONSE_TIME}}|10s|g" "$agent_file"
    sed -i "s|{{LARGE_RESPONSE_TIME}}|30s|g" "$agent_file"
    sed -i "s|{{ACCURACY_TARGET}}|95|g" "$agent_file"
    sed -i "s|{{SUCCESS_TARGET}}|90|g" "$agent_file"
    sed -i "s|{{SATISFACTION_TARGET}}|4|g" "$agent_file"
    sed -i "s|{{REVIEW_SCHEDULE}}|Quarterly|g" "$agent_file"

    echo -e "${GREEN}✓ Agent file created at ${agent_file}${NC}"
}

create_memory_structure() {
    local agent_name=$1
    local department=$2

    echo -e "${YELLOW}▶ Creating memory structure...${NC}"

    local memory_base="${DOCS_DIR}/${department}/${agent_name}"

    # Create memory directories
    mkdir -p "${memory_base}/context"
    mkdir -p "${memory_base}/knowledge"
    mkdir -p "${memory_base}/decisions"
    mkdir -p "${memory_base}/performance"

    # Create initial memory files
    echo "# ${agent_name} Context" > "${memory_base}/context/README.md"
    echo "Current working context and state for ${agent_name}" >> "${memory_base}/context/README.md"

    echo "# ${agent_name} Knowledge Base" > "${memory_base}/knowledge/README.md"
    echo "Accumulated knowledge and learnings" >> "${memory_base}/knowledge/README.md"

    echo "# ${agent_name} Decision Log" > "${memory_base}/decisions/README.md"
    echo "Historical decisions and rationales" >> "${memory_base}/decisions/README.md"

    echo "# ${agent_name} Performance Metrics" > "${memory_base}/performance/README.md"
    echo "Performance tracking and optimization data" >> "${memory_base}/performance/README.md"

    echo -e "${GREEN}✓ Memory structure created at ${memory_base}${NC}"
}

validate_agent_compliance() {
    local agent_file=$1

    echo -e "${YELLOW}▶ Validating constitutional compliance...${NC}"

    local errors=0

    # Check for constitution reference
    if ! grep -q "${CONSTITUTION_FILE}" "$agent_file"; then
        echo -e "${RED}✗ Missing constitution reference${NC}"
        ((errors++))
    else
        echo -e "${GREEN}✓ Constitution reference present${NC}"
    fi

    # Check for governance reference
    if ! grep -q "${GOVERNANCE_FILE}" "$agent_file"; then
        echo -e "${RED}✗ Missing governance reference${NC}"
        ((errors++))
    else
        echo -e "${GREEN}✓ Governance reference present${NC}"
    fi

    # Check for Git operations warning
    if ! grep -q "NO Git operations without explicit user approval" "$agent_file"; then
        echo -e "${RED}✗ Missing Git operations mandate${NC}"
        ((errors++))
    else
        echo -e "${GREEN}✓ Git operations mandate present${NC}"
    fi

    # Check for test-first principle
    if ! grep -q "Test-First" "$agent_file"; then
        echo -e "${RED}✗ Missing test-first principle${NC}"
        ((errors++))
    else
        echo -e "${GREEN}✓ Test-first principle present${NC}"
    fi

    if [[ $errors -eq 0 ]]; then
        echo -e "${GREEN}✓ All compliance checks passed${NC}"
        return 0
    else
        echo -e "${RED}✗ Compliance validation failed with ${errors} errors${NC}"
        return 1
    fi
}

log_creation() {
    local agent_name=$1
    local department=$2
    local status=$3

    mkdir -p "$(dirname "$AUDIT_LOG")"

    if [[ ! -f "$AUDIT_LOG" ]]; then
        echo "[]" > "$AUDIT_LOG"
    fi

    local entry=$(cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "agent": "${agent_name}",
  "department": "${department}",
  "action": "creation",
  "status": "${status}",
  "created_by": "${USER:-system}",
  "version": "1.0.0"
}
EOF
)

    # Add entry to log (requires jq for proper JSON handling)
    if command -v jq &> /dev/null; then
        jq ". += [${entry}]" "$AUDIT_LOG" > "${AUDIT_LOG}.tmp" && mv "${AUDIT_LOG}.tmp" "$AUDIT_LOG"
    else
        # Fallback without jq (less reliable)
        echo "${entry}" >> "${AUDIT_LOG}.entries"
    fi

    echo -e "${GREEN}✓ Creation logged to audit trail${NC}"
}

update_claude_md() {
    local agent_name=$1
    local department=$2
    local description=$3

    echo -e "${YELLOW}▶ Updating CLAUDE.md with new agent...${NC}"

    local claude_file="${REPO_ROOT}/CLAUDE.md"

    if [[ ! -f "$claude_file" ]]; then
        echo -e "${YELLOW}⚠ CLAUDE.md not found, skipping update${NC}"
        return
    fi

    # Check if agents section exists
    if ! grep -q "## Available Agents" "$claude_file"; then
        # Add agents section before the closing
        echo "" >> "$claude_file"
        echo "## Available Agents" >> "$claude_file"
        echo "" >> "$claude_file"
        echo "The following specialized agents are available for specific tasks:" >> "$claude_file"
        echo "" >> "$claude_file"
    fi

    # Add agent entry if not already present
    if ! grep -q "### ${agent_name}" "$claude_file"; then
        # Find the line number after "## Available Agents"
        local insert_line=$(grep -n "## Available Agents" "$claude_file" | cut -d: -f1)
        if [[ -n "$insert_line" ]]; then
            insert_line=$((insert_line + 3))

            # Create agent documentation
            local agent_doc="### ${agent_name} (${department})

**Purpose**: ${description}

**Usage**: \`Use the ${agent_name} agent to...\`

**Triggers**: See \`.specify/memory/agent-collaboration.md\` for automatic triggers

---
"
            # Insert the documentation
            echo "$agent_doc" | sed -i "${insert_line}r /dev/stdin" "$claude_file"
            echo -e "${GREEN}✓ Updated CLAUDE.md${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Agent already documented in CLAUDE.md${NC}"
    fi
}

update_agent_registry() {
    local agent_name=$1
    local department=$2
    local description=$3
    local tools=$4
    local mcp_access=$5

    echo -e "${YELLOW}▶ Updating agent registry...${NC}"

    local registry_file="${DOCS_DIR}/agent-registry.json"

    # Create registry if it doesn't exist
    if [[ ! -f "$registry_file" ]]; then
        mkdir -p "$(dirname "$registry_file")"
        echo '{"agents": {}, "departments": {}}' > "$registry_file"
    fi

    # Create agent entry
    local agent_entry=$(cat <<EOF
{
  "department": "${department}",
  "description": "${description}",
  "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "tools": "${tools}",
  "mcp_access": "${mcp_access}",
  "status": "active",
  "file": "${AGENTS_DIR}/${department}/${agent_name}.md",
  "memory": "${DOCS_DIR}/${department}/${agent_name}/"
}
EOF
)

    # Update registry using jq if available
    if command -v jq &> /dev/null; then
        jq ".agents[\"${agent_name}\"] = ${agent_entry}" "$registry_file" > "${registry_file}.tmp" && mv "${registry_file}.tmp" "$registry_file"

        # Update department count
        local dept_count=$(jq ".agents | map(select(.department == \"${department}\")) | length" "$registry_file")
        jq ".departments[\"${department}\"] = ${dept_count}" "$registry_file" > "${registry_file}.tmp" && mv "${registry_file}.tmp" "$registry_file"

        echo -e "${GREEN}✓ Agent registry updated${NC}"
    else
        echo -e "${YELLOW}⚠ jq not available, registry update skipped${NC}"
    fi
}

update_collaboration_triggers() {
    local agent_name=$1
    local department=$2
    local description=$3

    echo -e "${YELLOW}▶ Updating collaboration triggers...${NC}"

    local collab_file="${REPO_ROOT}/.specify/memory/agent-collaboration.md"

    if [[ ! -f "$collab_file" ]]; then
        echo -e "${YELLOW}⚠ Collaboration file not found, skipping${NC}"
        return
    fi

    # Extract keywords from description for trigger patterns
    local keywords=""
    case $department in
        "architecture")
            keywords="design|architecture|planning|system|integration"
            ;;
        "engineering")
            keywords="implement|develop|code|build|create"
            ;;
        "quality")
            keywords="test|review|audit|quality|security"
            ;;
        "data")
            keywords="database|sql|migration|query|schema"
            ;;
        "product")
            keywords="requirement|user|feature|story|ux"
            ;;
        "operations")
            keywords="deploy|monitor|devops|release|pipeline"
            ;;
    esac

    echo -e "${GREEN}✓ Collaboration triggers configured for ${department} department${NC}"
}

# Skill creation functions
should_suggest_skill() {
    local agent_name=$1
    local department=$2
    local description=$3

    # Product/Operations departments often need procedural skills
    if [[ "$department" == "product" || "$department" == "operations" ]]; then
        return 0
    fi

    # Workflow/command keywords
    if echo "$description" | grep -qiE "workflow|command|procedure|step-by-step|orchestration|coordination|validation|compliance|integration|setup|initialization|/plan|/specify|/tasks"; then
        return 0
    fi

    # Agent name patterns
    if [[ "$agent_name" =~ -orchestrator$|-validator$|-planner$ ]]; then
        return 0
    fi

    return 1
}

suggest_skill_creation() {
    local agent_name=$1
    local department=$2
    local description=$3

    if ! should_suggest_skill "$agent_name" "$department" "$description"; then
        return
    fi

    echo
    echo -e "${YELLOW}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║     ✨ Skill Creation Opportunity Detected      ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "This agent appears to handle ${BLUE}procedural/workflow${NC} work."
    echo -e "Creating an associated ${GREEN}skill${NC} provides:"
    echo -e "  • Progressive disclosure (30-50% context reduction)"
    echo -e "  • Reusable procedures across sessions"
    echo -e "  • Self-documenting workflows"
    echo
    read -p "Create skill for ${agent_name}? (y/n): " create_skill

    if [[ "$create_skill" =~ ^[Yy]$ ]]; then
        create_skill_for_agent "$agent_name" "$department" "$description"
    else
        echo -e "${BLUE}ℹ  You can create a skill later using: /create-skill ${agent_name}${NC}"
    fi
}

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

create_skill_for_agent() {
    local agent_name=$1
    local department=$2
    local description=$3

    local skill_category=$(determine_skill_category "$department")
    local skill_name="${agent_name}"
    local skill_dir="${REPO_ROOT}/plugins/sdd-domain-${skill_category}/skills/${skill_name}"

    echo
    echo -e "${YELLOW}▶ Creating skill: ${skill_name}${NC}"

    # Create skill directory
    mkdir -p "$skill_dir"

    # Generate SKILL.md from template
    generate_skill_template "$skill_dir/SKILL.md" "$skill_name" "$agent_name" "$description" "$department"

    echo -e "${GREEN}✓ Skill created: plugins/sdd-domain-${skill_category}/skills/${skill_name}/SKILL.md${NC}"
    echo -e "${BLUE}ℹ  Next steps:${NC}"
    echo -e "   1. Edit the skill file to add detailed procedure steps"
    echo -e "   2. Add specific trigger keywords"
    echo -e "   3. Include concrete examples"
    echo -e "   4. Define validation steps"
}

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

    cat > "$skill_file" <<'EOF'
---
name: SKILL_NAME
description: |
  SKILL_DESCRIPTION

  This skill provides step-by-step procedural guidance for tasks handled by
  the AGENT_NAME agent. Use when you need to understand the workflow or
  execute tasks that AGENT_NAME would typically handle.

  Triggered by: [TODO: Add trigger phrases]
allowed-tools: ALLOWED_TOOLS
---

# SKILL_NAME Skill

## When to Use

Activate this skill when:
- [TODO: Add specific trigger conditions]
- User requests work that AGENT_NAME handles
- [TODO: Add workflow phase or command]
- [TODO: Add domain-specific scenarios]

**Trigger Keywords**: [TODO: Add comma-separated keywords]

**Prerequisites**: [TODO: Add any required preconditions]

## Procedure

### Step 1: [TODO: Initialization/Setup]

**Action**: [TODO: Describe what to do in this step]

```bash
# TODO: Add commands if applicable
# Example: script.sh --flag value
```

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
When to delegate to AGENT_NAME:
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
```
[TODO: Show what files/artifacts were created]
```

**Validation**: [TODO: How to verify success]

### Example 2: [TODO: Alternative Scenario]

**User Request**: "[TODO: Different user request]"

**Skill Execution**:
1. [TODO: Steps for this scenario]

**Expected Result**: [TODO: Outcome]

## Agent Collaboration

### AGENT_NAME
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
**Created**: CREATION_DATE
**Last Updated**: CREATION_DATE
**Department**: DEPARTMENT
**Associated Agent**: AGENT_NAME
EOF

    # Replace placeholders
    sed -i "s|SKILL_NAME|${skill_name}|g" "$skill_file"
    sed -i "s|AGENT_NAME|${agent_name}|g" "$skill_file"
    sed -i "s|SKILL_DESCRIPTION|${description}|g" "$skill_file"
    sed -i "s|ALLOWED_TOOLS|${default_tools}|g" "$skill_file"
    sed -i "s|DEPARTMENT|${department}|g" "$skill_file"
    sed -i "s|CREATION_DATE|$(date +%Y-%m-%d)|g" "$skill_file"
}

# Interactive mode
interactive_create() {
    print_header
    validate_prerequisites

    echo -e "${BLUE}Starting interactive agent creation...${NC}"
    echo

    # Get agent name
    read -p "Enter agent name (kebab-case, e.g., 'backend-engineer'): " agent_name
    if [[ ! "$agent_name" =~ ^[a-z]+(-[a-z]+)*$ ]]; then
        echo -e "${RED}✗ Invalid name format. Use kebab-case only.${NC}"
        exit 1
    fi

    # Check for duplicates
    if ! analyze_existing_agents "$agent_name"; then
        exit 1
    fi

    # Get agent purpose
    echo
    read -p "Enter agent purpose/description (one line): " description

    # Determine department
    suggested_dept=$(determine_department "$description")
    echo
    echo "Available departments:"
    for dept in "${!DEPARTMENTS[@]}"; do
        echo "  - ${dept}: ${DEPARTMENTS[$dept]}"
    done
    echo
    read -p "Enter department (suggested: ${suggested_dept}): " department
    department=${department:-$suggested_dept}

    if [[ ! "${DEPARTMENTS[$department]+exists}" ]]; then
        echo -e "${RED}✗ Invalid department${NC}"
        exit 1
    fi

    # Get tools (use department defaults or custom)
    default_tools="${DEPT_TOOLS[$department]}"
    echo
    echo "Default tools for ${department}: ${default_tools}"
    read -p "Use default tools? (y/n): " use_defaults

    if [[ "$use_defaults" != "y" ]]; then
        read -p "Enter comma-separated tool list: " tools
    else
        tools="$default_tools"
    fi

    # Get responsibilities
    echo
    echo "Enter agent's core responsibilities (end with empty line):"
    responsibilities=""
    while IFS= read -r line; do
        [[ -z "$line" ]] && break
        responsibilities+="- ${line}\n"
    done

    # Create the agent
    echo
    create_agent_file "$agent_name" "$department" "$description" "$tools" "$responsibilities"
    create_memory_structure "$agent_name" "$department"

    # Get MCP access for the department
    local mcp_access="${DEPT_MCP[$department]:-none}"

    # Update related files
    update_claude_md "$agent_name" "$department" "$description"
    update_agent_registry "$agent_name" "$department" "$description" "$tools" "$mcp_access"
    update_collaboration_triggers "$agent_name" "$department" "$description"

    # Validate compliance
    agent_file="${AGENTS_DIR}/${department}/${agent_name}.md"
    if validate_agent_compliance "$agent_file"; then
        log_creation "$agent_name" "$department" "success"
        echo
        echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║     Agent Successfully Created!        ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
        echo
        echo "Agent Location: ${agent_file}"
        echo "Memory Location: ${DOCS_DIR}/${department}/${agent_name}/"
        echo "MCP Access: ${mcp_access}"
        echo
        echo "To use this agent, invoke it with:"
        echo "  'Please use the ${agent_name} agent to...'"
        echo
        echo "Files Updated:"
        echo "  - CLAUDE.md (agent documentation)"
        echo "  - Agent registry (${DOCS_DIR}/agent-registry.json)"
        echo "  - Collaboration triggers configured"

        # Suggest skill creation for workflow/procedural agents
        suggest_skill_creation "$agent_name" "$department" "$description"
    else
        log_creation "$agent_name" "$department" "failed_validation"
        echo -e "${RED}Agent created but failed validation. Please review and fix.${NC}"
        exit 1
    fi
}

# JSON mode for programmatic creation
json_create() {
    local json_input=$1

    # Parse JSON input (requires jq)
    if ! command -v jq &> /dev/null; then
        echo '{"error": "jq is required for JSON mode"}'
        exit 1
    fi

    local agent_name=$(echo "$json_input" | jq -r '.name')
    local description=$(echo "$json_input" | jq -r '.description')
    local department=$(echo "$json_input" | jq -r '.department // empty')
    local tools=$(echo "$json_input" | jq -r '.tools // empty')
    local responsibilities=$(echo "$json_input" | jq -r '.responsibilities // empty')

    # Validate required fields
    if [[ -z "$agent_name" ]] || [[ -z "$description" ]]; then
        echo '{"error": "name and description are required"}'
        exit 1
    fi

    # Auto-determine department if not provided
    if [[ -z "$department" ]]; then
        department=$(determine_department "$description")
    fi

    # Use default tools if not provided
    if [[ -z "$tools" ]]; then
        if [[ "${DEPT_TOOLS[$department]+exists}" ]]; then
            tools="${DEPT_TOOLS[$department]}"
        else
            tools="Read, Grep, Glob, TodoWrite"  # Minimal default
        fi
    fi

    # Analyze existing agents
    if ! analyze_existing_agents "$agent_name" > /dev/null 2>&1; then
        echo '{"error": "Agent name already exists"}'
        exit 1
    fi

    # Create agent
    create_agent_file "$agent_name" "$department" "$description" "$tools" "$responsibilities" > /dev/null 2>&1
    create_memory_structure "$agent_name" "$department" > /dev/null 2>&1

    # Get MCP access for the department
    local mcp_access="${DEPT_MCP[$department]:-none}"

    # Update related files
    update_claude_md "$agent_name" "$department" "$description" > /dev/null 2>&1
    update_agent_registry "$agent_name" "$department" "$description" "$tools" "$mcp_access" > /dev/null 2>&1
    update_collaboration_triggers "$agent_name" "$department" "$description" > /dev/null 2>&1

    # Validate
    agent_file="${AGENTS_DIR}/${department}/${agent_name}.md"
    if validate_agent_compliance "$agent_file" > /dev/null 2>&1; then
        log_creation "$agent_name" "$department" "success" > /dev/null 2>&1

        # Auto-create skill if detection passes (JSON mode creates automatically)
        local skill_created="false"
        local skill_file=""
        if should_suggest_skill "$agent_name" "$department" "$description"; then
            local skill_category=$(determine_skill_category "$department")
            skill_file="plugins/sdd-domain-${skill_category}/skills/${agent_name}/SKILL.md"
            create_skill_for_agent "$agent_name" "$department" "$description" > /dev/null 2>&1
            skill_created="true"
        fi

        echo "{\"success\": true, \"agent\": \"${agent_name}\", \"department\": \"${department}\", \"file\": \"${agent_file}\", \"mcp_access\": \"${mcp_access}\", \"skill_created\": ${skill_created}, \"skill_file\": \"${skill_file}\"}"
    else
        log_creation "$agent_name" "$department" "failed_validation" > /dev/null 2>&1
        echo '{"success": false, "error": "Validation failed"}'
        exit 1
    fi
}

# Main execution
main() {
    case "${1:-}" in
        --json)
            if [[ -n "${2:-}" ]]; then
                json_create "$2"
            else
                # Read from stdin
                json_input=$(cat)
                json_create "$json_input"
            fi
            ;;
        --help|-h)
            echo "Agent Creation Tool"
            echo "Usage:"
            echo "  $0                    # Interactive mode"
            echo "  $0 --json '{...}'    # JSON mode"
            echo "  echo '{...}' | $0 --json  # JSON from stdin"
            echo ""
            echo "JSON format:"
            echo "  {"
            echo "    \"name\": \"agent-name\","
            echo "    \"description\": \"Agent purpose\","
            echo "    \"department\": \"engineering\",  // optional"
            echo "    \"tools\": \"Read, Write, ...\",   // optional"
            echo "    \"responsibilities\": \"...\"      // optional"
            echo "  }"
            ;;
        *)
            interactive_create
            ;;
    esac
}

# Run main function
main "$@"