# File Structure & Organization Policy

**Version**: 1.1.0
**Effective Date**: 2026-06-30
**Authority**: Constitution v3.3.0
**Review Cycle**: Quarterly

---

## Purpose

This policy establishes comprehensive rules for file creation, folder organization, and directory structure management across the LogicLoom framework. It ensures consistency, discoverability, and maintainability as projects scale.

---

## Core Principles

### 1. Structure Before Content

**ALWAYS verify directory structure exists before creating files.**

```
WRONG: Write file directly
RIGHT: Verify parent directories → Create if needed → Write file
```

### 2. Convention Over Configuration

**Follow established patterns - don't invent new structures.**

### 3. Explicit Over Implicit

**File names should clearly indicate purpose, type, and ownership.**

### 4. Minimal File Creation

**Prefer editing existing files over creating new ones.**

---

## Framework Directory Structure

### Root Structure (SSOT)

```
project-root/
├── .claude/                    # Claude Code configuration
│   ├── agents/                 # Agent definitions (by department)
│   ├── commands/               # Slash command definitions
│   ├── skills/                 # Skill definitions (by category)
│   └── settings.json           # Claude Code settings
│
├── .docs/                      # Documentation and agent memory
│   ├── agents/                 # Agent memory (mirrors .claude/agents/)
│   ├── features/               # Feature-specific documentation
│   ├── policies/               # Framework policies
│   └── prd/                    # Product Requirements Documents
│
├── .logic-loom/                   # LogicLoom framework core
│   ├── config/                 # Framework configuration
│   ├── memory/                 # Constitutional documents
│   ├── scripts/                # Automation scripts
│   └── templates/              # Document templates
│
├── features/                   # Per-feature folders (vision/PRD/plan workflow pack)
│   └── <name>/                 # e.g., user-auth/ — vision, plan, retro
│
├── specs/                      # Feature specs (SDD waterfall workflow pack)
│   └── ###-feature-name/       # Per-feature spec directory
│
├── artifacts/                  # Standalone deliverables (vision, research, forensics,
│                               # docs — never a plan). Create on first use.
│
├── web/  (or apps/<name>/)     # PRODUCT app workspace (own package.json — see "Product Workspace")
│   └── src/                    # Product application code (NOT at repo root)
│
├── tests/                      # FRAMEWORK test files (product tests live in the workspace)
│   ├── unit/                   # Unit tests
│   ├── integration/            # Integration tests
│   └── contract/               # Contract tests
│
├── CLAUDE.md                   # AI assistant instructions
├── README.md                   # Project documentation
└── package.json                # Framework configuration (jest, devDeps — FRAMEWORK-OWNED)
```

---

## Product Workspace (harness vs product)

**The framework owns the repo root; product application code lives in a dedicated workspace.**

This is the load-bearing boundary that the rest of this policy assumes. Keeping
it clean is what lets `/update-framework` stay operational and the governance
floor stay path-agnostic.

### Framework-owned (repo root)

The following root surfaces are **FRAMEWORK-OWNED** — a product must not share or
repurpose them:

- Root `package.json` (jest, devDeps, framework coverage gates)
- Root `tests/` (framework contract / integration / unit suites + `tests/run_all_tests.sh`)
- `.claude/`, `.logic-loom/`, `plugins/` (governance, hooks, framework plugins)

### Product-owned (dedicated workspace)

PRODUCT application code lives in its own workspace **out of the repo root**, with
its **own** `package.json`, `node_modules`, build pipeline, and test runner:

```
web/                            # single product app
├── package.json                # product deps + product test runner (PRODUCT-OWNED)
├── node_modules/
└── src/

apps/                           # monorepo: one workspace per app
├── <name>/                     # e.g., apps/api/, apps/admin/
│   ├── package.json            # each app fully self-contained (PRODUCT-OWNED)
│   ├── node_modules/
│   └── src/
└── <other>/
```

- **Single app** → `web/`.
- **Monorepo** → `apps/<name>/`, each with its own `package.json` / `node_modules` /
  build / test runner.

Product specs under `specs/<feature>/` and feature work under `features/<name>/`
are **tracked** (committed and reaching clones) — they are the supported home for
product specification and exploratory work.

### Why a separate workspace (not the root)

Sharing the root `package.json` / `tests/` with product code causes two **silent**
collisions — silent because neither one fails a build; they just quietly change
what `npm test` covers:

- **jest-glob collision** — the framework's root `testMatch` glob sweeps product
  tests into `npm test`, mixing them with framework suites and forcing them under
  the framework's coverage gates.
- **coverage collision** — the framework's `collectCoverageFrom` is scoped to
  framework dirs; product code sharing the root distorts both gates.

A dedicated product workspace with its own `package.json` and test runner avoids
both — the framework keeps root `npm test` + contract coverage, the product keeps
its own runner.

---

## Directory-Specific Rules

### .claude/agents/ - Agent Definitions

**Structure**:
```
.claude/agents/
├── architecture/               # System design agents
│   └── subagent-architect.md
├── governance/                 # Governance agents
│   └── constitutional-governance-agent.md
├── orchestration/              # Multi-agent coordination
│   ├── team-synthesizer.md
│   └── memory-context-agent.md
├── product/                    # Product agents
│   └── prd-specialist.md
├── quality/                    # QA agents
│   ├── debug-analyst.md
│   ├── quality-assessor.md
│   └── tribunal-judge.md
└── operations/                 # Framework operations
    └── framework-sync-agent.md
```

**Rules**:
- One agent per file
- File name = agent name (kebab-case)
- Department folder must exist before creating agent
- Use `.logic-loom/templates/agent-template.md` for new agents

### plugins/<plugin>/skills/ - Skill Definitions

Skills belong to a plugin (Principle XVI). There is **no** top-level
`.claude/skills/` directory — `constitutional-check.sh` warns if one appears.

**Structure**:
```
plugins/
├── loom-governance/skills/     # Governance-core skills
│   ├── constitutional-compliance/
│   │   └── SKILL.md
│   ├── domain-detection/
│   │   └── SKILL.md
│   ├── file-organization/
│   │   └── SKILL.md
│   └── ...
└── sdd-specification/skills/   # SDD waterfall pack
    └── unified-specification/  # the plugin's only skill
        └── SKILL.md
```

**Rules**:
- Each skill gets its own folder inside its owning plugin
- Main file MUST be named `SKILL.md`
- Supporting files allowed: `reference.md`, `examples.md`
- Use `.logic-loom/templates/skill-template.md` for new skills

### .docs/agents/ - Agent Memory

**Structure**:
```
.docs/agents/
├── [department]/
│   └── [agent-name]/
│       ├── context/
│       │   └── [agent-name]-context.md
│       ├── knowledge/
│       │   └── [agent-name]-knowledge.md
│       ├── decisions/
│       │   └── [agent-name]-decisions.md
│       │   └── tasks/          # Task completion history
│       └── performance/
│           └── [agent-name]-performance.md
└── shared/
    └── task-handoffs/
        ├── README.md
        └── context-transfers.md
```

**Rules**:
- Mirror `.claude/agents/` department structure
- File names MUST include agent name prefix
- See `.docs/policies/agent-file-naming-convention.md`

### .docs/policies/ - Framework Policies

**Rules**:
- One policy per concern
- Use kebab-case: `[topic]-policy.md`
- Include version, date, and authority header
- Reference constitutional principles

### features/ - Vision/PRD/Plan Workflow Pack Folders

**Structure**:
```
features/
└── <feature-name>/             # e.g., user-auth/ (kebab-case, no number prefix)
    ├── vision.md               # Feature vision (PRD-lite, intent + acceptance)
    ├── plan.md                 # DAG plan from /swarm explore
    ├── retro.md                # Post-completion retrospective (/retro)
    └── notes/                  # Optional working notes, research, artifacts
```

**Rules**:
- Directory name: `<feature-name>` (kebab-case, no sequential prefix)
- Created via `/create-prd` or `/swarm explore` workflow
- Interchangeable with `specs/`; both workflow packs share the governance core

### specs/ - SDD Waterfall Workflow Pack Specifications

**Structure**:
```
specs/
└── ###-feature-name/           # e.g., 001-user-auth/
    ├── spec.md                 # Feature specification
    ├── plan.md                 # Implementation plan
    ├── research.md             # Technical research
    ├── data-model.md           # Entity definitions
    ├── tasks.md                # Implementation tasks
    ├── quickstart.md           # Test scenarios
    └── contracts/              # API contracts
        ├── users.yaml
        └── auth.yaml
```

**Rules** (SDD waterfall workflow pack):
- Feature number prefix (###) is sequential
- Directory name: `###-feature-name` (kebab-case)
- All files use templates from `.logic-loom/templates/`
- Created via `/specification` command (SDD waterfall pack)

### artifacts/ - Standalone deliverables (who/what/why/where)

A repo-root directory for **standalone deliverables**: a vision page, a research
write-up, a forensic record of an incident, a rendered doc. The test is
*who / what / why / where* — an artifact states something. It is **never a plan**:
sequencing belongs to `features/<name>/plan.md` or `specs/###-name/tasks.md`, and
hardwiring a plan into an artifact confines the agent that should be deciding it.

**Structure**:
```
artifacts/
├── <name>.html                 # self-contained page (inline CSS/JS, no external requests)
└── <name>.md                   # or plain markdown
```

**Rules**:
- **Create on first use.** The directory does not ship in a fresh clone — like
  `web/`, it is documented here and created when there is something to put in it.
- **Contents are project-owned**, not framework machinery. LogicLoom's own
  artifacts are stripped at template release (`artifacts` is a wholesale entry in
  `.logic-loom/scripts/bash/template-strip-manifest.txt`), so a cloner inherits
  the convention and none of our pages.
- Flat by default; add subdirectories only when the file count warrants it.
- An HTML artifact must be **self-contained** — inline CSS and JS, no CDN, no
  webfont, no remote image — because it is opened directly from disk over
  `file://`, where cross-origin requests (including `fetch()` of a sibling JSON)
  are blocked. `.logic-loom/scripts/bash/build-backlog-dashboard.sh` is the
  worked example: it inlines a snapshot of its data source for exactly this reason.
- **Placement follows what a file IS; tracking follows how it is PRODUCED.**
  These are separate questions and `artifacts/` answers only the first. Most
  artifacts are hand-authored and committed. A **generated** page that meets the
  who/what/why/where test belongs here too — and is **tracked like its
  neighbours, on one condition**: a fail-closed freshness gate covers it.
  Worked example: `artifacts/backlog-dashboard.html`, produced by
  `.logic-loom/scripts/bash/build-backlog-dashboard.sh` from
  `.logic-loom/backlog-index.json`. It is a *what/where* view — which work
  exists, of what class, from which source, in what state — and it sequences
  nothing, so it is an artifact and not a plan.

  **The rule for a generated deliverable, in full:**
  1. **Track only what a human opens.** The dashboard is read by people, so it
     is committed and travels worktree → feature branch → `dev-main` like any
     other file. A **machine-readable intermediate with no standalone reader** —
     `.logic-loom/backlog-index.json` — is not a deliverable, stays under
     `.logic-loom/`, and stays **gitignored**: nothing is lost by regenerating
     it, so nothing justifies the staleness cost of tracking it.
  2. **Pay the staleness cost with a gate, not a warning.** A tracked derived
     artifact drifts from its sources the moment one is edited without
     regenerating — the class that produced three defects in this repo, two of
     them behind a warn-only lint. The licence to track is
     `.logic-loom/scripts/bash/check-generated-freshness.sh`, which regenerates
     the artifact and **fails** if the committed copy differs. It runs in
     `.github/workflows/plugin-tests.yml`. Add a tracked generated file and you
     add it to that gate in the same change; remove the gate and the file goes
     back to being ignored.
  3. **Keep it out of the customer template at promote, not with an ignore
     rule.** Our artifacts are ours: `artifacts` is a **wholesale** entry in
     `.logic-loom/scripts/bash/template-strip-manifest.txt`, so the directory is
     removed when the sanitized template is built. Note that `.gitignore` is
     **not branch-scoped** in any reliable way — it is itself a tracked file, so
     a per-branch divergence merges and propagates like any other content
     difference. "Not ignored + stripped at promote" is the mechanism; a
     dev-only ignore rule is not.

### Product source code (inside the product workspace)

Product source code lives **inside the product workspace** (`web/` for a single
app, `apps/<name>/` for a monorepo — see "Product Workspace" above), **never at
the repo root**. Root `src/` is not a product home: a product `src/` at the root
trips the framework's jest-glob and coverage gates (see "Product Workspace").

**Decision rule** — pick the workspace shape first, then lay out `src/` inside it:

| Project shape | Workspace | Source layout |
|---------------|-----------|---------------|
| **Single app** | `web/` | `web/src/` (`models/`, `services/`, `components/`, `utils/`, …) |
| **Web app (split tiers)** | `web/` | `web/backend/src/` (`api/`, `models/`, `services/`, `middleware/`) + `web/frontend/src/` (`components/`, `pages/`, `hooks/`, `utils/`) |
| **Monorepo** | `apps/<name>/` | one `apps/<name>/src/` per app, each app self-contained |

**Rules**:
- Source lives under the product workspace, not the repo root.
- Follow language/framework conventions; the exact tree is defined in the feature's `plan.md`.
- Tests live with the product (the workspace's own test runner), mirroring source structure — not in the framework-owned root `tests/`.

---

## File Creation Rules

### Pre-Creation Checklist

Before creating ANY file:

```
[ ] Is this file necessary? (Can existing file be modified?)
[ ] Does the parent directory exist?
[ ] Does a file with this name already exist?
[ ] Does this follow naming conventions?
[ ] Is there a template for this file type?
[ ] Am I using absolute paths from repo root?
```

### File Creation Protocol

```
1. VERIFY need for new file
   └─ Check if existing file can be modified instead

2. VERIFY directory structure
   └─ Use: ls [parent-directory]
   └─ Create parent dirs if needed: mkdir -p [path]

3. CHECK for existing file
   └─ Use: ls [file-path] or Read tool
   └─ If exists: Edit instead of Write

4. USE TEMPLATE if available
   └─ Check .logic-loom/templates/ for applicable template
   └─ Copy and modify template content

5. CREATE file with full absolute path
   └─ Use Write tool with absolute path from repo root

6. VERIFY creation
   └─ Confirm file exists and content correct
```

### Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Agent | `[role]-[function].md` | `subagent-architect.md` |
| Skill folder | `[skill-name]/` | `domain-detection/` |
| Skill file | `SKILL.md` | `SKILL.md` |
| Policy | `[topic]-policy.md` | `testing-policy.md` |
| Feature spec | `###-[name]/` | `001-user-auth/` |
| Test file | `test_[name].py` | `test_user_service.py` |
| Config | `[name].config.[ext]` | `database.config.json` |

**General Rules**:
- Use **kebab-case** for directories and multi-word files
- Use **snake_case** for Python files
- Use **camelCase** for JavaScript/TypeScript files
- Prefix agent memory files with agent name
- Sequential numbering for features (001, 002, etc.)

---

## Folder Creation Rules

### Pre-Creation Checklist

Before creating ANY folder:

```
[ ] Does this folder fit the established structure?
[ ] Is the parent directory appropriate?
[ ] Does a folder with this name already exist?
[ ] Is there a standard location for this type of content?
```

### Folder Creation Protocol

```
1. VERIFY location
   └─ Check parent directory exists and is appropriate

2. CHECK for existing folder
   └─ Use: ls [parent-directory]

3. CREATE with proper permissions
   └─ Use: mkdir -p [path] (creates parents if needed)

4. ADD required files
   └─ Most folders need a README.md or similar
   └─ Agent memory folders need 4 subdirectories

5. VERIFY structure
   └─ Confirm folder and contents created correctly
```

### Required Folder Contents

| Folder Type | Required Contents |
|-------------|-------------------|
| Agent memory | `context/`, `knowledge/`, `decisions/`, `performance/` |
| Skill | `SKILL.md` |
| Feature spec | `spec.md`, `plan.md`, `tasks.md` (minimum) |
| Policy | At least one `*-policy.md` file |

---

## Prohibited Actions

### Never Do These

1. **Create files without checking existence first**
   ```
   BAD:  Write to path without checking
   GOOD: Read first, then Edit or Write
   ```

2. **Create arbitrary directory structures**
   ```
   BAD:  mkdir custom/random/path
   GOOD: Use established structure locations
   ```

3. **Use generic file names in agent directories**
   ```
   BAD:  README.md in every agent folder
   GOOD: agent-name-context.md, agent-name-knowledge.md
   ```

4. **Create documentation files proactively**
   ```
   BAD:  Auto-create README.md or docs without request
   GOOD: Only create when explicitly requested
   ```

5. **Duplicate existing content in new files**
   ```
   BAD:  Create new file with similar content
   GOOD: Modify existing file or reference it
   ```

---

## Enforcement

### Automated Checks

The framework provides validation tools:

```bash
# Validate directory structure
.logic-loom/scripts/bash/validate-structure.sh

# Check file naming conventions
.logic-loom/scripts/bash/check-naming.sh

# Audit file organization
.logic-loom/scripts/bash/file-audit.sh
```

### Skill-Based Enforcement

The `file-organization` skill provides:
- Pre-creation validation
- Naming convention checking
- Structure verification
- Template application guidance

### Agent Responsibilities

All agents MUST:
1. Verify directory exists before creating files
2. Use absolute paths from repository root
3. Follow naming conventions for their domain
4. Use templates when available
5. Prefer editing over creating

---

## Recovery Procedures

### Misplaced File

```
1. Identify correct location
2. Move file: mv [current] [correct]
3. Update any references
4. Verify file accessible at new location
```

### Incorrect Naming

```
1. Identify correct name per conventions
2. Rename file: mv [old-name] [new-name]
3. Update any imports/references
4. Verify no broken links
```

### Orphaned Directory

```
1. Determine if directory needed
2. If needed: Add required contents
3. If not needed: Remove directory
4. Update any references
```

---

## Quick Reference

### Common Paths

| Content Type | Path |
|--------------|------|
| Agent definition | `.claude/agents/[dept]/[agent].md` |
| Agent memory | `.docs/agents/[dept]/[agent]/` |
| Skill | `plugins/[plugin]/skills/[skill]/SKILL.md` |
| Command | `.claude/commands/[command].md` |
| Policy | `.docs/policies/[topic]-policy.md` |
| Feature (vision/PRD/plan pack) | `features/<name>/` |
| Feature (SDD waterfall pack) | `specs/###-[name]/` |
| Template | `.logic-loom/templates/[name]-template.md` |
| Standalone deliverable (vision / research / forensics / doc) | `artifacts/[name].html` or `.md` |

### Creation Commands

```bash
# Create agent (use script)
.logic-loom/scripts/bash/create-agent.sh [name] [description]

# Create skill folder (skills live inside their owning plugin)
mkdir -p plugins/[plugin]/skills/[skill-name]

# Create feature via vision/PRD/plan workflow pack
/create-prd [feature-name]      # bootstraps features/<name>/vision.md
/swarm explore [feature-name]   # produces features/<name>/plan.md

# Create feature via SDD waterfall workflow pack
/specification [feature-name]   # bootstraps specs/###-<name>/
```

---

## References

- Agent Naming: `.docs/policies/agent-file-naming-convention.md`
- Agent Creation: `.docs/policies/agent-creation-policy.md`
- Constitution: `.logic-loom/memory/constitution.md`
- Templates: `.logic-loom/templates/`

---

**Policy Version**: 1.1.0
**Approved By**: Constitutional Authority
**Next Review**: 2026-09-30
