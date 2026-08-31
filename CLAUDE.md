# CLAUDE.md — LogicLoom

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Project (technical)**: `logic-loom`
**Brand**: **LogicLoom**
**Framework folder**: `.logic-loom/`
**Per-feature folder**: `features/<feature-name>/`

LogicLoom is a **Claude-Code-native, governed multi-agent harness** for building
software. Its durable core is **constitutional governance** (hook-enforced). On
top of that core sit **interchangeable workflow packs** — none privileged. Pick
the pack that matches the problem.

---

## Core + Workflow Packs (READ FIRST)

Governance is the **core**; everything else is an **optional workflow pack**.
The packs share the same constitution, plugin chassis, and distribution
machinery. Pick by problem shape — there is no "primary" or "legacy" path:

| Workflow pack | Loop | Best for |
|---|---|---|
| **Swarm** (vision/PRD/plan/swarm) | `vision.md` → `/swarm explore` + `/research` → `/create-prd` → plan mode → `/plan-review` → `/swarm implement` → `/review-team` → `/git-push` → `/retro` | Exploratory or novel work; unclear scope (`features/<name>/`) |
| **SDD waterfall** | `/specification` → `/build-team` / `/fullstack-team` → `/finalize` | Well-understood feature with stable requirements (`specs/###-name/`) |
| _(none)_ | direct execution | Quick fix, no significant unknowns |

The swarm pack's `vision.md` and `/plan-review` are **gates within that pack**
(they prevent broad-spec cascade and worker collisions) — not framework-level
requirements.

### Model & provider boundary

The orchestration + governance runtime is **Claude-Code-native and assumes
Anthropic flagship (Opus-class) models**. Model-tier agnosticism is supported
within Anthropic via role→model config (`.logic-loom/config/models.conf`).
Cross-provider models (OpenAI/Gemini/Mistral) are supported **only at the
delegated research/verification layer** — never for orchestration. Two consumers:
`/research` (multi-LLM tribunal) and `/cross-check` (the governed cross-provider
adversarial reviewer, also the key-gated slot in `/review-team` and
`/plan-review`). In both, the external model is held strictly **advisory +
read-only** — it returns findings; the governed Claude agent triages and decides.
It never writes repo source, runs git, or makes a control-flow decision.

**Portability (superseded stance).** The prior absolute "not a provider-portable
orchestration runtime" is now scoped: the **policy** layer travels to any host —
the constitution, the operating principles, and the Cross-Check Disposition are
provider-neutral, model-followed rules (neutral source: **AGENTS.md Tier 1**).
**Enforcement does not travel**: the hook floor (git-approval gate,
governance-file protection, subagent-git-deny, freeze-write-scope) is the Claude
Code **reference adapter**; on other hosts those guarantees are *followed-only*
until a conformant adapter is supplied. Identity is unchanged — LogicLoom remains
a Claude-Code-native orchestrator whose *policy* is now portable. See the honest
enforced-vs-followed matrix in `.docs/architecture/governance-threat-model.md`.

### Orchestration primitives (ride native; don't reimplement)

LogicLoom is a **governance + dev layer on Claude Code's native orchestration**,
not an orchestration engine. Spawn workers with the **Task tool** (parallel =
multiple Task calls in one message); use **`/workflow`** for deterministic
fan-out (loops, pipelines, adversarial verify) and **`/loop`** for recurring/
self-paced cadence. There is no custom runner (no process manager, session
multiplexer, or shared swarm-state file). What LogicLoom adds on top: hook-enforced
governance, the plan-as-DAG **freeze** file-ownership, the behavioral evaluator,
domain briefs, jury-on-demand `/research`, and memory.

What was removed (not replaced): the `sdd-marketplace` MCP (defer to Anthropic's
Claude Code Plugin Marketplace + Docker MCP Toolkit), the RL telemetry
infrastructure, and the **dev-loop** pack (native `/workflow`/`/loop`/`/goal`
supersede it). Domain specialists were collapsed into a governance-core
**domain-brief registry** (`get_domain_brief`).

---

## Governance

Governance is the durable core of this harness. **Enforcement is hook-side and
model-independent** — you do not need to recite a compliance checklist on every
message. The hooks are the floor; the policies below are the standing intent.

### Hook enforcement (active regardless of model)

All six are wired from **`.claude/settings.json` at the repo root**. Their
scripts sit in two trees — the three git/protection guards under
`plugins/loom-governance/hooks/scripts/`, the rest under `.claude/hooks/` — but
location is not what makes them load; the root wiring is. Exact script paths and
registration keys: **LogicLoom Hooks** below.

| Hook | Enforces |
|---|---|
| `subagent-git-guard.sh` (PreToolUse · Bash) | **Principle VI** — denies MUTATING git from a subagent (detected via `agent_id` in the hook payload). A subagent may run explicitly **allowlisted read-only** git (`status`, `log`, `diff`, `show`, listings, `rev-parse`, `config --get`, …); everything else — write forms, `fetch`, code-executing globals (`-c`, `--git-dir`, `--work-tree`, `--exec-path`), command substitution — is denied. Mutating git stays main-agent + direct-user-request only. `gh` remains categorically denied for subagents. |
| `git-safety-gate.sh` (PreToolUse · Bash) | **Principle VI** — main-agent git mutations force an approval prompt (`permissionDecision: ask`). No autonomous git. |
| `protect-governance-files.sh` (PreToolUse · Write/Edit + Bash) | Edits to the governance surface (`.claude/hooks/`, `settings.json`, `constitution.md`, `governance.conf`, `loom-governance/hooks/`) → subagent **deny** / main **ask**. The model can't silently soften its own rules. |
| `guard-dangerous-commands.sh` (PreToolUse · Bash) | Policy-based dangerous-command blocking (bash 4+; fails open otherwise) |
| `freeze-write-scope.sh` (PreToolUse · Write/Edit) | Plan-as-DAG file ownership during `/swarm implement`; paths canonicalized (`realpath`) so `..`/symlink can't escape `owns:` scope. |
| `governance-preflight.sh` (UserPromptSubmit) | Injects domain guidance + memory context (and, in strict mode, the pre-flight recitation) |

Hooks are a **deterministic floor, not a sandbox.** They make the high-impact
failures hard (autonomous git, a subagent's `git clean`, the model rewriting its
own hooks, writing outside an owned scope) — but a string gate cannot see
interpreter/`eval` indirection or every Bash write path. Treat governance as
defense-in-depth; the known residual bypasses are documented in
`.docs/architecture/governance-threat-model.md`.

### Standing policies (respect without being asked)

- **VI Git Approval** — never run git mutations autonomously; the hook will gate them, but don't try to route around it.
- **II Test-First** — TDD by default; tests before implementation.
- **I Library-First / III Contract-First** — preferences for how features are shaped.
- **X Delegation & Context Isolation** — delegate specialized or parallel work to subagents/swarm for *isolation and parallelism*, not because the base model lacks capability.
- Cross-Check Disposition — when output correctness materially matters AND the ask invites scrutiny (double-check, cross-check, red-team, peer-review, second opinion, sanity-check, 'are you sure', 'poke holes', 'prove me wrong'), default to a decorrelated second look from a DIFFERENT-PROVIDER model rather than reviewing your own output in-lineage — a same-lineage self-review shares your blind spots. HOST-GATED: On the Claude Code host, this is surfaced as /cross-check (or the cross-provider slot in /review-team / --adversary on /plan-review), which hands a bounded artifact to a non-Claude model; advisory, read-only, key-gated and fail-open. On any host where you are the ONLY model reachable, a self-review is NOT decorrelation — say so plainly, do not label it a cross-check, and proceed. It never blocks and never touches git. Skip it for trivial asks. (Neutral source: AGENTS.md Tier 1; the Claude Code preflight hook also nudges toward `/cross-check` on verification-shaped asks.)

### Governance modes (capability-gated assist)

Set via `LOOM_GOVERNANCE_MODE` or `.logic-loom/config/governance.conf`:

- **`lean`** (default) — hooks enforce; no per-message recitation. Correct for
  flagship Opus-class models.
- **`strict`** — hooks enforce **and** the 4-step pre-flight is re-injected each
  message. The graceful-degradation path for weaker / non-flagship models.

Hook enforcement is identical in both modes; only the model-side assist differs.

### Gate policy (which operations interrupt the user)

`.logic-loom/config/gate-policy.conf` is **live** and answers a question the
verdict library deliberately does not: not "does this change the repo?" but "is
that change worth interrupting you?". Two verdicts per operation — `ask` (an
approval prompt) or `silent` (runs without an extra LogicLoom prompt; still
logged, still in the transcript, still subject to the host permission mode).
Shipped posture is `balanced`; `/initialize-project` offers `strict` (everything
asks), `balanced`, and `minimal` (only the floor asks).

**The floor is not tunable.** Five operations — push, history rewriting, repo
admin, secret write, auth — refuse a `silent` setting with a typed reason rather
than silently accepting it, on one test: *a wrong answer leaves the repository,
or a credential, somewhere a revert cannot reach*. Three more are not config keys
at all: protected-file writes, the dangerous-shell guard, and subagent git/gh.
The file is itself on the protected-path list, so a subagent cannot rewrite the
policy and then act under it. There is no wildcard and no "silence everything"
line — weakening the gate costs one line per thing weakened.

---

## Swarm Workflow Pack

One of the interchangeable workflow packs (not privileged). The swarm loop for
exploratory feature work:

```
[EnterWorktree]
    ↓
/swarm explore <topic>   +   /research <question>
    ↓                            (read-only investigations,
features/<x>/vision.md            external cross-validated research)
    ↓
/swarm explore + /research        (fill gaps surfaced by vision)
    ↓
/create-prd <feature>             (broad PRD + office-hours
    ↓                              forcing-questions gate)
plan mode                         (sprint-structured plan.md
    ↓                              with file-ownership DAG)
/plan-review <feature>            (CEO + Eng reviewers — GATES implementation)
    ↓
/swarm implement [sprint]         (DAG topological sort,
    ↓                              freeze hook enforces ownership)
test / fix                        (direct debug loop on failures)
    ↓
/review-team                      (security + quality + performance + evaluator)
    ↓
/git-push                         (commit + PR with explicit approval)
    ↓
/code-review                      (external Claude Code command — PR-level review)
    ↓
/retro <feature>                  (sprint retrospective → memory write)
    ↓
[ExitWorktree]
```

Steps are skippable when justified. Within this pack, `vision.md` and
`/plan-review` are **pack-internal gates** — they prevent broad-spec cascade and
worker collisions. They gate the swarm workflow only, not the harness.

### Per-feature folder layout

```
features/<feature-name>/
├── vision.md             # north-star, intentionally broad
├── exploration/          # /swarm explore outputs (read-only)
├── research/             # /research tribunal outputs
├── prd.md                # broad PRD with forcing-questions
├── plan.md               # sprint/wave-structured plan + file-ownership DAG
├── plan-review.md        # /plan-review verdict (CEO + Eng)
├── sprints/
│   └── NN-name/          # per-sprint worker outputs + evaluator findings
└── retro.md              # /retro learnings (also written to memory)
```

See `features/README.md` for the full convention.

---

## Quick Command Reference — Swarm pack

| Command | Purpose | Plugin |
|---|---|---|
| **`/swarm explore <topic>`** | Read-only parallel investigators; writes to `features/<x>/exploration/` | loom-orchestrator |
| **`/swarm implement [sprint]`** | DAG-driven sprint execution; freeze hook enforces ownership | loom-orchestrator |
| **`/swarm <freeform>`** | Generic multi-agent swarm | loom-orchestrator |
| **`/research <question>`** | Jury-on-demand tribunal (1-3 judges by query type; `--judges all` for full 3-LLM) | loom-orchestrator |
| **`/create-prd <feature>`** | Auto-detects vision-driven vs blank-slate mode; office-hours forcing-questions gate | loom-creation |
| **`/plan-review <feature>`** | CEO + Eng review of plan.md before `/swarm implement` (two internal reviewers) | loom-orchestrator |
| **`/review-team`** | Parallel reviewers: security + quality + performance + behavioral evaluator (chrome-devtools MCP) + key-gated cross-provider adversary | loom-orchestrator |
| **`/cross-check [target]`** | Governed cross-provider adversarial review (Codex/GPT default; Gemini pluggable). Non-Claude lineage tears apart a diff/plan/claims/file scope; advisory + read-only, never git. Canonical path for all cross-check reviews | loom-orchestrator |
| **`/git-push`** | Commit + push + PR creation with explicit user approval at each gate | loom-git |
| **`/retro <feature>`** | Sprint retrospective; writes action items to loom-memory | loom-orchestrator |
| **`/distill`** | Promotes `.brain/raw/` captures into `.brain/wiki/` pages; appends one dated entry to `.brain/DISTILL-LOG.md` on every run, including a zero-op run. A prompt, not an engine — no runner, no scheduler shipped, never runs git | loom-orchestrator |

---

## Quick Command Reference — SDD waterfall pack + tooling

| Command | Purpose | Plugin |
|---|---|---|
| `/specification` | Unified SDD waterfall — spec, plan, tasks in one command | sdd-specification |
| `/build-team` | Sequential architect → implementor → reviewer | loom-orchestrator |
| `/fullstack-team` | Parallel frontend + backend + database workers (domain briefs) | loom-orchestrator |
| `/finalize` | Pre-commit compliance validation (no git execution) | loom-git |
| `/create-agent` | Create specialized subagent | loom-creation |
| `/create-plugin` | Create new LogicLoom plugin | loom-creation |
| `/create-skill` | Create new skill | loom-creation |
| `/update-framework` | Check and apply upstream enhancements | loom-maintenance |
| `/initialize-project` | Post-PRD project customization | loom-maintenance |

Domain detection (preflight hook): keywords map to a **domain brief** in the
governance-core registry, injected into swarm/team workers via `get_domain_brief`
(see `plugins/loom-governance/domain-briefs/`). The seven domains —
frontend, backend, database, testing, security, performance, devops — are briefs,
not separate plugins.

For new work, prefer `/swarm explore` over individual specialist routing.

---

## Quick Command Reference — Environment promotion

`/promote-dev` → `/promote-staging` → `/promote-prod` is a **promotion
lifecycle, not a deploy engine**. Each rung gates and confirms — it checks the
declared promotion order and asks for confirmation whose strength escalates with
blast radius (prompt at dev and staging; a **typed exact phrase that no flag, env
var, or non-interactive path bypasses** at prod). The **rehearsal attestation is
read at prod only**: `/promote-prod` is the sole caller that passes
`--require-rehearsal` to `promote-gate.sh`, so dev and staging neither read nor
require one. It then calls out to the `deploy` seam your project owns.
The harness itself runs no cloud or CI call, no deploy command, no migration,
seed, teardown, secret or rollback — and no git. Methodology, evidence grades,
and the portable patterns: `.docs/policies/environment-promotion-policy.md`.

| Command | Purpose | Plugin |
|---|---|---|
| `/scaffold-environments` | Opt-in scaffolding of the promotion methodology into a new or existing project; detects what the repo already has, proposes a delta, writes only what you name | loom-maintenance |
| `/promote-dev` | Lowest rung — gates a feature branch/worktree into the integration branch and the dev environment, then prints the project's deploy-seam command. Prompts; skippable | loom-maintenance |
| `/promote-staging` | Middle rung — gates a promotion into the rehearsal environment, then prints the seam command that stands it up and runs the smoke pass rehearsing `/promote-prod` | loom-maintenance |
| `/promote-prod` | Top rung — rehearsal contract + promotion order + typed exact phrase. `--yes` is read and explicitly reported as ignored | loom-maintenance |

Confirmation strength resolves **target environment's declared `confirm` →
command default → none**, so a project can raise dev to a typed phrase or lower
prod to a prompt. The ladder is guidance, not rails — but weakening it is
reported loudly. (Distinct from **`/promote`**, the maintainer-only template
release driver, which is stripped from a customer's clone.)

---

## Constitution Principles

**ALWAYS read `.logic-loom/memory/constitution.md` BEFORE starting any work.**

The constitution (v3.3.0) contains **16 enforceable principles**. Enforcement is
hook-side (see the **Governance** section above); the list below is a quick map.

- **3 Immutable** (I-III): Library-First, Test-First, Contract-First
- **6 Quality & Safety** (IV-IX): Idempotency, Progressive Enhancement, Git Approval, Observability, Documentation Sync, Dependency Management
- **7 Workflow & Delegation** (X-XVI): Agent Delegation, Input Validation, Design System, Access Control, AI Model Selection, File Organization, Plugin-First Architecture

### Critical Principles Quick Reference

| Principle | Requirement | Consequence |
|---|---|---|
| **II (Test-First)** | TDD mandatory, >80% coverage | IMMUTABLE — blocks merge |
| **VI (Git Approval)** | NO autonomous git operations | CRITICAL — hook-gated (`git-safety-gate.sh` / `subagent-git-guard.sh`) |
| **X (Agent Delegation)** | Specialized work → specialists or `/swarm` | CRITICAL — delegate or violate |
| **XVI (Plugin-First)** | Capabilities as installable plugins | CRITICAL — all new features as plugins |

(Git operations under Principle VI are detailed in the **Governance** section above.)

### Project amendments (the fork extension point)

A fork adds project-specific mandates in **`.logic-loom/memory/amendments.md`**
(seeded from `.logic-loom/templates/amendments-template.md`) — never by editing
`constitution.md`. Upstream never ships `amendments.md`, so a fork's mandates
survive `/update-framework` and the constitution stays byte-identical to upstream
instead of becoming a permanent `conflict-review` file.

**Followed, not enforced — and nothing loads it. That is settled, not pending.**
No hook, preflight, or context module reads `amendments.md`; nothing validates a
mandate; nothing fails closed. A fork that does not read the file gets no
mandates and gets no warning. Mandates work only because this file and
`AGENTS.md` tell agents to read them. Read `.logic-loom/memory/amendments.md`
when it exists and treat its mandates as binding alongside the principles.

Wiring `amendments.md` into `governance-preflight.sh` was **considered and
declined** (2026-08-24) — there is no loader coming, so do not read the absence
as unfinished work. A loader would make mandates *look* enforced without making
them enforced: the hook floor would still never consult a mandate, so the only
thing gained is a stronger impression of enforcement than the mechanism can
support. What a fork gets is a file upstream never overwrites, a mandate grammar,
and composition rules binding on any agent that reads them. What it does not get
is injection, validation, a warning, or any change in hook behaviour.

The only normative unit is a **named mandate**: `### Mandate: <NAME>` with
`Constrains:` / `Rule:` / `Rationale:`. There is no second surface — no in-line
project markers in the constitution, no per-principle override blocks.

Composition is a conjunction: **effective governance = constitution AND every
mandate**. The constitutional floor stays normatively supreme; mandates are
intended to add obligations only, and any relaxing effect is invalid. That
invariant is **adjudicated, not structural**: the grammar has no `Overrides` /
`Waives` field, but `Rule` is unrestricted natural language, so a mandate *can*
weaken a principle semantically — by redefinition, by broadening what counts as
approval, by constraining enforcement rather than behaviour, or by making
compliance vacuous. The missing verb makes weakening conspicuous, not impossible.

Adjudication defaults, all failing toward the floor: relaxing wording is **void in
that respect**; an ambiguous mandate is read under its tightening interpretation
(and is void if it has none); a formal "tightening" that makes a principle
impossible to satisfy is void the same way; conflicting mandates compose to the
stricter obligation, and genuinely contradicting ones are both void in that
respect; validity is assessed per-effect, so a partly-valid mandate keeps only its
valid part. `VISION.md` sets direction and never relaxes a mandate. Mandates are
policy, not enforcement: they cannot touch a hook. Full statement including the
precedence order: `.logic-loom/memory/constitution.md` § *Project Amendments*.

---

## LogicLoom Hooks

**Every hook is wired from one place: `.claude/settings.json` at the repo root.**
That root wiring — not the file's location — is what makes a hook load. Scripts
live in two trees, and the split is deliberate:

- **`plugins/loom-governance/hooks/scripts/`** — the three constitutional guard
  scripts. They ship with the governance plugin but do **not** load as plugin
  hooks; the repo's `plugins/` tree is not a plugin *installation* (no
  `marketplace.json`, nothing in `~/.claude/plugins/`), so a per-plugin
  `hooks/hooks.json` is never read. They run only because root `settings.json`
  invokes them **by path**. Consequence: deleting the plugin's files would leave
  the root wiring pointing at missing scripts and thin the floor silently.
- **`.claude/hooks/`** — the repo-local hooks (plus `user-prompt-submit/`, one
  level down).

To confirm a hook is live, grep `.claude/settings.json` for its path — file
existence alone is not registration.

| Hook | Script path | Wired from `.claude/settings.json` |
|---|---|---|
| `subagent-git-guard.sh` | `plugins/loom-governance/hooks/scripts/` | `PreToolUse` · matcher `Bash` |
| `git-safety-gate.sh` | `plugins/loom-governance/hooks/scripts/` | `PreToolUse` · matcher `Bash` |
| `protect-governance-files.sh` | `plugins/loom-governance/hooks/scripts/` | `PreToolUse` · **both** matchers (`Bash`, and `Write\|Edit\|MultiEdit\|NotebookEdit`) |
| `guard-dangerous-commands.sh` | `.claude/hooks/` | `PreToolUse` · matcher `Bash` |
| `freeze-write-scope.sh` | `.claude/hooks/` | `PreToolUse` · matcher `Write\|Edit\|MultiEdit\|NotebookEdit` |
| `governance-preflight.sh` | `.claude/hooks/user-prompt-submit/` | `UserPromptSubmit` |
| `context-cap-warn.sh` | `.claude/hooks/` | `UserPromptSubmit` |
| `worktree-port-namespace.sh` | `.claude/hooks/` | `SessionStart` |
| `check-dev-branch-base.sh` | `.logic-loom/scripts/bash/` | `SessionStart` **and** `UserPromptSubmit` (via `--event`) |

What each one enforces (Principle mapping included) is in the **Governance**
section above; that table covers the six governance hooks, while this one lists
all nine wired hooks — the same set plus the three non-floor hooks below.
`check-dev-branch-base.sh` (LOOM-0024) is a detect-only branch-base advisory —
it warns when a worktree was based on the sanitized `main` snapshot instead of
`dev-main`, and by its own contract never runs git, never writes, and never
blocks. It is not part of the governance floor; it is listed here only because
`settings.json` runs it on every prompt.

---

## MCP Server Configuration

LogicLoom relies on **two external ecosystems** for MCP discovery — we no
longer ship our own marketplace MCP.

1. **Anthropic Claude Code Plugin Marketplace** — first-party plugin
   discovery and install. Use `/plugin` Claude Code commands and the
   marketplace browser to find third-party plugins.
2. **Docker MCP Toolkit** — 310+ containerized MCP servers via the unified
   gateway.

| Tool | Purpose |
|---|---|
| `mcp-find` | Search 310+ servers in Docker catalog |
| `mcp-add` | Add server to current session dynamically |
| `mcp-config-set` | Configure server credentials |
| `mcp-exec` | Execute tools from any enabled server |
| `code-mode` | Combine multiple MCP tools in JavaScript |

**Security notes**:
- Store all MCP credentials in `.env` (never commit)
- Use `env:VAR_NAME` syntax in MCP configuration
- Docker Toolkit provides container isolation (1 CPU, 2GB RAM limits)

---

## Plugin Registry

All framework capabilities are **discrete installable plugins** under
`plugins/`. Bundled in-repo (not via marketplace).

| Plugin | Layer | Notes |
|---|---|---|
| `loom-governance` | governance core (protected) | Constitutional enforcement, hooks, domain-brief registry |
| `loom-memory` | core | Memory context injection, `/retro` writes |
| `loom-orchestrator-hook` | core | Preflight domain detection + worker-brief recommendations |
| `loom-creation` | core tooling | `/create-prd`, `/create-skill`, `/create-agent`, `/create-plugin` |
| `loom-git` | core tooling | `/git-push`, `/finalize` |
| `loom-maintenance` | core tooling | `/update-framework`, `/initialize-project`, `/scaffold-environments`, `/promote-dev`, `/promote-staging`, `/promote-prod`, and the maintainer-only `/promote` (stripped at release) |
| `loom-orchestrator` | swarm pack | `/swarm` (explore/implement/freeform), `/research`, `/cross-check`, `/plan-review`, `/review-team`, `/retro`, `/distill`, `/build-team`, `/fullstack-team` |
| `sdd-specification` | SDD pack | `/specification` unified waterfall (keeps `sdd-` — it *is* the SDD workflow) |

Domain expertise is no longer a plugin: the 7 domains (frontend/backend/database/
testing/security/performance/devops) are **briefs** in
`loom-governance/domain-briefs/`, injected via `get_domain_brief`.

**This table is parsed, not just read.** `tests/contract/test_bash32_floor.sh`
takes it as the harness's declaration of which plugins under `plugins/` are
harness-owned, and holds exactly those to the bash 3.2 floor. A plugin **you**
build (via `/create-plugin` or by hand) is not in this table, so your shell is
not scanned — you choose your own runner. Listing your plugin here opts it into
the floor. Two guards keep that from going soft: a declared plugin with no
directory fails the suite, and so does any `loom-*` / `sdd-*` directory the
table does **not** declare — so a harness plugin cannot be dropped from the scan
by quietly dropping a row. Do not name your own plugin `loom-*` or `sdd-*`.

### Plugin command bridge

Commands are synced from plugins to `.claude/commands/` via the bridge:

```bash
.logic-loom/scripts/bash/sync-plugin-commands.sh sync      # sync all commands
.logic-loom/scripts/bash/sync-plugin-commands.sh list      # show command → plugin map
```

---

## Key Architecture

### Directory structure

```
VISION.md                              # Foundational product north-star (living; peer to the constitution)

.logic-loom/
  memory/
    constitution.md                    # 16 principles (v3.3.0) — upstream core, do not fork-edit
    amendments.md                      # OPTIONAL, fork-owned: project named mandates (additive only)
    todos.md                           # Level-0 SSOT, ACTIVE half — cross-cutting non-feature work
                                       # being worked / next up / waiting on an answer already asked for
    backlog.md                         # Level-0 SSOT, DEFERRED half — same grammar, same id space,
                                       # different question: "what should I bring up later".
                                       # Split so today's item isn't buried between two you
                                       # decided six weeks ago not to do. Grammar is normative
                                       # in backlog.md; todos.md points at it (one parser, one id
                                       # space, next id DERIVED via lint-backlog.sh --next-id)
    constitution_update_checklist.md
  scripts/bash/                        # Workflow automation + plugin bridge
  templates/                           # vision-template, prd-template, plan-template, ...
  config/
    governance.conf                    # Governance mode (lean / strict)
    models.conf                        # Documented role→tier convention + current flagship
    gate-policy.conf                   # LIVE — which git/gh operations ask vs run silent
    project.conf                       # Project identity (slug / name / id_prefix). Ships UNSTAMPED
                                       # (`__UNSET__`) so no cloner inherits our slug
    environments.conf                  # Environment + promotion-order DECLARATION. Ships FULLY
                                       # COMMENTED OUT — an active default would assert a topology
                                       # a cloner does not have. Declaration only; no deploy engine
    memory-backend.conf                # LIVE — one key, memory_backend = repo | project.
                                       # PROTECTED (declared via protected_paths in governance.conf)
    brain.conf                         # Advisory thresholds for the .brain/ liveness/load signal.
                                       # PROTECTED, same as memory-backend.conf above
    architecture.conf, framework-upstream.conf
  lib/                                 # Shared shell libs (policy.sh, logging.sh)

plugins/                               # See registry above

.claude/
  commands/                            # Bridge-generated from plugins
  context/                             # Modular context loaders
  hooks/                               # Governance + LogicLoom hooks

features/                              # Swarm pack: per-feature workspaces (vision/PRD/plan/sprints/retro)
specs/                                 # SDD pack: waterfall specs

.brain/                                # Project knowledge layer: raw/ (immutable captures), wiki/
                                       # (concepts/ + decisions/, cited sources), index/ (human
                                       # pointers), memory/ (durable memory; the default backend),
                                       # DISTILL-LOG.md. Ships holding only README.md; created on
                                       # first use, same treatment as artifacts/ and web/. Stripped
                                       # at template release except the README, which is stubbed.
                                       # Contract: `.brain/README.md`. See "Project knowledge layer"
                                       # below for the promotion path and the three-signal table

artifacts/                             # Standalone deliverables: who/what/why/where —
                                       # vision, research, forensics, docs. NEVER a plan
                                       # (sequencing belongs to plan.md / tasks.md).
                                       # Create on first use; contents are project-owned
                                       # and are stripped at template release.
                                       # Mostly hand-authored + committed; a GENERATED
                                       # deliverable belongs here too and is ALSO tracked
                                       # (artifacts/backlog-dashboard.html) — licensed by
                                       # the fail-closed freshness gate
                                       # .logic-loom/scripts/bash/check-generated-freshness.sh.
                                       # Its machine intermediate (.logic-loom/backlog-index.json)
                                       # stays gitignored: track only what a human opens.

web/  (or apps/<name>/)                # Product app (own package.json) — see Harness ↔ product boundary

.docs/
  architecture/loom-architecture.md    # Full architectural reference (LogicLoom shape)
  policies/
```

The repo root (`package.json`, `tests/`, `.claude/`, `.logic-loom/`, `plugins/`)
is **framework-owned**; product application code lives in `web/` / `apps/<name>/`.
See **Harness ↔ product boundary** under File Creation Rules.

### Workflow scripts

| Script | Purpose |
|---|---|
| `common.sh` | Shared functions + git approval |
| `constitutional-check.sh` | 16-principle compliance validator |
| `sync-plugin-commands.sh` | Plugin → `.claude/commands/` bridge |
| `load-context.sh` | Modular context loading |
| `resolve-memory-backend.sh` | Resolves `memory_backend` (`repo` default / `project`) to a path (`--path` / `--backend` / `--ensure` / `--explain`). A pure function of env + config — it never probes the filesystem to pick a default. Fail-SAFE: a bad value warns on stderr and falls back to `repo` rather than aborting a write. Runs no git; writes nothing unless `--ensure` |
| `check-brain-signals.sh` | ADVISORY only — `.brain/` liveness + load, plus the stranded-legacy-memory migration notice. Never blocks, never writes, never runs git. Not a hook and not part of the governance floor |
| `check-brain-record.sh` | CI, beside `check-generated-freshness.sh` — record-integrity gate for `.brain/`. FAIL-CLOSED but vacuously green on an absent or README-only `.brain/`. Reads frontmatter and file existence only, never a wiki page's body |

Pre-commit compliance check:
```bash
./.logic-loom/scripts/bash/constitutional-check.sh
```

---

## File Creation Rules (Principle XV)

**ALWAYS verify before creating files or folders.**

1. **Verify Before Create**: Check parent directory exists before writing
2. **Edit Over Create**: Prefer modifying existing files
3. **Templates First**: Use `.logic-loom/templates/` when available
4. **Absolute Paths**: Always use absolute paths from repository root
5. **No Proactive Docs**: Never create README.md or other documentation files unless explicitly requested

### Harness ↔ product boundary

The **framework owns the repo root** — root `package.json`, `tests/`, `.claude/`,
`.logic-loom/`, and `plugins/` are framework-owned. **Product application code
lives in its own workspace**, each product-owned with its own `package.json`,
`node_modules`, build, and test runner:

- **Single app** → `web/`
- **Monorepo** → `apps/<name>/` (one self-contained workspace per app)

Do **not** put product source at the repo root or share the root
`package.json` / `tests/` — that trips the framework's jest-glob and coverage
gates — a jest-glob collision that sweeps product tests into the framework's
`npm test`, and a coverage collision between the framework's
`collectCoverageFrom` scope and product code at the root. Product specs (`specs/<feature>/`)
and feature work (`features/<name>/`) are tracked. Full rule:
`.docs/policies/file-structure-policy.md` (§ Product Workspace).

### Harness ↔ user boundary

Sibling concept to the product boundary above, on the other side: **LogicLoom
never writes to `~/.claude/`.** The harness governs this repo only — its hooks,
constitution, plugins, and commands are all in-repo. Never edit a user's global
`CLAUDE.md`, `settings.json`, hooks, commands, or agents; if a change belongs
there, say so and let the user make it.

**Personal working preferences** — how the assistant talks to them, persona,
response shape, their own model/orchestration taste, their own global hooks —
belong in `~/.claude/CLAUDE.md`. The project `CLAUDE.md` is for repo-specific
facts only, since every cloner reads it. Note that plugin commands like
`/cross-check` don't travel with those preferences — they exist only inside a
LogicLoom project.

**Hooks compose**: user-level hooks and this repo's governance hooks both fire,
and decisions combine most-restrictive. A personal hook cannot weaken the
governance floor (Principle VI and the protected-surface hooks still hold), but
it can add friction of its own.

**Versioning personal config**: `~/.claude/` should stay out of git — it holds
session state and secrets-adjacent material. The workable pattern is a separate
private repo of *reference copies* for manual diffing; the tradeoff is that those
copies drift silently from the live files unless the user adds their own check.
Do not recommend symlinking or automating it, and do not ship tooling for it.
User-facing version: `START_HERE.md` § *Where do my personal preferences go?*

### Naming conventions

| Type | Pattern | Example |
|---|---|---|
| LogicLoom feature dir | `<kebab-name>/` | `features/auth-cookie-rotation/` |
| Sprint dir | `NN-name/` | `sprints/01-foundations/` |
| Agent file | `[role]-[function].md` | `plan-reviewer.md` |
| Skill folder | `[skill-name]/` | `swarm-implement/` |
| Legacy SDD feature | `###-[name]/` | `specs/001-user-auth/` |

**Policy**: `.docs/policies/file-structure-policy.md`

---

## Task Management

### Three-level task hierarchy

| Level | Location | Purpose |
|---|---|---|
| **Project (swarm pack)** | `features/<name>/plan.md` (DAG) and `features/<name>/sprints/NN-name/` | Sprint plan + per-sprint worker outputs |
| **Project (SDD pack)** | `specs/###-feature/tasks.md` | SDD waterfall task checklist |
| **Session** | TaskCreate/TaskUpdate tools | Active work tracking |

### Task tool rules (CRITICAL)

1. **ONE task `in_progress`** at any time — never multiple
2. **Mark `completed` IMMEDIATELY** via TaskUpdate — don't batch completions
3. **Use TaskCreate for 3+ step tasks** — skip for trivial single-step work
4. **Keep focused** — 3-10 items max

**Policy**: `.docs/policies/todo-architecture-policy.md`

---

## Project Knowledge Layer (`.brain/`)

Not part of the governance floor — no hook enforces this section; it is a
documented convention plus one CI gate, listed here because it lives next to
task/memory material, not because it is enforced the way the Governance
section is.

`.brain/` is where project knowledge accumulates: captures land in `raw/`
(immutable, never deleted), `/distill` promotes them into cited `wiki/` pages
(`concepts/` + `decisions/`), `index/` holds human-authored pointers, and
`memory/` holds durable memory under the default backend. The boundary test for
what belongs there: a file lives OUTSIDE `.brain/` when something RESOLVES its
exact path (a hook parses it, a script reads it as data, a workflow pack
requires it there); everything else — research output, review verdicts,
reports, distilled concepts — belongs inside. Contract: `.brain/README.md`.

`.brain/` **is this project's own vault** — same structure and the same
raw/distilled discipline, scoped to one project and self-contained. It has no
link to and no dependency on any external or personal vault; an outside store
reads `.brain/`, never the other way round.

Where memory itself is stored is a separate, related choice —
`.logic-loom/config/memory-backend.conf` (`memory_backend = repo | project`),
resolved by `resolve-memory-backend.sh`. **`repo` is the shipped default**:
`.brain/memory/`, in-tree, versioned, stripped at release — lessons travel
with the code, survive a machine change, and are readable by any tool with
filesystem access. `project` is the previous default,
`$HOME/.claude/projects/<slug>/memory/`: per-machine, outside the repo, never
committed, invisible to anything that is not Claude Code. A third backend
naming an external absolute path was **deleted**, not deprecated — it made a
one-machine directory a product feature and inverted the direction of the
relationship. `/retro` and both loom-memory search backends
(`keyword-backend.sh`, `bm25-search.sh`) resolve the setting rather than
assuming it, so retrieval follows the write target; the BM25 index directory
is keyed to the resolved backend so a change cannot serve stale hits from the
previous store.

**The default changed, and nothing is stranded silently.** Resolution is a
pure function of `(env, conf)` — the resolver never probes the filesystem to
pick a default, because the `project` slug is derived from the checkout path
and a probe would resolve differently in a worktree than in the main checkout
of the same project. Instead, when memory resolves to `repo` while
`$HOME/.claude/projects/<slug>/memory/` still holds files,
`check-brain-signals.sh` reports the count and both paths in the preflight
advisory until you move them or set `memory_backend = project`. Detection, by
something a human reads; never a decision a script makes, and never a file the
harness moves.

Three signals watch the routine, deliberately at different strengths — only
the first blocks anything, because a fail-closed gate must assert something
the change in front of it caused:

| Signal | Question | Mechanism | Strength |
|---|---|---|---|
| Record integrity | Does the routine's own record hold together? | `check-brain-record.sh` (CI) | FAIL-CLOSED |
| Liveness | Did the pass run recently? | preflight advisory | never blocks |
| Load | Is there a backlog? | preflight advisory | never blocks |

The advisory thresholds (`load_max_unprocessed`, `load_max_age_days`,
`liveness_max_age_days`, `advisory_enabled`) live in
`.logic-loom/config/brain.conf` and are silent when there are no unprocessed
captures and no run log — an unadopted routine makes no noise. The advisory
reaches the model through the *existing* `UserPromptSubmit` preflight
injection, riding the loom-memory search output `governance-preflight.sh`
already injects as `additionalContext` — not by editing the hook itself, since
`.claude/hooks/` sits on the governance protected-path list and the cheapest
change to a governance surface is none. `check-brain-signals.sh` is **not** a
hook and is not part of the governance floor.

**Protected**: `memory-backend.conf` and `brain.conf` govern behaviour, so both
are on `.logic-loom/config/governance.conf`'s `protected_paths` list. A
subagent is DENIED writes to either; a main-agent edit prompts for approval.
Expect the prompt when `/initialize-project` records your memory-backend
answer — that is the guard working, not a fault to route around.

**Capture is wired.** `/cross-check` writes its report to
`.brain/raw/reviews/<id>-<slug>/` and `/research` writes its final report as a
single self-contained capture at `.brain/raw/research/<id>-<slug>.md`, both
carrying `status: unprocessed` frontmatter so the record gate and `/distill`
can see them. `/research`'s working intermediates (vote JSONs, per-researcher
drafts) stay in the gitignored `.docs/research/<id>-<slug>/` — the same rule
`.gitignore` already states: **track only what a human opens**.

---

## AI Model Selection (Principle XIV)

Agents/commands select a tier via frontmatter keywords
(`opus`/`sonnet`/`haiku`/`inherit`), never pinned version strings. The
**documented** role→tier convention and current flagship live in
`.logic-loom/config/models.conf` (a reference table, not a runtime resolver —
no consumer parses it yet). Default flagship: **Opus 4.8**.

| Tier | Use Case |
|---|---|
| **frontier** (Fable 5 → Opus 4.8; see models.conf) | Orchestrator tier; plan/reason/delegate (model-agnostic-but-frontier) |
| **opus** (Opus 4.8; see models.conf) | Default for agents; architecture, security, complex reasoning |
| **sonnet** (Sonnet 5; see models.conf) | Cost optimization; high-volume tasks |
| **haiku** (Haiku 4.5; see models.conf) | Quick lookups; formatting; file ops (no `effort` support) |

**Model IDs** (single source): see `.logic-loom/config/models.conf` — agents select by tier keyword, never a pinned string.

> Orchestration is Claude-Code-native (Anthropic only). Cross-provider models
> (OpenAI/Gemini) are used solely at the delegated verification layer —
> `/research` and `/cross-check` — held advisory and read-only.

### Orchestrator + worker ladder

A dev-time delegation pattern: a **frontier orchestrator** plans/reasons/
delegates over cheaper Claude **workers** that do the bulk execution. Full
reference: `.docs/architecture/orchestrator-worker-ladder.md`.

| Rung | Tier | Model | Job |
|---|---|---|---|
| **Orchestrator** | `frontier` | Fable 5 → Opus 4.8 fallback | Main session. Plans, reasons, delegates, synthesizes. Set via `/model claude-fable-5`. |
| **deep-reasoner** | `opus` (effort `high`) | Opus 4.8 | Architecture, hard debugging. `.claude/agents/deep-reasoner.md`. |
| **fast-worker** | `sonnet` (effort `medium`) | Sonnet 5 | Boilerplate, tests, routine edits. `.claude/agents/fast-worker.md`. |

- **Orchestrator = model-agnostic-but-frontier**: a *role* targeting the frontier
  tier, defaulting to Fable 5 with a one-line downgrade to Opus 4.8 when Fable is
  unavailable/out of quota (`FRONTIER_MODEL` / `FRONTIER_FALLBACK` in
  `models.conf`). Never a non-Claude model.
- **Delegation policy**: reasoning/architecture → `deep-reasoner`; mechanical/
  boilerplate → `fast-worker`; correctness-critical + scrutiny-inviting → also run
  `/cross-check`. The orchestrator keeps the decision.
- **In workflows**: dispatch via `agent(prompt, { agentType: 'deep-reasoner' })`
  inside `/workflow`; `agent()`'s per-call `effort` gives the dynamic
  per-dispatch effort that raw Task subagents lack (Claude Code honours only
  *static* frontmatter `effort:`).
- **Boundary unchanged**: non-Claude models stay advisory-only (`/research`,
  `/cross-check`) — the ladder adds no non-Claude workers. Keep the two agents as
  **project** files (`.claude/agents/`), never plugin agents (which lose
  `hooks`/`mcpServers`/`permissionMode`). File-based agents load at session
  start — **restart to pick up edits**.

---

## Distribution & Cloner Support

The framework's cloner-init machinery is **UNTOUCHED**:

- `/update-framework` — pulls upstream LogicLoom enhancements
- `.sdd-sync-ref` — upstream pointer (filename preserved for backwards compatibility with already-cloned projects)
- `/initialize-project` — post-PRD project customization

---

## Additional Documentation

```bash
# Modular context loaders (still available)
./.logic-loom/scripts/bash/load-context.sh load agents
./.logic-loom/scripts/bash/load-context.sh load skills
./.logic-loom/scripts/bash/load-context.sh load workflows
./.logic-loom/scripts/bash/load-context.sh load governance
```

**See Also**:
- `VISION.md` — **foundational** product north-star (living); the *what/why* the constitution defers to (peer to the constitution, distinct from per-feature `features/<name>/vision.md`)
- `.docs/architecture/loom-architecture.md` — full architectural reference (LogicLoom shape)
- `.docs/architecture/evaluator-protocol.md` — `/review-team` evaluator contract
- `.docs/architecture/freeze-scope-protocol.md` — the `freeze-write-scope.sh` hook contract (a hook, not a command)
- `.logic-loom/memory/constitution.md` — 16 constitutional principles (v3.3.0)
- `.logic-loom/templates/amendments-template.md` — seed for a fork's `amendments.md` (project named mandates)
- `.logic-loom/memory/todos.md` / `.logic-loom/memory/backlog.md` — Level-0 SSOT for cross-cutting non-feature work: active half / deferred half, one grammar, one id space
- `.logic-loom/config/models.conf` — documented role→tier convention + current flagship
- `.logic-loom/config/governance.conf` — governance mode (lean/strict)
- `.logic-loom/config/gate-policy.conf` — **live**: which git/gh operations ask and which run silent, plus the five-operation floor that refuses to be silenced
- `.logic-loom/config/project.conf` — project identity (slug / name / `id_prefix`); ships unstamped, validated by `validate-project-identity.sh`
- `.logic-loom/config/environments.conf` — environment + promotion-order declaration; ships commented out, validated by `validate-environments.sh`
- `.brain/README.md` — the `.brain/` project knowledge layer contract (raw/wiki/index/memory, the boundary test for what belongs there)
- `.logic-loom/config/memory-backend.conf` — LIVE: `memory_backend = repo` (default) `| project`, resolved by `resolve-memory-backend.sh`. On `protected_paths` — see "Project Knowledge Layer" above
- `.logic-loom/config/brain.conf` — advisory thresholds for the `.brain/` liveness/load/migration signals. Also on `protected_paths`
- `.docs/policies/environment-promotion-policy.md` — the promotion methodology behind `/promote-dev` → `/promote-staging` → `/promote-prod`; every claim carries an evidence grade (VERIFIED / RECOMMENDED / UNSOLVED)
- `.docs/policies/shell-idiom-policy.md` — two things, with different force: **seven shell idioms** for hooks/scripts, each traced to a real failure (style guide, deliberately unenforced), and the **bash 3.2 floor**, which *is* enforced by `tests/contract/test_bash32_floor.sh` and fails CI. The floor covers **harness-owned shell only** — `.logic-loom/`, `.claude/hooks/`, `tests/`, and the plugins declared in the **Plugin Registry** table below. A plugin you add under `plugins/` is not scanned unless you list it there; `.github/workflows/` is out of scope (all `runs-on: ubuntu-latest`, bash 5)
- `plugins/MANIFEST-SCHEMA.md` — `.claude-plugin/plugin.json` schema (Principle XVI)
- `features/README.md` — per-feature folder convention
- `plugins/*/skills/` — skill documentation (Plugin-First Architecture)
- `AGENTS.md` — agent registry (tandem file — must update with CLAUDE.md)

---

## What changed in v6.2 (dev-loop removed)

- **Removed the dev-loop pack** (`loom-dev-loop` / `/dev-loop`): superseded by
  Claude Code's native `/workflow`, `/loop`, and `/goal` primitives, and its
  runtime self-extension was a governance liability. There are now **two**
  workflow packs — swarm and SDD waterfall — over the governance core. Plugin
  count: 8.

## What changed in v6.1 (Opus 4.8 re-base + agnostic core)

- **Governance is now hook-enforced** (not model-recited): `git-safety-gate.sh`
  forces approval on git mutations; `guard-dangerous-commands.sh` wired; the
  mandatory per-message 4-step ceremony is gone. New `LOOM_GOVERNANCE_MODE`
  (`lean` default / `strict` for weaker models).
- **Workflow-agnostic reframe**: governance core + interchangeable packs
  (swarm, SDD waterfall) — no "primary" or "legacy" path.
- **Domains collapsed**: the 7 `sdd-domain-*` plugins → governance-core
  domain-brief registry (`get_domain_brief`).
- **Model selection config-driven**: `.logic-loom/config/models.conf`
  (flagship Opus 4.8); pinned version strings removed.
- **Removed**: RL telemetry (incl. `rl_metrics` fields), the FR-707 compliance
  ceremony, `sdd-marketplace` MCP, migration scaffolding. (The DS-STAR refinement
  subsystem was later **removed** as well — redundant with Claude Code's native
  `/goal`, `/workflow`, and `/loop`; see the CHANGELOG.)
- **Renamed**: core/tooling/non-SDD packs `sdd-*` → `loom-*`; `sdd-specification`
  keeps its prefix (it *is* the SDD workflow).

---

**Framework**: logic-loom v6.6.2 (brand: **LogicLoom**)
**Constitution**: v3.3.0 (16 Principles)
**Architecture**: Governance core + interchangeable workflow packs (swarm / SDD waterfall)
**Runtime**: Claude-Code-native; Anthropic flagship (Opus-class) models
**Last Updated**: 2026-08-25
