# Feature Specification: Skills-First Architecture Paradigm Shift

**Feature Branch**: `dev-main` (working on current branch per user decision)
**Feature Number**: 002
**Created**: 2026-01-12
**Status**: Draft
**Priority**: High (Architectural Foundation)

---

## Executive Summary

This specification defines a fundamental architectural paradigm shift from **agent-first** to **skills-first** architecture within the SDD Framework. Based on comprehensive industry research (LangChain 2026 patterns, CrewAI, AutoGen multi-agent paradigms), this transformation inverts the current invocation model from `Agents -> Skills -> Tools` to `Skills -> Agents -> Tools`, making skills the primary orchestration layer while reducing agents to lightweight, context-minimal executors.

**Expected Outcomes**:
- 40-50% token efficiency improvement through progressive disclosure
- Reduced cognitive load on agents (lighter context footprints)
- Skill-centric development as the primary creation path
- 6-12 month parallel migration supporting both patterns

---

## User Scenarios & Testing

### Primary User Story

As a **framework developer**, I want skills to be the primary orchestration layer instead of agents, so that I can achieve better token efficiency, reduce context window consumption, and create a more maintainable, composable system where specialized procedural knowledge drives agent invocation rather than agents driving skill consumption.

### Secondary User Stories

**US-001**: As a **framework maintainer**, I want agents to have minimal context footprints, so that the system uses fewer tokens per operation and can scale to more complex workflows.

**US-002**: As a **skill author**, I want `/create-skill` to be the primary creation command (replacing `/create-agent` as the default path), so that the framework reflects skills-first philosophy.

**US-003**: As an **orchestration system**, I want skills to determine which agents to invoke with what minimal context, so that agents become lightweight executors rather than context-heavy decision makers.

**US-004**: As a **migrating user**, I want both agent-first and skills-first patterns to work during a transition period, so that existing workflows are not disrupted while new patterns are adopted.

**US-005**: As a **constitutional governance system**, I want Principle X to be rewritten to reflect skills-first delegation rather than agent-first delegation, so that the constitution accurately governs the new architecture.

### Acceptance Scenarios

**Scenario 1: Skill-Initiated Agent Invocation**
- **Given** a skill `sdd-specification` is activated
- **When** the skill determines specialized work is needed (e.g., database schema)
- **Then** the skill invokes `database-specialist` agent with minimal required context
- **And** the agent receives only the context subset relevant to its task
- **And** token usage is measurably reduced (target: 40% reduction vs current pattern)

**Scenario 2: Progressive Disclosure in Action**
- **Given** a user invokes `/specify user-authentication`
- **When** the system activates the `sdd-specification` skill
- **Then** context loading follows progressive disclosure: metadata (100 tokens) -> instructions (500 tokens) -> supporting files (on-demand)
- **And** total context does not exceed 1000 tokens until specialized work requires more

**Scenario 3: New Skill Creation Path**
- **Given** a user wants to create new capability
- **When** they invoke `/create-skill notification-handling`
- **Then** the skill-creation skill guides them through skill definition
- **And** the skill is created as primary entity (not wrapped in an agent)
- **And** the skill specifies which agents it may invoke

**Scenario 4: Backward Compatibility During Migration**
- **Given** existing workflows use agent-first patterns (Principle X current)
- **When** skills-first architecture is deployed (Phase 1)
- **Then** existing agent invocations continue to work
- **And** new skills-first invocations work alongside
- **And** migration warnings guide users toward new patterns

**Scenario 5: Constitutional Principle X Rewrite**
- **Given** the current Principle X mandates agent delegation
- **When** the skills-first architecture is fully adopted
- **Then** Principle X is rewritten to mandate skill activation with agent invocation
- **And** the 4-step pre-flight protocol references skills before agents
- **And** all compliance checks validate skill-centric patterns

### Edge Cases

- **EC-001**: What happens when a skill needs an agent that does not exist?
  - System should fail gracefully with skill providing fallback or error

- **EC-002**: What happens when agents receive conflicting context from multiple skills?
  - Skills must provide non-overlapping context; orchestration skill manages conflicts

- **EC-003**: What happens when migration period ends but old patterns are still used?
  - Deprecation warnings become errors; legacy patterns blocked

- **EC-004**: How do skills handle multi-domain work that previously required task-orchestrator?
  - New `orchestration-skill` coordinates multiple skill activations and their agent invocations

---

## Requirements

### Functional Requirements

#### Core Architecture (FR-100 Series)

**FR-101**: System MUST implement inverted invocation model: Skills -> Agents -> Tools
- Skills become primary orchestration layer
- Agents become lightweight executors with minimal context
- Tools remain unchanged (lowest layer)

**FR-102**: System MUST implement progressive disclosure for skill context loading
- Layer 1: Skill metadata (name, description, triggers) - loaded always
- Layer 2: Skill instructions (procedure, steps) - loaded on activation
- Layer 3: Supporting files (examples, references) - loaded on-demand

**FR-103**: System MUST reduce agent context footprint by minimum 40%
- Agents receive only task-relevant context from invoking skill
- Agents do not load full constitution, CLAUDE.md, or other framework context
- Minimal context passed: task description, relevant constraints, output expectations

**FR-104**: System MUST maintain skill -> agent invocation contract
- Skills specify which agents they may invoke
- Skills specify what context to pass to each agent
- Agents specify what context they require (minimum viable context)

#### Skill Taxonomy Expansion (FR-200 Series)

**FR-201**: System MUST expand skill taxonomy from 13 to 35+ skills across 8 categories

**Current Categories (to be expanded)**:
1. `sdd-workflow/` - Core SDD methodology (5 skills)
2. `validation/` - Quality gates and compliance (5 skills)
3. `governance/` - Constitutional enforcement (2 skills)
4. `project-initialization/` - Project setup (1 skill)
5. `integration/` - External system integrations (varies)

**New Categories (to be added)**:
6. `orchestration/` - Multi-skill coordination (3+ skills)
7. `domain/` - Domain-specific procedural knowledge (10+ skills)
8. `creation/` - Entity creation skills (3+ skills)

**FR-202**: System MUST implement skill inheritance and composition patterns
- Base skills can be extended by specialized skills
- Skills can compose other skills for complex workflows
- Skill dependencies are explicitly declared

**FR-203**: System MUST implement `/create-skill` as primary creation command
- Creates skill definition in `.claude/skills/[category]/[skill-name]/SKILL.md`
- Generates skill structure following progressive disclosure
- Specifies agent invocation patterns within skill definition

#### Agent Simplification (FR-300 Series)

**FR-301**: System MUST simplify agent definitions to lightweight executors
- Agent context reduced to: purpose, tools, output format
- Agent does NOT include full workflow context
- Agent receives context from invoking skill

**FR-302**: System MUST update all 15 existing agents to skills-first pattern
- Each agent specifies minimum viable context requirements
- Each agent specifies compatible skills that may invoke it
- Agent-skill compatibility matrix maintained

**FR-303**: System MUST implement agent context injection protocol
- Skills inject context into agents at invocation time
- Context scoped to current task only
- Previous task context explicitly cleared or passed

#### Constitutional Amendment (FR-400 Series)

**FR-401**: System MUST rewrite Constitutional Principle X for skills-first architecture

**Current Principle X** (Agent Delegation Protocol):
> "Specialized work MUST be delegated to specialized agents."

**New Principle X** (Skills-First Orchestration Protocol):
> "Workflow orchestration MUST be performed by skills. Skills MUST invoke lightweight agents for specialized execution. Agents MUST NOT be invoked directly except through skill activation."

**FR-402**: System MUST update 4-step pre-flight compliance protocol
- Step 2 becomes: "Analyze task for skill activation triggers" (not agent delegation)
- Step 3 becomes: "Activate appropriate skill; skill determines agent invocation"
- Step 4 becomes: "Skill executes, invoking agents as needed"

**FR-403**: System MUST update agent-collaboration-triggers.md to skill-activation-triggers.md
- Domain keywords map to skills (not agents)
- Skills internally map to agents they may invoke

#### Migration Support (FR-500 Series)

**FR-501**: System MUST support parallel operation of agent-first and skills-first patterns
- Migration flag in `.specify/config/architecture.conf`
- `ARCHITECTURE_MODE=hybrid|skills-first|legacy-agents`
- Default: `hybrid` during migration period

**FR-502**: System MUST emit deprecation warnings for direct agent invocation
- Warn when agents invoked without skill context
- Suggest equivalent skill activation
- Track legacy pattern usage for migration metrics

**FR-503**: System MUST provide migration tooling
- `migrate-agent-to-skill.sh` - converts agent workflow to skill
- `skill-coverage-audit.sh` - identifies agents without invoking skills
- `legacy-pattern-report.sh` - reports direct agent invocations

**FR-504**: System MUST define migration timeline
- Phase 1 (Months 1-3): Hybrid mode, new skills created
- Phase 2 (Months 4-6): Skills-first encouraged, legacy warnings
- Phase 3 (Months 7-9): Skills-first default, legacy deprecated
- Phase 4 (Months 10-12): Legacy patterns blocked, full migration

#### Reinforcement Learning & Learning (FR-600 Series)

**FR-601**: System MUST implement RL-enhanced skill registry with performance tracking
- Skill-index.json v3 includes RL metrics: success_rate, avg_tokens, avg_duration_ms, user_satisfaction, selection_weight
- Skills track performance across invocations for continuous improvement
- Learning history persisted with delta tracking (timestamp, reward, weight_delta)
- RL selection algorithm chooses skills based on learned weights when multiple skills match triggers

**FR-602**: System MUST implement credit assignment module for reward attribution
- Track LLM requests per skill/agent invocation
- Calculate contribution of each skill and agent to task outcome
- Implement reward calculation using GRPO (Generalized Reward Policy Optimization) or PPO (Proximal Policy Optimization)
- Update skill selection weights based on attributed rewards
- **Note**: Deferred to Phase 3-4 (advanced RL)

**FR-603**: System MUST consolidate 15 specialized agents into 8 domain agents with skill portfolios
- **Consolidation mapping**:
  - Merge `frontend-specialist` + `full-stack-developer` → `implementation-specialist`
  - Merge `devops-engineer` + `performance-engineer` → `operations-specialist`
  - Merge `specification-agent` + `planning-agent` + `tasks-agent` → `specification-orchestrator`
  - Merge `testing-specialist` + `security-specialist` → `quality-specialist`
  - Rename `subagent-architect` → `system-architect`
  - Rename `task-orchestrator` → `workflow-coordinator`
  - Remove `constitutional-governance-agent` (becomes `governance-preflight` skill)
  - Remove `prd-specialist` (merged into `specification-orchestrator`)
- Each consolidated agent maintains skill coverage from merged agents
- Domain agents assigned to skill portfolios (not rigid departments)

**FR-604**: System MUST implement skill performance tracking for RL feedback loop
- Log skill execution metrics: task_success, tokens_used, duration_ms, user_feedback
- Store metrics in `.docs/rl-metrics/skill-performance.json`
- Implement reward calculation function with configurable weights
- Update skill weights using policy optimizer after each invocation
- **Performance Targets**:
  - Skill selection accuracy improvement: +15-25% over baseline
  - Self-improvement observable within 30-day evaluation window

**FR-605**: System MUST implement skill prototype library with validation rubrics
- Curated library of validated skill templates
- Context-specific rubrics for skill quality evaluation
- Transform open-ended LLM evaluation into constrained verification
- Reduce reward variance through structured validation
- **Note**: Deferred to Phase 3-4 (advanced RL)

#### Agent Consolidation Details (FR-610 Series)

**FR-610**: `implementation-specialist` agent MUST cover UI/integration skill portfolio
- **Skills**: ui-development, component-design, state-management, api-integration, e2e-feature-development
- **Merged From**: frontend-specialist (UI/React), full-stack-developer (integration)
- **Tools**: Read, Write, Bash, MultiEdit, Edit
- **Rationale**: Both agents handle implementation work; skills differentiate UI vs full-stack complexity

**FR-611**: `operations-specialist` agent MUST cover runtime/infrastructure skill portfolio
- **Skills**: deployment, ci-cd, monitoring, performance-optimization, scaling
- **Merged From**: devops-engineer (deployment), performance-engineer (optimization)
- **Tools**: Read, Write, Bash, Grep, Glob
- **Rationale**: Both handle runtime/infrastructure; skills separate deployment vs performance concerns

**FR-612**: `specification-orchestrator` agent MUST cover product workflow skill portfolio
- **Skills**: requirement-analysis, implementation-planning, task-decomposition, prd-creation
- **Merged From**: specification-agent, planning-agent, tasks-agent, prd-specialist
- **Tools**: Read, Write, Bash, MultiEdit, TodoWrite
- **Rationale**: All handle product/workflow phases; skills differentiate specification → planning → tasks progression

**FR-613**: `quality-specialist` agent MUST cover QA/security skill portfolio
- **Skills**: test-strategy, security-review, qa-validation, penetration-testing, compliance-audit
- **Merged From**: testing-specialist, security-specialist
- **Tools**: Read, Write, Bash, Grep, Glob
- **Rationale**: Both handle quality assurance; skills separate testing vs security domains

**FR-614**: System MUST update agent skill portfolio mappings
- Each agent maintains list of skills it can execute
- Skills reference compatible agents in agent-invocations field
- Agent-skill compatibility matrix in agent-index.json
- Validation ensures skills only invoke compatible agents

#### DS-STAR Integration (FR-700 Series)

**FR-701**: System MUST integrate Router Agent with RL-enhanced skill selection
- Router Agent routes to SKILLS (not agents directly) after compliance check
- RL metrics inform router's skill selection algorithm
- Router logs skill routing decisions with confidence scores
- **Performance Target**: 3.5x task completion accuracy maintained from Feature 001

**FR-702**: System MUST adapt Verifier Agent for skill output validation
- Verifier validates both skill coordination quality and agent outputs
- Quality gates apply to skill-orchestrated workflows
- Binary decisions (sufficient/insufficient) block progression when quality unmet
- RL learns quality patterns to reduce false positives over time
- **Performance Target**: Binary decisions with 95% accuracy

**FR-703**: System MUST integrate Auto-Debug Agent with debug skill invocation
- `debug` skill invokes Auto-Debug Agent for error resolution (not direct invocation)
- Auto-Debug operates within skill context with error type classification
- RL learns which fix patterns work best for specific error types
- **Performance Target**: >70% auto-fix resolution rate maintained from Feature 001

**FR-704**: System MUST adapt Finalizer Agent for skills-first workflows
- Finalizer validates skill-coordinated multi-agent workflows
- Pre-commit gates check skill execution completeness and agent output quality
- Constitutional compliance includes skills-first pattern validation
- **Performance Target**: Zero false passes on quality gates

**FR-705**: System MUST integrate Context Analyzer with skill invocation
- Context Analyzer provides codebase context TO skills (not directly to agents)
- Skills use context to inform agent invocation decisions
- Context passed through skill → agent with minimal footprint
- RL optimizes context relevance ranking
- **Performance Target**: <2s context retrieval maintained from Feature 001

**FR-706**: System MUST adapt Refinement Engine for skill procedure refinement
- Refinement loops (max 20 rounds) apply to skill outputs AND agent outputs
- Early stopping threshold (0.95 quality) applies to skill coordination quality
- Feedback accumulation informs skill procedure improvements across iterations
- RL adjusts refinement thresholds based on effectiveness
- **Performance Target**: Early stopping achieved in <10 rounds on average

**FR-707**: System MUST enforce compliance check as FIRST step after user message
- Constitutional compliance check (message-preflight skill) runs IMMEDIATELY after user message
- Compliance check can run in background (non-blocking) but MUST execute
- Compliance check precedes Router Agent skill selection
- No workflow step may bypass compliance check
- **Critical**: User message → Compliance Check → Router Agent → Skill Selection → Agent Invocation
- Audit trail logs compliance check execution timestamp for every message

**FR-708**: System MUST maintain DS-STAR performance targets post-migration
- 3.5x task completion accuracy (measured baseline → skills-first)
- >70% auto-debug resolution rate
- <2s context retrieval
- 95% verifier accuracy
- All DS-STAR metrics continue during and after migration
- Performance regression alerts if targets not met

**FR-709**: System MUST preserve DS-STAR agent specialization (no consolidation)
- DS-STAR agents remain separate specialized agents (5 agents)
- DS-STAR agents NOT consolidated with domain agents
- **Total agent count**: 8 domain agents + 5 DS-STAR agents = 13 agents
- DS-STAR agents work WITH skills (not replaced by skills)

### Non-Functional Requirements

**NFR-001**: Token Efficiency
- Target: 40-50% reduction in average tokens per operation
- Measurement: Baseline current token usage, measure post-migration
- Context window consumption reduced through progressive disclosure

**NFR-002**: Backward Compatibility
- 100% of existing workflows MUST work during Phase 1-2
- 95% of existing workflows MUST work during Phase 3
- Clear migration path for remaining 5%

**NFR-003**: Documentation Completeness
- All 35+ skills fully documented
- Migration guide published
- Constitutional amendment ratified

**NFR-004**: Performance
- Skill activation latency: <100ms
- Agent invocation from skill: <200ms
- No performance degradation vs current patterns

### Key Entities

**Skill** (Enhanced with RL)
- Primary orchestration unit replacing agent-first invocation
- Attributes: name, description, triggers, instructions, agent-invocations, tool-restrictions, rl_metrics, learning_history
- **RL Attributes**: success_rate, avg_tokens, avg_duration_ms, user_satisfaction, selection_weight
- Relationships: invokes Agents, composes other Skills, belongs to Category

**Agent** (Simplified with Skill Portfolio)
- Lightweight executor with minimal context
- Attributes: purpose, required-context, tools, output-format, skill-portfolio
- **Skill Portfolio**: List of skills this agent can execute
- Relationships: invoked by Skills, uses Tools, executes Skill Portfolio

**Skill Category**
- Organizational grouping for skills
- Attributes: name, description, skills[], governance-level
- 8 categories in expanded taxonomy

**Skill Invocation Contract** (Enhanced with Performance Tracking)
- Defines skill -> agent context passing
- Attributes: skill-id, agent-id, context-subset, expected-output, rl_performance
- **RL Performance**: Per-agent metrics within skill context (invocation_count, success_rate, avg_tokens)
- Enforces minimal context principle

**Skill Index** (v3 with RL Enhancement)
- `.claude/skill-index.json` v3 becomes primary routing mechanism with RL
- Maps: trigger-keywords -> skills -> agents
- Includes RL metrics for skill selection optimization
- Auto-generated by skill discovery with performance tracking

**Agent Index** (NEW)
- `.claude/agent-index.json` capability registry
- Maps: domain -> agents -> skill-portfolios
- Consolidated agent directory (8 domain agents)
- Agent-skill compatibility matrix

**RL Performance Tracker** (NEW)
- `.docs/rl-metrics/skill-performance.json` stores execution history
- Tracks: task outcomes, token usage, duration, user feedback
- Provides data for reward calculation and weight updates
- Enables continuous improvement analytics

**DS-STAR Agents** (Feature 001 Integration - NOT Consolidated)
- **Router Agent** (architecture dept) - Domain analysis, RL-enhanced skill routing
- **Verifier Agent** (quality dept) - Binary quality gates, skill output validation
- **Auto-Debug Agent** (engineering dept) - Self-healing via debug skill invocation
- **Finalizer Agent** (quality dept) - Pre-commit compliance, skills-first validation
- **Context Analyzer** (architecture dept) - Codebase context provider to skills
- **Total**: 5 DS-STAR agents remain separate, specialized
- **Relationships**: Work WITH skills (Router→Skills, Skills→Verifier, Skills→Auto-Debug via debug skill)

**Refinement State** (DS-STAR Feature 001)
- Tracks iterative refinement progress (current round, max 20)
- Attributes: iteration_count, quality_score, feedback_log, early_stop_triggered
- Controls refinement engine loops with RL-adjusted thresholds
- Relationships: Updated by Verifier, used by skills for improvement

---

## Technical Considerations

### Architecture Changes

**Current Architecture** (Agent-First):
```
User Request
    |
    v
4-Step Pre-Flight (agent detection)
    |
    v
Agent Delegation (Principle X)
    |
    v
Agent Loads Context (CLAUDE.md, Constitution, Domain knowledge)
    |
    v
Agent May Activate Skills
    |
    v
Agent Uses Tools
    |
    v
Result
```

**New Architecture** (Skills-First + DS-STAR Integrated):
```
User Request
    |
    v
[CRITICAL] Constitutional Compliance Check (message-preflight skill)
    |  → Runs in background, logs timestamp
    |  → FR-707: MUST execute on every message
    v
4-Step Pre-Flight (skill detection via Router Agent)
    |  → Router Agent (DS-STAR) analyzes domain
    |  → RL-enhanced skill selection
    v
Skill Activation (Revised Principle X)
    |  → Skill selected based on triggers + RL weights
    v
Skill Loads Progressively (metadata -> instructions -> files)
    |  → Layer 1: Metadata (100 tokens)
    |  → Layer 2: Instructions (500 tokens)
    |  → Layer 3: Supporting files (on-demand)
    v
Context Analyzer (DS-STAR) - Optional
    |  → Provides codebase context TO skill (<2s)
    |  → RL-optimized relevance ranking
    v
Skill Determines Agent Needs
    |  → Checks agent-invocations field
    |  → Prepares minimal context subset
    v
Skill Invokes Domain Agent(s) with Minimal Context
    |  → implementation-specialist, quality-specialist, etc.
    |  → Context injection (200-400 tokens)
    v
Agent Executes with Injected Context + Tools
    |
    v
Verifier Agent (DS-STAR) - Quality Gate
    |  → Binary decision: sufficient/insufficient
    |  → RL learns quality patterns
    |  → Blocks if quality unmet
    v
[If insufficient] Refinement Engine (DS-STAR)
    |  → Max 20 rounds, early stop at 0.95
    |  → Feedback accumulation
    |  → RL adjusts thresholds
    |  → Loop back to skill
    v
[If error] Auto-Debug Agent (DS-STAR) via debug skill
    |  → >70% auto-fix target
    |  → RL learns fix patterns
    v
Result Returns to Skill
    |
    v
Skill Orchestrates / Aggregates Results
    |
    v
Finalizer Agent (DS-STAR) - Pre-Commit Gate
    |  → Constitutional compliance
    |  → Skills-first pattern validation
    |  → Zero false passes
    v
[RL Feedback Loop]
    |  → Update skill selection_weight
    |  → Update agent rl_performance
    |  → Log to skill-performance.json
    v
Final Result
```

### Skill Structure (Enhanced)

```yaml
# SKILL.md Frontmatter (Enhanced)
---
name: skill-name
version: 1.0.0
description: |
  What the skill does (max 1024 chars)
triggers:
  - keyword1
  - keyword2
  - /command
allowed-tools: Read, Write, Bash
agent-invocations:
  - agent: database-specialist
    context-subset: [data-model, constraints]
    when: "database schema work needed"
  - agent: backend-architect
    context-subset: [api-contracts, endpoints]
    when: "API design work needed"
composes:
  - skill: validation/constitutional-compliance
    phase: pre-execution
  - skill: validation/domain-detection
    phase: analysis
progressive-disclosure:
  layer1: [name, description, triggers]  # Always loaded
  layer2: [instructions, agent-invocations]  # On activation
  layer3: [examples, references, scripts]  # On demand
---
```

### Agent Definition (Simplified)

```yaml
# Agent Definition (Simplified)
---
name: database-specialist
purpose: Execute database schema and query operations
required-context:
  - data-model
  - constraints
  - schema-requirements
output-format: markdown | json | sql
tools: Read, Write, Bash, MultiEdit
invoked-by:
  - sdd-workflow/sdd-planning
  - domain/database-operations
  - orchestration/full-stack-workflow
---
```

### File Structure Changes

```
.claude/
  skills/                          # PRIMARY orchestration layer
    sdd-workflow/
      sdd-specification/SKILL.md   # Invokes agents as needed
      sdd-planning/SKILL.md
      sdd-tasks/SKILL.md
    validation/
      constitutional-compliance/SKILL.md
      domain-detection/SKILL.md
      skill-activation/SKILL.md    # NEW: validates skill invocations
    governance/
      governance-preflight/SKILL.md
      principle-enforcement/SKILL.md  # NEW
    orchestration/                  # NEW category
      multi-skill-workflow/SKILL.md
      full-stack-feature/SKILL.md
      migration-workflow/SKILL.md
    domain/                         # NEW category
      frontend-operations/SKILL.md
      backend-operations/SKILL.md
      database-operations/SKILL.md
      security-operations/SKILL.md
      testing-operations/SKILL.md
      devops-operations/SKILL.md
      performance-operations/SKILL.md
    creation/                       # NEW category
      create-skill/SKILL.md         # PRIMARY creation path
      create-agent/SKILL.md         # Secondary (invokes subagent-architect)
      create-template/SKILL.md
    project-initialization/SKILL.md
    integration/
      mcp-server-setup/SKILL.md
  agents/                          # SECONDARY: lightweight executors
    [structure unchanged but definitions simplified]
  skill-index.json                 # PRIMARY routing (enhanced)
  agent-index.json                 # NEW: agent capability registry
```

---

## Dependencies

### Internal Dependencies
- Constitution v1.6.0 (requires amendment to v2.0.0 for Principle X rewrite)
- All 15 existing agents (require simplification)
- All 13 existing skills (require enhancement)
- CLAUDE.md (requires update for skills-first routing)
- AGENTS.md (requires update for simplified agent definitions)

### External Dependencies
- None identified

### Assumptions
- [NEEDS CLARIFICATION: Will this require Claude model changes or API updates?]
- Framework versioning supports major version bump (v3.x -> v4.0)
- User community accepts 6-12 month migration timeline
- Existing projects can adopt incrementally

---

## Risks

### High Risk

**R-001**: Constitutional Amendment Complexity
- **Risk**: Principle X rewrite may have cascading effects across all documentation
- **Mitigation**: Use `constitution_update_checklist.md` rigorously; staged amendment process

**R-002**: Migration Disruption
- **Risk**: Existing workflows break during migration
- **Mitigation**: Hybrid mode with full backward compatibility; extensive testing

### Medium Risk

**R-003**: Skill Explosion
- **Risk**: 35+ skills may become unmanageable
- **Mitigation**: Strong taxonomy; skill discovery tooling; category governance

**R-004**: Agent Under-Context
- **Risk**: Simplified agents may lack context needed for complex work
- **Mitigation**: Skills responsible for context adequacy; validation checks

### Low Risk

**R-005**: Performance Overhead
- **Risk**: Additional skill layer adds latency
- **Mitigation**: Progressive disclosure minimizes actual overhead; target <100ms

---

## Success Metrics

| Metric | Current Baseline | Target | Measurement Method |
|--------|------------------|--------|-------------------|
| Token usage per operation | TBD (baseline) | 40-50% reduction | Token counting before/after |
| Agent context size | ~5000 tokens avg | <2000 tokens avg | Context audit tool |
| Skill count | 13 | 35+ | Skill index count |
| Agent count (domain) | 15 | 8 (47% reduction) | Agent registry |
| Agent count (total) | 20 (15+5 DS-STAR) | 13 (8+5 DS-STAR, 35% reduction) | Agent registry |
| Migration completion | 0% | 100% by Month 12 | Migration dashboard |
| Backward compatibility | N/A | 100% Phase 1-2 | Workflow test suite |
| Developer satisfaction | TBD | >80% positive | Survey |
| **RL skill selection accuracy** | Random (baseline) | +15-25% improvement | A/B testing framework |
| **Self-improvement rate** | N/A | Observable in 30 days | Performance delta analysis |
| **Skill routing efficiency** | TBD | <100ms selection time | Latency monitoring |
| **Agent consolidation coverage** | N/A | 100% skill coverage maintained | Skill-agent mapping validation |
| **DS-STAR: Task completion accuracy** | Current (baseline) | 3.5x improvement maintained | Feature 001 metrics |
| **DS-STAR: Auto-debug resolution** | N/A | >70% auto-fix rate | Auto-debug success logs |
| **DS-STAR: Context retrieval** | TBD | <2s retrieval time | Context analyzer metrics |
| **DS-STAR: Verifier accuracy** | TBD | 95% binary decision accuracy | Verifier decision audit |
| **DS-STAR: Compliance check coverage** | N/A | 100% messages checked | Audit log analysis |

---

## Phased Implementation Overview

### Phase 1: Foundation + RL Foundation (Months 1-3)
- Create 10 new skills in expanded taxonomy
- Implement progressive disclosure loader
- **Create skill-index.json v3 with RL metrics** (FR-601, FR-604)
- **Implement skill performance tracking** (FR-604)
- Implement hybrid architecture mode
- **Begin RL data collection** (execution metrics, outcomes)
- No breaking changes; full backward compatibility

### Phase 2: Agent Consolidation + Simplification (Months 4-6)
- **Consolidate 15 agents → 8 domain agents** (FR-603, FR-610-614)
- **Create agent-index.json with skill portfolios** (FR-614)
- Implement agent context injection protocol
- **Migrate skill invocations to consolidated agents**
- Skills-first encouraged; legacy warnings begin
- Document migration patterns
- **RL skill selection algorithm operational** (FR-601)

### Phase 3: Constitutional Amendment + Advanced RL (Months 7-9)
- Draft Principle X rewrite
- Update pre-flight protocol for skill detection
- Rename agent-collaboration-triggers.md to skill-activation-triggers.md
- Skills-first becomes default
- Legacy patterns deprecated with warnings
- **Implement credit assignment module** (FR-602 - deferred from Phase 1)
- **Skill prototype library with rubrics** (FR-605 - deferred from Phase 1)

### Phase 4: Full Migration + Continuous Learning (Months 10-12)
- Complete skill taxonomy (35+ skills)
- Block legacy agent-first patterns
- Ratify Constitution v2.0.0
- Remove hybrid mode
- Publish migration completion report
- **Enable continuous RL learning loop**
- **Validate 15-25% skill selection accuracy improvement**
- **Measure self-improvement over 30-day window**

---

## Review & Acceptance Checklist

### Content Quality
- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for stakeholders at multiple levels
- [x] All mandatory sections completed

### Requirement Completeness
- [ ] No [NEEDS CLARIFICATION] markers remain (1 remains - see Assumptions)
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

### Domain Analysis
**Detected Domains**: product, architecture, governance, all-engineering-domains
**Suggested Agents for Implementation**:
- specification-agent (this spec - COMPLETE)
- planning-agent (next: implementation plan)
- task-orchestrator (multi-domain coordination)
- All domain specialists (for skill creation in their domains)
**Delegation Strategy**: Multi-agent orchestrated workflow

---

## Execution Status

- [x] User description parsed
- [x] Key concepts extracted
- [x] Ambiguities marked (1 NEEDS CLARIFICATION)
- [x] User scenarios defined (5 stories, 5 acceptance scenarios, 4 edge cases)
- [x] Requirements generated (20 functional requirements, 4 NFRs)
- [x] Entities identified (5 key entities)
- [ ] Review checklist passed (pending NEEDS CLARIFICATION resolution)

---

## Next Steps

1. **Resolve NEEDS CLARIFICATION**: Determine if Claude model/API changes are needed
2. **Run `/plan`**: Generate implementation plan with research, data-model, and contracts
3. **Run `/tasks`**: Generate phased task breakdown aligned with 12-month timeline
4. **Constitutional Review**: Engage stakeholders on Principle X amendment process

---

**Specification Version**: 1.0.0
**Created By**: specification-agent
**Constitutional Compliance**: Pending (awaiting Principle X amendment)
