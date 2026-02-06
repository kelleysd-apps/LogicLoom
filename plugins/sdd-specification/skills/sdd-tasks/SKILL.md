---
name: sdd-tasks
description: |
  Generate actionable, dependency-ordered task lists from implementation plans using
  Specification-Driven Development (SDD) methodology. Use when creating executable
  work breakdown, task lists, or executing the /tasks command.

  This skill analyzes design artifacts (plan, contracts, data models, test scenarios)
  and generates a sequenced task list with parallel execution markers. Tasks follow
  TDD (test-first) and contract-first principles, with clear dependencies and file paths.

  Triggered by: /tasks command, user request for "task list", "work breakdown",
  "implementation steps", or "what tasks do I need to complete?".
allowed-tools: Read, Write, Bash, Grep, Glob
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_feedback: null
---

# SDD Tasks Skill

## When to Use

Activate this skill when:
- User invokes `/tasks` command
- User requests task list or work breakdown
- User asks "what do I need to implement?"
- Implementation plan is complete and ready for execution
- Need to break down plan into executable tasks

**Trigger Keywords**: tasks, task list, work breakdown, implementation steps, what to do next, /tasks

**Prerequisites**:
- Feature specification exists (from /specify)
- Implementation plan exists (from /plan)
- Design artifacts exist (research.md, data-model.md, contracts/, quickstart.md)

## Procedure

### Step 1: Check Prerequisites

**Run prerequisite check script**:
```bash
.specify/scripts/bash/check-task-prerequisites.sh --json
```

**Parse JSON output** to extract:
- `FEATURE_DIR`: Directory containing all feature artifacts
- `AVAILABLE_DOCS`: List of available design documents

**Available documents may include**:
- plan.md (ALWAYS required)
- data-model.md (if entities defined)
- contracts/ (if APIs/interfaces defined)
- research.md (if technical research done)
- quickstart.md (if test scenarios defined)

**IMPORTANT**: Not all features have all documents. Generate tasks based on what's available.

### Step 2: Load and Analyze Design Artifacts

**Always read the implementation plan**:
```bash
Read: $FEATURE_DIR/plan.md
```
- Extract tech stack and libraries
- Understand implementation approach
- Identify architecture patterns

**Read data-model.md if exists**:
```bash
Read: $FEATURE_DIR/data-model.md
```
- Extract entity names
- Understand relationships
- Note any special requirements

**Read contracts/ directory if exists**:
```bash
Glob: $FEATURE_DIR/contracts/*.md
Read: [each contract file]
```
- Extract endpoint/interface names
- Understand request/response schemas
- Note error cases

**Read research.md if exists**:
```bash
Read: $FEATURE_DIR/research.md
```
- Understand technical decisions
- Note dependencies and libraries
- Understand patterns to follow

**Read quickstart.md if exists**:
```bash
Read: $FEATURE_DIR/quickstart.md
```
- Extract test scenarios
- Understand user stories
- Note integration test requirements

### Step 3: Load Task Template

**Read the task template**:
```bash
Read: .specify/templates/tasks-template.md
```

**Template provides structure** for:
- Task numbering (T001, T002, etc.)
- Task categories (Setup, Tests, Core, Integration, Polish)
- Parallel execution markers [P]
- Dependency tracking
- Progress tracking

### Step 4: Generate Tasks by Category

**Setup Tasks** (always first):
```
T001: [ ] Initialize project structure
T002: [ ] Install and configure dependencies [from research.md]
T003: [ ] Set up linting and formatting [P]
T004: [ ] Configure build system [P]
```

**Test Tasks** (test-first, marked [P] for parallelism):
```
For each contract file:
  T00X: [ ] Write contract test for [endpoint/interface] [P]

For each user story in quickstart.md:
  T00Y: [ ] Write integration test for [user story] [P]
```

**Core Implementation Tasks**:
```
For each entity in data-model.md:
  T00Z: [ ] Implement [Entity] model [P]

For each contract:
  T00A: [ ] Implement [endpoint/interface]
  (NOT parallel if multiple endpoints share same file)

For each service/module in plan:
  T00B: [ ] Implement [Service] logic
```

**Integration Tasks**:
```
T00C: [ ] Set up database connection (if database domain)
T00D: [ ] Configure middleware and error handling
T00E: [ ] Set up logging and observability
T00F: [ ] Integrate with external services (if any)
```

**Polish Tasks** (final, marked [P]):
```
T00G: [ ] Add unit tests for edge cases [P]
T00H: [ ] Performance optimization [P]
T00I: [ ] Documentation generation [P]
T00J: [ ] Code review and refactoring [P]
```

### Step 5: Apply Task Generation Rules

**Parallel Execution Rules**:
- **Mark [P]** if: Tasks work on different files
- **No [P]** if: Tasks modify same file (sequential required)

**Examples**:
```
✅ PARALLEL:
- T005: Write contract test for GET /users [P]
- T006: Write contract test for POST /users [P]
(Different test files)

❌ NOT PARALLEL:
- T010: Implement GET /users endpoint
- T011: Implement POST /users endpoint
(Same routes file)
```

**Dependency Ordering**:
1. Setup tasks first
2. Test tasks before implementation (TDD)
3. Models before services
4. Services before endpoints
5. Core before integration
6. Everything before polish

### Step 6: Write Tasks File

**Create task list**:
```bash
Write: $FEATURE_DIR/tasks.md
```

**Include in tasks.md**:
- Feature name and description
- Total task count
- Parallel execution guidance
- All tasks with numbers (T001, T002, etc.)
- Clear file paths for each task
- Dependency notes
- Progress tracking checkboxes

**Task format**:
```markdown
- [ ] T001: Task description
  - File: `path/to/file.ts`
  - Dependencies: None
  - Parallel: No

- [ ] T005: Write contract test for GET /users [P]
  - File: `tests/contracts/get-users.test.ts`
  - Dependencies: T001, T002
  - Parallel: Yes (with T006, T007)
```

### Step 7: Validate Task List

**Run task validation**:
```bash
.specify/scripts/bash/validate-tasks.sh --file $FEATURE_DIR/tasks.md
```

**Validation checks** (12 total):

**Task Quality** (6 checks):
- Has tasks (at least 1)
- Has numbered tasks (T001, T002, etc.)
- Has parallel tasks marked [P]
- Tasks have clear descriptions
- Tasks have file paths
- Tasks have dependency notes

**Constitutional Compliance** (3 checks):
- Has test tasks (Principle II: Test-First)
- Has contract tasks (Principle III: Contract-First)
- Tests before implementation (TDD ordering)

**Organization** (3 checks):
- Tasks ordered by dependencies
- Setup tasks first
- Polish tasks last

**Report validation results**:
- Overall score (X/12 checks passing)
- Total task count
- Parallel task count
- Readiness status

### Step 8: Domain Detection

**Run domain detection on tasks**:
```bash
.specify/scripts/bash/detect-phase-domain.sh --file $FEATURE_DIR/tasks.md
```

**Identify agents needed** for task execution:
- Specialist agents by domain
- Delegation strategy (single vs multi-agent)
- task-orchestrator if multi-domain

### Step 9: Report Completion

**Provide comprehensive summary**:
```
✅ Task List Generated

Task File: [path-to-tasks.md]

Task Statistics:
- Total Tasks: X
- Parallel Tasks: Y
- Sequential Tasks: Z
- Estimated Duration: [based on task count]

Validation Score: X/12
Status: [ready/needs-improvement]

Task Breakdown:
- Setup: A tasks
- Tests: B tasks (all parallel)
- Core Implementation: C tasks
- Integration: D tasks
- Polish: E tasks (all parallel)

Domains Detected: [list]
Suggested Agents: [list]
Delegation Strategy: [single-agent/multi-agent]

Constitutional Compliance:
✅ Test-First: Tests before implementation
✅ Contract-First: Contract tests included
✅ Dependency-Ordered: Correct task sequence

Parallel Execution Example:
  Run T005, T006, T007 together:
  - All write contract tests
  - Different files, no conflicts

Next Step: Execute tasks sequentially or delegate to specialized agents
```

## Constitutional Compliance

### Principle II: Test-First Development
- **ALL test tasks BEFORE implementation tasks**
- Contract tests first
- Integration tests early
- Unit tests for edge cases last
- No implementation without corresponding test

### Principle III: Contract-First Design
- **Contract test tasks for EACH contract file**
- Contract tests validate:
  - Request schema
  - Response schema
  - Error cases
- Contract tests marked [P] for parallel execution

### Principle X: Agent Delegation Protocol
- Tasks identify which agents/domains are needed
- Multi-domain features routed to task-orchestrator
- Single-domain features routed to specialist
- Domain detection guides delegation

## Examples

### Example 1: REST API Task Generation

**User Request**: "/tasks Generate task list for user authentication API"

**Available Artifacts**:
- plan.md: Express.js API, bcrypt, JWT
- data-model.md: User entity, Session entity
- contracts/: POST /api/register, POST /api/login, POST /api/logout
- quickstart.md: Registration scenario, Login scenario, Logout scenario

**Generated Tasks**:
```markdown
# User Authentication API - Tasks

Total: 18 tasks (8 parallel)

## Setup (4 tasks)
- [ ] T001: Initialize Express.js project structure
- [ ] T002: Install dependencies (express, bcrypt, jsonwebtoken, pg)
- [ ] T003: Set up ESLint and Prettier [P]
- [ ] T004: Configure TypeScript [P]

## Tests (6 tasks - all parallel)
- [ ] T005: Write contract test for POST /api/register [P]
- [ ] T006: Write contract test for POST /api/login [P]
- [ ] T007: Write contract test for POST /api/logout [P]
- [ ] T008: Write integration test for registration flow [P]
- [ ] T009: Write integration test for login flow [P]
- [ ] T010: Write integration test for logout flow [P]

## Core Implementation (5 tasks)
- [ ] T011: Implement User model
- [ ] T012: Implement Session model
- [ ] T013: Implement POST /api/register endpoint
- [ ] T014: Implement POST /api/login endpoint
- [ ] T015: Implement POST /api/logout endpoint

## Integration (2 tasks)
- [ ] T016: Set up PostgreSQL connection and migrations
- [ ] T017: Configure JWT middleware and error handling

## Polish (3 tasks - all parallel)
- [ ] T018: Add unit tests for password hashing [P]
- [ ] T019: Performance test for concurrent logins [P]
- [ ] T020: Generate API documentation [P]
```

**Validation**: 12/12 checks passing
**Domains**: backend, database, security
**Agents**: backend-architect, database-specialist, security-specialist
**Delegation**: multi-agent via task-orchestrator

### Example 2: React Component Task Generation

**User Request**: "/tasks Break down user profile card component"

**Available Artifacts**:
- plan.md: React 18, TypeScript, CSS Modules, Vitest
- data-model.md: UserProfile interface, Avatar interface
- contracts/: ProfileCard component props
- quickstart.md: Component rendering scenarios

**Generated Tasks**:
```markdown
# User Profile Card Component - Tasks

Total: 12 tasks (6 parallel)

## Setup (3 tasks)
- [ ] T001: Initialize React component structure
- [ ] T002: Install dependencies (react, typescript, vitest)
- [ ] T003: Set up Vitest and React Testing Library [P]

## Tests (4 tasks - all parallel)
- [ ] T004: Write component prop validation test [P]
- [ ] T005: Write rendering test with mock data [P]
- [ ] T006: Write interaction test (click, hover) [P]
- [ ] T007: Write accessibility test (ARIA, keyboard) [P]

## Core Implementation (3 tasks)
- [ ] T008: Implement ProfileCard component structure
- [ ] T009: Implement Avatar sub-component
- [ ] T010: Style components with CSS Modules

## Polish (2 tasks - parallel)
- [ ] T011: Add Storybook stories [P]
- [ ] T012: Component documentation [P]
```

**Validation**: 11/12 checks passing (no integration tasks needed)
**Domains**: frontend
**Agents**: frontend-specialist
**Delegation**: single-agent

## Agent Collaboration

### tasks-agent
**When to delegate**: Complex task breakdown, dependency analysis

**What they handle**: Creating task lists, identifying dependencies, task sequencing

### task-orchestrator
**When to delegate**: Multi-domain tasks (3+ domains)

**What they handle**: Coordinating multiple specialists to execute tasks

### Domain Specialists
**When to notify**: Report which specialists needed based on domains

**What they handle**: Executing tasks in their domain

## Validation

Verify the skill executed correctly:

- [ ] Prerequisite check executed and artifacts identified
- [ ] All available design artifacts read and analyzed
- [ ] Task template loaded
- [ ] Tasks generated in all categories (Setup, Tests, Core, Integration, Polish)
- [ ] Task generation rules applied (parallel markers, dependencies)
- [ ] Tasks ordered correctly (tests before implementation)
- [ ] tasks.md created with proper structure
- [ ] Task validation executed and reported
- [ ] Domain detection executed and reported
- [ ] Task statistics reported to user
- [ ] Suggested agents reported
- [ ] User notified task list is ready for execution

## Troubleshooting

### Issue: check-task-prerequisites.sh fails

**Cause**: Missing required artifacts (usually plan.md)

**Solution**:
- Verify plan.md exists in feature directory
- Run /plan first to generate implementation plan
- Check that feature directory structure is correct

### Issue: No test tasks generated

**Cause**: No contracts or quickstart.md found

**Solution**:
- Review plan.md for interfaces/APIs that need tests
- Create contract tests for internal module APIs
- Generate at least unit test tasks for core functions
- Update plan if feature truly has no external contracts

### Issue: All tasks marked sequential (no [P])

**Cause**: Tasks all modify same files or unclear file paths

**Solution**:
- Review task file paths
- Separate concerns into different files
- Test files can always be parallel
- Model files for different entities can be parallel

### Issue: Validation shows poor dependency ordering

**Cause**: Tasks not ordered by dependency hierarchy

**Solution**:
- Ensure setup tasks first
- Move test tasks before implementation
- Order by: models → services → endpoints → integration
- Put polish tasks last

### Issue: Task count very low (<10 tasks)

**Cause**: Tasks too broad, not granular enough

**Solution**:
- Break down large tasks into smaller steps
- One task per contract
- One task per entity
- One task per integration point
- Separate testing from implementation

## Notes

- Tasks should be immediately executable - specific enough for LLM to complete
- Each task should take ≤4 hours of work (break down if larger)
- Parallel tasks marked [P] can run concurrently (big efficiency gain)
- Test-first means tests MUST come before implementation in task order
- Not all features have all artifact types (adapt based on what's available)
- CLI tools may not have contracts/, simple libraries may not have data-model.md
- Task validation ensures constitutional compliance before execution
- Tasks are the final planning artifact - ready for implementation



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
  "skill": "sdd-tasks",
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

- **sdd-specification**: Step 1 (creates specification)
- **sdd-planning**: Step 2 (creates implementation plan)
- **sdd-tasks**: Step 3 (THIS SKILL - creates task list)
- **domain-detection**: Identifies agents needed for execution
- **constitutional-compliance**: Validates TDD and contract-first compliance
