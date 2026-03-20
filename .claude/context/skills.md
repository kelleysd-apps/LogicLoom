# Skills Context Module
<!-- Auto-generated from plugin skill files - Plugin-First Architecture v4.1 -->
<!-- Module: Skill definitions, procedural workflows, trigger keywords -->

## Available Skills

Skills are procedural workflows that guide systematic execution of complex tasks. Each skill provides step-by-step procedures, verification criteria, and delegation points.

---

## Integration Skills

### mcp-toolkit

**Location**: `.claude/skills/integration/mcp-toolkit/SKILL.md`

**Purpose**: Docker MCP Toolkit integration for extended capabilities (browser automation, image generation, external APIs)

**When to Use**:
- Need browser automation (screenshots, testing, scraping)
- Generate or edit images
- Web research with Gemini
- Analyze media files (videos, images)

**Available MCP Tools**:
- `mcp-find` - Search 310+ server catalog
- `mcp-add` - Add server to session
- `mcp-config-set` - Configure server API keys
- `mcp-exec` - Execute any MCP tool

**Currently Enabled Servers**:
- `gemini` - Image/video generation, web search, media analysis
- `browsermcp` - Browser automation (Playwright)

**Usage Pattern**:
1. Check if capability exists in enabled servers
2. If not available, use `mcp-find` to search catalog
3. Enable server: `docker mcp server enable <name>`
4. Add to session: Use `mcp-add` tool
5. Configure: Use `mcp-config-set` for API keys
6. Execute: Use MCP tool directly

**Trigger Keywords**: browser automation, screenshot, image generation, web research, media analysis

---

## Marketing Skills

### content-pipeline

**Location**: `.claude/skills/marketing/content-pipeline/SKILL.md`

**Purpose**: End-to-end blog article creation workflow using specialized marketing agents

**When to Use**:
- Create blog posts or articles
- Strategy articles, tips articles, how-to guides
- Thought leadership content
- Content with SEO optimization

**Pipeline Sequence**:
```
Step 1: content-strategist → Content brief (title, keywords, structure, CTA)
Step 2: research-agent → Research brief (data, trends, sources, citations)
Step 3: copywriter-agent → Draft article (HTML, Brian's voice)
Step 4: seo-specialist → Optimization (meta tags, headings, internal links)
Step 5: Publication → Add to useBlog.ts, deploy
```

**Inputs Required**:
- Topic or title idea
- Target audience (default: founders, CTOs, PE partners)
- Article type (strategy, tips, how-to, etc.)

**Outputs Produced**:
- Content brief with SEO keywords and structure
- Research brief with citations and data points
- Complete HTML article in Brian's voice
- SEO-optimized version with meta tags

**Trigger Keywords**: blog post, article, content creation, write article, strategy article, thought leadership

**Example Usage**:
```
"Create a blog post about AI automation for founders"
→ Invokes content-pipeline skill
→ Coordinates: content-strategist → research-agent → copywriter-agent → seo-specialist
```

---

## SDD Workflow Skills

### sdd-specification

**Location**: `plugins/sdd-specification/skills/sdd-specification/SKILL.md`

**Purpose**: Feature specification creation workflow (Phase 1 - /specify command)

**When to Use**:
- Starting new feature development
- Need to document requirements and user stories
- Create acceptance criteria for feature

**Workflow Steps**:
1. Gather feature context and objectives
2. Define user stories and scenarios
3. Document functional and non-functional requirements
4. Create acceptance criteria
5. Identify constraints and dependencies
6. Generate spec.md at `specs/###-feature-name/spec.md`

**Delegates To**: `sdd-specification` skill

**Outputs**: spec.md with user stories, acceptance criteria, constraints

**Trigger Keywords**: /specify, create spec, feature specification, requirements

---

### sdd-planning

**Location**: `plugins/sdd-specification/skills/sdd-planning/SKILL.md`

**Purpose**: Implementation planning workflow (Phase 2 - /plan command)

**When to Use**:
- After feature spec is complete
- Need technical research and design
- Design API contracts and data models

**Workflow Steps**:
1. **Phase 0 - Research**: Technology stack selection, library evaluation, resolve unknowns
2. **Constitution Check Gate**: Validate research completeness
3. **Phase 1 - Design**: API contracts (OpenAPI/GraphQL), data models, test scenarios
4. **Constitution Check Gate**: Validate design quality
5. **Readiness Validation**: Ensure ready for task generation

**Delegates To**: `sdd-planning` skill

**Outputs**:
- plan.md - Implementation approach
- research.md - Technical decisions and library choices
- data-model.md - Entity definitions with fields/relationships
- contracts/ - API contract schemas (OpenAPI/GraphQL)
- quickstart.md - Test scenarios and integration tests

**Trigger Keywords**: /plan, implementation plan, technical research, contract design, data modeling

**DS-STAR Enhancement**: Includes quality verification gate that blocks progression if plan quality insufficient

---

### sdd-tasks

**Location**: `plugins/sdd-specification/skills/sdd-tasks/SKILL.md`

**Purpose**: Task generation workflow (Phase 3 - /tasks command)

**When to Use**:
- After implementation plan is complete
- Need task breakdown with dependencies
- Ready to start implementation

**Workflow Steps**:
1. Verify plan artifacts exist (plan.md, contracts/, data-model.md)
2. Extract tasks from plan and contracts
3. Identify dependencies between tasks
4. Mark parallel-executable tasks with [P]
5. Order tasks by dependencies
6. Generate tasks.md

**Delegates To**: `sdd-tasks` skill

**Outputs**: tasks.md with dependency-ordered task list

**Trigger Keywords**: /tasks, task generation, task breakdown, implementation tasks

---

## Technical Skills

---

## Validation Skills

### message-preflight

**Location**: `plugins/sdd-governance/skills/message-preflight/SKILL.md`

**Purpose**: MANDATORY 4-step compliance check before any action (Constitutional Principle X enforcement)

**When to Use**: **EVERY user message** (no exceptions)

**Workflow Steps**:
```
STEP 1: CONSTITUTION ACKNOWLEDGMENT
       └─ Confirm awareness of 16 principles (I-XVI)
       └─ Key: II (Test-First), VI (Git Approval), X (Agent Delegation), XVI (Plugin-First)

STEP 2: DOMAIN ANALYSIS
       └─ Scan message for domain trigger keywords
       └─ Domains: frontend, backend, database, testing, security,
                   performance, devops, specification, planning, tasks

STEP 3: DELEGATION DECISION
       └─ 0 domains → may execute directly
       └─ 1 domain → MUST delegate to specialist skill
       └─ 2+ domains → MUST delegate to team-orchestration skill

STEP 4: EXECUTION AUTHORIZATION
       └─ Confirm all steps complete
       └─ Proceed with direct execution OR agent delegation
```

**Output Format**:
```
Constitutional Compliance Check:
- Domain(s): [none | single: <domain> | multi: <domains>]
- Delegation: [direct execution | <agent-name>]
- Git operations: [none planned | will request approval]
- Proceeding with: [action description]
```

**Violation Self-Correction**:
1. STOP immediately
2. ACKNOWLEDGE the violation explicitly
3. CORRECT by running protocol now
4. PROCEED only after correction

**Constitutional Authority**: Principle X (Agent Delegation Protocol)

---

### domain-detection

**Location**: `plugins/sdd-governance/skills/domain-detection/SKILL.md`

**Purpose**: Automated domain keyword scanning for delegation routing

**When to Use**: During STEP 2 of message-preflight check

**Domain Keywords**:
- **Frontend**: UI, component, React, CSS, responsive, styling, navigation
- **Backend**: API, endpoint, service, auth, server, middleware
- **Database**: schema, migration, query, SQL, RLS, index
- **Testing**: test, E2E, integration, mock, QA, coverage
- **Security**: security, XSS, encryption, vulnerability, OWASP
- **Performance**: optimize, cache, benchmark, speed, latency
- **DevOps**: deploy, CI/CD, Docker, infrastructure, Vercel
- **Specification**: spec, requirements, user story, acceptance criteria
- **Planning**: /plan, research, contract design, data modeling
- **Tasks**: /tasks, task breakdown, dependency, parallel

**Output**: List of detected domains and delegation recommendation

---

### constitutional-compliance

**Location**: `plugins/sdd-governance/skills/constitutional-compliance/SKILL.md`

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
10. **Principle X**: Agent Delegation Protocol - Specialized work delegated
11. **Principle XI**: Input Validation & Output Sanitization - Security checks
12. **Principle XII**: Design System Compliance - UI consistency
13. **Principle XIII**: Feature Access Control - Auth/authz enforced
14. **Principle XIV**: AI Model Selection - Appropriate model used
15. **Principle XV**: File Organization - Proper structure and naming conventions
16. **Principle XVI**: Plugin-First Architecture - Capabilities as installable plugins

**Script**: `.specify/scripts/bash/constitutional-check.sh`

**Related Command**: `/finalize` (pre-commit validation)

---

## Skill Discovery

### Skill Index

Skills are organized within their respective plugins at `plugins/*/skills/`.

### Manual Skill Loading

Load skill context when needed:

```bash
# Load skills module
./.specify/scripts/bash/load-context.sh load skills

# Load based on request analysis
./.specify/scripts/bash/load-context.sh analyze "debug deployment error"
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
/specify    # Invokes sdd-specification skill
/plan       # Invokes sdd-planning skill
/tasks      # Invokes sdd-tasks skill
/debug      # Invokes debug skill
```

### Automatic Invocation (Trigger Keywords)

Skills with trigger keywords are automatically invoked when keywords detected:

- "create blog post" → content-pipeline
- "deployment failed" → debug
- "optimize performance" → delegates to performance-operations skill
- Any message → message-preflight (mandatory)

### Explicit Invocation (Skill Reference)

```
"Use the content-pipeline skill to create an article about AI automation"
"Follow the debug skill to investigate this 500 error"
```

---

**Module Version**: 2.0.0
**Created**: 2026-01-09 (Sprint 3 Task T024)
**Last Updated**: 2026-02-07
**Constitutional Authority**: Principle X (Procedural Workflow Guidance)
**Source Documents**:
- All SKILL.md files in `plugins/*/skills/`
- `.specify/memory/agent-collaboration-triggers.md`
- CLAUDE.md "Commands" section

## New Commands (v5.0.0)

### /specification - Unified Specification Workflow

**Replaces**: `/specify` → `/plan` → `/tasks`

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

## Deprecated Commands

The following commands are deprecated (use `/specification` instead):

| Deprecated | Use Instead |
|------------|-------------|
| `/specify` | `/specification` |
| `/plan` | `/specification` |
| `/tasks` | `/specification` |

