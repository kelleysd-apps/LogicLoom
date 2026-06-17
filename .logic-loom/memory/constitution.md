# LogicLoom Constitution v3.2.0

**Status**: RATIFIED

---

## Overview

This is the LogicLoom Constitution with 16 enforceable principles, including
Plugin-First Architecture (Principle XVI). The constitution is the **durable
core** of the harness: it governs all agents, skills, and workflows regardless of
which workflow pack (SDD waterfall, vision/swarm, …) is in use. No
principle privileges a particular workflow.

---

## Constitutional Principles (16 Principles)

### Preamble

This Constitution establishes the governance framework for **LogicLoom**, a
multi-agent harness for building software with Claude Code. Governance is the
core; workflow packs plug into it. All agents, skills, and workflows operating
within this framework MUST adhere to these principles.

**Governance vs. direction.** This Constitution governs *how* work is done — the
safety, quality, and process floor that holds regardless of task. It does NOT set
product direction. For *what* the project is building and *why* — its priorities,
scope, and north-star for anything new-project-related — the authoritative source
is the project's foundational `VISION.md` at the repository root. Where this
Constitution is silent on direction, agents defer to `VISION.md`. Where the two
appear to conflict, governance (the floor) prevails on *how* and `VISION.md`
prevails on *what/why*. `VISION.md` is a living steering document; it is never
itself a governance authority and can never relax this floor.

---

## Immutable Principles (I-III)

These principles cannot be modified or overridden.

### Principle I: Library-First Architecture

**Status**: UNCHANGED

Every feature MUST begin as a standalone library before integration.

### Principle II: Test-First Development

**Status**: UNCHANGED

TDD is MANDATORY. Coverage minimum: 80%.

```
TDD Cycle: Write failing test -> Get approval -> Implement -> Refactor
```

### Principle III: Contract-First Design

**Status**: UNCHANGED

Define contracts BEFORE implementation.

---

## Quality & Safety Principles (IV-IX)

### Principle IV: Idempotent Operations

**Status**: UNCHANGED

All operations MUST be safely repeatable.

### Principle V: Progressive Enhancement

**Status**: UNCHANGED

Start simple, add complexity only when proven necessary.

### Principle VI: Git Operation Approval

**Status**: UNCHANGED - CRITICAL

```
CRITICAL: NO autonomous Git operations
ALL git commands require explicit user approval
```

### Principle VII: Observability

**Status**: UNCHANGED

Structured logging and metrics required.

### Principle VIII: Documentation Synchronization

**Status**: UNCHANGED

Documentation MUST stay synchronized with code.

### Principle IX: Dependency Management

**Status**: UNCHANGED

All dependencies explicitly declared and version-pinned.

---

## Workflow & Delegation Principles (X-XV)

### Principle X: Delegation & Context Isolation

**Status**: Current

Delegate specialized or parallel work to subagents/swarm **for context isolation
and parallelism** — not because the base model lacks capability. A flagship
model handles cross-domain reasoning in a single context; the reason to spawn
workers is to give each an isolated context window, enforce file-ownership
scopes, or run independent tasks concurrently.

#### Delegation heuristic

```
0 domains / trivial    -> execute directly
1 domain               -> a specialist skill OR /swarm explore
2+ domains / parallel  -> /swarm  OR  team orchestration
```

This is guidance, not a mandatory per-message ceremony. Governance is enforced
**hook-side** (see Governance, below), so there is no recitation requirement and
no skills-first gate to "violate."

#### Governance enforcement (model-independent)

Enforcement lives in hooks, not in model recitation:

- `subagent-git-guard.sh` (PreToolUse · Bash) — Principle VI: denies ALL git
  from subagents (`agent_id` present).
- `git-safety-gate.sh` (PreToolUse · Bash) — Principle VI: git mutations force
  an approval prompt.
- `protect-governance-files.sh` (PreToolUse · Write/Edit + Bash) — edits to the
  governance surface (hooks, settings, this constitution, governance.conf) are
  subagent-`deny` / main-`ask`, so the model cannot soften its own rules.
- `guard-dangerous-commands.sh` (PreToolUse · Bash) — policy-based blocking.
- `freeze-write-scope.sh` (PreToolUse · Write/Edit) — plan-as-DAG ownership
  (paths canonicalized so `..`/symlink can't escape the owned scope).
- `governance-preflight.sh` (UserPromptSubmit) — domain guidance + memory; in
  `strict` mode also injects the optional 4-step pre-flight.

Hooks are a deterministic **floor, not a sandbox** — they do not see
interpreter/`eval` indirection or every Bash write path. Governance is
defense-in-depth; residual bypasses are tracked in
`.docs/architecture/governance-threat-model.md`.

#### Governance modes (capability-gated assist)

Configured via `LOOM_GOVERNANCE_MODE` / `.logic-loom/config/governance.conf`:

- **`lean`** (default) — hooks enforce; no per-message recitation. For flagship
  Opus-class models.
- **`strict`** — hooks enforce **and** the 4-step pre-flight is re-injected each
  message. For weaker / non-flagship models. Enforcement is identical in both
  modes; only the model-side assist differs.

### Principle XI: Input Validation & Output Sanitization

**Status**: UNCHANGED

All inputs validated, outputs sanitized.

### Principle XII: Design System Compliance

**Status**: UNCHANGED

UI components comply with project design system.

### Principle XIII: Feature Access Control

**Status**: UNCHANGED

Dual-layer enforcement (backend + frontend).

### Principle XIV: AI Model Selection

**Status**: Current

Default to the current flagship: **Opus 4.8** (`claude-opus-4-8`). Model choice is
**config-driven** via `.logic-loom/config/models.conf` (role → model), so swapping
tiers or future models is one config change rather than edits across agents.
Agent frontmatter uses tier keywords (`opus` / `sonnet` / `haiku` / `inherit`),
never pinned version strings. See the Model & Provider Boundary note in
`CLAUDE.md`: the orchestration runtime is Claude-Code-native (Anthropic models);
cross-provider models are supported only at the delegated research/verification
layer.

### Principle XV: File Organization

**Status**: UNCHANGED

Verify before creating files or folders.

---

### Principle XVI: Plugin-First Architecture

**Status**: Active

All framework capabilities MUST be organized as discrete, installable plugins.

```
Plugin Structure:
  plugins/<name>/
    .claude-plugin/plugin.json   # Manifest (name, version, dependencies)
    commands/                     # Slash commands (/specify, /debug, etc.)
    skills/                       # Skill definitions (SKILL.md)
    agents/                       # Agent definitions
    hooks/                        # Event hooks (UserPromptSubmit, PreToolUse, etc.)
    scripts/                      # Automation scripts
```

#### Requirements

1. **Manifest Required**: Every plugin MUST have a valid `.claude-plugin/plugin.json`
2. **Governance Dependency**: All plugins MUST declare the governance core plugin (`loom-governance`) as a dependency
3. **Protected Plugins**: `loom-governance` is protected and cannot be disabled
4. **Hot-Swap**: Plugins MUST support enable/disable without framework restart
5. **Portable Paths**: Use `${CLAUDE_PLUGIN_ROOT}` for cross-environment compatibility

#### Plugin Categories

| Category | Examples | Can Disable? |
|----------|----------|-------------|
| **Governance core** | `loom-governance` | ❌ Never (protected) |
| **Core tooling** | `loom-memory`, `loom-creation`, `loom-git`, `loom-maintenance` | ⚠️ With warning |
| **Workflow pack** | `sdd-specification` (SDD waterfall), `loom-orchestrator` (swarm) | ✅ Yes |
| **Community** | Third-party plugins | ✅ Yes |

No workflow pack is privileged; governance is the only protected layer.

---

## Amendment Process

1. **Propose** — describe the change and the principle(s) affected.
2. **Justify** — state which model-weakness assumption or policy need it
   addresses (governance is policy; capability scaffolding is removable).
3. **User approval** — the framework owner approves the amendment.
4. **Ratify** — bump the version, add a Version History row, update the Changes
   Summary, and sync tandem docs (`CLAUDE.md`, `AGENTS.md`).

Immutable principles (I–III) cannot be amended or overridden.

---


*LogicLoom Constitution v3.2.0. Governance is the durable core; workflow packs are interchangeable.*
