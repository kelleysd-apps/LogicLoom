# LogicLoom Constitution v3.1.0

**Status**: RATIFIED
**Ratified**: 2026-01-13 (v3.0.0) · **Amended**: 2026-05-28 (v3.1.0)
**Effective Date**: 2026-01-13

---

## Overview

This is the LogicLoom Constitution with 16 enforceable principles, including
Plugin-First Architecture (Principle XVI). The constitution is the **durable
core** of the harness: it governs all agents, skills, and workflows regardless of
which workflow pack (SDD waterfall, vision/swarm, dev-loop, …) is in use. No
principle privileges a particular workflow.

## Changes Summary (v3.1.0)

| Section | Change | Rationale |
|---------|--------|-----------|
| Identity | "SDD Framework" → **LogicLoom**; workflow-agnostic framing | Governance is the core; workflows are interchangeable packs |
| Principle X | "Skills-First / FR-707" → **Delegation & Context Isolation** | Enforcement is hook-side; delegation is for isolation/parallelism, not model-capability gaps |
| Principle XIV | Default model → **Opus 4.8** (was 4.6) | Current flagship; model selection is config-driven (`models.conf`) |
| Principle XVI | Dropped the `rl_metrics` manifest mandate | RL telemetry was removed in the LogicLoom migration |
| Governance | Hook-enforced, capability-gated (`lean`/`strict` modes) | Model-independent enforcement; no mandatory per-message recitation |

---

## Constitutional Principles (16 Principles)

### Preamble

This Constitution establishes the governance framework for **LogicLoom**, a
multi-agent harness for building software with Claude Code. Governance is the
core; workflow packs plug into it. All agents, skills, and workflows operating
within this framework MUST adhere to these principles.

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

**Status**: REWRITTEN (v3.1.0)

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

- `git-safety-gate.sh` (PreToolUse · Bash) — Principle VI: git mutations force
  an approval prompt.
- `guard-dangerous-commands.sh` (PreToolUse · Bash) — policy-based blocking.
- `freeze-write-scope.sh` (PreToolUse · Write/Edit) — plan-as-DAG ownership.
- `governance-preflight.sh` (UserPromptSubmit) — domain guidance + memory; in
  `strict` mode also injects the optional 4-step pre-flight.

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

**Status**: MODIFIED (v3.1.0)

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

**Status**: NEW (v3.0.0)

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
| **Workflow pack** | `sdd-specification` (SDD), `loom-orchestrator` (swarm), `loom-dev-loop` | ✅ Yes |
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

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-01-01 | Initial constitution |
| 1.5.0 | 2025-09-01 | Added principles XI-XIV |
| 1.6.0 | 2025-11-07 | Added principle XV |
| 2.0.0 | 2026-01-13 | Skills-first Principle X rewrite (ratified) |
| 3.0.0 | 2026-01-15 | Added Principle XVI: Plugin-First Architecture |
| 3.1.0 | 2026-05-28 | LogicLoom identity; Principle X → Delegation & Context Isolation (hook-enforced governance, lean/strict modes); Opus 4.8 + config-driven model selection; dropped `rl_metrics` mandate; workflow-agnostic framing |

---

*v3.1.0 — LogicLoom Constitution. Governance is the durable core; SDD waterfall,
vision/swarm, and dev-loop are interchangeable workflow packs.*
