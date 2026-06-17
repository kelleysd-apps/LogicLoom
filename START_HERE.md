# START HERE — LogicLoom Onboarding

**A governed Claude Code harness: a constitutional governance core with interchangeable workflow packs.**

This guide walks new users through their first feature using the **swarm pack** (one of two interchangeable workflow packs). For the **SDD waterfall pack** (`/specification`, `/specify`, `/plan`, `/tasks`), see the section near the end. Neither is privileged — pick by problem shape.

---

## 1. Install and bootstrap

```bash
git clone <your-repo-url> logic-loom
cd logic-loom
bash init-project.sh
```

`init-project.sh` checks for Node.js, Git, and Claude Code, then provisions `.logic-loom/` and `.claude/` hooks. Missing dependencies print platform-specific install instructions.

### What lives in `.logic-loom/`

| Path | Purpose |
|------|---------|
| `.logic-loom/memory/constitution.md` | 16 governance principles (v3.2.0) |
| `.logic-loom/scripts/bash/` | Workflow automation and plugin command bridge |
| `.logic-loom/templates/` | `vision-template.md`, `prd-template.md`, plan/sprint/retro templates |
| `.logic-loom/config/` | Quality thresholds |
| `.logic-loom/lib/` | Shared shell libraries |

Launch Claude Code with `claude`. The governance preflight hook fires on every message, injecting domain briefs and memory context. Governance is **hook-enforced** (git-safety gate, freeze-scope) — there is no per-message compliance ceremony in the default `lean` mode; set `LOOM_GOVERNANCE_MODE=strict` to re-add a recitation for weaker models.

### Framework updates

Run `/update-framework` inside Claude Code to pull upstream framework enhancements as reviewable, **proposal-based** changes. It is **fetch-only** — it never adds an `upstream` git remote, never pushes/pulls/merges upstream, and commits accepted changes only to **your** current branch. The upstream is configured in `.logic-loom/config/framework-upstream.conf`. See `.docs/guides/FRAMEWORK_SYNC_GUIDE.md`.

---

## The swarm pack — 14-step loop

Run each step from inside Claude Code unless noted. Outputs live under `features/<feature-name>/`. (This is the swarm pack; the SDD waterfall pack is summarized later.)

### 2. EnterWorktree

```
EnterWorktree feature/<short-name>
```

The `worktree-port-namespace` hook assigns this worktree a deterministic dev-server port range so parallel features don't collide.

### 3. `/swarm explore` (optional)

```
/swarm explore "current <thing> surfaces"
```

Parallel **read-only** investigation of existing code. Outputs land in `features/<feature-name>/exploration/`. Workers cannot write outside that folder.

### 4. Lock `vision.md`

Create `features/<feature-name>/vision.md` from `.logic-loom/templates/vision-template.md`. Vision is deliberately **broad** — one-sentence north star, persona, success shape, explicit non-goals. No implementation details.

### 5. `/research` (optional)

```
/research "<question>"
```

**Jury-on-demand**: picks 1-3 LLM judges based on query type. Pass `--judges all` for the legacy 3-judge tribunal (Claude + OpenAI + Gemini) on high-stakes questions. Outputs land in `features/<feature-name>/research/`.

### 6. `/create-prd`

```
/create-prd <feature-name>
```

Auto-detects mode: **vision-driven** when `vision.md` exists (runs the office-hours forcing-questions gate); **blank-slate** otherwise. Outputs `features/<feature-name>/prd.md`.

### 7. Plan mode

Switch into plan mode (Shift+Tab) and produce `features/<feature-name>/plan.md` declaring sprints (waves), per-sprint workers with their **file-ownership scope**, and the DAG of dependencies. File ownership is load-bearing — the `freeze-write-scope` hook rejects worker writes outside declared scope at runtime.

### 8. `/plan-review`

```
/plan-review
```

Runs a CEO reviewer (product fit, scope, ROI) and an Eng reviewer (architecture, file boundaries, testability). The verdict lands in `features/<feature-name>/plan-review.md` and **gates implementation**.

### 9. `/swarm implement` per sprint

```
/swarm implement 01-foundations
# ...when sprint 1 is green...
/swarm implement 02-api-surface
```

Reads the named sprint from `plan.md`, spawns scope-bounded workers, writes to `features/<feature-name>/sprints/NN-name/`. If tests fail, debug directly in the loop (edit + test + repeat) before starting the next sprint.

### 10. `/review-team`

`/review-team` runs **4 parallel reviewers**: security, quality, performance, and a **behavioral evaluator** that drives Playwright via the chrome-devtools MCP to exercise actual UI/API behavior.

### 11. `/git-push`

`/git-push` walks the full commit → push → PR flow with explicit user approval at every step (Principle VI). Merge conflicts surface interactively.

### 12. `/code-review`

Focused review of the open PR. This is an **external Claude Code command** the
workflow leans on — it is not shipped by LogicLoom (`loom-git` ships only
`/git-push` and `/finalize`).

### 13. `/retro`

`/retro` writes `features/<feature-name>/retro.md` — what worked, what to change next time, what to promote into the constitution or skills.

### 14. ExitWorktree

`ExitWorktree` releases the port-namespace allocation.

---

## Context guardrails (automatic)

- **`context-cap-warn`** — flags sessions approaching 800K of the 1M context window so you compact or hand off before quality degrades.
- **`freeze-write-scope`** — rejects swarm worker writes outside declared file scope.
- **`worktree-port-namespace`** — deterministic port ranges per worktree.

You don't invoke these; they fire from `.claude/hooks/`.

---

## SDD waterfall pack

The peer workflow pack. The **SDD waterfall** suits well-understood features with stable requirements; its specs live under `specs/###-feature-name/`.

| Command | Purpose |
|---------|---------|
| `/specification` | Unified workflow — spec + plan + tasks |
| `/specify` | Create feature specification |
| `/plan` | Generate implementation plan |
| `/tasks` | Generate dependency-ordered task list |
| `/build-team` | Sequential architect → implementor → reviewer |
| `/fullstack-team` | Parallel full-stack team |
| `/finalize` | Pre-commit compliance validation |

Pick the layout that matches the problem shape. Exploratory work belongs in `features/`; stable, well-spec'd work can use either.

---

## Project structure

```
your-project/
├── .logic-loom/             # Framework core (constitution, scripts, templates, config, lib)
├── .claude/                 # commands, context, hooks, settings.json
├── plugins/                 # LogicLoom plugins
├── features/                # Swarm pack — per-feature folders
│   └── <feature-name>/
│       ├── vision.md
│       ├── exploration/  research/
│       ├── prd.md  plan.md  plan-review.md
│       ├── sprints/NN-name/
│       └── retro.md
├── specs/                   # SDD waterfall pack — per-feature folders
├── .docs/                   # Project documentation
├── CLAUDE.md  README.md  START_HERE.md
```

---

## Where to read next

- **CLAUDE.md** — full AI assistant instructions and hook-enforced governance
- **README.md** — framework features and architecture
- **AGENTS.md** — complete agent registry
- **features/README.md** — per-feature layout convention with rationale
- **.logic-loom/memory/constitution.md** — 16 principles (v3.2.0)
- **.docs/policies/** — framework policies

---

## Troubleshooting

- **Setup script won't run (macOS/Linux)**: `chmod +x init-project.sh && bash init-project.sh`
- **CRLF errors (Windows clones)**: `find .logic-loom/scripts -name "*.sh" -exec sed -i 's/\r$//' {} \; && chmod +x .logic-loom/scripts/*.sh .logic-loom/scripts/bash/*.sh && bash init-project.sh`
- **Claude Code ENOTEMPTY**: `rm -rf $(npm config get prefix)/lib/node_modules/@anthropic-ai/.claude-code-* 2>/dev/null && npm install -g @anthropic-ai/claude-code`
- **Still stuck?** Open Claude Code and ask: `"I'm setting up LogicLoom and hitting <paste error>. Help me diagnose."` The governance hook pulls in relevant memory and constitution context automatically.

---

**Welcome to LogicLoom.** Start with vision, plan with file boundaries, swarm in scope, review behavior, retro the loop.
