# Core Context Module
<!-- Auto-generated from CLAUDE.md - Skill-Based Delegation v5.0 + Plugin-First Architecture v4.1 -->
<!-- Module: Essential instructions, constitutional principles, project overview -->

## MANDATORY: Message Pre-Flight Compliance Check

**EVERY user message requires a 4-step compliance check BEFORE any action.**

This is enforced by the `message-preflight` skill at `plugins/sdd-governance/skills/message-preflight/SKILL.md`.

### The 4-Step Protocol (Execute on EVERY message)

```
STEP 1: CONSTITUTION ACKNOWLEDGMENT
       └─ Confirm awareness of 16 principles (I-XVI)
       └─ Key: II (Test-First), VI (Git Approval), X (Agent Delegation), XVI (Plugin-First)

STEP 2: DOMAIN ANALYSIS
       └─ Scan message for domain trigger keywords
       └─ Domains: frontend, backend, database, testing, security,
                   performance, devops, specification, planning, tasks

STEP 3: DELEGATION DECISION
       └─ 0 domains → may execute directly
       └─ 1 domain → MUST delegate to specialist agent
       └─ 2+ domains → MUST delegate to team-orchestration skill

STEP 4: EXECUTION AUTHORIZATION
       └─ Confirm all steps complete
       └─ Proceed with direct execution OR agent delegation
```

### Compliance Summary Format

After completing pre-flight, provide brief summary:

```
Constitutional Compliance Check:
- Domain(s): [none | single: <domain> | multi: <domains>]
- Delegation: [direct execution | <agent-name>]
- Git operations: [none planned | will request approval]
- Proceeding with: [action description]
```

### Violation Self-Correction

If pre-flight was skipped or violated:
1. **STOP** immediately
2. **ACKNOWLEDGE** the violation explicitly
3. **CORRECT** by running protocol now
4. **PROCEED** only after correction

---

## Constitutional Foundation

**The constitution at `.specify/memory/constitution.md` is the SINGLE SOURCE OF TRUTH.**

The constitution (v3.0.0) contains **16 enforceable principles**:
- **3 Immutable Principles** (I-III): Library-First, Test-First, Contract-First
- **6 Quality & Safety Principles** (IV-IX): Idempotency, Progressive Enhancement, Git Approval, Observability, Documentation Sync, Dependency Management
- **7 Workflow & Delegation Principles** (X-XVI): Agent Delegation, Input Validation, Design System, Access Control, AI Model Selection, File Organization, Plugin-First Architecture

The constitution governs:
- Core development principles and rules
- Workflow requirements and gates
- Quality standards and constraints
- All architectural decisions
- Agent delegation protocol

### Critical Principles (Memorize These)

| Principle | Name | Key Rule |
|-----------|------|----------|
| **II** | Test-First | Write tests BEFORE implementation |
| **VI** | Git Approval | NEVER auto-commit, ALWAYS ask user |
| **X** | Agent Delegation | Specialized work → specialized agents |

### Work Session Initiation Protocol (Constitutional Basis)

The 4-step pre-flight check implements Constitutional Principle X:

1. **READ CONSTITUTION** - First action, no exceptions
2. **ANALYZE TASK DOMAIN** - Identify trigger keywords
3. **DELEGATION DECISION** - Delegate if specialized work
4. **EXECUTION** - Execute directly or via specialized agent

No work should proceed without completing this protocol.

## Project Overview

**Project**: Kelley AI Consulting (kelleysd.com)
**Type**: Solo AI Consultancy Website
**Owner**: Brian Kelley

This project uses the SDD (Specification-Driven Development) framework to build a professional AI consultancy website. The site positions Brian Kelley as an enterprise AI strategy consultant, combining 15+ years of IT/Security leadership with M&A integration expertise.

### Key Documents

| Document | Path | Purpose |
|----------|------|---------|
| **PRD** | `.docs/prd/prd.md` | Single Source of Truth for all requirements |
| **Constitutional Customizations** | `.docs/project/constitutional-customizations.md` | Project-specific principle applications |
| **Design System** | `docs/design-system/design-system.md` | UI/UX standards and components |
| **Quick Reference** | `.docs/prd/PRD_QUICK_REFERENCE.md` | PRD summary and next steps |

### Target Audience

- **Primary**: Mid-market CTOs, PE Partners evaluating AI capabilities
- **Secondary**: Security VPs, Peer Consultants seeking collaboration

### Tech Stack

- **Frontend**: React 18, Vite, TailwindCSS 3.4, Radix UI, Framer Motion
- **Backend**: Express.js, TypeScript, Node.js
- **Database**: PostgreSQL via Drizzle ORM (Supabase)
- **Auth**: JWT + bcrypt, session-based
- **Hosting**: Vercel

### Vercel Configuration (CRITICAL)

**Project Name**: `website` (NOT "kelleysd.com")

The correct Vercel project configuration is:
- **Project Name**: `website`
- **Project ID**: `prj_gYdedE5dz4XVaAiTArjnu9kpDRPH`
- **Org ID**: `team_Ns7A2cvWqvSkQ4cG6x43wWbM`

**Location**: `.vercel/project.json` (gitignored, must be configured locally)

**IMPORTANT**: If `.vercel/project.json` shows `"projectName":"kelleysd.com"`, it's WRONG. Always verify it says `"projectName":"website"` before deploying.

### Success Metrics

- 10 qualified leads/quarter within 6 months
- 2,000 visitors/month by month 6
- 500 newsletter subscribers
- 5% consultation booking rate

### MVP Features (Month 1)

1. Home page with value proposition
2. About page (Brian's expertise)
3. Services page (4 offerings)
4. Consultation booking system
5. Contact forms
6. Newsletter signup
7. Blog platform foundation
8. Mobile-responsive design
9. Analytics (GA4)

---

## Development Principles

ALL development principles are defined in `.specify/memory/constitution.md`.

The constitution supersedes all other practices and must be consulted for:
- Architecture decisions and patterns
- Testing requirements and gates
- Quality standards and constraints
- Workflow requirements
- Any exceptions or complexity justifications

Never proceed with implementation without verifying constitutional compliance.

**Note**: When updating the constitution, the `.specify/memory/constitution_update_checklist.md` MUST be followed to ensure all dependent documents are updated.

---

## Context Loading (NEW - Sprint 3)

This is a modular context system. Additional context modules available:

| Module | Description | Load When |
|--------|-------------|-----------|
| **agents** | Agent registry, delegation protocol | Agent/multi-domain tasks |
| **skills** | Skill definitions and triggers | Workflow commands, procedures |
| **workflows** | SDD commands, feature workflow | Feature development |
| **governance** | Git operations, compliance | Commits, quality gates |

Load additional modules using:
```bash
./.specify/scripts/bash/load-context.sh load <module>
```

Or analyze request automatically:
```bash
./.specify/scripts/bash/load-context.sh analyze "<request text>"
```

---

**Module Version**: 2.0.0
**Created**: 2026-01-09 (Sprint 3 Task T028)
**Last Updated**: 2026-02-07
**Constitutional Authority**: All 16 Principles (I-XVI)
**Source Documents**:
- `.specify/memory/constitution.md` (v3.0.0)
- CLAUDE.md core sections
- `plugins/sdd-governance/skills/message-preflight/SKILL.md`
