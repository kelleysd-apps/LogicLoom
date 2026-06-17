# LogicLoom

**A governed, Claude-Code-native multi-agent harness: a constitutional governance core with interchangeable workflow packs.**

LogicLoom is a Claude Code harness for building software with disciplined multi-agent loops. Its durable core is **constitutional governance, enforced by hooks** (not by per-message ceremony). On top of that core sit **interchangeable workflow packs** — none privileged: a **swarm** pack (vision → PRD → plan → scope-bounded swarm) and an **SDD waterfall** pack (`/specification`). Pick the pack that matches the problem.

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
- **Jury-on-demand `/research`** — picks 1-3 LLM judges (Claude, OpenAI, Gemini) per query type instead of always paying for the full tribunal. Pass `--judges all` for full 3-judge cross-validation.
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
| `loom-maintenance` | core tooling | `/update-framework`, `/initialize-project` |
| `sdd-specification` | SDD pack | `/specification` waterfall (keeps `sdd-` — it *is* the SDD workflow) |

Domain expertise is **not** a plugin: the 7 domains (frontend, backend, database, testing, security, performance, devops) are **briefs** in `plugins/loom-governance/domain-briefs/`, injected into swarm/team workers via `get_domain_brief`.

---

## Core principles

LogicLoom enforces Constitution v3.2.0 (16 principles). The most load-bearing in day-to-day work:

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
| `/specification` | Unified SDD workflow (spec + plan + tasks in one command) |
| `/specify` | Create feature specification |
| `/plan` | Generate implementation plan |
| `/tasks` | Generate task list |
| `/build-team` | Sequential architect → implementor → reviewer |
| `/fullstack-team` | Parallel full-stack team |
| `/finalize` | Pre-commit compliance validation |

Pick the layout that matches the problem shape. New exploratory work belongs in `features/`; stable, well-spec'd work can use either.

---

## Workflow commands at a glance

### Swarm pack

| Command | Purpose |
|---------|---------|
| `/swarm explore <topic>` | Parallel read-only investigation; outputs to `features/<feature>/exploration/` |
| `/swarm implement [sprint]` | Per-sprint scope-bounded workers from `plan.md` |
| `/research <question>` | Jury-on-demand multi-LLM research (1-3 judges) |
| `/create-prd <feature>` | Broad PRD with forcing-questions gate (vision-driven or blank-slate mode auto-detected) |
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
| `/initialize-project` | Post-PRD project customization |

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
+-- memory/constitution.md            # v3.2.0 (16 principles)
+-- config/                           # governance.conf (lean/strict), models.conf (role->model)
+-- scripts/bash/                     # Workflow automation + plugin bridge
+-- templates/                        # vision-template, prd-template, plan/sprints templates
+-- config/                           # Quality thresholds

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

**Framework**: LogicLoom v6.2.0
**Constitution**: v3.2.0 (16 principles)
**Architecture**: Governance core + interchangeable workflow packs (swarm / SDD waterfall)
**Runtime**: Claude-Code-native; Anthropic flagship (Opus-class) models
