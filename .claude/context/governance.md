# Governance Context Module
<!-- Auto-generated from CLAUDE.md - Plugin-First Architecture v4.1 -->
<!-- Module: Constitutional principles, git operations, compliance, dangerous commands -->

## Constitutional Foundation

**The constitution at `.logic-loom/memory/constitution.md` is the SINGLE SOURCE OF TRUTH.**

The constitution (v3.2.0) contains **16 enforceable principles**:
- **3 Immutable Principles** (I-III): Library-First, Test-First, Contract-First
- **6 Quality & Safety Principles** (IV-IX): Idempotency, Progressive Enhancement, Git Approval, Observability, Documentation Sync, Dependency Management
- **7 Workflow & Delegation Principles** (X-XVI): Delegation & Context Isolation, Input Validation, Design System, Access Control, AI Model Selection, File Organization, Plugin-First Architecture

The constitution governs:
- Core development principles and rules
- Workflow requirements and gates
- Quality standards and constraints
- All architectural decisions
- Delegation and context-isolation protocol
- Plugin-first architecture enforcement

---

## Hook-Enforced Governance (No Recited Ceremony)

Governance is the **core** of LogicLoom and is enforced automatically by hooks.
There is no manual message pre-flight recitation or compliance summary to print
on each message. The `UserPromptSubmit` preflight hook performs domain detection
and delegation recommendations; the pre-command guard gates dangerous and git
operations.

Verbosity is set by `LOOM_GOVERNANCE_MODE` in
`.logic-loom/config/governance.conf`:

| Mode | Behavior |
|------|----------|
| **lean** (default) | Hooks enforce silently; hints injected without ceremony |
| **strict** | Verbose compliance reporting and stricter gating prompts |

---

## Critical Principles (Memorize These)

| Principle | Name | Key Rule |
|-----------|------|----------|
| **II** | Test-First | Write tests BEFORE implementation |
| **VI** | Git Approval | NEVER auto-commit, ALWAYS ask user |
| **X** | Delegation & Context Isolation | Specialized work → specialists or `/swarm`; isolate worker context |
| **XVI** | Plugin-First | All capabilities as installable plugins |

---

## All 16 Constitutional Principles

### I. Library-First Architecture

**Rule**: Every feature must begin as a standalone library

**Rationale**: Ensures modularity, testability, and reusability

**Enforcement**:
- All features implemented as libraries in `src/lib/` or `lib/`
- Libraries must be framework-agnostic when possible
- Integration code in separate adapters/wrappers

**Exceptions**: None (immutable principle)

**Validation**: Check feature structure in plan.md and implementation

---

### II. Test-First Development (TDD)

**Rule**: Write tests → Get approval → Tests fail → Implement → Refactor

**Rationale**: Ensures quality, prevents regressions, validates requirements

**Workflow**:
1. Write tests based on contracts and acceptance criteria
2. Get user approval for test strategy
3. Verify tests fail (red)
4. Implement feature to pass tests (green)
5. Refactor for quality (refactor)

**Quality Gates**:
- Test coverage ≥80% (Principle II)
- All tests pass before merge
- Contract tests for all API endpoints
- Integration tests for user stories

**Enforcement**: `/finalize` command validates test coverage

**Exceptions**: Must be documented with justification

---

### III. Contract-First Design

**Rule**: Define contracts before implementation

**Rationale**: Establishes clear interfaces, enables parallel development, supports API versioning

**Workflow**:
1. Design API contracts in `contracts/` (OpenAPI/GraphQL schemas)
2. Generate contract tests from schemas
3. Implement to satisfy contracts
4. Validate with contract tests

**Enforcement**: `/plan` command generates contracts before tasks

**Exceptions**: Internal-only functions (must be documented)

---

### IV. Idempotent Operations

**Rule**: All operations must be safely repeatable

**Rationale**: Enables retries, reduces failure impact, supports automation

**Requirements**:
- Database migrations can run multiple times safely
- API endpoints handle duplicate requests
- Scripts check state before modifying
- File operations verify before overwriting

**Example**:
```bash
# Good: Checks before creating
if [ ! -d "$DIR" ]; then
  mkdir -p "$DIR"
fi

# Bad: Fails if already exists
mkdir "$DIR"
```

**Enforcement**: Code review, integration testing

---

### V. Progressive Enhancement

**Rule**: Start simple, add complexity only when proven necessary

**Rationale**: Prevents over-engineering, maintains velocity, reduces technical debt

**Requirements**:
- Start with simplest solution
- Document justification for added complexity
- Prefer established patterns over novel solutions
- Refactor when complexity proven necessary

**Enforcement**: Code review, architecture review

---

### VI. Git Operation Approval (CRITICAL)

**Rule**: NEVER automatic Git operations without user approval

**Scope**: All git commands including:
- Branch creation, switching, or deletion
- Commits and commit messages
- Pushes, pulls, and merges
- Any modifications to Git history (rebase, reset, amend)

**Workflow**:
1. Always ask the user for explicit approval first
2. For branch creation, ask how they want it formatted/named
3. Never assume permission for Git operations
4. SDD functions and scripts must not perform Git operations autonomously

**Quality Validation**: The `/finalize` command validates compliance but NEVER executes git commands. It provides a report and suggests commands for manual execution.

**Script Compliance**: All bash scripts use `request_git_approval()` function from `common.sh`

**Violations**: Immediate stop, violation acknowledgment, correction required

**Enforcement**: Pre-command hook at `.claude/hooks/guard-dangerous-commands.sh`

---

### VII. Observability

**Rule**: Structured logging and metrics required for all operations

**Rationale**: Enables debugging, monitoring, performance optimization

**Requirements**:
- Structured logging (JSON format preferred)
- Log levels: DEBUG, INFO, WARN, ERROR
- Request tracing for API calls
- Performance metrics collection
- Error tracking and alerting

**Enforcement**: Code review, logging validation

---

### VIII. Documentation Synchronization

**Rule**: Documentation must stay synchronized with code

**Rationale**: Prevents documentation drift, maintains knowledge accuracy

**Requirements**:
- Update CLAUDE.md when adding commands/workflows
- Update README.md when changing setup/deployment
- Update specs/ when requirements change
- Update API docs when contracts change
- Update agent context when capabilities change

**Files to Sync**:
- CLAUDE.md
- README.md
- specs/###/spec.md, plan.md, tasks.md
- API documentation
- Agent context files

**Enforcement**: `/finalize` command validates documentation sync

**Update Checklist**: `.logic-loom/memory/constitution_update_checklist.md`

---

### IX. Dependency Management

**Rule**: All dependencies explicitly declared and version-pinned

**Rationale**: Ensures reproducibility, prevents version conflicts

**Requirements**:
- Use package.json (Node.js) or requirements.txt (Python)
- Pin versions for production dependencies
- Document reason for each dependency
- Audit dependencies for security vulnerabilities
- Remove unused dependencies

**Enforcement**: Dependency audit, code review

---

### X. Delegation & Context Isolation

**Rule**: Specialized work delegated to specialists or `/swarm`; worker context kept isolated

**Rationale**: Ensures expert execution, maintains quality, enables parallel work, and prevents context bleed between concurrent workers

**How it works**:
- Domain keywords route to a domain brief (`get_domain_brief <domain>` from `common.sh`) or to `/swarm explore` / a team command
- Each delegated worker receives only the context it needs (isolated brief), not the full session
- 0 domains → execute directly; 1 domain → single brief; 2+ domains → `/swarm` or team orchestration

**Enforcement**: `UserPromptSubmit` preflight hook (domain detection + delegation recommendation) — no recited protocol required

**Reference**: `plugins/loom-governance/domain-briefs/<domain>.md`

---

### XI. Input Validation & Output Sanitization

**Rule**: All inputs validated, outputs sanitized

**Rationale**: Prevents security vulnerabilities, ensures data integrity

**Requirements**:
- Validate all user inputs (type, format, range, length)
- Sanitize outputs to prevent XSS
- Use parameterized queries to prevent SQL injection
- Validate file uploads (type, size, content)
- Escape data in templates

**Enforcement**: Security review, automated testing

---

### XII. Design System Compliance

**Rule**: UI components comply with project design system

**Rationale**: Ensures visual consistency, improves UX, reduces design debt

**Requirements**:
- Use design system components from `docs/design-system/`
- Follow color palette, typography, spacing guidelines
- Maintain accessibility standards (WCAG 2.1 AA)
- Consistent component behavior and interactions

**Reference**: `docs/design-system/design-system.md`

**Enforcement**: Design review, UI testing

---

### XIII. Feature Access Control

**Rule**: Dual-layer enforcement (backend + frontend)

**Rationale**: Security defense-in-depth, prevents unauthorized access

**Requirements**:
- Backend: Enforce authorization on all API endpoints
- Frontend: Hide UI elements based on permissions
- Row-level security (RLS) in database where applicable
- Role-based access control (RBAC) implementation
- Session management and token validation

**Enforcement**: Security review, penetration testing

---

### XIV. AI Model Selection

**Rule**: Use Opus 4.8 by default for all specialized agents

**Rationale**: Balances performance, cost, and quality

**Guidelines** (model IDs defined in `.logic-loom/config/models.conf`):
- **Opus 4.8** (flagship default): All specialized agents, architecture, security, complex reasoning
- **Sonnet** (fallback): Cost optimization, high-volume tasks, quota limits
- **Haiku** (cost-sensitive): Simple lookups, formatting, file operations

**Enforcement**: `.logic-loom/config/models.conf`, model selection documentation

---

### XV. File Organization

**Rule**: Verify before creating files, use proper naming conventions

**Rationale**: Maintains clean codebase structure and prevents file proliferation

**Requirements**:
- Verify parent directory exists before creating files
- Edit existing files over creating new ones
- Use templates from `.logic-loom/templates/` when available
- Always use absolute paths from repository root

**Enforcement**: File verification before create, code review

---

### XVI. Plugin-First Architecture

**Rule**: All framework capabilities must be organized as discrete installable plugins

**Rationale**: Ensures modularity, extensibility, and marketplace-ready distribution

**Requirements**:
- All new features implemented as plugins at `plugins/`
- Each plugin has `plugin.json` manifest, agents, skills, commands
- Plugin command bridge syncs commands to `.claude/commands/`
- Plugin governance validation via marketplace tools

**Enforcement**: Plugin validation, marketplace governance checks

---

## Git Operations (CRITICAL)

### Prohibited Automatic Operations

**NO automatic Git operations without user approval.** This includes:
- Branch creation, switching, or deletion
- Commits and commit messages
- Pushes, pulls, and merges
- Any modifications to Git history

### Required Approval Workflow

When Git operations are needed:
1. Always ask the user for explicit approval first
2. For branch creation, ask how they want it formatted/named
3. Never assume permission for Git operations
4. SDD functions and scripts must not perform Git operations autonomously

### Manual Git Command Execution

After `/finalize` validation passes, user manually executes:

```bash
# Add files to staging
git add <files>

# Commit with message
git commit -m "$(cat <<'EOF'
Feature description here

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"

# Push to remote
git push origin <branch-name>
```

### Git Commit Best Practices

When user requests commit:

1. **Run git commands in parallel** (if independent):
   ```bash
   git status    # See untracked files
   git diff      # See changes
   git log -5    # See recent commits
   ```

2. **Analyze changes** and draft commit message:
   - Summarize nature of changes (feature, fix, refactor, etc.)
   - Don't commit secrets (.env, credentials)
   - Use concise 1-2 sentence message focusing on "why"

3. **Execute git commands**:
   - Add relevant untracked files
   - Create commit with Co-Authored-By line
   - Run git status to verify success

4. **If commit fails** (pre-commit hook):
   - Fix the issue
   - Create a NEW commit (don't amend unless explicit user request)

### Git Safety Protocol

- **NEVER** update git config
- **NEVER** run destructive commands (push --force, hard reset) unless explicitly requested
- **NEVER** skip hooks (--no-verify, --no-gpg-sign) unless explicitly requested
- **NEVER** force push to main/master (warn user if requested)
- **Avoid** git commit --amend (only use if ALL conditions met):
  1. User explicitly requested amend, OR commit succeeded but hook auto-modified files
  2. HEAD commit created by you in this conversation
  3. Commit has NOT been pushed to remote
- **If commit failed/rejected**: NEVER amend, fix and create NEW commit

### HEREDOC Format for Commits

Always use HEREDOC for commit messages to ensure good formatting:

```bash
git commit -m "$(cat <<'EOF'
Commit message here.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Dangerous Commands (CRITICAL)

### Forbidden Commands (Kills VS Code Remote)

**NEVER run commands that kill all Node.js processes.** This will crash VS Code Remote:

| FORBIDDEN | WHY |
|-----------|-----|
| `pkill -f "node"` | Kills VS Code Server |
| `pkill node` | Kills VS Code Server |
| `killall node` | Kills VS Code Server |
| `kill -9 $(pgrep node)` | Kills VS Code Server |

### Safe Alternatives

```bash
# Kill by specific port (e.g., Vite on 5173)
lsof -ti:5173 | xargs kill -9 2>/dev/null || true

# Kill specific process by name
pkill -f "vite" 2>/dev/null || true

# Kill by exact process pattern
pkill -f "npm run dev" 2>/dev/null || true
```

### Enforcement

Pre-command hook at `.claude/hooks/guard-dangerous-commands.sh` blocks dangerous commands with guidance on safe alternatives.

---

## Compliance Validation

### Automated Compliance Check

Run before commits and releases:

```bash
./.logic-loom/scripts/bash/constitutional-check.sh
```

Validates:
- All 16 constitutional principles
- Documentation synchronization
- Test coverage
- Code style compliance
- No secrets in code
- Dependency declarations

### Manual Validation

Use `/finalize` command for comprehensive pre-commit validation:

```bash
# Run finalize command
./.logic-loom/scripts/bash/finalize-feature.sh

# Review compliance report
# If all checks pass, manually execute suggested git commands
```

### Constitutional Update Process

When updating the constitution:

**MUST follow** `.logic-loom/memory/constitution_update_checklist.md`

Ensures all dependent documents updated:
- CLAUDE.md
- Agent context files
- Skill documentation
- Workflow scripts
- Validation scripts

---

## Enforcement Model (Hook-Based)

Constitutional compliance is enforced by hooks, not by a recited per-message
ceremony:

- **Preflight hook** (`UserPromptSubmit`): domain detection + delegation hints
- **Dangerous-command guard** (pre-command): blocks destructive/forbidden commands
- **Git safety**: `request_git_approval()` in `common.sh` gates all git operations
- **`LOOM_GOVERNANCE_MODE`** (`governance.conf`): `lean` (default, silent) or `strict` (verbose)

If a violation occurs at runtime, stop, surface it, correct, and continue — the
hooks will have flagged it; no manual compliance block is required.

---

## Governance Loading

Load governance context when needed:

```bash
# Load governance module
./.logic-loom/scripts/bash/load-context.sh load governance

# Load based on request analysis
./.logic-loom/scripts/bash/load-context.sh analyze "commit these changes"
```

---

**Module Version**: 2.0.0
**Created**: 2026-01-09 (Sprint 3 Task T024)
**Last Updated**: 2026-02-07
**Constitutional Authority**: All 16 Principles (I-XVI)
**Source Documents**:
- `.logic-loom/memory/constitution.md` (v3.2.0)
- `.logic-loom/memory/constitution_update_checklist.md`
- `.logic-loom/config/governance.conf` (LOOM_GOVERNANCE_MODE)
- CLAUDE.md "Constitutional Foundation" and "Git Operations" sections
- `.logic-loom/scripts/bash/common.sh` (git approval + `get_domain_brief`)
