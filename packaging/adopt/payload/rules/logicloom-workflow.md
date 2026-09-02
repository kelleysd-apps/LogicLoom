# LogicLoom — workflow and delegation (installed rule)

Governance is the harness's durable core. Everything below it is an
**interchangeable workflow pack** — none privileged, none required. Pick by
problem shape, and picking none is a valid answer.

| Pack | Loop | Best for |
|---|---|---|
| **Swarm** | `/swarm explore` + `/research` → `/create-prd` → plan → `/plan-review` → `/swarm implement` → `/review-team` → `/retro` | exploratory work, unclear scope (`features/<name>/`) |
| **SDD waterfall** | `/specification` → `/build-team` or `/fullstack-team` → `/finalize` | a well-understood feature with stable requirements (`specs/###-name/`) |
| _(none)_ | direct execution | a quick fix with no significant unknowns |

Within the swarm pack, `vision.md` and `/plan-review` are **pack-internal
gates** — they exist to stop broad-spec cascade and worker collisions. They gate
that pack only, not the harness. Steps are skippable when you can say why.

Run `/help`, or read the command's own file under `.claude/commands/`, rather
than assuming what a command does. The per-feature folder convention is in
`features/README.md`.

## Ride the native orchestration; do not reimplement it

LogicLoom is a governance and dev layer on Claude Code's native orchestration,
not an orchestration engine. Spawn workers with the **Task tool** (parallel =
several Task calls in one message). Use **`/workflow`** for deterministic fan-out
and **`/loop`** for recurring cadence. There is no custom runner here — no
process manager, no session multiplexer, no shared swarm-state file. What the
harness adds on top is the hook floor, the plan-as-DAG file ownership enforced by
`freeze-write-scope.sh`, domain briefs, `/research`, and memory.

## Model and provider boundary

Orchestration and governance are **Claude-Code-native and assume an Anthropic
flagship model**. Cross-provider models are supported **only at the delegated
research and verification layer** — `/research` and `/cross-check` — where the
external model is strictly **advisory and read-only**: it returns findings, a
governed Claude agent triages and decides. It never writes repository source,
never runs git, and never makes a control-flow decision.

This boundary governs **the harness's own orchestration and governance
runtime** — the agents, commands, and workers LogicLoom itself dispatches. It
says nothing about what models the project you are building may call; an
application that legitimately calls OpenAI, Gemini, Mistral, or a local model
is fully compliant.

Select a model by **tier keyword** in frontmatter — `opus`, `sonnet`, `haiku`,
`inherit` — never a pinned version string. The role-to-tier convention lives in
`.logic-loom/config/models.conf`; it is a documented reference table, not a
runtime resolver, so nothing parses it for you.

Delegation policy: reasoning and architecture → the `deep-reasoner` agent;
mechanical or boilerplate work → `fast-worker` (both in `.claude/agents/`).
Correctness-critical and scrutiny-inviting work also gets `/cross-check`. The
orchestrator keeps the decision.

## Task tracking

1. Exactly **one** task `in_progress` at a time — never several.
2. Mark a task `completed` immediately; do not batch completions.
3. Create a task list for work of three or more steps; skip it for trivial work.
4. Keep the list to 3–10 focused items.

Project-level task state belongs in the pack's own files —
`features/<name>/plan.md` for swarm, `specs/###-feature/tasks.md` for SDD — not
in the session list.
