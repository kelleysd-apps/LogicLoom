# START HERE — LogicLoom Onboarding

**A governed Claude Code harness: a constitutional governance core with interchangeable workflow packs.**

This guide walks new users through their first feature using the **swarm pack** (one of two interchangeable workflow packs). For the **SDD waterfall pack** (`/specification`), see the section near the end. Neither is privileged — pick by problem shape.

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
| `.logic-loom/memory/constitution.md` | 16 governance principles (v3.3.0) |
| `.logic-loom/scripts/bash/` | Workflow automation and plugin command bridge |
| `.logic-loom/templates/` | `vision-template.md`, `prd-template.md`, plan/sprint/retro templates |
| `.logic-loom/config/` | `governance.conf` (lean/strict), `models.conf` (role -> tier), `gate-policy.conf` (see below), `project.conf` (your project's identity -- ships **unstamped**, `/initialize-project` fills it in), `environments.conf` (environment + promotion-order declaration -- ships **fully commented out**), `architecture.conf`, `framework-upstream.conf` |
| `.logic-loom/memory/todos.md` + `backlog.md` | Cross-cutting work that is not a feature: `todos.md` is what is being worked now, `backlog.md` is what to raise later. Same grammar, same id space |
| `.logic-loom/lib/` | Shared shell libraries |

Launch Claude Code with `claude`. The governance preflight hook fires on every message, injecting domain briefs and memory context. Governance is **hook-enforced** (git-safety gate, freeze-scope) — there is no per-message compliance ceremony in the default `lean` mode; set `LOOM_GOVERNANCE_MODE=strict` to re-add a recitation for weaker models.

### How much does LogicLoom interrupt you?

That is your call, and it lives in one file: **`.logic-loom/config/gate-policy.conf`**.

Governance used to ask one question — "does this command change the repo?" — so
`git commit -m "wip"` and `git push --force` produced the same prompt. A prompt
you see fifty times a day is a prompt you stop reading. `gate-policy.conf`
separates that into a second question you answer: *is this change worth
interrupting you?* Each git/gh operation gets `ask` (an approval prompt) or
`silent` (runs without an extra LogicLoom prompt -- still logged, still in your
transcript, still subject to your Claude Code permission mode).

`/initialize-project` offers three postures, and you can edit any line afterwards:

| Posture | What it means |
|---------|---------------|
| `strict` | Every operation asks. Nothing is silent |
| `balanced` | **The shipped default.** Consequential and destructive operations ask; routine local work (commit, add, stash, checkout between existing branches) runs silent |
| `minimal` | Everything tunable is silent; only the floor asks |

**The floor is not tunable.** Five operations -- push, history rewriting, repo
admin, secret write, auth -- refuse a `silent` setting and tell you why, on one
test: *a wrong answer leaves the repository, or a credential, somewhere a revert
cannot reach.* Three more are not config keys at all: governance-file writes, the
dangerous-command guard, and subagent git/gh. There is no wildcard and no
"silence everything" line -- weakening the gate costs one line per thing you
weaken.

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
| `/specification` | The entire waterfall in one command — spec, then plan, then dependency-ordered tasks, as three sequential phases with quality gates |
| `/build-team` | Sequential architect → implementor → reviewer |
| `/fullstack-team` | Parallel full-stack team |
| `/finalize` | Pre-commit compliance validation |

> **`/specify`, `/plan`, and `/tasks` do not exist.** They were three separate
> commands before v5.1.0 and were **merged** into `/specification` — not renamed.
> One command now produces all three artifacts; there is nothing else to run.

Pick the layout that matches the problem shape. Exploratory work belongs in `features/`; stable, well-spec'd work can use either.

---

## Environment promotion (optional)

`/promote-dev` -> `/promote-staging` -> `/promote-prod` is a promotion
**lifecycle, not a deploy engine.** Each rung checks the declared promotion
order and asks for a confirmation whose
strength escalates with blast radius -- a prompt at dev and staging, a **typed
exact phrase** at prod that no flag, environment variable, or non-interactive
path can bypass (`--yes` is read and explicitly reported as ignored). Then it
calls out to the `deploy` seam **your project owns**. LogicLoom itself runs no
cloud or CI call, no deploy command, no migration, seed, teardown, secret or
rollback -- and no git. The **rehearsal attestation is read at prod only**:
`/promote-prod` is the only rung that asks for one, so dev and staging neither
read nor require it.

| Command | Purpose |
|---------|---------|
| `/scaffold-environments` | Adopt the methodology into a new **or existing** project: detects what you already have, proposes a delta, writes only what you name |
| `/promote-dev` | Gates a feature branch or worktree into the integration branch and the dev environment, then prints your deploy seam's command. Prompts; skippable |
| `/promote-staging` | Gates a promotion into the rehearsal environment, then prints the seam command that stands it up and runs the smoke pass rehearsing `/promote-prod` |
| `/promote-prod` | Rehearsal contract, promotion order, typed exact phrase |

Declare your environments in `.logic-loom/config/environments.conf` (it ships
fully commented out -- an active default would assert a branch topology your repo
does not have) and check it with
`.logic-loom/scripts/bash/validate-environments.sh`. Confirmation strength
resolves from the target environment's declared `confirm` first, then the command
default, so you can raise dev to a typed phrase or lower prod to a prompt -- the
ladder is guidance, not rails, and a weakening is reported loudly rather than
refused.

The methodology, including what a green rehearsal does **not** prove and two
problems recorded as UNSOLVED rather than dressed up as patterns:
[.docs/policies/environment-promotion-policy.md](.docs/policies/environment-promotion-policy.md).

---

## Project structure

```
your-project/
├── .logic-loom/             # Framework core
│   ├── memory/               # constitution.md, todos.md (working now), backlog.md (later)
│   ├── config/               # governance.conf, models.conf, gate-policy.conf,
│   │                         #   project.conf, environments.conf, ...
│   └── scripts/  templates/  lib/
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
├── web/  (or apps/<name>/)  # Product app workspace (own package.json) — see below
├── .docs/                   # Project documentation
├── CLAUDE.md  README.md  START_HERE.md
```

### Where does my product code go?

The repo root (`package.json`, `tests/`, `.claude/`, `.logic-loom/`, `plugins/`)
is **framework-owned**. Your **product application code** lives in its own
workspace — `web/` for a single app or `apps/<name>/` for a monorepo — each with
its own `package.json`, `node_modules`, build, and test runner. Don't put product
source at the repo root or share the root `package.json` / `tests/`. Full rule:
`.docs/policies/file-structure-policy.md` (§ Product Workspace).

### Where do my personal preferences go?

**LogicLoom never writes to `~/.claude/`.** The harness governs this repository —
its hooks, constitution, plugins, and commands all live in-repo. Your personal
Claude Code layer stays yours; nothing in setup, `/initialize-project`, or
`/update-framework` touches it.

That means the two layers have different jobs:

| Layer | Lives in | Holds |
|-------|----------|-------|
| **Harness** | this repo (`.claude/`, `.logic-loom/`, `plugins/`, `CLAUDE.md`) | Repo-specific facts, governance, workflow packs |
| **You** | `~/.claude/` (`CLAUDE.md`, `settings.json`, your hooks/commands/agents) | How the assistant talks to you, persona, response shape, your own model/orchestration taste, your global hooks |

Put working preferences in `~/.claude/CLAUDE.md`, not the project `CLAUDE.md` —
the project file is read by everyone who clones the repo, so it should carry only
repo-specific facts.

**Hooks compose.** Your user-level hooks and LogicLoom's project hooks both fire,
and their decisions combine most-restrictive. A personal hook therefore cannot
weaken the governance floor, but it can add friction of its own — worth knowing
when a command is blocked and the deny message isn't one of LogicLoom's.

**Commands don't travel with you.** `/cross-check` is a LogicLoom plugin command,
so it exists only inside a LogicLoom project. If you put adversarial-review
instructions in your own `~/.claude/CLAUDE.md`, they will also run in projects
that have no `/cross-check` — and no governance floor. Inside a LogicLoom project,
use `/cross-check`; outside one, if you call an external model's CLI directly,
pass that provider's read-only sandbox flag. For Codex CLI that is
`codex exec --sandbox read-only -c approval_policy='"never"' "<brief>"` —
`codex exec` has no `--ask-for-approval` flag, so passing one makes the call
exit 2 without running. The harness's hooks cannot see inside a CLI subprocess,
so `--sandbox read-only` is the only thing keeping the external model
read-only.

### A note on GitHub CLI telemetry

GitHub CLI telemetry is **opt-out** — it is on by default (gh v2.91.0 onward) —
and LogicLoom uses `gh` heavily. So setup tells you once and stops there:

```bash
bash .logic-loom/scripts/bash/check-gh-telemetry.sh   # read-only; run it any time
```

It reads `command -v gh`, the `DO_NOT_TRACK` / `GH_TELEMETRY` environment
variables, and the `telemetry:` key in your gh config file. It **changes
nothing** — not your gh config, not `~/.zshrc`, not `~/.bashrc` — and it always
exits 0, so a missing or unreadable gh install never blocks setup. Silence means
there is nothing to tell you.

If you want to opt out, that is yours to run:

```bash
gh config set telemetry disabled
```

Same boundary as above: this is a per-user, per-machine preference. LogicLoom
will not make it for you, and neither `init-project.sh` nor `/initialize-project`
will offer to.

**Versioning your personal config.** Keep `~/.claude/` itself out of git — it
holds session state and secrets-adjacent material. If you want a backup, the
workable pattern is a separate private repo holding *reference copies* you diff
against by hand. The honest tradeoff: those copies drift silently from the live
files unless you add your own check. LogicLoom ships no tooling for this and
does not automate it.

---

## Where to read next

- **CLAUDE.md** — full AI assistant instructions and hook-enforced governance
- **README.md** — framework features and architecture
- **AGENTS.md** — complete agent registry
- **features/README.md** — per-feature layout convention with rationale
- **.logic-loom/memory/constitution.md** — 16 principles (v3.3.0)
- **.docs/policies/** — framework policies

---

## Troubleshooting

- **Setup script won't run (macOS/Linux)**: `chmod +x init-project.sh && bash init-project.sh`
- **CRLF errors (Windows clones)**: `find .logic-loom/scripts -name "*.sh" -exec sed -i 's/\r$//' {} \; && chmod +x .logic-loom/scripts/*.sh .logic-loom/scripts/bash/*.sh && bash init-project.sh`
- **Claude Code ENOTEMPTY**: `rm -rf $(npm config get prefix)/lib/node_modules/@anthropic-ai/.claude-code-* 2>/dev/null && npm install -g @anthropic-ai/claude-code`
- **Still stuck?** Open Claude Code and ask: `"I'm setting up LogicLoom and hitting <paste error>. Help me diagnose."` The governance hook pulls in relevant memory and constitution context automatically.

---

**Welcome to LogicLoom.** Start with vision, plan with file boundaries, swarm in scope, review behavior, retro the loop.
