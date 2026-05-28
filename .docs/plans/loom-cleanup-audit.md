# LogicLoom Migration — Full Bundle Cleanup Audit

**Generated**: 2026-05-27
**Branch**: `loom-migration` (will rename to align with logic-loom)
**Post-stage**: Stage 1 complete (marketplace cut, commit `3adbcf5`)
**Principle**: v3 supplementary — cut only internal overbuild; keep all user-facing tools as legacy

## Legend

| Symbol | Meaning |
|---|---|
| ✅ CUT | Already cut in a completed stage |
| 🟥 CUT-PLANNED | Slated for cut in current plan (Stage 4 RL) |
| 🟧 RECOMMEND-CUT | I'm recommending adding to cleanup scope (Stage 4b) |
| 🟨 VERIFY | Needs usage check before decision |
| ✓ KEEP | Stays per v3 principle (user-facing or framework infra) |
| 🔵 DEFER | Architectural consideration for later stages |

---

## 1. Plugins (`plugins/`)

| Plugin | Status | Reason |
|---|---|---|
| sdd-creation | ✓ KEEP | User-facing (/create-prd, /create-skill, /create-agent, /create-plugin) |
| sdd-dev-loop | ✓ KEEP | User-facing (/dev-loop) — v3 keeps as legacy |
| sdd-domain-backend | ✓ KEEP | User-facing skills — v3 keeps as legacy |
| sdd-domain-database | ✓ KEEP | Same |
| sdd-domain-devops | ✓ KEEP | Same |
| sdd-domain-frontend | ✓ KEEP | Same |
| sdd-domain-performance | ✓ KEEP | Same |
| sdd-domain-security | ✓ KEEP | Same |
| sdd-domain-testing | ✓ KEEP | Same |
| sdd-git | ✓ KEEP | /git-push, /finalize |
| sdd-governance | ✓ KEEP | Constitutional core, protected |
| sdd-maintenance | ✓ KEEP | /update-framework, /initialize-project, mcp-server-setup |
| sdd-memory | ✓ KEEP | Memory plugin |
| sdd-orchestrator | ✓ KEEP | /swarm, /research, /review-team, /build-team, /fullstack-team |
| sdd-orchestrator-hook | ✓ KEEP | Preflight orchestration |
| sdd-specification | ✓ KEEP | /specification — v3 keeps as legacy |

**Net**: 15 plugins, all kept.

---

## 2. Skills (by plugin) — 33 total

| Plugin | Skill | Status |
|---|---|---|
| sdd-creation | create-agent | ✓ KEEP |
| sdd-creation | create-plugin | ✓ KEEP |
| sdd-creation | create-prd | ✓ KEEP (modify Stage 7) |
| sdd-creation | create-skill | ✓ KEEP |
| sdd-creation | create-template | ✓ KEEP |
| sdd-dev-loop | core-loop | ✓ KEEP (v3 legacy) |
| sdd-domain-backend | api-design | ✓ KEEP |
| sdd-domain-backend | backend-operations | ✓ KEEP |
| sdd-domain-backend | service-architecture | ✓ KEEP |
| sdd-domain-backend | system-design | ✓ KEEP |
| sdd-domain-database | database-operations | ✓ KEEP |
| sdd-domain-database | schema-design | ✓ KEEP |
| sdd-domain-devops | devops-operations | ✓ KEEP |
| sdd-domain-devops | monitoring | ✓ KEEP |
| sdd-domain-frontend | frontend-operations | ✓ KEEP |
| sdd-domain-performance | performance-operations | ✓ KEEP |
| sdd-domain-security | security-operations | ✓ KEEP |
| sdd-domain-testing | testing-operations | ✓ KEEP |
| sdd-git | finalize | ✓ KEEP (v3 legacy) |
| sdd-git | git-push-workflow | ✓ KEEP |
| sdd-governance | constitutional-compliance | ✓ KEEP |
| sdd-governance | domain-detection | ✓ KEEP |
| sdd-governance | file-organization | ✓ KEEP |
| sdd-governance | governance-preflight | ✓ KEEP |
| sdd-governance | message-preflight | ✓ KEEP |
| sdd-governance | qa-validation | ✓ KEEP |
| sdd-maintenance | framework-updater | ✓ KEEP |
| sdd-maintenance | mcp-server-setup | ✓ KEEP |
| sdd-maintenance | project-initialization | ✓ KEEP |
| sdd-memory | context-injection | ✓ KEEP |
| sdd-orchestrator | full-stack-feature | 🔵 DEFER consolidation | overlaps /swarm modes — keep for v3, consider folding later |
| sdd-orchestrator | migration-workflow | 🔵 DEFER consolidation | same |
| sdd-orchestrator | multi-skill-workflow | 🔵 DEFER consolidation | same |
| sdd-orchestrator | team-orchestration | ✓ KEEP (modify Stages 6, 8) |
| sdd-orchestrator-hook | orchestration-guidance | ✓ KEEP |
| sdd-specification | unified-specification | ✓ KEEP (v3 legacy) |

**Skills to ADD** (new in migration):
- 🟢 ADD: sdd-orchestrator/skills/swarm-explore (Stage 6)
- 🟢 ADD: sdd-orchestrator/skills/swarm-implement (Stage 6, 10)
- 🟢 ADD: sdd-orchestrator/skills/review-evaluator (Stage 8)
- 🟢 ADD: sdd-orchestrator/skills/plan-review (Stage 7b)
- 🟢 ADD: sdd-orchestrator/skills/retro (Stage 11b)

**Net**: 33 existing kept + 5 new = 38 skills post-migration.

---

## 3. Agents — 6 total

| Plugin | Agent | Status |
|---|---|---|
| sdd-governance | constitutional-governance-agent | ✓ KEEP |
| sdd-memory | memory-context-agent | ✓ KEEP |
| sdd-creation | subagent-architect | ✓ KEEP |
| sdd-creation | prd-specialist | ✓ KEEP |
| sdd-maintenance | framework-sync-agent | ✓ KEEP |
| sdd-orchestrator | team-synthesizer | ✓ KEEP |

**Net**: 6 agents, all kept. No new agents in migration (all new functionality goes via skills).

---

## 4. Slash commands — 15 total

| Command | Status | Notes |
|---|---|---|
| /build-team | ✓ KEEP | v3 legacy (overlaps /swarm) |
| /create-agent | ✓ KEEP | Framework infra |
| /create-plugin | ✓ KEEP | Framework infra |
| /create-prd | ✓ KEEP (modify Stage 7) | Retarget to vision-driven mode |
| /create-skill | ✓ KEEP | Framework infra |
| /dev-loop | ✓ KEEP | v3 legacy |
| /finalize | ✓ KEEP | v3 legacy |
| /fullstack-team | ✓ KEEP | v3 legacy |
| /git-push | ✓ KEEP | Active workflow |
| /initialize-project | ✓ KEEP | Cloner support |
| /research | ✓ KEEP (modify Stage 9) | Simplified jury |
| /review-team | ✓ KEEP (modify Stage 8) | + Playwright evaluator |
| /specification | ✓ KEEP | v3 legacy |
| /swarm | ✓ KEEP (modify Stage 6) | + explore + implement modes |
| /update-framework | ✓ KEEP | Cloner support |

**Commands to ADD**:
- 🟢 ADD: /plan-review (Stage 7b)
- 🟢 ADD: /retro (Stage 11b)

**Net**: 15 existing + 2 new = 17 commands post-migration.

---

## 5. Bash scripts `.specify/scripts/bash/` — 28 + 8 RL

### Top-level (28)

| Script | Status | Reason |
|---|---|---|
| analyze-logs.sh | 🟨 VERIFY | Internal log analysis — verify usage before cut |
| check-task-prerequisites.sh | ✓ KEEP | Backs /specification (v3 legacy) |
| cleanup-governance-logs.sh | ✓ KEEP | Log retention — useful for users |
| common.sh | ✓ KEEP | Shared bash helpers (sourced everywhere) |
| constitutional-check.sh | ✓ KEEP | Verification gate |
| create-agent-command.sh | 🟨 VERIFY | Possibly internal scaffolder for /create-agent |
| create-agent.sh | ✓ KEEP | Backs /create-agent |
| create-new-feature.sh | ✓ KEEP | Backs /specification (v3 legacy) |
| create-prd.sh | ✓ KEEP | Backs /create-prd |
| create-skill-command.sh | 🟨 VERIFY | Possibly internal scaffolder for /create-skill |
| debug-hook.sh | ✓ KEEP | Hook diagnostic utility |
| detect-phase-domain.sh | ✓ KEEP | Used by preflight orchestration |
| finalize-feature.sh | ✓ KEEP | Backs /finalize (v3 legacy) |
| get-feature-paths.sh | ✓ KEEP | Sourced utility |
| governance-metrics.sh | ✓ KEEP | KPI reports |
| legacy-pattern-report.sh | 🟧 RECOMMEND-CUT | Audit for legacy SDD patterns — stale, not invoked |
| load-context.sh | ✓ KEEP | Modular context loader |
| migrate-agent-to-skill.sh | 🟧 RECOMMEND-CUT | One-time v4→v5 migration tool, conversion complete |
| sanitization-audit.sh | ✓ KEEP | Used by /git-push and /finalize |
| sanitize-for-template.sh | ✓ KEEP | Template hygiene |
| setup-plan.sh | ✓ KEEP | Backs /specification (v3 legacy) |
| skill-coverage-audit.sh | 🟧 RECOMMEND-CUT | Internal audit, not invoked |
| sync-plugin-commands.sh | ✓ KEEP | Plugin command bridge (critical) |
| update-agent-context.sh | 🟨 VERIFY | May be one-time agent migration tool |
| validate-plan.sh | ✓ KEEP | Backs /specification (v3 legacy) |
| validate-spec.sh | ✓ KEEP | Same |
| validate-tasks.sh | ✓ KEEP | Same |
| verify-mcp-toolkit.sh | ✓ KEEP | MCP toolkit health check |

### `.specify/scripts/bash/rl/` (8)

| Script | Status |
|---|---|
| collect-feedback.sh | 🟥 CUT-PLANNED (Stage 4) |
| credit-assignment.sh | 🟥 CUT-PLANNED |
| dashboard.sh | 🟥 CUT-PLANNED |
| grpo-optimizer.sh | 🟥 CUT-PLANNED |
| load-skill-progressive.sh | 🟥 CUT-PLANNED |
| select-skill.sh | 🟥 CUT-PLANNED |
| sync-metrics.sh | 🟥 CUT-PLANNED |
| update-skill-weight.sh | 🟥 CUT-PLANNED |

**Net**: 28 top-level (3 recommend cuts, 3 verify) + 8 RL (all cut) = ~25-28 scripts post-migration.

---

## 6. Python scripts `.specify/scripts/python/` — 3

| File | Status |
|---|---|
| __init__.py | ✓ KEEP |
| auto_debug_wrapper.py | ✓ KEEP | Tied to /dev-loop (v3 legacy) |
| ds_star_integration.py | ✓ KEEP | Tied to /specification (v3 legacy) |

---

## 7. Hooks

### `.claude/hooks/` — 3 files

| File | Status |
|---|---|
| guard-dangerous-commands.sh | ✓ KEEP | Governance |
| user-prompt-submit/governance-preflight.sh | ✓ KEEP | Preflight fallback |
| user-prompt-submit/README.md | ✓ KEEP | Doc |

### Plugin-level hooks — 4 files

| Plugin | Hook | Status |
|---|---|---|
| sdd-governance | governance-preflight.cjs | ✓ KEEP | Active preflight |
| sdd-governance | git-safety-gate.sh | ✓ KEEP | Principle VI enforcement |
| sdd-governance | rl-metrics-capture.sh | 🟥 CUT-PLANNED (Stage 4) |
| sdd-orchestrator | agent-stop-notification.sh | ✓ KEEP | /swarm coordination |

**Hooks to ADD** (Stage 11):
- 🟢 ADD: .claude/hooks/worktree-port-namespace.sh
- 🟢 ADD: .claude/hooks/context-cap-warn.sh
- 🟢 ADD: .claude/hooks/freeze-write-scope.sh

---

## 8. Templates `.specify/templates/` — 7 files + subdirs

| File | Status |
|---|---|
| agent-file-template.md | ✓ KEEP | Used by /create-agent |
| agent-template.md | ✓ KEEP | Same |
| plan-template.md | ✓ KEEP | Used by /specification (v3 legacy); will get new version for Loom plan-as-DAG (Stage 10) |
| prd-template.md | ✓ KEEP (modify Stage 7) | Add office-hours section |
| skill-template.md | ✓ KEEP | Used by /create-skill |
| spec-template.md | ✓ KEEP | v3 legacy |
| tasks-template.md | ✓ KEEP | v3 legacy |
| skill-prototypes/ | ✓ KEEP | Used by /create-skill prototyping |

**Templates to ADD** (Stage 5):
- 🟢 ADD: vision-template.md
- 🟢 ADD: feature-folder-scaffold.md (or features/README.md)

---

## 9. MCP servers `.mcp.json` — 3 entries

| Server | Status |
|---|---|
| docker | ✓ KEEP | Docker MCP Toolkit (310+ servers behind it) |
| browsermcp | ✓ KEEP | Browser automation |
| chrome-devtools | ✓ KEEP | DevTools via MCP — may double as evaluator behavioral tool (Stage 8 decision) |
| ~~sdd-marketplace~~ | ✅ CUT (Stage 1) | Removed in commit 3adbcf5 |

**Open question for Stage 8**: chrome-devtools MCP can drive Playwright-equivalent UI verification. Decide: add Playwright MCP separately, or use chrome-devtools alone?

---

## 10. `src/sdd/` — 7 entries

| Entry | Status |
|---|---|
| __init__.py | ✓ KEEP |
| agents/ | ✓ KEEP | Agent functionality |
| context/ | ✓ KEEP | Context management |
| feedback/ | 🟥 CUT-PLANNED (Stage 4) | RL feedback |
| metrics/ | 🟥 CUT-PLANNED (Stage 4) | RL metrics |
| refinement/ | ✓ KEEP | DS-STAR (tied to /specification v3 legacy) |
| validation/ | ✓ KEEP | Validators (tied to /specification v3 legacy) |

---

## 11. `.specify/memory/` — 6 files

| File | Status |
|---|---|
| agent-collaboration.md | 🟨 VERIFY | Possible duplicate or older version of agent-collaboration-triggers.md |
| agent-collaboration-triggers.md | ✓ KEEP | Domain routing (will update Stage 13) |
| agent-governance.md | ✓ KEEP | Governance-related |
| constitution.md | ✓ KEEP | UNTOUCHED per scope (governance deferred) |
| constitution_update_checklist.md | ✓ KEEP | UNTOUCHED |
| skill-activation-triggers.md | 🟨 VERIFY | Likely RL routing weights — may fold into Stage 4 if pure-RL |

---

## 12. `.specify/lib/` — 5 files

| File | Status |
|---|---|
| json-parse.cjs | ✓ KEEP | Utility |
| parallel.sh | ✓ KEEP | Parallel execution helper |
| logging.sh | ✓ KEEP | Structured logging (Principle VII) |
| policy.sh | ✓ KEEP | Tool restriction policy (Stage 11 extends for freeze) |
| routing/legacy-blocker.sh | ✓ KEEP | Skills-first routing enforcement |

---

## 13. `.specify/config/` — 2 files

| File | Status |
|---|---|
| architecture.conf | ✓ KEEP |
| refinement.conf | ✓ KEEP | Used by validators (v3 legacy) |

---

## 14. `.docs/` — 13 entries

| Entry | Status |
|---|---|
| agents/ | ✓ KEEP |
| architecture/ | ✓ KEEP |
| design/ | ✓ KEEP |
| feature-003-implementation-plan.md | 🟧 RECOMMEND-MOVE | Move to .docs/archive/ (historical completed feature) |
| feature-003-upstream-sync-report.md | 🟧 RECOMMEND-MOVE | Same |
| features/ | ✓ KEEP | Historical feature dirs |
| governance/ | ✓ KEEP |
| guides/ | ✓ KEEP |
| plans/ | ✓ KEEP | Active migration plan lives here |
| policies/ | ✓ KEEP |
| references/ | ✓ KEEP |
| reports/ | ✓ KEEP |
| reviews/ | ✓ KEEP |
| rl-metrics/ | 🟥 CUT-PLANNED (Stage 4) | RL telemetry data |
| troubleshooting/ | ✓ KEEP |

**Docs to ADD** (Stage 13):
- 🟢 ADD: .docs/architecture/loom-architecture.md
- 🟢 ADD: .docs/architecture/evaluator-protocol.md
- 🟢 ADD: .docs/architecture/freeze-scope-protocol.md

---

## Summary of cleanup scope

### Already cut (Stage 1, commit 3adbcf5)
- `mcp-servers/sdd-marketplace/` (entire dir, 7 files, ~68K)
- `.mcp.json` sdd-marketplace entry

### Currently slated for cut (Stage 4 — RL telemetry)
- `.specify/scripts/bash/rl/` (8 scripts)
- `plugins/sdd-governance/hooks/scripts/rl-metrics-capture.sh`
- `plugins/sdd-governance/hooks/hooks.json` PostToolUse entry (surgical)
- `rl_metrics` blocks in all `plugins/*/.claude-plugin/plugin.json` (script-driven)
- `src/sdd/feedback/`, `src/sdd/metrics/`
- `.docs/rl-metrics/`
- `.docs/architecture/RL-FEEDBACK-ARCHITECTURE.md`

### Recommend adding to cleanup scope (proposed Stage 4b)
- `.specify/scripts/bash/migrate-agent-to-skill.sh` (one-time v4→v5 migration tool, complete)
- `.specify/scripts/bash/legacy-pattern-report.sh` (stale audit)
- `.specify/scripts/bash/skill-coverage-audit.sh` (internal audit, not invoked)
- Move `.docs/feature-003-implementation-plan.md` + `feature-003-upstream-sync-report.md` to `.docs/archive/`
- Verify and possibly cut:
  - `.specify/scripts/bash/analyze-logs.sh`
  - `.specify/scripts/bash/create-agent-command.sh` and `create-skill-command.sh`
  - `.specify/scripts/bash/update-agent-context.sh`
  - `.specify/memory/agent-collaboration.md` (possible duplicate)
  - `.specify/memory/skill-activation-triggers.md` (possible RL-only — fold into Stage 4)

### Defer (architectural decisions for later stages)
- Plugin-local script duplication across sdd-{git,specification,orchestrator,governance} (Stage 13 architecture pickup)
- `sdd-orchestrator/skills/full-stack-feature, multi-skill-workflow, migration-workflow` consolidation into /swarm modes (post-v6.0)
- Playwright MCP vs chrome-devtools MCP for Stage 8 evaluator (decide at Stage 8)

### Items to ADD during migration
| Where | What | Stage |
|---|---|---|
| plugins/sdd-orchestrator/skills/ | swarm-explore, swarm-implement, review-evaluator, plan-review, retro (5 new skills) | 6, 7b, 8, 10, 11b |
| plugins/sdd-orchestrator/commands/ | plan-review.md, retro.md (2 new commands) | 7b, 11b |
| .claude/hooks/ | worktree-port-namespace.sh, context-cap-warn.sh, freeze-write-scope.sh (3 hooks) | 11 |
| .specify/templates/ | vision-template.md | 5 |
| features/ | New top-level dir + README.md | 5 |
| .docs/architecture/ | loom-architecture.md, evaluator-protocol.md, freeze-scope-protocol.md | 13 |

---

## Final counts

| Category | Pre-migration | Post-migration |
|---|---|---|
| Plugins | 15 (post Stage 1) | 15 |
| Skills | 33 | 38 (+5) |
| Agents | 6 | 6 |
| Slash commands | 15 | 17 (+2) |
| Bash scripts (top-level) | 28 | ~25 (-3 minimum, possibly -6 after verify) |
| Bash scripts (rl/) | 8 | 0 (-8) |
| Python scripts | 3 | 3 |
| Active hooks | 7 | 9 (+3 new, -1 RL hook) |
| Templates | 8 (incl skill-prototypes/) | 9 (+vision-template) |
| MCP servers | 3 (post Stage 1) | 3 |
| src/sdd/ subdirs | 7 | 5 (-2 RL) |
| .specify/memory/ | 6 | 5-6 (possibly -1 if dupe) |
| .docs/ entries | ~14 | ~14 (+3 new arch docs, -1 RL dir, -2 historical moved to archive) |

Net: Framework gains 5 skills + 2 commands + 3 hooks + 1 template + 1 dir convention; cuts ~10-15 files of internal overbuild + 7 historical/audit scripts.
