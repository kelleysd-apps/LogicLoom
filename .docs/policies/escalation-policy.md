# Escalation Policy

**Authority**: Constitution v3.3.0 — Principle VI (Git Approval), Principle X (Agent Delegation), Principle XIV (AI Model Selection)
**Design**: `features/escalation-advisor/exploration/design-v2.md`
**Status**: FOLLOWED (model-read policy) except where a section says otherwise. Nothing in this document is enforced unless it says so.

## Escalation Disposition

Escalation Disposition — size the checking to the work, not to the subject.
Score the work on two questions, what a wrong answer costs and how widely it reaches, and run the rung that sum sets.
Effort follows cost, fan-out follows width, never the other way.
Pick the lightest execution mode that fits: background task, workers, workflow, or swarm; state it in one line.

Three canonical sentences are pinned byte-identical across `AGENTS.md` (Tier 1), `CLAUDE.md` (Standing policies) and this policy by `tests/contract/test_disposition_tandem.sh`; the rest of the paragraph is kept in step by hand.

---

## 1. The rubric and the four rungs

Ask both questions before committing to an approach, and again before calling the work done.

**If this turns out wrong, what does it cost?**

| Score | Meaning |
|---|---|
| 0 | Nothing leaves the working tree |
| 1 | A revert fixes it |
| 3 | It leaves something a revert cannot take back: mail sent, a charge, a published package, a migrated table, a rotated credential, anything already serving production |
| +3 | On top of the line above: it changes auth, payment, or customer-data logic |

**How wide is it?**

| Score | Meaning |
|---|---|
| 0 | One file, or one obvious place |
| 1 | Several files that move together |
| 2 | Many independent places, or you cannot yet list them |

Add the two scores. Score the work, not the subject: a copy fix on the payments page is a copy fix; a dependency bump nothing depends on yet is still wide.

| Sum | Rung | What it requires |
|---|---|---|
| 0-1 | **Light** | No advisor. The orchestrator looks the work over before calling it done. |
| 2-3 | **Standard** | One advisor at medium effort. Review: argue the opposite case yourself. |
| 4-5 | **Heavy** | Standard, plus one external CLI as a second opinion before and as a reviewer after (via `/cross-check` in a LogicLoom repo). |
| 6+ | **Max** | Advisor plus both external CLIs, run concurrently, each inside a worker so raw output stays out of the orchestrator's context. A workflow or fleet is permitted at this rung. |

If the Standard advisor thinks the approach itself is wrong, not merely that it needs refinement, move to Heavy before deciding. The rung is the orchestrator's call; say it in one line when escalating.

An advisor at `inherit` is the same model lineage as the orchestrator, so it is a second look, not a decorrelated one; for decorrelation use `/cross-check` (cross-provider), per the Cross-Check Disposition.

Advisors advise; workers implement. Where two independent reviewers flag the same thing, treat it as real. Where they disagree, bring both positions to the user. Never silently discard a finding.

## 2. Cadence

The rung sets how hard a reviewer works, not how often. The agents' frontmatter effort is fixed (advisor medium, reviewer high); to vary effort by rung, dispatch through `/workflow` (whose `agent()` takes a per-call `effort`) or run `/cross-check` at the rung's effort. Otherwise Standard uses the advisor, and Heavy and Max use the reviewer plus the external CLI(s). On multi-package work the advisor, reviewer and any external CLIs run **once per phase, on the phase's combined diff**, not once per package.

**Exception.** A package that touches hooks, auth, payment, customer data, or a governance floor gets its own review at the rung's effort.

Before calling anything done, the orchestrator reads the combined diff itself: each worker saw only its own piece, and none saw the seam.

## 3. Worker tiers

| Role | Tier | Effort | Job | Hard limits |
|---|---|---|---|---|
| **checker** | `haiku` | none (Haiku has no effort control) | Check-and-report only (read-only, no Write/Edit): lookups, search-and-report, summaries, running tests and reporting | Never hooks, auth, payment, customer data, or anything floor-adjacent. Stop and report if a single request would exceed about 60k tokens of input; move it to a builder. |
| **builder** | `sonnet` (`fast-worker`) | medium | Anything that writes new logic or new tests. The **default worker**: `LOOM_MODEL_WORKER = sonnet` in `.logic-loom/config/models.conf` | None beyond the hooks |
| **deep-reasoner** | `opus` | high | Architecture and hard debugging | None beyond the hooks |
| **advisor** | `inherit` | medium | Adversarial second opinion; read-only tools | Advises, never implements |
| **reviewer** | `opus` | high | Phase review over a combined diff | Reads; does not edit |

Agent files: `.claude/agents/advisor.md`, `checker.md`, `reviewer.md`, `fast-worker.md`, `deep-reasoner.md`. Agents select a tier keyword (`opus|sonnet|haiku|inherit`), never a pinned model id (`tests/contract/test_model_agnostic.sh`).

**The tier rule.** Effort follows cost, fan-out follows width, never the other way. A wide cheap sweep gets many low-effort workers; a narrow irreversible change gets one high-effort worker. Implementing-worker effort by cost score: 0 low, 1 medium, 3 high, 4-5 xhigh, 6 max. When unsure between two tiers, take the higher one.

Workers running at the same time own non-overlapping files, stated in the brief. Non-Claude models stay advisory reviewers only (`/research`, `/cross-check`); they are not workers.

## 4. Execution mode

The rung sets how hard the work is reviewed. The width and shape of the work set the mode it runs in. Choose the lightest mode that fits, state it in one line next to the rung ("Standard, workers"), and do not ask permission: the orchestrator decides. Inline is the main session's own baseline; the four delegated modes below it are the ones chosen between. For 3-5 pieces, use workers unless the step is the same across the pieces or a fixed pipeline is needed. This follows Principle X: delegate for isolation and parallelism, not because the base model lacks capability.

| Mode | Use when | Do not use when |
|---|---|---|
| **Inline** (main session) | Read-only exploration, scoring, decisions, reading the combined diff, and a quick single-place fix with no significant unknowns (the direct-execution path) | The work has more than one piece, benefits from isolation or parallelism, or would fill the main session's context |
| **Background task** | One long-running command whose output is a result, not a judgment: a test suite, a build, a scan, a wait on CI. No model in the loop; the main session continues and is notified | The step needs judgment, or edits files |
| **Workers** (subagents via the Task/Agent tool) | The default once the work has more than one piece, benefits from isolation or parallelism, or would fill the main session's context. Bounded pieces, each with one owner and non-overlapping files, the full list known up front, about five or fewer running at once. Width 0-1 | The same step repeats across many items, more than about five workers are needed, or pieces depend on each other across sprints |
| **Workflow** (`/workflow`) | The same step repeats across many items (a width-2 sweep); a fixed pipeline must run deterministically (build, review, verify); more than about five workers are needed; per-dispatch effort must vary; or the Max rung permits one regardless of piece count | Fewer than three pieces (outside Max), or the pieces are not known yet |
| **Swarm** (`/swarm`: plan.md file-ownership DAG, `/plan-review`, the freeze hook) | Feature-scale work with dependencies between pieces across sprints or waves, where collisions are the risk | A single-sitting change. Swarm requires the plan gate; it is not a faster way to run workers |

**Escalate the mode, not the rung, when the lighter one fails.** Workers collide on files: move to swarm. Pieces keep multiplying, or the step is repeating: move to workflow. A worker is only waiting on a command: move that command to a background task. **De-escalate** when a workflow or swarm would have fewer than three pieces (outside Max).

Examples:
- Run the contract suite and report: background task.
- Rename a helper across four files that move together: workers, one owner per file.
- Add the same lint rule fix to sixty independent modules: workflow.
- Build a feature with a schema, an API and a UI that depend on each other: swarm.

Status: FOLLOWED. No hook checks the mode. Isolation for parallel workers comes from the host's own worktree isolation or from the freeze hook under `/swarm implement`, not from anything this policy adds.

## 5. Enforced versus followed

**Enforced by hooks (Claude Code only):** nothing in this policy. The existing git approval gate, the subagent git deny, the protected governance surface and the freeze hook keep doing their own jobs; the escalation ladder neither widens nor narrows them.

**Followed (model-read):** the rubric and rung selection; the tier rule and worker choice; cadence and "read the combined diff"; the execution mode and its one-line statement.

**Residual.** A user-installed mod can approve a call a project hook blocked; deny rules hold over mods only under managed settings or a Team or Enterprise login. This weakens every hook verdict, not only these.
