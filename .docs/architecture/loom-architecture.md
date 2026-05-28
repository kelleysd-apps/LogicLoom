# LogicLoom Architecture

**Status**: v6.0.0 (post-migration authoritative)
**Constitution**: v3.0.0 (16 principles, untouched in this migration)
**Migration source**: SDD-Workflow v5.0.0 → LogicLoom v6.0.0 (workflow-scope cutover)
**Reference**: Anthropic, "How we built our multi-agent harness."

---

## 1. Identity

- **Name**: `logic-loom` (slug) / **LogicLoom** (display)
- **Version**: v6.0.0
- **Repository layout**: three-layer separation, see §2.
- **Scope of this migration**: workflow only. Constitutional governance,
  preflight hook, and memory plugin are preserved as-is from v5.0.0.

## 2. Layers

LogicLoom keeps the three-layer separation introduced in v5.0.0; only the
namespace of layer-1 changes (`.specify/` → `.logic-loom/`).

| Layer | Path | Contents |
|-------|------|----------|
| 1. Governance + infra | `.logic-loom/` | constitution.md, MEMORY.md, lib/ (logging.sh, policy.sh), scripts/, templates/, config/, plans/, tests/ |
| 2. Harness integration | `.claude/` | hooks/, commands/ (bridge-generated), context/, settings.json |
| 3. Capabilities | `plugins/` | All skills, agents, commands (plugin-first per Principle XVI) |

**Worker workspace**: `features/<feature-name>/` holds vision.md, prd.md,
plan.md, and sprint output. This replaces `specs/###-name/` from v5.0.0.

## 3. Primary workflow — vision / PRD / plan / swarm

The primary loop is a 12-step pipeline. Each step is gated by a verifier or
by the immediately downstream step's preconditions.

1. **EnterWorktree** — isolate the feature on its own branch + working tree.
   `worktree-port-namespace.sh` writes `.loom-worktree-env` with the
   per-worktree port offset.
2. **`/swarm explore`** — read-only investigators sweep the codebase and
   external references; produces an exploration report under
   `features/<name>/explore/`.
3. **`/research`** — optional jury-on-demand multi-LLM research call (see §9).
4. **`/create-prd`** — auto-detect existing vision.md; produce vision.md
   (if absent) + prd.md from exploration + research artifacts.
5. **plan-mode** — Claude drafts `features/<name>/plan.md` as a DAG (see §5).
6. **`/plan-review`** — separate-context reviewer grades the plan against
   the PRD before any code is written. Blocks `/swarm implement` on fail.
7. **`/swarm implement`** — DAG executor. Topologically sorts tasks, injects
   `LOOM_ACTIVE_FEATURE` + `LOOM_ACTIVE_TASK` env vars before dispatching each
   worker so the freeze-write-scope hook gates writes (see §6).
8. **Test + fix** — implementor task runs project test command, iterates on
   failures up to its rubric budget.
9. **`/review-team`** — four reviewers run in parallel: security, quality,
   performance, and the behavioral evaluator (see §8).
10. **`/git-push`** — gated git workflow (Principle VI). Opens PR.
11. **`/code-review`** — diff-level correctness review on the PR.
12. **`/retro`** + **ExitWorktree** — write a short retrospective; tear down
    the worktree.

## 4. Legacy SDD workflow

The waterfall workflow remains available and is **not** removed in v6.0.0:

- `/specification` — three-phase SDD waterfall (spec → plan → tasks).
- `/build-team` — sequential architect → implementor → reviewer.
- `/fullstack-team` — parallel frontend + backend + database team.
- `/dev-loop` — recursive edit-test-debug loop with tribunal voting.
- `/finalize` — pre-commit constitutional compliance validator.

Use the legacy commands when the task is constrained, contract-first, and
benefits from a fully specified up-front design. Use the primary workflow
(§3) when the task is exploratory, surface-bearing, or has a quality bar
that needs behavioral grading.

Legacy docs live at `.docs/workflows/sdd-waterfall.md` (not migrated;
existing v5.0.0 documentation remains canonical).

## 5. Plan-as-DAG handoff contract

`features/<name>/plan.md` is the single source of truth between plan-mode
and `/swarm implement`. The plan body is a YAML-ish DAG in a fenced
code block; sections after the DAG are prose.

### YAML schema

```yaml
sprints:
  - id: 01
    description: "Foundations"
    tasks:
      - id: T01
        description: "Add logging.sh DEBUG default"
        owns:
          - .logic-loom/lib/logging.sh
        freeze:
          - .logic-loom/memory/constitution.md
        depends_on: []
        rubric:
          - test: "set -u sourcing logging.sh does not exit nonzero"
          - lint: "shellcheck clean"
      - id: T02
        description: "Wire helper into policy.sh"
        owns:
          - .logic-loom/lib/policy.sh
        freeze: []
        depends_on:
          - T01
        rubric:
          - test: "policy.sh unit tests pass"
```

### Rules (v0.1)

- **Topological sort**: Kahn's algorithm. Cycles are a parser error;
  `/swarm implement` refuses to dispatch.
- **One-task-one-owner**: if two tasks declare the same path in `owns`, the
  plan is rejected. Prevents write races.
- **Per-task rubric**: every task must declare at least one rubric item
  (`test:`, `lint:`, or `manual:`). `/review-team` checks before
  dependents are dispatched. A failing rubric blocks downstream tasks.
- **Freeze list**: optional explicit denylist. Defense-in-depth on top of
  `owns`. Enforced by the freeze-write-scope hook (see §6 and
  freeze-scope-protocol.md).
- **Sprint order**: sprints run sequentially. Within a sprint, v0.1
  dispatches tasks sequentially in topological order; **parallel waves are
  deferred to v0.2**.

## 6. Hook architecture

LogicLoom hooks live in `.claude/hooks/` and are wired in
`.claude/settings.json`. Three categories:

### Governance hooks (preserved from v5.0.0)

| Hook | Event | Purpose | Principle |
|------|-------|---------|-----------|
| `user-prompt-submit` | UserPromptSubmit | Injects constitutional governance reminder + domain detection + memory context | I–XVI |
| `guard-dangerous-commands.sh` | PreToolUse | Gates destructive bash commands; never auto-runs git | VI, XI |

### LogicLoom hooks (new in v6.0.0)

| Hook | Event | Purpose |
|------|-------|---------|
| `worktree-port-namespace.sh` | SessionStart | Computes per-worktree port offset; writes `.loom-worktree-env` sidecar so dev servers do not collide across parallel features |
| `context-cap-warn.sh` | UserPromptSubmit | Warns when context usage approaches 800K of the 1M window; surfaces a hint to compact |
| `freeze-write-scope.sh` | PreToolUse (Write\|Edit\|MultiEdit\|NotebookEdit) | Enforces plan-as-DAG file ownership at write time; see freeze-scope-protocol.md |

## 7. /swarm modes

`/swarm` is the unified multi-agent dispatch command. It has three modes:

- **`explore`** (read-only) — spawns investigator workers with Read/Grep/Glob
  tools only. Writes a single exploration report; no code edits. Used in
  primary workflow step 2.
- **`implement`** (DAG executor) — reads `features/<name>/plan.md`, performs
  topological sort, dispatches one worker per task. Before each dispatch,
  injects `LOOM_ACTIVE_FEATURE=<feature>` and `LOOM_ACTIVE_TASK=<id>` into
  the worker's environment so the freeze-write-scope hook can resolve the
  active scope and gate writes to that task's `owns:` list.
- **`generic`** (legacy team-orchestration) — preserves the v5.0.0 behavior
  of the team commands (`/build-team`, `/fullstack-team`, `/review-team`).

`/swarm` without a mode flag selects `generic` for backward compatibility.

## 8. /review-team 4-reviewer architecture

`/review-team` spawns four reviewers in parallel via the team-orchestration
skill:

1. **Security** — static review against the threat model.
2. **Quality** — static review against the constitution and project style.
3. **Performance** — static review for latency / allocation / N+1 patterns.
4. **Evaluator (behavioral)** — loads the running surface, takes
   accessibility-tree snapshots, grades against vision.md success criteria.
   See `evaluator-protocol.md` for the full rubric and synthesis rule.

**Functionality-fail override**: if the evaluator returns `fail` on the
Functionality rubric item, the team verdict is `fail` regardless of the
other three reviewers. Beautiful-but-broken is never shipped.

## 9. /research jury-on-demand

`/research` is the multi-LLM tribunal research command. v6.0.0 introduces
a query-type classifier that picks 1–3 judges instead of always calling all
three (Claude / OpenAI / Gemini):

- Fact-lookup queries → 1 judge.
- Reasoning queries → 2 judges + cross-vote.
- High-stakes / architectural queries → 3 judges + tribunal vote.

The `--judges all` flag preserves the v5.0.0 behavior for callers that want
deterministic three-way voting. Reference: arxiv 2512.01786 (Jury on Demand).

## 10. Memory architecture

The `sdd-memory` plugin is preserved unchanged. It injects relevant project
memory (past specs, tasks, sessions) into `additionalContext` via the
preflight hook.

**Deferred**: a 3rd-party memory tier (Mem0 / Letta) was scoped during
migration research and **deferred** as out-of-scope for v6.0.0. See §13.

## 11. Third-party discovery

LogicLoom does not run its own plugin marketplace in v6.0.0. Plugin and
skill discovery is delegated to the surrounding ecosystem:

- **Skills and plugins**: Anthropic Claude Code Plugin Marketplace.
- **MCP servers**: Docker MCP Toolkit (310+ containerized servers, `mcp-find`
  / `mcp-add` / `mcp-config-set` tools).

The v5.0.0 `mcp-servers/sdd-marketplace/` MCP server is retired.

## 12. Constitutional governance

The 16-principle constitution at `.logic-loom/memory/constitution.md` is
**unchanged** in v6.0.0. The migration is workflow-scope; principles I–XVI
and their enforcement (preflight hook, git-safety gates, finalize validator,
agent delegation rules) remain authoritative.

Quick reference (full text in constitution.md):

- **I** Library-First, **II** Test-First, **III** Contract-First (immutable).
- **VI** Git Approval — no autonomous git operations.
- **X** Agent Delegation — specialized work must be delegated.
- **XI** Input Validation — load-bearing for the freeze-write-scope hook.
- **XVI** Plugin-First Architecture — all new features ship as plugins.

## 13. Future work

Items scoped during May 2026 frontier-research review and **deferred** from
v6.0.0:

- **STORM write-arbiter** (arxiv 2605.20563) — multi-writer arbitration for
  long-form planning artifacts.
- **Policy Invariance jury smoke-test** (arxiv 2605.06161) — adversarial
  prompt-injection smoke test for `/research` jury composition.
- **Async subagents** — fire-and-forget task dispatch with later harvest.
- **Magentic ledger** — explicit shared state ledger across multi-agent runs.
- **Cursor parallel-detect** — pre-dispatch parallelizability analysis on
  plan DAGs (would enable §5 parallel waves).
- **Cost preview** — pre-flight token/dollar estimate before `/swarm`
  dispatch.
- **Screen-recording on evaluator fail** — Devin 2.2 pattern; capture short
  video of the failing interaction. Requires chrome-devtools MCP support.
- **Property-based testing branch** for the evaluator's non-UI branch
  (fast-check / Hypothesis). See evaluator-protocol.md §Future work.
- **Three-tier memory upgrade** — Mem0 or Letta integration as a 3rd-party
  memory tier alongside sdd-memory.
- **Sherlock-style replay debugging** (arxiv 2511.00330) — deterministic
  replay of failed worker dispatches.

## 14. References

- Anthropic, "How we built our multi-agent harness." See
  `.logic-loom/memory/MEMORY.md` →
  `reference_anthropic_harness_design.md` for indexed notes.
- Garry Tan / gstack — gstack cross-comparison. See `MEMORY.md` →
  `reference_gstack_research.md`.
- arxiv 2511.00330 — Sherlock (deterministic replay).
- arxiv 2512.01786 — Jury on Demand (query-type-driven judge selection).
- arxiv 2605.20563 — STORM (multi-writer write arbitration).
- arxiv 2605.06161 — Policy Invariance (jury adversarial robustness).
- `.docs/architecture/evaluator-protocol.md` — 4th-reviewer behavioral
  grader protocol.
- `.docs/architecture/freeze-scope-protocol.md` — freeze-write-scope hook
  protocol.
