# LogicLoom

**A coding harness framework with vision/PRD/plan/swarm workflow, hook-based governance, and legacy SDD support.**

LogicLoom is a Claude Code harness for building software with disciplined multi-agent loops. Features start broad (vision), get focused through exploration and research, harden into a plan with file-ownership boundaries, then execute via scope-bounded swarms with behavioral verification before they merge.

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

## The LogicLoom workflow

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
  -> /code-review          (PR-level review)
  -> /retro                (capture learnings)
ExitWorktree
```

Each feature lives in `features/<feature-name>/` with its own `vision.md`, `prd.md`, `plan.md`, `plan-review.md`, `sprints/`, and `retro.md`. See `features/README.md` for the per-feature layout convention.

---

## Key differentiators

- **Parallel `/swarm` modes** — `explore` (read-only investigations), `implement` (per-sprint scope-bounded workers), and `generic-legacy` (pre-LogicLoom behavior) selected by first argument.
- **Plan-as-DAG with file-ownership** — `plan.md` declares which files each worker may touch per sprint. The `freeze-write-scope` hook rejects out-of-scope writes at runtime.
- **Jury-on-demand `/research`** — picks 1-3 LLM judges (Claude, OpenAI, Gemini) per query type instead of always paying for the full tribunal. Pass `--judges all` for legacy 3-judge cross-validation.
- **Playwright behavioral evaluator** — `/review-team` runs four parallel reviewers including a behavioral evaluator that exercises the actual UI/API through the chrome-devtools MCP.
- **800K context cap** — the `context-cap-warn` hook flags sessions approaching 800K of the 1M window so you compact or hand off before degradation.
- **Worktree port-namespace** — the `worktree-port-namespace` hook assigns deterministic port ranges per worktree so parallel feature branches don't collide on dev servers.
- **Hook-based governance** — constitutional reminders, domain detection, agent recommendations, and memory context are injected via the `UserPromptSubmit` preflight hook. Claude Code runs with its native capabilities; the harness adds discipline through hooks rather than custom agents.

---

## Plugin Marketplace

LogicLoom does not run its own plugin marketplace. For third-party plugin and skill discovery:

- **Anthropic Claude Code Plugin Marketplace** — the canonical source for installable skills and plugins.
- **Docker MCP Toolkit** — pre-installed during setup, exposes 310+ containerized MCP servers via `mcp-find`, `mcp-add`, `mcp-config-set`, and `mcp-exec` tools.

LogicLoom's own plugins live in `plugins/` and are loaded directly — see Plugin Registry below.

### Plugin Registry

| Plugin | Category | Purpose |
|--------|----------|---------|
| `sdd-governance` | governance | Constitutional enforcement, compliance hooks |
| `sdd-orchestrator` | orchestration | `/swarm`, `/research`, `/plan-review`, `/retro`, `/review-team`, team commands |
| `sdd-orchestrator-hook` | orchestration | Domain detection, agent recommendations via hook |
| `sdd-memory` | orchestration | 3-tier memory with hybrid BM25/vector search |
| `sdd-creation` | core | `/create-prd`, `/create-agent`, `/create-plugin` |
| `sdd-git` | core | `/git-push`, `/code-review`, `/finalize` |
| `sdd-maintenance` | core | `/update-framework`, `/initialize-project` |
| `sdd-specification` | core | `/specification` (legacy SDD waterfall) |
| `sdd-dev-loop` | core | `/dev-loop` (legacy autonomous loop) |
| `sdd-domain-*` | domain | 7 domain skill plugins (frontend, backend, database, testing, security, devops, performance) |

---

## Core principles

LogicLoom enforces Constitution v3.0.0 (16 principles). The most load-bearing in day-to-day work:

1. **Test-First Development** (Principle II): TDD mandatory, >80% coverage.
2. **Git Operation Approval** (Principle VI): no autonomous git operations — every commit, push, branch action requires explicit user approval.
3. **Agent Delegation** (Principle X): specialized work routes to specialist skills; the governance hook recommends them.
4. **Plugin-First** (Principle XVI): all capabilities are discrete installable plugins under `plugins/`.

The v6.0.0 supplementary principle, **Legacy-Tool Coexistence**, declares that the legacy SDD path stays alongside the LogicLoom workflow.

---

## Legacy SDD workflow

The pre-LogicLoom waterfall is still fully supported for well-understood features with stable requirements. It lives under `specs/###-feature-name/` rather than `features/<name>/`.

| Command | Purpose |
|---------|---------|
| `/specification` | Unified SDD workflow (spec + plan + tasks in one command) |
| `/specify` | Create feature specification |
| `/plan` | Generate implementation plan |
| `/tasks` | Generate task list |
| `/build-team` | Sequential architect → implementor → reviewer |
| `/fullstack-team` | Parallel full-stack team |
| `/dev-loop` | Recursive autonomous edit-test-debug cycle |
| `/finalize` | Pre-commit compliance validation |

Pick the layout that matches the problem shape. New exploratory work belongs in `features/`; stable, well-spec'd work can use either.

---

## Workflow commands at a glance

### LogicLoom (primary)

| Command | Purpose |
|---------|---------|
| `/swarm explore <topic>` | Parallel read-only investigation; outputs to `features/<feature>/exploration/` |
| `/swarm implement [sprint]` | Per-sprint scope-bounded workers from `plan.md` |
| `/research <question>` | Jury-on-demand multi-LLM research (1-3 judges) |
| `/create-prd <feature>` | Broad PRD with forcing-questions gate (vision-driven or legacy mode auto-detected) |
| `/plan-review` | CEO + Eng verdict on `plan.md` before implementation |
| `/review-team` | 4 parallel reviewers (security + quality + performance + behavioral evaluator) |
| `/git-push` | Complete git workflow with conflict resolution and explicit approval |
| `/code-review` | PR-level review |
| `/retro` | Post-feature learning capture |

### Plugin & agent management

| Command | Purpose |
|---------|---------|
| `/create-plugin` | Create new LogicLoom plugin |
| `/create-agent` | Create specialized subagent |
| `/create-skill` | Create new agent skill |
| `/update-framework` | Check for upstream enhancements |
| `/initialize-project` | Post-PRD project customization |

---

## Project structure

```
plugins/                              # Plugin-First Architecture
+-- sdd-governance/                   # Protected -- constitutional enforcement
+-- sdd-orchestrator/                 # Swarm + research + plan-review + retro + review-team
+-- sdd-orchestrator-hook/            # Domain detection + memory injection hook
+-- sdd-memory/                       # 3-tier memory with hybrid search
+-- sdd-creation/                     # PRD + agent + plugin creation
+-- sdd-git/                          # Git operations
+-- sdd-maintenance/                  # Framework maintenance
+-- sdd-specification/                # Legacy SDD waterfall
+-- sdd-dev-loop/                     # Legacy autonomous dev loop
+-- sdd-domain-*/                     # 7 domain skill plugins

.logic-loom/
+-- memory/constitution.md            # v3.0.0 (16 principles)
+-- scripts/bash/                     # Workflow automation + plugin bridge
+-- templates/                        # vision-template, prd-template, plan/sprints templates
+-- config/                           # Quality thresholds

.claude/
+-- commands/                         # Slash commands (bridge-generated from plugins)
+-- context/                          # Modular context loading
+-- hooks/                            # Governance hooks (preflight, freeze-write-scope, context-cap-warn, worktree-port-namespace)
+-- settings.json                     # Hook configuration

features/                             # LogicLoom primary workflow (per-feature folders)
+-- <feature-name>/
    +-- vision.md
    +-- exploration/
    +-- research/
    +-- prd.md
    +-- plan.md
    +-- plan-review.md
    +-- sprints/NN-name/
    +-- retro.md

specs/                                # Legacy SDD waterfall (per-feature folders)
```

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

**Framework**: LogicLoom v6.0.0
**Constitution**: v3.0.0 (16 principles + v6.0.0 supplementary)
**Architecture**: LogicLoom workflow + Plugin-First + Skill-Based Delegation
