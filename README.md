# LogicLoom

**A governed, Claude-Code-native multi-agent harness: a constitutional governance core with interchangeable workflow packs.**

LogicLoom is a Claude Code harness for building software with disciplined multi-agent loops. Its durable core is **constitutional governance, enforced by hooks** (not by per-message ceremony). On top of that core sit **interchangeable workflow packs** — none privileged: a **swarm** pack (vision → PRD → plan → scope-bounded swarm) and an **SDD waterfall** pack (`/specification`). Pick the pack that matches the problem.

> **`/update-framework` not working?** If it fails with
> `.sdd-sync-ref is NOT reachable from upstream main`, that's a known issue in
> v6.3.1 / v6.4.0 with a one-line fix — see
> **[KNOWN_ISSUES.md](KNOWN_ISSUES.md)**.

---

## Quickstart

```bash
# Clone
git clone <your-repo-url> logic-loom
cd logic-loom

# Bootstrap (installs deps, wires hooks, syncs commands)
bash init-project.sh

# Launch Claude Code in the repo
claude

# Use the slash commands (see workflow below)
/swarm explore "current auth surfaces"
/create-prd "session-cookie-rotation"
# ... plan mode ...
/plan-review
/swarm implement 01-foundations
/review-team
/git-push
/code-review
/retro
```

---

## The swarm workflow pack (flagship example)

One of the interchangeable packs — best for exploratory or novel work. (For
well-specified features use the SDD waterfall pack.)

```
EnterWorktree
  -> /swarm explore        (optional - investigate existing surfaces, read-only)
  -> /research             (optional - resolve external unknowns, jury-on-demand)
  -> vision.md             (lock the north star)
  -> /swarm explore + /research   (fill remaining gaps surfaced by vision)
  -> /create-prd           (broad PRD with forcing-questions gate)
  -> plan mode             (sprint-structured plan with file-ownership DAG)
  -> /plan-review          (CEO + Eng verdict - gates implementation)
  -> /swarm implement      (per-sprint, scope-bounded workers)
  -> test / fix            (direct debug loop on failures)
  -> /review-team          (security + quality + performance + behavioral evaluator)
  -> /git-push             (commit + PR with explicit approval)
  -> /code-review          (external Claude Code command — PR-level review)
  -> /retro                (capture learnings)
ExitWorktree
```

Each feature lives in `features/<feature-name>/` with its own `vision.md`, `prd.md`, `plan.md`, `plan-review.md`, `sprints/`, and `retro.md`. See `features/README.md` for the per-feature layout convention.

---

## Key differentiators

- **Parallel `/swarm` modes** — `explore` (read-only investigations), `implement` (per-sprint scope-bounded workers), and `generic` (domain auto-detect) selected by first argument.
- **Plan-as-DAG with file-ownership** — `plan.md` declares which files each worker may touch per sprint. The `freeze-write-scope` hook rejects out-of-scope writes at runtime.
- **Jury-on-demand `/research`** — picks 1-3 LLM judges (Claude, OpenAI, Gemini) per query type instead of always paying for the full tribunal. Pass `--judges all` for legacy 3-judge cross-validation.
- **Playwright behavioral evaluator** — `/review-team` runs four parallel reviewers including a behavioral evaluator that exercises the actual UI/API through the chrome-devtools MCP.
- **800K context cap** — the `context-cap-warn` hook flags sessions approaching 800K of the 1M window so you compact or hand off before degradation.
- **Worktree port-namespace** — the `worktree-port-namespace` hook assigns deterministic port ranges per worktree so parallel feature branches don't collide on dev servers.
- **Hook-enforced governance** — Principle VI (no autonomous git) is enforced by the `git-safety-gate` PreToolUse hook (mutations force an approval prompt); `freeze-write-scope` and a dangerous-command guard run alongside. The `UserPromptSubmit` preflight injects domain briefs + memory context. There is **no per-message compliance ceremony** — governance modes are `lean` (default, for flagship Opus models) or `strict` (re-adds a recitation for weaker models) via `LOOM_GOVERNANCE_MODE`.
- **Model/provider boundary** — orchestration is Claude-Code-native (Anthropic flagship; tier selection via `.logic-loom/config/models.conf`). Cross-provider models (OpenAI/Gemini) are used only at the delegated `/research` layer.

---

## Plugin Marketplace

LogicLoom does not run its own plugin marketplace. For third-party plugin and skill discovery:

- **Anthropic Claude Code Plugin Marketplace** — the canonical source for installable skills and plugins.
- **Docker MCP Toolkit** — pre-installed during setup, exposes 310+ containerized MCP servers via `mcp-find`, `mcp-add`, `mcp-config-set`, and `mcp-exec` tools.

LogicLoom's own plugins live in `plugins/` and are loaded directly — see Plugin Registry below.

### Plugin Registry

| Plugin | Category | Purpose |
|--------|----------|---------|
| `loom-governance` | governance | Constitutional enforcement, compliance hooks |
| `loom-orchestrator` | orchestration | `/swarm`, `/research`, `/plan-review`, `/retro`, `/review-team`, team commands |
| `loom-orchestrator-hook` | orchestration | Domain detection, agent recommendations via hook |
| `loom-memory` | orchestration | 3-tier memory with hybrid BM25/vector search |
| `loom-creation` | core | `/create-prd`, `/create-agent`, `/create-plugin` |
| `loom-git` | core | `/git-push`, `/finalize` (`/code-review` is an external Claude Code command, not shipped here) |
| `loom-maintenance` | core tooling | `/update-framework`, `/initialize-project`, `/scaffold-environments`, `/promote-dev`, `/promote-staging`, `/promote-prod` |
| `sdd-specification` | SDD pack | `/specification` waterfall (keeps `sdd-` — it *is* the SDD workflow) |

Domain expertise is **not** a plugin: the 7 domains (frontend, backend, database, testing, security, performance, devops) are **briefs** in `plugins/loom-governance/domain-briefs/`, injected into swarm/team workers via `get_domain_brief`.

---

## Core principles

LogicLoom enforces Constitution v3.3.0 (16 principles). The most load-bearing in day-to-day work:

1. **Test-First Development** (Principle II): TDD mandatory, >80% coverage.
2. **Git Operation Approval** (Principle VI): no autonomous git operations — enforced by the `git-safety-gate` hook.
3. **Delegation & Context Isolation** (Principle X): delegate specialized/parallel work to subagents/swarm for isolation and parallelism — not because the base model lacks capability.
4. **Plugin-First** (Principle XVI): all capabilities are discrete installable plugins under `plugins/`.

No principle privileges a workflow; governance is the only protected layer, and the workflow packs are interchangeable.

---

## SDD waterfall pack

A peer workflow pack — best for well-understood features with stable requirements. Its work lives under `specs/###-feature-name/` rather than `features/<name>/`.

| Command | Purpose |
|---------|---------|
| `/specification` | The whole SDD waterfall in one command — spec, then plan, then tasks, as three sequential phases with quality gates |
| `/build-team` | Sequential architect → implementor → reviewer |
| `/fullstack-team` | Parallel full-stack team |
| `/finalize` | Pre-commit compliance validation |

> **There is no separate `/specify`, `/plan`, or `/tasks` command.** Earlier
> versions shipped those three as standalone commands; v5.1.0 **merged** them
> into `/specification`, which now runs all three phases itself. They were not
> renamed and there is no one-to-one replacement — run `/specification` and you
> get all three artifacts.

Pick the layout that matches the problem shape. New exploratory work belongs in `features/`; stable, well-spec'd work can use either.

---

## Workflow commands at a glance

### Swarm pack

| Command | Purpose |
|---------|---------|
| `/swarm explore <topic>` | Parallel read-only investigation; outputs to `features/<feature>/exploration/` |
| `/swarm implement [sprint]` | Per-sprint scope-bounded workers from `plan.md` |
| `/research <question>` | Jury-on-demand multi-LLM research (1-3 judges) |
| `/create-prd <feature>` | Broad PRD with forcing-questions gate (vision-driven or legacy mode auto-detected) |
| `/plan-review` | CEO + Eng verdict on `plan.md` before implementation |
| `/review-team` | 4 parallel reviewers (security + quality + performance + behavioral evaluator) |
| `/git-push` | Complete git workflow with conflict resolution and explicit approval |
| `/code-review` | PR-level review (external Claude Code command the workflow leans on — not shipped by LogicLoom) |
| `/retro` | Post-feature learning capture |

### Plugin & agent management

| Command | Purpose |
|---------|---------|
| `/create-plugin` | Create new LogicLoom plugin |
| `/create-agent` | Create specialized subagent |
| `/create-skill` | Create new agent skill |
| `/update-framework` | Check for upstream enhancements |
| `/initialize-project` | Post-PRD project customization (also picks the gate-policy posture) |

### Environment promotion

`/promote-dev` -> `/promote-staging` -> `/promote-prod` is a promotion
**lifecycle, not a deploy engine**. Each rung checks the declared promotion
order and asks for confirmation whose strength
escalates with blast radius — a prompt at dev and staging, a **typed exact
phrase that no flag or non-interactive path bypasses** at prod. It then calls out
to the `deploy` seam your project owns. The harness runs no cloud or CI call, no
deploy command, no migration, seed, teardown, secret or rollback, and no git.
The **rehearsal attestation is read at prod only** — `/promote-prod` is the only
rung that requires one.

| Command | Purpose |
|---------|---------|
| `/scaffold-environments` | Adopt the methodology into a new or existing project — detects what you already have, proposes a delta, writes only what you name |
| `/promote-dev` | Gates a feature branch/worktree -> integration branch + dev environment, then prints your deploy seam's command. Prompts; skippable |
| `/promote-staging` | Gates a promotion into the rehearsal environment, then prints the seam command that stands it up and runs the smoke pass rehearsing `/promote-prod` |
| `/promote-prod` | Rehearsal contract + promotion order + typed exact phrase |

Methodology, evidence grades, and the portable patterns:
[.docs/policies/environment-promotion-policy.md](.docs/policies/environment-promotion-policy.md).
Declare your environments in `.logic-loom/config/environments.conf` (ships
commented out) and check it with `.logic-loom/scripts/bash/validate-environments.sh`.

---

## Project structure

```
plugins/                              # Plugin-First Architecture
+-- loom-governance/                   # Protected -- constitutional enforcement
+-- loom-orchestrator/                 # Swarm + research + plan-review + retro + review-team
+-- loom-orchestrator-hook/            # Domain detection + memory injection hook
+-- loom-memory/                       # 3-tier memory with hybrid search
+-- loom-creation/                     # PRD + agent + plugin creation
+-- loom-git/                          # Git operations
+-- loom-maintenance/                  # Framework maintenance
+-- sdd-specification/                # SDD waterfall pack
                                       # (domains are briefs in loom-governance/domain-briefs/, not plugins)

.logic-loom/
+-- memory/constitution.md            # v3.3.0 (16 principles)
+-- memory/todos.md  backlog.md       # Level-0 SSOT for cross-cutting non-feature work:
                                      #   todos = being worked now; backlog = raise later.
                                      #   Same grammar, same id space, different question.
+-- config/                           # governance.conf (lean/strict), models.conf (role->model),
                                      #   gate-policy.conf (which ops ask vs run silent -- LIVE),
                                      #   project.conf (identity; ships unstamped),
                                      #   environments.conf (declaration; ships commented out),
                                      #   architecture.conf, framework-upstream.conf
+-- scripts/bash/                     # Workflow automation + plugin bridge
+-- templates/                        # vision-template, prd-template, plan/sprints templates

.claude/
+-- commands/                         # Slash commands (bridge-generated from plugins)
+-- context/                          # Modular context loading
+-- hooks/                            # Governance hooks (preflight, freeze-write-scope, context-cap-warn, worktree-port-namespace)
+-- settings.json                     # Hook configuration

features/                             # Swarm pack (per-feature folders)
+-- <feature-name>/
    +-- vision.md
    +-- exploration/
    +-- research/
    +-- prd.md
    +-- plan.md
    +-- plan-review.md
    +-- sprints/NN-name/
    +-- retro.md

specs/                                # SDD waterfall pack (per-feature folders)

web/  (or apps/<name>/)               # Product app workspace (own package.json) — see below
```

### Where does my product code go?

The repo root (`package.json`, `tests/`, `.claude/`, `.logic-loom/`, `plugins/`)
is **framework-owned**. Your **product application code** lives in its own
workspace — `web/` for a single app or `apps/<name>/` for a monorepo — each with
its own `package.json`, `node_modules`, build, and test runner. Don't put product
source at the repo root or share the root `package.json` / `tests/`. See
[.docs/policies/file-structure-policy.md](.docs/policies/file-structure-policy.md) (§ Product Workspace).

---

## Documentation

- **Constitution**: [.logic-loom/memory/constitution.md](.logic-loom/memory/constitution.md)
- **Framework Guide**: [CLAUDE.md](CLAUDE.md)
- **Agent Registry**: [AGENTS.md](AGENTS.md)
- **LogicLoom Workflow Convention**: [features/README.md](features/README.md)
- **Setup Guide**: [START_HERE.md](START_HERE.md)
- **Policies**: `.docs/policies/`

---

## License

MIT

---

**Framework**: LogicLoom v6.4.1
**Constitution**: v3.3.0 (16 principles)
**Architecture**: Governance core + interchangeable workflow packs (swarm / SDD waterfall)
**Runtime**: Claude-Code-native; Anthropic flagship (Opus-class) models
