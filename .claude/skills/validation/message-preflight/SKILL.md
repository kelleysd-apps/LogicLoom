---
name: message-preflight
version: 3.0.0
description: |
  CRITICAL FR-707 Compliance Skill: Executes the MANDATORY 4-step pre-flight compliance check
  on EVERY user message. This skill MUST be activated as the FIRST step after receiving any
  user message. It validates constitutional compliance, analyzes task domain, determines
  delegation requirements, and authorizes execution. Cannot be bypassed by other skills.
  Implements Constitutional Principle X Work Session Initiation Protocol with skills-first routing.
category: validation
triggers:
  - "__system_preflight__"
  - "compliance check"
  - "constitutional compliance"
  - "preflight"
allowed-tools:
  - Read
  - Grep
  - Glob
agent-invocations: []
composes: []
progressive-disclosure:
  layer1:
    - name
    - description
    - triggers
    - category
    - version
    - rl_metrics
  layer2:
    - instructions
    - agent-invocations
    - composes
    - allowed-tools
  layer3:
    - examples
    - references
rl_metrics:
  success_rate: 0.99
  avg_tokens: 150
  avg_duration_ms: 500
  user_satisfaction: 0.95
  selection_weight: 1.0
  invocation_count: 0
---

# Message Pre-Flight Compliance Check (FR-707)

## MANDATORY EXECUTION - FR-707 CRITICAL

**This skill MUST execute at the START of every user message. No exceptions.**

**Why This Exists**: FR-707 mandates that constitutional compliance check is the FIRST step after receiving ANY user message. This skill enforces that requirement proactively before the Router Agent or any other processing.

**What It Prevents**:
- Executing specialized work without skill-first routing
- Skipping constitution acknowledgment
- Forgetting to analyze task domains
- Autonomous git operations (Principle VI)
- Bypassing quality gates

## The 4-Step Protocol

### Step 1: Constitution Acknowledgment

**Action**: Confirm awareness of the 15 constitutional principles (v1.6.0).

**Key Principles to Remember**:
- **Principle II (Test-First)**: TDD is mandatory, >80% coverage
- **Principle VI (Git Approval)**: NO autonomous git operations - CRITICAL
- **Principle X (Agent Delegation)**: Now routes to SKILLS which invoke agents
- **Principle XV (File Organization)**: Verify before creating files/folders

**Mental Checklist**:
```
[ ] I am aware of the 15 constitutional principles
[ ] I know Principles I-III are IMMUTABLE
[ ] I know Principle VI prohibits autonomous git operations
[ ] I know Principle X requires skill-first routing (skills -> agents)
[ ] I know Principle XV requires verification before file creation
```

### Step 2: Domain Analysis

**Action**: Scan the user message for domain trigger keywords.

**Skills-First Domain Mapping (v3)**:

| Domain | Trigger Keywords | Route To Skill | Skill Invokes |
|--------|------------------|----------------|---------------|
| Frontend | UI, component, React, CSS, form | domain/frontend-operations | implementation-specialist |
| Backend | API, endpoint, server, auth, service | domain/backend-operations | backend-architect |
| Database | schema, migration, query, RLS, SQL | domain/database-operations | database-specialist |
| Testing | test, TDD, E2E, coverage, QA | domain/testing-operations | quality-specialist |
| Security | auth, encryption, XSS, secrets | domain/security-operations | quality-specialist |
| Performance | optimize, cache, benchmark | domain/performance-operations | operations-specialist |
| DevOps | deploy, CI/CD, Docker, pipeline | domain/devops-operations | operations-specialist |
| Specification | /specify, requirements, spec | sdd-workflow/sdd-specification | specification-orchestrator |
| Planning | /plan, research, contract | sdd-workflow/sdd-planning | specification-orchestrator |
| Tasks | /tasks, task list, dependencies | sdd-workflow/sdd-tasks | specification-orchestrator |
| Multi-Domain | 2+ domains detected | orchestration/multi-skill-workflow | workflow-coordinator |

**Scan Process**:
1. Read the user message
2. Identify any domain keywords present
3. Count how many domains are involved
4. Note which skills would be activated

### Step 3: Delegation Decision

**Action**: Make an explicit decision based on domain analysis.

**Skills-First Decision Logic (v3)**:
```
IF 0 domains detected:
  -> May execute directly (simple/informational task)

IF 1 domain detected:
  -> MUST activate the appropriate domain skill
  -> Skill will invoke consolidated agent as needed

IF 2+ domains detected:
  -> MUST activate orchestration/multi-skill-workflow
  -> Orchestration skill coordinates multiple domain skills
```

**Critical Rule**: Route to SKILLS, not agents directly. Skills determine agent invocation.

### Step 4: Execution Authorization

**Action**: Confirm all steps complete before proceeding.

**Authorization Checklist**:
```
[ ] Step 1: Constitution acknowledged
[ ] Step 2: Domains analyzed
[ ] Step 3: Skill routing decision made
[ ] Step 4: Ready to execute (directly or via skill activation)
```

**Log to Audit Trail**:
- Timestamp (ISO8601)
- Message hash (first 8 chars)
- Domains detected
- Skill routing target
- Git operations planned (boolean)

## Output Format

After completing the 4-step protocol, output a brief compliance summary:

```
Constitutional Compliance Check:
- Timestamp: [ISO8601]
- Domain(s): [none | single: <domain> | multi: <domains>]
- Delegation: [direct execution | <skill-name>]
- Git operations: [none planned | will request approval]
- Proceeding with: [action description]
```

**Examples**:

```
Constitutional Compliance Check:
- Timestamp: 2026-01-13T10:00:00Z
- Domain(s): none
- Delegation: direct execution
- Git operations: none planned
- Proceeding with: answering question about file structure
```

```
Constitutional Compliance Check:
- Timestamp: 2026-01-13T10:05:00Z
- Domain(s): single: database
- Delegation: domain/database-operations
- Git operations: none planned
- Proceeding with: activating database skill for schema design
```

```
Constitutional Compliance Check:
- Timestamp: 2026-01-13T10:10:00Z
- Domain(s): multi: frontend, backend, database
- Delegation: orchestration/multi-skill-workflow
- Git operations: will request approval
- Proceeding with: coordinating full-stack feature via orchestration skill
```

## Audit Trail (FR-707 Requirement)

Every compliance check MUST log to `.docs/audit/message-preflight.log`:

```json
{
  "timestamp": "2026-01-13T10:00:00Z",
  "message_hash": "abc12345",
  "domains_detected": ["backend", "database"],
  "delegation_target": "orchestration/multi-skill-workflow",
  "git_operations_planned": false,
  "compliance_status": "PASS",
  "duration_ms": 125
}
```

## Integration with DS-STAR

This skill integrates with DS-STAR Router Agent (FR-701):

```
User Message
    |
    v
[FR-707] message-preflight skill  <-- THIS SKILL (FIRST!)
    |
    v
Router Agent (DS-STAR)
    |
    v
RL-Enhanced Skill Selection
    |
    v
Skill Activation
    |
    v
Agent Invocation (via skill)
```

**Critical**: Router Agent MUST NOT process until this skill completes.

## Violation Handling

### If You Catch Yourself Violating

If you realize you started work without running this protocol:

1. **STOP** immediately
2. **ACKNOWLEDGE** the violation
3. **CORRECT** by running the 4-step protocol now
4. **PROCEED** only after completing all steps
5. **LOG** the self-correction event

**Self-Correction Template**:
```
[CORRECTION] I started work without completing the pre-flight check.

Constitutional Compliance Check (corrected):
- Timestamp: [now]
- Domain(s): [analysis]
- Delegation: [skill decision]
- Git operations: [status]
- Proceeding with: [corrected action]
```

### Bypass Attempt Detection

If another skill/agent attempts to bypass this check:

1. **BLOCK** the attempted action
2. **LOG** the bypass attempt
3. **FORCE** compliance check execution
4. **ALERT** user to governance violation

## Performance Targets

| Metric | Target | Rationale |
|--------|--------|-----------|
| Execution Time | <500ms | Must not delay user experience |
| Success Rate | 99.9% | Critical path, must be reliable |
| Token Usage | <200 | Minimal overhead |

## Common Violations to Avoid

1. **Skipping to implementation** without domain analysis
2. **Invoking agents directly** without going through skills (v3)
3. **Running git commands** without user approval
4. **Ignoring multi-domain** complexity (treating as single domain)
5. **Bypassing compliance check** on "simple" tasks (NO exceptions)

## Constitutional Compliance

This skill directly implements:
- **FR-707**: Compliance check as FIRST step after user message
- **Principle X**: Work Session Initiation Protocol (skills-first in v3)
- **Principle VI**: Git operation approval enforcement

**From Constitution v1.6.0**:

> **Work Session Initiation Protocol (MANDATORY for EVERY task)**:
>
> **Step 1: READ CONSTITUTION** - First action of any session
> **Step 2: ANALYZE TASK DOMAIN** - Scan for trigger keywords
> **Step 3: DELEGATION DECISION** - Route to appropriate skill
> **Step 4: EXECUTION** - Execute directly OR activate skill

This skill automates and enforces this protocol.

## Validation

Verify the skill executed correctly:

- [ ] Constitution acknowledgment completed (Step 1)
- [ ] Domain keywords scanned (Step 2)
- [ ] Domain count determined (0, 1, or 2+)
- [ ] Skill routing decision made (Step 3)
- [ ] Compliance summary output provided
- [ ] Appropriate skill activated (if needed)
- [ ] Git operations flagged (if detected)
- [ ] Audit log entry created

## Related Skills

- **domain-detection**: Detailed domain analysis
- **constitutional-compliance**: Full compliance validation (post-work)
- **orchestration/multi-skill-workflow**: Multi-domain coordination

## References

- Constitution v1.6.0: `.specify/memory/constitution.md`
- Skill Activation Triggers: `.specify/memory/skill-activation-triggers.md` (Phase 3)
- Agent Collaboration Triggers: `.specify/memory/agent-collaboration-triggers.md` (legacy)
- Domain Detection Skill: `.claude/skills/validation/domain-detection/SKILL.md`
