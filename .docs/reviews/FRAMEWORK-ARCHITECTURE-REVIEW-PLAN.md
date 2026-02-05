# Framework Architecture Review Plan

**Version**: 1.0.0
**Created**: 2026-02-04
**Branch**: `review/framework-architecture-audit`
**Status**: IN PROGRESS

---

## Overview

Systematic review of the SDD Agentic Framework to verify all components are functioning correctly after v3.1.3 release.

### Component Summary

| Component | Count | Location |
|-----------|-------|----------|
| Skills | 33 | `.claude/skills/` |
| Agents | 29 | `.claude/agents/` |
| Commands | 11 | `.claude/commands/` |
| Scripts | 39 | `.specify/scripts/` |
| Templates | 11 | `.specify/templates/` |
| Context Modules | 5 | `.claude/context/` |
| Policies | 13 | `.docs/policies/` |

---

## Review Sections

### Section 1: Constitutional Foundation
**Priority**: CRITICAL
**Estimated Time**: 30 min

- [ ] 1.1 Constitution file integrity (`.specify/memory/constitution.md`)
- [ ] 1.2 All 15 principles documented and enforceable
- [ ] 1.3 Version alignment (v1.6.0)
- [ ] 1.4 Constitutional update checklist present
- [ ] 1.5 Governance preflight hook functional

**Validation**: Run constitutional-check.sh

---

### Section 2: Entry Points & Configuration
**Priority**: HIGH
**Estimated Time**: 20 min

- [ ] 2.1 CLAUDE.md completeness and accuracy
- [ ] 2.2 AGENTS.md alignment with agent registry
- [ ] 2.3 settings.json configuration valid
- [ ] 2.4 agent-index.json matches agents directory
- [ ] 2.5 skill-index.json matches skills directory
- [ ] 2.6 .gitignore sanitization rules

**Validation**: Cross-reference indexes with actual files

---

### Section 3: Skills System
**Priority**: HIGH  
**Estimated Time**: 45 min

#### 3.1 Skill Categories
- [ ] Creation skills (2): create-skill, create-template
- [ ] Domain skills (12): api-design, backend, database, devops, frontend, monitoring, performance, schema, security, service-arch, system-design, testing
- [ ] Governance skills (1): governance-preflight
- [ ] Integration skills (2): framework-updater, mcp-server-setup
- [ ] Orchestration skills (3): full-stack-feature, migration-workflow, multi-skill-workflow
- [ ] Project skills (1): project-initialization
- [ ] SDD workflow skills (5): planning-agent, sdd-planning, sdd-specification, sdd-tasks, unified-specification
- [ ] Technical skills (1): debug
- [ ] Validation skills (5): constitutional-compliance, domain-detection, file-organization, message-preflight, qa-validation
- [ ] Git skills (1): git-push-workflow

#### 3.2 Skill Structure Validation
- [ ] All skills have valid SKILL.md frontmatter
- [ ] All skills have rl_metrics section
- [ ] All skills have RL Feedback Loop section
- [ ] All skills have Verifier Integration section
- [ ] Skill-index.json routing is correct

**Validation**: Automated skill audit script

---

### Section 4: Agent System
**Priority**: HIGH
**Estimated Time**: 40 min

#### 4.1 Agent Departments
- [ ] Architecture (2): backend-architect, subagent-architect
- [ ] Data (1): database-specialist
- [ ] Engineering (2): full-stack-developer, frontend-specialist
- [ ] Operations (2): devops-engineer, performance-engineer
- [ ] Product (4): prd-specialist, specification-agent, tasks-agent, task-orchestrator
- [ ] Quality (3): testing-specialist, security-specialist, qa-lead

#### 4.2 Agent Configuration Validation
- [ ] All agents have valid frontmatter
- [ ] Tool access properly configured
- [ ] Constitutional principles referenced
- [ ] Department classification correct
- [ ] Agent-index.json matches agents

**Validation**: Automated agent audit

---

### Section 5: Commands & Workflows
**Priority**: HIGH
**Estimated Time**: 30 min

- [ ] 5.1 /create-prd functional
- [ ] 5.2 /initialize-project functional
- [ ] 5.3 /specification functional (new unified command)
- [ ] 5.4 /git-push functional (new command)
- [ ] 5.5 /debug functional
- [ ] 5.6 /finalize functional
- [ ] 5.7 /create-agent functional
- [ ] 5.8 /create-skill functional
- [ ] 5.9 Deprecated commands have warnings (/specify, /plan, /tasks)

**Validation**: Manual command invocation tests

---

### Section 6: Scripts & Automation
**Priority**: MEDIUM
**Estimated Time**: 35 min

#### 6.1 Core Scripts
- [ ] common.sh (shared functions)
- [ ] constitutional-check.sh
- [ ] sanitization-audit.sh
- [ ] create-new-feature.sh
- [ ] setup-plan.sh
- [ ] check-task-prerequisites.sh
- [ ] finalize-feature.sh
- [ ] load-context.sh

#### 6.2 RL Scripts
- [ ] collect-feedback.sh
- [ ] sync-metrics.sh
- [ ] dashboard.sh

#### 6.3 Script Validation
- [ ] All scripts executable
- [ ] No hardcoded paths
- [ ] Git approval mechanisms present
- [ ] Error handling implemented

**Validation**: Run each script in dry-run mode

---

### Section 7: Templates System
**Priority**: MEDIUM
**Estimated Time**: 20 min

- [ ] 7.1 spec-template.md
- [ ] 7.2 plan-template.md
- [ ] 7.3 tasks-template.md
- [ ] 7.4 quickstart-template.md
- [ ] 7.5 contracts-template.md
- [ ] 7.6 research-template.md
- [ ] 7.7 data-model-template.md
- [ ] 7.8 Template placeholders documented
- [ ] 7.9 Templates referenced correctly in scripts

**Validation**: Template structure audit

---

### Section 8: Context Modules
**Priority**: MEDIUM
**Estimated Time**: 15 min

- [ ] 8.1 core.md - Essential instructions
- [ ] 8.2 agents.md - Agent registry
- [ ] 8.3 skills.md - Skill documentation
- [ ] 8.4 workflows.md - SDD workflows
- [ ] 8.5 governance.md - Constitutional principles
- [ ] 8.6 load-context.sh functional

**Validation**: Load each module and verify content

---

### Section 9: Hooks & Policies
**Priority**: MEDIUM
**Estimated Time**: 20 min

#### 9.1 Hooks
- [ ] governance-preflight.sh functional
- [ ] governance-preflight.js functional
- [ ] hookEventName field present
- [ ] Audit logging working

#### 9.2 Policies
- [ ] file-structure-policy.md
- [ ] todo-architecture-policy.md
- [ ] Other policies present and current

**Validation**: Hook execution test, policy review

---

### Section 10: Documentation & References
**Priority**: LOW
**Estimated Time**: 25 min

- [ ] 10.1 .docs/guides/ complete
- [ ] 10.2 .docs/policies/ current
- [ ] 10.3 .docs/reports/ accurate
- [ ] 10.4 .docs/architecture/ documented
- [ ] 10.5 README files present where needed
- [ ] 10.6 No stale documentation

**Validation**: Documentation audit

---

### Section 11: RL Feedback System
**Priority**: MEDIUM
**Estimated Time**: 20 min

- [ ] 11.1 skill-performance.json structure valid
- [ ] 11.2 EMA algorithm implemented correctly
- [ ] 11.3 Feedback collection working
- [ ] 11.4 Metrics sync functional
- [ ] 11.5 Dashboard displaying correctly
- [ ] 11.6 All skills have rl_metrics

**Validation**: End-to-end RL flow test

---

### Section 12: Integration & Cross-Cutting
**Priority**: HIGH
**Estimated Time**: 30 min

- [ ] 12.1 Skill → Command routing works
- [ ] 12.2 Agent → Skill delegation works
- [ ] 12.3 Context module loading works
- [ ] 12.4 Constitutional compliance check passes
- [ ] 12.5 Sanitization audit passes
- [ ] 12.6 No circular dependencies

**Validation**: Integration test suite

---

## Execution Schedule

| Phase | Sections | Time | Priority |
|-------|----------|------|----------|
| Phase 1 | 1, 2 | 50 min | CRITICAL |
| Phase 2 | 3, 4 | 85 min | HIGH |
| Phase 3 | 5, 6 | 65 min | HIGH |
| Phase 4 | 7, 8, 9 | 55 min | MEDIUM |
| Phase 5 | 10, 11, 12 | 75 min | MEDIUM/HIGH |

**Total Estimated Time**: ~5.5 hours

---

## Report Output

After each section, generate:
1. **Status**: PASS / FAIL / PARTIAL
2. **Issues Found**: List with severity
3. **Recommendations**: Fixes needed
4. **Evidence**: Commands run, output observed

Final report at: `.docs/reviews/FRAMEWORK-ARCHITECTURE-REVIEW-REPORT.md`

---

## Review Progress Tracker

| Section | Status | Issues | Reviewer |
|---------|--------|--------|----------|
| 1. Constitutional Foundation | ⏳ PENDING | - | - |
| 2. Entry Points | ⏳ PENDING | - | - |
| 3. Skills System | ⏳ PENDING | - | - |
| 4. Agent System | ⏳ PENDING | - | - |
| 5. Commands | ⏳ PENDING | - | - |
| 6. Scripts | ⏳ PENDING | - | - |
| 7. Templates | ⏳ PENDING | - | - |
| 8. Context Modules | ⏳ PENDING | - | - |
| 9. Hooks & Policies | ⏳ PENDING | - | - |
| 10. Documentation | ⏳ PENDING | - | - |
| 11. RL System | ⏳ PENDING | - | - |
| 12. Integration | ⏳ PENDING | - | - |

---

**Next Step**: Begin Phase 1 - Constitutional Foundation Review
