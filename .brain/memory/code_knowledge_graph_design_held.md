---
name: code-knowledge-graph-design-held
description: "2026-07-05 — deep-dive build-vs-buy design for adding a code + knowledge graph to LogicLoom. VERDICT: build a lightweight deterministic git-tracked text graph; buy nothing (no DB / MCP daemon / LLM extraction). 5-phase plan. User chose HOLD — nothing built. Design: features/code-knowledge-graph/exploration/graph-design.md."
metadata: 
  node_type: memory
  type: project
  originSessionId: d838fa68-7c8c-404d-9432-92c0df7b8891
---

Deep-dive (6-agent web-grounded research workflow) on adding a code graph + knowledge graph "to break down components." User scope: BOTH graphs, equal priority, together; evaluate 3rd-party AND build-your-own. Outcome: **HELD — nothing built** (user chose "hold for now" on both build-scope and product-code timing). Full design + sources: `features/code-knowledge-graph/exploration/graph-design.md` (uncommitted at time of writing).

**VERDICT (justified across dozens of tools): buy nothing; build a lightweight, deterministic, git-tracked plain-text graph. No graph DB, no MCP daemon, no LLM extraction.** Rationale:
- This repo has NO product code → the "code graph" is a HARNESS COMPONENT graph (plugins→commands→skills→agents→hooks→domain-briefs→principles); every edge already lives in `.bridge-manifest.json` / `plugin.json` / frontmatter / hook-wiring → a ~150-line jq/rg generator. A generic code-graph tool reads language ASTs and can't see this metadata.
- The "knowledge graph" ALREADY EXISTS as dead metadata: loom-memory's 16 files carry `[[wikilink]]` + temporal `SUPERSEDES/CORRECTS/REMOVED` edges the search backend parses NONE of. Formalize-in-place beats GraphRAG/Cognee/Graphiti, which re-derive those edges via expensive LLM (worse — Graphiti ~600K tokens/conversation + a graph DB to approximate the temporal edges already hand-written).
- Zero LLM extraction anywhere = the crux that keeps it from being the overbuild the framework cut 3× (marketplace MCP, RL telemetry, dev-loop).
- Storage = JSONL text-first (Anthropic memory-server shape); optional on-demand SQLite recursive-CTE ONLY if jq 1-2-hop walks prove insufficient; DOT/GraphML export-only for viz. Component graph ships IN-repo (`.logic-loom/graph/`); memory-graph sidecars the (out-of-repo) memory dir.

**Feeds existing machinery (earns its keep):** swarm-explore ranked repo-map; freeze plan-as-DAG blast-radius (ADVISORY at `/plan-review` + `/review-team` ONLY — never the write-time hook, which stays literal-match/fail-open); loom-memory 1-hop recall expansion; NEW orphan/dead-capability linter (warn, not block). Does NOTHING for domain detection or context loaders — explicitly don't build for them.

**5-PHASE PLAN (when resumed):** P1 component graph + orphan linter (deterministic, ships first); P2 formalize memory KG + 1-hop recall; P3 optional SQLite + DOT (only if jq insufficient); P4 freeze overlap/blast-radius validator (advisory, review-time); P5 DEFERRED product-code layer (ctags+rg ranked by in-degree, NO tree-sitter) until `web//apps/` exists.

**REFERENCE-ONLY (document, don't bundle) for the future product layer:** tree-sitter tags + the Aider repo-map PATTERN (copy ~200 lines, don't install), SCIP (`.scip` emitted in CI, read via a skill — precise, no resident server), Claude Code's native LSP tool. **REJECTED:** all graph DBs / MCP daemons / LLM-extraction pipelines (Neo4j/Memgraph/Kuzu-Ladybug/FalkorDB; GraphRAG/Cognee/Graphiti-Zep/Mem0/Neo4j-LLM-Builder; CodeQL/Kythe/Glean). Rot warnings surfaced: GitHub stack-graphs ARCHIVED Sept 2025; Kuzu archived Oct 2025 (→ Ladybug fork).

**Tripwires meaning it's becoming the next cut subsystem:** a running process/port/daemon a cloner must keep alive; an LLM call in the extraction path; a blocking validator (must be fail-open — ~40% of skills lack `constitutional_principles`/`triggers` keys); a new clone-time binary dep (tree-sitter/duckdb/native wheel); building for a non-consuming consumer (artifact-for-its-own-sake).

Related: [[feedback_improve_harness_not_user_skills]] (this design respects it — machinery uplift, not a new subsystem/plugin); [[architecture_v6_2_native_primitives]] (the ride-native stance it leans on); [[model_agnostic_orchestration]] (prior session-arc work).
