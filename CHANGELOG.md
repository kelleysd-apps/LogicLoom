# Changelog

All notable changes to LogicLoom (formerly the SDD Agent Framework) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [6.2.0] - 2026-05-31

**Removed the dev-loop pack** (superseded by native `/workflow`, `/loop`, `/goal`);
orchestration now leans on Claude Code's native loop primitives. LogicLoom has
**two** workflow packs over the governance core — swarm and SDD waterfall.

### Removed
- The `loom-dev-loop` plugin and the `/dev-loop` command (`core-loop` skill):
  Claude Code now ships native `/workflow`, `/loop`, and `/goal` primitives that
  supersede the autonomous edit-test-debug loop, and dev-loop's runtime
  self-extension (gap detection → scaffold → register) was a governance
  liability. Plugin count: 9 → 8.
- The dev-loop subsystems that lived only inside that pack: the dev-loop tribunal
  voting / grading engine, scope-detector, quality-grading, termination-engine,
  RL-feedback engine, self-extension, and the dev-loop contract test suites.

### Unchanged
- `/research` and its jury-on-demand multi-LLM tribunal (in `loom-orchestrator`,
  self-contained) are **kept** — they are not part of dev-loop.
- The DS-STAR refinement subsystem and `.logic-loom/config/refinement.conf` are
  **retained**, decoupled from governance.

## [6.1.0] - 2026-05-28

**Opus 4.8 re-base + workflow-agnostic core.** Removed harness scaffolding made
redundant by flagship models, and reframed the framework around a governance core
with interchangeable workflow packs (no "primary"/"legacy" path).

### Changed — governance is hook-enforced
- Removed the mandatory per-message **4-step compliance ceremony** (FR-707). The
  `git-safety-gate` PreToolUse hook now forces an approval prompt on git mutations
  (real Principle VI enforcement) and is wired into `.claude/settings.json` with
  the dangerous-command guard.
- New `LOOM_GOVERNANCE_MODE` (`.logic-loom/config/governance.conf`): `lean`
  (default, flagship models) / `strict` (re-adds recitation for weaker models).
- Constitution → **v3.1.0**: LogicLoom identity; Principle X rewritten to
  "Delegation & Context Isolation"; Opus 4.8 default; dropped the `rl_metrics`
  manifest mandate.

### Changed — workflow-agnostic reframe
- Governance core + **interchangeable workflow packs** (swarm, SDD waterfall,
  dev-loop); none privileged. `vision.md` / `/plan-review` are swarm-pack-internal
  gates, not framework-level.
- Plugins renamed `sdd-*` → `loom-*`; **`sdd-specification` keeps its prefix**
  (it *is* the SDD workflow). 9 plugins.

### Removed
- The 7 `sdd-domain-*` plugins — collapsed into a governance-core **domain-brief
  registry** (`get_domain_brief`).
- RL telemetry (`rl_metrics` fields), the `sdd-marketplace` MCP, migration
  scaffolding. (DS-STAR refinement subsystem **retained**, just decoupled from
  mandatory governance. RL retained inside the `loom-dev-loop` pack by design.)

### Added
- `.logic-loom/config/models.conf` — role→model config (flagship Opus 4.8); no
  pinned version strings in agents/commands.
- Documented model/provider boundary: orchestration is Claude-Code-native
  (Anthropic-only); cross-provider models only at the delegated `/research` layer.

## [6.0.0] - 2026-05-27

**Major release**: LogicLoom rename + workflow modernization. Project renamed `sdd-agentic-framework` → `logic-loom` (brand: **LogicLoom**); `.specify/` → `.logic-loom/`. The rename disambiguates from the loom.com video platform.

### Renamed

- Project package: `sdd-agentic-framework` → `logic-loom`
- Brand: **LogicLoom**
- Framework directory: `.specify/` → `.logic-loom/` (all script and config paths updated)

### Added — LogicLoom primary workflow

- **`features/<feature-name>/` layout**: vision → exploration → research → PRD → plan → plan-review → sprints → retro (see `features/README.md`)
- **`/plan-review` skill** (loom-orchestrator): CEO + Eng reviewer verdict on `plan.md` — gates `/swarm implement`
- **`/retro` skill** (loom-orchestrator): post-feature learning capture
- **Vision-driven `/create-prd`**: auto-detects whether `vision.md` exists and routes to vision-driven or legacy PRD mode; office-hours forcing-questions gate
- **3 new hooks**:
  - `worktree-port-namespace` — deterministic per-worktree dev-server port ranges (no collision across parallel branches)
  - `context-cap-warn` — flags sessions approaching 800K of the 1M context window
  - `freeze-write-scope` — rejects swarm worker writes outside declared file ownership

### Changed — Workflow commands

- **`/swarm` — 3 modes**: `explore` (read-only investigations), `implement [sprint]` (per-sprint scope-bounded workers, file-ownership DAG enforced), `generic-legacy` (pre-LogicLoom behavior preserved)
- **`/review-team` — 4 reviewers** (was 3): added a **behavioral evaluator** that drives Playwright via chrome-devtools MCP to exercise actual UI/API behavior alongside security + quality + performance
- **`/research` — jury-on-demand**: picks 1-3 LLM judges per query type instead of always running the full tribunal. Pass `--judges all` for legacy 3-judge cross-validation
- **`/create-prd`** auto-detects vision-driven vs legacy mode

### Removed

- `mcp-servers/sdd-marketplace/` — LogicLoom no longer runs its own plugin marketplace
- RL telemetry infrastructure: `.logic-loom/scripts/bash/rl/`, `src/sdd/feedback/`, `src/sdd/metrics/`, `.docs/rl-metrics/`
- 5 stale internal scripts: `migrate-agent-to-skill`, `legacy-pattern-report`, `skill-coverage-audit`, `analyze-logs`, and `.specify/memory/agent-collaboration.md`

### Defers (third-party discovery)

LogicLoom is not in the marketplace business. External skill and plugin discovery defers to:

- **Anthropic Claude Code Plugin Marketplace** — canonical source for installable skills/plugins
- **Docker MCP Toolkit** — 310+ containerized MCP servers via `mcp-find`, `mcp-add`, `mcp-config-set`, `mcp-exec`

### v3 supplementary principle — Legacy-Tool Coexistence

Legacy SDD tools remain as alternative paths alongside the LogicLoom workflow:

- `/specification` (unified waterfall), `/specify`, `/plan`, `/tasks`
- DS-STAR verifiers and validators
- 7 domain plugins (frontend, backend, database, testing, security, devops, performance)
- `/build-team`, `/fullstack-team`, `/dev-loop`, `/finalize`

Pick the workflow that matches the problem shape.

## [5.0.0] - 2026-02-16

**Major release**: Agent Architecture Simplification + pre-release sanitization. 1,322/1,322 tests passing across 27 suites.

### Added

- **Spec 006**: Agent Architecture Simplification + Memory Enhancement specification
- **13 new contract test suites**: dev-loop (8 suites), plugin lifecycle, deprecation, marketplace (unit + E2E) — total 27 suites, 1,322 tests
- **Dev-loop libraries**: lifecycle.sh, tribunal-engine.sh, self-extension.sh — completing dev-loop plugin implementation
- **Multi-LLM tribunal research**: `/research` command with Claude, OpenAI, and Gemini independent research + tribunal voting

### Changed - Agent Architecture Simplification

- **22 agents reduced to 11**: Eliminated redundant "Claude talking to Claude" custom agents
- **14 agents converted to enhanced plugin SKILLS**: Domain knowledge moved from agent `.md` files to plugin `SKILL.md` files with Task Briefs
  - 7 domain specialists (frontend, backend, database, security, testing, performance, devops) → plugin skills
  - 4 orchestrators (task-orchestrator, swarm-coordinator, workflow-coordinator, specification-orchestrator) → orchestration skills
  - 3 specification agents (specification, planning, tasks) → unified specification skill
- **11 agents retained**: constitutional-governance-agent, team-synthesizer, prd-specialist, subagent-architect, auto-debug-agent, framework-sync-agent, memory-context-agent, dev-loop-orchestrator, debug-analyst, quality-assessor, tribunal-judge
- **Plugin manifests** now authoritative source for RL metrics (replaces deprecated `.claude/skill-index.json`)
- **Agent registry** at `.docs/agents/agent-registry.json` (replaces deprecated `.claude/agent-index.json`)

### Changed - Pre-Release Sanitization

- **All policies** updated from Constitution v1.6.0 to v3.0.0 (8 files)
- **architecture.conf** rewritten for v5.0: skill-based-delegation mode, correct counts (11 agents, 18 plugins, 19 commands)
- **sanitize-for-template.sh** rewritten for v5.0: accurate README/TEMPLATE_INIT generation
- **RL feedback system** updated: all `skill-index.json` references replaced with plugin manifests
- **Constitutional compliance skill** updated from v1.5.0 to v3.0.0 (added Principles XV-XVI)
- **All "14 principles" references** updated to "16 principles" across ~20 files

### Removed

- **14 custom agent definitions**: Replaced by enhanced plugin skills with Task Briefs
- **3 obsolete scripts**: `generate-skill-index.sh`, `discover-skills.sh`, `update-agents-to-constitution-v1.5.0.sh`
- **TEMPLATE_INIT.md**: Now generated dynamically by sanitize script
- **Empty `loom-orchestrator-hook/agents/` directory**

### Fixed

- Agent-collaboration-triggers: removed references to non-existent agents (full-stack-developer, structure-architect, theme-designer)
- Governance knowledge base: domain-agent mapping updated to domain-skill mapping
- Plugin manifests: specification plugin agents count 4→0 (converted to skills)
- Bridge manifest: command count consistency

## [4.1.1] - 2026-02-09

**Patch**: Tag-aware update framework. 266/266 tests passing.

### Added

- **Release tag awareness** in `extract-proposals.sh`: proposals now include `release_tag` field associating each change with its upstream release version
- `list_tags_in_range()`: discovers release tags between sync-ref and upstream/main
- `find_tag_for_file()`: maps each changed file to the release it belongs to
- `--dry-run` now shows release tags in range with dates
- Framework-updater skill updated to group proposals by release tag for per-release adoption
- 5 new tag-awareness contract tests (266/266 total)

## [4.1.0] - 2026-02-09

**Release**: Hook-Based Orchestration + Memory Context Injection + Additive Update Framework. 261/261 tests passing.

### Added - Hook-Based Orchestration (Feature 005)

- **Removed custom agent profile** from `settings.json` — Claude Code runs natively, augmented by hooks
- **`loom-orchestrator-hook` plugin**: Domain detection via `config/domains.conf`, orchestration guidance injected as `additionalContext`
- **`governance-preflight.sh` v3.0.0**: Refactored to provide domain analysis, agent recommendations, and constitutional reminders without constraining Claude Code
- Downstream projects customize `domains.conf` for their own agent registries

### Added - Memory Context Agent (Feature 005)

- **`loom-memory` plugin**: 3-tier memory search (working/recall/archival) with keyword extraction and relevance scoring
- **`memory-search.sh`**: Searches project knowledge (specs, architecture docs, session history, plugins) within 5-second hook timeout
- **`memory-log.sh`**: Observability logging for memory search operations (JSONL format)
- **`memory-context-agent`**: Haiku-model agent for lightweight context injection
- Graceful fallback when plugin not installed — hook continues without memory context

### Added - Additive Update Framework (Feature 005 / Issue #30)

- **`.sdd-sync-ref`**: Single commit hash tracking last upstream sync point
- **`extract-proposals.sh`**: Upstream-history-only diffing (`sync-ref..upstream/main`) — never compares downstream content against upstream
- **Enhancement proposals**: Each upstream change presented as independently accept/reject proposal
- **Framework-updater skill v3.0.0**: 10-step proposal-based adoption flow replacing old git-diff heuristics
- Supports selective adoption: accept new plugins without accepting governance changes, etc.

### Added - Test Infrastructure

- **261/261 tests passing** across 14 suites (up from 209/11)
- 3 new contract test suites: `test_orchestration_hook.sh` (19), `test_memory_search.sh` (19), `test_update_framework.sh` (14)
- Test output format standardized to `N/N passed, N failed` for parser compatibility

### Changed

- `settings.json`: Removed `"agent"` field — Claude Code is primary agent, augmented by hook-based governance
- CLAUDE.md: Replaced agent profile section with hook-based orchestration documentation
- AGENTS.md: 22 agents across 17 plugins (up from 21/15)
- Plugin Command Bridge: 19 commands synced (unchanged count)

## [4.0.0] - 2026-02-08

**Major release**: Plugin-First Architecture, loom-dev-loop plugin, Multi-LLM tribunal research, 209/209 tests passing.

### Added - Plugin-First Architecture (v4.1)

- **16 plugins**: loom-governance, sdd-specification, loom-orchestrator, loom-creation, loom-git, sdd-debug, loom-maintenance, loom-dev-loop, 7 domain plugins, sdd-domain-template
- **SDD Marketplace MCP Server**: 6 tools for plugin management (list, validate, search, install, update, publish)
- **Dynamic Plugin Command Bridge**: `sync-plugin-commands.sh` auto-syncs plugin commands to `.claude/commands/`
- **Constitution v3.0.0**: 16 enforceable principles including Principle XVI (Plugin-First Architecture)
- **19 slash commands** across 7 core plugins, all bridge-generated

### Added - loom-dev-loop Plugin (NEW)

Recursive autonomous dev-loop with council/tribunal methodology:

- **8 libraries** (5,448 lines): grading-engine, termination-engine, event-logger, tribunal-api, permissions-sandbox, scope-detector, rl-feedback-engine, sandbox
- **6 skills**: core-loop, tribunal-vote, scope-analysis, rl-feedback, session-report, self-extend
- **4 agents**: dev-loop-orchestrator, tribunal-judge, quality-assessor, debug-analyst
- **7 entity models**: DevLoopSession, QualityGrade, TerminationEvent, TribunalBallot, RLMetrics, ScopeAnalysis, GapAnalysis
- **Composite quality grading**: 6 metrics (test_pass_rate, coverage, lint, type_safety, security, build) + LLM-as-Judge
- **6-layer termination engine**: Success → Convergence → Budget → Max Iterations → Stuck → User Interrupt
- **L0-L3 permission tiers**: Read-only → Safe Write → Network/VCS → High-Risk
- **Self-extension**: Gap detection → scaffold plugin → quarantine validate → register
- **764 test assertions** across 11 test files (247 passing, 517 TDD awaiting wiring libs)

### Added - Multi-LLM Tribunal Research

- **`/research` command**: Multi-LLM triplicate research with tribunal cross-validation
- **3 LLM providers**: Claude (Perplexity MCP), OpenAI (GPT-4o API), Gemini (2.5 Pro API)
- **5-phase pipeline**: Parallel Research → Claim Extraction → Tribunal Voting → Quality Gate → Synthesis
- **Tribunal voting**: Claude (accuracy), OpenAI (sourcing), Gemini (relevance) with EMA-weighted scoring
- Consolidates former `/research` and `/research-team` into single command

### Added - Test Infrastructure

- **209/209 framework tests passing** across 11 suites (up from 172)
- Contract tests: plugin lifecycle, swarm lifecycle, RL metrics, constitution, deprecation, plugin command bridge
- Integration tests: marketplace MCP (E2E), git safety, policy validation, structured logging

### Changed

- All monolithic agents/skills/commands migrated to plugins (deprecated stubs remain for backward compat)
- `skill-index.json` deprecated (plugin manifests now source of truth)
- AGENTS.md rewritten for Plugin-First Architecture (25 agents across 16 plugins)
- Session-specific artifacts (research output, agent decisions/sessions, feature specs) excluded from main via .gitignore
- Opus 4.6 model references updated throughout

### Fixed

- Git safety checkpoint ID assertion (epoch timestamp format)
- Structured logging `wc -l` whitespace comparison on macOS
- Policy validation `parse_json` silent failure on malformed JSON
- Missing guard-dangerous-commands.sh hook
- Stale `/research-team` test references after consolidation
- Governance plugin manifest missing `dependencies` field

## [3.2.0] - 2026-02-05

### Fixed - Framework Architecture Review

- Issues #18-#23 resolved
- Opus 4.6 model references updated
- `/research` skill added to loom-orchestrator
- Unified `/specification` and `/git-push` commands with RL integration

## [3.1.1] - 2026-01-10

### Added - Debug Skill

**New `/debug` Command** - Systematic deployment troubleshooting workflow

This patch release adds a comprehensive debugging skill with a 10-step systematic workflow for diagnosing and resolving production issues, deployment failures, and runtime errors.

#### New Skill: `/debug`

- **Location**: `.claude/skills/technical/debug/SKILL.md` (668 lines)
- **Command**: `.claude/commands/debug.md` (75 lines)

**10-Step Workflow**:
1. **Issue Identification** - Gather context, understand symptom type
2. **Local Verification** - Isolate platform vs code issues (TypeScript, client build, Vercel build)
3. **Vercel-Specific Diagnostics** - Function limits, config, env vars, platform dependencies
4. **API Endpoint Diagnosis** - Debug 404/500 errors, routing patterns
5. **TypeScript Error Resolution** - exactOptionalPropertyTypes, index signatures
6. **Fix Implementation** - Apply targeted fixes with type safety
7. **Verification Process** - Clean build, test, deploy
8. **Regression Check** - Ensure no new issues introduced
9. **Completion Report** - Document root cause and verification results
10. **Iteration Handling** - Max 5 cycles before user escalation

**Specialized Diagnostics**:
- Vercel deployment failures (build errors, function count limits, 404 endpoints)
- TypeScript compilation errors (`exactOptionalPropertyTypes`, index signatures)
- Platform-specific dependency issues (`package-lock.json`, native modules)
- API endpoint errors (500 errors, timeouts, missing routes)
- Production runtime issues (environment variables, database connections)

**Automatic Delegation**:
- `backend-architect` - API architecture issues, system design
- `database-specialist` - Query optimization, schema issues
- `security-specialist` - Auth/authorization, vulnerabilities
- `devops-engineer` - CI/CD failures, infrastructure

**Trigger Keywords**: debug, fix, broken, not working, failing, deployment failed, build error, 404, 500 error, investigate, troubleshoot, diagnose

**Constitutional Compliance**:
- **Principle II**: Verify/add tests for bug fixes
- **Principle VI**: NO automatic git operations
- **Principle VIII**: Update docs when patterns discovered
- **Principle X**: Delegates to specialists when appropriate

#### New Skill Category: `technical/`

Introduces domain-specific technical procedures category, enabling future skills:
- `technical/api-contract-design/`
- `technical/test-first-development/`
- `technical/performance-optimization/`

#### Documentation Updates

- **CLAUDE.md**: Added `/debug` to Quick Command Reference table
- **Version**: v3.1.0 → v3.1.1
- **.claude/context/skills.md**: Debug skill entry with workflow steps and delegation points

#### Real-World Validation

Battle-tested patterns from production debugging:
- Vercel function count limit issues (consolidating endpoints)
- TypeScript `exactOptionalPropertyTypes` errors (conditional object building)
- Platform-specific dependencies (Windows vs Linux lockfiles)

**Total Lines Added**: 743 lines (668 SKILL.md + 75 debug.md)

---

## [2.0.0] - 2025-11-11

### Major Feature: DS-STAR Multi-Agent Enhancement (Feature 001)

This release integrates Google's proven DS-STAR multi-agent patterns into the SDD framework, bringing sophisticated quality gates, intelligent routing, and self-healing capabilities.

#### Added - DS-STAR Agent Library

- **VerificationAgent** (`src/sdd/agents/quality/verifier.py`)
  - Binary quality decisions (sufficient/insufficient) at each workflow stage
  - Specification completeness validation (≥0.90 threshold)
  - Plan quality validation (≥0.85 threshold, ≥0.90 spec alignment)
  - Blocks progression when quality insufficient
  - Provides actionable feedback for improvements

- **FinalizerAgent** (`src/sdd/agents/quality/finalizer.py`)
  - Pre-commit constitutional compliance validation
  - All 14 constitutional principles validation
  - Test coverage verification (≥80%)
  - Code style compliance (black, isort)
  - Documentation synchronization checks
  - No automatic git operations (Principle VI compliant)

- **RouterAgent** (`src/sdd/agents/architecture/router.py`)
  - Intelligent multi-agent task orchestration
  - Domain detection and agent selection
  - Dependency graph (DAG) execution planning
  - Parallel execution optimization
  - Routing decision audit trails

- **AutoDebugAgent** (`src/sdd/agents/engineering/autodebug.py`)
  - Automatic error repair with >70% fix rate target
  - <30 second debug iteration cycles
  - Common error pattern recognition
  - Self-healing code corrections

- **ContextAnalyzerAgent** (`src/sdd/agents/architecture/context_analyzer.py`)
  - Semantic codebase search with <2 second retrieval
  - Context intelligence and summarization
  - Codebase understanding for agent tasks

#### Added - Refinement Engine

- **Iterative Refinement Loop** (`src/sdd/refinement/engine.py`)
  - Up to 20 refinement rounds with configurable thresholds
  - Early stopping at 0.95 quality threshold
  - State persistence between iterations
  - Feedback accumulation across rounds
  - Graceful escalation to human when needed

- **Configuration System** (`.logic-loom/config/refinement.conf`)
  - `MAX_REFINEMENT_ROUNDS=20` - Maximum iteration limit
  - `EARLY_STOP_THRESHOLD=0.95` - High quality early exit
  - `SPEC_COMPLETENESS_THRESHOLD=0.90` - Specification requirement
  - `PLAN_QUALITY_THRESHOLD=0.85` - Plan requirement
  - `TEST_COVERAGE_THRESHOLD=0.80` - Code coverage requirement

#### Enhanced - Workflow Commands

- **`/specify` Command**
  - Automatic refinement loop after spec generation
  - Iterative improvement until quality threshold met
  - Actionable feedback for specification improvements
  - Human escalation when quality unachievable

- **`/plan` Command**
  - Automatic verification gate after plan generation
  - Quality blocking before task generation phase
  - Plan-to-spec alignment validation
  - Actionable feedback for plan improvements

- **`/finalize` Command** (NEW)
  - Pre-commit compliance validation
  - All 14 constitutional principles checked
  - Test and coverage verification
  - Code style and linting validation
  - Documentation synchronization checks
  - Manual git command suggestions (no auto-execution)

#### Added - Testing Infrastructure

- **Contract Tests** (39 tests, 100% pass rate)
  - VerificationAgent contract tests (13 tests)
  - FinalizerAgent contract tests (13 tests)
  - RouterAgent contract tests (13 tests)
  - Full interface validation coverage

- **Integration Tests** (37 tests)
  - End-to-end verification workflow tests
  - Multi-agent routing orchestration tests
  - Context intelligence tests
  - Refinement loop tests
  - Autodebug healing tests

#### Added - Documentation

- **Feature Specification** (`specs/001-ds-star-multi/`)
  - Complete DS-STAR implementation spec
  - Technical design documentation
  - API contracts and data models
  - Test scenarios and quickstart guide

- **Integration Guides**
  - DS-STAR integration guide
  - Implementation status tracking
  - Test results documentation
  - Production readiness report

#### Enhanced - Framework Features

- **Graceful Degradation**
  - Framework works without Python/DS-STAR components
  - Warning messages when components unavailable
  - Manual review recommendations
  - No workflow blocking

- **Performance Targets**
  - Context retrieval: <2 seconds
  - Debug iteration: <30 seconds
  - 3.5x task completion accuracy improvement (target)
  - >70% automatic fix rate (target)

### Changed

- Updated README.md with DS-STAR feature documentation
- Updated CLAUDE.md with DS-STAR workflow enhancements
- Enhanced directory structure with `src/sdd/` Python library
- Added `.docs/agents/shared/` for cross-agent state

### Breaking Changes

None - DS-STAR enhancements are fully backward compatible with graceful degradation.

---

## [1.2.0] - 2025-09-19

### Added
- **New Agents**
  - `testing-specialist` - Comprehensive QA and test automation specialist in quality department
  - `performance-engineer` - Performance analysis and optimization specialist in operations department

### Enhanced
- **Agent Creation Workflow**
  - Enforced constitutional requirement for subagent-architect delegation
  - Custom tool override capability for specific agent needs
  - Automatic department classification based on purpose keywords
  - Improved MCP access configuration per department

### Documentation
- Updated README.md with current agent inventory (9 agents across 5 departments)
- Added agent quick reference section
- Improved troubleshooting guide

## [1.1.0] - 2025-09-18

### Added
- **Core Agent Infrastructure**
  - Established 7 initial agents across 5 departments:
    - Architecture: `subagent-architect`, `backend-architect`
    - Engineering: `frontend-specialist`, `full-stack-developer`
    - Quality: `security-specialist`
    - Operations: `devops-engineer`
    - Data: `database-specialist`

- **Agent Management System**
  - Central agent registry (`/docs/agents/agent-registry.json`)
  - Audit logging for agent creation
  - Memory structure for agent context and knowledge
  - Department-based organization

- **Constitutional Framework**
  - Section X: Mandatory specialized agent delegation
  - Agent governance framework
  - Agent collaboration patterns
  - Department-specific tool and MCP access controls

### Enhanced
- **create-agent.sh Script**
  - Automated department assignment
  - Tool restriction by department
  - MCP server configuration
  - Registry and documentation auto-updates
  - Constitutional compliance validation

- **Workflow Automation**
  - `/create-agent` command with subagent-architect enforcement
  - Automatic CLAUDE.md updates
  - Agent file naming conventions
  - Memory structure initialization

### Changed
- **Git Operations Policy**
  - NO automatic git operations without explicit user approval
  - Branch creation requires user confirmation and naming preference
  - All commits, pushes, and merges need explicit permission

## [1.0.0] - 2025-09-17

### Initial Framework Release
- **Specification-Driven Development (SDD) Core**
  - Constitutional development principles
  - Library-First architecture mandate
  - Test-First Development (TDD) enforcement
  - Contract-driven integration patterns

- **Workflow Commands**
  - `/specify` - Feature specification creation
  - `/plan` - Implementation planning
  - `/tasks` - Task list generation
  - `/create-agent` - Agent creation (initial version)

- **Directory Structure**
  - `.logic-loom/` - Framework core with templates and scripts
  - `.claude/` - AI assistant configuration
  - `.docs/` - Project documentation and policies
  - `specs/` - Feature specifications directory

- **Templates**
  - Feature specification template
  - Implementation plan template (9-step process)
  - Task list generation template
  - Agent file template

### Based On
- GitHub's spec-kit framework
- Extended with AI governance and agent orchestration
- Enhanced workflow automation and memory management

## Pre-1.0.0

### Foundation
- Initial commit from SDD framework base
- Basic directory structure setup
- Core constitutional principles established
- Initial templates and scripts

---

## Upgrade Guide

### From 1.1.0 to 1.2.0
1. No breaking changes
2. New agents available: `testing-specialist` and `performance-engineer`
3. Review updated agent collaboration patterns for optimal usage

### From 1.0.0 to 1.1.0
1. Review constitutional Section X for mandatory agent delegation
2. Update any custom scripts to use Task tool for agent invocation
3. Ensure all Git operations request user approval

## Future Roadmap

### Planned Features
- [ ] Agent performance metrics and optimization
- [ ] Cross-agent workflow templates
- [ ] Enhanced MCP integration patterns
- [ ] Agent capability evolution tracking
- [ ] Automated agent selection based on task analysis

### Under Consideration
- Product department agents
- Multi-agent orchestration improvements
- Agent learning and adaptation features
- Workflow visualization tools