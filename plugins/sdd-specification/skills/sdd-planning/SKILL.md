---
name: sdd-planning
description: |
  Generate comprehensive implementation plans using Specification-Driven Development (SDD)
  methodology. Use when creating technical design, implementation roadmap, or executing
  the /plan command.

  This skill orchestrates the plan-template.md execution flow, generating research, data
  models, API contracts, and test scenarios. It validates constitutional compliance
  (Library-First, Test-First, Contract-First) and prepares for task generation.

  Triggered by: /plan command, user request for "implementation plan", "technical design",
  "how to implement", or "design this feature".
allowed-tools: Read, Write, Bash, Grep, Glob
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_feedback: null
---

# SDD Planning Skill

## When to Use

Activate this skill when:
- User invokes `/plan` command
- User requests implementation planning for a feature
- User asks "how should we implement this?"
- Specification is complete and ready for technical design
- Need to generate data models, contracts, and test scenarios

**Trigger Keywords**: plan, implementation plan, technical design, how to implement, architecture, design, /plan

**Prerequisites**: Feature specification must exist (typically from /specify command)

## Procedure

### Step 1: Setup and Initialization

**Run setup script** to get feature paths:
```bash
.specify/scripts/bash/setup-plan.sh --json
```

**Parse JSON output** to extract:
- `FEATURE_SPEC`: Path to feature specification
- `IMPL_PLAN`: Path to implementation plan (plan.md)
- `SPECS_DIR`: Directory for all feature artifacts
- `BRANCH`: Current feature branch name

**IMPORTANT**: All file paths must be absolute (from repository root)

### Step 2: Analyze Specification

**Read and understand the feature specification**:
```bash
Read: $FEATURE_SPEC
```

**Extract key information**:
- Feature requirements and user stories
- Functional and non-functional requirements
- Success criteria and acceptance criteria
- Technical constraints and dependencies
- Domain context

### Step 3: Review Constitutional Requirements

**Read the constitution** to ensure compliance:
```bash
Read: .specify/memory/constitution.md
```

**Focus on core principles**:
- **Principle I**: Library-First Architecture - Feature must start as standalone library
- **Principle II**: Test-First Development - Tests written before implementation
- **Principle III**: Contract-First Design - Define contracts before code
- **Principle IX**: Dependency Management - All dependencies declared

### Step 4: Execute Plan Template

**Load the plan template**:
```bash
Read: .specify/templates/plan-template.md
```

**The plan template is self-executing** - follow its 9-step Execution Flow:

**Phase 0: Research & Analysis**
- Technical research for feature requirements
- Technology evaluation and selection
- Architecture patterns identification
- Risk assessment
- Generate: `$SPECS_DIR/research.md`

**Phase 1: Design Artifacts**
- Data model definition (entities, relationships, schemas)
  - Generate: `$SPECS_DIR/data-model.md`
- API contract definition (endpoints, request/response schemas)
  - Generate: `$SPECS_DIR/contracts/*.md` (one file per endpoint/contract)
- Test scenario definition (from user stories)
  - Generate: `$SPECS_DIR/quickstart.md`

**Phase 2: Execution Planning**
- Implementation roadmap
- Task breakdown with dependencies
- Note: tasks.md generation is deferred to /tasks command

**Incorporate user-provided details**:
- Add any additional context from command arguments to Technical Context section
- User may provide implementation preferences, technology choices, constraints

**Update Progress Tracking** as you complete each phase:
- Mark phases as complete
- Note any errors or blockers
- Track generated artifacts

### Step 5: Verify Execution

**Check that all phases completed successfully**:
- [ ] Phase 0: research.md exists and is comprehensive
- [ ] Phase 1: data-model.md exists with entities defined
- [ ] Phase 1: contracts/ directory exists with contract files
- [ ] Phase 1: quickstart.md exists with test scenarios
- [ ] Phase 2: Implementation approach documented in plan.md
- [ ] Progress Tracking shows all phases complete
- [ ] No ERROR states in execution

### Step 6: Validate Implementation Plan

**Run plan validation**:
```bash
.specify/scripts/bash/validate-plan.sh --file $IMPL_PLAN
```

**Validation checks** (16 total):

**Constitutional Compliance** (3 checks):
- Library-First: Plan mentions library/package/module
- Test-First: Plan mentions testing/TDD
- Contract-First: Plan mentions contracts/API/interfaces

**Artifact Existence** (4 checks):
- research.md exists
- data-model.md exists
- contracts/ directory exists
- quickstart.md exists

**Plan Content Quality** (9 checks):
- Has overview section
- Has architecture section
- Has implementation phases
- Has testing strategy
- Has dependencies section
- Has risks section
- Has timeline section
- Has technical stack
- Has deployment strategy

**Report validation results**:
- Overall score (X/16 checks passing)
- Readiness status (ready/needs-improvement)
- Specific recommendations

### Step 7: Domain Detection

**Run domain detection on plan**:
```bash
.specify/scripts/bash/detect-phase-domain.sh --file $IMPL_PLAN
```

**Confirm domain alignment**:
- Compare detected domains with specification domains
- Identify any NEW domains that emerged during planning
- Report any discrepancies

**Capture suggested agents**:
- Specialist agents needed for implementation
- Delegation strategy (single-agent vs multi-agent)

### Step 8: Report Completion

**Provide comprehensive summary**:
```
✅ Implementation Plan Generated

Branch: [branch-name]
Plan File: [path-to-plan.md]

Generated Artifacts:
- research.md: [Technical research and decisions]
- data-model.md: [Entities and schemas]
- contracts/: [X contract files]
- quickstart.md: [Test scenarios]

Validation Score: X/16
Status: [ready/needs-improvement]

Domains Detected: [list]
Suggested Agents: [list]
Delegation Strategy: [single-agent/multi-agent]

Constitutional Compliance:
✅ Library-First Architecture
✅ Test-First Development
✅ Contract-First Design

Next Step: Run /tasks to generate implementation task list
```

## Constitutional Compliance

### Principle I: Library-First Architecture
- Ensure plan describes feature as standalone library
- Library has clear public API
- Library is reusable and testable independently
- Document library structure in research.md

### Principle II: Test-First Development
- quickstart.md must include test scenarios BEFORE implementation
- Testing strategy documented in plan
- Each contract has corresponding test scenario
- Test scenarios cover happy path, error cases, edge cases

### Principle III: Contract-First Design
- All contracts defined in contracts/ directory BEFORE implementation
- Each endpoint/interface documented with:
  - Request schema
  - Response schema
  - Error cases
  - Examples
- Contracts drive implementation

### Principle VIII: Documentation Synchronization
- All artifacts generated together
- Plan references all artifacts
- Artifacts cross-reference each other
- Documentation complete before implementation starts

### Principle IX: Dependency Management
- All dependencies listed in research.md
- Dependency rationale documented
- Version constraints specified
- Licenses verified

## Examples

### Example 1: REST API Feature Planning

**User Request**: "/plan Add pagination, filtering, and sorting to user list API"

**Skill Execution**:
1. Run setup-plan.sh → get paths for current feature branch
2. Read specification → understand user list API requirements
3. Read constitution → verify Library-First, Test-First, Contract-First
4. Execute plan template:
   - **Phase 0**: Research pagination patterns, filtering syntax, sorting algorithms
   - **Phase 1**:
     - data-model.md: PaginatedResponse, FilterCriteria, SortOrder entities
     - contracts/get-users-paginated.md: GET /api/users with query params
     - quickstart.md: Test scenarios for pagination, filtering, sorting
   - **Phase 2**: Implementation approach documented
5. Verify all artifacts generated
6. Run validation → 16/16 checks passing
7. Run domain detection → backend, database domains
8. Report completion with suggested agents: backend-architect, database-specialist

**Generated Artifacts**:
```
specs/001-user-list-api/
├── spec.md (from /specify)
├── plan.md (implementation plan)
├── research.md (pagination patterns, filtering)
├── data-model.md (PaginatedResponse, FilterCriteria, SortOrder)
├── contracts/
│   └── get-users-paginated.md (GET /api/users contract)
└── quickstart.md (test scenarios)
```

### Example 2: React Component Planning

**User Request**: "/plan Implement user profile card component with avatar, name, bio"

**Skill Execution**:
1. Setup paths
2. Read specification → understand component requirements
3. Read constitution
4. Execute plan template:
   - **Phase 0**: Research React component patterns, styling approach, accessibility
   - **Phase 1**:
     - data-model.md: UserProfile interface, Avatar interface
     - contracts/profile-card-component.md: Component props, events, slots
     - quickstart.md: Component test scenarios (rendering, interactions, edge cases)
   - **Phase 2**: Implementation approach (component structure, state management)
5. Verify artifacts
6. Run validation → 15/16 passing (missing deployment for component)
7. Run domain detection → frontend domain
8. Report completion with suggested agent: frontend-specialist

## Agent Collaboration

### planning-agent (PRIMARY)
**When to delegate**: ALL /plan command executions - this is the designated autonomous agent for implementation planning

**What they handle**: Complete autonomous execution of the planning workflow including:
- Phase 0: Technical research, library evaluation, technology stack selection
- Phase 1: API contract design (OpenAPI/GraphQL), data model creation, test scenario extraction
- Phase 2: Constitutional compliance validation (14 principles)
- Quality gates: Pre-research and post-design compliance checks
- Artifact generation: plan.md, research.md, data-model.md, contracts/, quickstart.md
- Readiness validation for task generation phase

**How to invoke**:
```
Use the Task tool to delegate to planning-agent:
- subagent_type: "planning-agent"
- description: "Execute /plan command"
- prompt: "Execute the /plan command for this feature"
```

**Agent Location**: `.claude/agents/product/planning-agent.md`

**Note**: This skill provides procedural guidance for the planning workflow. For autonomous execution, always delegate to the planning-agent which has specialized tools and constitutional compliance built-in.

---

### backend-architect
**When to delegate**: Multi-service architecture, complex backend systems (for specialized research during Phase 0)

**What they handle**: Backend system design, API architecture, service patterns

### frontend-specialist
**When to delegate**: UI components, user interactions, client-side logic

**What they handle**: Component design, state management, UI patterns

### database-specialist
**When to delegate**: Complex data models, query optimization, schema design

**What they handle**: Database schema, relationships, indexing, query patterns

### task-orchestrator
**When to delegate**: Multi-domain feature (3+ domains detected)

**What they handle**: Coordinating multiple specialists during implementation

## Validation

Verify the skill executed correctly:

- [ ] setup-plan.sh executed and paths extracted
- [ ] Feature specification read and analyzed
- [ ] Constitution reviewed and applied
- [ ] Plan template executed through all phases
- [ ] research.md generated and comprehensive
- [ ] data-model.md generated with entities
- [ ] contracts/ directory has contract files
- [ ] quickstart.md generated with test scenarios
- [ ] Plan validation executed and reported
- [ ] Domain detection executed and reported
- [ ] Suggested agents reported to user
- [ ] User notified about next step (/tasks)

## Troubleshooting

### Issue: setup-plan.sh fails with "No specification found"

**Cause**: Feature specification doesn't exist or is in wrong location

**Solution**:
- Verify spec.md exists in current branch's specs/ directory
- Run /specify first to create specification
- Check branch name matches specs directory name

### Issue: Validation score low (<12/16)

**Cause**: Plan missing required sections or artifacts not generated

**Solution**:
- Review validation output for specific failures
- Check that all Phase 0 and Phase 1 artifacts exist
- Ensure plan.md includes all required sections
- Re-run plan template phases that failed

### Issue: No contracts generated

**Cause**: Feature doesn't define external interfaces or API contracts unclear

**Solution**:
- Review specification for API endpoints or component interfaces
- If truly no external contracts, document internal interfaces
- Create at least one contract showing module public API
- Update plan to clarify contract boundaries

### Issue: Domain detection shows different domains than specification

**Cause**: Planning revealed additional technical requirements

**Solution**:
- This is expected - planning adds technical detail
- Report discrepancy to user
- Suggest updating specification if domains significantly changed
- Proceed with planning if domains are additive (e.g., added database to frontend feature)

## Notes

- Planning phase is critical - quality here affects all downstream work
- Plan template is self-executing - trust its process
- All three artifacts (research, data-model, contracts) must exist before tasks
- Contracts define "what" to build, plan defines "how" to build
- quickstart.md test scenarios drive TDD implementation
- Use absolute paths to avoid path resolution issues
- Domain detection may reveal domains not apparent in specification
- Multi-domain features benefit from task-orchestrator coordination



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
  "skill": "sdd-planning",
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

- **sdd-specification**: Previous step (creates specification)
- **sdd-tasks**: Next step (generates task list from plan)
- **constitutional-compliance**: Validates constitutional principle adherence
- **api-contract-design**: Deep-dive into contract definition (Priority 3)
