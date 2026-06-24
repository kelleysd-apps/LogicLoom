#!/bin/bash

# ⚠️ DEPRECATED: Use /initialize-project command in Claude Code instead.
# This script is from the pre-plugin era. Use: plugins/loom-maintenance/commands/initialize-project.md
# Removal target: v5.0

# Project Initialization Script for LogicLoom
# This script helps users quickly set up a new project based on this framework

set -e

# Source common functions for git approval
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.logic-loom/scripts/bash/common.sh" ]; then
    source "$SCRIPT_DIR/.logic-loom/scripts/bash/common.sh"
fi

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}   LogicLoom Project Setup${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Get project name from user
read -p "Enter your project name (kebab-case): " PROJECT_NAME
if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}Error: Project name cannot be empty${NC}"
    exit 1
fi

# Validate project name (kebab-case)
if ! [[ "$PROJECT_NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo -e "${RED}Error: Project name must be in kebab-case (lowercase letters, numbers, and hyphens)${NC}"
    exit 1
fi

read -p "Enter project description: " PROJECT_DESCRIPTION
read -p "Enter author name: " AUTHOR_NAME

echo ""
echo -e "${BLUE}Initializing project: ${PROJECT_NAME}${NC}"
echo ""

# Update package.json
echo -e "${BLUE}Updating package.json...${NC}"
if [ -f "package.json" ]; then
    # Create a backup
    cp package.json package.json.backup

    # Update using sed (cross-platform compatible)
    sed -i.tmp "s/\"name\": \".*\"/\"name\": \"$PROJECT_NAME\"/" package.json
    sed -i.tmp "s/\"description\": \".*\"/\"description\": \"$PROJECT_DESCRIPTION\"/" package.json
    if [ ! -z "$AUTHOR_NAME" ]; then
        sed -i.tmp "s/\"author\": \".*\"/\"author\": \"$AUTHOR_NAME\"/" package.json
    fi
    rm -f package.json.tmp
    echo -e "${GREEN}✓${NC} package.json updated"
else
    echo -e "${RED}Warning: package.json not found${NC}"
fi

# Archive framework README and create project README
echo -e "${BLUE}Setting up documentation...${NC}"
if [ -f "README.md" ] && [ ! -f "FRAMEWORK_README.md" ]; then
    mv README.md FRAMEWORK_README.md
    echo -e "${GREEN}✓${NC} Framework documentation moved to FRAMEWORK_README.md"
fi

# Create new project README
cat > README.md << EOF
# $PROJECT_NAME

$PROJECT_DESCRIPTION

## 🚀 Getting Started

This project is built using **LogicLoom** — a governed Claude Code harness with a
constitutional governance core and interchangeable workflow packs. For framework
documentation, see \`FRAMEWORK_README.md\`.

### Prerequisites

- Node.js v18+
- npm v9+
- Claude Code access

### Installation

\`\`\`bash
npm install
\`\`\`

### Development Workflow

Pick a workflow pack (none is privileged):

- **Swarm** (exploratory): \`/swarm explore\` → \`/create-prd\` → plan mode →
  \`/plan-review\` → \`/swarm implement\` → \`/review-team\` → \`/git-push\`
- **SDD waterfall** (well-specified): \`/specification\` → \`/build-team\` → \`/finalize\`

Governance (no autonomous git, test-first, etc.) is enforced by hooks. See
\`FRAMEWORK_README.md\` and \`START_HERE.md\`.

## 📚 Documentation

- **Framework Guide**: See \`FRAMEWORK_README.md\` and \`CLAUDE.md\`
- **Getting Started**: See \`START_HERE.md\`
- **Constitution**: See \`.logic-loom/memory/constitution.md\`

## 🤖 Common Commands

Execute these in Claude Code:

- \`/swarm explore "<topic>"\` - parallel read-only investigation
- \`/create-prd "<feature>"\` - product requirements with forcing-questions gate
- \`/plan-review\` - gate a plan before implementation
- \`/swarm implement [sprint]\` - scope-bounded implementation workers
- \`/review-team\` - parallel security + quality + performance + behavioral review
- \`/git-push\` - commit + PR (requires your approval)

## 📁 Project Structure

\`\`\`
$PROJECT_NAME/
├── .logic-loom/      # Framework core (constitution, scripts, config, templates)
├── .claude/          # Claude Code config + governance hooks
├── .docs/            # Documentation
├── features/         # Swarm pack — per-feature folders
├── specs/            # SDD waterfall pack — per-feature folders
└── src/              # Your source code
\`\`\`

## 🤝 Contributing

Follow the constitutional principles in \`.logic-loom/memory/constitution.md\`.

## 📝 License

[Your License Here]

---

Built with [LogicLoom](https://github.com/kelleysd-apps/LogicLoom)
EOF

echo -e "${GREEN}✓${NC} Project README created"

# Initialize git if not already initialized
if [ ! -d ".git" ]; then
    echo -e "${BLUE}Initializing git repository...${NC}"
    echo ""

    # Constitutional Principle VI: Request approval for git operations
    if type request_git_approval &> /dev/null; then
        if ! request_git_approval "Git Initialization" "Initialize git repo with initial commit for $PROJECT_NAME"; then
            echo -e "${YELLOW}Git initialization skipped by user${NC}"
            echo -e "${YELLOW}You can initialize git manually later with: git init${NC}"
        else
            git init
            git add .
            git commit -m "Initial commit: $PROJECT_NAME setup with LogicLoom"
            echo -e "${GREEN}✓${NC} Git repository initialized"
        fi
    else
        # Fallback if common.sh not available
        read -p "Initialize git repository? (y/n): " INIT_GIT
        if [[ "$INIT_GIT" =~ ^[Yy]$ ]]; then
            git init
            git add .
            git commit -m "Initial commit: $PROJECT_NAME setup with LogicLoom"
            echo -e "${GREEN}✓${NC} Git repository initialized"
        else
            echo -e "${YELLOW}Git initialization skipped${NC}"
        fi
    fi
else
    echo -e "${YELLOW}ℹ${NC}  Git repository already exists"
fi

# Framework updates: /update-framework fetches the configured upstream
# (.logic-loom/config/framework-upstream.conf) AD-HOC and FETCH-ONLY into a
# namespaced ref. It deliberately does NOT add an `upstream` git remote — so a
# stray `git push upstream` is structurally impossible and your commits can only
# go to `origin`. Nothing to configure here.
echo -e "${GREEN}✓${NC} Framework updates: run /update-framework (fetch-only; upstream in .logic-loom/config/framework-upstream.conf)"

# ====================================
# Docker MCP Toolkit Installation
# ====================================
echo ""
echo -e "${BLUE}Checking Docker MCP Toolkit...${NC}"

# Check if Docker is available first
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}ℹ${NC}  Docker not detected - skipping MCP Toolkit installation"
    echo -e "${YELLOW}   Docker MCP Toolkit requires Docker to be installed${NC}"
else
    # Check if docker-mcp plugin is already installed
    if docker mcp version &>/dev/null 2>&1; then
        MCP_VERSION=$(docker mcp version 2>/dev/null)
        echo -e "${GREEN}✓${NC} Docker MCP Toolkit already installed: ${MCP_VERSION}"
    else
        echo -e "${BLUE}Installing Docker MCP Toolkit CLI...${NC}"

        # Detect architecture
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) ARCH="amd64" ;;
            aarch64|arm64) ARCH="arm64" ;;
            *)
                echo -e "${YELLOW}⚠${NC}  Unsupported architecture: $ARCH"
                echo -e "${YELLOW}   Docker MCP Toolkit installation skipped${NC}"
                ARCH=""
                ;;
        esac

        if [ -n "$ARCH" ]; then
            # Detect OS
            MCP_OS=$(uname -s | tr '[:upper:]' '[:lower:]')

            # Download and install
            MCP_RELEASE_VERSION="v0.30.0"
            DOWNLOAD_URL="https://github.com/docker/mcp-gateway/releases/download/${MCP_RELEASE_VERSION}/docker-mcp-${MCP_OS}-${ARCH}.tar.gz"

            mkdir -p "$HOME/.docker/cli-plugins/"

            if curl -sL "$DOWNLOAD_URL" | tar -xz -C "$HOME/.docker/cli-plugins/" 2>/dev/null; then
                chmod +x "$HOME/.docker/cli-plugins/docker-mcp"

                if docker mcp version &>/dev/null 2>&1; then
                    echo -e "${GREEN}✓${NC} Docker MCP Toolkit installed: $(docker mcp version)"
                else
                    echo -e "${YELLOW}⚠${NC}  Docker MCP Toolkit installation may have failed"
                fi
            else
                echo -e "${YELLOW}⚠${NC}  Could not download Docker MCP Toolkit"
                echo -e "${YELLOW}   You can install manually later${NC}"
            fi
        fi
    fi

    # Configure Claude Code connection if MCP Toolkit is available
    if docker mcp version &>/dev/null 2>&1; then
        echo -e "${BLUE}Configuring Claude Code MCP gateway connection...${NC}"
        docker mcp client connect claude-code --global 2>/dev/null || true
        echo -e "${GREEN}✓${NC} Claude Code MCP gateway configured"
        echo ""
        echo -e "${BLUE}Docker MCP Toolkit provides:${NC}"
        echo -e "  • ${GREEN}mcp-find${NC}    - Search 310+ MCP servers in Docker catalog"
        echo -e "  • ${GREEN}mcp-add${NC}     - Add MCP servers dynamically during conversations"
        echo -e "  • ${GREEN}mcp-exec${NC}    - Execute tools from any enabled server"
        echo -e "  • ${GREEN}code-mode${NC}   - Combine multiple MCP tools in JavaScript"
    fi
fi

# Run the main setup script
echo ""
echo -e "${BLUE}Running framework setup...${NC}"
if [ -f ".logic-loom/scripts/setup.sh" ]; then
    chmod +x .logic-loom/scripts/setup.sh
    ./.logic-loom/scripts/setup.sh
else
    echo -e "${RED}Warning: Setup script not found${NC}"
fi

# PRD-First Workflow Guidance
echo ""
echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}   Recommended: PRD-First Workflow${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""
echo -e "${GREEN}For best results, follow this initialization sequence:${NC}"
echo ""
echo -e "${YELLOW}1. Create Product Requirements Document (PRD)${NC}"
echo -e "   Use: ${GREEN}/create-prd${NC} in Claude Code"
echo -e "   → Defines product vision, goals, features, and success metrics"
echo -e "   → Serves as Single Source of Truth (SSOT) for your project"
echo ""
echo -e "${YELLOW}2. Initialize Project from PRD${NC}"
echo -e "   Use: ${GREEN}/initialize-project${NC} in Claude Code"
echo -e "   → Automatically customizes all 16 principles from your PRD"
echo -e "   → Creates custom agents identified in PRD (Principle X)"
echo -e "   → Recommends and configures MCP servers for your tech stack"
echo -e "   → Validates compliance and provides next steps"
echo ""
echo -e "${YELLOW}3. Configure MCP Servers (Docker MCP Toolkit)${NC}"
echo -e "   Docker MCP Toolkit is ${GREEN}pre-installed${NC} - use dynamic discovery:"
echo -e "   → Ask Claude: ${GREEN}\"Find MCP servers for databases\"${NC} (uses mcp-find)"
echo -e "   → Ask Claude: ${GREEN}\"Add the supabase MCP server\"${NC} (uses mcp-add)"
echo -e "   → Or browse: ${GREEN}docker mcp catalog show docker-mcp${NC}"
echo -e "   → 310+ servers available: database, cloud, testing, search, docs"
echo ""
echo -e "${YELLOW}4. Optional: Subscription Usage Tracking (Pro/Max)${NC}"
echo -e "   Install: ${GREEN}npm install -g ccstatusline${NC}"
echo -e "   → Adds session usage %, weekly usage %, block reset timer to status line"
echo -e "   → See: ${GREEN}https://github.com/sirmalloc/ccstatusline${NC}"
echo ""
echo -e "${YELLOW}5. Begin Feature Development${NC}"
echo -e "   Use: ${GREEN}/specification${NC} (unified spec+plan+tasks workflow)"
echo -e "   → All commands will reference PRD as SSOT"
echo -e "   → Features align with PRD goals and constraints"
echo ""
echo -e "${YELLOW}Alternative: Manual Initialization (Advanced)${NC}"
echo -e "   Edit: ${GREEN}.logic-loom/memory/constitution.md${NC} manually"
echo -e "   Use: ${GREEN}/create-agent${NC} for each agent identified in PRD"
echo ""
echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}   Why PRD-First?${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""
echo -e "✓ ${GREEN}Alignment${NC}: Stakeholders aligned on vision before code"
echo -e "✓ ${GREEN}Clarity${NC}: Clear success metrics and acceptance criteria"
echo -e "✓ ${GREEN}Customization${NC}: Framework tailored to YOUR needs"
echo -e "✓ ${GREEN}Efficiency${NC}: Less rework from unclear requirements"
echo -e "✓ ${GREEN}Quality${NC}: Better specs and plans downstream"
echo ""
echo -e "${YELLOW}Note:${NC} You can create the PRD anytime with ${GREEN}/create-prd${NC}"
echo -e "${YELLOW}      It's flexible - use it for projects, major features, or pivots${NC}"
echo ""

# Remove maintainer-only template-release CI. These workflows release + guard the
# LogicLoom template itself, not your project, and would only confuse your CI, so
# they are removed at initialization. (plugin-tests.yml is kept — it validates the
# harness you are using.)
echo ""
echo -e "${BLUE}Removing maintainer-only template-release CI...${NC}"
for wf in .github/workflows/promote-to-main.yml .github/workflows/release-tag.yml .github/workflows/leak-guard.yml; do
    if [ -f "$wf" ]; then
        rm -f "$wf"
        echo -e "${GREEN}✓${NC} Removed $wf (LogicLoom template-release CI, not for your project)"
    fi
done

# Cleanup process (with user approval)
echo ""
echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}   Cleanup Phase${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""
echo -e "${YELLOW}The following files are no longer needed after initialization:${NC}"
echo -e "  - init-project.sh (this script)"
echo -e "  - START_HERE.md (setup documentation)"
echo -e "  - FRAMEWORK_README.md (if you've created your own README)"
echo ""
read -p "Would you like to remove these initialization files? (y/n): " CLEANUP_CONFIRM

if [[ "$CLEANUP_CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Cleaning up initialization files...${NC}"

    # Remove the init script itself
    if [ -f "init-project.sh" ]; then
        rm -f init-project.sh
        echo -e "${GREEN}✓${NC} Removed init-project.sh"
    fi

    # Remove START_HERE.md
    if [ -f "START_HERE.md" ]; then
        rm -f START_HERE.md
        echo -e "${GREEN}✓${NC} Removed START_HERE.md"
    fi

    # Ask about FRAMEWORK_README.md separately
    if [ -f "FRAMEWORK_README.md" ]; then
        read -p "Remove FRAMEWORK_README.md? You may want to keep this for reference (y/n): " REMOVE_FRAMEWORK_README
        if [[ "$REMOVE_FRAMEWORK_README" =~ ^[Yy]$ ]]; then
            rm -f FRAMEWORK_README.md
            echo -e "${GREEN}✓${NC} Removed FRAMEWORK_README.md"
        else
            echo -e "${YELLOW}ℹ${NC}  Keeping FRAMEWORK_README.md for reference"
        fi
    fi

    echo -e "${GREEN}✓${NC} Cleanup complete"
else
    echo -e "${YELLOW}ℹ${NC}  Skipping cleanup - you can manually remove these files later"
fi

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}   Project Setup Complete! 🎉${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "Your project '${PROJECT_NAME}' is ready for development!"
echo ""

# Check if Claude Code is installed and provide guidance
if ! command -v claude &> /dev/null; then
    echo -e "${YELLOW}=====================================${NC}"
    echo -e "${YELLOW}   Claude Code Not Detected${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    echo ""
    echo -e "${BLUE}Claude Code is required to use the LogicLoom framework commands.${NC}"
    echo ""
    echo -e "${YELLOW}Install Claude Code using one of these methods:${NC}"
    echo ""
    echo -e "  ${GREEN}Option 1: npm (Recommended)${NC}"
    echo -e "    npm install -g @anthropic-ai/claude-code"
    echo ""
    echo -e "  ${GREEN}Option 2: Homebrew (macOS)${NC}"
    echo -e "    brew install claude-code"
    echo ""
    echo -e "  ${GREEN}Option 3: Direct Download${NC}"
    echo -e "    Visit: https://claude.ai/code"
    echo ""
    echo -e "${YELLOW}After installation:${NC}"
    echo -e "  1. Run: ${GREEN}claude login${NC}"
    echo -e "  2. Open project: ${GREEN}claude code .${NC}"
    echo -e "  3. Start with: ${GREEN}/create-prd${NC}"
    echo ""
fi

echo -e "${BLUE}Next steps:${NC}"
if command -v claude &> /dev/null; then
    echo -e "  1. Open in Claude Code: ${YELLOW}claude code .${NC}"
    echo -e "  2. Create PRD: ${YELLOW}/create-prd${NC}"
    echo -e "  3. Initialize project: ${YELLOW}/initialize-project${NC}"
    echo -e "  4. Start first feature: ${YELLOW}/specify${NC}"
else
    echo -e "  1. Install Claude Code (see instructions above)"
    echo -e "  2. Run: ${YELLOW}claude login${NC}"
    echo -e "  3. Open project: ${YELLOW}claude code .${NC}"
    echo -e "  4. Create PRD: ${YELLOW}/create-prd${NC}"
    echo -e "  5. Initialize project: ${YELLOW}/initialize-project${NC}"
fi
echo ""
echo -e "${YELLOW}Remember:${NC} The constitution is your guide!"
echo ""