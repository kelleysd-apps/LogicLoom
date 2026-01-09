# Skills Context Module
<!-- Auto-generated from skill files - Sprint 3 Task T024 -->
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

**Location**: `.claude/skills/sdd-workflow/sdd-specification/SKILL.md`

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

**Delegates To**: `specification-agent`

**Outputs**: spec.md with user stories, acceptance criteria, constraints

**Trigger Keywords**: /specify, create spec, feature specification, requirements

---

### sdd-planning (planning-agent)

**Location**: `.claude/skills/sdd-workflow/planning-agent/SKILL.md`

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

**Delegates To**: `planning-agent`

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

**Location**: `.claude/skills/sdd-workflow/sdd-tasks/SKILL.md`

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

**Delegates To**: `tasks-agent`

**Outputs**: tasks.md with dependency-ordered task list

**Trigger Keywords**: /tasks, task generation, task breakdown, implementation tasks

---

## Technical Skills

### debug

**Location**: `.claude/skills/technical/debug/SKILL.md`

**Purpose**: Interactive debugging workflow for Vercel deployment issues, API endpoint failures, and production runtime errors

**When to Use**:
- Vercel deployment fails (build errors, function deployment issues, 404 endpoints)
- API endpoint errors (500 errors, timeout issues, missing routes)
- Production runtime issues (silent failures, incorrect behavior)
- Local vs production discrepancies (works locally but fails on Vercel)
- TypeScript compilation errors blocking deployments
- Serverless function issues (cold starts, memory limits, timeouts)
- Database connection problems
- Environment variable issues

**Workflow Steps** (10-step systematic diagnosis):
1. **Issue Identification**: Gather context, check deployment status
2. **Local Verification**: TypeScript compilation, client build, Vercel build
3. **Vercel-Specific Diagnostics**: Function count, config, env vars, platform dependencies
4. **API Endpoint Diagnosis**: 404/500 analysis, routing patterns, function structure
5. **TypeScript Error Resolution**: exactOptionalPropertyTypes, index signatures, type issues
6. **Fix Implementation**: Apply targeted fixes based on diagnosis
7. **Verification Process**: Clean build, test, document changes
8. **Regression Check**: Ensure no new issues introduced
9. **Completion Report**: Document root cause, fixes applied, verification results
10. **Iteration Handling**: Max 5 diagnostic cycles before user escalation

**Delegates To** (when specialized work identified):
- `backend-architect` - API redesign, system architecture issues
- `database-specialist` - Query performance, schema-related errors
- `security-specialist` - Auth/authorization failures, security vulnerabilities
- `devops-engineer` - CI/CD failures, infrastructure configuration

**Specialized In**:
- Vercel deployment failures (build errors, function limits, 404s)
- TypeScript compilation errors (exactOptionalPropertyTypes, index signatures)
- Platform-specific dependency issues (package-lock.json, native modules)
- API endpoint errors (500 errors, timeouts, missing routes)
- Production runtime issues (silent failures, environment variables)

**Iteration Limit**: Maximum 5 diagnostic cycles before user escalation

**Trigger Keywords**: debug, fix, broken, not working, failing, deployment failed, build error, 404, 500 error, investigate, troubleshoot, diagnose

**Constitutional Compliance**:
- **Principle II**: Verify/add tests for bug fixes
- **Principle VI**: NO automatic git operations
- **Principle VIII**: Update docs if debugging reveals new patterns
- **Principle X**: Delegate to specialists when architecture/security/performance issues found

**Usage**: `/debug` command or automatic invocation when error keywords detected

---

## Validation Skills

### message-preflight

**Location**: `.claude/skills/validation/message-preflight/SKILL.md`

**Purpose**: MANDATORY 4-step compliance check before any action (Constitutional Principle X enforcement)

**When to Use**: **EVERY user message** (no exceptions)

**Workflow Steps**:
```
STEP 1: CONSTITUTION ACKNOWLEDGMENT
       └─ Confirm awareness of 14 principles (I-XIV)
       └─ Key: II (Test-First), VI (Git Approval), X (Agent Delegation)

STEP 2: DOMAIN ANALYSIS
       └─ Scan message for domain trigger keywords
       └─ Domains: frontend, backend, database, testing, security,
                   performance, devops, specification, planning, tasks

STEP 3: DELEGATION DECISION
       └─ 0 domains → may execute directly
       └─ 1 domain → MUST delegate to specialist agent
       └─ 2+ domains → MUST delegate to task-orchestrator

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

**Location**: `.claude/skills/validation/domain-detection/SKILL.md`

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

**Location**: `.claude/skills/validation/constitutional-compliance/SKILL.md`

**Purpose**: Validate adherence to 14 constitutional principles

**When to Use**:
- Before committing code
- During feature finalization
- When quality gates trigger
- Manual compliance audits

**Checks Performed** (aligned with 14 principles):
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

**Script**: `.specify/scripts/bash/constitutional-check.sh`

**Related Command**: `/finalize` (pre-commit validation)

---

## Skill Discovery

### Skill Index

Skills are indexed in `.claude/skills/skill-index.json` (if generated).

### Manual Skill Loading

Load skill context when needed:

```bash
# Load skills module
./.specify/scripts/bash/load-context.sh load skills

# Load based on request analysis
./.specify/scripts/bash/load-context.sh analyze "debug deployment error"
```

### Skill Registration

New skills should be registered in:
1. Skill metadata file (SKILL.md frontmatter)
2. agent-collaboration-triggers.md (trigger keywords)
3. skill-index.json (if auto-generation implemented)

**Future Enhancement (T026)**: Git pre-commit hook for automatic skill registration

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
- "optimize performance" → delegates to performance-engineer
- Any message → message-preflight (mandatory)

### Explicit Invocation (Skill Reference)

```
"Use the content-pipeline skill to create an article about AI automation"
"Follow the debug skill to investigate this 500 error"
```

---

**Module Version**: 1.0.0
**Created**: 2026-01-09 (Sprint 3 Task T024)
**Constitutional Authority**: Principle X (Procedural Workflow Guidance)
**Source Documents**:
- All SKILL.md files in `.claude/skills/`
- `.specify/memory/agent-collaboration-triggers.md`
- CLAUDE.md "Commands" section
