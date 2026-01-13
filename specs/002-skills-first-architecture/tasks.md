# Task List: Skills-First Architecture with RL and DS-STAR Integration

**Feature**: 002-skills-first-architecture
**SSOT**: This file is the Single Source of Truth for feature implementation tasks.
**Input**: Design documents from `/specs/002-skills-first-architecture/`
**Prerequisites**: plan.md (v2.0.0), research.md (v2.0.0), data-model.md (v2.0.0), contracts/ (6 files), quickstart.md (v2.0.0)
**Policy**: See `.docs/policies/todo-architecture-policy.md` for task management standards.
**Generated**: 2026-01-13
**Task Version**: 2.0.0 (aligned with plan v2.0.0)
**Total Tasks**: 68
**Parallel Tasks**: [P] marker indicates tasks that can run in parallel after dependencies met
**Timeline**: 12-month phased migration

---

## SSOT Task Architecture

```
PROJECT LEVEL (This File)          SESSION LEVEL (TodoWrite)
+--------------------------+        +--------------------------+
| specs/002-skills-first/  |   -->  | Claude Code TodoWrite    |
|     tasks.md             |        | (real-time tracking)     |
| - Persists in git        |   <--  | - Session-scoped         |
| - Full task list         |        | - Active work focus      |
| - Check off when done    |        | - One in_progress task   |
+--------------------------+        +--------------------------+
```

---

## Constitutional Compliance

**TDD Ordering** (Principle II):
- Contract tests (T001-T006) MUST complete before entity implementations
- Unit tests precede implementations within each task
- Integration tests validate cross-component behavior

**Contract-First** (Principle III):
- All 6 contracts tested before implementation begins
- Schema validation enforced throughout

**Library-First** (Principle I):
- Progressive disclosure loader implemented as standalone library
- RL algorithms implemented as reusable modules

**FR-707 Compliance**:
- Task T007 creates message-preflight skill early in Phase 1
- All subsequent tasks assume compliance check infrastructure exists

---

## Task Summary by Phase

| Phase | Tasks | Timeline | Key Deliverables |
|-------|-------|----------|------------------|
| Phase 1: Foundation + RL Foundation | T001-T022 | Months 1-3 | Contract tests, skill-index v3, RL infrastructure, progressive disclosure |
| Phase 2: Agent Consolidation | T023-T040 | Months 4-6 | 8 consolidated agents, agent-index.json, skill portfolio mappings |
| Phase 3: Constitutional Amendment + Advanced RL | T041-T054 | Months 7-9 | Principle X rewrite, skill-activation-triggers.md, advanced RL |
| Phase 4: Migration Completion | T055-T068 | Months 10-12 | 35+ skills, legacy blocking, Constitution v2.0.0, validation |

---

## Phase 1: Foundation + RL Foundation (Months 1-3)

### Contract Tests (TDD First - All Parallel)

**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

- [ ] **T001** [P] Contract Test - skill-definition.yaml v3
  - File: `tests/contracts/test_skill_definition_v3.test.js`
  - Validates: SKILL.md frontmatter against `contracts/skill-definition.yaml`
  - Coverage: rl_metrics fields, progressive-disclosure structure, agent-invocations validation
  - Acceptance Criteria:
    - [ ] Test validates all required fields (name, version, description, triggers, progressive-disclosure, rl_metrics)
    - [ ] Test validates rl_metrics bounds (success_rate 0-1, selection_weight 0.1-1.0)
    - [ ] Test validates agent-invocation references against consolidated agent names
    - [ ] Test validates progressive-disclosure layer definitions
    - [ ] All tests fail initially (red phase)
  - Type: test | Priority: critical | Complexity: medium | Hours: 4

- [ ] **T002** [P] Contract Test - agent-definition.yaml v2
  - File: `tests/contracts/test_agent_definition_v2.test.js`
  - Validates: Agent.md against `contracts/agent-definition.yaml`
  - Coverage: skill-portfolio field, merged-from tracking, rl_performance metrics
  - Acceptance Criteria:
    - [ ] Test validates all required fields (name, purpose, required-context, output-format, tools, department, skill-portfolio)
    - [ ] Test validates skill-portfolio path format (category/skill-name)
    - [ ] Test validates merged-from array for consolidation tracking
    - [ ] Test validates rl_performance metrics structure
    - [ ] All tests fail initially (red phase)
  - Type: test | Priority: critical | Complexity: medium | Hours: 4

- [ ] **T003** [P] Contract Test - skill-invocation.yaml v2
  - File: `tests/contracts/test_skill_invocation_v2.test.js`
  - Validates: Skill-to-agent invocation contracts
  - Coverage: rl_performance tracking, DS-STAR integration options, context validation
  - Acceptance Criteria:
    - [ ] Test validates invocation context structure
    - [ ] Test validates expected-output format matching
    - [ ] Test validates rl_performance metrics per invocation
    - [ ] Test validates DS-STAR integration options
    - [ ] Test validates context minimality (max 10 fields)
    - [ ] All tests fail initially (red phase)
  - Type: test | Priority: critical | Complexity: medium | Hours: 4

- [ ] **T004** [P] Contract Test - skill-index-v3.yaml
  - File: `tests/contracts/test_skill_index_v3.test.js`
  - Validates: skill-index.json v3 schema
  - Coverage: RL config parameters, routing table structure, rl_statistics
  - Acceptance Criteria:
    - [ ] Test validates version field equals "3.0.0"
    - [ ] Test validates rl_config with algorithm, learning_rate, reward_weights
    - [ ] Test validates routing table (command-routes, keyword-routes, domain-routes)
    - [ ] Test validates rl_statistics in statistics section
    - [ ] Test validates skill entries include rl_metrics
    - [ ] All tests fail initially (red phase)
  - Type: test | Priority: critical | Complexity: medium | Hours: 4

- [ ] **T005** [P] Contract Test - agent-index.yaml
  - File: `tests/contracts/test_agent_index.test.js`
  - Validates: agent-index.json schema
  - Coverage: domain_agents (exactly 8), ds_star_agents (exactly 5), consolidation_map
  - Acceptance Criteria:
    - [ ] Test validates domain_agents array has exactly 8 entries
    - [ ] Test validates ds_star_agents array has exactly 5 entries
    - [ ] Test validates consolidation_map covers all original 15 agents
    - [ ] Test validates statistics (total_agents = 13, consolidation_ratio)
    - [ ] Test validates FR-709 compliance (DS-STAR agents separate)
    - [ ] All tests fail initially (red phase)
  - Type: test | Priority: critical | Complexity: medium | Hours: 4

- [ ] **T006** [P] Contract Test - rl-metrics.yaml
  - File: `tests/contracts/test_rl_metrics.test.js`
  - Validates: skill-performance.json structure
  - Coverage: skill performance structure, learning history entries, global metrics
  - Acceptance Criteria:
    - [ ] Test validates skill performance fields (current_weight bounds, invocation counts)
    - [ ] Test validates learning_history entry structure
    - [ ] Test validates global_metrics including improvement_over_baseline
    - [ ] Test validates evaluation_config parameters
    - [ ] Test validates count consistency (invocation_count = success + failure + partial)
    - [ ] All tests fail initially (red phase)
  - Type: test | Priority: critical | Complexity: medium | Hours: 4

### FR-707 Compliance Infrastructure

- [ ] **T007** Implement message-preflight skill for FR-707 compliance
  - Files:
    - `.claude/skills/validation/message-preflight/SKILL.md`
    - `.claude/skills/validation/message-preflight/reference.md`
  - Dependencies: T001 (contract test for skill-definition)
  - Purpose: Executes compliance check on every user message (FR-707 CRITICAL)
  - Acceptance Criteria:
    - [ ] Skill validates against skill-definition.yaml v3 contract
    - [ ] Skill executes on every user message (FR-707)
    - [ ] Skill logs compliance check timestamp to audit trail
    - [ ] Skill completes 4-step pre-flight protocol
    - [ ] Skill cannot be bypassed by other skills
    - [ ] Unit tests pass (green phase)
  - Technical Notes: CRITICAL path - all other skills depend on compliance check
  - Type: feature | Priority: critical | Complexity: large | Hours: 8

### RL Infrastructure

- [ ] **T008** Implement skill-performance.json schema and initialization
  - Files:
    - `.docs/rl-metrics/skill-performance.json` (initial structure)
    - `.specify/lib/rl/performance-tracker.sh` (initialization script)
  - Dependencies: T006 (contract test for rl-metrics)
  - Acceptance Criteria:
    - [ ] JSON structure validates against rl-metrics.yaml contract
    - [ ] All existing skills have initial entries with default weights (0.5)
    - [ ] global_metrics initialized with baseline values
    - [ ] evaluation_config set to EMA algorithm with default parameters
    - [ ] Unit tests pass (green phase)
  - Type: feature | Priority: high | Complexity: medium | Hours: 4

- [ ] **T009** Implement EMA reward calculation function
  - File: `.specify/lib/rl/ema-reward.sh`
  - Dependencies: T008
  - Acceptance Criteria:
    - [ ] Implements formula: weight(t+1) = alpha * reward + (1-alpha) * weight(t)
    - [ ] Reward = 0.5*success + 0.3*token_efficiency + 0.2*user_satisfaction
    - [ ] Token efficiency = max(0, (baseline - avg_tokens) / baseline)
    - [ ] Weight clamped to [0.1, 1.0] bounds
    - [ ] Unit tests cover edge cases (0 tokens, 100% failure, etc.)
  - Type: feature | Priority: high | Complexity: medium | Hours: 6

- [ ] **T010** Implement skill weight update mechanism
  - File: `.specify/lib/rl/update-weights.sh`
  - Dependencies: T009
  - Acceptance Criteria:
    - [ ] Updates selection_weight in skill-performance.json after each invocation
    - [ ] Appends to learning_history (max 100 entries)
    - [ ] Logs timestamp, reward, weight_before, weight_after, outcome
    - [ ] Thread-safe for concurrent skill invocations
    - [ ] Unit tests pass (green phase)
  - Type: feature | Priority: high | Complexity: medium | Hours: 6

### Progressive Disclosure Infrastructure

- [ ] **T011** Implement progressive disclosure loader library
  - Files:
    - `.specify/lib/progressive-disclosure/loader.sh`
    - `.specify/lib/progressive-disclosure/layer-parser.sh`
  - Dependencies: T001 (contract test for skill-definition)
  - Acceptance Criteria:
    - [ ] Loads Layer 1 (metadata + rl_metrics) on index scan (~100 tokens)
    - [ ] Loads Layer 2 (instructions, agent-invocations) on skill activation (~500 tokens)
    - [ ] Loads Layer 3 (examples, references) on demand only
    - [ ] Token counting validates against budget constraints
    - [ ] Library is standalone with own tests (Principle I)
    - [ ] Unit tests pass (green phase)
  - Type: feature | Priority: high | Complexity: large | Hours: 8

- [ ] **T012** Implement token budget validation
  - File: `.specify/lib/progressive-disclosure/token-validator.sh`
  - Dependencies: T011
  - Acceptance Criteria:
    - [ ] Validates Layer 1 < 150 tokens
    - [ ] Validates Layer 2 < 600 tokens
    - [ ] Logs warning if Layer 3 causes total > 2000 tokens
    - [ ] Provides token breakdown per layer
    - [ ] Unit tests pass (green phase)
  - Type: feature | Priority: medium | Complexity: small | Hours: 3

### Skill Index v3

- [ ] **T013** Implement skill-index.json v3 schema structure
  - File: `.claude/skill-index.json` (v3 structure)
  - Dependencies: T004, T008
  - Acceptance Criteria:
    - [ ] Version field = "3.0.0"
    - [ ] All skills include rl_metrics section
    - [ ] rl_config section added with EMA defaults
    - [ ] routing table includes command-routes, keyword-routes, domain-routes
    - [ ] statistics includes rl_statistics
    - [ ] Validates against skill-index-v3.yaml contract
  - Type: feature | Priority: high | Complexity: medium | Hours: 6

- [ ] **T014** Implement skill index generator with RL metrics
  - File: `.specify/scripts/bash/generate-skill-index-v3.sh`
  - Dependencies: T013
  - Acceptance Criteria:
    - [ ] Scans all SKILL.md files in .claude/skills/
    - [ ] Extracts rl_metrics from each skill
    - [ ] Generates routing tables from triggers
    - [ ] Calculates statistics including rl_statistics
    - [ ] Idempotent (Principle IV) - safe to run multiple times
  - Type: feature | Priority: high | Complexity: medium | Hours: 6

### Hybrid Architecture Mode

- [ ] **T015** Implement architecture mode configuration
  - File: `.specify/config/architecture.conf`
  - Dependencies: none
  - Content: `ARCHITECTURE_MODE=hybrid`, `LEGACY_WARNINGS=true`, `LEGACY_BLOCKING=false`, `MIGRATION_PHASE=1`
  - Acceptance Criteria:
    - [ ] Config file created with hybrid mode default
    - [ ] Modes supported: hybrid, skills-first, legacy-agents
    - [ ] Configuration can be changed without code modifications
    - [ ] Unit tests validate mode switching
  - Type: feature | Priority: high | Complexity: small | Hours: 3

- [ ] **T016** Implement hybrid mode router
  - File: `.specify/lib/routing/hybrid-router.sh`
  - Dependencies: T015, T007
  - Acceptance Criteria:
    - [ ] In hybrid mode: supports both skill-first and agent-first patterns
    - [ ] Emits deprecation warning for direct agent invocation
    - [ ] Routes to skills when skill trigger matches
    - [ ] Falls back to agent routing when no skill match (legacy support)
    - [ ] Integration tests validate both paths work
  - Type: feature | Priority: high | Complexity: large | Hours: 8

### New Skills Creation (Phase 1 - 10 Skills)

- [ ] **T017** [P] Create orchestration/multi-skill-workflow skill
  - File: `.claude/skills/orchestration/multi-skill-workflow/SKILL.md`
  - Dependencies: T001, T011
  - Acceptance Criteria:
    - [ ] Skill validates against skill-definition.yaml v3
    - [ ] Progressive disclosure layers defined
    - [ ] Agent-invocations reference workflow-coordinator
    - [ ] Composes validation/message-preflight at pre-execution
    - [ ] rl_metrics initialized with defaults
  - Type: feature | Priority: medium | Complexity: medium | Hours: 4

- [ ] **T018** [P] Create orchestration/full-stack-feature skill
  - File: `.claude/skills/orchestration/full-stack-feature/SKILL.md`
  - Dependencies: T001, T011
  - Acceptance Criteria:
    - [ ] Skill validates against skill-definition.yaml v3
    - [ ] Agent-invocations includes implementation-specialist, database-specialist
    - [ ] Defines full-stack workflow from frontend to database
    - [ ] rl_metrics initialized with defaults
  - Type: feature | Priority: medium | Complexity: medium | Hours: 4

- [ ] **T019** [P] Create domain/frontend-operations skill
  - File: `.claude/skills/domain/frontend-operations/SKILL.md`
  - Dependencies: T001, T011
  - Acceptance Criteria:
    - [ ] Skill validates against skill-definition.yaml v3
    - [ ] Agent-invocations references implementation-specialist
    - [ ] Triggers include "UI", "component", "React", "CSS", "form"
    - [ ] rl_metrics initialized with defaults
  - Type: feature | Priority: medium | Complexity: medium | Hours: 4

- [ ] **T020** [P] Create domain/backend-operations skill
  - File: `.claude/skills/domain/backend-operations/SKILL.md`
  - Dependencies: T001, T011
  - Acceptance Criteria:
    - [ ] Skill validates against skill-definition.yaml v3
    - [ ] Agent-invocations references backend-architect, implementation-specialist
    - [ ] Triggers include "API", "endpoint", "server", "auth", "service"
    - [ ] rl_metrics initialized with defaults
  - Type: feature | Priority: medium | Complexity: medium | Hours: 4

- [ ] **T021** [P] Create domain/database-operations skill
  - File: `.claude/skills/domain/database-operations/SKILL.md`
  - Dependencies: T001, T011
  - Acceptance Criteria:
    - [ ] Skill validates against skill-definition.yaml v3
    - [ ] Agent-invocations references database-specialist
    - [ ] Triggers include "schema", "migration", "query", "RLS", "SQL"
    - [ ] rl_metrics initialized with defaults
  - Type: feature | Priority: medium | Complexity: medium | Hours: 4

- [ ] **T022** Update existing skills to v3 format
  - Target: All 13 existing skills in sdd-workflow/, validation/, governance/, project-initialization/, integration/
  - Dependencies: T001, T011, T014
  - Acceptance Criteria:
    - [ ] All skills in sdd-workflow/ updated
    - [ ] All skills in validation/ updated
    - [ ] All skills in governance/ updated
    - [ ] All skills in project-initialization/ updated
    - [ ] All skills in integration/ updated
    - [ ] All skills validate against skill-definition.yaml v3
    - [ ] Regenerate skill-index.json v3
  - Type: refactor | Priority: high | Complexity: large | Hours: 8

---

## Phase 2: Agent Consolidation (Months 4-6)

### Agent Consolidation Implementation

- [ ] **T023** Create implementation-specialist consolidated agent
  - File: `.claude/agents/engineering/implementation-specialist.md`
  - Archive: frontend-specialist.md, full-stack-developer.md
  - Dependencies: T002
  - Acceptance Criteria:
    - [ ] Agent validates against agent-definition.yaml v2
    - [ ] skill-portfolio includes frontend-operations, backend-operations, full-stack-feature
    - [ ] merged-from lists frontend-specialist, full-stack-developer
    - [ ] rl_performance initialized
    - [ ] Purpose: "Build UI components and full-stack integrations"
    - [ ] All capabilities from original agents preserved
  - FR: FR-610 | Type: feature | Priority: high | Complexity: large | Hours: 8

- [ ] **T024** Create operations-specialist consolidated agent
  - File: `.claude/agents/operations/operations-specialist.md`
  - Archive: devops-engineer.md, performance-engineer.md
  - Dependencies: T002
  - Acceptance Criteria:
    - [ ] Agent validates against agent-definition.yaml v2
    - [ ] skill-portfolio includes deployment, ci-cd, monitoring, performance-optimization
    - [ ] merged-from lists devops-engineer, performance-engineer
    - [ ] rl_performance initialized
    - [ ] Purpose: "Manage runtime infrastructure and performance optimization"
    - [ ] All capabilities from original agents preserved
  - FR: FR-611 | Type: feature | Priority: high | Complexity: large | Hours: 8

- [ ] **T025** Create specification-orchestrator consolidated agent
  - File: `.claude/agents/product/specification-orchestrator.md`
  - Archive: specification-agent.md, planning-agent.md, tasks-agent.md, prd-specialist.md
  - Dependencies: T002
  - Acceptance Criteria:
    - [ ] Agent validates against agent-definition.yaml v2
    - [ ] skill-portfolio includes sdd-specification, sdd-planning, sdd-tasks, prd-creation
    - [ ] merged-from lists all 4 original agents
    - [ ] rl_performance initialized
    - [ ] Purpose: "Orchestrate product workflow from PRD through tasks"
    - [ ] All capabilities from original agents preserved
  - FR: FR-612 | Type: feature | Priority: high | Complexity: large | Hours: 8

- [ ] **T026** Create quality-specialist consolidated agent
  - File: `.claude/agents/quality/quality-specialist.md`
  - Archive: testing-specialist.md, security-specialist.md
  - Dependencies: T002
  - Acceptance Criteria:
    - [ ] Agent validates against agent-definition.yaml v2
    - [ ] skill-portfolio includes test-strategy, security-review, qa-validation
    - [ ] merged-from lists testing-specialist, security-specialist
    - [ ] rl_performance initialized
    - [ ] Purpose: "Ensure quality through testing and security review"
    - [ ] All capabilities from original agents preserved
  - FR: FR-613 | Type: feature | Priority: high | Complexity: large | Hours: 8

- [ ] **T027** Rename subagent-architect to system-architect
  - File: `.claude/agents/architecture/system-architect.md`
  - Archive: subagent-architect.md
  - Dependencies: T002
  - Acceptance Criteria:
    - [ ] Agent validates against agent-definition.yaml v2
    - [ ] skill-portfolio includes create-agent, system-design
    - [ ] merged-from lists subagent-architect
    - [ ] Purpose: "Design system architecture and agent structures"
  - Type: refactor | Priority: medium | Complexity: small | Hours: 2

- [ ] **T028** Rename task-orchestrator to workflow-coordinator
  - File: `.claude/agents/product/workflow-coordinator.md`
  - Archive: task-orchestrator.md
  - Dependencies: T002
  - Acceptance Criteria:
    - [ ] Agent validates against agent-definition.yaml v2
    - [ ] skill-portfolio includes multi-skill-workflow, migration-workflow
    - [ ] merged-from lists task-orchestrator
    - [ ] Purpose: "Coordinate multi-skill workflows and migrations"
  - Type: refactor | Priority: medium | Complexity: small | Hours: 2

- [ ] **T029** Update backend-architect for v2 format
  - File: `.claude/agents/architecture/backend-architect.md` (updated)
  - Dependencies: T002
  - Acceptance Criteria:
    - [ ] Agent validates against agent-definition.yaml v2
    - [ ] skill-portfolio includes api-design, service-architecture
    - [ ] merged-from is empty (no consolidation)
    - [ ] rl_performance initialized
  - Type: refactor | Priority: medium | Complexity: small | Hours: 2

- [ ] **T030** Update database-specialist for v2 format
  - File: `.claude/agents/data/database-specialist.md` (updated)
  - Dependencies: T002
  - Acceptance Criteria:
    - [ ] Agent validates against agent-definition.yaml v2
    - [ ] skill-portfolio includes database-operations, schema-design
    - [ ] merged-from is empty (no consolidation)
    - [ ] rl_performance initialized
  - Type: refactor | Priority: medium | Complexity: small | Hours: 2

### Agent Index Implementation

- [ ] **T031** Implement agent-index.json structure
  - File: `.claude/agent-index.json`
  - Dependencies: T005, T023-T030
  - Acceptance Criteria:
    - [ ] Version field = "1.0.0"
    - [ ] domain_agents array has exactly 8 entries
    - [ ] ds_star_agents array has exactly 5 entries
    - [ ] consolidation_map complete for all original agents
    - [ ] statistics accurate (total_agents = 13)
    - [ ] Validates against agent-index.yaml contract
  - Type: feature | Priority: high | Complexity: medium | Hours: 6

- [ ] **T032** Implement agent index generator
  - File: `.specify/scripts/bash/generate-agent-index.sh`
  - Dependencies: T031
  - Acceptance Criteria:
    - [ ] Scans all agent.md files in .claude/agents/
    - [ ] Extracts skill-portfolio and merged-from
    - [ ] Generates consolidation_map automatically
    - [ ] Calculates statistics
    - [ ] Idempotent (safe to run multiple times)
  - Type: feature | Priority: medium | Complexity: medium | Hours: 4

### DS-STAR Integration Updates

- [ ] **T033** Update Router Agent for skill routing
  - File: `.claude/ds-star/router-agent.md` (updated)
  - Dependencies: T013, T031
  - Acceptance Criteria:
    - [ ] Router routes to SKILLS (not agents directly)
    - [ ] Uses skill-index.json v3 for routing decisions
    - [ ] RL metrics inform skill selection
    - [ ] Logs routing decisions with confidence scores
    - [ ] FR-701 compliant
  - FR: FR-701 | Type: feature | Priority: high | Complexity: large | Hours: 8

- [ ] **T034** Update Verifier Agent for skill output validation
  - File: `.claude/ds-star/verifier-agent.md` (updated)
  - Dependencies: T033
  - Acceptance Criteria:
    - [ ] Validates skill coordination quality
    - [ ] Validates agent outputs within skill context
    - [ ] Binary decisions (sufficient/insufficient)
    - [ ] RL learns quality patterns
    - [ ] FR-702 compliant
  - FR: FR-702 | Type: feature | Priority: high | Complexity: medium | Hours: 6

- [ ] **T035** Update Auto-Debug Agent for skill invocation
  - Files:
    - `.claude/ds-star/auto-debug-agent.md` (updated)
    - `.claude/skills/sdd-workflow/sdd-debug/SKILL.md` (updated)
  - Dependencies: T033
  - Acceptance Criteria:
    - [ ] Auto-Debug invoked BY debug skill (not directly)
    - [ ] Operates within skill context
    - [ ] RL learns which fix patterns work best
    - [ ] FR-703 compliant
  - FR: FR-703 | Type: feature | Priority: high | Complexity: medium | Hours: 6

- [ ] **T036** Update Finalizer Agent for skills-first validation
  - File: `.claude/ds-star/finalizer-agent.md` (updated)
  - Dependencies: T033
  - Acceptance Criteria:
    - [ ] Validates skills-first pattern usage
    - [ ] Pre-commit gates check skill execution
    - [ ] Constitutional compliance includes skills-first validation
    - [ ] FR-704 compliant
  - FR: FR-704 | Type: feature | Priority: high | Complexity: medium | Hours: 6

- [ ] **T037** Update Context Analyzer for skill context provision
  - File: `.claude/ds-star/context-analyzer.md` (updated)
  - Dependencies: T033
  - Acceptance Criteria:
    - [ ] Provides codebase context TO skills (not agents)
    - [ ] Context passed through skill -> agent
    - [ ] RL optimizes context relevance
    - [ ] <2s retrieval time maintained
    - [ ] FR-705 compliant
  - FR: FR-705 | Type: feature | Priority: high | Complexity: medium | Hours: 6

### Skill Migration

- [ ] **T038** Migrate all skill agent-invocations to consolidated agents
  - Target: All SKILL.md files
  - Dependencies: T023-T030, T022
  - Acceptance Criteria:
    - [ ] No skill references frontend-specialist (use implementation-specialist)
    - [ ] No skill references full-stack-developer (use implementation-specialist)
    - [ ] No skill references devops-engineer (use operations-specialist)
    - [ ] No skill references testing-specialist (use quality-specialist)
    - [ ] All agent-invocations validate against consolidated agent names
    - [ ] Regenerate skill-index.json v3
  - Type: refactor | Priority: high | Complexity: large | Hours: 8

- [ ] **T039** Implement RL skill selection algorithm
  - File: `.specify/lib/rl/skill-selector.sh`
  - Dependencies: T010, T013, T033
  - Acceptance Criteria:
    - [ ] When multiple skills match triggers, uses selection_weight
    - [ ] Applies softmax with configurable temperature
    - [ ] Logs selection decision and weights
    - [ ] Falls back to highest-weight on ties
    - [ ] Unit tests validate selection behavior
  - Type: feature | Priority: high | Complexity: large | Hours: 8

- [ ] **T040** Create domain skills (5 additional)
  - Files:
    - `.claude/skills/domain/security-operations/SKILL.md`
    - `.claude/skills/domain/testing-operations/SKILL.md`
    - `.claude/skills/domain/devops-operations/SKILL.md`
    - `.claude/skills/domain/performance-operations/SKILL.md`
    - `.claude/skills/domain/api-design/SKILL.md`
  - Dependencies: T001, T011
  - Acceptance Criteria:
    - [ ] All skills validate against skill-definition.yaml v3
    - [ ] Each skill references appropriate consolidated agent
    - [ ] All skills have rl_metrics initialized
    - [ ] All skills have progressive-disclosure defined
  - Type: feature | Priority: medium | Complexity: medium | Hours: 6

---

## Phase 3: Constitutional Amendment + Advanced RL (Months 7-9)

### Constitutional Amendment

- [ ] **T041** Draft Principle X rewrite
  - File: Draft amendment for constitution.md Principle X
  - Dependencies: T038
  - Acceptance Criteria:
    - [ ] Current text: "Specialized work MUST be delegated to specialized agents"
    - [ ] New text: "Workflow orchestration MUST be performed by skills..."
    - [ ] Impact analysis covers all affected documents
    - [ ] Amendment follows constitution_update_checklist.md
    - [ ] Review by stakeholders scheduled
  - FR: FR-401 | Type: docs | Priority: critical | Complexity: large | Hours: 8

- [ ] **T042** Update 4-step pre-flight protocol
  - Files: CLAUDE.md, constitution.md
  - Dependencies: T041
  - Acceptance Criteria:
    - [ ] Step 2: "Analyze task for skill activation triggers"
    - [ ] Step 3: "Activate appropriate skill; skill determines agent invocation"
    - [ ] Step 4: "Skill executes, invoking agents as needed"
    - [ ] All references to agent delegation updated
  - Type: refactor | Priority: high | Complexity: medium | Hours: 6

- [ ] **T043** Create skill-activation-triggers.md
  - File: `.specify/memory/skill-activation-triggers.md`
  - Dependencies: T041
  - Acceptance Criteria:
    - [ ] Domain keywords map to skills (not agents)
    - [ ] Skills internally map to agents they invoke
    - [ ] Format consistent with original triggers file
    - [ ] Cross-references from CLAUDE.md updated
  - Type: feature | Priority: high | Complexity: medium | Hours: 6

- [ ] **T044** Update CLAUDE.md for skills-first
  - File: CLAUDE.md
  - Dependencies: T042, T043
  - Acceptance Criteria:
    - [ ] Quick Reference table references skills as primary
    - [ ] Pre-flight protocol references skill detection
    - [ ] Agent Delegation section renamed/updated
    - [ ] Skill-activation-triggers.md referenced
    - [ ] All domain->agent mappings become domain->skill mappings
  - Type: refactor | Priority: high | Complexity: medium | Hours: 6

- [ ] **T045** Update AGENTS.md for consolidated agents
  - File: AGENTS.md
  - Dependencies: T031
  - Acceptance Criteria:
    - [ ] Registry shows 8 domain agents + 5 DS-STAR agents
    - [ ] Consolidation noted with merged-from information
    - [ ] Skill portfolios documented per agent
    - [ ] Department structure updated
  - Type: refactor | Priority: high | Complexity: medium | Hours: 6

### Advanced RL (Deferred Items)

- [ ] **T046** Implement credit assignment module
  - File: `.specify/lib/rl/credit-assignment.sh`
  - Dependencies: T039
  - Acceptance Criteria:
    - [ ] Tracks LLM requests per skill/agent
    - [ ] Calculates contribution weights per entity
    - [ ] Distributes reward based on contribution
    - [ ] Unit tests validate attribution accuracy
    - [ ] FR-602 compliant (deferred feature)
  - FR: FR-602 | Type: feature | Priority: medium | Complexity: x-large | Hours: 16

- [ ] **T047** Implement GRPO/PPO policy optimizer (optional)
  - File: `.specify/lib/rl/grpo-optimizer.sh`
  - Dependencies: T046
  - Technical Notes: May be deferred to post-Phase 4 if EMA performs adequately
  - Acceptance Criteria:
    - [ ] Implements policy gradient update
    - [ ] Advantage calculation from rewards
    - [ ] Integration with skill weight updates
    - [ ] Feature flag to enable/disable
    - [ ] Unit tests pass (green phase)
  - Type: feature | Priority: low | Complexity: x-large | Hours: 20

- [ ] **T048** Implement skill prototype library
  - File: `.specify/templates/skill-prototypes/`
  - Dependencies: T001
  - Acceptance Criteria:
    - [ ] Template for sdd-workflow skills
    - [ ] Template for domain skills
    - [ ] Template for orchestration skills
    - [ ] Rubrics for quality evaluation
    - [ ] FR-605 compliant (deferred feature)
  - FR: FR-605 | Type: feature | Priority: medium | Complexity: large | Hours: 8

### Migration Tooling

- [ ] **T049** Implement migrate-agent-to-skill.sh
  - File: `.specify/scripts/bash/migrate-agent-to-skill.sh`
  - Dependencies: T022
  - Acceptance Criteria:
    - [ ] Converts agent workflow to skill definition
    - [ ] Extracts agent capabilities into skill format
    - [ ] Generates agent-invocations section
    - [ ] Validates output against skill-definition.yaml v3
  - FR: FR-503 | Type: feature | Priority: medium | Complexity: medium | Hours: 6

- [ ] **T050** Implement skill-coverage-audit.sh
  - File: `.specify/scripts/bash/skill-coverage-audit.sh`
  - Dependencies: T031, T014
  - Acceptance Criteria:
    - [ ] Identifies agents without invoking skills
    - [ ] Reports skill coverage per agent
    - [ ] Flags gaps in consolidated agent portfolios
    - [ ] Outputs coverage percentage
  - FR: FR-503 | Type: feature | Priority: medium | Complexity: medium | Hours: 4

- [ ] **T051** Implement legacy-pattern-report.sh
  - File: `.specify/scripts/bash/legacy-pattern-report.sh`
  - Dependencies: T016
  - Acceptance Criteria:
    - [ ] Reports direct agent invocations (legacy pattern)
    - [ ] Counts skills-first vs agent-first usage
    - [ ] Recommends migration actions
    - [ ] Tracks migration progress percentage
  - FR: FR-503 | Type: feature | Priority: medium | Complexity: medium | Hours: 4

### Integration Tests

- [ ] **T052** [P] Integration Test - RL skill selection
  - File: `tests/integration/test_rl_skill_selection.test.js`
  - Dependencies: T039
  - Acceptance Criteria:
    - [ ] Test validates higher-weight skill selected when multiple match
    - [ ] Test validates weight update after invocation
    - [ ] Test validates bounds enforcement (0.1-1.0)
    - [ ] Test validates learning_history logging
  - Type: test | Priority: high | Complexity: medium | Hours: 6

- [ ] **T053** [P] Integration Test - Agent consolidation coverage
  - File: `tests/integration/test_agent_consolidation.test.js`
  - Dependencies: T031
  - Acceptance Criteria:
    - [ ] Test validates all 15 original capabilities covered
    - [ ] Test validates skill portfolios complete
    - [ ] Test validates consolidation_map accuracy
    - [ ] Test validates no capability gaps
  - Type: test | Priority: high | Complexity: medium | Hours: 6

- [ ] **T054** [P] Integration Test - DS-STAR flow
  - File: `tests/integration/test_ds_star_flow.test.js`
  - Dependencies: T033-T037
  - Acceptance Criteria:
    - [ ] Test validates FR-707 compliance check first
    - [ ] Test validates Router -> Skills -> Agents flow
    - [ ] Test validates Verifier quality gates
    - [ ] Test validates Auto-Debug via skill invocation
    - [ ] Test validates Finalizer skills-first validation
  - Type: test | Priority: high | Complexity: large | Hours: 8

---

## Phase 4: Migration Completion (Months 10-12)

### Complete Skill Taxonomy

- [ ] **T055** Create creation/create-skill skill
  - File: `.claude/skills/creation/create-skill/SKILL.md`
  - Dependencies: T001, T048
  - Acceptance Criteria:
    - [ ] Skill validates against skill-definition.yaml v3
    - [ ] Creates skill definition following progressive disclosure
    - [ ] Generates agent-invocations from user input
    - [ ] References skill prototype templates
    - [ ] FR-203 compliant
  - FR: FR-203 | Type: feature | Priority: high | Complexity: medium | Hours: 6

- [ ] **T056** Create creation/create-template skill
  - File: `.claude/skills/creation/create-template/SKILL.md`
  - Dependencies: T001
  - Acceptance Criteria:
    - [ ] Skill validates against skill-definition.yaml v3
    - [ ] Creates templates for skills, agents, or documents
    - [ ] Follows naming conventions
  - Type: feature | Priority: medium | Complexity: medium | Hours: 4

- [ ] **T057** [P] Create orchestration/migration-workflow skill
  - File: `.claude/skills/orchestration/migration-workflow/SKILL.md`
  - Dependencies: T001
  - Acceptance Criteria:
    - [ ] Skill validates against skill-definition.yaml v3
    - [ ] Orchestrates migration from legacy to skills-first
    - [ ] Agent-invocations references workflow-coordinator
  - Type: feature | Priority: medium | Complexity: medium | Hours: 4

- [ ] **T058** [P] Create remaining domain skills (3+)
  - Files:
    - `.claude/skills/domain/service-architecture/SKILL.md`
    - `.claude/skills/domain/schema-design/SKILL.md`
    - `.claude/skills/domain/system-design/SKILL.md`
  - Dependencies: T001
  - Acceptance Criteria:
    - [ ] All skills validate against skill-definition.yaml v3
    - [ ] Each skill references appropriate consolidated agent
    - [ ] Total domain skills >= 10
  - Type: feature | Priority: medium | Complexity: medium | Hours: 6

### Legacy Pattern Blocking

- [ ] **T059** Implement legacy pattern blocking
  - File: `.specify/lib/routing/legacy-blocker.sh`
  - Dependencies: T016, T051
  - Acceptance Criteria:
    - [ ] In skills-first mode: blocks direct agent invocation
    - [ ] Provides error message with migration guidance
    - [ ] Logs blocked attempts for metrics
    - [ ] Can be disabled via override flag (for emergencies)
  - Type: feature | Priority: high | Complexity: medium | Hours: 6

- [ ] **T060** Update architecture.conf default to skills-first
  - File: `.specify/config/architecture.conf`
  - Dependencies: T059
  - Content: `ARCHITECTURE_MODE=skills-first`
  - Acceptance Criteria:
    - [ ] Default mode changed from hybrid to skills-first
    - [ ] Legacy patterns blocked by default
    - [ ] Documentation updated
  - Type: refactor | Priority: high | Complexity: small | Hours: 2

### Constitution v2.0.0

- [ ] **T061** Ratify Constitution v2.0.0
  - File: `.specify/memory/constitution.md` (version 2.0.0)
  - Dependencies: T041, T042
  - Acceptance Criteria:
    - [ ] Principle X reflects skills-first architecture
    - [ ] Version bumped to 2.0.0
    - [ ] All cross-references updated
    - [ ] Amendment process documented in changelog
    - [ ] constitution_update_checklist.md completed
  - Type: docs | Priority: critical | Complexity: medium | Hours: 6

- [ ] **T062** Update constitutional-check.sh for v2.0.0
  - File: `.specify/scripts/bash/constitutional-check.sh` (updated)
  - Dependencies: T061
  - Acceptance Criteria:
    - [ ] Validates skills-first patterns
    - [ ] Checks for legacy pattern usage
    - [ ] References Principle X v2.0.0 text
    - [ ] All 15 principles validated
  - Type: refactor | Priority: high | Complexity: medium | Hours: 4

### Validation & Reporting

- [ ] **T063** Implement RL performance validation
  - File: `tests/validation/test_rl_performance.test.js`
  - Dependencies: T052
  - Acceptance Criteria:
    - [ ] Validates +15-25% skill selection accuracy vs baseline
    - [ ] A/B test framework operational
    - [ ] 30-day evaluation window analysis
    - [ ] FR-604 targets validated
  - FR: FR-604 | Type: test | Priority: high | Complexity: large | Hours: 8

- [ ] **T064** Implement token efficiency validation
  - File: `tests/validation/test_token_efficiency.test.js`
  - Dependencies: T012
  - Acceptance Criteria:
    - [ ] Validates 40-50% token reduction target
    - [ ] Measures baseline vs skills-first token usage
    - [ ] Layer 1/2/3 budgets validated
    - [ ] NFR-001 targets met
  - NFR: NFR-001 | Type: test | Priority: high | Complexity: medium | Hours: 6

- [ ] **T065** Implement DS-STAR performance validation
  - File: `tests/validation/test_ds_star_performance.test.js`
  - Dependencies: T054
  - Acceptance Criteria:
    - [ ] 3.5x task completion accuracy validated
    - [ ] >70% auto-debug resolution rate validated
    - [ ] <2s context retrieval validated
    - [ ] 95% verifier accuracy validated
    - [ ] FR-708 targets met
  - FR: FR-708 | Type: test | Priority: high | Complexity: medium | Hours: 6

- [ ] **T066** Generate migration completion report
  - File: `.docs/reports/migration-completion-report.md`
  - Dependencies: T063, T064, T065
  - Acceptance Criteria:
    - [ ] Token efficiency metrics documented
    - [ ] RL performance metrics documented
    - [ ] Agent consolidation coverage documented
    - [ ] DS-STAR performance metrics documented
    - [ ] All success metrics validated
  - Type: docs | Priority: medium | Complexity: medium | Hours: 4

### Final Cleanup

- [ ] **T067** Archive original agent definitions
  - File: `.docs/archive/original-agents/` (archived files)
  - Dependencies: T061
  - Acceptance Criteria:
    - [ ] Original 15 agent definitions archived
    - [ ] Not deleted (available for reference)
    - [ ] Archive location documented
  - Type: refactor | Priority: low | Complexity: small | Hours: 2

- [ ] **T068** Remove hybrid mode support (optional)
  - File: `.specify/lib/routing/hybrid-router.sh` (deprecated)
  - Dependencies: T060
  - Technical Notes: Consider keeping for emergency rollback capability
  - Acceptance Criteria:
    - [ ] Hybrid mode code deprecated (not deleted)
    - [ ] Can be re-enabled via override if needed
    - [ ] Documentation notes removal
  - Type: refactor | Priority: low | Complexity: small | Hours: 2

---

## Dependencies Graph

```
Phase 1: Foundation
T001-T006 [P] (Contract Tests)
    |
    +---> T007 (message-preflight) - FR-707 CRITICAL
    |
    +---> T008 --> T009 --> T010 (RL infrastructure)
    |
    +---> T011 --> T012 (progressive disclosure)
    |
    +---> T013 --> T014 (skill-index v3)
    |
    +---> T015 --> T016 (hybrid mode)
    |
    +---> T017-T021 [P] (new skills)
           |
           v
         T022 (update existing skills)

Phase 2: Agent Consolidation
T002 --> T023-T030 (create/update agents)
             |
             v
           T031 --> T032 (agent-index)
             |
             v
         T033-T037 (DS-STAR updates)
             |
             v
           T038 (migrate skill invocations)
             |
         T039 (RL selector) <--+
             |                 |
           T040 [P] (domain skills)

Phase 3: Constitutional Amendment
T041 (Principle X draft)
  |
  +--> T042 (pre-flight update)
  |
  +--> T043 (skill-activation-triggers.md)
         |
         v
       T044 --> T045 (docs updates)

T046 --> T047 (advanced RL - optional)
  |
T048 (prototypes)
  |
T049-T051 (tooling)
  |
T052-T054 [P] (integration tests)

Phase 4: Migration Completion
T055-T058 [P] (remaining skills)
  |
T059 --> T060 (legacy blocking)
  |
T061 --> T062 (constitution v2.0.0)
  |
T063-T065 (validation)
  |
T066 (report)
  |
T067-T068 [P] (cleanup)
```

---

## Parallel Execution Opportunities

### Batch 1: Contract Tests (T001-T006) - All Parallel
```
T001: Contract test skill-definition.yaml v3
T002: Contract test agent-definition.yaml v2
T003: Contract test skill-invocation.yaml v2
T004: Contract test skill-index-v3.yaml
T005: Contract test agent-index.yaml
T006: Contract test rl-metrics.yaml
```

### Batch 2: New Skills Phase 1 (T017-T021) - All Parallel
```
T017: orchestration/multi-skill-workflow
T018: orchestration/full-stack-feature
T019: domain/frontend-operations
T020: domain/backend-operations
T021: domain/database-operations
```

### Batch 3: Agent Consolidation (T023-T030) - Partially Parallel
```
T023: implementation-specialist [P]
T024: operations-specialist [P]
T025: specification-orchestrator [P]
T026: quality-specialist [P]
T027-T030: Updates/renames [P]
```

### Batch 4: DS-STAR Updates (T033-T037) - Sequential after T033
```
T033: Router Agent (must be first)
T034-T037: Remaining DS-STAR agents (after T033)
```

### Batch 5: Integration Tests (T052-T054) - All Parallel
```
T052: RL skill selection test
T053: Agent consolidation test
T054: DS-STAR flow test
```

### Batch 6: Final Skills (T055-T058) - Partially Parallel
```
T055: creation/create-skill
T056: creation/create-template
T057: orchestration/migration-workflow [P]
T058: remaining domain skills [P]
```

---

## Validation Checklist

*GATE: Verified before task generation*

- [x] All 6 contracts have corresponding tests (T001-T006)
- [x] All 8 entities from data-model.md have implementation tasks
- [x] FR-707 compliance check skill created early (T007)
- [x] All tests come before implementation (TDD ordering)
- [x] Parallel tasks are truly independent (no file conflicts)
- [x] Each task specifies exact file path
- [x] Constitutional amendment follows checklist process
- [x] Principle VI compliance: No autonomous git operations in any task
- [x] RL infrastructure tasks ordered (T008 -> T009 -> T010)
- [x] Agent consolidation tasks preserve all original capabilities
- [x] DS-STAR agents NOT consolidated (FR-709)

---

## Test Scenario Coverage

From quickstart.md v2.0.0:

| Scenario | Validation Tasks |
|----------|------------------|
| 1. FR-707 Compliance Check | T007, T054 |
| 2. RL-Enhanced Skill Selection | T009, T010, T039, T052 |
| 3. Consolidated Agent Invocation | T023-T030, T031, T053 |
| 4. DS-STAR Integration Flow | T033-T037, T054 |
| 5. Progressive Disclosure | T011, T012, T064 |
| 6. RL Performance Improvement | T063 |
| 7. Agent Consolidation Coverage | T031, T053 |
| 8. Backward Compatibility | T015, T016 |

---

## Risk Mitigation Tasks

| Risk | Task(s) | Mitigation |
|------|---------|------------|
| R-001: Constitutional Amendment | T041-T045, T061 | Staged amendment with checklist |
| R-002: Migration Disruption | T015, T016, T059, T060 | Hybrid mode with gradual transition |
| R-003: RL Instability | T009, T010, T052, T063 | EMA first, bounded weights, validation |
| R-004: Agent Consolidation Gaps | T031, T050, T053 | Explicit coverage audit |
| R-005: DS-STAR Integration | T033-T037, T054, T065 | Maintain separate agents, validate flow |
| R-006: FR-707 Bypass | T007, T054 | Mandatory first step, audit logging |

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Total Tasks | 68 |
| Contract Tests | 6 |
| Feature Tasks | 40 |
| Refactor Tasks | 13 |
| Integration Tests | 3 |
| Validation Tests | 3 |
| Documentation Tasks | 3 |
| Parallel Opportunities | 24 tasks marked [P] |
| Critical Path Tasks | 18 |

| Phase | Task Range | Duration |
|-------|------------|----------|
| Phase 1 | T001-T022 | Months 1-3 |
| Phase 2 | T023-T040 | Months 4-6 |
| Phase 3 | T041-T054 | Months 7-9 |
| Phase 4 | T055-T068 | Months 10-12 |

---

## Completion Summary

*Updated as tasks complete*

| Phase | Total | Completed | Remaining |
|-------|-------|-----------|-----------|
| Phase 1: Foundation + RL | 22 | 0 | 22 |
| Phase 2: Agent Consolidation | 18 | 0 | 18 |
| Phase 3: Constitutional Amendment | 14 | 0 | 14 |
| Phase 4: Migration Completion | 14 | 0 | 14 |
| **Total** | **68** | **0** | **68** |

---

## Audit Log

| Date | Task | Event | Agent/User |
|------|------|-------|------------|
| 2026-01-12 | ALL | Initial task list v1.0.0 generated (50 tasks) | tasks-agent |
| 2026-01-13 | ALL | Task list v2.0.0 generated (68 tasks) for RL + DS-STAR | tasks-agent |

---

**Task Generation Complete**
- Generated by: tasks-agent
- Date: 2026-01-13
- Task Version: 2.0.0
- Plan Version: 2.0.0
- Constitutional Compliance: Verified (Principles I, II, III, VI)
- Total Tasks: 68
- Parallel Opportunities: 24 tasks (35%)
- Sequential Dependencies: 44 tasks (65%)
