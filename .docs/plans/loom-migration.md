# Loom Migration Plan

**From**: `sdd-agentic-framework` v5.0.0 (SDD specification waterfall)
**To**: `logic-loom` (brand: **LogicLoom**) — vision → PRD → plan → swarm primary path, with SDD waterfall preserved as legacy
**Style**: Supplementary on workflow (no SDD tool deletions), hard cutover on rename, ~13 staged commits with verification between each
**Authored**: 2026-05-01
**Amended**: 2026-05-01 (v2 — gstack patterns); 2026-05-27 (v3 — supplementary-not-subtractive pivot, project name `logic-loom`, cut only marketplace overbuild + RL telemetry, keep all user-facing tools as legacy alternatives, defer to Anthropic Claude Code marketplace + Docker MCP Toolkit for 3rd-party discovery)

---

## Locked decisions

| Decision | Locked value |
|---|---|
| Project name (technical) | **`logic-loom`** (was `loom` — collision with loom.com) |
| Brand (human-facing) | **LogicLoom** |
| `.specify/` folder rename | **`.logic-loom/`** |
| Marketplace strategy (v3) | Cut our `sdd-marketplace` MCP entirely; defer to Anthropic Claude Code Plugin Marketplace + Docker MCP Toolkit for 3rd-party discovery; bundle LogicLoom plugins in repo |
| Workflow strategy (v3) | **Supplementary**: keep `/specification`, `/build-team`, `/fullstack-team`, `/dev-loop`, `/finalize`, validators, DS-STAR, domain plugins, templates, `specs/` — all as **legacy alternatives**. Add vision/PRD/plan/swarm as **primary documented path** |
| Token cap | **800K of 1M default context** |
| Phase 7 (test failure) recovery | Direct debug loop with agent (no formal re-plan trigger) |
| Evaluator placement | Folded into `/review-team` |
| Constitutional governance | UNTOUCHED (`/initialize-project`, hooks, constitution, `/create-skill`/`agent`/`plugin`) |
| Cloner / framework distribution | UNTOUCHED (`/update-framework`, `.sdd-sync-ref`) |
| `/create-prd` | KEEP — re-targeted as vision → PRD → plan bridge |
| **gstack Q1**: `/plan-review` depth | Single skill with internal CEO + Eng reviewers (promote to parallel-Task only if signal is strong) |
| **gstack Q2**: Codex CLI peer review | NO (declined — API tribunal already cross-models) |
| **gstack Q3**: office-hours placement | Inside `/create-prd` as mandatory forcing-questions section (not a standalone `/clarify`) |
| **gstack Q4**: `/freeze` enforcement | Hook-level (preflight rejects writes outside DAG-declared scope) |
| **gstack Q5**: gstack canonical naming | Decline name; steal "Reflect" phase via `/retro` |

## Scope reminders

**In scope**: Dev workflow scaffolding only. The SDD `/specification` waterfall, `/finalize`, three orchestration overlaps (`/build-team`, `/fullstack-team`, `/dev-loop`), 7 domain plugins, marketplace overbuild, RL infrastructure, DS-STAR / refinement Python, validators, `specs/` directory, project + folder rename.

**Out of scope** (do NOT touch): 16-principle constitution, `.specify/memory/` content, `plugins/sdd-governance/` (except removing the rl-metrics-capture hook), `plugins/sdd-creation/` (except retargeting `/create-prd`), `plugins/sdd-maintenance/`, `plugins/sdd-memory/`, governance preflight hook, dangerous-cmd guard, plugin chassis, cloner init scripts.

---

## Stage overview

| # | Stage | Risk | Reversible? | Parallel? |
|---|---|---|---|---|
| 0 | Pre-flight (snapshot, branch, baseline) | Low | Trivial | No |
| 1 | DELETE **marketplace overbuild only** (mcp-servers/sdd-marketplace + .mcp.json entry) — v3 scope | Low | Yes (revert commit) | No |
| ~~2~~ | ~~DELETE 7 sdd-domain-* plugins~~ — **DROPPED v3**: keep as legacy per supplementary principle | — | — | — |
| ~~3~~ | ~~DELETE /specification waterfall + validators + DS-STAR~~ — **DROPPED v3**: keep as legacy per supplementary principle | — | — | — |
| 4 | DELETE RL telemetry only (internal): .specify/scripts/bash/rl/ + rl-metrics-capture hook + rl_metrics manifest fields + .docs/rl-metrics/ + src/sdd/feedback,metrics/ | Medium | Yes | No |
| 5 | ADD `features/` folder convention + templates | Low | Trivial | No |
| 6 | MODIFY `/swarm` — add `explore` and `implement` modes | Medium | Yes | No |
| 7 | MODIFY `/create-prd` — retarget + add office-hours forcing gate (gstack-A) | Medium | Yes | No |
| **7b** | **NEW** `/plan-review` skill (gstack-B) — single-skill CEO + Eng reviewers | Medium | Yes | No |
| 8 | MODIFY `/review-team` — fold in Playwright + property-based evaluator | Medium | Yes | No |
| 9 | MODIFY `/research` — jury-on-demand tribunal | Medium | Yes | No |
| 10 | ADD plan-as-DAG support (handoff contract for `/swarm implement`) | Medium | Yes | No |
| 11 | ADD hooks bundle: port-namespace + 800K cap + `/freeze` write-scope (gstack-D) | Low | Trivial | **YES — 3 parallel hook authors** |
| **11b** | **NEW** `/retro` skill (gstack-C) — sprint retrospective writing to memory | Low | Yes | No |
| 12 | RENAME `sdd-agentic-framework` → `loom`, `.specify/` → `.loom/` | **HIGH** | Yes (revert commit) | No (atomic by design) |
| 13 | DOCS pass (CLAUDE.md, AGENTS.md, README, START_HERE, CHANGELOG, 3 new arch docs) | Low | Yes | **YES — parallel doc authors** |
| 14 | TEST suite pruning (1322+ → ~150-200) | Medium | Yes | **YES — parallel by suite category** |
| 15 | End-to-end verification (smoke including `/plan-review` and `/retro`) | — | — | No |

Each stage = one git commit. After each stage: run constitutional-check.sh, verify cloner-init still works, `/create-prd` and other retained commands still resolve.

**Parallel-stage execution pattern** (Stages 11/13/14): spawn 2-4 Agent (Task tool) workers with disjoint file-ownership, mirroring the post-migration `/swarm implement` pattern. Each worker scoped to a single output file/dir. After all return, single-author integration pass + commit. All other stages run linearly because they touch coordinated surfaces, have ordering dependencies, or need full coherence.

---

## Stage 0 — Pre-flight

**Goal**: Snapshot pre-migration state, isolate work to a branch.

**Steps** (require user approval per Principle VI):
1. `git tag pre-loom-migration` on main
2. `git checkout -b loom-migration`
3. Run baseline: `./.specify/scripts/bash/constitutional-check.sh` and `npm test`. Document any pre-existing failures.
4. Snapshot file inventory: `find plugins .specify .claude -type f | wc -l` (record count)

**Verify**: Tag exists, branch active, baseline state recorded.

---

## Stage 1 — Delete leaf items

**Goal**: Remove items with no inbound dependencies.

**Affects**:
- `plugins/sdd-dev-loop/` (entire plugin)
- `plugins/sdd-orchestrator/commands/build-team.md`, `fullstack-team.md`
- `plugins/sdd-orchestrator/skills/full-stack-feature/`, `migration-workflow/`, `multi-skill-workflow/` (only the ones backing /build-team, /fullstack-team)
- `plugins/sdd-git/commands/finalize.md`
- `plugins/sdd-git/skills/finalize/`
- `plugins/sdd-git/scripts/finalize-feature.sh`, `sanitization-audit.sh` (sanitization-audit only if not used by /git-push — verify)
- `mcp-servers/sdd-marketplace/` (entire dir)
- `.mcp.json` — remove sdd-marketplace entry

**Steps**:
1. Verify no other plugin's plugin.json declares dependency on these
2. Delete dirs/files
3. Run `.specify/scripts/bash/sync-plugin-commands.sh sync` to remove stub commands from `.claude/commands/`
4. Update `plugins/sdd-orchestrator/.claude-plugin/plugin.json` skill/command counts
5. Update root `CLAUDE.md` and `AGENTS.md` quick-command-reference table

**Verify**: `/swarm`, `/research`, `/review-team`, `/git-push`, `/create-prd`, `/initialize-project`, `/update-framework`, `/create-skill`, `/create-agent`, `/create-plugin` still resolve. constitutional-check.sh passes.

**Risk**: Low. These are leaves.

---

## Stage 2 — Delete 7 `sdd-domain-*` plugins

**Goal**: Remove all domain specialist plugins (~36 skills).

**Affects**:
- `plugins/sdd-domain-frontend/`
- `plugins/sdd-domain-backend/`
- `plugins/sdd-domain-database/`
- `plugins/sdd-domain-testing/`
- `plugins/sdd-domain-security/`
- `plugins/sdd-domain-performance/`
- `plugins/sdd-domain-devops/`

**Steps**:
1. Confirm no plugin manifest declares dependency on any sdd-domain-*
2. Delete the 7 plugin directories
3. Update `.specify/memory/agent-collaboration-triggers.md` — replace specialist routing with `/swarm`-based pattern, OR mark file as deferred-for-rewrite-in-Stage-13
4. Update CLAUDE.md domain-table to reflect that domain delegation now happens via `/swarm explore` (one orchestrator-worker mode replaces 7 specialist routes)
5. Re-sync command bridge

**Verify**: `/swarm`, `/research`, `/review-team` still resolve. Preflight hook still runs (it queries domains.conf — verify it doesn't crash on missing skill targets).

**Risk**: Low. Domain plugins were stateless prompt wrappers per the architectural baseline.

---

## Stage 3 — Delete `/specification` waterfall + validators + DS-STAR

**Goal**: Remove the SDD waterfall machinery entirely. PRD takes its place via `/create-prd` (Stage 7).

**Affects**:
- `plugins/sdd-specification/` (entire plugin: command, skill, scripts)
- `.specify/scripts/bash/create-new-feature.sh`, `setup-plan.sh`, `check-task-prerequisites.sh`
- `.specify/scripts/bash/validate-spec.sh`, `validate-plan.sh`, `validate-tasks.sh`
- `.specify/scripts/bash/sanitize-for-template.sh` (used by SDD templating only — verify)
- `.specify/scripts/python/ds_star_integration.py`
- `.specify/scripts/python/auto_debug_wrapper.py` (T044 auto-debug, tied to dev-loop)
- `.specify/templates/spec-template.md`, `plan-template.md`, `tasks-template.md`, `agent-file-template.md`
- `.specify/templates/skill-prototypes/` (sdd-workflow templates that are SDD-specific)
- `.specify/config/refinement.conf`
- `src/sdd/refinement/` (entire)
- `src/sdd/validation/` (entire — was for spec/plan/tasks validation)
- `specs/` directory contents (keep `specs/README.md` placeholder, OR delete dir entirely; prefer delete)
- `.docs/agents/shared/refinement-state/` (if exists)

**Keep**:
- `.specify/templates/agent-template.md` (used by `/create-agent`)
- `.specify/templates/skill-template.md` (used by `/create-skill`)
- `.specify/templates/prd-template.md` (used by `/create-prd` — will be re-targeted in Stage 7)

**Steps**:
1. Delete plugin and scripts above
2. Delete `specs/` directory
3. Update `.specify/memory/constitution_update_checklist.md` — remove references to validate-* scripts and spec/plan/tasks templates (this is a doc edit, not a constitution change — the principles themselves are untouched)
4. Re-sync command bridge

**Verify**:
- `/create-prd` still works (uses prd-template.md)
- `/initialize-project` still works
- `/create-skill`, `/create-agent`, `/create-plugin` still work
- `constitutional-check.sh` passes (it checks for principle compliance, not for the deleted scripts)

**Risk**: Medium. `constitutional-check.sh` may reference deleted validate-* scripts internally — audit and update before deletion.

---

## Stage 4 — Delete RL infrastructure + remove rl-metrics-capture hook

**Goal**: Strip RL feedback loop. Plugin manifests lose `rl_metrics` field. PostToolUse hook for metrics capture is removed.

**Affects**:
- `.specify/scripts/bash/rl/` (entire dir: collect-feedback.sh, update-skill-weight.sh, sync-metrics.sh, dashboard.sh, select-skill.sh, load-skill-progressive.sh, credit-assignment.sh, grpo-optimizer.sh)
- `plugins/sdd-governance/hooks/scripts/rl-metrics-capture.sh`
- `plugins/sdd-governance/hooks/hooks.json` — remove the PostToolUse entry pointing to rl-metrics-capture
- `src/sdd/feedback/` (RL components)
- `src/sdd/metrics/` (if RL-only; keep observability metrics if applicable)
- `.docs/rl-metrics/skill-performance.json` and dir
- `.docs/architecture/RL-FEEDBACK-ARCHITECTURE.md`
- `.specify/memory/skill-activation-triggers.md` (if purely RL — verify; if it has non-RL routing rules, keep + edit)
- `rl_metrics` field removed from every `plugins/*/.claude-plugin/plugin.json` (script-driven sed)

**Steps**:
1. Audit `skill-activation-triggers.md` — if pure RL weighting, delete; if hybrid, edit
2. Delete RL scripts, Python modules, docs
3. Update governance plugin's hooks.json to drop PostToolUse rl-metrics-capture entry
4. Run a small script to strip `rl_metrics` block from each plugin.json — preserve schema validity
5. Verify other governance hooks (preflight, git-safety-gate) still fire correctly

**Verify**: Submit a test prompt and confirm preflight + git-safety still inject context / gate git commands. constitutional-check.sh passes.

**Risk**: Medium. Governance hooks share a manifest — surgical edit required to remove only the rl-metrics-capture hook entry without breaking the others.

---

## Stage 5 — Add `features/` folder convention + templates

**Goal**: Introduce the new per-feature directory pattern. No code yet uses it; templates ready for Stage 6+.

**Affects**:
- `features/` (new top-level dir)
- `features/README.md` (convention doc)
- `.specify/templates/vision-template.md` (new)
- `.specify/templates/feature-folder-scaffold.md` (new — describes the layout)

**Layout documented**:
```
features/<feature-name>/
├── vision.md
├── exploration/
├── research/
├── prd.md
├── plan.md
└── sprints/
    └── 01-foundations/
```

**Steps**:
1. `mkdir -p features/`
2. Write `features/README.md` describing convention
3. Write vision-template.md (north-star format, design language section, NOT a tight spec)
4. Add `.gitkeep` files where appropriate to commit empty subdirs

**Verify**: `ls features/` shows convention. No existing functionality affected.

**Risk**: Trivial. Pure addition.

---

## Stage 6 — Modify `/swarm` — add `explore` and `implement` modes

**Goal**: Make `/swarm` first-class for the user's two primary modes. Generic mode preserved.

**Affects**:
- `plugins/sdd-orchestrator/skills/team-orchestration/SKILL.md` (add explore + implement procedures)
- `plugins/sdd-orchestrator/commands/swarm.md` (parse mode arg, dispatch)
- `plugins/sdd-orchestrator/scripts/launch-swarm.sh` (mode-aware spawning)
- New: `plugins/sdd-orchestrator/skills/swarm-explore/SKILL.md`
- New: `plugins/sdd-orchestrator/skills/swarm-implement/SKILL.md`

**Behavior**:
- `/swarm explore <topic>` — spawn N read-only investigators. Output → `features/<x>/exploration/<topic>.md`. No write tools allowed.
- `/swarm implement [sprint-name]` — read `features/<x>/plan.md`, dispatch workers per declared sprint with file-ownership boundaries. Output → `features/<x>/sprints/NN-name/`. Sprint-name optional (defaults to next unstarted sprint).
- `/swarm <freeform>` — current generic mode preserved.

**Steps**:
1. Refactor team-orchestration SKILL.md into 3-mode dispatcher
2. Add explore/implement Task Briefs (read-only / write-bounded respectively)
3. Update launch-swarm.sh to honor mode flag
4. Update orchestrator plugin.json skill list

**Verify**: 
- `/swarm explore "auth flow"` writes findings to `features/_test/exploration/auth-flow.md`
- `/swarm implement` errors gracefully when no plan.md is found
- `/swarm "ad hoc query"` works as before

**Risk**: Medium. team-orchestration SKILL.md is heavily used — preserve generic mode.

---

## Stage 7 — Modify `/create-prd` — retarget to vision + research

**Goal**: PRD becomes the vision-to-plan bridge. Inputs change from blank-slate to vision + research + arch context.

**Affects**:
- `plugins/sdd-creation/skills/create-prd/SKILL.md` (rewrite procedure)
- `.specify/templates/prd-template.md` (rewrite for broad-PRD philosophy)
- `plugins/sdd-creation/commands/create-prd.md` (update arg parsing if needed)

**New procedure**:
1. Resolve target feature: arg `<feature-name>` → `features/<feature-name>/`
2. Read `features/<feature-name>/vision.md` (required)
3. Read `features/<feature-name>/exploration/*.md` (optional)
4. Read `features/<feature-name>/research/*.md` (optional)
5. Read `.docs/architecture/*.md` (optional context)
6. **Office-hours forcing-questions gate (gstack-A)** — populate a `## Forcing Questions` section in the PRD answering 6 mandatory items derived from vision + research before any product detail is drafted:
   - Who exactly is this for? (concrete user/persona)
   - What is the smallest valuable thing we could ship? (MVP scope)
   - What does "done" look like at the user-visible level?
   - What are we explicitly NOT doing in this iteration?
   - What is the riskiest assumption?
   - What does success look like quantitatively (or qualitatively if metrics aren't tractable)?
   The model MUST refuse to proceed with PRD synthesis if any of the 6 are unanswered. Inputs from vision/research/exploration cited inline.
7. Synthesize broad PRD — explicitly leave reasoning room for the agent in Phase 5/6 (per Anthropic harness-design article: "if the planner tried to specify granular technical details upfront and got something wrong, the errors in the spec would cascade")
8. Write to `features/<feature-name>/prd.md`

**Template philosophy** (Anthropic harness-design article + gstack office-hours pattern): the PRD declares product context, deliverables, design language, success criteria, and the 6 forcing-question answers — NOT tight implementation specs.

**Verify**: Run `/create-prd test-feature` against a sample vision.md; confirm output is broad, references vision content, and contains a populated `## Forcing Questions` section.

**Risk**: Medium. Existing PRD users will see different output shape — accept this as part of the cutover.

---

## Stage 7b — NEW: `/plan-review` skill (gstack-B)

**Goal**: Block `/swarm implement` from running until `plan.md` passes a multi-perspective review. Mirror of `/review-team` for *plans* rather than code.

**Affects**:
- New: `plugins/sdd-orchestrator/skills/plan-review/SKILL.md`
- New: `plugins/sdd-orchestrator/commands/plan-review.md`

**Behavior** (single-skill design per locked Q1):
- Reads `features/<feature-name>/{vision.md, prd.md, plan.md}`
- Internally invokes two reviewer roles in sequence within one Task context:
  - **CEO review** — scope challenge: aligned with vision and PRD success criteria? Overshoots? Cheaper paths exist?
  - **Eng review** — architecture + test plan: DAG file-ownership coherent? Dependencies right? Rubrics testable? Risks called out?
- Optional 3rd reviewer (Design) opt-in via `--design` flag for UX-heavy plans
- Outputs go/no-go verdict + detailed feedback markdown at `features/<feature-name>/plan-review.md`

**Steps**:
1. Author plan-review SKILL.md with two-reviewer rubric
2. Add slash command stub
3. Update orchestrator plugin.json skill/command counts
4. Document workflow placement in CLAUDE.md (Phase 4.5: between plan-mode and `/swarm implement`)

**Verify**: Run `/plan-review test-feature` against a deliberately broken plan.md (e.g., file-ownership conflict). Confirm Eng review flags it. Run against a clean plan; confirm green.

**Risk**: Medium. Single-skill internal-roles design is the lighter v1; if signal is weak, promote to parallel-Task architecture (cheaper to extend later than to retract).

**Promotion criteria** (post-v6.0): if `/plan-review` false-pass rate exceeds 15% over 10 invocations, refactor to `/review-team`-style parallel Tasks.

---

## Stage 8 — Modify `/review-team` — fold in Playwright + property-based evaluator

**Goal**: External behavioral evaluator becomes a first-class reviewer alongside security/quality/performance.

**Affects**:
- `plugins/sdd-orchestrator/skills/team-orchestration/SKILL.md` (review-team mode)
- New: `plugins/sdd-orchestrator/skills/review-evaluator/SKILL.md`
- `.docs/architecture/evaluator-protocol.md` (new doc — what the evaluator checks)

**Behavior**:
- `/review-team` continues to spawn security + quality + performance reviewers in parallel
- Adds a 4th reviewer: **evaluator** — uses Playwright MCP (snapshot/accessibility-tree mode) for UI behavior, Hypothesis-style property tests for pure functions, behavioral diff against vision.md success criteria
- All four reviewers grade against pre-declared rubrics (Anthropic harness-design article §"Concrete Grading Criteria")
- Synthesizer agent merges; threshold-based pass/fail

**Steps**:
1. Author review-evaluator SKILL.md with rubric (design quality / originality / craft / functionality for UI; coverage / property-test depth / regression detection for libs)
2. Add Playwright MCP integration step (verify Playwright MCP is in user's MCP catalog; if not, add to docs as setup step)
3. Update review-team mode in team-orchestration SKILL.md to include 4th reviewer
4. Update synthesizer to weight evaluator findings

**Verify**: Run `/review-team` against a feature with UI changes — evaluator opens Playwright session and grades.

**Risk**: Medium. Playwright MCP availability is environment-dependent. Document the prerequisite.

---

## Stage 9 — Modify `/research` — jury-on-demand tribunal

**Goal**: Replace static 3-LLM tribunal (Claude+OpenAI+Gemini) with adaptive 2-5 judge selection per query, weighted by predicted reliability.

**Affects**:
- `plugins/sdd-orchestrator/skills/tribunal/` (locate exact path; likely the research skill)
- `plugins/sdd-orchestrator/scripts/launch-tribunal.sh` (or equivalent)

**Behavior** (per arxiv 2512.01786 pattern):
- Query type classifier (heuristic, ~10 categories: factual / architectural / design / security / performance / etc.)
- Per category, declare 2-5 preferred judges with predicted-agreement weights
- Voting: weighted majority instead of unweighted

**Steps**:
1. Document the query-type taxonomy in tribunal SKILL.md
2. Implement classifier (heuristic, prompt-based or regex — keep simple for first pass)
3. Update launch script to honor classifier output
4. Backward-compat: `--judges all` flag preserves the old 3-LLM behavior

**Verify**: Run `/research` on a factual query (expect Claude+OpenAI), an architectural query (expect Claude+Opus+Sonnet), a design query (varies). Confirm cost reduction vs always-3.

**Risk**: Medium. Classifier mis-routes are tolerable in v1; can iterate.

---

## Stage 10 — Plan-as-DAG support

**Goal**: `plan.md` becomes a DAG of tasks with file-ownership scope and per-task acceptance rubric. `/swarm implement` reads waves from DAG topology.

**Affects**:
- `.specify/templates/plan-template.md` (new format — replaces the deleted SDD plan-template)
- `plugins/sdd-orchestrator/skills/swarm-implement/SKILL.md` (DAG-aware dispatch)
- `features/README.md` (document plan format)

**Plan format** (YAML + markdown hybrid):
```yaml
sprints:
  - name: 01-foundations
    tasks:
      - id: t1
        owns: [src/auth/login.ts]
        depends_on: []
        rubric:
          - login form renders
          - submits credentials
      - id: t2
        owns: [src/auth/session.ts]
        depends_on: [t1]
        rubric:
          - session created on success
```

`/swarm implement` topologically sorts tasks within a sprint, dispatches non-conflicting tasks in parallel waves, blocks dependents until parents pass rubric.

**Steps**:
1. Author plan-template.md with sprint/task/DAG format
2. Implement DAG parser in swarm-implement skill
3. File-ownership conflict detection (two tasks owning same file = error before dispatch)
4. Wave scheduler (Kahn's algorithm)
5. Per-task rubric verification (calls evaluator from Stage 8)

**Verify**: Construct a 4-task plan with t1→t2, t1→t3, [t2,t3]→t4. Run `/swarm implement`. Confirm t1 alone, then t2+t3 parallel, then t4.

**Risk**: Medium-high. The DAG executor is the most novel piece. Incremental implementation: start with linear sprint execution, layer on parallelism in iteration.

---

## Stage 11 — Hooks bundle: port-namespace + 800K cap + freeze write-scope (PARALLEL)

**Goal**: Three independent quality-of-life / safety hooks. **Parallel authoring** — spawn 3 Agent workers (Task tool), one per hook, each scoped to a single new file. Single-author integration of `.claude/settings.json` hook registration after all return.

**Affects**:
- New: `.claude/hooks/worktree-port-namespace.sh`
- New: `.claude/hooks/context-cap-warn.sh`
- New: `.claude/hooks/freeze-write-scope.sh` (gstack-D)
- Modified: `.claude/settings.json` (register all three hooks)
- Modified (if needed): `.specify/lib/policy.sh` (extended for freeze-scope checks)

**Hook 1 — Worktree port namespace** (MindStudio/Augment 2026 pattern):
- Fires on session start when in a worktree (detect via `git worktree list`)
- Compute `WORKTREE_INDEX` from worktree path
- Export `PORT_BASE = 3000 + WORKTREE_INDEX*10`, `DB_PORT = 5400 + WORKTREE_INDEX*10`
- Inject as additionalContext on first message of session

**Hook 2 — 800K token cap** (Cognition / Devin pattern, scaled to 1M default):
- Monitors context usage
- At 800K of 1M, inject a strong reset reminder + handoff-artifact prompt
- Prevents "context anxiety" wrap-up bias

**Hook 3 — Freeze write-scope** (gstack-D, Q4 hook-level enforcement):
- Fires on PreToolUse for any write tool (Write, Edit, MultiEdit, NotebookEdit)
- Reads `features/<active-feature>/plan.md` — extracts the current task's `owns:` file list and any `freeze:` declarations
- If write target is outside the active task's owns/freeze scope: reject with explicit error citing the plan-as-DAG declaration
- Default-allow when no DAG-active context (e.g., free-form work outside `/swarm implement`)

**Parallel execution**:
```
Task A: Author worktree-port-namespace.sh   (file: .claude/hooks/worktree-port-namespace.sh)
Task B: Author context-cap-warn.sh           (file: .claude/hooks/context-cap-warn.sh)
Task C: Author freeze-write-scope.sh + extend .specify/lib/policy.sh if needed
```
Each Task receives scoped file ownership. After all three return, single-author registers all three in `.claude/settings.json` and commits the bundle.

**Steps**:
1. Spawn 3 parallel Agent (Task) workers per scope above
2. Integrate returned scripts into `.claude/hooks/`
3. Register hooks in `.claude/settings.json`
4. Test each in isolation: open Claude in a worktree, simulate 800K context, attempt write outside DAG scope
5. Single commit titled "Stage 11: hooks bundle (port-namespace + token-cap + freeze)"

**Risk**: Low. Hooks are isolated. Freeze hook needs careful default-allow-on-no-DAG semantics so it doesn't block legitimate ad-hoc work.

---

## Stage 11b — NEW: `/retro` skill (gstack-C)

**Goal**: Add the Reflect phase missing from Loom's workflow. Sprint retrospective skill consumed post-`/git-push`, feeding learnings into sdd-memory.

**Affects**:
- New: `plugins/sdd-orchestrator/skills/retro/SKILL.md`
- New: `plugins/sdd-orchestrator/commands/retro.md`

**Behavior**:
- `/retro <feature-name>` reads:
  - `features/<feature-name>/sprints/` (per-sprint outputs)
  - `git log --oneline` since branch creation
  - Plan-vs-actual diff (which DAG nodes succeeded first try, which failed-and-retried)
  - Any `/plan-review` feedback files
- Synthesizes a retro markdown at `features/<feature-name>/retro.md` covering:
  - What went well (technical wins, prompt patterns that worked)
  - What didn't (debug loops, scope creep, /freeze trips)
  - Action items (skill prompt updates, hook tuning, plan-template refinements)
- **Writes the action-items section into sdd-memory** as a `feedback` or `project` memory so future sessions inherit the lesson

**Steps**:
1. Author retro SKILL.md with the four-section rubric
2. Add slash command stub
3. Update orchestrator plugin.json
4. Wire memory write through existing `plugins/sdd-memory/scripts/memory-log.sh` (or equivalent)

**Verify**: Run `/retro test-feature` against a feature with a populated sprints/ directory and a known plan-vs-actual divergence. Confirm retro.md is generated and a memory entry is written.

**Risk**: Low. Pure addition. Memory-write is idempotent (memory plugin handles dedup).

---

## Stage 12 — RENAME `sdd-agentic-framework` → `loom`, `.specify/` → `.loom/`

**Goal**: The big rename. Project + folder. Atomic commit so cloner scripts remain functional throughout.

**Affects** (~50+ files):

**Folder rename**:
- `.specify/` → `.loom/`

**Project name references** (search and replace):
- `package.json` — `name` field
- `pyproject.toml` — project name
- `README.md`, `START_HERE.md`, `CHANGELOG.md`
- `CLAUDE.md`, `AGENTS.md`
- `.sdd-sync-ref` → consider renaming to `.loom-sync-ref` (but this breaks /update-framework — keep filename, update content references inside)
- All bash scripts under `.specify/scripts/bash/` referencing `.specify/` paths (now `.loom/`)
- Plugin manifests: any `plugins/*/plugin.json` referencing `.specify/`
- Hook scripts referencing `.specify/`
- Test files referencing `.specify/`
- `.docs/` files referencing the old name (do in Stage 13 docs pass — separate it from the path rename)

**Steps** (single git commit at the end):
1. `git mv .specify .loom`
2. Find-and-replace `.specify/` → `.loom/` across all bash, json, md, py, ts files
3. Find-and-replace `sdd-agentic-framework` → `loom` in: package.json (name field), pyproject.toml, README/START_HERE/CHANGELOG (delicate — keep historical references in CHANGELOG)
4. Run `./.loom/scripts/bash/sync-plugin-commands.sh sync` to confirm bridge still works
5. Run `./.loom/scripts/bash/constitutional-check.sh` to confirm governance still passes
6. Run cloner-init smoke test: `bash init-project.sh` in a sandbox
7. Single commit titled "Rename: sdd-agentic-framework → loom, .specify → .loom"

**Verify**: Cloner-init works. constitutional-check passes. /update-framework still resolves upstream pointer. /create-prd, /initialize-project, /create-skill, /create-agent, /create-plugin all run.

**Risk**: **HIGHEST in the migration**. Breakage modes: (a) bash script using a hard-coded `.specify/` string we missed; (b) plugin.json referencing a path we missed; (c) test file referencing the old name. Mitigation: thorough grep BEFORE the rename, comprehensive grep AFTER, run smoke tests.

**Rollback plan**: `git revert` the rename commit. Migration branch still has all prior stages.

---

## Stage 13 — Documentation pass

**Goal**: Bring all docs in line with new framework shape.

**Affects**:
- `CLAUDE.md` — new workflow diagram, new command reference, drop deleted commands
- `AGENTS.md` — remove deleted agents (none, since we kept all 6 agents), update plugin references
- `README.md`, `START_HERE.md` — new tagline, new quickstart
- `CHANGELOG.md` — entry for v6.0.0 / "Loom"
- `.docs/architecture/` — new `loom-architecture.md` describing vision/PRD/plan/swarm shape
- `.docs/architecture/RL-FEEDBACK-ARCHITECTURE.md` — already deleted in Stage 4
- `.docs/policies/` — review each, drop SDD-specific ones (file-structure-policy may need updates)
- `.specify/memory/agent-collaboration-triggers.md` — wait, this is now `.loom/memory/agent-collaboration-triggers.md`; rewrite domain routing to use `/swarm explore` instead of 7 specialists
- `features/README.md` — finalize convention doc

**Steps** (parallel authoring — spawn 5-6 Agent workers, one per doc family):
1. Worker A: Rewrite CLAUDE.md to reflect 10-phase workflow (vision → research → PRD → plan-review → plan-mode → swarm → review-team → git-push → code-review → retro → exit-worktree)
2. Worker B: Refresh AGENTS.md with current 6-agent registry, drop deleted-plugin references
3. Worker C: Update README + START_HERE + CHANGELOG (CHANGELOG entry for v6.0.0 / "Loom")
4. Worker D: Author `.docs/architecture/loom-architecture.md`
5. Worker E: Author `.docs/architecture/evaluator-protocol.md` (Stage 8 protocol) and `.docs/architecture/freeze-scope-protocol.md` (Stage 11 hook contract)
6. Worker F: Edit `.docs/policies/` — drop SDD-specific policies, update file-structure-policy

After all workers return, single-author integration pass: cross-link the docs (e.g., CLAUDE.md → loom-architecture.md), then single commit.

**Verify**: Read each doc fresh — does it accurately describe the post-migration framework?

**Risk**: Low. Docs.

---

## Stage 14 — Test suite pruning

**Goal**: 1322+ tests → only those validating retained behavior. Estimated ~150-200 retained.

**Affects**:
- `tests/contract/` — keep tests for retained components (governance, /swarm, /research, /review-team, /git-push, /create-prd, /initialize-project, /update-framework, memory plugin)
- `tests/integration/` — same
- `tests/unit/` — same
- `tests/validation/` — likely all deleted (was for SDD validators)

**Steps** (parallel pruning — spawn 3-4 Agent workers, one per test suite category):
1. Worker A: prune `tests/contract/` — keep retained, delete SDD-validator/marketplace/RL tests
2. Worker B: prune `tests/integration/` — same rule
3. Worker C: prune `tests/unit/` — same rule
4. Worker D: prune `tests/validation/` — likely entire deletion (was for SDD validators)

Workers operate on disjoint dirs so parallelism is conflict-free. After return, single-author updates `package.json` coverage thresholds if needed, runs `npm test`, commits.

**Verify**: All retained tests green. Coverage report shows reasonable numbers for retained surface.

**Risk**: Medium. Risk of deleting tests we'll later realize covered governance behavior. Mitigation: when in doubt, keep.

---

## Stage 15 — End-to-end verification

**Goal**: Run the full workflow on a real (small) feature to prove the framework works.

**Test feature**: a minimal end-to-end exercise — pick something simple, e.g., add a dark-mode toggle.

**Steps**:
1. `EnterWorktree` — Claude built-in
2. `/swarm explore "current theming code"` + `/research "dark mode best practices"`
3. Author `features/dark-mode/vision.md` from outputs
4. `/swarm explore "where to wire dark mode in"` + `/research "css variables vs inline"`
5. `/create-prd dark-mode` — verify office-hours 6 forcing questions populated, then PRD broad and references vision/research
6. Plan mode → `features/dark-mode/plan.md` with sprint/task DAG and file-ownership
7. **`/plan-review dark-mode`** — verify CEO + Eng pass; only on green does `/swarm implement` unlock
8. `/swarm implement` — verify wave dispatch, **freeze hook enforces file ownership**
9. Test manually
10. `/review-team` — verify Playwright evaluator runs against UI changes
11. `/git-push` — verify multi-stage approval gates fire
12. `/code-review` (Claude plugin) — review the PR
13. **`/retro dark-mode`** — verify retro.md generated and memory entry written
14. `ExitWorktree`

**Verify**: All 14 steps complete without framework-level errors. Document any rough edges; file follow-up issues.

---

## Risk + rollback notes

**Highest risk stages**: 12 (rename), 10 (DAG executor), 4 (RL hook removal), 11 (freeze hook needs careful default-allow-on-no-DAG semantics).

**Rollback policy**: Each stage = one commit on `loom-migration` branch. Any stage can be reverted via `git revert`. No force-push; no rebase.

**Non-negotiables**:
- `/initialize-project` must keep working at every stage (cloner support)
- `/update-framework` must keep working at every stage (cloner support)
- Constitutional governance hooks must keep firing at every stage
- `constitutional-check.sh` must pass at end of every stage

**Branch protection**: keep main untouched until Stage 15 verifies end-to-end. Then merge `loom-migration` → main as a single squash or as preserved-history depending on user preference.

---

## Verification protocol (run after every stage)

```bash
# 1. Governance still works
./.specify/scripts/bash/constitutional-check.sh        # before Stage 12
./.loom/scripts/bash/constitutional-check.sh           # after Stage 12

# 2. Plugin command bridge works
./.specify/scripts/bash/sync-plugin-commands.sh list   # before Stage 12
./.loom/scripts/bash/sync-plugin-commands.sh list      # after Stage 12

# 3. Retained commands resolve
ls .claude/commands/{create-prd,initialize-project,update-framework,git-push,swarm,research,review-team,create-skill,create-agent,create-plugin}.md

# 4. Cloner-init smoke (sandbox dir)
mkdir /tmp/loom-clone-test && cp -r . /tmp/loom-clone-test && cd /tmp/loom-clone-test && bash init-project.sh

# 5. Tests
npm test
```

---

## What this plan deliberately does NOT include

- Constitutional rewrite (separate later conversation)
- Three-tier memory upgrade (Letta-style; deferred — sdd-memory plugin remains as is for v6.0)
- Speculative execution / selective rollback (deferred — complexity not justified at solo scale)
- Graph memory (rejected)
- Renaming `.sdd-sync-ref` (kept to avoid breaking upstream-tracking in cloned projects)
- Revising `/initialize-project` workflow (untouched; only its references to deleted components in CLAUDE.md / AGENTS.md get updated in Stage 13)
- gstack 23-skill bundle wholesale (only 4 patterns folded in: A office-hours, B `/plan-review`, C `/retro`, D `/freeze`)
- gstack `/codex` cross-CLI hard dep (Q2 declined — API tribunal already cross-models)
- gstack standalone `/clarify` (Q3 declined — folded into `/create-prd` as forcing-questions section instead)
- gstack canonical "Think→Plan→Build→Review→Test→Ship→Reflect" naming (Q5 declined — Loom keeps specific names; only "Reflect" stolen via `/retro`)
- gstack browser primitives, role-played personas, LoC metrics, gbrain MCP (skipped per HN/TechCrunch critique consensus)

These are candidates for future work after Loom v6.0 ships.

---

## Open questions before execution

None blocking. The plan is executable. User to give final go-ahead, then we run Stage 0.
