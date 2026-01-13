# Quickstart Testing Guide: Skills-First Architecture with RL and DS-STAR

**Feature**: 002-skills-first-architecture
**Date**: 2026-01-13
**Status**: Ready for Testing
**Version**: 2.0.0 (updated for FR-600, FR-610, FR-700 series)
**Purpose**: Validate skills-first architecture with RL enhancement, agent consolidation, and DS-STAR integration

---

## Prerequisites

Before testing, ensure:
- [ ] SDD Framework v3.1.x installed
- [ ] Claude Code CLI available
- [ ] Repository cloned and on `dev-main` branch
- [ ] All Phase 1 artifacts created (plan.md, research.md, data-model.md, contracts/)
- [ ] skill-index.json v3 structure created
- [ ] agent-index.json structure created
- [ ] skill-performance.json initialized

---

## Test Scenarios

### Scenario 1: FR-707 Compliance Check (CRITICAL - Must Pass First)

**Objective**: Verify compliance check executes as FIRST step after every user message.

**Why First**: FR-707 mandates that constitutional compliance check MUST be the first step after receiving any user message. This test validates the fundamental governance requirement.

**Steps**:

1. **Send any user message**:
   ```
   Create a user authentication feature
   ```

2. **Verify compliance check execution**:
   - [ ] `message-preflight` skill activated BEFORE any other processing
   - [ ] Compliance check timestamp logged to audit trail
   - [ ] 4-step pre-flight protocol completed:
     - [ ] Step 1: Constitution acknowledgment
     - [ ] Step 2: Domain analysis
     - [ ] Step 3: Delegation decision
     - [ ] Step 4: Execution authorization

3. **Verify audit log entry**:
   ```bash
   # Check audit log for compliance timestamp
   grep "compliance_check" .docs/audit/message-preflight.log | tail -1
   ```

4. **Test bypass prevention**:
   - [ ] Attempt direct skill invocation without message-preflight
   - [ ] System should block and require compliance check first
   - [ ] Error message explains FR-707 requirement

**Expected Outcome**:
```
[2026-01-13T10:00:00Z] FR-707 Compliance Check
- Message received: "Create a user authentication feature"
- Compliance check initiated: message-preflight skill
- 4-step protocol: COMPLETE
- Domain(s): multi (frontend, backend, database, security)
- Delegation: workflow-coordinator
- Proceeding with: Feature specification workflow
```

---

### Scenario 2: RL-Enhanced Skill Selection (FR-601)

**Objective**: Verify RL metrics influence skill selection when multiple skills match.

**Steps**:

1. **Set up test with multiple matching skills**:
   ```bash
   # Ensure two skills both match keyword "database"
   # Skill A: domain/database-operations (selection_weight: 0.85)
   # Skill B: sdd-workflow/sdd-planning (selection_weight: 0.65)
   ```

2. **Invoke with matching keyword**:
   ```
   Help me with database schema design
   ```

3. **Verify RL-based selection**:
   - [ ] Router Agent receives multiple skill candidates
   - [ ] RL selection algorithm (EMA) evaluates selection_weights
   - [ ] Higher-weight skill selected (database-operations: 0.85)
   - [ ] Selection logged to skill-performance.json

4. **Verify weight update after completion**:
   ```bash
   # Check skill-performance.json for weight update
   cat .docs/rl-metrics/skill-performance.json | jq '.skills["domain/database-operations"].learning_history[-1]'
   ```

5. **Expected RL update**:
   ```json
   {
     "timestamp": "2026-01-13T10:05:00Z",
     "reward": 0.88,
     "weight_before": 0.85,
     "weight_after": 0.87,
     "weight_delta": 0.02,
     "outcome": "success",
     "tokens_used": 1150
   }
   ```

**Expected Outcome**:
```
RL Skill Selection:
- Candidates: [database-operations (0.85), sdd-planning (0.65)]
- Selection algorithm: EMA
- Selected: database-operations (highest weight)
- Post-execution: Weight updated 0.85 -> 0.87 (+0.02)
```

---

### Scenario 3: Consolidated Agent Invocation (FR-610-614)

**Objective**: Verify skills invoke consolidated agents (8) instead of original agents (15).

**Steps**:

1. **Invoke skill that previously used frontend-specialist**:
   ```
   /specify Build a dashboard component
   ```

2. **Verify consolidated agent mapping**:
   - [ ] Skill references `implementation-specialist` (NOT `frontend-specialist`)
   - [ ] Agent-index.json shows consolidation mapping
   - [ ] merged-from includes `frontend-specialist`

3. **Verify skill-portfolio coverage**:
   ```bash
   # Check agent has required skills
   cat .claude/agent-index.json | jq '.domain_agents[] | select(.name == "implementation-specialist") | .skill-portfolio'
   ```
   - [ ] Portfolio includes frontend-operations
   - [ ] Portfolio includes backend-operations
   - [ ] Portfolio includes full-stack-feature

4. **Test all 8 consolidated agents**:
   | Consolidated Agent | Test Trigger | Expected Skill |
   |-------------------|--------------|----------------|
   | implementation-specialist | "build UI" | frontend-operations |
   | operations-specialist | "deploy app" | deployment |
   | specification-orchestrator | "/specify" | sdd-specification |
   | quality-specialist | "test plan" | test-strategy |
   | backend-architect | "design API" | api-design |
   | system-architect | "/create-agent" | create-agent |
   | database-specialist | "schema design" | database-operations |
   | workflow-coordinator | "orchestrate workflow" | multi-skill-workflow |

**Expected Outcome**:
```
Agent Consolidation Verification:
- Original agent count: 15
- Consolidated agent count: 8
- DS-STAR agent count: 5 (separate)
- Total agent count: 13
- Consolidation ratio: 47% reduction
- Coverage: 100% of original capabilities
```

---

### Scenario 4: DS-STAR Integration Flow (FR-701-709)

**Objective**: Verify complete DS-STAR integration with skills-first architecture.

**Flow**: User -> Compliance Check -> Router -> Skill -> Agent -> Verifier -> Finalizer

**Steps**:

1. **Initiate test workflow**:
   ```
   /specify Create a notification service
   ```

2. **Verify Router Agent (FR-701)**:
   - [ ] Router receives request after compliance check
   - [ ] Router routes to SKILL (not agent directly)
   - [ ] RL metrics inform skill selection
   - [ ] Routing decision logged

3. **Verify Skill Activation**:
   - [ ] sdd-specification skill activated
   - [ ] Progressive disclosure loads Layer 1 -> Layer 2
   - [ ] Context prepared for agent invocation

4. **Verify Context Analyzer (FR-705)**:
   - [ ] Provides codebase context to skill
   - [ ] Context retrieval <2 seconds
   - [ ] Relevant files identified

5. **Verify Domain Agent Execution**:
   - [ ] specification-orchestrator invoked
   - [ ] Minimal context passed (not full constitution)
   - [ ] Agent completes task

6. **Verify Verifier Agent (FR-702)**:
   - [ ] Binary quality decision made
   - [ ] If "insufficient" -> refinement loop
   - [ ] If "sufficient" -> proceed
   - [ ] Decision accuracy tracked (target: 95%)

7. **Verify Refinement Loop (if triggered)**:
   - [ ] Max 20 rounds respected
   - [ ] Early stop at 0.95 quality
   - [ ] Feedback accumulated

8. **Verify Auto-Debug (FR-703)** (if errors occur):
   - [ ] debug skill invokes Auto-Debug Agent
   - [ ] Agent does NOT invoke directly
   - [ ] >70% auto-fix rate target

9. **Verify Finalizer Agent (FR-704)**:
   - [ ] Skills-first pattern validated
   - [ ] Pre-commit checks passed
   - [ ] Git approval requested (not auto-committed)

10. **Verify RL Feedback Loop**:
    - [ ] Outcome recorded
    - [ ] selection_weight updated
    - [ ] skill-performance.json updated

**Expected Outcome**:
```
DS-STAR Integration Test: COMPLETE

Flow executed:
1. FR-707 Compliance Check: PASS (timestamp logged)
2. Router Agent: PASS (routed to skill, not agent)
3. Skill Activation: PASS (sdd-specification)
4. Context Analyzer: PASS (<2s retrieval)
5. Domain Agent: PASS (specification-orchestrator)
6. Verifier: PASS (sufficient)
7. Finalizer: PASS (skills-first validated)
8. RL Feedback: PASS (weight updated)

Performance:
- Task completion: SUCCESS
- Token usage: 1850 (target: <2000)
- Duration: 45s
- Verifier accuracy: 100%
```

---

### Scenario 5: Progressive Disclosure Validation

**Objective**: Verify three-layer progressive loading achieves token reduction.

**Steps**:

1. **Measure Layer 1 loading** (always loaded):
   ```bash
   # Parse only frontmatter metadata + rl_metrics
   head -30 .claude/skills/sdd-workflow/sdd-specification/SKILL.md | wc -c
   ```
   - [ ] Tokens < 150

2. **Measure Layer 2 loading** (on skill activation):
   - [ ] Instructions section loaded
   - [ ] agent-invocations loaded
   - [ ] composes loaded
   - [ ] Total Layer 1+2 < 600 tokens

3. **Verify Layer 3 is on-demand**:
   - [ ] Request skill activation
   - [ ] Verify examples.md NOT loaded initially
   - [ ] Request example -> verify then loaded
   - [ ] Layer 3 tokens variable (measured on demand)

4. **Token budget validation table**:
   | Layer | Expected | Actual | Status |
   |-------|----------|--------|--------|
   | Layer 1 (metadata + RL) | <150 | ___ | [ ] |
   | Layer 2 (instructions) | <600 | ___ | [ ] |
   | Layer 3 (on demand) | variable | ___ | [ ] |
   | Total reduction | 40-50% | ___% | [ ] |

**Expected Outcome**:
```
Progressive Disclosure Validation:
- Layer 1 (metadata + RL): 95 tokens - LOADED ALWAYS
- Layer 2 (instructions): 480 tokens - LOADED ON ACTIVATION
- Layer 3 (examples): 850 tokens - LOADED ON DEMAND
- Total if fully loaded: 1425 tokens
- Current full-context: ~5000 tokens
- Reduction achieved: 71.5% (if Layer 3 not needed)
- Target: 40-50% - EXCEEDED
```

---

### Scenario 6: RL Performance Improvement Validation (FR-604)

**Objective**: Validate +15-25% skill selection accuracy improvement over baseline.

**Methodology**: A/B test comparing RL selection vs rule-based selection.

**Steps**:

1. **Establish baseline** (rule-based selection):
   ```bash
   # Set RL algorithm to "disabled" (rule-based fallback)
   # Record 100 skill selections with outcomes
   # Calculate baseline accuracy
   ```

2. **Enable RL selection**:
   ```bash
   # Set RL algorithm to "ema"
   # Record 100 skill selections with outcomes
   # Calculate RL accuracy
   ```

3. **Compare results**:
   ```bash
   cat .docs/rl-metrics/skill-performance.json | jq '.global_metrics.improvement_over_baseline'
   ```

4. **Validate improvement**:
   - [ ] improvement_over_baseline >= 0.15 (15%)
   - [ ] improvement_over_baseline <= 0.25 (25%)
   - [ ] Statistical significance (p < 0.05)

**Expected Outcome**:
```
RL Performance Validation:

Baseline (rule-based):
- Skill selections: 100
- Correct selections: 72
- Accuracy: 72%

RL-Enhanced (EMA):
- Skill selections: 100
- Correct selections: 87
- Accuracy: 87%

Improvement: +15% (target: 15-25%)
Status: PASS
```

---

### Scenario 7: Agent Consolidation Coverage Test

**Objective**: Verify all original 15 agent capabilities are covered by 8 consolidated agents.

**Steps**:

1. **Map original capabilities**:
   ```bash
   # List all capabilities from original 15 agents
   cat .docs/archive/original-agents/*.md | grep -E "^- \*\*" | sort -u
   ```

2. **Verify coverage in consolidated agents**:
   ```bash
   # Check each consolidated agent's skill-portfolio
   cat .claude/agent-index.json | jq '.domain_agents[].skill-portfolio | flatten' | sort -u
   ```

3. **Coverage matrix**:
   | Original Capability | Consolidated Agent | Skill | Covered |
   |--------------------|-------------------|-------|---------|
   | Frontend UI building | implementation-specialist | frontend-ops | [ ] |
   | Full-stack integration | implementation-specialist | backend-ops | [ ] |
   | DevOps deployment | operations-specialist | deployment | [ ] |
   | Performance optimization | operations-specialist | performance-opt | [ ] |
   | Specification creation | specification-orchestrator | sdd-specification | [ ] |
   | Planning | specification-orchestrator | sdd-planning | [ ] |
   | Task generation | specification-orchestrator | sdd-tasks | [ ] |
   | PRD creation | specification-orchestrator | prd-creation | [ ] |
   | Testing strategy | quality-specialist | test-strategy | [ ] |
   | Security review | quality-specialist | security-review | [ ] |
   | API design | backend-architect | api-design | [ ] |
   | Service architecture | backend-architect | service-architecture | [ ] |
   | Agent creation | system-architect | create-agent | [ ] |
   | Database operations | database-specialist | database-ops | [ ] |
   | Workflow orchestration | workflow-coordinator | multi-skill-workflow | [ ] |

4. **Verify 100% coverage**:
   - [ ] All 15 original capabilities mapped
   - [ ] No gaps in consolidated agent portfolios
   - [ ] Rollback available (original agents archived)

**Expected Outcome**:
```
Agent Consolidation Coverage:
- Original capabilities: 15
- Capabilities covered: 15
- Coverage: 100%
- Gaps: 0
- Status: PASS
```

---

### Scenario 8: Backward Compatibility During Migration

**Objective**: Verify both patterns work in hybrid mode.

**Steps**:

1. **Verify hybrid mode enabled**:
   ```bash
   cat .specify/config/architecture.conf
   # Expected: ARCHITECTURE_MODE=hybrid
   ```

2. **Test legacy agent invocation** (deprecated but functional):
   ```
   Use database-specialist to design schema for User entity
   ```
   - [ ] Agent invoked directly (legacy pattern)
   - [ ] Deprecation WARNING emitted (not error)
   - [ ] Agent completes successfully
   - [ ] Warning logged with migration guidance

3. **Test skills-first invocation** (preferred):
   ```
   /plan Create implementation plan for User entity
   ```
   - [ ] Skill activated (sdd-planning)
   - [ ] Skill invokes database-specialist with minimal context
   - [ ] No deprecation warning
   - [ ] RL metrics updated

4. **Verify migration tracking**:
   ```bash
   # Run legacy pattern report
   ./.specify/scripts/bash/legacy-pattern-report.sh
   ```
   - [ ] Legacy invocation counted
   - [ ] Skills-first invocation counted
   - [ ] Migration progress reported

**Expected Outcome**:
```
Architecture Mode: hybrid
Legacy invocations: 1 (WARNING emitted)
Skills-first invocations: 1 (clean)
Migration progress: 50% skills-first adoption
Recommendation: Convert legacy patterns to skills-first
```

---

## Integration Test: Full Workflow with RL and DS-STAR

**Objective**: Verify complete end-to-end workflow from specification to tasks.

**Steps**:

1. **FR-707: Compliance Check**:
   ```
   /specify Build user notification system
   ```
   - [ ] message-preflight executes FIRST
   - [ ] 4-step protocol logged

2. **Router Agent Routes to Skill**:
   - [ ] Router identifies: multi-domain (backend, database, frontend)
   - [ ] RL selection: sdd-specification (weight: 0.85)
   - [ ] Route to skill (NOT agent)

3. **Specification Skill with RL Tracking**:
   - [ ] sdd-specification skill activates
   - [ ] Context Analyzer provides codebase context
   - [ ] specification-orchestrator invoked with minimal context
   - [ ] Verifier validates output
   - [ ] spec.md created
   - [ ] RL weight updated

4. **Planning Skill**:
   ```
   /plan
   ```
   - [ ] sdd-planning skill activates
   - [ ] Database work -> database-specialist (consolidated)
   - [ ] API work -> backend-architect (unchanged)
   - [ ] Verifier validates plan quality
   - [ ] plan.md, research.md, data-model.md, contracts/ created

5. **Tasks Skill**:
   ```
   /tasks
   ```
   - [ ] sdd-tasks skill activates
   - [ ] specification-orchestrator handles task generation
   - [ ] Verifier validates task list
   - [ ] tasks.md created

6. **Finalizer Validation**:
   - [ ] Skills-first pattern validated
   - [ ] No legacy agent-first patterns
   - [ ] Git approval requested

7. **RL Summary**:
   ```bash
   cat .docs/rl-metrics/skill-performance.json | jq '.global_metrics'
   ```

**Token Usage Summary**:
| Phase | Current Tokens | Skills-First Tokens | RL Optimized | Reduction |
|-------|----------------|---------------------|--------------|-----------|
| Specify | ~8000 | ~3200 | ~2800 | 65% |
| Plan | ~15000 | ~6500 | ~5800 | 61% |
| Tasks | ~6000 | ~2800 | ~2500 | 58% |
| **Total** | **~29000** | **~12500** | **~11100** | **62%** |

**Expected Outcome**:
```
Full Workflow Test: COMPLETE

Workflow executed: /specify -> /plan -> /tasks
Total token usage: ~11,100 tokens (RL optimized)
Token reduction: 62% vs current patterns
RL improvement: +18% selection accuracy

All DS-STAR components validated:
- FR-707 Compliance Check: PASS
- Router Agent: PASS (routed to skills)
- Verifier Agent: PASS (3 quality gates)
- Context Analyzer: PASS (<2s retrieval)
- Finalizer Agent: PASS (skills-first validated)

Agent Consolidation:
- Domain agents used: 3 of 8 (specification-orchestrator, database-specialist, backend-architect)
- DS-STAR agents used: 4 of 5 (router, verifier, context, finalizer)

All artifacts created successfully.
```

---

## Validation Checklist

### Schema Validation

- [ ] `skill-definition.yaml` v3 validates all SKILL.md files (includes rl_metrics)
- [ ] `agent-definition.yaml` v2 validates consolidated agent files (includes skill-portfolio)
- [ ] `skill-invocation.yaml` v2 validates invocation contracts (includes rl_performance)
- [ ] `skill-index-v3.yaml` validates skill-index.json (includes rl_config)
- [ ] `agent-index.yaml` validates agent-index.json (8 domain + 5 DS-STAR)
- [ ] `rl-metrics.yaml` validates skill-performance.json

### RL Metrics Validation

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| selection_weight bounds | [0.1, 1.0] | ___ | [ ] |
| success_rate bounds | [0.0, 1.0] | ___ | [ ] |
| improvement_over_baseline | +15-25% | ___% | [ ] |
| learning_history limit | <=100 | ___ | [ ] |

### Agent Consolidation Validation

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Domain agents | 8 | ___ | [ ] |
| DS-STAR agents | 5 | ___ | [ ] |
| Total agents | 13 | ___ | [ ] |
| Consolidation ratio | 47% | ___% | [ ] |
| Capability coverage | 100% | ___% | [ ] |

### DS-STAR Integration Validation

| Component | Target | Actual | Status |
|-----------|--------|--------|--------|
| FR-707 compliance | First step | ___ | [ ] |
| Router -> Skills | Always | ___ | [ ] |
| Verifier accuracy | 95% | ___% | [ ] |
| Auto-debug rate | >70% | ___% | [ ] |
| Context retrieval | <2s | ___s | [ ] |
| Refinement max rounds | 20 | ___ | [ ] |

### Token Budget Validation

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Layer 1 average | <150 tokens | ___ | [ ] |
| Layer 2 average | <600 tokens | ___ | [ ] |
| Agent context | <500 tokens | ___ | [ ] |
| Total reduction | 40-50% | ___% | [ ] |

---

## Troubleshooting

### Issue: FR-707 compliance check bypassed

**Symptoms**: Skills activate without compliance check first

**Resolution**:
1. Verify message-preflight skill exists in validation category
2. Check skill composes includes message-preflight at pre-execution phase
3. Verify Router Agent calls compliance check before routing
4. Check audit log for missing timestamps

### Issue: RL selection weight not updating

**Symptoms**: selection_weight stays at 0.5 despite invocations

**Resolution**:
1. Verify rl_config.algorithm = "ema" (not "disabled")
2. Check learning_rate is > 0 (default: 0.1)
3. Verify outcome is being recorded (success/failure/partial)
4. Check skill-performance.json write permissions

### Issue: Agent consolidation mapping incorrect

**Symptoms**: Skill invokes old agent name, gets error

**Resolution**:
1. Check agent-invocations uses consolidated agent name
2. Verify agent-index.json has correct consolidation_map
3. Run migration script: `./consolidate-agents.sh --verify`
4. Update skill definition with correct agent reference

### Issue: DS-STAR Verifier rejects valid output

**Symptoms**: Quality gate blocks progression despite good output

**Resolution**:
1. Check verifier_decision in refinement state
2. Review feedback_text for specific issues
3. Adjust quality_threshold in refinement config
4. Check for false positive in verifier training data

### Issue: Context retrieval exceeds 2 seconds

**Symptoms**: Context Analyzer slow, workflow delays

**Resolution**:
1. Check context index freshness
2. Reduce scope of codebase scan
3. Enable context caching
4. Fall back to keyword-based retrieval (graceful degradation)

---

## Success Criteria

This feature is successfully implemented when:

1. **FR-707 Compliance**: Compliance check executes FIRST on every message
2. **RL Enhancement**: +15-25% skill selection accuracy improvement
3. **Agent Consolidation**: 8 domain agents cover all 15 original capabilities
4. **DS-STAR Integration**: All 5 agents work WITH skills, not replaced BY skills
5. **Token Efficiency**: 40-50% reduction in average tokens per operation
6. **Skill Activation**: Skills are primary orchestration layer
7. **Minimal Context**: Agents receive only task-relevant context (<500 tokens)
8. **Backward Compatibility**: 100% of existing workflows work in hybrid mode
9. **Schema Compliance**: All definitions validate against v3 contracts
10. **Constitutional Process**: Amendment process followed for Principle X

---

*Quickstart guide prepared by planning-agent*
*Constitutional Compliance: Principle II (Test-First Development)*
*Version: 2.0.0 - Updated for FR-600, FR-610, FR-700 series requirements*
