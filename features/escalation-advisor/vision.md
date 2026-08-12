# Vision: Universal Advisor + Escalation System

**Feature**: `escalation-advisor`
**Created**: 2026-08-12
**Owner**: Brian Kelley
**Status**: Draft

---

## North Star

LogicLoom ships the **structure** of an advisor-and-escalation system — a
deterministic rubric that grades work by blast radius and a ladder that says what
review each grade warrants — while shipping **no opinion about which model fills
any role**, including the orchestrator.

## Who this is for

The solo maintainer or small team running LogicLoom as their daily harness, in
the moment where they've just asked for something that *looks* routine but isn't
— a two-line change to a hook, a schema edit, a refactor that three parallel
workers will touch. Today nothing in the harness distinguishes that from a typo
fix, so the decision to slow down is left entirely to the agent's mood.

Constraint from the repo owner, verbatim: *"the system ships with an advisor
system with escalation but what those advisors are should be up to the user and
scenario."*

## What success looks like

**Qualitative**:
- The harness has a **quantified trigger** for extra scrutiny — grading is by
  consequence, not by keyword-spotting in the prompt.
- The escalation is **visible**: when the agent moves to a higher rung, the user
  sees a one-line announcement. Without it the ladder is decorative.
- A user with a different model roster (no Fable, no codex, a different
  cross-provider adversary) inherits the same structure and fills the roles
  themselves. Nothing breaks; nothing was assumed.
- Concurrent workers stop colliding in the ad-hoc case that no DAG covers.

**Quantitative**: *(not tractable at this stage)*

## What ships (universal, opinion-free)

1. **A consequence × width rubric.** A cost dimension (roughly 0/1/3/3, from
   trivially reversible to hard to undo) crossed with a width dimension (0/1/2,
   how far the blast radius reaches) resolves to a rung. Deterministic,
   model-independent, requires no code.
2. **A four-rung ladder** — Light / Standard / Heavy / Max — naming what each
   rung warrants. Light means proceed. Higher rungs progressively add advisor
   consults and cross-provider adversarial review.
3. **Announcement discipline.** One line naming the rung whenever escalating to
   Standard or above.
4. **An advisor ROLE in `models.conf`** — a tier keyword alongside the existing
   orchestrator / deep-reasoner / fast-worker convention. The role exists; the
   model that fills it is user config.
5. **Three orchestration-hygiene rules**:
   - The orchestrator **reads the combined diff before declaring done** — no
     individual worker ever saw the seam between their outputs.
   - Concurrent workers must have **non-overlapping file ownership stated in the
     brief**. This covers the ad-hoc parallel-Task case that
     `freeze-write-scope.sh` deliberately default-allows outside an active DAG.
   - **Two independent reviewers flagging the same thing is treated as real.**
     Disagreement surfaces both; a finding is never silently discarded.

## What this is NOT

- **Not a model assignment.** Neither the orchestrator nor the advisor gets a
  shipped default. The repo owner's own arrangement — frontier orchestrator,
  Sonnet workers, a Fable advisor at medium effort, codex/agy for adversarial
  review — is a documented **example configuration**, never a default.
- **Not a second governance mode.** `governance.conf` lean/strict grades by
  **model capability** and holds constant for a session. This ladder grades by
  **per-task consequence** and varies *within* a session. They are **orthogonal
  and compose** — a Heavy task in lean mode is entirely coherent. This is the
  most likely misreading of the whole feature; the shipped docs must say it
  outright.
- **Not a restatement of the Cross-Check Disposition.** The Disposition in
  `AGENTS.md` Tier 1 already defines the **what** (a decorrelated,
  different-provider second look). The ladder supplies the missing **when** (a
  quantified trigger). They compose. Do not duplicate the Disposition text.
- **Not a delegation-nudge counter hook.** That is taste calibration, not
  governance. If it ships at all it ships **disabled**, with a documented toggle.
- **Not anything that writes to `~/.claude/`.** The user's own layer stays
  untouched.

## Rejected options (recorded so they are not re-proposed)

- **"Mutation is always a worker's job."** REJECTED. It inverts Principle X,
  which delegates for *context isolation and parallelism* — explicitly **not**
  because the base model lacks capability — and whose own heuristic routes
  `0 domains / trivial` work to **direct execution**. A rule forcing every
  mutation through a worker would contradict the constitution it claims to serve
  and would add a context hop to every one-line fix.

## Constraints (real, verified against the current repo)

- **`models.conf` is a documented reference convention, not a runtime resolver.**
  No consumer parses it. An advisor role added there is a convention entry — it
  will not be resolved by anything at runtime, and the design must not imply
  otherwise.
- **Claude Code honors only STATIC frontmatter `effort:` on Task subagents.**
  Dynamic per-dispatch effort exists solely via `agent()` inside `/workflow`. So
  "an advisor at medium effort" implies a dedicated agent file, not a per-call
  flag.
- **`/cross-check` is a plugin command** and exists only inside a LogicLoom
  project. Any rung that leans on it is host- and project-gated, and the skill's
  own hard constraints hold: advisory, read-only, never git, fail-open.
- The rubric must stay executable by a model reading a document. Nothing here
  requires new hooks; the governance floor is unchanged by this feature.

## Open questions

- **Where does the rubric live?** `CLAUDE.md` Standing Policies (Claude Code
  binding), `AGENTS.md` Tier 1 (provider-neutral policy that travels), or both
  with a verbatim-contract test like the Cross-Check Disposition already has?
  The tandem-update rule makes "both" non-free.
- **Does the ladder need a `/cross-check` rung parameter** — e.g. Heavy invokes
  a bounded artifact review while Max invokes `--deep` — or does the rung stay
  advisory prose and leave invocation shape to the agent?
- **How is the advisor role expressed** given the static-effort constraint? A
  project agent file (`.claude/agents/advisor.md`) parallel to `deep-reasoner` /
  `fast-worker`, a `models.conf` convention line only, or both — and what does a
  user without the example roster inherit?
- Should the rung announcement be a plain sentence, or a structured marker
  something downstream could later count?
- Does anything need to change when the same task is re-graded mid-session as
  its blast radius becomes clearer?

---

*Next step after vision is locked: `/swarm explore <topic>` and/or
`/research <question>` to fill the unknowns, then `/create-prd escalation-advisor`
to synthesize the broad PRD.*
