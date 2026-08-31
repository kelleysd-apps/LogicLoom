---
name: 2025-2026 Multi-agent coding harness research findings
description: Curated findings from a research pass on the current frontier of multi-agent harness designs (Anthropic, Cognition/Devin, Cursor, Aider, LangGraph, MetaGPT, OpenAI Agents SDK, plus academic). Use when designing components of the new vision/PRD/plan/swarm framework. Identifies high-ROI patterns to integrate and patterns NOT worth adopting at this scale.
type: reference
originSessionId: fa3efdd7-669a-41f1-a450-2f778bb4afde
---
# 2025-2026 Multi-Agent Coding Harness Research — Distilled

## Top patterns to integrate (high ROI for this framework)

1. **Plan-as-DAG with typed sprint contracts** (POLARIS / Sherlock 2026)
   - Replace flat plan.md with a DAG of tasks. Each node carries: typed inputs/outputs, file-ownership scope, acceptance rubric.
   - Solves: real wave parallelism in `/swarm implement`, deterministic merge order, conflict-free worker dispatch.
   - Complexity: medium. Plan format is the contract — `/swarm implement` reads waves from DAG topology.

2. **Jury-on-demand tribunal** (arxiv 2512.01786)
   - Replace static 3-LLM tribunal with a learned reliability predictor that picks 2–5 judges per query and weights by predicted-agreement.
   - Solves: cost explosion, bias drift in `/research` and `/review-team`.
   - Complexity: low-medium. Drop-in extension to existing tribunal.

3. **Behavioral evaluator sidecar — Playwright MCP + property-based** (Anthropic Red, ToolFuzz, Tricentis)
   - Persistent evaluator: Playwright-MCP for UI work, Hypothesis/fast-check style property tests for pure functions.
   - Snapshot mode (accessibility tree) is consensus over screenshots — deterministic, drift-resistant.
   - Folds into `/review-team` per user direction.
   - Complexity: medium.

4. **Worktree port-namespace convention** (MindStudio, Augment, AddyOsmani)
   - `PORT = BASE + WORKTREE_INDEX*10 + SVC_OFFSET`. Trivial fix for the most common multi-worktree failure mode.
   - Plus per-worktree DB branching (Neon/Supabase) or per-worktree SQLite.
   - Complexity: trivial. Hook on EnterWorktree.

5. **Hard 800K token cap with explicit reset** (scaling Cognition / Devin learning to current 1M default context)
   - Models exhibit "context anxiety" near max context — prematurely wrap up work. Cap usage at **800K of the 1M default window**; force explicit context reset (not compaction) with strong handoff artifact. Cognition's published number was 200K of 1M (older Sonnet-4.5 era); with Opus 4.6/4.7 coherence, ~800K is the practical mark.
   - Complexity: trivial. settings.json + hook.

## Medium-priority

6. **Three-tier memory + LSP-grounded retrieval** (Letta/MemGPT, arxiv 2604.19022)
   - Core (in-context: vision summary), recall (searchable history), archival (full repo + episodic).
   - LSP-grounded retrieval beats pure RAG for code (symbol-precise: "what calls this", "where defined").
   - Use Mem0 SDK; do NOT adopt Letta-as-runtime (it wants to own the agent loop).
   - Slots beneath vision → plan handoff. Existing sdd-memory plugin is the foundation.

7. **Dependency-preserving compaction** (humanlayer ace-fca pattern)
   - Compaction prompt template that preserves "task A blocks task B" edges across summary boundaries.
   - Useful for sprint-spanning sessions.

## Defer / probably not worth it at this scale

8. **Speculative execution + selective rollback** (Sherlock-style) — generators proceed past unverified nodes; evaluators run async; cosine-similarity rollback. Cool, but complexity not justified at solo-dev scale yet.

## What NOT to adopt (patterns that look good but fail in production)

- **Full peer-to-peer agent chat** (AutoGen 1.x style) — produces "Agent Tennis" loops (#1 reported failure mode). Always orchestrator-worker.
- **N>5 LLM jury on every call** — cost explodes, marginal accuracy. Use jury-on-demand or 2-of-3 only on high-stakes gates.
- **Graph memory at solo-dev scale** — Memanto results show vector+typing matches it. Revisit only at multi-repo, multi-month scale.
- **Heavyweight role-play personas** (CEO/CTO/QA / MetaGPT-style) — academic SOTA but production reports show plain function-named workers (planner/generator/evaluator) win on PR-merge rates. Roles add prompt overhead without quality gain.
- **Letta-as-runtime** — wants to own the agent loop. Use Mem0 SDK and keep your loop.
- **Replanning every step** (LangGraph plan-execute) — 20s+ per cycle latency cost is brutal interactively. Replan only on verifier failure.
- **"Bag of agents" dynamic dispatch** — 17x error trap. Pre-declare roles + file ownership.
- **Full SDK lock-in** (OpenAI Agents SDK, Cursor SDK) — model-locked, language-locked. Cherry-pick patterns, not SDK.

## Production failure modes to design against

- **Agent Tennis**: A→B→C→A loops. Prevent via orchestrator-worker only.
- **Reliability compounding**: 10 chained 95% agents = 60% system. Cap chain depth.
- **Context overflow at 4+ workers** feeding one orchestrator. 40% of multi-agent pilots die in 6 months from this.
- **Naïve parallel decisions** producing conflicting implicit choices (Cognition's core critique). Pre-declared file ownership + DAG topology fixes this.
- **Tests pass but for wrong reasons** (Tricentis "intent drift"). Behavioral evaluator catches this.

## Validation that user's existing workflow is well-aligned

The user's vision → research → PRD → plan-mode → /swarm sprint/wave → /review-team → /git-push → /code-review flow is already executing 2025-2026 best practices:
- Multi-document handoff (vision, research, PRD, plan) — consensus pattern (Anthropic, MetaGPT, Intent macOS all converge here).
- Worktree isolation — mainstream (JetBrains 2026.1, VS Code July 2025, Cursor 3 native).
- Plan-mode → plan.md to disk (Ronacher writeup confirms this is canonical Claude pattern).
- Orchestrator-worker /swarm — winning pattern over peer-to-peer (Cogent 2026 playbook).
- External evaluator (review-team) — GAN-style adversarial critic (Anthropic harness article).
- Tribunal /research — LLM jury (should be made adaptive).

The proposed framework changes are evolutionary refinements (DAG plans, jury-on-demand, behavioral evaluator, port-namespace) rather than reinvention.

## Key sources

- Anthropic harness-design article (foundational)
- Cognition Devin 2025 review + "Don't Build Multi-Agents" (single-thread counter-position; context anxiety lesson)
- Cursor 3 release (parallel agents in worktrees)
- Aider Architect mode (dual-model cost cuts)
- arxiv 2512.01786 (LLM Jury on Demand)
- arxiv 2511.00330 (Sherlock — speculative agentic execution)
- arxiv 2604.19022 (LSP-grounded code retrieval)
- arxiv 2604.22085 (Memanto — typed semantic memory)
- arxiv 2604.08906 (Bug triggers in agentic frameworks — failure mode catalog)
- humanlayer ace-fca (dependency-preserving compaction)
- Anthropic Red property-based testing
- ToolFuzz (ETH Zurich)
- Mem0 / Letta state of memory 2026
- MindStudio / Augment / Addy Osmani worktree guides
