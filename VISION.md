<!--
PRODUCT VISION — LogicLoom. A LIVING north-star for the whole harness (not a
per-feature vision; those live in features/<name>/vision.md).

Purpose: keep the project aligned across separate sessions. Read this at the
start of strategic work; generate tasks from "Strategic Pillars" and "Open
Threads"; update it after each milestone (see "Keeping this document alive").

Philosophy (Anthropic harness-design article): a vision declares WHAT and WHY,
and the bet on HOW — it leaves room to reason about implementation. Keep it
short. Acceptance criteria and schemas belong in a PRD/plan, not here.
-->

# Vision: LogicLoom

**Product**: `logic-loom` (brand: **LogicLoom**)
**Document**: product north-star (living)
**Version**: 1.0 · **Last updated**: 2026-06-15 · **Owner**: brian@kelleysd.com
**Framework state**: v6.2.0 · constitution v3.1.0 · branch `loom-migration` (PR #56)

---

## North Star

**LogicLoom is a constitutional-governance-focused, framework-agnostic
development harness that ENHANCES the flagship model — by adding the things that
do NOT decay as models get smarter (governance, safety, observability, cost
discipline, file-ownership) while riding ON Claude Code's native orchestration,
never reimplementing it.**

One sentence to steer by: *be the durable floor and the value-on-top, not the
engine.*

## Why we exist (the bet)

Every harness component encodes an assumption about a model weakness. As the
model improves, the scaffolding built around those weaknesses **rots** —
per-message compliance ceremony, keyword routing, hand-rolled orchestration all
become drag. Two failure modes dominate the field:

1. **Over-building orchestration** the CLI now does natively (process managers,
   session multiplexers, shared swarm-state files) — dead weight the moment
   `/workflow`, `/loop`, `/goal`, and the Task tool exist.
2. **Disable-able guardrails** (cf. OpenClaw) — governance you can turn off is
   governance that gets turned off, then a security incident.

LogicLoom's bet: the durable, compounding value is a **thin governance FLOOR
that cannot be silently softened** plus a **value layer on top of native
primitives**. Governance, safety, observability, and cost discipline do not
decay with capability. Orchestration mechanics do.

## Who this is for

A developer (and their agents) doing real software work in Claude Code who wants
**guardrails they can trust without babysitting** and **multi-agent leverage
without standing up an orchestration framework**. They reach for native
`/workflow` / `/loop` / `/goal` daily and want a harness that amplifies that,
not one that competes with it.

## What success looks like

**Qualitative**
- The model is measurably *more* trustworthy for autonomous dev work *because*
  of the harness — not slower or more ceremonial.
- Governance holds regardless of which Anthropic model is driving; it never
  depends on the model "remembering" to comply.
- A new session can re-orient from `VISION.md` + memory + `CLAUDE.md` alone and
  stay on-strategy without re-litigating decisions.
- Adding a capability means shipping a plugin/brief, not patching the core.

**Quantitative** *(track as they become tractable)*
- Hook enforcement coverage of high-impact failure classes (autonomous git,
  governance self-modification, out-of-scope writes) → 100%, with residuals
  documented, not hidden.
- Contract-suite assertions green on every commit (currently 410 / 9 suites).
- Token/latency overhead of the governance layer kept negligible in `lean` mode.

## Strategic Pillars *(each pillar seeds tasks)*

1. **Governance is an enforced floor, not recitation and not a sandbox.**
   Hook-side, model-independent enforcement (git approval, subagent git-deny,
   governance-surface protection, freeze file-ownership, dangerous-command
   policy). It is defense-in-depth: it makes high-impact failures hard. Residual
   bypasses are documented honestly in the threat model, never papered over.

2. **Ride native primitives; don't reimplement orchestration.** Task tool for
   fan-out, `/workflow` for deterministic control flow, `/loop` for cadence,
   plan mode for design. LogicLoom adds the value the runtime doesn't: domain
   briefs, plan-as-DAG freeze ownership, the behavioral evaluator, jury-on-demand
   `/research`, and memory.

3. **Framework-agnostic, workflow-interchangeable.** Governance is the core;
   workflows are peer optional packs (swarm, SDD waterfall) chosen by problem
   shape. No privileged path, no "primary/legacy."

4. **Enhance the flagship; degrade gracefully.** `lean` (default, Opus-class):
   hooks enforce, zero per-message ceremony. `strict` (weaker/non-flagship):
   hooks plus re-injected assist. Enforcement is identical across modes; only
   the model-side help changes.

5. **Cross-session continuity is a feature.** The harness should stay coherent
   across sessions via memory + this living vision. Decisions get recorded once
   and respected thereafter.

6. **Honest model/provider boundary.** Orchestration + governance are
   Claude-Code-native and assume Anthropic flagship models. Cross-provider models
   (OpenAI/Gemini) are supported ONLY at the delegated `/research` layer — never
   for orchestration. We state the boundary plainly rather than overclaim
   portability.

## Recent shifts (how we now pursue the goals) — v6.2

The pivot that this vision encodes, driven by native `/workflow`/`/loop`/`/goal`
becoming first-class:

- **Cut the dev-loop pack** — native primitives supersede it; its runtime
  self-extension was a governance liability. Now 8 plugins, 2 workflow packs.
- **Hardened the governance floor** against the known PreToolUse bypasses
  (RFC#45427): added governance-surface protection (subagent→deny / main→ask),
  realpath-canonicalized freeze scope (closes `..`/symlink escape), and a written
  threat model that names the residuals. Codified "**floor, not sandbox.**"
- **Re-based orchestration on native primitives** — removed the custom-runner
  surface (launch-swarm/budget-manager, tmux/state-file coupling); the team
  skill now spawns via Task + `/workflow`.
- **Decoupled SDD from the agnostic core** — only `sdd-specification` carries SDD
  identity; the governance/tooling/swarm plugins are framework-neutral.

See memory: `architecture-v6-2-native-primitives` (and `-v6-1-opus48-rebase`).

## What this is NOT

- **Not an orchestration engine.** We do not own a process manager, session
  multiplexer, or shared swarm-state file. If the CLI does it natively, we ride
  it.
- **Not a provider-portable runtime.** The orchestration/governance layer is
  Anthropic-flagship-native by design.
- **Not a single methodology.** SDD is one pack among peers, not the product.
- **Not a sandbox.** The hook floor is deterministic defense-in-depth, not an
  execution jail. (An opt-in sandbox is an Open Thread, not a current claim.)
- **Not ceremony.** Governance is enforced by hooks, not by making the model
  recite a checklist every message.

## Open Threads *(the live backlog — generate tasks from here)*

Unresolved directions, roughly ordered. Each is a candidate to spin into a
feature/`vision.md` → PRD → plan, or a direct task.

- **Observability surface.** The SubagentStop hook is currently a benign stub.
  Build out a real, low-overhead observability stream (subagent lifecycle, hook
  decisions, cost) — Principle VII made tangible.
- **Cost discipline / preview.** Surface token/cost budgets and a pre-flight
  cost estimate for swarm/workflow fan-outs.
- **Contain the documented freeze residual.** The Bash-redirect escape of
  freeze file-ownership on arbitrary DAG paths is known and documented; decide
  whether to extend freeze to the Bash write-path or accept-and-monitor.
- **Lineage-based memory compression.** Hermes/Nous is ahead here; evaluate
  compressing memory along decision lineage to keep cross-session context cheap.
- **Tool registration-vs-exposure separation.** Another Hermes-ahead pattern:
  register many tools, expose few per-agent. Assess fit for swarm workers.
- **Opt-in execution sandbox.** A real isolation layer for untrusted execution,
  offered as opt-in — keeps "floor, not sandbox" honest while giving those who
  want a jail a path to one.
- **Evaluator-protocol maturation.** Harden `/review-team`'s behavioral
  evaluator contract (chrome-devtools MCP) and its hard-gate semantics.
- **Cross-session vision↔task sync loop.** A lightweight ritual (or `/loop`) that
  reconciles this VISION's Open Threads with active tasks and memory each session.

## Keeping this document alive

This file is the project's steering anchor across sessions. Maintenance protocol:

1. **At the start of strategic work**, read this alongside `CLAUDE.md`, `AGENTS.md`,
   and project memory. Treat the North Star + Pillars as standing constraints.
2. **To generate work**, pull from *Open Threads* (and unmet *success* metrics)
   into a `features/<name>/vision.md` or a task list — don't expand scope here.
3. **After each milestone**, update *Recent shifts*, *Current state* header
   (version/date/framework state), and prune/extend *Open Threads*. Bump the
   document **Version** and **Last updated**.
4. **When a decision lands**, record it in memory and reflect its consequence in
   the relevant Pillar or Thread — so the next session inherits it.
5. **Keep it short.** If a section is growing acceptance criteria or schemas, it
   belongs in a PRD/plan, not here.

---

*Generate from here: `/swarm explore <thread>` or `/research <question>` to open a
thread, then `/create-prd <name>` to synthesize. Per-feature visions go in
`features/<name>/vision.md`; this product vision stays at the root.*
