# Tasks: Plugin-First Architecture (v4.0)

**Branch**: `004-plugin-first-architecture` | **Date**: 2026-02-06
**Spec**: `spec.md` | **Plan**: `plan.md`

---

## Phase 1: Governance Plugin PoC (v3.2.0)

### 1.1 — Contract Tests for Plugin Lifecycle [P]
- [x] **T1.1.1**: Write contract test: plugin install succeeds with valid manifest
- [x] **T1.1.2**: Write contract test: plugin enable/disable toggles capability availability
- [x] **T1.1.3**: Write contract test: sdd-governance cannot be disabled (GOVERNANCE_PROTECTED)
- [x] **T1.1.4**: Write contract test: plugin list returns installed plugins with status

### 1.2 — Scaffold sdd-governance Plugin
- [x] **T1.2.1**: Create plugin directory structure (`sdd-governance/.claude-plugin/`, `hooks/`, `skills/`, `agents/`, `scripts/`)
- [x] **T1.2.2**: Create `plugin.json` manifest with name, version, description, rl_metrics
- [x] **T1.2.3**: Create `hooks/hooks.json` with UserPromptSubmit and PreToolUse event bindings

### 1.3 — Migrate Governance Components
- [x] **T1.3.1**: Copy `governance-preflight.cjs` → `sdd-governance/hooks/scripts/`
- [x] **T1.3.2**: Copy `message-preflight/SKILL.md` → `sdd-governance/skills/message-preflight/`
- [x] **T1.3.3**: Copy `constitutional-compliance/SKILL.md` → `sdd-governance/skills/constitutional-compliance/`
- [x] **T1.3.4**: Copy `domain-detection/SKILL.md` → `sdd-governance/skills/domain-detection/`
- [x] **T1.3.5**: Copy `constitutional-governance-agent.md` → `sdd-governance/agents/`
- [x] **T1.3.6**: Copy `constitutional-check.sh` → `sdd-governance/scripts/`
- [x] **T1.3.7**: Update all internal references to use `${CLAUDE_PLUGIN_ROOT}` portable paths

### 1.4 — Integration Testing
- [ ] **T1.4.1**: Install sdd-governance plugin locally (`claude plugin install ./sdd-governance`)
- [ ] **T1.4.2**: Verify UserPromptSubmit hook fires and runs 4-step preflight
- [ ] **T1.4.3**: Verify PreToolUse hook gates git operations (Principle VI)
- [ ] **T1.4.4**: Test hot-swap: disable → confirm protection warning → re-enable
- [ ] **T1.4.5**: Verify monolithic and plugin coexist (no duplicate hook firing)
- [ ] **T1.4.6**: Measure token overhead (must be <10% over monolithic baseline)

### 1.5 — RL Metrics Integration
- [x] **T1.5.1**: Add PostToolUse hook to capture skill success/failure
- [x] **T1.5.2**: Update plugin.json rl_metrics on each invocation
- [x] **T1.5.3**: Verify rl_metrics persist across sessions
- [x] **T1.5.4**: Write validation test: rl_metrics update correctly after success/failure

### 1.6 — Documentation
- [x] **T1.6.1**: Write sdd-governance README.md with installation and usage
- [x] **T1.6.2**: Document plugin conversion patterns for other phases
- [x] **T1.6.3**: Update CLAUDE.md to reference plugin architecture

---

## Phase 2: Core Plugins (v3.3.0)

### 2.1 — Contract Tests for Core Plugins [P]
- [x] **T2.1.1**: Write contract tests for sdd-specification plugin (4 commands function)
- [x] **T2.1.2**: Write contract tests for sdd-git plugin (/git-push, /finalize)
- [x] **T2.1.3**: Write contract tests for sdd-debug plugin (/debug workflow)
- [x] **T2.1.4**: Write contract tests for sdd-creation plugin (/create-agent, /create-skill, /create-prd)

### 2.2 — Scaffold and Migrate sdd-specification
- [x] **T2.2.1**: Create plugin structure with commands/, skills/, agents/, scripts/
- [x] **T2.2.2**: Migrate 4 specification skills (sdd-specification, sdd-planning, sdd-tasks, unified-specification)
- [x] **T2.2.3**: Create command .md files for /specification, /specify, /plan, /tasks
- [x] **T2.2.4**: Migrate specification-orchestrator and planning-agent
- [x] **T2.2.5**: Migrate scaffold scripts (create-new-feature.sh, setup-plan.sh, check-task-prerequisites.sh)
- [x] **T2.2.6**: Update all internal references to use `${CLAUDE_PLUGIN_ROOT}`
- [ ] **T2.2.7**: Integration test: full /specification workflow via plugin

### 2.3 — Scaffold and Migrate sdd-git
- [x] **T2.3.1**: Create plugin structure
- [x] **T2.3.2**: Migrate git-push-workflow skill and finalize skill
- [x] **T2.3.3**: Create command .md files for /git-push and /finalize
- [x] **T2.3.4**: Add PreToolUse hook for git safety gate
- [x] **T2.3.5**: Migrate finalize-feature.sh and sanitization-audit.sh
- [ ] **T2.3.6**: Integration test: /git-push workflow via plugin

### 2.4 — Scaffold and Migrate sdd-debug [P with 2.3]
- [x] **T2.4.1**: Create plugin structure
- [x] **T2.4.2**: Migrate sdd-debug skill and auto-debug-agent
- [x] **T2.4.3**: Create command .md for /debug
- [ ] **T2.4.4**: Integration test: /debug workflow via plugin

### 2.5 — Scaffold and Migrate sdd-creation [P with 2.3, 2.4]
- [x] **T2.5.1**: Create plugin structure
- [x] **T2.5.2**: Migrate create-agent, create-skill, create-prd skills
- [x] **T2.5.3**: Create command .md files for /create-agent, /create-skill, /create-prd
- [x] **T2.5.4**: Migrate subagent-architect agent
- [ ] **T2.5.5**: Integration test: /create-agent workflow via plugin

### 2.6 — Cross-Plugin Validation
- [ ] **T2.6.1**: Verify hook ordering: governance hooks fire before other plugin hooks
- [ ] **T2.6.2**: Verify no command name collisions across plugins
- [ ] **T2.6.3**: Verify all plugins coexist with remaining monolithic components
- [ ] **T2.6.4**: Performance test: measure token overhead with 5 plugins loaded

---

## Phase 3: Domain Plugins (v3.4.0)

### 3.1 — Domain Plugin Template
- [x] **T3.1.1**: Create reusable template script for domain plugin scaffolding
- [x] **T3.1.2**: Write contract tests for domain plugin standard (skill loads, agent available)

### 3.2 — Create Domain Plugins [P — all 7 can be built in parallel]
- [x] **T3.2.1**: Create sdd-domain-frontend (frontend-operations skill, frontend-specialist agent)
- [x] **T3.2.2**: Create sdd-domain-backend (backend-operations + api-design + service-architecture skills, backend-architect agent)
- [x] **T3.2.3**: Create sdd-domain-database (database-operations + schema-design skills, database-specialist agent)
- [x] **T3.2.4**: Create sdd-domain-testing (testing-operations + qa-validation skills, testing-specialist agent)
- [x] **T3.2.5**: Create sdd-domain-security (security-operations skill, security-specialist agent)
- [x] **T3.2.6**: Create sdd-domain-devops (devops-operations + monitoring skills, devops-engineer agent)
- [x] **T3.2.7**: Create sdd-domain-performance (performance-operations skill, performance-engineer agent)

### 3.3 — Selective Installation Testing
- [ ] **T3.3.1**: Test: install only backend + database plugins → verify only those domains available
- [ ] **T3.3.2**: Test: disable frontend plugin → verify frontend skills/agent unavailable, others unaffected
- [ ] **T3.3.3**: Test: enable all domain plugins → verify full domain coverage

### 3.4 — Per-Plugin RL Validation
- [ ] **T3.4.1**: Verify each domain plugin tracks independent rl_metrics
- [ ] **T3.4.2**: Test: invoke backend skill → only sdd-domain-backend metrics update
- [ ] **T3.4.3**: Run RL dashboard showing per-plugin metrics

### 3.5 — Eliminate skill-index.json
- [ ] **T3.5.1**: Verify all command routing works via plugin auto-discovery (no skill-index.json needed)
- [ ] **T3.5.2**: Verify all keyword triggers work via skill descriptions (no routing table needed)
- [x] **T3.5.3**: Deprecate skill-index.json (keep as fallback for monolithic mode)

---

## Phase 4: Swarm + Marketplace (v4.0.0)

### 4.1 — Swarm Contract Tests
- [x] **T4.1.1**: Write contract tests for swarm lifecycle (create, spawn, status, terminate)
- [x] **T4.1.2**: Write contract tests for agent team templates (load template, spawn team)
- [x] **T4.1.3**: Write contract tests for budget controls (per-agent limit, team limit, exceed behavior)

### 4.2 — Build sdd-orchestrator Plugin
- [x] **T4.2.1**: Create plugin structure with commands/, skills/, agents/, hooks/
- [x] **T4.2.2**: Create /swarm command (.md) with task analysis and agent spawning
- [x] **T4.2.3**: Create swarm-coordinator agent definition
- [x] **T4.2.4**: Create team-synthesizer agent for merging parallel outputs
- [x] **T4.2.5**: Create launch-swarm.sh script (tmux session management)
- [x] **T4.2.6**: Create agent-stop-notification.sh hook script
- [x] **T4.2.7**: Create hooks.json with Stop and SubagentStop event bindings

### 4.3 — Agent Team Templates
- [x] **T4.3.1**: Create research-team template (3× parallel researchers + synthesizer)
- [x] **T4.3.2**: Create build-team template (architect → implementor → reviewer)
- [x] **T4.3.3**: Create review-team template (security + quality + performance → synthesizer)
- [x] **T4.3.4**: Create full-stack-team template (frontend + backend + database parallel → integration)
- [x] **T4.3.5**: Create command .md files for /research-team, /build-team, /review-team, /fullstack-team

### 4.4 — Swarm Cost Controls
- [x] **T4.4.1**: Implement team-level budget allocation (divide by agent count or by priority weight)
- [x] **T4.4.2**: Implement per-agent budget enforcement via --max-budget-usd
- [x] **T4.4.3**: Implement automatic model fallback via --fallback-model
- [x] **T4.4.4**: Implement graceful termination on budget exceed (preserve partial work)
- [x] **T4.4.5**: Implement budget reporting (per-agent, per-team, per-session)

### 4.5 — Swarm Integration Testing
- [ ] **T4.5.1**: E2E test: /swarm "Build user auth" → spawns database, backend, frontend agents
- [ ] **T4.5.2**: E2E test: /research-team "Evaluate GraphQL vs REST" → 3 parallel researchers + synthesis
- [ ] **T4.5.3**: E2E test: budget exceed → agent terminated, partial work preserved
- [ ] **T4.5.4**: E2E test: dependency ordering → database completes before backend starts

### 4.6 — SDD Plugins Marketplace
- [ ] **T4.6.1**: Create `kelleysd-apps/sdd-plugins-marketplace` GitHub repository
- [ ] **T4.6.2**: Structure marketplace with `plugins/` directory containing all 13 plugins
- [ ] **T4.6.3**: Write marketplace README with installation instructions
- [ ] **T4.6.4**: Test: `claude plugin marketplace add sdd-marketplace --repo kelleysd-apps/sdd-plugins-marketplace`
- [ ] **T4.6.5**: Test: `claude plugin install sdd-governance@sdd-marketplace`
- [ ] **T4.6.6**: Test: `claude plugin update sdd-debug@sdd-marketplace`

---

## Phase 5: Advanced Features + Deprecation (v4.1.0)

### 5.1 — Agent SDK Integration
- [x] **T5.1.1**: Research Agent SDK plugin capabilities (Python + TypeScript verifiers)
- [ ] **T5.1.2**: Create sdd-agent-sdk plugin combining constitutional governance with Agent SDK
- [ ] **T5.1.3**: Create verifier agents for constitutional compliance in SDK apps

### 5.2 — RL-Driven Plugin Updates
- [ ] **T5.2.1**: Implement success_rate monitoring with threshold alerts
- [ ] **T5.2.2**: Implement automatic update check when success_rate drops below 0.70
- [ ] **T5.2.3**: Implement user notification: "Plugin X degrading. Update available. Update? (y/n)"

### 5.3 — Deprecate Monolithic Structure
- [x] **T5.3.1**: Mark `.claude/skills/` as deprecated (add deprecation notice)
- [x] **T5.3.2**: Mark `.claude/agents/` as deprecated (add deprecation notice)
- [x] **T5.3.3**: Create migration script for downstream projects
- [x] **T5.3.4**: Update CLAUDE.md for plugin-first architecture
- [x] **T5.3.5**: Update AGENTS.md for plugin-first architecture
- [x] **T5.3.6**: Update constitution to v3.0.0 with plugin governance principles

### 5.4 — Community Contribution Framework
- [x] **T5.4.1**: Create plugin contribution guidelines for marketplace
- [x] **T5.4.2**: Create plugin template for community contributors
- [x] **T5.4.3**: Create PR template for marketplace plugin submissions
- [x] **T5.4.4**: Document plugin testing requirements for community plugins

---

## Task Summary

| Phase | Tasks | Parallel | Dependencies |
|-------|-------|----------|--------------|
| Phase 1 (v3.2.0) | 24 | 4 | None |
| Phase 2 (v3.3.0) | 25 | 8 | Phase 1 |
| Phase 3 (v3.4.0) | 14 | 7 | Phase 2 |
| Phase 4 (v4.0.0) | 24 | 4 | Phase 3 |
| Phase 5 (v4.1.0) | 14 | 4 | Phase 4 |
| **TOTAL** | **101** | **27** | — |

**Estimated Timeline**: 6-8 weeks for Phases 1-4, 2-3 weeks for Phase 5

---
