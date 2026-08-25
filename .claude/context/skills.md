# Skills Context Module
<!-- Auto-generated from plugin skill files -->
<!-- MAINTAINED BY HAND — there is no generator. load-context.sh only READS and
     caches .claude/context/*.md; nothing writes them. The "Auto-generated" line
     above records this file's ORIGIN (transcribed once from the plugin SKILL.md
     files), not a live pipeline. Edit it directly and keep it in step with the
     plugins by hand. Every command, skill and path named here must resolve. -->
<!-- Module: Skill definitions, procedural workflows, trigger keywords -->

## Available Skills

Skills are procedural workflows that guide systematic execution of complex tasks. Each skill provides step-by-step procedures, verification criteria, and delegation points.

---

## Integration Skills

### mcp-server-setup

**Location**: `plugins/loom-maintenance/skills/mcp-server-setup/SKILL.md`

**Purpose**: MCP server selection and configuration via the Docker MCP Toolkit
(primary) or direct installation (fallback). LogicLoom ships no marketplace MCP
of its own — discovery is Anthropic's Claude Code Plugin Marketplace plus the
Docker MCP Toolkit gateway.

**When to Use**:
- Extending the session with browser automation, media, or external APIs
- After `/initialize-project`, when the project needs servers configured
- Storing MCP credentials (`.env` + `env:VAR_NAME` references — never committed)

**Docker MCP Toolkit tools**:
- `mcp-find` - Search the 310+ server catalog
- `mcp-add` - Add a server to the session
- `mcp-config-set` - Configure server credentials
- `mcp-exec` - Execute a tool from any enabled server
- `code-mode` - Combine multiple MCP tools in JavaScript

**Verifier**: `.logic-loom/scripts/bash/verify-mcp-toolkit.sh`

**Trigger Keywords**: set up MCP servers, configure MCP, add MCP server, what MCP servers are available

---

## SDD Workflow Skills

### unified-specification

**Location**: `plugins/sdd-specification/skills/unified-specification/SKILL.md`

**Command**: `/specification` (`plugins/sdd-specification/commands/specification.md`)

**Purpose**: The whole SDD waterfall in one skill — specification, planning and
task generation, with a quality gate between each phase. This is the ONLY
specification skill — the earlier one-skill-per-phase arrangement, and the three
per-phase commands that drove it, no longer exist.

**When to Use**:
- Requirements are well understood and stable (otherwise use the swarm pack)
- A feature needs spec + contracts + data model + tasks as one coherent set

**Workflow Steps**:
1. **Phase 1 — Specification**: user stories, acceptance criteria, constraints → `spec.md`
2. **Quality gate**: spec completeness ≥ 90%
3. **Phase 2 — Planning**: technical research, API contracts, data model, test scenarios → `plan.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`
4. **Quality gate**: plan quality ≥ 85%
5. **Phase 3 — Tasks**: dependency-ordered breakdown with `[P]` parallel markers → `tasks.md`

**Outputs**: seven artifacts under the feature's spec directory
(`specs/<feature>/`), plus `.workflow-state.json` for resume.

**Validators**: `.logic-loom/scripts/bash/validate-spec.sh`,
`.logic-loom/scripts/bash/validate-plan.sh`,
`.logic-loom/scripts/bash/validate-tasks.sh`

**Trigger Keywords**: /specification, create spec, feature specification,
requirements, implementation plan, contract design, task breakdown

---

## Governance & Domain Briefs

Governance is **hook-enforced** — there is no message pre-flight skill to invoke
on every message. The `UserPromptSubmit` preflight hook performs domain detection
and surfaces delegation recommendations automatically. Verbosity is controlled by
`LOOM_GOVERNANCE_MODE` (`lean` default / `strict`) in
`.logic-loom/config/governance.conf`.

### Domain-Brief Registry

Domain expertise is organized in a lightweight **domain-brief
registry** — one markdown brief per domain — loaded on demand:

**Location**: `plugins/loom-governance/domain-briefs/<domain>.md`

**Loader**: `get_domain_brief <domain>` (in `.logic-loom/scripts/bash/common.sh`)

| Domain | Trigger keywords | Brief |
|--------|------------------|-------|
| Frontend | UI, component, React, CSS, responsive, styling | `plugins/loom-governance/domain-briefs/frontend.md` |
| Backend | API, endpoint, service, auth, server, middleware | `plugins/loom-governance/domain-briefs/backend.md` |
| Database | schema, migration, query, SQL, RLS, index | `plugins/loom-governance/domain-briefs/database.md` |
| Testing | test, E2E, integration, mock, QA, coverage | `plugins/loom-governance/domain-briefs/testing.md` |
| Security | security, XSS, encryption, vulnerability, OWASP | `plugins/loom-governance/domain-briefs/security.md` |
| Performance | optimize, cache, benchmark, speed, latency | `plugins/loom-governance/domain-briefs/performance.md` |
| DevOps | deploy, CI/CD, Docker, infrastructure, Vercel | `plugins/loom-governance/domain-briefs/devops.md` |

**Usage**: when domain work is detected, load the matching brief and inject it as
the worker's context (e.g. via a `/swarm` worker or team command), keeping that
worker's context isolated per Principle X.

---

### constitutional-compliance

**Location**: `plugins/loom-governance/skills/constitutional-compliance/SKILL.md`

**Purpose**: Validate adherence to 16 constitutional principles

**When to Use**:
- Before committing code
- During feature finalization
- When quality gates trigger
- Manual compliance audits

**Checks Performed** (aligned with 16 principles):
1. **Principle I**: Library-First Architecture - Feature implemented as standalone library
2. **Principle II**: Test-First Development - Tests written before implementation, coverage >80%
3. **Principle III**: Contract-First Design - Contracts defined and validated
4. **Principle IV**: Idempotent Operations - Safe repeatability verified
5. **Principle V**: Progressive Enhancement - Complexity justified
6. **Principle VI**: Git Operation Approval - No automatic commits/pushes
7. **Principle VII**: Observability - Logging and metrics present
8. **Principle VIII**: Documentation Synchronization - Docs updated with code
9. **Principle IX**: Dependency Management - Dependencies declared and pinned
10. **Principle X**: Delegation & Context Isolation - Specialized work delegated, worker context isolated
11. **Principle XI**: Input Validation & Output Sanitization - Security checks
12. **Principle XII**: Design System Compliance - UI consistency
13. **Principle XIII**: Feature Access Control - Auth/authz enforced
14. **Principle XIV**: AI Model Selection - Appropriate model used
15. **Principle XV**: File Organization - Proper structure and naming conventions
16. **Principle XVI**: Plugin-First Architecture - Capabilities as installable plugins

**Script**: `.logic-loom/scripts/bash/constitutional-check.sh`

**Related Command**: `/finalize` (pre-commit validation)

---

## Skill Discovery

### Skill Index

Skills live inside their parent plugin at `plugins/<plugin>/skills/<name>/SKILL.md`.
The complete installed set (32):

| Skill | Plugin |
|---|---|
| `create-agent` | loom-creation |
| `create-plugin` | loom-creation |
| `create-prd` | loom-creation |
| `create-skill` | loom-creation |
| `create-template` | loom-creation |
| `finalize` | loom-git |
| `git-push-workflow` | loom-git |
| `constitutional-compliance` | loom-governance |
| `domain-detection` | loom-governance |
| `file-organization` | loom-governance |
| `governance-preflight` | loom-governance |
| `message-preflight` | loom-governance |
| `qa-validation` | loom-governance |
| `environment-scaffolding` | loom-maintenance |
| `framework-updater` | loom-maintenance |
| `mcp-server-setup` | loom-maintenance |
| `project-initialization` | loom-maintenance |
| `promotion-lifecycle` | loom-maintenance |
| `context-injection` | loom-memory |
| `orchestration-guidance` | loom-orchestrator-hook |
| `cross-check` | loom-orchestrator |
| `full-stack-feature` | loom-orchestrator |
| `migration-workflow` | loom-orchestrator |
| `multi-skill-workflow` | loom-orchestrator |
| `plan-review` | loom-orchestrator |
| `project-graph` | loom-orchestrator |
| `retro` | loom-orchestrator |
| `review-evaluator` | loom-orchestrator |
| `swarm-explore` | loom-orchestrator |
| `swarm-implement` | loom-orchestrator |
| `team-orchestration` | loom-orchestrator |
| `unified-specification` | sdd-specification |

### Manual Skill Loading

Load skill context when needed:

```bash
# Load skills module
./.logic-loom/scripts/bash/load-context.sh load skills

# Load based on request analysis
./.logic-loom/scripts/bash/load-context.sh analyze "add an API endpoint"
```

### Skill Registration

New skills should be created within their parent plugin:
1. Skill metadata file (`plugins/<plugin>/skills/<name>/SKILL.md`)
2. Plugin manifest (`plugins/<plugin>/plugin.json`)
3. agent-collaboration-triggers.md (trigger keywords)

---

## Skill Invocation Patterns

### Direct Invocation (Commands)

```bash
/specification   # Invokes unified-specification skill
/swarm explore   # Invokes swarm-explore skill
/swarm implement # Invokes swarm-implement skill
/plan-review     # Invokes plan-review skill
/cross-check     # Invokes cross-check skill
/finalize        # Invokes finalize skill
/git-push        # Invokes git-push-workflow skill
```

### Automatic Invocation (Trigger Keywords)

Skills with trigger keywords are automatically invoked when keywords detected:

- "optimize performance" → loads `plugins/loom-governance/domain-briefs/performance.md` via `get_domain_brief performance`
- "deploy", "CI/CD", "Docker" → loads `plugins/loom-governance/domain-briefs/devops.md` via `get_domain_brief devops`

Note: domain detection and delegation hints run automatically in the
`UserPromptSubmit` preflight hook — there is no skill to invoke per message.

### Explicit Invocation (Skill Reference)

```
"Follow the constitutional-compliance skill to check this change"
```

---

**Module Version**: 2.0.0
**Constitutional Authority**: Principle X (Delegation & Context Isolation)
**Source Documents**:
- All SKILL.md files in `plugins/*/skills/`
- `plugins/loom-governance/domain-briefs/` (domain-brief registry)
- CLAUDE.md "Commands" section

## Commands

### /specification - Unified Specification Workflow

**Usage**:
```bash
/specification "Build user authentication with email and password"
/specification --resume  # Resume interrupted workflow
/specification --phase plan  # Start from specific phase
```

**Generated Artifacts** (all in `specs/<branch>/`):
- `spec.md` - Feature specification
- `plan.md` - Implementation plan
- `research.md` - Technical research
- `data-model.md` - Entity definitions
- `contracts/` - API contracts
- `quickstart.md` - Test scenarios
- `tasks.md` - Implementation tasks

**Quality Gates**:
- Spec completeness: ≥90%
- Plan quality: ≥85%

---

### /git-push - Complete Git Workflow

**Purpose**: Commit → Push → PR → Conflict Resolution

**Usage**:
```bash
/git-push              # Full workflow
/git-push -m "msg"     # Custom commit message
/git-push --no-pr      # Push only, skip PR
/git-push -t develop   # Target specific branch
```

**Stages**:
1. DIFF - Review changes
2. COMMIT - Approval required (Principle VI)
3. PUSH - Approval required (Principle VI)
4. PR_CREATE - Approval required (Principle VI)
5. CONFLICT_CHECK - Detect merge conflicts
6. CONFLICT_RESOLVE - Loop until clean

**⚠️ All git operations require explicit user approval (Principle VI)**

---
