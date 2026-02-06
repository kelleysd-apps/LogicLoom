# Feature Specification: Plugin-First Architecture (v4.0)

**Feature Branch**: `004-plugin-first-architecture`  
**Created**: 2026-02-06  
**Status**: Draft  
**Input**: User description: "Migrate from monolithic skills/agents/hooks/scripts structure into a plugin-first architecture leveraging Claude Code's native plugin system. Enable hot-swappable capability modules, per-plugin RL feedback, multi-agent swarm orchestration, and marketplace distribution."
**Plan Reference**: `.docs/plans/v4.0-plugin-architecture-plan.md`

## Execution Flow (main)
```
1. Parse user description from Input
   → Feature description: Plugin-first architecture migration for SDD framework
2. Extract key concepts from description
   → Actors: Framework maintainers, downstream project users, community contributors
   → Actions: Install/remove plugins, spawn agent swarms, update plugins via RL, distribute via marketplace
   → Data: Plugin manifests, RL metrics, swarm state files, agent team templates
   → Constraints: Must preserve constitutional governance, backwards compatible during transition
3. Ambiguities marked: See [NEEDS CLARIFICATION] markers below
4. User Scenarios & Testing section filled
5. Functional Requirements generated (all testable)
6. Key Entities identified
7. Review Checklist: PASS (pending clarification items)
8. Return: SUCCESS (spec ready for planning)
```

---

## ⚡ Quick Guidelines
- ✅ Focus on WHAT users need and WHY
- ❌ Avoid HOW to implement (no tech stack, APIs, code structure)
- 👥 Written for business stakeholders, not developers

---

## User Scenarios & Testing *(mandatory)*

### Primary User Story
As a **framework maintainer**, I want to decompose the monolithic SDD framework into independent, hot-swappable plugins so that I can update, version, and distribute individual capabilities without affecting the entire framework.

### Secondary User Stories

**US-001**: As a **downstream project user**, I want to install only the plugins relevant to my project (e.g., backend + database but not frontend) so that I avoid unnecessary token overhead and complexity.

**US-002**: As a **framework maintainer**, I want each plugin to track its own RL metrics (success rate, token efficiency) so that underperforming plugins can be identified and updated independently.

**US-003**: As a **framework user**, I want to spawn coordinated multi-agent swarms that divide complex tasks across specialized agents working in parallel so that large features can be built faster.

**US-004**: As a **community contributor**, I want to create and distribute domain plugins (e.g., sdd-domain-rust, sdd-domain-mobile) through a marketplace so that the framework can be extended without modifying the core.

**US-005**: As a **framework maintainer**, I want governance enforcement to work across all plugins so that constitutional principles are never bypassed regardless of which plugins are installed.

**US-006**: As a **team lead**, I want to define agent team templates (research-team, build-team, review-team) so that common multi-agent workflows can be launched with a single command.

**US-007**: As a **framework user**, I want cost controls per agent and per team in swarm execution so that autonomous agent work stays within budget.

### Acceptance Scenarios

1. **Given** a monolithic SDD framework installation, **When** the migration is complete, **Then** all existing skills, agents, hooks, and scripts function identically through the plugin system.

2. **Given** a downstream project with custom agents and constitutional tweaks, **When** the user runs `claude plugin install sdd-governance`, **Then** the governance plugin enforces all 15 constitutional principles without overwriting project customizations.

3. **Given** two domain plugins installed (sdd-domain-backend, sdd-domain-database), **When** the user disables sdd-domain-database, **Then** all database-related skills, agents, and triggers are immediately unavailable, and backend functionality is unaffected.

4. **Given** a /swarm command with "Build user auth with React UI, Express API, PostgreSQL", **When** the orchestrator analyzes domains, **Then** it spawns appropriate agents in parallel with per-agent budget limits and dependency ordering.

5. **Given** a plugin with success_rate below 0.70, **When** a new version is available in the marketplace, **Then** the system notifies the user and offers one-command update.

6. **Given** a plugin installed from the marketplace, **When** the user runs `claude plugin update sdd-debug`, **Then** the plugin updates without affecting other installed plugins or project customizations.

### Edge Cases
- What happens when a required dependency plugin is not installed? [NEEDS CLARIFICATION: Plugin dependency enforcement mechanism — runtime check vs install-time validation?]
- What happens when two plugins define hooks for the same event? Hook execution ordering must be deterministic with governance hooks always running first.
- What happens when a swarm agent exceeds its budget? The agent must be terminated gracefully with partial work preserved.
- What happens during the transition period when both monolithic and plugin structures coexist? Both must function, with plugins taking precedence.

---

## Requirements *(mandatory)*

### Functional Requirements — Plugin Architecture

- **FR-001**: System MUST decompose the monolithic framework into 13 independent plugins: sdd-governance, sdd-specification, sdd-orchestrator, sdd-git, sdd-creation, sdd-debug, and 7 domain plugins.
- **FR-002**: Each plugin MUST follow the Claude Code plugin standard with `.claude-plugin/plugin.json` manifest, auto-discovered commands/, agents/, skills/, and hooks/.
- **FR-003**: System MUST support hot-swap enable/disable of any plugin except sdd-governance without session restart.
- **FR-004**: System MUST eliminate `skill-index.json` centralized routing in favor of plugin auto-discovery.
- **FR-005**: sdd-governance plugin MUST enforce all 15 constitutional principles across all other installed plugins.
- **FR-006**: Each plugin MUST track independent RL metrics (success_rate, selection_weight, invocation_count, avg_tokens) in its plugin.json.

### Functional Requirements — Multi-Agent Swarm

- **FR-007**: System MUST provide a `/swarm` command that analyzes a task description, detects domains, and spawns coordinated agents.
- **FR-008**: Swarm agents MUST support parallel execution via separate processes with state coordination.
- **FR-009**: System MUST provide agent team templates (research-team, build-team, review-team, full-stack-team) as pre-defined swarm configurations.
- **FR-010**: Each swarm agent MUST have a configurable budget limit (`--max-budget-usd`) with automatic termination on exceed.
- **FR-011**: Swarm coordination MUST use state files (`.claude/multi-agent-swarm.local.md`) for task tracking and dependency management.
- **FR-012**: System MUST support automatic model fallback (`--fallback-model`) when primary model quota is depleted.

### Functional Requirements — Marketplace Distribution

- **FR-013**: System MUST create a GitHub-hosted SDD plugins marketplace repository.
- **FR-014**: All 13 core plugins MUST be installable via `claude plugin install <name>@sdd-marketplace`.
- **FR-015**: Community contributors MUST be able to submit domain plugins to the marketplace.
- **FR-016**: Plugin updates MUST be installable independently without affecting other plugins.

### Functional Requirements — Backwards Compatibility

- **FR-017**: System MUST support a transition period where both monolithic and plugin structures coexist.
- **FR-018**: Existing downstream projects MUST continue working without modification during the transition.
- **FR-019**: Migration tooling MUST be provided to help downstream projects adopt plugins incrementally.

### Non-Functional Requirements

- **NFR-001**: Plugin enable/disable MUST take less than 2 seconds.
- **NFR-002**: Token overhead from plugin system MUST not exceed 10% over current monolithic approach.
- **NFR-003**: Swarm agent spawn time MUST be under 5 seconds per agent.
- **NFR-004**: All plugins MUST have >80% test coverage (Principle II).
- **NFR-005**: Plugin installation from marketplace MUST complete in under 30 seconds.

### Key Entities

- **Plugin**: Self-contained capability module with manifest, skills, agents, hooks, commands, and RL metrics.
- **Plugin Manifest**: JSON descriptor (plugin.json) defining plugin name, version, description, dependencies, and RL metadata.
- **Swarm**: Coordinated group of agents executing a complex task with dependency ordering and budget controls.
- **Swarm State**: Per-agent state file tracking task assignment, dependencies, coordinator session, and budget.
- **Agent Team Template**: Pre-defined swarm configuration specifying agents, execution mode, and budget allocation.
- **Marketplace**: GitHub repository hosting distributable plugins with versioning and community contributions.
- **RL Metrics (per-plugin)**: Success rate, selection weight, invocation count, and token efficiency tracked per plugin.

---

## Phased Delivery Plan

This feature is too large for a single release. It MUST be delivered in phases:

| Phase | Version | Scope | Dependencies |
|-------|---------|-------|-------------|
| **Phase 1: PoC** | v3.2.0 | Convert sdd-governance to plugin, validate hot-swap | None |
| **Phase 2: Core** | v3.3.0 | Convert sdd-specification, sdd-git, sdd-debug, sdd-creation | Phase 1 |
| **Phase 3: Domains** | v3.4.0 | Convert 7 domain plugins, selective install, per-plugin RL | Phase 2 |
| **Phase 4: Swarm** | v4.0.0 | /swarm, team templates, cost controls, marketplace | Phase 3 |
| **Phase 5: Advanced** | v4.1.0 | Agent SDK integration, RL-driven updates, deprecate monolithic | Phase 4 |

---

## Review & Acceptance Checklist
*GATE: Automated checks run during main() execution*

### Content Quality
- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

### Requirement Completeness
- [ ] No [NEEDS CLARIFICATION] markers remain — 1 remains (plugin dependency enforcement)
- [x] Requirements are testable and unambiguous  
- [x] Success criteria are measurable
- [x] Scope is clearly bounded (phased delivery)
- [x] Dependencies and assumptions identified

---

## Execution Status
*Updated by main() during processing*

- [x] User description parsed
- [x] Key concepts extracted
- [x] Ambiguities marked (1 item)
- [x] User scenarios defined (7 stories, 6 acceptance, 4 edge cases)
- [x] Requirements generated (19 FR + 5 NFR)
- [x] Entities identified (7 entities)
- [x] Review checklist passed (1 minor clarification pending)

---
