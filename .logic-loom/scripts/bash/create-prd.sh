#!/usr/bin/env bash
# Create Product Requirements Document (PRD) for project initialization
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Color codes for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Parse arguments
JSON_MODE=false
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        --help|-h)
            echo "Usage: $0 [--json] [project_name]"
            echo ""
            echo "Creates a Product Requirements Document (PRD) that serves as SSOT for:"
            echo "  - Feature specifications"
            echo "  - Constitutional customizations"
            echo "  - Agent planning"
            echo "  - Project initialization"
            echo ""
            echo "Options:"
            echo "  --json    Output in JSON format for programmatic use"
            echo "  --help    Show this help message"
            exit 0
            ;;
        *) ARGS+=("$arg") ;;
    esac
done

PROJECT_NAME="${ARGS[*]}"

# Get repository root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PRD_DIR="$REPO_ROOT/.docs/prd"
TEMPLATE="$REPO_ROOT/.logic-loom/templates/prd-template.md"

# Ensure directories exist
mkdir -p "$PRD_DIR"

# Banner
if [ "$JSON_MODE" = false ]; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Product Requirements Document${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
fi

# Interactive mode if no project name provided
if [ -z "$PROJECT_NAME" ]; then
    if [ "$JSON_MODE" = false ]; then
        echo -e "${YELLOW}Starting interactive PRD creation...${NC}"
        echo ""
        read -p "Enter project name: " PROJECT_NAME
        if [ -z "$PROJECT_NAME" ]; then
            echo -e "${RED}Error: Project name cannot be empty${NC}" >&2
            exit 1
        fi
    else
        echo '{"error":"Project name required","usage":"create-prd.sh [project_name]"}' >&2
        exit 1
    fi
fi

# Sanitize project name for filename
FILENAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//' | sed 's/-$//')
PRD_FILE="$PRD_DIR/prd.md"

if [ "$JSON_MODE" = false ]; then
    echo -e "${BLUE}Creating PRD for: ${GREEN}${PROJECT_NAME}${NC}"
    echo ""
fi

# Check if PRD already exists
if [ -f "$PRD_FILE" ]; then
    if [ "$JSON_MODE" = false ]; then
        echo -e "${YELLOW}Warning: PRD already exists at $PRD_FILE${NC}"
        read -p "Overwrite existing PRD? (y/n): " OVERWRITE
        if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Cancelled. Existing PRD preserved.${NC}"
            exit 0
        fi
    else
        echo '{"error":"PRD already exists","path":"'"$PRD_FILE"'"}' >&2
        exit 1
    fi
fi

# Copy template and customize
if [ ! -f "$TEMPLATE" ]; then
    if [ "$JSON_MODE" = false ]; then
        echo -e "${RED}Error: PRD template not found at $TEMPLATE${NC}" >&2
    else
        echo '{"error":"Template not found","path":"'"$TEMPLATE"'"}' >&2
    fi
    exit 1
fi

cp "$TEMPLATE" "$PRD_FILE"

# Replace placeholders
CURRENT_DATE=$(date +"%Y-%m-%d")
sed -i.bak "s/\[PROJECT NAME\]/$PROJECT_NAME/g" "$PRD_FILE"
sed -i.bak "s/\[project-name\]/$FILENAME/g" "$PRD_FILE"
sed -i.bak "s/\[DATE\]/$CURRENT_DATE/g" "$PRD_FILE"
rm -f "$PRD_FILE.bak"

if [ "$JSON_MODE" = false ]; then
    echo -e "${GREEN}✓${NC} PRD template created at: $PRD_FILE"
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Next Steps${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "1. ${YELLOW}Open PRD in Claude Code${NC}"
    echo -e "   - Review and complete all sections"
    echo -e "   - Use prd-specialist agent for guidance (one of the 11 remaining agents)"
    echo ""
    echo -e "2. ${YELLOW}Focus on these key sections${NC}:"
    echo -e "   • Executive Summary (vision, problem, success metrics)"
    echo -e "   • User Personas & Journeys"
    echo -e "   • Core Features & Requirements"
    echo -e "   • System Architecture Principles (customize 16 constitutional principles)"
    echo -e "   • Release Strategy (define MVP)"
    echo ""
    echo -e "3. ${YELLOW}After PRD completion${NC}:"
    echo -e "   • Run PRD Review Checklist"
    echo -e "   • Get stakeholder approval"
    echo -e "   • Update ${GREEN}.logic-loom/memory/constitution.md${NC} with customizations"
    echo -e "   • Create custom agents identified in PRD"
    echo -e "   • Begin feature specifications with ${GREEN}/specification${NC}"
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   PRD-Driven Workflow${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${YELLOW}The PRD serves as Single Source of Truth (SSOT) for:${NC}"
    echo ""
    echo -e "  📋 ${GREEN}/specification${NC} → Pulls user stories, personas, acceptance criteria from PRD"
    echo -e "     (combines /specify, /plan, /tasks into unified workflow)"
    echo -e "  ⚙️  ${GREEN}Constitution${NC} → Customized with project-specific guidance from PRD"
    echo -e "  🤖 ${GREEN}Custom Agents${NC} → Created based on specialized needs in PRD"
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${GREEN}PRD creation complete!${NC} Start by reviewing:"
    echo -e "  ${YELLOW}$PRD_FILE${NC}"
    echo ""
else
    # JSON output
    echo '{'
    echo '  "status": "success",'
    echo '  "prd_path": "'"$PRD_FILE"'",'
    echo '  "project_name": "'"$PROJECT_NAME"'",'
    echo '  "date": "'"$CURRENT_DATE"'",'
    echo '  "next_steps": ['
    echo '    "Complete PRD sections with prd-specialist agent",'
    echo '    "Run PRD Review Checklist",'
    echo '    "Update constitution.md with customizations",'
    echo '    "Create custom agents from PRD",'
    echo '    "Begin feature specs with /specification"'
    echo '  ]'
    echo '}'
fi

# Create a quick reference card for the user
QUICKREF="$PRD_DIR/PRD_QUICK_REFERENCE.md"
cat > "$QUICKREF" << 'EOF'
# PRD Quick Reference

## What is the PRD?

Your **Product Requirements Document (PRD)** is the Single Source of Truth for your entire project. It defines:
- What you're building and why
- Who you're building it for
- What success looks like
- How the framework should be customized

## How to Complete Your PRD

### 1. Executive Summary (Required)
- **Vision**: One paragraph - what are you building?
- **Problem**: What specific pain are you solving?
- **Success Metrics**: How do you measure success? (must be quantifiable)
- **Target Audience**: Who uses this?

### 2. User Personas (Required)
Create 2-4 realistic personas:
- Background, goals, pain points
- Be specific! "Sarah, a mid-level backend engineer..." not "A developer"

### 3. Core Features (Required)
For each feature:
- User story: "As a [persona], I want [action], so that [benefit]"
- Acceptance criteria: Specific, testable conditions
- Priority: High/Medium/Low

### 4. Constitutional Customization (Required)
**CRITICAL**: Customize all 16 principles for your project:

1. **Library-First** - How does this apply to you?
2. **Test-First** - Your testing philosophy?
3. **Contract-First** - Your API standards?
4. **Idempotency** - Which operations need this?
5. **Progressive Enhancement** - Your feature flag strategy?
6. **Git Approval** - NO automatic git ops (keep as-is)
7. **Observability** - Your logging/monitoring approach?
8. **Documentation** - Your doc maintenance strategy?
9. **Dependency Management** - Your approval process?
10. **Agent Delegation** - Custom agents you'll need?
11. **Input Validation** - Your validation standards?
12. **Design System** - Your UI/UX principles?
13. **Access Control** - Your tier strategy?
14. **AI Model Selection** - Keep defaults or customize?

### 5. Release Strategy (Required)
- **MVP**: Minimum features to launch (be ruthless!)
- **Phase 2, 3, N**: Future feature groupings
- **Success Criteria**: How to measure each phase

## Using the PRD

### When Running /specify
The unified-specification skill will:
- Pull user stories from your PRD
- Reference personas for context
- Use acceptance criteria patterns
- Align with release phases

### When Running /plan
The sdd-planning skill will:
- Read constitutional customizations
- Apply technical constraints
- Use integration requirements
- Validate against PRD principles

### After PRD Approval
1. **Update Constitution**:
   ```bash
   # Edit .logic-loom/memory/constitution.md
   # Add project-specific guidance from PRD for each principle
   ```

2. **Create Custom Agents**:
   ```bash
   # For each agent identified in PRD Principle X
   /create-agent agent-name "Agent purpose"
   ```

3. **Begin Features**:
   ```bash
   # For each MVP feature
   /specification "Feature description"
   ```

## PRD Review Checklist

Before finalizing, verify:
- [ ] Vision is clear and compelling
- [ ] Success metrics are quantifiable
- [ ] All 16 constitutional principles customized
- [ ] MVP is truly minimal
- [ ] User personas are specific and realistic
- [ ] All features have acceptance criteria
- [ ] Technical constraints documented
- [ ] Open questions identified with owners
- [ ] Stakeholders approved

## Getting Help

Use the **prd-specialist agent** in Claude Code:
- Ask questions about any PRD section
- Get guidance on prioritization
- Validate completeness
- Review constitutional customizations

The PRD is your north star. Invest time here to save time later!
EOF

if [ "$JSON_MODE" = false ]; then
    echo -e "${GREEN}✓${NC} Quick reference created at: $QUICKREF"
    echo ""
fi

exit 0
