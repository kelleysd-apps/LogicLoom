---
name: governance-preflight
category: governance
version: 1.0.0
description: Constitutional compliance and governance enforcement
author: SDD Framework
tags: [governance, constitution, compliance, audit]
layer: skill
invocation: /governance-preflight
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_feedback: null
---

# Governance Preflight Skill

**Purpose**: Manual constitutional compliance review and governance decision-making for complex scenarios requiring human judgment.

**Layer**: Layer 2 of 3-layer governance architecture (Hook → **Skill** → Agent)

---

## When to Use This Skill

Use `/governance-preflight` when:

1. **Complex Delegation Decision** - Multiple agents could handle the task
2. **Constitutional Ambiguity** - Unclear which principle applies
3. **Exception Request** - User wants to deviate from constitutional requirements
4. **Pre-Commit Review** - Manual validation before git operations
5. **Governance Audit** - Review governance decisions for compliance

**Auto-Triggered**: This skill is conceptually triggered by the UserPromptSubmit hook (Layer 1), but can be manually invoked for review.

---

## Constitutional Compliance Checklist

Use this checklist to validate compliance with all 16 principles:

### Part I: Core Immutable Principles (I-III)

- [ ] **Principle I: Library-First Architecture**
  - Is feature implemented as standalone library?
  - Does library have its own test suite?
  - Is library API versioned and documented?

- [ ] **Principle II: Test-First Development (TDD)** ⚠️ IMMUTABLE
  - Are tests written before implementation?
  - Is code coverage >80%?
  - Do tests fail before implementation?
  - Are tests passing after implementation?

- [ ] **Principle III: Contract-First Design**
  - Are API contracts defined before implementation?
  - Do contracts use OpenAPI/GraphQL schemas?
  - Are contract tests written and passing?

### Part II: Quality & Safety Principles (IV-IX)

- [ ] **Principle IV: Idempotent Operations**
  - Can operation be safely repeated?
  - Does script handle "already exists" scenarios?
  - Are state changes atomic?

- [ ] **Principle V: Progressive Enhancement**
  - Are feature flags used for gradual rollout?
  - Is rollback capability available?
  - Are breaking changes avoided?

- [ ] **Principle VI: Git Operation Approval** ⚠️ CRITICAL
  - Has user explicitly approved git operation?
  - Are commit messages clear and descriptive?
  - Is push/merge approved by user?
  - **NEVER** perform git operations autonomously

- [ ] **Principle VII: Observability & Structured Logging**
  - Are critical operations logged?
  - Is logging structured (JSON preferred)?
  - Are logs searchable and queryable?

- [ ] **Principle VIII: Documentation Synchronization**
  - Is CLAUDE.md updated if instructions changed?
  - Is README.md in sync with codebase?
  - Are API docs current?
  - Is constitution updated if principles changed?

- [ ] **Principle IX: Dependency Management**
  - Are dependencies explicitly declared?
  - Are version constraints specified?
  - Are security vulnerabilities checked?

### Part III: Workflow & Delegation Principles (X-XVI)

- [ ] **Principle X: Agent Delegation Protocol** ⚠️ CRITICAL
  - Is specialized work routed to specialist skills?
  - Is domain correctly identified?
  - Is appropriate skill selected?
  - **1 domain = 1 specialist skill**, **2+ domains = team-orchestration**

- [ ] **Principle XI: Input Validation & Output Sanitization**
  - Is user input validated?
  - Are outputs sanitized (no XSS, injection)?
  - Are secrets excluded from logs/outputs?

- [ ] **Principle XII: Design System Compliance**
  - Do UI components follow design system?
  - Are theme tokens used consistently?
  - Is accessibility (a11y) considered?

- [ ] **Principle XIII: Feature Access Control**
  - Are access tiers implemented (if applicable)?
  - Is RLS (Row Level Security) configured?
  - Are permissions enforced?

- [ ] **Principle XIV: AI Model Selection Protocol**
  - Is appropriate model selected (Opus/Sonnet/Haiku)?
  - Default: Opus 4.5 for agents
  - Sonnet for cost optimization
  - Haiku for simple tasks

- [ ] **Principle XV: File and Folder Organization**
  - Are files created in correct directories?
  - Do spec directories follow `###-feature-name` format?
  - Are agents in plugin agent directories?
  - Are skills in `plugin/skills/skill-name` structure?

---

## Skill Delegation Reference

Use this table to route tasks to appropriate skills:

### Single-Domain Routing

| Domain | Keywords | Skill | Plugin |
|--------|----------|-------|--------|
| **Frontend** | UI, component, React, CSS, form, responsive | frontend-operations | sdd-domain-frontend |
| **Backend** | API, endpoint, server, auth, middleware | api-design, service-architecture | sdd-domain-backend |
| **Database** | schema, migration, query, RLS, SQL | schema-design | sdd-domain-database |
| **Testing** | test, TDD, E2E, coverage, QA | testing-operations | sdd-domain-testing |
| **Security** | encryption, XSS, secrets, vulnerability | security-operations | sdd-domain-security |
| **Performance** | optimize, cache, benchmark, latency | performance-operations | sdd-domain-performance |
| **DevOps** | deploy, CI/CD, Docker, pipeline | monitoring | sdd-domain-devops |
| **Planning** | /plan, research, contract design | sdd-planning | sdd-specification |
| **Specification** | /specify, requirements, user story | unified-specification | sdd-specification |
| **Tasks** | /tasks, task list, dependencies | sdd-tasks | sdd-specification |

### Multi-Domain Routing

| Scenario | Delegate To | Reason |
|----------|-------------|--------|
| 2+ domains detected | team-orchestration | Coordinates multiple specialist skills |
| Complex workflow | team-orchestration | Orchestrates end-to-end implementation |
| Unclear domain | team-orchestration | Routes after analysis |

### Domain Trigger Keywords (Comprehensive)

**Frontend**: UI, component, React, Next.js, Vue, Angular, CSS, Tailwind, form, button, modal, responsive, mobile, web, client-side, browser, DOM, JSX, TSX

**Backend**: API, endpoint, REST, GraphQL, server, Express, Fastify, middleware, authentication, authorization, session, JWT, OAuth, controller, service, route, handler

**Database**: schema, table, column, migration, query, SQL, PostgreSQL, MySQL, MongoDB, Supabase, Prisma, TypeORM, RLS, row-level security, index, transaction

**Testing**: test, TDD, unit test, integration test, E2E, Playwright, Jest, Vitest, coverage, mock, stub, assertion, test suite

**Security**: security, vulnerability, XSS, CSRF, SQL injection, encryption, hashing, secrets, credentials, authentication, authorization, OWASP, penetration test

**Performance**: performance, optimize, cache, Redis, latency, throughput, bottleneck, profile, benchmark, load test, CDN, lazy load

**DevOps**: deploy, deployment, CI/CD, Docker, Kubernetes, pipeline, GitHub Actions, AWS, GCP, Azure, infrastructure, container, orchestration

---

## Pre-Commit Validation Checklist

Before ANY git commit, verify:

### Code Quality
- [ ] All tests passing
- [ ] Code coverage >80%
- [ ] No linting errors
- [ ] Code formatted (black, prettier, etc.)

### Documentation
- [ ] CLAUDE.md synchronized with changes
- [ ] README.md updated if user-facing changes
- [ ] API docs current
- [ ] Inline comments for complex logic

### Security
- [ ] No secrets in code (check .env files)
- [ ] No API keys, passwords, tokens committed
- [ ] `.gitignore` includes sensitive files
- [ ] `.env.example` updated if new vars added

### Constitutional Compliance
- [ ] All 16 principles checked
- [ ] Critical principles (II, VI, X) verified
- [ ] Exceptions documented with justification
- [ ] `/finalize` command run (if available)

### Git Operations
- [ ] User explicitly approved commit
- [ ] Commit message is clear and descriptive
- [ ] Branch name follows convention
- [ ] No force-push to main/master

---

## Governance Decision Guidelines

### When to Block

**ALWAYS BLOCK**:
- Autonomous git operations without user approval (Principle VI)
- TDD violation (tests not written first) (Principle II)
- Specialist work performed without skill-first routing (Principle X)
- Secrets committed to repository (Principle XI)

**WARN BUT ALLOW**:
- Missing library structure (Principle I)
- Test coverage <80% but >60%
- Documentation slightly out of date (Principle VIII)
- Minor file organization issues (Principle XV)

**ALLOW WITH GUIDANCE**:
- Novel architecture patterns (document justification)
- Complexity justified by requirements
- Emergency fixes (document as tech debt)
- Experimental features (use feature flags)

### Escalation Criteria

Escalate to human when:

1. **Constitutional Conflict** - Two principles contradict
2. **Novel Scenario** - Situation not covered by constitution
3. **High-Risk Operation** - Could cause data loss or security breach
4. **Ambiguous Intent** - User request unclear or contradictory
5. **Exception Request** - User explicitly requests constitutional deviation

---

## Audit Log Format

When making governance decisions, log in this format:

```json
{
  "timestamp": "ISO-8601",
  "session_id": "string",
  "event_type": "governance_decision | agent_delegation | message_blocked",
  "decision_type": "approve | block | warn | delegate",
  "layer": "skill",
  "agent_role": "governance-preflight",
  "input_summary": "first 100 chars",
  "constitutional_principles": ["VI", "X"],
  "decision_rationale": "Why this decision was made",
  "action_taken": "What happened as a result",
  "escalated": false,
  "duration_ms": 0
}
```

**Log Location**: `.docs/governance/audit/{YYYY-MM-DD}/session-{id}.json`

**Manual Logging** (if audit directory exists):
```bash
echo '{ ... }' >> .docs/governance/audit/$(date +%Y-%m-%d)/skill-decision.json
```

---

## Examples

### Example 1: Single Domain Delegation

**User Request**: "Add a button to the user profile to delete account"

**Analysis**:
- Domain: Frontend (button, UI component)
- Complexity: Medium (also involves backend API call)
- Wait - TWO domains: Frontend (UI) + Backend (API)

**Decision**: Activate `team-orchestration` skill (2+ domains)

**Output**:
```
Constitutional Compliance Check:
- Domain(s): multi (frontend, backend)
- Delegation: team-orchestration
- Git operations: none planned (will request approval if needed)
- Proceeding with: coordinating frontend and backend specialist skills
```

---

### Example 2: Critical Principle Violation

**User Request**: "Commit the changes to the repository"

**Analysis**:
- Git operation requested
- Principle VI (CRITICAL): Git Operation Approval
- No explicit approval in current message history

**Decision**: ASK USER for explicit approval

**Output**:
```
⚠️ GOVERNANCE CHECKPOINT

Your request involves a git operation (commit), which requires explicit approval per Constitutional Principle VI.

Before I proceed, please confirm:
1. Do you want me to commit the changes?
2. What commit message would you like?
3. Should I push to remote after commit?

Please provide explicit approval for each step.
```

---

### Example 3: TDD Violation Prevention

**User Request**: "Implement the calculateTotal function"

**Analysis**:
- Implementation work requested
- Principle II (IMMUTABLE): Test-First Development
- No test mentioned

**Decision**: BLOCK and redirect to TDD workflow

**Output**:
```
⚠️ TDD VIOLATION PREVENTION

Per Constitutional Principle II (IMMUTABLE), implementation must follow Test-First Development.

Required workflow:
1. Write failing test for calculateTotal()
2. Get user approval
3. Run test (should fail)
4. Implement calculateTotal()
5. Run test (should pass)

Would you like me to start by writing the test first?
```

---

### Example 4: File Organization Check

**User Request**: "Create a new agent called api-builder.md"

**Analysis**:
- File creation requested
- Principle XV: File and Folder Organization
- Agent files must be in department subdirectories

**Decision**: WARN and suggest correct location

**Output**:
```
⚠️ FILE ORGANIZATION

Per Principle XV, agent files should be in department subdirectories:

Incorrect: .claude/agents/api-builder.md
Correct: plugins/sdd-domain-backend/agents/api-builder.md

Which plugin should this agent belong to?
- sdd-specification (product/spec agents)
- sdd-domain-backend (backend agents)
- sdd-domain-frontend (frontend agents)
- sdd-domain-testing (testing agents)
- sdd-domain-security (security agents)
- sdd-domain-devops (devops agents)
- sdd-governance (governance agents)
```

---

## Integration with Hook and Agent Layers

### Layer 1: UserPromptSubmit Hook (Automatic)
- **When**: Every user message
- **Action**: Inject governance context
- **Blocking**: No
- **Audit**: Yes

### Layer 2: Governance Preflight Skill (Manual)
- **When**: Manual invocation or complex scenarios
- **Action**: Review, validate, decide
- **Blocking**: Yes (can recommend blocking)
- **Audit**: Yes

### Layer 3: Constitutional Governance Agent (Active)
- **When**: Set as default agent
- **Action**: Execute governance decisions
- **Blocking**: Yes (enforces principles)
- **Audit**: Yes

**Recommended Setup**: All 3 layers active for maximum governance coverage.

---

## Performance Characteristics

**Typical Execution**: Manual skill invocation, human-paced

**Decision Time**:
- Simple: <1 minute (single principle check)
- Medium: 1-5 minutes (multiple principles, delegation decision)
- Complex: 5-15 minutes (conflict resolution, exception review)

**Audit Log Size**: ~1KB per decision

---
## Related Documentation

- **Constitution**: `.logic-loom/memory/constitution.md` (v3.0.0)
- **Hook Layer**: `.claude/hooks/user-prompt-submit/README.md`
- **Agent Layer**: `plugins/sdd-governance/agents/constitutional-governance-agent.md`
- **Hybrid Architecture**: `.docs/governance/hybrid-architecture.md`
- **Finalize Command**: `/finalize` skill for pre-commit validation

---
