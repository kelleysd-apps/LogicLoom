# Core Context Module
<!-- Auto-generated from CLAUDE.md -->
<!-- Module: Essential instructions, constitutional principles, project overview -->

## Governance Is Hook-Enforced (No Recited Ceremony)

Constitutional governance is the **core** of LogicLoom and is enforced
automatically by hooks — there is no manual pre-flight recitation or compliance
summary to perform on each message. Domain detection, delegation
recommendations, and git-safety gating all run via the `UserPromptSubmit`
preflight hook and the pre-command dangerous-command guard.

### Governance modes

Governance verbosity is controlled by `LOOM_GOVERNANCE_MODE` in
`.logic-loom/config/governance.conf`:

| Mode | Behavior |
|------|----------|
| **lean** (default) | Hooks enforce silently; delegation/domain hints injected without ceremony |
| **strict** | Hooks add verbose compliance reporting and stricter gating prompts |

You do not need to recite a protocol or print a compliance block. Follow the
constitution; the hooks handle enforcement.

---

## Workflow Packs (Interchangeable)

Governance is the core. The development workflows sit on top of it as
**interchangeable packs** — none is primary or legacy. Choose the pack that
matches the problem shape:

| Pack | Use when |
|------|----------|
| **Vision / Swarm** (`features/<name>/`) | Exploratory or novel work; unclear scope |
| **SDD waterfall** (`specs/###-name/`) | Well-understood feature with stable requirements |

All packs share the same constitutional governance, plugin chassis, and
distribution machinery.

---

## Constitutional Foundation

**The constitution at `.logic-loom/memory/constitution.md` is the SINGLE SOURCE OF TRUTH.**

The constitution (v3.2.0) contains **16 enforceable principles**:
- **3 Immutable Principles** (I-III): Library-First, Test-First, Contract-First
- **6 Quality & Safety Principles** (IV-IX): Idempotency, Progressive Enhancement, Git Approval, Observability, Documentation Sync, Dependency Management
- **7 Workflow & Delegation Principles** (X-XVI): Delegation & Context Isolation, Input Validation, Design System, Access Control, AI Model Selection, File Organization, Plugin-First Architecture

The constitution governs:
- Core development principles and rules
- Workflow requirements and gates
- Quality standards and constraints
- All architectural decisions
- Delegation and context-isolation protocol

### Critical Principles (Memorize These)

| Principle | Name | Key Rule |
|-----------|------|----------|
| **II** | Test-First | Write tests BEFORE implementation |
| **VI** | Git Approval | NEVER auto-commit, ALWAYS ask user |
| **X** | Delegation & Context Isolation | Specialized work → specialists or `/swarm`; isolate worker context |

### Delegation (Hook-Assisted)

Principle X is enforced by the preflight hook, not a recited protocol. The hook
scans each request for domain trigger keywords and surfaces a delegation
recommendation. In practice:

- **0 domains** → execute directly
- **1 domain** → load the domain brief (`get_domain_brief <domain>`) or use `/swarm explore`
- **2+ domains** → `/swarm` or a team-orchestration command

## Development Principles

ALL development principles are defined in `.logic-loom/memory/constitution.md`.

The constitution supersedes all other practices and must be consulted for:
- Architecture decisions and patterns
- Testing requirements and gates
- Quality standards and constraints
- Workflow requirements
- Any exceptions or complexity justifications

Never proceed with implementation without verifying constitutional compliance.

**Note**: When updating the constitution, the `.logic-loom/memory/constitution_update_checklist.md` MUST be followed to ensure all dependent documents are updated.

---

## Context Loading

This is a modular context system. Additional context modules available:

| Module | Description | Load When |
|--------|-------------|-----------|
| **agents** | Agent registry, delegation protocol | Agent/multi-domain tasks |
| **skills** | Skill definitions and triggers | Workflow commands, procedures |
| **workflows** | SDD commands, feature workflow | Feature development |
| **governance** | Git operations, compliance | Commits, quality gates |

Load additional modules using:
```bash
./.logic-loom/scripts/bash/load-context.sh load <module>
```

Or analyze request automatically:
```bash
./.logic-loom/scripts/bash/load-context.sh analyze "<request text>"
```

---

**Module Version**: 2.0.0
**Constitutional Authority**: All 16 Principles (I-XVI)
**Source Documents**:
- `.logic-loom/memory/constitution.md` (v3.2.0)
- CLAUDE.md core sections
- `.logic-loom/config/governance.conf` (LOOM_GOVERNANCE_MODE)
- `.claude/hooks/` (preflight + dangerous-command guard)
