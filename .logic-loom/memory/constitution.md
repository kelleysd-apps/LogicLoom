# LogicLoom Constitution v3.3.0

**Status**: RATIFIED
**Ratified**: 2026-01-13 (v3.0.0) · **Amended**: 2026-05-28 (v3.1.0) · 2026-06-15 (v3.2.0) · 2026-08-17 (v3.3.0)
**Effective Date**: 2026-01-13

---

## Overview

This is the LogicLoom Constitution with 16 enforceable principles, including
Plugin-First Architecture (Principle XVI). The constitution is the **durable
core** of the harness: it governs all agents, skills, and workflows regardless of
which workflow pack (SDD waterfall, vision/swarm, …) is in use. No
principle privileges a particular workflow.

## Changes Summary (v3.3.0)

| Section | Change | Rationale |
|---------|--------|-----------|
| Project Amendments | Added a **fork extension point** — named mandates in a separate, fork-owned `.logic-loom/memory/amendments.md` | A fork with project-specific mandates previously had to edit ratified principle bodies in place, which then conflicted on every `/update-framework`. The mechanism is intended to be additive only, adjudicated toward the floor by explicit precedence rules — not guaranteed by the mandate grammar, whose `Rule` field is unrestricted natural language. It is model-followed policy: no loader, no validator, no enforcement. No principle body, numbering, immutability marker, or enforcement claim changed |

## Changes Summary (v3.2.0)

| Section | Change | Rationale |
|---------|--------|-----------|
| Preamble | Added **Governance vs. direction** clause deferring product direction to root `VISION.md` | The constitution governs *how* (the floor); the project's foundational `VISION.md` is the authority for *what/why*. No principle added — numbering stable |

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

**Status**: MODIFIED (v3.1.0)

Default to the current flagship: **Opus 4.8** (`claude-opus-4-8`). Model choice is
**config-driven** via `.logic-loom/config/models.conf` (role → model), so swapping
tiers or future models is one config change rather than edits across agents.
Agent frontmatter uses tier keywords (`opus` / `sonnet` / `haiku` / `inherit`),
never pinned version strings. See the Model & Provider Boundary note in
`CLAUDE.md`: the orchestration runtime is Claude-Code-native (Anthropic models);
cross-provider models are supported only at the delegated research/verification
layer.

**Whose models this governs.** This principle constrains **the harness's own
orchestration and governance runtime** — the agents, commands, and workers
LogicLoom itself dispatches. It says nothing about what models the project you
are BUILDING may call. An application that legitimately calls OpenAI, Gemini,
Mistral, or a local model is fully compliant; its provider choices are a product
decision this constitution does not reach.

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
    commands/                     # Slash commands (/specification, /swarm, etc.)
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

The Amendment Process above governs changes to **this file**, which is upstream
core. A fork that needs its own mandates does not use it — see Project
Amendments, below.

---

## Project Amendments (the fork extension point)

A fork MAY add project-specific mandates **without editing this Constitution**.
Amendments live in a separate, fork-owned file:

```
.logic-loom/memory/amendments.md
```

Seeded from `.logic-loom/templates/amendments-template.md`. Upstream never ships
`amendments.md`, so `/update-framework` has no upstream counterpart to propose
against it: a fork's mandates survive every framework update, and this
Constitution stays byte-identical to upstream instead of becoming a permanent
`conflict-review` file. That is the reason the extension point is a separate file
rather than in-line project markers.

### What this mechanism is not: there is no loader (settled, not pending)

Read this before relying on a mandate. `amendments.md` is a **convention, not a
runtime** — and that is a **decision, not an unfinished task**. Wiring
`amendments.md` into `governance-preflight.sh` (or any other loader) was
considered and **declined** (2026-08-24); there is no loader on the roadmap, and
a reader should not wait for one. The rationale: a loader would make mandates
*look* enforced without making them enforced — the hook floor still would not
consult a mandate, so the only thing gained is a stronger impression of
enforcement than the mechanism can support, which is exactly the phantom-gate
failure this document exists to avoid. Mandates are policy; policy is followed,
and the floor is what is enforced.

Exactly what a fork gets: a file upstream never overwrites, a grammar for named
mandates, and the composition/precedence rules below — all binding on any agent
that reads them. Exactly what a fork does **not** get: any injection, any
validation, any warning, and any change in hook behaviour. Concretely:

- **No loader.** Nothing injects `amendments.md` into any agent's context. No
  hook, no preflight, no context module reads it. Mandates are honoured only
  because `CLAUDE.md` and `AGENTS.md` instruct agents to read the file — and only
  by agents that actually do.
- **No validator.** Nothing checks that a mandate is well-formed, that it names a
  real principle, or that it is additive rather than relaxing.
- **No fail-closed behaviour.** A fork that never reads the file simply gets no
  mandates, silently. Nothing errors, warns, or blocks, and nothing will tell it.
- **No enforcement.** The hook floor (`git-safety-gate.sh`,
  `subagent-git-guard.sh`, `protect-governance-files.sh`, `freeze-write-scope.sh`)
  is unchanged by any mandate and never consults one.

In the vocabulary of `.docs/architecture/governance-threat-model.md`, a mandate is
**followed**, never **enforced**. Treat it the way you treat any other written
policy: it works when it is read and interpreted correctly, and it does nothing at
all when it is not.

### The only unit: a named mandate

The only **normative** unit in `amendments.md` is a named mandate. One shape, no
variants:

```
### Mandate: <SHORT-NAME>

**Constrains**: <principle numeral(s), or "—" for an area this Constitution is silent on>
**Rule**: <the additional requirement — MUST / MUST NOT>
**Rationale**: <why this project needs it>
```

Named mandates are the **single** extension surface. There is deliberately no
second mechanism: no in-line `> **PROJECT**:` markers in this file, no
per-principle override blocks, no project section appended to a principle body.
Anything else in `amendments.md` — the file header, explanatory prose, the
amendment log — is documentation and carries no governance force. Anything
outside `amendments.md` is not an amendment at all.

### Composition: intended additive, adjudicated toward the floor

Effective governance = **this Constitution AND every named mandate**, composed as
a conjunction.

The upstream constitutional floor remains **normatively supreme**. Project
mandates are intended to add obligations only; any conflicting or relaxing effect
is invalid. Because mandates are natural-language, model-interpreted policy, this
invariant depends on correct loading, interpretation, and conflict adjudication
rather than on the mandate grammar alone.

Be precise about what the grammar does and does not do. The mandate shape has no
`Overrides`, `Disables`, `Exempts`, `Waives`, or `Relaxes` field — `Constrains` is
the only relational field. That constrains **field names, not meaning**. `Rule` is
unrestricted natural language, so a mandate can weaken a principle semantically
while staying entirely inside the grammar: by redefining a term the principle
depends on, by broadening what counts as approval or as a test, by constraining
the *enforcement* rather than the behaviour, or by writing a rule under which
compliance is vacuous. The absence of a relaxing verb makes weakening
**conspicuous**, not impossible.

The rules below are therefore adjudication rules, applied by whoever — or
whatever — reads the file. They are not a structural guarantee.

1. A mandate MAY **tighten** any principle (I–XVI), the immutable three included.
   "Coverage minimum: 95%" is a legal tightening of Principle II.
2. A mandate MAY govern an area this Constitution is silent on.
3. A mandate MUST NOT relax, disable, exempt from, waive, or override any
   principle — whether it says so outright or achieves it by redefinition,
   reinterpretation, scope-narrowing, or any other wording.
4. If a mandate reads as relaxing a principle — by any wording — the **principle
   prevails and the mandate is void in that respect**. Conflict always resolves
   toward the floor, never away from it.
5. A mandate is policy, not enforcement. It cannot disable, weaken, or rewire a
   hook; a hook change is a governance-surface edit gated by
   `protect-governance-files.sh`, and is not an amendment at all.

### Tightening that neuters: the vacuous-precondition class

A mandate can defeat a principle's purpose without logically contradicting it.
"No code may be written until X" is formally a tightening even when X is
unachievable, circular, or under no one's control; "every test must be approved by
a party that does not exist" formally tightens Principle II while making it
impossible to satisfy. Such a rule does not relax I–III — it disables the activity
the principle exists to govern.

Treat it as a violation of rule 3. A mandate whose effect is that a principle can
never be satisfied, or that the work the principle governs can never begin, is
**void in that respect**, on the same footing as an openly relaxing mandate. The
test is effect, not form: ask what a compliant project can still do, not whether
the wording added a condition.

### Precedence and adjudication

Order of authority, highest first:

1. **Immutable Principles I–III** — never amendable, never overridable, by any
   mandate or any other document.
2. **Principles IV–XVI** (this Constitution).
3. **Named mandates** in `amendments.md`.
4. **`VISION.md`** — direction only. Never an authority on *how*.

Applied cases:

- **Mandate vs. this Constitution.** The Constitution prevails. The mandate is
  void in the conflicting respect only; the rest of it stands.
- **Mandate vs. mandate.** Both apply — the composition is a conjunction, so the
  **stricter obligation governs** and satisfying both is required. Where two
  mandates genuinely cannot both be satisfied (a real contradiction, not merely a
  tighter and a looser bound), neither wins by seniority or file order: **both
  are void in the contradicting respect** and the Constitution's own requirement
  stands unmodified. Fix the contradiction in `amendments.md`; do not resolve it
  silently at read time.
- **Mandate vs. `VISION.md`.** They do not compete. `VISION.md` is direction
  (*what/why*); a mandate is floor (*how*). Where a mandate blocks something
  `VISION.md` calls for, the **mandate prevails** — direction never relaxes the
  floor. The remedy is to amend or remove the mandate deliberately, not to
  disregard it because the vision wants the work.
- **Ambiguous mandate.** A mandate whose effect on a principle is unclear — one
  reading tightens, another relaxes — is read under the **tightening
  interpretation**. If no tightening reading exists, the mandate is void in that
  respect. Ambiguity is never resolved in the direction of less obligation.
  Surface it to the maintainer rather than acting on a guess.
- **Partial invalidity.** Validity is assessed per-effect, not per-mandate. A
  mandate that is a legal tightening in one respect and a relaxation in another
  keeps the valid part and loses the invalid part. The invalid part does not taint
  the rest, and the valid part does not rescue the invalid part.

### Relationship to `VISION.md`

`VISION.md` sets *what/why* (direction); `amendments.md` adds to *how* (the
floor). A mandate is not a third governance channel alongside this Constitution
and `VISION.md` — it is an extension of the *same* floor the Preamble's
governance-vs-direction clause describes, sitting directly under this
Constitution. Neither `VISION.md` nor `amendments.md` is a governance authority
over this Constitution, and neither can relax it.

### Protection status

`amendments.md` is fork content and is **not** on the hook-protected governance
surface. A fork that wants it protected must add it to its own protected paths.
Be honest about what that means: an unprotected `amendments.md` can be edited by
any agent with write access, and because nothing validates the file, a mandate
weakened or deleted there produces no signal at all. What actually keeps the floor
intact is that the hooks never consult mandates — not that a mandate is incapable
of saying something wrong.

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
| 3.2.0 | 2026-06-15 | Preamble **Governance vs. direction** clause: constitution defers new-project direction to the foundational root `VISION.md`; floor stays supreme. No principle added (numbering stable) |
| 3.3.0 | 2026-08-17 | **Project Amendments** extension point: fork mandates live as named mandates in a separate, fork-owned `.logic-loom/memory/amendments.md`, composed conjunctively with this Constitution. Intended additive-only, with precedence rules resolving conflict, contradiction, and ambiguity toward the floor; the invariant is reader-adjudicated, not grammar-guaranteed. Model-followed policy only — no loader, no validator, no enforcement. No principle body, numbering, immutability marker, or enforcement claim changed |

---

*v3.3.0 — LogicLoom Constitution. Governance is the durable core; SDD waterfall
and vision/swarm are interchangeable workflow packs.*
