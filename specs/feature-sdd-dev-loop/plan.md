# Implementation Plan: sdd-dev-loop — Recursive Autonomous Dev-Loop Plugin

**Branch**: `feature-sdd-dev-loop` | **Date**: 2026-02-07 | **Spec**: `specs/feature-sdd-dev-loop/spec.md`
**Input**: Feature specification from `specs/feature-sdd-dev-loop/spec.md`

## Summary

Implement a new `sdd-dev-loop` plugin that provides a recursive autonomous development loop invoked via `/dev-loop`. The plugin combines edit-test-debug cycles with multi-model tribunal voting (Claude Opus 4.6, GPT-4o, Gemini 2.5 Pro), composite quality grading across six dimensions, EMA-based reinforcement learning feedback, Docker-sandboxed execution with OS-level fallback, heuristic scope detection (tactic vs. strategy routing), event sourcing for full observability, and a four-phase self-extension lifecycle. The system iterates autonomously until a configurable quality threshold (default 0.95) is met or one of six termination layers triggers. Delivery is phased across 6 implementation phases matching the spec's incremental validation strategy.

## Technical Context

**Language/Version**: Bash (scripts, hooks, lib/), Markdown (commands, agents, skills), JSON (manifests, state, event logs as JSONL)
**Primary Dependencies**: Claude Code CLI, Docker MCP Toolkit, OpenAI API (GPT-4o), Google Gemini API (Gemini 2.5 Pro)
**Storage**: Filesystem — plugin directories under `plugins/sdd-dev-loop/`, session state under `.devloop/sessions/`, event logs as JSONL, RL metrics in `.docs/rl-metrics/`
**Testing**: Shell script contract tests using `tests/` directory (>80% coverage per Principle II)
**Target Platform**: macOS/Linux (Claude Code CLI environments)
**Project Type**: Single (framework plugin — not web/mobile)
**Performance Goals**: Tribunal vote < 30s (parallel execution), quality grade compute < 5s, checkpoint save < 2s, scope detection < 5s, session resume < 10s
**Constraints**: Must maintain constitutional governance, respect per-session budgets, require user approval for L3 operations, integrate with existing SDD RL metrics and plugin bridge
**Scale/Scope**: 1 plugin, 9 skills, 4 agents, 1 command, 8 entities, 5 contracts, 6 delivery phases

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | Library-First Architecture | PASS | Plugin is a self-contained, independently installable library under `plugins/sdd-dev-loop/` |
| II | Test-First Development | PASS | TDD mandatory; each phase starts with contract/unit tests before implementation; >80% coverage enforced (NFR-004) |
| III | Contract-First Design | PASS | 5 contracts defined before implementation: dev-loop-lifecycle, tribunal-voting, quality-grading, termination-engine, self-extension |
| IV | Idempotent Operations | PASS | Session start, iterate, grade, and terminate are idempotent — repeating with same inputs produces consistent state; checkpoint restore is idempotent |
| V | Progressive Enhancement | PASS | 6-phase delivery starts with minimal core loop (Phase 1), adds complexity only when prior phase validated; tactic mode is the simpler default |
| VI | Git Operation Approval | PASS | FR-031 blocks git branch operations; FR-032 requires explicit user approval for git push; L3 permission tier gates all high-risk git ops |
| VII | Observability | PASS | Event sourcing (FR-043) logs all thoughts, actions, observations, decisions; session reports (FR-044) provide comprehensive metrics; JSONL format enables structured querying |
| VIII | Documentation Synchronization | PASS | Plugin manifest self-documents capabilities; session reports auto-generated; RL metrics updated automatically |
| IX | Dependency Management | PASS | Plugin manifest declares dependencies on `sdd-governance`, `sdd-specification`, `sdd-git`; API provider versions tracked per-session |
| X | Skills-First Delegation | PASS | 9 skills handle specialized work (tribunal-vote, quality-grade, scope-analysis, etc.); 4 agents invoked by skills; orchestrator delegates per domain |
| XI | Input Validation | PASS | All contract endpoints define explicit input validation and error responses; quality weights validated to sum to 1.0; thresholds range-checked |
| XII | Design System Compliance | N/A | No UI components in this plugin |
| XIII | Feature Access Control | PASS | Four-tier L0-L3 permission model (FR-030) with escalating approval; governance plugin enforces constitutional access control |
| XIV | AI Model Selection | PASS | Primary model: Claude Opus 4.6; tribunal uses three independent models (Opus, GPT-4o, Gemini 2.5 Pro); EMA-weighted selection adapts over time |
| XV | File Organization | PASS | Standard plugin directory structure (`commands/`, `skills/`, `agents/`, `config/`, `lib/`, `templates/`, `tests/`); session data stored under `.devloop/sessions/` |
| XVI | Plugin-First Architecture | PASS | Entire feature delivered as a single installable plugin following v4.1 conventions; manifest with `rl_metrics`, hot-swap support, governance dependency declared |

**CONCERN**: None. All 16 principles pass without deviation.

## Project Structure

### Documentation (this feature)

```
specs/feature-sdd-dev-loop/
  spec.md                           # Feature specification (46 FR + 9 NFR)
  plan.md                           # This file
  research.md                       # 12 technical decisions, 38 research claims
  data-model.md                     # 8 entity definitions with schemas
  quickstart.md                     # PoC validation guide (8 steps)
  contracts/
    dev-loop-lifecycle.md           # Session CRUD, iterate, resume
    tribunal-voting.md              # Ballot create, vote, tally, consensus
    quality-grading.md              # Run grade, composite, threshold, LLM judge
    termination-engine.md           # 6-layer check, convergence, budget, oscillation, checkpoint
    self-extension.md               # Detect gap, scaffold, validate, register
  tasks.md                          # Implementation tasks (generated by /tasks)
```

### Source Code (plugin directory)

```
plugins/sdd-dev-loop/
  .claude-plugin/
    plugin.json                     # Plugin manifest (name, version, dependencies, rl_metrics)
    hooks.json                      # Dev-loop event hooks
  commands/
    dev-loop.md                     # Main /dev-loop slash command
  skills/
    dev-loop-core/SKILL.md          # Core edit-test-debug loop orchestration
    tribunal-research/SKILL.md      # Multi-LLM research orchestration
    tribunal-vote/SKILL.md          # Voting, anonymization, consensus execution
    scope-analysis/SKILL.md         # Tactic vs strategy detection heuristic
    autonomous-execute/SKILL.md     # Iteration execution driver
    quality-grade/SKILL.md          # Composite grading engine
    rl-feedback/SKILL.md            # Performance tracking, EMA updates
    session-report/SKILL.md         # Report generation from event log
    gap-detection/SKILL.md          # Capability gap identification
  agents/
    dev-loop-orchestrator.md        # Main loop controller agent
    tribunal-judge.md               # Tribunal voting agent
    quality-assessor.md             # Quality grading agent
    debug-analyst.md                # Failure diagnosis agent
  config/
    thresholds.json                 # Quality thresholds, convergence parameters
    safety-limits.json              # Budget limits, iteration caps, permission tiers
    weights.json                    # Quality metric weights, EMA alpha, UCB1 params
  templates/
    session-report.md               # Session report template
    tribunal-ballot.md              # Voting ballot template
    gap-analysis.md                 # Capability gap template
  lib/
    grading.sh                      # Quality grading functions (normalize, composite, threshold)
    termination.sh                  # 6-layer circuit breaker logic
    event-sourcing.sh               # JSONL event logging, replay, query functions
    llm-orchestration.sh            # Multi-LLM API abstraction (parallel calls, normalization)
    scope-detection.sh              # Tactic/strategy heuristic scoring
    rl-metrics.sh                   # EMA update, UCB1 selection, metrics persistence
    sandbox.sh                      # Docker sandbox setup, OS-level fallback
    permissions.sh                  # L0-L3 permission enforcement
  tests/
    test-grading.sh                 # Grading engine contract tests
    test-termination.sh             # Termination strategy tests
    test-tribunal.sh                # Tribunal voting tests
    test-scope-detection.sh         # Scope analysis tests
    test-event-sourcing.sh          # Event log tests
    test-permissions.sh             # Permission model tests
    test-rl-metrics.sh              # RL feedback tests
    test-lifecycle.sh               # Session lifecycle tests

# Session data (runtime, not committed)
.devloop/
  sessions/{session_id}/
    session.json                    # DevLoopSession state
    scope.json                      # ScopeAnalysis
    events.jsonl                    # EventLog (append-only)
    ballots/{ballot_id}.json        # TribunalBallot records
    grades/{grade_id}.json          # QualityGrade records
    termination.json                # TerminationEvent
    checkpoints/                    # Resumable checkpoint files
  quarantine/{plugin_name}/         # Self-created plugins under validation
```

**Structure Decision**: Option 1 (Single project). This is a framework plugin, not a web/mobile app.

## Phase 0: Outline & Research

Research complete -- see `research.md`. All 12 technical decisions resolved with full claim traceability:

1. **Core Loop Architecture** -- Edit-test-debug with fresh context per iteration (Ralph Wiggum pattern). Validated by C01, C02, C03, C05, C16.
2. **Tribunal Voting Mechanism** -- Simple majority (2-of-3) with anonymous peer review and EMA-weighted votes. Validated by C06, C07, C08, C14.
3. **Quality Grading Formula** -- Composite weighted scoring (test pass rate: 35%, coverage: 20%, lint: 15%, type safety: 15%, security: 10%, build: 5%) with optional LLM-as-Judge supplement. Validated by C15, C20, C21, C22, C23.
4. **RL Feedback Algorithm** -- EMA (alpha=0.1) for performance tracking + UCB1 for skill selection. Validated by C13, C14, C24.
5. **Termination Strategy** -- Six-layer circuit breaker: success, convergence, budget, max iterations, stuck/oscillation, user interrupt. Validated by C11, C12, C26, C30, C31, C32.
6. **Sandboxing Approach** -- Docker with non-root user, read-only root FS, restricted network; OS-level fallback (seatbelt/bubblewrap). Validated by C09, C27, C28.
7. **Permission Model** -- Four-tier L0-L3 with escalating approval; git branch ops blocked; git push always requires per-action approval. Validated by C17, C18, C28, C29.
8. **Scope Detection** -- Keyword + file count + cross-cutting heuristic with developer override. Validated by C33.
9. **Self-Extension Lifecycle** -- Detect, scaffold, quarantine, register; constitutional review by LLM governor. Validated by C19, C34, C35, C36, C37.
10. **Multi-LLM Orchestration** -- Parallel async execution with graceful degradation (continue with 2/3 on failure, halt at 1/3). Validated by C38.
11. **Event Sourcing Architecture** -- JSONL event stream, session-scoped storage, structured event types. Validated by C25.
12. **Plugin Structure** -- Standard SDD plugin layout with `sdd-dev-loop` naming, 9 skills, 4 agents, 1 command. Validated by C35, NFR-008.

**Research Confidence**: 97.4% unanimous tribunal approval across 38 claims with 0% refuted.

## Phase 1: Design & Contracts

### Contracts Defined

Five contracts define the plugin's operational interfaces:

1. **Dev-Loop Lifecycle** (`contracts/dev-loop-lifecycle.md`): 6 endpoints -- start session, execute iteration, grade iteration, terminate session, resume session, get session status. Defines the complete session management API.

2. **Tribunal Voting** (`contracts/tribunal-voting.md`): 4 endpoints -- create ballot, cast vote, tally votes, get consensus. Implements anonymized multi-model voting with EMA-weighted consensus.

3. **Quality Grading** (`contracts/quality-grading.md`): 4 endpoints -- run grade, compute composite, check threshold, run LLM judge. Covers all six quality dimensions plus optional semantic evaluation.

4. **Termination Engine** (`contracts/termination-engine.md`): 5 endpoints -- check all layers, check convergence, check budget, check oscillation, save checkpoint. Implements the six-layer circuit breaker with checkpoint persistence.

5. **Self-Extension** (`contracts/self-extension.md`): 4 endpoints -- detect gap, scaffold plugin, quarantine validate, register plugin. Covers the full lifecycle from gap detection through constitutional review to dynamic registration.

### Data Model

See `data-model.md` for complete entity definitions with JSON schemas, field tables, validation rules, and state transition diagrams for all 8 entities:

- **DevLoopSession**: Session state machine (pending -> running <-> paused -> complete/failed)
- **TribunalBallot**: Anonymous multi-model voting with EMA-weighted consensus
- **QualityGrade**: Six-dimensional composite scoring with configurable weights
- **TerminationEvent**: Six-layer trigger conditions with priority ordering
- **PluginManifest**: Self-created plugin metadata with quarantine lifecycle
- **EventLog**: Structured JSONL event stream with 8 event types
- **RLMetrics**: EMA-smoothed performance tracking with per-task-type breakdown
- **ScopeAnalysis**: Tactic/strategy classification with keyword scoring

### Architecture Overview

**State Machine (DevLoopSession)**:
```
pending -> running -> [paused <-> running]* -> complete
                                             -> failed
```
Sessions transition through well-defined states. Checkpoints are saved on every pause and at each iteration boundary, enabling resume from any point.

**Event Sourcing Architecture**:
All session activity is captured as an append-only JSONL event stream at `.devloop/sessions/{session_id}/events.jsonl`. Eight event types (thought, action, observation, decision, tool_invocation, grade, vote, error) provide complete observability. Session reports, RL feedback extraction, and replay are all derived from the event log as the single source of truth.

**Multi-LLM API Abstraction Layer**:
The `lib/llm-orchestration.sh` library provides a unified interface for parallel multi-model execution. It normalizes request/response formats across Claude, OpenAI, and Gemini APIs into a common schema (`{role, content, model, tokens_used, cost}`). Graceful degradation continues with 2/3 models on single provider failure; halts and saves checkpoint on 2/3 failure. Per-provider rate limiting with exponential backoff handles transient errors.

**Integration with Existing SDD Framework**:
- **RL Metrics**: Extends `.docs/rl-metrics/skill-performance.json` with dev-loop skill performance; uses existing EMA algorithm (alpha=0.1) and selection weight clamping
- **Governance Hooks**: Registers with `sdd-governance` for constitutional compliance; self-extension plugins undergo LLM governor review
- **Command Bridge**: `/dev-loop` command synced to `.claude/commands/` via `sync-plugin-commands.sh`
- **Plugin Architecture**: Follows v4.1 manifest conventions (`plugin.json` with `rl_metrics`, dependencies, hot-swap support)
- **Specification Workflow**: Strategy mode delegates to existing `/specification` workflow for full spec-plan-tasks generation

### Validation via Quickstart

See `quickstart.md` for PoC validation steps:
- Verify plugin directory structure and manifest
- Basic dev-loop invocation with tactic-mode task
- Tribunal voting with strategy-mode task
- Quality grading composite score verification
- All six termination layer tests
- Scope detection for tactic and strategy tasks
- Event sourcing and JSONL log verification
- RL feedback metrics integration

## Phase 2: Task Planning Approach

*This section describes what the /tasks command will do -- DO NOT execute during /plan.*

### Task Generation Strategy

Tasks will be generated across 6 implementation phases matching the spec's phased delivery plan. Each phase builds on the prior phase and follows strict TDD ordering (tests before implementation).

**Phase 1 -- Core Loop (estimated 10-12 tasks)**:
- Contract tests for dev-loop-lifecycle and quality-grading contracts
- Plugin scaffold (plugin.json manifest, directory structure)
- `lib/grading.sh` -- metric normalization and composite scoring
- `lib/termination.sh` -- 6-layer circuit breaker logic
- `lib/event-sourcing.sh` -- JSONL append, query, replay
- Core loop orchestration (single-model, no tribunal)
- Session management (start, iterate, grade, terminate)
- Checkpoint save/restore for interrupt handling
- Integration tests for end-to-end tactic-mode execution
- Dependencies: None (foundation layer)

**Phase 2 -- Tribunal (estimated 6-8 tasks)**:
- Contract tests for tribunal-voting contract
- `lib/llm-orchestration.sh` -- multi-LLM parallel execution, API normalization
- Tribunal ballot creation with anonymized assessments
- EMA-weighted vote tallying and consensus
- Graceful degradation (2/3 model fallback, 1/3 halt)
- Integration with core loop at decision checkpoints
- Dependencies: Phase 1 complete

**Phase 3 -- Safety (estimated 6-8 tasks)**:
- Contract tests for permission tier enforcement
- `lib/sandbox.sh` -- Docker sandbox setup, non-root user, read-only FS
- `lib/permissions.sh` -- L0-L3 tier enforcement, git operation gating
- OS-level fallback (seatbelt on macOS, bubblewrap on Linux)
- Resource limit enforcement (memory, CPU, disk)
- Integration tests for sandboxed execution
- Dependencies: Phase 1 complete

**Phase 4 -- Intelligence (estimated 6-8 tasks)**:
- Contract tests for scope detection
- `lib/scope-detection.sh` -- keyword analysis, file count heuristic, cross-cutting detection
- `lib/rl-metrics.sh` -- EMA update, UCB1 selection, metrics persistence
- Integration with existing SDD RL metrics system
- Strategy-mode routing to `/specification` workflow
- Tactic-mode streamlined cycle
- Dependencies: Phase 1 complete

**Phase 5 -- Observability (estimated 6-8 tasks)**:
- Session report generation from event log
- Report templates (session-report.md, tribunal-ballot.md)
- Session replay functionality
- LLM-as-Judge semantic evaluation (quality-grading contract)
- Dashboard integration with existing RL dashboard
- Dependencies: Phase 1 complete

**Phase 6 -- Self-Extension (estimated 6-8 tasks)**:
- Contract tests for self-extension contract
- Gap detection during execution (frequency tracking, pattern matching)
- Plugin scaffolding via `/create-plugin` workflow
- Quarantine validation (tests, security scan, constitutional review)
- Dynamic registration via MCP tool discovery
- Integration tests for full self-extension lifecycle
- Dependencies: Phase 3 (sandbox) and Phase 4 (RL metrics) complete

### Ordering Strategy

- **TDD order**: Contract tests written first, then library implementations, then integration tests
- **Dependency order**: Phase 1 (core) before all others; Phase 3 and Phase 4 before Phase 6
- **Parallel execution markers**: Phases 2, 3, 4, and 5 are independent of each other (all depend only on Phase 1) and can be executed in parallel where resources permit. Tasks marked `[P]` within a phase indicate no intra-phase dependency
- **Within each phase**: Tests -> library functions -> skill/agent definitions -> integration tests

### Estimated Output

40-52 numbered, dependency-ordered tasks across 6 phases in `tasks.md`. Each task includes:
- Clear deliverable description
- Test-first ordering (test task precedes implementation task)
- Dependency references to prior tasks
- `[P]` marker for parallelizable tasks
- Acceptance criteria tied to specific FRs/NFRs from the spec
- File paths for all deliverables

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| *None* | All 16 principles pass without deviation | N/A |

**Note on scale**: This plugin is the largest single feature in the SDD framework (46 FR + 9 NFR, 8 entities, 5 contracts, 9 skills, 4 agents). The 6-phase delivery plan (Principle V: Progressive Enhancement) manages this complexity by validating each layer before building the next. No constitutional deviations are required because the plugin's architecture naturally aligns with all 16 principles -- it is, by design, a library-first, test-first, contract-first, plugin-first module.

**NEEDS CLARIFICATION items from spec** (2 remaining, non-blocking for implementation):
1. **Concurrent session behavior**: Default implementation will prevent concurrent sessions on the same branch via lock file. Future enhancement may support parallel sessions on separate branches.
2. **Minimum sandboxing requirement**: OS-level fallback (seatbelt/bubblewrap) is the minimum. Systems without Docker or OS-level sandboxing will run with L1 permission restrictions and a warning.

## Progress Tracking

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command -- describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS (all 16 principles)
- [x] Post-Design Constitution Check: PASS (no new violations after contract/data model review)
- [x] All NEEDS CLARIFICATION resolved (2 non-blocking items documented with default behaviors)
- [x] Complexity deviations documented (0 deviations -- all principles satisfied)

---
*Based on Constitution v3.0.0 - See `.specify/memory/constitution.md`*
