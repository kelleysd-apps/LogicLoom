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
**Version**: 2.2 · **Last updated**: 2026-08-24 · **Owner**: brian@kelleysd.com
**Framework state**: v6.4.1 · constitution v3.3.0 · dev line `dev-main` · template line `main` (v6.4.1, 2026-08-13)

---

## North Star

**LogicLoom is a constitutional-governance-focused, workflow-agnostic
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

**The bet has been tested against our own output.** Five subsystems this project
built were later cut rather than defended: the `sdd-marketplace` MCP, RL
telemetry, the dev-loop pack, DS-STAR refinement, and the custom swarm runner.
Willingness to delete our own work is the practical form of this bet.

## Who this is for

A developer (and their agents) doing real software work in Claude Code who wants
**guardrails they can trust without babysitting** and **multi-agent leverage
without standing up an orchestration framework**. They reach for native
`/workflow` / `/loop` / `/goal` daily and want a harness that amplifies that,
not one that competes with it.

Increasingly also: **a cloner** — someone who takes the sanitized template line
and runs their own project on it. Their experience is a first-class concern, not
a byproduct (see Pillar 7).

## What success looks like

**Qualitative**
- The model is measurably *more* trustworthy for autonomous dev work *because*
  of the harness — not slower or more ceremonial.
- Governance holds regardless of which Anthropic model is driving; it never
  depends on the model "remembering" to comply.
- A new session can re-orient from `VISION.md` + memory + `CLAUDE.md` alone and
  stay on-strategy without re-litigating decisions.
- Adding a capability means shipping a plugin/brief, not patching the core.
- A cloner can install, run, and **update** without touching anything they wrote.

**Quantitative** *(track as they become tractable)*
- Hook enforcement coverage of high-impact failure classes (autonomous git,
  governance self-modification, out-of-scope writes) → 100%, with residuals
  documented, not hidden.
- Contract-suite assertions green on every commit
  (currently **461 / 462 across 14 suites**; one known cosmetic failure —
  see Open Threads).
- Token/latency overhead of the governance layer kept negligible in `lean` mode.
- Design-to-landed latency: no verified user-facing defect stays open while new
  design work accumulates (see "Standing risk").

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
   `/research`, `/cross-check`, and memory.

3. **Workflow-agnostic and workflow-interchangeable.** Governance is the core;
   workflows are peer optional packs (swarm, SDD waterfall) chosen by problem
   shape. No privileged path, no "primary/legacy."

4. **Enhance the flagship; degrade gracefully — and visibly.** `lean` (default,
   Opus-class): hooks enforce, zero per-message ceremony. `strict`
   (weaker/non-flagship): hooks plus re-injected assist. Enforcement is identical
   across modes. Where enforcement genuinely *cannot* hold (bash < 4, Windows
   without Git Bash), it must degrade **loudly** — a silently-absent floor with
   an identical UI is the worst outcome in the system.

5. **Cross-session continuity is a feature.** The harness should stay coherent
   across sessions via memory + this living vision. Decisions get recorded once
   and respected thereafter.

6. **Honest model/provider boundary — policy travels, enforcement does not.**
   *(Revised in v6.3.0; supersedes the earlier absolute "not provider-portable.")*
   The **policy** layer is provider-neutral and portable: the constitution, the
   operating principles, and the Cross-Check Disposition are model-followed rules
   sourced neutrally from `AGENTS.md` Tier 1. The **enforcement** layer is not:
   the hook floor is the Claude Code *reference adapter*, and on any other host
   those guarantees are followed-only until a conformant adapter exists.
   Orchestration remains Anthropic-flagship-native. Cross-provider models are
   admitted **only** at the delegated verification layer — `/research` and
   `/cross-check` — where they are advisory, read-only, and never touch git or
   control flow. The enforced-vs-followed matrix lives in
   `.docs/architecture/governance-threat-model.md`.

7. **Thin core, composable packages, untouched user layer.** The core owns only
   the enforced floor, the constitution, and the update/bridge scaffolding.
   Everything else is a package. Anything a *user* authors — settings, guidance,
   commands, agents, MCPs, constitution amendments, feature work — lives in a
   sink the updater structurally cannot see. All three properties are delivered
   by Claude Code's **native layered-config model** (USER < PROJECT < PLUGIN),
   not by a bespoke engine. Design:
   `features/modular-harness/exploration/unified-architecture.md`.

8. **Deterministic over inferred, where a graph is concerned.** The project's
   knowledge and component graph is a git-tracked, byte-reproducible text
   artifact built from manifests, frontmatter, and author-written
   `[[wikilink]]`/`SUPERSEDES` edges — zero LLM in the extraction path, no DB,
   daemon, port, or watcher. LLM-semantic graph tools are a user-layer
   escalation, never a dependency. Decision:
   `features/code-knowledge-graph/exploration/graph-stack-decision.md`.

## Recent shifts (how we now pursue the goals) — v6.3.x

- **Policy/enforcement split shipped (v6.3.0).** `AGENTS.md` Tier 1 as the
  neutral policy source, the Cross-Check Disposition, the `governance-verdicts.sh`
  verdict seam (self-protecting, fail-safe), and an off-host git adapter. This
  retired the blanket "not provider-portable" claim in favor of the scoped one
  in Pillar 6.
- **`/cross-check` became the canonical adversarial path** — a governed
  cross-provider reviewer, and the key-gated slot inside `/review-team` and
  `/plan-review`.
- **Release model settled**: `dev-main` is the publicly-visible dev mainline;
  `main` is the sanitized template line, cut via `/promote` +
  `promote-to-main.yml` with auto-tag-on-merge. Single public repo.
- **Model-agnostic orchestrator ladder** — a frontier orchestrator *role*
  (Fable 5 → Opus 4.8 fallback) over `deep-reasoner` / `fast-worker` project
  agents, with a tier-keyword convention guarded by `test_model_agnostic.sh`.
- **Product-workspace boundary defined** — the framework owns the repo root;
  product code lives in `web/` or `apps/<name>/` with its own package.json and
  test runner, ending the silent jest/coverage collisions.
- **Anti-overbuild exercised twice more**: DS-STAR removed (61 files); the graph
  stack was scoped down to a deterministic text artifact after an adopt-existing
  evaluation rejected the heavyweight option on reproducibility grounds.

Memory: `architecture-v7-provider-portable-pivot`,
`unified-architecture-thin-core`, `graph-stack-decision`,
`model-agnostic-orchestration`.

## What this is NOT

- **Not an orchestration engine.** We do not own a process manager, session
  multiplexer, or shared swarm-state file. If the CLI does it natively, we ride
  it.
- **Not a provider-portable *runtime*.** Policy travels; enforcement is
  Claude-Code-reference. We state which is which rather than overclaim (Pillar 6).
- **Not a single methodology.** SDD is one pack among peers, not the product.
- **Not a sandbox.** The hook floor is deterministic defense-in-depth, not an
  execution jail. (An opt-in sandbox is an Open Thread, not a current claim.)
- **Not ceremony.** Governance is enforced by hooks, not by making the model
  recite a checklist every message.
- **Not a GraphRAG / LLM-extraction system.** The graph is deterministic text.
  LLM-inferred graphs are a user-layer option, never bundled.

## Standing risk

**The project generates high-quality design faster than it lands it.** As of
this revision: three substantial exploration syntheses and one complete,
test-green feature sit uncommitted, while a verified user-facing distribution
defect has been known since 2026-07-09. This is an execution-cadence problem, not
a direction problem — the direction is sound. The "Now" block below exists to
correct it, and the design-to-landed-latency metric above exists to keep it
visible.

## Open Threads *(the live backlog — generate tasks from here)*

Ordered by what should happen next. Each is a candidate to spin into a
`features/<name>/vision.md` → PRD → plan, or a direct task.

**Convention for closed threads:** a resolved thread is **kept in place**, marked
`✅ RESOLVED (<date>, <version>)`, its original text left intact, and a short
`**Fix:**` line appended recording what actually landed. Threads are pruned only
when the whole section is rewritten — a closed thread is the record that the
defect was real. Anything not marked `✅ RESOLVED` is still open.

### Now — verified defects and unlanded work

1. ✅ **RESOLVED (2026-08-13, v6.4.1) — Fix the dead `.sdd-sync-ref` on the
   template line.** `origin/main` shipped `.sdd-sync-ref = 6c4c420`, a commit
   reachable from **neither** `origin/main` nor `origin/dev-main` — a local-only
   artifact of the sanitizing promote flow. A fresh cloner therefore got an
   unresolvable ref and **`/update-framework` could not work for any new user**.
   **Fix:** four parts, all landed —
   (a) one-time auto-remap of the known-bad baseline in
   `plugins/loom-maintenance/scripts/extract-proposals.sh`
   (`remap_known_bad_sync_ref`, with a user-visible NOTICE), so existing clones
   self-repair on the next `/update-framework`;
   (b) a prevention gate in `.github/workflows/release-tag.yml` that aborts the
   release when the snapshot is not an ancestor of `main` HEAD;
   (c) repo settings corrected to **merge-commit-only** (squash-merging the
   release PR was the root cause — it left the snapshot commit only ever on a
   release branch);
   (d) pinned issue #66 telling already-cloned users what to expect.

2. **Fix the `.gitignore` portability bug.** Committed `.gitignore` has `.local/`
   and `*.local`, and `*.local` matches **neither** `settings.local.json` nor
   `CLAUDE.local.md`. They are ignored on the maintainer's machine only via a
   personal global ignore. A cloner would **commit their own local overrides**,
   breaking the Pillar-7 preservation model before it starts. Two lines.

3. ✅ **RESOLVED (2026-08-17, v6.4.1) — Land the uncommitted increment on
   `dev-main`** (17 untracked + 6 modified
   files): the project-graph stack (`build-graph-bridge.sh`, `lint-graph.sh`,
   `/graph` + `project-graph` skill, `graph-bridge.jsonl`, 13/13 green), the
   `guard-dangerous-commands.sh` bash-4 re-exec fix, the advisory `/finalize`
   graph lint, CI wiring, and the two exploration feature folders. Resolve
   thread 4 first — it decides file placement.
   **Fix:** landed in commit `24dda52` ("feat(graph): deterministic project graph
   bridge + guard-dangerous bash4 re-exec") — the graph scripts, the
   `graph-bridge.jsonl` artifact at `.logic-loom/graph/`, the `/graph` command +
   `project-graph` skill, the guard bash-4 re-exec, the advisory `/finalize`
   graph lint, the `plugin-tests.yml` CI wiring, and the exploration feature
   folders are all tracked; the working tree is clean. Thread 4 (layer
   placement) was **not** resolved first and remains open — the code landed in
   core (`.logic-loom/scripts/bash/` + `loom-orchestrator`), so relocating it to
   a `loom-graph` package is still outstanding under thread 4.

4. **Resolve the graph's layer placement.** Both designs agree the graph should
   be a **`loom-graph` package**; the code as built lives in core
   (`.logic-loom/scripts/bash/`) plus `loom-orchestrator`, matching neither — and
   growing the core that Pillar 7 is trying to shrink. The
   build-vs-adopt question is already settled (keep the deterministic bespoke
   harvester; Understand-Anything and Obsidian are user-layer-only) — only
   placement is open.

5. **Register `artifacts/` as a first-class directory.** The new repo-root
   `artifacts/` (who/what/why/where — vision, research, forensics, docs; never
   a plan) is untracked and absent from `CLAUDE.md`'s directory structure and
   the file-structure policy.

6. ✅ **RESOLVED (2026-08-13, v6.4.1) — Fix the one failing contract
   assertion** — `test_update_framework.sh`: "Help text mentions release tags"
   (cosmetic; 461/462 otherwise green). **Fix:** landed alongside thread 1's
   `extract-proposals.sh` work; the suite is now 19/19 green and the whole
   contract set is 25 suites / 914 assertions / 0 failed.

### Next — the thin-core / preservation track

7. **Core-paths manifest + constitution split.** Add
   `.logic-loom/config/core-paths.manifest` (CORE globs vs USER denylist, CORE
   evaluated first for rename safety) and one `extract-proposals.sh` filter that
   demotes denylist hits to info-only. Split user amendments into
   `.logic-loom/memory/amendments.md` (never overwritten; immutable I–III
   un-overridable, lint-enforced) with the effective constitution injected as
   core ∪ amendments. Turns "never touch user files" from incidental to declared.

   **Partially landed (2026-08-17, constitution v3.3.0) — thread stays OPEN.**
   The *constitution-split half* is done: constitution v3.3.0 § *Project
   Amendments* declares `.logic-loom/memory/amendments.md` as the fork extension
   point, `amendments-template.md` seeds it, and upstream deliberately never
   ships the file — so it is never overwritten and the constitution stops being a
   `conflict-review` file. The unit is a **named mandate**, composed
   conjunctively; a mandate may tighten I–III, and conflicts, contradictions, and
   ambiguity all resolve toward the floor under an explicit precedence order.
   **Still open, and why this is not marked resolved:** (a)
   `.logic-loom/config/core-paths.manifest` does not exist and
   `extract-proposals.sh` has no denylist→info-only filter, so "never touch user
   files" is still incidental rather than declared for every other user path;
   (b) nothing *injects* core ∪ amendments — no loader, preflight hook, or
   context module reads `amendments.md`, so mandates are followed only because
   `CLAUDE.md`/`AGENTS.md` tell agents to read it; (c) the additive-only property is stated and adjudicated, not structural — the
   grammar has no relaxing verb, but `Rule` is free natural language, so a
   semantically weakening mandate can still be written, and there is no lint
   asserting anything.

8. ⚠️ **CONTESTED — pending a maintainer direction call. Do not action.**
   *Original thread:* **Add `marketplace.json`.** None exists anywhere — the
   single biggest gap in the two-tier update model. One file makes the repo its
   own marketplace so packs update via native `/plugin update` while the core
   updates via `/update-framework`. Omit `loom-governance` from `plugins[]`; the
   floor stays root-anchored and un-disable-able.

   **The contradiction (recorded 2026-08-15, not decided):** this thread points
   the repo *into* the marketplace business. The maintainer has since stated the
   intent to *shut the marketplace down* ("finish shutting down the plugin
   marketplace repo"), and the in-repo residue of the removed `sdd-marketplace`
   MCP was cleared on that basis. A separate, still-open proposal
   (backlog-2026-08-13 §8.1) goes further and asks whether LogicLoom's eight
   plugins should be **externalized** to third-party sources — the opposite of
   this repo publishing its own marketplace. The two directions cannot both be
   pursued.

   Constraints already established and unchanged by any of this:
   `loom-governance` **is** the hook floor and a user-disablable
   marketplace-installed plugin is not a floor; all 19 bridged commands are
   pointers into `plugins/` with no static fallback; Principle XVI requires every
   plugin to declare `loom-governance` as a dependency, which a harness-agnostic
   third-party plugin cannot do.

   **Next step is a decision, not an implementation.** Until the maintainer picks
   a direction, treat this thread as unsettled and cite neither position as
   agreed.

9. **`/governance-health` self-check + per-surface conformance matrix.** Actually
   trigger each floor hook and report which fired, on whatever surface you're on.
   This is what makes Pillar 4's "degrade visibly" real, and it is the honest
   answer to the Windows-without-Git-Bash silent-absence case.

   **Partially landed (verified 2026-08-24) — thread stays OPEN.** The *matrix*
   half now exists on paper:
   `.docs/architecture/orchestration-hook-enforcement.md` § *Surface portability*
   tabulates five surfaces, and the threat model adds the L1/L2/L3 layering plus
   the adapter-conformance contract. The *self-check* half does not exist:
   `/governance-health` appears nowhere in the repo except this thread, the
   threat model's own wishlist ("a `/governance-health` self-test is still the
   intended loud signal"), and the modular-harness exploration. No command,
   script, or test fires a floor hook and reports what actually fired.

10. **Empirically confirm the cloud floor.** Docs say repo-committed hooks clone
    and fire in cloud sessions; run one trivial PreToolUse `deny` hook in a cloud
    session to *prove* it before advertising uniform enforcement — and check
    whether managed-settings `allowManagedHooksOnly` silently de-authorizes a
    cloned repo's hooks under an org policy.

    **Re-verified 2026-08-24 — still open, still unproven.** The surface table
    exists, but its Confidence column reads "official docs" for the cloud row —
    documentation, not a run. `allowManagedHooksOnly` appears nowhere in the tree
    except this thread and the exploration doc that spawned it.

### Later — durable-value expansion

11. **Observability surface.** The SubagentStop hook is still a benign stub.
    Build a real, low-overhead stream (subagent lifecycle, hook decisions, cost)
    — Principle VII made tangible.

    **Re-verified 2026-08-24 — still open, and understated.** The hook is
    `plugins/loom-orchestrator/hooks/scripts/agent-stop-notification.sh`: it
    appends one `subagent_stop agent=<name>` line, and only when
    `.logic-loom/logs/` already exists. Worse, it is wired only through that
    plugin's own `hooks/hooks.json`, whose flat-array shape the threat model
    records as "almost certainly inert" — so the stub may not fire at all
    (`subagent-activity.log` holds a single line, last written 2026-06-14). No
    hook-decision or cost stream exists anywhere.

12. **Cost discipline / preview.** Token and cost budgets plus a pre-flight
    estimate for swarm/workflow fan-outs.

    **Re-verified 2026-08-24 — still open, nothing built.** The only "budget" in
    the tree is prose in the `/swarm` and `/research` command docs and
    token-truncation inside memory search. Consequence: the *What success looks
    like* metric "token/latency overhead of the governance layer kept negligible
    in `lean` mode" has no instrument behind it.

13. **Contain the documented freeze residual.** The Bash-redirect escape of
    freeze file-ownership is known and documented; decide between extending
    freeze to the Bash write-path and accept-and-monitor.

    **Re-verified 2026-08-24 — still open, decision still not taken.**
    `.claude/settings.json` wires `freeze-write-scope.sh` to
    `Write|Edit|MultiEdit|NotebookEdit` only; the `Bash` matcher carries the
    three git/protection guards and nothing scoped to the freeze DAG. Recorded
    unchanged as residual #2 in the threat model.

14. **Memory as a graph, not a keyword index.** Harvest the temporal edge
    vocabulary (`SUPERSEDES`/`CORRECTS`/`RETAINED`/`REMOVED`) the bridge
    currently emits zero of, and wire 1-hop expansion into
    `keyword-backend.sh` so author-written edges stop being dead metadata.
    Subsumes the older "lineage-based memory compression" thread.

    **Re-verified 2026-08-24 — still open and accurate verbatim.**
    `.logic-loom/graph/graph-bridge.jsonl` holds 101 entities and 61 relations,
    every one of them `mentions` (44) or `links-to` (17). `build-graph-bridge.sh`
    knows only `links-to|mentions|covers|decided-by`; no temporal verb appears in
    it, in `lint-graph.sh`, or anywhere in `plugins/loom-memory/`.

15. **Opt-in execution sandbox.** A real isolation layer for untrusted execution,
    offered opt-in — keeps "floor, not sandbox" honest while giving those who
    want a jail a path to one.

    **Re-scoped 2026-08-24 — still open, but the "build it" half is now
    suspect.** The host itself sandboxes tool execution (the Bash tool exposes a
    `dangerouslyDisableSandbox` escape hatch — i.e. isolation is the runtime's
    default posture, not a missing LogicLoom layer). Under Pillar 2 the honest
    thread is now *evaluate and surface the native boundary*, not build one.
    Threat-model residual #4 still asserts "no execution sandbox" as a LogicLoom
    fact and needs the same reconciliation.

16. **Evaluator-protocol maturation.** Harden `/review-team`'s behavioral
    evaluator contract (chrome-devtools MCP) and its hard-gate semantics.

    **Re-verified 2026-08-24 — still open, and understated.**
    `.docs/architecture/evaluator-protocol.md` is still stamped **v0.1 (Loom
    migration, Stage 8)** and defines no gate semantics at all: the word "gate"
    appears twice, both times to say gating is `/plan-review`'s job. There is no
    hard-gate contract to harden yet — one has to be written.

17. ⚠️ **STALE (assessed 2026-08-24) — the runtime now does this natively.**
    *Original thread:* **Tool registration-vs-exposure separation.** Register many
    tools, expose few per-agent. Assess fit for swarm workers.

    **What changed:** Claude Code ships deferred tools plus a `ToolSearch` tool —
    tools are registered but their schemas are not exposed until a search loads
    them. That *is* this separation, in the runtime. `AGENTS.md` already lists
    `ToolSearch` in the main-agent tool set and `.claude/statusline.sh` renders
    it. Building our own would be reimplementation under Pillar 2. What survives
    is a much smaller question — whether swarm/team worker briefs should say
    anything about which tools a worker loads. Kept as the record; not work.

18. **Cross-session vision↔task sync loop.** A lightweight ritual (or `/loop`)
    reconciling these Open Threads with active tasks and memory each session —
    the mechanism that would have caught this document going 6 weeks stale.

    **Partially landed (2026-08-20/21) — thread stays OPEN.** The *task* half
    shipped: `.logic-loom/memory/todos.md` + `backlog.md` as the Level-0 SSOT,
    `lint-backlog.sh`, `build-backlog-index.sh`, and the published dashboard
    under its freshness gate. `backlog.md` even states the relationship —
    "VISION threads are *direction*; backlog items are *work*." **Still open:**
    nothing reconciles the two. Neither `lint-backlog.sh` nor
    `build-backlog-index.sh` reads `VISION.md`, no thread records the item ids it
    spawned, and this audit — threads #9–#18, unchecked since they were written —
    had to be run by hand.

## Keeping this document alive

This file is the project's steering anchor across sessions. Maintenance protocol:

1. **At the start of strategic work**, read this alongside `CLAUDE.md`, `AGENTS.md`,
   and project memory. Treat the North Star + Pillars as standing constraints.
2. **To generate work**, pull from *Open Threads* (and unmet *success* metrics)
   into a `features/<name>/vision.md` or a task list — don't expand scope here.
3. **After each milestone**, update *Recent shifts*, the *Framework state* header
   (version/date/branch), and prune/extend *Open Threads*. Bump the document
   **Version** and **Last updated**.
4. **When a decision lands**, record it in memory and reflect its consequence in
   the relevant Pillar or Thread — so the next session inherits it.
5. **When a claim here is superseded, revise it in place and say so** (see
   Pillar 6) rather than leaving a stale absolute standing.
6. **Keep it short.** If a section is growing acceptance criteria or schemas, it
   belongs in a PRD/plan, not here.

---

*Generate from here: `/swarm explore <thread>` or `/research <question>` to open a
thread, then `/create-prd <name>` to synthesize. Per-feature visions go in
`features/<name>/vision.md`; this product vision stays at the root.*
