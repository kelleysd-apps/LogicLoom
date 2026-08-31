---
name: SDD → LogicLoom hybrid pivot (v3 — supplementary, not subtractive)
description: Strategic decision (2026-05-01, refined 2026-05-27) to ADD a vision/PRD/plan/swarm primary workflow alongside the existing SDD waterfall (kept as legacy). Project renamed logic-loom (was sdd-agentic-framework). Cut only internal overbuild (marketplace MCP server + RL telemetry); keep all user-facing tools accessible. SCOPE IS DEV WORKFLOW ONLY — constitutional governance untouched.
type: project
originSessionId: fa3efdd7-669a-41f1-a450-2f778bb4afde
---

# Migration v3: SDD → LogicLoom (supplementary, not subtractive)

**Decided**: 2026-05-01
**Refined**: 2026-05-27 (v3 — switched from subtractive to supplementary; only internal overbuild cut, user-facing tools preserved as legacy)
**Driver**: Anthropic harness-design article + Opus 4.7 capability + user's actual day-to-day workflow + May 2026 4-agent harness research
**Style**: Hard cutover on the rename; **supplementary** on the workflow (keep SDD tools, add LogicLoom primary path)

**STATUS (2026-05-27)**: **IN PROGRESS at Stage 1 (resumed)** — Stage 0 commit `614deb5` on branch `loom-migration` (will be renamed to track logic-loom). Research pass complete (see [[reference_harness_research_2026_05]]). v3 amendments locked. Resuming Stage 1: cut marketplace overbuild only (mcp-servers/sdd-marketplace + .mcp.json entry).

## Critical v3 reframe (2026-05-27)

User pivot: *"i dont want to remove the users ability to use the already existing specification tool etc just make it so the entire framework doesnt rely or revolve around them"*

**Implication**: The migration is no longer "rip and replace" — it's "supplement and reframe." All user-facing tools stay available; LogicLoom's vision/PRD/plan/swarm becomes the **primary documented path**, but `/specification`, `/build-team`, `/fullstack-team`, `/dev-loop`, `/finalize`, validators, DS-STAR, all 7 domain plugins, spec/plan/tasks templates, and `specs/` all REMAIN as **legacy alternatives**.

Only **internal overbuild** is cut:
- `mcp-servers/sdd-marketplace/` (user never sees; replaced by Anthropic Claude Code Plugin Marketplace + Docker MCP Toolkit, both already exist)
- RL telemetry infra (`.specify/scripts/bash/rl/`, rl-metrics-capture hook, `rl_metrics` plugin.json blocks, `.docs/rl-metrics/`, `src/sdd/feedback,metrics/`)

## Locked decisions (consolidated)

### Project identity (2026-05-27)
- **Project name LOCKED**: `sdd-agentic-framework` → **`logic-loom`** (kebab-case, technical)
- **Brand**: **LogicLoom** (human-facing)
- **Folder rename LOCKED**: `.specify/` → **`.logic-loom/`**
- **Why "logic-loom" not "loom"**: collision with loom.com video platform (major brand)

### Marketplace strategy (2026-05-27)
- **Option A locked**: cut our marketplace MCP entirely; defer to Anthropic's official Claude Code Plugin Marketplace for general 3rd-party skill discovery; Docker MCP Toolkit already covers 3rd-party MCP servers; LogicLoom's own plugins bundled in repo (no marketplace publishing needed)
- **Option B explicitly skipped** (publishing LogicLoom plugins to Anthropic marketplace) — plugins are tightly coupled (most depend on sdd-governance); revisit only if specific plugins become standalone-useful
- `/update-framework` unchanged — uses `.sdd-sync-ref` diff, independent of any marketplace

### Workflow strategy (2026-05-27)
- Primary path = vision → research → broad PRD → plan-mode → /swarm sprint/wave → /review-team → /git-push → /code-review → /retro → ExitWorktree
- Legacy path = `/specification` 3-phase waterfall (unchanged code; just no longer the recommended path in docs)
- Both paths share: `/create-prd`, `/create-skill`, `/create-agent`, `/create-plugin`, `/initialize-project`, `/update-framework`, `/git-push`, governance hooks

### gstack patterns adopted (2026-05-01)
- **A**: office-hours forcing-questions inside `/create-prd` (downgrade per 2026-05-26 — section headers in prd-template, not hard refuse-to-proceed gate)
- **B**: `/plan-review` skill (single-skill, internal CEO + Eng reviewers; Faros-study-validated)
- **C**: `/retro` skill (simple — sprints + git log + memory write; no counterfactuals)
- **D**: `/freeze` write-scope hook (hook-level, reads plan DAG ownership)

### May 2026 frontier (2026-05-26 — most deferred)
- **Adopt**: none for v6.0 (stress-test failed — Opus 4.7 doesn't need them)
- **Doc-only**: Coordinator-Implementor-Verifier naming (one paragraph), `/swarm` reservation principle (one line), healing-is-hiding rule (one line)
- **Defer**: STORM arbiter, Policy Invariance smoke-test, async subagents, magentic ledger, auto-detect parallelism (already in Stage 10 as topological sort), cost preview, screen-recording, runtime/db isolation (pending user worktree usage answer)

### Prior locked decisions (2026-05-01)
- Cutover style: hard pivot on rename, supplementary on workflow
- Constitution: DEFERRED — separate review later
- Architectural docs scope: new top-level `features/<name>/`
- Evaluator: folded into `/review-team` (Playwright behavioral, NOT property-based for v6.0)
- Token cap: 800K of 1M context
- Phase 7 (test failure) recovery: direct debug loop with agent
- `/create-prd` strategy: auto-detect (vision.md present → vision-driven; absent → legacy)
- `/research` strategy: simplified jury (1-3 judges by query type; drop "predicted-agreement weights" learned-model part; `--judges all` flag for old 3-LLM behavior)

## User's actual workflow (the thing the framework's PRIMARY path supports)

```
[EnterWorktree]                                      ← Claude built-in
   │
   ▼
1. EXPLORE + IDEA RESEARCH (parallel)
   ├── /swarm explore  └── /research tribunal
   ↓
2. VISION distillation → vision.md
   ↓
3. IMPLEMENTATION DISCOVERY (parallel)
   ├── /swarm explore  └── /research
   ↓
4. PRD (broad, vision-driven) → /create-prd auto-detects mode
   ↓
5. PLAN → Claude plan-mode → plan.md (sprint/wave DAG)
   ↓
6. PLAN-REVIEW → /plan-review (CEO + Eng) blocks /swarm implement until green
   ↓
7. IMPLEMENT → /swarm implement (DAG topological sort, freeze hook enforces ownership)
   ↓
8. TEST + FIX (direct debug loop)
   ↓
9. INTERNAL REVIEW → /review-team (security + quality + perf + Playwright evaluator)
   ↓
10. PR → /git-push
   ↓
11. PR REVIEW → /code-review (Claude OFFICIAL plugin)
   ↓
12. RETRO → /retro writes learnings to memory
   ↓
[ExitWorktree]
```

## Per-feature folder

```
features/<feature-name>/
├── vision.md          # Phase 2
├── exploration/       # Phase 1 + 3
├── research/          # Phase 1 + 3
├── prd.md             # Phase 4 (broad)
├── plan.md            # Phase 5 (DAG with file-ownership)
├── plan-review.md     # Phase 6
├── sprints/           # Phase 7
└── retro.md           # Phase 12
```

## Revised stage list (v3 — 13 stages, was 17)

| # | Stage | Status |
|---|---|---|
| 0 | Pre-flight: tag + branch + baseline | ✓ DONE (commit 614deb5) |
| 1 | Cut **marketplace overbuild only** (mcp-servers/sdd-marketplace + .mcp.json entry) | **IN PROGRESS** |
| ~~2~~ | ~~Delete 7 sdd-domain-* plugins~~ | **DROPPED (v3)** — keep as legacy |
| ~~3~~ | ~~Delete /specification waterfall + validators + DS-STAR~~ | **DROPPED (v3)** — keep as legacy |
| 4 | Cut RL infra + remove rl-metrics-capture hook + strip rl_metrics from manifests | Pending |
| 5 | Add `features/` + vision-template | Pending |
| 6 | `/swarm` — add explore + implement modes (additive, generic preserved) | Pending |
| 7 | `/create-prd` — auto-detect vision-driven vs legacy mode (backward compat) | Pending |
| 7b | NEW `/plan-review` skill | Pending |
| 8 | `/review-team` — fold in Playwright evaluator (additive 4th reviewer) | Pending |
| 9 | `/research` — simplified jury (1-3 judges by query type; `--judges all` backward compat) | Pending |
| 10 | Plan-as-DAG executor in `/swarm implement` | Pending |
| 11 | Hooks bundle: port-namespace + 800K cap + freeze write-scope | Pending |
| 11b | NEW `/retro` skill | Pending |
| 12 | RENAME `sdd-agentic-framework` → `logic-loom`, `.specify/` → `.logic-loom/` | Pending |
| 13 | Docs pass — vision/PRD/plan/swarm as primary; /specification as legacy alternative; point at Anthropic marketplace + Docker MCP Toolkit | Pending |
| 14 | Test pruning — only remove tests for actually-deleted components (marketplace + RL) | Pending |
| 15 | End-to-end smoke (14-step vision→retro cycle) | Pending |

## How to apply when implementing

**Cut**: marketplace MCP server (Stage 1), RL telemetry infra (Stage 4), nothing else from the existing framework.

**Keep**: every user-facing command, every plugin, every template, every script, every doc — unless flagged for new structure (Stages 5, 7b, 11, 11b add NEW; Stages 6, 7, 8, 9, 10 MODIFY existing while preserving backward compat).

**Reframe**: docs (Stage 13) put LogicLoom workflow first; SDD waterfall second.

**Rename** (Stage 12): atomic single commit, ~50+ file references touched. Cloner-init must keep working.

When in doubt: default to KEEP. The v3 principle is "supplement, don't subtract." The only legitimate cuts are internal-only overbuild the user never sees.
