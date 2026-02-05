#!/bin/bash

# =============================================================================
# Template Sanitization Script
# Purpose: Remove project-specific artifacts to prepare branch for cloning
# Usage: bash .specify/scripts/bash/sanitize-for-template.sh
# =============================================================================

set -e

echo "============================================"
echo "  SDD Framework Template Sanitization"
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

if [ -d "specs/001-ds-star-multi" ]; then
  rm -rf specs/001-ds-star-multi
  echo -e "${GREEN}  ✅ Removed specs/001-ds-star-multi${NC}"
  ((ITEMS_REMOVED++))
fi

if [ -d "specs/002-skills-first-architecture" ]; then
  rm -rf specs/002-skills-first-architecture
  echo -e "${GREEN}  ✅ Removed specs/002-skills-first-architecture${NC}"
  ((ITEMS_REMOVED++))
fi

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

if [ -f ".docs/reports/migration-completion-report.md" ]; then
  rm -f .docs/reports/migration-completion-report.md
  echo -e "${GREEN}  ✅ Removed migration-completion-report.md${NC}"
  ((ITEMS_REMOVED++))
fi

if [ -f ".docs/reports/phase-3-4-completion-report.md" ]; then
  rm -f .docs/reports/phase-3-4-completion-report.md
  echo -e "${GREEN}  ✅ Removed phase-3-4-completion-report.md${NC}"
  ((ITEMS_REMOVED++))
fi

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
# SDD Agentic Framework v3.0.0

**Skills-First Architecture with Reinforcement Learning and DS-STAR Integration**

A constitutional AI framework for specification-driven development with intelligent skill-based routing, multi-agent orchestration, and continuous learning.

## Features

- **Skills-First Architecture**: Skills invoke agents (not vice versa)
- **Reinforcement Learning**: EMA-based skill selection with 26.9% improvement
- **Progressive Disclosure**: 50% token reduction through 3-layer loading
- **DS-STAR Integration**: 5 specialized agents (Router, Verifier, Auto-Debug, Finalizer, Context Analyzer)
- **Constitutional Governance**: 15 enforceable principles (v2.0.0)
- **13 Specialized Agents**: 8 domain + 5 DS-STAR
- **28 Active Skills**: Across 8 categories
- **Test-First Development**: >80% coverage requirement

## Quick Start

### Prerequisites

- Node.js >=18.0.0
- npm >=9.0.0
- Git

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
3. **Check AGENTS.md**: Complete agent registry and capabilities
4. **Explore Skills**: [.claude/skill-index.json](.claude/skill-index.json)

## Architecture

### Skills-First Workflow

```
User Message → FR-707 Compliance Check → Router Agent →
Skill Selection (RL) → Skill Activation (progressive) →
Agent Invocation (minimal context) → Verifier (DS-STAR) →
Auto-Debug (if needed) → Output + RL Feedback
```

### Core Principles

1. **Test-First Development** (Principle II): TDD mandatory, >80% coverage
2. **Git Operation Approval** (Principle VI): NO autonomous git operations
3. **Skills-First Delegation** (Principle X): Skills orchestrate agents

## Workflow Commands

### Feature Development

- `/create-prd` - Create Product Requirements Document
- `/initialize-project` - Customize framework based on PRD
- `/specify` - Create feature specification
- `/plan` - Generate implementation plan
- `/tasks` - Generate dependency-ordered task list
- `/finalize` - Pre-commit compliance validation

### Agent/Skill Management

- `/create-agent` - Create specialized subagent
- `/create-skill` - Create new skill

## Configuration

- **Architecture Mode**: `skills-first` (Phase 4)
- **Constitution**: v2.0.0 (ratified 2026-01-13)
- **RL Algorithm**: EMA (Exponential Moving Average)
- **Test Framework**: Jest

See [.specify/config/architecture.conf](.specify/config/architecture.conf) for complete configuration.

## Documentation

- **Constitution**: [.specify/memory/constitution.md](.specify/memory/constitution.md)
- **Framework Guide**: [CLAUDE.md](CLAUDE.md)
- **Agent Registry**: [AGENTS.md](AGENTS.md)
- **Skill Registry**: [.claude/skill-index.json](.claude/skill-index.json)
- **Policies**: `.docs/policies/` directory

## Performance Metrics

| Metric | Target | Achieved |
|--------|--------|----------|
| Token Efficiency | 40-50% ↓ | 50% ✅ |
| Agent Consolidation | 35% ↓ | 53% ✅ |
| RL Improvement | 15-25% ↑ | 26.9% ✅ |
| Test Coverage | >80% | 95.4% ✅ |

## Testing

```bash
# Run all tests
npm test

# Run specific test suites
npm run test:contracts
npm run test:integration
npm run test:validation
```

## Project Structure

```
.claude/
├── skill-index.json          # 28 skills with RL
├── agent-index.json          # 13 agents
├── skills/                   # 8 categories
└── agents/                   # consolidated/ + ds-star/

.specify/
├── memory/constitution.md    # v2.0.0 principles
├── scripts/bash/rl/          # RL infrastructure
├── config/                   # Architecture configuration
└── templates/                # Skill/agent templates

specs/                        # Feature specifications (created per project)
tests/                        # Contract, integration, validation tests
```

## License

MIT

## Version

**Framework**: v3.0.0
**Constitution**: v2.0.0 (ratified 2026-01-13)
**Architecture Mode**: skills-first (Phase 4)
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

This is a clean template of the SDD Agentic Framework v3.0.0. Follow these steps to initialize for a new project.

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

```bash
# Create feature specification
/specify

# Generate implementation plan
/plan

# Generate task list
/tasks

# ... implement tasks ...

# Pre-commit validation
/finalize
```

## What's Included

This template includes:

✅ **Framework v3.0.0**: Skills-first architecture
✅ **Constitution v2.0.0**: 15 enforceable principles
✅ **28 Active Skills**: Ready to use
✅ **13 Specialized Agents**: 8 domain + 5 DS-STAR
✅ **RL Infrastructure**: EMA algorithm with 50% token reduction
✅ **Test Framework**: Jest with >80% coverage requirement
✅ **Migration Tools**: Scripts and templates
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

- `.specify/config/architecture.conf` - Architecture mode, RL settings
- `.specify/memory/constitution.md` - Constitutional principles
- `package.json` - Project metadata (update name, version, description)
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

### Create Custom Skills/Agents

```bash
# Create project-specific skill
/create-skill

# Create project-specific agent
/create-agent
```

## Verification

After initialization, verify the setup:

```bash
# Run constitutional compliance check
bash .specify/scripts/bash/constitutional-check.sh

# Run tests
npm test

# Check configuration
cat .specify/config/architecture.conf
```

## Next Steps

1. **Create PRD**: Document your project vision
2. **Initialize Project**: Customize framework for your needs
3. **Create Features**: Use specification workflow
4. **Iterate**: Use skills-first routing for all development

## Support

- **Framework Guide**: [CLAUDE.md](CLAUDE.md)
- **Agent Registry**: [AGENTS.md](AGENTS.md)
- **Constitution**: [.specify/memory/constitution.md](.specify/memory/constitution.md)
- **Policies**: `.docs/policies/` directory

---

**This template is ready to use!** Start by creating your PRD with `/create-prd`.
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
