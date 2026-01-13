# CLAUDE.md

This file provides essential guidance to Claude Code when working with this repository.

## MANDATORY: Message Pre-Flight Compliance Check (FR-707)

**EVERY user message MUST trigger the 4-step compliance protocol BEFORE any work begins.**

See [.claude/skills/validation/message-preflight/SKILL.md](.claude/skills/validation/message-preflight/SKILL.md) for complete protocol.

### Quick Protocol

```
STEP 1: CONSTITUTION ACKNOWLEDGMENT → Confirm 15 principles (I-XV)
STEP 2: DOMAIN ANALYSIS → Scan for domain keywords
STEP 3: ROUTING DECISION → Skills-first routing via skill-index.json
STEP 4: EXECUTION → Proceed via skill → agent pathway
```

**Critical Principles**: II (Test-First >80%), VI (Git Approval), X (Skills-First Delegation)

---

## CRITICAL: Read Constitution First

**ALWAYS read [.specify/memory/constitution.md](.specify/memory/constitution.md) BEFORE starting work.**

Constitution v2.0.0 (ratified 2026-01-13):
- **3 Immutable**: Library-First, Test-First, Contract-First
- **6 Quality & Safety**: Idempotency, Progressive Enhancement, Git Approval, Observability, Documentation Sync, Dependency Management
- **6 Workflow & Delegation**: **Skills-First Delegation** (Principle X rewritten), Input Validation, Design System, Access Control, AI Model Selection, File Organization

---

## Architecture: Skills-First (v3.0.0)

**New in v3.0.0**: Skills invoke agents (not agents invoking skills).

### Workflow

```
User Message → Compliance Check → Router Agent → Skill → Agent(s) → Verifier → Output
```

### Core Registries

- **Skills**: [.claude/skill-index.json](.claude/skill-index.json) - 28 skills with RL metrics
- **Agents**: [.claude/agent-index.json](.claude/agent-index.json) - 13 agents (8 domain + 5 DS-STAR)
- **Triggers**: [.specify/memory/skill-activation-triggers.md](.specify/memory/skill-activation-triggers.md)

### Key Skills

| Skill | Triggers | Agent |
|-------|----------|-------|
| message-preflight | __system_preflight__ | (none - direct) |
| sdd-specification | /specify, spec | specification-orchestrator |
| sdd-planning | /plan, research | specification-orchestrator |
| sdd-tasks | /tasks | specification-orchestrator |
| domain/* | keywords | domain agents |

---

## Commands

### Workflow Commands

- `/create-prd` - Create Product Requirements Document
- `/initialize-project` - Customize framework after PRD completion
- `/specify` - Create feature specification (asks about branch creation)
- `/plan` - Generate implementation plan with research
- `/tasks` - Generate dependency-ordered task list
- `/finalize` - Pre-commit compliance validation (NO auto-git)

### Agent/Skill Management

- `/create-agent` - Create specialized subagent
- `/create-skill` - Create new skill with procedural guidance

### Details

See [Command Reference](#commands-reference) section below for complete details.

---

## Key Architecture

### Directory Structure

```
.claude/
├── skill-index.json          # 28 skills with RL
├── agent-index.json          # 13 agents
├── skills/                   # 8 categories
└── agents/                   # consolidated/ + ds-star/

.specify/
├── memory/constitution.md    # v1.6.0 principles
├── scripts/bash/rl/          # RL infrastructure
└── templates/                # Skill/agent templates

specs/###-feature/            # Per-feature docs
└── [spec|plan|tasks|contracts|research|data-model|quickstart].md
```

### Agents (13 Total)

**8 Domain Agents** (consolidated from 15):
- implementation-specialist (frontend + full-stack)
- operations-specialist (devops + performance)
- specification-orchestrator (spec + planning + tasks + PRD)
- quality-specialist (testing + security)
- backend-architect, database-specialist, system-architect, workflow-coordinator

**5 DS-STAR Agents**:
- router-agent (RL-enhanced routing)
- verifier-agent (quality gates)
- auto-debug-agent (automatic fixes)
- finalizer-agent (pre-commit validation)
- context-analyzer (codebase intelligence)

See [AGENTS.md](AGENTS.md) for complete agent details.

---

## Development Principles

ALL principles defined in [.specify/memory/constitution.md](.specify/memory/constitution.md).

**Never proceed without verifying constitutional compliance.**

### Constitution Update Process

When updating constitution: [.specify/memory/constitution_update_checklist.md](.specify/memory/constitution_update_checklist.md) MUST be followed.

---

## Git Operations (CRITICAL - Principle VI)

**NO automatic Git operations without user approval.**

Always ask first for:
- Branch creation/switching/deletion
- Commits, pushes, pulls, merges
- Any Git history modifications

**Note**: `/specify` asks about branch creation. `/finalize` suggests commands but NEVER executes them.

---

## File Creation Rules (Principle XV)

**ALWAYS verify before creating files.**

### Pre-Creation Checklist

```
[ ] Is this file necessary? (Can existing file be modified?)
[ ] Does parent directory exist?
[ ] Does file already exist?
[ ] Follows naming conventions?
[ ] Using absolute paths from repo root?
```

See [.docs/policies/file-structure-policy.md](.docs/policies/file-structure-policy.md) for complete rules.

---

## Task Management

**Three-Level SSOT Architecture**:
1. **Project**: `specs/###-feature/tasks.md` (persists in git)
2. **Session**: TodoWrite tool (active tracking)
3. **Agent**: `.docs/agents/*/decisions/tasks/` (cross-session)

See [.docs/policies/todo-architecture-policy.md](.docs/policies/todo-architecture-policy.md) for details.

---

## MCP Server Configuration

**Primary Method**: Docker MCP Toolkit (310+ servers)

Use `mcp-find` and `mcp-add` tools for dynamic server discovery/installation.

See [MCP Server Setup Skill](.claude/skills/integration/mcp-server-setup/SKILL.md) for details.

---

## Testing Approach

- **TDD Required**: Principle II mandates >80% coverage
- **Contract-First**: Write contracts before implementation
- Test framework: Jest (configured)
- Run: `npm test` or `npm run test:contracts`

Check `specs/###-feature/quickstart.md` for feature-specific test scenarios.

---

## Commands Reference

### Product Requirements (Phase 0)

**`/create-prd`**
- **Agent**: prd-specialist
- **Purpose**: Create Product Requirements Document (SSOT)
- **Output**: `.docs/prd/prd.md`
- **Usage**: Start of new project, before any features

**`/initialize-project`**
- **Agent**: prd-specialist
- **Purpose**: Customize framework based on PRD
- **Prerequisite**: PRD must exist
- **Output**: Updated constitution, custom agents, configured MCPs

### Feature Specification Workflow

**`/specify`**
- **Agent**: specification-orchestrator
- **Asks**: Branch creation approval
- **Output**: `specs/###-feature/spec.md`
- **DS-STAR**: Auto-refines until quality ≥0.90

**`/plan`**
- **Agent**: specification-orchestrator
- **Output**: plan.md, research.md, data-model.md, contracts/, quickstart.md
- **DS-STAR**: Verifies plan quality before proceeding

**`/tasks`**
- **Agent**: specification-orchestrator
- **Output**: tasks.md (dependency-ordered)
- **Format**: Marks parallel tasks with [P]

**`/finalize`** (NEW - DS-STAR)
- **Agent**: finalizer-agent
- **Purpose**: Pre-commit compliance validation
- **Output**: Compliance report + suggested git commands
- **CRITICAL**: NEVER executes git operations (Principle VI)

### Agent Management

**`/create-agent`**
- **Agent**: system-architect
- **Output**: New agent in `.claude/agents/`
- **Auto-determines**: Department, tools, memory structure

**`/create-skill`**
- **Agent**: system-architect
- **Output**: New skill in `.claude/skills/`

---

## Validation Scripts

Run before commits:
```bash
./.specify/scripts/bash/constitutional-check.sh  # All 15 principles
./.specify/scripts/bash/sanitization-audit.sh    # Framework cleanliness
```

---

## Available Agents

See [AGENTS.md](AGENTS.md) for complete agent registry including:
- All 13 agents by department
- Agent capabilities and tools
- Domain → skill → agent mapping
- Slash command routing
- Agent collaboration workflows

**Note**: CLAUDE.md and AGENTS.md are **tandem files** - must update together per [.docs/policies/instruction-files-policy.md](.docs/policies/instruction-files-policy.md).

---

## Performance Metrics (v3.0.0)

| Metric | Target | Status |
|--------|--------|--------|
| Token Efficiency | 40-50% reduction | ✅ 50% achieved |
| Agent Count | 15 → 13 | ✅ 53% reduction |
| RL Improvement | +15-25% accuracy | 🔧 Infrastructure ready |
| DS-STAR Accuracy | 3.5x baseline | 🔧 Infrastructure ready |

---

## Model Selection (Principle XIV)

**Default**: Opus 4.5 for all specialized agents (maximum capability)

| Model | Use Case |
|-------|----------|
| Opus 4.5 | Default - specialized work, architecture, security |
| Sonnet 4.5 | Fallback - cost optimization, high-volume tasks |
| Haiku | Quick tasks - simple lookups, formatting |

---

## Resources

- **Constitution**: [.specify/memory/constitution.md](.specify/memory/constitution.md)
- **Skills Registry**: [.claude/skill-index.json](.claude/skill-index.json)
- **Agents Registry**: [.claude/agent-index.json](.claude/agent-index.json)
- **Agent Details**: [AGENTS.md](AGENTS.md)
- **Skill Triggers**: [.specify/memory/skill-activation-triggers.md](.specify/memory/skill-activation-triggers.md)
- **Migration Report**: [.docs/reports/migration-completion-report.md](.docs/reports/migration-completion-report.md)
- **Policies**: `.docs/policies/` directory

---

*Framework Version: 3.0.0 (Skills-First Architecture with RL and DS-STAR)*
*Constitution: v2.0.0 (ratified 2026-01-13, Principle X rewritten for skills-first)*
*Architecture Mode: skills-first (Phase 4 - legacy patterns blocked)*
*Last Updated: 2026-01-13*
