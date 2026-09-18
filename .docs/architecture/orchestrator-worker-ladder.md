# Orchestrator + Worker Ladder

**Status**: active · **Since**: 2026-06-30 · **Authority**: Constitution
Principles VI, X, XIV · **Config**: `.logic-loom/config/models.conf`

A dev-time delegation pattern for LogicLoom: a **frontier orchestrator** that
reasons, plans, and delegates, over a ladder of cheaper Claude **workers** that
do the bulk execution — with non-Claude models held to the existing
**advisory-only** layer. It is session tooling used to *build* things, not a
runtime system, and it does not change LogicLoom's governance floor.

## The ladder

| Rung | Tier | Model (default → fallback) | Job |
|---|---|---|---|
| **Orchestrator** | `frontier` | `claude-fable-5` → `claude-opus-4-8` | The main Claude Code session. Plans, reasons, decomposes, delegates, synthesizes. Emits few tokens; does **not** do bulk execution. |
| **deep-reasoner** | `opus` (effort `high`) | `claude-opus-4-8` | Architecture decisions, hard debugging, design tradeoffs. `.claude/agents/deep-reasoner.md`. |
| **fast-worker** | `sonnet` (effort `medium`) | `claude-sonnet-5` | Boilerplate, tests, routine mechanical edits. `.claude/agents/fast-worker.md`. |

**Economics**: the orchestrator is the priciest tier per token (Fable 5 is
$10/$50 per MTok), but a planner/delegator emits few tokens — the bulk-token
execution rides on Opus/Sonnet workers. Frontier tokens are spent where they pay
off (planning and hard reasoning), not on boilerplate.

## The orchestrator role is model-agnostic-but-frontier

The orchestrator is a **role**, not a pinned model. It targets the `frontier`
tier — any frontier-class **Anthropic** model — with a concrete default and a
documented fallback:

- **Default**: `claude-fable-5` (`FRONTIER_MODEL`).
- **Fallback**: `claude-opus-4-8` (`FRONTIER_FALLBACK`) — use when Fable 5 is
  unavailable or out of quota. Downgrading is a one-line change and does not
  alter the pattern.

**Mechanism** (Claude Code has no `frontier`/`fable` frontmatter keyword): set
the **main session model** with `/model claude-fable-5` (or `claude-opus-4-8`).
The orchestrator is the human-facing session, not a subagent — there is no
`orchestrator.md` agent file. Workers are subagents pinned via their frontmatter
`model:` tier keyword.

The orchestrator **never** runs on a non-Claude model. That would cross the
model/provider boundary (below) and Principle VI — orchestration is
Claude-Code-native.

## Delegation policy

- **Reasoning / architecture / hard debugging** → `deep-reasoner`.
- **Mechanical / boilerplate / test scaffolding** → `fast-worker`.
- **Correctness-critical output that invites scrutiny** → run `/cross-check`
  (cross-provider adversarial review) in parallel and synthesize both views
  before deciding (Cross-Check Disposition).
- The orchestrator keeps the decision. Workers and advisory models inform; they
  do not decide control flow.

## Running it in workflows and loops

The ladder composes with LogicLoom's native primitives — this is where it is
strongest:

- **`/workflow`** — `agent(prompt, { agentType: 'deep-reasoner' })` /
  `{ agentType: 'fast-worker' }` dispatches a named project agent inside a
  deterministic fan-out. `agent()` also takes a per-call **`effort`** override —
  so the workflow layer gives you the **dynamic per-dispatch effort** that raw
  Task-spawned subagents lack (Claude Code only honours *static* frontmatter
  `effort:`).
- **`/loop`** — wrap a workflow for recurring/self-paced cadence.
- **`/swarm`** — parallel Task fan-out; workers can carry these agent types.

Example shape (a workflow stage that reasons then implements):

```js
const design = await agent(designPrompt, { agentType: 'deep-reasoner', phase: 'Design' })
await parallel(design.tasks.map(t => () =>
  agent(t.prompt, { agentType: 'fast-worker', phase: 'Implement', effort: 'medium' })))
```

## Effort follows cost, fan-out follows width

A convention for choosing worker **effort** and **fan-out**, for any project
that adopts this ladder — generic, not tied to any individual's own config:

- **Cost sets effort; width sets how many workers** — never the other way. A
  wide, cheap, reversible sweep gets many low-effort workers; a narrow,
  irreversible change gets one high-effort worker.
- **Mechanics**: raw Task-spawned subagents only honour *static* frontmatter
  `effort:` (see `deep-reasoner` = high, `fast-worker` = medium above); a
  **dynamic** per-dispatch effort needs `/workflow`'s `agent()` call, as shown
  above.
- **External CLIs**: when an orchestrator invokes a CLI *directly* as an ad-hoc
  advisor (the escalation-ladder pattern — e.g. from a personal CLAUDE.md
  escalation section), pass the matching effort explicitly: Codex via
  `-c model_reasoning_effort=<level>`, Antigravity via `--effort low|medium|high`.
  `/cross-check` (the governed, shipped skill) is a **different case**: its
  Mode B `codex exec` invocation passes no effort flag today, so it runs at
  whatever `codex exec` defaults to — see
  `plugins/loom-orchestrator/skills/cross-check/SKILL.md`.
- **Antigravity headless caveat**: `agy -p` in `--mode plan` auto-denies its own
  tool calls, including file reads — so material must be **inlined in the
  prompt**, not left for the CLI to read from disk (verified via probes in
  `.brain/raw/research/2026-09-17-loom-0071-bash-sandbox.md`).

This is a **followed convention, not an enforced one**: no hook can see the
effort a Task or `agent()` call requested, so nothing here fails closed the
way the git-approval and protected-path hooks do. It is also **not a config
resolver** — a prior review rejected a parsed `effort-policy.conf`, because
nothing would enforce it and an account-specific model/effort table baked
into a shipped config would be wrong for every cloner with a different
account. Pick the mapping that fits your own escalation policy and models.

## The advisory boundary is unchanged

Non-Claude models (OpenAI/Codex, Gemini) remain **advisory + read-only**, at the
delegated verification layer only:

- **`/research`** — jury-on-demand multi-LLM tribunal.
- **`/cross-check`** — the governed cross-provider adversarial reviewer (also the
  key-gated slot in `/review-team` and `/plan-review`).

They emit findings; the governed Claude layer triages and decides. They never
write repo source, run git, or make a control-flow decision. The ladder does
**not** add non-Claude workers — that would move the enforced write path off the
Claude-Code hook floor (see `.docs/architecture/governance-threat-model.md`).

> **Codex peer-model plugin.** OpenAI's official `openai/codex-plugin-cc` is a
> *peer reviewer*, which is the **same capability `/cross-check` already
> provides**. If adopted, surface it **through** `/cross-check` (as a provider
> option), not as a parallel lane — otherwise two overlapping cross-provider
> review paths exist and only one carries the governance contract. Its
> `~/.codex/auth.json` is a secret: gitignore `.codex/config.toml` +
> `.codex/auth.json`, commit only `.codex/config.toml.example`.

## Setup

1. Set the session model: `/model claude-fable-5` (or `claude-opus-4-8`).
2. The `deep-reasoner` / `fast-worker` project agents travel with the repo — no
   `/agents` setup per clone. **File-based agents load at session start; editing
   them requires a session restart to take effect.**
3. Keep them as **project** agents (`.claude/agents/`), never plugin agents —
   plugin-packaged agents lose the `hooks` / `mcpServers` / `permissionMode`
   frontmatter (stripped for security), which LogicLoom's hook-enforced floor
   depends on.
