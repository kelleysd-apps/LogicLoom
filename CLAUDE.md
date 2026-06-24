# CLAUDE.md — LogicLoom

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Project (technical)**: `logic-loom`
**Brand**: **LogicLoom**
**Framework folder**: `.logic-loom/`
**Per-feature folder**: `features/<feature-name>/`

LogicLoom is a **Claude-Code-native, governed multi-agent harness** for building
software. Its durable core is **constitutional governance** (hook-enforced). On
top of that core sit **interchangeable workflow packs** — none privileged. Pick
the pack that matches the problem.

---

## Core + Workflow Packs (READ FIRST)

Governance is the **core**; everything else is an **optional workflow pack**.
The packs share the same constitution, plugin chassis, and distribution
machinery. Pick by problem shape — there is no "primary" or "legacy" path:

| Workflow pack | Loop | Best for |
|---|---|---|
| **Swarm** (vision/PRD/plan/swarm) | `vision.md` → `/swarm explore` + `/research` → `/create-prd` → plan mode → `/plan-review` → `/swarm implement` → `/review-team` → `/git-push` → `/retro` | Exploratory or novel work; unclear scope (`features/<name>/`) |
| **SDD waterfall** | `/specification` → `/build-team` / `/fullstack-team` → `/finalize` | Well-understood feature with stable requirements (`specs/###-name/`) |
| _(none)_ | direct execution | Quick fix, no significant unknowns |

The swarm pack's `vision.md` and `/plan-review` are **gates within that pack**
(they prevent broad-spec cascade and worker collisions) — not framework-level
requirements.

### Model & provider boundary

The orchestration + governance runtime is **Claude-Code-native and assumes
Anthropic flagship (Opus-class) models**. Model-tier agnosticism is supported
within Anthropic via role→model config (`.logic-loom/config/models.conf`).
Cross-provider models (OpenAI/Gemini/Mistral) are supported **only at the
delegated research/verification layer** — never for orchestration. Two consumers:
`/research` (multi-LLM tribunal) and `/cross-check` (the governed cross-provider
adversarial reviewer, also the key-gated slot in `/review-team` and
`/plan-review`). In both, the external model is held strictly **advisory +
read-only** — it returns findings; the governed Claude agent triages and decides.
It never writes repo source, runs git, or makes a control-flow decision.

**Portability (superseded stance).** The prior absolute "not a provider-portable
orchestration runtime" is now scoped: the **policy** layer travels to any host —
the constitution, the operating principles, and the Cross-Check Disposition are
provider-neutral, model-followed rules (neutral source: **AGENTS.md Tier 1**).
**Enforcement does not travel**: the hook floor (git-approval gate,
governance-file protection, subagent-git-deny, freeze-write-scope) is the Claude
Code **reference adapter**; on other hosts those guarantees are *followed-only*
until a conformant adapter is supplied. Identity is unchanged — LogicLoom remains
a Claude-Code-native orchestrator whose *policy* is now portable. See the honest
enforced-vs-followed matrix in `.docs/architecture/governance-threat-model.md`.

### Orchestration primitives (ride native; don't reimplement)

LogicLoom is a **governance + dev layer on Claude Code's native orchestration**,
not an orchestration engine. Spawn workers with the **Task tool** (parallel =
multiple Task calls in one message); use **`/workflow`** for deterministic
fan-out (loops, pipelines, adversarial verify) and **`/loop`** for recurring/
self-paced cadence. There is no custom runner (no process manager, session
multiplexer, or shared swarm-state file). What LogicLoom adds on top: hook-enforced
governance, the plan-as-DAG **freeze** file-ownership, the behavioral evaluator,
domain briefs, jury-on-demand `/research`, and memory.

---

## Governance

Governance is the durable core of this harness. **Enforcement is hook-side and
model-independent** — you do not need to recite a compliance checklist on every
message. The hooks are the floor; the policies below are the standing intent.

### Hook enforcement (active regardless of model)

| Hook | Enforces |
|---|---|
| `subagent-git-guard.sh` (PreToolUse · Bash) | **Principle VI** — denies ANY git command from a subagent (detected via `agent_id` in the hook payload). Git is main-agent + direct-user-request only. |
| `git-safety-gate.sh` (PreToolUse · Bash) | **Principle VI** — main-agent git mutations force an approval prompt (`permissionDecision: ask`). No autonomous git. |
| `protect-governance-files.sh` (PreToolUse · Write/Edit + Bash) | Edits to the governance surface (`.claude/hooks/`, `settings.json`, `constitution.md`, `governance.conf`, `loom-governance/hooks/`) → subagent **deny** / main **ask**. The model can't silently soften its own rules. |
| `guard-dangerous-commands.sh` (PreToolUse · Bash) | Policy-based dangerous-command blocking (bash 4+; fails open otherwise) |
| `freeze-write-scope.sh` (PreToolUse · Write/Edit) | Plan-as-DAG file ownership during `/swarm implement`; paths canonicalized (`realpath`) so `..`/symlink can't escape `owns:` scope. |
| `governance-preflight.sh` (UserPromptSubmit) | Injects domain guidance + memory context (and, in strict mode, the pre-flight recitation) |

Hooks are a **deterministic floor, not a sandbox.** They make the high-impact
failures hard (autonomous git, a subagent's `git clean`, the model rewriting its
own hooks, writing outside an owned scope) — but a string gate cannot see
interpreter/`eval` indirection or every Bash write path. Treat governance as
defense-in-depth; the known residual bypasses are documented in
`.docs/architecture/governance-threat-model.md`.

### Standing policies (respect without being asked)

- **VI Git Approval** — never run git mutations autonomously; the hook will gate them, but don't try to route around it.
- **II Test-First** — TDD by default; tests before implementation.
- **I Library-First / III Contract-First** — preferences for how features are shaped.
- **X Delegation & Context Isolation** — delegate specialized or parallel work to subagents/swarm for *isolation and parallelism*, not because the base model lacks capability.
- Cross-Check Disposition — when output correctness materially matters AND the ask invites scrutiny (double-check, cross-check, red-team, peer-review, second opinion, sanity-check, 'are you sure', 'poke holes', 'prove me wrong'), default to a decorrelated second look from a DIFFERENT-PROVIDER model rather than reviewing your own output in-lineage — a same-lineage self-review shares your blind spots. HOST-GATED: On the Claude Code host, this is surfaced as /cross-check (or the cross-provider slot in /review-team / --adversary on /plan-review), which hands a bounded artifact to a non-Claude model; advisory, read-only, key-gated and fail-open. On any host where you are the ONLY model reachable, a self-review is NOT decorrelation — say so plainly, do not label it a cross-check, and proceed. It never blocks and never touches git. Skip it for trivial asks. (Neutral source: AGENTS.md Tier 1; the Claude Code preflight hook also nudges toward `/cross-check` on verification-shaped asks.)

### Governance modes (capability-gated assist)

Set via `LOOM_GOVERNANCE_MODE` or `.logic-loom/config/governance.conf`:

- **`lean`** (default) — hooks enforce; no per-message recitation. Correct for
  flagship Opus-class models.
- **`strict`** — hooks enforce **and** the 4-step pre-flight is re-injected each
  message. The graceful-degradation path for weaker / non-flagship models.

Hook enforcement is identical in both modes; only the model-side assist differs.

---

## Swarm Workflow Pack

One of the interchangeable workflow packs (not privileged). The swarm loop for
exploratory feature work:

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
/code-review                      (external Claude Code command — PR-level review)
    ↓
/retro <feature>                  (sprint retrospective → memory write)
    ↓
[ExitWorktree]
```

Steps are skippable when justified. Within this pack, `vision.md` and
`/plan-review` are **pack-internal gates** — they prevent broad-spec cascade and
worker collisions. They gate the swarm workflow only, not the harness.

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

## Quick Command Reference — Swarm pack

| Command | Purpose | Plugin |
|---|---|---|
| **`/swarm explore <topic>`** | Read-only parallel investigators; writes to `features/<x>/exploration/` | loom-orchestrator |
| **`/swarm implement [sprint]`** | DAG-driven sprint execution; freeze hook enforces ownership | loom-orchestrator |
| **`/swarm <freeform>`** | Generic multi-agent swarm | loom-orchestrator |
| **`/research <question>`** | Jury-on-demand tribunal (1-3 judges by query type; `--judges all` for full 3-LLM) | loom-orchestrator |
| **`/create-prd <feature>`** | Auto-detects vision-driven vs blank-slate mode; office-hours forcing-questions gate | loom-creation |
| **`/plan-review <feature>`** | CEO + Eng review of plan.md before `/swarm implement` (two internal reviewers) | loom-orchestrator |
| **`/review-team`** | Parallel reviewers: security + quality + performance + behavioral evaluator (chrome-devtools MCP) + key-gated cross-provider adversary | loom-orchestrator |
| **`/cross-check [target]`** | Governed cross-provider adversarial review (Codex/GPT default; Gemini pluggable). Non-Claude lineage tears apart a diff/plan/claims/file scope; advisory + read-only, never git. Canonical path for all cross-check reviews | loom-orchestrator |
| **`/git-push`** | Commit + push + PR creation with explicit user approval at each gate | loom-git |
| **`/retro <feature>`** | Sprint retrospective; writes action items to loom-memory | loom-orchestrator |

---

## Quick Command Reference — SDD waterfall pack + tooling

| Command | Purpose | Plugin |
|---|---|---|
| `/specification` | Unified SDD waterfall — spec, plan, tasks in one command | sdd-specification |
| `/build-team` | Sequential architect → implementor → reviewer | loom-orchestrator |
| `/fullstack-team` | Parallel frontend + backend + database workers (domain briefs) | loom-orchestrator |
| `/finalize` | Pre-commit compliance validation (no git execution) | loom-git |
| `/create-agent` | Create specialized subagent | loom-creation |
| `/create-plugin` | Create new LogicLoom plugin | loom-creation |
| `/create-skill` | Create new skill | loom-creation |
| `/update-framework` | Check and apply upstream enhancements | loom-maintenance |
| `/initialize-project` | Post-PRD project customization | loom-maintenance |

Domain detection (preflight hook): keywords map to a **domain brief** in the
governance-core registry, injected into swarm/team workers via `get_domain_brief`
(see `plugins/loom-governance/domain-briefs/`). The seven domains —
frontend, backend, database, testing, security, performance, devops — are briefs,
not separate plugins.

For new work, prefer `/swarm explore` over individual specialist routing.

---

## Constitution Principles

**ALWAYS read `.logic-loom/memory/constitution.md` BEFORE starting any work.**

The constitution (v3.2.0) contains **16 enforceable principles**. Enforcement is
hook-side (see the **Governance** section above); the list below is a quick map.

- **3 Immutable** (I-III): Library-First, Test-First, Contract-First
- **6 Quality & Safety** (IV-IX): Idempotency, Progressive Enhancement, Git Approval, Observability, Documentation Sync, Dependency Management
- **7 Workflow & Delegation** (X-XVI): Agent Delegation, Input Validation, Design System, Access Control, AI Model Selection, File Organization, Plugin-First Architecture

### Critical Principles Quick Reference

| Principle | Requirement | Consequence |
|---|---|---|
| **II (Test-First)** | TDD mandatory, >80% coverage | IMMUTABLE — blocks merge |
| **VI (Git Approval)** | NO autonomous git operations | CRITICAL — hook-gated (`git-safety-gate.sh` / `subagent-git-guard.sh`) |
| **X (Agent Delegation)** | Specialized work → specialists or `/swarm` | CRITICAL — delegate or violate |
| **XVI (Plugin-First)** | Capabilities as installable plugins | CRITICAL — all new features as plugins |

(Git operations under Principle VI are detailed in the **Governance** section above.)

---

## LogicLoom Hooks

Full hook inventory under `.claude/hooks/` (see the **Governance** section for
how each maps to a principle):

| Hook | Purpose |
|---|---|
| `subagent-git-guard.sh` | Denies ANY git command from a subagent (Principle VI). Git is main-agent + direct-user-request only |
| `git-safety-gate.sh` | Forces an approval prompt on main-agent git mutations (Principle VI). No autonomous git |
| `guard-dangerous-commands.sh` | Policy-based dangerous-command blocking (bash 4+; fails open otherwise) |
| `governance-preflight.sh` | Injects domain briefs + memory context on `UserPromptSubmit` (and, in strict mode, the pre-flight recitation) |
| `worktree-port-namespace.sh` | Computes per-worktree port/db namespaces (`PORT_BASE`, `DB_PORT`) so parallel worktrees don't collide |
| `context-cap-warn.sh` | At 800K of 1M default context, injects reset reminder + handoff-artifact prompt to avoid "context anxiety" wrap-up bias |
| `freeze-write-scope.sh` | Hook-level enforcement of plan-as-DAG file ownership: rejects writes outside the active task's declared `owns:` scope; default-allows when no DAG context |

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

| Plugin | Layer | Notes |
|---|---|---|
| `loom-governance` | governance core (protected) | Constitutional enforcement, hooks, domain-brief registry |
| `loom-memory` | core | Memory context injection, `/retro` writes |
| `loom-orchestrator-hook` | core | Preflight domain detection + worker-brief recommendations |
| `loom-creation` | core tooling | `/create-prd`, `/create-skill`, `/create-agent`, `/create-plugin` |
| `loom-git` | core tooling | `/git-push`, `/finalize` |
| `loom-maintenance` | core tooling | `/update-framework`, `/initialize-project` |
| `loom-orchestrator` | swarm pack | `/swarm` (explore/implement/freeform), `/research`, `/cross-check`, `/plan-review`, `/review-team`, `/retro`, `/build-team`, `/fullstack-team` |
| `sdd-specification` | SDD pack | `/specification` unified waterfall (keeps `sdd-` — it *is* the SDD workflow) |

Domain expertise is no longer a plugin: the 7 domains (frontend/backend/database/
testing/security/performance/devops) are **briefs** in
`loom-governance/domain-briefs/`, injected via `get_domain_brief`.

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
VISION.md                              # Foundational product north-star (living; peer to the constitution)

.logic-loom/
  memory/
    constitution.md                    # 16 principles (v3.2.0)
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

features/                              # Swarm pack: per-feature workspaces (vision/PRD/plan/sprints/retro)
specs/                                 # SDD pack: waterfall specs

.docs/
  architecture/loom-architecture.md    # Full architectural reference (LogicLoom shape)
  policies/
```

### Workflow scripts

| Script | Purpose |
|---|---|
| `common.sh` | Shared functions + git approval |
| `constitutional-check.sh` | 16-principle compliance validator |
| `sync-plugin-commands.sh` | Plugin → `.claude/commands/` bridge |
| `load-context.sh` | Modular context loading |

Pre-commit compliance check:
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
| **Project (swarm pack)** | `features/<name>/plan.md` (DAG) and `features/<name>/sprints/NN-name/` | Sprint plan + per-sprint worker outputs |
| **Project (SDD pack)** | `specs/###-feature/tasks.md` | SDD waterfall task checklist |
| **Session** | TaskCreate/TaskUpdate tools | Active work tracking |

### Task tool rules (CRITICAL)

1. **ONE task `in_progress`** at any time — never multiple
2. **Mark `completed` IMMEDIATELY** via TaskUpdate — don't batch completions
3. **Use TaskCreate for 3+ step tasks** — skip for trivial single-step work
4. **Keep focused** — 3-10 items max

**Policy**: `.docs/policies/todo-architecture-policy.md`

---

## AI Model Selection (Principle XIV)

Agents/commands select a tier via frontmatter keywords
(`opus`/`sonnet`/`haiku`/`inherit`), never pinned version strings. The
**documented** role→tier convention and current flagship live in
`.logic-loom/config/models.conf` (a reference table, not a runtime resolver —
no consumer parses it yet). Default flagship: **Opus 4.8**.

| Tier | Use Case |
|---|---|
| **opus** (Opus 4.8) | Default for agents; architecture, security, complex reasoning |
| **sonnet** (Sonnet 4.6) | Cost optimization; high-volume tasks |
| **haiku** (Haiku) | Quick lookups; formatting; file ops |

**Model IDs**: `claude-opus-4-8`, `claude-sonnet-4-6`, `claude-haiku-4-5-20251001`

> Orchestration is Claude-Code-native (Anthropic only). Cross-provider models
> (OpenAI/Gemini) are used solely at the delegated verification layer —
> `/research` and `/cross-check` — held advisory and read-only.

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
- `VISION.md` — **foundational** product north-star (living); the *what/why* the constitution defers to (peer to the constitution, distinct from per-feature `features/<name>/vision.md`)
- `.docs/architecture/loom-architecture.md` — full architectural reference (LogicLoom shape)
- `.docs/architecture/evaluator-protocol.md` — `/review-team` evaluator contract
- `.docs/architecture/freeze-scope-protocol.md` — `/freeze` hook contract
- `.logic-loom/memory/constitution.md` — 16 constitutional principles (v3.2.0)
- `.logic-loom/config/models.conf` — documented role→tier convention + current flagship
- `.logic-loom/config/governance.conf` — governance mode (lean/strict)
- `features/README.md` — per-feature folder convention
- `plugins/*/skills/` — skill documentation (Plugin-First Architecture)
- `AGENTS.md` — agent registry (tandem file — must update with CLAUDE.md)

---


**Framework**: logic-loom v6.3.0 (brand: **LogicLoom**)
**Constitution**: v3.2.0 (16 Principles)
**Architecture**: Governance core + interchangeable workflow packs (swarm / SDD waterfall)
**Runtime**: Claude-Code-native; Anthropic flagship (Opus-class) models
