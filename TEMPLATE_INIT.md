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
