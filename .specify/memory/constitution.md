# SDD Framework Constitution v3.0.0

**Status**: RATIFIED
**Feature**: 004-plugin-first-architecture
**Ratified**: 2026-01-13
**Effective Date**: 2026-01-13

---

## Overview

This is the ratified Constitution v3.0.0 with 16 enforceable principles including Plugin-First Architecture (Principle XVI). The constitution governs all agents, skills, and workflows within the SDD Agentic Framework.

## Changes Summary

| Section | v2.0.0 | v3.0.0 | Rationale |
|---------|--------|--------|-----------|
| Principle X | Skills-First Delegation Protocol | *(unchanged)* | Skills are primary orchestration |
| **Principle XVI** | *(new)* | **Plugin-First Architecture** | Modular, installable capabilities |
| Architecture | Monolithic .claude/ | Plugin-based plugins/ | Hot-swap, RL metrics, governance |
| Routing | Plugin manifests (plugins/*/plugin.json) | Plugin auto-discovery | Eliminate centralized manifest |

---

## Constitutional Principles (16 Principles)

### Preamble

This Constitution establishes the governance framework for the Specification-Driven Development (SDD) Agentic Framework. All agents, skills, and workflows operating within this framework MUST adhere to these principles.

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

### Principle X: Skills-First Delegation Protocol

**Status**: MODIFIED (v2.0.0)**

```
OLD (v1.6.0): Specialized work delegated to specialized AGENTS
NEW (v2.0.0): Specialized work delegated to specialized SKILLS which invoke agents
```

#### Work Session Initiation Protocol (MANDATORY for EVERY task)

**Step 1: FR-707 COMPLIANCE CHECK** (First action)
- Activate `validation/message-preflight` skill
- Log compliance check timestamp
- Cannot be bypassed

**Step 2: DOMAIN ANALYSIS**
- Scan message for domain trigger keywords
- Identify applicable skill(s)
- Use RL selection weights for candidates

**Step 3: SKILL DELEGATION**
```
IF 0 domains detected:
  -> May execute directly

IF 1 domain detected:
  -> MUST activate the appropriate domain skill
  -> Skill determines if agent invocation needed

IF 2+ domains detected:
  -> MUST activate orchestration/multi-skill-workflow
  -> Orchestration skill coordinates domain skills
```

**Step 4: EXECUTION**
- Skill activates with progressive disclosure
- Skill invokes agent(s) with minimal context
- DS-STAR quality gates validate output
- RL metrics updated

#### Skills-First Flow

```
User Message
    |
    v
[FR-707] Compliance Check (MANDATORY FIRST)
    |
    v
Domain Analysis (Router)
    |
    v
RL-Enhanced Skill Selection
    |
    v
Skill Activation (Progressive Disclosure)
    |
    v
Agent Invocation (Minimal Context)
    |
    v
Verifier Validation
    |
    v
RL Feedback Loop
```

#### Violation Response

If skills-first pattern violated:
1. **STOP** current action
2. **LOG** violation
3. **CORRECT** by activating skill
4. **PROCEED** only via skill

#### Migration Period

During hybrid mode (Phase 1-2):
- Both patterns work
- Legacy emits deprecation warning
- Migration tracking enabled

After hybrid mode (Phase 3-4):
- Skills-first is default
- Legacy patterns blocked
- Full RL integration active

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

**Status**: UNCHANGED

Use Opus 4.6 by default (`claude-opus-4-6`). All agents use Opus for maximum capability.

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
    .claude-plugin/plugin.json   # Manifest (name, version, dependencies, rl_metrics)
    commands/                     # Slash commands (/specify, /debug, etc.)
    skills/                       # Skill definitions (SKILL.md)
    agents/                       # Agent definitions
    hooks/                        # Event hooks (UserPromptSubmit, PreToolUse, etc.)
    scripts/                      # Automation scripts
```

#### Requirements

1. **Manifest Required**: Every plugin MUST have a valid `.claude-plugin/plugin.json`
2. **Governance Dependency**: All plugins MUST declare `sdd-governance` as a dependency
3. **Protected Plugins**: `sdd-governance` is protected and cannot be disabled
4. **RL Metrics**: All plugins MUST include `rl_metrics` in their manifest
5. **Hot-Swap**: Plugins MUST support enable/disable without framework restart
6. **Portable Paths**: Use `${CLAUDE_PLUGIN_ROOT}` for cross-environment compatibility

#### Plugin Categories

| Category | Examples | Can Disable? |
|----------|----------|-------------|
| **Governance** | sdd-governance | ❌ Never |
| **Core** | sdd-specification, sdd-git, sdd-debug, sdd-creation | ⚠️ With warning |
| **Domain** | sdd-domain-frontend, sdd-domain-backend, etc. | ✅ Yes |
| **Orchestration** | sdd-orchestrator | ⚠️ With warning |
| **Community** | Third-party plugins | ✅ Yes |

---

## Amendment Process

### To Ratify v2.0.0

1. **Complete Phase 2** - Agent consolidation verified
2. **Validate RL benefit** - +15-25% skill selection accuracy
3. **Test hybrid mode** - 6+ months of successful operation
4. **User approval** - Framework users approve change
5. **Formal ratification** - Update version, deprecate legacy

### Rollback Conditions

Revert to v1.6.0 if:
- RL shows no improvement over baseline
- Skills-first pattern has critical bugs
- User satisfaction significantly decreases
- Migration proves too disruptive

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-01-01 | Initial constitution |
| 1.5.0 | 2025-09-01 | Added principles XI-XIV |
| 1.6.0 | 2025-11-07 | Added principle XV |
| 2.0.0 | 2026-01-13 | Skills-first Principle X rewrite (ratified) |
| 3.0.0 | 2026-01-15 | Added Principle XVI: Plugin-First Architecture |

---

*v3.0.0 ratified with Plugin-First Architecture (Principle XVI)*
*Spec 004: 13 plugins, 36 skills, 20 agents, 16 commands*
