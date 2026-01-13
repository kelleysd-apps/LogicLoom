# SDD Framework Constitution v2.0.0 (DRAFT)

**Status**: DRAFT - Phase 3 Preparation
**Feature**: 002-skills-first-architecture
**Task**: T041-T045
**Effective Date**: TBD (Phase 4 Ratification)

---

## Overview

This is the draft Constitution v2.0.0 with Principle X rewritten for skills-first architecture. This document will be ratified in Phase 4 after successful validation of the skills-first approach during the 12-month hybrid mode period.

## Changes Summary

| Section | v1.6.0 | v2.0.0 | Rationale |
|---------|--------|--------|-----------|
| Principle X | Agent Delegation Protocol | **Skills-First Delegation Protocol** | Skills are primary orchestration |
| Title | Agent Delegation | Skill Delegation | Reflects new paradigm |
| Flow | User -> Agent | User -> Skill -> Agent | Skills orchestrate |
| Routing | Domain -> Agent | Domain -> Skill -> Agent | Skill determines agent |

---

## Constitutional Principles (15 Principles)

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

Use Opus by default. All agents use Opus for maximum capability.

### Principle XV: File Organization

**Status**: UNCHANGED

Verify before creating files or folders.

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
| 2.0.0-draft | 2026-01-13 | Skills-first Principle X rewrite |

---

*Draft prepared for Phase 3 constitutional amendment*
*Subject to ratification after successful hybrid mode validation*
