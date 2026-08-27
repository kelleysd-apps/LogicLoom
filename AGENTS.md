# LogicLoom Agent Registry

**Version**: 6.5.0
**Last Updated**: 2026-08-17
**Constitution**: v3.3.0 (16 Principles)
**Architecture**: Governance core + interchangeable workflow packs + Plugin-First + Skill-Based Delegation
**Total Agents**: 8 (6 plugin + 2 project-level: deep-reasoner, fast-worker)
**Plugins**: 8

---

## Purpose

This file is the **Single Source of Truth (SSOT)** for agent information in LogicLoom. It provides quick reference for agent selection, capabilities, and usage patterns.

**Relationship to CLAUDE.md** (AGENTS.md is now two-tier):
- `AGENTS.md` **Tier 1** → provider-neutral operating principles + the Cross-Check Disposition (any capable agent / host)
- `AGENTS.md` **Tier 2** → Claude Code host implementation (agent registry, tools, slash commands, hooks, model tiers)
- `CLAUDE.md` → the Claude Code workflow/governance binding (hooks, settings, enforcement)

**Both files MUST be updated together** when agents or the Cross-Check Disposition change (see Tandem Update Rules below). The canonical **Cross-Check Disposition** paragraph must appear verbatim in both `AGENTS.md` (Tier 1) and `CLAUDE.md` (Standing policies) — a contract test asserts this.

> **Plugin-First Architecture**: All agents live within their respective plugins at `plugins/<plugin>/agents/`. The framework root holds no agent definitions outside of plugins.

---

# Tier 1 — Operating Principles & Disposition (any capable agent)

> **Tier 1 is provider-neutral policy that any capable coding agent can follow**
> — Claude Code, OpenAI Codex CLI, Cursor, Gemini CLI, Aider, Copilot, or a
> future host. **Tier 2 (below) is the Claude Code host implementation.**
> Enforcement is host-specific — read the Enforcement Reality banner next.

### ⚠ Enforcement reality on this host

**These principles are MODEL-FOLLOWED unless your host enforces them.**
LogicLoom's deterministic backstops — the git-approval gate, governance-file
protection, subagent-git-mutation-deny, and freeze-write-scope — are **Claude Code
hooks**. They exist **only on the Claude Code host**. On every other host there
is **no automated enforcement** of these rules today: if you skip an approval,
run git autonomously, or write outside your assigned scope, nothing stops you.
Treat the principles below as obligations **you** uphold, with no safety net.
(See `.docs/architecture/governance-threat-model.md` for the honest
enforced-vs-followed matrix by host.)

### Followable principles (self-enforced — no hook required)

- **I Library-First / III Contract-First** — shape features as reusable
  libraries behind explicit contracts.
- **II Test-First** — write the test before the implementation (TDD); keep
  coverage meaningful.
- **VI Git Approval (self-enforced)** — **never execute a git mutation** (commit,
  push, rebase, reset, clean, force) without explicit, in-band human approval for
  that specific operation. On Claude Code a hook forces this; off Claude Code,
  **you** must.
- **X Delegation & Context Isolation** — delegate specialized or parallel work to
  sub-agents for isolation and parallelism (use your host's sub-agent /
  parallel-dispatch mechanism).
- **XV File Organization** — verify a parent dir exists before creating; prefer
  editing an existing file over creating a new one; use absolute paths.
  **Harness ↔ product boundary**: the framework owns the repo root (root
  `package.json`, `tests/`, and the governance dirs); **product application code
  lives in its own workspace** — `web/` for a single app or `apps/<name>/` for a
  monorepo, each product-owned with its own `package.json` / `node_modules` /
  build / test runner. Do not put product source at the root or share the root
  `package.json` / `tests/`. (Claude Code: see CLAUDE.md "Harness ↔ product
  boundary"; full rule `.docs/policies/file-structure-policy.md` § Product
  Workspace.)

### Project amendments (project extension of the floor)

A project may layer its own mandates on top of the principles above. They live in
**`.logic-loom/memory/amendments.md`** (fork-owned; seeded from
`.logic-loom/templates/amendments-template.md`), never inside the constitution
itself — so upstream framework updates never collide with them.

Nothing loads that file, and that is **settled, not pending**. No hook,
preflight, or context module reads it; nothing validates a mandate; nothing fails
closed. A project that does not read it gets no mandates and no warning. So:
**read `amendments.md` if it exists** and treat its mandates as binding alongside
the principles. Mandates are followed policy, never host enforcement.

Wiring the file into a loader was **considered and declined** (2026-08-24) — no
loader is coming, so do not read its absence as unfinished work. A loader would
make mandates *look* enforced without making them enforced: no floor mechanism,
on any host, consults a mandate. What a project gets is a file upstream never
overwrites, a mandate grammar, and the composition rules below, binding on any
agent that reads them. What it does not get is injection, validation, a warning,
or any change in enforcement behaviour.

The only normative unit is a **named mandate**: `### Mandate: <NAME>` with
`Constrains:` / `Rule:` / `Rationale:`. Composition is a conjunction — **effective
governance = the principles AND every mandate**. The principles remain normatively
supreme: a mandate may *tighten* any principle (including the immutable three) or
cover ground the principles are silent on, and may never relax, disable, exempt
from, or override one. There is no field for that, but `Rule` is free natural
language, so a weakening mandate can still be written — the invariant is upheld by
your adjudication, not by the shape of the file.

Adjudicate toward the floor, always: relaxing wording is void in that respect; an
ambiguous mandate takes its tightening reading, and is void if it has none; a
formal tightening that makes a principle impossible to satisfy is void the same
way; two conflicting mandates compose to the stricter obligation, and genuinely
contradicting ones are both void in that respect; validity is per-effect, so a
partly-valid mandate keeps only its valid part. Direction documents such as
`VISION.md` never relax a mandate or a principle.

### Cross-Check Disposition

Cross-Check Disposition — when output correctness materially matters AND the ask invites scrutiny (double-check, cross-check, red-team, peer-review, second opinion, sanity-check, 'are you sure', 'poke holes', 'prove me wrong'), default to a decorrelated second look from a DIFFERENT-PROVIDER model rather than reviewing your own output in-lineage — a same-lineage self-review shares your blind spots. HOST-GATED: On the Claude Code host, this is surfaced as /cross-check (or the cross-provider slot in /review-team / --adversary on /plan-review), which hands a bounded artifact to a non-Claude model; advisory, read-only, key-gated and fail-open. On any host where you are the ONLY model reachable, a self-review is NOT decorrelation — say so plainly, do not label it a cross-check, and proceed. It never blocks and never touches git. Skip it for trivial asks.

### Capability catalog (by what it does)

LogicLoom's durable capabilities, described host-neutrally. Each ends with its
Claude Code binding (Tier 2).

- **Cross-check** — hand a bounded artifact (a diff, a plan, a claim set, a file
  set) to an independent **different-provider** model for adversarial findings;
  advisory + read-only; never writes code or runs git. *(Claude Code:
  `/cross-check`.)*
- **Review** — run multiple specialized reviewers (security, quality,
  performance, behavioral) over a change. *(Claude Code: `/review-team`.)*
- **Plan-review** — gate a plan against scope + architecture before
  implementation. *(Claude Code: `/plan-review`.)*
- **Swarm** — scope-bounded parallel workers under file-ownership isolation.
  *(Claude Code: `/swarm`.)*

### Foreign-host translation

Reading Tier 2 on a non-Claude host: where it says **"the Task tool"**, read
"your host's sub-agent / parallel-dispatch mechanism"; **"slash command `/X`"** →
"the equivalent host workflow, or perform the documented steps manually";
**"`opus`/`sonnet`/`haiku`"** → "your most-capable reasoning model / a
cheaper-faster model".

---

# Tier 2 — Host Implementation (Claude Code)

> **The mechanisms below are specific to the Claude Code host** (settings.json,
> the Task tool, slash commands, PreToolUse hooks, model tiers). Other hosts
> inherit **Tier 1 only** — they do not get the hook enforcement described here.
> The hooks are the Claude Code **implementation** of the Tier 1 rules
> (defense-in-depth), not the source of the obligation.

## Primary Agent (settings.json)

### constitutional-governance-agent (DEFAULT)

**Purpose**: Primary orchestration agent that serves as the **main thread entry point** for all Claude Code sessions. Carries the durable **governance core**, routes specialized work to domain briefs/skills, and relies on hooks to gate all git operations.

| Setting | Value |
|---------|-------|
| **Plugin** | `loom-governance` |
| **Model** | opus (required for governance decisions) |
| **Tools** | Full access (Read, Write, Edit, Bash, Grep, Glob, WebSearch, Task, TaskCreate, TaskUpdate, TaskList, TaskGet, Skill, ToolSearch) |
| **Location** | `plugins/loom-governance/agents/constitutional-governance-agent.md` |

**Configuration**: Hook-based orchestration (no custom `"agent"` field in settings.json). Constitutional governance is injected via the `UserPromptSubmit` preflight hook as `additionalContext`. Claude Code runs with its native capabilities, augmented by hook-injected guidance.

**Governance is hook-enforced, not ceremony-driven.** The mandatory per-message 4-step pre-flight recitation is no longer the default. `LOOM_GOVERNANCE_MODE` (env > `.logic-loom/config/governance.conf` > built-in default) selects:

- **`lean`** (default) — hooks enforce; no per-message compliance recitation. Correct for flagship Opus-class models that follow the governance section of CLAUDE.md directly.
- **`strict`** — hooks enforce **and** the explicit step-by-step compliance assist is re-injected on every message, as a graceful-degradation path for weaker / non-flagship models.

The **git-safety gate** runs as a `PreToolUse` hook and forces explicit approval on any git mutation regardless of mode (Principle VI). The dangerous-command guard and freeze-write-scope hooks likewise run independent of the mode.

**Where the hooks are.** Every one is wired from `.claude/settings.json` at the repo root; that wiring, not the file's location, is what makes it load. The three constitutional guard scripts — `git-safety-gate.sh`, `subagent-git-guard.sh`, `protect-governance-files.sh` — live under `plugins/loom-governance/hooks/scripts/` and are invoked **by path** from root (they do **not** load as plugin hooks). The remaining hooks live under `.claude/hooks/`, with `governance-preflight.sh` one level down in `.claude/hooks/user-prompt-submit/`. To confirm a hook is live, grep `.claude/settings.json` for its path — file existence is not registration. Full table kept in tandem with CLAUDE.md § *LogicLoom Hooks*.

The **subagent git guard** denies MUTATING git from a subagent. A subagent may run explicitly **allowlisted read-only** git (`status`, `log`, `diff`, `show`, branch/tag/stash listings, `rev-parse`, `config --get`, `worktree list`, …); write forms, `fetch`, code-executing global flags (`-c`, `--git-dir`, `--work-tree`, `--exec-path`) and command substitution are denied. The GitHub CLI (`gh`) stays **categorically** denied for subagents, reads included. Kept in tandem with CLAUDE.md § Governance; full statement in `.docs/architecture/governance-threat-model.md` § *The subagent git guarantee*.

**Key Responsibilities** (via hooks):
1. Inject constitutional governance context (lean) or full compliance assist (strict)
2. Detect domains and recommend domain briefs / specialist skills (Principle X)
3. Gate ALL git mutations via the git-safety-gate hook (Principle VI - CRITICAL)
4. Inject relevant project memory context
5. Run worktree-port-namespace, context-cap-warn, and freeze-write-scope hooks

---

## Agent Registry by Plugin

### loom-governance (1 agent)

| Agent | Purpose | Model |
|-------|---------|-------|
| **constitutional-governance-agent** | Primary entry point, governance enforcement | opus |

### loom-orchestrator (1 agent, 11 skills)

| Agent | Purpose | Model |
|-------|---------|-------|
| **team-synthesizer** | Merges multi-LLM parallel outputs; cross-model convergence analysis and tribunal confidence scoring | opus |

> **Note**: task-orchestrator, swarm-coordinator, and workflow-coordinator were converted to enhanced skills (`team-orchestration`, `multi-skill-workflow`) with Task Brief sections in v5.0.0. v6.0.0 added `plan-review` and `retro` skills for the LogicLoom workflow. A `cross-check` skill (governed cross-provider adversarial reviewer) was added later, and a `distillation-pass` skill (backs `/distill`, promotes `.brain/raw/` captures into `.brain/wiki/`) was added after that — a `project-graph` skill backs `/graph` (now **12** skills total in this plugin).

### sdd-specification (0 agents — skill-based)

> All 4 specification agents (specification-agent, planning-agent, tasks-agent, specification-orchestrator) were converted to enhanced skills in v5.0.0. v5.1.0 then **merged those skills into one**: the plugin ships a single skill, `unified-specification`, backing the single `/specification` command. `sdd-specification`, `sdd-planning`, and `sdd-tasks` no longer exist as skills, and `/specify`, `/plan`, `/tasks` no longer exist as commands.

### loom-creation (2 agents)

| Agent | Purpose | Model |
|-------|---------|-------|
| **prd-specialist** | PRD creation (auto-detects vision-driven vs blank-slate mode), product strategy | opus |
| **subagent-architect** | Agent creation, SDD compliance | inherit |

### loom-maintenance (1 agent)

| Agent | Purpose | Model |
|-------|---------|-------|
| **framework-sync-agent** | Framework updates from upstream | opus |

### loom-memory (1 agent)

| Agent | Purpose | Model |
|-------|---------|-------|
| **memory-context-agent** | Searches project memory and injects relevant context via preflight hook | haiku |

### Project-level agents (`.claude/agents/`) — orchestrator + worker ladder

Dev-time delegation ladder: a **frontier orchestrator** (the main session —
Fable 5 → Opus 4.8 fallback; set via `/model`, model-agnostic-but-frontier,
never a non-Claude model) plans/reasons/delegates over cheaper Claude workers.
Kept as **project** agents (not plugin agents, which lose
`hooks`/`mcpServers`/`permissionMode`) so the hook floor still governs them.
Full reference: `.docs/architecture/orchestrator-worker-ladder.md`.

| Agent | Purpose | Model (effort) |
|-------|---------|-------|
| **deep-reasoner** | Architecture decisions, hard debugging, design tradeoffs | opus (high) |
| **fast-worker** | Boilerplate, tests, routine mechanical edits | sonnet (medium) |

> Dispatch inside `/workflow` via `agent(prompt, { agentType: 'deep-reasoner' })`;
> `agent()`'s per-call `effort` supplies dynamic per-dispatch effort (raw Task
> subagents honour only static frontmatter `effort:`). Non-Claude models stay
> **advisory-only** (`/research`, `/cross-check`) — the ladder adds no non-Claude
> workers.

---

## Workflow Packs over a shared governance core

LogicLoom is a durable **governance core** (constitution, hooks, memory, plugin
chassis) plus a set of **interchangeable workflow packs** layered on top. No pack
is "primary" or "legacy" — pick the one that matches the problem shape:

| Pack | Entry points | Best for |
|------|--------------|----------|
| **Vision / swarm** | `vision.md` → `/swarm explore` + `/research` → `/create-prd` → `/plan-review` → `/swarm implement` → `/review-team` → `/retro` | Exploratory or surface-bearing work with a behavioral quality bar |
| **SDD waterfall** | `/specification` (spec → plan → tasks), `/build-team`, `/fullstack-team`, `/finalize` | Well-understood, contract-first features with a fully specified up-front design |

Both packs share the same governance core, plugin chassis, and distribution
machinery. Vision/swarm-internal gates (`vision.md`, `/plan-review`) belong to
that pack, not to the framework as a whole.

### Vision / swarm pack skills (loom-orchestrator)

The vision/swarm pack is built on the following orchestrator skills:

| Skill | Purpose | Backed By |
|-------|---------|-----------|
| `team-orchestration` | Multi-agent swarm coordination (explore + implement + generic) | loom-orchestrator |
| `multi-skill-workflow` | Cross-domain workflow composition | loom-orchestrator |
| `research` | Jury-on-demand multi-LLM research with tribunal cross-validation | loom-orchestrator |
| `cross-check` | Governed cross-provider adversarial reviewer (Codex/GPT default; Gemini pluggable) — advisory + read-only; the slot in `/review-team` + `/plan-review` and the standalone `/cross-check` | loom-orchestrator |
| `plan-review` | CEO + Eng review verdict on `plan.md` before swarm implement | loom-orchestrator |
| `retro` | Post-feature learning capture — what worked, what to change | loom-orchestrator |
| `distillation-pass` | Promotes `.brain/raw/` captures into cited `.brain/wiki/` pages; appends one dated entry to `.brain/DISTILL-LOG.md` on every run, including a zero-op run. A prompt, not an engine — no runner, never runs git | loom-orchestrator |

### `/swarm` modes (3)

The `/swarm` command now operates in three modes, selected via the first argument:

| Mode | Purpose | Worker scope |
|------|---------|--------------|
| `explore <topic>` | Read-only parallel investigations of existing surfaces; outputs land in `features/<feature>/exploration/` | Read-only, no writes |
| `implement [sprint-name]` | Per-sprint scope-bounded workers from `plan.md`; outputs land in `features/<feature>/sprints/NN-name/` | File-ownership DAG enforced by `freeze-write-scope` hook |
| `generic-legacy` | Pre-LogicLoom swarm behavior preserved for backward compatibility | Per legacy team-orchestration skill |

### `/review-team` (4 Claude reviewers + cross-provider adversary)

`/review-team` runs **4 parallel Claude reviewers plus 1 key-gated cross-provider
adversary**:

1. **security-operations** — vulnerability + access control review
2. **performance-operations** — latency, caching, bottleneck review
3. **testing-operations** — coverage + edge case review
4. **behavioral-evaluator** — chrome-devtools MCP / diagnostics, exercises actual UI/API behavior
5. **cross-provider adversary** — the `cross-check` skill (Codex/GPT default). The first four are Claude reviewing Claude (shared blind spots); this slot decorrelates the lineage. Advisory peer signal, **not** a hard gate; fails open to `unavailable` (omitted) if no provider key is set. `--no-adversary` to skip; `--adversary-deep` for read-only repo exploration.

### `/research` (jury-on-demand)

`/research` now selects 1-3 judges based on the query type rather than always running the full tribunal. Pass `--judges all` to force the full 3-judge tribunal (Claude + OpenAI + Gemini).

---

## Domain-Brief Delegation

**Architecture**: Domain expertise lives in a lightweight **domain-brief
registry** inside the governance core — not in standalone specialist plugins.
The former seven `sdd-domain-*` plugins were deleted; their guidance was folded
into one brief per domain at
`plugins/loom-governance/domain-briefs/<domain>.md`.

### How It Works

A coordinator resolves the brief for a detected domain via `get_domain_brief()`
in `.logic-loom/scripts/bash/common.sh`, then injects it as the Task tool prompt
when dispatching a worker:

```
/build-team (or /swarm) → get_domain_brief "backend"
                        → reads plugins/loom-governance/domain-briefs/backend.md
                        → Task(prompt=brief + task, model=<tier>)
```

### Domain → Brief Mapping

| Domain | Keywords | Brief file |
|--------|----------|------------|
| **Frontend** | UI, React, CSS, component | `domain-briefs/frontend.md` |
| **Backend** | API, endpoint, server, service | `domain-briefs/backend.md` |
| **Database** | schema, SQL, migration, query | `domain-briefs/database.md` |
| **Testing** | test, TDD, coverage, QA | `domain-briefs/testing.md` |
| **Security** | auth, encryption, vulnerability | `domain-briefs/security.md` |
| **Performance** | optimize, cache, latency | `domain-briefs/performance.md` |
| **DevOps** | deploy, CI/CD, Docker | `domain-briefs/devops.md` |

All briefs resolve under `plugins/loom-governance/domain-briefs/`.

### Model Strategy

Model tiers resolve via `.logic-loom/config/models.conf` (Principle XIV) using
tier keywords, never pinned version strings:

- **Coordinator** (`architect` → opus): Orchestrates team pipeline, makes architectural decisions
- **Domain Workers** (`worker` → opus by default; switch to sonnet in models.conf for cost): Execute domain-specific tasks using the resolved domain brief
- **File Ownership**: Each worker is assigned file boundaries to prevent conflicts (enforced by `freeze-write-scope` hook)

---

## Non-Domain Agent/Skill Mapping

Quick reference for delegation based on task domain:

| Domain | Keywords | Delegate To | Type | Plugin | Pack |
|--------|----------|-------------|------|--------|------|
| **PRD/Product** | PRD, product, vision, personas | prd-specialist | agent | loom-creation | shared |
| **Specification** | spec, requirements, user story | unified-specification skill | skill | sdd-specification | SDD waterfall |
| **Planning** | implementation plan, research, contracts | unified-specification skill (phase 2) | skill | sdd-specification | SDD waterfall |
| **Tasks** | task list, breakdown | unified-specification skill (phase 3) | skill | sdd-specification | SDD waterfall |
| **Plan review** | /plan-review, plan verdict | plan-review skill | skill | loom-orchestrator | vision/swarm |
| **Retro** | /retro, learnings | retro skill | skill | loom-orchestrator | vision/swarm |
| **Distill** | /distill, .brain, knowledge capture | distillation-pass skill | skill | loom-orchestrator | vision/swarm |
| **Unified spec** | /specification | unified-specification skill | skill | sdd-specification | SDD waterfall |
| **Agent Creation** | create agent, new agent | subagent-architect | agent | loom-creation | shared |
| **Multi-Domain** | 2+ domains detected | team-orchestration skill | skill | loom-orchestrator | vision/swarm |
| **Swarm** | swarm, team, parallel agents | team-orchestration skill | skill | loom-orchestrator | vision/swarm |

---

## Slash Command → Agent/Skill Mapping

| Command | Delegate | Plugin | Purpose |
|---------|----------|--------|---------|
| `/create-prd` | prd-specialist | loom-creation | Create PRD (auto-detects vision-driven vs legacy) |
| `/swarm` | team-orchestration skill | loom-orchestrator | Multi-agent swarm (explore / implement / generic-legacy) |
| `/research` | team-synthesizer | loom-orchestrator | Jury-on-demand multi-LLM research. Final report lands as a capture at `.brain/raw/research/<id>-<slug>.md` (`status: unprocessed`); working intermediates stay in the gitignored `.docs/research/<id>-<slug>/` |
| `/cross-check` | cross-check skill | loom-orchestrator | Governed cross-provider adversarial review (advisory + read-only). Report lands as a capture in `.brain/raw/reviews/<id>-<slug>/` unless a caller passes `--out` |
| `/plan-review` | plan-review skill | loom-orchestrator | CEO + Eng verdict on plan.md (`--adversary` adds cross-provider lens) |
| `/retro` | retro skill | loom-orchestrator | Post-feature learning capture. Memory destination is RESOLVED, never hardcoded — `memory_backend = repo` (default, `.brain/memory/`) or `project`; see `resolve-memory-backend.sh` |
| `/distill` | distillation-pass skill | loom-orchestrator | Promotes `.brain/raw/` captures into `.brain/wiki/`; appends a dated `.brain/DISTILL-LOG.md` entry on every run |
| `/review-team` | 4 reviewers + cross-provider adversary | loom-orchestrator | security + quality + performance + behavioral evaluator + Codex adversary |
| `/git-push` | - | loom-git | Complete git workflow (commit + push + PR) |
| `/code-review` | - | *(external Claude Code command — not shipped by LogicLoom)* | PR-level review |
| `/specification` | unified-specification skill | sdd-specification | SDD waterfall pack — runs spec, plan, and tasks as three sequential phases. There is no separate `/specify`, `/plan`, or `/tasks`: v5.1.0 merged them into this one command |
| `/build-team` | domain briefs + coordinator | loom-orchestrator | SDD waterfall pack — sequential architect→implementor→reviewer |
| `/fullstack-team` | domain briefs + coordinator | loom-orchestrator | SDD waterfall pack — parallel full-stack team |
| `/finalize` | - | loom-git | Pre-commit compliance validation (no git execution) |
| `/create-agent` | subagent-architect | loom-creation | Create new agent |
| `/create-plugin` | subagent-architect | loom-creation | Create new plugin |
| `/update-framework` | framework-sync-agent | loom-maintenance | Framework updates from upstream |
| `/initialize-project` | - | loom-maintenance | Post-PRD project customization (also picks the gate-policy posture) |
| `/scaffold-environments` | environment-scaffolding skill | loom-maintenance | Opt-in scaffolding of the promotion methodology into a new or existing project — detect, propose a delta, write only what is named |
| `/promote-dev` | promotion-lifecycle skill | loom-maintenance | Lowest rung — gates feature branch/worktree → integration branch + dev, then prints the project's seam command. Prompts; skippable |
| `/promote-staging` | promotion-lifecycle skill | loom-maintenance | Middle rung — gates a promotion into the rehearsal environment, then prints the seam command that stands it up and runs the smoke pass |
| `/promote-prod` | promotion-lifecycle skill | loom-maintenance | Top rung — rehearsal contract + promotion order + typed exact phrase no flag bypasses |

The three `/promote-*` commands **gate and confirm; they deploy nothing** — no
cloud or CI call, no deploy command, no migration, seed, teardown, secret or
rollback, and no git. Every action is a call out to the `deploy` seam the product
owns. Methodology: `.docs/policies/environment-promotion-policy.md`. Not to be
confused with `/promote`, the maintainer-only template release driver, which is
stripped from a customer's clone.

---

## Agent Collaboration Workflows

### Vision / swarm pack pipeline

```
vision.md (human — pack-internal gate)
       ↓
/swarm explore + /research (fill gaps)
       ↓
prd-specialist (/create-prd — vision-driven mode)
       ↓
plan mode → plan.md (sprint-structured, file-ownership DAG)
       ↓
/plan-review (CEO + Eng verdict — pack-internal gate on swarm implement)
       ↓
/swarm implement <sprint> (per-sprint scope-bounded workers)
       ↓
test / fix loop
       ↓
/review-team (4 reviewers: security + quality + performance + behavioral)
       ↓
/git-push (commit + PR with explicit approval)
       ↓
/code-review (PR-level)
       ↓
/retro (capture learnings)
       ↓
/distill (promote .brain/raw/ captures into .brain/wiki/, optional/skippable)
```

### SDD waterfall pack pipeline

```
prd-specialist (Phase 0: PRD)
       ↓
unified-specification skill (/specification)
  → phase 1 spec → phase 2 plan → phase 3 tasks (one skill, three phases)
       ↓
[Domain-brief workers for implementation]
       ↓
testing-brief worker (validation)
       ↓
security-brief worker (review)
       ↓
devops-brief worker (deployment)
```

### Multi-Agent Swarm (domain-brief based)

```
User: /swarm implement 02-api-surface
       ↓
Coordinator (Opus): reads plan.md sprint declaration, resolves domain briefs
       ↓
File-ownership DAG enforced by freeze-write-scope hook
       ↓
Phase 1: database-brief worker → schema
       ↓
Phase 2 (parallel):
  ├── backend-brief worker → API
  └── frontend-brief worker → UI
       ↓
Phase 3: testing-brief + behavioral-evaluator
       ↓
Coordinator merges results into features/<feature>/sprints/02-api-surface/
```

---

## Agent File Locations (Plugin-First)

```
plugins/
├── loom-governance/
│   ├── agents/
│   │   └── constitutional-governance-agent.md  (governance core entry)
│   └── domain-briefs/
│       ├── frontend.md  backend.md  database.md
│       ├── testing.md  security.md  performance.md
│       └── devops.md    (7 briefs — replaces the deleted sdd-domain-* plugins)
├── loom-orchestrator/
│   ├── agents/
│   │   └── team-synthesizer.md
│   └── skills/
│       ├── team-orchestration/SKILL.md
│       ├── multi-skill-workflow/SKILL.md
│       ├── research/SKILL.md
│       ├── plan-review/SKILL.md     (v6.0.0)
│       ├── retro/SKILL.md           (v6.0.0)
│       ├── distillation-pass/SKILL.md   (backs /distill)
│       └── ... (12 skills total)
├── sdd-specification/skills/
│   └── unified-specification/SKILL.md   (the only skill; spec+plan+tasks merged in v5.1.0)
├── loom-creation/agents/
│   ├── prd-specialist.md
│   └── subagent-architect.md
├── loom-maintenance/agents/
│   └── framework-sync-agent.md
└── loom-memory/agents/
    └── memory-context-agent.md
```

---

## Constitutional Compliance

All agents enforce Constitution v3.3.0 (16 Principles), the durable governance core for every workflow pack:

### Immutable Principles (I-III)
- **I: Library-First** — Features as standalone libraries
- **II: Test-First** — TDD mandatory, >80% coverage
- **III: Contract-First** — Define contracts before implementation

### Critical Principles
- **VI: Git Approval** — NO autonomous git operations
- **X: Agent Delegation** — Specialized work → specialized agents/skills
- **XVI: Plugin-First** — All capabilities as discrete plugins

### Interchangeable workflow packs
- The vision/swarm and SDD-waterfall packs are **peers** over the
  shared governance core. Neither is privileged. `/specification`, validators,
  `/build-team`, `/fullstack-team`, and `/finalize` are all first-class pack
  entry points — pick the pack that fits the problem shape.

### Project amendments
Constitution v3.3.0 adds a fork extension point: project mandates live in
`.logic-loom/memory/amendments.md` (optional, fork-owned), composed
conjunctively with the 16 principles. Intended additive-only, with precedence
rules that resolve conflict and ambiguity toward the floor — reader-adjudicated,
not grammar-guaranteed, and with no loader, validator, or enforcement behind it.
Agents read it when present.
Reference: `plugins/MANIFEST-SCHEMA.md` (Principle XVI plugin manifests) and
`.docs/policies/shell-idiom-policy.md` (hook/script shell idioms) are the
companion contributor references.

### All Agents Must
- Reference constitution in their system prompt
- Honor `.logic-loom/memory/amendments.md` mandates when the file exists
- Enforce TDD and library-first patterns
- Defer git mutations to the git-safety-gate hook (which forces approval)
- Maintain audit trails
- Follow file organization rules (Principle XV)
- Respect file-ownership DAG and `freeze-write-scope` hook during swarm work

---

## Quick Decision Tree

```
Starting a new feature? ────────────────────→ vision.md → /swarm explore → /create-prd
Reviewing a plan before implement? ────────→ /plan-review (skill, loom-orchestrator)
Running per-sprint workers? ───────────────→ /swarm implement <sprint>
Multi-LLM external research? ──────────────→ /research (jury-on-demand)
Multi-reviewer code/PR review? ────────────→ /review-team (4 reviewers)
Capturing post-feature learnings? ─────────→ /retro (skill, loom-orchestrator)
Building UI components? ───────────────────→ frontend domain brief (via swarm/team)
Designing APIs/services? ──────────────────→ backend domain brief (via swarm/team)
Working with database? ────────────────────→ database domain brief (via swarm/team)
Writing tests? ────────────────────────────→ testing domain brief (via swarm/team)
Security concerns? ────────────────────────→ security domain brief (via swarm/team)
Performance issues? ───────────────────────→ performance domain brief (via swarm/team)
Deploying/CI-CD? ──────────────────────────→ devops domain brief (via swarm/team)
Creating new agent? ───────────────────────→ subagent-architect (agent)
Contract-first, well-understood feature? ──→ /specification (spec + plan + tasks in one command)
```

---

## Tandem Update Rules

**CRITICAL**: CLAUDE.md and AGENTS.md must be updated together.

### When to Update
- Agent added, deleted, or deprecated
- Agent capabilities/tools/model changed
- Plugin restructured
- Command → agent mapping changed
- Constitutional version changes
- Domain skills added or modified

### Update Protocol
1. Update agent/skill file in plugin
2. Update AGENTS.md registry
3. Update CLAUDE.md delegation rules
4. Run `sync-plugin-commands.sh sync` (if commands changed)
5. Run `constitutional-check.sh`
6. Run full test suite

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 6.5.0 | 2026-08-25 | _(primarily a correctness release: the promotion commands and `gate-policy.conf` are the new capability; the bulk of the change set makes existing claims true — a shipped CI gate that broke every cloner, a provenance marker that red-lined customer trees, gates that could not fail, eight scripts violating the documented bash-3.2 floor)_ **User-tunable approval gating**: `gate-policy.conf` (live, `ask`/`silent` per operation, three onboarding postures, a five-operation floor that refuses to be silenced) + permission-mode awareness. **Environment promotion**: `environments.conf` declaration + validator (no deploy engine), `.docs/policies/environment-promotion-policy.md`, `/scaffold-environments`, and the `/promote-dev` → `/promote-staging` → `/promote-prod` lifecycle — gates and confirms, deploys nothing. **Backlog SSOT** split into `.logic-loom/memory/todos.md` (active) + `backlog.md` (deferred), one grammar/id space, published index + tracked offline dashboard behind a fail-closed freshness gate; `project.conf` project identity. **Governance floor**: subagent read-only git allowlist (subagents never *mutate* git, rather than never *touch* it), `gh` mutations + worktree writes gated, command-position matching, forkable-but-unremovable protected-path set, gh-telemetry detect-and-inform. **Honesty passes**: plugin `hooks.json` proven never to load (deleted, not repaired), the sandbox posture corrected to opt-in/off-by-default, `constitutional-check.sh` reports what it actually verified, and a `grep -q`-under-`pipefail` race that scored *passing* assertions as failures fixed across 204 sites |
| 6.4.1 | 2026-08-17 | _(docs/governance; no framework version bump)_ Constitution **v3.3.0** — Project Amendments fork extension point: project mandates live as named mandates in a separate, fork-owned `.logic-loom/memory/amendments.md` (seeded from `amendments-template.md`), composed conjunctively with the 16 principles. Intended additive-only, with precedence rules resolving conflict, contradiction, and ambiguity toward the floor; reader-adjudicated rather than grammar-guaranteed, and explicitly followed-not-enforced (no loader, validator, or fail-closed behaviour). No principle body, numbering, immutability marker, or enforcement claim changed |
| 6.4.1 | 2026-08-13 | Fixes the update path broken for v6.3.1 / v6.4.0 clones: those release PRs were squash-merged, discarding the single-parent snapshot `.sdd-sync-ref` names, so `/update-framework` exited 3 with "`.sdd-sync-ref` is NOT reachable from upstream main". Repo settings corrected (merge commits only). `extract-proposals.sh` auto-remaps the two known-bad baselines to their `main` equivalents; `release-tag.yml` now refuses to tag when the snapshot is not an ancestor of `main`; new `KNOWN_ISSUES.md` + sync-guide section keyed on the error string |
| 6.4.0 | 2026-08-12 | Full contract-suite CI gating — every suite (including Git Safety, covering Principle VI) now gates PRs. Orchestrator + worker ladder shipped with the framework-wide model-agnostic tier-keyword convention; deterministic text-first project graph (`/graph` + `graph-bridge.jsonl`, no engine/daemon); harness↔product and harness↔user boundaries written down. Governance floor hardened: bash 3.2 fail-open closed, dangerous-command matching at command position (not prose), test-runner accounting corrected |
| 6.3.1 | 2026-06-30 | _(docs/config; no framework version bump)_ Orchestrator + worker ladder: model-agnostic-but-frontier orchestrator role (`frontier` tier — Fable 5 → Opus 4.8 fallback) + `deep-reasoner` (opus) / `fast-worker` (sonnet) project agents; `models.conf` gains `LOOM_MODEL_ORCHESTRATOR`/`FRONTIER_MODEL`/`FRONTIER_FALLBACK` + refreshed tier IDs (Sonnet 5); `.docs/architecture/orchestrator-worker-ladder.md`. Non-Claude models stay advisory-only (unchanged) |
| 6.3.1 | 2026-06-30 | _(docs/config; no framework version bump)_ Harness↔product workspace boundary: documented `web/` (single app) / `apps/<name>/` (monorepo) product-workspace convention — root `package.json`/`tests/` framework-owned. Fixed two silent collisions: jest `testMatch`/`roots` scoped + `testPathIgnorePatterns` for `web/`·`apps/`·`src/`, and `.gitignore` no longer drops product specs. `init-project.sh` scaffolds `web/` instead of rebranding root. `file-structure-policy.md` ratified → v1.1.0. New contract test `test_product_workspace_boundary.sh` (wired into CI) |
| 6.2.1 | 2026-06-15 | Constitution **v3.2.0** (Preamble Governance-vs-direction clause). Foundational `VISION.md` as a first-class artifact (peer to the constitution); `/initialize-project` Step 1.5 scaffolds it; new `project-vision-template.md`. dev-main (private) → sanitized **public** template release model: `promote-to-main.yml` (single-parent snapshots), `leak-guard.yml` (public backstop), `strip-harness-dev.sh` + `leak-guard.sh` + `template-strip-manifest.txt` (tracked-content model) |
| 6.3.1 | 2026-06-24 | Release-tooling maintenance: `/promote` maintainer command + `bump-version.sh` + `release-tag.yml` auto-tag-on-merge (maintainer-only/stripped). No customer-facing framework change |
| 6.3.0 | 2026-06-24 | Cross-Check Disposition (primary-agent default for verification-shaped asks) + provider-portable **policy** layer: AGENTS.md Tier-1/Tier-2 split, shared verdict-function seam (`governance-verdicts.sh`, self-protecting; hooks fail-safe), off-host git-approval adapter (`.logic-loom/adapters/`), per-host wiring (`HOSTS.md`), honest enforced-vs-followed matrix. Policy travels; enforcement stays Claude-Code-reference. Phase 4 (orchestration-runtime rewrite) gated |
| 6.2.0 | 2026-05-31 | Removed the dev-loop pack (`loom-dev-loop` / `/dev-loop` / `core-loop` skill) — superseded by Claude Code native `/workflow`, `/loop`, `/goal` primitives; runtime self-extension retired as a governance liability. Two workflow packs (swarm, SDD waterfall); 8 plugins |
| 6.1.0 | 2026-05-28 | Governance core + interchangeable-packs reframe (no primary/legacy); hook-enforced governance with `LOOM_GOVERNANCE_MODE` lean/strict (mandatory 4-step ceremony removed from default); 7 `sdd-domain-*` plugins deleted → domain-brief registry under `plugins/loom-governance/domain-briefs/` via `get_domain_brief()`; constitution v3.1.0; flagship Opus 4.8 via `.logic-loom/config/models.conf`; 9 plugins |
| 6.0.0 | 2026-05-27 | LogicLoom rename + workflow modernization — `/swarm` 3 modes, `/review-team` 4 reviewers, `/research` jury-on-demand, `plan-review` + `retro` skills, vision-driven `/create-prd`, `.logic-loom/` paths |
| 5.1.0 | 2026-03-20 | Dead code cleanup — removed 4 orphaned dev-loop agents, sdd-debug plugin, sdd-domain-template; 6 agents, 16 plugins |
| 5.0.0 | 2026-02-15 | Full skill-based delegation — 3 orchestrator + 4 specification agents converted to skills |
| 4.0.0 | 2026-02-15 | Skill-based domain delegation — 7 domain agents converted to skills, model mixing (Opus/Sonnet) |
| 3.0.0 | 2026-02-07 | Plugin-First Architecture rewrite — command bridge, marketplace |
| 2.1.0 | 2025-12-05 | Added constitutional-governance-agent |
| 2.0.0 | 2025-11-29 | Complete rewrite, constitution v1.6.0 |
| 1.0.0 | 2025-09-19 | Initial creation |

---

**Registry Maintainer**: subagent-architect
**Review Cycle**: On any agent change
**Cross-Reference**: CLAUDE.md, `VISION.md`, `.logic-loom/memory/constitution.md`, `.logic-loom/memory/amendments.md` (fork-owned, optional), `.docs/policies/shell-idiom-policy.md`, `plugins/MANIFEST-SCHEMA.md`, `features/README.md`, `.brain/README.md` (project knowledge layer contract)
