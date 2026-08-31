---
name: may-2026-coding-harness-frontier-post-loom-v2-update
description: "Cross-cut research from 4 parallel agents on commercial / open-source / arxiv / practitioner signals from May 2026. Loom v2 plan validated; 8 specific refinements identified worth adopting plus defer/skip lists. Use this when amending Loom's plan or evaluating new patterns proposed in future research passes."
metadata: 
  node_type: memory
  type: reference
  originSessionId: fa3efdd7-669a-41f1-a450-2f778bb4afde
---

# May 2026 Coding-Harness Frontier — Consolidated Findings

**Captured**: 2026-05-26 via 4 parallel research agents (commercial / open-source / arxiv / practitioner)
**Verdict**: Loom v2 architecture **validated across all 4 angles**. No architectural rewrites needed. 8 specific refinements worth adopting; 4 specific items to defer; gstack 23-skill bundle correctly skipped.

## Cross-agent convergence (high confidence)

- **Worktree isolation** = table stakes (Cursor 3, Zed, Kanbots, `wt` all ship it)
- **Plan-as-DAG** = correct (Plan-Execute 92% vs ReAct 85%; 82% token reduction via context isolation)
- **Jury-on-demand tribunal** = correct (Phoenix v16.0.0 May 21 shipped LLM-jury natively; arxiv 2404.18796 validates the pattern)
- **Hook-based enforcement** = correct (Armin Ronacher's "chaos monkey" framing widely cited; PreToolUse hooks most-discussed Claude Code primitive 2026)
- **/retro pattern** = correct (Anthropic's "dreaming" feature validates the cross-session-learning thesis)
- **Vision→PRD→plan-mode** = correct (spec-driven dev is the 2026 standard four-phase workflow)
- **gstack skip** = correct (89.7K stars but marketing-driven, "600K LoC in 60d" widely doubted)
- **MBZUAI study**: harness vs model contribution is **98.4% / 1.6%** — Anthropic's harness-design thesis quantified

## Adopt-now patterns (8 specific refinements)

| # | Pattern | Source | Loom slot | Effort | Risk |
|---|---|---|---|---|---|
| 1 | **STORM write-time arbiter** | arxiv 2605.20563 (May 19) | Stage 11 — under freeze hook, dynamic conflict detection for legitimate same-file disjoint-range edits | M (2-3d) | Low |
| 2 | **Policy Invariance Score** | arxiv 2605.06161 (May 8) | Stage 9 — CI smoke-test on jury-on-demand rubric (paraphrase, confirm verdicts stable) | S (1d) | Trivial |
| 3 | **Async/background subagents** | Deep Agents v0.5 (May 2026) | Stage 10 — fire-and-forget task-IDs for long-running DAG nodes | M (2d) | Low |
| 4 | **Magentic ledger.md** | Microsoft Agent Framework 1.0 (Apr 2026) | Stage 6 or 10 — shared mutable orchestrator state file, survives context resets | S (1d) | Low |
| 5 | **Cursor "Build in Parallel" auto-detect** | Cursor 3 + Composer 2.5 (May 18) | Stage 10 — pre-wave DAG analyzer fans independent leaves automatically | M (2d) | Low |
| 6 | **Projected context-cost preview** | Claude Code marketplace (May 2026) | Stage 7b — render token-estimate per wave in /plan-review CEO gate | S (1d) | Low |
| 7 | **Screen-recording on failure** | Devin 2.2 | Stage 8 — MP4 capture in Playwright evaluator, attached to /retro context | M (3d) | Low |
| 8 | **Runtime isolation expansion** | Penligent critique, HN consensus | Stage 11 — expand port-namespace hook to cover DB/cache/test-state, not just ports | M (1-2d) | Low |

## Defer (revisit post-v6.0)

- **RGAO topology selection** (arxiv 2605.05657) — read code → tune DAG fan-out. Needs Loom misrouting telemetry first.
- **Memory-R2 counterfactual retro** (arxiv 2605.21768) — fair credit assignment for memory. Needs sdd-memory >100 entries.
- **Anthropic "dreaming"** scheduled cross-session pattern extraction — future evolution beyond /retro.
- **LangGraph / MAF / Letta as runtime** — assumes weaker models than Opus 4.7; never embed. Compose with Mem0 *only when* memory pain emerges.

## Doc-only items (Stage 13)

- **Explicitly name the Coordinator-Implementor-Verifier triangle** architecture in CLAUDE.md / loom-architecture.md — Loom has it but doesn't say it; practitioners ask for this exact framing (Augment Code)
- **`/swarm` reservation principle** — single-agent wins most workloads per Augment + HN consensus; reserve `/swarm` for genuinely parallel DAG branches, not default
- **"Healing-is-hiding" rule** in evaluator docs — classify failures (real / structural / environmental), never retry blindly

## Validation findings worth noting (not action items)

- Cognition caps Devin/Sonnet 4.5 at **200K of 1M** to defeat "context anxiety." Loom's 800K may be too generous, but Opus 4.7 has stronger coherence; keep 800K and tune down only if symptoms surface.
- Simon Willison (May 6, 2026) declared "vibe coding" dead — converging on agentic engineering with supervision. Loom on the right side of the consensus shift.
- METR study: experienced devs 19% **slower** with AI due to validation overhead. Loom's plan-review front-load is the right intervention.
- Faros AI 10K-dev study: AI teams produce 98% more PRs but review time balloons 91%. CEO+Eng plan-review gates this earlier.

## Skip with prejudice (no path to adopt)

- **gstack 23-skill bundle wholesale** — pattern theater (already skipped in v2)
- **Role personas** (CrewAI / MetaGPT CEO/PM/Designer cosplay) — prompt theater per Opus 4.7
- **Codex Goal mode** drift-style autonomy — opposite ethos to Loom's structured workflow
- **Cursor IDE rewrite** — wrong scope (Loom is harness-level, not editor)
- **JetBrains ACP** — too early, vendor-specific
- **LoC-as-success metric** — already correctly rejected

## Phasing recommendation for Stages 10 & 11

Both stages are growing — propose splitting risky parts:
- **Stage 10a (core)**: DAG executor linear → wave parallel (as currently planned)
- **Stage 10b (NEW)**: async subagents + Cursor auto-detect + magentic ledger (extensions to /swarm implement)
- **Stage 11a (core)**: port-namespace + 800K cap + freeze v1 (as currently planned)
- **Stage 11c (NEW)**: runtime/db/cache isolation expansion + STORM write-time arbiter

Net stage count: 17 → 19 (added 10b, 11c). Risk-isolated. Each new sub-stage one commit.

## Key sources (top citations)

- arxiv 2605.20563 STORM
- arxiv 2605.06161 Policy Invariance
- arxiv 2605.05657 RGAO (deferred)
- arxiv 2605.21768 Memory-R2 (deferred)
- arxiv 2605.06365 Execution Lineage (validates Sherlock)
- Deep Agents v0.5 — blog.langchain.com/deep-agents-v0-5
- MAF 1.0 — devblogs.microsoft.com (Apr 3 2026)
- Cursor 3 + Composer 2.5 (May 18 2026) — cursor.com/blog/composer-2-5
- Devin 2.2 — cognition.ai/blog/introducing-devin-2-2
- Claude Code week-19 updates — code.claude.com/docs/en/whats-new/2026-w19
- Anthropic "dreaming" — venturebeat.com
- MBZUAI study 98.4%/1.6% — techtimes.com (May 21 2026)
- Simon Willison (May 6) — simonwillison.net
- Penligent on runtime isolation — penligent.ai
- gstack 89.7K stars — augmentcode.com

## When to re-research

The field is moving fast. Re-run a 4-agent fan-out:
- Before promoting Loom v6.0 to main (Stage 15 verified)
- If a frontier model release (Opus 4.8, Sonnet 5.0) ships — many of these patterns are model-weakness-encoded
- Quarterly otherwise
