# CLAUDE.md — LogicLoom

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Project (technical)**: `logic-loom`
**Brand**: **LogicLoom**
**Framework folder**: `.logic-loom/`
**Per-feature folder**: `features/<feature-name>/`

LogicLoom is a **multi-agent harness** for building software with Claude Code.
It prefers a vision → PRD → plan → swarm loop over linear spec waterfalls, but
preserves the SDD waterfall (`/specification`, domain plugins, validators) as
**legacy alternatives** for users who want them.

---

## v3 Supplementary Principle (READ FIRST)

LogicLoom is **supplementary, not subtractive**. The migration introduced a new
primary workflow without removing the old one:

- **Primary path** (recommended for new work): `vision.md` → `/swarm explore` +
  `/research` → `/create-prd` → plan mode → `/plan-review` → `/swarm implement`
  → `/review-team` → `/git-push` → `/code-review` → `/retro`.
- **Legacy path** (still supported): `/specification` (unified spec/plan/tasks),
  `/build-team`, `/fullstack-team`, `/dev-loop`, `/finalize`, the 7
  `sdd-domain-*` plugins, validators, DS-STAR refinement — all retained.

Both styles share the same constitutional governance, plugin chassis, and
distribution machinery. Pick the workflow that matches the problem shape:

| Problem shape | Use |
|---|---|
| Exploratory or novel work; unclear scope | **Primary path** (`features/<name>/`) |
| Well-understood feature with stable requirements | Legacy `/specification` (`specs/###-name/`) |
| Quick fix, no significant unknowns | Direct execution; skip both |

What got cut entirely (not replaced — actually removed): our own
`mcp-servers/sdd-marketplace/` (deferred to Anthropic's Claude Code Plugin
Marketplace + Docker MCP Toolkit), RL telemetry infrastructure
(`.logic-loom/scripts/bash/rl/`, `src/sdd/feedback/`, `src/sdd/metrics/`), and
five stale internal scripts (`migrate-agent-to-skill`, `legacy-pattern-report`,
`skill-coverage-audit`, `analyze-logs`, `agent-collaboration.md`).

---

## MANDATORY: Message Pre-Flight Compliance Check

**EVERY user message MUST trigger this 4-step protocol BEFORE any work begins.**
Governance is unchanged from SDD-era; only the workflow path is new.

```
STEP 1: CONSTITUTION ACKNOWLEDGMENT
       - Confirm awareness of 16 principles (I-XVI)
       - Key: II (Test-First), VI (Git Approval), X (Agent Delegation)

STEP 2: DOMAIN ANALYSIS
       - Scan message for domain trigger keywords
       - Identify: frontend, backend, database, testing, security, etc.

STEP 3: DELEGATION DECISION
       - 0 domains: may execute directly
       - 1 domain: delegate to specialist (legacy) OR `/swarm explore` (primary)
       - 2+ domains: `/swarm` (primary) OR team-orchestration skill (legacy)

STEP 4: EXECUTION AUTHORIZATION
       - Confirm all steps complete
       - Output compliance summary
       - Proceed with action
```

### Compliance Summary Format

```
Constitutional Compliance Check:
- Domain(s): [none | single: <domain> | multi: <domains>]
- Delegation: [direct execution | /swarm <mode> | <legacy-agent-name>]
- Git operations: [none planned | will request approval]
- Proceeding with: [action description]
```

### Violation Self-Correction

If you start work without completing the pre-flight check:
1. **STOP** immediately
2. **ACKNOWLEDGE** the violation
3. **CORRECT** by running the 4-step protocol
4. **PROCEED** only after completing all steps

---

## LogicLoom Primary Workflow

The recommended loop for new feature work:

```
[EnterWorktree]
    ↓
/swarm explore <topic>   +   /research <question>
    ↓                            (read-only investigations,
features/<x>/vision.md            external cross-validated research)
    ↓
/swarm explore + /research        (fill gaps surfaced by vision)
    ↓
/create-prd <feature>             (broad PRD + office-hours
    ↓                              forcing-questions gate)
plan mode                         (sprint-structured plan.md
    ↓                              with file-ownership DAG)
/plan-review <feature>            (CEO + Eng reviewers — GATES implementation)
    ↓
/swarm implement [sprint]         (DAG topological sort,
    ↓                              freeze hook enforces ownership)
test / fix                        (direct debug loop on failures)
    ↓
/review-team                      (security + quality + performance + evaluator)
    ↓
/git-push                         (commit + PR with explicit approval)
    ↓
/code-review                      (Claude plugin — PR-level review)
    ↓
/retro <feature>                  (sprint retrospective → memory write)
    ↓
[ExitWorktree]
```

Steps are skippable when justified, but `vision.md` and `/plan-review` are
**hard gates** — they prevent broad-spec cascade and worker collisions.

### Per-feature folder layout

```
features/<feature-name>/
├── vision.md             # north-star, intentionally broad
├── exploration/          # /swarm explore outputs (read-only)
├── research/             # /research tribunal outputs
├── prd.md                # broad PRD with forcing-questions
├── plan.md               # sprint/wave-structured plan + file-ownership DAG
├── plan-review.md        # /plan-review verdict (CEO + Eng)
├── sprints/
│   └── NN-name/          # per-sprint worker outputs + evaluator findings
└── retro.md              # /retro learnings (also written to memory)
```

See `features/README.md` for the full convention.

---

## Quick Command Reference (Primary)

| Command | Purpose | Plugin |
|---|---|---|
| **`/swarm explore <topic>`** | Read-only parallel investigators; writes to `features/<x>/exploration/` | sdd-orchestrator |
| **`/swarm implement [sprint]`** | DAG-driven sprint execution; freeze hook enforces ownership | sdd-orchestrator |
| **`/swarm <freeform>`** | Generic multi-agent swarm (legacy mode preserved) | sdd-orchestrator |
| **`/research <question>`** | Jury-on-demand tribunal (1-3 judges by query type; `--judges all` for legacy 3-LLM) | sdd-orchestrator |
| **`/create-prd <feature>`** | Auto-detects vision-driven mode (vision.md exists) vs legacy mode; includes office-hours forcing-questions gate | sdd-creation |
| **`/plan-review <feature>`** | CEO + Eng review of plan.md before `/swarm implement` (single-skill, two internal reviewers) | sdd-orchestrator |
| **`/review-team`** | Four reviewers in parallel: security + quality + performance + behavioral evaluator (chrome-devtools MCP) | sdd-orchestrator |
| **`/git-push`** | Commit + push + PR creation with explicit user approval at each gate | sdd-git |
| **`/retro <feature>`** | Sprint retrospective; writes action items to sdd-memory | sdd-orchestrator |

---

## Quick Command Reference (Legacy SDD path)

These remain fully functional. Use when the problem is well-understood and the
linear spec → plan → tasks → implement flow fits.

| Command | Purpose | Plugin |
|---|---|---|
| `/specification` | Unified SDD waterfall — spec, plan, tasks in one command | sdd-specification |
| `/build-team` | Sequential architect → implementor → reviewer | sdd-orchestrator |
| `/fullstack-team` | Parallel frontend + backend + database specialists | sdd-orchestrator |
| `/dev-loop` | Recursive autonomous edit-test-debug cycles | sdd-dev-loop |
| `/finalize` | Pre-commit compliance validation (no git execution) | sdd-git |
| `/create-prd` (legacy mode) | Blank-slate PRD authoring (no vision.md present) | sdd-creation |
| `/create-agent` | Create specialized subagent | sdd-creation |
| `/create-plugin` | Create new LogicLoom plugin | sdd-creation |
| `/create-skill` | Create new skill | sdd-creation |
| `/update-framework` | Check and apply upstream enhancements | sdd-maintenance |
| `/initialize-project` | Post-PRD project customization | sdd-maintenance |

Legacy domain delegation (still routed by the preflight hook):

| Domain | Trigger keywords | Legacy specialist |
|---|---|---|
| Frontend | UI, component, React, CSS, form | sdd-domain-frontend |
| Backend | API, endpoint, server, auth, service | sdd-domain-backend |
| Database | schema, migration, query, RLS, SQL | sdd-domain-database |
| Testing | test, TDD, E2E, coverage | sdd-domain-testing |
| Security | encryption, XSS, secrets, vulnerability | sdd-domain-security |
| Performance | optimize, cache, benchmark, latency | sdd-domain-performance |
| DevOps | deploy, CI/CD, Docker, pipeline | sdd-domain-devops |

For new work, prefer `/swarm explore` over individual specialist routing.

---

## Constitution & Governance (UNCHANGED)

**ALWAYS read `.logic-loom/memory/constitution.md` BEFORE starting any work.**

The constitution (v3.0.0) contains **16 enforceable principles** unchanged from
SDD-era. Governance hooks, the preflight injection, and the git-safety gate
all continue to operate as before.

- **3 Immutable** (I-III): Library-First, Test-First, Contract-First
- **6 Quality & Safety** (IV-IX): Idempotency, Progressive Enhancement, Git Approval, Observability, Documentation Sync, Dependency Management
- **7 Workflow & Delegation** (X-XVI): Agent Delegation, Input Validation, Design System, Access Control, AI Model Selection, File Organization, Plugin-First Architecture

### Critical Principles Quick Reference

| Principle | Requirement | Consequence |
|---|---|---|
| **II (Test-First)** | TDD mandatory, >80% coverage | IMMUTABLE — blocks merge |
| **VI (Git Approval)** | NO autonomous git operations | CRITICAL — always ask user |
| **X (Agent Delegation)** | Specialized work → specialists or `/swarm` | CRITICAL — delegate or violate |
| **XVI (Plugin-First)** | Capabilities as installable plugins | CRITICAL — all new features as plugins |

### Git Operations (Principle VI)

**NO automatic Git operations without user approval.** This includes branch
creation/switching/deletion, commits, pushes, pulls, merges, history edits.

- `/git-push` requests explicit approval at each stage gate.
- `/finalize` (legacy) validates compliance but NEVER executes git commands.

---

## LogicLoom Hooks

The framework ships three new hooks under `.claude/hooks/` (in addition to the
unchanged governance preflight and dangerous-command guard):

| Hook | Purpose |
|---|---|
| `worktree-port-namespace.sh` | Computes per-worktree port/db namespaces (`PORT_BASE`, `DB_PORT`) so parallel worktrees don't collide |
| `context-cap-warn.sh` | At 800K of 1M default context, injects reset reminder + handoff-artifact prompt to avoid "context anxiety" wrap-up bias |
| `freeze-write-scope.sh` | Hook-level enforcement of plan-as-DAG file ownership: rejects writes outside the active task's declared `owns:` scope; default-allows when no DAG context |

Existing hooks unchanged: `user-prompt-submit/` (governance preflight),
`guard-dangerous-commands.sh`.

---

## MCP Server Configuration

LogicLoom relies on **two external ecosystems** for MCP discovery — we no
longer ship our own marketplace MCP.

1. **Anthropic Claude Code Plugin Marketplace** — first-party plugin
   discovery and install. Use `/plugin` Claude Code commands and the
   marketplace browser to find third-party plugins.
2. **Docker MCP Toolkit** — 310+ containerized MCP servers via the unified
   gateway.

| Tool | Purpose |
|---|---|
| `mcp-find` | Search 310+ servers in Docker catalog |
| `mcp-add` | Add server to current session dynamically |
| `mcp-config-set` | Configure server credentials |
| `mcp-exec` | Execute tools from any enabled server |
| `code-mode` | Combine multiple MCP tools in JavaScript |

**Security notes**:
- Store all MCP credentials in `.env` (never commit)
- Use `env:VAR_NAME` syntax in MCP configuration
- Docker Toolkit provides container isolation (1 CPU, 2GB RAM limits)

---

## Plugin Registry

All framework capabilities are **discrete installable plugins** under
`plugins/`. Bundled in-repo (not via marketplace).

| Plugin | Category | Notes |
|---|---|---|
| `sdd-governance` | governance | Constitutional enforcement, hooks, validators |
| `sdd-orchestrator` | orchestration | `/swarm` (explore/implement/freeform), `/research`, `/plan-review`, `/review-team`, `/retro`, `/build-team`, `/fullstack-team` |
| `sdd-orchestrator-hook` | orchestration | Preflight domain detection + agent recommendations |
| `sdd-memory` | orchestration | Memory context injection, `/retro` writes |
| `sdd-creation` | core | `/create-prd`, `/create-skill`, `/create-agent`, `/create-plugin` |
| `sdd-git` | core | `/git-push`, `/finalize` |
| `sdd-maintenance` | core | `/update-framework`, `/initialize-project` |
| `sdd-specification` | core (legacy) | `/specification` unified waterfall |
| `sdd-dev-loop` | core (legacy) | `/dev-loop` recursive autonomous loop |
| `sdd-domain-*` | domain (legacy) | 7 specialist plugins for frontend/backend/database/testing/security/performance/devops |

### Plugin command bridge

Commands are synced from plugins to `.claude/commands/` via the bridge:

```bash
.logic-loom/scripts/bash/sync-plugin-commands.sh sync      # sync all commands
.logic-loom/scripts/bash/sync-plugin-commands.sh list      # show command → plugin map
```

---

## Key Architecture

### Directory structure

```
.logic-loom/
  memory/
    constitution.md                    # 16 principles (v3.0.0 — UNCHANGED)
    constitution_update_checklist.md
  scripts/bash/                        # Workflow automation + plugin bridge
  templates/                           # vision-template, prd-template, plan-template, ...
  config/                              # Configuration
  lib/                                 # Shared shell libs (policy.sh, logging.sh)

plugins/                               # See registry above

.claude/
  commands/                            # Bridge-generated from plugins
  context/                             # Modular context loaders
  hooks/                               # Governance + LogicLoom hooks

features/                              # PRIMARY: per-feature workspaces (vision/PRD/plan/sprints/retro)
specs/                                 # LEGACY: SDD waterfall specs (still supported)

.docs/
  architecture/loom-architecture.md    # Full architectural reference (created in W3)
  policies/
  plans/loom-migration.md              # The migration master plan
```

### Workflow scripts

| Script | Purpose |
|---|---|
| `common.sh` | Shared functions + git approval |
| `constitutional-check.sh` | 16-principle compliance validator |
| `sync-plugin-commands.sh` | Plugin → `.claude/commands/` bridge |
| `load-context.sh` | Modular context loading |

Pre-commit (legacy SDD path):
```bash
./.logic-loom/scripts/bash/constitutional-check.sh
```

---

## File Creation Rules (Principle XV)

**ALWAYS verify before creating files or folders.**

1. **Verify Before Create**: Check parent directory exists before writing
2. **Edit Over Create**: Prefer modifying existing files
3. **Templates First**: Use `.logic-loom/templates/` when available
4. **Absolute Paths**: Always use absolute paths from repository root
5. **No Proactive Docs**: Never create README.md or other documentation files unless explicitly requested

### Naming conventions

| Type | Pattern | Example |
|---|---|---|
| LogicLoom feature dir | `<kebab-name>/` | `features/auth-cookie-rotation/` |
| Sprint dir | `NN-name/` | `sprints/01-foundations/` |
| Agent file | `[role]-[function].md` | `plan-reviewer.md` |
| Skill folder | `[skill-name]/` | `swarm-implement/` |
| Legacy SDD feature | `###-[name]/` | `specs/001-user-auth/` |

**Policy**: `.docs/policies/file-structure-policy.md`

---

## Task Management

### Three-level task hierarchy

| Level | Location | Purpose |
|---|---|---|
| **Project (primary)** | `features/<name>/plan.md` (DAG) and `features/<name>/sprints/NN-name/` | Sprint plan + per-sprint worker outputs |
| **Project (legacy)** | `specs/###-feature/tasks.md` | SDD waterfall task checklist |
| **Session** | TaskCreate/TaskUpdate tools | Active work tracking |

### Task tool rules (CRITICAL)

1. **ONE task `in_progress`** at any time — never multiple
2. **Mark `completed` IMMEDIATELY** via TaskUpdate — don't batch completions
3. **Use TaskCreate for 3+ step tasks** — skip for trivial single-step work
4. **Keep focused** — 3-10 items max

**Policy**: `.docs/policies/todo-architecture-policy.md`

---

## AI Model Selection (Principle XIV)

**Default**: All specialized agents use **Opus 4.6** for maximum capability.

| Model | Use Case |
|---|---|
| **Opus 4.6** | Default for agents; architecture, security, complex reasoning |
| **Sonnet 4.5** | Cost optimization; high-volume tasks |
| **Haiku** | Quick lookups; formatting; file ops |

**Model IDs**: `claude-opus-4-6`, `claude-sonnet-4-5-20250929`, `claude-haiku-4-5-20251001`

---

## Distribution & Cloner Support

The framework's cloner-init machinery is **UNTOUCHED**:

- `/update-framework` — pulls upstream LogicLoom enhancements
- `.sdd-sync-ref` — upstream pointer (filename preserved for backwards compatibility with already-cloned projects)
- `/initialize-project` — post-PRD project customization

---

## Additional Documentation

```bash
# Modular context loaders (still available)
./.logic-loom/scripts/bash/load-context.sh load agents
./.logic-loom/scripts/bash/load-context.sh load skills
./.logic-loom/scripts/bash/load-context.sh load workflows
./.logic-loom/scripts/bash/load-context.sh load governance
```

**See Also**:
- `.docs/architecture/loom-architecture.md` — full architectural reference (LogicLoom shape)
- `.docs/architecture/evaluator-protocol.md` — `/review-team` evaluator contract
- `.docs/architecture/freeze-scope-protocol.md` — `/freeze` hook contract
- `.docs/plans/loom-migration.md` — migration master plan + locked decisions
- `.logic-loom/memory/constitution.md` — 16 constitutional principles (v3.0.0)
- `features/README.md` — per-feature folder convention
- `plugins/*/skills/` — skill documentation (Plugin-First Architecture)
- `AGENTS.md` — agent registry (tandem file — must update with CLAUDE.md)

---

## What changed in v6.0 (LogicLoom)

- **Added** the vision/PRD/plan/swarm primary workflow under `features/`
- **Added** `/plan-review`, `/retro`, `/swarm explore`, `/swarm implement` skills
- **Added** three hooks: `worktree-port-namespace.sh`, `context-cap-warn.sh`, `freeze-write-scope.sh`
- **Modified** `/create-prd` (vision-driven mode + office-hours forcing-questions gate)
- **Modified** `/review-team` (added behavioral evaluator using chrome-devtools MCP)
- **Modified** `/research` (jury-on-demand: 1-3 judges by query type; `--judges all` for legacy 3-LLM behavior)
- **Renamed** project to `logic-loom` and folder to `.logic-loom/`
- **Removed** `mcp-servers/sdd-marketplace/` (defer to Anthropic Marketplace + Docker MCP Toolkit)
- **Removed** RL telemetry infrastructure (`.logic-loom/scripts/bash/rl/`, `src/sdd/feedback/`, `src/sdd/metrics/`, `rl_metrics` plugin fields)
- **Removed** five stale internal scripts (no user-facing impact)
- **Kept** all SDD-era user-facing tools as **legacy alternatives** (per v3 supplementary principle)

---

**Framework**: logic-loom v6.0.0 (brand: **LogicLoom**)
**Constitution**: v3.0.0 (16 Principles — UNCHANGED)
**Architecture**: Vision/PRD/Plan/Swarm primary; SDD waterfall legacy
**Last Updated**: 2026-05-27
