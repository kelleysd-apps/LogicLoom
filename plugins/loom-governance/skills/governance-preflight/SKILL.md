---
name: governance-preflight
category: governance
version: 3.1.0
description: Constitutional compliance and governance reference
tags: [governance, constitution, compliance, audit]
layer: skill
invocation: /governance-preflight
---

# Governance Preflight Skill

**Purpose**: Manual constitutional compliance review and governance decision-making for complex scenarios requiring human judgment.

**Enforcement is hook-driven.** The UserPromptSubmit governance hook injects constitutional
context and domain recommendations on every message, and the git-safety-gate PreToolUse hook
forces explicit approval on git mutations. Governance runs in two modes via
`LOOM_GOVERNANCE_MODE`: **lean** (default — hooks enforce silently) and **strict** (hooks
plus an explicit recited compliance summary). This skill is the reference layer between the
hook and the agent, invoked manually for complex review.

---

## When to Use This Skill

Use `/governance-preflight` when:

1. **Complex Delegation Decision** - Multiple worker briefs could handle the task
2. **Constitutional Ambiguity** - Unclear which principle applies
3. **Exception Request** - User wants to deviate from constitutional requirements
4. **Pre-Commit Review** - Manual validation before git operations
5. **Governance Audit** - Review governance decisions for compliance

**Hook-enforced**: governance context is injected automatically by the UserPromptSubmit hook;
this skill can be invoked manually for deeper review.

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
  - Is specialized work routed to a consolidated worker brief?
  - Is domain correctly identified?
  - Is the appropriate brief selected (`get_domain_brief <domain>`)?
  - **1 domain = 1 worker brief**, **2+ domains = swarm/team**

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
  - Is the appropriate model selected (Opus/Sonnet/Haiku)?
  - Default: Opus 4.8 (flagship) for agents
  - Sonnet for cost optimization
  - Haiku for simple tasks

- [ ] **Principle XV: File and Folder Organization**
  - Are files created in correct directories?
  - Do spec directories follow `###-feature-name` format?
  - Are agents in plugin agent directories?
  - Are skills in `plugin/skills/skill-name` structure?

---

## Worker Brief Delegation Reference

Domains resolve to consolidated worker briefs in the governance-core domain-brief registry
(`plugins/loom-governance/domain-briefs/<domain>.md`), resolved via `get_domain_brief
<domain>` in `.logic-loom/scripts/bash/common.sh`. This registry replaced the former seven
`sdd-domain-*` plugins. The authoritative keyword → domain map is
`plugins/loom-orchestrator-hook/config/domains.conf` (`keyword=domain`).

### Single-Domain Routing

| Domain | Keywords | Worker brief |
|--------|----------|--------------|
| **Frontend** | UI, component, React, CSS, form, responsive | `get_domain_brief frontend` |
| **Backend** | API, endpoint, server, auth, middleware, route | `get_domain_brief backend` |
| **Database** | schema, migration, query, RLS, SQL, table | `get_domain_brief database` |
| **Testing** | test, TDD, E2E, coverage, QA, assertion | `get_domain_brief testing` |
| **Security** | encryption, XSS, secrets, vulnerability, CSRF, injection | `get_domain_brief security` |
| **Performance** | optimize, cache, benchmark, latency, profiling | `get_domain_brief performance` |
| **DevOps** | deploy, CI/CD, Docker, pipeline, infrastructure | `get_domain_brief devops` |

### Multi-Domain Routing

| Scenario | Delegate To | Reason |
|----------|-------------|--------|
| 2+ domains detected | `/swarm` (or legacy team orchestration) | Coordinates multiple worker briefs |
| Complex workflow | `/swarm` | Orchestrates end-to-end implementation |
| Unclear domain | `/swarm explore` | Read-only investigation before committing scope |

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
- [ ] `/finalize` command run (legacy, if available)
- [ ] Git mutations gated by the git-safety-gate hook (Principle VI)

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
- Specialist work performed without worker-brief delegation (Principle X)
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

**Decision**: Dispatch a `/swarm` (2+ domains)

**Output**:
```
Constitutional Compliance Check:
- Domain(s): multi (frontend, backend)
- Delegation: /swarm
- Git operations: none planned (git-safety-gate will gate any mutation)
- Proceeding with: coordinating frontend and backend worker briefs under a swarm
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

Per Principle XV, agent files should live in a plugin's agents/ directory:

Incorrect: .claude/agents/api-builder.md
Correct: plugins/<plugin>/agents/api-builder.md

Which plugin should this agent belong to? Examples:
- loom-orchestrator (swarm/team orchestration agents)
- loom-creation (creation/scaffolding agents)
- loom-governance (governance agents)

Note: domain expertise is no longer carried by per-domain plugins — it lives as
consolidated worker briefs in plugins/loom-governance/domain-briefs/<domain>.md
(resolved via get_domain_brief). Create an agent only when a brief is insufficient.
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

- **Constitution**: `.logic-loom/memory/constitution.md` (v3.1.0)
- **Hook Layer**: `.claude/hooks/user-prompt-submit/README.md`
- **Agent Layer**: `plugins/loom-governance/agents/constitutional-governance-agent.md`
- **Hybrid Architecture**: `.docs/governance/hybrid-architecture.md`
- **Finalize Command**: `/finalize` skill for pre-commit validation

---
