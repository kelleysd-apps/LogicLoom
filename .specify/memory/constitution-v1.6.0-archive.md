# Specification-Driven Development Constitution

**Version**: 1.6.0
**Ratified**: 2025-11-06
**Last Amended**: 2025-11-30
**Status**: Active

---

## Preamble

This constitution establishes the foundational principles and development practices for specification-driven software development. It serves as the supreme authority for all development decisions, architectural choices, and process workflows within projects adopting this framework.

### Authority and Scope

This document governs:
- **Development Processes**: How features are specified, planned, and implemented
- **Quality Standards**: Minimum acceptable standards for code and documentation
- **Architectural Decisions**: Patterns and practices that must be followed
- **Workflow Requirements**: Mandatory gates and approval processes
- **Agent Delegation**: When and how to use specialized agents

All team members, contributors, and AI assistants must comply with these principles. Violations require explicit justification and documented approval.

---

## Part I: Core Immutable Principles

These three principles are the foundation of the framework and **CANNOT be amended** without replacing the entire constitutional framework.

### Principle I: Library-First Architecture (IMMUTABLE)

**Mandate**: Every feature MUST begin its existence as a standalone library.

**Requirements**:
- No feature shall be implemented directly within application code without first being abstracted into a reusable library component
- Libraries must be self-contained with their own tests, documentation, and clear boundaries
- Library interfaces must be designed for reusability beyond the immediate use case
- No "organizational" libraries—each must have a clear, singular purpose
- Libraries must expose a clean public API with versioned interfaces

**Rationale**: Library-first architecture enforces separation of concerns, enables code reuse, simplifies testing, and prevents monolithic coupling.

**Compliance Check**:
- [ ] Feature implemented as standalone library
- [ ] Library has its own test suite
- [ ] Library has README with usage examples
- [ ] Library has clear, singular purpose
- [ ] Library API is versioned

---

### Principle II: Test-First Development (IMMUTABLE - NON-NEGOTIABLE)

**Mandate**: Test-Driven Development (TDD) is mandatory for all code.

**Required Workflow**:
1. **Write tests** that define expected behavior
2. **Get user approval** on test scenarios
3. **Run tests** (they should fail initially)
4. **Implement** the minimum code to make tests pass
5. **Refactor** while keeping tests green

**Testing Requirements**:
- Every library must have unit tests with >80% code coverage
- Every integration point must have contract tests
- Every user-facing feature must have end-to-end tests
- Tests are living documentation and must be readable as such
- Test code follows the same quality standards as production code

**Rationale**: TDD prevents bugs, documents behavior, enables confident refactoring, and ensures code meets requirements.

**Compliance Check**:
- [ ] Tests written before implementation
- [ ] User approved test scenarios
- [ ] Tests initially fail (red)
- [ ] Implementation makes tests pass (green)
- [ ] Code coverage >80%

---

### Principle III: Contract-First Design (IMMUTABLE)

**Mandate**: All integration points must be defined by explicit contracts before implementation.

**Requirements**:
- Libraries communicate through well-defined contracts, not shared code
- All contracts must be versioned and backward compatible within major versions
- Contract changes require migration paths and deprecation notices
- Integration tests must verify contract compliance, not implementation details
- Mock implementations must be provided for testing consumers

**Contract Types**:
- **API Contracts**: Request/response schemas, error codes, headers
- **Event Contracts**: Message formats, topic names, delivery guarantees
- **Database Contracts**: Schema definitions, query interfaces, migrations
- **UI Contracts**: Component props, events, accessibility requirements

**Rationale**: Contract-first design enables independent development, prevents breaking changes, and documents integration boundaries.

**Compliance Check**:
- [ ] Contract defined before implementation
- [ ] Contract is versioned
- [ ] Integration tests verify contract
- [ ] Mock implementation provided
- [ ] Migration path documented for changes

---

## Part II: Quality and Safety Principles

These principles ensure code quality, reliability, and security.

### Principle IV: Idempotent Operations

**Mandate**: All operations should be safely repeatable without unintended side effects.

**Requirements**:
- Running the same operation multiple times produces the same result
- State mutations must be explicit and reversible
- Failure recovery must be automated where possible
- Partial failures must not leave inconsistent state
- All data modifications must support dry-run mode

**Examples**:
```bash
# Idempotent: Running multiple times is safe
./create-feature.sh my-feature  # Creates if not exists, skips if exists

# Non-Idempotent: Running multiple times causes errors
./create-feature.sh my-feature  # Second run fails with "already exists"
```

**Rationale**: Idempotency enables safe retry logic, simplifies error recovery, and prevents data corruption.

**Compliance Check**:
- [ ] Operation safe to run multiple times
- [ ] State changes are explicit
- [ ] Dry-run mode available
- [ ] Cleanup/rollback supported
- [ ] Error handling prevents partial state

---

### Principle V: Progressive Enhancement

**Mandate**: Start with the simplest solution that could possibly work. Add complexity only when proven necessary.

**Requirements**:
- YAGNI (You Aren't Gonna Need It) is the default position
- Premature optimization is forbidden
- Features must be feature-flagged and incrementally rollable
- Complexity requires justification with real use cases
- Always prefer simple, obvious code over clever code

**Decision Framework**:
1. Will this feature be used in the next sprint? → If no, don't build it
2. Is this optimization measured and necessary? → If no, keep it simple
3. Can this be solved with existing libraries? → If yes, use them

**Rationale**: Premature complexity increases bugs, maintenance burden, and onboarding time while providing no immediate value.

**Compliance Check**:
- [ ] Simplest solution attempted first
- [ ] Complexity justified with use cases
- [ ] Feature flags used for new features
- [ ] No premature optimization
- [ ] Code is readable and obvious

---

### Principle VI: Git Operation Approval (CRITICAL - NON-NEGOTIABLE)

**Mandate**: NO automatic git operations without explicit user approval.

**Requirements**:
- **Branch Operations**: MUST request approval before create/switch/delete
- **Commits**: MUST request approval with preview of changes
- **Push/Pull**: MUST request approval before remote operations
- **History Modifications**: MUST request approval for rebase/amend/reset
- **Automated Tools**: Scripts and agents MUST NOT perform git operations autonomously

**Approval Process**:
```bash
# Example from create-new-feature.sh
if ! request_git_approval "Branch Creation" "Create new branch: $BRANCH_NAME"; then
    echo "Operation cancelled by user"
    exit 1
fi
git checkout -b "$BRANCH_NAME"
```

**Exceptions**: NONE. This principle has no exceptions.

**Rationale**: User must maintain full control over version control. Autonomous git operations risk data loss, unintended commits, and unauthorized code changes.

**Compliance Check**:
- [ ] All git operations have approval prompts
- [ ] User can cancel any operation
- [ ] Approval explains what will happen
- [ ] Scripts use request_git_approval() function
- [ ] No git commands without preceding approval

**Enforcement**: Sanitization audit checks all scripts for unapproved git operations.

---

### Principle VII: Observability and Structured Logging

**Mandate**: Every operation must emit structured logs and metrics for debugging, monitoring, and audit trails.

**Requirements**:
- All operations must support structured logging with configurable verbosity
- Logs must use JSON format for machine parseability
- All operations must emit metrics about performance and errors
- Distributed tracing must be supported for request flows
- Health checks must be exposed for monitoring
- Debug modes must provide detailed operational insights

**Structured Log Format**:
```json
{
  "timestamp": "2025-11-06T10:30:00Z",
  "level": "INFO",
  "operation": "create-feature",
  "user_approved": true,
  "tools": ["Write", "Bash"],
  "outcome": "success",
  "constitutional_compliance": true,
  "duration_ms": 1250,
  "metadata": {
    "feature_number": "005",
    "branch_name": "005-user-authentication"
  }
}
```

**Audit Trail Requirements**:
- All operations performed (who, what, when, why)
- Constitutional compliance checks
- Approval decisions (user approved/denied)
- Errors and resolutions
- Agent invocations and handoffs

**Rationale**: Observability enables debugging, performance monitoring, security audits, and operational insights.

**Compliance Check**:
- [ ] Structured logging implemented
- [ ] JSON format for logs
- [ ] Metrics emitted
- [ ] Audit trail maintained
- [ ] Debug mode available

---

### Principle VIII: Documentation Synchronization

**Mandate**: Documentation must stay synchronized with code changes at all times.

**Requirements**:
- Documentation lives with code and is part of the definition of "done"
- Every library must have README with purpose, usage, and examples
- Every public API must have comprehensive docstrings
- Every architectural decision must be recorded in ADRs
- Every complex algorithm must have explanatory comments
- Documentation must be verified as part of CI/CD

**Synchronization Process**:
When code changes:
1. Update relevant documentation files
2. Update cross-references
3. Check for dependent documents (use `constitution_update_checklist.md`)
4. Validate examples and code snippets
5. Update timestamps/versions

**Key Documentation Types**:
- **Constitutional**: constitution.md, constitution_update_checklist.md
- **Instructions**: CLAUDE.md, AGENTS.md, README.md
- **Policies**: .docs/policies/*.md
- **Specifications**: specs/###-feature-name/*.md
- **Agents**: .claude/agents/**/*.md

**Rationale**: Documentation drift creates confusion, onboarding friction, and incorrect implementations.

**Compliance Check**:
- [ ] Code changes include doc updates
- [ ] Cross-references validated
- [ ] Examples tested and accurate
- [ ] Versions/timestamps updated
- [ ] CI/CD verifies docs

---

### Principle IX: Dependency Management

**Mandate**: All dependencies must be explicitly declared, version-pinned, and regularly audited.

**Requirements**:
- Development environments and tools must be explicitly defined per project
- No implicit assumptions about available tools or frameworks
- All dependencies must be declared in package.json / requirements.txt / etc.
- All dependencies must be version-pinned (exact versions, not ranges)
- Breaking changes to dependencies require team approval
- Dependencies must be regularly audited for vulnerabilities
- Unused dependencies must be removed

**Dependency Approval Process**:
1. Justify why dependency is needed
2. Evaluate alternatives (can existing deps solve this?)
3. Check license compatibility
4. Check security audit history
5. Pin exact version
6. Document in dependency rationale log

**Rationale**: Explicit dependency management prevents supply chain attacks, version conflicts, and unpredictable builds.

**Compliance Check**:
- [ ] All dependencies declared
- [ ] Versions pinned (exact, not range)
- [ ] Licenses verified
- [ ] Security audit clean
- [ ] Unused dependencies removed

---

## Part III: Workflow and Delegation Principles

These principles govern development workflows and agent coordination.

### Principle X: Agent Delegation Protocol (CRITICAL)

**Mandate**: Specialized work MUST be delegated to specialized agents. General-purpose agents MUST NOT execute domain-specific work directly.

**Work Session Initiation Protocol (MANDATORY for EVERY task)**:

**Step 1: READ CONSTITUTION**
- First action of any session, even for "simple" tasks
- No exceptions: file reading, status checks, answering questions ALL require reading constitution first

**Step 2: ANALYZE TASK DOMAIN**
- Use automated tools: `detect-phase-domain.sh`, `constitutional-check.sh`
- Manual scan for trigger keywords (see `agent-collaboration-triggers.md`)
- Keywords: test, UI, database, security, frontend, backend, API, schema, etc.

**Step 3: DELEGATION DECISION**
- IF domain keywords matched → STOP, delegate to specialized agent
- IF no keywords → Verify by reading files, document why no delegation
- NEVER execute specialized work directly

**Step 4: EXECUTION**
- ONLY after steps 1-3 complete
- Execute directly OR invoke specialized agent via Task tool

**Delegation Triggers** (see `agent-collaboration-triggers.md` for full list):

| Domain | Keywords | Agent |
|--------|----------|-------|
| Frontend | UI, component, React, responsive, design | frontend-specialist |
| Backend | API, endpoint, service, server, auth | backend-architect |
| Database | schema, migration, query, RLS, index | database-specialist |
| Testing | test, E2E, integration, contract, QA | testing-specialist |
| Security | auth, encryption, XSS, SQL injection | security-specialist |
| Performance | optimization, caching, benchmark | performance-engineer |
| DevOps | deploy, CI/CD, Docker, infrastructure | devops-engineer |
| Specification | spec, requirements, user stories | specification-agent |
| Tasks | task list, dependency, implementation | tasks-agent |
| Orchestration | multi-domain, complex workflow | task-orchestrator |

**Multi-Agent Coordination**:
- Features requiring 2+ domains → Use task-orchestrator
- task-orchestrator manages context handoffs, dependencies, and quality gates
- Each agent completes their domain work, passes context to next agent

**Rationale**: Specialized agents have domain expertise, proper tooling, and focused context that general-purpose agents lack.

**Compliance Check**:
- [ ] Constitution read at session start
- [ ] Task domain analyzed
- [ ] Delegation decision documented
- [ ] Appropriate agent invoked for specialized work
- [ ] No direct execution of specialized tasks

**Enforcement**: constitutional-check.sh verifies delegation protocol compliance.

---

### Principle XI: Input Validation and Output Sanitization

**Mandate**: Security is not optional. All inputs must be validated and sanitized. All outputs must be properly escaped.

**Requirements**:
- All user inputs must be validated against expected schemas
- All external data must be sanitized before use
- All outputs must be escaped for their context (HTML, SQL, shell, etc.)
- Secrets must NEVER be logged or committed
- Authentication and authorization must be enforced at every boundary
- Dependencies must be regularly audited for vulnerabilities

**Input Validation Pattern**:
```typescript
// Always validate user input
function createFeature(input: unknown) {
  const validated = FeatureInputSchema.parse(input); // Throws if invalid
  return createFeatureFromValidated(validated);
}
```

**Output Sanitization Pattern**:
```typescript
// Always escape output for context
const safeHTML = escapeHTML(userContent);
const safeSQL = parameterizedQuery(userInput);
const safeShell = escapeShellArg(userPath);
```

**Secrets Management**:
- Use environment variables or secret managers
- Never commit secrets to git
- Never log secrets (even in debug mode)
- Rotate secrets regularly
- Use least-privilege access

**Rationale**: Input validation prevents injection attacks, data corruption, and security breaches.

**Compliance Check**:
- [ ] All inputs validated
- [ ] All outputs sanitized/escaped
- [ ] No secrets in logs
- [ ] No secrets in git
- [ ] Authentication enforced

---

### Principle XII: Design System Compliance

**Mandate**: All user-facing components must comply with the project's design system for consistency and accessibility.

**Requirements**:
- Project must define a design system (color palette, typography, spacing, components)
- All UI components must use design system tokens/variables
- Design system must include accessibility standards (WCAG 2.1 AA minimum)
- Components must be responsive and mobile-friendly
- Design system must be documented with examples

**Design System Components**:
1. **Color Palette**: Define primary, secondary, accent, and semantic colors
2. **Typography**: Define font families, sizes, weights, line heights
3. **Spacing**: Define consistent spacing scale (4px, 8px, 16px, etc.)
4. **Component Library**: Reusable components (buttons, inputs, cards, etc.)
5. **Accessibility**: Color contrast, keyboard navigation, screen reader support

**Example Design System Structure**:
```typescript
// theme.ts
export const theme = {
  colors: {
    primary: '#your-primary-color',
    secondary: '#your-secondary-color',
    accent: '#your-accent-color',
  },
  typography: {
    fontFamily: 'Your Font',
    sizes: { sm: 14, md: 16, lg: 20 },
  },
  spacing: {
    xs: 4, sm: 8, md: 16, lg: 24, xl: 32,
  },
};
```

**Accessibility Requirements**:
- Color contrast ratio ≥ 4.5:1 for normal text
- Keyboard navigation supported
- Screen reader labels on interactive elements
- Focus indicators visible
- Error messages descriptive

**Rationale**: Design system compliance ensures consistent user experience, reduces design debt, and improves accessibility.

**Compliance Check**:
- [ ] Design system defined
- [ ] Components use design tokens
- [ ] Accessibility standards met (WCAG 2.1 AA)
- [ ] Responsive design implemented
- [ ] Design system documented

**Note**: Specific design system choices (for example: dark neumorphism, Material Design, Tailwind) are project-specific. This principle requires *a* design system, not *a specific* design system.

---

### Principle XIII: Feature Access Control

**Mandate**: Features with access restrictions must be enforced at BOTH backend and frontend layers.

**Dual-Layer Enforcement**:

**Backend Enforcement (MANDATORY)**:
- Database row-level security (RLS) policies
- API authorization checks before data access
- Access tier/role validated at data layer
- Backend is the source of truth for access control

**Frontend Enforcement (MANDATORY)**:
- UI indicators for restricted features
- Upgrade/access request prompts
- Graceful degradation for limited access
- Clear messaging about access requirements

**Access Control Pattern**:

**Backend (PostgreSQL RLS Example)**:
```sql
-- Enforce access control at database level
CREATE POLICY "access_control"
ON resources FOR INSERT
TO authenticated
WITH CHECK (
  (SELECT access_tier FROM user_profiles WHERE id = auth.uid()) IN ('premium', 'enterprise')
  OR
  (SELECT COUNT(*) FROM resources WHERE user_id = auth.uid()) < tier_limit(
    (SELECT access_tier FROM user_profiles WHERE id = auth.uid())
  )
);
```

**Frontend (React Example)**:
```typescript
const FeatureGate = ({ requiredTier, children }) => {
  const { userTier } = useAuth();

  if (!hasAccess(userTier, requiredTier)) {
    return (
      <AccessDeniedBanner
        message={`This feature requires ${requiredTier} access`}
        upgradeAction={() => navigate('/upgrade')}
      />
    );
  }

  return <>{children}</>;
};
```

**Access Tier Examples**:
- **Free Tier**: Basic features with limitations
- **Premium Tier**: Enhanced features and higher limits
- **Enterprise Tier**: Full feature set and unlimited access

**Rationale**: Dual-layer enforcement prevents circumvention via API calls while providing good UX with frontend indicators.

**Compliance Check**:
- [ ] Backend enforcement implemented (RLS/API)
- [ ] Frontend access indicators shown
- [ ] Access restrictions tested
- [ ] Upgrade/access paths clear
- [ ] Edge cases handled (tier transitions)

**Note**: Specific tier names and pricing are project-specific. This principle requires *access control patterns*, not *specific tiers*.

---

### Principle XIV: AI Model Selection Protocol

**Mandate**: Use appropriate AI models for tasks based on complexity, quality requirements, and cost considerations.

**Default Model**: Claude Opus 4.5 (RECOMMENDED)
- Model ID: `claude-opus-4-5-20251101`
- Use for: All specialized agent tasks by default
- Cost: $15/MTok input, $75/MTok output
- Context: 200K tokens
- Rationale: Highest capability model ensures best quality output for spec-driven development

**Fallback Model**: Claude Sonnet 4.5
- Model ID: `claude-sonnet-4-5-20250929`
- Cost: $3/MTok input, $15/MTok output (5x cheaper)
- Context: 200K tokens
- Use for: Cost optimization, high-volume tasks, when Opus unavailable

**Quick Tasks Model**: Claude Haiku
- Model ID: `claude-haiku` (latest)
- Cost: Lowest tier
- Use for: Simple file operations, formatting, quick lookups

**Model Selection Hierarchy**:
```
┌─────────────────────────────────────────────────────────────────┐
│                     MODEL SELECTION GUIDE                       │
├─────────────────────────────────────────────────────────────────┤
│  OPUS 4.5 (Default)                                             │
│  ├─ Specialized agent work (all departments)                    │
│  ├─ Architecture and design decisions                           │
│  ├─ Security reviews and audits                                 │
│  ├─ Complex multi-step reasoning                                │
│  ├─ Novel problem solving                                       │
│  └─ Production-critical implementations                         │
├─────────────────────────────────────────────────────────────────┤
│  SONNET 4.5 (Fallback)                                          │
│  ├─ High-volume repetitive tasks                                │
│  ├─ Cost-sensitive operations                                   │
│  ├─ When Opus quota exceeded                                    │
│  └─ Parallel task execution (cost optimization)                 │
├─────────────────────────────────────────────────────────────────┤
│  HAIKU (Quick Tasks)                                            │
│  ├─ Simple file reads/searches                                  │
│  ├─ Formatting and cleanup                                      │
│  ├─ Quick information lookups                                   │
│  └─ Status checks and validation                                │
└─────────────────────────────────────────────────────────────────┘
```

**When to Use Sonnet Instead of Opus**:
1. Budget constraints require cost optimization
2. Task is well-defined with clear patterns (no novelty)
3. High parallelization needed (cost multiplier consideration)
4. Opus quota/rate limits reached
5. User explicitly requests cost-efficient model

**Decision Tree**:
```
Task Type                    → Model        → Rationale
Specialized agent work       → Opus 4.5     → Maximum capability
Architecture design          → Opus 4.5     → Critical decisions
Security review              → Opus 4.5     → Safety-critical
Novel research               → Opus 4.5     → Deep reasoning needed
Standard coding (budget)     → Sonnet 4.5   → Cost optimization
Routine analysis             → Sonnet 4.5   → Sufficient capability
High-volume parallel tasks   → Sonnet 4.5   → Cost efficiency
Simple file operations       → Haiku        → Speed over depth
Quick lookups                → Haiku        → Minimal reasoning needed
```

**Documentation Requirements**:
- Log model selection in agent configurations
- Document when using non-default model (Sonnet/Haiku) and why
- Track costs for budget monitoring (future enhancement)

**Rationale**: Quality-first approach. Opus 4.5 provides best results for specification-driven development where accuracy and reasoning depth matter most.

**Compliance Check**:
- [ ] Opus 4.5 used by default for agent tasks
- [ ] Sonnet/Haiku usage justified (cost, volume, simplicity)
- [ ] Model selection documented in agent configs
- [ ] Non-default model usage logged with reason

---

### Principle XV: File and Folder Organization

**Mandate**: All file creation and folder management must follow established structure and naming conventions.

**Core Rules**:
1. **Verify Before Create**: Always check if parent directory exists before creating files
2. **Edit Over Create**: Prefer modifying existing files over creating new ones
3. **Templates First**: Use templates from `.specify/templates/` when available
4. **Absolute Paths**: Always use absolute paths from repository root
5. **Convention Compliance**: Follow naming conventions for each content type

**Pre-Creation Checklist** (MANDATORY):
```
[ ] Is this file necessary? (Can existing file be modified?)
[ ] Does the parent directory exist?
[ ] Does a file with this name already exist?
[ ] Does this follow naming conventions?
[ ] Is there a template for this file type?
[ ] Am I using absolute paths from repo root?
```

**Directory Structure** (SSOT):
```
.claude/agents/[dept]/          # Agent definitions
.claude/skills/[category]/      # Skill definitions
.claude/commands/               # Slash commands
.docs/agents/[dept]/[agent]/    # Agent memory
.docs/policies/                 # Framework policies
.specify/templates/             # Document templates
specs/###-[feature]/            # Feature specifications
src/                            # Source code
tests/                          # Test files
```

**Naming Conventions**:
| Type | Pattern | Example |
|------|---------|---------|
| Agent | `[role]-[function].md` | `backend-architect.md` |
| Skill folder | `[skill-name]/` | `domain-detection/` |
| Skill file | `SKILL.md` | `SKILL.md` |
| Policy | `[topic]-policy.md` | `testing-policy.md` |
| Agent memory | `[agent]-[type].md` | `planning-agent-context.md` |
| Feature dir | `###-[name]/` | `001-user-auth/` |

**Prohibited Actions**:
- Creating files without checking existence first
- Creating arbitrary directory structures outside established locations
- Using generic names (README.md) in agent memory directories
- Creating documentation files proactively without request
- Duplicating content in new files instead of editing existing

**Enforcement**:
- Skill: `.claude/skills/validation/file-organization/SKILL.md`
- Policy: `.docs/policies/file-structure-policy.md`
- Naming: `.docs/policies/agent-file-naming-convention.md`

**Rationale**: Consistent file organization enables discoverability, maintainability, and scalability as projects grow.

**Compliance Check**:
- [ ] Parent directory verified before file creation
- [ ] Existing files checked before creating new ones
- [ ] Naming conventions followed
- [ ] Templates used when available
- [ ] Absolute paths used

---

## Part IV: Development Workflow

### Quality Gates

Before any code can be merged:
- [ ] All tests must pass (unit, integration, e2e)
- [ ] Code coverage must meet minimum threshold (80%)
- [ ] Linting and formatting checks must pass
- [ ] Security scanning must show no critical issues
- [ ] Documentation must be updated
- [ ] Constitutional compliance verified

### Review Requirements

- Every PR requires at least one approval
- Authors cannot approve their own PRs
- Architectural changes require team consensus
- Breaking changes require migration plan with rollback procedure
- Performance impacts require benchmarks

### Branch Standards

- Feature branches follow pattern: `###-feature-name` (when user approves)
- Commits must be atomic with clear, descriptive messages
- Force pushes forbidden on main/master branches
- All changes require pull request review
- Squash merging preferred for feature branches

### Task Management (SSOT Architecture)

The framework uses a **Single Source of Truth (SSOT)** architecture for task management:

**Three-Level Hierarchy**:
```
┌─────────────────────────────────────────────────────────────────┐
│ LEVEL 1: PROJECT TASKS (specs/###-feature/tasks.md)             │
│ • Generated by /tasks command                                   │
│ • Persists in version control                                   │
│ • Full implementation checklist with dependencies               │
│ • Source of truth for feature scope                             │
├─────────────────────────────────────────────────────────────────┤
│ LEVEL 2: SESSION TASKS (TodoWrite tool)                         │
│ • Real-time tracking within Claude Code session                 │
│ • Derived from project tasks                                    │
│ • ONE task in_progress at a time                                │
│ • Mark completed IMMEDIATELY                                    │
├─────────────────────────────────────────────────────────────────┤
│ LEVEL 3: AGENT HISTORY (.docs/agents/*/decisions/tasks/)        │
│ • Completion records and decisions                              │
│ • Cross-session continuity                                      │
│ • Audit trail for agent work                                    │
└─────────────────────────────────────────────────────────────────┘
```

**Task Management Rules**:
1. Project tasks (`tasks.md`) are the authoritative source
2. Session tasks (TodoWrite) track active work
3. Only ONE task should be `in_progress` at any time
4. Mark tasks `completed` IMMEDIATELY when done
5. Sync completions back to `tasks.md`
6. Use `/finalize` to validate all tasks before commit

**TodoWrite Best Practices**:
- Use for tasks requiring 3+ steps
- Keep focused (3-10 items max)
- Update frequently for user visibility
- Derive from project-level tasks.md

**Policy Reference**: `.docs/policies/todo-architecture-policy.md`

---

## Part IV-B: Agent Skills and Progressive Disclosure

### Skills vs Agents: Complementary Systems

The SDD Framework employs a **hybrid approach** combining agents and skills:

**Agents** (Delegation Layer):
- **Purpose**: Orchestration, delegation, and multi-agent coordination
- **When**: Specialized work requiring autonomous decision-making
- **How**: Use Task tool to invoke specialized agents
- **Example**: task-orchestrator coordinates multiple specialists

**Skills** (Capability Layer):
- **Purpose**: Procedural "how-to" knowledge and step-by-step guidance
- **When**: Reusable procedures, workflows, or validation checks
- **How**: Claude loads skills dynamically using progressive disclosure
- **Example**: sdd-specification provides /specify command procedure

### Agent Skills Requirements

All skills must comply with:

1. **Constitutional Alignment**: Skills must reference applicable constitutional principles
2. **Agent Collaboration**: Skills must specify when to delegate to agents (Principle X)
3. **Progressive Disclosure**: Load information in layers (metadata → instructions → supporting files)
4. **Git Safety**: Skills must never perform autonomous git operations (Principle VI)
5. **Tool Restrictions**: Use `allowed-tools` YAML field to enforce least privilege

### Skill Structure

```
.claude/skills/category/skill-name/
├── SKILL.md          # Required: Instructions + YAML frontmatter
├── reference.md      # Optional: Detailed documentation
├── examples.md       # Optional: Usage examples
└── scripts/          # Optional: Executable utilities
```

**Required SKILL.md Frontmatter**:
```yaml
---
name: skill-name
description: |
  What the skill does and when to use it (max 1024 chars).
  Include trigger conditions and expected outcomes.
allowed-tools: Read, Write, Bash  # Optional: restricts tool access
---
```

### Skill Categories

1. **sdd-workflow/** - Core SDD methodology (specification, planning, tasks)
2. **validation/** - Quality gates and compliance (constitutional-compliance, domain-detection)
3. **technical/** - Domain-specific procedures (api-contract-design, test-first-development)
4. **integration/** - External system integrations (mcp-server-integration)

### Skills Decision Tree

```
Need procedural guidance?
├─ YES: Activate SKILL
│  └─ Self-contained "how-to" with steps
└─ NO: Need delegation/orchestration?
   ├─ YES: Invoke AGENT
   │  └─ Autonomous specialist work
   └─ NO: Execute directly
```

### Core Skills

**Priority 1 (SDD Workflow)**:
- `sdd-specification`: /specify command procedure
- `sdd-planning`: /plan command procedure
- `sdd-tasks`: /tasks command procedure

**Priority 2 (Validation)**:
- `constitutional-compliance`: Validate 15 principles
- `domain-detection`: Identify domains and suggest agents

**When to Use Skills vs Agents**:
- **Use Skill**: Need step-by-step procedure guidance
- **Use Agent**: Need specialized work executed autonomously
- **Use Both**: Agent uses skill for procedural guidance
- **Use Orchestrator**: Multi-domain work needs coordination

### Benefits of Hybrid Approach

| Benefit | Impact |
|---------|--------|
| **Context Efficiency** | 30-50% reduction in tokens |
| **User Extensibility** | Users add custom skills without framework mods |
| **Better Separation** | Agents delegate, skills guide procedures |
| **Constitutional Enforcement** | Dual-layer validation (agents + skills) |
| **Knowledge Sharing** | Skills capture procedural knowledge |

### Skills Compliance Requirements

- Skills MUST reference constitutional principles they enforce
- Skills MUST specify agent collaboration points
- Skills MUST NOT perform autonomous git operations
- Skills MUST use tool restrictions appropriately
- Skills MUST provide validation steps

---

## Part V: Exceptions and Amendments

### Constitutional Authority

This constitution represents the team's shared agreement on development practices. Violations require explicit justification and documented team approval. Temporary exceptions must have expiration dates and remediation plans. Permanent changes require constitutional amendment.

### Amendment Process

1. **Propose Change**: Submit proposal with rationale and impact analysis
2. **Impact Analysis**: Identify affected documents, workflows, and agents
3. **Team Discussion**: Build consensus on proposed change
4. **Trial Period**: For significant changes, trial for defined period
5. **Formal Vote**: Adopt or reject amendment
6. **Documentation**: Update constitution and all dependent documents
7. **MANDATORY**: Follow `.specify/memory/constitution_update_checklist.md`

### Immutable Principles

Principles I, II, and III (Library-First, Test-First, Contract-First) are immutable and cannot be amended without replacing the entire constitutional framework with a new governance model.

### Enforcement

- Constitution compliance is part of code review
- Violations block merging until resolved
- Patterns of violation trigger team discussion
- Good faith efforts to comply are expected
- Education preferred over punishment
- Automated checks via `constitutional-check.sh`

---

## Part VI: Compliance Verification

### Automated Checks

Run before commits, PRs, and releases:
```bash
# Check constitutional compliance
./.specify/scripts/bash/constitutional-check.sh

# Check sanitization (no project-specific elements)
./.specify/scripts/bash/sanitization-audit.sh
```

### Manual Review Checklist

Before declaring work complete:
- [ ] All 15 principles reviewed for applicability
- [ ] Work Session Initiation Protocol followed
- [ ] Appropriate agent(s) delegated to
- [ ] Git operations approved by user
- [ ] Tests written first, then implementation
- [ ] Documentation synchronized with code
- [ ] Design system compliance verified (if UI work)
- [ ] Access control enforced (if restricted features)

---

**END OF CONSTITUTION**

**Version**: 1.6.0
**Ratified**: 2025-11-06
**Total Principles**: 15
**Immutable Principles**: 3 (I, II, III)
**Critical Principles**: 2 (VI, X)
**Lines**: 950+ (expanded from 100 in v1.0.0)

**Project Customization**: Use `/initialize-project` command after PRD completion to apply project-specific customizations to this constitution automatically.

For amendment procedures, see: `.specify/memory/constitution_update_checklist.md`
For agent delegation details, see: `.specify/memory/agent-collaboration-triggers.md`
For compliance checking, see: `.specify/scripts/bash/constitutional-check.sh`
