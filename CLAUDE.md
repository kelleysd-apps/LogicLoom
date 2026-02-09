# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Context System (v2.0 - Token Efficient)

This framework uses **modular context loading** for 37% token efficiency improvement.

**This file contains**: Essential instructions (always loaded)
**Additional context**: Load as needed via `.claude/context/` modules

### Available Modules

| Module | Content | When to Load |
|--------|---------|--------------|
| **core.md** | Pre-flight protocol, MCP toolkit, constitution reference | Every session (redundant with this file) |
| **agents.md** | Agent registry, delegation protocol, multi-agent workflows | Multi-agent tasks, delegation |
| **skills.md** | Skill documentation, slash commands, workflows | Using /specify, /plan, /tasks |
| **workflows.md** | SDD workflows, feature development lifecycle | Feature work |
| **governance.md** | Constitutional principles, git operations, compliance | Git operations, quality gates |

### Load Context Modules

```bash
# Load specific module
./.specify/scripts/bash/load-context.sh load agents

# Intelligent analysis (auto-loads relevant modules)
./.specify/scripts/bash/load-context.sh analyze "your task description"

# List available modules
./.specify/scripts/bash/load-context.sh list
```

---

## MANDATORY: Message Pre-Flight Compliance Check

**EVERY user message MUST trigger this 4-step protocol BEFORE any work begins.**

```
STEP 1: CONSTITUTION ACKNOWLEDGMENT
       - Confirm awareness of 16 principles (I-XVI)
       - Key: II (Test-First), VI (Git Approval), X (Agent Delegation)

STEP 2: DOMAIN ANALYSIS
       - Scan message for domain trigger keywords
       - Identify: frontend, backend, database, testing, security, etc.

STEP 3: DELEGATION DECISION
       - 0 domains: may execute directly
       - 1 domain: MUST delegate to specialist agent
       - 2+ domains: MUST delegate to task-orchestrator

STEP 4: EXECUTION AUTHORIZATION
       - Confirm all steps complete
       - Output compliance summary
       - Proceed with action
```

### Compliance Summary Format

```
Constitutional Compliance Check:
- Domain(s): [none | single: <domain> | multi: <domains>]
- Delegation: [direct execution | <agent-name>]
- Git operations: [none planned | will request approval]
- Proceeding with: [action description]
```

### Quick Reference: Domain - Agent Mapping

| Domain | Trigger Keywords | Delegate To |
|--------|------------------|-------------|
| Frontend | UI, component, React, CSS, form | frontend-specialist |
| Backend | API, endpoint, server, auth, service | backend-architect |
| Database | schema, migration, query, RLS, SQL | database-specialist |
| Testing | test, TDD, E2E, coverage, QA | testing-specialist |
| Security | encryption, XSS, secrets, vulnerability | security-specialist |
| Performance | optimize, cache, benchmark, latency | performance-engineer |
| DevOps | deploy, CI/CD, Docker, pipeline | devops-engineer |
| Specification | spec, requirements, user story | specification-agent |
| Planning | /plan, research, contract design | planning-agent |
| Tasks | /tasks, task list, dependencies | tasks-agent |
| Multi-Domain | 2+ domains detected | task-orchestrator |

### Violation Self-Correction

If you start work without completing the pre-flight check:
1. **STOP** immediately
2. **ACKNOWLEDGE** the violation
3. **CORRECT** by running the 4-step protocol
4. **PROCEED** only after completing all steps

---

## CRITICAL: Read Constitution First

**ALWAYS read `.specify/memory/constitution.md` BEFORE starting any work.**

The constitution (v3.0.0) contains **16 enforceable principles**:
- **3 Immutable Principles** (I-III): Library-First, Test-First, Contract-First
- **6 Quality & Safety Principles** (IV-IX): Idempotency, Progressive Enhancement, Git Approval, Observability, Documentation Sync, Dependency Management
- **7 Workflow & Delegation Principles** (X-XVI): Agent Delegation, Input Validation, Design System, Access Control, AI Model Selection, File Organization, Plugin-First Architecture

### Critical Principles Quick Reference

| Principle | Requirement | Consequence |
|-----------|-------------|-------------|
| **II (Test-First)** | TDD mandatory, >80% coverage | IMMUTABLE - blocks merge |
| **VI (Git Approval)** | NO autonomous git operations | CRITICAL - always ask user |
| **X (Agent Delegation)** | Specialized work -> specialists | CRITICAL - delegate or violate |
| **XVI (Plugin-First)** | Capabilities as installable plugins | CRITICAL - all new features as plugins |

For complete constitutional reference, load the governance module:
```bash
./.specify/scripts/bash/load-context.sh load governance
```

---

## Git Operations (CRITICAL - Principle VI)

**NO automatic Git operations without user approval.** This includes:
- Branch creation, switching, or deletion
- Commits and commit messages
- Pushes, pulls, and merges
- Any modifications to Git history

**Always ask the user for explicit approval first.**

The `/finalize` command validates compliance but NEVER executes git commands. It provides a report and suggests commands for manual execution.

For complete git safety documentation, load the governance module:
```bash
./.specify/scripts/bash/load-context.sh load governance
```

---

## Project Overview

This is a specification-driven development framework that uses structured templates and workflows to generate and implement features. The project uses a TDD approach with contract-first design patterns as defined in the constitution.

### Quick Command Reference

| Command | Purpose | Plugin |
|---------|---------|--------|
| **`/specification`** | **Unified SDD workflow — spec, plan, tasks in one command** | **sdd-specification** |
| **`/git-push`** | **Complete git workflow — commit, push, PR** | **sdd-git** |
| `/create-prd` | Create Product Requirements Document | sdd-creation |
| `/create-agent` | Create specialized subagent | sdd-creation |
| `/create-plugin` | Create new SDD plugin | sdd-creation |
| `/debug` | Debug deployment/runtime issues | sdd-debug |
| `/finalize` | Pre-commit compliance validation | sdd-git |
| `/research` | Multi-LLM tribunal research (Claude, OpenAI, Gemini) | sdd-orchestrator |
| `/swarm` | Multi-agent swarm execution | sdd-orchestrator |
| `/build-team` | Sequential architect→implementor→reviewer | sdd-orchestrator |
| `/fullstack-team` | Parallel full-stack team | sdd-orchestrator |
| `/review-team` | Parallel security+quality+performance review | sdd-orchestrator |
| `/update-framework` | Check and apply upstream enhancements | sdd-maintenance |
| `/initialize-project` | Post-PRD project customization | sdd-maintenance |
| `/specify` | Create feature spec *(deprecated — use /specification)* | sdd-specification |
| `/plan` | Generate plan *(deprecated — use /specification)* | sdd-specification |
| `/tasks` | Generate tasks *(deprecated — use /specification)* | sdd-specification |

For detailed workflow documentation, load the workflows module:
```bash
./.specify/scripts/bash/load-context.sh load workflows
```

---

## MCP Server Configuration

The framework uses **Docker MCP Toolkit** as the primary MCP orchestration method, providing access to 310+ containerized MCP servers.

**Docker MCP Toolkit** (Pre-installed during setup):
- Dynamic discovery of 310+ servers via `mcp-find` tool
- Runtime installation via `mcp-add` tool
- Containerized execution (no local dependencies)
- Unified gateway for all MCP servers

**Docker MCP Toolkit Tools**:

| Tool | Purpose |
|------|---------|
| `mcp-find` | Search 310+ servers in Docker catalog |
| `mcp-add` | Add server to current session dynamically |
| `mcp-config-set` | Configure server credentials |
| `mcp-exec` | Execute tools from any enabled server |
| `code-mode` | Combine multiple MCP tools in JavaScript |

**Ask Claude for help with MCPs**:
- "Find MCP servers for database operations" (uses `mcp-find`)
- "Add the supabase MCP server" (uses `mcp-add`)
- "Configure my AWS credentials" (uses `mcp-config-set`)

**Security Notes**:
- Store all MCP credentials in `.env` (never commit!)
- Use `env:VAR_NAME` syntax in MCP configuration
- Docker Toolkit provides container isolation (1 CPU, 2GB RAM limits)

**Skill Reference**: `plugins/sdd-maintenance/skills/mcp-server-setup/SKILL.md`

---

## Agent Delegation Protocol

**Constitutional Principle X** requires specialized work be delegated to specialized agents.

**See `AGENTS.md`** for complete agent registry including:
- All 21 agents across 15 plugins
- Agent capabilities and tools
- Domain -> agent mapping (detailed)
- Slash command -> agent mapping
- Agent collaboration workflows

**Note**: CLAUDE.md and AGENTS.md are **tandem files** - they must be updated together.

For complete agent documentation, load the agents module:
```bash
./.specify/scripts/bash/load-context.sh load agents
```

### Hook-Based Orchestration (v3.0 — No Custom Agent Profile)

**Architecture**: Claude Code runs with its native capabilities. Constitutional governance
and orchestration guidance are injected via the `UserPromptSubmit` preflight hook as
`additionalContext`. No custom `"agent"` field in settings.json.

**Components**:
- `sdd-orchestrator-hook` plugin — Domain detection, agent recommendations, governance reminders
- `sdd-memory` plugin — Automatic memory context injection from project knowledge
- `governance-preflight.sh` — Hook script that combines orchestration + memory into additionalContext

**How It Works**:
1. User sends message → preflight hook fires
2. Hook detects domains (security, backend, etc.) from message keywords
3. Hook recommends specialist agents per Principle X
4. Hook searches project memory for relevant context (specs, tasks, past sessions)
5. Hook injects orchestration guidance + memory context as additionalContext
6. Claude Code processes request with full context, following constitutional governance

**Key Responsibilities** (via hook injection):
- Inject constitutional governance reminder on every message
- Detect domains and recommend specialist agents (Principle X)
- Route slash commands to plugin procedures
- Inject relevant project memory context
- Gate ALL git operations (Principle VI - CRITICAL)

---

## Key Architecture

### Directory Structure
```
.specify/
  memory/
    constitution.md                    # Core principles (v3.0.0 - 16 principles)
    constitution_update_checklist.md   # Mandatory change management
    agent-collaboration-triggers.md    # Agent delegation reference
  scripts/bash/                        # Workflow automation + plugin bridge
  templates/                           # Document templates
  config/                              # Configuration files

plugins/                               # Plugin-First Architecture (v4.1)
  sdd-governance/                      # Protected — constitutional enforcement
  sdd-specification/                   # /specification, /plan, /tasks
  sdd-orchestrator/                    # /swarm, /research, team commands
  sdd-creation/                        # /create-agent, /create-plugin, /create-prd
  sdd-git/                             # /git-push, /finalize
  sdd-debug/                           # /debug
  sdd-maintenance/                     # /update-framework, /initialize-project
  sdd-domain-*/                        # 7 domain specialist plugins

.claude/
  commands/                            # Slash commands (all bridge-generated from plugins)
  context/                             # Context modules
  hooks/                               # Governance hooks

mcp-servers/sdd-marketplace/           # Plugin marketplace MCP server

specs/###-feature-name/                # Per-feature documentation
  spec.md, plan.md, research.md, data-model.md, contracts/, quickstart.md, tasks.md
```

### Workflow Scripts

| Script | Purpose |
|--------|---------|
| `common.sh` | Shared functions + git approval |
| `constitutional-check.sh` | 16-principle compliance validator |
| `create-new-feature.sh` | Feature initialization + refinement |
| `setup-plan.sh` | Planning workflow + verification |
| `check-task-prerequisites.sh` | Task generation validator |
| `finalize-feature.sh` | Pre-commit compliance validation |
| `load-context.sh` | Modular context loading (NEW) |

Run before commits:
```bash
./.specify/scripts/bash/constitutional-check.sh
./.specify/scripts/bash/sanitization-audit.sh
```

---

## File Creation Rules (Principle XV)

**ALWAYS verify before creating files or folders.**

### Core Rules

1. **Verify Before Create**: Check parent directory exists with `ls` before creating files
2. **Edit Over Create**: Prefer modifying existing files over creating new ones
3. **Templates First**: Use templates from `.specify/templates/` when available
4. **Absolute Paths**: Always use absolute paths from repository root
5. **No Proactive Docs**: Never create README.md or documentation files unless explicitly requested

### Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Agent | `[role]-[function].md` | `backend-architect.md` |
| Skill folder | `[skill-name]/` | `domain-detection/` |
| Feature dir | `###-[name]/` | `001-user-auth/` |

**Policy**: See `.docs/policies/file-structure-policy.md`

---

## Task Management (SSOT Architecture)

### Three-Level Task Hierarchy

| Level | Location | Purpose |
|-------|----------|---------|
| **Project** | `specs/###-feature/tasks.md` | Full implementation checklist |
| **Session** | TodoWrite tool | Active work tracking |
| **Agent** | `.docs/agents/*/decisions/tasks/` | Completion history |

### TodoWrite Rules (CRITICAL)

1. **ONE task `in_progress`** at any time - never multiple
2. **Mark `completed` IMMEDIATELY** - don't batch completions
3. **Use for 3+ step tasks** - skip for trivial single-step work
4. **Keep focused** - 3-10 items max
5. **Derive from tasks.md** - session tasks come from project tasks

**Policy**: See `.docs/policies/todo-architecture-policy.md`

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
- `MAX_REFINEMENT_ROUNDS=20`
- `SPEC_COMPLETENESS_THRESHOLD=0.90`
- `PLAN_QUALITY_THRESHOLD=0.85`
- `TEST_COVERAGE_THRESHOLD=0.80` (matches Principle II)

### Performance Targets
- Context retrieval: <2 seconds
- Debug iteration cycle: <30 seconds
- 3.5x improvement in task completion accuracy (target)

---

## Framework v2.0 Enhancements (Feature 003)

The framework now includes 6 production-ready enhancements integrated in Phases 1-4:

### Integrated Enhancements

| Enhancement | Purpose | Constitutional Principle |
|-------------|---------|-------------------------|
| **Structured Logging** | Observability via `.specify/lib/logging.sh` | VII (Observability) |
| **Enhanced Git Safety** | Rollback checkpoints, commit suggestions | VI (Git Approval) |
| **Tool Restriction Policies** | Granular command validation | XI, XIII (Input Validation) |
| **Parallel Agent Execution** | 2-3x speedup for 3+ agents | IV, X (Idempotency, Delegation) |
| **Skill Auto-Discovery** | Plugin manifests with RL metrics | VIII (Documentation Sync) |
| **Modular Context Loading** | 37% token efficiency improvement | V, VIII, IX |

### Performance Improvements

| Metric | Improvement |
|--------|-------------|
| Token Efficiency | 37% reduction |
| Parallel Execution | 2-3x speedup |
| Context Loading | <2s with TTL caching |

For detailed enhancement documentation, see `.docs/reports/FRAMEWORK_ENHANCEMENTS_INTEGRATION_PLAN.md`

---

## AI Model Selection (Principle XIV)

**Default**: All specialized agents use **Opus 4.6** for maximum capability.

| Model | Use Case | When to Use |
|-------|----------|-------------|
| **Opus 4.6** | Default for all agents | Specialized work, architecture, security, complex reasoning |
| **Sonnet 4.5** | Fallback | Cost optimization, high-volume tasks, quota limits |
| **Haiku** | Quick tasks | Simple lookups, formatting, file operations |

**Model IDs**:
- Opus: `claude-opus-4-6`
- Sonnet: `claude-sonnet-4-5-20250929`
- Haiku: `claude-haiku-4-5-20251001`

---

## Plugin-First Architecture (v4.1)

All framework capabilities are organized as **discrete installable plugins** at `plugins/`.

### Plugin Registry

| Plugin | Category | Skills | Agents | Commands |
|--------|----------|--------|--------|----------|
| `sdd-governance` | governance | 6 | 1 | 0 |
| `sdd-specification` | core | 5 | 4 | 4 |
| `sdd-orchestrator` | orchestration | 5 | 4 | 6 |
| `sdd-orchestrator-hook` | orchestration | 1 | 0 | 0 |
| `sdd-memory` | orchestration | 1 | 1 | 0 |
| `sdd-creation` | core | 5 | 2 | 4 |
| `sdd-git` | core | 2 | 0 | 2 |
| `sdd-debug` | core | 1 | 1 | 1 |
| `sdd-maintenance` | core | 3 | 1 | 2 |
| `sdd-domain-*` | domain | 1-4 | 1 | 0 |

### Plugin Command Bridge

Commands are automatically synced from plugins to `.claude/commands/` via the bridge:

```bash
# Sync plugin commands (runs automatically on setup and plugin install)
.specify/scripts/bash/sync-plugin-commands.sh sync

# View command→plugin mapping
.specify/scripts/bash/sync-plugin-commands.sh list
```

### SDD Marketplace (MCP Server)

Plugin management via MCP tools:

| Tool | Purpose |
|------|---------|
| `marketplace-list` | List installed plugins with RL metrics |
| `marketplace-search` | Search plugin registry |
| `marketplace-install` | Install plugin from registry |
| `marketplace-validate` | Validate plugin governance compliance |
| `marketplace-update` | Update installed plugins |
| `marketplace-publish` | Publish plugin to registry (dry-run) |

---

## RL Feedback System (DS-STAR)

The framework includes an RL (Reinforcement Learning) feedback system that improves skill selection over time.

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| Metrics Tracking | `.docs/rl-metrics/skill-performance.json` | Detailed performance history |
| Skill Index | Plugin manifests (`plugins/*/plugin.json`) | RL weights for routing |
| Feedback Script | `.specify/scripts/bash/rl/collect-feedback.sh` | Record outcomes |
| Sync Script | `.specify/scripts/bash/rl/sync-metrics.sh` | Update skill index |
| Dashboard | `.specify/scripts/bash/rl/dashboard.sh` | View metrics |

### RL Flow

```
Skill Execution → Verifier Validation → Feedback Collection → Metrics Update
                                              ↓
                               selection_weight adjusted via EMA
```

### Commands

```bash
# Record skill execution result
.specify/scripts/bash/rl/collect-feedback.sh <skill-name> success|failure [tokens]

# Sync metrics to plugin manifests
.specify/scripts/bash/rl/sync-metrics.sh

# View dashboard
.specify/scripts/bash/rl/dashboard.sh
```

### Algorithm

Uses Exponential Moving Average (EMA) with learning rate 0.1:
```
success_rate = 0.9 * old_rate + 0.1 * (1 if success else 0)
selection_weight = clamp(success_rate, 0.1, 1.0)
```

**Documentation**: `.docs/architecture/RL-FEEDBACK-ARCHITECTURE.md`

## Additional Documentation

For comprehensive documentation, load the appropriate context modules:

```bash
# Agent delegation and registry
./.specify/scripts/bash/load-context.sh load agents

# Skill documentation
./.specify/scripts/bash/load-context.sh load skills

# SDD workflow details
./.specify/scripts/bash/load-context.sh load workflows

# Constitutional principles and compliance
./.specify/scripts/bash/load-context.sh load governance
```

**See Also**:
- `.specify/memory/constitution.md` - Constitutional principles (v3.0.0)
- `plugins/*/agents/` - Agent definitions (Plugin-First Architecture)
- `plugins/*/skills/` - Skill documentation (Plugin-First Architecture)
- `.docs/policies/` - Framework policies
- `.docs/reports/` - Framework documentation

---

**Framework**: sdd-agentic-framework v4.1.1
**Constitution**: v3.0.0 (16 Principles)
**Architecture**: Plugin-First (v4.1) with Command Bridge
**Context System**: Modular (v2.0)
**Last Updated**: 2026-02-07
