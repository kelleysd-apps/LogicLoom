# Implementation Plan: Skills-First Architecture with RL and DS-STAR Integration

**Branch**: `dev-main` | **Date**: 2026-01-13 | **Spec**: `specs/002-skills-first-architecture/spec.md`
**Input**: Feature specification v1.0.0 (updated with FR-600, FR-610, FR-700 series)
**Plan Version**: 2.0.0 (major update for RL, consolidation, DS-STAR)

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path [DONE]
2. Fill Technical Context (scan for NEEDS CLARIFICATION) [DONE]
3. Fill the Constitution Check section [DONE]
4. Evaluate Constitution Check section (pre-research gate) [DONE]
5. Execute Phase 0 -> research.md [DONE]
6. Execute Phase 1 -> contracts, data-model.md, quickstart.md [DONE]
7. Re-evaluate Constitution Check section (post-design gate) [DONE]
8. Plan Phase 2 -> Describe task generation approach [DONE]
9. STOP - Ready for /tasks command
```

## Summary

This implementation plan defines the comprehensive transformation from **agent-first** to **skills-first** architecture with three major enhancements:

1. **Skills-First Core** (FR-100 to FR-500): Inverts invocation model from `Agents -> Skills -> Tools` to `Skills -> Agents -> Tools`
2. **RL Enhancement** (FR-600 series): Adds reinforcement learning for skill selection optimization with performance tracking
3. **Agent Consolidation** (FR-610 series): Merges 15 domain agents into 8 consolidated agents with skill portfolios
4. **DS-STAR Integration** (FR-700 series): Integrates 5 DS-STAR agents (Router, Verifier, Auto-Debug, Finalizer, Context Analyzer) as separate specialized agents that work WITH skills

**Final Agent Count**: 8 domain agents + 5 DS-STAR agents = 13 total agents (35% reduction from 20)

**Key Technical Approach**:
- Progressive disclosure pattern for skill context loading (3 layers)
- RL-enhanced skill selection with GRPO/PPO algorithms
- skill-index.json v3 with RL metrics (success_rate, avg_tokens, selection_weight)
- Skill-initiated agent invocation with minimal context injection
- Constitutional compliance check as MANDATORY first step after every user message (FR-707)
- DS-STAR agents route to skills, not agents directly (FR-701)

## Technical Context

**Language/Version**: Markdown/YAML for definitions, Bash/TypeScript for tooling, JSON for indexes
**Primary Dependencies**: Claude Code SDK, existing SDD framework scripts, YAML/JSON parsers
**Storage**: File-based (Markdown, YAML, JSON) with skill-performance.json for RL tracking
**Testing**: Bash script testing, JSON schema validation, RL metric validation, workflow testing
**Target Platform**: Claude Code CLI environment (cross-platform)
**Project Type**: Single (framework enhancement, not web/mobile app)
**Performance Goals**:
- Skill activation <100ms
- Agent invocation <200ms
- 40-50% token reduction (progressive disclosure)
- +15-25% RL skill selection accuracy improvement
- 3.5x task completion accuracy (DS-STAR maintained)
- >70% auto-debug resolution rate
- <2s context retrieval
- 95% verifier accuracy
**Constraints**:
- Full backward compatibility during migration phases
- DS-STAR agents remain separate (NOT consolidated)
- Compliance check MUST execute on every message (FR-707)
**Scale/Scope**: 35+ skills, 13 agents (8 domain + 5 DS-STAR), 8 categories, 12-month migration timeline

**NEEDS CLARIFICATION Resolution**:
- **Claude model/API changes**: RESOLVED - No Claude API changes required. Framework changes are entirely structural.
- **GRPO/PPO implementation**: RESOLVED - Phase 3-4 advanced feature, initial implementation uses simpler exponential weighted moving average for skill weight updates.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Research Gate (PASSED)

| Principle | Requirement | Status | Notes |
|-----------|-------------|--------|-------|
| **I. Library-First (IMMUTABLE)** | Features as standalone libraries | COMPLIANT | Skills are standalone units with clear boundaries |
| **II. Test-First (IMMUTABLE)** | TDD mandatory, >80% coverage | COMPLIANT | Contract tests defined before implementation |
| **III. Contract-First (IMMUTABLE)** | Contracts before implementation | COMPLIANT | Skill/agent/RL contracts defined in Phase 1 |
| **IV. Idempotent Operations** | Safe to repeat operations | COMPLIANT | Migration scripts designed for idempotency |
| **V. Progressive Enhancement** | Start simple, add complexity when needed | COMPLIANT | 4-phase migration, hybrid mode first |
| **VI. Git Approval (CRITICAL)** | No autonomous git operations | COMPLIANT | All git operations require user approval |
| **VII. Observability** | Structured logging and metrics | COMPLIANT | RL metrics, token usage tracking, DS-STAR metrics |
| **VIII. Documentation Sync** | Docs synchronized with code | COMPLIANT | Update checklist in scope |
| **IX. Dependency Management** | Explicit, pinned dependencies | COMPLIANT | No new external dependencies |
| **X. Agent Delegation (CRITICAL)** | Specialized work to specialists | UNDER AMENDMENT | This feature rewrites Principle X |
| **XI. Input Validation** | All inputs validated | COMPLIANT | Skill/agent/RL schemas validated |
| **XII. Design System** | UI compliance | N/A | No UI components in this feature |
| **XIII. Feature Access Control** | Dual-layer enforcement | N/A | No access-controlled features |
| **XIV. AI Model Selection** | Appropriate model selection | COMPLIANT | Opus for planning, agents use Opus by default |
| **XV. File Organization** | Follow structure conventions | COMPLIANT | Uses established .claude/ structure |

### Post-Design Gate (PASSED)

All principles validated after Phase 1 design:
- Skill definitions follow Library-First (standalone units)
- Contract tests precede implementation (Test-First)
- Skill-agent-RL contracts defined (Contract-First)
- Migration designed for safe repetition (Idempotent)
- RL enhancement uses progressive enhancement (simple first, GRPO/PPO Phase 3-4)
- DS-STAR integration maintains existing quality gates
- Constitutional amendment process follows established procedures

### Special Consideration: Principle X Amendment

This feature **modifies Constitutional Principle X** from:
> "Specialized work MUST be delegated to specialized agents."

To:
> "Workflow orchestration MUST be performed by skills. Skills MUST invoke lightweight agents for specialized execution. Agents MUST NOT be invoked directly except through skill activation. DS-STAR agents (Router, Verifier, Auto-Debug, Finalizer, Context Analyzer) operate as specialized orchestration layer between skills and domain agents."

**Amendment Process Compliance**:
- [ ] Proposal documented (spec.md Section: FR-401)
- [ ] Impact analysis (constitution_update_checklist.md)
- [ ] Trial period (Phase 1-2 hybrid mode)
- [ ] Formal vote (Phase 3 ratification)
- [ ] Documentation update (Phase 4 completion)

## Project Structure

### Documentation (this feature)
```
specs/002-skills-first-architecture/
├── spec.md              # Feature specification (COMPLETE - v1.0.0 with FR-600,610,700)
├── plan.md              # This file (/plan command output - v2.0.0)
├── research.md          # Phase 0 output - Technical research (updated)
├── data-model.md        # Phase 1 output - Entity definitions (updated with RL)
├── quickstart.md        # Phase 1 output - Test scenarios (updated)
├── contracts/           # Phase 1 output - API contracts
│   ├── skill-definition.yaml      # v3 with RL fields
│   ├── agent-definition.yaml      # v2 with skill-portfolio
│   ├── skill-invocation.yaml      # v2 with rl_performance
│   ├── skill-index-v3.yaml        # NEW: RL-enhanced index
│   ├── agent-index.yaml           # NEW: consolidated agent registry
│   └── rl-metrics.yaml            # NEW: performance tracking schema
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code Changes (repository root)
```
.claude/
├── skills/                          # PRIMARY orchestration layer (expanded)
│   ├── sdd-workflow/               # Existing (enhanced)
│   │   ├── sdd-specification/
│   │   ├── sdd-planning/
│   │   ├── sdd-tasks/
│   │   └── sdd-debug/              # NEW: invokes Auto-Debug Agent (FR-703)
│   ├── validation/                  # Existing (enhanced)
│   │   ├── constitutional-compliance/
│   │   ├── domain-detection/
│   │   ├── file-organization/
│   │   ├── message-preflight/      # CRITICAL: FR-707 compliance check
│   │   └── skill-activation/
│   ├── governance/                  # Existing (enhanced)
│   │   ├── governance-preflight/
│   │   └── principle-enforcement/
│   ├── orchestration/               # NEW category
│   │   ├── multi-skill-workflow/
│   │   ├── full-stack-feature/
│   │   └── migration-workflow/
│   ├── domain/                      # NEW category
│   │   ├── frontend-operations/
│   │   ├── backend-operations/
│   │   ├── database-operations/
│   │   ├── security-operations/
│   │   ├── testing-operations/
│   │   ├── devops-operations/
│   │   └── performance-operations/
│   ├── creation/                    # NEW category
│   │   ├── create-skill/
│   │   ├── create-agent/
│   │   └── create-template/
│   ├── project-initialization/
│   └── integration/
│       └── mcp-server-setup/
├── agents/                          # SECONDARY: 8 consolidated domain agents
│   ├── product/
│   │   ├── specification-orchestrator.md  # NEW: merged spec+planning+tasks+prd
│   │   └── workflow-coordinator.md        # RENAMED: from task-orchestrator
│   ├── architecture/
│   │   └── system-architect.md            # RENAMED: from subagent-architect
│   ├── engineering/
│   │   └── implementation-specialist.md   # NEW: merged frontend+full-stack (FR-610)
│   ├── data/
│   │   └── database-specialist.md         # UNCHANGED
│   ├── operations/
│   │   └── operations-specialist.md       # NEW: merged devops+performance (FR-611)
│   └── quality/
│       └── quality-specialist.md          # NEW: merged testing+security (FR-613)
├── ds-star/                         # SEPARATE: 5 DS-STAR agents (NOT consolidated)
│   ├── router-agent.md              # Domain analysis, RL-enhanced skill routing
│   ├── verifier-agent.md            # Binary quality gates, skill output validation
│   ├── auto-debug-agent.md          # Self-healing via debug skill invocation
│   ├── finalizer-agent.md           # Pre-commit compliance, skills-first validation
│   └── context-analyzer.md          # Codebase context provider to skills
├── skill-index.json                 # v3: RL-enhanced routing
└── agent-index.json                 # NEW: consolidated 8 + separate 5 agents

.docs/
├── rl-metrics/
│   └── skill-performance.json       # NEW: RL execution history and weights

.specify/
├── memory/
│   ├── constitution.md              # Amended for Principle X + FR-707
│   ├── skill-activation-triggers.md # NEW: replaces agent-collaboration-triggers.md
│   └── agent-collaboration-triggers.md  # DEPRECATED (Phase 3)
├── config/
│   ├── architecture.conf            # Migration mode configuration
│   └── rl-config.conf               # NEW: RL parameters (learning rate, decay)
├── scripts/bash/
│   ├── migrate-agent-to-skill.sh
│   ├── skill-coverage-audit.sh
│   ├── legacy-pattern-report.sh
│   ├── update-rl-weights.sh         # NEW: RL weight update script
│   └── consolidate-agents.sh        # NEW: agent consolidation migration
└── templates/
    ├── skill-template.md
    ├── agent-template-simplified.md
    └── consolidated-agent-template.md  # NEW: for 8 domain agents
```

**Structure Decision**: Option 1 (Single project) - This is a framework enhancement, not a web/mobile application.

## Phase 0: Outline & Research

See `research.md` for complete technical research (updated for RL and DS-STAR).

### Key Research Findings

1. **Progressive Disclosure Pattern**: Three-layer loading achieves 40-50% token reduction
2. **RL for Skill Selection**: GRPO/PPO algorithms from Agent Lightning paper for credit assignment
3. **Agent Consolidation**: 15 -> 8 domain agents with skill portfolios maintains coverage
4. **DS-STAR Integration**: 5 specialized agents remain separate, work WITH skills not replaced BY skills
5. **Compliance-First Flow**: FR-707 mandates compliance check as FIRST step after every message

### Resolved NEEDS CLARIFICATION

| Unknown | Resolution | Source |
|---------|------------|--------|
| Claude model/API changes needed? | NO - Framework structural changes only | Research: LangChain patterns operate above model layer |
| GRPO/PPO implementation complexity | Deferred to Phase 3-4; Phase 1-2 uses simpler exponential weighted moving average | Research: Progressive enhancement principle |

**Output**: `research.md` - COMPLETE (v2.0.0)

## Phase 1: Design & Contracts

*Prerequisites: research.md complete*

### Entity Model

See `data-model.md` for complete entity definitions (updated for RL, consolidation, DS-STAR).

**Key Entities (NEW/UPDATED)**:
1. **Skill (Enhanced)**: Primary orchestration unit with RL metrics (success_rate, avg_tokens, avg_duration_ms, user_satisfaction, selection_weight, learning_history)
2. **Agent (Simplified with Portfolio)**: 8 consolidated domain agents with skill-portfolio field
3. **DS-STAR Agents (5)**: Separate specialized agents NOT consolidated (Router, Verifier, Auto-Debug, Finalizer, Context Analyzer)
4. **SkillInvocationContract (Enhanced)**: With rl_performance tracking per invocation
5. **SkillIndex v3**: RL-enhanced routing with performance metrics
6. **AgentIndex (NEW)**: Consolidated agent registry (8 domain + 5 DS-STAR)
7. **RLPerformanceTracker (NEW)**: skill-performance.json structure
8. **RefinementState**: DS-STAR refinement tracking (max 20 rounds, early stop 0.95)

### API Contracts

See `contracts/` directory for complete schemas.

**Contract Files (Updated/New)**:
1. `skill-definition.yaml` - v3 with RL fields (rl_metrics, learning_history)
2. `agent-definition.yaml` - v2 with skill-portfolio for consolidated agents
3. `skill-invocation.yaml` - v2 with rl_performance tracking
4. `skill-index-v3.yaml` - NEW: RL-enhanced skill index schema
5. `agent-index.yaml` - NEW: consolidated agent registry schema
6. `rl-metrics.yaml` - NEW: performance tracking and reward calculation schema

### Test Scenarios

See `quickstart.md` for complete test scenarios (updated for RL, consolidation, DS-STAR).

**Key Scenarios (New/Updated)**:
1. Skill-Initiated Agent Invocation (with RL weight update)
2. Progressive Disclosure Validation
3. RL Skill Selection Test (when multiple skills match)
4. Consolidated Agent Coverage Test (8 agents cover all 15 original domains)
5. DS-STAR Integration Test (Router -> Skill -> Agent -> Verifier flow)
6. FR-707 Compliance Check Test (first step after every message)
7. Backward Compatibility During Migration

**Output**: `data-model.md`, `contracts/*`, `quickstart.md` - COMPLETE (v2.0.0)

## Phase 2: Task Planning Approach

*This section describes what the /tasks command will do - DO NOT execute during /plan*

### Task Generation Strategy

**Source Documents**:
- `plan.md` (this file) - Structure decisions
- `research.md` - Technology decisions including RL algorithms
- `data-model.md` - Entity implementations with RL fields
- `contracts/*` - Schema implementations (6 contracts)
- `quickstart.md` - Test scenario tasks

### Task Categories

**Category 1: Foundation + RL Foundation (Phase 1 - Months 1-3)**
- skill-index.json v3 schema with RL metrics
- skill-performance.json structure
- Progressive disclosure loader
- RL data collection infrastructure
- Hybrid architecture mode flag
- message-preflight skill for FR-707

**Category 2: Agent Consolidation (Phase 2 - Months 4-6)**
- Merge frontend-specialist + full-stack-developer -> implementation-specialist (FR-610)
- Merge devops-engineer + performance-engineer -> operations-specialist (FR-611)
- Merge spec+planning+tasks+prd -> specification-orchestrator (FR-612)
- Merge testing+security -> quality-specialist (FR-613)
- agent-index.json creation with skill portfolios
- Migrate skill invocations to consolidated agents

**Category 3: DS-STAR Integration (Phase 2-3)**
- Router Agent skill routing integration (FR-701)
- Verifier Agent skill output validation (FR-702)
- debug skill -> Auto-Debug Agent invocation (FR-703)
- Finalizer Agent skills-first validation (FR-704)
- Context Analyzer skill context provider (FR-705)
- Refinement Engine skill procedure refinement (FR-706)

**Category 4: RL Enhancement (Phase 2-3)**
- RL skill selection algorithm operational (FR-601)
- skill weight update implementation (exponential moving average)
- Performance metric logging
- A/B testing framework for +15-25% accuracy validation

**Category 5: Constitutional Amendment + Advanced RL (Phase 3 - Months 7-9)**
- Principle X rewrite draft
- Pre-flight protocol update for skill detection
- skill-activation-triggers.md creation
- Credit assignment module (FR-602 - deferred)
- Skill prototype library with rubrics (FR-605 - deferred)

**Category 6: Migration Completion (Phase 4 - Months 10-12)**
- Complete skill taxonomy (35+ skills)
- Block legacy agent-first patterns
- Constitution v2.0.0 ratification
- Enable continuous RL learning loop
- Validate 15-25% skill selection accuracy improvement

### Ordering Strategy

**TDD Order**: Contract tests -> Unit tests -> Integration tests -> Implementation
**Dependency Order**:
1. RL infrastructure -> skill-index v3 -> skill selection
2. Agent consolidation -> agent-index -> skill portfolio mapping
3. DS-STAR integration -> workflow validation
4. Constitutional amendment -> compliance validation

**Parallelization Markers**: [P] for tasks that can run in parallel after foundation

### Estimated Output

- **Total Tasks**: 55-65 numbered, ordered tasks (increased from 40-50 for RL/DS-STAR)
- **Parallel Opportunities**: 25-30 tasks can run in parallel
- **Sequential Dependencies**: 25-30 tasks with strict ordering
- **Duration Alignment**: Tasks mapped to 12-month migration timeline

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation

*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)
**Phase 4**: Implementation (execute tasks.md following constitutional principles)
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking

*Constitutional Principle X is being amended with RL and DS-STAR integration, which is significant complexity.*

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Principle X Rewrite | Current agent-first pattern causes 40-50% token inefficiency; skills-first enables progressive disclosure | Incremental optimization insufficient for token reduction goals |
| RL Enhancement (FR-600) | Static skill selection cannot improve over time; RL enables +15-25% accuracy improvement | Rule-based selection rejected - no learning capability |
| Agent Consolidation 15->8 | Reduces cognitive load, simplifies routing, 35% fewer agents | Keeping 15 rejected - redundant capabilities in merged agents |
| DS-STAR Agents Separate (5) | Specialized orchestration functions require dedicated agents | Consolidating DS-STAR rejected - would lose specialization benefits |
| 35+ Skills (vs 13) | Comprehensive skill coverage enables skills as primary orchestration layer | Fewer skills would require agents to handle skill-like routing |
| 12-Month Migration | Full backward compatibility requires gradual transition | Faster migration would break existing workflows |
| Hybrid Architecture Mode | Supports both patterns during transition | Single-pattern switch would cause immediate breaking changes |

## Progress Tracking

*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command) - v2.0.0 with RL/DS-STAR
- [x] Phase 1: Design complete (/plan command) - v2.0.0 with RL/DS-STAR
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS (with Principle X amendment noted)
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented
- [x] RL enhancement requirements integrated
- [x] Agent consolidation plan complete
- [x] DS-STAR integration requirements mapped

---
*Based on Constitution v1.6.0 - See `.specify/memory/constitution.md`*
*Feature targets Constitution v2.0.0 upon completion*
*Plan Version: 2.0.0 - Updated for FR-600, FR-610, FR-700 series requirements*
