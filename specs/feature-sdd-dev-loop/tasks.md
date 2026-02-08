# Tasks: sdd-dev-loop — Recursive Autonomous Dev-Loop Plugin

**SSOT**: This file is the Single Source of Truth for feature implementation tasks.
**Input**: Design documents from `specs/feature-sdd-dev-loop/`
**Prerequisites**: plan.md (complete), research.md (complete), data-model.md (complete), contracts/ (5 contracts defined)
**Policy**: See `.docs/policies/todo-architecture-policy.md` for task management standards.
**Feature Branch**: `feature-sdd-dev-loop`

## SSOT Task Architecture

```
PROJECT LEVEL (This File)          SESSION LEVEL (TodoWrite)
+-------------------------+        +-------------------------+
| specs/feature-sdd-dev-  |   -->  | Claude Code TodoWrite   |
|   loop/tasks.md         |        | (real-time tracking)    |
| - Persists in git       |   <--  | - Session-scoped        |
| - Full task list        |        | - Active work focus     |
| - Check off when done   |        | - One in_progress task  |
+-------------------------+        +-------------------------+
```

**Workflow**:
1. This file defines ALL implementation tasks (project SSOT)
2. Agents use TodoWrite to track active work (session SSOT)
3. Completions sync back to this file (check off tasks)
4. `/finalize` validates all tasks completed before commit

## Execution Flow (main)
```
1. Load plan.md from specs/feature-sdd-dev-loop/
   -> Extracted: Bash/Markdown/JSON, 6 phases, 5 contracts, 8 entities, 9 skills, 4 agents
2. Load design documents:
   -> data-model.md: 8 entities (DevLoopSession, TribunalBallot, QualityGrade,
      TerminationEvent, PluginManifest, EventLog, RLMetrics, ScopeAnalysis)
   -> contracts/: 5 contracts with 23 endpoints total
      - dev-loop-lifecycle.md: 6 endpoints (Start, Iterate, Grade, Terminate, Resume, Status)
      - tribunal-voting.md: 4 endpoints (Create Ballot, Cast Vote, Tally, Consensus)
      - quality-grading.md: 4 endpoints (Run Grade, Compute Composite, Check Threshold, LLM Judge)
      - termination-engine.md: 5 endpoints (Check All, Convergence, Budget, Oscillation, Checkpoint)
      - self-extension.md: 4 endpoints (Detect Gap, Scaffold, Validate, Register)
   -> research.md: 12 decisions, 38 claims
3. Generate tasks across 6 phases (TDD order within each):
   -> Phase 1: Core Loop Engine (foundation)
   -> Phase 2: Tribunal Voting System
   -> Phase 3: Safety & Sandboxing
   -> Phase 4: Intelligence (Quality, RL, Scope)
   -> Phase 5: Observability (Events & Reporting)
   -> Phase 6: Self-Extension
4. Task rules applied:
   -> [P] marker for independent parallel tasks (different files, no dependencies)
   -> TDD: Tests written BEFORE implementation in every phase
   -> Sequential numbering T001-T049
   -> Dependency graph generated
5. Validation:
   -> All 23 contract endpoints have test + implementation tasks
   -> All 8 entities have model creation tasks
   -> All tests precede their implementation counterparts
6. Return: SUCCESS (49 tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Plugin root**: `plugins/sdd-dev-loop/`
- **Tests**: `plugins/sdd-dev-loop/tests/contract/`, `plugins/sdd-dev-loop/tests/integration/`
- **Libraries**: `plugins/sdd-dev-loop/lib/`
- **Config**: `plugins/sdd-dev-loop/config/`
- **Skills**: `plugins/sdd-dev-loop/skills/`
- **Agents**: `plugins/sdd-dev-loop/agents/`
- **Templates**: `plugins/sdd-dev-loop/templates/`
- **Session data**: `.devloop/sessions/` (runtime, gitignored)

---

## Phase 1: Core Loop Engine (Foundation)

### Phase 1.1: Setup

- [ ] T001 Create plugin directory structure for `plugins/sdd-dev-loop/` with subdirectories: `.claude-plugin/`, `commands/`, `skills/`, `agents/`, `config/`, `templates/`, `lib/`, `tests/contract/`, `tests/integration/`
  - **File**: `plugins/sdd-dev-loop/` (directory tree)
  - **Acceptance**: All directories exist per plan.md Project Structure
  - **Refs**: NFR-008, Principle XVI

- [ ] T002 Create plugin manifest at `plugins/sdd-dev-loop/.claude-plugin/plugin.json` with name, version, category, description, entrypoint, dependencies (`sdd-governance`, `sdd-specification`, `sdd-git`), permissions_required, permissions_elevated, agent/skill/command counts, and rl_metrics defaults
  - **File**: `plugins/sdd-dev-loop/.claude-plugin/plugin.json`
  - **Acceptance**: Valid JSON manifest matching SDD Plugin-First Architecture v4.1 schema; declares all dependencies
  - **Refs**: Research Decision 12, NFR-008

- [ ] T003 [P] Create `/dev-loop` bridge command at `plugins/sdd-dev-loop/commands/dev-loop.md` that accepts task description, optional `--threshold`, `--budget`, `--max-iterations`, `--mode` flags; delegates to `dev-loop-orchestrator` agent
  - **File**: `plugins/sdd-dev-loop/commands/dev-loop.md`
  - **Acceptance**: Command follows existing SDD command template format; `sync-plugin-commands.sh sync` discovers it
  - **Refs**: FR-004

- [ ] T004 [P] Create configuration files: `plugins/sdd-dev-loop/config/thresholds.json` (quality_threshold: 0.95, convergence_delta: 0.001, convergence_window: 3), `plugins/sdd-dev-loop/config/safety-limits.json` (max_iterations: 25, budget_tokens: 500000, budget_cost: 10.00, permission tiers L0-L3), `plugins/sdd-dev-loop/config/weights.json` (test_pass_rate: 0.35, coverage: 0.20, lint: 0.15, type_safety: 0.15, security: 0.10, build: 0.05, ema_alpha: 0.1)
  - **Files**: `plugins/sdd-dev-loop/config/thresholds.json`, `plugins/sdd-dev-loop/config/safety-limits.json`, `plugins/sdd-dev-loop/config/weights.json`
  - **Acceptance**: Valid JSON; weights sum to 1.0; thresholds within documented ranges
  - **Refs**: FR-015, FR-016, FR-024, FR-025, Research Decisions 3, 4, 5

### Phase 1.2: Entity Models

- [ ] T005 [P] Create DevLoopSession entity model as documented JSON schema example at `plugins/sdd-dev-loop/templates/session-state.json` with all fields from data-model.md (session_id, feature_description, branch, current_phase, iteration_count, quality_grades, tribunal_ballots, termination_reason, started_at, completed_at, scope_mode, budget_spent, budget_limit, checkpoint_path, config, status) and state transition rules (pending -> running <-> paused -> complete/failed)
  - **File**: `plugins/sdd-dev-loop/templates/session-state.json`
  - **Acceptance**: Schema matches data-model.md DevLoopSession; all validation rules documented
  - **Refs**: Data model: DevLoopSession

- [ ] T006 [P] Create QualityGrade entity model as documented JSON schema at `plugins/sdd-dev-loop/templates/quality-grade.json` with all fields (grade_id, session_id, iteration, raw_metrics, normalized_scores, weights_used, composite_grade, llm_judge_score, llm_judge_feedback, passed_threshold, threshold, timestamp) and calculation algorithm comments
  - **File**: `plugins/sdd-dev-loop/templates/quality-grade.json`
  - **Acceptance**: Schema matches data-model.md QualityGrade; weights_used.test_pass_rate >= 0.30
  - **Refs**: Data model: QualityGrade, FR-012, FR-014

- [ ] T007 [P] Create TerminationEvent entity model as documented JSON schema at `plugins/sdd-dev-loop/templates/termination-event.json` with all fields (event_id, session_id, reason enum, iteration, final_grade, checkpoint_saved, trigger_conditions for all 6 layers, details, timestamp) and priority ordering documentation
  - **File**: `plugins/sdd-dev-loop/templates/termination-event.json`
  - **Acceptance**: Schema matches data-model.md TerminationEvent; exactly one trigger_condition true per event
  - **Refs**: Data model: TerminationEvent, FR-022

### Phase 1.3: Tests First (TDD) -- MUST COMPLETE BEFORE Phase 1.4

**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation.**

- [ ] T008 [P] Contract tests for dev-loop-lifecycle: Start Session endpoint at `plugins/sdd-dev-loop/tests/contract/test_dev_loop_lifecycle.sh` -- test valid session creation with defaults, custom config overrides, INVALID_THRESHOLD error (outside 0.80-0.99), INVALID_BUDGET error (negative values), INVALID_WEIGHTS error (weights not summing to 1.0), INVALID_TASK error (empty description), NO_GIT_BASELINE error, session directory creation side effect
  - **File**: `plugins/sdd-dev-loop/tests/contract/test_dev_loop_lifecycle.sh`
  - **Acceptance**: All 8 test cases defined; tests fail before implementation; covers contract/dev-loop-lifecycle.md Start Session
  - **Refs**: Contract: dev-loop-lifecycle (Start Session), FR-004, FR-016

- [ ] T009 [P] Contract tests for dev-loop-lifecycle: Execute Iteration, Grade, Terminate, Resume, Get Status endpoints appended to `plugins/sdd-dev-loop/tests/contract/test_dev_loop_lifecycle.sh` -- test iteration execution with quality grade output, SESSION_NOT_FOUND errors, grade computation, terminate with all 6 reason types, resume from checkpoint (including CHECKPOINT_NOT_FOUND and CHECKPOINT_CORRUPTED errors), get status for running/paused/terminated sessions
  - **File**: `plugins/sdd-dev-loop/tests/contract/test_dev_loop_lifecycle.sh`
  - **Acceptance**: Tests cover all 6 lifecycle endpoints and all error cases from contract; tests fail before implementation
  - **Refs**: Contract: dev-loop-lifecycle (all 6 endpoints), FR-001, FR-028

- [ ] T010 [P] Contract tests for quality-grading at `plugins/sdd-dev-loop/tests/contract/test_quality_grading.sh` -- test Run Grade (valid grading with all 6 metrics, WORKSPACE_NOT_FOUND, GRADING_TIMEOUT), Compute Composite (valid weighted average, INVALID_METRICS, INVALID_WEIGHTS), Check Threshold (threshold met/not met, INVALID_GRADE, INVALID_THRESHOLD), Run LLM Judge (valid semantic evaluation, NO_CODE_CHANGES, LLM_FAILED)
  - **File**: `plugins/sdd-dev-loop/tests/contract/test_quality_grading.sh`
  - **Acceptance**: Tests cover all 4 quality-grading contract endpoints and all error cases; tests fail before implementation
  - **Refs**: Contract: quality-grading (all 4 endpoints), FR-012, FR-013, FR-017

- [ ] T011 [P] Contract tests for termination-engine at `plugins/sdd-dev-loop/tests/contract/test_termination_engine.sh` -- test Check All Layers (all 6 layers evaluated in priority order, first match wins), Check Convergence (convergent/non-convergent sequences, INSUFFICIENT_DATA), Check Budget (within/exceeded budget, per-model breakdown), Check Oscillation (oscillation detected/not detected, INSUFFICIENT_HISTORY), Save Checkpoint (successful save, CHECKPOINT_WRITE_FAILED, state capture verification)
  - **File**: `plugins/sdd-dev-loop/tests/contract/test_termination_engine.sh`
  - **Acceptance**: Tests cover all 5 termination-engine contract endpoints and all error cases; tests fail before implementation
  - **Refs**: Contract: termination-engine (all 5 endpoints), FR-022 through FR-028

### Phase 1.4: Core Implementation (ONLY after Phase 1.3 tests are failing)

- [ ] T012 Implement grading engine library at `plugins/sdd-dev-loop/lib/grading-engine.sh` with functions: `normalize_metric()` (normalize each of 6 metrics to 0-1 per data-model.md algorithm), `compute_composite()` (weighted average with configurable weights from config/weights.json), `check_threshold()` (compare composite grade against session threshold), `load_weights()` (read from config or session override), `validate_weights()` (ensure sum = 1.0, test_pass_rate >= 0.30)
  - **File**: `plugins/sdd-dev-loop/lib/grading-engine.sh`
  - **Acceptance**: All T010 Compute Composite and Check Threshold tests pass; weights validation enforced
  - **Refs**: FR-012, FR-013, FR-014, FR-015, Research Decision 3
  - **Depends**: T010

- [ ] T013 Implement termination engine library at `plugins/sdd-dev-loop/lib/termination-engine.sh` with functions: `check_all_layers()` (evaluate 6 layers in priority order, return first triggered), `check_convergence()` (grade improvement < delta for N consecutive iterations), `check_budget()` (cumulative tokens/cost vs limits with per-model tracking), `check_oscillation()` (code state hash comparison across iterations), `check_stuck()` (same error 3+ consecutive iterations), `save_checkpoint()` (serialize full session state to JSON file)
  - **File**: `plugins/sdd-dev-loop/lib/termination-engine.sh`
  - **Acceptance**: All T011 tests pass; 6-layer priority ordering correct; checkpoint produces valid JSON
  - **Refs**: FR-022 through FR-028, Research Decision 5
  - **Depends**: T011

- [ ] T014 Implement event logger library at `plugins/sdd-dev-loop/lib/event-logger.sh` with functions: `init_event_log()` (create JSONL file at session directory), `log_event()` (append structured event with timestamp, session_id, iteration, event_type, content, metadata), `query_events()` (filter by event_type, iteration range), `count_events()` (count by type), `close_log()` (finalize and validate JSONL integrity). Event types: thought, action, observation, decision, tool_invocation, grade, vote, error
  - **File**: `plugins/sdd-dev-loop/lib/event-logger.sh`
  - **Acceptance**: JSONL append is O(1); supports all 8 event types from data-model.md EventLog; each event has required fields
  - **Refs**: FR-043, FR-046, Research Decision 11, Data model: EventLog

- [ ] T015 Implement session management functions integrated into core loop skill: `start_session()` (create session directory, initialize DevLoopSession state, run scope analysis, initialize event log, save checkpoint_0), `iterate_session()` (read fresh context from git, execute phase actions, run tests, compute grade, evaluate termination, log events), `terminate_session()` (record TerminationEvent, save final checkpoint, generate report stub, record RL feedback), `resume_session()` (restore from checkpoint, validate state, continue from interruption point) at `plugins/sdd-dev-loop/skills/core-loop/SKILL.md`
  - **File**: `plugins/sdd-dev-loop/skills/core-loop/SKILL.md`
  - **Acceptance**: All T008 and T009 lifecycle contract tests pass; state machine transitions correct (pending -> running <-> paused -> complete/failed)
  - **Refs**: FR-001, FR-002, FR-003, FR-004, FR-005, FR-028, Research Decision 1
  - **Depends**: T005, T007, T008, T009, T012, T013, T014

- [ ] T016 Create dev-loop-orchestrator agent definition at `plugins/sdd-dev-loop/agents/dev-loop-orchestrator.md` specifying: purpose (main loop controller), model (claude-opus-4-6), tools (Read, Write, Edit, Bash, Grep, Glob, Task, TodoWrite), delegation protocol (routes to tribunal-judge for voting, quality-assessor for grading, debug-analyst for failure diagnosis), input handling (parse /dev-loop command args), and constitutional compliance (pre-flight check, Principle VI git gating)
  - **File**: `plugins/sdd-dev-loop/agents/dev-loop-orchestrator.md`
  - **Acceptance**: Agent definition follows existing SDD agent template; delegates to 3 specialist agents; enforces pre-flight protocol
  - **Refs**: FR-001, FR-004, Principle X, Principle VI

- [ ] T017 [P] Create debug-analyst agent definition at `plugins/sdd-dev-loop/agents/debug-analyst.md` specifying: purpose (failure diagnosis and fix suggestion), model (claude-opus-4-6), tools (Read, Grep, Glob, Bash), responsibilities (analyze test failures, identify root cause, suggest targeted fixes, detect stuck patterns), integration with core loop (invoked on iteration failure, produces diagnosis report for next iteration)
  - **File**: `plugins/sdd-dev-loop/agents/debug-analyst.md`
  - **Acceptance**: Agent definition follows SDD agent template; focuses on diagnosis not implementation
  - **Refs**: FR-026, Research Decision 1

### Phase 1.5: Integration

- [ ] T018 Integration test for end-to-end tactic-mode execution at `plugins/sdd-dev-loop/tests/integration/test_full_loop.sh` -- test complete flow: start session (tactic mode), iterate (plan -> implement -> test -> grade), verify termination on success/convergence/max_iterations, verify event log contains all phases, verify session report generated, verify checkpoint save/restore cycle
  - **File**: `plugins/sdd-dev-loop/tests/integration/test_full_loop.sh`
  - **Acceptance**: Full tactic-mode loop executes end-to-end; all termination conditions testable; event log complete
  - **Refs**: FR-001, FR-035, NFR-002, NFR-003, NFR-005
  - **Depends**: T012, T013, T014, T015

---

## Phase 2: Tribunal Voting System

### Phase 2.1: Entity Models

- [ ] T019 [P] Create TribunalBallot entity model as documented JSON schema at `plugins/sdd-dev-loop/templates/tribunal-ballot.md` with all fields (ballot_id, session_id, round, decision_point, claims array with anonymized model_id/assessment/confidence/reasoning, votes with per-model vote/weight/historical_success_rate, verdict, consensus_level enum, weighted_score, timestamp) and anonymization protocol documentation
  - **File**: `plugins/sdd-dev-loop/templates/tribunal-ballot.md`
  - **Acceptance**: Schema matches data-model.md TribunalBallot; anonymization protocol documented; claims.length = 3; votes entries = 3; weighted_score formula documented
  - **Refs**: Data model: TribunalBallot, FR-007

### Phase 2.2: Tests First (TDD) -- MUST COMPLETE BEFORE Phase 2.3

- [ ] T020 [P] Contract tests for tribunal-voting at `plugins/sdd-dev-loop/tests/contract/test_tribunal_voting.sh` -- test Create Ballot (valid creation with 3 models, INVALID_DECISION_POINT, EMPTY_CLAIMS, INSUFFICIENT_MODELS with < 2 available), Cast Vote (valid vote recording, ALREADY_VOTED, INVALID_CLAIM_INDEX, INVALID_CONFIDENCE), Tally Votes (majority outcome 2-of-3, unanimous 3-of-3, split 1-1-1, EMA-weighted scoring, INCOMPLETE_VOTING), Get Consensus (consensus reached, NO_CONSENSUS in degraded 2-model state, model identity de-anonymization after tally)
  - **File**: `plugins/sdd-dev-loop/tests/contract/test_tribunal_voting.sh`
  - **Acceptance**: Tests cover all 4 tribunal-voting contract endpoints and all error cases; tests fail before implementation
  - **Refs**: Contract: tribunal-voting (all 4 endpoints), FR-006 through FR-011

### Phase 2.3: Implementation (ONLY after Phase 2.2 tests are failing)

- [ ] T021 Implement multi-LLM API abstraction library at `plugins/sdd-dev-loop/lib/tribunal-api.sh` with functions: `call_claude_api()`, `call_openai_api()`, `call_gemini_api()` (provider-specific wrappers), `call_all_models_parallel()` (bash background jobs for parallel execution, wait for all), `normalize_response()` (convert provider responses to common schema: {role, content, model, tokens_used, cost}), `load_api_keys()` (read from .env: ANTHROPIC_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY), `check_model_availability()` (health check each provider), `handle_provider_failure()` (graceful degradation: continue with 2/3, halt at 1/3)
  - **File**: `plugins/sdd-dev-loop/lib/tribunal-api.sh`
  - **Acceptance**: Parallel execution verified (latency = max(individual), not sum); graceful degradation tested; API keys loaded from .env
  - **Refs**: FR-010, FR-011, NFR-001, Research Decision 10
  - **Depends**: T020

- [ ] T022 Implement tribunal voting skill at `plugins/sdd-dev-loop/skills/tribunal-vote/SKILL.md` with operations: create ballot (anonymize model identities, query all models in parallel via tribunal-api.sh), cast votes (record anonymized assessments), tally votes (apply EMA-weighted scoring from RL metrics, determine majority/unanimous/split), get consensus (de-anonymize after verdict, produce final decision with confidence score). Include EMA vote weighting formula: weighted_score = sum(confidence[i] * weight[i]) / sum(weight[i])
  - **File**: `plugins/sdd-dev-loop/skills/tribunal-vote/SKILL.md`
  - **Acceptance**: All T020 tribunal-voting contract tests pass; anonymization verified (model identity hidden during review); EMA weighting applied correctly
  - **Refs**: FR-006, FR-007, FR-008, FR-009, Research Decision 2
  - **Depends**: T019, T020, T021

- [ ] T023 [P] Create tribunal-judge agent definition at `plugins/sdd-dev-loop/agents/tribunal-judge.md` specifying: purpose (tribunal voting orchestration), model (claude-opus-4-6 for primary assessments; GPT-4o and Gemini 2.5 Pro for cross-validation), tools (Read, Grep, WebSearch), responsibilities (assess research directions, evaluate implementation approaches, resolve quality disputes), anonymization enforcement (presents claims without model attribution), integration with dev-loop-orchestrator (invoked at tribunal checkpoints in strategy mode)
  - **File**: `plugins/sdd-dev-loop/agents/tribunal-judge.md`
  - **Acceptance**: Agent definition follows SDD agent template; specifies all 3 tribunal models; documents anonymization protocol
  - **Refs**: FR-006, FR-007, Principle X, Research Decision 2

### Phase 2.4: Integration

- [ ] T024 Integration test for tribunal end-to-end flow at `plugins/sdd-dev-loop/tests/integration/test_tribunal_end_to_end.sh` -- test: create ballot with 3 models, parallel API call execution, anonymized assessment collection, EMA-weighted vote tallying, consensus determination, model identity reveal after verdict, graceful degradation with 1 model failure (continue 2/3), graceful halt with 2 model failures (save checkpoint)
  - **File**: `plugins/sdd-dev-loop/tests/integration/test_tribunal_end_to_end.sh`
  - **Acceptance**: End-to-end tribunal flow completes; parallel execution verified; degradation tested for 1-failure and 2-failure scenarios
  - **Refs**: FR-006 through FR-011, NFR-001
  - **Depends**: T021, T022

---

## Phase 3: Safety & Sandboxing

### Phase 3.1: Tests First (TDD) -- MUST COMPLETE BEFORE Phase 3.2

- [ ] T025 [P] Tests for permission enforcement and sandbox at `plugins/sdd-dev-loop/tests/contract/test_permissions_sandbox.sh` -- test L0 read-only operations (always permitted), L1 safe write operations (workspace-only writes permitted), L2 network/VCS operations (session-level approval required), L3 high-risk operations (per-action approval required, always blocked without explicit approval), git branch create/switch/delete blocked during execution (FR-031), git push blocked without per-action approval (FR-032), resource limit enforcement (memory, CPU, disk bounds)
  - **File**: `plugins/sdd-dev-loop/tests/contract/test_permissions_sandbox.sh`
  - **Acceptance**: Tests cover all 4 permission tiers; git branch blocking verified; git push gating verified; resource limits tested; tests fail before implementation
  - **Refs**: FR-029 through FR-033, Research Decision 7

### Phase 3.2: Implementation (ONLY after Phase 3.1 tests are failing)

- [ ] T026 Implement permission enforcement library at `plugins/sdd-dev-loop/lib/permissions.sh` with functions: `check_permission()` (evaluate operation against L0-L3 tiers, return allowed/denied/needs_approval), `get_tier_for_operation()` (classify operation into L0/L1/L2/L3 based on config/safety-limits.json), `is_git_branch_op()` (detect git branch create/switch/delete and block), `is_git_push_op()` (detect git push and require per-action approval), `request_approval()` (prompt user for L2/L3 operations), `load_session_permissions()` (read approved permissions for current session), `grant_session_permission()` (record L2 session-level grant)
  - **File**: `plugins/sdd-dev-loop/lib/permissions.sh`
  - **Acceptance**: T025 permission tests pass; L0-L3 tiers correctly enforced; git branch ops always blocked; git push always requires approval
  - **Refs**: FR-029, FR-030, FR-031, FR-032, Research Decision 7
  - **Depends**: T004, T025

- [ ] T027 Implement sandbox configuration library at `plugins/sdd-dev-loop/lib/sandbox.sh` with functions: `setup_docker_sandbox()` (create Docker container with non-root UID 1000, read-only root FS, writable /workspace volume, network restrictions to allowlisted domains, resource limits: 2GB RAM, 1 CPU, 10GB disk), `setup_os_sandbox()` (macOS: seatbelt profile; Linux: bubblewrap + seccomp), `detect_sandbox_method()` (check Docker availability, fallback to OS-level), `enforce_resource_limits()` (memory/CPU/disk bounds per iteration), `teardown_sandbox()` (cleanup container or sandbox profile), `validate_workspace_boundary()` (verify all file operations within workspace)
  - **File**: `plugins/sdd-dev-loop/lib/sandbox.sh`
  - **Acceptance**: T025 resource limit tests pass; Docker sandbox creates container with documented restrictions; OS-level fallback works on macOS and Linux
  - **Refs**: FR-029, FR-033, Research Decision 6, NFR-008
  - **Depends**: T025

- [ ] T028 Integrate safety layer into core loop skill -- update `plugins/sdd-dev-loop/skills/core-loop/SKILL.md` to: wrap iteration execution in sandbox (Docker or OS-level), check permissions before every tool invocation via permissions.sh, block L3 operations without approval, enforce resource limits per iteration, log all permission checks to event stream
  - **File**: `plugins/sdd-dev-loop/skills/core-loop/SKILL.md` (update)
  - **Acceptance**: Core loop respects sandbox boundaries; permission checks logged; no L3 operations without explicit approval
  - **Refs**: FR-005, FR-029, FR-030
  - **Depends**: T015, T026, T027

---

## Phase 4: Intelligence (Quality Grading, RL, Scope Detection)

### Phase 4.1: Entity Models

- [ ] T029 [P] Create RLMetrics entity model as documented JSON schema at `plugins/sdd-dev-loop/templates/rl-metrics.json` with all fields (skill_name, model_name, success_rate, selection_weight, invocation_count, avg_tokens, avg_duration_ms, last_feedback, ema_alpha, history, per_task_type) and EMA update algorithm documentation
  - **File**: `plugins/sdd-dev-loop/templates/rl-metrics.json`
  - **Acceptance**: Schema matches data-model.md RLMetrics; EMA formula documented; selection_weight clamped to [0.1, 1.0]
  - **Refs**: Data model: RLMetrics, FR-018

- [ ] T030 [P] Create ScopeAnalysis entity model as documented JSON schema at `plugins/sdd-dev-loop/templates/scope-analysis.json` with all fields (analysis_id, input_description, detected_scope, keyword_scores, signals with tactic/strategy keywords and file_count_estimate and cross_cutting_concerns, confidence, override_by_user, final_scope, timestamp) and classification algorithm documentation
  - **File**: `plugins/sdd-dev-loop/templates/scope-analysis.json`
  - **Acceptance**: Schema matches data-model.md ScopeAnalysis; tactic/strategy keyword lists documented; scoring formula documented
  - **Refs**: Data model: ScopeAnalysis, FR-034

### Phase 4.2: Tests First (TDD) -- MUST COMPLETE BEFORE Phase 4.3

- [ ] T031 [P] Contract tests for quality-grading Run Grade and LLM Judge endpoints (supplement to T010 composite/threshold tests) at `plugins/sdd-dev-loop/tests/contract/test_quality_grading.sh` (append) -- test Run Grade full pipeline (execute test suite, collect all 6 raw metrics, normalize, compute composite, check threshold, GRADING_TIMEOUT at 30s), Run LLM Judge (semantic evaluation with readability/architecture/compliance aspects, NO_CODE_CHANGES error, LLM_FAILED error)
  - **File**: `plugins/sdd-dev-loop/tests/contract/test_quality_grading.sh` (append)
  - **Acceptance**: Full Run Grade pipeline tested including metric collection; LLM Judge tests cover all error cases; 30s timeout enforced
  - **Refs**: Contract: quality-grading (Run Grade, LLM Judge), FR-013, FR-017, NFR-005
  - **Depends**: T010

- [ ] T032 [P] Tests for scope detection at `plugins/sdd-dev-loop/tests/contract/test_scope_detection.sh` -- test tactic classification ("fix the typo in README" -> tactic), strategy classification ("implement OAuth2 with RBAC" -> strategy), ambiguous cases default to tactic, user override to force strategy, user override to force tactic, confidence scoring (high confidence > 0.8, low confidence < 0.6 triggers clarification), cross-cutting concern detection (multiple domains -> strategy bias), file count heuristic (1-2 files -> tactic bias, 6+ -> strategy bias), NFR-006 scope detection < 5 seconds
  - **File**: `plugins/sdd-dev-loop/tests/contract/test_scope_detection.sh`
  - **Acceptance**: Tests cover all scope detection scenarios from spec acceptance scenarios 6 and 7; classification within 5s; tests fail before implementation
  - **Refs**: FR-034 through FR-037, NFR-006, Research Decision 8

- [ ] T033 [P] Tests for RL feedback at `plugins/sdd-dev-loop/tests/contract/test_rl_feedback.sh` -- test EMA update (success: new_rate = 0.9 * old + 0.1 * 1; failure: new_rate = 0.9 * old + 0.1 * 0), selection_weight clamping [0.1, 1.0], UCB1 score calculation, invocation count increment, per-task-type breakdown update, integration with existing `.docs/rl-metrics/skill-performance.json`, metrics persistence across sessions
  - **File**: `plugins/sdd-dev-loop/tests/contract/test_rl_feedback.sh`
  - **Acceptance**: EMA formula verified; clamping enforced; UCB1 formula correct; metrics persist to disk; tests fail before implementation
  - **Refs**: FR-018 through FR-021, Research Decision 4

### Phase 4.3: Implementation (ONLY after Phase 4.2 tests are failing)

- [ ] T034 Implement full quality grading pipeline in `plugins/sdd-dev-loop/lib/grading-engine.sh` (extend T012) -- add `run_grade()` function that: executes test suite and captures pass/fail/coverage, runs lint tool and counts errors, runs type checker and counts errors, runs security scanner (critical/high/medium/low counts), checks build status, normalizes all 6 metrics, computes composite grade, checks threshold, enforces 30s timeout (NFR-005), logs grade event to event stream
  - **File**: `plugins/sdd-dev-loop/lib/grading-engine.sh` (extend)
  - **Acceptance**: All T010 and T031 tests pass; all 6 metrics collected and normalized per data-model.md algorithm; 30s timeout enforced
  - **Refs**: FR-012, FR-013, FR-014, FR-015, NFR-005
  - **Depends**: T012, T031

- [ ] T035 [P] Implement quality-assessor agent definition at `plugins/sdd-dev-loop/agents/quality-assessor.md` specifying: purpose (quality grading orchestration and LLM-as-Judge evaluation), model (claude-opus-4-6), tools (Read, Bash, Grep), responsibilities (invoke grading-engine.sh for automated metrics, perform semantic evaluation for readability/architecture/compliance, produce QualityGrade entity, report grade to orchestrator), integration with core loop (invoked after each iteration's test phase)
  - **File**: `plugins/sdd-dev-loop/agents/quality-assessor.md`
  - **Acceptance**: Agent definition follows SDD agent template; documents both automated and semantic evaluation responsibilities
  - **Refs**: FR-012, FR-017, Principle X

- [ ] T036 Implement scope detection library at `plugins/sdd-dev-loop/lib/scope-detector.sh` with functions: `analyze_scope()` (accept task description, return ScopeAnalysis entity), `score_keywords()` (tactic keywords weight -1.0 each, strategy keywords weight +1.0 each per Research Decision 8), `estimate_file_count()` (regex analysis of description: 1-2 files -> -0.5, 3-5 -> 0, 6+ -> +0.5), `detect_cross_cutting()` (multiple domain mentions -> +1.0), `classify_scope()` (total_score <= -0.5 -> tactic, >= 0.5 -> strategy, else tactic default), `apply_override()` (user --mode flag overrides classification)
  - **File**: `plugins/sdd-dev-loop/lib/scope-detector.sh`
  - **Acceptance**: All T032 tests pass; classification within 5s (NFR-006); ambiguous defaults to tactic; override works
  - **Refs**: FR-034, FR-035, FR-036, FR-037, Research Decision 8
  - **Depends**: T030, T032

- [ ] T037 Implement scope-analysis skill at `plugins/sdd-dev-loop/skills/scope-analysis/SKILL.md` documenting: purpose (tactic vs strategy routing), invocation (called by dev-loop-orchestrator at session start), inputs (task description, optional --mode override), outputs (ScopeAnalysis entity, routing decision), workflow routing (tactic: plan -> implement -> test -> grade; strategy: research -> tribunal -> specify -> plan -> tasks -> implement -> test -> grade), integration with /specification workflow for strategy mode
  - **File**: `plugins/sdd-dev-loop/skills/scope-analysis/SKILL.md`
  - **Acceptance**: Skill definition follows SDD skill template; routing logic matches spec FR-035/FR-036
  - **Refs**: FR-034, FR-035, FR-036, FR-037
  - **Depends**: T036

- [ ] T038 Implement RL feedback library at `plugins/sdd-dev-loop/lib/rl-metrics.sh` with functions: `update_ema()` (new_rate = (1 - alpha) * old_rate + alpha * outcome; alpha = 0.1), `clamp_weight()` (clamp selection_weight to [0.1, 1.0]), `compute_ucb1()` (success_rate + sqrt(2 * ln(total) / count)), `record_feedback()` (update skill/model metrics after session), `load_metrics()` (read from `.docs/rl-metrics/skill-performance.json`), `save_metrics()` (write updated metrics), `update_per_task_type()` (track tactic/strategy breakdown), `select_skill()` (use UCB1 for exploration-exploitation)
  - **File**: `plugins/sdd-dev-loop/lib/rl-metrics.sh`
  - **Acceptance**: All T033 tests pass; EMA formula correct; UCB1 formula correct; metrics integrate with existing RL system
  - **Refs**: FR-018, FR-019, FR-020, FR-021, Research Decision 4
  - **Depends**: T033

- [ ] T039 [P] Implement rl-feedback skill at `plugins/sdd-dev-loop/skills/rl-feedback/SKILL.md` documenting: purpose (performance tracking and learning), invocation (called by dev-loop-orchestrator at session end), inputs (session outcome, skills used, models used, task type), outputs (updated RLMetrics), algorithm (EMA update for all skills/models, UCB1 for future selection), integration with existing `.docs/rl-metrics/` and `.claude/skill-index.json`
  - **File**: `plugins/sdd-dev-loop/skills/rl-feedback/SKILL.md`
  - **Acceptance**: Skill definition follows SDD skill template; integrates with existing RL metrics system
  - **Refs**: FR-018, FR-020

---

## Phase 5: Observability (Event Sourcing & Reporting)

### Phase 5.1: Tests First (TDD) -- MUST COMPLETE BEFORE Phase 5.2

- [ ] T040 [P] Tests for event sourcing and session reports at `plugins/sdd-dev-loop/tests/contract/test_event_sourcing.sh` -- test event logging (all 8 event types: thought, action, observation, decision, tool_invocation, grade, vote, error), JSONL format validation (each line is valid JSON), chronological ordering, event query by type/iteration, session report generation (includes iteration count, grade trajectory, tribunal decisions, resources consumed per model, cost, wall-clock time, code changes summary, termination reason), session replay (reconstruct state from events), NFR-007 performance with 50 iterations
  - **File**: `plugins/sdd-dev-loop/tests/contract/test_event_sourcing.sh`
  - **Acceptance**: Tests cover all 8 event types; JSONL format verified; report includes all required fields from FR-044; replay produces consistent state; tests fail before implementation
  - **Refs**: FR-043, FR-044, FR-045, FR-046, NFR-007, Research Decision 11

### Phase 5.2: Implementation (ONLY after Phase 5.1 tests are failing)

- [ ] T041 Implement session report generator at `plugins/sdd-dev-loop/skills/session-report/SKILL.md` with template at `plugins/sdd-dev-loop/templates/session-report.md` -- generate comprehensive report from event log including: total iterations, quality grade trajectory (with per-iteration scores), all tribunal decisions (with ballot details), total tokens consumed per model, total cost per model, wall-clock time, code changes summary (files modified, lines added/removed), termination reason, RL feedback recorded, resource efficiency metrics
  - **File**: `plugins/sdd-dev-loop/skills/session-report/SKILL.md`, `plugins/sdd-dev-loop/templates/session-report.md`
  - **Acceptance**: T040 session report tests pass; report matches FR-044 requirements; report readable by non-technical stakeholders
  - **Refs**: FR-044, US-004
  - **Depends**: T014, T040

- [ ] T042 Implement session replay capability in `plugins/sdd-dev-loop/lib/event-logger.sh` (extend T014) -- add `replay_session()` function that reads JSONL event log and reconstructs session state at any given iteration or timestamp, `extract_rl_signals()` function that connects session outcomes to specific skills/models via event log analysis, `generate_audit_trail()` function that produces chronological record of all autonomous actions for security review
  - **File**: `plugins/sdd-dev-loop/lib/event-logger.sh` (extend)
  - **Acceptance**: T040 replay tests pass; state reconstruction is deterministic; RL signals correctly extracted from events
  - **Refs**: FR-045, FR-046
  - **Depends**: T014, T040

- [ ] T043 Implement LLM-as-Judge quality evaluation in `plugins/sdd-dev-loop/lib/grading-engine.sh` (extend T034) -- add `run_llm_judge()` function that: sends code changes and spec requirements to AI model, evaluates readability/architecture/compliance aspects, returns semantic_grade (0-1), commentary, per-aspect scores, optionally integrates into composite grade as 7th dimension (weight 0.10, redistributing other weights proportionally)
  - **File**: `plugins/sdd-dev-loop/lib/grading-engine.sh` (extend)
  - **Acceptance**: T031 LLM Judge tests pass; semantic evaluation produces structured output per quality-grading contract
  - **Refs**: FR-017, Research Decision 3
  - **Depends**: T034, T031

---

## Phase 6: Self-Extension

### Phase 6.1: Entity Models

- [ ] T044 [P] Create PluginManifest (self-created) entity model as documented JSON schema at `plugins/sdd-dev-loop/templates/gap-analysis.md` with: gap detection template (missing_capability, frequency, impact, suggested_plugin_name, confidence), plugin manifest fields (name with sdd-tool- prefix, version 0.1.0, description, author "devloop-selfgen", entrypoint, parameters, permissions_required, created_by_session, quarantine_status lifecycle, constitutional_review fields, rl_metrics defaults)
  - **File**: `plugins/sdd-dev-loop/templates/gap-analysis.md`
  - **Acceptance**: Template matches data-model.md PluginManifest; quarantine lifecycle documented (pending -> testing -> passed/failed); sdd-tool- naming enforced
  - **Refs**: Data model: PluginManifest, FR-039

### Phase 6.2: Tests First (TDD) -- MUST COMPLETE BEFORE Phase 6.3

- [ ] T045 [P] Contract tests for self-extension at `plugins/sdd-dev-loop/tests/contract/test_self_extension.sh` -- test Detect Gap (gap detected with frequency >= 3, no gap with low frequency, EMPTY_ERROR_LOG, recurring pattern identification), Scaffold Plugin (valid scaffold with plugin.json + skill + test stubs, INVALID_NAME for non-sdd-tool prefix, CAPABILITY_TOO_VAGUE), Quarantine Validate (all-pass scenario, security scan failure, test coverage < 80% failure, constitutional review failure with principle violations, PLUGIN_NOT_FOUND), Register Plugin (successful registration moves from quarantine to plugins/, VALIDATION_NOT_PASSED error, ALREADY_REGISTERED error, MANIFEST_INVALID error, plugin bridge sync triggered)
  - **File**: `plugins/sdd-dev-loop/tests/contract/test_self_extension.sh`
  - **Acceptance**: Tests cover all 4 self-extension contract endpoints and all error cases; quarantine lifecycle fully tested; tests fail before implementation
  - **Refs**: Contract: self-extension (all 4 endpoints), FR-038 through FR-042

### Phase 6.3: Implementation (ONLY after Phase 6.2 tests are failing)

- [ ] T046 Implement gap detection skill at `plugins/sdd-dev-loop/skills/self-extend/SKILL.md` with: `detect_gap()` (analyze session error log for recurring patterns, frequency >= 3 occurrences triggers gap detection, classify impact as low/medium/high, suggest plugin name following sdd-tool-{name} convention, compute confidence score), integration with event logger (read error events from JSONL log)
  - **File**: `plugins/sdd-dev-loop/skills/self-extend/SKILL.md`
  - **Acceptance**: T045 Detect Gap tests pass; gaps with frequency >= 3 detected; impact classification correct
  - **Refs**: FR-038, Research Decision 9
  - **Depends**: T014, T044, T045

- [ ] T047 Implement plugin scaffolding and quarantine validation in `plugins/sdd-dev-loop/skills/self-extend/SKILL.md` (extend T046) -- add scaffold_plugin() (use /create-plugin workflow to generate plugin structure at `.devloop/quarantine/{plugin_name}/` with plugin.json, SKILL.md, agent.md, test stubs; author = "devloop-selfgen"), validate_quarantine() (run automated test suite checking > 80% coverage, security scan for 0 critical/high vulnerabilities, constitutional review by LLM governor checking all 16 principles, return validation results with pass/fail per check)
  - **File**: `plugins/sdd-dev-loop/skills/self-extend/SKILL.md` (extend)
  - **Acceptance**: T045 Scaffold and Quarantine Validate tests pass; scaffolded plugins follow SDD v4.1 conventions; constitutional review checks all 16 principles
  - **Refs**: FR-039, FR-040, FR-041, NFR-009, Research Decision 9
  - **Depends**: T046

- [ ] T048 Implement plugin registration in `plugins/sdd-dev-loop/skills/self-extend/SKILL.md` (extend T047) -- add register_plugin() (move validated plugin from `.devloop/quarantine/` to `plugins/`, update plugin registry, sync commands via sync-plugin-commands.sh, initialize RL metrics at success_rate: 0.5, selection_weight: 0.5, invocation_count: 0, record registration in event log, make plugin available for immediate use without restart)
  - **File**: `plugins/sdd-dev-loop/skills/self-extend/SKILL.md` (extend)
  - **Acceptance**: T045 Register Plugin tests pass; plugin moved from quarantine to plugins/; command bridge synced; RL metrics initialized; plugin immediately usable
  - **Refs**: FR-042, Research Decision 9
  - **Depends**: T047

### Phase 6.4: Integration

- [ ] T049 Integration test for full self-extension lifecycle at `plugins/sdd-dev-loop/tests/integration/test_self_extension_lifecycle.sh` -- test complete flow: simulate recurring capability gap (3+ error occurrences), detect gap, scaffold plugin in quarantine, run quarantine validation (tests, security, constitutional review), register validated plugin, verify plugin appears in `plugins/` directory, verify command bridge sync, verify RL metrics initialized, verify plugin usable in subsequent iteration. Also test failure path: scaffold plugin that fails security scan, verify it remains in quarantine with "failed" status
  - **File**: `plugins/sdd-dev-loop/tests/integration/test_self_extension_lifecycle.sh`
  - **Acceptance**: Full self-extension lifecycle executes end-to-end; both success and failure paths verified; quarantine isolation maintained
  - **Refs**: FR-038 through FR-042, NFR-009
  - **Depends**: T046, T047, T048

---

## Dependencies

### Phase Dependencies
```
Phase 1 (Core Loop)     -- no dependencies (foundation)
Phase 2 (Tribunal)      -- depends on Phase 1 complete (T001-T018)
Phase 3 (Safety)        -- depends on Phase 1 complete (T001-T018)
Phase 4 (Intelligence)  -- depends on Phase 1 complete (T001-T018)
Phase 5 (Observability) -- depends on Phase 1 complete (T001-T018)
Phase 6 (Self-Extension) -- depends on Phase 3 (T025-T028) AND Phase 4 (T029-T039) complete
```

### Intra-Phase Task Dependencies

**Phase 1:**
```
T001 -> T002 -> T003, T004 (T003, T004 parallel)
T005, T006, T007 (all parallel, no deps except T001)
T008, T009, T010, T011 (all parallel tests)
T012 -> depends on T010
T013 -> depends on T011
T014 (independent)
T015 -> depends on T005, T007, T008, T009, T012, T013, T014
T016 -> depends on T015
T017 (parallel with T016)
T018 -> depends on T012, T013, T014, T015
```

**Phase 2:**
```
T019 (parallel entity model)
T020 (parallel test)
T021 -> depends on T020
T022 -> depends on T019, T020, T021
T023 (parallel with T022)
T024 -> depends on T021, T022
```

**Phase 3:**
```
T025 (parallel test)
T026 -> depends on T004, T025
T027 -> depends on T025
T028 -> depends on T015, T026, T027
```

**Phase 4:**
```
T029, T030 (parallel entity models)
T031, T032, T033 (all parallel tests)
T034 -> depends on T012, T031
T035 (parallel agent definition)
T036 -> depends on T030, T032
T037 -> depends on T036
T038 -> depends on T033
T039 (parallel skill definition)
```

**Phase 5:**
```
T040 (parallel test)
T041 -> depends on T014, T040
T042 -> depends on T014, T040
T043 -> depends on T034, T031
```

**Phase 6:**
```
T044 (parallel entity model)
T045 (parallel test)
T046 -> depends on T014, T044, T045
T047 -> depends on T046
T048 -> depends on T047
T049 -> depends on T046, T047, T048
```

### Full Dependency Graph

```
T001 ──> T002 ──> T003 [P]
    |         └──> T004 [P] ──────────────────────────────> T026
    |
    ├──> T005 [P] ──────────────────────────> T015
    ├──> T006 [P]
    ├──> T007 [P] ──────────────────────────> T015
    |
    ├──> T008 [P] ──────────────────────────> T015
    ├──> T009 [P] ──────────────────────────> T015
    ├──> T010 [P] ──> T012 ──> T015          T034
    |                       └──> T018              └──> T043
    ├──> T011 [P] ──> T013 ──> T015
    |                       └──> T018
    |
    |              T014 ──> T015, T018, T041, T042, T046
    |
    |   T015 ──> T016 ──> (agents ready)
    |        └──> T017 [P]
    |        └──> T018
    |        └──> T028
    |
    |   === PHASE 2 (after Phase 1) ===
    |
    ├──> T019 [P] ──> T022
    ├──> T020 [P] ──> T021 ──> T022 ──> T024
    |                       └──> T024
    ├──> T023 [P]
    |
    |   === PHASE 3 (after Phase 1) ===
    |
    ├──> T025 [P] ──> T026 ──> T028
    |              └──> T027 ──> T028
    |
    |   === PHASE 4 (after Phase 1) ===
    |
    ├──> T029 [P]
    ├──> T030 [P] ──> T036 ──> T037
    ├──> T031 [P] ──> T034 ──> T043
    ├──> T032 [P] ──> T036
    ├──> T033 [P] ──> T038
    ├──> T035 [P]
    ├──> T039 [P]
    |
    |   === PHASE 5 (after Phase 1) ===
    |
    ├──> T040 [P] ──> T041, T042
    |
    |   === PHASE 6 (after Phase 3 + Phase 4) ===
    |
    ├──> T044 [P] ──> T046 ──> T047 ──> T048 ──> T049
    └──> T045 [P] ──> T046
```

---

## Parallel Execution Examples

### Example 1: Phase 1 Setup (4 tasks, 2 parallel groups)
```
# Group 1: Sequential setup
T001 -> T002

# Group 2: Parallel after T002
Launch T003, T004 together (different files, no interdependency)
```

### Example 2: Phase 1 Entity Models (3 tasks, all parallel)
```
# All entity models touch different template files
Launch T005, T006, T007 together
```

### Example 3: Phase 1 Contract Tests (4 tasks, all parallel)
```
# All tests touch different test files
Launch T008, T009, T010, T011 together
```

### Example 4: Cross-Phase Parallel (Phases 2-5 after Phase 1)
```
# After Phase 1 completes, these phases are independent of each other:
Phase 2 starts: T019, T020 (parallel entity + test)
Phase 3 starts: T025 (test)
Phase 4 starts: T029, T030, T031, T032, T033 (parallel entities + tests)
Phase 5 starts: T040 (test)

# Maximum parallelism: up to 9 tasks simultaneously
Launch T019, T020, T025, T029, T030, T031, T032, T033, T040
```

### Example 5: Phase 4 Intelligence (6 tasks in 2 waves)
```
# Wave 1: Parallel tests and entity models
Launch T029, T030, T031, T032, T033, T035, T039 together (all [P])

# Wave 2: Implementations (after tests ready)
T034 (after T031), T036 (after T030+T032), T038 (after T033) -- can run in parallel
T037 (after T036)
```

---

## Notes

- [P] tasks = different files, no dependencies -- safe for parallel execution
- Verify tests FAIL before implementing (TDD enforcement)
- All bash libraries (`lib/*.sh`) must be sourced, not executed directly
- Config files (`config/*.json`) are read-only during execution; overrides via session config
- Session data (`.devloop/sessions/`) is runtime-only and gitignored
- Quarantine data (`.devloop/quarantine/`) is runtime-only and gitignored
- All file paths are relative to repository root
- Constitutional compliance: every task respects Principle II (Test-First), VI (Git Approval), X (Delegation), XVI (Plugin-First)

---

## Task Generation Rules
*Applied during main() execution*

1. **From Contracts** (5 contracts, 23 endpoints):
   - dev-loop-lifecycle (6 endpoints) -> T008, T009 (tests), T015 (implementation)
   - tribunal-voting (4 endpoints) -> T020 (tests), T022 (implementation)
   - quality-grading (4 endpoints) -> T010, T031 (tests), T012, T034, T043 (implementation)
   - termination-engine (5 endpoints) -> T011 (tests), T013 (implementation)
   - self-extension (4 endpoints) -> T045 (tests), T046, T047, T048 (implementation)

2. **From Data Model** (8 entities):
   - DevLoopSession -> T005
   - TribunalBallot -> T019
   - QualityGrade -> T006
   - TerminationEvent -> T007
   - PluginManifest -> T044
   - EventLog -> T014 (implemented as library)
   - RLMetrics -> T029
   - ScopeAnalysis -> T030

3. **From Research Decisions** (12 decisions):
   - Decision 1 (Core Loop) -> T015
   - Decision 2 (Tribunal) -> T022, T023
   - Decision 3 (Quality Grading) -> T012, T034, T043
   - Decision 4 (RL Feedback) -> T038
   - Decision 5 (Termination) -> T013
   - Decision 6 (Sandboxing) -> T027
   - Decision 7 (Permissions) -> T026
   - Decision 8 (Scope Detection) -> T036
   - Decision 9 (Self-Extension) -> T046, T047, T048
   - Decision 10 (Multi-LLM) -> T021
   - Decision 11 (Event Sourcing) -> T014, T042
   - Decision 12 (Plugin Structure) -> T001, T002

4. **Ordering**:
   - Setup -> Tests -> Entity Models -> Libraries -> Skills/Agents -> Integration Tests
   - TDD: Tests always precede implementation within each phase
   - Dependencies block parallel execution within constraint graph

---

## Validation Checklist
*GATE: Checked by main() before returning*

- [x] All 23 contract endpoints have corresponding tests (T008-T011, T020, T031, T032, T033, T040, T045)
- [x] All 23 contract endpoints have corresponding implementations (T012-T015, T021-T022, T034, T036, T038, T041-T043, T046-T048)
- [x] All 8 entities have model/schema tasks (T005, T006, T007, T014, T019, T029, T030, T044)
- [x] All tests come before implementation in each phase (Phase 1: T008-T011 before T012-T015; Phase 2: T020 before T021-T022; Phase 3: T025 before T026-T027; Phase 4: T031-T033 before T034-T038; Phase 5: T040 before T041-T043; Phase 6: T045 before T046-T048)
- [x] Parallel tasks truly independent (different files, no shared state)
- [x] Each task specifies exact file path(s)
- [x] No task modifies same file as another [P] task
- [x] All 12 research decisions traced to implementation tasks
- [x] All 46 functional requirements covered
- [x] All 9 non-functional requirements addressed

---

## SSOT Synchronization

### Status Markers

| Marker | Meaning | When to Use |
|--------|---------|-------------|
| `- [ ]` | Not started | Initial state |
| `- [x]` | Completed | Task finished and verified |
| `- [~]` | In progress | Currently being worked on |
| `- [!]` | Blocked | Cannot proceed (document reason) |

### Completion Protocol

When completing a task:

1. **Update TodoWrite** - Mark task as `completed` immediately
2. **Update this file** - Change `[ ]` to `[x]`
3. **Record in agent decisions** - Log completion details
4. **Verify** - Run any validation scripts

### Cross-Session Continuity

When resuming work on this feature:

1. Review this file for incomplete tasks (`[ ]` items)
2. Check `.docs/agents/*/decisions/tasks/` for context
3. Create TodoWrite list from next incomplete tasks
4. Continue execution

### Completion Summary

*Updated as tasks complete*

| Phase | Total | Completed | Remaining |
|-------|-------|-----------|-----------|
| Phase 1: Core Loop | 18 | 0 | 18 |
| Phase 2: Tribunal | 6 | 0 | 6 |
| Phase 3: Safety | 4 | 0 | 4 |
| Phase 4: Intelligence | 11 | 0 | 11 |
| Phase 5: Observability | 4 | 0 | 4 |
| Phase 6: Self-Extension | 6 | 0 | 6 |
| **Total** | **49** | **0** | **49** |

### Audit Log

*Record significant task events*

| Date | Task | Event | Agent/User |
|------|------|-------|------------|
| | | | |

---
*Based on Constitution v3.0.0 - See `.specify/memory/constitution.md`*
*Generated from: spec.md (46 FR + 9 NFR), plan.md (6 phases), data-model.md (8 entities), research.md (12 decisions, 38 claims), 5 contracts (23 endpoints)*
