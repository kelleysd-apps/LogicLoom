# Workflows Context Module
<!-- Auto-generated from CLAUDE.md - Plugin-First Architecture v4.1 -->
<!-- Module: SDD workflow commands, feature development lifecycle, architecture -->

## SDD (Specification-Driven Development) Workflow

The SDD framework provides a structured approach to feature development with built-in quality gates, constitutional compliance, and multi-agent coordination.

---

## Phase 0: Project Initialization

### /create-prd Command

**Purpose**: Establishes Single Source of Truth (SSOT) for entire project

**Agent**: Executed by `prd-specialist` (auto-delegated per Principle X)

**Script**: `.specify/scripts/bash/create-prd.sh [project_name]`

**When to Use**:
- Starting a new project (first step before any features)
- Establishing product foundation and strategy
- Defining framework customizations for your context
- Aligning stakeholders on vision and priorities

**Outputs**:
- Product vision, goals, and success metrics
- User personas and journeys
- Core features and requirements with acceptance criteria
- Constitutional customizations (all 16 principles)
- Technical constraints and integration requirements
- Release strategy and MVP definition
- Custom agent planning
- Quick reference guide

**File Created**: `.docs/prd/prd.md`

**Workflow Integration**:
- `/specify` → References PRD for user stories, personas, acceptance criteria
- `/plan` → References PRD for technical constraints, architecture principles
- Constitution → Updated with project-specific guidance from PRD
- Custom agents → Created based on needs identified in PRD

**Usage**:
```bash
/create-prd                # Interactive mode
/create-prd MyProject      # With project name
```

---

## Phase 1: Feature Specification

### /specify Command

**Purpose**: Create detailed feature specification with user stories and acceptance criteria

**Skill**: Executed by `sdd-specification` skill (auto-delegated per Principle X)

**Script**: `.specify/scripts/bash/create-new-feature.sh --json "$ARGUMENTS"`

**When to Use**:
- Starting new feature development
- Need to document requirements before implementation
- Establish acceptance criteria for feature

**User Approval Required**:
- **REQUIRES USER APPROVAL** for new feature branch creation
- Will ask if you want a new feature branch created
- If approved, will ask for desired branch format/name
- Default format when approved: `###-feature-name`

**Outputs**:
- spec.md at `specs/###-feature-name/spec.md`
- User stories with acceptance criteria
- Functional and non-functional requirements
- Constraints and dependencies
- Success metrics

**DS-STAR Enhancement**:
- Automatically invokes refinement loop after spec generation
- Verifies specification quality against thresholds (completeness ≥0.90)
- Iteratively refines until sufficient or max 20 rounds
- Provides actionable feedback for improvements
- Escalates to human if quality threshold not met

**Skill Reference**: `plugins/sdd-specification/skills/sdd-specification/SKILL.md`

**Usage**:
```bash
/specify
# Interactive prompts for feature details
```

---

## Phase 2: Implementation Planning

### /plan Command

**Purpose**: Generate implementation plan with technical research, API contracts, and data models

**Skill**: Executed by `sdd-planning` skill (auto-delegated per Principle X)

**Script**: `.specify/scripts/bash/setup-plan.sh --json`

**When to Use**:
- After feature spec is complete
- Need technical research and design decisions
- Design API contracts and data models before coding

**Workflow Steps**:
1. **Phase 0 - Research**: Technology stack selection, library evaluation, best practices research, resolve technical unknowns
2. **Constitution Check Gate**: Validate research completeness
3. **Phase 1 - Design**: API contracts (OpenAPI/GraphQL), data entity modeling, test scenario planning
4. **Constitution Check Gate**: Validate design quality and spec alignment
5. **Readiness Validation**: Ensure ready for task generation

**Outputs**:
- `plan.md` - Implementation approach and architecture decisions
- `research.md` - Technical decisions, library choices, pattern recommendations
- `data-model.md` - Entity definitions with fields, relationships, validation rules
- `contracts/` - API contract schemas (OpenAPI/GraphQL)
- `quickstart.md` - Test scenarios and integration test plan

**DS-STAR Enhancement**:
- Automatically invokes verification gate after plan generation
- Verifies plan quality against thresholds (completeness ≥0.85, spec alignment ≥0.90)
- **Blocks progression to /tasks if quality insufficient**
- Provides actionable feedback for improvements
- MUST address feedback before proceeding

**Constitutional Validation**:
- Enforces Library-First, Test-First, Contract-First principles
- Pre-research and post-design compliance checks
- Complexity tracking and justification documentation

**Skill Reference**: `plugins/sdd-specification/skills/sdd-planning/SKILL.md`

**Usage**:
```bash
/plan
# Reads spec.md and generates planning artifacts
```

---

## Phase 3: Task Generation

### /tasks Command

**Purpose**: Create dependency-ordered task list from design artifacts

**Skill**: Executed by `sdd-tasks` skill (auto-delegated per Principle X)

**Script**: `.specify/scripts/bash/check-task-prerequisites.sh --json`

**When to Use**:
- After implementation plan is complete
- Need task breakdown with dependencies
- Ready to start implementation

**Prerequisites**:
- spec.md exists
- plan.md exists
- contracts/ directory exists (if feature has API endpoints)
- data-model.md exists (if feature has data entities)

**Workflow Steps**:
1. Verify plan artifacts exist
2. Extract tasks from plan and contracts
3. Identify dependencies between tasks
4. Mark parallel-executable tasks with [P]
5. Order tasks by dependencies
6. Generate tasks.md

**Output**: `tasks.md` with dependency-ordered task list

**Parallel Execution Markers**: Tasks marked with [P] can be executed in parallel (no dependencies)

**Skill Reference**: `plugins/sdd-specification/skills/sdd-tasks/SKILL.md`

**Usage**:
```bash
/tasks
# Generates task list from plan artifacts
```

---

## Phase 4: Implementation

### Working with Tasks

**When implementing features:**
1. Always work from feature branches (`###-feature-name` format)
2. Follow TDD: Write tests → Get approval → Fail tests → Implement
3. Each contract requires a test, each entity needs a model
4. Use parallel execution markers [P] for independent tasks
5. All paths must be absolute from repository root

**Testing Approach**:
- Check feature-specific `quickstart.md` for test scenarios
- Check `contracts/` directory for contract tests (one per endpoint)
- Integration test scenarios from user stories
- No standard test framework assumed - check `plan.md` for tech stack decisions

**Task Execution Order**:
1. Library/module structure
2. Data models (if database entities)
3. API contracts and tests (TDD - failing tests first)
4. Core implementation
5. Integration tests
6. Documentation updates
7. Refactoring and optimization

---

## Phase 5: Finalization & Commit

### /finalize Command (NEW - DS-STAR Enhancement)

**Purpose**: Pre-commit constitutional compliance validation

**Script**: `.specify/scripts/bash/finalize-feature.sh --json`

**CRITICAL**: NEVER performs git operations autonomously (Principle VI)

**When to Use**:
- After implementation complete
- Before committing changes
- Quality gate validation

**Checks Performed**:
- Tests passing and coverage >80%
- No linting errors
- Code style compliance (black, isort)
- Documentation synchronized (CLAUDE.md, README, specs, API docs)
- No secrets in code (.env templates updated)
- Constitutional compliance across all 16 principles

**Output**: Compliance report with pass/fail status

**Suggests Manual Git Commands** (user must execute):
```bash
git add <files>
git commit -m "message"
git push origin <branch>
```

**Usage Pattern**:
```bash
# After implementation complete
./.specify/scripts/bash/finalize-feature.sh

# If all checks pass, manually execute suggested git commands
git add <files>
git commit -m "message"
git push origin <branch>
```

**Skill Reference**: `plugins/sdd-governance/skills/constitutional-compliance/SKILL.md`

---

## Complete SDD Workflow Diagram

```
Phase 0: Project Initialization
   ↓
┌──────────────────────────────────┐
│ /create-prd                      │ ← prd-specialist
│ - Product vision & goals         │
│ - User personas & journeys       │
│ - Constitutional customizations  │
│ Output: .docs/prd/prd.md         │
└──────────────────────────────────┘
   ↓
Phase 1: Feature Specification
   ↓
┌──────────────────────────────────┐
│ /specify                         │ ← sdd-specification skill
│ - User stories                   │
│ - Acceptance criteria            │
│ - Constraints                    │
│ Output: specs/###/spec.md        │
│ ✓ DS-STAR Refinement Loop       │
└──────────────────────────────────┘
   ↓
Phase 2: Implementation Planning
   ↓
┌──────────────────────────────────┐
│ /plan                            │ ← sdd-planning skill
│ Phase 0: Technical Research      │
│ - Library evaluation             │
│ - Best practices                 │
│ Constitution Check Gate ✓        │
│ Phase 1: Design                  │
│ - API contracts                  │
│ - Data models                    │
│ - Test scenarios                 │
│ Constitution Check Gate ✓        │
│ Output: plan.md, research.md,    │
│         data-model.md, contracts/│
│ ✓ DS-STAR Verification Gate     │
└──────────────────────────────────┘
   ↓
Phase 3: Task Generation
   ↓
┌──────────────────────────────────┐
│ /tasks                           │ ← sdd-tasks skill
│ - Task breakdown                 │
│ - Dependency analysis            │
│ - Parallel markers [P]           │
│ Output: specs/###/tasks.md       │
└──────────────────────────────────┘
   ↓
Phase 4: Implementation
   ↓
┌──────────────────────────────────┐
│ Execute Tasks                    │ ← Domain skills
│ - TDD: Tests first               │   (frontend-operations,
│ - Implement features             │    api-design,
│ - Integration tests              │    schema-design,
│ - Documentation                  │    testing-operations, etc.)
└──────────────────────────────────┘
   ↓
Phase 5: Finalization & Commit
   ↓
┌──────────────────────────────────┐
│ /finalize                        │ ← Constitutional validation
│ - Test coverage >80%             │
│ - No linting errors              │
│ - Docs synchronized              │
│ - 16 principles validated        │
│ Output: Compliance report        │
│ ✓ Suggests git commands          │
└──────────────────────────────────┘
   ↓
Manual Git Operations (User Approval Required)
   ↓
┌──────────────────────────────────┐
│ User Executes:                   │
│ git add <files>                  │
│ git commit -m "message"          │
│ git push origin <branch>         │
└──────────────────────────────────┘
```

---

## Agent Management Commands

### /create-agent Command

**Purpose**: Create specialized subagent with constitutional compliance

**Agent**: Executed by `subagent-architect` (auto-delegated per Principle X)

**Script**: `.specify/scripts/bash/create-agent.sh --json`

**Features**:
- Auto-determines department based on purpose
- Sets appropriate tool restrictions
- Initializes memory structure
- Constitutional compliance built-in

**Usage**:
```bash
/create-agent custom-integration-agent "Custom integration specialist"
```

**Output**: New agent file at `plugins/<plugin>/agents/<agent-name>.md`

---

### /create-skill Command

**Purpose**: Create procedural workflow skills with step-by-step guidance

**Features**:
- Creates skill at `plugins/<plugin>/skills/<skill-name>/SKILL.md`
- Auto-registers skill in plugin manifest and agent-collaboration-triggers.md
- Interactive workflow for skill metadata and procedure definition

**Usage**:
```bash
/create-skill                           # Interactive mode
/create-skill debug "Vercel debugging"  # With arguments
```

**Output**: New skill file with frontmatter metadata and procedure steps

---

## Key Architecture

### Directory Structure

```
.specify/
├── memory/
│   ├── constitution.md                    # Core principles (v3.0.0 - 16 principles)
│   ├── constitution_update_checklist.md   # Mandatory change management
│   └── agent-collaboration-triggers.md    # Agent delegation reference
├── scripts/bash/                          # Workflow automation scripts
│   ├── common.sh                          # Shared functions + git approval
│   ├── constitutional-check.sh            # 16-principle compliance validator
│   ├── sanitization-audit.sh              # Framework sanitization checker
│   ├── create-new-feature.sh              # Feature initialization + refinement
│   ├── setup-plan.sh                      # Planning workflow + verification
│   ├── check-task-prerequisites.sh        # Task generation validator
│   └── finalize-feature.sh                # Pre-commit compliance validation
├── templates/                             # Document templates
│   ├── spec-template.md                   # Feature specification
│   ├── plan-template.md                   # Implementation plan (9-step)
│   ├── tasks-template.md                  # Task list generation
│   └── agent-file-template.md             # New agent template
├── config/                                # Configuration files
│   └── refinement.conf                    # Refinement engine settings

specs/###-feature-name/                     # Per-feature documentation
├── spec.md                                # Feature requirements
├── plan.md                                # Technical approach
├── research.md                            # Technical decisions
├── data-model.md                          # Entity definitions
├── contracts/                             # API contracts
├── quickstart.md                          # Test scenarios
└── tasks.md                               # Implementation tasks
```

---

## Workflow Scripts

### Core Scripts

- **common.sh**: Shared functions for branch/path management, git approval
- **create-new-feature.sh**: Initialize feature branch and spec + DS-STAR refinement loop
- **setup-plan.sh**: Prepare implementation planning + DS-STAR verification gate
- **check-task-prerequisites.sh**: Verify design artifacts exist before task generation
- **finalize-feature.sh**: Pre-commit compliance validation (no auto-git)
- **update-agent-context.sh**: Update AI assistant context files

### Validation Scripts

- **constitutional-check.sh**: Automated compliance checking for all 16 principles
- **sanitization-audit.sh**: Verifies framework sanitization (no project-specific elements)

**Run before commits and releases**:
```bash
./.specify/scripts/bash/constitutional-check.sh
./.specify/scripts/bash/sanitization-audit.sh
```

---

## DS-STAR Multi-Agent Enhancements (Feature 001)

The framework includes proven multi-agent patterns from Google's DS-STAR system:

### Quality Gates

- **Automatic Verification**: Specs and plans automatically verified for quality
- **Iterative Refinement**: Specs refined up to 20 rounds until quality thresholds met
- **Blocking Gates**: Insufficient plans block progression to tasks phase
- **Actionable Feedback**: Clear guidance provided for improvements

### Configuration

Quality thresholds configured in `.specify/config/refinement.conf`:

| Setting | Value | Purpose |
|---------|-------|---------|
| `MAX_REFINEMENT_ROUNDS` | 20 | Maximum iterations before escalation |
| `EARLY_STOP_THRESHOLD` | 0.95 | Stop if quality exceeds this |
| `SPEC_COMPLETENESS_THRESHOLD` | 0.90 | Specification quality requirement |
| `PLAN_QUALITY_THRESHOLD` | 0.85 | Plan quality requirement |
| `TEST_COVERAGE_THRESHOLD` | 0.80 | Code coverage requirement (Principle II) |

### Graceful Degradation

If DS-STAR components unavailable (Python not installed, dependencies missing):
- Workflow continues without quality gates
- Warning messages displayed
- Manual review recommended
- No workflow blocking

### Performance Targets

- Context retrieval: <2 seconds
- Debug iteration cycle: <30 seconds
- 3.5x improvement in task completion accuracy (target)
- >70% automatic fix rate for common errors (target)

---

## Workflow Loading

Load workflow context when needed:

```bash
# Load workflows module
./.specify/scripts/bash/load-context.sh load workflows

# Load based on request analysis
./.specify/scripts/bash/load-context.sh analyze "/plan the authentication feature"
```

---

**Module Version**: 2.0.0
**Created**: 2026-01-09 (Sprint 3 Task T024)
**Last Updated**: 2026-02-07
**Constitutional Authority**: Principles I-XVI (All 16 Principles)
**Source Documents**:
- CLAUDE.md "Commands" and "Key Architecture" sections
- `.specify/scripts/bash/` workflow scripts
- `.specify/memory/constitution.md` (v3.0.0)
- `plugins/*/skills/` skill definitions

## Unified Specification Workflow (NEW)

### Overview

The unified `/specification` command consolidates the entire SDD workflow:

```
User Request ──→ /specification ──→ 7 Artifacts
                      │
                      ├── Phase 1: spec.md
                      ├── Phase 2: plan.md + research.md + data-model.md + contracts/ + quickstart.md
                      └── Phase 3: tasks.md
```

### Quality Gates

| Phase | Artifact | Threshold |
|-------|----------|-----------|
| Specification | spec.md | 90% completeness |
| Planning | plan.md | 85% quality |
| Tasks | tasks.md | Full coverage |

### Workflow State

State persisted in `specs/<branch>/.workflow-state.json`:
- Enables resume after interruption
- Tracks phase progress
- Records quality gate results

---

## Git Push Workflow (NEW)

### Overview

The `/git-push` command provides a complete git workflow with Principle VI compliance:

```
/git-push
    │
    ├── 📊 DIFF ─────────→ Show changes
    │         ↓
    ├── 📝 COMMIT ───────→ 🔒 Approval Required
    │         ↓
    ├── 🚀 PUSH ─────────→ 🔒 Approval Required
    │         ↓
    ├── 📋 PR_CREATE ────→ 🔒 Approval Required
    │         ↓
    ├── 🔍 CONFLICT_CHECK
    │         ↓
    │   ┌─ CLEAN ────────→ ✅ COMPLETE
    │   └─ DIRTY ────────→ CONFLICT_RESOLVE ─┐
    │                            ↑           │
    │                            └───────────┘
    │                            (loop until clean)
    │
    └── ✅ COMPLETE
```

### Principle VI Checkpoints

Every git operation requires explicit approval:
- `git commit` → "Approve commit? (y/n)"
- `git push` → "Push to origin? (y/n)"
- `gh pr create` → "Create this PR? (y/n)"
- Conflict resolution → "Resolve conflicts? (y/n)"

**The workflow NEVER executes git commands without user approval.**

