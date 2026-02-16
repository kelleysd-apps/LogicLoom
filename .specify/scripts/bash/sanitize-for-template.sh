#!/bin/bash

# =============================================================================
# Template Sanitization Script (v5.0)
# Purpose: Remove project-specific artifacts to prepare branch for cloning
# Usage: bash .specify/scripts/bash/sanitize-for-template.sh
# =============================================================================

set -e

echo "============================================"
echo "  SDD Framework Template Sanitization v5.0"
echo "============================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ITEMS_REMOVED=0

# -----------------------------------------------------------------------------
# Remove Feature Specifications (Project-Specific)
# -----------------------------------------------------------------------------

echo -e "${BLUE}[1/8] Removing feature specification directories...${NC}"

# Remove all implementation feature specs (001-006)
for spec_dir in specs/001-* specs/002-* specs/003-* specs/004-* specs/005-* specs/006-*; do
  if [ -d "$spec_dir" ]; then
    rm -rf "$spec_dir"
    echo -e "${GREEN}  ✅ Removed $spec_dir${NC}"
    ((ITEMS_REMOVED++))
  fi
done

# Keep specs/ directory structure but add .gitkeep
mkdir -p specs
if [ ! -f "specs/.gitkeep" ]; then
  echo "# Feature specifications will be created here during development" > specs/.gitkeep
  echo -e "${GREEN}  ✅ Created specs/.gitkeep${NC}"
fi

# -----------------------------------------------------------------------------
# Remove Implementation Reports (Project-Specific)
# -----------------------------------------------------------------------------

echo -e "${BLUE}[2/8] Removing implementation reports...${NC}"

# Remove all project-specific reports
for report in .docs/reports/*-report.md .docs/reports/*-completion-*.md; do
  if [ -f "$report" ] && [ "$report" != ".docs/reports/.gitkeep" ]; then
    rm -f "$report"
    echo -e "${GREEN}  ✅ Removed $(basename "$report")${NC}"
    ((ITEMS_REMOVED++))
  fi
done

# Keep .docs/reports/ directory but add .gitkeep
if [ ! -f ".docs/reports/.gitkeep" ]; then
  echo "# Implementation reports will be generated here" > .docs/reports/.gitkeep
  echo -e "${GREEN}  ✅ Created .docs/reports/.gitkeep${NC}"
fi

# -----------------------------------------------------------------------------
# Clean Test Artifacts
# -----------------------------------------------------------------------------

echo -e "${BLUE}[3/8] Cleaning test artifacts...${NC}"

# Remove node_modules if present (should be in .gitignore but check anyway)
if [ -d "node_modules" ]; then
  rm -rf node_modules
  echo -e "${GREEN}  ✅ Removed node_modules${NC}"
  ((ITEMS_REMOVED++))
fi

# Remove coverage directory
if [ -d "coverage" ]; then
  rm -rf coverage
  echo -e "${GREEN}  ✅ Removed coverage directory${NC}"
  ((ITEMS_REMOVED++))
fi

# Remove jest cache
if [ -d ".jest" ]; then
  rm -rf .jest
  echo -e "${GREEN}  ✅ Removed .jest cache${NC}"
  ((ITEMS_REMOVED++))
fi

# -----------------------------------------------------------------------------
# Reset RL Metrics to Baseline
# -----------------------------------------------------------------------------

echo -e "${BLUE}[4/8] Resetting RL metrics to baseline...${NC}"

if [ -f ".docs/rl-metrics/skill-performance.json" ]; then
  cat > .docs/rl-metrics/skill-performance.json <<'EOF'
{
  "version": "1.0.0",
  "last_updated": "2026-01-13T00:00:00Z",
  "skills": {},
  "statistics": {
    "total_invocations": 0,
    "avg_success_rate": 0.0,
    "avg_token_efficiency": 0.0,
    "avg_user_satisfaction": 0.0
  }
}
EOF
  echo -e "${GREEN}  ✅ Reset skill-performance.json to baseline${NC}"
  ((ITEMS_REMOVED++))
fi

# -----------------------------------------------------------------------------
# Clean Audit Logs
# -----------------------------------------------------------------------------

echo -e "${BLUE}[5/8] Cleaning audit logs...${NC}"

mkdir -p .docs/audit

# Create placeholder files
if [ ! -f ".docs/audit/.gitkeep" ]; then
  echo "# Audit logs will be generated here" > .docs/audit/.gitkeep
  echo -e "${GREEN}  ✅ Created .docs/audit/.gitkeep${NC}"
fi

# Remove any existing audit logs
rm -f .docs/audit/rl-weight-updates.log 2>/dev/null || true
rm -f .docs/audit/message-preflight.log 2>/dev/null || true

# -----------------------------------------------------------------------------
# Remove Temporary Files
# -----------------------------------------------------------------------------

echo -e "${BLUE}[6/8] Removing temporary files...${NC}"

# Remove patch files
if [ -f "framework-v3.1.0-enhancements.patch" ]; then
  rm -f framework-v3.1.0-enhancements.patch
  echo -e "${GREEN}  ✅ Removed framework-v3.1.0-enhancements.patch${NC}"
  ((ITEMS_REMOVED++))
fi

if [ -f "framework-v3.1.0-enhancements-APPLY.md" ]; then
  rm -f framework-v3.1.0-enhancements-APPLY.md
  echo -e "${GREEN}  ✅ Removed framework-v3.1.0-enhancements-APPLY.md${NC}"
  ((ITEMS_REMOVED++))
fi

# Remove any .DS_Store files (Mac)
find . -name ".DS_Store" -type f -delete 2>/dev/null || true

# Remove any thumbs.db files (Windows)
find . -name "Thumbs.db" -type f -delete 2>/dev/null || true

# -----------------------------------------------------------------------------
# Update README for Template
# -----------------------------------------------------------------------------

echo -e "${BLUE}[7/8] Updating README for template usage...${NC}"

if [ -f "README.md" ]; then
  # Backup current README
  cp README.md README.md.backup

  cat > README.md <<'EOF'
# SDD Agentic Framework v4.1.1

**Plugin-First Architecture with Constitutional Governance and Multi-Agent Orchestration**

A constitutional AI framework for specification-driven development with plugin-based capabilities, skill-based delegation, and continuous learning.

## Features

- **Plugin-First Architecture v4.1**: All capabilities as installable plugins (18 plugins)
- **Constitutional Governance v3.0.0**: 16 enforceable principles with hook-based preflight checks
- **Skill-Based Delegation v5.0**: Skills defined in plugin manifests with agent recommendations
- **Multi-Agent Orchestration**: 11 specialized agents across 18 plugins
- **RL Feedback System**: EMA-based skill selection with performance tracking
- **Test-First Development**: >80% coverage requirement (1,322 tests across 27 suites)
- **Docker MCP Toolkit**: Access to 310+ containerized MCP servers
- **Unified Workflows**: `/specification` for spec+plan+tasks, `/git-push` for complete git workflow

## Quick Start

### Prerequisites

- Node.js >=18.0.0
- npm >=9.0.0
- Git
- Docker (for MCP servers)

### Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd sdd-agentic-framework

# Install dependencies
npm install

# Run tests
npm test
```

### First Steps

1. **Read the Constitution**: [.specify/memory/constitution.md](.specify/memory/constitution.md)
2. **Review CLAUDE.md**: Framework guidance for Claude Code
3. **Explore Plugins**: Check `plugins/` directory for available capabilities
4. **Check Agent Registry**: [.docs/agents/agent-registry.json](.docs/agents/agent-registry.json)

## Architecture

### Plugin-First Workflow

```
User Message → Constitutional Preflight Check → Domain Detection →
Agent Recommendation (Principle X) → Plugin Skill Execution →
Verifier Validation → RL Feedback → Output
```

### Core Principles (v3.0.0)

1. **Library-First** (Principle I): Prefer existing solutions
2. **Test-First Development** (Principle II): TDD mandatory, >80% coverage
3. **Contract-First Design** (Principle III): API contracts before implementation
4. **Git Operation Approval** (Principle VI): NO autonomous git operations
5. **Agent Delegation** (Principle X): Specialized work → specialists
6. **Plugin-First** (Principle XVI): All features as installable plugins

## Slash Commands

### Core Workflows

- **`/specification`** - Unified SDD workflow (spec, plan, tasks in one command)
- **`/git-push`** - Complete git workflow (commit, push, PR)
- `/create-prd` - Create Product Requirements Document
- `/create-agent` - Create specialized subagent
- `/create-plugin` - Create new SDD plugin
- `/debug` - Debug deployment/runtime issues
- `/finalize` - Pre-commit compliance validation

### Orchestration

- `/research` - Multi-LLM tribunal research (Claude, OpenAI, Gemini)
- `/swarm` - Multi-agent swarm execution
- `/build-team` - Sequential architect→implementor→reviewer
- `/fullstack-team` - Parallel full-stack team
- `/review-team` - Parallel security+quality+performance review

### Maintenance

- `/update-framework` - Check and apply upstream enhancements
- `/initialize-project` - Post-PRD project customization

## Configuration

- **Architecture**: Plugin-First (v4.1) with Command Bridge
- **Constitution**: v3.0.0 (16 principles)
- **Framework Version**: v4.1.1
- **RL Algorithm**: EMA (Exponential Moving Average)
- **Test Framework**: Jest

See [.specify/config/architecture.conf](.specify/config/architecture.conf) for complete configuration.

## Documentation

- **Constitution**: [.specify/memory/constitution.md](.specify/memory/constitution.md)
- **Framework Guide**: [CLAUDE.md](CLAUDE.md)
- **Agent Registry**: [.docs/agents/agent-registry.json](.docs/agents/agent-registry.json)
- **Plugin Registry**: Check `plugins/*/plugin.json` manifests
- **Policies**: `.docs/policies/` directory

## Testing

```bash
# Run all tests (27 suites, 1,322 tests)
npm test

# Run specific test suites
npm run test:contracts
npm run test:integration
npm run test:validation
```

## Project Structure

```
plugins/                      # 18 plugins with manifests
├── sdd-governance/          # Protected - constitutional enforcement
├── sdd-specification/       # /specification, /plan, /tasks
├── sdd-orchestrator/        # /swarm, /research, team commands
├── sdd-orchestrator-hook/   # Domain detection + preflight hooks
├── sdd-memory/              # Automatic memory context injection
├── sdd-creation/            # /create-agent, /create-plugin, /create-prd
├── sdd-git/                 # /git-push, /finalize
├── sdd-debug/               # /debug
├── sdd-maintenance/         # /update-framework, /initialize-project
└── sdd-domain-*/            # 7 domain specialist plugins

.claude/
├── commands/                # Slash commands (bridged from plugins)
├── context/                 # Modular context loading (5 modules)
└── hooks/                   # Constitutional preflight hooks

.specify/
├── memory/constitution.md   # v3.0.0 - 16 principles
├── scripts/bash/            # Workflow automation + plugin bridge
├── config/                  # Architecture configuration
└── templates/               # Document templates

.docs/
├── agents/agent-registry.json  # 11 agents
├── rl-metrics/              # RL performance tracking
├── policies/                # Framework policies
└── reports/                 # Implementation documentation

specs/                       # Feature specifications (created per project)
tests/                       # 27 test suites, 1,322 tests
```

## License

MIT

## Version

**Framework**: v4.1.1
**Constitution**: v3.0.0
**Architecture**: Plugin-First (v4.1) + Skill-Based Delegation (v5.0)
**Agents**: 11 agents across 18 plugins
**Commands**: 19 slash commands
**Tests**: 27 suites, 1,322 tests
EOF

  echo -e "${GREEN}  ✅ Updated README.md for template${NC}"
  echo -e "${YELLOW}  ⚠  Backup saved as README.md.backup${NC}"
  ((ITEMS_REMOVED++))
fi

# -----------------------------------------------------------------------------
# Create Template Initialization Guide
# -----------------------------------------------------------------------------

echo -e "${BLUE}[8/8] Creating template initialization guide...${NC}"

cat > TEMPLATE_INIT.md <<'EOF'
# Template Initialization Guide

This is a clean template of the SDD Agentic Framework v4.1.1 with Plugin-First Architecture. Follow these steps to initialize for a new project.

## Initialization Steps

### 1. Clone and Setup

```bash
# Clone this template
git clone <template-url> <your-project-name>
cd <your-project-name>

# Remove template remote (optional)
git remote remove origin

# Add your project remote
git remote add origin <your-project-url>

# Install dependencies
npm install
```

### 2. Create Product Requirements Document (PRD)

Use the `/create-prd` command to create your project's PRD:

```bash
# This creates .docs/prd/prd.md
/create-prd
```

The PRD serves as the Single Source of Truth (SSOT) for:
- Project vision and goals
- Target users and use cases
- Core features and requirements
- Technical constraints
- Success criteria

### 3. Initialize Project Configuration

After creating the PRD, customize the framework:

```bash
# This customizes constitution, agents, and MCP servers based on PRD
/initialize-project
```

This will:
- Review and customize constitutional principles
- Create project-specific agents (if needed)
- Configure MCP servers for your tech stack
- Set up project-specific workflows

### 4. Create Your First Feature

Use the unified `/specification` workflow (replaces separate /specify, /plan, /tasks):

```bash
# Create spec, plan, and tasks in one command
/specification

# ... implement tasks ...

# Complete git workflow (commit, push, PR)
/git-push
```

## What's Included

This template includes:

✅ **Framework v4.1.1**: Plugin-First Architecture with Command Bridge
✅ **Constitution v3.0.0**: 16 enforceable principles
✅ **18 Plugins**: Complete plugin ecosystem (sdd-governance, sdd-specification, sdd-orchestrator, etc.)
✅ **11 Specialized Agents**: Across 18 plugins
✅ **19 Slash Commands**: Bridged from plugin manifests
✅ **RL Infrastructure**: EMA algorithm with performance tracking
✅ **Test Framework**: Jest with >80% coverage requirement (27 suites, 1,322 tests)
✅ **Docker MCP Toolkit**: Access to 310+ containerized MCP servers
✅ **Documentation**: Complete framework guides

## What's NOT Included (Project-Specific)

The following will be created during your project:

❌ Feature specifications (specs/###-feature/)
❌ Implementation reports (.docs/reports/)
❌ RL performance metrics (will accumulate)
❌ Audit logs (will be generated)
❌ Project-specific README content

## Configuration Files

Key configuration files to review:

- `.specify/config/architecture.conf` - Architecture configuration
- `.specify/memory/constitution.md` - Constitutional principles (v3.0.0)
- `package.json` - Project metadata (update name, version, description)
- `plugins/*/plugin.json` - Plugin manifests with skill definitions
- `.gitignore` - Already configured

## Customization

### Update Package Metadata

Edit `package.json`:

```json
{
  "name": "your-project-name",
  "version": "0.1.0",
  "description": "Your project description",
  "keywords": ["your", "keywords"]
}
```

### Review Constitutional Principles

The constitution can be customized for your project needs:

```bash
# Review current constitution
cat .specify/memory/constitution.md

# Follow update checklist if modifying
cat .specify/memory/constitution_update_checklist.md
```

### Create Custom Plugins/Agents

```bash
# Create project-specific plugin
/create-plugin

# Create project-specific agent
/create-agent
```

## Verification

After initialization, verify the setup:

```bash
# Run constitutional compliance check
bash .specify/scripts/bash/constitutional-check.sh

# Run all tests (27 suites, 1,322 tests)
npm test

# Check plugin command bridge
bash .specify/scripts/bash/sync-plugin-commands.sh list

# View agent registry
cat .docs/agents/agent-registry.json
```

## Plugin Architecture

The framework uses **Plugin-First Architecture v4.1** where all capabilities are organized as discrete plugins:

### Core Plugins

- `sdd-governance` - Constitutional enforcement
- `sdd-specification` - `/specification`, `/plan`, `/tasks`
- `sdd-orchestrator` - `/swarm`, `/research`, team commands
- `sdd-orchestrator-hook` - Domain detection + preflight hooks
- `sdd-memory` - Automatic memory context injection
- `sdd-creation` - `/create-agent`, `/create-plugin`, `/create-prd`
- `sdd-git` - `/git-push`, `/finalize`
- `sdd-debug` - `/debug`
- `sdd-maintenance` - `/update-framework`, `/initialize-project`

### Domain Specialist Plugins

- `sdd-domain-frontend` - UI/React/CSS specialist
- `sdd-domain-backend` - API/server specialist
- `sdd-domain-database` - Schema/query specialist
- `sdd-domain-testing` - TDD/QA specialist
- `sdd-domain-security` - Security/auth specialist
- `sdd-domain-performance` - Optimization specialist
- `sdd-domain-devops` - CI/CD/deployment specialist

### Command Bridge

Commands are automatically synced from plugin manifests to `.claude/commands/`:

```bash
# Sync plugin commands (runs automatically on setup)
.specify/scripts/bash/sync-plugin-commands.sh sync

# View command→plugin mapping
.specify/scripts/bash/sync-plugin-commands.sh list
```

## Next Steps

1. **Create PRD**: Document your project vision with `/create-prd`
2. **Initialize Project**: Customize framework with `/initialize-project`
3. **Create Features**: Use `/specification` workflow
4. **Iterate**: Use plugin-based delegation for all development

## Key Workflows

### Unified Specification Workflow

```bash
# Single command for spec, plan, and tasks
/specification
```

### Complete Git Workflow

```bash
# Commit, push, and create PR
/git-push
```

### Multi-LLM Research

```bash
# Research with Claude, OpenAI, and Gemini
/research
```

### Multi-Agent Orchestration

```bash
# Swarm execution
/swarm

# Sequential team
/build-team

# Parallel teams
/fullstack-team
/review-team
```

## Support

- **Framework Guide**: [CLAUDE.md](CLAUDE.md)
- **Agent Registry**: [.docs/agents/agent-registry.json](.docs/agents/agent-registry.json)
- **Constitution**: [.specify/memory/constitution.md](.specify/memory/constitution.md)
- **Plugin Manifests**: `plugins/*/plugin.json`
- **Policies**: `.docs/policies/` directory

## Directory Structure

```
plugins/                      # 18 plugins with manifests
.claude/
├── commands/                # 19 slash commands (bridged from plugins)
├── context/                 # Modular context loading (5 modules)
└── hooks/                   # Constitutional preflight hooks
.specify/
├── memory/constitution.md   # v3.0.0 - 16 principles
├── scripts/bash/            # Workflow automation + plugin bridge
├── config/                  # Architecture configuration
└── templates/               # Document templates
.docs/
├── agents/agent-registry.json  # 11 agents
├── rl-metrics/              # RL performance tracking
├── policies/                # Framework policies
└── reports/                 # Implementation documentation
specs/                       # Feature specifications (created per project)
tests/                       # 27 test suites, 1,322 tests
```

---

**This template is ready to use!** Start by creating your PRD with `/create-prd`.

**Framework**: v4.1.1 | **Constitution**: v3.0.0 | **Architecture**: Plugin-First (v4.1) + Skill-Based Delegation (v5.0)
EOF

echo -e "${GREEN}  ✅ Created TEMPLATE_INIT.md${NC}"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

echo ""
echo "============================================"
echo "  Sanitization Complete"
echo "============================================"
echo ""
echo -e "${GREEN}✅ Items Removed/Reset: ${ITEMS_REMOVED}${NC}"
echo ""
echo "Template is ready for cloning!"
echo ""
echo "Key files created:"
echo "  • specs/.gitkeep"
echo "  • .docs/reports/.gitkeep"
echo "  • .docs/audit/.gitkeep"
echo "  • README.md (template version)"
echo "  • TEMPLATE_INIT.md (initialization guide)"
echo ""
echo "Next steps:"
echo "  1. Review README.md"
echo "  2. Review TEMPLATE_INIT.md"
echo "  3. Run: npm test"
echo "  4. Commit sanitized template"
echo ""
