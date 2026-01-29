# Changelog

All notable changes to the SDD Agent Framework will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

- **Configuration System** (`.specify/config/refinement.conf`)
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
  - `.specify/` - Framework core with templates and scripts
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