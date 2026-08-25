# Workflows Context Module
<!-- Auto-generated from CLAUDE.md - Plugin-First Architecture v4.1 -->
<!-- MAINTAINED BY HAND — there is no generator. load-context.sh only READS and
     caches .claude/context/*.md; nothing writes them. The "Auto-generated" line
     above records this file's ORIGIN (transcribed once from CLAUDE.md), not a
     live pipeline. Edit it directly and keep it in step with CLAUDE.md by hand.
     Every command, skill and path named here must resolve on disk. -->
<!-- Module: workflow commands, feature development lifecycle, architecture -->

## Workflow Packs (Interchangeable)

LogicLoom's constitutional governance is the **core**. Development workflows sit
on top of it as **interchangeable packs** — none is primary or legacy:

| Pack | Use when |
|------|----------|
| **Vision / Swarm** (`features/<name>/`) | Exploratory or novel work; unclear scope |
| **SDD waterfall** (`specs/###-name/`) | Well-understood feature with stable requirements |

This module documents the **SDD waterfall pack**. Its three phases — spec, plan,
tasks — are driven by the single `/specification` command; `/finalize` closes the
loop. All packs share the same built-in quality gates, constitutional compliance,
and multi-agent coordination.

---

## Phase 0: Project Initialization

### /create-prd Command

**Purpose**: Establishes Single Source of Truth (SSOT) for entire project

**Agent**: Executed by `prd-specialist` (auto-delegated per Principle X)

**Script**: `.logic-loom/scripts/bash/create-prd.sh [project_name]`

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

**File Created**: `specs/prd/PRD.md` (or a feature-specific location, e.g. `features/<name>/prd.md`)

**Workflow Integration**:
- `/specification` → References the PRD for user stories, personas and acceptance
  criteria in Phase 1, and for technical constraints and architecture principles
  in Phase 2
- Constitution → Updated with project-specific guidance from PRD
- Custom agents → Created based on needs identified in PRD

**Usage**:
```bash
/create-prd                # Interactive mode
/create-prd MyProject      # With project name
```

---

## Phases 1-3: Specification, Planning & Tasks

### /specification Command

**Purpose**: Produce the full SDD artifact set — specification, implementation
plan and dependency-ordered tasks — in one governed run.

**Skill**: Executed by the `unified-specification` skill (auto-delegated per Principle X)

**Command**: `plugins/sdd-specification/commands/specification.md`

**Supporting scripts**: `.logic-loom/scripts/bash/create-new-feature.sh`,
`.logic-loom/scripts/bash/setup-plan.sh`,
`.logic-loom/scripts/bash/check-task-prerequisites.sh`

**When to Use**:
- Requirements are well understood and stable
- A feature needs spec, contracts, data model and tasks as one coherent set
- (For exploratory or novel work, use the swarm pack instead: `/swarm explore` →
  `/create-prd` → plan mode → `/plan-review` → `/swarm implement`)

**User Approval Required**:
- **REQUIRES USER APPROVAL** for new feature branch creation (Principle VI)
- Default branch format when approved: `###-feature-name`

**Phase 1 — Specification**
1. Gather feature context and objectives
2. Define user stories, scenarios and acceptance criteria
3. Document functional and non-functional requirements, constraints, dependencies
4. Output: `spec.md` — validated by `.logic-loom/scripts/bash/validate-spec.sh`
   (quality gate: ≥ 90% completeness)

**Phase 2 — Planning**
1. **Research**: technology stack selection, library evaluation, resolve unknowns
2. **Constitution Check Gate**: validate research completeness
3. **Design**: API contracts (OpenAPI/GraphQL), data entity modeling, test scenarios
4. **Constitution Check Gate**: validate design quality and spec alignment
5. Outputs: `plan.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`
   — validated by `.logic-loom/scripts/bash/validate-plan.sh`
   (quality gate: ≥ 85% plan quality)

**Phase 3 — Tasks**
1. Verify plan artifacts exist
2. Extract tasks from plan and contracts, identify dependencies
3. Mark parallel-executable tasks with `[P]`, order by dependency
4. Output: `tasks.md` — validated by `.logic-loom/scripts/bash/validate-tasks.sh`

**Constitutional Validation**: enforces Library-First, Test-First and
Contract-First; pre-research and post-design compliance checks; complexity
tracking and justification.

**Skill Reference**: `plugins/sdd-specification/skills/unified-specification/SKILL.md`

**Usage**:
```bash
/specification "Build user authentication with email and password"
/specification --resume        # Resume an interrupted workflow
/specification --phase plan    # Start from a specific phase
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

### /finalize Command

**Purpose**: Pre-commit constitutional compliance validation

**Command**: `plugins/loom-git/commands/finalize.md`

**Scripts run**: `.logic-loom/scripts/bash/constitutional-check.sh`,
`tests/run_all_tests.sh`, and — when present and executable —
`.logic-loom/scripts/bash/build-graph-bridge.sh` + `.logic-loom/scripts/bash/lint-graph.sh`

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
/finalize
# (or run the compliance validator directly)
./.logic-loom/scripts/bash/constitutional-check.sh

# If all checks pass, manually execute suggested git commands
git add <files>
git commit -m "message"
git push origin <branch>
```

**Skill Reference**: `plugins/loom-governance/skills/constitutional-compliance/SKILL.md`

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
│ Output: specs/prd/PRD.md         │
└──────────────────────────────────┘
   ↓
Phases 1-3: Spec, Plan, Tasks
   ↓
┌──────────────────────────────────┐
│ /specification                   │ ← unified-specification skill
│ Phase 1: Specification           │
│ - User stories                   │
│ - Acceptance criteria            │
│ Quality Gate: spec ≥ 90% ✓       │
│ Phase 2: Planning                │
│ - Technical research             │
│ - API contracts                  │
│ - Data models                    │
│ Quality Gate: plan ≥ 85% ✓       │
│ Phase 3: Tasks                   │
│ - Dependency analysis            │
│ - Parallel markers [P]           │
│ Output: specs/<feature>/          │
│   spec.md, plan.md, research.md, │
│   data-model.md, contracts/,     │
│   quickstart.md, tasks.md        │
└──────────────────────────────────┘
   ↓
Phase 4: Implementation
   ↓
┌──────────────────────────────────┐
│ Execute Tasks                    │ ← Domain briefs, loaded via
│ - TDD: Tests first               │   get_domain_brief <domain>
│ - Implement features             │   (frontend, backend, database,
│ - Integration tests              │    testing, security,
│ - Documentation                  │    performance, devops)
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

**Script**: `.logic-loom/scripts/bash/create-agent.sh --json`

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
.logic-loom/
├── memory/
│   ├── constitution.md                    # Core principles (v3.3.0 - 16 principles)
│   ├── constitution_update_checklist.md   # Mandatory change management
│   └── agent-collaboration-triggers.md    # Agent delegation reference
├── scripts/bash/                          # Workflow automation scripts
│   ├── common.sh                          # Shared functions + git approval
│   ├── constitutional-check.sh            # 16-principle compliance validator
│   ├── create-new-feature.sh              # Feature initialization
│   ├── setup-plan.sh                      # Planning workflow
│   ├── check-task-prerequisites.sh        # Task generation validator
│   ├── validate-spec.sh                   # Phase 1 quality gate
│   ├── validate-plan.sh                   # Phase 2 quality gate
│   ├── validate-tasks.sh                  # Phase 3 quality gate
│   └── load-context.sh                    # Modular context loading
├── templates/                             # Document templates
│   ├── spec-template.md                   # Feature specification
│   ├── plan-template.md                   # Implementation plan (9-step)
│   ├── tasks-template.md                  # Task list generation
│   └── agent-file-template.md             # New agent template
├── config/                                # Configuration files
│   ├── models.conf                        # Role→model tier convention
│   └── governance.conf                    # Governance mode (lean/strict)

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
- **create-new-feature.sh**: Initialize feature branch and spec
- **setup-plan.sh**: Prepare implementation planning
- **check-task-prerequisites.sh**: Verify design artifacts exist before task generation
- **constitutional-check.sh**: Pre-commit compliance validation, all 16 principles (no auto-git; invoked by `/finalize`)
- **update-agent-context.sh**: Update AI assistant context files

### Validation Scripts

- **constitutional-check.sh**: Automated compliance checking for all 16 principles

**Run before commits and releases**:
```bash
./.logic-loom/scripts/bash/constitutional-check.sh
```

---

## Workflow Loading

Load workflow context when needed:

```bash
# Load workflows module
./.logic-loom/scripts/bash/load-context.sh load workflows

# Load based on request analysis
./.logic-loom/scripts/bash/load-context.sh analyze "/specification the authentication feature"
```

---

**Module Version**: 2.0.0
**Created**: 2026-01-09 (Sprint 3 Task T024)
**Last Updated**: 2026-02-07
**Constitutional Authority**: Principles I-XVI (All 16 Principles)
**Source Documents**:
- CLAUDE.md "Commands" and "Key Architecture" sections
- `.logic-loom/scripts/bash/` workflow scripts
- `.logic-loom/memory/constitution.md` (v3.3.0)
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

