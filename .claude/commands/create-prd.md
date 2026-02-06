# /create-prd - Create Product Requirements Document

> ⚠️ **DEPRECATED**: This command has moved to `plugins/sdd-creation/commands/create-prd.md`.
> The plugin version is the canonical source. This monolithic version will be removed in v5.0.
> 
> **Plugin-First Architecture (Principle XVI)**: All commands now live within their respective plugins.


Creates a comprehensive Product Requirements Document (PRD) that can serve as **Single Source of Truth (SSOT)** for various purposes throughout your development lifecycle.

## Purpose

A PRD provides structured requirements documentation for:
- **Project initialization** - Establish product vision, goals, and strategy
- **Major features** - Document complex feature requirements before development
- **Product pivots** - Re-define product direction and priorities
- **Stakeholder alignment** - Create shared understanding of goals and scope
- **Constitutional customization** - Define project-specific framework rules
- **Compliance documentation** - Meet regulatory or business documentation requirements
- **Any purpose requiring structured requirements** - Flexible tool for any planning need

## When to Use

**Use this command whenever you need structured requirements documentation**:

### At Project Start (Recommended First Step)
- **Primary Use**: Initialize new projects with complete product foundation
- **Result**: SSOT that guides constitution customization, agent creation, and all feature work
- **Workflow**: Create PRD → Customize constitution → Create agents → Begin features

### During Development (Anytime)
- **Major Features**: Document complex features before /specify
- **New Modules**: Define requirements for significant new capabilities
- **Product Changes**: Document pivots, re-scoping, or strategic shifts
- **Team Onboarding**: Create shared understanding for new team members
- **Stakeholder Communication**: Formalize requirements and decisions

### For Specific Needs
- **Compliance**: Create documentation for audits or regulatory requirements
- **Fundraising**: Document product vision and roadmap for investors
- **Planning**: Think through product strategy before committing to implementation
- **Retrospectives**: Document lessons learned and future direction

## Flexibility

**PRDs are flexible documents - use what you need**:
- Can be project-wide or feature-specific
- Can cover entire product or single module
- Can be detailed or high-level based on need
- Can be created at any time, not just at project start
- Multiple PRDs can exist (e.g., project PRD + major feature PRDs)

**Typical workflow for project initialization**:
```
1. /create-prd "MyProject"     ← Create project-wide PRD (SSOT)
2. Complete PRD with prd-specialist agent
3. Use PRD to customize .specify/memory/constitution.md
4. Create custom agents identified in PRD
5. /specify                     ← Create feature specs (reference PRD)
6. /plan                        ← Implementation planning (reference PRD)
7. /tasks → Implementation
```

## Usage

### Basic Usage
```
/create-prd
```

Interactive mode - will prompt for project name

### With Project Name
```
/create-prd MyAwesomeProject
```

Creates PRD with project name pre-filled

## What It Does

1. **Creates PRD Structure**
   - Copies template from `.specify/templates/prd-template.md`
   - Places PRD at `.docs/prd/prd.md`
   - Fills in project name and creation date
   - Creates quick reference guide

2. **Initializes Sections**
   - Executive Summary (vision, problem, metrics)
   - User Personas & Journeys
   - Core Features & Requirements
   - System Architecture Principles (14 constitutional principles)
   - Technical Constraints
   - Release Strategy (MVP, phases)
   - Open Questions & Risks
   - PRD Review Checklist

3. **Provides Guidance**
   - Quick reference card for PRD completion
   - Next steps workflow
   - Integration points with `/specify` and `/plan`
   - Constitutional customization guide

## PRD Workflow Integration

### How specification-agent Uses PRD

When you run `/specify` for a feature, the specification-agent:
- References PRD personas for user story context
- Pulls acceptance criteria patterns from PRD features
- Uses PRD success metrics for validation
- Aligns feature scope with PRD release phases

### How planning-agent Uses PRD

When you run `/plan` for a feature, the planning-agent:
- Reads constitutional customizations from PRD
- References technical constraints for architecture decisions
- Uses integration requirements from PRD
- Applies performance/security requirements from PRD
- Validates against PRD principles throughout planning

### Constitution Customization

After PRD approval:
1. Open `.specify/memory/constitution.md`
2. For each of 14 principles, add project-specific guidance from PRD
3. Document exceptions from PRD
4. Add PRD quality thresholds to relevant principles
5. Reference PRD as authoritative source

## Key PRD Sections

### Must Complete (Required)

1. **Executive Summary**
   - Vision statement (one paragraph)
   - Problem statement (specific pain points)
   - Success metrics (quantifiable!)
   - Target audience

2. **User Personas**
   - At least 1 primary, 1 secondary persona
   - Background, goals, pain points, behaviors
   - Be specific! Not "a developer" but "Sarah, mid-level backend engineer at Series B startup..."

3. **Core Features**
   - User stories: "As a [persona], I want [action], so that [benefit]"
   - Acceptance criteria (testable!)
   - Priority (High/Medium/Low)
   - Dependencies

4. **Constitutional Customization** (CRITICAL!)
   - All 14 principles must be addressed
   - Project-specific guidance for each
   - Document any necessary exceptions with justification
   - Define project-specific quality thresholds

5. **Release Strategy**
   - MVP features (be ruthless! What's TRULY minimal?)
   - Phase 2, 3, N groupings
   - Success criteria for each phase

### Optional (Include if Relevant)

- User Journey Maps (for complex workflows)
- Data & Analytics (for data-heavy products)
- Design Principles & UX Guidelines (for design-centric products)
- Additional personas beyond primary/secondary

## Constitutional Principles to Customize

**All 14 principles must be addressed**:

### Immutable Principles (Customize application, not the principle itself)
1. **Library-First Architecture** - How does this apply to your project?
2. **Test-First Development (TDD)** - Your testing philosophy?
3. **Contract-First Design** - Your API standards (OpenAPI, GraphQL, etc.)?

### Quality & Safety Principles
4. **Idempotent Operations** - Which operations need idempotency?
5. **Progressive Enhancement** - Your feature flag strategy?
6. **Git Operation Approval** - Keep as-is (NO automatic git ops)
7. **Observability & Structured Logging** - Your logging/monitoring approach?
8. **Documentation Synchronization** - Your doc maintenance strategy?
9. **Dependency Management** - Your approval process for dependencies?

### Workflow & Delegation Principles
10. **Agent Delegation Protocol** - Custom agents you'll need for this project?
11. **Input Validation & Output Sanitization** - Your validation standards?
12. **Design System Compliance** - Your UI/UX principles? Existing design system?
13. **Feature Access Control** - Your tier strategy (free/premium/enterprise)?
14. **AI Model Selection Protocol** - Keep defaults or customize when to use each model?

## Using prd-specialist Agent

The PRD creation invokes the **prd-specialist agent** automatically. This agent:

**Helps you with**:
- Asking clarifying questions about vision and goals
- Structuring user personas realistically
- Prioritizing features (ruthlessly!)
- Customizing constitutional principles
- Defining measurable success metrics
- Identifying custom agents needed

**Prevents common mistakes**:
- Vague success metrics ("improve user satisfaction" → "NPS > 40")
- Generic personas ("John, a developer" → "Sarah, mid-level backend engineer...")
- Scope creep (including every feature in MVP)
- Implementation details sneaking into requirements
- Over-specifying technology choices

## PRD Review Checklist

Before finalizing, verify:

**Completeness**:
- [ ] Executive summary clearly states vision, problem, success metrics
- [ ] All user personas documented with goals and pain points
- [ ] Core features have acceptance criteria
- [ ] All 14 constitutional principles addressed
- [ ] Technical constraints documented
- [ ] MVP clearly defined
- [ ] Open questions identified with owners and deadlines

**Clarity**:
- [ ] All requirements are testable and measurable
- [ ] Success metrics are quantifiable (not "good" or "fast")
- [ ] Personas are specific and realistic
- [ ] Feature priorities clearly marked
- [ ] No implementation details (WHAT/WHY only, not HOW)

**Alignment**:
- [ ] Goals align with vision and problem statement
- [ ] Features support defined user journeys
- [ ] Success metrics measure stated goals
- [ ] Constitutional principles don't conflict

**Actionability**:
- [ ] specification-agent can extract user stories
- [ ] planning-agent has sufficient constraints
- [ ] Each feature can become a spec
- [ ] Dependencies identified
- [ ] Risks have mitigation plans

**Stakeholder Review**:
- [ ] Product owner approved
- [ ] Technical feasibility validated
- [ ] Legal/compliance reviewed (if applicable)

## Next Steps After PRD

**RECOMMENDED**: Use `/initialize-project` command to automate steps 1-2:

```bash
/initialize-project
```

This command will:
- Update constitution with all PRD customizations
- Create custom agents identified in Principle X
- Update workflow documentation
- Validate compliance and provide next steps

**OR** proceed manually:

1. **Update Constitution**
   ```bash
   # Edit .specify/memory/constitution.md
   # Add project-specific guidance from PRD
   ```

2. **Create Custom Agents** (from Principle X in PRD)
   ```bash
   /create-agent agent-name "Purpose from PRD"
   ```

3. **Begin Feature Specifications**
   ```bash
   /specify "First MVP feature from PRD"
   ```

## Example Workflow

```bash
# 1. Create PRD
/create-prd E-Commerce Platform

# 2. Complete PRD sections using prd-specialist agent
# - Define vision: "Democratize e-commerce for small businesses"
# - Document personas: Small business owners, customers
# - List MVP features: Product catalog, shopping cart, checkout
# - Customize constitutional principles
# - Define success: 100 merchants onboarded in 3 months

# 3. Initialize project (RECOMMENDED - automates constitution + agent creation)
/initialize-project

# 4. Start feature development
/specify "Product catalog with search and filters"
/plan
/tasks
# ... implement ...

/specify "Shopping cart with persistence"
/plan
/tasks
# ... implement ...
```

### Alternative: Manual Initialization

```bash
# 3a. Manual constitution update
# Edit .specify/memory/constitution.md with PRD customizations

# 3b. Create custom agents identified in PRD
/create-agent payment-specialist "Payment processing and fraud detection"
/create-agent inventory-specialist "Inventory management and stock tracking"

# 4. Start feature development...
```

## Files Created

- `.docs/prd/prd.md` - Your Product Requirements Document
- `.docs/prd/PRD_QUICK_REFERENCE.md` - Quick reference guide

## Output Location

```
.docs/
└── prd/
    ├── prd.md                    # Main PRD document
    └── PRD_QUICK_REFERENCE.md    # Helper guide
```

## Tips for Success

1. **Be Ruthless About MVP**
   - If you can't ship without it, it's in MVP
   - Everything else is Phase 2+
   - "Would we delay launch for this?" is the test

2. **Make Success Metrics Quantifiable**
   - ❌ "Improve user satisfaction"
   - ✅ "Achieve NPS score > 40 within 3 months"

3. **Personas Must Be Specific**
   - ❌ "John, a software developer"
   - ✅ "Sarah, a mid-level backend engineer at a Series B startup, managing 3 microservices..."

4. **Requirements = WHAT & WHY, Not HOW**
   - ❌ "System should use React with Redux"
   - ✅ "Frontend must integrate with existing GraphQL API"

5. **Ask Questions Early**
   - Use prd-specialist agent to clarify ambiguities
   - Better to ask now than make wrong assumptions
   - Open questions section exists for a reason!

## Remember

The PRD is your north star. It:
- Guides all feature specifications
- Informs all implementation planning
- Customizes the framework for your needs
- Aligns stakeholders on vision and priorities

Invest time here to save time everywhere else in the project!

---

**Related Commands**:
- `/initialize-project` - **NEXT STEP** - Initialize project from completed PRD
- `/specify` - Create feature specifications (references PRD)
- `/plan` - Generate implementation plans (references PRD)
- `/create-agent` - Create custom agents (identified in PRD)
