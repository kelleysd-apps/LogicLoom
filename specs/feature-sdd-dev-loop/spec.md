# Feature Specification: sdd-dev-loop — Recursive Autonomous Dev-Loop Plugin with Council/Tribunal Methodology

**Feature Branch**: `feature-sdd-dev-loop`
**Created**: 2026-02-07
**Status**: Draft
**Input**: User description: "A recursive autonomous development loop plugin that combines edit-test-debug cycles, multi-model tribunal voting, composite quality grading, RL-based self-improvement, sandboxed execution, and self-extension into a unified system. Invoked via /dev-loop, it autonomously researches, plans, implements, tests, grades, and iterates until a configurable quality threshold is met or a termination condition is triggered."
**Research Reference**: `.docs/research/20260207-132845-recursive-dev-loop-council-plugin/final-report.md`

## Execution Flow (main)
```
1. Parse user description from Input
   -> Feature description: Recursive autonomous dev-loop plugin with council/tribunal methodology
2. Extract key concepts from description
   -> Actors: Developers, team leads, framework maintainers, autonomous agents
   -> Actions: Invoke dev-loop, research tasks, plan implementations, execute code changes,
      run tests, grade quality, vote via tribunal, iterate until convergence, self-extend
   -> Data: Sessions, tribunal ballots, quality grades, event logs, RL metrics, scope analyses
   -> Constraints: Must operate within safety sandbox, respect budget/iteration limits,
      preserve constitutional governance, require user approval for high-risk operations
3. Ambiguities marked: See [NEEDS CLARIFICATION] markers below
4. User Scenarios & Testing section filled
5. Functional Requirements generated (all testable, with research claim traceability)
6. Key Entities identified
7. Review Checklist: PASS (pending clarification items)
8. Return: SUCCESS (spec ready for planning)
```

---

## Quick Guidelines
- Focus on WHAT users need and WHY
- Avoid HOW to implement (no tech stack, APIs, code structure)
- Written for business stakeholders, not developers

---

## User Scenarios & Testing *(mandatory)*

### Primary User Story

As a **developer**, I want to invoke `/dev-loop "implement feature X"` and have the system autonomously research the task, plan the approach, implement code changes, run tests, grade quality, and iterate until a configurable quality threshold is met, so that I can focus on higher-level decisions while the system handles the repetitive edit-test-debug cycle.

### Secondary User Stories

**US-001**: As a **developer**, I want the system to use multiple independent AI models to vote on key decisions (research direction, implementation approach, quality assessment) so that no single model's blind spots or biases lead the project astray. *(Ref: C06, C07, C08)*

**US-002**: As a **developer**, I want the system to automatically stop iterating when quality improvements plateau, rather than burning through budget on diminishing returns, so that I get the best result for my investment. *(Ref: C11, C12)*

**US-003**: As a **team lead**, I want configurable budget limits (token count and cost) that act as hard circuit breakers on autonomous execution, so that a runaway loop never exceeds our spending thresholds. *(Ref: C31)*

**US-004**: As a **developer**, I want a detailed session report after each dev-loop run showing every iteration's quality grade, tribunal votes, decisions made, and resources consumed, so that I can understand what the system did and why. *(Ref: C25)*

**US-005**: As a **developer**, I want the system to learn from past sessions — remembering which approaches worked for which types of tasks — so that future runs start smarter and converge faster. *(Ref: C13, C14, C24)*

**US-006**: As a **developer**, I want to interrupt a running dev-loop at any point and have it save a checkpoint I can resume from later, so that I never lose work in progress. *(Ref: C32)*

**US-007**: As a **framework maintainer**, I want the system to detect when it lacks a needed capability and create new plugins to fill the gap, subject to safety review, so that the system improves itself over time. *(Ref: C34, C36)*

**US-008**: As a **developer**, I want the system to automatically determine whether my request is a small tactical task (bug fix, refactor) or a large strategic task (new feature, architecture change) and adjust its workflow accordingly, so that simple tasks are handled quickly without unnecessary overhead. *(Ref: C33)*

**US-009**: As a **developer**, I want all autonomous code execution to happen in a restricted environment where the system cannot access my credentials, modify files outside the project workspace, or push code without my explicit approval, so that I can trust the system to operate safely. *(Ref: C17, C27, C28, C29)*

**US-010**: As a **team lead**, I want the system's quality grading to be transparent and configurable, with clear weights for each quality dimension (tests, coverage, lint, type safety, security), so that I can tune it to match our team's quality standards. *(Ref: C15, C22)*

### Acceptance Scenarios

1. **Given** a developer invokes `/dev-loop "add input validation to the user registration form"`, **When** the system completes its autonomous loop, **Then** the resulting code changes pass all existing tests, introduce new validation tests, and achieve a composite quality grade at or above the configured threshold (default 0.95).

2. **Given** a dev-loop session where three AI models are consulted for a tribunal vote on implementation approach, **When** the models return their assessments, **Then** the system anonymizes model identities during review, applies majority voting, weights votes by each model's historical reliability, and records the full ballot for audit. *(Ref: C06, C07, C08, C14)*

3. **Given** a dev-loop session that has run for 5 iterations with quality grades of [0.72, 0.81, 0.84, 0.845, 0.846], **When** the improvement between the last three iterations is below the convergence threshold (0.001), **Then** the system exits with a "converged" status, reports the final grade, and does not consume additional resources. *(Ref: C11)*

4. **Given** a dev-loop session with a budget limit of 500,000 tokens, **When** cumulative token usage across all AI model calls reaches 500,000, **Then** the system immediately halts, saves a checkpoint of the current state, and reports "budget exhausted" with a summary of work completed. *(Ref: C31)*

5. **Given** a running dev-loop session, **When** the developer sends an interrupt signal, **Then** the system pauses execution within 5 seconds, saves all session state to a checkpoint, presents a summary of progress, and offers the developer the option to resume, adjust parameters, or terminate. *(Ref: C32)*

6. **Given** a developer invokes `/dev-loop "fix the typo in the README"`, **When** the system analyzes the task scope, **Then** it classifies the task as "tactic" mode, skips the full specification workflow, and proceeds directly with a streamlined plan-and-execute cycle. *(Ref: C33)*

7. **Given** a developer invokes `/dev-loop "implement OAuth2 authentication with role-based access control"`, **When** the system analyzes the task scope, **Then** it classifies the task as "strategy" mode and engages the full specification workflow including research, detailed planning, and multi-phase implementation. *(Ref: C33)*

8. **Given** a dev-loop iteration that produces code changes, **When** the quality grading system evaluates the result, **Then** it produces a composite score combining test pass rate, test coverage, lint compliance, type safety, security scan results, and build success, each normalized to a 0-1 scale and combined with configurable weights. *(Ref: C15, C21, C22, C23)*

9. **Given** a dev-loop session where the same test failure has occurred in 3 consecutive iterations, **When** the stuck detection layer identifies the pattern, **Then** the system triggers a tribunal re-evaluation of the approach rather than attempting the same fix again. *(Ref: C26)*

10. **Given** a dev-loop session where one of three tribunal AI models fails to respond, **When** the system detects the provider outage, **Then** it continues with the remaining two models, adjusts the voting threshold accordingly, and logs the degraded state. *(Ref: C38)*

11. **Given** a completed dev-loop session, **When** the system generates the session report, **Then** the report includes: total iterations, quality grade trajectory, tribunal votes and decisions, total tokens consumed, total cost, time elapsed, all code changes made, and the final termination reason.

12. **Given** a dev-loop session that achieves a quality grade meeting the threshold on iteration 3, **When** the success condition is evaluated, **Then** the system exits with "success" status, records the outcome as positive RL feedback for all skills and models used, and generates a session report. *(Ref: C13)*

### Edge Cases

- What happens when all three tribunal AI model providers fail simultaneously? The system MUST save a checkpoint, notify the developer, and wait for manual intervention rather than proceeding without tribunal validation.
- What happens when the system detects oscillation (undoing and redoing the same changes across iterations)? The system MUST detect repeated code states via change hashing, halt the current approach, and request tribunal re-evaluation of the strategy. *(Ref: C26)*
- What happens when the dev-loop encounters a task that requires a capability the system does not have (e.g., a specialized build tool)? The system MUST detect the gap, attempt to self-extend by creating a new plugin, validate it in quarantine, and only use it after safety review passes. If self-extension fails, the system MUST report the gap and request developer guidance. *(Ref: C34, C36)*
- What happens when the developer provides a task description that is too vague to act on? The system MUST ask clarifying questions before beginning autonomous execution, rather than making assumptions.
- What happens when the configured quality threshold is unreachable for the given task (e.g., 0.99 for a legacy codebase with inherent lint issues)? Convergence detection MUST serve as the escape hatch, stopping the loop when further improvement is negligible. *(Ref: C10, C11)*
- What happens when a dev-loop session is resumed from a checkpoint? The system MUST restore full session state including iteration count, quality history, budget consumed, and event log, then continue from the exact point of interruption.
- What happens when the system attempts to perform a git push during autonomous execution? The system MUST block the operation and request explicit developer approval before proceeding. *(Ref: C18, C29)*
- What happens when two dev-loop sessions are running concurrently on the same project? [NEEDS CLARIFICATION: Concurrent session behavior — should the system prevent concurrent sessions, isolate them on separate branches, or allow parallel execution with merge conflict detection?]

---

## Requirements *(mandatory)*

### Functional Requirements — Core Dev-Loop Engine

- **FR-001**: System MUST execute a recursive edit-test-debug loop following the cycle: Research -> Plan -> Implement -> Test -> Grade -> Evaluate -> [Pass: Complete | Fail: Diagnose -> Implement]. This is the foundational operational pattern validated across all major autonomous coding systems. *(Ref: C02)*

- **FR-002**: System MUST start each iteration with fresh context, reading current state from version control and structured files rather than accumulating context across iterations, to prevent degraded reasoning quality in long-running sessions. *(Ref: C01, C03)*

- **FR-003**: System MUST use automated test feedback (pass/fail results with detailed error output) as the primary signal for evaluating code quality and guiding iteration decisions. *(Ref: C05)*

- **FR-004**: System MUST provide a single entry point command (`/dev-loop`) that accepts a natural-language task description and optional configuration parameters (quality threshold, budget limit, iteration limit, execution mode). *(Ref: C02)*

- **FR-005**: System MUST use constrained tool interfaces rather than unrestricted system access, limiting available operations to a well-defined set of read, write, test, and analysis actions. *(Ref: C04, C16)*

### Functional Requirements — Tribunal Voting System

- **FR-006**: System MUST consult three independent AI models for tribunal decisions on key checkpoints: initial research synthesis, implementation approach selection, and quality disputes. *(Ref: C06)*

- **FR-007**: System MUST anonymize AI model identities during tribunal peer review to prevent favoritism bias, presenting assessments without attribution until after voting is complete. *(Ref: C07)*

- **FR-008**: System MUST use simple majority voting (2-of-3 agreement) for routine tribunal decisions, as this captures the majority of accuracy gains at lower cost than full consensus protocols. *(Ref: C08)*

- **FR-009**: System MUST weight tribunal votes using historically tracked reliability scores (EMA-adjusted), so that models with better track records have proportionally greater influence on close decisions. *(Ref: C14)*

- **FR-010**: System MUST query all tribunal models in parallel so that total tribunal latency is determined by the slowest model response, not the sum of all model responses. *(Ref: C38)*

- **FR-011**: System MUST continue tribunal operations with two of three models when one provider is unavailable, adjusting the voting threshold accordingly and logging the degraded state. *(Ref: C38)*

### Functional Requirements — Quality Grading System

- **FR-012**: System MUST compute a composite quality grade by normalizing each quality metric to a 0-1 scale and combining them with configurable weights. *(Ref: C22)*

- **FR-013**: System MUST evaluate quality across multiple dimensions: test pass rate, test coverage, lint compliance (zero errors), type safety (zero errors), security scan results (zero critical/high vulnerabilities), and build success. *(Ref: C21)*

- **FR-014**: System MUST weight test pass rate as the single heaviest factor in the composite grade (30-40% of total weight), reflecting its role as the primary correctness signal. *(Ref: C23)*

- **FR-015**: System MUST provide default quality weights (test pass rate: 35%, test coverage: 20%, lint: 15%, type safety: 15%, security: 10%, build: 5%) that can be overridden by the developer on a per-session or per-project basis. *(Ref: C15)*

- **FR-016**: System MUST support a configurable quality threshold with a default of 0.95, a minimum of 0.80 (industry standard), and a maximum of 0.99. The loop exits with "success" when the composite grade meets or exceeds the threshold. *(Ref: C10)*

- **FR-017**: System MUST supplement automated quality metrics with AI-based semantic evaluation (assessing readability, architectural soundness, and specification compliance) for aspects that automated tools cannot fully capture. *(Ref: C20)*

### Functional Requirements — RL Feedback and Learning

- **FR-018**: System MUST track performance of all skills and AI models using Exponential Moving Average (EMA) with a learning rate of 0.1, updating after each session based on outcome (success or failure). *(Ref: C13)*

- **FR-019**: System MUST persist RL metrics (success rate, selection weight, invocation count, average resource consumption) in structured data files that survive across sessions. *(Ref: C13)*

- **FR-020**: System MUST integrate with the existing SDD framework RL metrics system to maintain a single source of truth for skill and model performance data. *(Ref: C13)*

- **FR-021**: System MUST use exploration-exploitation balancing when selecting skills and approaches for a given task type, favoring proven approaches while occasionally trying alternatives to discover improvements. *(Ref: C24)*

### Functional Requirements — Multi-Layer Termination

- **FR-022**: System MUST implement a six-layer termination strategy, evaluated in priority order: (1) success threshold met, (2) convergence detected, (3) budget exhausted, (4) maximum iterations reached, (5) stuck/oscillation detected, (6) user interrupt received. *(Ref: C12)*

- **FR-023**: System MUST detect convergence when the quality grade improvement is below a configurable delta (default 0.001) for a configurable number of consecutive iterations (default 3), and exit with "converged" status. *(Ref: C11)*

- **FR-024**: System MUST enforce a configurable maximum iteration limit (default 25, range 10-50) as a non-negotiable safety backstop, exiting with "max iterations" status when reached. *(Ref: C30)*

- **FR-025**: System MUST track cumulative token usage and cost per AI model provider and enforce hard budget limits, exiting with "budget exhausted" status when any limit is reached. *(Ref: C31)*

- **FR-026**: System MUST detect stuck states by identifying when the same error or test failure recurs across three or more consecutive iterations, and trigger a tribunal re-evaluation of the approach when detected. *(Ref: C26)*

- **FR-027**: System MUST detect oscillation by tracking code change fingerprints across iterations and identifying when the system reverts to a previously visited state. *(Ref: C26)*

- **FR-028**: System MUST handle user interrupt signals by pausing execution within 5 seconds, saving all session state to a resumable checkpoint, and presenting a summary of progress. *(Ref: C32)*

### Functional Requirements — Safety and Sandboxing

- **FR-029**: System MUST execute all autonomous code changes and test runs within a sandboxed environment that restricts the agent to a designated workspace directory with no access to system files, credentials, or resources outside the project. *(Ref: C27, C28)*

- **FR-030**: System MUST enforce a tiered permission model with four levels: Level 0 (read-only operations — always permitted), Level 1 (safe write operations within workspace — permitted by default), Level 2 (version control commits on current branch, network access to allowlisted destinations — requires per-session approval), Level 3 (version control push, deployment actions, credential access — requires explicit per-action approval). *(Ref: C17)*

- **FR-031**: System MUST block all version control branch operations (create, switch, delete) during autonomous execution, restricting the agent to its designated working branch. *(Ref: C18)*

- **FR-032**: System MUST require explicit developer approval before any version control push operation, regardless of the session's permission level. *(Ref: C29)*

- **FR-033**: System MUST enforce resource limits (processing time, memory) on sandboxed execution to prevent a single iteration from consuming unbounded resources. *(Ref: C27)*

### Functional Requirements — Scope Detection

- **FR-034**: System MUST analyze each incoming task description to classify it as either "tactic" (small, focused — e.g., bug fix, simple refactor, documentation update) or "strategy" (large, cross-cutting — e.g., new feature, architectural change, multi-component work). *(Ref: C33)*

- **FR-035**: System MUST use "tactic" mode for small tasks, executing a streamlined cycle (plan -> implement -> test -> grade) that skips the full specification and research phases, optimizing for speed. *(Ref: C33)*

- **FR-036**: System MUST use "strategy" mode for large tasks, engaging the full workflow (research -> tribunal -> specify -> plan -> implement -> test -> grade) with tribunal checkpoints at key decision points. *(Ref: C33)*

- **FR-037**: System MUST allow the developer to override the automatic scope classification, forcing either tactic or strategy mode regardless of the system's assessment.

### Functional Requirements — Self-Extension

- **FR-038**: System MUST detect capability gaps when it encounters recurring inefficiencies or missing tools during execution, and report these gaps in the session report. *(Ref: C34)*

- **FR-039**: System MUST be capable of creating new plugins to fill detected capability gaps, using the standard plugin creation workflow to generate the plugin structure, tests, and manifest. *(Ref: C34, C35)*

- **FR-040**: System MUST validate all self-created plugins in a quarantine environment with comprehensive testing and security scanning before they are made available for use. *(Ref: C34)*

- **FR-041**: System MUST subject all self-created plugins to a constitutional governance review — an independent AI assessment verifying the plugin does not violate framework principles, attempt unauthorized access, or introduce security risks — before activation. *(Ref: C36)*

- **FR-042**: System MUST dynamically register validated new plugins for use in the current and future sessions without requiring a system restart. *(Ref: C19)*

### Functional Requirements — Event Sourcing and Reporting

- **FR-043**: System MUST log every significant event during a dev-loop session (thoughts, actions, observations, decisions, tool invocations, quality grades, tribunal votes) into a structured event stream. *(Ref: C25)*

- **FR-044**: System MUST generate a comprehensive session report at the conclusion of every dev-loop run, including: iteration count, quality grade trajectory, all tribunal decisions, total tokens consumed per model, total cost, wall-clock time, code changes summary, termination reason, and RL feedback recorded. *(Ref: C25)*

- **FR-045**: System MUST support full session replay from the event log, enabling post-hoc debugging and analysis of any completed dev-loop session. *(Ref: C25)*

- **FR-046**: System MUST use the event log as the source for extracting RL reward signals, connecting session outcomes to the specific skills and models that contributed to them. *(Ref: C25)*

### Non-Functional Requirements

- **NFR-001**: Tribunal voting latency MUST be bounded by the slowest individual model response time, not the sum of all model response times (parallel execution required). *(Ref: C38)*

- **NFR-002**: Checkpoint save on interrupt MUST complete within 5 seconds of signal receipt.

- **NFR-003**: Session resume from checkpoint MUST restore full state and continue execution within 10 seconds.

- **NFR-004**: All plugin components MUST have greater than 80% test coverage (Constitutional Principle II).

- **NFR-005**: Quality grading computation MUST complete within 30 seconds per iteration, including all metric collection.

- **NFR-006**: Scope detection classification MUST complete within 5 seconds of receiving the task description.

- **NFR-007**: Event log MUST support sessions of up to 50 iterations without performance degradation in write or query operations.

- **NFR-008**: The plugin MUST integrate with the existing SDD framework plugin architecture, following all plugin manifest and directory structure conventions (Constitutional Principle XVI).

- **NFR-009**: Self-created plugins MUST pass the same governance validation as manually created plugins, with no reduced scrutiny.

---

## Key Entities

- **DevLoopSession**: Represents a single invocation of the dev-loop from start to termination. Tracks the task description, configuration parameters (quality threshold, budget, iteration limit, execution mode), current iteration number, quality grade history, cumulative resource consumption, session status (running, paused, completed, failed), and the termination reason.

- **TribunalBallot**: Represents the outcome of a single tribunal vote. Contains the decision point identifier (what was being decided), the anonymized assessments from each participating model, individual confidence scores, the aggregated vote result (approved, rejected, split), the EMA-adjusted weight applied to each vote, and the final decision reached.

- **QualityGrade**: Represents the quality assessment of a single iteration's output. Contains the raw metric values (test pass rate, coverage percentage, lint error count, type error count, security vulnerability count, build status), the normalized 0-1 scores for each metric, the weights applied, and the composite grade. Optionally contains the AI-based semantic evaluation score and commentary.

- **TerminationEvent**: Represents the reason a dev-loop session ended. Contains the termination layer that triggered (success, convergence, budget, max iterations, stuck, user interrupt), the specific trigger values (e.g., final grade, convergence delta, tokens consumed), and a human-readable explanation.

- **PluginManifest**: Represents the metadata for a self-created plugin. Contains the plugin name, version, entry point, parameter definitions, required permissions, and governance review status. Must conform to the SDD framework's standard plugin manifest schema.

- **EventLog**: Represents the ordered sequence of all events in a dev-loop session. Each event has a timestamp, event type (thought, action, observation, decision, tool_invocation, grade, vote), structured payload, and the iteration number it belongs to. Serves as the source of truth for session replay, reporting, and RL feedback extraction.

- **RLMetrics**: Represents the learned performance data for a skill or AI model. Contains the current success rate (EMA-smoothed), selection weight (derived from success rate), total invocation count, average resource consumption, and per-task-type performance breakdowns. Updated after each session based on outcomes.

- **ScopeAnalysis**: Represents the system's classification of a task's scope. Contains the input task description, detected keywords and signals, estimated file count impact, cross-cutting concern indicators, the resulting classification (tactic or strategy), the confidence level of the classification, and any developer override applied.

---

## Phased Delivery Plan

This feature is large and MUST be delivered in phases to manage risk and enable incremental validation:

| Phase | Scope | Dependencies | Key Deliverables |
|-------|-------|--------------|------------------|
| **Phase 1: Core Loop** | Basic edit-test-debug loop with single-model execution, quality grading, and termination | None | FR-001 through FR-005, FR-012 through FR-016, FR-022 through FR-028, NFR-002 through NFR-005 |
| **Phase 2: Tribunal** | Multi-model tribunal voting, anonymous review, EMA-weighted decisions | Phase 1 | FR-006 through FR-011, NFR-001 |
| **Phase 3: Safety** | Sandboxed execution, tiered permissions, git operation controls | Phase 1 | FR-029 through FR-033, NFR-008 |
| **Phase 4: Intelligence** | Scope detection, RL feedback integration, learning across sessions | Phase 1 | FR-018 through FR-021, FR-034 through FR-037, NFR-006 |
| **Phase 5: Observability** | Event sourcing, session reporting, session replay | Phase 1 | FR-043 through FR-046, FR-017, NFR-007 |
| **Phase 6: Self-Extension** | Capability gap detection, plugin self-creation, quarantine validation, constitutional review | Phase 3, Phase 4 | FR-038 through FR-042, NFR-009 |

---

## Dependencies and Assumptions

### Dependencies

- **SDD Plugin Architecture (v4.1)**: The dev-loop plugin depends on the existing plugin-first architecture for installation, manifest conventions, and command bridge integration.
- **SDD Governance Plugin**: Constitutional governance enforcement (Principle X delegation, Principle VI git approval) must be available for the safety layer and self-extension review.
- **SDD RL Metrics System**: The existing RL feedback infrastructure must be available for integration (metrics files, sync scripts, dashboard).
- **SDD Specification Workflow**: Strategy mode depends on the existing `/specification` workflow for full spec-plan-tasks generation.
- **Multiple AI Model Providers**: Tribunal functionality requires access to at least two (preferably three) independent AI model providers.

### Assumptions

- Developers have access to at least one AI model provider for basic operation (single-model mode) and at least two for tribunal operations.
- The project under development has an automated test suite that can be executed programmatically and returns structured pass/fail results.
- The project has a version control repository initialized and the developer has committed a working baseline before invoking the dev-loop.
- Sandboxed execution environments are available on the developer's system. [NEEDS CLARIFICATION: What is the minimum sandboxing requirement for developers who cannot run containerized environments? Is OS-level sandboxing (Ref: C09) a viable fallback?]

---

## Research Traceability Matrix

The following matrix maps each confirmed research claim to its corresponding functional requirements, ensuring full traceability from evidence to specification.

| Claim ID | Claim Summary | Confidence | Requirements |
|----------|---------------|------------|-------------|
| C01 | Fresh-context loop pattern is production-tested | 0.90 | FR-002 |
| C02 | Edit-test-debug loop is universal pattern | 0.97 | FR-001, FR-004 |
| C03 | Fresh context prevents reasoning degradation | 0.81 | FR-002 |
| C04 | Constrained tool interfaces more reliable | 0.90 | FR-005 |
| C05 | Automated testing is most reliable quality signal | 0.97 | FR-003 |
| C06 | 3-model tribunal reduces error probability | 0.90 | FR-006 |
| C07 | Anonymous reviews prevent favoritism bias | 0.90 | FR-007 |
| C08 | Majority voting captures most gains | 0.90 | FR-008 |
| C09 | OS-level sandboxing reduces permission prompts | 0.81 | Assumption note |
| C10 | 99% threshold ambitious; 80% is industry standard | 0.90 | FR-016 |
| C11 | Convergence detection more efficient than max iterations | 0.97 | FR-023 |
| C12 | Multi-layer termination strategy required | 0.97 | FR-022 |
| C13 | EMA with alpha=0.1 for performance tracking | 0.97 | FR-018, FR-019, FR-020 |
| C14 | EMA-adjusted tribunal vote weighting | 0.97 | FR-009 |
| C15 | Composite quality score with standard weights | 0.97 | FR-015 |
| C16 | Constrained interfaces validated by SWE-bench results | 0.97 | FR-005 |
| C17 | Tiered permission model (L0-L3) | 0.90 | FR-030 |
| C18 | Git branch operations must be blocked | 0.97 | FR-031 |
| C19 | Dynamic tool discovery via protocol | 0.97 | FR-042 |
| C20 | AI-based semantic evaluation supplements automated metrics | 0.97 | FR-017 |
| C21 | Multi-dimensional grading metrics required | 0.97 | FR-013 |
| C22 | Normalize metrics to 0-1, combine with configurable weights | 0.97 | FR-012 |
| C23 | Test pass rate weighted most heavily | 0.97 | FR-014 |
| C24 | Exploration-exploitation balancing for skill selection | 0.90 | FR-021 |
| C25 | Event sourcing for all session events | 0.90 | FR-043, FR-044, FR-045, FR-046 |
| C26 | Oscillation detection via code state hashing | 0.90 | FR-026, FR-027 |
| C27 | Sandboxed execution with restricted access | 0.97 | FR-029, FR-033 |
| C28 | Principle of least privilege for agent access | 0.90 | FR-029 |
| C29 | Git push requires user approval | 0.97 | FR-032 |
| C30 | Configurable max iteration limit as safety backstop | 0.74 | FR-024 |
| C31 | Cost/token budget circuit breaker required | 0.97 | FR-025 |
| C32 | Interrupt handling with checkpoint persistence | 0.90 | FR-028 |
| C33 | Scope detection for tactic vs strategy routing | 0.81 | FR-034, FR-035, FR-036, FR-037 |
| C34 | Self-extension: detect gaps, scaffold, validate, register | 0.97 | FR-038, FR-039, FR-040, FR-042 |
| C35 | Plugin manifest with standard fields | 0.81 | FR-039 (PluginManifest entity) |
| C36 | Constitutional review of self-created plugins | 0.81 | FR-041 |
| C37 | Self-modification yields substantial improvement (SICA evidence) | 0.81 | FR-038 (motivation) |
| C38 | Parallel multi-model execution for latency | 0.90 | FR-010, FR-011, NFR-001 |

---

## Review & Acceptance Checklist
*GATE: Automated checks run during main() execution*

### Content Quality
- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

### Requirement Completeness
- [ ] No [NEEDS CLARIFICATION] markers remain — 2 remain (concurrent sessions, minimum sandboxing)
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Scope is clearly bounded (phased delivery)
- [x] Dependencies and assumptions identified
- [x] Research claims traced to requirements (traceability matrix)

---

## Execution Status
*Updated by main() during processing*

- [x] User description parsed
- [x] Key concepts extracted (actors, actions, data, constraints)
- [x] Ambiguities marked (2 items)
- [x] User scenarios defined (10 user stories, 12 acceptance scenarios, 8 edge cases)
- [x] Requirements generated (46 FR + 9 NFR)
- [x] Entities identified (8 entities)
- [x] Research traceability matrix completed (38 claims mapped)
- [x] Phased delivery plan defined (6 phases)
- [x] Review checklist passed (2 minor clarifications pending)

---
