---
name: domain-detection
description: |
  Analyze text to identify technical domains and suggest appropriate specialized agents
  for delegation following Constitutional Principle X (Agent Delegation Protocol).

  This skill examines specifications, plans, tasks, or any technical text to detect
  domain keywords and recommend whether to use single-agent or multi-agent delegation.
  It ensures specialized work is routed to specialists rather than handled by generalists.

  Triggered by: User request for "which agent?", "who should do this?", domain
  identification needs, or automatically by /specify, /plan, /tasks commands.
allowed-tools: Read, Bash, Grep
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_feedback: null
---

# Domain Detection Skill

## When to Use

Activate this skill when:
- Need to identify which domains/agents are involved in work
- User asks "which agent should handle this?"
- Determining delegation strategy (single vs multi-agent)
- After creating specification (identify domains early)
- After creating plan (confirm domains, detect new ones)
- Before executing tasks (route to correct agents)

**Trigger Keywords**: which agent, domain, who should, delegate to, specialist, orchestrator

**Automatic Activation**: `/specify`, `/plan`, and `/tasks` commands automatically use this skill

## Procedure

### Step 1: Load Agent Collaboration Reference

**Read the agent collaboration triggers document**:
```bash
Read: .specify/memory/agent-collaboration-triggers.md
```

**Understand the 11 domains**:
1. **Frontend** - UI, components, client-side
2. **Backend** - APIs, servers, business logic
3. **Database** - Schema, queries, data modeling
4. **Testing** - Quality assurance, test automation
5. **Security** - Authentication, authorization, vulnerabilities
6. **Performance** - Optimization, scaling, monitoring
7. **DevOps** - CI/CD, deployment, infrastructure
8. **Architecture** - System design, patterns, decisions
9. **Specification** - Requirements, user stories, acceptance criteria
10. **Tasks** - Work breakdown, dependencies, planning
11. **Integration** - External APIs, third-party services

### Step 2: Analyze Text for Domain Keywords

**If analyzing a file**:
```bash
.specify/scripts/bash/detect-phase-domain.sh --file PATH_TO_FILE
```

**If analyzing user text**:
```bash
echo "TEXT_TO_ANALYZE" | .specify/scripts/bash/detect-phase-domain.sh --text
```

**Script performs keyword-based detection**:
- Counts domain keyword occurrences
- Scores each domain (weighted by keyword frequency)
- Identifies significant domains (threshold: 3+ keywords)
- Determines delegation strategy

**Domain Keywords (Examples)**:

**Frontend**: ui, user interface, component, view, screen, page, react, vue, angular, css, html, styling, responsive, mobile, desktop, web app, client-side

**Backend**: api, endpoint, server, service, route, handler, middleware, controller, business logic, authentication, authorization, session, jwt, rest, graphql

**Database**: database, schema, table, query, sql, nosql, postgres, mongodb, redis, migration, index, relationship, foreign key, primary key, data model, entity

**Testing**: test, testing, tdd, unit test, integration test, e2e, jest, vitest, cypress, playwright, coverage, assertion, mock, stub, test case

**Security**: security, vulnerability, authentication, authorization, rbac, permission, role, owasp, xss, sql injection, csrf, encryption, password, secret, token

### Step 3: Interpret Detection Results

**Parse JSON output**:
```json
{
  "detected_domains": ["frontend", "backend", "database"],
  "domain_scores": {
    "frontend": 8,
    "backend": 12,
    "database": 5
  },
  "significant_domains": ["frontend", "backend", "database"],
  "delegation_strategy": "multi-skill",
  "suggested_skills": [
    "frontend-operations (sdd-domain-frontend)",
    "api-design (sdd-domain-backend)",
    "schema-design (sdd-domain-database)",
    "team-orchestration (sdd-orchestrator)"
  ],
  "confidence": "high"
}
```

**Domain Count Rules**:
- **0 domains**: Generic work, no specialist skill needed
- **1 domain**: Single-skill activation
- **2 domains**: Single or dual-skill activation (evaluate complexity)
- **3+ domains**: Multi-skill coordination via team-orchestration

### Step 4: Determine Delegation Strategy

**Single-Skill Activation**:
- One significant domain detected
- Work is contained within domain
- No cross-domain dependencies

**Example**: "Implement user profile card component"
- Domain: frontend
- Skill: frontend-operations (sdd-domain-frontend)
- Strategy: single-skill

**Multi-Skill Coordination**:
- Multiple significant domains (3+)
- Work spans domain boundaries
- Requires coordination

**Example**: "Implement user registration with email verification"
- Domains: backend, database, security, integration
- Skills: api-design (backend), schema-design (database), security-operations (security), team-orchestration (orchestrator)
- Strategy: multi-skill (orchestration coordinates)

**team-orchestration Required When**:
- 3+ significant domains detected
- Complex cross-domain coordination needed
- Multiple specialist skills must work together

### Step 5: Map Domains to Agents

**Skill Mapping** (from skill registry):

| Domain | Enhanced Skill | Plugin |
|--------|----------------|--------|
| Frontend | frontend-operations | sdd-domain-frontend |
| Backend | api-design, service-architecture | sdd-domain-backend |
| Database | schema-design | sdd-domain-database |
| Testing | testing-operations | sdd-domain-testing |
| Security | security-operations | sdd-domain-security |
| Performance | performance-operations | sdd-domain-performance |
| DevOps | monitoring | sdd-domain-devops |
| Architecture | service-architecture (backend), subagent-architect (agent design) | Multiple |
| Specification | unified-specification | sdd-specification |
| Tasks | sdd-tasks | sdd-specification |
| Integration | api-design, monitoring | Multiple |

**Coordination Skill**:
- **team-orchestration** (sdd-orchestrator): Coordinates multi-skill workflows

### Step 6: Report Detection Results

**Provide comprehensive domain analysis**:
```
🔍 Domain Detection Results

Text Analyzed: [file path or description]
Analysis Method: [keyword-based detection]

Detected Domains (X total):
- Frontend: Score 8 (significant)
- Backend: Score 12 (significant)
- Database: Score 5 (significant)
- Testing: Score 2 (minor)

Significant Domains: frontend, backend, database

Delegation Strategy: multi-skill

Suggested Skills:
- frontend-operations (sdd-domain-frontend) - UI components
- api-design (sdd-domain-backend) - API design
- schema-design (sdd-domain-database) - Schema design
- team-orchestration (sdd-orchestrator) - Coordinate workflow

Confidence: High

Rationale:
- 3 significant domains detected (frontend, backend, database)
- Cross-domain work requires coordination
- team-orchestration recommended to manage specialist skills

Next Step:
- Activate team-orchestration skill
- team-orchestration will route work to specialist skills
- Skills collaborate on implementation
```

## Constitutional Compliance

### Principle X: Agent Delegation Protocol
**This skill IMPLEMENTS Principle X**:

- Analyzes task domain
- Identifies specialized agents
- Determines delegation strategy
- Ensures specialized work → specialized agents

**Principle X Workflow** (4 mandatory steps):
1. READ CONSTITUTION ✅
2. ANALYZE TASK DOMAIN ✅ (this skill)
3. DELEGATION DECISION ✅ (this skill)
4. EXECUTION (agent executes)

**Critical Triggers** from Principle X:
- "test" → testing-operations (sdd-domain-testing)
- "database" → schema-design (sdd-domain-database)
- "API" → api-design (sdd-domain-backend)
- "component" → frontend-operations (sdd-domain-frontend)
- "security" → security-operations (sdd-domain-security)
- "deploy" → monitoring (sdd-domain-devops)
- "optimize" → performance-operations (sdd-domain-performance)

## Examples

### Example 1: Single-Domain Detection

**User Request**: "Implement a loading spinner component for React"

**Skill Execution**:
1. Load skill registry reference
2. Analyze text: "loading spinner component React"
3. Detect keywords: component (frontend), React (frontend), UI (frontend)
4. Results:
   - Domains: frontend (score: 5)
   - Significant: frontend
   - Strategy: single-skill
   - Skills: frontend-operations

**Output**:
```
🔍 Domain Detection Results

Detected Domains: frontend
Delegation Strategy: single-skill
Suggested Skill: frontend-operations (sdd-domain-frontend)

Rationale: Pure frontend UI component work
```

### Example 2: Multi-Domain Detection

**User Request**: "Build user authentication with email, password, JWT tokens, and PostgreSQL storage"

**Skill Execution**:
1. Load reference
2. Analyze text
3. Detect keywords:
   - Backend: api, endpoint, jwt, token, authentication
   - Database: postgresql, storage, schema
   - Security: authentication, password, token
4. Results:
   - Domains: backend (12), database (6), security (8)
   - Significant: backend, database, security
   - Strategy: multi-skill
   - Skills: api-design, schema-design, security-operations, team-orchestration

**Output**:
```
🔍 Domain Detection Results

Detected Domains: backend, database, security
Delegation Strategy: multi-skill
Suggested Skills:
- api-design (sdd-domain-backend) - API design, JWT handling
- schema-design (sdd-domain-database) - User schema, sessions
- security-operations (sdd-domain-security) - Password hashing, auth security
- team-orchestration (sdd-orchestrator) - Coordinate workflow

Rationale: 3 domains require specialist coordination
```

### Example 3: No Specialist Needed

**User Request**: "Update README with installation instructions"

**Skill Execution**:
1. Load reference
2. Analyze text: "README installation instructions"
3. Detect keywords: documentation (general)
4. Results:
   - Domains: none significant
   - Strategy: no delegation needed
   - Can be handled without specialist skill

**Output**:
```
🔍 Domain Detection Results

Detected Domains: None significant
Delegation Strategy: No specialist skill needed
Suggestion: Handle directly (simple documentation update)

Rationale: No specialized domain work detected
```

## Skill Collaboration

### team-orchestration
**When to suggest**: 3+ significant domains detected

**What it does**: Coordinate multiple specialist skills, manage workflow, ensure integration

### All Specialist Skills
**When to suggest**: Domain detected matches their specialty

**What they do**: Execute specialized work in their domain (may invoke consolidated agents)

### Work Session Initiation Protocol
**This skill supports Step 2** of the mandatory 4-step protocol:
1. READ CONSTITUTION (required before this skill)
2. **ANALYZE TASK DOMAIN** ← THIS SKILL
3. DELEGATION DECISION (based on this skill's output)
4. EXECUTION (execute directly or activate skill)

## Validation

Verify the skill executed correctly:

- [ ] Agent collaboration reference loaded
- [ ] Text analyzed (file or user input)
- [ ] Domain detection script executed
- [ ] Detection results parsed (JSON)
- [ ] Domain scores calculated
- [ ] Significant domains identified
- [ ] Delegation strategy determined
- [ ] Agents mapped to domains
- [ ] Results reported to user
- [ ] Confidence level assessed
- [ ] Rationale provided

## Troubleshooting

### Issue: No domains detected for obviously technical work

**Cause**: Keywords not in detection dictionary

**Solution**:
- Review `.specify/scripts/bash/detect-phase-domain.sh` keyword lists
- Add missing keywords to appropriate domain
- Re-run detection

### Issue: Wrong domains detected

**Cause**: Ambiguous keywords or keyword overlap

**Solution**:
- Review domain scores (not just presence/absence)
- Higher score = stronger signal
- Consider context (not just keywords)
- Manual override if clearly incorrect

### Issue: Single-agent vs multi-agent unclear (2 domains)

**Cause**: Edge case (2 domains can go either way)

**Solution**:
- Evaluate complexity:
  - Simple integration → single-agent can handle both
  - Complex coordination → use multi-agent with orchestrator
- Default to multi-agent if unsure (safer)

### Issue: Multiple skills from same domain

**Cause**: Domain maps to multiple specialist skills

**Solution**:
- Choose most specific skill
- Example: "system architecture" could be service-architecture or subagent-architect
  - For implementation architecture → service-architecture (sdd-domain-backend)
  - For agent/constitutional architecture → subagent-architect (agent)

## Notes

- Domain detection is keyword-based (fast but not perfect)
- High domain scores indicate stronger presence of that domain
- team-orchestration is "coordinator" not a domain specialist skill
- Single-skill activation is simpler and faster (prefer when possible)
- Multi-skill coordination provides better quality for complex work
- Principle X makes skill-first routing MANDATORY for specialized work
- This skill automates Step 2 of Work Session Initiation Protocol
- Detection runs automatically in /specify, /plan, /tasks workflows
- Can be run standalone on any text/file



## RL Feedback Loop

After skill execution completes, the RL feedback mechanism updates metrics:

### Success Criteria
- Task completed without errors
- Output validated by verifier (if applicable)
- User satisfaction (implicit from follow-up)

### Feedback Collection
```
ON SKILL COMPLETION:
  1. Capture execution result (success/failure)
  2. Record token usage
  3. Calculate execution duration
  4. Update rl_metrics via EMA:
     - success_rate = 0.9 * old_rate + 0.1 * (1 if success else 0)
     - selection_weight = adjusted based on success_rate
  5. Log to .docs/rl-metrics/skill-performance.json
```

### Metrics Update Trigger
```python
# Pseudo-code for RL update
def update_rl_metrics(skill_name: str, success: bool, tokens: int):
    metrics = load_skill_metrics(skill_name)
    metrics['invocation_count'] += 1
    metrics['success_rate'] = 0.9 * metrics['success_rate'] + 0.1 * (1 if success else 0)
    metrics['avg_tokens'] = 0.9 * metrics['avg_tokens'] + 0.1 * tokens
    metrics['selection_weight'] = max(0.1, min(1.0, metrics['success_rate']))
    metrics['last_feedback'] = datetime.utcnow().isoformat()
    save_skill_metrics(skill_name, metrics)
```


## Verifier Integration

### Pre-Completion Validation
Before marking this skill as complete, invoke verifier validation:

```
VERIFIER_CHECK:
  1. Output format validation
  2. Constitutional compliance check
  3. Quality threshold verification
  4. Domain-specific validation rules
```

### Verifier Handoff
```json
{
  "skill": "domain-detection",
  "output": "<skill_output>",
  "validation_required": ["format", "compliance", "quality"],
  "threshold": 0.85
}
```

### On Verification Failure
- Log failure reason
- Update rl_metrics with failure
- Report to user with remediation options

## Related Skills

- **sdd-specification**: Uses this skill to identify agents early
- **sdd-planning**: Uses this skill to confirm/update agents
- **sdd-tasks**: Uses this skill to route task execution
- **constitutional-compliance**: Validates Principle X compliance

## References

- Agent Collaboration Triggers: `.specify/memory/agent-collaboration-triggers.md`
- Constitution v1.5.0: `.specify/memory/constitution.md` (Principle X)
- Detection Script: `.specify/scripts/bash/detect-phase-domain.sh`
- Skill Registry: `plugins/*/skills/` (all specialist skills across plugins)
