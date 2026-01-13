# Data Model: Skills-First Architecture with RL and DS-STAR Integration

**Feature**: 002-skills-first-architecture
**Date**: 2026-01-13
**Status**: Complete
**Version**: 2.0.0 (updated for FR-600, FR-610, FR-700 series)
**Purpose**: Define entities, relationships, and validation rules for skills-first architecture with RL enhancement, agent consolidation, and DS-STAR integration

---

## Entity Overview

```
+-------------------------------------------------------------------------+
|                SKILLS-FIRST ARCHITECTURE v2.0 (RL + DS-STAR)             |
+-------------------------------------------------------------------------+
|                                                                          |
|  +----------------+     composes      +------------------+               |
|  | SkillCategory  |<------------------|      Skill       |               |
|  | (8 types)      |                   | (35+ skills)     |               |
|  +----------------+                   | + RL Metrics     |               |
|                                       +--------+---------+               |
|                                                |                         |
|                                       invokes  |  through                |
|                                                v                         |
|                              +---------------------------+               |
|                              | SkillInvocationContract   |               |
|                              | + rl_performance          |               |
|                              +-----------+---------------+               |
|                                          |                               |
|                                 defines  |  context for                  |
|                                          v                               |
|  +----------------+           +--------------------+                     |
|  | DS-STAR Agents |           | Consolidated Agent |                     |
|  | (5 separate)   |           | (8 domain agents)  |                     |
|  | - Router       |---------->| + skill-portfolio  |                     |
|  | - Verifier     | routes to +--------------------+                     |
|  | - Auto-Debug   |                                                      |
|  | - Finalizer    |                                                      |
|  | - Context      |                                                      |
|  +----------------+                                                      |
|                                                                          |
|  +----------------+     routes      +------------------+                 |
|  | SkillIndex v3  |<--------------->|   AgentIndex     |                 |
|  | + RL metrics   |                 | (8 domain + 5    |                 |
|  +----------------+                 |  DS-STAR)        |                 |
|                                     +------------------+                 |
|                                                                          |
|  +--------------------+          +--------------------+                  |
|  | RLPerformanceTracker|          |  RefinementState   |                  |
|  | skill-performance   |          |  (DS-STAR)         |                  |
|  +--------------------+          +--------------------+                  |
|                                                                          |
+-------------------------------------------------------------------------+
```

---

## Entity: Skill (Enhanced with RL)

**Purpose**: Primary orchestration unit in skills-first architecture with reinforcement learning metrics for continuous improvement.

### Fields

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `name` | String | Required, unique, kebab-case | Skill identifier (e.g., `sdd-specification`) |
| `version` | SemVer | Required, format: X.Y.Z | Skill version for compatibility |
| `description` | String | Required, max 1024 chars | What the skill does and when to use it |
| `category` | SkillCategory | Required, valid category | Organizational grouping |
| `triggers` | String[] | Required, 1-10 items | Keywords/commands that activate skill |
| `allowed-tools` | String[] | Optional, valid tool names | Tool restrictions (default: all) |
| `agent-invocations` | AgentInvocation[] | Optional | Agents this skill may invoke |
| `composes` | SkillComposition[] | Optional | Other skills this skill uses |
| `progressive-disclosure` | ProgressiveDisclosure | Required | Layer definitions |
| `instructions` | Markdown | Required | Procedural steps |
| `examples` | FilePath | Optional | Path to examples file |
| `references` | FilePath | Optional | Path to reference file |
| `scripts` | DirPath | Optional | Path to utility scripts |
| **`rl_metrics`** | RLMetrics | Required (v3) | RL performance metrics |
| **`learning_history`** | LearningEntry[] | Auto-managed | Historical performance data |

### RLMetrics Fields (NEW - FR-601)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `success_rate` | Float | 0.0-1.0, default: 0.5 | Task completion rate without errors |
| `avg_tokens` | Integer | >= 0 | Average tokens used per invocation |
| `avg_duration_ms` | Integer | >= 0 | Average execution time in milliseconds |
| `user_satisfaction` | Float | 0.0-1.0, optional | Explicit user feedback score |
| `selection_weight` | Float | 0.1-1.0, default: 0.5 | RL-computed selection probability |
| `invocation_count` | Integer | >= 0 | Total number of invocations |

### LearningEntry Fields (NEW - FR-601)

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | ISO8601 | When the update occurred |
| `reward` | Float | Computed reward for this invocation |
| `weight_delta` | Float | Change to selection_weight |
| `outcome` | String | success / failure / partial |
| `tokens_used` | Integer | Tokens used in this invocation |

### Relationships

| Relationship | Type | Target | Description |
|--------------|------|--------|-------------|
| `belongs-to` | Many-to-One | SkillCategory | Skill belongs to one category |
| `invokes` | One-to-Many | Agent (Consolidated) | Skill may invoke multiple agents |
| `composes` | Many-to-Many | Skill | Skills can compose other skills |
| `indexed-in` | One-to-One | SkillIndex v3 | Skill registered in RL-enhanced index |
| `tracked-by` | One-to-One | RLPerformanceTracker | Performance logged |

### Validation Rules

1. **Name uniqueness**: No two skills may have the same name
2. **Category validity**: Category must exist in SkillCategory enum
3. **Trigger uniqueness**: Triggers should not conflict with other skills in same category
4. **Tool restriction**: `allowed-tools` must be subset of valid Claude Code tools
5. **Agent reference**: All agents in `agent-invocations` must exist in AgentIndex
6. **Skill reference**: All skills in `composes` must exist (no circular dependencies)
7. **Progressive disclosure**: All three layers must be defined
8. **RL metrics bounds**: success_rate, user_satisfaction in [0,1], selection_weight in [0.1,1.0]

### State Transitions

```
DRAFT -> PUBLISHED -> DEPRECATED -> ARCHIVED
  |         |           |
  +---------+-----------+-------- DELETED (with migration)
```

---

## Entity: Agent (Consolidated with Skill Portfolio)

**Purpose**: Lightweight executor with minimal context. 8 consolidated domain agents, each with a skill portfolio mapping their capabilities.

### Fields

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `name` | String | Required, unique, kebab-case | Agent identifier |
| `purpose` | String | Required, max 256 chars | Single sentence describing execution role |
| `required-context` | String[] | Required, 1-10 items | Context fields agent needs from skill |
| `output-format` | OutputFormat | Required | Result format (markdown, json, sql, etc.) |
| `tools` | String[] | Required, valid tool names | Tools agent may use |
| `model` | ModelId | Optional, default: opus | AI model for execution |
| `department` | Department | Required | Organizational department |
| **`skill-portfolio`** | SkillPath[] | Required (v2) | Skills this agent can execute |
| **`merged-from`** | String[] | Optional | Original agents merged into this |
| **`rl_performance`** | AgentRLMetrics | Auto-managed | Per-agent RL metrics |

### AgentRLMetrics Fields (NEW)

| Field | Type | Description |
|-------|------|-------------|
| `invocation_count` | Integer | Total invocations across all skills |
| `success_rate` | Float | Overall success rate |
| `avg_tokens` | Integer | Average tokens per invocation |
| `skill_success_rates` | Map<SkillPath, Float> | Success rate per invoking skill |

### Consolidated Agents Registry (FR-610-614)

| Agent | Purpose | Department | Merged From | Skill Portfolio |
|-------|---------|------------|-------------|-----------------|
| `implementation-specialist` | Build UI and integrations | engineering | frontend-specialist, full-stack-developer | frontend-ops, backend-ops, full-stack-feature |
| `operations-specialist` | Manage runtime/infra | operations | devops-engineer, performance-engineer | deployment, ci-cd, monitoring, performance-opt |
| `specification-orchestrator` | Orchestrate product workflow | product | specification-agent, planning-agent, tasks-agent, prd-specialist | sdd-specification, sdd-planning, sdd-tasks, prd-creation |
| `quality-specialist` | Ensure quality and security | quality | testing-specialist, security-specialist | test-strategy, security-review, qa-validation |
| `backend-architect` | Design APIs and services | architecture | (unchanged) | api-design, service-architecture |
| `system-architect` | Design system and agents | architecture | subagent-architect (renamed) | agent-creation, system-design |
| `database-specialist` | Manage data layer | data | (unchanged) | database-operations, schema-design |
| `workflow-coordinator` | Coordinate multi-skill work | product | task-orchestrator (renamed) | multi-skill-workflow, migration-workflow |

### Validation Rules

1. **Name uniqueness**: No two agents may have the same name
2. **Purpose brevity**: Purpose must be single, focused sentence
3. **Context minimality**: `required-context` should be minimal set needed
4. **Tool validity**: All tools must be valid Claude Code tools
5. **Skill portfolio coverage**: Each skill in portfolio must exist in SkillIndex
6. **Merged-from tracking**: Must list all original agents if consolidation

---

## Entity: DS-STAR Agent (Separate Orchestration Layer)

**Purpose**: 5 specialized DS-STAR agents that provide orchestration functions. NOT consolidated with domain agents. Work WITH skills.

### DS-STAR Agents (FR-709)

| Agent | Department | Purpose | Integration Point |
|-------|------------|---------|-------------------|
| `router-agent` | architecture | Domain analysis, RL-enhanced skill routing | After compliance check, routes to skills |
| `verifier-agent` | quality | Binary quality gates, skill/agent output validation | After agent execution, validates output |
| `auto-debug-agent` | engineering | Self-healing error resolution | Invoked BY debug skill, not directly |
| `finalizer-agent` | quality | Pre-commit compliance, skills-first validation | Before any git operations |
| `context-analyzer` | architecture | Codebase context provider | Provides context TO skills |

### DS-STAR Agent Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Agent identifier |
| `department` | Department | Organizational placement |
| `purpose` | String | Orchestration function description |
| `invoked-by` | String | "skill" or "system" - how it's triggered |
| `invokes` | String | "skills" or "agents" - what it calls |
| `ds-star-role` | DSStarRole | router / verifier / debug / finalizer / context |
| `performance-targets` | Map<String, Float> | DS-STAR performance requirements |

### DS-STAR Performance Targets (FR-708)

| Agent | Target | Measurement |
|-------|--------|-------------|
| router-agent | 3.5x task completion accuracy | Pre/post baseline |
| verifier-agent | 95% binary decision accuracy | Decision audit |
| auto-debug-agent | >70% auto-fix rate | Error resolution tracking |
| finalizer-agent | 0 false passes | Quality gate logs |
| context-analyzer | <2s retrieval | Latency monitoring |

---

## Entity: SkillCategory

**Purpose**: Organizational grouping for skills with governance metadata.

### Enum Values (8 Categories)

```yaml
categories:
  - name: sdd-workflow
    description: Core SDD methodology skills
    governance-level: high

  - name: validation
    description: Quality gates and compliance skills
    governance-level: high

  - name: governance
    description: Constitutional enforcement skills
    governance-level: critical

  - name: orchestration
    description: Multi-skill coordination skills
    governance-level: high

  - name: domain
    description: Domain-specific procedural knowledge
    governance-level: medium

  - name: creation
    description: Entity creation skills
    governance-level: medium

  - name: project-initialization
    description: Project setup skills
    governance-level: medium

  - name: integration
    description: External system integrations
    governance-level: medium
```

---

## Entity: SkillInvocationContract (Enhanced with RL)

**Purpose**: Defines how a skill invokes an agent with minimal context and RL performance tracking.

### Fields

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `skill-id` | SkillPath | Required, valid skill | Invoking skill |
| `agent-id` | AgentPath | Required, valid agent | Invoked agent (consolidated) |
| `context-subset` | String[] | Required | Specific context fields passed |
| `when` | String | Required | Condition for invocation |
| `expected-output` | OutputSchema | Required | Expected result format |
| `timeout` | Duration | Optional, default: 5m | Maximum execution time |
| `retry` | RetryPolicy | Optional | Retry behavior on failure |
| **`rl_performance`** | InvocationRLMetrics | Auto-managed | Per-contract RL metrics |

### InvocationRLMetrics Fields (NEW)

| Field | Type | Description |
|-------|------|-------------|
| `invocation_count` | Integer | Times this specific contract executed |
| `success_rate` | Float | Success rate for this skill-agent pair |
| `avg_tokens` | Integer | Average tokens for this contract |
| `last_invocation` | ISO8601 | When last executed |

---

## Entity: SkillIndex v3 (RL-Enhanced)

**Purpose**: Primary routing mechanism with RL metrics for skill selection optimization.

### Fields

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `version` | String | Required, "3.0.0" | Index schema version |
| `generated` | ISO8601 | Required | Generation timestamp |
| `architecture-mode` | ArchitectureMode | Required | Current mode (hybrid/skills-first) |
| `categories` | CategoryEntry[] | Required | Category metadata |
| `skills` | SkillEntry[] | Required | All registered skills |
| `routing` | RoutingTable | Required | Trigger-to-skill mapping |
| **`rl_config`** | RLConfig | Required (v3) | RL algorithm parameters |
| **`statistics`** | IndexStatistics | Required | Index and RL statistics |

### SkillEntry Fields (v3 with RL)

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Skill name |
| `path` | FilePath | Path to SKILL.md |
| `category` | String | Category name |
| `triggers` | String[] | Trigger keywords |
| `token-budget` | TokenBudget | Layer token counts |
| `agents` | String[] | Consolidated agents this skill invokes |
| `status` | String | active / deprecated / draft |
| **`rl_metrics`** | RLMetrics | Current RL performance metrics |

### RLConfig Fields (NEW)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `algorithm` | String | "ema" | ema (Phase 1-2), grpo (Phase 3-4) |
| `learning_rate` | Float | 0.1 | Alpha for weight updates |
| `reward_weights` | RewardWeights | See below | Weights for reward calculation |
| `selection_temperature` | Float | 1.0 | Softmax temperature for selection |
| `min_weight` | Float | 0.1 | Minimum selection weight |
| `max_weight` | Float | 1.0 | Maximum selection weight |

### RewardWeights Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `success_rate` | Float | 0.5 | Weight for task success |
| `token_efficiency` | Float | 0.3 | Weight for token efficiency |
| `user_satisfaction` | Float | 0.2 | Weight for user feedback |

---

## Entity: AgentIndex (NEW)

**Purpose**: Agent capability registry for consolidated 8 domain agents + 5 DS-STAR agents.

### Fields

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `version` | String | Required, "1.0.0" | Index schema version |
| `generated` | ISO8601 | Required | Generation timestamp |
| `domain_agents` | AgentEntry[] | Required | 8 consolidated domain agents |
| `ds_star_agents` | DSStarEntry[] | Required | 5 DS-STAR agents |
| `consolidation_map` | Map<String, String[]> | Required | New agent -> original agents |
| **`statistics`** | AgentStatistics | Required | Agent registry stats |

### AgentEntry Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Agent name |
| `path` | FilePath | Path to agent.md |
| `department` | String | Department name |
| `purpose` | String | Agent purpose (brief) |
| `skill-portfolio` | String[] | Skills this agent can execute |
| `merged-from` | String[] | Original agents (if consolidated) |
| `rl_performance` | AgentRLMetrics | Performance metrics |

### DSStarEntry Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | DS-STAR agent name |
| `path` | FilePath | Path to agent.md |
| `department` | String | Department name |
| `ds-star-role` | String | router / verifier / debug / finalizer / context |
| `performance-targets` | Map<String, Float> | FR-708 targets |

### AgentStatistics Fields

| Field | Type | Description |
|-------|------|-------------|
| `total_domain_agents` | Integer | Should be 8 |
| `total_ds_star_agents` | Integer | Should be 5 |
| `total_agents` | Integer | Should be 13 |
| `consolidation_ratio` | Float | 8/15 = 0.53 (47% reduction) |

---

## Entity: RLPerformanceTracker (NEW)

**Purpose**: Persistent storage for RL execution history and weight updates. Stored at `.docs/rl-metrics/skill-performance.json`.

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `version` | String | Schema version |
| `last_updated` | ISO8601 | Last update timestamp |
| `total_invocations` | Integer | Total skill invocations tracked |
| `skills` | Map<SkillPath, SkillPerformance> | Per-skill performance data |
| `global_metrics` | GlobalRLMetrics | Framework-wide RL metrics |

### SkillPerformance Fields

| Field | Type | Description |
|-------|------|-------------|
| `skill_name` | String | Skill identifier |
| `current_weight` | Float | Current selection weight |
| `invocation_count` | Integer | Total invocations |
| `success_count` | Integer | Successful invocations |
| `total_tokens` | Integer | Cumulative tokens used |
| `total_duration_ms` | Integer | Cumulative execution time |
| `learning_history` | LearningEntry[] | Last N weight updates |

### GlobalRLMetrics Fields

| Field | Type | Description |
|-------|------|-------------|
| `avg_selection_accuracy` | Float | Average correct skill selection |
| `improvement_over_baseline` | Float | +X% vs rule-based (target: 15-25%) |
| `total_reward` | Float | Cumulative reward across all skills |
| `evaluation_window_days` | Integer | 30-day rolling window |

---

## Entity: RefinementState (DS-STAR Integration)

**Purpose**: Tracks iterative refinement progress for DS-STAR quality loops.

### Fields

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `task_id` | String | Required | Task being refined |
| `phase` | String | Required | specification / planning / implementation |
| `current_round` | Integer | 1-20 | Current refinement iteration |
| `max_rounds` | Integer | Default: 20 | Maximum allowed iterations |
| `quality_score` | Float | 0.0-1.0 | Current quality assessment |
| `early_stop_threshold` | Float | Default: 0.95 | Quality threshold for early stopping |
| `early_stop_triggered` | Boolean | Default: false | Whether early stop activated |
| `feedback_log` | FeedbackEntry[] | Required | Accumulated feedback |
| `skill_invocations` | SkillInvocation[] | Required | Skills invoked in refinement |

### FeedbackEntry Fields

| Field | Type | Description |
|-------|------|-------------|
| `round` | Integer | Refinement round number |
| `timestamp` | ISO8601 | When feedback received |
| `verifier_decision` | String | sufficient / insufficient |
| `feedback_text` | String | Detailed improvement guidance |
| `quality_delta` | Float | Change in quality score |

---

## Entity Relationships Diagram (v2.0)

```
+----------------+         +------------------+
| SkillCategory  |<--------|      Skill       |
|                | 1     * | + rl_metrics     |
+----------------+         | + learning_hist  |
                           +--------+---------+
                                    |
                           composes | *
                                    v *
                           +----------------+
                           |     Skill      |
                           +----------------+
                                    |
                            invokes | *
                                    v *
                    +---------------------------+
                    | SkillInvocationContract   |
                    | + rl_performance          |
                    +-----------+---------------+
                                |
                       defines  | *
                                v 1
+----------------+      +-------------------+      +----------------+
| DS-STAR Agents |      | Consolidated      |      | AgentIndex     |
| (5 separate)   |----->| Agent (8)         |----->| (8 domain +    |
| - Router       |routes| + skill-portfolio |      |  5 DS-STAR)    |
| - Verifier     | to   | + merged-from     |      +----------------+
| - Auto-Debug   |      +-------------------+
| - Finalizer    |              |
| - Context      |     belongs  | *
+----------------+              v 1
                        +---------------+
                        |  Department   |
                        +---------------+

+--------------------+      +--------------------+
| RLPerformanceTracker|      |  RefinementState   |
| (skill-performance)|      |  (DS-STAR)         |
+--------------------+      +--------------------+
```

---

## Supporting Types

### Department Enum

```yaml
departments:
  - architecture
  - data
  - engineering
  - operations
  - product
  - quality
```

### DSStarRole Enum

```yaml
ds-star-roles:
  - router      # Routes to skills based on RL
  - verifier    # Binary quality decisions
  - debug       # Auto-fix errors
  - finalizer   # Pre-commit validation
  - context     # Codebase context provider
```

### ArchitectureMode Enum

```yaml
architecture-modes:
  - hybrid        # Both patterns work (Phase 1-2)
  - skills-first  # Skills-first default (Phase 3-4)
  - legacy-agents # Legacy only (pre-migration)
```

### OutputFormat Enum

```yaml
output-formats:
  - markdown
  - json
  - yaml
  - sql
  - typescript
  - python
  - bash
  - text
```

### GovernanceLevel Enum

```yaml
governance-levels:
  - critical    # Constitutional review required
  - high        # Technical review required
  - medium      # Self-review with checklist
  - low         # Automated validation only
```

### ModelId Enum

```yaml
model-ids:
  - claude-opus-4-5-20251101      # Default (Opus)
  - claude-sonnet-4-5-20250929    # Fallback (Sonnet)
  - claude-haiku                   # Quick tasks
```

---

## Data Integrity Constraints

1. **Referential Integrity**: All skill/agent references must be valid
2. **No Circular Composition**: Skill composition graph must be acyclic
3. **Index Synchronization**: Indexes must reflect current file system state
4. **Version Compatibility**: Skill versions must follow semver
5. **Token Budgets**: Layer token counts must not exceed limits
6. **RL Bounds**: All RL metrics within defined bounds (0.1-1.0 for weights)
7. **Agent Consolidation Coverage**: All original 15 capabilities mapped to 8 agents
8. **DS-STAR Separation**: 5 DS-STAR agents never consolidated with domain agents
9. **FR-707 Compliance**: Every message must have compliance check timestamp

---

## Migration Entities

### ConsolidationMap

**Purpose**: Tracks which original agents map to consolidated agents.

```yaml
consolidation-map:
  implementation-specialist:
    - frontend-specialist
    - full-stack-developer
  operations-specialist:
    - devops-engineer
    - performance-engineer
  specification-orchestrator:
    - specification-agent
    - planning-agent
    - tasks-agent
    - prd-specialist
  quality-specialist:
    - testing-specialist
    - security-specialist
  backend-architect:
    - backend-architect  # unchanged
  system-architect:
    - subagent-architect  # renamed
  database-specialist:
    - database-specialist  # unchanged
  workflow-coordinator:
    - task-orchestrator  # renamed
```

---

*Data model designed by planning-agent*
*Constitutional Compliance: Principle III (Contract-First Design)*
*Version: 2.0.0 - Updated for FR-600, FR-610, FR-700 series requirements*
