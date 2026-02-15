---
name: planning-agent
description: |
  Step-by-step procedural guidance for executing the /plan command workflow. Covers
  Phase 0 (Research), Phase 1 (Design), and Phase 2 (Validation) for implementation
  planning with constitutional compliance.

  This skill orchestrates the generation of implementation plans from feature specifications.
  It produces research.md, data-model.md, contracts/, and quickstart.md artifacts while
  enforcing Library-First, Test-First, and Contract-First principles.

  Triggered by: /plan command, "generate plan", "implementation plan", "create plan from spec",
  "design this feature", "how should we implement", "technical design".
allowed-tools: Read, Write, Bash, Grep, Glob, TaskCreate, TaskUpdate
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_feedback: null
---

# Planning Agent Skill

## When to Use

Activate this skill when:
- User invokes the `/plan` command
- User requests an implementation plan for a feature with an existing specification
- User asks "how should we implement this feature?"
- User requests technical design, architecture planning, or contract generation
- A specification (spec.md) is complete and ready for planning

**Trigger Keywords**: /plan, plan, implementation plan, technical design, how to implement, architecture design, design this feature, create plan, generate plan

**Prerequisites**:
- Feature specification (`spec.md`) must exist in the feature's `specs/` directory
- Feature branch must follow naming convention `###-feature-name`
- Constitution at `.specify/memory/constitution.md` must be accessible

## Procedure

### Step 1: Initialize Planning Scaffolding

**Action**: Run the setup script to scaffold the plan and extract feature paths.

```bash
.specify/scripts/bash/setup-plan.sh --json
```

**Parse the JSON output** to extract:
- `FEATURE_SPEC`: Path to the feature specification (spec.md)
- `IMPL_PLAN`: Path to the implementation plan (plan.md, copied from template)
- `SPECS_DIR`: Directory for all feature artifacts
- `BRANCH`: Current feature branch name

**Expected Outcome**: Plan template copied to `$IMPL_PLAN`, all paths resolved as absolute paths.

### Step 2: Analyze the Feature Specification

**Action**: Read the feature specification and extract key information for planning.

```bash
Read: $FEATURE_SPEC
```

**Extract from the specification**:
- Feature requirements and user stories
- Functional and non-functional requirements
- Success criteria and acceptance criteria
- Technical constraints and dependencies
- Domain context and scope boundaries

**Expected Outcome**: Clear understanding of what the feature requires, ready to inform research and design phases.

### Step 3: Review Constitutional Requirements

**Action**: Read the constitution and apply governance to the planning process.

```bash
Read: .specify/memory/constitution.md
```

**Focus on these principles for planning**:
- **Principle I (Library-First)**: Feature must be designed as a standalone library with clear public API
- **Principle II (Test-First)**: Test scenarios must be defined before implementation approach
- **Principle III (Contract-First)**: API contracts and interfaces defined before any code
- **Principle IX (Dependency Management)**: All dependencies declared with versions and rationale
- **Principle XVI (Plugin-First)**: New capabilities should be structured as plugins where applicable

**Expected Outcome**: Constitution check section populated in the plan template; any violations documented in Complexity Tracking.

### Step 4: Execute Phase 0 -- Research and Analysis

**Action**: Resolve all technical unknowns and document decisions in research.md.

**Details**:
- Identify all `NEEDS CLARIFICATION` items in the Technical Context section of the plan
- For each technology decision: evaluate 2-3 options, compare on maturity, community support, performance, and team skill alignment
- For each library dependency: assess stars/downloads, maintenance activity, license compatibility
- For each integration point: research patterns, best practices, and known pitfalls
- Resolve ALL unknowns before proceeding to Phase 1

**Output format for research.md**:
```markdown
## Decision: [Technology Choice]
- **Selected**: [What was chosen]
- **Rationale**: [Why it was chosen]
- **Alternatives Considered**: [What else was evaluated and why rejected]
```

**Expected Outcome**: `$SPECS_DIR/research.md` generated with all decisions documented and all `NEEDS CLARIFICATION` items resolved.

### Step 5: Execute Phase 1 -- Design and Contracts

**Action**: Generate data models, API contracts, and test scenarios from the specification and research.

**Sub-steps**:

1. **Data Model** -- Extract entities from the spec and define in `data-model.md`:
   - Entity names, fields, types, constraints
   - Relationships between entities
   - Validation rules derived from requirements
   - State transitions (if applicable)
   - Database indexes for performance

2. **API Contracts** -- Generate contract files in `contracts/` directory:
   - One file per endpoint or interface
   - REST: standard HTTP verbs, resource-oriented URLs, proper status codes, OpenAPI 3.0 format
   - GraphQL: schema-first, type definitions, query/mutation separation
   - Each contract includes request schema, response schema, error cases, and examples
   - Every user action from the spec must map to a contract

3. **Test Scenarios** -- Define test scenarios in `quickstart.md`:
   - Each user story maps to integration test scenarios
   - Cover happy path, error cases, and edge cases
   - Scenarios must be executable without additional context
   - Tests are designed to fail initially (TDD-first)

4. **Agent Context File** -- Update agent-specific context:
   ```bash
   .specify/scripts/bash/update-agent-context.sh claude
   ```

**Expected Outcome**: `data-model.md`, `contracts/*.md`, and `quickstart.md` all generated in `$SPECS_DIR`.

### Step 6: Post-Design Constitution Check

**Action**: Re-evaluate constitutional compliance after design phase completes.

**Checklist**:
- [ ] Principle I: Plan describes feature as standalone library with clear public API
- [ ] Principle II: quickstart.md includes test scenarios before implementation details
- [ ] Principle III: All contracts defined in contracts/ directory before any implementation
- [ ] Principle VIII: All artifacts generated together and cross-reference each other
- [ ] Principle IX: All dependencies listed with versions in research.md

**If violations found**: Refactor the design, return to Step 5, and regenerate affected artifacts.

**Expected Outcome**: Constitution check passes; plan is compliant with all immutable principles.

### Step 7: Validate the Implementation Plan

**Action**: Run the automated plan validation script.

```bash
.specify/scripts/bash/validate-plan.sh --file $IMPL_PLAN
```

**Validation categories (16 checks total)**:

- **Content Checks (5)**: File not empty, has title, has architecture section, specifies tech stack, defines implementation approach
- **Constitutional Principle Checks (3)**: Addresses Library-First, Test-First, Contract-First
- **Quality Checks (4)**: References data model, references contracts, lists dependencies, addresses security
- **Artifact Checks (4)**: research.md exists, data-model.md exists, contracts/ exists with files, quickstart.md exists

**Interpret results**:
- Score >= 80% (13/16): Ready to proceed
- Score 50-79%: Needs improvement -- address failing checks
- Score < 50%: Major gaps -- revisit Phases 0-1

**Expected Outcome**: Validation score reported with specific recommendations for any failing checks.

### Step 8: Run Domain Detection

**Action**: Detect which domains the plan touches and identify specialist agents for implementation.

```bash
.specify/scripts/bash/detect-phase-domain.sh --file $IMPL_PLAN
```

**Review domain detection output**:
- Compare detected domains against specification domains
- Identify any NEW domains that emerged during planning (this is expected -- planning adds technical detail)
- Record suggested agents for implementation phase
- Determine delegation strategy: single-agent vs multi-agent

**Expected Outcome**: Domain list, suggested agents, and delegation strategy captured for the completion report.

### Step 9: Report Completion

**Action**: Provide a comprehensive summary of planning results.

**Report format**:
```
Implementation Plan Generated

Branch: [branch-name]
Plan File: [path-to-plan.md]

Generated Artifacts:
- research.md: [Technical research and decisions]
- data-model.md: [Entities and schemas]
- contracts/: [N contract files]
- quickstart.md: [Test scenarios]

Validation Score: X/16
Status: [ready/needs-improvement]

Domains Detected: [list]
Suggested Agents: [list]
Delegation Strategy: [single-agent/multi-agent]

Constitutional Compliance:
- Library-First Architecture: [PASS/FAIL]
- Test-First Development: [PASS/FAIL]
- Contract-First Design: [PASS/FAIL]

Next Step: Run /tasks to generate implementation task list
```

**Expected Outcome**: User has clear understanding of planning results and readiness for the `/tasks` phase.

## Constitutional Compliance

### Principle I: Library-First Architecture
- Plan must describe the feature as a standalone, reusable library
- Library has a clear public API defined in contracts
- Library is testable independently of the application
- Library structure documented in research.md

### Principle II: Test-First Development
- quickstart.md defines test scenarios BEFORE implementation approach
- Each contract has a corresponding test scenario
- Testing strategy documented in the plan with coverage targets
- Test scenarios cover happy path, error cases, and edge cases

### Principle III: Contract-First Design
- All contracts defined in `contracts/` directory BEFORE implementation begins
- Each endpoint or interface documented with request/response schemas, error cases, and examples
- Contracts drive the implementation -- code fulfills contracts, not the other way around

### Principle VI: Git Operation Approval
- **CRITICAL**: NO autonomous git operations during planning
- Request user approval for ANY git commands (branch creation, commits, pushes)
- Document any planned git operations in the completion report

### Principle VIII: Documentation Synchronization
- All artifacts (research.md, data-model.md, contracts/, quickstart.md) generated together
- Plan.md references all generated artifacts
- Artifacts cross-reference each other for consistency
- Documentation is complete before implementation starts

### Principle IX: Dependency Management
- All dependencies listed in research.md with version constraints
- Each dependency has documented rationale and license verification
- Alternatives considered for each major dependency decision

### Principle X: Agent Delegation Protocol
When to delegate during planning:
- Complex multi-service architecture research: delegate Phase 0 research to backend-architect
- Database schema design requiring optimization expertise: delegate to database-specialist
- Multi-domain features (3+ domains detected): recommend task-orchestrator for implementation phase
- Security-critical features: flag for security-specialist review

## Examples

### Example 1: REST API Feature Planning

**User Request**: "/plan Add pagination, filtering, and sorting to user list API"

**Skill Execution**:
1. Run `setup-plan.sh --json` to get paths for current feature branch
2. Read spec.md to understand user list API requirements
3. Read constitution to verify Library-First, Test-First, Contract-First compliance
4. Execute Phase 0: Research pagination patterns (cursor vs offset), filtering syntax (query params vs body), sorting algorithms
5. Execute Phase 1:
   - data-model.md: PaginatedResponse, FilterCriteria, SortOrder entities
   - contracts/get-users-paginated.md: GET /api/users with query params for page, limit, filter, sort
   - quickstart.md: Test scenarios for pagination boundaries, filter combinations, sort ordering
6. Post-design constitution check: all principles satisfied
7. Run validation: 16/16 checks passing
8. Run domain detection: backend and database domains detected
9. Report completion with suggested agents: backend-architect, database-specialist

**Generated Artifacts**:
```
specs/001-user-list-api/
  spec.md          (from /specify)
  plan.md          (implementation plan)
  research.md      (pagination patterns, filtering approaches)
  data-model.md    (PaginatedResponse, FilterCriteria, SortOrder)
  contracts/
    get-users-paginated.md  (GET /api/users contract)
  quickstart.md    (test scenarios)
```

**Validation**: Run `validate-plan.sh --file plan.md` and confirm score >= 13/16.

### Example 2: React Component Planning

**User Request**: "/plan Implement user profile card component with avatar, name, bio"

**Skill Execution**:
1. Setup paths via `setup-plan.sh --json`
2. Read specification for component requirements (props, events, styling)
3. Read constitution
4. Execute Phase 0: Research React component patterns, CSS-in-JS vs Tailwind, accessibility standards (ARIA)
5. Execute Phase 1:
   - data-model.md: UserProfile interface, Avatar interface with size variants
   - contracts/profile-card-component.md: Component props, events, slots, accessibility attributes
   - quickstart.md: Rendering tests, interaction tests, accessibility tests, edge cases (missing avatar, long bio)
6. Post-design constitution check
7. Run validation: 15/16 passing (deployment check may not apply to component-only work)
8. Run domain detection: frontend domain detected
9. Report completion with suggested agent: frontend-specialist

**Expected Result**: Complete plan with frontend-focused artifacts, ready for `/tasks` generation.

## Agent Collaboration

### specification-agent
**When to delegate**: If no specification exists yet, redirect user to run `/specify` first.

**What they handle**: Feature specification creation, requirements gathering, user story definition.

**Handoff format**: "Run /specify first to create a feature specification, then return to /plan."

### backend-architect
**When to delegate**: Multi-service architecture decisions, complex backend system design, API gateway patterns during Phase 0 research.

**What they handle**: Backend system design, service decomposition, API architecture patterns.

### frontend-specialist
**When to delegate**: UI component architecture, state management decisions, client-side routing during Phase 0 research.

**What they handle**: Component design patterns, state management, UI/UX patterns.

### database-specialist
**When to delegate**: Complex data modeling, query optimization, schema design for high-scale systems during Phase 1.

**What they handle**: Database schema design, relationships, indexing strategies, query patterns.

### task-orchestrator
**When to delegate**: Multi-domain features where 3+ domains are detected during Step 8 domain detection.

**What they handle**: Coordinating multiple specialist agents during the implementation phase.

### tasks-agent
**When to delegate**: After planning completes, the user runs `/tasks` to generate the implementation task list.

**What they handle**: Converting the plan and its artifacts into an ordered, dependency-aware task list.

## RL Feedback Loop

After skill execution completes, the RL feedback mechanism updates metrics:

### Success Criteria
- All planning phases (0-1) completed without errors
- Validation score >= 80% (13/16 checks passing)
- All required artifacts generated (research.md, data-model.md, contracts/, quickstart.md)
- Constitutional compliance confirmed (Principles I, II, III)
- User proceeds to /tasks (implicit satisfaction signal)

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
  1. Output format validation - plan.md follows template structure
  2. Constitutional compliance check - Principles I, II, III confirmed
  3. Quality threshold verification - validation score >= 80%
  4. Artifact existence check - all required files generated
```

### Verifier Handoff
```json
{
  "skill": "planning-agent",
  "output": "<skill_output>",
  "validation_required": ["format", "compliance", "quality", "artifacts"],
  "threshold": 0.85
}
```

### On Verification Failure
- Log failure reason and specific check that failed
- Update rl_metrics with failure
- Report to user with specific remediation steps (which artifact to regenerate, which section to add)

## Validation

Verify the skill executed correctly:

- [ ] setup-plan.sh executed and all paths extracted (FEATURE_SPEC, IMPL_PLAN, SPECS_DIR, BRANCH)
- [ ] Feature specification read and key information extracted
- [ ] Constitution reviewed and principles applied to plan
- [ ] Phase 0: research.md generated with all decisions documented
- [ ] Phase 1: data-model.md generated with entities and relationships
- [ ] Phase 1: contracts/ directory created with contract files
- [ ] Phase 1: quickstart.md generated with test scenarios
- [ ] Post-design constitution check passed (Principles I, II, III)
- [ ] validate-plan.sh executed with score >= 80%
- [ ] detect-phase-domain.sh executed with domains and agents reported
- [ ] Completion report provided with all artifact paths
- [ ] User notified about next step (/tasks)

## Troubleshooting

### Issue: setup-plan.sh fails with "No specification found"

**Cause**: Feature specification does not exist or the current branch does not match the specs directory naming convention.

**Solution**:
1. Verify spec.md exists in the current branch's `specs/` directory
2. Run `/specify` first to create the specification
3. Ensure branch name follows `###-feature-name` convention
4. Check that `get_feature_paths` in `common.sh` resolves correctly

**Prevention**: Always confirm a specification exists before invoking `/plan`.

### Issue: Validation score is low (below 80%)

**Cause**: Plan is missing required sections or Phase 0/Phase 1 artifacts were not generated.

**Solution**:
1. Review validation output for specific failing checks
2. For content failures: add missing sections (architecture, tech stack, implementation steps)
3. For artifact failures: regenerate the missing files (re-run Phase 0 or Phase 1)
4. For constitutional failures: ensure plan mentions library/testing/contracts
5. Re-run `validate-plan.sh` after fixes

**Prevention**: Follow the template structure exactly and verify each phase before proceeding.

### Issue: No contracts generated

**Cause**: Feature does not define clear external interfaces, or API boundaries are ambiguous in the specification.

**Solution**:
1. Review the specification for API endpoints, component interfaces, or module boundaries
2. If the feature is purely internal, document internal module interfaces as contracts
3. Create at least one contract showing the module's public API
4. Update the plan to clarify contract boundaries

**Prevention**: Ensure the specification clearly defines user-facing actions that map to interfaces.

### Issue: Domain detection shows unexpected domains

**Cause**: Planning often reveals technical requirements not apparent in the specification (e.g., a frontend feature that needs a new API endpoint introduces the backend domain).

**Solution**:
1. This is expected behavior -- planning adds technical depth
2. Report the discrepancy to the user
3. If domains are additive (new domains added), proceed normally
4. If domains changed significantly, suggest updating the specification
5. Use the expanded domain list to recommend appropriate agents for implementation

**Prevention**: None needed -- this is a normal part of the planning process.

## Notes

**Important Considerations**:
- Planning quality directly affects all downstream work (tasks, implementation, testing)
- The plan template at `.specify/templates/plan-template.md` is self-executing -- trust its 9-step Execution Flow
- All three core artifacts (research.md, data-model.md, contracts/) must exist before `/tasks` can run
- Contracts define WHAT to build; the plan defines HOW to build
- quickstart.md test scenarios drive TDD implementation during the tasks phase

**Best Practices**:
- Use absolute paths throughout to avoid path resolution errors
- Resolve ALL `NEEDS CLARIFICATION` items during Phase 0 before moving to Phase 1
- Cross-reference artifacts: data-model.md entities should appear in contracts, contracts should have test scenarios in quickstart.md
- For multi-domain features, recommend task-orchestrator coordination in the completion report
- Keep the plan focused on the specification scope -- avoid scope creep during research

**Related Skills**:
- **sdd-specification**: Previous step in the SDD workflow (creates the feature specification)
- **sdd-planning**: The newer planning skill with identical workflow (shares the same procedure)
- **sdd-tasks**: Next step in the SDD workflow (generates task list from plan artifacts)
- **constitutional-compliance**: Validates constitutional principle adherence at quality gates

## Task Brief

You are a Senior Implementation Planning Specialist for SDD. You bridge the gap
between feature specifications and actionable task lists by creating comprehensive
technical plans that guide AI-driven implementation.

**Pipeline position**: Receives spec.md, produces plan.md + research.md +
data-model.md + contracts/ + quickstart.md. Downstream: tasks-agent consumes these.

**Research methodology** (Phase 0):
- For each technology decision: evaluate 2-3 options, compare on maturity/community/
  performance/team-skill, document decision + rationale + alternatives in research.md
- For library evaluation: assess stars, maintenance, license, compatibility
- Resolve ALL "NEEDS CLARIFICATION" items before moving to design

**Contract design** (Phase 1):
- REST: standard HTTP verbs, resource-oriented URLs, proper status codes, OpenAPI 3.0
- GraphQL: schema-first, type definitions, query/mutation separation
- Every user action must have a corresponding contract
- Generate failing contract tests (TDD-first)

**Data model design**: Define entities with fields, types, constraints, relationships,
validation rules, state transitions, and indexes.

**Quality gates**: Pre-research constitution check (16 principles) and post-design
constitution check. Refactor if violations found. Validate plan score >= 80%.

**Output standards**: All NEEDS CLARIFICATION resolved, each decision has rationale,
contracts are valid OpenAPI/GraphQL, quickstart.md is executable without extra context.

## Supporting Files

This skill directory can include:

### scripts/ (optional)
Executable utilities to automate parts of the procedure

### templates/ (optional)
Reusable content templates for generated artifacts

### reference.md (optional)
Detailed technical documentation and API references

### examples.md (optional)
Extended usage examples and edge cases

## References

- Plan Template: `.specify/templates/plan-template.md`
- Setup Script: `.specify/scripts/bash/setup-plan.sh`
- Validation Script: `.specify/scripts/bash/validate-plan.sh`
- Domain Detection: `.specify/scripts/bash/detect-phase-domain.sh`
- Constitution: `.specify/memory/constitution.md`
- SDD Planning Skill: `plugins/sdd-specification/skills/sdd-planning/SKILL.md`
- /plan Command: `plugins/sdd-specification/commands/plan.md`

---

**Skill Version**: 2.0.0
**Created**: 2025-11-08
**Last Updated**: 2026-02-15
**Department**: product
**Associated Agent**: planning-agent
